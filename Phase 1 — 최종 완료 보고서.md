# Phase 1 — 최종 완료 보고서

> **작성일**: 2026-04-09
>
> **상태**: Phase 1 완료. 채팅 기반 진단 도구로서 기능 완성.

---

# 1. 가설 검증 결과

| 가설 | 내용 | 결과 | 비고 |
|------|------|------|------|
| H1 | ZZZ_ prefix로 마지막 로딩 → 전수 hook | **조건부 PASS** | DependsOn topological sort가 우선. ACI=#63/75. 그러나 lazy init 패턴으로 222건 포착 → 실용적 충분 |
| H2 | ZO_PreHook EVENT_MANAGER 후킹 | **PASS** | 222건 live 포착. LibCombat 단독 136건 (필터 트릭). ZOS 네이티브 등록도 포착 |
| H3 | ZO_SavedVars 생성자 후킹 | **PASS** | NewAccountWide, NewCharacterIdSettings 등 4개 메서드 hook. 5건 포착, 충돌 0건 |

---

# 2. 구현된 명령어 (11개)

```
/aci            요약 리포트
/aci health     환경 종합 진단 (비율 기반 신호등)
/aci stats      이벤트 등록 통계 (클러스터별)
/aci addons     애드온 목록
/aci deps       가장 많이 쓰이는 라이브러리
/aci deps X     X의 forward/reverse 의존성
/aci init       Init 시간 추정 (상위 10)
/aci orphans    불필요한 라이브러리 + de-facto
/aci hot        이벤트 hot path
/aci sv         SV 등록 + 충돌
/aci dump       진단 데이터를 SV에 저장
/aci debug      embedded 감지 진단
/aci save       SV 강제 저장
/aci help       도움말
```

---

# 3. 진단 기능 전체 목록

| # | 기능 | 파일 | 함수 |
|---|------|------|------|
| 1 | 로드 순서 추적 | ACI_Core.lua | OnAnyAddOnLoaded (EVENT_ADD_ON_LOADED) |
| 2 | 이벤트 등록 live 포착 | ACI_Hooks.lua | InstallEventHook (ZO_PreHook) |
| 3 | SV 충돌 감지 | ACI_Hooks.lua + ACI_Analysis.lua | InstallSVHooks + DetectSVConflicts |
| 4 | 정적 메타데이터 수집 | ACI_Inventory.lua | CollectMetadata (67 애드온) |
| 5 | 의존성 forward/reverse 인덱스 | ACI_Analysis.lua | BuildDependencyIndex |
| 6 | Namespace clustering | ACI_Analysis.lua | ClusterNamespaces (숫자 접미사 제거) |
| 7 | 고아 라이브러리 탐지 | ACI_Analysis.lua | FindOrphanLibraries (embedded 필터 + 오타 힌트) |
| 8 | De-facto library 식별 | ACI_Analysis.lua | FindDeFactoLibraries (reverse dep >= 3) |
| 9 | Event hot path 분석 | ACI_Analysis.lua | FindEventHotPaths (base cluster 단위) |
| 10 | Embedded sub-addon 감지 | ACI_Analysis.lua | TagEmbeddedAddons + IsEmbeddedPath |
| 11 | Health score | ACI_Analysis.lua | ComputeHealthScore (비율 기반 + 컨텍스트) |
| 12 | Init 시간 추정 | ACI_Analysis.lua | EstimateInitTimes (loadOrder ts 차이) |
| 13 | eventCode → 이름 매핑 | ACI_Core.lua | BuildEventNameMap + EventName (lazy init) |

---

# 4. 파일 구조

```
ZZZ_AddOnInspector/
  ZZZ_AddOnInspector.addon    매니페스트 (APIVersion 101049 101050)
  ACI_Core.lua                전역 테이블, SV 초기화, 이벤트 라이프사이클
  ACI_Hooks.lua               ZO_PreHook (EVENT_MANAGER + ZO_SavedVars)
  ACI_Inventory.lua           GetAddOnManager 기반 정적 메타데이터 수집
  ACI_Analysis.lua            clustering, 집계, 충돌 감지, health score
  ACI_Commands.lua            /aci 슬래시 명령어 체계
```

---

# 5. 주요 발견 & 인사이트

## 5.1 LibCombat 필터 트릭 (Step 1)

LibCombat이 172-177개의 고유 namespace(`LibCombat1`, `LibCombat3`, ..., `LibCombat353`)로 이벤트를 등록. ESO의 `AddFilterForEvent` API가 namespace당 1개의 필터만 허용하기 때문에, 필터 조합마다 별도 namespace를 생성하는 트릭.

