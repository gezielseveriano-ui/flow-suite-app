-- ============================================================================
-- FactoryView -- Módulo Qualidade: novo perfil de acesso.
-- Rodar sozinho (ALTER TYPE ADD VALUE precisa estar em sua própria transação
-- antes de o valor novo poder ser usado em outros comandos -- mesma regra de
-- 065_perfil_almoxarifado_enum.sql). Depois de rodar este arquivo, rode o
-- 071_modulo_qualidade.sql em separado.
-- ============================================================================

alter type public.perfil_usuario add value if not exists 'qualidade';
