# GGB-ERR-2026-0005: all_servants_complete 캐시 갱신 규칙 누락

> [충돌·오류 관리](../README.md) / [운영 레지스트리](../충돌오류_레지스트리.md)

| 필드 | 값 |
| --- | --- |
| 심각도 | 중간 |
| 상태 | VERIFIED |
| 작업 상태 | DONE |
| 우선순위 | P1 |
| 담당자 | `beru` |
| 목표 마일스톤 | `M1_V04_PLANNING_BASELINE` |
| 영역 | 파생 상태·결산 |
| 발생 문서 | [17 Godot 데이터](../../17_상태변수_이벤트ID_Godot데이터구조.md) |
| 선행 항목 | `GGB-CNF-2026-0004` |
| 검증 ID | `QA-ERR-0005-LIVE`, `QA-ERR-0005-LOAD` |

## 문제

`all_servants_complete`는 로드 시 재계산 후 캐시한다고만 정의되어 있다. 플레이 중 마지막 E3 이벤트를 완료하면 캐시가 갱신되지 않을 수 있다.

## 권장 해결

- 저장값이 아닌 계산 프로퍼티로 사용하거나,
- E3_1~E3_5 변경 신호에서 즉시 재계산한다.

## 해결 체크리스트

- [x] 4명→5명 완료 즉시 ALL 판정 확인.
- [x] 저장·로드 후 동일 값 확인.
- [x] 완료 플래그 롤백 시 false로 복원 확인.

## 해결 증거

```yaml
resolved_in:
  - 17_상태변수_이벤트ID_Godot데이터구조.md §8~9
resolution_summary: "all_servants_complete를 비저장·비캐시 읽기 전용 계산 프로퍼티로 정의해 E3 완료 플래그의 현재값을 항상 반영한다."
verification_ids:
  - QA-ERR-0005-LIVE
  - QA-ERR-0005-LOAD
verified_on: 2026-07-18
```

## 변경 이력

| 날짜 | 이전 상태 | 새 상태 | 변경 문서 | 근거 |
| --- | --- | --- | --- | --- |
| - | - | OPEN | - | 최초 개별 파일 분리 |
| 2026-07-18 | OPEN·BLOCKED | IN_PROGRESS | `17` | `GGB-CNF-2026-0004` 해결로 선행 차단 해제 |
| 2026-07-18 | IN_PROGRESS | RESOLVED | `17` | 저장·캐시 없는 계산 프로퍼티 계약 반영 |
| 2026-07-18 | RESOLVED | VERIFIED·DONE | `17` | `QA-ERR-0005-LIVE`, `QA-ERR-0005-LOAD` 통과 |
