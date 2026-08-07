-- ============================================================================
-- FactoryView -- PCP: permite "descer" uma posição inteira do desenho (ex: a
-- engenharia manda fabricar só a posição A por enquanto, B e C ficam pra
-- depois) -- a posição descida não gera item de produção (some de "Itens
-- Gerados") e o peso dela não conta em lugar nenhum, como se não tivesse
-- sido lançada. "Subir" de volta reativa normalmente.
-- ============================================================================

alter table public.desenhos_engenharia_posicoes
  add column if not exists descida boolean not null default false;
