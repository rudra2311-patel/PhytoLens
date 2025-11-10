import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  // 🔒 Secure storage instance (only one)
  static const _storage = FlutterSecureStorage();

  // 💾 Save both tokens securely
  static Future<void> saveTokens(String accessToken, String refreshToken) async {
    await _storage.write(key: "access_token", value: accessToken);
    await _storage.write(key: "refresh_token", value: refreshToken);
    final storedAccess = await AuthService.getAccessToken();
final storedRefresh = await AuthService.getRefreshToken();
print("STORED ACCESS TOKEN: $storedAccess");
print("STORED REFRESH TOKEN: $storedRefresh");    
  }
  // 🔑 Get stored access token
  static Future<String?> getAccessToken() async {
    return await _storage.read(key: "access_token");
  }

  // 🔑 Get stored refresh token
  static Future<String?> getRefreshToken() async {
    return await _storage.read(key: "refresh_token");
  }

  // 🚪 Logout (delete all tokens)
  static Future<void> logout() async {
    await _storage.deleteAll();
  }

  // ✅ Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null;
  }
}
