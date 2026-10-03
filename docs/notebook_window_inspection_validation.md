# 프롤로그 창문 확대 복원 검증

기준: 2026-10-04, develop `c677e73`. 전체 목표는 `IN_PROGRESS`다.

## 변경 범위

P2 확대 창의 번호와 선택 도구를 게임 로컬 `NOTEBOOK_WINDOW_INSPECTION` 키에 저장한다. 대사 커서와 분리하여 도구 사용 대사가 창 위에 겹친 상태도 복원한다. 청소 진행과 도구를 자동 재실행하지 않고, 기존 저장된 물리 상태를 현재 언어로 표시한다.

선택 도구 저장 실패는 이전 도구로 복구하며 닫기 저장 실패는 창을 유지한다. 청소 진행 저장 실패에도 화면만 청소되거나 P2 완료로 넘어가지 않도록 물리 상태를 다시 읽는다. 이전 로드의 창문·아이템 입력과 닫기는 scope 검사로 차단한다.

## 실행 방법

Godot 4.7.2 Windows, 격리 APPDATA/LOCALAPPDATA, 빈 실행 폴더와 Windows Desktop Debug PCK를 사용한다. 실제 작업 디렉터리의 사용자 편집 씬·리소스·추가 플러그인은 덮어쓰거나 이 검증 패키지에 포함하지 않는다.

```text
godot --headless --path <game> --editor --quit
godot --headless --path <game> --export-pack "Windows Desktop Debug" <notebook.pck>
godot --headless --path <empty> --main-pack <notebook.pck> -- --notebook-prologue-presentation-smoke --ggb-dev-notebook-v2 --window-inspection-only --cursor-phase=seed
godot --headless --path <empty> --main-pack <notebook.pck> -- --notebook-prologue-presentation-smoke --ggb-dev-notebook-v2 --window-inspection-only --cursor-phase=resume
godot --headless --path <empty> --main-pack <notebook.pck> -- --notebook-prologue-presentation-smoke --ggb-dev-notebook-v2 --window-inspection-only --cursor-phase=completed
```

세 phase는 같은 격리 저장소를 쓰는 서로 다른 OS 프로세스다. seed는 한국어, resume와 completed는 영어다. 종료 코드와 필수 PASS 마커, 스크립트/파싱/리소스 오류를 함께 판정한다.

## 검사 항목

- 세 창문 각각 번호·선택 도구와 전체 snapshot을 실제 슬롯 JSON 재로드 전후 비교한다.
- 스패너 대사가 겹친 상태의 대사 토큰·도구·확대 창을 함께 복원하고 중복 관찰/자동 실행이 없는지 확인한다.
- 도구 선택·닫기 저장 실패, 닫기 재시도 및 닫은 화면의 재로드를 검사한다.
- 청소 저장 실패 후 먼지가 유지되며, 마지막 젖은 구역의 저장 실패도 P2를 완료하지 않는지 확인한다. 재로드 후 명시적 마지막 닦기로만 완료하고 중앙홀로 돌아간다.
- 같은 슬롯을 다시 로드한 뒤 이전 화면의 구역 클릭·도구 선택·드래그 시작·닫기 요청이 상태를 변경하지 않는지 검사한다.
- 잘못된 버전·창문 번호·아이템 ID를 저장 검증기가 거부한다.
- 개발 옵션을 끈 legacy 검사에서는 새 확대 키를 쓰지 않고 기존 방 단위 재개와 도구 동작을 유지한다.
- 별도 프로세스에서 젖은 창문과 선택 천은 복원하되 GUI 드래그와 닦기를 재실행하지 않는다. 전체 snapshot은 복원 전후 동일하다.
- 기존 수첩 호스트, 프롤로그 대사/관찰/메모, 본편 대사·기록 모달·보조창의 회귀를 검사한다.

## 결과

최종 PCK SHA256: `F9E96F6B66F2A919CAA8FDFD98912E0921C18A7CFAB9B0A3D7BF1C2D49B53E30`.

| 최종 패키지 검사 | 결과 | 프로세스 시간(초) |
| --- | --- | --- |
| import / export | PASS | 43.0 / 11.2 |
| 창문 seed / resume / completed | PASS, 75 + 7 + 3 = 85개 | 39.7 / 8.5 / 5.7 |
| 기존 모드 창문 | PASS, 7개 | 6.3 |
| 수첩 호스트 | PASS, 301개 | 76.1 |
| 프롤로그 커서 seed / resume / completed | PASS, 66 + 26 + 16 = 108개 | 33.3 / 14.7 / 7.1 |
| 기존 모드 프롤로그 종합 | PASS | 12.5 |

