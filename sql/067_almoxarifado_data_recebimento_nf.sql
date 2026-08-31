-- ============================================================================
-- FactoryView -- Almoxarifado: campo manual "Data de recebimento da NF".
-- Mesma regra dos outros campos manuais (quantidade_recebida/nf/observacao):
-- só entra pelo RPC editar_recebimento_almoxarifado, a reimportação do
-- Sapiens nunca toca aqui (não faz parte do INSERT/UPDATE de importar_almoxarifado).
-- ============================================================================

alter table public.almoxarifado_itens
  add column if not exists data_recebimento_nf date;

-- adiciona o novo parâmetro no fim, com default -- PostgREST continua
-- funcionando pra quem já chamava com os 4 parâmetros antigos.
create or replace function public.editar_recebimento_almoxarifado(
  p_id bigint, p_quantidade_recebida numeric, p_nf text, p_observacao text,
  p_data_recebimento_nf date default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.meu_perfil() not in ('almoxarifado', 'admin') then
    raise exception 'Sem permissão para editar recebimento';
  end if;
  if p_quantidade_recebida is null or p_quantidade_recebida < 0 then
    raise exception 'Quantidade recebida inválida';
  end if;

  update public.almoxarifado_itens
  set quantidade_recebida = p_quantidade_recebida,
      nf                  = nullif(trim(p_nf), ''),
      observacao          = nullif(trim(p_observacao), ''),
      data_recebimento_nf = p_data_recebimento_nf,
      updated_at          = now()
  where id = p_id;

  if not found then
    raise exception 'Item não encontrado';
  end if;
end;
$$;
