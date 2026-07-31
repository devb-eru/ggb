# GGB 기여자 권리 증거·제작물 반입 기준

## 1. 목적과 현재 상태

이 문서는 팀원이 만든 코드, 문서, 시나리오, 아트, 애니메이션, 음원과 음향을 GGB가 상업 게임에 포함할 수 있다는 증거를 누락하지 않기 위한 운영 기준이다. root `LICENSE`의 All Rights Reserved 표기나 Git 커밋만으로 개별 제작자의 권리 허락이 자동 증명된다고 보지 않는다.

현재 상태는 `POLICY_READY / SIGNATURES_PENDING`이다. 본 문서는 법률 자문이나 실제 계약서를 대신하지 않는다. 프로젝트의 계약 주체와 준거법이 정해지면 적합한 양도 또는 이용허락 문서를 별도로 검토·서명해야 한다.

## 2. 적용 대상

- 저장소에 들어가는 코드·문서·데이터.
- Drive에 보관하고 게임·상점·홍보에 쓰는 아트·음원·영상 원본과 export.
- 기존 개인 작업, 외주, 공동 저작, 수정·편집 결과.
- 생성형 도구, 외부 brush·font·sample·plugin을 사용한 제작물.
- 본명 대신 활동명을 크레딧에 쓰더라도 동일하게 적용한다.

아이디어 제안이나 일반 피드백과 실제 저작물 반입은 구분한다. 권리 판단이 불명확한 파일은 임시 참고 자료로만 두고 release asset으로 승인하지 않는다.

## 3. 필수 증거 필드

각 기여 묶음은 공개 저장소에 개인정보를 넣지 않고 다음 식별 정보만 남긴다.

```yaml
contribution_rights:
  rights_evidence_id: RIGHTS-YYYY-NNNN
  contributor_id: team_alias
  work_ids: []
  asset_ids: []
  contribution_types: []
  ownership_basis: ORIGINAL | AUTHORIZED_THIRD_PARTY | CONTRACTED
  external_material_ids: []
  generative_tool_disclosure_id: null
  signed_record_ref: PRIVATE_RECORD_ID
  reviewed_by: beru
  reviewed_on: YYYY-MM-DD
  status: PENDING | VERIFIED | REJECTED | SUPERSEDED
```

실제 이름, 주소, 서명, 지급 정보와 계약 원문은 접근이 제한된 비공개 저장소에 둔다. 공개 manifest의 `evidence`에는 `rights_ref=RIGHTS-YYYY-NNNN`만 기록한다.

## 4. 확인해야 할 내용

실제 서명 문서는 프로젝트 상황과 관할 법률에 맞춰 검토하되, 운영상 최소한 다음 질문에 답해야 한다.

1. 누가 어떤 파일과 범위를 만들었는가.
2. 제작자가 해당 작업을 제공할 권한이 있는가.
3. GGB가 게임, 데모, 상점, 홍보, 패치와 보관을 위해 복제·수정·배포할 수 있는가.
4. 플랫폼 배포사, 번역·QA·외주 파트너에게 필요한 범위로 전달할 수 있는가.
5. 보수, 로열티, 크레딧명과 표시 방식은 무엇인가.
6. 외부 재료와 생성형 도구 사용이 있다면 어떤 조건과 고지가 필요한가.
7. 제작물이 교체·삭제되어도 이미 배포된 빌드와 백업을 어떻게 처리하는가.

권리 양도와 이용허락 중 어느 방식을 쓸지는 이 문서가 결정하지 않는다. 적절한 계약 형식이 확정되지 않으면 `PENDING`으로 남긴다.

## 5. 반입·승인 게이트

| 단계 | 권리 처리 |
| --- | --- |
| `00_INTAKE` | 제작자·출처·외부 재료·권리 상태를 접수하고 `rights_evidence_id`를 발급하거나 기존 증거를 연결 |
| `10_WORKING` | `PENDING` 허용, 외부 공개·상점 사용 금지 |
| `20_REVIEW` | 실제 서명 기록과 license registry를 교차 확인하고 누락 시 반려 |
| `30_APPROVED` | `VERIFIED`만 허용하며 승인 source와 export를 같은 권리 범위로 묶음 |
| Git/LFS 반영 | `30_APPROVED`를 유지하면서 manifest `evidence`에 rights reference를 기록하고 `INTEGRATED`로 전환 |
| `90_ARCHIVE` | 교체·취소된 파일도 당시 권리 증거와 대체 asset ID를 보존 |
| demo lock·RC | 모든 포함 제작물 `VERIFIED`, 외부 조건·크레딧 일치 |

권리 증거가 없는 파일은 기술 시험용 placeholder로는 쓸 수 있지만 배포 후보에는 들어갈 수 없다. 파일을 수정하거나 다른 사람이 덧그려도 원본 권리 공백이 사라지지 않는다.

## 6. 변경과 철회

- 기여 범위, 크레딧, 외부 재료 또는 이용 조건이 바뀌면 새 증거 버전을 만든다.
- 기존 증거를 덮어쓰지 않고 `SUPERSEDED`와 대체 ID를 연결한다.
- 분쟁 또는 철회 요청이 오면 해당 asset을 `BLOCKED_RIGHTS`로 격리하고 새 build 반입을 중단한다.
- 이미 공개된 빌드의 처리와 교체 기한은 실제 계약·플랫폼 의무를 확인한 뒤 결정한다.
- 권리 분쟁 내용과 개인정보를 공개 Issue나 Discord에 게시하지 않는다.

## 7. 출시 전 체크

- [ ] 현재·과거 팀 기여자의 포함 제작물에 `rights_evidence_id`가 있다.
- [ ] 각 ID가 비공개 서명 기록과 연결된다.
- [ ] `license_id=TBD` 또는 `rights_ref` 누락 자산이 demo lock·RC에 없다.
- [ ] 외부 재료가 `third_party_credits.csv`와 크레딧에 반영된다.
- [ ] 생성형 도구 사용 기록과 플랫폼 고지 요구를 출시 시점 기준으로 재확인한다.
- [ ] 프로젝트 계약 주체와 실제 배포 계정 명의가 권리 문서와 일치한다.
