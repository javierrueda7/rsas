-- ═══════════════════════════════════════════════════════════════════════════
-- Migración septiembre 2026: seguridad por rol + cálculo de pagos en la base
--
-- Correr COMPLETO en el SQL Editor de Supabase, primero en PRUEBAS y, ya
-- validado, en PRODUCCIÓN. Es idempotente (se puede volver a correr).
--
-- ORDEN EN PRODUCCIÓN (importante):
--   1. Desplegar la Edge Function `login` nueva (ya sabe usar la función de
--      esta migración y, si todavía no existe, cae a la vieja).
--   2. Correr este SQL.
--   3. Publicar la app (push a main).
-- Si se corre el SQL antes de desplegar `login`, NADIE puede iniciar sesión
-- (el login viejo usa la anon key, que acá pierde el permiso).
--
-- Qué hace:
--   A. Permisos por rol DENTRO de la base (antes solo se validaban en
--      pantalla): usuarios/asesores/formas de pago/expedición/intermediarios
--      solo los escribe un Administrador; reportes de comisiones y abonos
--      solo roles distintos a Digitador. Un usuario desactivado pierde el
--      acceso de inmediato, aunque tenga un token vigente.
--   B. Nadie (ni siquiera un usuario con sesión) puede leer los hashes de
--      las contraseñas.
--   C. Se apaga "Olvidé mi clave" (permitía cambiar la clave de cualquiera
--      sabiendo apodo + correo). Mientras no exista un flujo con código por
--      correo, la clave la reasigna un Administrador desde Usuarios.
--   D. Login con bloqueo: 5 intentos fallidos seguidos → 15 minutos
--      bloqueado. La verificación ya no se puede llamar directo con la anon
--      key. Hash bcrypt más fuerte (costo 11, se actualiza solo al entrar).
--   E. Plata: lo pagado de cada póliza y su paso a/desde COMPLETA lo calcula
--      la base en la misma transacción del abono (antes eran 4-5 llamadas
--      sueltas desde la app, sin transacción). Nunca pisa un estado puesto
--      a mano. Los totales de cada reporte se calculan en la vista (ya no
--      pueden quedar desfasados). Los abonos ANULADOS no suman.
--   F. fultmod lo pone la base (antes quedaba 5 horas corrido).
--   G. Aprendizaje IA atómico: una sola corrección ya no se vuelve regla.
--   H. Vista de pólizas con el nombre del estado + índices para el dashboard.
--   I. Clientes duplicados por documento normalizado y fusión que conserva
--      los datos de contacto.
-- ═══════════════════════════════════════════════════════════════════════════


-- ═══ A. Rol del usuario que hace la consulta ═══════════════════════════════

-- Id del usuario (claim "sub" del token que firma la función login).
create or replace function app_usuario_id()
returns bigint
language sql
stable
as $$
  select case when (auth.jwt() ->> 'sub') ~ '^[0-9]+$'
              then (auth.jwt() ->> 'sub')::bigint end;
$$;

-- Rol ACTUAL del usuario, leído de la tabla (no del token): si lo
-- desactivan o le cambian el rol, aplica de inmediato. Null = sin acceso.
create or replace function app_rol()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select u.rol from usuarios u
  where u.id = app_usuario_id() and u.estado_usuario = true;
$$;

revoke all on function app_usuario_id() from public;
revoke all on function app_rol() from public;
grant execute on function app_usuario_id() to authenticated;
grant execute on function app_rol() to authenticated;

-- Política base para TODAS las tablas: cualquier usuario activo lee y
-- escribe (lo mismo de antes, pero ahora un usuario desactivado queda
-- afuera). "(select ...)" hace que se evalúe una sola vez por consulta.
do $$
declare
  t record;
begin
  for t in select tablename from pg_tables where schemaname = 'public'
  loop
    execute format('alter table public.%I enable row level security;', t.tablename);
    execute format('drop policy if exists app_authenticated_full_access on public.%I;', t.tablename);
    execute format('drop policy if exists app_lectura on public.%I;', t.tablename);
    execute format('drop policy if exists app_escritura on public.%I;', t.tablename);
    execute format(
      'create policy app_authenticated_full_access on public.%I for all to authenticated '
      'using ((select app_rol()) is not null) with check ((select app_rol()) is not null);',
      t.tablename
    );
  end loop;
