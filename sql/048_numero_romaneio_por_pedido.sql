-- ============================================================================
-- FactoryView -- Bug: `romaneios.numero` era único no banco inteiro, mas a
-- numeração ("LE 001", "LE 002"...) é calculada por pedido (ver
-- gerar_numero_romaneio em 002_functions_triggers.sql). Isso funcionou por
-- acaso enquanto só existia um pedido gerando romaneio -- o primeiro romaneio
-- de QUALQUER pedido novo vira "LE 001" e colide com o "LE 001" que já existe
-- de outro pedido, travando com "duplicate key value violates unique
-- constraint romaneios_numero_key".
-- ============================================================================

alter table public.romaneios drop constraint romaneios_numero_key;
alter table public.romaneios add constraint romaneios_numero_pedido_key unique (pedido_id, numero);
