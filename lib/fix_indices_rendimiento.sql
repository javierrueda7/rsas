-- ═══════════════════════════════════════════════════════════════════════════
-- Fix de rendimiento: índices en las columnas de relación (FK) que la app
-- filtra/joinea todo el tiempo y que hoy no tienen índice — sin esto, cada
-- consulta hace un recorrido completo de la tabla en vez de un lookup.
-- Con RLS ya activo (política por rol, no por fila) esto pasa a notarse
-- más porque cada fila ahora también pasa por el chequeo de política.
--
-- Ejecutar completo, en orden, en el SQL Editor de Supabase. Es seguro
-- volver a correrlo (todo usa "if not exists").
-- ═══════════════════════════════════════════════════════════════════════════

-- 1. abonos_poliza: las dos columnas más consultadas de toda la app — se
--    golpean en cada carga del Estado de Cuenta de una póliza/reporte y en
--    cada creación/edición/borrado de un abono (vía
--    actualizarEstadoPolizaSegunPagos, ver repositorio_pagos.dart).
create index if not exists idx_abonos_poliza_id_poliza  on abonos_poliza (id_poliza);
create index if not exists idx_abonos_poliza_idrep_pago on abonos_poliza (idrep_pago);

-- 2. polizas: soportan tanto los filtros directos como los joins que arma
--    vw_polizas_busqueda (la vista detrás del buscador principal de
--    pólizas) y vw_abonos_detalle.
create index if not exists idx_polizas_cliente_id       on polizas (cliente_id);
create index if not exists idx_polizas_asesor_id        on polizas (asesor_id);
create index if not exists idx_polizas_ramo_id          on polizas (ramo_id);
create index if not exists idx_polizas_producto_id      on polizas (producto_id);
create index if not exists idx_polizas_aseg_id          on polizas (aseg_id);
create index if not exists idx_polizas_intermediario_id on polizas (intermediario_id);
create index if not exists idx_polizas_forma_pago_id    on polizas (forma_pago_id);
create index if not exists idx_polizas_formaexp_id      on polizas (formaexp_id);
create index if not exists idx_polizas_usuario_id       on polizas (usuario_id);
create index if not exists idx_polizas_agencia_id       on polizas (agencia_id);

-- 3. reportes_pago: soporta el join de vw_reportes_resumen.
create index if not exists idx_reportes_pago_aseg_id   on reportes_pago (aseg_id);
create index if not exists idx_reportes_pago_interm_id on reportes_pago (interm_id);

-- 4. productos: catálogo chico hoy, pero barato de indexar y ya se filtra
--    por estas dos columnas al elegir producto en el formulario de póliza.
create index if not exists idx_productos_ramo_id        on productos (ramo_id);
create index if not exists idx_productos_aseguradora_id on productos (aseguradora_id);
