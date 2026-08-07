import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_vehiculos/core/utils/civil_date.dart';
import 'package:gestor_vehiculos/domain/models/fuel_charge.dart';

void main() {
  group('CivilDate', () {
    test('el día viaja como medianoche UTC, no como medianoche local', () {
      expect(CivilDate.toSupabase(DateTime(2026, 8, 5)), '2026-08-05T00:00:00.000Z');
    });

    test('descarta la hora: dos momentos del mismo día dan el mismo string', () {
      expect(
        CivilDate.toSupabase(DateTime(2026, 8, 5, 23, 59)),
        CivilDate.toSupabase(DateTime(2026, 8, 5, 0, 0)),
      );
    });

    test('al leer toma los componentes UTC en vez de convertir a local', () {
      final date = CivilDate.fromSupabase('2026-08-05T00:00:00+00:00');
      expect(date.year, 2026);
      expect(date.month, 8);
      expect(date.day, 5);
      expect(date.isUtc, isFalse);
    });

    test('round-trip: el día no se corre (el bug era que restaba uno)', () {
      for (final picked in [
        DateTime(2026, 8, 5),
        DateTime(2026, 1, 1),
        DateTime(2026, 12, 31),
        DateTime(2026, 3, 1),
      ]) {
        final stored = CivilDate.toSupabase(picked);
        final read = CivilDate.fromSupabase(stored);
        expect(read, picked, reason: 'se corrió la fecha en $picked');
      }
    });

    test('lee filas viejas con hora: conserva el día almacenado en UTC', () {
      expect(
        CivilDate.fromSupabase('2026-08-05T14:39:00+00:00'),
        DateTime(2026, 8, 5),
      );
    });

    test('nullable: pasa null sin tocarlo', () {
      expect(CivilDate.toSupabaseOrNull(null), isNull);
      expect(CivilDate.fromSupabaseOrNull(null), isNull);
      expect(CivilDate.fromSupabaseOrNull('2026-08-05T00:00:00Z'), DateTime(2026, 8, 5));
    });
  });

  group('FuelCharge fecha', () {
    test('round-trip Supabase de una fecha elegida en el picker', () {
      final charge = FuelCharge(
        vehicleId: 'v1',
        date: DateTime(2026, 8, 5),
        liters: 28.605,
        price: 40000,
      );

      final sent = charge.toSupabase();
      expect(sent['date'], '2026-08-05T00:00:00.000Z');

      final read = FuelCharge.fromSupabase({
        ...sent,
        'id': 'c1',
        'date': '2026-08-05T00:00:00+00:00',
        'created_at': '2026-08-05T12:00:00+00:00',
        'updated_at': '2026-08-05T12:00:00+00:00',
      });
      expect(read.date, DateTime(2026, 8, 5));
    });

    test('conserva los 3 decimales del surtidor', () {
      final charge = FuelCharge(
        vehicleId: 'v1',
        date: DateTime(2026, 8, 5),
        liters: 28.605,
        price: 40000,
      );
      expect(charge.toSupabase()['liters'], 28.605);
    });
  });
}
