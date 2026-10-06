# GGB-ERR-2026-0043: 실행 엔진과 export template 버전 불일치

| 항목 | 값 |
| --- | --- |
| 유형 | 오류 ERR |
| 심각도 | 중간 |
| 해결 상태 | VERIFIED |
| 작업 상태 | DONE |
| 우선순위 | P2 |
| 담당자 | `Codex` |
| 목표 마일스톤 | `FULL_00_CONTENT_COMPLETE` |
| 최초 확인 | 2026-10-07 |
| 영역 | Windows 빌드 / scripts/validate_renderer_candidates.ps1 |

## 원인과 영향

기존 스크립트는 실행 파일의 버전을 읽지 않고 `editor_data/export_templates`에서 Windows debug 파일이 있는 첫 폴더를 선택했다. 4.5.2/4.6.3/4.7.2가 함께 있는 fixture에서 4.6.3 엔진에 4.5.2 템플릿을 선택하는 것을 재현했다. 내보내기 실패 또는 실행 엔진과 다른 버전의 EXE 생성 위험이 있으며, 이전 빌드가 실제로 잘못된 버전이었다고 소급 판정한 것은 아니다.

## 해결과 검증

- 실행 엔진의 `--version`에서 release/status를 추출하고 정확한 템플릿 폴더·version.txt·Windows debug x64 파일을 확인한다. 없으면 다른 버전으로 fallback하지 않는다.
- 표준 GDScript 프로젝트용 정책이며 Mono 엔진은 거부한다. 입력 문자열만으로 임의 경로를 선택할 수 없다. 메타데이터 일치 검사이지 바이너리 위변조 검증은 아니므로 후보의 공식 패키지 SHA 검증은 별도로 수행했다.
- 검증 runtime/APPDATA는 실행마다 새 경로이고 이미 존재하는 명시 경로는 거부한다. 각 자식 프로세스는 600초 제한으로 자기 프로세스만 종료한다.
- `scripts/test_godot_windows_template_policy.ps1`의 정상 3/거부 7조건을 PowerShell 7과 Windows PowerShell 5.1에서 PASS. 잘못된 첫 폴더 선택 재현을 포함한다.
- 공식 4.6.3 템플릿으로 실제 Windows EXE 두 후보를 내보내고 각각 foundation PASS. headless 검사이며 실제 렌더링 품질/성능 인수는 아니다.

자세한 공식 패키지 hash/범위는 [후보 EXE 검증](../validation/2026-10-07_엔진템플릿_버전일치_및_EXE검증.md)을 따른다. 이 항목의 VERIFIED가 IME ERR-0042 해결이나 전체 엔진 채택을 뜻하지 않는다.

```yaml
resolved_in:
  - scripts/validate_renderer_candidates.ps1
  - scripts/godot_windows_template_policy.ps1
resolution_summary: exact runtime/template version matching; no fallback; isolated bounded processes
verification_ids:
  - GODOT_TEMPLATE_POLICY (PowerShell 7 / Windows PowerShell 5.1, 10 checks)
  - FOUNDATION_SMOKE (official 4.6.3 Windows EXE, two candidate paths)
verified_on: 2026-10-07
```
