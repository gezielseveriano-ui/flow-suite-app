-- ============================================================================
-- FactoryView -- Expedição: importar itens comprados fora do sistema (ex:
-- fixação — parafuso, porca, arruela — comprada em outro sistema/fornecedor,
-- nunca passou pela Engenharia/PCP) direto pra dentro de uma LE/romaneio já
-- gerada, a partir de uma planilha no mesmo formato da LE exportada pelo
-- sistema. Isso cria o item (setor "COMERCIAL", fora da capacidade fabril)
-- já como expedido, pra aparecer no Excel final da LE e no Dashboard.
--
-- O perfil "expedicao" não tem permissão de INSERT direto em `itens` (só
-- pcp/admin, ver 003_rls_policies.sql) -- por isso essa é uma função
-- security definer, no mesmo padrão de `adicionar_itens_romaneio`
-- (013_editar_romaneio.sql), que já valida o perfil internamente.
-- ============================================================================

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
  if public.meu_perfil() not in ('expedicao', 'admin') then
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
