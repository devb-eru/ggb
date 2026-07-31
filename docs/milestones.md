# GGB 마일스톤

## 1. 전체 일정

| ID | 마일스톤 | 상태 | 내부 목표일 | 완료 기준 요약 |
| --- | --- | --- | --- | --- |
| `M1_V04_PLANNING_BASELINE` | v0.4 기획 기준선 확정 | COMPLETE | 2026-07-23, 완료 2026-07-27 | PR #14 병합, `niik` 승인, PR #16에 `gatam` 승인 기록 |
| `OPS_01_COLLABORATION_BASELINE` | 협업 시스템 운영 기준선 | IN_PROGRESS | 2026-08-04 | GitHub Project, Discord 알림, 회의 안건과 운영 리허설 |
| `STEAM_01_ONBOARDING` | Steamworks 가입·기본 AppID | PLANNED | 2026-08-14 | 계약 주체, 은행·세금 정보, 수수료, AppID 완료 |
| `TECH_01_FOUNDATION` | Godot 기술 기반선 | PROVISIONAL | 2026-08-21 | production bootstrap, 상태·사건·입력·저장 최소 구조, Windows debug export |
| `PROD_01_VERTICAL_SLICE` | 20~30분 버티컬 슬라이스 | PROVISIONAL | 2026-09-18 | 첫 리셋→영구 정보→실패→숏컷→성공 경로와 접근성·복구 검사 |
| `CH1_01_ALPHA` | 프롤로그·1장 알파 | PROVISIONAL | 2026-10-09 | 필수 경로, 초기 저장 지점, 한국어 원문, 임시 에셋 목록 |
| `STEAM_02_STORE_PUBLIC` | 기본 게임 Coming Soon 공개 | PLANNED | 2026-10-30 | 한·영 상점과 심사 완료, 찜하기 시작 |
| `M2_DEMO_FEATURE_COMPLETE` | 데모 기능 완료 | PROVISIONAL | 2026-11-06 | 프롤로그~D4·D5 스팅어, 저장·입력·접근성 기능 범위 고정 |
| `M2_DEMO_COMPLETE` | 공개 데모 콘텐츠 락 | PROVISIONAL | 2026-11-20 | 선택된 시간안, `SAVE_D5_COMPLETE`, 공개 품질, manifest `unit_count` 가중 임시 리소스 20% 이하 |
| `STEAM_03_DEMO_PRIVATE_QA` | Steam 데모 비공개 QA | PLANNED | 2026-12-04 | 데모 AppID, depot, 설치·업데이트 검증 |
| `LOC_01_DEMO_LOCK` | 데모 한·영 현지화 락 | PROVISIONAL | 2026-12-18 | 번역·말투·placeholder·200% 레이아웃 QA |
| `M3_NEXT_FEST_REGISTRATION` | Next Fest 등록 완료 | PLANNED | 2027-01-08 | 공식 마감 2027-01-10 23:59 PST보다 이틀 앞서 완료 |
| `FULL_00_CONTENT_COMPLETE` | 전편 콘텐츠 완료 | PROVISIONAL | 2027-01-15 | 프롤로그~엔딩 필수·선택 경로 연결, 알려진 차단 결함 0건 |
| `M4_PRESS_PREVIEW_SUBMISSION` | 프레스 프리뷰 심사 제출 | PLANNED | 2027-01-22 | 공식 권장일 2027-01-25보다 앞서 제출 |
| `FULL_00_CONTENT_LOCK` | 전편 콘텐츠·현지화 락 | PROVISIONAL | 2027-01-29 | 신규 범위 종료, 한·영·에셋·크레딧 잠금 |
| `M5_NEXT_FEST_READY` | 행사 필수 항목 심사 제출 | PLANNED | 2027-02-05 | 공식 마감 2027-02-08보다 앞서 제출 |
| `FULL_01_RELEASE_CANDIDATE` | 출시 후보 빌드 | PLANNED | 2027-02-12 | 전체 범위, 한·영, 저장 승계, Valve 심사 여유 확보 |
| `M6_NEXT_FEST_LIVE` | Steam Next Fest 참가 | PLANNED | 2027-02-22 10:00 PST | 출시 후보 수준의 품질로 2장 데모 공개 |
| `FULL_02_RELEASE` | 정식 버전 1.0 출시 | PLANNED | 가장 빠르면 2027-03-05 03:00 KST | 행사 종료 후 72시간 이상 안정화하고 `beru` 승인 |

