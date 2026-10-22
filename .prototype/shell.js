// shell.js — the right-hand tool window (icon rail + one panel at a time) shared by every Gomin Apps prototype.
// Mirrors ToolWindow.swift in hosts-manager / git-exclude-manager. Identical in ssh-config-manager and
// git-identity-manager (keep in sync until DevFileKit).
//
// App contract — Shell.init({
//   name, icon, version, strings: {en:{}, th:{}},        // app strings override shell strings
//   help: [[titleKey, descKey]…], quick: [questionKey…], intro: key,
//   aiContext() → system prompt, mockReply(q) → string,  // mock when Ollama is offline
//   snapshot() → data, restore(data), render(),          // History + language switch
//   clipboard?: { paste(items) }, suggestions?: () → [{title, sub, add()}]   // optional panels
//   panels?: { clipboard|suggestions|history|inbox: () → html },  // own panel body
//   badge?: panel → number | undefined,
//   rail?: ['clipboard', 'history', 'inbox', 'agent', 'help'],  // own top-rail order (bottom is always the same)
//   left?: ['projects'], leftBottom?: ['providers'], leftDefault?: 'projects',   // a second tool window on the left edge
//   icons?: { generate: '<svg paths>' },              // icons for the app's own panels
// })

const OLLAMA = 'http://localhost:11434';
const ICONS = {
  clipboard: '<rect x="6" y="4" width="12" height="17" rx="2"/><path d="M9 4h6v3H9zM9 11h6M9 15h4"/>',
  suggestions: '<path d="M9 18h6M10 21h4M12 3a6 6 0 0 0-3.5 10.9c.6.5 1 1.2 1 2.1h5c0-.9.4-1.6 1-2.1A6 6 0 0 0 12 3z"/>',
  history: '<path d="M3 12a9 9 0 1 0 3-6.7L3 8"/><path d="M3 3v5h5M12 7v5l3 2"/>',
  projects: '<path d="M3 6h6l2 2h10v11H3z"/><path d="M3 10h18"/>',
  inbox: '<path d="M4 4h16l1 9v6H3v-6z"/><path d="M3 13h5l1.5 3h5l1.5-3h5"/>',
  agent: '<path d="M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8zM19 15l.8 2.2L22 18l-2.2.8L19 21l-.8-2.2L16 18l2.2-.8z"/>',
  help: '<circle cx="12" cy="12" r="9"/><path d="M9.5 9a2.5 2.5 0 1 1 3.5 2.3c-.6.3-1 .9-1 1.6V14M12 17.5v.01"/>',
  appearance: '<path d="M12 3a9 9 0 1 0 0 18c1.1 0 1.5-.8 1.5-1.5 0-.9-.7-1.2-.7-2 0-.8.7-1.5 1.5-1.5H17a4 4 0 0 0 4-4c0-5-4-9-9-9z"/><circle cx="7.5" cy="11" r="1"/><circle cx="10" cy="7" r="1"/><circle cx="15" cy="7" r="1"/>',
  language: '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c2.5 2.6 3.8 5.6 3.8 9s-1.3 6.4-3.8 9c-2.5-2.6-3.8-5.6-3.8-9S9.5 5.6 12 3z"/>',
  about: '<circle cx="12" cy="12" r="9"/><path d="M12 11v6M12 7.5v.01"/>',
};
// Measured palette from swiftui-mac-skills `theming-accent-and-gradients` (all ≈ 0.16 luminance: one value, both modes).
const ACCENTS = { system: '#036ae4', red: '#e00219', orange: '#b45403', amber: '#9a6405', olive: '#7f7002', lime: '#557b04',
  green: '#028132', emerald: '#057f60', teal: '#077d7a', cyan: '#027a8f', blue: '#036ae4', indigo: '#5c55ff', violet: '#8f3dfa',
  purple: '#b424d8', magenta: '#cf01a6', pink: '#db045e', graphite: '#6f6f6f' };
