# GGB-ERR-2026-0039: progress 미래 임시 파일 덮어쓰기

| 항목 | 값 |
| --- | --- |
| 유형 | 오류 ERR |
| 심각도 | 높음 |
| 해결 상태 | VERIFIED |
| 작업 상태 | DONE |
| 우선순위 | P1 |
| 담당자 | `Codex` |
| 목표 마일스톤 | `FULL_00_CONTENT_COMPLETE` |
| 최초 확인 | 2026-10-05 |
| 영역 | SaveManager.save_snapshot, load_slot 백업 복구 |
| 기준 | [수첩 계획](../validation/notebook_history_review_plan.md) 15절 |

## 원인과 수정

기준 develop `1223290`. 일반 저장은 main/bak의 미래 형식을 거부하지만 `progress.tmp.json`을 확인하지 않고 WRITE로 연다. 구형 main의 자동 이관과 bak 복구도 같은 쓰기 경로에 도달한다. 복구는 저장 전에 main을 교체하기 때문에 쓰기 함수만 막으면 원본 main까지 보존하지 못한다. F3 capture를 다룬 ERR-0037과 별도 경로다.

- `save_snapshot`에서 기존 tmp의 미래 형식을 첫 파일 쓰기 전에 거부한다.
- `load_slot`의 bak 복구에서도 main 제거/복사 전에 같은 임시 후보를 검사한다.
- 정상적으로 확정된 신형 main은 미래 tmp가 있어도 읽을 수 있다. tmp를 읽기 후보로 승격하거나 삭제하지 않는다.
- 미래 envelope·대화 기록·지식 원장 모두 기존 `ERR_SAVE_FUTURE_SCHEMA`로 거부한다. 임의 버전 강등이나 본문 추정은 하지 않는다.

## 재현·검증

`notebook_migration_smoke._validate_progress_future_temporary`에서 저장/구형 이관/백업 복구 × 미래 envelope/기록/원장의 아홉 fixture를 실행했다.

- 수정 전: 아홉 fixture 모두 거부하지 않았고, main/tmp가 변경됐다. 복구 세 조건은 bak도 변경됐다. 총 30개 단언 실패.
- 수정 후: 정확한 오류와 main/bak/tmp의 바이트 불변을 모두 확인했다.
- 각 fixture에서 확정 신형 main으로 바꾼 뒤 읽기 성공·정확한 snapshot·미래 tmp 보존도 확인했다. 테스트 전용 슬롯 외 사용자 저장은 사용하지 않았다.
- Godot 4.7.2, 격리 APPDATA, headless PCK: import 39.3초, export 11.1초, migration 21.5초 PASS(저장 안전성 138개 포함). 재선택 복원 366개 60.4초, 기본 모드 크레딧·재선택 집중 242개 16.1초 PASS. 모든 프로세스 종료 0. 기존 인증서 저장소 경고 외 SCRIPT/파싱 오류 없음.
- 명령: `--notebook-migration-smoke --ggb-dev-notebook-v2`, `--notebook-reselect-presentation-smoke --ggb-dev-notebook-v2`, `--basement-session-smoke --basement-credits-regression-only`. 마지막은 전체 캠페인 회귀가 아니다.

| 원자료 | SHA-256 |
| --- | --- |
| `%TEMP%/ggb-progress-future-baseline-20261005/notebook.pck` | `9C20A23513725C59B06F7E7B1466E0E3E5214A96F24289EBCC9B6E52D203D7D5` |
| 같은 폴더의 `migration.out.log` | `BC9F3D2E321EB7ACA8109F44EF46A9199E6CF200681980FF739F5BE4CB72CB0D` |
| `%TEMP%/ggb-progress-future-fixed-20261005/notebook.pck` | `BD234D3D8A29EC7AD5FE62FD9EC74AB7A706CC9BB06F60BA343D77A823AA89B7` |
| 같은 폴더의 `migration.out.log` | `A30987C36F9B9B802BBF307346C4D43105181CDF904852FFF97D6F0B558D2A47` |

## 잔여 범위

[저장 입구 대조표](../validation/notebook_history_save_entry_matrix.md)의 다른 형식·design revision·실제 공간 부족·동시 외부 쓰기·전원 차단은 이 수정으로 검증되지 않는다. 전체 목표는 진행 중이고 기본 rollout OFF를 유지한다.
