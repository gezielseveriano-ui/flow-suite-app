-- ============================================================================
-- FactoryView -- Peso do desenho (declarado pela Engenharia, peso de UMA
-- unidade do conjunto completo -- ex: "um chute pesa 200kg"). Serve de
-- conferência cruzada: peso_unitario_desenho x quantidade_fabricar deve bater
-- com a soma dos pesos dos itens que o PCP lê automaticamente do desenho.
-- ============================================================================

alter table public.desenhos_engenharia
  add column if not exists peso_unitario_desenho numeric(12,3);
