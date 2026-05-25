const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'ptv_cityhall';

const state = {
    open: false,
    activeView: 'market',
    activeCategory: null,
    activeOfficeView: 'management',
    activeItemTaxCategory: null,
    data: null
};

const app = document.getElementById('app');
const mainTabs = document.getElementById('mainTabs');
const tabs = document.getElementById('tabs');
const items = document.getElementById('items');
const message = document.getElementById('message');
const managerPanel = document.getElementById('managerPanel');
const taxInputs = document.getElementById('taxInputs');
const interaction = document.getElementById('interaction');
const interactionKey = document.getElementById('interactionKey');
const interactionEyebrow = document.getElementById('interactionEyebrow');
const interactionTitle = document.getElementById('interactionTitle');
const interactionMessage = document.getElementById('interactionMessage');
const interactionAction = document.getElementById('interactionAction');

function money(value) {
    return `$${Number(value || 0).toFixed(2)}`;
}

function escapeHtml(value) {
    return String(value === undefined || value === null ? '' : value)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
}

function secondsText(seconds) {
    seconds = Number(seconds || 0);
    if (seconds <= 0) return 'jetzt';

    const days = Math.floor(seconds / 86400);
    if (days > 0) {
        const hours = Math.floor((seconds % 86400) / 3600);
        return `${days}d ${hours}h`;
    }

    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    if (hours > 0) return `${hours}h ${minutes}m`;
    return `${minutes}m`;
}

function citizenshipText(status) {
    if (status === 'active') return 'bestaetigter Bürger';
    if (status === 'pending') return 'Antrag offen';
    if (status === 'removed') return 'ausgetragen';
    return 'nicht eingetragen';
}

function electionText(phase) {
    if (phase === 'nomination') return 'Kandidaturphase';
    if (phase === 'voting') return 'Abstimmung';
    if (phase === 'finished') return 'Wahl beendet';
    return 'Keine aktive Wahl';
}

function isEnabled(value) {
    return !(value === false || value === 0 || value === '0' || value === 'false');
}

