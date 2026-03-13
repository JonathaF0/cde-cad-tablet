-- client/main.lua
-- CAD Tablet & Call Details Popup

local tabletOpen    = false
local popupVisible  = false
local callData      = {}
local callIndex     = 1
local lastOpenTime  = 0
local openDebounce  = 500
local tabletProp    = nil

local TABLET_ANIM_DICT = "amb@code_human_in_bus_passenger_idles@female@tablet@base"
local TABLET_ANIM_NAME = "base"
local TABLET_PROP_MODEL = "prop_cs_tablet"

-- ─── Debug helper ────────────────────────────────────────────────────────────
local function dbg(msg)
    print("^5[CAD-TABLET] " .. msg .. "^0")
end

-- ─── Duty check (Standalone / CDE) ──────────────────────────────────────────
local function isOnDuty()
    if not Config.RequireOnDuty then return true end
    if not Config.Framework.Standalone then return true end

    if GetResourceState('CDE_Duty') ~= 'started' then return false end

    local ok, result = pcall(function()
        return exports.CDE_Duty:GetDutyStatus()
    end)
    if ok and result then return result.onDuty end

    local ok2, isLEO = pcall(function()
        return exports.CDE_Duty:IsOnDutyLEO()
    end)
    return ok2 and isLEO or false
end

-- ─── Tablet open / close ─────────────────────────────────────────────────────
local function cleanupProp()
    local ped = PlayerPedId()
    ClearPedTasks(ped)
    if tabletProp and DoesEntityExist(tabletProp) then
        DeleteEntity(tabletProp)
        tabletProp = nil
    end
end

local function closeTablet()
    if not tabletOpen then return end
    dbg("closeTablet() called")

    tabletOpen = false
    lastOpenTime = GetGameTimer()

    cleanupProp()

    Citizen.Wait(100)

    SetNuiFocusKeepInput(false)
    SetNuiFocus(false, false)
    SendNUIMessage({ type = "closeTablet" })

    dbg("Tablet closed — NUI focus released")
end

local function openTablet()
    if tabletOpen then return end
    if not isOnDuty() then
        dbg("Cannot open tablet — not on duty")
        return
    end

    -- Debounce rapid toggles
    if (GetGameTimer() - lastOpenTime) < openDebounce then return end

    dbg("openTablet() called")
    tabletOpen = true
    lastOpenTime = GetGameTimer()

    -- Play tablet animation and attach prop
    local ped = PlayerPedId()
    RequestAnimDict(TABLET_ANIM_DICT)
    while not HasAnimDictLoaded(TABLET_ANIM_DICT) do
        Citizen.Wait(100)
    end

    tabletProp = CreateObject(GetHashKey(TABLET_PROP_MODEL), 0, 0, 0, true, true, true)
    AttachEntityToEntity(
        tabletProp, ped, GetPedBoneIndex(ped, 60309),
        0.03, 0.002, -0.02,
        0.0, 0.0, 0.0,
        true, true, false, true, 1, true
    )
    TaskPlayAnim(ped, TABLET_ANIM_DICT, TABLET_ANIM_NAME, 8.0, -8.0, -1, 50, 0, false, false, false)

    Citizen.Wait(200)
    SendNUIMessage({ type = "openTablet", url = Config.TabletURL, dimmer = Config.TabletDimmer })
    SetNuiFocus(true, true)

    dbg("Tablet opened")
end

local function toggleTablet()
    dbg("toggleTablet() — tabletOpen=" .. tostring(tabletOpen))
    if tabletOpen then closeTablet() else openTablet() end
end

-- ─── Call popup ──────────────────────────────────────────────────────────────
local function showPopup()
    if popupVisible then return end
    popupVisible = true
    SendNUIMessage({ type = "showPopup" })
    TriggerServerEvent('cad-tablet:requestCalls')
    dbg("Popup shown")
end

local function hidePopup()
    if not popupVisible then return end
    popupVisible = false
    SendNUIMessage({ type = "hidePopup" })
    dbg("Popup hidden")
end

local function togglePopup()
    if popupVisible then hidePopup() else showPopup() end
end

-- ─── Receive call data from server ───────────────────────────────────────────
RegisterNetEvent('cad-tablet:receiveCalls')
AddEventHandler('cad-tablet:receiveCalls', function(calls)
    callData = calls or {}
    if callIndex > #callData then callIndex = #callData end
    if callIndex < 1 then callIndex = 1 end

    SendNUIMessage({
        type       = "updateCalls",
        calls      = callData,
        callIndex  = callIndex,
        totalCalls = #callData,
    })
end)

