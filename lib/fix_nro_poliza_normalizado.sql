-- ═══════════════════════════════════════════════════════════════════════════
-- Fix: comparar nro_poliza ignorando espacios/separadores.
-- "1 0987 2" y "109872" deben detectarse como el mismo número de póliza.
-- Ejecutar en el SQL Editor de Supabase. Es seguro volver a correrlo.
-- ═══════════════════════════════════════════════════════════════════════════

-- 1. Columna generada: mismo valor de nro_poliza pero sin nada que no sea
--    letra o dígito, en mayúsculas. Se recalcula sola en cada insert/update,
--    no hace falta mantenerla a mano.
alter table polizas
  add column if not exists nro_poliza_norm text
  generated always as (upper(regexp_replace(coalesce(nro_poliza, ''), '[^0-9A-Za-z]', '', 'g'))) stored;

create index if not exists polizas_nro_poliza_norm_idx
  on polizas (nro_poliza_norm);

-- ═══════════════════════════════════════════════════════════════════════════
-- 2. Diagnóstico (solo lectura): ¿ya existen pólizas duplicadas hoy según
--    este criterio? Si esta consulta devuelve filas, revisalas antes de
--    pensar en agregar una restricción única de verdad — hay que decidir
--    caso por caso cuál de las dos filas es la buena.
-- ═══════════════════════════════════════════════════════════════════════════
select nro_poliza_norm, count(*) as cantidad,
       array_agg(id order by id) as ids,
       array_agg(nro_poliza order by id) as numeros_originales
from polizas
where nro_poliza_norm <> ''
group by nro_poliza_norm
having count(*) > 1
order by cantidad desc;

-- ═══════════════════════════════════════════════════════════════════════════
-- 3. OPCIONAL — no se corre ahora: si el diagnóstico de arriba no devuelve
--    ninguna fila (o después de resolver las que aparezcan), se puede hacer
--    que la base misma rechace duplicados, no solo la app:
--
-- create unique index polizas_nro_poliza_norm_uidx
--   on polizas (nro_poliza_norm) where nro_poliza_norm <> '';
-- ═══════════════════════════════════════════════════════════════════════════
