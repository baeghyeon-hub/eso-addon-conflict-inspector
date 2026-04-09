# Phase 1 Step 2 — Inventory & Deps 구현 기록

> **작성일**: 2026-04-08
>
> **상태**: Step 2 완료, 인게임 검증 완료

---

# 구현 내역

## Step 2a: 사소한 버그 수정

- **Reset 기능 제거**: live 참조 끊김 버그 + lastLoadedAddon 고정 + loadOrder 시간축 불일치. 유즈케이스 자체가 모호 (reloadui가 자연스러운 reset). 근본적으로 제거.
- **Init 시간 prefix**: `#63` → `load#63`. 정렬 순위가 아닌 로드 인덱스임을 명확히.

## Step 2b: API mismatch 검출

- `GetAPIVersion()` → `metadata.currentAPI`에 기록
- `outOfDateCount`, `libraryCount`, `enabledCount` 집계 추가
- 요약 리포트(`/aci`)에 API 버전 + out-of-date 카운트 표시
- **한계**: GetAddOnManager에 `GetAddOnAPIVersion` 메서드 없음 (managerMethods 덤프 확인). 개별 애드온의 API 버전은 읽을 수 없고, `isOutOfDate` 플래그에만 의존.

## Step 2c: 의존성 역방향 인덱스

`ACI.BuildDependencyIndex()` 추가 (ACI_Analysis.lua):
- `forward[name]` = 이 애드온이 필요로 하는 dep 이름 배열
- `reverse[depName]` = 이 라이브러리를 사용하는 애드온 이름 배열
- `byName[name]` = 애드온 메타데이터 엔트리 참조

## Step 2d: /aci deps [name]

- `/aci deps` — 가장 많이 사용되는 라이브러리 상위 15 + 의존성 없는 애드온 수
- `/aci deps <name>` — 특정 애드온의 forward + reverse (대소문자 무시 매칭)

---

# 인게임 검증 결과

## /aci deps Azurah

- 의존성 2개: LibMediaProvider-1.0 OK, LibAddonMenu-2.0 OK
- 역의존성 0개 (본체 애드온이므로 정상)

## /aci deps (전체 요약)

| 라이브러리 | 사용 수 | 비고 |
|-----------|--------|------|
| LibAddonMenu-2.0 | 16 | 설정 UI 표준. 생태계 정점 |
| LibMapPins-1.0 | 5 | 맵 관련 |
| **HarvestMap** | **5** | **본체 애드온인데 de-facto library** |
| LibGPS | 4 | |
| LibDebugLogger | 4 | |
| LibHarvensAddonSettings | 4 | |
| CustomCompassPins | 4 | |
| LibCustomMenu | 3 | |
| LibMediaProvider | 3 | |
| LibMapData | 3 | |
| LibCombat | 2 | |
| LibDataEncode | 2 | |
| LibMainMenu-2.0 | 2 | |
| LibNotification | 1 | |
| LibMapPing | 1 | |

의존성 없는 애드온: 29개 (75개 중 39%)

## /aci deps LibAddonMenu-2.0

역의존성 16개 전부 정확히 나옴: TamrielTradeCentre, FancyActionBar+, LoreBooks, SkyShards, Azurah, CombatMetrics, USPF, DolgubonsLazyWritCreator, Destinations, HarvestMap, LibAddonMenuSoundSlider, ActionDurationReminder, CrutchAlerts, BeamMeUp, pChat, LostTreasure.

---

# 발견된 인사이트

## 1. HarvestMap = de-facto library

HarvestMap이 `isLibrary: false`인데 5개 애드온(HarvestMapDLC, HarvestMapAD, HarvestMapDC, HarvestMapEP, HarvestMapNF)이 의존. 존별 데이터 애드온의 공통 베이스 역할.

**시사점**:
- `isLibrary` 플래그는 완전히 신뢰할 수 없음
- ACI가 "reverse dep count ≥ 3인 본체 애드온 = de-facto library" 자동 분류 가능
- 이건 시장에 없는 분석. Phase 2 후보.

## 2. 의존성 없는 애드온 39%

75개 중 29개가 standalone. 나머지 46개가 라이브러리 생태계에 얽혀있음.

- ZZZ_ 트릭 실패의 데이터 증거: 61%가 DependsOn으로 엮여서 topological sort가 알파벳 순을 오버라이드
- "의존성 없는 29개 중 ACI를 가장 먼저 로드" 전략은 가능하지만, 이 29개 자체가 대부분 라이브러리(Lib*)이므로 진단적 가치 제한적

## 3. GetUserAddOnSavedVariablesDiskUsageMB

managerMethods 덤프에서 존재 확인됨. 실제 반환값 검증은 다음 SV flush 후.

---

# Phase 1 Step 2 완료 체크

| 항목 | 상태 |
|------|------|
| Reset 버그 수정 (제거) | ✅ |
| Init 시간 prefix | ✅ |
| API mismatch (isOutOfDate 기반) | ✅ |
| 의존성 역방향 인덱스 | ✅ |
| /aci deps [name] | ✅ |
| GetAddOnAPIVersion 확인 | ✅ (없음, isOutOfDate 폴백) |

---

# Phase 2 후보 아이디어 (이번 단계에서 발견)

- [ ] de-facto library 자동 분류 (reverse dep ≥ 3인 본체 애드온)
- [ ] "의존성 고아" 탐지 (설치했지만 아무도 안 쓰는 라이브러리)
- [ ] 이벤트 코드별 hot path 분석 (어떤 EVENT_*에 가장 많은 핸들러가 몰려있나)
- [ ] namespace → 소스 애드온 매핑 (debug.traceback 기반)
