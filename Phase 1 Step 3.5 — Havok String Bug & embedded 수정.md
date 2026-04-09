# Phase 1 Step 3.5 — embedded 감지 4연속 실패 & 해결

> **작성일**: 2026-04-09
>
> **상태**: 수정 완료, 인게임 검증 완료 (34/56, EMB=10)
>
> **정정**: 초기에 "Havok String Bug"로 추정했으나, 후속 테스트에서 raw API 문자열의
> string 메서드는 전부 정상 동작 확인. 원래 실패의 근본 원인은 미확정.
> 다만 현재 아키텍처(Analysis 재계산)가 정상 동작하며 설계적으로도 더 우수.

---

# 문제

`IsEmbeddedAddon(rootPath)` 함수가 CollectMetadata 내부에서 항상 `false`를 반환.
10개의 embedded 서브애드온이 전부 top-level로 잘못 분류됨.

---

# 트러블슈팅 이력 (4회 시도 + 원인 발견)

## 시도 1: 슬래시 카운트 (local function)

```lua
local function IsEmbeddedAddon(rootPath)
    if not rootPath then return false end
    if rootPath:find("Managed", 1, true) then return false end
    local _, slashCount = rootPath:gsub("/", "")
    return slashCount > 3
end
```

**결과**: embeddedCount = 0. 전부 false.

## 시도 2: match + gsub + find (local function)

```lua
local function IsEmbeddedAddon(rootPath)
    if not rootPath then return false end
    local rel = rootPath:match("/AddOns/(.+)")
    if not rel then return false end
    rel = rel:gsub("/$", "")
    return rel:find("/", 1, true) ~= nil
end
```

**결과**: embeddedCount = 0. 전부 false.

## 시도 3: 인라인 match (local function 제거)

```lua
local isEmbedded = false
if rootPath and rootPath:match("/AddOns/[^/]+/.") then
    isEmbedded = true
end
```

**결과**: embeddedCount = 0. 전부 false.

## 시도 4: plain find + sub (패턴 완전 제거)

```lua
local isEmbedded = false
if rootPath then
    local marker = "/AddOns/"
    local mPos = rootPath:find(marker, 1, true)
    if mPos then
        local afterAddons = rootPath:sub(mPos + #marker)
        local firstSlash = afterAddons:find("/", 1, true)
        if firstSlash and firstSlash < #afterAddons then
            isEmbedded = true
        end
    end
end
```

**결과**: embeddedCount = 0. 전부 false.

## 돌파구: dump 재계산

동일한 로직을 `/aci dump` 명령어에서 `a.rootPath`(테이블에 저장된 값)로 재계산:

```lua
-- dump 내부에서 a.rootPath로 재계산
local rp = a.rootPath or ""
local mPos = rp:find("/AddOns/", 1, true)
local afterAddons = mPos and rp:sub(mPos + 8) or "N/A"
local firstSlash = afterAddons:find("/", 1, true)
-- _result = (firstSlash < #afterAddons) and "EMB" or "TOP"
```

**결과**: `_result: EMB=10, TOP=56`. **정상 동작!**

그런데 같은 세션의 CollectMetadata에서 설정한 `isEmbedded`는 여전히 전부 false.

---

# 원인

## 확정 사실

| 위치 | rootPath 소스 | string 연산 | 결과 |
|------|-------------|------------|------|
| CollectMetadata | `GetAddOnRootDirectoryPath(i)` 직접 | find/match/gsub | **전부 실패** |
| dump 재계산 | `a.rootPath` (테이블 저장 후) | find/sub | **정상 (10개 EMB)** |

두 곳에서 사용하는 rootPath **값**은 동일 (`user:/AddOns/HarvestMapData/Modules/HarvestMapDLC/`).
테이블에 `a.rootPath = rootPath` 대입 후에는 정상 동작.

## 후속 재현 테스트 결과 (정정)

