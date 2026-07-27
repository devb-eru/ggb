# GGB-CNF-2026-0012: Godot 디렉터리와 서비스 책임 규칙 충돌

> [충돌·오류 관리](../README.md) / [운영 레지스트리](../충돌오류_레지스트리.md)

| 필드 | 값 |
| --- | --- |
| 심각도 | 중간 |
| 상태 | VERIFIED |
| 작업 상태 | DONE |
| 우선순위 | P1 |
| 담당자 | `Codex` |
| 목표 마일스톤 | `M1_V04_PLANNING_BASELINE` |
| 영역 | Godot 프로젝트 구조·서비스 책임·데이터 정본 |
| 기준 문서 | [`docs/godot_conventions.md`](../../../../../docs/godot_conventions.md), [`docs/data_contract.md`](../../../../../docs/data_contract.md) |
| 영향 문서 | `docs/data_contract.md`, `docs/godot_conventions.md`, `00`, `README`, `04`, `13`, `14`, `17`, `18` |
| 해결 담당 영역 | `res://` 경로와 autoload·systems·data_types 책임 정규화 |
| 검증 ID | `QA-CNF-0012-PATH`, `QA-CNF-0012-SERVICE`, `QA-CNF-0012-BOUNDARY`, `QA-CNF-0012-SYNC` |

## 문제

개정 전 문서 17의 권장 구조는 다음 경로를 사용했다.

```text
res://autoload/
res://resources/
res://scenes/locations/
```

프로젝트 공통 규칙은 다음 경로를 사용한다.

```text
res://scripts/autoload/
res://scripts/systems/
res://scripts/interactables/
res://scenes/rooms/
res://data/
```

또한 개정 전 문서는 `EventBus`, `ReactionRouter`, `EndingRouter`, `VisualStateResolver`를 모두 autoload처럼 배치했다. 공통 규칙에서는 전역 싱글톤과 일반 시스템의 실제 등록을 구현 시점에 구분하도록 되어 있어 다음 위험이 있었다.

- 같은 클래스가 서로 다른 경로에 중복 생성됨.
- 모든 router가 전역 상태를 직접 소유한다고 오해함.
- 정적 Resource 클래스와 사용자 저장 데이터가 같은 `resources/` 폴더에 섞임.
- `EventBus`와 `EventManager`가 같은 사건 신호를 중복 발행함.

## 채택 해결안

- 프로젝트 루트는 `game/`, Godot 내부 경로는 `res://`로 유지한다.
- autoload 후보는 `GameState`, `EventManager`, `SaveManager`, `AccessibilityProfileManager`로 제한한다.
- `StateWriter`, `ResetCoordinator`, `ReactionRouter`, `EndingRouter`, `VisualStateResolver`는 `res://scripts/systems/`에 둔다.
- Resource 클래스는 `res://scripts/data_types/`, 실제 저작 데이터는 `res://data/`에 둔다.
- `EventBus`를 별도 autoload로 두지 않고 `EventManager`가 사건 신호와 실행 순서를 소유한다.
- 정적 저작 데이터는 `.tres`, 사용자 진행·프로필은 `user://` JSON으로 분리한다.

## 해결 체크리스트

- [x] 문서 17 §10의 구식 경로를 프로젝트 규칙에 맞게 교정함.
- [x] autoload와 일반 systems를 분리함.
- [x] `EventBus`와 `EventManager`의 중복 책임을 제거함.
- [x] data type 클래스와 저작 Resource 경로를 분리함.
- [x] 저작 데이터와 사용자 저장 데이터의 경계를 정의함.
- [x] canonical registry 배치 경로를 추가함.
- [x] `docs/data_contract.md`와 `docs/godot_conventions.md`를 정본 경로·책임에 동기화함.
- [x] `00`·`README`·`04`·`13`·`14`·`18`에 구현 인계 요약을 동기화함.
- [x] 문서 17 §32의 후속 동기화 상태를 모두 `완료`로 갱신함.

## 해결 증거

```yaml
resolved_in:
  - docs/data_contract.md §1~§8
  - docs/godot_conventions.md §1~§9
  - 00_v04_문서목록_및_확정사항.md §18
  - README.md §13
  - 04_전체이벤트리스트_상태표.md §38
  - 13_이벤트상세_08_파열_전환_결산.md §23
  - 14_이벤트상세_09_엔딩.md §20
  - 17_상태변수_이벤트ID_Godot데이터구조.md §10
  - 17_상태변수_이벤트ID_Godot데이터구조.md §18
  - 17_상태변수_이벤트ID_Godot데이터구조.md §26
  - 17_상태변수_이벤트ID_Godot데이터구조.md §27
  - 17_상태변수_이벤트ID_Godot데이터구조.md §32
  - 18_GGB_게임기획서_v0.4_통합본.md §19
  - 18_GGB_게임기획서_v0.4_통합본.md §23
resolution_summary: 프로젝트 공통 Godot 경로를 기준으로 autoload·systems·data_types·저작 데이터·사용자 저장의 책임과 위치를 분리하고 모든 후속 문서를 동기화했다.
verification_ids:
  - QA-CNF-0012-PATH
  - QA-CNF-0012-SERVICE
  - QA-CNF-0012-BOUNDARY
  - QA-CNF-0012-SYNC
verified_on: 2026-07-27
```

## 검증 결과

| 검증 ID | 검사 | 기대 결과 | 결과 |
| --- | --- | --- | --- |
| `QA-CNF-0012-PATH` | 문서 17 권장 경로와 Godot 공통 규칙 대조 | `res://scripts/*`, `res://data/*`, `res://scenes/*` 체계 일치 | PASS |
| `QA-CNF-0012-SERVICE` | autoload·systems 책임표 검사 | 전역 상태 소유자와 무상태 router가 분리됨 | PASS |
| `QA-CNF-0012-BOUNDARY` | `.tres`·진행 JSON·프로필 JSON 배치 검사 | 정적 저작·진행·프로필 저장 경계가 겹치지 않음 | PASS |
| `QA-CNF-0012-SYNC` | 문서 17 §32의 후속 문서 8개와 공통 계약 2개 검사 | 경로·서비스·저장 경계 요약이 상세 정본과 일치 | PASS |

## 회귀 방지 규칙

1. `res://autoload/`, `res://resources/`, `res://scenes/locations/`를 신규 정본 경로로 추가하지 않는다.
2. router가 GameState Dictionary를 직접 수정하지 않는다.
3. 사건 신호 소유자를 `EventManager`와 별도 EventBus에 중복 등록하지 않는다.
4. 사용자 진행 JSON을 `res://data/`에 저장하지 않는다.
5. 프로젝트 경로를 변경하면 `docs/godot_conventions.md`, `docs/data_contract.md`, 문서 17을 같은 변경 단위로 갱신한다.
