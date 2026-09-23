-- ═══════════════════════════════════════════════════════════════════════════
-- Tabla de pólizas "en borrador" / "pendientes de revisión" — pólizas que
-- todavía NO tienen un id definitivo en `polizas`. Dos orígenes posibles:
--   - 'borrador': alguien la dejó a medio llenar a mano y la guardó para
--                 seguir después.
--   - 'pendiente_revision': llegó predigitada por IA (carga masiva o,
--                 más adelante, la carpeta de Google Drive) y espera a que
--                 alguien la revise, complete y guarde como póliza real.
-- Cuando se termina de llenar y se guarda como póliza real (tabla polizas,
-- con su id de verdad asignado por la base), esta fila se borra — no es un
-- historial, es una bandeja de trabajo.
-- Ejecutar en el SQL Editor de Supabase. Seguro de volver a correr.
-- ═══════════════════════════════════════════════════════════════════════════

create table if not exists polizas_pendientes (
  id bigint generated always as identity primary key,
  estado text not null default 'borrador'
    check (estado in ('borrador', 'pendiente_revision')),
  -- Snapshot de los campos del formulario (mismas claves que arma
  -- extraer-poliza, más lo que el usuario haya alcanzado a llenar a mano).
  datos jsonb not null default '{}'::jsonb,
  nombre_archivo text,
  origen text not null default 'manual'
    check (origen in ('manual', 'ia_carga_masiva', 'ia_drive')),
  drive_file_id text,
  error_msg text,
  usuario_id bigint references usuarios(id),
  fcreado timestamptz not null default now(),
  fultmod timestamptz not null default now()
);

create index if not exists polizas_pendientes_estado_idx
  on polizas_pendientes (estado);

-- RLS — mismo criterio que el resto de tablas de la app (ver
-- fix_rls_seguridad.sql): cualquier usuario autenticado con el JWT propio
-- puede leer/escribir, la app controla los roles a nivel de UI.
alter table polizas_pendientes enable row level security;

drop policy if exists polizas_pendientes_all on polizas_pendientes;
create policy polizas_pendientes_all on polizas_pendientes
  for all to authenticated using (true) with check (true);
