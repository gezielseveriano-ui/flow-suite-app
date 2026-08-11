-- ============================================================================
-- FactoryView -- Permite excluir remessa (Engenharia/Admin). A tabela já
-- tinha select/insert/update, mas nenhuma policy de delete -- sem isso o RLS
-- bloqueia silenciosamente. A FK em desenhos_engenharia.remessa_id (sem
-- cascade) já protege contra excluir remessa com desenho vinculado.
-- ============================================================================

create policy "remessas_delete_engenharia_admin" on public.remessas
  for delete to authenticated
  using (public.meu_perfil() in ('engenharia', 'admin'));
