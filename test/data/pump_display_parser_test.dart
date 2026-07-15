import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_vehiculos/data/services/pump_display_parser.dart';

// Layouts sintéticos que replican las fotos reales de surtidores YPF que
// disparaban el bug: el importe (display de arriba) terminaba en litros.

void main() {
  group('PumpDisplayParser', () {
    test('surtidor con importe, litros y precio unitario (foto YPF 1)', () {
      // $ 60900 arriba, 28.605 L abajo, $/L 2124 en display chico.
      final lines = [
        const OcrLine(r'$', Rect.fromLTWH(215, 645, 30, 34)),
        const OcrLine('60900', Rect.fromLTWH(210, 720, 340, 88)),
        const OcrLine('28.605', Rect.fromLTWH(220, 905, 330, 84)),
        const OcrLine(r'$', Rect.fromLTWH(290, 1035, 20, 24)),
        const OcrLine('2124', Rect.fromLTWH(245, 1060, 105, 34)),
        const OcrLine('or lit', Rect.fromLTWH(60, 1040, 90, 30)),
        const OcrLine('INFINIA', Rect.fromLTWH(140, 1140, 90, 26)),
        const OcrLine('SUPER', Rect.fromLTWH(265, 1150, 80, 26)),
        const OcrLine('95', Rect.fromLTWH(160, 1380, 50, 40)),
        const OcrLine('12%', Rect.fromLTWH(215, 1385, 46, 40)),
      ];

      final r = PumpDisplayParser.parse(lines);
      expect(r.liters, 28.605);
      expect(r.price, 60900);
    });

    test('surtidor con labels L y \$/L (foto YPF 2)', () {
      final lines = [
        const OcrLine(r'$', Rect.fromLTWH(75, 260, 60, 70)),
        const OcrLine('41892', Rect.fromLTWH(40, 380, 760, 190)),
        const OcrLine('L', Rect.fromLTWH(95, 690, 40, 50)),
        const OcrLine('20.505', Rect.fromLTWH(60, 770, 720, 170)),
        const OcrLine(r'$/L', Rect.fromLTWH(240, 1010, 90, 36)),
        const OcrLine(r'$/L', Rect.fromLTWH(540, 1010, 90, 36)),
        const OcrLine('2043', Rect.fromLTWH(195, 1060, 200, 46)),
        const OcrLine('SUPER', Rect.fromLTWH(255, 1210, 110, 34)),
        const OcrLine('INFINIA DIESEL', Rect.fromLTWH(465, 1210, 210, 30)),
        const OcrLine('12%', Rect.fromLTWH(125, 1600, 60, 40)),
      ];

      final r = PumpDisplayParser.parse(lines);
      expect(r.liters, 20.505);
      expect(r.price, 41892);
    });

    test('REGRESIÓN: importe leído con punto de miles no roba el campo litros', () {
      // "60.900" parsea como 60.9 con formato de litros y está en rango 10-100.
      // La aritmética (28.605 × 2124 ≈ 60900) tiene que resolver la ambigüedad.
      final lines = [
        const OcrLine('60.900', Rect.fromLTWH(210, 720, 340, 88)),
        const OcrLine('28.605', Rect.fromLTWH(220, 905, 330, 84)),
        const OcrLine('2124', Rect.fromLTWH(245, 1060, 105, 34)),
      ];

      final r = PumpDisplayParser.parse(lines);
      expect(r.liters, 28.605);
      expect(r.price, 60900);
    });

    test('sin precio unitario legible: desempata por posición (litros abajo)', () {
      final lines = [
        const OcrLine('60.900', Rect.fromLTWH(210, 720, 340, 88)),
        const OcrLine('28.605', Rect.fromLTWH(220, 905, 330, 84)),
      ];

      final r = PumpDisplayParser.parse(lines);
      expect(r.liters, 28.605);
      expect(r.price, 60900);
    });

    test('display 7 segmentos leído con espacios se recompone', () {
      final lines = [
        const OcrLine('6 09 00', Rect.fromLTWH(210, 720, 340, 88)),
        const OcrLine('28.605', Rect.fromLTWH(220, 905, 330, 84)),
        const OcrLine('2 12 4', Rect.fromLTWH(245, 1060, 105, 34)),
      ];

      final r = PumpDisplayParser.parse(lines);
      expect(r.liters, 28.605);
      expect(r.price, 60900);
    });

    test('litros sin punto decimal se recuperan por aritmética', () {
      // Caso real (emulador): "20.505" leído como "20505" y el importe como
      // "4 1842". 20505/1000 × 2043 ≈ 41842 confirma la interpretación.
      final lines = [
        const OcrLine('4 1842', Rect.fromLTWH(40, 380, 760, 190)),
        const OcrLine('20505', Rect.fromLTWH(60, 770, 720, 170)),
        const OcrLine(r'$/L', Rect.fromLTWH(240, 1010, 90, 36)),
        const OcrLine('2043', Rect.fromLTWH(195, 1060, 200, 46)),
      ];

      final r = PumpDisplayParser.parse(lines);
      expect(r.liters, 20.505);
      expect(r.price, 41842);
    });

    test('sin aritmética que lo confirme, un entero no se toma como litros', () {
      // "20505" suelto podría ser un importe: sin importe+unitario que
      // validen, mejor no completar litros.
      final lines = [
        const OcrLine('20505', Rect.fromLTWH(60, 770, 720, 170)),
      ];

      final r = PumpDisplayParser.parse(lines);
      expect(r.liters, isNull);
    });

    test('el precio unitario solo no se confunde con el importe', () {
      // Si el OCR no leyó el importe, 2124/28.605 da un $/L implausible (74),
      // así que el precio queda vacío en vez de completarse mal.
      final lines = [
        const OcrLine('28.605', Rect.fromLTWH(220, 905, 330, 84)),
        const OcrLine('2124', Rect.fromLTWH(245, 1060, 105, 34)),
      ];

      final r = PumpDisplayParser.parse(lines);
      expect(r.liters, 28.605);
      expect(r.price, isNull);
    });

    test('solo litros legibles: precio null', () {
      final lines = [
        const OcrLine('28.605', Rect.fromLTWH(220, 905, 330, 84)),
      ];

      final r = PumpDisplayParser.parse(lines);
      expect(r.liters, 28.605);
      expect(r.price, isNull);
    });

    test('sin números devuelve vacío', () {
      final lines = [
        const OcrLine('INFINIA', Rect.fromLTWH(140, 1140, 90, 26)),
      ];

      final r = PumpDisplayParser.parse(lines);
      expect(r.liters, isNull);
      expect(r.price, isNull);
    });

    test('foto de ticket en el slot del surtidor también funciona', () {
      final lines = [
        const OcrLine('YPF ACA', Rect.fromLTWH(100, 50, 200, 30)),
        const OcrLine(r'TOTAL $60.900', Rect.fromLTWH(80, 300, 300, 30)),
        const OcrLine('28,605 Lts x 2.124', Rect.fromLTWH(80, 200, 320, 28)),
      ];

      final r = PumpDisplayParser.parse(lines);
      expect(r.liters, 28.605);
      expect(r.price, 60900);
    });
  });
}
