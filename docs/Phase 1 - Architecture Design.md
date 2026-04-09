# Phase 1 — Architecture Design

> **Date**: 2026-04-08
>
> **Status**: Draft design
>
> **Design input**: Phase 0 SV dataset (75 addons, 222 event registrations, 5 SV creations, namespace pattern analysis)

---

# 1. Data model

## 1.1 Core principles

- Store **live references** in SV. If a table reference is stored, the latest state is serialized automatically at flush time.
- Keep `eventLog` as a flat array, then aggregate it through namespace clustering when rendering the UI.
- Four-tier structure: `addon → cluster → namespace → event`

## 1.2 SavedVariables schema (`ACI_SavedVars`)

```lua
ACI_SavedVars = {
    -- settings
    settings = {
        version = 1,
        simpleMode = true,        -- Simple/Expert mode toggle
        clusterPatterns = {       -- namespace clustering patterns
            "^(LibCombat)%d+$",
            "^(CrutchAlerts%w+)%d+$",
            "^(Azurah)%w+$",
        },
    },

    -- Phase 0 data (live references)
    loadOrder       = {},   -- { index, addon, ts }[]
    eventLog        = {},   -- { ts, namespace, eventCode, callbackId }[]
    svRegistrations = {},   -- { [table::namespace] = { method, version, caller, ts, traceback }[] }

    -- Phase 1 data (static, collected once at PLAYER_ACTIVATED)
    metadata = {
        numAddons = 0,
        addons = {},          -- { name, title, author, version, enabled, isLibrary, isOutOfDate, deps[], svDiskMB, ... }[]
        managerMethods = {},
    },

    -- Phase 1 aggregates (for UI rendering, updated when /aci runs or the window opens)
    summary = {
        totalAddons = 0,
        enabledAddons = 0,
        libraryCount = 0,
        outOfDateCount = 0,
        totalEventRegistrations = 0,
        namespaceClusters = {},   -- { base, count, eventCodes[] }[]
        topHeavyAddons = {},      -- top N entries
        svTotalDiskMB = 0,
        svPerAddon = {},          -- { name, diskMB }[]
    },
}
```

## 1.3 Namespace Clustering Rules

Patterns identified in PoC data:

| Pattern | Example | Group result |
|------|------|----------|
| `LibCombat%d+` | LibCombat1, LibCombat353 |→ `LibCombat` (172 cases)|
| `CrutchAlerts%w+%d+` | CrutchAlertsEffectAlert17874 |→ `CrutchAlerts` (11 cases)|
| `Azurah%w+` | AzurahTarget, AzurahBossbar |→ `Azurah` (16 cases)|
|`FancyActionBar%p?%w*`| FancyActionBar+, FancyActionBar+UltValue |→ `FancyActionBar` (4 cases)|
|Regular case without a numeric suffix| CombatAlerts, BUI_Event |→ unchanged|

**Default clustering algorithm**:
1. Remove numeric suffix: `namespace:match("^(.-)%d+$")` → base extraction
2. Grouping items with the same base
3. Special patterns are covered with regular expressions added to `settings.clusterPatterns`

---

# 2. File structure

```
ZZZ_AddOnInspector/
├── ZZZ_AddOnInspector.addon      -- manifest
├── ACI_Core.lua                  -- global table, SV initialization, event lifecycle
├── ACI_Hooks.lua                 -- install PreHooks (RegisterForEvent, ZO_SavedVars)
├── ACI_Inventory.lua             -- static metadata collection using GetAddOnManager
├── ACI_Analysis.lua              -- clustering, aggregation, conflict detection
├── ACI_Commands.lua              -- /aci slash command system
├── ACI_UI.lua                    -- main dashboard window (late Phase 1)
├── ACI_UI.xml                    --XML Layout (late Phase 1)
└── ACI_Export.lua                -- environment report text generation (Phase 4, stub only)
```

Manifest file list:
```
ACI_Core.lua
ACI_Hooks.lua
ACI_Inventory.lua
ACI_Analysis.lua
ACI_Commands.lua
;Late phase 1
; ACI_UI.xml
; ACI_UI.lua
; ACI_Export.lua
```

### Load-order dependencies

```
Core → Hooks → Inventory → Analysis → Commands → (UI)
```

- `Core`: ACI global table, EVENT_ADD_ON_LOADED handler, SV initialization
- `Hooks`: writes data into `ACI.eventLog` and `ACI.svRegistrations`
- `Inventory`: writes static metadata into `ACI.metadata`
- `Analysis`: reads `eventLog` + `metadata` and builds `summary`
- `Commands`: prints analysis results

ESO loads files in the order listed in the manifest, so just list the above order in the manifest.

---

# 3. Slash command system

