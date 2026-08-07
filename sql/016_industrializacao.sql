-- ============================================================================
-- FactoryView -- Módulo de Industrialização: itens enviados a fornecedores
-- terceiros para concluir um serviço (ex: revestimento) ou para aliviar
-- capacidade quando a MDE está no limite. Gera uma LI (Lista de
-- Industrialização), documento irmão da LE mas endereçado a um fornecedor
-- em vez de um cliente. É um registro à parte: não mexe em status_expedicao
-- nem em etapas_avanco — qualquer item cadastrado pode ser selecionado,
-- sem restrição de status.
-- ============================================================================

-- ── FORNECEDORES ────────────────────────────────────────────────────────────

create table public.fornecedores (
  id                 bigint generated always as identity primary key,
  razao_social       text not null,
  endereco           text,
  cep                text,
  cidade             text,
  uf                 text,
  cnpj               text,
  inscricao_estadual text,
  telefone           text,
  ativo              boolean not null default true,
  created_at         timestamptz not null default now(),
  created_by         uuid references public.perfis(id) default auth.uid()
);

comment on table public.fornecedores is 'Fornecedores terceiros usados no módulo de Industrialização (destinatário da LI).';

alter table public.fornecedores enable row level security;

create policy "fornecedores_select" on public.fornecedores
  for select using (public.autenticado_ativo());

create policy "fornecedores_insert" on public.fornecedores
  for insert with check (public.meu_perfil() in ('pcp', 'expedicao', 'admin'));

create policy "fornecedores_update" on public.fornecedores
  for update using (public.meu_perfil() in ('pcp', 'expedicao', 'admin'));

create policy "fornecedores_delete" on public.fornecedores
  for delete using (public.meu_perfil() = 'admin');

-- ── INDUSTRIALIZAÇÕES (cabeçalho da LI) ─────────────────────────────────────

create table public.industrializacoes (
  id                   bigint generated always as identity primary key,
  numero               text unique,
  pedido_id            bigint not null references public.pedidos(id),
  fornecedor_id        bigint not null references public.fornecedores(id),
  natureza_operacao    text,
  oc                   text,
  data_criacao         timestamptz not null default now(),
  usuario_id           uuid references public.perfis(id) default auth.uid()
);

alter table public.industrializacoes enable row level security;

create policy "industrializacoes_select" on public.industrializacoes
  for select using (public.autenticado_ativo());

create policy "industrializacoes_insert" on public.industrializacoes
  for insert with check (public.meu_perfil() in ('pcp', 'expedicao', 'admin'));

create policy "industrializacoes_delete" on public.industrializacoes
  for delete using (public.meu_perfil() in ('pcp', 'expedicao', 'admin'));

-- numeração "LI 001, LI 002..." sequencial por pedido (mesmo padrão da LE)
create or replace function public.gerar_numero_industrializacao()
returns trigger
language plpgsql
as $$
declare
  v_seq int;
begin
  if new.numero is not null then
    return new;
  end if;

  select count(*) + 1 into v_seq
  from public.industrializacoes where pedido_id = new.pedido_id;

  new.numero := 'LI ' || lpad(v_seq::text, 3, '0');
  return new;
end;
$$;

create trigger trg_gerar_numero_industrializacao
before insert on public.industrializacoes
for each row execute function public.gerar_numero_industrializacao();

-- ── ITENS DA LI ──────────────────────────────────────────────────────────

create table public.industrializacao_itens (
  id                  bigint generated always as identity primary key,
  industrializacao_id bigint not null references public.industrializacoes(id) on delete cascade,
  item_id             bigint not null references public.itens(id),
  quantidade          numeric(12,3) not null check (quantidade > 0),
  peso_unitario       numeric(12,3) not null default 0,
  peso_total          numeric(14,3) generated always as (peso_unitario * quantidade) stored,
  valor_unitario      numeric(12,2) not null default 0,
  valor_total         numeric(14,2) generated always as (valor_unitario * quantidade) stored
);

create index idx_industrializacao_itens_li on public.industrializacao_itens(industrializacao_id);
create index idx_industrializacao_itens_item on public.industrializacao_itens(item_id);

alter table public.industrializacao_itens enable row level security;

create policy "industrializacao_itens_select" on public.industrializacao_itens
  for select using (public.autenticado_ativo());

create policy "industrializacao_itens_insert" on public.industrializacao_itens
  for insert with check (public.meu_perfil() in ('pcp', 'expedicao', 'admin'));

create policy "industrializacao_itens_delete" on public.industrializacao_itens
  for delete using (public.meu_perfil() in ('pcp', 'expedicao', 'admin'));

-- ── RPC: criar a LI com todos os itens de uma vez ───────────────────────────
-- p_itens = '[{"item_id": 123, "quantidade": 2, "valor_unitario": 4.50}, ...]'::jsonb
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
  if public.meu_perfil() not in ('pcp', 'expedicao', 'admin') then
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
