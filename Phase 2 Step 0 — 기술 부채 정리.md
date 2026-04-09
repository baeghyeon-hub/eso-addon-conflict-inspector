# Phase 2 Step 0 — 기술 부채 정리

> **작성일**: 2026-04-09
>
> **상태**: 실험 1-1 검증 완료, 실험 코드 제거 완료, 나머지 검증 대기

---

# 1-1. embedded 4연속 실패 후속 실험

**목적**: 원래 실패의 근본 원인 확정. 코드 작성 시 자신감 확보.

**구현**: `ACI.RunEmbeddedExperiment()` 함수 추가 (ACI_Inventory.lua)

- PLAYER_ACTIVATED 콜백 안에서, CollectMetadata 직전에 실행
- 테스트 대상: index 1 (top-level), 8 (embedded HarvestMapDLC), 45 (ACI)
- raw `GetAddOnRootDirectoryPath(i)` 값에 직접:
  - `gsub("/", "")` → count
  - `find("/AddOns/", 1, true)` → position
  - IsEmbedded 로직 인라인 실행
- 결과를 채팅창 출력 + `ACI_SavedVars.exp1_1`에 저장

**판정 기준**:
- `gsub=5, find=6, emb=true` (index 8) → 타이밍 무관, 원래 실패는 코드 경로 문제 (가설 #2)
- `gsub=0, find=nil` (index 8) → PLAYER_ACTIVATED 타이밍 이슈 확정 (가설 #1)

**인게임 결과** (2026-04-09 검증 완료):
```
#1  VotansAdvancedSettings  gsub=3  find=6  emb=false  ✅
#8  HarvestMapDLC           gsub=5  find=6  emb=true   ✅
#45 ZZZ_AddOnInspector      gsub=3  find=6  emb=false  ✅
```

**확정 결론**: PLAYER_ACTIVATED 타이밍 이슈 **아님** (가설 #1 기각).
raw API 반환값에서 `gsub`, `find`, `sub` 전부 정상 동작.
원래 4연속 실패는 **코드 경로 문제** (가설 #2) — 상위 로직의 조건문/변수명/저장 단계 오류.
같은 하나의 버그가 네 번 반복된 것이지, API 레벨 Havok 이슈가 아니었음.

**수확**:
- "Havok String Bug" ESOUI 포럼 리포트 → 완전 철회
- raw API 값에 패턴 매칭 써도 됨. 회피 불필요
- 현재 아키텍처는 "Havok 버그 회피"가 아닌 "관심사 분리" 이유로 정당

**실험 코드 제거 완료**. SV의 `exp1_1` 필드도 1회성 nil 할당으로 정리.

---

# 1-2. ACI.Reset() 잔여물 확인

**결과**: **잔여물 없음. 클린.**

- `ACI.eventLog = {}`, `ACI.svRegistrations = {}`, `ACI.loadOrder = {}` — 초기화 선언만 존재 (ACI_Core.lua 상단)
- 이후 재할당하는 코드 없음
- Reset() 함수 흔적 없음
- `wipe()` 패턴 불필요

---

# 1-3. 인덱스 체계 정리

**문제**: `GetAddOnInfo(i)` 순서(dump index)와 `EVENT_ADD_ON_LOADED` 순서(loadOrder index) 불일치.
예: ZZZ_AddOnInspector → dump #45, loadOrder #63

**변경**:

| 파일 | 변경 |
|------|------|
| ACI_Core.lua | `ACI.loadOrderMap = {}` 추가, `OnAnyAddOnLoaded`에서 `loadOrderMap[addonName] = loadIndex` 구축 |
| ACI_Inventory.lua | `CollectMetadata`에서 `loadOrderIndex = ACI.loadOrderMap[name]` 필드 추가 |
| ACI_Commands.lua | dump에 `dumpIndex`, `loadOrderIndex` 필드 추가 |

**효과**: 이제 모든 애드온 엔트리에 두 인덱스가 공존. dump에서 차이 확인 가능.

---

# 1-4. ACI self-filter 일관성

**문제**: ACI 자신의 이벤트/SV 등록이 통계에 포함되어 숫자가 미세하게 부풀림.

**해결**: `ACI.IsSelfNamespace(ns)` 유틸 함수 하나로 일관 적용.

```lua
function ACI.IsSelfNamespace(ns)
    return ns and ns:find(ACI.name, 1, true) ~= nil
end
```

**적용 현황**:

| 기능 | 적용 방식 | 변경 |
|------|----------|------|
| FindEventHotPaths | `IsSelfNamespace` | 기존 하드코딩 → 유틸 호출로 리팩토링 |
| ClusterNamespaces | `IsSelfNamespace` | **새로 추가** |
| event log 카운트 (Report/Stats/Health) | `EventCountExcludingSelf()` | **새로 추가** |
| SV 카운트 (Report/SV) | `IsSelfNamespace(caller)` | **새로 추가** |
| SV 목록 (PrintSV) | `IsSelfNamespace(caller)` | **새로 추가** |

`EventCountExcludingSelf()` 헬퍼 함수도 ACI_Analysis.lua에 추가.

---

# 변경 파일 요약

| 파일 | 변경 사항 |
|------|----------|
| ACI_Core.lua | `IsSelfNamespace()` 유틸, `loadOrderMap` 필드, `RunEmbeddedExperiment()` 호출 |
| ACI_Inventory.lua | `RunEmbeddedExperiment()` 함수, `loadOrderIndex` 필드 |
| ACI_Analysis.lua | `EventCountExcludingSelf()`, ClusterNamespaces self-filter, hot path 리팩토링 |
| ACI_Commands.lua | 이벤트/SV 카운트 self-filter 적용, dump에 인덱스 필드 추가 |

---

# 인게임 검증 항목

- [ ] 실험 1-1: PLAYER_ACTIVATED 시점 raw string 연산 결과 확인
- [ ] self-filter: `/aci` 이벤트 카운트가 이전보다 약간 줄어야 함 (ACI 자신의 등록 제외)
- [ ] self-filter: `/aci sv` 에서 ACI_SavedVars 관련 항목 제외됨
- [ ] self-filter: `/aci stats` 에서 ACI 클러스터 제외됨
- [ ] loadOrderIndex: `/aci dump` 에서 dumpIndex vs loadOrderIndex 차이 확인
