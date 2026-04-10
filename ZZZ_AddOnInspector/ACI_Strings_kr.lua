----------------------------------------------------------------------
-- ACI_Strings_kr.lua — Korean overrides
--
-- ESO does not officially support Korean (no kr in language.2 enum),
-- so $(language) cannot auto-load this file. It is loaded unconditionally
-- and self-checks before populating overrides.
--
-- Detection is 3-tiered because the "real" signal that a Korean user is
-- present is the TamrielKR community patch — not an ESO CVar:
--
--   1. TamrielKR:GetLanguage() == "kr"   — most accurate (current API)
--   2. TamrielKR global exists           — API may rename/move
--   3. GetCVar("language.2") == "kr"     — theoretical future-proofing
--
-- TamrielKR also hooks GetCVar("language.2") to return "en" so non-Korean
-- addons don't crash on missing kr.lua files. We bypass that by asking
-- TamrielKR directly.
----------------------------------------------------------------------

-- Self-guard: ACI may not exist yet if manifest order is changed.
ACI = ACI or {}
ACI.S = ACI.S or {}

local function IsKoreanClient()
    -- Tier 1: TamrielKR public API. If the API answers at all, trust it —
    -- whether the answer is "kr" or not. Only fall through if the API is
    -- unreachable (missing or throwing).
    if TamrielKR and TamrielKR.GetLanguage then
        local ok, lang = pcall(TamrielKR.GetLanguage, TamrielKR)
        if ok then return lang == "kr" end
        -- pcall failed: API exists but throws → fall through
    end
    -- Tier 2: TamrielKR present but API unusable (renamed/removed/throwing).
    -- Mere presence is still a strong signal of a Korean user.
    if _G["TamrielKR"] then
        return true
    end
    -- Tier 3: ESO CVar (currently dead path; future-proof)
    return GetCVar("language.2") == "kr"
end

if not IsKoreanClient() then return end

local S = ACI.S

----------------------------------------------------------------------
-- Common
----------------------------------------------------------------------
S.NO_METADATA      = "[ACI] 메타데이터 없음."
S.NO_METADATA_PA   = "[ACI] 메타데이터 없음. PLAYER_ACTIVATED 이후 사용하세요."
S.FMT_MORE         = "[ACI]   ... 외 %d개"
S.FMT_UNKNOWN_CMD  = "[ACI] 알 수 없는 명령어: %s"

----------------------------------------------------------------------
-- /aci — summary report
----------------------------------------------------------------------
S.REPORT_TITLE       = "[ACI] 애드온 환경 보고서 (live)"
S.FMT_REPORT_API     = " (API %s)"
S.FMT_REPORT_OOD     = "  |cFFFF00구버전 %d개|r"
S.FMT_REPORT_LOADED  = "[ACI] 로드됨: 애드온 %d개%s, ACI=#%s%s"
S.FMT_REPORT_EVENTS  = "[ACI] 이벤트: |c00FF00%d|r 등록, %d 클러스터"
S.FMT_REPORT_CLUSTER = "[ACI]   %s%s"
S.FMT_REPORT_SV      = "[ACI] SV: %d 등록, 충돌 %d건"
S.REPORT_HELP_HINT   = "[ACI] 모든 명령어는 /aci help 입력"

----------------------------------------------------------------------
-- /aci stats
----------------------------------------------------------------------
S.FMT_STATS_TITLE  = "[ACI] 이벤트 등록 통계 — 총 %d개 (live)"
S.FMT_SUB_NS       = " [하위 ns %d개]"

----------------------------------------------------------------------
-- /aci addons
----------------------------------------------------------------------
S.FMT_ADDONS_TITLE     = "[ACI] 애드온 목록 — 총 %d개 (활성 %d, 비활성 %d)"
S.FMT_ADDONS_OOD       = "[ACI] |cFFFF00구버전: %d개|r"
S.FMT_ADDONS_HEADER    = "[ACI] |c00FF00애드온 (%d)|r"
S.FMT_LIBS_HEADER      = "[ACI] |c8888FF 라이브러리 (%d)|r"
S.FMT_ADDON_ENTRY      = "[ACI] %s%s  v%s"

