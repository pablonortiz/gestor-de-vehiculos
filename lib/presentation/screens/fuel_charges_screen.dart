import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/fuel_charge.dart';
import '../providers/fuel_charge_provider.dart';
import '../widgets/month_navigator.dart';
import '../widgets/fuel_summary_card.dart';
import '../widgets/fuel_charge_card.dart';
import '../widgets/fuel_charts.dart';
import '../widgets/fuel_charge_form_sheet.dart';

class FuelChargesScreen extends ConsumerStatefulWidget {
  final String vehicleId;

  const FuelChargesScreen({
    super.key,
    required this.vehicleId,
  });

  @override
  ConsumerState<FuelChargesScreen> createState() => _FuelChargesScreenState();
}

class _FuelChargesScreenState extends ConsumerState<FuelChargesScreen> {
  bool _showCharts = false;
  String? _deletingId;

  @override
  Widget build(BuildContext context) {
    final selectedMonth = ref.watch(selectedMonthProvider(widget.vehicleId));
    final chargesParams = MonthlyFuelParams(
      vehicleId: widget.vehicleId,
      year: selectedMonth.year,
      month: selectedMonth.month,
    );
    final chargesAsync = ref.watch(fuelChargesByMonthProvider(chargesParams));
    final summaryAsync = ref.watch(fuelChargeSummaryProvider(chargesParams));
    final chartDataAsync = ref.watch(fuelChartDataProvider(
      ChartDataParams(vehicleId: widget.vehicleId, months: 6),
    ));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cargas de Combustible'),
        actions: [
          IconButton(
            onPressed: () {
              setState(() => _showCharts = !_showCharts);
            },
            icon: Icon(
              _showCharts ? Icons.bar_chart : Icons.bar_chart_outlined,
              color: _showCharts ? AppTheme.accentPrimary : AppTheme.textSecondary,
            ),
            tooltip: 'Ver estadísticas',
          ),
        ],
      ),
      body: Column(
        children: [
          MonthNavigator(
            selectedMonth: selectedMonth,
            onPreviousMonth: () {
              ref.read(selectedMonthProvider(widget.vehicleId).notifier).state =
                  selectedMonth.previousMonth();
            },
            onNextMonth: () {
              ref.read(selectedMonthProvider(widget.vehicleId).notifier).state =
                  selectedMonth.nextMonth();
            },
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(fuelChargesByMonthProvider(chargesParams));
                ref.invalidate(fuelChargeSummaryProvider(chargesParams));
                ref.invalidate(fuelChartDataProvider(
                  ChartDataParams(vehicleId: widget.vehicleId, months: 6),
                ));
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // Summary card
                    summaryAsync.when(
                      data: (summary) => FuelSummaryCard(summary: summary),
                      loading: () => const Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                      error: (e, _) => Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('Error: $e'),
                      ),
                    ),
                    // Charts section (collapsible)
                    if (_showCharts)
                      chartDataAsync.when(
                        data: (data) => FuelCharts(data: data),
                        loading: () => const Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(),
                        ),
                        error: (e, _) => const SizedBox.shrink(),
                      ),
                    if (_showCharts) const SizedBox(height: 16),
                    // Charges list
                    chargesAsync.when(
                      data: (charges) {
                        if (charges.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.local_gas_station_outlined,
                                  size: 64,
                                  color: AppTheme.textSecondary.withOpacity(0.5),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No hay cargas este mes',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return Column(
                          children: charges.map((charge) => FuelChargeCard(
                            fuelCharge: charge,
                            onTap: () => _showFuelChargeForm(charge),
                            onDelete: () => _deleteCharge(charge),
                            isDeleting: _deletingId == charge.id,
                          )).toList(),
                        );
                      },
                      loading: () => const Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                      error: (e, _) => Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('Error: $e'),
                      ),
                    ),
                    const SizedBox(height: 80), // Space for FAB
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showFuelChargeForm(null),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _deleteCharge(FuelCharge charge) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar carga'),
        content: const Text('¿Estás seguro de eliminar esta carga de combustible?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );

    if (confirmed != true || charge.id == null) return;

    setState(() => _deletingId = charge.id);

    try {
      final repo = ref.read(fuelChargeRepositoryProvider);
      await repo.deleteFuelCharge(charge.id!);

      // Refresh data
      final selectedMonth = ref.read(selectedMonthProvider(widget.vehicleId));
      final params = MonthlyFuelParams(
        vehicleId: widget.vehicleId,
        year: selectedMonth.year,
        month: selectedMonth.month,
      );
      ref.invalidate(fuelChargesByMonthProvider(params));
      ref.invalidate(fuelChargeSummaryProvider(params));
      ref.invalidate(fuelChartDataProvider(
        ChartDataParams(vehicleId: widget.vehicleId, months: 6),
      ));
      ref.invalidate(recentFuelChargesProvider(widget.vehicleId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Carga eliminada')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _deletingId = null);
      }
    }
  }

  void _showFuelChargeForm(FuelCharge? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FuelChargeFormSheet(
        vehicleId: widget.vehicleId,
        existing: existing,
        onSaved: () {
          final selectedMonth = ref.read(selectedMonthProvider(widget.vehicleId));
          final params = MonthlyFuelParams(
            vehicleId: widget.vehicleId,
            year: selectedMonth.year,
            month: selectedMonth.month,
          );
          ref.invalidate(fuelChargesByMonthProvider(params));
          ref.invalidate(fuelChargeSummaryProvider(params));
          ref.invalidate(fuelChartDataProvider(
            ChartDataParams(vehicleId: widget.vehicleId, months: 6),
          ));
          ref.invalidate(recentFuelChargesProvider(widget.vehicleId));
        },
      ),
    );
  }
}
