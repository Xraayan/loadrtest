import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:loadr/constants.dart';
import 'package:loadr/models/place_suggestion.dart';
import 'package:loadr/models/ride_quote.dart';
import 'package:loadr/screens/request_quote_screen.dart';
import 'package:loadr/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RequestVehicleScreen extends StatefulWidget {
  const RequestVehicleScreen({super.key});

  @override
  State<RequestVehicleScreen> createState() => _RequestVehicleScreenState();
}

class _RequestVehicleScreenState extends State<RequestVehicleScreen> {
  final _pickupController = TextEditingController();
  final _dropController = TextEditingController();
  final _pickupFocusNode = FocusNode();
  final _dropFocusNode = FocusNode();

  Timer? _pickupDebounce;
  Timer? _dropDebounce;
  PlaceSuggestion? _pickupPlace;
  PlaceSuggestion? _dropPlace;
  List<PlaceSuggestion> _locationSuggestions = [];
  String _selectedVehicle = 'Tata Ace';
  String _selectedSchedule = 'Now';
  bool _searchingPickup = true;
  bool _isSearchingLocation = false;
  bool _isOpeningQuote = false;
  bool _isEstimatingRide = false;
  String? _locationSearchError;
  String? _estimateError;
  RideEstimate? _rideEstimate;
  String _latestPickupQuery = '';
  String _latestDropQuery = '';
  String _lastPickupSearchQuery = '';
  String _lastDropSearchQuery = '';
  String? _estimatedRouteKey;

