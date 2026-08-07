-- ============================================================================
-- FactoryView -- Expedicao/Finalizado controlados automaticamente pelo romaneio
-- As etapas "expedicao" e "finalizado" nao devem ser lancadas manualmente no
-- Apontamento. Quando um item entra num romaneio, o sistema marca essas duas
-- etapas em 100% sozinho. RLS tambem passa a bloquear producao de lancar
-- manualmente essas duas etapas (defesa extra, mesmo com a tela ja travada).
-- ============================================================================

-- 1) criar_romaneio agora tambem fecha as etapas expedicao/finalizado
create or replace function public.criar_romaneio(p_pedido_id bigint, p_item_ids bigint[])
returns public.romaneios
language plpgsql
security definer
set search_path = public
as $$
declare
  v_romaneio     public.romaneios;
  v_fora_pedido  int;
  v_item_id      bigint;
  v_etapa        public.etapa_producao;
  v_max          numeric(5,2);
begin
  if public.meu_perfil() not in ('expedicao', 'admin') then
    raise exception 'Sem permissão para gerar romaneio';
  end if;

  select count(*) into v_fora_pedido
  from public.itens
  where id = any(p_item_ids) and pedido_id <> p_pedido_id;

  if v_fora_pedido > 0 then
    raise exception 'Todos os itens selecionados devem pertencer ao mesmo pedido';
  end if;

  insert into public.romaneios (pedido_id, usuario_id)
  values (p_pedido_id, auth.uid())
  returning * into v_romaneio;

  update public.itens
  set status_expedicao = 'expedido', romaneio_id = v_romaneio.id
  where id = any(p_item_ids);

  -- fecha automaticamente as etapas expedicao e finalizado (100%) para cada item
  foreach v_item_id in array p_item_ids loop
    foreach v_etapa in array array['expedicao'::public.etapa_producao, 'finalizado'::public.etapa_producao] loop
      select max(percentual) into v_max
      from public.etapas_avanco
      where item_id = v_item_id and etapa = v_etapa;

      if v_max is null or v_max < 100 then
        insert into public.etapas_avanco (item_id, etapa, percentual, usuario_id)
        values (v_item_id, v_etapa, 100, auth.uid());
      end if;
    end loop;
  end loop;

  return v_romaneio;
end;
$$;

-- 2) RLS: producao nao pode lancar manualmente expedicao/finalizado (admin ainda pode, para correcoes)
drop policy if exists "etapas_insert_producao_admin" on public.etapas_avanco;
create policy "etapas_insert_producao_admin" on public.etapas_avanco
  for insert to authenticated
  with check (
    (public.meu_perfil() = 'admin' and usuario_id = auth.uid())
    or (
      public.meu_perfil() = 'producao'
      and usuario_id = auth.uid()
      and etapa not in ('expedicao', 'finalizado')
    )
  );
