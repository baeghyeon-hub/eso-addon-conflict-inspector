# Phase 2 Step 0 — `pairs(_G)` Silent Crash Troubleshooting

> **Date**: 2026-04-09
>
> **Status**: Cause identified, fix implemented, and in-game verification complete
>
> **Impact scope**: This fully invalidates the Phase 1 "Havok String Bug" hypothesis and also explains the four consecutive embedded-detection failures.

---

# Symptoms

## Direct Symptoms (Phase 2 Step 0)

The `loadOrderIndex` field added to the `CollectMetadata()` function of `ACI_Inventory.lua` does not appear at all in SV.

- It does not appear even after removing the `d()` call.
- Even simple string fields like `_v = "d4"` do not appear.
- Numeric fields like `_diagMapSize` do not appear.
- The same result persisted across eight deploy/test cycles

## Past Symptoms (Phase 1 Step 3.5)

All four variations of the detection logic embedded within `CollectMetadata()` return `embeddedCount = 0`.
If the same logic is executed later through the `/aci dump` slash command, it behaves normally (`EMB = 10`).

## Secondary Symptoms Observed

- `[ACI] v0.2.0-step0 loaded` message does not appear when connecting to the game
- Initial report (`ACI.PrintReport()`) not automatically printed
- `/aci` slash command works normally
- `loadOrder`, `eventLog`, `svRegistrations` are recorded normally.

---

# Misdiagnosis history

## Misdiagnosis 1: d() function error (Phase 2 Step 0 initial)

**Hypothesis**: The call to `d("[ACI] CollectMetadata START")` inside `CollectMetadata` caused an error at PLAYER_ACTIVATED and the function was stopped.

**Action**: Remove all d() calls, remove debug block.

**Result**: loadOrderIndex still does not appear. **Dismissed.**

**Lesson**: d() works normally when PLAYER_ACTIVATED (other add-ons also use d() at this point). It's just that execution didn't reach d() in the first place.

## Misdiagnosis 2: Error in the loadOrderIndex line itself.

**Hypothesis**: `ACI.loadOrderMap[name]` lookup causes an error (nil table, key mismatch, etc.).

**Action**: Comment out the loadOrderIndex line, leaving only the `_v = "d4"` marker.

**Result**: `_v` does not appear. Unrelated to loadOrderIndex. **Dismissed.**

## Misdiagnosis 3: Failed to load ACI_Inventory.lua file

**Hypothesis**: ACI_Inventory.lua is not parsed by ESO due to file encoding, BOM, CRLF, etc.

**Action**: Check file encoding (UTF-8 no BOM), distribution file diff, xxd binary.

**Result**: Source and distribution files are completely identical. The other working file (ACI_Core.lua) also has the same encoding. **Dismissed.**

## Misdiagnosis 4: Havok String Bug (Phase 1 Step 3.5)

**Hypothesis**: ESO's API returns a "Havok protected string", causing Lua's string methods (find, match, gsub) to not work.

**Action**: Implement a bypass to recalculate with the values ​​stored in the table in the Analysis stage.

**Results**: The bypass worked, but in subsequent reproduction tests (T1 to T10), all string methods of raw API strings worked normally. The original "failure" cannot be reproduced.

**Real Cause**: CollectMetadata was never run in the first place. Not “failure” but “non-execution”. **Completely dismissed.**

---

# Cause tracing process

## Step 1: Wrapping pcall (trying to catch errors)

```lua
--Inside ACI_Core.lua PLAYER_ACTIVATED
local ok, result = pcall(ACI.CollectMetadata)
ACI_SavedVars._collectOk = ok
if ok then
    ACI_SavedVars.metadata = result
else
    ACI_SavedVars._collectErr = tostring(result)
end
```

**Result**: `_collectOk` itself never appears in SV. That means execution never even reaches the `pcall` line.

## Step 2: Callback entry marker

```lua
--OnACILoaded first line
ACI_SavedVars._onLoaded = "v5"

--PLAYER_ACTIVATED callback first line
ACI_SavedVars._paFired = "v5"
```

**Result**:
- `_onLoaded = "v5"` ✓ — Check OnACILoaded execution
- `_paFired = "v5"` ✓ — Confirm PLAYER_ACTIVATED callback entry
- `_collectOk` ✗ — execution stops partway through

**Meaning**: The callback starts but stops midway with a silent error.

## Step 3: _step binary search (deterministic)

