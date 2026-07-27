# Data Contract

이 문서는 기획 문서, Godot 저작 데이터, 사용자 저장 데이터 사이의 연결 규칙이다. 세부 타입·상태·사건·저장 계약은 [`ideas/md/v04/17_상태변수_이벤트ID_Godot데이터구조.md`](../ideas/md/v04/17_상태변수_이벤트ID_Godot데이터구조.md)를 따른다.

## 1. Source Of Truth

```text
기획 원본 Markdown
→ Godot 저작 Resource
→ 사용자 저장 JSON
```

| 계층 | 경로 | 형식 | 책임 |
| --- | --- | --- | --- |
| 기획 원본 | `ideas/md/v04/` | Markdown·Mermaid·YAML 예시 | 사람이 읽는 사건·퍼즐·서사 정본 |
| 구현 계약 | `ideas/md/v04/17_*.md` | Markdown | 타입·writer·저장·검증 정본 |
| 저작 데이터 | `game/data/` | `.tres` 중심 | 게임이 읽는 정적 사건·대사·퍼즐·registry |
| 게임 코드 | `game/scripts/` | GDScript | Resource 실행·상태 쓰기·저장 |
| 사용자 진행 | `user://saves/` | JSON | 슬롯별 진행·루프·파열·엔딩 실행 |
| 사용자 프로필 | `user://profile/` | JSON | 접근성·입력·엔딩 열람 메타 |

- 게임은 기획 Markdown을 직접 파싱하지 않는다.
- `.tres`는 빌드에 포함되는 읽기 전용 저작 데이터다.
- JSON은 실행 중 변경되는 사용자 데이터다.
- 장면 경로·NodePath 대신 안정된 ID를 사용자 저장에 기록한다.

## 2. Data Folders

```text
game/data/
├─ events/
├─ dialogue/
├─ puzzles/
├─ states/
├─ maps/
├─ object_reactions/
├─ color_signatures/
├─ avatar_visual_profiles/
├─ world_phase_visual_profiles/
├─ accessibility/
└─ registries/
```

| 폴더 | 내용 |
| --- | --- |
| `events/` | 사건 정의, 노드, 선행 조건, 결과, 재개 정책 |
| `dialogue/` | 사용인·시스템·엔딩 텍스트 ID와 대사 |
| `puzzles/` | 검증 단계, 힌트, 실패, checkpoint |
| `states/` | enum·state path·기본값 정의 |
| `maps/` | location·연결·잠금 registry |
| `object_reactions/` | canonical 오브젝트 상태별 반응 |
| `color_signatures/` | 다섯 인격 데이터 서명 |
| `avatar_visual_profiles/` | 캐릭터 대표 외형 |
| `world_phase_visual_profiles/` | S0~S5·R0 표현 상한 |
| `accessibility/` | UI·핫스폿·표시 기본값 |
| `registries/` | ID·상태 경로·오브젝트·텍스트·저장 지점 색인 |

JSON·CSV를 임시 저작 형식으로 사용할 수 있으나 빌드 전 정식 Resource 또는 registry로 변환하고 같은 검증기를 통과해야 한다.

## 3. ID Rule

### 3.1 기획 ID와 데이터 ID

| 기획 표기 | 데이터 표기 | 파일 |
| --- | --- | --- |
| `B3-A` | `B3_A` | `event_b3_a.tres` |
| `C2-1` | `C2_1` | `event_c2_1.tres` |
| `F0-D` | `F0_D` | `event_f0_d.tres` |
| `CLR-04` | `CLR_04` | `color_stage_clr_04.tres` |

- Markdown은 기획 ID를 사용할 수 있다.
- Resource·변수·저장은 정규화된 데이터 ID만 사용한다.
- 파일명은 소문자 snake_case다.
- `EDGAR_B2`, `SERVANT_ED_*` 같은 문서 별칭을 실행 registry에 넣지 않는다.

### 3.2 ID 안정성

- 발급된 ID의 의미를 다른 콘텐츠에 재사용하지 않는다.
- 폐기 ID는 `deprecated`와 `replacement_id`를 남긴다.
- 같은 ID가 둘 이상의 category에 등록되면 빌드를 차단한다.
- 런타임에서 하이픈·underscore 별칭을 동시에 검색하지 않는다.

## 4. State Rule

