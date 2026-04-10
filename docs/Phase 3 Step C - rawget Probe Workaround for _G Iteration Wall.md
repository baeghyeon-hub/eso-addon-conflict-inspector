# My pcall "Fix" Was a Lie. Here's How I Found Out 6 Commits Later.

*A story about wrapping the right thing in the wrong way, and why "the crash stopped" is not the same as "the function works".*

---

If you write Lua for a game that embeds its own modified VM, you eventually run into a global table you can't iterate. Mine was Elder Scrolls Online's `_G`. I "fixed" the crash. The fix worked. Six commits later I discovered the fix had been quietly producing garbage the entire time.

This is the story of how `pcall(rawget, _G, name)` saved a feature that I didn't even know was broken.

## The Setup

I'm building **AddOn Conflict Inspector** (ACI), a diagnostic addon for Elder Scrolls Online. One of its features is `/aci hot` — show the events that the most addons are registered on, so you can spot performance bottleneck candidates. Output looks like this:

```
4 addons, 6 regs  EVENT_PLAYER_ACTIVATED
2 addons, 141 regs  EVENT_COMBAT_EVENT
2 addons, 23 regs  EVENT_EFFECT_CHANGED
```

That `EVENT_COMBAT_EVENT` label is the interesting part. ESO's `EVENT_MANAGER:RegisterForEvent` takes a numeric event code, not a name. The `EVENT_*` constants live in `_G` as integer-typed globals. To turn `131109` back into `EVENT_COMBAT_EVENT`, I built a reverse lookup map at addon load time:

```lua
function ACI.BuildEventNameMap()
    local map = {}
    for k, v in pairs(_G) do
        if type(v) == "number" and type(k) == "string" and k:sub(1, 6) == "EVENT_" then
            map[v] = k
        end
    end
    return map
end
```

Simple. Iterate `_G`, grab everything starting with `EVENT_` whose value is a number, build the inverse table. ESO has roughly 700 of these constants. The map should have 700-ish entries.

It crashed. Hard.

## The Phase 2 "Fix"

The crash didn't even surface as a Lua error. ESO wraps event callbacks in a protected call internally, so when `pairs(_G)` errored partway through iteration, the entire `EVENT_PLAYER_ACTIVATED` callback was silently aborted. I lost not just the event name map but everything that ran after it: metadata collection, the initial report, all the diagnostic output.

I documented this in `Phase 2 Step 0 - pairs(_G) Silent Crash Troubleshooting.md`. The cause is that ESO's `_G` contains protected entries — globals with some kind of access guard that fires during iteration. The fix at the time:

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

Wrap the whole loop in `pcall`. If iteration crashes, catch the error, return whatever was collected. The callback no longer aborts. `EVENT_PLAYER_ACTIVATED` runs to completion. The initial report shows up. I marked Phase 2 Step 0 done and moved on.

I never actually checked how many entries the map contained. Why would I? The crash was the bug, the crash was fixed, the report was printing. There was no consumer surface for the event name map at the time — `EventName(code)` was a stub that one place in the code called and nobody looked at the output.

## Six Commits Later

Phase 3 came around. I was building `/aci hot` and finally needed real event names. I wired `ACI.EventName(h.eventCode)` into the output formatter, deployed, restarted the game, and got this:

```
5 addons, 7 regs  589824
3 addons, 4 regs  65540
2 addons, 2 regs  589825
2 addons, 141 regs  131109
2 addons, 23 regs  131158
2 addons, 4 regs  131459
```

Raw numbers. No names.

My first hypothesis was reasonable: maybe these specific codes are LibCombat custom pseudo-events. LibCombat is famous in the ESO addon community for inventing its own internal callback codes that don't have public `EVENT_*` constants. `131109 = 0x20025` looks suspiciously like a bit-pattern. Maybe the names just don't exist.

But before chasing that hypothesis, I added one diagnostic line:

```lua
ACI_SavedVars._eventNamesSize = ACI.TableLength(ACI.eventNames)
```

Saved, restarted, grepped the SV file:

