# 수첩 생산자 재감사와 재선택 안내 분리

기준: 2026-10-04, develop `5830d41`. 전체 계획은 `IN_PROGRESS`이며 이 보고서는 NP01~NP22 전체 인수 완료 선언이 아니다.

## 1. 확인한 결함과 수정

### NP22 재선택 알림이 이야기 기록을 생성함

`basement_controller.gd`의 `_create_reselect`, `_resume_reselect`는 생성 실패·로드 실패·복사본 진입 안내를 `_show_dialogue`로 표시했다. 이 경로는 실제 본편 대사 writer와 재개 커서를 사용하므로, `EXCLUDED_UI`로 정한 관리 안내가 신규 `unmapped` 기록이 되고 복사본의 대사 커서까지 바꿀 수 있었다.

세 알림은 `_show_reselect_notice`의 비서사 모달로 통일한다. 원래 한영 안내 문구와 명시적 닫기를 유지하고, 기록·선택·커서 저장을 하지 않는다. 원본 엔딩·F3 복사본 생성 규칙·갤러리 원문은 바꾸지 않는다. 자료를 새로 획득한 것처럼 보이게 하거나 과거 미분류 기록을 삭제하지 않는다.

검사는 두 언어의 세 알림에 대해 실제 모달 표시·닫기, 단일 키보드 포커스 가능한 버튼, 전체 snapshot과 슬롯 바이트 불변을 확인한다. F3 캡처가 없는 슬롯에서 실제 생성 실패 경로도 실행한다. 기존 지하 종합 회귀는 실제 복사본 진입 안내를 닫은 뒤 새로 공개되는 authored 문서 표면 기록만 허용하고, 그 외 게임 상태·대사 커서는 불변인지 검사하도록 갱신한다.

### NP20 저장 실패 시험이 관찰 이전에서 중단됨

기존 `notebook_content_smoke.gd`는 모든 저장을 거부한 뒤 도움 요청 버튼을 눌렀다. 현재 보조창은 요청·닫기 커서 저장 성공 후 힌트를 보여 주므로, 문장이 없는 상태에서 첫 문장 토큰에 접근해 실행 오류가 났다.

실패 주입은 대사 관찰 저장에 한정하고 보조창 저장은 실제 SaveManager로 위임한다. 메뉴만 열어서는 공개 기록을 만들지 않는 검사와 퍼즐·관계·일지·엔딩 불변 비교를 유지한다. 비교에서 제외하는 것은 명시적인 `NOTEBOOK_PRESENTATION` 편의 커서뿐이며 기록 내용은 제외하지 않는다. 표시 도달을 먼저 단언해 실패를 배열 접근 오류로 가리지 않는다.

### NP04 집계에 NP21 단서 표시가 섞임

기존 `notebook_chapter_one_smoke.gd`는 NP05·NP06 외 모든 관찰을 NP04로 간주했다. 화면 단서 기록 NP21이 추가된 현재 경로에서 잘못된 출처 오류와 대사 ID 과다 집계가 발생했다.

모든 항목의 authored 분류와 1장 출처, 허용 생산자를 먼저 검사하고 NP04만 해당 대사의 실행 커버리지에 집계한다. NP21을 미분류로 허용하거나 대사 검사를 삭제하지 않는다. NP21 전체 표시 검사는 별도 chapter-surfaces 검사 책임이다.

## 2. 정적 인벤토리

26개 등록 카탈로그에 고유 콘텐츠 ID 1,683개, 의미 버전별 정의 1,686개, 정의별 segment 합계 2,478개가 있다. NP06의 3개 추가 버전은 새 ID 수로 중복 집계하지 않는다. 이 수는 작성량이며 실제 모든 분기 실행 수가 아니다.