기존 모드 창문은 `--notebook-prologue-presentation-smoke --window-inspection-legacy-only`, 기존 모드 종합은 `--prologue-smoke`를 사용하며 두 명령 모두 `--ggb-dev-notebook-v2`를 붙이지 않는다. 호스트는 `--notebook-host-smoke --ggb-dev-notebook-v2`, 프롤로그 커서는 집중 명령에서 `--window-inspection-only`를 제외한다.

기존 모드 제한을 추가하기 전의 선행 PCK `ABA08B2BDF10AF14D8BE448E1BA7699399A2B86879F7D1955E51DEF4AAB93851`에서도 다음 회귀를 실행했다. 최종 패키지 재실행 결과와 구분한다. 이 선행 패키지 이후 제품 코드 차이는 v2에서만 확대 키를 쓰고 복원하며 열기 저장을 수행하도록 제한한 것이다.

| 선행 패키지 회귀 | 결과 | 프로세스 시간(초) |
| --- | --- | --- |
| 기록 모달·보조창 seed / resume / completed | PASS, 397 + 7 + 4 = 408개 | 105.1 / 7.4 / 5.5 |
| 본편 대사 seed / resume / completed | PASS, 106 + 7 + 4 = 117개 | 27.8 / 5.7 / 5.7 |
| 프롤로그 원고·표시 | PASS, 164 ID-언어·176 segment-언어·252 동적 조합 | 473.8 |
| 프롤로그 원고 단독 | PASS, authored 정의 102개 | 376.3 |

원고·표시 검사는 원고 단독 검사를 내부에서 포함하므로 독립 검사의 총합으로 더하지 않는다. 필수 PASS·종료 코드 0과 스크립트/파싱/리소스 오류 없음으로 성공을 확인했다. Windows 루트 인증서 저장소 읽기 경고는 환경 경고로 따로 남겼다. 아래 실패한 v2 구형 종합 조합은 이 PASS 표에 포함하지 않는다.

### 검사 중 발견한 결함

최초 66개 집중 검사와 별도 프로세스 resume/completed는 통과했지만, 마지막 구역 실패·재시도 검사를 추가하자 복원 후 완료 대사가 닫히지 않는 문제가 드러났다. 복원용 빈 관찰 scope에서 이후 도구 입력을 수집해 사건/session 식별자가 비어 있는 요청이 완료 저장에 들어갔다. 복원 자체에서는 관찰하지 않고, 재구성 끝에 다음 명시적 입력용 scope만 준비하도록 수정했다. 이 실패 실행은 최종 PASS 결과에 포함하지 않는다.

### 후속 테스트 정비 항목

`--prologue-smoke --ggb-dev-notebook-v2` 조합은 실패했다. `prologue_scene_smoke.gd`의 P4 fixture는 `_dismiss_dialogue_for_test`로 표시만 닫은 뒤 진행 변수를 직접 바꿔 이전 P1 커서를 유지한다. 새 모드가 저장된 대사를 우선 복원하므로, 이 fixture의 구형 P4 자동 재개 가정과 충돌한다. 또한 588행의 `HistoryTranscript` 직접 접근은 공통 수첩 호스트 경로에서 null을 참조한다. 작성 정보 없는 임의 문자열 대사도 새 authored 커서 fixture와 구별해야 한다.

이 실행을 제품 회귀 PASS에 포함하지 않는다. 당시 후속 정비안은 실제 대사 완료/새 표시 경로로 fixture를 만들고, 공통 수첩 조회·닫기 API를 사용하며, 임의 raw 대사와 authored 대사의 계약을 나누는 것이었다. 기존 단언을 삭제하거나 제품 코드가 오래된 테스트를 우회하도록 바꾸지 않는다. 창문 단계에서는 구형 종합 검사를 기존 모드로 실행하고, 새 모드는 별도 프롤로그 원고/표시/커서 검사로 검증했다.

후속 [프롤로그 종합 회귀 정비](notebook_prologue_regression_validation.md)에서 해당 조합을 수정·재실행하여 v2와 기존 모드 모두 통과했다. 이 해결은 별도 후속 패키지의 결과이며 위 창문 패키지의 실패 이력을 덮어쓰지 않는다. UI 내부 라인 번호는 당시 `60aabc1` 기준이다.

## 한계와 후속 범위

엔진 신호 기반 headless 자동 검사다. 실제 Windows 마우스·키보드·IME·OS 배율·시각 검수나 고정 fixture cold/warm 지연·RAM 인수를 대체하지 않는다. 프로세스 시간은 개별 입력의 p95 수치가 아니다.

일반 본문 스크롤·포커스의 재시작 위치와 나머지 조사/탐색 화면, 22개 생산자의 전체 필수/반복/최초 공개/공개 ID 감사는 남아 있다. 기존 지하 전체 두 엔딩 결과는 [별도 검증](notebook_basement_regression_validation.md)에 있으며 이번 패키지의 재실행 결과로 취급하지 않는다.
