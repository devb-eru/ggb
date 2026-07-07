# Contributing

GGB 협업 규칙입니다. 기획과 구현이 함께 움직이는 프로젝트이므로, 변경 범위와 참조한 기획 문서를 커밋 또는 PR에 남기는 것을 기본으로 합니다.

## 브랜치 규칙

- `main`: 안정 버전, 릴리즈 또는 외부 공유용입니다.
- `develop`: 일반 개발 통합 브랜치입니다.
- `feature/*`: 기능 구현입니다.
- `fix/*`: 버그 수정입니다.
- `docs/*`: 기획서, 설계 문서, 협업 문서 수정입니다.
- `content/*`: 이벤트, 대사, 퍼즐 데이터 수정입니다.
- `art/*`: 아트, 사운드 등 에셋 반영입니다.

## 커밋 메시지

가능하면 아래 접두사를 사용합니다.

```text
docs: update servant relationship notes
content: add J4 journal restore data
feature: implement reset shortcut manager
fix: prevent library alert softlock
art: add Edgar portrait placeholder
audio: add archive signal sfx
```

## PR 체크

- 변경한 기획 문서 또는 이벤트 ID를 PR 설명에 적습니다.
- Godot 씬을 수정했다면 에디터에서 열리는지 확인합니다.
- `ideas/md/v04/issues/`에 연결된 충돌 또는 오류가 있으면 ID를 적습니다.
- 바이너리 에셋은 Git LFS 추적 대상인지 확인합니다.
- `game/.godot/` 같은 로컬 캐시는 커밋하지 않습니다.

