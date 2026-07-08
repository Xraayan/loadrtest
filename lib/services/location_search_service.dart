import 'package:loadr/models/place_suggestion.dart';
import 'package:loadr/services/api_service.dart';

class LocationSearchService {
  static Future<List<PlaceSuggestion>> autocomplete(String query) {
    return ApiService.autocompletePlaces(query);
  }

  static Future<PlaceSuggestion> reverseGeocode({
    required double latitude,
    required double longitude,
  }) {
    return ApiService.reverseGeocode(
      latitude: latitude,
      longitude: longitude,
    );
  }
}
