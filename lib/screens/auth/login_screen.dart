import 'package:agriscan_pro/services/api_services.dart';
import 'package:agriscan_pro/services/auth_services.dart';
import 'package:agriscan_pro/services/farm_database_helper.dart';
import 'package:agriscan_pro/services/fcm_service.dart';
import 'package:agriscan_pro/models/farm_model.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  /// Sync farms from backend to local database after login
  Future<void> _syncFarmsFromBackend() async {
    try {
      debugPrint('🔄 Syncing farms from backend...');

      // Fetch farms from backend
      final backendFarms = await ApiService.getMyFarms();
      debugPrint('📥 Fetched ${backendFarms.length} farms from backend');

      // Get current user ID
      final userId = await AuthService.getUserId();
      if (userId == null) {
        debugPrint('⚠️ No user ID found, skipping farm sync');
        return;
      }

      // Save each farm to local database
      for (var farmData in backendFarms) {
        try {
          // Check if farm already exists in local DB
          final existingFarm = await FarmDatabaseHelper.instance
              .getFarmByBackendId(farmData['id'].toString());

          if (existingFarm == null) {
            // Create new farm in local DB
            final farm = Farm(
              backendId: farmData['id'].toString(),
              userId: userId,
              name: farmData['name'] ?? 'Farm',
              location: '${farmData['lat']}, ${farmData['lon']}',
              latitude: (farmData['lat'] as num).toDouble(),
              longitude: (farmData['lon'] as num).toDouble(),
              cropType: farmData['crop'] ?? 'Unknown',
              createdAt: DateTime.now(),
            );

            await FarmDatabaseHelper.instance.createFarm(farm);
            debugPrint('✅ Saved farm to local DB: ${farm.name}');
          } else {
            debugPrint('ℹ️ Farm already exists: ${existingFarm.name}');
          }
        } catch (e) {
          debugPrint('⚠️ Failed to save farm: $e');
        }
      }

      debugPrint('✅ Farm sync complete');
    } catch (e) {
      debugPrint('❌ Failed to sync farms from backend: $e');
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final result = await ApiService.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      final accessToken = result['access_token'];
      final refreshToken = result['refresh_token'];

      // 🔥 store tokens securely (frontend storage, not backend)
      await AuthService.saveTokens(accessToken, refreshToken);

      // 🔐 Extract and save user ID from login response
      // Backend returns user data in the response
      if (result['user'] != null && result['user']['user_id'] != null) {
        await AuthService.saveUserId(result['user']['user_id'].toString());
        debugPrint('✅ User ID saved: ${result['user']['user_id']}');
      } else {
        // Fallback: fetch user profile to get user_id
        try {
          final profile = await ApiService.getUserProfile();
          if (profile['user_id'] != null) {
            await AuthService.saveUserId(profile['user_id'].toString());
            debugPrint('✅ User ID saved from profile: ${profile['user_id']}');
          }
        } catch (e) {
          debugPrint('⚠️ Could not fetch user_id: $e');
        }
      }

      // 🌾 CRITICAL: Sync farms from backend to local database
      await _syncFarmsFromBackend();

      // 📱 CRITICAL: Send FCM token to backend after successful login
      try {
        await FCMService().updateFCMTokenOnBackend();
        debugPrint('✅ FCM token sent to backend after login');
      } catch (e) {
        debugPrint('⚠️ Failed to send FCM token after login: $e');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Login successful!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );

      // navigate to home screen
      Navigator.pushReplacementNamed(context, '/');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Login failed: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Animated Gradient Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F9D58), // Rich Green
                  Color(0xFF16A765), // Medium Green
                  Color(0xFF34A853), // Light Green
                  Color(0xFFB7E4C7), // Pale Green
                ],
                stops: [0.0, 0.3, 0.6, 1.0],
              ),
            ),
          ),

          // Decorative Circles
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF1E7F5C).withOpacity(0.15),
                    const Color(0xFF1E7F5C).withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -150,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF34A853).withOpacity(0.2),
                    const Color(0xFF34A853).withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),

          // Decorative Farm Icons - Top Right
          Positioned(
            top: 80,
            right: 40,
            child: Opacity(
              opacity: 0.1,
              child: Icon(Icons.eco_outlined, size: 60, color: Colors.white),
            ),
          ),
          Positioned(
            top: 140,
            right: 110,
            child: Opacity(
              opacity: 0.08,
              child: Icon(Icons.grass_outlined, size: 45, color: Colors.white),
            ),
          ),

          // Decorative Farm Icons - Bottom Left
          Positioned(
            bottom: 100,
            left: 30,
            child: Opacity(
              opacity: 0.1,
              child: Icon(
                Icons.agriculture_outlined,
                size: 55,
                color: Colors.white,
              ),
            ),
          ),
          Positioned(
            bottom: 160,
            left: 90,
            child: Opacity(
              opacity: 0.08,
              child: Icon(Icons.nature_outlined, size: 40, color: Colors.white),
            ),
          ),

          // Decorative Farm Icons - Middle Right
          Positioned(
            top: MediaQuery.of(context).size.height * 0.5,
            right: 20,
            child: Opacity(
              opacity: 0.07,
              child: Icon(
                Icons.local_florist_outlined,
                size: 35,
                color: Colors.white,
              ),
            ),
          ),

          // Main Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 40,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated Brand Mark
                    TweenAnimationBuilder(
                      duration: const Duration(milliseconds: 800),
                      tween: Tween<double>(begin: 0, end: 1),
                      builder: (context, double value, child) {
                        return Transform.scale(
                          scale: value,
                          child: Opacity(
                            opacity: value,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF1E7F5C,
                                    ).withOpacity(0.3),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.spa_outlined,
                                size: 40,
                                color: Color(0xFF1E7F5C),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 48),

                    // Animated Floating White Card
                    TweenAnimationBuilder(
                      duration: const Duration(milliseconds: 1000),
                      tween: Tween<double>(begin: 50, end: 0),
                      curve: Curves.easeOutCubic,
                      builder: (context, double value, child) {
                        return Transform.translate(
                          offset: Offset(0, value),
                          child: Opacity(
                            opacity: 1 - (value / 50),
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 440),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1E7F5C).withOpacity(0.15),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                              spreadRadius: 0,
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title
                              const Text(
                                "Welcome back",
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1F2933),
                                  letterSpacing: -0.5,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                "Sign in to continue",
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Color(0xFF6B7280),
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 40),

                              // Form
                              Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Email Label
                                    const Text(
                                      "Email",
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF1F2933),
                                        height: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    _buildModernTextField(
                                      controller: _emailController,
                                      hint: "you@example.com",
                                      keyboardType: TextInputType.emailAddress,
                                      validator: (val) => val!.contains("@")
                                          ? null
                                          : "Enter a valid email",
                                    ),
                                    const SizedBox(height: 24),

                                    // Password Label
                                    const Text(
                                      "Password",
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF1F2933),
                                        height: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    _buildModernTextField(
                                      controller: _passwordController,
                                      hint: "Enter your password",
                                      obscureText: _obscurePassword,
                                      validator: (val) => val!.length < 6
                                          ? "Min 6 chars"
                                          : null,
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                          size: 20,
                                        ),
                                        color: const Color(0xFF6B7280),
                                        onPressed: () {
                                          setState(
                                            () => _obscurePassword =
                                                !_obscurePassword,
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // Forgot Password
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: () {},
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          minimumSize: Size.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: const Text(
                                          "Forgot password?",
                                          style: TextStyle(
                                            color: Color(0xFF1E7F5C),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 32),

                                    // Login Button
                                    SizedBox(
                                      width: double.infinity,
                                      height: 56,
                                      child: ElevatedButton(
                                        onPressed: _isLoading ? null : _login,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF1E7F5C,
                                          ),
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          disabledBackgroundColor: const Color(
                                            0xFF1E7F5C,
                                          ).withOpacity(0.6),
                                        ),
                                        child: _isLoading
                                            ? const SizedBox(
                                                height: 20,
                                                width: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                      color: Colors.white,
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  const Text(
                                                    "Login",
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      letterSpacing: 0,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Icon(
                                                    Icons.arrow_forward,
                                                    size: 18,
                                                    color: const Color(
                                                      0xFFF4C430,
                                                    ).withOpacity(0.9),
                                                  ),
                                                ],
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Professional Sign Up Button
                    TweenAnimationBuilder(
                      duration: const Duration(milliseconds: 1200),
                      tween: Tween<double>(begin: 0, end: 1),
                      builder: (context, double value, child) {
                        return Opacity(opacity: value, child: child);
                      },
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.pushNamed(context, '/signup');
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.4),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "Don't have an account? ",
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.95),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const Text(
                                  "Sign up",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.arrow_forward,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String hint,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(
        fontSize: 15,
        color: Color(0xFF1F2933),
        height: 1.5,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 15),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF1E7F5C), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
        ),
        errorStyle: const TextStyle(fontSize: 13, color: Color(0xFFDC2626)),
      ),
    );
  }

  Widget _buildFilledTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(
        fontSize: 16,
        color: Colors.white,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.white.withOpacity(0.8),
          fontSize: 15,
        ),
        prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.8)),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withOpacity(0.15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.white, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.red.shade300, width: 1.5),
        ),
        errorStyle: TextStyle(
          color: Colors.red.shade100,
          fontWeight: FontWeight.w500,
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.red.shade200, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
