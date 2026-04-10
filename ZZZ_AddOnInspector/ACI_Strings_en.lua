----------------------------------------------------------------------
-- ACI_Strings_en.lua — default English string table
--
-- All user-facing strings live here keyed by uppercase identifier.
-- ACI_Strings_kr.lua (loaded after this file) overrides individual keys
-- when the user is on a Korean client. Missing keys fall back to the
-- key string itself via ACI.L(), making typos immediately visible.
--
-- Naming convention:
--   PLAIN_KEY  = literal string used as-is via ACI.L("PLAIN_KEY")
--   FMT_KEY    = format template used via string.format(ACI.L("FMT_KEY"), ...)
----------------------------------------------------------------------

-- Self-guard: ACI may not exist yet if manifest order is changed.
ACI = ACI or {}
ACI.S = ACI.S or {}

local S = ACI.S

----------------------------------------------------------------------
-- Common
----------------------------------------------------------------------
S.SEPARATOR        = "--------------------------------------------"
S.NO_METADATA      = "[ACI] No metadata."
S.NO_METADATA_PA   = "[ACI] No metadata. Use after PLAYER_ACTIVATED."
S.FMT_MORE         = "[ACI]   ... +%d more"
S.FMT_UNKNOWN_CMD  = "[ACI] Unknown command: %s"

----------------------------------------------------------------------
-- /aci — summary report
----------------------------------------------------------------------
S.REPORT_TITLE     = "[ACI] Addon Environment Report (live)"
S.FMT_REPORT_API   = " (API %s)"
S.FMT_REPORT_OOD   = "  |cFFFF00%d out-of-date|r"
S.FMT_REPORT_LOADED  = "[ACI] Loaded: %d addons%s, ACI=#%s%s"
S.FMT_REPORT_EVENTS  = "[ACI] Events: |c00FF00%d|r registrations, %d clusters"
S.FMT_REPORT_CLUSTER = "[ACI]   %s%s"
S.FMT_REPORT_SV      = "[ACI] SV: %d registrations, %d conflicts"
S.REPORT_HELP_HINT   = "[ACI] Type /aci help for all commands"

----------------------------------------------------------------------
-- /aci stats
----------------------------------------------------------------------
S.FMT_STATS_TITLE  = "[ACI] Event Registration Stats — %d total (live)"
S.FMT_SUB_NS       = " [%d sub-ns]"

----------------------------------------------------------------------
-- /aci addons
----------------------------------------------------------------------
S.FMT_ADDONS_TITLE     = "[ACI] Addon List — %d total (enabled %d, disabled %d)"
S.FMT_ADDONS_OOD       = "[ACI] |cFFFF00Out-of-date: %d|r"
S.FMT_ADDONS_HEADER    = "[ACI] |c00FF00Addons (%d)|r"
S.FMT_LIBS_HEADER      = "[ACI] |c8888FF Libraries (%d)|r"
S.FMT_ADDON_ENTRY      = "[ACI] %s%s  v%s"

----------------------------------------------------------------------
-- /aci sv
----------------------------------------------------------------------
S.FMT_SV_HEADER         = "[ACI] SavedVariables — %d registrations, %d unique pairs"
S.FMT_SV_ENTRY          = "[ACI]   %s <- %s"
S.FMT_SV_CONFLICT_HEAD  = "[ACI] |cFF0000Conflicts: %d|r"
S.FMT_SV_CONFLICT_LINE  = "[ACI]   %s <- %s"
S.SV_NO_CONFLICTS       = "[ACI]   No conflicts"
S.FMT_SV_DISK_TITLE     = "[ACI] SV Disk Usage — %.2f MB total across %d addons"
S.FMT_SV_DISK_ENTRY     = "[ACI]   %s%s  %s|r%s"
S.SV_TAG_REVIEW         = " |cFFFF00[review]|r"
S.SV_TAG_UNUSED         = " |cAAAAAA[unused]|r"
S.FMT_SV_TAG_DEPS       = " |c00FF00[%d deps]|r"

----------------------------------------------------------------------
-- /aci init
----------------------------------------------------------------------
S.INIT_TITLE       = "[ACI] Addon Init Time Estimation (top 10)"
S.FMT_INIT_ENTRY   = "  %5dms  load#%d %s|r"

----------------------------------------------------------------------
-- /aci deps [name]
----------------------------------------------------------------------
S.FMT_DEPS_NOT_FOUND   = "[ACI] '%s' not found."
S.LABEL_LIBRARY        = " |c8888FF[Library]|r"
S.FMT_DEPS_NEEDS       = "[ACI] Dependencies (needs): %d"
S.FMT_DEPS_REVERSE     = "[ACI] Reverse deps (used by): %d"
S.DEP_OK               = "|c00FF00OK|r"
S.DEP_OFF              = "|cFF0000OFF|r"
S.DEP_MISSING          = "|cFF0000MISSING|r"
S.DEPS_SUMMARY_TITLE   = "[ACI] Dependency Summary — most depended-on libraries"
S.FMT_DEPS_DEPENDENT   = "[ACI]   %3d dependents  %s"
S.FMT_DEPS_NO_DEPS     = "[ACI] Addons with no dependencies: %d"

