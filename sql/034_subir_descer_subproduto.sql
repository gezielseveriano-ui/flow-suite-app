-- ============================================================================
-- FactoryView -- Engenharia/PCP: permite "subir" um subproduto (peça que
-- normalmente só compõe uma posição, ex: chapa de desgaste, pino) pra virar
-- um item de produção independente, com controle próprio (expedição avulsa,
-- apontamento próprio), em vez de ficar só contabilizado dentro da posição
-- que a contém. "Descer" desfaz isso.
--
-- Quando subido=true, o subproduto passa a gerar sua própria linha na tabela
-- `itens` (ver sincronizarItensPCP em cadastro.html) -- e o peso dele some da
-- contagem da posição-mãe, pra não contar peso duas vezes.
-- ============================================================================

alter table public.desenhos_engenharia_subprodutos
  add column if not exists subido boolean not null default false;