**시사점**: namespace 수 = "무거움" 지표가 아님. 단일 이벤트(131109, 추정 EVENT_COMBAT_EVENT)에 136건 등록은 필터 트릭이지만 콜백 비용은 존재. 전투 중 fps 병목 용의자 1순위.

## 5.2 대소문자 오타 탐지 (Step 3)

`libAddonKeybinds` (소문자 l) — 다른 애드온들이 `LibAddonKeybinds` (대문자 L)로 DependsOn 걸면 ESO가 매칭 실패. 결과: 애드온은 로드되지만 아무도 참조 못하는 좀비 라이브러리.

dump 16번 항목: `isOutOfDate = false` → 애드온 자체는 정상 로드됨. 근데 orphan 5개에 포함 → 아무도 안 씀.

ACI가 lowercase 비교로 이 패턴을 자동 탐지. 

## 5.3 HarvestMap de-facto library (Step 2)

HarvestMap이 `isLibrary: false`인데 5개 리전별 데이터 애드온이 의존. reverse dep count = 5. ACI가 자동으로 de-facto library로 분류.

HarvestMap의 이중 폴더 구조:
- `HarvestMap/` — 메인 + `Modules/HarvestMap/` (embedded) + `Libs/NodeDetection/` (embedded)
- `HarvestMapData/` — `Modules/HarvestMapAD/`, `DC/`, `DLC/`, `EP/`, `NF/` (모두 embedded)

2개의 최상위 폴더에 7개의 embedded 서브모듈. Phase 2 "addon group" 개념의 시드.

## 5.4 LibAddonMenu-2.0 = 생태계 정점 (Step 2)

reverse dep 16개. ESO 애드온 생태계에서 가장 많이 참조되는 라이브러리.

## 5.5 U49 직후 OOD 분석 (Step 3.5)

| 구분 | 수 | OOD | OOD% |
|------|---|-----|------|
| Top-level 전체 | 56 | 34 | 61% |
| 라이브러리 | 23 | 18 | 78% |
| 본체 애드온 | 33 | 16 | 48% |
| Embedded | 10 | 9 | 90% |

U49 (2026-03-09) 후 1개월. 라이브러리 78% OOD는 구조적 문제 (작가 방치). "Allow out of date addons" 체크 시 전부 정상 동작.

**ACI의 해석**: 61% → "패치 후 정상 범위 (1-2개월 내)". 절대값이 아닌 비율 기반 판정이 유일한 합리적 방법.

## 5.6 embedded 감지 4연속 실패 & 해결 (Step 3.5)

### 현상

CollectMetadata 내부에서 embedded 감지를 4가지 방법으로 시도했으나 전부 embeddedCount=0.
그러나 dump에서 `a.rootPath`(테이블 저장값)로 재계산하면 EMB=10 정상.

### 트러블슈팅 이력

| # | 방법 | 코드 위치 | 결과 |
|---|------|---------|------|
| 1 | `gsub("/","")` 카운트 > 3 | CollectMetadata 내 local function | embeddedCount=0 |
| 2 | `match("/AddOns/(.+)")` → `gsub("/$","")` → `find("/")` | CollectMetadata 내 local function | embeddedCount=0 |
| 3 | `match("/AddOns/[^/]+/.")` | CollectMetadata 내 인라인 | embeddedCount=0 |
| 4 | `find("/AddOns/",1,true)` → `sub` → `find("/",1,true)` | CollectMetadata 내 인라인 | embeddedCount=0 |
| 5 | dump에서 `a.rootPath`로 재계산 (동일 로직) | DumpToSV 내 | **EMB=10 정상!** |

### 초기 가설 → 기각

"Havok Script의 API 반환 문자열에서 string 메서드가 다르게 동작"으로 추정.
그러나 후속 재현 테스트(`/aci debug`)에서 raw API 반환값의 `find`, `match`, `gsub`,
`tostring`, `#`, `type` **전부 정상 동작 확인**. 재현 불가로 **가설 기각**.

(테스트 T7의 `gsub cnt=0`은 테스트 코드의 `and/or` 연산자 우선순위 버그였음)

### 근본 원인 — 미확정

| # | 후보 | 가능성 |
|---|------|--------|
| 1 | PLAYER_ACTIVATED 콜백 시점 환경 차이 | 중 |
| 2 | 코드 경로 미도달 (조건문/스코프 문제) | 중 |
| 3 | 배포 타이밍 | 낮음 |

