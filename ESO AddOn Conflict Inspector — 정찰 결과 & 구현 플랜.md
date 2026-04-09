# ESO AddOn Conflict Inspector — 정찰 결과 & 구현 플랜

> **프로젝트 코드명**: AddOn Conflict Inspector (이하 ACI)
> 

> **작성일**: 2026-04-08
> 

> **상태**: 정찰 완료, PoC 진입 직전
> 

> **목표 사용자**: 애드온을 10개 이상 깐 일반 ESO 유저, 길드 트러블슈팅 담당자, 콘솔 유저
> 

---

# 한 줄 요약

ESO 애드온 생태계에는 **개발자용 프로파일링 도구는 이미 충분**(ESOProfiler, Zgoo, LibDebugLogger)하지만, **일반 유저를 위한 "내 환경 진단·트러블슈팅 보조" 도구는 비어있다.** ACI는 이 빈 자리를 노린다.

# 시장 정찰 결과

## 이미 존재하는 도구 (경쟁자/보완재)

| 도구 | 작성자 | 무엇을 함 | ACI와의 관계 |
| --- | --- | --- | --- |
| **ESOProfiler** | sirinsidiator | ZOS 공식 script profiler API wrapping. 함수별 호출 시간, call-stack, perfetto trace export | **개발자용. 일반 유저 대상 아님.** ACI는 이 위에 얹지 않음 |
| **Zgoo** | (zgoo author) | 실시간 변수 inspect, /zgoo events 로 이벤트 추적, 컨트롤 검사 | **개발자용 디버거.** ACI는 이걸 대체하지 않음 |
| **LibDebugLogger + DebugLogViewer** | sirinsidiator | 로그 인프라, 외부 viewer | **인프라.** ACI는 이걸 의존성으로 쓸 수 있음 |
| **Performance Statz** | - | fps/latency 평균 표시 | 단순 도구. ACI 대상 아님 |
| **Addon Clearer** (discontinued) | - | 일괄 선택/해제 버튼 | 죽음 |
| **Minion** (외부) | - | 다운로드/업데이트 매니저 | 게임 외부 도구. ACI 대상 아님 |
| **ZOS 기본 애드온 매니저** | ZOS | 켜기/끄기, 의존성 표시 | **빈약함.** ACI의 진짜 경쟁자이자 baseline |

## 비어있는 자리 (ACI가 노릴 영역)

- 애드온별 정적 메타데이터 통합 뷰 (ZOS 기본 UI보다 풍부하게)
- 의존성 그래프 시각화
- 글로벌 namespace 충돌 진단 ("이 두 애드온이 같은 변수 이름 씀")
- SavedVariables 충돌 진단
- 애드온별 이벤트 등록 카운트 / hot path 진단
- 콘솔 메모리 한도 (100MB 공유) 추적기
- 트러블슈팅용 환경 덤프 / 클립보드 export (길드 헬프 채널 붙여넣기용)
- 버그 발생 시 어느 애드온이 원인인지 자동 추정 (LibDebugLogger 로그 분석 + 의심 애드온 disable 추천)

# 기술 정찰 결과

## 결정적 사실 1: ESO Lua 환경의 특성

- **Havok Script (Lua 5.1 기반, 64-bit, 일부 5.2/5.3 백포팅)**
- **`io`, `os`, `package` 모듈은 제거됨** — 파일/네트워크 직접 접근 불가
- **모든 변수는 진짜 글로벌**: 모든 애드온이 같은 글로벌 테이블 공유, API 함수도 글로벌 변수임 → `_G` 순회로 namespace 검사 가능
- **SavedVariables는 zone change / reloadui / logout 시점에만 디스크 flush**

## 결정적 사실 2: EVENT_MANAGER 후킹 가능

EVENT_MANAGER 객체 자체의 내부 등록 테이블은 C 측에 있어 직접 enumerate 불가. **하지만** `EVENT_MANAGER:RegisterForEvent`는 Lua 함수이므로 ZO_PreHook으로 가로챌 수 있음.

```lua
-- ZO_PreHook 시그니처
function ZO_PreHook(objectTable, existingFunctionName, hookFunction)
-- 또는 글로벌 함수의 경우:
function ZO_PreHook(existingFunctionNameInQuotes, hookFunction)

-- hookFunction이 true 반환 → 원본 호출 안 함
-- false/nil 반환 → 원본 호출됨 (정상 케이스)
```

