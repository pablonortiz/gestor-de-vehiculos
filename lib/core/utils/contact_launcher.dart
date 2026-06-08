import 'package:url_launcher/url_launcher.dart';

/// Lanza acciones de contacto (llamada / WhatsApp) a partir de un teléfono.
/// Encapsula la normalización de números argentinos para no tenerla embebida
/// en las pantallas.
class ContactLauncher {
  /// Normaliza un número argentino al formato internacional que espera wa.me:
  /// saca el 0 inicial, el 15 de celular tras el código de área, y antepone
  /// 549 si todavía no empieza con 54.
  static String normalizeArgentineMobile(String phoneNumber) {
    String n = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

    if (n.startsWith('0')) {
      n = n.substring(1);
    }

    if (n.length > 2) {
      final areaCode = n.substring(0, 2);
      final rest = n.substring(2);
      if (rest.startsWith('15')) {
        n = areaCode + rest.substring(2);
      }
    }

    if (!n.startsWith('54')) {
      n = '549$n';
    }

    return n;
  }

  /// Intenta iniciar una llamada. Devuelve false si no se pudo lanzar el `tel:`.
  static Future<bool> callPhone(String phoneNumber) async {
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$cleanNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return true;
    }
    return false;
  }

  /// Abre el chat de WhatsApp del número, con fallback al esquema nativo
  /// `whatsapp://` si falla la apertura por https.
  static Future<void> openWhatsApp(String phoneNumber) async {
    final cleanNumber = normalizeArgentineMobile(phoneNumber);
    final uri = Uri.parse('https://wa.me/$cleanNumber');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      final androidUri = Uri.parse('whatsapp://send?phone=$cleanNumber');
      await launchUrl(androidUri);
    }
  }
}
