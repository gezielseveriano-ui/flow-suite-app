-- ============================================================================
-- FactoryView -- Quantidade a fabricar (informada manualmente pela Engenharia
-- ao subir o desenho -- ex: "FABRICAR 3x CONFORME DESENHO", igual vem escrito
-- nas remessas do Reinaldo). Multiplica a quantidade de cada posição lida do
-- desenho na hora de gerar os itens (uma posição com qtde=2 na lista de
-- material, com "fabricar 3x", vira quantidade=6 no item final).
-- ============================================================================

alter table public.desenhos_engenharia
  add column if not exists quantidade_fabricar numeric(10,2) not null default 1;