end $$;

-- Tablas que en la app solo administra el rol A: todos leen, solo A escribe.
do $$
declare
  t text;
begin
  foreach t in array array['usuarios', 'asesores', 'formas_pago', 'formaexp',
                           'intermediarios', 'estados_poliza', 'municipio']
  loop
    if to_regclass('public.' || t) is null then continue; end if;
    execute format('drop policy if exists app_authenticated_full_access on public.%I;', t);
    execute format(
      'create policy app_lectura on public.%I for select to authenticated '
      'using ((select app_rol()) is not null);', t);
    execute format(
      'create policy app_escritura on public.%I for all to authenticated '
      'using ((select app_rol()) = ''A'') with check ((select app_rol()) = ''A'');', t);
  end loop;
end $$;

-- Reportes de comisiones: la pantalla solo la ve quien no es Digitador (D).
do $$
declare
  t text;
begin
  foreach t in array array['reportes_pago', 'abonos_poliza', 'ia_aprendizaje_intermediario_reporte']
  loop
    if to_regclass('public.' || t) is null then continue; end if;
    execute format('drop policy if exists app_authenticated_full_access on public.%I;', t);
    execute format(
      'create policy app_lectura on public.%I for select to authenticated '
      'using ((select app_rol()) is not null);', t);
    execute format(
      'create policy app_escritura on public.%I for all to authenticated '
      'using ((select app_rol()) in (''A'', ''S'')) with check ((select app_rol()) in (''A'', ''S''));', t);
  end loop;
end $$;


-- ═══ B. Hashes de contraseña: nadie los puede leer ═════════════════════════
-- Se quita el SELECT de tabla y se da SELECT columna por columna, todas
-- menos clave_usuario. OJO: si más adelante se agrega una columna a
-- usuarios, hay que volver a correr este bloque para que se pueda leer.

revoke select on public.usuarios from anon, authenticated;
do $$
declare
  cols text;
begin
  select string_agg(quote_ident(column_name), ', ')
    into cols
    from information_schema.columns
   where table_schema = 'public' and table_name = 'usuarios'
     and column_name <> 'clave_usuario';
  execute format('grant select (%s) on public.usuarios to authenticated;', cols);
end $$;

-- Hash más fuerte para las claves nuevas (antes costo 6, el mínimo).
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
    new.clave_usuario := crypt(new.clave_usuario, gen_salt('bf', 11));
  end if;
  return new;
end;
$$;


-- ═══ C. "Olvidé mi clave" apagado ══════════════════════════════════════════
-- Las funciones quedan (por si se quiere volver atrás), pero ya nadie las
-- puede llamar. Sin un código enviado al correo, cualquiera que supiera el
-- apodo y el correo de otra persona podía cambiarle la clave.

do $$
begin
  if to_regprocedure('public.verificar_apodo_recuperacion(text)') is not null then
    revoke execute on function verificar_apodo_recuperacion(text) from public, anon, authenticated;
  end if;
  if to_regprocedure('public.verificar_recuperacion_usuario(text, text)') is not null then
    revoke execute on function verificar_recuperacion_usuario(text, text) from public, anon, authenticated;
  end if;
  if to_regprocedure('public.cambiar_clave_usuario(text, text, text)') is not null then
    revoke execute on function cambiar_clave_usuario(text, text, text) from public, anon, authenticated;
  end if;
end $$;


-- ═══ D. Login con bloqueo por intentos fallidos ════════════════════════════

create table if not exists login_intentos (
  id bigint generated always as identity primary key,
  apodo text not null,
  exitoso boolean not null,
  fecha timestamptz not null default now()
);
create index if not exists login_intentos_apodo_fecha_idx
  on login_intentos (lower(apodo), fecha desc);
-- RLS sin políticas: solo la función de abajo (security definer) la toca.
alter table login_intentos enable row level security;
drop policy if exists app_authenticated_full_access on login_intentos;

