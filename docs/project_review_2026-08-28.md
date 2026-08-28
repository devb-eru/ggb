# GGB 전체 프로젝트 오류·충돌 감사

## 1. 감사 정보

| 항목 | 내용 |
| --- | --- |
| 기준일 | 2026-08-28 KST |
| 기준 브랜치 | `develop` |
| 기준 커밋 | 감사 시작 시 `8297825` |
| 범위 | v0.4 기획 정본, 제품·운영·Steam 문서, 의뢰·에셋·오브젝트 대장, 검증기, 추적 중 이슈, Godot 저장소 상태 |
| 방식 | Markdown·CSV 정적 검사, ID·링크·상태 교차 참조, Git/LFS 점검, 일정·게이트 대조, 저장소 구현 증거 확인 |
| 외부 제외 | GitHub Project·Steamworks·Discord·Drive의 현재 화면과 권한은 직접 조회하지 않음 |
| 실행 제외 | Godot과 Node.js가 로컬 PATH에 없어 엔진 import·실행 및 Discord Node 테스트는 실행하지 못함 |

이 문서의 `GGB-REV-*`는 감사 발견 ID다. v0.4 설계 결함 정본은 기존 `GGB-CNF`·`GGB-ERR`, 제작 작업은 `GGB-WRK`로 계속 관리한다.

## 2. 결론

정적 문서 계약은 감사 중 교정 후 통과했다. 링크·ID·에셋 참조·의뢰 참조의 추가 확정 오류는 남지 않았다. 다만 프로젝트가 오류 없이 제작 준비를 마쳤다는 뜻은 아니다.

현재 열린 핵심 문제는 다음 네 축이다.

1. 외부 서고 B3 시계와 기록 내실 시계의 canonical ID 충돌 1건이 이미 `OPEN` 상태다.
2. `TECH_01_FOUNDATION` 목표일이 지났지만 저장소의 제품 진입점은 아직 연습 씬이다.
3. 기한이 지난 마일스톤·창작 잠금의 상태가 정책대로 `AT_RISK` 또는 재산정 상태로 갱신되지 않았다.
4. 제작 의뢰 10건이 모두 수락 대기이고 에셋 329행이 모두 계획·임시 상태다.

감사 중 정본 마일스톤 ID, 사용인 오브젝트 예시, 검증기 사각지대와 Node.js 환경 문서를 교정했다. 외부 상태나 팀 결정을 추정해야 하는 항목은 임의로 완료 처리하지 않았다.

## 3. 상태 기준

| 상태 | 의미 |
| --- | --- |
| `OPEN` | 저장소 근거만으로 문제를 확정했고 후속 수정이 필요함 |
| `ACTION_REQUIRED` | 오류라기보다 제작 게이트가 충족되지 않았으며 즉시 재계획이 필요함 |
| `REVERIFY_REQUIRED` | 과거 기록과 후속 기록이 충돌해 외부 상태 재확인이 필요함 |
| `EXTERNAL_EVIDENCE_REQUIRED` | 팀 수락·계정·실기 결과 없이는 닫을 수 없음 |
| `RESOLVED_IN_AUDIT` | 이번 감사에서 문서와 재발 방지 검사를 함께 수정함 |
| `DOC_RESOLVED_TEST_PENDING` | 문서 누락은 고쳤으나 해당 실행 환경의 테스트가 남음 |

## 4. 발견 요약

