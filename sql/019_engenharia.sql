-- ============================================================================
-- FactoryView -- Módulo de Engenharia (ÁREA DE TESTE, separada do Cadastro/PCP
-- de propósito, pra não mexer em nada que já está aprovado). A engenharia
-- (outra cidade) sobe o arquivo do desenho (DWG) e lança as informações
-- básicas dele: número do desenho MDE, número do desenho do cliente, revisão,
-- e as posições do desenho (A, B, ...) com peso unitário/total cada uma.
-- Ainda não lança lista de material completa — só a lógica base, pra testar
-- com pedidos reais antes de decidir a modelagem final.
-- ============================================================================

-- ── DESENHOS (cabeçalho) ────────────────────────────────────────────────────

create table public.desenhos_engenharia (
  id              bigint generated always as identity primary key,
  codigo_mde      bigint not null unique default nextval('public.seq_codigo_mde'),
  desenho_mde     text not null,
  desenho_cliente text,
  revisao         text,
  pedido_id       bigint references public.pedidos(id),
  arquivo_nome    text,
  arquivo_path    text,
  created_at      timestamptz not null default now(),
  created_by      uuid references public.perfis(id) default auth.uid()
);

create index idx_desenhos_engenharia_pedido on public.desenhos_engenharia(pedido_id);
create index idx_desenhos_engenharia_desenho on public.desenhos_engenharia(desenho_mde);

alter table public.desenhos_engenharia enable row level security;

create policy "desenhos_engenharia_select" on public.desenhos_engenharia
  for select using (public.autenticado_ativo());

create policy "desenhos_engenharia_insert" on public.desenhos_engenharia
  for insert with check (public.meu_perfil() in ('pcp', 'admin'));

create policy "desenhos_engenharia_update" on public.desenhos_engenharia
  for update using (public.meu_perfil() in ('pcp', 'admin'));

create policy "desenhos_engenharia_delete" on public.desenhos_engenharia
  for delete using (public.meu_perfil() in ('pcp', 'admin'));

-- ── POSIÇÕES DO DESENHO (A, B, C...) ────────────────────────────────────────

create table public.desenhos_engenharia_posicoes (
  id             bigint generated always as identity primary key,
  desenho_id     bigint not null references public.desenhos_engenharia(id) on delete cascade,
  posicao        text not null,
  peso_unitario  numeric(12,3),
  peso_total     numeric(12,3),
  remessa        text default '1',
  created_at     timestamptz not null default now()
);

create index idx_desenhos_engenharia_posicoes_desenho on public.desenhos_engenharia_posicoes(desenho_id);

alter table public.desenhos_engenharia_posicoes enable row level security;

create policy "desenhos_engenharia_posicoes_select" on public.desenhos_engenharia_posicoes
  for select using (public.autenticado_ativo());

create policy "desenhos_engenharia_posicoes_insert" on public.desenhos_engenharia_posicoes
  for insert with check (public.meu_perfil() in ('pcp', 'admin'));

create policy "desenhos_engenharia_posicoes_update" on public.desenhos_engenharia_posicoes
  for update using (public.meu_perfil() in ('pcp', 'admin'));

create policy "desenhos_engenharia_posicoes_delete" on public.desenhos_engenharia_posicoes
  for delete using (public.meu_perfil() in ('pcp', 'admin'));

-- ── STORAGE: bucket para os arquivos de desenho (DWG/PDF/DXF) ──────────────
-- privado (não público) — só quem está logado no sistema acessa.

insert into storage.buckets (id, name, public)
values ('desenhos', 'desenhos', false)
on conflict (id) do nothing;

create policy "desenhos_storage_select" on storage.objects
  for select using (bucket_id = 'desenhos' and public.autenticado_ativo());

create policy "desenhos_storage_insert" on storage.objects
  for insert with check (bucket_id = 'desenhos' and public.meu_perfil() in ('pcp', 'admin'));

create policy "desenhos_storage_delete" on storage.objects
  for delete using (bucket_id = 'desenhos' and public.meu_perfil() in ('pcp', 'admin'));
