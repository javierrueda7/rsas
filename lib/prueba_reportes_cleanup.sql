-- ═══════════════════════════════════════════════════════════════════════════
-- Borra TODO lo que creó prueba_reportes_setup.sql — pólizas, los abonos
-- que se les hayan cargado durante la prueba, y los clientes de prueba
-- (solo si no quedaron con más pólizas reales asociadas). No toca
-- aseguradoras/ramos/productos, esos ya existían de antes.
-- Ejecutar en el SQL Editor de Supabase (PRUEBAS) cuando termines de
-- probar la importación de reportes.
-- ═══════════════════════════════════════════════════════════════════════════

-- 1. Abonos de esas pólizas (si llegaste a importar el reporte de verdad).
delete from abonos_poliza
where id_poliza in (select id from polizas where obs_poliza = 'PRUEBA-REPORTES-BORRAR');

-- 2. Las pólizas ficticias.
delete from polizas where obs_poliza = 'PRUEBA-REPORTES-BORRAR';

-- 3. Los clientes ficticios — solo si no quedó ninguna póliza real
--    colgada de ellos (por si el matching le asignó por error una línea
--    de más a un cliente de prueba, mejor no perder esa póliza real).
delete from clientes
where notas_cliente = 'PRUEBA-REPORTES-BORRAR'
  and not exists (select 1 from polizas where cliente_id = clientes.id);

-- Verificación: debería devolver 0 filas.
select count(*) as quedaron_pendientes
from clientes
where notas_cliente = 'PRUEBA-REPORTES-BORRAR';
