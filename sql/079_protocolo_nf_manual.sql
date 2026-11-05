-- ============================================================================
-- FactoryView -- Protocolo de NF: lançamento manual de NF num protocolo já
-- gerado (NF de manutenção e outras que não passam pela lista de compras) e
-- remoção de linha lançada errado. Mesmos perfis do 078.
-- ============================================================================

create policy "protocolos_nf_itens_insert_almox" on public.protocolos_nf_itens
  for insert to authenticated
  with check (public.meu_perfil() in ('almoxarifado', 'logistica', 'admin'));

create policy "protocolos_nf_itens_delete_almox" on public.protocolos_nf_itens
  for delete to authenticated
  using (public.meu_perfil() in ('almoxarifado', 'logistica', 'admin'));

grant insert, delete on public.protocolos_nf_itens to authenticated;
