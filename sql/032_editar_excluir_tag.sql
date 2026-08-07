-- ============================================================================
-- FactoryView -- Permite editar (renomear) e excluir tags, pra corrigir erro
-- de digitação no cadastro. Faltava a policy de update (não existia nenhuma
-- até agora), e o delete só liberava pcp/admin -- quem cadastra o tag é a
-- Engenharia, então ela também precisa poder corrigir/excluir.
-- ============================================================================

create policy "tags_update_engenharia_pcp_admin" on public.tags
  for update to authenticated
  using (public.meu_perfil() in ('engenharia', 'pcp', 'admin'));

alter policy "tags_delete_pcp_admin" on public.tags
  using (public.meu_perfil() in ('engenharia', 'pcp', 'admin'));
