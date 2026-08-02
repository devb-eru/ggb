# GitHub→Discord 선별 알림 운영

## 1. 목적과 정본

GitHub Issue·Project·PR의 중요한 변화만 Discord `#git-updates`에 전달한다. Discord는 알림 화면이고 상태·담당·기한의 정본은 계속 GitHub다.

구현은 [`.github/workflows/discord-notifications.yml`](../.github/workflows/discord-notifications.yml)과 [`scripts/discord_notifications.mjs`](../scripts/discord_notifications.mjs)로 구성한다. 외부 GitHub Action에 webhook을 맡기지 않고 저장소 코드가 Discord webhook에 직접 전송한다.

## 2. 알림 기준

| 경로 | 대상 | 지연 목표 | 제외 |
| --- | --- | --- | --- |
| 즉시 이벤트 | `develop`·`main` push, PR 생성·검토 요청·변경 요청·병합, 마일스톤 목표일, 릴리스, 배포 결과, 지정 CI 실패 | 이벤트 발생 후 5분 이내 | 닫혔지만 병합되지 않은 PR, CI 성공, 목표일 외 마일스톤 설명 수정 |
| Project 감시 | `GGB Production` 항목이 `BLOCKED`가 되거나 우선순위가 `P0/P1`이 됨 | 통상 5분 주기 | 그 밖의 상태·필드 변경 |
| 회의 안건 | `BLOCKED`·`P0/P1`, 다음 회의 전 마감, `REVIEW` 24시간+, 일정 초과, 실제 담당자 누락 | 금요일 21:30 KST | 완료 작업, 같은 작업의 낮은 우선순위 구역 중복 |
| 24시간 요약 | 작업 브랜치 커밋, 새 Issue와 생명주기 변화, 사람의 Issue·PR 댓글, PR review | 금요일을 제외한 매일 21:30 KST | 단순 라벨·설명 수정, 봇 활동, 변화가 없는 날 |
| Issue 라벨 보조 경로 | 저장소 Issue에 `p0`, `p1`, `blocked` 라벨 추가 | 즉시 | 그 밖의 라벨 |

금요일에는 24시간 요약 대신 회의 안건 하나만 보낸다. 안건이 없어도 Project 링크와 준비 상태를 보내므로 22:00 회의의 시작 여부를 확인할 수 있다.

개인 소유 Project에는 저장소 GitHub Actions가 직접 받을 수 있는 Project V2 변경 이벤트가 없으므로 혼잡한 정각을 피한 5분 간격의 읽기 전용 조회를 사용한다. GitHub 예약 실행은 부하에 따라 지연되거나 드물게 누락될 수 있으므로 엄격한 5분 SLA가 아니라 best-effort 감시다. 이 경로만 별도 토큰이 필요하며, 토큰이 없거나 조회에 실패해도 저장소 이벤트 알림은 독립적으로 동작한다.

## 3. GitHub Actions 설정

저장소 `Settings → Secrets and variables → Actions`에 다음 repository secret을 둔다.

| Secret | 권한 | 상태·용도 |
| --- | --- | --- |
| `DISCORD_GIT_UPDATES_WEBHOOK` | Discord `#git-updates` webhook URL | 등록 완료. 모든 실제 전송에 필요 |
| `PROJECTS_READ_TOKEN` | `devb-eru`의 classic PAT, `read:project`만 선택 | 등록 완료. 개인 Project 중요 상태 감시에만 사용 |

`PROJECTS_READ_TOKEN`은 다음 기준을 따른다.

1. GitHub의 classic personal access token을 만들고 `read:project`만 선택한다.
2. 만료일은 90일 이하를 권장하며 교체일을 개인 일정으로 관리한다.
3. 토큰 원문은 Discord, Issue, PR, commit 또는 이 문서에 남기지 않는다.
4. GitHub 저장소 secret으로 저장한 뒤 원문을 다시 공유하지 않는다.

`GITHUB_TOKEN`은 Actions가 자동 발급한 저장소 읽기 토큰만 사용한다. 기본 권한은 `contents: read`이고, 24시간 요약 job에만 `issues: read`와 `pull-requests: read`를 추가한다.

## 4. 활성화와 확인 순서

예약 실행과 `workflow_dispatch`는 기본 브랜치의 workflow를 기준으로 한다. 따라서 다음 순서로 활성화한다.

1. 구현 PR을 `develop`에 병합한다.
2. `develop` 검증이 끝나면 운영 규칙에 따라 `main`에 동기화한다.
3. Actions secret `PROJECTS_READ_TOKEN`을 등록한다.
4. `Actions → Discord GitHub notifications → Run workflow`에서 `mode=smoke`, `dry_run=true`를 실행해 payload와 로그를 확인한다.
5. 같은 경로를 `dry_run=false`로 한 번 실행해 `#git-updates` 수신을 확인한다.
6. `mode=project`, `dry_run=true`로 현재 `BLOCKED`·`P0/P1` 예상 목록을 먼저 확인한다.
7. 최초 5분 예약 실행이 기존 항목을 알리지 않고 현재 Project 상태를 기준선으로 저장하는지 확인한다.
8. 다음 예약 실행이 캐시를 복원하고, 중요 변경이 없을 때 중복 알림을 보내지 않는지 확인한다.
9. `mode=agenda`, `dry_run=true`로 안건 순서, 중복 제거, 목표일과 담당자 표시를 확인한다.

