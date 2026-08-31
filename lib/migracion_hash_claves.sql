-- ═══════════════════════════════════════════════════════════════════════════
-- Migración: hashear contraseñas de usuarios (usuarios.clave_usuario)
-- Ejecutar completo, en orden, en el SQL Editor de Supabase.
-- Es seguro volver a correrlo (todos los pasos son idempotentes).
-- ═══════════════════════════════════════════════════════════════════════════

-- 1. Extensión necesaria para crypt()/gen_salt() (bcrypt).
create extension if not exists pgcrypto;

-- 2. Función + trigger: cualquier INSERT/UPDATE que deje clave_usuario en
--    texto plano lo hashea automáticamente antes de guardar. Si ya viene
--    hasheada (por ejemplo, el formulario de Usuario reenvía la clave sin
--    cambios al editar), la deja intacta — así ningún camino de escritura
--    puede guardar texto plano, sin tener que tocar cada lugar del código
--    que hace insert/update de usuarios.
create or replace function hash_clave_usuario()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if new.clave_usuario is not null
     and new.clave_usuario !~ '^\$2[aby]\$'
  then
    new.clave_usuario := crypt(new.clave_usuario, gen_salt('bf'));
  end if;
  return new;
end;
$$;

drop trigger if exists trg_hash_clave_usuario on usuarios;
create trigger trg_hash_clave_usuario
  before insert or update on usuarios
  for each row
  execute function hash_clave_usuario();

-- 3. Backfill: hashea las contraseñas que hoy están en texto plano.
--    El trigger de arriba ya protege esta misma UPDATE (no rehashea lo que
--    ya sea un hash bcrypt), así que corre sin importar el orden.
update usuarios
set clave_usuario = crypt(clave_usuario, gen_salt('bf'))
where clave_usuario is not null
  and clave_usuario !~ '^\$2[aby]\$';

-- 4. Función de login: verifica apodo+clave contra el hash en el servidor
--    y devuelve el usuario SIN la columna clave_usuario (nunca sale de la
--    base). SECURITY DEFINER porque el cliente (anon key) no debería poder
--    leer clave_usuario directo.
create or replace function autenticar_usuario(p_apodo text, p_clave text)
returns table (
  id bigint,
  apodo_usuario text,
  nombre_usuario text,
  rol text,
  asesor_id bigint,
  correo_usuario text,
  estado_usuario boolean
)
language sql
security definer
set search_path = public, extensions
as $$
  select u.id, u.apodo_usuario, u.nombre_usuario, u.rol, u.asesor_id,
         u.correo_usuario, u.estado_usuario
  from usuarios u
  where u.apodo_usuario = p_apodo
    and u.estado_usuario = true
    and u.clave_usuario = crypt(p_clave, u.clave_usuario)
  limit 1;
$$;

revoke all on function autenticar_usuario(text, text) from public;
grant execute on function autenticar_usuario(text, text) to anon, authenticated;

-- ═══════════════════════════════════════════════════════════════════════════
-- Después de correr esto:
--  - El login (pagina_login.dart) ya usa esta función — el cambio de código
--    Flutter correspondiente ya está hecho (RepositorioCatalogos.autenticar).
--  - Crear/editar usuario y "Olvidé mi clave" (cambiarClave) siguen siendo
--    un UPDATE/INSERT normal — el trigger los hashea solo, sin cambios de
--    código adicionales.
--  - NO se tocó el flujo de recuperación (verifica apodo + correo, sin
--    token/OTP) — sigue siendo débil contra alguien que conozca ambos
--    datos de un compañero. Es un cambio más grande (requiere envío de
--    correo) que no entró en este alcance.
-- ═══════════════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════════════
-- Diagnóstico: correr estas dos consultas por separado para revisar el
-- estado de todos los usuarios después de la migración.
-- ═══════════════════════════════════════════════════════════════════════════

-- 1. Estado de cada usuario: ¿su clave ya es un hash bcrypt? (debería decir
--    "hasheada" en todas las filas; si alguna dice "TEXTO PLANO" es porque
--    se guardó después de la migración con el trigger viejo, sin
--    search_path — hay que corregirlo a mano o re-guardando esa clave ahora
--    que el trigger ya está arreglado).
select
  apodo_usuario,
  estado_usuario,
  case
    when clave_usuario ~ '^\$2[aby]\$' then 'hasheada'
    when clave_usuario is null then 'sin clave'
    else 'TEXTO PLANO'
  end as estado_clave
from usuarios
order by apodo_usuario;

-- 2. Probar un login puntual sin pasar por la app (reemplazá apodo/clave).
--    ilike para no fallar por mayúsculas/minúsculas al diagnosticar.
select apodo_usuario, estado_usuario,
       clave_usuario = crypt('JCRS01', clave_usuario) as clave_coincide
from usuarios
where apodo_usuario ilike 'javier';
-- ═══════════════════════════════════════════════════════════════════════════
