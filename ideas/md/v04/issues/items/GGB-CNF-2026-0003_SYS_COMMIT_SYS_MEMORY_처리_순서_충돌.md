# GGB-CNF-2026-0003: SYS_COMMIT·SYS_MEMORY 처리 순서 충돌

> [충돌·오류 관리](../README.md) / [운영 레지스트리](../충돌오류_레지스트리.md)

| 필드 | 값 |
| --- | --- |
| 심각도 | 높음 |
| 상태 | VERIFIED |
| 작업 상태 | DONE |
| 우선순위 | P1 |
| 담당자 | `beru` |
| 목표 마일스톤 | `M1_V04_PLANNING_BASELINE` |
| 관련 결정 | [GGB-DEC-2026-0001](../../../../../docs/decisions/GGB-DEC-2026-0001_정상_리셋_처리_순서.md) |
| 차단 해제 근거 | `GGB-DEC-2026-0001` ACCEPTED, 2026-07-18 |
| 영역 | 정상 리셋 트랜잭션 |
| 기준 문서 | [07 루프·영구 정보·숏컷](../../07_이벤트상세_02_루프_영구정보_숏컷.md) |
| 영향 문서 | [02 루프 시스템](../../02_루프_관계_기억_색상서명시스템.md), [17 Godot 데이터 구조](../../17_상태변수_이벤트ID_Godot데이터구조.md) |
| 해결 담당 영역 | 저장·복구 |
| 검증 ID | `QA-CNF-0003-ORDER`, `QA-CNF-0003-CRASH` |

## 문제

`02`는 사용인 기억 압축 뒤 영구 상태를 커밋한다. `07`의 공식 체인은 다음 순서다.

```text
NORMAL_SLEEP
→ SYS_COMMIT
→ SYS_MEMORY
→ NORMAL_RESET
→ MORNING
→ ROUTE
```

## 권장 해결

`07`을 정본으로 채택하고 두 커밋 성공 뒤에만 물리 상태를 폐기한다.

## 해결 체크리스트

- [x] `02` 처리 순서 교정.
- [x] `17`에 단계별 재개 상태 추가.
- [x] 동일 transaction ID의 중복 적용 방지.
- [x] SYS_COMMIT·SYS_MEMORY 각각의 실패 복구 검증.

## 해결 증거

```yaml
resolved_in:
  - 02_루프_관계_기억_색상서명시스템.md §4, §7.2~7.3
  - 17_상태변수_이벤트ID_Godot데이터구조.md §11
resolution_summary: "정상 리셋을 SYS_COMMIT → SYS_MEMORY → NORMAL_RESET 순으로 통일하고, 두 커밋 완료 전 물리 상태 폐기를 금지했다."
verification_ids:
  - QA-CNF-0003-ORDER
  - QA-CNF-0003-CRASH
verified_on: 2026-07-18
```

## 변경 이력

| 날짜 | 이전 상태 | 새 상태 | 변경 문서 | 근거 |
| --- | --- | --- | --- | --- |
| - | - | OPEN | - | 최초 개별 파일 분리 |
| 2026-07-18 | OPEN·BLOCKED | OPEN·READY | - | `GGB-DEC-2026-0001` 권장안 A 승인 |
| 2026-07-18 | OPEN·READY | IN_PROGRESS | `02`, `17` | 영향 문서 동기화 착수 |
| 2026-07-18 | IN_PROGRESS | RESOLVED | `02`, `17` | 순서·폐기 장벽·재개 계약 반영 |
| 2026-07-18 | RESOLVED | VERIFIED·DONE | `02`, `17` | `QA-CNF-0003-ORDER`, `QA-CNF-0003-CRASH` 통과 |
