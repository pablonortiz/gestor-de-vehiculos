part of '../vehicle_detail_screen.dart';

// Sección de fotos de documentos (Cédula Verde, Azul, Título)
class _DocumentPhotosSection extends ConsumerStatefulWidget {
  final List<DocumentPhoto> photos;
  final String vehicleId;

  const _DocumentPhotosSection({
    required this.photos,
    required this.vehicleId,
  });

  @override
  ConsumerState<_DocumentPhotosSection> createState() => _DocumentPhotosSectionState();
}

class _DocumentPhotosSectionState extends ConsumerState<_DocumentPhotosSection> {
  bool _isUploading = false;
  DocumentType? _uploadingType;

  @override
  Widget build(BuildContext context) {
    // Agrupar las fotos por tipo en una sola pasada, en vez de filtrar la lista
    // completa una vez por cada DocumentType en cada build.
    final photosByType = <DocumentType, List<DocumentPhoto>>{};
    for (final photo in widget.photos) {
      (photosByType[photo.documentType] ??= []).add(photo);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: 'Documentos'),
        const SizedBox(height: 12),
        ...DocumentType.values.map(
          (type) => _buildDocumentTypeSection(type, photosByType[type] ?? const []),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildDocumentTypeSection(
      DocumentType type, List<DocumentPhoto> photosForType) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    type == DocumentType.titulo
                        ? Icons.description
                        : type == DocumentType.vtv
                            ? Icons.verified_user
                            : Icons.credit_card,
                    size: 20,
                    color: AppTheme.accentPrimary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    type.label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (photosForType.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.accentPrimary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${photosForType.length}',
                        style: const TextStyle(fontSize: 11, color: AppTheme.accentPrimary),
                      ),
                    ),
                ],
              ),
              _isUploading && _uploadingType == type
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      onPressed: () => _addPhoto(type),
                      icon: const Icon(Icons.add_a_photo, size: 20),
                      color: AppTheme.accentPrimary,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
            ],
          ),
          if (photosForType.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 70,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: photosForType.length,
                itemBuilder: (context, index) {
                  final photo = photosForType[index];
                  return GestureDetector(
                    onTap: () {
                      if (photo.isPdf) {
                        _showPdfPreview(context, photo.cloudinaryUrl, photo.fileName);
                      } else {
                        _showFullScreenImage(context, photo.cloudinaryUrl);
                      }
                    },
                    onLongPress: () => _showPhotoOptions(photo),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 70,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: photo.isPdf
                            ? _buildPdfThumbnailSmall(photo.fileName)
                            : CachedNetworkImage(
                                imageUrl: photo.cloudinaryUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, _) => const Center(
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                errorWidget: (_, _, _) => const Icon(Icons.error),
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Sin fotos',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary.withValues(alpha: 0.7),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _addPhoto(DocumentType type) async {
    final source = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Cámara'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galería (múltiples)'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.attach_file),
              title: const Text('Archivo (PDF/Imagen)'),
              onTap: () => Navigator.pop(ctx, 'file'),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    setState(() {
      _isUploading = true;
      _uploadingType = type;
    });

    try {
      final cloudinary = CloudinaryService.instance;
      final docPhotoRepo = ref.read(documentPhotoRepositoryProvider);

      final results = await cloudinary.pickAndUpload(source);
      for (final result in results) {
        await docPhotoRepo.insertPhoto(DocumentPhoto(
          vehicleId: widget.vehicleId,
          documentType: type,
          cloudinaryUrl: result.url,
          cloudinaryPublicId: result.publicId,
          isPdf: result.isPdf,
          fileName: result.fileName,
        ));
      }

      ref.invalidate(documentPhotosByVehicleProvider(widget.vehicleId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al subir el documento: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadingType = null;
        });
      }
    }
  }

  void _showPhotoOptions(DocumentPhoto photo) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.fullscreen),
              title: const Text('Ver en pantalla completa'),
              onTap: () {
                Navigator.pop(ctx);
                _showFullScreenImage(context, photo.cloudinaryUrl);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: AppTheme.error),
              title: const Text('Eliminar', style: TextStyle(color: AppTheme.error)),
              onTap: () async {
                Navigator.pop(ctx);
                if (!await confirmDelete(context,
                    title: 'Eliminar documento',
                    message: '¿Eliminar esta foto del documento? No se puede deshacer.')) {
                  return;
                }
                if (!mounted) return;
                final docPhotoRepo = ref.read(documentPhotoRepositoryProvider);
                try {
                  await docPhotoRepo.deletePhoto(photo.id!);
                  ref.invalidate(documentPhotosByVehicleProvider(widget.vehicleId));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Foto eliminada')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error al eliminar el documento: $e'),
                        backgroundColor: AppTheme.error,
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
