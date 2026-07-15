import 'package:latlong2/latlong.dart';

class VehicleQuote {
  final String vehicleType;
  final double distanceKm;
  final double baseFare;
  final double perKmRate;
  final double minimumFare;
  final double amount;

  const VehicleQuote({
    required this.vehicleType,
    required this.distanceKm,
    required this.baseFare,
    required this.perKmRate,
    required this.minimumFare,
    required this.amount,
  });

  factory VehicleQuote.fromJson(Map<String, dynamic> json) {
    return VehicleQuote(
      vehicleType: '${json['vehicle_type'] ?? json['vehicleType'] ?? ''}',
      distanceKm: _toDouble(json['distance_km'] ?? json['distanceKm']),
      baseFare: _toDouble(json['base_fare'] ?? json['baseFare']),
      perKmRate: _toDouble(json['per_km_rate'] ?? json['perKmRate']),
      minimumFare: _toDouble(json['minimum_fare'] ?? json['minimumFare']),
      amount: _toDouble(json['amount']),
    );
  }

  static double _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}') ?? 0;
  }
}

class RideEstimate {
  final double distanceKm;
  final VehicleQuote selectedQuote;
  final List<VehicleQuote> vehicleQuotes;
  final List<LatLng> routePoints;
  final String city;
  final String district;
  final String state;
  final String suggestedVehicleType;

  const RideEstimate({
    required this.distanceKm,
    required this.selectedQuote,
    required this.vehicleQuotes,
    required this.routePoints,
    required this.city,
    required this.district,
    required this.state,
    required this.suggestedVehicleType,
  });

  factory RideEstimate.fromJson(Map<String, dynamic> json) {
    final quotes = (json['vehicle_quotes'] as List? ?? [])
        .whereType<Map>()
        .map((item) => VehicleQuote.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    final selected = json['selected_quote'] is Map
        ? VehicleQuote.fromJson(
            Map<String, dynamic>.from(json['selected_quote'] as Map),
          )
        : (quotes.isNotEmpty
            ? quotes.first
            : const VehicleQuote(
                vehicleType: 'Tata Ace',
                distanceKm: 0,
                baseFare: 0,
                perKmRate: 0,
                minimumFare: 0,
                amount: 0,
              ));
    final metadata = json['pickup_metadata'] is Map
        ? Map<String, dynamic>.from(json['pickup_metadata'] as Map)
        : <String, dynamic>{};

    return RideEstimate(
      distanceKm: VehicleQuote._toDouble(json['distance_km']),
      selectedQuote: selected,
      vehicleQuotes: quotes,
      routePoints:
          (json['route_points'] as List? ?? []).whereType<Map>().map((item) {
        final point = Map<String, dynamic>.from(item);
        return LatLng(
          VehicleQuote._toDouble(point['latitude']),
          VehicleQuote._toDouble(point['longitude']),
        );
      }).toList(),
      city: '${metadata['city'] ?? ''}',
      district: '${metadata['district'] ?? ''}',
      state: '${metadata['state'] ?? ''}',
      suggestedVehicleType: '${json['suggested_vehicle_type'] ?? ''}',
    );
  }

  VehicleQuote quoteFor(String vehicleType) {
    return vehicleQuotes.firstWhere(
      (quote) => quote.vehicleType == vehicleType,
      orElse: () => selectedQuote,
    );
  }
}
