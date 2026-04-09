# ESO AddOn Conflict Inspector - Recon Findings & Implementation Plan

> **Project codename**: AddOn Conflict Inspector (ACI)
>
> **Date**: 2026-04-08
>
> **Status**: Recon complete, right before PoC entry
>
> **Target users**: Regular ESO players with 10+ addons installed, guild troubleshooting helpers, console users

---

# One-line summary

The ESO addon ecosystem already has **enough developer-facing profiling tools** (ESOProfiler, Zgoo, LibDebugLogger), but there is still no solid **"diagnose my environment and help me troubleshoot it"** tool for regular users. ACI is aimed at that gap.

# Market Recon Findings

## Existing tools (competitors / complements)

| Tool | Author | What it does | Relationship to ACI |
| --- | --- | --- | --- |
| **ESOProfiler** | sirinsidiator | Wrapper around the official ZOS script profiler API. Per-function timing, call stacks, Perfetto trace export | **Developer tool. Not for regular users.** ACI does not build on top of it |
| **Zgoo** | (zgoo author) | Live variable inspection, event tracing via `/zgoo events`, control inspection | **Developer debugger.** ACI does not replace it |
| **LibDebugLogger + DebugLogViewer** | sirinsidiator | Logging infrastructure and external viewer | **Infrastructure.** ACI can use it as a dependency |
| **Performance Statz** | - | Shows average FPS / latency | Simple utility. Not ACI's target |
| **Addon Clearer** (discontinued) | - | Bulk enable / disable buttons | Dead |
| **Minion** (external) | - | Download / update manager | Out-of-game tool. Not ACI's target |
| **Default ZOS AddOn Manager** | ZOS | Enable / disable, show dependencies | **Weak.** ACI's real competitor and baseline |

## The gap ACI can own

- Rich per-addon static metadata view that goes beyond the default ZOS UI
- Dependency graph visualization
- Global namespace collision diagnostics ("these two addons use the same variable name")
- SavedVariables collision diagnostics
- Per-addon event registration counts / hot-path diagnostics
- Console memory budget tracker (100 MB shared pool)
- Troubleshooting environment dump / clipboard export for guild help channels
- Automatic suspicion scoring for "which addon probably caused this bug?" using LibDebugLogger logs plus suggested disables

# Technical Recon Findings

## Critical fact 1: Characteristics of the ESO Lua environment

- **Havok Script (Lua 5.1-based, 64-bit, with some 5.2/5.3 backports)**
- **The `io`, `os`, and `package` modules are removed** - no direct file or network access
- **All variables are truly global**: every addon shares the same global table, and API functions are global too -> namespace inspection via `_G` traversal is possible
- **SavedVariables are only flushed to disk on zone change / reloadui / logout**

## Critical fact 2: EVENT_MANAGER can be hooked

The EVENT_MANAGER object's internal registration table lives on the C side, so it cannot be enumerated directly. **However**, `EVENT_MANAGER:RegisterForEvent` is a Lua function, so it can be intercepted with `ZO_PreHook`.

```lua
-- ZO_PreHook signature
function ZO_PreHook(objectTable, existingFunctionName, hookFunction)
-- Or for a global function:
function ZO_PreHook(existingFunctionNameInQuotes, hookFunction)

-- If hookFunction returns true -> the original call is blocked
-- If it returns false/nil -> the original call proceeds (normal case)
```

`SecurePostHook` also exists. It is recommended to always use `ZO_PreHook` / `SecurePostHook` instead of overwriting functions directly, to avoid secure-context taint. BetterUI recently migrated to this approach.

## Critical fact 3: Addon load-order rules

Official rules (from the `Addon Structure` wiki):

1. If dependencies (`DependsOn`, `OptionalDependsOn`) exist, they affect sorting first
2. If there are no dependencies, folders are loaded in **reverse alphabetical order**. In other words, folders starting with **Z load earlier**, and those closer to A load later
3. ZOS code always loads first
4. If duplicate names exist, the one with the larger `AddOnVersion` is selected

**-> ACI's folder name should start with something like `ZZZ_AddOnInspector` so it loads before other addons.** This is not a hack; it is official ZOS behavior, so it is relatively stable.

**Limit**: This is not guaranteed 100%. Other libraries can use the same trick. The honest handling is: "addons that did not load before us may be missing from the analysis."

## Critical fact 4: There are three event systems

To do real conflict analysis, we need to monitor **all three**:

