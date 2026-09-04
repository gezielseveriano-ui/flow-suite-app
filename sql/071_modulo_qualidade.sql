-- ============================================================================
-- FactoryView -- Módulo Qualidade: RNC (Relatório de Não Conformidade).
-- Substitui a planilha MG-008 "Gestão de Não Conformidades" -- aba "Controle
-- de RNCs" (lista) + aba "RNC" (documento gerado por RNC, um botão no
-- sistema gera o PDF equivalente) + aba "Indicador RNCs" (painel de KPI
-- mensal por empresa/origem, calculado no cliente a partir desta tabela).
--
-- Rodar DEPOIS de 070_perfil_qualidade.sql (precisa do perfil já existir no
-- enum antes de ser usado nas policies abaixo).
--
-- Numeração do RNC: sequencial, reinicia a cada ano (01/2026, 02/2026, ...,
-- 01/2027, ...) -- gerada por trigger, mesmo padrão de
-- gerar_numero_romaneio() (002_functions_triggers.sql): conta quantos RNCs
-- já existem no ano corrente e soma 1. Não é à prova de concorrência
-- (duas inserções no mesmíssimo instante poderiam colidir), mas é o mesmo
-- risco aceito pelo romaneio -- baixíssima chance neste sistema de poucos
-- usuários simultâneos.
--
-- Sem RPC de escrita: diferente do Almoxarifado (que precisa proteger campos
-- manuais de reimportação em massa), aqui não há importação nem concorrência
-- de escrita no mesmo registro -- então INSERT/UPDATE via policy direta,
-- igual ao padrão já usado em `pedidos` (003_rls_policies.sql) e
-- `pedidos_dados_comerciais` (045_pedidos_comerciais.sql).
-- ============================================================================

create table public.rnc (
  id                       bigint generated always as identity primary key,

  -- numeração -- gerada pelo trigger abaixo, nunca informada pelo cliente
  ano_rnc                  int,
  numero_rnc               int,

  empresa                  text not null check (empresa in ('MDE- ENGENHARIA S/A', 'MDE - EQUIPAMENTOS LTDA')),
  pedido_id                bigint references public.pedidos(id),
  fornecedor               text,
  tipo_desvio              text,
  responsavel_nc           text,

  ordem_compra             text,
  item_oc                  text,
  nota_fiscal              text,

  desenho                  text,
  revisao                  text,
  posicao                  text,
  especificacao_tecnica    text,

  item                     text,
  quantidade_inspecionada  numeric(12,3),
  quantidade_segregada     numeric(12,3),
  unidade_medida           text,

  especificado             text,
  encontrado               text,
  observacoes              text,

  local_nc                 text,
  emitido_por              text,
  data_abertura            date not null default current_date,

  causa                    text,
  origem_rnc               text check (origem_rnc in ('interno', 'fornecedor', 'cliente')),

  responsavel_disposicao   text,
  disposicao               text check (disposicao in ('aceitar_como_esta', 'retrabalhar', 'sucatear', 'devolver_fornecedor')),
  descricao_disposicao     text,
  prazo_execucao           date,

  verificacao_eficacia     text check (verificacao_eficacia in ('aprovado', 'reprovado')),
  data_verificacao         date,
  custo                    numeric(12,2),

  status_nc                text not null default 'em_aberto' check (status_nc in ('em_aberto', 'encerrado')),

  criado_por               uuid references public.perfis(id) default auth.uid(),
  criado_em                timestamptz not null default now(),
  atualizado_em            timestamptz not null default now(),

  unique (ano_rnc, numero_rnc)
);

create index idx_rnc_pedido on public.rnc(pedido_id);
create index idx_rnc_status on public.rnc(status_nc);
create index idx_rnc_ano on public.rnc(ano_rnc);

comment on table public.rnc is
  'Relatório de Não Conformidade -- substitui a aba "Controle de RNCs" da planilha MG-008. Um botão no sistema gera o documento (equivalente à aba "RNC") em PDF a partir de um registro.';

-- ── numeração automática, reinicia por ano ──────────────────────────────────
create or replace function public.gerar_numero_rnc()
returns trigger
language plpgsql
as $$
declare
  v_ano int;
  v_seq int;
begin
  if new.numero_rnc is not null then
    return new;
  end if;

  v_ano := extract(year from now())::int;

  select count(*) + 1 into v_seq
  from public.rnc where ano_rnc = v_ano;

  new.ano_rnc := v_ano;
  new.numero_rnc := v_seq;
  return new;
end;
$$;

create trigger trg_gerar_numero_rnc
before insert on public.rnc
for each row execute function public.gerar_numero_rnc();

create or replace function public.tocar_atualizado_em_rnc()
returns trigger
language plpgsql
as $$
begin
  new.atualizado_em := now();
  return new;
end;
$$;

create trigger trg_tocar_atualizado_em_rnc
before update on public.rnc
for each row execute function public.tocar_atualizado_em_rnc();

-- ── RLS ──────────────────────────────────────────────────────────────────
alter table public.rnc enable row level security;

create policy "rnc_select" on public.rnc
  for select to authenticated
  using (public.autenticado_ativo());

create policy "rnc_insert_qualidade_admin" on public.rnc
  for insert to authenticated
  with check (public.meu_perfil() in ('qualidade', 'admin'));

create policy "rnc_update_qualidade_admin" on public.rnc
  for update to authenticated
  using (public.meu_perfil() in ('qualidade', 'admin'))
  with check (public.meu_perfil() in ('qualidade', 'admin'));