| ID | 우선순위 | 상태 | 요약 |
| --- | --- | --- | --- |
| `GGB-REV-2026-0033` | P1 | OPEN | 외부 서고 B3 시계와 기록 내실 시계 canonical ID 충돌 |
| `GGB-REV-2026-0034` | P1 | ACTION_REQUIRED | 기술 기반선 목표 경과와 제품 bootstrap 증거 부재 |
| `GGB-REV-2026-0035` | P1 | ACTION_REQUIRED | 기한 경과 마일스톤·창작 잠금의 상태 정책 미반영 |
| `GGB-REV-2026-0036` | P1 | REVERIFY_REQUIRED | 제작 Issue 등록의 GitHub 인증 차단 기록과 후속 Issue 생성 기록 충돌 |
| `GGB-REV-2026-0037` | P1 | EXTERNAL_EVIDENCE_REQUIRED | 의뢰 전부 수락 대기, 에셋 전부 임시 상태 |
| `GGB-REV-2026-0038` | P2 | RESOLVED_IN_AUDIT | 본편 의뢰·현지화 문서의 존재하지 않는 마일스톤 별칭 |
| `GGB-REV-2026-0039` | P2 | RESOLVED_IN_AUDIT | 상태 데이터 문서의 미등록 사용인 오브젝트 예시 |
| `GGB-REV-2026-0040` | P2 | RESOLVED_IN_AUDIT | 마일스톤·오브젝트 교차 참조 검증 사각지대 |
| `GGB-REV-2026-0041` | P2 | REVERIFY_REQUIRED | GitHub Project 정본 원칙과 로컬 운영 현황 스냅숏의 노후화 |
| `GGB-REV-2026-0042` | P3 | DOC_RESOLVED_TEST_PENDING | 운영 스크립트의 Node.js 24 로컬 환경 계약 누락 |

## 5. P1 발견

### GGB-REV-2026-0033: 외부 서고와 기록 내실 시계 ID 충돌

**근거**

- [기존 개별 이슈](../ideas/md/v04/issues/items/GGB-CNF-2026-0018_외부서고_B3_시계와_기록내실_시계_ID_충돌.md)가 `OPEN · READY · P1`이다.
- B3 외부 서고 시계와 `M1_LIBRARY_INNER` 기록 시계가 `OBJ_LIBRARY_RECORD_CLOCK`을 공유하면 위치·아트·상호작용 resolver가 같은 물체로 오인한다.
- 현재 외부 서고 시계는 정본 export에서 격리되어 있어 즉시 런타임 오염은 없지만 버티컬 슬라이스 제작 전에는 닫아야 한다.

**해결안**

1. 기록 내실은 `OBJ_LIBRARY_RECORD_CLOCK`과 `ART_OBJ_LIBRARY_RECORD_CLOCK`을 유지한다.
2. 외부 서고 B3용 `OBJ_LIBRARY_OUTER_CLOCK`, `ART_OBJ_LIBRARY_OUTER_CLOCK`을 발급한다.
3. v0.4 문서 `04`, `05`, `08`, `09`, `15`, `17`, 오브젝트·에셋 대장, ART·CNT 의뢰를 동기화한다.
4. 외부·내실 두 시계가 서로 다른 위치와 이벤트를 resolve하는 회귀 검사를 추가한다.

**완료 증거**

- 개별 이슈가 `VERIFIED · DONE`으로 전환된다.
- 두 ID가 정본 대장에 각각 한 번 존재하고 `validate_docs.ps1`이 통과한다.

### GGB-REV-2026-0034: 기술 기반선 목표 경과와 bootstrap 부재

**근거**

- [마일스톤](milestones.md)의 `TECH_01_FOUNDATION` 목표일은 2026-08-21이며 상태는 여전히 `PROVISIONAL`이다.
- `game/project.godot`의 앱 이름은 `임시`, main scene은 `res://signal_practice.tscn`이다.
- 추적된 제품 기반은 연습 씬 1개와 GDScript 5개이며 production main scene, autoload 구현, 사건 Resource, 저장 fixture와 Windows export preset이 없다.
- [검증 계획](validation_plan.md)의 `V1~V5`는 모두 `NOT_IMPLEMENTED`다.

**영향**

2026-09-18 버티컬 슬라이스까지 남은 기간에 기술 기반선과 콘텐츠 통합을 동시에 처리해야 한다. 일정 지연뿐 아니라 상태·저장·입력·접근성 계약을 급히 구현하면서 문서와 런타임이 어긋날 위험이 크다.

**해결안**

