/// Fechas que representan un día del calendario (la fecha de una carga, un
/// vencimiento de VTV) y no un instante.
///
/// Las columnas en Supabase son TIMESTAMPTZ y la base corre en UTC: un string
/// ISO sin offset se interpreta como UTC. Mandar la medianoche local que
/// devuelve el date picker hacía que al releerla en UTC-3 la fecha se corriera
/// al día anterior. Por eso el día viaja siempre como medianoche UTC, y al
/// leerlo se toman los componentes UTC en vez de convertir a hora local.
class CivilDate {
  CivilDate._();

  static String toSupabase(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day).toIso8601String();

  static String? toSupabaseOrNull(DateTime? date) =>
      date == null ? null : toSupabase(date);

  static DateTime fromSupabase(String value) {
    final utc = DateTime.parse(value).toUtc();
    return DateTime(utc.year, utc.month, utc.day);
  }

  static DateTime? fromSupabaseOrNull(Object? value) =>
      value == null ? null : fromSupabase(value as String);
}
