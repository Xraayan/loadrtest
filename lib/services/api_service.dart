import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://10.0.2.2:8000/api';

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
        throw Exception('Invalid OTP: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
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
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get profile');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Update driver profile
  static Future<void> updateDriverProfile(
      String uid, Map<String, dynamic> data) async {
    try {
      final token = await getAuthToken();
      final response = await http
          .put(
            Uri.parse('$baseUrl/drivers/$uid'),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Failed to update profile');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
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
    String? vehicleType,
  }) async {
    try {
      final token = await getAuthToken();
      final query = <String, String>{
        if (state != null && state.trim().isNotEmpty) 'state': state.trim(),
        if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
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
        throw Exception('Failed to accept job: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Get ledger summary
  static Future<Map<String, dynamic>> getLedger(String uid) async {
    try {
      final token = await getAuthToken();
      final response = await http.get(
        Uri.parse('$baseUrl/ledger/$uid'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get ledger: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Update location
  static Future<void> updateLocation(
      String uid, Map<String, dynamic> location) async {
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
        throw Exception('Failed to update location');
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
  }
}