1. `TECH_01_FOUNDATION`을 현재 증거 기준 `AT_RISK`로 표시하고 실제 capacity를 반영한 새 목표일을 기록한다.
2. `production bootstrap → GameState/EventManager/StateWriter → 입력·포커스 → 저장 schema 1 → locale → Windows debug export` 순으로 최소 기반선을 만든다.
3. 각 단계는 [제작 전환 백로그](production_backlog.md)와 [Godot 규칙](godot_conventions.md)의 완료 조건으로 검증한다.
4. 기술 기반선이 버티컬 슬라이스 일정을 침범하면 `PROD_01_VERTICAL_SLICE`도 같은 날 재산정한다.

**완료 증거**

- 연습 씬과 분리된 production main scene 및 제품 ID.
- headless import, 상태·저장 최소 fixture, Windows debug export 로그.
- 마일스톤 상태·목표일·차단 사유의 최신 기록.

### GGB-REV-2026-0035: 기한 경과 상태와 창작 잠금 정책 불일치

**근거**

- `OPS_01_COLLABORATION_BASELINE`은 2026-08-04 목표에 `IN_PROGRESS`, `STEAM_01_ONBOARDING`은 2026-08-14 목표에 `PLANNED`, `TECH_01_FOUNDATION`은 2026-08-21 목표에 `PROVISIONAL`로 남아 있다.
- [창작 잠금 일정](creative_lock_schedule.md)의 정식명, 태그라인, 주인공 화면명·연령대, 마라 이름, 마라 2 외형 연령 결정은 2026-08-14~21 필요일을 지났지만 현재 값은 가칭·미정·임시명이다.
- 같은 문서는 기한 경과 시 연결 마일스톤을 `AT_RISK`로 갱신하라고 규정한다.
- [Steam 계획](steam_release_plan.md)은 게임명·소개만 `AT_RISK`로 표시하지만 마일스톤 표와 다른 잠금에는 반영되지 않았다.

**영향**

의뢰가 `READY_FOR_ACCEPTANCE`여도 이름·비율·브랜딩이 잠기지 않아 아트·대사·번역·Steam 작업의 재작업 비용을 판단할 수 없다. 오래된 상태가 대시보드에서 정상 진행처럼 보일 수 있다.

**해결안**

1. 잠금표에 `status`, `last_verified_on`, `linked_milestone`, `revised_target` 열을 추가한다.
2. 결정을 완료하지 못한 항목은 `LOCKED`로 꾸미지 않고 `OPEN/REVIEW + AT_RISK`로 표시한다.
3. 세 기한 경과 마일스톤을 실제 외부 상태와 대조한 뒤 `COMPLETE`, `AT_RISK`, `BLOCKED` 중 하나로 갱신한다.
4. 각 `AT_RISK` 항목에 책임자, 다음 결정일, 중단되는 제작 범위를 기록한다.

### GGB-REV-2026-0036: GitHub 인증 차단 기록과 후속 생성 기록 충돌

**근거**

- [제작 전환 백로그](production_backlog.md)는 2026-07-31 HTTP 403과 무효한 로컬 token을 근거로 `PB-003=BLOCKED_GITHUB_AUTH`라고 기록한다.
- [다음 작업 계획](next_work_plan.md)은 이후 실제 GitHub Issues #15, #17, #19, #22, #24, #26과 Project 구성을 기록한다.
- 따라서 “모든 Issue 쓰기 경로가 차단됨”은 현재 상태 설명으로 사용할 수 없다. 다만 제작 PB 항목이 실제로 등록됐다는 증거도 없다.

**해결안**

1. 7월 31일 403은 변경 이력으로 보존한다.
2. 차단 상태를 `integration issue write`, `gh CLI auth`, `production PB registration` 세 축으로 분리한다.
3. 현재 인증으로 중복 검색을 먼저 실행한 뒤 미등록 제작 Issue만 재시도한다.
4. `PB-003`은 재시험 결과에 따라 `AUTH_RETEST_REQUIRED`, `PARTIAL`, `RESOLVED` 중 하나로 갱신한다.

### GGB-REV-2026-0037: 제작 의뢰와 에셋 수락 증거 부재

**근거**