----------------------------------------------------------------------
-- /aci sv
----------------------------------------------------------------------
S.FMT_SV_HEADER         = "[ACI] SavedVariables — %d 등록, 고유 쌍 %d개"
S.FMT_SV_ENTRY          = "[ACI]   %s <- %s"
S.FMT_SV_CONFLICT_HEAD  = "[ACI] |cFF0000충돌: %d건|r"
S.FMT_SV_CONFLICT_LINE  = "[ACI]   %s <- %s"
S.SV_NO_CONFLICTS       = "[ACI]   충돌 없음"
S.FMT_SV_DISK_TITLE     = "[ACI] SV 디스크 사용량 — 총 %.2f MB / %d개 애드온"
S.FMT_SV_DISK_ENTRY     = "[ACI]   %s%s  %s|r%s"
S.SV_TAG_REVIEW         = " |cFFFF00[검토]|r"
S.SV_TAG_UNUSED         = " |cAAAAAA[미사용]|r"
S.FMT_SV_TAG_DEPS       = " |c00FF00[의존 %d개]|r"

----------------------------------------------------------------------
-- /aci init
----------------------------------------------------------------------
S.INIT_TITLE       = "[ACI] 애드온 초기화 시간 추정 (상위 10)"
S.FMT_INIT_ENTRY   = "  %5dms  load#%d %s|r"

----------------------------------------------------------------------
-- /aci deps [name]
----------------------------------------------------------------------
S.FMT_DEPS_NOT_FOUND   = "[ACI] '%s' 찾을 수 없음."
S.LABEL_LIBRARY        = " |c8888FF[라이브러리]|r"
S.FMT_DEPS_NEEDS       = "[ACI] 의존성 (필요): %d개"
S.FMT_DEPS_REVERSE     = "[ACI] 역방향 의존 (사용처): %d개"
S.DEP_OK               = "|c00FF00OK|r"
S.DEP_OFF              = "|cFF0000꺼짐|r"
S.DEP_MISSING          = "|cFF0000없음|r"
S.DEPS_SUMMARY_TITLE   = "[ACI] 의존성 요약 — 의존도 높은 라이브러리"
S.FMT_DEPS_DEPENDENT   = "[ACI]   %3d 의존  %s"
S.FMT_DEPS_NO_DEPS     = "[ACI] 의존성 없는 애드온: %d개"

----------------------------------------------------------------------
-- /aci orphans
----------------------------------------------------------------------
S.ORPHANS_TITLE        = "[ACI] 라이브러리 분석"
S.FMT_ORPHANS_HEADER   = "[ACI] |cFFFF00미사용 라이브러리 (%d)|r — 이를 사용하는 활성 애드온 없음:"
S.ORPHANS_NONE         = "[ACI] |c00FF00미사용 라이브러리 없음|r"
S.DEFACTO_HEADER       = "[ACI] |c8888FF사실상 라이브러리|r — 라이브러리로 표시되지 않았으나 여러 애드온이 의존:"
S.FMT_DEFACTO_ENTRY    = "[ACI]   %s (의존 %d개)"
S.FMT_HINT_CASE        = "|cFF6600<- 대소문자 불일치? %s|r"
S.FMT_HINT_VERSION     = "|cFF6600<- 버전 불일치? %s|r"
S.FMT_HINT_TYPO        = "|cFFFF00<- 오타? %s|r"

----------------------------------------------------------------------
-- /aci missing
----------------------------------------------------------------------
S.MISSING_TITLE             = "[ACI] 누락된 의존성"
S.MISSING_NONE              = "[ACI] |c00FF00누락된 의존성 없음|r"
S.FMT_MISSING_HEADER        = "[ACI] |cFFFF00선언되었으나 설치되지 않은 의존성 %d개:|r"
S.FMT_MISSING_ENTRY         = "[ACI]   %s (필요한 애드온 %d개)"
S.FMT_MISSING_HINT_CASE     = "[ACI] |cFF6600  -> 대소문자 불일치: %s 가 설치됨|r"
S.FMT_MISSING_HINT_VERSION  = "[ACI] |cFF6600  -> 버전 불일치: %s 가 설치됨|r"
S.FMT_MISSING_HINT_TYPO     = "[ACI] |cFFFF00  -> 오타? %s 가 설치됨|r"
S.FMT_MISSING_USER          = "[ACI]     <- %s"

