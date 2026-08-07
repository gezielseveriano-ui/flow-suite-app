-- ============================================================================
-- FactoryView -- Novo perfil "engenharia", separado do PCP. A partir de agora
-- a Engenharia só sobe o desenho (classificação, tag, setor, revisão,
-- quantidade a fabricar, peso do desenho) -- quem lê/transcreve é só o PCP.
-- ============================================================================

alter type public.perfil_usuario add value if not exists 'engenharia';