| 생산자 | 고유 ID | 버전별 정의 |
| --- | ---: | ---: |
| NP01 / NP02 / NP03 | 79 / 14 / 9 | 79 / 14 / 9 |
| NP04 / NP05 / NP06 | 57 / 123 / 26 | 57 / 123 / 29 |
| NP07 / NP08 / NP09 | 100 / 73 / 117 | 100 / 73 / 117 |
| NP10 / NP11 / NP12 | 27 / 45 / 31 | 27 / 45 / 31 |
| NP13 / NP14 / NP15 | 45 / 103 / 178 | 45 / 103 / 178 |
| NP16 / NP17 / NP18 | 122 / 66 / 153 | 122 / 66 / 153 |
| NP19 / NP20 / NP21 | 118 / 60 / 137 | 118 / 60 / 137 |
| NP22 | 0 | 0, 새 본편 관찰을 생산하지 않는 소비·관리 경로 |

모든 컨트롤러의 직접 `_show_modal`, `_show_recorded_choice`, `_show_dialogue` 호출과 관계/결산/잔류 wrapper를 재대조했다. 관계 wrapper의 일반 모달은 구형 모드 분기이며 v2에서는 명시적 원고가 있는 기록 모달로 연결된다. 메뉴·설정·구형 수첩·갤러리·재선택 확인은 비서사 소비/관리 경로다. 힌트 요청 및 양 비교표는 관찰을 생산하지 않는 utility이며 실제 힌트 본문은 NP20이 기록한다. 이번에 찾아 수정한 예외가 위 재선택 안내 세 문장이다.

이 호출 대조만으로 일반 피드백의 모든 동적 분기나 직접 상태 쓰기를 증명하지 않는다. 신규 raw 예외·최초 공개·반복 분기는 실행 증거와 함께 계속 대조해야 한다.

## 3. 실행 근거

기존 기준 패키지의 생산자별 24개 검사를 격리 APPDATA/LOCALAPPDATA, 빈 실행 디렉터리, Windows Godot 4.7.2 headless에서 순차 실행한다. 각 프로세스의 종료 코드, PASS 표식, 스크립트/파싱/컴파일 오류를 별도로 확인한다. 중간 오류가 있는 검사는 통과로 세지 않는다.

기준 PCK SHA-256: `957C0DE0CC2B8C11899C618C75C870FBDC83A99737348428BD81167145A43CDE`.
로그 위치: `%TEMP%/ggb-producer-audit-20261004/`.

### 기준 패키지 전체 생산자 검사

명령은 `godot --headless --path <empty> --main-pack <pck> -- --notebook-<검사명>-smoke --ggb-dev-notebook-v2`다. 24개 중 14개 PASS, 8개 단언 실패, 1개 스크립트 오류, 1개 실행 제한 종료였다. 종료한 검사만 다음 검사로 넘어갔다. 이 수는 테스트 묶음 수이며 생산자 그룹 완료 수가 아니다.

| 검사명 | 기준 패키지 결과 | 실행 시간(초) |
| --- | --- | ---: |
| `content` | 실행 오류 | 160.6 |
| `prologue` | PASS | 359.9 |
| `knowledge` | PASS | 15.2 |
| `chapter-one` | 단언 실패 | 204.3 |
| `chapter-one-notes` | PASS | 44.6 |
| `modals` | PASS | 254.4 |
| `mirror` | 단언 실패 | 143.1 |
| `basement` | 단언 실패 | 139.6 |
| `fracture` | PASS | 231.2 |
| `fracture-surfaces` | PASS | 53.6 |
| `mara1` | 단언 실패 | 71.9 |
| `iris` | 단언 실패 | 213.8 |
| `luca` | 단언 실패 | 75.9 |
| `authority-archive` | 실행 제한 종료 | 900.4 |
| `settlement` | PASS | 281.1 |
| `journal-four` | PASS | 12.0 |
| `journal-four-display` | PASS | 287.5 |
| `core` | PASS | 197.0 |
| `final` | PASS | 174.6 |
| `reality` | 단언 실패 | 311.5 |
| `stay` | PASS | 279.3 |
| `puzzle-surfaces` | 단언 실패 | 33.3 |
| `chapter-surfaces` | PASS | 43.7 |
| `prologue-surfaces` | PASS | 420.4 |

