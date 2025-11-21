import 'package:flutter/foundation.dart';
import '../models/farm_model.dart';
import '../models/alert_model.dart';
import '../services/api_services.dart';
import '../services/farm_database_helper.dart';

class WeatherAlertService {
  /// Fetch weather risk for a farm and create alerts if needed
  static Future<void> checkAndCreateWeatherAlerts(Farm farm) async {
    try {
      debugPrint('🌤️ Checking weather alerts for farm: ${farm.name}');

      // Get weather risk from backend
      final response = await ApiService.getWeatherRisk(
        lat: farm.latitude,
        lon: farm.longitude,
        crop: farm.cropType,
      );

      debugPrint('📡 Backend response received for ${farm.name}');

      final riskData = response['risk'] ?? {};
      final severity = riskData['severity'] ?? 'low';
      final riskLevel = riskData['risk'] ?? 'No risk';
      final message = riskData['message'] ?? 'Weather conditions are normal';
      final advice = riskData['advice'] ?? '';

      debugPrint('📊 Risk data: severity=$severity, risk=$riskLevel');

      // Always create an alert entry to show current weather status
      await _createWeatherAlert(
        farm: farm,
        severity: severity,
        riskLevel: riskLevel,
        message: message,
        advice: advice,
      );

      debugPrint(
        '✅ Weather alert created for ${farm.name}: $severity - $message',
      );
    } catch (e) {
      debugPrint('❌ Failed to check weather alerts for ${farm.name}: $e');

      // Create a fallback alert even if backend fails
      try {
        await _createWeatherAlert(
          farm: farm,
          severity: 'low',
          riskLevel: 'Unable to fetch current risk',
          message:
              'Could not connect to weather service. Your farm data is safe.',
          advice: 'Check your internet connection and try again later.',
        );
        debugPrint('✅ Fallback alert created for ${farm.name}');
      } catch (fallbackError) {
        debugPrint('❌ Failed to create fallback alert: $fallbackError');
      }
    }
  }

