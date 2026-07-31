# GGB-ERR-2026-0015: J4 확인창 placeholder 계약 누락

> [충돌·오류 관리](../README.md) / [운영 레지스트리](../충돌오류_레지스트리.md)

| 필드 | 값 |
| --- | --- |
| 심각도 | 중간 |
| 상태 | VERIFIED |
| 작업 상태 | DONE |
| 우선순위 | P1 |
| 담당자 | `Codex` |
| 목표 마일스톤 | `TECH_01_FOUNDATION` |
| 영역 | J4 비가역 경계·현지화·접근성 |
| 기준 문서 | [09 정보·일지](../../09_이벤트상세_04_정보조사_일지복원.md), [13 파열·결산](../../13_이벤트상세_08_파열_전환_결산.md) |
| 영향 문서 | `09`, `13`, `docs/localization.md` |
| 검증 ID | `QA-ERR-0015-TOKENS`, `QA-ERR-0015-ZERO`, `QA-ERR-0015-A11Y` |

## 문제

미완료 관계 사건을 영구 종료하는 J4 확인창이 `N개`, `N~N분` 같은 비의미 placeholder를 사용했다. 값의 계산 원천, 0건 표시와 현지화 token 이름이 없어 잘못된 수량이나 원문 잔존이 발생할 수 있었다.

## 채택 해결안

- 의미 token 다섯 개를 사용한다: `completed_relation_count`, `remaining_relation_count`, `remaining_relation_list`, `remaining_minutes_min/max`, `researcher_record_count`.
- 시간 범위는 문서 12의 미완료 E3 목표 시간을 합산한다.
- 에드가 E3_4M은 대체 안내로 분리한다.
- 0건은 `없음`, `남은 선택 사건 없음`으로 표시한다.
- 목록은 색만 쓰지 않고 문양과 화면명을 병행한다.

## 해결 증거

```yaml
resolved_in:
  - 09_이벤트상세_04_정보조사_일지복원.md §17.1
  - 13_이벤트상세_08_파열_전환_결산.md §10.2
resolution_summary: J4 확인창의 수량·시간·목록 token과 0건 처리 규칙을 정의했다.
verification_ids: [QA-ERR-0015-TOKENS, QA-ERR-0015-ZERO, QA-ERR-0015-A11Y]
verified_on: 2026-07-31
```

## 검증 결과

| 검증 ID | 검사 | 기대 결과 | 결과 |
| --- | --- | --- | --- |
| `QA-ERR-0015-TOKENS` | J4 확인창 검색 | 익명 `N` 대신 의미 token 사용 | PASS |
| `QA-ERR-0015-ZERO` | 관계 5명 완료 | `0~0분` 대신 남은 사건 없음 표시 | PASS |
| `QA-ERR-0015-A11Y` | 색 제거 모드 | 문양·화면명 목록으로 식별 가능 | PASS |

## 회귀 방지 규칙

플레이어 노출 문자열의 동적 값은 의미 있는 영어 snake_case token으로 선언하고 0·1·복수 표시를 함께 정의한다.

