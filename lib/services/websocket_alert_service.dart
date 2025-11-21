import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import '../models/farm_model.dart';
import '../models/alert_model.dart';
import '../services/farm_database_helper.dart';

/// Real-time WebSocket service for weather alerts
/// This is ADDITIONAL to the existing REST API calls
/// Provides push notifications for high/critical severity alerts
class WebSocketAlertService {
  static WebSocketAlertService? _instance;
  static WebSocketAlertService get instance {
    _instance ??= WebSocketAlertService._internal();
    return _instance!;
  }

  WebSocketAlertService._internal();

  // WebSocket connections for each farm
  final Map<int, WebSocketChannel> _connections = {};
  final Map<int, StreamSubscription> _subscriptions = {};
  final Map<int, Timer> _pingTimers = {};
  final Map<int, Timer> _reconnectTimers = {};

  // Connection state tracking
  final Map<int, bool> _isConnected = {};
  final Map<int, String> _connectionIds = {};

  // Alert callback
  Function(Alert)? onAlertReceived;
  Function(int farmId, bool connected)? onConnectionStateChanged;

  // Configuration
  static const String wsBaseUrl = 'ws://10.0.2.2:8000';
  static const Duration pingInterval = Duration(seconds: 30);
  static const Duration reconnectDelay = Duration(seconds: 5);
  static const int maxReconnectAttempts = 5;
  final Map<int, int> _reconnectAttempts = {};

  /// Connect to WebSocket for a specific farm
  Future<void> connectForFarm(Farm farm) async {
    if (_connections.containsKey(farm.id)) {
      debugPrint('⚠️ WebSocket already connected for farm ${farm.name}');
      return;
    }

    try {
      // Use userId from farm for WebSocket connection
      final userId = farm.userId ?? 'unknown';

      final uri = Uri.parse(
        '$wsBaseUrl/ws/weather-alerts'
        '?lat=${farm.latitude}'
        '&lon=${farm.longitude}'
        '&crop=${Uri.encodeComponent(farm.cropType)}'
        '&user_id=$userId',
      );

      debugPrint('🔌 Connecting WebSocket for ${farm.name}: $uri');

      final channel = WebSocketChannel.connect(uri);
      _connections[farm.id!] = channel;
      _reconnectAttempts[farm.id!] = 0;

      // Listen to messages
      _subscriptions[farm.id!] = channel.stream.listen(
        (message) => _handleMessage(farm, message),
        onError: (error) => _handleError(farm, error),
        onDone: () => _handleDisconnect(farm),
        cancelOnError: false,
      );

      // Start ping timer to keep connection alive
      _startPingTimer(farm);

      debugPrint('✅ WebSocket connected for ${farm.name}');
    } catch (e) {
      debugPrint('❌ Failed to connect WebSocket for ${farm.name}: $e');
      _scheduleReconnect(farm);
    }
  }

  /// Handle incoming WebSocket messages
  void _handleMessage(Farm farm, dynamic message) {
    try {
      final data = jsonDecode(message);
      final type = data['type'];

      debugPrint('📨 WebSocket message for ${farm.name}: $type');

      switch (type) {
        case 'connection':
          _handleConnectionMessage(farm, data);
          break;

        case 'weather_alert':
          _handleWeatherAlert(farm, data);
          break;

        case 'pong':
          debugPrint('💓 Pong received for ${farm.name}');
          break;

        default:
          debugPrint('⚠️ Unknown message type: $type');
      }
    } catch (e) {
      debugPrint('❌ Error parsing WebSocket message: $e');
    }
  }

  /// Handle connection confirmation
  void _handleConnectionMessage(Farm farm, Map<String, dynamic> data) {
    _connectionIds[farm.id!] = data['connection_id'] ?? '';
    _isConnected[farm.id!] = true;
    _reconnectAttempts[farm.id!] = 0;

    debugPrint(
      '✅ WebSocket connected for ${farm.name} - ID: ${_connectionIds[farm.id!]}',
    );

    onConnectionStateChanged?.call(farm.id!, true);
  }

  /// Handle weather alert from WebSocket
  Future<void> _handleWeatherAlert(Farm farm, Map<String, dynamic> data) async {
    try {
      final severity = data['severity'] ?? 'medium';
      final riskData = data['risk'] ?? {};
      final weatherData = data['weather'] ?? {};

      final message = riskData['message'] ?? 'Weather alert received';
      final advice = riskData['advice'] ?? '';
      final risk = riskData['risk'] ?? 'Weather Alert';

      debugPrint('🚨 WEATHER ALERT for ${farm.name}: $severity - $message');

      // Create alert in local database
      final alert = Alert(
        type: _determineAlertType(message, risk),
        severity: severity,
        title: _getAlertTitle(severity),
        message: message,
        farmId: farm.id,
        farmName: farm.name,
        userId: farm.userId, // Attach userId from farm
        createdAt: DateTime.now(),
        isRead: false,
        metadata: {
          'risk': risk,
          'advice': advice,
          'lat': farm.latitude,
          'lon': farm.longitude,
          'weather': weatherData,
          'source': 'websocket',
        },
      );

      await FarmDatabaseHelper.instance.createAlert(alert);

      // Trigger callback for UI update
      onAlertReceived?.call(alert);

      debugPrint('✅ Alert saved to database for ${farm.name}');
    } catch (e) {
      debugPrint('❌ Error handling weather alert: $e');
    }
  }

