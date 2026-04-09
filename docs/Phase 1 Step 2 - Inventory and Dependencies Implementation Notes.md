# Phase 1 Step 2 — Inventory & Deps Implementation Notes

> **Date**: 2026-04-08
>
> **Status**: Step 2 completed, in-game verification complete

---

# Implementation details

## Step 2a: Minor bug fixes

- **Remove the Reset function**: it broke live references and also interfered with `lastLoadedAddon` and the load-order timebase. The use case itself was ambiguous, since `reloadui` already serves as a natural reset.
- **Init-time prefix**: `#63` -> `load#63`, to make it clear that this is a load index rather than a sort rank.

## Step 2b: API mismatch detection

- Recorded at `GetAPIVersion()` → `metadata.currentAPI`
- Add aggregates `outOfDateCount`, `libraryCount`, `enabledCount`
- Show API version + out-of-date count in summary report (`/aci`)
- **Limitation**: No method `GetAddOnAPIVersion` in GetAddOnManager (check managerMethods dump). API versions of individual add-ons cannot be read, relying only on the `isOutOfDate` flag.

## Step 2c: Dependency Reverse Index

Added `ACI.BuildDependencyIndex()` in `ACI_Analysis.lua`:
- `forward[name]` = array of dep names needed by this addon
- `reverse[depName]` = array of add-on names that use this library
- `byName[name]` = the addon metadata entry

## Step 2d: /aci deps [name]

- `/aci deps` — Top 15 most used libraries + number of add-ons without dependencies
- `/aci deps <name>` — forward + reverse of specific add-on (case-insensitive matching)

---

# In-game verification results

## /aci deps Azurah

- 2 dependencies: LibMediaProvider-1.0 OK, LibAddonMenu-2.0 OK
- 0 reverse dependencies (normal for a primary addon)

## /aci deps (full summary)

| Library | Uses | Notes |
|-----------|--------|------|
| LibAddonMenu-2.0 | 16 | Standard settings UI library; ecosystem hub |
| LibMapPins-1.0 | 5 | Map-related |
| **HarvestMap** | **5** | **Not marked as a library, but clearly acting as one** |
| LibGPS | 4 | |
| LibDebugLogger | 4 | |
| LibHarvensAddonSettings | 4 | |
| CustomCompassPins | 4 | |
| LibCustomMenu | 3 | |
| LibMediaProvider | 3 | |
| LibMapData | 3 | |
| LibCombat | 2 | |
| LibDataEncode | 2 | |
| LibMainMenu-2.0 | 2 | |
| LibNotification | 1 | |
| LibMapPing | 1 | |

Add-ons without dependencies: 29 (39% of 75)

## /aci deps LibAddonMenu-2.0

All 16 reverse dependencies are correct: TamrielTradeCentre, FancyActionBar+, LoreBooks, SkyShards, Azurah, CombatMetrics, USPF, DolgubonsLazyWritCreator, Destinations, HarvestMap, LibAddonMenuSoundSlider, ActionDurationReminder, CrutchAlerts, BeamMeUp, pChat, and LostTreasure.

---

# Insights discovered

## 1. HarvestMap = de facto library

HarvestMap has `isLibrary: false`, but five addons (HarvestMapDLC, HarvestMapAD, HarvestMapDC, HarvestMapEP, HarvestMapNF) depend on it. It is effectively the shared base for the zone-specific data addons.

**Implications**:
- `isLibrary` flag is completely unreliable
- ACI can automatically classify a "primary addon with reverse dep count >= 3" as a de facto library
- This is exactly the kind of analysis ACI can differentiate on. Good Phase 2 material.

## 2. Add-ons without dependencies 39%

29 out of 75 are standalone. The remaining 46 are intertwined in the library ecosystem.

- More evidence that the `ZZZ_` trick is limited: 61% of the set is tied to `DependsOn`, so topological sorting overrides alphabetical order.
- The "load ACI first among the 29 without dependencies" strategy is possible, but these 29 themselves are mostly libraries (Lib*), so their diagnostic value is limited.

## 3. GetUserAddOnSavedVariablesDiskUsageMB

Confirmed existence in managerMethods dump. The actual return value is verified after the next SV flush.

---

# Phase 1 Step 2 completion check

| item | status |
|------|------|
|Reset bug fixed (removed)| ✅ |
|Init time prefix| ✅ |
|API mismatch (based on isOutOfDate)| ✅ |
|Dependency Reverse Index| ✅ |
| /aci deps [name] | ✅ |
|Check GetAddOnAPIVersion|✅ (none, isOutOfDate fallback)|

---

# Phase 2 Candidate Ideas (Discovered in this Phase)

- [ ] Automatic de facto library classification (primary addon with reverse dep ≥ 3)
- [ ] Detection of “orphan dependencies” (libraries that are installed but no one uses them)
- [ ] Hot path analysis by event code (which EVENT_* has the most handlers)
- [ ] namespace → source add-on mapping (based on debug.traceback)
