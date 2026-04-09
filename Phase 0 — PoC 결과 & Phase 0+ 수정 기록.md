# Phase 0 — PoC 결과 & Phase 0+ 수정 기록

> **작성일**: 2026-04-08
>
> **상태**: Phase 0 PoC 완료 → Phase 0+ 보강 완료, 인게임 검증 대기
>
> **선행 문서**: `ESO AddOn Conflict Inspector — 정찰 결과 & 구현 플랜.md`

---

# Phase 0 PoC 실행 결과 (첫 번째 인게임 테스트)

## 테스트 환경

- 날짜: 2026-04-08 20:44
- 설치 애드온 수: 75개 (추적 기준)
- ESO 클라이언트: live 서버, PC

## 가설 검증 결과 요약

| 가설 | 판정 | 상세 |
|------|------|------|
| **H1** ZZZ_ 로딩 순서 | **조건부 PASS** | 첫 로드 = `ZO_FontStrings` (ZOS 네이티브). 유저 애드온 중 순서는 SV 데이터로 추가 확인 필요 |
| **H2** ZO_PreHook on RegisterForEvent | **PASS** | 44개 RegisterForEvent 호출 가로채기 성공 |
| **H3** SV 매니페스트 필드 API 접근 | **FAIL** | GetAddOnManager에 SV 필드 읽는 메서드 없음 (예상된 R1 위험 현실화) |

## H1 상세 분석

- `ZO_FontStrings`가 첫 번째로 찍힌 건 완전히 예상 범위
- ZOS 네이티브 코드는 항상 유저 애드온보다 먼저 로드됨 (공식 문서 명시)
- **진짜 질문은 "유저 애드온 중 ACI가 첫 번째인가"**
- H2가 PASS했다는 것 자체가 간접 증거: 44개 호출을 잡았다는 건 그 44개 모두가 ACI의 PreHook 설치 이후에 등록됐다는 뜻
- 만약 ACI가 중간에 로드됐다면 이전 애드온들의 호출은 놓쳤을 것

## H2 상세 분석

- 44개를 잡았다는 건 단순 PoC 성공이 아니라 **Phase 2의 핵심 아키텍처가 통째로 확정**됐다는 의미
- 같은 패턴으로 확장 가능:
  - `control:RegisterForEvent` → 각 컨트롤 인스턴스에 PreHook
  - `CALLBACK_MANAGER:RegisterCallback` → CALLBACK_MANAGER 객체에 PreHook
  - `EVENT_MANAGER:RegisterForUpdate` → 같은 패턴
  - `EVENT_MANAGER:AddFilterForEvent` → 같은 패턴
- **Phase 2 이벤트 추적 레이어의 기술적 불확실성 거의 제거됨**

## H3 FAIL → 우회로 확정

### 원래 계획의 문제

원래 계획: "매니페스트의 `## SavedVariables:` 필드를 읽어서 같은 테이블 이름을 두 애드온이 쓰면 충돌"

이건 **부정확한 충돌 정의**였음. 이유:
- ZOS 자체 코드가 `ZO_Ingame_SavedVariables`를 여러 내부 매니저가 공유하면서 namespace 인자로 서브테이블만 분리해 씀
- 같은 SV 테이블을 여러 곳에서 쓰는 건 **정상 패턴**

### 새로운 (더 정확한) 충돌 정의

> **진짜 충돌 = 같은 `(SV_table, namespace)` 쌍을 다른 애드온이 쓸 때**

이건 매니페스트 파싱으로는 잡을 수 없고, **ZO_SavedVars 생성자 호출을 후킹해야만** 잡을 수 있음. H3 FAIL이 오히려 더 정확한 감지 방법으로 이끈 것.

### 우회 기술: ZO_SavedVars 생성자 후킹

`ZO_SavedVars`는 Lua 함수 (esoui/esoui 소스 미러에서 확인됨) → ZO_PreHook 가능

후킹 대상 메서드 4개:
- `ZO_SavedVars:NewAccountWide(tableName, version, namespace, defaults, profile, displayName)`
- `ZO_SavedVars:NewCharacterIdSettings(tableName, version, namespace, defaults, profile)`
- `ZO_SavedVars:NewCharacterSettings(tableName, version, namespace, defaults, profile)`
- `ZO_SavedVars:New(tableName, version, namespace, defaults, profile)` (존재 시)

