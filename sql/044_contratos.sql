-- ============================================================================
-- FactoryView -- Módulo Contratos. Um contrato agrupa os dados do cliente
-- (CNPJ, endereço, etc.) e o número/data do contrato assinado -- um cliente
-- pode ter vários Pedidos sob o mesmo contrato ao longo do tempo (ver
-- 045_pedidos_comerciais.sql pra onde o Pedido em si é criado).
-- ============================================================================

create table public.contratos (
  id                 bigint generated always as identity primary key,
  cliente            text not null,
  cnpj               text,
  inscricao_estadual text,
  endereco           text,
  municipio          text,
  cep                text,
  telefone           text,
  email              text,
  comprador          text,
  numero_contrato    text,
  data_contrato      date,
  ativo              boolean not null default true,
  created_at         timestamptz not null default now(),
  created_by         uuid references public.perfis(id) default auth.uid()
);

alter table public.contratos enable row level security;

create policy "contratos_select" on public.contratos
  for select to authenticated
  using (public.autenticado_ativo());

create policy "contratos_insert_contratos_admin" on public.contratos
  for insert to authenticated
  with check (public.meu_perfil() in ('contratos', 'admin'));

create policy "contratos_update_contratos_admin" on public.contratos
  for update to authenticated
  using (public.meu_perfil() in ('contratos', 'admin'));

create policy "contratos_delete_admin" on public.contratos
  for delete to authenticated
  using (public.meu_perfil() = 'admin');
