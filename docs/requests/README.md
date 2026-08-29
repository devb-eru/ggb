# GGB 제작 의뢰서 운영

## 1. 목적

이 폴더는 제작자가 작업을 시작하기 전에 범위, 맥락, 산출물과 승인 기준을 합의하는 정본이다. 완성물을 받은 뒤의 보관·검수는 [에셋 접수·보관 운영](../asset_intake.md), 기술 수치는 [콘텐츠 제작 규격](../content_pipeline_specs.md), 전체 에셋 존재 여부와 상태는 [에셋 매니페스트](../asset_manifest.md)가 담당한다.

```text
기획 정본·매니페스트
→ 제작 의뢰 REQUEST
→ 팀 수락 ACCEPTED
→ 제작·검토
→ 납품 접수 INTAKE
→ 승인·Git/LFS 통합
```

의뢰서는 매니페스트를 복제하지 않는다. 아트·사운드 항목은 기존 `asset_id`를 참조하며, 콘텐츠 항목은 승인 전 `content_item_id`로 관리한다. 실행 문자열의 `line_id`는 원문 검토 뒤 [현지화 제작 계약](../localization.md)에 따라 발급한다.

## 2. 기존 자료와 새 자료

| 자료 | 역할 |
| --- | --- |
| [request_register.csv](request_register.csv) | 모든 팀·배치의 의뢰 상태 정본 |
| [아트 버티컬 슬라이스 의뢰서](REQ-ART-2026-0001_버티컬슬라이스.md) | 공간 4종의 배치·구도와 활성 오브젝트·퍼즐·UI·에드가 subset 전수 명세 |
| [사운드 버티컬 슬라이스 의뢰서](REQ-AUD-2026-0001_버티컬슬라이스.md) | BGM·앰비언스·퍼즐·리셋·UI cue |
| [콘텐츠 기획 버티컬 슬라이스 의뢰서](REQ-CNT-2026-0001_버티컬슬라이스.md) | 대사·상호작용 문구·수첩·서류·접근성 문구 |
| [공개 데모 잔여 아트 의뢰서](REQ-ART-2026-0002_공개데모잔여.md) | VS 제외 P1~D5 아트 115종 전수 제작 |
| [본편 전용 아트 의뢰서](REQ-ART-2026-0003_본편전용.md) | D6~두 엔딩 아트 76종 전수 제작 |
| [상점·홍보 아트 의뢰서](REQ-ART-2026-0004_상점홍보.md) | Steam 상점·로고·스크린샷·트레일러 9행·13단위 |
| [아트 전수 부속 명세](art/README.md) | 공간·오브젝트·퍼즐·캐릭터/UI·상점 세부 카드 |
| [공개 데모 잔여 사운드 의뢰서](REQ-AUD-2026-0002_공개데모잔여.md) | VS 제외 P1~D5 사운드 50종 전수 제작 |
| [본편 전용 사운드 의뢰서](REQ-AUD-2026-0003_본편전용.md) | D6~두 엔딩 사운드 28종 전수 제작 |
| [사운드 전수 부속 명세](audio/README.md) | 공간음·BGM/서명·퍼즐/전환·공통 SFX 97종 상세 |
| [공개 데모 콘텐츠 원문 의뢰서](REQ-CNT-2026-0002_공개데모원문.md) | P1~D5 대사·상호작용·문서·퍼즐·자막 전수 작성 |
| [본편 콘텐츠 원문 의뢰서](REQ-CNT-2026-0003_본편원문.md) | D6~두 엔딩 원문과 관계·선택 분기 전수 작성 |
| [콘텐츠 에피소드별 부속 명세](content/README.md) | EP00~EP09 제작 패키지와 공통 schema |
| [에셋 매니페스트](../asset_manifest.csv) | 에셋 ID·수량·승인 상태 정본 |
| [정본 런타임 오브젝트 대장](../game_object_catalog.md) | 독립 상태·저장 의미를 가진 63개 오브젝트 |
| [전체 제작 오브젝트 인벤토리](../game_object_inventory.md) | 정본 63개와 퍼즐·문서·UI·소품 제작 엔티티 |
| [에셋 접수 메시지](../templates/asset_intake_message.md) | 제작 완료 뒤 Discord 전달 양식 |

