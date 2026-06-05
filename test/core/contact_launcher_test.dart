import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_vehiculos/core/utils/contact_launcher.dart';

void main() {
  group('ContactLauncher.normalizeArgentineMobile (#A7)', () {
    test('celular de Buenos Aires con 0 y 15 → internacional', () {
      // 011 15 1234-5678 → quita 0, quita 15 → 1112345678 → 5491112345678
      expect(
        ContactLauncher.normalizeArgentineMobile('011 15 1234-5678'),
        '5491112345678',
      );
    });

    test('número ya en formato internacional se mantiene', () {
      expect(
        ContactLauncher.normalizeArgentineMobile('5491112345678'),
        '5491112345678',
      );
    });

    test('número sin 0 ni 15 antepone 549', () {
      expect(
        ContactLauncher.normalizeArgentineMobile('1112345678'),
        '5491112345678',
      );
    });
  });
}
