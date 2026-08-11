-- ============================================================================
-- FactoryView -- Novo perfil "contratos": coordenador do setor de contratos.
-- É quem cria contrato + pedido comercial (Folha de Rosto) daqui pra frente --
-- o pedido deixa de nascer no PCP (ver 045_pedidos_comerciais.sql).
-- ============================================================================

alter type public.perfil_usuario add value if not exists 'contratos';