1. **`EVENT_MANAGER:RegisterForEvent`** - C -> Lua game events (the biggest one)
2. **`control:RegisterForEvent`** - XML control-level events (used by things like TradingHouse)
3. **`CALLBACK_MANAGER:RegisterCallback`** - custom addon-to-addon events (fake events created by addons)

Even ESOProfiler only traces the first one; it does not cover 2 or 3. This is a clear differentiation point for ACI.

## Critical fact 5: AddOn metadata API

```lua
local manager = GetAddOnManager()
local numAddons = manager:GetNumAddOns()

for i = 1, numAddons do
    -- Signature confirmed
    local name, title, author, description, enabled, state, isOutOfDate, isLibrary
        = manager:GetAddOnInfo(i)

    local version = manager:GetAddOnVersion(i)
    local rootPath = manager:GetAddOnRootDirectoryPath(i)
    local numDeps = manager:GetAddOnNumDependencies(i)
    -- GetAddOnDependencyInfo(addOnIndex, depIndex) likely exists as well
end

-- Enums such as ADDON_STATE_ENABLED also exist
```

These are all unprotected public APIs. We can read this information freely.

## Critical fact 6: A memory measurement function is exposed

```lua
local totalMB = GetTotalUserAddOnMemoryPoolUsageMB()
```

Console addons **share a 100 MB memory pool**, and there is also a 1-second execution-time budget per frame. This is critical information for console users. It is also useful for memory leak debugging on PC. `collectgarbage()` can be called as well, which means we can estimate addon impact indirectly by measuring memory before and after forced GC.

## Critical fact 7: Full set of manifest directives

Directives available in an addon manifest (`.txt` or `.addon`):

