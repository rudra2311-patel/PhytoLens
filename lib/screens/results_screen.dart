import 'package:agriscan_pro/services/database_helper.dart';
import 'package:flutter/material.dart';
import 'dart:io';

class ResultsScreen extends StatelessWidget {
  final String imagePath;
  final String prediction;
  final double confidence;
  final Disease? diseaseInfo;

  const ResultsScreen({
    super.key,
    required this.imagePath,
    required this.prediction,
    required this.confidence,
    this.diseaseInfo,
  });

  String _formatDiseaseName(String disease) {
    return disease
        .replaceAll('___', ' ')
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return Colors.green;
    if (confidence >= 0.6) return Colors.orange;
    return Colors.red; // Assuming AppColors.error is red
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan Results"), // Assuming AppStrings exists
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0), // Assuming AppDimensions exists
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildImageCard(),
            const SizedBox(height: 20),
            _buildAnalysisCard(),
            if (diseaseInfo != null) ...[
              const SizedBox(height: 20),
              _buildDiseaseInfoCard(),
              const SizedBox(height: 20),
              _buildTreatmentCard(),
            ] else 
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'No detailed information found for "$prediction" in the local database.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageCard() {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Image.file(File(imagePath), height: 250, width: double.infinity, fit: BoxFit.cover),
        ],
      ),
    );
  }

  Widget _buildAnalysisCard() {
    final bool isHealthy = prediction.toLowerCase().contains('healthy');
    final Color confidenceColor = _getConfidenceColor(confidence);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(
              isHealthy ? Icons.check_circle : Icons.warning_amber_rounded,
              color: isHealthy ? Colors.green : confidenceColor,
              size: 40,
            ),
            const SizedBox(height: 8),
            Text(
              _formatDiseaseName(prediction),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Confidence: ${(confidence * 100).toStringAsFixed(1)}%',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: confidence,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(confidenceColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiseaseInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Disease Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(height: 20),
            const Text('Symptoms', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(diseaseInfo?.symptoms ?? 'Not available.'),
          ],
        ),
      ),
    );
  }

  Widget _buildTreatmentCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Recommendations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(height: 20),
            const Text('Treatment', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(diseaseInfo?.treatment ?? 'Not available.'),
            const SizedBox(height: 12),
            const Text('Prevention', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(diseaseInfo?.prevention ?? 'Not available.'),
          ],
        ),
      ),
    );
  }
}