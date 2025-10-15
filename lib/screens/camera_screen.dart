import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:agriscan_pro/services/database_helper.dart';
import 'package:agriscan_pro/utils/plant_disease_classifier.dart';
import 'results_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isLoading = true;
  bool _isProcessing = false;

  final PlantDiseaseClassifier _classifier = PlantDiseaseClassifier();
  final DatabaseHelper _databaseHelper = DatabaseHelper();

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

  // ✅ Proper lifecycle handling
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    final controller = _cameraController;

    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      await controller.dispose();
      _isCameraInitialized = false;
    } else if (state == AppLifecycleState.resumed) {
      await _initializeCamera(controller.description);
    }
  }

  // ✅ Initialize model + camera
  Future<void> _initializeServices() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      await _classifier.loadModel();
      await _initializeCamera();
    } catch (e) {
      _showErrorSnackBar('Initialization failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ✅ Safe camera initialization
  Future<void> _initializeCamera([CameraDescription? description]) async {
    try {
      _isCameraInitialized = false;
      await _cameraController?.dispose();

      _cameras = await availableCameras();
      description ??= _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      final controller = CameraController(
        description,
        ResolutionPreset.medium, // ✅ medium = more stable on Android
        enableAudio: false,
      );

      _cameraController = controller;

      await controller.initialize();
      if (!mounted) return;

      setState(() => _isCameraInitialized = true);
    } catch (e) {
      _showErrorSnackBar('Camera failed: $e');
    }
  }

  // ✅ Take picture and process
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

  // ✅ Pick image from gallery
  Future<void> _pickFromGallery() async {
    try {
      final XFile? pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
      );
      if (pickedFile != null) {
        await _processImage(pickedFile.path);
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick image: $e');
    }
  }

  // ✅ AI model processing
  Future<void> _processImage(String imagePath) async {
    setState(() => _isProcessing = true);
    try {
      final imageBytes = await File(imagePath).readAsBytes();
      final img.Image? decodedImage = img.decodeImage(imageBytes);
      if (decodedImage == null) throw Exception('Failed to decode image.');

      final predictions = await _classifier.classifyPlantDisease(decodedImage);

      if (predictions.isEmpty) {
        throw Exception('Model returned no predictions');
      }

      final topPrediction = predictions.entries.reduce(
        (a, b) => a.value > b.value ? a : b,
      );

      final diseaseName = topPrediction.key;
      final confidence = topPrediction.value;

      final diseaseInfo = await _databaseHelper.getDisease(diseaseName);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ResultsScreen(
              imagePath: imagePath,
              prediction: diseaseName,
              confidence: confidence,
              diseaseInfo: diseaseInfo,
            ),
          ),
        );
      }
    } catch (e) {
      _showErrorSnackBar('Analysis failed: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ✅ Error message helper
  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  // ✅ Flip between front & back camera
  Future<void> _flipCamera() async {
    if (_cameras.length < 2 || _cameraController == null) return;

    final currentLens = _cameraController!.description.lensDirection;
    final newDescription = currentLens == CameraLensDirection.back
        ? _cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.front,
          )
        : _cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.back,
          );

    await _initializeCamera(newDescription);
  }

  // ✅ UI
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
        if (_cameraController != null && _cameraController!.value.isInitialized)
          CameraPreview(_cameraController!)
        else
          const Center(child: CircularProgressIndicator()),

        // Processing overlay
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

        // Controls
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
            icon: const Icon(
              Icons.photo_library,
              color: Colors.white,
              size: 32,
            ),
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
            icon: const Icon(
              Icons.flip_camera_ios,
              color: Colors.white,
              size: 32,
            ),
            onPressed: _flipCamera,
          ),
        ],
      ),
    );
  }
}