`content`는 첫 문장 배열 접근 오류를 감지해 해당 검증 프로세스만 종료했다. `authority-archive`는 900초 실행 제한으로 종료했으며 완료 표식이 없다. 이는 관찰 응답의 시간 초과나 통과가 아니다. `actual surface capture`, `last choice deferral never completes the relation` 단언도 그 전에 출력됐다. 다음 재검증은 시나리오별 진행 표식과 충분한 실행 제한을 사용해야 한다.

### 수정 패키지 집중 재검증

PCK SHA-256: `220565920B4E1C2AEF6E301E5EDF598A106FDF742CCFF5BEF449BC3A136775DF`. 로그: `%TEMP%/ggb-producer-final2-20261004/`. import 39.8초, export 11.0초. 기준 패키지 전체 검사와 수정 후 검사를 혼합해 전체 PASS로 표기하지 않는다.

| 검사 | 수정 후 결과 | 시간(초) |
| --- | --- | ---: |
| 힌트 `content` | PASS, 60개 ID / 한영 120조합 | 148.4 |
| 1장 대사 `chapter-one` | PASS, 57개 ID / 한영 114조합 / segment·언어 190조합 | 188.5 |
| 통합 조회 `query` | PASS, 갤러리 182개 및 조회·검색·자료 비교·레거시 등 하위 검사 포함 | 105.3 |
| 지하 전체 v2 | 종료, 14,011개 검사 중 이전 안내 닫기 판정 4건 실패 | 감시 교체로 최종 소요 시간 미보존 |

전체 v2 실행은 완료됐으며 실패 목록은 `Closing replay notice changes no story record or presentation cursor` 네 건뿐이었다. 해당 실행 패키지는 아래 판정 보완 이전 것이므로 실패를 통과로 소급 변경하지 않는다. 동일 패키지의 기존 모드 검사는 실패 후 연속 실행이 중단되어 실행하지 않았고, 아래 최종 패키지에서 별도로 전체 실행했다.

그 뒤 실제 복사본 진입 검사에서 안내를 닫을 때 새로 보이는 목적지 표면이 정당하게 기록되는 경우를 확인했다. 안내 자체의 무기록 검사는 갤러리 검사에서 전체 snapshot·슬롯 바이트로 유지한다. 복사본 전환 검사는 신규 항목이 authored 문서 표면인지 확인하고, 그 공개 기록을 제외한 전체 게임 상태와 대사 커서는 그대로인지 비교한다. 공개 자료의 정상 기록을 관리 알림 오염으로 오인하지 않는다.

이 시험 판정 보완과 크레딧 집중 실행 옵션만 추가한 최종 PCK는 `7275F67897D15281B7B734F72B9DC302BEE5E636F9666D5BC9CAC82D373C2CB6`이다. 위 수정 패키지와 게임 제품 코드는 같고 테스트만 보완했다. 로그는 `%TEMP%/ggb-producer-credits-20261004/`이며 import 36.9초, export 9.9초다.

| 최종 시험 패키지 검사 | 결과 | 시간(초) |
| --- | --- | ---: |
| 통합 조회 `--notebook-query-smoke --ggb-dev-notebook-v2` | PASS, 갤러리 182개 포함 | 107.6 |
| 크레딧·갤러리·실제 복사본 집중 v2 | PASS, 250개 | 17.9 |
| 동일 집중 기존 모드 | PASS, 240개 | 13.4 |
| 지하 전체 기존 모드 | PASS, 13,913개 | 327.0 |
| 지하 전체 v2 | NOT_RUN, 최종 판정 보완 후 전체 재실행 필요 | - |

