# Data Contract

이 문서는 기획 문서, Godot 저작 데이터, 사용자 저장 데이터 사이의 연결 규칙이다. 제품에 노출되는 저장·재개 약속은 [제품 계약](product_contract.md), 세부 타입·상태·사건 계약은 [`ideas/md/v04/17_상태변수_이벤트ID_Godot데이터구조.md`](../ideas/md/v04/17_상태변수_이벤트ID_Godot데이터구조.md)를 따른다. 저장 헤더나 생명 주기가 충돌하면 최신 `GGB-DEC`와 제품 계약을 우선하고 문서 17을 같은 변경 단위로 동기화한다.

## 1. Source Of Truth

```text
기획 원본 Markdown
→ Godot 저작 Resource
→ 사용자 저장 JSON
```

| 계층 | 경로 | 형식 | 책임 |
| --- | --- | --- | --- |
| 기획 원본 | `ideas/md/v04/` | Markdown·Mermaid·YAML 예시 | 사람이 읽는 사건·퍼즐·서사 정본 |
| 제품 계약 | `docs/product_contract.md` | Markdown | 빌드·입력·접근성·저장 UX 정본 |
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
│  └─ event_parts/
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
| `object_reactions/event_parts/` | P2~P5처럼 사건 안에서만 유효한 자식 핫스폿 반응 |
| `color_signatures/` | 다섯 인격 데이터 서명 |
| `avatar_visual_profiles/` | 캐릭터 대표 외형 |
| `world_phase_visual_profiles/` | S0~S5·R0 표현 상한 |
| `accessibility/` | UI·핫스폿·표시 기본값 |
| `registries/` | ID·상태 경로·canonical 오브젝트·사건 자식 핫스폿·텍스트·저장 지점 색인 |

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
- canonical 오브젝트는 `object_id`, 사건 자식 핫스폿은 전역 유일한 `interaction_part_id`로 식별한다.
- canonical 부모가 없는 자식 핫스폿은 `event_context`, `location_id`, `production_id`를 함께 가져야 한다. `production_id`는 제작 역추적용이며 저장 키가 아니다.

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
- 사건 전용 도구·부분 진행은 `loop_state.event_local_states.EVENT_ID`에 두고 NORMAL_RESET에서 초기화한다.
- 수첩 지식·일지·실패 정보·관계·잔류 기억은 영구 유지한다.
- 확인한 대화 기록은 `meta_progress.dialogue_history`에 두고 모든 세계 리셋에서 유지한다.
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
progress.schema_version = 1
progress.design_revision = "v0.4-state-r12"
accessibility.accessibility_profile_version = 1
ending_meta.ending_meta_profile_version = 1
```

첫 팀·외부 배포 저장 형식은 `schema_version=1`에서 시작한다. 기존 기획 문서의 schema 12는 런타임 이관 번호가 아니라 열두 번째 상태 모델 개정이며 `design_revision`으로만 추적한다. 실제 배포한 저장 형식이 바뀔 때만 `schema_version`을 올리고 입력·출력 fixture를 보존한다.

진행 헤더 최소 계약:

```yaml
save_header:
  schema_version: 1
  design_revision: "v0.4-state-r12"
  game_version: "0.0.0-dev"
  build_id: "local-dev"
  build_flavor: "demo"
  content_revision: "unlocked"
  content_boundary_id: "SAVE_J1_COMPLETE"
  source_app_id: "local"
  engine_version: "4.7"
  slot_id: "slot_01"
  save_point_id: "SAVE_J1_COMPLETE"
  transaction_id: "SAVE_TX_000001"
  created_at_utc: 0
  updated_at_utc: 0
  checksum_algorithm: "sha256"
  checksum: ""
