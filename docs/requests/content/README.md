# GGB 전체 콘텐츠 원문 의뢰 부속 명세

## 1. 역할

이 폴더는 게임 전체의 한국어 원문을 에피소드별 제작 패키지로 나눈다. 부모 실행 의뢰는 `REQ-CNT-2026-0001~0003`이며, 에피소드 파일은 독립 수락 요청이 아니라 부모 의뢰의 납품 단위다.

| package_id | 문서 | 구간 | 부모 의뢰 |
| --- | --- | --- | --- |
| `CNT-EP00` | [프롤로그](EP00_프롤로그.md) | P1~P6 | `REQ-CNT-2026-0002` |
| `CNT-EP01` | [반복과 시계망](EP01_반복과시계망.md) | A1~J2 | `REQ-CNT-2026-0002` |
| `CNT-EP02` | [검은 거울](EP02_검은거울.md) | C0~J3 | `REQ-CNT-2026-0002` |
| `CNT-EP03` | [지하와 파열](EP03_지하와파열.md) | D0~D5 | `REQ-CNT-2026-0002` |
| `CNT-EP04` | [다른 아침](EP04_다른아침.md) | D6~E2_INTRO | `REQ-CNT-2026-0003` |
| `CNT-EP05` | [다섯 관계와 마지막 저녁](EP05_다섯관계와마지막저녁.md) | E_HUB~E6 | `REQ-CNT-2026-0003` |
| `CNT-EP06` | [코어와 마지막 기록](EP06_코어와마지막기록.md) | F0~J5 | `REQ-CNT-2026-0003` |
| `CNT-EP07` | [대면과 최종 선택](EP07_대면과최종선택.md) | F2~EDC | `REQ-CNT-2026-0003` |
| `CNT-EP08` | [현실 기상](EP08_현실기상.md) | ED_REALITY | `REQ-CNT-2026-0003` |
| `CNT-EP09` | [안정화 잔류](EP09_안정화잔류.md) | ED_STAY | `REQ-CNT-2026-0003` |

공통 schema·문체·분기·검수는 [공통 원문 계약](00_공통원문계약.md)을 따른다.
63개 정본 오브젝트의 원문 소유 에피소드와 필수 상태는 [정본 오브젝트 원문 전수 매핑](01_정본오브젝트원문_전수매핑.md)에서 확인한다.
사용인 짧은 반응과 엔딩 개인 반응은 [사용인 반응 전수 매핑](02_사용인반응_전수매핑.md), 종이·일지·기록은 [문서·수첩 전수 목록](03_문서수첩_전수목록.md), 메타 UI·시스템 문구는 [공통 시스템·UI 원문](04_공통시스템_UI원문.md)에서 교차 확인한다.
EP01 Google Sheets의 초기 보완 검토는 [EP01 스크립트 Sheet 보완 검토](EP01_스크립트시트_보완검토.md)에서 확인한다.
EP02 Google Sheets의 위치, EP01 대비 구조 변경과 검증 결과는 [EP02 검은 거울 스크립트 Sheet 인계](EP02_검은거울_스크립트시트_인계.md)에서 확인한다.
EP03 Google Sheets의 위치, D1 HARD FAILURE와 D5 build 인계 계약은 [EP03 지하와 파열 스크립트 Sheet 인계](EP03_지하와파열_스크립트시트_인계.md)에서 확인한다.
EP04 Google Sheets의 위치, `BROKEN_RESET_ONCE`, E1 3-of-4와 E2 관계 허브 인계 계약은 [EP04 다른 아침 스크립트 Sheet 인계](EP04_다른아침_스크립트시트_인계.md)에서 확인한다.
두 Sheet의 schema v3 전환 결과와 항목별 해결 증거는 [EP01·EP02 스크립트 Sheet 2차 검토](EP01_EP02_스크립트시트_2차검토.md)를 정본으로 삼는다.
기계 판독 열 계약은 [CNT Sheet schema v3](schemas/CNT_sheet_schema_v3.json), 최신 기술 검증 결과는 [LINT-20260901-R3](lint/LINT-20260901-R3.json)에서 확인한다.
재검증 시 각 정본 탭을 CSV로 내보낸 뒤 `scripts/content_sheet_contract_lint.py`에 Runtime·Route·Predicate·Effect, 공용 Vocab, 상태 Registry와 이전 Runtime 기준본을 전달한다.

## 2. 전수성 기준

각 실행 사건은 아래 중 하나 이상에 연결돼야 한다.

- 주 대사·독백.
- 클릭·획득·배치·사용·거부·반복·상태 변화 상호작용 문구.
- 문서·종이·일지·수첩·기록 단말 원문.
- 퍼즐 입력·무효·힌트·재시도·HARD FAILURE·숏컷·성공 피드백.
- 사용인 짧은 반응·핵심 관계·결산·엔딩 후속.
- 시스템·저장·리셋·접근성·감각 자막.
- 의도적으로 무문구인 순간은 `silent_intent`와 연출 이유를 기록.

## 3. 언어 범위

- 이번 의뢰는 `ko-KR` 정본 후보 작성과 승인 준비까지다.
- 승인 뒤 `line_id`를 발급하고 `en-US`·pseudo-localization은 별도 현지화 단계에서 진행한다.
- 주인공 이름·정확한 나이, 프로젝트 정식명, 마라 1/2 정식명은 확정하지 않는다. 표시 token을 사용한다.
- 음성 녹음은 범위에 없으므로 말줄임·호흡·말투는 화면 텍스트와 초상 연기로 전달한다.

## 4. 납품 구조

```text
content/
├─ ko_KR_master.csv
├─ branch_scripts/EP00~EP09.md
├─ readables/EP00~EP09.md
├─ captions/captions_ko_KR.csv
├─ notebook/notebook_entries_ko_KR.csv
└─ metrics/content_metrics.md
```
