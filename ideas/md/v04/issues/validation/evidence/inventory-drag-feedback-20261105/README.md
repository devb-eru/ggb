# 드래그 안내 회귀 원자료

검증 ID `INVENTORY-DRAG-FEEDBACK-20261105`. 사용자 마우스 진행 제외 지시 전에 발견한 ERR-0079의 코드 수정과 합성 알림 회귀다. 마우스 진행을 재개하지 않았다.

- 원본 정식 실행: 244확인/20실패, native 1, 스크립트 오류 없음.
- 수정 후보: 같은 244확인/0실패, native 0.
- 관련 프롤로그: 265확인/native 0/PASS.
- 관련 1장: 수정 전·후 모두 같은 8실패/native 1. ERR-0080 OPEN으로 분리하며 전체 회귀 PASS로 계산하지 않는다.
- 실제 엔진의 drag-end 알림 전달·OS 입력·운영 history wrapper·비동기 저장은 집중 검사의 범위 밖이다. 이슈 상태는 RESOLVED/REVIEW다.

`raw.zip`의 31파일을 `manifest.json`의 크기·SHA-256으로 대조한다. baseline/candidate 각각 source ZIP과 313스크립트 지문을 보존했으며 정식 두 실행의 제품 소스 차이는 prologue controller 하나다. 최초 구형 필드 null 변환 검사 오류와 잘못된 authored 강제 플래그 실행도 진단으로 보존했다.

`prior-mouse-observations/`는 제외 지시 전 자연 슬롯 진행의 action log와 깨끗한 milestone 캡처만 포함한다. 사용자 본래 프로필·세이브는 포함하지 않는다. 이 관찰을 수정 후 마우스 검증이나 전편 완주로 바꾸어 읽지 않는다.

독립 대조 명령은 해당 지문의 저장소 루트에서 실행한다.

```powershell
& ./scripts/audit_inventory_drag_feedback.ps1 `
  -EvidencePath ./ideas/md/v04/issues/validation/evidence/inventory-drag-feedback-20261105 `
  -RepoPath .
```

이 감사는 봉인된 결과·실패·소스 지문을 대조하며 게임을 재실행하지 않는다. 이후 소스가 변경된 개발본에는 과거 지문을 그대로 적용하지 않는다.

첫 감사에서는 정상 실행의 빈 stderr가 PowerShell에서 빈 배열로 평가되어 Boolean 매개변수 변환이 실패했다. 로그를 문자열로 정규화한 뒤 다시 실행하며, 원로그·결과·지문은 변경하지 않았다.
