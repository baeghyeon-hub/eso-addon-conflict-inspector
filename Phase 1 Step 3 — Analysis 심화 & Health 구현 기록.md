# Phase 1 Step 3 — Analysis 심화 & Health 구현 기록

> **작성일**: 2026-04-08
>
> **상태**: 구현 완료, 인게임 검증 1차 완료 → 임계값 조정 배포됨

---

# 구현 내역

## ACI_Core.lua

- `BuildEventNameMap()` — `_G` 순회하여 `EVENT_` 접두사 전역변수 → code:name 매핑
- `EventName(code)` — lazy init 포함. eventNames가 비어있으면 자동 구축

## ACI_Analysis.lua

### 새 함수 4개

1. **`FindOrphanLibraries()`** — `isLibrary=true` + enabled인데 활성 애드온 중 아무도 DependsOn 안 건 것
   - 대소문자 오타 탐지 내장: orphan 이름의 lowercase가 다른 dep의 lowercase와 같으면 `typoHint` 반환
2. **`FindDeFactoLibraries(threshold)`** — `isLibrary=false`인데 reverse dep ≥ threshold
3. **`FindEventHotPaths(threshold)`** — base cluster 기준 hot path. ACI 자신의 등록 제외.
4. **`ComputeHealthScore()`** — SV 충돌, 구버전, 고아 라이브러리 종합 → red/yellow/green

### 수정

- `BuildDependencyIndex()` — reverse를 enabled 애드온의 deps만으로 집계 (고아 탐지 정확도)

## ACI_Commands.lua

### 새 명령어 3개

- `/aci orphans` — 고아 라이브러리 (오타 힌트 포함) + de-facto library
- `/aci hot` — 이벤트 hot path (eventName 표시, base cluster 상세)
- `/aci health` — 신호등 진단

### 수정

- 슬래시 명령어 등록을 PLAYER_ACTIVATED → OnACILoaded로 이동 (에러 시 명령어 등록 실패 방지)

---

# 인게임 검증 결과 (1차)

## /aci health — 빨간불

| 항목 | 값 | 판정 |
|------|---|------|
| out-of-date | 43개 | RED (임계값 >5) |
| orphan | 6개 | YELLOW (>3) |
| SV 충돌 | 0건 | OK |
| hot path | 5개 | 정보 수준 |

### 43개 out-of-date 해석

U49 (2026-03-09) 직후 시즌. 작가들이 API 버전 태그 미업데이트. "Allow out of date addons" 체크박스 켜둔 상태라 실제로는 동작하지만 isOutOfDate=true. **ACI의 진단은 정확하지만, 임계값이 너무 민감했음.**

→ 임계값 조정: `>20` RED, `>10` YELLOW, `>0` INFO

## /aci orphans — 6개

| 라이브러리 | 오타? | 비고 |
|-----------|------|------|
| **libAddonKeybinds** | **가능성 높음** | 소문자 `l`로 시작. 다른 애드온은 `LibAddonKeybinds`(대문자)로 DependsOn |
| LibZone | - | |
| NodeDetection | - | |
| LibMarify | - | |
| LibQuestData | - | |
| LibDialog | - | |

### 대소문자 오타 발견

`libAddonKeybinds` (소문자 l) — 다른 애드온들이 `LibAddonKeybinds` (대문자 L)로 DependsOn 걸고 있을 가능성. 폴더명 오타로 인해 매칭 실패 → orphan으로 분류됨. **ACI가 설치 오류를 자동 진단한 사례.**

→ 오타 힌트 기능 추가: orphan 이름의 lowercase가 다른 dep의 lowercase와 같으면 경고

## /aci hot — 5개 hot path

| eventCode | base 수 | 총 등록 | 추정 이벤트 | 주요 registrant |
|-----------|--------|--------|-----------|----------------|
| 589824 | 7 | 9 | EVENT_PLAYER_ACTIVATED? | ZO_Frame, LibCombat, CombatAlerts, ACI |
| 131129 | 6 | 8 | EVENT_POWER_UPDATE? | LibCombat, FAB+, Azurah |
| 131109 | 5 | 141 | EVENT_COMBAT_EVENT? | LibCombat×136, CrutchAlerts |
| 131459 | 4 | 5 | GROUP/ROLE? | CombatAlerts, LibCombat, LCA, Azurah |
| 65540 | 3 | 7 | EVENT_SCREEN_RESIZED? | ZO_Frame, ZO_ItemPreview, FAB |

### 핵심 인사이트

- **131109 (추정 EVENT_COMBAT_EVENT)**: LibCombat 단독 136건. 단일 이벤트에 단일 애드온이 136개 namespace로 등록. 필터 트릭이지만 실제 콜백 비용 존재. 전투 중 fps 병목 용의자 1순위.
- **ACI 자신이 hot path에 포함**: 589824에 자기 등록이 잡힘 → ACI 제외 필터 추가함
- **eventCode → 이름 매핑**: 숫자로만 나와서 읽기 어려움 → EventName lazy init 추가
- **ZOS 네이티브 코드도 일부 잡힘**: `ZO_FramePlayerTargetFragment`, `ZO_ItemPreview_Shared` — PLAYER_ACTIVATED 이후 ZOS가 추가 등록한 것

---

# 즉시 개선 4건 (2차 배포)

| # | 개선 | 상세 |
|---|------|------|
| 1 | out-of-date 임계값 완화 | >20 RED, >10 YELLOW, >0 INFO |
| 2 | ACI 자신 hot path 제외 | `namespace:find(ACI.name)` 필터 |
| 3 | EventName lazy init | eventNames 비어있으면 자동 구축 |
| 4 | orphan 오타 힌트 | lowercase 비교로 대소문자 오타 탐지 |

---

# Phase 2 이후 후보 아이디어 (이번 단계에서 발견)

- [ ] edit distance 기반 오타 탐지 (현재는 대소문자만. Levenshtein 1-2면 오타)
- [ ] "무거운 이벤트 × 무거운 registrant" 경고 (131109 + LibCombat 136)
- [ ] eventCode 숫자 → 이름 매핑의 완전성 검증 (중복, 미문서화 이벤트)
- [ ] namespace clustering missed case: AzurahATTRIBUTES vs AzurahAttributes

---

# Phase 1 완료 상태 체크

| Step | 내용 | 상태 |
|------|------|------|
| 1 | 파일 분리 (5개) | ✅ |
| 2 | Inventory + Deps | ✅ |
| 3 | Analysis 심화 + Health | ✅ |
| 4 | Commands 확장 | ✅ (3과 동시 진행) |
| 5 | UI (XML + Lua) | ⬜ 미착수 |

**Step 1~4 완료.** 채팅 기반 진단 도구로서는 이미 기능 완성. Step 5 (UI)는 별도 Phase로 분리 가능.

---

# 현재 슬래시 명령어 전체

```
/aci          요약 리포트
/aci health   환경 종합 진단 (신호등)
/aci stats    이벤트 등록 통계 (클러스터별)
/aci addons   애드온 목록
/aci deps     가장 많이 쓰이는 라이브러리
/aci deps X   X의 forward/reverse 의존성
/aci init     Init 시간 추정 (상위 10)
/aci orphans  불필요한 라이브러리 + de-facto
/aci hot      이벤트 hot path
/aci sv       SV 등록 + 충돌
/aci save     SV 강제 저장
/aci help     도움말
```
