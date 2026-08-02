# GGB Discord 운영 기준

## 1. 역할 분담

Discord는 팀이 보는 운영 화면과 전달 채널로 사용한다. 작업 상태·담당자·마감·검증 근거의 정본은 GitHub Issue·Project다.

```text
GitHub Issue·Project
├─ 작업·담당·마감·상태 정본
├─ Discord #git-updates 알림
└─ 금요일 회의 안건 생성

Discord #asset-intake
└─ beru 검수 → Google Drive 편집 원본 → Git/LFS 승인 export
```

Discord 메시지만으로 작업 완료나 마감 변경을 확정하지 않는다. 회의나 채팅에서 결정한 내용은 관련 GitHub 작업 또는 `GGB-DEC`에 반영한다.

## 2. 채널

| 채널 | 용도 | 책임자 |
| --- | --- | --- |
| `#git-updates` | GitHub 중요 사건, 요약, 회의 안건 | `beru` |
| `#asset-intake` | 계정이 없는 팀원의 원본·수정본 전달 | `beru` |

`beru`는 Discord 서버 관리 권한을 가진다.

## 3. Git 알림 정책

### 즉시 알림

- `develop`, `main` push.
- PR 생성, 검토 요청, 변경 요청, 병합.
- 작업이 `BLOCKED`가 되거나 `P0/P1`으로 변경됨.
- 마일스톤 목표일 변경.
- 릴리스, 배포와 CI 실패.

### 요약 알림

- 작업 브랜치의 일반 커밋.
- 단순 라벨·설명 수정.
- 반복되는 봇 갱신과 일반 댓글.

일반 변경은 매일 21:30 KST에 한 번 요약한다. 현재 금요일에도 요약을 보내며, `GGB-WRK-2026-0006`의 회의 안건 자동 생성이 활성화되면 금요일 요약을 주간 회의 안건으로 대체한다. 구현·secret·검증 절차는 [GitHub→Discord 선별 알림 운영](discord_notifications.md)을 따른다.

## 4. 정기 회의

| 항목 | 기준 |
| --- | --- |
| 주기 | 매주 금요일 |
| 시작 | 22:00 KST |
| 기본 길이 | 60분 |
| 종료 | 안건에 따라 유동적 |
| 참석 | `gatam`, `niik`, `beru`, `210`, `nana`, `NOne` 전원 |
| 안건 게시 | 금요일 21:30 KST, `#git-updates` |

Discord 서버 `게임개발일지`에는 다음 Scheduled Event 하나를 주간 회의 표시용으로 유지한다.

| 설정 | 값 |
| --- | --- |
| 이벤트명 | `GGB 주간 제작 회의` |
| 첫 일정 | 2026-08-07 금요일 22:00 KST |
| 반복 | 매주 금요일 |
| 음성 채널 | `회의실` |
| 운영 시간 | 기본 60분, 종료는 안건에 따라 유동적 |

이벤트 설명은 다음 문구를 사용한다.

```text
GitHub GGB Production이 작업·담당·마감의 정본입니다.
회의 안건은 금요일 21:30 #git-updates에서 확인합니다.
기본 회의 시간은 60분이며, 회의 후 결정·담당자·목표일을 GitHub에 반영합니다.
https://github.com/users/devb-eru/projects/1
```

Scheduled Event는 기존 반복 이벤트를 Discord UI에서 정비해 사용한다. incoming webhook은 `#git-updates` 메시지 게시 전용이므로 이벤트 생성·수정 권한을 맡기지 않는다. 별도 Discord bot과 토큰은 반복 이벤트를 코드로 관리해야 할 요구가 생길 때만 검토한다.

회의 안건은 다음 순서로 만든다.

1. 지금 결정하지 않으면 멈추는 `P0/P1`과 `BLOCKED`.
2. 다음 회의 전 마감되는 작업.
3. 24시간 넘게 검토 대기 중인 작업.
4. 일정 초과, 담당자 누락, 팀 간 전달 대기.
5. 데모·완성본·Steamworks 마일스톤 변화.

회의가 끝나면 결정, 담당자, 목표일과 후속 작업을 GitHub에 반영한다. 회의가 길어지면 60분 시점에 남은 안건을 계속 논의할지 비동기 작업으로 바꿀지 결정한다.

## 5. 에셋 접수

제작 전 범위와 승인 기준은 [팀별 제작 의뢰](requests/README.md)에서 먼저 합의한다. 세부 납품 절차, Drive 폴더와 권한 기준은 [에셋 접수·보관 운영](asset_intake.md)을 따른다. `#asset-intake`에서는 원 `request_id`를 포함한 [접수 메시지 템플릿](templates/asset_intake_message.md)을 사용한다.

```text
work_id: GGB-WRK-YYYY-NNNN
contributor: 실제 제작자
asset_type: art | audio | ui | source
version: v001
usage: 사용 장면·이벤트·화면
deliverable: 필요한 원본·출력물
source_or_export: source | export | both
license: original | external_with_terms
rights_evidence_id: RIGHTS-YYYY-NNNN | beru_pending
drive_url: beru_pending | Google Drive 작업 폴더
requires: 선행 작업·폰트·플러그인
notes: 수정 주의사항
```

- 게임에서 직접 쓰는 최종 파일은 Git LFS 추적 여부를 확인하고 저장소에 넣는다.
- PSD, 원본 음원, 편집 프로젝트 등 대용량 원본은 [Google Drive `GGB/Assets`](https://drive.google.com/drive/folders/1S8S8CSfpfO2ToszpAbSRaJqGgNRAqVoD)에 보관한다.
- Discord 첨부는 전달 수단이며 유일한 원본 보관본으로 취급하지 않는다.
- `beru`가 저장 위치와 반영 commit/PR을 원 메시지 또는 작업 항목에 회신한다.
- 반려 파일은 기존 버전을 덮어쓰지 않고 버전을 올려 `10_WORKING`으로 되돌린다.

## 6. 일정 운영

- 작업 마감과 마일스톤은 GitHub Project의 날짜 필드를 정본으로 사용한다.
- Discord Scheduled Event는 금요일 정기 회의와 특별 회의 표시용으로 사용한다.
- 마감 변경은 GitHub에서 먼저 수정하고 Discord에 알린다.
- 일정 조율 자동화는 GitHub 날짜와 Discord 알림을 연결하며 별도 캘린더에 같은 마감을 중복 입력하지 않는다.
- 정기 회의의 일회성 연기·취소는 해당 회차만 수정하고 `#git-updates`에 알린다. 이 변경만으로 작업 목표일을 바꾸지 않는다.
- 정기 회의 시각을 계속 바꾸려면 이 문서의 기준을 먼저 갱신하고 반복 시리즈 전체를 수정한다.
- 특별 회의는 별도 일회성 Scheduled Event로 만들고 관련 GitHub 작업을 설명에 연결한다.
- 회의 변경으로 작업 마감도 달라지면 GitHub 목표일을 먼저 수정한 뒤 Discord에 변경 이유를 알린다.
- 서버·채널·이벤트 ID와 webhook·bot 토큰은 문서, Issue, PR, Discord 메시지에 기록하지 않는다.
