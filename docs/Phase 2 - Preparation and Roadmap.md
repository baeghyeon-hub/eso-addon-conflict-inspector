# Phase 2 — Preparation & Roadmap

> **Date**: 2026-04-09
>
> **Phase 1 exit criteria**: 11 commands, 13 diagnostic capabilities, embedded detection, and a health score

---

# 1. Technical debt to clear before Phase 2

## 1-1. Follow-up experiments for the four embedded-detection failures

**Purpose**: Determine the root cause of the original failure. Gain confidence when writing code.

**Experiment A**: Test the same inside the PLAYER_ACTIVATED callback

```lua
--Temporary addition to PLAYER_ACTIVATED callback in ACI_Core.lua
local manager = GetAddOnManager()
local rootPath = manager:GetAddOnRootDirectoryPath(8) -- HarvestMapDLC
local _, cnt = rootPath:gsub("/", "")
local found = rootPath:find("/AddOns/", 1, true)
d("[ACI] PA test: gsub count=" .. tostring(cnt) .. " find=" .. tostring(found))
```

- `cnt=5, found=6` → Timing is irrelevant, the original failure was a code path problem
- `cnt=0, found=nil` → PLAYER_ACTIVATED timing issue confirmed

**Experiment B**: Restore current CollectMetadata code + debug log

```lua
--Add just before isEmbedded calculation
d("[ACI] EMB_CHECK: i=" .. i .. " rootPath=" .. tostring(rootPath))
```

- Printed → Code reached but operation failed
- Does not appear → Code path not reached (scope/conditional statement problem)

## 1-2. ACI.Reset() status check

`Reset()` was removed in Phase 0+, but the codebase still needs to be checked for leftovers.

- `ACI.eventLog = {}` creates a new table -> breaks the PreHook closure reference
- `ACI.svRegistrations = {}` → SV live reference disconnected
- `ACI.lastLoadedAddon` renewal stopped

After confirmation: Completely remove the remaining Reset code, or replace it with a safe `wipe(table)` pattern.

```lua
--Safe wipe (keep table reference)
local function wipe(t)
    for k in pairs(t) do t[k] = nil end
end
```

## 1-3. Index model cleanup

Current points of confusion:
- `GetAddOnInfo(i)` → addon manager order (dump index)
- `EVENT_ADD_ON_LOADED` order → loadOrder index
- ZZZ_AddOnInspector: dump #45, loadOrder #63

**Planned fix**: add a `loadOrderIndex` field to `metadata.addons[i]`.

```lua
--Building a mapping in OnAnyAddOnLoaded in ACI_Core.lua
ACI.loadOrderMap[addonName] = loadIndex

--Referenced in CollectMetadata in ACI_Inventory.lua
loadOrderIndex = ACI.loadOrderMap[name] or nil
```

## 1-4. ACI self-filter consistency

| Area | Exclude ACI? | Status |
|------|-------------|------|
| Hot paths | Yes | Implemented |
| Event-log total count | No | Not implemented |
| SV registrations | No | Not implemented |
| Orphan / de facto analysis | Not applicable | - |
| Health stats | No, ACI is still included | Not implemented |

**Solution**: Consistently applied with one `ACI.IsSelfNamespace(ns)` utility function.

```lua
function ACI.IsSelfNamespace(ns)
    return ns and ns:find(ACI.name, 1, true) ~= nil
end
```

---

# 2. Phase 2 core features (in order of priority)

## A. Typo Hints — Diagnosing Installation Errors (Highest Priority)

**Value**: There is no comparable tool in this niche. This is one of ACI's clearest differentiation points.

**Case**: `libAddonKeybinds` (lowercase l) vs `LibAddonKeybinds` (uppercase L)
- Add-on is loaded (isOutOfDate=false)
- No addon depends on it (orphaned)
- DependsOn has a capital L, so ESO fails to match.

**Implementation**:

```lua
--Case-ignoring reverse matching
local lowerName = a.name:lower()
for depName in pairs(depIndex.reverse) do
    if depName ~= a.name and depName:lower() == lowerName then
        --Typo hint: Dependency was set as depName, but the actual folder name is a.name
        typoHint = depName
    end
end
```

**Already partially implemented** (lowercase comparison exists in FindOrphanLibraries). In Phase 2:
- Separate into independent functions
- Add edit-distance checks as well (Levenshtein distance 1-2)
- “Suggest typo correction” message in `/aci orphans` output

## B. OOD segmentation classification

Current: "34/56 top-level addons are out of date (61%)"
Goal: "Only a small number of standalone addons should need real attention; the rest should be safely ignorable."

```lua
local oodStats = {
    libOnly     = 0,  -- library-only OOD: usually neglected tags, often still works
    dependents  = 0,  -- standalone addons affected indirectly by OOD libraries
    standalone  = 0,  -- standalone addon is OOD with no dependency excuse
    embedded    = 0,  -- handled together with the parent addon
}
```

