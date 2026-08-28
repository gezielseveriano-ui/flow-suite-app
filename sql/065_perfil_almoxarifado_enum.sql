-- ============================================================================
-- FactoryView -- Módulo Almoxarifado: novo perfil de acesso.
-- Rodar sozinho (ALTER TYPE ADD VALUE precisa estar em sua própria transação
-- antes de o valor novo poder ser usado em outros comandos -- mesma regra de
-- 010_status_parcial.sql). Depois de rodar este arquivo, rode o
-- 066_almoxarifado_modulo.sql em separado.
-- ============================================================================

alter type public.perfil_usuario add value if not exists 'almoxarifado';
