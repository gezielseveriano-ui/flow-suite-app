// ── Conexão com o Supabase (compartilhada por todas as páginas) ────────────
const SUPABASE_URL = 'https://cmuhdptdkroxslxwinea.supabase.co';
const SUPABASE_KEY = 'sb_publishable_2SElqmz9NJs8Cy2NdaGBag_cVeoz4gx';

const sb = window.supabase.createClient(SUPABASE_URL, SUPABASE_KEY);

// setores válidos (precisam existir como linha em public.setores_producao,
// que tem FK a partir de itens.produto/desenhos_engenharia.setor/
// capacidade_setor.setor -- salvar um setor que não está cadastrado lá
// falha). RMF/TECMETAL/CSM saíram da lista da Engenharia -- viraram
// fornecedores terceirizados (ver fornecedores_producao/PCP), não é mais a
// Engenharia quem escolhe isso. DOCUMENTOS é pra anexos que não são desenho
// de fabricação (Word/Excel/PDF de apoio).
const SETORES = [
  'ESTRUTURA', 'USINAGEM', 'TAMBOR', 'ROLOS', 'BASES ROLETES',
  'REVESTIMENTO', 'COMERCIAL', 'DOCUMENTOS'
];

// as 9 etapas fixas, na ordem correta
const ETAPAS = [
  { key: 'materia_prima',   label: 'Matéria Prima' },
  { key: 'relatorio',       label: 'Relatório' },
  { key: 'preparacao',      label: 'Preparação' },
  { key: 'caldeiraria',     label: 'Caldeiraria' },
  { key: 'solda',           label: 'Solda' },
  { key: 'acabamento',      label: 'Acabamento' },
  { key: 'pronto_acabado',  label: 'Pronto Acabado' },
  { key: 'expedicao',       label: 'Expedição' },
  { key: 'finalizado',      label: 'Finalizado' },
];

// peso de cada etapa no cálculo de Avanço (dashboard) -- só as 5 etapas de
// produção de verdade entram, somando 100%. relatorio/pronto_acabado/
// expedicao/finalizado continuam existindo como marcadores/checkpoints, só
// não têm peso próprio no avanço. Regra definida pela empresa, mesma lógica
// que já existia no dashboard antigo (FactoryView/calcAvanco).
const PESO_AVANCO_ETAPA = {
  materia_prima: 25,
  preparacao: 25,
  caldeiraria: 22.5,
  solda: 22.5,
  acabamento: 5,
};

/* Garante que existe uma sessão ativa e um perfil válido/ativo.
   Se não houver, redireciona para o login. Retorna {user, perfil}. */
async function exigirLogin(perfisPermitidos) {
  const { data: { session } } = await sb.auth.getSession();
  if (!session) {
    window.location.href = 'login.html';
    return null;
  }
  const { data: perfilRow, error } = await sb
    .from('perfis')
    .select('nome, perfil, ativo')
    .eq('id', session.user.id)
    .single();

  if (error || !perfilRow || !perfilRow.ativo) {
    await sb.auth.signOut();
    window.location.href = 'login.html?erro=perfil_invalido';
    return null;
  }

  if (perfisPermitidos && !perfisPermitidos.includes(perfilRow.perfil)) {
    window.location.href = 'index.html';
    return null;
  }

  return { user: session.user, nome: perfilRow.nome, perfil: perfilRow.perfil };
}

async function logout() {
  await sb.auth.signOut();
  window.location.href = 'login.html';
}

function esc(s) {
  return String(s ?? '').replace(/[&<>"']/g, c => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
  }[c]));
}

