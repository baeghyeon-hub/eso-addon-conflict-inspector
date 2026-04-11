----------------------------------------------------------------------
-- ACI_Hooks.lua — PreHook install (RegisterForEvent, ZO_SavedVars)
--
-- Caller identification note (v0.3.1):
-- Earlier versions used debug.traceback("", 2) inside the
-- RegisterForEvent prehook. This caused native ESO crashes when
-- certain other addons were loaded (confirmed with PortToFriendsHouse
-- on ESO live 11.3.5). Bisect proved both debug.traceback AND
-- debug.getinfo(3, "S") trigger the same crash, even when wrapped in
-- pcall — meaning ANY Lua-side stack inspection is unsafe inside this
-- prehook when the wrapped RegisterForEvent is called from ESO's
-- internal addon-loading C path.
--
-- Resolution: hook body never touches debug.*. Caller is approximated
-- via ACI.lastLoadedAddon, which is correct for file-scope register
-- calls (the common case) and a best-guess for dynamic registers.
-- Inaccurate caller is acceptable; native crash is not.
--
-- Escape hatch: ACI_SavedVars.disableEventHook (see /aci hooks).
----------------------------------------------------------------------

-- SV hook still uses the traceback path because it has not exhibited
-- the same crash pattern. If a future SV-hook conflict is reported,
-- apply the same lastLoadedAddon fallback here.
local function CallerFromTraceback(trace)
    return trace and trace:match("user:/AddOns/([^/]+)/") or nil
end

----------------------------------------------------------------------
-- RegisterForEvent interception
----------------------------------------------------------------------
function ACI.InstallEventHook()
    ZO_PreHook(EVENT_MANAGER, "RegisterForEvent",
            function(self, namespace, eventCode, callback, ...)
        -- NO debug.* calls here. See file header for the crash story.
        -- Caller is approximated via the most-recently loaded addon,
        -- which is the actual caller for file-scope register calls
        -- and a best-guess for dynamic ones. Marked as a guess so
        -- analysis can downgrade confidence accordingly.
        table.insert(ACI.eventLog, {
            ts            = GetGameTimeMilliseconds(),
            namespace     = namespace or "?",
            eventCode     = eventCode or -1,
            callbackId    = tostring(callback),
            caller        = ACI.lastLoadedAddon,
            callerIsGuess = true,
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
