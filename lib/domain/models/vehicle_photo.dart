class VehiclePhoto {
  final String? id;
  final String vehicleId;
  final String cloudinaryUrl;
  final String cloudinaryPublicId;
  final bool isPrimary;
  final DateTime createdAt;

  VehiclePhoto({
    this.id,
    required this.vehicleId,
    required this.cloudinaryUrl,
    required this.cloudinaryPublicId,
    this.isPrimary = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  VehiclePhoto copyWith({
    String? id,
    String? vehicleId,
    String? cloudinaryUrl,
    String? cloudinaryPublicId,
    bool? isPrimary,
    DateTime? createdAt,
  }) {
    return VehiclePhoto(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      cloudinaryUrl: cloudinaryUrl ?? this.cloudinaryUrl,
      cloudinaryPublicId: cloudinaryPublicId ?? this.cloudinaryPublicId,
      isPrimary: isPrimary ?? this.isPrimary,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      if (id != null) 'id': id,
      'vehicle_id': vehicleId,
      'cloudinary_url': cloudinaryUrl,
      'cloudinary_public_id': cloudinaryPublicId,
      'is_primary': isPrimary,
    };
  }

  factory VehiclePhoto.fromSupabase(Map<String, dynamic> map) {
    return VehiclePhoto(
      id: map['id'] as String,
      vehicleId: map['vehicle_id'] as String,
      cloudinaryUrl: map['cloudinary_url'] as String,
      cloudinaryPublicId: map['cloudinary_public_id'] as String,
      isPrimary: map['is_primary'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vehicle_id': vehicleId,
      'cloudinary_url': cloudinaryUrl,
      'cloudinary_public_id': cloudinaryPublicId,
      'is_primary': isPrimary ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory VehiclePhoto.fromMap(Map<String, dynamic> map) {
    return VehiclePhoto(
      id: map['id'] as String?,
      vehicleId: map['vehicle_id'] as String,
      cloudinaryUrl: map['cloudinary_url'] as String,
      cloudinaryPublicId: map['cloudinary_public_id'] as String,
      isPrimary: (map['is_primary'] as int?) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
}
