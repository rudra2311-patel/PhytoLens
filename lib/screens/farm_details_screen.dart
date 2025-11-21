import 'package:flutter/material.dart';
import '../models/farm_model.dart';
import '../models/alert_model.dart';
import '../services/farm_database_helper.dart';
import '../services/api_services.dart';
import '../services/weather_alert_service.dart';
import '../services/websocket_alert_service.dart';

class FarmDetailsScreen extends StatefulWidget {
  final Farm farm;

  const FarmDetailsScreen({super.key, required this.farm});

  @override
  _FarmDetailsScreenState createState() => _FarmDetailsScreenState();
}

class _FarmDetailsScreenState extends State<FarmDetailsScreen> {
  late Farm _farm;
  List<Alert> _farmAlerts = [];
  bool _isLoadingAlerts = false;

  @override
  void initState() {
    super.initState();
    _farm = widget.farm;
    _loadFarmAlerts();
    _checkWeatherAlerts();
  }

  Future<void> _loadFarmAlerts() async {
    if (!mounted) return;
    setState(() => _isLoadingAlerts = true);

    try {
      final allAlerts = await FarmDatabaseHelper.instance.getAllAlerts();
      final farmAlerts = allAlerts
          .where((alert) => alert.farmId == _farm.id)
          .toList();

      if (!mounted) return;
      setState(() {
        _farmAlerts = farmAlerts;
        _isLoadingAlerts = false;
      });
    } catch (e) {
      debugPrint('Failed to load farm alerts: $e');
      if (!mounted) return;
      setState(() => _isLoadingAlerts = false);
    }
  }

  Future<void> _checkWeatherAlerts() async {
    await WeatherAlertService.checkAndCreateWeatherAlerts(_farm);
    if (!mounted) return;
    await _loadFarmAlerts();
  }

