-- ═══════════════════════════════════════════════════════════════════════════
-- Bug real reportado: al importar un PDF con IA, el cliente no se
-- detectaba aunque SÍ existía en la base — pasaba sobre todo con NIT.
-- Causa: doc_cliente se guarda con el guión del dígito de verificación
-- ("901385053-0"), y el matcheo buscaba por los últimos 3 caracteres del
-- documento extraído del PDF. Cuando esos 3 caracteres caen sobre el
-- guión (casi siempre en un NIT, porque el guión está a 1 dígito del
-- final), la búsqueda no encontraba nada.
--
-- Mismo arreglo que ya se usó para nro_poliza: una columna generada con
-- SOLO dígitos (sin puntos ni guión), para comparar de forma exacta y
-- confiable en vez de buscar por substring de texto.
-- Ejecutar en el SQL Editor de Supabase. Seguro de volver a correr.
-- ═══════════════════════════════════════════════════════════════════════════

-- Mayúsculas + solo dígitos/letras (igual criterio que nro_poliza_norm),
-- para que pasaportes con letras también normalicen bien.
alter table clientes
  add column if not exists doc_cliente_norm text
  generated always as (upper(regexp_replace(coalesce(doc_cliente, ''), '[^0-9A-Za-z]', '', 'g'))) stored;

create index if not exists clientes_doc_cliente_norm_idx
  on clientes (doc_cliente_norm);

-- ═══════════════════════════════════════════════════════════════════════════
-- Diagnóstico (solo lectura): ¿esto revela más grupos de clientes duplicados
-- que fix_clientes_duplicados.sql no veía porque comparaba tipo+número
-- pero acá vemos duplicados de número sin importar el tipo, que es un caso
-- distinto y no se toca automáticamente, solo para informar?
-- ═══════════════════════════════════════════════════════════════════════════
select doc_cliente_norm, count(*) as cantidad,
       array_agg(id order by id) as ids,
       array_agg(nombre_cliente order by id) as nombres
from clientes
where doc_cliente_norm <> ''
group by doc_cliente_norm
having count(*) > 1
order by cantidad desc;
