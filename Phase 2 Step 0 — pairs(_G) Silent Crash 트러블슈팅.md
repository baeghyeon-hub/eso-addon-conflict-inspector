# Phase 2 Step 0 — `pairs(_G)` Silent Crash 트러블슈팅

> **작성일**: 2026-04-09
>
> **상태**: 원인 확정, 수정 완료, 인게임 검증 완료
>
> **영향 범위**: Phase 1의 "Havok String Bug" 가설 전면 기각. embedded 감지 4연속 실패의 근본 원인도 이것으로 확정.

---

# 증상

## 직접 증상 (Phase 2 Step 0)

`ACI_Inventory.lua`의 `CollectMetadata()` 함수에 추가한 `loadOrderIndex` 필드가 SV에 전혀 나타나지 않음.

- `d()` 호출 제거 후에도 안 나옴
- `_v = "d4"` 같은 단순 문자열 필드도 안 나옴
- `_diagMapSize` 같은 숫자 필드도 안 나옴
- 8회 배포+테스트 반복해도 동일

## 과거 증상 (Phase 1 Step 3.5)

`CollectMetadata()` 내부에서 embedded 감지 로직 4가지 변형 모두 `embeddedCount = 0` 반환.
동일한 로직을 `/aci dump` 슬래시 명령어에서 실행하면 정상 (EMB=10).

## 관찰된 부수 증상

- 게임 접속 시 `[ACI] v0.2.0-step0 loaded` 메시지 안 나옴
- 초기 리포트 (`ACI.PrintReport()`) 자동 출력 안 됨
- `/aci` 슬래시 명령어는 정상 작동
- `loadOrder`, `eventLog`, `svRegistrations`는 정상 기록됨

---

# 오진 이력

## 오진 1: d() 함수 에러 (Phase 2 Step 0 초기)

**가설**: `CollectMetadata` 내부의 `d("[ACI] CollectMetadata START")` 호출이 PLAYER_ACTIVATED 시점에서 에러를 일으켜 함수가 중단됨.

**조치**: d() 호출 전부 제거, 디버그 블록 제거.

**결과**: 여전히 loadOrderIndex 안 나옴. **기각.**

**교훈**: d()는 PLAYER_ACTIVATED 시점에서 정상 동작함 (다른 애드온들도 이 시점에서 d() 사용). 애초에 d()까지 실행이 도달하지 않았을 뿐.

## 오진 2: loadOrderIndex 라인 자체의 에러

**가설**: `ACI.loadOrderMap[name]` 조회가 에러를 일으킴 (nil 테이블, 키 불일치 등).

**조치**: loadOrderIndex 라인 주석 처리 후 `_v = "d4"` 마커만 남김.

**결과**: `_v`도 안 나옴. loadOrderIndex와 무관. **기각.**

## 오진 3: ACI_Inventory.lua 파일 로드 실패

**가설**: 파일 인코딩, BOM, CRLF 등의 이유로 ACI_Inventory.lua가 ESO에 의해 파싱되지 않음.

**조치**: 파일 인코딩(UTF-8 no BOM), 배포 파일 diff, xxd 바이너리 검사.

**결과**: 소스와 배포 파일 완전 동일. 다른 작동하는 파일(ACI_Core.lua)도 동일한 인코딩. **기각.**

## 오진 4: Havok String Bug (Phase 1 Step 3.5)

**가설**: ESO의 API가 "Havok 보호 문자열"을 반환하여 Lua의 string 메서드(find, match, gsub)가 작동하지 않음.

**조치**: Analysis 단계에서 테이블 저장된 값으로 재계산하는 우회로 구현.

**결과**: 우회로는 작동했지만, 후속 재현 테스트(T1~T10)에서 raw API 문자열의 string 메서드가 전부 정상 동작. 원래 "실패"가 재현 불가.

**진짜 원인**: 애초에 CollectMetadata가 실행된 적이 없었음. "실패"가 아니라 "미실행". **전면 기각.**

---

# 원인 추적 과정

## 단계 1: pcall 래핑 (에러 포착 시도)

