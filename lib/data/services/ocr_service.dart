import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../domain/models/fuel_charge.dart';

class OcrResult {
  final double? value;
  final String? rawText;
  final String? fullText; // Full OCR text for debugging
  final bool success;

  OcrResult({
    this.value,
    this.rawText,
    this.fullText,
    required this.success,
  });

  factory OcrResult.failure([String? fullText]) => OcrResult(success: false, fullText: fullText);

  factory OcrResult.found(double value, String rawText, [String? fullText]) =>
      OcrResult(value: value, rawText: rawText, fullText: fullText, success: true);
}

class OcrService {
  static final OcrService instance = OcrService._internal();
  OcrService._internal();

  // Techo plausible para un gasto de combustible: descarta CUIT (11 dígitos),
  // números de comprobante y otros tokens grandes que no son el total.
  static const double _maxPlausiblePrice = 10000000;
  // Rango plausible de litros de una carga (compartido con el form).
  static const double _maxPlausibleLiters = FuelCharge.maxPlausibleLiters;

  // Extract liters from a pump display photo
  Future<OcrResult> extractLiters(File imageFile) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      debugPrint('OCR: Starting liters extraction from ${imageFile.path}');

      if (!await imageFile.exists()) {
        debugPrint('OCR Error: File does not exist');
        return OcrResult.failure();
      }

      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await recognizer.processImage(inputImage);
      final fullText = recognizedText.text;

      debugPrint('OCR Text for liters (${fullText.length} chars): $fullText');

      if (fullText.isEmpty) {
        debugPrint('OCR: No text recognized in image');
        return OcrResult.failure(fullText);
      }

      final parsed = parseLitersFromText(fullText);
      if (parsed != null) {
        debugPrint('OCR: Liters extracted: ${parsed.$1} from "${parsed.$2}"');
        return OcrResult.found(parsed.$1, parsed.$2, fullText);
      }

