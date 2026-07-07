import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../domain/models/fuel_charge.dart';

/// Rendimiento (km/L) por tramo entre cargas consecutivas con odómetro. Ordena
/// por odómetro, descarta cargas sin odómetro y tramos con distancia o litros no
/// positivos (datos erróneos). Pura y testeable.
List<({DateTime date, double kmPerLiter})> consumptionPoints(
    List<FuelCharge> charges) {
  final withOdometer = charges.where((c) => c.odometer != null).toList()
    ..sort((a, b) => a.odometer!.compareTo(b.odometer!));
  final points = <({DateTime date, double kmPerLiter})>[];
  for (var i = 1; i < withOdometer.length; i++) {
    final prev = withOdometer[i - 1];
    final curr = withOdometer[i];
    final km = curr.odometer! - prev.odometer!;
    if (km > 0 && curr.liters > 0) {
      points.add((date: curr.date, kmPerLiter: km / curr.liters));
    }
  }
  return points;
}

class FuelCharts extends StatelessWidget {
  final List<MonthlyFuelData> data;
  final List<FuelCharge> charges;

  const FuelCharts({
    super.key,
    required this.data,
    this.charges = const [],
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty || data.every((d) => d.totalLiters == 0)) {
      return const SizedBox.shrink();
    }

    final consumption = consumptionPoints(charges);

    return Column(
      children: [
        _LitersBarChart(data: data),
        const SizedBox(height: 24),
        _PriceLineChart(data: data),
        if (consumption.isNotEmpty) ...[
          const SizedBox(height: 24),
          _ConsumptionLineChart(points: consumption),
        ],
      ],
    );
  }
}

class _LitersBarChart extends StatelessWidget {
  final List<MonthlyFuelData> data;

  const _LitersBarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final maxLiters = data.map((d) => d.totalLiters).reduce((a, b) => a > b ? a : b);
    final maxY = (maxLiters * 1.2).ceilToDouble();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
              const Icon(
                Icons.local_gas_station,
                size: 18,
                color: AppTheme.accentPrimary,
              ),
              const SizedBox(width: 8),
              const Text(
                'Litros por Mes',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                minY: 0,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppTheme.surfaceLight,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        AppFormats.liters(rod.toY),
                        const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < data.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              data[index].monthLabel,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 10,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                      reservedSize: 30,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: AppTheme.border,
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                barGroups: data.asMap().entries.map((entry) {
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value.totalLiters,
                        color: AppTheme.accentPrimary,
                        width: 20,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceLineChart extends StatelessWidget {
  final List<MonthlyFuelData> data;

  const _PriceLineChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final dataWithValues = data.where((d) => d.averagePricePerLiter > 0).toList();
    if (dataWithValues.isEmpty) {
      return const SizedBox.shrink();
    }

    final prices = dataWithValues.map((d) => d.averagePricePerLiter).toList();
    final minPrice = prices.reduce((a, b) => a < b ? a : b);
    final maxPrice = prices.reduce((a, b) => a > b ? a : b);
    final range = maxPrice - minPrice;
    final minY = (minPrice - range * 0.2).floorToDouble();
    final maxY = (maxPrice + range * 0.2).ceilToDouble();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
              const Icon(
                Icons.trending_up,
                size: 18,
                color: AppTheme.warning,
              ),
              const SizedBox(width: 8),
              const Text(
                'Precio por Litro',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: LineChart(
              LineChartData(
                minY: minY > 0 ? minY : 0,
                maxY: maxY,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppTheme.surfaceLight,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        return LineTooltipItem(
                          '${AppFormats.money(spot.y)}/L',
                          const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < data.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              data[index].monthLabel,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 10,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                      reservedSize: 30,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 45,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          AppFormats.money(value),
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 9,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: AppTheme.border,
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: data.asMap().entries.map((entry) {
                      if (entry.value.averagePricePerLiter <= 0) {
                        return FlSpot.nullSpot;
                      }
                      return FlSpot(
                        entry.key.toDouble(),
                        entry.value.averagePricePerLiter,
                      );
                    }).toList(),
                    isCurved: true,
                    color: AppTheme.warning,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: AppTheme.warning,
                          strokeWidth: 2,
                          strokeColor: AppTheme.surface,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppTheme.warning.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConsumptionLineChart extends StatelessWidget {
  final List<({DateTime date, double kmPerLiter})> points;

  const _ConsumptionLineChart({required this.points});

  @override
  Widget build(BuildContext context) {
    // Mostramos los últimos 12 tramos para no saturar el eje.
    final shown =
        points.length > 12 ? points.sublist(points.length - 12) : points;
    final values = shown.map((p) => p.kmPerLiter).toList();
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final range = (maxV - minV).abs();
    final pad = (range == 0 ? 1.0 : range) * 0.2;
    final minY = (minV - pad).floorToDouble();
    final maxY = (maxV + pad).ceilToDouble();
    final dateFormat = DateFormat('dd/MM');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
              const Icon(Icons.speed, size: 18, color: AppTheme.accentPrimary),
              const SizedBox(width: 8),
              const Text(
                'Consumo (km/L)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: LineChart(
              LineChartData(
                minY: minY > 0 ? minY : 0,
                maxY: maxY,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppTheme.surfaceLight,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        return LineTooltipItem(
                          '${spot.y.toStringAsFixed(1)} km/L',
                          const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < shown.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              dateFormat.format(shown[index].date),
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 9,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                      reservedSize: 30,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 35,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(color: AppTheme.border, strokeWidth: 1);
                  },
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: shown
                        .asMap()
                        .entries
                        .map((e) => FlSpot(e.key.toDouble(), e.value.kmPerLiter))
                        .toList(),
                    isCurved: true,
                    color: AppTheme.accentPrimary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: AppTheme.accentPrimary,
                          strokeWidth: 2,
                          strokeColor: AppTheme.surface,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppTheme.accentPrimary.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
