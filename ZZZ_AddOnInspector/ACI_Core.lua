----------------------------------------------------------------------
-- ACI_Core.lua — global table, SV init, event lifecycle
----------------------------------------------------------------------

ACI = {}
ACI.name = "ZZZ_AddOnInspector"
ACI.version = "0.2.0"
ACI.eventLog = {}
ACI.svRegistrations = {}
ACI.loadOrder = {}
ACI.loadOrderMap = {}   -- addonName -> loadIndex (reverse lookup)
ACI.lastLoadedAddon = nil
ACI.hookInstalled = false
ACI.svHookInstalled = false

----------------------------------------------------------------------
-- Load order tracking (registered at file load time)
----------------------------------------------------------------------
local loadIndex = 0

local function OnAnyAddOnLoaded(eventCode, addonName)
    loadIndex = loadIndex + 1
    ACI.lastLoadedAddon = addonName
    ACI.loadOrderMap[addonName] = loadIndex
    table.insert(ACI.loadOrder, {
        index = loadIndex,
        addon = addonName,
        ts    = GetGameTimeMilliseconds(),
    })
end

EVENT_MANAGER:RegisterForEvent(ACI.name .. "_LoadOrder", EVENT_ADD_ON_LOADED, OnAnyAddOnLoaded)

----------------------------------------------------------------------
-- Utilities
----------------------------------------------------------------------

-- Check if namespace belongs to ACI (for self-filter)
function ACI.IsSelfNamespace(ns)
    return ns and ns:find(ACI.name, 1, true) ~= nil
end

function ACI.TableLength(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

function ACI.EnumerateMethods(obj)
    local methods = {}
    local mt = getmetatable(obj)
    if mt and mt.__index then
        for k, v in pairs(mt.__index) do
            if type(v) == "function" then
                table.insert(methods, k)
            end
        end
    end
    if type(obj) == "table" then
        for k, v in pairs(obj) do
            if type(v) == "function" then
                table.insert(methods, k)
            end
        end
    end
    table.sort(methods)
    return methods
end

----------------------------------------------------------------------
-- eventCode -> name mapping (collect EVENT_ prefixed globals)
-- Wrapped in pcall: pairs(_G) can crash on ESO protected globals
----------------------------------------------------------------------
function ACI.BuildEventNameMap()
    local map = {}
    pcall(function()
        for k, v in pairs(_G) do
            if type(v) == "number" and type(k) == "string" and k:sub(1, 6) == "EVENT_" then
                map[v] = k
            end
        end
    end)
    return map
end

ACI.eventNames = {}  -- Populated after PLAYER_ACTIVATED

function ACI.EventName(code)
    if not next(ACI.eventNames) then
        ACI.eventNames = ACI.BuildEventNameMap()
    end
    return ACI.eventNames[code] or tostring(code)
end

----------------------------------------------------------------------
-- Main initialization
----------------------------------------------------------------------
local function OnACILoaded(eventCode, addonName)
    if addonName ~= ACI.name then return end
    EVENT_MANAGER:UnregisterForEvent(ACI.name, EVENT_ADD_ON_LOADED)

    ACI_SavedVars = ACI_SavedVars or {}

    -- Install hooks (ACI_Hooks.lua)
    ACI.InstallEventHook()
    ACI.svHookInstalled = ACI.InstallSVHooks()

    -- Store live references in SV
    ACI_SavedVars.eventLog        = ACI.eventLog
    ACI_SavedVars.svRegistrations = ACI.svRegistrations
    ACI_SavedVars.loadOrder       = ACI.loadOrder

    -- Register commands immediately (works regardless of PLAYER_ACTIVATED errors)
    ACI.RegisterCommands()

    -- PLAYER_ACTIVATED: collect static data + initial report
    EVENT_MANAGER:RegisterForEvent(ACI.name, EVENT_PLAYER_ACTIVATED, function()
        EVENT_MANAGER:UnregisterForEvent(ACI.name, EVENT_PLAYER_ACTIVATED)
        EVENT_MANAGER:UnregisterForEvent(ACI.name .. "_LoadOrder", EVENT_ADD_ON_LOADED)

        -- Build eventCode -> name mapping
        ACI.eventNames = ACI.BuildEventNameMap()

        -- Collect metadata (ACI_Inventory.lua)
        ACI_SavedVars.metadata = ACI.CollectMetadata()
        ACI_SavedVars.svHookOk = ACI.svHookInstalled

        -- Delay report until chat UI is ready (zo_callLater)
        zo_callLater(function()
            ACI.PrintReport()
            d("[ACI] Type |c00FF00/aci|r for latest stats.")
        end, 1000)
    end)

    zo_callLater(function()
        d("[ACI] v" .. ACI.version .. " loaded. Hooks: Event=" .. tostring(ACI.hookInstalled) .. ", SV=" .. tostring(ACI.svHookInstalled))
    end, 500)
end

EVENT_MANAGER:RegisterForEvent(ACI.name, EVENT_ADD_ON_LOADED, OnACILoaded)
