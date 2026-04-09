# ACI Dump — Embedded modification verification completed

> timestamp: 00:21:31
> level: yellow

## Health Stats

| Metric | Value |
|--------|-------|
| embeddedCount | 10 |
| topLevelEnabled | 56 |
| topLevelOOD | 34 |
| oodRatio | 0.6071428571 |
| embeddedStr YES | 10 |
| embeddedStr NO | 56 |

## Raw Dump Block

```lua
["dump"] = 
    {
        ["ts"] = "00:21:31",
        ["health"] = 
        {
            ["issues"] = 
            {
                [1] = 
                {
["msg"] = "34/56 outdated (61%)",
                    ["level"] = "yellow",
                },
                [2] = 
                {
["msg"] = "5 unnecessary libraries",
                    ["level"] = "yellow",
                },
            },
            ["level"] = "yellow",
            ["stats"] = 
            {
                ["hotPaths"] = 5,
                ["addonOOD"] = 16,
                ["orphans"] = 5,
                ["topLevelOOD"] = 34,
                ["libOOD"] = 18,
                ["svConflicts"] = 0,
                ["topLevelEnabled"] = 56,
                ["deFacto"] = 1,
                ["embeddedCount"] = 10,
                ["oodRatio"] = 0.6071428571,
            },
        },
        ["addons"] = 
        {
            [1] = 
            {
                ["isOutOfDate"] = true,
                ["name"] = "VotansAdvancedSettings",
                ["embeddedStr"] = "NO",
                ["rootPath"] = "user:/AddOns/VotansAdvancedSettings/",
                ["isLibrary"] = false,
            },
            [2] = 
            {
                ["isOutOfDate"] = true,
                ["name"] = "TamrielTradeCentre",
                ["embeddedStr"] = "NO",
                ["rootPath"] = "user:/AddOns/TamrielTradeCentre/",
                ["isLibrary"] = false,
            },
            [3] = 
            {
                ["isOutOfDate"] = false,
                ["name"] = "FancyActionBar+",
                ["embeddedStr"] = "NO",
                ["rootPath"] = "user:/AddOns/FancyActionBar+/",
                ["isLibrary"] = false,
            },
            [4] = 
            {
                ["isOutOfDate"] = true,
                ["name"] = "LibMediaProvider-1.0",
                ["embeddedStr"] = "YES",
                ["rootPath"] = "user:/AddOns/LibMediaProvider/PC/LibMediaProvider-1.0/",
                ["isLibrary"] = true,
            },
            [5] = 
            {
                ["isOutOfDate"] = true,
                ["name"] = "TamrielKR_Bridge",
                ["embeddedStr"] = "NO",
                ["rootPath"] = "user:/AddOns/TamrielKR_Bridge/",
                ["isLibrary"] = false,
            },
            [6] = 
            {
                ["isOutOfDate"] = true,
                ["name"] = "LibGPS",
                ["embeddedStr"] = "NO",
                ["rootPath"] = "user:/AddOns/LibGPS/",
                ["isLibrary"] = true,
            },
            [7] = 
            {
                ["isOutOfDate"] = true,
                ["name"] = "LoreBooks",
                ["embeddedStr"] = "NO",
                ["rootPath"] = "user:/AddOns/LoreBooks/",
                ["isLibrary"] = false,
            },
            [8] = 
            {
                ["isOutOfDate"] = true,
                ["name"] = "HarvestMapDLC",
                ["embeddedStr"] = "YES",
                ["rootPath"] = "user:/AddOns/HarvestMapData/Modules/HarvestMapDLC/",
                ["isLibrary"] = false,
            },
            [9] = 
            {
                ["isOutOfDate"] = true,
                ["name"] = "LibHarvensAddonSettings",
                ["embeddedStr"] = "NO",
                ["rootPath"] = "user:/AddOns/LibHarvensAddonSettings/",
                ["isLibrary"] = true,
            },
            [10] = 
            {
                ["isOutOfDate"] = true,
                ["name"] = "LibMapPins-1.0",
                ["embeddedStr"] = "NO",
                ["rootPath"] = "user:/AddOns/LibMapPins-1.0/",
                ["isLibrary"] = true,
            },
            [11] = 
            {
                ["isOutOfDate"] = true,
                ["name"] = "TamrielKRFontInspector",
                ["embeddedStr"] = "NO",
                ["rootPath"] = "user:/AddOns/TamrielKRFontInspector/",
                ["isLibrary"] = false,
            },
            [12] = 
            {
                ["isOutOfDate"] = true,
                ["name"] = "LibChatMessage",
                ["embeddedStr"] = "NO",
                ["rootPath"] = "user:/AddOns/LibChatMessage/",
                ["isLibrary"] = true,
            },
            [13] = 
            {
                ["isOutOfDate"] = true,
                ["name"] = "SkyShards",
                ["embeddedStr"] = "NO",
                ["rootPath"] = "user:/AddOns/SkyShards/",
                ["isLibrary"] = false,
            },
            [14] = 
            {
                ["isOutOfDate"] = true,
                ["name"] = "Azurah",
                ["embeddedStr"] = "NO",
                ["rootPath"] = "user:/AddOns/Azurah/",
                ["isLibrary"] = false,
            },
            [15] = 
            {
                ["isOutOfDate"] = false,
                ["name"] = "LibTreasure",
                ["embeddedStr"] = "NO",
                ["rootPath"] = "user:/AddOns/LibTreasure/",
                ["isLibrary"] = true,
            },
            [16] = 
            {
                ["isOutOfDate"] = false,
                ["name"] = "libAddonKeybinds",
                ["embeddedStr"] = "NO",
                ["rootPath"] = "user:/AddOns/libAddonKeybinds/",
                ["isLibrary"] = true,
            },
            [17] = 
            {
                ["isOutOfDate"] = false,
                ["name"] = "CombatMetrics",
                ["embeddedStr"] = "NO",
                ["rootPath"] = "user:/AddOns/CombatMetrics/",
                ["isLibrary"] = false,
            },
            [18] = 
            {
                ["isOutOfDate"] = true,
                ["name"] = "TamrielKR",
                ["embeddedStr"] = "NO",
                ["rootPath"] = "user:/AddOns/TamrielKR/",
                ["isLibrary"] = false,
            },
            [19] = 
            {
                ["isOutOfDate"] = true,
                ["name"] = "CircularMinimap",
                ["embeddedStr"] = "NO",
                ["rootPath"] = "user:/AddOns/CircularMinimap/",
                ["isLibrary"] = false,
            },
            [20] = 
            {
                ["isOutOfDate"] = false,
                ["name"] = "LibDebugLogger",
                ["embeddedStr"] = "NO",
                ["rootPath"] = "user:/AddOns/LibDebugLogger/",
                ["isLibrary"] = true,
            },
            [21] = 
            {
                ["isOutOfDate"] = true,
                ["name"] = "USPF",
                ["embeddedStr"] = "NO",
                ["rootPath"] = "user:/AddOns/USPF/",
                ["isLibrary"] = false,
            },
            [22] = 
            {
                ["isOutOfDate"] = false,
                ["name"] = "BanditsUserInterface",
                ["embeddedStr"] = "NO",
                ["rootPath"] = "user:/AddOns/BanditsUserInterface/",
                ["isLibrary"] = false,
            },
            [23] = 
            {
                ["isOutOfDate"] = false,
                ["name"] = "DolgubonsLazyWritCreator",
                ["embeddedStr"] = "NO",
                ["rootPath"] = "user:/AddOns/DolgubonsLazyWritCreator/",
                ["isLibrary"] = false,
            },
            [24] = 
            {
                ["isOutOfDate"] = true,
                ["name"] = "Destinations",
                ["embeddedStr"] = "NO",
                ["rootPath"] = "user:/AddOns/Destinations/",
                ["isLibrary"] = false,
            },
            [25] = 
            {
                ["isOutOfDate"] = true,
                ["name"] = "LibTableFunctions-1.0",
                ["embeddedStr"] = "NO",
                ["rootPath"] = "user:/AddOns/LibTableFunctions-1.0/",
                ["isLibrary"] = true,
            },
            [26] = 
            {
                ["isOutOfDate"] = true,
                ["name"] = "LibCustomMenu",
                ["embeddedStr"] = "NO",
                ["rootPath"] = "user:/AddOns/LibCustomMenu/",
                ["isLibrary"] = true,
            },
            [27] = 
            {
                ["isOutOfDate"] = true,
                ["name"] = "HarvestMap",
                ["embeddedStr"] = "YES",
                ["rootPath"] = "user:/AddOns/HarvestMap/Modules/HarvestMap/",
                ["isLibrary"] = false,
            },
            [28] = 
            {
                ["isOutOfDate"] = false,
                ["name"] = "LibAddonMenuSoundSlider",
                ["embeddedStr"] = "NO",
                ["rootPath"] = "user:/AddOns/LibAddonMenuSoundSlider/",
                ["isLibrary"] = true,
            },
            [29] = 
            {
                ["isOutOfDate"] = false,
                ["name"] = "LibZone",
                ["embeddedStr"] = "NO",
                ["rootPath"] = "user:/AddOns/LibZone/",
                ["isLibrary"] = true,
            },
            [30] = 
            {
                ["isOutOfDate"] = true,
                ["name"] = "HarvestMapAD",
                ["embeddedStr"] = "YES",
                ["rootPath"] = "user:/AddOns/HarvestMapData/Modules/HarvestMapAD/",
                ["isLibrary"] = false,
            },
            [31] = 
            {
                ["isOutOfDate"] = true,
                ["name"] = "CustomCompassPins",
                ["embeddedStr"] = "NO",
                ["rootPath"] = "user:/AddOns/CustomCompassPins/",
                ["isLibrary"] = true,
            },
            [32] = 
            {
                ["isOutOfDate"] = true,
                ["name"] = "HarvestMapDC",
                ["embeddedStr"] = "YES",
                ["rootPath"] = "user:/AddOns/HarvestMapData/Modules/HarvestMapDC/",
                ["isLibrary"] = false,
            },
            [33] = 
            {
                ["isOutOfDate"] = false,
                ["name"] = "ActionDurationReminder",
                ["embeddedStr"] = "NO",
                ["rootPath"] = "user:/AddOns/ActionDurationReminder/",
                ["isLibrary"] = false,
            },
            [34] = 
            {
                ["isOutOfDate"] = true,
                ["name"] = "HarvestMapEP",
                ["embeddedStr"] = "YES",
                ["rootPath"] = "user:/AddOns/HarvestMapData/Modules/HarvestMapEP/",
                ["isLibrary"] = false,
            },
            [35] = 
            {
                ["isOutOfDate"] = true,
                ["name"] = "VotansAdaptiveSettings",
                ["embeddedStr"] = "NO",
                ["rootPath"] = "user:/AddOns/VotansAdaptiveSettings/",
                ["isLibrary"] = false,
            },
            [36] = 
            {
                ["isOutOfDate"] = true,
                ["name"] = "HarvestMapNF",
                ["embeddedStr"] = "YES",
                ["rootPath"] = "user:/AddOns/HarvestMapData/Modules/HarvestMapNF/",
                ["isLibrary"] = false,
            },
            [37] = 
            {
                ["isOutOfDate"] = true,
                ["name"] = "LibMapData",
                ["embeddedStr"] = "NO",
                ["rootPath"] = "user:/AddOns/LibMapData/",
                ["isLibrary"] = true,
            },
            [38] = 
            {
                ["isOutOfDate"] = false,
                ["name"] = "CrutchAlerts",
                ["embeddedStr"] = "NO",
                ["rootPath"] = "user:/AddOns/CrutchAlerts/",
                ["isLibrary"] = false,
            },
            [39] = 
            {
                ["isOutOfDate"] = false,
                ["name"] = "LibCombat",
                ["embeddedStr"] = "NO",
                ["rootPath"] = "user:/AddOns/LibCombat/",
                ["isLibrary"] = true,
            },
            [40] = 
            {
                ["isOutOfDate"] = true,
                ["name"] = "NodeDetection",
                ["embeddedStr"] = "YES",
                ["rootPath"] = "user:/AddOns/HarvestMap/Libs/NodeDetection/",
                ["isLibrary"] = true,
            },
            [41] = 
            {
                ["isOutOfDate"] = true,
                ["name"] = "displayleads",
                ["embeddedStr"] = "NO",
                ["rootPath"] = "user:/AddOns/displayleads/",
                ["isLibrary"] = false,
            },
            [42] = 
            {
                ["isOutOfDate"] = true,
                ["name"] = "LibMarify",
                ["embeddedStr"] = "NO",
                ["rootPath"] = "user:/AddOns/LibMarify/",
                ["isLibrary"] = true,
            },
            [43] = 
            {
                ["isOutOfDate"] = true,
                ["name"] = "LibUespQuestData",
                ["embeddedStr"] = "NO",
                ["rootPath"] = "user:/AddOns/LibUespQuestData/",
                ["isLibrary"] = true,
            },
            [44] = 
            {
                ["isOutOfDate"] = true,
                ["name"] = "LibDataEncode",
                ["embeddedStr"] = "NO",
                ["rootPath"] = "user:/AddOns/LibDataEncode/",
                ["isLibrary"] = true,
            },
            [45] = 
            {
                ["isOutOfDate"] = false,
                ["name"] = "ZZZ_AddOnInspector",
                ["embeddedStr"] = "NO",
                ["rootPath"] = "user:/AddOns/ZZZ_AddOnInspector/",
                ["isLibrary"] = false,
            },
            [46] = 
            {
                ["isOutOfDate"] = true,
                ["name"] = "LibMainMenu-2.0",
                ["embeddedStr"] = "NO",
                ["rootPath"] = "user:/AddOns/LibMainMenu-2.0/",
                ["isLibrary"] = true,
            },
            [47] = 
            {
                ["isOutOfDate"] = true,
                ["name"] = "LibSavedVars",
                ["embeddedStr"] = "NO",
                ["rootPath"] = "user:/AddOns/LibSavedVars/",
                ["isLibrary"] = true,
            },
            [48] = 
            {
                ["isOutOfDate"] = false,
                ["name"] = "CombatAlerts",
                ["embeddedStr"] = "NO",
                ["rootPath"] = "user:/AddOns/CombatAlerts/",
                ["isLibrary"] = false,
            },
            [49] = 
            {
                ["isOutOfDate"] = true,
                ["name"] = "LibMapPing",
                ["embeddedStr"] = "NO",
                ["rootPath"] = "user:/AddOns/LibMapPing/",
                ["isLibrary"] = true,
            },
            [50] = 
            {
                ["isOutOfDate"] = true,
                ["name"] = "LibQuestData",
                ["embeddedStr"] = "NO",
                ["rootPath"] = "user:/AddOns/LibQuestData/",
                ["isLibrary"] = true,
            },
            [51] = 
            {
                ["isOutOfDate"] = true,
                ["name"] = "VotansMiniMap",
                ["embeddedStr"] = "NO",
                ["rootPath"] = "user:/AddOns/VotansMiniMap/",
                ["isLibrary"] = false,
            },
            [52] = 
            {
                ["isOutOfDate"] = false,
                ["name"] = "DolgubonsLazyWritCreator-KR-Mini",
                ["embeddedStr"] = "NO",
                ["rootPath"] = "user:/AddOns/DolgubonsLazyWritCreator-KR-Minion/",
                ["isLibrary"] = false,
            },
            [53] = 
            {
                ["isOutOfDate"] = true,
                ["name"] = "CombatMetricsFightData",
                ["embeddedStr"] = "YES",
                ["rootPath"] = "user:/AddOns/CombatMetrics/CombatMetricsFightData/",
                ["isLibrary"] = true,
            },
            [54] = 
            {
                ["isOutOfDate"] = false,
                ["name"] = "LibMediaProvider",
                ["embeddedStr"] = "NO",
                ["rootPath"] = "user:/AddOns/LibMediaProvider/",
                ["isLibrary"] = true,
            },
            [55] = 
            {
                ["isOutOfDate"] = false,
                ["name"] = "TamrielTradeCentre-KR-Minion",
                ["embeddedStr"] = "NO",
                ["rootPath"] = "user:/AddOns/TamrielTradeCentre-KR-Minion/",
                ["isLibrary"] = false,
            },
            [56] = 
            {
                ["isOutOfDate"] = true,
                ["name"] = "ToggleErrorUI",
                ["embeddedStr"] = "NO",
                ["rootPath"] = "user:/AddOns/ToggleErrorUI/",
                ["isLibrary"] = false,
            },
            [57] = 
            {
                ["isOutOfDate"] = true,
                ["name"] = "LibNotification",
                ["embeddedStr"] = "NO",
                ["rootPath"] = "user:/AddOns/LibNotification/",
                ["isLibrary"] = true,
            },
            [58] = 
            {
                ["isOutOfDate"] = false,
                ["name"] = "pChat",
                ["embeddedStr"] = "NO",
                ["rootPath"] = "user:/AddOns/pChat/",
                ["isLibrary"] = false,
            },
            [59] = 
            {
                ["isOutOfDate"] = false,
                ["name"] = "LibLazyCrafting",
                ["embeddedStr"] = "NO",
                ["rootPath"] = "user:/AddOns/LibLazyCrafting/",
                ["isLibrary"] = true,
            },
            [60] = 
            {
                ["isOutOfDate"] = true,
                ["name"] = "TheQuestingGuide",
                ["embeddedStr"] = "NO",
                ["rootPath"] = "user:/AddOns/TheQuestingGuide/",
                ["isLibrary"] = false,
            },
            [61] = 
            {
                ["isOutOfDate"] = false,
                ["name"] = "LibAsync",
                ["embeddedStr"] = "NO",
                ["rootPath"] = "user:/AddOns/LibAsync/",
                ["isLibrary"] = true,
            },
            [62] = 
            {
                ["isOutOfDate"] = true,
                ["name"] = "LibDialog",
                ["embeddedStr"] = "NO",
                ["rootPath"] = "user:/AddOns/LibDialog/",
                ["isLibrary"] = true,
            },
            [63] = 
            {
                ["isOutOfDate"] = false,
                ["name"] = "CrutchAlerts-KR-Minion",
                ["embeddedStr"] = "NO",
                ["rootPath"] = "user:/AddOns/CrutchAlerts-KR-Minion/",
                ["isLibrary"] = false,
            },
            [64] = 
            {
                ["isOutOfDate"] = true,
                ["name"] = "LibAddonMenu-2.0",
                ["embeddedStr"] = "NO",
                ["rootPath"] = "user:/AddOns/LibAddonMenu-2.0/",
                ["isLibrary"] = true,
            },
            [65] = 
            {
                ["isOutOfDate"] = false,
                ["name"] = "LibCombatAlerts",
                ["embeddedStr"] = "YES",
                ["rootPath"] = "user:/AddOns/CombatAlerts/LibCombatAlerts/",
                ["isLibrary"] = true,
            },
            [66] = 
            {
                ["isOutOfDate"] = false,
                ["name"] = "LostTreasure",
                ["embeddedStr"] = "NO",
                ["rootPath"] = "user:/AddOns/LostTreasure/",
                ["isLibrary"] = false,
            },
        },
    }
```