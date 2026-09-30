# GGB-ERR-2026-0022: 저장 로드 snapshot·GameState 복원 경로 누락

> [충돌·오류 관리](../README.md) / [운영 레지스트리](../충돌오류_레지스트리.md)

| 필드 | 값 |
| --- | --- |
| 심각도 | 높음 |
| 상태 | VERIFIED |
| 작업 상태 | DONE |
| 우선순위 | P1 |
| 담당자 | `beru` |
| 목표 마일스톤 | `TECH_01_FOUNDATION` |
| 영역 | 저장 불러오기·상태 복원·안전 재개점 |
| 기준 문서 | [`docs/data_contract.md`](../../../../../docs/data_contract.md), [문서 17](../../17_상태변수_이벤트ID_Godot데이터구조.md) |
| 영향 파일 | [`game/scripts/autoload/save_manager.gd`](../../../../../game/scripts/autoload/save_manager.gd), [`game/scripts/autoload/game_state.gd`](../../../../../game/scripts/autoload/game_state.gd), `game/scripts/systems/` |
| 예정 검증 ID | `QA-ERR-0022-INSTALL`, `QA-ERR-0022-RESUME`, `QA-ERR-0022-RECOVERY` |

## 문제

`SaveManager.load_slot()`은 checksum·schema를 검사한 snapshot을 반환하지만 이를 `StateWriter`의 전체 schema 검증 뒤 `GameState`에 설치하는 경로가 없다. production bootstrap도 기존 슬롯을 조회하거나 `save_point_id`를 안전한 사건 재개 노드로 해석하지 않는다.

현재 smoke는 저장 직후 반환 snapshot의 동등성만 증명한다. 프로세스를 종료하고 다시 실행하면 저장 파일은 남아 있어도 실제 플레이 상태를 복원해 계속할 수 없다.

## 권장 해결안

1. 일반 시스템 `LoadCoordinator`를 만들고 `SaveManager → schema validator → StateWriter → GameState` 순서만 허용한다.
2. 전체 snapshot 루트·타입·논리 집합·불변식을 검사한 뒤 한 revision으로 설치한다.
3. `save_point_id`와 `content_boundary_id`를 저장 지점 registry에서 안전한 resume event·node로 해석한다.
4. primary 손상 시 backup snapshot을 설치하고 복구 출처를 UI와 로그에 전달한다.
5. future schema는 원본 파일을 보존한 채 설치하지 않고 호환 불가 화면으로 보낸다.

## 완료 조건

- [x] 새 프로세스에서 정상 슬롯을 불러오면 저장 직전의 영구·루프·파열 상태가 동등하다.
- [x] 일부 루트만 적용되는 중간 상태가 존재하지 않는다.
- [x] 손상 primary는 backup을 설치하고 복구 사실을 표시한다.
- [x] future schema와 허용되지 않은 build flavor·boundary는 GameState를 변경하지 않는다.
- [x] 모든 save point가 등록된 안전 resume node를 가진다.

## 해결 내용

```yaml
resolved_in:
  - game/scripts/systems/state_snapshot_validator.gd
  - game/scripts/systems/state_writer.gd
  - game/scripts/systems/load_coordinator.gd
  - game/data/registries/save_point_registry.json
  - game/scripts/tests/foundation_runtime_regression.gd
resolution_summary: 전체 snapshot을 schema·논리 집합·교차 루트 불변식 검사 뒤 한 revision으로 설치하고, 저장 지점 registry와 진행 중 reset phase를 안전 재개 event·node로 해석한다.
verification_ids:
  - QA-ERR-0022-INSTALL
  - QA-ERR-0022-RESUME
  - QA-ERR-0022-RECOVERY
verification_state: PASS
verified_on: 2026-08-30
```

Godot JSON 숫자는 로드 경계에서 런타임 정수 타입으로 정규화한다. primary 손상 복구 여부는 `recovered=true`, 설치 출처는 `source=backup`으로 호출자에게 반환하며 future schema와 등록되지 않은 경계는 설치 전에 거부한다.

## 검증 계획

| 검증 ID | 검사 | 기대 결과 |
| --- | --- | --- |
| `QA-ERR-0022-INSTALL` | 정상 snapshot 전체 설치 | revision 1회 증가, 모든 루트 동등 |
| `QA-ERR-0022-RESUME` | 각 save point 재시작 | 지정된 안전 사건·노드에서 재개 |
| `QA-ERR-0022-RECOVERY` | primary 손상·future schema | backup만 설치, future는 원본 보존·거부 |

## 변경 이력

| 날짜 | 주체 | 내용 | 상태 |
| --- | --- | --- | --- |
| 2026-08-30 | `Codex` | 최소 저장 smoke 완료 뒤 실제 GameState 설치·안전 재개 경로 부재를 독립 오류로 등록 | OPEN · READY |
| 2026-08-30 | `Codex` | 전체 snapshot 검증·원자 설치·save point registry·backup/future schema 회귀 fixture 구현 및 Godot 4.7.2 실기 통과 | VERIFIED · DONE |
