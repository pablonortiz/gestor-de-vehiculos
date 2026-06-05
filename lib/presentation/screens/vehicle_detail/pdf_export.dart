part of '../vehicle_detail_screen.dart';

// Mostrar opciones de exportación PDF
void _showPdfOptions(
  BuildContext context,
  WidgetRef ref,
  Vehicle vehicle,
  List<VehiclePhoto> photos,
  List<DocumentPhoto> documentPhotos,
  List<Maintenance> maintenances,
  List<VehicleNote> notes,
) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textSecondary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Exportar PDF',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accentPrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.directions_car, color: AppTheme.accentPrimary),
              ),
              title: const Text(
                'Datos del vehículo',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              subtitle: const Text(
                'Información general, fotos, documentos y mantenimientos',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppTheme.border),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _exportPdf(context, ref, vehicle, photos, documentPhotos, maintenances);
              },
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accentPrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.local_gas_station, color: AppTheme.accentPrimary),
              ),
              title: const Text(
                'Registro de combustible',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              subtitle: const Text(
                'Resumen de estadísticas y detalle de todas las cargas',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppTheme.border),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showFuelReportConfig(context, ref, vehicle);
              },
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accentPrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.summarize, color: AppTheme.accentPrimary),
              ),
              title: const Text(
                'Reporte completo',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              subtitle: const Text(
                'Datos del vehículo y registro de combustible combinados',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppTheme.border),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showCombinedReportConfig(context, ref, vehicle, photos, documentPhotos, maintenances, notes);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

// Configuración del reporte de combustible
void _showFuelReportConfig(
  BuildContext context,
  WidgetRef ref,
  Vehicle vehicle,
) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _ReportConfigSheet(
      title: 'Reporte de combustible',
      periodLabel: 'Período',
      orderLabel: 'Orden',
      buttonLabel: 'Generar PDF',
      onGenerate: (startDate, endDate, ascending) {
        Navigator.pop(ctx);
        _exportFuelReport(context, ref, vehicle, startDate, endDate, ascending);
      },
    ),
  );
}

// Configuración del reporte completo combinado
void _showCombinedReportConfig(
  BuildContext context,
  WidgetRef ref,
  Vehicle vehicle,
  List<VehiclePhoto> photos,
  List<DocumentPhoto> documentPhotos,
  List<Maintenance> maintenances,
  List<VehicleNote> notes,
) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _ReportConfigSheet(
      title: 'Reporte completo',
      subtitle: 'Vehículo + Combustible',
      periodLabel: 'Período de combustible',
      orderLabel: 'Orden de cargas',
      buttonLabel: 'Generar PDF completo',
      onGenerate: (startDate, endDate, ascending) {
        Navigator.pop(ctx);
        _exportCombinedPdf(context, ref, vehicle, photos, documentPhotos, maintenances, notes, startDate, endDate, ascending);
      },
    ),
  );
}

// Hoja de configuración reutilizable: selector de período (Año / Personalizar)
// y orden (ascendente / descendente). Usada por los reportes de combustible y completo.
class _ReportConfigSheet extends StatefulWidget {
  final String title;
  final String? subtitle;
  final String periodLabel;
  final String orderLabel;
  final String buttonLabel;
  final void Function(DateTime startDate, DateTime endDate, bool ascending) onGenerate;

  const _ReportConfigSheet({
    required this.title,
    this.subtitle,
    required this.periodLabel,
    required this.orderLabel,
    required this.buttonLabel,
    required this.onGenerate,
  });

  @override
  State<_ReportConfigSheet> createState() => _ReportConfigSheetState();
}

class _ReportConfigSheetState extends State<_ReportConfigSheet> {
  final DateTime _now = DateTime.now();
  late DateTime _startDate;
  late DateTime _endDate;
  bool _ascending = true;
  bool _isCustomRange = false;