  /// Determine alert type based on message content
  String _determineAlertType(String message, String risk) {
    final lowerMessage = message.toLowerCase();
    final lowerRisk = risk.toLowerCase();

    if (lowerMessage.contains('disease') ||
        lowerMessage.contains('fungal') ||
        lowerMessage.contains('blight') ||
        lowerMessage.contains('bacterial') ||
        lowerRisk.contains('disease') ||
        lowerRisk.contains('blight')) {
      return 'disease';
    }

    if (lowerMessage.contains('pest') ||
        lowerRisk.contains('pest') ||
        lowerRisk.contains('insect')) {
      return 'action';
    }

    return 'weather';
  }

  /// Get alert title based on severity
  String _getAlertTitle(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return '🔴 CRITICAL ALERT';
      case 'high':
        return '🟠 HIGH PRIORITY ALERT';
      case 'medium':
        return '🟡 WEATHER NOTICE';
      default:
        return '📊 Weather Update';
    }
  }

  /// Handle WebSocket errors
  void _handleError(Farm farm, dynamic error) {
    debugPrint('❌ WebSocket error for ${farm.name}: $error');
    _isConnected[farm.id!] = false;
    onConnectionStateChanged?.call(farm.id!, false);
  }

  /// Handle WebSocket disconnect
  void _handleDisconnect(Farm farm) {
    debugPrint('🔌 WebSocket disconnected for ${farm.name}');
    _isConnected[farm.id!] = false;
    onConnectionStateChanged?.call(farm.id!, false);

    _stopPingTimer(farm);
    _scheduleReconnect(farm);
  }

  void _startPingTimer(Farm farm) {
    _pingTimers[farm.id!]?.cancel();
    _pingTimers[farm.id!] = Timer.periodic(pingInterval, (timer) {
      if (_connections.containsKey(farm.id)) {
        try {
          _connections[farm.id!]!.sink.add('ping');
          debugPrint('💓 Ping sent for ${farm.name}');
        } catch (e) {
          debugPrint('❌ Failed to send ping for ${farm.name}: $e');
          timer.cancel();
        }
      }
    });
  }

  /// Stop ping timer
  void _stopPingTimer(Farm farm) {
    _pingTimers[farm.id!]?.cancel();
    _pingTimers.remove(farm.id!);
  }

  /// Schedule reconnection attempt
  void _scheduleReconnect(Farm farm) {
    if (_reconnectAttempts[farm.id!]! >= maxReconnectAttempts) {
      debugPrint(
        '❌ Max reconnect attempts reached for ${farm.name}. Giving up.',
      );
      return;
    }

    _reconnectAttempts[farm.id!] = (_reconnectAttempts[farm.id!] ?? 0) + 1;

    debugPrint(
      '🔄 Scheduling reconnect for ${farm.name} (attempt ${_reconnectAttempts[farm.id!]})...',
    );

    _reconnectTimers[farm.id!]?.cancel();
    _reconnectTimers[farm.id!] = Timer(reconnectDelay, () {
      disconnectFarm(farm.id!);
      connectForFarm(farm);
    });
  }

  /// Disconnect WebSocket for a specific farm
  void disconnectFarm(int farmId) {
    debugPrint('🔌 Disconnecting WebSocket for farm ID: $farmId');

    _stopPingTimer(
      Farm(
        id: farmId,
        name: '',
        location: '',
        latitude: 0,
        longitude: 0,
        cropType: '',
        createdAt: DateTime.now(),
      ),
    );

    _reconnectTimers[farmId]?.cancel();
    _reconnectTimers.remove(farmId);

    _subscriptions[farmId]?.cancel();
    _subscriptions.remove(farmId);

    try {
      _connections[farmId]?.sink.close(status.goingAway);
    } catch (e) {
      debugPrint('⚠️ Error closing WebSocket: $e');
    }

    _connections.remove(farmId);
    _isConnected.remove(farmId);
    _connectionIds.remove(farmId);
    _reconnectAttempts.remove(farmId);
  }

  /// Connect to WebSocket for all farms
  Future<void> connectAllFarms() async {
    try {
      final farms = await FarmDatabaseHelper.instance.getAllFarms();

      debugPrint('🔌 Connecting WebSocket for ${farms.length} farms...');

      for (var farm in farms) {
        if (farm.id != null) {
          await connectForFarm(farm);
          // Small delay to avoid overwhelming the server
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      debugPrint('✅ All farm WebSocket connections initiated');
    } catch (e) {
      debugPrint('❌ Error connecting all farms: $e');
    }
  }

  /// Disconnect all WebSocket connections
  void disconnectAll() {
    debugPrint('🔌 Disconnecting all WebSocket connections...');

    final farmIds = List<int>.from(_connections.keys);
    for (var farmId in farmIds) {
      disconnectFarm(farmId);
    }

    debugPrint('✅ All WebSocket connections closed');
  }

  /// Check if a farm is connected
  bool isConnected(int farmId) {
    return _isConnected[farmId] ?? false;
  }

  /// Get connection ID for a farm
  String? getConnectionId(int farmId) {
    return _connectionIds[farmId];
  }

  /// Get count of active connections
  int get activeConnectionsCount {
    return _isConnected.values.where((connected) => connected).length;
  }

  /// Dispose all resources
  void dispose() {
    disconnectAll();
    _pingTimers.clear();
    _reconnectTimers.clear();
  }
}
