import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:loadr/models/place_suggestion.dart';
import 'package:loadr/models/ride_quote.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String _apiBaseUrlOverride =
      String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_apiBaseUrlOverride.trim().isNotEmpty) {
      return _apiBaseUrlOverride.trim().replaceFirst(RegExp(r'/$'), '');
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api';
    }

    return 'http://localhost:8000/api';
  }

  // Sign in with phone number
  static Future<Map<String, dynamic>> signIn(String phone) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/signin'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'phone': phone}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to sign in: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Verify OTP and get token
  static Future<Map<String, dynamic>> verifyOtp(
      String phone, String otp) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/verify-otp'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'phone': phone, 'otp': otp}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Store token locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', data['token']);
        await prefs.setString('uid', data['uid']);
        return data;
      } else {
        throw Exception(_errorMessage(
          response.body,
          fallback: 'Invalid OTP',
        ));
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static Future<void> selectRole(String uid, String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_role', role);

    try {
      final token = await getAuthToken();
      final response = await http
          .patch(
            Uri.parse('$baseUrl/users/$uid/role'),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'role': role}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        await prefs.remove('role_sync_pending');
      } else {
        await prefs.setBool('role_sync_pending', true);
      }
    } catch (_) {
      await prefs.setBool('role_sync_pending', true);
    }
  }

  static Future<String?> getSelectedRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('selected_role');
  }

  static Future<void> updateUserProfile(
    String uid, {
    required String name,
    required String email,
    Map<String, dynamic>? currentLocation,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('customer_name', name);
    await prefs.setString('customer_email', email);
    if (currentLocation != null) {
      final latitude = currentLocation['latitude'];
      final longitude = currentLocation['longitude'];
      if (latitude is num && longitude is num) {
        await prefs.setDouble('customer_latitude', latitude.toDouble());
        await prefs.setDouble('customer_longitude', longitude.toDouble());
      }
    }

    try {
      final token = await getAuthToken();
      final body = <String, dynamic>{
        'name': name,
        'email': email,
        if (currentLocation != null) 'current_location': currentLocation,
      };
      final response = await http
          .patch(
            Uri.parse('$baseUrl/users/$uid/profile'),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        await prefs.remove('customer_profile_sync_pending');
      } else {
        await prefs.setBool('customer_profile_sync_pending', true);
        throw Exception(_errorMessage(
          response.body,
          fallback: 'Failed to save customer profile',
        ));
      }
    } catch (e) {
      await prefs.setBool('customer_profile_sync_pending', true);
      throw Exception('Profile saved locally, but database sync failed: $e');
    }
  }

  static String _errorMessage(String responseBody, {required String fallback}) {
    try {
      final data = jsonDecode(responseBody);
      final detail = data['detail'];
      if (detail is String && detail.trim().isNotEmpty) {
        return detail.trim();
      }
    } catch (_) {
      // Use fallback below when the backend did not send JSON.
    }
    return fallback;
  }

  // Get stored auth token
  static Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // Get driver profile
  static Future<Map<String, dynamic>> getDriverProfile(String uid) async {
    try {
      final token = await getAuthToken();
      final response = await http.get(
        Uri.parse('$baseUrl/drivers/$uid'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        await cacheDriverProfile(data);
        return data;
      } else {
        throw Exception('Failed to get profile');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static Future<void> updateDriverProfile(
    String uid,
    Map<String, dynamic> data,
  ) async {
    await cacheDriverProfile(data);
    final token = await getAuthToken();

    final response = await http.put(
      Uri.parse('$baseUrl/drivers/$uid'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );

    if (response.statusCode != 200) {
      throw Exception(response.body);
    }
  }

  static Future<void> cacheDriverProfile(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final name = data['name'];
    final vehicleNumber = data['vehicle_number'];
    if (name != null && '$name'.trim().isNotEmpty) {
      await prefs.setString('driver_name', '$name'.trim());
    }
    if (vehicleNumber != null && '$vehicleNumber'.trim().isNotEmpty) {
      await prefs.setString('driver_vehicle_number', '$vehicleNumber'.trim());
    }

    final location = data['current_location'];
    if (location is Map) {
      await cacheLocation(
        role: 'driver',
        latitude: location['latitude'],
        longitude: location['longitude'],
        isActive: location['is_active'],
      );
    }
  }

  static Future<void> cacheLocation({
    required String role,
    required Object? latitude,
    required Object? longitude,
    Object? isActive,
    String? label,
  }) async {
    final lat = _toDouble(latitude);
    final lng = _toDouble(longitude);
    if (lat == null || lng == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('${role}_latitude', lat);
    await prefs.setDouble('${role}_longitude', lng);
    if (isActive is bool) {
      await prefs.setBool('${role}_is_active', isActive);
    }
    if (label != null && label.trim().isNotEmpty) {
      await prefs.setString('${role}_location_label', label.trim());
    }
  }

  static double? _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}');
  }

  // Get all trips
  static Future<List<dynamic>> getTrips(String uid) async {
    try {
      final token = await getAuthToken();
      final response = await http.get(
        Uri.parse('$baseUrl/trips/$uid'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get trips');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Get open jobs/loads
  static Future<List<dynamic>> getJobs({
    String? state,
    String? city,
    String? district,
    String? vehicleType,
  }) async {
    try {
      final token = await getAuthToken();
      final query = <String, String>{
        if (state != null && state.trim().isNotEmpty) 'state': state.trim(),
        if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
        if (district != null && district.trim().isNotEmpty)
          'district': district.trim(),
        if (vehicleType != null && vehicleType.trim().isNotEmpty)
          'vehicle_type': vehicleType.trim(),
      };
      final uri = Uri.parse('$baseUrl/jobs/').replace(queryParameters: query);
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get jobs: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Create customer load request as an open job for drivers
  static Future<Map<String, dynamic>> createJob(
    Map<String, dynamic> data,
  ) async {
    try {
      final token = await getAuthToken();
      final response = await http
          .post(
            Uri.parse('$baseUrl/jobs/'),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to create job: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static Future<Map<String, dynamic>> getJob(String jobId) async {
    try {
      final token = await getAuthToken();
      final response = await http.get(
        Uri.parse('$baseUrl/jobs/$jobId'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get job: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static Future<List<PlaceSuggestion>> autocompletePlaces(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.length < 3) return [];
    try {
      final token = await getAuthToken();
      final uri = Uri.parse('$baseUrl/places/autocomplete').replace(
        queryParameters: {'query': trimmedQuery},
      );
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is! List) return [];
        return data
            .whereType<Map>()
            .map((item) => PlaceSuggestion.fromJson(
                  Map<String, dynamic>.from(item),
                ))
            .where((place) => place.displayName.trim().isNotEmpty)
            .toList();
      } else {
        throw Exception(_errorMessage(
          response.body,
          fallback: 'Location autocomplete failed',
        ));
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static Future<PlaceSuggestion> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final token = await getAuthToken();
      final uri = Uri.parse('$baseUrl/places/reverse').replace(
        queryParameters: {
          'latitude': '$latitude',
          'longitude': '$longitude',
        },
      );
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return PlaceSuggestion.fromJson(Map<String, dynamic>.from(data));
      } else {
        throw Exception(_errorMessage(
          response.body,
          fallback: 'Location lookup failed',
        ));
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static Future<RideEstimate> estimateRide({
    required PlaceSuggestion pickup,
    required PlaceSuggestion drop,
    required String vehicleType,
    required String schedule,
  }) async {
    try {
      final token = await getAuthToken();
      final response = await http.post(
        Uri.parse('$baseUrl/quotes/estimate'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'pickup': _placePayload(pickup),
          'drop': _placePayload(drop),
          'vehicle_type': vehicleType,
          'schedule': schedule,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return RideEstimate.fromJson(Map<String, dynamic>.from(data));
      } else {
        throw Exception(_errorMessage(
          response.body,
          fallback: 'Failed to estimate ride',
        ));
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static Map<String, dynamic> _placePayload(PlaceSuggestion place) {
    return {
      'display_name': place.displayName,
      'latitude': place.latitude,
      'longitude': place.longitude,
      'city': place.city,
      'district': place.district,
      'state': place.state,
    };
  }

  static Future<Map<String, dynamic>> getDriverLocation(String uid) async {
    try {
      final token = await getAuthToken();
      final response = await http.get(
        Uri.parse('$baseUrl/location/$uid'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data.containsKey('latitude') && data.containsKey('longitude')) {
          await cacheLocation(
            role: 'driver',
            latitude: data['latitude'],
            longitude: data['longitude'],
            isActive: data['is_active'],
          );
        }
        return data;
      } else {
        throw Exception('Failed to get location: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static Future<void> updateDriverStatus(String uid, bool isActive) async {
    final prefs = await SharedPreferences.getInstance();
    var latitude = prefs.getDouble('driver_latitude');
    var longitude = prefs.getDouble('driver_longitude');

    if (latitude == null || longitude == null) {
      final location = await getDriverLocation(uid);
      latitude = _toDouble(location['latitude']);
      longitude = _toDouble(location['longitude']);
    }

    if (latitude == null || longitude == null) {
      throw Exception('Driver location is not set');
    }

    await updateLocation(uid, {
      'latitude': latitude,
      'longitude': longitude,
      'is_active': isActive,
    });
  }

  // Accept a job/load and create a trip
  static Future<Map<String, dynamic>> acceptJob(
      String uid, String jobId) async {
    try {
      final token = await getAuthToken();
      final response = await http.post(
        Uri.parse('$baseUrl/jobs/$jobId/accept/$uid'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(_errorMessage(
          response.body,
          fallback: 'Failed to accept job',
        ));
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static Future<void> cacheDriverActiveJob(Map<String, dynamic> job) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('driver_active_job', jsonEncode(job));
  }

  static Future<void> clearDriverActiveJob() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('driver_active_job');
  }

  static Future<Map<String, dynamic>?> getDriverActiveJob(String uid) async {
    try {
      final token = await getAuthToken();
      final response = await http.get(
        Uri.parse('$baseUrl/jobs/driver/$uid/active'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is! Map<String, dynamic>) return null;
        final job = data['job'];
        if (job is Map) {
          final activeJob = Map<String, dynamic>.from(job);
          final trip = data['trip'];
          if (trip is Map && trip['trip_id'] != null) {
            activeJob['trip_id'] = trip['trip_id'];
          }
          await cacheDriverActiveJob(activeJob);
          return activeJob;
        }
        await clearDriverActiveJob();
        return null;
      } else {
        throw Exception('Failed to get active job: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Update location
  static Future<void> updateLocation(
      String uid, Map<String, dynamic> location) async {
    await cacheLocation(
      role: 'driver',
      latitude: location['latitude'],
      longitude: location['longitude'],
      isActive: location['is_active'],
    );

    try {
      final token = await getAuthToken();
      final response = await http
          .post(
            Uri.parse('$baseUrl/location/update?uid=$uid'),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode(location),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Failed to update location: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Get available vehicles
  static Future<List<dynamic>> getVehicles() async {
    try {
      final token = await getAuthToken();
      final response = await http.get(
        Uri.parse('$baseUrl/vehicles/'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get vehicles');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Assign vehicle to driver
  static Future<void> assignVehicle(String uid, String vehicleNumber) async {
    try {
      final token = await getAuthToken();
      final uri = Uri.parse('$baseUrl/vehicles/$uid/assign').replace(
        queryParameters: {'vehicle_number': vehicleNumber},
      );
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Failed to assign vehicle: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Save driver preferences
  static Future<void> updatePreferences(
    String uid,
    List<String> preferredStates, {
    String? preferredVehicleType,
  }) async {
    try {
      final token = await getAuthToken();
      final body = <String, dynamic>{
        'preferred_states': preferredStates,
        if (preferredVehicleType != null)
          'preferred_vehicle_type': preferredVehicleType,
      };
      final response = await http
          .put(
            Uri.parse('$baseUrl/preferences/$uid'),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Failed to save preferences: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Upload driver license document
  static Future<void> uploadDocument(
    String uid, {
    required String filePath,
    required String filename,
  }) async {
    try {
      final token = await getAuthToken();
      final uri = Uri.parse('$baseUrl/documents/upload').replace(
        queryParameters: {
          'uid': uid,
          'doc_type': 'license',
        },
      );
      final request = http.MultipartRequest('POST', uri);
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          filePath,
          filename: filename,
        ),
      );

      final streamedResponse = await request.send().timeout(
            const Duration(seconds: 20),
          );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        throw Exception('Failed to upload document: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Logout
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('uid');
    await prefs.remove('selected_role');
    await prefs.remove('role_sync_pending');
    await prefs.remove('customer_name');
    await prefs.remove('customer_email');
    await prefs.remove('customer_latitude');
    await prefs.remove('customer_longitude');
    await prefs.remove('customer_location_label');
    await prefs.remove('customer_profile_sync_pending');
    await prefs.remove('active_booking');
    await prefs.remove('last_latitude');
    await prefs.remove('last_longitude');
    await prefs.remove('user_latitude');
    await prefs.remove('user_longitude');
    await prefs.remove('user_location_label');
    await prefs.remove('driver_name');
    await prefs.remove('driver_vehicle_number');
    await prefs.remove('driver_latitude');
    await prefs.remove('driver_longitude');
    await prefs.remove('driver_location_label');
    await prefs.remove('driver_is_active');
    await prefs.remove('driver_active_job');
  }

  static Future<String?> getUid() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('uid');
  }
}
