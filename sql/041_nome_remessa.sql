-- ============================================================================
-- FactoryView -- Nome da remessa (ex: "Ponte Treliça", "Chutes de Descarga"),
-- pra identificar rápido o que está descendo sem precisar abrir e ver os
-- desenhos. Preenchido ao gerar a remessa na Engenharia, com autocomplete dos
-- nomes já usados antes (mesma lógica do nome do equipamento).
-- ============================================================================

alter table public.remessas
  add column if not exists nome text;
