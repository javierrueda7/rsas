-- ═══════════════════════════════════════════════════════════════════════════
-- SOLO LECTURA. Valida, en PRODUCCIÓN, los reportes y abonos históricos de
-- PRUEBAS cargados en el esquema aparte hist_pruebas (archivos
-- C:\projects\historico_reportes_privado\hist_*.sql), antes de pasarlos a
-- las tablas reales.
--
-- CONSULTA 1: resumen (una fila por verificación). CONSULTA 2: detalle de
-- las pólizas que no cuadran. Sombrear cada una y Run.
-- ═══════════════════════════════════════════════════════════════════════════


-- ── CONSULTA 1: resumen ─────────────────────────────────────────────────────
with abo as (
  select h.*, p.id as prod_id, p.nro_poliza_norm as prod_nro, p.aseg_id as prod_aseg,
         p.vlrprimapagada_poliza as prod_pagado, p.vlrprimapagada_base as prod_base
    from hist_pruebas.abonos h
    left join polizas p on p.id = h.id_poliza
),
por_poliza as (
  select id_poliza,
         sum(vlrabono_prima) filter (where estado_pago <> 'A') as suma,
         max(prod_base) as base, bool_or(prod_id is null) as falta
    from abo group by id_poliza
)
select '1. reportes a pasar' as verificacion, count(*)::text as resultado from hist_pruebas.reportes
union all select '2. abonos a pasar', count(*)::text from hist_pruebas.abonos
union all select '3. reportes con aseguradora distinta en producción',
  count(*)::text from hist_pruebas.reportes r
  join hist_pruebas.aseguradoras ha on ha.id = r.aseg_id
  left join aseguradoras a on a.id = r.aseg_id
 where a.id is null or upper(trim(a.nombre_aseg)) <> upper(trim(ha.nombre_aseg))
union all select '4. reportes con intermediario distinto en producción',
  count(*)::text from hist_pruebas.reportes r
  join hist_pruebas.intermediarios hi on hi.id = r.interm_id
  left join intermediarios i on i.id = r.interm_id
 where i.id is null or upper(trim(i.nombre_interm)) <> upper(trim(hi.nombre_interm))
union all select '5. reportes con usuario que no existe', count(*)::text from hist_pruebas.reportes r
 where r.usuario_id is not null and not exists (select 1 from usuarios u where u.id = r.usuario_id)
union all select '6. abonos con usuario que no existe', count(*)::text from hist_pruebas.abonos a
 where a.usuario_id is not null and not exists (select 1 from usuarios u where u.id = a.usuario_id)
union all select '7. abonos cuya póliza NO existe en producción', count(*)::text from abo where prod_id is null
union all select '8. abonos cuya póliza tiene OTRO número en producción',
  count(*)::text from abo where prod_id is not null and coalesce(prod_nro, '') <> coalesce(pol_nro_norm, '')
union all select '9. abonos cuya póliza tiene OTRA aseguradora en producción',
  count(*)::text from abo where prod_id is not null and prod_aseg is distinct from pol_aseg_id
union all select '10. pólizas con abonos', count(*)::text from por_poliza
union all select '11. pólizas donde lo pagado de producción = suma de abonos',
  count(*)::text from por_poliza where not falta and round(coalesce(base, 0), 0) = round(coalesce(suma, 0), 0)
union all select '12. pólizas donde NO cuadra (diferencia total en $)',
  count(*)::text || ' (' || coalesce(sum(coalesce(base, 0) - coalesce(suma, 0)), 0)::bigint::text || ')'
  from por_poliza where not falta and round(coalesce(base, 0), 0) <> round(coalesce(suma, 0), 0)
union all select '13. ya hay reportes o abonos reales en producción',
  ((select count(*) from reportes_pago) + (select count(*) from abonos_poliza))::text;


-- ── CONSULTA 2: detalle de las pólizas con problemas (máx. 200) ────────────
with abo as (
  select h.*, p.id as prod_id, p.nro_poliza as prod_nro_poliza, p.nro_poliza_norm as prod_nro,
         p.aseg_id as prod_aseg, p.vlrprimapagada_base as prod_base
    from hist_pruebas.abonos h
    left join polizas p on p.id = h.id_poliza
)
select id_poliza,
       max(pol_nro_norm)                         as numero_en_pruebas,
       max(prod_nro_poliza)                      as numero_en_produccion,
       max(pol_aseg_id)                          as aseg_pruebas,
       max(prod_aseg)                            as aseg_produccion,
       sum(vlrabono_prima) filter (where estado_pago <> 'A') as suma_abonos,
       max(prod_base)                            as pagado_produccion,
       case when bool_or(prod_id is null) then 'no existe en producción'
            when max(coalesce(prod_nro, '')) <> max(coalesce(pol_nro_norm, '')) then 'otro número'
            when max(prod_aseg) is distinct from max(pol_aseg_id) then 'otra aseguradora'
            else 'pagado distinto' end            as problema
  from abo
 group by id_poliza
having bool_or(prod_id is null)
    or max(coalesce(prod_nro, '')) <> max(coalesce(pol_nro_norm, ''))
    or max(prod_aseg) is distinct from max(pol_aseg_id)
    or round(coalesce(max(prod_base), 0), 0)
       <> round(coalesce(sum(vlrabono_prima) filter (where estado_pago <> 'A'), 0), 0)
 order by problema, id_poliza
 limit 200;
