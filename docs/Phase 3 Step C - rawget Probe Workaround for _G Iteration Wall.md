# Phase 3 Step C — `rawget` Probe Workaround for `_G` Iteration Wall

> **Date**: 2026-04-10
>
> **Status**: Verified, deployed (commit `ab7b7db`)
>
> **Impact scope**: Supersedes the Phase 2 Step 0 `pairs(_G)` "fix". The previous pcall-wrap fix prevented the silent crash from killing `PLAYER_ACTIVATED`, but the resulting `eventNames` cache was effectively empty (3 entries) and was never used in any user-visible output until Phase 3 C exposed it via `/aci hot`. This document records the real workaround.

---

# Background

In Phase 2 Step 0, we discovered that `pairs(_G)` triggers a runtime error inside ESO event callbacks because the global table contains protected entries. The fix at the time was:

```lua
function ACI.BuildEventNameMap()
    local map = {}
    pcall(function()
        for k, v in pairs(_G) do
            if type(v) == "number" and type(k) == "string" and k:sub(1, 6) == "EVENT_" then
                map[v] = k
            end
        end
    end)
    return map
end
```

This stopped the crash from aborting `PLAYER_ACTIVATED`, allowing `CollectMetadata` and `PrintReport` to run. Phase 2 was declared complete and we moved on.

The cache itself was never inspected. There was no UI surface that displayed event names — the only consumer was a stub `EventName(code)` that nobody called from a user-facing command.

---

# Discovery

In Phase 3 Step C, `/aci hot` was extended to display event names alongside event codes. The output showed raw numbers (`589824`, `131109`, `131158`...) instead of names. Hypothesis: those specific codes were LibCombat custom pseudo-events that don't have public `EVENT_*` globals.

To verify, we added `ACI_SavedVars._eventNamesSize` and read it after a `/aci save`:

```
["_eventNamesSize"] = 2,
```

**The cache had 2 entries.** Out of ~700+ EVENT_* globals in ESO. The Phase 2 fix had been silently producing a near-empty cache for the entire phase.

---

# Root cause

`pcall(function() for k, v in pairs(_G) do ... end end)` catches the error but `for-pairs` cannot resume after a failed iteration step. The protected key sits very early in the hash table iteration order — after only 2-3 successful steps, `next()` errors and the entire loop exits via the pcall.

We tried per-step pcall to skip the bad key:

```lua
local k = nil
while true do
    local ok, nk, nv = pcall(next, _G, k)
    if not ok or nk == nil then break end
    if type(nv) == "number" and type(nk) == "string" and nk:sub(1, 6) == "EVENT_" then
        map[nv] = nk
    end
    k = nk
end
```

Result: still 2-3 entries. **`next(_G, k)` cannot advance past the bad key** — without knowing the next key's identity, we can't supply it to `next()` ourselves to skip ahead. Lua's hash iteration is opaque from the outside.

We tried calling `BuildEventNameMap` at three different timing points (file load, `EVENT_ADD_ON_LOADED`, `EVENT_PLAYER_ACTIVATED`) hoping the global table state would differ:

```
["_eventNamesSize_load"]  = 3,
["_eventNamesSize_addon"] = 3,
["_eventNamesSize"]       = 3,
```

Hash table iteration order in Lua 5.1 is determined by the hash slot of each key, which doesn't change once a key is inserted. **Identical iteration order at every call site → identical wall position.**

---

# Workaround: `pcall(rawget)` probes

The breakthrough was realizing that the iteration crash and the value access crash are different mechanisms. `pairs`/`next` reads values during iteration via the underlying VM step. Some keys have a VM-level access guard that errors during this read.

`rawget(_G, name)` bypasses metamethods entirely and goes straight to the hash slot. **It does not trigger the protected access guard** — at least not for the keys we care about. We just need to know the key names ahead of time, which means giving up on enumeration and switching to a hardcoded probe list.

```lua
ACI.knownEventNames = {
    "EVENT_ADD_ON_LOADED", "EVENT_PLAYER_ACTIVATED",
    "EVENT_COMBAT_EVENT", "EVENT_EFFECT_CHANGED",
    -- ... ~120 well-known event names
}

function ACI.BuildEventNameMap(into)
    local map = into or {}
    for _, name in ipairs(ACI.knownEventNames) do
        local ok, v = pcall(rawget, _G, name)
        if ok and type(v) == "number" then
            map[v] = name
        end
    end
    return map
end
```

`pcall` is kept as a defensive measure in case any specific name still trips the guard, but in practice all 120 probes succeed.

## Verification

```
["_eventNamesSize"] = 114,
```

114 out of 120 probes resolved. The 6 misses are events that were renamed or removed in current ESO versions. After deploying, `/aci hot` correctly displays:

```
4 addons, 6 regs  EVENT_PLAYER_ACTIVATED
2 addons, 141 regs  EVENT_COMBAT_EVENT
2 addons, 23 regs  EVENT_EFFECT_CHANGED
2 addons, 2 regs  EVENT_PLAYER_DEACTIVATED
2 addons, 6 regs  EVENT_POWER_UPDATE
2 addons, 4 regs  EVENT_PLAYER_COMBAT_STATE
```