----------------------------------------------------------------------
-- /aci hot
----------------------------------------------------------------------
S.HOT_TITLE_BY_ADDONS  = "애드온 수 기준 상위 10"
S.HOT_TITLE_BY_REGS    = "등록 횟수 기준 상위 10"
S.FMT_HOT_TITLE        = "[ACI] 이벤트 핫패스 — %s"
S.HOT_DISCLAIMER       = "|cAAAAAA(등록 횟수이며 발생 빈도가 아님. CPU 영향은 프로파일링 필요.)|r"
S.HOT_NONE             = "[ACI] 핫패스 없음"
S.FMT_HOT_EVENT        = "  %d 애드온, %d 등록  %s|r"
S.FMT_TAG_CROSS_HEAVY  = "  |cFF6600[핫이벤트 %d개] 과부하|r"
S.FMT_TAG_CROSS        = "  |cFFFF00[핫이벤트 %d개]|r"

----------------------------------------------------------------------
-- /aci ood
----------------------------------------------------------------------
S.OOD_TITLE                = "[ACI] 구버전 분류"
S.FMT_OOD_RATIO            = "[ACI] %d/%d 최상위 (%d%%)"
S.FMT_OOD_STANDALONE_HEAD  = "[ACI] |cFFFF00독립 애드온 (%d)|r — 업데이트 권장:"
S.OOD_STANDALONE_NONE      = "[ACI] |c00FF00구버전 독립 애드온 없음|r"
S.FMT_OOD_LIBONLY_HEAD     = "[ACI] |cCCCCCC라이브러리 (%d)|r — 작성자 구버전, 대개 무해:"
S.FMT_LIB_DEPENDENTS       = " |c888888(의존 %d개)|r"
S.OOD_LIBONLY_NONE         = "[ACI] |c00FF00구버전 라이브러리 없음|r"
S.FMT_OOD_EMBEDDED_HEAD    = "[ACI] |c666666내장 (%d)|r — 번들 하위 애드온, 무시:"
S.OOD_EMBEDDED_NONE        = "[ACI] |c00FF00구버전 내장 하위 애드온 없음|r"

----------------------------------------------------------------------
-- /aci health
----------------------------------------------------------------------
S.HEALTH_LABEL_RED         = "문제 발견"
S.HEALTH_LABEL_YELLOW      = "주의"
S.HEALTH_LABEL_GREEN       = "정상"
S.FMT_HEALTH_HEADER        = "[ACI] %s● %s|r"
S.FMT_HEALTH_OOD           = "[ACI] 구버전: %d/%d 최상위 (%d%%)"
S.FMT_HEALTH_IGNORABLE     = "[ACI]   |cCCCCCC무시 가능: 라이브러리 %d + 내장 %d|r"
S.FMT_HEALTH_ATTENTION     = "[ACI]   |cFFFF00주의: 독립 애드온 %d개|r"
S.FMT_HEALTH_NAMES         = "[ACI]     %s%s"
S.FMT_HEALTH_NAMES_MORE    = " 외 %d개"
S.HEALTH_CTX_MAJOR         = "메이저 패치 또는 장기 방치"
S.HEALTH_CTX_PATCH         = "패치 직후 정상 (1~2개월)"
S.HEALTH_CTX_NORMAL        = "정상"
S.HEALTH_CTX_WELL          = "잘 관리됨"
S.FMT_HEALTH_CTX           = "[ACI]   -> %s"
S.HEALTH_FULL_BREAKDOWN    = "[ACI]   상세: /aci ood"
S.FMT_HEALTH_ISSUE         = "[ACI] %s●|r %s"
S.FMT_REVIEW_CAND_SIZE_HINT  = " — 디스크 %.1f KB 사용"
S.FMT_REVIEW_CAND_HEADER     = "[ACI] |cCCCCCC● 검토 후보 (%d)|r — 라이브러리: 비활성 · 작성자 구버전 · 참조 없음:%s"
S.FMT_REVIEW_CAND_ENTRY      = "[ACI]   %s%s"
S.FMT_REVIEW_CAND_SIZE_MB    = " |c888888(%.2f MB)|r"
S.FMT_REVIEW_CAND_SIZE_KB    = " |c888888(%.1f KB)|r"
S.REVIEW_CAND_WARNING        = "[ACI]   |cFFAA00! 매니페스트 수준 분석임. ESO Lua API는 런타임 의존성(OptionalDependsOn, 전역 함수 사용)을 볼 수 없음. 삭제 전 Minion이나 애드온 문서에서 반드시 확인할 것.|r"
S.REVIEW_CAND_NOTE           = "[ACI]   |cCCCCCC^ 실제로는 사용 중일 수 있음. 맹목적 삭제 금지.|r"
S.FMT_HEALTH_ISSUE_SV_CONFLICTS  = "SV 충돌 %d건"
S.FMT_HEALTH_ISSUE_OOD           = "%d/%d 구버전 (%d%%)"
S.FMT_HEALTH_ISSUE_MISSING       = "누락 의존성 %d개"
S.FMT_HEALTH_ISSUE_MISSING_HINTS = "누락 의존성 %d개 (힌트 %d개)"
S.FMT_HEALTH_ISSUE_ORPHANS       = "미사용 라이브러리 %d개"
S.FMT_HEALTH_ISSUE_BIG_SV        = "%s 가 SV 디스크의 %.0f%% 사용 (%.2f MB / %.2f MB)"
S.FMT_HEALTH_EVENTS        = "[ACI] 이벤트: %d, 핫패스 %d"
S.HEALTH_DETAILS           = "[ACI] 상세: /aci orphans | /aci missing | /aci ood | /aci sv"