----------------------------------------------------------------------
-- /aci orphans
----------------------------------------------------------------------
S.ORPHANS_TITLE        = "[ACI] Library Analysis"
S.FMT_ORPHANS_HEADER   = "[ACI] |cFFFF00Unused libraries (%d)|r — no enabled addon depends on these:"
S.ORPHANS_NONE         = "[ACI] |c00FF00No unused libraries|r"
S.DEFACTO_HEADER       = "[ACI] |c8888FFDe-facto libraries|r — not flagged as library but multiple addons depend on:"
S.FMT_DEFACTO_ENTRY    = "[ACI]   %s (%d dependents)"
S.FMT_HINT_CASE        = "|cFF6600<- case mismatch? %s|r"
S.FMT_HINT_VERSION     = "|cFF6600<- version mismatch? %s|r"
S.FMT_HINT_TYPO        = "|cFFFF00<- typo? %s|r"

----------------------------------------------------------------------
-- /aci missing
----------------------------------------------------------------------
S.MISSING_TITLE             = "[ACI] Missing Dependencies"
S.MISSING_NONE              = "[ACI] |c00FF00No missing dependencies|r"
S.FMT_MISSING_HEADER        = "[ACI] |cFFFF00%d dep(s) declared but not installed:|r"
S.FMT_MISSING_ENTRY         = "[ACI]   %s (%d addon(s) need this)"
S.FMT_MISSING_HINT_CASE     = "[ACI] |cFF6600  -> case mismatch: %s is installed|r"
S.FMT_MISSING_HINT_VERSION  = "[ACI] |cFF6600  -> version mismatch: %s is installed|r"
S.FMT_MISSING_HINT_TYPO     = "[ACI] |cFFFF00  -> typo? %s is installed|r"
S.FMT_MISSING_USER          = "[ACI]     <- %s"

----------------------------------------------------------------------
-- /aci hot
----------------------------------------------------------------------
S.HOT_TITLE_BY_ADDONS  = "top 10 by addon count"
S.HOT_TITLE_BY_REGS    = "top 10 by registration count"
S.FMT_HOT_TITLE        = "[ACI] Event Hot Paths — %s"
S.HOT_DISCLAIMER       = "|cAAAAAA(registration count, not firing frequency. CPU impact requires profiling.)|r"
S.HOT_NONE             = "[ACI] No hot paths"
S.FMT_HOT_EVENT        = "  %d addons, %d regs  %s|r"
S.FMT_TAG_CROSS_HEAVY  = "  |cFF6600[cross-hot:%d] heavy|r"
S.FMT_TAG_CROSS        = "  |cFFFF00[cross-hot:%d]|r"

----------------------------------------------------------------------
-- /aci ood
----------------------------------------------------------------------
S.OOD_TITLE                = "[ACI] Out-of-Date Breakdown"
S.FMT_OOD_RATIO            = "[ACI] %d/%d top-level (%d%%)"
S.FMT_OOD_STANDALONE_HEAD  = "[ACI] |cFFFF00Standalone addons (%d)|r — update recommended:"
S.OOD_STANDALONE_NONE      = "[ACI] |c00FF00No standalone addons out-of-date|r"
S.FMT_OOD_LIBONLY_HEAD     = "[ACI] |cCCCCCCLibraries (%d)|r — author outdated, usually harmless:"
S.FMT_LIB_DEPENDENTS       = " |c888888(%d dependents)|r"
S.OOD_LIBONLY_NONE         = "[ACI] |c00FF00No libraries out-of-date|r"
S.FMT_OOD_EMBEDDED_HEAD    = "[ACI] |c666666Embedded (%d)|r — bundled sub-addons, ignore:"
S.OOD_EMBEDDED_NONE        = "[ACI] |c00FF00No embedded sub-addons out-of-date|r"

