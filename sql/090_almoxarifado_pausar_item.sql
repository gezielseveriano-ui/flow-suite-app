-- ============================================================================
-- FactoryView -- Almoxarifado: PAUSAR a compra de um item.
--
-- Item pausado = "não vou mais comprar/cobrar" (ex.: o material foi achado na
-- própria fábrica). Fica marcado na tela com cor própria e NÃO entra no PDF de
-- cobrança nem no Excel exportado. Despausar volta tudo ao normal.
--
-- Colunas novas, controladas só pelo RPC abaixo -- a reimportação do Sapiens
-- (importar_almoxarifado) não as toca, então o pause sobrevive a uma nova
-- importação. Nenhum dado existente é alterado (tudo nasce "não pausado").
-- ============================================================================

alter table public.almoxarifado_itens
  add column if not exists pausado     boolean not null default false,
  add column if not exists pausado_em  timestamptz,
  add column if not exists pausado_por uuid references auth.users(id);

create or replace function public.pausar_item_almoxarifado(p_id bigint, p_pausado boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.meu_perfil() not in ('almoxarifado', 'logistica', 'admin') then
    raise exception 'Sem permissão para pausar item';
  end if;

  update public.almoxarifado_itens
  set pausado     = coalesce(p_pausado, false),
      pausado_em  = case when coalesce(p_pausado, false) then now() else null end,
      pausado_por = case when coalesce(p_pausado, false) then auth.uid() else null end
  where id = p_id;

  if not found then
    raise exception 'Item não encontrado';
  end if;
end;
$$;

grant execute on function public.pausar_item_almoxarifado(bigint, boolean) to authenticated;
