# GGB 현지화 제작 계약

## 1. 범위와 정본

| 항목 | 기준 |
| --- | --- |
| 필수 locale | `ko-KR`, `en-US` |
| 원문 언어 | `ko-KR` |
| 음성 | 없음 |
| 문자열 정본 | 추적 가능한 UTF-8 CSV 또는 Godot Translation Resource |
| ID 정본 | `TXT_*`, `DLG_*`, `UI_*`, `SYS_*` registry |
| 제품 기준 | [제품 계약](product_contract.md) |

Markdown의 대사 예시는 서사 기준이지만 런타임 문자열 정본은 아니다. 실행 대사는 안정된 `line_id`를 통해서만 참조하고 코드, 씬과 퍼즐 데이터에 사용자 노출 문장을 직접 넣지 않는다.

## 2. 문자열 레코드

```yaml
localization_entry:
  line_id: DLG_EDGAR_B1_001
  ko_KR: "..."
  en_US: "..."
  speaker_id: SERVANT_EDGAR
  event_id: B1
  context: "주인공이 시간표를 처음 조사한 직후"
  emotion: guarded
  register: formal_danakka
  variables: []
  max_lines: 3
  max_width_class: dialogue_normal
  spoiler_tier: seen_only
  status: reviewed
  translator: ""
  reviewer: ""
  source_revision: 1
```

필수 필드:

| 필드 | 규칙 |
| --- | --- |
| `line_id` | 발급 후 의미 재사용 금지 |
| `ko_KR`, `en_US` | 줄바꿈을 포함한 실제 표시 문장 |
| `speaker_id` | 화자 없음은 `SYSTEM`, 독백은 `SUBJECT` |
| `event_id` | 최초 발생 사건, 공통 UI는 빈 값 허용 |
| `context` | 번역자가 장면을 이해할 한 문장 |
| `emotion` | 표층 감정과 숨은 의도가 다르면 둘 다 기록 |
| `register` | 캐릭터·시스템 말투 토큰 |
| `variables` | 허용 placeholder와 타입 |
| `max_lines` | 목표 UI에서 허용하는 최대 줄 수 |
| `spoiler_tier` | 대화 기록·갤러리 노출 조건 |
| `status` | `draft`, `translated`, `reviewed`, `locked` |

## 3. 캐릭터 말투 기준

| 화자 | 한국어 | 영어 방향 | 피해야 할 것 |
| --- | --- | --- | --- |
| 에드가 | 예외 없이 딱딱한 다나까체 | 간결하고 정확한 formal register, 호칭 유지 | 갑작스러운 축약·속어·친근한 반말 |
| 마라 1 | 유연한 말투와 슴다체, 감정 변화 큼 | 빠르고 현장감 있는 구어체, 정비 은어 | 문법 오류로만 우스움을 표현 |
| 루카 | 말줄임표가 잦고 조심스럽지만 필요할 때 단호함 | hesitation은 짧은 pause로, 결단 순간은 문장 완결 | 모든 문장을 무기력하게 흐림 |
| 이리스 | 부드럽고 모성적인 웃음, 속뜻은 관계에 따라 변화 | warm polite surface와 통제적 subtext의 간극 | 초반부터 노골적인 악역 어조 |
| 마라 2 | 장난스럽고 느낌표가 잦은 영리한 반말 | witty, quick, overconfident cadence | 유아화·성적 뉘앙스·무작위 인터넷 은어 |
| 주인공 | 감각과 심리 반응 중심, 이름·정확한 나이 회피 | concise sensory internal voice | 플레이어 선택을 대신 확정하는 가치 판단 |

고유 말투는 철자 훼손이나 과도한 방언으로 대체하지 않는다. 영어에서 완전히 대응하지 않는 말투는 문장 길이, 형식성, 어휘 선택과 리듬으로 구분한다.

## 4. 용어 기준선

| 한국어 | 영어 기준 | 비고 |
| --- | --- | --- |
| 주인공 | Subject | UI·시스템 내부 호칭, 대사에서는 상황에 맞게 생략 가능 |
| 사용인 | servant | 고딕 표층 역할 |
| 연구원 | researcher | 원본 인격의 과거 직무 |
| 정상 리셋 | Normal Reset | `NORMAL_RESET` 표시명 |
| 파열 후 휴식 | Post-Fracture Rest | `POST_BROKEN_REST` 표시명 |
| 영구 정보 | persistent knowledge | 물리 아이템과 구분 |
| 일지 복원 | journal restoration | 데이터 복원 의미 병행 |
| 위장 필터 | camouflage filter | 고딕 외형을 유지하는 시스템 |
| 색상 서명 | color signature | 색만이 아니라 패턴·음향 포함 |
| 저택 코어 | manor core | 시설과 시뮬레이션 경계 장치 |

정식명·사용인 최종 이름이 결정되면 용어집 revision을 올리고 ID는 불필요하게 바꾸지 않는다.

## 5. 변수와 문장 조립

- 문장 조각을 코드에서 이어 붙이지 않는다.
- 복수형, 조사, 성별 또는 순서가 달라질 수 있는 문장은 locale별 완전한 문장으로 둔다.
- placeholder는 `{servant_name}`, `{count}`, `{input_action}`처럼 의미 있는 이름을 쓴다.
- 모든 locale은 같은 placeholder 집합과 타입을 가져야 한다.
- 키 이름, 시간, 숫자는 locale formatter를 거친다.
- 사용자 지정 키는 실제 키 이름 대신 `InputAction` 표시 문자열로 치환한다.

## 6. 레이아웃과 글꼴

