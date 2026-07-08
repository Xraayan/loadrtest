class PlaceSuggestion {
  final String displayName;
  final double latitude;
  final double longitude;
  final String city;
  final String district;
  final String state;

  const PlaceSuggestion({
    required this.displayName,
    required this.latitude,
    required this.longitude,
    this.city = '',
    this.district = '',
    this.state = '',
  });

  factory PlaceSuggestion.fromJson(Map<String, dynamic> json) {
    return PlaceSuggestion(
      displayName: '${json['display_name'] ?? json['displayName'] ?? ''}',
      latitude: double.parse('${json['latitude'] ?? json['lat']}'),
      longitude: double.parse('${json['longitude'] ?? json['lon']}'),
      city: '${json['city'] ?? ''}',
      district: '${json['district'] ?? ''}',
      state: '${json['state'] ?? ''}',
    );
  }
}
