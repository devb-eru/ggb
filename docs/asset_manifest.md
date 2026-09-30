# GGB 에셋 BOM·승인 레지스트리

## 1. 정본

| 항목 | 기준 |
| --- | --- |
| 기계 판독 manifest | [`asset_manifest.csv`](asset_manifest.csv) |
| 제작 의뢰·배치 대장 | [`requests/`](requests/) |
| 접수·보관 흐름 | [`asset_intake.md`](asset_intake.md) |
| 제작 기술 규격 | [`content_pipeline_specs.md`](content_pipeline_specs.md) |
| 외부 라이선스 정본 | [`third_party_credits.csv`](third_party_credits.csv) |
| 제품 임시 에셋 기준 | [`product_contract.md`](product_contract.md) |
| 공간 정본 | `ideas/md/v04/05_*` location registry |
| 오브젝트 정본 | `ideas/md/v04/15_*` canonical object registry |

manifest 한 행은 독립적으로 검토·승인할 수 있는 **deliverable unit**이다. 원본 파일 수나 export 파일 수가 아니라 게임에서 하나의 기능·장면 단위로 교체 가능한 묶음을 뜻한다.

예:

- 방 배경 원화 1개와 런타임 export 묶음은 한 행.
- 한 인물의 표정 10종 세트는 한 행이며 `unit_count=10`.
- 한 오브젝트의 상태 sprite 묶음은 한 행이며 실제 상태 수를 `unit_count`에 기록.
- BGM loop와 stem이 함께 승인되어야 하면 한 행으로 묶되 deliverable 설명에 구성물을 적는다.

## 2. 필드 계약

| 필드 | 규칙 |
| --- | --- |
| `asset_id` | 고유 ASCII ID, 발급 후 의미 재사용 금지 |
| `source_entity_id` | location, object, character, UI 또는 event ID |
| `asset_type` | `background`, `world_overlay`, `object_state`, `character_sheet`, `portrait_set`, `pose_set`, `character_overlay`, `ui`, `ambient_audio` 등 |
| `variant` | base, phase, screen 또는 상태 묶음 이름 |
| `build_scope` | `demo_full`, `full_only`, `store_only` |
| `required` | 제품 경로에 필요한 deliverable이면 `true` |
| `unit_count` | 행이 포함하는 실제 검토 단위 수, 미분해 상태는 1 |
| `status` | `PLANNED`, `WORKING`, `REVIEW`, `APPROVED`, `INTEGRATED`, `REPLACED`, `CUT` |
| `is_placeholder` | 현재 게임 export가 임시 자산이면 `true` |
| `owner` | 제작 책임자 한 명 |
| `reviewer` | 승인 책임자 한 명 |
| `target_milestone` | 데모 또는 본편 잠금 게이트 |
| `license_id` | `INTERNAL`, 외부 license registry ID 또는 `TBD` |
| `evidence` | Drive 버전, Issue, PR, commit, QA ID와 내부 제작물의 `rights_ref=RIGHTS-YYYY-NNNN` |

## 3. 현재 기준선

2026-07-31 기준 manifest는 기획 registry에서 다음을 초기 생성했다.

| 묶음 | source 수 | 생성 행 | 상태 |
| --- | ---: | ---: | --- |
| 공간 | 39 location | 배경 39, 단계 overlay pack 36, ambient 39 | PLANNED |
| 오브젝트 | 63 canonical object | 상태 art pack 63 | PLANNED |
| 캐릭터 | 주인공+사용인 5명 | sheet·portrait·pose·fracture pack 24 | PLANNED |
| 공통 UI | 13 screen/package | 13 | PLANNED |
| 메인 퍼즐 | 14 puzzle stage | panel·VFX·audio 42 | PLANNED |
| 주요 전환 | 8 transition | event art·audio 16 | PLANNED |
| 인격 서명 | owner 5명+SUBJECT | VFX·audio 12 | PLANNED |
| 공통 음악·효과음 | BGM 10, SFX 20 | 30 | PLANNED |
| 공통 기술 자산 | font 3, shader 4 | 7 | PLANNED |
| Steam 상점 | package 9 | 9, screenshot `unit_count=5` 포함 | PLANNED |

전체 기준선은 330행이다. `store_only`를 제외한 데모 대상은 217행·316 unit, 본편 대상은 321행·420 unit이다. 현 시점에는 최종 export와 승인 근거가 없으므로 모든 행은 `PLANNED`, `is_placeholder=true`다. 이는 실제 임시 에셋 비율이 100%라는 뜻이며, 데모 완료를 주장할 수 없음을 명확히 보여 준다.

