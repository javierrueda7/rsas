-- ═══════════════════════════════════════════════════════════════════════════
-- El documento de identidad del cliente (doc_cliente) va a quedar SIEMPRE
-- guardado sin puntos ("9002278851", "900227885-1"). Los puntos que
-- aparecían antes eran inconsistentes (algunos clientes los tenían, otros
-- no) y eso rompía la búsqueda/matching contra los PDFs. La app ya se
-- encarga de que no se vuelvan a guardar con puntos — esto solo limpia lo
-- que ya existe. Ejecutar en el SQL Editor de Supabase. Seguro de repetir.
-- ═══════════════════════════════════════════════════════════════════════════

-- 1. Diagnóstico (solo lectura): ¿cuántos clientes tienen puntos hoy?
select count(*) as clientes_con_puntos
from clientes
where doc_cliente like '%.%';

-- 2. Limpieza: les quita los puntos a los que los tengan.
update clientes
set doc_cliente = replace(doc_cliente, '.', '')
where doc_cliente like '%.%';
