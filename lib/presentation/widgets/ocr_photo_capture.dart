import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/ocr_service.dart';
import '../../data/services/cloudinary_service.dart';
import 'ocr_photo_types.dart';
import 'ocr_image_viewer.dart';

// Re-export para que los consumidores (p.ej. fuel_charge_form_sheet) sigan
// importando solo ocr_photo_capture.dart.
export 'ocr_photo_types.dart';

class OcrPhotoCapture extends StatefulWidget {
  final OcrPhotoType type;
  final String? initialPhotoUrl;
  final double? initialValue;
  final bool showOcrIndicator;
  final ValueChanged<OcrPhotoResult> onPhotoResult;

  const OcrPhotoCapture({
    super.key,
    required this.type,
    this.initialPhotoUrl,
    this.initialValue,
    this.showOcrIndicator = false,
    required this.onPhotoResult,
  });

  @override
  State<OcrPhotoCapture> createState() => _OcrPhotoCaptureState();
}

class _OcrPhotoCaptureState extends State<OcrPhotoCapture> {
  String? _photoUrl;
  String? _ocrText;
  bool _isProcessing = false;
  bool _ocrDetected = false;
  bool _isPdf = false;
  String? _fileName;

  @override
  void initState() {
    super.initState();
    _photoUrl = widget.initialPhotoUrl;
    _ocrDetected = widget.showOcrIndicator;
  }

