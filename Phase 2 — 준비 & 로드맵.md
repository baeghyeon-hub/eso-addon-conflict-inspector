# Phase 2 — 준비 & 로드맵

> **작성일**: 2026-04-09
>
> **Phase 1 완료 기준**: 11개 명령어, 13개 진단 기능, embedded 감지, health score

---

# 1. 기술 부채 정리 (Phase 2 진입 전 필수)

## 1-1. embedded 4연속 실패 후속 실험

**목적**: 원래 실패의 근본 원인 확정. 코드 작성 시 자신감 확보.

**실험 A**: PLAYER_ACTIVATED 콜백 안에서 동일 테스트

```lua
-- ACI_Core.lua의 PLAYER_ACTIVATED 콜백에 임시 추가
local manager = GetAddOnManager()
local rootPath = manager:GetAddOnRootDirectoryPath(8) -- HarvestMapDLC
local _, cnt = rootPath:gsub("/", "")
local found = rootPath:find("/AddOns/", 1, true)
d("[ACI] PA test: gsub count=" .. tostring(cnt) .. " find=" .. tostring(found))
```

- `cnt=5, found=6` → 타이밍 무관, 원래 실패는 코드 경로 문제
- `cnt=0, found=nil` → PLAYER_ACTIVATED 타이밍 이슈 확정

**실험 B**: 당시 CollectMetadata 코드 복원 + 디버그 로그

```lua
-- isEmbedded 계산 직전에 추가
d("[ACI] EMB_CHECK: i=" .. i .. " rootPath=" .. tostring(rootPath))
```

- 출력됨 → 코드 도달했지만 연산 실패
- 안 나옴 → 코드 경로 미도달 (스코프/조건문 문제)

## 1-2. ACI.Reset() 상태 확인

Phase 0+에서 Reset()을 제거했으나, 코드에 잔여물이 있는지 확인 필요.

- `ACI.eventLog = {}` 새 테이블 생성 → PreHook 클로저 참조 끊김
- `ACI.svRegistrations = {}` → SV live 참조 끊김
- `ACI.lastLoadedAddon` 갱신 중단

확인 후: 잔여 Reset 코드 완전 제거, 또는 안전한 `wipe(table)` 패턴으로 대체.

```lua
-- 안전한 wipe (테이블 참조 유지)
local function wipe(t)
    for k in pairs(t) do t[k] = nil end
end
```

## 1-3. 인덱스 체계 정리

현재 혼동 포인트:
- `GetAddOnInfo(i)` → addon manager 순서 (dump index)
- `EVENT_ADD_ON_LOADED` 순서 → loadOrder index
- ZZZ_AddOnInspector: dump #45, loadOrder #63

**해결**: `metadata.addons[i]`에 `loadOrderIndex` 필드 추가.

```lua
-- ACI_Core.lua의 OnAnyAddOnLoaded에서 매핑 구축
ACI.loadOrderMap[addonName] = loadIndex

-- ACI_Inventory.lua의 CollectMetadata에서 참조
loadOrderIndex = ACI.loadOrderMap[name] or nil
```

## 1-4. ACI self-filter 일관성

| 기능 | ACI 제외 여부 | 상태 |
|------|-------------|------|
| hot path | O | 구현됨 |
| event log 총 카운트 | X | 미구현 |
| SV 등록 | X | 미구현 |
| orphan/de-facto | 해당 없음 | - |
| health stats | event 카운트에 ACI 포함 | 미구현 |

**해결**: `ACI.IsSelfNamespace(ns)` 유틸 함수 하나로 일관 적용.

```lua
function ACI.IsSelfNamespace(ns)
    return ns and ns:find(ACI.name, 1, true) ~= nil
end
```

---

# 2. Phase 2 핵심 기능 (우선순위 순)

## A. 오타 힌트 — 설치 오류 진단 (최우선)

**가치**: 시장에 비슷한 도구 없음. ACI의 차별화 포인트.

**케이스**: `libAddonKeybinds` (소문자 l) vs `LibAddonKeybinds` (대문자 L)
- 애드온은 로드됨 (isOutOfDate=false)
- 아무도 참조 못함 (orphan)
- DependsOn에는 대문자 L로 걸려있어서 ESO가 매칭 실패

**구현**:

```lua
-- 대소문자 무시 역방향 매칭
local lowerName = a.name:lower()
for depName in pairs(depIndex.reverse) do
    if depName ~= a.name and depName:lower() == lowerName then
        -- 오타 힌트: depName으로 의존성 걸렸는데 실제 폴더명은 a.name
        typoHint = depName
    end
end
```

**이미 부분 구현됨** (FindOrphanLibraries에 lowercase 비교 존재). Phase 2에서:
- 독립 함수로 분리
- edit distance 1-2도 추가 (Levenshtein)
- `/aci orphans` 출력에 "오타 교정 제안" 메시지

## B. OOD 세분화 분류

현재: "34/56 top-level 구버전 (61%)"
목표: "본체 standalone 8개만 진짜 주목, 나머지는 무시 가능"

```lua
local oodStats = {
    libOnly     = 0,  -- 라이브러리만 OOD (작가 방치, 대부분 동작)
    dependents  = 0,  -- OOD 라이브러리에 의존하는 본체 (간접 영향)
    standalone  = 0,  -- 본체 OOD, 의존성 문제 없음 (사용자가 업데이트해야 함)
    embedded    = 0,  -- parent와 함께 취급
}
```

`/aci health`에서:
```
구버전 34/56 (61%)
  무시 가능: 라이브러리 18 + embedded 9
  주의: 본체 standalone 7개
  → Azurah, LoreBooks, SkyShards, ...
```

