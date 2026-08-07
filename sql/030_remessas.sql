-- ============================================================================
-- FactoryView -- Remessas (organização dos desenhos que a Engenharia sobe,
-- igual à pasta "CONTROLE DE REMESSAS / REMESSA N" que já existe hoje no
-- arquivo real da empresa). Um pedido tem várias remessas; uma remessa tem
-- vários desenhos. numero é sequencial por pedido (Remessa 1, 2, 3...).
-- ============================================================================

create table public.remessas (
  id                bigint generated always as identity primary key,
  pedido_id         bigint not null references public.pedidos(id),
  numero            integer not null,
  created_at        timestamptz not null default now(),
  created_by        uuid references public.perfis(id) default auth.uid(),
  enviada_email_em  timestamptz,
  unique (pedido_id, numero)
);

create index idx_remessas_pedido on public.remessas(pedido_id);

alter table public.remessas enable row level security;

create policy "remessas_select" on public.remessas
  for select to authenticated
  using (public.autenticado_ativo());

create policy "remessas_insert_engenharia_admin" on public.remessas
  for insert to authenticated
  with check (public.meu_perfil() in ('engenharia', 'admin'));

create policy "remessas_update_engenharia_admin" on public.remessas
  for update to authenticated
  using (public.meu_perfil() in ('engenharia', 'admin'));

-- vincula cada desenho à remessa em que foi cadastrado (nível 3 da navegação
-- da Engenharia). O campo "remessa" (texto) já existente é mantido em
-- sincronia com remessas.numero, pra não quebrar itens.remessa (usado na
-- expedição/dashboard) nem a lógica de sincronizarItensPCP no cadastro.html.
alter table public.desenhos_engenharia
  add column if not exists remessa_id bigint references public.remessas(id);

create index if not exists idx_desenhos_engenharia_remessa on public.desenhos_engenharia(remessa_id);

-- ── CORREÇÃO: o perfil "engenharia" foi criado depois destas políticas
-- (migration 029), que ainda só liberavam 'pcp'/'admin'. Sem este ajuste,
-- um usuário de verdade com perfil='engenharia' (não-admin) teria o upload
-- de desenho bloqueado pelo RLS.
alter policy "desenhos_engenharia_insert" on public.desenhos_engenharia
  with check (public.meu_perfil() in ('engenharia', 'pcp', 'admin'));

alter policy "desenhos_engenharia_update" on public.desenhos_engenharia
  using (public.meu_perfil() in ('engenharia', 'pcp', 'admin'));

alter policy "desenhos_engenharia_delete" on public.desenhos_engenharia
  using (public.meu_perfil() in ('engenharia', 'pcp', 'admin'));

alter policy "desenhos_storage_insert" on storage.objects
  with check (bucket_id = 'desenhos' and public.meu_perfil() in ('engenharia', 'pcp', 'admin'));

alter policy "tags_insert_pcp_admin" on public.tags
  with check (public.meu_perfil() in ('engenharia', 'pcp', 'admin'));
