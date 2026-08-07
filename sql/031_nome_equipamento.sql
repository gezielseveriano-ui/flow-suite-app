-- ============================================================================
-- FactoryView -- Nome do equipamento/título do desenho (ex: "PROJETO WAVE
-- ALUMINIUM - COLUNA, SUPORTE E PINO DE FIXAÇÃO"), igual à coluna
-- "DESENHO-TÍTULO" que já aparece nos emails de remessa reais da Engenharia.
-- Campo descritivo, separado da Observação (que é mais tipo instrução, ex:
-- "FABRICAR 1x CONFORME DESENHO").
-- ============================================================================

alter table public.desenhos_engenharia
  add column if not exists nome_equipamento text;
