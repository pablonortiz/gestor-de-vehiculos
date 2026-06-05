import 'package:intl/intl.dart';
import '../../domain/models/fuel_charge.dart';

/// Estadísticas agregadas de un período de cargas de combustible.
/// Lógica pura (sin dependencias de la generación de PDF) para poder testearla.
class FuelStats {
  final List<FuelCharge> sortedCharges;
  final double totalLiters;
  final double totalPrice;
  final double avgPricePerLiter;
  final double avgLitersPerCharge;
  final String? avgKmBetweenCharges;

  FuelStats._({
    required this.sortedCharges,
    required this.totalLiters,
    required this.totalPrice,
    required this.avgPricePerLiter,
    required this.avgLitersPerCharge,
    required this.avgKmBetweenCharges,
  });

  factory FuelStats.from(List<FuelCharge> fuelCharges, bool ascending) {
    final numberFormat = NumberFormat('#,###');

    final sortedCharges = List<FuelCharge>.from(fuelCharges);
    sortedCharges.sort((a, b) => ascending
        ? a.date.compareTo(b.date)
        : b.date.compareTo(a.date));

    final totalLiters = sortedCharges.fold<double>(0, (sum, c) => sum + c.liters);
    final totalPrice = sortedCharges.fold<double>(0, (sum, c) => sum + c.price);
    final avgPricePerLiter = totalLiters > 0 ? totalPrice / totalLiters : 0.0;
    final avgLitersPerCharge = sortedCharges.isNotEmpty ? totalLiters / sortedCharges.length : 0.0;

    String? avgKmBetweenCharges;
    final chargesWithOdometer = sortedCharges.where((c) => c.odometer != null).toList();
    chargesWithOdometer.sort((a, b) => a.date.compareTo(b.date));
    if (chargesWithOdometer.length >= 2) {
      final totalKm = chargesWithOdometer.last.odometer! - chargesWithOdometer.first.odometer!;
      final avgKm = totalKm / (chargesWithOdometer.length - 1);
      avgKmBetweenCharges = '${numberFormat.format(avgKm.round())} km';
    }

    return FuelStats._(
      sortedCharges: sortedCharges,
      totalLiters: totalLiters,
      totalPrice: totalPrice,
      avgPricePerLiter: avgPricePerLiter,
      avgLitersPerCharge: avgLitersPerCharge,
      avgKmBetweenCharges: avgKmBetweenCharges,
    );
  }
}