- [의뢰 대장](requests/request_register.csv)의 10건이 모두 `READY_FOR_ACCEPTANCE`다.
- 각 의뢰서의 수락 범위·제외 범위·공수 회신은 비어 있다.
- [에셋 manifest](asset_manifest.csv)의 329행은 모두 `PLANNED`, `is_placeholder=true`다.
- 팀 의뢰에 포함되지 않은 4행은 `beru` 소유 기술 셰이더이며 의도된 내부 구현 범위다. 누락으로 판정하지 않는다.

**영향**

문서상 전수 목록은 갖췄지만 실제 처리량, 담당 분배, 첫 검토일과 통합 시간이 없다. 버티컬 슬라이스 일정은 아직 제작 속도에 근거하지 않는다.

**해결안**

1. 버티컬 슬라이스 ART·AUD·CNT 3건부터 팀이 범위·제외·담당·시간·첫 검토일을 회신한다.
2. 대표 에셋과 문자열을 소량 제작해 역할별 실제 시간을 기록한다.
3. 수락 뒤에만 `ACCEPTED/IN_PROGRESS`로 전환하고, 실제 파일·권리·검토 근거 없이 `APPROVED/INTEGRATED`로 올리지 않는다.
4. 실측 결과로 데모·본편 배치와 `PROD_01_VERTICAL_SLICE` 날짜를 재산정한다.

## 6. P2·P3 발견

### GGB-REV-2026-0038: 존재하지 않는 본편 콘텐츠 락 별칭

**원인**

본편 의뢰 3건과 현지화 단계표가 정본 `FULL_00_CONTENT_LOCK` 대신 `FULL_CONTENT_LOCK`을 사용했다. 의뢰 대장과 상세 brief끼리는 같았기 때문에 기존 검증은 오류를 잡지 못했다.

**처리**

- ART·AUD·CNT 본편 의뢰와 대장을 `FULL_00_CONTENT_LOCK`으로 수정했다.
- 세 의뢰 개정을 r2로 올리고 2026-08-28 변경 이력을 추가했다.
- 현지화 단계의 비정본 별칭도 `M2_DEMO_FEATURE_COMPLETE`, `M2_DEMO_COMPLETE`, `LOC_01_DEMO_LOCK`, `FULL_00_CONTENT_LOCK`으로 교정했다.

**상태**: `RESOLVED_IN_AUDIT`

### GGB-REV-2026-0039: 미등록 사용인 오브젝트 예시

**원인**

[상태·데이터 문서](../ideas/md/v04/17_상태변수_이벤트ID_Godot데이터구조.md)의 ID 규칙 예시가 정본에 없는 `SERVANT_OBJ_EDGAR`를 사용했다. 실제 canonical ID는 `SERVANT_OBJ_EDGAR_LOCK_PORT`다.

**처리**

- 예시를 정본 ID로 교정했다.
- 현행 계약 문서의 구체 `OBJ_*`, `SERVANT_OBJ_*`가 오브젝트 대장에 없으면 실패하는 검사를 추가했다.

**상태**: `RESOLVED_IN_AUDIT`

### GGB-REV-2026-0040: 정적 검증기의 교차 참조 사각지대

**원인**

기존 검증기는 CSV 구조와 의뢰서 자체 일치는 검사했지만 다음을 정본과 대조하지 않았다.

- 에셋·의뢰·개별 이슈의 목표 마일스톤 존재 여부.
- 의뢰 대장과 상세 brief의 목표 마일스톤·revision 일치.
- 현행 문서의 구체 오브젝트 ID와 canonical catalog 일치.
- 오브젝트의 `art_asset_id`와 manifest 연결.

**처리**

[검증 스크립트](../scripts/validate_docs.ps1)와 [검증 계획](validation_plan.md)에 위 규칙을 추가했다. 현재 19개 마일스톤, 62개 오브젝트, 329개 에셋, 10개 의뢰와 36개 개별 이슈가 새 검사까지 통과한다.

**상태**: `RESOLVED_IN_AUDIT`

### GGB-REV-2026-0041: 운영 현황 스냅숏의 정본 원칙 위반

**근거**