function post(name, data = {}) {
    return fetch(`https://${resource}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    }).then((response) => response.json());
}

function runAction(name, data = {}) {
    return post(name, data)
        .then((result) => {
            setMessage(result.message || '');
            if (result && result.data && result.data.ok) {
                setData(result.data);
            }
            return result;
        })
        .catch(() => {
            setMessage('Aktion konnte nicht ausgefuehrt werden.');
        });
}

function setMessage(text) {
    message.textContent = text || '';
}

function showInteraction(data = {}) {
    interactionKey.textContent = data.keyLabel || 'G';
    interactionEyebrow.textContent = data.eyebrow || 'Interaktion';
    interactionTitle.textContent = data.title || 'Markthalle';
    interactionMessage.textContent = data.message || 'Bürger, Wahlen und Marktverwaltung';
    interactionAction.textContent = data.actionLabel || 'Druecke G zum Oeffnen';
    interaction.classList.add('is-open');
    interaction.setAttribute('aria-hidden', 'false');
}

function hideInteraction() {
    interaction.classList.remove('is-open');
    interaction.setAttribute('aria-hidden', 'true');
}

function categoryTax(data, categoryKey) {
    const town = data && data.town ? data.town : {};
    const taxes = (data && data.categoryTaxes && data.categoryTaxes[categoryKey]) || {};
    return {
        buyRate: Number(taxes.buyRate !== undefined ? taxes.buyRate : (town.taxBuyRate !== undefined ? town.taxBuyRate : (town.taxRate || 0))),
        sellRate: Number(taxes.sellRate !== undefined ? taxes.sellRate : (town.taxSellRate !== undefined ? town.taxSellRate : (town.taxRate || 0)))
    };
}

function taxSummary(data, categoryKey) {
    const tax = categoryTax(data, categoryKey);
    return `E ${tax.buyRate.toFixed(2)}% / V ${tax.sellRate.toFixed(2)}%`;
}

function availableViews(data) {
    const views = [
        { key: 'market', label: 'Markt' },
        { key: 'citizens', label: 'Bürger' },
        { key: 'elections', label: 'Wahlen' }
    ];

    if (data.player && data.player.canUseOffice) {
        views.push({ key: 'office', label: 'Verwaltung' });
    }

    return views;
}

function availableOfficeViews() {
    return [
        { key: 'management', label: 'Verwaltung' },
        { key: 'citizens', label: 'Bürger' },
        { key: 'exports', label: 'Exports' },
        { key: 'logs', label: 'Logs' }
    ];
}

function setData(data) {
    state.data = data;

    const firstCategory = data.categories && data.categories[0] ? data.categories[0].key : null;
    const categoryExists = (data.categories || []).some((category) => category.key === state.activeCategory);
    if (!categoryExists) {
        state.activeCategory = firstCategory;
    }

    const itemTaxCategoryExists = (data.categories || []).some((category) => category.key === state.activeItemTaxCategory);
    if (!itemTaxCategoryExists) {
        state.activeItemTaxCategory = firstCategory;
    }

    const viewExists = availableViews(data).some((view) => view.key === state.activeView);
    if (!viewExists) {
        state.activeView = 'market';
    }

    const officeViewExists = availableOfficeViews().some((view) => view.key === state.activeOfficeView);
    if (!officeViewExists) {
        state.activeOfficeView = 'management';
    }

    render();
}

function render() {
    const data = state.data;
    if (!data) return;

    document.getElementById('townName').textContent = data.town.name;
    document.getElementById('windowTitle').textContent = data.mode === 'admin'
        ? (state.activeView === 'market' ? 'Markthalle Verwaltung' : 'Rathaus Verwaltung')
        : 'Markthalle';
    document.getElementById('goodsTaxRate').textContent = taxSummary(data, 'goods');
    document.getElementById('weaponsTaxRate').textContent = taxSummary(data, 'weapons');
    document.getElementById('treasury').textContent = money(data.town.treasury);
    document.getElementById('itemCount').textContent = data.items.filter((item) => isEnabled(item.enabled)).length;

    if (data.mode === 'admin') {
        renderTaxInputs(data);
    }

    renderMainTabs(data);

    managerPanel.classList.toggle('hidden', data.mode !== 'admin' || state.activeView !== 'market');
    tabs.classList.toggle('hidden', state.activeView !== 'market');
    items.innerHTML = '';

    if (state.activeView === 'market') {
        renderMarket(data);
    } else if (state.activeView === 'citizens') {
        renderCitizenPanel(data);
    } else if (state.activeView === 'elections') {
        renderElectionPanel(data);
    } else if (state.activeView === 'office') {
        renderOfficePanel(data);
    }
}

function renderTaxInputs(data) {
    taxInputs.innerHTML = '';

    (data.categories || []).forEach((category) => {
        const tax = categoryTax(data, category.key);
        const row = document.createElement('div');
        row.className = 'tax-editor';
        row.dataset.category = category.key;
        row.innerHTML = `
            <span>${escapeHtml(category.label)}</span>
            <label>Einkauf <input data-tax="buy" type="number" min="5" step="0.01" value="${tax.buyRate.toFixed(2)}"></label>
            <label>Verkauf <input data-tax="sell" type="number" min="6" step="0.01" value="${tax.sellRate.toFixed(2)}"></label>
        `;
        taxInputs.appendChild(row);
    });
}

function renderMainTabs(data) {
    mainTabs.innerHTML = '';
    availableViews(data).forEach((view) => {
        const button = document.createElement('button');
        button.className = `tab${view.key === state.activeView ? ' active' : ''}`;
        button.type = 'button';
        button.textContent = view.label;
        button.addEventListener('click', () => {
            state.activeView = view.key;
            render();
        });
        mainTabs.appendChild(button);
    });
}

function renderMarket(data) {
    tabs.innerHTML = '';
    data.categories.forEach((category) => {
        const button = document.createElement('button');
        button.className = `tab${category.key === state.activeCategory ? ' active' : ''}`;
        button.type = 'button';
        button.textContent = category.label;
        button.addEventListener('click', () => {
            state.activeCategory = category.key;
            render();
        });
        tabs.appendChild(button);
    });

    const visibleItems = data.items.filter((item) => {
        if (item.category !== state.activeCategory) return false;
        return isEnabled(item.enabled);
    });
    if (visibleItems.length === 0) {
        items.appendChild(emptyRow('Keine Waren in diesem Reiter', 'Pruefe Config.Market.Categories und ob die Resource neu gestartet wurde.'));
        return;
    }

    visibleItems.forEach((item) => items.appendChild(renderItem(item, data)));
}

function renderItem(item, data) {
    const row = document.createElement('article');
    row.className = 'item-row';

    const tax = categoryTax(data, item.category);
    const buyTaxRate = Number(item.taxBuyRate !== undefined ? item.taxBuyRate : tax.buyRate);
    const sellTaxRate = Number(item.taxSellRate !== undefined ? item.taxSellRate : tax.sellRate);
    const buyTax = Number(item.buyPrice || 0) * (buyTaxRate / 100);
    const sellTax = Number(item.sellPrice || 0) * (sellTaxRate / 100);
    const canEditPrices = data.mode === 'admin' && data.player.canManage && !(data.market && data.market.useConfigPrices);

    row.innerHTML = `
        <div>
            <div class="item-title">${escapeHtml(item.itemLabel)}</div>
            <span class="item-meta">${escapeHtml(item.categoryLabel)}${isEnabled(item.enabled) ? '' : ' | deaktiviert'}</span>
        </div>
        <div><span class="item-meta">Bestand</span><strong>${Number(item.stock || 0)}</strong></div>
        <div><span class="item-meta">Dein Bestand</span><strong>${Number(item.playerCount || 0)}</strong></div>
        <div><span class="item-meta">Einkauf</span><strong>${money(item.buyPrice)}</strong><small>Steuer ${buyTaxRate.toFixed(2)}%: ${money(buyTax)}</small></div>
        <div><span class="item-meta">Verkauf</span><strong>${money(item.sellPrice)}</strong><small>Steuer ${sellTaxRate.toFixed(2)}%: ${money(sellTax)}</small></div>
    `;

    if (canEditPrices) {
        const admin = document.createElement('div');
        admin.className = 'price-admin';
        admin.innerHTML = `
            <input type="number" step="0.01" value="${Number(item.buyPrice || 0).toFixed(2)}" aria-label="Einkaufspreis">
            <input type="number" step="0.01" value="${Number(item.sellPrice || 0).toFixed(2)}" aria-label="Verkaufspreis">
            <button type="button">Preis</button>
        `;
        admin.querySelector('button').addEventListener('click', () => {
            const inputs = admin.querySelectorAll('input');
            doSetPrice(item, inputs[0].value, inputs[1].value);
        });
        row.appendChild(admin);
    } else if (data.mode !== 'admin') {
        const amount = document.createElement('div');
        amount.innerHTML = `
            <span class="item-meta">Menge</span>
            <input type="number" min="1" step="1" value="1">
        `;
        row.appendChild(amount);

        const amountInput = amount.querySelector('input');
        const actions = document.createElement('div');
        actions.className = 'item-actions';
        actions.innerHTML = `
            <button type="button" data-action="buy">Einkauf</button>
            <button type="button" data-action="sell">Verkauf</button>
        `;
        actions.querySelector('[data-action="buy"]').addEventListener('click', () => doTrade('buy', item, amountInput));
        actions.querySelector('[data-action="sell"]').addEventListener('click', () => doTrade('sell', item, amountInput));
        row.appendChild(actions);
    }

    return row;
}

function renderCitizenPanel(data) {
    const player = data.player || {};
    const counts = (data.town && data.town.citizens) || { active: 0, pending: 0 };

    items.appendChild(panelRow(
        'Bürgerstatus',
        `Du bist aktuell: ${citizenshipText(player.citizenship)}. Bestaetigte Bürger: ${counts.active || 0}, offene Antraege: ${counts.pending || 0}.`
    ));

    const citizenCooldown = Number(player.citizenshipCooldownRemaining || 0);
    if (player.citizenship !== 'active' && player.citizenship !== 'pending' && citizenCooldown > 0) {
        items.appendChild(panelRow(
            'Buerger-Cooldown',
            `Naechster Buergerantrag moeglich in ${secondsText(citizenCooldown)}.`
        ));
    } else if (player.citizenship !== 'active' && player.citizenship !== 'pending') {
        items.appendChild(panelRow(
            'Eintragung beantragen',
            `Bürgerschaft fuer ${data.town.name} einreichen.`,
            [actionButton('Als Bürger eintragen', () => runAction('applyCitizenship'))]
        ));
    } else if (player.citizenship === 'pending') {
        items.appendChild(panelRow('Bürgerantrag offen', 'Dein Antrag wartet auf Bestaetigung durch den Bürgermeister.'));
    }

    if (Number(player.pendingPayout || 0) > 0) {
        items.appendChild(panelRow(
            'Auszahlungen',
            `Offen: ${money(player.pendingPayout)}.`,
            [actionButton('Abholen', () => runAction('claimPayouts'))]
        ));
    }

    if (Number(player.pendingItemReturns || 0) > 0) {
        items.appendChild(panelRow(
            'Warenrueckgaben',
            `Offen: ${Number(player.pendingItemReturns || 0)} Items.`,
            [actionButton('Abholen', () => runAction('claimItemReturns'))]
        ));
    }
}

function renderElectionPanel(data) {
    const election = data.election || { phase: 'none', remaining: 0, candidates: [] };
    const phase = election.phase || 'none';

    items.appendChild(panelRow(
        'Wahlstatus',
        `${electionText(phase)}${phase !== 'none' ? `, Restzeit ${secondsText(election.remaining)}` : ''}.`
    ));

    if (data.player && data.player.isAdmin && phase === 'none') {
        const row = document.createElement('article');
        row.className = 'panel-row grant-panel';
        row.innerHTML = `
            <div>
                <div class="item-title">Wahl starten</div>
                <span class="item-meta">Admin-Aktion</span>
            </div>
            <input type="number" min="1" step="1" value="24" placeholder="Kandidatur h">
            <input type="number" min="1" step="1" value="24" placeholder="Abstimmung h">
            <span></span>
            <button type="button">Starten</button>
        `;
        row.querySelector('button').addEventListener('click', () => {
            const inputs = row.querySelectorAll('input');
            runAction('startElection', {
                nominationHours: inputs[0].value,
                votingHours: inputs[1].value
            });
        });
        items.appendChild(row);
    }

    if (data.player && data.player.isAdmin && phase !== 'none') {
        items.appendChild(panelRow(
            'Wahl beenden',
            'Admin-Aktion: aktive Wahl sofort auswerten.',
            [actionButton('Beenden', () => runAction('endElection'))]
        ));
    }

    if (phase === 'nomination') {
        const row = document.createElement('article');
        row.className = 'panel-row form-panel';
        row.innerHTML = `
            <div>
                <div class="item-title">Kandidatur einreichen</div>
                <span class="item-meta">Wahlprogramm bis 240 Zeichen</span>
            </div>
            <textarea id="manifestoInput" maxlength="240" placeholder="Wahlprogramm"></textarea>
            <button type="button">Einreichen</button>
        `;
        row.querySelector('button').addEventListener('click', () => {
            runAction('registerCandidate', { manifesto: row.querySelector('textarea').value });
        });
        items.appendChild(row);
    }

    const candidates = election.candidates || [];
    if (candidates.length === 0) {
        items.appendChild(emptyRow('Keine Kandidaten', phase === 'none' ? 'Aktuell laeuft keine Wahl.' : 'Noch wurde keine Kandidatur eingereicht.'));
        return;
    }

    candidates.forEach((candidate) => {
        const buttons = [];
        if (phase === 'voting') {
            buttons.push(actionButton('Abstimmen', () => runAction('castVote', { candidateId: candidate.id })));
        }

        items.appendChild(panelRow(
            candidate.name,
            `Stimmen: ${Number(candidate.votes || 0)} | ${candidate.manifesto || ''}`,
            buttons
        ));
    });
}

function renderOfficePanel(data) {
    const player = data.player || {};
    if (!player.canUseOffice) {
        items.appendChild(emptyRow('Keine Berechtigung', 'Nur Bürgermeister und Admins koennen die Verwaltung oeffnen.'));
        return;
    }

    const office = data.office || { citizens: [], counts: {}, ledger: [] };
    const counts = office.counts || {};

    items.appendChild(panelRow(
        'Bürgermeisterverwaltung',
        `Bürgermeister: ${data.town.mayorName || 'nicht besetzt'} | Stadtkasse: ${money(data.town.treasury)} | Bürger: ${counts.active || 0} aktiv, ${counts.pending || 0} offen.`
    ));

    renderOfficeTabs();

    if (state.activeOfficeView === 'management') {
        renderAnnouncementForm();
        renderGrantForm();
        renderItemTaxEditor(data);
    } else if (state.activeOfficeView === 'citizens') {
        renderCitizenRegistry(office.citizens || []);
    } else if (state.activeOfficeView === 'exports') {
        renderMarketStorage(data);
    } else if (state.activeOfficeView === 'logs') {
        renderLedger(office.ledger || []);
    }
}

function renderOfficeTabs() {
    const nav = document.createElement('nav');
    nav.className = 'office-tabs';

    availableOfficeViews().forEach((view) => {
        const button = document.createElement('button');
        button.className = `tab${view.key === state.activeOfficeView ? ' active' : ''}`;
        button.type = 'button';
        button.textContent = view.label;
        button.addEventListener('click', () => {
            state.activeOfficeView = view.key;
            render();
        });
        nav.appendChild(button);
    });

    items.appendChild(nav);
}

function renderAnnouncementForm() {
    const row = document.createElement('article');
    row.className = 'panel-row form-panel';
    row.innerHTML = `
        <div>
            <div class="item-title">Bekanntmachung</div>
            <span class="item-meta">Nachricht an alle Spieler</span>
        </div>
        <input type="text" maxlength="180" placeholder="Text">
        <button type="button">Senden</button>
    `;
    row.querySelector('button').addEventListener('click', () => {
        runAction('mayorAnnouncement', { message: row.querySelector('input').value });
    });
    items.appendChild(row);
}

function renderGrantForm() {
    const row = document.createElement('article');
    row.className = 'panel-row grant-panel';
    row.innerHTML = `
        <div>
            <div class="item-title">Auszahlung</div>
            <span class="item-meta">Aus Stadtkasse an Online-Spieler</span>
        </div>
        <input type="number" min="1" step="1" placeholder="Server-ID">
        <input type="number" min="0.01" step="0.01" placeholder="Betrag">
        <input type="text" maxlength="120" placeholder="Grund">
        <button type="button">Auszahlen</button>
    `;
    row.querySelector('button').addEventListener('click', () => {
        const inputs = row.querySelectorAll('input');
        runAction('treasuryGrant', {
            targetId: inputs[0].value,
            amount: inputs[1].value,
            reason: inputs[2].value
        });
    });
    items.appendChild(row);
}

function renderItemTaxEditor(data) {
    items.appendChild(sectionTitle('Artikelsteuern'));

    const stockItems = (data.items || []).slice();

    if (stockItems.length === 0) {
        items.appendChild(emptyRow('Keine Artikel', 'Keine Waren oder Waffen in der Config gefunden.'));
        return;
    }

    const categories = (data.categories || []).filter((category) => {
        return stockItems.some((item) => item.category === category.key);
    });

    if (categories.length === 0) {
        items.appendChild(emptyRow('Keine Reiter', 'Keine Waren- oder Waffenreiter in der Config gefunden.'));
        return;
    }

    if (!categories.some((category) => category.key === state.activeItemTaxCategory)) {
        state.activeItemTaxCategory = categories[0].key;
    }

    const nav = document.createElement('nav');
    nav.className = 'item-tax-tabs';
    categories.forEach((category) => {
        const button = document.createElement('button');
        button.className = `tab${category.key === state.activeItemTaxCategory ? ' active' : ''}`;
        button.type = 'button';
        button.textContent = category.label;
        button.addEventListener('click', () => {
            state.activeItemTaxCategory = category.key;
            render();
        });
        nav.appendChild(button);
    });
    items.appendChild(nav);

    const visibleItems = stockItems
        .filter((item) => item.category === state.activeItemTaxCategory)
        .sort((a, b) => String(a.itemLabel || '').localeCompare(String(b.itemLabel || '')));

    if (visibleItems.length === 0) {
        items.appendChild(emptyRow('Keine Artikel', 'In diesem Reiter sind keine Artikel vorhanden.'));
        return;
    }

    visibleItems.forEach((item) => {
        const row = document.createElement('article');
        row.className = 'panel-row item-tax-row';
        row.innerHTML = `
            <div>
                <div class="item-title">${escapeHtml(item.itemLabel)}</div>
                <span class="item-meta">${escapeHtml(item.categoryLabel)} | Einkauf ${money(item.buyPrice)} | Verkauf ${money(item.sellPrice)}</span>
            </div>
            <label>Einkauf %<input data-tax="buy" type="number" min="5" step="0.01" value="${Number(item.taxBuyRate || 5).toFixed(2)}"></label>
            <label>Verkauf %<input data-tax="sell" type="number" min="6" step="0.01" value="${Number(item.taxSellRate || 6).toFixed(2)}"></label>
            <button type="button">Setzen</button>
        `;

        row.querySelector('button').addEventListener('click', () => {
            const buyInput = row.querySelector('[data-tax="buy"]');
            const sellInput = row.querySelector('[data-tax="sell"]');
            runAction('setItemTaxes', {
                itemName: item.itemName,
                buyRate: buyInput.value,
                sellRate: sellInput.value
            });
        });

        items.appendChild(row);
    });
}

function renderMarketStorage(data) {
    items.appendChild(sectionTitle('Markthallenlager'));

    const market = data.market || {};
    const exportPercent = Number(market.exportPercent !== undefined ? market.exportPercent : 5);
    const stockItems = (data.items || []).slice().sort((a, b) => {
        const categoryCompare = String(a.categoryLabel || '').localeCompare(String(b.categoryLabel || ''));
        if (categoryCompare !== 0) return categoryCompare;
        return String(a.itemLabel || '').localeCompare(String(b.itemLabel || ''));
    });

    if (stockItems.length === 0) {
        items.appendChild(emptyRow('Kein Lagerbestand', 'Keine Waren oder Waffen in der Config gefunden.'));
        return;
    }

    stockItems.forEach((item) => {
        const stock = Number(item.stock || 0);
        const totalValue = Number(item.buyPrice || 0) * stock;
        const exportValue = totalValue * (exportPercent / 100);
        const row = document.createElement('article');
        const enabled = isEnabled(item.enabled);
        row.className = `panel-row storage-row${enabled ? '' : ' is-disabled'}`;
        row.innerHTML = `
            <div>
                <div class="item-title">${escapeHtml(item.itemLabel)}</div>
                <span class="item-meta">${escapeHtml(item.categoryLabel)} | ${enabled ? 'aktiv' : 'deaktiviert'} | Bestand ${stock} | Export ${exportPercent.toFixed(2)}%: ${money(exportValue)}</span>
            </div>
            <label class="toggle-check">
                <input type="checkbox" ${enabled ? 'checked' : ''}>
                <span>Angeboten</span>
            </label>
            <input type="number" min="1" step="1" value="${stock > 0 ? 1 : 0}" ${stock <= 0 ? 'disabled' : ''}>
        `;

        const checkbox = row.querySelector('.toggle-check input');
        checkbox.addEventListener('change', () => {
            const previous = enabled;
            checkbox.disabled = true;
            runAction('toggleMarketItem', { itemName: item.itemName, enabled: checkbox.checked })
                .then((result) => {
                    if (!result || !result.ok) {
                        checkbox.checked = previous;
                    }
                })
                .finally(() => {
                    checkbox.disabled = false;
                });
        });

        const input = row.querySelector('input[type="number"]');
        const actions = document.createElement('div');
        actions.className = 'compact-actions';
        const withdraw = actionButton('Entnehmen', () => doStockAction('withdrawStock', item, input));
        const exportButton = actionButton('Export', () => doStockAction('exportStock', item, input));
        withdraw.disabled = stock <= 0;
        exportButton.disabled = stock <= 0;
        actions.appendChild(withdraw);
        actions.appendChild(exportButton);
        row.appendChild(actions);
        items.appendChild(row);
    });
}

function renderCitizenRegistry(citizens) {
    items.appendChild(sectionTitle('Bürgerregister'));
    const jobs = (state.data && state.data.office && state.data.office.jobs) || [];

    if (citizens.length === 0) {
        items.appendChild(emptyRow('Keine Eintraege', 'Aktuell gibt es keine offenen oder aktiven Bürger.'));
        return;
    }

    citizens.forEach((citizen) => {
        const row = document.createElement('article');
        row.className = 'panel-row citizen-row';
        row.innerHTML = `
            <div>
                <div class="item-title">${escapeHtml(citizen.name)}</div>
                <span class="item-meta">${citizenshipText(citizen.status)} | Char-ID ${escapeHtml(citizen.charid)}${citizen.job ? ` | Job: ${escapeHtml(citizen.joblabel || citizen.job)} Rang ${Number(citizen.jobgrade || 0)}` : ''}</span>
            </div>
            <input type="text" maxlength="180" placeholder="Grund optional">
        `;

        if (citizen.status === 'active' && jobs.length > 0) {
            const jobBox = document.createElement('div');
            jobBox.className = 'citizen-job';
            const select = document.createElement('select');
            jobs.forEach((job) => {
                const option = document.createElement('option');
                option.value = job.key || job.job;
                option.textContent = `${job.label || job.job} Rang ${Number(job.grade || 0)}`;
                if (citizen.job === job.job && Number(citizen.jobgrade || 0) === Number(job.grade || 0)) {
                    option.selected = true;
                }
                select.appendChild(option);
            });
            jobBox.appendChild(select);
            jobBox.appendChild(actionButton('Job setzen', () => runAction('assignCitizenJob', { citizenId: citizen.id, job: select.value })));
            row.appendChild(jobBox);
        }

        const actions = document.createElement('div');
        actions.className = 'compact-actions';
        if (citizen.status === 'pending') {
            actions.appendChild(actionButton('Bestaetigen', () => runAction('approveCitizen', { citizenId: citizen.id })));
        }
        actions.appendChild(actionButton(citizen.status === 'pending' ? 'Ablehnen' : 'Entfernen', () => {
            runAction('removeCitizen', { citizenId: citizen.id, reason: row.querySelector('input').value });
        }));
        row.appendChild(actions);
        items.appendChild(row);
    });
}

function renderLedger(rows) {
    items.appendChild(sectionTitle('Stadtkasse'));

    if (rows.length === 0) {
        items.appendChild(emptyRow('Keine Buchungen', 'Noch keine Eintraege vorhanden.'));
        return;
    }

    rows.slice(0, 10).forEach((entry) => {
        items.appendChild(panelRow(
            entry.entryLabel || entry.entry_type || 'Buchung',
            `${money(entry.amount)} | ${entry.actor_name || 'System'} | ${entry.note || ''}`
        ));
    });
}

function sectionTitle(title) {
    const row = document.createElement('div');
    row.className = 'section-title';
    row.textContent = title;
    return row;
}

function panelRow(title, meta, buttons = []) {
    const row = document.createElement('article');
    row.className = 'panel-row';
    row.innerHTML = `
        <div>
            <div class="item-title">${escapeHtml(title)}</div>
            <span class="item-meta">${escapeHtml(meta)}</span>
        </div>
    `;

    if (buttons.length > 0) {
        const actions = document.createElement('div');
        actions.className = 'compact-actions';
        buttons.forEach((button) => actions.appendChild(button));
        row.appendChild(actions);
    }

    return row;
}

function emptyRow(title, meta) {
    const row = panelRow(title, meta);
    row.classList.add('empty-row');
    return row;
}

function actionButton(label, handler) {
    const button = document.createElement('button');
    button.type = 'button';
    button.textContent = label;
    button.addEventListener('click', handler);
    return button;
}

function doTrade(type, item, amountInput) {
    const amount = Number(amountInput.value || 0);
    runAction(type, { itemName: item.itemName, amount });
}

function doSetPrice(item, buyPrice, sellPrice) {
    runAction('setPrice', { itemName: item.itemName, buyPrice, sellPrice });
}

function doStockAction(action, item, amountInput) {
    const amount = Number(amountInput.value || 0);
    runAction(action, { itemName: item.itemName, amount });
}

document.getElementById('setTaxBtn').addEventListener('click', () => {
    const taxes = {};
    taxInputs.querySelectorAll('.tax-editor').forEach((row) => {
        const category = row.dataset.category;
        taxes[category] = {
            buyRate: row.querySelector('[data-tax="buy"]').value,
            sellRate: row.querySelector('[data-tax="sell"]').value
        };
    });

    runAction('setTaxes', { taxes });
});

document.getElementById('closeBtn').addEventListener('click', () => post('close'));

document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') {
        post('close');
    }
});

window.addEventListener('message', (event) => {
    const payload = event.data || {};
    if (payload.action === 'open') {
        state.open = true;
        hideInteraction();
        app.classList.remove('hidden');
        if (payload.view) {
            state.activeView = payload.view;
        }
        setMessage('');
        setData(payload.data);
    }
    if (payload.action === 'update') {
        setData(payload.data);
    }
    if (payload.action === 'close') {
        state.open = false;
        app.classList.add('hidden');
    }
    if (payload.action === 'showInteraction') {
        showInteraction(payload);
    }
    if (payload.action === 'hideInteraction') {
        hideInteraction();
    }
    if (payload.action === 'message') {
        setMessage(payload.message);
    }
});
