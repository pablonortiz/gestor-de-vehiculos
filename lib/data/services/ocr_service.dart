import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../core/utils/ar_number.dart';
import '../../domain/models/fuel_charge.dart';
import 'pump_display_parser.dart';

/// Resultado del OCR sobre una foto de carga: litros y/o precio total.
class FuelOcrResult {
  final double? liters;
  final String? litersRaw;
  final double? price;
  final String? priceRaw;
  final String? fullText;

  FuelOcrResult({
    this.liters,
    this.litersRaw,
    this.price,
    this.priceRaw,
    this.fullText,
  });

  factory FuelOcrResult.empty([String? fullText]) =>
      FuelOcrResult(fullText: fullText);

  bool get success => liters != null || price != null;
}

class OcrService {
  static final OcrService instance = OcrService._internal();
  OcrService._internal();

  // Techo plausible para un gasto de combustible: descarta CUIT (11 dígitos),
  // números de comprobante y otros tokens grandes que no son el total.
  static const double _maxPlausiblePrice = 10000000;
  // Rango plausible de litros de una carga (compartido con el form).
  static const double _maxPlausibleLiters = FuelCharge.maxPlausibleLiters;

  /// OCR de la foto del display del surtidor: litros e importe total.
  /// Usa la posición y el tamaño de las líneas reconocidas (geometría) más la
  /// relación importe ≈ litros × $/L para asignar cada número a su campo.
  Future<FuelOcrResult> extractFromPumpDisplay(File imageFile) async {
    try {
      final recognized = await _recognize(imageFile, 'display');
      if (recognized == null) return FuelOcrResult.empty();

      final fullText = recognized.text;
      if (fullText.isEmpty) return FuelOcrResult.empty(fullText);

      final lines = [
        for (final block in recognized.blocks)
          for (final line in block.lines) OcrLine(line.text, line.boundingBox),
      ];
      final values = PumpDisplayParser.parse(lines);

      var liters = values.liters;
      var litersRaw = values.litersRaw;
      // Red de seguridad si la geometría no encontró litros (p.ej. boxes
      // degenerados): caer al parseo por texto plano.
      if (liters == null) {
        final fallback = parseLitersFromText(fullText);
        liters = fallback?.$1;
        litersRaw = fallback?.$2;
      }

      debugPrint(
        'OCR display: liters=$liters ("$litersRaw") price=${values.price} ("${values.priceRaw}")',
      );
      return FuelOcrResult(
        liters: liters,
        litersRaw: litersRaw,
        price: values.price,
        priceRaw: values.priceRaw,
        fullText: fullText,
      );
    } catch (e, stack) {
      debugPrint('OCR Error extracting from pump display: $e');
      debugPrint('OCR Stack trace: $stack');
      return FuelOcrResult.empty();
    }
  }

  /// OCR de la foto del ticket: precio total y, si aparece con etiqueta
  /// ("28,605 Lts"), también los litros.
  Future<FuelOcrResult> extractFromReceipt(File imageFile) async {
    try {
      final recognized = await _recognize(imageFile, 'receipt');
      if (recognized == null) return FuelOcrResult.empty();

      final fullText = recognized.text;
      if (fullText.isEmpty) return FuelOcrResult.empty(fullText);

      final price = parsePriceFromText(fullText);
      // En un ticket un número suelto con decimales puede ser cualquier cosa;
      // solo se aceptan litros anclados a una keyword.
      final liters = parseLitersFromText(fullText, requireKeyword: true);

      debugPrint(
        'OCR receipt: price=${price?.$1} ("${price?.$2}") liters=${liters?.$1} ("${liters?.$2}")',
      );
      return FuelOcrResult(
        liters: liters?.$1,
        litersRaw: liters?.$2,
        price: price?.$1,
        priceRaw: price?.$2,
        fullText: fullText,
      );
    } catch (e, stack) {
      debugPrint('OCR Error extracting from receipt: $e');
      debugPrint('OCR Stack trace: $stack');
      return FuelOcrResult.empty();
    }
  }

