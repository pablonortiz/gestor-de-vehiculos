-- Saneo one-off (2026-07): ciudades y lugares duplicados / mal tipeados.
-- Causa: carga manual sin catálogo cerrado — el mismo sitio se tipeó con
-- variantes de mayúsculas, puntos finales y typos, y a veces la radio se
-- cargó como "ciudad". Resultado: 16 cities que son 11 reales y 25 lugares
-- que son 10.
--
-- Mapeo canónico confirmado por Pablo el 2026-07-07:
--   BA:        Talar de Pacheco (+ "planta transmisora" pasa a lugar)
--   CABA:      CABA / LRA1
--   Chubut:    Comodoro Rivadavia
--   Córdoba:   Córdoba Capital / Planta transmisora
--   Corrientes: Paso de los Libres / LT12 Gral. Madariaga / Paso de los Libres
--              (las 3 cities y 9 lugares de LT12 se fusionan en ese único par)
--   E. Ríos:   Concepción del Uruguay / LT11 Concepción del Uruguay
--              Gualeguaychú / LRA42 · Paraná / LT14 Paraná Gral. Urquiza
--   Mendoza:   San Rafael / LV4 San Rafael · Malargüe / LV19 Malargüe
--   S. Cruz:   Lago Argentino / LU23 Lago Argentino
--
-- Orden FK-safe: primero se repuntan los vehículos, después se borran las
-- variantes (vehicles.city_id/lugar_id son NO ACTION; lugares.city_id es
-- CASCADE, por eso las cities sobrantes se borran al final y sin lugares
-- vivos adentro). Los renames van después de los deletes para no chocar
-- nombres normalizados. La UI muestra los campos texto de vehicles, así que
-- al final se re-sincronizan desde el catálogo.

-- ── 1. Repuntar vehículos a las filas canónicas ─────────────────────────────

-- Pacheco: EOG690 (city "Talar de Pacheco planta transmisora" → Talar de Pacheco)
UPDATE vehicles
SET city_id = '8626b49f-7f73-477a-895a-5caf8d19e908',
    lugar_id = '40f1dc1b-92d4-4430-9b71-9abcd55de113',
    updated_at = now()
WHERE city_id = 'e481b80e-f977-4bfa-8732-e8b3901a85c0';

-- CABA: AF053FS ("Lra1" → "LRA 1", que después se renombra a LRA1)
UPDATE vehicles
SET lugar_id = '629991dc-25f9-4ba8-a44b-1623e69e23ee',
    updated_at = now()
WHERE lugar_id = '4b109ba7-2bc6-4626-b029-c60bff498718';

-- Corrientes: W0H856, BEQ129, GUV755, WOH855 → par canónico único
UPDATE vehicles
SET city_id = '92fb4029-3aa3-4259-9f6a-ee9d0248e4ee',
    lugar_id = 'fecf2a51-4dd9-4f94-8ebe-346a622a0371',
    updated_at = now()
WHERE city_id IN ('0931f894-aea7-481a-a905-22a51d22202c',
                  'dc5eaf97-3644-44ff-92ba-8416c97527e5');

-- Concepción del Uruguay: TWI197
UPDATE vehicles
SET city_id = 'e0730275-ae1e-42e7-89cf-8fa7e59bedb5',
    lugar_id = 'd1b6d21c-2192-4730-a503-88a4785d38ea',
    updated_at = now()
WHERE city_id = 'e2dfc0de-4ef8-4535-868d-6729c24f9fbc';

-- San Rafael: NFQ548
UPDATE vehicles
SET city_id = '4c60161a-641b-4523-a324-5fc458b5ba13',
    lugar_id = 'fcbbb7f0-1f91-4e04-99a1-b91cfe50ed70',
    updated_at = now()
WHERE city_id = 'b90dfdf0-4c0c-4f6f-98ee-12239908f5b0';

-- ── 2. Borrar lugares sobrantes (15) ────────────────────────────────────────

DELETE FROM lugares WHERE id IN (
  'a61b3fa1-1556-426d-96ed-d9289a00fb6b', -- Planta de Pacheco
  '186e971f-7877-4927-b5d6-72da1d7dc46a', -- Talar de Pacheco.
  '4b109ba7-2bc6-4626-b029-c60bff498718', -- Lra1
  '04cf847b-8c95-4181-8674-fe5276dd5ed0', -- LT12 Gral Madariaga
  '2cd7fa36-702b-4ce2-84ec-a6b13b20ca33', -- LT12 gral. Madariaga
  '5b9abc2e-95df-4b6a-9b93-8b480364ada8', -- LT12 PASO DE LIS LIBRES
  '9c6745f5-01bf-4c83-90fc-8c1015ddcee5', -- LT12 PASO DE LOS LIBRES
  'ace138d8-ad56-4ca0-8e5f-7ae355220485', -- LT12 GRAL. MADARIAGA.
  '815f2f06-1a7a-471f-87df-4f92636b476e', -- LT12 PASO DE LOS LIBRES.
  'd9b4192e-ae3b-4a47-9695-21d77d788027', -- LT12 GRAL. MADARIAGA. (bis)
  'f8a29509-7b80-46ec-954f-f6b6d9890941', -- Lt12 paso de los libres
  'fceb2c97-fc30-445d-8bef-59804a1dfff0', -- LT11 Concepción del Uruguay (dup)
  '27de5af6-d5dc-4f00-ba5a-f2c1aa07dfe8', -- concepción del Uruguay entre Rios
  'bd1ae4eb-10ef-4ea0-a600-8442844b471a', -- LV19 Malargüe (huérfano en San Rafael.)
  'eb8fb4f7-b8e5-4fb2-ad5b-0d3fcc2c5366'  -- LV4 San Rafael (dup)
);

