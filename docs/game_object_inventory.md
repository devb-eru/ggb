# GGB 전체 제작 오브젝트 인벤토리

## 1. 목적

아트·콘텐츠·구현팀이 게임에 등장하는 물체를 한곳에서 조회하기 위한 독립 목록이다. 이 문서에서 “오브젝트”는 런타임 저장 개체뿐 아니라 플레이어가 보고, 읽고, 클릭하고, 조작하거나 장면 구성을 위해 별도 제작해야 하는 물체 묶음을 포함한다.

정본과 제작 단위를 섞지 않기 위해 다음 두 층을 유지한다.

| 층 | ID | 의미 | 변경 절차 |
| --- | --- | --- | --- |
| 정본 런타임 오브젝트 | `OBJ_*`, `SERVANT_OBJ_*` | 독립 상태·반응·저장 의미를 갖는 62개 개체 | v0.4 `04·05·15·17`, 매니페스트와 함께 변경 |
| 제작 엔티티 | `PRDOBJ_*` | 퍼즐 하위 부품·읽기 자료·UI·캐릭터 소품·장식군을 조회하기 위한 카탈로그 ID | 저장 키로 사용하지 않으며 부모 정본/에셋 아래 납품 |

`PRDOBJ_*`는 제작 대장 전용 ID다. Godot 상태 키, 이벤트 ID, 세이브 데이터에 기록하지 않는다. 동일한 의자나 책이 여러 개 놓이는 경우 개별 인스턴스를 무한히 늘리지 않고 “동일 제작 묶음” 한 행과 공간별 배치표로 관리한다.

## 2. 전수 범위 요약

| 범주 | 조회 위치 | 수량 기준 |
| --- | --- | ---: |
| 정본 런타임 오브젝트 | [정본 대장](game_object_catalog.md) | 62 |
| 공간 구조·이동·생활 소품군 | §3 | 27 제작 묶음 |
| 튜토리얼·조사·읽기 자료 | §4 | 25 제작 묶음 |
| 메인 퍼즐 하위 부품 | §5 | 14 패널·60 하위 부품군 |
| 캐릭터 소품·부착부 | §6 | 13 제작 묶음 |
| UI 화면·공통 조작부 | §7 | 13 화면·11 공통 부품군 |
| 상점·홍보 출력물 | §8 | 9행·13단위 |

정본 62개는 [game_object_catalog.md](game_object_catalog.md)에 이름·위치·기능을 모두 열거한다. 아래 표는 그 62개에 포함되지 않지만 제작에서 빠지면 장면 또는 상호작용이 성립하지 않는 대상이다.

### 2.1 정본 62개 빠른 목록

