# Embedded Detection Debug Report

> timestamp: dump block ts from SV
> parsed entries: 67

## Summary

| Metric | Value |
|--------|-------|
| Total enabled | 67 |
| `_result` = EMB | 10 |
| `_result` = TOP | 56 |
| `embeddedStr` = YES | 0 |
| `embeddedStr` = NO | 66 |

## Key Finding

**`_result` (recalculated from dump) = 10 EMB, 56 TOP → Logic is correct.**

**`embeddedStr` (`isEmbedded` in CollectMetadata) = 0 YES, 66 NO → Calculation failed in CollectMetadata.**

In other words, if you run the **same logic** in dump for the **same rootPath**, it will work normally.
It does not work inside CollectMetadata.

---

## Attempt History

| # |method|cord|result|
|---|------|------|------|
| 1 |slash count| `local _, n = rootPath:gsub("/", ""); return n > 3` | embeddedCount=0 |
| 2 | match + gsub + find | `match("/AddOns/(.+)")` → `gsub("/$","")` → `find("/")` | embeddedCount=0 |
| 3 |inline match| `rootPath:match("/AddOns/[^/]+/.")` | embeddedCount=0 |
| 4 | plain find + sub | `find("/AddOns/",1,true)` → `sub` → `find("/",1,true)` | embeddedCount=0 |
| - |Recalculate dump (same logic)|Recalculate from dump to `a.rootPath`|**EMB=10 normal!**|

## Cause analysis

### confirmed facts

1. rootPath format: `user:/AddOns/X/` (PC, forward slash, trailing slash)
2. embedded path: `user:/AddOns/X/Y/Z/` (2+ folders after AddOns)
3. Recalculation of dump works on `a.rootPath` (Lua string stored in table)
4. Does not work with `rootPath` variable in CollectMetadata (API return value)
5. However, when rootPath is saved in the table in CollectMetadata, it is entered as a normal string.

### Prominent hypothesis: Problem with type of API return value

The value returned by `GetAddOnRootDirectoryPath(i)` is **possible** to not be a pure Lua string.

- The string returned by ESO's C++ API is internally `const char*`,
  Automatically converted to Lua string when passed to Lua
- However, in Havok Script, this conversion is lazy or
  `:find()`, `:match()`, `:gsub()`, etc. may behave differently in C-strings
- When saved in a table, it is **copied** as a Lua string and operates normally.

### Verification method

`rootPath` to `tostring(rootPath)` or `rootPath .. ""` in CollectMetadata
The problem is likely to be resolved if you use it after forced Lua string conversion.

Or: do not calculate isEmbedded on CollectMetadata;
**Recalculating from ComputeHealthScore to `a.rootPath` (value stored in table)** definitely works.

---

## 10 EMB judgment entries (based on dump recalculation)

| # | name | rootPath | _mPos | _after | _slash1 | _lenAfter |
|---|------|---------|-------|--------|---------|-----------|
| 4 | LibMediaProvider-1.0 | `user:/AddOns/LibMediaProvider/PC/LibMediaProvider-1.0/` | 6 | `LibMediaProvider/PC/LibMediaProvider-1.0/` | 17 | 41 |
| 8 | HarvestMapDLC | `user:/AddOns/HarvestMapData/Modules/HarvestMapDLC/` | 6 | `HarvestMapData/Modules/HarvestMapDLC/` | 15 | 37 |
| 27 | HarvestMap | `user:/AddOns/HarvestMap/Modules/HarvestMap/` | 6 | `HarvestMap/Modules/HarvestMap/` | 11 | 30 |
| 30 | HarvestMapAD | `user:/AddOns/HarvestMapData/Modules/HarvestMapAD/` | 6 | `HarvestMapData/Modules/HarvestMapAD/` | 15 | 36 |
| 32 | HarvestMapDC | `user:/AddOns/HarvestMapData/Modules/HarvestMapDC/` | 6 | `HarvestMapData/Modules/HarvestMapDC/` | 15 | 36 |
| 34 | HarvestMapEP | `user:/AddOns/HarvestMapData/Modules/HarvestMapEP/` | 6 | `HarvestMapData/Modules/HarvestMapEP/` | 15 | 36 |
| 36 | HarvestMapNF | `user:/AddOns/HarvestMapData/Modules/HarvestMapNF/` | 6 | `HarvestMapData/Modules/HarvestMapNF/` | 15 | 36 |
| 40 | NodeDetection | `user:/AddOns/HarvestMap/Libs/NodeDetection/` | 6 | `HarvestMap/Libs/NodeDetection/` | 11 | 30 |
| 53 | CombatMetricsFightData | `user:/AddOns/CombatMetrics/CombatMetricsFightData/` | 6 | `CombatMetrics/CombatMetricsFightData/` | 14 | 37 |
| 65 | LibCombatAlerts | `user:/AddOns/CombatAlerts/LibCombatAlerts/` | 6 | `CombatAlerts/LibCombatAlerts/` | 13 | 29 |

