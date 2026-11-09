-- ============================================================================
-- FactoryView -- Almoxarifado: cobrança de certificado de matéria-prima.
--
-- O que é marcado "PENDENTE" no protocolo de NF (protocolos_nf_itens,
-- sql/078) vira uma pendência por fornecedor. O fornecedor é cadastrado com
-- o e-mail; o botão "Cobrar" abre o e-mail pronto (Outlook) e registra a
-- cobrança aqui. Passou do prazo (3 dias) sem chegar -> cobra de novo.
-- Quando o certificado chega, a linha vira OK e o trigger grava a data --
-- é daí que sai a contagem de quantos dias cada fornecedor demorou.
--
-- Almoxarifado, Logística, Qualidade e Admin cobram e dão baixa.
-- ============================================================================

-- quando o certificado chegou (preenchido sozinho quando vira OK)
alter table public.protocolos_nf_itens add column certificado_recebido_em timestamptz;

create or replace function public.marcar_certificado_recebido()
returns trigger
language plpgsql
as $$
begin
  if new.certificado = 'ok' and old.certificado is distinct from 'ok' then
    new.certificado_recebido_em := now();
  elsif new.certificado <> 'ok' then
    new.certificado_recebido_em := null;
  end if;
  return new;
end;
$$;

create trigger trg_marcar_certificado_recebido
before update of certificado on public.protocolos_nf_itens
for each row execute function public.marcar_certificado_recebido();

-- a Qualidade também dá baixa no certificado que chegou
drop policy "protocolos_nf_itens_update_almox" on public.protocolos_nf_itens;
create policy "protocolos_nf_itens_update_almox" on public.protocolos_nf_itens
  for update to authenticated
  using (public.meu_perfil() in ('almoxarifado', 'logistica', 'qualidade', 'admin'))
  with check (public.meu_perfil() in ('almoxarifado', 'logistica', 'qualidade', 'admin'));

create table public.cert_fornecedores (
  id            bigint generated always as identity primary key,
  nome          text not null unique,
  -- como o nome aparece nas O.C./NF (o Sapiens corta em 20 letras e às vezes
  -- vem escrito diferente) -- é por aqui que a pendência acha o fornecedor
  apelidos      text[] not null default '{}',
  email_para    text not null,          -- um ou mais, separados por ;
  email_cc      text,                   -- cópia só deste fornecedor (vendedor etc.)
  contato       text,
  ativo         boolean not null default true,
  criado_por    uuid references public.perfis(id) default auth.uid(),
  criado_em     timestamptz not null default now()
);

create table public.cert_cobrancas (
  id                bigint generated always as identity primary key,
  fornecedor_id     bigint references public.cert_fornecedores(id) on delete set null,
  fornecedor_nome   text not null,
  itens             bigint[] not null,  -- protocolos_nf_itens.id cobrados neste e-mail
  sequencia         int not null default 1,   -- 1ª, 2ª, 3ª cobrança...
  para              text,
  cc                text,
  assunto           text,
  enviado_por       uuid references public.perfis(id) default auth.uid(),
  enviado_por_nome  text,
  enviado_em        timestamptz not null default now()
);

create index idx_cert_cobrancas_fornecedor on public.cert_cobrancas(fornecedor_id);

-- uma linha só: quem vai sempre em cópia e o prazo pra cobrar de novo
create table public.cert_cobranca_config (
  id          int primary key default 1 check (id = 1),
  cc_padrao   text,
  prazo_dias  int not null default 3 check (prazo_dias between 1 and 30)
);
insert into public.cert_cobranca_config (id) values (1);

alter table public.cert_fornecedores enable row level security;
alter table public.cert_cobrancas enable row level security;
alter table public.cert_cobranca_config enable row level security;

create policy "cert_fornecedores_select" on public.cert_fornecedores for select to authenticated using (public.autenticado_ativo());
create policy "cert_fornecedores_insert" on public.cert_fornecedores for insert to authenticated with check (public.meu_perfil() in ('almoxarifado', 'logistica', 'qualidade', 'admin'));
create policy "cert_fornecedores_update" on public.cert_fornecedores for update to authenticated using (public.meu_perfil() in ('almoxarifado', 'logistica', 'qualidade', 'admin')) with check (public.meu_perfil() in ('almoxarifado', 'logistica', 'qualidade', 'admin'));
create policy "cert_fornecedores_delete" on public.cert_fornecedores for delete to authenticated using (public.meu_perfil() in ('almoxarifado', 'logistica', 'qualidade', 'admin'));

create policy "cert_cobrancas_select" on public.cert_cobrancas for select to authenticated using (public.autenticado_ativo());
create policy "cert_cobrancas_insert" on public.cert_cobrancas for insert to authenticated with check (public.meu_perfil() in ('almoxarifado', 'logistica', 'qualidade', 'admin'));
create policy "cert_cobrancas_delete" on public.cert_cobrancas for delete to authenticated using (public.meu_perfil() in ('almoxarifado', 'logistica', 'qualidade', 'admin'));

create policy "cert_cobranca_config_select" on public.cert_cobranca_config for select to authenticated using (public.autenticado_ativo());
create policy "cert_cobranca_config_update" on public.cert_cobranca_config for update to authenticated using (public.meu_perfil() in ('almoxarifado', 'logistica', 'qualidade', 'admin')) with check (public.meu_perfil() in ('almoxarifado', 'logistica', 'qualidade', 'admin'));

-- desde 2026-10-30 o Supabase não dá mais grant automático em tabela nova
grant select, insert, update, delete on public.cert_fornecedores to authenticated;
grant select, insert, delete on public.cert_cobrancas to authenticated;
grant select, update on public.cert_cobranca_config to authenticated;
grant select, insert, update, delete on public.cert_fornecedores, public.cert_cobrancas, public.cert_cobranca_config to service_role;
