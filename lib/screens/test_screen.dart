import 'package:agriscan_pro/utils/plant_disease_classifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import '../services/database_helper.dart'; // Import your new database helper

class TestScreen extends StatefulWidget {
  const TestScreen({super.key});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  final PlantDiseaseClassifier _classifier = PlantDiseaseClassifier();
  final DatabaseHelper _dbHelper = DatabaseHelper();

  String _status = 'Ready to test';
  String _result = '';
  bool _isLoading = false;
  bool _modelLoaded = false;
  final String _testImagePath = 'assets/test_images/Tomato_Late_Blight.jpg';

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  /// Load the TensorFlow Lite model
  Future<void> _loadModel() async {
    setState(() {
      _isLoading = true;
      _status = 'Loading model...';
    });

    final success = await _classifier.loadModel();

    setState(() {
      _isLoading = false;
      _modelLoaded = success;
      _status = success
          ? 'Model loaded successfully! Ready to test.'
          : 'Failed to load model. Check your assets.';
    });
  }

  /// Run test classification
  /// Run test classification
  Future<void> _runTest() async {
    if (!_modelLoaded) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Model not loaded yet!')));
      return;
    }

    setState(() {
      _isLoading = true;
      _status = 'Running classification test...';
      _result = '';
    });

    try {
      // 1. Load the test image from assets
      final byteData = await rootBundle.load(_testImagePath);
      final testImage = img.decodeImage(byteData.buffer.asUint8List());

      if (testImage == null) {
        setState(() {
          _isLoading = false;
          _status = 'Error: Could not load test image';
          _result = 'Make sure $_testImagePath exists in your assets folder.';
        });
        return;
      }

      // 2. Get the full prediction string from your AI classifier
      final fullPredictionString = await _classifier.classifyPlantDisease(
        testImage,
      );

      // --- FIX START ---
      // 3. Extract ONLY the disease name from the full string for the database query.
      // It splits "Tomato___Late_blight (97.8% confidence)" into two parts and takes the first one.
      final diseaseName = fullPredictionString.split('(').first.trim();
      // --- FIX END ---

      // 4. Get the detailed advice from your database using the clean name
      final diseaseInfo = await _dbHelper.getDisease(diseaseName);

      // 5. Update the UI with the final results
      setState(() {
        _isLoading = false;
        _status = 'Classification completed!';
        if (diseaseInfo != null) {
          _result =
              '''
Prediction: $fullPredictionString

Symptoms:
${diseaseInfo.symptoms}

Treatment:
${diseaseInfo.treatment}

Prevention:
${diseaseInfo.prevention}
''';
        } else {
          _result =
              "Prediction: $fullPredictionString\n\n(Details not found in database)";
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _status = 'Test failed';
        _result = 'Error: $e';
      });
    }
  }

  @override
  void dispose() {
    _classifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AgriScan Model Test'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              color: _modelLoaded
                  ? Colors.green.shade50
                  : Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(
                      _modelLoaded ? Icons.check_circle : Icons.warning,
                      color: _modelLoaded ? Colors.green : Colors.orange,
                      size: 48,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Model Status',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _status,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Test Button
            ElevatedButton(
              onPressed: _isLoading ? null : _runTest,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('Processing...'),
                      ],
                    )
                  : const Text(
                      'Run Classification Test',
                      style: TextStyle(fontSize: 16),
                    ),
            ),

            const SizedBox(height: 24),

            // Results Card
            if (_result.isNotEmpty)
              Expanded(
                child: SingleChildScrollView(
                  child: Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Icon(Icons.analytics, color: Colors.blue, size: 48),
                          const SizedBox(height: 8),
                          Text(
                            'Prediction Result',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _result,
                            textAlign: TextAlign.left,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(color: Colors.blue.shade800),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
