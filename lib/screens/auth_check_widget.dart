import 'package:agriscan_pro/services/auth_services.dart';
import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({super.key});

  @override
  State<AuthCheckScreen> createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  late Future<bool> _isLoggedInFuture;

  @override
  void initState() {
    super.initState();

    // 👇 load and print stored tokens for debugging
    _printStoredTokens();

    // normal login check
    _isLoggedInFuture = AuthService.isLoggedIn();
  }

  // 🔍 Debugging function to print stored tokens
  Future<void> _printStoredTokens() async {
    final storedAccess = await AuthService.getAccessToken();
    final storedRefresh = await AuthService.getRefreshToken();

    if (storedAccess != null && storedRefresh != null) {
      print("✅ STORED ACCESS TOKEN: $storedAccess");
      print("✅ STORED REFRESH TOKEN: $storedRefresh");
    } else {
      print("⚠️ No tokens found in secure storage.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isLoggedInFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text("Error: ${snapshot.error}")),
          );
        }

        // ✅ if logged in → go to home
        // ❌ else → show login screen
        final loggedIn = snapshot.data ?? false;
        return loggedIn ? const HomeScreen() : const LoginScreen();
      },
    );
  }
}
