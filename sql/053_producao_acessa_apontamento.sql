-- ============================================================================
-- FactoryView -- Marcio (perfil 'producao', supervisor de fábrica) vai ser o
-- responsável pelo único tablet de Apontamento de Horas por enquanto. Em vez
-- de criar um usuário novo com perfil 'apontamento', libera o módulo direto
-- pra quem já é 'producao' -- ele mantém o acesso que já tinha à Produção e
-- ganha o quiosque de apontamento com a mesma conta.
-- ============================================================================

create or replace function public.apontamento_identificar(p_matricula text, p_pin text)
returns table (
  matricula text, nome text, cargo text, setor_cc text, classificacao public.classificacao_colaborador_enum,
  apontamento_aberto_id bigint, apontamento_aberto_atividade text, apontamento_aberto_inicio timestamptz
)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_col public.colaboradores;
begin
  if public.meu_perfil() not in ('apontamento', 'producao', 'admin') then
    raise exception 'Sem permissão para usar o apontamento de horas';
  end if;

  v_col := public._checar_pin(p_matricula, p_pin);

  return query
  select v_col.matricula, v_col.nome, v_col.cargo, v_col.setor_cc, v_col.classificacao,
         ah.id, ah.atividade_codigo, ah.hora_inicio
  from (select 1) dummy
  left join public.apontamentos_horas ah
    on ah.matricula = v_col.matricula and ah.hora_fim is null
  limit 1;
end;
$$;

create or replace function public.apontamento_iniciar(
  p_matricula text, p_pin text, p_atividade_codigo text,
  p_pedido_id bigint default null, p_observacao text default null
)
returns public.apontamentos_horas
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_col  public.colaboradores;
  v_ativ public.atividades;
  v_novo public.apontamentos_horas;
begin
  if public.meu_perfil() not in ('apontamento', 'producao', 'admin') then
    raise exception 'Sem permissão para usar o apontamento de horas';
  end if;

  v_col := public._checar_pin(p_matricula, p_pin);

  select * into v_ativ from public.atividades where codigo = p_atividade_codigo and ativo;
  if v_ativ.codigo is null then
    raise exception 'Atividade inválida';
  end if;

  if v_ativ.exige_pedido and p_pedido_id is null then
    raise exception 'A atividade "%" exige um pedido', v_ativ.nome;
  end if;

  if exists (select 1 from public.apontamentos_horas where matricula = v_col.matricula and hora_fim is null) then
    raise exception 'Já existe um apontamento em aberto para esta matrícula';
  end if;

  insert into public.apontamentos_horas
    (matricula, atividade_codigo, pedido_id, setor_cc, observacao, lancado_por, usuario_id)
  values
    (v_col.matricula, p_atividade_codigo, p_pedido_id, v_col.setor_cc, p_observacao, 'self', auth.uid())
  returning * into v_novo;

  return v_novo;
end;
$$;

create or replace function public.apontamento_finalizar(p_matricula text, p_pin text)
returns public.apontamentos_horas
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_col  public.colaboradores;
  v_fim  public.apontamentos_horas;
begin
  if public.meu_perfil() not in ('apontamento', 'producao', 'admin') then
    raise exception 'Sem permissão para usar o apontamento de horas';
  end if;

  v_col := public._checar_pin(p_matricula, p_pin);

  update public.apontamentos_horas
  set hora_fim = now()
  where matricula = v_col.matricula and hora_fim is null
  returning * into v_fim;

  if v_fim.id is null then
    raise exception 'Não há apontamento em aberto para esta matrícula';
  end if;

  return v_fim;
end;
$$;
