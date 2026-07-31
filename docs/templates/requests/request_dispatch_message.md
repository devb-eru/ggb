# GGB 제작 의뢰 전달 메시지

아래 블록을 팀 채널이나 작업 스레드에 게시한다. 완성물 납품에는 별도 [에셋 접수 메시지](../asset_intake_message.md)를 사용한다.

```text
request_id: REQ-ART-YYYY-NNNN
team: ART | AUD | CNT
status: READY_FOR_ACCEPTANCE
batch_id: BATCH-VS01
priority: P1
brief_url:
summary:
included_scope:
excluded_scope:
target_milestone:
response_requested:
  - accepted_scope
  - excluded_scope
  - assigned_contributors
  - estimate_hours
  - first_review_target
  - dependencies_or_questions
note: 본 회신 전에는 제작 시작이 아니라 범위·공수 검토 단계입니다.
```

팀 회신을 받은 뒤 요청 대장과 상세 의뢰서에 같은 내용을 반영한다. Discord 메시지만으로 `ACCEPTED` 상태를 확정하지 않는다.