## C. Event hot path × heavy registrant 교차 분석

**가설**: LibCombat 136 registrations on EVENT_COMBAT_EVENT → 전투 중 fps 병목 용의자.

**문제**: ESO에 `debug.profile` 없음. 콜백 호출 빈도 직접 측정 불가.

**우회**:
- ZO_PreHook으로 콜백 래핑 → 호출 횟수/시간 측정
- 단, 모든 콜백 래핑은 성능 영향 → Phase 3 프로파일링 범위

Phase 2에서는 "등록 수 × 이벤트 빈도(추정)" 매트릭스까지만:
- EVENT_COMBAT_EVENT: 매우 빈번 (전투 중 프레임당 수십 회)
- EVENT_PLAYER_ACTIVATED: 1회성
- "빈번 이벤트에 많은 등록" = 경고 대상

## D. Addon group 개념

HarvestMap의 이중 폴더 구조:
- `HarvestMap/` + `HarvestMapData/` = 사용자 체감 "HarvestMap 하나"
- 7개 embedded 서브모듈

**그룹 기준 후보**:
1. rootPath의 첫 번째 폴더명 공유
2. 같은 author
3. 이름 prefix 공유 (HarvestMap*)
4. 의존성 클러스터 (서로 의존하는 그룹)

Phase 2 후반 또는 UI 작업 시작할 때.

---

# 3. 탐구/실험 과제

## E. Dummy conflict addon (SV 충돌 테스트)

현재 환경: 충돌 0건. DetectSVConflicts 로직이 실제로 작동하는지 미검증.

**방법**: 테스트용 더미 애드온 2개 생성, 같은 SV 테이블+namespace 쌍 사용.

```
DummyConflictA/
  DummyConflictA.txt  → SavedVariables: TestConflictSV
  init.lua            → ZO_SavedVars.NewAccountWide("TestConflictSV", 1, nil, {})

DummyConflictB/
  DummyConflictB.txt  → SavedVariables: TestConflictSV
  init.lua            → ZO_SavedVars.NewAccountWide("TestConflictSV", 1, nil, {})
```

`/aci sv`에서 충돌 1건 나오면 성공.

## F. GetUserAddOnSavedVariablesDiskUsageMB 확인

Phase 1 dump의 `managerMethods`에 이미 수집돼 있을 수 있음.
SV 파일에서 확인만 하면 됨.

- 있음 → 애드온별 SV 용량 표시 가능
- 없음 → 대안: SV 파일 크기 직접 측정 (불가능, io 모듈 없음)

## G. OptionalDependsOn 로드 순서 실험

ACI 매니페스트에 주요 Lib을 OptionalDependsOn으로 추가:

```
## OptionalDependsOn: LibDebugLogger LibAddonMenu-2.0 LibCombat HarvestMap
```

**기대**: DependsOn topological sort에 의해 ACI 로드 순서가 #63 → 더 뒤로.
(OptionalDependsOn이 토폴로지 정렬에 포함되는지 확인 필요)

**위험**: OptionalDependsOn이 "해당 애드온이 없으면 무시"인지 "해당 애드온보다 뒤에 로드"인지 ESO 문서가 불명확. 실험 필요.

## H. Namespace → addon 역추적 (debug.traceback)

현재: `lastLoadedAddon` 휴리스틱 (EVENT_ADD_ON_LOADED 순서 기반)
문제: PLAYER_ACTIVATED 이후 등록되는 이벤트는 역추적 불가

**실험**:
```lua
ZO_PreHook(EVENT_MANAGER, "RegisterForEvent", function(self, ns, code, callback)
    local trace = debug.traceback("", 2)
    -- trace에서 파일 경로 추출 → 애드온 폴더명 역추적
    local addonFolder = trace:match("user:/AddOns/([^/]+)/")
    -- ...
end)
```

`debug.traceback`이 ESO에서 파일 경로를 포함하는지 확인 필요.
Phase 1의 SV hook에서 이미 traceback을 기록하고 있음 → 기존 데이터 확인.

---

# 4. 실행 순서 (제안)

| 순서 | 작업 | 예상 시간 | 의존성 |
|------|------|---------|--------|
| 0 | 기술 부채 정리 (1-1 ~ 1-4) | 30분 | 없음 |
| 1 | A. 오타 힌트 강화 | 20분 | 없음 |
| 2 | B. OOD 세분화 | 30분 | A 완료 후 (orphan 연동) |
| 3 | F. SV 용량 API 확인 | 5분 | 없음 |
| 4 | G. OptionalDependsOn 실험 | 10분 | 없음 |
| 5 | E. Dummy conflict 테스트 | 15분 | 없음 |
| 6 | C. Hot path 교차 분석 | 30분 | 없음 |
| 7 | H. traceback 역추적 실험 | 20분 | 없음 |
| 8 | D. Addon group | Phase 2 후반 | B, H 결과에 따라 |

3, 4, 5는 독립 실험이라 어느 순서로든 가능. 기술 부채(0)는 반드시 먼저.

---

# 5. Phase 2 완료 기준 (잠정)

- [ ] embedded 실패 근본 원인 확정 또는 "재현 불가 + 문서화"로 종결
- [ ] 오타 힌트가 libAddonKeybinds 케이스를 정확히 잡음
- [ ] OOD 세분화가 `/aci health`에서 "주목할 것 N개" 형태로 출력
- [ ] ACI self-filter 일관 적용
- [ ] 최소 1건의 SV 충돌 테스트 (dummy addon)
- [ ] Phase 2 완료 보고서 작성
