-- ═══════════════════════════════════════════════════════════════════════════
-- Optimiza la pantalla "Pólizas con número repetido": hoy trae TODAS las
-- pólizas al cliente (miles de filas) solo para agrupar por nro_poliza_norm
-- y descartar en Dart las que no se repiten. Esta vista hace ese filtro en
-- la base — la app solo trae las filas que en verdad están duplicadas.
-- Ejecutar en el SQL Editor de Supabase. Es seguro volver a correrlo.
-- ═══════════════════════════════════════════════════════════════════════════

-- Filtra por id (no por nro_poliza_norm) porque esa columna vive en la
-- tabla polizas y no sabemos si la vista vw_polizas_busqueda la expone tal
-- cual — así funciona sin depender de eso.
create or replace view vw_polizas_duplicadas as
select v.*
from vw_polizas_busqueda v
where v.id in (
  select p.id
  from polizas p
  where p.nro_poliza_norm in (
    select nro_poliza_norm
    from polizas
    where nro_poliza_norm <> ''
    group by nro_poliza_norm
    having count(*) > 1
  )
);

-- Respeta la RLS de quien consulta (mismo criterio ya aplicado a las otras
-- vistas de la app, ver fix_rls_seguridad.sql) en vez de correr con
-- privilegios del dueño.
alter view public.vw_polizas_duplicadas set (security_invoker = true);
