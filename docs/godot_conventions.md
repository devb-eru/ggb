# Godot Conventions

## Project Root

Godot 프로젝트 루트는 `game/`입니다.

```text
game/project.godot
```

## Folder Roles

- `game/scenes/main/`: 시작 씬, 부트스트랩 씬, 테스트 진입 씬입니다.
- `game/scenes/rooms/`: 저택 방, 회랑, 코어실 등 공간 씬입니다.
- `game/scenes/ui/`: 수첩, 대화창, 조사 UI 등 UI 씬입니다.
- `game/scenes/events/`: 이벤트 전용 연출 씬입니다.
- `game/scripts/autoload/`: 전역 싱글톤 스크립트입니다.
- `game/scripts/systems/`: 루프, 상태, 이벤트, 대화, 저장 시스템입니다.
- `game/scripts/interactables/`: 클릭 가능한 오브젝트와 상호작용 컴포넌트입니다.
- `game/scripts/ui/`: UI 동작 스크립트입니다.
- `game/data/`: 이벤트, 대사, 퍼즐, 상태 데이터입니다.
- `game/assets/`: 아트, 오디오, 폰트, 셰이더입니다.

## Naming

- 파일명은 `snake_case`를 기본으로 합니다.
- 씬 파일은 의미 단위로 작성합니다. 예: `library_inner.tscn`
- 스크립트 파일은 담당 클래스 또는 시스템명을 반영합니다. 예: `event_manager.gd`
- 이벤트 ID, 상태 변수명은 `ideas/md/v04`와 `docs/data_contract.md`를 기준으로 맞춥니다.

## Scene Rule

하나의 방은 가능하면 하나의 대표 room scene을 갖습니다. 방 안의 오브젝트는 독립 씬으로 분리할 수 있습니다.

```text
game/scenes/rooms/library_inner.tscn
game/scenes/events/b2_edgar_entry.tscn
game/scripts/interactables/library_service_alcove.gd
```

## Autoload Candidates

- `GameState`
- `EventManager`
- `DialogueManager`
- `Inventory`
- `Notebook`
- `AudioBus`

실제 등록은 구현 시점에 확정합니다.

