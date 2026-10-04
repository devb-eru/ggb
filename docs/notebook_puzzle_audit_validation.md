# 거울·지하 관찰 범위와 확인창 취소 검증

기준: 2026-10-04, develop `d3a1e4a`. 생산자 재감사의 PA04와 PA05 지하 확인창을 대상으로 한다. 게임 퍼즐 정답·진행·관계·저장 동작은 변경하지 않으며, 테스트와 디버그 실행 진입점만 보완한다.

## 1. 기존 판정의 문제

- `notebook_mirror_smoke.gd`와 `notebook_basement_smoke.gd`는 각각 NP07/NP08의 전체 ID를 요구했지만, 후속 추가된 화면 표면은 `notebook_puzzle_surfaces_smoke.gd`가 실행한다. 원 경로 테스트의 ID 경고만으로 제품의 기록 누락이라고 결론 낼 수 없었다.
- 지하 확인창의 취소는 실제 취소 선택의 관찰과 완료된 `NOTEBOOK_PRESENTATION`을 저장한다. 기존 `loop_state` 전체 동일 단언은 정상 커서 변경까지 실패로 판정했다.
- 정상 수첩 열기 선택에서는 snapshot 전체 차이가 없었다. 취소와 수첩 탐색을 같은 허용 조건으로 묶지 않는다.

기존 패키지 `96D9E0EE9AEBD5484561B1419560067786FA6BA1E24B6E430A45D2E324363927`의 지하 검사를 먼저 다시 실행해 실패를 재현했다. 이어 진단 출력만 추가한 패키지에서 두 언어의 모든 비확정 선택과 응답 유실 취소를 검사했다. 차이는 대화 기록의 append/순번 및 표시 커서뿐이었다. 이 두 실행은 실패 결과로 보존하며 아래 PASS와 합치지 않는다.

로그: `%TEMP%/ggb-basement-audit-baseline-20261004/`, `%TEMP%/ggb-basement-audit-diagnostic-20261004/`.

## 2. 카탈로그 소유권과 합집합

`notebook_puzzle_coverage.gd`는 `CONTENT.CATALOGS`의 모든 버전을 읽어 NP07/NP08 정의를 검사한다. 각 필수 키는 `[content_id, content_version, action_or_variant, segment_id, locale]`다.

| 정의 출처 | 실행 소유 검사 | 고유 ID | 한영 필수 키 |
| --- | --- | ---: | ---: |
| `mirror_v1.json` | `mirror` | 64 | 192 |
| `basement_v1.json` | `basement` | 56 | 164 |
| `puzzle_surfaces_v1.json` | `puzzle-surfaces` | 53 | 136 |
| 합계 | 세 검사 합집합 | 173 | 492 |

소유권은 단순 `NB_PUZZLE_` 접두사 제외가 아니라 카탈로그 소속으로 정한다. 세 검사에서 실제 저장된 authored 관찰만 수집하고, 해당 버전의 출처·분기·문장·언어 및 원고 재표시 유효성을 확인한다. 다른 검사에서 우연히 보인 표면을 담당 검사의 실행 근거로 대체하지 않는다.

`notebook_puzzle_audit_smoke.gd`는 세 시나리오를 순차 실행한다. 개별 검사 오류, 미등록 관찰, 누락된 필수 키, 잘못된 소유권 중 하나라도 있으면 실패한다. 각 소유 검사에서 문장 키를 삭제하거나 다른 소유자에게 이동시키는 반례 여섯 개를 모두 거부했다. 기존 퍼즐 화면의 9,556개 descriptor/JSON 왕복 행렬 검사도 유지한다.

이 합집합은 카탈로그에 등록된 버전·분기·문장·언어의 실제 관찰 범위를 증명한다. 9,556개 모든 변수 조합을 실제 마우스 입력으로 실행했다는 뜻은 아니다. 개별 mirror/basement 검사만 PASS해도 전체 표면 인수가 끝난 것으로 집계하지 않는다.

## 3. 지하 확인창의 엄격한 불변 조건

대상은 세 축의 누름 확인, 중앙축 양 방향 확인, 보조 레버 확인이다.

1. 수첩 열기와 복귀는 전체 snapshot 동일과 원래 확인창 복귀를 요구한다. 관찰·커서·기계 입력을 추가하지 않는다.
2. 취소는 원래 관찰 기록을 그대로 보존하고, 지정된 취소 대사 한 개와 정확한 순번 증가만 허용한다. 응답 유실 재시도는 아직 기록하지 못한 질문과 취소를 각각 한 번만 허용한다.
3. 새 관찰은 원 확인창과 같은 occurrence/conversation에 속해야 하며 실제 원고로 검증되어야 한다. 그 뒤 현재 분기·문맥에 속한 유효한 완료 모달 커서 하나만 분리하여 나머지 snapshot 전체를 비교한다.
4. 저장 거부 시 전체 snapshot 불변·입력 차단, 로드 전 콜백 거부, D4 원자 저장·응답 유실 검사를 유지한다.

한영 각 7회, 총 14회 정상 취소 비교에서 예상 밖 차이는 없었다. 한영 각각 기존 7종 게임 상태/커서 변조와 추가 5종 기록 변조(추가 항목, 순번, 출처, 분기 원고, 기존 기록/원본 식별)를 거부했다. 수량 보조창의 별도 불변 및 7종 반례 검사도 두 언어에서 유지했다. 이는 임의의 대화 기록 증가나 전체 loop 변경을 허용하도록 검사를 약화한 것이 아니다.

## 4. 실행 결과

- Windows Godot 4.7.2 headless, 별도 APPDATA/LOCALAPPDATA 및 빈 실행 디렉터리.
- 최종 PCK SHA-256: `B208E085D890969D7A0A6FF7769E358EB0AF83A4E0D2F28FAF5CA3E2EEE4A668`.
- 로그: `%TEMP%/ggb-puzzle-audit-20261004/`.
- import 20.4초, export 8.1초, 통합 실행 158.3초. 종료 코드 0과 `NOTEBOOK_PUZZLE_AUDIT_SMOKE: PASS`를 함께 확인했다.
- 실행 인자: `--headless --path <empty> --main-pack <pck> -- --notebook-puzzle-audit-smoke --ggb-dev-notebook-v2`.
- 세 소유 검사 모두 PASS, 실제 필수 키 192 + 164 + 136 = 492, 누락 0. 퍼즐 화면 실제 ID·언어 106개 / 문장·언어 136개, descriptor 행렬 9,556개.
- 공통 Windows 루트 인증서 저장소 경고는 남아 있다. 스크립트·파싱·컴파일·리소스 오류는 없었다.

## 5. 범위 밖과 다음 인수

PA04와 PA05 지하 확인창의 검사 계약은 위 범위에서 해결했다. 전체 목표는 계속 `IN_PROGRESS`다.

- PA06 에드가·마라 2의 실제 표면/미룸 검사와 기존 실행 제한 종료를 해결해야 한다.
- 최신 지하 전체 v2 회귀는 이번 실행에 포함하지 않았다. `notebook-basement`는 `basement-session` 전체 회귀의 대체가 아니다.
- 22개 생산자의 전체 필수·반복·최초 공개·공개 ID 감사, 나머지 조사·탐색 계약 검토가 남아 있다.
- PA09 전 장소 실제 입력 검토와 Windows 마우스·키보드·IME·시각/성능 인수는 별도다. 기본 비활성 rollout을 변경하지 않는다.

관련: [생산자 재감사](notebook_producer_audit_validation.md), [전체 구현 현황](../ideas/md/v04/issues/validation/notebook_history_implementation_status.md).