```
["_eventNamesSize"] = 2,
```

**Two.**

Out of seven hundred. The Phase 2 fix had been producing a 99.7% empty cache for six commits. Nobody noticed because nobody was reading from it.

The "131109 is a custom LibCombat code" hypothesis was wrong before I even tested it. `131109` is the actual numeric code for `EVENT_COMBAT_EVENT`. The reason it wasn't being resolved had nothing to do with LibCombat. It was that the cache only contained two entries, period, and `EVENT_COMBAT_EVENT` wasn't one of them.

## Trying to Skip the Bad Key

OK, so `pairs(_G)` aborts after 2-3 iterations. I need to skip past the bad key and continue. Lua has `next(t, k)` which gives you the key after `k`. If I call it manually with per-step `pcall`, I should be able to catch the error on the bad key, log it, and... wait. If `next(_G, k)` errors when trying to advance from `k`, I don't know what the next key is. I can't supply it to `next()` to skip ahead.

I tried anyway:

```lua
function ACI.BuildEventNameMap()
    local map = {}
    local k = nil
    while true do
        local ok, nk, nv = pcall(next, _G, k)
        if not ok or nk == nil then break end
        if type(nv) == "number" and type(nk) == "string" and nk:sub(1, 6) == "EVENT_" then
            map[nv] = nk
        end
        k = nk
    end
    return map
end
```

The thinking: at least if `next()` fails on a specific transition, I'd see partial data up to that point. Maybe the error is recoverable — maybe a fresh `next` call after an error would advance.

Result: 3 entries. Marginally better than 2. Same wall.

Lua's `next()` is deterministic. If `next(_G, k)` errors, calling it again with the same `k` errors again. There is no "skip" mode. Hash table iteration order is determined by the slot of each key in the underlying array, and you cannot reorder it from outside.

## Trying Different Timing

Next theory: maybe the protected globals get added to `_G` at a specific point during ESO's initialization. If I call `BuildEventNameMap` *before* that point, the bad key might not exist yet. I instrumented three timing positions:

```lua
-- Attempt #1: file-load time (top-level code, earliest possible)
ACI.BuildEventNameMap(ACI.eventNames)

-- Attempt #2: EVENT_ADD_ON_LOADED for our own addon
local function OnACILoaded(eventCode, addonName)
    if addonName ~= ACI.name then return end
    ACI_SavedVars._eventNamesSize_load = ACI.TableLength(ACI.eventNames)
    ACI.BuildEventNameMap(ACI.eventNames)
    ACI_SavedVars._eventNamesSize_addon = ACI.TableLength(ACI.eventNames)
    -- ...
end

-- Attempt #3: EVENT_PLAYER_ACTIVATED (latest, all addons loaded)
EVENT_MANAGER:RegisterForEvent(ACI.name, EVENT_PLAYER_ACTIVATED, function()
    ACI.BuildEventNameMap(ACI.eventNames)
    ACI_SavedVars._eventNamesSize = ACI.TableLength(ACI.eventNames)
end)
```

Each call extends the same shared map. If different timings hit different walls, I'd see growth across the three diagnostic sizes. Saved, restarted, grepped:

```
["_eventNamesSize_load"]  = 3,
["_eventNamesSize_addon"] = 3,
["_eventNamesSize"]       = 3,
```

All three identical. Same 3 entries every time.

Of course they were. Lua 5.1 hash slots are determined by the hash function applied to the key, and the hash function doesn't change between calls. The bad key sits in the same iteration position regardless of when you start iterating. Multi-timing was never going to help, and I'd just spent three deploy cycles confirming that.

## The Insight

I sat there looking at the diagnostic output and thinking about what `pairs` actually does. `pairs(t)` calls `next(t, k)` repeatedly. `next` is a C function in the Lua VM that walks the hash table and reads both the key and the value at each position. Whatever is happening with the protected globals, it's happening during that read.

But there's another way to read a value from a table: `rawget(t, k)`. Unlike `t[k]`, `rawget` bypasses metamethods entirely. It goes straight to the hash slot lookup and returns whatever is there. No `__index`, no access guard, no nothing.

