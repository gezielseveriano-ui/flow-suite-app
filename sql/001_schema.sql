-- ============================================================================
-- FactoryView — Schema inicial
-- Ordem de aplicação: rodar este arquivo inteiro de uma vez no SQL Editor
-- do Supabase (Project > SQL Editor > New query).
-- ============================================================================

-- ── ENUMS ───────────────────────────────────────────────────────────────────

create type public.perfil_usuario as enum (
  'admin', 'pcp', 'producao', 'expedicao', 'gestao'
);

create type public.setor_producao as enum (
  'ESTRUTURA', 'USINAGEM', 'TAMBOR', 'ROLOS', 'BASES ROLETES',
  'REVESTIMENTO', 'RMF', 'TECMETAL', 'CSM', 'COMERCIAL'
);

-- ordem fixa das 9 etapas — a ordem de declaração do enum é a ordem de exibição
create type public.etapa_producao as enum (
  'materia_prima', 'relatorio', 'preparacao', 'caldeiraria',
  'solda', 'acabamento', 'pronto_acabado', 'expedicao', 'finalizado'
);

create type public.status_expedicao_enum as enum ('pendente', 'expedido');

-- ── PERFIS (ligado ao auth.users nativo do Supabase) ───────────────────────
-- Login/senha ficam no auth.users, cuidado do próprio Supabase Auth.
-- Esta tabela só guarda nome + perfil de acesso de cada usuário.

create table public.perfis (
  id         uuid primary key references auth.users(id) on delete cascade,
  nome       text not null,
  perfil     public.perfil_usuario not null,
  ativo      boolean not null default true,
  created_at timestamptz not null default now()
);

comment on table public.perfis is 'Perfil de acesso de cada usuário. Cadastro manual via Supabase Auth + insert aqui.';

-- ── PEDIDOS ─────────────────────────────────────────────────────────────────

create table public.pedidos (
  id                 bigint generated always as identity primary key,
  numero_pedido      text not null unique,
  cliente            text,
  equipamento        text,
  data_prevista      date,
  data_reprogramada  date,
  observacao         text,
  created_at         timestamptz not null default now(),
  created_by         uuid references public.perfis(id) default auth.uid()
);

-- ── ROMANEIOS ───────────────────────────────────────────────────────────────
-- Criado antes de `itens` porque itens.romaneio_id referencia esta tabela.
-- numero é gerado automaticamente por trigger (ver 002_functions_triggers.sql)

create table public.romaneios (
  id           bigint generated always as identity primary key,
  numero       text unique,
  pedido_id    bigint not null references public.pedidos(id),
  data_criacao timestamptz not null default now(),
  usuario_id   uuid references public.perfis(id) default auth.uid()
);

-- ── ITENS (equivalente à antiga aba MICRO) ─────────────────────────────────

-- sequência do código MDE — continua de onde a planilha atual parou (max = 4394)
create sequence public.seq_codigo_mde start with 4395 increment by 1;

create table public.itens (
  id                bigint generated always as identity primary key,
  codigo_mde        bigint not null unique default nextval('public.seq_codigo_mde'),
  desenho           text,
  descricao         text,
  tag               text,
  produto           public.setor_producao not null,
  pedido_id         bigint not null references public.pedidos(id),
  peso_unitario     numeric(12,3) not null default 0 check (peso_unitario >= 0),
  quantidade        numeric(12,3) not null default 0 check (quantidade >= 0),
  peso_total        numeric(14,3) generated always as (peso_unitario * quantidade) stored,
  fornecedor        text,
  revisao           text,
  data_engenharia   date,
  status_expedicao  public.status_expedicao_enum not null default 'pendente',
  romaneio_id       bigint references public.romaneios(id),
  created_at        timestamptz not null default now(),
  created_by        uuid references public.perfis(id) default auth.uid()
);

create index idx_itens_pedido on public.itens(pedido_id);
create index idx_itens_produto on public.itens(produto);
create index idx_itens_desenho on public.itens(desenho);
create index idx_itens_romaneio on public.itens(romaneio_id);

-- ── ETAPAS DE AVANÇO (histórico auditável, nunca sobrescrito) ──────────────

create table public.etapas_avanco (
  id          bigint generated always as identity primary key,
  item_id     bigint not null references public.itens(id),
  etapa       public.etapa_producao not null,
  percentual  numeric(5,2) not null check (percentual >= 0 and percentual <= 100),
  usuario_id  uuid references public.perfis(id) default auth.uid(),
  data_hora   timestamptz not null default now()
);

create index idx_etapas_item_etapa on public.etapas_avanco(item_id, etapa, data_hora desc);

-- ── CAPACIDADE POR SETOR ────────────────────────────────────────────────────

create table public.capacidade_setor (
  id                     bigint generated always as identity primary key,
  setor                  public.setor_producao not null unique,
  capacidade_mensal_ton  numeric(12,3) not null default 0 check (capacidade_mensal_ton >= 0)
);
