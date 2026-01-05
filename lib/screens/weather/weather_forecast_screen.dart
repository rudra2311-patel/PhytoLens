import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/farm_model.dart';
import '../../services/api_services.dart';

class WeatherForecastScreen extends StatefulWidget {
  final Farm farm;

  const WeatherForecastScreen({super.key, required this.farm});

  @override
  _WeatherForecastScreenState createState() => _WeatherForecastScreenState();
}

class _WeatherForecastScreenState extends State<WeatherForecastScreen> {
  Map<String, dynamic>? _currentWeather;
  Map<String, dynamic>? _riskData;
  List<Map<String, dynamic>> _forecast = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadWeatherData();
  }

  Future<void> _loadWeatherData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Fetch current weather
      final weatherResponse = await ApiService.getCurrentWeather(
        lat: widget.farm.latitude,
        lon: widget.farm.longitude,
      );

      // Fetch risk assessment (contains full weather data with hourly)
      final riskResponse = await ApiService.getWeatherRisk(
        lat: widget.farm.latitude,
        lon: widget.farm.longitude,
        crop: widget.farm.cropType,
      );

      // Generate 3-day forecast from hourly data returned by risk endpoint
      final weatherData = riskResponse['weather'];
      if (weatherData != null && weatherData['hourly'] != null) {
        _forecast = _generate3DayForecast(weatherData['hourly']);
      } else {
        _forecast = [];
        debugPrint('⚠️ No hourly data available for forecast');
      }

      setState(() {
        _currentWeather = weatherResponse;
        _riskData = riskResponse['risk'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _generate3DayForecast(
    Map<String, dynamic> hourlyData,
  ) {
    try {
      final List<dynamic>? times = hourlyData['time'];
      final List<dynamic>? temps = hourlyData['temperature_2m'];
      final List<dynamic>? humidity = hourlyData['relativehumidity_2m'];
      final List<dynamic>? rain = hourlyData['rain'];
      final List<dynamic>? rainProb = hourlyData['precipitation_probability'];

      if (times == null || times.isEmpty || temps == null || temps.isEmpty) {
        debugPrint('❌ Missing required forecast data');
        return [];
      }

      final Map<String, Map<String, dynamic>> dailyData = {};

      for (int i = 0; i < times.length; i++) {
        try {
          final dateTime = DateTime.parse(times[i].toString());
          final dateKey = DateFormat('yyyy-MM-dd').format(dateTime);

          if (!dailyData.containsKey(dateKey)) {
            dailyData[dateKey] = {
              'date': dateTime,
              'temps': <double>[],
              'humidity': <double>[],
              'rain': <double>[],
              'rainProb': <double>[],
            };
          }

          dailyData[dateKey]!['temps'].add(temps[i].toDouble());
          if (humidity != null && i < humidity.length) {
            dailyData[dateKey]!['humidity'].add(humidity[i].toDouble());
          }
          if (rain != null && i < rain.length) {
            dailyData[dateKey]!['rain'].add(rain[i].toDouble());
          }
          if (rainProb != null && i < rainProb.length) {
            dailyData[dateKey]!['rainProb'].add(rainProb[i].toDouble());
          }
        } catch (e) {
          debugPrint('Error parsing forecast data: $e');
        }
      }

      // Convert to forecast list
      return dailyData.entries.take(3).map((entry) {
        final temps = entry.value['temps'] as List<double>;
        final humidityList = entry.value['humidity'] as List<double>;
        final rainList = entry.value['rain'] as List<double>;
        final rainProbList = entry.value['rainProb'] as List<double>;

        return {
          'date': entry.value['date'],
          'tempMax': temps.isNotEmpty
              ? temps.reduce((a, b) => a > b ? a : b)
              : 0.0,
          'tempMin': temps.isNotEmpty
              ? temps.reduce((a, b) => a < b ? a : b)
              : 0.0,
          'humidity': humidityList.isNotEmpty
              ? humidityList.reduce((a, b) => a + b) / humidityList.length
              : 0.0,
          'rainfall': rainList.isNotEmpty
              ? rainList.reduce((a, b) => a + b)
              : 0.0,
          'rainChance': rainProbList.isNotEmpty
              ? rainProbList.reduce((a, b) => a > b ? a : b)
              : 0.0,
        };
      }).toList();
    } catch (e) {
      debugPrint('❌ Error generating 3-day forecast: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('${widget.farm.name} Weather'),
        backgroundColor: const Color(0xFF2196F3),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadWeatherData,
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _error != null
          ? _buildErrorState()
          : RefreshIndicator(
              onRefresh: _loadWeatherData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _buildCurrentWeatherHeader(),
                    _buildRiskAssessmentCard(),
                    _buildForecastSection(),
                    _buildPersonalizedInsights(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.blue[700]),
          const SizedBox(height: 16),
          Text(
            'Loading weather data...',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Failed to load weather data',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadWeatherData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentWeatherHeader() {
    if (_currentWeather == null) return const SizedBox();

    final temp = (_currentWeather!['temperature'] ?? 0).round();
    final humidity = _currentWeather!['humidity'] ?? 0;
    final windSpeed = _currentWeather!['wind_speed'] ?? 0;
    final rainfall = _currentWeather!['rainfall_mm'] ?? 0.0;

    final condition = _getWeatherCondition(temp.toDouble(), rainfall);
    final icon = _getWeatherIcon(condition);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue[700]!, Colors.blue[500]!],
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: Colors.white70, size: 18),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  widget.farm.location,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Icon(icon, size: 80, color: Colors.white),
          const SizedBox(height: 16),
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
            style: const TextStyle(fontSize: 20, color: Colors.white70),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildWeatherMetric(Icons.water_drop, '$humidity%', 'Humidity'),
              _buildWeatherMetric(
                Icons.air,
                '${windSpeed.round()} km/h',
                'Wind',
              ),
              _buildWeatherMetric(
                Icons.umbrella,
                '${rainfall.toStringAsFixed(1)}mm',
                'Rain',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherMetric(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 24),
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
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildRiskAssessmentCard() {
    if (_riskData == null) return const SizedBox();

    final severity = _riskData!['severity'] ?? 'low';
    final message = _riskData!['message'] ?? 'No risk detected';
    final advice = _riskData!['advice'] ?? '';

    final Color riskColor = severity == 'critical'
        ? Colors.red[700]!
        : severity == 'high'
        ? const Color(0xFFE53935)
        : severity == 'medium'
        ? const Color(0xFFFB8C00)
        : const Color(0xFF43A047);

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: riskColor.withOpacity(0.3), width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: riskColor.withOpacity(0.15),
                    shape: BoxShape.circle,
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
                        '${severity.toUpperCase()} RISK',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: riskColor,
                        ),
                      ),
                      Text(
                        'Crop: ${widget.farm.cropType}',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
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
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: riskColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Risk Details',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[800],
                      height: 1.4,
                    ),
                  ),
                  if (advice.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          color: Colors.amber[700],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Recommendation',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      advice,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[800],
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForecastSection() {
    if (_forecast.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.calendar_today,
                  color: Colors.blue[700],
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '3-Day Forecast',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _forecast.length,
          itemBuilder: (context, index) =>
              _buildForecastCard(_forecast[index], index),
        ),
      ],
    );
  }

  Widget _buildForecastCard(Map<String, dynamic> forecast, int dayIndex) {
    final date = forecast['date'] as DateTime;
    final tempMax = forecast['tempMax'].round();
    final tempMin = forecast['tempMin'].round();
    final humidity = forecast['humidity'].round();
    final rainfall = forecast['rainfall'];
    final rainChance = forecast['rainChance'].round();

    final dayName = dayIndex == 0
        ? 'Today'
        : dayIndex == 1
        ? 'Tomorrow'
        : DateFormat('EEEE').format(date);
    final dateStr = DateFormat('MMM dd').format(date);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dayName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      dateStr,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Icon(
                      _getWeatherIcon(
                        _getWeatherCondition(tempMax.toDouble(), rainfall),
                      ),
                      size: 36,
                      color: Colors.blue[700],
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$tempMax°C',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '$tempMin°C',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildForecastMetric(
                  Icons.water_drop,
                  '$humidity%',
                  'Humidity',
                  Colors.blue,
                ),
                _buildForecastMetric(
                  Icons.umbrella,
                  '$rainChance%',
                  'Rain',
                  Colors.indigo,
                ),
                _buildForecastMetric(
                  Icons.water,
                  '${rainfall.toStringAsFixed(1)}mm',
                  'Rainfall',
                  Colors.cyan,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForecastMetric(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color.withOpacity(0.7), size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildPersonalizedInsights() {
    final insights = _generateInsights();
    if (insights.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.tips_and_updates,
                  color: Colors.purple[700],
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Personalized Insights',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: insights.length,
          itemBuilder: (context, index) {
            final insight = insights[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: insight['color'].withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    insight['icon'],
                    color: insight['color'],
                    size: 24,
                  ),
                ),
                title: Text(
                  insight['title'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                subtitle: Text(
                  insight['description'],
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _generateInsights() {
    final insights = <Map<String, dynamic>>[];

    if (_currentWeather == null || _forecast.isEmpty) return insights;

    final temp = (_currentWeather!['temperature'] ?? 0).round();
    final humidity = _currentWeather!['humidity'] ?? 0;
    final rainfall = _currentWeather!['rainfall_mm'] ?? 0.0;

    // Temperature insights
    if (temp > 35) {
      insights.add({
        'icon': Icons.wb_sunny,
        'color': Colors.orange,
        'title': 'High Temperature Alert',
        'description':
            'Ensure adequate irrigation. ${widget.farm.cropType} may require extra watering in this heat.',
      });
    } else if (temp < 10) {
      insights.add({
        'icon': Icons.ac_unit,
        'color': Colors.blue,
        'title': 'Cold Weather Warning',
        'description':
            'Protect ${widget.farm.cropType} from frost. Consider covering crops overnight.',
      });
    }

    // Humidity insights
    if (humidity > 80) {
      insights.add({
        'icon': Icons.water_damage,
        'color': Colors.cyan,
        'title': 'High Humidity Detected',
        'description':
            'Increased fungal disease risk. Monitor plants closely for signs of infection.',
      });
    }

    // Rainfall insights
    if (rainfall > 20) {
      insights.add({
        'icon': Icons.umbrella,
        'color': Colors.indigo,
        'title': 'Heavy Rainfall Expected',
        'description':
            'Check drainage systems. Waterlogging can damage ${widget.farm.cropType} roots.',
      });
    }

    // Forecast-based insights
    final avgTemp =
        _forecast
            .map((f) => (f['tempMax'] + f['tempMin']) / 2)
            .reduce((a, b) => a + b) /
        _forecast.length;
    if (avgTemp > 30) {
      insights.add({
        'icon': Icons.trending_up,
        'color': Colors.red,
        'title': 'Warm Week Ahead',
        'description':
            'Next 3 days will be warm. Plan irrigation schedule accordingly.',
      });
    }

    return insights;
  }

  String _getWeatherCondition(double temp, double rainfall) {
    if (rainfall > 5) return 'Rainy';
    if (rainfall > 0) return 'Light Rain';
    if (temp > 30) return 'Hot & Sunny';
    if (temp < 15) return 'Cool';
    return 'Partly Cloudy';
  }

  IconData _getWeatherIcon(String condition) {
    if (condition.contains('Rain')) return Icons.water_drop;
    if (condition.contains('Sunny') || condition.contains('Hot')) {
      return Icons.wb_sunny;
    }
    if (condition.contains('Cloud')) return Icons.cloud;
    if (condition.contains('Cool')) return Icons.ac_unit;
    return Icons.wb_cloudy;
  }
}
