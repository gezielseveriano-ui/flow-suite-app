-- ============================================================================
-- FactoryView -- Roberto Duarte: cria a linha em public.perfis.
-- O 082 não mudou nada porque a linha não existia (usuário criado só no
-- Supabase Auth; perfis é cadastro manual -- ver 001_schema.sql).
-- Se der erro de foreign key, o id abaixo não é o do usuário no Auth.
-- ============================================================================

insert into public.perfis (id, nome, perfil, ativo)
values ('4fbb31e4-fc3f-485f-be61-790e1cdae6a4', 'Roberto Duarte', 'diretor', true)
on conflict (id) do update set nome = excluded.nome, perfil = excluded.perfil, ativo = true;

-- conferência: tem que voltar 1 linha, perfil diretor, e email_confirmado preenchido
select p.id, p.nome, p.perfil, p.ativo, u.email, u.email_confirmed_at as email_confirmado
from public.perfis p
join auth.users u on u.id = p.id
where p.id = '4fbb31e4-fc3f-485f-be61-790e1cdae6a4';
