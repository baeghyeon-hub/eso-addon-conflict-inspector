# Phase 0 — SV 데이터 분석 & H1 재검토

> **작성일**: 2026-04-08
>
> **상태**: SV 데이터 1차 분석 완료. H1 전략 재검토 필요.
>
> **데이터 출처**: `SavedVariables/ZZZ_AddOnInspector.lua` (첫 번째 PoC 실행분, 3682줄)

---

# 1. eventLog 분석 — 실제 222개 (채팅 표시 44개는 부정확)

## 버그 발견

채팅에 `가로챈 RegisterForEvent: 44`로 표시됐으나, SV 파일에는 **222개** 기록됨.

**원인**: `h2_capturedCount`를 `EVENT_PLAYER_ACTIVATED` 시점에 `#ACI.eventLog`로 찍었는데, PLAYER_ACTIVATED 이후에도 RegisterForEvent 호출이 계속 들어옴. SV flush는 /reloadui 또는 로그아웃 시점이라 그 사이에 178개가 추가 적재됨.

**시사점**: 
- PLAYER_ACTIVATED 시점의 스냅샷은 불완전. 최종 리포트는 SV flush 직전이나 슬래시 명령어 호출 시점에 생성해야 함.
- 또는 `RequestAddOnSavedVariablesPrioritySave()` 호출로 원하는 시점에 flush 가능.

## namespace별 등록 분포

| 애드온 (namespace 그룹) | 등록 수 | namespace 패턴 | 비고 |
|------------------------|--------|---------------|------|
| **LibCombat** | **172** | `LibCombat1`, `LibCombat3`, ... `LibCombat353` (홀수) | AddFilterForEvent 때문에 개별 namespace 필요 |
| **Azurah** | **16** | `AzurahAttributes`, `AzurahTarget`, `AzurahBossbar`, `AzurahUltimate`, `AzurahExperience`, `AzurahCompass` | 모듈별 namespace |
| **CrutchAlerts** | **11** | `CrutchAlertsEffectAlert{ID}`, `CrutchAlertsOthersBegin{ID}`, `CrutchAlertsOthersFaded{ID}`, `CrutchAlertsOthersGained{ID}`, `CrutchAlertsOthersGainedDuration{ID}` | 스킬 ID별 namespace |
| **CombatAlerts** | **5** | `CombatAlerts` | |
| **LCA_RoleMonitor** | **2** | `LCA_RoleMonitor` | LibCombatAlerts 내부 |
| **CA_ReformGroup** | **2** | `CA_ReformGroup` | CombatAlerts 내부 |
| **FancyActionBar+** | **4** | `FancyActionBar+`, `FancyActionBar+UltValue`, `FancyActionBar_ScreenResize` | |
| **LostTreasure** | **2** | `Lost Treasure`, `LostTreasure_TemporaryFix` | |
| **BUI_Event** | **1** | `BUI_Event` | BanditsUserInterface |
| **LibCodesCommonCode29_5** | **1** | `LibCodesCommonCode29_5` | |
| **ZZZ_AddOnInspector** | **1** | `ZZZ_AddOnInspector` | ACI 자신 (EVENT_PLAYER_ACTIVATED) |

## 핵심 인사이트

### 1. LibCombat는 이벤트 등록 monster

172개 — 전체 222개의 **77%**. namespace마다 홀수 번호를 붙여서 개별 등록하는 이유는 ESO API의 `AddFilterForEvent` 제약 때문:
- `RegisterForEvent`의 namespace는 고유해야 함
- 같은 이벤트에 다른 필터를 걸려면 다른 namespace로 등록해야 함
- LibCombat는 다양한 combat log 이벤트를 세밀하게 필터링하므로 namespace 폭발

**Phase 2 설계 시사점**:
- "헤비 애드온" 판정 시 단순 등록 수보다 **고유 namespace 접두사 기준**으로 그룹핑 필요
- `LibCombat{N}` → `LibCombat`로 정규화하면 172개가 1개 애드온의 등록으로 올바르게 집계됨
- 임계값: namespace 접두사 기준 50개 이상이면 "heavy" 표시가 적절해 보임

### 2. namespace ≠ 애드온 이름 — CrossCheck 로직 수정 필요

