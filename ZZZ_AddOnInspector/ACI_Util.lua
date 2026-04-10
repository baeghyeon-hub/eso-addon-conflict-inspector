----------------------------------------------------------------------
-- ACI_Util.lua — pure helpers shared across modules
--
-- No game-state access, no ACI global reads beyond writing exports.
-- Loaded early in the manifest so Analysis/Commands can consume these
-- as ACI.* without local copies.
----------------------------------------------------------------------

ACI = ACI or {}

----------------------------------------------------------------------
-- String matching utilities (typo / missing-dep detection)
----------------------------------------------------------------------

-- Strip version suffixes: "LibFoo-2.0" -> "LibFoo", "LibBar-r17" -> "LibBar"
function ACI.StripVersionSuffix(name)
    return name:gsub("%-[%d%.]+$", ""):gsub("%-r%d+$", "")
end

-- Levenshtein edit distance (pure Lua, early-exit for large gaps)
function ACI.Levenshtein(a, b)
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
function ACI.FindClosestMatch(target, candidates, minLen, maxDist)
    minLen = minLen or 8
    maxDist = maxDist or 3
    if #target < minLen then return nil end

    local best, bestDist = nil, maxDist
    local tLower = target:lower()
    for _, c in ipairs(candidates) do
        if #c >= minLen then
            local dist = ACI.Levenshtein(tLower, c:lower())
            if dist < bestDist then
                bestDist = dist
                best = c
            end
        end
    end
    return best, bestDist
end

----------------------------------------------------------------------
-- Embedded sub-addon path check
-- An embedded addon lives one level deeper than /AddOns/<Root>/ — its
-- rootPath has another slash after the first directory component.
----------------------------------------------------------------------
function ACI.IsEmbeddedPath(rootPath)
    if not rootPath then return false end
    local mPos = rootPath:find("/AddOns/", 1, true)
    if not mPos then return false end
    local afterAddons = rootPath:sub(mPos + 8)  -- #"/AddOns/" = 8
    local firstSlash = afterAddons:find("/", 1, true)
    return firstSlash ~= nil and firstSlash < #afterAddons
end

----------------------------------------------------------------------
-- Color helpers (consolidate inline ternary chains in Commands.lua)
--
-- Two distinct palettes are used across ACI output:
--   * Heat palette     : orange -> yellow -> grey (busy/hot/heavy)
--   * Severity palette : red    -> yellow -> grey (broken/critical)
-- Level-based coloring (health summaries, individual issues) uses the
-- severity palette plus an optional green for the "ok" level.
----------------------------------------------------------------------

-- Map a named severity level to an ESO color code.
-- "red" -> red, "yellow" -> yellow, "green" -> green, else muted grey.
-- Individual issues pass "red"/"yellow" and fall through to grey for
-- unknown; the health headline additionally uses "green" for the ok
-- state.
function ACI.LevelColor(level)
    if level == "red" then
        return "|cFF0000"
    elseif level == "yellow" then
        return "|cFFFF00"
    elseif level == "green" then
        return "|c00FF00"
    else
        return "|cCCCCCC"
    end
end

-- Heat palette with caller-supplied thresholds.
-- value >= hot -> orange, value >= warm -> yellow, else muted grey.
function ACI.HeatThreshold(value, hot, warm)
    if value >= hot then
        return "|cFF6600"
    elseif value >= warm then
        return "|cFFFF00"
    else
        return "|cCCCCCC"
    end
end

-- Severity palette with caller-supplied thresholds.
-- value >= critical -> red, value >= warning -> yellow, else muted grey.
function ACI.SeverityThreshold(value, critical, warning)
    if value >= critical then
        return "|cFF0000"
    elseif value >= warning then
        return "|cFFFF00"
    else
        return "|cCCCCCC"
    end
end

-- Wrap `text` with a color prefix and the |r reset code.
-- Lets callers write ACI.Colorize(ACI.LevelColor(i.level), msg) instead
-- of color .. msg .. "|r" concatenations.
function ACI.Colorize(color, text)
    return color .. text .. "|r"
end
