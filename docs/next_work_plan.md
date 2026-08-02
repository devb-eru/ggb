# GGB 다음 작업 계획

## 1. 목표

확정된 기획을 실제 제작 가능한 작업으로 옮기고, 이를 지원하는 협업 시스템을 운영한다. 기술 기반선과 버티컬 슬라이스가 운영 자동화보다 우선한다.

```text
M1 기획 기준선 검토·병합
→ 제품 계약 충돌 해소
→ 제작 백로그 GitHub 정본화
→ 기술 기반선·버티컬 슬라이스
→ 실측 기반 일정 재산정
→ Discord 알림·에셋 접수
→ 작업 현황 대시보드
→ 일정 조율
→ 오늘의 회의 안건 자동 생성
```

2026-07-27에 M1의 객관적 완료 조건, 정적 회귀 검사, `niik`·`gatam` 검토와 `main` 병합을 모두 확인했다. GitHub Project 기반선을 완료하고 같은 날 2단계 에셋 접수 흐름을 시작했다.

## 2. 1단계: M1 v0.4 기획 기준선

| 날짜 | 작업 | 책임자 | 참여·검토 | 종료 조건 | 상태 |
| --- | --- | --- | --- | --- | --- |
| 07-19 | `GGB-CNF-2026-0003` 정상 리셋 순서 문서 통일 | `beru` | `niik`, `gatam` 검토 | `02`, `07`, `17` 순서 일치 | `DONE` 07-18 조기 완료 |
| 07-19 | `GGB-CNF-2026-0004` HIGH·ALL 판정 통일 | `gatam` | `beru` 검토 | 관계 결산 정의 일치 | `DONE` 07-18 조기 완료 |
| 07-20 | `GGB-ERR-2026-0002` 리셋 복구 스키마 | `beru` | `niik` | 단계별 재개·멱등 조건 정의 | `DONE` 07-18 조기 완료 |
| 07-20 | `GGB-ERR-2026-0005` 전원 완료 파생 상태 | `beru` | `gatam` | 실시간·로드 후 갱신 정의 | `DONE` 07-18 조기 완료 |
| 07-21 | `GGB-ERR-2026-0003` 실패·숏컷 재개 스키마 | `beru` | `niik` | B/C/D 재개 데이터 정의 | `DONE` 07-18 조기 완료 |
| 07-21~22 | P1 회귀 검사와 문서 동기화 | `gatam` | `beru`, `niik` | P1 전부 `VERIFIED` 또는 허용된 `DEFERRED` | `DONE` 07-18 조기 완료 |
| 07-22 | M1 연장 게이트 | `beru` | 각 팀장 | P1이 하나라도 남으면 07-30으로 변경 | `PASS` P1 잔여 0건 |
| 07-23~27 | P2·P3 처리, 전체 회귀, M1 검토·병합 | `beru` | `gatam`, `niik` | M1 DoD 충족, 팀 승인과 `main` 병합 | `DONE` 07-27 |

P2·P3 권장 순서는 `ERR-0001 → ERR-0006 → CNF-0006 → ERR-0007`이다. 7월 23일에 무리하게 모두 완료하지 않고 개발을 막지 않는 항목은 재검토 조건과 후속 마일스톤을 기록해 `DEFERRED`할 수 있다.

### M1 잔여 작업 실행안

| 목표일 | 작업 | 담당·검토 | 종료 조건 |
| --- | --- | --- | --- |
| 07-19 | `GGB-ERR-2026-0001` 마라 2 병합·분리 저장 효과 | `beru`·`gatam` | `DONE` 07-18 조기 완료; 선택 결과와 후속 대사·엔딩 반응이 저장·로드 후 동일 |
| 07-20 | `GGB-ERR-2026-0006` E3_5·이리스 데이터 계약 | `beru`·`gatam` | `DONE` 07-18 조기 완료; E3_5 노드와 이리스 6상태를 F2·두 엔딩이 동일하게 참조 |
| 07-21 | `GGB-CNF-2026-0006` 위장 필터 변수 극성 | `beru`·`niik` | `DONE` 07-18 조기 완료; ACTIVE·DISABLED·BROKEN 단일 enum과 당시 state model r7 정규화 규칙 확정. 배포 migration 아님 |
| 07-22~27 | `GGB-ERR-2026-0007` 통합 문서 구식 표기 제거 | `gatam`·`beru` | `DONE`; `00`, `README`, `18` 역할·용어·링크 재검증 통과 |
| 07-27 | M1 전체 회귀·승인 | `beru`·각 팀장 | `DONE`; OPEN 0, 25/25 VERIFIED/DONE, Markdown 정적 검사 PASS, PR #14 병합과 팀 승인 기록 |

## 3. 2단계: 제작 전환

