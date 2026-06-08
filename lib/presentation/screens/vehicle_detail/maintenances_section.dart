part of '../vehicle_detail_screen.dart';

// Sección de mantenimientos
class _MaintenancesSection extends ConsumerStatefulWidget {
  final List<Maintenance> maintenances;
  final String vehicleId;

  const _MaintenancesSection({
    required this.maintenances,
    required this.vehicleId,
  });

  @override
  ConsumerState<_MaintenancesSection> createState() => _MaintenancesSectionState();
}

class _MaintenancesSectionState extends ConsumerState<_MaintenancesSection> {
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const _SectionTitle(title: 'Mantenimientos'),
            IconButton(
              onPressed: () => _showMaintenanceDialog(null),
              icon: const Icon(Icons.add, color: AppTheme.accentPrimary),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (widget.maintenances.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: const Center(
              child: Text(
                'Sin mantenimientos registrados',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          )
        else
          ...widget.maintenances.map((m) => _MaintenanceCard(
            maintenance: m,
            dateFormat: dateFormat,
            onTap: () => _showMaintenanceDialog(m),
            onDelete: () => _deleteMaintenance(m),
            isDeleting: _isDeleting,
          )),
      ],
    );
  }

  void _showMaintenanceDialog(Maintenance? maintenance) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _MaintenanceFormSheet(
        vehicleId: widget.vehicleId,
        maintenance: maintenance,
        onSaved: (message) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(message)),
            );
          }
        },
      ),
    );
  }

  Future<void> _deleteMaintenance(Maintenance maintenance) async {
    if (!await confirmDelete(context,
        title: 'Eliminar mantenimiento',
        message: '¿Eliminar este mantenimiento y sus facturas? No se puede deshacer.')) {
      return;
    }
    if (!mounted) return;
    setState(() => _isDeleting = true);
    try {
      final maintenanceRepo = ref.read(maintenanceRepositoryProvider);
      await maintenanceRepo.deleteMaintenance(maintenance.id!);
      ref.invalidate(maintenancesByVehicleProvider(widget.vehicleId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mantenimiento eliminado')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }
}

// Contenido del modal de alta/edición de mantenimiento.
// StatefulWidget dedicado para que los TextEditingController se liberen en dispose.
class _MaintenanceFormSheet extends ConsumerStatefulWidget {
  final String vehicleId;
  final Maintenance? maintenance;
  final void Function(String message) onSaved;

  const _MaintenanceFormSheet({
    required this.vehicleId,
    required this.maintenance,
    required this.onSaved,
  });

  @override
  ConsumerState<_MaintenanceFormSheet> createState() => _MaintenanceFormSheetState();
}

class _MaintenanceFormSheetState extends ConsumerState<_MaintenanceFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _dateController;
  late final TextEditingController _detailController;
  late final TextEditingController _costController;
  late DateTime? _selectedDate;
  late List<MaintenanceInvoice> _existingInvoices;
  final List<PlatformFile> _pendingFiles = [];
  bool _isSaving = false;
  bool _isSelectingFiles = false;
  bool _hasChanges = false;

  bool get _isEditing => widget.maintenance != null;

  @override
  void initState() {
    super.initState();
    final maintenance = widget.maintenance;
    _dateController = TextEditingController(
      text: maintenance != null
          ? DateFormat('dd/MM/yyyy').format(maintenance.date)
          : '',
    );
    _detailController = TextEditingController(text: maintenance?.detail ?? '');
    _costController = TextEditingController(
      text: maintenance?.cost != null
          ? formatWithDots(maintenance!.cost!.toStringAsFixed(0))
          : '',
    );
    _selectedDate = maintenance?.date;
    _existingInvoices = List.from(maintenance?.invoices ?? []);
    _dateController.addListener(_markDirty);
    _detailController.addListener(_markDirty);
    _costController.addListener(_markDirty);
  }

  void _markDirty() {
    if (!_hasChanges) _hasChanges = true;
  }

  Future<void> _attemptClose() async {
    final dirty = _hasChanges || _pendingFiles.isNotEmpty;
    if (dirty) {
      final discard = await confirmDelete(
        context,
        title: 'Descartar cambios',
        message: 'Tenés cambios sin guardar. ¿Querés descartarlos?',
        confirmLabel: 'Descartar',
      );
      if (!discard) return;
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _dateController.dispose();
    _detailController.dispose();
    _costController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isEditing ? 'Editar Mantenimiento' : 'Nuevo Mantenimiento',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    onPressed: _isSaving ? null : _attemptClose,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _dateController,
                readOnly: true,
                enabled: !_isSaving,
                validator: (_) => _selectedDate == null ? 'Completá la fecha' : null,
                decoration: const InputDecoration(
                  labelText: 'Fecha *',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setState(() {
                      _selectedDate = date;
                      _dateController.text = DateFormat('dd/MM/yyyy').format(date);
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _detailController,
                maxLines: 4,
                enabled: !_isSaving,
                decoration: const InputDecoration(
                  labelText: 'Detalle *',
                  alignLabelWithHint: true,
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Completá el detalle' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _costController,
                keyboardType: TextInputType.number,
                enabled: !_isSaving,
                inputFormatters: [ThousandsSeparatorFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Costo',
                  prefixText: '\$ ',
                  hintText: 'Opcional',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Facturas/Archivos',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  _isSelectingFiles
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : TextButton.icon(
                          onPressed: _isSaving ? null : () async {
                            setState(() => _isSelectingFiles = true);
                            try {
                              final result = await FilePicker.platform.pickFiles(
                                type: FileType.custom,
                                allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
                                allowMultiple: true,
                              );
                              if (result != null && result.files.isNotEmpty) {
                                setState(() {
                                  _pendingFiles.addAll(result.files);
                                });
                              }
                            } finally {
                              if (mounted) setState(() => _isSelectingFiles = false);
                            }
                          },
                          icon: const Icon(Icons.attach_file, size: 18),
                          label: const Text('Adjuntar'),
                        ),
                ],
              ),
              // Mostrar facturas existentes (solo en edición)
              if (_existingInvoices.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Adjuntos guardados (tocá para abrir):', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _existingInvoices.map((invoice) => GestureDetector(
                    onTap: () {
                      if (invoice.isPdf) {
                        _showPdfPreview(context, invoice.cloudinaryUrl, invoice.fileName);
                      } else {
                        _showFullScreenImage(context, invoice.cloudinaryUrl);
                      }
                    },
                    child: Chip(
                      avatar: Icon(
                        invoice.isPdf ? Icons.picture_as_pdf : Icons.image,
                        size: 18,
                        color: invoice.isPdf ? Colors.red : AppTheme.accentPrimary,
                      ),
                      label: Text(
                        invoice.fileName ?? 'Archivo',
                        style: const TextStyle(fontSize: 12),
                      ),
                      onDeleted: _isSaving ? null : () async {
                        if (!await confirmDelete(context,
                            title: 'Eliminar factura',
                            message: '¿Eliminar esta factura? No se puede deshacer.')) {
                          return;
                        }
                        if (!mounted) return;
                        final maintenanceRepo = ref.read(maintenanceRepositoryProvider);
                        await maintenanceRepo.deleteInvoice(invoice.id!);
                        if (!mounted) return;
                        setState(() {
                          _existingInvoices.remove(invoice);
                        });
                        ref.invalidate(maintenancesByVehicleProvider(widget.vehicleId));
                      },
                    ),
                  )).toList(),
                ),
              ],
              // Mostrar archivos pendientes
              if (_pendingFiles.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Pendientes de subir:', style: TextStyle(fontSize: 12, color: AppTheme.warning)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _pendingFiles.map((file) {
                    final isPdf = file.extension?.toLowerCase() == 'pdf';
                    return Chip(
                      avatar: Icon(
                        isPdf ? Icons.picture_as_pdf : Icons.image,
                        size: 18,
                        color: isPdf ? Colors.red : AppTheme.accentPrimary,
                      ),
                      label: Text(
                        file.name.length > 15 ? '${file.name.substring(0, 15)}...' : file.name,
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor: AppTheme.warning.withValues(alpha: 0.2),
                      onDeleted: _isSaving ? null : () {
                        setState(() {
                          _pendingFiles.remove(file);
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                            SizedBox(width: 12),
                            Text('Guardando...'),
                          ],
                        )
                      : Text(_isEditing ? 'Guardar' : 'Agregar'),
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);

    try {
      final maintenanceRepo = ref.read(maintenanceRepositoryProvider);
      final cost = _costController.text.trim().isEmpty
          ? null
          : double.tryParse(_costController.text.replaceAll('.', ''));
      String maintenanceId;

      if (_isEditing) {
        await maintenanceRepo.updateMaintenance(
          widget.maintenance!.copyWith(
            date: _selectedDate,
            detail: _detailController.text,
            cost: cost,
          ),
        );
        maintenanceId = widget.maintenance!.id!;
      } else {
        maintenanceId = await maintenanceRepo.insertMaintenance(Maintenance(
          vehicleId: widget.vehicleId,
          date: _selectedDate!,
          detail: _detailController.text,
          cost: cost,
        ));
      }

      // Subir archivos pendientes
      if (_pendingFiles.isNotEmpty) {
        final cloudinary = CloudinaryService.instance;
        for (final file in _pendingFiles) {
          if (file.path == null) continue;
          final isPdf = file.extension?.toLowerCase() == 'pdf';
          final result = await cloudinary.uploadFile(
            File(file.path!),
            isPdf: isPdf,
            fileName: file.name,
          );
          if (result != null) {
            await maintenanceRepo.insertInvoice(MaintenanceInvoice(
              maintenanceId: maintenanceId,
              cloudinaryUrl: result.url,
              cloudinaryPublicId: result.publicId,
              fileType: result.isPdf ? InvoiceFileType.pdf : InvoiceFileType.image,
              fileName: result.fileName,
            ));
          }
        }
      }

      ref.invalidate(maintenancesByVehicleProvider(widget.vehicleId));
      if (mounted) {
        Navigator.pop(context);
        widget.onSaved(_isEditing ? 'Mantenimiento actualizado' : 'Mantenimiento agregado');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _MaintenanceCard extends StatelessWidget {
  final Maintenance maintenance;
  final DateFormat dateFormat;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final bool isDeleting;

  const _MaintenanceCard({
    required this.maintenance,
    required this.dateFormat,
    required this.onTap,
    required this.onDelete,
    this.isDeleting = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isDeleting ? null : onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentPrimary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.build, color: AppTheme.accentPrimary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateFormat.format(maintenance.date),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      if (maintenance.invoices.isNotEmpty)
                        Text(
                          '${maintenance.invoices.length} adjunto(s)',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                isDeleting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 20),
                      ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              maintenance.detail,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
