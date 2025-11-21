import 'package:flutter/material.dart';
import '../models/farm_model.dart';
import '../services/farm_database_helper.dart';
import '../services/api_services.dart';
import '../services/weather_alert_service.dart';
import 'weather_forecast_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with AutomaticKeepAliveClientMixin {
  List<Farm> _farms = [];
  Farm? _selectedFarm;
  Map<String, dynamic>? _weatherData;
  Map<String, dynamic>? _riskAssessment;
  bool _isLoading = false;

  @override
  bool get wantKeepAlive => false; // Don't keep state alive, always refresh

  @override
  void initState() {
    super.initState();
    _loadFarms();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload farms when navigating back to this screen
    _loadFarms();
  }

  Future<void> _loadFarms() async {
    // First, clean up any duplicates in the database
    await FarmDatabaseHelper.instance.removeDuplicateFarms();

    final farms = await FarmDatabaseHelper.instance.getAllFarms();

    // Deduplicate farms based on backend_id or local id (as extra safety)
    final Map<String, Farm> uniqueFarms = {};
    for (var farm in farms) {
      final key =
          farm.backendId ??
          farm.id?.toString() ??
          '${farm.latitude}_${farm.longitude}';
      if (!uniqueFarms.containsKey(key)) {
        uniqueFarms[key] = farm;
      }
    }

    final deduplicatedFarms = uniqueFarms.values.toList();

    setState(() {
      _farms = deduplicatedFarms;
      if (deduplicatedFarms.isNotEmpty) {
        // Keep selected farm if it still exists, otherwise select first
        if (_selectedFarm != null) {
          final stillExists = deduplicatedFarms.any(
            (f) =>
                (f.backendId != null &&
                    f.backendId == _selectedFarm!.backendId) ||
                (f.id != null && f.id == _selectedFarm!.id),
          );
          if (!stillExists) {
            _selectedFarm = deduplicatedFarms.first;
          }
        } else {
          _selectedFarm = deduplicatedFarms.first;
        }
        // Always reload weather data after loading farms
        _loadWeatherData();
      } else {
        _selectedFarm = null;
        _weatherData = null;
      }
    });
  }

  Future<void> _loadWeatherData() async {
    if (_selectedFarm == null) return;

    setState(() => _isLoading = true);
    try {
      final weatherResponse = await ApiService.getCurrentWeather(
        lat: _selectedFarm!.latitude,
        lon: _selectedFarm!.longitude,
      );

      final riskResponse = await ApiService.getWeatherRisk(
        lat: _selectedFarm!.latitude,
        lon: _selectedFarm!.longitude,
        crop: _selectedFarm!.cropType,
      );

      // Create weather alerts based on risk assessment
      await WeatherAlertService.checkAndCreateWeatherAlerts(_selectedFarm!);

      // Backend returns: {weather: {...}, risk: {risk, severity, message, advice}}
      final riskData = riskResponse['risk'] ?? {};
      final severity = riskData['severity'] ?? 'low';
      final riskMessage = riskData['message'] ?? 'No immediate risk';
      final advice = riskData['advice'] ?? '';

      setState(() {
        _weatherData = {
          'temp': weatherResponse['temperature']?.round() ?? 0,
          'condition': _getWeatherCondition(weatherResponse),
          'humidity': weatherResponse['humidity'] ?? 0,
          'wind': weatherResponse['wind_speed']?.round() ?? 0,
          'rain_chance': (weatherResponse['rain_probability'] ?? 0).round(),
          'cloud_cover': 40,
        };

        _riskAssessment = {
          'level': severity,
          'disease': riskMessage,
          'confidence': severity == 'critical'
              ? 0.95
              : severity == 'high'
              ? 0.85
              : severity == 'medium'
              ? 0.70
              : 0.50,
          'recommendations': advice.isNotEmpty ? [advice] : [],
        };
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Weather API failed: $e');
      setState(() {
        _isLoading = false;
        _weatherData = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load weather data: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  String _getWeatherCondition(Map<String, dynamic> weather) {
    final rainfall = weather['rainfall'] ?? 0.0;
    final temp = weather['temperature'] ?? 20.0;

    if (rainfall > 5) return 'Rainy';
    if (rainfall > 0) return 'Light Rain';
    if (temp > 30) return 'Hot & Sunny';
    if (temp < 15) return 'Cool';
    return 'Partly Cloudy';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Weather Dashboard'),
        backgroundColor: const Color(0xFF2196F3),
        elevation: 0,
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () async {
                await _loadFarms();
              },
              tooltip: 'Refresh Weather & Farms',
            ),
        ],
      ),
      body: _farms.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: () async {
                await _loadFarms();
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildFarmSelector(),
                  const SizedBox(height: 16),
                  if (_isLoading)
                    _buildLoadingState()
                  else if (_weatherData != null) ...[
                    _buildWeatherCard(),
                    const SizedBox(height: 12),
                    _buildForecastButton(),
                    const SizedBox(height: 16),
                    _buildDetailedWeatherInfo(),
                    const SizedBox(height: 16),
                    _buildRiskAssessmentCard(),
                    const SizedBox(height: 16),
                    _buildRecommendedActions(),
                    const SizedBox(height: 20),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.wb_sunny_outlined,
                size: 80,
                color: Colors.blue[300],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Farms Yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Add a farm to view real-time weather\nand disease risk insights',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                // Navigate to Farms tab (index 2) in MainNavigationScreen
                // The Farms screen has the + button to add new farms
                try {
                  // Find the MainNavigationScreen in the widget tree
                  final scaffoldContext = context
                      .findAncestorStateOfType<ScaffoldState>()
                      ?.context;
                  if (scaffoldContext != null) {
                    // Try to access parent navigation
                    Navigator.of(context).popUntil((route) => route.isFirst);
                    // This will go back to MainNavigationScreen
                    // Then we need to programmatically switch tabs
                  }
                } catch (e) {
                  debugPrint('Navigation error: $e');
                }

                // Show helpful message
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      '📍 Please tap the "Farms" tab at the bottom, then tap + to add a farm',
                    ),
                    duration: Duration(seconds: 4),
                    backgroundColor: Color(0xFF2196F3),
                  ),
                );
              },
              icon: const Icon(Icons.add_rounded, size: 22),
              label: const Text('Add Your First Farm'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFarmSelector() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: Colors.grey[700], size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Select Farm',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Farm>(
                  value: _selectedFarm,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down),
                  items: _farms.map((farm) {
                    return DropdownMenuItem(
                      value: farm,
                      child: Row(
                        children: [
                          Text(
                            _getCropEmoji(farm.cropType),
                            style: const TextStyle(fontSize: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${farm.name} (${farm.cropType})',
                              style: const TextStyle(fontSize: 15),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (farm) {
                    setState(() => _selectedFarm = farm);
                    _loadWeatherData();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        height: 200,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[400]!),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading weather data...',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherCard() {
    final temp = _weatherData!['temp'];
    final condition = _weatherData!['condition'];

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$temp°C',
                      style: const TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      condition,
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                Icon(
                  _getWeatherIcon(condition),
                  size: 72,
                  color: Colors.white.withOpacity(0.9),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildWeatherStat(
                    Icons.water_drop,
                    '${_weatherData!['humidity']}%',
                    'Humidity',
                  ),
                  _buildWeatherStat(
                    Icons.air,
                    '${_weatherData!['wind']} km/h',
                    'Wind',
                  ),
                  _buildWeatherStat(
                    Icons.umbrella,
                    '${_weatherData!['rain_chance']}%',
                    'Rain',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  IconData _getWeatherIcon(String condition) {
    if (condition.contains('Rain')) return Icons.water_drop;
    if (condition.contains('Sunny') || condition.contains('Hot')) {
      return Icons.wb_sunny;
    }
    if (condition.contains('Cloud')) return Icons.cloud;
    return Icons.wb_cloudy;
  }

  Widget _buildDetailedWeatherInfo() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                  child: Icon(
                    Icons.info_outline,
                    color: Colors.blue[700],
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Weather Details',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildDetailCard(
                    Icons.thermostat,
                    'Temperature',
                    '${_weatherData!['temp']}°C',
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDetailCard(
                    Icons.water_drop,
                    'Humidity',
                    '${_weatherData!['humidity']}%',
                    Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildDetailCard(
                    Icons.air,
                    'Wind Speed',
                    '${_weatherData!['wind']} km/h',
                    Colors.teal,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDetailCard(
                    Icons.cloud,
                    'Cloud Cover',
                    '${_weatherData!['cloud_cover']}%',
                    Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildWeatherTip(),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherTip() {
    String tip = '';
    IconData icon = Icons.wb_sunny;
    Color tipColor = Colors.green;

    final temp = _weatherData!['temp'];
    final humidity = _weatherData!['humidity'];
    final rainChance = _weatherData!['rain_chance'];

    if (rainChance > 60) {
      tip = 'High chance of rain. Consider postponing spraying operations.';
      icon = Icons.umbrella;
      tipColor = Colors.blue;
    } else if (temp > 35) {
      tip = 'Very hot weather. Ensure adequate irrigation and monitor plants.';
      icon = Icons.warning_amber;
      tipColor = Colors.orange;
    } else if (humidity > 80) {
      tip = 'High humidity. Watch for fungal disease development.';
      icon = Icons.water_drop;
      tipColor = Colors.blue;
    } else if (temp < 15) {
      tip = 'Cool weather. Monitor for frost and protect sensitive crops.';
      icon = Icons.ac_unit;
      tipColor = Colors.lightBlue;
    } else {
      tip = 'Favorable weather conditions for farming activities.';
      icon = Icons.check_circle;
      tipColor = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tipColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: tipColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tip,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[800],
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskAssessmentCard() {
    final level = _riskAssessment!['level'];
    Color riskColor = level == 'high'
        ? const Color(0xFFE53935)
        : level == 'medium'
        ? const Color(0xFFFB8C00)
        : const Color(0xFF43A047);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: riskColor.withOpacity(0.3), width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: riskColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.health_and_safety,
                    color: riskColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${level.toString().toUpperCase()} RISK',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: riskColor,
                        ),
                      ),
                      if (_riskAssessment!['confidence'] > 0)
                        Text(
                          '${(_riskAssessment!['confidence'] * 100).toInt()}% Confidence',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Disease Risk',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _riskAssessment!['disease'],
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            if (_riskAssessment!['recommendations'] is List &&
                (_riskAssessment!['recommendations'] as List).isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Recommendations',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...(_riskAssessment!['recommendations'] as List)
                  .take(3)
                  .map(
                    (rec) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 7),
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: riskColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              rec,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[700],
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
            if (_riskAssessment!['reasons'] is List &&
                (_riskAssessment!['reasons'] as List).isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Reasons',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...(_riskAssessment!['reasons'] as List).map(
                (reason) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 7),
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: riskColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          reason,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendedActions() {
    final actions =
        _riskAssessment!['actions'] ??
        _riskAssessment!['recommendations'] ??
        [];

    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.lightbulb_outline,
                    color: Colors.amber,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Action Items',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...((actions as List)
                .take(4)
                .map(
                  (action) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          color: Colors.grey[400],
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            action,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildForecastButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          if (_selectedFarm != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    WeatherForecastScreen(farm: _selectedFarm!),
              ),
            );
          }
        },
        icon: const Icon(Icons.calendar_today, size: 20),
        label: const Text(
          'View 3-Day Forecast & Insights',
          style: TextStyle(fontSize: 16),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[600],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
      ),
    );
  }

  String _getCropEmoji(String crop) {
    switch (crop.toLowerCase()) {
      case 'tomato':
        return '🍅';
      case 'potato':
        return '🥔';
      case 'corn':
        return '🌽';
      case 'grapes':
        return '🍇';
      case 'rice':
      case 'wheat':
        return '🌾';
      case 'cotton':
        return '☁️';
      case 'pepper':
        return '🌶️';
      case 'soybean':
        return '🫘';
      default:
        return '🌱';
    }
  }
}
