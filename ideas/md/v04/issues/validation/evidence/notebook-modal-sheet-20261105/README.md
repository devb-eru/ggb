# 선택창 시트 경로 회귀 근거

- 검증 ID: `NB-MODAL-SHEET-20261105`.
- 기준: develop `c4abc09eabf3f106e086166ef5503625375af50b`에서 검사 파일 하나만 보완했다. 제품 코드·시트·과거 원문은 변경하지 않았다.
- 공식 Godot 4.6.3 후보, 개발 통합 수첩·엄격 작성 ID 모드. 제품의 4.7 기준 및 rollout OFF는 유지한다.
- `raw.zip`: 원본 실패, 첫 보완 실패, 최종 seed/resume/completed 원로그·receipt·실행 스크립트와 당시 검사 원본 총 23파일. 실패 실행을 성공으로 재분류하지 않는다.
- 최종 native 세 프로세스 모두 0, seed 980·resume 7·completed 4단언(합계 991), 각 PASS. 첫 장 한영 선택/취소 행렬은 그 안의 30조건이다. 12개 엔딩 복구 조건도 그 안에 포함되며 별도 합산하지 않는다.
- 최종 실행의 게임 307스크립트·63data 지문과 원로그 hash, 세 프로세스·991단언·실패 진단 보존을 `scripts/audit_notebook_modal_sheet.ps1`로 재확인했다: 407확인 PASS.
- 현재 C4의 실제 안내·조건부 에드가 개입·선택창 복원과 A1의 저장된 답변 명시 재시도를 검사했다. 추가 C4/J3 저장 실패 경계, 실제 Windows 수면 입력, 전편 완주·성능·엔진 채택 인수의 대체 근거가 아니다.
- 다른 앱 알림을 포함한 화면이나 사용자 원본 프로필·세이브는 이 묶음에 넣지 않았다.

저장소 루트에서 PowerShell 7로 재확인:

```powershell
./scripts/audit_notebook_modal_sheet.ps1 -EvidencePath ./ideas/md/v04/issues/validation/evidence/notebook-modal-sheet-20261105 -RepoPath .
```

`manifest.json`은 원자료와 고정 소스의 지문을 가진다. 이후 제품 소스가 달라지면 해당 과거 근거의 소스 대조가 거부되는 것이 정상이다. 원본 실행은 `baseline`, 첫 보완 실패는 `intermediate`, 최종 세 프로세스는 `final`로 구분한다. 샌드박스 가져오기 실패는 테스트 본문 미진입 진단으로 검토 문서에 별도 기록했다.
