-- ============================================================================
-- FactoryView -- Expedição: permite corrigir/completar a Descrição de um item
-- direto na tela de "Ver itens" de uma LE (ex: descrição veio incompleta do
-- desenho, ou precisa de uma observação a mais antes de gerar o Excel/nota).
--
-- O perfil "expedicao" não tem permissão de UPDATE direto em `itens` (só
-- pcp/admin, ver 003_rls_policies.sql) -- por isso essa é uma função
-- security definer, restrita só ao campo descrição (não deixa mexer em peso/
-- quantidade por aqui, que continua sendo responsabilidade do PCP).
-- ============================================================================

create or replace function public.editar_descricao_item_expedicao(p_item_id bigint, p_descricao text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.meu_perfil() not in ('expedicao', 'admin') then
    raise exception 'Sem permissão para editar item';
  end if;

  update public.itens set descricao = nullif(trim(p_descricao), '') where id = p_item_id;

  if not found then
    raise exception 'Item não encontrado';
  end if;
end;
$$;
