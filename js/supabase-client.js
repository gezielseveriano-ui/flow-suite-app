// ── Conexão com o Supabase (compartilhada por todas as páginas) ────────────
const SUPABASE_URL = 'https://cmuhdptdkroxslxwinea.supabase.co';
const SUPABASE_KEY = 'sb_publishable_2SElqmz9NJs8Cy2NdaGBag_cVeoz4gx';

const sb = window.supabase.createClient(SUPABASE_URL, SUPABASE_KEY);

// setores válidos (devem bater exatamente com o enum setor_producao do banco)
const SETORES = [
  'ESTRUTURA', 'USINAGEM', 'TAMBOR', 'ROLOS', 'BASES ROLETES',
  'REVESTIMENTO', 'RMF', 'TECMETAL', 'CSM', 'COMERCIAL'
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
