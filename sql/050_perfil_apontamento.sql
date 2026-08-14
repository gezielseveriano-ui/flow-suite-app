-- ============================================================================
-- FactoryView -- Novo perfil "apontamento": conta do tablet/quiosque usada
-- pelo chão de fábrica pra bater ponto (ver 051_apontamento_horas.sql).
-- Precisa rodar sozinho: o Postgres não deixa usar um valor de enum
-- recém-criado na mesma transação em que ele foi adicionado (mesmo padrão de
-- 029_perfil_engenharia.sql e 043_perfil_contratos.sql).
-- ============================================================================

alter type public.perfil_usuario add value if not exists 'apontamento';