-- Solo la puede llamar la Edge Function `login` con la service role key
-- (nunca sale del servidor). Devuelve {ok, usuario} | {ok:false} | {bloqueado}.
create or replace function autenticar_usuario_v2(p_apodo text, p_clave text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_fallos int;
  v_u usuarios%rowtype;
  v_ok boolean;
begin
  select count(*) into v_fallos
    from login_intentos
   where lower(apodo) = lower(p_apodo)
     and not exitoso
     and fecha > now() - interval '15 minutes';
  if v_fallos >= 5 then
    return jsonb_build_object('ok', false, 'bloqueado', true);
  end if;

  select * into v_u
    from usuarios u
   where u.apodo_usuario = p_apodo
     and u.estado_usuario = true
     and u.clave_usuario = crypt(p_clave, u.clave_usuario)
   limit 1;
  v_ok := found;

  insert into login_intentos (apodo, exitoso) values (p_apodo, v_ok);
  -- La tabla no crece sin fin: se descartan los intentos de más de 30 días.
  delete from login_intentos where fecha < now() - interval '30 days';
  if not v_ok then
    return jsonb_build_object('ok', false);
  end if;

  -- Un login exitoso limpia los fallos previos de ese apodo.
  delete from login_intentos where lower(apodo) = lower(p_apodo) and not exitoso;

  -- Claves con hash viejo (costo < 11): se rehashean ahora que se conoce la clave.
  if v_u.clave_usuario !~ '^\$2[aby]\$(1[1-9]|[2-3][0-9])\$' then
    update usuarios set clave_usuario = crypt(p_clave, gen_salt('bf', 11)) where id = v_u.id;
  end if;

  return jsonb_build_object(
    'ok', true,
    'usuario', jsonb_build_object(
      'id', v_u.id,
      'apodo_usuario', v_u.apodo_usuario,
      'nombre_usuario', v_u.nombre_usuario,
      'rol', v_u.rol,
      'asesor_id', v_u.asesor_id,
      'correo_usuario', v_u.correo_usuario,
      'estado_usuario', v_u.estado_usuario
    )
  );
end;
$$;

revoke all on function autenticar_usuario_v2(text, text) from public, anon, authenticated;
grant execute on function autenticar_usuario_v2(text, text) to service_role;

-- La vieja ya no se puede llamar desde afuera (se saltaba el bloqueo).
do $$
begin
  if to_regprocedure('public.autenticar_usuario(text, text)') is not null then
    revoke execute on function autenticar_usuario(text, text) from public, anon, authenticated;
    grant execute on function autenticar_usuario(text, text) to service_role;
  end if;
end $$;

-- Fusión de clientes: solo usuarios con sesión (antes quedaba abierta a public).
do $$
begin
  if to_regprocedure('public.fusionar_clientes(bigint, bigint[])') is not null then
    revoke execute on function fusionar_clientes(bigint, bigint[]) from public, anon;
    grant execute on function fusionar_clientes(bigint, bigint[]) to authenticated;
    alter function fusionar_clientes(bigint, bigint[]) set search_path = public;
  end if;
end $$;


-- ═══ E. Plata: lo pagado y el estado de cada póliza, calculado en la base ══

-- true = el estado COMPLETA lo puso el sistema por pagos (se puede revertir
-- solo si luego se borra/reversa un abono). Un estado puesto a mano nunca
-- se toca.
alter table polizas add column if not exists estado_por_pagos boolean not null default false;

-- Corre antes de cada insert/update de una póliza. Solo actúa sobre pólizas
-- que tienen abonos (o cuando lo dispara un cambio en abonos): las pólizas
-- históricas sin abonos conservan su "prima pagada" digitada a mano.
create or replace function polizas_pago_estado()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_recalculo boolean := coalesce(current_setting('app.recalculo_pago', true), '') = '1';
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

drop trigger if exists trg_polizas_pago_estado on polizas;
create trigger trg_polizas_pago_estado
  before insert or update on polizas
  for each row
  execute function polizas_pago_estado();

-- Recalcula una póliza puntual (lo llama el trigger de abonos).
create or replace function recalcular_pago_poliza(p_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_id is null then return; end if;
  perform set_config('app.recalculo_pago', '1', true);
  update polizas set vlrprimapagada_poliza = vlrprimapagada_poliza where id = p_id;
  perform set_config('app.recalculo_pago', '', true);
end;
$$;

create or replace function abonos_recalcular_poliza()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op in ('UPDATE', 'DELETE') then
    perform recalcular_pago_poliza(old.id_poliza);
  end if;
  if tg_op in ('INSERT', 'UPDATE')
     and (tg_op = 'INSERT' or new.id_poliza is distinct from old.id_poliza
          or new.vlrabono_prima is distinct from old.vlrabono_prima
          or new.estado_pago is distinct from old.estado_pago) then
    perform recalcular_pago_poliza(new.id_poliza);
  end if;
  return null;
end;
$$;

drop trigger if exists trg_abonos_recalcular_poliza on abonos_poliza;
create trigger trg_abonos_recalcular_poliza
  after insert or update or delete on abonos_poliza
  for each row
  execute function abonos_recalcular_poliza();

revoke all on function recalcular_pago_poliza(bigint) from public, anon;
grant execute on function recalcular_pago_poliza(bigint) to authenticated;

-- Totales del reporte calculados desde sus abonos (antes eran columnas que
-- la app actualizaba a mano y podían quedar en $0 o desfasadas). Mismas
-- columnas y en el mismo orden que la vista anterior.
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
  count(ab.id)::integer as num_abonos
from public.reportes_pago rp
left join public.aseguradoras   aseg on rp.aseg_id  = aseg.id
left join public.intermediarios i    on rp.interm_id = i.id
left join public.abonos_poliza  ab   on ab.idrep_pago = rp.id
group by rp.id, aseg.nombre_aseg, i.nombre_interm;

alter view public.vw_reportes_resumen set (security_invoker = true);

-- Pone al día lo pagado de las pólizas que ya tienen abonos (misma regla de
-- siempre: suma de abonos; y las que ya cubren la prima y siguen en I pasan
-- a COMPLETA). Las pólizas sin abonos no se tocan.
do $$
declare
  v_id bigint;
begin
  for v_id in select distinct id_poliza from abonos_poliza loop
    perform recalcular_pago_poliza(v_id);
  end loop;
end $$;


-- ═══ F. fultmod lo pone la base ════════════════════════════════════════════
-- La app mandaba la hora local sin zona y quedaba guardada 5 horas corrida.

create or replace function set_fultmod()
returns trigger
language plpgsql
as $$
begin
  new.fultmod := now();
  return new;
end;
$$;

do $$
declare
  t record;
begin
  for t in
    select c.table_name
      from information_schema.columns c
      join pg_tables pt on pt.schemaname = 'public' and pt.tablename = c.table_name
     where c.table_schema = 'public' and c.column_name = 'fultmod'
  loop
    execute format('drop trigger if exists trg_fultmod on public.%I;', t.table_name);
    execute format(
      'create trigger trg_fultmod before update on public.%I for each row execute function set_fultmod();',
      t.table_name);
  end loop;
end $$;


-- ═══ G. Aprendizaje IA atómico ═════════════════════════════════════════════
-- Misma corrección otra vez → veces + 1. Corrección distinta → reemplaza y
-- vuelve a 1 (antes sumaba igual, y una corrección de B sobre un A ya
-- aprendido quedaba aplicándose sola de inmediato).

create or replace function registrar_aprendizaje_producto(p_aseg bigint, p_texto text, p_producto bigint)
returns void
language sql
as $$
  insert into ia_aprendizaje_producto as t (aseguradora_id, texto_extraido, producto_id)
  values (p_aseg, p_texto, p_producto)
  on conflict (aseguradora_id, texto_extraido) do update set
    veces = case when t.producto_id = excluded.producto_id then t.veces + 1 else 1 end,
    producto_id = excluded.producto_id,
    fultmod = now();
$$;

create or replace function registrar_aprendizaje_intermediario(p_aseg bigint, p_texto text, p_interm bigint)
returns void
language sql
as $$
  insert into ia_aprendizaje_intermediario_reporte as t (aseguradora_id, texto_extraido, intermediario_id)
  values (p_aseg, p_texto, p_interm)
  on conflict (aseguradora_id, texto_extraido) do update set
    veces = case when t.intermediario_id = excluded.intermediario_id then t.veces + 1 else 1 end,
    intermediario_id = excluded.intermediario_id,
    fultmod = now();
$$;

create or replace function reforzar_aprendizaje_rol_cliente(p_aseg bigint, p_rol text)
returns void
language sql
as $$
  insert into ia_aprendizaje_rol_cliente as t (aseguradora_id, rol)
  values (p_aseg, p_rol)
  on conflict (aseguradora_id, rol) do update set
    veces = t.veces + 1,
    fultmod = now();
$$;

revoke all on function registrar_aprendizaje_producto(bigint, text, bigint) from public, anon;
revoke all on function registrar_aprendizaje_intermediario(bigint, text, bigint) from public, anon;
revoke all on function reforzar_aprendizaje_rol_cliente(bigint, text) from public, anon;
grant execute on function registrar_aprendizaje_producto(bigint, text, bigint) to authenticated;
grant execute on function registrar_aprendizaje_intermediario(bigint, text, bigint) to authenticated;
grant execute on function reforzar_aprendizaje_rol_cliente(bigint, text) to authenticated;


-- ═══ H. Vista de pólizas + índices del dashboard ═══════════════════════════
-- Igual a la definición anterior (fix_vista_polizas_tipodoc.sql) con dos
-- columnas nuevas AL FINAL: el nombre del estado (para que el dashboard no
-- cuente anuladas como vigentes) y la marca de estado por pagos.

-- Si la vista en esta base cambió desde fix_vista_polizas_tipodoc.sql, este
-- bloque solo avisa (NOTICE) y el resto de la migración sigue: la app
-- funciona igual sin estas dos columnas.
do $bloque_vista$
begin
execute $vista$
create or replace view vw_polizas_busqueda as
SELECT p.id,
    p.nro_poliza,
    p.cliente_id,
    p.asesor_id,
    p.ramo_id,
    p.producto_id,
    p.fexp_poliza,
    p.fini_poliza,
    p.ffin_poliza,
    p.prima_poliza,
    p.valor_poliza,
    p.bien_asegurado,
    p.obs_poliza,
    p.fcreado,
    p.fultmod,
    p.vlraseg_poliza,
    p.porccom_poliza,
    p.vlrbasecom_poliza,
    p.intermediario_id,
    p.porcom_agencia,
    p.vlrcom_poliza,
    p.vlrcomfija_poliza,
    p.porcomadic_poliza,
    p.vlrcomadic_poliza,
    p.porcom_asesor1,
    p.agencia_id,
    p.forma_pago_id,
    p.estado_poliza_id,
    p.vlrprimapagada_poliza,
    p.asesor2_id,
    p.porcom_asesor2,
    p.asesor3_id,
    p.porcom_asesor3,
    p.asesorad_id,
    p.porcom_asesorad,
    p.agenciaad_id,
    p.porcom_agenciaad,
    p.fechareg,
    p.horareg,
    p.norecordar,
    p.formaexp_id,
    p.aseg_id,
    p.usuario_id,
    c.nombre_cliente,
    c.doc_cliente,
    a.nombre_asesor,
    r.nombre_ramo,
    pr.nombre_prod,
    ase.nombre_aseg,
    i.nombre_interm,
    fp.nombre_forma_pago,
    fe.nombre_formaexp,
    u.nombre_usuario,
    u.apodo_usuario,
    c.tel_cliente,
    c.tipodoc_cliente,
    ep.nombre_estado,
    p.estado_por_pagos
   FROM polizas p
     LEFT JOIN clientes c ON c.id = p.cliente_id
     LEFT JOIN asesores a ON a.id = p.asesor_id
     LEFT JOIN ramos r ON r.id = p.ramo_id
     LEFT JOIN productos pr ON pr.id = p.producto_id
     LEFT JOIN aseguradoras ase ON ase.id = p.aseg_id
     LEFT JOIN intermediarios i ON i.id = p.intermediario_id
     LEFT JOIN formas_pago fp ON fp.id = p.forma_pago_id
     LEFT JOIN formaexp fe ON fe.id = p.formaexp_id
     LEFT JOIN usuarios u ON u.id = p.usuario_id
     LEFT JOIN estados_poliza ep ON ep.id = p.estado_poliza_id
$vista$;
exception when others then
  raise notice 'vw_polizas_busqueda no se actualizó (%). La app funciona igual.', sqlerrm;
end
$bloque_vista$;

alter view public.vw_polizas_busqueda set (security_invoker = true);

create index if not exists idx_polizas_ffin_poliza on polizas (ffin_poliza);
create index if not exists idx_polizas_fcreado on polizas (fcreado desc);


-- ═══ I. Clientes duplicados por documento normalizado ══════════════════════
-- Antes se comparaba el documento tal cual: "900227885-1" y "9002278851"
-- (el mismo NIT) no aparecían como duplicados.

create or replace view vw_clientes_duplicados as
select c.*
from clientes c
where coalesce(c.doc_cliente_norm, '') <> ''
  and coalesce(c.tipodoc_cliente, '') <> ''
  and (c.tipodoc_cliente, c.doc_cliente_norm) in (
    select tipodoc_cliente, doc_cliente_norm
    from clientes
    where coalesce(doc_cliente_norm, '') <> ''
      and coalesce(tipodoc_cliente, '') <> ''
    group by tipodoc_cliente, doc_cliente_norm
    having count(*) > 1
  );

alter view public.vw_clientes_duplicados set (security_invoker = true);

-- Fusión: además de mover las pólizas, verifica que todos sean el mismo
-- documento y completa en el cliente que se conserva los datos que le
-- falten (teléfono, correo, dirección, etc.) antes de borrar los demás.
create or replace function fusionar_clientes(p_id_bueno bigint, p_ids_malos bigint[])
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_doc text;
  v_distintos int;
begin
  if p_id_bueno = any(p_ids_malos) then
    raise exception 'El cliente a conservar no puede estar en la lista de sobrantes.';
  end if;

  select doc_cliente_norm into v_doc from clientes where id = p_id_bueno;
  select count(*) into v_distintos
    from clientes
   where id = any(p_ids_malos)
     and coalesce(doc_cliente_norm, '') <> coalesce(v_doc, '');
  if v_distintos > 0 then
    raise exception 'Solo se pueden fusionar clientes con el mismo documento.';
  end if;

  update clientes b set
    tel_cliente       = coalesce(nullif(b.tel_cliente, ''),       m.tel_cliente),
    correo_cliente    = coalesce(nullif(b.correo_cliente, ''),    m.correo_cliente),
    dir_cliente       = coalesce(nullif(b.dir_cliente, ''),       m.dir_cliente),
    munic_id          = coalesce(b.munic_id,                      m.munic_id),
    contacto_cliente  = coalesce(nullif(b.contacto_cliente, ''),  m.contacto_cliente),
    cargocont_cliente = coalesce(nullif(b.cargocont_cliente, ''), m.cargocont_cliente),
    asesor_id         = coalesce(b.asesor_id,                     m.asesor_id),
    notas_cliente     = coalesce(nullif(b.notas_cliente, ''),     m.notas_cliente)
  from (
    select
      (array_agg(tel_cliente)       filter (where coalesce(tel_cliente, '') <> ''))[1]       as tel_cliente,
      (array_agg(correo_cliente)    filter (where coalesce(correo_cliente, '') <> ''))[1]    as correo_cliente,
      (array_agg(dir_cliente)       filter (where coalesce(dir_cliente, '') <> ''))[1]       as dir_cliente,
      (array_agg(munic_id)          filter (where munic_id is not null))[1]                  as munic_id,
      (array_agg(contacto_cliente)  filter (where coalesce(contacto_cliente, '') <> ''))[1]  as contacto_cliente,
      (array_agg(cargocont_cliente) filter (where coalesce(cargocont_cliente, '') <> ''))[1] as cargocont_cliente,
      (array_agg(asesor_id)         filter (where asesor_id is not null))[1]                 as asesor_id,
      (array_agg(notas_cliente)     filter (where coalesce(notas_cliente, '') <> ''))[1]     as notas_cliente
    from clientes
    where id = any(p_ids_malos)
  ) m
  where b.id = p_id_bueno;

  update polizas set cliente_id = p_id_bueno where cliente_id = any(p_ids_malos);
  delete from clientes where id = any(p_ids_malos);
end;
$$;

revoke execute on function fusionar_clientes(bigint, bigint[]) from public, anon;
grant execute on function fusionar_clientes(bigint, bigint[]) to authenticated;


-- ═══ Verificación (debe devolver filas coherentes) ═════════════════════════

-- 1. Políticas por tabla (usuarios/asesores/... con app_lectura + app_escritura).
select tablename, policyname, cmd
  from pg_policies
 where schemaname = 'public'
 order by tablename, policyname;

-- 2. Totales de los últimos reportes, ya calculados por la vista.
select id, fecha_rep, nombre_aseg, num_abonos, vlrsumprima_rep, vlrsumcom_rep
  from vw_reportes_resumen
 order by id desc
 limit 5;
