# GGB

GGB는 포인트 앤 클릭 어드벤처 게임 프로젝트의 작업 저장소입니다.

이 저장소는 기획 문서와 Godot 프로젝트를 함께 관리합니다. 기획 원본은 `ideas/`에 두고, 실제 게임 구현은 `game/` 아래에서 진행합니다.

## 주요 경로

- `game/`: Godot 프로젝트 루트입니다. Godot에서 `game/project.godot`을 열어 작업합니다.
- `ideas/md/v04/`: v0.4 기준 기획 문서와 이벤트 설계 문서입니다.
- `docs/`: 개발 환경, Git 운용, Godot 작성 규칙, 데이터 계약 문서입니다.
- `tools/`: 문서 생성, 검증, 변환 등 보조 도구 위치입니다.
- `builds/`: 로컬 테스트 빌드 산출물 위치입니다.
- `exports/`: 배포용 export 산출물 위치입니다.

## 기본 작업 흐름

1. `develop`에서 최신 내용을 받습니다.
2. 기능, 문서, 콘텐츠 단위로 새 브랜치를 만듭니다.
3. Godot 작업은 `game/`, 기획 작업은 `ideas/`, 협업 규칙은 `docs/`에서 진행합니다.
4. 변경 후 PR을 `develop`으로 보냅니다.
5. 안정화된 버전만 `main`으로 병합합니다.

작업 상태, 담당자, 완료 조건, 의사결정 기록은 [`docs/project_operations.md`](docs/project_operations.md)를 기준으로 관리합니다. 새 작업과 결정은 [`docs/templates/`](docs/templates/)의 템플릿을 사용합니다.

- 프로젝트 역할: [`docs/project_roles.md`](docs/project_roles.md)
- 다음 작업 계획: [`docs/next_work_plan.md`](docs/next_work_plan.md)
- 마일스톤과 외부 일정: [`docs/milestones.md`](docs/milestones.md)
- 공개 데모 완료 기준: [`docs/demo_definition.md`](docs/demo_definition.md)
- 완성본 범위와 출시 게이트: [`docs/full_game_definition.md`](docs/full_game_definition.md)
- Steamworks·Next Fest 준비: [`docs/steam_release_plan.md`](docs/steam_release_plan.md)

## Godot 열기

Godot 에디터에서 아래 파일을 엽니다.

```text
game/project.godot
```

`game/.godot/`은 Godot가 생성하는 로컬 캐시이므로 Git에 올리지 않습니다.
