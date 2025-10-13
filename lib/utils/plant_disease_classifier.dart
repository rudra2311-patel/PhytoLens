import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:math' as math;

class PlantDiseaseClassifier {
  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isModelLoaded = false;

  // Ensure this is the correct path to your final model
  static const String modelPath = 'assets/models/final_model.tflite';
  static const String labelsPath = 'assets/models/labels.txt';

  // Model configurations from your notebook
  static const int modelInputSize = 160;
  static const int numClasses = 39;

  /// Initialize and load the model.
  Future<bool> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(modelPath);
      await _loadLabels();
      _isModelLoaded = true;
      print('✅ Model loaded successfully');
      return true;
    } catch (e) {
      print('❌ Error loading model: $e');
      _isModelLoaded = false;
      return false;
    }
  }

  /// Load class labels from assets.
  Future<void> _loadLabels() async {
    try {
      final labelsData = await rootBundle.loadString(labelsPath);
      _labels = labelsData
          .split('\n')
          .map((label) => label.trim())
          .where((label) => label.isNotEmpty)
          .toList();
      print('✅ Loaded ${_labels.length} labels');
    } catch (e) {
      print('❌ Error loading labels: $e');
    }
  }

  /// Classify plant disease from an image and return a map of probabilities.
  Future<Map<String, double>> classifyPlantDisease(img.Image image) async {
    if (!_isModelLoaded || _interpreter == null) {
      throw Exception('Error: Model not loaded');
    }

    try {
      final inputBytes = _preprocessImage(image);
      final input = inputBytes.reshape([1, modelInputSize, modelInputSize, 3]);

      final output = List.filled(numClasses, 0.0).reshape([1, numClasses]);

      _interpreter!.run(input, output);

      final results = output[0] as List<double>;

      // The model already outputs probabilities because we trained with a Softmax layer.
      final probabilities = results;

      final Map<String, double> labeledProbabilities = {};
      for (int i = 0; i < probabilities.length; i++) {
        if (i < _labels.length) {
          labeledProbabilities[_labels[i]] = probabilities[i];
        }
      }
      return labeledProbabilities;
    } catch (e) {
      print('❌ Error during classification: $e');
      throw Exception('Error: Classification failed - $e');
    }
  }

  /// Preprocess image for model input.
  Float32List _preprocessImage(img.Image image) {
    final resizedImage = img.copyResize(
      image,
      width: modelInputSize,
      height: modelInputSize,
      interpolation: img.Interpolation.linear,
    );

    final inputBytes = Float32List(modelInputSize * modelInputSize * 3);
    int bufferIndex = 0;
    for (var y = 0; y < modelInputSize; y++) {
      for (var x = 0; x < modelInputSize; x++) {
        // --- CRITICAL FIX START ---
        // getPixel now returns an int. Use the image package's helper functions
        // to extract the Red, Green, and Blue channels correctly.
        final pixel = resizedImage.getPixel(x, y);
        inputBytes[bufferIndex++] = img.getRed(pixel).toDouble();
        inputBytes[bufferIndex++] = img.getGreen(pixel).toDouble();
        inputBytes[bufferIndex++] = img.getBlue(pixel).toDouble();
        // --- CRITICAL FIX END ---
      }
    }

    return inputBytes;
  }

  /// Applies the Softmax function to convert logits to probabilities.
  List<double> _softmax(List<double> logits) {
    final maxLogit = logits.reduce(math.max);
    final exps = logits.map((x) => math.exp(x - maxLogit)).toList();
    final sumExp = exps.reduce((a, b) => a + b);
    return exps.map((e) => e / sumExp).toList();
  }

  void dispose() {
    _interpreter?.close();
  }

  bool get isModelLoaded => _isModelLoaded;
}
