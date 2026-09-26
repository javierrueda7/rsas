-- ═══════════════════════════════════════════════════════════════════════════
-- CARGA FINAL: pasa los reportes y abonos históricos de PRUEBAS (ya
-- cargados y validados en el esquema aparte hist_pruebas, ver
-- lib/historico_validar.sql) a las tablas reales de PRODUCCIÓN.
--
-- Decisiones acordadas:
--   * Todas las pólizas conservan su prima pagada actual (la base absorbe la
--     diferencia; en las de redondeo queda un residuo de centavos/pesos).
--   * Excepto 11 pólizas que en producción están en $0 y en pruebas quedaron
--     pagadas por sus abonos: esas quedan con base 0 → pagado = sus abonos.
--   * La 21506 conserva su pagado de producción (el abono de 2020 se pasa
--     para que el reporte 1418 quede completo, pero la base lo compensa).
--   * Los estados de las pólizas no cambian ni su fecha de última modificación.
--
-- PASO 1 es UNA sola transacción: si cualquier verificación falla, lanza un
-- error y no queda NADA cargado. Sombrear cada paso y Run, en orden.
-- ═══════════════════════════════════════════════════════════════════════════


-- ── PASO 1: carga ───────────────────────────────────────────────────────────
do $$
declare
  v_once constant bigint[] := array[1946, 1947, 1950, 1951, 1952, 1955, 1957, 1958, 1959, 1960, 1961];
  n bigint;
begin
  if exists (select 1 from reportes_pago) or exists (select 1 from abonos_poliza) then
    raise exception 'Producción ya tiene reportes o abonos: no se cargó nada.';
  end if;

  select count(*) into n from polizas
   where id = any (v_once) and coalesce(vlrprimapagada_poliza, 0) = 0 and vlrprimapagada_base = 0;
  if n <> 11 then
    raise exception 'Las 11 pólizas en $0 cambiaron desde la validación (% de 11): no se cargó nada.', n;
  end if;

  -- Foto de las pólizas afectadas antes de la carga.
  create temp table _hist_antes on commit drop as
  select p.id, coalesce(p.vlrprimapagada_poliza, 0) as pagado, p.estado_poliza_id, p.fultmod
    from polizas p
   where p.id in (select id_poliza from hist_pruebas.abonos);

  -- Reportes, con sus mismos códigos. Creador = último editor = el de pruebas.
  insert into reportes_pago (id, fecha_rep, aseg_id, interm_id, fini_rep, ffin_rep, vlrprima_rep,
                             vlrcom_rep, estado_rep, obs_rep, usuario_id, usuario_ultmod_id, fcreado, fultmod)
  overriding system value
  select id, fecha_rep, aseg_id, interm_id, fini_rep, ffin_rep, vlrprima_rep,
         vlrcom_rep, estado_rep, obs_rep, usuario_id, usuario_id, fcreado, fultmod
    from hist_pruebas.reportes
   order by id;

  -- Abonos, sin el recálculo por fila (cambiaría estados de pólizas).
  alter table abonos_poliza disable trigger trg_abonos_recalcular_poliza;
  insert into abonos_poliza (id, idrep_pago, id_poliza, fecha_pago, vlrprima_poliza, vlrabono_prima,
                             porccomision, vlrcomision, porccomad, vlrcomad, idfactura, num_factura,
                             estado_pago, obs_pago, usuario_id, fcreado, fultmod)
  overriding system value
  select id, idrep_pago, id_poliza, fecha_pago, vlrprima_poliza, vlrabono_prima,
         porccomision, vlrcomision, porccomad, vlrcomad, idfactura, num_factura,
         estado_pago, obs_pago, usuario_id, fcreado, fultmod
    from hist_pruebas.abonos
   order by id;
  alter table abonos_poliza enable trigger trg_abonos_recalcular_poliza;

  -- Base = lo pagado por fuera de los abonos. Modo "solo monto": el trigger
  -- recalcula la prima pagada (= base + abonos) sin tocar estados.
  alter table polizas disable trigger trg_fultmod;
  perform set_config('app.solo_monto', '1', true);
  update polizas p
     set vlrprimapagada_base = case when p.id = any (v_once) then 0
                                    else p.vlrprimapagada_base - s.suma end
    from (select id_poliza,
                 coalesce(sum(vlrabono_prima) filter (where estado_pago <> 'A'), 0) as suma
            from abonos_poliza group by id_poliza) s
   where s.id_poliza = p.id;
  perform set_config('app.solo_monto', '', true);
  alter table polizas enable trigger trg_fultmod;

  -- Códigos nuevos siguen después del más alto.
  perform setval(pg_get_serial_sequence('reportes_pago', 'id'), (select max(id) from reportes_pago));
  perform setval(pg_get_serial_sequence('abonos_poliza', 'id'), (select max(id) from abonos_poliza));

  -- ── Verificaciones: cualquier falla deshace todo ──
  if (select count(*) from reportes_pago) <> (select count(*) from hist_pruebas.reportes)
     or (select count(*) from abonos_poliza) <> (select count(*) from hist_pruebas.abonos) then
    raise exception 'La cantidad de reportes o abonos no coincide: no se cargó nada.';
  end if;

  select count(*) into n from _hist_antes a join polizas p using (id)
   where not (p.id = any (v_once)) and coalesce(p.vlrprimapagada_poliza, 0) <> a.pagado;
  if n > 0 then
    raise exception '% pólizas cambiaron su prima pagada: no se cargó nada.', n;
  end if;

  select count(*) into n from polizas p
   where p.id = any (v_once)
     and p.vlrprimapagada_poliza <> (select coalesce(sum(vlrabono_prima) filter (where estado_pago <> 'A'), 0)
                                       from abonos_poliza a where a.id_poliza = p.id);
  if n > 0 then
    raise exception '% de las 11 pólizas no quedaron con el pagado de sus abonos: no se cargó nada.', n;
  end if;

  select count(*) into n from _hist_antes a join polizas p using (id)
   where p.estado_poliza_id is distinct from a.estado_poliza_id or p.fultmod is distinct from a.fultmod;
  if n > 0 then
    raise exception '% pólizas cambiaron de estado o de fecha de modificación: no se cargó nada.', n;
  end if;

  select count(*) into n from polizas p
   where p.id in (select id from _hist_antes)
     and coalesce(p.vlrprimapagada_poliza, 0) <> p.vlrprimapagada_base
         + (select coalesce(sum(vlrabono_prima) filter (where estado_pago <> 'A'), 0)
              from abonos_poliza a where a.id_poliza = p.id);
  if n > 0 then
    raise exception '% pólizas quedaron con pagado ≠ base + abonos: no se cargó nada.', n;
  end if;
end $$;


-- ── PASO 2 (solo lectura): resultado ────────────────────────────────────────
-- reportes = 1517, abonos = 20955, y total_pagado = el de antes + 136.304
-- (las 11 pólizas que estaban en $0).
select (select count(*) from reportes_pago)                                 as reportes,
       (select count(*) from abonos_poliza)                                 as abonos,
       (select count(*) from polizas where coalesce(vlrprimapagada_poliza, 0) <> 0) as polizas_con_pago,
       (select sum(coalesce(vlrprimapagada_poliza, 0)) from polizas)        as total_pagado;


-- ── PASO 3: borrar el esquema aparte (SOLO después de revisar en la app) ────
-- drop schema hist_pruebas cascade;
