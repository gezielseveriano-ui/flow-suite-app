-- ============================================================================
-- FactoryView -- Almoxarifado: 2º relatório do Sapiens (SCOC104, "Ordem de
-- Compra") pra preencher o Fornecedor, que o 1º relatório (SCSC124) não traz.
--
-- Esse relatório é por O.C. (cada exportação cobre 1 O.C.), mas já traz SC e
-- Seq.SC de cada linha -- então casa direto pela MESMA chave de negócio do
-- módulo (sc, item_seq), sem precisar de tabela auxiliar por O.C.
--
-- Efeito colateral que precisa ser corrigido antes: importar_almoxarifado
-- (o import do 1º relatório) sobrescrevia fornecedor/nf_sistema em TODA
-- reimportação -- como o 1º relatório nunca tem esses dois campos, cada
-- reimportação apagava de volta pra null o que este 2º import acabou de
-- preencher. Tira os dois do "do update set" (fica só no insert, pra linha
-- nova nascer null até esse 2º relatório ser importado).
-- ============================================================================

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
  if public.meu_perfil() not in ('almoxarifado', 'admin') then
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

-- ── Importar o 2º relatório (fornecedor por O.C., casado por SC+Item) ──────
-- p_itens = '[{"sc":2015,"item_seq":13,"oc":"2819","fornecedor":"Target Fix"}, ...]'::jsonb
-- Só faz UPDATE -- nunca insere linha nova (esse relatório não tem os campos
-- que importar_almoxarifado exige, como descrição/quantidade solicitada; a
-- linha já precisa ter chegado antes pelo 1º relatório).
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
  if public.meu_perfil() not in ('almoxarifado', 'admin') then
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
