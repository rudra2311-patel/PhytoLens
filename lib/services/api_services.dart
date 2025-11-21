import 'dart:convert';
import 'package:agriscan_pro/services/auth_services.dart';
import 'package:http/http.dart' as http;

class ApiService {
  // Base URL for auth & scans
  static const String baseUrl = "http://10.0.2.2:8000/api/v1";

  // -------------------- AUTH SECTION -------------------- //

  // Signup
  static Future<Map<String, dynamic>> signup({
    required String firstName,
    required String lastName,
    required String username,
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/auth/signup"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "first_name": firstName,
        "last_name": lastName,
        "username": username,
        "email": email,
        "password": password,
      }),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 400) {
      throw Exception("User with this email already exists.");
    } else {
      throw Exception(
        "Signup failed: ${response.statusCode} → ${response.body}",
      );
    }
  }

  // Login
  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse("$baseUrl/auth/login"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "password": password}),
    );

    if (response.statusCode == 200) {
      final res = jsonDecode(response.body);
      print("ACCESS TOKEN: ${res['access_token']}");
      print("REFRESH TOKEN: ${res['refresh_token']}");
      return res;
    } else {
      throw Exception("Invalid credentials: ${response.body}");
    }
  }

  // Logout
  static Future<void> logoutUser() async {
    final refreshToken = await AuthService.getRefreshToken();

    final response = await http.post(
      Uri.parse('$baseUrl/auth/logout'),
      headers: {'Authorization': 'Bearer $refreshToken'},
    );

    if (response.statusCode != 200) {
      throw Exception("Logout failed: ${response.body}");
    }
  }

  // Get User Profile
  static Future<Map<String, dynamic>> getUserProfile() async {
    final accessToken = await AuthService.getAccessToken();
    if (accessToken == null) throw Exception('No access token found');

    final response = await http.get(
      Uri.parse('$baseUrl/auth/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized - Please login again');
    } else {
      throw Exception('Failed to fetch profile: ${response.body}');
    }
  }

  // -------------------- SCAN FEATURE SECTION -------------------- //

  // Upload Scan
  static Future<Map<String, dynamic>> uploadScan({
    required String diseaseName,
    required double confidence,
    required String imageBase64,
  }) async {
    final accessToken = await AuthService.getAccessToken();
    if (accessToken == null) throw Exception('No access token found');

    final response = await http.post(
      Uri.parse('$baseUrl/scans/scans/upload'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'disease_name': diseaseName,
        'confidence': confidence,
        'image_base64': imageBase64,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to upload scan: ${response.body}');
    }
  }

  // Get Scan History
  static Future<List<Map<String, dynamic>>> getScanHistory() async {
    final accessToken = await AuthService.getAccessToken();
    if (accessToken == null) throw Exception('No access token found');

    final response = await http.get(
      Uri.parse('$baseUrl/scans/scans/history'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized - Please login again');
    } else {
      throw Exception('Failed to fetch scan history: ${response.body}');
    }
  }

  // Delete Single Scan
  static Future<bool> deleteScan(String scanId) async {
    final accessToken = await AuthService.getAccessToken();
    if (accessToken == null) throw Exception('No access token found');

    final response = await http.delete(
      Uri.parse('$baseUrl/scans/scans/$scanId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      return true;
    } else if (response.statusCode == 404) {
      throw Exception('Scan not found or unauthorized');
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized - Please login again');
    } else {
      throw Exception('Failed to delete scan: ${response.body}');
    }
  }

  // Clear All Scan History
  static Future<int> clearScanHistory() async {
    final accessToken = await AuthService.getAccessToken();
    if (accessToken == null) throw Exception('No access token found');

    final response = await http.delete(
      Uri.parse('$baseUrl/scans/scans/history/clear'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['deleted_count'] ?? 0;
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized - Please login again');
    } else {
      throw Exception('Failed to clear history: ${response.body}');
    }
  }

  // -------------------- FARMS SECTION -------------------- //

  // Add Farm
  static Future<Map<String, dynamic>> addFarm({
    required double lat,
    required double lon,
    required String crop,
  }) async {
    final accessToken = await AuthService.getAccessToken();
    if (accessToken == null) throw Exception('No access token found');

    final response = await http.post(
      Uri.parse('$baseUrl/farms/add'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({'lat': lat, 'lon': lon, 'crop': crop}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized - Please login again');
    } else {
      throw Exception('Failed to add farm: ${response.body}');
    }
  }

  // Get My Farms
  static Future<List<Map<String, dynamic>>> getMyFarms() async {
    final accessToken = await AuthService.getAccessToken();
    if (accessToken == null) throw Exception('No access token found');

    final response = await http.get(
      Uri.parse('$baseUrl/farms/my'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized - Please login again');
    } else {
      throw Exception('Failed to fetch farms: ${response.body}');
    }
  }

  // Delete Farm
  static Future<bool> deleteFarmFromBackend(String farmId) async {
    final accessToken = await AuthService.getAccessToken();
    if (accessToken == null) throw Exception('No access token found');

    final response = await http.delete(
      Uri.parse('$baseUrl/farms/$farmId'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      return true;
    } else if (response.statusCode == 404) {
      throw Exception('Farm not found');
    } else if (response.statusCode == 403) {
      throw Exception('Not authorized to delete this farm');
    } else {
      throw Exception('Failed to delete farm: ${response.body}');
    }
  }

  // -------------------- WEATHER SECTION -------------------- //

  // Get Current Weather
  static Future<Map<String, dynamic>> getCurrentWeather({
    required double lat,
    required double lon,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/weather/current?lat=$lat&lon=$lon'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch weather: ${response.body}');
    }
  }

  // Get Weather Risk Assessment
  static Future<Map<String, dynamic>> getWeatherRisk({
    required double lat,
    required double lon,
    required String crop,
  }) async {
    final accessToken = await AuthService.getAccessToken();

    if (accessToken == null) {
      throw Exception('Not authenticated. Please login again.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/weather/risk?lat=$lat&lon=$lon&crop=$crop'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch weather risk: ${response.body}');
    }
  }
}