제작 작업의 전체 분해와 등록 조건은 [제작 전환 백로그](production_backlog.md)를 따른다.

| 순서 | 작업 | 현 상태 | 다음 판정 |
| ---: | --- | --- | --- |
| 1 | 제품·접근성·데모·저장 계약 통합 | 문서 완료 | 교차 문서 정적 검사 |
| 2 | 개인별 capacity 확인 | 미확인 | 팀 입력 뒤 잠정 날짜 재산정 |
| 3 | 기술 기반선·버티컬 슬라이스 Issue 등록 | 미등록 | GitHub Project 필드·선행 관계 확인 |
| 4 | 에셋 BOM·현지화·검증 작업 등록 | 미등록 | owner·검토자·마일스톤 확인 |
| 5 | 구현 착수 | 현재 범위 제외 | 사용자가 구현 시작을 지시한 뒤 진행 |

구현이 시작되지 않았으므로 production bootstrap, save runtime, CI와 Windows export는 완료로 표시하지 않는다.

## 4. 3단계: 협업 시스템 구현

| ID | 가장 빠른 날짜 | 작업 | 책임자 | 선행 | 완료 조건 | 상태 |
| --- | --- | --- | --- | --- | --- | --- |
| [`GGB-WRK-2026-0001`](https://github.com/devb-eru/ggb/issues/15) | 07-27 | GitHub Issue·Project 기반선 | `beru` | M1 병합 | 상태·우선순위·담당·마일스톤·차단 필드와 기본 뷰 생성 | `DONE` |
| [`GGB-WRK-2026-0002`](https://github.com/devb-eru/ggb/issues/17) | 07-27 | Discord 에셋 접수·보관 흐름 | `beru` | WRK-0001, Google Drive | `#asset-intake`에서 제작자·작업 ID·전달일·보관 위치 추적 | `DONE` 08-01: 권한·업로드·핀·PR #18 병합 확인 |
| [`GGB-WRK-2026-0003`](https://github.com/devb-eru/ggb/issues/19) | 07-31 | GitHub→Discord 선별 알림 | `beru` | WRK-0001, webhook secret | 중요 사건 실시간·일반 변경 21:30 요약 | `DONE` 08-02: 최초 예약 실행 기준선 저장, 다음 실행 캐시 복원·중복 없음, 예약 실행 29건 성공 확인 |
| [`GGB-WRK-2026-0004`](https://github.com/devb-eru/ggb/issues/22) | 08-01 | 작업 현황 대시보드 | `beru` | WRK-0001 | 담당자·마일스톤·차단·지연·검토 대기 뷰 제공 | `DONE` 08-02: 저장 뷰 8개 구성, PR #23 병합과 검사 통과 확인 |
| [`GGB-WRK-2026-0005`](https://github.com/devb-eru/ggb/issues/24) | 08-02 | GitHub 일정·Discord 회의 연결 | `beru` | WRK-0001, WRK-0003~0004, Discord 권한 | GitHub 마감 정본과 Discord 금요일 회의 이벤트 연결 | `IN_PROGRESS`: Issue·Project 등록, 기존 주간 이벤트와 `회의실` 확인, 반복 시리즈 정비·운영 문서 검증 중 |
| `GGB-WRK-2026-0006` | 08-03 | 오늘의 회의 안건 생성 | `beru` | WRK-0003~0005 | 금요일 21:30에 기한 임박·BLOCKED·REVIEW를 Discord에 요약 | `PLANNED` |
| `GGB-WRK-2026-0007` | 08-04 | 운영 리허설 | `gatam` | WRK-0001~0006 | 가상 작업 1건을 등록→알림→회의→완료까지 통과 | `PLANNED` |

### GitHub Project 작업 현황 뷰

[GGB Production](https://github.com/users/devb-eru/projects/1)에 다음 뷰와 필터를 구성했다.

- `전체`: 모든 Project 항목과 운영 필드.
- `활성`: `IN_PROGRESS`, `READY`, `BLOCKED`, `REVIEW`; 우선순위 순.
- `차단`: `BLOCKED`; 목표일 순으로 원인과 해제 조건 확인.
- `검토 대기`: `REVIEW`; 오래 갱신되지 않은 순으로 검증 근거 확인.
- `마일스톤`: 미완료이면서 GitHub Milestone이 있는 항목의 Roadmap.
- `팀별`: 활성 작업을 실제 담당 팀으로 그룹화.
- `담당자`: 활성 작업을 실제 담당자로 그룹화.
- `지연`: 목표일이 지난 활성 작업.

필드와 등록 절차는 [GitHub Issue·Project 운영](github_project.md), 표시 필드와 사용 순서는 [작업 현황 대시보드](work_status_dashboard.md)를 따른다. 정확한 REVIEW 진입 후 24시간 계산은 상태 변경 이력이 필요한 `GGB-WRK-2026-0006`에서 구현한다.

### Discord 기본 알림 정책

- 즉시 알림: PR 생성·검토 요청·병합, `BLOCKED`, `P0/P1`, 마일스톤 변경, 릴리스·배포·CI 실패, `develop/main` push.
- 21:30 요약: 작업 브랜치 커밋, 일반 Issue 수정과 댓글.
- 제외: 단순 라벨·설명 수정과 봇의 반복 갱신.
- 대상 채널: `#git-updates`.
- 에셋 접수 메시지 필수값: 작업 ID, 제작자, 에셋 종류, 버전, 사용 위치, 원본 여부.

### 오늘의 회의 안건 순서

1. 오늘 결정하지 않으면 멈추는 `P0/P1`·`BLOCKED`.
2. 48시간 안에 마감되는 작업.
3. 검토 대기 24시간 이상인 작업.
4. 담당자 없는 작업과 일정 초과 작업.
5. 팀 간 전달이 필요한 아트·사운드·개발 의존성.
6. 결정·담당자·목표일을 회의 결과로 기록.

## 5. 병행 작업: Steam 출시 준비

| ID | 목표일 | 작업 | 책임자 | 완료 조건 |
| --- | --- | --- | --- | --- |
| `GGB-WRK-2026-0008` | 08-03 | 개인 명의 온보딩 서류 준비 | `beru` | 법적 이름·은행·세금 서류 준비 여부 자체 점검 |
| `GGB-WRK-2026-0009` | 07-31 | 한·영 게임명과 한 문장 소개 후보 | `gatam` | 각 3안 작성, `beru` 1안 승인 |
| `GGB-WRK-2026-0010` | 08-14 | Steamworks 가입·AppID | `beru` | 계정, 수수료, 기본 게임 AppID 완료 |
| `GGB-WRK-2026-0011` | 12-18 | 가격·출시 할인 결정 | `beru` | 비교작·플레이 시간·지역 가격을 근거로 승인 |
| `GGB-WRK-2026-0012` | 12-18 | 최소·권장 사양 확정 | `beru` | 기준 장비·성능 계측·Windows 10/11 검증 |

민감한 Steamworks 정보는 저장소, Issue, Discord에 기록하지 않는다. 완료 여부와 차단 사유만 추적한다.

## 6. 구현 전 준비 상태

현재 운영 입력은 다음과 같이 확정됐다.

- 개인별 실제 가용시간은 아직 저장소에서 검증되지 않았다. 확인 전에는 주말·초과 근무를 일정에 넣지 않고 [프로젝트 역할](project_roles.md#2-가용시간과-계획-용량)의 70/30 용량 규칙을 적용한다.
- Discord 서버 관리 권한 있음.
- 채널: `#git-updates`, `#asset-intake`.
- 회의: 매주 금요일 22:00 KST, 전원 참석, 기본 60분·종료 유동적.
- 일정: GitHub Project 날짜가 정본, Discord는 회의·알림 화면.

확인된 준비 상태:

- 편집 원본 보관소 [Google Drive `GGB/Assets`](https://drive.google.com/drive/folders/1S8S8CSfpfO2ToszpAbSRaJqGgNRAqVoD)와 단계 폴더 5개를 생성했다. 2026-08-01에 팀 권한·시험 업로드·Discord 핀과 PR #18 병합을 확인하고 `GGB-WRK-2026-0002`를 종료했다.
- `#git-updates` webhook은 GitHub Actions secret `DISCORD_GIT_UPDATES_WEBHOOK`으로 등록 완료했다.
- 개인 `GGB Production` Project의 중요 상태 감시용 `PROJECTS_READ_TOKEN`을 등록했다. Project dry-run은 중요 항목 3건을 읽었고, 2026-08-01~02 최초 예약 실행의 무알림 기준선 저장과 다음 실행의 캐시 복원·중복 없음까지 확인했다.
- GitHub Project #1을 `GGB Production`으로 정식화하고 저장소 연결, 필드 22개와 첫 Issue #15를 구성했다. 2026-08-01에는 작업 현황 저장 뷰를 8개로 확장했다.
- Discord 서버 `게임개발일지`의 기존 주간 이벤트와 음성 채널 `회의실`을 확인했다. `GGB-WRK-2026-0005`에서 금요일 22:00 KST 기준으로 반복 시리즈를 정비한다.

## 7. 완료 판정

운영 기반은 다음 시나리오가 한 번 끝까지 통과하면 완료한다.

```text
작업 등록
→ 담당·기한·완료 조건 지정
→ Discord 알림
→ BLOCKED 또는 REVIEW 변화 반영
→ 회의 안건에 자동 포함
→ 결정·후속 작업 기록
→ DONE과 검증 근거 확인
```