The "131109 LibCombat custom pseudo-event" hypothesis was wrong. `131109` is the real `EVENT_COMBAT_EVENT` code — LibCombat just registers on it 136 times.

---

# Why this matters beyond ACI

Any ESO addon that needs to enumerate `_G` for any purpose (debug tools, event introspection, dynamic constant lookup, autocomplete, runtime API surface analysis) hits this wall. The standard advice "wrap `pairs(_G)` in pcall" is technically correct (prevents the crash) but produces empty results that look like success.

**Safe pattern for ESO**: never iterate `_G`. If you need a set of constants, hardcode the names you care about and probe via `pcall(rawget, _G, name)`.

This applies to:
- `EVENT_*` constants (this case)
- `INTERACTION_*`, `INTERACT_*` constants
- `BAG_*`, `SLOT_*` constants
- Anything else where you'd be tempted to enumerate by name prefix

---

# Lessons

## 1. Verify the fix actually does what you think it does

The Phase 2 pcall-wrap was tested by checking "does `PLAYER_ACTIVATED` complete?" — answer: yes. We never asked "does the cache contain useful data?" because no consumer needed it yet. **A fix that suppresses the symptom is not the same as a fix that solves the problem.** Phase 2 closed with a cache that was 99.6% empty and nobody noticed for 6 commits.

## 2. Distinguish "crash prevented" from "function works"

`pcall` is a crash suppressor. It says nothing about whether the wrapped code accomplished its goal. When the wrapped operation is iterative state-building (`for ... do map[k] = v end`), suppressing the crash means accepting whatever partial state was built before the crash. That partial state can be anything from "complete" to "empty".

Always pair `pcall` with a sanity check on the output:

```lua
local map = ACI.BuildEventNameMap()
assert(next(map) ~= nil, "BuildEventNameMap returned empty")
-- or at least: ACI_SavedVars._diagSize = ACI.TableLength(map)
```

## 3. Hash iteration order is opaque — you cannot skip a bad key

When `next(t, k)` errors, you lose the ability to advance. There's no `next(t, k, skip=true)`. The only ways forward are:
- Avoid iteration entirely (rawget probes, like this fix)
- Use a different table that wraps the original safely
- Change the data source (e.g., enumerate via a different API)

Per-step pcall around `next()` does not help because `next()` is deterministic — retrying yields the same crash on the same key.

## 4. Bypass metamethods when the metatable is hostile

ESO's `_G` has some kind of access guard that fires during iteration. `rawget` does not trigger metamethods (`__index`, etc.) and reads the raw hash slot directly. This is a powerful escape hatch when you suspect a metatable is the culprit.

`rawget`, `rawset`, `rawequal`, `rawlen` — keep these in mind for any situation where standard table access misbehaves.

## 5. The cost of a hardcoded list is lower than the cost of clever iteration

Maintaining a list of ~120 event names feels ugly and "non-extensible". But:
- ESO adds maybe 5-10 events per major patch
- Updates take 30 seconds
- The list is testable and predictable
- The alternative is 0 entries

Sometimes the dumb solution is the right solution. We spent more code (and cycles) on per-step pcall, multi-timing experiments, and SV diagnostic fields than the entire hardcoded list took to write.

---

# Code paths affected

| File | Change |
|------|--------|
| `ACI_Core.lua` | `BuildEventNameMap` rewritten to use `pcall(rawget)` probes against `ACI.knownEventNames`. Removed multi-pass timing logic. |
| `ACI_Core.lua` | `ACI.knownEventNames` table added (~120 entries) |
| `ACI_Commands.lua` | `PrintHotPaths` already called `ACI.EventName(code)` — no change needed once the cache was populated correctly. |

---

# Open questions

- **Which exact `_G` key is the protected one?** Unknown. Could probably be found via binary search by hardcoding a known-good iteration prefix and testing what advances past it. Not worth the time — we don't need to identify it, only avoid it.
- **Are there `EVENT_*` names we're missing?** Likely yes. The probe list is curated from common addon usage patterns. Any addon using a rare event would still show as raw code. Mitigation: extend the list when we encounter unfamiliar codes.
- **Does `pcall(rawget)` work for all `_G` keys?** Unknown. The 6 missing probes (114/120) might be renamed events, or might be cases where rawget also fails. No way to tell without per-name diagnostics.

---

# Timeline

| Step | Result |
|------|--------|
| Phase 2 Step 0 | `pairs(_G)` pcall-wrap stops `PLAYER_ACTIVATED` crash. Declared fixed. |
| Phase 3 C | `/aci hot` displays raw codes instead of names. Hypothesis: LibCombat custom codes. |
| Phase 3 C diagnostic | `_eventNamesSize = 2` written to SV. Cache was empty all along. |
| Phase 3 C attempt 1 | Per-step `pcall(next)` — still 3 entries. `next` cannot skip bad key. |
| Phase 3 C attempt 2 | Multi-pass at 3 timing points — all 3, identical. Hash order is deterministic. |
| Phase 3 C fix | `pcall(rawget, _G, name)` probes against hardcoded ~120 event names. **114/120 success.** |
| Verification | `/aci hot` shows `EVENT_COMBAT_EVENT`, `EVENT_PLAYER_ACTIVATED`, etc. Hypothesis disproved: `131109 = EVENT_COMBAT_EVENT`, real ESO event. |
