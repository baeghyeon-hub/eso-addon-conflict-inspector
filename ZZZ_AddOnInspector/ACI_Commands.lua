----------------------------------------------------------------------
-- ACI_Commands.lua — /aci 슬래시 명령어 체계
----------------------------------------------------------------------

function ACI.RegisterCommands()
    SLASH_COMMANDS["/aci"] = function(args)
        args = (args or ""):lower():match("^%s*(.-)%s*$")
        if args == "" then
            ACI.PrintReport()
        elseif args == "stats" then
            ACI.PrintStats()
        elseif args == "addons" then
            ACI.PrintAddons()
        elseif args == "sv" then
            ACI.PrintSV()
        elseif args:match("^deps") then
            local name = args:match("^deps%s+(.+)")
            ACI.PrintDeps(name)
        elseif args == "init" then
            ACI.PrintInitTimes()
        elseif args == "orphans" then
            ACI.PrintOrphans()
        elseif args == "hot" then
            ACI.PrintHotPaths()
        elseif args == "health" then
            ACI.PrintHealth()
        elseif args == "save" then
            ACI.ForceSave()
        elseif args == "debug" then
            ACI.PrintDebug()
        elseif args == "dump" then
            ACI.DumpToSV()
        elseif args == "help" then
            ACI.PrintHelp()
        else
            d("[ACI] 알 수 없는 명령: " .. args)
            ACI.PrintHelp()
        end
    end
end

