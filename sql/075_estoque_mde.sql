-- ============================================================================
-- FactoryView -- Estoque MDE (aba nova no Almoxarifado).
--
-- O módulo Almoxarifado (066) controla o que é COMPRADO (SC/O.C. do Sapiens).
-- Este controla o que JÁ ESTÁ no estoque da MDE -- estoque antigo, sobras,
-- itens comprados pra estoque -- em dois tipos:
--   'comprado'      -- rolamento, mancal, bucha, anel de fixação, motorredutor...
--   'materia_prima' -- cantoneira, chapa, tubo... (controla peças/barras E kg)
--
-- Saldo: guardado no próprio item (saldo_qtd/saldo_kg) e só muda dentro de
-- lancar_movimento_estoque/estornar_movimento_estoque, que travam a linha do
-- item (for update) antes de somar/descontar -- duas baixas ao mesmo tempo
-- nunca deixam o saldo negativo (check >= 0 na tabela é a última defesa).
--
-- Nada é apagado: um lançamento errado é corrigido com ESTORNO (um movimento
-- contrário apontando pro original em estorno_de), então o histórico de cada
-- item sempre fecha com o saldo.
--
-- Escrita só via RPC (perfis almoxarifado/logistica/admin, mesmo acesso do
-- módulo de compras -- 073); leitura liberada pra qualquer usuário ativo.
-- Rodar DEPOIS de 073_logistica_acesso_expedicao_almoxarifado.sql.
-- ============================================================================

create table public.estoque_itens (
  id                 bigint generated always as identity primary key,
  tipo               text not null check (tipo in ('comprado', 'materia_prima')),
  codigo             text unique,                 -- código interno/Sapiens, opcional
  descricao          text not null,
  categoria          text,                        -- Rolamento, Mancal, Cantoneira, Chapa...
  especificacao      text,                        -- ex.: 6204-2RS, L 2" x 1/4" x 6 m
  unidade            text not null default 'PÇ',  -- PÇ, JG, BARRA, M, KG...
  peso_unitario_kg   numeric(12,3) check (peso_unitario_kg is null or peso_unitario_kg >= 0), -- sugere o kg na matéria-prima
  localizacao        text,                        -- prateleira/baia
  estoque_minimo     numeric(14,3) check (estoque_minimo is null or estoque_minimo >= 0),

  -- só mudam via RPC de movimento
  saldo_qtd          numeric(14,3) not null default 0 check (saldo_qtd >= 0),
  saldo_kg           numeric(14,3) not null default 0 check (saldo_kg >= 0),

  ativo              boolean not null default true,
  criado_por         uuid references public.perfis(id) default auth.uid(),
  criado_em          timestamptz not null default now(),
  atualizado_em      timestamptz not null default now()
);

create index idx_estoque_itens_tipo on public.estoque_itens(tipo);

create table public.estoque_movimentos (
  id                 bigint generated always as identity primary key,
  item_id            bigint not null references public.estoque_itens(id),
  tipo               text not null check (tipo in ('entrada', 'saida')),
  quantidade         numeric(14,3) not null check (quantidade > 0),
  peso_kg            numeric(14,3) not null default 0 check (peso_kg >= 0),
  data_movimento     date not null default current_date,

  -- entrada
  origem             text,          -- NF de compra, Estoque antigo, Inventário, Devolução de obra...
  nota_fiscal        text,
  fornecedor         text,

  -- saída (pedido_id OU uso_interno -- obrigatório um dos dois na RPC)
  pedido_id          bigint references public.pedidos(id),
  uso_interno        boolean not null default false,
  retirado_por       text,
  setor              text,

  observacao         text,
  estorno_de         bigint unique references public.estoque_movimentos(id), -- unique: um lançamento só pode ser estornado uma vez

  usuario_id         uuid references public.perfis(id) default auth.uid(),
  criado_em          timestamptz not null default now()
);

create index idx_estoque_mov_item on public.estoque_movimentos(item_id, criado_em desc);
create index idx_estoque_mov_pedido on public.estoque_movimentos(pedido_id);

comment on table public.estoque_itens is
  'Estoque MDE (aba do Almoxarifado) -- saldo_qtd/saldo_kg só mudam pelas RPCs lancar_movimento_estoque/estornar_movimento_estoque.';
comment on table public.estoque_movimentos is
  'Entradas e saídas do Estoque MDE. Nunca apagado nem editado -- correção é por estorno (estorno_de).';

-- ── RLS + grants ────────────────────────────────────────────────────────────
alter table public.estoque_itens enable row level security;
alter table public.estoque_movimentos enable row level security;

create policy "estoque_itens_select" on public.estoque_itens
  for select to authenticated using (public.autenticado_ativo());
create policy "estoque_movimentos_select" on public.estoque_movimentos
  for select to authenticated using (public.autenticado_ativo());

