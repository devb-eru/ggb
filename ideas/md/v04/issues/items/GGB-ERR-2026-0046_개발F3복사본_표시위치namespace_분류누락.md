# GGB-ERR-2026-0046: 개발 F3 복사본 표시 위치 namespace 분류 누락

| 항목 | 값 |
| --- | --- |
| 유형 | 오류 ERR |
| 심각도 | 중간 |
| 해결 상태 | VERIFIED |
| 작업 상태 | DONE |
| 우선순위 | P2 |
| 담당자 | Codex |
| 목표 마일스톤 | `FULL_00_CONTENT_COMPLETE` |
| 최초 확인 | 2026-10-07 |
| 영역 | presentation_view_tracker / 개발 F3 복사본 |

## 원인과 영향

ERR-0045에서 수첩 host/commands/worker를 통일했지만 별도 화면 열람 위치 추적기는 슬롯명의 `__dev_` 접두사만 확인했다. 개발 체크포인트의 `reselect_<random>` 복사본을 full로 분류해 일반 namespace에 화면 위치 편의 파일을 생성한다. 본문·고정·일반 슬롯의 실제 덮어쓰기는 관찰하지 않았다.

일반 데이터가 미리 채워진 격리 실행에서 일반 저장 12개는 보존됐지만 프로필 비교가 실패했다. 복사본 수첩은 development, 동일 복사본 화면 위치는 full이라는 실제 생성 파일을 확인했다. 합법적인 development 화면 위치 파일을 초기 검사기가 보호 영역에 포함한 문제도 있어, 검사기와 제품 오류를 구분했다.

## 해결

추적기의 namespace는 `notebook_commands.scope_namespace` 공통 정책을 사용한다. 슬롯/run/origin/branch/load epoch 및 flush의 live 상태 검사는 유지한다. 이전 잘못된 편의 파일은 자동 삭제·이관하지 않는다. 신규 올바른 development 파일부터 별도로 관리한다.

회귀 검사에는 일반 demo/full 각 세 슬롯의 main/bak, 각 슬롯 수첩·화면 위치 main/bak, 두 엔딩 메타·갤러리를 미리 생성한다. 실제 개발 jump/resume/F3 copy, 복사본 수첩 고정·저장·재로드, 개발 갤러리 열람/비교, 타이틀 복귀를 검사한다. 개발 편의 파일도 경로·scope·체크섬·스키마가 유효해야 예외 처리한다. full/demo 및 손상·미등록 파일은 보호 영역에 남는다.

검증 상세: [기존 일반 데이터 개발 모드 비오염 검사](../validation/2026-10-07_기존일반데이터_개발모드_비오염검증.md).

최종 격리 headless 회귀: 89개 개발 체크포인트 PASS, 일반 저장 12개·프로필 29개의 경로 및 SHA-256 보존 PASS. 실제 F3 복사본 추적기 namespace와 고정·재로드, 갤러리 읽기 전용 상태도 확인했다. 엔진은 Steam 4.7.2이며 IME 실기나 4.6.3 채택 검증으로 계산하지 않는다.
