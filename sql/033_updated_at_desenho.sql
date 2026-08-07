-- ============================================================================
-- FactoryView -- updated_at em desenhos_engenharia, pra saber quais desenhos
-- foram revisados DEPOIS do último envio de email da remessa (comparando
-- com remessas.enviada_email_em) -- usado pra destacar "REVISÃO" no assunto
-- e no corpo do email quando a Engenharia reenvia uma remessa já enviada.
-- ============================================================================

alter table public.desenhos_engenharia
  add column if not exists updated_at timestamptz not null default now();