```lua
-- ACI_Core.lua PLAYER_ACTIVATED 내부
local ok, result = pcall(ACI.CollectMetadata)
ACI_SavedVars._collectOk = ok
if ok then
    ACI_SavedVars.metadata = result
else
    ACI_SavedVars._collectErr = tostring(result)
end
```

**결과**: `_collectOk` 자체가 SV에 안 나옴. pcall 라인까지 도달하지 못한다는 의미.

## 단계 2: 콜백 진입 마커

```lua
-- OnACILoaded 첫 줄
ACI_SavedVars._onLoaded = "v5"

-- PLAYER_ACTIVATED 콜백 첫 줄
ACI_SavedVars._paFired = "v5"
```

**결과**:
- `_onLoaded = "v5"` ✓ — OnACILoaded 실행 확인
- `_paFired = "v5"` ✓ — PLAYER_ACTIVATED 콜백 진입 확인
- `_collectOk` ✗ — 중간에서 에러

**의미**: 콜백은 시작되지만 중간에서 사일런트 에러로 중단됨.

## 단계 3: _step 이진 탐색 (결정적)

```lua
ACI_SavedVars._paFired = "v5"
ACI_SavedVars._step = 1
EVENT_MANAGER:UnregisterForEvent(ACI.name, EVENT_PLAYER_ACTIVATED)
ACI_SavedVars._step = 2
EVENT_MANAGER:UnregisterForEvent(ACI.name .. "_LoadOrder", EVENT_ADD_ON_LOADED)
ACI_SavedVars._step = 3
ACI.eventNames = ACI.BuildEventNameMap()  -- ← 여기서 에러
ACI_SavedVars._step = 4                  -- ← 도달 못함
local ok, result = pcall(ACI.CollectMetadata)
ACI_SavedVars._step = 5
ACI_SavedVars._collectOk = ok
```

**결과**: `_step = 3`

**의미**: `ACI.BuildEventNameMap()` 호출에서 에러 발생. 이 이후 코드 전부 미실행.

---

# 근본 원인

## 에러 발생 코드

```lua
function ACI.BuildEventNameMap()
    local map = {}
    for k, v in pairs(_G) do  -- ← 이 줄에서 런타임 에러
        if type(v) == "number" and type(k) == "string" and k:sub(1, 6) == "EVENT_" then
            map[v] = k
        end
    end
    return map
end
```

## 원인 분석

`pairs(_G)`는 ESO의 전체 글로벌 테이블을 순회한다. ESO의 수정된 Lua 5.1 VM에서 일부 글로벌 변수는 **보호된(protected) 접근 제어**가 있어, `pairs()` 순회 중 해당 키/값에 접근할 때 런타임 에러가 발생한다.

## ESO의 사일런트 에러 메커니즘

ESO는 이벤트 콜백(EVENT_ADD_ON_LOADED, EVENT_PLAYER_ACTIVATED 등)을 내부적으로 보호된 호출(pcall 유사)로 실행한다. 콜백 내에서 에러가 발생하면:

1. ESO가 에러를 catch
2. 에러가 UI 에러 프레임에 잠깐 표시될 수 있음 (ToggleErrorUI 애드온이 없으면 안 보임)
3. **에러 발생 줄 이후의 모든 코드가 실행되지 않음**
4. 다른 이벤트 핸들러나 후속 이벤트는 정상 실행됨

이 메커니즘 때문에:
- `BuildEventNameMap()` 에러 → `CollectMetadata()` 미실행 → `PrintReport()` 미실행
- 하지만 `/aci` 슬래시 명령어(별도 콜백 경로)는 정상 작동
- `loadOrder`, `eventLog` 등 live 참조 데이터는 OnACILoaded에서 이미 설정됨 → 정상

## 영향 범위

### PLAYER_ACTIVATED 콜백에서 미실행된 코드

| 코드 | 기능 | 결과 |
|------|------|------|
| `ACI.BuildEventNameMap()` | eventCode→이름 매핑 | **에러 발생** |
| `ACI.CollectMetadata()` | 메타데이터 수집 | **미실행** |
| `ACI.PrintReport()` | 초기 리포트 출력 | **미실행** |
| `d("[ACI] /aci 로...")` | 안내 메시지 | **미실행** |

