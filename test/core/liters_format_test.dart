import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_vehiculos/core/utils/formatters.dart';
import 'package:gestor_vehiculos/core/utils/thousands_formatter.dart';

String _typed(String previous, String next) {
  final result = DecimalCommaFormatter().formatEditUpdate(
    TextEditingValue(text: previous, selection: TextSelection.collapsed(offset: previous.length)),
    TextEditingValue(text: next, selection: TextSelection.collapsed(offset: next.length)),
  );
  return result.text;
}

void main() {
  group('AppFormats.liters', () {
    test('muestra los 3 decimales del surtidor', () {
      expect(AppFormats.liters(28.605), '28,605 L');
    });

    test('no rellena con ceros de cola', () {
      expect(AppFormats.liters(45.5), '45,5 L');
      expect(AppFormats.liters(45), '45 L');
    });
  });

  group('formatLitersAr', () {
    test('convierte a coma y conserva 3 decimales', () {
      expect(formatLitersAr(28.605), '28,605');
      expect(formatLitersAr(45.5), '45,5');
      expect(formatLitersAr(45), '45');
    });
  });

  group('DecimalCommaFormatter', () {
    test('acepta hasta 3 decimales', () {
      expect(_typed('28,60', '28,605'), '28,605');
    });

    test('rechaza el cuarto decimal', () {
      expect(_typed('28,605', '28,6051'), '28,605');
    });

    test('el punto se retransforma a coma', () {
      expect(_typed('28', '28.'), '28,');
      expect(_typed('28.', '28.6'), '28,6');
    });

    test('rechaza una segunda coma y las letras', () {
      expect(_typed('28,6', '28,6,'), '28,6');
      expect(_typed('28', '28a'), '28');
    });
  });
}
