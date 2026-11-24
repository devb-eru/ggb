# GGB-WRK-2026-0054 · EP01 수정 시트의 Godot 반영

| 필드 | 값 |
| --- | --- |
| ID | GGB-WRK-2026-0054 · 로컬 작업, 외부 Issue 미등록 |
| 유형 | CONTENT / FEATURE |
| 담당자 / 검토자 | Codex / beru |
| 작업 상태 | REVIEW |
| 목표 마일스톤 | PROD_01_VERTICAL_SLICE |
| 관련 결정 | [GGB-DEC-2026-0013](../../decisions/GGB-DEC-2026-0013_EP01_수정대사_재생시점.md) |
| 기준일 | 2026-10-27, Asia/Seoul |

[원본 시트](https://docs.google.com/spreadsheets/d/1cHx28-B4lG-p9iMyxt7HkQ4Dgk9QeI14UiAJC512v5w/edit)의 `09_Runtime_Master`, `10_Route_Edge_Master`, `11_State_Predicate`, `12_State_Effect`를 기준으로 한다. 기존 행과 한국어 대사 원문을 보존한다.

- [x] 노드 529개, 연결 135개, 조건 152개, 효과 33개를 런타임 데이터로 생성했다.
- [x] 모든 노드의 한국어 원문, 화자, 초상 위치·상태 및 출처 ID를 연결했다.
- [x] 에드가의 추가 선택지, 조건별 반응, 같은 루프의 반복 반응을 연결했다.
- [x] 대화 완료 시 반복 플래그를 저장하고 다음 루프에서는 초기화한다.
- [x] 새 문장 표식은 버전 3으로 기록하고 기존 수첩 버전 1·2는 유지한다.
- [x] 대화 중간·선택지 화면·완료 후의 저장 및 불러오기를 검사했다.
- [x] 사용자 확인에 따라 첫 취침·다음 아침의 프롤로그를 새 대사로 연결했다.
- [x] 사용자 확인에 따라 A1의 ‘어제 그 흔적’ 독백을 다음 아침 표식 확인 때 재생한다.
- [x] 최종 회귀 검증을 완료하고 근거를 기록한다.

## 구현

- `scripts/sync_ep01_sheet.py`: 실제 시트 응답을 읽고 재현 가능한 JSON을 생성한다. `--check`는 원본 스냅샷과 생성물이 일치하는지 검사한다.
- `game/data/dialogue/chapter_one/ep01_runtime.json`: 원본 4개 표와 출처 해시.
- `game/data/notebook/ep01_sheet_v1.json`: 표시한 대사와 선택지의 수첩 정의. 번역이 비어 있는 새 대사는 한국어 원문을 표시한다.
- `game/scripts/systems/ep01_script.gd`: 대사 구간·조건·선택지 해석. 퍼즐 진행과 리셋은 기존 Session 및 Coordinator를 사용한다.
- `game/scripts/chapters/chapter_one_controller.gd`: 실제 행동과 원본 대사 연결, 선택지 저장·재개.
- `game/scripts/systems/chapter_one_session.gd`: 완료한 조건별 대화의 반복 플래그 저장.
- `game/scripts/prologue/prologue_controller.gd`: 첫 취침·다음 아침의 새 대사와 선택지, 최초 리셋의 저장·재개 및 챕터 인계.

## 검증

이 기록의 수량과 PASS는 2026-10-27 검증 후보의 결과다. 이후 브랜치의 적용 상태는 그 브랜치의 런타임 데이터와 검증 결과에서 확인한다.

현행 생성기로 대조하려면 수식의 `effectiveValue`가 들어 있는 시트 스냅샷과 이전 수첩 카탈로그가 필요하다. 2026-10-27 로컬 스냅샷에는 이 필드가 빠진 수식이 있어 당시 검증 기록과 함께 보관한다.

`python -X utf8 scripts/sync_ep01_sheet.py --source <시트 스냅샷 JSON> --previous-catalog <이전 카탈로그 JSON> --check`

현재 게임 프로젝트를 Godot에서 가져온 뒤 `powershell -File scripts/run_ep01_sheet_tests.ps1 -GodotPath <Godot 실행 파일>`로 런타임을 검증한다.

같은 명령의 `-Suite`에 `prologue`, `notebook_prologue`, `cursor_seed`, `cursor_resume`, `cursor_completed`를 지정할 수 있다. 커서 검사는 seed → resume → completed 순서로 서로 다른 프로세스에서 실행한다.

테스트는 실제 소스와 임포트 리소스를 복사한 별도 프로젝트 및 사용자 저장소에서 실행한다. 사용자 에디터의 MCP 서비스와 저장 파일에 영향을 주지 않는다. 원본 스냅샷과 기존 검증 기록은 로컬 `output/ep01-godot-sync/`에 보관하고 새 테스트 프로젝트와 실행 로그는 `outputs/ep01-godot-sync/`에 생성한다.

EP01 전용 검사는 모든 원문·화자 정의, 새 선택지의 합류, 조건별 최초/반복/리셋 반응, 실제 컨트롤러의 저장·불러오기, A1 표식부터 J2 복원까지의 진행을 확인한다. 첫 취침 검사는 취소, 저장된 취침·아침 선택창의 복원, 실제 ResetCoordinator를 통한 정확히 한 번의 리셋, 반복 플래그 초기화, 첫 아침 답변과 챕터 인계를 확인한다.

기존 `chapter_one_smoke.gd` 전체는 별도로 실행했으며, 변경 전 HEAD 코드에서도 동일한 이력 상태 비교 실패 8개와 371행의 수첩 뷰 null 접근 오류가 재현됐다. 이 기존 테스트의 실패를 EP01 검사 통과로 표현하지 않는다. 기존 테스트가 발견한 새 표식창 충돌은 A1 단계에만 새 흐름을 적용하도록 수정했다.

기존 이력 뷰와 구형 회귀 검사 충돌에 대한 후속 검토는 [NB-R05](../../../ideas/md/v04/issues/validation/notebook_history_review_plan.md#nb-r05--p1검증-차단--기존-회귀-테스트가-새-구조와-충돌)를 참조한다.

기존 프롤로그 검사는 새 취침·아침 선택 흐름에 맞춰 갱신했다. NP01·NP02·NP03 생산자 검사에서는 이전 취침 선택지와 대사 정의도 별도 호환성 경로로 실제 표시한다. EP01 생산자에 대한 검증은 `ep01_sheet_smoke.gd`가 담당한다.

| 검증 | 최종 결과 |
| --- | --- |
| 생성 데이터 재현 검사 | 529 / 135 / 152 / 33개 일치 |
| EP01 대사·실제 진행·실패 후 재시도·첫 취침 | PASS |
| 기존 프롤로그 씬 | 265개 검사 PASS |
| NP01·NP02·NP03 원본·번역 조합 | 232 / 232개, 누락·미등록 0개, PASS |
| 별도 프로세스의 저장 화면 생성 / 복원 / 완료 | 66 / 26 / 16개 검사 PASS |
| 인증된 Google Sheets 최종 재조회 | 4개 표의 CellData가 반영 스냅샷과 동일 |

검증 ID는 `GGB-QA-EP01-SHEET-SYNC-2026-10-27`이다. 당시 로컬 `output/ep01-godot-sync/verification-final.json`에 원본·구현·로그 해시와 결과를 보관했다. Godot 4.7.2 stable Steam에서 실행했으며 검증 프로젝트의 소스가 당시 최종 후보와 일치함을 확인했다. 원본 시트 해시는 `19e17ce7db2fcba8ccbbf669347e93193fbc62c25dbaf053090a6acf4b970021`이다.

시트에 별도 대사가 없는 제외 슬롯 오류는 기존의 정확한 약한 시험 진단과 원본의 공통 실패 대사를 사용한다. 다른 역할의 오류 대사를 임의로 대신 표시하지 않는다. 잠든 뒤의 준비 단축, 위상 재입력, 성공 신호와 파형 기록, J2 복원까지 실제 Session·Controller로 검사했다.

## 확정한 재생 순서

2026-10-27 사용자가 첫 취침부터 반영하고 미번역 대사는 한국어로 표시하도록 승인했다. 첫 취침 확인 후 원본의 종·기억·리셋 대사를 표시하고, 실제 리셋이 끝난 다음 새 첫 아침 대사와 세 답변을 표시한다. 아침 답변이 끝나야 챕터 인계를 완료한다.

A1 표식 작성은 다음 날의 흔적을 묘사하는 독백 직전에서 멈춘다. 다음 아침에는 표식을 확인하는 원문, `EP01_A1_REACTION_001`부터 이어지는 독백, A2의 확인 대사와 선택지 순서로 표시한다. 한국어 원문은 재작성하지 않았다.
