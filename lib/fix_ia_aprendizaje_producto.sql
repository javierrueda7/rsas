-- ═══════════════════════════════════════════════════════════════════════════
-- Aprendizaje de correcciones: cuando la IA sugiere un Ramo/Producto al
-- importar una póliza y el digitador lo cambia manualmente antes de
-- guardar, se registra acá qué texto traía el documento y cuál era el
-- producto correcto de verdad. La próxima vez que aparezca un texto igual
-- de esa misma aseguradora, la app usa directamente lo aprendido — sin
-- depender de que la IA "adivine" otra vez.
-- Ejecutar en el SQL Editor de Supabase. Seguro de volver a correr.
-- ═══════════════════════════════════════════════════════════════════════════

create table if not exists ia_aprendizaje_producto (
  id bigint generated always as identity primary key,
  aseguradora_id bigint not null references aseguradoras(id),
  texto_extraido text not null,
  producto_id bigint not null references productos(id),
  veces int not null default 1,
  fcreado timestamptz not null default now(),
  fultmod timestamptz not null default now(),
  constraint ia_aprendizaje_producto_unico unique (aseguradora_id, texto_extraido)
);

alter table ia_aprendizaje_producto enable row level security;

drop policy if exists ia_aprendizaje_producto_all on ia_aprendizaje_producto;
create policy ia_aprendizaje_producto_all on ia_aprendizaje_producto
  for all to authenticated using (true) with check (true);