const THEMES = { none: ['', '', 'system'], ocean: ['#007cbe', '#fff7ae', 'blue'], ember: ['#e57a44', '#251351', 'orange'],
  lavender: ['#f1fec6', '#a882dd', 'violet'], watermelon: ['#db5375', '#b3ffb3', 'pink'], lagoon: ['#02c3bd', '#4e148c', 'teal'],
  meadow: ['#629460', '#f4d35e', 'lime'], dusk: ['#414288', '#b0db43', 'indigo'], peach: ['#ffc145', '#ec368d', 'magenta'] };
const LANGS = [['en', '🇺🇸', 'English', 'English'], ['th', '🇹🇭', 'ไทย', 'Thai'], ['ja', '🇯🇵', '日本語', 'Japanese'],
  ['ko', '🇰🇷', '한국어', 'Korean'], ['vi', '🇻🇳', 'Tiếng Việt', 'Vietnamese'], ['id', '🇮🇩', 'Bahasa Indonesia', 'Indonesian'],
  ['ms', '🇲🇾', 'Bahasa Melayu', 'Malay'], ['tl', '🇵🇭', 'Filipino', 'Filipino'], ['zh-Hans', '🇨🇳', '简体中文', 'Simplified Chinese'],
  ['zh-Hant', '🇹🇼', '繁體中文', 'Traditional Chinese'], ['es', '🇪🇸', 'Español', 'Spanish'], ['ru', '🇷🇺', 'Русский', 'Russian']];
// Released apps only (each has a page on gomin2013.github.io); SSH Config / Git Identity Manager join when they ship.
const FAMILY = [['Hosts Manager', 'hosts-manager'], ['Git Exclude Manager', 'git-exclude-manager']];

