-- ============================================================
-- ZERAR DADOS DE TESTE — Flow Suite
-- Apaga todos os pedidos/desenhos/itens/romaneios/industrializações
-- de teste, mantendo intactas as tabelas de configuração
-- (perfis, capacidade_setor, equipamentos_padrao, fornecedores).
--
-- COMO RODAR: Supabase → SQL Editor → cole este script inteiro → Run.
-- ATENÇÃO: isso é IRREVERSÍVEL. Confira se não há nada que você
-- ainda precise antes de rodar (não tem desfazer depois).
-- ============================================================

truncate table
  public.desenhos_paralisacoes,
  public.desenhos_engenharia_subprodutos,
  public.desenhos_engenharia_posicoes,
  public.desenhos_engenharia,
  public.remessas,
  public.tags,
  public.romaneio_itens,
  public.romaneios,
  public.etapas_avanco,
  public.itens,
  public.industrializacao_itens,
  public.industrializacoes,
  public.pedidos
restart identity cascade;

-- volta a numeração do Cód. MDE (compartilhada entre "itens" e
-- "desenhos_engenharia") pro ponto de partida original do sistema.
alter sequence public.seq_codigo_mde restart with 4395;