실제 전송 확인 결과는 `GGB-WRK-2026-0003` Issue와 Project의 `검증 근거`에 Actions 실행 URL로 남긴다.

### 2026-08-02 활성화 상태

- smoke dry-run과 실제 `#git-updates` 전송을 통과했다.
- 24시간 digest dry-run을 통과했다.
- Project dry-run에서 토큰 접근과 `BLOCKED`·`P0/P1` 매핑을 확인했다.
- [최초 예약 Project 조회](https://github.com/devb-eru/ggb/actions/runs/30663574483)가 기존 항목을 알리지 않고 기준선을 저장했다.
- [다음 예약 조회](https://github.com/devb-eru/ggb/actions/runs/30667553868)가 캐시를 복원하고 중요 변경이 없을 때 중복 알림을 보내지 않았다.
- 예약 실행 29건이 모두 성공했으며 [최신 확인 실행](https://github.com/devb-eru/ggb/actions/runs/30748329393)도 같은 기준선을 복원했다.

Project 실제 수동 실행은 현재 작업 제목을 Discord로 보내고 상태 캐시를 바꾸므로 생략했다. 예약 실행 두 번으로 초기 기준선과 중복 억제를 검증했고, 이후 예약 실행으로 계속 감시한다.

## 5. 안전장치와 실패 처리

- PR 알림은 같은 저장소의 사람 PR만 처리하고 외부 fork와 Dependabot PR은 제외한다. webhook secret을 쓰는 단계는 PR 코드가 아닌 대상 브랜치의 신뢰된 commit을 checkout한다.
- 알림 코드를 처음 도입하는 PR은 대상 브랜치에 신뢰된 스크립트가 아직 없으므로 PR 알림만 안전하게 건너뛴다. PR head 코드에 webhook secret을 넘겨 자체 알림하게 하지 않는다.
- 릴리스·배포·Issue·마일스톤·CI 이벤트도 이벤트 대상 ref 대신 기본 브랜치의 알림 코드를 실행한다.
- 알림에는 PR·Issue 본문, review 본문, diff, 로그, 이메일과 secret을 포함하지 않는다.
- Discord `allowed_mentions`를 비우고 `@everyone`, `@here`, 사용자·역할 mention 표현을 무력화한다.
- Discord webhook URL은 HTTPS와 Discord 공식 호스트를 검사한다.
- `429`와 일시적 `5xx`·네트워크 오류는 최대 세 번 제한적으로 재시도한다. 그 뒤에는 Actions를 실패시켜 운영자가 로그로 확인할 수 있게 한다.
- GitHub 목록은 페이지를 따라 최대 1,000건까지 읽고 브랜치 비교는 최대 4개만 동시에 실행한다. 안전 한도를 넘거나 일부 API가 끝내 실패하면 불완전한 요약을 보내지 않고 Actions를 실패시킨다.
- Project 최초 예약 조회는 기존 항목을 알리지 않고 기준선만 저장한다. 상태 캐시가 사라진 뒤에도 같은 방식으로 대량 중복 알림을 피한다.
- Project 상태 캐시는 각 항목의 `statusEnteredAt`을 함께 보존한다. 상태가 유지되면 시각을 보존하고 상태가 바뀌면 새 시각을 기록해 `REVIEW` 24시간 경과를 계산한다.
- 기존 캐시에 진입 시각이 없거나 캐시가 사라지면 현재 시각부터 다시 측정한다. 알 수 없는 과거 시간을 추정해 오래된 검토로 잘못 알리지 않는다.
- 회의 안건 job도 최신 Project 캐시를 복원한다. 조회 중 새 필드나 상태 변화를 발견하면 실제 전송 실행에서 새 캐시를 저장한다.
- Project 토큰이 없으면 해당 job summary에 비활성 사유를 남기고 성공 종료한다.

## 6. 로컬 검증

Node.js 24 이상에서 다음을 실행한다.

```powershell
node --check scripts/discord_notifications.mjs
node --test scripts/discord_notifications.test.mjs
```

테스트는 이벤트 선별, PR·CI 필터, mention 무력화, webhook URL 제한, dry-run 무전송, 일일 요약, Project 중요 상태 변화와 저장소 범위 제한, 상태 진입 시각, 회의 안건 순서와 중복 제거를 확인한다.

## 7. 변경 규칙

- 즉시 알림 종류를 늘릴 때는 `buildImmediateMessage` 테스트를 먼저 추가한다.
- 새 CI workflow 실패를 알리려면 workflow의 표시 이름을 `workflow_run.workflows` 허용 목록에 추가한다.
- Discord 메시지에 사용자 입력을 새로 포함하면 `sanitize`를 거치고 본문·diff·로그는 계속 제외한다.
- Project 소유권을 조직으로 옮길 때는 조직 Project webhook 사용 가능성을 다시 검토하고 5분 조회를 제거할지 결정한다.

참고: [GitHub Actions 이벤트](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows), [GitHub Project API 인증](https://docs.github.com/en/issues/planning-and-tracking-with-projects/automating-your-project/using-the-api-to-manage-projects), [Discord webhook 실행](https://docs.discord.com/developers/resources/webhook#execute-webhook).
