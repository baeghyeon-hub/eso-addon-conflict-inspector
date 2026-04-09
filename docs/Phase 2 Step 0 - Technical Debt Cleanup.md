# Phase 2 Step 0 — Eliminate technical debt

> **Date**: 2026-04-09
>
> **Status**: Experiment 1-1 verification completed, experiment code removed, awaiting remaining verification

---

# 1-1. embedded 4 consecutive failure follow-up experiments

**Purpose**: Determine the root cause of the original failure. Gain confidence when writing code.

**Implementation**: Add `ACI.RunEmbeddedExperiment()` function (ACI_Inventory.lua)

- Executed inside the PLAYER_ACTIVATED callback, just before CollectMetadata
- Test targets: index 1 (top-level), 8 (embedded HarvestMapDLC), 45 (ACI)
- Directly to the raw `GetAddOnRootDirectoryPath(i)` values:
  - `gsub("/", "")` → count
  - `find("/AddOns/", 1, true)` → position
  - IsEmbedded Executes logic inline
- Print results in chat window + save to `ACI_SavedVars.exp1_1`

**Judgment criteria**:
- `gsub=5, find=6, emb=true` (index 8) → Timing is irrelevant, the original failure was a code path issue (Hypothesis #2)
- `gsub=0, find=nil` (index 8) → PLAYER_ACTIVATED timing issue confirmed (Hypothesis #1)

**In-game results** (verified on 2026-04-09):
```
#1  VotansAdvancedSettings  gsub=3  find=6  emb=false  ✅
#8  HarvestMapDLC           gsub=5  find=6  emb=true   ✅
#45 ZZZ_AddOnInspector      gsub=3  find=6  emb=false  ✅
```

**Definitive conclusion**: PLAYER_ACTIVATED timing issue **not** (Hypothesis #1 rejected).
In the raw API return value, `gsub`, `find`, and `sub` all operate normally.
Originally, 4 consecutive failures were **code path problem** (Hypothesis #2) — Error in conditional statement/variable name/save step of upper logic.
It was the same bug repeated four times, not an API level Havok issue.

**harvest**:
- “Havok String Bug” ESOUI forum report → Completely withdrawn
- You can also use pattern matching on raw API values. No need to avoid
- Current architecture is justified for "separation of concerns" reasons rather than "avoiding Havok bugs"

**Experimental code removed**. SV's `exp1_1` field is also organized with one-time nil assignment.

---

# 1-2. Check ACI.Reset() residue

**Result**: **No residue. Clean.**

- `ACI.eventLog = {}`, `ACI.svRegistrations = {}`, `ACI.loadOrder = {}` — Only initialization declaration exists (top of ACI_Core.lua)
- No code reassignment later
- No trace of Reset() function
- `wipe()` pattern not required

---

# 1-3. Index system organized

**Problem**: `GetAddOnInfo(i)` order (dump index) and `EVENT_ADD_ON_LOADED` order (loadOrder index) mismatch.
Example: ZZZ_AddOnInspector → dump #45, loadOrder #63

**change**:

|file|change|
|------|------|
| ACI_Core.lua |Add `ACI.loadOrderMap = {}`, build `loadOrderMap[addonName] = loadIndex` from `OnAnyAddOnLoaded`|
| ACI_Inventory.lua |Add fields `loadOrderIndex = ACI.loadOrderMap[name]` to `CollectMetadata`|
| ACI_Commands.lua |Add `dumpIndex` and `loadOrderIndex` fields to dump|

**Effect**: All add-on entries now have two indices. You can check the difference in dump.

---

# 1-4. ACI self-filter consistency

**Problem**: ACI's own event/SV registrations are included in the statistics, slightly inflating the numbers.

**Solution**: Consistently applied with one `ACI.IsSelfNamespace(ns)` utility function.

```lua
function ACI.IsSelfNamespace(ns)
    return ns and ns:find(ACI.name, 1, true) ~= nil
end
```

**Application status**:

|function|Application method|change|
|------|----------|------|
| FindEventHotPaths | `IsSelfNamespace` |Existing hard coding → Refactoring to utility call|
| ClusterNamespaces | `IsSelfNamespace` |**Add new**|
|event log count (Report/Stats/Health)| `EventCountExcludingSelf()` |**Add new**|
|SV Count (Report/SV)| `IsSelfNamespace(caller)` |**Add new**|
|SV list (PrintSV)| `IsSelfNamespace(caller)` |**Add new**|

`EventCountExcludingSelf()` helper function also added to ACI_Analysis.lua.

---

# Summary of changed files

|file|changes|
|------|----------|
| ACI_Core.lua |`IsSelfNamespace()` utility, `loadOrderMap` field, `RunEmbeddedExperiment()` call|
| ACI_Inventory.lua |`RunEmbeddedExperiment()` function, `loadOrderIndex` field|
| ACI_Analysis.lua |`EventCountExcludingSelf()`, ClusterNamespaces self-filter, hot path refactoring|
| ACI_Commands.lua |Apply event/SV count self-filter, add index field to dump|

---

# In-game verification items

- [ ] Experiment 1-1: Checking raw string operation results at PLAYER_ACTIVATED point
- [ ] self-filter: `/aci` event count should be slightly lower than before (excluding ACI's own registration)
- [ ] self-filter: ACI_SavedVars related items excluded from `/aci sv`
- [ ] self-filter: ACI cluster excluded from `/aci stats`
- [ ] loadOrderIndex: Check the difference between dumpIndex and loadOrderIndex in `/aci dump`