**SecurePostHook**도 존재. 직접 함수 덮어쓰기보다 항상 ZO_PreHook/SecurePostHook 사용이 권장됨 (secure context taint 방지). BetterUI가 최근 이걸로 마이그레이션함.

## 결정적 사실 3: 애드온 로딩 순서 규칙

공식 규칙 (`Addon Structure` 위키):

1. 의존성 (`DependsOn`, `OptionalDependsOn`)이 있으면 그것이 먼저 sort에 반영됨
2. 의존성이 없는 경우, **폴더 이름의 역알파벳 순(reverse alphabetic)**으로 로드. 즉 **Z로 시작하는 폴더가 먼저, A로 갈수록 나중**.
3. ZOS 코드는 항상 가장 먼저
4. 동일 이름 중복은 `AddOnVersion` 큰 게 선택됨

**→ ACI의 폴더 이름은 `ZZZ_AddOnInspector` 같은 형태로 시작해야 다른 애드온보다 먼저 로드된다.** 이는 트릭이 아니라 ZOS 공식 동작이라 안정적.

**한계**: 100% 보장은 아님. 다른 라이브러리도 같은 트릭을 쓸 수 있음. → "가장 먼저 로드되지 못한 애드온은 분석에서 표시 누락"으로 정직하게 처리.

## 결정적 사실 4: 세 종류의 이벤트 시스템

진정한 충돌 분석을 하려면 **셋 다** 모니터링해야 함:

1. **`EVENT_MANAGER:RegisterForEvent`** — C → Lua 게임 이벤트 (가장 큼)
2. **`control:RegisterForEvent`** — XML 컨트롤별 이벤트 (TradingHouse 등이 사용)
3. **`CALLBACK_MANAGER:RegisterCallback`** — 애드온 간 커스텀 이벤트 (애드온이 만든 가짜 이벤트)

ESOProfiler도 1번만 추적하지 2,3번은 안 봄. ACI의 차별화 포인트.

## 결정적 사실 5: AddOn 메타데이터 API

```lua
local manager = GetAddOnManager()
local numAddons = manager:GetNumAddOns()

for i = 1, numAddons do
    -- 시그니처 확정
    local name, title, author, description, enabled, state, isOutOfDate, isLibrary
        = manager:GetAddOnInfo(i)
    
    local version = manager:GetAddOnVersion(i)
    local rootPath = manager:GetAddOnRootDirectoryPath(i)
    local numDeps = manager:GetAddOnNumDependencies(i)
    -- GetAddOnDependencyInfo(addOnIndex, depIndex) 도 있을 가능성 큼
end

-- ADDON_STATE_ENABLED 같은 enum 존재
```

전부 보호되지 않은 public API. 어떤 정보든 자유롭게 읽을 수 있음.

## 결정적 사실 6: 메모리 측정 함수가 노출됨

```lua
local totalMB = GetTotalUserAddOnMemoryPoolUsageMB()
```

콘솔 애드온은 **모든 애드온이 100MB 풀을 공유**하고 프레임당 1초 실행 시간 한도가 있음. 콘솔 유저에게는 절실한 정보. PC 유저도 메모리 누수 디버깅에 유용. **collectgarbage()** 도 호출 가능 → 강제 GC 후 메모리 측정으로 간접적으로 애드온별 영향 추정 가능.

## 결정적 사실 7: 매니페스트 디렉티브 전체

매니페스트(`.txt` 또는 `.addon`)에 들어가는 디렉티브:

- `## Title:` — 표시 이름
- `## Author:`
- `## Version:` — 사람용 버전 문자열
- `## APIVersion:` — ESO API 버전 (101049 등)
- `## AddOnVersion:` — 정수, 중복 폴더 처리에 사용
- `## IsLibrary:` — true/false
- `## DependsOn:` — 하드 의존성 (없으면 로드 안 됨)
- `## OptionalDependsOn:` — 소프트 의존성 (sort에만 영향)
- `## SavedVariables:` — SV 글로벌 변수 이름들 (공백 구분)
- `## SavedVariablesPerCharacter:`
- `## Description:`

