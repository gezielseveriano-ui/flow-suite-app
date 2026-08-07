-- ============================================================================
-- FactoryView -- Expedicao parcial por quantidade (romaneio_itens)
-- Rodar depois do 010_status_parcial.sql
-- ============================================================================

-- 1) Nova tabela: cada linha é um item + quantidade expedida NUM romaneio
--    especifico. Um mesmo item pode aparecer em varios romaneios (expedicao
--    parcial em datas diferentes).
create table public.romaneio_itens (
  id                  bigint generated always as identity primary key,
  romaneio_id         bigint not null references public.romaneios(id) on delete cascade,
  item_id             bigint not null references public.itens(id),
  quantidade_expedida numeric(12,3) not null check (quantidade_expedida > 0),
  peso_unitario       numeric(12,3) not null,
  peso_total          numeric(14,3) generated always as (quantidade_expedida * peso_unitario) stored,
  created_at          timestamptz not null default now()
);

create index idx_romaneio_itens_romaneio on public.romaneio_itens(romaneio_id);
create index idx_romaneio_itens_item on public.romaneio_itens(item_id);

alter table public.romaneio_itens enable row level security;

create policy "romaneio_itens_select" on public.romaneio_itens
  for select to authenticated
  using (public.autenticado_ativo());

-- inserts normais acontecem via criar_romaneio (security definer); esta
-- policy cobre insert direto por quem tem permissao de expedicao.
create policy "romaneio_itens_insert_expedicao_admin" on public.romaneio_itens
  for insert to authenticated
  with check (public.meu_perfil() in ('expedicao', 'admin'));

-- 2) Migra os vinculos antigos (itens.romaneio_id) para a tabela nova antes
--    de remover a coluna -- preserva o historico dos romaneios ja gerados.
insert into public.romaneio_itens (romaneio_id, item_id, quantidade_expedida, peso_unitario, created_at)
select romaneio_id, id, quantidade, peso_unitario, created_at
from public.itens
where romaneio_id is not null;

-- itens.romaneio_id não faz mais sentido (um item pode estar em vários
-- romaneios). A relação agora vive só em romaneio_itens.
alter table public.itens drop column if exists romaneio_id;

-- 3) Numero do romaneio no formato "LE 001", sequencial por pedido
create or replace function public.gerar_numero_romaneio()
returns trigger
language plpgsql
as $$
declare
  v_seq int;
begin
  if new.numero is not null then
    return new;
  end if;

  select count(*) + 1 into v_seq
  from public.romaneios where pedido_id = new.pedido_id;

  new.numero := 'LE ' || lpad(v_seq::text, 3, '0');
  return new;
end;
$$;
-- (trigger trg_gerar_numero_romaneio já existe apontando pra essa função, não precisa recriar)

-- 4) criar_romaneio: agora recebe quantidade por item (nao so a lista de ids)
--    p_itens = '[{"item_id": 123, "quantidade": 5}, ...]'::jsonb
drop function if exists public.criar_romaneio(bigint, bigint[]);

create or replace function public.criar_romaneio(p_pedido_id bigint, p_itens jsonb)
returns public.romaneios
language plpgsql
security definer
set search_path = public
as $$
declare
  v_romaneio     public.romaneios;
  v_fora_pedido  int;
  v_item         jsonb;
  v_item_id      bigint;
  v_qtd          numeric(12,3);
  v_peso_unit    numeric(12,3);
  v_qtd_cadastro numeric(12,3);
  v_qtd_total_exp numeric(12,3);
  v_max_exp      numeric(5,2);
  v_max_fin      numeric(5,2);
begin
  if public.meu_perfil() not in ('expedicao', 'admin') then
    raise exception 'Sem permissão para gerar romaneio';
  end if;

  select count(*) into v_fora_pedido
  from public.itens
  where id = any(array(select (elem->>'item_id')::bigint from jsonb_array_elements(p_itens) elem))
    and pedido_id <> p_pedido_id;

  if v_fora_pedido > 0 then
    raise exception 'Todos os itens selecionados devem pertencer ao mesmo pedido';
  end if;

  insert into public.romaneios (pedido_id, usuario_id)
  values (p_pedido_id, auth.uid())
  returning * into v_romaneio;

  for v_item in select * from jsonb_array_elements(p_itens) loop
    v_item_id := (v_item->>'item_id')::bigint;
    v_qtd     := (v_item->>'quantidade')::numeric;

    if v_qtd is null or v_qtd <= 0 then
      raise exception 'Quantidade inválida para o item %', v_item_id;
    end if;

    select peso_unitario, quantidade into v_peso_unit, v_qtd_cadastro
    from public.itens where id = v_item_id;

    insert into public.romaneio_itens (romaneio_id, item_id, quantidade_expedida, peso_unitario)
    values (v_romaneio.id, v_item_id, v_qtd, v_peso_unit);

    -- soma tudo que já foi expedido desse item (incluindo o que acabou de entrar)
    select coalesce(sum(quantidade_expedida), 0) into v_qtd_total_exp
    from public.romaneio_itens where item_id = v_item_id;

    update public.itens
    set status_expedicao = case
      when v_qtd_total_exp >= v_qtd_cadastro then 'expedido'::status_expedicao_enum
      else 'parcial'::status_expedicao_enum
    end
    where id = v_item_id;

    -- avanço da etapa "expedicao" acompanha o % expedido; "finalizado" só fecha 100% quando o item está totalmente expedido
    select max(percentual) into v_max_exp from public.etapas_avanco where item_id = v_item_id and etapa = 'expedicao';
    if v_qtd_cadastro > 0 then
      if v_max_exp is null or least(100, round(v_qtd_total_exp / v_qtd_cadastro * 100)) > v_max_exp then
        insert into public.etapas_avanco (item_id, etapa, percentual, usuario_id)
        values (v_item_id, 'expedicao', least(100, round(v_qtd_total_exp / v_qtd_cadastro * 100)), auth.uid());
      end if;
    end if;

    if v_qtd_total_exp >= v_qtd_cadastro then
      select max(percentual) into v_max_fin from public.etapas_avanco where item_id = v_item_id and etapa = 'finalizado';
      if v_max_fin is null or v_max_fin < 100 then
        insert into public.etapas_avanco (item_id, etapa, percentual, usuario_id)
        values (v_item_id, 'finalizado', 100, auth.uid());
      end if;
    end if;
  end loop;

  return v_romaneio;
end;
$$;