From `/aci health`:
```
Out-of-date addons 34/56 (61%)
Usually safe to ignore: libraries 18 + embedded 9
Worth attention: 7 standalone addons
  → Azurah, LoreBooks, SkyShards, ...
```

## C. Event hot path × heavy registrant cross analysis

**Hypothesis**: LibCombat 136 registrations on EVENT_COMBAT_EVENT → Suspected fps bottleneck during combat.

**Problem**: No `debug.profile` in ESO. Callback call frequency cannot be directly measured.

**Workaround**:
- Wrapping callbacks with ZO_PreHook → Measure number of calls/time
- However, all callback wrapping has performance impact → Phase 3 profiling scope

In Phase 2, only the “Number of Registrations × Event Frequency (estimated)” matrix:
- EVENT_COMBAT_EVENT: Very frequent (tens of times per frame during combat)
- EVENT_PLAYER_ACTIVATED: One-time use
- “Many registrations for frequent events” = warning target

## D. Addon group concept

HarvestMap's dual folder structure:
- `HarvestMap/` + `HarvestMapData/` = User experience of “one HarvestMap”
- 7 embedded submodules

**Candidates by group**:
1. Share the first folder name in rootPath
2. same author
3. Share name prefix (HarvestMap*)
4. Dependency clusters (groups that depend on each other)

Late in Phase 2 or when UI work begins.

---

# 3. Exploratory/experimental tasks

## E. Dummy conflict addon (SV conflict test)

Current environment: 0 confirmed conflicts. `DetectSVConflicts` itself has not yet been validated against a real collision case.

**Setup**: create two dummy addons that use the same SV table + namespace pair.

```
DummyConflictA/
  DummyConflictA.txt  → SavedVariables: TestConflictSV
  init.lua            → ZO_SavedVars.NewAccountWide("TestConflictSV", 1, nil, {})

DummyConflictB/
  DummyConflictB.txt  → SavedVariables: TestConflictSV
  init.lua            → ZO_SavedVars.NewAccountWide("TestConflictSV", 1, nil, {})
```

If one collision occurs in `/aci sv`, success.

## F. Check GetUserAddOnSavedVariablesDiskUsageMB

It may already be collected in `managerMethods` of Phase 1 dump.
Just check in the SV file.

- Yes → SV capacity can be displayed for each add-on
- None → Alternative: Direct measurement of SV file size (impossible, no io module)

## G. OptionalDependsOn Load Order Experiment

Add the main Lib as OptionalDependsOn to the ACI manifest:

```
## OptionalDependsOn: LibDebugLogger LibAddonMenu-2.0 LibCombat HarvestMap
```

**Expected**: ACI load order by DependsOn topological sort #63 → further back.
(Need to check if OptionalDependsOn is included in topology sorting)

**RISK**: ESO documentation is unclear as to whether OptionalDependsOn is "ignore if the add-on does not exist" or "load after the add-on". Experiment needed.

## H. Namespace → addon traceback (debug.traceback)

Currently: `lastLoadedAddon` heuristic (based on EVENT_ADD_ON_LOADED order)
Problem: Events registered after PLAYER_ACTIVATED cannot be traced back.

**experiment**:
```lua
ZO_PreHook(EVENT_MANAGER, "RegisterForEvent", function(self, ns, code, callback)
    local trace = debug.traceback("", 2)
    --Extract file path from trace → Trace back add-on folder name
    local addonFolder = trace:match("user:/AddOns/([^/]+)/")
    -- ...
end)
```

Need to check if `debug.traceback` contains the file path in ESO.
SV hook in Phase 1 is already recording traceback → Check existing data.

---

# 4. Execution order (suggested)

| Order | Work | Estimated time | Dependency |
|------|------|---------|--------|
| 0 | Clear technical debt (1-1 to 1-4) | 30 min | None |
| 1 | A. Strengthen typo hints | 20 min | None |
| 2 | B. OOD segmentation | 30 min | After A (for orphan linkage) |
| 3 | F. Check the SV-capacity API | 5 min | None |
| 4 | G. OptionalDependsOn experiment | 10 min | None |
| 5 | E. Dummy conflict test | 15 min | None |
| 6 | C. Hot-path cross analysis | 30 min | None |
| 7 | H. Traceback-based addon tracing experiment | 20 min | None |
| 8 | D. Addon groups | Late Phase 2 | Depends on B and H results |

Items 3, 4, and 5 are independent experiments and can be done in any order. Item 0 should come first.

---

# 5. Phase 2 completion criteria (tentative)

- [ ] Confirm root cause of embedded failure or conclude as “unreproducible + documentation”
- [ ] Typo hint correctly catches libAddonKeybinds case
- [ ] OOD segmentation is output in the form of “N things to pay attention to” in `/aci health`
- [ ] Consistent application of ACI self-filter
- [ ] At least one SV conflict test (dummy addon)
- [ ] Write Phase 2 completion report
