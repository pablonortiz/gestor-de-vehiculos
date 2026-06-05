import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/config/cloudinary_config.dart';

class CloudinaryUploadResult {
  final String url;
  final String publicId;
  final bool isPdf;
  final String? fileName;

  CloudinaryUploadResult({
    required this.url,
    required this.publicId,
    required this.isPdf,
    this.fileName,
  });
}

/// Error de subida a Cloudinary (red, preset inválido, etc.). Permite a los
/// callers distinguir un fallo real de "el usuario canceló el picker" (null).
class CloudinaryUploadException implements Exception {
  final String message;
  CloudinaryUploadException(this.message);
  @override
  String toString() => message;
}

class CloudinaryService {
  static final CloudinaryService instance = CloudinaryService._();
  final ImagePicker _imagePicker = ImagePicker();

  CloudinaryService._();

  CloudinaryPublic get _cloudinary => CloudinaryConfig.client;

  // Subir imagen desde cámara
  Future<CloudinaryUploadResult?> uploadFromCamera() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
    
    if (image == null) return null;

    return await _uploadFile(File(image.path), isPdf: false, throwOnError: true);
  }

  // Subir imagen desde galería
  Future<CloudinaryUploadResult?> uploadFromGallery() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (image == null) return null;

    return await _uploadFile(File(image.path), isPdf: false, throwOnError: true);
  }

  // Subir múltiples imágenes desde galería
  Future<List<CloudinaryUploadResult>> uploadMultipleFromGallery() async {
    final List<XFile> images = await _imagePicker.pickMultiImage(
      imageQuality: 80,
    );
    
    final results = <CloudinaryUploadResult>[];
    for (final image in images) {
      final result = await _uploadFile(File(image.path), isPdf: false);
      if (result != null) {
        results.add(result);
      }
    }

    final failed = images.length - results.length;
    if (failed > 0) {
      debugPrint(
        'Subida múltiple de galería: $failed de ${images.length} archivos fallaron',
      );
    }

    return results;
  }

  // Subir PDF o imagen (para facturas)
  Future<CloudinaryUploadResult?> uploadInvoice() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
    );
    
    if (result == null || result.files.isEmpty) return null;
    
    final file = result.files.first;
    if (file.path == null) return null;
    
    final isPdf = file.extension?.toLowerCase() == 'pdf';
    
    return await _uploadFile(
      File(file.path!),
      isPdf: isPdf,
      fileName: file.name,
      throwOnError: true,
    );
  }

  // Subir múltiples PDFs o imágenes (para facturas)
  Future<List<CloudinaryUploadResult>> uploadMultipleInvoices() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      allowMultiple: true,
    );
    
    if (result == null || result.files.isEmpty) return [];
    
    final selectedFiles = result.files.where((f) => f.path != null).toList();
    final results = <CloudinaryUploadResult>[];
    for (final file in selectedFiles) {
      final isPdf = file.extension?.toLowerCase() == 'pdf';
      final uploadResult = await _uploadFile(
        File(file.path!),
        isPdf: isPdf,
        fileName: file.name,
      );

      if (uploadResult != null) {
        results.add(uploadResult);
      }
    }

    final failed = selectedFiles.length - results.length;
    if (failed > 0) {
      debugPrint(
        'Subida múltiple de facturas: $failed de ${selectedFiles.length} archivos fallaron',
      );
    }

    return results;
  }

  // Subir archivo a Cloudinary
  // Subir archivo a Cloudinary. Devuelve null en error salvo que throwOnError
  // sea true (subidas single, donde el caller necesita distinguir fallo de
  // cancelación). Los loops/subidas múltiples usan null para saltear y seguir.
  Future<CloudinaryUploadResult?> _uploadFile(
    File file, {
    required bool isPdf,
    String? fileName,
    bool throwOnError = false,
  }) async {
    try {
      final response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          file.path,
          resourceType: isPdf ? CloudinaryResourceType.Raw : CloudinaryResourceType.Image,
          folder: isPdf ? 'gestor_vehiculos/invoices' : 'gestor_vehiculos/photos',
        ),
      );

      return CloudinaryUploadResult(
        url: response.secureUrl,
        publicId: response.publicId,
        isPdf: isPdf,
        fileName: fileName,
      );
    } catch (e) {
      debugPrint('Error subiendo archivo a Cloudinary: $e');
      if (throwOnError) {
        throw CloudinaryUploadException('No se pudo subir el archivo: $e');
      }
      return null;
    }
  }

  // Subir archivo directamente (para uso interno)
  Future<CloudinaryUploadResult?> uploadFile(File file, {bool isPdf = false, String? fileName}) async {
    return await _uploadFile(file, isPdf: isPdf, fileName: fileName);
  }
}