집중 명령은 `--basement-session-smoke --basement-credits-regression-only`이며 v2에만 `--ggb-dev-notebook-v2`를 붙인다. 두 엔딩의 정상 checkpoint와 실제 F3 캡처를 만들고 같은 종합 회귀의 크레딧 함수를 실행한다. 출력도 `NOT FULL REGRESSION`으로 표시한다. 이 250/240개 집중 PASS를 전체 v2 회귀 PASS로 대체하지 않는다.

PASS 판정에는 종료 코드 0과 해당 PASS 표식을 모두 요구한다. 환경의 `Failed to read the root certificate store`는 통과 검사에도 공통으로 남으며 해결한 것으로 계산하지 않는다. 위에 적은 단언·스크립트 오류·실행 제한 종료를 이 환경 메시지와 섞어 무시하지 않는다.

첫 수정 패키지에서 힌트의 JSON 숫자 왕복 비교와 초기 화면 예약 기록이 실패 주입에 섞이는 문제를 추가로 확인했다. 실제 화면 단서 저장을 먼저 완료하고 재로드 비교는 전체 snapshot의 `same_persisted_value`로 검증했다. 원고·UID·보호 기록과 게임 상태를 비교에서 빼지 않았다.

기존 지하 전체 v2 검증의 약 4,086초 실행 이력을 확인하여 수정 패키지의 감시 제한을 7,200초로 늘렸다. 실행 중인 Godot PID를 유지하고 감시 프로세스만 교체했으며 처음부터 재시작하지 않았다. 위 실행 시간은 검증 비용이지 입력 p95 측정값이 아니다.

## 4. 발견 사항과 다음 조치

아래 ID는 이 보고서의 내부 추적 ID다. 공식 GGB 이슈 번호나 전체 해결 판정을 대신하지 않는다.

| ID | 위치 / 상태 | 확인한 내용 | 다음 조치 |
| --- | --- | --- | --- |
| PA01 | `basement_controller.gd::_create_reselect/_resume_reselect` / 수정 | 비서사 관리 알림이 대화 writer·커서로 들어감 | `_show_reselect_notice`로 분리, 전체 상태·슬롯 바이트 및 실제 복사본 진입 회귀로 검증 |
| PA02 | `notebook_content_smoke.gd::_validate_failed_write/_validate_live_hints` / 수정·집중 PASS | 보조창 저장 실패 때문에 표시 전 배열 접근, 현재 커서와 JSON 숫자 비교 계약 미반영 | 관찰 저장만 실패 주입, 초기 화면 저장 선행, 게임 상태·기록 불변 및 전체 재로드 비교 유지 |
| PA03 | `notebook_chapter_one_smoke.gd::_collect` / 수정·집중 PASS | NP21 표시를 NP04 대사로 집계 | 모든 항목의 authored·장·허용 생산자 검사 후 NP04만 집계 |
| PA04 | `notebook_mirror_smoke.gd`, `notebook_basement_smoke.gd` / 미해결 | 생산자 전체 ID 목록에 후속 `NB_PUZZLE_*`가 포함되지만 원래 경로 검사는 모든 표시 변형을 실행하지 않음 | catalog·variant·segment별 소유 검사를 명시하고 puzzle-surfaces와 합집합 대조. 필수 ID를 단순 제거해 통과시키지 않음 |
| PA05 | `notebook_basement_smoke.gd::_modals/_failures`, `notebook_mara1_smoke.gd`, `notebook_iris_smoke.gd`, `notebook_luca_smoke.gd` / 부분 해결 | 취소·미룸 뒤 전체 또는 loop 상태 불변 단언 실패. 세 관계 검사는 완료된 표시 커서만 다름을 확인하고 교정·한영 PASS(6절) | 지하 확인창은 미해결. 같은 원인이라고 추정해 종결하지 말고 해당 경로의 전체 차이를 확인. 기계 입력·관계 완료·연구 기록·지식 불변 유지 |
| PA06 | `notebook_authority_archive_smoke.gd` / 미해결·실행 불완전 | 실제 표면 기록 및 미룸 단언 실패, 900초 안에 종료하지 않음 | 인물·시나리오·언어별 진행/실패 로그와 표면 기록 반환 원인 확인, 충분한 시간의 전체 재실행. 시간만 늘린 것으로 오류 해결을 주장하지 않음 |
| PA07 | `notebook_reality_smoke.gd::_field`, `notebook_puzzle_surfaces_smoke.gd` / 수정·한영 PASS | Esc 및 수량 보조창 닫기 뒤 완료 커서만 변화함을 실제 경로에서 확인. 진행·읽음·대화·지식 변경은 없음(6절) | 유효한 완료 커서만 비교에서 분리하며 나머지 snapshot 전체를 비교. 명시적 읽기 확인 없이 ledger가 늘지 않는 조건 유지 |
| PA08 | `basement_controller.gd::_resume_reselect`, `presentation_view_tracker.gd::_process` / 정적 추가 발견·실행 미검증 | 기존 컨트롤러에서 슬롯·세션을 교체하지만 일반 초기화의 `_restore_presentation`을 호출하지 않으며 tracker는 생성 당시 scope가 바뀌면 쓰기를 거부함 | 진행 중인 복사본을 다시 여는 fixture로 대사/선택/utility 재개와 새 읽기 위치 저장 검증. 승인된 슬롯 전환에서 새 tracker와 표시 복원을 연결하되 이전 콜백의 쓰기 거부 유지 |

