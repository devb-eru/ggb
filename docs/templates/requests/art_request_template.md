# REQ-ART-YYYY-NNNN: 아트 제작 의뢰 제목

> 안내 문구를 지운 뒤 사용한다. 기술 기본값은 `docs/content_pipeline_specs.md`를 따르고, 예외만 본문에 적는다.

## 1. 의뢰 정보

| 필드 | 값 |
| --- | --- |
| request_id | `REQ-ART-YYYY-NNNN` |
| 상태 | `DRAFT` |
| 배치·우선순위 | `BATCH-*` · `P2` |
| 담당 팀장·검토자 | `UNASSIGNED` · `UNASSIGNED` |
| 목표 마일스톤 | `UNSCHEDULED` |
| 플랫폼 | Windows 10/11 64-bit PC |
| 참조 work_id | `미발급` |
| request revision | `1` |

## 2. 목적과 전달 정보

플레이어가 무엇을 보고 알아야 하는지, 감정 곡선에서 어떤 역할을 하는지 쓴다.

## 3. 범위

### 포함

- 제작할 범위.

### 제외

- 이번 의뢰에서 만들지 않을 범위.

## 4. 참조 ID

| asset_id | 유형 | location_id·event_id·object_id | 요청 subset | 우선순위 |
| --- | --- | --- | --- | --- |
| `ART_*` | background / object / character / puzzle / UI / VFX | `*` | base·state·pose 등 | MUST |

## 5. 시각 요구

| 항목 | 요구 |
| --- | --- |
| 구도·카메라 |  |
| 세계 단계·상태 변형 |  |
| 상호작용 hotspot |  |
| 캐릭터 anchor·가림 |  |
| 대표색·문양·선 패턴 |  |
| 심리·감각 기능 |  |
| 피해야 할 표현 |  |

## 6. 에셋별 상세

각 에셋에 대해 기본 상태, 상호작용 상태, 실패·성공·반복 상태, 재사용 의도를 적는다.

## 7. 접근성

- 색을 제거해도 문양·형태·텍스트로 구분된다.
- 1280x720과 200% UI에서 필수 hotspot·단서가 가려지지 않는다.
- 모션 감소용 정적 상태를 제공한다.
- 필수 클릭 영역은 44x44 논리 px 이상이다.

## 8. 납품

| 묶음 | 요구 |
| --- | --- |
| source | PSD·KRA 등 편집 원본과 외부 브러시·폰트 조건 |
| runtime | `asset_id__variant__rNN.ext` |
| preview | 1080p·720p·4K·200% UI·색 제거 capture |
| layer sheet | 카메라·anchor·hotspot·foreground·phase layer |
| evidence | revision·제작자·권리 ID·메모리 추정·검토 결과 |

## 9. 수락·완료 조건

### 팀 수락

- [ ] 담당자와 예상 공수가 기록됐다.
- [ ] 포함 subset과 제외 범위에 합의했다.
- [ ] 차단 설정·선행 에셋이 기록됐다.

### 제작 완료

- [ ] 요청한 state와 source·runtime export가 모두 있다.
- [ ] 접근성·해상도 capture가 있다.
- [ ] `asset_id`, revision과 권리 증거가 연결됐다.
- [ ] 팀장과 QA 검토 결과가 남았다.

## 10. 팀 회신·변경 이력

| 날짜 | 주체 | 내용 | 상태·revision |
| --- | --- | --- | --- |
| YYYY-MM-DD | 작성자 | 최초 작성 | DRAFT · r1 |
