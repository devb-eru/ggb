# GGB 마일스톤

## 1. 전체 일정

| ID | 마일스톤 | 상태 | 내부 목표일 | 완료 기준 요약 |
| --- | --- | --- | --- | --- |
| `M1_V04_PLANNING_BASELINE` | v0.4 기획 기준선 확정 | IN_PROGRESS | 2026-07-23, 조건부 2026-07-30 | 7월 22일에 `P1`이 남아 있으면 자동 연장 |
| `STEAM_01_ONBOARDING` | Steamworks 가입·기본 AppID | PLANNED | 2026-08-14 | 계약 주체, 은행·세금 정보, 수수료, AppID 완료 |
| `STEAM_02_STORE_PUBLIC` | 기본 게임 Coming Soon 공개 | PLANNED | 2026-10-30 | 한·영 상점과 심사 완료, 찜하기 시작 |
| `M2_DEMO_COMPLETE` | 2장 공개 데모 완성 | PLANNED | 2026-11-20 | 2~3.5시간, 공개 품질, 임시 리소스 20% 이하 |
| `FULL_00_CONTENT_COMPLETE` | 완성본 콘텐츠 완료 | PLANNED | 2026-11-20 | 프롤로그~4장·엔딩 연결, 필수 3~5시간·전체 6시간 이상 |
| `STEAM_03_DEMO_PRIVATE_QA` | Steam 데모 비공개 QA | PLANNED | 2026-12-04 | 데모 AppID, depot, 설치·업데이트 검증 |
| `M3_NEXT_FEST_REGISTRATION` | Next Fest 등록 완료 | PLANNED | 2027-01-08 | 공식 마감 2027-01-10 23:59 PST보다 이틀 앞서 완료 |
| `M4_PRESS_PREVIEW_SUBMISSION` | 프레스 프리뷰 심사 제출 | PLANNED | 2027-01-22 | 공식 권장일 2027-01-25보다 앞서 제출 |
| `M5_NEXT_FEST_READY` | 행사 필수 항목 심사 제출 | PLANNED | 2027-02-05 | 공식 마감 2027-02-08보다 앞서 제출 |
| `FULL_01_RELEASE_CANDIDATE` | 출시 후보 빌드 | PLANNED | 2027-02-12 | 전체 범위, 한·영, 저장 승계, Valve 심사 여유 확보 |
| `M6_NEXT_FEST_LIVE` | Steam Next Fest 참가 | PLANNED | 2027-02-22 10:00 PST | 출시 후보 수준의 품질로 2장 데모 공개 |
| `FULL_02_RELEASE` | 정식 버전 1.0 출시 | PLANNED | 가장 빠르면 2027-03-05 03:00 KST | 행사 종료 후 72시간 이상 안정화하고 `beru` 승인 |

Steam 행사 시각과 제출일은 [Steamworks February 2027 Next Fest 안내](https://partner.steamgames.com/doc/marketing/upcoming_events/nextfest/feb_2027)를 기준으로 한다. 공식 일정은 2026년 12월부터 주 1회 재확인한다.

## 2. M1 기획 기준선

### 운영 기준

- 모든 담당자는 주 7일, 하루 8시간 이상의 개인 공통 가용시간을 가지며, 기획·개발·QA 등 겸임 역할 사이에서 당일 우선순위에 따라 배분한다. 기본 계획 부하는 주간 가용시간의 80% 이내로 둔다.
- 2026-07-23은 1차 내부 기준일이다. 2026-07-22 점검에서 `P1`이 하나라도 남으면 새 목표일은 2026-07-30으로 자동 변경한다.
- 열린 이슈의 기본 책임자는 기술·데이터 이슈 `beru`, 서사·문서 정합성 이슈 `gatam`이다.
- `DEFERRED`는 일괄 금지하지 않고 [프로젝트 운영 기준](project_operations.md#82-deferred-운영)에 따라 유동적으로 사용한다.

### 완료 조건

- [ ] 열린 `GGB-CNF/ERR`가 `VERIFIED`, 근거 있는 `DEFERRED`, 또는 근거 있는 `WONT_FIX`다.
- [ ] `00~18` 기획 문서와 v0.4 README가 동기화되어 있다.
- [ ] 이벤트 ID, 상태 변수, 위치 ID, 관계 결산 규칙이 문서 간 일치한다.
- [ ] `game/data`로 옮길 데이터 계약과 변경 범위가 확정되어 있다.
- [ ] 개발을 막지 않는 후속 기획은 별도 작업으로 분리되어 있다.

목표일을 넘겨도 범위를 숨기거나 검증 없이 완료 처리하지 않는다. 연장 시 남은 `P1`, 책임자, 예상 완료일과 영향 범위를 함께 기록한다.

## 3. 11월 20일 이중 기준선

같은 날짜에 서로 다른 결과물 두 개를 고정한다.

- `M2_DEMO_COMPLETE`: 2장까지 외부 공개 가능한 데모.
- `FULL_00_CONTENT_COMPLETE`: 프롤로그~4장·엔딩까지 내부에서 끝까지 가능한 완성본 콘텐츠.

두 범위가 같은 작업으로 오인되지 않도록 빌드 채널, 완료 체크리스트, QA 결과를 분리한다. 데모는 [공개 데모 정의](demo_definition.md), 완성본은 [완성본 정의](full_game_definition.md)를 따른다.

## 4. Next Fest와 출시

- 행사 시점에는 출시판과 거의 동일한 기본 게임 완성본을 확보한다.
- Steam 행사 참여 요건상 공개 데모 AppID는 유지한다.
- 행사 데모는 출시판 수준의 품질을 사용하되 2장까지만 공개한다.
- 행사 종료 후 최소 72시간 동안 크래시·저장 손상·진행 불가·상점 설정을 점검한다.
- 안정화 게이트를 통과하면 앞서 해보기가 아닌 정식 버전 1.0으로 출시한다.
