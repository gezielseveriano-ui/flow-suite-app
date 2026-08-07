-- ============================================================================
-- FactoryView -- Revisão de apontamento: corrige um percentual de etapa já
-- lançado (ex: apontador marcou 100% em Matéria Prima por engano). A trigger
-- trg_checar_avanco_etapa só permite o percentual subir, então uma revisão
-- de verdade (pra corrigir um erro, inclusive pra baixo) precisa passar por
-- aqui: apaga o histórico daquele item+etapa e lança de novo com o valor certo.
-- ============================================================================

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

  if p_percentual is null or p_percentual < 0 or p_percentual > 100 then
    raise exception 'Percentual inválido: %', p_percentual;
  end if;

  delete from public.etapas_avanco
  where item_id = p_item_id and etapa = p_etapa;

  insert into public.etapas_avanco (item_id, etapa, percentual, usuario_id)
  values (p_item_id, p_etapa, p_percentual, auth.uid());
end;
$$;
