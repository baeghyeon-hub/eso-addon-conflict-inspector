# Phase 1 — 아키텍처 설계

> **작성일**: 2026-04-08
>
> **상태**: 설계 초안
>
> **설계 인풋**: Phase 0 SV 데이터 (75 애드온, 222 이벤트 등록, 5 SV 생성, namespace 패턴 분석)

---

# 1. 데이터 모델

## 1.1 핵심 원칙

- SV에는 **live 참조**를 저장. table 참조를 넣으면 flush 시점에 최신 데이터가 자동 직렬화됨.
- eventLog는 flat array 유지하되, **UI 표시 시 namespace clustering**으로 집계.
- 4계층 구조: `addon → cluster → namespace → event`

## 1.2 SavedVariables 스키마 (`ACI_SavedVars`)

```lua
ACI_SavedVars = {
    -- 설정
    settings = {
        version = 1,
        simpleMode = true,        -- Simple/Expert 모드 토글
        clusterPatterns = {       -- namespace clustering 정규식
            "^(LibCombat)%d+$",
            "^(CrutchAlerts%w+)%d+$",
            "^(Azurah)%w+$",
        },
    },

    -- Phase 0 데이터 (live 참조)
    loadOrder       = {},   -- { index, addon, ts }[]
    eventLog        = {},   -- { ts, namespace, eventCode, callbackId }[]
    svRegistrations = {},   -- { [table::namespace] = { method, version, caller, ts, traceback }[] }

    -- Phase 1 데이터 (정적, PLAYER_ACTIVATED에서 1회 수집)
    metadata = {
        numAddons = 0,
        addons = {},          -- { name, title, author, version, enabled, isLibrary, isOutOfDate, deps[], svDiskMB, ... }[]
        managerMethods = {},
    },

    -- Phase 1 집계 (UI 렌더링용, /aci 또는 창 열 때 갱신)
    summary = {
        totalAddons = 0,
        enabledAddons = 0,
        libraryCount = 0,
        outOfDateCount = 0,
        totalEventRegistrations = 0,
        namespaceClusters = {},   -- { base, count, eventCodes[] }[]
        topHeavyAddons = {},      -- 상위 N개
        svTotalDiskMB = 0,
        svPerAddon = {},          -- { name, diskMB }[]
    },
}
```

## 1.3 Namespace Clustering 규칙

PoC 데이터에서 확인된 패턴:

| 패턴 | 예시 | 그룹 결과 |
|------|------|----------|
| `LibCombat%d+` | LibCombat1, LibCombat353 | → `LibCombat` (172건) |
| `CrutchAlerts%w+%d+` | CrutchAlertsEffectAlert17874 | → `CrutchAlerts` (11건) |
| `Azurah%w+` | AzurahTarget, AzurahBossbar | → `Azurah` (16건) |
| `FancyActionBar%p?%w*` | FancyActionBar+, FancyActionBar+UltValue | → `FancyActionBar` (4건) |
| 숫자 접미사 없는 일반 | CombatAlerts, BUI_Event | → 그대로 |

**기본 클러스터링 알고리즘**:
1. 숫자 접미사 제거: `namespace:match("^(.-)%d+$")` → base 추출
2. base가 같은 것끼리 그룹핑
3. 특수 패턴은 `settings.clusterPatterns`에 추가 정규식으로 커버

---

# 2. 파일 구조

```
ZZZ_AddOnInspector/
├── ZZZ_AddOnInspector.addon      -- 매니페스트
├── ACI_Core.lua                  -- 전역 테이블, SV 초기화, 이벤트 라이프사이클
├── ACI_Hooks.lua                 -- PreHook 설치 (RegisterForEvent, ZO_SavedVars)
├── ACI_Inventory.lua             -- GetAddOnManager 기반 정적 메타데이터 수집
├── ACI_Analysis.lua              -- clustering, 집계, 충돌 감지
├── ACI_Commands.lua              -- /aci 슬래시 명령어 체계
├── ACI_UI.lua                    -- 메인 대시보드 윈도우 (Phase 1 후반)
├── ACI_UI.xml                    -- XML 레이아웃 (Phase 1 후반)
└── ACI_Export.lua                -- 환경 리포트 텍스트 생성 (Phase 4, 스텁만)
```

매니페스트 파일 목록:
```
ACI_Core.lua
ACI_Hooks.lua
ACI_Inventory.lua
ACI_Analysis.lua
ACI_Commands.lua
; Phase 1 후반
; ACI_UI.xml
; ACI_UI.lua
; ACI_Export.lua
```

### 로드 순서 의존성

```
Core → Hooks → Inventory → Analysis → Commands → (UI)
```

- `Core`: ACI 전역 테이블, EVENT_ADD_ON_LOADED 핸들러, SV 초기화
- `Hooks`: Core의 ACI.eventLog, ACI.svRegistrations에 데이터를 넣음
- `Inventory`: Core의 ACI.metadata에 정적 데이터를 넣음
- `Analysis`: eventLog + metadata를 읽어서 summary를 생성
- `Commands`: Analysis 결과를 출력

ESO는 매니페스트에 나열된 순서대로 파일을 로드하므로, 위 순서를 매니페스트에 그대로 나열하면 됨.

---

# 3. Slash Command 체계