| 상태 루트 | 수명 | RESET | 저장 |
| --- | --- | --- | --- |
| `meta_progress` | 슬롯 영구 | 유지 | 진행 JSON |
| `loop_state` | 현재 루프 | NORMAL_RESET 부분 초기화 | 진행 JSON |
| `fracture_state` | D5 이후 영구 | 유지 | 진행 JSON |
| `reset_state` | 리셋 트랜잭션 | 완료 뒤 idle | 진행 JSON |
| `ending_run` | 엔딩 실행 | 해당 없음 | 진행 JSON |
| `ending_meta` | 사용자 프로필 | 영향 없음 | 별도 profile JSON |
| `accessibility_settings` | 사용자 프로필 | 영향 없음 | 별도 profile JSON |

주요 원칙:

- 방·오브젝트 위치·당일 도구는 물리 리셋 대상이다.
- 수첩 지식·일지·실패 정보·관계·잔류 기억은 영구 유지한다.
- D5 뒤 첫 수면만 S3를 생성하며 이후 휴식은 현재 물리 상태를 보존한다.
- 파생값은 저장하지 않고 원본 상태에서 다시 계산한다.
- UI·resolver·대사 코드는 진행 상태를 직접 쓰지 않는다.

## 5. Godot Type And Serialization

| 논리 타입 | Godot 4.7 | JSON |
| --- | --- | --- |
| ID·enum | `StringName` | string |
| 순서 목록 | `Array[StringName]` | array |
| 논리 집합 | 중복 없는 `Array[StringName]` | 정렬된 string array |
| 레코드 | `Dictionary` 또는 Resource | object |
| 정적 정의 | `Resource` | 사용자 저장 안 함 |
| 선택 전 | enum `unset`·`unresolved` | string |
| 대상 없음 | 빈 `StringName` 또는 null | schema 지정 방식 |

Godot 4.7에는 `Set[StringName]` 내장 타입이 없다. 논리 집합은 추가·로드·저장 때 중복을 제거하고 저장 전에 사전순으로 정렬한다. 순서가 의미인 사건 노드와 퍼즐 단계는 정렬하지 않는다.

## 6. Writer Ownership

```text
EventManager
→ StateWriter
→ GameState revision
→ SaveManager
```

- 모든 진행 쓰기는 선언된 state path와 writer 권한을 검사한다.
- 영구 효과가 둘 이상인 사건은 atomic group으로 커밋한다.
- 관계 사건은 완료 플래그·기록·사용인 상태·관계 delta·event history를 함께 쓴다.
- 접근성 프로필 writer는 진행 상태를 수정할 수 없다.
- SaveManager는 상태를 결정하지 않고 확정 snapshot만 직렬화한다.

## 7. Save And Profile

```text
user://saves/{slot_id}/progress.json
user://saves/{slot_id}/progress.bak.json
user://saves/{slot_id}/progress.tmp.json
user://saves/{slot_id}/f3_reselect.json
user://profile/ending_meta.json
user://profile/accessibility.json
user://profile/input_map.json
```

버전:

```text
progress.schema_version = 12
accessibility.accessibility_profile_version = 1
ending_meta.ending_meta_profile_version = 1
```

안전 저장 순서:

1. GameState snapshot을 고정한다.
2. schema와 불변식을 검사한다.
3. 논리 집합·Dictionary를 결정적 순서로 정규화한다.
4. SHA-256 checksum을 계산한다.
5. tmp 파일을 기록하고 다시 검증한다.
6. 기존 progress를 backup으로 보존한다.
7. tmp를 progress로 교체한다.

진행·접근성·엔딩 메타 파일은 서로 독립적으로 migration한다. 하나의 손상이 다른 파일을 덮어쓰거나 되돌리지 않는다.

## 8. Validation

빌드 전 최소 검사:

- 모든 event·node·location·object·text·signature ID가 등록되어 있다.
- 모든 prerequisite와 write state path가 선언되어 있다.
- 사건 category가 금지 상태를 쓰지 않는다.
- 선택 관계 사건이 F0·엔딩 진입을 막지 않는다.
- 논리 집합 배열에 중복·빈 ID가 없다.
- 필수 사건 graph가 entry에서 completion·return까지 도달한다.
- 모든 save point가 안전한 resume node를 가진다.
- 색·음향·모션을 제거해도 필수 상호작용이 남는다.
- 진행 설정 변경 전후 진행 checksum payload가 같다.

오류는 조용히 건너뛰지 않는다. 필수 Resource 오류는 export를 차단하고 선택 Resource 오류는 해당 콘텐츠를 비활성화한 뒤 개발 오류 ID를 남긴다.
