# GGB 정본 런타임 오브젝트 대장

## 1. 목적

이 문서는 독립된 상태·반응·저장 의미를 갖는 62개 정본 런타임 오브젝트의 사람용 색인이다. 기계 판독 정본은 [game_object_catalog.csv](game_object_catalog.csv)이며, 퍼즐 부품·문서·UI·캐릭터 소품·배경 소품군까지 포함한 제작 전수 목록은 [전체 제작 오브젝트 인벤토리](game_object_inventory.md)에서 확인한다. 상세 반응은 [공통 오브젝트 반응](../ideas/md/v04/15_이벤트상세_10_공통오브젝트반응.md), 위치는 [공간 구성 지도](../ideas/md/v04/05_공간구성지도_및_동선.md), 아트 행은 [에셋 매니페스트](asset_manifest.csv)를 따른다.

## 2. 포함 기준

다음 대상은 오브젝트로 센다.

- 월드에서 클릭하거나 조작하는 물체.
- 이동·잠금·수면·엔딩 진입을 담당하는 물체.
- 수첩·일지·단말처럼 정보와 영구 상태를 보유하는 물체.
- 퍼즐의 진입점이거나 결과 상태가 월드에 남는 물체.
- 동의가 필요한 사용인 부착 인터페이스.
- 현실·잔류 엔딩에서 필수 또는 선택 후속 반응을 가진 물체.

다음은 이 대장의 62개 정본 오브젝트에 포함하지 않는다.

- `ART_PUZ_*` 확대 패널과 그 내부 버튼·카드: 퍼즐 제작 부품 대장에서 관리한다.
- `UI_*` 화면과 버튼: UI 제작 대장에서 관리한다.
- 배경 장식 군집, 이동 화면의 비활성 소품: 공간 명세의 배치 요소로 관리한다.
- 레이피어·스패너처럼 캐릭터 시트에 종속된 일반 소품. 단, 독립 상호작용이 생긴 `OBJ_STAY_RAPIER`는 포함한다.

## 3. 수량

| 범주 | 수 | 범위 |
| --- | ---: | --- |
| 침실·수면 | 6 | 리셋·영구 수첩·파열 수면 |
| 중앙홀·생활 | 8 | 일상·관계·주방·온실 |
| 서재·지하·거울 | 11 | 기록·압박·메인 퍼즐 |
| 북쪽 기록·코어 | 7 | 마라 2·최종 선택 장치 |
| 현실·잔류 | 25 | 두 엔딩의 필수·선택 후속 |
| 사용인 부착 인터페이스 | 5 | 동의 기반 진단·수리 |
| **합계** | **62** | `asset_manifest.csv`의 `object_state` 62행과 일치 |

## 4. 빠른 목록

### 4.1 침실·수면

| ID | 이름 | 위치 | 핵심 기능 |
| --- | --- | --- | --- |
| `OBJ_BEDROOM_BED` | 침실 침대 | `M2_BEDROOM` | 정상 수면·리셋·파열 후 휴식 |
| `OBJ_BEDROOM_WINDOW` | 침실 창문 | `M2_BEDROOM` | 반복 경로·외부 센서 모순 |
| `OBJ_SUBJECT_NOTEBOOK_SIM` | 시뮬레이션 수첩 | 휴대 | 영구 정보·실패 기록·자기 선택 |
| `OBJ_BEDROOM_MIRROR` | 침실 거울 | `M2_BEDROOM` | 반사 지연·E1 조사 |
| `OBJ_BEDROOM_CALL_CORD` | 침실 호출끈 | `M2_BEDROOM` | 사용인 호출·기억 누수 |
| `OBJ_EMERGENCY_REST_CAPSULE` | 비상 휴식 캡슐 | `H0_SERVICE_SPINE` | D5 이후 단발 파열 수면 |

### 4.2 중앙홀·생활 공간

| ID | 이름 | 위치 | 핵심 기능 |
| --- | --- | --- | --- |
| `OBJ_HALL_FAMILY_PORTRAIT` | 가족 초상화 | `M1_CENTRAL_HALL` | 세계 단계·가족 정보 |
| `OBJ_HALL_WALLPAPER` | 복도 벽지 | 복도군 | 길 찾기·외피 파열 |
| `OBJ_HALL_CALL_CORD` | 중앙홀 호출끈 | `M1_CENTRAL_HALL` | 관계 허브 호출 |
| `OBJ_KITCHEN_TEA_SET` | 차 도구 | `M1_KITCHEN` | P4·C3·F0-B |
| `OBJ_DINING_TABLE` | 식탁 | `M1_DINING_ROOM` | E5 결산·잔류 후속 |
| `OBJ_KITCHEN_LIFE_PIPE` | 주방 하부 배관 | 주방·생명 유지실 | 루카 수리·F0 회수 |
| `OBJ_GREENHOUSE_DOOR` | 온실 잠금문 | `M1_GREENHOUSE_VESTIBULE` | 날씨 모순·이리스 접근 |
| `OBJ_GREENHOUSE_PLANTER` | 온실 화분 | `M1_GREENHOUSE` | 계절 모순·센서 교정 |