```
/aci              -- 요약 리포트 (Simple 모드: 신호등, Expert 모드: 상세)
/aci stats        -- 이벤트 등록 통계 (클러스터별)
/aci addons       -- 애드온 목록 (enabled/disabled/outofdate)
/aci deps [name]  -- 의존성 트리 (특정 애드온 또는 전체)
/aci sv           -- SV 등록 + 충돌 리포트
/aci save         -- SV 강제 flush
/aci reset        -- 로그 초기화
/aci export       -- 환경 리포트 텍스트 생성 (Phase 4)
/aci mode         -- Simple ↔ Expert 토글
```

---

# 4. Phase 1 구현 순서

## Step 1: 파일 분리 (현재 ACI_Main.lua → 5개 파일)

순수 리팩터링. 기능 변경 없이 코드를 파일별로 나눔.

## Step 2: ACI_Inventory.lua 강화

- 모든 애드온 메타데이터 수집 완성
- 의존성 트리 구축 (역방향 포함: "이 라이브러리를 누가 쓰는가")
- API 버전 mismatch 검출
- isOutOfDate 플래그 집계
- SV 디스크 용량 수집

## Step 3: ACI_Analysis.lua

- namespace clustering 엔진
- 클러스터별 이벤트 등록 수 집계
- 이벤트 코드별 핸들러 수 집계 (hot path 후보)
- SV 충돌 감지 (기존 DetectSVConflicts)
- 애드온별 init 시간 추정 (loadOrder ts 차이)

## Step 4: ACI_Commands.lua 확장

- /aci stats, /aci addons, /aci deps, /aci sv 구현
- Simple 모드: 빨/노/초 신호등 + 한 줄 요약
- Expert 모드: 원시 데이터 전부 출력

## Step 5: ACI_UI.xml + ACI_UI.lua (Phase 1 후반)

- TopLevelControl (ESC로 토글)
- 좌측: 애드온 리스트 (스크롤, 검색, 필터)
- 우측: 선택한 애드온 상세 (메타데이터 + 이벤트 등록 + 의존성)
- 상단 배너: 경고 카운트 (out-of-date, SV 충돌, hot path)

---

# 5. Phase 1 UI 와이어프레임 (텍스트)

```
┌─ AddOn Conflict Inspector ──────────────────────────────────┐
│ [Simple ▼]  [검색: ________]  ⚠ 3 out-of-date  ⚠ 0 충돌  │
├─────────────────────┬───────────────────────────────────────┤
│ ■ 애드온 목록 (66)  │ ▶ Azurah                              │
│                     │   Author: Azurah Team                 │
│ ✅ Azurah        ▶ │   Version: 2.5.1                      │
│ ✅ BanditsUI        │   API: 101049 (current)               │
│ ✅ CombatAlerts     │   Type: AddOn                         │
│ ✅ CombatMetrics    │   SV Disk: 0.23 MB                   │
│ ⚠  CrutchAlerts    │                                       │
│ ✅ Destinations     │   ▼ 의존성 (2)                         │
│ ✅ DolgubonsLazy... │     LibAddonMenu-2.0 ✅               │
│ ✅ FancyActionBar+  │     LibCustomMenu ✅                  │
│ ...                 │                                       │
│                     │   ▼ 이벤트 등록 (16건, 6 sub-ns)      │
│ 📚 라이브러리 (27)  │     AzurahTarget (6)                  │
│ ✅ LibAddonMenu     │       131129, 131131, 131132,         │
│ ✅ LibAsync         │       131123, -1, 131136              │
│ ✅ LibCombat     ⚡ │     AzurahBossbar (2)                 │
│ ...                 │     AzurahUltimate (2)                │
│                     │     AzurahAttributes (1)              │
│                     │     AzurahExperience (2)              │
│                     │     AzurahCompass (2)                  │
│                     │                                       │
│                     │   ▼ 역의존성 (이 애드온을 쓰는 것)     │
│                     │     (없음)                             │
└─────────────────────┴───────────────────────────────────────┘
```

### 아이콘 범례
- ✅ 정상
- ⚠ out-of-date 또는 경고
- ⚡ heavy registrant (클러스터 50+ events)
- 📚 라이브러리 섹션 헤더

---

# 6. Phase 0 데이터 기반 설계 결정

| 결정 | 근거 (데이터) |
|------|-------------|
| namespace count는 "무거움" 지표로 안 씀 | LibCombat 172 ≠ 10x heavier than Azurah 16. 필터가 좁을수록 callback 빈도 낮음 |
| 기본 clustering은 숫자 접미사 제거 | LibCombat%d+, CrutchAlerts...%d+ 패턴이 전체의 80%+ 차지 |
| init 시간 = loadOrder ts 차이로 추정 | CombatMetrics ~1.2s, TTC ~320ms 이미 보임 |
| CrossCheck는 Phase 2로 연기 | namespace→addon 매핑은 traceback 기반이 정확. Phase 1에선 불필요 |
| "100% 추적 포기" 포지션 채택 | 222건 중 대부분이 PLAYER_ACTIVATED 이후. Lib init-time 등록은 진단적 가치 낮음 |
| SV는 live 참조로 저장 | flush 시점에 최신 데이터 자동 직렬화. PLAYER_ACTIVATED 스냅샷 버그 재발 방지 |

---

# 7. 다음 액션

- [ ] Step 1: ACI_Main.lua → 5개 파일 분리
- [ ] Step 2: ACI_Inventory.lua — 의존성 트리 + API mismatch + SV 용량
- [ ] Step 3: ACI_Analysis.lua — clustering + 집계 + init 시간
- [ ] Step 4: ACI_Commands.lua — /aci stats, addons, deps, sv
- [ ] Step 5: ACI_UI — 대시보드 (Phase 1 후반)
- [ ] 매 Step 완료 시 인게임 검증 + 문서 기록