  Future<Position> _determinePosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Please turn on location services and try again');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception('Location permission is required');
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permission is blocked. Enable it from app settings',
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
      ),
    );
  }

  Future<void> _openMapPickerFor(bool isPickup) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final savedLatitude = prefs.getDouble('customer_latitude');
    final savedLongitude = prefs.getDouble('customer_longitude');
    final savedPoint = savedLatitude == null || savedLongitude == null
        ? null
        : LatLng(savedLatitude, savedLongitude);

    final result = await showModalBottomSheet<_MapPickerResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _MapPickerSheet(
          initialIsPickup: isPickup,
          pickupPlace: _pickupPlace,
          dropPlace: _dropPlace,
          savedPoint: savedPoint,
          resolveCurrentPosition: _determinePosition,
        );
      },
    );

    if (result == null || !mounted) return;
    _selectPlace(isPickup: result.isPickup, place: result.place);
  }

  void _onLocationFocus({required bool isPickup}) {
    setState(() {
      _searchingPickup = isPickup;
      _locationSearchError = null;
    });
  }

  void _onLocationChanged({
    required bool isPickup,
    required String value,
  }) {
    final timer = isPickup ? _pickupDebounce : _dropDebounce;
    timer?.cancel();
    final query = value.trim();

    setState(() {
      _searchingPickup = isPickup;
      _locationSearchError = null;
      _estimateError = null;
      _rideEstimate = null;
      _estimatedRouteKey = null;
      if (isPickup) {
        _pickupPlace = null;
        _latestPickupQuery = query;
      } else {
        _dropPlace = null;
        _latestDropQuery = query;
      }
    });

    if (query.length < 4) {
      setState(() {
        _locationSuggestions = [];
        _isSearchingLocation = false;
        if (isPickup) {
          _lastPickupSearchQuery = '';
        } else {
          _lastDropSearchQuery = '';
        }
      });
      return;
    }

    final debounce = Timer(
      const Duration(milliseconds: 900),
      () => _searchLocation(isPickup: isPickup, query: query),
    );

    if (isPickup) {
      _pickupDebounce = debounce;
    } else {
      _dropDebounce = debounce;
    }
  }

  Future<void> _searchLocation({
    required bool isPickup,
    required String query,
  }) async {
    if (_currentQuery(isPickup) != query || query.length < 4) return;

    final lastQuery = isPickup ? _lastPickupSearchQuery : _lastDropSearchQuery;
    if (lastQuery == query) return;

    if (isPickup) {
      _lastPickupSearchQuery = query;
    } else {
      _lastDropSearchQuery = query;
    }

    setState(() {
      _searchingPickup = isPickup;
      _isSearchingLocation = true;
    });

    try {
      final places = await ApiService.autocompletePlaces(query);
      if (!mounted || _currentQuery(isPickup) != query) return;
      setState(() {
        _locationSuggestions = places;
        _locationSearchError = null;
      });
    } catch (e) {
      if (!mounted || _currentQuery(isPickup) != query) return;
      setState(() {
        _locationSuggestions = [];
        _locationSearchError = '$e';
      });
    } finally {
      if (mounted && _currentQuery(isPickup) == query) {
        setState(() => _isSearchingLocation = false);
      }
    }
  }

  void _selectPlace({
    required bool isPickup,
    required PlaceSuggestion place,
  }) {
    setState(() {
      if (isPickup) {
        _pickupPlace = place;
        _pickupController.text = place.displayName;
        _latestPickupQuery = place.displayName;
      } else {
        _dropPlace = place;
        _dropController.text = place.displayName;
        _latestDropQuery = place.displayName;
      }
      _locationSuggestions = [];
      _locationSearchError = null;
      _estimateError = null;
      _estimatedRouteKey = null;
    });
    FocusScope.of(context).unfocus();
    _loadEstimateIfReady();
  }

  String _currentQuery(bool isPickup) {
    return isPickup ? _latestPickupQuery : _latestDropQuery;
  }

  VehicleQuote? _quoteForVehicle(String vehicleType) {
    return _rideEstimate?.quoteFor(vehicleType);
  }

  String _estimateKeyFor(PlaceSuggestion pickup, PlaceSuggestion drop) {
    return '${pickup.latitude.toStringAsFixed(6)},'
        '${pickup.longitude.toStringAsFixed(6)}|'
        '${drop.latitude.toStringAsFixed(6)},'
        '${drop.longitude.toStringAsFixed(6)}';
  }

  Future<RideEstimate?> _loadEstimateIfReady() async {
    final pickup = _pickupPlace;
    final drop = _dropPlace;
    if (pickup == null || drop == null) return null;

    final estimateKey = _estimateKeyFor(pickup, drop);
    if (_rideEstimate != null && _estimatedRouteKey == estimateKey) {
      return _rideEstimate;
    }
    if (_isEstimatingRide && _estimatedRouteKey == estimateKey) {
      return _rideEstimate;
    }

    setState(() {
      _isEstimatingRide = true;
      _estimateError = null;
      _estimatedRouteKey = estimateKey;
    });

    try {
      final estimate = await ApiService.estimateRide(
        pickup: pickup,
        drop: drop,
        vehicleType: _selectedVehicle,
        schedule: _selectedSchedule,
      );
      if (!mounted || _estimatedRouteKey != estimateKey) return null;
      setState(() {
        _rideEstimate = estimate;
        if (estimate.vehicleQuotes.isNotEmpty &&
            estimate.quoteFor(_selectedVehicle).vehicleType !=
                _selectedVehicle) {
          _selectedVehicle = estimate.suggestedVehicleType.trim().isNotEmpty
              ? estimate.suggestedVehicleType
              : estimate.vehicleQuotes.first.vehicleType;
        }
      });
      return estimate;
    } catch (e) {
      if (!mounted || _estimatedRouteKey != estimateKey) return null;
      setState(() {
        _rideEstimate = null;
        _estimatedRouteKey = null;
        _estimateError = '$e';
      });
      return null;
    } finally {
      if (mounted && _estimatedRouteKey == estimateKey) {
        setState(() => _isEstimatingRide = false);
      }
    }
  }

  Future<void> _continue() async {
    if (_pickupPlace == null || _dropPlace == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select both pickup and drop locations'),
        ),
      );
      return;
    }

    setState(() => _isOpeningQuote = true);

    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('uid');
    if (uid == null) {
      setState(() => _isOpeningQuote = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in again')),
      );
      return;
    }

    final estimate = _rideEstimate ?? await _loadEstimateIfReady();
    if (estimate == null) {
      setState(() => _isOpeningQuote = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not estimate this route')),
      );
      return;
    }
    final quote = estimate.quoteFor(_selectedVehicle);

    await prefs.setString('request_pickup_name', _pickupPlace!.displayName);
    await prefs.setDouble('request_pickup_latitude', _pickupPlace!.latitude);
    await prefs.setDouble('request_pickup_longitude', _pickupPlace!.longitude);
    await prefs.setString('request_drop_name', _dropPlace!.displayName);
    await prefs.setDouble('request_drop_latitude', _dropPlace!.latitude);
    await prefs.setDouble('request_drop_longitude', _dropPlace!.longitude);
    await prefs.setString('request_vehicle_type', _selectedVehicle);
    await prefs.setString('request_schedule', _selectedSchedule);
    await prefs.setDouble('request_distance_km', estimate.distanceKm);
    await prefs.setDouble('request_estimated_amount', quote.amount);

    if (!mounted) return;
    await Navigator.pushNamed(
      context,
      '/request-quote',
      arguments: RequestQuoteArgs(
        customerUid: uid,
        pickup: _pickupPlace!,
        drop: _dropPlace!,
        vehicleType: _selectedVehicle,
        schedule: _selectedSchedule,
        estimate: estimate,
      ),
    );

    if (mounted) {
      setState(() => _isOpeningQuote = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F8F8),
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.maybePop(context);
            } else {
              Navigator.pushReplacementNamed(context, '/customer-home');
            }
          },
          icon: const Icon(Icons.arrow_back, color: Colors.black),
        ),
        title: const Text(
          'Request Vehicle',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            const Text(
              'Plan your move',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose pickup and drop locations.',
              style: TextStyle(
                color: Colors.black54,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            _RouteInputCard(
              pickupController: _pickupController,
              dropController: _dropController,
              pickupFocusNode: _pickupFocusNode,
              dropFocusNode: _dropFocusNode,
              pickupPlace: _pickupPlace,
              dropPlace: _dropPlace,
              loadingPickup: _isSearchingLocation && _searchingPickup,
              loadingDrop: _isSearchingLocation && !_searchingPickup,
              onPickupFocus: () => _onLocationFocus(isPickup: true),
              onDropFocus: () => _onLocationFocus(isPickup: false),
              onPickupChanged: (value) => _onLocationChanged(
                isPickup: true,
                value: value,
              ),
              onDropChanged: (value) => _onLocationChanged(
                isPickup: false,
                value: value,
              ),
              onPickupMapTap: () => _openMapPickerFor(true),
              onDropMapTap: () => _openMapPickerFor(false),
            ),
            _InlineLocationSuggestions(
              suggestions: _locationSuggestions,
              error: _locationSearchError,
              onSelected: (place) => _selectPlace(
                isPickup: _searchingPickup,
                place: place,
              ),
            ),
            const SizedBox(height: 28),
            const _SectionTitle('Schedule'),
            const SizedBox(height: 12),
            _ScheduleSegmentedControl(
              selectedValue: _selectedSchedule,
              onChanged: (value) {
                setState(() => _selectedSchedule = value);
              },
            ),
            const SizedBox(height: 28),
            const _SectionTitle('Vehicle type'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _SuggestVehicleChip(
                  onTap: () {
                    final suggested = _rideEstimate?.suggestedVehicleType;
                    if (suggested == null || suggested.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Select pickup and drop first'),
                        ),
                      );
                      return;
                    }
                    setState(() => _selectedVehicle = suggested);
                  },
                ),
                for (final vehicle in _vehicleOptions())
                  _VehicleChip(
                    label: vehicle,
                    amount: _quoteForVehicle(vehicle)?.amount,
                    selected: _selectedVehicle == vehicle,
                    onTap: () {
                      setState(() => _selectedVehicle = vehicle);
                    },
                  ),
              ],
            ),
            if (_isEstimatingRide) ...[
              const SizedBox(height: 12),
              const _InlineMessage(text: 'Estimating route and prices...'),
            ] else if (_estimateError != null) ...[
              const SizedBox(height: 12),
              _InlineMessage(text: _estimateError!),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed:
                  (_isOpeningQuote || _isEstimatingRide) ? null : _continue,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryOrange,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isOpeningQuote
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  List<String> _vehicleOptions() {
    final quotes = _rideEstimate?.vehicleQuotes;
    if (quotes != null && quotes.isNotEmpty) {
      return quotes.map((quote) => quote.vehicleType).toList();
    }
    return const [
      '3 Wheeler Ape',
      'Tata Ace',
      'Dost Pickup',
      'Tata 407 Water Tanker',
    ];
  }

  @override
  void dispose() {
    _pickupDebounce?.cancel();
    _dropDebounce?.cancel();
    _pickupController.dispose();
    _dropController.dispose();
    _pickupFocusNode.dispose();
    _dropFocusNode.dispose();
    super.dispose();
  }
}