`/aci debug`로 raw API 반환값에 T1~T10 테스트 수행:

- `find()`, `match()`, `gsub()`, `tostring()`, `#`, `type()` — **전부 정상**
- raw와 table 경유 값 사이 **차이 없음**
- T7(`raw:gsub cnt = 0`)은 테스트 코드의 `and/or` 연산자 우선순위 버그

**"Havok String Bug"는 재현 불가. 초기 가설은 증거 부족으로 기각.**

### 원래 4연속 실패의 근본 원인 — **확정 (2026-04-09)**

**원인: `ACI.BuildEventNameMap()`의 `pairs(_G)` 런타임 에러**

PLAYER_ACTIVATED 콜백 실행 순서:
1. `ACI.BuildEventNameMap()` — `pairs(_G)` 순회에서 ESO 보호된 글로벌로 인해 에러
2. → ESO가 콜백 에러를 사일런트 catch → 콜백 전체 중단
3. → `ACI.CollectMetadata()` **실행 자체가 안 됨**
4. → SV metadata는 이전 세션 데이터 그대로 잔존

**4가지 embedded 감지 시도는 "실패"가 아니라 "실행되지 않았음".**
dump 재계산이 성공한 이유는 `/aci dump` 슬래시 명령어가 PLAYER_ACTIVATED 경로와 무관하기 때문.

**"Havok String Bug"는 존재하지 않았음.** pcall로 `pairs(_G)` 감싸서 해결.

증거: `_step` 마커 이진 탐색으로 `_step=3` (BuildEventNameMap 직전)에서 중단 확인.

### 교훈

- 가설을 통제 실험 없이 확정하면 안 됨
- 재현 실패 자체가 유용한 정보
- "잘못된 확신"보다 "원인 모름 + 해결됨"이 정직하고 안전

---

# 해결: Analysis 단계에서 재계산

## 설계 원칙

> **증거 기반 > 추측 기반**
>
> - dump에서 `a.rootPath`로 재계산 성공 = **증명된 사실**
> - `tostring(rootPath)`로 변환 시도 = **가설** (될 수도 안 될 수도)
> - 증거 기반이 항상 이긴다

## 변경 내역

### ACI_Inventory.lua

- `IsEmbeddedAddon()` 함수 **완전 제거**
- `isEmbedded` 필드 **제거** — rootPath만 저장
- 테이블 대입 시 Havok → Lua string 변환이 자동으로 일어남

### ACI_Analysis.lua

- `IsEmbeddedPath(rootPath)` local function 추가 (파일 상단)
- `ACI.TagEmbeddedAddons()` 함수 추가 — metadata.addons 배열 일괄 태깅
- `ComputeHealthScore()` 진입부에서 `TagEmbeddedAddons()` 호출
- `FindOrphanLibraries()`는 기존 `not a.isEmbedded` 필터 유지 (태깅 후이므로 정상 동작)

### ACI_Commands.lua

- dump에서 중간값 진단 제거 (문제 해결됨)
- `ACI.TagEmbeddedAddons()` 호출 추가 (dump 전에 태깅)

---

# 예상 검증 결과

## /aci health

```
● 주의  (또는 ● 정상)
구버전: 34/56 top-level (61%)
  (embedded 서브애드온 10개 제외)
  라이브러리 18 | 본체 16
  → 패치 후 정상 범위 (1-2개월 내)
```

## /aci dump → SV

```
embeddedCount = 10
topLevelEnabled = 56
topLevelOOD = 34
embeddedStr: YES=10, NO=56
```

---

# Phase 2+ 후보 아이디어

- [x] ~~Havok String Bug 최소 재현~~ — **불필요. 버그 자체가 존재하지 않았음.** `pairs(_G)` 에러로 인한 코드 미도달이 원인.
- [x] ~~`ACI.DetectHavokStringBug()`~~ — 불필요
- [x] ~~다른 API 함수 검증~~ — 불필요
