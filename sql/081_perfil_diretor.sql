-- ============================================================================
-- FactoryView -- novo perfil "diretor" (diretor da fábrica).
-- Só visualização em: Dashboard, Almoxarifado, Qualidade, Produção,
-- Expedição e Apontamento de Horas. Sem acesso a Contratos, Engenharia,
-- PCP e Industrialização.
-- Nenhuma policy de escrita inclui 'diretor', então o banco já barra
-- qualquer alteração -- as páginas só escondem os botões.
--
-- Rodar SOZINHO (ALTER TYPE ADD VALUE precisa estar em sua própria
-- transação antes de o valor poder ser usado). Depois rode o 082.
-- ============================================================================

alter type public.perfil_usuario add value if not exists 'diretor';
