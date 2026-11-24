# 대사 JSON 작성 규격

프롤로그(CNT-EP00)부터 EP02까지의 공통 작성 템플릿이다. 2026-11-03 작업 트리와 소비 코드를 기준으로 정의했다. 이 폴더의 예시는 게임에 등록되지 않은 작성용 자료다. 에드가 첫 서브스토리는 같은 runtime·문구 카탈로그 구조의 별도 파일을 사용한다. [런타임](../../../game/data/dialogue/substories/edgar_sub_01.json) · [문구 카탈로그](../../../game/data/notebook/edgar_sub_01_v1.json)

**원문·연결은 runtime 형식에 작성하고, 표시·기록용 content 카탈로그를 같은 원문에서 파생한다.** 두 형식을 하나의 작성 규칙으로 관리한다. 현재 게임에서는 content 카탈로그가 실제 표시 문구를 담당하는 경로도 있으므로, 적용 시에는 두 산출물이 일치해야 한다.

| 템플릿 | 작성 단위 | 사용 |
| --- | --- | --- |
| [runtime.template.json](runtime.template.json) | 화면에 표시할 발화·지문·선택지 한 개를 `nodes` 한 행으로 작성 | 원문, 화자, 초상화, 다음 연결, 조건·효과 의도 |
| [content.template.json](content.template.json) | `content_id`의 특정 버전 한 개 | 실제 표시 문구, 문구 분절, 번역, 당시 기록 재현 |

예시의 `TEMPLATE` ID·문구·출처는 교체한다. `mapping_status: AUTHORED_ID`는 카탈로그 식별 규약이며 게임 호출 연결 완료 표시가 아니다. 템플릿은 완성된 시트 스냅샷이나 게임에 바로 추가할 패키지가 아니다. 생성 필드·에피소드별 연결·등록이 별도로 필요하다.

기존 동기화 도구의 입력은 Google Sheets CellData 스냅샷이다. 이 작성용 JSON을 직접 받아 변환하는 새 importer는 이번 작업에서 추가하지 않는다. 아래 규격은 집필 내용과 적용 시 대응 관계를 정의한다.

## 1. 현재 파일과 대응

세 runtime 파일의 행 열은 공통 시트 v3 계약을 사용한다. 수첩 카탈로그도 `format_version → contents → ID → 버전 → 정의`가 공통이다. 차이는 아래 확장과 실제 소비 경로에 있다.

| 범위 | 실행·연결 JSON | 문구·기록 JSON | 실제 표시와 연결 |
| --- | --- | --- | --- |
| 프롤로그 | `game/data/dialogue/sheets/prologue_runtime.json` | `game/data/notebook/prologue_v1.json`, `prologue_notes_v1.json`, `prologue_surfaces_v1.json` | `_prologue_line()`이 `source_text_id`로 기존 `.tres` 문구를 읽고 카탈로그로 기록을 검증. alias·응답 묶음·연출 override 사용 |
| EP01 | `game/data/dialogue/chapter_one/ep01_runtime.json` | `game/data/notebook/ep01_sheet_v1.json`, `chapter_one_v1.json`, `chapter_one_notes_v1.json` | `Ep01Script.line()`은 카탈로그를 표시. `Ep01Script.text()`에는 runtime 본문 직접 조회 경로도 있음 |
| EP02 | `game/data/dialogue/sheets/ep02_runtime.json` | `game/data/notebook/ep02_sheet_v1.json`, `mirror_v1.json`, `ep02_player_versions.json`, `ep02_modal_versions.json`, `ep02_hint_versions.json` | 카탈로그를 표시하며 EP02 추가 버전 파일도 함께 조회 |
| 공용 | 에피소드 runtime과 컨트롤러의 호출 | `modals_v1.json`, `hints_v1.json`, `puzzle_surfaces_v1.json`, `chapter_surfaces_v1.json` 등 | 메뉴·힌트·화면 문구의 실제 사용 구간에 따라 연결 |