----------------------------------------------------------------------
-- /aci debug
----------------------------------------------------------------------
S.DEBUG_TITLE          = "[ACI] 디버그 — 내장 상태"
S.FMT_DEBUG_EMB_LINE   = "[ACI]   EMB  %s  <-  %s"
S.FMT_DEBUG_EMB_TOTAL  = "[ACI] 내장: %d / 활성 %s개"

----------------------------------------------------------------------
-- /aci dump
----------------------------------------------------------------------
S.DUMP_SAVED       = "[ACI] 덤프 저장됨. /reloadui 후 SV 파일의 [\"dump\"] 블록 확인."

----------------------------------------------------------------------
-- /aci save
----------------------------------------------------------------------
S.SAVE_REQUESTED       = "[ACI] SV 우선 저장 요청됨."
S.SAVE_NOT_AVAILABLE   = "[ACI] 사용 불가. /reloadui 로 저장."

----------------------------------------------------------------------
-- /aci help — command list
----------------------------------------------------------------------
S.HELP_TITLE       = "[ACI] 명령어 목록"
S.HELP_REPORT      = "[ACI]   /aci          요약 보고서"
S.HELP_STATS       = "[ACI]   /aci stats    이벤트 등록 통계"
S.HELP_ADDONS      = "[ACI]   /aci addons   애드온 목록"
S.HELP_DEPS        = "[ACI]   /aci deps     의존도 높은 라이브러리"
S.HELP_DEPS_X      = "[ACI]   /aci deps X   X의 정/역방향 의존성"
S.HELP_INIT        = "[ACI]   /aci init     초기화 시간 추정 (상위 10)"
S.HELP_ORPHANS     = "[ACI]   /aci orphans  미사용 라이브러리 + 사실상 라이브러리"
S.HELP_MISSING     = "[ACI]   /aci missing  누락된 의존성 + 힌트"
S.HELP_OOD         = "[ACI]   /aci ood      구버전 분류"
S.HELP_HOT         = "[ACI]   /aci hot      이벤트 핫패스 (애드온 수 기준)"
S.HELP_HOT_REGS    = "[ACI]   /aci hot regs 핫패스 등록 횟수 기준 정렬"
S.HELP_HEALTH      = "[ACI]   /aci health   환경 진단"
S.HELP_SV          = "[ACI]   /aci sv       SV 등록 + 충돌"
S.HELP_SAVE        = "[ACI]   /aci save     SV 강제 저장"
S.HELP_HELP        = "[ACI]   /aci help     이 도움말"

----------------------------------------------------------------------
-- Boot messages
----------------------------------------------------------------------
S.BOOT_USE_HINT    = "[ACI] |c00FF00/aci|r 입력으로 최신 통계 확인."
S.FMT_BOOT_LOADED  = "[ACI] v%s 로드됨. Hooks: Event=%s, SV=%s"