-- ─── Polling thread — only runs while popup is visible ───────────────────────
local function startPolling()
    Citizen.CreateThread(function()
        while popupVisible do
            Citizen.Wait(Config.CallPollInterval)
            if popupVisible then
                TriggerServerEvent('cad-tablet:requestCalls')
            end
        end
    end)
end

local _showPopup = showPopup
showPopup = function()
    _showPopup()
    startPolling()
end

-- ─── NUI callbacks ───────────────────────────────────────────────────────────
RegisterNUICallback('closeTablet', function(_, cb)
    dbg("NUI callback: closeTablet")
    closeTablet()
    cb('ok')
end)

RegisterNUICallback('prevCall', function(_, cb)
    if callIndex > 1 then
        callIndex = callIndex - 1
        SendNUIMessage({
            type       = "updateCalls",
            calls      = callData,
            callIndex  = callIndex,
            totalCalls = #callData,
        })
    end
    cb('ok')
end)

RegisterNUICallback('nextCall', function(_, cb)
    if callIndex < #callData then
        callIndex = callIndex + 1
        SendNUIMessage({
            type       = "updateCalls",
            calls      = callData,
            callIndex  = callIndex,
            totalCalls = #callData,
        })
    end
    cb('ok')
end)

RegisterNUICallback('closePopup', function(_, cb)
    hidePopup()
    cb('ok')
end)

-- ─── Commands ────────────────────────────────────────────────────────────────
-- Use the same command names as the old tablet script so existing keybinds work.
RegisterCommand('tablet', function()
    dbg("Command 'tablet' fired")
    toggleTablet()
end, false)

RegisterCommand('cad', function()
    dbg("Command 'cad' fired")
    toggleTablet()
end, false)

RegisterKeyMapping('tablet', Config.TabletDescription, 'keyboard', Config.TabletKey)

-- Emergency reset command
RegisterCommand('resetcad', function()
    dbg("Emergency reset triggered")
    cleanupProp()
    SetNuiFocusKeepInput(false)
    SetNuiFocus(false, false)
    SendNUIMessage({ type = "closeTablet" })
    tabletOpen = false
    lastOpenTime = GetGameTimer()
    dbg("Emergency reset complete")
end, false)

if Config.EnableCallPopup then
    RegisterCommand('cad_popup', function()
        if tabletOpen then return end
        togglePopup()
    end, false)
    RegisterKeyMapping('cad_popup', Config.CallPopupDescription, 'keyboard', Config.CallPopupKey)
end

-- ─── ESC close & death check thread ─────────────────────────────────────────
-- SetNuiFocus(true, true) blocks all game input. Control 200 (ESC) is still
-- detectable via IsControlJustReleased as FiveM always processes it.
-- NUI callbacks (× button) use GetParentResourceName() for correct routing.
Citizen.CreateThread(function()
    local deathCheck = 0
    while true do
        if tabletOpen then
            Citizen.Wait(0)
            if IsControlJustReleased(0, 200) then
                dbg("ESC pressed, closing tablet")
                closeTablet()
            end
            -- Death check every ~60 frames
            deathCheck = deathCheck + 1
            if deathCheck >= 60 then
                deathCheck = 0
                if IsEntityDead(PlayerPedId()) then
                    dbg("Player died, closing tablet")
                    closeTablet()
                end
            end
        else
            deathCheck = 0
            Citizen.Wait(500)
        end
    end
end)

-- ─── Cleanup ─────────────────────────────────────────────────────────────────
AddEventHandler('onResourceStop', function(res)
    if GetCurrentResourceName() ~= res then return end
    cleanupProp()
    SetNuiFocusKeepInput(false)
    SetNuiFocus(false, false)
end)

-- ─── Init ────────────────────────────────────────────────────────────────────
Citizen.CreateThread(function()
    -- Clear any stale NUI focus state from previous resource starts
    SetNuiFocusKeepInput(false)
    SetNuiFocus(false, false)
    Citizen.Wait(500)
    dbg("Initialized — Tablet key: " .. Config.TabletKey ..
         ", Popup key: " .. (Config.EnableCallPopup and Config.CallPopupKey or "disabled"))
end)
