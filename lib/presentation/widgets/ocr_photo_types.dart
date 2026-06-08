/// Tipos compartidos del flujo de captura con OCR.
enum OcrPhotoType { receipt, display }

class OcrPhotoResult {
  final String? cloudinaryUrl;
  final String? cloudinaryPublicId;
  final double? extractedValue;
  final bool ocrDetected;
  final String? ocrText;
  final bool isPdf;
  final String? fileName;

  OcrPhotoResult({
    this.cloudinaryUrl,
    this.cloudinaryPublicId,
    this.extractedValue,
    this.ocrDetected = false,
    this.ocrText,
    this.isPdf = false,
    this.fileName,
  });
}
