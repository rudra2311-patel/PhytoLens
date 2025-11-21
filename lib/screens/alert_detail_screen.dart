import 'package:flutter/material.dart';
import '../models/alert_model.dart';

class AlertDetailScreen extends StatelessWidget {
  final Alert alert;

  const AlertDetailScreen({super.key, required this.alert});

  Color get _severityColor {
    switch (alert.severity) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alert Details'),
        backgroundColor: const Color(0xFFFF9800),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeaderCard(),
          const SizedBox(height: 16),
          _buildLocationCard(),
          const SizedBox(height: 16),
          if (alert.type == 'disease') _buildRiskDetailsCard(),
          if (alert.type == 'weather') _buildWeatherConditionsCard(),
          if (alert.severity == 'high' || alert.severity == 'medium')
            _buildRecommendedActionsCard(),
          const SizedBox(height: 16),
          _buildActionButtons(context),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      color: _severityColor.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(alert.icon, style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    alert.title.toUpperCase(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _severityColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(alert.message, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('📍 Location', alert.farmName ?? 'Unknown'),
            const SizedBox(height: 8),
            _buildDetailRow('⏰ Time', _formatDateTime(alert.createdAt)),
          ],
        ),
      ),
    );
  }

  Widget _buildRiskDetailsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📊 RISK DETAILS',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildDetailRow('Disease', 'Late Blight (Fungal)'),
            _buildDetailRow('Severity', alert.severity.toUpperCase()),
            _buildDetailRow('Confidence', '87%'),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherConditionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🌡️ WEATHER CONDITIONS',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildDetailRow('Temperature', '28°C'),
            _buildDetailRow('Humidity', '75% (High)'),
            _buildDetailRow('Rain Probability', '20%'),
            _buildDetailRow('Wind', '12 km/h'),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendedActionsCard() {
    final actions = alert.severity == 'high'
        ? [
            'Apply copper-based fungicide',
            'Improve field drainage',
            'Remove infected leaves',
            'Monitor for 48 hours',
          ]
        : [
            'Monitor humidity levels',
            'Check plants for early symptoms',
            'Prepare fungicide if needed',
          ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '💡 RECOMMENDED ACTIONS',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...actions.map(
              (action) => CheckboxListTile(
                title: Text(action),
                value: false,
                onChanged: (value) {
                  // TODO: Save action completion
                },
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              // TODO: Navigate to farm details
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Navigate to farm')));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
            ),
            child: const Text('View Farm'),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$label:', style: TextStyle(color: Colors.grey[700])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final alertDate = DateTime(date.year, date.month, date.day);

    String dateStr;
    if (alertDate == today) {
      dateStr = 'Today';
    } else if (alertDate == today.subtract(const Duration(days: 1))) {
      dateStr = 'Yesterday';
    } else {
      dateStr = '${date.day}/${date.month}/${date.year}';
    }

    return '$dateStr, ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