2026-08-01에 `BATCH-VS01` 대표 제작 의뢰 3건을 작성했고, 2026-08-29에 ART·AUD·CNT의 10개 의뢰가 모두 `ACCEPTED`로 전환됐다. ART·CNT는 팀 전체 수락 패키지 2주, AUD는 1개월의 경과 공수를 회신했으나 개별 의뢰 배분과 첫 검토일은 아직 재산정 대기다. 실제 제작 파일·작업 증거는 없으므로 manifest 행은 계속 `PLANNED`다. 실제 작업을 시작할 때만 해당 행 또는 합의한 subset의 evidence에 `request_id`를 기록하고 `WORKING`으로 전이한다.

### 3.1 담당자별 기준선

| 담당자 | 전체 행 | 전체 unit | 데모 행 | 데모 unit | 주 책임 |
| --- | ---: | ---: | ---: | ---: | --- |
| `210` | 229 | 332 | 144 | 243 | 아트·캐릭터·배경·UI |
| `nana` | 0 | 0 | 0 | 0 | 아트 구성원, 현재 manifest 미배정 |
| `NOne` | 97 | 97 | 69 | 69 | BGM·환경음·효과음 |
| `beru` | 4 | 4 | 4 | 4 | shader·기술 자산 |

이 수량은 제작 공수가 아니다. portrait set의 10 unit과 단일 SFX의 1 unit은 같은 시간이 들지 않으며, 수정 횟수·통합·접근성 변형도 아직 계측되지 않았다. 특히 `210`의 데모 242 unit을 일정상 완료 가능하다고 간주해서는 안 된다. 아트 구성원 `nana`에게 배정된 행이 0인 상태 역시 의도된 무배정인지 단순 기준선 생성 결과인지 capacity 입력 때 확인하고, 실제 책임을 나눌 때 owner·reviewer를 함께 갱신한다.

`M2_DEMO_COMPLETE` 일정을 확정하기 전에 배경+overlay, 캐릭터 portrait/pose, 오브젝트 상태, UI, puzzle art, BGM·환경음·SFX에서 대표 샘플을 최소 1개씩 제작·검토·통합한다. 각 샘플에는 순수 제작 시간, 리뷰 대기, 수정 횟수, export·통합, 접근성 대체와 승인 시간을 기록하고, 그 실측값으로 남은 manifest를 다시 산정한다.

대표 샘플 범위와 승인 조건은 [REQ-ART-2026-0001](requests/REQ-ART-2026-0001_버티컬슬라이스.md), [REQ-AUD-2026-0001](requests/REQ-AUD-2026-0001_버티컬슬라이스.md)을 따른다. 요청 subset 완료는 portrait·pose·phase pack 전체 행 완료와 같지 않다.

`world_overlay`는 현실 `R0_*`를 제외한 36개 시뮬레이션·시설 location에 생성했다. 실제 단계 조합은 room state matrix를 확정할 때 행을 variant별로 분해한다.

### 3.2 기존 연습 씬 자산

`game/background1.png`~`background3.png`, `drawer_close.png`, `drawer_open.png`, `key.png`, `lock.png`은 현재 `signal_practice.tscn`용 로컬 연습 자산이다. 이 7개 파일은 v0.4 production BOM에 포함되지 않으며 존재만으로 `APPROVED` 또는 `INTEGRATED`가 아니다.

- 제작자, source 파일, 권리 범위와 `rights_ref`가 저장소에서 검증되지 않았다.
- production에서 재사용하려면 새 canonical `asset_id`로 접수하고 실제 event/location, owner, reviewer, license와 evidence를 채운다.
- 증거를 확인할 수 없거나 v0.4 미술 기준에 맞지 않으면 샌드박스와 함께 교체한다.
- `.import` 파일과 LFS 포인터는 권리·승인 증거를 대신하지 않는다.

## 4. 임시 에셋 비율

데모 비율은 다음 조건의 행만 사용한다.

```text
build_scope = demo_full
required = true
status != CUT
```

```text
placeholder_ratio
= sum(unit_count where is_placeholder=true)
  / sum(unit_count for eligible rows)
  x 100
```

- `PLANNED`, `WORKING`, `REVIEW`는 최종 export가 실제로 통합·검증되기 전까지 placeholder로 계산한다.
- `APPROVED`지만 게임에 반영되지 않은 행도 placeholder다.
- `INTEGRATED`이고 해당 빌드에서 검증된 행만 `is_placeholder=false`가 될 수 있다.
- 단순히 파일이 존재한다는 이유로 상태를 올리지 않는다.
- `unit_count`를 뒤늦게 줄여 비율을 맞추지 않는다. 범위 삭제는 `CUT`과 결정 근거를 기록한다.

## 5. 승인 상태 전이

