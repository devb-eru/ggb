# REQ-CNT-YYYY-NNNN: 콘텐츠 기획 의뢰 제목

> 안내 문구를 지운 뒤 사용한다. 승인 전에는 `content_item_id`, 승인 뒤에는 별도 `line_id`를 사용한다.

## 1. 의뢰 정보

| 필드 | 값 |
| --- | --- |
| request_id | `REQ-CNT-YYYY-NNNN` |
| 상태 | `DRAFT` |
| 배치·우선순위 | `BATCH-*` · `P2` |
| 담당 팀장·검토자 | `UNASSIGNED` · `UNASSIGNED` |
| 목표 마일스톤 | `UNSCHEDULED` |
| 플랫폼 | Windows 10/11 64-bit PC |
| 참조 work_id | `미발급` |
| request revision | `1` |

## 2. 목적과 플레이어 경험

대사·상호작용·문서가 전달해야 할 사실, 감정과 숨겨야 할 사실을 쓴다.

## 3. 범위

### 포함

- dialogue / monologue / inspect / acquire / use / deny / hint / readable / notebook / system / caption.

### 제외

- 이번 의뢰에서 작성하지 않을 언어·사건·분기.

## 4. 콘텐츠 항목

| content_item_id | 유형 | source_event_id·location_id·object_id | trigger | 목표 분량 | 필수 정보·선택 일화 |
| --- | --- | --- | --- | --- | --- |
| `CNT-*` | dialogue / inspect / readable 등 | `*` | click / acquire / state change 등 |  |  |

## 5. 레코드 필드

모든 원문 행은 다음 필드를 가진다.

```text
draft_id,request_id,content_item_id,content_type,ko_KR,speaker_id,
source_event_id,location_id,object_id,trigger,condition,emotion,
hidden_intent,register,variables,max_lines,max_width_class,spoiler_tier,
state_reads,state_writes,repeat_policy,notes
```

## 6. 분기·상태 계약

- `state_reads`: 문구 선택에 사용해도 되는 상태.
- `state_writes`: 문구 또는 선택 완료가 쓰는 상태. 순수 조사문이면 `none`.
- `repeat_policy`: `once`, `first_repeat`, `per_loop`, `state_variant`, `always`.
- 조건이 달라도 필수 정보량과 퍼즐 정답은 달라지지 않는다.
- 플레이어의 엔딩 가치 판단을 대사가 대신 확정하지 않는다.

## 7. 문체·접근성

- 캐릭터 말투는 `docs/localization.md`의 register를 따른다.
- 심리와 감각을 우선하되 정답·필수 조작은 모호한 비유만으로 숨기지 않는다.
- 색·소리·방향 정보는 문양·명칭·상태 문구와 병행한다.
- 200% UI의 `max_lines`와 페이지 분할을 적는다.
- 선택지끼리 정보량과 도덕적 어조가 한쪽으로 기울지 않게 한다.

## 8. 납품

| 파일 | 요구 |
| --- | --- |
| CSV 원문 | UTF-8, 위 레코드 필드, 한국어 정본 후보 |
| branch script | 사건 순서·선택·조건을 읽을 수 있는 Markdown |
| readable 원문 | 제목·본문·발견 위치·필수/선택 정보·페이지 구분 |
| 집계 | 유형·화자·사건별 행 수, 한국어 어절 수, variant 수 |

## 9. 수락·완료 조건

### 팀 수락

- [ ] 담당자와 예상 공수가 기록됐다.
- [ ] 필수 사실, 선택 일화와 제외 범위에 합의했다.
- [ ] 미확정 이름·설정의 토큰 처리 방식이 기록됐다.

### 원문 완료

- [ ] 모든 항목에 trigger·조건·상태 읽기·쓰기가 있다.
- [ ] 첫 조사·반복·실패·성공 variant가 필요한 곳에 존재한다.
- [ ] 필수 정보는 색 제거·음량 0에서도 전달된다.
- [ ] 말투·스포일러·200% UI·placeholder 검토가 끝났다.
- [ ] 승인 행에 추적 가능한 `line_id` 발급 준비가 됐다.

## 10. 팀 회신·변경 이력

| 날짜 | 주체 | 내용 | 상태·revision |
| --- | --- | --- | --- |
| YYYY-MM-DD | 작성자 | 최초 작성 | DRAFT · r1 |
