-- ============================================================================
-- FactoryView -- Política de exclusão de itens (faltava -- só existia
-- select/insert/update). Necessária pra sincronização Engenharia -> PCP
-- remover um item quando a posição correspondente é removida do desenho E
-- esse item ainda não tem nenhum progresso/expedição lançado (a checagem de
-- "sem progresso" é feita na aplicação antes de chamar o delete).
-- ============================================================================

create policy "itens_delete_pcp_admin" on public.itens
  for delete to authenticated
  using (public.meu_perfil() in ('pcp', 'admin'));
