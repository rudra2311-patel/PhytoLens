import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'dashboard_screen.dart';
import 'farms_screen.dart';
import 'alerts_screen.dart';
import 'profile_screen.dart';
import '../services/websocket_alert_service.dart';
import '../services/weather_alert_service.dart';
import '../services/farm_database_helper.dart';
import '../models/alert_model.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  _MainNavigationScreenState createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final _wsService = WebSocketAlertService.instance;

  @override
  void initState() {
    super.initState();
    _initializeWebSocket();
    _initializeAlerts(); // Create initial alerts for existing farms
  }

  /// Initialize alerts for all existing farms on app start
  Future<void> _initializeAlerts() async {
    debugPrint('🚀 Initializing weather alerts for existing farms...');
    try {
      // Import weather alert service
      final farms = await FarmDatabaseHelper.instance.getAllFarms();
      if (farms.isNotEmpty) {
        debugPrint('🌾 Found ${farms.length} farm(s), creating alerts...');
        await WeatherAlertService.checkAllFarmsWeatherAlerts();
        debugPrint('✅ Initial alerts created successfully');
      } else {
        debugPrint('ℹ️ No farms found, skipping alert creation');
      }
    } catch (e) {
      debugPrint('❌ Failed to initialize alerts: $e');
    }
  }

  /// Initialize WebSocket connections for all farms
  Future<void> _initializeWebSocket() async {
    debugPrint('🚀 Initializing WebSocket alert system...');

    // Set up alert callback
    _wsService.onAlertReceived = _handleNewAlert;

    // Set up connection state callback
    _wsService.onConnectionStateChanged = _handleConnectionStateChange;

    // Connect to all farms
    await _wsService.connectAllFarms();

    debugPrint(
      '✅ WebSocket initialized. Active connections: ${_wsService.activeConnectionsCount}',
    );
  }

  /// Handle new alert received from WebSocket
  void _handleNewAlert(Alert alert) {
    debugPrint('🚨 New real-time alert: ${alert.title}');

    // Show snackbar notification
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                _getSeverityIcon(alert.severity),
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      alert.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      alert.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: _getSeverityColor(alert.severity),
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'VIEW',
            textColor: Colors.white,
            onPressed: () {
              setState(() => _currentIndex = 3); // Navigate to Alerts tab
            },
          ),
        ),
      );
    }
  }

  /// Handle WebSocket connection state changes
  void _handleConnectionStateChange(int farmId, bool connected) {
    debugPrint(
      'Farm ID $farmId WebSocket: ${connected ? "✅ Connected" : "❌ Disconnected"}',
    );
  }

  IconData _getSeverityIcon(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Icons.error;
      case 'high':
        return Icons.warning;
      case 'medium':
        return Icons.info;
      default:
        return Icons.notifications;
    }
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Colors.red.shade700;
      case 'high':
        return Colors.orange.shade700;
      case 'medium':
        return Colors.amber.shade700;
      default:
        return Colors.blue.shade700;
    }
  }

  @override
  void dispose() {
    _wsService.disconnectAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const HomeScreen(),
          const DashboardScreen(key: ValueKey('dashboard')),
          const FarmsScreen(),
          const AlertsScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF4CAF50),
        unselectedItemColor: const Color(0xFF757575),
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.agriculture_rounded),
            label: 'Farms',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_rounded),
            label: 'Alerts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
