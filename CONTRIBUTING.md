# Contributing

GGB 협업 규칙입니다. 기획과 구현이 함께 움직이는 프로젝트이므로, 변경 범위와 참조한 기획 문서를 커밋 또는 PR에 남기는 것을 기본으로 합니다.

작업 상태, 담당자, 완료 조건과 결정 기록은 [프로젝트 운영 기준](docs/project_operations.md)을 따릅니다.

## 작업 시작

- 새 일반 작업은 `GGB-WRK-YYYY-NNNN` ID를 사용하고 [작업 항목 템플릿](docs/templates/work_item.md)으로 범위와 완료 조건을 작성합니다.
- 기존 `GGB-CNF/ERR`를 해결할 때는 해당 ID를 그대로 작업 ID로 사용합니다.
- `IN_PROGRESS`로 변경하기 전에 담당자와 목표 마일스톤을 정합니다.
- 선행 작업이나 결정이 필요하면 `BLOCKED`와 차단 원인 ID를 기록합니다.
- 둘 이상의 유효한 선택지 중 중요한 하나를 확정할 때는 [결정 기록](docs/decisions/README.md)을 남깁니다.

## 브랜치 규칙

- `main`: 안정 버전, 릴리즈 또는 외부 공유용입니다.
- `develop`: 일반 개발 통합 브랜치입니다.
- `feature/*`: 기능 구현입니다.
- `fix/*`: 버그 수정입니다.
- `docs/*`: 기획서, 설계 문서, 협업 문서 수정입니다.
- `content/*`: 이벤트, 대사, 퍼즐 데이터 수정입니다.
- `art/*`: 아트, 사운드 등 에셋 반영입니다.

## 커밋 메시지

아래 접두사를 사용하고, 연결된 작업 ID가 있으면 제목 끝에 적습니다.

```text
docs: update servant relationship notes [GGB-WRK-2026-0001]
content: add J4 journal restore data [GGB-WRK-2026-0002]
feature: implement reset shortcut manager [GGB-CNF-2026-0003]
fix: prevent library alert softlock [GGB-WRK-2026-0003]
art: add Edgar portrait placeholder [GGB-WRK-2026-0004]
audio: add archive signal sfx [GGB-WRK-2026-0005]
```

## PR 체크

- 변경한 기획 문서 또는 이벤트 ID를 PR 설명에 적습니다.
- 연결된 작업 ID, 완료 조건, 검증 근거를 PR 설명에 적습니다.
- 중요한 선택이 있었다면 관련 `GGB-DEC` ID를 적습니다.
- Godot 씬을 수정했다면 에디터에서 열리는지 확인합니다.
- `ideas/md/v04/issues/`에 연결된 충돌 또는 오류가 있으면 ID를 적습니다.
- 바이너리 에셋은 Git LFS 추적 대상인지 확인합니다.
- `game/.godot/` 같은 로컬 캐시는 커밋하지 않습니다.

## GitHub 계정이 없는 팀원의 작업

`gatam`, `210`, `nana`, `NOne`이 Discord로 전달한 작업은 `beru`가 저장소에 대리 반영합니다.

- 작업 항목 또는 PR 설명에 `contributor: 실제 제작자`를 적습니다.
- Discord 전달 메시지·날짜, 작업 ID, 반영 파일을 기록합니다.
- 아트·사운드 등 외부 에셋은 사용 권리와 원본 보관 위치를 확인합니다.
- Discord 첨부만 장기 보관본으로 삼지 않고 Git/LFS 또는 별도 원본 보관소에 복사합니다.
- 커밋 작성자와 실제 제작자를 같은 사람으로 오해하지 않도록 기록을 유지합니다.