첫 수정 시 PA04~PA08은 완료 수치에 포함하지 않았다. 후속 6절에서 PA05 일부와 PA07을 검증했으며, 나머지는 미해결이다. 특히 PA08의 소스 근거를 실제 재현 결과로 바꾸어 쓰지 않는다.

## 5. 잔여 인수

- 생산자별 PASS는 해당 테스트가 열거한 ID·variant·segment 범위의 증거다. 테스트가 열거하지 않은 필수/반복 분기까지 자동으로 완료 처리하지 않는다.
- 최종 판정 보완 패키지의 지하 전체 v2 회귀를 다시 실행해야 한다. 이전 전체 실행의 네 실패와 최신 집중 PASS를 합쳐 전체 PASS로 보고하지 않는다.
- 신규 미매핑 0, 필수 분기 `NOT_COVERED` 0, 공개 전 제목/본문/검색어/내부 ID 누출 0의 전편 감사가 필요하다.
- Windows 실제 마우스·키보드·IME·시각 검수와 고정 fixture cold/warm p95·RAM 측정은 headless 검사와 별개다.
- 기존 사용자 변경 씬·번역 리소스·플러그인은 패키지 검증 및 이번 수정에 포함하지 않았다. 개발 rollout은 기본 비활성을 유지한다.

관련 기준: [구현 계획](../ideas/md/v04/issues/validation/notebook_history_review_plan.md), [생산자 연결 현황](../ideas/md/v04/issues/validation/notebook_content_mapping_status.md).

## 6. 취소·미룸의 화면 커서 계약 재검증

후속 기준: develop `4137f5e`. 앞 절의 기준 패키지 실패 결과는 당시 실행 근거로 보존한다. 이번 변경은 게임 동작을 바꾸는 것이 아니라, 이미 저장하도록 구현한 표시 커서와 게임 진행 상태를 구분하여 PA05의 세 관계 검사와 PA07의 두 검사를 교정하는 작업이다.

`notebook_state_assertions.gd::same_gameplay`는 다음 순서로 판정한다.

1. 현재 저장된 커서가 스키마에 맞고 현재 snapshot의 원본·분기·게임 문맥에 속하는지 `PRESENTATION.matches`로 검사한다.
2. 호출자가 지정한 `modal` 또는 `utility` 종류이며 `completed` 상태인지 확인한다. 없거나 미완료인 커서를 허용하지 않는다.
3. 두 snapshot에서 `loop_state.event_local_states.NOTEBOOK_PRESENTATION` 하나만 제거하고 나머지 전체 영속값을 비교한다. 차이가 있으면 경로를 출력한다. JSON 왕복의 동등한 정수 표현만 허용하며 값·타입을 임의로 변환하지 않는다.

