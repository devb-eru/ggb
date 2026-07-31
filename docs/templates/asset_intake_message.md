# Discord 에셋 접수 메시지

아래 블록을 복사해 `#asset-intake`에 게시한다.

```text
work_id: GGB-WRK-YYYY-NNNN
contributor:
asset_type: art | audio | ui | source
version: v001
usage:
deliverable:
source_or_export: source | export | both
license: original | external_with_terms
drive_url: beru_pending | https://drive.google.com/...
requires:
notes:
```

`beru`는 같은 스레드에 아래 형식으로 접수 결과를 회신한다.

```text
status: RECEIVED | NEEDS_INFO
github_issue:
drive_url:
checked:
missing:
next_owner:
```

검토 요청과 결과는 아래 값을 사용한다.

```text
status: REVIEW_REQUESTED | CHANGES_REQUESTED | APPROVED | INTEGRATED | ARCHIVED
version:
reviewer:
result:
evidence:
next_owner:
```

상태·담당자·목표일 변경은 Discord에서 끝내지 않고 GitHub Issue·Project에 반영한다.