파일명의 `_v1`은 내부 모든 콘텐츠가 버전 1이라는 뜻이 아니다. 같은 파일에 여러 콘텐츠 버전이 들어갈 수 있다. `ep02_*versions.json`도 별도 문법이 아니라 같은 카탈로그 형식의 추가 버전이다.

프롤로그 runtime에는 `CNT-EP00`과 `CNT-EP01` 행이 함께 있고 `package_id`가 `MIXED_SOURCE`다. `PrologueSheetScript`는 그중 `CNT-EP00` 노드만 색인한다. 첫 취침·첫 아침의 중첩 영역은 EP01이 소유하며, 물리적 파일 위치와 원문 소유 패키지를 구분한다.

## 2. runtime 공통 템플릿

최상위 작성 필드는 `schema_version: 1`, `package_id`, `nodes`, `edges`, `predicates`, `effects`다. 사용하지 않는 배열은 `[]`로 둔다. 한 패키지의 신규 원고는 `CNT-EP00`, `CNT-EP01`, `CNT-EP02` 중 하나로 작성한다. 기존 프롤로그의 혼합 패키지 구조는 동기화 시 보존할 예외다.

공통 열 이름은 [CNT Sheet schema v3](../../requests/content/schemas/CNT_sheet_schema_v3.json), 허용 어휘는 [cnt_shared_vocab.json](../../../game/data/registries/cnt_shared_vocab.json)을 기준으로 한다. 전자는 시트 열 계약이며 JSON Schema 검증기용 스키마는 아니다.

### nodes: 표시할 내용

템플릿은 현재 38개 원본 열을 모두 포함한다. 아래 표의 ‘작성’은 신규 원고에서 채울 정보, ‘관리’는 검토·출처 정보다. 값이 없을 수 있는 열도 키는 유지한다.

신규 JSON 원고에서는 이 38개 열의 값을 문자열로 작성한다. 컴파일러가 추가하는 `sheet_row`는 정수다. 조건·효과의 정렬 숫자와 카탈로그 객체·배열에는 각각 아래에 정의한 별도 타입을 사용한다.

| 필드 | 작성 규칙 |
| --- | --- |
| `package_id` | 소유 패키지. 같은 원고의 최상위 값과 일치 |
| `node_id` | 고정 노드 ID. 프롤로그는 기존 `P1_…` 계열, 신규 EP01/EP02는 `EP01_…`/`EP02_…` 계열. 삽입·정렬로 기존 ID를 개명하지 않음 |
| `draft_id`, `line_id` | 초안 ID와 승인 후 발급하는 정식 문구 ID. 미발급 `line_id`는 `NONE`; `node_id`와 구분 |
| `scene_id`, `scene_label`, `order` | 장면 ID·작업용 이름·정렬 번호. `order`는 현재 호환을 위해 문자열. 재생은 행 위치보다 `next_type/next_id`가 결정 |
| `content_type` | 아래 유형 표의 값 |
| `speaker_id` | 실제 화자. `SUBJECT`, `SYSTEM`, `DOCUMENT`, `SERVANT_EDGAR`, `SERVANT_MARA1`, `SERVANT_MARA2`, `SERVANT_LUCA`, `SERVANT_IRIS` |
| `character_art` | 표시할 초상화. `NONE`, `EDGAR`, `MARA1`, `MARA2`, `LUCA`, `IRIS`. 화자와 독립 |
| `portrait_position`, `portrait_state` | 위치 `NONE/LEFT/CENTER/RIGHT`; 상태 `NONE/DEFAULT/NEUTRAL/SMILE/WORRIED/ANGRY/SAD/SURPRISED/GLITCH` |
| `direction` | 집필·연출 지시. 플레이어에게 보여 줄 지문은 별도 `CAPTION` 노드로 작성. 이 문자열 자체가 연출 명령어로 실행되지는 않음 |
| `ko_KR`, `en_US` | 원문과 영어. 이름표를 본문에 붙이지 않음. 영어 미완료 시 runtime의 `en_US`는 빈 문자열 허용 |
| `next_type`, `next_id` | 바로 뒤에 재생·호출할 대상. 아래 연결 규칙 참조 |
| `location_id`, `object_id`, `trigger` | 장소·대상·호출 계기. 등록 어휘 사용. `click` 등의 선언만으로 핫스폿은 생성되지 않음 |
| `display_condition_id`, `route_predicate_id` | 관련 조건 ID. 없으면 `NONE`. 조건을 적는 것과 실제 평가 코드 연결은 별도 |
| `repeat_policy` | `always/first_repeat/once/per_loop/per_state/protected/state_variant`. 소비 코드가 이 정책을 어떻게 구현하는지도 확인 |
| `request_id`, `content_item_id`, `document_id`, `knowledge_id`, `owner_id` | 의뢰·제작 묶음·문서·지식·소유자 참조. 화자와 소유자를 혼동하지 않음. 없는 ID는 `NONE`; 여러 지식 참조는 현행의 `;` 구분 규칙 유지 |
| `approval_status`, `localization_status`, `revision`, `review_owner`, `reviewed_at` | 관리. 승인 상태 `draft/in_review/approved/rejected`; 번역 상태 `not_started/not_applicable/in_review/approved`. 신규는 `draft`, `r1`, 미지정 검토자·시각은 `""` |
| `source_file`, `source_anchor`, `source_commit`, `source_checksum`, `design_revision` | 관리. 실제 원문 출처와 개정 근거. 새 체크섬·커밋을 임의로 만들어 넣지 않음 |

