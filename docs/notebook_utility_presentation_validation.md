# 비관찰 보조창 복원 검증

기준: 2026-10-04, develop `7183274`. 전체 목표는 `IN_PROGRESS`다.

## 수정 범위

힌트 단계 요청창, B3 반복 실패 지원창, C3 세정제 양 비교표는 기록된 선택 모달이 아니므로 이전 schema 3 복원 대상에서 빠져 있었다. schema 4의 `utility`는 관찰을 새로 기록하지 않고 이 세 종류와 현재 단계·체크 상태만 보존한다. 기존 schema 1/2/3의 읽기 호환을 유지한다.

게임 코드의 `_restore_utility`는 고정된 화면 생성 경로만 허용하며 저장된 동작을 호출하지 않는다. 현재 단계와 세계 anchor를 검사하고, 다음 힌트 요청창에는 직전 힌트의 실제 archive 관찰을 요구한다. 체크를 저장하지 못하면 화면을 되돌리며 닫기 저장 실패는 창을 유지한다. 재로드된 옛 버튼과 새 창으로 교체된 옛 체크 콜백을 차단한다.

## 실행 방법

Godot 4.7.2 Windows에서 격리 APPDATA/LOCALAPPDATA와 빈 실행 폴더를 사용한다. 추적 기준 파일과 이번 변경으로 Windows Desktop Debug PCK를 export한다. 실제 프로젝트의 사용자 편집 씬·리소스·미추적 플러그인은 이 패키지에 포함하지 않는다.

```text
godot --headless --path <game> --editor --quit
godot --headless --path <game> --export-pack "Windows Desktop Debug" <notebook.pck>
godot --headless --path <empty> --main-pack <notebook.pck> -- --notebook-modal-presentation-smoke --ggb-dev-notebook-v2 --utility-only --cursor-phase=seed
godot --headless --path <empty> --main-pack <notebook.pck> -- --notebook-modal-presentation-smoke --ggb-dev-notebook-v2 --utility-only --cursor-phase=resume
godot --headless --path <empty> --main-pack <notebook.pck> -- --notebook-modal-presentation-smoke --ggb-dev-notebook-v2 --utility-only --cursor-phase=completed
```

세 명령은 같은 격리 저장 폴더를 쓰되 별도 프로세스다. seed의 한국어 양 비교표 체크를 resume의 영어 창에 복원하고 명시적으로 닫은 뒤 completed에서 다시 열리지 않는지 확인한다. 필수 PASS 마커·종료 코드와 스크립트/파싱/리소스 오류를 함께 확인한다.

## 검사 항목

- B3_B/C3/C4/D1/F0_A의 H0 메뉴 JSON 재로드, H1 명시적 요청·확인 후 다음 요청창 복원. H2 자동 공개 없음.
- 메뉴 열기·복원·양 비교 체크 전후의 전체 게임 상태 불변. 정상 표시 쓰기에서는 유효한 커서만 제외하며 복원과 실패에서는 전체 snapshot을 비교한다.
- H5를 읽지 않은 상태의 최종 메뉴 복원 거부. utility의 구버전 위장 및 실행 가능한 후속 동작 필드 거부.
- 동일 슬롯의 실제 재로드 뒤 낡은 힌트 버튼, 같은 세션의 새 비교표 뒤 낡은 체크 콜백 차단.
- 양 비교 체크 저장 실패 시 UI 복구, 닫기 실패 시 창 유지, 정상 재시도 및 별도 프로세스 복원.
- 반복 실패 지원은 상태·횟수 조건을 다시 검사하며 힌트나 잠금 해제를 자동 실행하지 않음.
- 기존 호스트와 프롤로그/본편 대사/기록 모달 재시작 회귀.
- 이전 schema 1/2의 대사와 schema 3의 모달을 실제 슬롯 파일로 저장·로드하여 같은 커서와 기록을 쓰기 없이 복원.

## 결과

최종 PCK SHA256: `6AB36DAD5174F87ED10678109A9F6859599D62231BDE90C08A4D7862B08D5745`.

| 검사 | 결과 | 실행 시간(초) |
| --- | --- | --- |
| import / export | PASS | 27.0 / 10.3 |
| 보조창 seed / resume / completed | PASS, 147 + 6 + 3 = 156개 | 29.7 / 7.4 / 6.2 |
| 수첩 호스트 | PASS, 301개 | 79.7 |
| 기록 모달 seed / resume / completed | PASS, 397 + 7 + 4 = 408개 | 104.7 / 6.1 / 5.5 |
| 본편 대사 seed / resume / completed | PASS, 106 + 7 + 4 = 117개 | 26.6 / 5.5 / 4.9 |
| 프롤로그 seed / resume / completed | PASS, 66 + 26 + 16 = 108개 | 35.1 / 15.8 / 8.1 |

모든 프로세스의 종료 코드 0과 해당 smoke PASS 마커를 확인했다. 기록 모달 seed에도 보조창 검사가 포함되므로 두 수치를 독립 경로의 총합으로 계산하지 않는다. `--utility-only` 실행 로그의 `NOTEBOOK_UTILITY_CHECKS`는 보조창 검사 수이며, 지하 전체 회귀 검사 수가 아니다.

기존 호스트 한 곳의 loop 전체 불변 가정은 새 표시 커서 저장과 충돌하여 최초 호환 실행에서 실패했다. 수정 후 유효한 utility 커서만 제외하고 loop뿐 아니라 전체 snapshot을 비교한다. 최종 패키지로 위 검사를 모두 재실행했으며 이전 실패는 PASS에 포함하지 않았다. 최종 스크립트/파싱/리소스 오류와 실패 단언은 없고, Windows 루트 인증서 저장소 읽기 경고는 별도로 남아 있다.

이번 패키지에서 지하 전체 두 엔딩 회귀를 다시 실행한 것은 아니다. 이전 커밋의 [지하 전체 검사](notebook_basement_regression_validation.md)와 이번 표시 상태·호스트·저장 호환 검사의 범위를 구분한다.

## 한계와 남은 범위

엔진 신호 기반 자동 검사다. 실제 Windows 마우스·키보드·IME/시각 검수, 고정 fixture의 cold/warm p95·RAM 인수를 대신하지 않는다. 실행 시간은 자동 검사 전체 소요 시간이며 입력 성능 수치가 아니다.

프롤로그 창문 확대, 일반 본문 스크롤과 마지막 선택 이외의 포커스 재시작 복원, 전체 22개 생산자의 필수/반복/최초 공개/공개 ID 감사는 남아 있다. 갤러리·설정·메뉴를 임의의 utility로 직렬화하지 않았으며 전체 목표를 이 세 창으로 축소하지 않는다.
