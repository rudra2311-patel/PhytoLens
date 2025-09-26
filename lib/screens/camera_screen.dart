import 'dart:io';
import 'package:agriscan_pro/services/database_helper.dart';
import 'package:agriscan_pro/utils/plant_disease_classifier.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'results_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isLoading = true;
  final String _errorMessage = '';

  // AI Integration
  bool _isProcessing = false;
  final PlantDiseaseClassifier _classifier = PlantDiseaseClassifier();
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final bool _isModelLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _classifier.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _cameraController!.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera(_cameraController!.description);
    }
  }

  Future<void> _initializeServices() async {
    setState(() => _isLoading = true);
    await _classifier.loadModel();
    await _initializeCamera();
    setState(() => _isLoading = false);
  }

  Future<void> _initializeCamera([CameraDescription? cameraDescription]) async {
    if (cameraDescription == null) {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _showErrorSnackBar('No cameras found.');
        return;
      }
      cameraDescription = _cameras.firstWhere(
          (cam) => cam.lensDirection == CameraLensDirection.back,
          orElse: () => _cameras.first);
    }

    _cameraController =
        CameraController(cameraDescription, ResolutionPreset.high, enableAudio: false);

    try {
      await _cameraController!.initialize();
      if (mounted) setState(() => _isCameraInitialized = true);
    } catch (e) {
      _showErrorSnackBar('Failed to initialize camera: $e');
    }
  }
  
  // --- THIS IS THE MAINLY CORRECTED FUNCTION ---
  Future<void> _processImage(String imagePath) async {
    setState(() => _isProcessing = true);

    try {
      final imageBytes = await File(imagePath).readAsBytes();
      final img.Image? decodedImage = img.decodeImage(imageBytes);
      if (decodedImage == null) throw Exception('Failed to decode image.');

      // This now correctly receives a Map
      final Map<String, double> predictions = await _classifier.classifyPlantDisease(decodedImage);
      
      if (predictions.isEmpty) {
        throw Exception('Classification failed: Model returned no predictions');
      }

      // Find the top prediction from the Map
      final topPredictionEntry = predictions.entries.reduce((a, b) => a.value > b.value ? a : b);
      final String diseaseName = topPredictionEntry.key;
      final double confidence = topPredictionEntry.value;
      print('DATABASE LOOKUP FOR: ---"$diseaseName"---');
      
      print('🎯 Top prediction: $diseaseName (${(confidence * 100).toStringAsFixed(1)}%)');

      final Disease? diseaseInfo = await _databaseHelper.getDisease(diseaseName);
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ResultsScreen(
              imagePath: imagePath,
              prediction: diseaseName, // Pass the clean name
              confidence: confidence, // Pass the real confidence
              diseaseInfo: diseaseInfo,
            ),
          ),
        );
      }
    } catch (e) {
      _showErrorSnackBar('Analysis failed: $e');
    } finally {
      if(mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _takePicture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      _showErrorSnackBar('Camera not ready.');
      return;
    }
    try {
      final XFile picture = await _cameraController!.takePicture();
      await _processImage(picture.path);
    } catch (e) {
      _showErrorSnackBar('Failed to take picture: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        await _processImage(pickedFile.path);
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick image: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan Crop'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (!_isCameraInitialized || _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(_cameraController!),
        if (_isProcessing)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text('Analyzing...', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ),
        _buildControls(),
      ],
    );
  }

  Widget _buildControls() {
    return Positioned(
      bottom: 30,
      left: 20,
      right: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.photo_library, color: Colors.white, size: 32),
            onPressed: _pickFromGallery,
          ),
          GestureDetector(
            onTap: _takePicture,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: Colors.green, width: 4),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 32),
            onPressed: () { /* TODO: Implement camera flip */ },
          ),
        ],
      ),
    );
  }
}