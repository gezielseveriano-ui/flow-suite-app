-- ============================================================================
-- FactoryView -- Exclusão do pedido de teste P-128 (id = 2, Wave Aluminium
-- Brasil S.A) e de tudo que está amarrado nele. Confirmado com o usuário:
-- 16 itens, 2 desenhos de engenharia, 3 remessas, 1 romaneio, 1 tag e 7
-- apontamentos de horas (checado via SELECT antes de rodar isso).
--
-- Nenhuma dessas tabelas apaga em cascata sozinha a partir de `pedidos`
-- (só pedidos_dados_comerciais/pedidos_itens_comerciais, que não existem
-- pra esse pedido) -- por isso a ordem importa: de baixo pra cima, senão a
-- foreign key trava a exclusão. Roda isso de uma vez só (é uma transação:
-- se qualquer linha falhar, nada é apagado).
-- ============================================================================

begin;

-- pedidos_avulsos referenciando desenho OU item deste pedido
delete from public.revisoes_desenho
where desenho_id in (select id from public.desenhos_engenharia where pedido_id = 2)
   or item_id in (select id from public.itens where pedido_id = 2);

-- LI (industrialização) -- não deveria ter nenhuma (industrializacoes=0 no
-- preview), mas limpa por segurança caso algum item tenha entrado numa LI
-- de outro pedido
delete from public.industrializacao_itens
where item_id in (select id from public.itens where pedido_id = 2);
delete from public.industrializacoes where pedido_id = 2;

-- progresso de produção e romaneio (itens expedidos)
delete from public.etapas_avanco
where item_id in (select id from public.itens where pedido_id = 2);
delete from public.romaneio_itens
where item_id in (select id from public.itens where pedido_id = 2);
delete from public.romaneios where pedido_id = 2;

-- horas de colaborador apontadas pra esse pedido
delete from public.apontamentos_horas where pedido_id = 2;

-- itens (precisa vir antes de desenhos_engenharia -- é itens.desenho_engenharia_id
-- que aponta pra lá, não o contrário)
delete from public.itens where pedido_id = 2;

-- desenhos de engenharia (posições, subprodutos e paralisações somem
-- sozinhas, são "on delete cascade")
delete from public.desenhos_engenharia where pedido_id = 2;

-- remessas (agora sem nenhum desenho apontando pra elas)
delete from public.remessas where pedido_id = 2;

-- tags (agora sem nenhum item/desenho apontando pra elas)
delete from public.tags where pedido_id = 2;

-- por fim, o pedido em si
delete from public.pedidos where id = 2;

commit;
