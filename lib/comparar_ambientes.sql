-- ═══════════════════════════════════════════════════════════════════════════
-- SOLO LECTURA. Huella de cada ambiente para saber si los reportes y abonos
-- de PRUEBAS se pueden pasar a PRODUCCIÓN tal cual (mismos códigos de
-- póliza, aseguradoras, intermediarios y usuarios).
--
-- Correr IGUAL en PRUEBAS y en PRODUCCIÓN. Devuelve una sola celda de
-- texto: copiarla completa (clic en la celda → copiar) y pegarla en el chat.
--
-- Cada línea: clave = cantidad / huella / suma de prima pagada.
-- Las pólizas van agrupadas de a 1.000 códigos: si un grupo coincide en los
-- dos ambientes, esas pólizas son las mismas (código, número, aseguradora,
-- cliente y prima).
-- ═══════════════════════════════════════════════════════════════════════════
with lineas as (
  select 'aseg' as clave, count(*)::text || '/' ||
         left(md5(coalesce(string_agg(id || ':' || coalesce(nombre_aseg, ''), ',' order by id), '')), 8) as valor
    from aseguradoras
  union all
  select 'interm', count(*)::text || '/' ||
         left(md5(coalesce(string_agg(id || ':' || coalesce(nombre_interm, ''), ',' order by id), '')), 8)
    from intermediarios
  union all
  select 'usu', count(*)::text || '/' ||
         left(md5(coalesce(string_agg(id || ':' || coalesce(apodo_usuario, ''), ',' order by id), '')), 8)
    from usuarios
  union all
  select 'rep', count(*)::text from reportes_pago
  union all
  select 'abo', count(*)::text || '/polizas:' || count(distinct id_poliza)::text ||
         '/codigos:' || coalesce(min(id_poliza), 0)::text || '-' || coalesce(max(id_poliza), 0)::text
    from abonos_poliza
  union all
  select 'pol' || lpad((id / 1000)::text, 3, '0'),
         count(*)::text || '/' ||
         left(md5(string_agg(
           id || ':' || coalesce(nro_poliza_norm, '') || ':' || coalesce(aseg_id, 0) || ':' ||
           coalesce(cliente_id, 0) || ':' || coalesce(prima_poliza, 0)::text, ',' order by id)), 8) || '/' ||
         coalesce(sum(vlrprimapagada_poliza), 0)::bigint::text
    from polizas
   group by id / 1000
)
select string_agg(clave || '=' || valor, ' | ' order by clave) as huella
  from lineas;