```text
PLANNED
→ WORKING
→ REVIEW
→ APPROVED
→ INTEGRATED
```

제작 의뢰의 `READY_FOR_ACCEPTANCE`·`ACCEPTED`는 manifest 상태가 아니다. `ACCEPTED` 뒤 실제 제작 파일이나 작업 증거가 생긴 시점에 `PLANNED → WORKING`으로 바꾼다. manifest `evidence`에는 최소 `request_id`, `work_id`, Drive revision을 연결한다.

- 수정 요청은 `REVIEW → WORKING`으로 되돌린다.
- 새 버전이 대체하면 기존 행을 `REPLACED`로 두고 새 `asset_id` 또는 revision 근거를 연결한다.
- 범위에서 제거하면 `CUT`과 관련 결정·작업을 기록한다.
- Drive의 `30_APPROVED`와 manifest `APPROVED`는 같은 검토 결과를 가리켜야 한다.
- Git/LFS 반영과 게임 내 검증이 끝나야 `INTEGRATED`다.

## 6. 분해 규칙

### 배경·공간

- base composition과 world phase overlay를 분리한다.
- 카메라 이동, 16:9 밖의 여백과 200% UI 안전 영역을 함께 검토한다.
- 핫스폿 위치 데이터는 art manifest가 아니라 map registry에 둔다.
- S0~S5가 모두 필요한 것으로 가정하지 않고 공간별 실제 노출 단계만 variant로 만든다.

### 오브젝트

- canonical object 63개를 삭제하거나 합치면 문서 04·05·15·17과 함께 갱신한다.
- 닫힘·열림·손상·파열·완료처럼 시각적으로 다른 상태는 `unit_count`에 반영한다.
- 색상 단서에는 문양·선 패턴·라벨 또는 감각 자막 deliverable을 함께 연결한다.

### 캐릭터

- model sheet, portrait expressions, body poses와 fracture overlays를 분리한다.
- 표정 이름은 대사 감정 토큰과 연결한다.
- 회색 128px 실루엣 검사를 통과하기 전 색으로 식별 문제를 덮지 않는다.
- 마라 2 외형 연령과 마라 1·2 최종 이름 결정 전 최종 sheet를 잠그지 않는다.

### UI

- 1280x720, 1920x1080, 4K와 텍스트 200% 상태를 같은 deliverable에서 검토한다.
- `ko-KR`, `en-US`, pseudo-localization screenshot을 승인 근거에 포함한다.
- focus, hover, disabled, error와 selected 상태를 한 행의 필수 variant로 본다.

### 오디오

- ambient loop, BGM, SFX와 UI cue를 분리한다.
- loop point, loudness, 동시 발음 우선순위와 감각 자막 ID를 승인 근거에 둔다.
- 음량 0에서도 진행 가능한지 QA ID를 연결한다.

## 7. 현재 부족분

초기 manifest는 알려진 공간·오브젝트·캐릭터·공통 UI·공간 ambient·메인 퍼즐·주요 전환·서명·공통 음악·효과·폰트·shader·Steam 자산을 등록한 제작 기준선이다. 다음 수량은 실제 제작 전 고정해야 한다.

- 오브젝트별 실제 상태 수와 캐릭터별 최종 표정·포즈 수.
- 각 `world_overlay` pack에 포함되는 실제 S0~S5 variant 수.
- 주요 전환 8개 밖의 선택 관계·짧은 반응 전용 animation 필요 여부.
- 오디오 cue registry와 manifest 58개 BGM·SFX·서명·퍼즐·전환 행의 일대일 매핑.
- 상점 규격 확정 뒤 capsule·trailer export variant 수.

`GGB-REV-2026-0011`의 “manifest 부재”는 문서 단계에서 해결됐다. 다만 위 `unit_count` 잠금과 실제 승인·통합은 각각 데모·본편 에셋 게이트에서 검증한다.

## 8. 잠금 게이트

### 데모

- [ ] `demo_full` 필수 행의 `unit_count`가 모두 확정됐다.
- [ ] 임시 비율이 20% 이하다.
- [ ] 필수 단서 대체 자산이 같은 행 또는 연결 행에 있다.
- [ ] 라이선스 `TBD`가 없다.
- [ ] 내부 제작물의 `evidence`에 검증된 `rights_ref`가 있다.
- [ ] 모든 `is_placeholder=false` 행에 build QA 근거가 있다.

### 정식판

- [ ] `full_only`를 포함한 필수 행의 임시 비율이 0%다.
- [ ] `REVIEW`, `APPROVED`에 머문 필수 행이 없다.
- [ ] 크레딧과 license registry가 manifest와 일치한다.
- [ ] 교체된 파일이 빌드와 LFS에서 고아 참조를 남기지 않는다.
