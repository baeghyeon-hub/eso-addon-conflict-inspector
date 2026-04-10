----------------------------------------------------------------------
-- ACI_Commands.lua — /aci slash command system
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
            d("[ACI] Unknown command: " .. args)
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
        -- Exclude ACI's own SV registrations from count
        for _, e in ipairs(entries) do
            if not ACI.IsSelfNamespace(e.caller) then
                totalSV = totalSV + 1
            end
        end
    end

    d("--------------------------------------------")
    d("[ACI] Addon Environment Report (live)")
    d("--------------------------------------------")

    local meta = ACI_SavedVars and ACI_SavedVars.metadata
    local apiStr = meta and meta.currentAPI and (" (API " .. tostring(meta.currentAPI) .. ")") or ""
    local oodStr = meta and meta.outOfDateCount and meta.outOfDateCount > 0
        and ("  |cFFFF00" .. meta.outOfDateCount .. " out-of-date|r") or ""

    d("[ACI] Loaded: " .. tostring(#ACI.loadOrder) .. " addons" .. apiStr .. ", ACI=#" .. tostring(aciLoadIndex or "?") .. oodStr)

    d("[ACI] Events: |c00FF00" .. tostring(ACI.EventCountExcludingSelf()) .. "|r registrations, " .. tostring(#sorted) .. " clusters")
    for i = 1, math.min(5, #sorted) do
        local s = sorted[i]
        local suffix = s.count > 1 and (" (" .. s.count .. ")") or ""
        d("[ACI]   " .. s.base .. suffix)
    end
    if #sorted > 5 then
        d("[ACI]   ... +" .. (#sorted - 5) .. " more")
    end

    d("[ACI] SV: " .. tostring(totalSV) .. " registrations, " .. tostring(#svConflicts) .. " conflicts")
    d("[ACI] Type /aci help for all commands")
    d("--------------------------------------------")
end

----------------------------------------------------------------------
-- /aci stats — event registration stats by cluster
----------------------------------------------------------------------
function ACI.PrintStats()
    local sorted = ACI.SortedClusters()

    d("--------------------------------------------")
    d("[ACI] Event Registration Stats — " .. tostring(ACI.EventCountExcludingSelf()) .. " total (live)")
    d("--------------------------------------------")
    for i, s in ipairs(sorted) do
        local subInfo = s.subCount > 1 and (" [" .. s.subCount .. " sub-ns]") or ""
        local color = s.count >= 50 and "|cFF6600" or s.count >= 10 and "|cFFFF00" or "|cCCCCCC"
        d(color .. string.format("  %3d  %s%s|r", s.count, s.base, subInfo))
    end
    d("--------------------------------------------")
end

----------------------------------------------------------------------
-- /aci addons — addon list
----------------------------------------------------------------------
function ACI.PrintAddons()
    local meta = ACI_SavedVars.metadata
    if not meta or not meta.addons then
        d("[ACI] No metadata. Use after PLAYER_ACTIVATED.")
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
    d("[ACI] Addon List — " .. tostring(meta.numAddons) .. " total (enabled " .. tostring(#addons + #libs) .. ", disabled " .. tostring(#disabled) .. ")")
    if outOfDate > 0 then
        d("[ACI] |cFFFF00Out-of-date: " .. tostring(outOfDate) .. "|r")
    end
    d("--------------------------------------------")

    d("[ACI] |c00FF00Addons (" .. #addons .. ")|r")
    for _, a in ipairs(addons) do
        local flag = a.isOutOfDate and "|cFFFF00!|r " or "  "
        d("[ACI] " .. flag .. a.name .. "  v" .. tostring(a.version))
    end

    d("[ACI] |c8888FF Libraries (" .. #libs .. ")|r")
    for _, a in ipairs(libs) do
        d("[ACI]   " .. a.name)
    end
    d("--------------------------------------------")
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

    d("--------------------------------------------")
    d("[ACI] SavedVariables — " .. tostring(totalSV) .. " registrations, " .. tostring(uniquePairs) .. " unique pairs")
    d("--------------------------------------------")

    for key, entries in pairs(ACI.svRegistrations) do
        local callers = {}
        for _, e in ipairs(entries) do
            -- Exclude ACI's own SV from listing
            if not ACI.IsSelfNamespace(e.caller) then
                callers[e.caller] = true
            end
        end
        if next(callers) then
            local callerStr = ""
            for c in pairs(callers) do
                callerStr = callerStr .. (callerStr ~= "" and ", " or "") .. c
            end
            d("[ACI]   " .. key .. " <- " .. callerStr)
        end
    end

    if #conflicts > 0 then
        d("[ACI] |cFF0000Conflicts: " .. #conflicts .. "|r")
        for _, c in ipairs(conflicts) do
            d("[ACI]   " .. c.key .. " <- " .. table.concat(c.callers, " vs "))
        end
    else
        d("[ACI]   No conflicts")
    end

    -- SV disk usage (top 10 by size)
    local meta = ACI_SavedVars and ACI_SavedVars.metadata
    if meta and meta.addons then
        -- Build dependency index for dependent counts
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
            d(string.format("[ACI] SV Disk Usage — %.2f MB total across %d addons", totalMB, #svSizes))
            local limit = math.min(10, #svSizes)
            for i = 1, limit do
                local s = svSizes[i]
                local sizeStr
                if s.mb >= 1 then
                    sizeStr = string.format("%.2f MB", s.mb)
                else
                    sizeStr = string.format("%.1f KB", s.mb * 1024)
                end
                local color = s.mb >= 1 and "|cFF6600" or s.mb >= 0.1 and "|cFFFF00" or "|cCCCCCC"

                -- Value/waste tag
                local tag = ""
                if s.isLibrary and s.isOrphan and s.isOOD then
                    tag = " |cFF0000[waste]|r"
                elseif s.isLibrary and s.isOrphan then
                    tag = " |cFFFF00[unused]|r"
                elseif s.isLibrary and s.dependents > 0 then
                    tag = string.format(" |c00FF00[%d deps]|r", s.dependents)
                end

                d(string.format("[ACI]   %s%s  %s|r%s", color, sizeStr, s.name, tag))
            end
            if #svSizes > 10 then
                d("[ACI]   ... +" .. (#svSizes - 10) .. " more")
            end
        end
    end

    d("--------------------------------------------")
end

----------------------------------------------------------------------
-- /aci init — addon init time estimation (top 10)
----------------------------------------------------------------------
function ACI.PrintInitTimes()
    local times = ACI.EstimateInitTimes()

    d("--------------------------------------------")
    d("[ACI] Addon Init Time Estimation (top 10)")
    d("--------------------------------------------")
    for i = 1, math.min(10, #times) do
        local t = times[i]
        local color = t.initMs >= 500 and "|cFF0000" or t.initMs >= 100 and "|cFFFF00" or "|cCCCCCC"
        d(color .. string.format("  %5dms  load#%d %s|r", t.initMs, t.index, t.addon))
    end
    d("--------------------------------------------")
end

----------------------------------------------------------------------
-- /aci deps [name] — dependency tree
----------------------------------------------------------------------
function ACI.PrintDeps(name)
    local depIndex = ACI.BuildDependencyIndex()
    if not depIndex then
        d("[ACI] No metadata. Use after PLAYER_ACTIVATED.")
        return
    end

    if name then
        -- Specific addon: forward + reverse deps (case-insensitive match)
        local matchedName = nil
        for n in pairs(depIndex.byName) do
            if n:lower() == name:lower() then
                matchedName = n
                break
            end
        end
        if not matchedName then
            d("[ACI] '" .. name .. "' not found.")
            return
        end

        local addon = depIndex.byName[matchedName]
        local fwd = depIndex.forward[matchedName] or {}
        local rev = depIndex.reverse[matchedName] or {}

        d("--------------------------------------------")
        d("[ACI] " .. matchedName .. (addon.isLibrary and " |c8888FF[Library]|r" or ""))
        d("--------------------------------------------")

        d("[ACI] Dependencies (needs): " .. tostring(#fwd))
        if #fwd > 0 then
            for _, depName in ipairs(fwd) do
                local depAddon = depIndex.byName[depName]
                local status = depAddon and (depAddon.enabled and "|c00FF00OK|r" or "|cFF0000OFF|r") or "|cFF0000MISSING|r"
                d("[ACI]   " .. depName .. " " .. status)
            end
        end

        d("[ACI] Reverse deps (used by): " .. tostring(#rev))
        if #rev > 0 then
            for _, userName in ipairs(rev) do
                d("[ACI]   " .. userName)
            end
        end
        d("--------------------------------------------")
    else
        -- Overview: most-used libraries top 15
        local sorted = {}
        for depName, users in pairs(depIndex.reverse) do
            table.insert(sorted, { name = depName, count = #users })
        end
        table.sort(sorted, function(a, b) return a.count > b.count end)

        d("--------------------------------------------")
        d("[ACI] Dependency Summary — most depended-on libraries")
        d("--------------------------------------------")
        for i = 1, math.min(15, #sorted) do
            local s = sorted[i]
            d(string.format("[ACI]   %3d dependents  %s", s.count, s.name))
        end
        if #sorted > 15 then
            d("[ACI]   ... +" .. (#sorted - 15) .. " more")
        end

        -- Addons with no dependencies
        local noDeps = {}
        for name, fwd in pairs(depIndex.forward) do
            if #fwd == 0 then
                table.insert(noDeps, name)
            end
        end
        d("[ACI] Addons with no dependencies: " .. tostring(#noDeps))
        d("--------------------------------------------")
    end
end

----------------------------------------------------------------------
-- /aci orphans — unused libraries + de-facto libraries
----------------------------------------------------------------------
function ACI.PrintOrphans()
    local orphans = ACI.FindOrphanLibraries()
    local deFacto = ACI.FindDeFactoLibraries(3)

    d("--------------------------------------------")
    d("[ACI] Library Analysis")
    d("--------------------------------------------")

    if #orphans > 0 then
        d("[ACI] |cFFFF00Unused libraries (" .. #orphans .. ")|r — no enabled addon depends on these:")
        for _, o in ipairs(orphans) do
            if o.hint then
                local tag
                if o.hint.type == "case" then
                    tag = "|cFF6600<- case mismatch? " .. o.hint.suggestion .. "|r"
                elseif o.hint.type == "version" then
                    tag = "|cFF6600<- version mismatch? " .. o.hint.suggestion .. "|r"
                else
                    tag = "|cFFFF00<- typo? " .. o.hint.suggestion .. "|r"
                end
                d("[ACI]   " .. o.name .. " " .. tag)
            else
                d("[ACI]   " .. o.name)
            end
        end
    else
        d("[ACI] |c00FF00No unused libraries|r")
    end

    if #deFacto > 0 then
        d("[ACI] |c8888FFDe-facto libraries|r — not flagged as library but multiple addons depend on:")
        for _, df in ipairs(deFacto) do
            d("[ACI]   " .. df.name .. " (" .. df.userCount .. " dependents)")
        end
    end
    d("--------------------------------------------")
end

----------------------------------------------------------------------
-- /aci missing — unresolved dependencies (declared but not installed)
----------------------------------------------------------------------
function ACI.PrintMissingDeps()
    local missing = ACI.FindMissingDependencies()

    d("--------------------------------------------")
    d("[ACI] Missing Dependencies")
    d("--------------------------------------------")

    if #missing == 0 then
        d("[ACI] |c00FF00No missing dependencies|r")
    else
        d("[ACI] |cFFFF00" .. #missing .. " dep(s) declared but not installed:|r")
        for _, m in ipairs(missing) do
            local line = "[ACI]   " .. m.name .. " (" .. #m.users .. " addon(s) need this)"
            d(line)

            if m.hint then
                local tag
                if m.hint.type == "case" then
                    tag = "|cFF6600  -> case mismatch: " .. m.hint.suggestion .. " is installed|r"
                elseif m.hint.type == "version" then
                    tag = "|cFF6600  -> version mismatch: " .. m.hint.suggestion .. " is installed|r"
                else
                    tag = "|cFFFF00  -> typo? " .. m.hint.suggestion .. " is installed|r"
                end
                d("[ACI] " .. tag)
            end

            -- List which addons need this dep
            for _, u in ipairs(m.users) do
                d("[ACI]     <- " .. u)
            end
        end
    end
    d("--------------------------------------------")
end

----------------------------------------------------------------------
-- /aci hot — event hot paths
----------------------------------------------------------------------
function ACI.PrintHotPaths(mode)
    mode = mode or "addons"
    local hot, crossRef = ACI.FindHotPathsWithCrossRef(2, 30)

    -- Re-sort by reg count if requested, then truncate to 10
    if mode == "regs" then
        table.sort(hot, function(a, b) return a.totalCount > b.totalCount end)
    end
    local limit = math.min(10, #hot)
    local truncated = {}
    for i = 1, limit do truncated[i] = hot[i] end
    hot = truncated

    local title = (mode == "regs") and "top 10 by registration count" or "top 10 by addon count"
    d("--------------------------------------------")
    d("[ACI] Event Hot Paths — " .. title)
    d("|cAAAAAA(registration count, not firing frequency. CPU impact requires profiling.)|r")
    d("--------------------------------------------")

    if #hot == 0 then
        d("[ACI] No hot paths")
    else
        -- Threshold for cross-hot warning: addon appears in >=50% of listed hot events
        local warnThreshold = math.max(3, math.floor(#hot * 0.5 + 0.5))

        for _, h in ipairs(hot) do
            local name = ACI.EventName(h.eventCode)
            local color = h.baseCount >= 5 and "|cFF6600" or h.baseCount >= 3 and "|cFFFF00" or "|cCCCCCC"
            d(color .. string.format("  %d addons, %d regs  %s|r", h.baseCount, h.totalCount, name))

            -- List registered base clusters with cross-hot annotation
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
                    crossTag = string.format("  |cFF6600[cross-hot:%d] heavy|r", b.cross)
                elseif b.cross >= 2 then
                    crossTag = string.format("  |cFFFF00[cross-hot:%d]|r", b.cross)
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
    d("--------------------------------------------")
end

----------------------------------------------------------------------
-- /aci ood — out-of-date breakdown by category
----------------------------------------------------------------------
function ACI.PrintOOD()
    local ood = ACI.ClassifyOOD()
    if not ood then
        d("[ACI] No metadata.")
        return
    end

    local pct = math.floor(ood.oodRatio * 100 + 0.5)

    d("--------------------------------------------")
    d("[ACI] Out-of-Date Breakdown")
    d(string.format("[ACI] %d/%d top-level (%d%%)", ood.topLevelOOD, ood.topLevelEnabled, pct))
    d("--------------------------------------------")

    -- Standalone addons — user action needed
    if #ood.standalone > 0 then
        d("[ACI] |cFFFF00Standalone addons (" .. #ood.standalone .. ")|r — update recommended:")
        for _, name in ipairs(ood.standalone) do
            d("[ACI]   " .. name)
        end
    else
        d("[ACI] |c00FF00No standalone addons out-of-date|r")
    end

    d("[ACI]")

    -- Libraries — author abandoned, usually harmless
    if #ood.libOnly > 0 then
        d("[ACI] |cCCCCCCLibraries (" .. #ood.libOnly .. ")|r — author outdated, usually harmless:")
        for _, lib in ipairs(ood.libOnly) do
            local depStr = lib.dependents > 0
                and (" |c888888(" .. lib.dependents .. " dependents)|r")
                or ""
            d("[ACI]   " .. lib.name .. depStr)
        end
    else
        d("[ACI] |c00FF00No libraries out-of-date|r")
    end

    d("[ACI]")

    -- Embedded — bundled, ignore
    if #ood.embedded > 0 then
        d("[ACI] |c666666Embedded (" .. #ood.embedded .. ")|r — bundled sub-addons, ignore:")
        for _, name in ipairs(ood.embedded) do
            d("[ACI]   " .. name)
        end
    else
        d("[ACI] |c00FF00No embedded sub-addons out-of-date|r")
    end

    d("--------------------------------------------")
end

----------------------------------------------------------------------
-- /aci health — overall environment diagnosis (traffic light)
----------------------------------------------------------------------
function ACI.PrintHealth()
    local h = ACI.ComputeHealthScore()
    local s = h.stats

    local color = h.level == "red" and "|cFF0000"
        or h.level == "yellow" and "|cFFFF00"
        or "|c00FF00"
    local label = h.level == "red" and "Issues Found"
        or h.level == "yellow" and "Warning"
        or "Healthy"

    d("--------------------------------------------")
    d("[ACI] " .. color .. "● " .. label .. "|r")
    d("--------------------------------------------")

    -- OOD segmented breakdown
    local ood = h.ood
    if ood then
        local pct = math.floor(ood.oodRatio * 100 + 0.5)
        d(string.format("[ACI] Out-of-date: %d/%d top-level (%d%%)",
            ood.topLevelOOD, ood.topLevelEnabled, pct))

        -- Ignorable section
        local ignorable = #ood.libOnly + #ood.embedded
        if ignorable > 0 then
            d(string.format("[ACI]   |cCCCCCCIgnorable: %d libraries + %d embedded|r",
                #ood.libOnly, #ood.embedded))
        end

        -- Attention section: standalone addons
        if #ood.standalone > 0 then
            d(string.format("[ACI]   |cFFFF00Attention: %d standalone addon(s)|r", #ood.standalone))
            -- Show up to 5 names inline
            local names = {}
            for i = 1, math.min(5, #ood.standalone) do
                table.insert(names, ood.standalone[i])
            end
            local suffix = #ood.standalone > 5 and (" +" .. (#ood.standalone - 5) .. " more") or ""
            d("[ACI]     " .. table.concat(names, ", ") .. suffix)
        end

        -- Ratio-based context
        local ctx
        if ood.oodRatio > 0.8 then
            ctx = "Major patch or long-neglected"
        elseif ood.oodRatio > 0.5 then
            ctx = "Normal after patch (1-2 months)"
        elseif ood.oodRatio > 0.2 then
            ctx = "Normal"
        else
            ctx = "Well maintained"
        end
        d("[ACI]   -> " .. ctx)
        d("[ACI]   Full breakdown: /aci ood")
    end

    -- Other issues (SV conflicts, orphans, missing deps, etc.)
    local otherIssues = {}
    for _, i in ipairs(h.issues) do
        -- OOD already shown above, skip it
        if not i.msg:find("out%-of%-date") then
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

    -- Safe-to-delete: orphan AND out-of-date (sorted by SV size)
    local safeToDelete, saveMB = ACI.FindSafeToDelete()
    if #safeToDelete > 0 then
        d("[ACI]")
        local saveStr = saveMB > 0
            and string.format(" — saves %.1f KB", saveMB * 1024)
            or ""
        d("[ACI] |cFF6600● Safe to delete (" .. #safeToDelete .. ")|r — unused AND outdated:" .. saveStr)
        for _, s in ipairs(safeToDelete) do
            local sizeTag = ""
            if s.svDiskMB and s.svDiskMB > 0 then
                if s.svDiskMB >= 1 then
                    sizeTag = string.format(" |c888888(%.2f MB)|r", s.svDiskMB)
                else
                    sizeTag = string.format(" |c888888(%.1f KB)|r", s.svDiskMB * 1024)
                end
            end
            d("[ACI]   " .. s.name .. sizeTag)
        end
        d("[ACI]   |cCCCCCC^ No dependents, no updates. Zero-risk removal.|r")
    end

    d("[ACI]")
    d("[ACI] Events: " .. tostring(ACI.EventCountExcludingSelf()) .. ", hot paths " .. tostring(s.hotPaths))
    d("[ACI] Details: /aci orphans | /aci missing | /aci ood | /aci sv")
    d("--------------------------------------------")
end

----------------------------------------------------------------------
-- /aci debug — embedded detection diagnostics
----------------------------------------------------------------------
function ACI.PrintDebug()
    local meta = ACI_SavedVars and ACI_SavedVars.metadata
    if not meta or not meta.addons then
        d("[ACI] No metadata.")
        return
    end

    ACI.TagEmbeddedAddons()

    d("--------------------------------------------")
    d("[ACI] Debug — embedded status")
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
-- /aci dump — save diagnostic data to SV (copy from file)
----------------------------------------------------------------------
function ACI.DumpToSV()
    local meta = ACI_SavedVars and ACI_SavedVars.metadata
    if not meta or not meta.addons then
        d("[ACI] No metadata.")
        return
    end

    -- Recalculate embedded tags from stored rootPath
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

    -- Hot paths with cross-reference for offline analysis
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

    d("[ACI] Dump saved. Check [\"dump\"] block in SV file after /reloadui.")
end

----------------------------------------------------------------------
-- /aci save
----------------------------------------------------------------------
function ACI.ForceSave()
    local mgr = GetAddOnManager()
    if mgr and mgr.RequestAddOnSavedVariablesPrioritySave then
        mgr:RequestAddOnSavedVariablesPrioritySave()
        d("[ACI] SV priority save requested.")
    else
        d("[ACI] Not available. Use /reloadui to save.")
    end
end

----------------------------------------------------------------------
-- /aci help
----------------------------------------------------------------------
function ACI.PrintHelp()
    d("--------------------------------------------")
    d("[ACI] Commands")
    d("--------------------------------------------")
    d("[ACI]   /aci          summary report")
    d("[ACI]   /aci stats    event registration stats")
    d("[ACI]   /aci addons   addon list")
    d("[ACI]   /aci deps     most-used libraries")
    d("[ACI]   /aci deps X   forward/reverse deps for X")
    d("[ACI]   /aci init     init time estimation (top 10)")
    d("[ACI]   /aci orphans  unused libraries + de-facto")
    d("[ACI]   /aci missing  missing dependencies + hints")
    d("[ACI]   /aci ood      out-of-date breakdown")
    d("[ACI]   /aci hot      event hot paths (by addon count)")
    d("[ACI]   /aci hot regs hot paths sorted by registration count")
    d("[ACI]   /aci health   environment diagnosis")
    d("[ACI]   /aci sv       SV registrations + conflicts")
    d("[ACI]   /aci save     force SV save")
    d("[ACI]   /aci help     this help")
    d("--------------------------------------------")
end
