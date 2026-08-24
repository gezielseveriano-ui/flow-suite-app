-- ============================================================================
-- FactoryView -- Setor de Produção deixa de ser enum fixo (public.setor_producao)
-- e vira tabela administrável, mesmo padrão que fornecedores_producao/059:
-- id... na verdade aqui a chave é o próprio nome (nome/ativo), tela de
-- "+ Novo setor" / Ativar-Desativar no Cadastro. Enum do Postgres não dá pra
-- editar em produção (adicionar valor exige migração; remover não existe
-- nativo) -- por isso ficava travado nos 10 valores fixos de sempre.
--
-- Os valores gravados (itens.produto, desenhos_engenharia.setor,
-- capacidade_setor.setor) continuam sendo o mesmo texto de sempre
-- ('ESTRUTURA', 'USINAGEM'...) -- só o tipo da coluna muda de enum pra text,
-- com FK pra setores_producao(nome) garantindo que só aponta pra um setor
-- cadastrado. Excluir é sempre "desativar" (ativo=false, igual fornecedor) --
-- nunca apaga a linha, senão quebraria desenhos/itens antigos que já usam
-- aquele setor.
-- ============================================================================

create table public.setores_producao (
  nome       text primary key,
  ativo      boolean not null default true,
  created_at timestamptz not null default now()
);

insert into public.setores_producao (nome) values
  ('ESTRUTURA'), ('USINAGEM'), ('TAMBOR'), ('ROLOS'), ('BASES ROLETES'),
  ('REVESTIMENTO'), ('RMF'), ('TECMETAL'), ('CSM'), ('COMERCIAL');

alter table public.setores_producao enable row level security;

create policy "setores_producao_select" on public.setores_producao
  for select to authenticated
  using (public.autenticado_ativo());

create policy "setores_producao_insert_pcp_admin" on public.setores_producao
  for insert to authenticated
  with check (public.meu_perfil() in ('pcp', 'admin'));

create policy "setores_producao_update_pcp_admin" on public.setores_producao
  for update to authenticated
  using (public.meu_perfil() in ('pcp', 'admin'));

-- ── troca o tipo das 3 colunas que usavam o enum, de setor_producao pra text
-- (o `using coluna::text` preserva os valores existentes -- só muda o tipo)
alter table public.itens
  alter column produto type text using produto::text,
  add constraint itens_produto_fkey foreign key (produto) references public.setores_producao(nome);

alter table public.desenhos_engenharia
  alter column setor type text using setor::text,
  add constraint desenhos_engenharia_setor_fkey foreign key (setor) references public.setores_producao(nome);

alter table public.capacidade_setor
  alter column setor type text using setor::text,
  add constraint capacidade_setor_setor_fkey foreign key (setor) references public.setores_producao(nome);

-- nada mais referencia o enum -- pode derrubar
drop type public.setor_producao;