      debugPrint('OCR: No valid liters pattern found in text');
      return OcrResult.failure(fullText);
    } catch (e, stack) {
      debugPrint('OCR Error extracting liters: $e');
      debugPrint('OCR Stack trace: $stack');
      return OcrResult.failure();
    } finally {
      await recognizer.close();
    }
  }

  // Extract price from a receipt photo
  Future<OcrResult> extractPrice(File imageFile) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      debugPrint('OCR: Starting price extraction from ${imageFile.path}');

      if (!await imageFile.exists()) {
        debugPrint('OCR Error: File does not exist');
        return OcrResult.failure();
      }

      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await recognizer.processImage(inputImage);
      final fullText = recognizedText.text;

      debugPrint('OCR Text for price (${fullText.length} chars): $fullText');

      if (fullText.isEmpty) {
        debugPrint('OCR: No text recognized in image');
        return OcrResult.failure(fullText);
      }

      final parsed = parsePriceFromText(fullText);
      if (parsed != null) {
        debugPrint('OCR: Price extracted: ${parsed.$1} from "${parsed.$2}"');
        return OcrResult.found(parsed.$1, parsed.$2, fullText);
      }

      debugPrint('OCR: No valid price pattern found in text');
      return OcrResult.failure(fullText);
    } catch (e, stack) {
      debugPrint('OCR Error extracting price: $e');
      debugPrint('OCR Stack trace: $stack');
      return OcrResult.failure();
    } finally {
      await recognizer.close();
    }
  }

  /// Parsea los litros del texto OCR. Devuelve (valor, textoCrudo) o null.
  /// Separado del OCR para poder testearlo con texto fijo.
  @visibleForTesting
  (double, String)? parseLitersFromText(String fullText) {
    // Patrones anclados por keyword: alta confianza. El decimal es opcional para
    // tolerar lecturas enteras del surtidor (ej. "45 L").
    final keywordPatterns = [
      // "45 L" / "45.50 L" / "45,50 litros"
      RegExp(r'(\d{1,3}(?:[.,]\d{1,3})?)\s*[Ll](?:itros?)?', caseSensitive: false),
      // "Litros: 45.50" / "Litros 45"
      RegExp(r'[Ll]itros?:?\s*(\d{1,3}(?:[.,]\d{1,3})?)', caseSensitive: false),
      // "Vol: 45.50" / "VOL 45"
      RegExp(r'[Vv][Oo][Ll](?:umen)?:?\s*(\d{1,3}(?:[.,]\d{1,3})?)'),
    ];

    for (final pattern in keywordPatterns) {
      final match = pattern.firstMatch(fullText);
      if (match != null) {
        final rawValue = match.group(1)!;
        final value = double.tryParse(rawValue.replaceAll(',', '.'));
        if (value != null && value > 0 && value <= _maxPlausibleLiters) {
          return (value, rawValue);
        }
      }
    }

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

      // Prefiere valores en el rango típico de carga (10-100 L); entre esos, el
      // mayor. Si ninguno califica, cae al mayor válido.
      final candidateInRange = value >= 10 && value <= 100;
      final bestInRange = bestValue != null && bestValue >= 10 && bestValue <= 100;
      if (bestValue == null ||
          (candidateInRange && !bestInRange) ||
          (candidateInRange == bestInRange && value > bestValue)) {
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
    // Patrones anclados por keyword/$ para precios argentinos: alta confianza.
    final keywordPatterns = [
      RegExp(r'[Tt][Oo][Tt][Aa][Ll]:?\s*\$?\s*([\d.,]+)'),
      RegExp(r'[Ii]mporte:?\s*\$?\s*([\d.,]+)'),
      RegExp(r'[Pp]agar:?\s*\$?\s*([\d.,]+)'),
      RegExp(r'\$\s*([\d.,]+)'),
    ];

    for (final pattern in keywordPatterns) {
      final match = pattern.firstMatch(fullText);
      if (match != null) {
        final rawValue = match.group(1)!;
        final value = _parseArgentinePrice(rawValue);
        if (value != null && value > 100 && value < _maxPlausiblePrice) {
          return (value, rawValue);
        }
      }
    }

    // Fallback sin keyword: el total suele ser la cifra más grande del ticket,
    // pero acotada a un rango plausible para no agarrar el CUIT, el número de
    // comprobante u otros tokens grandes que no son el total.
    final standalonePattern =
        RegExp(r'\b(\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{2})?)\b');

    String? bestRaw;
    double? bestValue;
    for (final match in standalonePattern.allMatches(fullText)) {
      final rawValue = match.group(1)!;
      final value = _parseArgentinePrice(rawValue);
      if (value == null || value <= 100 || value >= _maxPlausiblePrice) continue;
      if (bestValue == null || value > bestValue) {
        bestValue = value;
        bestRaw = rawValue;
      }
    }

    if (bestValue != null && bestRaw != null) return (bestValue, bestRaw);
    return null;
  }

  // Parse Argentine price format: "45.000,50" -> 45000.50
  double? _parseArgentinePrice(String priceStr) {
    String cleaned = priceStr.trim();

    // Coma como separador decimal (formato argentino "45.000,50" = 45000.50).
    if (cleaned.contains(',')) {
      final parts = cleaned.split(',');
      if (parts.length == 2) {
        final integerPart = parts[0].replaceAll('.', '');
        final decimalPart = parts[1];
        cleaned = '$integerPart.$decimalPart';
      } else {
        cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
      }
    } else if (cleaned.contains('.')) {
      final dotCount = '.'.allMatches(cleaned).length;
      if (dotCount > 1) {
        // Varios puntos = separadores de miles, sin decimal.
        cleaned = cleaned.replaceAll('.', '');
      } else {
        final afterDot = cleaned.split('.').last;
        if (afterDot.length == 3) {
          // Probable separador de miles.
          cleaned = cleaned.replaceAll('.', '');
        }
        // Si no, se mantiene como separador decimal.
      }
    }

    return double.tryParse(cleaned);
  }
}
