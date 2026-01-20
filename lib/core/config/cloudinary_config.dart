import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CloudinaryConfig {
  static String get cloudName => dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
  static String get uploadPreset => dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '';

  static CloudinaryPublic get client => CloudinaryPublic(
    cloudName,
    uploadPreset,
    cache: false,
  );

  static bool get isConfigured =>
      cloudName.isNotEmpty && 
      uploadPreset.isNotEmpty &&
      cloudName != 'TU_CLOUD_NAME';
}