  @override
  void initState() {
    super.initState();
    _startDate = DateTime(_now.year, 1, 1);
    _endDate = _now;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textSecondary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            if (widget.subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                widget.subtitle!,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Period selection
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.periodLabel,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isCustomRange = false;
                        _startDate = DateTime(_now.year, 1, 1);
                        _endDate = _now;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: !_isCustomRange
                            ? AppTheme.accentPrimary.withOpacity(0.2)
                            : AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: !_isCustomRange ? AppTheme.accentPrimary : AppTheme.border,
                        ),
                      ),
                      child: Text(
                        'Año ${_now.year}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: !_isCustomRange ? AppTheme.accentPrimary : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final range = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: _now,
                        initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: AppTheme.accentPrimary,
                                onPrimary: AppTheme.background,
                                surface: AppTheme.surface,
                                onSurface: AppTheme.textPrimary,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (range != null) {
                        setState(() {
                          _isCustomRange = true;
                          _startDate = range.start;
                          _endDate = range.end;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _isCustomRange
                            ? AppTheme.accentPrimary.withOpacity(0.2)
                            : AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _isCustomRange ? AppTheme.accentPrimary : AppTheme.border,
                        ),
                      ),
                      child: Text(
                        _isCustomRange
                            ? '${DateFormat('dd/MM/yy').format(_startDate)} - ${DateFormat('dd/MM/yy').format(_endDate)}'
                            : 'Personalizar',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _isCustomRange ? AppTheme.accentPrimary : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Sort order
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.orderLabel,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _ascending = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _ascending
                            ? AppTheme.accentPrimary.withOpacity(0.2)
                            : AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _ascending ? AppTheme.accentPrimary : AppTheme.border,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.arrow_upward,
                            size: 16,
                            color: _ascending ? AppTheme.accentPrimary : AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Más antigua primero',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _ascending ? AppTheme.accentPrimary : AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _ascending = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: !_ascending
                            ? AppTheme.accentPrimary.withOpacity(0.2)
                            : AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: !_ascending ? AppTheme.accentPrimary : AppTheme.border,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.arrow_downward,
                            size: 16,
                            color: !_ascending ? AppTheme.accentPrimary : AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Más reciente primero',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: !_ascending ? AppTheme.accentPrimary : AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Generate button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => widget.onGenerate(_startDate, _endDate, _ascending),
                icon: const Icon(Icons.picture_as_pdf),
                label: Text(widget.buttonLabel),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Exportar reporte combinado a PDF
Future<void> _exportCombinedPdf(
  BuildContext context,
  WidgetRef ref,
  Vehicle vehicle,
  List<VehiclePhoto> photos,
  List<DocumentPhoto> documentPhotos,
  List<Maintenance> maintenances,
  List<VehicleNote> notes,
  DateTime startDate,
  DateTime endDate,
  bool ascending,
) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.surface,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          const Text(
            'Generando reporte completo...',
            style: TextStyle(color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'Preparando datos del vehículo y combustible',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    ),
  );

  var dialogOpen = true;
  try {
    final repository = ref.read(fuelChargeRepositoryProvider);
    final fuelCharges = await repository.getFuelChargesByDateRange(
      vehicle.id!,
      startDate,
      DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59),
    );

    final pdfBytes = await PdfService.generateCombinedPdf(
      vehicle: vehicle,
      photos: photos,
      documentPhotos: documentPhotos,
      maintenances: maintenances,
      notes: notes,
      fuelCharges: fuelCharges,
      startDate: startDate,
      endDate: endDate,
      ascending: ascending,
    );

    if (context.mounted) {
      Navigator.pop(context);
      dialogOpen = false;
    }

    await PdfService.sharePdf(pdfBytes, '${vehicle.plate}_completo');

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reporte completo generado exitosamente'),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  } catch (e) {
    if (dialogOpen && context.mounted) {
      Navigator.pop(context);
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al generar reporte: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }
}

// Exportar reporte de combustible a PDF
Future<void> _exportFuelReport(
  BuildContext context,
  WidgetRef ref,
  Vehicle vehicle,
  DateTime startDate,
  DateTime endDate,
  bool ascending,
) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.surface,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          const Text(
            'Generando reporte...',
            style: TextStyle(color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'Preparando reporte de combustible',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    ),
  );

  var dialogOpen = true;
  try {
    final repository = ref.read(fuelChargeRepositoryProvider);
    final fuelCharges = await repository.getFuelChargesByDateRange(
      vehicle.id!,
      startDate,
      DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59),
    );

    final pdfBytes = await PdfService.generateFuelReportPdf(
      vehicle: vehicle,
      fuelCharges: fuelCharges,
      startDate: startDate,
      endDate: endDate,
      ascending: ascending,
    );

    if (context.mounted) {
      Navigator.pop(context);
      dialogOpen = false;
    }

    await PdfService.sharePdf(pdfBytes, '${vehicle.plate}_combustible');

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reporte de combustible generado exitosamente'),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  } catch (e) {
    if (dialogOpen && context.mounted) {
      Navigator.pop(context);
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al generar reporte: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }
}

// Exportar vehículo a PDF
Future<void> _exportPdf(
  BuildContext context,
  WidgetRef ref,
  Vehicle vehicle,
  List<VehiclePhoto> photos,
  List<DocumentPhoto> documentPhotos,
  List<Maintenance> maintenances,
) async {
  // Mostrar diálogo de progreso
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.surface,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          const Text(
            'Generando PDF...',
            style: TextStyle(color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'Descargando imágenes y creando documento',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    ),
  );

  var dialogOpen = true;
  try {
    final pdfBytes = await PdfService.generateVehiclePdf(
      vehicle: vehicle,
      photos: photos,
      documentPhotos: documentPhotos,
      maintenances: maintenances,
    );

    // Cerrar diálogo de progreso
    if (context.mounted) {
      Navigator.pop(context);
      dialogOpen = false;
    }

    // Compartir/guardar PDF
    await PdfService.sharePdf(pdfBytes, vehicle.plate);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF generado exitosamente'),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  } catch (e) {
    // Solo cerrar el diálogo si seguía abierto (si falló sharePdf ya se cerró,
    // un segundo pop sacaría la pantalla de detalle de la pila).
    if (dialogOpen && context.mounted) {
      Navigator.pop(context);
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al generar PDF: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }
}