재사용 원본은 [팀별 의뢰서 템플릿](../templates/requests/README.md)에 둔다.
팀 채널에 전달할 때는 [제작 의뢰 전달 메시지](../templates/requests/request_dispatch_message.md)를 사용하고, 완성물 납품 때만 에셋 접수 메시지를 사용한다.

## 3. 의뢰 ID와 배치

의뢰 ID는 `REQ-<TEAM>-YYYY-NNNN`을 사용한다.

| TEAM | 대상 |
| --- | --- |
| `ART` | 배경·오브젝트·캐릭터·퍼즐 시각·UI 시각 |
| `AUD` | BGM·앰비언스·SFX·퍼즐·접근성 오디오 |
| `CNT` | 대사·독백·조사문·수첩·문서·힌트·시스템 문구 |

공통 실행 대상은 Windows 10/11 64-bit PC다. 기본 논리 화면은 1920x1080이며 1280x720~4K, 90~220% UI·텍스트 배율과 마우스·키보드 동등 경로를 검토한다.

| 배치 | 범위 | 현재 운영 |
| --- | --- | --- |
| `BATCH-VS01` | 20~30분 버티컬 슬라이스 | ART·AUD·CNT 범위 수락 완료. 개별 배분·첫 검토일과 기술 기반선 확정 뒤 착수 |
| `BATCH-DEMO02` | 공개 데모 잔여 범위 | ART·AUD·CNT 범위 수락 완료. `VS01_*_THROUGHPUT_RECORDED` 충족 뒤 착수 |
| `BATCH-FULL03` | 본편 전용 범위 | ART·AUD·CNT 범위 수락 완료. 데모 제작률 승인 뒤 착수 |
| `BATCH-STORE04` | Steam 상점·홍보 범위 | ART 범위 수락 완료. Steamworks 규격 확인·정식명 잠금 뒤 착수 |

버티컬 슬라이스는 정식 사건 순서를 대체하지 않는 검증용 편집 경로다. `VS01_*` 표기는 빌드 래퍼나 요청 항목이며 새 정식 이벤트 ID가 아니다. 정식 상태에는 기존 `P*`, `A*`, `B3_A`, `B3_B`, `NORMAL_RESET` 등을 사용한다.

## 4. 버티컬 슬라이스 편집 경로

```text
VS01_OPENING_RECAP
→ A1 수첩 표시
→ NORMAL_RESET
→ A2 표시 유지 확인
→ VS01_B3_CONTEXT_FIXTURE
→ B3_A 검증
→ B3_B 비가역 실패
→ BF·MEM_EDGAR_B3_FAILURE_01
→ NORMAL_RESET
→ VS01_EDGAR_MEMORY_REACTION
→ BSHORT
→ B3_B 성공
→ VS01_S2_PREVIEW
```

- `VS01_B3_CONTEXT_FIXTURE`는 J1과 B3 진입 정보를 테스트 세이브에 공급하는 개발 fixture다. 정식 저장에 기록하지 않는다.
- `VS01_S2_PREVIEW`는 S2의 미술·음향 표현을 한 장면에서 검증하는 빌드 전용 미리보기다. 정식 `world_phase`나 C5 완료를 쓰지 않는다.
- P1~P6 전체 프롤로그, B1·B2·J1의 정식 진행과 C 이후 사건은 이번 배치에 포함하지 않는다.

## 5. 상태

| 상태 | 의미 | 제작 가능 여부 |
| --- | --- | --- |
| `PLANNED` | 배치와 팀만 예약됨 | 불가 |
| `DRAFT` | 의뢰 내용 작성 중 | 불가 |
| `READY_FOR_ACCEPTANCE` | 팀이 범위·공수·담당을 검토할 수 있음 | 수락 전 불가 |
| `ACCEPTED` | 담당·제작 범위·팀 패키지 예상 공수가 합의됨 | `acceptance_gate`·선행 의뢰·개별 배분을 모두 충족한 항목만 가능 |
| `IN_PROGRESS` | 제작 중 | 가능 |
| `REVIEW` | 납품 검토 중 | 수정만 가능 |
| `APPROVED` | 영역 검토 통과 | 통합 가능 |
| `INTEGRATED` | 빌드 입력과 증거 반영 완료 | 완료 |
| `CHANGES_REQUESTED` | 수정 필요 | 수정 가능 |
| `CANCELLED` | 범위에서 제거됨 | 불가 |

