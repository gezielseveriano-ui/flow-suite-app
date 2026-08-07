-- ============================================================================
-- FactoryView -- Tags (cadastradas por pedido, pra distinguir unidades/destinos
-- idênticos dentro do mesmo pedido -- ex: dois transportadores iguais, um em
-- cada parte da obra) e classificação do desenho (fabricação/conhecimento/
-- compra), preenchidos na Engenharia ao subir o desenho.
-- ============================================================================

create table public.tags (
  id          bigint generated always as identity primary key,
  pedido_id   bigint not null references public.pedidos(id),
  nome        text not null,
  created_at  timestamptz not null default now(),
  created_by  uuid references public.perfis(id) default auth.uid(),
  unique (pedido_id, nome)
);

alter table public.tags enable row level security;

create policy "tags_select" on public.tags
  for select to authenticated
  using (public.autenticado_ativo());

create policy "tags_insert_pcp_admin" on public.tags
  for insert to authenticated
  with check (public.meu_perfil() in ('pcp', 'admin'));

create policy "tags_delete_pcp_admin" on public.tags
  for delete to authenticated
  using (public.meu_perfil() in ('pcp', 'admin'));

-- classificação do desenho + tag, escolhidos na Engenharia ao subir o arquivo
alter table public.desenhos_engenharia
  add column if not exists tag_id bigint references public.tags(id),
  add column if not exists is_fabricacao boolean not null default false,
  add column if not exists is_conhecimento boolean not null default false,
  add column if not exists is_compra boolean not null default false,
  add column if not exists observacao text;
