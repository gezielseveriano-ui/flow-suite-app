-- ============================================================================
-- FactoryView -- Revisão de LI já gerada: remover ou acrescentar itens numa
-- LI existente, mesmo padrão da revisão de romaneio (013_editar_romaneio.sql).
-- Industrialização não mexe em status_expedicao/etapas_avanco, então aqui
-- não há recálculo de avanço a fazer — só inserir/remover a linha mesmo.
-- ============================================================================

create or replace function public.remover_item_industrializacao(p_industrializacao_id bigint, p_item_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.meu_perfil() not in ('pcp', 'expedicao', 'admin') then
    raise exception 'Sem permissão para editar Lista de Industrialização';
  end if;

  delete from public.industrializacao_itens
  where industrializacao_id = p_industrializacao_id and item_id = p_item_id;

  if not found then
    raise exception 'Item não encontrado nesta LI';
  end if;
end;
$$;

-- p_itens = '[{"item_id": 123, "quantidade": 2, "valor_unitario": 10.00}, ...]'::jsonb
create or replace function public.adicionar_itens_industrializacao(p_industrializacao_id bigint, p_itens jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_pedido_id   bigint;
  v_fora_pedido int;
  v_ja_existe   int;
  v_item        jsonb;
  v_item_id     bigint;
  v_qtd         numeric(12,3);
  v_valor_unit  numeric(12,2);
  v_peso_unit   numeric(12,3);
begin
  if public.meu_perfil() not in ('pcp', 'expedicao', 'admin') then
    raise exception 'Sem permissão para editar Lista de Industrialização';
  end if;

  select pedido_id into v_pedido_id from public.industrializacoes where id = p_industrializacao_id;
  if v_pedido_id is null then
    raise exception 'LI não encontrada';
  end if;

  select count(*) into v_fora_pedido
  from public.itens
  where id = any(array(select (elem->>'item_id')::bigint from jsonb_array_elements(p_itens) elem))
    and pedido_id <> v_pedido_id;

  if v_fora_pedido > 0 then
    raise exception 'Todos os itens devem pertencer ao mesmo pedido da LI';
  end if;

  for v_item in select * from jsonb_array_elements(p_itens) loop
    v_item_id    := (v_item->>'item_id')::bigint;
    v_qtd        := (v_item->>'quantidade')::numeric;
    v_valor_unit := coalesce((v_item->>'valor_unitario')::numeric, 0);

    if v_qtd is null or v_qtd <= 0 then
      raise exception 'Quantidade inválida para o item %', v_item_id;
    end if;

    select count(*) into v_ja_existe
    from public.industrializacao_itens where industrializacao_id = p_industrializacao_id and item_id = v_item_id;
    if v_ja_existe > 0 then
      raise exception 'Item % já está nesta LI', v_item_id;
    end if;

    select peso_unitario into v_peso_unit from public.itens where id = v_item_id;

    insert into public.industrializacao_itens (industrializacao_id, item_id, quantidade, peso_unitario, valor_unitario)
    values (p_industrializacao_id, v_item_id, v_qtd, v_peso_unit, v_valor_unit);
  end loop;
end;
$$;
