-- ============================================================================
-- FactoryView -- Engenharia: adiciona Quantidade em cada posição do desenho
-- (faltava pra comparar com peso unitário/total).
-- ============================================================================

alter table public.desenhos_engenharia_posicoes add column if not exists quantidade numeric(12,3);