4번의 실패가 4가지 다른 메서드 때문인지, 같은 근본 원인(코드 경로 미도달 등) 하나가
4번 반복된 건지 당시 디버그 출력이 없어 확인 불가.

### 해결

CollectMetadata에서 isEmbedded 계산을 제거. Analysis 단계에서 저장된 `a.rootPath`로 재계산.

```lua
-- ACI_Analysis.lua 상단
local function IsEmbeddedPath(rootPath)
    if not rootPath then return false end
    local mPos = rootPath:find("/AddOns/", 1, true)
    if not mPos then return false end
    local afterAddons = rootPath:sub(mPos + 8)
    local firstSlash = afterAddons:find("/", 1, true)
    return firstSlash ~= nil and firstSlash < #afterAddons
end

function ACI.TagEmbeddedAddons()
    local meta = ACI_SavedVars and ACI_SavedVars.metadata
    if not meta or not meta.addons then return end
    for _, a in ipairs(meta.addons) do
        a.isEmbedded = IsEmbeddedPath(a.rootPath)
    end
end
```

### 교훈

1. **Evidence-based debugging**: 가설을 통제 실험 없이 확정하면 안 됨
2. **재현 실패 자체가 유용한 정보**: "원인 모름 + 해결됨"이 "잘못된 확신"보다 정직
3. **결과적으로 더 나은 설계**: Inventory=수집, Analysis=분석 분리는 원인과 무관하게 올바른 아키텍처
4. **디버그 코드도 버그 가능**: `and/or` 우선순위가 `gsub` 반환값을 먹는 Lua 함정 주의

---

# 6. 최종 검증 데이터 (dump 00:21:31)

## Health Stats

| Metric | 값 | 검증 |
|--------|---|------|
| embeddedCount | 10 | 예측 10 ✅ |
| topLevelEnabled | 56 | 예측 56 ✅ |
| topLevelOOD | 34 | 예측 34 ✅ |
| oodRatio | 0.6071 | 34/56 = 0.6071 ✅ |
| libOOD | 18 | ✅ |
| addonOOD | 16 | 18+16=34 ✅ |
| orphans | 5 | NodeDetection embedded 빠짐 ✅ |
| svConflicts | 0 | ✅ |
| deFacto | 1 | HarvestMap ✅ |
| hotPaths | 5 | stats raw=5, 출력=4 (ACI 자신 필터링) |

## Embedded 10개

| # | name | rootPath |
|---|------|---------|
| 4 | LibMediaProvider-1.0 | LibMediaProvider/PC/LibMediaProvider-1.0/ |
| 8 | HarvestMapDLC | HarvestMapData/Modules/HarvestMapDLC/ |
| 27 | HarvestMap | HarvestMap/Modules/HarvestMap/ |
| 30 | HarvestMapAD | HarvestMapData/Modules/HarvestMapAD/ |
| 32 | HarvestMapDC | HarvestMapData/Modules/HarvestMapDC/ |
| 34 | HarvestMapEP | HarvestMapData/Modules/HarvestMapEP/ |
| 36 | HarvestMapNF | HarvestMapData/Modules/HarvestMapNF/ |
| 40 | NodeDetection | HarvestMap/Libs/NodeDetection/ |
| 53 | CombatMetricsFightData | CombatMetrics/CombatMetricsFightData/ |
| 65 | LibCombatAlerts | CombatAlerts/LibCombatAlerts/ |

---

# 7. 버그 수정 이력

| # | 문제 | 원인 | 수정 | Step |
|---|------|------|------|------|
| 1 | H2 count 44 vs 222 | PLAYER_ACTIVATED 스냅샷 vs SV flush 시점 | live 테이블 참조로 변경 | 0+ |
| 2 | Reset() 후 hook 깨짐 | 새 테이블 생성 시 PreHook 클로저/SV 참조 끊김 | Reset 기능 완전 제거 | 2 |
| 3 | 명령어 3개 전부 안 먹힘 | RegisterCommands가 PLAYER_ACTIVATED 안에 있어서, 그 전에 에러 나면 등록 실패 | OnACILoaded로 이동 | 3 |
| 4 | if/else 구문 에러 | FindEventHotPaths ACI 자기 필터 추가 시 end 누락 | 구조 수정 | 3 |
| 5 | eventCode 숫자로만 표시 | eventNames 맵이 비어있음 (PLAYER_ACTIVATED 에러 시) | EventName lazy init 추가 | 3 |
| 6 | OOD 43개 → RED 판정 | 절대값 임계값 >5가 너무 민감 | 비율 기반으로 전환 (>0.8 RED, >0.5 YELLOW) | 3.5 |
| 7 | embedded 감지 4연속 실패 | 근본 원인 미확정 (후속 테스트에서 raw string 정상 동작 확인) | Analysis 단계에서 테이블 저장값으로 재계산 | 3.5 |