`READY_FOR_ACCEPTANCE`는 제작 지시가 아니다. 팀장은 다음 값을 회신한 뒤 `ACCEPTED` 전이를 요청한다.

```yaml
accepted_scope: []
excluded_scope: []
assigned_contributors: []
estimate_hours: 0
first_review_target: YYYY-MM-DD | PROVISIONAL
dependencies_or_questions: []
```

### 5.1 수락과 제작 착수

`ACCEPTED`는 팀이 현재 revision의 범위와 팀 단위 공수를 수락했다는 뜻이며, 모든 배치를 즉시 병렬 제작한다는 뜻이 아니다. 실제 착수는 다음 조건을 모두 만족해야 한다.

1. `request_register.csv`의 `depends_on`이 완료됐다.
2. 같은 행의 `acceptance_gate`가 증거와 함께 충족됐다.
3. 해당 의뢰의 세부 담당과 첫 검토일이 배분됐다.
4. 매니페스트 대상이 실제 작업 증거와 함께 `WORKING`으로 전이됐다.

현재 10개 의뢰는 모두 범위 수락 상태지만, 요청별 배분과 첫 검토일은 `REBASELINE_REQUIRED`다. 후속 배치는 각 게이트를 통과하기 전까지 제작 대기이며, `ACCEPTED`만으로 `WORKING`, `APPROVED`, `INTEGRATED`를 주장하지 않는다.

## 6. 전체 게임 전수성 현황

| 범위 | 정본 | 의뢰 연결 |
| --- | ---: | --- |
| 아트 담당 에셋 | 229행 | VS 29 + 데모 잔여 115 + 본편 76 + 상점 9 = 229 |
| 사운드 담당 에셋 | 97행 | VS 19 + 데모 잔여 50 + 본편 28 = 97 |
| 기술 셰이더 | 4행 | `beru` 소유, ART/AUD 팀 의뢰 범위 밖 |
| 콘텐츠 원문 | EP00~EP09 | VS + 데모 4패키지 + 본편 6패키지 |
| 정본 오브젝트 | 63개 | 아트·CNT 전수 매핑 완료 |
| 비런타임 제작 엔티티 | 86묶음 | 전체 제작 오브젝트 인벤토리에서 부모 에셋 아래 추적 |

매니페스트 330행은 아트 229 + 사운드 97 + 기술 셰이더 4로 모두 소유자가 정해져 있다. 콘텐츠 원문은 매니페스트 에셋 행이 아니라 `content_item_id`와 승인 뒤 `line_id`로 관리한다.

## 7. 공통 필수 필드

모든 상세 의뢰서는 다음을 포함한다.

- `request_id`, 팀, 상태, 배치, 우선순위, 담당·검토자.
- 사용 목적과 플레이어에게 전달할 정보.
- 포함·제외 범위와 참조 `asset_id`·이벤트·장소·오브젝트.
- source와 runtime export, 미리보기, 권리 증거 요구.
- 접근성 대체, 실패·반복 상태와 금지 표현.
- 수락 조건, 제작 완료 조건과 검증 증거.
- 변경 이력과 팀 질문 기록.

## 8. 변경과 추적

1. 범위 변경은 의뢰서 revision과 `request_register.csv` evidence에 기록한다.
2. `asset_id`를 새로 만들거나 제거하면 매니페스트를 먼저 갱신한다.
3. `content_item_id` 승인 후 `line_id`를 발급해도 의뢰 ID와 항목 ID를 원문 레코드에 남긴다.
4. 납품 메시지에는 `request_id`, `work_id`, 실제 제작자와 버전을 모두 적는다.
5. Discord 대화만으로 범위나 승인을 확정하지 않는다.

## 9. 검증

`scripts/validate_docs.ps1`은 다음을 확인한다.

- 의뢰 ID와 대장 중복.
- `READY_FOR_ACCEPTANCE` 이후 활성 의뢰 상세 문서의 존재, ID·revision·상태 일치.
- 아트·사운드 의뢰의 `asset_id`가 매니페스트에 존재하는지 여부.
- 팀·상태·배치 값과 필수 제작 필드.
- 문서 링크와 UTF-8 Markdown 기본 구조.
