-- ============================================================================
-- FactoryView -- Módulo Almoxarifado: substitui o controle manual em planilha
-- das Solicitações de Compra/Recebimento exportadas do Sapiens.
--
-- Rodar DEPOIS de 065_perfil_almoxarifado_enum.sql (precisa do perfil já
-- existir no enum antes de ser usado aqui embaixo).
--
-- Chave de negócio: SC + Item/Sequência (nunca a SC sozinha, nunca a OC --
-- ver comentário da tabela). A importação faz insert ... on conflict do
-- update só das colunas vindas do Sapiens -- as colunas manuais
-- (quantidade_recebida, nf, observacao) nunca entram no "do update set",
-- então uma reimportação nunca consegue sobrescrevê-las, sem precisar de
-- nenhuma lógica extra de "preservar campo" no código.
-- ============================================================================

create table public.almoxarifado_itens (
  id                     bigint generated always as identity primary key,

  -- chave de negócio -- SC sozinha NÃO identifica um registro (uma SC tem
  -- vários itens); OC também não serve de chave (pode nem existir ainda na
  -- 1ª importação e aparecer só numa importação posterior).
  sc                     bigint not null,
  item_seq               integer not null,

  -- vindos do Sapiens a cada importação (sempre sobrescritos)
  pedido_bruto           text,                                -- texto cru do Sapiens, mesmo quando o link abaixo funciona
  pedido_id              bigint references public.pedidos(id), -- link com o pedido real do sistema, quando o número bate
  familia                text,
  oc                     text,
  data_prevista_entrega  date,
  codigo_produto         text,
  descricao              text,
  data_solicitacao       date,
  pc                     text,
  quantidade_solicitada  numeric(12,3) not null default 0 check (quantidade_solicitada >= 0),
  desenho                text,
  requisitante           text,
  situacao_oc            text,
  nf_sistema             text,
  fornecedor             text,

  -- controlados manualmente no Flow Suite -- uma reimportação NUNCA toca
  -- nessas 3 colunas (editar_recebimento_almoxarifado é o único caminho de
  -- escrita nelas)
  quantidade_recebida    numeric(12,3) not null default 0 check (quantidade_recebida >= 0),
  nf                     text,
  observacao             text,

  -- calculados pelo banco -- nunca vêm de importação nem de digitação manual
  quantidade_pendente    numeric(12,3) generated always as (greatest(0, quantidade_solicitada - quantidade_recebida)) stored,
  status_recebimento     text generated always as (
    case
      when quantidade_recebida <= 0 then 'pendente'
      when quantidade_solicitada - quantidade_recebida <= 0 then 'total'
      else 'parcial'
    end
  ) stored,

  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now(),
  ultima_importacao_em   timestamptz not null default now(),

  unique (sc, item_seq)
);

create index idx_almoxarifado_itens_pedido on public.almoxarifado_itens(pedido_id);
create index idx_almoxarifado_itens_status on public.almoxarifado_itens(status_recebimento);

comment on table public.almoxarifado_itens is
  'Um registro por (SC, Item) -- nunca duplica, reimportação atualiza campos do Sapiens e preserva os manuais (quantidade_recebida/nf/observacao).';

alter table public.almoxarifado_itens enable row level security;

create policy "almoxarifado_itens_select" on public.almoxarifado_itens
  for select to authenticated
  using (public.autenticado_ativo());

-- ── Importar (criar ou atualizar) itens vindos do Sapiens ───────────────────
-- p_itens = '[{"sc":10025,"item_seq":1,"pedido_bruto":"198","familia":"PAT",
--   "oc":"50080","data_prevista_entrega":"2026-06-01","codigo_produto":"...",
--   "descricao":"...","data_solicitacao":"2026-01-06","pc":"PC",
--   "quantidade_solicitada":1,"desenho":"...","requisitante":"...",
--   "situacao_oc":"...","nf_sistema":"...","fornecedor":"..."}, ...]'::jsonb
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
      pedido_bruto          = excluded.pedido_bruto,
      pedido_id             = excluded.pedido_id,
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
      nf_sistema             = excluded.nf_sistema,
      fornecedor             = excluded.fornecedor,
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

-- ── Editar os 3 campos manuais de um item já importado ──────────────────────
-- Único caminho de escrita em quantidade_recebida/nf/observacao -- não existe
-- policy de UPDATE direto na tabela (mesmo padrão de
-- editar_descricao_item_expedicao/053), então a reimportação nunca disputa
-- com a edição manual.
create or replace function public.editar_recebimento_almoxarifado(
  p_id bigint, p_quantidade_recebida numeric, p_nf text, p_observacao text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.meu_perfil() not in ('almoxarifado', 'admin') then
    raise exception 'Sem permissão para editar recebimento';
  end if;
  if p_quantidade_recebida is null or p_quantidade_recebida < 0 then
    raise exception 'Quantidade recebida inválida';
  end if;

  update public.almoxarifado_itens
  set quantidade_recebida = p_quantidade_recebida,
      nf          = nullif(trim(p_nf), ''),
      observacao  = nullif(trim(p_observacao), ''),
      updated_at  = now()
  where id = p_id;

  if not found then
    raise exception 'Item não encontrado';
  end if;
end;
$$;
