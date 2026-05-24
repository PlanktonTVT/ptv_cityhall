local RESOURCE = GetCurrentResourceName()
local Core = exports.vorp_core:GetCore()
local Menu = exports.vorp_menu:GetMenuData()

local menuOpen = false
local marketWindowOpen = false
local marketWindowMode = 'market'
local activeTownKey = Config.DefaultTown or 'blackwater'
local marketPeds = {}
local cityHallBlips = {}
local interactionShown = false
local interactionTownKey = nil
local syncedTownKey = nil
local interactionCoordsForTown
local selectNearestTown

local function event(name)
    return RESOURCE .. ':server:' .. name
end

local function debugLog(message)
    if Config.Debug then
        print(('[%s] %s'):format(RESOURCE, message))
    end
end

local function townEntries()
    local entries = {}
    local towns = Config.Towns or {}
    local seen = {}

    local function add(key)
        key = tostring(key or '')
        if key ~= '' and towns[key] and not seen[key] then
            seen[key] = true
            entries[#entries + 1] = {
                key = key,
                config = towns[key]
            }
        end
    end

    for _, key in ipairs(Config.TownOrder or {}) do
        add(key)
    end

    for key in pairs(towns) do
        add(key)
    end

    if #entries == 0 then
        entries[1] = {
            key = activeTownKey,
            config = Config.Town
        }
    end

    return entries
end

local function townConfig(townKey)
    local towns = Config.Towns or {}
    townKey = tostring(townKey or activeTownKey or Config.DefaultTown or 'blackwater')
    if towns[townKey] then
        return towns[townKey], townKey
    end

    local defaultKey = Config.DefaultTown or 'blackwater'
    if towns[defaultKey] then
        return towns[defaultKey], defaultKey
    end

    return Config.Town, defaultKey
end

local function townName(townKey)
    local town, key = townConfig(townKey)
    return town.Name or town.name or key
end

local function townHall(townKey)
    local town = townConfig(townKey)
    return town.MarketHall or Config.Town.MarketHall
end

local function configCoords(coords)
    if not coords or coords.x == nil or coords.y == nil or coords.z == nil then
        return nil
    end

    return vector3(tonumber(coords.x) or coords.x, tonumber(coords.y) or coords.y, tonumber(coords.z) or coords.z)
end

local function configHeading(coords, fallback)
    return tonumber(coords and (coords.h or coords.heading or coords.w)) or tonumber(fallback) or 0.0
end

local function setActiveTown(townKey)
    local _, resolved = townConfig(townKey)
    if activeTownKey ~= resolved then
        activeTownKey = resolved
    end

    if syncedTownKey ~= activeTownKey then
        syncedTownKey = activeTownKey
        TriggerServerEvent(event('setActiveTown'), activeTownKey)
    end
end

local function activeTownName()
    return townName(activeTownKey)
end

local function notify(message)
    Core.NotifyRightTip(tostring(message), 5000)
end

local function closeMenu(menu)
    menu.close(true, true, true)
    menuOpen = false
end

RegisterNetEvent(RESOURCE .. ':client:notifyAll', function(message)
    notify(message)
end)

RegisterNetEvent(RESOURCE .. ':client:forceJobState', function(job, jobLabel, grade)
    local stateCharacter = LocalPlayer.state.Character
    if type(stateCharacter) ~= 'table' then
        stateCharacter = {}
    end

    grade = tonumber(grade) or 0
    stateCharacter.Job = tostring(job or '')
    stateCharacter.job = tostring(job or '')
    stateCharacter.JobLabel = tostring(jobLabel or job or '')
    stateCharacter.jobLabel = tostring(jobLabel or job or '')
    stateCharacter.joblabel = tostring(jobLabel or job or '')
    stateCharacter.joblable = tostring(jobLabel or job or '')
    stateCharacter.Grade = grade
    stateCharacter.JobGrade = grade
    stateCharacter.jobGrade = grade
    stateCharacter.jobgrade = grade

    pcall(function()
        LocalPlayer.state:set('Character', stateCharacter, false)
        LocalPlayer.state:set('Job', stateCharacter.Job, false)
        LocalPlayer.state:set('JobLabel', stateCharacter.JobLabel, false)
        LocalPlayer.state:set('JobGrade', grade, false)
        LocalPlayer.state:set('Grade', grade, false)
    end)
end)

local function call(name, ...)
    return Core.Callback.TriggerAwait(RESOURCE .. ':' .. name, activeTownKey, ...)
end

local function sendMarketWindow(action, mode, view)
    setActiveTown(activeTownKey)
    mode = mode or marketWindowMode or 'market'
    local callbackName = mode == 'admin' and 'getMarketAdminWindow' or 'getMarketWindow'
    local data = call(callbackName)
    if not data or not data.ok then
        notify(data and data.message or 'Markthalle konnte nicht geladen werden.')
        return false
    end

    SendNUIMessage({
        action = action or 'update',
        data = data,
        view = view
    })
    return data
end

local function refreshMarketWindow()
    if marketWindowOpen then
        return sendMarketWindow('update', marketWindowMode)
    end

    return nil
end

local function closeMarketWindow()
    marketWindowOpen = false
    marketWindowMode = 'market'
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function openMarketWindow()
    if marketWindowOpen then
        return
    end

    setActiveTown(activeTownKey)
    TriggerServerEvent(event('requestMarketWindow'), activeTownKey)
end

local function openMarketAdminWindow(initialView)
    if marketWindowOpen then
        return
    end

    setActiveTown(activeTownKey)
    marketWindowMode = 'admin'
    if sendMarketWindow('open', 'admin', initialView) then
        marketWindowOpen = true
        SetNuiFocus(true, true)
    else
        marketWindowMode = 'market'
    end
end

RegisterNetEvent(RESOURCE .. ':client:showMarketWindow', function(data)
    if not data or not data.ok then
        notify(data and data.message or 'Markthalle konnte nicht geladen werden.')
        return
    end

    marketWindowOpen = true
    marketWindowMode = data.mode or 'market'
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        data = data
    })
end)

RegisterNetEvent(RESOURCE .. ':client:openAdminWindow', function(townKey)
    if townKey then
        setActiveTown(townKey)
    elseif selectNearestTown then
        selectNearestTown(75.0)
    end

    openMarketAdminWindow('office')
end)

