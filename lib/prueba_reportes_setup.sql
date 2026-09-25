-- ═══════════════════════════════════════════════════════════════════════════
-- SOLO PARA PRUEBAS: crea clientes y pólizas ficticias que coinciden (mismo
-- documento, mismo núcleo de número de póliza y mismo anexo) con líneas
-- reales de los 3 reportes de comisiones de ejemplo (Solidaria, Mundial,
-- Estado), para poder importar esos reportes de verdad y ver si el
-- matching de la pantalla de revisión los encuentra bien.
--
-- Todo lo que este script crea queda marcado con la nota
-- 'PRUEBA-REPORTES-BORRAR' (en obs_poliza / notas_cliente) para poder
-- borrarlo después con fix_prueba_reportes_cleanup.sql sin tocar nada real.
-- Reusa la Aseguradora y el Ramo/Producto "CUMPLIMIENTO" que ya existen —
-- si por algún motivo no existieran para alguna aseguradora, ese bloque
-- simplemente no crea la póliza (se ve en el mensaje de NOTICE) en vez de
-- fallar todo el script.
--
-- Ejecutar en el SQL Editor de Supabase (PRUEBAS). Seguro de volver a
-- correr — no duplica si ya existen los mismos documentos/pólizas.
-- ═══════════════════════════════════════════════════════════════════════════

do $$
declare
  v_aseg_id bigint;
  v_ramo_id bigint;
  v_prod_id bigint;
  v_cliente_id bigint;
  v_usuario_id bigint;
