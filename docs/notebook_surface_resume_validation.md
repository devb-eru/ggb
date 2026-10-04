# 월드 표시 재개와 관찰 기록 중복 검증

기준: 2026-10-04, develop `070e630`. 대상은 PA09 / [GGB-ERR-2026-0025](../ideas/md/v04/issues/items/GGB-ERR-2026-0025_월드_재진입_관찰기록_중복.md)다. 통합 수첩 전체 목표는 `IN_PROGRESS`다.

## 1. 원인과 수정

월드 표면의 occurrence·conversation·presentation 토큰은 `NotebookSurfaceCapture` 인스턴스에만 남았다. 새 컨트롤러는 저장된 월드를 다시 그리면서 토큰을 새로 만들었고, 같은 언어·원문의 EDC 표면 세 개가 다시 기록됐다.

`notebook_surface_receipt.gd`는 현재 방문의 표시 확인 정보를 loop-local snapshot에 보관한다. `DialogueHistoryWriter.append_to_snapshot`이 실제 authored 관찰과 이 정보를 같은 후보 snapshot에 반영한다. 확인 정보만 가지고 자료를 공개하지 않고 기존 관찰 writer의 토큰·내용 일치 검사를 그대로 통과한다.

- 새 컨트롤러/로드에서 같은 stable scope인 경우만 이전 토큰을 재사용한다.
- 정상 방문 scope 변경과 `new_attempt`는 새로운 발생을 유지한다.
- 표시한 값·segment·언어·원문·버전이 다른 경우를 동일 content ID로 합치지 않는다.
- 현재 활성 표면 및 미완료 요청의 토큰만 남긴다. 이전 변수 조합의 원문은 archive에서 계속 보존한다.
- 기존 session/load epoch guard는 그대로 둔다. 표시 확인 정보만 게임 anchor 계산에서 제외하고 실제 게임 필드는 제외하지 않는다.
- 일반 본편 컨트롤러와 프롤로그의 직접 저장·사건 원자 저장에 모두 연결한다. 통합 수첩 Query에는 writer를 추가하지 않는다.

## 2. 검사 구성

`--notebook-surface-resume-smoke --ggb-dev-notebook-v2`는 실제 GameState, SaveManager, LoadCoordinator, DialogueHistoryWriter와 별도 테스트 슬롯을 사용한다. capture 단위의 방문 전환은 합성 scope로 검사하며 실제 방 이동 완주라고 부르지 않는다.

| 사례 | 기대 |
| --- | --- |
| 실제 파일 저장·로드 후 새 capture | 같은 snapshot·언어의 관찰·순번·확인 정보 불변 |
| 다른 scope 진입 후 복귀·명시적 재시도 | 새로운 발생은 유지 |
| 저장 거부 | 게임 snapshot과 저장 바이트가 모두 이전 상태 |
| 성공 응답 유실 | 디스크 커밋 확인 후 한 번만 성공, 재생성에도 중복 없음 |
| 언어 변경 | 새로 표시된 번역만 별도 기록, 기존 원문 불변, 같은 번역 재개는 중복 없음 |
| 동적 퍼즐 표면 | 다른 회전값은 새 관찰, JSON 왕복 후 같은 값은 동일 기록 |
| 격리·호환 | 슬롯·분기 불일치 거부, receipt 없는 구 저장은 정직한 최초 기록, 미래/손상 schema 거부 |

실제 재선택 회귀는 두 언어 각각 대화·확인창·미확정 선택·완료 커서·커서 없는 복사본을 연다. 동일 언어 완료/커서 없음에서는 전체 snapshot 불변과 신규 관찰 0을 요구한다. 언어 변경 사례에서는 실제 활성 표면에 해당하는 새 번역 관찰과 그 표시 확인 정보만 허용한다. 원본 슬롯 파일, 이전 관찰/보호/출처 링크와 모든 게임 진행은 유지한다.

## 3. 실행 이력

초기 import에서 GDScript의 `can_resume` 추론 오류를 발견해 `bool` 명시로 수정했다. 첫 실행 가능한 패키지의 집중 검사 66개가 통과했고 동적 변수·실제 JSON 로드 검사를 추가한 다음 패키지는 80개가 통과했다. 이 수치는 최종 통합 회귀 전체 통과를 뜻하지 않는다.

활성 표면만 남기는 저장 범위와 표시 지문 확인은 이후 보완했으므로, 앞선 패키지의 PASS를 최종 소스 결과로 옮겨 적지 않는다. 최종 결과와 잔여 검사는 후속 절에 구분해 기록한다.

첫 통합 PCK `077E5F35CEC0BDE33D65C18DA7FDD72D4193875B964979AC5518406C9BF556C5`의 로그는 `%TEMP%/ggb-surface-resume-integration-20261004/`다. import 39.0초, export 10.8초 후 집중 80개(8.1초), 실제 한영 교차 재선택 356개(65.0초), 조회 통합(120.1초), 파열 표면 50 ID/한영 100조합(48.9초)이 통과했다.

이어 프롤로그 표면의 기존 `before.loop_state == after.loop_state` 판정 26건이 실패했다. 당시 패키지는 표시 확인 정보를 loop-local에 새로 저장하지만 테스트가 그 필드도 게임 진행 변화로 취급했다. 표면 ID·언어 164개, segment·언어 176개, 행렬 252개는 끝까지 실행됐으나 해당 실행 전체는 FAIL이다. 그 뒤 검사는 실패 시 중단되어 실행하지 않았으며 통과로 보충하지 않는다.