```lua
ACI_SavedVars._paFired = "v5"
ACI_SavedVars._step = 1
EVENT_MANAGER:UnregisterForEvent(ACI.name, EVENT_PLAYER_ACTIVATED)
ACI_SavedVars._step = 2
EVENT_MANAGER:UnregisterForEvent(ACI.name .. "_LoadOrder", EVENT_ADD_ON_LOADED)
ACI_SavedVars._step = 3
ACI.eventNames = ACI.BuildEventNameMap()  --← Error here
ACI_SavedVars._step = 4                  --← Not reached
local ok, result = pcall(ACI.CollectMetadata)
ACI_SavedVars._step = 5
ACI_SavedVars._collectOk = ok
```

**Result**: `_step = 3`

**Meaning**: An error occurred in the `ACI.BuildEventNameMap()` call. After this, all code is not executed.

---

# Root Cause

## Faulting code

```lua
function ACI.BuildEventNameMap()
    local map = {}
    for k, v in pairs(_G) do  --← Runtime error on this line
        if type(v) == "number" and type(k) == "string" and k:sub(1, 6) == "EVENT_" then
            map[v] = k
        end
    end
    return map
end
```

## Cause analysis

`pairs(_G)` traverses ESO's entire global table. In ESO's modified Lua 5.1 VM, some global variables have **protected access control**, which causes a runtime error when accessing the corresponding key/value during `pairs()` traversal.

## ESO's Silent Error Mechanism

ESO executes event callbacks (EVENT_ADD_ON_LOADED, EVENT_PLAYER_ACTIVATED, etc.) internally as protected calls (similar to pcall). If an error occurs within the callback:

1. ESO catches the error
2. Errors may briefly appear in the UI error frame (not visible without the ToggleErrorUI add-on)
3. **Any code after the line where the error occurred is not executed**
4. Other event handlers and subsequent events execute normally.

Because of this mechanism:
- `BuildEventNameMap()` error → `CollectMetadata()` not executed → `PrintReport()` not executed
- However, the `/aci` slash command (separate callback path) works normally.
- Live reference data such as `loadOrder`, `eventLog` are already set in OnACILoaded → Normal

## Impact scope

### Unexecuted code in PLAYER_ACTIVATED callback

| Code | Purpose | Result |
|------|------|------|
| `ACI.BuildEventNameMap()` | `eventCode -> name` mapping | **Errored out** |
| `ACI.CollectMetadata()` | Metadata collection | **Not executed** |
| `ACI.PrintReport()` | Initial report output | **Not executed** |
| `d("[ACI] /aci lo...")` | Informational message | **Not executed** |

### Code that worked properly (OnACILoaded, slash command)

| Code | Why it still worked |
|------|------|
| `ACI_SavedVars.loadOrder = ACI.loadOrder` | Runs in `OnACILoaded`, before `PLAYER_ACTIVATED` |
| `ACI_SavedVars.eventLog = ACI.eventLog` | Runs in `OnACILoaded`, before `PLAYER_ACTIVATED` |
| `ACI.RegisterCommands()` | Runs in `OnACILoaded`, before `PLAYER_ACTIVATED` |
| Embedded recalculation inside `/aci dump` | Slash-command path is separate from the failing callback |

---

# Fix

## BuildEventNameMap pcall wrapping

```lua
function ACI.BuildEventNameMap()
    local map = {}
    local ok, err = pcall(function()
        for k, v in pairs(_G) do
            if type(v) == "number" and type(k) == "string" and k:sub(1, 6) == "EVENT_" then
                map[v] = k
            end
        end
    end)
    return map
end
```

Even if an error occurs, the partial map collected up to that point is still returned, and the `PLAYER_ACTIVATED` callback is no longer interrupted.

## Verification results

In-game testing after modification:

|item|result|
|------|------|
| `_step` |5 (reach the end)|
| `_collectOk` | true |
| `_v` |"d4" (Check for CollectMetadata new code execution)|
| `_mapSize` |75 (loadOrderMap normal collection)|
|`loadOrderIndex` count|66 (1 of 67 is disabled and nil)|

---

# Phase 1 “Havok String Bug” reinterpretation

## What it looked like at the time

In Phase 1 Step 3.5, we tried four ways to embed the detection logic inside CollectMetadata:

1. Slash count via `gsub` -> `embeddedCount = 0`
2. match + gsub + find → embeddedCount = 0
3. inline match → embeddedCount = 0
4. plain find + sub → embeddedCount = 0

When the same logic was run through `/aci dump`, `EMB = 10` came out correctly.

## Interpretation at the time

“The string method does not work because the string in the API return value is special (Havok protected string)” → Havok String Bug hypothesis.

No reproducibility in subsequent reproducibility tests (T1 to T10) → Conclusion of “undetermined cause.”

## Reinterpretation (confirmed)

