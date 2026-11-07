-- ============================================================================
-- FactoryView -- Importa a planilha MG-008 (Gestão de Não Conformidades 2026)
-- abas "Controle de RNCs" e "Controle de Desvio Cliente" para o módulo Qualidade.
-- 1) apaga os registros de teste (RNC 01 TESTE, desvios 01 e 02 "teste")
-- 2) RNCs do Vagner já lançados no sistema: 02 -> 10/2026, 03 -> 11/2026
-- 3) importa os RNCs 01 a 09 e os desvios 01 a 53 com o número da planilha
--    (desvios 35 e 53 aparecem 2x na planilha: o 2º de cada vira 54 e 55)
-- Pedidos que não existem no sistema (128, 129, 132, 133, 188, 190) ficam
-- sem pedido; o número vai escrito no texto (observações / descrição).
-- Tudo numa transação: se der erro, nada muda.
-- ============================================================================
begin;

delete from public.rnc where id = 1 and fornecedor = 'TESTE FORNECEDOR';
delete from public.desvios_cliente where id in (1, 2) and descricao = 'teste';

update public.rnc set numero_rnc = 10 where id = 2 and numero_rnc = 2;
update public.rnc set numero_rnc = 11 where id = 3 and numero_rnc = 3;

insert into public.rnc (ano_rnc, numero_rnc, empresa, pedido_id, fornecedor, tipo_desvio, responsavel_nc, ordem_compra, item_oc, nota_fiscal, desenho, revisao, posicao, especificacao_tecnica, item, quantidade_inspecionada, quantidade_segregada, unidade_medida, especificado, encontrado, observacoes, local_nc, emitido_por, data_abertura, causa, origem_rnc, responsavel_disposicao, disposicao, descricao_disposicao, prazo_execucao, verificacao_eficacia, data_verificacao, custo, debito, status_nc)
values (2026, 1, 'MDE- ENGENHARIA S/A', null, 'MDE', 'ENGENHARIA/DESENHO', 'ENGENHARIA', null, null, null, 'L-072468-1', '0', '72468E', 'DESENHO DETALHE', '50', 1, 1, 'PEÇA', 'PARAFUSO ESC. SEXT. INT. Ø5/8" X 2" RT PARA MONTAGEM DA CHAPA DE DESGASTE 72468E', 'O PARAFUSO NÃO APRESENTOU ASSENTAMENTO ADEQUADO NO ESCAREADO DA CHAPA', 'Pedido 132 (não cadastrado no sistema)', 'MONTAGEM MDE', 'VAGNER LUCIO', '2026-02-17', null, 'interno', 'GABRIEL', null, null, '2025-02-20', null, null, null, null, 'em_aberto');
insert into public.rnc (ano_rnc, numero_rnc, empresa, pedido_id, fornecedor, tipo_desvio, responsavel_nc, ordem_compra, item_oc, nota_fiscal, desenho, revisao, posicao, especificacao_tecnica, item, quantidade_inspecionada, quantidade_segregada, unidade_medida, especificado, encontrado, observacoes, local_nc, emitido_por, data_abertura, causa, origem_rnc, responsavel_disposicao, disposicao, descricao_disposicao, prazo_execucao, verificacao_eficacia, data_verificacao, custo, debito, status_nc)
values (2026, 2, 'MDE- ENGENHARIA S/A', null, 'MDE', 'ENGENHARIA/DESENHO', 'ENGENHARIA', null, null, null, 'L-071898-4', '1', null, 'DESENHO DETALHE', '800/801/82', 1, 1, null, 'DESENHO DE DETALHE EINFORMANDO QUANTIDADE DE PARAFUSOS SUFICIENTES PARA MONTAGEM DAS CHAPAS DE DESGASTE', 'QUANTDADE DE PARAFUSO COM PORCA E ARRUELA NO DESENHO ESTA INCORRETA', 'Pedido 129 (não cadastrado no sistema)', 'MONTAGEM OBRA', 'VAGNER LUCIO', '2026-03-12', 'ERRO AO DIGITAR QUANTIDADE CORRETA NA TABELA DO DESENHO', 'interno', 'GABRIEL', null, null, null, null, null, null, null, 'encerrado');
insert into public.rnc (ano_rnc, numero_rnc, empresa, pedido_id, fornecedor, tipo_desvio, responsavel_nc, ordem_compra, item_oc, nota_fiscal, desenho, revisao, posicao, especificacao_tecnica, item, quantidade_inspecionada, quantidade_segregada, unidade_medida, especificado, encontrado, observacoes, local_nc, emitido_por, data_abertura, causa, origem_rnc, responsavel_disposicao, disposicao, descricao_disposicao, prazo_execucao, verificacao_eficacia, data_verificacao, custo, debito, status_nc)
values (2026, 3, 'MDE- ENGENHARIA S/A', (select id from public.pedidos where numero_pedido='P-198'), 'TAKONO', 'QUALIDADE', 'FORNECEDOR', '2640', null, '939925', '73198', null, null, 'DESENHO DETALHE', null, 9, 9, 'PÇ', 'Perfil U 203,2 x 5,59 mm ASTM A36 x 6000 ( 9x )', 'MATERIAL FORNECIDO ( PERFIL U 203,2 X 5,59 )  APRESENTANDO EMPENO', null, 'RECEBIMENTO MDE', 'LUCAS VIEIRA', '2026-06-25', null, 'fornecedor', 'FORNECEDOR TAKONO', null, null, '2026-06-30', null, null, null, null, 'em_aberto');
insert into public.rnc (ano_rnc, numero_rnc, empresa, pedido_id, fornecedor, tipo_desvio, responsavel_nc, ordem_compra, item_oc, nota_fiscal, desenho, revisao, posicao, especificacao_tecnica, item, quantidade_inspecionada, quantidade_segregada, unidade_medida, especificado, encontrado, observacoes, local_nc, emitido_por, data_abertura, causa, origem_rnc, responsavel_disposicao, disposicao, descricao_disposicao, prazo_execucao, verificacao_eficacia, data_verificacao, custo, debito, status_nc)
values (2026, 4, 'MDE- ENGENHARIA S/A', (select id from public.pedidos where numero_pedido='P-198'), 'MDE', 'ENGENHARIA/DESENHO', 'ENGENHARIA', null, null, null, null, null, null, 'DESENHO DETALHE', null, 1, 1, 'PÇ', 'Fixaçoes (Parafuso, Porca e Arruela deverão ser fornecidos com acabamento GEOMET 500 Gr. A, conforme PIT e Especificação Tecnica do Cliente.', 'Desenhos foram enviados para fabricação / compra especificando parafusos com acabamento Galvanizado divergete ao PIT e Especificação Tecnica do clinete', null, 'ENGENHARIA MDE', 'VAGNER LUCIO', '2026-07-10', null, 'interno', 'ENGENHARIA', null, null, null, null, null, null, null, 'em_aberto');
insert into public.rnc (ano_rnc, numero_rnc, empresa, pedido_id, fornecedor, tipo_desvio, responsavel_nc, ordem_compra, item_oc, nota_fiscal, desenho, revisao, posicao, especificacao_tecnica, item, quantidade_inspecionada, quantidade_segregada, unidade_medida, especificado, encontrado, observacoes, local_nc, emitido_por, data_abertura, causa, origem_rnc, responsavel_disposicao, disposicao, descricao_disposicao, prazo_execucao, verificacao_eficacia, data_verificacao, custo, debito, status_nc)
values (2026, 5, 'MDE- ENGENHARIA S/A', (select id from public.pedidos where numero_pedido='P-198'), 'TAKONO', 'QUALIDADE', 'FORNECEDOR', '2339', null, '938472', null, null, null, 'DESENHO DETALHE', null, 1, 1, 'PÇ', 'Chapa 3/8" conforme especificação.', 'Recebida chapa de 3/8" apresentando defeito de dupla laminação.', null, 'RECEBIMENTO MDE', 'MARCIO SOARES', '2026-07-10', null, 'fornecedor', 'FORNECEDOR TAKONO', null, null, '2026-07-14', null, null, null, null, 'em_aberto');
insert into public.rnc (ano_rnc, numero_rnc, empresa, pedido_id, fornecedor, tipo_desvio, responsavel_nc, ordem_compra, item_oc, nota_fiscal, desenho, revisao, posicao, especificacao_tecnica, item, quantidade_inspecionada, quantidade_segregada, unidade_medida, especificado, encontrado, observacoes, local_nc, emitido_por, data_abertura, causa, origem_rnc, responsavel_disposicao, disposicao, descricao_disposicao, prazo_execucao, verificacao_eficacia, data_verificacao, custo, debito, status_nc)
values (2026, 6, 'MDE- ENGENHARIA S/A', (select id from public.pedidos where numero_pedido='P-198'), 'MDE', 'ENGENHARIA/DESENHO', 'ENGENHARIA', null, null, null, 'T-073240-1', null, '73240A', 'DESENHO DETALHE', null, 1, 1, 'PÇ', 'FABRICAÇÃO DO CHASSI DE RETORNO CONFORME DESENHO T-043240-1 REV. 2', 'FABRICAÇÃO DO CHASSI DE RETORNO CONFORME DESENHO T-043240-1 REV. 1', 'REVISÃO SOLICITADA APOS O TERMMINO  DA FABRICAÇÃO', 'FABRICA MDE', 'MARCIO SOARES', '2026-08-03', null, 'interno', 'ENGENHARIA', null, null, '2026-08-07', null, null, null, null, 'em_aberto');
insert into public.rnc (ano_rnc, numero_rnc, empresa, pedido_id, fornecedor, tipo_desvio, responsavel_nc, ordem_compra, item_oc, nota_fiscal, desenho, revisao, posicao, especificacao_tecnica, item, quantidade_inspecionada, quantidade_segregada, unidade_medida, especificado, encontrado, observacoes, local_nc, emitido_por, data_abertura, causa, origem_rnc, responsavel_disposicao, disposicao, descricao_disposicao, prazo_execucao, verificacao_eficacia, data_verificacao, custo, debito, status_nc)
values (2026, 7, 'MDE- ENGENHARIA S/A', (select id from public.pedidos where numero_pedido='P-198'), 'MDE', 'ENGENHARIA/DESENHO', 'ENGENHARIA', null, null, null, 'T-073243-1', null, '73243A', 'DESENHO DETALHE', null, 1, 1, 'PÇ', 'FABRICAÇÃO DA PONTE TRELIÇADA CONFORME DESENHO T-043243-1 REV. 4', 'FABRICAÇÃO DA PONTE TRELIÇADA CONFORME DESENHO T-043243-1 REV. 3', 'REVISÃO SOLICITADA APOS O TERMMINO  DA FABRICAÇÃO', 'FABRICA MDE', 'MARCIO SOARES', '2026-08-03', null, 'interno', 'ENGENHARIA', null, null, '2026-08-07', null, null, null, null, 'em_aberto');
insert into public.rnc (ano_rnc, numero_rnc, empresa, pedido_id, fornecedor, tipo_desvio, responsavel_nc, ordem_compra, item_oc, nota_fiscal, desenho, revisao, posicao, especificacao_tecnica, item, quantidade_inspecionada, quantidade_segregada, unidade_medida, especificado, encontrado, observacoes, local_nc, emitido_por, data_abertura, causa, origem_rnc, responsavel_disposicao, disposicao, descricao_disposicao, prazo_execucao, verificacao_eficacia, data_verificacao, custo, debito, status_nc)
values (2026, 8, 'MDE- ENGENHARIA S/A', (select id from public.pedidos where numero_pedido='P-211'), 'NORTE AÇO', 'QUALIDADE', 'FORNECEDOR', '2769', null, '37351', 'DW-0406-001-D', 'D', null, 'DESENHO DETALHE', 'ITEM 2', 2, 1, 'PÇ', 'Chapa 9"  ASTM A36 Preta Lisa Ø1196 x Ø460mm', 'Chapa 9" apresentando trincas e heterogeneidade de dureza na chapa, com variações significativas entre pontos de medição próximos, apresentando regiões de alta e baixa dureza', null, 'FABRICA MDE', 'LUCIO EVANGELISTA', '2026-09-16', null, 'fornecedor', 'FORNECEDOR NORTE AÇO', 'devolver_fornecedor', 'REALIZAR TROCA DOMATERIAL', '2026-09-21', 'reprovado', '2026-10-15', 5120, null, 'encerrado');
insert into public.rnc (ano_rnc, numero_rnc, empresa, pedido_id, fornecedor, tipo_desvio, responsavel_nc, ordem_compra, item_oc, nota_fiscal, desenho, revisao, posicao, especificacao_tecnica, item, quantidade_inspecionada, quantidade_segregada, unidade_medida, especificado, encontrado, observacoes, local_nc, emitido_por, data_abertura, causa, origem_rnc, responsavel_disposicao, disposicao, descricao_disposicao, prazo_execucao, verificacao_eficacia, data_verificacao, custo, debito, status_nc)
values (2026, 9, 'MDE- ENGENHARIA S/A', (select id from public.pedidos where numero_pedido='P-211'), 'NORTE AÇO', 'QUALIDADE', 'FORNECEDOR', '2769', null, '37629', 'DW-0406-001-D', 'D', null, 'DESENHO DETALHE', 'ITEM 2', 1, 1, 'PÇ', 'Chapa 9"  ASTM A36 Preta Lisa Ø1196 x Ø460mm', 'Chapa 9" apresentando trincas', 'MATERIAL DE SUBSTITUIÇÃO 
RNC 08/2026', 'FABRICA MDE', 'LUCIO EVANGELISTA', '2026-09-16', null, 'fornecedor', 'FORNECEDOR NORTE AÇO', null, null, null, null, null, null, null, 'encerrado');

insert into public.desvios_cliente (ano_desvio, numero_desvio, empresa, cliente, pedido_id, desenho, desenho_cliente, posicao, tag, tipo, data_desvio, descricao, prazo_resposta, responsavel_resposta, resposta, prazo_execucao, custo, debito, status_desvio)
values (2026, 1, 'MDE- ENGENHARIA S/A', 'NEW WAVE', null, 'T-071429-1', null, 'C', '130-TR-005', 'desvio', '2026-02-19', '[Tipo: DIVERGÊNCIA ROMANEIO / MATERIAL · Origem: MDE - LOGISTICA · Pedido 128 (não cadastrado no sistema)]
•	O romaneio LE 006 - Correia, enviado por email está divergente do romaneio físico recebido juntamente com a carga. A conferência foi realizada pelo romaneio trazido pelo motorista.
•	Foram identificadas 2 unidades desta peça identificada na foto em anexo, que não consta em nenhum dos romaneios. A ICEC, favor identificar o material.', '2026-02-24', 'ESTEVÃO - LOGISTICA', 'MATERIAL ENVIADO NA LE 005 (ITEM 162, VOLUME 4),', '2026-02-23', null, null, 'encerrado');
insert into public.desvios_cliente (ano_desvio, numero_desvio, empresa, cliente, pedido_id, desenho, desenho_cliente, posicao, tag, tipo, data_desvio, descricao, prazo_resposta, responsavel_resposta, resposta, prazo_execucao, custo, debito, status_desvio)
values (2026, 2, 'MDE- ENGENHARIA S/A', 'NEW WAVE', null, 'T-072339-1
T-072337-1
T-072322-1
T-072314-1
T-072332-1
T-072330-1', null, null, '120-AL-001
120-TR-002
110-TR-001
110-AL-001', 'desvio', '2026-02-19', '[Tipo: DIVERGÊNCIA ROMANEIO / MATERIAL · Origem: MDE - LOGISTICA · Pedido 133 (não cadastrado no sistema)]
•	O item 142 - Arruela cônica 5/8" ASTM-A307 PEDIDO 133 DES.072383-1 110-TR-001. 
•	No físico veio como arruela "cunha" - verificar se foi apenas um erro de digitação.
•	 Os itens 174 a 179 que se referem a contra pinos de 8x45, no somatório geral seriam 68 peças, foram identificadas apenas 16 unidades. Favor verificar.', '2026-02-24', 'ESTEVÃO - LOGISTICA', 'ITEM 142 - MATERIAL CORRETO NO FISICO, DESENHO E LE 005 SERÃO REVISADOS.
ITENS 174 A 179 - OS CONTRAPINOS NÃO LOCALIZADOS FORAM ENVIDOS MONTADOS NOS PINOS CORRESPONDENTES.', '2026-02-23', null, null, 'encerrado');
insert into public.desvios_cliente (ano_desvio, numero_desvio, empresa, cliente, pedido_id, desenho, desenho_cliente, posicao, tag, tipo, data_desvio, descricao, prazo_resposta, responsavel_resposta, resposta, prazo_execucao, custo, debito, status_desvio)
values (2026, 3, 'MDE- ENGENHARIA S/A', 'NEW WAVE', null, 'T-072383-1', null, '15', '110-TR-001', 'desvio', '2026-02-27', '[Tipo: PENDENCIA DE MATERIAL OBRA · Origem: MDE - FÁBRICA · Pedido 133 (não cadastrado no sistema)]
Item 15 do desenho T-072383-1 não localizado na Obra', '2026-03-03', 'ESTEVÃO - LOGISTICA', 'Material expedido no romaneio LE 008', '2026-03-03', null, null, 'encerrado');
insert into public.desvios_cliente (ano_desvio, numero_desvio, empresa, cliente, pedido_id, desenho, desenho_cliente, posicao, tag, tipo, data_desvio, descricao, prazo_resposta, responsavel_resposta, resposta, prazo_execucao, custo, debito, status_desvio)
values (2026, 4, 'MDE- ENGENHARIA S/A', 'NEW WAVE', null, 'L-071898-4', '0701-MDE-0130-DT-00078', '800/801/802', '130-EC-001
130-EC-002
130-EC-003
130-EC-004', 'desvio', '2026-03-12', '[Tipo: ENGENHARIA/DESENHO · Origem: MDE - ENGENHARIA · Pedido 129 (não cadastrado no sistema)]
DESENHO DE DETALHE EINFORMANDO QUANTIDADE DE PARAFUSOS DIVERGENTE AO  NECESSARIO PARA  MONTAGEM DAS CHAPAS DE DESGASTE', '2026-03-12', 'GABRIEL - ENGENHARIA', 'REVISAR DESENHO INFORMANDO QUANTIDADE CORRETA - MATERIAL ENVIADO LE 006 ITEM 31, 33, 36', '2026-03-12', null, null, 'encerrado');
insert into public.desvios_cliente (ano_desvio, numero_desvio, empresa, cliente, pedido_id, desenho, desenho_cliente, posicao, tag, tipo, data_desvio, descricao, prazo_resposta, responsavel_resposta, resposta, prazo_execucao, custo, debito, status_desvio)
values (2026, 5, 'MDE- ENGENHARIA S/A', 'NEW WAVE', null, 'L-071894-4', '0701-MDE-0130-DT-00074', '800/801/802', '130-EC-001
130-EC-002
130-EC-003
130-EC-004', 'desvio', '2026-03-12', '[Tipo: ENGENHARIA/DESENHO · Origem: MDE - ENGENHARIA · Pedido 129 (não cadastrado no sistema)]
DESENHO DE DETALHE EINFORMANDO QUANTIDADE DE PARAFUSOS DIVERGENTE AO  NECESSARIO PARA  MONTAGEM DOS MEDULOS DO ELEVADOR', '2026-03-12', 'GABRIEL - ENGENHARIA', 'REVISAR DESENHO INFORMANDO QUANTIDADE CORRETA - MATERIAL ENVIADO LE010  P129 -  ITEM 52, 55 , 56', '2026-03-12', null, null, 'encerrado');
insert into public.desvios_cliente (ano_desvio, numero_desvio, empresa, cliente, pedido_id, desenho, desenho_cliente, posicao, tag, tipo, data_desvio, descricao, prazo_resposta, responsavel_resposta, resposta, prazo_execucao, custo, debito, status_desvio)
values (2026, 6, 'MDE- ENGENHARIA S/A', 'NEW WAVE', null, 'T-072310-1', '0701-MDE-0110-D4-00001', null, '110-TR-001', 'desvio', '2026-03-12', '[Tipo: ENGENHARIA/DESENHO · Origem: MDE - ENGENHARIA · Pedido 133 (não cadastrado no sistema)]
DESENHO DE ARRANHO INFORMA LARGURA INCORRETA DAS COLUNAS', '2026-03-12', 'GABRIEL - ENGENHARIA', 'REVISAR DESENHO INDICANDO COTAS CORRETAS E ENVIAR PARA O CLIENTE', '2026-03-12', null, null, 'encerrado');
insert into public.desvios_cliente (ano_desvio, numero_desvio, empresa, cliente, pedido_id, desenho, desenho_cliente, posicao, tag, tipo, data_desvio, descricao, prazo_resposta, responsavel_resposta, resposta, prazo_execucao, custo, debito, status_desvio)
values (2026, 7, 'MDE- ENGENHARIA S/A', 'NEW WAVE', (select id from public.pedidos where numero_pedido='P-158'), null, null, null, null, 'desvio', '2026-03-25', '[Tipo: DIVERGÊNCIA ROMANEIO / MATERIAL · Origem: MDE-LOGISTICA]
LE 003 -  VEIO NO FÍSICO E NÃO CONSTA NOS ROMANEIOS UMA SIRENE', '2026-03-28', 'ESTEVÃO - LOGISTICA', 'REVISAR ROMANEIO CONFORME MATERIAL ENVIADO NO FISICO', null, null, null, 'encerrado');
insert into public.desvios_cliente (ano_desvio, numero_desvio, empresa, cliente, pedido_id, desenho, desenho_cliente, posicao, tag, tipo, data_desvio, descricao, prazo_resposta, responsavel_resposta, resposta, prazo_execucao, custo, debito, status_desvio)
values (2026, 8, 'MDE- ENGENHARIA S/A', 'NEW WAVE', null, null, null, null, null, 'desvio', '2026-03-25', '[Tipo: DIVERGÊNCIA ROMANEIO / MATERIAL · Origem: MDE-LOGISTICA · Pedido 128 (não cadastrado no sistema)]
LE 003 - DIVERGENCIA NO ROMANEIO ITENS 08,09,10,11,14,17,29,52', '2026-03-28', 'ESTEVÃO - LOGISTICA', 'REVISAR ROMANEIO CONFORME MATERIAL ENVIADO NO FISICO', null, null, null, 'encerrado');
insert into public.desvios_cliente (ano_desvio, numero_desvio, empresa, cliente, pedido_id, desenho, desenho_cliente, posicao, tag, tipo, data_desvio, descricao, prazo_resposta, responsavel_resposta, resposta, prazo_execucao, custo, debito, status_desvio)
values (2026, 9, 'MDE- ENGENHARIA S/A', 'NEW WAVE', null, null, null, null, null, 'desvio', '2026-03-25', '[Tipo: DIVERGÊNCIA ROMANEIO / MATERIAL · Origem: MDE-LOGISTICA · Pedido 129 (não cadastrado no sistema)]
LE 010 - DIVERGENCIA NO ROMANEIO ITENS 14,15,24,33,34,51,87,97,46,57,98,99,100', '2026-03-28', 'ESTEVÃO - LOGISTICA', 'REVISAR ROMANEIO CONFORME MATERIAL ENVIADO NO FISICO', null, null, null, 'encerrado');
insert into public.desvios_cliente (ano_desvio, numero_desvio, empresa, cliente, pedido_id, desenho, desenho_cliente, posicao, tag, tipo, data_desvio, descricao, prazo_resposta, responsavel_resposta, resposta, prazo_execucao, custo, debito, status_desvio)
values (2026, 10, 'MDE- ENGENHARIA S/A', 'NEW WAVE', null, null, null, null, '130-TR-005', 'rnc', '2026-03-26', '[Tipo: RNC 001 · Origem: MONTAGEM OBRA · Pedido 128 (não cadastrado no sistema)]
* Desalinhamento das bases de apoio dos módulos com as bases do skid do Transportador. Há pontos onde será
necessário abrir novas furações

* Falha no tagueamento em baixo relevo nas partes dos módulos do Transportador de arraste. O transportador é o
130-TR-005 e possui partes dos módulos tagueadas como 130-TR-001. Esses módulos já vieram pré montados de
fábrica.', null, 'FABRICA - MARCIO', '* SOLUÇÃO PARA A NÃO CONFORMIDADE: Realizar o ajuste da furação na estrutura de sustentação, garantindo o alinhamento e a coincidência dos furos com os dos módulos.

* SOLUÇÃO PARA A NÃO CONFORMIDADE: A MDE realiza o tagueamento com a identificação da marca da peça e a aplicação do próprio TAG, garantindo uma dupla checagem. A porta de inspeção é a mesma para todos os arrastadores. Todas as peças foram pré-montadas em seus respectivos módulos, o que contribui para a minimização de erros de tagueamento. O setor de qualidade da MDE está atuando para que o erro não se repita.', null, null, null, 'encerrado');
insert into public.desvios_cliente (ano_desvio, numero_desvio, empresa, cliente, pedido_id, desenho, desenho_cliente, posicao, tag, tipo, data_desvio, descricao, prazo_resposta, responsavel_resposta, resposta, prazo_execucao, custo, debito, status_desvio)
values (2026, 11, 'MDE- ENGENHARIA S/A', 'NEW WAVE', null, null, null, null, '120-TR-001', 'rnc', '2026-03-25', '[Tipo: RNC 002 · Origem: MONTAGEM OBRA · Pedido 132 (não cadastrado no sistema)]
* Ausência de furações na estrutura metálica para fixação das peças. 

* Furações com distanciamentos divergentes de 70mm e 90mm para fixação das peças;
- Chapas de interligação e fixação soldadas invertidas com as furações para a parte interna da peça;
- Furações das chapas de interligação com posicionamentos divergentes

* - Após a montagem da estrutura metálica das treliças do Transportador Flexowell -120-TR-001, mesmo com o aperto dos parafusos de fixação, a estrutura não apresentou estabilidade (rigidez);
- As interligações entre as estruturas são feitas por apenas dois parafusos fixados e apertados pela parte externa das estruturas;
- Após aperto dos parafusos a face externa das emendas fecham 100%, porém as faces internas não fecham 100%.', null, '* FABRICA - MARCIO

* FABRICA - MARCIO

* ENGENHARIA - GABRIEL', '* SOLUÇÃO PARA A NÃO CONFORMIDADE: Executar as furações faltantes conforme os desenhos MDE indicados no conjunto de montagem 0701-MDE-0120-DT-00017_Rev_2. ( OBS : itemm 1 e 2  Retrabalho realizado pela montadora sem aval da MDE , e custos não foram apresentados ).
 
* Sera realizada solda em todo contorno solda especificação da solda a ser definida pela engenharia MDE', null, null, null, 'encerrado');
insert into public.desvios_cliente (ano_desvio, numero_desvio, empresa, cliente, pedido_id, desenho, desenho_cliente, posicao, tag, tipo, data_desvio, descricao, prazo_resposta, responsavel_resposta, resposta, prazo_execucao, custo, debito, status_desvio)
values (2026, 12, 'MDE- ENGENHARIA S/A', 'NEW WAVE', null, null, null, null, '120-TR-001', 'rnc', '2026-03-24', '[Tipo: RNC 003 · Origem: MONTAGEM OBRA · Pedido 132 (não cadastrado no sistema)]
* Falha na locação de furação da estrutura metálica do chassi. Desenhos de referência 0701-MDE-0120-DT-00024 Rer.1 e 0701-MDE-0120-DT-00017 Rer.1 

* - Durante a montagem da estrutura metálica do conjunto do tambor de desvio do chassi inferior do Transportador Flexowell, foi identificado a ausência de duas chapas perfuradas utilizadas para ajuste do conjunto. Desenho: 0701-MDE-0120-DT-00090 Rer.0

* - Todas as chapas de fixação dos roletes não deram montagem.

- Abrir novas furações na locação correta de montagem da estrutura;
- Solicitar ao fornecedor (MDE) a fabricação e fornecimento das chapas de ajuste, assim como as chapas de fixação dos roletes ou fabricar, ajustar e instalar as chapas in-loco com a montadora;
- Ablongar os furos dos suportes de fixação e suportação dos roletes, possibilitando o alinhamento dos mesmos.', null, '*  FABRICA - MARCIO

* ERRO MONTAGEM

*  FABRICA - MARCIO

*  FABRICA - MARCIO', '* SOLUÇÃO PARA A NÃO CONFORMIDADE: É imprescindível que a equipe de campo realize, inicialmente, a verificação das cotas constantes nos desenhos estruturais das peças que apresentaram a não conformidade. Deve-se conferir as cotas indicadas no desenho abaixo e, após a confirmação, proceder com a furação no chassi de esticamento. OBS: Retrabalho realizado sem o aval da MDE custo apresentado R$ 2490,42 .

* SOLUÇÃO PARA A NÃO CONFORMIDADE: Conforme verificado em campo, o suporte de mancal mencionado foi montado em local incorreto, sendo este o suporte de acionamento. Os suportes corretos já foram devidamente identificados e serão montados nos respectivos locais corretos.

* Devido ao alto custo do retrabalho a MDE ira fornecer novas peças já ajustadas, para item 3 e item 4 da RNC003.', null, null, null, 'encerrado');
insert into public.desvios_cliente (ano_desvio, numero_desvio, empresa, cliente, pedido_id, desenho, desenho_cliente, posicao, tag, tipo, data_desvio, descricao, prazo_resposta, responsavel_resposta, resposta, prazo_execucao, custo, debito, status_desvio)
values (2026, 13, 'MDE- ENGENHARIA S/A', 'NEW WAVE', null, 'T-042327-1', '0701-MDE-0120-DT-00033', 'E', '120-TR-002', 'desvio', '2026-04-06', '[Tipo: FALTA DE MATERIAL · Origem: MDE-FABRICA · Pedido 133 (não cadastrado no sistema)]
FALTAM 4 PINOS COM ARRUELA E CONTRAPINO DESENHO', null, 'FABRICA - MARCIO', 'REVISAR ROMANEIO CONFORME MATERIAL ENVIADO NO FISICO', null, null, null, 'encerrado');
insert into public.desvios_cliente (ano_desvio, numero_desvio, empresa, cliente, pedido_id, desenho, desenho_cliente, posicao, tag, tipo, data_desvio, descricao, prazo_resposta, responsavel_resposta, resposta, prazo_execucao, custo, debito, status_desvio)
values (2026, 14, 'MDE- ENGENHARIA S/A', 'NEW WAVE', null, 'T-072457-1', null, null, '120-TR-001', 'desvio', '2026-04-06', '[Tipo: FALTA DE MATERIAL · Origem: MDE-FABRICA · Pedido 132 (não cadastrado no sistema)]
FALTAM 56 PARAFUSOS COM PORCA E ARRUELA', null, 'PCP - MATEUS', 'REVISAR ROMANEIO CONFORME MATERIAL ENVIADO NO FISICO', null, null, null, 'encerrado');
insert into public.desvios_cliente (ano_desvio, numero_desvio, empresa, cliente, pedido_id, desenho, desenho_cliente, posicao, tag, tipo, data_desvio, descricao, prazo_resposta, responsavel_resposta, resposta, prazo_execucao, custo, debito, status_desvio)
values (2026, 15, 'MDE- ENGENHARIA S/A', 'NEW WAVE', null, 'T-072457-1', null, null, '120-TR-001', 'desvio', '2026-04-06', '[Tipo: FALTA DE MATERIAL · Origem: MDE-FABRICA · Pedido 132 (não cadastrado no sistema)]
FALTAM 56 PARAFUSOS COM PORCA E ARRUELA', null, 'PCP - MATEUS', 'REVISAR ROMANEIO CONFORME MATERIAL ENVIADO NO FISICO', null, null, null, 'encerrado');
insert into public.desvios_cliente (ano_desvio, numero_desvio, empresa, cliente, pedido_id, desenho, desenho_cliente, posicao, tag, tipo, data_desvio, descricao, prazo_resposta, responsavel_resposta, resposta, prazo_execucao, custo, debito, status_desvio)
values (2026, 16, 'MDE- ENGENHARIA S/A', 'NEW WAVE', null, null, 'B-071364-1 0701-MDE-0130-EL-00011', null, '130-TR-01 / 130-TR-02
130-TR-03 / 130-TR-04
130-TR-05', 'desvio', '2026-08-26', '[Tipo: FALTA DE MATERIAL · Origem: SUPRIMENTOS - MDE · Pedido 128 (não cadastrado no sistema)]
FALTAM 10 SENSORES INDUTIVOS', null, 'SUPRIMENTOS - GERSON', 'Realizar compra dos 10 sensores pendentes  
OC 2209- PRAZO 02/10/2026', null, null, null, 'encerrado');
insert into public.desvios_cliente (ano_desvio, numero_desvio, empresa, cliente, pedido_id, desenho, desenho_cliente, posicao, tag, tipo, data_desvio, descricao, prazo_resposta, responsavel_resposta, resposta, prazo_execucao, custo, debito, status_desvio)
values (2026, 17, 'MDE- ENGENHARIA S/A', 'NEW WAVE', (select id from public.pedidos where numero_pedido='P-158'), null, 'Remessa 65', null, '120-TR-003 / 120-TR-007 
120-TR-008 / 120-TR-009', 'desvio', '2026-08-26', '[Tipo: FALTA DE MATERIAL · Origem: ENGENHARIA - MDE]
FALTOU INDICAR AS FIXAÇOES NO DESENHO', null, 'GABRIEL - ENGENHARIA', 'Desenho revisado, acrescentadas as fixações pendentes', null, null, null, 'encerrado');
insert into public.desvios_cliente (ano_desvio, numero_desvio, empresa, cliente, pedido_id, desenho, desenho_cliente, posicao, tag, tipo, data_desvio, descricao, prazo_resposta, responsavel_resposta, resposta, prazo_execucao, custo, debito, status_desvio)
values (2026, 18, 'MDE- ENGENHARIA S/A', 'AURA', null, 'T-072995-1', null, 'POS. 14, 15 E 16', '1073-TC-006
1073-TC-007', 'desvio', '2026-09-28', '[Tipo: FALTA DE MATERIAL · Origem: RMF · Pedido 188 (não cadastrado no sistema)]
FALTOU FORNECER PINOS CONTRAPINOS E ARRUELAS', '2026-10-05', 'GEZIEL - PCP', 'Material sendo fabricado sera enviado ao cliente na carga do dia  05/10/2026', null, null, 'FÁBRICA - MDE', 'encerrado');
insert into public.desvios_cliente (ano_desvio, numero_desvio, empresa, cliente, pedido_id, desenho, desenho_cliente, posicao, tag, tipo, data_desvio, descricao, prazo_resposta, responsavel_resposta, resposta, prazo_execucao, custo, debito, status_desvio)
values (2026, 19, 'MDE- ENGENHARIA S/A', 'AURA', null, 'T-072928-1', null, 'F, G, H, K', '1073-TC-006
1073-TC-007', 'desvio', '2026-09-28', '[Tipo: FALTA DE MATERIAL · Origem: RMF · Pedido 188 (não cadastrado no sistema)]
FALTOU FORNECER AS PROTEÇOES INJETADAS', '2026-10-05', 'GEZIEL - PCP', 'Material disponivel em estoque e complemento em processo de compra , sera enviado ao cliente na carga do dia  05/10/2026', null, null, 'FÁBRICA - MDE', 'encerrado');
insert into public.desvios_cliente (ano_desvio, numero_desvio, empresa, cliente, pedido_id, desenho, desenho_cliente, posicao, tag, tipo, data_desvio, descricao, prazo_resposta, responsavel_resposta, resposta, prazo_execucao, custo, debito, status_desvio)
values (2026, 20, 'MDE- ENGENHARIA S/A', 'AURA', null, 'R-007180-1', null, 'A', '1073-TC-006
1073-TC-007', 'desvio', '2026-06-19', '[Tipo: CTE-PRX-058-012 / ENGENHARIA/DESENHO · Origem: MDE - ENGENHARIA · Pedido 188 (não cadastrado no sistema)]
Durante a pré montagem da estrutura metálica dos filtros prensa foram encontradas inconsistências / interferências que impedem a continuidade das atividades.
O cavalote dos roletes de auto alinhamento estão atritando com a cantoneira da estrutura. 
A altura do cilindro de travamento indica que a função de delimitar a área de trabalho da correia não será plenamente atendida.
Ver registros fotográficos', '2026-06-22', 'GABRIEL - ENGENHARIA', 'Para correção da não conformidade identificada na base de retorno autoalinhante, será necessário realizar as seguintes intervenções em campo conforme croqui anexo:

1.	Executar o recorte de uma das abas da cantoneira da ponte treliçada que está interferindo com a base do rolete de retorno autoalinhante. Após o ajuste, deverá ser soldada uma cantoneira de mesma dimensão, para reforço estrutural.
2.	Realizar a soldagem de um complemento acima da face superior do suporte do rolo guia, com o objetivo de elevar sua posição.
3.	Ajustar em campo os batentes que delimitam o ângulo de giro da base de retorno autoalinhante, incluindo o corte e reposicionamento das peças, de forma a garantir um ângulo de aproximadamente 5°.', '2026-06-22', null, 'ENGENHARIA - MDE', 'encerrado');
insert into public.desvios_cliente (ano_desvio, numero_desvio, empresa, cliente, pedido_id, desenho, desenho_cliente, posicao, tag, tipo, data_desvio, descricao, prazo_resposta, responsavel_resposta, resposta, prazo_execucao, custo, debito, status_desvio)
values (2026, 21, 'MDE- ENGENHARIA S/A', 'AURA', null, null, null, null, '1073-TC-006
1073-TC-007', 'rnc', '2026-06-13', '[Tipo: RNC-PRX-058-006 / DANOS DURANTE MOVIMENTAÇÃO E TRANSPORTE · Origem: MDE - FABRICA · Pedido 188 (não cadastrado no sistema)]
Foi evidenciado nas atividades de montagem da estrutura do transportadores de correia, na abertura das caixas e início da montagem, furações incompatível com passagem  dos parafusos, oxidação , "rasgo" de fixação realizado na posição incorreta. Não conformidades evidenciadas repetidamente nas estruturas e são encontradas a medida do avanço da pré montagem. Ver página 2/2.', '2026-06-16', null, 'RETRABALHO REALIZADO SEM APROVAÇÃO DA ENGENHARIA MDE', null, null, 'FÁBRICA - MDE', 'encerrado');
insert into public.desvios_cliente (ano_desvio, numero_desvio, empresa, cliente, pedido_id, desenho, desenho_cliente, posicao, tag, tipo, data_desvio, descricao, prazo_resposta, responsavel_resposta, resposta, prazo_execucao, custo, debito, status_desvio)
values (2026, 22, 'MDE- ENGENHARIA S/A', 'AURA', null, 'T-072956-1', null, null, '1073-TC-007', 'rnc', '2026-07-09', '[Tipo: RNC-PRX-058-010 / DANOS DURANTE MOVIMENTAÇÃO E TRANSPORTE · Origem: RMF / TRANSPORTADORA · Pedido 188 (não cadastrado no sistema)]
Durante a inspeção de recebimento físico das Estruturas Metálicas do Transportador de Correia 1073-TC-006/007 associados à NF 9084, MDE, foi evidenciado avaria na estrutura do Passadiço. As estruturas apresentam ruptura por fratura na área de soldagem, borda irregular causada por corte de maçarico, compromentendo a proteção da pintura, que poderá ter pontos de corrosão prematura.', '2026-07-13', 'ROBERTO - FABRICA', 'A MDE irá disponibilizar um novo passadiço para substituição.', null, null, 'SUPRIMENTOS - MDE', 'encerrado');
insert into public.desvios_cliente (ano_desvio, numero_desvio, empresa, cliente, pedido_id, desenho, desenho_cliente, posicao, tag, tipo, data_desvio, descricao, prazo_resposta, responsavel_resposta, resposta, prazo_execucao, custo, debito, status_desvio)
values (2026, 23, 'MDE- ENGENHARIA S/A', 'AURA', null, 'T-072995-1', null, 'A', '1073-TC-006', 'rnc', '2026-09-29', '[Tipo: RNC-PRX-058-030 / ERRO DE FABRICAÇÃO · Origem: RMF · Pedido 188 (não cadastrado no sistema)]
Conforme montagem do redutor no eixo do tambor, foi constatado desalinhamento do olhal do skid do acionamento com relação ao olhal da estrutura do TC-006 conforme fotos anexas evidenciando o não acoplamento entre os mesmos.', '2026-10-02', 'GABRIEL - ENGENHARIA', 'Realizar o ajuste do olhal em campo, conforme orientação do supervisor MDE. Os custos do retrabalho deverão ser encaminhados para aprovação antes da execução.', null, null, 'FORNECEDOR  - RMF', 'encerrado');
insert into public.desvios_cliente (ano_desvio, numero_desvio, empresa, cliente, pedido_id, desenho, desenho_cliente, posicao, tag, tipo, data_desvio, descricao, prazo_resposta, responsavel_resposta, resposta, prazo_execucao, custo, debito, status_desvio)
values (2026, 24, 'MDE- ENGENHARIA S/A', 'AURA', null, 'T-072982-1', null, 'A', '1073-TC-006
1073-TC-007', 'rnc', '2026-10-05', '[Tipo: RNC-PRX-058-033 / ENGENHARIA/DESENHO · Origem: MDE - ENGENHARIA · Pedido 188 (não cadastrado no sistema)]
Foi evidenciado que o chute do Transportador de Correia 1073-TC-006 parte inferior, não vieram com as aberturas necessárias e as furações para a montagem dos raspadores primários e secundários.', '2026-10-05', 'GABRIEL - ENGENHARIA', 'Realizar o recorte do chute em campo, conforme orientação do supervisor MDE, garantindo o posicionamento adequado para a regulagem do raspador. Os custos do retrabalho deverão ser encaminhados para aprovação antes da execução.', null, null, 'ENGENHARIA - MDE', 'encerrado');
insert into public.desvios_cliente (ano_desvio, numero_desvio, empresa, cliente, pedido_id, desenho, desenho_cliente, posicao, tag, tipo, data_desvio, descricao, prazo_resposta, responsavel_resposta, resposta, prazo_execucao, custo, debito, status_desvio)
values (2026, 25, 'MDE- ENGENHARIA S/A', 'AURA', null, 'T-072982-1', null, 'POS. 14 E 15', '1073-TC-006
1073-TC-007', 'desvio', '2026-09-28', '[Tipo: FALTA DE MATERIAL · Origem: RMF · Pedido 188 (não cadastrado no sistema)]
FALTOU FORNECER BARA DE DESGASTE DO CHUTE POSIÇÃO 14 E POSIÇÃO 15', '2026-10-05', 'GEZIEL - PCP', 'Material sendo fabricado sera enviado ao cliente na carga do dia  05/10/2026
Prazo para execução: Fabricado', null, null, 'FÁBRICA - MDE', 'encerrado');
insert into public.desvios_cliente (ano_desvio, numero_desvio, empresa, cliente, pedido_id, desenho, desenho_cliente, posicao, tag, tipo, data_desvio, descricao, prazo_resposta, responsavel_resposta, resposta, prazo_execucao, custo, debito, status_desvio)
values (2026, 26, 'MDE- ENGENHARIA S/A', 'SERRA VERDE', (select id from public.pedidos where numero_pedido='P-198'), 'T-73193-1', null, null, '14-CV-0001', 'rnc', '2026-07-17', '[Tipo: RNC 2026-063 · Origem: MDE - FÁBRICA]
BAIXA ESPESSURA DE TINTA E PONTOS COM OXIDAÇÃO', '2026-07-16', 'JARDEL - MDE', 'FORNECER TINTA PARA REALIZAR RETOQUE , ATINGIR 320 MICROMETROS DE ESPESSURA', null, null, null, 'em_aberto');
insert into public.desvios_cliente (ano_desvio, numero_desvio, empresa, cliente, pedido_id, desenho, desenho_cliente, posicao, tag, tipo, data_desvio, descricao, prazo_resposta, responsavel_resposta, resposta, prazo_execucao, custo, debito, status_desvio)
values (2026, 27, 'MDE- ENGENHARIA S/A', 'SERRA VERDE', (select id from public.pedidos where numero_pedido='P-198'), 'T-73207-1', null, null, '14-CV-0001', 'rnc', '2026-10-02', '[Tipo: RNC 2026-064 · Origem: MDE - FÁBRICA]
BAIXA ESPESSURA DE TINTA NA PARTE INTERNA DO CHUTE', '2026-08-13', 'JARDEL - MDE', 'FORNECER TINTA PARA REALIZAR RETOQUE , ATINGIR 320 MICROMETROS DE ESPESSURA', null, null, null, 'em_aberto');
insert into public.desvios_cliente (ano_desvio, numero_desvio, empresa, cliente, pedido_id, desenho, desenho_cliente, posicao, tag, tipo, data_desvio, descricao, prazo_resposta, responsavel_resposta, resposta, prazo_execucao, custo, debito, status_desvio)
values (2026, 28, 'MDE- ENGENHARIA S/A', 'SERRA VERDE', (select id from public.pedidos where numero_pedido='P-198'), 'T-73731-1', 'MI-D-148-ME-DF-0110', 'POS. 3 E 8', '14-CV-0001', 'rnc', '2026-10-02', '[Tipo: RNC 2026-088 · Origem: MDE - FÁBRICA / AXION]
FALTOU MONTAR POSIÇÃO 3 E 8 CONFORME DESENHO', '2026-10-06', 'JUALIANO - AXION', 'FORNECER POSIÇÕES FALTANTES PARA MONTAGEM EM CAMPO', null, null, null, 'em_aberto');
insert into public.desvios_cliente (ano_desvio, numero_desvio, empresa, cliente, pedido_id, desenho, desenho_cliente, posicao, tag, tipo, data_desvio, descricao, prazo_resposta, responsavel_resposta, resposta, prazo_execucao, custo, debito, status_desvio)
values (2026, 29, 'MDE- ENGENHARIA S/A', 'AURA', null, 'P-073056-1', 'BBR-D-DF-1073-MDE-M-0034', 'POS. 12 E 14', '1073-PR-0002', 'desvio', '2026-09-17', '[Tipo: ESPECIFICAÇÃO · Origem: MDE · Pedido 190 (não cadastrado no sistema)]
CLASSE DE DUREZA NÃO ESPECIFICADA CORRETAMENTE', '2026-09-18', 'GABRIEL - ENGENHARIA', 'REVISAR DESENHO ENVIAR FIXAÇOES CONFORME NORMA', null, null, 'ENGENHARIA - MDE', 'encerrado');
insert into public.desvios_cliente (ano_desvio, numero_desvio, empresa, cliente, pedido_id, desenho, desenho_cliente, posicao, tag, tipo, data_desvio, descricao, prazo_resposta, responsavel_resposta, resposta, prazo_execucao, custo, debito, status_desvio)
values (2026, 30, 'MDE- ENGENHARIA S/A', 'AURA', null, 'P-073056-4', 'BBR-D-DF-1073-MDE-M-0034', 'POS.14', '1073-PR-0002', 'desvio', '2026-10-13', '[Tipo: ENGENHARIA/DESENHO · Origem: ENGENHARIA - MDE · Pedido 190 (não cadastrado no sistema)]
Foi evidenciado durante a montagem do conjunto da ponte rolante, 1073-PR-0002, que a possível furação para inserção do para-choque não coincide com a furação disposta no acessório.', '2026-10-15', 'GABRIEL - ENGENHARIA', 'Executar furação e rosca para fixação dos batentes na posição adequada conforme altura do fim de curso.', null, null, 'ENGENHARIA - MDE', 'encerrado');
insert into public.desvios_cliente (ano_desvio, numero_desvio, empresa, cliente, pedido_id, desenho, desenho_cliente, posicao, tag, tipo, data_desvio, descricao, prazo_resposta, responsavel_resposta, resposta, prazo_execucao, custo, debito, status_desvio)
values (2026, 31, 'MDE- ENGENHARIA S/A', 'AURA', null, 'T-007177-1', null, 'A', '1073-TC-007', 'desvio', '2026-10-15', '[Tipo: FALTA DE MATERIAL · Origem: MDE · Pedido 188 (não cadastrado no sistema)]
BASE PARA ROLO DE CARGA', '2026-10-20', 'GEZIEL - PCP', 'FABRICAR E ENVIAR NA PROXIMA CARGA 6 PEÇAS
Prazo para execução: Fabricado', null, null, 'FÁBRICA - MDE', 'encerrado');
insert into public.desvios_cliente (ano_desvio, numero_desvio, empresa, cliente, pedido_id, desenho, desenho_cliente, posicao, tag, tipo, data_desvio, descricao, prazo_resposta, responsavel_resposta, resposta, prazo_execucao, custo, debito, status_desvio)
values (2026, 32, 'MDE- ENGENHARIA S/A', 'AURA', null, 'R-1-4-9211', null, null, '1073-TC-007', 'desvio', '2026-10-15', '[Tipo: FALTA DE MATERIAL · Origem: MDE · Pedido 188 (não cadastrado no sistema)]
ROLO DE CARGA', '2026-10-20', 'GEZIEL - PCP', 'FABRICAR E ENVIAR NA PROXIMA CARGA 18 PEÇAS', '2026-10-30', null, 'FÁBRICA - MDE', 'encerrado');
insert into public.desvios_cliente (ano_desvio, numero_desvio, empresa, cliente, pedido_id, desenho, desenho_cliente, posicao, tag, tipo, data_desvio, descricao, prazo_resposta, responsavel_resposta, resposta, prazo_execucao, custo, debito, status_desvio)
values (2026, 33, 'MDE- ENGENHARIA S/A', 'AURA', null, 'T-007179-1', null, null, '1073-TC-007', 'desvio', '2026-10-15', '[Tipo: FALTA DE MATERIAL · Origem: MDE · Pedido 188 (não cadastrado no sistema)]
BASE PARA ROLO DE RETORNO', '2026-10-20', 'GEZIEL - PCP', 'FABRICAR E ENVIAR NA PROXIMA CARGA 1 CJ
Prazo para execução: Fabricado', null, null, 'FÁBRICA - MDE', 'encerrado');
insert into public.desvios_cliente (ano_desvio, numero_desvio, empresa, cliente, pedido_id, desenho, desenho_cliente, posicao, tag, tipo, data_desvio, descricao, prazo_resposta, responsavel_resposta, resposta, prazo_execucao, custo, debito, status_desvio)
values (2026, 34, 'MDE- ENGENHARIA S/A', 'AURA', null, 'R-3-4-7843', null, 'A', '1073-TC-007', 'desvio', '2026-10-15', '[Tipo: FALTA DE MATERIAL · Origem: MDE · Pedido 188 (não cadastrado no sistema)]
ROLO DE RETORNO', '2026-10-20', 'GEZIEL - PCP', 'FABRICAR E ENVIAR NA PROXIMA CARGA 1 PEÇA
Prazo para execução: Fabricado', null, null, 'FÁBRICA - MDE', 'encerrado');
insert into public.desvios_cliente (ano_desvio, numero_desvio, empresa, cliente, pedido_id, desenho, desenho_cliente, posicao, tag, tipo, data_desvio, descricao, prazo_resposta, responsavel_resposta, resposta, prazo_execucao, custo, debito, status_desvio)
values (2026, 35, 'MDE- ENGENHARIA S/A', 'AURA', null, 'T-072929-1', null, 'A', '1073-TC-006
1073-TC-007', 'desvio', '2026-10-08', '[Tipo: FALTA DE MATERIAL · Origem: MDE · Pedido 188 (não cadastrado no sistema)]
PROTEÇÃO CONTRA QUEDA DE ROLETE / DESENHO COMPLETO COM ITENS DE FIXAÇÃO', '2026-10-20', 'GEZIEL - PCP', 'FABRICAR E ENVIAR NA PROXIMA CARGA', '2026-10-23', null, 'FÁBRICA - MDE', 'encerrado');
insert into public.desvios_cliente (ano_desvio, numero_desvio, empresa, cliente, pedido_id, desenho, desenho_cliente, posicao, tag, tipo, data_desvio, descricao, prazo_resposta, responsavel_resposta, resposta, prazo_execucao, custo, debito, status_desvio)
values (2026, 54, 'MDE- ENGENHARIA S/A', 'AURA', null, 'T-072993-1', 'BBR-D-DF-1073-MDE-M-0075', 'A', '1073-TC-007', 'desvio', '2026-10-21', '[Tipo: FALTA DE MATERIAL · Origem: MDE · Pedido 188 (não cadastrado no sistema)]
PROTEÇÃO LATERAL', '2026-10-20', 'GABRIEL - ENGENHARIA', 'FABRICAR E ENVIAR NA PROXIMA CARGA 4 PEÇAS', '2026-10-23', null, 'ENGENHARIA - MDE', 'encerrado');
insert into public.desvios_cliente (ano_desvio, numero_desvio, empresa, cliente, pedido_id, desenho, desenho_cliente, posicao, tag, tipo, data_desvio, descricao, prazo_resposta, responsavel_resposta, resposta, prazo_execucao, custo, debito, status_desvio)
values (2026, 36, 'MDE- ENGENHARIA S/A', 'AURA', null, null, null, null, '1073-TC-006
1073-TC-007', 'desvio', '2026-10-21', '[Tipo: FALTA DE MATERIAL · Origem: MDE · Pedido 188 (não cadastrado no sistema)]
LUBRIFICANTES ISO VG 320 (Sintético) - 64 LITROS', '2026-10-20', 'GABRIEL - ENGENHARIA', 'ENVIAR NA PROXIMA CARGA - 64 LITROS', '2026-10-30', null, 'ENGENHARIA - MDE', 'em_aberto');
insert into public.desvios_cliente (ano_desvio, numero_desvio, empresa, cliente, pedido_id, desenho, desenho_cliente, posicao, tag, tipo, data_desvio, descricao, prazo_resposta, responsavel_resposta, resposta, prazo_execucao, custo, debito, status_desvio)
values (2026, 37, 'MDE- ENGENHARIA S/A', 'AURA', null, null, null, null, '1073-PR-0002', 'desvio', '2026-10-21', '[Tipo: FALTA DE MATERIAL · Origem: MDE · Pedido 190 (não cadastrado no sistema)]
LUBRIFICANTES ISO VG 320 (Sintético) - 15,25 LITROS', '2026-10-20', 'GABRIEL - ENGENHARIA', 'ENVIAR NA PROXIMA CARGA 15,25 LITROS', '2026-10-30', null, 'ENGENHARIA - MDE', 'em_aberto');
insert into public.desvios_cliente (ano_desvio, numero_desvio, empresa, cliente, pedido_id, desenho, desenho_cliente, posicao, tag, tipo, data_desvio, descricao, prazo_resposta, responsavel_resposta, resposta, prazo_execucao, custo, debito, status_desvio)
values (2026, 38, 'MDE- ENGENHARIA S/A', 'AURA', null, null, null, null, '1073-PR-0002', 'desvio', '2026-10-21', '[Tipo: FALTA DE MATERIAL · Origem: MDE · Pedido 190 (não cadastrado no sistema)]
ITEM:52 - Chave fim de curso da translação do carro e fim de curso da translação da ponte 4 PEÇAS', '2026-10-20', 'GERSON - COMPRAS', 'ENVIAR NA PROXIMA CARGA 4 PEÇA', '2026-10-30', null, 'SUPRIMENTOS - MDE', 'encerrado');
insert into public.desvios_cliente (ano_desvio, numero_desvio, empresa, cliente, pedido_id, desenho, desenho_cliente, posicao, tag, tipo, data_desvio, descricao, prazo_resposta, responsavel_resposta, resposta, prazo_execucao, custo, debito, status_desvio)
values (2026, 39, 'MDE- ENGENHARIA S/A', 'AURA', null, 'T-072928-1', 'BBR-D-DF-1073-MDE-M-0024', 'B & K', '1073-TC-006
1073-TC-007', 'desvio', '2026-10-21', '[Tipo: FALTA DE MATERIAL · Origem: MDE · Pedido 188 (não cadastrado no sistema)]
PROTEÇÃO LATERAL / 16x pos.B 2x Pos. K Esquerda', '2026-10-20', 'GABRIEL - ENGENHARIA', 'FABRICAR E ENVIAR NA PROXIMA CARGA 4 PEÇAS
Prazo para execução: Fabricado', null, null, 'ENGENHARIA - MDE', 'encerrado');
insert into public.desvios_cliente (ano_desvio, numero_desvio, empresa, cliente, pedido_id, desenho, desenho_cliente, posicao, tag, tipo, data_desvio, descricao, prazo_resposta, responsavel_resposta, resposta, prazo_execucao, custo, debito, status_desvio)
values (2026, 40, 'MDE- ENGENHARIA S/A', null, null, null, null, null, '1073-TC-0007', 'desvio', '2026-10-21', '[Tipo: FALTA DE MATERIAL · Origem: MDE]
Cavaletes de carga', '2026-10-22', null, 'ITEM 31 ACIMA', null, null, 'ENGENHARIA - MDE', 'encerrado');
insert into public.desvios_cliente (ano_desvio, numero_desvio, empresa, cliente, pedido_id, desenho, desenho_cliente, posicao, tag, tipo, data_desvio, descricao, prazo_resposta, responsavel_resposta, resposta, prazo_execucao, custo, debito, status_desvio)
values (2026, 41, 'MDE- ENGENHARIA S/A', null, null, null, null, null, '1073-TC-0007', 'desvio', '2026-10-21', '[Tipo: FALTA DE MATERIAL · Origem: MDE]
Proteção de retorno da torre de esticamento', '2026-10-22', null, 'ITEM 35 ACIMA', null, null, 'ENGENHARIA - MDE', 'encerrado');
insert into public.desvios_cliente (ano_desvio, numero_desvio, empresa, cliente, pedido_id, desenho, desenho_cliente, posicao, tag, tipo, data_desvio, descricao, prazo_resposta, responsavel_resposta, resposta, prazo_execucao, custo, debito, status_desvio)
values (2026, 42, 'MDE- ENGENHARIA S/A', 'AURA', null, 'T-072996-1', 'BBR-D-DF-1073-MDE-M-0078', 'B', '1073-TC-0006', 'rnc', '2026-10-21', '[Tipo: RNC-PRX-058-044 / FALTA DE MATERIAL · Origem: MDE · Pedido 188 (não cadastrado no sistema)]
Proteção do anel de contração', '2026-10-22', 'GABRIEL - ENGENHARIA', 'FABRICAR E ENVIAR NA PROXIMA CARGA', '2026-10-30', null, 'ENGENHARIA - MDE', 'encerrado');
insert into public.desvios_cliente (ano_desvio, numero_desvio, empresa, cliente, pedido_id, desenho, desenho_cliente, posicao, tag, tipo, data_desvio, descricao, prazo_resposta, responsavel_resposta, resposta, prazo_execucao, custo, debito, status_desvio)
values (2026, 43, 'MDE- ENGENHARIA S/A', 'AURA', null, 'T-072996-1', 'BBR-D-DF-1073-MDE-M-0078', 'B', '1073-TC-0007', 'rnc', '2026-10-21', '[Tipo: RNC-PRX-058-044 / FALTA DE MATERIAL · Origem: MDE · Pedido 188 (não cadastrado no sistema)]
Proteção do anel de contração', '2026-10-22', 'GABRIEL - ENGENHARIA', 'FABRICAR E ENVIAR NA PROXIMA CARGA', '2026-10-30', null, 'ENGENHARIA - MDE', 'encerrado');
insert into public.desvios_cliente (ano_desvio, numero_desvio, empresa, cliente, pedido_id, desenho, desenho_cliente, posicao, tag, tipo, data_desvio, descricao, prazo_resposta, responsavel_resposta, resposta, prazo_execucao, custo, debito, status_desvio)
values (2026, 44, 'MDE- ENGENHARIA S/A', null, null, null, null, null, '1073-PR-0002', 'desvio', '2026-10-21', '[Tipo: PROJETO · Origem: MDE]
Verificar detalhe tipico de suporte de paineis da ponte', '2026-10-22', null, null, null, null, null, 'em_aberto');
insert into public.desvios_cliente (ano_desvio, numero_desvio, empresa, cliente, pedido_id, desenho, desenho_cliente, posicao, tag, tipo, data_desvio, descricao, prazo_resposta, responsavel_resposta, resposta, prazo_execucao, custo, debito, status_desvio)
values (2026, 45, 'MDE- ENGENHARIA S/A', null, null, null, null, null, '1073-PR-0002', 'desvio', '2026-10-21', '[Tipo: PROJETO · Origem: MDE]
Verificar detalhe tipico de fixação de fim de curso do carro e da ponte', '2026-10-22', null, null, null, null, null, 'em_aberto');
insert into public.desvios_cliente (ano_desvio, numero_desvio, empresa, cliente, pedido_id, desenho, desenho_cliente, posicao, tag, tipo, data_desvio, descricao, prazo_resposta, responsavel_resposta, resposta, prazo_execucao, custo, debito, status_desvio)
values (2026, 46, 'MDE- ENGENHARIA S/A', null, null, null, null, null, '1073-TC-0006', 'desvio', '2026-10-21', '[Tipo: FALTA DE MATERIAL · Origem: MDE]
Portão de acesso a escada da torre de contra-peso', '2026-10-22', null, 'MATERIALFORNECIDO LE 13 ENCONTRADO NA OBRA', null, null, null, 'em_aberto');
insert into public.desvios_cliente (ano_desvio, numero_desvio, empresa, cliente, pedido_id, desenho, desenho_cliente, posicao, tag, tipo, data_desvio, descricao, prazo_resposta, responsavel_resposta, resposta, prazo_execucao, custo, debito, status_desvio)
values (2026, 47, 'MDE- ENGENHARIA S/A', null, null, null, null, null, '1073-TC-0007', 'desvio', '2026-10-21', '[Tipo: FALTA DE MATERIAL · Origem: MDE]
Portão de acesso a escada da torre de contra-peso', '2026-10-22', null, 'MATERIALFORNECIDO LE 13 ENCONTRADO NA OBRA', null, null, null, 'em_aberto');
insert into public.desvios_cliente (ano_desvio, numero_desvio, empresa, cliente, pedido_id, desenho, desenho_cliente, posicao, tag, tipo, data_desvio, descricao, prazo_resposta, responsavel_resposta, resposta, prazo_execucao, custo, debito, status_desvio)
values (2026, 48, 'MDE- ENGENHARIA S/A', 'SERRA VERDE', (select id from public.pedidos where numero_pedido='P-198'), 'T-073734-1
T-073735-1
T-073739-1', null, null, '14-CV-0001', 'rnc', '2026-10-21', '[Tipo: RNC 2026-091 · Origem: MDE - FÁBRICA / AXION]
Durante a pré-montagem da estrutura metálica do Transportador de Correia 14-CV-0001, na torre de esticamento da plataforma EL. +964,260, foi constatada uma divergência entre o projeto e a fabricação.

As vigas de posição 73734H e 73734G possuem, em projeto, oito furos destinados à montagem das bases de apoio dos mancais 73253A e 73252B. Entretanto, as vigas foram fabricadas com apenas quatro furos deslocados da posoição de projeto, impossibilitando a montagem dos componentes conforme previsto em projeto.

Essa condição pode ser verificada nos desenhos MI-D-148-ME-DF-0081 e MI-D-148-ME-DF-0136 (ver Imagens 01 e 02).

Adicionalmente, foram identificadas divergências nas colunas de TAG 73730A e 73731A, nas quais não foram fabricadas/instaladas duas chapas de ligação do contraventamento 73739C, conforme previsto em projeto MI-D-148-ME-DF-0129.

O contraventramento entre as elevações 964,360 e 961,360, itens 73735E e F, apresenta deficiência de montagem, ficando desalinhados conforme evidenciado nas fotos abaixo. Elevação do eixo P13 desenho MI-D-148-ME-DF-0130-R0.

Des: MI-D-148-ME-DF-0081 Rev.0 / MI-D-148-ME-DF-0136 Rev.0 / MI-D-148-ME-DF-0129 Rev.0', '2026-10-23', 'JUALIANO - AXION', null, null, null, 'FORNECEDOR - AXION', 'em_aberto');
insert into public.desvios_cliente (ano_desvio, numero_desvio, empresa, cliente, pedido_id, desenho, desenho_cliente, posicao, tag, tipo, data_desvio, descricao, prazo_resposta, responsavel_resposta, resposta, prazo_execucao, custo, debito, status_desvio)
values (2026, 49, 'MDE- ENGENHARIA S/A', 'SERRA VERDE', (select id from public.pedidos where numero_pedido='P-198'), 'T-073774-1', null, null, '14-CV-0001', 'rnc', '2026-10-21', '[Tipo: RNC 2026-092 · Origem: MDE - ENGENHARIA]
Durante a execução da pré-montagem da estrutura de sustentação do extrator, foram constatadas divergências que impedem a continuidade da montagem.

A primeira refere-se às vigas 73774-N e 73774-L, que apresentam incompatibilidade de montagem. Foram avaliadas duas possibilidades de posicionamento, porém, em ambas as condições, a aba da viga interfere na montagem, impossibilitando seu correto encaixe. Solicita-se análise e definição da solução aplicável. Ver imagens 01 e 02.

Adicionalmente, verificou-se que as vigas 73774-A (direita e esquerda) apresentam divergência em relação às vigas 73774-B (direita e esquerda) e 73774-C (direita e esquerda), uma vez que a linha de ligação encontra-se no sentido oposto ao indicado, impedindo a continuidade da montagem. Ver imagens 03, 04 e 05.

Documento de referência: MI-D-148-ME-DF-0086 - Rev. 0', '2026-10-23', 'GABRIEL - ENGENHARIA', 'Os desenhos foram corrigidos, e as peças deverão ser retrabalhadas em campo.
Para a primeira ocorrência, recomenda-se realizar o recorte na peça 73774-N, conforme indicado no desenho revisado MI-D-148-ME-DF-0153-R1.
Para a segunda ocorrência, deverão ser corrigidas duas peças 73774-A, conforme indicado no desenho revisado MI-D-148-ME-DF-0153-R1. A configuração correta deveria contemplar a fabricação de duas peças direitas e duas peças esquerdas. Para adequação, remover os Itens 4 atualmente soldados nas colunas e realizar sua soldagem no lado oposto ao da posição original, conforme detalhado no desenho revisado.', null, null, 'ENGENHARIA - MDE', 'em_aberto');
insert into public.desvios_cliente (ano_desvio, numero_desvio, empresa, cliente, pedido_id, desenho, desenho_cliente, posicao, tag, tipo, data_desvio, descricao, prazo_resposta, responsavel_resposta, resposta, prazo_execucao, custo, debito, status_desvio)
values (2026, 50, 'MDE- ENGENHARIA S/A', 'AURA', null, null, null, null, '1073-TC-006
1073-TC-007', 'rnc', '2026-10-21', '[Tipo: RNC-PRX-058-042 · Origem: MDE · Pedido 188 (não cadastrado no sistema)]
Foi evidenciado nas atividades de pré comissionamento do transportador de correia 1073-TC-0006 e 1073-TC-0007, anomalias que impedem a correta montagem dos componentes do sistema, listadas a seguir.
1 - Torre de Esticamento:
a) As furações para fixação das roldanas não coincidem o dimensional para montagem.
b) As cantoneiras dos contraventamentos obstruem a guia da caixa de lastro de se movimentar na estrutura da torre
c) Corte para ajuste e reinstalação das talas do guarda corpo 72998-B para montagem.
2 - Passadiço:
a) As furações não coincidem o dimensional para montagem no passadiço quanto também nas longarinas
3 - Chute de Descarga:
a) A chapa interna (morto) interfere no funcionamento do sistema.
b) O recorte existente no elemento superior do chute não permite a montagem do conjunto.', '2026-10-21', null, 'Apenas o Chute tem aval da engenharia , retrabalho realizado sem aprovação da MDE', null, null, null, 'encerrado');
insert into public.desvios_cliente (ano_desvio, numero_desvio, empresa, cliente, pedido_id, desenho, desenho_cliente, posicao, tag, tipo, data_desvio, descricao, prazo_resposta, responsavel_resposta, resposta, prazo_execucao, custo, debito, status_desvio)
values (2026, 51, 'MDE- ENGENHARIA S/A', 'AURA', null, null, null, null, '1073-PR-0002', 'rnc', '2026-10-21', '[Tipo: RNC-PRX-058-043 · Origem: MDE · Pedido 190 (não cadastrado no sistema)]
Foi evidenciado durante as atividades de montagem da ponte rolante avaria no cabo de controle: 

a) 1X12CX1,5mm² tensão de isolamento 0,6/1kv, encordoamento classe 5, temperatura máxima do condutor 70°c em serviço contínuo, cobertura na cor preta. ref. prysmian: cabo sintenax flex controle.', '2026-10-21', null, 'Mtaerial fornecido sem danos', null, null, null, 'encerrado');
insert into public.desvios_cliente (ano_desvio, numero_desvio, empresa, cliente, pedido_id, desenho, desenho_cliente, posicao, tag, tipo, data_desvio, descricao, prazo_resposta, responsavel_resposta, resposta, prazo_execucao, custo, debito, status_desvio)
values (2026, 52, 'MDE- ENGENHARIA S/A', 'AURA', null, null, null, null, '1073-TC-006
1073-TC-007', 'rnc', '2026-10-14', '[Tipo: RNC-PRX-058-036 · Origem: MDE · Pedido 188 (não cadastrado no sistema)]
Foi evidenciado durante as atividades de recebimento de materiais, divergencias entre o romaneio e o material fornecido, conforme segue:
1-Itens mencionados em romaneios e não fornecidos:
Item 02 - Manilha Reta p/ Carga 6.3 Ton - Grau T Diam . Pino Ø1'''' CIMAF OU SIMILAR - DESENHO:T-072992-1 (TAG:1073-TC-006/1073-TC-007) – 48 Pç (NÃO RECEBIDO)
Item 03 - Manilha Reta p/ Carga 3.2Ton - Grau T Diam. Pino Ø3/4" CIMAF OU SIMILAR - DESENHO:T-072992-1 (TAG:1073-TC-006/1073-TC-007) – 48 Pç (NÃO RECEBIDO)
Item 04 - Grampo Pesado Clips p/ Cabo Ø7/16" CIMAF OU SIMILAR - DESENHO:T-072992-1 (TAG:1073-TC-006/1073-TC-007) – 96 Pç (NÃO RECEBIDO)
Item 05 - Manilha Reta p/ Carga 3.2Ton - Grau T Diam. Pino Ø3/4" CIMAF OU SIMILAR - DESENHO:T-072992-1 (TAG:1073-TC-006/1073-TC-007) – 24 Pç (NÃO RECEBIDO)
Item 06 - Grampo Pesado Clips p/ Cabo Ø7/16" CIMAF OU SIMILAR - DESENHO:T-072992-1 (TAG:1073-TC-006/1073-TC-007) – 48 Pç (NÃO RECEBIDO)
2-Itens recebidos e não mencionados em Romaneio:
2.1-Manilha 3.1/4 Ton. Diam. Pino 5/8” – 32 Pç
2.1-Manilha 6.1/2 Ton. Diam. Pino 7/8” – 18 Pç
Nota: Etiqueta de identificação da Manilha 6.1/2 Ton. Diam. Pino 7/8” informa 48pç, recebido apenas 18 pç.
Materiais recebidos na presença dos representantes das empresas Time Now e MDE', '2026-10-16', 'GEZIEL - PCP', 'Após verificação realizada em campo, confirmamos que o material recebido atende integralmente aos quantitativos estipulados no projeto para ambos os transportadores.
Dessa forma, informamos que procederemos com a revisão do romaneio para indicar a quantidade correta enviada.', null, null, null, 'encerrado');
insert into public.desvios_cliente (ano_desvio, numero_desvio, empresa, cliente, pedido_id, desenho, desenho_cliente, posicao, tag, tipo, data_desvio, descricao, prazo_resposta, responsavel_resposta, resposta, prazo_execucao, custo, debito, status_desvio)
values (2026, 53, 'MDE- ENGENHARIA S/A', 'AURA', null, null, 'BBR-D-DF-1073-MDE-M-0034', null, '1073-PR-0002', 'rnc', '2026-10-16', '[Tipo: RNC-PRX-058-038 · Origem: MDE · Pedido 190 (não cadastrado no sistema)]
Foi evidenciado nas atividades de montagem elétrica dos suportes para passagem dos cabos de eletrificação da ponte rolante que os suportes fornecidos contém um furo para fixação dos grampos, porém os grampos são com dois furos para fixação. Da forma apresentada nao é possível realizar a montagem.', '2026-10-20', 'GABRIEL - ENGENHARIA', 'RESPOSTA AURA: REALIZAR ADEQUAÇÃO NO SUPORTE', null, null, null, 'encerrado');
insert into public.desvios_cliente (ano_desvio, numero_desvio, empresa, cliente, pedido_id, desenho, desenho_cliente, posicao, tag, tipo, data_desvio, descricao, prazo_resposta, responsavel_resposta, resposta, prazo_execucao, custo, debito, status_desvio)
values (2026, 55, 'MDE- ENGENHARIA S/A', 'AURA', null, null, 'BBR-D-DF-1073-MDE-K-0015 / 0016', null, '1073-PR-0002', 'rnc', '2026-10-22', '[Tipo: RNC-PRX-058-045 · Origem: MDE · Pedido 190 (não cadastrado no sistema)]
Foi evidenciado nas atividades de montagem elétrica e instrumentação da ponte rolante, 1073-PR-0002, que a infraestrutura existente no conjunto da alimentação dos motores de translação do carro, não comportam os cabos a serem lançados em razão da redução de 1.1/2" para 3/4" do eletroduto, ao longo da rota de ligação dos motores e as caixas de junção.', '2026-10-27', 'GABRIEL - ENGENHARIA', null, null, null, null, 'em_aberto');

commit;

-- conferência: 11 RNCs (01 a 11) e 55 desvios
select 'rnc' as tabela, count(*) as qtd, min(numero_rnc) as menor, max(numero_rnc) as maior from public.rnc where ano_rnc = 2026
union all
select 'desvios', count(*), min(numero_desvio), max(numero_desvio) from public.desvios_cliente where ano_desvio = 2026;
