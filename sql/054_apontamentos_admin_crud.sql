-- ============================================================================
-- FactoryView -- Admin ganha CRUD completo em apontamentos_horas: útil pra
-- corrigir um lançamento errado sem passar pelo quiosque, e necessário pra
-- gerar cargas de dados em lote (ex: simulação de teste, importação de
-- histórico). O quiosque continua sendo o único caminho pro colaborador
-- comum -- isso só abre uma porta extra pro admin.
-- ============================================================================

create policy "apontamentos_horas_admin_all" on public.apontamentos_horas
  for all to authenticated
  using (public.meu_perfil() = 'admin')
  with check (public.meu_perfil() = 'admin');