### 4.3 서재·지하·거울

| ID | 이름 | 위치 | 핵심 기능 |
| --- | --- | --- | --- |
| `OBJ_LIBRARY_OUTER_SHELVES` | 외부 서고 책장 | `M1_LIBRARY_OUTER` | P3 분류·B3-A |
| `OBJ_LIBRARY_INNER_SHELVES` | 기록 내실 책장 | `M1_LIBRARY_INNER` | B2·J1~J4 기록 탐색 |
| `OBJ_LIBRARY_JOURNAL` | 아버지의 일지 | `M1_LIBRARY_INNER` | J1~J4 영구 복원 |
| `OBJ_LIBRARY_JOURNAL_DESK` | 일지 책상 | `M1_LIBRARY_INNER` | 압박·은신·복원 조작 |
| `OBJ_LIBRARY_INDEX_DRAWERS` | 색인 서랍 | `M1_LIBRARY_INNER` | B2 색인·D0 단서 |
| `OBJ_LIBRARY_RECORD_CLOCK` | 기록 내실 경계 시계 | `M1_LIBRARY_INNER` | 에드가 진입 예고 |
| `OBJ_LIBRARY_SERVICE_ALCOVE` | 점검 벽감 | `M1_LIBRARY_INNER` | 비실패 은신 선택 |
| `OBJ_LIBRARY_PORTRAIT_LATCH` | 초상화 걸쇠 | `M1_LIBRARY_INNER` | 내실 접근 숏컷 |
| `OBJ_LIBRARY_MAP_FLOOR` | 지도 이중 바닥 | `M1_LIBRARY_INNER` | D0-A 중첩 지도 |
| `OBJ_MIRROR_BLACK` | 검은 거울 | `M1_MIRROR_GALLERY` | C0~C5·F0-C |
| `OBJ_BASEMENT_AXIS_DEVICE` | 세 축 장치 | `B1_AXIS_CHAMBER` | D1 확정 물리 실패 |

### 4.4 북쪽 기록·코어

| ID | 이름 | 위치 | 핵심 기능 |
| --- | --- | --- | --- |
| `OBJ_ARCHIVE_NAMEPLATES` | 기록 회랑 이름표 | `M1_NORTH_ARCHIVE_HALL` | 이름·서명 튜토리얼 |
| `OBJ_ARCHIVE_PORTRAIT_01` | 겹친 단체 초상화 | `M1_PORTRAIT_STORAGE` | 원본·손상 사본 단서 |
| `OBJ_COLOR_SEPARATOR_PANEL` | 색분해실 외부 패널 | `M1_COLOR_ROOM_ENTRY` | E3_5 접근 잠금 |
| `OBJ_PERSONALITY_ARCHIVE_TERMINAL` | 인격 아카이브 단말 | `H0_PERSONALITY_ARCHIVE` | E3_5·F0-D |
| `OBJ_CORE_WAKE_DEVICE` | 냉각 기상 장치 | `H0_CORE_CHAMBER` | 현실 기상 후보 |
| `OBJ_CORE_LOOP_STABILIZER` | 루프 안정화 장치 | `H0_CORE_CHAMBER` | 잔류 후보 |
| `OBJ_CORE_NOTEBOOK_TERMINAL` | SUBJECT 수첩대 | `H0_CORE_CHAMBER` | 결정 유보·재조사 |

### 4.5 현실 엔딩

