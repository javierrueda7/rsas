-- ═══════════════════════════════════════════════════════════════════════════
-- Fix: sincronizar las secuencias IDENTITY con el id más alto real.
-- No modifica ninguna fila — solo el contador interno que genera el
-- próximo id. Seguro de volver a correr.
--
-- Causa: durante mucho tiempo el código insertaba con un id calculado a
-- mano (máx + 1), sin pasar por la secuencia. La secuencia real quedó
-- atrasada, así que Postgres puede intentar asignar un id que ya existe
-- (choque de llave primaria, error 23505) en la primera creación después
-- de la migración a IDENTITY.
-- ═══════════════════════════════════════════════════════════════════════════

do $$
declare
  t text;
  seq text;
begin
  foreach t in array array[
    'clientes', 'polizas', 'asesores', 'aseguradoras', 'ramos', 'productos',
    'formas_pago', 'formaexp', 'usuarios', 'reportes_pago', 'abonos_poliza',
    'intermediarios'
  ]
  loop
    seq := pg_get_serial_sequence(t, 'id');
    if seq is not null then
      execute format(
        'select setval(%L, coalesce((select max(id) from %I), 0) + 1, false)',
        seq, t
      );
    end if;
  end loop;
end $$;

-- Verificación (de solo lectura, no consume la secuencia): el "próximo id"
-- guardado en cada secuencia debería quedar en max(id) + 1 de su tabla.
select 'clientes' as tabla, (select max(id) from clientes) as max_id,
       (select last_value from pg_sequences where schemaname='public' and sequencename=split_part(pg_get_serial_sequence('clientes','id'),'.',2)) as proximo_id
union all
select 'polizas', (select max(id) from polizas),
       (select last_value from pg_sequences where schemaname='public' and sequencename=split_part(pg_get_serial_sequence('polizas','id'),'.',2))
union all
select 'asesores', (select max(id) from asesores),
       (select last_value from pg_sequences where schemaname='public' and sequencename=split_part(pg_get_serial_sequence('asesores','id'),'.',2));
