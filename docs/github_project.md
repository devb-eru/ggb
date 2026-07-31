# GGB GitHub Issue·Project 운영

## 1. 기준 위치

- 저장소: [devb-eru/ggb](https://github.com/devb-eru/ggb)
- 작업 Project: [GGB Production](https://github.com/users/devb-eru/projects/1)
- 최초 운영 작업: [GGB-WRK-2026-0001](https://github.com/devb-eru/ggb/issues/15)

GitHub Issue는 목적·범위·완료 조건·검증 근거의 기록이고, GitHub Project는 상태·우선순위·담당·일정·차단의 정본이다. Discord는 이를 전달하는 알림·회의 화면이며 값을 직접 소유하지 않는다.

## 2. Issue와 Project의 책임

| 위치 | 소유 정보 |
| --- | --- |
| Issue 제목 | 작업 ID와 결과 중심 제목 |
| Issue 본문 | 배경, 포함·제외 범위, 완료 조건, 관련 문서·PR, 상세 검증 근거 |
| Project 필드 | 현재 상태, 우선순위, 유형, 실제 담당자, 담당 팀, 시작일, 목표일, 차단 정보, 짧은 검증 근거 |
| GitHub Assignees | 저장소에 실제로 반영하는 GitHub 계정 |
| GitHub Milestone | 결과물이 포함될 일정 기준선 |
| Discord | 변경 알림, 전달 확인, 회의 논의 |

Issue 본문의 작업 정보는 등록 시점의 설명이다. 이후 상태·목표일·담당자가 달라지면 Project 필드를 먼저 갱신하고, 변경 이유가 필요할 때 Issue 댓글 또는 변경 이력을 남긴다.

## 3. 필드 기준선

기본 필드를 포함해 총 22개 필드를 사용한다.

| 필드 | 값·형식 | 규칙 |
| --- | --- | --- |
| `Status` | `BACKLOG`, `READY`, `IN_PROGRESS`, `REVIEW`, `BLOCKED`, `DONE` | 공통 작업 상태 정본 |
| `우선순위` | `P0`, `P1`, `P2`, `P3` | 처리 순서 |
| `유형` | `FEATURE`, `CONTENT`, `ART`, `AUDIO`, `BUG`, `DOCS`, `QA`, `OPS`, `CNF`, `ERR` | 작업 종류 |
| `실제 담당자` | `beru`, `niik`, `gatam`, `210`, `nana`, `NOne`, `UNASSIGNED` | 실제 작업 책임자 |
| `담당 팀` | `기획`, `아트`, `사운드`, `개발`, `QA`, `릴리즈`, `운영` | 기본 팀 분류 |
| `시작일` | 날짜 | 실제 착수일 |
| `목표일` | 날짜 | 현재 합의된 목표일 |
| `차단 원인` | 텍스트 | 차단 작업 ID 또는 결정 |
| `차단 해제 조건` | 텍스트 | 다시 시작할 수 있는 확인 조건 |
| `검증 근거` | 텍스트 | PR·커밋·QA·빌드의 짧은 참조 |

`Title`, `Assignees`, `Labels`, `Milestone`, `Repository`, `Linked pull requests`, `Reviewers`, `Parent issue`, `Sub-issues progress`, `Created`, `Updated`, `Closed`는 GitHub 기본 필드를 그대로 사용한다.

## 4. 기본 뷰

| 뷰 | 저장 필터 | 목적 |
| --- | --- | --- |
| `전체` | 없음 | Project의 모든 항목 |
| `오늘` | `status:IN_PROGRESS,READY,BLOCKED,REVIEW` | 지금 행동이 필요한 활성 작업 |
| `차단` | `status:BLOCKED` | 차단 원인과 해제 조건 확인 |
| `검토` | `status:REVIEW` | 검토 대기와 검증 근거 확인 |
| `마일스톤` | `has:milestone` | 일정 기준선에 연결된 작업 |
| `팀별` | `has:"담당 팀"` | 실제 담당 팀이 지정된 작업 |

그룹화·차트·지연 표시 등 대시보드 고도화는 `GGB-WRK-2026-0004`에서 수행한다.

## 5. GitHub 계정이 없는 팀원

`gatam`, `210`, `nana`, `NOne`의 저장소 반영은 `beru`가 담당한다.

- `Assignees`: `devb-eru`.
- `실제 담당자`: 실제 팀원.
- Issue 또는 PR: `contributor: 팀원명`, Discord 전달일, 작업 ID, 반영 파일을 기록.
- 검토 결과: Discord에서 확인한 사람이 `beru`에게 전달하고, `beru`가 관련 Issue 또는 PR 댓글에 요약.

커밋 작성자와 실제 제작자를 동일인으로 추정하지 않는다.

## 6. 작업 등록 순서

1. `GGB-WRK`, `GGB-CNF`, `GGB-ERR` ID로 Issue를 만든다.
2. 목적, 포함·제외 범위, 완료 조건과 선행 항목을 작성한다.
3. Issue를 `GGB Production`에 추가한다.
4. `Status`, 우선순위, 유형, 실제 담당자, 담당 팀, 마일스톤과 날짜를 입력한다.
5. 시작할 때 `IN_PROGRESS`, 변경 제출 뒤 `REVIEW`로 전환한다.
6. 검증 근거를 입력하고 검토가 끝나면 `DONE`으로 전환한 뒤 Issue를 닫는다.

`BLOCKED`에는 `차단 원인`과 `차단 해제 조건`이 모두 있어야 한다. `DONE`에는 PR·커밋·QA·빌드 중 하나 이상의 검증 근거가 있어야 한다.

## 7. 기준선 검증

2026-07-27에 다음을 확인했다.

- Project 제목·설명·저장소 연결.
- 필드 22개와 상태 6종.
- 주요 마일스톤 13개.
- 필터가 저장된 기본 뷰 6개.
- Issue #15의 Assignee·Milestone·Status·P1·OPS·beru·운영·날짜 필드.

Discord 자동 알림, 에셋 접수, 일정·회의 연결과 운영 리허설은 `GGB-WRK-2026-0002~0007`에서 이어서 검증한다.

## 8. Discord 중요 상태 감시

개인 소유 `GGB Production` Project의 `BLOCKED`·`P0/P1` 진입은 저장소 이벤트가 아니라 5분 읽기 조회로 감시한다. `PROJECTS_READ_TOKEN`은 `read:project`만 가진 repository secret으로 보관하고 Project 값을 수정하는 데 사용하지 않는다. 상세 활성화·실패 처리와 테스트는 [GitHub→Discord 선별 알림 운영](discord_notifications.md)을 따른다.