| ID | 이름 | 위치 | 필수성 |
| --- | --- | --- | --- |
| `OBJ_REALITY_HAND` | 현실의 손 | `R0_CRYO_CHAMBER` | 신체 확인 3종 중 2종 |
| `OBJ_REALITY_BREATH_MONITOR` | 호흡 표시기 | `R0_CRYO_CHAMBER` | 신체 확인 3종 중 2종 |
| `OBJ_REALITY_RESTRAINT` | 고정 벨트 | `R0_CRYO_CHAMBER` | 신체 확인 3종 중 2종 |
| `OBJ_REALITY_FIELD_NOTEBOOK` | 공동 인계 수첩 | `R0_CRYO_CHAMBER` | 필수 |
| `OBJ_REALITY_EXIT_PANEL` | 시설 출구 패널 | `R0_FACILITY_EXIT` | 필수 |
| `OBJ_REALITY_CAPSULE_GLASS` | 캡슐 유리 | `R0_CRYO_CHAMBER` | 선택 |
| `OBJ_REALITY_EMPTY_STAND` | 빈 연구원 거치대 | `R0_CRYO_CHAMBER` | 선택 |
| `OBJ_REALITY_TOOLBOX` | 공구함 | `R0_FACILITY_EXIT` | 선택 |
| `OBJ_REALITY_DRY_PLANTER` | 마른 재배함 | `R0_FACILITY_EXIT` | 선택 |
| `OBJ_REALITY_NAME_WALL` | 이름 벽 | `R0_FACILITY_EXIT` | 선택 |
| `OBJ_REALITY_DISTANT_SIGNAL` | 먼 신호 | `R0_SURFACE_THRESHOLD` | 선택·마지막 프레임 |

### 4.6 잔류 엔딩

| ID | 이름 | 위치 | 필수성 |
| --- | --- | --- | --- |
| `OBJ_STAY_MEMORY_CHARTER` | 기억 헌장 | `H0_CORE_CHAMBER` | 필수 |
| `OBJ_STAY_APPEARANCE_CONTROL` | 외형 표시 제어 | `H0_CORE_CHAMBER` | 필수 |
| `OBJ_STAY_AUTONOMY_CHARTER` | 자율성 헌장 | `H0_CORE_CHAMBER` | 필수 |
| `OBJ_STAY_CLOCK` | 중앙홀 시계 | `M1_CENTRAL_HALL` | 선택 |
| `OBJ_STAY_SCHEDULE` | 일정표 | `M1_CENTRAL_HALL` | 선택 |
| `OBJ_STAY_FRONT_DOOR` | 정문 | `M1_CENTRAL_HALL` | 선택 |
| `OBJ_STAY_CARPET` | 카펫 | `M1_CENTRAL_HALL` | 선택 |
| `OBJ_STAY_CALL_CORD` | 호출끈 | `M1_CENTRAL_HALL` | 선택 |
| `OBJ_STAY_NOTEBOOK` | 잔류 수첩 | `M1_DINING_ROOM` | 필수 |
| `OBJ_STAY_STAIN` | 식탁 얼룩 | `M1_DINING_ROOM` | 선택·마라 1 |
| `OBJ_STAY_TEA` | 차 | `M1_DINING_ROOM` | 선택·루카 |
| `OBJ_STAY_SEASON_WINDOW` | 계절창 | `M1_DINING_ROOM` | 선택·이리스 |
| `OBJ_STAY_PORTRAIT_LABEL` | 초상화 이름표 | `M1_DINING_ROOM` | 선택·마라 2 |
| `OBJ_STAY_RAPIER` | 레이피어 | `M1_DINING_ROOM` | 선택·에드가 |

### 4.7 사용인 부착 인터페이스

| ID | 소유자 | 조사 가능 요소 | 조건 |
| --- | --- | --- | --- |
| `SERVANT_OBJ_EDGAR_LOCK_PORT` | 에드가 | 장갑 아래 잠금 인터페이스 | 진단·수리 동의 뒤 |
| `SERVANT_OBJ_MARA1_MAINTENANCE_PORT` | 마라 1 | 팔 정비 포트 | 진단·수리 동의 뒤 |
| `SERVANT_OBJ_LUCA_BIO_PORT` | 루카 | 귀 신호부·손목 생체 포트 | 진단·수리 동의 뒤 |
| `SERVANT_OBJ_IRIS_SENSOR_MEMBRANE` | 이리스 | 머리 장식·날개 센서막 | 진단·수리 동의 뒤 |
| `SERVANT_OBJ_MARA2_ARCHIVE_PORT` | 마라 2 | 목깃 액자핀·기록 포트 | 진단·수리 동의 뒤 |

## 5. 전수성 계약

1. CSV의 `object_id` 집합은 `asset_manifest.csv`에서 `asset_type=object_state`인 `source_entity_id` 집합과 정확히 같아야 한다.
2. 새 오브젝트를 추가할 때 `04`, `05`, `15`, `17`, 에셋 매니페스트와 이 대장을 같은 변경에서 갱신한다.
3. 퍼즐 내부 부품이나 장식 소품에 독립 저장·상호작용이 생기면 먼저 정본 `object_id` 승격 여부를 결정한다.
4. `GGB-CNF-2026-0018`이 해결되기 전 외부 서고 B3 시계는 `OBJ_LIBRARY_RECORD_CLOCK`으로 등록하지 않는다. 이 ID는 기록 내실 경계 시계만 뜻한다.
