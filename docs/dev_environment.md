# Development Environment

## Required

- Godot 4.7 계열
- Git
- Git LFS

Godot 프로젝트는 `game/project.godot`입니다.

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

