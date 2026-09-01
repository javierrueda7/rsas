-- ═══════════════════════════════════════════════════════════════════════════
-- Fix de seguridad: habilita Row Level Security en TODAS las tablas de
-- public (hoy están abiertas a cualquiera con la anon key, sin pasar por el
-- login de la app) y corrige las 3 vistas SECURITY DEFINER para que respeten
-- esa RLS en vez de saltársela.
--
-- Requiere, del lado de la app, que el login entregue un JWT propio (ver
-- supabase/functions/login/index.ts) — sin eso, después de correr este
-- script la app deja de poder leer/escribir nada (se rompe a propósito,
-- es la prueba de que el hueco se cerró). Coordinar el deploy de la Edge
-- Function ANTES o AL MISMO TIEMPO que este script.
--
-- Ejecutar completo, en orden, en el SQL Editor de Supabase. Es seguro
-- volver a correrlo (todo es idempotente).
-- ═══════════════════════════════════════════════════════════════════════════

-- 1. RLS + política permisiva ("cualquier usuario logueado puede todo",
--    igual que hoy) en cada tabla de public. No dejo ninguna política para
--    el rol anon a propósito: sin JWT válido, cero acceso.
do $$
declare
  t record;
begin
  for t in select tablename from pg_tables where schemaname = 'public'
  loop
    execute format('alter table public.%I enable row level security;', t.tablename);
    execute format('drop policy if exists app_authenticated_full_access on public.%I;', t.tablename);
    execute format(
      'create policy app_authenticated_full_access on public.%I for all to authenticated using (true) with check (true);',
      t.tablename
    );
  end loop;
end $$;

-- 2. Las 3 vistas que usa la app (vw_polizas_busqueda, vw_abonos_detalle,
--    vw_reportes_resumen) están marcadas SECURITY DEFINER, lo que hace que
--    corran con privilegios del dueño e ignoren la RLS de arriba. Las paso
--    a SECURITY INVOKER para que respeten los permisos de quien consulta.
alter view public.vw_polizas_busqueda set (security_invoker = true);
alter view public.vw_abonos_detalle   set (security_invoker = true);
alter view public.vw_reportes_resumen set (security_invoker = true);

-- ═══════════════════════════════════════════════════════════════════════════
-- 3. El flujo de "Olvidé mi clave" (pagina_recuperar_clave.dart) corre ANTES
--    de loguearse, así que necesita funciones SECURITY DEFINER propias
--    (igual que autenticar_usuario) para seguir funcionando sin acceso
--    directo a la tabla usuarios. De paso, cambiar_clave_usuario ahora
--    también revalida apodo+correo (antes el paso 3 confiaba ciegamente en
--    que el paso 2 ya se había cumplido, sin re-chequearlo en el servidor).
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function verificar_apodo_recuperacion(p_apodo text)
returns boolean
language sql
security definer
set search_path = public, extensions
as $$
  select exists(
    select 1 from usuarios
    where apodo_usuario = p_apodo and estado_usuario = true
  );
$$;

create or replace function verificar_recuperacion_usuario(p_apodo text, p_correo text)
returns boolean
language sql
security definer
set search_path = public, extensions
as $$
  select exists(
    select 1 from usuarios
    where apodo_usuario = p_apodo
      and correo_usuario = p_correo
      and estado_usuario = true
  );
$$;

create or replace function cambiar_clave_usuario(p_apodo text, p_correo text, p_nueva_clave text)
returns boolean
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if not exists (
    select 1 from usuarios
    where apodo_usuario = p_apodo
      and correo_usuario = p_correo
      and estado_usuario = true
  ) then
    return false;
  end if;

  update usuarios
  set clave_usuario = p_nueva_clave  -- el trigger trg_hash_clave_usuario la hashea sola
  where apodo_usuario = p_apodo;

  return true;
end;
$$;

revoke all on function verificar_apodo_recuperacion(text) from public;
revoke all on function verificar_recuperacion_usuario(text, text) from public;
revoke all on function cambiar_clave_usuario(text, text, text) from public;
grant execute on function verificar_apodo_recuperacion(text) to anon, authenticated;
grant execute on function verificar_recuperacion_usuario(text, text) to anon, authenticated;
grant execute on function cambiar_clave_usuario(text, text, text) to anon, authenticated;

-- ═══════════════════════════════════════════════════════════════════════════
-- Diagnóstico: confirma que ya no queda ninguna tabla de public sin RLS.
-- Debería devolver 0 filas.
-- ═══════════════════════════════════════════════════════════════════════════
select tablename
from pg_tables
where schemaname = 'public' and not rowsecurity;
