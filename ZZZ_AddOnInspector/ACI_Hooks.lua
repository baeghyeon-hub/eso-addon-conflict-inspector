----------------------------------------------------------------------
-- ACI_Hooks.lua — PreHook 설치 (RegisterForEvent, ZO_SavedVars)
----------------------------------------------------------------------

----------------------------------------------------------------------
-- RegisterForEvent 가로채기
----------------------------------------------------------------------
function ACI.InstallEventHook()
    ZO_PreHook(EVENT_MANAGER, "RegisterForEvent", function(self, namespace, eventCode, callback, ...)
        table.insert(ACI.eventLog, {
            ts         = GetGameTimeMilliseconds(),
            namespace  = namespace or "?",
            eventCode  = eventCode or -1,
            callbackId = tostring(callback),
        })
    end)
    ACI.hookInstalled = true
end

----------------------------------------------------------------------
-- ZO_SavedVars 생성자 후킹
----------------------------------------------------------------------
local function RecordSVCall(method, tableName, version, namespace)
    local ns = tostring(namespace or "Default")
    local key = tostring(tableName) .. "::" .. ns
    if not ACI.svRegistrations[key] then
        ACI.svRegistrations[key] = {}
    end
    table.insert(ACI.svRegistrations[key], {
        method    = method,
        version   = version,
        caller    = ACI.lastLoadedAddon or "unknown",
        ts        = GetGameTimeMilliseconds(),
        traceback = debug.traceback("", 3),
    })
end

function ACI.InstallSVHooks()
    if not ZO_SavedVars then return false end

    ZO_PreHook(ZO_SavedVars, "NewAccountWide", function(self, t, v, ns, ...)
        RecordSVCall("NewAccountWide", t, v, ns)
    end)
    ZO_PreHook(ZO_SavedVars, "NewCharacterIdSettings", function(self, t, v, ns, ...)
        RecordSVCall("NewCharacterIdSettings", t, v, ns)
    end)
    if ZO_SavedVars.NewCharacterSettings then
        ZO_PreHook(ZO_SavedVars, "NewCharacterSettings", function(self, t, v, ns, ...)
            RecordSVCall("NewCharacterSettings", t, v, ns)
        end)
    end
    if ZO_SavedVars.New then
        ZO_PreHook(ZO_SavedVars, "New", function(self, t, v, ns, ...)
            RecordSVCall("New", t, v, ns)
        end)
    end
    return true
end
