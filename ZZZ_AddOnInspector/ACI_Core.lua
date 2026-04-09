----------------------------------------------------------------------
-- ACI_Core.lua — 전역 테이블, SV 초기화, 이벤트 라이프사이클
----------------------------------------------------------------------

ACI = {}
ACI.name = "ZZZ_AddOnInspector"
ACI.version = "0.2.0"
ACI.eventLog = {}
ACI.svRegistrations = {}
ACI.loadOrder = {}
ACI.loadOrderMap = {}   -- addonName → loadIndex (역방향 조회용)
ACI.lastLoadedAddon = nil
ACI.hookInstalled = false
ACI.svHookInstalled = false

----------------------------------------------------------------------
-- 로딩 순서 추적 (파일 로드 시점에 즉시 등록)
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
-- 유틸리티
----------------------------------------------------------------------

-- ACI 자신의 namespace인지 판정 (self-filter 일관 적용용)
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
-- eventCode → 이름 매핑 (_G에서 EVENT_ 접두사 수집)
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

ACI.eventNames = {}  -- PLAYER_ACTIVATED 이후에 채워짐

function ACI.EventName(code)
    if not next(ACI.eventNames) then
        ACI.eventNames = ACI.BuildEventNameMap()
    end
    return ACI.eventNames[code] or tostring(code)
end

----------------------------------------------------------------------
-- 메인 초기화
----------------------------------------------------------------------
local function OnACILoaded(eventCode, addonName)
    if addonName ~= ACI.name then return end
    EVENT_MANAGER:UnregisterForEvent(ACI.name, EVENT_ADD_ON_LOADED)

    ACI_SavedVars = ACI_SavedVars or {}

    -- Hooks 설치 (ACI_Hooks.lua)
    ACI.InstallEventHook()
    ACI.svHookInstalled = ACI.InstallSVHooks()

    -- SV에 live 참조 저장
    ACI_SavedVars.eventLog        = ACI.eventLog
    ACI_SavedVars.svRegistrations = ACI.svRegistrations
    ACI_SavedVars.loadOrder       = ACI.loadOrder

    -- 슬래시 명령어는 즉시 등록 (PLAYER_ACTIVATED 에러와 무관하게 작동)
    ACI.RegisterCommands()

    -- PLAYER_ACTIVATED: 정적 데이터 수집 + 초기 리포트
    EVENT_MANAGER:RegisterForEvent(ACI.name, EVENT_PLAYER_ACTIVATED, function()
        EVENT_MANAGER:UnregisterForEvent(ACI.name, EVENT_PLAYER_ACTIVATED)
        EVENT_MANAGER:UnregisterForEvent(ACI.name .. "_LoadOrder", EVENT_ADD_ON_LOADED)

        -- eventCode → 이름 매핑 구축
        ACI.eventNames = ACI.BuildEventNameMap()

        -- 메타데이터 수집 (ACI_Inventory.lua)
        ACI_SavedVars.metadata = ACI.CollectMetadata()
        ACI_SavedVars.svHookOk = ACI.svHookInstalled

        -- 채팅 UI 준비 후 리포트 출력 (zo_callLater로 지연)
        zo_callLater(function()
            ACI.PrintReport()
            d("[ACI] |c00FF00/aci|r 로 최신 통계를 볼 수 있습니다.")
        end, 1000)
    end)

    zo_callLater(function()
        d("[ACI] v" .. ACI.version .. " loaded. Hooks: Event=" .. tostring(ACI.hookInstalled) .. ", SV=" .. tostring(ACI.svHookInstalled))
    end, 500)
end

EVENT_MANAGER:RegisterForEvent(ACI.name, EVENT_ADD_ON_LOADED, OnACILoaded)
