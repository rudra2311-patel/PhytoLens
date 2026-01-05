import 'package:agriscan_pro/screens/auth/auth_check_widget.dart';
import 'package:agriscan_pro/screens/auth/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/sign_up_screen.dart';
import 'core/theme/app_theme.dart';
import 'services/fcm_service.dart';

// Global key for showing in-app notifications
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  try {
    await Firebase.initializeApp();
    debugPrint('🔥 Firebase initialized');

    // Initialize FCM
    await FCMService().initialize();
    debugPrint('📱 FCM initialized');
  } catch (e) {
    debugPrint('❌ Firebase/FCM initialization failed: $e');
  }

  // Lock app in portrait mode
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const PhytoLensApp());
}

class PhytoLensApp extends StatelessWidget {
  const PhytoLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AgriScan Pro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      scaffoldMessengerKey: scaffoldMessengerKey,

      // Start with splash screen
      home: const SplashScreen(),

      // Define routes
      routes: {
        '/auth-check': (context) => const AuthCheckScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignUpScreen(),
      },
    );
  }
}
