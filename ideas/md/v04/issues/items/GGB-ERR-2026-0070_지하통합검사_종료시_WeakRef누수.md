# GGB-ERR-2026-0070: 지하 통합 검사 종료 시 WeakRef 누수

| 항목 | 값 |
| --- | --- |
| 유형 | 오류 ERR |
| 심각도 | 낮음 |
| 해결 상태 | OPEN |
| 작업 상태 | READY |
| 우선순위 | P2 |
| 담당자 | Codex |
| 목표 마일스톤 | `FULL_00_CONTENT_COMPLETE` |
| 최초 확인 | 2026-10-11 |
| 영역 | BasementSessionSmoke / deferred focus·process_frame 대기 수명 |

## 확인된 내용

기상 출처 후보의 기본 지하 통합 검사는 `BASEMENT_SESSION_SMOKE: PASS`, 실행 단언 13,921개, native 0으로 끝났다. 그러나 verbose 로그에는 `ObjectDB instances leaked at exit`, `WeakRef` 객체 다섯 개와 `process_frame`의 고아 StringName 여섯 참조가 남았다. 행동 PASS와 native 0만으로 종료 수명 검사까지 통과한 것으로 볼 수 없다.

실행 소스 265개, 엔진 지문, 로그 SHA 및 기본 모드 영수증은 [기상 출처 검증 원자료](../validation/2026-10-11_기상출처_침실정본화_검증.md)의 `before-basement-ordinary-candidate`에 보존한다. 수정 전 기준본의 `before-basement-ordinary-baseline`도 행동 13,921단언/PASS/native 0 뒤 같은 WeakRef 다섯 개 종료 누수가 남았다. 위치 수정 이전에도 존재한 문제지만 정확한 생성 경로는 아직 특정하지 않았다. `process_frame` 대기 중인 포커스/화면 수명 작업이 후보이며 verbose 이름만으로 제품 또는 검사기에 원인을 단정하지 않는다.

## 권장 조치

1. 실제 기본 모드 종료를 fixture 단위로 좁히고 생성·대기·완료·제거 시점과 소유자 세대를 기록한다. engine와 동일한 제품 소스를 고정한다.
2. 검사 fixture의 화면 제거 전에 필요한 완료를 기다리고, 완료 자체가 불가능해지는 삭제 경로는 detached 작업·약한 화면 참조와 명시적 취소로 회수한다. 임의의 긴 대기나 누수 경고 무시로 해결하지 않는다.
3. 제품 실행의 소유자 수명 결함으로 재현되면 관련 범위의 production code를 수정하고, 단순 검사 fixture 정리 문제이면 helper에만 수정한다. ERR-0069의 동작 단언 실패와 별도 검증한다.
4. 기본/개발 모드·한영 지하 전체의 행동 PASS, native 0 및 verbose 무누수를 함께 요구한다. 이전 소스의 수명 PASS나 다른 경로 검사를 전체 지하 무누수 근거로 재사용하지 않는다.

## 상태

- [x] 기본 모드 행동 통과와 종료 누수의 분리 기록.
- [x] 구형 기준본의 동일 행동 PASS와 종료 누수 비교.
- [ ] 생성 경로 국소 재현.
- [ ] 회수/취소 조치 후 같은 소스 전체 무누수 검사.

해결 전까지 이 실행은 추가 진단이며, 합격 회귀 묶음 수에 포함하지 않는다. 전체 Windows 완주나 실제 종료 입력의 증거도 아니다.
