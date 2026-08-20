-- ============================================================================
-- FactoryView -- Capacidade de fornecedor terceirizado vira só aviso visual,
-- não bloqueio.
--
-- A regra original (atribuir_fornecedor_producao, ver 059) recusava salvar
-- se a atribuição estourasse a capacidade do fornecedor. Combinado com o
-- usuário: isso deve funcionar exatamente como já funciona pros setores
-- internos hoje -- não existe bloqueio nenhum lá, só o Dashboard pinta a
-- barra de vermelho e mostra "Indisponível" quando passa de 100%. PCP
-- precisa poder mandar acima da capacidade quando for urgência.
--
-- A checagem de capacidade em si não precisa de função nenhuma pra isso
-- (o Dashboard já calcula util>100% sozinho, ver calcSetores/renderCapacidade
-- em dashboard.html) -- só a atribuição do fornecedor no item, que passa a
-- ser um update comum, protegido pela mesma policy itens_update_pcp_admin
-- que já existe (é assim que o campo `produto`/setor também é atualizado,
-- sem RPC nenhuma). Remove a função antiga.
-- ============================================================================

drop function if exists public.atribuir_fornecedor_producao(bigint, bigint);
