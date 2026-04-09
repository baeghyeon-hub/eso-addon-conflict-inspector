----------------------------------------------------------------------
-- ACI_Analysis.lua — clustering, aggregation, conflict detection
----------------------------------------------------------------------

----------------------------------------------------------------------
-- String matching utilities (typo/missing dep detection)
----------------------------------------------------------------------

-- Strip version suffixes: "LibFoo-2.0" -> "LibFoo", "LibBar-r17" -> "LibBar"
local function StripVersionSuffix(name)
    return name:gsub("%-[%d%.]+$", ""):gsub("%-r%d+$", "")
end

-- Levenshtein edit distance (pure Lua, early-exit for large gaps)
local function Levenshtein(a, b)
    if a == b then return 0 end
    local la, lb = #a, #b
    if la == 0 then return lb end
    if lb == 0 then return la end
    if math.abs(la - lb) > 2 then return 99 end

    local prev = {}
    for j = 0, lb do prev[j] = j end

    for i = 1, la do
        local curr = { [0] = i }
        for j = 1, lb do
            local cost = (a:sub(i, i) == b:sub(j, j)) and 0 or 1
            curr[j] = math.min(
                prev[j] + 1,
                curr[j - 1] + 1,
                prev[j - 1] + cost
            )
        end
        prev = curr
    end
    return prev[lb]
end

-- Find closest match from candidates. Returns (name, distance) or nil.
-- minLen: skip short names to avoid false positives (default 8)
-- maxDist: accept only distances below this (default 3, i.e. <=2)
local function FindClosestMatch(target, candidates, minLen, maxDist)
    minLen = minLen or 8
    maxDist = maxDist or 3
    if #target < minLen then return nil end

    local best, bestDist = nil, maxDist
    local tLower = target:lower()
    for _, c in ipairs(candidates) do
        if #c >= minLen then
            local dist = Levenshtein(tLower, c:lower())
            if dist < bestDist then
                bestDist = dist
                best = c
            end
        end
    end
    return best, bestDist
end

----------------------------------------------------------------------
-- Embedded sub-addon detection
-- Separation of concerns: Inventory = collection, Analysis = analysis.
-- Uses rootPath stored in metadata table for analysis-phase tagging.
----------------------------------------------------------------------
local function IsEmbeddedPath(rootPath)
    if not rootPath then return false end
    local mPos = rootPath:find("/AddOns/", 1, true)
    if not mPos then return false end
    local afterAddons = rootPath:sub(mPos + 8)  -- #"/AddOns/" = 8
    local firstSlash = afterAddons:find("/", 1, true)
    return firstSlash ~= nil and firstSlash < #afterAddons
end

-- Batch-tag isEmbedded field on metadata.addons entries
function ACI.TagEmbeddedAddons()
    local meta = ACI_SavedVars and ACI_SavedVars.metadata
    if not meta or not meta.addons then return end
    for _, a in ipairs(meta.addons) do
        a.isEmbedded = IsEmbeddedPath(a.rootPath)
    end
end

----------------------------------------------------------------------
-- Event count excluding ACI's own registrations
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
-- Groups by stripping numeric suffixes: LibCombat47 -> LibCombat
----------------------------------------------------------------------
function ACI.ClusterNamespaces()
    local clusters = {}
    for _, entry in ipairs(ACI.eventLog) do
        -- Exclude ACI's own registrations
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