- [작업 현황 대시보드](work_status_dashboard.md)는 GitHub Project를 현재 상태 정본으로 규정한다.
- [다음 작업 계획](next_work_plan.md)은 8월 2~4일의 `IN_PROGRESS/PLANNED` 상태를 현재형으로 보존한다.
- [마일스톤](milestones.md)도 같은 운영 기반선을 8월 4일 목표 `IN_PROGRESS`로 유지한다.

저장소만으로 GitHub Project의 실제 현재 상태를 판정할 수 없으므로 미완료로 단정하지 않는다. 문제는 로컬 문서가 “언제 조회한 스냅숏인지” 표시하지 않아 정본처럼 읽힌다는 점이다.

**해결안**

- 로컬 현황표에 `snapshot_as_of`를 추가하고 역사 스냅숏임을 명시한다.
- 현재 상태·기한·차단은 GitHub Project에서 조회한 날짜와 함께 동기화한다.
- 외부 조회 없이 오래된 로컬 상태를 `DONE`으로 바꾸지 않는다.

### GGB-REV-2026-0042: Node.js 24 환경 계약 누락

**근거**

- Discord 알림 workflow와 전용 문서는 Node.js 24를 사용한다.
- 기존 [개발 환경](dev_environment.md)은 Godot·Git·Git LFS만 적어 운영 담당자의 로컬 테스트 전제조건이 빠져 있었다.
- 감사 환경에는 `node`가 없어 `node --test scripts/discord_notifications.test.mjs`를 실행하지 못했다.

**처리**

- 개발 환경 문서에 운영 담당자용 Node.js 24 조건, 실행 명령과 CI 대체 증거 원칙을 추가했다.
- Node.js는 일반 Godot 콘텐츠 작업의 필수 도구로 승격하지 않았다.

**남은 증거**

- Node.js 24 환경 또는 GitHub Actions에서 Discord 테스트 통과 로그 확인.

**상태**: `DOC_RESOLVED_TEST_PENDING`

## 7. 이상 없음으로 확인한 범위

- Markdown 182개: strict UTF-8, H1, fence, 상대 링크 검사 통과.
- 결정 11건과 개별 충돌·오류 36건: ID 중복·색인·집계 검사 통과.
- 기존 이슈: 35건 `VERIFIED · DONE`, 1건 `OPEN · READY`; 대장 집계와 일치.
- canonical 오브젝트 62개: 중복 0, 대응 `art_asset_id` 누락 0.
- 에셋 329개: ID·상태·scope·bool·단위 수·목표 마일스톤 검사 통과.
- 의뢰 10건: ID·team·상태·source·asset·brief·revision·목표 마일스톤 검사 통과.
- 의뢰 미포함 에셋 4개는 기술 셰이더로서 `beru` 내부 구현 범위임을 확인.
- Git LFS: 추적 PNG 7개가 LFS 포인터로 관리됨.
- 추적된 `tmp` 중단 저장 파일 없음.
- `git diff --check` 통과.

## 8. 권장 처리 순서

1. `GGB-CNF-2026-0018`의 외부 서고 시계 ID를 분리한다.
2. GitHub Project·Steamworks·Discord의 실제 현재 상태를 확인하고 8월 기한 경과 항목을 재분류한다.
3. 제작 Issue 인증 경로를 재시험하고 미등록 PB 작업만 등록한다.
4. 버티컬 슬라이스 ART·AUD·CNT 의뢰 3건의 팀 수락과 공수 회신을 받는다.
5. `TECH_01_FOUNDATION` 목표일을 재산정하고 production bootstrap부터 구현 증거를 만든다.
6. 창작 잠금 6건의 상태·연결 마일스톤·새 결정일을 명시한다.
7. Node.js 24 또는 CI에서 Discord 테스트를 확인한다.

## 9. 재검증 명령

```powershell
./scripts/validate_docs.ps1
git diff --check
git lfs ls-files
node --test scripts/discord_notifications.test.mjs
```

마지막 명령은 Node.js 24 환경에서만 실행한다. Godot `V1~V5`는 production bootstrap과 해당 fixture가 생긴 뒤 [검증 계획](validation_plan.md)에 따라 활성화한다.
