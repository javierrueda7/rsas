-- ═══════════════════════════════════════════════════════════════════════════
-- Prima pagada "de antes": protege el valor histórico de cada póliza.
--
-- Problema: en producción 17.382 pólizas tienen prima pagada (vino del
-- sistema anterior) pero no tienen abonos. El trigger de la migración de
-- septiembre calcula la prima pagada = suma de abonos, así que el primer
-- abono que se cargue a una de esas pólizas borraría el valor histórico.
--
-- Solución: columna vlrprimapagada_base = lo pagado por fuera de los abonos
-- del sistema (histórico o digitado a mano). Desde ahora:
--     prima pagada = vlrprimapagada_base + suma de abonos (no anulados)
-- Si alguien digita la prima pagada a mano en el formulario, se ajusta la
-- base para que el total quede exactamente en lo digitado.
--
-- Correr primero en PRUEBAS y luego en PRODUCCIÓN, por PASOS, en orden
-- (sombrear cada paso y Run). Ningún total cambia: el PASO 3 debe dar los
-- mismos números que el PASO 0.
-- ═══════════════════════════════════════════════════════════════════════════


-- ── PASO 0 (solo lectura): anotar estos números antes de empezar ───────────
select
  count(*) filter (where coalesce(vlrprimapagada_poliza, 0) <> 0) as polizas_con_pago,
  sum(coalesce(vlrprimapagada_poliza, 0))                          as total_pagado
from polizas;


-- ── PASO 1: columna + trigger nuevo ─────────────────────────────────────────
alter table polizas add column if not exists vlrprimapagada_base numeric not null default 0;

create or replace function polizas_pago_estado()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_recalculo boolean := coalesce(current_setting('app.recalculo_pago', true), '') = '1';
  -- '1' = solo recalcular el monto pagado, sin tocar estados.
  v_solo_monto boolean := coalesce(current_setting('app.solo_monto', true), '') = '1';
  v_tiene_abonos boolean;
  v_abonos numeric;
  v_total numeric;
  v_completa text;
begin
  -- Póliza nueva: todavía no tiene abonos, lo digitado es la base.
  if tg_op = 'INSERT' then
    new.vlrprimapagada_base := coalesce(new.vlrprimapagada_poliza, 0);
    return new;
  end if;

  select exists(select 1 from abonos_poliza where id_poliza = new.id),
         coalesce(sum(vlrabono_prima) filter (where estado_pago <> 'A'), 0)
    into v_tiene_abonos, v_abonos
    from abonos_poliza
   where id_poliza = new.id;

  -- Prima pagada digitada a mano (no viene de un cambio en abonos): la base
  -- se ajusta para que el total quede en lo digitado.
  if not v_recalculo
     and new.vlrprimapagada_poliza is distinct from old.vlrprimapagada_poliza then
    new.vlrprimapagada_base := coalesce(new.vlrprimapagada_poliza, 0) - v_abonos;
  end if;

  v_total := coalesce(new.vlrprimapagada_base, 0) + v_abonos;
  new.vlrprimapagada_poliza := v_total;

  -- Los estados solo se manejan por pagos en pólizas con abonos (las
  -- históricas sin abonos conservan su estado tal cual).
  if v_solo_monto or (not v_tiene_abonos and not v_recalculo) then
    return new;
  end if;

  -- Estado cambiado a mano en esta misma operación: se respeta.
  if not v_recalculo and new.estado_poliza_id is distinct from old.estado_poliza_id then
    new.estado_por_pagos := false;
    return new;
  end if;

  select id into v_completa from estados_poliza where upper(nombre_estado) = 'COMPLETA' limit 1;
  if v_completa is null then
    return new;
  end if;

  if new.prima_poliza > 0 and v_total >= new.prima_poliza then
    -- Solo avanza desde el estado inicial (I) o sin estado.
    if new.estado_poliza_id is null or new.estado_poliza_id = 'I' then
      new.estado_poliza_id := v_completa;
      new.estado_por_pagos := true;
    end if;
  elsif new.estado_por_pagos and new.estado_poliza_id = v_completa then
    -- La había completado el sistema y ya no alcanza: vuelve a I.
    new.estado_poliza_id := 'I';
    new.estado_por_pagos := false;
  end if;

  return new;
end;
$$;


-- ── PASO 2: llenar la base con lo que hoy no está explicado por abonos ──────
-- En producción (sin abonos) la base queda igual a la prima pagada actual.
-- En pruebas, las pólizas cuyos abonos ya suman su prima pagada quedan con
-- base 0. Modo "solo monto": no cambia ningún estado.
do $$
begin
  perform set_config('app.solo_monto', '1', true);

  update polizas p
     set vlrprimapagada_base = coalesce(p.vlrprimapagada_poliza, 0) - coalesce((
           select sum(a.vlrabono_prima)
             from abonos_poliza a
            where a.id_poliza = p.id and a.estado_pago <> 'A'), 0)
   where coalesce(p.vlrprimapagada_poliza, 0) <> 0
      or exists (select 1 from abonos_poliza a where a.id_poliza = p.id);

  perform set_config('app.solo_monto', '', true);
end $$;


-- ── PASO 3 (solo lectura): verificación ─────────────────────────────────────
-- polizas_con_pago y total_pagado deben ser IGUALES a los del PASO 0.
-- descuadradas debe ser 0.
select
  count(*) filter (where coalesce(p.vlrprimapagada_poliza, 0) <> 0) as polizas_con_pago,
  sum(coalesce(p.vlrprimapagada_poliza, 0))                          as total_pagado,
  count(*) filter (where p.vlrprimapagada_base <> 0)                 as polizas_con_base,
  count(*) filter (
    where coalesce(p.vlrprimapagada_poliza, 0) <> p.vlrprimapagada_base + coalesce((
      select sum(a.vlrabono_prima) from abonos_poliza a
       where a.id_poliza = p.id and a.estado_pago <> 'A'), 0)
  ) as descuadradas
from polizas p;
