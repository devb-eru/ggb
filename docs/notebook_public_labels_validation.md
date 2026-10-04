# 공개 명칭과 관계 완료 안내의 의미 버전 검증

기준: 2026-10-04, develop `29e9c81`. 생산자 감사 PA11 / [GGB-ERR-2026-0026](../ideas/md/v04/issues/items/GGB-ERR-2026-0026_플레이어_문구_내부ID_노출.md)의 첫 수정 범위다. 전체 이슈와 통합 수첩 목표는 `IN_PROGRESS`다.

## 1. 재현과 수정 범위

다섯 사용인의 관계 완료 화면은 `SCREEN.COMPLETE` 원고와 한영 UI 번역에서 `REC_MARA1` 같은 내부 키를 플레이어에게 안내했다. 완료 화면은 실제 월드 관찰 원문으로도 저장되므로, 번역 문자열만 바꾸면 새 화면과 기존 version 1 descriptor가 불일치해 저장을 거부할 수 있다.

다음 다섯 ID에만 의미 버전 2를 추가하고 실제 완료 화면의 생산자가 그 descriptor를 명시적으로 선택한다.

| ID | 공개 명칭 |
| --- | --- |
| `NB_MARA1_SCREEN_COMPLETE` | 마라 1의 연구 기록 / Mara 1's research record |
| `NB_IRIS_SCREEN_COMPLETE` | 이리스의 연구 기록 / Iris's research record |
| `NB_LUCA_SCREEN_COMPLETE` | 루카의 연구 기록 / Luca's research record |
| `NB_EDGAR_SCREEN_COMPLETE` | 에드가 연구 기록 / Edgar's research record |
| `NB_MARA2_SCREEN_COMPLETE` | 마라 2의 연구 기록 / Mara 2's research record |

- 책임·불확실성·자기 결정권에 관한 앞 문장은 유지한다. `SUBJECT`는 실제 권한 이름이므로 유지한다.
- `relationship_labels_v2.json`을 등록하고 COMPLETE 이외의 관계 표면에는 기존 경로를 유지한다.
- 원래 다섯 v1 카탈로그 파일은 바이트 단위로 변경하지 않았다. 과거 기록의 ID·버전·문장·보호·출처를 갱신하거나 삭제하지 않는다.
- 저장 키 `REC_*`, 관계 완료 상태·선택지·보상·퍼즐 답안은 바꾸지 않는다. 일반 표시 전체에 최신 버전을 자동 적용하지 않는다.
- 총 27개 카탈로그, 고유 ID 1,683개, 버전별 정의 1,691개, 정의별 문장 합계 2,483개다. 이 수는 작성량이며 전 분기 실행 수가 아니다.

## 2. 검사 계약

네 관계 생산자 검사에 공통 `notebook_relationship_label_assertions.gd`를 연결한다.

1. 다섯 ID의 한국어·영어 최신 화면 원고와 version 2 카탈로그를 비교한다.
2. version 1 원고가 계속 존재하는지 확인하고, 실제 과거 observation 구조를 JSON 왕복한 뒤 두 언어로 재생한다. captured text나 의미 버전은 변하지 않아야 한다.
3. version 2 문구를 version 1로 관찰 저장하려는 요청은 거부해야 한다.
4. 실제 관계 진행에서 수집한 완료 화면은 정확한 version 2이며, 당시 표시와 보관 문장·재생 결과에 `REC_`가 없어야 한다.
5. 구 버전 observation을 최신 경로 판정에 넣으면 거부한다.
6. 기존 관계 검사들의 미룸·저장 거부·응답 유실·재로드·반복 행동·미공개 자료·지식/관계 불변 검사를 유지한다.

과거 version 1의 내부 ID 포함 원문은 보존 검사의 대상이다. 이를 신규 플레이 문구 노출 0 조건과 혼합해 원문을 삭제하지 않는다.

## 3. 실행 근거

