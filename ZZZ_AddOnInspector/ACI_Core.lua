----------------------------------------------------------------------
-- ACI_Core.lua — global table, SV init, event lifecycle
----------------------------------------------------------------------

ACI = ACI or {}
ACI.name = "ZZZ_AddOnInspector"
ACI.version = "0.2.0"
ACI.eventLog = {}
ACI.svRegistrations = {}
ACI.loadOrder = {}
ACI.loadOrderMap = {}   -- addonName -> loadIndex (reverse lookup)
ACI.lastLoadedAddon = nil
ACI.hookInstalled = false
ACI.svHookInstalled = false

----------------------------------------------------------------------
-- Load order tracking (registered at file load time)
----------------------------------------------------------------------
local loadIndex = 0

local function OnAnyAddOnLoaded(eventCode, addonName)
    loadIndex = loadIndex + 1
    ACI.lastLoadedAddon = addonName
    ACI.loadOrderMap[addonName] = loadIndex
    table.insert(ACI.loadOrder, {
        index = loadIndex,
        addon = addonName,
        ts    = GetGameTimeMilliseconds(),
    })
end

EVENT_MANAGER:RegisterForEvent(ACI.name .. "_LoadOrder", EVENT_ADD_ON_LOADED, OnAnyAddOnLoaded)

----------------------------------------------------------------------
-- Utilities
----------------------------------------------------------------------

-- Check if namespace belongs to ACI (for self-filter)
function ACI.IsSelfNamespace(ns)
    return ns and ns:find(ACI.name, 1, true) ~= nil
end

