-- ============================================================================
-- FactoryView — Funções e triggers de regra de negócio
-- Rodar depois do 001_schema.sql
-- ============================================================================

-- ── Helpers de permissão (usados nas policies de RLS) ──────────────────────
-- security definer: consulta perfis ignorando RLS, evitando recursão infinita.

create or replace function public.meu_perfil()
returns public.perfil_usuario
language sql
security definer
stable
set search_path = public
as $$
  select perfil from public.perfis where id = auth.uid()
$$;

create or replace function public.autenticado_ativo()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists(select 1 from public.perfis where id = auth.uid() and ativo)
$$;

-- ── Regra: percentual de etapa só pode subir, nunca retroceder ─────────────

create or replace function public.checar_avanco_etapa()
returns trigger
language plpgsql
as $$
declare
  v_max numeric(5,2);
begin
  select max(percentual) into v_max
  from public.etapas_avanco
  where item_id = new.item_id and etapa = new.etapa;

  if v_max is not null and new.percentual <= v_max then
    raise exception 'Percentual informado (%) deve ser maior que o já registrado (%) para esta etapa', new.percentual, v_max;
  end if;

  return new;
end;
$$;

create trigger trg_checar_avanco_etapa
before insert on public.etapas_avanco
for each row execute function public.checar_avanco_etapa();

-- ── Regra: numero do romaneio = R-{numero_pedido}-{sequencial} ─────────────
-- ex: pedido "P-158" -> romaneios "R-158-01", "R-158-02", ...

create or replace function public.gerar_numero_romaneio()
returns trigger
language plpgsql
as $$
declare
  v_pedido_num text;
  v_seq        int;
begin
  if new.numero is not null then
    return new;
  end if;

  select regexp_replace(numero_pedido, '\D', '', 'g') into v_pedido_num
  from public.pedidos where id = new.pedido_id;

  select count(*) + 1 into v_seq
  from public.romaneios where pedido_id = new.pedido_id;

  new.numero := 'R-' || v_pedido_num || '-' || lpad(v_seq::text, 2, '0');
  return new;
end;
$$;

create trigger trg_gerar_numero_romaneio
before insert on public.romaneios
for each row execute function public.gerar_numero_romaneio();

-- ── RPC: gerar romaneio a partir de uma lista de itens ──────────────────────
-- Usada pelo módulo de Expedição. Garante atomicidade (cria o romaneio E
-- marca os itens como expedidos numa única transação) e garante que todos
-- os itens pertencem ao mesmo pedido informado.

create or replace function public.criar_romaneio(p_pedido_id bigint, p_item_ids bigint[])
returns public.romaneios
language plpgsql
security definer
set search_path = public
as $$
declare
  v_romaneio     public.romaneios;
  v_fora_pedido  int;
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

  return v_romaneio;
end;
$$;
