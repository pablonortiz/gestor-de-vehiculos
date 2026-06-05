import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_vehiculos/data/services/fuel_stats.dart';
import 'package:gestor_vehiculos/domain/models/fuel_charge.dart';

FuelCharge _charge({required DateTime date, required double liters, required double price, int? odometer}) =>
    FuelCharge(
      vehicleId: 'v1',
      date: date,
      liters: liters,
      price: price,
      odometer: odometer,
    );

void main() {
  group('FuelStats.from (#A1)', () {
    test('agrega totales y promedios', () {
      final stats = FuelStats.from([
        _charge(date: DateTime(2026, 1, 1), liters: 10, price: 1000, odometer: 1000),
        _charge(date: DateTime(2026, 1, 10), liters: 20, price: 3000, odometer: 1300),
      ], true);

      expect(stats.totalLiters, 30);
      expect(stats.totalPrice, 4000);
      expect(stats.avgPricePerLiter, closeTo(133.33, 0.01));
      expect(stats.avgLitersPerCharge, 15);
      // 300 km entre 2 cargas / (2-1) = 300 km
      expect(stats.avgKmBetweenCharges, '300 km');
    });

    test('ascending ordena por fecha', () {
      final stats = FuelStats.from([
        _charge(date: DateTime(2026, 2, 1), liters: 5, price: 500),
        _charge(date: DateTime(2026, 1, 1), liters: 5, price: 500),
      ], true);
      expect(stats.sortedCharges.first.date, DateTime(2026, 1, 1));
    });

    test('lista vacía no divide por cero', () {
      final stats = FuelStats.from([], true);
      expect(stats.totalLiters, 0);
      expect(stats.avgPricePerLiter, 0);
      expect(stats.avgLitersPerCharge, 0);
      expect(stats.avgKmBetweenCharges, isNull);
    });
  });
}
