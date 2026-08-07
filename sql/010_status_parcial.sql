-- ============================================================================
-- FactoryView -- Novo status "parcial" (expedicao parcial de um item)
-- Rodar sozinho (ALTER TYPE ADD VALUE precisa estar em sua propria transacao
-- antes de o valor novo poder ser usado em outros comandos).
-- ============================================================================

alter type public.status_expedicao_enum add value if not exists 'parcial';
