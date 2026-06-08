part of '../vehicle_detail_screen.dart';

// Sección de cargas de combustible
class _FuelChargesSection extends ConsumerStatefulWidget {
  final List<FuelCharge> recentCharges;
  final String vehicleId;

  const _FuelChargesSection({
    required this.recentCharges,
    required this.vehicleId,
  });

  @override
  ConsumerState<_FuelChargesSection> createState() => _FuelChargesSectionState();
}

class _FuelChargesSectionState extends ConsumerState<_FuelChargesSection> {
  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final currencyFormat = NumberFormat.currency(
      locale: 'es_AR',
      symbol: '\$',
      decimalDigits: 0,
    );

    // Get current month summary
    final now = DateTime.now();
    final summaryParams = MonthlyFuelParams(
      vehicleId: widget.vehicleId,
      year: now.year,
      month: now.month,
    );
    final summaryAsync = ref.watch(fuelChargeSummaryProvider(summaryParams));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const _SectionTitle(title: 'Combustible'),
            TextButton.icon(
              onPressed: () => context.push('/vehicle/${widget.vehicleId}/fuel'),
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text('Ver historial'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.accentPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Monthly summary card (variante compacta del widget compartido)
        summaryAsync.when(
          data: (summary) => FuelSummaryCard(summary: summary, compact: true),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const SizedBox.shrink(),
        ),

        if (widget.recentCharges.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Últimas cargas',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          ...widget.recentCharges.map((charge) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.local_gas_station,
                    size: 16,
                    color: AppTheme.accentPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${charge.liters.toStringAsFixed(1)} L',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        dateFormat.format(charge.date),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  currencyFormat.format(charge.price),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.accentPrimary,
                  ),
                ),
              ],
            ),
          )),
        ],
      ],
    );
  }
}