RegisterNUICallback('close', function(data, cb)
    closeMarketWindow()
    cb({ ok = true })
end)

RegisterNUICallback('buy', function(data, cb)
    local result = call('marketBuy', data.itemName, data.amount) or { ok = false, message = 'Aktion fehlgeschlagen.' }
    refreshMarketWindow()
    cb(result)
end)

RegisterNUICallback('sell', function(data, cb)
    local result = call('marketSell', data.itemName, data.amount) or { ok = false, message = 'Aktion fehlgeschlagen.' }
    refreshMarketWindow()
    cb(result)
end)

RegisterNUICallback('setPrice', function(data, cb)
    local result = call('marketSetPrice', data.itemName, data.buyPrice, data.sellPrice) or { ok = false, message = 'Aktion fehlgeschlagen.' }
    refreshMarketWindow()
    cb(result)
end)

RegisterNUICallback('setTaxes', function(data, cb)
    local result = call('marketSetTaxRates', data.taxes) or { ok = false, message = 'Aktion fehlgeschlagen.' }
    refreshMarketWindow()
    cb(result)
end)

RegisterNUICallback('setItemTaxes', function(data, cb)
    local result = call('marketSetItemTaxRates', data.itemName, data.buyRate, data.sellRate) or { ok = false, message = 'Aktion fehlgeschlagen.' }
    local refreshed = refreshMarketWindow()
    if result and result.ok and refreshed and refreshed.ok then
        result.data = refreshed
    end
    cb(result)
end)

RegisterNUICallback('exportStock', function(data, cb)
    local result = call('marketExportStock', data.itemName, data.amount) or { ok = false, message = 'Aktion fehlgeschlagen.' }
    refreshMarketWindow()
    cb(result)
end)

RegisterNUICallback('withdrawStock', function(data, cb)
    local result = call('marketWithdrawStock', data.itemName, data.amount) or { ok = false, message = 'Aktion fehlgeschlagen.' }
    refreshMarketWindow()
    cb(result)
end)

RegisterNUICallback('toggleMarketItem', function(data, cb)
    local result = call('marketToggleItem', data.itemName, data.enabled) or { ok = false, message = 'Aktion fehlgeschlagen.' }
    local refreshed = refreshMarketWindow()
    if result and result.ok and refreshed and refreshed.ok then
        result.data = refreshed
    end
    cb(result)
end)

RegisterNUICallback('applyCitizenship', function(data, cb)
    TriggerServerEvent(event('applyCitizenship'))
    Wait(300)
    refreshMarketWindow()
    cb({ ok = true, message = 'Bürgerantrag gesendet.' })
end)

RegisterNUICallback('claimPayouts', function(data, cb)
    TriggerServerEvent(event('claimPayouts'))
    Wait(300)
    refreshMarketWindow()
    cb({ ok = true, message = 'Auszahlungen werden abgeholt.' })
end)

RegisterNUICallback('claimItemReturns', function(data, cb)
    TriggerServerEvent(event('claimItemReturns'))
    Wait(300)
    refreshMarketWindow()
    cb({ ok = true, message = 'Warenrueckgaben werden abgeholt.' })
end)

RegisterNUICallback('registerCandidate', function(data, cb)
    TriggerServerEvent(event('registerCandidate'), data.manifesto)
    Wait(300)
    refreshMarketWindow()
    cb({ ok = true, message = 'Kandidatur gesendet.' })
end)

RegisterNUICallback('castVote', function(data, cb)
    TriggerServerEvent(event('castVote'), data.candidateId)
    Wait(300)
    refreshMarketWindow()
    cb({ ok = true, message = 'Stimme gesendet.' })
end)

RegisterNUICallback('startElection', function(data, cb)
    TriggerServerEvent(event('startElectionFromHall'), data.nominationHours, data.votingHours)
    Wait(300)
    refreshMarketWindow()
    cb({ ok = true, message = 'Wahlstart gesendet.' })
end)

RegisterNUICallback('endElection', function(data, cb)
    TriggerServerEvent(event('endElectionFromHall'))
    Wait(300)
    refreshMarketWindow()
    cb({ ok = true, message = 'Wahlabschluss gesendet.' })
end)

RegisterNUICallback('approveCitizen', function(data, cb)
    TriggerServerEvent(event('approveCitizen'), data.citizenId)
    Wait(300)
    refreshMarketWindow()
    cb({ ok = true, message = 'Bürgeraktion gesendet.' })
end)

RegisterNUICallback('removeCitizen', function(data, cb)
    TriggerServerEvent(event('removeCitizen'), data.citizenId, data.reason)
    Wait(300)
    refreshMarketWindow()
    cb({ ok = true, message = 'Bürgeraktion gesendet.' })
end)

RegisterNUICallback('assignCitizenJob', function(data, cb)
    TriggerServerEvent(event('assignCitizenJob'), data.citizenId, data.job)
    Wait(300)
    refreshMarketWindow()
    cb({ ok = true, message = 'Job-Zuweisung gesendet.' })
end)

RegisterNUICallback('mayorAnnouncement', function(data, cb)
    TriggerServerEvent(event('mayorAnnouncement'), data.message)
    Wait(300)
    refreshMarketWindow()
    cb({ ok = true, message = 'Bekanntmachung gesendet.' })
end)

RegisterNUICallback('treasuryGrant', function(data, cb)
    TriggerServerEvent(event('treasuryGrant'), data.targetId, data.amount, data.reason)
    Wait(300)
    refreshMarketWindow()
    cb({ ok = true, message = 'Auszahlung gesendet.' })
end)

local function money(value)
    return ('$%.2f'):format(tonumber(value) or 0)
end

local function secondsText(seconds)
    seconds = tonumber(seconds) or 0
    if seconds <= 0 then
        return 'jetzt'
    end

    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    if hours > 0 then
        return ('%sh %sm'):format(hours, minutes)
    end

    return ('%sm'):format(minutes)
end

local function citizenStatusText(status)
    if status == 'active' then
        return 'bestaetigter Bürger'
    end

    if status == 'pending' then
        return 'Antrag offen'
    end

    if status == 'removed' then
        return 'ausgetragen'
    end

    return 'nicht eingetragen'
