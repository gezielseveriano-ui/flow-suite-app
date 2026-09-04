-- ============================================================================
-- FactoryView -- "Arquivar pedido" no Dashboard, igual ao dashboard antigo da
-- planilha (aba MICRO). Lá isso ficava só no localStorage do navegador,
-- porque aquele dashboard não tinha backend pra compartilhar entre PCs. Aqui
-- vira uma coluna de verdade -- arquivar num PC aparece arquivado pra todo
-- mundo que abre o Dashboard, em vez de só na máquina de quem clicou.
--
-- Efeito: pedido arquivado some da lista "Todos os pedidos" e não entra mais
-- na Capacidade de Produção (carga programada/expedido/líquida por setor),
-- mas continua consultável em "Pedidos arquivados". Puramente organizacional
-- -- não apaga nem bloqueia nada, só tira da conta corrente.
-- ============================================================================

alter table public.pedidos
  add column if not exists arquivado boolean not null default false;

create or replace function public.arquivar_pedido(p_pedido_id bigint, p_arquivado boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.meu_perfil() not in ('pcp', 'admin') then
    raise exception 'Sem permissão para arquivar pedido';
  end if;

  update public.pedidos set arquivado = p_arquivado where id = p_pedido_id;

  if not found then
    raise exception 'Pedido não encontrado';
  end if;
end;
$$;
