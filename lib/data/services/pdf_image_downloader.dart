import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';

/// Descarga y rasterizado de imágenes/PDFs remotos para la generación de PDF.
/// Separa el concern de I/O de red del armado del documento.
class PdfImageDownloader {
  static Future<Uint8List?> downloadImage(String url) async {
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (e) {
      debugPrint('🖼️ [PDF] Error descarga imagen: $url -> $e');
    }
    return null;
  }

  /// Descarga un PDF desde una URL y retorna los bytes.
  static Future<Uint8List?> downloadPdfBytes(String url) async {
    try {
      debugPrint('📄 [PDF] Descargando: $url');
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 20));
      debugPrint('📄 [PDF] Status: ${response.statusCode}, Size: ${response.bodyBytes.length}');
      if (response.statusCode == 200 && response.bodyBytes.length > 10) {
        return response.bodyBytes;
      }
      debugPrint('📄 [PDF] Respuesta no válida');
    } catch (e) {
      debugPrint('📄 [PDF] Error descarga: $e');
    }
    return null;
  }

  /// Descarga un PDF y lo rasteriza a imágenes PNG.
  static Future<List<Uint8List>> downloadAndRasterizePdf(String url,
      {double dpi = 150}) async {
    try {
      final pdfBytes = await downloadPdfBytes(url);
      if (pdfBytes == null) return [];

      final pages = <Uint8List>[];
      await for (final page in Printing.raster(pdfBytes, dpi: dpi)) {
        pages.add(await page.toPng());
      }
      return pages;
    } catch (e) {
      return [];
    }
  }
}
