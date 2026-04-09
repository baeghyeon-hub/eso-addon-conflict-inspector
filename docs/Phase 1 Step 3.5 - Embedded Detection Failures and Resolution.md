# Phase 1 Step 3.5 — Embedded detection fails 4 times in a row & resolution

> **Date**: 2026-04-09
>
> **Status**: Fixed, in-game verified (34/56, EMB=10)
>
> **Correction**: This was initially blamed on a "Havok String Bug", but later testing showed that raw API strings behave normally under all relevant string operations. The original failure path is still unknown, but the current Analysis-stage recalculation design works reliably and is architecturally cleaner.

---

# Problem

The `IsEmbeddedAddon(rootPath)` function always returns `false` inside CollectMetadata.
All 10 embedded sub-add-ons were incorrectly classified as top-level.

---

# Troubleshooting history (4 attempts + cause discovery)

## Attempt 1: Slash count (local function)

```lua
local function IsEmbeddedAddon(rootPath)
    if not rootPath then return false end
    if rootPath:find("Managed", 1, true) then return false end
    local _, slashCount = rootPath:gsub("/", "")
    return slashCount > 3
end
```

**Result**: embeddedCount = 0. All false.

## Attempt 2: match + gsub + find (local function)

```lua
local function IsEmbeddedAddon(rootPath)
    if not rootPath then return false end
    local rel = rootPath:match("/AddOns/(.+)")
    if not rel then return false end
    rel = rel:gsub("/$", "")
    return rel:find("/", 1, true) ~= nil
end
```

**Result**: embeddedCount = 0. All false.

## Attempt 3: Inline match (remove local function)

```lua
local isEmbedded = false
if rootPath and rootPath:match("/AddOns/[^/]+/.") then
    isEmbedded = true
end
```

**Result**: embeddedCount = 0. All false.

## Attempt 4: plain find + sub (completely remove pattern)

```lua
local isEmbedded = false
if rootPath then
    local marker = "/AddOns/"
    local mPos = rootPath:find(marker, 1, true)
    if mPos then
        local afterAddons = rootPath:sub(mPos + #marker)
        local firstSlash = afterAddons:find("/", 1, true)
        if firstSlash and firstSlash < #afterAddons then
            isEmbedded = true
        end
    end
end
```

**Result**: embeddedCount = 0. All false.

## Breakthrough: dump-time recalculation

Re-running the same logic inside `/aci dump`, this time against `a.rootPath` (the value already stored in the table), produced the expected result:

```lua
--Recalculate a.rootPath inside dump
local rp = a.rootPath or ""
local mPos = rp:find("/AddOns/", 1, true)
local afterAddons = mPos and rp:sub(mPos + 8) or "N/A"
local firstSlash = afterAddons:find("/", 1, true)
-- _result = (firstSlash < #afterAddons) and "EMB" or "TOP"
```

**Result**: `_result: EMB=10, TOP=56`. **Normal operation!**

However, `isEmbedded` set in CollectMetadata of the same session is still all false.

---

# Cause

## Confirmed facts

|location|rootPath source|string operations|result|
|------|-------------|------------|------|
| CollectMetadata |`GetAddOnRootDirectoryPath(i)` direct| find/match/gsub |**All failed**|
|dump recalculation|`a.rootPath` (after saving table)| find/sub |**Normal (10 EMB)**|

The rootPath **value** used in both places is the same (`user:/AddOns/HarvestMapData/Modules/HarvestMapDLC/`).
Normal operation after assigning `a.rootPath = rootPath` to the table.

## Subsequent reproducible test results (corrected)

T1-T10 reproduction tests were run against raw API return values using `/aci debug`:

- `find()`, `match()`, `gsub()`, `tostring()`, `#`, `type()` — **All OK**
- **No difference** between raw and table values
- T7(`raw:gsub cnt = 0`) is a `and/or` operator precedence bug in the test code.

**"Havok String Bug" cannot be reproduced. Initial hypothesis was rejected due to lack of evidence.**

### Original root cause of 4 consecutive failures — **Confirmed (2026-04-09)**

**Cause: Runtime error `pairs(_G)` in `ACI.BuildEventNameMap()`**

PLAYER_ACTIVATED callback execution order:
1. `ACI.BuildEventNameMap()` — Error due to ESO protected global in `pairs(_G)` traversal
2. → ESO silently catches callback errors → Aborts the entire callback
3. → `ACI.CollectMetadata()` **Cannot run**
4. → SV metadata remains as previous session data

**The four embedded detection attempts were not "failed" but "not executed".**
The reason the dump recalculation was successful is because the `/aci dump` slash command is unrelated to the PLAYER_ACTIVATED path.

**"Havok String Bug" did not exist.** Solved by wrapping `pairs(_G)` with pcall.

Evidence: Binary search for marker `_step` confirms break at `_step=3` (just before BuildEventNameMap).

### Lessons

- Hypotheses should not be confirmed without controlled experiments.
- Failure to reproduce itself is useful information.
- “Unknown cause + solved” is more honest and safer than “false assurance”

---

# Solved: Recalculate in Analysis step

## design principles

> **Evidence-based > Speculation-based**
>
> - Successful recalculation from dump to `a.rootPath` = **Proven fact**
> - Try converting to `tostring(rootPath)` = **Hypothesis** (may or may not work)
> - Evidence-based always wins

## Change history

### ACI_Inventory.lua

- `IsEmbeddedAddon()` function **completely removed**
- **Remove** field `isEmbedded` — save only rootPath
- When substituting a table, Havok → Lua string conversion occurs automatically.

### ACI_Analysis.lua

- Add `IsEmbeddedPath(rootPath)` local function (top of file)
- Add `ACI.TagEmbeddedAddons()` function — metadata.addons array batch tagging
- Call `TagEmbeddedAddons()` at the `ComputeHealthScore()` entry point.
- `FindOrphanLibraries()` maintains the existing `not a.isEmbedded` filter (normal operation as it is after tagging)

### ACI_Commands.lua

- Remove median diagnostics from dump (problem solved)
- Add `ACI.TagEmbeddedAddons()` call (tagging before dump)

---

# Expected verification results

## /aci health

```
● Caution (or ● Normal)
Old version: 34/56 top-level (61%)
(Excluding 10 embedded sub-add-ons)
Library 18 | body 16
→ Normal range after patch (within 1-2 months)
```

## /aci dump → SV

```
embeddedCount = 10
topLevelEnabled = 56
topLevelOOD = 34
embeddedStr: YES=10, NO=56
```

---

# Phase 2+ Candidate Ideas

- [x] ~~Minimum reproduction of Havok String Bug~~ — **Not required. The bug itself did not exist.** The cause was code failure to arrive due to `pairs(_G)` error.
- [x] ~~`ACI.DetectHavokStringBug()`~~ — Not needed
- [x] ~~Verify other API functions~~ — Not required