Windows Godot 4.7.2 headless, 격리 APPDATA/LOCALAPPDATA, 빈 실행 디렉터리에서 export PCK를 사용한다. 종료 코드 0, PASS 표식, 파싱/컴파일/스크립트 오류 없음이 모두 충족되어야 PASS다.

- 로그: `%TEMP%/ggb-public-labels-20261004/`.
- PCK SHA-256: `AE8498FDCD5492DA1D3BF958536B3C8D736971F8721D8C7EC1A0C90181106566`.
- import 20.9초, export 7.5초.
- 명령: `godot --headless --path <empty> --main-pack <pck> -- --notebook-<검사명>-smoke --ggb-dev-notebook-v2`.

| 검사명 | 결과 | 실제 범위 | 시간 |
| --- | --- | --- | --- |
| `mara1` | PASS | 27 ID / 54 ID·언어 / 64 문장·언어 | 32.9초 |
| `iris` | PASS | 45 ID / 90 ID·언어 / 104 문장·언어 / 관계 결과 20개 | 77초 |
| `luca` | PASS | 31 ID / 62 ID·언어 / 78 문장·언어 / 1,250 열거형 조합 | 35.4초 |
| `authority-archive` | PASS | 148 ID / 296 ID·언어 / 666 문장·언어 / 관계 결과 48개 / 규칙 행렬 546개 | 347.6초 |

같은 PCK의 추가 회귀 로그는 `%TEMP%/ggb-public-labels-regression-20261004/`다. 별도 프로세스에서 순차 실행했다.

| 검사명 | 결과 | 범위 | 시간 |
| --- | --- | --- | --- |
| `query` | PASS | 통합 조회 299개와 조회·검색·자료 비교·갤러리·레거시·보호/인물 등 기존 하위 검사 | 41.1초 |
| `surface-resume` | PASS | 현재 방문 재개·동적 표시·저장 실패/응답 유실·언어/범위 격리 108개 | 6.1초 |

추가 조회 검사의 하위 수는 legacy-notes 73, view 83, browse 190, visual 138, search 180, investigation 300, person-retention 64, memory-disclosure 83, self-mark 270, gallery 182다. 이 수를 서로 독립적인 전편 시나리오 수로 합산하지 않는다. `surface-resume`은 기본 capture 검사이며 별도 `--surface-resume-phase`의 새 프로세스 단계 실행은 이번 범위가 아니다.

다섯 완료 안내 외 다른 화면의 내부 ID 노출을 이 결과로 해결 처리하지 않는다. 환경의 `Failed to read the root certificate store` 메시지는 별도로 남으며 게임 스크립트 실패와 구분한다.

## 4. 잔여 작업과 한계

- J4 인덱스 fallback, 현실 인계 페이지, 지하 도면, 코어 자료, 일부 힌트/제목·편집 이력의 내부 ID는 아직 수정하지 않았다. 원인·파일·조건·해결 방향은 개별 이슈에 기록했다.
- raw title 일부는 이미 조회 메타데이터에서 일반 제목으로 대체한다. 카탈로그 정적 검색만으로 실제 제목 노출이나 완전 해결을 판정하지 않는다.
- 한글 조사에 붙은 ID, 동적 변수로 생성되는 ID, 개발자 화면 전용 ID를 구분해야 한다.
- 이번 실행은 실제 컨트롤러/관찰 저장 경로의 자동 검사다. Windows 실제 마우스·키보드·IME·시각 검수나 cold/warm p95 측정이 아니다.
- 변경 후 전체 캠페인/지하 종합 회귀는 이 보고서의 집중 검사와 별도다. 직전 커밋의 전체 PASS를 새 패키지 전체 PASS로 소급하지 않는다.
- rollout 기본 비활성, 여러 자료를 담고 두 개씩 비교, 보호/미분류 기록 별도 보관, 개인 자유 메모 후속 분리 결정을 유지한다.
