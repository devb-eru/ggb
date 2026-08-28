# Development Environment

## Required

- Godot 4.7 계열
- Git
- Git LFS

Godot 프로젝트는 `game/project.godot`입니다.

## Role-Specific Tooling

- GitHub→Discord 알림 스크립트를 로컬에서 검증하는 운영 담당자는 Node.js 24 이상이 필요합니다.
- 일반 Godot 콘텐츠 작업에는 Node.js가 필수는 아닙니다.

운영 스크립트 검증:

```bash
node --test scripts/discord_notifications.test.mjs
```

CI는 `.github/workflows/discord-notifications.yml`에서 Node.js 24를 사용합니다. 로컬 Node.js가 없으면 이 테스트를 실행했다고 표시하지 않고 CI 결과 또는 Node.js 24가 설치된 환경의 로그를 근거로 남깁니다.

## Recommended Editor Flow

1. 저장소 루트에서 최신 브랜치를 받습니다.
2. Godot Project Manager에서 `game/project.godot`을 엽니다.
3. 에디터가 생성한 `game/.godot/`은 커밋하지 않습니다.
4. 새 씬, 스크립트, 데이터 파일은 `docs/godot_conventions.md`의 위치 규칙을 따릅니다.

## Git LFS

이미지, 사운드, 폰트, 원본 아트 파일은 `.gitattributes`에서 Git LFS 대상으로 지정합니다.

처음 저장소를 받는 사람은 아래 명령을 한 번 실행합니다.

```bash
git lfs install
```

## Local Outputs

- 테스트 빌드: `builds/`
- 배포 산출물: `exports/`

두 폴더의 실제 산출물은 Git에서 제외됩니다.
