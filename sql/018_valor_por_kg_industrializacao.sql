-- ============================================================================
-- FactoryView -- Correção: na Industrialização o "Valor unitário" é o preço
-- por KG cobrado pelo fornecedor (ex: R$10/kg), não por peça. O Valor Total
-- precisa ser Valor unitário × Peso total (kg), não × Quantidade (peças).
-- Ex: peso total 702 kg × R$10/kg = R$ 7.020,00.
-- ============================================================================

alter table public.industrializacao_itens drop column valor_total;

alter table public.industrializacao_itens
  add column valor_total numeric(14,2) generated always as (valor_unitario * peso_unitario * quantidade) stored;