| 쓰려는 내용 | `content_type` | 기본 작성 |
| --- | --- | --- |
| 인물의 발화 | `DIALOGUE` | 실제 화자, 발화 본문 |
| 속생각 | `MONOLOGUE` | 보통 `SUBJECT`, 생각 본문 |
| 플레이어에게 보이는 지문·감각자막 | `CAPTION` | 보통 `SYSTEM`, 보여 줄 문장 |
| 선택 버튼 | `CHOICE` | 선택지 하나당 노드 하나. 선택 후 발화는 별도 노드 |
| 사물 조사·거부·반복 반응 | `OBJECT` | 사물과 상태에 맞는 문구 |
| 종이·일지·문서 | `DOCUMENT` | 읽을 본문. 필요 시 여러 노드·segment로 구분 |
| 수첩 안내·기록 문구 | `NOTEBOOK` | 해당 기록 문구 |
| 퍼즐 결과 | `PUZZLE_FEEDBACK` | 성공·실패·무효 입력에 맞는 문구 |
| 시스템 안내 | `SYSTEM` | 안내 문구 |

한 노드에 여러 화자의 문장을 합치지 않는다. 같은 화자라도 화면을 넘겨야 하면 노드를 나눈다. 내부 ID와 퍼즐 정답은 플레이어용 본문·제목에 설명용으로 삽입하지 않는다.

### 연결과 선택지

| `next_type` | `next_id` 대상 | 작성 의미 |
| --- | --- | --- |
| `line` | 노드 ID | 다음 문장 |
| `choice` | 선택 route ID | 선택지를 제시하고 입력 대기 |
| `router` | 조건 route ID | 상태에 맞는 경로 선택 |
| `hub` | 허브 ID | 메뉴·허브로 제어 반환 |
| `scene` | 장면·진입 ID | 현재 대사 구간을 끝내고 장면 전환 요청 |
| `episode_exit` | 다음 에피소드 진입 ID | 에피소드 인계 요청 |
| `end` | 종료 토큰 | 현재 상호작용 종료. 일반 예시는 `SYS_INTERACTION_END` |

허브·장면·에피소드 전환·종료는 컨트롤러가 처리할 대상을 확인한다. `scene`을 쓰는 것만으로 임의의 `.tscn`을 로드하지 않는다.

선택 예시는 `대사 노드 → choice route → CHOICE 노드 → 선택 후 대사/게임 행동` 순서다. 아래는 `edges` 행과 그 조건인 `predicates` 행의 형식이다. 예시 ID는 미등록이며 기존 코드에 자동 연결되지 않는다.

