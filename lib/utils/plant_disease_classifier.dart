import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:math' as math;

class PlantDiseaseClassifier {
  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isModelLoaded = false;

  // Use the final, correct model name from your training script.
  static const String modelPath =
      'assets/models/plant_disease_rudra_model.tflite';
  static const String labelsPath = 'assets/models/labels.txt';

  // Model configurations from your notebook.
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
          .where((label) => label.isNotEmpty)
          .toList();
      print('✅ Loaded ${_labels.length} labels');
    } catch (e) {
      print('❌ Error loading labels: $e');
    }
  }

  /// Classify plant disease from an image.
  Future<String> classifyPlantDisease(img.Image image) async {
    if (!_isModelLoaded || _interpreter == null) {
      return 'Error: Model not loaded';
    }

    try {
      // Preprocess the image (resize and convert to Float32List).
      final inputBytes = _preprocessImage(image);
      final input = inputBytes.reshape([1, modelInputSize, modelInputSize, 3]);

      // Prepare the output tensor.
      final output = List.filled(numClasses, 0.0).reshape([1, numClasses]);

      // Run inference.
      _interpreter!.run(input, output);

      // Get the raw prediction results (logits).
      final results = output[0] as List<double>;

      // Find the class with the highest score.
      double maxScore = -double.infinity;
      int maxIndex = 0;

      for (int i = 0; i < results.length; i++) {
        if (results[i] > maxScore) {
          maxScore = results[i];
          maxIndex = i;
        }
      }

      // Get the class name from the labels list.
      String className = maxIndex < _labels.length
          ? _labels[maxIndex]
          : 'Unknown_Class_$maxIndex';

      // Convert the top score to a confidence percentage using softmax.
      final probabilities = _softmax(results);
      String confidencePercent = (probabilities[maxIndex] * 100)
          .toStringAsFixed(1);

      return className;
    } catch (e) {
      print('❌ Error during classification: $e');
      return 'Error: Classification failed - $e';
    }
  }

  /// Preprocess image for model input.
  Float32List _preprocessImage(img.Image image) {
    // Resize image to model input size (160x160).
    final resizedImage = img.copyResize(
      image,
      width: modelInputSize,
      height: modelInputSize,
      interpolation: img.Interpolation.linear,
    );

    // Your Keras model contains the preprocessing layer, so it expects raw pixel
    // values as Float32, NOT normalized values.
    final inputBytes = Float32List(1 * modelInputSize * modelInputSize * 3);
    int bufferIndex = 0;
    for (var y = 0; y < modelInputSize; y++) {
      for (var x = 0; x < modelInputSize; x++) {
        final pixel = resizedImage.getPixel(x, y);
        inputBytes[bufferIndex++] = img.getRed(pixel).toDouble();
        inputBytes[bufferIndex++] = img.getGreen(pixel).toDouble();
        inputBytes[bufferIndex++] = img.getBlue(pixel).toDouble();
      }
    }

    // --- FIX ---
    // The interpreter expects a flat list (Float32List). The reshape happens
    // right before running the interpreter.
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
