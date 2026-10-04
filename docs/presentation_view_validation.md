# 호출 화면 스크롤·포커스 편의 저장 검증

기준: 2026-10-04, develop `4262cc4`. 전체 목표는 `IN_PROGRESS`다.

## 구현 범위

`presentation_view_tracker.gd`가 프롤로그와 파생 본편 컨트롤러의 기존 UI에서 읽기 위치를 수집한다. `presentation_view_store.gd`는 슬롯·run·분기·namespace·local profile별로 최신 화면의 위치를 원자적 편의 파일로 저장한다. 게임 원고·퍼즐·선택·수첩 공개 규칙을 바꾸지 않는다.

복원 대상은 저장된 대사/질문/확인·기록 모달/utility, 창문 확대, 현재 월드 포커스다. 임의 설정 메뉴의 재시작 복원을 추가하지 않는다. 위치 문자열은 현재 컨트롤 맵에서만 조회하며 실행 가능한 노드/메서드 경로를 저장하지 않는다. 기준은 [데이터 계약 9.16절](data_contract.md#916-호출-화면의-스크롤포커스-편의-저장)이다.

## 실행

Godot 4.7.2 Windows, 격리 APPDATA/LOCALAPPDATA, 빈 실행 디렉터리, Windows Desktop Debug PCK를 사용한다. 실제 작업 디렉터리의 사용자 편집 씬·리소스·미추적 플러그인은 이 패키지에 포함하지 않는다.

```text
godot --headless --path <game> --editor --quit
godot --headless --path <game> --export-pack "Windows Desktop Debug" <notebook.pck>
godot --headless --path <empty> --main-pack <notebook.pck> -- --presentation-view-smoke --ggb-dev-notebook-v2 --cursor-phase=seed
godot --headless --path <empty> --main-pack <notebook.pck> -- --presentation-view-smoke --ggb-dev-notebook-v2 --cursor-phase=resume
godot --headless --path <empty> --main-pack <notebook.pck> -- --presentation-view-smoke --ggb-dev-notebook-v2 --cursor-phase=completed
```

세 phase는 실제 슬롯 파일과 편의 파일을 공유하는 서로 다른 OS 프로세스다. 테스트는 `user://__test_presentation_views`만 사용한다. 기존 호스트/프롤로그/모달/본편 대사/창문 복원 검사도 함께 실행한다.

## 검사 내용

- 긴 대사의 실제 스크롤 가능 영역에서 위치와 본문 포커스를 저장하고 별도 프로세스에서 같은 픽셀을 복원한다. 다음 문장으로 넘어가면 이전 위치를 재사용하지 않는다.
- 200% 글자 배율로 재개할 때 가용 영역의 상대 위치로 보정한다. 복원 대기 중 입력은 자동 복원을 취소한다.
- A1 질문, C4 경로 창, J4 결산 확인, C3 양 비교표에서 누르지 않은 버튼의 포커스를 한영 전환·디스크 재로드 후 복원한다. 실제 게임 snapshot은 변하지 않는다.
- P4 질문, P2 확대, 중앙홀 오브젝트도 포커스만 복원하고 선택·청소·이동을 실행하지 않는다.
- 다른 profile/namespace/slot/run/origin/branch와 다른 표시 식별에서는 이전 위치를 사용하지 않는다. 실제 재로드 뒤 이전 tracker의 쓰기를 차단한다.
- 손상 primary의 정상 backup 복구, 미래 버전 backup의 덮어쓰기 금지, 잘못된 위치 값 거부를 검사한다.
- 경로를 파일로 막아 실제 편의 저장 실패를 유발한다. 게임 snapshot 불변과 warning, 정상 경로 복구 뒤 재저장을 확인한다.

## 결과

최종 PCK SHA-256: `957C0DE0CC2B8C11899C618C75C870FBDC83A99737348428BD81167145A43CDE`.

아래 검사는 scope·컨트롤러·레이아웃 버전 분리 및 삭제 대기 화면 방어까지 포함한 동일 패키지로 실행했다. import 42.3초, export 11.7초, 모든 실행 종료 코드 0이다.

| 검사 | 통과 수 | 실행 시간(초) |
| --- | --- | --- |
| 신규 위치 복원 seed / resume / completed | 59 / 6 / 3 | 25.0 / 6.5 / 6.0 |
| 통합 수첩 호스트 | 301 | 69.8 |
| 프롤로그 종합 v2 / 기존 모드 | 267 / 262 | 17.1 / 12.4 |
| 기록 모달 seed / resume / completed | 397 / 7 / 4 | 102.7 / 6.7 / 5.9 |
| 프롤로그 대사·선택 커서 seed / resume / completed | 66 / 26 / 16 | 33.5 / 15.5 / 7.0 |
| 본편 대사 커서 seed / resume / completed | 106 / 7 / 4 | 28.7 / 6.1 / 5.7 |
| 창문 확대 seed / resume / completed | 75 / 7 / 3 | 38.1 / 7.8 / 5.5 |

총 1,616개 단언을 통과했다. 위 시간은 headless 검증 실행 시간이며 사용자 입력 지연이나 성능 예산 측정값이 아니다. 추가 회귀 명령은 각각 `--notebook-host-smoke`, `--prologue-smoke`, `--notebook-modal-presentation-smoke`, `--notebook-prologue-presentation-smoke`, `--notebook-presentation-smoke`이며, 창문 검사는 프롤로그 커서 명령에 `--window-inspection-only`를 붙인다. phase 검사는 위와 같은 `--cursor-phase`를 사용하고 기존 모드 프롤로그만 `--ggb-dev-notebook-v2`를 제외한다.

로컬 실행 로그는 `%TEMP%/ggb-presentation-view-final-*.out.log`, `*.err.log`, 패키지는 `%TEMP%/ggb-presentation-view-final-20261004/notebook.pck`에 남겼다. 모든 stderr의 오류·경고 표식은 환경의 `Failed to read the root certificate store`뿐이었다. 스크립트 파싱·컴파일·리소스 로딩 오류는 없었다. 인증서 환경 메시지를 해결한 것으로 계산하지 않는다.

중간 검사에서 JSON 왕복의 숫자 표현 차이로 양 비교표의 화면 식별이 달라지는 문제를 발견해 기존 게임 상태의 정규화 규칙을 적용했다. backup 비교는 JSON에 저장된 동일 payload끼리 비교하도록 교정했다. 부동소수점 편의 위치를 원래 메모리 비트와 동일하다고 간주하지 않으며 게임 상태 비교의 엄격한 규칙은 변경하지 않았다.

## 적용 한계

대부분 엔진 신호와 컨트롤러 API로 실행하는 headless 검사다. 키/마우스의 실제 OS 전달, IME, OS 배율·시각 검수와 입력 latency/RAM 계측을 대신하지 않는다. 언어·배치 변경 후 상대 위치는 같은 문단의 정확한 재현 보장이 아니다.

기존 게임 커서가 없는 임의 화면을 자동으로 새 저장 지점으로 만드는 기능은 없다. 기록되지 않은 메뉴·설정 패널의 탐색 상태는 각 기존 계약의 별도 범위다. 22개 생산자의 전체 필수/반복/최초 공개/공개 ID 감사와 실제 입력·성능 인수는 남아 있다.
