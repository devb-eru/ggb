# EP02 선택창 저장 경계 증거

기준 `f8aada719409238f6dd54a269c749c36df363ba4`, 검증 ID `NB-EP02-BOUNDARIES-20261105`.

## 실행 결과

아래 8회는 Godot 4.6.3 native headless 실행의 기존 영수증을 패키징한 것이다. **OS 실제 입력 8회가 아니며**, 이번 감사에서 게임을 다시 실행한 것도 아니다. 실제 UI 연결 callable 검사는 Windows 마우스/키보드 입력 전달의 증거가 아니다. 제품 엔진 4.7 기준과 rollout OFF는 변경하지 않는다.

| raw.zip 경로 | 검사 분모 | 결과 |
| --- | --- | --- |
| `scope/` | 한영 18조건, 2,298단언 | completed true, native 0, PASS |
| `boundaries/` | 한영 44조건, 692단언 | completed true, native 0, PASS |
| `regression/sheet.*` | 3,361 checks | completed true, native 0, PASS |
| `regression/ep01.*` | 557 source rows 및 관련 변형 | completed true, native 0, PASS |
| `regression/modal-seed.*` | 980 checks | completed true, native 0, PASS |
| `regression/modal-resume.*` | 7 checks | completed true, native 0, PASS |
| `regression/modal-completed.*` | 4 checks | completed true, native 0, PASS |
| `regression/campaign.*` | `FULL_CAMPAIGN_SMOKE: PASS` | completed true, native 0, PASS |

분모의 단위가 다르므로 합산하지 않는다. modal 세 실행은 별도 프로세스에서 같은 격리 modal 저장 디렉터리를 이어 사용한다. campaign smoke PASS를 전체 캠페인 OS 인수나 전체 수첩 계획 완료로 확대하지 않는다.

## 원자료와 지문

- `raw.zip`: 4,076,254 bytes, SHA-256 `dbfa1674527714bd4ddbab57780569e5e79e14fa3f959329929967294ab0453a`.
- `manifest.json`: 후보 310 GDScript와 63 data 파일의 경로/지문, 엔진 지문, raw 43파일의 경로/크기/지문, 아카이브 지문.
- 엔진 SHA-256: `ef90e929ba1a6a4322860285d97f40f4aa349c90329a91b0e8b55b8df0f4cb00`. 선언 지문이며 감사 시 외부 엔진 실행 파일을 재실행하거나 재해시하지 않는다.
- `baseline/`: 원래 제품 코드의 18조건·2,334단언, native 1, ok false. 실행 루트 `ggb-ep02-boundary-dc024116839049c4b88e16ca19fda907`, PID 39872. 실제 만료 retry callable이 snapshot/revision·슬롯 파일·교체 UI·공개 기록을 변경한 실패다.
- `scope/`: 수정 후보 PID 40096. 정상 원래 retry와 만료 callable 무효화를 대조한다.
- `boundaries/`: 수정 후보 PID 38112, `trace.json`의 실제 snapshot/disk 44쌍과 ACK 유실 트랜잭션 목록. 시작 언어별 22조건을 대조한다.
- baseline/scope/boundaries 각각 `run.json`, stdout/stderr, `runner.ps1`, `source_scripts.zip` 포함. 각 소스 ZIP의 310스크립트 지문을 대조하며 baseline과 후보 사이 변경은 `scripts/chapters/chapter_one_controller.gd` 하나다.
- `regression/`: 6회 영수증·stdout·stderr와 공통 runner. 모든 영수증의 source 목록은 후보와 같다. 회귀용 소스 ZIP 자체는 별도 중복 수록하지 않는다.
- `diagnostics/first-boundaries/`: 최초 42조건·607단언, native 1. 후속 표시 저장까지 무조건 ACK 유실 1회로 가정한 12단언 실패를 보존한다.
- `diagnostics/scope-parse/`: 최초 검사 타입 추론 오류, completed false, exit -1. 실행 본문에 진입하지 못한 시도이며 native 성공에 포함하지 않는다.