const SHELL_STRINGS = {
  en: {
    'panel.clipboard': 'Clipboard', 'panel.suggestions': 'Suggestions', 'panel.history': 'History', 'panel.agent': 'AI Agent',
    'panel.help': 'Help', 'panel.appearance': 'Appearance', 'panel.language': 'Language', 'panel.about': 'About', 'panel.inbox': 'AI Inbox', 'panel.projects': 'Recent Projects',
    'shortcut': '{0} ({1})', 'hide': 'Hide', 'cancel': 'Cancel', 'save': 'Save', 'close': 'Close', 'copied': 'Copied: {0}',
    'clip.empty': 'Select rows (⌘-click / ⇧-click) and press ⌘C to collect them here, then switch tab and paste.',
    'clip.pasteAll': 'Paste all', 'clip.clear': 'Clear', 'clip.added': '{0} added to Clipboard',
    'sugg.empty': 'No suggestions right now.',
    'hist.pinned': 'Pinned', 'hist.recent': 'Recent', 'hist.pin': 'Pin Current Version', 'hist.opened': 'When Opened',
    'hist.now': 'Now', 'hist.restore': 'Restore This Version', 'hist.rename': 'Rename…', 'hist.unpin': 'Unpin',
    'hist.remove': 'Remove from History', 'hist.pinDefault': 'Pinned at {0}', 'hist.reverted': 'Restored the {0} version',
    'hist.restored': 'Restored “{0}”', 'hist.revertedOpened': 'Restored the version when opened',
    'ai.try': 'Try asking', 'ai.ask': 'Ask AI…', 'ai.send': 'Send', 'ai.thinking': 'Thinking…',
    'ai.mock': '(MOCK — Ollama is not running, this is a canned answer)', 'ai.offline': 'mock · Ollama offline',
    'ai.settings': 'Provider settings (Apple, Ollama, OpenAI, Gemini, Claude) come with the Swift app.',
    'ap.mode': 'Appearance', 'ap.system': 'System', 'ap.light': 'Light', 'ap.dark': 'Dark', 'ap.accent': 'Accent',
    'ap.theme': 'Gradient theme',
    'lang.search': 'Search languages…', 'lang.note': 'Prototype: English and Thai only. The other 10 come with the Swift app.',
    'about.version': 'Version {0} · static prototype', 'about.family': 'Gomin Apps family', 'about.sponsor': 'Support on GitHub Sponsors',
  },
  th: {
    'panel.clipboard': 'คลิปบอร์ด', 'panel.suggestions': 'คำแนะนำ', 'panel.history': 'ประวัติ', 'panel.agent': 'AI Agent',
    'panel.help': 'วิธีใช้', 'panel.appearance': 'ลักษณะ', 'panel.language': 'ภาษา', 'panel.about': 'เกี่ยวกับ', 'panel.inbox': 'AI Inbox', 'panel.projects': 'โปรเจกต์ล่าสุด',
    'hide': 'ซ่อน', 'cancel': 'ยกเลิก', 'save': 'บันทึก', 'close': 'ปิด', 'copied': 'คัดลอกแล้ว: {0}',
    'clip.empty': 'เลือกแถว (⌘-คลิก / ⇧-คลิก) แล้วกด ⌘C เพื่อเก็บไว้ที่นี่ จากนั้นสลับแท็บแล้ววาง',
    'clip.pasteAll': 'วางทั้งหมด', 'clip.clear': 'ล้าง', 'clip.added': 'เพิ่ม {0} รายการในคลิปบอร์ด',
    'sugg.empty': 'ยังไม่มีคำแนะนำ',
    'hist.pinned': 'ปักหมุด', 'hist.recent': 'ล่าสุด', 'hist.pin': 'ปักหมุดเวอร์ชันปัจจุบัน', 'hist.opened': 'ตอนเปิด',
    'hist.now': 'ตอนนี้', 'hist.restore': 'กลับไปเวอร์ชันนี้', 'hist.rename': 'เปลี่ยนชื่อ…', 'hist.unpin': 'เลิกปักหมุด',
    'hist.remove': 'เอาออกจากประวัติ', 'hist.pinDefault': 'ปักหมุดเมื่อ {0}', 'hist.reverted': 'กลับไปเวอร์ชัน {0}',
    'hist.restored': 'กลับไปที่ “{0}”', 'hist.revertedOpened': 'กลับไปเวอร์ชันตอนเปิด',
    'ai.try': 'ลองถาม', 'ai.ask': 'ถาม AI…', 'ai.send': 'ส่ง', 'ai.thinking': 'กำลังคิด…',
    'ai.mock': '(MOCK: Ollama ไม่ได้เปิด นี่คือคำตอบตัวอย่าง)', 'ai.offline': 'mock · Ollama ไม่ได้เปิด',
    'ai.settings': 'ตั้งค่า provider (Apple, Ollama, OpenAI, Gemini, Claude) มาพร้อมแอป Swift',
    'ap.mode': 'โหมดสี', 'ap.system': 'ตามระบบ', 'ap.light': 'สว่าง', 'ap.dark': 'มืด', 'ap.accent': 'สีหลัก',
    'ap.theme': 'ธีมไล่สี',
    'lang.search': 'ค้นหาภาษา…', 'lang.note': 'Prototype: มีแค่อังกฤษและไทย อีก 10 ภาษามาพร้อมแอป Swift',
    'about.version': 'เวอร์ชัน {0} · static prototype', 'about.family': 'แอปในตระกูล Gomin Apps', 'about.sponsor': 'สนับสนุนผ่าน GitHub Sponsors',
  },
};

const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
const clone = v => JSON.parse(JSON.stringify(v));
/** History time, like Hosts Manager: today → 14:05, older → 22 Oct 14:05. */
const histTime = ms => new Date(ms).toLocaleString(Shell.lang, { hour: '2-digit', minute: '2-digit',
  ...(new Date(ms).toDateString() === new Date().toDateString() ? {} : { day: 'numeric', month: 'short' }) });