----------------------------------------------------------------------
-- /aci health
----------------------------------------------------------------------
S.HEALTH_LABEL_RED         = "Issues Found"
S.HEALTH_LABEL_YELLOW      = "Warning"
S.HEALTH_LABEL_GREEN       = "Healthy"
S.FMT_HEALTH_HEADER        = "[ACI] %s● %s|r"
S.FMT_HEALTH_OOD           = "[ACI] Out-of-date: %d/%d top-level (%d%%)"
S.FMT_HEALTH_IGNORABLE     = "[ACI]   |cCCCCCCIgnorable: %d libraries + %d embedded|r"
S.FMT_HEALTH_ATTENTION     = "[ACI]   |cFFFF00Attention: %d standalone addon(s)|r"
S.FMT_HEALTH_NAMES         = "[ACI]     %s%s"
S.FMT_HEALTH_NAMES_MORE    = " +%d more"
S.HEALTH_CTX_MAJOR         = "Major patch or long-neglected"
S.HEALTH_CTX_PATCH         = "Normal after patch (1-2 months)"
S.HEALTH_CTX_NORMAL        = "Normal"
S.HEALTH_CTX_WELL          = "Well maintained"
S.FMT_HEALTH_CTX           = "[ACI]   -> %s"
S.HEALTH_FULL_BREAKDOWN    = "[ACI]   Full breakdown: /aci ood"
S.FMT_HEALTH_ISSUE         = "[ACI] %s●|r %s"
S.FMT_REVIEW_CAND_SIZE_HINT  = " — %.1f KB disk use"
S.FMT_REVIEW_CAND_HEADER     = "[ACI] |cCCCCCC● Review candidates (%d)|r — libraries: inactive, author outdated, no references found:%s"
S.FMT_REVIEW_CAND_ENTRY      = "[ACI]   %s%s"
S.FMT_REVIEW_CAND_SIZE_MB    = " |c888888(%.2f MB)|r"
S.FMT_REVIEW_CAND_SIZE_KB    = " |c888888(%.1f KB)|r"
S.REVIEW_CAND_WARNING        = "[ACI]   |cFFAA00! Manifest-level only. ESO's Lua API cannot see runtime dependencies (OptionalDependsOn, global-function use). Verify in Minion or the addon's own docs before removing anything.|r"
S.REVIEW_CAND_NOTE           = "[ACI]   |cCCCCCC^ These may still be in use. Do not delete blindly.|r"
S.FMT_HEALTH_ISSUE_SV_CONFLICTS  = "%d SV conflict(s)"
S.FMT_HEALTH_ISSUE_OOD           = "%d/%d out-of-date (%d%%)"
S.FMT_HEALTH_ISSUE_MISSING       = "%d missing dep(s)"
S.FMT_HEALTH_ISSUE_MISSING_HINTS = "%d missing dep(s) (%d with hints)"
S.FMT_HEALTH_ISSUE_ORPHANS       = "%d unused libraries"
S.FMT_HEALTH_ISSUE_BIG_SV        = "%s uses %.0f%% of SV disk (%.2f MB / %.2f MB)"
S.FMT_HEALTH_EVENTS        = "[ACI] Events: %d, hot paths %d"
S.HEALTH_DETAILS           = "[ACI] Details: /aci orphans | /aci missing | /aci ood | /aci sv"

----------------------------------------------------------------------
-- /aci debug
----------------------------------------------------------------------
S.DEBUG_TITLE          = "[ACI] Debug — embedded status"
S.FMT_DEBUG_EMB_LINE   = "[ACI]   EMB  %s  <-  %s"
S.FMT_DEBUG_EMB_TOTAL  = "[ACI] embedded: %d / %s enabled"

----------------------------------------------------------------------
-- /aci dump
----------------------------------------------------------------------
S.DUMP_SAVED       = "[ACI] Dump saved. Check [\"dump\"] block in SV file after /reloadui."

----------------------------------------------------------------------
-- /aci save
----------------------------------------------------------------------
S.SAVE_REQUESTED       = "[ACI] SV priority save requested."
S.SAVE_NOT_AVAILABLE   = "[ACI] Not available. Use /reloadui to save."

----------------------------------------------------------------------
-- /aci help
----------------------------------------------------------------------
S.HELP_TITLE       = "[ACI] Commands"
S.HELP_REPORT      = "[ACI]   /aci          summary report"
S.HELP_STATS       = "[ACI]   /aci stats    event registration stats"
S.HELP_ADDONS      = "[ACI]   /aci addons   addon list"
S.HELP_DEPS        = "[ACI]   /aci deps     most-used libraries"
S.HELP_DEPS_X      = "[ACI]   /aci deps X   forward/reverse deps for X"
S.HELP_INIT        = "[ACI]   /aci init     init time estimation (top 10)"
S.HELP_ORPHANS     = "[ACI]   /aci orphans  unused libraries + de-facto"
S.HELP_MISSING     = "[ACI]   /aci missing  missing dependencies + hints"
S.HELP_OOD         = "[ACI]   /aci ood      out-of-date breakdown"
S.HELP_HOT         = "[ACI]   /aci hot      event hot paths (by addon count)"
S.HELP_HOT_REGS    = "[ACI]   /aci hot regs hot paths sorted by registration count"
S.HELP_HEALTH      = "[ACI]   /aci health   environment diagnosis"
S.HELP_SV          = "[ACI]   /aci sv       SV registrations + conflicts"
S.HELP_SAVE        = "[ACI]   /aci save     force SV save"
S.HELP_HELP        = "[ACI]   /aci help     this help"

----------------------------------------------------------------------
-- ACI_Core.lua boot messages
----------------------------------------------------------------------
S.BOOT_USE_HINT    = "[ACI] Type |c00FF00/aci|r for latest stats."
S.FMT_BOOT_LOADED  = "[ACI] v%s loaded. Hooks: Event=%s, SV=%s"
