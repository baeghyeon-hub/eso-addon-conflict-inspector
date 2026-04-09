# ZZZ_AddOnInspector (ACI)

An ESO (Elder Scrolls Online) addon that diagnoses your addon environment — event registrations, dependency issues, SavedVariables conflicts, and overall health.

## Features

- **Event Hook Monitoring** — intercepts `RegisterForEvent` calls at load time, counts registrations per addon cluster
- **Load Order Tracking** — records exact load sequence and init time estimation
- **Dependency Analysis** — forward/reverse dependency index, orphan library detection, de-facto library detection
- **Missing Dependency Detection** — finds declared `DependsOn` entries that aren't installed, with 3-tier hint matching:
  - Case mismatch (`libFoo` installed but `LibFoo` declared)
  - Version suffix mismatch (`LibFoo` installed but `LibFoo-2.0` declared)
  - Typo detection via Levenshtein distance
- **Out-of-Date Segmentation** — classifies OOD addons into standalone (user action needed), library (author abandoned), and embedded (bundled, ignore)
- **Safe-to-Delete Detection** — identifies orphan libraries that are also out-of-date: zero-risk removal candidates
- **SavedVariables Conflict Detection** — identifies multiple addons writing to the same SV table::namespace pair
- **Embedded Sub-addon Tagging** — distinguishes top-level addons from bundled sub-addons via `rootPath` analysis
- **Health Score** — traffic-light diagnosis (green/yellow/red) with segmented OOD breakdown, orphan count, missing deps, SV conflicts, and safe-to-delete recommendations
- **16 Slash Commands** — `/aci`, `/aci health`, `/aci orphans`, `/aci missing`, `/aci ood`, `/aci deps`, and more

## Installation

Copy the `ZZZ_AddOnInspector` folder to your ESO AddOns directory:

```
Documents/Elder Scrolls Online/live/AddOns/ZZZ_AddOnInspector/
```

The `ZZZ_` prefix ensures it loads last, allowing it to observe all other addons' registrations.

## Commands

| Command | Description |
|---------|-------------|
| `/aci` | Summary report |
| `/aci health` | Environment diagnosis (traffic light + safe-to-delete) |
| `/aci orphans` | Unused libraries + de-facto libraries |
| `/aci missing` | Missing dependencies + 3-tier hints |
| `/aci ood` | Out-of-date breakdown (standalone / library / embedded) |
| `/aci stats` | Event registration stats by cluster |
| `/aci addons` | Full addon list |
| `/aci deps` | Most depended-on libraries |
| `/aci deps X` | Forward/reverse deps for addon X |
| `/aci init` | Init time estimation (top 10) |
| `/aci hot` | Event hot paths |
| `/aci sv` | SavedVariables registrations + conflicts |
| `/aci save` | Force SV priority save |
| `/aci help` | Command list |

## Architecture

```
ZZZ_AddOnInspector/
  ACI_Core.lua        — globals, SV init, event lifecycle, utilities
  ACI_Hooks.lua       — PreHook install (RegisterForEvent, ZO_SavedVars)
  ACI_Inventory.lua   — static metadata collection via GetAddOnManager
  ACI_Analysis.lua    — clustering, dependency index, OOD segmentation, health score, typo detection
  ACI_Commands.lua    — /aci slash command system (16 commands)
```

## Key Technical Notes

- **`pairs(_G)` must be pcall-wrapped** — ESO's global table contains protected entries that crash on iteration. Event callbacks are silently wrapped in pcall by ESO, so the error is caught but all subsequent code in the callback is aborted. See `docs/Phase 2 Step 0 - pairs(_G) Silent Crash Troubleshooting.md`.
- **`d()` needs `zo_callLater`** — chat output during `EVENT_ADD_ON_LOADED` or `EVENT_PLAYER_ACTIVATED` executes without error but the chat UI isn't ready to display. Delay with `zo_callLater(fn, 500-1000)`.
- **`/reloadui` does not reload addon code** — ESO requires a full game restart to pick up Lua file changes.
- **`OptionalDependsOn` is invisible to API** — `GetAddOnDependencyInfo()` only returns `DependsOn` entries. `OptionalDependsOn` entries are not reported. See `docs/Phase 2 Step 3 - OptionalDependsOn API Discovery.md`.

## Documentation

Development logs and design documents are in the `docs/` folder, organized by phase:

- **Phase 0** — Proof of concept, SV data analysis
- **Phase 1** — Full architecture, inventory, analysis, health score, commands
- **Phase 2** — Technical debt cleanup (`pairs(_G)` fix), missing dep detection, typo hints, OOD segmentation, safe-to-delete

## License

This project is source-available under a custom license.

Personal, private, non-commercial use and private local modifications are
allowed. Re-uploading, redistributing, repackaging, or distributing modified
versions is not allowed without prior written permission.

See the [LICENSE](LICENSE) file for the full terms.

This add-on is not created by, affiliated with, or sponsored by ZeniMax Media Inc. or its affiliates. The Elder Scrolls is a registered trademark of ZeniMax Media Inc.
