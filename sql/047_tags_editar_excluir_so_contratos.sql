-- ============================================================================
-- FactoryView -- Só o setor de Contratos (e admin) pode editar ou excluir tag
-- agora. A Engenharia perdeu os ícones de editar/excluir (ela só marca quais
-- tags valem pro desenho que está subindo).
-- ============================================================================

drop policy "tags_delete_pcp_admin" on public.tags;
create policy "tags_delete_contratos_admin" on public.tags
  for delete to authenticated
  using (public.meu_perfil() in ('contratos', 'admin'));

-- nunca existiu policy de update pra tags (o botão de editar da Engenharia já
-- não funcionava pra ninguém, nem admin) -- criando agora, restrita.
create policy "tags_update_contratos_admin" on public.tags
  for update to authenticated
  using (public.meu_perfil() in ('contratos', 'admin'));