수정한 `same_surface_gameplay`는 다음을 모두 확인한다. 단순히 loop 상태 비교를 제거한 것이 아니다.

1. 표시 확인 정보가 schema·출처·분기에 맞고 각 토큰이 실제 authored 관찰의 occurrence/conversation과 함께 존재한다.
2. 기존 관찰 원문·보호·참조가 그대로이며 새 관찰 수만큼의 순번/revision 증가만 허용한다.
3. 관찰 append와 표시 확인 정보 외 전체 snapshot이 같다. 대사 커서·지식·관계·인벤토리·퍼즐 진행도 비교에 남긴다.
4. 지식, 인벤토리, 관계값, 대사 커서, archive 순번, 관찰에 없는 receipt 토큰을 각각 주입하면 비교기가 거부해야 한다.

## 4. 최종 패키지 검증

PCK SHA-256: `96D9E0EE9AEBD5484561B1419560067786FA6BA1E24B6E430A45D2E324363927`. 로그: `%TEMP%/ggb-surface-resume-release-20261004/`. Windows Godot 4.7.2 headless, 격리 APPDATA/LOCALAPPDATA·빈 실행 디렉터리에서 실행했다. import 41.7초, export 14.8초다. 중간 패키지 `E30A1189ABC28C4BF8AC416827FBCD34985E563D951BAC96C9FD42070D6B56E0`의 통과 결과와 섞지 않고, A→B→A 배치 복귀 및 별도 프로세스 검사를 포함한 마지막 패키지 결과만 아래에 기재한다.

| 검사 | 최종 결과 | 시간(초) |
| --- | --- | ---: |
| `surface-resume` | PASS, 108개. 한영 실패 원자성·동적 값·A→B→A·반례 거부 포함 | 10.4 |
| `reselect-presentation` 한영 교차 | PASS, 356개. 실제 새 언어 표면만 기록 | 60.9 |
| 같은 검사 `--reselect-same-locale` | PASS, 348개. 같은 EDC 월드 재개 신규 관찰 0 | 33.7 |
| `query` | PASS, 조회 299·비교 300·갤러리 182 등 하위 검사 포함 | 47.4 |
| `fracture-surfaces` | PASS, 50 ID·한영 100조합 | 40.2 |
| `prologue-surfaces` | PASS, ID·언어 164 / segment·언어 176 / 행렬 252 | 293.7 |
| `puzzle-surfaces` | PASS, ID·언어 106 / segment·언어 136 / 행렬 9,556 | 27.4 |
| 월드 실제 프로세스 seed / resume | PASS, 8 + 8개. 서로 다른 PID, 전체 snapshot·저장 본문 동일, EDC 표면 정확히 3건 유지 | 5.2 / 5.0 |
| 프롤로그 대사 커서 seed / resume / completed | PASS, 66 + 26 + 16개. 서로 다른 프로세스 | 21.0 / 10.1 / 5.0 |
| 본편 대사 커서 seed / resume / completed | PASS, 106 + 7 + 4개. 서로 다른 프로세스 | 15.3 / 4.5 / 4.2 |
| 크레딧·재선택 집중 v2 / 기존 모드 | PASS, 254 / 242개. 종합 회귀가 아님 | 10.9 / 9.1 |
| 지하 전체 v2 / 기존 모드 | NOT_RUN, 이번 최종 패키지의 전편 회귀로 집계하지 않음 | - |

명령은 `godot --headless --path <empty> --main-pack <pck> -- --notebook-<검사명>-smoke --ggb-dev-notebook-v2`를 기본으로 한다. 실제 월드 프로세스는 `surface-resume`에 `--surface-resume-phase=seed`, 다음 프로세스에 `--surface-resume-phase=resume`을 붙인다. 커서 프로세스는 `--cursor-phase=seed/resume/completed`를 순서대로 실행한다. 크레딧 집중은 `--basement-session-smoke --basement-credits-regression-only`이며 기존 모드에서는 개발 플래그를 빼고 실행한다.

각 PASS는 종료 코드 0과 해당 완료 표식을 함께 확인했다. 스크립트·파싱 오류 및 비정상 종료를 성공으로 처리하지 않았다. 환경의 `Failed to read the root certificate store` 경고는 남아 있으며 해결한 것으로 계산하지 않는다. 시간은 검증 프로세스 소요 시간이지 입력 p95나 메모리 성능 인수값이 아니다.

## 5. 남은 범위

- PA09 제품 수정은 `RESOLVED`, 전 장소 실제 입력 재개 검토는 `REVIEW`다. 합성 scope 이동을 실제 방 이동 완주로 보고하지 않는다. 실제 새 프로세스 검사는 F3 재선택 EDC 월드, 기존 커서 프로세스 검사는 각 스크립트가 열거한 경로다.
- Windows 실제 마우스·키보드·IME·스크롤·시각 검수와 고정 대형 fixture cold/warm p95·RAM 인수는 별도다.
- PA04 커버리지 합집합, PA05 지하 확인창, PA06 에드가·마라 2, 최신 지하 전체 v2 및 22개 생산자의 필수/반복/최초 공개·공개 ID 전편 감사는 남아 있다.
- 기존 사용자 편집 씬·번역 리소스·플러그인·오디오는 테스트 패키지나 이번 커밋에 합치지 않았다. 기본 비활성 rollout을 유지한다.
