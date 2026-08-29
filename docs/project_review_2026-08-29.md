# GGB 전체 프로젝트 오류·충돌 재검토 2026-08-29

## 1. 검토 정보

| 항목 | 값 |
| --- | --- |
| 기준 브랜치 | `develop` |
| 기준 커밋 | `f6eb941` (`docs: resolve audit findings and sync accepted requests`) |
| 검토 범위 | 기획 정본, Godot 폴더, 운영 문서, 에셋·오브젝트·의뢰 CSV, GitHub Actions, LFS, 검증 스크립트 |
| 제외 | 팀의 실제 작업 파일, GitHub Project 비공개 필드, Steamworks 관리자 화면, Godot 실기 실행 |
| 판정 원칙 | 증거가 없는 구현·외부 상태는 완료 처리하지 않음 |

이번 검토는 [2026-08-28 감사](project_review_2026-08-28.md)의 해결 커밋을 먼저 고정한 뒤 깨끗한 기준점에서 다시 수행했다. 기획상의 의도적 미정과 실제 정합성 오류를 구분하고, 수정 가능한 문서·검증 오류는 이번 작업에서 교정했다.

## 2. 결론

오류와 충돌이 있었다. 총 8건을 확인했으며, 이 중 문서·검증 오류 4건은 이번 감사에서 해결했다. 나머지 4건은 구현 착수, 팀별 일정 배분 또는 외부 인증·결정 증거가 필요한 운영 위험이다.

| ID | 우선순위 | 현재 상태 | 요약 |
| --- | --- | --- | --- |
| `GGB-REV-2026-0043` | P1 | RESOLVED_IN_AUDIT | 전 의뢰 수락과 배치별 수락 대기 문구·착수 의미 충돌 |
| `GGB-REV-2026-0044` | P2 | RESOLVED_IN_AUDIT | VS 아트 29종 전환 뒤 데모 잔여 의뢰의 28종 표기 잔존 |
| `GGB-REV-2026-0045` | P2 | RESOLVED_IN_AUDIT | V0가 일부 Markdown을 검사하지 않음 |
| `GGB-REV-2026-0046` | P2 | RESOLVED_IN_AUDIT | 문서 CI의 외부 Action 참조가 commit SHA로 고정되지 않음 |
| `GGB-REV-2026-0047` | P1 | MANAGED_AT_RISK | production bootstrap 부재와 연습 씬의 기본 실행·코드 결함 |
| `GGB-REV-2026-0048` | P1 | MANAGED_AT_RISK | 수락 의뢰 10건의 요청별 배분·첫 검토일·착수 게이트 미확정 |
| `GGB-REV-2026-0049` | P1 | EXTERNAL_REVERIFY | `gh` 인증 무효와 GitHub Project·Steamworks 현재 상태 미확인 |
| `GGB-REV-2026-0050` | P1 | MANAGED_AT_RISK | 기술·운영 마일스톤과 창작 잠금의 일정 위험 지속 |

## 3. 이번 감사에서 해결한 사항

### GGB-REV-2026-0043: 수락 상태와 제작 착수 의미 충돌

**발생 위치**

- [의뢰 운영 README](requests/README.md)는 `BATCH-VS01`만 수락 완료로 쓰고, 데모·본편 배치는 이후 수락이라고 적었다.
- 같은 문서의 상태표는 `ACCEPTED`를 단순히 “제작 가능”으로 표시했다.
- [의뢰 대장](requests/request_register.csv)의 ART 4건, AUD 3건, CNT 3건은 모두 `ACCEPTED`다.
- 상세 의뢰서의 미체크된 요청별 배분·첫 검토일 조건이 “팀 수락 조건”으로 남아 팀 패키지 수락과 착수 준비를 혼용했다.

**영향**

팀은 이미 수락한 범위를 다시 수락해야 한다고 오해하거나, 반대로 선행 게이트가 충족되지 않은 데모·본편·상점 배치를 즉시 시작할 수 있었다. 후자의 경우 VS 처리량, 정식명, Steamworks 규격과 기술 기반선 없이 재작업이 발생한다.

**처리**

