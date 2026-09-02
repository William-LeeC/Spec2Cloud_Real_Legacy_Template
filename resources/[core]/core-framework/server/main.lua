-- Core Player Framework & Persistence (specs/frd-core-framework.md)
-- Owns: player identification, character load/save lifecycle, and the
-- session API that currency-system (and future job resources) build on.
-- Implements no gameplay content of its own.

local loadedCharacters = {} -- [source] = { identifier, name, cash, bank, job }

-- ---------------------------------------------------------------------
-- Persistence helpers
-- ---------------------------------------------------------------------

local function fetchCharacterRow(identifier)
    local ok, rows = pcall(function()
        return MySQL.query.await('SELECT * FROM characters WHERE identifier = ?', { identifier })
    end)

    if not ok or rows == nil then
        return nil, 'db-error'
    end

    return rows[1], nil
end

local function insertNewCharacter(identifier)
    -- Two near-simultaneous first connections from the same identifier can
    -- both observe "no existing row" before either INSERT lands. The
    -- `identifier` PRIMARY KEY makes the DB reject the losing INSERT
    -- (FRD edge case: "two rapid reconnects... must not create duplicate
    -- rows or race on load") rather than creating a duplicate. Callers
    -- treat a failed insert here as "someone else just created it" and
    -- re-fetch, not as a hard failure.
    local ok = pcall(function()
        MySQL.insert.await('INSERT INTO characters (identifier, name) VALUES (?, ?)', { identifier, Config.DefaultCharacterName })
    end)

    return ok
end

local function loadOrCreateCharacter(identifier)
    local row, err = fetchCharacterRow(identifier)
    if err then
        return nil, false, err
    end

    if row then
        pcall(function()
            MySQL.update.await('UPDATE characters SET last_login = CURRENT_TIMESTAMP WHERE identifier = ?', { identifier })
        end)
        return row, false, nil
    end

    if not insertNewCharacter(identifier) then
        row, err = fetchCharacterRow(identifier)
        if row then
            return row, false, nil
        end
        return nil, false, err or 'db-error'
    end

    row, err = fetchCharacterRow(identifier)
    if err or not row then
        return nil, false, 'db-error'
    end

    return row, true, nil
end

local function saveCharacter(src)
    local character = loadedCharacters[src]
    if not character then return false end

    local ok = pcall(function()
        MySQL.update.await(
            'UPDATE characters SET name = ?, cash = ?, bank = ?, job = ? WHERE identifier = ?',
            { character.name, character.cash, character.bank, character.job, character.identifier }
        )
    end)

    if not ok then
        print(('[core-framework] CRITICAL: failed to save character (source %s, identifier %s)'):format(src, character.identifier))
    end

    return ok
end

-- ---------------------------------------------------------------------
-- Connection lifecycle
-- ---------------------------------------------------------------------

AddEventHandler('playerConnecting', function(_, _, deferrals)
    local src = source
    deferrals.defer()
    Wait(0)

    deferrals.update('Verifying your account...')

    local identifier = GetPlayerIdentifierByType(src, 'license')
    if not identifier then
        deferrals.done('Unable to verify your account. Please restart FiveM and try again.')
        return
    end

    local character, isNewCharacter, err = loadOrCreateCharacter(identifier)

    if err then
        deferrals.done('Server is temporarily unavailable. Please try again shortly.')
        return
    end

    -- Guard against this server slot having been reassigned to a different
    -- connecting player while the DB round-trip above was in flight.
    if GetPlayerIdentifierByType(src, 'license') ~= identifier then
        deferrals.done('Connection state changed during setup. Please reconnect.')
        return
    end

    loadedCharacters[src] = character
    deferrals.done()

    TriggerEvent('framework:characterLoaded', src, isNewCharacter)
end)

AddEventHandler('playerDropped', function()
    local src = source
    if loadedCharacters[src] then
        saveCharacter(src)
        TriggerEvent('framework:characterUnloaded', src)
        loadedCharacters[src] = nil
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    -- Planned shutdown: flush every connected character before the
    -- process goes down (FRD edge case).
    for src in pairs(loadedCharacters) do
        saveCharacter(src)
    end
end)

-- ---------------------------------------------------------------------
-- Periodic save (FR5)
-- ---------------------------------------------------------------------

CreateThread(function()
    while true do
        Wait(Config.SaveIntervalMs)
        for src in pairs(loadedCharacters) do
            saveCharacter(src)
        end
    end
end)

-- ---------------------------------------------------------------------
-- Session API (FR6) - consumed by currency-system and future resources
-- ---------------------------------------------------------------------

exports('GetCharacter', function(src)
    return loadedCharacters[src]
end)

exports('IsCharacterLoaded', function(src)
    return loadedCharacters[src] ~= nil
end)

exports('SaveCharacter', function(src)
    return saveCharacter(src)
end)