```
/aci              -- Summary report (Simple mode: traffic lights, Expert mode: detailed)
/aci stats        -- Event registration statistics by cluster
/aci addons       -- Addon list (enabled / disabled / out-of-date)
/aci deps [name]  -- Dependency tree for one addon or for the full set
/aci sv           -- SV registrations + conflict report
/aci save         --Force an SV flush
/aci reset        --Clear captured logs
/aci export       --Generate environment report text (Phase 4)
/aci mode         -- Simple ↔ Expert toggle
```

---

# 4. Phase 1 implementation sequence

## Step 1: Separate files (currently ACI_Main.lua → 5 files)

Pure refactoring. Divide code into files without changing functionality.

## Step 2: Harden ACI_Inventory.lua

- Complete collection of all addon metadata
- Build the dependency tree, including reverse lookups ("who uses this library?")
- API version mismatch detection
- isOutOfDate flag aggregate
- SV disk capacity collection

## Step 3: ACI_Analysis.lua

- Namespace clustering engine
- Counting event registrations by cluster
- Counting the number of handlers by event code (hot path candidates)
- SV collision detection (formerly DetectSVConflicts)
- Init time estimation for each add-on (loadOrder ts difference)

## Step 4: Expand ACI_Commands.lua

- Implement `/aci stats`, `/aci addons`, `/aci deps`, and `/aci sv`
- Simple mode: red / yellow / green traffic-light summary + one-line explanation
- Expert mode: output raw data

## Step 5: ACI_UI.xml + ACI_UI.lua (late phase 1)

- TopLevelControl (toggle with ESC)
- Left: addon list (scroll, search, filter)
- Right: selected addon details (metadata + event registration + dependencies)
- Top banner: warning count (out-of-date, SV collision, hot path)

---

# 5. Phase 1 UI wireframe (text)

```
┌─ AddOn Conflict Inspector ──────────────────────────────────┐
│ [Simple ▼] [Search: ________] ⚠ 3 out-of-date ⚠ 0 conflicts │
├─────────────────────┬───────────────────────────────────────┤
│ ■ Add-on list (66) │ ▶ Azurah │
│                     │   Author: Azurah Team                 │
│ ✅ Azurah        ▶ │   Version: 2.5.1                      │
│ ✅ BanditsUI        │   API: 101049 (current)               │
│ ✅ CombatAlerts     │   Type: AddOn                         │
│ ✅ CombatMetrics    │   SV Disk: 0.23 MB                   │
│ ⚠  CrutchAlerts    │                                       │
│ ✅ Destinations │ ▼ Dependencies (2) │
│ ✅ DolgubonsLazy... │     LibAddonMenu-2.0 ✅               │
│ ✅ FancyActionBar+  │     LibCustomMenu ✅                  │
│ ...                 │                                       │
│ │ ▼ Event registration (16 cases, 6 sub-ns) │
│ 📚 Library (27) │ AzurahTarget (6) │
│ ✅ LibAddonMenu     │       131129, 131131, 131132,         │
│ ✅ LibAsync         │       131123, -1, 131136              │
│ ✅ LibCombat     ⚡ │     AzurahBossbar (2)                 │
│ ...                 │     AzurahUltimate (2)                │
│                     │     AzurahAttributes (1)              │
│                     │     AzurahExperience (2)              │
│                     │     AzurahCompass (2)                  │
│                     │                                       │
│ │ ▼ Reverse dependencies (addons using this addon) │
│ │ (none) │
└─────────────────────┴───────────────────────────────────────┘
```

### Icon Legend
- ✅ Normal
- ⚠ out-of-date or warning
- ⚡ heavy registrant (cluster 50+ events)
- 📚 Library section header

---

# 6. Phase 0 data-driven design decisions

| Decision | Evidence |
|------|-------------|
|The namespace count is not used as a “heaviness” indicator.|LibCombat 172 ≠ 10x heavier than Azurah 16. The narrower the filter, the lower the callback frequency.|
|Basic clustering removes numeric suffixes|LibCombat%d+, CrutchAlerts...%d+ patterns account for 80%+ of the total|
|estimated by init time = loadOrder ts difference|CombatMetrics ~1.2s, TTC ~320ms already visible|
|CrossCheck postponed to Phase 2|The namespace→addon mapping is accurate based on traceback. Not necessary in Phase 1|
|Adopted the “100% abandonment of tracking” position|Most of the 222 cases were after PLAYER_ACTIVATED. Lib init-time registration has low diagnostic value|
|SV is stored as a live reference|Automatic serialization of the latest data at flush time. PLAYER_ACTIVATED Prevent snapshot bug from recurring|

---

# 7. Next action

- [ ] Step 1: ACI_Main.lua → Separate 5 files
- [ ] Step 2: ACI_Inventory.lua — Dependency tree + API mismatch + SV capacity
- [ ] Step 3: ACI_Analysis.lua — clustering + aggregation + init time
- [ ] Step 4: ACI_Commands.lua — /aci stats, addons, deps, sv
- [ ] Step 5: ACI_UI — Dashboard (second half of Phase 1)
- [ ] In-game verification + document recording upon completion of each step
