-- ═══════════════════════════════════════════════════════════════════════════
-- Aprendizaje de correcciones: cuando la IA importa un Reporte de Pago y no
-- logra (o logra mal) matchear el Intermediario contra el catálogo —el
-- texto de la cabecera del documento suele traer un código/orden distinto
-- al nombre guardado, ej. "5728 - SERRANO MANTILLA LUZ STELLA" en el
-- documento vs. "LUZ STELLA SERRANO" en la base— se registra acá qué texto
-- traía el documento de esa aseguradora y cuál era el intermediario
-- correcto. La próxima vez que aparezca ese mismo texto de esa misma
-- aseguradora, la app lo usa directo. Mismo patrón que
-- ia_aprendizaje_producto.
-- Ejecutar en el SQL Editor de Supabase. Seguro de volver a correr.
-- ═══════════════════════════════════════════════════════════════════════════

create table if not exists ia_aprendizaje_intermediario_reporte (
  id bigint generated always as identity primary key,
  aseguradora_id bigint not null references aseguradoras(id),
  texto_extraido text not null,
  intermediario_id bigint not null references intermediarios(id),
  veces int not null default 1,
  fcreado timestamptz not null default now(),
  fultmod timestamptz not null default now(),
  constraint ia_aprendizaje_intermediario_reporte_unico unique (aseguradora_id, texto_extraido)
);

alter table ia_aprendizaje_intermediario_reporte enable row level security;

drop policy if exists ia_aprendizaje_intermediario_reporte_all on ia_aprendizaje_intermediario_reporte;
create policy ia_aprendizaje_intermediario_reporte_all on ia_aprendizaje_intermediario_reporte
  for all to authenticated using (true) with check (true);
