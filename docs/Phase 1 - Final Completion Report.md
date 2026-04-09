# Phase 1 — Final Completion Report

> **Date**: 2026-04-09
>
> **Status**: Phase 1 is complete. The chat-based diagnostic workflow is now complete.

---

# 1. Hypothesis verification results

| Hypothesis | What we tested | Result | Notes |
|------|------|------|------|
| H1 | Whether the `ZZZ_` prefix would let ACI load early enough to hook most registrations | **Conditional PASS** | DependsOn-based topological sorting takes priority, so ACI loaded at `#63/75`. Even so, the lazy-init pattern still captured 222 registrations, which is sufficient for practical diagnostics. |
| H2 | `ZO_PreHook` on `EVENT_MANAGER:RegisterForEvent` | **PASS** | 222 live registrations were captured. LibCombat alone accounted for 136 of them via its filter trick. ZOS-native registrations were also captured. |
| H3 | Hooking the `ZO_SavedVars` constructors | **PASS** | Four constructor hooks were installed, including `NewAccountWide` and `NewCharacterIdSettings`. Five registrations were captured and no conflicts were detected. |

---

# 2. Implemented commands

```
/aci            Summary report
/aci health     Overall environment health (ratio-based traffic-light summary)
/aci stats      Event registration statistics by cluster
/aci addons     Installed addon list
/aci deps       Most-used libraries
/aci deps X     Forward and reverse dependencies for addon X
/aci init       Estimated init times (top 10)
/aci orphans    Orphaned libraries + de facto libraries
/aci hot        Event hot paths
/aci sv         SV registrations + conflict report
/aci dump       Save diagnostic data to SV
/aci debug      Embedded-detection diagnostics
/aci save       Force an SV save
/aci help       Help
```

---

# 3. Full list of diagnostic functions

| # | Capability | File | Entry point |
|---|------|------|------|
| 1 | Load-order tracking | `ACI_Core.lua` | `OnAnyAddOnLoaded` (`EVENT_ADD_ON_LOADED`) |
| 2 | Live event-registration capture | `ACI_Hooks.lua` | `InstallEventHook` (`ZO_PreHook`) |
| 3 | SV conflict detection | `ACI_Hooks.lua` + `ACI_Analysis.lua` | `InstallSVHooks` + `DetectSVConflicts` |
| 4 | Static metadata collection | `ACI_Inventory.lua` | `CollectMetadata` (67 addons) |
| 5 | Forward / reverse dependency index | `ACI_Analysis.lua` | `BuildDependencyIndex` |
| 6 | Namespace clustering | `ACI_Analysis.lua` | `ClusterNamespaces` (numeric suffix removal) |
| 7 | Orphan library detection | `ACI_Analysis.lua` | `FindOrphanLibraries` (embedded filter + typo hint) |
| 8 | De facto library detection | `ACI_Analysis.lua` | `FindDeFactoLibraries` (`reverse dep >= 3`) |
| 9 | Event hot-path analysis | `ACI_Analysis.lua` | `FindEventHotPaths` (base-cluster level) |
| 10 | Embedded sub-addon detection | `ACI_Analysis.lua` | `TagEmbeddedAddons` + `IsEmbeddedPath` |
| 11 | Health score | `ACI_Analysis.lua` | `ComputeHealthScore` (ratio-based + contextual) |
| 12 | Init-time estimation | `ACI_Analysis.lua` | `EstimateInitTimes` (load-order timestamp deltas) |
| 13 | `eventCode -> name` mapping | `ACI_Core.lua` | `BuildEventNameMap` + `EventName` (lazy init) |

---

# 4. File structure

```
ZZZ_AddOnInspector/
  ZZZ_AddOnInspector.addon    -- manifest (APIVersion 101049 101050)
  ACI_Core.lua                -- global table, SV initialization, event lifecycle
  ACI_Hooks.lua               -- ZO_PreHook hooks (EVENT_MANAGER + ZO_SavedVars)
  ACI_Inventory.lua           -- static metadata collection via GetAddOnManager
  ACI_Analysis.lua            -- clustering, aggregation, conflict detection, health score
  ACI_Commands.lua            -- /aci slash command system
```

---

