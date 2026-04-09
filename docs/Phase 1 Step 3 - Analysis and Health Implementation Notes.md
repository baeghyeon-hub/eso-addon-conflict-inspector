# Phase 1 Step 3 — Analysis Advanced & Health Implementation Notes

> **Date**: 2026-04-08
>
> **Status**: Implementation complete. First in-game verification complete, followed by a threshold-tuning pass.

---

# Implementation details

## ACI_Core.lua

- `BuildEventNameMap()` — traverse `_G` and map `EVENT_` globals to `code -> name`
- `EventName(code)` — lazily initialize the map if `eventNames` is still empty

## ACI_Analysis.lua

### Four new functions

1. **`FindOrphanLibraries()`** — `isLibrary=true` + enabled, but none of the active add-ons have DependsOn
   - Built-in case typo detection: if the lowercase of an orphan name is the same as the lowercase of another dep, return `typoHint`
2. **`FindDeFactoLibraries(threshold)`** — `isLibrary=false` but reverse dep ≥ threshold
3. **`FindEventHotPaths(threshold)`** — hot path based on base cluster. Excluding ACI's own registration.
4. **`ComputeHealthScore()`** — combine SV conflicts, outdated addons, and orphaned libraries into a red/yellow/green health result

### Fix

- `BuildDependencyIndex()` — Count only the deps of add-ons with reverse enabled (orphan detection accuracy)

## ACI_Commands.lua

### 3 new commands

- `/aci orphans` — orphan library (with typo hint) + de facto library
- `/aci hot` — Event hot path (eventName displayed, base cluster details)
- `/aci health` — Traffic light diagnostics

### Fix

- Move slash command registration to PLAYER_ACTIVATED → OnACILoaded (prevent command registration failure in case of error)

---

# In-game verification results (1st)

## `/aci health` - red

| Item | Value | Verdict |
|------|---|------|
| out-of-date |43|RED (threshold >5)|
| orphan |6| YELLOW (>3) |
| SV conflicts | 0 | OK |
| hot path | 5 | info |

### Interpreting the 43 out-of-date addons

The season immediately after U49 (2026-03-09). Authors do not update API version tag. Since the "Allow out of date addons" checkbox is turned on, it actually works, but isOutOfDate=true. **ACI's diagnosis was accurate, but the thresholds were too sensitive.**

→ Threshold adjustment: `>20` RED, `>10` YELLOW, `>0` INFO

## /aci orphans — 6

|library|typo?|note|
|-----------|------|------|
| **libAddonKeybinds** |**Highly likely**|Starts with lowercase letters `l`. Other add-ons depend on `LibAddonKeybinds` (capital letters)|
| LibZone | - | |
| NodeDetection | - | |
| LibMarify | - | |
| LibQuestData | - | |
| LibDialog | - | |

### Case-sensitive typo detected

`libAddonKeybinds` (lowercase l) — Other add-ons may be DependsOn with `LibAddonKeybinds` (uppercase L). Matching failed due to typo in folder name → classified as orphan. **An example of ACI automatically diagnosing an installation error.**

→ Added typo hint function: warn if the lowercase of the orphan name is the same as the lowercase of another dep

## /aci hot — 5 hot paths

| eventCode | Base clusters | Total registrations | Estimated event | Main registrants |
|-----------|--------|--------|-----------|----------------|
| 589824 | 7 | 9 |EVENT_PLAYER_ACTIVATED?| ZO_Frame, LibCombat, CombatAlerts, ACI |
| 131129 | 6 | 8 |EVENT_POWER_UPDATE?| LibCombat, FAB+, Azurah |
| 131109 | 5 | 141 |EVENT_COMBAT_EVENT?| LibCombat×136, CrutchAlerts |
| 131459 | 4 | 5 |GROUP/ROLE?| CombatAlerts, LibCombat, LCA, Azurah |
| 65540 | 3 | 7 |EVENT_SCREEN_RESIZED?| ZO_Frame, ZO_ItemPreview, FAB |

### Key Insights

- **131109 (estimated EVENT_COMBAT_EVENT)**: 136 cases in LibCombat alone. A single add-on is registered with 136 namespaces in a single event. It's a filter trick, but there is a real callback cost. The #1 suspect for FPS bottlenecks during combat.
- **ACI itself included in hot path**: Self-registration caught in 589824 → ACI exclusion filter added
- **eventCode → Name Mapping**: Difficult to read as only numbers appear → Add EventName lazy init
- **Some ZOS native code was also captured**: `ZO_FramePlayerTargetFragment`, `ZO_ItemPreview_Shared` — Additional registration by ZOS after PLAYER_ACTIVATED

---

# 4 immediate improvements (second pass)

| # | improvement | details |
|---|------|------|
| 1 |Relax out-of-date thresholds| >20 RED, >10 YELLOW, >0 INFO |
| 2 |ACI excludes its own hot path|`namespace:find(ACI.name)` filter|
| 3 | EventName lazy init | Automatically build the map when `eventNames` is empty |
| 4 | Orphan typo hint | Detect case-only typos via lowercase comparison |

---

# Candidate ideas after Phase 2 (discovered during this phase)

- [ ] Edit distance-based typo detection (currently only case and lowercase letters. Typos on Levenshtein 1-2 pages)
- [ ] "heavy event × heavy registrant" warning (131109 + LibCombat 136)
- [ ] eventCode number → Verify completeness of name mapping (duplicate, undocumented events)
- [ ] namespace clustering missed case: AzurahATTRIBUTES vs AzurahAttributes

---

# Check Phase 1 completion status

| Step | detail | status |
|------|------|------|
| 1 |Separate files (5)| ✅ |
| 2 | Inventory + Deps | ✅ |
| 3 |Advanced Analysis + Health| ✅ |
| 4 |Commands extension|✅ (completed alongside Step 3)|
| 5 | UI (XML + Lua) |⬜ Not started|

**Steps 1 to 4 completed.** Already functional as a chat-based diagnostic tool. Step 5 (UI) can be separated into a separate phase.

---

# Current full slash command

```
/aci          Summary report
/aci health   Overall environment health (traffic lights)
/aci stats    Event registration statistics by cluster
/aci addons   Installed addon list
/aci deps     Most-used libraries
/aci deps X   Forward and reverse dependencies for addon X
/aci init     Estimated init times (top 10)
/aci orphans  Orphaned libraries + de facto libraries
/aci hot      Event hot paths
/aci sv       SV registrations + conflict report
/aci save     Force an SV save
/aci help     Help
```