The catch: `rawget` requires you to know the key. You can't enumerate. You can only ask "is `_G["EVENT_COMBAT_EVENT"]` defined?" and get yes/no. If you don't know the name to ask about, you're stuck.

But — for my use case, I *do* know the names. I've been writing ESO addons for a while. I know roughly which `EVENT_*` constants exist. I can hardcode a list and probe each one:

```lua
ACI.knownEventNames = {
    "EVENT_ADD_ON_LOADED", "EVENT_PLAYER_ACTIVATED", "EVENT_PLAYER_DEACTIVATED",
    "EVENT_PLAYER_DEAD", "EVENT_PLAYER_ALIVE", "EVENT_PLAYER_REINCARNATED",
    "EVENT_PLAYER_COMBAT_STATE", "EVENT_COMBAT_EVENT", "EVENT_BOSSES_CHANGED",
    "EVENT_TARGET_CHANGE", "EVENT_RETICLE_TARGET_CHANGED", "EVENT_POWER_UPDATE",
    "EVENT_LEVEL_UPDATE", "EVENT_EXPERIENCE_UPDATE", "EVENT_ABILITY_LIST_CHANGED",
    "EVENT_UNIT_CREATED", "EVENT_UNIT_DESTROYED", "EVENT_UNIT_DEATH_STATE_CHANGED",
    "EVENT_GROUP_MEMBER_JOINED", "EVENT_GROUP_MEMBER_LEFT",
    "EVENT_INVENTORY_FULL_UPDATE", "EVENT_INVENTORY_SINGLE_SLOT_UPDATE",
    "EVENT_QUEST_ADDED", "EVENT_QUEST_COMPLETE", "EVENT_QUEST_ADVANCED",
    "EVENT_ZONE_CHANGED", "EVENT_EFFECT_CHANGED", "EVENT_EFFECTS_FULL_UPDATE",
    -- ... ~120 entries total, covering common addon-registered events
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

The `pcall` is defensive. I expected most probes to succeed but didn't want a single bad name to kill the loop, just like before. I called this from file-load time so the cache would be populated before any consumer touched it:

```lua
ACI.eventNames = {}

-- File-load time: probe all known events into the cache
ACI.BuildEventNameMap(ACI.eventNames)

function ACI.EventName(code)
    if not next(ACI.eventNames) then
        ACI.BuildEventNameMap(ACI.eventNames)  -- lazy retry
    end
    return ACI.eventNames[code] or tostring(code)
