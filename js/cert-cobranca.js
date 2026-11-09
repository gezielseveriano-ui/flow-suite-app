// ===== Certificados pendentes de fornecedor: cobrança por e-mail =====
// Usado no Almoxarifado e na Qualidade (mesma tela, espelhada). Precisa de
// sb, AUTH, esc e showMsg da página (supabase-client.js + a própria página).
//
// O que foi marcado PENDENTE no protocolo de NF (protocolos_nf_itens) vira
// pendência do fornecedor. "Cobrar" abre o e-mail pronto no Outlook (mailto)
// e registra a cobrança em cert_cobrancas; passou do prazo
// (cert_cobranca_config.prazo_dias, 3) sem o certificado chegar -> cobra de
// novo. "Chegou" marca OK e o trigger grava a data (sql/086) -- daí sai
// quantos dias cada fornecedor demorou.
//
// Quem cobra: a 1ª cobrança é do Almoxarifado (ou Logística); da 2ª em
// diante é da Qualidade. A 1ª vai para Compras (COMPRAS) com o fornecedor em
// cópia; a partir da 2ª vai direto para o fornecedor. Admin faz as duas. Dar baixa ("Chegou") e cadastrar
// fornecedor: os quatro perfis.
const CertCobranca = (() => {
  const PERFIS_1A = ['almoxarifado', 'logistica', 'admin'];
  const PERFIS_RECOBRA = ['qualidade', 'admin'];
  const PERFIS_EDITA = ['almoxarifado', 'logistica', 'qualidade', 'admin'];
  // a 1ª cobrança vai para Compras, com o fornecedor em cópia; da 2ª em diante
  // a Qualidade cobra o fornecedor direto
  const COMPRAS = { nome: 'Gerson', email: 'gerson.cunha@mde.ind.br' };
  // responsável da Qualidade: em cópia na 1ª cobrança, faz as seguintes
  const QUALIDADE = { nome: 'Vagner Lucio', email: 'vagner.lucio@mde.ind.br' };
  const perfil = () => AUTH?.perfil;
  const podeEditar = () => PERFIS_EDITA.includes(perfil());
  const podePrimeira = () => PERFIS_1A.includes(perfil());
  const podeRecobrar = () => PERFIS_RECOBRA.includes(perfil());

  let FORN = [], COBR = [], LINHAS = [], CFG = { cc_padrao: '', prazo_dias: 3 };
  let ABA = 'pendencias';  // 'pendencias' | 'fornecedores' | 'historico'
  let ENVIO = null, FORN_EDIT = null, ALVO = null;

  const DIA_MS = 86400000;
  const diasEntre = (a, b = new Date()) => Math.max(0, Math.floor((new Date(b) - new Date(a)) / DIA_MS));
  const fmtData = s => { const m = String(s || '').match(/^(\d{4})-(\d{2})-(\d{2})/); return m ? `${m[3]}/${m[2]}/${m[1]}` : ''; };
  const normNome = s => String(s || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim();
  const listaEmails = s => String(s || '').split(/[;,\s]+/).map(e => e.trim()).filter(e => e.includes('@'));
  const $ = id => document.getElementById(id);

  // ── estilo e modais (as duas páginas têm .btn/.dtbl/.tbl-wrap e as mesmas cores) ──
  function montarUmaVez(){
    if ($('ccxEstilo')) return;
    const st = document.createElement('style'); st.id = 'ccxEstilo';
    st.textContent = `
      #badgeCert:empty{display:none}
      #badgeCert{display:inline-block;min-width:18px;padding:1px 6px;margin-left:4px;border-radius:999px;background:var(--red);color:#fff;font-size:10.5px;font-weight:700}
      .ccx-chips{display:flex;gap:8px;margin-bottom:1.1rem;flex-wrap:wrap}
      .ccx-chip{padding:8px 16px;border-radius:999px;border:1px solid var(--border);background:var(--bg2);font-size:13px;font-weight:600;color:var(--text2);cursor:pointer}
      .ccx-chip:hover{border-color:var(--blue);color:var(--blue)}
      .ccx-chip.on{background:var(--blue);border-color:var(--blue);color:#fff}
      .ccx-chip .n{font-weight:500;opacity:.75;margin-left:4px}
      .ccx-resumo{display:grid;grid-template-columns:repeat(auto-fit,minmax(140px,1fr));gap:1px;background:var(--border);border:1px solid var(--border);border-radius:10px;overflow:hidden;margin-bottom:1.25rem}
      .ccx-stat{background:var(--bg2);padding:.9rem 1rem}
      .ccx-stat .k{font-size:10.5px;color:var(--text3);text-transform:uppercase;letter-spacing:.05em;margin-bottom:.3rem}
      .ccx-stat .v{font-size:1.2rem;font-weight:700}
      .ccx-stat.err .v{color:var(--red)} .ccx-stat.warn .v{color:var(--amber,#b5690a)} .ccx-stat.ok .v{color:var(--green)}
      .ccx-forn{background:var(--bg2);border:1px solid var(--border);border-radius:var(--radius);box-shadow:var(--shadow-sm);margin-bottom:14px;overflow:hidden}
      .ccx-forn.atrasado{border-color:rgba(220,38,38,.45)}
      .ccx-forn .tbl-wrap{border:none;border-radius:0;box-shadow:none}
      .ccx-head{display:flex;align-items:center;justify-content:space-between;gap:12px;flex-wrap:wrap;padding:12px 16px;border-bottom:1px solid var(--border)}
      .ccx-nome{font-size:14.5px;font-weight:700}
      .ccx-email{font-size:12px;color:var(--text2)}
      .ccx-email.falta{color:var(--red);font-weight:600}
      .ccx-quem{font-size:12px;color:var(--text2);font-style:italic}
      .ccx-badge{display:inline-block;padding:2px 9px;border-radius:20px;font-size:10.5px;font-weight:600;white-space:nowrap}
      .ccx-badge.vermelho{background:var(--red-dim);color:var(--red)}
      .ccx-badge.azul{background:var(--blue-dim);color:var(--blue)}
      .ccx-badge.verde{background:var(--green-dim);color:var(--green)}
      .ccx-btn-red{background:var(--red);border-color:var(--red);color:#fff;font-weight:600}
      .ccx-btn-red:hover{background:#B91C1C;border-color:#B91C1C;color:#fff}
      .ccx-mini{padding:4px 9px;font-size:11.5px}
      .ccx-link{color:var(--blue);cursor:pointer;font-size:12px;font-weight:600}
      .ccx-link:hover{text-decoration:underline}
      .ccx-sec{font-size:14px;font-weight:700;margin:1.5rem 0 .6rem;display:flex;justify-content:space-between;align-items:center;gap:10px}
      .ccx-dica{color:var(--text2);font-size:12px;font-weight:400}
      .ccx-vazio{text-align:center;padding:3rem 2rem;color:var(--text2);font-size:13px}
      .ccx-aviso{margin:0 0 12px;padding:8px 14px;border-radius:10px;background:#FEF3C7;color:#92400E;font-size:12.5px}
      .ccx-linha{display:flex;gap:10px;margin-bottom:1rem;flex-wrap:wrap;align-items:center}
      .ccx-linha input{padding:10px 13px;border:1px solid var(--border);border-radius:var(--radius-sm);background:var(--bg2);color:var(--text);font-size:13px}
      .ccx-linha input.larga{flex:1;min-width:240px}
      .ccx-linha input.num{width:70px;text-align:right}
      .ccx-overlay{position:fixed;inset:0;background:rgba(15,23,42,.55);display:none;align-items:flex-start;justify-content:center;z-index:400;padding:3rem 1rem;overflow-y:auto}
      .ccx-overlay.show{display:flex}
      .ccx-box{background:var(--bg2);border-radius:var(--radius);max-width:680px;width:100%;box-shadow:var(--shadow-md);padding:1.5rem}
      .ccx-titulo{font-size:16px;font-weight:700;margin-bottom:.5rem}
      .ccx-sub{font-size:12.5px;color:var(--text2);margin-bottom:1rem}
      .ccx-form{display:flex;flex-direction:column;gap:12px}
      .ccx-form label{display:flex;flex-direction:column;gap:5px;font-size:12px;font-weight:600;color:var(--text2)}
      .ccx-form input,.ccx-form textarea{padding:9px 11px;border:1px solid var(--border);border-radius:var(--radius-sm);background:var(--bg2);color:var(--text);font-size:13px;font-family:inherit;font-weight:400}
      .ccx-form input:focus,.ccx-form textarea:focus{outline:none;border-color:var(--blue)}
      .ccx-form textarea{min-height:300px;line-height:1.45;resize:vertical}
      .ccx-form .req::after{content:' *';color:var(--red)}
      .ccx-erro{display:none;margin:0 0 1rem;padding:10px 14px;border-radius:var(--radius-sm);font-size:13px;background:var(--red-dim);color:var(--red)}
      .ccx-erro.show{display:block}
      .ccx-acoes{display:flex;gap:10px;justify-content:flex-end;margin-top:1.25rem;flex-wrap:wrap}
      @media (max-width:640px){.ccx-overlay{padding:1rem .5rem}.ccx-box{padding:1rem}}`;
    document.head.appendChild(st);

    const div = document.createElement('div');
    div.innerHTML = `
    <div class="ccx-overlay" id="ccxModalCob">
      <div class="ccx-box">
        <div class="ccx-titulo" id="ccxCobTitulo">Cobrar certificado</div>
        <div class="ccx-sub">Confira o texto. Ao clicar no botão azul o e-mail abre pronto no Outlook — é só clicar em <b>Enviar</b> lá. A cobrança fica registrada e a contagem de dias começa.</div>
        <div class="ccx-erro" id="ccxCobErro"></div>
        <div class="ccx-form">
          <label><span class="req">Para</span><input id="ccxPara"></label>
          <label>Cópia (Cc)<input id="ccxCc"></label>
          <label><span class="req">Assunto</span><input id="ccxAssunto"></label>
          <label>Mensagem<textarea id="ccxCorpo"></textarea></label>
        </div>
        <div class="ccx-acoes">
          <button class="btn" onclick="CertCobranca.fechar('ccxModalCob')">Cancelar</button>
          <button class="btn" onclick="CertCobranca.copiar()">📋 Copiar texto</button>
          <button class="btn btn-primary" id="ccxBtnEnviar" onclick="CertCobranca.enviar()">📧 Abrir e-mail e registrar cobrança</button>
        </div>
      </div>
    </div>
    <div class="ccx-overlay" id="ccxModalForn">
      <div class="ccx-box">
        <div class="ccx-titulo" id="ccxFornTitulo">Cadastrar fornecedor</div>
        <div class="ccx-sub">O e-mail de cobrança vai para quem estiver em "Para". Separe vários e-mails com ponto e vírgula ( ; ).</div>
        <div class="ccx-erro" id="ccxFornErro"></div>
        <div class="ccx-form">
          <label><span class="req">Nome do fornecedor</span><input id="ccxFNome" list="ccxNomes"></label>
          <datalist id="ccxNomes"></datalist>
          <label>Como aparece na O.C./NF <span class="ccx-dica">outros jeitos que o nome vem escrito, separados por ; (o Sapiens corta em 20 letras)</span><input id="ccxFApelidos"></label>
          <label><span class="req">E-mail (Para)</span><input id="ccxFPara" placeholder="qualidade@fornecedor.com.br; vendas@fornecedor.com.br"></label>
          <label>E-mail em cópia só deste fornecedor<input id="ccxFCc" placeholder="vendedor, representante..."></label>
          <label>Contato<input id="ccxFContato" placeholder="nome / telefone de quem cuida"></label>
        </div>
        <div class="ccx-acoes">
          <button class="btn ccx-btn-red" id="ccxFExcluir" style="margin-right:auto" onclick="CertCobranca.excluirForn()">Excluir</button>
          <button class="btn" onclick="CertCobranca.fechar('ccxModalForn')">Cancelar</button>
          <button class="btn btn-primary" onclick="CertCobranca.salvarForn()">Salvar</button>
        </div>
      </div>
    </div>`;
    document.body.appendChild(div);
  }

  // o nome vem do Sapiens cortado em 20 letras ("Port Dsitribuidora d") -- casa
  // pelo nome, pelos apelidos ou quando um começa com o outro
  function acharForn(nome){
    const n = normNome(nome);
    if (!n) return null;
    return FORN.find(f => [f.nome, ...(f.apelidos || [])].some(a => {
      const x = normNome(a);
      return x && (x === n || (x.length >= 6 && n.startsWith(x)) || (n.length >= 6 && x.startsWith(n)));
    })) || null;
  }

  async function badge(elId){
    const el = $(elId);
    if (!el) return;
    montarUmaVez();
    const { count, error } = await sb.from('protocolos_nf_itens').select('id', { count: 'exact', head: true }).eq('certificado', 'pendente');
    el.textContent = !error && count ? count : '';
  }

  async function carregar(){
    const [f, c, cfg, l] = await Promise.all([
      sb.from('cert_fornecedores').select('*').order('nome'),
      sb.from('cert_cobrancas').select('*').order('enviado_em'),
      sb.from('cert_cobranca_config').select('*').eq('id', 1).maybeSingle(),
      // pendentes + os que já chegaram (pro histórico de dias)
      sb.from('protocolos_nf_itens')
        .select('id, oc, nf, fornecedor, data_nf, pedido, certificado, certificado_recebido_em, protocolos_nf(numero, cnpj, data)')
        .in('certificado', ['pendente', 'ok']),
    ]);
    const erro = f.error || c.error || cfg.error || l.error;
    if (erro) throw erro;
    FORN = f.data || []; COBR = c.data || []; LINHAS = l.data || [];
    if (cfg.data) CFG = cfg.data;
    const porLinha = new Map();
    COBR.forEach(cb => (cb.itens || []).forEach(id => { if (!porLinha.has(id)) porLinha.set(id, []); porLinha.get(id).push(cb); }));
    LINHAS.forEach(x => {
      x.cobrancas = porLinha.get(x.id) || [];
      x.forn = acharForn(x.fornecedor);
      x.data_ref = x.data_nf || x.protocolos_nf?.data || null;
    });
  }

  // situação de uma linha pendente: nunca cobrada / aguardando / prazo vencido
  function situacao(x){
    if (x.certificado === 'ok') return { cod: 'ok', txt: 'Chegou', cor: 'verde' };
    if (!x.cobrancas.length) return { cod: 'cobrar', txt: '1ª cobrança — Almoxarifado', cor: 'vermelho' };
    const d = diasEntre(x.cobrancas[x.cobrancas.length - 1].enviado_em);
    if (d >= CFG.prazo_dias) return { cod: 'recobrar', txt: `Cobrar de novo — Qualidade (${d} dias sem resposta)`, cor: 'vermelho' };
    return { cod: 'aguardando', txt: `Aguardando · faltam ${CFG.prazo_dias - d} dia(s)`, cor: 'azul' };
  }

  async function render(alvo, aba){
    montarUmaVez();
    if (alvo) ALVO = alvo;
    if (aba) ABA = aba;
    ALVO.innerHTML = `<div class="ccx-vazio">Carregando...</div>`;
    try { await carregar(); }
    catch (err){
      ALVO.innerHTML = `<div class="ccx-vazio">${/cert_|certificado_recebido_em|does not exist|schema cache/i.test(err.message)
        ? 'Falta rodar o <b>sql/086_cobranca_certificados.sql</b> no Supabase.' : 'Erro: ' + esc(err.message)}</div>`;
      return;
    }
    const pend = LINHAS.filter(x => x.certificado === 'pendente');
    const n = { pendencias: pend.length, fornecedores: FORN.length, historico: COBR.length };
    ALVO.innerHTML = `
      ${podeEditar() ? '' : '<div class="ccx-aviso">Cobrar e dar baixa é pelo Almoxarifado, Logística, Qualidade ou Administrador.</div>'}
      <div class="ccx-chips">
        ${[['pendencias', '⏳ Pendências'], ['fornecedores', '🏢 Fornecedores e e-mails'], ['historico', '📊 Histórico']].map(([k, t]) =>
          `<span class="ccx-chip ${ABA === k ? 'on' : ''}" onclick="CertCobranca.render(null, '${k}')">${t}<span class="n">${n[k]}</span></span>`).join('')}
      </div>
      <div id="ccxConteudo"></div>`;
    ({ pendencias: renderPendencias, fornecedores: renderFornecedores, historico: renderHistorico })[ABA]();
  }

  function renderPendencias(){
    const wrap = $('ccxConteudo');
    const pend = LINHAS.filter(x => x.certificado === 'pendente');
    if (!pend.length){
      wrap.innerHTML = `<div class="ccx-vazio">Nenhum certificado pendente. 👍<br><br><span class="ccx-dica">A pendência nasce quando a NF entra no protocolo do Almoxarifado (aba 📑 Protocolo) com Certificado = PENDENTE.</span></div>`;
      return;
    }
    // agrupa por fornecedor cadastrado (ou pelo nome cru, se ainda não tem cadastro)
    const grupos = new Map();
    pend.forEach(x => {
      const k = x.forn ? 'f' + x.forn.id : 'n' + normNome(x.fornecedor);
      if (!grupos.has(k)) grupos.set(k, { k, forn: x.forn, nome: x.forn?.nome || x.fornecedor || '(sem fornecedor)', linhas: [] });
      grupos.get(k).linhas.push(x);
    });
    const lista = [...grupos.values()].map(g => {
      g.sits = g.linhas.map(situacao);
      g.primeira = g.sits.some(s => s.cod === 'cobrar');
      g.atrasado = g.sits.some(s => s.cod === 'recobrar');
      g.maisAntiga = Math.max(...g.linhas.map(x => x.data_ref ? diasEntre(x.data_ref) : 0));
      return g;
    }).sort((a, b) => b.atrasado - a.atrasado || b.primeira - a.primeira || b.maisAntiga - a.maisAntiga);

    const nPrimeira = lista.filter(g => g.primeira).length;
    const nRecobrar = lista.filter(g => g.atrasado).length;
    const semCadastro = lista.filter(g => !g.forn).length;
    wrap.innerHTML = `
      <div class="ccx-resumo">
        <div class="ccx-stat err"><div class="k">NFs sem certificado</div><div class="v">${pend.length}</div></div>
        <div class="ccx-stat"><div class="k">Fornecedores</div><div class="v">${lista.length}</div></div>
        <div class="ccx-stat ${nPrimeira ? 'err' : 'ok'}"><div class="k">1ª cobrança (Almox.)</div><div class="v">${nPrimeira}</div></div>
        <div class="ccx-stat ${nRecobrar ? 'err' : 'ok'}"><div class="k">Cobrar de novo (Qualidade)</div><div class="v">${nRecobrar}</div></div>
        <div class="ccx-stat warn"><div class="k">Mais antiga</div><div class="v">${Math.max(...lista.map(g => g.maisAntiga))} dias</div></div>
        ${semCadastro ? `<div class="ccx-stat warn"><div class="k">Sem e-mail cadastrado</div><div class="v">${semCadastro}</div></div>` : ''}
      </div>
      ${lista.map(g => {
        return `
        <div class="ccx-forn ${g.atrasado ? 'atrasado' : ''}">
          <div class="ccx-head">
            <div>
              <div class="ccx-nome">${esc(g.nome)}${g.forn && podeEditar() ? ` <span class="ccx-link" onclick="CertCobranca.abrirForn(${g.forn.id})">editar</span>` : ''}</div>
              <div class="ccx-email ${g.forn ? '' : 'falta'}">${g.forn ? '📧 ' + esc(g.forn.email_para) : '⚠ Fornecedor sem e-mail cadastrado — cadastre para poder cobrar'}</div>
            </div>
            <div>${botaoGrupo(g)}</div>
          </div>
          <div class="tbl-wrap"><table class="dtbl">
            <thead><tr><th>NF</th><th>O.C.</th><th>Pedido</th><th>Recebida em</th><th style="text-align:right">Dias sem certificado</th><th>Cobranças</th><th>Situação</th>${podeEditar() ? '<th></th>' : ''}</tr></thead>
            <tbody>${g.linhas.map((x, i) => {
              const s = g.sits[i];
              const ult = x.cobrancas[x.cobrancas.length - 1];
              return `<tr>
                <td><strong>${esc(x.nf)}</strong></td><td>${esc(x.oc || '—')}</td><td>${esc(x.pedido || '—')}</td>
                <td>${fmtData(x.data_ref) || '—'}</td>
                <td style="text-align:right"><strong>${x.data_ref ? diasEntre(x.data_ref) : '—'}</strong></td>
                <td>${x.cobrancas.length ? `${x.cobrancas.length}× · última ${fmtData(ult.enviado_em)}` : '—'}</td>
                <td><span class="ccx-badge ${s.cor}">${s.txt}</span></td>
                ${podeEditar() ? `<td><span class="btn ccx-mini" onclick="CertCobranca.chegou(${x.id})" title="O certificado chegou — tira da cobrança">✓ Chegou</span></td>` : ''}
              </tr>`;
            }).join('')}</tbody>
          </table></div>
        </div>`;
      }).join('')}`;
  }

  // 1ª cobrança é do Almoxarifado; da 2ª em diante, da Qualidade
  function botaoGrupo(g){
    if (!podeEditar()) return '';
    if (!g.forn) return `<span class="btn btn-primary" onclick="CertCobranca.abrirForn(null, ${esc(JSON.stringify(g.linhas[0].fornecedor || ''))})">＋ Cadastrar e-mail</span>`;
    // cada botão cobra só as NFs daquela etapa (o fornecedor pode ter NF nova
    // e NF já cobrada ao mesmo tempo -- viram dois e-mails diferentes)
    const cobrar = (modo, cls, txt, title = '') => `<span class="btn ${cls}" title="${title}" onclick="CertCobranca.abrirCobranca('${g.k}', '${modo}')">📧 ${txt}</span>`;
    const nVencidas = Math.max(0, ...g.linhas.filter((x, i) => g.sits[i].cod === 'recobrar').map(x => x.cobrancas.length));
    const b = [];
    if (g.primeira) b.push(podePrimeira() ? cobrar('primeira', 'btn-primary', 'Cobrar certificado (1ª cobrança)')
      : `<span class="ccx-quem">1ª cobrança é com o Almoxarifado</span>`);
    if (g.atrasado) b.push(podeRecobrar() ? cobrar('recobrar', 'ccx-btn-red', `Cobrar de novo (${nVencidas + 1}ª cobrança)`)
      : `<span class="ccx-quem">Prazo vencido — a ${nVencidas + 1}ª cobrança é com a Qualidade</span>`);
    if (!b.length && podeRecobrar()) b.push(cobrar('todas', '', 'Cobrar mesmo assim', 'Ainda no prazo — dá pra cobrar antes se quiser'));
    return b.join(' ');
  }

  async function chegou(id){
    const x = LINHAS.find(l => l.id === id);
    if (!confirm(`Certificado da NF ${x.nf} (${x.fornecedor || 'fornecedor'}) chegou?`)) return;
    const { error } = await sb.from('protocolos_nf_itens').update({ certificado: 'ok' }).eq('id', id);
    if (error){ showMsg('Erro ao dar baixa: ' + error.message, false); return; }
    await render();
    const dias = x.cobrancas.length ? diasEntre(x.cobrancas[0].enviado_em) : null;
    showMsg(`Certificado da NF ${x.nf} recebido${dias !== null ? ` — ${dias} dia(s) depois da 1ª cobrança` : ''}.`, true);
  }

  // ── e-mail de cobrança ──
  function texto(linhas, seq){
    const prazo = CFG.prazo_dias;
    const itens = linhas.map(x => `• NF ${x.nf}${x.oc ? ' · O.C. ' + x.oc : ''}${x.data_ref ? ' · recebida em ' + fmtData(x.data_ref) : ''}${x.pedido ? ' · Pedido ' + x.pedido : ''}`).join('\n');
    const setor = seq <= 1 ? 'Almoxarifado' : 'Controle de Qualidade';
    const assinatura = `Atenciosamente,\n${AUTH.nome || ''}\n${setor} — MDE`;
    const varias = linhas.length > 1;
    if (seq <= 1){
      const forn = linhas[0].forn?.nome || 'o fornecedor';
      return [
        `Prezado ${COMPRAS.nome},`,
        `Recebemos do fornecedor ${forn} o material referente ${varias ? 'às notas fiscais abaixo' : 'à nota fiscal abaixo'} sem o certificado de qualidade:`,
        itens,
        `Solicitamos o apoio de Compras para que ${varias ? 'os certificados sejam enviados' : 'o certificado seja enviado'} no prazo de até ${prazo} (${['', 'um', 'dois', 'três', 'quatro', 'cinco'][prazo] || prazo}) dia${prazo > 1 ? 's' : ''}. O fornecedor está em cópia e pode responder a este e-mail diretamente com ${varias ? 'os certificados' : 'o certificado'}.`,
        'Reforçamos que o certificado de qualidade é documento obrigatório em todo fornecimento de matéria-prima para a MDE. Ele garante a rastreabilidade do material e faz parte da documentação técnica (data book) que entregamos aos nossos clientes. Sem ele, a liberação do material e a documentação do pedido ficam comprometidas.',
        `Ao fornecedor ${forn}, pedimos que, nos próximos fornecimentos, o certificado seja enviado junto com a nota fiscal, para que essa situação não volte a acontecer.`,
        'Agradecemos a atenção e contamos com a colaboração de todos.',
        assinatura,
      ].join('\n\n');
    }
    const primeira = linhas.flatMap(x => x.cobrancas).map(c => c.enviado_em).sort()[0];
    return [
      'Prezados,',
      `Reiteramos a solicitação enviada em ${fmtData(primeira)} (há ${diasEntre(primeira)} dias), que até o momento não teve retorno. ${varias ? 'Os certificados de qualidade abaixo continuam pendentes' : 'O certificado de qualidade abaixo continua pendente'}:`,
      itens,
      'Pedimos o envio com urgência. Essa pendência compromete a liberação do material e a documentação do nosso pedido junto ao cliente.',
      'Lembramos que toda matéria-prima fornecida à MDE deve vir acompanhada do certificado de qualidade, enviado junto com a nota fiscal.',
      `Caso ${varias ? 'os certificados já tenham sido enviados' : 'o certificado já tenha sido enviado'}, pedimos a gentileza de responder a este e-mail confirmando o envio.`,
      assinatura,
    ].join('\n\n');
  }

  function abrirCobranca(k, modo = 'todas'){
    const cod = { primeira: 'cobrar', recobrar: 'recobrar' }[modo];
    const pend = LINHAS.filter(x => x.certificado === 'pendente' && x.forn && 'f' + x.forn.id === k && (!cod || situacao(x).cod === cod));
    if (!pend.length) return;
    const forn = pend[0].forn;
    const seq = Math.max(...pend.map(x => x.cobrancas.length)) + 1;
    ENVIO = { forn, linhas: pend, seq };
    $('ccxCobTitulo').textContent = `${seq}ª cobrança — ${forn.nome}`;
    const fornEmails = [...listaEmails(forn.email_para), ...listaEmails(forn.email_cc)];
    const para = seq <= 1 ? [COMPRAS.email] : listaEmails(forn.email_para);
    const cc = seq <= 1 ? [...fornEmails, QUALIDADE.email, ...listaEmails(CFG.cc_padrao)] : [...listaEmails(forn.email_cc), ...listaEmails(CFG.cc_padrao)];
    $('ccxPara').value = para.join('; ');
    $('ccxCc').value = [...new Set(cc)].filter(e => !para.includes(e)).join('; ');
    $('ccxAssunto').value = `${seq > 1 ? `${seq}ª COBRANÇA — ` : ''}MDE — Certificado de qualidade pendente — NF ${pend.map(x => x.nf).join(', ')}`;
    $('ccxCorpo').value = texto(pend, seq);
    $('ccxCobErro').classList.remove('show');
    $('ccxBtnEnviar').disabled = false;
    $('ccxModalCob').classList.add('show');
  }

  async function copiar(){
    try { await navigator.clipboard.writeText($('ccxCorpo').value); showMsg('Texto copiado — é só colar no e-mail.', true); }
    catch (e) { $('ccxCorpo').select(); }
  }

  async function enviar(){
    const v = id => $(id).value.trim();
    const para = listaEmails(v('ccxPara')), cc = listaEmails(v('ccxCc'));
    const erro = $('ccxCobErro');
    if (!para.length){ erro.textContent = 'Informe pelo menos um e-mail em "Para".'; erro.classList.add('show'); return; }
    const btn = $('ccxBtnEnviar'); btn.disabled = true;
    const { forn, linhas, seq } = ENVIO;
    const { error } = await sb.from('cert_cobrancas').insert({
      fornecedor_id: forn.id, fornecedor_nome: forn.nome, itens: linhas.map(x => x.id), sequencia: seq,
      para: para.join('; '), cc: cc.join('; ') || null, assunto: v('ccxAssunto'), enviado_por_nome: AUTH.nome,
    });
    if (error){ btn.disabled = false; erro.textContent = 'Erro ao registrar cobrança: ' + error.message; erro.classList.add('show'); return; }
    const q = [cc.length ? 'cc=' + encodeURIComponent(cc.join(';')) : '', 'subject=' + encodeURIComponent(v('ccxAssunto')),
      'body=' + encodeURIComponent($('ccxCorpo').value.replace(/\r?\n/g, '\r\n'))].filter(Boolean).join('&');
    window.location.href = `mailto:${para.join(';')}?${q}`;
    fechar('ccxModalCob');
    await render();
    showMsg(`Cobrança registrada (${seq}ª) para ${forn.nome}. Confira o e-mail que abriu no Outlook e clique em Enviar. Se não abriu, use "📋 Copiar texto".`, true);
  }

  // ── cadastro de fornecedores ──
  function renderFornecedores(){
    const wrap = $('ccxConteudo');
    const ed = podeEditar() ? '' : 'disabled';
    wrap.innerHTML = `
      <div class="ccx-sec">Sempre em cópia nas cobranças</div>
      <div class="ccx-linha">
        <input class="larga" id="ccxCcPadrao" ${ed} value="${esc(CFG.cc_padrao || '')}" placeholder="ex.: qualidade@... ; compras@... (separe com ;)">
        <label class="ccx-dica">Cobrar de novo a cada <input class="num" type="number" min="1" max="30" id="ccxPrazo" ${ed} value="${CFG.prazo_dias}"> dias</label>
        ${podeEditar() ? '<span class="btn btn-primary" onclick="CertCobranca.salvarConfig()">Salvar</span>' : ''}
      </div>
      <div class="ccx-sec">Fornecedores cadastrados
        ${podeEditar() ? '<span class="btn btn-primary" onclick="CertCobranca.abrirForn(null)">＋ Cadastrar fornecedor</span>' : ''}</div>
      ${FORN.length ? `<div class="tbl-wrap"><table class="dtbl">
        <thead><tr><th>Fornecedor</th><th>Para</th><th>Cópia</th><th>Contato</th><th style="text-align:right">Pendentes</th>${podeEditar() ? '<th></th>' : ''}</tr></thead>
        <tbody>${FORN.map(f => `<tr>
          <td><strong>${esc(f.nome)}</strong>${(f.apelidos || []).length ? `<div class="ccx-dica">${esc(f.apelidos.join(' · '))}</div>` : ''}</td>
          <td>${esc(f.email_para)}</td><td>${esc(f.email_cc || '—')}</td><td>${esc(f.contato || '—')}</td>
          <td style="text-align:right">${LINHAS.filter(x => x.certificado === 'pendente' && x.forn?.id === f.id).length || '—'}</td>
          ${podeEditar() ? `<td><span class="btn ccx-mini" onclick="CertCobranca.abrirForn(${f.id})">Editar</span></td>` : ''}
        </tr>`).join('')}</tbody></table></div>`
      : '<div class="ccx-vazio">Nenhum fornecedor cadastrado ainda.</div>'}`;
  }

  async function salvarConfig(){
    const cc = listaEmails($('ccxCcPadrao').value).join('; ');
    const prazo = parseInt($('ccxPrazo').value, 10);
    if (!(prazo >= 1 && prazo <= 30)){ showMsg('Prazo entre 1 e 30 dias.', false); return; }
    const { error } = await sb.from('cert_cobranca_config').update({ cc_padrao: cc || null, prazo_dias: prazo }).eq('id', 1);
    if (error){ showMsg('Erro ao salvar: ' + error.message, false); return; }
    CFG = { ...CFG, cc_padrao: cc, prazo_dias: prazo };
    showMsg('Salvo.', true);
  }

  function abrirForn(id, nomeSugerido){
    montarUmaVez();
    FORN_EDIT = id ? FORN.find(f => f.id === id) : null;
    const f = FORN_EDIT || {};
    const nomes = [...new Set(LINHAS.map(x => x.fornecedor).filter(Boolean))].sort();
    $('ccxNomes').innerHTML = nomes.map(n => `<option value="${esc(n)}">`).join('');
    $('ccxFornTitulo').textContent = id ? 'Editar fornecedor' : 'Cadastrar fornecedor';
    $('ccxFNome').value = f.nome || nomeSugerido || '';
    $('ccxFApelidos').value = (f.apelidos || (nomeSugerido ? [nomeSugerido] : [])).join('; ');
    $('ccxFPara').value = f.email_para || '';
    $('ccxFCc').value = f.email_cc || '';
    $('ccxFContato').value = f.contato || '';
    $('ccxFExcluir').style.display = id ? '' : 'none';
    $('ccxFornErro').classList.remove('show');
    $('ccxModalForn').classList.add('show');
    $(nomeSugerido ? 'ccxFPara' : 'ccxFNome').focus();
  }

  async function salvarForn(){
    const v = id => $(id).value.trim();
    const erro = $('ccxFornErro');
    const falha = t => { erro.textContent = t; erro.classList.add('show'); };
    const para = listaEmails(v('ccxFPara'));
    if (!v('ccxFNome')) return falha('Informe o nome do fornecedor.');
    if (!para.length) return falha('Informe pelo menos um e-mail válido em "Para".');
    const reg = {
      nome: v('ccxFNome'), apelidos: v('ccxFApelidos').split(';').map(s => s.trim()).filter(Boolean),
      email_para: para.join('; '), email_cc: listaEmails(v('ccxFCc')).join('; ') || null, contato: v('ccxFContato') || null,
    };
    const r = FORN_EDIT ? await sb.from('cert_fornecedores').update(reg).eq('id', FORN_EDIT.id)
                        : await sb.from('cert_fornecedores').insert(reg);
    if (r.error) return falha(/duplicate|unique/i.test(r.error.message) ? 'Já existe um fornecedor com esse nome.' : 'Erro ao salvar: ' + r.error.message);
    fechar('ccxModalForn');
    await render();
    showMsg(`Fornecedor ${reg.nome} salvo.`, true);
  }

  async function excluirForn(){
    const f = FORN_EDIT;
    if (!f || !confirm(`Excluir o cadastro de ${f.nome}? O histórico de cobranças continua guardado.`)) return;
    const { error } = await sb.from('cert_fornecedores').delete().eq('id', f.id);
    if (error){ showMsg('Erro ao excluir: ' + error.message, false); return; }
    fechar('ccxModalForn');
    await render();
  }

  // ── histórico: quem demora, quantas cobranças ──
  function renderHistorico(){
    const wrap = $('ccxConteudo');
    const porForn = new Map();
    LINHAS.filter(x => x.cobrancas.length).forEach(x => {
      const nome = x.forn?.nome || x.cobrancas[0].fornecedor_nome;
      if (!porForn.has(nome)) porForn.set(nome, { nome, nfs: 0, cobrancas: 0, chegaram: [], pendentes: 0 });
      const g = porForn.get(nome);
      g.nfs++; g.cobrancas += x.cobrancas.length;
      if (x.certificado === 'ok' && x.certificado_recebido_em) g.chegaram.push(diasEntre(x.cobrancas[0].enviado_em, x.certificado_recebido_em));
      else if (x.certificado === 'pendente') g.pendentes++;
    });
    const media = a => a.length ? (a.reduce((s, n) => s + n, 0) / a.length).toLocaleString('pt-BR', { maximumFractionDigits: 1 }) : '—';
    const forns = [...porForn.values()].sort((a, b) => b.cobrancas - a.cobrancas);
    const ultimas = [...COBR].reverse().slice(0, 50);
    const r = 'style="text-align:right"';
    wrap.innerHTML = `
      <div class="ccx-sec">Por fornecedor</div>
      ${forns.length ? `<div class="tbl-wrap"><table class="dtbl">
        <thead><tr><th>Fornecedor</th><th ${r}>NFs cobradas</th><th ${r}>E-mails de cobrança</th><th ${r}>Chegaram</th><th ${r}>Ainda pendentes</th><th ${r}>Média de dias p/ enviar</th><th ${r}>Maior demora</th></tr></thead>
        <tbody>${forns.map(g => `<tr>
          <td><strong>${esc(g.nome)}</strong></td><td ${r}>${g.nfs}</td><td ${r}>${g.cobrancas}</td><td ${r}>${g.chegaram.length}</td>
          <td ${r}>${g.pendentes ? `<span class="ccx-badge vermelho">${g.pendentes}</span>` : '—'}</td>
          <td ${r}>${media(g.chegaram)}</td><td ${r}>${g.chegaram.length ? Math.max(...g.chegaram) + ' dias' : '—'}</td>
        </tr>`).join('')}</tbody></table></div>` : '<div class="ccx-vazio">Nenhuma cobrança feita ainda.</div>'}
      ${ultimas.length ? `<div class="ccx-sec">Últimas cobranças enviadas</div>
      <div class="tbl-wrap"><table class="dtbl">
        <thead><tr><th>Data</th><th>Fornecedor</th><th>Cobrança</th><th>NFs</th><th>Para</th><th>Enviado por</th></tr></thead>
        <tbody>${ultimas.map(c => `<tr>
          <td>${new Date(c.enviado_em).toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'short' })}</td>
          <td>${esc(c.fornecedor_nome)}</td><td>${c.sequencia}ª</td>
          <td>${esc((c.itens || []).map(id => LINHAS.find(x => x.id === id)?.nf).filter(Boolean).join(', ') || '—')}</td>
          <td>${esc(c.para || '')}</td><td>${esc(c.enviado_por_nome || '—')}</td>
        </tr>`).join('')}</tbody></table></div>` : ''}`;
  }

  const fechar = id => $(id).classList.remove('show');

  return { render, badge, chegou, abrirCobranca, copiar, enviar, salvarConfig, abrirForn, salvarForn, excluirForn, fechar };
})();
