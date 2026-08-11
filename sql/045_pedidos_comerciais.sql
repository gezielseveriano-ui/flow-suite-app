-- ============================================================================
-- FactoryView -- Dados comerciais do pedido (Folha de Rosto / Confirmação de
-- Encomenda) + itens com valor, separados dos `itens` de fabricação (PCP).
-- A partir de agora o pedido nasce só no módulo Contratos -- tira 'pcp' do
-- insert em `pedidos` e adiciona 'contratos'. Update continua com pcp (ainda
-- edita data_reprogramada/observacao no dia a dia) + contratos.
-- ============================================================================

alter table public.pedidos add column if not exists contrato_id bigint references public.contratos(id);

create type public.natureza_operacao_enum as enum
  ('venda_produto', 'revenda', 'industrializacao_encomenda', 'venda_servico');

create type public.entrega_tipo_enum as enum ('CIF', 'FOT');

create table public.pedidos_dados_comerciais (
  id                       bigint generated always as identity primary key,
  pedido_id                bigint not null unique references public.pedidos(id) on delete cascade,
  titulo                   text,
  data_pedido              date not null default current_date,
  revisao                  text not null default '0',
  numero_proposta_mde      text,
  data_proposta            date,
  natureza_operacao        public.natureza_operacao_enum,
  objeto                   text,
  condicoes_pagamento      text,
  entrega_tipo             public.entrega_tipo_enum,
  prazo_entrega            text,
  data_entrega             date,
  transportadora           text,
  local_entrega            text,
  endereco_cobranca        text,
  classificacao_fiscal     text,
  impostos                 text,
  observacoes_importantes  text,
  created_at               timestamptz not null default now(),
  updated_at               timestamptz not null default now()
);

create table public.pedidos_itens_comerciais (
  id              bigint generated always as identity primary key,
  pedido_id       bigint not null references public.pedidos(id) on delete cascade,
  numero_item     int not null,
  tag             text,
  descricao       text not null,
  quantidade      numeric(12,3) not null default 1,
  valor_unitario  numeric(14,2) not null default 0,
  valor_total     numeric(16,2) generated always as (quantidade * valor_unitario) stored,
  created_at      timestamptz not null default now()
);

create index idx_pedidos_itens_comerciais_pedido on public.pedidos_itens_comerciais(pedido_id);

alter table public.pedidos_dados_comerciais enable row level security;
alter table public.pedidos_itens_comerciais enable row level security;

create policy "pedidos_dados_comerciais_select" on public.pedidos_dados_comerciais
  for select to authenticated
  using (public.autenticado_ativo());

create policy "pedidos_dados_comerciais_insert_contratos_admin" on public.pedidos_dados_comerciais
  for insert to authenticated
  with check (public.meu_perfil() in ('contratos', 'admin'));

create policy "pedidos_dados_comerciais_update_contratos_admin" on public.pedidos_dados_comerciais
  for update to authenticated
  using (public.meu_perfil() in ('contratos', 'admin'));

create policy "pedidos_itens_comerciais_select" on public.pedidos_itens_comerciais
  for select to authenticated
  using (public.autenticado_ativo());

create policy "pedidos_itens_comerciais_insert_contratos_admin" on public.pedidos_itens_comerciais
  for insert to authenticated
  with check (public.meu_perfil() in ('contratos', 'admin'));

create policy "pedidos_itens_comerciais_update_contratos_admin" on public.pedidos_itens_comerciais
  for update to authenticated
  using (public.meu_perfil() in ('contratos', 'admin'));

create policy "pedidos_itens_comerciais_delete_contratos_admin" on public.pedidos_itens_comerciais
  for delete to authenticated
  using (public.meu_perfil() in ('contratos', 'admin'));

-- pedido agora nasce só em Contratos
drop policy "pedidos_insert_pcp_admin" on public.pedidos;
create policy "pedidos_insert_contratos_admin" on public.pedidos
  for insert to authenticated
  with check (public.meu_perfil() in ('contratos', 'admin'));

drop policy "pedidos_update_pcp_admin" on public.pedidos;
create policy "pedidos_update_pcp_contratos_admin" on public.pedidos
  for update to authenticated
  using (public.meu_perfil() in ('pcp', 'contratos', 'admin'));
