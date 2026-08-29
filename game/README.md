# GGB Godot 프로젝트 상태

## 현재 상태

이 폴더는 Godot 4.7 계열 프로젝트 루트다. 기본 실행 씬은 `scenes/main/main.tscn`, 내부 앱 이름은 가칭 `GGB`다. 현재 bootstrap은 제작 코드와 연습 코드를 분리하는 최소 진입점이며, 아직 플레이 가능한 버티컬 슬라이스는 아니다.

루트의 `signal_practice.tscn`과 GDScript·PNG는 과거 신호 연결, 배경 전환, 서랍·열쇠 클릭을 확인하는 격리된 기술 스파이크다. 기본 실행 경로에서 사용하지 않는다.

이 연습 씬은 다음을 증명하지 않는다.

- v0.4 사건·상태·저장 데이터 구현
- production main scene과 autoload 구성
- 마우스·키보드 동등 경로 또는 접근성 계약
- Windows debug export와 성능 기준
- 버티컬 슬라이스 완료

정식명이 잠기기 전 내부 표시명은 가칭 `GGB`를 사용한다. 이는 제품명·스토어 App ID·사용자 데이터 경로·데모와 본편의 저장 승계 식별자를 확정한 것이 아니다. 해당 식별자는 `TECH_01_FOUNDATION`에서 별도로 고정한다.

## 연습 코드 보수 상태와 한계

- 2026-08-30에 열쇠 획득 시 연습용 인벤토리 기록, 숨김과 입력 비활성화를 연결했다.
- 열쇠·서랍·자물쇠는 대상 배경에서만 보이며, 배경 이동과 획득 뒤 상태가 되살아나지 않는다.
- 클릭 확정은 `pressed` 신호를 사용하고 배경 수는 배열 길이에서 계산한다.
- 씬은 여전히 고정 좌표와 형제 `NodePath`를 사용하는 연습 코드다. production 입력 라우터·접근성 포커스·정식 인벤토리와 저장 계약을 증명하지 않는다.
- 현재 셸에서는 Godot 실행 파일을 찾지 못해 headless import와 GDScript parse를 재검증하지 못했다.

연습 코드를 유지한다면 기능 예시로만 격리하고, 제작 코드가 이 파일에 의존하지 않게 한다.

## Production 전환 조건

`TECH_01_FOUNDATION`에서 다음 순서로 교체한다.

1. 완료: `scenes/main/`의 production bootstrap과 기본 진입점 분리.
2. `scripts/autoload/`, `scripts/systems/`, `data/`에 문서 계약의 최소 구조를 구현한다.
3. 상태·사건·입력·저장 schema 1 fixture를 연결한다.
4. Godot headless import·parse와 Windows debug export를 통과한다.
5. 제품명이 확정되면 내부 표시명과 사용자 데이터·배포 식별자를 결정 기록에 따라 이관한다.

세부 완료 조건은 [검증 계획](../docs/validation_plan.md), [Godot 규칙](../docs/godot_conventions.md), [기술 백로그](../docs/production_backlog.md)를 따른다.