중요: ACI는 매니페스트 파일을 직접 읽을 수 없음 (io 모듈 제거됨). **GetAddOnInfo/GetAddOnNumDependencies API로만 접근 가능.** 즉 `## SavedVariables:` 필드를 직접 읽을 방법이 없을 수 있음 → SV 충돌 감지는 다른 방법이 필요할 수 있다. **PoC에서 검증 필요**.

# ACI 설계

## 핵심 가치

> 애드온을 많이 깐 ESO 유저가 느린 fps, 충돌, 알 수 없는 에러를 만났을 때, 어느 애드온이 원인인지 빠르게 좁히고 길드/포럼에 붙여넣을 환경 리포트를 클릭 한 번에 만들어준다.
> 

## 타겟 사용자 (구체적으로)

**Primary**: 애드온 15~50개를 깐 일반 PC 유저. 트러블슈팅 의지는 있지만 Lua를 모름.

**Secondary**: 길드의 "애드온 헬프" 담당자. 다른 유저의 환경을 진단해줘야 함.

**Tertiary**: 콘솔 유저. 100MB 메모리 한도 때문에 누가 메모리 먹는지 절실히 알아야 함.

**Non-target**: 애드온 작가. 이 사람들에겐 ESOProfiler/Zgoo가 더 좋음.

## 단계별 로드맵

### Phase 0 — Spike / PoC (1주)

**목표: 핵심 가설 3개 검증**

1. `ZZZ_` 폴더명 트릭이 실제로 다른 애드온보다 먼저 로드되는가?
2. `ZO_PreHook(EVENT_MANAGER, "RegisterForEvent", ...)` 가 작동하는가?
3. `## SavedVariables:` 필드를 어떻게든 읽을 방법이 있는가? (없으면 SV 충돌 감지 기능 빠짐)

**산출물**: 100~200줄짜리 단일 lua 파일. SavedVariables에 "내가 가로챈 RegisterForEvent 호출 목록"을 덤프. /reloadui 후 SV 파일 열어서 확인.

### Phase 1 — Static Inventory (1~2주)

**목표: 정적 정보만으로도 ZOS 기본 UI보다 명백하게 나은 "내 애드온 대시보드" 제공**