-- Convert clusters to sorted array (descending by registration count)
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
-- SV conflict detection
-- Same (svTable::namespace) pair with different callers = conflict
----------------------------------------------------------------------
function ACI.DetectSVConflicts()
    local conflicts = {}
    for key, entries in pairs(ACI.svRegistrations) do
        local callers = {}
        for _, e in ipairs(entries) do
            if not ACI.IsSelfNamespace(e.caller) then
                callers[e.caller] = true
            end
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
-- Dependency index (forward + reverse)
-- forward: addon -> [deps it needs]    (already in metadata.addons[].deps)
-- reverse: library -> [addons that use it]
----------------------------------------------------------------------
function ACI.BuildDependencyIndex()
    local meta = ACI_SavedVars and ACI_SavedVars.metadata
    if not meta or not meta.addons then return nil end

    local forward = {}   -- name → { depName[] }
    local reverse = {}   -- depName -> { addonName[] }  (enabled addons only)
    local byName = {}    -- name → addon entry

    for _, addon in ipairs(meta.addons) do
        byName[addon.name] = addon
        forward[addon.name] = {}
        for _, dep in ipairs(addon.deps) do
            table.insert(forward[addon.name], dep.name)
            -- reverse: only count enabled addons' deps (orphan detection accuracy)
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
-- Orphan libraries: isLibrary=true but no enabled addon depends on them.
-- 3-tier hint matching: case -> version-stripped -> levenshtein
----------------------------------------------------------------------
function ACI.FindOrphanLibraries()
    local depIndex = ACI.BuildDependencyIndex()
    if not depIndex then return {} end

    -- Map all dep names: lowercase -> original (for case-mismatch detection)
    local allDepNames = {}
    for depName in pairs(depIndex.reverse) do
        allDepNames[depName:lower()] = depName
    end

    -- Collect all dep names for hint matching
    local allDepList = {}
    for depName in pairs(depIndex.reverse) do
        table.insert(allDepList, depName)
    end

    local meta = ACI_SavedVars.metadata
    local orphans = {}
    for _, a in ipairs(meta.addons) do
        if a.enabled and a.isLibrary and not a.isEmbedded then
            local users = depIndex.reverse[a.name]
            if not users or #users == 0 then
                -- 3-tier hint: case match -> version-stripped -> levenshtein
                local hint = nil
                local lower = a.name:lower()

                -- Tier 1: exact case-insensitive match against dep names
                if allDepNames[lower] and allDepNames[lower] ~= a.name then
                    hint = { type = "case", suggestion = allDepNames[lower] }
                end

                -- Tier 2: version-stripped match
                if not hint then
                    local stripped = StripVersionSuffix(a.name):lower()
                    for _, depName in ipairs(allDepList) do
                        if StripVersionSuffix(depName):lower() == stripped and depName ~= a.name then
                            hint = { type = "version", suggestion = depName }
                            break
                        end
                    end
                end

                -- Tier 3: levenshtein distance <= 2
                if not hint then
                    local match = FindClosestMatch(a.name, allDepList)
                    if match then
                        hint = { type = "typo", suggestion = match }
                    end
                end

                table.insert(orphans, { name = a.name, hint = hint })
            end
        end
    end
    return orphans
end

