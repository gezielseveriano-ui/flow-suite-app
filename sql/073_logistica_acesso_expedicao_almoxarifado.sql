-- ============================================================================
-- FactoryView -- Dá ao perfil "logistica" (072_perfil_logistica.sql) o mesmo
-- acesso que os perfis "expedicao" e "almoxarifado" já têm hoje, nos dois
-- módulos (só esses dois -- Industrialização continua exclusiva do perfil
-- "expedicao"/"pcp", não faz parte do pedido).
--
-- Cada função abaixo é um "create or replace" do corpo já existente, só
-- acrescentando 'logistica' na checagem de permissão -- nada mais muda.
-- Rodar DEPOIS de 072_perfil_logistica.sql (precisa do valor novo do enum já
-- existir).
-- ============================================================================

-- ── Expedição: policies de insert direto (defesa extra por trás das RPCs) ──

alter policy "romaneios_insert_expedicao_admin" on public.romaneios
  with check (public.meu_perfil() in ('expedicao', 'logistica', 'admin'));

alter policy "romaneio_itens_insert_expedicao_admin" on public.romaneio_itens
  with check (public.meu_perfil() in ('expedicao', 'logistica', 'admin'));

-- ── Expedição: RPCs usadas por expedicao.html ──────────────────────────────

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
  if public.meu_perfil() not in ('expedicao', 'logistica', 'admin') then
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

