-- ============================================================================
-- FactoryView — Capacidade mensal por setor (valores atuais da planilha)
-- Rodar depois do 003_rls_policies.sql
-- Pode editar os valores livremente depois, direto pela tela de admin ou
-- pela tabela editor do Supabase — são só os números iniciais.
-- ============================================================================

insert into public.capacidade_setor (setor, capacidade_mensal_ton) values
  ('ESTRUTURA',      25),
  ('USINAGEM',       10),
  ('TAMBOR',         15),
  ('ROLOS',           8),
  ('BASES ROLETES',   5),
  ('REVESTIMENTO',   15),
  ('RMF',            40),
  ('TECMETAL',        0),
  ('CSM',             0),
  ('COMERCIAL',       0)
on conflict (setor) do nothing;