end
```

Saved, deployed, restarted, ran `/aci save`, grepped:

```
["_eventNamesSize"] = 114,
```

**One hundred fourteen.** Out of 120 probes. Six misses, probably events that were renamed or removed between ESO versions. The other 114 resolved instantly.

`/aci hot` now showed:

```
4 addons, 6 regs  EVENT_PLAYER_ACTIVATED
2 addons, 141 regs  EVENT_COMBAT_EVENT
2 addons, 23 regs  EVENT_EFFECT_CHANGED
2 addons, 2 regs  EVENT_PLAYER_DEACTIVATED
2 addons, 6 regs  EVENT_POWER_UPDATE
2 addons, 4 regs  EVENT_PLAYER_COMBAT_STATE
```

`131109` was indeed `EVENT_COMBAT_EVENT`. LibCombat just registers on it 136 times, which is exactly the kind of pattern `/aci hot` was designed to surface.

## Why rawget Works

I don't have ESO's source code, but I have a working theory.

`pairs` and `next` operate at the VM level. They walk the hash table by stepping through internal slots and reading whatever is there. ESO's protected globals seem to have *something* — maybe a special hash slot type, maybe an upvalue that errors when read, maybe a tagged value with a side effect — that fires during this VM-level read. Whatever it is, it's tied to the iteration mechanism.

`rawget`, on the other hand, takes a key, hashes it, walks the collision chain for that specific slot, and returns the value. It doesn't iterate. It doesn't visit any slot other than the one you asked about. If your key doesn't collide with the protected one in the hash table, you never touch the protected slot, and the access guard never fires.

That's why hardcoding works: every key in my probe list resolves to a different hash slot than the protected key, so each probe accesses memory the access guard doesn't watch. The guard only fires when you try to step into its slot during iteration.

This is speculative — I can't see the VM internals. But it matches the observed behavior. `pairs(_G)` dies at slot ~3. `pcall(rawget, _G, "EVENT_COMBAT_EVENT")` succeeds 100% of the time. The two operations are reading from the same table but using different code paths.

## The Cache Was Empty for Six Commits

This is the part that bothers me most.

Phase 2 closed with the cache holding 2 entries instead of 700. The pcall fix prevented the visible symptom (callback abort) but left the underlying functionality broken. I shipped six commits — including a Phase 2 completion report claiming all features verified — without anyone noticing.

The reason is structural: nothing read from the cache. `EventName(code)` existed but only one place called it, and that place was buried in summary output where the absence of resolved names looked like normal "this code has no public name" rather than "the cache is empty".

The fix that surfaced the problem was the *new feature* in Phase 3 C. `/aci hot` was the first user-facing place where missing event names were obviously wrong. Without that feature, the broken cache might have stayed broken indefinitely.

I'm going to be more careful from now on about a specific pattern: **fixes that suppress crashes in iterative state-building code**. When you wrap `for ... do map[k] = v end` in `pcall`, you're not fixing iteration. You're saying "stop crashing, and I'll accept whatever partial state you got". That partial state could be 100% complete or 0.3% complete. You won't know unless you check.

The cheap version of "checking" is one diagnostic line:

```lua
ACI_SavedVars._diagSize = ACI.TableLength(map)
```

If I'd added that to the Phase 2 fix, I would have seen `2` immediately and known something was wrong before declaring the phase complete.

## What I'd Tell Past Me

A few things, in order of importance:

**1. `pcall` is a crash suppressor, not a fix.** It catches errors. It says nothing about whether your code accomplished its goal. When the wrapped code's purpose is to populate state, always sanity-check the populated state.

**2. Don't iterate `_G` in ESO.** Or more generally: don't iterate any table in a host environment that has access guards on individual keys. Hash iteration order is opaque, you can't skip past a bad key, and per-step `pcall` doesn't help because the bad key is deterministic. Use `rawget` against a known list instead.

**3. `rawget`, `rawset`, `rawequal`, and `rawlen` are escape hatches.** When standard table access misbehaves and you suspect a metatable, the raw versions bypass metamethods entirely. Keep them in your toolkit for hostile metatables.

**4. The dumb solution often beats the clever one.** I burned three deploy cycles on per-step `pcall` and multi-timing experiments. The hardcoded list of 120 names took five minutes to type and works perfectly. ESO adds maybe 5-10 events per major patch. Maintaining the list is cheaper than maintaining clever iteration code that doesn't work.

**5. New features expose old bugs.** The Phase 2 fix was wrong but invisible because nothing consumed the cache. The Phase 3 feature didn't introduce the bug — it surfaced it. Be glad when this happens and don't rationalize it away ("oh, those codes are probably custom"). If something looks broken in your output, it probably *is* broken somewhere upstream.

## The Numbers

| Approach | Cache size | Verdict |
|---|---|---|
| Original `pairs(_G)` | crashes | unfixed |
| `pcall` around the whole loop | 2-3 entries | suppresses crash, breaks cache |
| Per-step `pcall(next, _G, k)` | 3 entries | same wall, deterministic |
| Multi-timing (load/addon/activated) | 3, 3, 3 | hash order is constant |
| `pcall(rawget, _G, name)` × 120 known | 114 | works |

The fix that worked was less code than the fix that didn't. It's also more obvious in hindsight, which is the most painful kind of obvious.

---

*ACI is open source. Code lives on [GitHub](https://github.com/baeghyeon-hub/eso-addon-conflict-inspector). The full Phase 2 Step 0 troubleshooting log (the original `pairs(_G)` crash) is in the `docs/` folder, and so is this story's source-of-truth notes file.*
