-- ============================================================================
-- FactoryView -- Volume (agrupamento de itens numa mesma caixa/pacote) por
-- linha do romaneio. Opcional -- fica NULL se o item nao foi agrupado ainda.
-- ============================================================================

alter table public.romaneio_itens add column if not exists volume text;

-- criar_romaneio agora aceita "volume" (opcional) dentro de cada item do jsonb:
-- p_itens = '[{"item_id": 123, "quantidade": 5, "volume": "1"}, ...]'::jsonb
create or replace function public.criar_romaneio(p_pedido_id bigint, p_itens jsonb)
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

  select count(*) into v_fora_pedido
  from public.itens
  where id = any(array(select (elem->>'item_id')::bigint from jsonb_array_elements(p_itens) elem))
    and pedido_id <> p_pedido_id;

  if v_fora_pedido > 0 then
    raise exception 'Todos os itens selecionados devem pertencer ao mesmo pedido';
  end if;

  insert into public.romaneios (pedido_id, usuario_id)
  values (p_pedido_id, auth.uid())
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
