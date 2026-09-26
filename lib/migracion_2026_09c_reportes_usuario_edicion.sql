-- ═══════════════════════════════════════════════════════════════════════════
-- Reportes de comisiones: quién lo creó y quién lo editó por última vez.
--
-- usuario_id         = quien CREÓ el reporte (ya no cambia al editar).
-- usuario_ultmod_id  = quien lo editó por última vez (columna nueva).
--
-- Los dos los pone la base con el usuario de la sesión (trigger), así
-- funciona igual desde la app actual (Flutter, que al editar manda
-- usuario_id) y desde la nueva. Para los reportes que ya existen, los dos
-- quedan con el mismo valor.
--
-- Correr primero en PRUEBAS y luego en PRODUCCIÓN, por PASOS, en orden.
-- ═══════════════════════════════════════════════════════════════════════════


-- ── PASO 1: columna nueva, con el valor actual para los reportes existentes ─
alter table reportes_pago
  add column if not exists usuario_ultmod_id bigint references usuarios(id);

update reportes_pago
   set usuario_ultmod_id = usuario_id
 where usuario_ultmod_id is null;


-- ── PASO 2: trigger que llena los dos campos ────────────────────────────────
create or replace function reportes_pago_usuarios()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    new.usuario_id := coalesce(app_usuario_id(), new.usuario_id);
    new.usuario_ultmod_id := new.usuario_id;
  else
    -- El creador no cambia aunque la app mande otro usuario_id al editar.
    new.usuario_id := old.usuario_id;
    new.usuario_ultmod_id := coalesce(app_usuario_id(), new.usuario_ultmod_id);
  end if;
  return new;
end;
$$;

drop trigger if exists trg_reportes_pago_usuarios on reportes_pago;
create trigger trg_reportes_pago_usuarios
  before insert or update on reportes_pago
  for each row
  execute function reportes_pago_usuarios();


-- ── PASO 3: la vista de reportes también entrega el nuevo campo ─────────────
-- Misma vista de antes (migracion_2026_09_seguridad_y_pagos.sql) con la
-- columna nueva al final.
create or replace view public.vw_reportes_resumen as
select
  rp.id, rp.fecha_rep, rp.aseg_id, rp.interm_id,
  rp.fini_rep, rp.ffin_rep,
  rp.vlrprima_rep,
  coalesce(sum(ab.vlrabono_prima) filter (where ab.estado_pago <> 'A'), 0)::numeric as vlrsumprima_rep,
  rp.vlrcom_rep,
  coalesce(sum(ab.vlrcomision + ab.vlrcomad) filter (where ab.estado_pago <> 'A'), 0)::numeric as vlrsumcom_rep,
  rp.estado_rep, rp.obs_rep,
  rp.usuario_id, rp.fcreado, rp.fultmod,
  aseg.nombre_aseg,
  i.nombre_interm,
  count(ab.id)::integer as num_abonos,
  rp.usuario_ultmod_id
from public.reportes_pago rp
left join public.aseguradoras   aseg on rp.aseg_id  = aseg.id
left join public.intermediarios i    on rp.interm_id = i.id
left join public.abonos_poliza  ab   on ab.idrep_pago = rp.id
group by rp.id, aseg.nombre_aseg, i.nombre_interm;

alter view public.vw_reportes_resumen set (security_invoker = true);


-- ── PASO 4 (solo lectura): verificación ─────────────────────────────────────
-- sin_editor debe dar 0 (salvo reportes que ya no tenían creador), y
-- distintos da 0 hoy: todos los existentes quedan con el mismo valor.
select
  count(*)                                                        as reportes,
  count(*) filter (where usuario_ultmod_id is null
                     and usuario_id is not null)                  as sin_editor,
  count(*) filter (where usuario_ultmod_id is distinct from usuario_id) as distintos
from reportes_pago;