```

`design_revision`이나 `engine_version` 하나만으로 호환을 허용하지 않는다. 최소한 `schema_version`, `build_flavor`, `content_boundary_id`, `source_app_id`와 checksum을 함께 판정한다.

### 7.1 대화 기록

[GGB-DEC-2026-0006](decisions/GGB-DEC-2026-0006_대화_기록_영속화.md)에 따라 대화 기록은 진행 슬롯에 명시적으로 저장한다. 보존·통합 수첩의 목표 계약은 [DEC-0012](decisions/GGB-DEC-2026-0012_통합_수첩_범위와_기록_보존.md)와 [구현 계획](../ideas/md/v04/issues/validation/notebook_history_review_plan.md)을 적용한다. 아래 예시는 이전 기록의 논리 필드 설명이며 신형 archive의 완전한 직렬화 예제가 아니다. 현재 게임은 transcript 저장을 사용하며 새 저장 계층의 실제 연결 상태는 [구현 현황](../ideas/md/v04/issues/validation/notebook_history_implementation_status.md)을 따른다.

개발 옵션의 authored 기록은 `content_id + content_version + variant_id + 공개 segment`를 고정한다. 현재 언어 재열람은 정확히 같은 의미 버전만 사용하고, 없으면 저장 당시 원문임을 표시한다. 변수는 해당 segment가 선언한 공개 값만 받고 정수 공개 값은 첫 저장부터 JSON 수 표현으로 고정한다. 새 대화·힌트 관찰은 실제 표시문과 일치해야 하며, 사건 작성 원고는 7.1.1절을 따른다. 기존 버전 원고의 덮어쓰기나 문자열 역검색으로 출처를 추정하지 않는다. 현재 이 계약의 실제 연결 대상은 [NP01~NP03 프롤로그, NP04 1장 표시, NP05 등록 선택창, NP06 1장 원고, NP07 거울, NP08 지하, NP09 파열/휴식/기상/보고 등록분, NP10~NP14 다섯 사용인 핵심 관계, NP15 저녁/접근 등록분, NP20 단계 힌트](../ideas/md/v04/issues/validation/notebook_content_mapping_status.md)이며 다른 생산자의 임시 `unmapped`는 인수 완료로 세지 않는다. 선택 문구 확정 기록은 입력 의향의 증거이고, 뒤이어 실행하는 출발·수면 등 게임 상태 저장의 성공을 뜻하지 않는다.

공개 변수의 선택적 `enum:<이름>` 형식은 해당 의미 버전의 `enums[이름][ko-KR/en-US][토큰]` 명칭을 사용한다. 두 언어의 허용 토큰 집합은 같고 비어 있지 않아야 하며, 토큰·번역문은 비어 있지 않은 문자열이어야 한다. 선언하지 않은 enum·토큰·번역문 자체·숫자/객체 입력은 거절한다. 저장에는 당시 공개한 토큰만 들어가고 표시문은 한 번만 치환한다. 값 속 중괄호는 추가 변수로 해석하지 않는다. enum이 없는 기존 카탈로그는 기존 계약을 유지한다. 과거 의미 버전 전체를 구할 수 없으면 저장한 완전한 원문과 fallback 안내를 사용한다.

NP04는 `loop_state.event_local_states.CHAPTER_ONE.last_feedback.notebook_feedback`에 명시적인 문단별 descriptor 목록을 선택적으로 보존한다. 이는 미표시 대사의 관찰 증거가 아니며 사건 진행과 함께 저장한 표시 원고 식별자다. 대화창에서 실제로 표시한 문단만 archive 관찰로 생성한다. 필드 없는 과거 피드백을 텍스트 ID나 한국어 본문으로 소급 매핑하지 않는다. 시계 배치의 공개 변수는 `matched` 또는 `position` 정수만 허용하며, 미래 정답이나 현재 상태로 재계산하지 않는다. 게임 사건 저장 응답 유실은 transaction과 전체 영속 값 일치를 확인한 경우에만 성공으로 인정한다.

NP05의 등록 선택창은 표시와 각 입력의 콘텐츠 ID/종류를 명시한다. 첫 번째 버튼이라는 이유로 취소하지 않으며 실제 읽기 확인·의향 선택·단순 재생/닫기를 구분한다. 표시 및 선택 토큰과 언어·사건 문맥을 생성 시 동결하고 저장 실패 시 콜백 실행을 막는다. 선택 기록의 저장은 이후 gameplay 커밋의 성공 증거가 아니다. 슬롯/로드 epoch/출처/분기/namespace와 모달 세대를 대조하고, 오래된 창은 새 상태에 기록하지 않고 닫는다. 공개한 부기/경로 segment만 저장하며 아직 읽지 않은 확대 본문을 summary의 관찰로 재열람하지 않는다. 공통 선택창 전체 및 앱 재시작 커서의 완료 여부는 매핑 현황을 따른다.

명시적 취소가 없는 읽기 창의 Esc도 활성 scope에서 표시 저장이 실패했다면 같은 표시 요청을 먼저 재시도한다. 성공 전에는 닫지 않는다. 성공 후의 단순 닫기는 `choice_confirmed`나 `field_read`를 만들지 않는다. 로드 등으로 scope가 무효화된 창의 무기록 닫기와 구분한다.

```yaml
meta_progress:
  dialogue_history:
    next_sequence: 1
    entries:
      - sequence: 0
        line_id: DLG_EDGAR_B1_001
        speaker_id: SERVANT_EDGAR
        choice_id: null
        viewed_locale: ko-KR
        event_id: B1
        viewed_at_utc: 0
        retention: normal