| 범주 | object_id·표시명 |
| --- | --- |
| 침실·수면 6 | `OBJ_BEDROOM_BED` 침실 침대<br>`OBJ_BEDROOM_WINDOW` 침실 창문<br>`OBJ_SUBJECT_NOTEBOOK_SIM` 시뮬레이션 수첩<br>`OBJ_BEDROOM_MIRROR` 침실 거울<br>`OBJ_BEDROOM_CALL_CORD` 침실 호출끈<br>`OBJ_EMERGENCY_REST_CAPSULE` 비상 휴식 캡슐 |
| 중앙홀·생활 8 | `OBJ_HALL_FAMILY_PORTRAIT` 가족 초상화<br>`OBJ_HALL_WALLPAPER` 복도 벽지<br>`OBJ_HALL_CALL_CORD` 중앙홀 호출끈<br>`OBJ_KITCHEN_TEA_SET` 차 도구<br>`OBJ_DINING_TABLE` 식탁<br>`OBJ_KITCHEN_LIFE_PIPE` 주방 하부 배관<br>`OBJ_GREENHOUSE_DOOR` 온실 잠금문<br>`OBJ_GREENHOUSE_PLANTER` 온실 화분 |
| 서재·지하·거울 11 | `OBJ_LIBRARY_OUTER_SHELVES` 외부 서고 책장<br>`OBJ_LIBRARY_INNER_SHELVES` 기록 내실 책장<br>`OBJ_LIBRARY_JOURNAL` 아버지의 일지<br>`OBJ_LIBRARY_JOURNAL_DESK` 일지 책상<br>`OBJ_LIBRARY_INDEX_DRAWERS` 색인 서랍<br>`OBJ_LIBRARY_RECORD_CLOCK` 기록 내실 경계 시계<br>`OBJ_LIBRARY_SERVICE_ALCOVE` 점검 벽감<br>`OBJ_LIBRARY_PORTRAIT_LATCH` 초상화 걸쇠<br>`OBJ_LIBRARY_MAP_FLOOR` 지도 이중 바닥<br>`OBJ_MIRROR_BLACK` 검은 거울<br>`OBJ_BASEMENT_AXIS_DEVICE` 세 축 장치 |
| 북쪽 기록·코어 7 | `OBJ_ARCHIVE_NAMEPLATES` 기록 회랑 이름표<br>`OBJ_ARCHIVE_PORTRAIT_01` 겹친 단체 초상화<br>`OBJ_COLOR_SEPARATOR_PANEL` 색분해실 외부 패널<br>`OBJ_PERSONALITY_ARCHIVE_TERMINAL` 인격 아카이브 단말<br>`OBJ_CORE_WAKE_DEVICE` 냉각 기상 장치<br>`OBJ_CORE_LOOP_STABILIZER` 루프 안정화 장치<br>`OBJ_CORE_NOTEBOOK_TERMINAL` SUBJECT 수첩대 |
| 현실 11 | `OBJ_REALITY_HAND` 현실의 손<br>`OBJ_REALITY_BREATH_MONITOR` 호흡 표시기<br>`OBJ_REALITY_RESTRAINT` 고정 벨트<br>`OBJ_REALITY_FIELD_NOTEBOOK` 공동 인계 수첩<br>`OBJ_REALITY_EXIT_PANEL` 시설 출구 패널<br>`OBJ_REALITY_CAPSULE_GLASS` 캡슐 유리<br>`OBJ_REALITY_EMPTY_STAND` 빈 연구원 거치대<br>`OBJ_REALITY_TOOLBOX` 공구함<br>`OBJ_REALITY_DRY_PLANTER` 마른 재배함<br>`OBJ_REALITY_NAME_WALL` 이름 벽<br>`OBJ_REALITY_DISTANT_SIGNAL` 먼 신호 |
| 잔류 14 | `OBJ_STAY_MEMORY_CHARTER` 기억 헌장<br>`OBJ_STAY_APPEARANCE_CONTROL` 외형 표시 제어<br>`OBJ_STAY_AUTONOMY_CHARTER` 자율성 헌장<br>`OBJ_STAY_CLOCK` 중앙홀 시계<br>`OBJ_STAY_SCHEDULE` 일정표<br>`OBJ_STAY_FRONT_DOOR` 정문<br>`OBJ_STAY_CARPET` 카펫<br>`OBJ_STAY_CALL_CORD` 호출끈<br>`OBJ_STAY_NOTEBOOK` 잔류 수첩<br>`OBJ_STAY_STAIN` 식탁 얼룩<br>`OBJ_STAY_TEA` 차<br>`OBJ_STAY_SEASON_WINDOW` 계절창<br>`OBJ_STAY_PORTRAIT_LABEL` 초상화 이름표<br>`OBJ_STAY_RAPIER` 레이피어 |
| 사용인 부착 인터페이스 5 | `SERVANT_OBJ_EDGAR_LOCK_PORT` 에드가 잠금 포트<br>`SERVANT_OBJ_MARA1_MAINTENANCE_PORT` 마라 1 정비 포트<br>`SERVANT_OBJ_LUCA_BIO_PORT` 루카 생체 포트<br>`SERVANT_OBJ_IRIS_SENSOR_MEMBRANE` 이리스 센서막<br>`SERVANT_OBJ_MARA2_ARCHIVE_PORT` 마라 2 기록 포트 |

## 3. 공간 구조·생활 소품군

