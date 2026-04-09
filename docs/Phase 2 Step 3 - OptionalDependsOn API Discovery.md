# Phase 2 Step 3 — OptionalDependsOn API Discovery

## Date: 2026-04-09

## Discovery

ESO's `GetAddOnDependencyInfo()` API only returns **`DependsOn`** entries. 
**`OptionalDependsOn` entries are completely invisible to the API.**

## Test Method

### Test 1: DependsOn with typo deps

Original manifest (`OptionalDependsOn: LibDebugLogger`) was replaced via deploy:

```bash
DEST="C:/Users/user/Documents/Elder Scrolls Online/live/AddOns/ZZZ_AddOnInspector/ZZZ_AddOnInspector.txt"
sed -i 's/## OptionalDependsOn: LibDebugLogger/## DependsOn: LibAddonManu-2.0 LibDebuggLogger/' "$DEST"
```

Resulting deployed manifest:
```
## Title: AddOn Conflict Inspector
## Author: Ricci Curvature
## APIVersion: 101049 101050
## AddOnVersion: 1
## Version: 0.2.0
## IsLibrary: false
## SavedVariables: ACI_SavedVars
## DependsOn: LibAddonManu-2.0 LibDebuggLogger
## Description: Diagnose addon conflicts, namespace collisions, and performance issues for everyday ESO players.

ACI_Core.lua
ACI_Hooks.lua
ACI_Inventory.lua
ACI_Analysis.lua
ACI_Commands.lua
```

Expected hint results:
- `LibAddonManu-2.0` — Levenshtein distance 1 (`Manu` → `Menu`), hint: `LibAddonMenu-2.0`
- `LibDebuggLogger` — Levenshtein distance 1 (`gg` → `g`), hint: `LibDebugLogger`

**Result: ACI failed to load entirely.** Game started with blank screen, no chat output, no `[ACI] v0.2.0 loaded` message. ESO blocks any addon whose `DependsOn` targets are not installed.

User report: "아까처럼 접속하면 아무것도 안뜨는데" (Nothing shows up when I log in)

### Test 2: OptionalDependsOn with same typo deps

Switched from `DependsOn` to `OptionalDependsOn`:

```bash
DEST="C:/Users/user/Documents/Elder Scrolls Online/live/AddOns/ZZZ_AddOnInspector/ZZZ_AddOnInspector.txt"
sed -i 's/## DependsOn: LibAddonManu-2.0 LibDebuggLogger/## OptionalDependsOn: LibAddonManu-2.0 LibDebuggLogger/' "$DEST"
```

Resulting deployed manifest:
```
## OptionalDependsOn: LibAddonManu-2.0 LibDebuggLogger
```

**Result: ACI loaded normally** (`[ACI] v0.2.0 loaded` appeared in chat), but `/aci missing` returned **0 results**. The typo deps were completely invisible to `GetAddOnDependencyInfo()`.

User report: "[ACI] v0.2.0 loaded 이건 뜨는데 LibAddonManu-2.0, LibDebuggLogger는 안나오네" (v0.2.0 loaded shows up, but the typo deps don't appear)

### Manifest Restored

```
## OptionalDependsOn: LibDebugLogger
```

## Why This Happens — Code Path

`ACI_Inventory.lua` collects dependency info via `GetAddOnDependencyInfo()`:

```lua
local numDeps = manager:GetAddOnNumDependencies(i)
local deps = {}
for d = 1, numDeps do
    if manager.GetAddOnDependencyInfo then
        local depName, depActive = manager:GetAddOnDependencyInfo(i, d)
        table.insert(deps, { name = depName, active = depActive })
    end
end
```

`ACI_Analysis.lua` builds the dependency index from this data:

```lua
function ACI.BuildDependencyIndex()
    -- ...
    for _, addon in ipairs(meta.addons) do
        byName[addon.name] = addon
        forward[addon.name] = {}
        for _, dep in ipairs(addon.deps) do
            table.insert(forward[addon.name], dep.name)
            if addon.enabled then
                if not reverse[dep.name] then reverse[dep.name] = {} end
                table.insert(reverse[dep.name], addon.name)
            end
        end
    end
    -- ...
end
```

`FindMissingDependencies()` then checks `depIndex.reverse` keys against `depIndex.byName`:

```lua
function ACI.FindMissingDependencies()
    -- ...
    for depName, users in pairs(depIndex.reverse) do
        if not depIndex.byName[depName] then
            -- This dep name has no matching installed addon
            local hint = nil

            -- Tier 1: case-insensitive exact match
            local lower = depName:lower()
            if installedLower[lower] and installedLower[lower] ~= depName then
                hint = { type = "case", suggestion = installedLower[lower] }
            end

            -- Tier 2: version-suffix-stripped match
            if not hint then
                local stripped = StripVersionSuffix(depName)
                if stripped ~= depName and installedLower[stripped:lower()] then
                    hint = { type = "version", suggestion = installedLower[stripped:lower()] }
                end
            end

            -- Tier 3: Levenshtein distance
            if not hint then
                local closest, dist = FindClosestMatch(depName, installedList, 8, 3)
                if closest then
                    hint = { type = "typo", suggestion = closest, distance = dist }
                end
            end

            table.insert(missing, { name = depName, users = users, hint = hint })
        end
    end
    -- ...
end
```

Since `OptionalDependsOn` entries never appear in `addon.deps` (because `GetAddOnDependencyInfo` doesn't return them), they never enter `depIndex.reverse`, and `FindMissingDependencies()` never sees them.

## Implications

- `FindMissingDependencies()` can only detect unresolved `DependsOn` entries from **other addons**
- ACI cannot detect its own missing optional dependencies
- The 3-tier hint matching (case → version-strip → levenshtein) is correctly implemented but only triggers when another addon has an unresolved `DependsOn`
- In practice, addons with unresolved `DependsOn` won't load, but they still appear in `GetAddOnManager()` metadata with `enabled=true` and their dependency info is accessible

## ESO API Behavior Summary

| Manifest Directive | `GetAddOnDependencyInfo` | Addon Loads? |
|---|---|---|
| `DependsOn: InstalledLib` | Returns entry, `active=true` | Yes |
| `DependsOn: MissingLib` | Returns entry, `active=false` | **No** (blocked) |
| `OptionalDependsOn: InstalledLib` | **Not returned** | Yes |
| `OptionalDependsOn: MissingLib` | **Not returned** | Yes |

## Testing Alternative

To test hint matching in-game, inject `DependsOn: LibDebuggLogger` into a **different addon's manifest** (not ACI). That addon won't load, but ACI will still be able to read its dependency info and detect the typo.

## Status

Feature implemented and code-reviewed. Natural triggering will occur when users have addons with genuinely unresolved `DependsOn` entries (e.g., after uninstalling a library that other addons require).