# 5. Key Findings & Insights

## 5.1 LibCombat Filter Trick (Step 1)

LibCombat registers events with 172-177 unique namespaces (`LibCombat1`, `LibCombat3`, ..., `LibCombat353`). Since ESO's `AddFilterForEvent` API only allows one filter per namespace, a trick is to create a separate namespace for each filter combination.

**Implication**: raw namespace count is not a reliable "heaviness" metric. The 136 registrations on a single event (`131109`, likely `EVENT_COMBAT_EVENT`) come from a filter trick, but they still carry real callback overhead. LibCombat remains the top FPS bottleneck suspect during combat.

## 5.2 Case typo detection (Step 3)

`libAddonKeybinds` (lowercase `l`) breaks dependency matching when other addons declare `DependsOn: LibAddonKeybinds` (uppercase `L`). The addon still loads, but it becomes a zombie library that nobody can reference.

Dump item 16 shows `isOutOfDate = false`, so the addon itself loads normally. It still appears in the orphan list, which means nothing depends on it.

ACI automatically detects this pattern through lowercase comparison.

## 5.3 HarvestMap de facto library (Step 2)

HarvestMap has `isLibrary: false`, but five region-specific data addons depend on it. Its reverse dependency count is 5, so ACI correctly classifies it as a de facto library.

HarvestMap's dual folder structure:
- `HarvestMap/` — Main + `Modules/HarvestMap/` (embedded) + `Libs/NodeDetection/` (embedded)
- `HarvestMapData/` — `Modules/HarvestMapAD/`, `DC/`, `DLC/`, `EP/`, `NF/` (all embedded)

7 embedded submodules in 2 top level folders. Phase 2 “addon group” concept seed.

## 5.4 LibAddonMenu-2.0 as an ecosystem hub (Step 2)

It has 16 reverse dependencies, making it the most widely referenced library in this addon set.

## 5.5 OOD analysis immediately after U49 (Step 3.5)

| Category | Count | OOD | OOD % |
|------|---|-----|------|
| Top-level addons | 56 | 34 | 61% |
| Libraries | 23 | 18 | 78% |
| Standalone addons | 33 | 16 | 48% |
| Embedded addons | 10 | 9 | 90% |

This snapshot was taken one month after U49 (2026-03-09). A 78% OOD rate for libraries points to a structural issue: authors often leave API tags untouched even when the code still works. With "Allow out of date addons" enabled, everything ran normally.

**ACI’s interpretation**: 61% → “Normal range after patch (within 1-2 months)”. The only reasonable method is to judge based on ratios rather than absolute values.

## 5.6 Embedded detection fails 4 times in a row & resolution (Step 3.5)

### What we observed

I tried four different embedded-detection approaches inside `CollectMetadata`, and all of them produced `embeddedCount = 0`.
When I reran the same logic later against `a.rootPath` from the saved dump, it correctly produced `EMB = 10`.

### Troubleshooting history

| # | Method | Code location | Result |
|---|------|---------|------|
| 1 | `gsub("/", "")` count > 3 | Local helper inside `CollectMetadata` | `embeddedCount = 0` |
| 2 | `match("/AddOns/(.+)")` -> `gsub("/$", "")` -> `find("/")` | Local helper inside `CollectMetadata` | `embeddedCount = 0` |
| 3 | `match("/AddOns/[^/]+/.")` | Inline inside `CollectMetadata` | `embeddedCount = 0` |
| 4 | `find("/AddOns/", 1, true)` -> `sub` -> `find("/", 1, true)` | Inline inside `CollectMetadata` | `embeddedCount = 0` |
| 5 | Recalculate from dump using `a.rootPath` (same logic) | `DumpToSV` | **EMB = 10, normal** |

### Initial hypothesis -> rejected

The initial guess was that Havok Script might treat raw API-returned strings differently.
Later reproduction tests with `/aci debug` showed that `find`, `match`, `gsub`, `tostring`, `#`, and `type` all behaved normally on raw API return values. The hypothesis was rejected because it could not be reproduced.

(`gsub cnt=0` in test T7 was a `and/or` operator precedence bug in the test code)

### Root cause - still undetermined