end

local function marketCategories()
    local categories = {}
    local categoryConfig = Config.Market.Categories or {}
    local seen = {}

    local function addCategory(categoryKey, category)
        categoryKey = tostring(categoryKey or '')
        if type(category) ~= 'table' or seen[categoryKey] then
            return
        end

        seen[categoryKey] = true
        categories[#categories + 1] = {
            key = categoryKey,
            label = category.label or categoryKey
        }
    end

    for _, categoryKey in ipairs(Config.Market.CategoryOrder or {}) do
        addCategory(categoryKey, categoryConfig[categoryKey])
    end

    for categoryKey, category in pairs(categoryConfig) do
        addCategory(categoryKey, category)
    end

    return categories
end

local function marketCategoryLabel(categoryKey)
    for _, category in ipairs(marketCategories()) do
        if category.key == categoryKey then
            return category.label
        end
    end

    return 'Markthalle'
end

local function openMainMenu()
    if menuOpen then
        return
    end

    local dashboard = call('getDashboard')
    if not dashboard or not dashboard.ok then
        notify(dashboard and dashboard.message or 'Daten konnten nicht geladen werden.')
        return
    end

    menuOpen = true
    Menu.CloseAll()

    local town = dashboard.town
    local election = dashboard.election
    local player = dashboard.player
    local citizenCounts = town.citizens or { active = 0, pending = 0 }
    local citizenshipText = citizenStatusText(player.citizenship)
    local electionLine = 'Keine Wahl aktiv'
    if election then
        local phaseLabel = election.phase == 'nomination' and 'Kandidaturphase' or 'Abstimmung'
        electionLine = ('%s, Restzeit %s'):format(phaseLabel, secondsText(election.remaining))
    end

    local elements = {
        {
            label = 'Stadtstatus',
            value = 'status',
            desc = ('Bürgermeister: %s | Stadtkasse: %s | Einkaufsteuer: %.2f%% | Verkaufsteuer: %.2f%% | Bürger: %s aktiv, %s offen | Du: %s | Wahl: %s'):format(
                town.mayorName or 'nicht besetzt',
                money(town.treasury),
                town.taxBuyRate or town.taxRate or 0,
                town.taxSellRate or town.taxRate or 0,
                citizenCounts.active or 0,
                citizenCounts.pending or 0,
                citizenshipText,
                electionLine
            )
        },
        { label = 'Wahlen', value = 'elections', desc = 'Kandidieren, Kandidaten ansehen und abstimmen.' },
        { label = 'Markthalle', value = 'market', desc = 'Waren einstellen, kaufen und eigene Angebote verwalten.' }
    }

    if player.citizenship ~= 'active' and player.citizenship ~= 'pending' then
        elements[#elements + 1] = {
            label = 'Als Bürger eintragen',
            value = 'citizen_apply',
            desc = ('Bürgerschaft fuer %s beantragen.'):format(activeTownName())
        }
    elseif player.citizenship == 'pending' then
        elements[#elements + 1] = {
            label = 'Bürgerantrag offen',
            value = 'noop',
            desc = 'Der Bürgermeister muss deinen Antrag noch bestaetigen.'
        }
    end

    if player.pendingPayout and player.pendingPayout > 0 then
        elements[#elements + 1] = {
            label = 'Auszahlungen abholen',
            value = 'claim',
            desc = ('Offen: %s'):format(money(player.pendingPayout))
        }
    end

    if player.pendingItemReturns and player.pendingItemReturns > 0 then
        elements[#elements + 1] = {
            label = 'Warenrueckgaben abholen',
            value = 'claim_items',
            desc = ('Offen: %s Items'):format(player.pendingItemReturns)
        }
    end

    if player.canUseOffice then
        elements[#elements + 1] = {
            label = 'Bürgermeisteramt',
            value = 'office',
            desc = 'Steuer setzen, Stadtkasse verwalten und Bekanntmachungen senden.'
        }
    end

    Menu.Open('default', RESOURCE, 'main', {
        title = activeTownName(),
        subtext = 'Rathaus und Markthalle',
        align = 'top-left',
        elements = elements,
        maxVisibleItems = 7,
        hideRadar = true,
        soundOpen = true
    }, function(data, menu)
        if data.current.value == 'elections' then
            menu.close(true, true, true)
            menuOpen = false
            openElectionMenu()
        elseif data.current.value == 'market' then
            menu.close(true, true, true)
            menuOpen = false
            openMarketWindow()
        elseif data.current.value == 'claim' then
            TriggerServerEvent(event('claimPayouts'))
            menu.close(true, true, true)
            menuOpen = false
        elseif data.current.value == 'claim_items' then
            TriggerServerEvent(event('claimItemReturns'))
            menu.close(true, true, true)
            menuOpen = false
        elseif data.current.value == 'citizen_apply' then
            TriggerServerEvent(event('applyCitizenship'))
            menu.close(true, true, true)
            menuOpen = false
        elseif data.current.value == 'office' then
            menu.close(true, true, true)
            menuOpen = false
            openOfficeMenu()
        end
    end, function(data, menu)
        menu.close(true, true, true)
        menuOpen = false
    end)
end

_G.openMainMenu = openMainMenu

