-- ═══════════════════════════════════════════════════════════════════════════
-- SOLO PARA PRUEBAS (en producción esto ya viene dentro de
-- migracion_2026_09_seguridad_y_pagos.sql, sección E).
--
-- Abonos históricos (migrados del sistema anterior): el valor pagado de cada
-- abono quedó en vlrprima_poliza y vlrabono_prima quedó en 0 en TODOS.
-- Comprobado: el total guardado de los reportes viejos (vlrsumprima_rep)
-- coincide con la suma de vlrprima_poliza de sus abonos. La primera versión
-- de la migración sumó vlrabono_prima y dejó en 0 la prima pagada de las
-- 18.515 pólizas con abonos; esto la repara.
--
-- Correr por PASOS, en orden (sombrear cada paso y Run).
-- ═══════════════════════════════════════════════════════════════════════════


-- ── PASO 1: trigger con modo "solo monto" (igual al de la migración) ───────
create or replace function polizas_pago_estado()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_recalculo boolean := coalesce(current_setting('app.recalculo_pago', true), '') = '1';
  v_solo_monto boolean := coalesce(current_setting('app.solo_monto', true), '') = '1';
  v_tiene_abonos boolean;
  v_total numeric;
  v_completa text;
begin
  if tg_op = 'INSERT' then
    return new;
  end if;

  select exists(select 1 from abonos_poliza where id_poliza = new.id) into v_tiene_abonos;
  if not v_tiene_abonos and not v_recalculo then
    return new;
  end if;

  select coalesce(sum(vlrabono_prima), 0) into v_total
    from abonos_poliza
   where id_poliza = new.id and estado_pago <> 'A';
  new.vlrprimapagada_poliza := v_total;

  if v_solo_monto then
    return new;
  end if;

  if not v_recalculo and new.estado_poliza_id is distinct from old.estado_poliza_id then
    new.estado_por_pagos := false;
    return new;
  end if;

  select id into v_completa from estados_poliza where upper(nombre_estado) = 'COMPLETA' limit 1;
  if v_completa is null then
    return new;
  end if;

  if new.prima_poliza > 0 and v_total >= new.prima_poliza then
    if new.estado_poliza_id is null or new.estado_poliza_id = 'I' then
      new.estado_poliza_id := v_completa;
      new.estado_por_pagos := true;
    end if;
  elsif new.estado_por_pagos and new.estado_poliza_id = v_completa then
    new.estado_poliza_id := 'I';
    new.estado_por_pagos := false;
  end if;

  return new;
end;
$$;


-- ── PASO 2: copiar el valor histórico (solo monto, sin tocar estados) ───────
do $$
begin
  perform set_config('app.solo_monto', '1', true);

  update abonos_poliza
     set vlrabono_prima = vlrprima_poliza
   where vlrabono_prima = 0
     and vlrprima_poliza <> 0;

  perform set_config('app.solo_monto', '', true);
end $$;


-- ── PASO 3 (solo lectura): verificación ─────────────────────────────────────
-- polizas_en_cero debe bajar muchísimo (quedan solo las pólizas cuyos abonos
-- valen 0 en ambas columnas). pasarian_a_completa = cuántas históricas
-- cambiarían de estado si se corre el PASO 4.
select
  count(*) as polizas_con_abonos,
  count(*) filter (where coalesce(p.vlrprimapagada_poliza, 0) = 0) as polizas_en_cero,
  count(*) filter (
    where p.prima_poliza > 0
      and p.vlrprimapagada_poliza >= p.prima_poliza
      and coalesce(p.estado_poliza_id, 'I') = 'I'
  ) as pasarian_a_completa
from polizas p
where exists (select 1 from abonos_poliza a where a.id_poliza = p.id);


-- ── PASO 4 (OPCIONAL, decisión del negocio) ─────────────────────────────────
-- Pasa a COMPLETA las pólizas históricas en INCOMPLETA cuyos abonos ya
-- cubren la prima (la misma regla que se aplica a los abonos nuevos). Solo
-- correr si está de acuerdo con el número "pasarian_a_completa" del PASO 3.
-- do $$
-- declare
--   v_id bigint;
-- begin
--   for v_id in
--     select p.id from polizas p
--      where p.prima_poliza > 0
--        and p.vlrprimapagada_poliza >= p.prima_poliza
--        and coalesce(p.estado_poliza_id, 'I') = 'I'
--        and exists (select 1 from abonos_poliza a where a.id_poliza = p.id)
--   loop
--     perform recalcular_pago_poliza(v_id);
--   end loop;
-- end $$;