```json
{
  "edge": {
    "package_id": "CNT-EP01",
    "route_id": "EP01_CHOICE_TEMPLATE",
    "edge_id": "EDGE_EP01_CHOICE_TEMPLATE_01",
    "edge_order": 1,
    "predicate_id": "PRED_EP01_CHOICE_TEMPLATE_01",
    "predicate_expression": "selection == EP01_TEMPLATE_CH01",
    "target_type": "node",
    "target_id": "EP01_TEMPLATE_CH01",
    "is_fallback": "FALSE",
    "priority": 1,
    "source_condition": "선택지 1",
    "source_anchor": "작성 원고의 선택 구간",
    "design_revision": "v0.4-sheet-r3",
    "validation_status": "DRAFT"
  },
  "predicate": {
    "package_id": "CNT-EP01",
    "predicate_id": "PRED_EP01_CHOICE_TEMPLATE_01",
    "scope": "route:EP01_CHOICE_TEMPLATE",
    "state_path": "loop_state.event_local_states",
    "comparator": "matches",
    "typed_value": "selection == EP01_TEMPLATE_CH01",
    "value_type": "string",
    "logic_group": "ALL",
    "registration_status": "REGISTERED",
    "source_anchor": "작성 원고의 선택 구간",
    "design_revision": "v0.4-sheet-r3",
    "notes": "형식 예시. 실제 등록·선택 처리 연결 전에는 실행 완료로 취급하지 않는다."
  }
}
```

이 블록의 `edge`/`predicate` 묶음은 설명용이다. 실제 파일에서는 각각 `edges`/`predicates` 배열에 행을 넣는다. `REGISTERED`는 실제 등록 확인 뒤 사용한다. 미연결 초안을 등록 완료 데이터로 배포하지 않는다.

- 각 선택지에 `CHOICE` 노드를 만들고 route의 `target_id`로 연결한다. 버튼 정렬은 `edge_order`다.
- `is_fallback`은 **문자열 `"TRUE"` 또는 `"FALSE"`**다. 자동 조건 분기에 기본 경로가 필요하면 fallback은 route당 최대 한 개로 작성한다. 선택 route에는 필수가 아니다. 선택 취소 행동은 별도로 정의하며 fallback과 같은 개념으로 취급하지 않는다.
- `target_type`은 `node`, `route` 또는 코드가 처리하는 반환 대상이다. runtime의 `next_type: line/router`와 edge의 `target_type: node/route`를 구분한다.
- 현행 EP01의 선택 인식은 `EP01_CHOICE_…`, 일부 허브의 전용 처리에 의존한다. EP02는 생성된 `choice_routes`와 `conditional_choice_routes`도 사용한다.
- `Ep01Script.resolve()`는 `contains` 상태 조회와 코드가 정한 `selection/route_case`를 처리한다. 임의의 `gte/equals` 식이나 `logic_group: ALL`만 추가해도 범용 평가되지는 않는다. `priority`보다 `edge_order`가 실제 정렬 기준이다.

### effects: 완료 후 바뀌어야 할 상태

효과 한 개는 다음 형식으로 작성한다. 아래 예시는 현행 EP02의 관계치 효과와 같은 구조를 사용하며 새 등록을 뜻하지 않는다.

```json
{
  "package_id": "CNT-EP02",
  "effect_id": "EFF_EP02_TEMPLATE_01",
  "event_id": "C0",
  "node_id": "EP02_TEMPLATE_001",
  "effect_order": 1,
  "state_path": "meta_progress.servants.edgar.bond",
  "operation": "increment",
  "value_type": "int",
  "typed_value": "1",
  "writer": "StateWriter",
  "commit_phase": "event_commit",
  "repeat_policy": "once",
  "registration_status": "REGISTERED",
  "source_anchor": "작성 원고의 완료 노드",
  "source_checksum": "",
  "design_revision": "v0.4-sheet-r3",
  "notes": "등록·소비 코드 확인이 필요한 효과 형식 예시"
}
```