| # | Candidate | Likelihood |
|---|------|--------|
| 1 | Differences in the `PLAYER_ACTIVATED` callback environment | Medium |
| 2 | Code path never reached because of scope / condition flow | Medium |
| 3 | Deployment timing issue | Low |

Are the 4 failures due to 4 different methods or the same root cause (code path not reached, etc.)?
It is impossible to confirm whether it was repeated 4 times as there was no debug output at the time.

### Fix

Removed isEmbedded calculation from CollectMetadata. Recalculated with `a.rootPath` saved in the Analysis stage.

```lua
--ACI_Analysis.lua top
local function IsEmbeddedPath(rootPath)
    if not rootPath then return false end
    local mPos = rootPath:find("/AddOns/", 1, true)
    if not mPos then return false end
    local afterAddons = rootPath:sub(mPos + 8)
    local firstSlash = afterAddons:find("/", 1, true)
    return firstSlash ~= nil and firstSlash < #afterAddons
end

function ACI.TagEmbeddedAddons()
    local meta = ACI_SavedVars and ACI_SavedVars.metadata
    if not meta or not meta.addons then return end
    for _, a in ipairs(meta.addons) do
        a.isEmbedded = IsEmbeddedPath(a.rootPath)
    end
end
```

### Lessons

1. **Evidence-based debugging**: Hypotheses should not be confirmed without controlled experiments
2. **Reproducibility failure itself is useful information**: “Cause unknown + solved” is more honest than “false confidence”
3. **Better design as a result**: Inventory=Collection, Analysis=Analysis Separation is the right architecture regardless of cause.
4. **Debug code can be buggy too**: Beware of Lua trap where priority `and/or` eats return value `gsub`

---

# 6. Final verification data (dump 00:21:31)

## Health Stats

| Metric |value|verification|
|--------|---|------|
| embeddedCount | 10 |Prediction 10 ✅|
| topLevelEnabled | 56 |Prediction 56 ✅|
| topLevelOOD | 34 |Prediction 34 ✅|
| oodRatio | 0.6071 | 34/56 = 0.6071 ✅ |
| libOOD | 18 | ✅ |
| addonOOD | 16 | 18+16=34 ✅ |
| orphans | 5 |NodeDetection embedded missing ✅|
| svConflicts | 0 | ✅ |
| deFacto | 1 | HarvestMap ✅ |
| hotPaths | 5 |stats raw=5, output=4 (ACI self-filtered)|

## 10 Embedded

| # | name | rootPath |
|---|------|---------|
| 4 | LibMediaProvider-1.0 | LibMediaProvider/PC/LibMediaProvider-1.0/ |
| 8 | HarvestMapDLC | HarvestMapData/Modules/HarvestMapDLC/ |
| 27 | HarvestMap | HarvestMap/Modules/HarvestMap/ |
| 30 | HarvestMapAD | HarvestMapData/Modules/HarvestMapAD/ |
| 32 | HarvestMapDC | HarvestMapData/Modules/HarvestMapDC/ |
| 34 | HarvestMapEP | HarvestMapData/Modules/HarvestMapEP/ |
| 36 | HarvestMapNF | HarvestMapData/Modules/HarvestMapNF/ |
| 40 | NodeDetection | HarvestMap/Libs/NodeDetection/ |
| 53 | CombatMetricsFightData | CombatMetrics/CombatMetricsFightData/ |
| 65 | LibCombatAlerts | CombatAlerts/LibCombatAlerts/ |

---

# 7. Bug fix history

| # | Problem | Cause | Fix | Step |
|---|------|------|------|------|
| 1 | H2 count showed 44 instead of 222 | `PLAYER_ACTIVATED` snapshot timing vs. final SV flush timing | Switched to live-table references | 0+ |
| 2 | Hook broke after `Reset()` | Creating a new table broke the PreHook closure and SV references | Removed the Reset function entirely | 2 |
| 3 | All three commands failed | `RegisterCommands` lived inside `PLAYER_ACTIVATED`, so earlier errors prevented registration | Moved registration into `OnACILoaded` | 3 |
| 4 | `if/else` syntax error | Missing `end` while adding the ACI self-filter to `FindEventHotPaths` | Fixed the control-flow structure | 3 |
| 5 | `eventCode` showed only numbers | `eventNames` map stayed empty when `PLAYER_ACTIVATED` errored out | Added lazy init to `EventName` | 3 |
| 6 | 43 OOD addons forced a RED result | Absolute threshold `> 5` was too sensitive | Switched to ratio-based thresholds (`> 0.8` RED, `> 0.5` YELLOW) | 3.5 |
| 7 | Embedded detection failed four times in a row | Root cause still undetermined, though raw strings behaved normally in later tests | Recalculate from the stored table values during Analysis | 3.5 |