| production_id | 이름 | 위치 | 부모·용도 | 필수 상태·배치 |
| --- | --- | --- | --- | --- |
| `PRDOBJ_NAV_DOOR_SET` | 일반 저택 문·손잡이 세트 | M2·M1 전역 | 공간 이동 | 열림·닫힘·잠김·해금, 문틀과 손잡이 분리 |
| `PRDOBJ_NAV_FACILITY_DOOR_SET` | 시설 격벽·정비문 세트 | H0 전역 | S3 이동 | 잠김·개방·수동 해제, 저택 문과 실루엣 구분 |
| `PRDOBJ_NAV_AIRLOCK_SET` | 현실 에어록·수동 레버 | `R0_FACILITY_EXIT` | 현실 출구 | 전원 확인·공기 확인·수동 해제·개방 |
| `PRDOBJ_M2_RAIL_LIGHT_SET` | 2층 난간·벽등·방향 장식 | M2 회랑 | 길 찾기 | S0 외피·S2 체결부·S3 시설 골격 |
| `PRDOBJ_HALL_STAIR_SET` | 중앙 계단·난간 | `M1_CENTRAL_HALL` | 허브 구도 | S0·S1 어긋남·S3 척추·S5 안정화 |
| `PRDOBJ_HALL_CLOCK_DECOR` | 중앙홀 장식 시계군 | 중앙홀 | 시간 반복 암시 | 정상·한 박자 지연·잔류 정상화 |
| `PRDOBJ_PARLOR_WINDOW_SET` | 대응접실 세 창·걸쇠 | `M1_PARLOR` | P2·B3 기준 | 오염·부분 청소·완료·리셋 복원 |
| `PRDOBJ_PARLOR_FURNITURE_SET` | 소파·낮은 탁자·커튼 | `M1_PARLOR` | 생활 배경 | 기본·S1 반복·S3 평면 외피 |
| `PRDOBJ_LIBRARY_READING_SET` | 분류대·의자·사다리·서류 더미 | 서재 2구역 | P3·B1·B2 | 정리 전/후·조사 가능/소진 |
| `PRDOBJ_ARCHIVE_FRAME_RACK_SET` | 액자 선반·운반대·작업대 | 북쪽 기록 구역 | P3B·마라 2 | 정상·이중 윤곽·인덱스 노출 |
| `PRDOBJ_DINING_CHAIR_SET` | 식탁 의자 6석 | `M1_DINING_ROOM` | E5·잔류 | 관계 등급별 착석/공석 배치 |
| `PRDOBJ_DINING_CABINET_SET` | 찬장·식기장·서빙대 | 식당 | 생활·후속 | 닫힘·열림·S5 생활 흔적 |
| `PRDOBJ_KITCHEN_WORK_SET` | 조리대·싱크·선반·화구 | 주방 | P4·C3 | 준비 전·사용 중·정리 후·S3 배관 노출 |
| `PRDOBJ_KITCHEN_CROCKERY_SET` | 컵·찻잔·접시·주전자 받침 | 주방·식당 | 차·식탁 폴리 | 온전·사용·얼룩·정리 |
| `PRDOBJ_GREENHOUSE_GLASS_SET` | 유리벽·천창·환기창 | 온실 | 날씨 모순 | 계절 영상·센서 이음새·S3 제어층 |
| `PRDOBJ_GREENHOUSE_PLANT_SET` | 화분·덩굴·건조 식물군 | 온실 | P5·이리스 | 계절 불일치·센서 교정·후속 회복/정지 |
| `PRDOBJ_SERVICE_LOCKER_SET` | 작업 사물함·선반·표찰 | 정비 구역 | 사용인 업무 | 닫힘·열림·주인별 문양·S3 인덱스 |
| `PRDOBJ_TOOL_STORAGE_SET` | 공구벽·공구함·보관함 | 도구실·배선실 | C2·E3_1 | 정돈·일부 회수·반납·파열 |
| `PRDOBJ_BASEMENT_SHELF_SET` | 지하 저장 선반·연구 상자 | `B1_STORAGE` | D2 조사 | 잠김 실루엣·개방·조사 완료 |
| `PRDOBJ_CLOCKWORK_ROOM_SET` | 기어벽·축·공명통·케이블 | 대시계·태엽 심장 | B3·D4 | 정상·잠김·기동·외피 박리 |
| `PRDOBJ_H0_PIPE_SET` | 시설 배관·펌프·밸브군 | H0 | S3 길 찾기·수리 | 손상·우회·안정화 |
| `PRDOBJ_H0_CABLE_TRAY_SET` | 케이블 트레이·릴레이·단자대 | H0 | 데이터 경로 | 끊김·점멸·수리·코어 동기화 |
| `PRDOBJ_H0_SIGNAGE_SET` | 시설 표지·위험 라벨·실 번호 | H0 | 비색상 길 찾기 | 고딕 외피 중첩·S3 노출 |
| `PRDOBJ_CORE_SEAT_SET` | 코어실 작업석·연구원 거치 구조 | `H0_CORE_CHAMBER` | F2·EDC | 빈 자리·대면·선택 후 분리 |
| `PRDOBJ_REALITY_DEBRIS_SET` | 현실 시설 잔해·먼지·파손 패널 | R0 | 황폐함 | 통행 가능/불가 실루엣, 고어 금지 |
| `PRDOBJ_REALITY_SURVIVAL_SET` | 물통·필터·배터리·표식 끈 | 현실 출구 | 살아가는 법 단서 | 사용 가능·고갈·미확인 |
| `PRDOBJ_STAY_TABLEWARE_SET` | 잔류 식탁의 식기·냅킨·의자 흔적 | 식당 S5 | 마지막 장면 | 관계별 개인 흔적, 완벽한 대칭 금지 |

