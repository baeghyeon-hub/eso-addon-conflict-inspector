# Phase 2 Step 3 — OptionalDependsOn API Discovery

## Date: 2026-04-09

## Discovery

ESO's `GetAddOnDependencyInfo()` API only returns **`DependsOn`** entries. 
**`OptionalDependsOn` entries are completely invisible to the API.**

## Test Method

1. Injected `## DependsOn: LibAddonManu-2.0 LibDebuggLogger` into ACI's manifest
   - Result: ACI failed to load entirely (blank screen, no chat output)
   - ESO blocks any addon whose `DependsOn` targets are not installed

2. Changed to `## OptionalDependsOn: LibAddonManu-2.0 LibDebuggLogger`
   - Result: ACI loaded normally, `[ACI] v0.2.0 loaded` appeared
   - `/aci missing` returned 0 results — the typo deps were invisible

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
