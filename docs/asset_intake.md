# GGB 에셋 접수·보관 운영

## 1. 시스템 역할

| 시스템 | 역할 | 정본 여부 |
| --- | --- | --- |
| GitHub Issue·Project | 작업 상태, 실제 담당자, 목표일, 완료 조건, 검증 근거 | 작업 정본 |
| Discord `#asset-intake` | 제작자 전달, 접수 확인, 수정·승인 대화 | 전달 화면 |
| [Google Drive `GGB/Assets`](https://drive.google.com/drive/folders/1S8S8CSfpfO2ToszpAbSRaJqGgNRAqVoD) | PSD, 편집 프로젝트, 원본 음원 등 대용량 원본 | 편집 원본 정본 |
| Git·Git LFS | 게임이 직접 읽는 승인된 export와 구현 파일 | 빌드 입력 정본 |

Discord 첨부만 남기거나 Drive 파일만 이동해서는 작업이 완료되지 않는다. 현재 상태와 승인 근거는 관련 GitHub Issue·Project에 기록한다.

## 2. Drive 폴더

```text
GGB/
└─ Assets/
   ├─ 00_INTAKE/
   ├─ 10_WORKING/
   ├─ 20_REVIEW/
   ├─ 30_APPROVED/
   └─ 90_ARCHIVE/
```

| 폴더 | 의미 | 이동 조건 |
| --- | --- | --- |
| `00_INTAKE` | 전달됐지만 필수 정보와 파일을 아직 확인 중 | `beru`가 작업 ID, 제작자, 사용처, 버전, 권리를 확인 |
| `10_WORKING` | 제작 또는 수정 진행 중 | 담당자와 목표일이 GitHub Project에 지정됨 |
| `20_REVIEW` | 팀장·QA 검토 대기 | source, export, 미리보기와 검토 요청이 준비됨 |
| `30_APPROVED` | 사용 승인된 현재 버전 | 영역 팀장 승인과 기본 열기·재생 검증 통과 |
| `90_ARCHIVE` | 교체된 버전, 취소 작업, 흐름 테스트 | 대체 버전이나 취소 이유가 GitHub에 기록됨 |

작업 폴더는 동시에 한 단계에만 둔다. 반려된 작업은 `20_REVIEW`에서 `10_WORKING`으로 되돌리고 버전을 올린다. 승인 파일을 수정해야 하면 기존 폴더를 덮어쓰지 않고 새 버전을 `10_WORKING`에서 시작한다.

## 3. 이름과 내부 구조

작업 폴더 이름은 다음 형식을 사용한다.

```text
<work_id>__<asset_type>__<contributor>__vNNN
```

예:

```text
GGB-WRK-2026-0042__art__210__v003
GGB-WRK-2026-0051__audio__NOne__v001
```

폴더 안에는 필요한 항목만 만든다.

```text
source/    편집 원본
export/    게임 또는 상점에 사용할 출력물
preview/   Discord·Issue 검토용 미리보기
license/   외부 폰트·브러시·샘플·플러그인의 사용 조건
```

파일 이름은 `<asset_key>__<variant>__vNNN.ext`를 사용한다. 같은 버전 파일을 덮어쓰지 않는다. 파일이 바뀌면 버전을 올리고 Discord와 GitHub에 변경 요약을 남긴다.

## 4. Discord 접수

[`asset_intake_message.md`](templates/asset_intake_message.md)를 복사해 `#asset-intake`에 게시한다.

필수값은 다음과 같다.

- `work_id`: 연결된 GitHub 작업 ID.
- `contributor`: 실제 제작자.
- `asset_type`: `art`, `audio`, `ui`, `source` 중 하나.
- `version`: `vNNN`.
- `usage`: 사용 장면, 이벤트, 화면 또는 상점 위치.
- `deliverable`: 필요한 source와 export 목록.
- `source_or_export`: 전달 파일의 성격.
- `license`: 자체 제작 또는 외부 자산의 사용 조건.
- `drive_url`: 작업 폴더 URL. 최초 Discord 첨부라면 `beru_pending`.

`beru`는 필수값과 파일을 확인한 뒤 같은 스레드에 `RECEIVED` 또는 `NEEDS_INFO`로 회신한다. `RECEIVED` 회신에는 Drive 작업 폴더와 GitHub Issue URL을 포함한다.

## 5. 상태 전이

| 사건 | Drive | GitHub Project | Discord 회신 |
| --- | --- | --- | --- |
| 전달 접수 | `00_INTAKE` | `READY` 또는 기존 상태 유지 | `RECEIVED` |
| 제작·수정 시작 | `10_WORKING` | `IN_PROGRESS` | `WORKING` |
| 검토 요청 | `20_REVIEW` | `REVIEW` | `REVIEW_REQUESTED` |
| 수정 필요 | `10_WORKING` | `IN_PROGRESS` | `CHANGES_REQUESTED` |
| 팀장 승인 | `30_APPROVED` | 검증 완료 전 `REVIEW` | `APPROVED` |
| Git/LFS 반영·검증 완료 | `30_APPROVED` | `DONE` | `INTEGRATED` |
| 교체·취소 | `90_ARCHIVE` | 관련 작업 상태와 사유 기록 | `ARCHIVED` |

Discord 회신은 알림이고 GitHub Project 상태가 정본이다. 폴더 이동과 Project 상태가 다르면 Project를 기준으로 원인을 확인한 뒤 둘을 맞춘다.

## 6. 검토와 저장소 반영

1. 제작 팀장은 source가 다시 편집 가능한지, export가 요구 규격을 충족하는지 확인한다.
2. `gatam` 또는 지정 QA는 사용 장면, 언어, 잘림·루프·가독성 등 작업별 완료 조건을 확인한다.
3. `beru`는 파일 출처와 라이선스, 이름, 버전, Drive 위치를 확인한다.
4. 게임이 직접 읽는 최종 export만 Git 또는 Git LFS에 반영한다.
5. 관련 commit·PR·QA 결과를 GitHub Project `검증 근거`에 기록한다.
6. 승인 source는 `30_APPROVED`에 유지하고 교체된 버전만 `90_ARCHIVE`로 이동한다.

`.psd`, `.kra`, DAW 프로젝트, 무압축 원본과 대용량 중간 산출물은 저장소에 중복 보관하지 않는다. Git LFS 포함 여부는 실제 파일 형식과 크기를 확인한 뒤 결정한다.

## 7. 권한 기준

개인 이메일은 저장소나 Discord에 기록하지 않는다. Google Drive 공유 화면에서만 계정을 지정한다.

| 대상 | 권장 권한 |
| --- | --- |
| `beru` | `GGB/Assets` 전체 편집·정리 |
| `210`, `nana`, `NOne` | `00_INTAKE`, `10_WORKING` 편집 |
| 각 영역 팀장과 `gatam` | `20_REVIEW` 댓글 또는 편집 |
| 전체 팀 | `30_APPROVED` 읽기 |
| `beru` 외 팀원 | `90_ARCHIVE` 읽기 |

불특정 사용자에게 링크 편집 권한을 공개하지 않는다. 팀원이 Google 계정을 쓰지 않으면 Discord로 전달하고 `beru`가 Drive에 보관한다.

## 8. 기준선 검증

2026-07-27에 `__FLOW_TEST__GGB-WRK-2026-0002` 폴더를 사용해 다음 이동을 확인했다.

```text
00_INTAKE
→ 10_WORKING
→ 20_REVIEW
→ 30_APPROVED
→ 90_ARCHIVE
```

각 이동 뒤 상위 폴더를 다시 읽어 단일 단계에만 존재함을 확인했다. 테스트 폴더는 감사 근거로 `90_ARCHIVE`에 남겼다. 실제 에셋은 이전하거나 공개하지 않았다.
