-- CAD Tablet Client Script with File-Based Storage
local isTabletOpen = false
local cadUrl = "https://cad.tnsrp.com/login2"
local tabletStorage = {}

-- Load storage from file on resource start
Citizen.CreateThread(function()
    Wait(1000)
    local file = LoadResourceFile(GetCurrentResourceName(), "tablet_storage.json")
    if file then
        local success, decoded = pcall(json.decode, file)
        if success and decoded then
            tabletStorage = decoded
            print("^2[CAD-TABLET] Loaded storage from disk (" .. json.encode(tabletStorage):len() .. " bytes)^0")
        else
            print("^3[CAD-TABLET] Could not decode storage file^0")
            tabletStorage = {}
        end
    else
        print("^3[CAD-TABLET] No storage file found, starting fresh^0")
        tabletStorage = {}
    end
end)

-- Save storage to file
local function SaveStorage()
    local encoded = json.encode(tabletStorage)
    SaveResourceFile(GetCurrentResourceName(), "tablet_storage.json", encoded, -1)
    print("^2[CAD-TABLET] Saved storage to disk (" .. encoded:len() .. " bytes)^0")
end

-- NUI Callback: Get storage
RegisterNUICallback('getTabletStorage', function(data, cb)
    print("^3[CAD-TABLET] NUI requested storage^0")
    cb(tabletStorage)
end)

-- NUI Callback: Save storage
RegisterNUICallback('setTabletStorage', function(data, cb)
    print("^3[CAD-TABLET] NUI saving storage^0")
    tabletStorage = data
    SaveStorage()
    cb('ok')
end)

-- Function to close tablet
local function CloseTablet()
    if not isTabletOpen then return end
    
    print("^3[CAD-TABLET] Closing tablet^0")
    
    -- Clear NUI focus immediately
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    
    -- Send close message (this will trigger storage save in HTML)
    SendNUIMessage({type = "closeTablet"})
    
    -- Re-enable all controls
    EnableControlAction(0, 1, true)   -- Mouse look
    EnableControlAction(0, 2, true)   -- Mouse look
    EnableControlAction(0, 30, true)  -- Move left/right
    EnableControlAction(0, 31, true)  -- Move forward/back
    EnableControlAction(0, 21, true)  -- Sprint
    EnableControlAction(0, 22, true)  -- Jump
    EnableControlAction(0, 24, true)  -- Attack
    EnableControlAction(0, 25, true)  -- Aim
    EnableControlAction(0, 322, true) -- ESC
    
    -- Re-enable radar
    DisplayRadar(true)
    
    -- Update state
    isTabletOpen = false
    
    print("^2[CAD-TABLET] Tablet closed successfully^0")
end

-- Function to open tablet
local function OpenTablet()
    if isTabletOpen then return end
    
    print("^3[CAD-TABLET] Opening tablet^0")
    
    -- Update state first
    isTabletOpen = true
    
    -- Send message to NUI
    SendNUIMessage({
        type = "openTablet",
        url = cadUrl
    })
    
    -- Set NUI focus
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    
    -- Hide radar for immersion
    DisplayRadar(false)
    
    print("^2[CAD-TABLET] Tablet opened successfully^0")
end

-- Toggle function
local function ToggleTablet()
    if isTabletOpen then
        CloseTablet()
    else
        OpenTablet()
    end
end

-- Register commands
RegisterCommand('tablet', function()
    ToggleTablet()
end, false)

RegisterCommand('cad', function()
    ToggleTablet()
end, false)

-- Emergency reset command
RegisterCommand('resetcad', function()
    print("^1[CAD-TABLET] Emergency reset^0")
    
    -- Force everything off
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({type = "forceClose"})
    
    -- Re-enable all controls
    EnableControlAction(0, 1, true)
    EnableControlAction(0, 2, true)
    EnableControlAction(0, 30, true)
    EnableControlAction(0, 31, true)
    EnableControlAction(0, 21, true)
    EnableControlAction(0, 22, true)
    EnableControlAction(0, 24, true)
    EnableControlAction(0, 25, true)
    EnableControlAction(0, 322, true)
    
    DisplayRadar(true)
    isTabletOpen = false
    
    print("^2[CAD-TABLET] Reset complete^0")
end, false)

-- Clear storage command (for testing)
RegisterCommand('clearcad', function()
    print("^1[CAD-TABLET] Clearing storage^0")
    tabletStorage = {}
    SaveStorage()
    print("^2[CAD-TABLET] Storage cleared^0")
end, false)

-- Key mapping
RegisterKeyMapping('tablet', 'Toggle CAD Tablet', 'keyboard', 'LBRACKET')

-- NUI callback for closing
RegisterNUICallback('closeTablet', function(data, cb)
    CloseTablet()
    cb('ok')
end)

-- Simple control thread that only runs when tablet is open
CreateThread(function()
    while true do
        if isTabletOpen then
            -- Only disable movement and camera when tablet is open
            DisableControlAction(0, 1, true)   -- Mouse look left/right
            DisableControlAction(0, 2, true)   -- Mouse look up/down
            DisableControlAction(0, 30, true)  -- Move left/right
            DisableControlAction(0, 31, true)  -- Move forward/back
            
            -- Check for ESC key to close
            if IsDisabledControlJustPressed(0, 322) then
                CloseTablet()
            end
            
            -- Check if player died
            local playerPed = PlayerPedId()
            if IsEntityDead(playerPed) then
                CloseTablet()
            end
            
            Wait(0) -- Run every frame when tablet is open
        else
            Wait(1000) -- Wait 1 second when tablet is closed
        end
    end
end)

-- Add chat suggestions
CreateThread(function()
    TriggerEvent('chat:addSuggestion', '/tablet', 'Open/close CAD tablet')
    TriggerEvent('chat:addSuggestion', '/cad', 'Open/close CAD tablet')
    TriggerEvent('chat:addSuggestion', '/resetcad', 'Emergency reset CAD tablet')
    TriggerEvent('chat:addSuggestion', '/clearcad', 'Clear tablet storage (logout)')
end)

print("^2[CAD-TABLET] Client script with file-based storage loaded^0")
