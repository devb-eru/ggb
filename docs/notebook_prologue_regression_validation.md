# 프롤로그 종합 회귀의 수첩 v2 대응 검증

기준: 2026-10-04, develop `60aabc1`. [전체 계획](../ideas/md/v04/issues/validation/notebook_history_review_plan.md)의 목표는 계속 `IN_PROGRESS`다.

## 문제와 수정

직전 [창문 확대 검증](notebook_window_inspection_validation.md)의 `--prologue-smoke --ggb-dev-notebook-v2` 실패를 재확인했다. 이번 변경 대상은 `prologue_scene_smoke.gd`와 검증 문서이며, 게임 코드·대사·저장 규칙은 바꾸지 않는다.

| 기존 검사 문제 | 수정 | 유지·추가한 검증 |
| --- | --- | --- |
| P1 대사를 화면에서만 닫고 P4 진행 값을 덮어써 P1 커서가 남음 | P1을 실제 완료하고 주방 진입·관찰 저장 후 P4 기억 대사를 표시해서 저장 | P4 7문장 재개, 올바른 authored 첫 문장, 복원 전후 전체 snapshot 동일, 완료 후 `memory_anchor_ready` |
| 메뉴 자식 4번과 구형 `HistoryTranscript` 라벨을 고정 조회 | 기록 열기 진입점과 실제 공통 호스트 Query·상세·닫기 사용. 기존 모드는 기존 라벨을 별도 확인 | 보인 문장만 목록·실제 본문에 표시, 미표시 다음 문장 제외, 닫은 뒤 원래 화면과 전체 snapshot 유지 |
| 슬롯을 바꿔 저장 실패를 흉내 내면 v2의 낡은 콜백 차단에 먼저 걸림 | v2에서는 슬롯·로드 scope를 유지한 채 저장 서비스 실패 주입. 기존 모드의 잘못된 슬롯 검사도 유지 | 선택·문장 저장 실패 롤백, 실패 시 선택창 유지/대사 넘김 금지, 재시도 중복 없음 |
| 임의 raw 대사에 필수 사건·장·위치 문맥이 없음 | 테스트 대사에 명시적 문맥만 추가하고 authored ID를 붙이지 않음 | v2에서 `unmapped` 분류, 원문 그대로 조회, authored 원고 검증으로 가장하지 않음 |
| 대화 완료까지 무제한 반복 | 128회 상한과 문장·인덱스 무진행 검출 | 진행 불가 시 원인을 출력하고 실패, 무한 대기로 PASS 여부가 숨지 않음 |

기존 취침 실패의 로컬 진행·수첩 롤백, 일반 저장 뒤 완료 누출 금지, P6 저장 경계, 첫 리셋 후 물리 상태 초기화, 대화·일지·색 서명·차 기억·주방 진동 기록의 보존과 재로드 단언도 유지했다. UI 구현에 맞지 않는 접근만 교체했으며 실패 검사를 삭제하지 않았다.

## 실행 방법

Godot 4.7.2 Windows에서 격리 APPDATA/LOCALAPPDATA, 빈 실행 디렉터리와 Windows Desktop Debug PCK를 사용한다. 실제 작업 디렉터리의 사용자 편집 씬·리소스·미추적 플러그인은 이 패키지에 포함하지 않는다.

```text
godot --headless --path <game> --editor --quit
godot --headless --path <game> --export-pack "Windows Desktop Debug" <notebook.pck>
godot --headless --path <empty> --main-pack <notebook.pck> -- --prologue-smoke --ggb-dev-notebook-v2
godot --headless --path <empty> --main-pack <notebook.pck> -- --prologue-smoke
godot --headless --path <empty> --main-pack <notebook.pck> -- --notebook-prologue-presentation-smoke --ggb-dev-notebook-v2 --cursor-phase=seed
godot --headless --path <empty> --main-pack <notebook.pck> -- --notebook-prologue-presentation-smoke --ggb-dev-notebook-v2 --cursor-phase=resume
godot --headless --path <empty> --main-pack <notebook.pck> -- --notebook-prologue-presentation-smoke --ggb-dev-notebook-v2 --cursor-phase=completed
```

마지막 세 명령은 같은 격리 저장소를 쓰는 별도 OS 프로세스다. 기존 커서 검사는 변경하지 않고 함께 실행했다. import/export와 각 smoke의 종료 코드, 필수 PASS 마커, 스크립트·파싱·리소스 오류를 모두 검사한다.

## 최종 결과

PCK SHA256: `68398DAEC284D2BC35ED7267DAA309D466EE0AA9ECA1FB6BCB1F17FE9EE88DA3`.

| 검사 | 결과 | 프로세스 시간(초) |
| --- | --- | --- |
| import / export | PASS | 25.2 / 10.5 |
| 프롤로그 종합 v2 | PASS, 267개 | 15.8 |
| 프롤로그 종합 기존 모드 | PASS, 262개 | 13.2 |
| 대화 커서 seed / resume / completed | PASS, 66 + 26 + 16 = 108개 | 34.9 / 14.8 / 7.0 |

모든 최종 프로세스는 종료 코드 0과 필수 마커를 확인했다. Windows 루트 인증서 저장소 읽기 경고는 환경 경고로 남겼다. 중간 실행의 본문 라벨 종류 가정 오류와 동적 값의 타입 추론 오류는 테스트에서 수정하고 최종 패키지를 다시 만들었다. 그 실패 실행은 최종 PASS에 포함하지 않는다.

## 계획 대응과 한계

- NB-R05: 프롤로그 검사에서 낡은 UI 계층 가정을 제거했다. 다른 테스트 전체의 UI 가정 감사까지 완료한 것은 아니다.
- NB-Q08: 이번 프롤로그 자료 조회·상세·닫기의 전체 snapshot 불변을 검사했다. 모든 필터·고정 경로는 기존 전용 검증과 별도로 확인해야 한다.
- NB-Q09·NB-Q10: 첫 리셋의 기록 보존과 미표시 다음 문장 차단을 확인했다. 모든 장·모든 숨은 이름과 자료를 포괄하는 증거로 확대하지 않는다.
- P4의 세 답변 전개를 빠르게 순회하는 기존 부분은 `test_mode` 검사다. 실제 저장을 쓰는 P4 재로드와 별도 커서 검사를 구분하며, 이 검사만으로 모든 P4 선택의 실제 OS 입력을 증명하지 않는다.
- 수첩 내부 UI 편의 저장과 호출 화면의 앱 재시작 스크롤·포커스는 별개다. 이번 테스트 정비가 후자의 새 구현을 포함하지 않는다.

22개 생산자 전체 필수/반복/최초 공개/공개 ID 감사, 일반 스크롤·포커스 및 나머지 조사 표시의 계약 대조, Windows 실제 마우스·키보드·IME·시각 검수와 고정 부하 성능 인수는 남아 있다. 실행 시간은 입력 지연 p95나 성능 예산 통과 근거가 아니다.
