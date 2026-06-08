/// Parseo tolerante de enums serializados desde DB/Supabase/JSON.
///
/// Evita que un valor fuera de rango (índice nuevo de otra versión, dato
/// corrupto) o un nombre desconocido haga crashear toda la deserialización.
/// Devuelve [fallback] en vez de lanzar.
T enumFromIndex<T>(List<T> values, Object? index, T fallback) {
  if (index is int && index >= 0 && index < values.length) {
    return values[index];
  }
  return fallback;
}

T enumFromName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}
