class Farm {
  final int? id;
  final String? backendId; // UUID from backend
  final String? userId;
  final String name;
  final String location;
  final double latitude;
  final double longitude;
  final String cropType;
  final double? farmSize;
  final DateTime createdAt;
  final String? riskLevel; // 'low', 'medium', 'high'
  final String? imageUrl;

  Farm({
    this.id,
    this.backendId,
    this.userId,
    required this.name,
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.cropType,
    this.farmSize,
    required this.createdAt,
    this.riskLevel,
    this.imageUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'backend_id': backendId,
      'user_id': userId,
      'name': name,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'crop_type': cropType,
      'farm_size': farmSize,
      'created_at': createdAt.toIso8601String(),
      'risk_level': riskLevel,
      'image_url': imageUrl,
    };
  }

  factory Farm.fromMap(Map<String, dynamic> map) {
    return Farm(
      id: map['id'],
      backendId: map['backend_id'],
      userId: map['user_id'],
      name: map['name'],
      location: map['location'],
      latitude: map['latitude'],
      longitude: map['longitude'],
      cropType: map['crop_type'],
      farmSize: map['farm_size'],
      createdAt: DateTime.parse(map['created_at']),
      riskLevel: map['risk_level'],
      imageUrl: map['image_url'],
    );
  }

  // Factory constructor for backend response
  factory Farm.fromBackendJson(Map<String, dynamic> json) {
    return Farm(
      backendId: json['id'],
      userId: json['user_id'],
      name:
          json['name'] ??
          json['crop'], // Use name from backend, fallback to crop
      location: 'Lat: ${json['lat']}, Lon: ${json['lon']}',
      latitude: json['lat'],
      longitude: json['lon'],
      cropType: json['crop'],
      createdAt:
          DateTime.now(), // Backend doesn't return created_at in response
      riskLevel: 'low', // Default
    );
  }

  Farm copyWith({
    int? id,
    String? backendId,
    String? userId,
    String? name,
    String? location,
    double? latitude,
    double? longitude,
    String? cropType,
    double? farmSize,
    DateTime? createdAt,
    String? riskLevel,
    String? imageUrl,
  }) {
    return Farm(
      id: id ?? this.id,
      backendId: backendId ?? this.backendId,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      cropType: cropType ?? this.cropType,
      farmSize: farmSize ?? this.farmSize,
      createdAt: createdAt ?? this.createdAt,
      riskLevel: riskLevel ?? this.riskLevel,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  // Override equality operators for proper comparison in dropdowns
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Farm &&
        other.id == id &&
        other.backendId == backendId &&
        other.name == name &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.cropType == cropType;
  }

  @override
  int get hashCode {
    return Object.hash(id, backendId, name, latitude, longitude, cropType);
  }
}