`effect_id`는 효과 중복 적용 방지에도 사용되므로 고정한다. `event_id`는 효과가 속한 사건이며 대사 장면 ID와 항상 같지는 않다. `node_id`는 완료를 판단할 실제 노드다.

`operation`은 `set/increment/add/remove`, `writer`와 `commit_phase`는 공유 어휘 및 실제 소유 시스템에 맞춘다. `registration_status`는 실제 등록 결과를 기록한다. 경로는 [state_path_registry.json](../../../game/data/states/state_path_registry.json)과 소비 코드를 함께 확인한다.

| 값 | `value_type` 신규 작성 표기 | `typed_value`의 JSON 표현 |
| --- | --- | --- |
| 정수 | `int` | `"1"` |
| 불리언 | `bool` | `"true"` |
| 문자열 | `string` | `"기록 내용"` |
| 객체 | `dictionary` | `"{\"flag\":true}"` |

`typed_value`는 실제 값이 숫자·불리언·객체여도 **JSON 문자열**이다. 프롤로그의 기존 `integer/boolean`은 과거 표기이며 이 작성 규칙의 `int/bool`과 대응시킨다. 개별 효과 소비자가 허용하는 타입·연산이 우선한다.

현재 EP01은 허용된 대화 완료 표시 등 일부 효과만, EP02는 전용 코드가 허용한 관계치·기억·지식·이력 효과만 반영한다. 인벤토리·퍼즐 정답·물리 전이·리셋은 Session/Coordinator 소유다. 조건·효과 행을 작성한 다음 **어느 코드가 언제 소비하는지**까지 연결해야 동작한다.

## 3. 문구·기록 카탈로그 템플릿

[content.template.json](content.template.json)은 runtime 예시의 `EP01_TEMPLATE_001`에 대응한다. 기본 ID는 `NB_` + 노드 ID다. 프롤로그는 기존 `NB_PR_…`, 공용 UI·피드백은 각 기존 content ID를 유지한다.

| 필드 | 작성 규칙 |
| --- | --- |
| `format_version` | 카탈로그 형식 버전 `1`. 개별 문구 버전과 구분 |
| `contents[content_id]["1"]` | 고정 콘텐츠 ID 아래의 문자열 버전 키. 버전 `2`는 `"2"`로 추가 |
| `producer_id`, `source_file`, `source_symbol` | 생산자와 출처. EP01/02 시트 문구는 `EP01_SHEET/EP02_SHEET`, source symbol은 노드 ID. 프롤로그 기존 생산자는 `NP01` 등 각 출처 유지 |
| `event_id`, `node_ids` | 기록 사건과 허용 재생 문맥. 시트 대사는 보통 장면 ID/노드 ID지만, 프롤로그는 `PG`, `P3` 등 기존 문맥을 사용하므로 무조건 같은 이름으로 맞추지 않음 |
| `action_or_variant` | 같은 사건의 표시 목적. 시트 대사는 `sheet_line`, 선택지 표시는 `options` 등 기존 생산자 규칙 사용 |
| `speaker_id`, `locales.*.speaker` | 내부 화자 ID와 언어별 이름표. 별개 값. 새 시트 원고는 `SERVANT_*` 계열 사용; 기존 프롤로그의 `EDGAR` 등 기록 ID를 일괄 개명하지 않음 |
| `location_source` | 장소의 출처. 시트 문구 예시 `history_context:actual_room`; 실제 장소는 표시 순간의 문맥에서 기록 |
| `entry_kind` | 아래 6종 중 하나. runtime의 `content_type`과 별도 분류 |
| `disclosure_owner` | 보통 `actual_display_or_choice_press`. 지식 획득 커밋에서 기록하는 정의는 `event_note_commit`과 해당 `knowledge` 확장을 사용 |
| `mapping_status`, `owner` | `AUTHORED_ID`, 담당 출처. 예시 담당은 `development/content` |
| `visible_segment_ids` | 정의된 표시·기록 분절의 순서. 최소 1개, 중복 불가. 실제 표시는 이 중 선택된 일부만 가능 |
| `protection_reasons` | 보호 사유 배열. 없으면 `[]`. 보호 항목의 기존 정책을 유지하며 분류·숨김 규칙은 소비 코드 확인 |
| `variables`, `localization_keys` | segment마다 변수 타입 객체와 고정 번역 키. 변수가 없어도 `{ "body": {} }` 필요 |
| `locales` | `ko-KR`, `en-US` 모두 필요. 각각 `title/summary/speaker`와 모든 segment 본문은 빈 문자열 불가 |

