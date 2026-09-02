-- Balance display (specs/frd-currency-system.md FR5) via ox_lib.

local function formatBalances(balances)
    return ('Cash: $%d | Bank: $%d'):format(balances.cash, balances.bank)
end

RegisterCommand('balance', function()
    local balances = lib.callback.await('currency-system:getBalances', false)
    if not balances then return end

    lib.notify({
        title = 'Balance',
        description = formatBalances(balances),
        type = 'inform'
    })
end, false)

RegisterNetEvent('currency:balanceChanged', function(payload)
    lib.notify({
        title = 'Balance Updated',
        description = formatBalances(payload),
        type = 'success'
    })
end)