1. 네 배치를 모두 “범위 수락 완료”로 동기화했다.
2. `ACCEPTED`는 범위·팀 패키지 공수 수락이며 실제 착수는 `depends_on`, `acceptance_gate`, 개별 배분, 첫 검토일을 모두 요구한다고 분리했다.
3. 10개 상세 의뢰서의 “팀 수락 조건”을 “개별 배분·착수” 또는 “제작 완료 조건”으로 고쳤다.
4. 모든 수락 brief에 패키지 수락 완료 문구가 있고, 미체크 착수 조건을 수락 대기로 표기하지 않는지 V0에서 검사한다.

**완료 증거**

- [의뢰 운영 README §3·§5](requests/README.md)
- `REQUEST_ACCEPTED_DOC_STATUS`, `REQUEST_START_GATE`, `REQUEST_ACCEPTED_BRIEF` 검사 통과

### GGB-REV-2026-0044: 버티컬 슬라이스 아트 제외 수량 회귀

**발생 위치**

- 외부 서고 시계 추가로 [버티컬 슬라이스 아트 의뢰](requests/REQ-ART-2026-0001_버티컬슬라이스.md)는 29종이 됐다.
- [데모 잔여 아트 의뢰](requests/REQ-ART-2026-0002_공개데모잔여.md)는 배타적 목록 115종과 전체 합산은 맞지만, 설명 두 곳이 VS 28종 제외로 남았다.

**영향**

외부 서고 시계를 VS와 데모 잔여 팀이 중복 제작하거나, 229종 전수성 계산을 신뢰하지 못할 수 있었다.

**처리**

- 두 문구를 29종으로 교정했다.
- 본 의뢰의 115종 목록은 변하지 않아 기존 팀 범위 수락을 유지하고 변경 이력에 비범위 정정을 기록했다.
- ART·AUD 요청 에셋이 서로 중복되지 않고 각 팀 매니페스트 행을 전부 덮는지 검사한다.
- 데모 잔여 의뢰의 VS 제외 수량을 실제 VS 요청 수에서 계산해 검사한다.

**완료 증거**

```text
ASSETS=330
REQUESTED_ART_AUD=326
UNCOVERED_NONTECH=0
DUP_REQUESTED=0
UNKNOWN=0
```

### GGB-REV-2026-0045: V0 Markdown 검사 범위 누락

**발생 위치**

[검증 스크립트](../scripts/validate_docs.ps1)는 루트 `README.md`, `docs/`, `ideas/`만 검사해 `CONTRIBUTING.md`, `THIRD_PARTY_NOTICES.md`, `game/README.md`를 검사하지 않았다. [검증 계획](validation_plan.md)은 모든 현행 Markdown의 UTF-8·H1·fence·링크를 검사한다고 설명했다.

**영향**

기여 규칙, 라이선스 고지, Godot 상태 안내에서 링크나 인코딩 오류가 생겨도 CI가 통과할 수 있었다.

**처리**

- 루트 운영 문서와 `game/`을 Markdown 검사 대상에 추가했다.
- 현재 186개 Markdown의 strict UTF-8, H1, fence와 로컬 링크 검사가 통과한다.
- [검증 계획 §4](validation_plan.md)의 실제 범위를 동기화했다.

### GGB-REV-2026-0046: GitHub Action 참조 고정 불일치

**발생 위치**

- Discord 워크플로는 외부 Action을 40자리 commit SHA로 고정했다.
- 문서 검증 워크플로의 `actions/checkout@v4`만 이동 가능한 tag를 사용했다.

**영향**

같은 저장소 안에서 CI 공급망 기준이 달랐고, tag가 이동하면 검토하지 않은 Action 코드가 실행될 수 있었다.

**처리**

- [문서 검증 워크플로](../.github/workflows/validate-docs.yml)의 checkout을 기존 사용 중인 `de0fac2e4500dabe0009e67214ff5f5447ce83dd`로 고정했다.
- 모든 워크플로의 외부 `uses:` 참조가 40자리 SHA인지 `ACTION_REF_NOT_PINNED`으로 검사한다.

## 4. 남아 있는 운영·구현 위험

### GGB-REV-2026-0047: production bootstrap 부재와 연습 씬 결함

**발생 위치**