  Color get _riskColor {
    switch (_farm.riskLevel) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String get _riskIcon {
    switch (_farm.riskLevel) {
      case 'high':
        return '🔴';
      case 'medium':
        return '🟡';
      case 'low':
        return '🟢';
      default:
        return '⚪';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_farm.name),
        backgroundColor: const Color(0xFF4CAF50),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // Navigate to edit farm screen (to be implemented)
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Edit feature coming soon')),
              );
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          _buildImageSection(),
          _buildStatusCard(),
          _buildLocationCard(),
          _buildCropDetailsCard(),
          _buildActiveAlertsCard(),
          _buildDeleteButton(),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    return Container(
      height: 200,
      color: Colors.grey[200],
      child: _farm.imageUrl != null
          ? Image.network(_farm.imageUrl!, fit: BoxFit.cover)
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.agriculture, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 8),
                Text(
                  'No farm image',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Add image feature coming soon'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_a_photo),
                  label: const Text('Add Photo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📊 CURRENT STATUS',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Risk Level:', style: TextStyle(fontSize: 16)),
                Row(
                  children: [
                    Text(_riskIcon, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 4),
                    Text(
                      _farm.riskLevel?.toUpperCase() ?? 'UNKNOWN',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _riskColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Risk level based on farm location',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📍 LOCATION',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(_farm.location, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 4),
            Text(
              'Lat: ${_farm.latitude.toStringAsFixed(4)}, Lon: ${_farm.longitude.toStringAsFixed(4)}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  // TODO: Open map
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Map feature coming soon')),
                  );
                },
                icon: const Icon(Icons.map),
                label: const Text('View on Map'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCropDetailsCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🌾 CROP DETAILS',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              'Crop',
              '${_getCropEmoji(_farm.cropType)} ${_farm.cropType}',
            ),
            if (_farm.farmSize != null)
              _buildDetailRow('Size', '${_farm.farmSize} acres'),
            _buildDetailRow('Planted', _formatDate(_farm.createdAt)),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveAlertsCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.notifications_active,
                    color: Colors.orange[700],
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'ACTIVE ALERTS',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (_isLoadingAlerts)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: _checkWeatherAlerts,
                    tooltip: 'Refresh alerts',
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoadingAlerts)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_farmAlerts.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 48,
                      color: Colors.green[400],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'All Clear!',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No active weather or disease alerts for this farm.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
              )
            else
              ..._farmAlerts.map((alert) => _buildAlertItem(alert)),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertItem(Alert alert) {
    Color severityColor;
    IconData severityIcon;

    switch (alert.severity.toLowerCase()) {
      case 'critical':
        severityColor = Colors.red;
        severityIcon = Icons.error;
        break;
      case 'high':
        severityColor = Colors.orange;
        severityIcon = Icons.warning;
        break;
      case 'medium':
        severityColor = Colors.amber;
        severityIcon = Icons.info;
        break;
      case 'low':
        severityColor = Colors.green;
        severityIcon = Icons.check_circle;
        break;
      default:
        severityColor = Colors.grey;
        severityIcon = Icons.circle;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: severityColor.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
        color: severityColor.withOpacity(0.05),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: severityColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(severityIcon, color: severityColor, size: 20),
        ),
        title: Text(
          alert.title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(alert.message, style: const TextStyle(fontSize: 13)),
            if (alert.metadata?['advice'] != null &&
                alert.metadata!['advice'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 16,
                      color: Colors.blue[700],
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        alert.metadata!['advice'].toString(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[900],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              _getTimeAgo(alert.createdAt),
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${(difference.inDays / 7).floor()}w ago';
  }

  Widget _buildDeleteButton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: OutlinedButton.icon(
        onPressed: () async {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Delete Farm'),
              content: Text(
                'Are you sure you want to delete ${_farm.name}? This action cannot be undone.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          );
          if (confirm == true) {
            try {
              // Step 1: Disconnect WebSocket for this farm
              if (_farm.id != null) {
                debugPrint(
                  '🔌 Disconnecting WebSocket for farm: ${_farm.name}',
                );
                WebSocketAlertService.instance.disconnectFarm(_farm.id!);
                debugPrint('✅ WebSocket disconnected for farm: ${_farm.name}');
              }

              // Step 2: Delete from backend (backend will close WebSocket on server)
              if (_farm.backendId != null) {
                try {
                  await ApiService.deleteFarmFromBackend(_farm.backendId!);
                  debugPrint(
                    '✅ Farm deleted from backend (WebSocket closed on server)',
                  );
                } catch (backendError) {
                  debugPrint('⚠️ Backend deletion failed: $backendError');
                  // Continue with local deletion even if backend fails
                }
              }

              // Step 3: Delete farm-specific alerts/notifications from local DB
              if (_farm.id != null) {
                try {
                  await FarmDatabaseHelper.instance.deleteAlertsByFarmId(
                    _farm.id!,
                  );
                  debugPrint('✅ Deleted all alerts for farm: ${_farm.name}');
                } catch (alertError) {
                  debugPrint('⚠️ Failed to delete alerts: $alertError');
                }
              }

              // Step 4: Delete farm from local database
              if (_farm.id != null) {
                await FarmDatabaseHelper.instance.deleteFarm(_farm.id!);
                debugPrint('✅ Farm deleted from local database');
              }

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Farm, WebSocket, and notifications deleted successfully',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
                Navigator.pop(context, true);
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to delete farm: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          }
        },
        icon: const Icon(Icons.delete, color: Colors.red),
        label: const Text('Delete Farm', style: TextStyle(color: Colors.red)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.red),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$label:', style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _getCropEmoji(String crop) {
    final emojis = {
      'Tomato': '🍅',
      'Potato': '🥔',
      'Corn': '🌽',
      'Grapes': '🍇',
      'Rice': '🌾',
      'Wheat': '🌾',
      'Cotton': '🌱',
      'Pepper': '🌶️',
      'Soybean': '🫘',
    };
    return emojis[crop] ?? '🌱';
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