---

# 8. Known unresolved issues

| # | Issue | Priority | Note |
|---|------|---------|------|
| 1 | `hotPaths` shows 5 in stats but 4 in the output | Low | ACI's self-filter is applied only at display time, not in the raw stats |
| 2 | Dump index vs. `loadOrderIndex` mismatch | Low | `GetAddOnInfo(i)` ordering differs from `EVENT_ADD_ON_LOADED` ordering, which is easy to misread |
| 3 | `/aci debug` and `/aci dump` cleanup | Low | These are troubleshooting commands; decide in Phase 2 whether to keep or remove them |

---

# 9. Candidate ideas after Phase 2

## Analysis features

- [ ] Edit distance based typo detection (Levenshtein 1-2 page typo)
- [ ] "heavy event x heavy registrant" warning (131109 + LibCombat 136)
- [ ] OOD segmentation: libraries / dependents / standalone / embedded separation
- [ ] Identify standalone addons that depend on OOD libraries
- [ ] Addon group concept (same parent dir / same author → group)
- [ ] namespace → source add-on mapping (based on debug.traceback)
- [ ] AzurahATTRIBUTES vs AzurahAttributes clustering missed case

## Platform & Infrastructure

- [ ] When console is supported, `BuildEmbeddedIndex()` is replaced with backtracking method.
- [ ] embedded Root cause of 4 consecutive failures confirmed (reproducible test within PLAYER_ACTIVATED callback)
- [ ] Systematic verification of string method operation for other API function return values ​​(timing dependence)

## related to embedded

- [ ] LibCombatAlerts are embedded, but isLibrary=true — Verify whether DependsOn is possible externally
- [ ] Parent identification: embedded → "HarvestMap > HarvestMapAD" hierarchy display
- [ ] Check the global namespace registration mechanism of embedded library

## UI (Phase 3+)

- [ ] XML + Lua-based in-game UI (separated from Step 5)
- [ ] Export report (Text / Markdown)

---

# 10. Document index

| Document | Description |
|------|------|
|Phase 0 - PoC Results and Phase 0+ Change Log.md|H1/H2/H3 verification, PoC modifications|
|Phase 0 - SV Data Analysis and H1 Reassessment.md|SV dump analysis, H1 reinterpretation|
|Phase 1 - Architecture Design.md|5-file split structure, data flow|
|Phase 1 Step 2 - Inventory and Dependencies Implementation Notes.md|API mismatch, dependency index, `/aci deps`|
|Phase 1 Step 3 - Analysis and Health Implementation Notes.md|Orphans, de facto libraries, hot paths, health|
|Phase 1 Step 3.5 - Out-of-Date Analysis and Embedded Classification.md|43 OOD analysis, embedded classification introduced|
|Phase 1 Step 3.5 - Embedded Detection Failures and Resolution.md|Four failed attempts, reproduction testing, and the eventual fix|
|Phase 1 - Final Completion Report.md|**This document**|
|ACI Dump - Verified.md|Final verification dump data|
|Embedded Detection - Debug Report.md|Embedded-detection troubleshooting dump|

---

# 11. Technology Stack Summary

| Item | Detail |
|------|------|
|language| Lua 5.1 (Havok Script) |
|Target| ESO (Elder Scrolls Online) |
|API version| 101049, 101050 |
|Hook method| ZO_PreHook (EVENT_MANAGER, ZO_SavedVars) |
|data storage|SavedVariables (live table references, flushed on reloadui/logout)|
|distribution| deploy.sh (cp -r to AddOns folder) |

---

**End of Phase 1. Complete as a chat-based diagnostic tool.**