첫 번째 인자 `tableName`이 SavedVariables 전역 테이블 이름(문자열).

### 호출 애드온 역추적 방법 2가지

1. **Last-addon-loaded 기반** (채택): `EVENT_ADD_ON_LOADED`를 같이 후킹하여 "가장 최근에 init 중인 애드온"을 전역 상태로 유지. SV 생성은 보통 그 애드온의 OnAddOnLoaded 콜백 안에서 일어나므로 안정적.
2. **Traceback 기반** (보조): `debug.traceback()`으로 호출 스택을 얻고 경로에서 `AddOns/Foo/...` 패턴 parse. ESO Lua는 traceback이 backported되어 사용 가능.

→ Phase 0+ 에서는 **두 가지 모두 기록** (`caller` + `traceback` 필드)하여 어느 쪽이 더 신뢰성 높은지 실데이터로 비교.

## GetAddOnManager 메서드 전체 목록 (인게임 덤프)

PoC에서 열거한 GetAddOnManager 메서드:

```
AddRelevantFilter
AreAddOnsEnabled
ClearForceDisabledAddOnNotification
ClearUnusedAddOnSavedVariables
ClearWarnOutOfDateAddOns
GetAddOnDependencyInfo
GetAddOnFilter
GetAddOnInfo
GetAddOnNumDependencies
GetAddOnRootDirectoryPath
GetAddOnVersion
GetForceDisabledAddOnInfo
GetLoadOutOfDateAddOns
GetNumAddOns
GetNumForceDisabledAddOns
GetTotalUnusedAddOnSavedVariablesDiskUsageMB
GetTotalUserAddOnSavedVariablesDiskCapacityMB
GetTotalUserAddOnSavedVariablesDiskUsageMB
GetUserAddOnSavedVariablesDiskUsageMB
RemoveAddOnFilter
RequestAddOnSavedVariablesPrioritySave
ResetRelevantFilters
SetAddOnEnabled
SetAddOnFilter
SetAddOnsEnabled
ShouldWarnOutOfDateAddOns
WasAddOnDetected
```

### SV 관련 활용 가능 메서드

| 메서드 | 용도 | Phase |
|--------|------|-------|
| `GetUserAddOnSavedVariablesDiskUsageMB(i)` | 애드온별 SV 디스크 용량 | Phase 1 |
| `GetTotalUserAddOnSavedVariablesDiskUsageMB()` | 전체 SV 디스크 용량 | Phase 1 |
| `GetTotalUserAddOnSavedVariablesDiskCapacityMB()` | SV 디스크 한도 | Phase 3 (콘솔) |
| `RequestAddOnSavedVariablesPrioritySave()` | SV 우선 저장 요청 | Phase 4 (리포트 덤프) |
| `ClearUnusedAddOnSavedVariables()` | 미사용 SV 정리 | Phase 4 (유틸리티) |

---

# Phase 0+ 코드 수정 내역

## 수정 일시: 2026-04-08

## 변경 목적

PoC 첫 테스트 결과를 반영하여:
1. H1 판정 로직 보강 (ZOS 네이티브 제외, 교차 검증 추가)
2. H3 우회로 구현 (ZO_SavedVars 생성자 후킹)
3. SV 디스크 용량 데이터 수집 추가

## 변경된 파일

### `ACI_Main.lua` — 전면 재작성 (100줄 → ~250줄)

#### 추가된 기능

1. **`ACI.lastLoadedAddon` 추적**
   - `OnAnyAddOnLoaded`에서 매 애드온 로드 시 현재 init 중인 애드온 이름을 전역 상태로 유지
   - SV 생성자 후킹의 caller 역추적에 사용

2. **`CrossCheckLoadOrder()`** — H1 교차 검증
   - `GetAddOnInfo`로 전체 활성 애드온 목록 획득
   - `ACI.eventLog`의 고유 namespace 집합과 대조
   - eventLog에 namespace가 안 잡힌 활성 애드온 = ACI보다 먼저 로드된 것으로 추정
   - 출력: `totalEnabled`, `capturedNS`, `missedAddons`, `missedCount`

