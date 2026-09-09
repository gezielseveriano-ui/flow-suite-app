-- ============================================================================
-- FactoryView -- Novo perfil "logistica": coordenador que responde tanto pela
-- Expedição quanto pelo Almoxarifado (hoje são dois perfis separados, cada um
-- só enxerga o próprio módulo).
-- Rodar sozinho (ALTER TYPE ADD VALUE precisa estar em sua própria transação
-- antes de o valor novo poder ser usado em outros comandos -- mesma regra de
-- 065_perfil_almoxarifado_enum.sql). Depois de rodar este arquivo, rode o
-- 073_logistica_acesso_expedicao_almoxarifado.sql em separado.
-- ============================================================================

alter type public.perfil_usuario add value if not exists 'logistica';
