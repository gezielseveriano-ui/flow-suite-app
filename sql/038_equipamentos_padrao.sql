-- ============================================================================
-- FactoryView -- Engenharia: catálogo padrão de equipamentos (independente do
-- tamanho do transportador, os equipamentos que o compõem são sempre os
-- mesmos — muda quantidade/dimensão, não o item em si). Substitui o campo de
-- texto livre "Nome do equipamento" por uma lista padronizada, agrupada por
-- categoria, evitando duplicidade tipo "Tambor de Acionamento" vs "Tambor
-- Acionamento".
-- ============================================================================

create type public.categoria_equipamento as enum (
  'CABECA', 'TRONCO', 'CAUDA', 'TAMBORES_DIVERSOS',
  'ELETRICO_INSTRUMENTACAO', 'SEGURANCA_PROTECOES', 'OUTROS'
);

create table public.equipamentos_padrao (
  id          bigint generated always as identity primary key,
  nome        text not null unique,
  categoria   public.categoria_equipamento not null default 'OUTROS',
  created_at  timestamptz not null default now(),
  created_by  uuid references public.perfis(id) default auth.uid()
);

create index idx_equipamentos_padrao_categoria on public.equipamentos_padrao(categoria);

alter table public.equipamentos_padrao enable row level security;

create policy "equipamentos_padrao_select" on public.equipamentos_padrao
  for select to authenticated
  using (public.autenticado_ativo());

-- mesmo perfil que já cadastra desenho na Engenharia (ver 029_perfil_engenharia.sql)
create policy "equipamentos_padrao_insert" on public.equipamentos_padrao
  for insert to authenticated
  with check (public.meu_perfil() in ('engenharia', 'pcp', 'admin'));

create policy "equipamentos_padrao_update" on public.equipamentos_padrao
  for update to authenticated
  using (public.meu_perfil() in ('engenharia', 'pcp', 'admin'));

-- liga o desenho ao equipamento padrão escolhido -- mantém nome_equipamento
-- (texto) em paralelo, sincronizado automaticamente pelo formulário, pra não
-- quebrar as telas que já leem esse campo (cadastro.html, PDF/email...).
alter table public.desenhos_engenharia
  add column if not exists equipamento_id bigint references public.equipamentos_padrao(id);

-- ── Lista inicial ────────────────────────────────────────────────────────
insert into public.equipamentos_padrao (nome, categoria) values
  -- Cabeça (Head Chute / Head Pulley)
  ('Tambor de acionamento', 'CABECA'),
  ('Tambor de encosto', 'CABECA'),
  ('Chute de descarga', 'CABECA'),
  ('Raspador de correia (primário/secundário/terciário)', 'CABECA'),
  ('Raspador de tambor (V-plow)', 'CABECA'),
  ('Proteção/carenagem do tambor', 'CABECA'),
  ('Guincho de emergência / soft-starter', 'CABECA'),
  -- Tronco (Corpo)
  ('Pontes treliçadas', 'TRONCO'),
  ('Colunas de sustentação', 'TRONCO'),
  ('Roletes de carga', 'TRONCO'),
  ('Roletes de retorno', 'TRONCO'),
  ('Roletes de impacto', 'TRONCO'),
  ('Roletes autoalinhantes', 'TRONCO'),
  ('Correia transportadora', 'TRONCO'),
  ('Guias de material (skirt boards)', 'TRONCO'),
  ('Chapas de desgaste', 'TRONCO'),
  ('Guarda-corpo e rodapé', 'TRONCO'),
  ('Passarela', 'TRONCO'),
  ('Escadas de acesso e plataformas', 'TRONCO'),
  ('Sistema de cobertura (capotas)', 'TRONCO'),
  -- Cauda
  ('Tambor de cauda', 'CAUDA'),
  ('Chute de carga / moega', 'CAUDA'),
  ('Sistema de tensionamento', 'CAUDA'),
  ('Tambor esticador', 'CAUDA'),
  -- Tambores Diversos
  ('Tambor de desvio (bend pulley)', 'TAMBORES_DIVERSOS'),
  ('Tambor de flexão/quebra', 'TAMBORES_DIVERSOS'),
  ('Tambor prensa-correia (snub pulley)', 'TAMBORES_DIVERSOS'),
  -- Sistema Elétrico e Instrumentação
  ('Motor elétrico de acionamento', 'ELETRICO_INSTRUMENTACAO'),
  ('Redutor', 'ELETRICO_INSTRUMENTACAO'),
  ('Acoplamento', 'ELETRICO_INSTRUMENTACAO'),
  ('Freio', 'ELETRICO_INSTRUMENTACAO'),
  ('Suporte de chave elétrica', 'ELETRICO_INSTRUMENTACAO'),
  ('Chave de emergência (pull cord)', 'ELETRICO_INSTRUMENTACAO'),
  ('Sensor de desalinhamento de correia', 'ELETRICO_INSTRUMENTACAO'),
  ('Sensor de velocidade zero', 'ELETRICO_INSTRUMENTACAO'),
  ('Detector de rasgo longitudinal', 'ELETRICO_INSTRUMENTACAO'),
  ('Chave de nível', 'ELETRICO_INSTRUMENTACAO'),
  ('Sistema de alarme sonoro/luminoso', 'ELETRICO_INSTRUMENTACAO'),
  ('Sensor de rotação de tambor', 'ELETRICO_INSTRUMENTACAO'),
  -- Segurança e Proteções
  ('Proteções de tambores e polias', 'SEGURANCA_PROTECOES'),
  ('Proteções de acoplamento', 'SEGURANCA_PROTECOES'),
  ('Guarda-corpo lateral', 'SEGURANCA_PROTECOES'),
  ('Sinalização de segurança', 'SEGURANCA_PROTECOES'),
  -- Outros
  ('Sistema de lubrificação de mancais', 'OUTROS'),
  ('Mancais/rolamentos', 'OUTROS'),
  ('Selo/vedação de mancais', 'OUTROS'),
  ('Sistema de aspersão de água', 'OUTROS'),
  ('Balança de correia', 'OUTROS'),
  ('Detector de metais', 'OUTROS'),
  ('Sistema de limpeza automática (varredor de retorno)', 'OUTROS')
on conflict (nome) do nothing;
