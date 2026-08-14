-- ============================================================================
-- FactoryView -- Correção retroativa de apontamento: só admin e supervisor
-- (perfil 'producao', hoje o Marcio) podem editar. O colaborador comum nunca
-- corrige nada sozinho pelo quiosque -- evita gente "ajustando" hora a favor
-- própria. Toda correção fica marcada (status='corrigido') e registra quem
-- corrigiu em lancado_por -- nunca some o rastro. Excluir vira "estornar"
-- (status='estornado'), nunca um delete de verdade -- mesma filosofia de
-- histórico imutável já usada em etapas_avanco.
-- ============================================================================

-- Fecha, edita atividade/pedido/observação, ou reabre um apontamento existente.
create or replace function public.apontamento_corrigir(
  p_id bigint,
  p_hora_inicio timestamptz,
  p_hora_fim timestamptz,
  p_atividade_codigo text,
  p_pedido_id bigint default null,
  p_observacao text default null
)
returns public.apontamentos_horas
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_ativ public.atividades;
  v_nome_corretor text;
  v_row  public.apontamentos_horas;
begin
  if public.meu_perfil() not in ('admin', 'producao') then
    raise exception 'Sem permissão para corrigir apontamentos';
  end if;

  select * into v_ativ from public.atividades where codigo = p_atividade_codigo and ativo;
  if v_ativ.codigo is null then
    raise exception 'Atividade inválida';
  end if;
  if v_ativ.exige_pedido and p_pedido_id is null then
    raise exception 'A atividade "%" exige um pedido', v_ativ.nome;
  end if;
  if p_hora_fim is not null and p_hora_fim <= p_hora_inicio then
    raise exception 'Hora final precisa ser depois da hora inicial';
  end if;

  select nome into v_nome_corretor from public.perfis where id = auth.uid();

  update public.apontamentos_horas set
    data             = p_hora_inicio::date,
    hora_inicio      = p_hora_inicio,
    hora_fim         = p_hora_fim,
    atividade_codigo = p_atividade_codigo,
    pedido_id        = p_pedido_id,
    observacao       = p_observacao,
    status           = 'corrigido',
    lancado_por      = 'corrigido por ' || coalesce(v_nome_corretor, 'admin')
  where id = p_id
  returning * into v_row;

  if v_row.id is null then
    raise exception 'Apontamento não encontrado';
  end if;

  return v_row;
end;
$$;

-- Lança do zero um apontamento que a pessoa esqueceu de bater (dia anterior, etc).
create or replace function public.apontamento_criar_manual(
  p_matricula text,
  p_hora_inicio timestamptz,
  p_hora_fim timestamptz,
  p_atividade_codigo text,
  p_pedido_id bigint default null,
  p_observacao text default null
)
returns public.apontamentos_horas
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_col  public.colaboradores;
  v_ativ public.atividades;
  v_nome_corretor text;
  v_row  public.apontamentos_horas;
begin
  if public.meu_perfil() not in ('admin', 'producao') then
    raise exception 'Sem permissão para lançar apontamentos manualmente';
  end if;

  select * into v_col from public.colaboradores where matricula = p_matricula and ativo;
  if v_col.matricula is null then
    raise exception 'Colaborador não encontrado ou inativo';
  end if;

  select * into v_ativ from public.atividades where codigo = p_atividade_codigo and ativo;
  if v_ativ.codigo is null then
    raise exception 'Atividade inválida';
  end if;
  if v_ativ.exige_pedido and p_pedido_id is null then
    raise exception 'A atividade "%" exige um pedido', v_ativ.nome;
  end if;
  if p_hora_fim is not null and p_hora_fim <= p_hora_inicio then
    raise exception 'Hora final precisa ser depois da hora inicial';
  end if;

  select nome into v_nome_corretor from public.perfis where id = auth.uid();

  insert into public.apontamentos_horas
    (matricula, data, hora_inicio, hora_fim, atividade_codigo, pedido_id, setor_cc, observacao, status, lancado_por, usuario_id)
  values
    (v_col.matricula, p_hora_inicio::date, p_hora_inicio, p_hora_fim, p_atividade_codigo, p_pedido_id, v_col.setor_cc, p_observacao,
     'corrigido', 'lançado por ' || coalesce(v_nome_corretor, 'admin'), auth.uid())
  returning * into v_row;

  return v_row;
end;
$$;

-- Estorna (cancela) um apontamento lançado por engano -- nunca apaga de verdade.
create or replace function public.apontamento_estornar(p_id bigint)
returns public.apontamentos_horas
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_row public.apontamentos_horas;
begin
  if public.meu_perfil() not in ('admin', 'producao') then
    raise exception 'Sem permissão para estornar apontamentos';
  end if;

  update public.apontamentos_horas set status = 'estornado'
  where id = p_id
  returning * into v_row;

  if v_row.id is null then
    raise exception 'Apontamento não encontrado';
  end if;

  return v_row;
end;
$$;