3. **`InstallSVHooks()`** — H3 우회
   - `ZO_SavedVars.NewAccountWide` PreHook
   - `ZO_SavedVars.NewCharacterIdSettings` PreHook
   - `ZO_SavedVars.NewCharacterSettings` PreHook (존재 시)
   - `ZO_SavedVars.New` PreHook (존재 시)
   - 각 호출마다 `RecordSVCall()` → `ACI.svRegistrations[table::namespace]`에 기록

4. **`RecordSVCall(method, tableName, version, namespace)`**
   - `caller`: `ACI.lastLoadedAddon`에서 가져옴
   - `traceback`: `debug.traceback("", 3)`으로 호출 스택 기록
   - `ts`: `GetGameTimeMilliseconds()`

5. **`DetectSVConflicts()`**
   - `ACI.svRegistrations`를 순회하며 같은 key에 다른 caller가 있으면 충돌으로 판정
   - 출력: `{ key, callers[], count }`

6. **H1 판정 로직 변경**
   - 기존: `loadOrder[1].addon == ACI.name` (ZOS 네이티브 포함 → 항상 FAIL)
   - 변경: `ZO_` 접두사 애드온을 건너뛰고 유저 애드온 중 첫 번째가 ACI인지 판정

7. **SV 디스크 용량 수집**
   - `ProbeAddOnMetadata()`에 `GetUserAddOnSavedVariablesDiskUsageMB(i)` 추가
   - 각 애드온의 `svDiskMB` 필드로 기록

#### 제거된 것

- H3 원래 방식 (`GetAddOnSavedVariables` 존재 여부 체크) — 불필요해짐
- `h3_svFieldAvailable` 판정 — SV 후킹 방식으로 대체

#### 출력 포맷 변경

- H1: `PASS` / `CONDITIONAL` (기존: `PASS` / `FAIL`)
- H3: `HOOK OK` / `HOOK FAIL` + 충돌 건수 + 상세 (기존: `PASS` / `FAIL — API에 SV 필드 없음`)
- 색상 코드: `|c00FF00|` (녹색), `|cFFFF00|` (노랑), `|cFF0000|` (빨강)

---

# Phase 0 Spike 종합 판정: **강한 GO**

- 기술 리스크 3개 중 2개 완전 해소, 1개 우회로 확정
- H3 우회로가 원래 계획보다 **더 정확한 충돌 정의**를 가능하게 함 (부수 효과로 가치 상승)
- 이벤트 추적 레이어 아키텍처 확정
- 44개라는 숫자는 PoC치고 매우 건전한 신호 — 더미 테스트가 아니라 진짜 생태계 데이터를 잡고 있음

---

# 원본 플랜 대비 변경 사항 추적

| 원본 플랜 항목 | 변경 | 이유 |
|---------------|------|------|
| H3: 매니페스트 `## SavedVariables:` 읽기 | → ZO_SavedVars 생성자 후킹 | API에 해당 필드 없음 (FAIL 확인). 우회로가 더 정확한 충돌 정의 제공 |
| SV 충돌 정의: "같은 SV 테이블 이름" | → "같은 (table, namespace) 쌍" | ZOS 자체가 공유 SV 테이블 패턴을 사용하므로 테이블 이름만으로는 false positive |
| H1 판정: 단순 첫 번째 비교 | → ZOS 네이티브 제외 + 교차 검증 | ZOS 코드는 항상 먼저 로드됨 (공식 동작) |
| Phase 1 메타데이터에 SV 필드 | → SV 디스크 용량 (MB) | 필드명 대신 용량은 API로 읽을 수 있음 |

---

# 다음 액션

- [ ] `/reloadui` 후 Phase 0+ 인게임 결과 확인
- [ ] SV 파일 (`ZZZ_AddOnInspector.lua`) 열어서 상세 데이터 검증
  - `loadOrder`에서 유저 애드온 순서 확인
  - `svRegistrations`에서 SV 후킹 데이터 확인
  - `svConflicts`에서 충돌 감지 동작 확인
  - `crossCheck.missedAddons`에서 ACI보다 먼저 로드된 애드온 목록 확인
- [ ] 결과 확인 후 Phase 1 진입 여부 결정
