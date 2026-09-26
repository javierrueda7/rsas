-- ═══════════════════════════════════════════════════════════════════════════
-- Números de póliza: los espacios entre números o letras pasan a guion.
--   "96-95-1000000164 0"  → "96-95-1000000164-0"
--   "AA 19447 055167"     → "AA-19447-055167"
--   "400 -40-994000013811 10" → "400-40-994000013811-10" (espacio + guion = un guion)
--   "96--44-101150203 0"  → "96-44-101150203-0"  (guion doble = uno)
--
-- Solo cambia cómo se ve el número: nro_poliza_norm (letras y dígitos, con
-- lo que se buscan y comparan las pólizas) queda igual. No cambia estados,
-- prima pagada ni la fecha de última modificación.
--
-- La app, desde esta versión, guarda los números nuevos con la misma regla.
-- Correr primero en PRUEBAS y luego en PRODUCCIÓN, por PASOS, en orden.
-- ═══════════════════════════════════════════════════════════════════════════


-- ── PASO 0 (solo lectura): cuántas cambian, ejemplos y choques ──────────────
-- choques debe dar 0 (un número nuevo que ya exista igualito en otra póliza
-- de la misma aseguradora).
with cambio as (
  select id, aseg_id, nro_poliza as antes,
         regexp_replace(btrim(nro_poliza), '[[:space:]-]+', '-', 'g') as despues
    from polizas
   where nro_poliza ~ '[[:space:]]|--'
)
select (select count(*) from cambio)                                        as polizas_a_cambiar,
       (select count(*) from cambio c join polizas p
          on p.id <> c.id and p.aseg_id is not distinct from c.aseg_id
         and p.nro_poliza = c.despues)                                       as choques,
       (select string_agg(antes || '  →  ' || despues, E'\n' order by id)
          from (select * from cambio order by id limit 15) x)               as ejemplos;


-- ── PASO 1: cambio ──────────────────────────────────────────────────────────
do $$
declare
  n bigint;
begin
  alter table polizas disable trigger trg_fultmod;
  perform set_config('app.solo_monto', '1', true);

  update polizas
     set nro_poliza = regexp_replace(btrim(nro_poliza), '[[:space:]-]+', '-', 'g')
   where nro_poliza ~ '[[:space:]]|--';
  get diagnostics n = row_count;

  perform set_config('app.solo_monto', '', true);
  alter table polizas enable trigger trg_fultmod;

  raise notice 'Pólizas cambiadas: %', n;
end $$;


-- ── PASO 2 (solo lectura): verificación — debe dar 0 ────────────────────────
select count(*) as quedan_con_espacios
  from polizas
 where nro_poliza ~ '[[:space:]]|--';