## 4. 튜토리얼·조사·읽기 자료

| production_id | 이름 | 사건·위치 | 상호작용·상태 |
| --- | --- | --- | --- |
| `PRDOBJ_P2_CLEANING_CLOTH` | 창문 닦는 천 | P2·대응접실 | 획득·사용·오염·세척·반납 |
| `PRDOBJ_P2_WATER_BASIN` | 물대야 | P2 | 적심·헹굼·탁해짐·리셋 복원 |
| `PRDOBJ_P2_DUST_PATTERN` | 창 오염 문양 | P2 | 시작·잘못 번짐·부분 완료·완료 |
| `PRDOBJ_P3_BOOK_SET` | 분류용 책 묶음 | P3·외부 서고 | 집기·분류·오배치·정렬 완료 |
| `PRDOBJ_P3_CLASSIFICATION_LABELS` | 책장 분류표 | P3 | 명칭·문양·선 패턴 대응 |
| `PRDOBJ_P3_JOURNAL_GLIMPSE` | 잠긴 내실 너머 일지 실루엣 | P3 | 발견만 가능·B2 전 접근 불가 |
| `PRDOBJ_P3B_PORTRAIT_LABEL_SET` | 초상화 이름표 작업 묶음 | P3B | 이름·서명 맞추기·오배치·완료 |
| `PRDOBJ_P4_TEA_LEAF_SET` | 찻잎·향신 재료 | P4 | 조사·선택·계량·우림 |
| `PRDOBJ_P4_KETTLE` | 주전자 | P4 | 찬물·가열·적정·과열·따르기 |
| `PRDOBJ_P4_TRAY` | 차 쟁반 | P4 | 빈 쟁반·배치 중·완료·전달 |
| `PRDOBJ_P5_WEATHER_GAUGE` | 외부 날씨 계기 | P5 | 온도·습도·계절 모순 비교 |
| `PRDOBJ_B1_SCHEDULE_BOARD` | 사용인 시간표 게시판 | B1 | 첫 조사·수첩 전사·반복 요약 |
| `PRDOBJ_DOC_WORK_LEDGER` | 근무대장 | B1 | 에드가 동선 단서·사소한 정정 메모 |
| `PRDOBJ_DOC_DELIVERY_SHEET` | 배송표 | B1 | 루카·주방 동선 단서 |
| `PRDOBJ_DOC_CLEANING_ROTA` | 청소 일정표 | B1·C2 | 마라 1의 코팅 정보 |
| `PRDOBJ_DOC_GREENHOUSE_LOG` | 온실 수출·계절 기록 | B1·P5 | 이리스 동선·날씨 모순 |
| `PRDOBJ_DOC_JOURNAL_PAGES` | J1~J5 복원 페이지 묶음 | 기록 내실 | 찢김·부분 복원·새 탭·완전 복원 |
| `PRDOBJ_DOC_CLOCK_WAVEFORM` | 열세 번째 종 파형지 | B4 | 기록·수첩 전사·C4에서 겹치기 |
| `PRDOBJ_DOC_CLEANING_MEASURE` | 세정 측정표·코팅 대장 | C2 | 코팅·건조·중성 조건 단서 |
| `PRDOBJ_DOC_CHEM_LABEL_SET` | 약품 라벨·접힌 메모·시험지침 | C2-1 | 재료·혼합 순서·위험 표시 |
| `PRDOBJ_DOC_MIRROR_TRACING` | 거울 회로 투명지 | C5 | 채널 추적·D0-A 중첩 |
| `PRDOBJ_DOC_BASEMENT_PLAN` | 지하 평면도·축 표기 | D0 | 회전·반전·기준점 중첩 |
| `PRDOBJ_DOC_RESEARCHER_RECORDS` | `REC_*` 연구원 기록 5종 | E3 | 원본·사본·outcome·J4 집계 |
| `PRDOBJ_DOC_FATHER_LOG_SET` | 아버지 마지막 기록 8구간 | F1 | 재생·일시정지·구간 선택·J5 연계 |
| `PRDOBJ_DOC_ENDING_TEXTS` | 현실 수첩·잔류 헌장·잔류 수첩 | 엔딩 | 페이지·탭·관계 후속·반복 읽기 |

