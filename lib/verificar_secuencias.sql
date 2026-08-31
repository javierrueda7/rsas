select 'clientes' as tabla, (select max(id) from clientes) as max_id,
       (select last_value from clientes_id_seq) as proximo_id
union all
select 'polizas', (select max(id) from polizas),
       (select last_value from polizas_id_seq)
union all
select 'asesores', (select max(id) from asesores),
       (select last_value from asesores_id_seq);