## TOP Judgment Samples (First 5)

| # | name | rootPath | _mPos | _after | _slash1 | _lenAfter |
|---|------|---------|-------|--------|---------|-----------|
| 1 | VotansAdvancedSettings | `user:/AddOns/VotansAdvancedSettings/` | 6 | `VotansAdvancedSettings/` | 23 | 23 |
| 2 | TamrielTradeCentre | `user:/AddOns/TamrielTradeCentre/` | 6 | `TamrielTradeCentre/` | 19 | 19 |
| 3 | FancyActionBar+ | `user:/AddOns/FancyActionBar+/` | 6 | `FancyActionBar+/` | 16 | 16 |
| 5 | TamrielKR_Bridge | `user:/AddOns/TamrielKR_Bridge/` | 6 | `TamrielKR_Bridge/` | 17 | 17 |
| 6 | LibGPS | `user:/AddOns/LibGPS/` | 6 | `LibGPS/` | 7 | 7 |

---

## Raw Dump Block

```lua
["dump"] = 
    {
        ["addons"] = 
        {
            [1] = 
            {
                ["rootPath"] = "user:/AddOns/VotansAdvancedSettings/",
                ["name"] = "VotansAdvancedSettings",
                ["_result"] = "TOP",
                ["_lenAfter"] = 23,
                ["_slash1"] = 23,
                ["embeddedStr"] = "NO",
                ["_after"] = "VotansAdvancedSettings/",
                ["_mPos"] = 6,
            },
            [2] = 
            {
                ["rootPath"] = "user:/AddOns/TamrielTradeCentre/",
                ["name"] = "TamrielTradeCentre",
                ["_result"] = "TOP",
                ["_lenAfter"] = 19,
                ["_slash1"] = 19,
                ["embeddedStr"] = "NO",
                ["_after"] = "TamrielTradeCentre/",
                ["_mPos"] = 6,
            },
            [3] = 
            {
                ["rootPath"] = "user:/AddOns/FancyActionBar+/",
                ["name"] = "FancyActionBar+",
                ["_result"] = "TOP",
                ["_lenAfter"] = 16,
                ["_slash1"] = 16,
                ["embeddedStr"] = "NO",
                ["_after"] = "FancyActionBar+/",
                ["_mPos"] = 6,
            },
            [4] = 
            {
                ["rootPath"] = "user:/AddOns/LibMediaProvider/PC/LibMediaProvider-1.0/",
                ["name"] = "LibMediaProvider-1.0",
                ["_result"] = "EMB",
                ["_lenAfter"] = 41,
                ["_slash1"] = 17,
                ["embeddedStr"] = "NO",
                ["_after"] = "LibMediaProvider/PC/LibMediaProvider-1.0/",
                ["_mPos"] = 6,
            },
            [5] = 
            {
                ["rootPath"] = "user:/AddOns/TamrielKR_Bridge/",
                ["name"] = "TamrielKR_Bridge",
                ["_result"] = "TOP",
                ["_lenAfter"] = 17,
                ["_slash1"] = 17,
                ["embeddedStr"] = "NO",
                ["_after"] = "TamrielKR_Bridge/",
                ["_mPos"] = 6,
            },
            [6] = 
            {
                ["rootPath"] = "user:/AddOns/LibGPS/",
                ["name"] = "LibGPS",
                ["_result"] = "TOP",
                ["_lenAfter"] = 7,
                ["_slash1"] = 7,
                ["embeddedStr"] = "NO",
                ["_after"] = "LibGPS/",
                ["_mPos"] = 6,
            },
            [7] = 
            {
                ["rootPath"] = "user:/AddOns/LoreBooks/",
                ["name"] = "LoreBooks",
                ["_result"] = "TOP",
                ["_lenAfter"] = 10,
                ["_slash1"] = 10,
                ["embeddedStr"] = "NO",
                ["_after"] = "LoreBooks/",
                ["_mPos"] = 6,
            },
            [8] = 
            {
                ["rootPath"] = "user:/AddOns/HarvestMapData/Modules/HarvestMapDLC/",
                ["name"] = "HarvestMapDLC",
                ["_result"] = "EMB",
                ["_lenAfter"] = 37,
                ["_slash1"] = 15,
                ["embeddedStr"] = "NO",
                ["_after"] = "HarvestMapData/Modules/HarvestMapDLC/",
                ["_mPos"] = 6,
            },
            [9] = 
            {
                ["rootPath"] = "user:/AddOns/LibHarvensAddonSettings/",
                ["name"] = "LibHarvensAddonSettings",
                ["_result"] = "TOP",
                ["_lenAfter"] = 24,
                ["_slash1"] = 24,
                ["embeddedStr"] = "NO",
                ["_after"] = "LibHarvensAddonSettings/",
                ["_mPos"] = 6,
            },
            [10] = 
            {
                ["rootPath"] = "user:/AddOns/LibMapPins-1.0/",
                ["name"] = "LibMapPins-1.0",
                ["_result"] = "TOP",
                ["_lenAfter"] = 15,
                ["_slash1"] = 15,
                ["embeddedStr"] = "NO",
                ["_after"] = "LibMapPins-1.0/",
                ["_mPos"] = 6,
            },
            [11] = 
            {
                ["rootPath"] = "user:/AddOns/TamrielKRFontInspector/",
                ["name"] = "TamrielKRFontInspector",
                ["_result"] = "TOP",
                ["_lenAfter"] = 23,
                ["_slash1"] = 23,
                ["embeddedStr"] = "NO",
                ["_after"] = "TamrielKRFontInspector/",
                ["_mPos"] = 6,
            },
            [12] = 
            {
                ["rootPath"] = "user:/AddOns/LibChatMessage/",
                ["name"] = "LibChatMessage",
                ["_result"] = "TOP",
                ["_lenAfter"] = 15,
                ["_slash1"] = 15,
                ["embeddedStr"] = "NO",
                ["_after"] = "LibChatMessage/",
                ["_mPos"] = 6,
            },
            [13] = 
            {
                ["rootPath"] = "user:/AddOns/SkyShards/",
                ["name"] = "SkyShards",
                ["_result"] = "TOP",
                ["_lenAfter"] = 10,
                ["_slash1"] = 10,
                ["embeddedStr"] = "NO",
                ["_after"] = "SkyShards/",
                ["_mPos"] = 6,
            },
            [14] = 
            {
                ["rootPath"] = "user:/AddOns/Azurah/",
                ["name"] = "Azurah",
                ["_result"] = "TOP",
                ["_lenAfter"] = 7,
                ["_slash1"] = 7,
                ["embeddedStr"] = "NO",
                ["_after"] = "Azurah/",
                ["_mPos"] = 6,
            },
            [15] = 
            {
                ["rootPath"] = "user:/AddOns/LibTreasure/",
                ["name"] = "LibTreasure",
                ["_result"] = "TOP",
                ["_lenAfter"] = 12,
                ["_slash1"] = 12,
                ["embeddedStr"] = "NO",
                ["_after"] = "LibTreasure/",
                ["_mPos"] = 6,
            },
            [16] = 
            {
                ["rootPath"] = "user:/AddOns/libAddonKeybinds/",
                ["name"] = "libAddonKeybinds",
                ["_result"] = "TOP",
                ["_lenAfter"] = 17,
                ["_slash1"] = 17,
                ["embeddedStr"] = "NO",
                ["_after"] = "libAddonKeybinds/",
                ["_mPos"] = 6,
            },
            [17] = 
            {
                ["rootPath"] = "user:/AddOns/CombatMetrics/",
                ["name"] = "CombatMetrics",
                ["_result"] = "TOP",
                ["_lenAfter"] = 14,
                ["_slash1"] = 14,
                ["embeddedStr"] = "NO",
                ["_after"] = "CombatMetrics/",
                ["_mPos"] = 6,
            },
            [18] = 
            {
                ["rootPath"] = "user:/AddOns/TamrielKR/",
                ["name"] = "TamrielKR",
                ["_result"] = "TOP",
                ["_lenAfter"] = 10,
                ["_slash1"] = 10,
                ["embeddedStr"] = "NO",
                ["_after"] = "TamrielKR/",
                ["_mPos"] = 6,
            },
            [19] = 
            {
                ["rootPath"] = "user:/AddOns/CircularMinimap/",
                ["name"] = "CircularMinimap",
                ["_result"] = "TOP",
                ["_lenAfter"] = 16,
                ["_slash1"] = 16,
                ["embeddedStr"] = "NO",
                ["_after"] = "CircularMinimap/",
                ["_mPos"] = 6,
            },
            [20] = 
            {
                ["rootPath"] = "user:/AddOns/LibDebugLogger/",
                ["name"] = "LibDebugLogger",
                ["_result"] = "TOP",
                ["_lenAfter"] = 15,
                ["_slash1"] = 15,
                ["embeddedStr"] = "NO",
                ["_after"] = "LibDebugLogger/",
                ["_mPos"] = 6,
            },
            [21] = 
            {
                ["rootPath"] = "user:/AddOns/USPF/",
                ["name"] = "USPF",
                ["_result"] = "TOP",
                ["_lenAfter"] = 5,
                ["_slash1"] = 5,
                ["embeddedStr"] = "NO",
                ["_after"] = "USPF/",
                ["_mPos"] = 6,
            },
            [22] = 
            {
                ["rootPath"] = "user:/AddOns/BanditsUserInterface/",
                ["name"] = "BanditsUserInterface",
                ["_result"] = "TOP",
                ["_lenAfter"] = 21,
                ["_slash1"] = 21,
                ["embeddedStr"] = "NO",
                ["_after"] = "BanditsUserInterface/",
                ["_mPos"] = 6,
            },
            [23] = 
            {
                ["rootPath"] = "user:/AddOns/DolgubonsLazyWritCreator/",
                ["name"] = "DolgubonsLazyWritCreator",
                ["_result"] = "TOP",
                ["_lenAfter"] = 25,
                ["_slash1"] = 25,
                ["embeddedStr"] = "NO",
                ["_after"] = "DolgubonsLazyWritCreator/",
                ["_mPos"] = 6,
            },
            [24] = 
            {
                ["rootPath"] = "user:/AddOns/Destinations/",
                ["name"] = "Destinations",
                ["_result"] = "TOP",
                ["_lenAfter"] = 13,
                ["_slash1"] = 13,
                ["embeddedStr"] = "NO",
                ["_after"] = "Destinations/",
                ["_mPos"] = 6,
            },
            [25] = 
            {
                ["rootPath"] = "user:/AddOns/LibTableFunctions-1.0/",
                ["name"] = "LibTableFunctions-1.0",
                ["_result"] = "TOP",
                ["_lenAfter"] = 22,
                ["_slash1"] = 22,
                ["embeddedStr"] = "NO",
                ["_after"] = "LibTableFunctions-1.0/",
                ["_mPos"] = 6,
            },
            [26] = 
            {
                ["rootPath"] = "user:/AddOns/LibCustomMenu/",
                ["name"] = "LibCustomMenu",
                ["_result"] = "TOP",
                ["_lenAfter"] = 14,
                ["_slash1"] = 14,
                ["embeddedStr"] = "NO",
                ["_after"] = "LibCustomMenu/",
                ["_mPos"] = 6,
            },
            [27] = 
            {
                ["rootPath"] = "user:/AddOns/HarvestMap/Modules/HarvestMap/",
                ["name"] = "HarvestMap",
                ["_result"] = "EMB",
                ["_lenAfter"] = 30,
                ["_slash1"] = 11,
                ["embeddedStr"] = "NO",
                ["_after"] = "HarvestMap/Modules/HarvestMap/",
                ["_mPos"] = 6,
            },
            [28] = 
            {
                ["rootPath"] = "user:/AddOns/LibAddonMenuSoundSlider/",
                ["name"] = "LibAddonMenuSoundSlider",
                ["_result"] = "TOP",
                ["_lenAfter"] = 24,
                ["_slash1"] = 24,
                ["embeddedStr"] = "NO",
                ["_after"] = "LibAddonMenuSoundSlider/",
                ["_mPos"] = 6,
            },
            [29] = 
            {
                ["rootPath"] = "user:/AddOns/LibZone/",
                ["name"] = "LibZone",
                ["_result"] = "TOP",
                ["_lenAfter"] = 8,
                ["_slash1"] = 8,
                ["embeddedStr"] = "NO",
                ["_after"] = "LibZone/",
                ["_mPos"] = 6,
            },
            [30] = 
            {
                ["rootPath"] = "user:/AddOns/HarvestMapData/Modules/HarvestMapAD/",
                ["name"] = "HarvestMapAD",
                ["_result"] = "EMB",
                ["_lenAfter"] = 36,
                ["_slash1"] = 15,
                ["embeddedStr"] = "NO",
                ["_after"] = "HarvestMapData/Modules/HarvestMapAD/",
                ["_mPos"] = 6,
            },
            [31] = 
            {
                ["rootPath"] = "user:/AddOns/CustomCompassPins/",
                ["name"] = "CustomCompassPins",
                ["_result"] = "TOP",
                ["_lenAfter"] = 18,
                ["_slash1"] = 18,
                ["embeddedStr"] = "NO",
                ["_after"] = "CustomCompassPins/",
                ["_mPos"] = 6,
            },
            [32] = 
            {
                ["rootPath"] = "user:/AddOns/HarvestMapData/Modules/HarvestMapDC/",
                ["name"] = "HarvestMapDC",
                ["_result"] = "EMB",
                ["_lenAfter"] = 36,
                ["_slash1"] = 15,
                ["embeddedStr"] = "NO",
                ["_after"] = "HarvestMapData/Modules/HarvestMapDC/",
                ["_mPos"] = 6,
            },
            [33] = 
            {
                ["rootPath"] = "user:/AddOns/ActionDurationReminder/",
                ["name"] = "ActionDurationReminder",
                ["_result"] = "TOP",
                ["_lenAfter"] = 23,
                ["_slash1"] = 23,
                ["embeddedStr"] = "NO",
                ["_after"] = "ActionDurationReminder/",
                ["_mPos"] = 6,
            },
            [34] = 
            {
                ["rootPath"] = "user:/AddOns/HarvestMapData/Modules/HarvestMapEP/",
                ["name"] = "HarvestMapEP",
                ["_result"] = "EMB",
                ["_lenAfter"] = 36,
                ["_slash1"] = 15,
                ["embeddedStr"] = "NO",
                ["_after"] = "HarvestMapData/Modules/HarvestMapEP/",
                ["_mPos"] = 6,
            },
            [35] = 
            {
                ["rootPath"] = "user:/AddOns/VotansAdaptiveSettings/",
                ["name"] = "VotansAdaptiveSettings",
                ["_result"] = "TOP",
                ["_lenAfter"] = 23,
                ["_slash1"] = 23,
                ["embeddedStr"] = "NO",
                ["_after"] = "VotansAdaptiveSettings/",
                ["_mPos"] = 6,
            },
            [36] = 
            {
                ["rootPath"] = "user:/AddOns/HarvestMapData/Modules/HarvestMapNF/",
                ["name"] = "HarvestMapNF",
                ["_result"] = "EMB",
                ["_lenAfter"] = 36,
                ["_slash1"] = 15,
                ["embeddedStr"] = "NO",
                ["_after"] = "HarvestMapData/Modules/HarvestMapNF/",
                ["_mPos"] = 6,
            },
            [37] = 
            {
                ["rootPath"] = "user:/AddOns/LibMapData/",
                ["name"] = "LibMapData",
                ["_result"] = "TOP",
                ["_lenAfter"] = 11,
                ["_slash1"] = 11,
                ["embeddedStr"] = "NO",
                ["_after"] = "LibMapData/",
                ["_mPos"] = 6,
            },
            [38] = 
            {
                ["rootPath"] = "user:/AddOns/CrutchAlerts/",
                ["name"] = "CrutchAlerts",
                ["_result"] = "TOP",
                ["_lenAfter"] = 13,
                ["_slash1"] = 13,
                ["embeddedStr"] = "NO",
                ["_after"] = "CrutchAlerts/",
                ["_mPos"] = 6,
            },
            [39] = 
            {
                ["rootPath"] = "user:/AddOns/LibCombat/",
                ["name"] = "LibCombat",
                ["_result"] = "TOP",
                ["_lenAfter"] = 10,
                ["_slash1"] = 10,
                ["embeddedStr"] = "NO",
                ["_after"] = "LibCombat/",
                ["_mPos"] = 6,
            },
            [40] = 
            {
                ["rootPath"] = "user:/AddOns/HarvestMap/Libs/NodeDetection/",
                ["name"] = "NodeDetection",
                ["_result"] = "EMB",
                ["_lenAfter"] = 30,
                ["_slash1"] = 11,
                ["embeddedStr"] = "NO",
                ["_after"] = "HarvestMap/Libs/NodeDetection/",
                ["_mPos"] = 6,
            },
            [41] = 
            {
                ["rootPath"] = "user:/AddOns/displayleads/",
                ["name"] = "displayleads",
                ["_result"] = "TOP",
                ["_lenAfter"] = 13,
                ["_slash1"] = 13,
                ["embeddedStr"] = "NO",
                ["_after"] = "displayleads/",
                ["_mPos"] = 6,
            },
            [42] = 
            {
                ["rootPath"] = "user:/AddOns/LibMarify/",
                ["name"] = "LibMarify",
                ["_result"] = "TOP",
                ["_lenAfter"] = 10,
                ["_slash1"] = 10,
                ["embeddedStr"] = "NO",
                ["_after"] = "LibMarify/",
                ["_mPos"] = 6,
            },
            [43] = 
            {
                ["rootPath"] = "user:/AddOns/LibUespQuestData/",
                ["name"] = "LibUespQuestData",
                ["_result"] = "TOP",
                ["_lenAfter"] = 17,
                ["_slash1"] = 17,
                ["embeddedStr"] = "NO",
                ["_after"] = "LibUespQuestData/",
                ["_mPos"] = 6,
            },
            [44] = 
            {
                ["rootPath"] = "user:/AddOns/LibDataEncode/",
                ["name"] = "LibDataEncode",
                ["_result"] = "TOP",
                ["_lenAfter"] = 14,
                ["_slash1"] = 14,
                ["embeddedStr"] = "NO",
                ["_after"] = "LibDataEncode/",
                ["_mPos"] = 6,
            },
            [45] = 
            {
                ["rootPath"] = "user:/AddOns/ZZZ_AddOnInspector/",
                ["name"] = "ZZZ_AddOnInspector",
                ["_result"] = "TOP",
                ["_lenAfter"] = 19,
                ["_slash1"] = 19,
                ["embeddedStr"] = "NO",
                ["_after"] = "ZZZ_AddOnInspector/",
                ["_mPos"] = 6,
            },
            [46] = 
            {
                ["rootPath"] = "user:/AddOns/LibMainMenu-2.0/",
                ["name"] = "LibMainMenu-2.0",
                ["_result"] = "TOP",
                ["_lenAfter"] = 16,
                ["_slash1"] = 16,
                ["embeddedStr"] = "NO",
                ["_after"] = "LibMainMenu-2.0/",
                ["_mPos"] = 6,
            },
            [47] = 
            {
                ["rootPath"] = "user:/AddOns/LibSavedVars/",
                ["name"] = "LibSavedVars",
                ["_result"] = "TOP",
                ["_lenAfter"] = 13,
                ["_slash1"] = 13,
                ["embeddedStr"] = "NO",
                ["_after"] = "LibSavedVars/",
                ["_mPos"] = 6,
            },
            [48] = 
            {
                ["rootPath"] = "user:/AddOns/CombatAlerts/",
                ["name"] = "CombatAlerts",
                ["_result"] = "TOP",
                ["_lenAfter"] = 13,
                ["_slash1"] = 13,
                ["embeddedStr"] = "NO",
                ["_after"] = "CombatAlerts/",
                ["_mPos"] = 6,
            },
            [49] = 
            {
                ["rootPath"] = "user:/AddOns/LibMapPing/",
                ["name"] = "LibMapPing",
                ["_result"] = "TOP",
                ["_lenAfter"] = 11,
                ["_slash1"] = 11,
                ["embeddedStr"] = "NO",
                ["_after"] = "LibMapPing/",
                ["_mPos"] = 6,
            },
            [50] = 
            {
                ["rootPath"] = "user:/AddOns/LibQuestData/",
                ["name"] = "LibQuestData",
                ["_result"] = "TOP",
                ["_lenAfter"] = 13,
                ["_slash1"] = 13,
                ["embeddedStr"] = "NO",
                ["_after"] = "LibQuestData/",
                ["_mPos"] = 6,
            },
            [51] = 
            {
                ["rootPath"] = "user:/AddOns/VotansMiniMap/",
                ["name"] = "VotansMiniMap",
                ["_result"] = "TOP",
                ["_lenAfter"] = 14,
                ["_slash1"] = 14,
                ["embeddedStr"] = "NO",
                ["_after"] = "VotansMiniMap/",
                ["_mPos"] = 6,
            },
            [52] = 
            {
                ["rootPath"] = "user:/AddOns/DolgubonsLazyWritCreator-KR-Minion/",
                ["name"] = "DolgubonsLazyWritCreator-KR-Mini",
                ["_result"] = "TOP",
                ["_lenAfter"] = 35,
                ["_slash1"] = 35,
                ["embeddedStr"] = "NO",
                ["_after"] = "DolgubonsLazyWritCreator-KR-Minion/",
                ["_mPos"] = 6,
            },
            [53] = 
            {
                ["rootPath"] = "user:/AddOns/CombatMetrics/CombatMetricsFightData/",
                ["name"] = "CombatMetricsFightData",
                ["_result"] = "EMB",
                ["_lenAfter"] = 37,
                ["_slash1"] = 14,
                ["embeddedStr"] = "NO",
                ["_after"] = "CombatMetrics/CombatMetricsFightData/",
                ["_mPos"] = 6,
            },
            [54] = 
            {
                ["rootPath"] = "user:/AddOns/LibMediaProvider/",
                ["name"] = "LibMediaProvider",
                ["_result"] = "TOP",
                ["_lenAfter"] = 17,
                ["_slash1"] = 17,
                ["embeddedStr"] = "NO",
                ["_after"] = "LibMediaProvider/",
                ["_mPos"] = 6,
            },
            [55] = 
            {
                ["rootPath"] = "user:/AddOns/TamrielTradeCentre-KR-Minion/",
                ["name"] = "TamrielTradeCentre-KR-Minion",
                ["_result"] = "TOP",
                ["_lenAfter"] = 29,
                ["_slash1"] = 29,
                ["embeddedStr"] = "NO",
                ["_after"] = "TamrielTradeCentre-KR-Minion/",
                ["_mPos"] = 6,
            },
            [56] = 
            {
                ["rootPath"] = "user:/AddOns/ToggleErrorUI/",
                ["name"] = "ToggleErrorUI",
                ["_result"] = "TOP",
                ["_lenAfter"] = 14,
                ["_slash1"] = 14,
                ["embeddedStr"] = "NO",
                ["_after"] = "ToggleErrorUI/",
                ["_mPos"] = 6,
            },
            [57] = 
            {
                ["rootPath"] = "user:/AddOns/LibNotification/",
                ["name"] = "LibNotification",
                ["_result"] = "TOP",
                ["_lenAfter"] = 16,
                ["_slash1"] = 16,
                ["embeddedStr"] = "NO",
                ["_after"] = "LibNotification/",
                ["_mPos"] = 6,
            },
            [58] = 
            {
                ["rootPath"] = "user:/AddOns/pChat/",
                ["name"] = "pChat",
                ["_result"] = "TOP",
                ["_lenAfter"] = 6,
                ["_slash1"] = 6,
                ["embeddedStr"] = "NO",
                ["_after"] = "pChat/",
                ["_mPos"] = 6,
            },
            [59] = 
            {
                ["rootPath"] = "user:/AddOns/LibLazyCrafting/",
                ["name"] = "LibLazyCrafting",
                ["_result"] = "TOP",
                ["_lenAfter"] = 16,
                ["_slash1"] = 16,
                ["embeddedStr"] = "NO",
                ["_after"] = "LibLazyCrafting/",
                ["_mPos"] = 6,
            },
            [60] = 
            {
                ["rootPath"] = "user:/AddOns/TheQuestingGuide/",
                ["name"] = "TheQuestingGuide",
                ["_result"] = "TOP",
                ["_lenAfter"] = 17,
                ["_slash1"] = 17,
                ["embeddedStr"] = "NO",
                ["_after"] = "TheQuestingGuide/",
                ["_mPos"] = 6,
            },
            [61] = 
            {
                ["rootPath"] = "user:/AddOns/LibAsync/",
                ["name"] = "LibAsync",
                ["_result"] = "TOP",
                ["_lenAfter"] = 9,
                ["_slash1"] = 9,
                ["embeddedStr"] = "NO",
                ["_after"] = "LibAsync/",
                ["_mPos"] = 6,
            },
            [62] = 
            {
                ["rootPath"] = "user:/AddOns/LibDialog/",
                ["name"] = "LibDialog",
                ["_result"] = "TOP",
                ["_lenAfter"] = 10,
                ["_slash1"] = 10,
                ["embeddedStr"] = "NO",
                ["_after"] = "LibDialog/",
                ["_mPos"] = 6,
            },
            [63] = 
            {
                ["rootPath"] = "user:/AddOns/CrutchAlerts-KR-Minion/",
                ["name"] = "CrutchAlerts-KR-Minion",
                ["_result"] = "TOP",
                ["_lenAfter"] = 23,
                ["_slash1"] = 23,
                ["embeddedStr"] = "NO",
                ["_after"] = "CrutchAlerts-KR-Minion/",
                ["_mPos"] = 6,
            },
            [64] = 
            {
                ["rootPath"] = "user:/AddOns/LibAddonMenu-2.0/",
                ["name"] = "LibAddonMenu-2.0",
                ["_result"] = "TOP",
                ["_lenAfter"] = 17,
                ["_slash1"] = 17,
                ["embeddedStr"] = "NO",
                ["_after"] = "LibAddonMenu-2.0/",
                ["_mPos"] = 6,
            },
            [65] = 
            {
                ["rootPath"] = "user:/AddOns/CombatAlerts/LibCombatAlerts/",
                ["name"] = "LibCombatAlerts",
                ["_result"] = "EMB",
                ["_lenAfter"] = 29,
                ["_slash1"] = 13,
                ["embeddedStr"] = "NO",
                ["_after"] = "CombatAlerts/LibCombatAlerts/",
                ["_mPos"] = 6,
            },
            [66] = 
            {
                ["rootPath"] = "user:/AddOns/LostTreasure/",
                ["name"] = "LostTreasure",
                ["_result"] = "TOP",
                ["_lenAfter"] = 13,
                ["_slash1"] = 13,
                ["embeddedStr"] = "NO",
                ["_after"] = "LostTreasure/",
                ["_mPos"] = 6,
            },
        },
        ["health"] = 
        {
            ["issues"] = 
            {
                [1] = 
                {
["msg"] = "43/66 outdated (65%)",
                    ["level"] = "yellow",
                },
                [2] = 
                {
["msg"] = "6 unnecessary libraries",
                    ["level"] = "yellow",
                },
            },
            ["level"] = "yellow",
            ["stats"] = 
            {
                ["embeddedCount"] = 0,
                ["topLevelEnabled"] = 66,
                ["orphans"] = 6,
                ["hotPaths"] = 5,
                ["svConflicts"] = 0,
                ["oodRatio"] = 0.6515151515,
                ["libOOD"] = 21,
                ["deFacto"] = 1,
                ["addonOOD"] = 22,
                ["topLevelOOD"] = 43,
            },
        },
        ["ts"] = "23:56:39",
    }
```