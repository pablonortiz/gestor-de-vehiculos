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

    test('no matchea el final del importe contra el label L de la línea siguiente', () {
      // Display: importe "41892", label "L", litros "20.505". El patrón viejo
      // matcheaba "892\nL" como litros.
      final r = ocr.parseLitersFromText('41892\nL\n20.505');
      expect(r, isNotNull);
      expect(r!.$1, 20.505);
    });

    test('con importe leído con punto de miles gana el valor menor en rango', () {
      // "60.900" (importe) parsea como 60.9 y antes le ganaba a los litros
      // reales por ser mayor.
      final r = ocr.parseLitersFromText('60.900\n28.605');
      expect(r, isNotNull);
      expect(r!.$1, 28.605);
    });

    test('descarta tokens con pinta de fecha', () {
      expect(ocr.parseLitersFromText('14.07\n45.500')!.$1, 45.5);
    });

    group('requireKeyword (tickets)', () {
      test('litros anclados a "Lts" en línea de detalle', () {
        final r = ocr.parseLitersFromText(
          'NAFTA SUPER\n28,605 Lts x 2.124\nTOTAL 60.900',
          requireKeyword: true,
        );
        expect(r, isNotNull);
        expect(r!.$1, 28.605);
      });

      test('sin keyword no usa el fallback y devuelve null', () {
        expect(
          ocr.parseLitersFromText('TOTAL 60.900\n15.000,00', requireKeyword: true),
          isNull,
        );
      });
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

    test(r'entre varios montos con $ elige el mayor (unitario vs total)', () {
      final r = ocr.parsePriceFromText('\$ 2.124 por litro\n\$ 60.900');
      expect(r, isNotNull);
      expect(r!.$1, 60900);
    });
  });
}
