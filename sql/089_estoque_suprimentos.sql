-- ============================================================================
-- FactoryView -- Estoque MDE: terceiro tipo "suprimento" (EPI, disco de corte,
-- gás, lixa, óleo, material de limpeza e escritório...).
--
-- Usa o mesmo controle dos itens comprados: saldo por quantidade, entrada,
-- saída (baixa por pedido ou uso interno, quem retirou, setor), estorno,
-- histórico e estoque mínimo. Só o que muda: o banco passa a aceitar
-- tipo = 'suprimento'. Nenhuma tabela nova, nenhum dado existente é alterado.
-- Rodar DEPOIS de 075_estoque_mde.sql.
-- ============================================================================

-- troca a regra que só aceitava 'comprado' e 'materia_prima'
do $$
declare
  r record;
begin
  for r in
    select c.conname
    from pg_constraint c
    where c.conrelid = 'public.estoque_itens'::regclass
      and c.contype = 'c'
      and pg_get_constraintdef(c.oid) ilike '%materia_prima%'
  loop
    execute format('alter table public.estoque_itens drop constraint %I', r.conname);
  end loop;
end $$;

alter table public.estoque_itens
  add constraint estoque_itens_tipo_check
  check (tipo in ('comprado', 'materia_prima', 'suprimento'));

-- cadastro de item (igual ao da 075; só a validação do tipo aceita 'suprimento')
create or replace function public.salvar_item_estoque(p_id bigint, p_dados jsonb)
returns public.estoque_itens
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item public.estoque_itens;
begin
  if public.meu_perfil() not in ('almoxarifado', 'logistica', 'admin') then
    raise exception 'Sem permissão para cadastrar item de estoque';
  end if;
  if nullif(trim(p_dados->>'descricao'), '') is null then
    raise exception 'Informe a descrição do item';
  end if;
  if coalesce(p_dados->>'tipo', '') not in ('comprado', 'materia_prima', 'suprimento') then
    raise exception 'Tipo inválido (comprado, materia_prima ou suprimento)';
  end if;

  if p_id is null then
    insert into public.estoque_itens (
      tipo, codigo, descricao, categoria, especificacao, unidade,
      peso_unitario_kg, localizacao, estoque_minimo
    ) values (
      p_dados->>'tipo',
      nullif(trim(p_dados->>'codigo'), ''),
      trim(p_dados->>'descricao'),
      nullif(trim(p_dados->>'categoria'), ''),
      nullif(trim(p_dados->>'especificacao'), ''),
      coalesce(nullif(trim(upper(p_dados->>'unidade')), ''), 'PÇ'),
      nullif(p_dados->>'peso_unitario_kg', '')::numeric,
      nullif(trim(p_dados->>'localizacao'), ''),
      nullif(p_dados->>'estoque_minimo', '')::numeric
    )
    returning * into v_item;
  else
    update public.estoque_itens set
      tipo             = p_dados->>'tipo',
      codigo           = nullif(trim(p_dados->>'codigo'), ''),
      descricao        = trim(p_dados->>'descricao'),
      categoria        = nullif(trim(p_dados->>'categoria'), ''),
      especificacao    = nullif(trim(p_dados->>'especificacao'), ''),
      unidade          = coalesce(nullif(trim(upper(p_dados->>'unidade')), ''), 'PÇ'),
      peso_unitario_kg = nullif(p_dados->>'peso_unitario_kg', '')::numeric,
      localizacao      = nullif(trim(p_dados->>'localizacao'), ''),
      estoque_minimo   = nullif(p_dados->>'estoque_minimo', '')::numeric,
      ativo            = coalesce((p_dados->>'ativo')::boolean, ativo),
      atualizado_em    = now()
    where id = p_id
    returning * into v_item;

    if v_item.id is null then
      raise exception 'Item não encontrado';
    end if;
  end if;

  return v_item;
end;
$$;

grant execute on function public.salvar_item_estoque(bigint, jsonb) to authenticated;
