import 'package:flutter/material.dart';
import '../../models/alert_model.dart';
import '../../models/backend_notification_model.dart';
import '../../services/farm_database_helper.dart';
import '../../services/api_services.dart';
import 'alert_detail_screen.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  _AlertsScreenState createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Alert> _allAlerts = [];
  List<BackendNotification> _backendNotifications = [];
  List<Alert> _filteredAlerts = [];
  String _currentFilter = 'all';
  bool _isLoading = true;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadAlerts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        switch (_tabController.index) {
          case 0:
            _currentFilter = 'all';
            break;
          case 1:
            _currentFilter = 'weather';
            break;
          case 2:
            _currentFilter = 'disease';
            break;
          case 3:
            _currentFilter = 'action';
            break;
        }
        _filterAlerts();
      });
    }
  }

  Future<void> _loadAlerts() async {
    debugPrint('📱 AlertsScreen: Starting to load alerts...');
    setState(() => _isLoading = true);

    try {
      // Load local alerts from database (created by FCM or local checks)
      debugPrint('📱 AlertsScreen: Loading local alerts from database...');
      final localAlerts = await FarmDatabaseHelper.instance.getAllAlerts();

      // Load backend notification history (last 7 days)
      debugPrint('📱 AlertsScreen: Fetching backend notifications...');
      List<BackendNotification> backendNotifs = [];
      try {
        final response = await ApiService.getNotifications(
          limit: 50,
          hours: 168,
        );
        final notifList = response['notifications'] as List;
        backendNotifs = notifList
            .map((json) => BackendNotification.fromJson(json))
            .toList();
        debugPrint(
          '📱 AlertsScreen: Loaded ${backendNotifs.length} backend notifications',
        );

        // Count unread
        _unreadCount = backendNotifs.where((n) => !n.isRead).length;
        debugPrint('📱 AlertsScreen: $_unreadCount unread notifications');
      } catch (e) {
        debugPrint('⚠️ AlertsScreen: Failed to load backend notifications: $e');
      }

      debugPrint('📱 AlertsScreen: Loaded ${localAlerts.length} local alerts');
      debugPrint('📱 Alert types breakdown:');
      final weatherCount = localAlerts.where((a) => a.type == 'weather').length;
      final diseaseCount = localAlerts.where((a) => a.type == 'disease').length;
      final actionCount = localAlerts.where((a) => a.type == 'action').length;
      debugPrint('   - Weather: $weatherCount');
      debugPrint('   - Disease: $diseaseCount');
      debugPrint('   - Action: $actionCount');

      setState(() {
        _allAlerts = localAlerts;
        _backendNotifications = backendNotifs;
        _filterAlerts();
        _isLoading = false;
      });

      debugPrint('📱 AlertsScreen: UI updated with alerts');
    } catch (e) {
      debugPrint('❌ AlertsScreen: Error loading alerts: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markNotificationAsRead(BackendNotification notification) async {
    if (notification.isRead) return;

    try {
      await ApiService.markNotificationAsRead(notification.id);
      setState(() {
        final index = _backendNotifications.indexOf(notification);
        if (index != -1) {
          // Update the notification in the list
          _backendNotifications[index] = BackendNotification(
            id: notification.id,
            type: notification.type,
            severity: notification.severity,
            message: notification.message,
            createdAt: notification.createdAt,
            isRead: true,
            sent: notification.sent,
          );
          _unreadCount = _backendNotifications.where((n) => !n.isRead).length;
        }
      });
      debugPrint('✅ Marked notification ${notification.id} as read');
    } catch (e) {
      debugPrint('⚠️ Failed to mark notification as read: $e');
    }
  }

  Future<void> _markAllNotificationsAsRead() async {
    try {
      await ApiService.markAllNotificationsAsRead();
      setState(() {
        _backendNotifications = _backendNotifications
            .map(
              (n) => BackendNotification(
                id: n.id,
                type: n.type,
                severity: n.severity,
                message: n.message,
                createdAt: n.createdAt,
                isRead: true,
                sent: n.sent,
              ),
            )
            .toList();
        _unreadCount = 0;
      });
      debugPrint('✅ Marked all notifications as read');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All notifications marked as read')),
      );
    } catch (e) {
      debugPrint('⚠️ Failed to mark all notifications as read: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to mark all as read')),
      );
    }
  }

  void _filterAlerts() {
    if (_currentFilter == 'all') {
      _filteredAlerts = _allAlerts;
    } else {
      _filteredAlerts = _allAlerts
          .where((alert) => alert.type == _currentFilter)
          .toList();
    }
  }

  Future<void> _markAllAsRead() async {
    // Mark local alerts as read
    await FarmDatabaseHelper.instance.markAllAlertsAsRead();

    // Mark backend notifications as read
    await _markAllNotificationsAsRead();

    // Reload to refresh UI
    await _loadAlerts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: const Color(0xFFFF9800),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Force Refresh Alerts',
            onPressed: () {
              debugPrint('🔄 User triggered force refresh');
              _loadAlerts();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Refreshing alerts...'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.done_all),
            onPressed: _markAllAsRead,
            tooltip: 'Mark all as read',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Weather'),
            Tab(text: 'Disease'),
            Tab(text: 'Action'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (_filteredAlerts.isEmpty && _backendNotifications.isEmpty)
          ? _buildEmptyState()
          : RefreshIndicator(onRefresh: _loadAlerts, child: _buildAlertsList()),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.notifications_outlined,
                size: 100,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 16),
              Text(
                _currentFilter == 'all'
                    ? 'No Notifications Yet'
                    : 'No ${_currentFilter.toUpperCase()} Alerts',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 12),
              if (_currentFilter == 'all')
                Text(
                  'Pull down to refresh or tap the refresh button above',
                  style: TextStyle(fontSize: 14, color: Colors.blue[700]),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 12),
              Text(
                'Notifications will appear here when:',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRequirementItem('🌾 You add farms to monitor'),
                    const SizedBox(height: 8),
                    _buildRequirementItem(
                      '🌧️ Weather conditions are analyzed',
                    ),
                    const SizedBox(height: 8),
                    _buildRequirementItem('⚠️ Disease risks are detected'),
                    const SizedBox(height: 8),
                    _buildRequirementItem('📡 Real-time monitoring is active'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Add a farm to start receiving notifications',
                style: TextStyle(color: Colors.grey[500], fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequirementItem(String text) {
    return Row(
      children: [
        Icon(Icons.check_circle_outline, size: 20, color: Colors.blue[700]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
        ),
      ],
    );
  }

  Widget _buildAlertsList() {
    // Group alerts by date
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));

    // Combine backend notifications with local alerts
    final allNotifications = <dynamic>[];

    // Add backend notifications (filter by current tab if needed)
    if (_currentFilter == 'all') {
      allNotifications.addAll(_backendNotifications);
    } else {
      allNotifications.addAll(
        _backendNotifications.where((n) => n.type == _currentFilter),
      );
    }

    // Add local alerts
    allNotifications.addAll(_filteredAlerts);

    // Sort by createdAt (most recent first)
    allNotifications.sort((a, b) {
      final aDate = a is BackendNotification
          ? a.createdAt
          : (a as Alert).createdAt;
      final bDate = b is BackendNotification
          ? b.createdAt
          : (b as Alert).createdAt;
      return bDate.compareTo(aDate);
    });

    // Group by date
    final todayItems = allNotifications.where((item) {
      final date = item is BackendNotification
          ? item.createdAt
          : (item as Alert).createdAt;
      return date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;
    }).toList();

    final yesterdayItems = allNotifications.where((item) {
      final date = item is BackendNotification
          ? item.createdAt
          : (item as Alert).createdAt;
      return date.year == yesterday.year &&
          date.month == yesterday.month &&
          date.day == yesterday.day;
    }).toList();

    final olderItems = allNotifications.where((item) {
      final date = item is BackendNotification
          ? item.createdAt
          : (item as Alert).createdAt;
      return date.isBefore(yesterday.subtract(const Duration(hours: 1)));
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (todayItems.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'TODAY',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          ...todayItems.map(
            (item) => item is BackendNotification
                ? _buildBackendNotificationCard(item)
                : _buildAlertCard(item as Alert),
          ),
        ],
        if (yesterdayItems.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'YESTERDAY',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          ...yesterdayItems.map(
            (item) => item is BackendNotification
                ? _buildBackendNotificationCard(item)
                : _buildAlertCard(item as Alert),
          ),
        ],
        if (olderItems.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'EARLIER',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          ...olderItems.map(
            (item) => item is BackendNotification
                ? _buildBackendNotificationCard(item)
                : _buildAlertCard(item as Alert),
          ),
        ],
      ],
    );
  }

  Widget _buildAlertCard(Alert alert) {
    Color severityColor = alert.severity == 'high'
        ? Colors.red
        : alert.severity == 'medium'
        ? Colors.orange
        : Colors.green;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: alert.isRead ? null : severityColor.withOpacity(0.05),
      child: InkWell(
        onTap: () async {
          if (alert.id != null && !alert.isRead) {
            await FarmDatabaseHelper.instance.markAlertAsRead(alert.id!);
          }
          if (mounted) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AlertDetailScreen(alert: alert),
              ),
            );
            _loadAlerts();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(alert.icon, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      alert.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: alert.isRead
                            ? FontWeight.normal
                            : FontWeight.bold,
                      ),
                    ),
                  ),
                  if (!alert.isRead)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: severityColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              if (alert.farmName != null) ...[
                const SizedBox(height: 4),
                Text(
                  alert.farmName!,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
              const SizedBox(height: 8),
              Text(alert.message, style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatTimeAgo(alert.createdAt),
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Colors.grey,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackendNotificationCard(BackendNotification notification) {
    Color severityColor = notification.severity == 'critical'
        ? Colors.red
        : notification.severity == 'high'
        ? Colors.orange
        : notification.severity == 'medium'
        ? Colors.yellow.shade700
        : Colors.green;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: notification.isRead ? null : severityColor.withOpacity(0.05),
      child: InkWell(
        onTap: () => _markNotificationAsRead(notification),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(notification.icon, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      notification.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: notification.isRead
                            ? FontWeight.normal
                            : FontWeight.bold,
                      ),
                    ),
                  ),
                  if (!notification.isRead)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: severityColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud, size: 12, color: Colors.blue[700]),
                    const SizedBox(width: 4),
                    Text(
                      'Backend Notification',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (notification.body.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(notification.body, style: const TextStyle(fontSize: 14)),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatTimeAgo(notification.createdAt),
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  if (notification.isRead)
                    const Icon(Icons.check, size: 14, color: Colors.green)
                  else
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: Colors.grey,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }
}