- `## Title:` - display name
- `## Author:`
- `## Version:` - human-facing version string
- `## APIVersion:` - ESO API version (for example `101049`)
- `## AddOnVersion:` - integer used for duplicate folder handling
- `## IsLibrary:` - true / false
- `## DependsOn:` - hard dependency (won't load without it)
- `## OptionalDependsOn:` - soft dependency (affects sort only)
- `## SavedVariables:` - SV global variable names (space-separated)
- `## SavedVariablesPerCharacter:`
- `## Description:`

Important: ACI cannot read the manifest file directly, because the `io` module is removed. **We can only access it through APIs such as `GetAddOnInfo` / `GetAddOnNumDependencies`.** That means we may not have a direct way to read the `## SavedVariables:` field -> SV collision detection may require a different strategy. **This must be verified in the PoC.**

# ACI Design

## Core value

> When an ESO player with many addons runs into low FPS, conflicts, or unknown errors, ACI helps narrow down the likely cause quickly and generates a shareable environment report with a single click for guild or forum troubleshooting.

## Target users, more concretely

**Primary**: Regular PC users with 15 to 50 addons installed. They are willing to troubleshoot, but they do not know Lua.

**Secondary**: Guild members who act as the "addon help" person and need to diagnose other players' setups.

**Tertiary**: Console users, who urgently need to know what is eating memory because of the 100 MB limit.

**Non-target**: Addon authors. ESOProfiler and Zgoo are better tools for them.

## Phased roadmap

### Phase 0 - Spike / PoC (1 week)

**Goal: validate three core hypotheses**

1. Does the `ZZZ_` folder-name trick really make us load before other addons?
2. Does `ZO_PreHook(EVENT_MANAGER, "RegisterForEvent", ...)` work?
3. Is there any way at all to read the `## SavedVariables:` field? If not, SV collision detection drops out of scope

**Deliverable**: A single 100-200 line Lua file. Dump the list of intercepted `RegisterForEvent` calls into SavedVariables. After `/reloadui`, open the SV file and inspect it.

### Phase 1 - Static Inventory (1-2 weeks)

**Goal: provide a clearly better "my addon dashboard" than the default ZOS UI, using static information only**

- Full list of installed addons + metadata (name, version, author, API version, enabled, isLibrary, isOutOfDate)
- API version mismatch warnings
- Dependency tree visualization (what each addon depends on, and what depends on it)
- Library usage statistics ("23 addons use LibAddonMenu-2.0")
- Search / filter (name, author, category)
- Click-through link to the [ESOUI.com](http://ESOUI.com) page

**Dependencies**: probably `LibAddonMenu-2.0` for settings UI and `LibCustomMenu` for context menus. Keep library usage minimal.

### Phase 2 - Runtime Inspection (2-3 weeks)

**Goal: add dynamic tracing features**

- Global namespace pollution inspection: take one `_G` snapshot right after reloadui and another after `PLAYER_ACTIVATED`, then diff them to track "which globals each addon created"
- Warn when the same global name is defined by two places
- Intercept event registration with `ZO_PreHook`: track `RegisterForEvent`, `control:RegisterForEvent`, and `CALLBACK_MANAGER`
- Flag hot paths when 5+ handlers are registered to the same event
- Show reverse trace information for "who registered this event"

**Important limit**: Even if we load first using the `ZZZ_` trick, **ZOS native code will still register its own handlers before us**. So our stats will miss ZOS-native handlers. This should be stated honestly as "ZOS native handlers: not tracked."

### Phase 3 - Performance Diagnostics (2-3 weeks)

**Goal: help narrow down performance issues**

- Time-series graph of `GetTotalUserAddOnMemoryPoolUsageMB()`
- `/reloadui` time breakdown: estimate each addon's init time from deltas between `EVENT_ADD_ON_LOADED` timestamps
- A/B mode: automate "disable this addon -> measure FPS for 1 minute -> enable it -> measure FPS for 1 minute" (with two user-requested reloads)
- Memory leak suspicion: warn if `GetTotalUserAddOnMemoryPoolUsageMB()` trends upward monotonically over time
- **Special console warning**: notify when usage reaches 80% of the 100 MB budget

**Important limit**: We are not doing precise per-function timing. ESOProfiler already does that much better. Our job is only to narrow down which addon looks suspicious.

### Phase 4 - Diagnostic Reports (1-2 weeks)

**Goal: reduce friction when asking for troubleshooting help in guilds or forums**

- "Generate environment report" button: dump the following into SavedVariables with one click
  - Addon list + versions + enabled state
  - Dependency tree
  - API mismatch list
  - Global conflicts / event hot-path findings
  - Memory usage
  - Recent LibDebugLogger error logs, if available
- Guide the user to paste the SV contents into the clipboard / Pastebin / GitHub Gist
- **Direct in-game transmission is impossible** because networking is blocked. Ship an external helper script (Python) that converts the SV file into clean Markdown -> host a web converter on the RICCILAB domain
- Automatic estimation mode (late Phase 4): inspect recent error logs and estimate "this error is likely caused by addon X with Y% confidence"

# Risks & Responses

## R1: No access to SavedVariables manifest fields

- **Probability**: Medium
- **Impact**: SV collision detection feature may be lost
- **Response**: Validate this quickly in the PoC. If the GetAddOn APIs do not expose the SV field, use a heuristic workaround: track globals created by each addon that look like persisted tables registered through SavedVariables directives

## R2: The `ZZZ_` trick does not work 100%

- **Probability**: Low
- **Impact**: Some libraries (for example LibStub successors) may still load earlier
- **Response**: Be honest and show them under a section like "these addons registered before ACI loaded." Do not promise 100% trace coverage

## R3: People think it duplicates ESOProfiler

- **Probability**: Medium
- **Impact**: Users conclude "there is no need for ACI because ESOProfiler already exists"
- **Response**: Separate the positioning clearly. **ESOProfiler is for authors optimizing code; ACI is for users trying to understand what is wrong with their setup.** The first-screen UX should reflect that difference - ESOProfiler starts with call-stack trees, ACI starts with "my addon list."

## R4: Risk of breaking on each API patch

- **Probability**: Medium
- **Impact**: Maintenance required every major patch
- **Response**: The API surface we depend on is small (`GetAddOnInfo` family + `ZO_PreHook`), and both are stable official ZOS patterns, so the breakage risk is relatively low

## R5: Regular users may not understand the diagnostics

- **Probability**: High
- **Impact**: They see a term like "namespace pollution" and immediately close the tool
- **Response**: Split the UX into two modes - `Simple` (red / yellow / green lights + one-line explanations) and `Expert` (raw data). Default to `Simple`.

# Differentiation Matrix

| Feature | ESOProfiler | Zgoo | Default ZOS UI | **ACI** |
| --- | --- | --- | --- | --- |
| Function execution-time profiling | ✅ Strong | ❌ | ❌ | ❌ (not doing this) |
| Live variable inspection | ❌ | ✅ Strong | ❌ | ❌ (not doing this) |
| Addon list + metadata | ❌ | ❌ | ⚠️ Weak | ✅ Strong |
| Dependency graph | ❌ | ❌ | ⚠️ Text only | ✅ Visualized |
| API mismatch warnings | ❌ | ❌ | ⚠️ "out of date" only | ✅ Detailed |
| Namespace collision detection | ❌ | ❌ | ❌ | ✅ |
| Event hot-path detection | ⚠️ Timing only | ⚠️ Live tracing only | ❌ | ✅ |
| Memory tracking (console budget) | ⚠️ Generic | ❌ | ❌ | ✅ Console-focused |
| Environment report export | ❌ | ❌ | ❌ | ✅ Core feature |
| UX for regular users | ❌ Developer-facing | ❌ Developer-facing | ⚠️ Weak | ✅ Core value |

# Next Actions

## Immediate (this week)

- [ ] Write the PoC code (Phase 0)
  - [ ] Create the `ZZZ_AddOnInspector` folder
  - [ ] Create the manifest (`.addon` recommended for PC / console compatibility)
  - [ ] Install a `ZO_PreHook` on `EVENT_MANAGER:RegisterForEvent`
  - [ ] Dump intercepted calls into SavedVariables with timestamps
  - [ ] Inspect the SV file after `/reloadui`
- [ ] Record the validation results for all three hypotheses

## Next (if the PoC passes)

- [ ] Create the GitHub repo (`baeghyeon-hub/eso-aci`)
- [ ] Set up the CI pipeline (automatic addon zip build first, ESOUI upload automation later)
- [ ] Evaluate adopting LibDebugLogger as a dependency
- [ ] Design the Phase 1 data model

## Later (Phase 2+)

- [ ] Integrate LibAddonMenu-2.0
- [ ] Build the external conversion tool (Python, hosted on the RICCILAB domain)
- [ ] Add Korean / English / German / French localization

# Appendix: Core Code Snippets

## Manifest example (`ZZZ_AddOnInspector.addon`)

```
## Title: AddOn Conflict Inspector
## Author: Ricci Curvature
## APIVersion: 101049 101050
## AddOnVersion: 1
## Version: 0.0.1-poc
## IsLibrary: false
## SavedVariables: ACI_SavedVars
## OptionalDependsOn: LibDebugLogger
## Description: Diagnose addon conflicts, performance issues, and conflicts.

ACI_Main.lua
```

## Core PoC code

```lua
ACI = {}
ACI.name = "ZZZ_AddOnInspector"
ACI.eventLog = {}

local function OnAddOnLoaded(eventCode, addonName)
    if addonName ~= ACI.name then return end
    EVENT_MANAGER:UnregisterForEvent(ACI.name, EVENT_ADD_ON_LOADED)

    -- SavedVariables init
    ACI_SavedVars = ACI_SavedVars or {}
    ACI_SavedVars.eventLog = {}

    -- Hypothesis validation: intercept RegisterForEvent with ZO_PreHook
    ZO_PreHook(EVENT_MANAGER, "RegisterForEvent", function(self, namespace, eventCode, callback, ...)
        table.insert(ACI_SavedVars.eventLog, {
            ts = GetGameTimeMilliseconds(),
            namespace = namespace,
            eventCode = eventCode,
            -- callback is a function and cannot be serialized, so store only its address string
            callbackStr = tostring(callback),
        })
        -- false/nil -> original call proceeds normally
    end)

    d("[ACI] PoC loaded. ZO_PreHook installed on EVENT_MANAGER:RegisterForEvent")
end

EVENT_MANAGER:RegisterForEvent(ACI.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
```

After validation, opening the SavedVariables file should show the event registrations from other addons inside the `eventLog` table. If it is almost empty, then either the `ZZZ_` trick failed or the `ZO_PreHook` failed. If it is full, then the **core hypothesis passes and candidate 3 is a go**.

# References

- [ESOUI Wiki - ZO_PreHook](https://wiki.esoui.com/ZO_PreHook)
- [ESOUI Wiki - Addon Structure](https://wiki.esoui.com/Addon_Structure)
- [ESOUI Wiki - Addon manifest format](https://wiki.esoui.com/Addon_manifest_(.txt)_format)
- [ESOUI Wiki - Esolua](https://wiki.esoui.com/Esolua)
- [ESOUI Wiki - How to update for console](https://wiki.esoui.com/How_to_update_your_addon_for_console)
- [esoui/esoui GitHub mirror](https://github.com/esoui/esoui) (live mirror currently reflected up to API 101048)
- [ESOProfiler](https://www.esoui.com/downloads/info2166-ESOProfiler.html)
- [Zgoo](https://www.esoui.com/downloads/info24-Zgoo-datainspectiontool.html)
- [LibDebugLogger](https://www.esoui.com/downloads/info2275-LibDebugLogger.html)