begin
  select id into v_usuario_id from usuarios order by id limit 1;

  -- ─── Helper inline: por cada (aseguradora, doc, nombre, nro_base, anexo, prima) ───
  -- Solidaria
  select id into v_aseg_id from aseguradoras where nombre_aseg ilike '%solidaria%' limit 1;
  if v_aseg_id is not null then
    select p.id, p.ramo_id into v_prod_id, v_ramo_id
      from productos p where p.aseguradora_id = v_aseg_id and p.nombre_prod ilike '%cumplimiento%' limit 1;
    if v_prod_id is not null then
      -- Cliente 1: IMAGENES DIAGNOSTICAS POR ACCIONES SIMPLIFICADAS
      insert into clientes (nombre_cliente, tipopers_cliente, tipodoc_cliente, doc_cliente, estado_cliente, notas_cliente)
        select 'IMAGENES DIAGNOSTICAS POR ACCIONES SIMPLIFICADAS', 'J', 'NIT', '800177716', true, 'PRUEBA-REPORTES-BORRAR'
        where not exists (select 1 from clientes where doc_cliente_norm = '800177716')
        returning id into v_cliente_id;
      if v_cliente_id is null then
        select id into v_cliente_id from clientes where doc_cliente_norm = '800177716';
      end if;
      insert into polizas (nro_poliza, cliente_id, ramo_id, producto_id, aseg_id, prima_poliza, valor_poliza,
                            ffin_poliza, usuario_id, bien_asegurado, obs_poliza)
        select '994000000193-6', v_cliente_id, v_ramo_id, v_prod_id, v_aseg_id, 7692824.92, 7692824.92,
               now() + interval '1 year', v_usuario_id, 'PRUEBA - Solidaria', 'PRUEBA-REPORTES-BORRAR'
        where not exists (select 1 from polizas where nro_poliza_norm = '9940000001936');

      -- Cliente 2: FUNDACION COLOMBIA COLLEGE (tiene reversión en el reporte)
      insert into clientes (nombre_cliente, tipopers_cliente, tipodoc_cliente, doc_cliente, estado_cliente, notas_cliente)
        select 'FUNDACION COLOMBIA COLLEGE', 'J', 'NIT', '900159756', true, 'PRUEBA-REPORTES-BORRAR'
        where not exists (select 1 from clientes where doc_cliente_norm = '900159756')
        returning id into v_cliente_id;
      if v_cliente_id is null then
        select id into v_cliente_id from clientes where doc_cliente_norm = '900159756';
      end if;
      insert into polizas (nro_poliza, cliente_id, ramo_id, producto_id, aseg_id, prima_poliza, valor_poliza,
                            ffin_poliza, usuario_id, bien_asegurado, obs_poliza)
        select '994000000046-0', v_cliente_id, v_ramo_id, v_prod_id, v_aseg_id, 750000, 750000,
               now() + interval '1 year', v_usuario_id, 'PRUEBA - Solidaria (con reversion)', 'PRUEBA-REPORTES-BORRAR'
        where not exists (select 1 from polizas where nro_poliza_norm = '9940000000460');
    else
      raise notice 'Solidaria: no se encontró producto CUMPLIMIENTO, se omite.';
    end if;
  else
    raise notice 'No se encontró la aseguradora Solidaria, se omite.';
  end if;

  -- Mundial
  select id into v_aseg_id from aseguradoras where nombre_aseg ilike '%mundial%' limit 1;
  if v_aseg_id is not null then
    select p.id, p.ramo_id into v_prod_id, v_ramo_id
      from productos p where p.aseguradora_id = v_aseg_id and p.nombre_prod ilike '%cumplimiento%' limit 1;
    if v_prod_id is not null then
      insert into clientes (nombre_cliente, tipopers_cliente, tipodoc_cliente, doc_cliente, estado_cliente, notas_cliente)
        select 'URIBE SERGIO FERNANDO', 'N', 'CC', '91078726', true, 'PRUEBA-REPORTES-BORRAR'
        where not exists (select 1 from clientes where doc_cliente_norm = '91078726')
        returning id into v_cliente_id;
      if v_cliente_id is null then
        select id into v_cliente_id from clientes where doc_cliente_norm = '91078726';
      end if;
      insert into polizas (nro_poliza, cliente_id, ramo_id, producto_id, aseg_id, prima_poliza, valor_poliza,
                            ffin_poliza, usuario_id, bien_asegurado, obs_poliza)
        select '100022101-0', v_cliente_id, v_ramo_id, v_prod_id, v_aseg_id, 204832, 204832,
               now() + interval '1 year', v_usuario_id, 'PRUEBA - Mundial', 'PRUEBA-REPORTES-BORRAR'
        where not exists (select 1 from polizas where nro_poliza_norm = '1000221010');

      insert into clientes (nombre_cliente, tipopers_cliente, tipodoc_cliente, doc_cliente, estado_cliente, notas_cliente)
        select 'OBRAS COLOMBIA Y SERVICIOS OBRACOL SAS', 'J', 'NIT', '900995495', true, 'PRUEBA-REPORTES-BORRAR'
        where not exists (select 1 from clientes where doc_cliente_norm = '900995495')
        returning id into v_cliente_id;
      if v_cliente_id is null then
        select id into v_cliente_id from clientes where doc_cliente_norm = '900995495';
      end if;
      insert into polizas (nro_poliza, cliente_id, ramo_id, producto_id, aseg_id, prima_poliza, valor_poliza,
                            ffin_poliza, usuario_id, bien_asegurado, obs_poliza)
        select '100078341-0', v_cliente_id, v_ramo_id, v_prod_id, v_aseg_id, 2922680, 2922680,
               now() + interval '1 year', v_usuario_id, 'PRUEBA - Mundial (con reversion)', 'PRUEBA-REPORTES-BORRAR'
        where not exists (select 1 from polizas where nro_poliza_norm = '1000783410');
    else
      raise notice 'Mundial: no se encontró producto CUMPLIMIENTO, se omite.';
    end if;
  else
    raise notice 'No se encontró la aseguradora Mundial, se omite.';
  end if;

  -- Seguros del Estado
  select id into v_aseg_id from aseguradoras where nombre_aseg ilike '%estado%' limit 1;
  if v_aseg_id is not null then
    select p.id, p.ramo_id into v_prod_id, v_ramo_id
      from productos p where p.aseguradora_id = v_aseg_id and p.nombre_prod ilike '%cumplimiento%' limit 1;
    if v_prod_id is not null then
      insert into clientes (nombre_cliente, tipopers_cliente, tipodoc_cliente, doc_cliente, estado_cliente, notas_cliente)
        select 'DIANA MARCELA VILLAMIZAR OLARTE', 'N', 'CC', '1098633206', true, 'PRUEBA-REPORTES-BORRAR'
        where not exists (select 1 from clientes where doc_cliente_norm = '1098633206')
        returning id into v_cliente_id;
      if v_cliente_id is null then
        select id into v_cliente_id from clientes where doc_cliente_norm = '1098633206';
      end if;
      insert into polizas (nro_poliza, cliente_id, ramo_id, producto_id, aseg_id, prima_poliza, valor_poliza,
                            ffin_poliza, usuario_id, bien_asegurado, obs_poliza)
        select '101011263-1', v_cliente_id, v_ramo_id, v_prod_id, v_aseg_id, 815175, 815175,
               now() + interval '1 year', v_usuario_id, 'PRUEBA - Estado', 'PRUEBA-REPORTES-BORRAR'
        where not exists (select 1 from polizas where nro_poliza_norm = '1010112631');

      insert into clientes (nombre_cliente, tipopers_cliente, tipodoc_cliente, doc_cliente, estado_cliente, notas_cliente)
        select 'JUAN CRISTOBAL MARTINEZ PRADA', 'N', 'CC', '13819056', true, 'PRUEBA-REPORTES-BORRAR'
        where not exists (select 1 from clientes where doc_cliente_norm = '13819056')
        returning id into v_cliente_id;
      if v_cliente_id is null then
        select id into v_cliente_id from clientes where doc_cliente_norm = '13819056';
      end if;
      insert into polizas (nro_poliza, cliente_id, ramo_id, producto_id, aseg_id, prima_poliza, valor_poliza,
                            ffin_poliza, usuario_id, bien_asegurado, obs_poliza)
        select '101010543-5', v_cliente_id, v_ramo_id, v_prod_id, v_aseg_id, 1942448.74, 1942448.74,
               now() + interval '1 year', v_usuario_id, 'PRUEBA - Estado (con reversion, otro anexo)', 'PRUEBA-REPORTES-BORRAR'
        where not exists (select 1 from polizas where nro_poliza_norm = '1010105435');
    else
      raise notice 'Estado: no se encontró producto CUMPLIMIENTO, se omite.';
    end if;
  else
    raise notice 'No se encontró la aseguradora Estado, se omite.';
  end if;
end $$;

-- Verificación: esto es lo que quedó creado.
select id, nro_poliza, nombre_cliente, nombre_aseg, prima_poliza, obs_poliza
from vw_polizas_busqueda
where obs_poliza = 'PRUEBA-REPORTES-BORRAR'
order by id;
