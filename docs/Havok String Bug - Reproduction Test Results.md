# Havok String Bug — Reproduction Test Results

> Execute `/aci debug`, extract from SV `havokTest` block
>
> Test targets: index 1 (top-level), 8 (embedded), 45 (ACI)

---

## Summary of results

### Index 1: VotansAdvancedSettings (top-level, 3 slashes)

| # |test|result|
|---|--------|------|
| T1 | raw:find('/AddOns/') | **6** |
| T2 | tostring():find | 6 |
| T3 | concat(''):find | 6 |
| T4 | table.p:find | 6 |
| T5 | raw:match('/AddOns/(.+)') | **VotansAdvancedSettings/** |
| T6 | table:match | VotansAdvancedSettings/ |
| T7 | raw:gsub('/')cnt | **0** ❓ |
| T8 | tbl:gsub('/')cnt | **3** |
| T9 | name:find('a') | 4 |
| T10 | #raw / #tbl | 36 / 36 |

### Index 8: HarvestMapDLC (embedded, 5 slashes)

| # |test|result|
|---|--------|------|
| T1 | raw:find('/AddOns/') | **6** |
| T2 | tostring():find | 6 |
| T3 | concat(''):find | 6 |
| T4 | table.p:find | 6 |
| T5 | raw:match('/AddOns/(.+)') | **HarvestMapData/Modules/HarvestMapDLC/** |
| T6 | table:match | HarvestMapData/Modules/HarvestMapDLC/ |
| T7 | raw:gsub('/')cnt | **0** ❓ |
| T8 | tbl:gsub('/')cnt | **5** |
| T9 | name:find('a') | 2 |
| T10 | #raw / #tbl | 50 / 50 |

### Index 45: ZZZ_AddOnInspector (top-level, 3 slashes)

| # |test|result|
|---|--------|------|
| T1 | raw:find('/AddOns/') | **6** |
| T2 | tostring():find | 6 |
| T3 | concat(''):find | 6 |
| T4 | table.p:find | 6 |
| T5 | raw:match('/AddOns/(.+)') | **ZZZ_AddOnInspector/** |
| T6 | table:match | ZZZ_AddOnInspector/ |
| T7 | raw:gsub('/')cnt | **0** ❓ |
| T8 | tbl:gsub('/')cnt | **3** |
| T9 | name:find('a') |nil (normal, no 'a')|
| T10 | #raw / #tbl | 32 / 32 |

---

## analyze

### T7 — Test code operator precedence bug

T7 test code:
```lua
local _, rawGsub = rootPath and rootPath:gsub("/", "") or "", 0
```

Lua `and`/`or` operator precedence:
1. `rootPath and rootPath:gsub("/", "")` → Only the **first return value** of gsub survives (modified string)
2. `... or ""` → The first value is truthy, so it is as is.
3. `, 0` → **Literal 0 is always assigned to rawGsub**

That is, T7 is always 0. **It is not a Havok bug, but the `and/or` priority of the test code ate the second return value of gsub.**

T8 is normal:
```lua
local _, tblGsub = t.p:gsub("/", "")  --Direct call, no and/or → count returns normally
```

### T1-T6, T9-T10 — all normal. No difference between raw and table.

- `find()`: Normal in raw ✅
- `match()`: Normal in raw ✅
- `type()`: "string" ✅
- `#` (length): Same as raw and table ✅
- `tostring()`, `concat("")`: No difference ✅

---

## conclusion

### There was no "Havok String Bug"

In the raw API return string, `find`, `match`, `sub`, and `gsub` all operate normally.
T7's `cnt = 0` is a `and/or` priority bug in the test code.

### So why did CollectMetadata fail 4 times?

Conclusive facts:
1. All four internal CollectMetadata implementations embeddedCount = 0
2. If I recalculate a.rootPath in Analysis, it's normal (embeddedCount = 10)
3. In this test, all raw string operations are normal.

Unresolved — Possible cause candidates:

| # |hypothesis|possibility|
|---|------|--------|
| 1 |PLAYER_ACTIVATED viewpoint environment differences|Among them — CollectMetadata is not a callback, debug is a slash command.|
| 2 |gsub count issue on first attempt|Low — Since it is a direct call, it has nothing to do with and/or priority.|
| 3 |Deployment/Cache Timing|Low — /reloadui causes a full Lua VM restart.|
| 4 |isEmbedded code not reached due to CollectMetadata internal error|Medium — However, all 66 entries were created normally.|
| 5 |**Cause unknown — but resolved**| — |

### Why your current architecture is correct (regardless of the cause)

The Analysis step recalculation approach is not a "Havok bug bypass" but a **better design**:
- Separation of concerns: Inventory = collection, Analysis = analysis.
- Cleaner as CollectMetadata has no analysis logic
- Recalculation can also be applied to previous session data loaded from SV

Whatever the cause, the current structure is better.

---

## Follow-up experiments (Phase 2 candidates)

To determine the root cause:

```lua
--Run the same test inside the PLAYER_ACTIVATED callback
EVENT_MANAGER:RegisterForEvent("ACI_HavokTest", EVENT_PLAYER_ACTIVATED, function()
    local manager = GetAddOnManager()
    local rootPath = manager:GetAddOnRootDirectoryPath(8)
    local _, cnt = rootPath:gsub("/", "")
    local found = rootPath:find("/AddOns/", 1, true)
    d("[ACI] PA gsub count=" .. tostring(cnt) .. " find=" .. tostring(found))
end)
```

---

## Raw test output

```
--------------------------------------------
[ACI] Havok String Bug Test
--------------------------------------------
[ACI] --- index 1: VotansAdvancedSettings ---
[ACI] rootPath raw = user:/AddOns/VotansAdvancedSettings/
[ACI] type(rootPath) = string
[ACI] type(name) = string
[ACI] T1 raw:find         = 6
[ACI] T2 tostring:find    = 6
[ACI] T3 concat(''):find  = 6
[ACI] T4 table.p:find     = 6
[ACI] T5 raw:match        = VotansAdvancedSettings/
[ACI] T6 table:match      = VotansAdvancedSettings/
[ACI] T7 raw:gsub('/')cnt = 0
[ACI] T8 tbl:gsub('/')cnt = 3
[ACI] T9 name:find('a')   = 4
[ACI] T10 #raw=36 #tbl=36
[ACI]
[ACI] --- index 8: HarvestMapDLC ---
[ACI] rootPath raw = user:/AddOns/HarvestMapData/Modules/HarvestMapDLC/
[ACI] type(rootPath) = string
[ACI] type(name) = string
[ACI] T1 raw:find         = 6
[ACI] T2 tostring:find    = 6
[ACI] T3 concat(''):find  = 6
[ACI] T4 table.p:find     = 6
[ACI] T5 raw:match        = HarvestMapData/Modules/HarvestMapDLC/
[ACI] T6 table:match      = HarvestMapData/Modules/HarvestMapDLC/
[ACI] T7 raw:gsub('/')cnt = 0
[ACI] T8 tbl:gsub('/')cnt = 5
[ACI] T9 name:find('a')   = 2
[ACI] T10 #raw=50 #tbl=50
[ACI]
[ACI] --- index 45: ZZZ_AddOnInspector ---
[ACI] rootPath raw = user:/AddOns/ZZZ_AddOnInspector/
[ACI] type(rootPath) = string
[ACI] type(name) = string
[ACI] T1 raw:find         = 6
[ACI] T2 tostring:find    = 6
[ACI] T3 concat(''):find  = 6
[ACI] T4 table.p:find     = 6
[ACI] T5 raw:match        = ZZZ_AddOnInspector/
[ACI] T6 table:match      = ZZZ_AddOnInspector/
[ACI] T7 raw:gsub('/')cnt = 0
[ACI] T8 tbl:gsub('/')cnt = 3
[ACI] T9 name:find('a')   = nil
[ACI] T10 #raw=32 #tbl=32
[ACI]
--------------------------------------------
[ACI] Stored in SV (havokTest). You can check the file after /reloadui.
```
