-- ============================================================================
-- FactoryView -- Liga a Engenharia (desenhos_engenharia/posicoes) ao PCP
-- (itens/apontamento/expedição/dashboard), que até aqui só existia por
-- lançamento manual na aba Cadastro. Cadastro continua existindo, mas fica
-- em standby -- a Engenharia passa a ser quem gera os itens automaticamente.
-- ============================================================================

-- setor de produção do desenho (obrigatório pro item existir; escolhido pelo
-- engenheiro no formulário, uma vez por desenho -- vale pra todas as posições)
alter table public.desenhos_engenharia
  add column if not exists setor public.setor_producao;

-- referência estável de onde cada item veio, pra sincronizar sem perder
-- progresso já lançado (apontamento/expedição) quando o desenho for revisado.
-- Não usa o id da posição porque "Salvar Alterações" apaga e recria as
-- posições do zero a cada edição -- por isso o vínculo é por (desenho + letra
-- da posição), que é o que realmente identifica "a mesma peça" entre revisões.
alter table public.itens
  add column if not exists desenho_engenharia_id bigint references public.desenhos_engenharia(id),
  add column if not exists posicao_engenharia text;

create index if not exists idx_itens_desenho_engenharia
  on public.itens(desenho_engenharia_id, posicao_engenharia);
