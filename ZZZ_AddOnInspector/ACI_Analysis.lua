----------------------------------------------------------------------
-- ACI_Analysis.lua — clustering, 집계, 충돌 감지
----------------------------------------------------------------------

----------------------------------------------------------------------
-- Embedded 서브애드온 판정
-- 관심사 분리: Inventory = 수집, Analysis = 분석.
-- 테이블에 저장된 rootPath로 분석 단계에서 판정한다.
----------------------------------------------------------------------
local function IsEmbeddedPath(rootPath)
    if not rootPath then return false end
    local mPos = rootPath:find("/AddOns/", 1, true)
    if not mPos then return false end
    local afterAddons = rootPath:sub(mPos + 8)  -- #"/AddOns/" = 8
    local firstSlash = afterAddons:find("/", 1, true)
    return firstSlash ~= nil and firstSlash < #afterAddons
end

-- metadata.addons 배열에 isEmbedded 필드를 일괄 태깅
function ACI.TagEmbeddedAddons()
    local meta = ACI_SavedVars and ACI_SavedVars.metadata
    if not meta or not meta.addons then return end
    for _, a in ipairs(meta.addons) do
        a.isEmbedded = IsEmbeddedPath(a.rootPath)
    end
end

----------------------------------------------------------------------
-- ACI 제외 이벤트 카운트
----------------------------------------------------------------------
function ACI.EventCountExcludingSelf()
    local count = 0
    for _, entry in ipairs(ACI.eventLog) do
        if not ACI.IsSelfNamespace(entry.namespace) then
            count = count + 1
        end
    end
    return count
end

----------------------------------------------------------------------
-- Namespace Clustering
-- 숫자 접미사 제거로 그룹핑: LibCombat47 → LibCombat
----------------------------------------------------------------------
function ACI.ClusterNamespaces()
    local clusters = {}
    for _, entry in ipairs(ACI.eventLog) do
        -- ACI 자신의 등록은 제외
        if not ACI.IsSelfNamespace(entry.namespace) then
            local base = entry.namespace:match("^(.-)%d+$") or entry.namespace
            if not clusters[base] then
                clusters[base] = { count = 0, eventCodes = {}, namespaces = {} }
            end
            local c = clusters[base]
            c.count = c.count + 1
            c.eventCodes[entry.eventCode] = (c.eventCodes[entry.eventCode] or 0) + 1
            c.namespaces[entry.namespace] = true
        end
    end
    return clusters
end

-- 클러스터를 등록 수 내림차순 정렬 배열로 변환
function ACI.SortedClusters(clusters)
    clusters = clusters or ACI.ClusterNamespaces()
    local sorted = {}
    for base, data in pairs(clusters) do
        table.insert(sorted, {
            base       = base,
            count      = data.count,
            eventCodes = data.eventCodes,
            subCount   = ACI.TableLength(data.namespaces),
        })
    end
    table.sort(sorted, function(a, b) return a.count > b.count end)
    return sorted
end

----------------------------------------------------------------------
-- SV 충돌 감지
-- 같은 (svTable::namespace) 쌍에 다른 caller가 있으면 충돌
----------------------------------------------------------------------
function ACI.DetectSVConflicts()
    local conflicts = {}
    for key, entries in pairs(ACI.svRegistrations) do
        local callers = {}
        for _, e in ipairs(entries) do
            callers[e.caller] = true
        end
        local callerList = {}
        for c in pairs(callers) do
            table.insert(callerList, c)
        end
        if #callerList > 1 then
            table.insert(conflicts, {
                key     = key,
                callers = callerList,
                count   = #entries,
            })
        end
    end
    return conflicts
end

