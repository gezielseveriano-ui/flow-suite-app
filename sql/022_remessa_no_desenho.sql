-- ============================================================================
-- FactoryView -- Engenharia: Remessa passa a ser do DESENHO (uma vez só),
-- não de cada posição — todas as posições de um mesmo desenho compartilham
-- a mesma remessa.
-- ============================================================================

alter table public.desenhos_engenharia add column if not exists remessa text default '1';

-- copia a remessa já lançada em alguma posição (se houver) pro cabeçalho do desenho
update public.desenhos_engenharia d
set remessa = sub.remessa
from (
  select distinct on (desenho_id) desenho_id, remessa
  from public.desenhos_engenharia_posicoes
  where remessa is not null
  order by desenho_id, id
) sub
where sub.desenho_id = d.id;

alter table public.desenhos_engenharia_posicoes drop column if exists remessa;
