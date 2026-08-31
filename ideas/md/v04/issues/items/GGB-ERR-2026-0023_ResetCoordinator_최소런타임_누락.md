# GGB-ERR-2026-0023: ResetCoordinator 최소 런타임 누락

> [충돌·오류 관리](../README.md) / [운영 레지스트리](../충돌오류_레지스트리.md)

| 필드 | 값 |
| --- | --- |
| 심각도 | 높음 |
| 상태 | VERIFIED |
| 작업 상태 | DONE |
| 우선순위 | P1 |
| 담당자 | `beru` |
| 목표 마일스톤 | `TECH_01_FOUNDATION` |
| 영역 | NORMAL_RESET·BROKEN_RESET·중단 복구 |
| 기준 문서 | [문서 02](../../02_루프_관계_기억_색상서명시스템.md), [문서 17](../../17_상태변수_이벤트ID_Godot데이터구조.md), [`docs/milestones.md`](../../../../../docs/milestones.md) |
| 영향 파일 | `game/scripts/systems/reset_coordinator.gd`, [`game/scripts/autoload/game_state.gd`](../../../../../game/scripts/autoload/game_state.gd), [`game/scripts/autoload/save_manager.gd`](../../../../../game/scripts/autoload/save_manager.gd) |
| 예정 검증 ID | `QA-ERR-0023-NORMAL`, `QA-ERR-0023-BROKEN`, `QA-ERR-0023-CRASH` |

## 문제

`GameState`에는 `reset_state` 기본 필드가 있지만 이를 단계적으로 실행하는 `ResetCoordinator`가 없다. `TECH_01_FOUNDATION` 완료 계약은 이 최소 인터페이스를 요구하며, 현재 코드로는 첫 수면의 NORMAL_RESET, D5 이후 단발 BROKEN_RESET, 중간 종료 뒤 멱등 재개를 구현할 공통 경로가 없다.

이 상태에서 사건별로 리셋 코드를 따로 만들면 영구 정보가 지워지거나 사용인 잔류 기억이 중복 적용되고, 물리 상태 폐기 전에 기억 효과가 확정되는 순서 오류가 다시 생길 수 있다.

## 권장 해결안

1. autoload가 아닌 일반 시스템 `ResetCoordinator`를 만들고 `reset_state.phase`를 단계별로 전진시킨다.
2. NORMAL_RESET은 `SYS_COMMIT → SYS_MEMORY → 물리 상태 폐기 → 아침 재구성 → 안전 저장` 순서를 사용한다.
3. BROKEN_RESET은 D5 뒤 최초 1회만 허용하고 이후 수면은 `POST_BROKEN_REST`로 분리한다.
4. `transaction_id`와 `last_completed_transaction_id`로 각 단계를 멱등 처리한다.
5. 각 단계 직후 강제 종료 fixture를 두고 동일 결과로 복구되는지 검사한다.

## 완료 조건

- [x] NORMAL_RESET이 영구 정보·관계·대화 기록을 보존하고 루프 물리 상태만 초기화한다.
- [x] BROKEN_RESET은 한 번만 발생하고 위장 필터·세계 단계가 원자적으로 전환된다.
- [x] 어느 단계에서 종료해도 보상·기억·일지 효과가 중복되지 않는다.
- [x] 완료 뒤 `reset_state.phase=idle`과 최신 완료 transaction이 저장된다.

## 해결 내용

```yaml
resolved_in:
  - game/scripts/autoload/game_state.gd
  - game/scripts/systems/reset_coordinator.gd
  - game/scripts/systems/load_coordinator.gd
  - game/scripts/tests/foundation_runtime_regression.gd
resolution_summary: sleep_confirmed부터 complete·idle까지 각 단계를 전체 snapshot 원자 커밋과 안전 저장으로 확정하며 NORMAL·BROKEN을 분리하고 transaction ID로 재개한다.
verification_ids:
  - QA-ERR-0023-NORMAL
  - QA-ERR-0023-BROKEN
  - QA-ERR-0023-CRASH
verification_state: PASS
verified_on: 2026-08-30
```

NORMAL과 BROKEN 각각 일곱 중단 phase를 저장한 뒤 `GameState`를 초기화하고 다시 로드해 최종 `idle`까지 재개했다. 총 14개 중단 경로에서 영구 상태 동등성, 루프 물리 폐기, BROKEN 단발 S3 전환과 후속 `POST_BROKEN_REST` 라우팅을 확인했다.

## 검증 계획

| 검증 ID | 검사 | 기대 결과 |
| --- | --- | --- |
| `QA-ERR-0023-NORMAL` | 정상 수면 리셋 | 영구 보존·물리 초기화·같은 아침 재구성 |
| `QA-ERR-0023-BROKEN` | D5 뒤 첫 수면과 후속 휴식 | BROKEN 1회, 이후 물리 보존 |
| `QA-ERR-0023-CRASH` | 단계별 강제 종료 | 재실행 결과 동등, 중복 효과 0건 |

## 변경 이력

| 날짜 | 주체 | 내용 | 상태 |
| --- | --- | --- | --- |
| 2026-08-30 | `Codex` | 기술 기반선 계약과 실제 코드 대조에서 ResetCoordinator 부재를 등록 | OPEN · READY |
| 2026-08-30 | `Codex` | 단계형 reset transaction·단계별 저장·14개 중단 재개 fixture를 구현하고 Godot 4.7.2 실기 통과 | VERIFIED · DONE |
