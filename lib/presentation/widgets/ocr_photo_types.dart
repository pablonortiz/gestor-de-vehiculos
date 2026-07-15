/// Tipos compartidos del flujo de captura con OCR.
enum OcrPhotoType { receipt, display }

class OcrPhotoResult {
  final String? cloudinaryUrl;
  final String? cloudinaryPublicId;
  final double? extractedLiters;
  final double? extractedPrice;
  final bool ocrDetected;
  final String? ocrText;
  final bool isPdf;
  final String? fileName;

  OcrPhotoResult({
    this.cloudinaryUrl,
    this.cloudinaryPublicId,
    this.extractedLiters,
    this.extractedPrice,
    this.ocrDetected = false,
    this.ocrText,
    this.isPdf = false,
    this.fileName,
  });
}
