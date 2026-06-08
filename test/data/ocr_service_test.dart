import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_vehiculos/data/services/ocr_service.dart';

void main() {
  final ocr = OcrService.instance;

  group('parseLitersFromText (#B9)', () {
    test('lectura entera con keyword "45 L" (antes no matcheaba)', () {
      final r = ocr.parseLitersFromText('45 L');
      expect(r, isNotNull);
      expect(r!.$1, 45);
    });

    test('lectura con decimal "Litros: 45,50"', () {
      expect(ocr.parseLitersFromText('Litros: 45,50')!.$1, 45.5);
    });

    test('"Vol 50" entero', () {
      expect(ocr.parseLitersFromText('Vol 50')!.$1, 50);
    });

    test('texto sin litros devuelve null', () {
      expect(ocr.parseLitersFromText('Gracias por su compra'), isNull);
    });
  });

  group('parsePriceFromText (#B8)', () {
    test('total con formato argentino', () {
      expect(ocr.parsePriceFromText(r'TOTAL $45.000,50')!.$1, 45000.5);
    });

    test('descarta el CUIT en el fallback sin keyword y toma el monto plausible', () {
      final r = ocr.parsePriceFromText('CUIT 30.712.345.678\n15.000,00');
      expect(r, isNotNull);
      expect(r!.$1, 15000);
    });

    test('precio con \$ explícito', () {
      expect(ocr.parsePriceFromText(r'Subtotal $1.500')!.$1, 1500);
    });
  });
}
