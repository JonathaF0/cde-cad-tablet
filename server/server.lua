-- server/main.lua
-- CAD Tablet Server — Fetches assigned calls from CAD API for the popup

local function debugLog(msg)
    if Config.EnableDebug then
        print("^5[CAD-TABLET-SV] " .. msg .. "^0")
    end
end

-- ─── Build API URL ───────────────────────────────────────────────────────────
local function apiUrl(path)
    local base = Config.CADEndpoint
    if base:sub(-1) == '/' then base = base:sub(1, -2) end
    return base .. path
end

-- ─── Fetch assigned calls for a player ───────────────────────────────────────
RegisterNetEvent('cad-tablet:requestCalls')
AddEventHandler('cad-tablet:requestCalls', function()
    local src = source
    if not src or src <= 0 then return end

    local identifiers = GetPlayerIdentifiers(src)
    local discordId = nil

    for _, id in ipairs(identifiers) do
        if id:sub(1, 8) == 'discord:' then
            discordId = id:sub(9)
            break
        end
    end

    if not discordId then
        debugLog("No Discord identifier for player " .. src)
        TriggerClientEvent('cad-tablet:receiveCalls', src, {})
        return
    end

    local url = apiUrl('/api/fivem/unit-calls?discordId=' .. discordId)
    debugLog("Fetching calls for discord:" .. discordId)

    PerformHttpRequest(url, function(statusCode, body, headers)
        if statusCode ~= 200 then
            debugLog("API error " .. tostring(statusCode) .. ": " .. tostring(body))
            TriggerClientEvent('cad-tablet:receiveCalls', src, {})
            return
        end

        local ok, data = pcall(json.decode, body)
        if not ok or not data or not data.success then
            debugLog("Failed to parse response")
            TriggerClientEvent('cad-tablet:receiveCalls', src, {})
            return
        end

        debugLog("Got " .. #(data.calls or {}) .. " calls for player " .. src)
        TriggerClientEvent('cad-tablet:receiveCalls', src, data.calls or {})
    end, 'GET', '', {
        ['Content-Type']  = 'application/json',
        ['x-api-key']     = Config.APIKey,
    })
end)

-- ─── Init ────────────────────────────────────────────────────────────────────
AddEventHandler('onResourceStart', function(res)
    if GetCurrentResourceName() ~= res then return end
    print("^2[CAD-TABLET] Server initialized^0")
end)
