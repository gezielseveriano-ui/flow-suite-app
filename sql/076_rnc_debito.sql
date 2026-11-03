-- 076: campo "Débito" no RNC (ao lado de "Origem do RNC").
-- Texto livre com sugestões na tela (ENGENHARIA, PCP, FÁBRICA...): indica
-- qual setor/empresa recebe o débito da não conformidade.
-- Só adiciona coluna em tabela existente -- não precisa de GRANT novo.

alter table public.rnc add column if not exists debito text;
