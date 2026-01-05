import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../main.dart' show scaffoldMessengerKey;
import '../services/api_services.dart';
import '../services/auth_services.dart';
import '../services/farm_database_helper.dart';
import '../models/alert_model.dart';

// Top-level function for background message handling
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('📱 Background message received: ${message.messageId}');

  // Save to local database
  await FCMService._saveNotificationToDatabase(message);
}

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  /// Initialize FCM
  /// Backend handles: deduplication (60min), rate limiting (5/hr, 20/day),
  /// smart batching (15min window), personalized messages, priority routing
  Future<void> initialize() async {
    try {
      debugPrint('🔥 Initializing FCM...');

      // Request permission (iOS + Android 13+)
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: true, // For critical alerts
        provisional: false,
        sound: true,
      );

      debugPrint('📱 FCM Permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // Get FCM token
        _fcmToken = await _messaging.getToken();
        debugPrint('📱 FCM Token: $_fcmToken');

        // Send token to backend
        if (_fcmToken != null) {
          await _sendTokenToBackend(_fcmToken!);
        }

        // Set up message handlers
        _setupMessageHandlers();

        // Handle token refresh
        _messaging.onTokenRefresh.listen((newToken) {
          debugPrint('📱 FCM Token refreshed: $newToken');
          _fcmToken = newToken;
          _sendTokenToBackend(newToken);
        });

        debugPrint('✅ FCM initialized successfully');
      } else {
        debugPrint('⚠️ Notification permission denied');
      }
    } catch (e) {
      debugPrint('❌ Failed to initialize FCM: $e');
    }
  }

  /// Setup message handlers
  void _setupMessageHandlers() {
    // Background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Foreground messages - show in-app notification
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📱 Foreground message: ${message.notification?.title}');

      // Backend already handles deduplication, rate limiting, and batching
      // Just display and save the smart notification

      // Show in-app notification banner
      _showInAppNotification(message);

      // Save to database
      _saveNotificationToDatabase(message);
    });

    // When user taps notification (app in background)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('📱 Notification tapped (background): ${message.messageId}');
      _handleNotificationTap(message);
    });

    // When app is opened from terminated state via notification
    _messaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint('📱 App opened from notification: ${message.messageId}');
        _handleNotificationTap(message);
      }
    });

    debugPrint('✅ Message handlers setup complete');
  }

  /// Show in-app notification when app is in foreground
  void _showInAppNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    final data = message.data;
    final severity = data['severity'] ?? 'low';
    final farmName = data['farm_name'];
    final notificationType = data['notification_type'] ?? 'general';
    final priority = data['priority'] ?? 'normal';

    debugPrint('📬 Notification Details:');
    debugPrint('  - Type: $notificationType');
    debugPrint('  - Severity: $severity');
    debugPrint('  - Priority: $priority');
    if (farmName != null) debugPrint('  - Farm: $farmName');

    // Choose color based on severity
    Color backgroundColor;
    IconData icon;

    switch (severity) {
      case 'critical':
        backgroundColor = Colors.red.shade600;
        icon = Icons.warning_amber_rounded;
        break;
      case 'high':
        backgroundColor = Colors.orange.shade600;
        icon = Icons.notification_important;
        break;
      case 'medium':
        backgroundColor = Colors.blue.shade600;
        icon = Icons.notifications_active;
        break;
      default:
        backgroundColor = Colors.green.shade600;
        icon = Icons.notifications;
    }

    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    notification.title ?? 'New Notification',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  if (notification.body != null)
                    Text(
                      notification.body!,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: SnackBarAction(
          label: 'VIEW',
          textColor: Colors.white,
          onPressed: () {
            debugPrint('📱 User tapped notification action');
            // TODO: Navigate to alerts screen
          },
        ),
      ),
    );
  }

  /// Save notification to local database
  static Future<void> _saveNotificationToDatabase(RemoteMessage message) async {
    try {
      final notification = message.notification;
      final data = message.data;

      if (notification == null) return;

      // Get current logged-in user ID
      final currentUserId = await AuthService.getUserId();
      if (currentUserId == null) {
        debugPrint('⚠️ No user logged in, skipping notification save');
        return;
      }

      // Create Alert object with backend's rich notification data
      final alert = Alert(
        title: notification.title ?? 'New Alert',
        message: notification.body ?? '',
        severity: data['severity'] ?? 'low',
        type: data['notification_type'] ?? data['type'] ?? 'notification',
        createdAt: DateTime.now(),
        isRead: false,
        farmId: data['farm_id'] != null
            ? int.tryParse(data['farm_id'])
            : (data['farmId'] != null ? int.tryParse(data['farmId']) : null),
        metadata: data.isNotEmpty ? data : null,
        userId: currentUserId, // Use logged-in user
      );

      debugPrint('💾 Saving notification: ${alert.title} (${alert.severity})');
      if (data['farm_name'] != null) {
        debugPrint(
          '   Farm: ${data['farm_name']}, Crop: ${data['crop'] ?? 'N/A'}',
        );
      }

      // Save to database
      final db = FarmDatabaseHelper.instance;
      await db.createAlert(alert);
      debugPrint('✅ Notification saved to database: ${alert.title}');
    } catch (e) {
      debugPrint('❌ Failed to save notification to database: $e');
    }
  }

  /// Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    // Navigate to alerts screen or specific alert detail
    debugPrint('📱 User tapped notification: ${message.data}');
    // TODO: Navigate to AlertDetailScreen using global navigator
    // You can use a stream controller or global navigator key to navigate
  }

  /// Send FCM token to backend
  Future<void> _sendTokenToBackend(String token) async {
    try {
      // Call your backend API to save the token
      await ApiService.updateFCMToken(token);
      debugPrint('✅ FCM token sent to backend');
    } catch (e) {
      debugPrint('❌ Failed to send FCM token to backend: $e');
    }
  }

  /// Manually update FCM token on backend (call after login)
  Future<void> updateFCMTokenOnBackend() async {
    if (_fcmToken != null) {
      await _sendTokenToBackend(_fcmToken!);
    } else {
      debugPrint('⚠️ No FCM token available to send');
    }
  }

  /// Subscribe to topic (e.g., for all users, critical alerts)
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      debugPrint('✅ Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('❌ Failed to subscribe to topic: $e');
    }
  }

  /// Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      debugPrint('✅ Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('❌ Failed to unsubscribe from topic: $e');
    }
  }
}