## 5. 메인 퍼즐 하위 부품

각 행의 `부품군`은 독립 그림·레이어 또는 조작 상태가 필요한 최소 제작 단위다. 패널 자체의 정본 `asset_id`와 효과 상태는 [퍼즐·전환 아트 명세](requests/art/03_퍼즐_전환_전수명세.md)를 따른다.

| stage_id | 패널 부모 | 부품군 | 필수 변형 |
| --- | --- | --- | --- |
| `B3_A` | `ART_PUZ_B3_A_PANEL` | 외부 시계 하우징, 탁본 4장, 회전판, 반전판, 연결 모서리, 검증 도장 | 집기·회전·반전·유효/무효 연결·완성 |
| `B3_B` | `ART_PUZ_B3_B_PANEL` | 역할 카드, 위상 고리, 제외 슬롯, 봉인핀, 시험 레버, 실행 레버, XIII 홈 | 배치·이동·제외·검토·확정·잠금·성공 |
| `C3` | `ART_PUZ_C3_PANEL` | 용매병, 중화재, 측정 스푼, 혼합컵, 시험지, 교반봉 | 계량·주입·혼합·시험·폐기·정답 용액 |
| `C4` | `ART_PUZ_C4_PANEL` | 검은 거울 표면, 세정 천, 중성 세정제, 파형지, 습식 기준점, 경화 코팅 | 닦기·중첩·부분 반응·과도포·경화·회로 노출 |
| `C5` | `ART_PUZ_C5_PANEL` | 진단 패널, 다섯 서명 채널, SUBJECT 압흔, 냉각 실루엣, 회로 추적지 | 채널 선택·겹침·분리·기록·완료 |
| `D0_A` | `ART_PUZ_D0_A_PANEL` | 저택 지도, 지하 도면, 거울 투명지, 회전축, 반전 손잡이, 기준점 핀 | 자료 선택·회전·반전·고정·중첩 성공 |
| `D1` | `ART_PUZ_D1_PANEL` | 세 축 원판, 깊이 링, 압력핀, 검증 홈, 실패 고정핀, 해금 레버 | 조정·시험·비가역 압력·잠금·복원·해금 |
| `D4` | `ART_PUZ_D4_PANEL` | 태엽 심장, 손잡이, 기어열, XII 눈금, +1 기동부, 위장 외피 | 기어 조합·기동·XIII 생성·필터 해제 |
| `E3_5` | `ART_PUZ_E3_5_PANEL` | 다섯 채널 필터, 원본 인격, 손상 사본, 결손 위치, 체크섬, 병합/분리 제어 | 청취/판독·비교·결손 표시·검증·outcome |
| `F0_A` | `ART_PUZ_F0_A_PANEL` | 입력·중계·출력·제외 타일, 피드백 선, 충돌 표시 | 회전·교환·부분 회로·충돌·완성 |
| `F0_B` | `ART_PUZ_F0_B_PANEL` | 시스템 신호 표본, 물리/기억/생체 슬롯, 파형·문양 라벨 | 재생·분류·오분류·비교·확정 |
| `F0_C` | `ART_PUZ_F0_C_PANEL` | 회로지·저택 도면·환경 자료, 투명도 제어, 반전, 기준점 | 자료 조합·앞뒤·부분 일치·모순·경로 출력 |
| `F0_D` | `ART_PUZ_F0_D_PANEL` | 연구원 행동 문장, 출처 카드, 역할 라벨, 익명 인덱스, 분류 슬롯 | 출처 식별·행동/의도 분리·익명 대체·역할 복원 |
| `F0_E` | `ART_PUZ_F0_E_PANEL` | 과거 인증 자료, SUBJECT 작성면, 연필 입력, 의향 3종, 공통 합류 제어 | 과거 인증·자기 문장·의향 선택·수정·동일 합류 |