----------------------------------------------------------------------
-- Missing dependencies: declared in DependsOn but not installed.
-- 3-tier hint matching against installed addon names.
----------------------------------------------------------------------
function ACI.FindMissingDependencies()
    local depIndex = ACI.BuildDependencyIndex()
    if not depIndex then return {} end

    local meta = ACI_SavedVars and ACI_SavedVars.metadata
    if not meta or not meta.addons then return {} end

    -- Build installed name lookup (lowercase -> actual name)
    local installedLower = {}
    local installedList = {}
    for _, a in ipairs(meta.addons) do
        installedLower[a.name:lower()] = a.name
        table.insert(installedList, a.name)
    end

    local missing = {}
    for depName, users in pairs(depIndex.reverse) do
        if not depIndex.byName[depName] then
            -- This dep name has no matching installed addon
            local hint = nil

            -- Tier 1: case-insensitive exact match
            local lower = depName:lower()
            if installedLower[lower] and installedLower[lower] ~= depName then
                hint = { type = "case", suggestion = installedLower[lower] }
            end

            -- Tier 2: version-stripped match
            if not hint then
                local stripped = StripVersionSuffix(depName):lower()
                for _, installed in ipairs(installedList) do
                    if StripVersionSuffix(installed):lower() == stripped and installed ~= depName then
                        hint = { type = "version", suggestion = installed }
                        break
                    end
                end
            end

            -- Tier 3: levenshtein distance <= 2
            if not hint then
                local match = FindClosestMatch(depName, installedList)
                if match then
                    hint = { type = "typo", suggestion = match }
                end
            end

            table.insert(missing, {
                name = depName,
                users = users,
                hint = hint,
            })
        end
    end

    table.sort(missing, function(a, b) return #a.users > #b.users end)
    return missing
end

----------------------------------------------------------------------
-- De-facto library: not flagged isLibrary but reverse dep >= threshold
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
-- Event Hot Path: N+ base clusters registered on the same eventCode
----------------------------------------------------------------------
function ACI.FindEventHotPaths(threshold)
    threshold = threshold or 3
    local perEvent = {}
    for _, e in ipairs(ACI.eventLog) do
        -- Exclude ACI's own registrations
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
-- Safe-to-delete libraries: orphan AND out-of-date (zero-risk removal)
----------------------------------------------------------------------
function ACI.FindSafeToDelete()
    local orphans = ACI.FindOrphanLibraries()
    local meta = ACI_SavedVars and ACI_SavedVars.metadata
    if not meta or not meta.addons then return {} end

    local orphanSet = {}
    for _, o in ipairs(orphans) do
        orphanSet[o.name] = true
    end

    ACI.TagEmbeddedAddons()

    local result = {}
    local totalSaveMB = 0
    for _, a in ipairs(meta.addons) do
        if a.enabled and a.isLibrary and a.isOutOfDate
            and not a.isEmbedded and orphanSet[a.name]
        then
            local mb = a.svDiskMB or 0
            totalSaveMB = totalSaveMB + mb
            table.insert(result, { name = a.name, version = a.version, svDiskMB = mb })
        end
    end
    -- Sort by SV size descending (biggest waste first)
    table.sort(result, function(a, b) return a.svDiskMB > b.svDiskMB end)
    return result, totalSaveMB
end

----------------------------------------------------------------------
-- OOD segmentation — classify out-of-date addons into actionable groups
-- Returns { standalone[], libOnly[], embedded[], topLevelEnabled, ... }
----------------------------------------------------------------------
function ACI.ClassifyOOD()
    local meta = ACI_SavedVars and ACI_SavedVars.metadata
    if not meta or not meta.addons then return nil end

    ACI.TagEmbeddedAddons()

    local depIndex = ACI.BuildDependencyIndex()

    local standalone = {}   -- non-library OOD: user should update
    local libOnly    = {}   -- library OOD: author abandoned, usually harmless
    local embedded   = {}   -- bundled sub-addon: ignore, follows parent

    local topLevelEnabled = 0
    local topLevelOOD = 0
    local embeddedCount = 0

    for _, a in ipairs(meta.addons) do
        if a.enabled then
            if a.isEmbedded then
                embeddedCount = embeddedCount + 1
                if a.isOutOfDate then
                    table.insert(embedded, a.name)
                end
            else
                topLevelEnabled = topLevelEnabled + 1
                if a.isOutOfDate then
                    topLevelOOD = topLevelOOD + 1
                    if a.isLibrary then
                        -- Count how many enabled addons depend on this lib
                        local rev = depIndex and depIndex.reverse[a.name] or {}
                        table.insert(libOnly, { name = a.name, dependents = #rev })
                    else
                        table.insert(standalone, a.name)
                    end
                end
            end
        end
    end

    -- Sort libOnly by dependent count (most-depended first)
    table.sort(libOnly, function(x, y) return x.dependents > y.dependents end)

    local oodRatio = topLevelOOD / math.max(1, topLevelEnabled)

    return {
        standalone      = standalone,
        libOnly         = libOnly,
        embedded        = embedded,
        topLevelEnabled = topLevelEnabled,
        topLevelOOD     = topLevelOOD,
        embeddedCount   = embeddedCount,
        oodRatio        = oodRatio,
    }
end

----------------------------------------------------------------------
-- Health Score — overall environment diagnosis
-- Uses ClassifyOOD for segmented OOD reporting
----------------------------------------------------------------------
function ACI.ComputeHealthScore()
    local meta = ACI_SavedVars and ACI_SavedVars.metadata
    if not meta then return { level = "unknown", issues = {}, stats = {} } end

    -- Recalculate embedded tags from stored rootPath (pure Lua string)
    ACI.TagEmbeddedAddons()

    local ood         = ACI.ClassifyOOD()
    local orphans     = ACI.FindOrphanLibraries()
    local missingDeps = ACI.FindMissingDependencies()
    local deFacto     = ACI.FindDeFactoLibraries(3)
    local hotPaths    = ACI.FindEventHotPaths(3)
    local svConflicts = ACI.DetectSVConflicts()

    local issues = {}

    -- SV conflicts — always critical
    if #svConflicts > 0 then
        table.insert(issues, { level = "red", msg = #svConflicts .. " SV conflict(s)" })
    end

    -- OOD — ratio-based severity (only standalone count matters for user action)
    if ood then
        local pct = math.floor(ood.oodRatio * 100 + 0.5)
        if ood.oodRatio > 0.8 then
            table.insert(issues, { level = "red",
                msg = ood.topLevelOOD .. "/" .. ood.topLevelEnabled .. " out-of-date (" .. pct .. "%)" })
        elseif ood.oodRatio > 0.5 then
            table.insert(issues, { level = "yellow",
                msg = ood.topLevelOOD .. "/" .. ood.topLevelEnabled .. " out-of-date (" .. pct .. "%)" })
        elseif ood.topLevelOOD > 0 then
            table.insert(issues, { level = "info",
                msg = ood.topLevelOOD .. "/" .. ood.topLevelEnabled .. " out-of-date (" .. pct .. "%)" })
        end
    end

    -- Missing dependencies — always notable
    if #missingDeps > 0 then
        local hinted = 0
        for _, m in ipairs(missingDeps) do
            if m.hint then hinted = hinted + 1 end
        end
        local msg = #missingDeps .. " missing dep(s)"
        if hinted > 0 then
            msg = msg .. " (" .. hinted .. " with hints)"
        end
        table.insert(issues, { level = "yellow", msg = msg })
    end

    -- Orphan libraries
    if #orphans > 3 then
        table.insert(issues, { level = "yellow", msg = #orphans .. " unused libraries" })
    elseif #orphans > 0 then
        table.insert(issues, { level = "info", msg = #orphans .. " unused libraries" })
    end

    -- Big SV alert — single addon using > 50% of total SV disk
    if meta.addons then
        local totalMB = 0
        local biggest = { name = nil, mb = 0 }
        for _, a in ipairs(meta.addons) do
            if a.enabled and a.svDiskMB and a.svDiskMB > 0 then
                totalMB = totalMB + a.svDiskMB
                if a.svDiskMB > biggest.mb then
                    biggest = { name = a.name, mb = a.svDiskMB }
                end
            end
        end
        if totalMB > 0 and biggest.name then
            local pct = biggest.mb / totalMB * 100
            if pct > 50 then
                table.insert(issues, { level = "yellow",
                    msg = string.format("%s uses %.0f%% of SV disk (%.2f MB / %.2f MB)",
                        biggest.name, pct, biggest.mb, totalMB) })
            end
        end
    end

    -- Determine final severity level
    local level = "green"
    for _, i in ipairs(issues) do
        if i.level == "red" then level = "red"; break end
        if i.level == "yellow" then level = "yellow" end
    end

    return {
        level  = level,
        issues = issues,
        ood    = ood,
        stats  = {
            topLevelEnabled = ood and ood.topLevelEnabled or 0,
            topLevelOOD     = ood and ood.topLevelOOD or 0,
            libOOD          = ood and #ood.libOnly or 0,
            addonOOD        = ood and #ood.standalone or 0,
            embeddedCount   = ood and ood.embeddedCount or 0,
            oodRatio        = ood and ood.oodRatio or 0,
            orphans         = #orphans,
            missingDeps     = #missingDeps,
            deFacto         = #deFacto,
            hotPaths        = #hotPaths,
            svConflicts     = #svConflicts,
        },
    }
end

----------------------------------------------------------------------
-- Init time estimation (loadOrder timestamp deltas)
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
    -- Last addon excluded: no way to know time until PLAYER_ACTIVATED
    table.sort(results, function(a, b) return a.initMs > b.initMs end)
    return results
end
