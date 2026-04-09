# Phase 0 — SV data analysis & H1 reassessment

> **Date**: 2026-04-08
>
> **Status**: Primary SV data analysis completed. H1 strategy needs to be revisited.
>
> **Data source**: `SavedVariables/ZZZ_AddOnInspector.lua` (first PoC run, 3682 lines)

---

# 1. eventLog analysis — 222 actual (44 chat indications are incorrect)

## Bug Found

Displayed as `Intercepted RegisterForEvent: 44` in chat, but **222** were recorded in the SV file.

**Cause**: `h2_capturedCount` was recorded as `#ACI.eventLog` at the time of `EVENT_PLAYER_ACTIVATED`, but RegisterForEvent calls continue to come in even after PLAYER_ACTIVATED. SV flush is done at /reloadui or at logout time, so 178 additional files are loaded in the meantime.

**Implications**:
- The snapshot at PLAYER_ACTIVATED is incomplete. The final report must be generated just before SV flush or at the time of calling the slash command.
- Alternatively, it can be flushed at any desired time by calling `RequestAddOnSavedVariablesPrioritySave()`.

## Registration distribution by namespace

|Add-ons (namespace group)|number of registrations|namespace pattern|note|
|------------------------|--------|---------------|------|
| **LibCombat** | **172** |`LibCombat1`, `LibCombat3`, ... `LibCombat353` (odd)|Separate namespace required because of AddFilterForEvent|
| **Azurah** | **16** | `AzurahAttributes`, `AzurahTarget`, `AzurahBossbar`, `AzurahUltimate`, `AzurahExperience`, `AzurahCompass` |namespace for each module|
| **CrutchAlerts** | **11** | `CrutchAlertsEffectAlert{ID}`, `CrutchAlertsOthersBegin{ID}`, `CrutchAlertsOthersFaded{ID}`, `CrutchAlertsOthersGained{ID}`, `CrutchAlertsOthersGainedDuration{ID}` |Namespace for each skill ID|
| **CombatAlerts** | **5** | `CombatAlerts` | |
| **LCA_RoleMonitor** | **2** | `LCA_RoleMonitor` |Inside LibCombatAlerts|
| **CA_ReformGroup** | **2** | `CA_ReformGroup` |Inside CombatAlerts|
| **FancyActionBar+** | **4** | `FancyActionBar+`, `FancyActionBar+UltValue`, `FancyActionBar_ScreenResize` | |
| **LostTreasure** | **2** | `Lost Treasure`, `LostTreasure_TemporaryFix` | |
| **BUI_Event** | **1** | `BUI_Event` | BanditsUserInterface |
| **LibCodesCommonCode29_5** | **1** | `LibCodesCommonCode29_5` | |
| **ZZZ_AddOnInspector** | **1** | `ZZZ_AddOnInspector` |ACI Himself (EVENT_PLAYER_ACTIVATED)|

## Key Insights

### 1. LibCombat registers event monster

172 — **77%** of 222 total. The reason for registering each namespace individually with an odd number is due to the `AddFilterForEvent` limitation of the ESO API:
- The namespace of `RegisterForEvent` must be unique
- If you want to apply a different filter to the same event, you must register it as a different namespace.
- LibCombat granularly filters various combat log events, so namespace explosions are possible.

**Phase 2 Design Implications**:
- When determining "heavy add-on", grouping is required based on **unique namespace prefix** rather than simple registration count.
- When normalized to `LibCombat{N}` → `LibCombat`, 172 are correctly counted as registrations of 1 addon.
- Threshold: If there are 50 or more namespace prefixes, a "heavy" label seems appropriate.

### 2. namespace ≠ add-on name — CrossCheck logic needs to be modified

Most add-ons use a namespace **different** from the add-on folder name:
- `Azurah` add-on → `AzurahTarget`, `AzurahBossbar`, ...
- `BanditsUserInterface` Add-on → `BUI_Event`
- `LibCombat` add-on → `LibCombat1`, `LibCombat3`, ...
- `CombatAlerts` → `CA_ReformGroup`, `LCA_RoleMonitor`

**→ “63 missed” in CrossCheck is mostly false positive.** Matching failed because the namespace string does not match the add-on name.

**Correction direction**: Namespace → Apply fuzzy matching or prefix matching to add-on mapping. Alternatively, `lastLoadedAddon` based tracking (Phase 0+ code) is more accurate.

### 3. Event code distribution

| eventCode |number of registrations|estimated event|
|-----------|--------|------------|
| 131109 | **~120** |EVENT_COMBAT_EVENT (most)|
| 131158 | ~20 | EVENT_EFFECT_CHANGED |
| 131129 | ~8 | EVENT_POWER_UPDATE |
| 589824 | 6 | EVENT_PLAYER_ACTIVATED |
| 131137 | 5 | EVENT_UNIT_DEATH_STATE_CHANGED |
| 131459 | 4 |EVENT_PLAYER_ACTIVATED? or GROUP|
|etc|1 to 3 each|various|

**EVENT_COMBAT_EVENT (131109) is the overwhelming hot path.** LibCombat applies dozens of filters to this event. First candidate for hot path warning in Phase 2.

---

# 2. loadOrder analysis — H1 is a real FAIL

## Full loading order

