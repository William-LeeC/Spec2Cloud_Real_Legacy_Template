-- Currency System (specs/frd-currency-system.md)
-- Dual-balance (cash/bank) transactions on top of core-framework's
-- character session. Implements no job/paycheck content of its own -
-- FR8's /testpay command exists only to prove this loop end-to-end
-- until Increment 2 delivers a real job.

-- ---------------------------------------------------------------------
-- Atomicity note (FR2, AC4)
-- ---------------------------------------------------------------------
-- FXServer's Lua VM is single-threaded with cooperative coroutines: a
-- handler only yields at an explicit await/Wait point. Every transaction
-- function below reads and mutates the in-memory character table in one
-- unbroken block with NO yield in between, so two concurrent calls for
-- the same character can never interleave mid-mutation - that's what
-- gives us atomicity without an explicit lock. Persistence (SaveCharacter,
-- which awaits a DB write) only happens AFTER the in-memory mutation is
-- complete. Do not restructure these functions to await anything before
-- the mutation is applied.

local function validateAmount(amount)
    return type(amount) == 'number' and amount == math.floor(amount) and amount >= 0
end

local function notifyBalance(src, character, reason)
    local payload = { cash = character.cash, bank = character.bank, reason = reason }
    -- Server-side listeners (future job/economy resources) get this
    -- without polling; the owning client gets it too, for FR5's HUD/UI.
    TriggerEvent('currency:balanceChanged', src, payload)
    TriggerClientEvent('currency:balanceChanged', src, payload)
end

local function persist(src)
    exports['core-framework']:SaveCharacter(src)
end

local function AddCash(src, amount)
    if not validateAmount(amount) then return false end
    local character = exports['core-framework']:GetCharacter(src)
    if not character then return false end

    character.cash = character.cash + amount
    persist(src)
    notifyBalance(src, character, 'add-cash')
    return true
end

local function RemoveCash(src, amount)
    if not validateAmount(amount) then return false end
    local character = exports['core-framework']:GetCharacter(src)
    if not character then return false end
    if character.cash < amount then return false end

    character.cash = character.cash - amount
    persist(src)
    notifyBalance(src, character, 'remove-cash')
    return true
end

local function AddBank(src, amount)
    if not validateAmount(amount) then return false end
    local character = exports['core-framework']:GetCharacter(src)
    if not character then return false end

    character.bank = character.bank + amount
    persist(src)
    notifyBalance(src, character, 'add-bank')
    return true
end

local function RemoveBank(src, amount)
    if not validateAmount(amount) then return false end
    local character = exports['core-framework']:GetCharacter(src)
    if not character then return false end
    if character.bank < amount then return false end

    character.bank = character.bank - amount
    persist(src)
    notifyBalance(src, character, 'remove-bank')
    return true
end

local function Transfer(src, direction, amount)
    if not validateAmount(amount) then return false end
    local character = exports['core-framework']:GetCharacter(src)
    if not character then return false end

    if amount == 0 then return true end -- edge case: no-op success

    if direction == 'cashToBank' then
        if character.cash < amount then return false end
        character.cash = character.cash - amount
        character.bank = character.bank + amount
    elseif direction == 'bankToCash' then
        if character.bank < amount then return false end
        character.bank = character.bank - amount
        character.cash = character.cash + amount
    else
        return false
    end

    persist(src)
    notifyBalance(src, character, 'transfer:' .. direction)
    return true
end

local function GetBalances(src)
    local character = exports['core-framework']:GetCharacter(src)
    if not character then return nil end
    return { cash = character.cash, bank = character.bank }
end

-- ---------------------------------------------------------------------
-- Exports (API contract for future job/economy resources)
-- ---------------------------------------------------------------------

exports('AddCash', AddCash)
exports('RemoveCash', RemoveCash)
exports('AddBank', AddBank)
exports('RemoveBank', RemoveBank)
exports('Transfer', Transfer)
exports('GetBalances', GetBalances)

lib.callback.register('currency-system:getBalances', function(source)
    return GetBalances(source)
end)

-- ---------------------------------------------------------------------
-- FR6: starting balance grant on first-ever connection
-- ---------------------------------------------------------------------

AddEventHandler('framework:characterLoaded', function(src, isNewCharacter)
    if not isNewCharacter then return end
    AddCash(src, Config.StartingCash)
    AddBank(src, Config.StartingBank)
end)

-- ---------------------------------------------------------------------
-- FR8: temporary verification hook - remove/lock down once Increment 2
-- ships real jobs. Permission grant lives in server.cfg (ACE), never
-- hardcode identifiers here.
-- ---------------------------------------------------------------------

RegisterCommand('testpay', function(src, args)
    if not IsPlayerAceAllowed(src, 'currency.test') then
        TriggerClientEvent('chat:addMessage', src, { args = { '^1SYSTEM', 'Insufficient permissions.' } })
        return
    end

    local amount = tonumber(args[1])
    if not validateAmount(amount) then
        TriggerClientEvent('chat:addMessage', src, { args = { '^1SYSTEM', 'Usage: /testpay <positive whole number>' } })
        return
    end

    if AddCash(src, amount) then
        print(('[currency-system] /testpay: source %s paid $%d (test command)'):format(src, amount))
    end
end, false)

-- ---------------------------------------------------------------------
-- FR7: admin balance adjustment, audited. Amount may be negative to
-- remove funds. Online players only (documented limitation).
-- ---------------------------------------------------------------------

RegisterCommand('setmoney', function(src, args)
    if not IsPlayerAceAllowed(src, 'currency.admin') then
        TriggerClientEvent('chat:addMessage', src, { args = { '^1SYSTEM', 'Insufficient permissions.' } })
        return
    end

    local targetId = tonumber(args[1])
    local balanceType = args[2]
    local amount = tonumber(args[3])
    local reason = table.concat(args, ' ', 4) ~= '' and table.concat(args, ' ', 4) or 'no reason given'

    if not targetId or (balanceType ~= 'cash' and balanceType ~= 'bank') or amount == nil then
        TriggerClientEvent('chat:addMessage', src, { args = { '^1SYSTEM', 'Usage: /setmoney <serverId> <cash|bank> <amount> <reason>' } })
        return
    end

    if not exports['core-framework']:IsCharacterLoaded(targetId) then
        TriggerClientEvent('chat:addMessage', src, { args = { '^1SYSTEM', 'Target player has no loaded character (must be online).' } })
        return
    end

    local ok
    if amount >= 0 then
        ok = (balanceType == 'cash') and AddCash(targetId, amount) or AddBank(targetId, amount)
    else
        ok = (balanceType == 'cash') and RemoveCash(targetId, -amount) or RemoveBank(targetId, -amount)
    end

    print(('[currency-system] AUDIT setmoney: admin_source=%s admin_identifier=%s target=%s type=%s amount=%d reason="%s" result=%s')
        :format(src, GetPlayerIdentifierByType(src, 'license') or 'unknown', targetId, balanceType, amount, reason, tostring(ok)))
end, false)
