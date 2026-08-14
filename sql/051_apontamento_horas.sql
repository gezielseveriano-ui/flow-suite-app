-- ============================================================================
-- FactoryView -- Módulo novo: Apontamento de Horas / Centro de Custo.
--
-- IMPORTANTE: rode 050_perfil_apontamento.sql SOZINHO primeiro (ele só cria o
-- valor novo do enum de perfil). O Postgres não deixa usar um valor de enum
-- recém-criado dentro da MESMA execução/transação em que ele foi adicionado
-- -- por isso esse `alter type` ficou separado deste arquivo (mesmo padrão já
-- usado em 029_perfil_engenharia.sql e 043_perfil_contratos.sql, cada um
-- rodado sozinho antes do restante da respectiva migração).
--
-- Módulo separado da Produção (que acompanha % de avanço por ITEM/desenho).
-- Este aqui acompanha TEMPO de cada COLABORADOR (matrícula), independente de
-- ele tocar em algum item — inclui gente de apoio (qualidade, almoxarifado
-- etc.) que não aparece em `itens`.
--
-- Decisão de arquitetura: o colaborador de chão de fábrica NÃO tem conta
-- Supabase Auth própria (seriam dezenas de contas pra manter). Em vez disso:
--   - o TABLET do setor loga no Flow Suite com uma conta normal, perfil novo
--     'apontamento' (ou 'admin');
--   - dentro do módulo, cada colaborador se identifica por matrícula + PIN
--     de 4 dígitos, só pra saber "quem é" e bater o apontamento;
--   - o PIN nunca sai do banco: fica numa tabela separada sem NENHUMA
--     policy de select, só acessível de dentro das funções abaixo
--     (security definer, mesmo padrão de criar_romaneio/criar_industrializacao);
--   - toda escrita em apontamentos_horas passa por essas funções — não existe
--     policy de insert/update direta na tabela.
-- ============================================================================

create extension if not exists pgcrypto;

create type public.tipo_atividade_enum as enum ('produtiva', 'improdutiva', 'apoio');
create type public.classificacao_colaborador_enum as enum ('produtivo', 'improdutivo', 'apoio');
create type public.status_apontamento_enum as enum ('normal', 'corrigido', 'estornado');

-- ── SETORES / CENTRO DE CUSTO (organizacional -- diferente do enum setor_producao,
--    que é sobre linha de produção do item, não sobre RH/custo) ─────────────
create table public.setores_cc (
  codigo_cc  text primary key,
  nome       text not null,
  ativo      boolean not null default true
);

alter table public.setores_cc enable row level security;

create policy "setores_cc_select" on public.setores_cc
  for select to authenticated using (public.autenticado_ativo());

create policy "setores_cc_admin_all" on public.setores_cc
  for all to authenticated
  using (public.meu_perfil() = 'admin')
  with check (public.meu_perfil() = 'admin');

-- ── ATIVIDADES ───────────────────────────────────────────────────────────
create table public.atividades (
  codigo        text primary key,
  nome          text not null,
  tipo          public.tipo_atividade_enum not null,
  exige_pedido  boolean not null default false,
  ativo         boolean not null default true
);

alter table public.atividades enable row level security;

create policy "atividades_select" on public.atividades
  for select to authenticated using (public.autenticado_ativo());

create policy "atividades_admin_all" on public.atividades
  for all to authenticated
  using (public.meu_perfil() = 'admin')
  with check (public.meu_perfil() = 'admin');

-- ── COLABORADORES (dados públicos -- sem PIN aqui) ──────────────────────────
create table public.colaboradores (
  matricula      text primary key,
  nome           text not null,
  cargo          text,
  setor_cc       text references public.setores_cc(codigo_cc),
  supervisor     text,
  classificacao  public.classificacao_colaborador_enum not null default 'produtivo',
  ativo          boolean not null default true,
  created_at     timestamptz not null default now(),
  created_by     uuid references public.perfis(id) default auth.uid()
);

alter table public.colaboradores enable row level security;

create policy "colaboradores_select" on public.colaboradores
  for select to authenticated using (public.autenticado_ativo());

create policy "colaboradores_admin_all" on public.colaboradores
  for all to authenticated
  using (public.meu_perfil() = 'admin')
  with check (public.meu_perfil() = 'admin');

-- ── PIN dos colaboradores -- tabela isolada, SEM policy de select nenhuma.
--    Só é lida de dentro das funções security definer abaixo.
create table public.colaboradores_pin (
  matricula  text primary key references public.colaboradores(matricula) on delete cascade,
  pin_hash   text not null,
  updated_at timestamptz not null default now()
);

alter table public.colaboradores_pin enable row level security;
-- (propositalmente nenhuma policy: ninguém acessa via API direta)

-- ── PEDIDOS: horas orçadas (pro relatório orçado x consumido) ──────────────
alter table public.pedidos add column if not exists horas_orcadas numeric(10,2);

-- ── APONTAMENTOS DE HORAS ───────────────────────────────────────────────────
create table public.apontamentos_horas (
  id             bigint generated always as identity primary key,
  matricula      text not null references public.colaboradores(matricula),
  data           date not null default current_date,
  hora_inicio    timestamptz not null default now(),
  hora_fim       timestamptz,
  horas          numeric(6,2) generated always as (
                   case when hora_fim is null then null
                        else round((extract(epoch from (hora_fim - hora_inicio)) / 3600.0)::numeric, 2)
                   end
                 ) stored,
  atividade_codigo text not null references public.atividades(codigo),
  pedido_id      bigint references public.pedidos(id),
  setor_cc       text references public.setores_cc(codigo_cc), -- snapshot do setor na data (não muda se colaborador for transferido depois)
  observacao     text,
  lancado_por    text not null default 'self', -- 'self' ou identificação de quem lançou por outro colaborador
  status         public.status_apontamento_enum not null default 'normal',
  usuario_id     uuid references public.perfis(id) default auth.uid(), -- conta do tablet que registrou
  created_at     timestamptz not null default now()
);

