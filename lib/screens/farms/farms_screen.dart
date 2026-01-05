import 'package:flutter/material.dart';
import '../../models/farm_model.dart';
import '../../services/farm_database_helper.dart';
import '../../services/api_services.dart';
import '../../services/websocket_alert_service.dart';
import '../../services/auth_services.dart';
import 'add_farm_screen.dart';
import 'farm_details_screen.dart';

class FarmsScreen extends StatefulWidget {
  const FarmsScreen({super.key});

  @override
  _FarmsScreenState createState() => _FarmsScreenState();
}

class _FarmsScreenState extends State<FarmsScreen> {
  List<Farm> _farms = [];
  bool _isLoading = true;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadFarms();
  }

  Future<void> _loadFarms() async {
    setState(() => _isLoading = true);

    // Load local farms first
    final localFarms = await FarmDatabaseHelper.instance.getAllFarms();
    setState(() {
      _farms = localFarms;
      _isLoading = false;
    });

    // Then sync with backend in the background
    _syncWithBackend();
  }

  Future<void> _syncWithBackend() async {
    setState(() => _isSyncing = true);

    try {
      // Get current user id to attach to locally created backend farms
      final currentUserId = await AuthService.getUserId();

      // Fetch farms from backend
      final backendFarms = await ApiService.getMyFarms();

      // Merge with local database
      for (var backendFarmJson in backendFarms) {
        final backendId = backendFarmJson['id'];

        // Check if farm already exists locally
        final existingFarm = await FarmDatabaseHelper.instance
            .getFarmByBackendId(backendId);

        if (existingFarm == null) {
          // New farm from backend, create locally and attach user id
          var newFarm = Farm.fromBackendJson(backendFarmJson);
          if (currentUserId != null) {
            newFarm = newFarm.copyWith(userId: currentUserId);
          }
          await FarmDatabaseHelper.instance.createFarm(newFarm);
        }
      }

      // Reload farms after sync
      final updatedFarms = await FarmDatabaseHelper.instance.getAllFarms();
      setState(() {
        _farms = updatedFarms;
      });
    } catch (e) {
      debugPrint('Backend sync failed: $e');
      // Don't show error to user, just use local data
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  /// Connect newly added farms to WebSocket
  Future<void> _connectNewFarmsToWebSocket() async {
    try {
      final wsService = WebSocketAlertService.instance;

      for (var farm in _farms) {
        if (farm.id != null && !wsService.isConnected(farm.id!)) {
          await wsService.connectForFarm(farm);
          debugPrint('🔌 Connected WebSocket for new farm: ${farm.name}');
        }
      }
    } catch (e) {
      debugPrint('❌ Error connecting new farms to WebSocket: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Row(
          children: [
            const Text('My Farms'),
            if (_isSyncing) ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Syncing',
                      style: TextStyle(fontSize: 12, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        backgroundColor: const Color(0xFF4CAF50),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddFarmScreen()),
              );
              if (result == true) {
                await _loadFarms();
                // Connect new farms to WebSocket
                _connectNewFarmsToWebSocket();
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Card(
                margin: const EdgeInsets.all(24),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Loading farms...'),
                    ],
                  ),
                ),
              ),
            )
          : _farms.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _loadFarms,
              child: Column(
                children: [
                  _buildSummaryCard(),
                  Expanded(child: _buildFarmsList()),
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.green[50],
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.agriculture, size: 64, color: Colors.green[700]),
          ),
          const SizedBox(height: 24),
          const Text(
            'No farms yet',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Start by adding your first farm',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddFarmScreen()),
              );
              if (result == true) _loadFarms();
            },
            icon: const Icon(Icons.add),
            label: const Text('Add First Farm'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    int highRisk = _farms.where((f) => f.riskLevel == 'high').length;
    int mediumRisk = _farms.where((f) => f.riskLevel == 'medium').length;
    int lowRisk = _farms.where((f) => f.riskLevel == 'low').length;

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.analytics, color: Colors.blue[700]),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Summary',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem(
                  'Total',
                  _farms.length.toString(),
                  Colors.blue,
                  Icons.agriculture,
                ),
                _buildSummaryItem(
                  'High Risk',
                  highRisk.toString(),
                  Colors.red,
                  Icons.warning_amber_rounded,
                ),
                _buildSummaryItem(
                  'Medium',
                  mediumRisk.toString(),
                  Colors.orange,
                  Icons.info_outline,
                ),
                _buildSummaryItem(
                  'Low',
                  lowRisk.toString(),
                  Colors.green,
                  Icons.check_circle_outline,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildFarmsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _farms.length,
      itemBuilder: (context, index) {
        final farm = _farms[index];
        return _buildFarmCard(farm);
      },
    );
  }

  Widget _buildFarmCard(Farm farm) {
    Color riskColor = farm.riskLevel == 'high'
        ? Colors.red
        : farm.riskLevel == 'medium'
        ? Colors.orange
        : Colors.green;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FarmDetailsScreen(farm: farm),
            ),
          );
          if (result == true) _loadFarms();
        },
        borderRadius: BorderRadius.circular(12),
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
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.agriculture,
                      color: Colors.green[700],
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      farm.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () => _showFarmOptions(farm),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      farm.location,
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.grass, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${_getCropEmoji(farm.cropType)} ${farm.cropType}',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: riskColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: riskColor.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      farm.riskLevel == 'high'
                          ? Icons.warning_amber_rounded
                          : farm.riskLevel == 'medium'
                          ? Icons.info_outline
                          : Icons.check_circle_outline,
                      size: 16,
                      color: riskColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${farm.riskLevel?.toUpperCase() ?? 'UNKNOWN'} RISK',
                      style: TextStyle(
                        color: riskColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Added: ${_formatDate(farm.createdAt)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FarmDetailsScreen(farm: farm),
                      ),
                    );
                    if (result == true) _loadFarms();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('View Details'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFarmOptions(Farm farm) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Edit Farm'),
            onTap: () {
              Navigator.pop(context);
              // TODO: Navigate to edit farm screen
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text(
              'Delete Farm',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () async {
              Navigator.pop(context);
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Farm'),
                  content: Text(
                    'Are you sure you want to delete ${farm.name}?',
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
                  if (farm.id != null) {
                    debugPrint(
                      '🔌 Disconnecting WebSocket for farm: ${farm.name}',
                    );
                    WebSocketAlertService.instance.disconnectFarm(farm.id!);
                    debugPrint(
                      '✅ WebSocket disconnected for farm: ${farm.name}',
                    );
                  }

                  // Step 2: Delete from backend (backend will close WebSocket on server)
                  if (farm.backendId != null) {
                    try {
                      await ApiService.deleteFarmFromBackend(farm.backendId!);
                      debugPrint(
                        '✅ Farm deleted from backend (WebSocket closed on server)',
                      );
                    } catch (backendError) {
                      debugPrint('⚠️ Backend deletion failed: $backendError');
                      // Continue with local deletion
                    }
                  }

                  // Step 3: Delete farm-specific alerts/notifications from local DB
                  if (farm.id != null) {
                    try {
                      await FarmDatabaseHelper.instance.deleteAlertsByFarmId(
                        farm.id!,
                      );
                      debugPrint('✅ Deleted all alerts for farm: ${farm.name}');
                    } catch (alertError) {
                      debugPrint('⚠️ Failed to delete alerts: $alertError');
                    }
                  }

                  // Step 4: Delete farm from local database
                  if (farm.id != null) {
                    await FarmDatabaseHelper.instance.deleteFarm(farm.id!);
                    debugPrint('✅ Farm deleted from local database');
                  }

                  _loadFarms();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Farm, WebSocket, and notifications deleted successfully',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to delete: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
          ),
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
    return '${date.day}/${date.month}/${date.year}';
  }
}
