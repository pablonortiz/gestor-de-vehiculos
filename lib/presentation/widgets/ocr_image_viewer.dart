import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:printing/printing.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/pdf_service.dart';
import 'ocr_photo_types.dart';

/// Visor a pantalla completa de la imagen capturada, con acceso al texto OCR.
class OcrFullScreenViewer extends StatelessWidget {
  final String imageUrl;
  final String? ocrText;
  final OcrPhotoType type;

  const OcrFullScreenViewer({
    super.key,
    required this.imageUrl,
    this.ocrText,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final isReceipt = type == OcrPhotoType.receipt;
    final title = isReceipt ? 'Ticket' : 'Surtidor';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title),
        actions: [
          if (ocrText != null && ocrText!.isNotEmpty)
            IconButton(
              onPressed: () => _showOcrText(context),
              icon: const Icon(Icons.text_snippet),
              tooltip: 'Ver texto OCR',
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    placeholder: (_, _) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    errorWidget: (_, _, _) => const Icon(
                      Icons.error,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
            // Bottom hint
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.black.withValues(alpha: 0.8),
              child: Text(
                isReceipt
                    ? 'Pellizca para zoom. Busca el precio total en el ticket.'
                    : 'Pellizca para zoom. Busca los litros y el importe en el display.',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOcrText(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppTheme.border),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Texto detectado por OCR',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  ocrText ?? 'No se detectó texto',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppTheme.border),
                ),
              ),
              child: Text(
                type == OcrPhotoType.receipt
                    ? 'Busca palabras como "Total", "Importe" o valores con "\$"'
                    : 'Busca los litros (ej. "28.605") y el importe total del display',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vista de preview de un PDF (factura) descargado desde su URL.
class OcrPdfPreviewPage extends StatelessWidget {
  final String url;
  final String? fileName;
  const OcrPdfPreviewPage({super.key, required this.url, this.fileName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(fileName ?? 'PDF'),
        backgroundColor: AppTheme.surface,
      ),
      body: PdfPreview(
        build: (format) async {
          final bytes = await PdfService.downloadPdfBytes(url);
          if (bytes == null) throw Exception('No se pudo descargar el PDF');
          return bytes;
        },
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        pdfFileName: fileName,
      ),
    );
  }
}
