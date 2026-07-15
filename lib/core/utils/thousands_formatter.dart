import 'package:flutter/services.dart';

String formatWithDots(String digits) {
  digits = digits.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return '';
  final buffer = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Formatea litros en convención es_AR: hasta 3 decimales (lo que muestra el
/// surtidor), sin ceros de cola. 28.605 → "28,605"; 45.5 → "45,5"; 45.0 → "45".
String formatLitersAr(double value) {
  final s = value.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');
  return s.replaceAll('.', ',');
}

/// Para campos decimales (ej. litros): el "." se retransforma a "," al tipear.
/// En una carga nunca van miles de litros, así que un punto solo puede querer
/// decir separador decimal — se muestra en convención es_AR en vez de castigar
/// después con un error. Admite una sola coma y solo dígitos.
class DecimalCommaFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll('.', ',');
    if (RegExp(r'^[0-9]*,?[0-9]*$').hasMatch(text)) {
      return newValue.copyWith(text: text);
    }
    return oldValue;
  }
}

class ThousandsSeparatorFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }
    final formatted = formatWithDots(digitsOnly);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
