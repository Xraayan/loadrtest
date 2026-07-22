import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:loadr/constants.dart';
import 'package:loadr/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  String _displayName = 'Customer';
  Map<String, dynamic>? _activeBooking;

  @override
  void initState() {
    super.initState();
    _loadHeader();
  }

  Future<void> _loadHeader() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('customer_name');
      final activeBookingJson = prefs.getString('active_booking');
    Map<String, dynamic>? activeBooking;
    if (activeBookingJson != null && activeBookingJson.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(activeBookingJson);
        if (decoded is Map) {
          activeBooking = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        await prefs.remove('active_booking');
      }
      }

      if (!mounted) return;
      setState(() {
        if (name != null && name.trim().isNotEmpty) {
          _displayName = name.trim();
        }
        _activeBooking = activeBooking;
      });

      final uid = prefs.getString('uid');
      if (uid != null && uid.trim().isNotEmpty) {
        final backendBooking = await ApiService.getCustomerActiveJob(uid);
        if (!mounted) return;
        setState(() => _activeBooking = backendBooking);
      }
    } catch (_) {
      // Keep cached dashboard data while the backend is unavailable.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Welcome',
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          _displayName,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () async {
                      await Navigator.pushNamed(context, '/profile');
                      if (mounted) _loadHeader();
                    },
                    borderRadius: BorderRadius.circular(999),
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: kPrimaryOrange.withOpacity(0.12),
                      child: const Icon(
                        Icons.person_outline,
                        color: kPrimaryOrange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: kPrimaryOrange,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Move goods without the calls',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Book a vehicle, compare driver availability, and track your shipment.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          height: 46,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await Navigator.pushNamed(
                                context,
                                '/request-vehicle',
                              );
                              if (mounted) {
                                _loadHeader();
                              }
                            },
                            icon: const Icon(
                              Icons.add_road,
                              color: kPrimaryOrange,
                            ),
                            label: const Text('Request Vehicle'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: kPrimaryOrange,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'For you',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.18,
                    children: [
                      _CustomerActionCard(
                        title: 'Active Bookings',
                        subtitle: _activeBooking == null
                            ? 'Track current moves'
                            : _bookingTileSubtitle(_activeBooking!),
                        icon: Icons.route_outlined,
                        active: _activeBooking != null,
                        onTap: _activeBooking == null
                            ? null
                            : () async {
                                await Navigator.pushNamed(
                                  context,
                                  '/active-booking',
                                );
                                if (mounted) {
                                  _loadHeader();
                                }
                              },
                      ),
                      const _CustomerActionCard(
                        title: 'Saved Places',
                        subtitle: 'Pickup and drop points',
                        icon: Icons.bookmark_border,
                      ),
                      const _CustomerActionCard(
                        title: 'Quotes',
                        subtitle: 'Compare load prices',
                        icon: Icons.receipt_long_outlined,
                      ),
                      const _CustomerActionCard(
                        title: 'Support',
                        subtitle: 'Get help quickly',
                        icon: Icons.support_agent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _activeBooking == null
                      ? const _EmptyBookingCard()
                      : _ActiveBookingCard(
                          booking: _activeBooking!,
                          onTap: () async {
                            await Navigator.pushNamed(
                              context,
                              '/active-booking',
                            );
                            if (mounted) {
                              _loadHeader();
                            }
                          },
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveBookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final VoidCallback onTap;

  const _ActiveBookingCard({
    required this.booking,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pickup = _shortLocation('${booking['pickup_location'] ?? ''}');
    final drop = _shortLocation('${booking['dropoff_location'] ?? ''}');
    final vehicleType = '${booking['vehicle_type'] ?? 'Vehicle'}';
    final amount = _asDouble(booking['amount']);
    final distanceKm = _asDouble(booking['distance_km']);
    final statusLabel = _bookingStatusLabel(booking);
    final accepted = _bookingAccepted(booking);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEAEAEA)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0F000000),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0EA),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.local_shipping_outlined,
                        color: kPrimaryOrange,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Active booking',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$vehicleType - ${distanceKm.toStringAsFixed(1)} km',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: accepted
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFFFFF0EA),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: accepted
                              ? const Color(0xFF2E7D32)
                              : kPrimaryOrange,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right, color: Colors.black38),
                  ],
                ),
                const SizedBox(height: 16),
                _RouteLine(
                  label: 'Pickup',
                  value: pickup,
                  icon: Icons.trip_origin,
                ),
                const SizedBox(height: 10),
                _RouteLine(label: 'Drop', value: drop, icon: Icons.stop),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(
                      Icons.payments_outlined,
                      size: 18,
                      color: Colors.black45,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Estimated Rs ${amount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteLine extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _RouteLine({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.black45),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.black45,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value.isEmpty ? '-' : value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyBookingCard extends StatelessWidget {
  const _EmptyBookingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEAEAEA)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0EA),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.local_shipping_outlined,
              color: kPrimaryOrange,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No active bookings yet',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 4),
                Text(
                  'Your requested vehicles and shipments will appear here.',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool active;
  final VoidCallback? onTap;

  const _CustomerActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: active ? const Color(0xFFFFF7F4) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active ? kPrimaryOrange : const Color(0xFFEAEAEA),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: kPrimaryOrange, size: 28),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: active ? kPrimaryOrange : Colors.black54,
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

double _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}

String _shortLocation(String value) {
  final parts = value
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return value;
  return parts.first;
}

String _bookingTileSubtitle(Map<String, dynamic> booking) {
  final status = '${booking['status'] ?? ''}'.trim().toLowerCase();
  if (status == 'arriving') return 'Driver reaching pickup';
  if (status == 'in_progress') return 'Pickup confirmed';
  if (status == 'completed') return 'Trip completed';
  return _bookingAccepted(booking) ? 'Driver accepted' : '1 open move';
}

String _bookingStatusLabel(Map<String, dynamic> booking) {
  final status = '${booking['status'] ?? ''}'.trim().toLowerCase();
  if (status == 'arriving') return 'Arriving';
  if (status == 'in_progress') return 'On trip';
  if (status == 'completed') return 'Done';
  return _bookingAccepted(booking) ? 'Accepted' : 'Open';
}

bool _bookingAccepted(Map<String, dynamic> booking) {
  final status = '${booking['status'] ?? ''}'.trim().toLowerCase();
  return status == 'assigned' ||
      status == 'accepted' ||
      status == 'arriving' ||
      status == 'in_progress' ||
      status == 'completed' ||
      '${booking['assigned_driver_uid'] ?? ''}'.trim().isNotEmpty;
}