대부분의 애드온이 namespace를 애드온 폴더 이름과 **다르게** 사용:
- `Azurah` 애드온 → `AzurahTarget`, `AzurahBossbar`, ...
- `BanditsUserInterface` 애드온 → `BUI_Event`
- `LibCombat` 애드온 → `LibCombat1`, `LibCombat3`, ...
- `CombatAlerts` → `CA_ReformGroup`, `LCA_RoleMonitor`

**→ CrossCheck의 "63개 놓침"은 대부분 false positive.** namespace 문자열이 애드온 이름과 일치하지 않아서 매칭 실패한 것.

**수정 방향**: namespace → 애드온 매핑에 fuzzy matching 또는 접두사 매칭 적용. 또는 `lastLoadedAddon` 기반 추적(Phase 0+ 코드)이 더 정확.

### 3. 이벤트 코드 분포

| eventCode | 등록 수 | 추정 이벤트 |
|-----------|--------|------------|
| 131109 | **~120** | EVENT_COMBAT_EVENT (가장 많음) |
| 131158 | ~20 | EVENT_EFFECT_CHANGED |
| 131129 | ~8 | EVENT_POWER_UPDATE |
| 589824 | 6 | EVENT_PLAYER_ACTIVATED |
| 131137 | 5 | EVENT_UNIT_DEATH_STATE_CHANGED |
| 131459 | 4 | EVENT_PLAYER_ACTIVATED? or GROUP |
| 기타 | 각 1~3 | 다양 |

**EVENT_COMBAT_EVENT (131109)가 압도적 hot path.** LibCombat가 이 이벤트에 대해 수십 가지 필터를 거는 것. Phase 2에서 hot path 경고의 첫 번째 후보.

---

# 2. loadOrder 분석 — H1은 진짜 FAIL

## 전체 로딩 순서

```
[ZOS 네이티브 — 9개]
 #1  ZO_FontStrings         ts=2474108
 #2  ZO_FontDefs            ts=2474108
 #3  ZO_AppAndInGame        ts=2474108
 #4  ZO_IngameLocalization  ts=2474109
 #5  ZO_Libraries           ts=2474109
 #6  ZO_Common              ts=2474109
 #7  ZO_PregameAndIngame    ts=2474109
 #8  ZO_PublicAllIngames    ts=2474109
 #9  ZO_Ingame              ts=2474278  ← ZOS 로드만 170ms

[유저 애드온 — 66개]
 #10 LibHarvensAddonSettings  ts=2474286  ← 첫 유저 애드온
 #11 VotansAdvancedSettings   ts=2474287
 #12 LibDebugLogger           ts=2474287
 #13 LibAddonMenu-2.0         ts=2474287
 #14 LibCustomMenu            ts=2474287
 #15 TamrielTradeCentre       ts=2474608  ← DependsOn: LAM, LibCustomMenu
 #16 LibMediaProvider          ts=2474608
 #17 LibMediaProvider-1.0      ts=2474608
 #18 Azurah                    ts=2474619
 #19 BanditsUserInterface      ts=2474938
 #20 FancyActionBar+           ts=2474949
 ...
 #63 ZZZ_AddOnInspector        ts=2478919  ← 유저 애드온 54/66번째
 #64 LibSavedVars              ts=2478923
 #65 LibCombatAlerts           ts=2478923
 #66 CombatAlerts              ts=2478923
 #67 LibQuestData              ts=2478925
 #68 DolgubonsLazyWritCreator-KR-Mini  ts=2478949
 #69 TamrielTradeCentre-KR-Minion     ts=2478949
 #70 ToggleErrorUI             ts=2478949
 #71 LibNotification           ts=2478949
 #72 TheQuestingGuide          ts=2478958
 #73 LibDialog                 ts=2478962
 #74 CrutchAlerts-KR-Minion    ts=2478962
 #75 LostTreasure              ts=2478962
```

## H1 결론

**ZZZ_ 역알파벳 트릭은 사실상 실패.** 유저 애드온 66개 중 54번째로 로드됨.

### 실패 원인