### 정상 작동한 코드 (OnACILoaded, 슬래시 명령어)

| 코드 | 이유 |
|------|------|
| `ACI_SavedVars.loadOrder = ACI.loadOrder` | OnACILoaded (PA 이전) |
| `ACI_SavedVars.eventLog = ACI.eventLog` | OnACILoaded (PA 이전) |
| `ACI.RegisterCommands()` | OnACILoaded (PA 이전) |
| `/aci dump` 내 embedded 재계산 | 슬래시 명령어 (별도 경로) |

---

# 수정

## BuildEventNameMap pcall 래핑

```lua
function ACI.BuildEventNameMap()
    local map = {}
    local ok, err = pcall(function()
        for k, v in pairs(_G) do
            if type(v) == "number" and type(k) == "string" and k:sub(1, 6) == "EVENT_" then
                map[v] = k
            end
        end
    end)
    return map
end
```

에러가 발생해도 그 시점까지 수집된 부분적 맵을 반환. PLAYER_ACTIVATED 콜백이 중단되지 않음.

## 검증 결과

수정 후 인게임 테스트:

| 항목 | 결과 |
|------|------|
| `_step` | 5 (끝까지 도달) |
| `_collectOk` | true |
| `_v` | "d4" (CollectMetadata 새 코드 실행 확인) |
| `_mapSize` | 75 (loadOrderMap 정상 수집) |
| `loadOrderIndex` 카운트 | 66개 (67개 중 1개는 disabled로 nil) |

---

# Phase 1 "Havok String Bug" 재해석

## 당시 상황

Phase 1 Step 3.5에서 CollectMetadata 내부에 embedded 감지 로직을 4가지 방법으로 시도:

1. 슬래시 카운트 (`gsub`) → embeddedCount = 0
2. match + gsub + find → embeddedCount = 0
3. 인라인 match → embeddedCount = 0
4. plain find + sub → embeddedCount = 0

동일 로직을 `/aci dump`에서 실행하면 EMB=10 정상.

## 당시 해석

"API 반환값의 문자열이 특수(Havok 보호 문자열)해서 string 메서드가 작동하지 않는다" → Havok String Bug 가설.

후속 재현 테스트(T1~T10)에서 재현 불가 → "원인 미확정" 결론.

## 재해석 (확정)

**embedded 감지 로직은 한 번도 실행된 적이 없다.**

실행 흐름:
```
PLAYER_ACTIVATED 콜백 시작
  → BuildEventNameMap()  ← pairs(_G) 에러로 콜백 중단
  → CollectMetadata()    ← 미실행 (embedded 로직 포함)
  → PrintReport()        ← 미실행
```

SV에 나타난 `embeddedCount = 0`은 "감지 실패"가 아니라 **이전 세션의 잔존 데이터**. CollectMetadata가 실행되지 않았으므로 `ACI_SavedVars.metadata`는 덮어써지지 않고, 이전 세션(BuildEventNameMap 추가 이전, 또는 /reloadui 세션)의 metadata가 그대로 남아있었음.

`/aci dump`이 성공한 이유: 슬래시 명령어는 PLAYER_ACTIVATED 콜백과 무관한 별도 실행 경로.

**결론: Havok String Bug는 존재하지 않았다. `pairs(_G)` 런타임 에러 하나가 모든 증상의 원인.**

---

# 교훈

## 1. "실패"와 "미실행"을 구분하라

코드가 "잘못된 결과를 반환"하는 것과 "실행 자체가 안 됨"은 완전히 다른 문제. ESO의 사일런트 에러 메커니즘 때문에 둘이 동일하게 보일 수 있다.

**진단법**: 의심 함수 앞뒤에 `ACI_SavedVars._step = N` 마커를 배치하여 실행 경로를 이진 탐색.

## 2. 에러가 아닌 곳에서 에러를 찾지 마라

CollectMetadata 내부를 8회 수정하며 테스트했지만, 실제 에러는 CollectMetadata **호출 이전** BuildEventNameMap에 있었다. 실패하는 함수 자체가 아니라 **호출 경로 전체**를 검증해야 한다.

