# Godot Conventions

## 1. Project Root And Version

Godot 프로젝트 루트는 `game/`이며 엔진은 Godot 4.7 계열을 사용한다.

```text
game/project.godot
```

Windows 10/11 64-bit PC 데스크톱이 목표 실행 환경이다. 최소·권장 하드웨어 사양은 실제 빌드 검증 뒤 확정한다.

## 2. Folder Roles

```text
game/
├─ scenes/
│  ├─ main/
│  ├─ rooms/
│  ├─ ui/
│  └─ events/
├─ scripts/
│  ├─ autoload/
│  ├─ systems/
│  ├─ data_types/
│  ├─ interactables/
│  └─ ui/
├─ data/
└─ assets/
```

| 경로 | 책임 |
| --- | --- |
| `scenes/main/` | 부트스트랩·메인·테스트 진입 씬 |
| `scenes/rooms/` | 저택 방·회랑·코어·현실 공간 |
| `scenes/ui/` | 수첩·대화·조사·설정·엔딩 UI |
| `scenes/events/` | 사건 전용 연출 씬 |
| `scripts/autoload/` | 명시적으로 등록한 전역 서비스 |
| `scripts/systems/` | 상태 writer·router·resolver·reset 조정 |
| `scripts/data_types/` | Resource·상태·event node 타입 |
| `scripts/interactables/` | 핫스폿·상호작용 adapter |
| `scripts/ui/` | UI 동작·포커스·접근성 |
| `data/` | 읽기 전용 사건·대사·퍼즐·registry `.tres` |
| `assets/` | 아트·오디오·폰트·셰이더 |

`res://autoload/`, `res://resources/`, `res://scenes/locations/`를 병렬 정본 경로로 추가하지 않는다.

## 3. Naming

- 파일명과 폴더명은 소문자 snake_case다.
- 씬 파일은 공간·사건 의미 단위를 사용한다. 예: `library_inner.tscn`.
- 스크립트 파일은 담당 클래스나 서비스를 반영한다. 예: `event_manager.gd`.
- 기획 ID `B3-A`, `F0-D`, `CLR-04`는 구현에서 `B3_A`, `F0_D`, `CLR_04`로 정규화한다.
- Resource 파일은 `event_e3_5.tres`, `signature_mara2.tres`처럼 category와 ID를 드러낸다.
- 이벤트 ID·상태 경로는 [`ideas/md/v04/17_상태변수_이벤트ID_Godot데이터구조.md`](../ideas/md/v04/17_상태변수_이벤트ID_Godot데이터구조.md)와 [`docs/data_contract.md`](data_contract.md)를 따른다.

## 4. Scene Rule

하나의 방은 가능하면 하나의 대표 room scene을 갖는다. 방 안 오브젝트와 복잡한 사건 연출은 독립 씬으로 분리할 수 있다.

```text
game/scenes/rooms/library_inner.tscn
game/scenes/events/b2_edgar_entry.tscn
game/scripts/interactables/library_service_alcove.gd
```

- room scene은 진행 상태의 정본이 아니다.
- scene load 시 GameState snapshot을 읽어 외형·잠금·오브젝트 위치를 적용한다.
- scene 종료 시 Node 전체를 저장하지 않고 허용된 상태 ID만 writer에 전달한다.
- 절대 Windows 경로와 editor 전용 NodePath를 저장 데이터에 넣지 않는다.

## 5. Autoload And Systems

### 5.1 권장 autoload

| 서비스 | 책임 |
| --- | --- |
| `GameState` | 영구·루프·파열·엔딩 실행 snapshot과 파생 getter |
| `EventManager` | 사건 정의 조회·실행·신호·현재 사건 |
| `SaveManager` | 슬롯 저장·backup·migration·복구 |
| `AccessibilityProfileManager` | Windows 표시·입력·접근성 프로필 |
| `DialogueManager` | 텍스트 ID 조회·대사 재생 |
| `Inventory` | 현재 루프 도구와 영구 항목 구분 |
| `Notebook` | 수첩 표시와 영구 정보 조회 |
| `AudioBus` | 음향·감각 자막 연동 |