create or replace function public.editar_nota_fiscal_romaneio(p_romaneio_id bigint, p_nota_fiscal text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.meu_perfil() not in ('expedicao', 'logistica', 'admin') then
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

create or replace function public.remover_item_romaneio(p_romaneio_id bigint, p_item_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_qtd_cadastro  numeric(12,3);
  v_qtd_total_exp numeric(12,3);
begin
  if public.meu_perfil() not in ('expedicao', 'logistica', 'admin') then
    raise exception 'Sem permissão para editar romaneio';
  end if;

  delete from public.romaneio_itens
  where romaneio_id = p_romaneio_id and item_id = p_item_id;

  if not found then
    raise exception 'Item não encontrado neste romaneio';
  end if;

  select quantidade into v_qtd_cadastro from public.itens where id = p_item_id;

  select coalesce(sum(quantidade_expedida), 0) into v_qtd_total_exp
  from public.romaneio_itens where item_id = p_item_id;

  update public.itens
  set status_expedicao = case
    when v_qtd_total_exp <= 0 then 'pendente'::status_expedicao_enum
    when v_qtd_total_exp >= v_qtd_cadastro then 'expedido'::status_expedicao_enum
    else 'parcial'::status_expedicao_enum
  end
  where id = p_item_id;

  -- reconstrói o histórico de avanço de expedição/finalizado a partir do zero,
  -- pois o percentual precisa poder cair (a trigger de não-regressão só permite subir).
  delete from public.etapas_avanco
  where item_id = p_item_id and etapa in ('expedicao', 'finalizado');

  if v_qtd_cadastro > 0 and v_qtd_total_exp > 0 then
    insert into public.etapas_avanco (item_id, etapa, percentual, usuario_id)
    values (p_item_id, 'expedicao', least(100, round(v_qtd_total_exp / v_qtd_cadastro * 100)), auth.uid());
  end if;

  if v_qtd_cadastro > 0 and v_qtd_total_exp >= v_qtd_cadastro then
    insert into public.etapas_avanco (item_id, etapa, percentual, usuario_id)
    values (p_item_id, 'finalizado', 100, auth.uid());
  end if;
end;
$$;

create or replace function public.adicionar_itens_romaneio(p_romaneio_id bigint, p_itens jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_pedido_id     bigint;
  v_fora_pedido   int;
  v_ja_existe     int;
  v_item          jsonb;
  v_item_id       bigint;
  v_qtd           numeric(12,3);
  v_volume        text;
  v_peso_unit     numeric(12,3);
  v_qtd_cadastro  numeric(12,3);
  v_qtd_total_exp numeric(12,3);
  v_max_exp       numeric(5,2);
  v_max_fin       numeric(5,2);
begin
  if public.meu_perfil() not in ('expedicao', 'logistica', 'admin') then
    raise exception 'Sem permissão para editar romaneio';
  end if;

  select pedido_id into v_pedido_id from public.romaneios where id = p_romaneio_id;
  if v_pedido_id is null then
    raise exception 'Romaneio não encontrado';
  end if;

  select count(*) into v_fora_pedido
  from public.itens
  where id = any(array(select (elem->>'item_id')::bigint from jsonb_array_elements(p_itens) elem))
    and pedido_id <> v_pedido_id;

  if v_fora_pedido > 0 then
    raise exception 'Todos os itens devem pertencer ao mesmo pedido do romaneio';
  end if;

  for v_item in select * from jsonb_array_elements(p_itens) loop
    v_item_id := (v_item->>'item_id')::bigint;
    v_qtd     := (v_item->>'quantidade')::numeric;
    v_volume  := nullif(v_item->>'volume', '');

    if v_qtd is null or v_qtd <= 0 then
      raise exception 'Quantidade inválida para o item %', v_item_id;
    end if;

    select count(*) into v_ja_existe
    from public.romaneio_itens where romaneio_id = p_romaneio_id and item_id = v_item_id;
    if v_ja_existe > 0 then
      raise exception 'Item % já está neste romaneio', v_item_id;
    end if;

    select peso_unitario, quantidade into v_peso_unit, v_qtd_cadastro
    from public.itens where id = v_item_id;

    insert into public.romaneio_itens (romaneio_id, item_id, quantidade_expedida, peso_unitario, volume)
    values (p_romaneio_id, v_item_id, v_qtd, v_peso_unit, v_volume);

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
end;
$$;

create or replace function public.importar_itens_romaneio(p_romaneio_id bigint, p_itens jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_pedido_id  bigint;
  v_item       jsonb;
  v_item_id    bigint;
  v_qtd        numeric(12,3);
  v_peso_unit  numeric(12,3);
  v_volume     text;
begin
  if public.meu_perfil() not in ('expedicao', 'logistica', 'admin') then
    raise exception 'Sem permissão para importar itens';
  end if;

  select pedido_id into v_pedido_id from public.romaneios where id = p_romaneio_id;
  if v_pedido_id is null then
    raise exception 'Romaneio não encontrado';
  end if;

  for v_item in select * from jsonb_array_elements(p_itens) loop
    v_qtd       := (v_item->>'quantidade')::numeric;
    v_peso_unit := coalesce((v_item->>'peso_unitario')::numeric, 0);
    v_volume    := nullif(v_item->>'volume', '');

    if v_qtd is null or v_qtd <= 0 then
      raise exception 'Quantidade inválida para o item "%"', v_item->>'descricao';
    end if;

    insert into public.itens (
      pedido_id, desenho, desenho_cliente, descricao, tag, produto,
      peso_unitario, quantidade, fornecedor, status_expedicao
    ) values (
      v_pedido_id,
      nullif(v_item->>'desenho', ''),
      nullif(v_item->>'desenho_cliente', ''),
      nullif(v_item->>'descricao', ''),
      nullif(v_item->>'tag', ''),
      'COMERCIAL',
      v_peso_unit,
      v_qtd,
      'COMPRA EXTERNA (importado na expedição)',
      'expedido'
    )
    returning id into v_item_id;

    insert into public.romaneio_itens (romaneio_id, item_id, quantidade_expedida, peso_unitario, volume)
    values (p_romaneio_id, v_item_id, v_qtd, v_peso_unit, v_volume);

    insert into public.etapas_avanco (item_id, etapa, percentual, usuario_id)
    values (v_item_id, 'expedicao', 100, auth.uid()), (v_item_id, 'finalizado', 100, auth.uid());
  end loop;
end;
$$;

create or replace function public.editar_descricao_item_expedicao(p_item_id bigint, p_descricao text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.meu_perfil() not in ('expedicao', 'logistica', 'admin') then
    raise exception 'Sem permissão para editar item';
  end if;

  update public.itens set descricao = nullif(trim(p_descricao), '') where id = p_item_id;

  if not found then
    raise exception 'Item não encontrado';
  end if;
end;
$$;

-- ── Almoxarifado: RPCs usadas por almoxarifado.html ────────────────────────

create or replace function public.importar_almoxarifado(p_itens jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item         jsonb;
  v_sc           bigint;
  v_item_seq     integer;
  v_pedido_bruto text;
  v_pedido_id    bigint;
  v_foi_novo     boolean;
  v_novos        int := 0;
  v_atualizados  int := 0;
begin
  if public.meu_perfil() not in ('almoxarifado', 'logistica', 'admin') then
    raise exception 'Sem permissão para importar';
  end if;

  for v_item in select * from jsonb_array_elements(p_itens) loop
    v_sc       := (v_item->>'sc')::bigint;
    v_item_seq := (v_item->>'item_seq')::integer;

    if v_sc is null or v_item_seq is null then
      raise exception 'Item sem SC ou Item/Sequência válido: %', v_item;
    end if;

    v_pedido_bruto := nullif(v_item->>'pedido_bruto', '');
    v_pedido_id := null;
    if v_pedido_bruto is not null then
      select id into v_pedido_id from public.pedidos where numero_pedido = 'P-' || v_pedido_bruto;
    end if;

    insert into public.almoxarifado_itens (
      sc, item_seq, pedido_bruto, pedido_id, familia, oc, data_prevista_entrega,
      codigo_produto, descricao, data_solicitacao, pc, quantidade_solicitada,
      desenho, requisitante, situacao_oc, nf_sistema, fornecedor, ultima_importacao_em
    ) values (
      v_sc, v_item_seq, v_pedido_bruto, v_pedido_id,
      nullif(v_item->>'familia', ''), nullif(v_item->>'oc', ''),
      nullif(v_item->>'data_prevista_entrega', '')::date,
      nullif(v_item->>'codigo_produto', ''), nullif(v_item->>'descricao', ''),
      nullif(v_item->>'data_solicitacao', '')::date, nullif(v_item->>'pc', ''),
      coalesce((v_item->>'quantidade_solicitada')::numeric, 0),
      nullif(v_item->>'desenho', ''), nullif(v_item->>'requisitante', ''),
      nullif(v_item->>'situacao_oc', ''), nullif(v_item->>'nf_sistema', ''),
      nullif(v_item->>'fornecedor', ''), now()
    )
    on conflict (sc, item_seq) do update set
      pedido_bruto           = excluded.pedido_bruto,
      pedido_id              = excluded.pedido_id,
      familia                = excluded.familia,
      oc                     = excluded.oc,
      data_prevista_entrega  = excluded.data_prevista_entrega,
      codigo_produto         = excluded.codigo_produto,
      descricao              = excluded.descricao,
      data_solicitacao       = excluded.data_solicitacao,
      pc                     = excluded.pc,
      quantidade_solicitada  = excluded.quantidade_solicitada,
      desenho                = excluded.desenho,
      requisitante           = excluded.requisitante,
      situacao_oc            = excluded.situacao_oc,
      ultima_importacao_em   = now(),
      updated_at             = now()
    returning (xmax = 0) into v_foi_novo;

    if v_foi_novo then
      v_novos := v_novos + 1;
    else
      v_atualizados := v_atualizados + 1;
    end if;
  end loop;

  return jsonb_build_object('novos', v_novos, 'atualizados', v_atualizados, 'total', v_novos + v_atualizados);
end;
$$;

create or replace function public.importar_fornecedores_almoxarifado(p_itens jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item        jsonb;
  v_sc          bigint;
  v_item_seq    integer;
  v_fornecedor  text;
  v_oc          text;
  v_linhas      int;
  v_atualizados int := 0;
  v_nao_achados int := 0;
begin
  if public.meu_perfil() not in ('almoxarifado', 'logistica', 'admin') then
    raise exception 'Sem permissão para importar';
  end if;

  for v_item in select * from jsonb_array_elements(p_itens) loop
    v_sc         := (v_item->>'sc')::bigint;
    v_item_seq   := (v_item->>'item_seq')::integer;
    v_fornecedor := nullif(v_item->>'fornecedor', '');
    v_oc         := nullif(v_item->>'oc', '');

    if v_sc is null or v_item_seq is null then
      raise exception 'Item sem SC ou Item/Sequência válido: %', v_item;
    end if;

    update public.almoxarifado_itens
    set fornecedor = coalesce(v_fornecedor, fornecedor),
        oc         = coalesce(v_oc, oc),
        updated_at = now()
    where sc = v_sc and item_seq = v_item_seq;

    get diagnostics v_linhas = row_count;
    if v_linhas > 0 then
      v_atualizados := v_atualizados + 1;
    else
      v_nao_achados := v_nao_achados + 1;
    end if;
  end loop;

  return jsonb_build_object('atualizados', v_atualizados, 'nao_achados', v_nao_achados);
end;
$$;

create or replace function public.editar_recebimento_almoxarifado(
  p_id bigint, p_quantidade_recebida numeric, p_nf text, p_observacao text,
  p_data_recebimento_nf date default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.meu_perfil() not in ('almoxarifado', 'logistica', 'admin') then
    raise exception 'Sem permissão para editar recebimento';
  end if;
  if p_quantidade_recebida is null or p_quantidade_recebida < 0 then
    raise exception 'Quantidade recebida inválida';
  end if;

  update public.almoxarifado_itens
  set quantidade_recebida = p_quantidade_recebida,
      nf                  = nullif(trim(p_nf), ''),
      observacao          = nullif(trim(p_observacao), ''),
      data_recebimento_nf = p_data_recebimento_nf,
      updated_at          = now()
  where id = p_id;

  if not found then
    raise exception 'Item não encontrado';
  end if;
end;
$$;