// ── SININHO DE AVISOS (desenhos paralisados pela Engenharia) ───────────────
// Compartilhado por todas as páginas: chama iniciarSininho('idDoContainer')
// no init() de cada módulo, com um <div id="..."></div> vazio no top-bar.
async function iniciarSininho(containerId){
  const wrap = document.getElementById(containerId);
  if (!wrap) return;
  wrap.style.position = 'relative';
  wrap.innerHTML = `
    <button type="button" id="sininhoBtn" title="Avisos importantes" style="position:relative;background:rgba(255,255,255,.14);border:1px solid rgba(255,255,255,.25);border-radius:8px;padding:7px 10px;cursor:pointer;font-size:15px;color:inherit;line-height:1">
      🔔<span id="sininhoBadge" style="display:none;position:absolute;top:-5px;right:-5px;background:#c0392b;color:#fff;border-radius:10px;font-size:10px;font-weight:700;padding:1px 5px;line-height:1.4"></span>
    </button>
    <div id="sininhoPainel" style="display:none;position:absolute;top:120%;right:0;width:340px;max-height:420px;overflow-y:auto;background:var(--bg2);color:var(--text);border:1px solid var(--border);border-radius:var(--radius-sm);box-shadow:0 12px 28px rgba(0,0,0,.3);z-index:1000;text-align:left"></div>`;

  document.getElementById('sininhoBtn').addEventListener('click', async (e) => {
    e.stopPropagation();
    const painel = document.getElementById('sininhoPainel');
    const abrindo = painel.style.display === 'none';
    painel.style.display = abrindo ? 'block' : 'none';
    if (abrindo) await atualizarSininho();
  });
  document.getElementById('sininhoPainel').addEventListener('click', e => e.stopPropagation());
  document.addEventListener('click', () => {
    const painel = document.getElementById('sininhoPainel');
    if (painel) painel.style.display = 'none';
  });

  await atualizarSininho();
}

async function atualizarSininho(){
  const badge = document.getElementById('sininhoBadge');
  const painel = document.getElementById('sininhoPainel');
  if (!badge || !painel) return;

  const { data, error } = await sb
    .from('desenhos_engenharia')
    .select('id, codigo_mde, desenho_mde, paralisado_em, paralisado_motivo')
    .eq('paralisado', true)
    .order('paralisado_em', { ascending: false });

  if (error || !data || !data.length){
    badge.style.display = 'none';
    painel.innerHTML = `<div style="padding:14px;font-size:12px;color:var(--text2)">Nenhum desenho paralisado no momento.</div>`;
    return;
  }

  badge.textContent = data.length;
  badge.style.display = 'inline-block';

  painel.innerHTML = `
    <div style="padding:10px 14px;font-weight:700;font-size:12px;border-bottom:1px solid var(--border)">⏸ ${data.length} desenho(s) paralisado(s)</div>
    ${data.map(d => {
      const dias = Math.floor((Date.now() - new Date(d.paralisado_em).getTime()) / 86400000);
      return `<div style="padding:10px 14px;border-bottom:1px solid var(--border);font-size:12px">
        <div style="font-weight:600">Cód. MDE ${d.codigo_mde} — ${esc(d.desenho_mde)}</div>
        <div style="color:var(--text2);margin-top:2px">Paralisado em ${new Date(d.paralisado_em).toLocaleString('pt-BR')}${dias > 0 ? ` (há ${dias} dia${dias > 1 ? 's' : ''})` : ''}</div>
        ${d.paralisado_motivo ? `<div style="color:var(--text2);margin-top:4px;font-style:italic">"${esc(d.paralisado_motivo)}"</div>` : ''}
      </div>`;
    }).join('')}`;
}

// ── CARTINHA: pedidos de revisão de desenho (Produção/PCP → Engenharia) ────
// Compartilhado igual o sininho: chama iniciarCartinha('idDoContainer') no
// init() de cada módulo. Fica visível pra todo mundo; só Engenharia/admin
// vê o campo de resposta. Nunca some sozinho — só quando alguém responde.
async function iniciarCartinha(containerId){
  const wrap = document.getElementById(containerId);
  if (!wrap) return;
  wrap.style.position = 'relative';
  wrap.innerHTML = `
    <button type="button" id="cartinhaBtn" title="Pedidos de revisão de desenho" style="position:relative;background:rgba(255,255,255,.14);border:1px solid rgba(255,255,255,.25);border-radius:8px;padding:7px 10px;cursor:pointer;font-size:15px;color:inherit;line-height:1">
      ✉️<span id="cartinhaBadge" style="display:none;position:absolute;top:-5px;right:-5px;background:#c0392b;color:#fff;border-radius:10px;font-size:10px;font-weight:700;padding:1px 5px;line-height:1.4"></span>
    </button>
    <div id="cartinhaPainel" style="display:none;position:absolute;top:120%;right:0;width:360px;max-height:440px;overflow-y:auto;background:var(--bg2);color:var(--text);border:1px solid var(--border);border-radius:var(--radius-sm);box-shadow:0 12px 28px rgba(0,0,0,.3);z-index:1000;text-align:left"></div>`;

  document.getElementById('cartinhaBtn').addEventListener('click', async (e) => {
    e.stopPropagation();
    const painel = document.getElementById('cartinhaPainel');
    const abrindo = painel.style.display === 'none';
    painel.style.display = abrindo ? 'block' : 'none';
    if (abrindo) await atualizarCartinha();
  });
  document.getElementById('cartinhaPainel').addEventListener('click', e => e.stopPropagation());
  document.addEventListener('click', () => {
    const painel = document.getElementById('cartinhaPainel');
    if (painel) painel.style.display = 'none';
  });

  await atualizarCartinha();
}