  Future<RecognizedText?> _recognize(File imageFile, String label) async {
    debugPrint('OCR: Starting $label extraction from ${imageFile.path}');
    if (!await imageFile.exists()) {
      debugPrint('OCR Error: File does not exist');
      return null;
    }

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final recognized =
          await recognizer.processImage(InputImage.fromFile(imageFile));
      debugPrint(
        'OCR Text for $label (${recognized.text.length} chars): ${recognized.text}',
      );
      return recognized;
    } finally {
      await recognizer.close();
    }
  }

  /// Parsea los litros del texto OCR plano. Devuelve (valor, textoCrudo) o null.
  /// Separado del OCR para poder testearlo con texto fijo.
  @visibleForTesting
  (double, String)? parseLitersFromText(
    String fullText, {
    bool requireKeyword = false,
  }) {
    // Patrones anclados por keyword: alta confianza. El decimal es opcional
    // para tolerar lecturas enteras del surtidor (ej. "45 L"). Sin \s para no
    // cruzar de línea (evita matchear "...892\nL" del importe + label L), y
    // con \b para no arrancar en el medio de un número más largo.
    final keywordPatterns = [
      // "45 L" / "45.50 Lts" / "45,50 litros"
      RegExp(
        r'\b(\d{1,3}(?:[.,]\d{1,3})?)[ \t]*L(?:itros|ts|t)?\b',
        caseSensitive: false,
      ),
      // "Litros: 45.50" / "Vol 45" / "Cant. 45,5"
      RegExp(
        r'\b(?:litros?|vol(?:umen)?|cant(?:idad)?)\.?:?[ \t]*(\d{1,3}(?:[.,]\d{1,3})?)\b',
        caseSensitive: false,
      ),
    ];

    for (final pattern in keywordPatterns) {
      for (final match in pattern.allMatches(fullText)) {
        final rawValue = match.group(1)!;
        final value = double.tryParse(rawValue.replaceAll(',', '.'));
        if (value != null && value > 0 && value <= _maxPlausibleLiters) {
          return (value, rawValue);
        }
      }
    }

    if (requireKeyword) return null;

    // Fallback sin keyword: exige decimal (un entero suelto es demasiado
    // ambiguo) y descarta tokens con pinta de fecha/hora.
    final standalonePattern = RegExp(r'\b(\d{1,3}[.,]\d{1,3})\b');
    final dateTimeLike = RegExp(r'^([0-2]?\d|3[01])[.,][0-5]\d$');

    String? bestRaw;
    double? bestValue;
    for (final match in standalonePattern.allMatches(fullText)) {
      final rawValue = match.group(1)!;
      if (dateTimeLike.hasMatch(rawValue)) continue;
      final value = double.tryParse(rawValue.replaceAll(',', '.'));
      if (value == null || value <= 0 || value > _maxPlausibleLiters) continue;

      // Prefiere valores en el rango típico de carga (10-100 L); entre esos,
      // el MENOR: en un display el importe leído con separador ("60.900")
      // siempre es mayor que los litros reales.
      final candidateInRange = value >= 10 && value <= 100;
      final bestInRange = bestValue != null && bestValue >= 10 && bestValue <= 100;
      if (bestValue == null ||
          (candidateInRange && !bestInRange) ||
          (candidateInRange == bestInRange && value < bestValue)) {
        bestValue = value;
        bestRaw = rawValue;
      }
    }

    if (bestValue != null && bestRaw != null) return (bestValue, bestRaw);
    return null;
  }

  /// Parsea el precio del texto OCR. Devuelve (valor, textoCrudo) o null.
  /// Separado del OCR para poder testearlo con texto fijo.
  @visibleForTesting
  (double, String)? parsePriceFromText(String fullText) {
    // Patrones anclados por keyword: alta confianza.
    final keywordPatterns = [
      RegExp(r'total:?\s*\$?\s*([\d.,]+)', caseSensitive: false),
      RegExp(r'importe:?\s*\$?\s*([\d.,]+)', caseSensitive: false),
      RegExp(r'pagar:?\s*\$?\s*([\d.,]+)', caseSensitive: false),
    ];

    for (final pattern in keywordPatterns) {
      for (final match in pattern.allMatches(fullText)) {
        final rawValue = match.group(1)!;
        final value = parseArgentineAmount(rawValue);
        if (value != null && value > 100 && value < _maxPlausiblePrice) {
          return (value, rawValue);
        }
      }
    }

    // Montos con "$": el total es el mayor de ellos (un ticket puede mostrar
    // antes el precio unitario, también con "$").
    final dollarPattern = RegExp(r'\$\s*([\d.,]+)');
    String? bestRaw;
    double? bestValue;
    for (final match in dollarPattern.allMatches(fullText)) {
      final rawValue = match.group(1)!;
      final value = parseArgentineAmount(rawValue);
      if (value == null || value <= 100 || value >= _maxPlausiblePrice) continue;
      if (bestValue == null || value > bestValue) {
        bestValue = value;
        bestRaw = rawValue;
      }
    }
    if (bestValue != null && bestRaw != null) return (bestValue, bestRaw);

    // Fallback sin keyword: el total suele ser la cifra más grande del ticket,
    // pero acotada a un rango plausible para no agarrar el CUIT, el número de
    // comprobante u otros tokens grandes que no son el total.
    final standalonePattern =
        RegExp(r'\b(\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{2})?)\b');

    for (final match in standalonePattern.allMatches(fullText)) {
      final rawValue = match.group(1)!;
      final value = parseArgentineAmount(rawValue);
      if (value == null || value <= 100 || value >= _maxPlausiblePrice) continue;
      if (bestValue == null || value > bestValue) {
        bestValue = value;
        bestRaw = rawValue;
      }
    }

    if (bestValue != null && bestRaw != null) return (bestValue, bestRaw);
    return null;
  }
}
