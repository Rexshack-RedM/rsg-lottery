const RESOURCE = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'rsg-lottery';

let L = {};
let info = null;
let selected = [];
let countdownTimer = null;
let drawAt = 0;
let buying = false;

const $ = (id) => document.getElementById(id);
const t = (key) => L[key] || '';
const money = (n) => '$' + Number(n || 0).toLocaleString();

function post(name, body) {
    return fetch(`https://${RESOURCE}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body || {}),
    }).then((r) => r.json()).catch(() => null);
}

function el(tag, className, text) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined) node.textContent = text; // textContent: never inject HTML from player names
    return node;
}

function emptyRow(text) {
    return el('div', 'empty', text);
}

/* ---------- open / close ---------- */

function applyLocale() {
    document.querySelectorAll('[data-l]').forEach((node) => {
        const val = L[node.dataset.l];
        if (val) node.textContent = val;
    });
    $('closeBtn').title = t('close');
}

function open(locale) {
    L = locale || {};
    applyLocale();
    selected = [];
    switchTab('buy');
    $('app').classList.remove('hidden');
    loadInfo();
}

function close() {
    $('app').classList.add('hidden');
    clearInterval(countdownTimer);
    post('close');
}

/* ---------- data ---------- */

async function loadInfo() {
    const data = await post('getInfo');
    if (!data || data.numMin === undefined) return;
    info = data;

    $('jackpotAmount').textContent = money(info.jackpot);
    $('priceValue').textContent = money(info.ticketPrice);
    $('pickValue').textContent = `${info.numMin} - ${info.numMax}`;
    $('perDrawValue').textContent = `${info.ticketsLeft} ${t('left')}`;
    $('requiredCount').textContent = info.numbersPerTicket;

    $('infoTicketPrice').textContent = money(info.ticketPrice);
    $('infoPickRange').textContent = `${info.numMin} - ${info.numMax}`;
    $('infoNumbersPerTicket').textContent = info.numbersPerTicket;
    $('infoMaxPerDraw').textContent = info.maxPerDraw;
    $('infoDrawTime').textContent = `${info.drawTime} ${t('daily')}`;

    buildPrizeBreakdown();
    buildGrid();
    startCountdown(info.secondsToDraw);
}

async function loadTickets() {
    const list = $('ticketsList');
    const tickets = await post('getTickets');
    list.replaceChildren();
    if (!Array.isArray(tickets) || tickets.length === 0) {
        list.appendChild(emptyRow(t('noTickets')));
        return;
    }
    tickets.forEach((tk) => {
        const row = el('div', 'card');
        const chips = el('div', 'chips');
        (tk.numbers || []).forEach((n) => chips.appendChild(el('span', 'chip', n)));
        row.append(chips, el('span', 'badge', '#' + tk.ticket));
        list.appendChild(row);
    });
}

async function loadWinners() {
    const list = $('winnersList');
    const winners = await post('getWinners');
    list.replaceChildren();
    if (!Array.isArray(winners) || winners.length === 0) {
        list.appendChild(emptyRow(t('noWinners')));
        return;
    }
    winners.forEach((w) => {
        const row = el('div', 'card');
        const left = el('div', 'card-body');
        const name = el('div', 'card-title', w.winnerName || t('unknown'));
        if (w.winType === 'jackpot') name.appendChild(el('span', 'badge gold', t('jackpotLabel')));
        left.append(
            name,
            el('div', 'card-desc', `${w.date || ''} · ${w.matchCount} ${t('matched')} · ${(w.winningNumbers || []).join(', ')}`)
        );
        row.append(left, el('div', 'card-prize', money(w.prize)));
        list.appendChild(row);
    });
}

function buildPrizeBreakdown() {
    const list = $('prizeBreakdown');
    list.replaceChildren();
    const head = el('div', 'row head');
    head.append(el('span', '', t('numbersMatched')), el('span', '', t('prize')));
    list.appendChild(head);
    (info.prizes || []).forEach((p) => {
        const row = el('div', 'row');
        row.append(el('span', '', p.match), el('b', '', p.prize === 'jackpot' ? t('jackpotLabel') : money(p.prize)));
        list.appendChild(row);
    });
}

/* ---------- number picker ---------- */

function buildGrid() {
    const grid = $('numbersGrid');
    grid.replaceChildren();
    for (let i = info.numMin; i <= info.numMax; i++) {
        const btn = el('button', 'number-btn', i);
        btn.dataset.value = i;
        btn.addEventListener('click', () => toggleNumber(i));
        grid.appendChild(btn);
    }
    refreshPicker();
}

function toggleNumber(n) {
    const idx = selected.indexOf(n);
    if (idx > -1) selected.splice(idx, 1);
    else if (selected.length < info.numbersPerTicket) selected.push(n);
    refreshPicker();
}

function quickPick() {
    if (!info) return;
    const pool = [];
    for (let i = info.numMin; i <= info.numMax; i++) pool.push(i);
    selected = [];
    while (selected.length < info.numbersPerTicket && pool.length) {
        selected.push(pool.splice(Math.floor(Math.random() * pool.length), 1)[0]);
    }
    refreshPicker();
}

function refreshPicker() {
    if (!info) return;
    const full = selected.length >= info.numbersPerTicket;
    document.querySelectorAll('.number-btn').forEach((btn) => {
        const isSel = selected.includes(Number(btn.dataset.value));
        btn.classList.toggle('selected', isSel);
        btn.disabled = !isSel && full;
    });
    $('selectedCount').textContent = selected.length;
    refreshBuyButton();
}

function refreshBuyButton() {
    const btn = $('buyBtn');
    const left = info ? info.ticketsLeft : 0;
    const ready = info && selected.length === info.numbersPerTicket;
    btn.disabled = buying || !ready || left <= 0;
    if (buying) btn.textContent = t('buying');
    else if (left <= 0) btn.textContent = t('noTicketsLeft');
    else if (ready) btn.textContent = t('buyTicketBtn').replace('%s', info.ticketPrice);
    else btn.textContent = t('selectNumbers').replace('%s', info ? info.numbersPerTicket : 0);
}

async function buyTicket() {
    if (buying || !info || selected.length !== info.numbersPerTicket) return;
    buying = true;
    refreshBuyButton();
    const ok = await post('buy', { numbers: selected });
    buying = false;
    if (ok === true) {
        selected = [];
        await loadInfo();
    } else {
        refreshBuyButton();
    }
}

/* ---------- tabs & countdown ---------- */

function switchTab(name) {
    document.querySelectorAll('.tab').forEach((tab) => tab.classList.toggle('active', tab.dataset.tab === name));
    document.querySelectorAll('.tab-content').forEach((sec) => sec.classList.toggle('hidden', sec.id !== 'tab-' + name));
    $('buyBtn').parentElement.classList.toggle('hidden', name !== 'buy');
    if (name === 'tickets') loadTickets();
    else if (name === 'winners') loadWinners();
}

function startCountdown(seconds) {
    clearInterval(countdownTimer);
    drawAt = Date.now() + Math.max(0, seconds) * 1000;
    tick();
    countdownTimer = setInterval(tick, 1000);
}

function tick() {
    const diff = Math.max(0, Math.round((drawAt - Date.now()) / 1000));
    if (diff <= 0) {
        $('drawInValue').textContent = t('drawingNow');
        clearInterval(countdownTimer);
        return;
    }
    const pad = (n) => String(n).padStart(2, '0');
    $('drawInValue').textContent = `${pad(Math.floor(diff / 3600))}:${pad(Math.floor((diff % 3600) / 60))}:${pad(diff % 60)}`;
}

/* ---------- wiring ---------- */

window.addEventListener('message', (e) => {
    const data = e.data || {};
    if (data.type === 'open') open(data.locale);
    else if (data.type === 'close') $('app').classList.add('hidden');
});

document.addEventListener('DOMContentLoaded', () => {
    $('closeBtn').addEventListener('click', close);
    $('buyBtn').addEventListener('click', buyTicket);
    $('quickPickBtn').addEventListener('click', quickPick);
    $('clearBtn').addEventListener('click', () => { selected = []; refreshPicker(); });
    document.querySelectorAll('.tab').forEach((tab) => tab.addEventListener('click', () => switchTab(tab.dataset.tab)));
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && !$('app').classList.contains('hidden')) close();
    });
});