실제 autoload 등록은 구현 시 확정하지만 상태 소유권은 위 책임을 넘지 않는다.

### 5.2 일반 systems

| 시스템 | 책임 | 전역 상태 직접 소유 |
| --- | --- | --- |
| `StateWriter` | 타입·권한·불변식 검사 후 상태 커밋 | 금지 |
| `ResetCoordinator` | SYS_COMMIT→SYS_MEMORY→RESET→ROUTE | transaction runtime만 |
| `ReactionRouter` | 짧은 반응 queue·우선순위·만료 | 금지 |
| `EndingRouter` | EDC 이후 노드·메타 라우팅 | 금지 |
| `VisualStateResolver` | 세계·인물·서명·접근성 표현 합성 | 금지 |
| `DataContractValidator` | ID·참조·writer·graph 정적 검사 | 금지 |

`EventBus`를 별도 autoload로 중복 등록하지 않는다. 사건 신호는 `EventManager`가 소유한다.

## 6. State Mutation

```text
입력
→ InteractionRouter
→ EventManager
→ StateWriter
→ GameState revision
```

- UI·대사·resolver·scene script가 GameState Dictionary를 직접 수정하지 않는다.
- 한 번의 명시적 confirm은 최대 한 사건 node와 한 writer 요청만 소비한다.
- 영구 효과가 둘 이상이면 atomic group을 사용한다.
- signal payload로 mutable 전체 Dictionary를 넘기지 않는다.
- 상태 변경 뒤 `state_committed(revision, changed_paths)`를 통해 UI와 scene이 새 snapshot을 읽는다.

## 7. Resource And Save

| 데이터 | 형식 | 경로 |
| --- | --- | --- |
| 사건·퍼즐·오브젝트·시각 정의 | `.tres` | `res://data/` |
| 진행 슬롯 | JSON | `user://saves/{slot_id}/` |
| 접근성·입력·엔딩 메타 | JSON | `user://profile/` |
| migration·검증 로그 | JSONL | `user://logs/` |

- Resource는 런타임에 수정하지 않는다.
- Godot 4.7의 논리 집합은 중복 없는 `Array[StringName]`으로 구현한다.
- 저장 전 논리 집합은 정렬하고 Dictionary 키도 결정적 순서로 직렬화한다.
- `progress.tmp.json` 검증 뒤 backup과 main 파일을 교체한다.
- 접근성 프로필 손상은 진행 슬롯 손상으로 취급하지 않는다.

## 8. Windows UI And Focus

- 기준 화면은 1920×1080, 최소 레이아웃은 1280×720이다.
- UI·글자·커서 확대와 Windows 표시 배율 100~200%를 함께 검사한다.
- 마우스 hover와 키보드 focus를 별도로 유지한다.
- `Alt+Tab`, 최소화, 포커스 상실 때 대사 자동 진행과 미확정 입력을 멈춘다.
- 팝업 종료 시 원래 object ID로 focus를 돌린다.
- 키보드 전용으로 필수 진행과 두 엔딩을 완료할 수 있어야 한다.

## 9. Validation

구현 전·빌드 전 다음 검사를 통과해야 한다.

- event·node·state·location·object·text ID 중복과 누락.
- Resource 상대 참조와 registry 일치.
- 사건 category별 금지 writer.
- entry→completion→return graph 도달성.
- save fixture migration·backup 복구.
- 논리 집합 중복·빈 ID.
- 색 제거·음량 0·모션 최소 경로.
- Windows 1280×720·UI 200%·키보드 전용 경로.

필수 데이터 오류가 있으면 export를 차단한다. 프로토타입이 아닌 문서 단계의 GDScript 예시는 클래스·필드·호출 경계를 나타내는 인터페이스 명세로 취급한다.