- [Godot 프로젝트](../game/project.godot)의 앱 이름은 `임시`, 기본 씬은 `res://signal_practice.tscn`이다.
- production main scene, autoload, 사건 Resource, 저장 fixture, export preset은 없다.
- `key.gd`는 클릭 뒤 `key_clicked=1`만 쓰고 버튼을 숨기거나 비활성화하지 않으며 인벤토리 이동도 구현하지 않았다.
- 현재 셸에서는 Godot 실행 파일을 찾지 못해 headless import와 GDScript parse를 수행할 수 없었다.
- [검증 계획](validation_plan.md)의 `V1~V5`는 모두 `NOT_IMPLEMENTED`다.

**영향**

연습 씬을 버티컬 슬라이스나 제작 기반선으로 오인할 수 있다. 현재 리소스 경로 존재 검사는 통과했지만, Godot parse·실행·Windows export의 정상 여부는 증명되지 않았다.

**해결안**

1. 개발 capacity와 `TECH_01_FOUNDATION` 새 목표일을 먼저 확정한다.
2. 연습 씬을 격리 또는 폐기하고 `scenes/main/` production bootstrap을 만든다.
3. `GameState → EventManager → StateWriter → SaveManager` 최소 경로와 schema 1 fixture를 구현한다.
4. 연습 코드를 보존한다면 열쇠 획득 시 `visible=false`, 입력 비활성화, 인벤토리 writer 호출과 `pressed` 기반 확정을 구현한다.
5. Godot 4.7 headless import·parse, Windows debug export를 통과한 뒤에만 main scene과 앱 식별자를 바꾼다.

**현재 통제**

[game 상태 안내](../game/README.md)에 연습 씬의 한계와 production 전환 조건을 명시했다. 구현 완료는 아직 아니다.

**완료 증거**

- production main scene과 내부 앱 식별자
- V1 headless import·GDScript parse 로그
- 최소 상태·저장 fixture
- V4 Windows debug export 로그

### GGB-REV-2026-0048: 요청별 일정과 착수 게이트 미확정

**발생 위치**

- 10개 의뢰는 모두 범위 수락 상태다.
- ART·CNT는 팀 전체 패키지 2주, AUD는 1개월의 경과 공수만 있다.
- 요청별 담당, 묶음별 시간, 첫 검토일은 `REBASELINE_REQUIRED`다.
- VS 이후 배치는 처리량·데모 제작률·정식명·Steamworks 규격 게이트가 아직 충족되지 않았다.

**영향**

현재 2026-09-18 버티컬 슬라이스 목표를 신뢰할 수 없다. 특히 기술 기반선과 한 달 AUD 경로를 합치지 않은 채 제작을 시작하면 통합 순서가 뒤집힌다.

**해결안**

1. 먼저 `BATCH-VS01`의 ART·AUD·CNT 담당과 첫 검토일을 배분한다.
2. 기술 bootstrap과 세 팀의 실제 시작 가능일을 한 임계 경로로 합산한다.
3. 가장 긴 AUD 경로, 통합·수정·QA 시간을 포함해 `PROD_01_VERTICAL_SLICE`를 재산정한다.
4. 실제 작업 파일·work ID·Drive revision이 생긴 대상만 매니페스트 `WORKING`으로 전이한다.
5. VS 실측 전에는 `BATCH-DEMO02` 이후 배치를 착수하지 않는다.

**완료 증거**

- 10개 brief의 `assigned_contributors`, 묶음별 공수, 첫 검토일
- 요청별 `acceptance_gate` 충족 증거
- 매니페스트 `WORKING` 행의 request·work·Drive revision

### GGB-REV-2026-0049: GitHub·Steam 외부 상태 재확인 필요

**발생 위치**

- `gh auth status`는 `devb-eru` 기본 token이 무효라고 보고한다.
- Git fetch·push와 공개 REST 읽기는 가능하지만 Issue·Project 쓰기는 인증되지 않았다.
- GitHub Project custom status와 Steamworks 가입·AppID·상점 관리자 상태는 이번 감사에서 읽지 못했다.

**영향**

로컬 `PB-*`를 실제 GitHub 작업으로 등록하거나, Steam 마일스톤을 완료로 판정할 수 없다. 공개 Issue의 OPEN/CLOSED만으로 Project custom status를 대신할 수도 없다.