총 raw 43파일은 baseline 5, scope 5, boundaries 6, regression 19, diagnostics 8개다. raw 자료를 통과 결과로 다시 쓰지 않았다. 데이터 본문과 전체 프로젝트/에셋은 이 ZIP에 포함하지 않으므로 완전한 재실행 번들로 간주하지 않는다.

## 독립 감사

미러 루트에서 PowerShell 7로 실행한다. `RepoPath`는 검증 대상 후보 310스크립트·63데이터와 정확히 같은 지문이어야 한다.

```powershell
$mirror = 'C:/Users/beruo/.codex/worktrees/5b3e/ggb/.tmp-notebook-sheet-20261103'
$evidence = Join-Path $mirror 'ideas/md/v04/issues/validation/evidence/notebook-ep02-boundaries-20261105'
& (Join-Path $mirror 'scripts/audit_notebook_ep02_modal_boundaries.ps1') -EvidencePath $evidence -RepoPath $mirror
& (Join-Path $evidence 'verifier-negative-tests.ps1') -RepoPath $mirror
```

감사는 아카이브/개별 파일/9회 정식 영수증 로그의 지문, 현재 후보와 실행별 source 목록, baseline과 수정 후보의 결과 요약 및 native 종료 코드, 회귀 PASS marker와 오류 로그 부재를 확인한다. trace에서는 PID·한영 조건 집합·RAM/디스크 구조 동일성·ACK 유실 트랜잭션 중복 부재·선택한 답변만의 공개·실제 물리 상태·선택형 기억의 비물리적 성격을 별도로 대조한다. 이는 저장된 증거의 독립 대조이며 Godot 테스트 재실행은 아니다.

- `packaging-attempt-01.json`: 최초 패키징 후 감사 실패 보존. 검증기가 v2 선택 관찰 ID 대신 본문 ID `NB_EP02_C4_COMMIT_CH01..03`을 기대해 실패했다.
- 검증기를 실제 계약의 `NB_EP02_CHOICE_C4_COMMIT_SELECT_0..2` 및 `choice_confirmed` 대조로 수정했다. 게임 코드/데이터나 원자료는 변경하지 않았다.
- `audit-attempt-02.json`: ID 수정 후 PASS.
- `audit-attempt-03.json`: manifest 식별자·고유 source 분모·영수증 로그 해시·정확한 결과 분모 검사를 추가한 최종 검증기 PASS. 검증기 SHA-256 `ab4cab7d0ab80cf7d53681c399c65df6a86bccb2c8291c103e72ae656c40f057`.
- `verifier-negative-tests.ps1` / `.json`: 아카이브 해시, source 분모, raw 해시, 선택 관찰 오류, RAM/디스크 불일치의 5/5 거절 확인. 뒤의 두 fixture는 JSON과 ZIP 지문을 재생성해 단순 해시 오류가 아닌 의미 검사가 거절했음을 확인했다. 원본 raw.zip은 그대로 두고 임시 복사본만 변경한다.
- `final-check-attempt-01.json`: 추가 문법 검사 명령이 이미 절대 경로인 파일에 루트를 다시 붙여 FileReadError가 난 이력을 보존했다. 감사 자체는 먼저 PASS했으며, 검사 명령의 경로 해석만 `Resolve-Path`로 보완했다.
- `final-checks.json`: 최종 감사 재실행 PASS, 스크립트 2개 문법 오류 0, 문서 링크 3개 유효, 변조 거절 5/5 및 raw.zip 지문 불변 확인.

## Delivery Pending

- 최신 후보의 실제 Windows 입력과 수면 경로, 전체 T12 및 수첩 계획 전체 인수는 미완료다.
- 선택형 기억 EFF46 저장 경계와 복원 완료 EFF49 retry 수명 검사는 별도 범위다. async writer opt-in, 모든 서비스/owner 경계의 수명, 모든 경로의 프로세스 재시작을 인수한 것이 아니다.
- 별도로 진행 중인 최신 레이아웃 변경은 이 지문으로 검증했다고 주장하지 않는다. 후보 지문이 바뀌면 새 증거로 다시 판정해야 한다.
- 실제 저장소 접근/수정, develop 전달, commit/push, registry/TODO/main README 동기화는 수행하지 않았다. 메인 담당의 별도 작업이며 이 패키지의 검증 PASS와 구분한다.
