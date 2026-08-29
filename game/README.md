# GGB Godot 프로젝트 상태

## 현재 상태

이 폴더는 Godot 4.7 계열 프로젝트 루트다. 다만 현재 기본 실행 씬 `signal_practice.tscn`과 루트의 GDScript·PNG는 과거 신호 연결, 배경 전환, 서랍·열쇠 클릭을 확인한 연습용 기술 스파이크다.

이 연습 씬은 다음을 증명하지 않는다.

- v0.4 사건·상태·저장 데이터 구현
- production main scene과 autoload 구성
- 마우스·키보드 동등 경로 또는 접근성 계약
- Windows debug export와 성능 기준
- 버티컬 슬라이스 완료

`project.godot`의 `config/name="임시"`와 `run/main_scene="res://signal_practice.tscn"`도 제품명·제품 App ID·production 진입점으로 사용하지 않는다. 정식명이 잠기기 전 내부 개발 식별자는 가칭 `GGB`를 사용하되, 실제 사용자 데이터 경로와 데모·본편 저장 승계 식별자는 `TECH_01_FOUNDATION`에서 별도로 고정한다.

## 알려진 연습 코드 한계

- `key.gd`는 클릭 뒤 `key_clicked`만 바꾸며 버튼을 숨기거나 비활성화하지 않는다.
- 주석에 적힌 인벤토리 이동은 구현되지 않았다.
- 씬은 고정 좌표와 형제 `NodePath`, `button_down` 신호를 사용하며 production 입력·포커스 규칙을 따르지 않는다.
- 현재 셸에서는 Godot 실행 파일을 찾지 못해 headless import와 GDScript parse를 재검증하지 못했다.

연습 코드를 유지한다면 기능 예시로만 격리하고, 제작 코드가 이 파일에 의존하지 않게 한다.

## Production 전환 조건

`TECH_01_FOUNDATION`에서 다음 순서로 교체한다.

1. `scenes/main/`에 production bootstrap과 main scene을 만든다.
2. `scripts/autoload/`, `scripts/systems/`, `data/`에 문서 계약의 최소 구조를 구현한다.
3. 상태·사건·입력·저장 schema 1 fixture를 연결한다.
4. Godot headless import·parse와 Windows debug export를 통과한다.
5. 그 뒤에만 `run/main_scene`과 내부 앱 식별자를 production 값으로 바꾼다.

세부 완료 조건은 [검증 계획](../docs/validation_plan.md), [Godot 규칙](../docs/godot_conventions.md), [기술 백로그](../docs/production_backlog.md)를 따른다.