async function atualizarCartinha(){
  const badge = document.getElementById('cartinhaBadge');
  const painel = document.getElementById('cartinhaPainel');
  if (!badge || !painel) return;

  const { data, error } = await sb
    .from('revisoes_desenho')
    .select('id, observacao, solicitado_por_nome, solicitado_em, respondido, resposta, respondido_por_nome, respondido_em, desenhos_engenharia(codigo_mde, desenho_mde)')
    .order('solicitado_em', { ascending: false })
    .limit(50);

  if (error || !data){ badge.style.display = 'none'; painel.innerHTML = `<div style="padding:14px;font-size:12px;color:var(--text2)">Erro ao carregar.</div>`; return; }

  const abertas = data.filter(r => !r.respondido);
  badge.textContent = abertas.length;
  badge.style.display = abertas.length ? 'inline-block' : 'none';

  const podeResponder = typeof AUTH !== 'undefined' && AUTH && (AUTH.perfil === 'engenharia' || AUTH.perfil === 'admin');

  if (!data.length){
    painel.innerHTML = `<div style="padding:14px;font-size:12px;color:var(--text2)">Nenhum pedido de revisão ainda.</div>`;
    return;
  }

  painel.innerHTML = `
    <div style="padding:10px 14px;font-weight:700;font-size:12px;border-bottom:1px solid var(--border)">✉️ ${abertas.length} pedido(s) de revisão em aberto</div>
    ${data.map(r => {
      const d = r.desenhos_engenharia;
      return `<div style="padding:10px 14px;border-bottom:1px solid var(--border);font-size:12px;${r.respondido ? 'opacity:.65' : ''}">
        <div style="font-weight:600">Cód. MDE ${d?.codigo_mde ?? '—'} — ${esc(d?.desenho_mde || '')}</div>
        <div style="color:var(--text2);margin-top:2px">Pedido por ${esc(r.solicitado_por_nome || '—')} em ${new Date(r.solicitado_em).toLocaleString('pt-BR')}</div>
        <div style="color:var(--text2);margin-top:4px;font-style:italic">"${esc(r.observacao)}"</div>
        ${r.respondido
          ? `<div style="margin-top:6px;padding:6px 8px;background:rgba(16,185,129,.12);border-radius:6px;color:#0d9488">
              <strong>✓ Respondida</strong> por ${esc(r.respondido_por_nome || '—')} em ${new Date(r.respondido_em).toLocaleString('pt-BR')}
              ${r.resposta ? `<div style="margin-top:3px;font-style:italic">"${esc(r.resposta)}"</div>` : ''}
            </div>`
          : (podeResponder
            ? `<div style="margin-top:6px">
                <textarea id="respostaTexto-${r.id}" placeholder="Responder ao pedido de revisão..." style="width:100%;min-height:44px;padding:6px 8px;border:1px solid var(--border);border-radius:6px;background:var(--bg3);color:var(--text);font-size:12px;font-family:inherit"></textarea>
                <button type="button" onclick="responderRevisaoDesenho(${r.id})" style="margin-top:4px;padding:5px 10px;border:none;border-radius:6px;background:#2563eb;color:#fff;font-size:11px;font-weight:600;cursor:pointer">Marcar como respondida</button>
              </div>`
            : `<div style="margin-top:6px;font-size:11px;color:#b5690a;font-weight:600">⏳ Aguardando resposta da Engenharia</div>`)}
      </div>`;
    }).join('')}`;
}

async function responderRevisaoDesenho(id){
  const campo = document.getElementById(`respostaTexto-${id}`);
  const resposta = campo ? campo.value.trim() : '';
  const { error } = await sb.from('revisoes_desenho').update({
    respondido: true,
    resposta: resposta || null,
    respondido_por_nome: (typeof AUTH !== 'undefined' && AUTH) ? AUTH.nome : null,
    respondido_em: new Date().toISOString(),
  }).eq('id', id);
  if (error){ alert('Erro ao responder: ' + error.message); return; }
  await atualizarCartinha();
}
