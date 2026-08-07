-- ============================================================================
-- FactoryView -- Revisão de romaneios já gerados: remover ou acrescentar itens
-- num romaneio existente (LE), sem precisar gerar um novo. Reaproveita a mesma
-- logica de recalculo de status_expedicao / etapas_avanco usada em criar_romaneio.
-- ============================================================================

-- ── Remover um item de um romaneio já gerado ────────────────────────────────
-- Reverte a quantidade expedida daquele item (recalcula pendente/parcial/expedido
-- e reabre a etapa "finalizado" se ela não for mais 100% coberta).
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
  if public.meu_perfil() not in ('expedicao', 'admin') then
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

-- ── Acrescentar itens a um romaneio já gerado ───────────────────────────────
-- p_itens = '[{"item_id": 123, "quantidade": 5, "volume": "1"}, ...]'::jsonb
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
  if public.meu_perfil() not in ('expedicao', 'admin') then
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