----------------------------------------------------------------------
-- /aci — 요약 리포트
----------------------------------------------------------------------
function ACI.PrintReport()
    local svConflicts = ACI.DetectSVConflicts()
    local sorted = ACI.SortedClusters()

    local aciLoadIndex = nil
    local firstUserAddon = nil
    for _, entry in ipairs(ACI.loadOrder) do
        if not string.find(entry.addon, "^ZO_") and not firstUserAddon then
            firstUserAddon = entry.addon
        end
        if entry.addon == ACI.name then
            aciLoadIndex = entry.index
        end
    end

    local totalSV = 0
    for key, entries in pairs(ACI.svRegistrations) do
        -- ACI 자신의 SV 등록은 카운트에서 제외
        for _, e in ipairs(entries) do
            if not ACI.IsSelfNamespace(e.caller) then
                totalSV = totalSV + 1
            end
        end
    end

    d("--------------------------------------------")
    d("[ACI] 환경 진단 리포트 (live)")
    d("--------------------------------------------")

    local meta = ACI_SavedVars and ACI_SavedVars.metadata
    local apiStr = meta and meta.currentAPI and (" (API " .. tostring(meta.currentAPI) .. ")") or ""
    local oodStr = meta and meta.outOfDateCount and meta.outOfDateCount > 0
        and ("  |cFFFF00" .. meta.outOfDateCount .. " out-of-date|r") or ""

    d("[ACI] 로딩: " .. tostring(#ACI.loadOrder) .. "개 애드온" .. apiStr .. ", ACI=#" .. tostring(aciLoadIndex or "?") .. oodStr)

    d("[ACI] 이벤트: |c00FF00" .. tostring(ACI.EventCountExcludingSelf()) .. "|r건, " .. tostring(#sorted) .. "개 클러스터")
    for i = 1, math.min(5, #sorted) do
        local s = sorted[i]
        local suffix = s.count > 1 and (" (" .. s.count .. ")") or ""
        d("[ACI]   " .. s.base .. suffix)
    end
    if #sorted > 5 then
        d("[ACI]   ... 외 " .. (#sorted - 5) .. "개")
    end

    d("[ACI] SV: " .. tostring(totalSV) .. "건, 충돌 " .. tostring(#svConflicts) .. "건")
    d("[ACI] /aci help 로 전체 명령어 확인")
    d("--------------------------------------------")
end

----------------------------------------------------------------------
-- /aci stats — 클러스터별 이벤트 통계
----------------------------------------------------------------------
function ACI.PrintStats()
    local sorted = ACI.SortedClusters()

    d("--------------------------------------------")
    d("[ACI] 이벤트 등록 통계 — " .. tostring(ACI.EventCountExcludingSelf()) .. "건 (live)")
    d("--------------------------------------------")
    for i, s in ipairs(sorted) do
        local subInfo = s.subCount > 1 and (" [" .. s.subCount .. " sub-ns]") or ""
        local color = s.count >= 50 and "|cFF6600" or s.count >= 10 and "|cFFFF00" or "|cCCCCCC"
        d(color .. string.format("  %3d  %s%s|r", s.count, s.base, subInfo))
    end
    d("--------------------------------------------")
end

----------------------------------------------------------------------
-- /aci addons — 애드온 목록
----------------------------------------------------------------------
function ACI.PrintAddons()
    local meta = ACI_SavedVars.metadata
    if not meta or not meta.addons then
        d("[ACI] 메타데이터 없음. PLAYER_ACTIVATED 이후 사용하세요.")
        return
    end

    local libs, addons, disabled = {}, {}, {}
    local outOfDate = 0
    for _, a in ipairs(meta.addons) do
        if not a.enabled then
            table.insert(disabled, a)
        elseif a.isLibrary then
            table.insert(libs, a)
        else
            table.insert(addons, a)
        end
        if a.isOutOfDate and a.enabled then
            outOfDate = outOfDate + 1
        end
    end

    d("--------------------------------------------")
    d("[ACI] 애드온 목록 — " .. tostring(meta.numAddons) .. "개 (활성 " .. tostring(#addons + #libs) .. ", 비활성 " .. tostring(#disabled) .. ")")
    if outOfDate > 0 then
        d("[ACI] |cFFFF00구버전 경고: " .. tostring(outOfDate) .. "개|r")
    end
    d("--------------------------------------------")

    d("[ACI] |c00FF00애드온 (" .. #addons .. ")|r")
    for _, a in ipairs(addons) do
        local flag = a.isOutOfDate and "|cFFFF00!|r " or "  "
        d("[ACI] " .. flag .. a.name .. "  v" .. tostring(a.version))
    end

    d("[ACI] |c8888FF라이브러리 (" .. #libs .. ")|r")
    for _, a in ipairs(libs) do
        d("[ACI]   " .. a.name)
    end
    d("--------------------------------------------")
end

----------------------------------------------------------------------
-- /aci sv — SV 등록 + 충돌
----------------------------------------------------------------------
function ACI.PrintSV()
    local conflicts = ACI.DetectSVConflicts()
    local totalSV = 0
    local uniquePairs = 0
    for key, entries in pairs(ACI.svRegistrations) do
        local hasForeign = false
        for _, e in ipairs(entries) do
            if not ACI.IsSelfNamespace(e.caller) then
                totalSV = totalSV + 1
                hasForeign = true
            end
        end
        if hasForeign then uniquePairs = uniquePairs + 1 end
    end

    d("--------------------------------------------")
    d("[ACI] SavedVariables 등록 — " .. tostring(totalSV) .. "건, 고유 쌍 " .. tostring(uniquePairs) .. "개")
    d("--------------------------------------------")

    for key, entries in pairs(ACI.svRegistrations) do
        local callers = {}
        for _, e in ipairs(entries) do
            -- ACI 자신의 SV는 목록에서 제외
            if not ACI.IsSelfNamespace(e.caller) then
                callers[e.caller] = true
            end
        end
        if next(callers) then
            local callerStr = ""
            for c in pairs(callers) do
                callerStr = callerStr .. (callerStr ~= "" and ", " or "") .. c
            end
            d("[ACI]   " .. key .. " ← " .. callerStr)
        end
    end

    if #conflicts > 0 then
        d("[ACI] |cFF0000충돌 " .. #conflicts .. "건:|r")
        for _, c in ipairs(conflicts) do
            d("[ACI]   " .. c.key .. " ← " .. table.concat(c.callers, " vs "))
        end
    else
        d("[ACI]   충돌 없음")
    end
    d("--------------------------------------------")
end

----------------------------------------------------------------------
-- /aci init — 애드온별 init 시간 (상위 10)
----------------------------------------------------------------------
function ACI.PrintInitTimes()
    local times = ACI.EstimateInitTimes()

    d("--------------------------------------------")
    d("[ACI] 애드온 Init 시간 추정 (상위 10)")
    d("--------------------------------------------")
    for i = 1, math.min(10, #times) do
        local t = times[i]
        local color = t.initMs >= 500 and "|cFF0000" or t.initMs >= 100 and "|cFFFF00" or "|cCCCCCC"
        d(color .. string.format("  %5dms  load#%d %s|r", t.initMs, t.index, t.addon))
    end
    d("--------------------------------------------")
end

----------------------------------------------------------------------
-- /aci deps [name] — 의존성 트리
----------------------------------------------------------------------
function ACI.PrintDeps(name)
    local depIndex = ACI.BuildDependencyIndex()
    if not depIndex then
        d("[ACI] 메타데이터 없음. PLAYER_ACTIVATED 이후 사용하세요.")
        return
    end

    if name then
        -- 특정 애드온의 forward + reverse
        -- 대소문자 무시 매칭
        local matchedName = nil
        for n in pairs(depIndex.byName) do
            if n:lower() == name:lower() then
                matchedName = n
                break
            end
        end
        if not matchedName then
            d("[ACI] '" .. name .. "' 을(를) 찾을 수 없습니다.")
            return
        end

        local addon = depIndex.byName[matchedName]
        local fwd = depIndex.forward[matchedName] or {}
        local rev = depIndex.reverse[matchedName] or {}

        d("--------------------------------------------")
        d("[ACI] " .. matchedName .. (addon.isLibrary and " |c8888FF[Library]|r" or ""))
        d("--------------------------------------------")

        d("[ACI] 의존성 (이것이 필요로 하는 것): " .. tostring(#fwd) .. "개")
        if #fwd > 0 then
            for _, depName in ipairs(fwd) do
                local depAddon = depIndex.byName[depName]
                local status = depAddon and (depAddon.enabled and "|c00FF00OK|r" or "|cFF0000OFF|r") or "|cFF0000MISSING|r"
                d("[ACI]   " .. depName .. " " .. status)
            end
        end

        d("[ACI] 역의존성 (이것을 사용하는 것): " .. tostring(#rev) .. "개")
        if #rev > 0 then
            for _, userName in ipairs(rev) do
                d("[ACI]   " .. userName)
            end
        end
        d("--------------------------------------------")
    else
        -- 전체 요약: 가장 많이 사용되는 라이브러리 상위 10
        local sorted = {}
        for depName, users in pairs(depIndex.reverse) do
            table.insert(sorted, { name = depName, count = #users })
        end
        table.sort(sorted, function(a, b) return a.count > b.count end)

        d("--------------------------------------------")
        d("[ACI] 의존성 요약 — 가장 많이 사용되는 라이브러리")
        d("--------------------------------------------")
        for i = 1, math.min(15, #sorted) do
            local s = sorted[i]
            d(string.format("[ACI]   %3d개가 사용  %s", s.count, s.name))
        end
        if #sorted > 15 then
            d("[ACI]   ... 외 " .. (#sorted - 15) .. "개")
        end

        -- 의존성 없는 애드온
        local noDeps = {}
        for name, fwd in pairs(depIndex.forward) do
            if #fwd == 0 then
                table.insert(noDeps, name)
            end
        end
        d("[ACI] 의존성 없는 애드온: " .. tostring(#noDeps) .. "개")
        d("--------------------------------------------")
    end
end

----------------------------------------------------------------------
-- /aci orphans — 불필요한 라이브러리 + de-facto library
----------------------------------------------------------------------
function ACI.PrintOrphans()
    local orphans = ACI.FindOrphanLibraries()
    local deFacto = ACI.FindDeFactoLibraries(3)

    d("--------------------------------------------")
    d("[ACI] 라이브러리 분석")
    d("--------------------------------------------")

    if #orphans > 0 then
        d("[ACI] |cFFFF00불필요한 라이브러리 (" .. #orphans .. "개)|r — 활성 애드온 중 아무도 안 씀:")
        for _, o in ipairs(orphans) do
            if o.typoHint then
                d("[ACI]   " .. o.name .. " |cFF6600← 오타? " .. o.typoHint .. " 과 혼동|r")
            else
                d("[ACI]   " .. o.name)
            end
        end
    else
        d("[ACI] |c00FF00불필요한 라이브러리 없음|r")
    end

    if #deFacto > 0 then
        d("[ACI] |c8888FFDe-facto 라이브러리|r — 라이브러리 아닌데 여러 애드온이 의존:")
        for _, df in ipairs(deFacto) do
            d("[ACI]   " .. df.name .. " (" .. df.userCount .. "개가 사용)")
        end
    end
    d("--------------------------------------------")
end

----------------------------------------------------------------------
-- /aci hot — 이벤트 hot path
----------------------------------------------------------------------
function ACI.PrintHotPaths()
    local hot = ACI.FindEventHotPaths(2)

    d("--------------------------------------------")
    d("[ACI] 이벤트 Hot Path — 여러 애드온이 같은 이벤트에 등록")
    d("--------------------------------------------")

    if #hot == 0 then
        d("[ACI] hot path 없음")
    else
        for _, h in ipairs(hot) do
            local name = ACI.EventName(h.eventCode)
            local color = h.baseCount >= 5 and "|cFF6600" or h.baseCount >= 3 and "|cFFFF00" or "|cCCCCCC"
            d(color .. string.format("  %d개 애드온, %d건  %s|r", h.baseCount, h.totalCount, name))

            -- 등록한 base cluster 나열
            local bases = {}
            for base, count in pairs(h.bases) do
                table.insert(bases, { base = base, count = count })
            end
            table.sort(bases, function(a, b) return a.count > b.count end)
            local parts = {}
            for i = 1, math.min(5, #bases) do
                local b = bases[i]
                table.insert(parts, b.base .. (b.count > 1 and ("x" .. b.count) or ""))
            end
            if #bases > 5 then
                table.insert(parts, "... +" .. (#bases - 5))
            end
            d("[ACI]     " .. table.concat(parts, ", "))
        end
    end
    d("--------------------------------------------")
end

----------------------------------------------------------------------
-- /aci health — 환경 종합 진단 (신호등)
----------------------------------------------------------------------
function ACI.PrintHealth()
    local h = ACI.ComputeHealthScore()
    local s = h.stats

    local color = h.level == "red" and "|cFF0000"
        or h.level == "yellow" and "|cFFFF00"
        or "|c00FF00"
    local label = h.level == "red" and "문제 있음"
        or h.level == "yellow" and "주의"
        or "정상"

    d("--------------------------------------------")
    d("[ACI] " .. color .. "● " .. label .. "|r")
    d("--------------------------------------------")

    -- OOD 상세 (embedded 제외 비율 기반)
    local pct = math.floor(s.oodRatio * 100 + 0.5)
    d(string.format("[ACI] 구버전: %d/%d top-level (%d%%)",
        s.topLevelOOD, s.topLevelEnabled, pct))
    if s.embeddedCount > 0 then
        d(string.format("[ACI]   (embedded 서브애드온 %d개 제외)", s.embeddedCount))
    end
    d(string.format("[ACI]   라이브러리 %d | 본체 %d", s.libOOD, s.addonOOD))

    -- 비율 기반 컨텍스트
    local ctx
    if s.oodRatio > 0.8 then
        ctx = "메이저 패치 직후이거나 장기 방치"
    elseif s.oodRatio > 0.5 then
        ctx = "패치 후 정상 범위 (1-2개월 내)"
    elseif s.oodRatio > 0.2 then
        ctx = "정상"
    else
        ctx = "잘 관리됨"
    end
    d("[ACI]   → " .. ctx)

    -- 기타 이슈 (SV 충돌, 고아 라이브러리 등)
    local otherIssues = {}
    for _, i in ipairs(h.issues) do
        -- OOD는 위에서 이미 표시했으므로 제외
        if not i.msg:find("구버전") then
            table.insert(otherIssues, i)
        end
    end

    if #otherIssues > 0 then
        d("[ACI]")
        for _, i in ipairs(otherIssues) do
            local c = i.level == "red" and "|cFF0000" or i.level == "yellow" and "|cFFFF00" or "|cCCCCCC"
            d("[ACI] " .. c .. "●|r " .. i.msg)
        end
    end

    d("[ACI]")
    d("[ACI] 이벤트: " .. tostring(ACI.EventCountExcludingSelf()) .. "건, hot path " .. tostring(s.hotPaths) .. "개")
    d("[ACI] 상세: /aci orphans | /aci hot | /aci sv | /aci addons")
    d("--------------------------------------------")
end

----------------------------------------------------------------------
-- /aci debug — embedded 감지 진단 (임시)
----------------------------------------------------------------------
function ACI.PrintDebug()
    local meta = ACI_SavedVars and ACI_SavedVars.metadata
    if not meta or not meta.addons then
        d("[ACI] 메타데이터 없음.")
        return
    end

    ACI.TagEmbeddedAddons()

    d("--------------------------------------------")
    d("[ACI] Debug — embedded 현황")
    d("--------------------------------------------")

    local embCount = 0
    for _, a in ipairs(meta.addons) do
        if a.enabled and a.isEmbedded then
            embCount = embCount + 1
            d("[ACI]   EMB  " .. a.name .. "  <-  " .. (a.rootPath or "?"))
        end
    end
    d("[ACI] embedded: " .. embCount .. " / " .. tostring(meta.enabledCount or "?") .. " enabled")
    d("--------------------------------------------")
end

----------------------------------------------------------------------
-- /aci dump — 진단 데이터를 SV에 저장 (파일에서 복사 가능)
----------------------------------------------------------------------
function ACI.DumpToSV()
    local meta = ACI_SavedVars and ACI_SavedVars.metadata
    if not meta or not meta.addons then
        d("[ACI] 메타데이터 없음.")
        return
    end

    -- embedded 태깅 (저장된 rootPath 기반 재계산)
    ACI.TagEmbeddedAddons()

    local dump = {}
    for _, a in ipairs(meta.addons) do
        if a.enabled then
            table.insert(dump, {
                name           = a.name,
                rootPath       = a.rootPath,
                embeddedStr    = a.isEmbedded and "YES" or "NO",
                isLibrary      = a.isLibrary,
                isOutOfDate    = a.isOutOfDate,
                dumpIndex      = a.index,
                loadOrderIndex = a.loadOrderIndex,
            })
        end
    end

    local health = ACI.ComputeHealthScore()

    ACI_SavedVars.dump = {
        ts      = GetTimeString and GetTimeString() or "?",
        addons  = dump,
        health  = health,
    }

    d("[ACI] dump 저장 완료. /reloadui 후 SV 파일에서 [\"dump\"] 블록을 확인하세요.")
end

----------------------------------------------------------------------
-- /aci save
----------------------------------------------------------------------
function ACI.ForceSave()
    local mgr = GetAddOnManager()
    if mgr and mgr.RequestAddOnSavedVariablesPrioritySave then
        mgr:RequestAddOnSavedVariablesPrioritySave()
        d("[ACI] SV 우선 저장 요청됨.")
    else
        d("[ACI] 사용 불가. /reloadui 로 저장하세요.")
    end
end

----------------------------------------------------------------------
-- /aci help
----------------------------------------------------------------------
function ACI.PrintHelp()
    d("--------------------------------------------")
    d("[ACI] 명령어 목록")
    d("--------------------------------------------")
    d("[ACI]   /aci          요약 리포트")
    d("[ACI]   /aci stats    이벤트 등록 통계 (클러스터별)")
    d("[ACI]   /aci addons   애드온 목록")
    d("[ACI]   /aci deps     가장 많이 쓰이는 라이브러리")
    d("[ACI]   /aci deps X   X의 forward/reverse 의존성")
    d("[ACI]   /aci init     Init 시간 추정 (상위 10)")
    d("[ACI]   /aci orphans  불필요한 라이브러리 + de-facto")
    d("[ACI]   /aci hot      이벤트 hot path")
    d("[ACI]   /aci health   환경 종합 진단 (신호등)")
    d("[ACI]   /aci sv       SV 등록 + 충돌")
    d("[ACI]   /aci save     SV 강제 저장")
    d("[ACI]   /aci help     이 도움말")
    d("--------------------------------------------")
end
