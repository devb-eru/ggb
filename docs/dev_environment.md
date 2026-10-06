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

2026-08-29 검증에서는 Codex 번들 Node.js `v24.19.0`으로 위 명령을 실행해 15개 테스트가 모두 통과했습니다. 이 기록은 Discord 알림 스크립트의 로컬 실행 증거이며 Godot `V1~V5` 구현 증거를 대신하지 않습니다.

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

## Windows Export Template Matching

`scripts/validate_renderer_candidates.ps1`은 지정한 Godot 실행 파일의 `--version`과 정확히 일치하는 표준 Windows 템플릿만 사용합니다. 여러 버전 중 첫 폴더를 고르거나 다른 버전으로 fallback하지 않습니다.

```text
<Godot 실행 파일의 폴더>/editor_data/export_templates/<release.status>/
  version.txt                 # 내용도 release.status와 일치
  windows_debug_x86_64.exe
```

예를 들어 실행 파일이 `4.6.3.stable.official.<hash>`인 후보 검증은 `4.6.3.stable` 폴더를 요구합니다. 이 예시가 현재 제품의 Godot 4.7 요구를 대체하지는 않습니다. 공식 템플릿 패키지의 checksum도 별도로 확인해야 하며 폴더/marker 일치만으로 바이너리 무결성이 증명되지는 않습니다. Mono는 이 표준 GDScript 검증 경로에서 지원하지 않습니다.

정책 자체의 fixture 검사는 Godot 없이 실행할 수 있으며 PowerShell 7과 Windows PowerShell 5.1에서 검사했습니다.

```powershell
./scripts/test_godot_windows_template_policy.ps1
```

전체 내보내기 스크립트는 PowerShell 7에서 다음과 같이 실행합니다. 매번 새 임시 runtime/APPDATA를 사용하며 이미 존재하는 `-RuntimeRoot`는 거부합니다. 필요한 경우 이 옵션에 존재하지 않는 경로를 명시할 수 있습니다. 각 자식 프로세스의 제한은 600초입니다.

```powershell
./scripts/validate_renderer_candidates.ps1 -GodotPath 'C:/path/to/godot.exe'
```

headless foundation PASS는 실제 GPU 렌더러/성능 인수나 제품 엔진 채택 완료를 뜻하지 않습니다. 후보 검증 결과는 [4.6.3 EXE 검증](../ideas/md/v04/issues/validation/2026-10-07_엔진템플릿_버전일치_및_EXE검증.md)에 기록합니다.