-- sem policy de insert/update/delete: escrita só pelas RPCs abaixo
grant select on public.estoque_itens to authenticated;
grant select on public.estoque_movimentos to authenticated;
grant select, insert, update, delete on public.estoque_itens to service_role;
grant select, insert, update, delete on public.estoque_movimentos to service_role;

-- ── Cadastrar / editar item (nunca mexe no saldo) ───────────────────────────
-- p_id null = novo. p_dados = {"tipo":"comprado","codigo":"...","descricao":"...",
--   "categoria":"...","especificacao":"...","unidade":"PÇ","peso_unitario_kg":1.2,
--   "localizacao":"...","estoque_minimo":2,"ativo":true}
create or replace function public.salvar_item_estoque(p_id bigint, p_dados jsonb)
returns public.estoque_itens
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item public.estoque_itens;
begin
  if public.meu_perfil() not in ('almoxarifado', 'logistica', 'admin') then
    raise exception 'Sem permissão para cadastrar item de estoque';
  end if;
  if nullif(trim(p_dados->>'descricao'), '') is null then
    raise exception 'Informe a descrição do item';
  end if;
  if coalesce(p_dados->>'tipo', '') not in ('comprado', 'materia_prima') then
    raise exception 'Tipo inválido (comprado ou materia_prima)';
  end if;

  if p_id is null then
    insert into public.estoque_itens (
      tipo, codigo, descricao, categoria, especificacao, unidade,
      peso_unitario_kg, localizacao, estoque_minimo
    ) values (
      p_dados->>'tipo',
      nullif(trim(p_dados->>'codigo'), ''),
      trim(p_dados->>'descricao'),
      nullif(trim(p_dados->>'categoria'), ''),
      nullif(trim(p_dados->>'especificacao'), ''),
      coalesce(nullif(trim(upper(p_dados->>'unidade')), ''), 'PÇ'),
      nullif(p_dados->>'peso_unitario_kg', '')::numeric,
      nullif(trim(p_dados->>'localizacao'), ''),
      nullif(p_dados->>'estoque_minimo', '')::numeric
    )
    returning * into v_item;
  else
    update public.estoque_itens set
      tipo             = p_dados->>'tipo',
      codigo           = nullif(trim(p_dados->>'codigo'), ''),
      descricao        = trim(p_dados->>'descricao'),
      categoria        = nullif(trim(p_dados->>'categoria'), ''),
      especificacao    = nullif(trim(p_dados->>'especificacao'), ''),
      unidade          = coalesce(nullif(trim(upper(p_dados->>'unidade')), ''), 'PÇ'),
      peso_unitario_kg = nullif(p_dados->>'peso_unitario_kg', '')::numeric,
      localizacao      = nullif(trim(p_dados->>'localizacao'), ''),
      estoque_minimo   = nullif(p_dados->>'estoque_minimo', '')::numeric,
      ativo            = coalesce((p_dados->>'ativo')::boolean, ativo),
      atualizado_em    = now()
    where id = p_id
    returning * into v_item;

    if v_item.id is null then
      raise exception 'Item não encontrado';
    end if;
  end if;

  return v_item;
end;
$$;

-- ── Lançar entrada ou saída (baixa) ─────────────────────────────────────────
create or replace function public.lancar_movimento_estoque(
  p_item_id      bigint,
  p_tipo         text,
  p_quantidade   numeric,
  p_peso_kg      numeric default 0,
  p_data         date default null,
  p_origem       text default null,
  p_nota_fiscal  text default null,
  p_fornecedor   text default null,
  p_pedido_id    bigint default null,
  p_uso_interno  boolean default false,
  p_retirado_por text default null,
  p_setor        text default null,
  p_observacao   text default null
)
returns public.estoque_movimentos
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item public.estoque_itens;
  v_mov  public.estoque_movimentos;
  v_kg   numeric := coalesce(p_peso_kg, 0);
