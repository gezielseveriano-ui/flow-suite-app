-- ============================================================================
-- FactoryView -- Expedição: número da Nota Fiscal por romaneio (LE). Cada LE
-- gera uma nota fiscal (emitida por outro setor, sem nada físico aqui) --
-- passa a ser obrigatório informar esse número ao gerar um romaneio novo, e
-- ele aparece ao lado do número da LE em todo lugar que a LE já aparecia
-- (Lista de Embarque/Histórico da Expedição, Relatório Geral e Itens
-- Expedidos do Dashboard), pra dar pra pesquisar por nota fiscal depois.
--
-- Romaneios já existentes (antes desta migração) ficam com nota_fiscal em
-- branco -- não dá pra inventar o número deles. Editáveis depois pela tela
-- (Lista de Embarque/Histórico), sem precisar recriar o romaneio.
-- ============================================================================

alter table public.romaneios add column if not exists nota_fiscal text;

-- criar_romaneio passa a exigir a nota fiscal (novo parâmetro obrigatório —
-- por isso derruba a assinatura de 2 parâmetros antes de recriar com 3,
-- senão ficam as duas versões coexistindo, ambíguas pro PostgREST).
drop function if exists public.criar_romaneio(bigint, jsonb);

create or replace function public.criar_romaneio(p_pedido_id bigint, p_itens jsonb, p_nota_fiscal text)
returns public.romaneios
language plpgsql
security definer
set search_path = public
as $$
declare
  v_romaneio     public.romaneios;
  v_fora_pedido  int;
  v_item         jsonb;
  v_item_id      bigint;
  v_qtd          numeric(12,3);
  v_volume       text;
  v_peso_unit    numeric(12,3);
  v_qtd_cadastro numeric(12,3);
  v_qtd_total_exp numeric(12,3);
  v_max_exp      numeric(5,2);
  v_max_fin      numeric(5,2);
begin
  if public.meu_perfil() not in ('expedicao', 'admin') then
    raise exception 'Sem permissão para gerar romaneio';
  end if;

  if p_nota_fiscal is null or trim(p_nota_fiscal) = '' then
    raise exception 'Informe o número da nota fiscal';
  end if;

  select count(*) into v_fora_pedido
  from public.itens
  where id = any(array(select (elem->>'item_id')::bigint from jsonb_array_elements(p_itens) elem))
    and pedido_id <> p_pedido_id;

  if v_fora_pedido > 0 then
    raise exception 'Todos os itens selecionados devem pertencer ao mesmo pedido';
  end if;

  insert into public.romaneios (pedido_id, usuario_id, nota_fiscal)
  values (p_pedido_id, auth.uid(), trim(p_nota_fiscal))
  returning * into v_romaneio;

  for v_item in select * from jsonb_array_elements(p_itens) loop
    v_item_id := (v_item->>'item_id')::bigint;
    v_qtd     := (v_item->>'quantidade')::numeric;
    v_volume  := nullif(v_item->>'volume', '');

    if v_qtd is null or v_qtd <= 0 then
      raise exception 'Quantidade inválida para o item %', v_item_id;
    end if;

    select peso_unitario, quantidade into v_peso_unit, v_qtd_cadastro
    from public.itens where id = v_item_id;

    insert into public.romaneio_itens (romaneio_id, item_id, quantidade_expedida, peso_unitario, volume)
    values (v_romaneio.id, v_item_id, v_qtd, v_peso_unit, v_volume);

    select coalesce(sum(quantidade_expedida), 0) into v_qtd_total_exp
    from public.romaneio_itens where item_id = v_item_id;

    update public.itens
    set status_expedicao = case
      when v_qtd_total_exp >= v_qtd_cadastro then 'expedido'::status_expedicao_enum
      else 'parcial'::status_expedicao_enum
    end
    where id = v_item_id;

    select max(percentual) into v_max_exp from public.etapas_avanco where item_id = v_item_id and etapa = 'expedicao';
    if v_qtd_cadastro > 0 then
      if v_max_exp is null or least(100, round(v_qtd_total_exp / v_qtd_cadastro * 100)) > v_max_exp then
        insert into public.etapas_avanco (item_id, etapa, percentual, usuario_id)
        values (v_item_id, 'expedicao', least(100, round(v_qtd_total_exp / v_qtd_cadastro * 100)), auth.uid());
      end if;
    end if;

    if v_qtd_total_exp >= v_qtd_cadastro then
      select max(percentual) into v_max_fin from public.etapas_avanco where item_id = v_item_id and etapa = 'finalizado';
      if v_max_fin is null or v_max_fin < 100 then
        insert into public.etapas_avanco (item_id, etapa, percentual, usuario_id)
        values (v_item_id, 'finalizado', 100, auth.uid());
      end if;
    end if;
  end loop;

  return v_romaneio;
end;
$$;

-- ── editar/preencher a nota fiscal de um romaneio já existente ─────────────
-- (backfill dos romaneios antigos, ou corrigir número digitado errado)
create or replace function public.editar_nota_fiscal_romaneio(p_romaneio_id bigint, p_nota_fiscal text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.meu_perfil() not in ('expedicao', 'admin') then
    raise exception 'Sem permissão para editar romaneio';
  end if;

  if p_nota_fiscal is null or trim(p_nota_fiscal) = '' then
    raise exception 'Informe o número da nota fiscal';
  end if;

  update public.romaneios set nota_fiscal = trim(p_nota_fiscal) where id = p_romaneio_id;

  if not found then
    raise exception 'Romaneio não encontrado';
  end if;
end;
$$;