function ACI.TableLength(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

----------------------------------------------------------------------
-- Localization lookup. ACI.S is populated by ACI_Strings_en.lua and
-- optionally overridden per-key by ACI_Strings_kr.lua (which self-checks
-- for Korean clients via TamrielKR or raw GetCVar). Missing keys fall
-- back to the key string itself, so a typo is immediately visible.
----------------------------------------------------------------------
ACI.S = ACI.S or {}
function ACI.L(key)
    return ACI.S[key] or key
end

function ACI.EnumerateMethods(obj)
    local methods = {}
    local mt = getmetatable(obj)
    if mt and mt.__index then
        for k, v in pairs(mt.__index) do
            if type(v) == "function" then
                table.insert(methods, k)
            end
        end
    end
    if type(obj) == "table" then
        for k, v in pairs(obj) do
            if type(v) == "function" then
                table.insert(methods, k)
            end
        end
    end
    table.sort(methods)
    return methods
end

----------------------------------------------------------------------
-- eventCode -> name mapping (collect EVENT_ prefixed globals)
-- Wrapped in pcall: pairs(_G) can crash on ESO protected globals
----------------------------------------------------------------------
-- Known EVENT_* names probed via rawget. ESO has a protected global at the
-- 4th _G iteration position that kills pairs(_G), even with per-step pcall —
-- so we cannot enumerate. Instead, probe a hardcoded list of well-known event
-- names with pcall(rawget) which bypasses metamethods entirely.
ACI.knownEventNames = {
    "EVENT_ADD_ON_LOADED","EVENT_PLAYER_ACTIVATED","EVENT_PLAYER_DEACTIVATED",
    "EVENT_PLAYER_DEAD","EVENT_PLAYER_ALIVE","EVENT_PLAYER_REINCARNATED",
    "EVENT_PLAYER_COMBAT_STATE","EVENT_PLAYER_STUNNED_STATE_CHANGED",
    "EVENT_PLAYER_SWAP_HAND_VISUAL","EVENT_PLAYER_TELEPORTED_TO_LOCATION",
    "EVENT_COMBAT_EVENT","EVENT_BOSSES_CHANGED","EVENT_TARGET_CHANGE",
    "EVENT_RETICLE_TARGET_CHANGED","EVENT_RETICLE_HIDDEN_UPDATE",
    "EVENT_WEAPON_PAIR_CHANGED","EVENT_ACTIVE_WEAPON_PAIR_CHANGED",
    "EVENT_POWER_UPDATE","EVENT_ATTRIBUTE_FORCE_REBUILD","EVENT_LEVEL_UPDATE",
    "EVENT_EXPERIENCE_UPDATE","EVENT_CHAMPION_LEVEL_ACHIEVED",
    "EVENT_CHAMPION_POINT_GAINED","EVENT_CHAMPION_POINTS_GAINED",
    "EVENT_UNIT_CREATED","EVENT_UNIT_DESTROYED","EVENT_UNIT_DEATH_STATE_CHANGED",
    "EVENT_UNIT_FRAME_UPDATE","EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED",
    "EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED","EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED",
    "EVENT_LEADER_UPDATE","EVENT_GROUP_MEMBER_JOINED","EVENT_GROUP_MEMBER_LEFT",
    "EVENT_GROUP_UPDATE","EVENT_GROUP_INVITE_RECEIVED","EVENT_GROUP_INVITE_REMOVED",
    "EVENT_GROUP_TYPE_CHANGED","EVENT_GROUP_MEMBER_CONNECTED_STATUS",
    "EVENT_GROUP_MEMBER_ROLE_CHANGED","EVENT_GROUPING_TOOLS_NO_LONGER_LFG",
    "EVENT_INVENTORY_FULL_UPDATE","EVENT_INVENTORY_SINGLE_SLOT_UPDATE",
    "EVENT_INVENTORY_ITEM_USED","EVENT_BAG_CAPACITY_CHANGED",
    "EVENT_BUYBACK_RECEIPT","EVENT_OPEN_STORE","EVENT_CLOSE_STORE",
    "EVENT_OPEN_BANK","EVENT_CLOSE_BANK","EVENT_OPEN_GUILD_BANK","EVENT_CLOSE_GUILD_BANK",
    "EVENT_OPEN_TRADING_HOUSE","EVENT_CLOSE_TRADING_HOUSE","EVENT_OPEN_FENCE","EVENT_CLOSE_FENCE",
    "EVENT_ABILITY_LIST_CHANGED","EVENT_SKILL_LINE_ADDED","EVENT_SKILL_LINE_LEVELED_UP",
    "EVENT_SKILL_LINE_RANK_UPDATE","EVENT_SKILL_XP_UPDATE",
    "EVENT_SKILL_BUILD_SELECTION_UPDATED","EVENT_SKILLS_FULL_UPDATE",
    "EVENT_ACTION_SLOTS_FULL_UPDATE","EVENT_ACTION_SLOT_UPDATED",
    "EVENT_ACTION_SLOT_ABILITY_USED","EVENT_ACTION_BAR_IS_RESPECABLE",
    "EVENT_ACTIVE_SOUL_GEM_TYPE_CHANGED","EVENT_ATTRIBUTE_UPGRADE_UPDATED",
    "EVENT_QUEST_ADDED","EVENT_QUEST_REMOVED","EVENT_QUEST_COMPLETE",
    "EVENT_QUEST_LIST_UPDATED","EVENT_QUEST_ADVANCED",
    "EVENT_QUEST_CONDITION_COUNTER_CHANGED","EVENT_QUEST_OFFERED",
    "EVENT_QUEST_OPTIONAL_STEP_ADVANCED","EVENT_QUEST_OBJECTIVES_UPDATED",
    "EVENT_QUEST_OBJECTIVE_COMPLETED","EVENT_QUEST_TIMER_UPDATED",
    "EVENT_ZONE_CHANGED","EVENT_ZONE_UPDATE","EVENT_MAP_PING",
    "EVENT_LOCATION_DISCOVERED","EVENT_POI_DISCOVERED","EVENT_POI_UPDATED",
    "EVENT_CHAT_MESSAGE_CHANNEL","EVENT_FRIEND_ADDED","EVENT_FRIEND_REMOVED",
    "EVENT_FRIEND_PLAYER_STATUS_CHANGED","EVENT_INCOMING_FRIEND_INVITE_ADDED",
    "EVENT_INCOMING_FRIEND_INVITE_REMOVED","EVENT_GUILD_SELF_JOINED_GUILD",
    "EVENT_GUILD_SELF_LEFT_GUILD","EVENT_EFFECT_CHANGED","EVENT_EFFECTS_FULL_UPDATE",
    "EVENT_ARTIFICIAL_EFFECT_ADDED","EVENT_ARTIFICIAL_EFFECT_REMOVED",
    "EVENT_MOUNT_INFO_UPDATED","EVENT_MOUNTED_STATE_CHANGED",
    "EVENT_CRAFT_STARTED","EVENT_CRAFT_COMPLETED",
    "EVENT_CRAFTING_STATION_INTERACT","EVENT_END_CRAFTING_STATION_INTERACT",
    "EVENT_RAID_TRIAL_STARTED","EVENT_RAID_TRIAL_COMPLETE","EVENT_RAID_TRIAL_FAILED",
    "EVENT_ACHIEVEMENT_AWARDED","EVENT_ACHIEVEMENT_UPDATED",
    "EVENT_END_FAST_TRAVEL_INTERACTION","EVENT_BEGIN_FAST_TRAVEL_INTERACTION",
    "EVENT_LOCKPICK_BROKE","EVENT_LOCKPICK_FAILED","EVENT_LOCKPICK_SUCCESS",
    "EVENT_INTERACT_BUSY","EVENT_INTERACTION_INTERCEPTED",
    "EVENT_LOOT_RECEIVED","EVENT_LOOT_UPDATED","EVENT_LOOT_CLOSED","EVENT_LOOT_ITEM_FAILED",
    "EVENT_INTERFACE_SETTING_CHANGED","EVENT_KEYBINDING_SET","EVENT_KEYBINDING_CLEARED",
    "EVENT_GAMEPAD_PREFERRED_MODE_CHANGED","EVENT_SCREEN_RESIZED",
    "EVENT_NEW_MOVEMENT_IN_UI_MODE","EVENT_GLOBAL_MOUSE_DOWN","EVENT_GLOBAL_MOUSE_UP",
    "EVENT_DISGUISE_STATE_CHANGED","EVENT_STEALTH_STATE_CHANGED",
    "EVENT_HOTBAR_SLOT_STATE_UPDATED","EVENT_HOTBAR_PAYMENT_REQUIREMENT_CHANGED",
    "EVENT_HOTBAR_IS_VISIBLE_UPDATE","EVENT_INVENTORY_BOUGHT_BOUNCED_MAIL",
    "EVENT_LFG_FIND_REPLACEMENT_NOTIFICATION_NEW","EVENT_LFG_LOCK_UPDATE",
    "EVENT_LFG_UPDATE_NOTIFICATION_REMOVED","EVENT_GROUP_MEMBER_IN_REMOTE_REGION",
}

-- Build (or extend) eventCode -> name map via rawget probes.
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

ACI.eventNames = {}

-- Attempt #1: file-load time (earliest possible)
ACI.BuildEventNameMap(ACI.eventNames)

function ACI.EventName(code)
    if not next(ACI.eventNames) then
        ACI.BuildEventNameMap(ACI.eventNames)
    end
    return ACI.eventNames[code] or tostring(code)
end

----------------------------------------------------------------------
-- Main initialization
----------------------------------------------------------------------
local function OnACILoaded(eventCode, addonName)
    if addonName ~= ACI.name then return end
    EVENT_MANAGER:UnregisterForEvent(ACI.name, EVENT_ADD_ON_LOADED)

    ACI_SavedVars = ACI_SavedVars or {}

    -- Attempt #2: ADD_ON_LOADED time. Different timing → different partial coverage.
    ACI_SavedVars._eventNamesSize_load = ACI.TableLength(ACI.eventNames)
    ACI.BuildEventNameMap(ACI.eventNames)
    ACI_SavedVars._eventNamesSize_addon = ACI.TableLength(ACI.eventNames)

    -- Install hooks (ACI_Hooks.lua)
    ACI.InstallEventHook()
    ACI.svHookInstalled = ACI.InstallSVHooks()

    -- Store live references in SV
    ACI_SavedVars.eventLog        = ACI.eventLog
    ACI_SavedVars.svRegistrations = ACI.svRegistrations
    ACI_SavedVars.loadOrder       = ACI.loadOrder

    -- Register commands immediately (works regardless of PLAYER_ACTIVATED errors)
    ACI.RegisterCommands()

    -- PLAYER_ACTIVATED: collect static data + initial report
    EVENT_MANAGER:RegisterForEvent(ACI.name, EVENT_PLAYER_ACTIVATED, function()
        EVENT_MANAGER:UnregisterForEvent(ACI.name, EVENT_PLAYER_ACTIVATED)
        EVENT_MANAGER:UnregisterForEvent(ACI.name .. "_LoadOrder", EVENT_ADD_ON_LOADED)

        -- Attempt #3: PLAYER_ACTIVATED time (latest, most globals defined)
        ACI.BuildEventNameMap(ACI.eventNames)
        ACI_SavedVars._eventNamesSize = ACI.TableLength(ACI.eventNames)

        -- Collect metadata (ACI_Inventory.lua)
        ACI_SavedVars.metadata = ACI.CollectMetadata()
        ACI_SavedVars.svHookOk = ACI.svHookInstalled

        -- Delay report until chat UI is ready (zo_callLater)
        zo_callLater(function()
            ACI.PrintReport()
            d(ACI.L("BOOT_USE_HINT"))
        end, 1000)
    end)

    zo_callLater(function()
        d(string.format(ACI.L("FMT_BOOT_LOADED"),
            ACI.version,
            tostring(ACI.hookInstalled),
            tostring(ACI.svHookInstalled)
        ))
    end, 500)
end

EVENT_MANAGER:RegisterForEvent(ACI.name, EVENT_ADD_ON_LOADED, OnACILoaded)