- 설치된 애드온 전체 목록 + 메타데이터 (이름, 버전, 작성자, API 버전, enabled, isLibrary, isOutOfDate)
- API 버전 mismatch 경고 (현재 게임 API와 다른 애드온)
- 의존성 트리 시각화 (각 애드온이 무엇에 의존하고 무엇에 의존받는지)
- 라이브러리 사용 통계 ("LibAddonMenu-2.0을 23개 애드온이 사용 중")
- 검색/필터 (이름, 작성자, 카테고리)
- 클릭 시 [ESOUI.com](http://ESOUI.com) 페이지 링크

**의존성**: `LibAddonMenu-2.0` (설정 UI), `LibCustomMenu` (컨텍스트 메뉴) 정도. 라이브러리 사용 최소화.

### Phase 2 — Runtime Inspection (2~3주)

**목표: 동적 추적 기능 추가**

- 글로벌 namespace pollution 검사: `_G`를 reloadui 직후와 PLAYER_ACTIVATED 후에 두 번 스냅샷, diff로 "각 애드온이 만든 글로벌 변수" 추적
- 같은 글로벌 이름이 두 곳에서 정의되면 충돌 경고
- 이벤트 등록 가로채기: ZO_PreHook으로 RegisterForEvent / control:RegisterForEvent / CALLBACK_MANAGER 추적
- 같은 이벤트에 5개 이상 핸들러가 등록되면 hot path 표시
- 이벤트별 "누가 등록했는지" namespace 역추적 표시

**중요한 한계**: 우리가 `ZZZ_` 트릭으로 먼저 로드되어도 **ZOS 네이티브 코드는 그보다 먼저 자기 핸들러를 등록**함. 즉 ZOS 자체 핸들러는 우리 통계에서 누락됨. 이건 정직하게 표시 ("ZOS native handlers: not tracked").

### Phase 3 — Performance Diagnostic (2~3주)

**목표: 성능 문제의 원인을 좁히는 데 도움**

- `GetTotalUserAddOnMemoryPoolUsageMB()` 시간별 그래프
- /reloadui 시간 분해: EVENT_ADD_ON_LOADED 발사 사이의 GetGameTimeMilliseconds 차이를 측정해서 "각 애드온의 init 시간" 추정
- A/B 모드: "이 애드온 비활성화 → 1분간 fps 측정 → 활성화 → 1분간 fps 측정" 자동화 (사용자에게 reloadui 두 번 요청)
- 메모리 leak 추정: 시간이 지남에 따라 GetTotalUserAddOnMemoryPoolUsageMB이 단조 증가하면 경고
- **콘솔 모드 특별 경고**: 100MB의 80% 도달 시 알림

**중요한 한계**: 함수별 정확한 실행 시간 측정은 안 함. 그건 ESOProfiler가 훨씬 잘함. 우리는 "어느 애드온이 의심스러운가"를 좁히는 단계까지만.

### Phase 4 — Diagnostic Reports (1~2주)

**목표: 트러블슈팅을 길드/포럼에 요청할 때의 마찰 제거**

- "환경 리포트 생성" 버튼: 클릭 한 번으로 다음 정보를 SavedVariables에 덤프
    - 애드온 목록 + 버전 + enabled 상태
    - 의존성 트리
    - API mismatch 목록
    - 글로벌 충돌 / 이벤트 hot path 발견 사항
    - 메모리 사용량
    - LibDebugLogger 최근 에러 로그 (있으면)
- 사용자가 SV 파일 내용을 클립보드/Pastebin/GitHub Gist에 붙여넣을 수 있도록 안내
- **인게임에서 직접 전송은 불가** (네트워크 차단). 외부 보조 스크립트(Python)로 SV 파일을 깔끔한 markdown으로 변환하는 도구를 함께 제공 → RICCILAB 도메인에 웹 변환기 호스팅
- 자동 추정 모드 (Phase 4 후반): 최근 에러 로그를 보고 "이 에러는 이 애드온이 원인일 가능성 X%"라고 추정

# 위험 요소 & 대응

## R1: SavedVariables 매니페스트 필드 접근 불가

- **확률**: 중
- **영향**: SV 충돌 감지 기능이 빠짐
- **대응**: PoC에서 빠르게 검증. 만약 GetAddOn API에 SV 필드가 안 나오면, 우회로 "각 애드온이 만든 글로벌 변수 중 SavedVariables 디렉티브로 등록된 패턴(테이블, persisted)"을 휴리스틱으로 추적

## R2: ZZZ_ 트릭이 100% 동작 안 함

- **확률**: 낮음
- **영향**: 일부 라이브러리(LibStub 후속 등)는 더 먼저 로드될 수 있음
- **대응**: 정직하게 "이 애드온들은 ACI 로드 전에 등록됨" 섹션으로 표시. 100% 추적을 약속하지 않음.

## R3: ESOProfiler와 기능 중복 인식

- **확률**: 중
- **영향**: 사용자가 "ESOProfiler 있으니까 ACI 필요 없어" 라고 판단
- **대응**: 마케팅에서 명확히 분리. **ESOProfiler는 "코드 최적화하려는 작가용", ACI는 "내 환경에 뭐가 잘못됐나 알고 싶은 유저용"**. 첫 화면 UX 자체가 다름 — ESOProfiler는 call-stack 트리로 시작, ACI는 "내 애드온 목록"으로 시작.

## R4: API 패치마다 깨질 위험

- **확률**: 중
- **영향**: 매 메이저 패치마다 유지보수
- **대응**: 의존하는 API가 매우 적음 (GetAddOnInfo 계열 + ZO_PreHook). 둘 다 안정적인 ZOS 공식 패턴이라 깨질 가능성 낮음

## R5: 일반 유저가 진단 정보를 이해 못 함

- **확률**: 높음
- **영향**: 유저가 "namespace pollution" 같은 단어를 보고 닫음
- **대응**: UX 설계 시 두 모드 분리 — "Simple"(빨/노/초 신호등 + 한 줄 설명)와 "Expert"(원시 데이터). 기본은 Simple.

# 차별화 매트릭스 (다시 정리)

| 기능 | ESOProfiler | Zgoo | ZOS 기본 UI | **ACI** |
| --- | --- | --- | --- | --- |
| 함수 실행 시간 프로파일링 | ✅ 강력 | ❌ | ❌ | ❌ (안 함) |
| 변수 실시간 inspect | ❌ | ✅ 강력 | ❌ | ❌ (안 함) |
| 애드온 목록 + 메타데이터 | ❌ | ❌ | ⚠️ 빈약 | ✅ 강력 |
| 의존성 그래프 | ❌ | ❌ | ⚠️ 텍스트 | ✅ 시각화 |
| API mismatch 경고 | ❌ | ❌ | ⚠️ "out of date"만 | ✅ 상세 |
| Namespace 충돌 감지 | ❌ | ❌ | ❌ | ✅ |
| 이벤트 hot path 감지 | ⚠️ 시간만 | ⚠️ 실시간 추적만 | ❌ | ✅ |
| 메모리 추적 (콘솔 한도) | ⚠️ 일반 | ❌ | ❌ | ✅ 콘솔 특화 |
| 환경 리포트 export | ❌ | ❌ | ❌ | ✅ 핵심 기능 |
| 일반 유저 친화 UX | ❌ 개발자용 | ❌ 개발자용 | ⚠️ 빈약 | ✅ 핵심 |

# 다음 액션

## 즉시 (이번 주)

- [ ]  PoC 코드 작성 (Phase 0)
    - [ ]  `ZZZ_AddOnInspector` 폴더 생성
    - [ ]  매니페스트 (`.addon` 권장 — PC/콘솔 호환)
    - [ ]  `EVENT_MANAGER:RegisterForEvent`에 ZO_PreHook
    - [ ]  가로챈 호출을 SavedVariables에 timestamped 덤프
    - [ ]  /reloadui 후 SV 파일 확인
- [ ]  가설 3개 검증 결과 기록

## 다음 (PoC 통과 시)

- [ ]  GitHub 리포 생성 (`baeghyeon-hub/eso-aci`)
- [ ]  CI 파이프라인 (애드온 zip 자동 빌드, ESOUI 업로드 자동화는 나중에)
- [ ]  LibDebugLogger 의존성 도입 검토
- [ ]  Phase 1 데이터 모델 설계

## 나중 (Phase 2+)

- [ ]  LibAddonMenu-2.0 통합
- [ ]  외부 변환 도구 (Python, RICCILAB 도메인에 호스팅)
- [ ]  한국어 / 영어 / 독일어 / 프랑스어 로컬라이제이션

# 부록: 핵심 코드 스니펫

## 매니페스트 예시 (`ZZZ_AddOnInspector.addon`)

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

## PoC 핵심 코드

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
    
    -- 가설 검증: ZO_PreHook으로 RegisterForEvent 가로채기
    ZO_PreHook(EVENT_MANAGER, "RegisterForEvent", function(self, namespace, eventCode, callback, ...)
        table.insert(ACI_SavedVars.eventLog, {
            ts = GetGameTimeMilliseconds(),
            namespace = namespace,
            eventCode = eventCode,
            -- callback은 함수라 직렬화 불가, 주소만 기록
            callbackStr = tostring(callback),
        })
        -- false/nil 반환 → 원본 정상 호출
    end)
    
    d("[ACI] PoC loaded. ZO_PreHook installed on EVENT_MANAGER:RegisterForEvent")
end

EVENT_MANAGER:RegisterForEvent(ACI.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
```

검증 후 SavedVariables 파일을 열어보면 `eventLog` 테이블에 다른 애드온들의 이벤트 등록 내역이 들어 있어야 함. 만약 거의 비어 있다면 → ZZZ_ 트릭 실패 또는 ZO_PreHook 실패. 가득 차 있다면 → **핵심 가설 통과, 후보 3 GO**.

# 참고 링크

- [ESOUI Wiki — ZO_PreHook](https://wiki.esoui.com/ZO_PreHook)
- [ESOUI Wiki — Addon Structure](https://wiki.esoui.com/Addon_Structure)
- [ESOUI Wiki — Addon manifest format](https://wiki.esoui.com/Addon_manifest_(.txt)_format)
- [ESOUI Wiki — Esolua](https://wiki.esoui.com/Esolua)
- [ESOUI Wiki — How to update for console](https://wiki.esoui.com/How_to_update_your_addon_for_console)
- [esoui/esoui GitHub mirror](https://github.com/esoui/esoui) (live: API 101048까지 반영)
- [ESOProfiler](https://www.esoui.com/downloads/info2166-ESOProfiler.html)
- [Zgoo](https://www.esoui.com/downloads/info24-Zgoo-datainspectiontool.html)
- [LibDebugLogger](https://www.esoui.com/downloads/info2275-LibDebugLogger.html)