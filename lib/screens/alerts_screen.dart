import 'package:flutter/material.dart';
import '../models/alert_model.dart';
import '../services/farm_database_helper.dart';
import '../services/weather_alert_service.dart';
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
  List<Alert> _filteredAlerts = [];
  String _currentFilter = 'all';
  bool _isLoading = true;

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
      // First check for new weather alerts for all farms
      debugPrint('📱 AlertsScreen: Calling WeatherAlertService...');
      await WeatherAlertService.checkAllFarmsWeatherAlerts();

      // Load alerts from database
      debugPrint('📱 AlertsScreen: Loading alerts from database...');
      final alerts = await FarmDatabaseHelper.instance.getAllAlerts();

      debugPrint('📱 AlertsScreen: Loaded ${alerts.length} alerts');
      debugPrint('📱 Alert types breakdown:');
      final weatherCount = alerts.where((a) => a.type == 'weather').length;
      final diseaseCount = alerts.where((a) => a.type == 'disease').length;
      final actionCount = alerts.where((a) => a.type == 'action').length;
      debugPrint('   - Weather: $weatherCount');
      debugPrint('   - Disease: $diseaseCount');
      debugPrint('   - Action: $actionCount');

      setState(() {
        _allAlerts = alerts;
        _filterAlerts();
        _isLoading = false;
      });

      debugPrint('📱 AlertsScreen: UI updated with alerts');
    } catch (e) {
      debugPrint('❌ AlertsScreen: Error loading alerts: $e');
      setState(() => _isLoading = false);
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
    await FarmDatabaseHelper.instance.markAllAlertsAsRead();
    await _loadAlerts();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All notifications marked as read')),
      );
    }
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
          : _filteredAlerts.isEmpty
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

    final todayAlerts = _filteredAlerts
        .where(
          (a) =>
              a.createdAt.year == today.year &&
              a.createdAt.month == today.month &&
              a.createdAt.day == today.day,
        )
        .toList();

    final yesterdayAlerts = _filteredAlerts
        .where(
          (a) =>
              a.createdAt.year == yesterday.year &&
              a.createdAt.month == yesterday.month &&
              a.createdAt.day == yesterday.day,
        )
        .toList();

    final olderAlerts = _filteredAlerts
        .where(
          (a) => a.createdAt.isBefore(
            yesterday.subtract(const Duration(hours: 1)),
          ),
        )
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (todayAlerts.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'TODAY',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          ...todayAlerts.map((alert) => _buildAlertCard(alert)),
        ],
        if (yesterdayAlerts.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'YESTERDAY',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          ...yesterdayAlerts.map((alert) => _buildAlertCard(alert)),
        ],
        if (olderAlerts.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'EARLIER',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          ...olderAlerts.map((alert) => _buildAlertCard(alert)),
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
