# Phase 1 Step 3.5 — Out-of-Date 심층 분석 & embedded 구분

> **작성일**: 2026-04-08
>
> **상태**: 구현 완료, 인게임 검증 대기

---

# 문제 정의

`/aci health` 결과 43개 out-of-date → RED 판정.

**사용자 질문**: "43개 진짜면 심각한 건지, 내 환경이 특수한 건지, 임계값이 민감한 건지?"

---

# SV 데이터 심층 분석

## 원시 수치

| 항목 | 값 |
|------|---|
| GetAddOnManager 총 엔트리 | 67 |
| 활성 (enabled) | 66 |
| Out-of-date (raw) | 43 |
| 현재 API | 101049 (U49, 2026-03-09) |

## 발견: embedded 서브애드온 팽창

ESO의 `GetAddOnManager`는 서브폴더 안에 `.txt` 매니페스트가 있으면 **별도 엔트리**로 등록한다.

### 66개 enabled의 실체

| 구분 | 수 | OOD | OOD% |
|------|---|-----|------|
| **Top-level 폴더** | 56 | 34 | 61% |
| **Embedded 서브애드온** | 10 | 9 | 90% |
| 합계 (raw) | 66 | 43 | 65% |

### Embedded 서브애드온 10개

| 이름 | rootPath | OOD |
|------|---------|-----|
| HarvestMap | HarvestMap/Modules/HarvestMap/ | Y |
| HarvestMapAD | HarvestMapData/Modules/HarvestMapAD/ | Y |
| HarvestMapDC | HarvestMapData/Modules/HarvestMapDC/ | Y |
| HarvestMapDLC | HarvestMapData/Modules/HarvestMapDLC/ | Y |
| HarvestMapEP | HarvestMapData/Modules/HarvestMapEP/ | Y |
| HarvestMapNF | HarvestMapData/Modules/HarvestMapNF/ | Y |
| NodeDetection | HarvestMap/Libs/NodeDetection/ | Y |
| CombatMetricsFightData | CombatMetrics/CombatMetricsFightData/ | Y |
| LibMediaProvider-1.0 | LibMediaProvider/PC/LibMediaProvider-1.0/ | Y |
| LibCombatAlerts | CombatAlerts/LibCombatAlerts/ | N |

### Top-level 34개 OOD 내역

**라이브러리 (18):**
CustomCompassPins, LibAddonMenu-2.0, LibChatMessage, LibCustomMenu, LibDataEncode, LibDialog, LibGPS, LibHarvensAddonSettings, LibMainMenu-2.0, LibMapData, LibMapPing, LibMapPins-1.0, LibMarify, LibNotification, LibQuestData, LibSavedVars, LibTableFunctions-1.0, LibUespQuestData

**본체 애드온 (16):**
Azurah, CircularMinimap, Destinations, LoreBooks, SkyShards, TamrielKR, TamrielKRFontInspector, TamrielKR_Bridge, TamrielTradeCentre, TheQuestingGuide, ToggleErrorUI, USPF, VotansAdaptiveSettings, VotansAdvancedSettings, VotansMiniMap, displayleads

---

# 핵심 분석

## 1. 43개 OOD는 정확하지만 과대 보고

- raw 43개 중 9개는 embedded 서브애드온의 이중 카운트
- 사용자가 실제로 "설치한" top-level 기준으로는 34/56 = 61%
- HarvestMap 생태계 단독 6개 (사용자 체감: 1개)

## 2. 61% OOD는 U49 직후 정상 범위

- 라이브러리 OOD 18/23 (78%) → 라이브러리 작가들의 API 태그 방치가 구조적 원인
- 본체 애드온 OOD 16/33 (48%) → KR 패치 애드온 포함으로 약간 높은 편
- "Allow out of date addons" 체크 시 전부 정상 동작

## 3. 절대값 임계값의 한계

- 애드온 5개 설치 유저: OOD 3개 = 60% (심각)
- 애드온 66개 설치 유저: OOD 43개 = 65% (패치 직후 정상)
- **비율 기반이 유일한 합리적 방법**

---

# 구현 내역

## ACI_Inventory.lua

### 새 함수: `IsEmbeddedAddon(rootPath)`

```lua
local function IsEmbeddedAddon(rootPath)
    if not rootPath then return false end
    if rootPath:find("Managed", 1, true) then return false end  -- 콘솔 경로 가드
    local _, slashCount = rootPath:gsub("/", "")
    return slashCount > 3  -- user:/AddOns/Folder/ = 3, embedded = 4+
end
```

### 수정: `CollectMetadata()`

- 각 애드온에 `isEmbedded` 필드 추가

## ACI_Analysis.lua

### 수정: `ComputeHealthScore()`

- embedded 제외한 `topLevelEnabled`, `topLevelOOD` 집계
- `libOOD`, `addonOOD` 분리
- **비율 기반 임계값**: >0.8 RED, >0.5 YELLOW, >0 INFO
- stats 테이블 확장: `topLevelEnabled`, `topLevelOOD`, `libOOD`, `addonOOD`, `embeddedCount`, `oodRatio`, `deFacto`

### 수정: `FindOrphanLibraries()`

- `a.isEmbedded` 필터 추가 → embedded 라이브러리는 orphan 판정 제외

## ACI_Commands.lua

### 수정: `PrintHealth()`

- OOD를 별도 상세 블록으로 표시 (비율 + embedded 제외 명시)
- 비율 기반 컨텍스트 메시지: 정상 범위인지 해석 제공
- issues 목록에서 OOD 중복 표시 방지

---

# 예상 검증 결과

## Before (현재)

```
● 문제 있음
● 43개 구버전 애드온  (red)
● 6개 불필요한 라이브러리  (yellow)
```

## After (수정 후)

```
● 주의
구버전: 34/56 top-level (61%)
  (embedded 서브애드온 10개 제외)
  라이브러리 18 | 본체 16
  → 패치 후 정상 범위 (1-2개월 내)

● N개 불필요한 라이브러리 (embedded 필터링 후 감소 예상)
```

- RED → YELLOW (61% < 80%)
- 사용자가 상황을 해석할 수 있는 컨텍스트 제공

---

# embedded 감지 전략 비교

| 전략 | 장점 | 단점 | 채택 |
|------|------|------|------|
| 슬래시 카운트 + 콘솔 가드 | 3줄, 빠름, PC 확실 | 콘솔 미지원 | ✅ Phase 1 |
| 폴더명 역추적 (O(n²)) | 플랫폼 독립, parent 식별 | 20줄, 콘솔 전용 이점 | Phase 3 후보 |

---

# Phase 2 이후 후보 아이디어 (이번 단계에서 발견)

- [ ] OOD 세분화: libraries / dependents / standalone / embedded 분리 → "진짜 주목할 OOD"만 하이라이트
- [ ] 콘솔 지원 시 `BuildEmbeddedIndex()` 역추적 방식으로 교체
- [ ] parent 식별: embedded → "HarvestMap > HarvestMapAD" 계층 표시
- [ ] OOD 라이브러리에 의존하는 본체 애드온 식별 ("LibX가 구버전 → 이 애드온들이 영향받을 수 있음")
