# GGB-ERR-2026-0012: Set StringName 직렬화 표현 오류

> [충돌·오류 관리](../README.md) / [운영 레지스트리](../충돌오류_레지스트리.md)

| 필드 | 값 |
| --- | --- |
| 심각도 | 중간 |
| 상태 | VERIFIED |
| 작업 상태 | DONE |
| 우선순위 | P1 |
| 담당자 | `Codex` |
| 목표 마일스톤 | `M1_V04_PLANNING_BASELINE` |
| 영역 | Godot 4.7 타입·저장 직렬화·중복 방지 |
| 기준 문서 | [17 Godot 데이터](../../17_상태변수_이벤트ID_Godot데이터구조.md) |
| 영향 문서 | `docs/data_contract.md`, `docs/godot_conventions.md`, `00`, `README`, `04`, `13`, `14`, `17`, `18` |
| 해결 담당 영역 | 논리 집합의 Godot 런타임·JSON 표현 정규화 |
| 검증 ID | `QA-ERR-0012-TYPE`, `QA-ERR-0012-UNIQUE`, `QA-ERR-0012-DETERMINISTIC`, `QA-ERR-0012-SYNC` |

## 문제

개정 전 문서 17은 다음 필드를 `Set[StringName]`으로 직렬화한다고 표현했다.

- `ending_run.completed_nodes`.
- `ending_run.required_interactions_seen`.
- `ending_run.optional_interactions_seen`.
- `servants.*.short_events_seen`.
- `object_reaction_memory.persistent_seen`.
- `object_reaction_memory.per_state_seen`.

Godot 4.7에는 GDScript 내장 `Set[T]` 컬렉션이 없다. 이 표현을 구현 타입으로 해석하면 존재하지 않는 타입을 사용하거나, Dictionary key만으로 집합을 흉내 내면서 JSON 순서와 체크섬이 불안정해질 수 있다.

## 채택 해결안

- 문서의 Set은 “논리 집합”이라는 의미로만 사용한다.
- Godot 4.7 런타임에서는 중복 없는 `Array[StringName]`을 사용한다.
- JSON에서는 사전순으로 정렬한 문자열 배열을 사용한다.
- 추가·로드·저장 시 공통 정규화 함수를 거친다.
- 순서가 의미인 `interaction_nodes`, `completed_beats`는 일반 배열로 남기고 정렬하지 않는다.
- 중복을 발견하면 제거하고 `SAVE_DUPLICATE_SET_VALUE` 경고를 남긴다.

## 해결 체크리스트

- [x] 기존 `Set[StringName]` 구현 표기를 논리 집합 배열로 교정함.
- [x] Godot 4.7 타입 대응표를 추가함.
- [x] `normalize_id_set()` 계약을 추가함.
- [x] 결정적 JSON 정렬 순서를 추가함.
- [x] null·unset·빈 ID 구분을 추가함.
- [x] 논리 집합 불변식과 fixture 검증을 추가함.
- [x] 공통 데이터 계약과 Godot 규칙에 `Array[StringName]`·JSON 문자열 배열 경계를 동기화함.
- [x] `00`·`README`·`04`·`13`·`14`·`18`의 구식 Set 구현 표기를 제거함.

## 해결 증거

```yaml
resolved_in:
  - docs/data_contract.md §5
  - docs/godot_conventions.md §7
  - 00_v04_문서목록_및_확정사항.md §18
  - README.md §13
  - 04_전체이벤트리스트_상태표.md §38
  - 13_이벤트상세_08_파열_전환_결산.md §23
  - 14_이벤트상세_09_엔딩.md §20
  - 17_상태변수_이벤트ID_Godot데이터구조.md §3
  - 17_상태변수_이벤트ID_Godot데이터구조.md §8
  - 17_상태변수_이벤트ID_Godot데이터구조.md §13
  - 17_상태변수_이벤트ID_Godot데이터구조.md §16
  - 17_상태변수_이벤트ID_Godot데이터구조.md §20
  - 17_상태변수_이벤트ID_Godot데이터구조.md §29~§31
  - 18_GGB_게임기획서_v0.4_통합본.md §19
  - 18_GGB_게임기획서_v0.4_통합본.md §23
resolution_summary: 논리 집합을 Godot 4.7의 중복 없는 Array StringName과 정렬된 JSON 문자열 배열로 명시하고 정규화·검증 규칙을 모든 후속 문서에 동기화했다.
verification_ids:
  - QA-ERR-0012-TYPE
  - QA-ERR-0012-UNIQUE
  - QA-ERR-0012-DETERMINISTIC
  - QA-ERR-0012-SYNC
verified_on: 2026-07-27
```

## 검증 결과

| 검증 ID | 검사 | 기대 결과 | 결과 |
| --- | --- | --- | --- |
| `QA-ERR-0012-TYPE` | 문서 17의 `Set[StringName]` 구현 타입 검색 | 존재하지 않는 내장 Set을 직렬화 타입으로 지시하지 않음 | PASS |
| `QA-ERR-0012-UNIQUE` | 중복·빈 ID 입력 정규화 예 | 빈 ID 제거·중복 제거·StringName 배열 반환 | PASS |
| `QA-ERR-0012-DETERMINISTIC` | 같은 논리 집합의 다른 입력 순서 | 정렬 뒤 같은 JSON·checksum 생성 | PASS |
| `QA-ERR-0012-SYNC` | 공통 계약과 후속 문서의 논리 집합 표기 검사 | 런타임은 `Array[StringName]`, 저장은 정렬된 문자열 배열로 일치 | PASS |

## 회귀 방지 규칙

1. `Set[StringName]`을 Godot 클래스 필드 타입으로 선언하지 않는다.
2. 논리 집합 배열 순서를 게임 판정에 사용하지 않는다.
3. 저장 전에 중복 제거와 사전순 정렬을 생략하지 않는다.
4. 순서 배열과 논리 집합 배열에 같은 정규화 함수를 사용하지 않는다.
5. 구형 저장의 중복값을 보상·관계 효과 재적용 근거로 사용하지 않는다.
