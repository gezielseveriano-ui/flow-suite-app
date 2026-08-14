-- ============================================================================
-- FactoryView -- PCP passa a ser apenas VISUALIZAÇÃO em Produção, Expedição
-- e Industrialização (o front já esconde os botões de escrita para o perfil
-- 'pcp' nessas 3 telas). Esta migração reforça a regra no banco: remove
-- 'pcp' das policies de escrita de Industrialização (fornecedores, LI e
-- itens da LI) e do RPC criar_industrializacao, deixando só expedicao/admin
-- (Produção e Expedição já eram fechadas para pcp desde o início — ver
-- 003_rls_policies.sql e 013_editar_romaneio.sql).
-- ============================================================================

drop policy "fornecedores_insert" on public.fornecedores;
create policy "fornecedores_insert" on public.fornecedores
  for insert with check (public.meu_perfil() in ('expedicao', 'admin'));

drop policy "fornecedores_update" on public.fornecedores;
create policy "fornecedores_update" on public.fornecedores
  for update using (public.meu_perfil() in ('expedicao', 'admin'));

drop policy "industrializacoes_insert" on public.industrializacoes;
create policy "industrializacoes_insert" on public.industrializacoes
  for insert with check (public.meu_perfil() in ('expedicao', 'admin'));

drop policy "industrializacoes_delete" on public.industrializacoes;
create policy "industrializacoes_delete" on public.industrializacoes
  for delete using (public.meu_perfil() in ('expedicao', 'admin'));

drop policy "industrializacao_itens_insert" on public.industrializacao_itens;
create policy "industrializacao_itens_insert" on public.industrializacao_itens
  for insert with check (public.meu_perfil() in ('expedicao', 'admin'));

drop policy "industrializacao_itens_delete" on public.industrializacao_itens;
create policy "industrializacao_itens_delete" on public.industrializacao_itens
  for delete using (public.meu_perfil() in ('expedicao', 'admin'));

create or replace function public.criar_industrializacao(
  p_pedido_id bigint,
  p_fornecedor_id bigint,
  p_natureza_operacao text,
  p_oc text,
  p_itens jsonb
)
returns public.industrializacoes
language plpgsql
security definer
set search_path = public
as $$
declare
  v_li           public.industrializacoes;
  v_fora_pedido  int;
  v_item         jsonb;
  v_item_id      bigint;
  v_qtd          numeric(12,3);
  v_valor_unit   numeric(12,2);
  v_peso_unit    numeric(12,3);
begin
  if public.meu_perfil() not in ('expedicao', 'admin') then
    raise exception 'Sem permissão para gerar Lista de Industrialização';
  end if;

  select count(*) into v_fora_pedido
  from public.itens
  where id = any(array(select (elem->>'item_id')::bigint from jsonb_array_elements(p_itens) elem))
    and pedido_id <> p_pedido_id;

  if v_fora_pedido > 0 then
    raise exception 'Todos os itens selecionados devem pertencer ao mesmo pedido';
  end if;

  insert into public.industrializacoes (pedido_id, fornecedor_id, natureza_operacao, oc, usuario_id)
  values (p_pedido_id, p_fornecedor_id, p_natureza_operacao, p_oc, auth.uid())
  returning * into v_li;

  for v_item in select * from jsonb_array_elements(p_itens) loop
    v_item_id    := (v_item->>'item_id')::bigint;
    v_qtd        := (v_item->>'quantidade')::numeric;
    v_valor_unit := coalesce((v_item->>'valor_unitario')::numeric, 0);

    if v_qtd is null or v_qtd <= 0 then
      raise exception 'Quantidade inválida para o item %', v_item_id;
    end if;

    select peso_unitario into v_peso_unit from public.itens where id = v_item_id;

    insert into public.industrializacao_itens (industrializacao_id, item_id, quantidade, peso_unitario, valor_unitario)
    values (v_li.id, v_item_id, v_qtd, v_peso_unit, v_valor_unit);
  end loop;

  return v_li;
end;
$$;
