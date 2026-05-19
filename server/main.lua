local RESOURCE = GetCurrentResourceName()
local Core = exports.vorp_core:GetCore()

local started = false
local activeTownBySource = {}
local characterColumnCache = nil
local electionReminderSent = {}
local assignedJobByCharId = {}
local assignedJobBySource = {}

local function debugLog(message)
    if Config.Debug then
        print(('[%s] %s'):format(RESOURCE, message))
    end
end

local function now()
    return os.time()
end

local function roundMoney(value)
    value = tonumber(value) or 0
    return math.floor((value * 100) + 0.5) / 100
end

local function money(value)
    return ('$%.2f'):format(roundMoney(value))
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

local function trim(value)
    value = tostring(value or '')
    return value:match('^%s*(.-)%s*$')
end

local function notify(source, message)
    if source == 0 then
        print(('[%s] %s'):format(RESOURCE, message))
        return
    end

    Core.NotifyTip(source, tostring(message), 5000)
end

local function consoleLog(message, color)
    print(('%s[%s]^0 %s'):format(color or '^5', RESOURCE, tostring(message or '')))
end

local function scriptVersion()
    local configured = trim(Config.Version)
    if configured ~= '' then
        return configured
    end

    local manifestVersion = GetResourceMetadata(RESOURCE, 'version', 0)
    manifestVersion = trim(manifestVersion)
    if manifestVersion ~= '' then
        return manifestVersion
    end

    return 'unknown'
end

