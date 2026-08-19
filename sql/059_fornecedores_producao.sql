-- ============================================================================
-- FactoryView -- Terceirização no PCP.
--
-- Hoje "terceirizar" é um gambiarra: RMF/TECMETAL/CSM/COMERCIAL são valores
-- do MESMO enum setor_producao usado pelos setores internos de verdade
-- (ESTRUTURA, USINAGEM...), escolhido pela Engenharia -- então não dá pra
-- saber ao mesmo tempo "isso é ESTRUTURA" E "foi mandado pra RMF": escolher
-- um apaga o outro.
--
-- Separa as duas coisas: `produto` (itens.produto) continua sendo o tipo de
-- produto, escolha da Engenharia, sem mudar. `fornecedor_producao_id` é NOVO
-- -- onde é produzido (NULL = interno MDE, ou um fornecedor terceirizado com
-- capacidade própria) -- escolha do PCP, independente do tipo de produto.
--
-- Não usa o nome "fornecedores" porque já existe uma tabela com esse nome
-- pra um domínio totalmente diferente (fornecedores de matéria-prima/
-- importação do módulo Industrialização -- razão social, CNPJ, LI...).
--
-- A RMF continua funcionando exatamente como hoje (itens antigos com
-- produto='RMF' não são tocados) -- só entra pelo mecanismo novo o que for
-- atribuído daqui pra frente. Semeia a RMF aqui como o primeiro fornecedor
-- de produção pra já existir pronta pro PCP usar.
--
-- Capacidade é 100% manual (nunca calculada pelo sistema) -- só um número
-- fixo que o PCP edita quando a capacidade real muda (ex: perdeu um
-- caldeireiro, RMF de 40t cai pra 30t). Mesmo modelo que capacidade_setor já
-- usa pros setores internos.
-- ============================================================================

create table public.fornecedores_producao (
  id                      bigint generated always as identity primary key,
  nome                    text not null unique,
  capacidade_maxima_ton   numeric(12,3) not null default 0 check (capacidade_maxima_ton >= 0),
  ativo                   boolean not null default true,
  created_at              timestamptz not null default now()
);

alter table public.fornecedores_producao enable row level security;

create policy "fornecedores_producao_select" on public.fornecedores_producao
  for select to authenticated
  using (public.autenticado_ativo());

create policy "fornecedores_producao_insert_pcp_admin" on public.fornecedores_producao
  for insert to authenticated
  with check (public.meu_perfil() in ('pcp', 'admin'));

create policy "fornecedores_producao_update_pcp_admin" on public.fornecedores_producao
  for update to authenticated
  using (public.meu_perfil() in ('pcp', 'admin'));

insert into public.fornecedores_producao (nome, capacidade_maxima_ton) values ('RMF', 40);

-- ── ITENS: onde é produzido (NULL = interno MDE) ────────────────────────────
alter table public.itens
  add column if not exists fornecedor_producao_id bigint references public.fornecedores_producao(id);

create index if not exists idx_itens_fornecedor_producao on public.itens(fornecedor_producao_id);

-- ── PCP também edita capacidade dos setores internos, não só admin ─────────
-- (antes só admin podia mexer em capacidade_setor -- o PCP passa a cuidar
-- da capacidade de tudo, setor interno e fornecedor terceirizado, junto)
drop policy if exists "capacidade_admin_all" on public.capacidade_setor;

create policy "capacidade_update_pcp_admin" on public.capacidade_setor
  for all to authenticated
  using (public.meu_perfil() in ('pcp', 'admin'))
  with check (public.meu_perfil() in ('pcp', 'admin'));

-- ── Atribuir fornecedor a um item, com bloqueio de capacidade ──────────────
-- Mesmo padrão de apontar_etapa/remessa_confirmar_recebimento_pcp (056...):
-- security definer, checa perfil, raise exception com mensagem clara -- a
-- checagem de capacidade fica no banco (não só no JS) pra não dar pra burlar
-- nem ter corrida entre duas telas mandando item pro mesmo fornecedor.
--
-- "Ocupado" = soma do peso_total dos itens já atribuídos a esse fornecedor
-- que ainda não foram expedidos (produção terceirizada em aberto agora) --
-- quando expede, libera espaço de novo pro fornecedor.
create or replace function public.atribuir_fornecedor_producao(p_item_id bigint, p_fornecedor_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_peso_item numeric;
  v_cap       numeric;
  v_ativo     boolean;
  v_ocupado   numeric;
begin
  if public.meu_perfil() not in ('pcp', 'admin') then
    raise exception 'Sem permissão para atribuir fornecedor';
  end if;

  select peso_total into v_peso_item from public.itens where id = p_item_id;
  if not found then
    raise exception 'Item não encontrado';
  end if;

  if p_fornecedor_id is not null then
    select capacidade_maxima_ton * 1000, ativo into v_cap, v_ativo
    from public.fornecedores_producao where id = p_fornecedor_id;
    if not found then
      raise exception 'Fornecedor não encontrado';
    end if;
    if not v_ativo then
      raise exception 'Fornecedor inativo -- reative antes de atribuir itens a ele';
    end if;

    select coalesce(sum(peso_total), 0) into v_ocupado
    from public.itens
    where fornecedor_producao_id = p_fornecedor_id
      and status_expedicao <> 'expedido'
      and id <> p_item_id;

    if v_ocupado + v_peso_item > v_cap then
      raise exception 'Capacidade excedida: % t ocupadas de % t (item precisa de % t)',
        round(v_ocupado / 1000, 2), round(v_cap / 1000, 2), round(v_peso_item / 1000, 2);
    end if;
  end if;

  update public.itens set fornecedor_producao_id = p_fornecedor_id where id = p_item_id;
end;
$$;