## 6. 캐릭터 소품·부착부

| production_id | 소유자 | 물체 | 상태·주의 |
| --- | --- | --- | --- |
| `PRDOBJ_PROP_SUBJECT_NOTEBOOK_PENCIL` | 주인공 | 연필·지우개·종이 조각 | 흑연 압흔·쓰기·지우기·현실 도구와 구분 |
| `PRDOBJ_PROP_SUBJECT_CRYO_GEAR` | 주인공 | 냉각복·고정구 흔적 | 현실 기상, 성적 대상화 금지 |
| `PRDOBJ_PROP_EDGAR_RAPIER` | 에드가 | 레이피어·칼집 | 지시·정렬·잔류 후속, 주인공을 겨누지 않음 |
| `PRDOBJ_PROP_EDGAR_GLOVES` | 에드가 | 장갑·잠금 포트 덮개 | 닫힘·동의 후 개방·수리·복원 |
| `PRDOBJ_PROP_MARA1_SPANNER` | 마라 1 | 스패너·작업 장갑 | 업무·실수·수리·후속 |
| `PRDOBJ_PROP_MARA1_TOOLBELT` | 마라 1 | 정비 허리띠 | 공구 수납·일부 회수·파열 포트 |
| `PRDOBJ_PROP_LUCA_TEA_TOOLS` | 루카 | 찻도구·생체 기록판 | P4·E3_3, 여림과 능력 병행 |
| `PRDOBJ_PROP_LUCA_SENSOR` | 루카 | 쥐 귀 신호부·손목 포트 | 닫힘·동의·진단·안정화 |
| `PRDOBJ_PROP_IRIS_WINGS` | 이리스 | 플라스틱 날개·센서막 | 장식 외피·센서 노출·교정·관계별 손 위치 |
| `PRDOBJ_PROP_IRIS_GARDEN_TOOLS` | 이리스 | 전지가위·물뿌리개·계절표 | 일상·센서 교정, 무기화 금지 |
| `PRDOBJ_PROP_MARA2_NAMECARD` | 마라 2 | 이름표·액자핀 | 반복 확인·분실 공포·이름 보존 |
| `PRDOBJ_PROP_MARA2_ARCHIVE_TOOLS` | 마라 2 | 기록 렌즈·채널 필터·체크섬 카드 | 장난·계산·E3_5 |
| `PRDOBJ_PROP_SERVANT_PORT_COVERS` | 사용인 5명 | 정비 포트 덮개 공통 구조 | 소유자별 문양·동의 전 닫힘·수리 후 공존 |

### 6.1 관계 이벤트 작업 키트

| production_id | 사건 | 부품 | 필수 상태 |
| --- | --- | --- | --- |
| `PRDOBJ_E31_WIRING_KIT` | E3_1 마라 1 | 손상 배선, 단자대, 우회선, 삭제 로그판, 절연 공구 | 진단·분리·재결선·과부하 경고·안정화 |
| `PRDOBJ_E32_CLIMATE_KIT` | E3_2 이리스 | 계절 센서막, 전력 추적판, 온도·습도 기준표, 교정 프레임 | 불일치·시험·교정·외부 진실/보호 투사 outcome |
| `PRDOBJ_E33_LIFE_SUPPORT_KIT` | E3_3 루카 | 생명 배관, 밸브 4종, 압력계, 파형 슬롯, 우회관 | 누출·밸브 선택·압력 비교·안정화·완전 공개/선 안정화 outcome |
| `PRDOBJ_E34_AUTHORITY_KIT` | E3_4 에드가 | 권한 카드, 소유자 토큰, 잠금핀, CHOICE 슬롯, 레이피어 정렬 홈 | 관리자 고정·권한 반환·SUBJECT 선택·복원 |
| `PRDOBJ_E34M_MINIMUM_PIN` | E3_4M | 최소 접근 핀과 안내판 | 대체 접근·관계/기록 미획득·코어 길 개방 |
| `PRDOBJ_E35_ARCHIVE_KIT` | E3_5 마라 2 | 인격 채널 필터, 원본·손상 사본, 결손 프레임, 체크섬 카드 | 병합/분리 outcome·이름 후속·익명 대체 |
| `PRDOBJ_E5_SETTLEMENT_SET` | E5 | 6석 배치, 개인 삽입 소품, 공석 표식, 식사 도구 | LOW/MID/HIGH/ALL·전원 완료 보정 |
| `PRDOBJ_F2_FACT_CARDS` | F2 | 필수 사실 6개 카드와 소유자 반응 삽입부 | 확인·누락 recap·관계별 고백/완곡 표현 |

