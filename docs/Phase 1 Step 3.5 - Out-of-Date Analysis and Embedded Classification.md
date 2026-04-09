# Phase 1 Step 3.5 — Out-of-Date in-depth analysis & embedded distinction

> **Date**: 2026-04-08
>
> **Status**: Implementation complete, awaiting in-game verification

---

# Problem definition

`/aci health` reported 43 out-of-date addons, which pushed the result into RED.

**User Question**: “If 43 is real, is it serious, is my environment special, or is the threshold sensitive?”

---

# SV data in-depth analysis

## Raw Numbers

|item|value|
|------|---|
|GetAddOnManager total entries| 67 |
|enabled| 66 |
| Out-of-date (raw) | 43 |
|Current API| 101049 (U49, 2026-03-09) |

## Finding: embedded sub-addon expansion

ESO's `GetAddOnManager` is registered as a **separate entry** if there is a `.txt` manifest in the subfolder.

### 66 enabled entities

| Category | Count | OOD | OOD % |
|------|---|-----|------|
|**Top-level folder**| 56 | 34 | 61% |
|**Embedded sub-add-on**| 10 | 9 | 90% |
|Total (raw)| 66 | 43 | 65% |

### 10 Embedded sub-add-ons

|name| rootPath | OOD |
|------|---------|-----|
| HarvestMap | HarvestMap/Modules/HarvestMap/ | Y |
| HarvestMapAD | HarvestMapData/Modules/HarvestMapAD/ | Y |
| HarvestMapDC | HarvestMapData/Modules/HarvestMapDC/ | Y |
| HarvestMapDLC | HarvestMapData/Modules/HarvestMapDLC/ | Y |
| HarvestMapEP | HarvestMapData/Modules/HarvestMapEP/ | Y |
| HarvestMapNF | HarvestMapData/Modules/HarvestMapNF/ | Y |
| NodeDetection | HarvestMap/Libs/NodeDetection/ | Y |
| CombatMetricsFightData | CombatMetrics/CombatMetricsFightData/ | Y |
| LibMediaProvider-1.0 | LibMediaProvider/PC/LibMediaProvider-1.0/ | Y |
| LibCombatAlerts | CombatAlerts/LibCombatAlerts/ | N |

### Top-level 34 OOD details

**Library (18):**
CustomCompassPins, LibAddonMenu-2.0, LibChatMessage, LibCustomMenu, LibDataEncode, LibDialog, LibGPS, LibHarvensAddonSettings, LibMainMenu-2.0, LibMapData, LibMapPing, LibMapPins-1.0, LibMarify, LibNotification, LibQuestData, LibSavedVars, LibTableFunctions-1.0, LibUespQuestData

**Standalone Add-ons (16):**
Azurah, CircularMinimap, Destinations, LoreBooks, SkyShards, TamrielKR, TamrielKRFontInspector, TamrielKR_Bridge, TamrielTradeCentre, TheQuestingGuide, ToggleErrorUI, USPF, VotansAdaptiveSettings, VotansAdvancedSettings, VotansMiniMap, displayleads

---

# Key Analysis

## 1. The 43 OOD count is accurate, but still overstates the user-facing problem

- 9 out of 43 raw are double counts of embedded sub-add-ons
- 34/56 = 61% based on what top-level users actually “installed”
- The HarvestMap ecosystem alone contributes 6 entries, even though users mentally treat it as 1 install

## 2. 61% OOD is still within a normal range right after U49

- Library OOD 18/23 (78%) → Neglect of API tags by library authors is the structural cause
- Standalone addon OOD is 16/33 (48%), slightly higher because KR patch addons are included
- When “Allow out of date addons” is checked, everything operates normally.

## 3. Limits of absolute value thresholds

- Users installing 5 add-ons: 3 OODs = 60% (severe)
- Users installing 66 add-ons: 43 OODs = 65% (normal immediately after patch)
- **Ratio-based is the only reasonable method**

---

# Implementation details

## ACI_Inventory.lua

### New function: `IsEmbeddedAddon(rootPath)`

```lua
local function IsEmbeddedAddon(rootPath)
    if not rootPath then return false end
    if rootPath:find("Managed", 1, true) then return false end  --console path guard
    local _, slashCount = rootPath:gsub("/", "")
    return slashCount > 3  -- user:/AddOns/Folder/ = 3, embedded = 4+
end
```

### Edit: `CollectMetadata()`

- Add `isEmbedded` field to each add-on

## ACI_Analysis.lua

### Edit: `ComputeHealthScore()`

- Aggregation of `topLevelEnabled`, `topLevelOOD` excluding embedded
- Separate `libOOD`, `addonOOD`
- **Ratio-based thresholds**: >0.8 RED, >0.5 YELLOW, >0 INFO
- stats table extension: `topLevelEnabled`, `topLevelOOD`, `libOOD`, `addonOOD`, `embeddedCount`, `oodRatio`, `deFacto`

### Edit: `FindOrphanLibraries()`

- Add `a.isEmbedded` filter → Exclude orphan decision for embedded libraries

## ACI_Commands.lua

### Edit: `PrintHealth()`

- Display OOD as a separate detailed block (specify ratio + embedded exclusion)
- Ratio-based context messages: give the user a sense of what "normal" looks like
- Prevent OOD duplicate display in issues list

---

# Expected verification results

## Before (present)

```
● There is a problem
● 43 out-of-date addons (red)
● 6 unnecessary libraries (yellow)
```

## After (after modification)

```
● Caution
Out of date: 34/56 top-level addons (61%)
(Excluding 10 embedded sub-add-ons)
Libraries 18 | standalone addons 16
→ Normal range after patch (within 1-2 months)

● N unnecessary libraries (expected to decrease after embedded filtering)
```

- RED → YELLOW (61% < 80%)
- Add context so users can interpret the result correctly

---

# Comparison of embedded detection strategies

| Strategy | Advantages | Drawbacks | Adopted |
|------|------|------|------|
| Slash count + console guard | 3 lines, fast, reliable on PC | Does not support console | ✅ Phase 1 |
| Folder-name traceback (`O(n²)`) | Platform-independent, can identify parents | Longer implementation; console is the main beneficiary | Phase 3 candidate |

---

# Candidate ideas after Phase 2 (discovered during this phase)

- [ ] OOD segmentation: Separate libraries / dependents / standalone / embedded → highlight only “really noteworthy OOD”
- [ ] When console is supported, `BuildEmbeddedIndex()` is replaced with backtracking method.
- [ ] Parent identification: embedded → "HarvestMap > HarvestMapAD" hierarchy display
- [ ] Identify main body add-ons that depend on OOD libraries ("LibX is out of date → These add-ons may be affected")
