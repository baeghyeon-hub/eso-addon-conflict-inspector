----------------------------------------------------------------------
-- ACI_Commands.lua — /aci slash command system
----------------------------------------------------------------------

local L = function(k) return ACI.L(k) end

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
        elseif args == "missing" then
            ACI.PrintMissingDeps()
        elseif args == "ood" then
            ACI.PrintOOD()
        elseif args == "hot" then
            ACI.PrintHotPaths("addons")
        elseif args == "hot regs" then
            ACI.PrintHotPaths("regs")
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
            d(string.format(L("FMT_UNKNOWN_CMD"), args))
            ACI.PrintHelp()
        end
    end
end

----------------------------------------------------------------------
-- /aci — summary report
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
        for _, e in ipairs(entries) do
            if not ACI.IsSelfNamespace(e.caller) then
                totalSV = totalSV + 1
            end
        end
    end

    d(L("SEPARATOR"))
    d(L("REPORT_TITLE"))
    d(L("SEPARATOR"))

    local meta = ACI_SavedVars and ACI_SavedVars.metadata
    local apiStr = ""
    if meta and meta.currentAPI then
        apiStr = string.format(L("FMT_REPORT_API"), tostring(meta.currentAPI))
    end
    local oodStr = ""
    if meta and meta.outOfDateCount and meta.outOfDateCount > 0 then
        oodStr = string.format(L("FMT_REPORT_OOD"), meta.outOfDateCount)
    end

    d(string.format(L("FMT_REPORT_LOADED"),
        #ACI.loadOrder,
        apiStr,
        tostring(aciLoadIndex or "?"),
        oodStr
    ))

    d(string.format(L("FMT_REPORT_EVENTS"), ACI.EventCountExcludingSelf(), #sorted))
    for i = 1, math.min(5, #sorted) do
        local s = sorted[i]
        local suffix = s.count > 1 and (" (" .. s.count .. ")") or ""
        d(string.format(L("FMT_REPORT_CLUSTER"), s.base, suffix))
    end
    if #sorted > 5 then
        d(string.format(L("FMT_MORE"), #sorted - 5))
    end

    d(string.format(L("FMT_REPORT_SV"), totalSV, #svConflicts))
    d(L("REPORT_HELP_HINT"))
    d(L("SEPARATOR"))
end

----------------------------------------------------------------------
-- /aci stats — event registration stats by cluster
----------------------------------------------------------------------
function ACI.PrintStats()
    local sorted = ACI.SortedClusters()

    d(L("SEPARATOR"))
    d(string.format(L("FMT_STATS_TITLE"), ACI.EventCountExcludingSelf()))
    d(L("SEPARATOR"))
    for i, s in ipairs(sorted) do
        local subInfo = s.subCount > 1 and string.format(L("FMT_SUB_NS"), s.subCount) or ""
        local color = ACI.HeatThreshold(s.count, 50, 10)
        d(color .. string.format("  %3d  %s%s|r", s.count, s.base, subInfo))
    end
    d(L("SEPARATOR"))
end

----------------------------------------------------------------------
-- /aci addons — addon list
----------------------------------------------------------------------
function ACI.PrintAddons()
    local meta = ACI_SavedVars.metadata
    if not meta or not meta.addons then
        d(L("NO_METADATA_PA"))
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

    d(L("SEPARATOR"))
    d(string.format(L("FMT_ADDONS_TITLE"), meta.numAddons, #addons + #libs, #disabled))
    if outOfDate > 0 then
        d(string.format(L("FMT_ADDONS_OOD"), outOfDate))
    end
    d(L("SEPARATOR"))

    d(string.format(L("FMT_ADDONS_HEADER"), #addons))
    for _, a in ipairs(addons) do
        local flag = a.isOutOfDate and "|cFFFF00!|r " or "  "
        d(string.format(L("FMT_ADDON_ENTRY"), flag, a.name, tostring(a.version)))
    end

    d(string.format(L("FMT_LIBS_HEADER"), #libs))
    for _, a in ipairs(libs) do
        d("[ACI]   " .. a.name)
    end
    d(L("SEPARATOR"))
end

----------------------------------------------------------------------
-- /aci sv — SV registrations + conflicts
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

    d(L("SEPARATOR"))
    d(string.format(L("FMT_SV_HEADER"), totalSV, uniquePairs))
    d(L("SEPARATOR"))

    for key, entries in pairs(ACI.svRegistrations) do
        local callers = {}
        for _, e in ipairs(entries) do
            if not ACI.IsSelfNamespace(e.caller) then
                callers[e.caller] = true
            end
        end
        if next(callers) then
            local callerStr = ""
            for c in pairs(callers) do
                callerStr = callerStr .. (callerStr ~= "" and ", " or "") .. c
            end
            d(string.format(L("FMT_SV_ENTRY"), key, callerStr))
        end
    end

    if #conflicts > 0 then
        d(string.format(L("FMT_SV_CONFLICT_HEAD"), #conflicts))
        for _, c in ipairs(conflicts) do
            d(string.format(L("FMT_SV_CONFLICT_LINE"), c.key, table.concat(c.callers, " vs ")))
        end
    else
        d(L("SV_NO_CONFLICTS"))
    end

    -- SV disk usage (top 10 by size)
    local meta = ACI_SavedVars and ACI_SavedVars.metadata
    if meta and meta.addons then
        local depIndex = ACI.BuildDependencyIndex()
        local orphanSet = {}
        local orphans = ACI.FindOrphanLibraries()
        for _, o in ipairs(orphans) do orphanSet[o.name] = true end

        local svSizes = {}
        local totalMB = 0
        for _, a in ipairs(meta.addons) do
            if a.enabled and a.svDiskMB and a.svDiskMB > 0 then
                local deps = depIndex and depIndex.reverse[a.name] or {}
                table.insert(svSizes, {
                    name = a.name,
                    mb = a.svDiskMB,
                    dependents = #deps,
                    isLibrary = a.isLibrary,
                    isOrphan = orphanSet[a.name] or false,
                    isOOD = a.isOutOfDate,
                })
                totalMB = totalMB + a.svDiskMB
            end
        end
        table.sort(svSizes, function(a, b) return a.mb > b.mb end)

        if #svSizes > 0 then
            d("[ACI]")
            d(string.format(L("FMT_SV_DISK_TITLE"), totalMB, #svSizes))
            local limit = math.min(10, #svSizes)
            for i = 1, limit do
                local s = svSizes[i]
                local sizeStr
                if s.mb >= 1 then
                    sizeStr = string.format("%.2f MB", s.mb)
                else
                    sizeStr = string.format("%.1f KB", s.mb * 1024)
                end
                local color = ACI.HeatThreshold(s.mb, 1, 0.1)

                local tag = ""
                if s.isLibrary and s.isOrphan and s.isOOD then
                    tag = L("SV_TAG_REVIEW")
                elseif s.isLibrary and s.isOrphan then
                    tag = L("SV_TAG_UNUSED")
                elseif s.isLibrary and s.dependents > 0 then
                    tag = string.format(L("FMT_SV_TAG_DEPS"), s.dependents)
                end

                d(string.format(L("FMT_SV_DISK_ENTRY"), color, sizeStr, s.name, tag))
            end
            if #svSizes > 10 then
                d(string.format(L("FMT_MORE"), #svSizes - 10))
            end
        end
    end

    d(L("SEPARATOR"))
end

----------------------------------------------------------------------
-- /aci init — addon init time estimation (top 10)
----------------------------------------------------------------------
function ACI.PrintInitTimes()
    local times = ACI.EstimateInitTimes()

    d(L("SEPARATOR"))
    d(L("INIT_TITLE"))
    d(L("SEPARATOR"))
    for i = 1, math.min(10, #times) do
        local t = times[i]
        local color = ACI.SeverityThreshold(t.initMs, 500, 100)
        d(color .. string.format(L("FMT_INIT_ENTRY"), t.initMs, t.index, t.addon))
    end
    d(L("SEPARATOR"))
end

----------------------------------------------------------------------
-- /aci deps [name] — dependency tree
----------------------------------------------------------------------
function ACI.PrintDeps(name)
    local depIndex = ACI.BuildDependencyIndex()
    if not depIndex then
        d(L("NO_METADATA_PA"))
        return
    end

    if name then
        local matchedName = nil
        for n in pairs(depIndex.byName) do
            if n:lower() == name:lower() then
                matchedName = n
                break
            end
        end
        if not matchedName then
            d(string.format(L("FMT_DEPS_NOT_FOUND"), name))
            return
        end

        local addon = depIndex.byName[matchedName]
        local fwd = depIndex.forward[matchedName] or {}
        local rev = depIndex.reverse[matchedName] or {}

        d(L("SEPARATOR"))
        d("[ACI] " .. matchedName .. (addon.isLibrary and L("LABEL_LIBRARY") or ""))
        d(L("SEPARATOR"))

        d(string.format(L("FMT_DEPS_NEEDS"), #fwd))
        if #fwd > 0 then
            for _, depName in ipairs(fwd) do
                local depAddon = depIndex.byName[depName]
                local status
                if not depAddon then
                    status = L("DEP_MISSING")
                elseif depAddon.enabled then
                    status = L("DEP_OK")
                else
                    status = L("DEP_OFF")
                end
                d("[ACI]   " .. depName .. " " .. status)
            end
        end

        d(string.format(L("FMT_DEPS_REVERSE"), #rev))
        if #rev > 0 then
            for _, userName in ipairs(rev) do
                d("[ACI]   " .. userName)
            end
        end
        d(L("SEPARATOR"))
    else
        local sorted = {}
        for depName, users in pairs(depIndex.reverse) do
            table.insert(sorted, { name = depName, count = #users })
        end
        table.sort(sorted, function(a, b) return a.count > b.count end)

        d(L("SEPARATOR"))
        d(L("DEPS_SUMMARY_TITLE"))
        d(L("SEPARATOR"))
        for i = 1, math.min(15, #sorted) do
            local s = sorted[i]
            d(string.format(L("FMT_DEPS_DEPENDENT"), s.count, s.name))
        end
        if #sorted > 15 then
            d(string.format(L("FMT_MORE"), #sorted - 15))
        end

        local noDeps = {}
        for name, fwd in pairs(depIndex.forward) do
            if #fwd == 0 then
                table.insert(noDeps, name)
            end
        end
        d(string.format(L("FMT_DEPS_NO_DEPS"), #noDeps))
        d(L("SEPARATOR"))
    end
end

----------------------------------------------------------------------
-- /aci orphans — unused libraries + de-facto libraries
----------------------------------------------------------------------
function ACI.PrintOrphans()
    local orphans = ACI.FindOrphanLibraries()
    local deFacto = ACI.FindDeFactoLibraries(3)

    d(L("SEPARATOR"))
    d(L("ORPHANS_TITLE"))
    d(L("SEPARATOR"))

    if #orphans > 0 then
        d(string.format(L("FMT_ORPHANS_HEADER"), #orphans))
        for _, o in ipairs(orphans) do
            if o.hint then
                local tag
                if o.hint.type == "case" then
                    tag = string.format(L("FMT_HINT_CASE"), o.hint.suggestion)
                elseif o.hint.type == "version" then
                    tag = string.format(L("FMT_HINT_VERSION"), o.hint.suggestion)
                else
                    tag = string.format(L("FMT_HINT_TYPO"), o.hint.suggestion)
                end
                d("[ACI]   " .. o.name .. " " .. tag)
            else
                d("[ACI]   " .. o.name)
            end
        end
    else
        d(L("ORPHANS_NONE"))
    end

    if #deFacto > 0 then
        d(L("DEFACTO_HEADER"))
        for _, df in ipairs(deFacto) do
            d(string.format(L("FMT_DEFACTO_ENTRY"), df.name, df.userCount))
        end
    end
    d(L("SEPARATOR"))
end

----------------------------------------------------------------------
-- /aci missing — unresolved dependencies (declared but not installed)
----------------------------------------------------------------------
function ACI.PrintMissingDeps()
    local missing = ACI.FindMissingDependencies()

    d(L("SEPARATOR"))
    d(L("MISSING_TITLE"))
    d(L("SEPARATOR"))

    if #missing == 0 then
        d(L("MISSING_NONE"))
    else
        d(string.format(L("FMT_MISSING_HEADER"), #missing))
        for _, m in ipairs(missing) do
            d(string.format(L("FMT_MISSING_ENTRY"), m.name, #m.users))

            if m.hint then
                if m.hint.type == "case" then
                    d(string.format(L("FMT_MISSING_HINT_CASE"), m.hint.suggestion))
                elseif m.hint.type == "version" then
                    d(string.format(L("FMT_MISSING_HINT_VERSION"), m.hint.suggestion))
                else
                    d(string.format(L("FMT_MISSING_HINT_TYPO"), m.hint.suggestion))
                end
            end

            for _, u in ipairs(m.users) do
                d(string.format(L("FMT_MISSING_USER"), u))
            end
        end
    end
    d(L("SEPARATOR"))
end

----------------------------------------------------------------------
-- /aci hot — event hot paths
----------------------------------------------------------------------
function ACI.PrintHotPaths(mode)
    mode = mode or "addons"
    local hot, crossRef = ACI.FindHotPathsWithCrossRef(2, 30)

    if mode == "regs" then
        table.sort(hot, function(a, b) return a.totalCount > b.totalCount end)
    end
    local limit = math.min(10, #hot)
    local truncated = {}
    for i = 1, limit do truncated[i] = hot[i] end
    hot = truncated

    local title = (mode == "regs") and L("HOT_TITLE_BY_REGS") or L("HOT_TITLE_BY_ADDONS")
    d(L("SEPARATOR"))
    d(string.format(L("FMT_HOT_TITLE"), title))
    d(L("HOT_DISCLAIMER"))
    d(L("SEPARATOR"))

    if #hot == 0 then
        d(L("HOT_NONE"))
    else
        local warnThreshold = math.max(3, math.floor(#hot * 0.5 + 0.5))

        for _, h in ipairs(hot) do
            local name = ACI.EventName(h.eventCode)
            local color = ACI.HeatThreshold(h.baseCount, 5, 3)
            d(color .. string.format(L("FMT_HOT_EVENT"), h.baseCount, h.totalCount, name))

            local bases = {}
            for base, count in pairs(h.bases) do
                table.insert(bases, { base = base, count = count, cross = crossRef[base] or 1 })
            end
            table.sort(bases, function(a, b)
                if a.cross ~= b.cross then return a.cross > b.cross end
                return a.count > b.count
            end)
            for i = 1, math.min(5, #bases) do
                local b = bases[i]
                local label = b.base .. (b.count > 1 and ("x" .. b.count) or "")
                local crossTag
                if b.cross >= warnThreshold then
                    crossTag = string.format(L("FMT_TAG_CROSS_HEAVY"), b.cross)
                elseif b.cross >= 2 then
                    crossTag = string.format(L("FMT_TAG_CROSS"), b.cross)
                else
                    crossTag = ""
                end
                d("[ACI]     " .. label .. crossTag)
            end
            if #bases > 5 then
                d("[ACI]     ... +" .. (#bases - 5))
            end
        end
    end
    d(L("SEPARATOR"))
end

----------------------------------------------------------------------
-- /aci ood — out-of-date breakdown by category
----------------------------------------------------------------------
function ACI.PrintOOD()
    local ood = ACI.ClassifyOOD()
    if not ood then
        d(L("NO_METADATA"))
        return
    end

    local pct = math.floor(ood.oodRatio * 100 + 0.5)

    d(L("SEPARATOR"))
    d(L("OOD_TITLE"))
    d(string.format(L("FMT_OOD_RATIO"), ood.topLevelOOD, ood.topLevelEnabled, pct))
    d(L("SEPARATOR"))

    if #ood.standalone > 0 then
        d(string.format(L("FMT_OOD_STANDALONE_HEAD"), #ood.standalone))
        for _, name in ipairs(ood.standalone) do
            d("[ACI]   " .. name)
        end
    else
        d(L("OOD_STANDALONE_NONE"))
    end

    d("[ACI]")

    if #ood.libOnly > 0 then
        d(string.format(L("FMT_OOD_LIBONLY_HEAD"), #ood.libOnly))
        for _, lib in ipairs(ood.libOnly) do
            local depStr = lib.dependents > 0
                and string.format(L("FMT_LIB_DEPENDENTS"), lib.dependents)
                or ""
            d("[ACI]   " .. lib.name .. depStr)
        end
    else
        d(L("OOD_LIBONLY_NONE"))
    end

    d("[ACI]")

    if #ood.embedded > 0 then
        d(string.format(L("FMT_OOD_EMBEDDED_HEAD"), #ood.embedded))
        for _, name in ipairs(ood.embedded) do
            d("[ACI]   " .. name)
        end
    else
        d(L("OOD_EMBEDDED_NONE"))
    end

    d(L("SEPARATOR"))
end

----------------------------------------------------------------------
-- /aci health — overall environment diagnosis (traffic light)
----------------------------------------------------------------------
function ACI.PrintHealth()
    local h = ACI.ComputeHealthScore()
    local s = h.stats

    local color = ACI.LevelColor(h.level)
    local label = h.level == "red" and L("HEALTH_LABEL_RED")
        or h.level == "yellow" and L("HEALTH_LABEL_YELLOW")
        or L("HEALTH_LABEL_GREEN")

    d(L("SEPARATOR"))
    d(string.format(L("FMT_HEALTH_HEADER"), color, label))
    d(L("SEPARATOR"))

    local ood = h.ood
    if ood then
        local pct = math.floor(ood.oodRatio * 100 + 0.5)
        d(string.format(L("FMT_HEALTH_OOD"), ood.topLevelOOD, ood.topLevelEnabled, pct))

        local ignorable = #ood.libOnly + #ood.embedded
        if ignorable > 0 then
            d(string.format(L("FMT_HEALTH_IGNORABLE"), #ood.libOnly, #ood.embedded))
        end

        if #ood.standalone > 0 then
            d(string.format(L("FMT_HEALTH_ATTENTION"), #ood.standalone))
            local names = {}
            for i = 1, math.min(5, #ood.standalone) do
                table.insert(names, ood.standalone[i])
            end
            local suffix = ""
            if #ood.standalone > 5 then
                suffix = string.format(L("FMT_HEALTH_NAMES_MORE"), #ood.standalone - 5)
            end
            d(string.format(L("FMT_HEALTH_NAMES"), table.concat(names, ", "), suffix))
        end

        local ctx
        if ood.oodRatio > 0.8 then
            ctx = L("HEALTH_CTX_MAJOR")
        elseif ood.oodRatio > 0.5 then
            ctx = L("HEALTH_CTX_PATCH")
        elseif ood.oodRatio > 0.2 then
            ctx = L("HEALTH_CTX_NORMAL")
        else
            ctx = L("HEALTH_CTX_WELL")
        end
        d(string.format(L("FMT_HEALTH_CTX"), ctx))
        d(L("HEALTH_FULL_BREAKDOWN"))
    end

    local otherIssues = {}
    for _, i in ipairs(h.issues) do
        if i.kind ~= "ood" then
            table.insert(otherIssues, i)
        end
    end

    if #otherIssues > 0 then
        d("[ACI]")
        for _, i in ipairs(otherIssues) do
            local c = ACI.LevelColor(i.level)
            d(string.format(L("FMT_HEALTH_ISSUE"), c, i.msg))
        end
    end

    local reviewCandidates, totalMB = ACI.FindReviewCandidates()
    if #reviewCandidates > 0 then
        d("[ACI]")
        local sizeHint = ""
        if totalMB > 0 then
            sizeHint = string.format(L("FMT_REVIEW_CAND_SIZE_HINT"), totalMB * 1024)
        end
        d(string.format(L("FMT_REVIEW_CAND_HEADER"), #reviewCandidates, sizeHint))
        d(L("REVIEW_CAND_WARNING"))
        for _, rc in ipairs(reviewCandidates) do
            local sizeTag = ""
            if rc.svDiskMB and rc.svDiskMB > 0 then
                if rc.svDiskMB >= 1 then
                    sizeTag = string.format(L("FMT_REVIEW_CAND_SIZE_MB"), rc.svDiskMB)
                else
                    sizeTag = string.format(L("FMT_REVIEW_CAND_SIZE_KB"), rc.svDiskMB * 1024)
                end
            end
            d(string.format(L("FMT_REVIEW_CAND_ENTRY"), rc.name, sizeTag))
        end
        d(L("REVIEW_CAND_NOTE"))
    end

    d("[ACI]")
    d(string.format(L("FMT_HEALTH_EVENTS"), ACI.EventCountExcludingSelf(), s.hotPaths))
    d(L("HEALTH_DETAILS"))
    d(L("SEPARATOR"))
end

----------------------------------------------------------------------
-- /aci debug — embedded detection diagnostics
----------------------------------------------------------------------
function ACI.PrintDebug()
    local meta = ACI_SavedVars and ACI_SavedVars.metadata
    if not meta or not meta.addons then
        d(L("NO_METADATA"))
        return
    end

    ACI.TagEmbeddedAddons()

    d(L("SEPARATOR"))
    d(L("DEBUG_TITLE"))
    d(L("SEPARATOR"))

    local embCount = 0
    for _, a in ipairs(meta.addons) do
        if a.enabled and a.isEmbedded then
            embCount = embCount + 1
            d(string.format(L("FMT_DEBUG_EMB_LINE"), a.name, a.rootPath or "?"))
        end
    end
    d(string.format(L("FMT_DEBUG_EMB_TOTAL"), embCount, tostring(meta.enabledCount or "?")))
    d(L("SEPARATOR"))
end

----------------------------------------------------------------------
-- /aci dump — save diagnostic data to SV (copy from file)
----------------------------------------------------------------------
function ACI.DumpToSV()
    local meta = ACI_SavedVars and ACI_SavedVars.metadata
    if not meta or not meta.addons then
        d(L("NO_METADATA"))
        return
    end

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

    local hot, crossRef = ACI.FindHotPathsWithCrossRef(2, 30)
    local hotDump = {}
    for _, h in ipairs(hot) do
        local bases = {}
        for base, count in pairs(h.bases) do
            table.insert(bases, {
                base     = base,
                count    = count,
                crossHot = crossRef[base] or 1,
            })
        end
        table.insert(hotDump, {
            eventCode  = h.eventCode,
            eventName  = ACI.EventName(h.eventCode),
            totalCount = h.totalCount,
            baseCount  = h.baseCount,
            bases      = bases,
        })
    end

    ACI_SavedVars.dump = {
        ts       = GetTimeString and GetTimeString() or "?",
        addons   = dump,
        health   = health,
        hotPaths = hotDump,
    }

    d(L("DUMP_SAVED"))
end

----------------------------------------------------------------------
-- /aci save
----------------------------------------------------------------------
function ACI.ForceSave()
    local mgr = GetAddOnManager()
    if mgr and mgr.RequestAddOnSavedVariablesPrioritySave then
        mgr:RequestAddOnSavedVariablesPrioritySave()
        d(L("SAVE_REQUESTED"))
    else
        d(L("SAVE_NOT_AVAILABLE"))
    end
end

----------------------------------------------------------------------
-- /aci help
----------------------------------------------------------------------
function ACI.PrintHelp()
    d(L("SEPARATOR"))
    d(L("HELP_TITLE"))
    d(L("SEPARATOR"))
    d(L("HELP_REPORT"))
    d(L("HELP_STATS"))
    d(L("HELP_ADDONS"))
    d(L("HELP_DEPS"))
    d(L("HELP_DEPS_X"))
    d(L("HELP_INIT"))
    d(L("HELP_ORPHANS"))
    d(L("HELP_MISSING"))
    d(L("HELP_OOD"))
    d(L("HELP_HOT"))
    d(L("HELP_HOT_REGS"))
    d(L("HELP_HEALTH"))
    d(L("HELP_SV"))
    d(L("HELP_SAVE"))
    d(L("HELP_HELP"))
    d(L("SEPARATOR"))
end