관계 미룸 검사는 원래 허용한 질문·취소 기록 증가를 별도로 유지하고, 커서 외 관계값·완료 여부·연구 기록·지식·퍼즐 상태의 변화는 허용하지 않는다. 현실 수첩의 Esc와 수량 보조창은 대화 기록까지 전체 비교에 남긴다. 즉, 페이지를 읽었다거나 새 단서를 획득한 것처럼 처리하면 실패해야 한다.

반례 검사는 정상적인 보조창 닫기 상태를 출발점으로 관계값, 소지품, 지식, 대화 순번, 커서 누락, 미완료 커서, 다른 분기 커서를 각각 주입한다. 실제 게임이나 저장 파일을 수정하지 않고 snapshot 사본만 변형하며, 일곱 경우 모두 비교기가 거부해야 한다.

검증 패키지 SHA-256: `6DC12A969698E042CC3806F69D0B63C6CD065063191D03A02ED37D0A1A59F203`. 로그는 `%TEMP%/ggb-producer-cursor-20261004/`다. Windows Godot 4.7.2 headless, 별도 APPDATA/LOCALAPPDATA·빈 실행 디렉터리를 사용했다. import 41.6초, export 11.0초이며 모든 검사는 종료 코드 0과 PASS 표식을 함께 확인했다.

명령: `godot --headless --path <empty> --main-pack <pck> -- --notebook-<검사명>-smoke --ggb-dev-notebook-v2`.

| 검사명 | 결과 | 실행 증거 | 시간(초) |
| --- | --- | --- | ---: |
| `mara1` | PASS | ID·언어 54 / segment·언어 64, 미룸 차이 검사 4회 | 67.2 |
| `iris` | PASS | ID·언어 90 / segment·언어 104, 결과 시나리오 20, 미룸 차이 검사 2회 | 204.3 |
| `luca` | PASS | ID·언어 62 / segment·언어 78, enum 1,250조합, 미룸 차이 검사 2회 | 73.8 |
| `reality` | PASS | ID·언어 306 / segment·언어 336, Esc 차이 검사 2회 | 335.7 |
| `puzzle-surfaces` | PASS | ID·언어 106 / segment·언어 136, 행렬 9,556조합, 보조창 차이 검사 2회 | 39.5 |

위 12회 상태 비교에서 모두 `unexpected=[]`가 출력됐다. 세 관계 검사는 원래부터 허용한 질문·취소 기록 증가를 제외한 비교이며, 현실·수량 검사는 대화 기록도 비교한다. 등록 ID 수나 선언된 테스트 개수만 보고 통과로 간주한 결과가 아니다.

반례 검사 함수와 해당 호출만 추가한 최종 패키지 SHA-256은 `0CF34D62C6C46A1C77D09BA658DC927B658C174318FC076F9792122E3412D765`다. 기존 비교 함수와 나머지 네 검사 파일은 첫 패키지와 같다. `%TEMP%/ggb-producer-cursor-guards-20261004/`에서 import 41.9초·export 11.0초 후 `puzzle-surfaces`를 전체 재실행해 37.9초 PASS했다. 한영 각각 일곱 반례를 모두 거부했고 실제 표시 ID·segment와 9,556조합 검사도 유지했다. 이 최종 패키지로 나머지 네 검사를 다시 실행한 것으로 표기하지 않는다. 공통 Windows 루트 인증서 저장소 경고는 앞 절과 동일하게 남아 있다.

PA04의 커버리지 소유권, PA05의 지하 확인창, PA06의 에드가·마라 2 및 PA08의 재선택 복원 문제는 이 다섯 검사로 해결했다고 계산하지 않는다. 최신 지하 전체 v2 회귀와 Windows 실제 입력·성능 인수도 여전히 남아 있다.
