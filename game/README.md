# GGB Godot 프로젝트 상태

## 개발자 시점 이동

디버그 실행에서 오른쪽 위 `개발자 · F10` 또는 F10을 눌러 프롤로그·퍼즐·사용인·엔딩 시점을 선택할 수 있다. `C4`는 거울 경로 시험, `P4_MEMORY`는 차 준비 뒤 기억 닻, `EDR_FIELD_NOTEBOOK`은 현실 수첩 테스트 지점이다. 별도 개발 슬롯에서 이어서 플레이하며, `마지막 개발 테스트 이어하기`로 재개한다. 상세 사용법은 [개발자 시점 이동](../docs/developer_checkpoints.md)을 따른다.

통합 수첩·엔딩 감상 수첩 열람 중에는 닫기와 입력 보호를 위해 개발자 버튼 및 F10 개발자 진입이 잠시 비활성화된다. 수첩을 닫은 뒤 사용할 수 있다.

## 현재 상태

이 폴더는 Godot 4.7 계열 프로젝트 루트다. 기본 실행 씬은 `scenes/main/main.tscn`, 내부 앱 이름은 가칭 `GGB`다. 현재 production 셸에는 상태·사건·원자 writer·저장, 입력 라우팅과 키보드 포커스의 최소 fixture가 연결돼 있다. 아직 플레이 가능한 버티컬 슬라이스는 아니다.

루트의 `signal_practice.tscn`과 GDScript·PNG는 과거 신호 연결, 배경 전환, 서랍·열쇠 클릭을 확인하는 격리된 기술 스파이크다. 기본 실행 경로에서 사용하지 않는다.

이 연습 씬은 부모 컨트롤러가 초기 배경 snapshot과 노드 의존성을 배포하도록 보수했지만 다음을 증명하지 않는다.

- 전체 v0.4 사건·상태·저장 데이터 구현
- 실제 방과 퍼즐의 production scene 구성
- 마우스·키보드 동등 경로 또는 접근성 계약
- Windows debug export와 성능 기준
- 버티컬 슬라이스 완료

정식명이 잠기기 전 내부 표시명은 가칭 `GGB`를 사용한다. 이는 제품명·스토어 App ID·사용자 데이터 경로·데모와 본편의 저장 승계 식별자를 확정한 것이 아니다. 해당 식별자는 `TECH_01_FOUNDATION`에서 별도로 고정한다.

## 연습 코드 보수 상태와 한계

- 2026-08-30에 열쇠 획득 시 연습용 인벤토리 기록, 숨김과 입력 비활성화를 연결했다.
- 열쇠·서랍·자물쇠는 대상 배경에서만 보이며, 배경 이동과 획득 뒤 상태가 되살아나지 않는다.
- 클릭 확정은 `pressed` 신호를 사용하고 배경 수는 배열 길이에서 계산한다.
- 씬은 여전히 고정 좌표를 사용하는 연습 코드다. 형제 경로 직접 참조는 제거하고 부모 컨트롤러의 export NodePath 주입으로 바꿨지만 production 입력 라우터·접근성 포커스·정식 인벤토리와 저장 계약을 증명하지 않는다.
- Godot 4.7.2에서 headless import·GDScript parse·foundation 저장 smoke와 연습 씬 smoke를 통과했다.

연습 코드를 유지한다면 기능 예시로만 격리하고, 제작 코드가 이 파일에 의존하지 않게 한다.

## Production 전환 조건

`TECH_01_FOUNDATION`에서 다음 순서로 교체한다.

1. 완료: `scenes/main/`의 production bootstrap과 기본 진입점 분리.
2. 완료: `scripts/autoload/`, `scripts/systems/`, `data/`에 문서 계약의 최소 구조 구현.
3. 완료: 상태·사건·입력·저장 schema 1 fixture 연결.
4. 완료: Godot headless import·parse와 Windows debug export 통과.
5. 제품명이 확정되면 내부 표시명과 사용자 데이터·배포 식별자를 결정 기록에 따라 이관한다.

세부 완료 조건은 [검증 계획](../docs/validation_plan.md), [Godot 규칙](../docs/godot_conventions.md), [기술 백로그](../docs/production_backlog.md)를 따른다.
