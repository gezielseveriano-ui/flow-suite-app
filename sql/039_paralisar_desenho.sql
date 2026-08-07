-- ============================================================================
-- FactoryView -- Engenharia: "paralisar" um desenho quando é detectado um
-- problema que precisa de revisão (ex: chute mal dimensionado). Enquanto
-- paralisado, o desenho fica bloqueado em todo o sistema — apontamento não
-- consegue dar avanço nem baixar o DWG, expedição não consegue expedir.
-- Substitui a ligação telefônica pra fábrica pedindo pra parar manualmente.
--
-- `desenhos_engenharia.paralisado/paralisado_em/paralisado_motivo` é o estado
-- ATUAL (rápido de checar em qualquer tela). `desenhos_paralisacoes` é o
-- histórico auditável de cada pausa (permite contabilizar quanto tempo cada
-- desenho ficou parado, e reconstruir o histórico se parar mais de uma vez).
-- ============================================================================

alter table public.desenhos_engenharia
  add column if not exists paralisado boolean not null default false,
  add column if not exists paralisado_em timestamptz,
  add column if not exists paralisado_motivo text;

create table public.desenhos_paralisacoes (
  id              bigint generated always as identity primary key,
  desenho_id      bigint not null references public.desenhos_engenharia(id) on delete cascade,
  motivo          text,
  paralisado_em   timestamptz not null default now(),
  paralisado_por  uuid references public.perfis(id) default auth.uid(),
  liberado_em     timestamptz,
  liberado_por    uuid references public.perfis(id)
);

create index idx_desenhos_paralisacoes_desenho on public.desenhos_paralisacoes(desenho_id);
create index idx_desenhos_engenharia_paralisado on public.desenhos_engenharia(paralisado) where paralisado;

alter table public.desenhos_paralisacoes enable row level security;

create policy "desenhos_paralisacoes_select" on public.desenhos_paralisacoes
  for select to authenticated
  using (public.autenticado_ativo());

create policy "desenhos_paralisacoes_insert" on public.desenhos_paralisacoes
  for insert to authenticated
  with check (public.meu_perfil() in ('engenharia', 'pcp', 'admin'));

create policy "desenhos_paralisacoes_update" on public.desenhos_paralisacoes
  for update to authenticated
  using (public.meu_perfil() in ('engenharia', 'pcp', 'admin'));

-- ── Paralisar / liberar (security definer: escreve nas duas tabelas de
-- forma atômica, evitando o estado "atual" e o histórico saírem dessincronizados) ──

create or replace function public.paralisar_desenho(p_desenho_id bigint, p_motivo text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.meu_perfil() not in ('engenharia', 'pcp', 'admin') then
    raise exception 'Sem permissão para paralisar desenho';
  end if;

  update public.desenhos_engenharia
  set paralisado = true, paralisado_em = now(), paralisado_motivo = nullif(trim(p_motivo), '')
  where id = p_desenho_id and not paralisado;

  if not found then
    raise exception 'Desenho não encontrado ou já está paralisado';
  end if;

  insert into public.desenhos_paralisacoes (desenho_id, motivo)
  values (p_desenho_id, nullif(trim(p_motivo), ''));
end;
$$;

create or replace function public.liberar_desenho(p_desenho_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.meu_perfil() not in ('engenharia', 'pcp', 'admin') then
    raise exception 'Sem permissão para liberar desenho';
  end if;

  update public.desenhos_engenharia
  set paralisado = false, paralisado_em = null, paralisado_motivo = null
  where id = p_desenho_id and paralisado;

  if not found then
    raise exception 'Desenho não encontrado ou não está paralisado';
  end if;

  update public.desenhos_paralisacoes
  set liberado_em = now(), liberado_por = auth.uid()
  where desenho_id = p_desenho_id and liberado_em is null;
end;
$$;

-- ── Trava de verdade no banco: mesmo que alguém tente lançar apontamento por
-- fora da tela (ou a checagem da tela falhe), o banco recusa qualquer avanço
-- de etapa de um item cujo desenho esteja paralisado.
create or replace function public.bloquear_avanco_desenho_paralisado()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_paralisado boolean;
begin
  select de.paralisado into v_paralisado
  from public.itens it
  join public.desenhos_engenharia de on de.id = it.desenho_engenharia_id
  where it.id = new.item_id;

  if v_paralisado then
    raise exception 'Este item está com o desenho paralisado pela Engenharia — não é possível lançar apontamento até ser liberado.';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_bloquear_avanco_desenho_paralisado on public.etapas_avanco;
create trigger trg_bloquear_avanco_desenho_paralisado
before insert on public.etapas_avanco
for each row execute function public.bloquear_avanco_desenho_paralisado();