현행 검증은 비어 있지 않은 생산자·출처·문맥 문자열, 중복 없는 배열, 두 언어 및 segment별 정의를 요구한다. 작성 원본의 영어가 비어 있으면 파생 카탈로그의 `en-US` 본문은 한국어로 폴백할 수 있다. 예시도 이 규칙을 사용한다. 이를 번역 완료로 표시하지 않는다.

| 기록 목적 | `entry_kind` |
| --- | --- |
| 표시한 발화·일반 피드백 | `dialogue` |
| 실제 제시한 선택지 묶음 | `options_presented` |
| 확정한 선택 | `choice_confirmed` |
| 취소한 선택 | `choice_cancelled` |
| 문서·지식·화면 기록의 공개 부분 | `document_segment` |
| 열어 본 힌트 | `hint_revealed` |

`CAPTION → caption`, `SYSTEM → system`처럼 기계적으로 소문자 변환하지 않는다. 감각자막과 UI 라벨도 현재 생산 경로에 따라 `dialogue` 또는 화면 segment로 기록된다.

EP02 감각자막은 `captions_enabled`와 전용 코드의 허용 노드 목록으로 삽입된다. `CAPTION` 노드 작성만으로 접근성 설정에 따른 노출 제어가 자동 연결되지는 않는다.

### 변수와 여러 segment

```json
{
  "visible_segment_ids": ["body"],
  "variables": {"body": {"knowledge_count": "int"}},
  "localization_keys": {"body": "NB_EXAMPLE:body"},
  "locales": {
    "ko-KR": {"title": "수첩", "summary": "기록 수", "speaker": "주인공", "body": "기록이 {knowledge_count}개 남아 있다."},
    "en-US": {"title": "Notebook", "summary": "Record count", "speaker": "Protagonist", "body": "There are {knowledge_count} records."}
  }
}
```

위 블록은 전체 row에 넣을 변수 부분 예시다. 변수명 집합은 각 언어의 `{placeholder}` 집합과 정확히 같아야 한다. 호출 순간에도 같은 이름과 타입의 값을 제공한다. 타입은 `string/int/float/bool/enum:이름`; enum은 `enums`에 두 언어의 동일 토큰 집합과 번역을 정의한다.

카탈로그가 지원하는 타입과 현재 생성 도구의 추론 범위는 다르다. EP01·EP02 시트 동기화는 현재 원문 placeholder를 `int`로 생성하므로, 다른 타입의 변수를 새로 쓰려면 생성·호출 경로의 지원도 확인한다.

같이 표시되는 문장 안의 줄바꿈은 `\n`으로 쓴다. 조건부 결과·자막·옵션처럼 공개 시점이 다르면 `header/option_0/result/caption` 등의 별도 segment로 나눈다. 순서는 `visible_segment_ids`가 결정한다. 실제 보이지 않은 segment를 함께 기록하지 않는다.

### 선택지의 표시·확정·취소

선택지는 runtime의 `CHOICE` 노드 외에 카탈로그에도 제시·확정 기록을 각각 갖는다. 선택지 표시 row의 확장 예시는 다음과 같다.

```json
{
  "entry_kind": "options_presented",
  "visible_segment_ids": ["option_0", "option_1"],
  "default_segments": ["option_0", "option_1"],
  "choices": [
    {"content_id": "NB_EP01_CHOICE_TEMPLATE_SELECT_0", "kind": "confirm"},
    {"content_id": "NB_EP01_CHOICE_TEMPLATE_SELECT_1", "kind": "confirm"}
  ],
  "cancel_index": -1
}
```