local function versionParts(version)
    local parts = {}
    for number in tostring(version or ''):gmatch('(%d+)') do
        parts[#parts + 1] = tonumber(number) or 0
    end

    return parts
end

local function compareVersions(current, latest)
    local currentParts = versionParts(current)
    local latestParts = versionParts(latest)
    local maxParts = math.max(#currentParts, #latestParts)

    for i = 1, maxParts do
        local currentPart = currentParts[i] or 0
        local latestPart = latestParts[i] or 0
        if currentPart < latestPart then
            return -1
        end
        if currentPart > latestPart then
            return 1
        end
    end

    return 0
end

local function updateInfoFromBody(body)
    body = trim(body)
    if body == '' then
        return {}
    end

    if json and json.decode then
        local ok, decoded = pcall(json.decode, body)
        if ok and type(decoded) == 'table' then
            return {
                version = trim(decoded.version or decoded.latest or decoded.latestVersion or decoded.tag_name),
                download = trim(decoded.download or decoded.downloadUrl or decoded.url or decoded.html_url),
                changelog = trim(decoded.changelog or decoded.notes or decoded.body)
            }
        end
    end

    local lines = {}
    for line in body:gmatch('[^\r\n]+') do
        local value = trim(line)
        if value ~= '' then
            lines[#lines + 1] = value
        end
    end

    return {
        version = trim(lines[1]),
        download = trim(lines[2]),
        changelog = trim(lines[3])
    }
end

local function runUpdateChecker(manual)
    local checker = Config.UpdateChecker or {}
    local currentVersion = scriptVersion()

    if checker.Enabled == false then
        consoleLog(('Version %s geladen. Updatechecker ist deaktiviert.'):format(currentVersion), '^3')
        return
    end

    local url = trim(checker.Url)
    if url == '' then
        if manual or checker.PrintIfNoUrl ~= false then
            consoleLog(('Version %s geladen. Updatechecker bereit, aber Config.UpdateChecker.Url ist leer.'):format(currentVersion), '^3')
            consoleLog('Trage dort eine Raw-URL ein, die z.B. 1.0 oder JSON mit {"version":"1.0"} liefert.', '^3')
        end
        return
    end

    consoleLog(('Version %s geladen. Updatechecker prueft %s'):format(currentVersion, url), '^5')
    PerformHttpRequest(url, function(statusCode, responseBody, _, errorData)
        statusCode = tonumber(statusCode) or 0
        if statusCode < 200 or statusCode >= 300 then
            local suffix = trim(errorData) ~= '' and (' - ' .. trim(errorData)) or ''
            consoleLog(('Updatecheck fehlgeschlagen. HTTP %s%s'):format(statusCode, suffix), '^1')
            return
        end

        local updateInfo = updateInfoFromBody(responseBody)
        local latestVersion = trim(updateInfo.version)
        if latestVersion == '' then
            consoleLog('Updatecheck fehlgeschlagen. Die Update-Datei enthaelt keine Version.', '^1')
            return
        end

        local comparison = compareVersions(currentVersion, latestVersion)
        if comparison < 0 then
            local downloadUrl = trim(updateInfo.download)
            if downloadUrl == '' then
                downloadUrl = trim(checker.DownloadUrl)
            end

            consoleLog(('Update verfuegbar: installiert %s, aktuell %s.'):format(currentVersion, latestVersion), '^3')
            if downloadUrl ~= '' then
                consoleLog(('Download: %s'):format(downloadUrl), '^3')
            end
            if trim(updateInfo.changelog) ~= '' then
                consoleLog(('Changelog: %s'):format(updateInfo.changelog), '^3')
            end
        elseif comparison > 0 then
            consoleLog(('Lokale Version %s ist neuer als die Update-Version %s.'):format(currentVersion, latestVersion), '^2')
        else
            consoleLog(('ptv_cityhall ist aktuell: Version %s.'):format(currentVersion), '^2')
        end
    end, 'GET', '', {
        ['User-Agent'] = RESOURCE .. '/' .. currentVersion,
        ['Cache-Control'] = 'no-cache'
    })
end

local updateCommand = trim((Config.UpdateChecker or {}).Command)
if updateCommand ~= '' then
    RegisterCommand(updateCommand, function(source)
        if source ~= 0 then
            notify(source, 'Dieser Command ist nur ueber die CFX-Konsole verfuegbar.')
            return
        end

        runUpdateChecker(true)
    end, false)
end

local function discordEnabled(eventName)
    local discord = Config.Discord or {}
    if not discord.Enabled or trim(discord.Webhook) == '' then
        return false
    end

    local events = discord.Events or {}
    if eventName and events[eventName] == false then
        return false
    end

    return true
end

local function sendDiscord(eventName, title, description, fields, color)
    if not discordEnabled(eventName) then
        return
    end

    local discord = Config.Discord or {}
    local embed = {
        title = tostring(title or 'PTV Cityhall'),
        description = tostring(description or ''),
        color = tonumber(color or discord.Color) or 16768851,
        fields = fields or {},
        footer = { text = RESOURCE },
        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
    }

    local payload = {
        username = discord.Username or 'PTV Cityhall',
        embeds = { embed }
    }

    if trim(discord.AvatarUrl) ~= '' then
        payload.avatar_url = discord.AvatarUrl
    end

    PerformHttpRequest(discord.Webhook, function() end, 'POST', json.encode(payload), { ['Content-Type'] = 'application/json' })
end

local function usedCharacter(user)
    if not user then
        return nil
    end

    local character = user.getUsedCharacter
    if type(character) == 'function' then
        local ok, result = pcall(character)
        if ok and type(result) == 'table' then
            character = result
        else
            ok, result = pcall(character, user)
            character = ok and result or nil
        end
    end

    if type(character) ~= 'table' then
        return nil
    end

    return character
end

local function getUserAndCharacter(source)
    local user = Core.getUser(source)
    if not user then
        return nil, nil
    end

    local character = usedCharacter(user)
    if not character then
        return user, nil
    end

    return user, character
end

local function getCoreUserByCharId(charid)
    if not Core.getUserByCharId then
        return nil
    end

    local ok, user = pcall(Core.getUserByCharId, tonumber(charid) or charid)
    if not ok then
        debugLog(('Core.getUserByCharId fehlgeschlagen: %s'):format(tostring(user)))
        return nil
    end

    return user
end

local function characterName(character)
    local name = trim(('%s %s'):format(character.firstname or '', character.lastname or ''))
    if name == '' then
        return ('Char %s'):format(tostring(character.charIdentifier or 'unknown'))
    end

    return name
end

local function characterInfo(source)
    local user, character = getUserAndCharacter(source)
    if not character then
        return nil
    end

    return {
        user = user,
        character = character,
        identifier = tostring(character.identifier or ''),
        charid = tostring(character.charIdentifier),
        name = characterName(character),
        group = tostring(character.group or user.getGroup or '')
    }
end

local function databaseUserGroup(identifier)
    identifier = tostring(identifier or '')
    if identifier == '' then
        return nil
    end

    local ok, rows = pcall(MySQL.query.await, 'SELECT `group` FROM users WHERE identifier = ? LIMIT 1', { identifier })
    if not ok then
        debugLog(('users.group konnte nicht gelesen werden: %s'):format(rows))
        return nil
    end

    return rows and rows[1] and rows[1].group or nil
end

local function findSourceByCharId(charid)
    charid = tostring(charid)
    for _, player in ipairs(GetPlayers()) do
        local playerSource = tonumber(player)
        local info = playerSource and characterInfo(playerSource) or nil
        if info and info.charid == charid then
            return playerSource
        end
    end

    local user = getCoreUserByCharId(charid)
    local userSource = tonumber(user and user.source)
    if userSource then
        return userSource
    end

    return nil
end

local function isAdmin(source)
    if source == 0 then
        return true
    end

    local info = characterInfo(source)
    if not info then
        return false
    end

    local group = databaseUserGroup(info.identifier) or info.group
    return Config.AdminGroups[tostring(group or '')] == true
end

local function resolveTownKey(context)
    if type(context) == 'number' then
        return activeTownBySource[context] or BMDB.defaultTownKey()
    end

    if type(context) == 'string' and context ~= '' then
        local townKey = BMDB.townConfig(context)
        return townKey
    end

    return BMDB.defaultTownKey()
end

local function getTown(context)
    local townKey = resolveTownKey(context)
    return BMDB.getTown(townKey) or BMDB.ensureTownByKey(townKey)
end

local function setActiveTown(source, townKey)
    if source == 0 then
        return BMDB.defaultTownKey()
    end

    local resolved = resolveTownKey(townKey)
    activeTownBySource[source] = resolved
    return resolved
end

local function isMayor(source, town)
    local info = characterInfo(source)
    if not info or not town or not town.mayor_charid then
        return false
    end

    return tostring(town.mayor_charid) == info.charid
end

local function canUseOffice(source, town)
    return isAdmin(source) or isMayor(source, town)
end

local function configuredJobGrade(job)
    return tonumber(job and job.grade)
        or tonumber(job and job.jobgrade)
        or tonumber(job and job.jobGrade)
        or tonumber(job and job.job_grade)
        or tonumber(job and job.rank)
        or 0
end

local function configuredJobLabel(job)
    return job and (job.jobLabel or job.joblabel or job.joblable or job.label or job.job) or ''
end

local function mayorJobKey(jobName, grade)
    return ('%s|%s'):format(tostring(jobName or ''), tostring(tonumber(grade) or 0))
end

local function mayorJobsConfig(town)
    local towns = Config.Towns or {}
    local townConfig = town and town.key and towns[town.key] or nil
    if townConfig and townConfig.MayorJobs then
        return townConfig.MayorJobs
    end

    return Config.MayorJobs or {}
end

local function configuredMayorJobs(town)
    local mayorJobs = mayorJobsConfig(town)
    if mayorJobs.Enabled == false then
        return {}
    end

    local jobs = {}
    for _, job in ipairs(mayorJobs.Jobs or {}) do
        if type(job) == 'table' and trim(job.job) ~= '' then
            local grade = configuredJobGrade(job)
            local jobName = tostring(job.job)
            jobs[#jobs + 1] = {
                key = mayorJobKey(jobName, grade),
                label = job.label or job.jobLabel or job.job,
                job = jobName,
                grade = grade,
                jobLabel = configuredJobLabel(job)
            }
        end
    end

    return jobs
end

local function allowedMayorJob(jobName, town, jobs)
    jobName = tostring(jobName or '')
    for _, job in ipairs(jobs or configuredMayorJobs(town)) do
        if job.key == jobName or job.job == jobName then
            return job
        end
    end

    return nil
end

local function characterColumns()
    if characterColumnCache then
        return characterColumnCache
    end

    characterColumnCache = {}
    local ok, rows = pcall(MySQL.query.await, 'SHOW COLUMNS FROM characters')
    if not ok then
        debugLog(('characters-Spalten konnten nicht gelesen werden: %s'):format(rows))
        return characterColumnCache
    end

    for _, row in ipairs(rows or {}) do
        local field = tostring(row.Field or '')
        characterColumnCache[field:lower()] = field
    end

    return characterColumnCache
end

local function characterColumnName(columns, names)
    for _, name in ipairs(names) do
        local column = columns[tostring(name):lower()]
        if column then
            return column
        end
    end

    return nil
end

local function sqlColumn(name)
    return ('`%s`'):format(tostring(name):gsub('`', '``'))
end

local function characterSelectColumn(columns, names, alias, fallback)
    local column = characterColumnName(columns, names)
    if column then
        return ('ch.%s AS %s'):format(sqlColumn(column), sqlColumn(alias))
    end

    return ('%s AS %s'):format(fallback or "''", sqlColumn(alias))
end

local function updateCharacterJob(citizen, job)
    local columns = characterColumns()
    local sets = {}
    local setParams = {}
    local usedColumns = {}
    local grade = configuredJobGrade(job)
    local jobLabel = configuredJobLabel(job)

    local function addSet(names, value)
        local added = false
        for _, name in ipairs(names) do
            local column = columns[tostring(name):lower()]
            local columnKey = column and column:lower() or nil
            if column and not usedColumns[columnKey] then
                usedColumns[columnKey] = true
                sets[#sets + 1] = ('%s = ?'):format(sqlColumn(column))
                setParams[#setParams + 1] = value
                added = true
            end
        end

        return added
    end

    addSet({ 'job' }, job.job)
    addSet({ 'joblable', 'joblabel', 'jobLabel', 'job_label' }, jobLabel)
    addSet({ 'jobgrade', 'jobGrade', 'job_grade' }, grade)
    addSet({ 'grade' }, grade)

    if #sets == 0 then
        return false, 'In der characters-Tabelle wurden keine Job-Spalten gefunden.'
    end

    local charIdentifierColumn = characterColumnName(columns, { 'charidentifier', 'charIdentifier', 'char_identifier' })
    if not charIdentifierColumn then
        return false, 'In der characters-Tabelle wurde keine charidentifier-Spalte gefunden.'
    end

    local where = ('CAST(%s AS CHAR) = ?'):format(sqlColumn(charIdentifierColumn))
    local whereParams = { tostring(citizen.charid) }

    local params = {}
    for _, value in ipairs(setParams) do
        params[#params + 1] = value
    end
    for _, value in ipairs(whereParams) do
        params[#params + 1] = value
    end

    local updated = MySQL.update.await(
        ("UPDATE characters SET %s WHERE %s"):format(table.concat(sets, ', '), where),
        params
    )

    local gradeSets = {}
    local gradeParams = {}
    local usedGradeColumns = {}
    for _, name in ipairs({ 'jobgrade', 'jobGrade', 'job_grade', 'grade' }) do
        local column = columns[tostring(name):lower()]
        local columnKey = column and column:lower() or nil
        if column and not usedGradeColumns[columnKey] then
            usedGradeColumns[columnKey] = true
            gradeSets[#gradeSets + 1] = ('%s = ?'):format(sqlColumn(column))
            gradeParams[#gradeParams + 1] = grade
        end
    end

    local gradeUpdated = 0
    if #gradeSets > 0 then
        for _, value in ipairs(whereParams) do
            gradeParams[#gradeParams + 1] = value
        end
        gradeUpdated = MySQL.update.await(
            ("UPDATE characters SET %s WHERE %s"):format(table.concat(gradeSets, ', '), where),
            gradeParams
        )
    end

    if (tonumber(updated) or 0) > 0 or (tonumber(gradeUpdated) or 0) > 0 then
        debugLog(('characters aktualisiert: Char %s Job %s Rang %s.'):format(tostring(citizen.charid), tostring(job.job), tostring(grade)))
        return true
    end

    local existing = MySQL.query.await(
        ("SELECT 1 FROM characters WHERE %s LIMIT 1"):format(where),
        whereParams
    )

    return existing and existing[1] ~= nil, 'Charakter nicht in der characters-Tabelle gefunden.'
end

local function rememberAssignedJob(citizen, job)
    local charid = tostring(citizen and citizen.charid or '')
    if charid == '' or not job then
        return
    end

    local saved = {
        charid = charid,
        identifier = tostring(citizen.identifier or ''),
        job = tostring(job.job),
        jobLabel = tostring(configuredJobLabel(job)),
        grade = configuredJobGrade(job)
    }

    assignedJobByCharId[charid] = saved

    local targetSource = findSourceByCharId(charid)
    if targetSource then
        assignedJobBySource[targetSource] = saved
    end
end

local function persistRememberedJob(charid, identifier)
    local saved = assignedJobByCharId[tostring(charid or '')]
    if not saved then
        return
    end

    local citizen = {
        charid = saved.charid,
        identifier = identifier ~= nil and tostring(identifier or '') or saved.identifier
    }
    local ok, message = updateCharacterJob(citizen, saved)
    if not ok then
        debugLog(('Job konnte nachtraeglich nicht gespeichert werden: %s'):format(message or 'unbekannt'))
    end
end

local function refreshOnlineJobState(source, job)
    if not source or not job then
        return
    end

    local grade = configuredJobGrade(job)
    local jobLabel = configuredJobLabel(job)
    local player = Player(source)
    if not player or not player.state then
        return
    end

    local stateCharacter = player.state.Character
    if type(stateCharacter) ~= 'table' then
        stateCharacter = {}
    end

    stateCharacter.Job = tostring(job.job)
    stateCharacter.job = tostring(job.job)
    stateCharacter.JobLabel = jobLabel
    stateCharacter.jobLabel = jobLabel
    stateCharacter.joblabel = jobLabel
    stateCharacter.joblable = jobLabel
    stateCharacter.Grade = grade
    stateCharacter.JobGrade = grade
    stateCharacter.jobGrade = grade
    stateCharacter.jobgrade = grade

    pcall(function()
        player.state:set('Character', stateCharacter, true)
        player.state:set('Job', tostring(job.job), true)
        player.state:set('JobLabel', jobLabel, true)
        player.state:set('JobGrade', grade, true)
        player.state:set('Grade', grade, true)
    end)

    TriggerClientEvent(RESOURCE .. ':client:forceJobState', source, tostring(job.job), jobLabel, grade)
end

local function applyOnlineJob(charid, job)
    local targetSource = findSourceByCharId(charid)
    local user = nil
    local character = nil

    if targetSource then
        user, character = getUserAndCharacter(targetSource)
    end

    if not character then
        user = getCoreUserByCharId(charid)
        character = usedCharacter(user)
        targetSource = targetSource or tonumber(user and user.source)
    end

    if not targetSource then
        return false
    end

    if not character then
        return false
    end

    local function tryOn(targetCharacter, method, ...)
        local fn = targetCharacter and targetCharacter[method]
        if type(fn) ~= 'function' then
            return false
        end

        local ok = pcall(fn, ...)
        if not ok then
            ok = pcall(fn, targetCharacter, ...)
        end

        return ok
    end

    local function try(method, ...)
        return tryOn(character, method, ...)
    end

    local function setField(field, value)
        pcall(function()
            character[field] = value
        end)
    end

    local grade = configuredJobGrade(job)
    local jobLabel = configuredJobLabel(job)
    local jobName = tostring(job.job)
    local oldJob = character.job
    local oldGrade = character.jobGrade or character.jobgrade or character.grade
    local jobSetterRan = false
    local gradeSetterRan = false

    jobSetterRan = try('setJob', jobName) or try('setJob', jobName, true) or jobSetterRan
    jobSetterRan = try('SetJob', jobName) or try('SetJob', jobName, true) or jobSetterRan
    jobSetterRan = try('setjob', jobName) or try('setjob', jobName, true) or jobSetterRan
    try('setJobLabel', jobLabel)
    try('setJoblabel', jobLabel)
    try('setJobLable', jobLabel)
    try('setJoblable', jobLabel)
    try('SetJobLabel', jobLabel)
    gradeSetterRan = try('setJobGrade', grade) or try('setJobGrade', grade, true) or gradeSetterRan
    gradeSetterRan = try('setJobgrade', grade) or try('setJobgrade', grade, true) or gradeSetterRan
    gradeSetterRan = try('SetJobGrade', grade) or try('SetJobGrade', grade, true) or gradeSetterRan

    setField('job', jobName)
    setField('jobLabel', jobLabel)
    setField('joblabel', jobLabel)
    setField('jobLable', jobLabel)
    setField('joblable', jobLabel)
    setField('jobGrade', grade)
    setField('jobgrade', grade)
    setField('grade', grade)

    local freshUser = getCoreUserByCharId(charid)
    local freshCharacter = usedCharacter(freshUser)
    if freshCharacter and freshCharacter ~= character then
        tryOn(freshCharacter, 'setJob', jobName)
        tryOn(freshCharacter, 'setJobLabel', jobLabel)
        tryOn(freshCharacter, 'setJoblabel', jobLabel)
        tryOn(freshCharacter, 'setJobLable', jobLabel)
        tryOn(freshCharacter, 'setJoblable', jobLabel)
        tryOn(freshCharacter, 'setJobGrade', grade)
        tryOn(freshCharacter, 'setJobgrade', grade)
        pcall(function() freshCharacter.job = jobName end)
        pcall(function() freshCharacter.jobLabel = jobLabel end)
        pcall(function() freshCharacter.joblabel = jobLabel end)
        pcall(function() freshCharacter.jobLable = jobLabel end)
        pcall(function() freshCharacter.joblable = jobLabel end)
        pcall(function() freshCharacter.jobGrade = grade end)
        pcall(function() freshCharacter.jobgrade = grade end)
        pcall(function() freshCharacter.grade = grade end)
    end

    targetSource = tonumber(freshUser and freshUser.source) or targetSource
    refreshOnlineJobState(targetSource, job)

    if not jobSetterRan and tostring(oldJob or '') ~= jobName then
        TriggerEvent('vorp:playerJobChange', targetSource, jobName, oldJob)
    end
    if not gradeSetterRan and tonumber(oldGrade) ~= grade then
        TriggerEvent('vorp:playerJobGradeChange', targetSource, grade, oldGrade)
    end

    return true
end

RegisterNetEvent(RESOURCE .. ':server:setActiveTown', function(townKey)
    local source = source
    setActiveTown(source, townKey)
end)

AddEventHandler('playerDropped', function()
    local droppedSource = source
    local info = characterInfo(droppedSource)
    local saved = info and assignedJobByCharId[info.charid] or assignedJobBySource[droppedSource]
    if saved then
        local charid = saved.charid
        local identifier = info and info.identifier or saved.identifier
        persistRememberedJob(charid, identifier)
        CreateThread(function()
            Wait(2500)
            persistRememberedJob(charid, identifier)
            Wait(5000)
            persistRememberedJob(charid, identifier)
            Wait(7500)
            persistRememberedJob(charid, identifier)
            Wait(15000)
            persistRememberedJob(charid, identifier)
        end)
    end

    assignedJobBySource[droppedSource] = nil
    activeTownBySource[droppedSource] = nil
end)

local function hasActiveCitizenship(townId, charid)
    local citizenship = BMDB.citizenship(townId, charid)
    return citizenship and citizenship.status == 'active'
end

local function marketCatalog()
    local itemMap = {}
    local categories = {}
    local categoryConfig = Config.Market.Categories or {}
    local seen = {}

    local function addCategory(categoryKey, category)
        if type(category) ~= 'table' then
            return
        end

        categoryKey = tostring(categoryKey)
        if seen[categoryKey] then
            return
        end

        seen[categoryKey] = true
        categories[#categories + 1] = {
            key = categoryKey,
            label = category.label or categoryKey
        }

        for key, item in pairs(category.items or {}) do
            local itemConfig = type(item) == 'table' and item or { label = tostring(item) }
            local itemName = itemConfig.name or (type(key) == 'string' and key or nil)
            if itemName then
                itemName = tostring(itemName)
                itemMap[itemName] = {
                    name = itemName,
                    label = itemConfig.label or itemName,
                    category = categoryKey,
                    categoryLabel = category.label or categoryKey,
                    minAmount = tonumber(itemConfig.minAmount) or Config.Market.MinAmount,
                    maxAmount = tonumber(itemConfig.maxAmount) or Config.Market.MaxAmount,
                    minPrice = tonumber(itemConfig.minPrice) or Config.Market.MinPrice,
                    maxPrice = tonumber(itemConfig.maxPrice) or Config.Market.MaxPrice,
                    buyPrice = tonumber(itemConfig.buyPrice) or tonumber(itemConfig.minPrice) or Config.Market.MinPrice,
                    sellPrice = tonumber(itemConfig.sellPrice) or tonumber(itemConfig.buyPrice) or Config.Market.MinPrice,
                    initialStock = tonumber(itemConfig.initialStock) or 0,
                    enabled = itemConfig.enabled ~= false
                }
            end
        end
    end

    for _, categoryKey in ipairs(Config.Market.CategoryOrder or {}) do
        addCategory(categoryKey, categoryConfig[categoryKey])
    end

    for categoryKey, category in pairs(categoryConfig) do
        addCategory(categoryKey, category)
    end

    return itemMap, categories
end

local function marketCategory(categoryKey)
    if not categoryKey or categoryKey == '' then
        return nil
    end

    categoryKey = tostring(categoryKey)
    local _, categories = marketCatalog()
    for _, category in ipairs(categories) do
        if category.key == categoryKey then
            return category
        end
    end

    return nil
end

local function marketItemConfig(itemName, categoryKey)
    if not itemName then
        return nil
    end

    local items = marketCatalog()
    local item = items[tostring(itemName)]
    if not item then
        return nil
    end

    if categoryKey and categoryKey ~= '' and item.category ~= tostring(categoryKey) then
        return nil
    end

    return item
end

local function useConfigMarketPrices()
    return (Config.Market or {}).UseConfigPrices ~= false
end

local function dbEnabled(value)
    if value == false or value == 0 then
        return false
    end

    if type(value) == 'string' then
        local normalized = trim(value):lower()
        return not (normalized == '0' or normalized == 'false')
    end

    return true
end

local function inputEnabled(value)
    if value == true or value == 1 then
        return true
    end

    if type(value) == 'string' then
        local normalized = trim(value):lower()
        return normalized == '1' or normalized == 'true'
    end

    return false
end

local function syncMarketStock(town)
    town = town or getTown()
    local items = marketCatalog()
    local priceUpdate = ''
    if useConfigMarketPrices() then
        priceUpdate = [[
                    buy_price = VALUES(buy_price),
                    sell_price = VALUES(sell_price),]]
    end

    for _, item in pairs(items) do
        MySQL.insert.await(
            ([[
                INSERT INTO bm_market_stock
                    (town_id, category, item_name, item_label, stock, enabled, buy_price, sell_price, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE
                    category = VALUES(category),
                    item_label = VALUES(item_label),
%s
                    updated_at = VALUES(updated_at)
            ]]):format(priceUpdate),
            {
                town.id,
                item.category,
                item.name,
                item.label,
                math.floor(item.initialStock),
                1,
                roundMoney(item.buyPrice),
                roundMoney(item.sellPrice),
                now()
            }
        )
    end
end

local function marketStockRows(townId)
    local rows = MySQL.query.await(
        [[
            SELECT category, item_name, item_label, stock, enabled, buy_price, sell_price
            FROM bm_market_stock
            WHERE town_id = ?
            ORDER BY category ASC, item_label ASC
        ]],
        { townId }
    ) or {}

    local normalized = {}
    for _, row in ipairs(rows) do
        local configured = marketItemConfig(row.item_name)
        if configured then
            normalized[#normalized + 1] = {
                category = configured.category,
                categoryLabel = configured.categoryLabel,
                itemName = row.item_name,
                itemLabel = configured.label or row.item_label,
                stock = tonumber(row.stock) or 0,
                enabled = dbEnabled(row.enabled),
                buyPrice = useConfigMarketPrices() and roundMoney(configured.buyPrice) or (tonumber(row.buy_price) or 0),
                sellPrice = useConfigMarketPrices() and roundMoney(configured.sellPrice) or (tonumber(row.sell_price) or 0),
                minPrice = configured.minPrice,
                maxPrice = configured.maxPrice
            }
        end
    end

    return normalized
end

local function stockRowForItem(town, itemName)
    if not town or not itemName then
        return nil
    end

    syncMarketStock(town)
    local rows = MySQL.query.await(
        'SELECT * FROM bm_market_stock WHERE town_id = ? AND item_name = ? LIMIT 1',
        { town.id, tostring(itemName) }
    )

    return rows and rows[1] or nil
end

local function marketItemEnabled(town, itemName)
    local row = stockRowForItem(town, itemName)
    return row and dbEnabled(row.enabled)
end

local function marketEnabledMap(town)
    if not town then
        return {}
    end

    syncMarketStock(town)
    local rows = MySQL.query.await('SELECT item_name, enabled FROM bm_market_stock WHERE town_id = ?', { town.id }) or {}
    local map = {}
    for _, row in ipairs(rows) do
        map[tostring(row.item_name)] = dbEnabled(row.enabled)
    end

    return map
end

local function marketExportPercent()
    local percent = tonumber((Config.Market or {}).ExportPercent) or 5.0
    if percent < 0 then
        percent = 0
    end

    return percent
end

local function townTaxRates(town)
    local buyRate = tonumber(town and town.tax_buy_rate) or tonumber(town and town.tax_rate) or Config.Town.DefaultBuyTaxRate
    local sellRate = tonumber(town and town.tax_sell_rate) or (buyRate + Config.Town.MinSellTaxSpread)

    buyRate = math.max(buyRate, Config.Town.MinTaxRate)
    sellRate = math.max(sellRate, buyRate + Config.Town.MinSellTaxSpread, Config.Town.MinTaxRate)

    return roundMoney(buyRate), roundMoney(sellRate)
end

local function validateTaxRates(buyRate, sellRate)
    buyRate = roundMoney(buyRate)
    sellRate = roundMoney(sellRate)

    if buyRate < Config.Town.MinTaxRate or sellRate < Config.Town.MinTaxRate then
        return false, ('Beide Steuersaetze muessen mindestens %.2f%% betragen.'):format(Config.Town.MinTaxRate)
    end

    if buyRate > Config.Town.MaxTaxRate or sellRate > Config.Town.MaxTaxRate then
        return false, ('Beide Steuersaetze duerfen maximal %.2f%% betragen.'):format(Config.Town.MaxTaxRate)
    end

    if sellRate < buyRate + Config.Town.MinSellTaxSpread then
        return false, ('Verkaufsteuer muss mindestens %.2f Prozentpunkt hoeher sein als Einkaufsteuer.'):format(Config.Town.MinSellTaxSpread)
    end

    return true, nil, buyRate, sellRate
end

local function defaultCategoryTaxRates(categoryKey)
    local categoryTaxes = Config.Market.CategoryTaxes or {}
    local configured = categoryTaxes[tostring(categoryKey or '')] or {}
    local buyRate = configured.buyRate or Config.Town.DefaultBuyTaxRate
    local sellRate = configured.sellRate or Config.Town.DefaultSellTaxRate
    local ok, _, normalizedBuy, normalizedSell = validateTaxRates(buyRate, sellRate)

    if ok then
        return normalizedBuy, normalizedSell
    end

    buyRate = math.max(Config.Town.DefaultBuyTaxRate, Config.Town.MinTaxRate)
    sellRate = math.max(Config.Town.DefaultSellTaxRate, buyRate + Config.Town.MinSellTaxSpread)
    return roundMoney(buyRate), roundMoney(sellRate)
end

local function syncMarketTaxes(town)
    town = town or getTown()
    local _, categories = marketCatalog()

    for _, category in ipairs(categories) do
        local buyRate, sellRate = defaultCategoryTaxRates(category.key)
        MySQL.insert.await(
            [[
                INSERT INTO bm_market_taxes
                    (town_id, category, category_label, buy_tax_rate, sell_tax_rate, updated_at)
                VALUES (?, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE
                    category_label = VALUES(category_label)
            ]],
            {
                town.id,
                category.key,
                category.label,
                buyRate,
                sellRate,
                now()
            }
        )
    end
end

local function marketCategoryTaxMap(town)
    town = town or getTown()
    syncMarketTaxes(town)

    local rows = MySQL.query.await(
        'SELECT category, category_label, buy_tax_rate, sell_tax_rate FROM bm_market_taxes WHERE town_id = ?',
        { town.id }
    ) or {}

    local map = {}
    for _, row in ipairs(rows) do
        local categoryKey = tostring(row.category or '')
        local buyRate = tonumber(row.buy_tax_rate)
        local sellRate = tonumber(row.sell_tax_rate)
        local ok, _, normalizedBuy, normalizedSell = validateTaxRates(buyRate, sellRate)
        if not ok then
            normalizedBuy, normalizedSell = defaultCategoryTaxRates(categoryKey)
        end

        map[categoryKey] = {
            category = categoryKey,
            label = row.category_label or categoryKey,
            buyRate = normalizedBuy,
            sellRate = normalizedSell
        }
    end

    local _, categories = marketCatalog()
    for _, category in ipairs(categories) do
        if not map[category.key] then
            local buyRate, sellRate = defaultCategoryTaxRates(category.key)
            map[category.key] = {
                category = category.key,
                label = category.label,
                buyRate = buyRate,
                sellRate = sellRate
            }
        end
    end

    return map
end

local function marketCategoryTaxRates(town, categoryKey)
    local map = marketCategoryTaxMap(town)
    local rates = map[tostring(categoryKey or '')]
    if rates then
        return rates.buyRate, rates.sellRate
    end

    return townTaxRates(town)
end

local function setAllMarketCategoryTaxes(town, buyRate, sellRate)
    local _, categories = marketCatalog()

    for _, category in ipairs(categories) do
        MySQL.insert.await(
            [[
                INSERT INTO bm_market_taxes
                    (town_id, category, category_label, buy_tax_rate, sell_tax_rate, updated_at)
                VALUES (?, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE
                    category_label = VALUES(category_label),
                    buy_tax_rate = VALUES(buy_tax_rate),
                    sell_tax_rate = VALUES(sell_tax_rate),
                    updated_at = VALUES(updated_at)
            ]],
            { town.id, category.key, category.label, buyRate, sellRate, now() }
        )
    end
end

local function electionPhase(election)
    if not election then
        return 'none', 0
    end

    local ts = now()
    local nominationEndsAt = tonumber(election.nomination_ends_at) or 0
    local votingEndsAt = tonumber(election.voting_ends_at) or 0

    if ts < nominationEndsAt then
        return 'nomination', nominationEndsAt - ts
    end

    if ts < votingEndsAt then
        return 'voting', votingEndsAt - ts
    end

    return 'finished', 0
end

local function ledgerEntryLabel(entryType)
    local labels = {
        market_buy_tax = 'Kauft im Markt inkl. Steuer',
        market_sell_tax = 'Verkauft an den Markt abzgl. Steuer',
        sales_tax = 'Kauft Spielerangebot inkl. Steuer',
        listing_fee = 'Markthallen-Einstellgebuehr',
        market_price_change = 'Marktpreis geaendert',
        market_export = 'Lagerbestand exportiert',
        market_withdraw = 'Aus Markthallenlager entnommen',
        market_item_toggle = 'Marktware umgeschaltet',
        tax_change = 'Steuern geaendert',
        admin_tax_change = 'Admin setzt Steuern',
        citizen_apply = 'Bürgerantrag gestellt',
        citizen_approved = 'Bürger bestaetigt',
        citizen_removed = 'Bürger entfernt',
        citizen_job = 'Bürger-Job gesetzt',
        election_start = 'Wahl gestartet',
        election_result = 'Wahlergebnis',
        election_failed = 'Wahl geschlossen',
        election_tie = 'Wahl Gleichstand',
        announcement = 'Bekanntmachung',
        grant = 'Auszahlung aus Stadtkasse',
        listing_removed = 'Marktangebot entfernt',
        listing_price_change = 'Angebotspreis geaendert'
    }

    return labels[tostring(entryType or '')] or tostring(entryType or 'Buchung')
end

local function normalizeLedgerRows(rows)
    for _, row in ipairs(rows or {}) do
        row.amount = tonumber(row.amount) or 0
        row.entryLabel = ledgerEntryLabel(row.entry_type)
    end

    return rows or {}
end

local function addLedger(townId, entryType, amount, actor, note)
    MySQL.insert.await(
        'INSERT INTO bm_ledger (town_id, entry_type, amount, actor_charid, actor_name, note, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
        {
            townId,
            entryType,
            roundMoney(amount),
            actor and actor.charid or nil,
            actor and actor.name or nil,
            tostring(note or ''),
            now()
        }
    )
end

local function addTreasury(townId, amount, entryType, actor, note)
    amount = roundMoney(amount)
    if amount <= 0 then
        return true
    end

    local updated = MySQL.update.await(
        'UPDATE bm_towns SET treasury = treasury + ? WHERE id = ?',
        { amount, townId }
    )

    if (tonumber(updated) or 0) < 1 then
        return false
    end

    addLedger(townId, entryType, amount, actor, note)
    return true
end

local function spendTreasury(townId, amount, entryType, actor, note)
    amount = roundMoney(amount)
    if amount <= 0 then
        return false, 'Ungueltiger Betrag.'
    end

    local updated = MySQL.update.await(
        'UPDATE bm_towns SET treasury = treasury - ? WHERE id = ? AND treasury >= ?',
        { amount, townId, amount }
    )

    if (tonumber(updated) or 0) < 1 then
        return false, 'Die Stadtkasse hat nicht genug Geld.'
    end

    addLedger(townId, entryType, -amount, actor, note)
    return true
end

local function awaitVorpInventory(register)
    local pending = promise.new()

    register(function(result)
        pending:resolve(result)
    end)

    return Citizen.Await(pending)
end

local function isTrue(value)
    return value == true or (type(value) == 'number' and value > 0)
end

local function isWeaponName(itemName)
    return tostring(itemName or ''):upper():find('^WEAPON_') ~= nil
end

local function getItemCount(source, itemName)
    return tonumber(awaitVorpInventory(function(done)
        exports.vorp_inventory:getItemCount(source, done, itemName, nil, nil)
    end)) or 0
end

local function getWeaponRows(source)
    return awaitVorpInventory(function(done)
        exports.vorp_inventory:getUserInventoryWeapons(source, done)
    end) or {}
end

local function getWeaponCount(source, weaponName)
    local count = 0
    for _, weapon in pairs(getWeaponRows(source)) do
        if tostring(weapon.name or '') == tostring(weaponName) then
            count = count + 1
        end
    end

    return count
end

local function safeItemCount(source, itemName)
    local getter = isWeaponName(itemName) and getWeaponCount or getItemCount
    local ok, count = pcall(getter, source, itemName)
    if not ok then
        debugLog(('Inventarbestand fuer %s konnte nicht gelesen werden: %s'):format(tostring(itemName), count))
        return 0
    end

    return tonumber(count) or 0
end

local function canCarryItem(source, itemName, amount)
    return isTrue(awaitVorpInventory(function(done)
        exports.vorp_inventory:canCarryItem(source, itemName, amount, done)
    end))
end

local function addItem(source, itemName, amount)
    return isTrue(awaitVorpInventory(function(done)
        exports.vorp_inventory:addItem(source, itemName, amount, {}, done, nil)
    end))
end

local function removeItem(source, itemName, amount)
    return isTrue(awaitVorpInventory(function(done)
        exports.vorp_inventory:subItem(source, itemName, amount, {}, done, nil)
    end))
end

local function canCarryMarketItem(source, itemName, amount)
    if isWeaponName(itemName) then
        return isTrue(awaitVorpInventory(function(done)
            exports.vorp_inventory:canCarryWeapons(source, amount, done, itemName)
        end))
    end

    return canCarryItem(source, itemName, amount)
end

local function addMarketItem(source, itemName, amount)
    if not isWeaponName(itemName) then
        return addItem(source, itemName, amount)
    end

    for _ = 1, amount do
        local created = awaitVorpInventory(function(done)
            exports.vorp_inventory:createWeapon(source, itemName, 0, {}, {}, done)
        end)
        if not isTrue(created) then
            return false
        end
    end

    return true
end

local function removeMarketItem(source, itemName, amount)
    if not isWeaponName(itemName) then
        return removeItem(source, itemName, amount)
    end

    local weapons = {}
    for _, weapon in pairs(getWeaponRows(source)) do
        if tostring(weapon.name or '') == tostring(itemName) then
            weapons[#weapons + 1] = weapon
        end
    end

    if #weapons < amount then
        return false
    end

    for index = 1, amount do
        local removed = awaitVorpInventory(function(done)
            exports.vorp_inventory:subWeapon(source, weapons[index].id, done)
        end)
        if not isTrue(removed) then
            return false
        end
    end

    return true
end

local function getItemLabel(itemName)
    local item = awaitVorpInventory(function(done)
        exports.vorp_inventory:getItemDB(itemName, done)
    end)

    return item and (item.label or item.name) or itemName
end

local function payCharacter(character, amount)
    amount = roundMoney(amount)
    if amount <= 0 then
        return false
    end

    character.addCurrency(0, amount)
    return true
end

local function removeMoney(character, amount)
    amount = roundMoney(amount)
    if amount <= 0 then
        return false
    end

    if (tonumber(character.money) or 0) < amount then
        return false
    end

    character.removeCurrency(0, amount)
    return true
end

local function getOnlineUserByCharId(charid)
    return getCoreUserByCharId(charid)
end

local function createPayout(charid, name, amount, reason)
    amount = roundMoney(amount)
    if amount <= 0 then
        return nil
    end

    return MySQL.insert.await(
        'INSERT INTO bm_payouts (charid, name, amount, reason, status, created_at) VALUES (?, ?, ?, ?, ?, ?)',
        { tostring(charid), tostring(name), amount, tostring(reason), 'pending', now() }
    )
end

local function createItemReturn(charid, name, itemName, itemLabel, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then
        return nil
    end

    return MySQL.insert.await(
        'INSERT INTO bm_item_returns (charid, name, item_name, item_label, amount, reason, status, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        { tostring(charid), tostring(name), tostring(itemName), tostring(itemLabel), amount, tostring(reason), 'pending', now() }
    )
end

local function claimPayoutsForChar(charid)
    local rows = MySQL.query.await(
        'SELECT * FROM bm_payouts WHERE charid = ? AND status = ? ORDER BY id ASC',
        { tostring(charid), 'pending' }
    ) or {}

    if #rows == 0 then
        return 0
    end

    local total = 0
    local ids = {}
    for _, row in ipairs(rows) do
        total = total + (tonumber(row.amount) or 0)
        ids[#ids + 1] = row.id
    end

    total = roundMoney(total)
    if total <= 0 then
        return 0
    end

    local user = getOnlineUserByCharId(charid)
    if not user then
        return 0
    end

    local character = usedCharacter(user)
    if not character then
        return 0
    end

    payCharacter(character, total)

    local placeholders = {}
    local params = { 'paid', now() }
    for _, id in ipairs(ids) do
        placeholders[#placeholders + 1] = '?'
        params[#params + 1] = id
    end

    MySQL.update.await(
        ('UPDATE bm_payouts SET status = ?, paid_at = ? WHERE id IN (%s)'):format(table.concat(placeholders, ',')),
        params
    )

    return total
end

local function claimItemReturnsForSource(source, charid)
    local rows = MySQL.query.await(
        'SELECT * FROM bm_item_returns WHERE charid = ? AND status = ? ORDER BY id ASC',
        { tostring(charid), 'pending' }
    ) or {}

    if #rows == 0 then
        return 0, 'Keine offenen Warenrueckgaben.'
    end

    local claimed = 0
    for _, row in ipairs(rows) do
        local amount = tonumber(row.amount) or 0
        if amount > 0 and canCarryItem(source, row.item_name, amount) and addItem(source, row.item_name, amount) then
            MySQL.update.await(
                'UPDATE bm_item_returns SET status = ?, claimed_at = ? WHERE id = ? AND status = ?',
                { 'claimed', now(), row.id, 'pending' }
            )
            claimed = claimed + amount
        else
            return claimed, ('Nicht genug Platz fuer %sx %s.'):format(amount, row.item_label)
        end
    end

    return claimed, ('Warenrueckgaben abgeholt: %s Items.'):format(claimed)
end

local function normalizeManifesto(value)
    value = trim(value)
    if #value > 240 then
        value = value:sub(1, 240)
    end

    return value
end

local function candidateVoteRows(electionId)
    return MySQL.query.await(
        [[
            SELECT c.id, c.charid, c.name, c.manifesto, c.created_at, COUNT(v.id) AS votes
            FROM bm_candidates c
            LEFT JOIN bm_votes v ON v.candidate_id = c.id
            WHERE c.election_id = ?
            GROUP BY c.id
            ORDER BY votes DESC, c.created_at ASC
        ]],
        { electionId }
    ) or {}
end

local function activeCitizenCharIds(townId)
    local rows = MySQL.query.await(
        'SELECT charid FROM bm_citizens WHERE town_id = ? AND status = ?',
        { townId, 'active' }
    ) or {}

    local charids = {}
    for _, row in ipairs(rows) do
        charids[#charids + 1] = tostring(row.charid)
    end

    return charids
end

local function notifyTownCitizens(town, message)
    if not town or not town.id then
        return 0
    end

    local sent = 0
    for _, charid in ipairs(activeCitizenCharIds(town.id)) do
        local targetSource = findSourceByCharId(charid)
        if targetSource then
            notify(targetSource, message)
            sent = sent + 1
        end
    end

    return sent
end

local function electionReminderMessage(town, election)
    local phase, remaining = electionPhase(election)
    if phase == 'nomination' then
        return ('Rathaus %s: Die Kandidaturphase ist aktiv. Bürger dieser Stadt können sich aktuell zur Bürgermeisterwahl aufstellen lassen. Restzeit: %s.'):format(town.name, secondsText(remaining))
    end

    if phase == 'voting' then
        return ('Rathaus %s: Die Bürgermeisterwahl ist aktiv. Bürger dieser Stadt können jetzt ihre Stimme abgeben. Restzeit: %s.'):format(town.name, secondsText(remaining))
    end

    return nil
end

local function sendElectionReminder(town, election, force)
    local reminder = Config.ElectionReminder or {}
    if reminder.Enabled == false or not town or not election then
        return
    end

    local message = electionReminderMessage(town, election)
    if not message then
        return
    end

    local interval = math.max(1, tonumber(reminder.IntervalMinutes) or 60) * 60
    local key = tostring(election.id)
    local ts = now()
    if not force and electionReminderSent[key] and (ts - electionReminderSent[key]) < interval then
        return
    end

    electionReminderSent[key] = ts
    notifyTownCitizens(town, message)
end

local function finishElection(electionId, closer)
    local rows = MySQL.query.await(
        'SELECT e.*, t.id AS town_id, t.name AS town_name FROM bm_elections e JOIN bm_towns t ON t.id = e.town_id WHERE e.id = ? AND e.status = ? LIMIT 1',
        { electionId, 'active' }
    )
    local election = rows and rows[1]
    if not election then
        return false, 'Keine aktive Wahl gefunden.'
    end

    local candidates = candidateVoteRows(election.id)
    if #candidates < Config.Election.MinCandidates then
        MySQL.update.await(
            'UPDATE bm_elections SET status = ?, closed_at = ? WHERE id = ?',
            { 'closed', now(), election.id }
        )
        addLedger(election.town_id, 'election_failed', 0, closer, 'Wahl ohne genug Kandidaten geschlossen.')
        sendDiscord('electionResult', 'Wahl geschlossen', ('Die Wahl in %s wurde ohne genug Kandidaten geschlossen.'):format(election.town_name or 'der Stadt'), {
            { name = 'Stadt', value = election.town_name or 'unbekannt', inline = true }
        })
        return true, 'Wahl geschlossen: nicht genug Kandidaten.'
    end

    local winner = candidates[1]
    local tie = false
    if candidates[2] and tonumber(candidates[2].votes) == tonumber(winner.votes) then
        tie = true
    end

    if tie and Config.Election.TieKeepsCurrentMayor then
        MySQL.update.await(
            'UPDATE bm_elections SET status = ?, closed_at = ? WHERE id = ?',
            { 'closed', now(), election.id }
        )
        addLedger(election.town_id, 'election_tie', 0, closer, 'Wahl endete im Gleichstand.')
        sendDiscord('electionResult', 'Wahl Gleichstand', ('Die Wahl in %s endete im Gleichstand.'):format(election.town_name or 'der Stadt'), {
            { name = 'Stadt', value = election.town_name or 'unbekannt', inline = true }
        })
        return true, 'Wahl geschlossen: Gleichstand, Amt bleibt unveraendert.'
    end

    local termStart = now()
    local termEnd = termStart + (Config.Town.TermDays * 86400)

    MySQL.update.await(
        'UPDATE bm_towns SET mayor_charid = ?, mayor_name = ?, term_started_at = ?, term_ends_at = ? WHERE id = ?',
        { winner.charid, winner.name, termStart, termEnd, election.town_id }
    )
    MySQL.update.await(
        'UPDATE bm_elections SET status = ?, winner_charid = ?, winner_name = ?, closed_at = ? WHERE id = ?',
        { 'closed', winner.charid, winner.name, now(), election.id }
    )
    addLedger(
        election.town_id,
        'election_result',
        0,
        closer,
        ('%s gewinnt mit %s Stimmen.'):format(winner.name, tostring(winner.votes))
    )

    notifyTownCitizens({ id = election.town_id, name = election.town_name or 'der Stadt' }, ('%s ist neuer Bürgermeister von %s.'):format(winner.name, election.town_name or 'der Stadt'))
    sendDiscord('electionResult', 'Bürgermeister gewählt', ('%s ist neuer Bürgermeister von %s.'):format(winner.name, election.town_name or 'der Stadt'), {
        { name = 'Stadt', value = election.town_name or 'unbekannt', inline = true },
        { name = 'Gewinner', value = winner.name, inline = true },
        { name = 'Stimmen', value = tostring(winner.votes or 0), inline = true }
    })
    return true, ('%s wurde gewaehlt.'):format(winner.name)
end

local function ensureStarted()
    if started then
        return true
    end

    notify(0, 'Resource ist noch nicht bereit.')
    return false
end

local function callback(name, handler)
    Core.Callback.Register(RESOURCE .. ':' .. name, function(source, cb, ...)
        if not started then
            cb({ ok = false, message = 'Bürgermeistersystem wird noch geladen.' })
            return
        end

        local args = { ... }
        if type(args[1]) == 'string' and BMDB.isTownKey(args[1]) then
            setActiveTown(source, args[1])
            table.remove(args, 1)
        end

        local ok, result = pcall(handler, source, table.unpack(args))
        if not ok then
            print(('[%s] Callback %s failed: %s'):format(RESOURCE, name, result))
            cb({ ok = false, message = Config.Text.InternalError })
            return
        end

        cb(result)
    end)
end

callback('getDashboard', function(source)
    local town = getTown(source)
    local election = BMDB.activeElection(town.id)
    local phase, remaining = electionPhase(election)
    if phase == 'finished' and election then
        finishElection(election.id, nil)
        election = nil
        phase = 'none'
        remaining = 0
        town = getTown(source)
    end

    local info = characterInfo(source)
    local pending = info and BMDB.pendingPayoutTotal(info.charid) or 0
    local pendingItems = info and BMDB.pendingItemReturnCount(info.charid) or 0
    local citizenship = info and BMDB.citizenship(town.id, info.charid) or nil
    local citizenCounts = BMDB.citizenCounts(town.id)
    local taxBuyRate, taxSellRate = townTaxRates(town)
    local categoryTaxes = marketCategoryTaxMap(town)

    return {
        ok = true,
        town = {
            key = town.key,
            name = town.name,
            treasury = tonumber(town.treasury) or 0,
            taxRate = taxBuyRate,
            taxBuyRate = taxBuyRate,
            taxSellRate = taxSellRate,
            mayorName = town.mayor_name,
            termEndsAt = tonumber(town.term_ends_at) or nil,
            citizens = citizenCounts
        },
        categoryTaxes = categoryTaxes,
        election = election and {
            id = election.id,
            phase = phase,
            remaining = remaining,
            nominationEndsAt = tonumber(election.nomination_ends_at),
            votingEndsAt = tonumber(election.voting_ends_at)
        } or nil,
        player = {
            isMayor = info and isMayor(source, town) or false,
            isAdmin = isAdmin(source),
            canUseOffice = canUseOffice(source, town),
            pendingPayout = pending,
            pendingItemReturns = pendingItems,
            citizenship = citizenship and citizenship.status or nil
        }
    }
end)

callback('getElectionCandidates', function(source)
    local town = getTown(source)
    local election = BMDB.activeElection(town.id)
    if not election then
        return { ok = true, phase = 'none', candidates = {} }
    end

    local phase, remaining = electionPhase(election)
    return {
        ok = true,
        electionId = election.id,
        phase = phase,
        remaining = remaining,
        candidates = candidateVoteRows(election.id)
    }
end)

callback('getMarketCategories', function()
    local _, categories = marketCatalog()
    return { ok = true, categories = categories }
end)

local function windowLedgerRows(townId, limit)
    local rows = MySQL.query.await(
        [[
            SELECT entry_type, amount, actor_name, note, created_at
            FROM bm_ledger
            WHERE town_id = ?
            ORDER BY id DESC
            LIMIT ?
        ]],
        { townId, limit or 12 }
    ) or {}

    return normalizeLedgerRows(rows)
end

local function normalizeCitizenRows(rows)
    for _, row in ipairs(rows or {}) do
        local dbName = trim(row.name)
        if dbName == '' then
            row.name = row.stored_name or ('Char %s'):format(tostring(row.charid or 'unknown'))
        end
        row.job = row.job or ''
        row.joblabel = row.joblabel or row.job or ''
        row.jobgrade = tonumber(row.jobgrade) or 0
    end

    return rows or {}
end

local function citizenRegistryRows(townId)
    local columns = characterColumns()
    local jobSelect = characterSelectColumn(columns, { 'job' }, 'job', "''")
    local jobLabelSelect = characterSelectColumn(columns, { 'joblable', 'joblabel', 'jobLabel', 'job_label' }, 'joblabel', "''")
    local jobGradeSelect = characterSelectColumn(columns, { 'jobgrade', 'jobGrade', 'job_grade', 'grade' }, 'jobgrade', '0')

    local ok, rows = pcall(MySQL.query.await,
        ([[
            SELECT
                c.id,
                c.charid,
                c.identifier,
                COALESCE(NULLIF(TRIM(CONCAT(COALESCE(ch.firstname, ''), ' ', COALESCE(ch.lastname, ''))), ''), c.name) AS name,
                c.name AS stored_name,
                c.status,
                c.note,
                c.created_at,
                c.approved_at,
                c.removed_at,
                c.decided_by_name,
                %s,
                %s,
                %s
            FROM bm_citizens c
            LEFT JOIN characters ch
                ON CAST(ch.charidentifier AS CHAR) = c.charid
                AND (c.identifier IS NULL OR c.identifier = '' OR ch.identifier = c.identifier)
            WHERE c.town_id = ? AND c.status IN ('pending', 'active')
            ORDER BY
                CASE WHEN c.status = 'pending' THEN 0 ELSE 1 END,
                name ASC
            LIMIT ?
        ]]):format(jobSelect, jobLabelSelect, jobGradeSelect),
        { townId, Config.Citizenship.MaxRegistryRows }
    )

    if ok then
        return normalizeCitizenRows(rows)
    end

    debugLog(('Bürgerregister konnte nicht mit characters Join geladen werden: %s'):format(rows))
    rows = MySQL.query.await(
        [[
            SELECT id, charid, identifier, name, name AS stored_name, status, note, created_at, approved_at, removed_at, decided_by_name, '' AS job, '' AS joblabel, 0 AS jobgrade
            FROM bm_citizens
            WHERE town_id = ? AND status IN ('pending', 'active')
            ORDER BY
                CASE WHEN status = 'pending' THEN 0 ELSE 1 END,
                name ASC
            LIMIT ?
        ]],
        { townId, Config.Citizenship.MaxRegistryRows }
    ) or {}

    return normalizeCitizenRows(rows)
end

local function windowCitizenRegistry(townId)
    local rows = citizenRegistryRows(townId)

    return {
        counts = BMDB.citizenCounts(townId),
        citizens = rows
    }
end

local function buildMarketWindowData(source, mode)
    local town = getTown(source)
    local _, categories = marketCatalog()
    syncMarketStock(town)
    syncMarketTaxes(town)
    town = getTown(source)
    local items = marketStockRows(town.id)
    if #items == 0 then
        syncMarketStock(town)
        town = getTown(source)
        items = marketStockRows(town.id)
    end

    local categoryTaxes = marketCategoryTaxMap(town)
    for _, category in ipairs(categories) do
        local rates = categoryTaxes[category.key]
        if rates then
            category.taxBuyRate = rates.buyRate
            category.taxSellRate = rates.sellRate
        end
    end

    for _, item in ipairs(items) do
        item.playerCount = safeItemCount(source, item.itemName)
        local itemTaxes = categoryTaxes[item.category]
        if itemTaxes then
            item.taxBuyRate = itemTaxes.buyRate
            item.taxSellRate = itemTaxes.sellRate
        end
    end

    local adminMode = mode == 'admin'
    local taxBuyRate, taxSellRate = townTaxRates(town)
    local info = characterInfo(source)
    local admin = isAdmin(source)
    local officeAccess = canUseOffice(source, town)
    local citizenship = info and BMDB.citizenship(town.id, info.charid) or nil
    local citizenCounts = BMDB.citizenCounts(town.id)
    local pending = info and BMDB.pendingPayoutTotal(info.charid) or 0
    local pendingItems = info and BMDB.pendingItemReturnCount(info.charid) or 0
    local election = BMDB.activeElection(town.id)
    local phase, remaining = electionPhase(election)

    if phase == 'finished' and election then
        finishElection(election.id, nil)
        town = getTown(source)
        election = nil
        phase = 'none'
        remaining = 0
    end

    local office = nil
    if officeAccess then
        local registry = windowCitizenRegistry(town.id)
        office = {
            counts = registry.counts,
            citizens = registry.citizens,
            ledger = windowLedgerRows(town.id, 12),
            jobs = configuredMayorJobs(town)
        }
    end

    return {
        ok = true,
        mode = adminMode and 'admin' or 'market',
        town = {
            key = town.key,
            name = town.name,
            taxRate = taxBuyRate,
            taxBuyRate = taxBuyRate,
            taxSellRate = taxSellRate,
            treasury = tonumber(town.treasury) or 0,
            mayorName = town.mayor_name,
            termEndsAt = tonumber(town.term_ends_at) or nil,
            citizens = citizenCounts
        },
        election = {
            id = election and election.id or nil,
            phase = election and phase or 'none',
            remaining = election and remaining or 0,
            nominationEndsAt = election and tonumber(election.nomination_ends_at) or nil,
            votingEndsAt = election and tonumber(election.voting_ends_at) or nil,
            candidates = election and candidateVoteRows(election.id) or {}
        },
        office = office,
        categoryTaxes = categoryTaxes,
        categories = categories,
        items = items,
        market = {
            useConfigPrices = useConfigMarketPrices(),
            exportPercent = marketExportPercent()
        },
        player = {
            canManage = adminMode and admin or false,
            isAdmin = admin,
            isMayor = info and isMayor(source, town) or false,
            canUseOffice = officeAccess,
            pendingPayout = pending,
            pendingItemReturns = pendingItems,
            citizenship = citizenship and citizenship.status or nil
        }
    }
end

callback('getMarketWindow', function(source)
    return buildMarketWindowData(source, 'market')
end)

callback('getMarketAdminWindow', function(source)
    if not isAdmin(source) then
        return { ok = false, message = Config.Text.NoPermission }
    end

    return buildMarketWindowData(source, 'admin')
end)

RegisterNetEvent(RESOURCE .. ':server:requestMarketWindow', function()
    local source = source
    local ok, data = pcall(buildMarketWindowData, source, 'market')
    if not ok then
        print(('[%s] Markthallenfenster konnte nicht gebaut werden: %s'):format(RESOURCE, data))
        notify(source, 'Markthalle konnte nicht geladen werden. Pruefe Server-Konsole.')
        return
    end

    TriggerClientEvent(RESOURCE .. ':client:showMarketWindow', source, data)
end)

callback('marketBuy', function(source, itemName, amount)
    local buyer = characterInfo(source)
    if not buyer then
        return { ok = false, message = 'Charakter nicht geladen.' }
    end

    itemName = trim(itemName)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then
        return { ok = false, message = 'Ungueltige Menge.' }
    end

    local town = getTown(source)
    local configured = marketItemConfig(itemName)
    if not configured then
        return { ok = false, message = 'Ware nicht gefunden.' }
    end

    syncMarketStock(town)
    local rows = MySQL.query.await(
        'SELECT * FROM bm_market_stock WHERE town_id = ? AND item_name = ? LIMIT 1',
        { town.id, itemName }
    )
    local stock = rows and rows[1]
    if not stock then
        return { ok = false, message = 'Ware nicht gefunden.' }
    end

    if not dbEnabled(stock.enabled) then
        return { ok = false, message = 'Diese Ware ist in dieser Stadt aktuell deaktiviert.' }
    end

    local currentStock = tonumber(stock.stock) or 0
    if currentStock < amount then
        return { ok = false, message = 'Nicht genug Bestand in der Markthalle.' }
    end

    if not canCarryMarketItem(source, itemName, amount) then
        return { ok = false, message = 'Du kannst diese Menge nicht tragen.' }
    end

    local unitPrice = useConfigMarketPrices() and configured.buyPrice or (tonumber(stock.buy_price) or 0)
    local subtotal = roundMoney(unitPrice * amount)
    local taxBuyRate = marketCategoryTaxRates(town, configured.category)
    local tax = roundMoney(subtotal * (taxBuyRate / 100))
    local total = roundMoney(subtotal + tax)
    if not removeMoney(buyer.character, total) then
        return { ok = false, message = ('Du brauchst %s.'):format(money(total)) }
    end

    local updated = MySQL.update.await(
        'UPDATE bm_market_stock SET stock = stock - ?, updated_at = ? WHERE town_id = ? AND item_name = ? AND stock >= ?',
        { amount, now(), town.id, itemName, amount }
    )
    if (tonumber(updated) or 0) < 1 then
        payCharacter(buyer.character, total)
        return { ok = false, message = 'Bestand wurde gerade geaendert.' }
    end

    if not addMarketItem(source, itemName, amount) then
        MySQL.update.await(
            'UPDATE bm_market_stock SET stock = stock + ?, updated_at = ? WHERE town_id = ? AND item_name = ?',
            { amount, now(), town.id, itemName }
        )
        payCharacter(buyer.character, total)
        return { ok = false, message = 'Ware konnte nicht uebergeben werden.' }
    end

    if tax > 0 then
        addTreasury(town.id, tax, 'market_buy_tax', buyer, ('Einkaufsteuer %.2f%% aus %sx %s.'):format(taxBuyRate, amount, configured.label))
    end

    return { ok = true, message = ('Gekauft: %sx %s fuer %s inkl. Steuer.'):format(amount, configured.label, money(total)) }
end)

callback('marketSell', function(source, itemName, amount)
    local seller = characterInfo(source)
    if not seller then
        return { ok = false, message = 'Charakter nicht geladen.' }
    end

    itemName = trim(itemName)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then
        return { ok = false, message = 'Ungueltige Menge.' }
    end

    local town = getTown(source)
    local configured = marketItemConfig(itemName)
    if not configured then
        return { ok = false, message = 'Ware nicht gefunden.' }
    end

    syncMarketStock(town)
    local rows = MySQL.query.await(
        'SELECT * FROM bm_market_stock WHERE town_id = ? AND item_name = ? LIMIT 1',
        { town.id, itemName }
    )
    local stock = rows and rows[1]
    if not stock then
        return { ok = false, message = 'Ware nicht gefunden.' }
    end

    if not dbEnabled(stock.enabled) then
        return { ok = false, message = 'Diese Ware ist in dieser Stadt aktuell deaktiviert.' }
    end

    if safeItemCount(source, itemName) < amount then
        return { ok = false, message = 'Du hast nicht genug davon im Inventar.' }
    end

    if not removeMarketItem(source, itemName, amount) then
        return { ok = false, message = 'Ware konnte nicht aus dem Inventar genommen werden.' }
    end

    local updated = MySQL.update.await(
        'UPDATE bm_market_stock SET stock = stock + ?, updated_at = ? WHERE town_id = ? AND item_name = ?',
        { amount, now(), town.id, itemName }
    )
    if (tonumber(updated) or 0) < 1 then
        addMarketItem(source, itemName, amount)
        return { ok = false, message = 'Bestand konnte nicht aktualisiert werden.' }
    end

    local unitPrice = useConfigMarketPrices() and configured.sellPrice or (tonumber(stock.sell_price) or 0)
    local subtotal = roundMoney(unitPrice * amount)
    local _, taxSellRate = marketCategoryTaxRates(town, configured.category)
    local tax = roundMoney(subtotal * (taxSellRate / 100))
    local payout = roundMoney(subtotal - tax)
    if payout > 0 then
        payCharacter(seller.character, payout)
    end
    if tax > 0 then
        addTreasury(town.id, tax, 'market_sell_tax', seller, ('Verkaufsteuer %.2f%% aus %sx %s.'):format(taxSellRate, amount, configured.label))
    end

    return { ok = true, message = ('Verkauft: %sx %s. Auszahlung: %s, Steuer: %s.'):format(amount, configured.label, money(payout), money(tax)) }
end)

callback('marketSetPrice', function(source, itemName, buyPrice, sellPrice)
    local actor = characterInfo(source)
    local town = getTown(source)
    if not actor or not isAdmin(source) then
        return { ok = false, message = Config.Text.NoPermission }
    end

    itemName = trim(itemName)
    buyPrice = roundMoney(buyPrice)
    sellPrice = roundMoney(sellPrice)

    if useConfigMarketPrices() then
        return { ok = false, message = 'Preise werden zentral ueber config.lua gesetzt und fuer alle Markthallen uebernommen.' }
    end

    local configured = marketItemConfig(itemName)
    if not configured then
        return { ok = false, message = 'Ware nicht gefunden.' }
    end

    if buyPrice < configured.minPrice or buyPrice > configured.maxPrice or sellPrice < configured.minPrice or sellPrice > configured.maxPrice then
        return { ok = false, message = ('Preise muessen zwischen %s und %s liegen.'):format(money(configured.minPrice), money(configured.maxPrice)) }
    end

    MySQL.update.await(
        'UPDATE bm_market_stock SET buy_price = ?, sell_price = ?, updated_at = ? WHERE town_id = ? AND item_name = ?',
        { buyPrice, sellPrice, now(), town.id, itemName }
    )
    addLedger(town.id, 'market_price_change', 0, actor, ('%s: Einkauf %s, Verkauf %s.'):format(configured.label, money(buyPrice), money(sellPrice)))

    return { ok = true, message = ('Preise gesetzt fuer %s.'):format(configured.label) }
end)

callback('marketExportStock', function(source, itemName, amount)
    local actor = characterInfo(source)
    local town = getTown(source)
    if not actor or not canUseOffice(source, town) then
        return { ok = false, message = Config.Text.NoPermission }
    end

    itemName = trim(itemName)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then
        return { ok = false, message = 'Ungueltige Menge.' }
    end

    local configured = marketItemConfig(itemName)
    if not configured then
        return { ok = false, message = 'Ware nicht gefunden.' }
    end

    local stock = stockRowForItem(town, itemName)
    if not stock then
        return { ok = false, message = 'Lagerbestand nicht gefunden.' }
    end

    local currentStock = tonumber(stock.stock) or 0
    if currentStock < amount then
        return { ok = false, message = 'Nicht genug Bestand im Lager.' }
    end

    local unitPrice = useConfigMarketPrices() and configured.buyPrice or (tonumber(stock.buy_price) or 0)
    local totalValue = roundMoney(unitPrice * amount)
    local percent = marketExportPercent()
    local treasuryGain = roundMoney(totalValue * (percent / 100))

    local updated = MySQL.update.await(
        'UPDATE bm_market_stock SET stock = stock - ?, updated_at = ? WHERE town_id = ? AND item_name = ? AND stock >= ?',
        { amount, now(), town.id, itemName, amount }
    )
    if (tonumber(updated) or 0) < 1 then
        return { ok = false, message = 'Bestand wurde gerade geaendert.' }
    end

    if treasuryGain > 0 then
        addTreasury(town.id, treasuryGain, 'market_export', actor, ('Export %.2f%% aus %sx %s. Gesamtwert %s.'):format(percent, amount, configured.label, money(totalValue)))
    else
        addLedger(town.id, 'market_export', 0, actor, ('Export %sx %s ohne Auszahlung.'):format(amount, configured.label))
    end
    sendDiscord('marketExport', 'Lagerbestand exportiert', ('%s hat in %s %sx %s exportiert.'):format(actor.name, town.name, amount, configured.label), {
        { name = 'Stadt', value = town.name, inline = true },
        { name = 'Ware', value = configured.label, inline = true },
        { name = 'Menge', value = tostring(amount), inline = true },
        { name = 'Gesamtwert', value = money(totalValue), inline = true },
        { name = 'Stadtkasse', value = ('+%s (%s%%)'):format(money(treasuryGain), percent), inline = true },
        { name = 'Akteur', value = actor.name, inline = true }
    })

    return { ok = true, message = ('Exportiert: %sx %s. Stadtkasse +%s (%s%% von %s).'):format(amount, configured.label, money(treasuryGain), percent, money(totalValue)) }
end)

callback('marketWithdrawStock', function(source, itemName, amount)
    local actor = characterInfo(source)
    local town = getTown(source)
    if not actor or not canUseOffice(source, town) then
        return { ok = false, message = Config.Text.NoPermission }
    end

    itemName = trim(itemName)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then
        return { ok = false, message = 'Ungueltige Menge.' }
    end

    local configured = marketItemConfig(itemName)
    if not configured then
        return { ok = false, message = 'Ware nicht gefunden.' }
    end

    local stock = stockRowForItem(town, itemName)
    if not stock then
        return { ok = false, message = 'Lagerbestand nicht gefunden.' }
    end

    local currentStock = tonumber(stock.stock) or 0
    if currentStock < amount then
        return { ok = false, message = 'Nicht genug Bestand im Lager.' }
    end

    if not canCarryMarketItem(source, itemName, amount) then
        return { ok = false, message = 'Du kannst diese Menge nicht tragen.' }
    end

    local updated = MySQL.update.await(
        'UPDATE bm_market_stock SET stock = stock - ?, updated_at = ? WHERE town_id = ? AND item_name = ? AND stock >= ?',
        { amount, now(), town.id, itemName, amount }
    )
    if (tonumber(updated) or 0) < 1 then
        return { ok = false, message = 'Bestand wurde gerade geaendert.' }
    end

    if not addMarketItem(source, itemName, amount) then
        MySQL.update.await(
            'UPDATE bm_market_stock SET stock = stock + ?, updated_at = ? WHERE town_id = ? AND item_name = ?',
            { amount, now(), town.id, itemName }
        )
        return { ok = false, message = 'Ware konnte nicht aus dem Lager uebergeben werden.' }
    end

    addLedger(town.id, 'market_withdraw', 0, actor, ('%sx %s kostenlos aus dem Lager entnommen.'):format(amount, configured.label))
    sendDiscord('marketWithdraw', 'Aus Lager entnommen', ('%s hat in %s %sx %s aus dem Markthallenlager entnommen.'):format(actor.name, town.name, amount, configured.label), {
        { name = 'Stadt', value = town.name, inline = true },
        { name = 'Ware', value = configured.label, inline = true },
        { name = 'Menge', value = tostring(amount), inline = true },
        { name = 'Akteur', value = actor.name, inline = true }
    })
    return { ok = true, message = ('Entnommen: %sx %s aus dem Markthallenlager.'):format(amount, configured.label) }
end)

callback('marketToggleItem', function(source, itemName, enabled)
    local actor = characterInfo(source)
    local town = getTown(source)
    if not actor or not canUseOffice(source, town) then
        return { ok = false, message = Config.Text.NoPermission }
    end

    itemName = trim(itemName)
    local configured = marketItemConfig(itemName)
    if not configured then
        return { ok = false, message = 'Ware nicht gefunden.' }
    end

    local stock = stockRowForItem(town, itemName)
    if not stock then
        return { ok = false, message = 'Lagerbestand nicht gefunden.' }
    end

    local newValue = inputEnabled(enabled)
    MySQL.update.await(
        'UPDATE bm_market_stock SET enabled = ?, updated_at = ? WHERE town_id = ? AND item_name = ?',
        { newValue and 1 or 0, now(), town.id, itemName }
    )

    addLedger(town.id, 'market_item_toggle', 0, actor, ('%s wurde %s.'):format(configured.label, newValue and 'aktiviert' or 'deaktiviert'))
    sendDiscord('marketToggle', 'Marktware umgeschaltet', ('%s hat in %s %s %s.'):format(actor.name, town.name, configured.label, newValue and 'aktiviert' or 'deaktiviert'), {
        { name = 'Stadt', value = town.name, inline = true },
        { name = 'Ware', value = configured.label, inline = true },
        { name = 'Status', value = newValue and 'Aktiviert' or 'Deaktiviert', inline = true },
        { name = 'Akteur', value = actor.name, inline = true }
    })
    return { ok = true, message = ('%s wurde %s.'):format(configured.label, newValue and 'aktiviert' or 'deaktiviert') }
end)

callback('marketSetTaxRates', function(source, taxes, legacySellRate)
    local actor = characterInfo(source)
    local town = getTown(source)
    if not actor or not isAdmin(source) then
        return { ok = false, message = Config.Text.NoPermission }
    end

    local _, categories = marketCatalog()
    local updates = {}

    if type(taxes) ~= 'table' then
        local ok, message, normalizedBuy, normalizedSell = validateTaxRates(taxes, legacySellRate)
        if not ok then
            return { ok = false, message = message }
        end

        for _, category in ipairs(categories) do
            updates[#updates + 1] = {
                category = category.key,
                label = category.label,
                buyRate = normalizedBuy,
                sellRate = normalizedSell
            }
        end
    else
        for _, category in ipairs(categories) do
            local values = taxes[category.key]
            if type(values) == 'table' then
                local ok, message, normalizedBuy, normalizedSell = validateTaxRates(values.buyRate, values.sellRate)
                if not ok then
                    return { ok = false, message = ('%s: %s'):format(category.label, message) }
                end

                updates[#updates + 1] = {
                    category = category.key,
                    label = category.label,
                    buyRate = normalizedBuy,
                    sellRate = normalizedSell
                }
            end
        end
    end

    if #updates == 0 then
        return { ok = false, message = 'Keine Steuersaetze uebergeben.' }
    end

    for _, update in ipairs(updates) do
        MySQL.insert.await(
            [[
                INSERT INTO bm_market_taxes
                    (town_id, category, category_label, buy_tax_rate, sell_tax_rate, updated_at)
                VALUES (?, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE
                    category_label = VALUES(category_label),
                    buy_tax_rate = VALUES(buy_tax_rate),
                    sell_tax_rate = VALUES(sell_tax_rate),
                    updated_at = VALUES(updated_at)
            ]],
            { town.id, update.category, update.label, update.buyRate, update.sellRate, now() }
        )
    end

    local primary = updates[1]
    MySQL.update.await(
        'UPDATE bm_towns SET tax_rate = ?, tax_buy_rate = ?, tax_sell_rate = ? WHERE id = ?',
        { primary.buyRate, primary.buyRate, primary.sellRate, town.id }
    )

    local notes = {}
    for _, update in ipairs(updates) do
        notes[#notes + 1] = ('%s E %.2f%% / V %.2f%%'):format(update.label, update.buyRate, update.sellRate)
    end

    local note = table.concat(notes, ', ')
    addLedger(town.id, 'tax_change', 0, actor, note)
    sendDiscord('taxChange', 'Markthallensteuern gesetzt', ('%s hat in %s die Markthallensteuern gesetzt.'):format(actor.name, town.name), {
        { name = 'Stadt', value = town.name, inline = true },
        { name = 'Steuern', value = note, inline = false }
    })
    TriggerClientEvent(RESOURCE .. ':client:notifyAll', -1, ('Markthallensteuern gesetzt: %s.'):format(note))

    return { ok = true, message = ('Steuern gesetzt: %s.'):format(note) }
end)

callback('getInventoryItems', function(source, categoryKey)
    if categoryKey and categoryKey ~= '' and not marketCategory(categoryKey) then
        return { ok = false, message = 'Unbekannter Markthallen-Reiter.' }
    end

    local town = getTown(source)
    local enabledMap = marketEnabledMap(town)
    local items = awaitVorpInventory(function(done)
        exports.vorp_inventory:getUserInventoryItems(source, done)
    end) or {}

    local normalized = {}
    for _, item in pairs(items) do
        local name = item.name
        local count = tonumber(item.count or item.amount or item.quantity) or 0
        local configured = marketItemConfig(name, categoryKey)
        if name and count > 0 and configured and enabledMap[tostring(name)] ~= false and not Config.Market.RestrictedItems[name] then
            normalized[#normalized + 1] = {
                name = name,
                label = configured.label or item.label or name,
                count = count,
                category = configured.category,
                categoryLabel = configured.categoryLabel,
                minAmount = configured.minAmount,
                maxAmount = math.min(count, configured.maxAmount),
                minPrice = configured.minPrice,
                maxPrice = configured.maxPrice
            }
        end
    end

    table.sort(normalized, function(a, b)
        return a.label < b.label
    end)

    return { ok = true, items = normalized }
end)

callback('getListings', function(source, categoryKey)
    if categoryKey and categoryKey ~= '' and not marketCategory(categoryKey) then
        return { ok = false, message = 'Unbekannter Markthallen-Reiter.' }
    end

    local town = getTown(source)
    local enabledMap = marketEnabledMap(town)
    local rows = MySQL.query.await(
        [[
            SELECT id, seller_name, item_name, item_label, amount, price_each, created_at
            FROM bm_market_listings
            WHERE town_id = ? AND status = ?
            ORDER BY created_at DESC
            LIMIT ?
        ]],
        { town.id, 'active', Config.Market.MaxActiveListings * 5 }
    ) or {}

    local filtered = {}
    for _, row in ipairs(rows) do
        local configured = marketItemConfig(row.item_name, categoryKey)
        if configured and enabledMap[tostring(row.item_name)] ~= false then
            row.price_each = tonumber(row.price_each) or 0
            row.item_label = configured.label or row.item_label
            row.category = configured.category
            row.categoryLabel = configured.categoryLabel
            row.minPrice = configured.minPrice
            row.maxPrice = configured.maxPrice
            filtered[#filtered + 1] = row
            if #filtered >= Config.Market.MaxActiveListings then
                break
            end
        end
    end

    local taxBuyRate, taxSellRate = townTaxRates(town)
    if categoryKey and categoryKey ~= '' then
        taxBuyRate, taxSellRate = marketCategoryTaxRates(town, categoryKey)
    end
    return {
        ok = true,
        listings = filtered,
        taxRate = taxSellRate,
        taxBuyRate = taxBuyRate,
        taxSellRate = taxSellRate,
        canManage = Config.Market.MayorCanRemoveListings and canUseOffice(source, town) or false
    }
end)

callback('getMyListings', function(source)
    local info = characterInfo(source)
    if not info then
        return { ok = false, message = 'Charakter nicht geladen.' }
    end

    local town = getTown(source)
    local rows = MySQL.query.await(
        [[
            SELECT id, item_name, item_label, amount, price_each, created_at
            FROM bm_market_listings
            WHERE seller_charid = ? AND town_id = ? AND status = ?
            ORDER BY created_at DESC
        ]],
        { info.charid, town.id, 'active' }
    ) or {}

    for _, row in ipairs(rows) do
        row.price_each = tonumber(row.price_each) or 0
        local configured = marketItemConfig(row.item_name)
        row.category = configured and configured.category or nil
        row.categoryLabel = configured and configured.categoryLabel or 'Nicht konfiguriert'
        row.item_label = configured and configured.label or row.item_label
    end

    return { ok = true, listings = rows }
end)

callback('getLedger', function(source)
    local town = getTown(source)
    if not canUseOffice(source, town) then
        return { ok = false, message = Config.Text.NoPermission }
    end

    local rows = MySQL.query.await(
        [[
            SELECT entry_type, amount, actor_name, note, created_at
            FROM bm_ledger
            WHERE town_id = ?
            ORDER BY id DESC
            LIMIT 20
        ]],
        { town.id }
    ) or {}

    return { ok = true, rows = normalizeLedgerRows(rows) }
end)

callback('getCitizenRegistry', function(source)
    local town = getTown(source)
    if not canUseOffice(source, town) then
        return { ok = false, message = Config.Text.NoPermission }
    end

    return {
        ok = true,
        counts = BMDB.citizenCounts(town.id),
        citizens = citizenRegistryRows(town.id)
    }
end)

RegisterNetEvent(RESOURCE .. ':server:applyCitizenship', function()
    local source = source
    local info = characterInfo(source)
    if not info then
        notify(source, 'Charakter nicht geladen.')
        return
    end

    local town = getTown(source)
    local citizenship = BMDB.citizenship(town.id, info.charid)
    if citizenship and citizenship.status == 'active' then
        notify(source, ('Du bist bereits bestaetigter Bürger von %s.'):format(town.name))
        return
    end

    if citizenship and citizenship.status == 'pending' then
        notify(source, 'Dein Bürgerantrag wartet bereits auf Bestaetigung.')
        return
    end

    if citizenship and citizenship.status == 'removed' and not Config.Citizenship.AllowReapplyAfterRemoval then
        notify(source, 'Du kannst dich aktuell nicht erneut als Bürger eintragen.')
        return
    end

    local createdAt = now()
    if citizenship then
        MySQL.update.await(
            [[
                UPDATE bm_citizens
                SET identifier = ?, name = ?, status = ?, note = '', created_at = ?,
                    approved_at = NULL, removed_at = NULL, decided_by_charid = NULL,
                    decided_by_name = NULL, updated_at = ?
                WHERE id = ?
            ]],
            { info.identifier, info.name, 'pending', createdAt, createdAt, citizenship.id }
        )
    else
        MySQL.insert.await(
            [[
                INSERT INTO bm_citizens
                    (town_id, charid, identifier, name, status, note, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ]],
            { town.id, info.charid, info.identifier, info.name, 'pending', '', createdAt, createdAt }
        )
    end

    addLedger(town.id, 'citizen_apply', 0, info, ('%s beantragt die Bürgerschaft.'):format(info.name))
    sendDiscord('citizenApply', 'Bürgerantrag gestellt', ('%s hat in %s einen Bürgerantrag gestellt.'):format(info.name, town.name), {
        { name = 'Stadt', value = town.name, inline = true },
        { name = 'Spieler', value = info.name, inline = true },
        { name = 'Char-ID', value = info.charid, inline = true }
    })
    notify(source, ('Bürgerantrag fuer %s eingereicht.'):format(town.name))
end)

RegisterNetEvent(RESOURCE .. ':server:approveCitizen', function(citizenId)
    local source = source
    local actor = characterInfo(source)
    local town = getTown(source)
    if not actor or not canUseOffice(source, town) then
        notify(source, Config.Text.NoPermission)
        return
    end

    citizenId = tonumber(citizenId)
    if not citizenId then
        notify(source, 'Ungueltiger Bürger-Eintrag.')
        return
    end

    local rows = MySQL.query.await(
        'SELECT * FROM bm_citizens WHERE id = ? AND town_id = ? LIMIT 1',
        { citizenId, town.id }
    )
    local citizen = rows and rows[1]
    if not citizen then
        notify(source, 'Bürger-Eintrag nicht gefunden.')
        return
    end

    if citizen.status == 'active' then
        notify(source, ('%s ist bereits bestaetigter Bürger.'):format(citizen.name))
        return
    end

    MySQL.update.await(
        [[
            UPDATE bm_citizens
            SET status = ?, approved_at = ?, removed_at = NULL, decided_by_charid = ?,
                decided_by_name = ?, note = '', updated_at = ?
            WHERE id = ? AND town_id = ?
        ]],
        { 'active', now(), actor.charid, actor.name, now(), citizen.id, town.id }
    )

    addLedger(town.id, 'citizen_approved', 0, actor, ('%s wurde als Bürger bestaetigt.'):format(citizen.name))
    sendDiscord('citizenApproved', 'Bürger bestätigt', ('%s wurde in %s als Bürger bestätigt.'):format(citizen.name, town.name), {
        { name = 'Stadt', value = town.name, inline = true },
        { name = 'Bürger', value = citizen.name, inline = true },
        { name = 'Bearbeitet von', value = actor.name, inline = true }
    })
    notify(source, ('%s wurde als Bürger bestaetigt.'):format(citizen.name))

    local targetSource = findSourceByCharId(citizen.charid)
    if targetSource then
        notify(targetSource, ('Du wurdest als Bürger von %s bestaetigt.'):format(town.name))
    end
end)

RegisterNetEvent(RESOURCE .. ':server:removeCitizen', function(citizenId, reason)
    local source = source
    local actor = characterInfo(source)
    local town = getTown(source)
    if not actor or not canUseOffice(source, town) then
        notify(source, Config.Text.NoPermission)
        return
    end

    citizenId = tonumber(citizenId)
    if not citizenId then
        notify(source, 'Ungueltiger Bürger-Eintrag.')
        return
    end

    local rows = MySQL.query.await(
        'SELECT * FROM bm_citizens WHERE id = ? AND town_id = ? LIMIT 1',
        { citizenId, town.id }
    )
    local citizen = rows and rows[1]
    if not citizen then
        notify(source, 'Bürger-Eintrag nicht gefunden.')
        return
    end

    if citizen.status == 'removed' then
        notify(source, ('%s ist bereits ausgetragen.'):format(citizen.name))
        return
    end

    if tostring(citizen.charid) == tostring(town.mayor_charid) and not isAdmin(source) then
        notify(source, 'Der amtierende Bürgermeister kann nur durch einen Admin ausgetragen werden.')
        return
    end

    reason = trim(reason)
    if #reason > 180 then
        reason = reason:sub(1, 180)
    end

    local note = reason ~= '' and reason or 'Aus dem Bürgerregister entfernt.'
    MySQL.update.await(
        [[
            UPDATE bm_citizens
            SET status = ?, removed_at = ?, decided_by_charid = ?, decided_by_name = ?,
                note = ?, updated_at = ?
            WHERE id = ? AND town_id = ?
        ]],
        { 'removed', now(), actor.charid, actor.name, note, now(), citizen.id, town.id }
    )

    addLedger(town.id, 'citizen_removed', 0, actor, ('%s wurde ausgetragen: %s'):format(citizen.name, note))
    sendDiscord('citizenRemoved', 'Bürger entfernt', ('%s wurde in %s aus dem Bürgerregister entfernt.'):format(citizen.name, town.name), {
        { name = 'Stadt', value = town.name, inline = true },
        { name = 'Bürger', value = citizen.name, inline = true },
        { name = 'Grund', value = note, inline = false }
    })
    notify(source, ('%s wurde aus dem Bürgerregister entfernt.'):format(citizen.name))

    local targetSource = findSourceByCharId(citizen.charid)
    if targetSource then
        notify(targetSource, ('Du wurdest aus dem Bürgerregister von %s entfernt.'):format(town.name))
    end
end)

RegisterNetEvent(RESOURCE .. ':server:assignCitizenJob', function(citizenId, jobName)
    local source = source
    local actor = characterInfo(source)
    local town = getTown(source)
    if not actor or not canUseOffice(source, town) then
        notify(source, Config.Text.NoPermission)
        return
    end

    local availableJobs = configuredMayorJobs(town)
    if #availableJobs == 0 then
        notify(source, 'Job-Zuweisung ist fuer diese Stadt in der Config deaktiviert.')
        return
    end

    citizenId = tonumber(citizenId)
    if not citizenId then
        notify(source, 'Ungültiger Bürger-Eintrag.')
        return
    end

    local job = allowedMayorJob(jobName, town, availableJobs)
    if not job then
        notify(source, 'Dieser Job darf vom Bürgermeister nicht vergeben werden.')
        return
    end

    local rows = MySQL.query.await(
        'SELECT * FROM bm_citizens WHERE id = ? AND town_id = ? AND status = ? LIMIT 1',
        { citizenId, town.id, 'active' }
    )
    local citizen = rows and rows[1]
    if not citizen then
        notify(source, 'Aktiver Bürger-Eintrag nicht gefunden.')
        return
    end

    local ok, message = updateCharacterJob(citizen, job)
    if not ok then
        notify(source, message)
        return
    end

    rememberAssignedJob(citizen, job)
    local onlineUpdated = applyOnlineJob(citizen.charid, job)
    CreateThread(function()
        Wait(500)
        applyOnlineJob(citizen.charid, job)
        Wait(1500)
        persistRememberedJob(citizen.charid, citizen.identifier)
    end)

    addLedger(town.id, 'citizen_job', 0, actor, ('%s bekommt Job %s Rang %s.'):format(citizen.name, job.jobLabel, job.grade))
    sendDiscord('citizenJob', 'Job vergeben', ('%s hat %s in %s den Job %s Rang %s gegeben.'):format(actor.name, citizen.name, town.name, job.jobLabel, job.grade), {
        { name = 'Stadt', value = town.name, inline = true },
        { name = 'Bürger', value = citizen.name, inline = true },
        { name = 'Job', value = ('%s (%s)'):format(job.jobLabel, job.job), inline = true }
    })

    notify(source, ('Job gesetzt: %s ist jetzt %s Rang %s.'):format(citizen.name, job.jobLabel, job.grade))
    if not onlineUpdated then
        notify(source, 'Hinweis: Der Bürger wurde in der Datenbank gesetzt, war aber online nicht eindeutig gefunden.')
    end
    local targetSource = findSourceByCharId(citizen.charid)
    if targetSource then
        notify(targetSource, ('Dein Bürgermeister hat dir den Job %s Rang %s gegeben.'):format(job.jobLabel, job.grade))
    end
end)

RegisterNetEvent(RESOURCE .. ':server:registerCandidate', function(manifesto)
    local source = source
    local info = characterInfo(source)
    if not info then
        notify(source, 'Charakter nicht geladen.')
        return
    end

    local town = getTown(source)
    local election = BMDB.activeElection(town.id)
    if not election then
        notify(source, 'Es laeuft keine Wahl.')
        return
    end

    local phase = electionPhase(election)
    if phase ~= 'nomination' then
        notify(source, 'Die Kandidaturphase ist beendet.')
        return
    end

    if Config.Citizenship.RequireApprovedForCandidacy and not hasActiveCitizenship(town.id, info.charid) then
        notify(source, 'Nur bestaetigte Bürger koennen kandidieren.')
        return
    end

    local inserted = MySQL.insert.await(
        'INSERT IGNORE INTO bm_candidates (election_id, charid, identifier, name, manifesto, created_at) VALUES (?, ?, ?, ?, ?, ?)',
        { election.id, info.charid, info.identifier, info.name, normalizeManifesto(manifesto), now() }
    )

    if inserted and inserted > 0 then
        notify(source, 'Kandidatur eingereicht.')
    else
        notify(source, 'Du bist bereits Kandidat in dieser Wahl.')
    end
end)

RegisterNetEvent(RESOURCE .. ':server:castVote', function(candidateId)
    local source = source
    local info = characterInfo(source)
    if not info then
        notify(source, 'Charakter nicht geladen.')
        return
    end

    candidateId = tonumber(candidateId)
    if not candidateId then
        notify(source, 'Ungueltiger Kandidat.')
        return
    end

    local town = getTown(source)
    local election = BMDB.activeElection(town.id)
    if not election then
        notify(source, 'Es laeuft keine Wahl.')
        return
    end

    local phase = electionPhase(election)
    if phase ~= 'voting' then
        notify(source, 'Aktuell kann nicht abgestimmt werden.')
        return
    end

    if Config.Citizenship.RequireApprovedForVoting and not hasActiveCitizenship(town.id, info.charid) then
        notify(source, 'Nur bestaetigte Bürger koennen abstimmen.')
        return
    end

    local candidateRows = MySQL.query.await(
        'SELECT id, charid, name FROM bm_candidates WHERE id = ? AND election_id = ? LIMIT 1',
        { candidateId, election.id }
    )
    local candidate = candidateRows and candidateRows[1]
    if not candidate then
        notify(source, 'Kandidat nicht gefunden.')
        return
    end

    if not Config.Election.AllowSelfVote and tostring(candidate.charid) == info.charid then
        notify(source, 'Du kannst nicht fuer dich selbst stimmen.')
        return
    end

    local inserted = MySQL.insert.await(
        'INSERT IGNORE INTO bm_votes (election_id, candidate_id, voter_charid, voter_name, created_at) VALUES (?, ?, ?, ?, ?)',
        { election.id, candidate.id, info.charid, info.name, now() }
    )

    if inserted and inserted > 0 then
        notify(source, ('Du hast fuer %s gestimmt.'):format(candidate.name))
    else
        notify(source, 'Du hast in dieser Wahl bereits abgestimmt.')
    end
end)

RegisterNetEvent(RESOURCE .. ':server:createListing', function(itemName, amount, priceEach)
    local source = source
    local info = characterInfo(source)
    if not info then
        notify(source, 'Charakter nicht geladen.')
        return
    end

    itemName = trim(itemName)
    amount = math.floor(tonumber(amount) or 0)
    priceEach = roundMoney(priceEach)

    if itemName == '' or not itemName:match('^[%w_%-]+$') then
        notify(source, 'Ungueltiger Itemname.')
        return
    end

    if Config.Market.RestrictedItems[itemName] then
        notify(source, 'Dieses Item darf nicht verkauft werden.')
        return
    end

    local configured = marketItemConfig(itemName)
    if not configured then
        notify(source, 'Dieses Item ist nicht in der Markthallen-Config eingetragen.')
        return
    end

    local town = getTown(source)
    if not marketItemEnabled(town, itemName) then
        notify(source, 'Diese Ware ist in dieser Stadt aktuell deaktiviert.')
        return
    end

    local noListingFee = Config.Market.MayorNoListingFee and canUseOffice(source, town)

    if amount < configured.minAmount or amount > configured.maxAmount then
        notify(source, ('Menge muss zwischen %s und %s liegen.'):format(configured.minAmount, configured.maxAmount))
        return
    end

    if priceEach < configured.minPrice or priceEach > configured.maxPrice then
        notify(source, ('Preis muss zwischen %s und %s liegen.'):format(money(configured.minPrice), money(configured.maxPrice)))
        return
    end

    local activeCount = MySQL.query.await(
        'SELECT COUNT(*) AS count FROM bm_market_listings WHERE seller_charid = ? AND status = ?',
        { info.charid, 'active' }
    )
    if (tonumber(activeCount and activeCount[1] and activeCount[1].count) or 0) >= Config.Market.MaxListingsPerPlayer then
        notify(source, 'Du hast bereits zu viele aktive Angebote.')
        return
    end

    if getItemCount(source, itemName) < amount then
        notify(source, 'Du hast nicht genug davon im Inventar.')
        return
    end

    local fee = noListingFee and 0 or roundMoney(Config.Market.ListingFee)
    if fee > 0 and not removeMoney(info.character, fee) then
        notify(source, ('Du brauchst %s Einstellgebuehr.'):format(money(fee)))
        return
    end

    if not removeItem(source, itemName, amount) then
        if fee > 0 then
            payCharacter(info.character, fee)
        end
        notify(source, 'Item konnte nicht aus dem Inventar genommen werden.')
        return
    end

    local itemLabel = configured.label or getItemLabel(itemName)
    local ok, listingId = pcall(MySQL.insert.await,
        'INSERT INTO bm_market_listings (town_id, seller_charid, seller_name, item_name, item_label, amount, price_each, status, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { town.id, info.charid, info.name, itemName, itemLabel, amount, priceEach, 'active', now() }
    )

    if not ok or not listingId then
        addItem(source, itemName, amount)
        if fee > 0 then
            payCharacter(info.character, fee)
        end
        notify(source, 'Angebot konnte nicht erstellt werden.')
        return
    end

    if fee > 0 then
        addTreasury(town.id, fee, 'listing_fee', info, ('Einstellgebuehr fuer Angebot #%s.'):format(listingId))
    end

    notify(source, ('Angebot erstellt: %sx %s (%s) fuer %s pro Stueck.'):format(amount, itemLabel, configured.categoryLabel, money(priceEach)))
end)

RegisterNetEvent(RESOURCE .. ':server:buyListing', function(listingId)
    local source = source
    local buyer = characterInfo(source)
    if not buyer then
        notify(source, 'Charakter nicht geladen.')
        return
    end

    listingId = tonumber(listingId)
    if not listingId then
        notify(source, 'Ungueltiges Angebot.')
        return
    end

    local town = getTown(source)
    local listingRows = MySQL.query.await(
        'SELECT * FROM bm_market_listings WHERE id = ? AND town_id = ? AND status = ? LIMIT 1',
        { listingId, town.id, 'active' }
    )
    local listing = listingRows and listingRows[1]
    if not listing then
        notify(source, 'Angebot nicht mehr verfuegbar.')
        return
    end

    local configured = marketItemConfig(listing.item_name)
    if not configured then
        notify(source, 'Dieses Angebot ist nicht mehr in der Markthallen-Config freigegeben.')
        return
    end

    if not marketItemEnabled(town, listing.item_name) then
        notify(source, 'Diese Ware ist in dieser Stadt aktuell deaktiviert.')
        return
    end

    if not Config.Market.AllowSelfPurchase and tostring(listing.seller_charid) == buyer.charid then
        notify(source, 'Du kannst dein eigenes Angebot nicht kaufen.')
        return
    end

    local locked = MySQL.update.await(
        'UPDATE bm_market_listings SET status = ? WHERE id = ? AND status = ?',
        { 'processing', listing.id, 'active' }
    )
    if (tonumber(locked) or 0) < 1 then
        notify(source, 'Angebot wird gerade bearbeitet.')
        return
    end

    local amount = tonumber(listing.amount) or 0
    local priceEach = tonumber(listing.price_each) or 0
    local total = roundMoney(amount * priceEach)
    local _, taxSellRate = marketCategoryTaxRates(town, configured.category)
    local tax = roundMoney(total * (taxSellRate / 100))
    local sellerPayout = roundMoney(total - tax)

    local function unlock()
        MySQL.update.await(
            'UPDATE bm_market_listings SET status = ? WHERE id = ? AND status = ?',
            { 'active', listing.id, 'processing' }
        )
    end

    if not canCarryItem(source, listing.item_name, amount) then
        unlock()
        notify(source, 'Du kannst diese Menge nicht tragen.')
        return
    end

    if not removeMoney(buyer.character, total) then
        unlock()
        notify(source, ('Du brauchst %s.'):format(money(total)))
        return
    end

    if not addItem(source, listing.item_name, amount) then
        payCharacter(buyer.character, total)
        unlock()
        notify(source, 'Item konnte nicht uebergeben werden.')
        return
    end

    MySQL.update.await(
        'UPDATE bm_market_listings SET status = ?, buyer_charid = ?, buyer_name = ?, sold_at = ? WHERE id = ?',
        { 'sold', buyer.charid, buyer.name, now(), listing.id }
    )

    createPayout(listing.seller_charid, listing.seller_name, sellerPayout, ('Markthallenverkauf #%s'):format(listing.id))
    claimPayoutsForChar(listing.seller_charid)

    if tax > 0 then
        addTreasury(town.id, tax, 'sales_tax', buyer, ('Verkaufsteuer %.2f%% aus Angebot #%s.'):format(taxSellRate, listing.id))
    end

    notify(source, ('Gekauft: %sx %s fuer %s. Steuer: %s.'):format(amount, configured.label or listing.item_label, money(total), money(tax)))
end)

RegisterNetEvent(RESOURCE .. ':server:cancelListing', function(listingId)
    local source = source
    local info = characterInfo(source)
    if not info then
        notify(source, 'Charakter nicht geladen.')
        return
    end

    listingId = tonumber(listingId)
    if not listingId then
        notify(source, 'Ungueltiges Angebot.')
        return
    end

    local town = getTown(source)
    local rows = MySQL.query.await(
        'SELECT * FROM bm_market_listings WHERE id = ? AND town_id = ? AND status = ? LIMIT 1',
        { listingId, town.id, 'active' }
    )
    local listing = rows and rows[1]
    if not listing then
        notify(source, 'Angebot nicht gefunden.')
        return
    end

    if tostring(listing.seller_charid) ~= info.charid then
        notify(source, Config.Text.NoPermission)
        return
    end

    local amount = tonumber(listing.amount) or 0
    if not canCarryItem(source, listing.item_name, amount) then
        notify(source, 'Du kannst die Ware gerade nicht zuruecknehmen.')
        return
    end

    local locked = MySQL.update.await(
        'UPDATE bm_market_listings SET status = ? WHERE id = ? AND status = ?',
        { 'processing', listing.id, 'active' }
    )
    if (tonumber(locked) or 0) < 1 then
        notify(source, 'Angebot wird gerade bearbeitet.')
        return
    end

    if not addItem(source, listing.item_name, amount) then
        MySQL.update.await('UPDATE bm_market_listings SET status = ? WHERE id = ?', { 'active', listing.id })
        notify(source, 'Ware konnte nicht zurueckgegeben werden.')
        return
    end

    MySQL.update.await(
        'UPDATE bm_market_listings SET status = ?, sold_at = ? WHERE id = ?',
        { 'cancelled', now(), listing.id }
    )
    notify(source, 'Angebot zurueckgenommen.')
end)

RegisterNetEvent(RESOURCE .. ':server:removeListingFromMarket', function(listingId)
    local source = source
    local actor = characterInfo(source)
    local town = getTown(source)
    if not actor or not canUseOffice(source, town) or not Config.Market.MayorCanRemoveListings then
        notify(source, Config.Text.NoPermission)
        return
    end

    listingId = tonumber(listingId)
    if not listingId then
        notify(source, 'Ungueltiges Angebot.')
        return
    end

    local rows = MySQL.query.await(
        'SELECT * FROM bm_market_listings WHERE id = ? AND town_id = ? AND status = ? LIMIT 1',
        { listingId, town.id, 'active' }
    )
    local listing = rows and rows[1]
    if not listing then
        notify(source, 'Angebot nicht gefunden.')
        return
    end

    local locked = MySQL.update.await(
        'UPDATE bm_market_listings SET status = ? WHERE id = ? AND status = ?',
        { 'processing', listing.id, 'active' }
    )
    if (tonumber(locked) or 0) < 1 then
        notify(source, 'Angebot wird gerade bearbeitet.')
        return
    end

    local amount = tonumber(listing.amount) or 0
    local returnedDirectly = false
    local sellerSource = findSourceByCharId(listing.seller_charid)
    if sellerSource and canCarryItem(sellerSource, listing.item_name, amount) then
        returnedDirectly = addItem(sellerSource, listing.item_name, amount)
    end

    if not returnedDirectly then
        createItemReturn(
            listing.seller_charid,
            listing.seller_name,
            listing.item_name,
            listing.item_label,
            amount,
            ('Markthallenangebot #%s entfernt'):format(listing.id)
        )
    end

    MySQL.update.await(
        'UPDATE bm_market_listings SET status = ?, sold_at = ? WHERE id = ?',
        { 'removed', now(), listing.id }
    )

    addLedger(
        town.id,
        'listing_removed',
        0,
        actor,
        ('Angebot #%s von %s entfernt: %sx %s.'):format(listing.id, listing.seller_name, amount, listing.item_label)
    )

    notify(source, ('Angebot entfernt: %sx %s.'):format(amount, listing.item_label))
    if sellerSource then
        if returnedDirectly then
            notify(sellerSource, ('Dein Markthallenangebot wurde entfernt und dir zurueckgegeben: %sx %s.'):format(amount, listing.item_label))
        else
            notify(sellerSource, ('Dein Markthallenangebot wurde entfernt. Hole die Ware in der Markthalle ab: %sx %s.'):format(amount, listing.item_label))
        end
    end
end)

RegisterNetEvent(RESOURCE .. ':server:updateListingPrice', function(listingId, priceEach)
    local source = source
    local actor = characterInfo(source)
    local town = getTown(source)
    if not actor or not canUseOffice(source, town) then
        notify(source, Config.Text.NoPermission)
        return
    end

    listingId = tonumber(listingId)
    priceEach = roundMoney(priceEach)
    if not listingId then
        notify(source, 'Ungueltiges Angebot.')
        return
    end

    local rows = MySQL.query.await(
        'SELECT * FROM bm_market_listings WHERE id = ? AND town_id = ? AND status = ? LIMIT 1',
        { listingId, town.id, 'active' }
    )
    local listing = rows and rows[1]
    if not listing then
        notify(source, 'Angebot nicht gefunden.')
        return
    end

    local configured = marketItemConfig(listing.item_name)
    if not configured then
        notify(source, 'Dieses Angebot ist nicht mehr in der Markthallen-Config freigegeben.')
        return
    end

    if priceEach < configured.minPrice or priceEach > configured.maxPrice then
        notify(source, ('Preis muss zwischen %s und %s liegen.'):format(money(configured.minPrice), money(configured.maxPrice)))
        return
    end

    MySQL.update.await(
        'UPDATE bm_market_listings SET price_each = ? WHERE id = ? AND town_id = ? AND status = ?',
        { priceEach, listing.id, town.id, 'active' }
    )
    addLedger(
        town.id,
        'listing_price_change',
        0,
        actor,
        ('Preis fuer Angebot #%s auf %s pro Stueck gesetzt.'):format(listing.id, money(priceEach))
    )
    notify(source, ('Preis gesetzt: %s pro Stueck.'):format(money(priceEach)))
end)

RegisterNetEvent(RESOURCE .. ':server:claimPayouts', function()
    local source = source
    local info = characterInfo(source)
    if not info then
        notify(source, 'Charakter nicht geladen.')
        return
    end

    local total = claimPayoutsForChar(info.charid)
    if total > 0 then
        notify(source, ('Auszahlung erhalten: %s.'):format(money(total)))
    else
        notify(source, 'Keine offenen Auszahlungen.')
    end
end)

RegisterNetEvent(RESOURCE .. ':server:claimItemReturns', function()
    local source = source
    local info = characterInfo(source)
    if not info then
        notify(source, 'Charakter nicht geladen.')
        return
    end

    local claimed, message = claimItemReturnsForSource(source, info.charid)
    notify(source, message)
end)

RegisterNetEvent(RESOURCE .. ':server:setTaxRate', function(rate)
    local source = source
    local info = characterInfo(source)
    local town = getTown(source)
    if not info or not canUseOffice(source, town) then
        notify(source, Config.Text.NoPermission)
        return
    end

    local buyRate = roundMoney(rate)
    local sellRate = buyRate + Config.Town.MinSellTaxSpread
    local ok, message, normalizedBuy, normalizedSell = validateTaxRates(buyRate, sellRate)
    if not ok then
        notify(source, message)
        return
    end

    MySQL.update.await(
        'UPDATE bm_towns SET tax_rate = ?, tax_buy_rate = ?, tax_sell_rate = ? WHERE id = ?',
        { normalizedBuy, normalizedBuy, normalizedSell, town.id }
    )
    setAllMarketCategoryTaxes(town, normalizedBuy, normalizedSell)
    addLedger(town.id, 'tax_change', 0, info, ('Alle Kategorien: Einkauf %.2f%%, Verkauf %.2f%%.'):format(normalizedBuy, normalizedSell))
    sendDiscord('taxChange', 'Steuern geändert', ('%s hat in %s die Steuern geändert.'):format(info.name, town.name), {
        { name = 'Stadt', value = town.name, inline = true },
        { name = 'Einkauf', value = ('%.2f%%'):format(normalizedBuy), inline = true },
        { name = 'Verkauf', value = ('%.2f%%'):format(normalizedSell), inline = true }
    })
    TriggerClientEvent(RESOURCE .. ':client:notifyAll', -1, ('Markthallensteuern fuer alle Kategorien: Einkauf %.2f%%, Verkauf %.2f%%.'):format(normalizedBuy, normalizedSell))
end)

RegisterNetEvent(RESOURCE .. ':server:mayorAnnouncement', function(message)
    local source = source
    local info = characterInfo(source)
    local town = getTown(source)
    if not info or not canUseOffice(source, town) then
        notify(source, Config.Text.NoPermission)
        return
    end

    message = trim(message)
    if #message < 3 or #message > 180 then
        notify(source, 'Bekanntmachung muss 3 bis 180 Zeichen haben.')
        return
    end

    addLedger(town.id, 'announcement', 0, info, message)
    TriggerClientEvent(RESOURCE .. ':client:notifyAll', -1, ('Rathaus %s: %s'):format(town.name, message))
end)

RegisterNetEvent(RESOURCE .. ':server:treasuryGrant', function(targetId, amount, reason)
    local source = source
    local actor = characterInfo(source)
    local town = getTown(source)
    if not actor or not canUseOffice(source, town) then
        notify(source, Config.Text.NoPermission)
        return
    end

    targetId = tonumber(targetId)
    amount = roundMoney(amount)
    reason = trim(reason)
    if not targetId or targetId <= 0 then
        notify(source, 'Ungueltige Spieler-ID.')
        return
    end

    local _, targetCharacter = getUserAndCharacter(targetId)
    if not targetCharacter then
        notify(source, 'Zielspieler ist nicht online oder hat keinen Charakter geladen.')
        return
    end

    if amount <= 0 then
        notify(source, 'Ungueltiger Betrag.')
        return
    end

    local ok, message = spendTreasury(town.id, amount, 'grant', actor, reason ~= '' and reason or ('Auszahlung an %s'):format(characterName(targetCharacter)))
    if not ok then
        notify(source, message)
        return
    end

    payCharacter(targetCharacter, amount)
    sendDiscord('treasuryGrant', 'Auszahlung aus Stadtkasse', ('%s hat aus der Stadtkasse %s ausgezahlt.'):format(actor.name, money(amount)), {
        { name = 'Stadt', value = town.name, inline = true },
        { name = 'Empfänger', value = characterName(targetCharacter), inline = true },
        { name = 'Grund', value = reason ~= '' and reason or 'Auszahlung', inline = false }
    })
    notify(source, ('Auszahlung gesendet: %s.'):format(money(amount)))
    notify(targetId, ('Du hast eine Auszahlung aus der Stadtkasse erhalten: %s.'):format(money(amount)))
end)

local function startElection(source, nominationHours, votingHours, townContext)
    local actor = source > 0 and characterInfo(source) or nil
    local town = getTown(townContext or source)
    if BMDB.activeElection(town.id) then
        notify(source, 'Es laeuft bereits eine Wahl.')
        return
    end

    nominationHours = tonumber(nominationHours) or Config.Election.NominationHours
    votingHours = tonumber(votingHours) or Config.Election.VotingHours

    local createdAt = now()
    local nominationEndsAt = createdAt + math.max(1, math.floor(nominationHours * 3600))
    local votingEndsAt = nominationEndsAt + math.max(1, math.floor(votingHours * 3600))

    local id = MySQL.insert.await(
        [[
            INSERT INTO bm_elections
                (town_id, status, nomination_ends_at, voting_ends_at, created_by_charid, created_by_name, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ]],
        {
            town.id,
            'active',
            nominationEndsAt,
            votingEndsAt,
            actor and actor.charid or nil,
            actor and actor.name or 'Console',
            createdAt
        }
    )

    addLedger(town.id, 'election_start', 0, actor, ('Wahl #%s gestartet.'):format(id))
    notifyTownCitizens(town, ('Eine neue Bürgermeisterwahl in %s wurde gestartet.'):format(town.name))
    sendDiscord('electionStart', 'Wahl gestartet', ('In %s wurde eine neue Bürgermeisterwahl gestartet.'):format(town.name), {
        { name = 'Stadt', value = town.name, inline = true },
        { name = 'Kandidatur', value = ('%.1fh'):format(nominationHours), inline = true },
        { name = 'Abstimmung', value = ('%.1fh'):format(votingHours), inline = true }
    })
    if (Config.ElectionReminder or {}).NotifyOnStart ~= false then
        local election = BMDB.activeElection(town.id)
        sendElectionReminder(town, election, true)
    end
    notify(source, ('Wahl gestartet: Kandidatur %.1fh, Abstimmung %.1fh.'):format(nominationHours, votingHours))
end

RegisterNetEvent(RESOURCE .. ':server:startElectionFromHall', function(nominationHours, votingHours)
    local source = source
    if not isAdmin(source) then
        notify(source, Config.Text.NoPermission)
        return
    end

    startElection(source, nominationHours, votingHours)
end)

RegisterNetEvent(RESOURCE .. ':server:endElectionFromHall', function()
    local source = source
    if not isAdmin(source) then
        notify(source, Config.Text.NoPermission)
        return
    end

    local town = getTown(source)
    local election = BMDB.activeElection(town.id)
    if not election then
        notify(source, 'Keine aktive Wahl.')
        return
    end

    local _, message = finishElection(election.id, characterInfo(source))
    notify(source, message)
end)

RegisterCommand(Config.Commands.Admin, function(source, args)
    if not ensureStarted() then
        return
    end

    if not isAdmin(source) then
        notify(source, Config.Text.NoPermission)
        return
    end

    local commandTownKey = nil
    if BMDB.isTownKey(args[1]) then
        commandTownKey = tostring(args[1])
        setActiveTown(source, commandTownKey)
        table.remove(args, 1)
    end
    local townContext = commandTownKey or source

    local sub = tostring(args[1] or ''):lower()
    if sub == '' then
        if source == 0 then
            notify(source, ('Nutzung: /%s [stadtkey] start [kandidatur_stunden] [wahl_stunden] | end | settax [waren_einkauf] [waren_verkauf] [waffen_einkauf] [waffen_verkauf] | treasury'):format(Config.Commands.Admin))
            return
        end

        TriggerClientEvent(RESOURCE .. ':client:openAdminWindow', source, commandTownKey)
    elseif sub == 'start' then
        startElection(source, args[2], args[3], townContext)
    elseif sub == 'end' then
        local town = getTown(townContext)
        local election = BMDB.activeElection(town.id)
        if not election then
            notify(source, 'Keine aktive Wahl.')
            return
        end
        local ok, message = finishElection(election.id, source > 0 and characterInfo(source) or nil)
        notify(source, message)
    elseif sub == 'settax' then
        if not args[2] or not args[3] then
            notify(source, ('Nutzung: /%s settax [waren_einkauf] [waren_verkauf] [waffen_einkauf] [waffen_verkauf]'):format(Config.Commands.Admin))
            return
        end

        local town = getTown(townContext)
        local updates = {}

        if args[4] and args[5] then
            local goodsOk, goodsMessage, goodsBuy, goodsSell = validateTaxRates(args[2], args[3])
            if not goodsOk then
                notify(source, ('Waren: %s'):format(goodsMessage))
                return
            end

            local weaponsOk, weaponsMessage, weaponsBuy, weaponsSell = validateTaxRates(args[4], args[5])
            if not weaponsOk then
                notify(source, ('Waffen: %s'):format(weaponsMessage))
                return
            end

            updates = {
                { category = 'goods', label = marketCategory('goods') and marketCategory('goods').label or 'Waren', buyRate = goodsBuy, sellRate = goodsSell },
                { category = 'weapons', label = marketCategory('weapons') and marketCategory('weapons').label or 'Waffen', buyRate = weaponsBuy, sellRate = weaponsSell }
            }
        else
            local ok, message, buyRate, sellRate = validateTaxRates(args[2], args[3])
            if not ok then
                notify(source, message)
                return
            end

            setAllMarketCategoryTaxes(town, buyRate, sellRate)
            updates = {
                { category = 'all', label = 'Alle Kategorien', buyRate = buyRate, sellRate = sellRate }
            }
        end

        for _, update in ipairs(updates) do
            if update.category ~= 'all' then
                MySQL.insert.await(
                    [[
                        INSERT INTO bm_market_taxes
                            (town_id, category, category_label, buy_tax_rate, sell_tax_rate, updated_at)
                        VALUES (?, ?, ?, ?, ?, ?)
                        ON DUPLICATE KEY UPDATE
                            category_label = VALUES(category_label),
                            buy_tax_rate = VALUES(buy_tax_rate),
                            sell_tax_rate = VALUES(sell_tax_rate),
                            updated_at = VALUES(updated_at)
                    ]],
                    { town.id, update.category, update.label, update.buyRate, update.sellRate, now() }
                )
            end
        end

        local primary = updates[1]
        MySQL.update.await(
            'UPDATE bm_towns SET tax_rate = ?, tax_buy_rate = ?, tax_sell_rate = ? WHERE id = ?',
            { primary.buyRate, primary.buyRate, primary.sellRate, town.id }
        )

        local notes = {}
        for _, update in ipairs(updates) do
            notes[#notes + 1] = ('%s E %.2f%% / V %.2f%%'):format(update.label, update.buyRate, update.sellRate)
        end

        local note = table.concat(notes, ', ')
        addLedger(town.id, 'admin_tax_change', 0, source > 0 and characterInfo(source) or nil, note)
        sendDiscord('taxChange', 'Admin setzt Steuern', ('In %s wurden die Steuern per Admin-Command gesetzt.'):format(town.name), {
            { name = 'Stadt', value = town.name, inline = true },
            { name = 'Steuern', value = note, inline = false }
        })
        notify(source, ('Steuern gesetzt: %s'):format(note))
    elseif sub == 'treasury' then
        local town = getTown(townContext)
        local taxes = marketCategoryTaxMap(town)
        local goods = taxes.goods
        local weapons = taxes.weapons
        notify(source, ('Stadtkasse %s: %s, Waren E %.2f%%/V %.2f%%, Waffen E %.2f%%/V %.2f%%'):format(
            town.name,
            money(town.treasury),
            goods and goods.buyRate or 0,
            goods and goods.sellRate or 0,
            weapons and weapons.buyRate or 0,
            weapons and weapons.sellRate or 0
        ))
    else
        notify(source, ('Nutzung: /%s [stadtkey] start [kandidatur_stunden] [wahl_stunden] | end | settax [waren_einkauf] [waren_verkauf] [waffen_einkauf] [waffen_verkauf] | treasury'):format(Config.Commands.Admin))
    end
end, false)

AddEventHandler('vorp:SelectedCharacter', function(source)
    CreateThread(function()
        Wait(5000)
        local info = characterInfo(source)
        if not info then
            return
        end

        local pending = BMDB.pendingPayoutTotal(info.charid)
        if pending > 0 then
            notify(source, ('Du hast offene Markthallen-Auszahlungen: %s. Hole sie in der Markthalle ab.'):format(money(pending)))
        end

        local pendingItems = BMDB.pendingItemReturnCount(info.charid)
        if pendingItems > 0 then
            notify(source, ('Du hast offene Warenrueckgaben in der Markthalle: %s Items.'):format(pendingItems))
        end
    end)
end)

CreateThread(function()
    Wait(1500)
    runUpdateChecker(false)
    BMDB.bootstrap()
    BMDB.ensureAllTowns()
    for _, townKey in ipairs(BMDB.townKeys()) do
        local town = getTown(townKey)
        syncMarketStock(town)
        syncMarketTaxes(town)
    end
    started = true
    debugLog('Bürgermeistersystem bereit.')

    while true do
        Wait(60000)
        for _, townKey in ipairs(BMDB.townKeys()) do
            local town = getTown(townKey)
            local election = BMDB.activeElection(town.id)
            if election then
                local phase = electionPhase(election)
                if phase == 'finished' then
                    finishElection(election.id, nil)
                else
                    sendElectionReminder(town, election, false)
                end
            end
        end
    end
end)
