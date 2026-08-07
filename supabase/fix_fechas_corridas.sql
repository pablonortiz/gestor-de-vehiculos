-- Saneo one-off (2026-08): fechas guardadas a medianoche UTC.
--
-- Contexto: hasta el fix de CivilDate, el día elegido en el date picker se
-- mandaba como medianoche LOCAL sin offset. Postgres (base en UTC) lo leía
-- como medianoche UTC, y al releerlo en UTC-3 la app mostraba el día anterior.
-- Con el fix, la app ahora muestra el día tal como está almacenado en UTC.
--
-- Consecuencia: toda fila guardada a 00:00 UTC pasa a verse UN DÍA DESPUÉS de
-- lo que se veía antes del fix. Si el dato se cargó compensando (poniendo el
-- día siguiente para que se viera bien), hay que restarle un día. Si se cargó
-- con la fecha real y se venía viendo corrido, NO hay que tocarlo: el fix de
-- código ya lo deja bien.
--
-- ⚠️ Ejecutar solo los bloques cuya respuesta sea "estaba compensado".
-- ⚠️ Requiere confirmación de Pablo. Correr el SELECT de preview primero.
--
-- Después de correr esto, la app necesita un fullSync (reabrirla) para que la
-- cache local se reemplace con los valores corregidos.
--
-- ESTADO (2026-08-07, con OK de Pablo):
--   Bloque 1 (cargas de combustible) — EJECUTADO. 38 filas, del 27/02 al 21/07,
--     restadas un día. Verificado en device: las fechas se siguen viendo igual
--     que antes del fix (PBP253 julio → 20, 13, 8, 6, 1, idénticas a Supabase).
--   Bloques 2 y 3 (mantenimientos, VTV y seguro) — NO aplicar. Esas fechas se
--     cargaron sin compensar, así que el fix de código ya las endereza solo.

-- ---------------------------------------------------------------------------
-- Preview (no modifica nada)
-- ---------------------------------------------------------------------------
SELECT to_char(date, 'YYYY-MM-DD') AS almacenado_hoy,
       to_char(date - interval '1 day', 'YYYY-MM-DD') AS quedaria,
       liters, price
FROM fuel_charges
WHERE date::time = '00:00:00' AND created_at < '2026-08-07 00:00:00+00'
ORDER BY date;

-- ---------------------------------------------------------------------------
-- Bloque 1 — cargas de combustible (38 filas)
-- Aplicar SI el usuario venía compensando la fecha al cargarlas.
-- El filtro por created_at deja fuera las cargas nuevas, que ya nacen bien.
-- ---------------------------------------------------------------------------
-- UPDATE fuel_charges
-- SET date = date - interval '1 day',
--     updated_at = now()
-- WHERE date::time = '00:00:00'
--   AND created_at < '2026-08-07 00:00:00+00';

-- ---------------------------------------------------------------------------
-- Bloque 2 — mantenimientos (9 de 12 filas)
-- Aplicar SI esas fechas se cargaron compensadas. Si se cargaron con la fecha
-- real (lo más probable: nadie revisa si un mantenimiento se corrió un día),
-- dejar comentado — el fix de código ya las endereza.
-- ---------------------------------------------------------------------------
-- UPDATE maintenances
-- SET date = date - interval '1 day',
--     updated_at = now()
-- WHERE date::time = '00:00:00'
--   AND created_at < '2026-08-07 00:00:00+00';

-- ---------------------------------------------------------------------------
-- Bloque 3 — vencimientos de VTV y seguro (1 y 13 filas)
-- Mismo criterio que el bloque 2. Ojo: un vencimiento corrido un día cambia
-- cuándo la app avisa "por vencer".
-- ---------------------------------------------------------------------------
-- UPDATE vehicles
-- SET vtv_expiry = vtv_expiry - interval '1 day',
--     updated_at = now()
-- WHERE vtv_expiry::time = '00:00:00';

-- UPDATE vehicles
-- SET insurance_expiry = insurance_expiry - interval '1 day',
--     updated_at = now()
-- WHERE insurance_expiry::time = '00:00:00';
