import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/farm_model.dart';
import '../../services/farm_database_helper.dart';
import '../../services/api_services.dart';
import '../../services/auth_services.dart';
import '../../services/websocket_alert_service.dart';

class AddFarmScreen extends StatefulWidget {
  const AddFarmScreen({super.key});

  @override
  _AddFarmScreenState createState() => _AddFarmScreenState();
}

class _AddFarmScreenState extends State<AddFarmScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _latController = TextEditingController();
  final _lonController = TextEditingController();
  final _sizeController = TextEditingController();

  String _selectedCrop = 'Tomato';
  final List<String> _crops = [
    'Tomato',
    'Potato',
    'Corn',
    'Grapes',
    'Rice',
    'Wheat',
    'Cotton',
    'Pepper',
    'Soybean',
  ];
  bool _isLoadingLocation = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _latController.dispose();
    _lonController.dispose();
    _sizeController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _isLoadingLocation = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission denied. Please allow location.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Get GPS location
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Update lat/lon fields
      _latController.text = position.latitude.toString();
      _lonController.text = position.longitude.toString();

      // 🔥 Fetch City, State using reverse geocoding
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;

        String city = place.locality ?? "";
        String state = place.administrativeArea ?? "";

        setState(() {
          _locationController.text = "$city, $state";
        });
      }

      setState(() => _isLoadingLocation = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location & Address fetched successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _isLoadingLocation = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to get location: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveFarm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final latitude = double.parse(_latController.text);
      final longitude = double.parse(_lonController.text);

      // Create farm object
      Farm farm = Farm(
        name: _nameController.text.trim(),
        location: _locationController.text.trim(),
        latitude: latitude,
        longitude: longitude,
        cropType: _selectedCrop,
        farmSize: _sizeController.text.isEmpty
            ? null
            : double.parse(_sizeController.text),
        createdAt: DateTime.now(),
        riskLevel: 'low', // Default
      );

      // Try to sync with backend first
      try {
        final backendResponse = await ApiService.addFarm(
          lat: latitude,
          lon: longitude,
          crop: _selectedCrop,
          name: _nameController.text.trim(),
        );

        // If backend sync successful, save with backend_id
        if (backendResponse['id'] != null) {
          farm = farm.copyWith(backendId: backendResponse['id']);
        }

        // 🔥 Immediately fetch weather data for this farm
        try {
          await ApiService.getWeatherRisk(
            lat: latitude,
            lon: longitude,
            crop: _selectedCrop,
          );
          debugPrint('✅ Weather data fetched for new farm');
        } catch (weatherError) {
          debugPrint('⚠️ Weather fetch failed: $weatherError');
          // Don't block farm creation if weather fails
        }
      } catch (e) {
        // Backend sync failed, continue with local save
        debugPrint('Backend sync failed: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Saved locally. Will sync when online.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }

      // Attach current user id to farm before saving locally
      final currentUserId = await AuthService.getUserId();
      if (currentUserId == null) {
        // We require the user to be logged in to save farms locally
        setState(() => _isSaving = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please login to add a farm.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      farm = farm.copyWith(userId: currentUserId);

      // Save to local database
      final farmId = await FarmDatabaseHelper.instance.createFarm(farm);

      // 🔌 Connect WebSocket for real-time alerts immediately after adding farm
      try {
        final savedFarm = await FarmDatabaseHelper.instance.getFarmById(farmId);
        if (savedFarm != null) {
          final wsService = WebSocketAlertService.instance;
          await wsService.connectForFarm(savedFarm);
          debugPrint('✅ WebSocket connected for new farm: ${savedFarm.name}');
        }
      } catch (e) {
        debugPrint('⚠️ Failed to connect WebSocket for new farm: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Farm added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save farm: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Add New Farm'),
        backgroundColor: const Color(0xFF4CAF50),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.agriculture,
                            color: Colors.green[700],
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Farm Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Farm Name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.label_outline),
                        hintText: 'e.g., My Farm #1',
                      ),
                      validator: (value) => value?.isEmpty ?? true
                          ? 'Farm name is required'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _locationController,
                      decoration: InputDecoration(
                        labelText: 'Location (City, State)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.location_city),
                        hintText: 'e.g., Pune, Maharashtra',
                      ),
                      validator: (value) => value?.isEmpty ?? true
                          ? 'Location is required'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _latController,
                            decoration: InputDecoration(
                              labelText: 'Latitude',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              prefixIcon: const Icon(Icons.place),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            validator: (value) {
                              if (value?.isEmpty ?? true) return 'Required';
                              if (double.tryParse(value!) == null) {
                                return 'Invalid';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _lonController,
                            decoration: InputDecoration(
                              labelText: 'Longitude',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              prefixIcon: const Icon(Icons.place),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            validator: (value) {
                              if (value?.isEmpty ?? true) return 'Required';
                              if (double.tryParse(value!) == null) {
                                return 'Invalid';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoadingLocation
                            ? null
                            : _useCurrentLocation,
                        icon: _isLoadingLocation
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.my_location),
                        label: Text(
                          _isLoadingLocation
                              ? 'Getting location...'
                              : 'Use Current Location',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF4CAF50),
                          side: const BorderSide(color: Color(0xFF4CAF50)),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCrop,
                      decoration: InputDecoration(
                        labelText: 'Select Crop',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.grass),
                      ),
                      items: _crops
                          .map(
                            (crop) => DropdownMenuItem(
                              value: crop,
                              child: Text(crop),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _selectedCrop = value!),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _sizeController,
                      decoration: InputDecoration(
                        labelText: 'Farm Size (acres)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.crop_landscape),
                        hintText: 'Optional',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) {
                        if (value != null &&
                            value.isNotEmpty &&
                            double.tryParse(value) == null) {
                          return 'Invalid number';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveFarm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isSaving
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              Text('Saving...'),
                            ],
                          )
                        : const Text('Add Farm'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
