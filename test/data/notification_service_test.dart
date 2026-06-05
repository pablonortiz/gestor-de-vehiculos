import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_vehiculos/data/services/notification_service.dart';

void main() {
  group('reminderSchedule (#Ft1)', () {
    test('programa 30/7/1 días antes a las 9:00', () {
      final now = DateTime(2026, 1, 1, 12);
      final expiry = DateTime(2026, 3, 1);
      final r = reminderSchedule(expiry, now);

      expect(r.length, 3);
      expect(r[0].date, DateTime(2026, 1, 30, 9)); // 30 días antes
      expect(r[1].date, DateTime(2026, 2, 22, 9)); // 7 días antes
      expect(r[2].date, DateTime(2026, 2, 28, 9)); // 1 día antes
      expect(r.map((e) => e.index).toList(), [0, 1, 2]);
    });

    test('descarta los recordatorios que ya pasaron', () {
      final now = DateTime(2026, 2, 25, 12); // ya pasaron el de 30 y el de 7 días
      final expiry = DateTime(2026, 3, 1);
      final r = reminderSchedule(expiry, now);

      expect(r.length, 1);
      expect(r.first.index, 2);
      expect(r.first.date, DateTime(2026, 2, 28, 9));
    });

    test('un vencimiento ya pasado no programa nada', () {
      final now = DateTime(2026, 6, 1);
      final expiry = DateTime(2026, 1, 1);
      expect(reminderSchedule(expiry, now), isEmpty);
    });
  });
}
