import 'package:agriscan_pro/services/database_helper.dart';
import 'package:agriscan_pro/services/translation_service.dart';
import 'package:flutter/material.dart';
import 'dart:io';

class ResultsScreen extends StatefulWidget {
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

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  String? _selectedLanguage;
  bool _isTranslating = false;
  Map<String, String> _translations = {};

  // Cache statistics
  int _cachedCount = 0;
  double _cacheHitRate = 0.0;

  @override
  void initState() {
    super.initState();
    // Initialize with original English text
    _translations = {
      'prediction': widget.prediction,
      'symptoms': widget.diseaseInfo?.symptoms ?? '',
      'treatment': widget.diseaseInfo?.treatment ?? '',
      'prevention': widget.diseaseInfo?.prevention ?? '',
    };
  }

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
    return Colors.red;
  }

  Future<void> _translateContent(String langCode) async {
    if (langCode == 'en') {
      // Reset to English
      setState(() {
        _selectedLanguage = 'en';
        _translations = {
          'prediction': widget.prediction,
          'symptoms': widget.diseaseInfo?.symptoms ?? '',
          'treatment': widget.diseaseInfo?.treatment ?? '',
          'prevention': widget.diseaseInfo?.prevention ?? '',
        };
      });
      return;
    }

    setState(() {
      _isTranslating = true;
    });

    try {
      // Use optimized batch translation endpoint
      final result = await TranslationService.translateBatchOptimized(
        texts: [
          widget.prediction,
          widget.diseaseInfo?.symptoms ?? '',
          widget.diseaseInfo?.treatment ?? '',
          widget.diseaseInfo?.prevention ?? '',
        ],
        targetLang: langCode,
      );

      // Convert to map format
      final translations = result.toMap([
        'prediction',
        'symptoms',
        'treatment',
        'prevention',
      ]);

      setState(() {
        _selectedLanguage = langCode;
        _translations = translations;
        _cachedCount = result.cachedCount;
        _cacheHitRate = result.cacheHitRate;
        _isTranslating = false;
      });

      // Show success message with cache stats
      final cacheMessage = result.cachedCount > 0
          ? ' (${result.cachedCount}/${result.translations.length} cached ⚡)'
          : '';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Translated to ${TranslationService.getLanguageName(langCode)}$cacheMessage',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      setState(() {
        _isTranslating = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Translation failed: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showLanguageSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select Language',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Powered by Sarvam AI - 22 Indian Languages',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: TranslationService.supportedLanguages.length,
                  itemBuilder: (context, index) {
                    final entry = TranslationService.supportedLanguages.entries
                        .elementAt(index);
                    final isSelected = _selectedLanguage == entry.key;

                    return ListTile(
                      leading: Icon(
                        Icons.language,
                        color: isSelected ? Colors.green : Colors.grey,
                      ),
                      title: Text(
                        entry.value,
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected ? Colors.green : Colors.black,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : null,
                      onTap: () {
                        Navigator.pop(context);
                        _translateContent(entry.key);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan Results"),
        actions: [
          // Translation Button with Cache Indicator
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.translate, size: 28),
                // Active translation indicator (green checkmark)
                if (_selectedLanguage != null && _selectedLanguage != 'en')
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                // Cache hit indicator (lightning bolt)
                if (_cachedCount > 0)
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        color: Colors.orange[700],
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.bolt,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            tooltip: _cachedCount > 0
                ? 'Translate (${_cacheHitRate.toStringAsFixed(0)}% cached ⚡)'
                : 'Translate to Indian Languages',
            onPressed: _isTranslating ? null : _showLanguageSelector,
          ),
        ],
      ),
      body: _isTranslating
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Translating...', style: TextStyle(fontSize: 16)),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildImageCard(),
                  const SizedBox(height: 20),
                  _buildAnalysisCard(),
                  if (widget.diseaseInfo != null) ...[
                    const SizedBox(height: 20),
                    _buildDiseaseInfoCard(),
                    const SizedBox(height: 20),
                    _buildTreatmentCard(),
                  ] else
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'No detailed information found for "${_translations['prediction']}" in the local database.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                ],
              ),
            ),
      floatingActionButton: _buildTranslateFloatingButton(),
    );
  }

  Widget _buildTranslateFloatingButton() {
    // Don't show if already translating or if it's in English
    if (_isTranslating) return const SizedBox.shrink();

    return FloatingActionButton.extended(
      onPressed: _showLanguageSelector,
      backgroundColor: _selectedLanguage != null && _selectedLanguage != 'en'
          ? Colors.green
          : Colors.blue[700],
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.translate, size: 24),
          // Lightning bolt for cache indicator
          if (_cachedCount > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.orange[700],
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.bolt, size: 12, color: Colors.white),
              ),
            ),
        ],
      ),
      label: Text(
        _selectedLanguage != null && _selectedLanguage != 'en'
            ? TranslationService.getLanguageName(
                _selectedLanguage!,
              ).split('(')[0].trim()
            : 'Translate',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildImageCard() {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Image.file(
            File(widget.imagePath),
            height: 250,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisCard() {
    final translatedPrediction =
        _translations['prediction'] ?? widget.prediction;
    final bool isHealthy = translatedPrediction.toLowerCase().contains(
      'healthy',
    );
    final Color confidenceColor = _getConfidenceColor(widget.confidence);

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
              _formatDiseaseName(translatedPrediction),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Confidence: ${(widget.confidence * 100).toStringAsFixed(1)}%',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: widget.confidence,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(confidenceColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiseaseInfoCard() {
    final symptoms =
        _translations['symptoms'] ??
        widget.diseaseInfo?.symptoms ??
        'Not available.';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Disease Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 20),
            const Text(
              'Symptoms',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(symptoms),
          ],
        ),
      ),
    );
  }

  Widget _buildTreatmentCard() {
    final treatment =
        _translations['treatment'] ??
        widget.diseaseInfo?.treatment ??
        'Not available.';
    final prevention =
        _translations['prevention'] ??
        widget.diseaseInfo?.prevention ??
        'Not available.';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recommendations',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 20),
            const Text(
              'Treatment',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(treatment),
            const SizedBox(height: 12),
            const Text(
              'Prevention',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(prevention),
          ],
        ),
      ),
    );
  }
}
