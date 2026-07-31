# GGB

GGB는 포인트 앤 클릭 어드벤처 게임 프로젝트의 작업 저장소입니다.

이 저장소는 기획 문서와 Godot 프로젝트를 함께 관리합니다. 기획 원본은 `ideas/`에 두고, 실제 게임 구현은 `game/` 아래에서 진행합니다.

## 주요 경로

- `game/`: Godot 프로젝트 루트입니다. Godot에서 `game/project.godot`을 열어 작업합니다.
- `ideas/md/v04/`: v0.4 기준 기획 문서와 이벤트 설계 문서입니다.
- `docs/`: 개발 환경, Git 운용, Godot 작성 규칙, 데이터 계약 문서입니다.
- `scripts/`: 저장소에 추적하는 문서·데이터·CI 검증 도구 위치입니다.
- `tools/`: 개인용 문서 생성·변환 도구 위치이며 현재 Git에서 제외됩니다.
- `builds/`: 로컬 테스트 빌드 산출물 위치입니다.
- `exports/`: 배포용 export 산출물 위치입니다.

### 정본과 로컬 산출물

- 현재 게임 기획 정본은 `ideas/md/v04/00~18`과 그 문서가 지정한 `docs/` 계약이다.
- 루트의 v0.1~v0.3 DOCX, `_qa_gdd*`, `build_gdd.py`, `tools/`, `node_modules/`는 Git에서 제외된 과거 참고·개인 생성 환경이며 v0.4 수정 기준으로 사용하지 않는다.
- `~$*.docx` 같은 잠금 파일은 열려 있는 문서 작업 흔적일 수 있으므로 자동 삭제하지 않는다.
- 과거 문서를 참고해 규칙을 되살릴 때는 현행 v0.4와 결정 기록을 먼저 비교하고, 충돌하면 새 결정 또는 이슈로 처리한다.

## 기본 작업 흐름

1. `develop`에서 최신 내용을 받습니다.
2. 기능, 문서, 콘텐츠 단위로 새 브랜치를 만듭니다.
3. Godot 작업은 `game/`, 기획 작업은 `ideas/`, 협업 규칙은 `docs/`에서 진행합니다.
4. 변경 후 PR을 `develop`으로 보냅니다.
5. 안정화된 버전만 `main`으로 병합합니다.

작업 상태, 담당자, 완료 조건, 의사결정 기록은 [`docs/project_operations.md`](docs/project_operations.md)를 기준으로 관리합니다. 새 작업과 결정은 [`docs/templates/`](docs/templates/)의 템플릿을 사용합니다.

- 프로젝트 역할: [`docs/project_roles.md`](docs/project_roles.md)
- GitHub Issue·Project 운영: [`docs/github_project.md`](docs/github_project.md)
- 다음 작업 계획: [`docs/next_work_plan.md`](docs/next_work_plan.md)
- 제작 전환 백로그: [`docs/production_backlog.md`](docs/production_backlog.md)
- 에셋 BOM·승인 레지스트리: [`docs/asset_manifest.md`](docs/asset_manifest.md)
- 아트·애니메이션·오디오 제작 규격: [`docs/content_pipeline_specs.md`](docs/content_pipeline_specs.md)
- 미확정 설정·브랜딩 잠금 일정: [`docs/creative_lock_schedule.md`](docs/creative_lock_schedule.md)
- 1.0 플랫폼·지원·법적 기능표: [`docs/release_feature_matrix.md`](docs/release_feature_matrix.md)
- 기여자 권리 증거·제작물 반입 기준: [`docs/contributor_rights.md`](docs/contributor_rights.md)
- 검증·CI 단계: [`docs/validation_plan.md`](docs/validation_plan.md)
- 2026-07-31 전체 프로젝트 검토와 후속 상태: [`docs/project_review_2026-07-31.md`](docs/project_review_2026-07-31.md)
- Windows 렌더러·성능 예산: [`docs/technical_performance_budget.md`](docs/technical_performance_budget.md)
- 메타 UI·인벤토리 계약: [`docs/meta_ui_flow.md`](docs/meta_ui_flow.md)
- 타깃 플레이어·플레이테스트: [`docs/player_experience_and_playtest.md`](docs/player_experience_and_playtest.md)
- Discord 알림·회의·에셋 접수: [`docs/discord_operations.md`](docs/discord_operations.md)
- 에셋 접수·Google Drive 보관: [`docs/asset_intake.md`](docs/asset_intake.md)
- 마일스톤과 외부 일정: [`docs/milestones.md`](docs/milestones.md)
- 공통 제품 계약: [`docs/product_contract.md`](docs/product_contract.md)
- 한·영 현지화 제작 계약: [`docs/localization.md`](docs/localization.md)
- 콘텐츠 고지·심리 안전 기준: [`docs/content_advisory.md`](docs/content_advisory.md)
- 상태·저장 데이터 계약: [`docs/data_contract.md`](docs/data_contract.md)
- M1 v0.4 기준선 검토 기록: [`docs/milestone_reviews/M1_V04_PLANNING_BASELINE.md`](docs/milestone_reviews/M1_V04_PLANNING_BASELINE.md)
- 공개 데모 완료 기준: [`docs/demo_definition.md`](docs/demo_definition.md)
- 완성본 범위와 출시 게이트: [`docs/full_game_definition.md`](docs/full_game_definition.md)
- Steamworks·Next Fest 준비: [`docs/steam_release_plan.md`](docs/steam_release_plan.md)

## Godot 열기

Godot 에디터에서 아래 파일을 엽니다.

```text
game/project.godot
```

`game/.godot/`은 Godot가 생성하는 로컬 캐시이므로 Git에 올리지 않습니다.
