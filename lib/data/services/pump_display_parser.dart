import 'dart:math';
import 'dart:ui';

import '../../core/utils/ar_number.dart';
import '../../domain/models/fuel_charge.dart';

/// Línea de texto reconocida por OCR con su posición en la imagen.
class OcrLine {
  final String text;
  final Rect box;

  const OcrLine(this.text, this.box);
}

/// Valores extraídos del display de un surtidor.
class PumpDisplayValues {
  final double? liters;
  final String? litersRaw;
  final double? price;
  final String? priceRaw;

  const PumpDisplayValues({
    this.liters,
    this.litersRaw,
    this.price,
    this.priceRaw,
  });
}

class _Token {
  final String raw;
  final OcrLine line;

  _Token(this.raw, this.line);

  Rect get box => line.box;
}

/// Interpreta el display de un surtidor a partir de las líneas OCR con posición.
///
/// Un surtidor muestra tres números: importe total (display grande de arriba),
/// litros (display grande de abajo, con decimales) y precio por litro (display
/// chico). Se combinan tres señales para asignar roles: la relación
/// importe ≈ litros × precio unitario, el tamaño/posición de cada línea y el
/// formato del número.
class PumpDisplayParser {
  // Tolerancia relativa para validar importe ≈ litros × precio unitario.
  static const _arithmeticTolerance = 0.03;
  // Rango plausible de $/litro: filtra que el display chico (precio unitario)
  // termine en el campo de importe y valida el par (importe, litros).
  static const _minUnitPrice = 100.0;
  static const _maxUnitPrice = 100000.0;
  static const _minPlausiblePrice = 100.0;
  static const _maxPlausiblePrice = 10000000.0;
  static const _maxLiters = FuelCharge.maxPlausibleLiters;
  // Altura mínima (relativa a la línea numérica más alta) para considerar que
  // un número está en uno de los displays principales.
  static const _bigDisplayRatio = 0.55;

  static final _numberToken = RegExp(r'\d[\d.,]*');
  static final _litersShape = RegExp(r'^\d{1,3}[.,]\d{1,3}$');
  static final _dotlessLitersShape = RegExp(r'^\d{4,6}$');
  static final _dateTimeLike = RegExp(r'^([0-2]?\d|3[01])[.,][0-5]\d$');
  static final _digitsOnlyLine = RegExp(r'^[\d\s.,]+$');
  static final _unitPriceLabel = RegExp(r'\$\s*/\s*L', caseSensitive: false);
  static final _litersKeyword = RegExp(
    r'\b(\d{1,3}(?:[.,]\d{1,3})?)[ \t]*L(?:itros|ts|t)?\b',
    caseSensitive: false,
  );

  static PumpDisplayValues parse(List<OcrLine> lines) {
    final tokens = _tokenize(lines);
    if (tokens.isEmpty) return const PumpDisplayValues();

    final maxHeight = tokens.map((t) => t.box.height).reduce(max);
    final liters = _pickLiters(tokens, maxHeight);
    final priceToken = _pickPrice(tokens, liters?.$1, liters?.$2, maxHeight);

    return PumpDisplayValues(
      liters: liters?.$2,
      litersRaw: liters?.$1.raw,
      price: priceToken != null ? parseArgentineAmount(priceToken.raw) : null,
      priceRaw: priceToken?.raw,
    );
  }

  static List<_Token> _tokenize(List<OcrLine> lines) {
    final tokens = <_Token>[];
    for (final line in lines) {
      // En una línea puramente numérica los espacios son ruido del OCR sobre
      // el display 7 segmentos ("2 12 4" → "2124").
      final source = _digitsOnlyLine.hasMatch(line.text)
          ? line.text.replaceAll(' ', '')
          : line.text;
      for (final match in _numberToken.allMatches(source)) {
        final raw = match.group(0)!.replaceAll(RegExp(r'[.,]+$'), '');
        if (raw.isEmpty) continue;
        tokens.add(_Token(raw, line));
      }
    }
    return tokens;
  }

  static double? _litersValue(_Token t) =>
      double.tryParse(t.raw.replaceAll(',', '.'));

  static bool _isLitersShaped(_Token t) {
    if (!_litersShape.hasMatch(t.raw)) return false;
    if (_dateTimeLike.hasMatch(t.raw)) return false;
    final value = _litersValue(t);
    return value != null && value > 0 && value <= _maxLiters;
  }

