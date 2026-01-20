class Maintenance {
  final String? id;
  final String vehicleId;
  final DateTime date;
  final String detail;
  final List<MaintenanceInvoice> invoices;
  final DateTime createdAt;
  final DateTime updatedAt;

  Maintenance({
    this.id,
    required this.vehicleId,
    required this.date,
    required this.detail,
    this.invoices = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Maintenance copyWith({
    String? id,
    String? vehicleId,
    DateTime? date,
    String? detail,
    List<MaintenanceInvoice>? invoices,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Maintenance(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      date: date ?? this.date,
      detail: detail ?? this.detail,
      invoices: invoices ?? this.invoices,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      if (id != null) 'id': id,
      'vehicle_id': vehicleId,
      'date': date.toIso8601String(),
      'detail': detail,
    };
  }

  factory Maintenance.fromSupabase(Map<String, dynamic> map, {List<MaintenanceInvoice>? invoices}) {
    return Maintenance(
      id: map['id'] as String,
      vehicleId: map['vehicle_id'] as String,
      date: DateTime.parse(map['date'] as String),
      detail: map['detail'] as String,
      invoices: invoices ?? [],
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vehicle_id': vehicleId,
      'date': date.millisecondsSinceEpoch,
      'detail': detail,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory Maintenance.fromMap(Map<String, dynamic> map) {
    return Maintenance(
      id: map['id'] as String?,
      vehicleId: map['vehicle_id'] as String,
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      detail: map['detail'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }
}

enum InvoiceFileType {
  image,
  pdf,
}

extension InvoiceFileTypeExtension on InvoiceFileType {
  String get label {
    switch (this) {
      case InvoiceFileType.image:
        return 'Imagen';
      case InvoiceFileType.pdf:
        return 'PDF';
    }
  }
}

class MaintenanceInvoice {
  final String? id;
  final String maintenanceId;
  final String cloudinaryUrl;
  final String cloudinaryPublicId;
  final InvoiceFileType fileType;
  final String? fileName;
  final DateTime createdAt;

  MaintenanceInvoice({
    this.id,
    required this.maintenanceId,
    required this.cloudinaryUrl,
    required this.cloudinaryPublicId,
    required this.fileType,
    this.fileName,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isPdf => fileType == InvoiceFileType.pdf;
  bool get isImage => fileType == InvoiceFileType.image;

  Map<String, dynamic> toSupabase() {
    return {
      if (id != null) 'id': id,
      'maintenance_id': maintenanceId,
      'cloudinary_url': cloudinaryUrl,
      'cloudinary_public_id': cloudinaryPublicId,
      'file_type': fileType.index,
      'file_name': fileName,
    };
  }

  factory MaintenanceInvoice.fromSupabase(Map<String, dynamic> map) {
    return MaintenanceInvoice(
      id: map['id'] as String,
      maintenanceId: map['maintenance_id'] as String,
      cloudinaryUrl: map['cloudinary_url'] as String,
      cloudinaryPublicId: map['cloudinary_public_id'] as String,
      fileType: InvoiceFileType.values[map['file_type'] as int? ?? 0],
      fileName: map['file_name'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'maintenance_id': maintenanceId,
      'cloudinary_url': cloudinaryUrl,
      'cloudinary_public_id': cloudinaryPublicId,
      'file_type': fileType.index,
      'file_name': fileName,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory MaintenanceInvoice.fromMap(Map<String, dynamic> map) {
    return MaintenanceInvoice(
      id: map['id'] as String?,
      maintenanceId: map['maintenance_id'] as String,
      cloudinaryUrl: map['cloudinary_url'] as String,
      cloudinaryPublicId: map['cloudinary_public_id'] as String,
      fileType: InvoiceFileType.values[map['file_type'] as int? ?? 0],
      fileName: map['file_name'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
}