create index idx_apontamentos_matricula_data on public.apontamentos_horas(matricula, data);
create index idx_apontamentos_pedido on public.apontamentos_horas(pedido_id);

alter table public.apontamentos_horas enable row level security;

create policy "apontamentos_horas_select" on public.apontamentos_horas
  for select to authenticated using (public.autenticado_ativo());
-- Sem policy de insert/update/delete: só as funções abaixo escrevem aqui.

-- ── FUNÇÕES (security definer) ──────────────────────────────────────────────

create or replace function public._checar_pin(p_matricula text, p_pin text)
returns public.colaboradores
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_col public.colaboradores;
  v_hash text;
begin
  select pin_hash into v_hash from public.colaboradores_pin where matricula = p_matricula;

  if v_hash is null or v_hash <> crypt(p_pin, v_hash) then
    raise exception 'Matrícula ou PIN inválido';
  end if;

  select * into v_col from public.colaboradores where matricula = p_matricula and ativo;
  if v_col.matricula is null then
    raise exception 'Colaborador não encontrado ou inativo';
  end if;

  return v_col;
end;
$$;

-- Admin define/reseta o PIN de um colaborador (tela de cadastro)
create or replace function public.definir_pin_colaborador(p_matricula text, p_pin text)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if public.meu_perfil() <> 'admin' then
    raise exception 'Sem permissão para definir PIN';
  end if;
  if p_pin is null or length(p_pin) < 4 then
    raise exception 'PIN precisa ter ao menos 4 dígitos';
  end if;

  insert into public.colaboradores_pin (matricula, pin_hash, updated_at)
  values (p_matricula, crypt(p_pin, gen_salt('bf')), now())
  on conflict (matricula) do update set pin_hash = excluded.pin_hash, updated_at = now();
end;
$$;

-- Identifica o colaborador no quiosque (matrícula+PIN) e devolve se já tem
-- apontamento em aberto, pra decidir a tela seguinte (iniciar ou finalizar).
create or replace function public.apontamento_identificar(p_matricula text, p_pin text)
returns table (
  matricula text, nome text, cargo text, setor_cc text, classificacao public.classificacao_colaborador_enum,
  apontamento_aberto_id bigint, apontamento_aberto_atividade text, apontamento_aberto_inicio timestamptz
)
language plpgsql
security definer
set search_path = public
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

-- Inicia um apontamento (bate o "início")
create or replace function public.apontamento_iniciar(
  p_matricula text, p_pin text, p_atividade_codigo text,
  p_pedido_id bigint default null, p_observacao text default null
)
returns public.apontamentos_horas
language plpgsql
security definer
set search_path = public
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

-- Finaliza o apontamento em aberto da matrícula
create or replace function public.apontamento_finalizar(p_matricula text, p_pin text)
returns public.apontamentos_horas
language plpgsql
security definer
set search_path = public
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

-- ── SEED: atividades (códigos e nomes confirmados pela planilha; tipo e
--    exige_pedido são um ponto de partida -- ajustável no cadastro) ────────
insert into public.atividades (codigo, nome, tipo, exige_pedido) values
  ('AT01', 'Produção',             'produtiva',   true),
  ('AT02', 'Montagem',             'produtiva',   true),
  ('AT03', 'Elétrica',             'produtiva',   true),
  ('AT04', 'Mecânica',             'produtiva',   true),
  ('AT05', 'Solda',                'produtiva',   true),
  ('AT06', 'Usinagem',             'produtiva',   true),
  ('AT07', 'Impressão 3D',         'produtiva',   true),
  ('AT08', 'Pintura',              'produtiva',   true),
  ('AT09', 'Testes',               'produtiva',   true),
  ('AT10', 'Embalagem',            'produtiva',   true),
  ('AT11', 'Retrabalho',           'produtiva',   true),
  ('AT12', 'Assistência Técnica',  'apoio',       false),
  ('AT13', 'Desenvolvimento',      'apoio',       false),
  ('AT14', 'Engenharia',           'apoio',       false),
  ('AT15', 'Compras',              'apoio',       false),
  ('AT16', 'Almoxarifado',         'apoio',       false),
  ('AT17', 'Qualidade',            'apoio',       false),
  ('AT18', 'Reunião',              'improdutiva', false),
  ('AT19', 'Treinamento',          'improdutiva', false),
  ('AT20', 'Manutenção',           'apoio',       false),
  ('AT21', 'Limpeza',              'improdutiva', false),
  ('AT22', 'Setup',                'produtiva',   true),
  ('AT23', 'Outros',               'improdutiva', false)
on conflict (codigo) do nothing;

-- ── SEED: setores/CC confirmados pela planilha (só os 2 visíveis; o resto
--    entra depois via cadastro) ─────────────────────────────────────────────
insert into public.setores_cc (codigo_cc, nome) values
  ('1101', 'Caldeiraria'),
  ('1102', 'Produção')
on conflict (codigo_cc) do nothing;
