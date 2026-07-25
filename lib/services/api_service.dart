import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:loadr/models/place_suggestion.dart';
import 'package:loadr/models/ride_quote.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiUnauthorizedException implements Exception {
  const ApiUnauthorizedException();
}

class ApiService {
  static const String _apiBaseUrlOverride =
      String.fromEnvironment('API_BASE_URL');
  static const String _authTokenKey = 'auth_token';
  static const _secureStorage = FlutterSecureStorage();
  static bool _isLoggingOut = false;

  static bool get isLoggingOut => _isLoggingOut;

  static String get baseUrl {
    final configuredUrl = _apiBaseUrlOverride.trim();
    if (configuredUrl.isNotEmpty) {
      final uri = Uri.tryParse(configuredUrl);
      if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
        throw StateError('API_BASE_URL must be an absolute URL');
      }
      if (kReleaseMode && uri.scheme != 'https') {
        throw StateError('A release build requires an HTTPS API_BASE_URL');
      }
      return configuredUrl.replaceFirst(RegExp(r'/$'), '');
    }

    if (kReleaseMode) {
      throw StateError('A release build requires API_BASE_URL');
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api';
    }

    return 'http://localhost:8000/api';
  }

  static String get mapTileUrlTemplate {
    return '$baseUrl/map/geoapify/osm-bright-smooth/{z}/{x}/{y}{r}.png';
  }

  static Future<Object?> _readJsonCache(String key, Duration maxAge) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.trim().isEmpty) return null;

    try {
      final wrapper = jsonDecode(raw);
      if (wrapper is! Map) return null;
      final savedAt = DateTime.tryParse('${wrapper['saved_at'] ?? ''}');
      if (savedAt == null || DateTime.now().difference(savedAt) > maxAge) {
        return null;
      }
      return wrapper['value'];
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writeJsonCache(String key, Object value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      key,
      jsonEncode({
        'saved_at': DateTime.now().toIso8601String(),
        'value': value,
      }),
    );
  }

  // Sign in with email OTP
  static Future<Map<String, dynamic>> signIn(
    String email, {
    String? phone,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/signin'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              if (phone != null && phone.trim().isNotEmpty)
                'phone': phone.trim(),
            }),
          )
          .timeout(const Duration(seconds: 35));

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
    String email,
    String otp, {
    String? phone,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/verify-otp'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'otp': otp,
              if (phone != null && phone.trim().isNotEmpty)
                'phone': phone.trim(),
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is! Map) throw Exception('Invalid sign-in response');
        final authData = Map<String, dynamic>.from(data);
        final token = '${authData['token'] ?? ''}'.trim();
        final uid = '${authData['uid'] ?? ''}'.trim();
        if (token.isEmpty || uid.isEmpty) {
          throw Exception('Invalid sign-in response');
        }

        _isLoggingOut = false;
        final prefs = await SharedPreferences.getInstance();
        await _secureStorage.write(key: _authTokenKey, value: token);
        await prefs.remove(_authTokenKey);
        await prefs.setString('uid', uid);
        await prefs.setString('auth_email', email);
        if (phone != null && phone.trim().isNotEmpty) {
          await prefs.setString('auth_phone', phone.trim());
        }
        return authData;
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

  static Future<Map<String, dynamic>?> getUserState(String uid) async {
    try {
      final token = await getAuthToken();
      final response = await http.get(
        Uri.parse('$baseUrl/users/$uid'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map) {
          final profile = Map<String, dynamic>.from(data);
          await cacheUserState(profile);
          return profile;
        }
        return null;
      }

      if (response.statusCode == 404) return null;
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const ApiUnauthorizedException();
      }
      throw Exception(_errorMessage(
        response.body,
        fallback: 'Failed to get user profile',
      ));
    } on ApiUnauthorizedException {
      rethrow;
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static Future<void> cacheUserState(Map<String, dynamic> profile) async {
    final prefs = await SharedPreferences.getInstance();
    final role = '${profile['role'] ?? ''}'.trim();
    if (role == 'user' || role == 'driver') {
      await prefs.setString('selected_role', role);
      await prefs.remove('role_sync_pending');
    }

    final name = '${profile['name'] ?? ''}'.trim();
    final email = '${profile['email'] ?? ''}'.trim();
    final phone = '${profile['phone'] ?? ''}'.trim();
    if (phone.isNotEmpty) await prefs.setString('auth_phone', phone);
    if (role == 'user') {
      if (name.isNotEmpty) await prefs.setString('customer_name', name);
      if (email.isNotEmpty) await prefs.setString('customer_email', email);
      final customerProfile = profile['customer_profile'];
      if (customerProfile is Map) {
        final location = customerProfile['current_location'];
        if (location is Map) {
          await cacheLocation(
            role: 'customer',
            latitude: location['latitude'],
            longitude: location['longitude'],
          );
        }
      }
    } else if (role == 'driver') {
      if (name.isNotEmpty) await prefs.setString('driver_name', name);
      final driverProfile = profile['driver_profile'];
      if (driverProfile is Map) {
        await cacheDriverProfile({
          ...profile,
          ...Map<String, dynamic>.from(driverProfile),
        });
      } else {
        await cacheDriverProfile(profile);
      }
    }
  }

  static Future<String> resolveRouteAfterAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('uid');
    if (uid != null && uid.trim().isNotEmpty) {
      try {
        await getUserState(uid);
      } catch (_) {
        // Fall back to the last cached local state.
      }
    }

    final role = prefs.getString('selected_role');
    if (role == null || role.isEmpty) return '/role-selection';

    if (role == 'user') {
      final hasProfile = (prefs.getString('customer_name') ?? '').isNotEmpty &&
          !(prefs.getBool('customer_profile_sync_pending') ?? false);
      return hasProfile ? '/customer-home' : '/customer-details';
    }

    final hasDriverProfile =
        (prefs.getString('driver_name') ?? '').isNotEmpty &&
            (prefs.getString('driver_vehicle_number') ?? '').isNotEmpty;
    if (hasDriverProfile) return '/dashboard';

    final hasDriverLocation = prefs.getDouble('driver_latitude') != null &&
        prefs.getDouble('driver_longitude') != null;
    return hasDriverLocation ? '/driver-details' : '/location';
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
    final storedToken = await _secureStorage.read(key: _authTokenKey);
    if (storedToken != null && storedToken.trim().isNotEmpty) {
      return storedToken;
    }

    final prefs = await SharedPreferences.getInstance();
    final legacyToken = prefs.getString(_authTokenKey);
    if (legacyToken == null || legacyToken.trim().isEmpty) return null;

    await _secureStorage.write(key: _authTokenKey, value: legacyToken);
    await prefs.remove(_authTokenKey);
    return legacyToken;
  }

  static Future<String?> getAuthEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_email') ?? prefs.getString('customer_email');
  }

  static Future<String> _requireAuthToken() async {
    if (_isLoggingOut) throw Exception('Not signed in');
    final token = await getAuthToken();
    if (token == null || token.trim().isEmpty) {
      throw Exception('Not signed in');
    }
    return token;
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
    final token = await _requireAuthToken();

    final response = await http
        .put(
          Uri.parse('$baseUrl/drivers/$uid'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(data),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception(response.body);
    }
    await cacheDriverProfile(data);
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
    if (_isLoggingOut) return [];
    final token = await getAuthToken();
    if (token == null || token.trim().isEmpty) return [];

    try {
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
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return _openJobsOnly(data);
        }
        return [];
      } else {
        throw Exception('Failed to get jobs: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static List<dynamic> _openJobsOnly(List<dynamic> jobs) {
    return jobs.where((job) {
      if (job is! Map) return false;
      return '${job['status'] ?? ''}'.trim().toLowerCase() == 'open';
    }).toList();
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

  static Future<void> cancelJob(String jobId) async {
    try {
      final token = await getAuthToken();
      final response = await http.patch(
        Uri.parse('$baseUrl/jobs/$jobId/cancel'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        await clearCustomerActiveBooking();
        return;
      }
      throw Exception(_errorMessage(
        response.body,
        fallback: 'Failed to cancel pickup',
      ));
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static Future<Map<String, dynamic>?> getCustomerActiveJob(
    String uid, {
    String? jobId,
  }) async {
    try {
      final token = await getAuthToken();
      final uri = Uri.parse('$baseUrl/jobs/customer/$uid/active').replace(
        queryParameters: {
          if (jobId != null && jobId.trim().isNotEmpty) 'job_id': jobId.trim(),
        },
      );
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception(_errorMessage(
          response.body,
          fallback: 'Failed to get active booking',
        ));
      }

      final data = jsonDecode(response.body);
      final job = data is Map ? data['job'] : null;
      if (job is Map) {
        final activeJob = Map<String, dynamic>.from(job);
        await cacheCustomerActiveBooking(activeJob);
        return activeJob;
      }
      await clearCustomerActiveBooking();
      return null;
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getCustomerActiveJobs(
    String uid,
  ) async {
    try {
      final token = await getAuthToken();
      final response = await http.get(
        Uri.parse('$baseUrl/jobs/customer/$uid/active'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception(_errorMessage(
          response.body,
          fallback: 'Failed to get active bookings',
        ));
      }

      final data = jsonDecode(response.body);
      final jobs = data is Map ? data['jobs'] : null;
      if (jobs is List) {
        return jobs
            .whereType<Map>()
            .map((job) => Map<String, dynamic>.from(job))
            .toList();
      }

      final job = data is Map ? data['job'] : null;
      if (job is Map) return [Map<String, dynamic>.from(job)];
      return [];
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static Stream<Map<String, dynamic>?> streamCustomerActiveJob(
    String uid, {
    String? jobId,
  }) async* {
    final client = http.Client();
    try {
      final token = await getAuthToken();
      final uri =
          Uri.parse('$baseUrl/jobs/customer/$uid/active/stream').replace(
        queryParameters: {
          if (jobId != null && jobId.trim().isNotEmpty) 'job_id': jobId.trim(),
        },
      );
      final request = http.Request(
        'GET',
        uri,
      );
      request.headers.addAll({
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      });

      final response = await client.send(request).timeout(
            const Duration(seconds: 10),
          );
      if (response.statusCode != 200) {
        throw Exception('Active booking stream failed');
      }

      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (!line.startsWith('data:')) continue;
        final payload = line.substring(5).trim();
        if (payload.isEmpty) continue;

        final data = jsonDecode(payload);
        final job = data is Map ? data['job'] : null;
        if (job is Map) {
          final activeJob = Map<String, dynamic>.from(job);
          yield activeJob;
        } else {
          await clearCustomerActiveBooking();
          yield null;
        }
      }
    } finally {
      client.close();
    }
  }

  static Future<List<Map<String, dynamic>>> getNearbyDrivers({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final token = await getAuthToken();
      final uri = Uri.parse('$baseUrl/location/nearby').replace(
        queryParameters: {
          'latitude': '$latitude',
          'longitude': '$longitude',
          'radius_km': '8',
        },
      );
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body);
      if (data is! List) return [];
      return data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> cacheCustomerActiveBooking(
    Map<String, dynamic> booking,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_booking', jsonEncode(booking));
  }

  static Future<void> clearCustomerActiveBooking() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_booking');
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
    bool useCache = true,
  }) async {
    final cacheKey = 'estimate_v5_${pickup.latitude.toStringAsFixed(5)}_'
        '${pickup.longitude.toStringAsFixed(5)}_'
        '${drop.latitude.toStringAsFixed(5)}_'
        '${drop.longitude.toStringAsFixed(5)}_${vehicleType}_$schedule';
    if (useCache) {
      final cached =
          await _readJsonCache(cacheKey, const Duration(minutes: 15));
      if (cached is Map) {
        final estimate =
            RideEstimate.fromJson(Map<String, dynamic>.from(cached));
        if (estimate.routePoints.length > 2) return estimate;
      }
    }

    try {
      final token = await getAuthToken();
      final response = await http
          .post(
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
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map) {
          final estimateJson = Map<String, dynamic>.from(data);
          if (useCache) await _writeJsonCache(cacheKey, estimateJson);
          return RideEstimate.fromJson(estimateJson);
        }
        throw Exception('Invalid estimate response');
      } else {
        throw Exception(_errorMessage(
          response.body,
          fallback: 'Failed to estimate ride',
        ));
      }
    } catch (e) {
      if (useCache) {
        final stale = await _readJsonCache(cacheKey, const Duration(days: 1));
        if (stale is Map) {
          final estimate =
              RideEstimate.fromJson(Map<String, dynamic>.from(stale));
          if (estimate.routePoints.length > 2) return estimate;
        }
      }
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
      final token = await _requireAuthToken();
      final response = await http.get(
        Uri.parse('$baseUrl/location/$uid'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
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
    if (_isLoggingOut) return;
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
      ).timeout(const Duration(seconds: 30));

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
      final token = await _requireAuthToken();
      final response = await http.get(
        Uri.parse('$baseUrl/jobs/driver/$uid/active'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
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

  static Stream<Map<String, dynamic>?> streamDriverActiveJob(
      String uid) async* {
    final client = http.Client();
    try {
      final token = await _requireAuthToken();
      final request = http.Request(
        'GET',
        Uri.parse('$baseUrl/jobs/driver/$uid/active/stream'),
      );
      request.headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      });

      final response = await client.send(request).timeout(
            const Duration(seconds: 10),
          );
      if (response.statusCode != 200) {
        throw Exception('Active trip stream failed');
      }

      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (!line.startsWith('data:')) continue;
        final payload = line.substring(5).trim();
        if (payload.isEmpty) continue;

        final data = jsonDecode(payload);
        final job = data is Map ? data['job'] : null;
        if (job is Map) {
          final activeJob = Map<String, dynamic>.from(job);
          final trip = data['trip'];
          if (trip is Map && trip['trip_id'] != null) {
            activeJob['trip_id'] = trip['trip_id'];
          }
          await cacheDriverActiveJob(activeJob);
          yield activeJob;
        } else {
          await clearDriverActiveJob();
          yield null;
        }
      }
    } finally {
      client.close();
    }
  }

  static Future<Map<String, dynamic>> updateTripStatus(
    String tripId,
    String status,
  ) async {
    try {
      final token = await getAuthToken();
      final uri = Uri.parse('$baseUrl/trips/trip/$tripId/status').replace(
        queryParameters: {'status': status},
      );
      final response = await http.patch(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception(_errorMessage(
        response.body,
        fallback: 'Failed to update trip',
      ));
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Update location
  static Future<void> updateLocation(
      String uid, Map<String, dynamic> location) async {
    if (_isLoggingOut) return;
    await cacheLocation(
      role: 'driver',
      latitude: location['latitude'],
      longitude: location['longitude'],
      isActive: location['is_active'],
    );

    try {
      final token = await _requireAuthToken();
      final response = await http
          .post(
            Uri.parse('$baseUrl/location/update?uid=$uid'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
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
    const cacheKey = 'vehicles_v2';
    final cached = await _readJsonCache(cacheKey, const Duration(days: 1));
    if (cached is List) return cached;

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
        final data = jsonDecode(response.body);
        if (data is List) {
          await _writeJsonCache(cacheKey, data);
          return data;
        }
        return [];
      } else {
        throw Exception('Failed to get vehicles');
      }
    } catch (e) {
      final stale = await _readJsonCache(cacheKey, const Duration(days: 30));
      if (stale is List) return stale;
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
    _isLoggingOut = true;
    await _secureStorage.delete(key: _authTokenKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  static Future<String?> getUid() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('uid');
  }
}
