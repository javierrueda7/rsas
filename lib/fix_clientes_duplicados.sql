-- ═══════════════════════════════════════════════════════════════════════════
-- Detecta y permite unificar clientes duplicados: mismo tipo de documento
-- Y mismo número de documento (sin puntos). Dos clientes con el mismo
-- número pero tipo distinto (una CC y un NIT, por ejemplo) NO cuentan como
-- duplicados — eso sí puede pasar en la vida real.
-- Ejecutar en el SQL Editor de Supabase. Seguro de volver a correr.
-- ═══════════════════════════════════════════════════════════════════════════

-- 1. Diagnóstico (solo lectura): ¿cuántos grupos hay hoy?
select tipodoc_cliente, doc_cliente, count(*) as cantidad,
       array_agg(id order by id) as ids,
       array_agg(nombre_cliente order by id) as nombres
from clientes
where doc_cliente is not null and doc_cliente <> ''
  and tipodoc_cliente is not null and tipodoc_cliente <> ''
group by tipodoc_cliente, doc_cliente
having count(*) > 1
order by cantidad desc;

-- ═══════════════════════════════════════════════════════════════════════════
-- 2. Vista para que la pantalla "Clientes duplicados" de la app solo traiga
--    los que en verdad están repetidos, no el catálogo completo.
-- ═══════════════════════════════════════════════════════════════════════════
create or replace view vw_clientes_duplicados as
select c.*
from clientes c
where c.id in (
  select id
  from clientes
  where doc_cliente is not null and doc_cliente <> ''
    and tipodoc_cliente is not null and tipodoc_cliente <> ''
    and (tipodoc_cliente, doc_cliente) in (
      select tipodoc_cliente, doc_cliente
      from clientes
      where doc_cliente is not null and doc_cliente <> ''
        and tipodoc_cliente is not null and tipodoc_cliente <> ''
      group by tipodoc_cliente, doc_cliente
      having count(*) > 1
    )
);

alter view public.vw_clientes_duplicados set (security_invoker = true);

-- ═══════════════════════════════════════════════════════════════════════════
-- 3. Función para fusionar: mueve todas las pólizas de los clientes
--    "sobrantes" hacia el cliente que se decide conservar, y borra los
--    sobrantes. Todo en una sola transacción — o se hace todo, o no se hace
--    nada. La usa la pantalla "Clientes duplicados" de la app, nunca borra
--    nada sin que el usuario elija explícitamente cuál conservar.
-- ═══════════════════════════════════════════════════════════════════════════
create or replace function fusionar_clientes(p_id_bueno bigint, p_ids_malos bigint[])
returns void
language plpgsql
security invoker
as $$
begin
  if p_id_bueno = any(p_ids_malos) then
    raise exception 'El cliente a conservar no puede estar en la lista de sobrantes.';
  end if;

  update polizas
  set cliente_id = p_id_bueno
  where cliente_id = any(p_ids_malos);

  delete from clientes where id = any(p_ids_malos);
end;
$$;
