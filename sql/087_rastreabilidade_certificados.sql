-- ============================================================================
-- FactoryView -- Rastreabilidade de certificados de matéria-prima.
--
-- O almoxarife digita o nº do certificado na linha da NF do protocolo
-- (protocolos_nf_itens, sql/078): daí o sistema já sabe pedido, O.C., NF e
-- fornecedor. A Qualidade lê o PDF do certificado (programa local, porta
-- 8020) e o sistema casa o nº lido com o que foi digitado e completa usina,
-- material, bitola, norma e corrida. Os desenhos em que o material foi usado
-- a Qualidade informa na aba Rastreabilidade.
--
-- Uma NF pode ter vários certificados; um certificado vale para uma NF só.
-- O PDF fica na pasta do OneDrive (só o nome do arquivo vem para cá).
-- Almoxarifado, Logística, Qualidade e Admin lançam e corrigem.
-- ============================================================================

create table public.certificados_mp (
  id                bigint generated always as identity primary key,
  numero            text not null,                 -- nº do certificado (como a usina escreve)
  -- vem da linha do protocolo (preenchido pelo sistema)
  protocolo_item_id bigint references public.protocolos_nf_itens(id) on delete set null,
  oc                text,
  nf                text,
  pedido            text,
  fornecedor        text,                           -- distribuidor que vendeu
  -- vem da leitura do PDF (programa local)
  usina             text,
  produto           text,
  norma             text,
  bitola            text,
  corrida           text,
  data_cert         date,
  -- preenchido pela Qualidade
  desenhos          text,
  observacao        text,
  arquivo           text,                           -- nome do PDF na pasta de certificados
  leitura_status    text not null default 'pendente' check (leitura_status in ('pendente', 'lido', 'conferir')),
  lido_em           timestamptz,
  criado_por        uuid references public.perfis(id) default auth.uid(),
  criado_em         timestamptz not null default now()
);

-- o mesmo nº não entra duas vezes na mesma NF
create unique index uq_certificados_mp_numero_nf on public.certificados_mp (lower(trim(numero)), coalesce(nf, ''));
create index idx_certificados_mp_protocolo_item on public.certificados_mp (protocolo_item_id);
create index idx_certificados_mp_pedido on public.certificados_mp (pedido);

alter table public.certificados_mp enable row level security;

create policy "certificados_mp_select" on public.certificados_mp
  for select to authenticated using (public.autenticado_ativo());
create policy "certificados_mp_insert" on public.certificados_mp
  for insert to authenticated
  with check (public.meu_perfil() in ('almoxarifado', 'logistica', 'qualidade', 'admin'));
create policy "certificados_mp_update" on public.certificados_mp
  for update to authenticated
  using (public.meu_perfil() in ('almoxarifado', 'logistica', 'qualidade', 'admin'))
  with check (public.meu_perfil() in ('almoxarifado', 'logistica', 'qualidade', 'admin'));
create policy "certificados_mp_delete" on public.certificados_mp
  for delete to authenticated
  using (public.meu_perfil() in ('almoxarifado', 'logistica', 'qualidade', 'admin'));

-- desde 2026-10-30 o Supabase não dá mais grant automático em tabela nova
grant select, insert, update, delete on public.certificados_mp to authenticated;
grant select, insert, update, delete on public.certificados_mp to service_role;
