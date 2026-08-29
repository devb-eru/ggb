# GGB-CNF-2026-0019: 렌더러 미확정과 D3D12·Forward+ 고정 충돌

> [충돌·오류 관리](../README.md) / [운영 레지스트리](../충돌오류_레지스트리.md)

| 필드 | 값 |
| --- | --- |
| 심각도 | 높음 |
| 상태 | OPEN |
| 작업 상태 | READY |
| 우선순위 | P1 |
| 담당자 | `beru` |
| 목표 마일스톤 | `TECH_01_FOUNDATION` |
| 영역 | Windows 렌더러·성능·배포 설정 |
| 기준 문서 | [`docs/technical_performance_budget.md`](../../../../../docs/technical_performance_budget.md) |
| 영향 파일 | [`game/project.godot`](../../../../../game/project.godot), 향후 `game/export_presets.cfg` |
| 예정 검증 ID | `QA-CNF-0019-CANDIDATES`, `QA-CNF-0019-PERF`, `QA-CNF-0019-DECISION` |

## 문제

성능 계약은 같은 장면을 Compatibility와 Forward+로 비교하고, Compatibility가 필수 연출과 접근성 기준을 만족하면 우선하도록 규정한다. 그러나 현재 `game/project.godot`은 `Forward Plus` 기능과 Windows `d3d12` 드라이버를 단일 기본값처럼 기록한다.

현재 값은 과거 연습 프로젝트의 설정일 뿐 결정 증거가 아니다. 이 상태로 export preset과 Steam 최소 사양을 만들면 다음 문제가 생긴다.

- 통합 GPU와 구형 Windows 장비에서 Compatibility 후보를 시험하기 전에 지원 범위가 좁아질 수 있다.
- D5 글리치 연출 때문에 Forward+가 필요하다는 가설과 실제 계측 결과가 섞인다.
- 개발 설정이 제품 렌더러 결정으로 오인되어 상점 사양과 QA 장비표가 잘못 고정될 수 있다.

## 권장 해결안

1. C5·D5·E1·색 제거 모드를 포함한 동일 렌더러 시험 씬을 만든다.
2. Compatibility와 Forward+ 후보를 동일 해상도·품질·콘텐츠 revision으로 Windows debug export한다.
3. LOW-IGPU, LOW-DGPU, MID, HIGH-DPI 장비에서 프레임·VRAM·시작 시간·필수 단서 보존을 비교한다.
4. 결과를 새 `GGB-DEC`로 승인하고 `project.godot`, export preset, 성능 예산과 Steam 사양을 같은 변경에서 동기화한다.
5. 결정 전까지 현재 D3D12·Forward+ 값에는 `PROVISIONAL` 의미만 부여하고 제품 최소 사양 근거로 사용하지 않는다.

## 완료 조건

- [ ] 두 후보가 같은 시험 장면과 품질표를 사용한다.
- [ ] 최소 네 장비 역할의 계측표와 실패 원인이 있다.
- [ ] 색 제거·UI 200%에서 필수 단서 동등성을 확인한다.
- [ ] renderer 결정 ID가 프로젝트 설정과 배포 문서에 연결된다.
- [ ] Windows debug export를 깨끗한 사용자 환경에서 실행한다.

## 검증 계획

| 검증 ID | 검사 | 기대 결과 |
| --- | --- | --- |
| `QA-CNF-0019-CANDIDATES` | 두 후보 설정 비교 | 동일 콘텐츠·해상도에서 Compatibility와 Forward+ 산출물 존재 |
| `QA-CNF-0019-PERF` | 장비별 성능·필수 단서 | 선택 후보가 모든 필수 기능과 성능 하한 통과 |
| `QA-CNF-0019-DECISION` | 결정·설정·상점 사양 추적 | 한 결정 ID로 모두 역추적 가능 |

## 변경 이력

| 날짜 | 주체 | 내용 | 상태 |
| --- | --- | --- | --- |
| 2026-08-30 | `Codex` | 코드 재감사에서 미확정 렌더러와 단일 D3D12·Forward+ 설정의 충돌 등록 | OPEN · READY |
