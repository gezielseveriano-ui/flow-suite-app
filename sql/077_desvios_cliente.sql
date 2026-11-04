-- ============================================================================
-- FactoryView -- Qualidade: Controle de Desvios Cliente.
-- Substitui a aba "Controle de Desvio Cliente" da planilha MG-008.
--
-- tipo = 'rnc'    -> conta no quadro "Reclamação de Cliente -- Controle
--                    Externo de RNC" do Indicador RNCs (tabela e gráfico),
--                    somado aos RNCs com origem = cliente.
-- tipo = 'desvio' -> só fica registrado aqui, sem indicador.
--
-- Numeração: sequencial por ano (01/2026, 02/2026...), por trigger, mesmo
-- padrão do RNC (071) -- usa max()+1 do ano em vez de count()+1.
-- Escrita direta por policy (qualidade/admin), leitura pra todo autenticado.
-- ============================================================================

create table public.desvios_cliente (
  id                     bigint generated always as identity primary key,
  ano_desvio             int,
  numero_desvio          int,

  empresa                text not null check (empresa in ('MDE- ENGENHARIA S/A', 'MDE - EQUIPAMENTOS LTDA')),
  cliente                text,
  pedido_id              bigint references public.pedidos(id),
  desenho                text,
  desenho_cliente        text,
  posicao                text,
  tag                    text,
  tipo                   text not null default 'desvio' check (tipo in ('rnc', 'desvio')),
  data_desvio            date not null default current_date,
  descricao              text,
  prazo_resposta         date,
  responsavel_resposta   text,
  resposta               text,
  prazo_execucao         date,
  custo                  numeric(12,2),
  debito                 text,
  status_desvio          text not null default 'em_aberto' check (status_desvio in ('em_aberto', 'encerrado')),

  criado_por             uuid references public.perfis(id) default auth.uid(),
  criado_em              timestamptz not null default now(),
  atualizado_em          timestamptz not null default now(),

  unique (ano_desvio, numero_desvio)
);

create index idx_desvios_cliente_pedido on public.desvios_cliente(pedido_id);
create index idx_desvios_cliente_ano on public.desvios_cliente(ano_desvio);

create or replace function public.gerar_numero_desvio_cliente()
returns trigger
language plpgsql
as $$
begin
  if new.numero_desvio is not null then
    return new;
  end if;
  new.ano_desvio := extract(year from now())::int;
  select coalesce(max(numero_desvio), 0) + 1 into new.numero_desvio
  from public.desvios_cliente where ano_desvio = new.ano_desvio;
  return new;
end;
$$;

create trigger trg_gerar_numero_desvio_cliente
before insert on public.desvios_cliente
for each row execute function public.gerar_numero_desvio_cliente();

create or replace function public.tocar_atualizado_em_desvio_cliente()
returns trigger
language plpgsql
as $$
begin
  new.atualizado_em := now();
  return new;
end;
$$;

create trigger trg_tocar_atualizado_em_desvio_cliente
before update on public.desvios_cliente
for each row execute function public.tocar_atualizado_em_desvio_cliente();

alter table public.desvios_cliente enable row level security;

create policy "desvios_cliente_select" on public.desvios_cliente
  for select to authenticated
  using (public.autenticado_ativo());

create policy "desvios_cliente_insert_qualidade_admin" on public.desvios_cliente
  for insert to authenticated
  with check (public.meu_perfil() in ('qualidade', 'admin'));

create policy "desvios_cliente_update_qualidade_admin" on public.desvios_cliente
  for update to authenticated
  using (public.meu_perfil() in ('qualidade', 'admin'))
  with check (public.meu_perfil() in ('qualidade', 'admin'));

-- desde 2026-10-30 o Supabase não dá mais grant automático em tabela nova
grant select, insert, update on public.desvios_cliente to authenticated;
grant select, insert, update, delete on public.desvios_cliente to service_role;