Steam 행사 시각과 제출일은 [Steamworks February 2027 Next Fest 안내](https://partner.steamgames.com/doc/marketing/upcoming_events/nextfest/feb_2027)를 기준으로 한다. 공식 일정은 2026년 12월부터 주 1회 재확인한다. `PROVISIONAL` 날짜는 구현 약속이 아니라 계획 가설이며 `PROD_01_VERTICAL_SLICE` 실측 뒤 5영업일 안에 다시 산정한다.

## 2. M1 기획 기준선

### 운영 기준

- M1 당시의 가용시간 가정은 완료 기록에만 남기고 이후 제작 일정에는 사용하지 않는다. 현행 용량 기준은 [프로젝트 역할](project_roles.md#2-가용시간과-계획-용량)을 따른다.
- 2026-07-23은 1차 내부 기준일이다. 2026-07-22 점검에서 `P1`이 하나라도 남으면 새 목표일은 2026-07-30으로 자동 변경한다.
- 열린 이슈의 기본 책임자는 기술·데이터 이슈 `beru`, 서사·문서 정합성 이슈 `gatam`이다.
- `DEFERRED`는 일괄 금지하지 않고 [프로젝트 운영 기준](project_operations.md#82-deferred-운영)에 따라 유동적으로 사용한다.

### 완료 조건

- [x] 열린 `GGB-CNF/ERR`가 `VERIFIED`, 근거 있는 `DEFERRED`, 또는 근거 있는 `WONT_FIX`다.
- [x] `00~18` 기획 문서와 v0.4 README가 동기화되어 있다.
- [x] 이벤트 ID, 상태 변수, 위치 ID, 관계 결산 규칙이 문서 간 일치한다.
- [x] `game/data`로 옮길 데이터 계약과 변경 범위가 확정되어 있다.
- [x] 개발을 막지 않는 후속 기획은 별도 작업으로 분리되어 있다.

객관적 완료 조건과 정적 회귀 검사는 모두 통과했다. 세부 근거와 사람 검토 역할은 [M1 검토 기록](milestone_reviews/M1_V04_PLANNING_BASELINE.md)에 둔다. PR #14 병합, `niik` 승인과 PR #16의 `gatam` 승인 기록을 확인하고 2026-07-27에 `COMPLETE`로 전환했다.

목표일을 넘겨도 범위를 숨기거나 검증 없이 완료 처리하지 않는다. 연장 시 남은 `P1`, 책임자, 예상 완료일과 영향 범위를 함께 기록한다.

## 3. 제작 게이트

[GGB-DEC-2026-0010](decisions/GGB-DEC-2026-0010_제작_마일스톤_재편.md)에 따라 2026-11-20의 이중 완료선을 폐기한다. 해당 날짜는 `M2_DEMO_COMPLETE` 하나만 둔다. 전편은 버티컬 슬라이스의 실제 속도와 팀 용량을 반영해 별도 게이트로 진행한다.

### 3.1 기술 기반선

- 제품 ID와 production bootstrap scene이 정해져 있다.
- 입력 action, 포커스, 1280x720 레이아웃 뼈대가 있다.
- `GameState`, `EventManager`, `StateWriter`, `ResetCoordinator`, `SaveManager`의 최소 인터페이스가 연결된다.
- 한국어·영어 문자열 소스와 대화 기록 형식이 로드된다.
- Windows debug export를 재현할 수 있다.

### 3.2 버티컬 슬라이스

공개 데모 범위를 그대로 만들지 않고 다음 20~30분 경로로 가장 위험한 가정을 검사한다.

```text
같은 아침의 짧은 일과
→ 수첩 표시
→ NORMAL_RESET
→ 표시 유지 확인
→ B3형 비가역 조작 실패
→ 실패를 기억하는 사용인 반응
→ 수면과 숏컷
→ 검증 부분을 이용한 성공
→ S2 표면 누수 한 장면
```

합격 조건:

- 신규 플레이어가 수면 리셋과 디스크 저장을 구분한다.
- 실패 뒤 같은 노동을 그대로 반복한다고 느끼지 않는다.
- 성공자의 80% 이상이 정답 이유를 설명한다.
- 사용인이 기억하면서도 즉시 차단하지 않는 이유를 이해한다.
- 강제 종료 5개 지점에서 보상 중복 없이 재개한다.
- 마우스 전용, 키보드 전용, 색 제거·음량 0·모션 감소 경로가 모두 통과한다.

### 3.3 재산정 게이트

`PROD_01_VERTICAL_SLICE` 완료 뒤 다음 값을 기록한다.

| 값 | 용도 |
| --- | --- |
| 역할별 실제 시간 | 남은 사건·방·UI의 공수 추정 |
| 임시/최종 에셋 수 | 에셋 BOM과 제작 속도 계산 |
| 결함 수정 시간 | 일정 버퍼 재산정 |
| 플레이 중앙값·이탈 지점 | 데모 compact/extended 선택 |
| 렌더러별 성능 | 최소 사양과 효과 범위 결정 |

예상 공수가 가용 용량을 20% 이상 초과하면 11월 이후 게이트를 이동한다. 주말·초과 근무로 차이를 메운 것으로 계산하지 않는다.

## 4. Next Fest와 출시

- 행사 시점에는 출시판과 거의 동일한 기본 게임 완성본을 확보한다.
- Steam 행사 참여 요건상 공개 데모 AppID는 유지한다.
- 행사 데모는 출시판 수준의 품질을 사용하되 2장까지만 공개한다.
- 행사 종료 후 최소 72시간 동안 크래시·저장 손상·진행 불가·상점 설정을 점검한다.
- 안정화 게이트를 통과하면 앞서 해보기가 아닌 정식 버전 1.0으로 출시한다.
- `FULL_01_RELEASE_CANDIDATE`를 통과하지 못하면 가장 빠른 출시 목표를 자동 약속으로 사용하지 않고 출시일을 연기한다.
