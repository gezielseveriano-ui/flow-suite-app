-- ============================================================================
-- FactoryView — Row Level Security (permissões por perfil)
-- Rodar depois do 002_functions_triggers.sql
--
-- Resumo de acesso:
--   admin      -> tudo
--   pcp        -> cadastra pedidos e itens; lê tudo
--   producao   -> lê itens/pedidos; lança etapas_avanco
--   expedicao  -> lê itens/pedidos; gera romaneios (via RPC criar_romaneio)
--   gestao     -> só leitura em tudo
-- ============================================================================

alter table public.perfis            enable row level security;
alter table public.pedidos           enable row level security;
alter table public.romaneios         enable row level security;
alter table public.itens             enable row level security;
alter table public.etapas_avanco     enable row level security;
alter table public.capacidade_setor  enable row level security;

-- ── perfis ───────────────────────────────────────────────────────────────
create policy "perfis_select_own_or_admin" on public.perfis
  for select to authenticated
  using (id = auth.uid() or public.meu_perfil() = 'admin');

create policy "perfis_admin_all" on public.perfis
  for all to authenticated
  using (public.meu_perfil() = 'admin')
  with check (public.meu_perfil() = 'admin');

-- ── pedidos ──────────────────────────────────────────────────────────────
create policy "pedidos_select" on public.pedidos
  for select to authenticated
  using (public.autenticado_ativo());

create policy "pedidos_insert_pcp_admin" on public.pedidos
  for insert to authenticated
  with check (public.meu_perfil() in ('pcp', 'admin'));

create policy "pedidos_update_pcp_admin" on public.pedidos
  for update to authenticated
  using (public.meu_perfil() in ('pcp', 'admin'));

-- ── itens ────────────────────────────────────────────────────────────────
create policy "itens_select" on public.itens
  for select to authenticated
  using (public.autenticado_ativo());

create policy "itens_insert_pcp_admin" on public.itens
  for insert to authenticated
  with check (public.meu_perfil() in ('pcp', 'admin'));

create policy "itens_update_pcp_admin" on public.itens
  for update to authenticated
  using (public.meu_perfil() in ('pcp', 'admin'));
-- Observação: a mudança de status_expedicao/romaneio_id na expedição acontece
-- pela função criar_romaneio (security definer), que já valida o perfil
-- internamente — não precisa de policy de update para o perfil expedicao.

-- ── etapas_avanco ────────────────────────────────────────────────────────
create policy "etapas_select" on public.etapas_avanco
  for select to authenticated
  using (public.autenticado_ativo());

create policy "etapas_insert_producao_admin" on public.etapas_avanco
  for insert to authenticated
  with check (
    public.meu_perfil() in ('producao', 'admin')
    and usuario_id = auth.uid()
  );
-- Sem policy de update/delete: histórico é imutável (auditoria).

-- ── capacidade_setor ─────────────────────────────────────────────────────
create policy "capacidade_select" on public.capacidade_setor
  for select to authenticated
  using (public.autenticado_ativo());

create policy "capacidade_admin_all" on public.capacidade_setor
  for all to authenticated
  using (public.meu_perfil() = 'admin')
  with check (public.meu_perfil() = 'admin');

-- ── romaneios ────────────────────────────────────────────────────────────
create policy "romaneios_select" on public.romaneios
  for select to authenticated
  using (public.autenticado_ativo());

create policy "romaneios_insert_expedicao_admin" on public.romaneios
  for insert to authenticated
  with check (public.meu_perfil() in ('expedicao', 'admin'));
-- Geração normal acontece via RPC criar_romaneio (security definer),
-- esta policy cobre o caso de insert direto pela mesma pessoa autorizada.
