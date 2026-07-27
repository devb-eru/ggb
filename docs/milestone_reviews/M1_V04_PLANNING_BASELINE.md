# M1 v0.4 기획 기준선 검토 기록

## 1. 검토 대상

| 필드 | 값 |
| --- | --- |
| 마일스톤 | `M1_V04_PLANNING_BASELINE` |
| 상태 | `REVIEW` |
| 기준선 후보 | `develop → main` PR 전체 변경, 검토 시작점 `c08bb3c` |
| 검토 시작일 | 2026-07-27 |
| 승인 책임자 | `beru` |
| 최종 검토 | `gatam`, `niik` |
| 병합 결과 | [PR #14](https://github.com/devb-eru/ggb/pull/14), merge commit `a219c16` |

검토 범위는 `ideas/md/v04/README.md`, `00~18` 기획 문서, 개별 충돌·오류 25건, 구현 데이터 계약과 운영 기준 문서다.

## 2. 완료 조건 판정

| 완료 조건 | 근거 | 결과 |
| --- | --- | --- |
| 열린 `GGB-CNF/ERR` 정리 | CNF 12건·ERR 13건 모두 `VERIFIED/DONE` | PASS |
| `00~18`과 v0.4 README 동기화 | `QA-GDD-HANDOFF-*`, `QA-ERR-0007-*` | PASS |
| 이벤트·상태·위치·관계 계약 일치 | 충돌·오류 레지스트리의 계약별 회귀 검사 | PASS |
| 구현 데이터 계약과 변경 범위 확정 | `docs/data_contract.md`, `docs/godot_conventions.md`, 문서 17 | PASS |
| 비차단 후속 작업 분리 | `GGB-WRK-2026-0001~0012` 실행 순서 | PASS |

## 3. 재검증 결과

| 검증 ID | 범위 | 결과 |
| --- | --- | --- |
| `QA-M1-STATIC` | v0.4·운영 Markdown 72개: UTF-8, 첫 H1, 코드 펜스, 상대 링크 | PASS, 오류 0건 |
| `QA-M1-ISSUES` | 개별 CNF·ERR 파일 상태와 작업 상태 | PASS, 25/25 `VERIFIED/DONE` |
| `QA-M1-LEGACY` | `00`, README, 문서 18의 구식 RESET·공간·결산 표기 | PASS, 운영 구식 표기 0건 |
| `QA-M1-DIFF` | `git diff --check` | PASS |

Mermaid는 텍스트 구조만 검사했다. 실제 렌더링은 구현 문서화 단계의 후속 검증으로 남기며 현재 기획 기준선을 차단하지 않는다.

## 4. 사람 검토

- `gatam`: 서사 흐름, 용어, 관계·엔딩 반응을 확인한다. GitHub 계정이 없으므로 Discord에서 검토하고 `beru`가 결과를 PR 댓글에 기록한다.
- `niik`: 이벤트 ID, 상태 전이, 저장 스키마, Godot 데이터 경계를 확인한다. GitHub 계정 `niik0203`으로 검토할 수 있다.
- `beru`: 요청된 수정이 모두 반영됐는지 확인하고 PR을 `main`에 병합한다.

| 검토자 | 상태 | 근거 |
| --- | --- | --- |
| `niik` | 완료 | `niik0203`이 PR #14 승인, 2026-07-27 |
| `gatam` | 기록 대기 | PR #14와 Issue에 Discord 검토 요약 없음 |
| `beru` | 병합 완료 | PR #14를 `main`에 병합 |

검토 중 새 충돌이나 오류가 발견되면 기존 원인의 이슈를 다시 열거나 새 ID를 발급한다. 차단 문제가 없고 두 영역 검토가 끝나면 마일스톤을 `COMPLETE`로 전환한다.

## 5. 병합 뒤 다음 작업

1. 마일스톤 상태를 `COMPLETE`로 갱신한다.
2. `GGB-WRK-2026-0001` GitHub Issue·Project 기반선을 시작한다.
3. GitHub Project #1을 작업 상태의 정본으로 전환한다.
4. Discord 알림·에셋 접수·회의 안건 자동화 작업을 선행 순서대로 진행한다.
