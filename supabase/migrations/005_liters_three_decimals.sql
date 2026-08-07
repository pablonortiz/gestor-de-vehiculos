-- Litros con 3 decimales (2026-08): el surtidor muestra 3 (28,605 L) y la
-- columna era DECIMAL(10,2), así que Postgres redondeaba el tercero. Como el
-- fullSync baja de Supabase y reemplaza la cache local, el valor redondeado
-- pisaba al que SQLite (REAL) sí había guardado bien.
--
-- Ampliar la escala no pierde datos. El tope de litros por carga lo impone el
-- validator de la app (200 L), muy por debajo de los 7 enteros que deja (10,3).
--
-- Los 3ros decimales de los registros históricos ya se perdieron al guardarse;
-- no son recuperables por SQL.

ALTER TABLE fuel_charges
  ALTER COLUMN liters TYPE DECIMAL(10,3);