  static bool _isPriceShaped(_Token t) {
    // Una línea "$/L" es el precio unitario, nunca el importe.
    if (_unitPriceLabel.hasMatch(t.line.text)) return false;
    final value = parseArgentineAmount(t.raw);
    return value != null &&
        value > _minPlausiblePrice &&
        value < _maxPlausiblePrice;
  }

  static bool _isUnitShaped(_Token t) {
    final value = parseArgentineAmount(t.raw);
    return value != null && value >= _minUnitPrice && value <= _maxUnitPrice;
  }

  /// Busca un token de importe P tal que P ≈ liters × U para algún otro token
  /// U con pinta de precio unitario. Es la señal más fuerte del display: los
  /// tres números se validan entre sí.
  static _Token? _arithmeticPriceFor(
    double liters,
    List<_Token> tokens,
    _Token? exclude,
  ) {
    _Token? best;
    var bestError = _arithmeticTolerance;
    for (final p in tokens) {
      if (identical(p, exclude) || !_isPriceShaped(p)) continue;
      final priceValue = parseArgentineAmount(p.raw)!;
      for (final u in tokens) {
        if (identical(u, p) || identical(u, exclude) || !_isUnitShaped(u)) {
          continue;
        }
        final unitValue = parseArgentineAmount(u.raw)!;
        final error = (priceValue - liters * unitValue).abs() / priceValue;
        if (error <= bestError) {
          bestError = error;
          best = p;
        }
      }
    }
    return best;
  }

  static (_Token, double)? _pickLiters(List<_Token> tokens, double maxHeight) {
    (_Token, double)? best;
    var bestScore = -1;
    for (final t in tokens) {
      for (final (value, needsArithmetic) in _litersInterpretations(t)) {
        final hasArithmetic = _arithmeticPriceFor(value, tokens, t) != null;
        if (needsArithmetic && !hasArithmetic) continue;

        var score = 0;
        if (hasArithmetic) score += 4;
        final keyword = _litersKeyword.firstMatch(t.line.text);
        if (keyword != null && keyword.group(1) == t.raw) score += 2;
        if (value >= 10 && value <= 100) score += 2;
        if (t.box.height >= _bigDisplayRatio * maxHeight) score += 1;

        // Empate → el de más abajo: en el surtidor los litros van debajo del
        // importe, y un importe mal leído como "60.900" empataría en score.
        if (best == null ||
            score > bestScore ||
            (score == bestScore && t.box.center.dy > best.$1.box.center.dy)) {
          best = (t, value);
          bestScore = score;
        }
      }
    }
    return best;
  }

  /// Lecturas posibles de un token como litros. La normal exige separador
  /// decimal; la "sin punto" ("20505" → 20.505, el punto del display 7
  /// segmentos es lo primero que pierde el OCR) solo vale si la aritmética
  /// la confirma contra importe y precio unitario.
  static Iterable<(double, bool)> _litersInterpretations(_Token t) sync* {
    if (_isLitersShaped(t)) yield (_litersValue(t)!, false);
    if (_dotlessLitersShape.hasMatch(t.raw)) {
      final value = int.parse(t.raw) / 1000;
      if (value > 0 && value <= _maxLiters) yield (value, true);
    }
  }

  static _Token? _pickPrice(
    List<_Token> tokens,
    _Token? litersToken,
    double? liters,
    double maxHeight,
  ) {
    if (liters != null) {
      final validated = _arithmeticPriceFor(liters, tokens, litersToken);
      if (validated != null) return validated;
    }

    _Token? best;
    var bestScore = -1;
    var bestValue = 0.0;
    for (final t in tokens) {
      if (identical(t, litersToken) || !_isPriceShaped(t)) continue;
      final value = parseArgentineAmount(t.raw)!;

      // El importe dividido los litros tiene que dar un $/L plausible; esto
      // descarta el display chico del precio unitario (ratio ≈ unit/liters).
      if (liters != null) {
        final impliedUnit = value / liters;
        if (impliedUnit < _minUnitPrice || impliedUnit > _maxUnitPrice) {
          continue;
        }
      }

      var score = 0;
      if (t.line.text.contains(r'$')) score += 2;
      if (litersToken != null && t.box.center.dy < litersToken.box.center.dy) {
        score += 2;
      }
      if (t.box.height >= _bigDisplayRatio * maxHeight) score += 1;

      if (best == null ||
          score > bestScore ||
          (score == bestScore && value > bestValue)) {
        best = t;
        bestScore = score;
        bestValue = value;
      }
    }
    return best;
  }
}
