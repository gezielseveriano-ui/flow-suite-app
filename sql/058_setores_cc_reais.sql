-- ============================================================================
-- FactoryView -- Lista real de setores/centro de custo (planilha de RH),
-- deduplicada (cada linha da planilha era um funcionário, o CC repetia por
-- pessoa). Substitui os 2 que tínhamos como exemplo (1101/1102) e adiciona
-- todos os outros. Reparem que alguns setores (ex: "Producao", "Usinagem",
-- "PCP") têm mais de um centro de custo -- são células/turnos diferentes com
-- o mesmo nome de setor, mantidos como linhas separadas de propósito.
-- ============================================================================

insert into public.setores_cc (codigo_cc, nome) values
  ('1101', 'Caldeiraria'),
  ('1102', 'Producao'),
  ('1103', 'Producao'),
  ('1104', 'Producao'),
  ('1108', 'Producao'),
  ('1112', 'Manut. Ferroviaria (MRS)'),
  ('1113', 'Producao'),
  ('1202', 'PCP'),
  ('1203', 'PCP'),
  ('1205', 'Logistica'),
  ('1206', 'Logistica'),
  ('1207', 'Logistica'),
  ('1210', 'PCP'),
  ('1302', 'Qualidade'),
  ('1303', 'Qualidade'),
  ('1304', 'Engenharia'),
  ('1401', 'Administrativo'),
  ('1402', 'Administrativo'),
  ('1403', 'Administrativo'),
  ('1',    'Usinagem'),
  ('3',    'Usinagem'),
  ('7',    'Usinagem'),
  ('10',   'Eletrica'),
  ('21',   'Montagem'),
  ('27',   'Pintura'),
  ('41',   'Testes'),
  ('44',   'Eletrica')
on conflict (codigo_cc) do update set nome = excluded.nome;