----------------------------------------------------------------------
-- 의존성 역방향 인덱스
-- forward: addon → [deps it needs]    (이미 metadata.addons[].deps에 있음)
-- reverse: library → [addons that use it]
----------------------------------------------------------------------
function ACI.BuildDependencyIndex()
    local meta = ACI_SavedVars and ACI_SavedVars.metadata
    if not meta or not meta.addons then return nil end

    local forward = {}   -- name → { depName[] }
    local reverse = {}   -- depName → { addonName[] }  (enabled 애드온만)
    local byName = {}    -- name → addon entry

    for _, addon in ipairs(meta.addons) do
        byName[addon.name] = addon
        forward[addon.name] = {}
        for _, dep in ipairs(addon.deps) do
            table.insert(forward[addon.name], dep.name)
            -- reverse: 활성 애드온의 의존성만 집계 (고아 탐지 정확도)
            if addon.enabled then
                if not reverse[dep.name] then
                    reverse[dep.name] = {}
                end
                table.insert(reverse[dep.name], addon.name)
            end
        end
    end

    return {
        forward = forward,
        reverse = reverse,
        byName  = byName,
    }
end

----------------------------------------------------------------------
-- 고아 라이브러리: isLibrary=true인데 활성 애드온 중 아무도 안 쓰는 것
----------------------------------------------------------------------
function ACI.FindOrphanLibraries()
    local depIndex = ACI.BuildDependencyIndex()
    if not depIndex then return {} end

    -- 모든 deps 이름을 lowercase → original로 매핑 (오타 탐지용)
    local allDepNames = {}
    for depName in pairs(depIndex.reverse) do
        allDepNames[depName:lower()] = depName
    end

    local meta = ACI_SavedVars.metadata
    local orphans = {}
    for _, a in ipairs(meta.addons) do
        if a.enabled and a.isLibrary and not a.isEmbedded then
            local users = depIndex.reverse[a.name]
            if not users or #users == 0 then
                -- 대소문자 오타 탐지: 같은 lowercase인데 다른 이름이 deps에 있으면 오타
                local typoHint = nil
                local lower = a.name:lower()
                if allDepNames[lower] and allDepNames[lower] ~= a.name then
                    typoHint = allDepNames[lower]
                end
                table.insert(orphans, { name = a.name, typoHint = typoHint })
            end
        end
    end
    return orphans
end

