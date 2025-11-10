import 'dart:convert';
import 'package:agriscan_pro/services/auth_services.dart';
import 'package:http/http.dart' as http;

class ApiService {
  // make sure this URL points to your FastAPI signup route
  static const String baseUrl = "http://10.0.2.2:8000/apiv1/auth";

  // ✅ updated signup request to match backend
  static Future<Map<String, dynamic>> signup({
    required String firstName,
    required String lastName,
    required String username,
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/signup"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "first_name": firstName,
        "last_name": lastName,
        "username": username,
        "email": email,
        "password": password,
      }),
    );

    // handle backend responses
    if (response.statusCode == 201) {
      // ✅ signup successful
      return jsonDecode(response.body);
    } else if (response.statusCode == 400) {
      // backend returns 400 if user already exists
      throw Exception("User with this email already exists.");
    } else {
      throw Exception(
        "Signup failed: ${response.statusCode} → ${response.body}",
      );
    }
  }

  // (keep your login, refresh-token, logout methods here)
   static Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse("$baseUrl/login"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "email": email,
        "password": password,
      }),
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      print("ACCESS TOKEN: ${responseData['access_token']}");
      print("REFRESH TOKEN: ${responseData['refresh_token']}");
      return responseData;
    } else {
      throw Exception("Invalid credentials: ${response.body}");
    }
  }
    /// 🚀 Logout User — invalidates refresh token from Redis
 static Future<void> logoutUser() async {
  final refreshToken = await AuthService.getRefreshToken(); // ✅ use refresh token
  final response = await http.post(
    Uri.parse('$baseUrl/logout'),
    headers: {
      'Authorization': 'Bearer $refreshToken', // ✅ refresh token here
    },
  );

  if (response.statusCode != 200) {
    throw Exception("Logout failed: ${response.body}");
  }
}

}
