-- ============================================================================
-- FactoryView -- Roberto Duarte (roberto.duarte@mde.ind.br), diretor da
-- fábrica, passa para o perfil "diretor". Rodar DEPOIS do 081.
-- ============================================================================

update public.perfis
set perfil = 'diretor', ativo = true
where id = '4fbb31e4-fc3f-485f-be61-790e1cdae6a4';

select id, nome, perfil, ativo from public.perfis
where id = '4fbb31e4-fc3f-485f-be61-790e1cdae6a4';
