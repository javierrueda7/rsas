-- ═══════════════════════════════════════════════════════════════════════════
-- Aprendizaje de qué ROL corresponde al cliente real según la aseguradora:
-- en unas pólizas el cliente de la correduría figura como Tomador, en
-- otras como Asegurado o Beneficiario, según cómo arma el documento cada
-- aseguradora. Cada vez que se confirma (al guardar) que el rol que se
-- usó automáticamente era el correcto, se refuerza acá — con eso, para
-- clientes NUEVOS que todavía no están en la base (donde no hay documento
-- para comparar), el sistema puede priorizar el rol que históricamente
-- resultó ser el correcto para esa aseguradora en vez de asumir siempre
-- "Tomador".
-- Ejecutar en el SQL Editor de Supabase. Seguro de volver a correr.
-- ═══════════════════════════════════════════════════════════════════════════

create table if not exists ia_aprendizaje_rol_cliente (
  id bigint generated always as identity primary key,
  aseguradora_id bigint not null references aseguradoras(id),
  rol text not null check (rol in ('tomador', 'asegurado', 'beneficiario')),
  veces int not null default 1,
  fultmod timestamptz not null default now(),
  constraint ia_aprendizaje_rol_cliente_unico unique (aseguradora_id, rol)
);

alter table ia_aprendizaje_rol_cliente enable row level security;

drop policy if exists ia_aprendizaje_rol_cliente_all on ia_aprendizaje_rol_cliente;
create policy ia_aprendizaje_rol_cliente_all on ia_aprendizaje_rol_cliente
  for all to authenticated using (true) with check (true);
