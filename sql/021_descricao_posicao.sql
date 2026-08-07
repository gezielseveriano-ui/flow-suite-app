-- ============================================================================
-- FactoryView -- Engenharia: adiciona Descrição em cada posição do desenho
-- (ex: "COLUNA A", "TAMBOR DE ACIONAMENTO"), como aparece na lista de material.
-- ============================================================================

alter table public.desenhos_engenharia_posicoes add column if not exists descricao text;