---

# 8. 알려진 미해결 이슈

| # | 이슈 | 우선순위 | 비고 |
|---|------|---------|------|
| 1 | hotPaths stats=5 vs 출력=4 | 낮음 | ACI 자신 필터가 stats에는 미반영. 표시 단계에서만 필터링 |
| 2 | dump 인덱스 vs loadOrder 인덱스 불일치 | 낮음 | GetAddOnInfo(i)의 i와 EVENT_ADD_ON_LOADED 순서가 다름. 혼동 가능 |
| 3 | `/aci debug`, `/aci dump` 정리 | 낮음 | 트러블슈팅용 명령어. 유지할지 Phase 2에서 제거할지 결정 |

---

# 9. Phase 2 이후 후보 아이디어

## 분석 기능

- [ ] Edit distance 기반 오타 탐지 (Levenshtein 1-2면 오타)
- [ ] "무거운 이벤트 x 무거운 registrant" 경고 (131109 + LibCombat 136)
- [ ] OOD 세분화: libraries / dependents / standalone / embedded 분리
- [ ] OOD 라이브러리에 의존하는 본체 애드온 식별
- [ ] Addon group 개념 (같은 parent dir / 같은 author → 그룹)
- [ ] namespace → 소스 애드온 매핑 (debug.traceback 기반)
- [ ] AzurahATTRIBUTES vs AzurahAttributes clustering missed case

## 플랫폼 & 인프라

- [ ] 콘솔 지원 시 `BuildEmbeddedIndex()` 역추적 방식으로 교체
- [ ] embedded 4연속 실패 근본 원인 확정 (PLAYER_ACTIVATED 콜백 내 재현 테스트)
- [ ] 다른 API 함수 반환값에 대한 string 메서드 동작 체계적 검증 (타이밍 의존 여부)

## embedded 관련

- [ ] LibCombatAlerts가 embedded인데 isLibrary=true — 외부에서 DependsOn 가능한지 검증
- [ ] parent 식별: embedded → "HarvestMap > HarvestMapAD" 계층 표시
- [ ] embedded library의 글로벌 네임스페이스 등록 메커니즘 확인

## UI (Phase 3+)

- [ ] XML + Lua 기반 인게임 UI (Step 5에서 분리)
- [ ] 리포트 내보내기 (텍스트 / 마크다운)

---

# 10. 문서 인덱스

| 문서 | 내용 |
|------|------|
| Phase 0 — PoC 결과 & Phase 0+ 수정 기록.md | H1/H2/H3 검증, PoC 수정 |
| Phase 0 — SV 데이터 분석 & H1 재검토.md | SV 덤프 분석, H1 재해석 |
| Phase 1 — 아키텍처 설계.md | 5파일 분리 구조, 데이터 흐름 |
| Phase 1 Step 2 — Inventory & Deps 구현 기록.md | API mismatch, 의존성 인덱스, /aci deps |
| Phase 1 Step 3 — Analysis 심화 & Health 구현 기록.md | orphan, de-facto, hot path, health |
| Phase 1 Step 3.5 — Out-of-Date 심층 분석 & embedded 구분.md | 43 OOD 분석, embedded 개념 도입 |
| Phase 1 Step 3.5 — embedded 감지 4연속 실패 & 해결.md | 4회 실패 + 재현 테스트 + 해결 (근본 원인 미확정) |
| Phase 1 — 최종 완료 보고서.md | **이 문서** |
| _dump_verified.md | 최종 검증 dump 데이터 |
| _embedded_debug_report.md | embedded 트러블슈팅 진단 dump |

---

# 11. 기술 스택 요약

| 항목 | 내용 |
|------|------|
| 언어 | Lua 5.1 (Havok Script) |
| 대상 | ESO (Elder Scrolls Online) |
| API 버전 | 101049, 101050 |
| Hook 방식 | ZO_PreHook (EVENT_MANAGER, ZO_SavedVars) |
| 데이터 저장 | SavedVariables (live 테이블 참조, flush on reloadui/logout) |
| 배포 | deploy.sh (cp -r to AddOns folder) |

---

**Phase 1 종료. 채팅 기반 진단 도구로서 완성.**