----------------------------------------------------------------------
-- De-facto library: isLibrary=false인데 reverse dep ≥ threshold
----------------------------------------------------------------------
function ACI.FindDeFactoLibraries(threshold)
    threshold = threshold or 3
    local depIndex = ACI.BuildDependencyIndex()
    if not depIndex then return {} end

    local meta = ACI_SavedVars.metadata
    local result = {}
    for _, a in ipairs(meta.addons) do
        if a.enabled and not a.isLibrary then
            local users = depIndex.reverse[a.name] or {}
            if #users >= threshold then
                table.insert(result, { name = a.name, userCount = #users })
            end
        end
    end
    table.sort(result, function(x, y) return x.userCount > y.userCount end)
    return result
end

----------------------------------------------------------------------
-- 이벤트 Hot Path: 같은 eventCode에 N개 이상의 base cluster가 등록
----------------------------------------------------------------------
function ACI.FindEventHotPaths(threshold)
    threshold = threshold or 3
    local perEvent = {}
    for _, e in ipairs(ACI.eventLog) do
        -- ACI 자신의 등록은 제외
        if not ACI.IsSelfNamespace(e.namespace) then
            local code = e.eventCode
            local base = e.namespace:match("^(.-)%d+$") or e.namespace
            if not perEvent[code] then
                perEvent[code] = { bases = {}, totalCount = 0 }
            end
            perEvent[code].totalCount = perEvent[code].totalCount + 1
            perEvent[code].bases[base] = (perEvent[code].bases[base] or 0) + 1
        end
    end

    local hot = {}
    for code, data in pairs(perEvent) do
        local baseCount = ACI.TableLength(data.bases)
        if baseCount >= threshold then
            table.insert(hot, {
                eventCode  = code,
                totalCount = data.totalCount,
                baseCount  = baseCount,
                bases      = data.bases,
            })
        end
    end
    table.sort(hot, function(a, b) return a.baseCount > b.baseCount end)
    return hot
end

----------------------------------------------------------------------
-- Health Score — 환경 종합 진단
-- embedded 서브애드온 제외, 비율 기반 임계값
----------------------------------------------------------------------
function ACI.ComputeHealthScore()
    local meta = ACI_SavedVars and ACI_SavedVars.metadata
    if not meta then return { level = "unknown", issues = {}, stats = {} } end

    -- 저장된 rootPath(순수 Lua string)로 embedded 재계산
    ACI.TagEmbeddedAddons()

    local orphans     = ACI.FindOrphanLibraries()
    local deFacto     = ACI.FindDeFactoLibraries(3)
    local hotPaths    = ACI.FindEventHotPaths(3)
    local svConflicts = ACI.DetectSVConflicts()

    -- embedded 제외 OOD 집계
    local topLevelEnabled, topLevelOOD = 0, 0
    local libOOD, addonOOD = 0, 0
    local embeddedCount = 0

    for _, a in ipairs(meta.addons) do
        if a.enabled then
            if a.isEmbedded then
                embeddedCount = embeddedCount + 1
            else
                topLevelEnabled = topLevelEnabled + 1
                if a.isOutOfDate then
                    topLevelOOD = topLevelOOD + 1
                    if a.isLibrary then
                        libOOD = libOOD + 1
                    else
                        addonOOD = addonOOD + 1
                    end
                end
            end
        end
    end

    local oodRatio = topLevelOOD / math.max(1, topLevelEnabled)

    local issues = {}

    -- SV 충돌 — 항상 심각
    if #svConflicts > 0 then
        table.insert(issues, { level = "red", msg = #svConflicts .. "개 SV 충돌" })
    end

    -- OOD — 비율 기반
    if oodRatio > 0.8 then
        table.insert(issues, { level = "red",
            msg = topLevelOOD .. "/" .. topLevelEnabled .. " 구버전 (" .. math.floor(oodRatio * 100 + 0.5) .. "%)" })
    elseif oodRatio > 0.5 then
        table.insert(issues, { level = "yellow",
            msg = topLevelOOD .. "/" .. topLevelEnabled .. " 구버전 (" .. math.floor(oodRatio * 100 + 0.5) .. "%)" })
    elseif topLevelOOD > 0 then
        table.insert(issues, { level = "info",
            msg = topLevelOOD .. "/" .. topLevelEnabled .. " 구버전 (" .. math.floor(oodRatio * 100 + 0.5) .. "%)" })
    end

    -- 고아 라이브러리
    if #orphans > 3 then
        table.insert(issues, { level = "yellow", msg = #orphans .. "개 불필요한 라이브러리" })
    elseif #orphans > 0 then
        table.insert(issues, { level = "info", msg = #orphans .. "개 불필요한 라이브러리" })
    end

    -- 최종 레벨 결정
    local level = "green"
    for _, i in ipairs(issues) do
        if i.level == "red" then level = "red"; break end
        if i.level == "yellow" then level = "yellow" end
    end

    return {
        level  = level,
        issues = issues,
        stats  = {
            topLevelEnabled = topLevelEnabled,
            topLevelOOD     = topLevelOOD,
            libOOD          = libOOD,
            addonOOD        = addonOOD,
            embeddedCount   = embeddedCount,
            oodRatio        = oodRatio,
            orphans         = #orphans,
            deFacto         = #deFacto,
            hotPaths        = #hotPaths,
            svConflicts     = #svConflicts,
        },
    }
end

----------------------------------------------------------------------
-- Init 시간 추정 (loadOrder ts 차이)
----------------------------------------------------------------------
function ACI.EstimateInitTimes()
    local results = {}
    for i = 2, #ACI.loadOrder do
        local prev = ACI.loadOrder[i - 1]
        local curr = ACI.loadOrder[i]
        table.insert(results, {
            addon    = prev.addon,
            initMs   = curr.ts - prev.ts,
            index    = prev.index,
        })
    end
    -- 마지막 애드온은 PLAYER_ACTIVATED까지의 시간을 알 수 없으므로 제외
    table.sort(results, function(a, b) return a.initMs > b.initMs end)
    return results
end