이 역시 전체 row의 일부다. 각 option에 `variables`, `localization_keys`, 두 언어 본문을 정의한다. 각 `choices[].content_id`는 별도 `choice_confirmed` row로 만들고, 같은 사건의 option 문구와 해당 row의 `body`를 **두 언어 모두 일치**시킨다. 확정 기록 ID는 CHOICE 노드의 문구 ID와 별개로 생성되는 경우가 있다.

취소 기록은 `choice_cancelled` 정의와 실제 취소 콜백을 연결한다. `cancel_index`와 `choices[].kind`는 기존 UI 소비 규칙을 따른다. 프롤로그는 `author/locked/silent/confirm/cancel` 등의 segment명을 사용하고, 거울 모달은 header·판정·경로·자막을 같은 정의 안에서 부분 공개하므로 이를 `option_n`으로 일괄 개명하지 않는다.

## 4. 에피소드별 연결·생성 필드

| 항목 | 현재 대응 및 템플릿 처리 |
| --- | --- |
| `source_url`, `source_sha256`, `source_package_ids`, `sheet_row` | 동기화·컴파일 출처. 템플릿에 가짜 URL·해시·행 번호를 넣지 않는다. source hash는 입력 스냅샷의 해시이며 원문 파일 checksum과 구분 |
| `adapter_provenance` | EP02 추가 무명 행 연결 시 도구가 생성할 수 있는 출처. 신규 JSON 원고는 명시적 노드 ID를 작성 |
| `notebook_versions` | content ID → 정수 버전 연결. EP01은 지정 버전, EP02는 지정 버전과 현재 로드 카탈로그의 최신 버전을 함께 조회 |
| 프롤로그 버전 연결 | 현재 프롤로그의 새 content 버전 연결도 EP01 runtime의 `notebook_versions`를 사용. 프롤로그 파일에 같은 필드를 추가하는 것으로 대체하지 않음 |
| `overlap_owner` | 프롤로그 중첩 부분의 소유는 `EP01`. 첫 취침·첫 아침 연결을 임의로 EP00로 이동하지 않음 |
| `prologue_aliases` | 기존 호출 키 → 실제 노드 ID. ID를 추가해도 기존 컨트롤러 호출 키는 자동 생성되지 않음 |
| `prologue_response_sequences` | 응답 키 → 표시할 노드 ID 배열. 현행 대상은 `P3_A_AUTHOR`, `P3_A_LOCKED`, `P4_A_FATHER_TEA`; 분할 응답의 `_001`, `_002` 순서를 도구가 검사 |
| `prologue_render_overrides` | 노드 ID → `speaker_id/character_art/portrait_position/portrait_state` 변경. 특수 컵·맥박·음향 연출은 컨트롤러 extras 소유 |
| `choice_routes`, `conditional_choice_routes` | EP02 선택 경로 목록. 동기화 도구가 연결 구조에서 추출. 임의 이름의 선택 route를 추가할 때 소비 코드까지 확인 |
| `source_text_id`, `text_source` | 프롤로그 카탈로그에서 기존 텍스트 ID/`.tres`를 연결. 표시 본문·화자와 카탈로그 기록 정의를 맞춤 |
| `knowledge`, `source_knowledge_ids`, `legacy_key`, `new_attempt` | 지식·문서·레거시 기록용 확장. 일반 대사 템플릿에 무조건 넣지 않고 해당 기록 생산자의 기존 계약을 사용 |
| `source_sheet_segments` | 모달·힌트 등의 개정 문구가 어느 시트 노드에서 파생됐는지 연결 |
| `source_display_policy`, `source_raw_content_version` | EP02 플레이어용 개정 문구의 출처 추적. 분기 조건이나 버전 선택을 자동 실행하는 명령은 아님 |

