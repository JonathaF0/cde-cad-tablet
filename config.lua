Config = {}

-- ========================================
-- CAD BACKEND CONFIGURATION
-- ========================================
Config.CADEndpoint = "https://cdecad.com"   -- Your CAD backend URL (no trailing slash)
Config.APIKey      = ""                      -- Your community's FiveM API key (fvm_...)

-- ========================================
-- TABLET SETTINGS
-- ========================================
-- The URL to load when the tablet opens
Config.TabletURL   = "https://cdecad.com/login2"

-- Keybind to open/close the tablet (default: [ key)
-- Uses FiveM RegisterKeyMapping — players can rebind in Settings > Key Bindings > FiveM
Config.TabletKey         = "LBRACKET"
Config.TabletDescription = "Open/Close CAD Tablet"

-- Dim the tablet when the mouse moves outside of it
-- When true, the tablet fades to 15% opacity when the cursor leaves it
Config.TabletDimmer = false

-- Prevent the tablet from auto-redirecting to /home after login
-- When true, the NUI will block navigation to /home and stay on the current page
Config.PreventAutoRedirect = true

-- ========================================
-- CALL DETAILS POPUP SETTINGS
-- ========================================
-- On-screen popup showing details of calls you are attached to
Config.EnableCallPopup = true

-- Keybind to toggle the call details popup (default: G key)
Config.CallPopupKey         = "G"
Config.CallPopupDescription = "Toggle Call Details Popup"

-- How often (in ms) to poll the CAD for updated call data
-- Only polls while the popup is visible; stops when hidden
Config.CallPollInterval = 10000  -- 10 seconds

-- Auto-hide the popup after this many seconds (0 = never auto-hide)
Config.CallPopupAutoHide = 0

-- ========================================
-- FRAMEWORK SETTINGS
-- ========================================
Config.Framework = {
    Standalone = true,   -- Use CDE Duty System (no ESX/QBCore)
    ESX        = false,  -- ESX Framework
    QBCore     = false,  -- QB-Core Framework
}

-- Only allow the tablet to open while on duty (Standalone/CDE only)
Config.RequireOnDuty = false

-- ========================================
-- LOCATION TRACKING (optional — replaces cde_lm livemap)
-- ========================================
-- When enabled, this resource pushes the player's GPS location to the CAD
-- livemap on a timer, mirroring what cde_lm does. Useful for servers that
-- don't want to run a separate livemap script.
--
-- IMPORTANT: do NOT enable this if you also run cde_lm — you'll get duplicate
-- updates. The resource will print a warning if it detects cde_lm running.
Config.LocationTracking = {
    Enabled         = false,         -- Master switch (off by default)

    -- Where to read the player's duty status from:
    --   'auto'     — try CDE_Duty → ESX → QBCore → CAD (in that order)
    --   'cde_duty' — exports.CDE_Duty:GetDutyStatus()
    --   'esx'      — ESX PlayerData.job
    --   'qbcore'   — QBCore PlayerData.job
    --   'cad'      — poll CAD's /api/fivem/unit-active (no duty script needed;
    --                user goes "on duty" by clicking Begin Shift in CAD)
    DutySource      = 'auto',

    Interval        = 10000,         -- ms between location pushes
    MinDistance     = 50.0,          -- GTA units; skip update if moved less
    LEOOnly         = false,         -- only track LEO (police/sheriff) depts

    -- For DutySource = 'cad': how often to ask the CAD if the user is active.
    -- Cheap call (lean DB read), but no need to hammer it.
    CADActiveCheckInterval = 30000,

    SendOfflineOnDisconnect = true,  -- Push status='Offline' on resource stop
}

-- ========================================
-- OPTIMIZATION SETTINGS
-- ========================================
Config.EnableDebug = false  -- Enable verbose debug logging
