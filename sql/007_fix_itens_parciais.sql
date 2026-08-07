-- ============================================================================
-- FactoryView -- Corrige status de itens que foram PARCIALMENTE expedidos
-- na planilha antiga (tinham peso_expedido > 0 E ainda peso pendente > 0).
-- Como o sistema novo trata expedicao como binaria (tudo ou nada), esses
-- itens ficaram marcados como "expedido" e seu peso pendente real (coluna Z)
-- nao entrava na conta de "Total em carteira". Marcamos como pendente,
-- ja que ainda ha material real aguardando expedicao.
-- ============================================================================

update public.itens
set status_expedicao = 'pendente'
where status_expedicao = 'expedido'
  and peso_pendente_historico is not null
  and peso_pendente_historico > 0;
