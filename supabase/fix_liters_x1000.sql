-- Saneo one-off (2026-07): cargas de combustible con litros ×1000.
-- Causa: el surtidor muestra litros con 3 decimales (23.562) y se tipearon
-- sin el separador (23562). Desde el fix del validator (ux-fixes-jul6) la app
-- rechaza litros > 200, pero los 48 registros históricos quedaron corruptos.
--
-- Preview verificado el 2026-07-06: los 48 registros con liters > 200 dan,
-- divididos por 1000, cargas de 11–58 L con precio/litro $1.000–$2.500
-- (plausible para AR 2026).
--
-- ⚠️ Revisar aparte (no los arregla este script del todo):
--   - 33136633 y 5f8bbe29: liters ≈ price (parece precio pegado en litros).
--   - Posibles cargas duplicadas: 06-02 (x2 idénticas), 05-06/05-07,
--     05-18/05-19 (mismos litros, precio distinto).
--
-- Ejecutar en el SQL editor de Supabase (requiere confirmación de Pablo):

UPDATE fuel_charges
SET liters = liters / 1000,
    updated_at = now()
WHERE liters > 200;
