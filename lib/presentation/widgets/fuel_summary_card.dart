import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/fuel_charge.dart';

/// Resumen mensual de combustible. Dos variantes:
/// - completa (default): 4 KPIs con divisores, usada en la pantalla dedicada.
/// - [compact]: 3 KPIs, estilo más sutil y sin margen, para la sección del detalle.
class FuelSummaryCard extends StatelessWidget {
  final FuelChargeSummary summary;
  final bool compact;

  const FuelSummaryCard({
    super.key,
    required this.summary,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'es_AR',
      symbol: '\$',
      decimalDigits: 0,
    );

    return Container(
      margin: compact ? EdgeInsets.zero : const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.accentPrimary.withValues(alpha: compact ? 0.1 : 0.15),
            AppTheme.accentDark.withValues(alpha: compact ? 0.05 : 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(compact ? 12 : 16),
        border: Border.all(
          color: AppTheme.accentPrimary.withValues(alpha: compact ? 0.2 : 0.3),
        ),
      ),
      child: summary.chargeCount == 0
          ? _buildEmptyState()
          : (compact
              ? _buildCompactContent(currencyFormat)
              : _buildFullContent(currencyFormat)),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Sin cargas este mes',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildFullContent(NumberFormat currencyFormat) {
    return Row(
      children: [
        Expanded(
          child: _SummaryItem(
            icon: Icons.local_gas_station,
            label: 'Total',
            value: '${summary.totalLiters.toStringAsFixed(1)} L',
          ),
        ),
        _divider(40),
        Expanded(
          child: _SummaryItem(
            icon: Icons.attach_money,
            label: 'Gastado',
            value: currencyFormat.format(summary.totalPrice),
          ),
        ),
        _divider(40),
        Expanded(
          child: _SummaryItem(
            icon: Icons.trending_up,
            label: 'Promedio',
            value: '${currencyFormat.format(summary.averagePricePerLiter)}/L',
          ),
        ),
        _divider(40),
        Expanded(
          child: _SummaryItem(
            icon: Icons.format_list_numbered,
            label: 'Cargas',
            value: summary.chargeCount.toString(),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactContent(NumberFormat currencyFormat) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _SummaryItem(
          icon: Icons.local_gas_station,
          label: 'Este mes',
          value: '${summary.totalLiters.toStringAsFixed(1)} L',
          compact: true,
        ),
        _divider(30),
        _SummaryItem(
          icon: Icons.attach_money,
          label: 'Gastado',
          value: currencyFormat.format(summary.totalPrice),
          compact: true,
        ),
        _divider(30),
        _SummaryItem(
          icon: Icons.trending_up,
          label: 'Promedio',
          value: '${currencyFormat.format(summary.averagePricePerLiter)}/L',
          compact: true,
        ),
      ],
    );
  }

  Widget _divider(double height) => Container(
        width: 1,
        height: height,
        color: AppTheme.border,
      );
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool compact;

  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.value,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppTheme.accentPrimary, size: compact ? 18 : 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: compact ? 12 : 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppTheme.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
