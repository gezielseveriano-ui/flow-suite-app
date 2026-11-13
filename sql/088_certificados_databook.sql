-- ============================================================================
-- FactoryView -- Rastreabilidade de certificados: em qual item do Databook
-- (PR-G-363, ex.: 3.1 matéria-prima, 3.4 solda, 3.5 pintura, 3.7 comerciais)
-- o certificado entra. O leitor sugere pelo conteúdo do PDF e a Qualidade
-- confere. Nem todo pedido tem Databook: sem Databook o PDF fica só na pasta
-- de certificados; quando o Databook abrir, a Qualidade envia tudo de uma vez.
-- ============================================================================

alter table public.certificados_mp
  add column item_databook text,                   -- código do item (ex.: '3.1'), sugerido pelo leitor ou escolhido
  add column enviado_databook_em timestamptz;      -- quando o PDF foi copiado para a pasta do item
