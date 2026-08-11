-- ============================================================================
-- FactoryView -- Tag agora nasce em Contratos (a partir da coluna TAG dos
-- itens do pedido), não mais na Engenharia. A Engenharia continua só
-- escolhendo entre as tags já existentes daquele pedido.
-- ============================================================================

drop policy "tags_insert_pcp_admin" on public.tags;
create policy "tags_insert_contratos_admin" on public.tags
  for insert to authenticated
  with check (public.meu_perfil() in ('contratos', 'admin'));