-- ── 3. Borrar cities sobrantes (5) ──────────────────────────────────────────

DELETE FROM cities WHERE id IN (
  'e481b80e-f977-4bfa-8732-e8b3901a85c0', -- Talar de Pacheco planta transmisora
  '0931f894-aea7-481a-a905-22a51d22202c', -- LT12 Gral. Madariaga
  'dc5eaf97-3644-44ff-92ba-8416c97527e5', -- LT12 Gral. MADARIAGA.
  'e2dfc0de-4ef8-4535-868d-6729c24f9fbc', -- LT11 Concepción del Uruguay
  'b90dfdf0-4c0c-4f6f-98ee-12239908f5b0'  -- San Rafael.
);

-- ── 4. Renombrar filas canónicas (name_normalized = lowercase sin acentos,
--       igual que TextNormalizer.normalize de la app) ─────────────────────────

UPDATE cities SET name = 'CABA', name_normalized = 'caba', updated_at = now()
WHERE id = 'da59bbc9-4749-4aa0-8ea8-5c3dafb80254';

UPDATE cities SET name = 'Comodoro Rivadavia', name_normalized = 'comodoro rivadavia', updated_at = now()
WHERE id = 'ff5b5a29-5ab8-4482-a057-c0cba39e207d';

UPDATE cities SET name = 'Córdoba Capital', name_normalized = 'cordoba capital', updated_at = now()
WHERE id = '9af5617e-5857-42ef-afa1-e75590dfe669';

UPDATE cities SET name = 'Paso de los Libres', name_normalized = 'paso de los libres', updated_at = now()
WHERE id = '92fb4029-3aa3-4259-9f6a-ee9d0248e4ee';

UPDATE cities SET name = 'Concepción del Uruguay', name_normalized = 'concepcion del uruguay', updated_at = now()
WHERE id = 'e0730275-ae1e-42e7-89cf-8fa7e59bedb5';

UPDATE cities SET name = 'Paraná', name_normalized = 'parana', updated_at = now()
WHERE id = '81d8291a-47ef-4115-b459-e77e00f79be0';

UPDATE cities SET name = 'San Rafael', name_normalized = 'san rafael', updated_at = now()
WHERE id = '4c60161a-641b-4523-a324-5fc458b5ba13';

UPDATE cities SET name = 'Lago Argentino', name_normalized = 'lago argentino', updated_at = now()
WHERE id = '5c5d0414-3a62-48b1-8ebc-2e216e0dcc3f';

UPDATE lugares SET name = 'Planta transmisora Pacheco', name_normalized = 'planta transmisora pacheco', updated_at = now()
WHERE id = '40f1dc1b-92d4-4430-9b71-9abcd55de113';

UPDATE lugares SET name = 'LRA1', name_normalized = 'lra1', updated_at = now()
WHERE id = '629991dc-25f9-4ba8-a44b-1623e69e23ee';

UPDATE lugares SET name = 'Planta transmisora', name_normalized = 'planta transmisora', updated_at = now()
WHERE id = '83733f3e-91ba-4e9c-a98a-b14e86f0f203';

UPDATE lugares SET name = 'LT12 Gral. Madariaga / Paso de los Libres', name_normalized = 'lt12 gral. madariaga / paso de los libres', updated_at = now()
WHERE id = 'fecf2a51-4dd9-4f94-8ebe-346a622a0371';

UPDATE lugares SET name = 'LT11 Concepción del Uruguay', name_normalized = 'lt11 concepcion del uruguay', updated_at = now()
WHERE id = 'd1b6d21c-2192-4730-a503-88a4785d38ea';

UPDATE lugares SET name = 'LRA42', name_normalized = 'lra42', updated_at = now()
WHERE id = '40f15ff4-ab54-4559-b8e0-89509f79f723';

UPDATE lugares SET name = 'LT14 Paraná Gral. Urquiza', name_normalized = 'lt14 parana gral. urquiza', updated_at = now()
WHERE id = 'f8f7aa36-20ee-4a3d-b869-5dca8493c5d6';

UPDATE lugares SET name = 'LV4 San Rafael', name_normalized = 'lv4 san rafael', updated_at = now()
WHERE id = 'fcbbb7f0-1f91-4e04-99a1-b91cfe50ed70';

UPDATE lugares SET name = 'LU23 Lago Argentino', name_normalized = 'lu23 lago argentino', updated_at = now()
WHERE id = '41c95802-9d3b-4a67-93d7-307dcf04557a';

-- ── 5. Re-sincronizar los campos texto denormalizados de vehicles
--       (la UI muestra vehicles.city / vehicles.lugar, no el join) ────────────

UPDATE vehicles v SET city = c.name, updated_at = now()
FROM cities c
WHERE v.city_id = c.id AND v.city IS DISTINCT FROM c.name;

UPDATE vehicles v SET lugar = l.name, updated_at = now()
FROM lugares l
WHERE v.lugar_id = l.id AND v.lugar IS DISTINCT FROM l.name;

-- Verificación post-saneo esperada:
--   SELECT count(*) FROM cities;   -- 11
--   SELECT count(*) FROM lugares;  -- 10
--   SELECT count(*) FROM vehicles v LEFT JOIN cities c ON c.id = v.city_id
--     WHERE c.id IS NULL;          -- 0 (sin refs rotos)
--   SELECT count(*) FROM vehicles v WHERE v.lugar_id IS NOT NULL
--     AND NOT EXISTS (SELECT 1 FROM lugares l WHERE l.id = v.lugar_id); -- 0