// Prefixed with the page title: both prototypes may share one origin (python -m http.server from ~/Documents/SwiftUI).
const load = (k, d) => { try { return JSON.parse(localStorage.getItem(document.title + '.' + k)) ?? d; } catch { return d; } };
const store = (k, v) => { try { localStorage.setItem(document.title + '.' + k, JSON.stringify(v)); } catch { /* private window */ } };
function t(key, ...args) {
  const pick = l => Shell.app?.strings?.[l]?.[key] ?? SHELL_STRINGS[l]?.[key];
  // t('k', a, b) fills {0} {1}; t('k', {n: 3}) fills {n}. Unknown placeholders stay as written.
  return (pick(Shell.lang) ?? pick('en') ?? key).replace(/\{(\w+)\}/g, (m, k) => (typeof args[0] === 'object' ? args[0][k] : args[k]) ?? m);
}
/** Inline code, fenced code, bold — enough for chat replies (MarkdownText.swift in the app). */
const md = s => esc(s).replace(/```[\w-]*\n?([\s\S]*?)```/g, '<pre>$1</pre>')
  .replace(/`([^`\n]+)`/g, '<code>$1</code>').replace(/\*\*([^*\n]+)\*\*/g, '<b>$1</b>');

const Shell = {
  app: null, lang: 'en', panel: null, clip: [], pinned: [], hist: { states: [] },
  models: [], model: null, online: false, chat: [], busy: false,

  init(app) {
    this.app = app;
    this.lang = load('lang', 'en');
    this.leftBottom = app.leftBottom ?? [];
    this.left = [...(app.left ?? []), ...this.leftBottom];
    this.top = (app.rail ?? [...['clipboard', 'suggestions'].filter(p => app[p] || app.panels?.[p]), 'history', 'agent', 'help'])
      .filter(p => !this.left.includes(p));
    this.bottom = ['appearance', 'language', 'about'];
    this.all = [...this.left, ...this.top, ...this.bottom];
    this.panel = load('panel', 'agent');
    if (!this.top.includes(this.panel) && !this.bottom.includes(this.panel)) this.panel = this.top.includes('agent') ? 'agent' : null;
    this.leftPanel = this.left.length ? load('leftPanel', app.leftDefault ?? this.left[0]) : null;
    if (this.leftPanel && !this.left.includes(this.leftPanel)) this.leftPanel = app.leftDefault ?? this.left[0];   // panel moved sides
    if (this.left.length) document.querySelector('.app').insertAdjacentHTML('afterbegin',
      '<nav class="rail rail-left" id="railL" aria-label="Project tool windows"></nav><aside class="panel panel-left" id="panelL" aria-live="polite"></aside>');
    document.querySelector('.app').insertAdjacentHTML('beforeend',
      '<aside class="panel" id="panel" aria-live="polite"></aside><nav class="rail" id="rail" aria-label="Tool windows"></nav>');
    document.addEventListener('keydown', e => {
      if (e.key === 'Escape') this.closeSheet();
      const n = e.altKey && e.metaKey && /^Digit([0-9])$/.exec(e.code);   // ⌥ changes e.key on macOS, so use e.code; 0 = 10th
      const p = n && this.all[(+n[1] || 10) - 1];
      if (p) { e.preventDefault(); this.toggle(p); }
    });
    this.applyAppearance();
    this.resetHistory();
    this.render();
    this.probeOllama();
  },

  render() {
    document.documentElement.lang = this.lang;
    document.querySelectorAll('[data-i18n]').forEach(el => { el.textContent = t(el.dataset.i18n); });
    document.querySelectorAll('[data-i18n-ph]').forEach(el => { el.placeholder = t(el.dataset.i18nPh); });
    document.querySelectorAll('[data-i18n-title]').forEach(el => { el.title = t(el.dataset.i18nTitle); });
    this.app.render();
    this.renderRail();
    this.renderPanel();
  },

  toggle(p) {
    if (this.left.includes(p)) { this.leftPanel = this.leftPanel === p ? null : p; store('leftPanel', this.leftPanel); }
    else { this.panel = this.panel === p ? null : p; store('panel', this.panel); }
    this.renderRail(); this.renderPanel();
  },

  renderRail() {
    const btn = p => {
      const i = this.all.indexOf(p), n = (i + 1) % 10;   // 10th tool window = ⌥⌘0; the 11th on has no shortcut
      const count = this.app.badge?.(p) ?? (p === 'clipboard' ? this.clip.length : p === 'suggestions' ? this.app.suggestions?.().length : 0);
      const on = p === this.panel || p === this.leftPanel;
      return `<button class="${on ? 'on' : ''}" onclick="Shell.toggle('${p}')" title="${esc(i < 10 ? t('shortcut', t('panel.' + p), '⌥⌘' + n) : t('panel.' + p))}"
        aria-label="${esc(t('panel.' + p))}" aria-pressed="${on}"><svg viewBox="0 0 24 24">${this.app.icons?.[p] ?? ICONS[p]}</svg>
        ${count ? `<span class="badge">${count}</span>` : ''}</button>`;
    };
    document.getElementById('rail').innerHTML =
      this.top.map(btn).join('') + '<div class="spacer"></div>' + this.bottom.map(btn).join('');
    if (this.left.length) document.getElementById('railL').innerHTML =
      this.left.filter(p => !this.leftBottom.includes(p)).map(btn).join('') + '<div class="spacer"></div>' + this.leftBottom.map(btn).join('');
  },

  renderPanel() {
    this.paint('panel', this.panel);
    if (this.left.length) this.paint('panelL', this.leftPanel);
  },
  paint(id, p) {
    const el = document.getElementById(id);
    el.classList.toggle('closed', !p);
    if (!p) return;
    const pin = p === 'history' ? `<button class="icon-btn" onclick="Shell.pin()" title="${esc(t('hist.pin'))}" aria-label="${esc(t('hist.pin'))}">📌</button>` : '';
    el.innerHTML = `<div class="panel-h"><span>${esc(t('panel.' + p))}</span><span>${pin}
      <button class="icon-btn" onclick="Shell.toggle('${p}')" title="${esc(t('hide'))}" aria-label="${esc(t('hide'))}">–</button></span></div>
      <div class="panel-b">${this.app.panels?.[p]?.() ?? this['panel_' + p]()}</div>`;
    const log = el.querySelector('.chat-log');
    if (log) log.scrollTop = log.scrollHeight;
  },

  // MARK: Clipboard (optional)
  clipAdd(items) {
    for (const it of items) if (!this.clip.some(c => c.label === it.label)) this.clip.push(it);
    this.toast(t('clip.added', items.length));
    this.renderRail(); this.renderPanel();
  },
  panel_clipboard() {
    if (!this.clip.length) return `<p class="muted">${esc(t('clip.empty'))}</p>`;
    return `<div class="toolbar"><button class="btn small primary" onclick="Shell.clipPaste()">${esc(t('clip.pasteAll'))}</button>
      <button class="btn small" onclick="Shell.clip=[];Shell.renderRail();Shell.renderPanel()">${esc(t('clip.clear'))}</button></div>` +
      this.clip.map((c, i) => `<div class="prow"><div class="grow" onclick="Shell.clipPaste(${i})"><div class="mono">${esc(c.label)}</div>
        <div class="sub">${esc(c.sub || '')}</div></div>
        <button class="icon-btn" onclick="Shell.clip.splice(${i},1);Shell.renderRail();Shell.renderPanel()" aria-label="Remove">×</button></div>`).join('');
  },
  clipPaste(i) { this.app.clipboard.paste(i == null ? this.clip : [this.clip[i]]); },

  // MARK: Suggestions (optional)
  panel_suggestions() {
    this._sugg = this.app.suggestions();
    if (!this._sugg.length) return `<p class="muted">${esc(t('sugg.empty'))}</p>`;
    return this._sugg.map((s, i) => `<div class="prow"><div class="grow"><div class="mono">${esc(s.title)}</div>
      <div class="sub">${esc(s.sub)}</div></div><button class="btn small" onclick="Shell._sugg[${i}].add();Shell.render()">＋</button></div>`).join('');
  },

  // MARK: History — same as Hosts Manager (HistoryPanel.swift, building-edit-history): Pinned = your pins, newest
  // first, then "When Opened"; Recent = the last 30 steps, newest first, the top one is "Now". Going back is a new
  // step too, so nothing is lost. Double-click a row or press ↩ to go back.
  /** A fresh History: one step "When Opened", also pinned. Apps with several documents call it per document. */
  resetHistory() {
    this.hist = { states: [] }; this.pinned = [];
    this.record(t('hist.opened'));
    this.pinned.push({ ...clone(this.hist.states[0]), opened: true });
  },
  record(label) {
    const h = this.hist;
    h.states.push({ label, snap: clone(this.app.snapshot()), at: Date.now() });
    if (h.states.length > 30) h.states.shift();
    if (this.panel === 'history' || this.leftPanel === 'history') this.renderPanel();
  },
  restoreTo(s, label) { this.app.restore(clone(s.snap)); this.record(label); this.render(); },
  restoreStep(i) { const s = this.hist.states[i]; this.restoreTo(s, t('hist.reverted', histTime(s.at))); },
  restorePinned(i) { const s = this.pinned[i]; this.restoreTo(s, s.opened ? t('hist.revertedOpened') : t('hist.restored', s.label)); },
  removeStep(i) { this.hist.states.splice(i, 1); this.renderPanel(); },
  pin() { this.pinned.unshift({ label: t('hist.pinDefault', histTime(Date.now())), snap: clone(this.app.snapshot()), at: Date.now() }); this.renderPanel(); },
  renamePin(i) { const n = prompt(t('hist.rename'), this.pinned[i].label)?.trim(); if (n) { this.pinned[i].label = n; this.renderPanel(); } },
  unpin(i) { this.pinned.splice(i, 1); this.renderPanel(); },
  panel_history() {
    const now = JSON.stringify(this.app.snapshot()), last = this.hist.states.length - 1;
    const btn = (fn, ico, tip) => `<button class="icon-btn" onclick="event.stopPropagation();${fn}" title="${esc(t(tip))}" aria-label="${esc(t(tip))}">${ico}</button>`;
    // Current row: bold, tinted icon, "Now" instead of ↩ (pins keep Rename / Unpin)
    const row = (s, cur, icon, back, extra = '') => `<div class="prow hrow ${cur ? 'cur' : ''}" ${cur ? '' : `ondblclick="${back}"`}>
      <span class="hico">${icon}</span><div class="grow">${esc(s.label)}<div class="sub">${histTime(s.at)}</div></div>
      ${cur ? `<span class="now">${esc(t('hist.now'))}</span>` : btn(back, '↩', 'hist.restore')}${extra}</div>`;
    return `<h3>${esc(t('hist.pinned'))}</h3>` +
      this.pinned.map((s, i) => row(s, JSON.stringify(s.snap) === now, s.opened ? '📄' : '📌', `Shell.restorePinned(${i})`,
        s.opened ? '' : btn(`Shell.renamePin(${i})`, '✎', 'hist.rename') + btn(`Shell.unpin(${i})`, '✕', 'hist.unpin'))).join('') +
      `<h3>${esc(t('hist.recent'))}</h3>` +
      this.hist.states.map((s, i) => [s, i]).reverse().map(([s, i]) => i === last ? row(s, true, '◉', '')
        : row(s, false, '○', `Shell.restoreStep(${i})`, btn(`Shell.removeStep(${i})`, '🗑', 'hist.remove'))).join('');
  },

  // MARK: AI Agent — real Ollama when running, canned answers otherwise
  async probeOllama() {
    try {
      const j = await (await fetch(OLLAMA + '/api/tags')).json();
      this.models = j.models.map(m => m.name);
      this.model = this.models.includes(load('model')) ? load('model') : this.models.find(m => m.startsWith('qwen3.8')) || this.models[0];
      this.online = !!this.model;
    } catch { this.online = false; }
    this.renderPanel();   // any open panel may show Ollama's status (AI Agent, a providers list…)
  },
  /** One chat call. `format` = JSON schema for structured answers. Returns null when offline or on error. */
  async ai(messages, format) {
    if (!this.online) return null;
    try {
      const r = await fetch(OLLAMA + '/api/chat', { method: 'POST', body: JSON.stringify(
        { model: this.model, messages, stream: false, think: false, ...(format ? { format } : {}) }) });
      return (await r.json()).message?.content ?? null;
    } catch { return null; }
  },
  async ask(q) {
    q = q.trim();
    if (!q || this.busy) return;
    this.chat.push({ role: 'user', content: q }); this.busy = true; this.renderPanel();
    const a = await this.ai([{ role: 'system', content: this.app.aiContext() }, ...this.chat.slice(-8)]);
    this.chat.push({ role: 'assistant', content: a ?? t('ai.mock') + '\n\n' + this.app.mockReply(q) });
    this.busy = false; this.renderPanel();
  },
  panel_agent() {
    const models = this.online
      ? `<select onchange="Shell.model=this.value;store('model',this.value)" aria-label="Model">${this.models.map(m =>
        `<option ${m === this.model ? 'selected' : ''}>${esc(m)}</option>`).join('')}</select>`
      : `<span class="muted"><span class="dot"></span>${esc(t('ai.offline'))}</span>`;
    const intro = `<div class="chat-intro"><h2>✦ ${esc(t('panel.agent'))}</h2><p class="muted">${esc(t(this.app.intro))}</p>
      <h3>${esc(t('ai.try'))}</h3>${this.app.quick.map((k, i) => `<div class="prow" onclick="Shell.ask(t(Shell.app.quick[${i}]))">
      <div class="grow">${esc(t(k))}</div><span class="muted">›</span></div>`).join('')}</div>`;
    const log = this.chat.map(m => `<div class="msg ${m.role === 'user' ? 'user' : 'ai'}">${md(m.content)}</div>`).join('') +
      (this.busy ? `<div class="msg ai muted">${esc(t('ai.thinking'))}</div>` : '');
    return `<div class="chat"><div class="chat-top">${this.online ? '<span class="dot on"></span>' : ''}${models}
      <button class="icon-btn" onclick="Shell.toast(t('ai.settings'))" aria-label="AI settings">⚙︎</button></div>
      <div class="chat-log">${this.chat.length ? log : intro}</div>
      <form class="chat-in" onsubmit="event.preventDefault();Shell.ask(this.q.value)"><input name="q" placeholder="${esc(t('ai.ask'))}"
        aria-label="${esc(t('ai.ask'))}"><button class="btn primary small" ${this.busy ? 'disabled' : ''}>${esc(t('ai.send'))}</button></form></div>`;
  },

  // MARK: Help
  panel_help() {
    return this.app.help.map(([title, desc]) => `<div style="margin-bottom:12px"><b>${esc(t(title))}</b>
      <div class="muted">${esc(t(desc))}</div></div>`).join('');
  },

  // MARK: Appearance / Language / About
  applyAppearance() {
    const mode = load('mode', 'system'), theme = THEMES[load('theme', 'none')] || THEMES.none;
    if (mode === 'system') delete document.documentElement.dataset.theme; else document.documentElement.dataset.theme = mode;
    const s = document.documentElement.style;
    s.setProperty('--accent', ACCENTS[load('accent', 'system')] || ACCENTS.system);
    s.setProperty('--amb1', theme[0] ? theme[0] + '40' : 'transparent');
    s.setProperty('--amb2', theme[1] ? theme[1] + '40' : 'transparent');
  },
  setLook(key, value) {
    store(key, value);
    if (key === 'theme') store('accent', THEMES[value][2]);   // a theme sets its paired solid accent
    this.applyAppearance(); this.renderPanel();
  },
  panel_appearance() {
    const mode = load('mode', 'system'), accent = load('accent', 'system'), theme = load('theme', 'none');
    return `<h3>${esc(t('ap.mode'))}</h3><div class="seg">${['system', 'light', 'dark'].map(m =>
      `<button class="${m === mode ? 'on' : ''}" onclick="Shell.setLook('mode','${m}')">${esc(t('ap.' + m))}</button>`).join('')}</div>
      <h3>${esc(t('ap.accent'))}</h3><div class="swatches">${Object.entries(ACCENTS).map(([k, c]) =>
      `<button class="${k === accent ? 'on' : ''}" style="background:${c}" title="${k}" aria-label="${k}" onclick="Shell.setLook('accent','${k}')"></button>`).join('')}</div>
      <h3>${esc(t('ap.theme'))}</h3><div class="themes">${Object.entries(THEMES).map(([k, [a, b]]) =>
      `<button class="${k === theme ? 'on' : ''}" style="background:${a ? `linear-gradient(135deg,${a},${b})` : 'var(--bg3)'};${a ? '' : 'color:var(--text)'}"
        onclick="Shell.setLook('theme','${k}')">${k}</button>`).join('')}</div>`;
  },
  panel_language() {
    return `<div class="search"><input placeholder="${esc(t('lang.search'))}" oninput="Shell.filterLang(this.value)" aria-label="${esc(t('lang.search'))}"></div>
      <div id="langs" style="margin-top:8px">${LANGS.map(([code, flag, native, en]) => `<div class="prow" data-q="${esc((native + ' ' + en + ' ' + code).toLowerCase())}"
        onclick="Shell.lang='${code}';store('lang','${code}');Shell.render()"><span>${flag}</span><div class="grow">${esc(native)}<div class="sub">${en}</div></div>
        ${code === this.lang ? '✓' : ''}</div>`).join('')}</div><p class="muted">${esc(t('lang.note'))}</p>`;
  },
  filterLang(q) { document.querySelectorAll('#langs .prow').forEach(r => r.classList.toggle('hidden', !r.dataset.q.includes(q.toLowerCase()))); },
  panel_about() {
    const a = this.app;
    return `<div style="text-align:center;padding:10px 0"><div style="width:72px;height:72px;margin:auto;border-radius:16px;display:grid;place-items:center;
      font-size:36px;background:linear-gradient(135deg,var(--accent),#1d1d1f)">${a.icon}</div><h2 style="margin:10px 0 2px">${esc(a.name)}</h2>
      <div class="muted">${esc(t('about.version', a.version))}</div><p>${esc(t('about.desc'))}</p></div>
      <h3>${esc(t('about.family'))}</h3>${FAMILY.filter(([n]) => n !== a.name).map(([n, slug]) =>
      `<div class="prow" onclick="window.open('https://gomin2013.github.io/${slug}/')"><div class="grow">${n}</div><span class="muted">↗</span></div>`).join('')}
      <p><a href="https://github.com/sponsors/gomin2013" target="_blank" rel="noopener">${esc(t('about.sponsor'))}</a></p>`;
  },

  // MARK: Sheet + toast + copy
  sheet(html) {
    this.closeSheet();
    document.body.insertAdjacentHTML('beforeend', `<div class="scrim" id="scrim" role="dialog" aria-modal="true"><div class="sheet">${html}</div></div>`);
    const scrim = document.getElementById('scrim');
    scrim.addEventListener('mousedown', e => { if (e.target === scrim) this.closeSheet(); });
    scrim.querySelector('input, select, textarea, button')?.focus();
    return scrim.querySelector('.sheet');
  },
  closeSheet() { document.getElementById('scrim')?.remove(); },
  /** `action` = [label, fn], e.g. [t('undo'), restore]. */
  toast(msg, action) {
    document.querySelector('.toast')?.remove();
    document.body.insertAdjacentHTML('beforeend', `<div class="toast" role="status">${esc(msg)}${action ? `<button>${esc(action[0])}</button>` : ''}</div>`);
    const el = document.querySelector('.toast');
    if (action) el.querySelector('button').onclick = () => { el.remove(); action[1](); };
    setTimeout(() => el.remove(), action ? 5000 : 2600);
  },
  async copy(text) {
    try { await navigator.clipboard.writeText(text); } catch { /* file:// without focus — still show what would be copied */ }
    this.toast(t('copied', text.length > 60 ? text.slice(0, 57) + '…' : text));
  },
};