새 작성의 타입은 `nodes.order`는 문자열, `edge_order/priority/effect_order`는 정수, `is_fallback/typed_value`는 문자열로 통일한다. 기존 프롤로그의 정렬 필드 문자열은 읽는 코드가 정수로 변환하는 호환 예외이며 기존 파일을 이번 작업에서 재작성하지 않는다. `NONE`은 부재 ID, `""`는 비어 있는 본문·관리값에 사용한다. 프롤로그의 기존 `NOT_CONNECTED/PROPOSED/source_action`을 신규 정본 허용값처럼 복제하지 않는다.

## 5. 문구 개정과 적용 전 확인

`revision: r2`는 원고 관리 개정이고 `contents[id]["2"]`는 저장 기록 재현용 콘텐츠 버전이다. 서로 대체하지 않는다. 문구·화자·segment·변수 계약 등 기존 기록에 영향을 주는 정의가 바뀌면 새 콘텐츠 버전을 만들고 이전 버전을 보존한다. 같은 `content_id + version`은 로드되는 모든 카탈로그에서 한 번만 정의한다.

프롤로그·EP01·EP02의 공통 확인 순서는 다음과 같다.

- [ ] UTF-8 JSON 문법이 유효하고 ID가 고정·고유한가.
- [ ] runtime 4개 배열과 모든 원본 열을 유지했는가. 노드·route·조건·효과 참조가 존재하는가.
- [ ] 타입·`NONE`·허용 어휘가 맞는가. 행 순서가 아닌 ID로 연결했는가.
- [ ] 문구 한 노드의 화자·본문·초상화가 의도에 맞는가. 제작 지시와 표시 지문을 나눴는가.
- [ ] 원고, 표시용 카탈로그, 프롤로그 `.tres`가 해당 표시 경로에서 일치하는가.
- [ ] 두 언어, segment, 변수 계약이 맞고 미번역 폴백을 번역 완료와 구분했는가.
- [ ] 선택지 표시·확정·취소, 힌트·감각자막이 실제 공개된 범위만 기록하는가.
- [ ] 기존 콘텐츠 버전을 보존하고 각 에피소드의 버전 연결을 확인했는가.
- [ ] 조건·효과·게임 행동·장면 전환을 처리할 실제 소비 코드가 연결되어 있는가.

이번 산출물은 작성 규격과 예시다. 동기화 도구 실행·런타임 마이그레이션·기존 대사 개정은 포함하지 않는다.

## 근거 코드

- [compile_script_sheet.py](../../../scripts/compile_script_sheet.py): 4개 원본 테이블 컴파일과 ID 연결 확인.
- [sync_ep01_sheet.py](../../../scripts/sync_ep01_sheet.py), [sync_ep02_sheet.py](../../../scripts/sync_ep02_sheet.py), [sync_prologue_sheet.py](../../../scripts/sync_prologue_sheet.py): runtime·카탈로그·프롤로그 연결과 버전 보존.
- [ep01_script.gd](../../../game/scripts/systems/ep01_script.gd), [prologue_sheet_script.gd](../../../game/scripts/systems/prologue_sheet_script.gd): 노드·route·프롤로그 확장 소비.
- [prologue_controller.gd](../../../game/scripts/prologue/prologue_controller.gd): `_prologue_line()`, `_prologue_response()`, 표시·선택·연출 호출.
- [notebook_content.gd](../../../game/scripts/systems/notebook_content.gd), [notebook_observation_schema.gd](../../../game/scripts/systems/notebook_observation_schema.gd): 카탈로그 검증·표시·관찰 기록 계약.
- [sheet_dialogue_effects.gd](../../../game/scripts/systems/sheet_dialogue_effects.gd): EP02에서 실제 허용하는 효과.
- [사용인 대화 시트 작성 기준](../../requests/content/05_사용인대화_시트작성기준.md), [EP01 수정 대사 재생 시점](../../decisions/GGB-DEC-2026-0013_EP01_수정대사_재생시점.md): 대화 단위와 중첩 구간의 기존 작성·재생 규칙.
