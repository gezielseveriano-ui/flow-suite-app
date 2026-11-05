-- ============================================================================
-- FactoryView -- Qualidade: documentos anexados ao Controle de Desvio Cliente
-- (não conformidade enviada pelo cliente, fotos, relatórios...).
-- Arquivos no bucket privado "qualidade-docs"; vários por desvio.
-- Ver/baixar: todo autenticado. Anexar/remover: qualidade e admin (mesmo
-- perfil que edita o desvio no 077).
-- ============================================================================

insert into storage.buckets (id, name, public)
values ('qualidade-docs', 'qualidade-docs', false)
on conflict (id) do nothing;

create policy "qualidade_docs_storage_select" on storage.objects
  for select using (bucket_id = 'qualidade-docs' and public.autenticado_ativo());
create policy "qualidade_docs_storage_insert" on storage.objects
  for insert with check (bucket_id = 'qualidade-docs' and public.meu_perfil() in ('qualidade', 'admin'));
create policy "qualidade_docs_storage_delete" on storage.objects
  for delete using (bucket_id = 'qualidade-docs' and public.meu_perfil() in ('qualidade', 'admin'));

create table public.desvios_cliente_anexos (
  id            bigint generated always as identity primary key,
  desvio_id     bigint not null references public.desvios_cliente(id) on delete cascade,
  arquivo_path  text not null,
  arquivo_nome  text not null,
  enviado_por   uuid references public.perfis(id) default auth.uid(),
  enviado_em    timestamptz not null default now()
);

create index idx_desvios_cliente_anexos_desvio on public.desvios_cliente_anexos(desvio_id);

alter table public.desvios_cliente_anexos enable row level security;

create policy "desvios_cliente_anexos_select" on public.desvios_cliente_anexos
  for select to authenticated using (public.autenticado_ativo());
create policy "desvios_cliente_anexos_insert" on public.desvios_cliente_anexos
  for insert to authenticated with check (public.meu_perfil() in ('qualidade', 'admin'));
create policy "desvios_cliente_anexos_delete" on public.desvios_cliente_anexos
  for delete to authenticated using (public.meu_perfil() in ('qualidade', 'admin'));

-- desde 2026-10-30 o Supabase não dá mais grant automático em tabela nova
grant select, insert, delete on public.desvios_cliente_anexos to authenticated;
grant select, insert, update, delete on public.desvios_cliente_anexos to service_role;
