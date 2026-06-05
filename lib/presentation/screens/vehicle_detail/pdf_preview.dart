part of '../vehicle_detail_screen.dart';

// Helper para thumbnails de PDF (tamaño grande - galería de vehículos)
Widget _buildPdfThumbnail(String? fileName) {
  return Container(
    color: AppTheme.surface,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.picture_as_pdf, color: Colors.red, size: 36),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            fileName ?? 'PDF',
            style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    ),
  );
}

// Helper para thumbnails de PDF (tamaño pequeño - documentos, notas)
Widget _buildPdfThumbnailSmall(String? fileName) {
  return Container(
    color: AppTheme.surface,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.picture_as_pdf, color: Colors.red, size: 28),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            fileName ?? 'PDF',
            style: const TextStyle(fontSize: 8, color: AppTheme.textSecondary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    ),
  );
}

// Helper para mostrar imagen en pantalla completa
void _showFullScreenImage(BuildContext context, String imageUrl) {
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      child: Stack(
        children: [
          InteractiveViewer(
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
              placeholder: (_, _) => const Center(
                child: CircularProgressIndicator(),
              ),
              errorWidget: (_, _, _) => const Center(
                child: Icon(Icons.error, color: AppTheme.error, size: 48),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// Helper para previsualizar PDFs usando PdfPreview del paquete printing
void _showPdfPreview(BuildContext context, String url, String? fileName) {
  Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _PdfPreviewPage(url: url, fileName: fileName),
    ),
  );
}

class _PdfPreviewPage extends StatelessWidget {
  final String url;
  final String? fileName;
  const _PdfPreviewPage({required this.url, this.fileName});

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