ESO의 로딩 순서 규칙 재정리:
1. **DependsOn/OptionalDependsOn이 모든 것을 지배함.** 대부분의 애드온이 Lib*에 DependsOn을 걸고 있어서 의존성 트리가 알파벳 순을 완전히 오버라이드.
2. **역알파벳 순은 "의존성이 없는 애드온들 사이에서만" 적용됨.** 의존성이 있는 애드온은 의존성 해결 순서가 우선.
3. ACI는 `OptionalDependsOn: LibDebugLogger`만 있는데, 이건 LibDebugLogger가 있으면 그 뒤에 로드된다는 의미. 하지만 다른 애드온들이 더 깊은 의존성 체인을 갖고 있어서 그것들이 먼저 해결됨.

### 이것이 ACI에 미치는 영향

**PreHook 설치 시점이 늦다** = init 시점(EVENT_ADD_ON_LOADED) 동안의 RegisterForEvent 호출은 #10~#62 애드온 것을 놓침.

**그러나 이건 치명적이지 않다.** 이유:
1. init 시점의 RegisterForEvent는 대부분 EVENT_ADD_ON_LOADED 자체 등록 (1~2개). 진짜 대량 등록은 PLAYER_ACTIVATED 이후에 발생 (LibCombat 172개가 증거).
2. **현재 222개 중 대부분이 ACI 로드 이후 시점에 잡힌 것.** PreHook은 한번 설치되면 그 이후 모든 호출을 잡음.
3. Phase 1의 핵심 기능(애드온 목록, 메타데이터, 의존성 트리)은 `GetAddOnManager` API 기반이라 로딩 순서와 무관.

### H1 전략 수정안

**원래 전략**: ZZZ_ 폴더명으로 가장 먼저 로드 → 모든 RegisterForEvent를 가로챔

**수정된 전략**: 로딩 순서는 포기. 대신:
1. **init 단계 추적**: EVENT_ADD_ON_LOADED 이벤트 자체는 가장 처음에 등록 가능 (파일 로드 시점 = 매니페스트 파싱 직후). 이걸로 모든 애드온의 로딩 순서와 init 시간 측정은 가능.
2. **runtime 단계 추적**: PreHook은 ACI 로드 후부터 작동. init 동안 놓친 등록은 정직하게 "ACI 로드 전 등록, 추적 불가"로 표시.
3. **PLAYER_ACTIVATED 이후 등록이 진짜 중요한 데이터**: 성능 영향이 큰 이벤트(combat, effect 등)는 대부분 이 시점에 등록됨. 222개 중 init 시점 등록은 소수.

---

# 3. 타임라인 분석

전체 로딩 시간: `ts 2474108` ~ `ts 2480025` = **약 5.9초**

| 구간 | 시간(ms) | 비고 |
|------|---------|------|
| ZOS 네이티브 (#1~#9) | ~170 | 빠름 |
| 유저 애드온 init (#10~#75) | ~4640 | 느림 |
| PLAYER_ACTIVATED 이후 등록 | ~1100 | LibCombat 대량 등록 포함 |

TamrielTradeCentre (#15, ts=2474608): init만 ~320ms — 무거운 애드온의 첫 번째 후보.
LibMapData (#28, ts=2475763): 이전 애드온(#27)과 ~800ms 차이 — 느린 init.
CombatMetrics (#43, ts=2477970): 이전(#42)과 ~1200ms — 매우 무거운 init.

**Phase 3의 "각 애드온 init 시간 추정"은 이 데이터로 이미 가능.** loadOrder의 연속 ts 차이가 곧 각 애드온의 init 소요 시간.

---

# 4. 다음 액션

- [ ] Phase 0+ SV 데이터 확보 (게임에서 /reloadui 필요 — 현재 SV는 첫 번째 PoC 것)
- [ ] eventLog 카운트 버그 수정: PLAYER_ACTIVATED 시점이 아닌 슬래시 명령어 또는 SV flush 직전에 최종 카운트
- [ ] CrossCheck 로직 수정: namespace → 애드온 매핑에 접두사 매칭 또는 lastLoadedAddon 기반 추적
- [ ] H1 전략 문서 업데이트: ZZZ_ 트릭 포기, 새 전략 반영
- [ ] Phase 1 UI 설계에 LibCombat 같은 heavy registrant 패턴 고려
- [ ] Phase 3 init 시간 측정은 loadOrder ts 차이로 구현 가능 확인됨