  void _safeSetState(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    final isReceipt = widget.type == OcrPhotoType.receipt;
    final label = isReceipt ? 'Ticket' : 'Surtidor';
    final icon = isReceipt ? Icons.receipt_long : Icons.local_gas_station;

    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _ocrDetected ? AppTheme.success : AppTheme.border,
          width: _ocrDetected ? 2 : 1,
        ),
      ),
      child: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : _photoUrl != null
              ? _buildPhotoPreview()
              : _buildCaptureButton(icon, label),
    );
  }

  Widget _buildCaptureButton(IconData icon, String label) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showPickerOptions,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.accentPrimary, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.accentPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'OCR',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.accentPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoPreview() {
    return Stack(
      children: [
        // Tappable image/pdf to view fullscreen
        GestureDetector(
          onTap: _isPdf
              ? () => _showPdfPreviewDialog()
              : _showFullScreenImage,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: _isPdf
                ? Container(
                    color: AppTheme.surfaceLight,
                    width: double.infinity,
                    height: double.infinity,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.picture_as_pdf, color: Colors.red, size: 32),
                        const SizedBox(height: 2),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            _fileName ?? 'PDF',
                            style: const TextStyle(fontSize: 8, color: AppTheme.textSecondary),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  )
                : CachedNetworkImage(
                    imageUrl: _photoUrl!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    placeholder: (_, _) => const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
          ),
        ),
        // Expand icon overlay
        Positioned(
          bottom: 4,
          right: 4,
          child: GestureDetector(
            onTap: _showFullScreenImage,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.zoom_in,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
        ),
        // Remove button
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: _removePhoto,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppTheme.error,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
        ),
        if (_ocrDetected)
          Positioned(
            bottom: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.success,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check, size: 10, color: Colors.white),
                  SizedBox(width: 2),
                  Text(
                    'OCR',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _showPdfPreviewDialog() {
    if (_photoUrl == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => OcrPdfPreviewPage(url: _photoUrl!, fileName: _fileName),
      ),
    );
  }

  void _showFullScreenImage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => OcrFullScreenViewer(
          imageUrl: _photoUrl!,
          ocrText: _ocrText,
          type: widget.type,
        ),
      ),
    );
  }

  void _showPickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Cámara'),
              onTap: () {
                Navigator.pop(ctx);
                _capturePhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galería'),
              onTap: () {
                Navigator.pop(ctx);
                _capturePhoto(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file),
              title: const Text('Archivo (PDF/Imagen)'),
              subtitle: const Text('Sin OCR para PDFs', style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _pickFile();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _capturePhoto(ImageSource source) async {
    setState(() => _isProcessing = true);

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFile == null) {
        _safeSetState(() => _isProcessing = false);
        return;
      }

      final file = File(pickedFile.path);

      OcrResult ocrResult;
      CloudinaryUploadResult? uploadResult;
      try {
        // Perform OCR
        final ocrService = OcrService.instance;
        ocrResult = widget.type == OcrPhotoType.receipt
            ? await ocrService.extractPrice(file)
            : await ocrService.extractLiters(file);

        // Upload to Cloudinary
        final cloudinary = CloudinaryService.instance;
        uploadResult = await cloudinary.uploadFile(file);
      } finally {
        // Clean up the temp file created by image_picker after uploading.
        try {
          await file.delete();
        } catch (_) {
          // File may already be gone; ignore.
        }
      }

      if (uploadResult != null) {
        final upload = uploadResult;
        _safeSetState(() {
          _photoUrl = upload.url;
          _ocrText = ocrResult.fullText;
          _ocrDetected = ocrResult.success;
          _isProcessing = false;
        });

        widget.onPhotoResult(OcrPhotoResult(
          cloudinaryUrl: upload.url,
          cloudinaryPublicId: upload.publicId,
          extractedValue: ocrResult.value,
          ocrDetected: ocrResult.success,
          ocrText: ocrResult.fullText,
        ));

        // Show snackbar with OCR result info
        if (mounted) {
          if (ocrResult.success) {
            final valueType = widget.type == OcrPhotoType.receipt ? 'precio' : 'litros';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('OCR detectó $valueType: ${ocrResult.rawText}'),
                backgroundColor: AppTheme.success,
                duration: const Duration(seconds: 2),
              ),
            );
          } else if (ocrResult.fullText != null && ocrResult.fullText!.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('OCR no encontró el valor. Toca la imagen para ver más detalles.'),
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      } else {
        _safeSetState(() => _isProcessing = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al subir la foto')),
          );
        }
      }
    } catch (e) {
      _safeSetState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo subir el archivo')),
        );
      }
    }
  }

  Future<void> _pickFile() async {
    setState(() => _isProcessing = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      );

      if (result == null || result.files.isEmpty || result.files.first.path == null) {
        _safeSetState(() => _isProcessing = false);
        return;
      }

      final file = result.files.first;
      final isPdf = file.extension?.toLowerCase() == 'pdf';
      final localFile = File(file.path!);

      CloudinaryUploadResult? uploadResult;
      try {
        final cloudinary = CloudinaryService.instance;
        uploadResult = await cloudinary.uploadFile(
          localFile,
          isPdf: isPdf,
          fileName: file.name,
        );
      } finally {
        // Clean up the temp file copied by file_picker after uploading.
        try {
          await localFile.delete();
        } catch (_) {
          // File may already be gone; ignore.
        }
      }

      if (uploadResult != null) {
        final upload = uploadResult;
        _safeSetState(() {
          _photoUrl = upload.url;
          _isPdf = upload.isPdf;
          _fileName = upload.fileName;
          _ocrText = null;
          _ocrDetected = false;
          _isProcessing = false;
        });

        widget.onPhotoResult(OcrPhotoResult(
          cloudinaryUrl: upload.url,
          cloudinaryPublicId: upload.publicId,
          isPdf: upload.isPdf,
          fileName: upload.fileName,
        ));
      } else {
        _safeSetState(() => _isProcessing = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al subir el archivo')),
          );
        }
      }
    } catch (e) {
      _safeSetState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo subir el archivo')),
        );
      }
    }
  }

  void _removePhoto() {
    setState(() {
      _photoUrl = null;
      _ocrText = null;
      _ocrDetected = false;
      _isPdf = false;
      _fileName = null;
    });

    widget.onPhotoResult(OcrPhotoResult());
  }
}

/// Full screen image viewer with OCR text display
