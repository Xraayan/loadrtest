import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // static const String baseUrl = 'http://localhost:8000/api';
  static const String baseUrl =
      'https://harmonize-curliness-apple.ngrok-free.dev/api';

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
  // static Future<void> updateDriverProfile(
  //     String uid, Map<String, dynamic> data) async {
  //   try {
  //     final token = await getAuthToken();
  //     final response = await http
  //         .put(
  //           Uri.parse('$baseUrl/drivers/$uid'),
  //           headers: {
  //             'Content-Type': 'application/json',
  //             if (token != null) 'Authorization': 'Bearer $token',
  //           },
  //           body: jsonEncode(data),
  //         )
  //         .timeout(const Duration(seconds: 10));
  //     if (response.statusCode != 200) {
  //       throw Exception('Failed to update profile');
  //     }
  //   } catch (e) {
  //     throw Exception('Error: $e');
  //   }
  // }

  static Future<void> updateDriverProfile(
    String uid,
    Map<String, dynamic> data,
  ) async {
    final token = await getAuthToken();

    final response = await http.put(
      Uri.parse('$baseUrl/drivers/$uid'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );

    print('Status: ${response.statusCode}');
    print('Body: ${response.body}');

    if (response.statusCode != 200) {
      throw Exception(response.body);
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

  // Logout
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('uid');
  }

  static Future<String?> getUid() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('uid');
  }
}
