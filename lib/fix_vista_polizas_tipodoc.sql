-- ═══════════════════════════════════════════════════════════════════════════
-- Agrega tipodoc_cliente a vw_polizas_busqueda para mostrarlo junto al
-- documento en la lista de Pólizas (ej. "CC 79.876.543"). Se agrega al
-- FINAL de la lista de columnas — Postgres exige que un CREATE OR REPLACE
-- VIEW no reordene ni quite columnas existentes, solo puede agregar al
-- final. Todo lo demás queda idéntico a la definición actual.
-- Ejecutar en el SQL Editor de Supabase. Seguro de volver a correr.
-- ═══════════════════════════════════════════════════════════════════════════

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
    c.tipodoc_cliente
   FROM polizas p
     LEFT JOIN clientes c ON c.id = p.cliente_id
     LEFT JOIN asesores a ON a.id = p.asesor_id
     LEFT JOIN ramos r ON r.id = p.ramo_id
     LEFT JOIN productos pr ON pr.id = p.producto_id
     LEFT JOIN aseguradoras ase ON ase.id = p.aseg_id
     LEFT JOIN intermediarios i ON i.id = p.intermediario_id
     LEFT JOIN formas_pago fp ON fp.id = p.forma_pago_id
     LEFT JOIN formaexp fe ON fe.id = p.formaexp_id
     LEFT JOIN usuarios u ON u.id = p.usuario_id;

-- CREATE OR REPLACE no garantiza que se conserven las opciones de storage
-- — se vuelve a fijar security_invoker para que la vista siga respetando
-- la RLS de quien consulta (ver fix_rls_seguridad.sql).
alter view public.vw_polizas_busqueda set (security_invoker = true);