- 영어는 한국어 원문의 최대 140% 폭을 임시 예산으로 잡는다.
- 200% 텍스트 배율에서 대화, 선택지, 수첩, 일지, 저장 슬롯과 설정 화면을 검사한다.
- 대화창은 고정 높이 안에 문장을 억지로 축소하지 않고 확장 또는 페이지 분할한다.
- 필수 정보는 말줄임표 처리로 숨기지 않는다.
- 한국어 완성형·영문·숫자·기호와 접근성 표시에 필요한 글리프를 포함한 fallback chain을 지정한다.
- 폰트 라이선스, 버전, 원본 URL과 수정 여부를 에셋 manifest에 기록한다.

## 7. 제작 흐름

```text
기획 대사 확정
→ line_id 발급·context 작성
→ 한국어 원문 검토
→ 영어 번역
→ 말투·용어 검수
→ 게임 내 레이아웃 검수
→ 진행 동등성 검수
→ locked
```

- `locked` 이후 원문 의미를 바꾸면 `source_revision`을 올리고 번역 상태를 `translated` 이전으로 되돌린다.
- 번역자가 없는 임시 문자열도 빈 문자열로 두지 않고 `status=draft`, fallback locale을 명시한다.
- 번역 검수와 기능 QA는 분리한다. 자연스러운 문장이라도 조건·ID·placeholder가 다르면 실패다.

## 8. Pseudo-localization

영문 번역 완료 전부터 다음 가상 locale로 레이아웃을 검사한다.

- 길이 140% 확장.
- 앞뒤 경계 문자 추가.
- 숫자, placeholder와 키 표시 유지.
- 줄바꿈, 대화 로그, 200% 텍스트 배율 검사.

필수 화면에서 잘림, 겹침, 클릭 영역 이탈 또는 포커스 손실이 발생하면 해당 UI는 완료가 아니다.

## 9. QA 매트릭스

| 대상 | `ko-KR` | `en-US` | pseudo | 200% 텍스트 | 키보드 전용 |
| --- | --- | --- | --- | --- | --- |
| 필수 사건 | 전수 | 전수 | 핵심 | 전수 | 전수 |
| 선택 관계 | 전수 | 전수 | 표본+결산 | 핵심 | 핵심 |
| 퍼즐 힌트·실패 | 전수 | 전수 | 전수 | 전수 | 전수 |
| 저장·복구 | 전수 | 전수 | 핵심 | 전수 | 전수 |
| 엔딩·크레딧 | 전수 | 전수 | 전수 | 전수 | 전수 |

검증 항목:

- 누락·중복 `line_id` 0건.
- locale별 placeholder 집합 불일치 0건.
- 번역되지 않은 필수 문자열 0건.
- 언어 변경 전후 진행 checksum 동일.
- 대화 기록이 현재 locale로 재해석됨.
- 화면 밖 필수 텍스트와 포커스 불가 항목 0건.

## 10. 일정 게이트

| 게이트 | 잠그는 내용 |
| --- | --- |
| `VERTICAL_SLICE` | 데이터 형식, 폰트 후보, 캐릭터 말투 샘플 |
| `M2_DEMO_FEATURE_COMPLETE` | 데모의 모든 `line_id`와 UI 문자열 |
| `M2_DEMO_COMPLETE` | 한국어 원문 의미와 사건 순서 |
| `LOC_01_DEMO_LOCK` | 데모 한국어·영어, 용어집, 레이아웃 |
| `FULL_00_CONTENT_LOCK` | 본편 한국어·영어와 크레딧 |

정식명과 마라 1·2의 최종 이름은 데모 번역 원문 잠금 전에 결정해야 한다. 결정이 늦어지면 표시명만 치환 가능한 별도 토큰을 사용하고 대사 ID를 이름에 종속시키지 않는다.

## 11. 현재 생산 기준선

| 항목 | 현재 상태 | 다음 증거 |
| --- | --- | --- |
| canonical 문자열 파일 | NOT_CREATED | 추적 가능한 UTF-8 CSV 또는 Translation Resource |
| 발급된 runtime `line_id` | 0건 검증됨 | 중복 없는 registry 검사 결과 |
| 버티컬 슬라이스 원문 의뢰 | READY_FOR_ACCEPTANCE | [REQ-CNT-2026-0001](requests/REQ-CNT-2026-0001_버티컬슬라이스.md) 팀 수락·skeleton CSV |
| 한국어 원문 분량 | UNKNOWN | 사건별 문자열·단어 수 |
| 영어 번역 분량 | UNKNOWN | 번역 대상 단어 수와 상태 집계 |
| 폰트·fallback | CANDIDATE_NOT_LOCKED | 라이선스·글리프·200% capture |

Markdown에 있는 예시 대사 수를 실제 제작 완료량으로 세지 않는다. 먼저 `PROD_01_VERTICAL_SLICE` 범위의 UI, 대사, 독백, 수첩, 힌트, 시스템 오류를 전부 한 정본에 옮겨 다음 값을 계측한다.

`REQ-CNT-2026-0001`의 `content_item_id`와 `draft_id`는 제작·검토용 추적자이며 runtime `line_id`가 아니다. 한국어 의미와 상태 조건을 승인한 뒤에만 `TXT_*`, `DLG_*`, `UI_*`, `SYS_*`를 발급한다.

- 유형별 string 수와 한국어·영어 단어 수.
- 화자별 대사 수와 선택·관계·경계 단계 variant 수.
- placeholder, 최대 줄 수, 스포일러 등급 누락 수.
- 번역·말투 검수·200% 레이아웃에 걸린 실제 시간.
- 본편 사건 목록에서 아직 `line_id`가 없는 노드 수.

이 기준선이 없으면 `M2_DEMO_FEATURE_COMPLETE`의 문자열 동결과 번역 견적을 완료로 판정하지 않는다.
