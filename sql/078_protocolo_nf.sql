-- ============================================================================
-- FactoryView -- Almoxarifado: Protocolo de entrega de NF (Financeiro/Qualidade).
-- Substitui a planilha "PROTOCOLO - CERTIFICADOS".
--
-- Um protocolo = um CNPJ da MDE + várias linhas O.C./NF. As linhas vêm do que
-- o almoxarife já lançou em almoxarifado_itens (oc + nf + data_recebimento_nf
-- + fornecedor), agrupado por O.C./NF -- não por item.
-- Cada par O.C./NF só pode entrar em UM protocolo (índice único).
-- Numeração sequencial separada por CNPJ (cada CNPJ tinha sua planilha).
-- Criação pelo RPC criar_protocolo_nf (numera com lock, grava tudo junto).
-- ============================================================================

create table public.protocolos_nf (
  id            bigint generated always as identity primary key,
  cnpj          text not null check (cnpj in ('01.276.159/0001-04', '04.999.654/0001-21')),
  numero        int not null,
  data          date not null default current_date,
  observacao    text,
  criado_por    uuid references public.perfis(id) default auth.uid(),
  criado_em     timestamptz not null default now(),
  unique (cnpj, numero)
);

create table public.protocolos_nf_itens (
  id            bigint generated always as identity primary key,
  protocolo_id  bigint not null references public.protocolos_nf(id) on delete cascade,
  oc            text,
  nf            text not null,
  fornecedor    text,
  data_nf       date,
  pedido        text,
  certificado   text not null default 'na' check (certificado in ('ok', 'na', 'pendente'))
);

create index idx_protocolos_nf_itens_protocolo on public.protocolos_nf_itens(protocolo_id);
create unique index uq_protocolos_nf_itens_oc_nf on public.protocolos_nf_itens(coalesce(oc, ''), nf);

alter table public.protocolos_nf enable row level security;
alter table public.protocolos_nf_itens enable row level security;

create policy "protocolos_nf_select" on public.protocolos_nf
  for select to authenticated using (public.autenticado_ativo());
create policy "protocolos_nf_delete_almox" on public.protocolos_nf
  for delete to authenticated
  using (public.meu_perfil() in ('almoxarifado', 'logistica', 'admin'));

create policy "protocolos_nf_itens_select" on public.protocolos_nf_itens
  for select to authenticated using (public.autenticado_ativo());
-- só o certificado muda depois (ex.: PENDENTE -> OK quando o certificado chega)
create policy "protocolos_nf_itens_update_almox" on public.protocolos_nf_itens
  for update to authenticated
  using (public.meu_perfil() in ('almoxarifado', 'logistica', 'admin'))
  with check (public.meu_perfil() in ('almoxarifado', 'logistica', 'admin'));

-- p_itens: [{oc, nf, fornecedor, data_nf, pedido, certificado}, ...]
-- p_numero_inicial: só vale no 1º protocolo do CNPJ (pra continuar a
-- numeração da planilha); depois é sempre o maior + 1.
create or replace function public.criar_protocolo_nf(
  p_cnpj text, p_itens jsonb, p_numero_inicial int default null
)
returns table (id bigint, numero int)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_numero int;
  v_id bigint;
begin
  if public.meu_perfil() not in ('almoxarifado', 'logistica', 'admin') then
    raise exception 'Sem permissão para gerar protocolo';
  end if;
  if p_itens is null or jsonb_array_length(p_itens) = 0 then
    raise exception 'Nenhuma O.C./NF selecionada';
  end if;

  perform pg_advisory_xact_lock(hashtext('protocolo_nf:' || p_cnpj));
  select max(p.numero) + 1 into v_numero from public.protocolos_nf p where p.cnpj = p_cnpj;
  v_numero := coalesce(v_numero, p_numero_inicial, 1);

  insert into public.protocolos_nf (cnpj, numero) values (p_cnpj, v_numero)
  returning protocolos_nf.id into v_id;

  insert into public.protocolos_nf_itens (protocolo_id, oc, nf, fornecedor, data_nf, pedido, certificado)
  select v_id, nullif(trim(i->>'oc'), ''), trim(i->>'nf'), i->>'fornecedor',
         nullif(i->>'data_nf', '')::date, i->>'pedido', coalesce(nullif(i->>'certificado', ''), 'na')
  from jsonb_array_elements(p_itens) i;

  return query select v_id, v_numero;
end;
$$;

-- desde 2026-10-30 o Supabase não dá mais grant automático em tabela nova
grant select, delete on public.protocolos_nf to authenticated;
grant select, update on public.protocolos_nf_itens to authenticated;
grant select, insert, update, delete on public.protocolos_nf to service_role;
grant select, insert, update, delete on public.protocolos_nf_itens to service_role;
grant execute on function public.criar_protocolo_nf(text, jsonb, int) to authenticated;