  /// Check weather alerts for all farms
  static Future<void> checkAllFarmsWeatherAlerts() async {
    debugPrint('🚀 Starting alert check for all farms...');
    try {
      final farms = await FarmDatabaseHelper.instance.getAllFarms();

      debugPrint('🌾 Found ${farms.length} farm(s) in database');

      if (farms.isEmpty) {
        debugPrint('ℹ️ No farms to check for alerts');
        return;
      }

      for (var farm in farms) {
        debugPrint('🔄 Processing farm: ${farm.name} (ID: ${farm.id})');
        await checkAndCreateWeatherAlerts(farm);
        await _createActionAlerts(farm); // Add action recommendations
      }

      // Verify alerts were created
      final allAlerts = await FarmDatabaseHelper.instance.getAllAlerts();
      debugPrint(
        '✅ Alert check complete. Total alerts in DB: ${allAlerts.length}',
      );
    } catch (e) {
      debugPrint('❌ Failed to check all farm alerts: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
    }
  }

  /// Create action alerts (recommendations for farm activities)
  static Future<void> _createActionAlerts(Farm farm) async {
    try {
      // Check if we already have recent action alerts
      final recentAlerts = await FarmDatabaseHelper.instance.getAllAlerts();
      final sixHoursAgo = DateTime.now().subtract(const Duration(hours: 6));

      final hasRecentActionAlert = recentAlerts.any(
        (alert) =>
            alert.farmId == farm.id &&
            alert.type == 'action' &&
            alert.createdAt.isAfter(sixHoursAgo),
      );

      if (hasRecentActionAlert) {
        return; // Don't spam action alerts
      }

      // Generate action recommendations based on crop type
      final actions = _getActionRecommendations(farm.cropType);

      for (var action in actions) {
        final alert = Alert(
          type: 'action',
          severity: 'low',
          title: '📋 Recommended Action',
          message: '${farm.name}: $action',
          farmId: farm.id,
          farmName: farm.name,
          userId: farm.userId, // Attach userId from farm
          createdAt: DateTime.now(),
          isRead: false,
          metadata: {'crop': farm.cropType, 'action_type': 'recommendation'},
        );

        await FarmDatabaseHelper.instance.createAlert(alert);
      }
    } catch (e) {
      debugPrint('❌ Failed to create action alerts: $e');
    }
  }

  /// Get action recommendations based on crop type
  static List<String> _getActionRecommendations(String cropType) {
    final crop = cropType.toLowerCase();

    if (crop.contains('tomato')) {
      return [
        'Check soil moisture levels and adjust irrigation if needed',
        'Monitor plants for early signs of blight or pests',
      ];
    } else if (crop.contains('wheat') || crop.contains('rice')) {
      return [
        'Inspect crop growth stage and adjust fertilizer schedule',
        'Monitor for pest activity in grain crops',
      ];
    } else if (crop.contains('corn') || crop.contains('maize')) {
      return [
        'Check for weed growth and plan cultivation',
        'Monitor nitrogen levels in soil',
      ];
    } else {
      return [
        'Perform routine crop health inspection',
        'Check irrigation system functionality',
      ];
    }
  }

  /// Create a weather alert in the local database
  static Future<void> _createWeatherAlert({
    required Farm farm,
    required String severity,
    required String riskLevel,
    required String message,
    required String advice,
  }) async {
    // Determine alert type based on risk
    String type = 'weather';
    String title = _getAlertTitle(severity, riskLevel);

    // If message contains specific keywords, categorize as disease
    if (message.toLowerCase().contains('disease') ||
        message.toLowerCase().contains('fungal') ||
        message.toLowerCase().contains('blight') ||
        message.toLowerCase().contains('pest')) {
      type = 'disease';
    }

    // Create personalized message for all severity levels
    String personalizedMessage = message;
    String personalizedAdvice = advice;

    if (severity.toLowerCase() == 'low') {
      // Generate engaging updates even for safe conditions
      personalizedMessage =
          '✅ ${farm.name} Status Update\n\n'
          'Your ${farm.cropType} crops are doing great! Current weather conditions are ideal for growth. '
          '${message.isEmpty ? "No risks detected by our prediction engine." : message}\n\n'
          'Our AI monitoring system is continuously analyzing weather patterns, soil conditions, and disease risks for your farm.';
      personalizedAdvice = advice.isEmpty
          ? 'Continue with regular farm maintenance. Your crops are in excellent condition!'
          : advice;
    } else if (severity.toLowerCase() == 'medium') {
      personalizedMessage =
          '⚠️ ${farm.name} Attention Needed\n\n$message\n\n'
          'Our prediction engine has detected conditions that require your attention.';
    } else if (severity.toLowerCase() == 'high' ||
        severity.toLowerCase() == 'critical') {
      personalizedMessage =
          '🚨 ${farm.name} URGENT ACTION REQUIRED\n\n$message\n\n'
          'Immediate action recommended to protect your ${farm.cropType} crops!';
    }

    // Create the alert
    final alert = Alert(
      type: type,
      severity: severity,
      title: title,
      message: personalizedMessage,
      farmId: farm.id,
      farmName: farm.name,
      userId: farm.userId, // Attach userId from farm
      createdAt: DateTime.now(),
      isRead: false,
      metadata: {
        'risk': riskLevel,
        'advice': personalizedAdvice,
        'lat': farm.latitude,
        'lon': farm.longitude,
      },
    );

    await FarmDatabaseHelper.instance.createAlert(alert);
  }

  /// Get human-readable alert title based on severity and risk
  static String _getAlertTitle(String severity, String riskLevel) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return '🔴 Critical Weather Alert';
      case 'high':
        return '🟠 High Risk Warning';
      case 'medium':
        return '🟡 Moderate Weather Notice';
      case 'low':
        return '🟢 Weather Update';
      default:
        return '📊 Weather Status';
    }
  }

  /// Get severity icon
  static String getSeverityIcon(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return '🔴';
      case 'high':
        return '🟠';
      case 'medium':
        return '🟡';
      case 'low':
        return '🟢';
      default:
        return '⚪';
    }
  }
}
