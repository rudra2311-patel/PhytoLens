import 'package:agriscan_pro/screens/scan_screen.dart';
import 'package:agriscan_pro/services/auth_services.dart';
import 'package:flutter/material.dart';
import 'camera_screen.dart';
import '../utils/constants.dart';
import '../services/api_services.dart';
import '../services/farm_database_helper.dart';
import '../services/weather_alert_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _farmsCount = 0;
  int _scansCount = 0;
  int _alertsCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
    _checkAndCreateAlerts(); // Proactively create alerts on home screen
  }

  /// Proactively check and create weather alerts for all farms
  Future<void> _checkAndCreateAlerts() async {
    try {
      // Check if user has farms
      final farmsCount = await FarmDatabaseHelper.instance.getFarmsCount();
      if (farmsCount > 0) {
        // Create weather alerts in background (don't block UI)
        WeatherAlertService.checkAllFarmsWeatherAlerts()
            .then((_) {
              debugPrint('✅ Background alert check completed');
              // Refresh alert count after creating alerts
              _loadStatistics();
            })
            .catchError((e) {
              debugPrint('⚠️ Background alert check failed: $e');
            });
      }
    } catch (e) {
      debugPrint('⚠️ Failed to initiate alert check: $e');
    }
  }

  Future<void> _loadStatistics() async {
    try {
      final farmsCount = await FarmDatabaseHelper.instance.getFarmsCount();
      final alertsCount = await FarmDatabaseHelper.instance
          .getUnreadAlertsCount();

      setState(() {
        _farmsCount = farmsCount;
        _scansCount = 0; // Will be updated when scan API is integrated
        _alertsCount = alertsCount;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _logout(BuildContext context) async {
    try {
      await ApiService.logoutUser();
    } catch (e) {
      if (e.toString().contains("Token has been revoked") ||
          e.toString().contains("Invalid or expired token")) {
        debugPrint(
          "⚠️ Token already revoked or expired — continuing logout...",
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Logout failed: $e")));
        }
        return;
      }
    }

    // SECURITY FIX: Clear local database before logout
    try {
      await FarmDatabaseHelper.instance.clearAllUserData();
      debugPrint('✅ Local database cleared');
    } catch (e) {
      debugPrint('⚠️ Failed to clear database: $e');
    }

    await AuthService.logout();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Logged out successfully")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.green[700],
        title: const Text(
          AppStrings.appName,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.logout, color: Colors.white, size: 20),
              ),
              tooltip: 'Logout',
              onPressed: () => _logout(context),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header Section with Gradient
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.green[700]!, Colors.green[600]!],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                  child: Column(
                    children: [
                      // Circular Icon with Animation Effect
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.agriculture,
                          size: 48,
                          color: Colors.green[700],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        AppStrings.welcomeTitle,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppStrings.welcomeSubtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white.withOpacity(0.9),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Main Content
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Main Action Buttons with Cards
                    _buildActionCard(
                      context: context,
                      icon: Icons.camera_alt,
                      title: AppStrings.scanButton,
                      subtitle: 'Take a photo to diagnose plant disease',
                      color: Colors.green[700]!,
                      onTap: () => _navigateToCamera(context),
                    ),

                    const SizedBox(height: 16),

                    _buildActionCard(
                      context: context,
                      icon: Icons.history,
                      title: AppStrings.historyButton,
                      subtitle: 'View your previous scans',
                      color: Colors.blue[700]!,
                      isOutlined: true,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ScanHistoryScreen(),
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Section Header
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.green[700],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Key Features',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Feature Cards
                    _buildFeatureCard(
                      icon: Icons.offline_bolt,
                      title: 'Offline Detection',
                      description: 'Works completely offline without internet',
                      color: Colors.orange[700]!,
                    ),

                    const SizedBox(height: 12),

                    _buildFeatureCard(
                      icon: Icons.speed,
                      title: 'Instant Results',
                      description: 'Get AI-powered diagnosis in seconds',
                      color: Colors.purple[700]!,
                    ),

                    const SizedBox(height: 12),

                    _buildFeatureCard(
                      icon: Icons.lightbulb_outline,
                      title: 'Smart Recommendations',
                      description: 'Receive treatment and prevention advice',
                      color: Colors.amber[700]!,
                    ),

                    const SizedBox(height: 32),

                    // Info Banner
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.green[50]!, Colors.green[100]!],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.green[200]!, width: 1),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.green[700],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.info_outline,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'Designed for farmers in rural areas with limited internet connectivity',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[800],
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool isOutlined = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isOutlined ? Colors.white : color,
          borderRadius: BorderRadius.circular(16),
          border: isOutlined ? Border.all(color: color, width: 2) : null,
          boxShadow: [
            BoxShadow(
              color: (isOutlined ? color : color).withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isOutlined
                    ? color.withOpacity(0.1)
                    : Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isOutlined ? color : Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isOutlined ? color : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: isOutlined
                          ? Colors.grey[600]
                          : Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: isOutlined ? color : Colors.white,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToCamera(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CameraScreen()),
    );
  }

  void _showHistoryComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(AppStrings.historyComingSoon),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
