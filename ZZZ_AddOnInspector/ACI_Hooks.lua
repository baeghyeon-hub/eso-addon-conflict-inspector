----------------------------------------------------------------------
-- ACI_Hooks.lua — PreHook install (RegisterForEvent, ZO_SavedVars)
----------------------------------------------------------------------

-- Extract addon folder name from debug.traceback
-- Looks for "user:/AddOns/<FolderName>/" pattern
local function CallerFromTraceback(trace)
    local folder = trace:match("user:/AddOns/([^/]+)/")
    return folder
end

----------------------------------------------------------------------
-- RegisterForEvent interception
----------------------------------------------------------------------
function ACI.InstallEventHook()
    ZO_PreHook(EVENT_MANAGER, "RegisterForEvent", function(self, namespace, eventCode, callback, ...)
        local trace = debug.traceback("", 2)
        local caller = CallerFromTraceback(trace)
        table.insert(ACI.eventLog, {
            ts         = GetGameTimeMilliseconds(),
            namespace  = namespace or "?",
            eventCode  = eventCode or -1,
            callbackId = tostring(callback),
            caller     = caller,
        })
    end)
    ACI.hookInstalled = true
end

----------------------------------------------------------------------
-- ZO_SavedVars constructor hooking
----------------------------------------------------------------------
local function RecordSVCall(method, tableName, version, namespace)
    local ns = tostring(namespace or "Default")
    local key = tostring(tableName) .. "::" .. ns
    if not ACI.svRegistrations[key] then
        ACI.svRegistrations[key] = {}
    end
    local trace = debug.traceback("", 3)
    local caller = CallerFromTraceback(trace) or ACI.lastLoadedAddon or "unknown"
    table.insert(ACI.svRegistrations[key], {
        method    = method,
        version   = version,
        caller    = caller,
        ts        = GetGameTimeMilliseconds(),
        traceback = trace,
    })
end

function ACI.InstallSVHooks()
    if not ZO_SavedVars then return false end

    -- ZO_SavedVars methods can be called two ways:
    --   Colon: ZO_SavedVars:New(tableName, version, ns, defaults)  → self=ZO_SavedVars, t=tableName
    --   Dot:   ZO_SavedVars.New(tableName, version, ns, defaults)  → self=tableName, t=version
    -- Detect by checking if self is a string (dot call) or table (colon call)
    ZO_PreHook(ZO_SavedVars, "NewAccountWide", function(self, t, v, ns, ...)
        if type(self) == "string" then
            RecordSVCall("NewAccountWide", self, t, v)
        else
            RecordSVCall("NewAccountWide", t, v, ns)
        end
    end)
    ZO_PreHook(ZO_SavedVars, "NewCharacterIdSettings", function(self, t, v, ns, ...)
        if type(self) == "string" then
            RecordSVCall("NewCharacterIdSettings", self, t, v)
        else
            RecordSVCall("NewCharacterIdSettings", t, v, ns)
        end
    end)
    if ZO_SavedVars.NewCharacterSettings then
        ZO_PreHook(ZO_SavedVars, "NewCharacterSettings", function(self, t, v, ns, ...)
            if type(self) == "string" then
                RecordSVCall("NewCharacterSettings", self, t, v)
            else
                RecordSVCall("NewCharacterSettings", t, v, ns)
            end
        end)
    end
    if ZO_SavedVars.New then
        ZO_PreHook(ZO_SavedVars, "New", function(self, t, v, ns, ...)
            if type(self) == "string" then
                RecordSVCall("New", self, t, v)
            else
                RecordSVCall("New", t, v, ns)
            end
        end)
    end
    return true
end