```
[ZOS Native — 9]
 #1  ZO_FontStrings         ts=2474108
 #2  ZO_FontDefs            ts=2474108
 #3  ZO_AppAndInGame        ts=2474108
 #4  ZO_IngameLocalization  ts=2474109
 #5  ZO_Libraries           ts=2474109
 #6  ZO_Common              ts=2474109
 #7  ZO_PregameAndIngame    ts=2474109
 #8  ZO_PublicAllIngames    ts=2474109
#9 ZO_Ingame ts=2474278 ← ZOS load only 170ms

[User Add-ons — 66]
#10 LibHarvensAddonSettings ts=2474286 ← First User Addon
 #11 VotansAdvancedSettings   ts=2474287
 #12 LibDebugLogger           ts=2474287
 #13 LibAddonMenu-2.0         ts=2474287
 #14 LibCustomMenu            ts=2474287
 #15 TamrielTradeCentre       ts=2474608  ← DependsOn: LAM, LibCustomMenu
 #16 LibMediaProvider          ts=2474608
 #17 LibMediaProvider-1.0      ts=2474608
 #18 Azurah                    ts=2474619
 #19 BanditsUserInterface      ts=2474938
 #20 FancyActionBar+           ts=2474949
 ...
#63 ZZZ_AddOnInspector ts=2478919 ← User Add-on 54/66th
 #64 LibSavedVars              ts=2478923
 #65 LibCombatAlerts           ts=2478923
 #66 CombatAlerts              ts=2478923
 #67 LibQuestData              ts=2478925
 #68 DolgubonsLazyWritCreator-KR-Mini  ts=2478949
 #69 TamrielTradeCentre-KR-Minion     ts=2478949
 #70 ToggleErrorUI             ts=2478949
 #71 LibNotification           ts=2478949
 #72 TheQuestingGuide          ts=2478958
 #73 LibDialog                 ts=2478962
 #74 CrutchAlerts-KR-Minion    ts=2478962
 #75 LostTreasure              ts=2478962
```

## H1 Conclusion

**ZZZ_ Reverse alphabet trick actually fails.** Loaded 54th out of 66 user add-ons.

### Cause of failure

Reorganized ESO's loading order rules:
1. **DependsOn/OptionalDependsOn rules everything.** Most addons depend on Lib*, so the dependency tree completely overrides alphabetical order.
2. **Reverse alphabetical order applies “only between add-ons that do not have dependencies.”** Add-ons that have dependencies have priority in the order of dependency resolution.
3. There is only ACI `OptionalDependsOn: LibDebugLogger`, which means that if LibDebugLogger exists, it is loaded after it. However, other add-ons have deeper dependency chains, so they are resolved first.

### How this affects ACI

**PreHook installation time is late** = RegisterForEvent call during init time (EVENT_ADD_ON_LOADED) misses add-ons #10~#62.

**But it is not fatal.** Reason:
1. RegisterForEvent at init time mostly registers itself as EVENT_ADD_ON_LOADED (1-2). Real mass registration occurs after PLAYER_ACTIVATED (172 LibCombats as evidence).
2. **Most of the current 222 are caught after ACI is loaded.** Once installed, PreHook catches all calls after that.
3. The core functions of Phase 1 (add-on list, metadata, dependency tree) are based on the `GetAddOnManager` API, so they are independent of the loading order.

### H1 Strategy Amendment

**Original strategy**: Load ZZZ_ folder name first → Intercept all RegisterForEvents

**Modified Strategy**: Abandon loading order. instead:
1. **init step tracking**: The EVENT_ADD_ON_LOADED event itself can be registered at the very beginning (when the file is loaded = immediately after manifest parsing). With this, you can measure the loading order and init time of all add-ons.
2. **runtime phase tracking**: PreHook works after ACI is loaded. Missed registrations during init are honestly marked as "registered before ACI load, untrackable".
3. **Data that is really important to register after PLAYER_ACTIVATED**: Most events with a large performance impact (combat, effect, etc.) are registered at this point. Of the 222, only a small number are registered at init time.

---

# 3. Timeline analysis

Total loading time: `ts 2474108` to `ts 2480025` = **approximately 5.9 seconds**

|panel|Time (ms)|note|
|------|---------|------|
|ZOS Native (#1~#9)| ~170 |speed|
|User add-on init (#10~#75)| ~4640 |slow|
|Register after PLAYER_ACTIVATED| ~1100 |Includes LibCombat bulk registration|

TamrielTradeCentre (#15, ts=2474608): init only ~320ms — first candidate for a heavy addon.
LibMapData (#28, ts=2475763): ~800ms difference from previous addon (#27) — slower init.
CombatMetrics (#43, ts=2477970): ~1200ms compared to previous (#42) — very heavy init.

**Phase 3's "Estimate init time for each addon" is already possible with this data.** The difference between successive ts of loadOrder is the init time for each addon.

---

# 4. Next action

- [ ] Obtain Phase 0+ SV data (requires /reloadui in game — SV is currently the first PoC)
- [ ] eventLog count bug fix: final count before slash command or SV flush rather than at PLAYER_ACTIVATED
- [ ] Modify CrossCheck logic: namespace → prefix matching to addon mapping or tracking based on lastLoadedAddon
- [ ] H1 strategy document update: ZZZ_ Give up tricks, reflect new strategy
- [ ] Consider heavy registrant patterns such as LibCombat in Phase 1 UI design
- [ ] Phase 3 init time measurement confirmed to be implemented using loadOrder ts difference