function openElectionMenu()
    if menuOpen then
        return
    end

    local data = call('getElectionCandidates')
    if not data or not data.ok then
        notify(data and data.message or 'Wahldaten konnten nicht geladen werden.')
        return
    end

    menuOpen = true
    Menu.CloseAll()

    local phaseText = data.phase == 'nomination' and 'Kandidaturphase' or (data.phase == 'voting' and 'Abstimmung' or 'Keine aktive Wahl')
    local elements = {
        { label = 'Aktueller Stand', value = 'noop', desc = ('%s | Restzeit: %s'):format(phaseText, secondsText(data.remaining)) }
    }

    if data.phase == 'nomination' then
        elements[#elements + 1] = { label = 'Kandidatur einreichen', value = 'register', desc = 'Reiche dein Wahlprogramm ein.' }
    end

    if data.phase == 'voting' then
        elements[#elements + 1] = { label = 'Stimme abgeben', value = 'vote_menu', desc = 'Du kannst pro Wahl einmal abstimmen.' }
    end

    for _, candidate in ipairs(data.candidates or {}) do
        elements[#elements + 1] = {
            label = candidate.name,
            value = 'candidate',
            desc = ('Stimmen: %s | %s'):format(candidate.votes or 0, candidate.manifesto or '')
        }
    end
    elements[#elements + 1] = { label = 'Zurueck', value = 'back', desc = 'Zurueck zum Hauptmenue.' }

    Menu.Open('default', RESOURCE, 'elections', {
        title = 'Wahlen',
        subtext = activeTownName(),
        align = 'top-left',
        elements = elements,
        maxVisibleItems = 8,
        hideRadar = true,
        soundOpen = true
    }, function(data, menu)
        if data.current.value == 'register' then
            menu.displayInput({
                inputType = 'text',
                header = 'Wahlprogramm',
                placeholder = 'Kurz und ueberzeugend...',
                buttons = { confirm = 'Einreichen', cancel = 'Abbrechen' },
                maxLength = 240
            }, function(value)
                TriggerServerEvent(event('registerCandidate'), value)
                menu.close(true, true, true)
                menuOpen = false
            end)
        elseif data.current.value == 'vote_menu' then
            menu.close(true, true, true)
            menuOpen = false
            openVoteMenu()
        elseif data.current.value == 'back' then
            closeMenu(menu)
            openMainMenu()
        end
    end, function(data, menu)
        closeMenu(menu)
    end)
end

function openVoteMenu()
    if menuOpen then
        return
    end

    local data = call('getElectionCandidates')
    if not data or not data.ok then
        notify(data and data.message or 'Wahldaten konnten nicht geladen werden.')
        return
    end

    if data.phase ~= 'voting' then
        notify('Aktuell kann nicht abgestimmt werden.')
        return
    end

    local elements = {}
    for _, candidate in ipairs(data.candidates or {}) do
        elements[#elements + 1] = {
            label = candidate.name,
            value = 'vote',
            candidateId = candidate.id,
            desc = candidate.manifesto or ''
        }
    end

    if #elements == 0 then
        notify('Keine Kandidaten vorhanden.')
        return
    end
    elements[#elements + 1] = { label = 'Zurueck', value = 'back', desc = 'Zurueck zu den Wahlen.' }

    menuOpen = true
    Menu.CloseAll()
    Menu.Open('default', RESOURCE, 'vote', {
        title = 'Stimme abgeben',
        subtext = activeTownName(),
        align = 'top-left',
        elements = elements,
        maxVisibleItems = 8,
        hideRadar = true,
        soundOpen = true
    }, function(data, menu)
        if data.current.value == 'vote' then
            TriggerServerEvent(event('castVote'), data.current.candidateId)
            menu.close(true, true, true)
            menuOpen = false
        elseif data.current.value == 'back' then
            closeMenu(menu)
            openElectionMenu()
        end
    end, function(data, menu)
        closeMenu(menu)
    end)
end

function openMarketMenu()
    if menuOpen then
        return
    end

    local categories = marketCategories()
    if #categories == 0 then
        notify('Keine Markthallen-Kategorien konfiguriert.')
        return
    end

    local dashboard = call('getDashboard')
    local town = dashboard and dashboard.ok and dashboard.town or { taxBuyRate = 0, taxSellRate = 0 }
    local player = dashboard and dashboard.ok and dashboard.player or {}
    local listingFee = (player.canUseOffice and Config.Market.MayorNoListingFee) and 0 or Config.Market.ListingFee

    local elements = {
        {
            label = 'Marktinfo',
            value = 'noop',
            desc = ('Einkaufsteuer: %.2f%% | Verkaufsteuer: %.2f%% | Einstellgebuehr: %s'):format(town.taxBuyRate or 0, town.taxSellRate or 0, listingFee > 0 and money(listingFee) or 'frei')
        }
    }
    for _, category in ipairs(categories) do
        elements[#elements + 1] = {
            label = category.label,
            value = 'browse',
            categoryKey = category.key,
            desc = ('Aktive Angebote im Reiter %s. Einkaufsteuer %.2f%%, Verkaufsteuer %.2f%%.'):format(category.label, town.taxBuyRate or 0, town.taxSellRate or 0)
        }
    end
    for _, category in ipairs(categories) do
        elements[#elements + 1] = {
            label = category.label .. ' einstellen',
            value = 'create',
            categoryKey = category.key,
            desc = ('Items aus der Config-Kategorie %s anbieten. Einstellgebuehr: %s'):format(category.label, listingFee > 0 and money(listingFee) or 'frei')
        }
    end
    elements[#elements + 1] = { label = 'Meine Angebote', value = 'mine', desc = 'Aktive eigene Angebote zuruecknehmen.' }
    elements[#elements + 1] = { label = 'Zurueck', value = 'back', desc = 'Zurueck zum Hauptmenue.' }

    menuOpen = true
    Menu.CloseAll()
    Menu.Open('default', RESOURCE, 'market', {
        title = 'Markthalle',
        subtext = activeTownName(),
        align = 'top-left',
        elements = elements,
        hideRadar = true,
        soundOpen = true
    }, function(data, menu)
        if data.current.value == 'browse' then
            menu.close(true, true, true)
            menuOpen = false
            openListingsMenu(data.current.categoryKey)
        elseif data.current.value == 'create' then
            menu.close(true, true, true)
            menuOpen = false
            openInventoryForListing(data.current.categoryKey)
        elseif data.current.value == 'mine' then
            menu.close(true, true, true)
            menuOpen = false
            openMyListings()
        elseif data.current.value == 'back' then
            closeMenu(menu)
            openMainMenu()
        end
    end, function(data, menu)
        closeMenu(menu)
    end)
end

function openListingsMenu(categoryKey)
    if menuOpen then
        return
    end

    local categoryLabel = marketCategoryLabel(categoryKey)
    local data = call('getListings', categoryKey)
    if not data or not data.ok then
        notify(data and data.message or 'Angebote konnten nicht geladen werden.')
        return
    end

    local elements = {}
    local taxRate = tonumber(data.taxRate) or 0
    for _, listing in ipairs(data.listings or {}) do
        local listingTaxRate = tonumber(listing.taxSellRate or taxRate) or 0
        local total = (tonumber(listing.amount) or 0) * (tonumber(listing.price_each) or 0)
        local tax = total * (listingTaxRate / 100)
        elements[#elements + 1] = {
            label = ('%sx %s'):format(listing.amount, listing.item_label),
            value = data.canManage and 'manage_listing' or 'buy',
            listing = listing,
            listingId = listing.id,
            desc = ('Verkaeufer: %s | Preis/Stk: %s | Gesamt: %s | Steuer %.2f%%: %s'):format(listing.seller_name, money(listing.price_each), money(total), listingTaxRate, money(tax)),
            descPrice = { amount = total, icon = 'money', text = 'Kaufen' }
        }
    end

    if #elements == 0 then
        elements[1] = { label = 'Keine Angebote', value = 'noop', desc = ('Der Reiter %s ist leer.'):format(categoryLabel) }
    end
    elements[#elements + 1] = { label = 'Zurueck', value = 'back', desc = 'Zurueck zur Markthalle.' }

    menuOpen = true
    Menu.CloseAll()
    Menu.Open('default', RESOURCE, 'listings', {
        title = categoryLabel,
        subtext = activeTownName(),
        align = 'top-left',
        elements = elements,
        maxVisibleItems = 8,
        hideRadar = true,
        soundOpen = true
    }, function(data, menu)
        if data.current.value == 'buy' then
            TriggerServerEvent(event('buyListing'), data.current.listingId)
            menu.close(true, true, true)
            menuOpen = false
        elseif data.current.value == 'manage_listing' then
            local listing = data.current.listing
            closeMenu(menu)
            openListingActionMenu(listing, categoryKey, tonumber(listing.taxSellRate or taxRate) or 0)
        elseif data.current.value == 'back' then
            closeMenu(menu)
            openMarketMenu()
        end
    end, function(data, menu)
        closeMenu(menu)
    end)
end

function openListingActionMenu(listing, categoryKey, taxRate)
    if menuOpen then
        return
    end

    if not listing then
        notify('Angebot nicht gefunden.')
        return
    end

    taxRate = tonumber(taxRate) or 0
    local total = (tonumber(listing.amount) or 0) * (tonumber(listing.price_each) or 0)
    local tax = total * (taxRate / 100)

    menuOpen = true
    Menu.CloseAll()
    Menu.Open('default', RESOURCE, 'listing_action', {
        title = ('%sx %s'):format(listing.amount, listing.item_label),
        subtext = 'Markthalle',
        align = 'top-left',
        elements = {
            {
                label = 'Preisuebersicht',
                value = 'noop',
                desc = ('Preis/Stk: %s | Gesamt: %s | Steuer %.2f%%: %s'):format(
                    money(listing.price_each),
                    money(total),
                    taxRate,
                    money(tax)
                )
            },
            { label = 'Kaufen', value = 'buy', listingId = listing.id, desc = ('Vom Verkaeufer %s kaufen.'):format(listing.seller_name) },
            { label = 'Preis setzen', value = 'price', listingId = listing.id, desc = 'Bürgermeister-Aktion: Preis pro Stueck anpassen.' },
            { label = 'Aus Markthalle entfernen', value = 'remove', listingId = listing.id, desc = 'Bürgermeister-Aktion: Ware geht an den Verkaeufer zurueck.' },
            { label = 'Zurueck', value = 'back', desc = 'Zurueck zum Reiter.' }
        },
        maxVisibleItems = 6,
        hideRadar = true,
        soundOpen = true
    }, function(data, menu)
        if data.current.value == 'buy' then
            TriggerServerEvent(event('buyListing'), data.current.listingId)
            closeMenu(menu)
        elseif data.current.value == 'price' then
            menu.displayInput({
                inputType = 'number',
                header = 'Neuer Preis pro Stueck',
                placeholder = 'Preis pro Stueck',
                buttons = { confirm = 'Setzen', cancel = 'Abbrechen' },
                maxLength = 10,
                pattern = 'money'
            }, function(value)
                TriggerServerEvent(event('updateListingPrice'), listing.id, value)
                closeMenu(menu)
            end)
        elseif data.current.value == 'remove' then
            TriggerServerEvent(event('removeListingFromMarket'), data.current.listingId)
            closeMenu(menu)
        elseif data.current.value == 'back' then
            closeMenu(menu)
            openListingsMenu(categoryKey)
        end
    end, function(data, menu)
        closeMenu(menu)
    end)
end

function openInventoryForListing(categoryKey)
    if menuOpen then
        return
    end

    local categoryLabel = marketCategoryLabel(categoryKey)
    local data = call('getInventoryItems', categoryKey)
    if not data or not data.ok then
        notify(data and data.message or 'Inventar konnte nicht geladen werden.')
        return
    end

    local elements = {}
    for _, item in ipairs(data.items or {}) do
        elements[#elements + 1] = {
            label = ('%s x%s'):format(item.label, item.count),
            value = 'select',
            itemName = item.name,
            itemLabel = item.label,
            maxAmount = item.count,
            minAmount = item.minAmount,
            configMaxAmount = item.maxAmount,
            desc = ('Menge: %s-%s'):format(item.minAmount, item.maxAmount)
        }
    end
    if #elements == 0 then
        notify(('Keine passenden %s im Inventar.'):format(categoryLabel))
        return
    end
    elements[#elements + 1] = { label = 'Zurueck', value = 'back', desc = 'Zurueck zur Markthalle.' }

    menuOpen = true
    Menu.CloseAll()
    Menu.Open('default', RESOURCE, 'inventory_listing', {
        title = categoryLabel .. ' einstellen',
        subtext = 'Item auswaehlen',
        align = 'top-left',
        elements = elements,
        maxVisibleItems = 8,
        hideRadar = true,
        soundOpen = true
    }, function(data, menu)
        if data.current.value == 'back' then
            closeMenu(menu)
            openMarketMenu()
            return
        end

        if data.current.value ~= 'select' then
            return
        end

        local item = data.current
        menu.displayInput({
            inputType = 'number',
            header = ('Menge: %s'):format(item.itemLabel),
            placeholder = ('%s bis %s'):format(item.minAmount or 1, item.configMaxAmount or item.maxAmount),
            buttons = { confirm = 'Weiter', cancel = 'Abbrechen' },
            maxLength = 4,
            pattern = 'numbers'
        }, function(amountValue)
            local amount = tonumber(amountValue)
            if not amount then
                notify('Ungueltige Menge.')
                return
            end

            menu.displayInput({
                inputType = 'number',
                header = 'Preis pro Stueck',
                placeholder = 'Preis pro Stueck',
                buttons = { confirm = 'Einstellen', cancel = 'Abbrechen' },
                maxLength = 10,
                pattern = 'money'
            }, function(priceValue)
                TriggerServerEvent(event('createListing'), item.itemName, amount, priceValue)
                menu.close(true, true, true)
                menuOpen = false
            end)
        end)
    end, function(data, menu)
        closeMenu(menu)
    end)
end

function openMyListings()
    if menuOpen then
        return
    end

    local data = call('getMyListings')
    if not data or not data.ok then
        notify(data and data.message or 'Eigene Angebote konnten nicht geladen werden.')
        return
    end

    local elements = {}
    for _, listing in ipairs(data.listings or {}) do
        elements[#elements + 1] = {
            label = ('%sx %s'):format(listing.amount, listing.item_label),
            value = 'cancel',
            listingId = listing.id,
            desc = ('Reiter: %s | Preis/Stk: %s | Zuruecknehmen'):format(listing.categoryLabel or 'Nicht konfiguriert', money(listing.price_each))
        }
    end

    if #elements == 0 then
        elements[1] = { label = 'Keine eigenen Angebote', value = 'noop', desc = 'Du hast aktuell nichts eingestellt.' }
    end
    elements[#elements + 1] = { label = 'Zurueck', value = 'back', desc = 'Zurueck zur Markthalle.' }

    menuOpen = true
    Menu.CloseAll()
    Menu.Open('default', RESOURCE, 'my_listings', {
        title = 'Meine Angebote',
        subtext = activeTownName(),
        align = 'top-left',
        elements = elements,
        maxVisibleItems = 8,
        hideRadar = true,
        soundOpen = true
    }, function(data, menu)
        if data.current.value == 'cancel' then
            TriggerServerEvent(event('cancelListing'), data.current.listingId)
            menu.close(true, true, true)
            menuOpen = false
        elseif data.current.value == 'back' then
            closeMenu(menu)
            openMarketMenu()
        end
    end, function(data, menu)
        closeMenu(menu)
    end)
end

function openOfficeMenu()
    if menuOpen then
        return
    end

    local dashboard = call('getDashboard')
    local ledger = call('getLedger')
    if ledger and ledger.ok == false then
        notify(ledger.message)
        return
    end

    local town = dashboard and dashboard.ok and dashboard.town or { taxBuyRate = 0, taxSellRate = 0, treasury = 0 }
    local elements = {
        {
            label = 'Steuer und Kasse',
            value = 'noop',
            desc = ('Einkaufsteuer: %.2f%% | Verkaufsteuer: %.2f%% | Stadtkasse: %s'):format(town.taxBuyRate or 0, town.taxSellRate or 0, money(town.treasury))
        },
        { label = 'Bürgerregister', value = 'citizens', desc = 'Antraege bestaetigen und Bürger verwalten.' },
        { label = 'Steuersatz setzen', value = 'tax', desc = ('Setzt Einkaufsteuer; Verkaufsteuer wird automatisch +%.2f Prozentpunkt gesetzt.'):format(Config.Town.MinSellTaxSpread) },
        { label = 'Bekanntmachung', value = 'announce', desc = 'Nachricht an alle Spieler senden.' },
        { label = 'Auszahlung aus Stadtkasse', value = 'grant', desc = 'Online-Spieler per Server-ID bezahlen.' },
        { label = 'Zurueck', value = 'back', desc = 'Zurueck zum Hauptmenue.' }
    }

    for _, row in ipairs((ledger and ledger.rows) or {}) do
        elements[#elements + 1] = {
            label = ('Buchung: %s'):format(row.entryLabel or row.entry_type),
            value = 'noop',
            desc = ('%s | %s | %s'):format(money(row.amount), row.actor_name or 'System', row.note or '')
        }
    end

    menuOpen = true
    Menu.CloseAll()
    Menu.Open('default', RESOURCE, 'office', {
        title = 'Bürgermeisteramt',
        subtext = activeTownName(),
        align = 'top-left',
        elements = elements,
        maxVisibleItems = 8,
        hideRadar = true,
        soundOpen = true
    }, function(data, menu)
        if data.current.value == 'citizens' then
            menu.close(true, true, true)
            menuOpen = false
            openCitizenRegistry()
        elseif data.current.value == 'tax' then
            menu.displayInput({
                inputType = 'number',
                header = 'Neue Einkaufsteuer',
                placeholder = ('mind. %.2f'):format(Config.Town.MinTaxRate),
                buttons = { confirm = 'Setzen', cancel = 'Abbrechen' },
                maxLength = 5,
                pattern = 'money'
            }, function(value)
                TriggerServerEvent(event('setTaxRate'), value)
                menu.close(true, true, true)
                menuOpen = false
            end)
        elseif data.current.value == 'announce' then
            menu.displayInput({
                inputType = 'text',
                header = 'Bekanntmachung',
                placeholder = 'Text...',
                buttons = { confirm = 'Senden', cancel = 'Abbrechen' },
                maxLength = 180
            }, function(value)
                TriggerServerEvent(event('mayorAnnouncement'), value)
                menu.close(true, true, true)
                menuOpen = false
            end)
        elseif data.current.value == 'grant' then
            menu.displayInput({
                inputType = 'number',
                header = 'Server-ID',
                placeholder = 'Spieler-ID',
                buttons = { confirm = 'Weiter', cancel = 'Abbrechen' },
                maxLength = 5,
                pattern = 'numbers'
            }, function(targetId)
                menu.displayInput({
                    inputType = 'number',
                    header = 'Betrag',
                    placeholder = 'z.B. 25',
                    buttons = { confirm = 'Weiter', cancel = 'Abbrechen' },
                    maxLength = 10,
                    pattern = 'money'
                }, function(amount)
                    menu.displayInput({
                        inputType = 'text',
                        header = 'Grund',
                        placeholder = 'optional',
                        buttons = { confirm = 'Auszahlen', cancel = 'Abbrechen' },
                        maxLength = 120
                    }, function(reason)
                        TriggerServerEvent(event('treasuryGrant'), targetId, amount, reason)
                        menu.close(true, true, true)
                        menuOpen = false
                    end)
                end)
            end)
        elseif data.current.value == 'back' then
            closeMenu(menu)
            openMainMenu()
        end
    end, function(data, menu)
        closeMenu(menu)
    end)
end

function openCitizenRegistry()
    if menuOpen then
        return
    end

    local data = call('getCitizenRegistry')
    if not data or not data.ok then
        notify(data and data.message or 'Bürgerregister konnte nicht geladen werden.')
        return
    end

    local counts = data.counts or { active = 0, pending = 0 }
    local elements = {
        {
            label = 'Uebersicht',
            value = 'noop',
            desc = ('Bestaetigte Bürger: %s | Offene Antraege: %s'):format(counts.active or 0, counts.pending or 0)
        }
    }

    for _, citizen in ipairs(data.citizens or {}) do
        local actionText = citizen.status == 'pending' and 'Bestaetigen oder ablehnen' or 'Aus Stadt entfernen'
        elements[#elements + 1] = {
            label = citizen.name,
            value = 'manage',
            citizen = citizen,
            desc = ('Status: %s | Char-ID: %s | %s'):format(citizenStatusText(citizen.status), citizen.charid or 'unbekannt', actionText)
        }
    end

    if #elements == 1 then
        elements[#elements + 1] = {
            label = 'Keine Eintraege',
            value = 'noop',
            desc = 'Aktuell gibt es keine offenen oder aktiven Bürger.'
        }
    end
    elements[#elements + 1] = { label = 'Zurueck', value = 'back', desc = 'Zurueck zum Bürgermeisteramt.' }

    menuOpen = true
    Menu.CloseAll()
    Menu.Open('default', RESOURCE, 'citizen_registry', {
        title = 'Bürgerregister',
        subtext = activeTownName(),
        align = 'top-left',
        elements = elements,
        maxVisibleItems = 8,
        hideRadar = true,
        soundOpen = true
    }, function(data, menu)
        if data.current.value == 'manage' then
            local citizen = data.current.citizen
            menu.close(true, true, true)
            menuOpen = false
            openCitizenManageMenu(citizen)
        elseif data.current.value == 'back' then
            closeMenu(menu)
            openOfficeMenu()
        end
    end, function(data, menu)
        closeMenu(menu)
    end)
end

function openCitizenManageMenu(citizen)
    if menuOpen then
        return
    end

    if not citizen then
        notify('Bürger-Eintrag nicht gefunden.')
        return
    end

    local elements = {
        {
            label = 'Status',
            value = 'noop',
            desc = ('%s ist %s.'):format(citizen.name, citizenStatusText(citizen.status))
        }
    }

    if citizen.status == 'pending' then
        elements[#elements + 1] = {
            label = 'Bürger bestaetigen',
            value = 'approve',
            desc = ('%s als Bürger von %s aufnehmen.'):format(citizen.name, activeTownName())
        }
        elements[#elements + 1] = {
            label = 'Antrag ablehnen',
            value = 'remove',
            desc = 'Antrag entfernen und optional Grund hinterlegen.'
        }
    else
        elements[#elements + 1] = {
            label = 'Aus Stadt entfernen',
            value = 'remove',
            desc = 'Bürgerschaft entziehen und optional Grund hinterlegen.'
        }
    end
    elements[#elements + 1] = { label = 'Zurueck', value = 'back', desc = 'Zurueck zum Bürgerregister.' }

    menuOpen = true
    Menu.CloseAll()
    Menu.Open('default', RESOURCE, 'citizen_manage', {
        title = citizen.name,
        subtext = 'Bürgerverwaltung',
        align = 'top-left',
        elements = elements,
        maxVisibleItems = 6,
        hideRadar = true,
        soundOpen = true
    }, function(data, menu)
        if data.current.value == 'approve' then
            TriggerServerEvent(event('approveCitizen'), citizen.id)
            menu.close(true, true, true)
            menuOpen = false
        elseif data.current.value == 'remove' then
            menu.displayInput({
                inputType = 'text',
                header = 'Grund',
                placeholder = 'optional',
                buttons = { confirm = 'Entfernen', cancel = 'Abbrechen' },
                maxLength = 180
            }, function(reason)
                TriggerServerEvent(event('removeCitizen'), citizen.id, reason)
                menu.close(true, true, true)
                menuOpen = false
            end)
        elseif data.current.value == 'back' then
            closeMenu(menu)
            openCitizenRegistry()
        end
    end, function(data, menu)
        closeMenu(menu)
    end)
end

RegisterNetEvent(RESOURCE .. ':client:openMain', function()
    if selectNearestTown then
        selectNearestTown(75.0)
    end

    openMainMenu()
end)

selectNearestTown = function(maxDistance)
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local closest = nil

    for _, entry in ipairs(townEntries()) do
        local hall = townHall(entry.key)
        if hall and hall.coords then
            local coords = interactionCoordsForTown(entry.key)
            if coords then
                local distance = #(playerCoords - coords)
                if not closest or distance < closest.distance then
                    closest = {
                        key = entry.key,
                        town = entry.config,
                        hall = hall,
                        coords = coords,
                        distance = distance
                    }
                end
            end
        end
    end

    if closest and (not maxDistance or closest.distance <= maxDistance) then
        setActiveTown(closest.key)
    end

    return closest
end

RegisterCommand(Config.Commands.Menu, function()
    selectNearestTown(75.0)
    openMainMenu()
end, false)

RegisterCommand(Config.Commands.Market, function()
    selectNearestTown(75.0)
    openMarketWindow()
end, false)

RegisterCommand(Config.Commands.MarketAdmin, function()
    selectNearestTown(75.0)
    openMarketAdminWindow()
end, false)

local function showInteraction()
    if interactionShown and interactionTownKey == activeTownKey then
        return
    end

    interactionShown = true
    interactionTownKey = activeTownKey
    SendNUIMessage({
        action = 'showInteraction',
        keyLabel = 'G',
        eyebrow = activeTownName(),
        title = 'Markthalle und Rathaus',
        message = 'Bürger, Wahlen und Marktverwaltung',
        actionLabel = Config.Text.OpenHint
    })
end

local function hideInteraction()
    if not interactionShown then
        return
    end

    interactionShown = false
    interactionTownKey = nil
    SendNUIMessage({ action = 'hideInteraction' })
end

interactionCoordsForTown = function(townKey)
    local hall = townHall(townKey)
    local ped = hall.Ped or {}
    return configCoords((ped.enabled and ped.coords) or hall.coords)
end

local function loadModel(model)
    local modelHash = type(model) == 'number' and model or GetHashKey(tostring(model))
    RequestModel(modelHash)

    local timeout = GetGameTimer() + 10000
    while not HasModelLoaded(modelHash) and GetGameTimer() < timeout do
        Wait(50)
    end

    if not HasModelLoaded(modelHash) then
        return nil
    end

    return modelHash
end

local function spawnMarketPed(townKey)
    local hall = townHall(townKey)
    local ped = hall.Ped or {}
    if not ped.enabled or marketPeds[townKey] then
        return
    end

    local modelHash = loadModel(ped.model or 'U_M_M_NbxGeneralStoreOwner_01')
    if not modelHash then
        notify(('Markthallen-NPC fuer %s konnte nicht geladen werden.'):format(townName(townKey)))
        return
    end

    local rawCoords = ped.coords or hall.coords
    local coords = configCoords(rawCoords)
    if not coords then
        notify(('Markthallen-NPC fuer %s hat ungueltige Koordinaten.'):format(townName(townKey)))
        return
    end

    local heading = configHeading(rawCoords, ped.heading or configHeading(hall.coords, 0.0))
    local marketPed = CreatePed(modelHash, coords.x, coords.y, coords.z - 1.0, heading, false, false, false, false)
    if marketPed and DoesEntityExist(marketPed) then
        marketPeds[townKey] = marketPed
        Citizen.InvokeNative(0x283978A15512B2FE, marketPed, true)
        SetEntityInvincible(marketPed, true)
        FreezeEntityPosition(marketPed, true)
        SetBlockingOfNonTemporaryEvents(marketPed, true)
    end

    SetModelAsNoLongerNeeded(modelHash)
end

local function blipSprite(sprite)
    if type(sprite) == 'number' then
        return sprite
    end

    return GetHashKey(tostring(sprite or 'blip_ambient_vip'))
end

local function blipExists(blip)
    if not blip or blip == 0 then
        return false
    end

    if type(DoesBlipExist) == 'function' then
        return DoesBlipExist(blip)
    end

    return true
end

local function createCityHallBlip(townKey)
    local globalBlip = Config.CityHallBlip or {}
    local town = townConfig(townKey)
    local townBlip = town.Blip or {}
    if globalBlip.enabled == false or townBlip.enabled == false then
        return
    end

    if blipExists(cityHallBlips[townKey]) then
        return
    end

    cityHallBlips[townKey] = nil

    local hall = townHall(townKey)
    if not hall or not hall.coords then
        debugLog(('Kein Rathauspunkt fuer Blip %s gefunden.'):format(tostring(townKey)))
        return
    end

    local coords = configCoords(townBlip.coords or hall.coords)
    if not coords then
        debugLog(('Rathaus-Blip fuer %s hat ungueltige Koordinaten.'):format(townName(townKey)))
        return
    end

    local style = tonumber(townBlip.style or globalBlip.style) or 1664425300
    local sprite = blipSprite(townBlip.sprite or globalBlip.sprite)
    local scale = tonumber(townBlip.scale or globalBlip.scale) or 0.22
    local blip = Citizen.InvokeNative(0x554D9D53F696D002, style, coords.x, coords.y, coords.z)
    if not blip or blip == 0 then
        debugLog(('Rathaus-Blip fuer %s konnte nicht erstellt werden.'):format(townName(townKey)))
        return
    end

    SetBlipSprite(blip, sprite, true)
    SetBlipScale(blip, scale)
    Citizen.InvokeNative(0xD38744167B2FA257, blip, scale)
    Citizen.InvokeNative(0x9CB1A1623062F402, blip, tostring(townBlip.label or ((globalBlip.labelPrefix or 'Rathaus') .. ' ' .. townName(townKey))))
    cityHallBlips[townKey] = blip
    debugLog(('Rathaus-Blip erstellt: %s / Sprite %s / Style %s.'):format(townName(townKey), tostring(sprite), tostring(style)))
end

local function setupTownPoints()
    for _, entry in ipairs(townEntries()) do
        spawnMarketPed(entry.key)
        createCityHallBlip(entry.key)
    end
end

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= RESOURCE then
        return
    end

    for townKey, marketPed in pairs(marketPeds) do
        if marketPed and DoesEntityExist(marketPed) then
            DeletePed(marketPed)
        end
        marketPeds[townKey] = nil
    end

    for townKey, blip in pairs(cityHallBlips) do
        RemoveBlip(blip)
        cityHallBlips[townKey] = nil
    end

    hideInteraction()
end)

CreateThread(function()
    Wait(1000)
    setupTownPoints()
    Wait(5000)
    setupTownPoints()

    while true do
        Wait(60000)
        setupTownPoints()
    end
end)

CreateThread(function()
    while true do
        local sleep = 1000
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local closest = nil

        for _, entry in ipairs(townEntries()) do
            local hall = townHall(entry.key)
            if hall and hall.coords then
                local coords = interactionCoordsForTown(entry.key)
                if coords then
                    local distance = #(playerCoords - coords)
                    if distance <= (hall.hintDistance or 12.0) and (not closest or distance < closest.distance) then
                        closest = {
                            key = entry.key,
                            hall = hall,
                            distance = distance
                        }
                    end
                end
            end
        end

        if closest then
            local hall = closest.hall
            local interactionDistance = hall.interactionDistance or hall.radius or 2.25
            sleep = 250
            if closest.distance <= interactionDistance and not marketWindowOpen then
                sleep = 0
                setActiveTown(closest.key)
                showInteraction()

                if IsControlJustReleased(0, Config.Keys.Interact) then
                    hideInteraction()
                    openMarketWindow()
                    Wait(500)
                end
            else
                hideInteraction()
            end
        else
            hideInteraction()
        end

        Wait(sleep)
    end
end)