class _RouteInputCard extends StatelessWidget {
  final TextEditingController pickupController;
  final TextEditingController dropController;
  final FocusNode pickupFocusNode;
  final FocusNode dropFocusNode;
  final PlaceSuggestion? pickupPlace;
  final PlaceSuggestion? dropPlace;
  final bool loadingPickup;
  final bool loadingDrop;
  final VoidCallback onPickupFocus;
  final VoidCallback onDropFocus;
  final ValueChanged<String> onPickupChanged;
  final ValueChanged<String> onDropChanged;
  final VoidCallback onPickupMapTap;
  final VoidCallback onDropMapTap;

  const _RouteInputCard({
    required this.pickupController,
    required this.dropController,
    required this.pickupFocusNode,
    required this.dropFocusNode,
    required this.pickupPlace,
    required this.dropPlace,
    required this.loadingPickup,
    required this.loadingDrop,
    required this.onPickupFocus,
    required this.onDropFocus,
    required this.onPickupChanged,
    required this.onDropChanged,
    required this.onPickupMapTap,
    required this.onDropMapTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFEDEDED)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 24, 8, 20),
            child: _RouteIndicator(),
          ),
          Expanded(
            child: Column(
              children: [
                _RouteLocationRow(
                  controller: pickupController,
                  focusNode: pickupFocusNode,
                  label: 'Pick-up location',
                  placeholder: 'Enter pick-up location',
                  selected: pickupPlace != null,
                  loading: loadingPickup,
                  onFocus: onPickupFocus,
                  onChanged: onPickupChanged,
                  onMapTap: onPickupMapTap,
                ),
                const Divider(height: 1, color: Color(0xFFEDEDED)),
                _RouteLocationRow(
                  controller: dropController,
                  focusNode: dropFocusNode,
                  label: 'Drop location',
                  placeholder: 'Where to?',
                  selected: dropPlace != null,
                  loading: loadingDrop,
                  onFocus: onDropFocus,
                  onChanged: onDropChanged,
                  onMapTap: onDropMapTap,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteIndicator extends StatelessWidget {
  const _RouteIndicator();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 104,
      child: Column(
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black87, width: 2),
            ),
            child: Center(
              child: Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Colors.black87,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              width: 2,
              margin: const EdgeInsets.symmetric(vertical: 6),
              color: const Color(0xFFD8D8D8),
            ),
          ),
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteLocationRow extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final String placeholder;
  final bool selected;
  final bool loading;
  final VoidCallback onFocus;
  final ValueChanged<String> onChanged;
  final VoidCallback onMapTap;

  const _RouteLocationRow({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.placeholder,
    required this.selected,
    required this.loading,
    required this.onFocus,
    required this.onChanged,
    required this.onMapTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      textField: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 13, 18, 13),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onTap: onFocus,
                  onChanged: onChanged,
                  textInputAction: TextInputAction.search,
                  minLines: 1,
                  maxLines: 1,
                  decoration: InputDecoration(
                    labelText: label,
                    hintText: placeholder,
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    labelStyle: const TextStyle(
                      color: Colors.black45,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    hintStyle: const TextStyle(
                      color: Colors.black38,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 40,
                height: 40,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: loading
                      ? const Center(
                          key: ValueKey('loading'),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          key: ValueKey('map-$selected'),
                          tooltip: selected ? 'Change on map' : 'Set on map',
                          onPressed: onMapTap,
                          style: IconButton.styleFrom(
                            backgroundColor: selected
                                ? kPrimaryOrange.withOpacity(0.10)
                                : const Color(0xFFF5F5F5),
                            foregroundColor:
                                selected ? kPrimaryOrange : Colors.black45,
                            padding: EdgeInsets.zero,
                          ),
                          icon: const Icon(
                            Icons.my_location_outlined,
                            size: 20,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineLocationSuggestions extends StatelessWidget {
  final List<PlaceSuggestion> suggestions;
  final String? error;
  final ValueChanged<PlaceSuggestion> onSelected;

  const _InlineLocationSuggestions({
    required this.suggestions,
    required this.error,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (error == null && suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE8E8E8)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F000000),
                blurRadius: 14,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: error != null
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: _InlineMessage(text: error!),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemBuilder: (context, index) {
                    final place = suggestions[index];
                    return _PlaceSuggestionTile(
                      place: place,
                      onTap: () => onSelected(place),
                    );
                  },
                  separatorBuilder: (context, index) {
                    return const Divider(
                      height: 1,
                      indent: 58,
                      color: Color(0xFFEFEFEF),
                    );
                  },
                  itemCount: suggestions.length,
                ),
        ),
      ),
    );
  }
}

class _MapPickerSheet extends StatefulWidget {
  final bool initialIsPickup;
  final PlaceSuggestion? pickupPlace;
  final PlaceSuggestion? dropPlace;
  final LatLng? savedPoint;
  final Future<Position> Function() resolveCurrentPosition;

  const _MapPickerSheet({
    required this.initialIsPickup,
    required this.pickupPlace,
    required this.dropPlace,
    required this.savedPoint,
    required this.resolveCurrentPosition,
  });

  @override
  State<_MapPickerSheet> createState() => _MapPickerSheetState();
}

class _MapPickerSheetState extends State<_MapPickerSheet> {
  static const LatLng _defaultCenter = LatLng(20.5937, 78.9629);

  final _mapController = MapController();
  late bool _isPickup;
  late LatLng _selectedPoint;
  String? _selectedAddress;
  PlaceSuggestion? _resolvedPlace;
  Timer? _reverseDebounce;
  int _reverseLookupId = 0;
  bool _loading = false;
  bool _resolvingAddress = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _isPickup = widget.initialIsPickup;
    final fieldPoint = _pointForCurrentField();
    _selectedPoint = fieldPoint ?? widget.savedPoint ?? _defaultCenter;
    _resolvedPlace = _currentPlace;
    _selectedAddress = _resolvedPlace?.displayName;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (fieldPoint == null && widget.savedPoint == null) {
        _moveToCurrentLocation();
      } else if (_selectedAddress == null) {
        _scheduleReverseLookup();
      }
    });
  }

  PlaceSuggestion? get _currentPlace {
    return _isPickup ? widget.pickupPlace : widget.dropPlace;
  }

  LatLng? _pointForCurrentField() {
    final place = _currentPlace;
    if (place == null) return null;
    return LatLng(place.latitude, place.longitude);
  }

  Future<void> _moveToCurrentLocation() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final position = await widget.resolveCurrentPosition();
      if (!mounted) return;
      final point = LatLng(position.latitude, position.longitude);
      setState(() {
        _selectedPoint = point;
        _selectedAddress = null;
        _resolvedPlace = null;
      });
      _moveMap(point, 16);
      _scheduleReverseLookup();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _setField(bool isPickup) {
    final nextPlace = isPickup ? widget.pickupPlace : widget.dropPlace;
    final nextPoint = nextPlace == null
        ? _selectedPoint
        : LatLng(nextPlace.latitude, nextPlace.longitude);

    setState(() {
      _isPickup = isPickup;
      _selectedPoint = nextPoint;
      _resolvedPlace = nextPlace;
      _selectedAddress = _resolvedPlace?.displayName;
      _error = null;
    });
    _moveMap(nextPoint, 15);
    if (_selectedAddress == null) {
      _scheduleReverseLookup();
    }
  }

  void _moveMap(LatLng point, double zoom) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _mapController.move(point, zoom);
      } catch (_) {
        // The map controller can be briefly unattached while the sheet lays out.
      }
    });
  }

  void _setSelectedPoint(LatLng point) {
    setState(() {
      _selectedPoint = point;
      _selectedAddress = null;
      _resolvedPlace = null;
      _error = null;
    });
    _scheduleReverseLookup();
  }

  void _scheduleReverseLookup() {
    _reverseDebounce?.cancel();
    final point = _selectedPoint;
    setState(() => _resolvingAddress = true);
    _reverseDebounce = Timer(
      const Duration(milliseconds: 700),
      () async {
        try {
          await _reverseLookup(point);
        } catch (_) {
          // Passive map preview lookup can fail; confirmation will retry.
        }
      },
    );
  }

  Future<PlaceSuggestion> _reverseLookup(LatLng point) async {
    final lookupId = ++_reverseLookupId;
    if (mounted) {
      setState(() => _resolvingAddress = true);
    }

    try {
      final place = await ApiService.reverseGeocode(
        latitude: point.latitude,
        longitude: point.longitude,
      );
      if (!mounted || lookupId != _reverseLookupId) return place;
      setState(() {
        _resolvedPlace = place;
        _selectedAddress = place.displayName;
      });
      return place;
    } finally {
      if (mounted && lookupId == _reverseLookupId) {
        setState(() => _resolvingAddress = false);
      }
    }
  }

  Future<void> _confirm() async {
    _reverseDebounce?.cancel();
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final place = _resolvedPlace ?? await _reverseLookup(_selectedPoint);
      if (!mounted) return;
      Navigator.pop(
        context,
        _MapPickerResult(isPickup: _isPickup, place: place),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.88,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Set location on map',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                _ScheduleSegmentedControl(
                  selectedValue: _isPickup ? 'Pick-up' : 'Drop',
                  values: const ['Pick-up', 'Drop'],
                  icons: const [
                    Icons.radio_button_checked,
                    Icons.location_on_outlined,
                  ],
                  onChanged: (value) => _setField(value == 'Pick-up'),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _GeoapifyMapPicker(
                    controller: _mapController,
                    selectedPoint: _selectedPoint,
                    selectedAddress: _selectedAddress,
                    loading: _loading,
                    resolvingAddress: _resolvingAddress,
                    onPositionChanged: _setSelectedPoint,
                    onUseCurrentLocation: _moveToCurrentLocation,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _InlineMessage(text: _error!),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _confirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryOrange,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Confirm location',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _reverseDebounce?.cancel();
    super.dispose();
  }
}

class _GeoapifyMapPicker extends StatelessWidget {
  final MapController controller;
  final LatLng selectedPoint;
  final String? selectedAddress;
  final bool loading;
  final bool resolvingAddress;
  final ValueChanged<LatLng> onPositionChanged;
  final VoidCallback onUseCurrentLocation;

  const _GeoapifyMapPicker({
    required this.controller,
    required this.selectedPoint,
    required this.selectedAddress,
    required this.loading,
    required this.resolvingAddress,
    required this.onPositionChanged,
    required this.onUseCurrentLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F6),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE7E7E7)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: controller,
              options: MapOptions(
                initialCenter: selectedPoint,
                initialZoom: 15,
                minZoom: 4,
                maxZoom: 20,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.drag |
                      InteractiveFlag.pinchZoom |
                      InteractiveFlag.doubleTapZoom,
                ),
                onPositionChanged: (camera, hasGesture) {
                  if (hasGesture) {
                    onPositionChanged(camera.center);
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: ApiService.mapTileUrlTemplate,
                  retinaMode: false,
                  userAgentPackageName: 'com.example.loadr',
                  panBuffer: 0,
                  maxNativeZoom: 20,
                  maxZoom: 20,
                ),
                const RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution(
                      'Geoapify | OpenStreetMap contributors',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Center(
            child: IgnorePointer(
              child: Padding(
                padding: EdgeInsets.only(bottom: 22),
                child: Icon(
                  Icons.location_on,
                  color: kPrimaryOrange,
                  size: 42,
                ),
              ),
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 14,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 16,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      selectedAddress ??
                          (resolvingAddress
                              ? 'Finding location name...'
                              : 'Move map to choose location'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selectedAddress == null
                            ? Colors.black45
                            : Colors.black87,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 40,
                    child: TextButton.icon(
                      onPressed: loading ? null : onUseCurrentLocation,
                      icon: loading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location, size: 18),
                      label: const Text('GPS'),
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFFFF0EA),
                        foregroundColor: kPrimaryOrange,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPickerResult {
  final bool isPickup;
  final PlaceSuggestion place;

  const _MapPickerResult({
    required this.isPickup,
    required this.place,
  });
}

class _PlaceSuggestionTile extends StatelessWidget {
  final PlaceSuggestion place;
  final VoidCallback onTap;

  const _PlaceSuggestionTile({
    required this.place,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F5F5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on_outlined,
                  color: Colors.black54,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${place.latitude.toStringAsFixed(5)}, '
                      '${place.longitude.toStringAsFixed(5)}',
                      style: const TextStyle(
                        color: Colors.black45,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleSegmentedControl extends StatelessWidget {
  final String selectedValue;
  final List<String> values;
  final List<IconData> icons;
  final ValueChanged<String> onChanged;

  const _ScheduleSegmentedControl({
    required this.selectedValue,
    required this.onChanged,
    this.values = const ['Now', 'Later'],
    this.icons = const [Icons.flash_on, Icons.schedule],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFEFEF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          for (var index = 0; index < values.length; index++) ...[
            Expanded(
              child: _SegmentButton(
                label: values[index],
                icon: icons[index],
                selected: selectedValue == values[index],
                onTap: () => onChanged(values[index]),
              ),
            ),
            if (index != values.length - 1) const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            height: 44,
            decoration: BoxDecoration(
              color: selected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              boxShadow: selected
                  ? const [
                      BoxShadow(
                        color: Color(0x12000000),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: selected ? kPrimaryOrange : Colors.black54,
                  size: 18,
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? Colors.black87 : Colors.black54,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VehicleChip extends StatelessWidget {
  final String label;
  final double? amount;
  final bool selected;
  final VoidCallback onTap;

  const _VehicleChip({
    required this.label,
    required this.amount,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              color: selected ? kPrimaryOrange : Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected ? kPrimaryOrange : const Color(0xFFE3E3E3),
              ),
              boxShadow: selected
                  ? const [
                      BoxShadow(
                        color: Color(0x1FE64A19),
                        blurRadius: 12,
                        offset: Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              amount == null
                  ? label
                  : '$label  Rs ${amount!.toStringAsFixed(0)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xB8000000),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SuggestVehicleChip extends StatelessWidget {
  final VoidCallback onTap;

  const _SuggestVehicleChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF0EA),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFFFD2C2)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome, color: kPrimaryOrange, size: 17),
              SizedBox(width: 7),
              Text(
                'Suggest me',
                style: TextStyle(
                  color: kPrimaryOrange,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.black87,
        fontSize: 17,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  final String text;

  const _InlineMessage({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFB3261E),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
