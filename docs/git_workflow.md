# Git Workflow

## Branches

- `main`: 안정 버전입니다.
- `develop`: 일반 개발 통합 브랜치입니다.
- `feature/*`: 시스템, UI, 퍼즐 등 새 기능입니다.
- `fix/*`: 버그 수정입니다.
- `docs/*`: 문서 수정입니다.
- `content/*`: 이벤트, 대사, 데이터 수정입니다.
- `art/*`: 아트와 오디오 에셋 반영입니다.

## Suggested Flow

```bash
git checkout develop
git pull
git checkout -b feature/reset-system
```

작업 후:

```bash
git add game docs ideas
git commit -m "feature: add reset system scaffold"
git push -u origin feature/reset-system
```

PR은 기본적으로 `develop`을 대상으로 합니다.

## Review Points

- Godot 프로젝트가 열리는가.
- 이벤트 ID와 상태 변수명이 기획 문서와 일치하는가.
- 로컬 캐시, 빌드 산출물, 임시 파일이 포함되지 않았는가.
- 바이너리 파일이 Git LFS 대상으로 처리되는가.