**embedded detection logic has never been executed**

Execution flow:
```
Start PLAYER_ACTIVATED callback
→ BuildEventNameMap() ← pairs(_G) callback aborted due to error
→ CollectMetadata() ← Not executed (including embedded logic)
→ PrintReport() ← Not executed
```

`embeddedCount = 0` shown in SV is not a "detection failure" but **residual data from previous session**. Because CollectMetadata was not executed, `ACI_SavedVars.metadata` was not overwritten, and the metadata from the previous session (before adding BuildEventNameMap, or /reloadui session) remained.

Reason why `/aci dump` was successful: The slash command is a separate execution path unrelated to the PLAYER_ACTIVATED callback.

**Conclusion: Havok String Bug did not exist. `pairs(_G)` One runtime error is the cause of all symptoms.**

---

# Lessons

## 1. Distinguish between "failure" and "non-execution"

Code "returning incorrect results" and "not running" are two completely different things. Due to ESO's silent error mechanism, the two may appear identical.

**Task**: Binary search the execution path by placing `ACI_SavedVars._step = N` markers before and after the suspect function.

## 2. Don’t look for errors where they aren’t.

We tested by modifying the inside of CollectMetadata 8 times, but the actual error was in BuildEventNameMap **before the call** to CollectMetadata. You should verify **the entire call path**, not just the failing function itself.

## 3. Traversing ESO `_G` is dangerous

`pairs(_G)` may cause a runtime error due to protected globals in ESO. It must be wrapped with pcall.

## 4. _step marker binary search pattern

The most effective ways to track silent errors in ESO:

```lua
ACI_SavedVars._step = 1
--Suspicious Code A
ACI_SavedVars._step = 2
--Suspicious Code B
ACI_SavedVars._step = 3
--Suspicious Code C
ACI_SavedVars._step = 4
```

If you check the `_step` value in SV, you can see exactly in which line the error occurred.

## 5. Beware of spreading hypotheses

Once the "Havok String Bug" hypothesis took hold, every later analysis was framed around it. The trap was that **a workaround was found from within that hypothesis before the hypothesis itself had been properly verified.**

## 6. ESO's d() is not displayed if called before chat UI preparation.

The `d()` call itself succeeds, but at `EVENT_ADD_ON_LOADED` or `PLAYER_ACTIVATED` the chat UI may not be ready yet, so nothing is shown on screen.

**SOLVED**: Delayed call to `zo_callLater`.

```lua
--When OnACILoaded (EVENT_ADD_ON_LOADED): 500ms delay
zo_callLater(function()
    d("[ACI] v" .. ACI.version .. " loaded.")
end, 500)

--When PLAYER_ACTIVATED: 1000ms delay
zo_callLater(function()
    ACI.PrintReport()
d("You can view the latest statistics with [ACI] /aci.")
end, 1000)
```

**Diagnosis process**: All `_printReportReached`, `_dReached`, and `_dDone` markers are recorded in SV → d() is executed but not displayed in the chat window → Timing problem confirmed.

---

# timeline

|point of view|work|result|
|------|------|------|
| Phase 1 Step 2 |BuildEventNameMap first created|Add _G traversal code|
| Phase 1 Step 3.5 |4 attempts to detect embedded|All “failure” → Havok Bug hypothesis|
| Phase 1 Step 3.5 |dump recalculation bypass|Success → Adoption of Analysis recalculation architecture|
|Phase 1 completed|final report|“Cause undetermined”|
| Phase 2 Step 0 |Add loadOrderIndex|Doesn't appear in SV|
| Phase 2 Step 0 |Remove d(), clean up code|Still not showing up|
| Phase 2 Step 0 |comment out loadOrderIndex|_v marker does not appear|
| Phase 2 Step 0 |Add complex diagnostic codes|_diag does not appear|
| Phase 2 Step 0 |pcall wrapping|_collectOk does not appear|
| Phase 2 Step 0 |**_onLoaded + _paFired marker**|**Both appear → Confirm callback entry**|
| Phase 2 Step 0 |**_step binary search**|**_step=3 → Confirm BuildEventNameMap**|
| Phase 2 Step 0 |**BuildEventNameMap pcall wrapping**|**All resolved. loadOrderIndex 66 normal**|
| Phase 2 Step 0 |Havok Bug Reinterpretation|**It was the same cause. Havok Bug completely dismissed**|
| Phase 2 Step 0 |d() chat unmarked investigation|_printReportReached=true, _dDone=true → Executed but not displayed|
| Phase 2 Step 0 |**Apply zo_callLater**|**Report is output normally when connected. v0.2.0 final completed**|
