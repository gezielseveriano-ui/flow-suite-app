-- ============================================================================
-- FactoryView -- Campo "Remessa": identificador de remessa/lote vinculado ao
-- desenho/item, usado para localização física do desenho na fábrica/estoque.
-- Texto livre, opcional (nem todo item tem remessa cadastrada).
-- ============================================================================

alter table public.itens add column if not exists remessa text;

create index if not exists idx_itens_remessa on public.itens(remessa);
