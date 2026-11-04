# 시트 선택·공개 경계 봉인 근거

- 검증 ID: `NB-SHEET-20261105`.
- 기준: 수정 전 develop `8479e9d`, 수정 후 `game/scripts` 307개 GDScript와 `game/data` 63개 파일. 프로젝트 내부 테스트를 포함하며 외부 하네스는 별도로 봉인했다.
- [manifest](manifest.json): 수정 후 지문, 실행 행렬, 원자료 목록·크기·SHA-256.
- [원자료](raw.zip): 165개 로그·실행 영수증·하네스·조건별 저장 스냅샷. 성공 9개 실행, 기대 실패 2개 대조군 및 폐기 진단 6개를 구분한다.
- [독립 감사 결과](audit_result.json): 16,905확인·25반례 거부, 실제 스냅샷 48개와 전달 도구의 지문 대조.
- PCK: 내보내기·50개 JSON 지문 비교·통합 수첩 Scene 회귀·기본 모드 실제 시작 씬의 4개 native 실행. 배포 EXE나 PCK 바이너리는 Git에 포함하지 않았으며 PCK 지문과 검사 코드·로그를 보존했다.
- runtime은 공식 Godot 4.6.3 후보다. 제품 4.7 기준과 rollout OFF는 변경하지 않았다. 실제 Windows 입력·정식 성능·엔진 채택·전체 인수 근거가 아니다.

저장소 루트에서 실행한다. 후속 수정본이 아니라 이 근거를 전달한 동일 소스 트리를 사용해야 한다.

```powershell
pwsh -NoProfile -File scripts/audit_notebook_sheet_disclosure.ps1 -EvidencePath ideas/md/v04/issues/validation/evidence/notebook-sheet-20261103 -RepoPath . -SelfTest
```

[검증 보고서](../../2026-11-03_시트선택_비동기저장_및_공개경계_검증.md)에서 각 실패 시도와 남은 전체 인수 범위를 확인한다. 구형 선택 runner는 GD 지문만 기록하며 그 실행의 data 불변성을 별도로 증명했다고 주장하지 않는다.
