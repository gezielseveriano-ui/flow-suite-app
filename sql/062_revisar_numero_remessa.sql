-- ============================================================================
-- FactoryView -- Permite revisar o NÚMERO de uma remessa já criada (além do
-- nome, que já dava pra editar). Caso de uso: alguém subiu os desenhos numa
-- remessa com o número errado -- em vez de excluir tudo e lançar de novo,
-- só corrige o número.
--
-- Isso precisa de uma função (não um update simples) porque o número da
-- remessa não vive só em `remessas.numero` -- `desenhos_engenharia.remessa`
-- é uma cópia em TEXTO desse número, feita no momento de salvar o desenho
-- (ver comentário na migration 030), e esse texto se propaga de novo pra
-- `itens.remessa` quando o PCP sincroniza (sincronizarItensPCP, em
-- cadastro.html). Nenhum dos dois atualiza sozinho quando `remessas.numero`
-- muda -- por isso a função atualiza os três juntos, na mesma transação.
-- ============================================================================

create or replace function public.revisar_remessa(p_remessa_id bigint, p_novo_numero integer, p_novo_nome text)
returns public.remessas
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.remessas;
begin
  if public.meu_perfil() not in ('engenharia', 'admin') then
    raise exception 'Sem permissão para revisar remessa';
  end if;

  if p_novo_numero is null or p_novo_numero < 1 then
    raise exception 'Número de remessa inválido';
  end if;

  update public.remessas set numero = p_novo_numero, nome = p_novo_nome
  where id = p_remessa_id
  returning * into v_row;

  if v_row.id is null then
    raise exception 'Remessa não encontrada';
  end if;

  update public.desenhos_engenharia set remessa = p_novo_numero::text
  where remessa_id = p_remessa_id;

  update public.itens set remessa = p_novo_numero::text
  where desenho_engenharia_id in (
    select id from public.desenhos_engenharia where remessa_id = p_remessa_id
  );

  return v_row;
end;
$$;
