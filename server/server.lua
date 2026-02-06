-- Server-side script for CAD status retention
-- Add this as server/server.lua in your resource

local playerStatuses = {}
local statusSaveInterval = 300000 -- 5 minutes in milliseconds

-- Function to save player status
local function SavePlayerStatus(source, statusData)
    local identifier = GetPlayerIdentifier(source, 0) -- Steam ID or license
    if not identifier then return end
    
    playerStatuses[identifier] = {
        status = statusData.status or "10-7", -- Default to off-duty
        location = statusData.location or "",
        callsign = statusData.callsign or "",
        unit = statusData.unit or "",
        timestamp = os.time(),
        source = source
    }
    
    print(("^2[CAD-TABLET] Saved status for %s: %s^0"):format(identifier, statusData.status))
end

-- Function to get player status
local function GetPlayerStatus(source)
    local identifier = GetPlayerIdentifier(source, 0)
    if not identifier then return nil end
    
    return playerStatuses[identifier]
end

-- Function to save all statuses to file (optional - for persistence across server restarts)
local function SaveStatusesToFile()
    local file = io.open(GetResourcePath(GetCurrentResourceName()) .. '/status_data.json', 'w')
    if file then
        file:write(json.encode(playerStatuses))
        file:close()
        print("^2[CAD-TABLET] Saved all player statuses to file^0")
    end
end

-- Function to load statuses from file
local function LoadStatusesFromFile()
    local file = io.open(GetResourcePath(GetCurrentResourceName()) .. '/status_data.json', 'r')
    if file then
        local content = file:read('*all')
        file:close()
        
        local data = json.decode(content)
        if data then
            playerStatuses = data
            print("^2[CAD-TABLET] Loaded player statuses from file^0")
        end
    end
end

-- Register server events
RegisterServerEvent('cad:saveStatus')
AddEventHandler('cad:saveStatus', function(statusData)
    local source = source
    SavePlayerStatus(source, statusData)
end)

RegisterServerEvent('cad:requestStatus')
AddEventHandler('cad:requestStatus', function()
    local source = source
    local status = GetPlayerStatus(source)
    
    if status then
        TriggerClientEvent('cad:receiveStatus', source, status)
    end
end)

-- Clean up disconnected players
AddEventHandler('playerDropped', function(reason)
    local source = source
    local identifier = GetPlayerIdentifier(source, 0)
    
    if identifier and playerStatuses[identifier] then
        -- Mark as disconnected but keep status for a while
        playerStatuses[identifier].disconnected = true
        playerStatuses[identifier].disconnectTime = os.time()
    end
end)

-- Periodic cleanup of old disconnected players (remove after 24 hours)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(3600000) -- Check every hour
        
        local currentTime = os.time()
        local toRemove = {}
        
        for identifier, data in pairs(playerStatuses) do
            if data.disconnected and (currentTime - data.disconnectTime) > 86400 then -- 24 hours
                table.insert(toRemove, identifier)
            end
        end
        
        for _, identifier in ipairs(toRemove) do
            playerStatuses[identifier] = nil
            print(("^3[CAD-TABLET] Cleaned up old status for %s^0"):format(identifier))
        end
    end
end)

-- Auto-save statuses periodically
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(statusSaveInterval)
        SaveStatusesToFile()
    end
end)

-- Load statuses on resource start
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        LoadStatusesFromFile()
    end
end)

-- Save statuses on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        SaveStatusesToFile()
    end
end)

-- Export functions for other resources
exports('getPlayerStatus', GetPlayerStatus)
exports('savePlayerStatus', SavePlayerStatus)
exports('getAllStatuses', function()
    return playerStatuses
end)

print("^2[CAD-TABLET] Server script loaded - Status retention enabled^0")