begin
  if public.meu_perfil() not in ('almoxarifado', 'logistica', 'admin') then
    raise exception 'Sem permissão para movimentar o estoque';
  end if;
  if p_tipo not in ('entrada', 'saida') then
    raise exception 'Tipo de movimento inválido';
  end if;
  if p_quantidade is null or p_quantidade <= 0 then
    raise exception 'Informe uma quantidade maior que zero';
  end if;
  if v_kg < 0 then
    raise exception 'Peso inválido';
  end if;

  select * into v_item from public.estoque_itens where id = p_item_id for update;
  if v_item.id is null then
    raise exception 'Item não encontrado';
  end if;

  if p_tipo = 'saida' then
    if p_pedido_id is null and not coalesce(p_uso_interno, false) then
      raise exception 'Na baixa, informe o pedido de destino (ou marque uso interno)';
    end if;
    if nullif(trim(p_retirado_por), '') is null then
      raise exception 'Na baixa, informe quem retirou';
    end if;
    if nullif(trim(p_setor), '') is null then
      raise exception 'Na baixa, informe o setor';
    end if;
    if p_quantidade > v_item.saldo_qtd then
      raise exception 'Saldo insuficiente: em estoque % %, baixa de %', v_item.saldo_qtd, v_item.unidade, p_quantidade;
    end if;
    if v_kg > v_item.saldo_kg then
      raise exception 'Saldo em kg insuficiente: em estoque % kg, baixa de % kg', v_item.saldo_kg, v_kg;
    end if;
  end if;

  insert into public.estoque_movimentos (
    item_id, tipo, quantidade, peso_kg, data_movimento,
    origem, nota_fiscal, fornecedor,
    pedido_id, uso_interno, retirado_por, setor, observacao
  ) values (
    p_item_id, p_tipo, p_quantidade, v_kg, coalesce(p_data, current_date),
    case when p_tipo = 'entrada' then nullif(trim(p_origem), '') end,
    case when p_tipo = 'entrada' then nullif(trim(p_nota_fiscal), '') end,
    case when p_tipo = 'entrada' then nullif(trim(p_fornecedor), '') end,
    case when p_tipo = 'saida' and not coalesce(p_uso_interno, false) then p_pedido_id end,
    p_tipo = 'saida' and coalesce(p_uso_interno, false),
    case when p_tipo = 'saida' then nullif(trim(p_retirado_por), '') end,
    case when p_tipo = 'saida' then nullif(trim(p_setor), '') end,
    nullif(trim(p_observacao), '')
  )
  returning * into v_mov;

  update public.estoque_itens set
    saldo_qtd     = saldo_qtd + case when p_tipo = 'entrada' then p_quantidade else -p_quantidade end,
    saldo_kg      = saldo_kg  + case when p_tipo = 'entrada' then v_kg else -v_kg end,
    atualizado_em = now()
  where id = p_item_id;

  return v_mov;
end;
$$;

-- ── Estornar um lançamento errado (cria o movimento contrário) ──────────────
create or replace function public.estornar_movimento_estoque(p_movimento_id bigint, p_motivo text)
returns public.estoque_movimentos
language plpgsql
security definer
set search_path = public
as $$
declare
  v_orig public.estoque_movimentos;
  v_item public.estoque_itens;
  v_mov  public.estoque_movimentos;
  v_tipo text;
begin
  if public.meu_perfil() not in ('almoxarifado', 'logistica', 'admin') then
    raise exception 'Sem permissão para estornar';
  end if;
  if nullif(trim(p_motivo), '') is null then
    raise exception 'Informe o motivo do estorno';
  end if;

  select * into v_orig from public.estoque_movimentos where id = p_movimento_id;
  if v_orig.id is null then
    raise exception 'Lançamento não encontrado';
  end if;
  if v_orig.estorno_de is not null then
    raise exception 'Este lançamento já é um estorno';
  end if;
  if exists (select 1 from public.estoque_movimentos where estorno_de = p_movimento_id) then
    raise exception 'Este lançamento já foi estornado';
  end if;

  select * into v_item from public.estoque_itens where id = v_orig.item_id for update;
  v_tipo := case when v_orig.tipo = 'entrada' then 'saida' else 'entrada' end;

  if v_tipo = 'saida' and (v_orig.quantidade > v_item.saldo_qtd or v_orig.peso_kg > v_item.saldo_kg) then
    raise exception 'Não dá pra estornar esta entrada: parte dela já saiu do estoque (saldo atual % %)', v_item.saldo_qtd, v_item.unidade;
  end if;

  insert into public.estoque_movimentos (
    item_id, tipo, quantidade, peso_kg, data_movimento, observacao, estorno_de
  ) values (
    v_orig.item_id, v_tipo, v_orig.quantidade, v_orig.peso_kg, current_date,
    'ESTORNO: ' || trim(p_motivo), v_orig.id
  )
  returning * into v_mov;

  update public.estoque_itens set
    saldo_qtd     = saldo_qtd + case when v_tipo = 'entrada' then v_orig.quantidade else -v_orig.quantidade end,
    saldo_kg      = saldo_kg  + case when v_tipo = 'entrada' then v_orig.peso_kg else -v_orig.peso_kg end,
    atualizado_em = now()
  where id = v_orig.item_id;

  return v_mov;
end;
$$;

grant execute on function public.salvar_item_estoque(bigint, jsonb) to authenticated;
grant execute on function public.lancar_movimento_estoque(bigint, text, numeric, numeric, date, text, text, text, bigint, boolean, text, text, text) to authenticated;
grant execute on function public.estornar_movimento_estoque(bigint, text) to authenticated;