**해결안**

1. 사용자가 `gh auth login -h github.com`으로 재인증한다.
2. 후보 제목 중복을 검색하고 미등록 `PB-*`만 Issue로 만든다.
3. Project의 Status·Priority·Actual Owner·Target Date·Blocked Reason을 읽어 로컬 스냅숏을 갱신한다.
4. Steamworks 관리자 화면에서 가입, 수수료, AppID, 상점 심사 상태를 별도로 확인한다.

**완료 증거**

- 유효한 `gh auth status`
- 실제 `GGB-WRK-*` URL과 Project 필드 스냅숏 시각
- Steamworks 화면 근거와 확인일

### GGB-REV-2026-0050: 마일스톤·창작 잠금 일정 위험

**발생 위치**

- [마일스톤](milestones.md)의 운영, Steam 온보딩, 기술 기반선, 버티컬 슬라이스, 상점 공개 5개가 `AT_RISK`다.
- [창작 잠금](creative_lock_schedule.md)의 정식명, 태그라인, 주인공 화면명·연령대, 마라 이름, 마라 2 외형 연령 6개가 `OPEN · AT_RISK · REBASELINE_REQUIRED`다.

**영향**

수락된 아트·대사·사운드 범위를 그대로 시작하면 화면 이름, 비율, 로고, 서명 cue와 상점 자산의 재작업이 발생할 수 있다.

**해결안**

1. 정식명·주인공 표시 정책·마라 이름처럼 ID·번역에 영향을 주는 결정을 먼저 잠근다.
2. 연령대·외형 비율은 ART 첫 제작 전 검토한다.
3. 각 결정은 `LOCKED` 근거와 영향 문서를 같은 변경에서 갱신한다.
4. 처리량과 기술 capacity가 나온 뒤 5개 마일스톤의 새 목표일을 한 번에 재산정한다.

**완료 증거**

- 6개 잠금의 `LOCKED` 근거 또는 명시적 유지 결정
- 책임자·입력값·버퍼가 있는 마일스톤 재기준화 기록

## 5. 이상 없음으로 확인한 범위

| 범위 | 결과 |
| --- | --- |
| v0.4 충돌·오류 | 36건 전부 `VERIFIED · DONE`, 열린 항목 0 |
| 정본 오브젝트 | 63개, 중복·미등록 참조 0 |
| 에셋 매니페스트 | 330행, ART 229·AUD 97·기술 4 |
| 팀 의뢰 | 10건 모두 `ACCEPTED`, ART·AUD 에셋 중복·누락 0 |
| Markdown | 186개 UTF-8·H1·fence·로컬 링크 검사 통과 |
| LFS | PNG 7개 pointer, `git lfs fsck` 통과 |
| 파일 경로 | 대소문자 충돌 0, 추적 임시 파일 0, 현재 `res://` 참조 대상 누락 0 |
| Discord 스크립트 | Node.js 24.19.0, 15개 테스트 통과 |
| Git 객체 | `git fsck --no-dangling` 오류 없음 |
| 예약 문법 | GitHub Actions의 IANA `timezone` 사용은 현행 공식 구문과 일치 |

예약 문법 근거: [GitHub Actions workflow syntax: `on.schedule`](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#onschedule)

## 6. 권장 처리 순서

1. GitHub CLI 재인증과 Project·Steamworks 외부 상태 재확인.
2. 개발 capacity 확정과 `TECH_01_FOUNDATION` production bootstrap 착수.
3. `BATCH-VS01`의 팀별 담당·첫 검토일 배분.
4. 정식명·주인공 표시·마라 이름·외형 잠금 결정.
5. 기술·AUD·ART·CNT 임계 경로를 반영한 버티컬 슬라이스 재산정.
6. 실제 작업 증거가 생긴 요청과 에셋만 `IN_PROGRESS`·`WORKING`으로 전이.

## 7. 재검증 명령

```powershell
./scripts/validate_docs.ps1
node --test scripts/discord_notifications.test.mjs
git lfs fsck
git fsck --no-dangling
git diff --check
```

Godot 실행 파일과 production bootstrap이 준비된 뒤 추가한다.

```powershell
godot --headless --path game --editor --quit
```
