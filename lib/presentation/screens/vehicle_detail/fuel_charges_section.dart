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

        // Monthly summary card
        summaryAsync.when(
          data: (summary) => Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.accentPrimary.withOpacity(0.1),
                  AppTheme.accentDark.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.accentPrimary.withOpacity(0.2)),
            ),
            child: summary.chargeCount == 0
                ? const Center(
                    child: Text(
                      'Sin cargas este mes',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _FuelSummaryItem(
                        icon: Icons.local_gas_station,
                        value: '${summary.totalLiters.toStringAsFixed(1)} L',
                        label: 'Este mes',
                      ),
                      Container(
                        width: 1,
                        height: 30,
                        color: AppTheme.border,
                      ),
                      _FuelSummaryItem(
                        icon: Icons.attach_money,
                        value: currencyFormat.format(summary.totalPrice),
                        label: 'Gastado',
                      ),
                      Container(
                        width: 1,
                        height: 30,
                        color: AppTheme.border,
                      ),
                      _FuelSummaryItem(
                        icon: Icons.trending_up,
                        value: '${currencyFormat.format(summary.averagePricePerLiter)}/L',
                        label: 'Promedio',
                      ),
                    ],
                  ),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const SizedBox.shrink(),
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
                    color: AppTheme.accentPrimary.withOpacity(0.1),
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

class _FuelSummaryItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _FuelSummaryItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppTheme.accentPrimary, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}