```

규칙:

- 신규 기록은 원 콘텐츠 ID·의미 버전·variant·안전한 변수·실제 공개 segment로 현재 locale에 표시한다. 해당 버전이 없으면 당시 표시 원문과 언어를 fallback으로 쓰며 최신 비밀 본문으로 대체하지 않는다. legacy 원문은 재작성하지 않는다.
- `entry_uid`는 불변 참조 키다. `sequence`는 분기 내 표시 순서이며 과거 복귀로 값이 재사용돼도 다른 기록에 연결하지 않는다. 원 출처·분기·namespace·load epoch를 구분한다.
- NORMAL_RESET, BROKEN_RESET, 불러오기와 언어 변경에서 유지한다.
- 일반 대사는 최신 2,000개를 유지하고 보호 기록·legacy는 수량 계산에서 제외해 별도로 보존한다. 보호만 2,001개여도 새 일반 기록을 밀어내지 않는다.
- 일지·최종 선택·관계 outcome·단서/가설/인물의 출처와 책갈피·비교 참조가 원문을 보호한다. 참조와 보호 이유는 같은 슬롯 snapshot에서 저장하며 해제는 해당 이유만 제거한다.
- 조회/검색/확대는 읽기 전용이다. 고정/비교 명령은 공개된 자료의 참조·보호·기록 메타 revision만 변경한다. 세계·관계·퍼즐·현실 `field_read`는 변경하지 않는다.
- 새 게임·삭제는 다른 슬롯과 갤러리를 지우지 않는다. 호환 불가 상태는 원본 보존·명시적 복구 경로로 처리하고 자동 초기화하지 않는다.
- 아직 보지 않은 line이나 후속 선택지는 기록에 생성하지 않는다.

현실 몸 재관찰의 독립 증거는 `meta_progress.knowledge_entries.dialogue_observed_facts`에 둔다. 허용 키는 `BODY_REPEAT:OBJ_REALITY_HAND`, `BODY_REPEAT:OBJ_REALITY_BREATH_MONITOR`, `BODY_REPEAT:OBJ_REALITY_RESTRAINT`이며 값은 `true`만 허용한다. 실제 재관찰 대사가 표시될 때 기존 조사 확인·현재 현실 노드를 검사하고 대사 기록과 함께 저장한다. 저장 실패 시 두 변경을 함께 롤백한다. 갤러리는 이 증거로 재관찰 본문을 보존하되 기존 조사 확인 조건을 우회하지 않는다. 구형 저장의 원문 확인은 읽기 전용 호환 경로로 유지한다.

현재 본편 writer는 자동 정리를 켜지 않았다. UID·보호·출처·저장 이관·원문 소비 경로가 갖춰진 뒤 위 정책을 활성화한다. 새 archive 후보 변환만 통과한 것을 실제 슬롯 이관 완료로 간주하지 않는다.

개발 검증 옵션 `--ggb-dev-notebook-v2`에서는 실제 schema 1 -> 2 이관과 신형 archive 저장을 검사할 수 있다. 일반 실행은 schema 1을 유지하며 release에서는 이 옵션을 무시한다. 원본은 checksum 검증 후 `pre_notebook_<checksum>.json`으로 바이트 보존하고, 원본/백업/F3/demo/개발/갤러리의 읽기 입구를 각각 처리한다. 갤러리 원본과 hash ID는 변경하지 않는다. 미래 형식과 백업 충돌은 덮어쓰지 않는다.

신형 검증 모드의 미연결 생산자는 `unmapped` 보존 래퍼이며 authored 완료로 계산하지 않는다. legacy/unmapped에는 자동 정리를 적용하지 않는다. `notebook_commands.gd`의 고정/비교 쓰기는 실제 슬롯 트랜잭션과 연결했지만 일반 수첩 UI는 아직 연결 전이다. 자료 고정은 gameplay 상태를 바꾸지 않으며, 실패·응답 소실·낡은 scope/revision을 검사한다. 전체 전환 상태는 구현 현황의 단계별 인수 결과가 기준이다.

### 7.1.1 사건 작성 지식 Revision (개발 검증)

선택 필드 `meta_progress.knowledge_entries.notebook_knowledge`는 `{schema_version: 1, revision, revisions: []}`다. 필드가 없는 구형 원고에는 과거 획득 이력을 만들어 넣지 않는다. 같은 archive 2 snapshot에 실제 획득한 원고와 아래 revision을 함께 저장한다. 일반 실행의 기본 저장 형식은 이 변경으로 승격하지 않는다.

| 필드 | 계약 |
| --- | --- |
| `knowledge_uid` | 카드별 불변 128-bit ID. 같은 knowledge ID의 후속 revision이 공유 |
| `revision_uid`, `previous_revision_uid` | 개별 원고 갱신 ID와 바로 이전 ID. 최초는 이전 ID 빈 문자열 |
| `sequence` | ledger 내부 순서. 단순 표시 변경·재조회·같은 요청 재시도로 증가하지 않음 |
| `metadata` | `knowledge_id`, `category`, `epistemic_state`, `provenance_state`, `lifetime`. 내용 해석과 출처 확인을 구분 |
| `observation_ref` | 실제 획득 원고의 종류/출처/UID/정확한 의미 버전/공개 segment |
| `source_refs` | 원고 자체와 이미 공개된 인용 출처. 각 참조에 `knowledge_source:<revision_uid>` 보호가 일치해야 함 |

NP03 9종 원고는 `document_segment` / `replay_committed`로 획득한다. `event_note_commit`으로 등록한 콘텐츠만 이 공개 방식을 사용할 수 있다. 힌트·문서 뒷면을 수첩 열기로 획득하거나, 기록했다는 사실로 gameplay 읽기 완료를 만들지 않는다. P4 진동은 실제 기록 버튼을 눌렀을 때만 작성한다. 다음에 표시될 대사를 미리 출처로 인용하지 않는다.

NP06 26종도 같은 ledger 계약을 사용한다. A1/A2는 `CH1_SELF_MARK`의 가설/검증 revision이고, 실제 실패와 B4 해결은 `CH1_CLOCK_FAILURE`의 연속 revision이다. J1/J2는 복원 성공으로 작성한 페이지 전체의 `replay_committed` 증거이며 NP04가 한 문장씩 표시한 `displayed` 증거와 별개다. 동일 원고 재조사는 획득을 반복하지 않지만 새로운 실패 실행은 같은 진단이어도 별도 revision이다. 현재 snapshot에서 획득한 출처만 인용하고, legacy의 사라진 이전 값·획득 시각·숨은 역할 정답은 재구성하지 않는다. B4 파형과 실패 해결 원고, 관련 게임 플래그는 한 커밋으로 저장한다. 수첩 소비 화면은 이 공급자 함수를 호출하지 않는다.

NP06에서 같은 행동으로 작성한 복수 원고는 `event_occurrence_id`와 작성 묶음의 `conversation_session_id`를 공유하지만 각 `presentation_token`은 다르다. 뒤이어 실제 표시하는 NP04 대사는 사건 ID를 공유하고 별도의 대화 세션을 연다. 작성 묶음은 대화 재개 커서나 읽음 증거가 아니다.

NP07 17종 사건 원고는 같은 계약으로 기록한다. `MIRROR_COATING`의 관찰/가설, `MIRROR_TRACING`의 원도/대조, `MIRROR_FAILURE`의 실제 실패/해결은 이전 revision을 보존한다. 잠김 상태에서 거절한 재입력은 새 실패가 아니며 정상 수면 뒤 실제 실패는 같은 진단이어도 새 revision이다. 원도에 채널 이름을 선행 작성하지 않고 실제 다섯 채널 대조 후에만 기록한다. C5 대조와 실패 해결은 한 커밋이며 J3 전체 페이지의 사건 작성은 문장별 대화 공개·저자 인증과 별개다.

NP08 8종 사건 원고도 같은 계약을 따른다. `BASEMENT_PLAN`은 미검증 자료 확보와 실제 중첩 검증, `BASEMENT_FAILURE`는 실제 압력핀 잠김과 해결, `BASEMENT_ACCESS`는 직접 검증한 개방, `BASEMENT_HEART`는 실제 보조 입력의 결과다. 수면 뒤 재개방은 과거 검증을 새 획득으로 만들지 않으며, 정상 안정화/보조 조사/확정 원고는 실제 공개된 출처만 연결한다. D4 원고와 필터 상태·D5 반응 선택은 원자 저장하되 미래 반응의 대사를 기록하지 않는다. 데모에서 억제한 결과 대화의 표시 관찰도 만들지 않는다. 지하 확인창은 NP08 콘텐츠로 공통 모달 writer를 사용하고 수첩 재열람/취소/기계 조작 확정을 구분한다.

NP09 11종 사건 원고도 같은 계약을 따른다. D5의 파열 요약, D6 조사, E1 기상/다른 아침, E2 핵심 보고와 조건부 색인은 실제 해당 사건에서 작성한다. 동결한 사용인 반응은 실제 표시 관찰만 출처로 인용하며 시선 선택은 반응 재선정이나 관계 변화가 아니다. E2 보고·색인·관계 허브 개방은 원자 저장한다. 선택하지 않은 질문의 답변이나 구형 진행 플래그만 있는 과거 자료를 선행 생성하지 않는다. 휴식 확인창은 NP09 콘텐츠로 공통 모달 writer를 사용하고 실제 BROKEN_RESET과 구분한다.

NP09 시간 경과 패널·안내·정적 보드·현장 질문은 별도의 `fracture_surfaces_v1.json` 50개 정의다. `notebook_surface_capture.gd`는 실제 표시문·당시 언어·발생/세션·토큰을 동결하며 같은 방문의 재그리기와 실패 재시도를 구분한다. 표시 실패 시 다음 박자/현장 행동을 멈추고 재시도한다. 화면 세대와 슬롯/세션/로드/원본/분기/빌드/장소/단계 scope가 바뀐 콜백은 실행하지 않는다. 질문 목록 공개, 실제 선택, 게임 상태 성공은 별개이며 선택만 저장된 뒤 행동이 실패하면 성공한 선택 토큰을 재사용한다. 대화/모달 뒤의 미표시 질문, 시간 값만 지나간 미표시 박, 구형 안내 checkpoint를 공개 증거로 사용하지 않는다. 현재 요청 캐시는 실행 중에만 유효하며 앱 재시작의 같은 토큰/커서 복구는 후속이다. 새 패널 관찰로 이미 동결한 원고나 과거 출처 목록을 소급 변경하지 않는다.

같은 방문의 패널은 발생/세션을 공유하되 표시 토큰은 개별이다. `retry_required`는 실행 중 명시적 재시도 대기 상태이며 저장 스키마 필드가 아니다. 실패 이후 타이머·재그리기·언어 변경은 저장을 자동 재시도하지 않는다. 현재 세대의 재시도 버튼으로만 다시 시도하며 성공 후 해당 버튼에 있던 포커스는 살아 있는 월드 조작 또는 메뉴로 옮긴다. 요청이 전혀 없는 이전 퍼즐은 이 대기 제한으로 막지 않는다.

NP10 `mara1_v1.json`은 마라 1의 피드백 14종, 실제 화면 9종, 조건 미충족 안내 2종, 선택별 연구원 기록 2종이다. 기록 버튼 전체 본문을 실제 화면에서 읽을 수 있으면 표시 관찰을 남기지만, 그것만으로 퍼즐 순서를 배치하거나 기록 획득을 확정하지 않는다. 가려진 단자·문서와 아직 표시하지 않은 고백 문단은 관찰에 넣지 않는다. `REC_MARA1`은 실제 선택한 원본 귀속/식별자 보호 원고 하나만 생성하며 관계·완료·호환용 원문·archive·ledger와 같은 후보로 커밋한다. 보류와 재열람, 완료 플래그만 있는 과거 저장은 연구원 원고를 생성하지 않는다.

NP10의 배선 근거 부족/연대순 미완료 안내는 실제 거절 입력마다 별도 관찰이다. `notebook_surface_capture.gd`의 `new_attempt`는 이전 요청이 성공했을 때만 새 토큰을 만든다. 실패한 요청은 같은 토큰으로 재시도하며 재그리기나 타이머로 자동 반복 저장하지 않는다. 진행 중 자료/수리 상태를 불러와도 이전 관찰을 변경하지 않으며 자료 관찰과 퍼즐 배치를 혼동하지 않는다. 앱 재시작 이후 같은 표시 요청의 영속 커서는 별도 후속 범위다.

NP11 `iris_v1.json`은 피드백/조건부 응답 19종, 실제 화면 18종, 거절 2종, 연구원 원고 1종, 출처 확인창/입력 5종이다. 네 고백 모드는 실제 선택 결과의 관계 조건에서 한 번 정하고 문단 descriptor로 고정한다. 높은 경계의 감각 문장은 별도 조건이다. 첫 결과 문장만 본 시점에는 뒤 고백을 관찰로 만들지 않으며 현재 관계·언어·재열람으로 다른 응답을 합성하지 않는다. 관계 수치와 비공개 모드를 공개 변수/제목에 넣지 않는다.

NP11 연구원 원고 `REC_IRIS`는 기존의 공통 사실 요약이다. 실제 획득한 보고, 표시한 문서/복원/책임 대조/대면, 보존 입력과 자신의 참조를 사용하며 커밋 뒤에 표시될 고백은 선행 인용하지 않는다. 관계·완료·호환 원문·archive·ledger는 한 후보로 저장한다. 센서/문서 버튼의 표시 관찰은 퍼즐 배치가 아니고, 출처 확인창의 실제 입력은 정답이나 게임 저장 성공을 뜻하지 않는다. 표시/입력 저장 실패 시 콜백을 막고 불러오기 전 모달도 거절한다. 구형 완료 상태에서 원고/고백을 소급 생성하지 않는다.

NP12 `luca_v1.json`은 고정 피드백 13종, 공개 주기 1종, 실제 화면/문서 9종, 관 대조 거절 1종, 공통 연구원 원고 1종, 위상 선택창/입력 6종이다. `NB_LUCA_CYCLE`은 `line_01`의 `slot_0..slot_3`을 `enum:phase`로 선언하고 `main_1/main_2/aux_1/safety/unassigned`만 받는다. 미리보기 당시 네 칸만 보존하며 현재 퍼즐 상태에서 재계산하지 않는다. 주기와 실행 결과는 각각 표시한 문단만 기록한다. 문서 버튼의 표시 관찰은 문서 클릭 완료나 기상 기준 확인 플래그를 바꾸지 않는다.

NP12 `REC_LUCA`는 두 확인 순서의 공통 사실 원고다. 실제 보고·관 대조/성공/문서/고백 관찰·선택한 NP05 문구·원고 자신의 참조만 사용하고, 저장 뒤 나올 위험/안정 결과 문장은 선행 인용하지 않는다. 기존 퍼즐 정답·압력 복귀·관계 delta는 유지한다. 원고/관계/완료는 한 후보로 저장하며 기존 완료 플래그만으로 새 원고를 생성하지 않는다. 위상 선택창은 실제 목록 공개와 확정/취소를 구분하고 표시 저장 실패나 이전 로드의 콜백에서는 배치를 실행하지 않는다.

NP13 `edgar_v1.json`은 E3_4의 이력·권한 배치·모순·책임 보고·조건부 응답·화면·선택창·공통 원고 45종이다. 모순 판단에서 실제 반환한 문장 키만 순서대로 공개한다. 맞는 배치는 유지하고 틀린 카드만 되돌리는 게임 규칙은 변경하지 않는다. 관계별 추가 응답은 당시 실제 표시한 것만 보존한다. 연구원 원고와 최소 코어 접근 절차를 같은 사건/권한으로 취급하지 않는다.

NP14 `mara2_v1.json`은 E3_5의 신호·초상화 표식·칸 상태·보조 기록·고백·조건부 응답·입력 모달·공통 원고 103종이다. 아홉 고정 칸과 세 결손 칸의 네 표시 상태를 구분하고, 아직 배치하지 않은 정답 조각을 선행 공개하지 않는다. `CHECKSUM_COUNT.line_01.matches`만 선언된 공개 정수로 저장한다. 원본 발견 결과는 별도 문단이며 수치만 보고 그 뒤 문장을 추정하지 않는다.

NP13/14의 기능·출처·정렬·결손 선택 목록은 대상별 정의를, 동일한 선택 문구는 해당 그룹의 정의를 공유한다. 목록과 선택이 같은 발생/대화 세션을 가지므로 다른 기능/초상화/정렬 종류/칸의 선택은 문맥으로 구별한다. 입력 저장 실패 시 동작을 실행하지 않고 낡은 로드 scope의 콜백을 거절한다. 입력 기록은 게임 상태 저장 성공이나 정답 판정이 아니다.

`REC_EDGAR/REC_MARA2`는 각각 기존 공통 사실 원고다. 실제 획득한 보고·현재까지 표시한 자료/고백·선택한 NP05 문구·자신의 참조만 인용하고 선택 뒤의 결과 문장은 미리 인용하지 않는다. 관계·완료·호환 문자열·archive·ledger는 한 번에 저장한다. 기존 완료 플래그만으로 신규 원고를 소급 생성하지 않으며, 마라 2 미완료의 익명 인덱스 경로를 유지한다.

NP15 `settlement_v1.json`은 E5/E6/EDGAR_S3/MARA2_FU의 등록분 75종이다. 결산의 당시 완료·관계·이전 선택으로 정한 문장만 순서대로 실제 공개하며, 현재 상태로 과거 결산을 재계산하지 않는다. 공동 질문/이름 응답/에드가 요청의 목록과 선택은 같은 발생/세션에 속한다. E5 결산·E6 진입의 확인창 취소는 해당 게임 행동을 실행하지 않는다.

이름을 적는 `e6_mara2:write`만 `MARA2_NAME` 원고·관계·후속 완료·호환 문자열·ledger를 원자 저장한다. 기존 REC_MARA2 revision과 실제 표시한 이름 보드/목록/선택만 추가 출처이며, 뒤의 응답은 선행 인용하지 않는다. `call/joke`나 기존 이름 플래그를 불러오는 동작은 새 이름 원고를 만들지 않는다. E6 진입 결과는 전환 전 문맥인 E6·3장에 남고 엔딩 결정은 실행하지 않는다. J4/최소 접근 원고는 이 등록분에 포함하지 않는다.

`notebook_event_notes.gd`는 NP06~NP16 등록 단일 `body` 원고의 후보 작성 공통 경로다. 다중 문단 원고를 첫 본문만으로 축약하지 않도록 `NB_EVENT_NOTE_COMPOSITION_REQUIRED`로 거절한다. `source_knowledge_ids`는 현재 ledger의 획득 revision만 연결한다. 선택적인 `source_content_ids`는 현재 archive에서 해당 ID의 최신 authored 관찰과 그 항목에 이미 공개된 segment만 연결한다. 전체 카탈로그의 segment를 순회해 미열람 본문을 출처로 만들지 않는다. 정확한 버전/한국어 공급문을 확인한 뒤 현재 언어의 원고를 작성하며 실패 후보에서 원래 상태를 부분 변경하지 않는다. ledger의 `source_refs`에는 원고 자체의 `observation_ref`가 항상 포함되며, 추가 외부 출처가 없어도 그 자기 참조는 남는다.

J4는 `journal_four_notebook.gd`가 현재의 명시적인 획득 정보로 복합 원고를 구성한다. 원고 정의 `NB_J4_DOCUMENT`의 19개 문단 중 실제 포함한 문단만 하나의 observation으로 원자 저장한다. `observation_ref`는 첫 문단이며 모든 자기 문단을 `source_refs`에 포함해 보호한다. 다중 문단 acquire는 동일 언어/공개 방식, 선언된 순서·변수·표시문 전체의 재구성 일치를 검사한다. 동일 revision 재시도는 전체 observation과 전체 출처가 같아야 하며 공개 문단의 자기 참조 누락도 거부한다. ledger schema는 1, archive schema는 2로 유지하며 기존 단일 문단 자료도 유효하다.

알려진 REC revision은 ID/버전과 저장 당시 원고가 일치할 때만 해당 동결 번역을 인용한다. 이 정보가 없는 이전 문자열은 카탈로그의 `original_only_segments`에 명시한 문단에서만 그대로 보존한다. 해당 문단의 변수는 `original_text: string` 하나이며 템플릿은 공백을 제외하면 `{original_text}`만 허용한다. 재열람은 `original_only`와 원문 안내를 제공하고 문자열 안의 중괄호를 다시 치환하지 않는다. 기존 기록의 획득 시점·언어·출처 ID를 추정하지 않으며 새로운 연구원 기록을 소급 발급하지 않는다. 본문 없는 획득 인덱스는 기존 인덱스만 보존한다.

J4 전체 한국어 원고가 기존 게임 규칙의 출력과 정확히 같아야 저장할 수 있다. J4 기본/확장/전원 문단 조건은 기존 규칙대로 유지한다. 이 복원 원고 획득은 대화 문장 표시 증거가 아니며 J4 확인창/피드백·E3_4M 표시는 별도의 ID와 공개 시점으로 연결한다. `CONTENT.presentation`은 검증된 descriptor의 표시문을 계산할 뿐 공개/획득/저장 상태를 변경하지 않는다.

선택적인 `superseded_by_content_ids`는 같은 지식 카드의 최신 revision이 해당 후속 원고를 실제로 획득했을 때 하위 단계의 재작성을 생략한다. C1 가설을 C0 관찰로, 검증한 지하 도면을 처음 확보한 자료로 되돌리지 않는 명시적 규칙이다. 진행 플래그만으로 획득을 추정하지 않으며 반복 행동의 실제 대화 관찰은 생략하지 않는다. 원문/ledger 유효성 검사는 생략 판정보다 먼저 수행한다.

ledger와 archive, 호환용 문자열, 사건 진행을 하나의 저장에 넣는다. 실패 후보는 공개하지 않으며 NP03은 대기 요청을 유지하고 NP06~NP16 등록 원고는 사용자 재시도에서 미공개 후보를 다시 만든다. 조회는 쓰기를 실행하지 않는다. 정상 리셋은 ledger/출처를 보존하며, 의미 갱신은 이전 원고를 덮어쓰지 않는다. JSON의 정수 표현은 archive와 ledger 참조를 함께 정규화하고 소수 순번은 거부한다. 미래 ledger schema는 checksum 이후 호환 불가로 반환하여 원본/백업을 덮어쓰지 않는다. 현재 공급 범위와 실행 근거는 [생산자 연결 현황](../ideas/md/v04/issues/validation/notebook_content_mapping_status.md)을 따른다. J5·엔딩 원고와 새 카드 UI는 아직 후속 작업이다.

J4 복원 시 선택한 문단 descriptor를 `last_feedback`에 저장하고 실제 표시한 한 줄만 별도 `displayed` 관찰로 기록한다. 전체 원고의 `replay_committed`는 대사 전체 열람을 뜻하지 않는다. 출처 없는 옛 인용은 `original_only_segments`의 문자열 그대로 표시하며 문자열 역검색 번역을 하지 않는다. 조사 종료 확인창은 당시 완료/기록 수·미완료 조합·예상 시간·최소 접근 경고만 선언 변수/segment로 고정한다. 목록·취소·확정·후속 게임 저장과 E3_4M 보상 없음은 서로 다른 계약이다. 이 연결은 프로세스 재시작 시 표시 커서 복원을 구현한 것이 아니다.

NP16 `core_v1.json`의 122개 정의는 F0-A~E 결과·정적/가변 화면·작성자/임시 의향 입력·원고를 분리한다. 규칙이 내보낸 명시적 증거 키와 허용 변수만 descriptor로 만들며 실제 표시한 문단만 관찰한다. 방/방위/역할/표식은 언어 독립 토큰이고 수치 변수는 JSON 왕복 뒤 정수로 복원한다. 표본 이름표는 추적 본문을, 조사점 이름은 조사 완료를, 자료의 과거 사건 언급은 그 사건을 직접 목격했다는 사실을 대신하지 않는다.

`queue_descriptor`는 scope 안에서 descriptor와 표시 언어별로 요청을 구별한다. 재그리기는 같은 요청을 쓰고 다른 공개 값은 새 토큰으로 보존한다. 실패한 요청은 원래 값으로 명시적 재시도하며 자동 입력으로 우회하지 않는다. 이 캐시는 현재 실행 범위이고 내구성 있는 재시작 커서는 별도다.

세 중첩 자료의 `visual`은 의미 버전별 경로/마커/선/고리/변환 기준의 동결 메타데이터다. 관찰의 선언 변수는 당시 변환 상태다. 향후 비교 렌더러는 이 둘로 표시하고 현재 퍼즐 상태나 정답으로 과거 그림을 재생성하지 않는다. 시각 자료 확대·비교 소비 UI는 아직 구현 전이다.

`ANON_PURPLE_RESIDENT_INDEX`, `F0_CURRENT_AUTHOR`, `F0_PROVISIONAL_INTENT`의 원고는 NP16의 단일 body 후보로 기존 공통 writer에서 게임 상태·ledger·archive와 원자 저장한다. 익명 인덱스는 연구원 관계 기록을 지급하지 않는다. 작성자 인증은 선택한 삶의 방향과 별개이고 세 임시 의향 모두 `ending_run.final_decision`을 변경하지 않는다. 출처는 실제 획득/공개한 기존 원고·목록·선택뿐이며, 이후 나올 응답이나 구형 완료 플래그에서 관찰을 추정하지 않는다. 식별 불가능한 옛 A1 표식은 원문 전용 descriptor로 보존한다.

### 7.2 초기 저장 지점

| ID | 생성 조건 | 안전 재개점 |
| --- | --- | --- |
| `SAVE_P6_COMPLETE` | 첫 취침 확정 | NORMAL_RESET 진입 |
| `SAVE_NORMAL_RESET_COMPLETE` | 각 정상 리셋 transaction 완료 | 같은 아침 ROUTE |
| `SAVE_A2_COMPLETE` | 수첩 표시 지속 확인 | B1 진입 |
| `SAVE_J1_COMPLETE` | J1 원자 완료 | B3 준비 |
| `SAVE_J2_COMPLETE` | J2 원자 완료 | 다음 정상 리셋 |
| `SAVE_J3_COMPLETE` | J3 원자 완료 | D0 진입 |

동일 ID의 저장을 반복 생성할 수 있지만 최신 완전 transaction만 현재 진행으로 승격한다. 세계 리셋 도중의 중간 상태를 안전 지점으로 표시하지 않는다.

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
- 저장 헤더의 flavor·경계가 허용 event registry와 일치한다.
- 대화 기록의 `sequence`가 중복되지 않고 모든 `line_id`, `speaker_id`, `choice_id`가 등록되어 있다.
- 한국어·영어의 placeholder 집합과 타입이 같다.
- 색·음향·모션을 제거해도 필수 상호작용이 남는다.
- 진행 설정 변경 전후 진행 checksum payload가 같다.

오류는 조용히 건너뛰지 않는다. 필수 Resource 오류는 export를 차단하고 선택 Resource 오류는 해당 콘텐츠를 비활성화한 뒤 개발 오류 ID를 남긴다.