## 7. UI 화면·공통 조작부

### 7.1 정본 화면 13종

`UI_TITLE`, `UI_FIRST_RUN_ACCESS`, `UI_SAVE_SLOTS`, `UI_SETTINGS`, `UI_DIALOGUE`, `UI_DIALOGUE_HISTORY`, `UI_NOTEBOOK`, `UI_INVENTORY`, `UI_MAP`, `UI_PUZZLE_COMMON`, `UI_DEMO_END`, `UI_ENDING_GALLERY`, `UI_CREDITS`.

### 7.2 공통 부품군

| production_id | 부품 | 필수 상태 |
| --- | --- | --- |
| `PRDOBJ_UI_CURSOR` | 포인터·키보드 초점 표시 | 기본·초점·활성·사용 불가·대기 |
| `PRDOBJ_UI_BUTTON_SET` | 버튼·선택지·탭 | 기본·가리킴·초점·누름·선택·비활성 |
| `PRDOBJ_UI_SCROLL_SET` | 스크롤바·페이지 이동 | 처음·중간·끝·키보드 초점 |
| `PRDOBJ_UI_DIALOGUE_PARTS` | 이름판·본문·진행·선택·자동 진행 | 화자·독백·시스템·감각 자막 |
| `PRDOBJ_UI_NOTEBOOK_TABS` | 관찰·가설·검증·실패·인물·일지 탭 | 새 항목·읽음·잠김·검색 결과 |
| `PRDOBJ_UI_INVENTORY_CARDS` | 당일 아이템·영구 정보 카드 | 획득·선택·조합 가능/불가·리셋 소실 예정 |
| `PRDOBJ_UI_MAP_MARKERS` | 현재 위치·발견·잠금·숏컷·목표 | 색 없이 문양·명칭 병행 |
| `PRDOBJ_UI_PUZZLE_CONTROLS` | 검토·확정·취소·힌트·초기화 | 가능·불가·비가역 확인·로컬 재시도 |
| `PRDOBJ_UI_SAVE_INDICATORS` | 저장 시작·완료·복구·오류 | NORMAL_RESET과 다른 문양·문구 |
| `PRDOBJ_UI_ACCESS_CONTROLS` | 모션·글리치·심박·저주파·텍스트 설정 | 즉시 미리보기·기본값·적용/취소 |
| `PRDOBJ_UI_ENDING_CONTROLS` | 의향·최종 확인·후속 메뉴 | 선택 간 동일 크기·위치·정보량 |

## 8. 상점·홍보 출력물

`STORE_CAPSULE_HEADER`, `STORE_CAPSULE_SMALL`, `STORE_CAPSULE_MAIN`, `STORE_CAPSULE_VERTICAL`, `STORE_LIBRARY_HERO`, `STORE_SCREENSHOTS` 5장, `STORE_TRAILER`, `STORE_LOGO_KO`, `STORE_LOGO_EN`을 [상점·홍보 명세](requests/art/05_상점홍보_전수명세.md)에서 관리한다.

## 9. 누락 방지 계약

1. 새 클릭 대상에 독립 상태·저장 의미가 생기면 먼저 62개 정본 대장으로 승격할지 결정한다.
2. 새 퍼즐 부품·문서·UI 조작부·캐릭터 소품은 해당 부모 에셋과 함께 이 목록에 추가한다.
3. 배경 장식은 동일 제작 묶음을 재사용할 수 있지만, 공간마다 필요한 배치·가림·월드 단계는 [공간 아트 명세](requests/art/01_공간_전수명세.md)에 기록한다.
4. `PRDOBJ_*`가 독립 클릭·저장·콘텐츠 분기를 갖게 되면 카탈로그 ID를 런타임에서 그대로 쓰지 않고 정식 `OBJ_*` 발급 절차를 거친다.
5. `GGB-CNF-2026-0018` 해결 전 외부 서고 B3 시계는 B3-A 패널의 자식 제작 엔티티이며 `OBJ_LIBRARY_RECORD_CLOCK`이 아니다.
