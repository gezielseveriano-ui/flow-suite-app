-- ============================================================================
-- FactoryView -- Confirmação de recebimento de remessa. A Engenharia já
-- dispara a remessa por email pro PCP (enviada_email_em, ver 013.../030...).
-- Agora:
--   1) O PCP confirma que recebeu (qualquer perfil 'pcp' ou admin).
--   2) A Produção confirma que recebeu (só perfil 'producao' -- o supervisor,
--      hoje o Marcio -- ou admin como retaguarda se ele não estiver disponível).
-- A confirmação da produção passa a ser OBRIGATÓRIA: não dá pra apontar
-- nenhuma etapa de um item ligado a uma remessa ainda não confirmada.
-- Item sem remessa vinculada (lançado fora desse fluxo) não é bloqueado.
-- ============================================================================

alter table public.remessas add column if not exists recebida_pcp_em timestamptz;
alter table public.remessas add column if not exists recebida_pcp_por uuid references public.perfis(id);
alter table public.remessas add column if not exists recebida_producao_em timestamptz;
alter table public.remessas add column if not exists recebida_producao_por uuid references public.perfis(id);

create or replace function public.remessa_confirmar_recebimento_pcp(p_remessa_id bigint)
returns public.remessas
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.remessas;
begin
  if public.meu_perfil() not in ('pcp', 'admin') then
    raise exception 'Sem permissão para confirmar recebimento';
  end if;

  update public.remessas set recebida_pcp_em = now(), recebida_pcp_por = auth.uid()
  where id = p_remessa_id
  returning * into v_row;

  if v_row.id is null then
    raise exception 'Remessa não encontrada';
  end if;

  return v_row;
end;
$$;

create or replace function public.remessa_confirmar_recebimento_producao(p_remessa_id bigint)
returns public.remessas
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.remessas;
begin
  if public.meu_perfil() not in ('producao', 'admin') then
    raise exception 'Sem permissão para confirmar recebimento';
  end if;

  update public.remessas set recebida_producao_em = now(), recebida_producao_por = auth.uid()
  where id = p_remessa_id
  returning * into v_row;

  if v_row.id is null then
    raise exception 'Remessa não encontrada';
  end if;

  return v_row;
end;
$$;

create or replace function public.remessa_recebida_producao(p_item_id bigint)
returns boolean
language sql
stable
as $$
  select coalesce(
    (select r.recebida_producao_em is not null
     from public.itens i
     join public.desenhos_engenharia d on d.id = i.desenho_engenharia_id
     join public.remessas r on r.id = d.remessa_id
     where i.id = p_item_id),
    true
  );
$$;

-- ── Apontamento normal passa a ser uma função (não mais insert direto),
--    pra poder dar mensagem de erro clara quando a remessa não foi
--    confirmada, em vez do erro genérico de RLS. ──────────────────────────
drop policy if exists "etapas_insert_producao_admin" on public.etapas_avanco;

create or replace function public.apontar_etapa(p_item_id bigint, p_etapa public.etapa_producao, p_percentual numeric)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.meu_perfil() not in ('producao', 'admin') then
    raise exception 'Sem permissão para apontar produção';
  end if;

  if not public.remessa_recebida_producao(p_item_id) then
    raise exception 'Esta remessa ainda não foi confirmada como recebida pela produção. Peça pro supervisor confirmar o recebimento antes de apontar.';
  end if;

  insert into public.etapas_avanco (item_id, etapa, percentual, usuario_id)
  values (p_item_id, p_etapa, p_percentual, auth.uid());
end;
$$;

create or replace function public.revisar_etapa(p_item_id bigint, p_etapa public.etapa_producao, p_percentual numeric)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.meu_perfil() not in ('producao', 'admin') then
    raise exception 'Sem permissão para revisar apontamento';
  end if;

  if p_etapa in ('expedicao', 'finalizado') then
    raise exception 'Etapa % é controlada automaticamente pelo módulo de Expedição e não pode ser revisada manualmente', p_etapa;
  end if;

  if not public.remessa_recebida_producao(p_item_id) then
    raise exception 'Esta remessa ainda não foi confirmada como recebida pela produção. Peça pro supervisor confirmar o recebimento antes de apontar.';
  end if;

  if p_percentual is null or p_percentual < 0 or p_percentual > 100 then
    raise exception 'Percentual inválido: %', p_percentual;
  end if;

  delete from public.etapas_avanco
  where item_id = p_item_id and etapa = p_etapa;

  insert into public.etapas_avanco (item_id, etapa, percentual, usuario_id)
  values (p_item_id, p_etapa, p_percentual, auth.uid());
end;
$$;
