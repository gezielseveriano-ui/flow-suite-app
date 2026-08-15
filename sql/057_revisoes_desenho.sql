-- ============================================================================
-- FactoryView -- Pedido de revisão de desenho: supervisor (perfil 'producao')
-- ou PCP pedem pra Engenharia revisar um desenho, com uma observação
-- explicando o motivo. Fica visível pra todo mundo (select aberto, igual o
-- sininho de desenhos paralisados) até a Engenharia responder -- nunca some
-- sozinho, só quando alguém de Engenharia/admin marca como respondida.
-- ============================================================================

-- Postgres não deixa usar subquery direta em "default" de coluna -- por isso
-- essa função pequena (o default chama a função, que aí sim pode ter subquery).
create or replace function public.meu_nome()
returns text
language sql
stable
as $$
  select nome from public.perfis where id = auth.uid();
$$;

create table public.revisoes_desenho (
  id                  bigint generated always as identity primary key,
  desenho_id          bigint not null references public.desenhos_engenharia(id),
  item_id             bigint references public.itens(id),
  observacao          text not null,
  solicitado_por      uuid references public.perfis(id) default auth.uid(),
  solicitado_por_nome text default public.meu_nome(),
  solicitado_em       timestamptz not null default now(),
  respondido          boolean not null default false,
  resposta            text,
  respondido_por_nome text,
  respondido_em       timestamptz
);

create index idx_revisoes_desenho_desenho on public.revisoes_desenho(desenho_id);
create index idx_revisoes_desenho_respondido on public.revisoes_desenho(respondido);

alter table public.revisoes_desenho enable row level security;

create policy "revisoes_desenho_select" on public.revisoes_desenho
  for select to authenticated
  using (public.autenticado_ativo());

create policy "revisoes_desenho_insert" on public.revisoes_desenho
  for insert to authenticated
  with check (public.meu_perfil() in ('producao', 'pcp', 'admin'));

create policy "revisoes_desenho_update" on public.revisoes_desenho
  for update to authenticated
  using (public.meu_perfil() in ('engenharia', 'admin'));
