-- ============================================================================
-- FactoryView -- Engenharia: subprodutos dentro de cada posição (os itens que
-- compõem o conjunto: chapa, perfil, pino...), lidos da lista de material do
-- desenho. Guardados à parte porque às vezes a expedição precisa enviar um
-- item avulso (ex: só a chapa de desgaste, só o pino) em vez da posição
-- inteira montada.
-- ============================================================================

create table public.desenhos_engenharia_subprodutos (
  id             bigint generated always as identity primary key,
  posicao_id     bigint not null references public.desenhos_engenharia_posicoes(id) on delete cascade,
  item           text,
  descricao      text,
  material       text,
  quantidade     numeric(12,3),
  peso_unitario  numeric(12,3),
  peso_total     numeric(12,3),
  created_at     timestamptz not null default now()
);

create index idx_desenhos_engenharia_subprodutos_posicao on public.desenhos_engenharia_subprodutos(posicao_id);

alter table public.desenhos_engenharia_subprodutos enable row level security;

create policy "desenhos_engenharia_subprodutos_select" on public.desenhos_engenharia_subprodutos
  for select using (public.autenticado_ativo());

create policy "desenhos_engenharia_subprodutos_insert" on public.desenhos_engenharia_subprodutos
  for insert with check (public.meu_perfil() in ('pcp', 'admin'));

create policy "desenhos_engenharia_subprodutos_update" on public.desenhos_engenharia_subprodutos
  for update using (public.meu_perfil() in ('pcp', 'admin'));

create policy "desenhos_engenharia_subprodutos_delete" on public.desenhos_engenharia_subprodutos
  for delete using (public.meu_perfil() in ('pcp', 'admin'));