## 3. ESO `_G` 순회는 위험하다

`pairs(_G)`는 ESO의 보호된 글로벌 때문에 런타임 에러를 일으킬 수 있다. 반드시 pcall로 감싸야 한다.

## 4. _step 마커 이진 탐색 패턴

ESO의 사일런트 에러를 추적하는 가장 효과적인 방법:

```lua
ACI_SavedVars._step = 1
-- 의심 코드 A
ACI_SavedVars._step = 2
-- 의심 코드 B
ACI_SavedVars._step = 3
-- 의심 코드 C
ACI_SavedVars._step = 4
```

SV에서 `_step` 값을 확인하면 정확히 어느 줄에서 에러가 발생했는지 알 수 있다.

## 5. 가설의 전파를 경계하라

"Havok String Bug"라는 가설이 만들어지자, 이후 모든 분석이 그 프레임 안에서 이루어졌다. 가설이 틀렸을 때 빠져나오기 어려웠던 이유는 **가설 자체를 검증하는 대신 가설을 전제로 한 우회로를 찾았기 때문.**

## 6. ESO의 d()는 채팅 UI 준비 이전에 호출하면 표시되지 않는다

`d()` 호출 자체는 에러 없이 성공하지만, EVENT_ADD_ON_LOADED나 PLAYER_ACTIVATED 시점에서는 채팅 UI가 아직 초기화되지 않아 메시지가 표시되지 않음.

**해결**: `zo_callLater`로 지연 호출.

```lua
-- OnACILoaded 시점 (EVENT_ADD_ON_LOADED): 500ms 지연
zo_callLater(function()
    d("[ACI] v" .. ACI.version .. " loaded.")
end, 500)

-- PLAYER_ACTIVATED 시점: 1000ms 지연
zo_callLater(function()
    ACI.PrintReport()
    d("[ACI] /aci 로 최신 통계를 볼 수 있습니다.")
end, 1000)
```

**진단 과정**: `_printReportReached`, `_dReached`, `_dDone` 마커가 전부 SV에 기록됨 → d()는 실행됐으나 채팅창에 미표시 → 타이밍 문제 확정.

---

# 타임라인

| 시점 | 작업 | 결과 |
|------|------|------|
| Phase 1 Step 2 | BuildEventNameMap 최초 작성 | _G 순회 코드 추가 |
| Phase 1 Step 3.5 | embedded 감지 4회 시도 | 전부 "실패" → Havok Bug 가설 |
| Phase 1 Step 3.5 | dump 재계산 우회로 | 성공 → Analysis 재계산 아키텍처 채택 |
| Phase 1 완료 | 최종 보고서 | "원인 미확정" |
| Phase 2 Step 0 | loadOrderIndex 추가 | SV에 안 나옴 |
| Phase 2 Step 0 | d() 제거, 코드 정리 | 여전히 안 나옴 |
| Phase 2 Step 0 | loadOrderIndex 주석 처리 | _v 마커도 안 나옴 |
| Phase 2 Step 0 | 복잡한 진단 코드 추가 | _diag 안 나옴 |
| Phase 2 Step 0 | pcall 래핑 | _collectOk 안 나옴 |
| Phase 2 Step 0 | **_onLoaded + _paFired 마커** | **둘 다 나옴 → 콜백 진입 확인** |
| Phase 2 Step 0 | **_step 이진 탐색** | **_step=3 → BuildEventNameMap 확정** |
| Phase 2 Step 0 | **BuildEventNameMap pcall 래핑** | **전부 해결. loadOrderIndex 66개 정상** |
| Phase 2 Step 0 | Havok Bug 재해석 | **같은 원인이었음. Havok Bug 전면 기각** |
| Phase 2 Step 0 | d() 채팅 미표시 조사 | _printReportReached=true, _dDone=true → 실행됐으나 미표시 |
| Phase 2 Step 0 | **zo_callLater 적용** | **접속 시 리포트 정상 출력. v0.2.0 최종 완료** |
