/// Parsea un monto en convención argentina: "45.000,50" → 45000.50.
/// Un punto con exactamente 3 dígitos detrás se interpreta como separador de
/// miles ("60.900" → 60900); con otra cantidad, como decimal ("45.5" → 45.5).
double? parseArgentineAmount(String amount) {
  String cleaned = amount.trim();

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
      cleaned = cleaned.replaceAll('.', '');
    } else {
      final afterDot = cleaned.split('.').last;
      if (afterDot.length == 3) {
        cleaned = cleaned.replaceAll('.', '');
      }
    }
  }

  return double.tryParse(cleaned);
}
