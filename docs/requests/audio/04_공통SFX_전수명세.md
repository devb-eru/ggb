# GGB 공통 SFX 전수 명세

## 1. 공통 규칙

공통 SFX는 특정 퍼즐 pack의 재질음과 겹칠 때 짧은 UI·커밋 층으로만 사용한다. 모든 항목은 기본 `loop=false`이며, 연타 가능한 항목은 variation과 cooldown을 둔다.

| asset_id | 용도·느낌 | 길이 | 악기·음색·음원 | 반복 여부·변형 | sensory_caption_id |
| --- | --- | ---: | --- | --- | --- |
| `SFX_NORMAL_RESET_SLEEP` | 정상 수면 진입, 몸의 압력이 천천히 줄어듦 | 1.5~3초 | 침구·천·낮은 공기 감쇠 | one-shot; 첫/반복 2종 | `CAP_NORMAL_RESET_SLEEP` |
| `SFX_NORMAL_RESET_COMMIT` | 영구 정보가 안전하게 커밋됨, 디스크 저장과 구분 | 0.8~1.4초 | 종이 압흔+짧은 relay 2단 | one-shot; 중복 재생 금지 | `CAP_NORMAL_RESET_COMMIT` |
| `SFX_CLOCK_BELL_13` | 열세 번째 종과 B4 파형의 핵심 사건 | 4~7초 | 실제 금속 종, 12회 잔향 뒤 구조가 다른 13번째 공명 | one-shot; 저주파 감소·짧은 대체 | `CAP_CLOCK_BELL_13` |
| `SFX_CLOCK_NETWORK_LOCK` | B3-B HARD FAILURE 뒤 당일 시계망 잠금 | 1.2~2초 | 연쇄 잠금핀, 기어 정지, 목재 공명 | one-shot | `CAP_CLOCK_NETWORK_LOCK` |
| `SFX_MIRROR_CLEAN` | C4 천 이동과 젖음 정도 | 0.15~0.6초 | 젖은/마른 천·유리 4 variation | one-shot; 120ms cooldown | `CAP_MIRROR_CLEAN_STATE` |
| `SFX_MIRROR_REVEAL` | 회로와 진단면이 표면 아래 드러남 | 1.8~3초 | 유리 장력 해제, 얇은 relay, 공기층 | one-shot | `CAP_MIRROR_REVEAL` |
| `SFX_JOURNAL_RESTORE` | 한 페이지/문장 결합 시점 | 0.8~1.5초 | 종이 맞물림, 제본실, 흑연 | one-shot; J1~J5 3 variation | `CAP_JOURNAL_RESTORE` |
| `SFX_NOTEBOOK_WRITE` | 주인공의 자기작성·수첩 기록 | 0.25~1.2초 | 연필, 종이 섬유, 압력별 5 variation | one-shot; 80ms cooldown | `CAP_NOTEBOOK_WRITE` |
| `SFX_SHORTCUT_CONFIRM` | 이미 검증한 준비를 축약 경로로 전환 | 0.7~1.1초 | 종이 접기+문 잠금 해제의 부드러운 2단 | one-shot; 성공 fanfare 금지 | `CAP_SHORTCUT_CONFIRM` |
| `SFX_HARD_FAILURE_COMMIT` | 물리 변형을 되돌릴 수 없는 당일 커밋 | 0.9~1.5초 | 둔한 핀 고정, 낮은 압력 하강 | one-shot; 위험 경고와 구분 | `CAP_HARD_FAILURE_COMMIT` |
| `SFX_DOOR_LOCK` | 일반 문·시설문 잠금 | 0.25~0.8초 | 목재 걸쇠/금속 핀/시설 자석 3재질 | one-shot; 3~5 variation | `CAP_DOOR_LOCK` |
| `SFX_DOOR_UNLOCK` | 정보·퍼즐로 경로가 열림 | 0.3~1초 | 걸쇠 이탈/압력 해제/시설 relay | one-shot; `SFX_SHORTCUT_CONFIRM`과 구분 | `CAP_DOOR_UNLOCK` |
| `SFX_ITEM_PICKUP` | 종이·병·공구·카드 획득 | 0.12~0.6초 | 종이/유리/금속/천/전자 카드 재질별 variation | one-shot; 100ms cooldown | `CAP_ITEM_PICKUP` |
| `SFX_PUZZLE_VALIDATE` | 현재 입력 조합이 검증을 통과 | 0.35~0.8초 | 절제된 두 단계 확인음, 퍼즐 재질 본체 위 얇게 | one-shot | `CAP_PUZZLE_VALIDATE` |
| `SFX_PUZZLE_REJECT` | 현재 입력이 무효이나 상태 손실 없음 | 0.25~0.65초 | 둔한 단일 click+짧은 되돌림, 경보음 금지 | one-shot; 연속 3회 이후 더 부드러운 variant | `CAP_PUZZLE_REJECT` |
| `SFX_UI_FOCUS` | 키보드·마우스 초점 이동 | 0.05~0.12초 | 종이 모서리/작은 무음정 tick | one-shot; 60ms cooldown, 반복 감소 시 50% 생략 | `CAP_UI_FOCUS` |
| `SFX_UI_CONFIRM` | 일반 버튼·선택 확정 | 0.12~0.25초 | 낮고 짧은 2층 click | one-shot | `CAP_UI_CONFIRM` |
| `SFX_UI_CANCEL` | 취소·뒤로, 불이익 없음 | 0.12~0.28초 | 종이 접힘/부드러운 역방향 click | one-shot | `CAP_UI_CANCEL` |
| `SFX_SAVE_START` | 디스크 저장 트랜잭션 시작 | 0.35~0.7초 | 짧은 데이터 seek+고정된 UI 음색 | one-shot; reset commit과 다른 문양 | `CAP_SAVE_START` |
| `SFX_SAVE_COMPLETE` | 디스크 저장 완료 | 0.45~0.9초 | 닫히는 데이터 쌍+부드러운 확인 | one-shot; 같은 transaction에서 1회 | `CAP_SAVE_COMPLETE` |

## 2. 부모 아래 필수 폴리 단위

매니페스트에 별도 행을 늘리지 않고 아래를 기존 부모의 `cue_part_id`로 납품한다. 실제 파일·메모리·재사용성이 독립 에셋 수준으로 커지면 매니페스트 행을 먼저 추가한다.

| cue_part_id 묶음 | 부모 | 범위 |
| --- | --- | --- |
| `FOL_FOOTSTEP_WOOD/CARPET/STONE/METAL` | 각 `AUD_AMB_<LOCATION>` | 공간 전환·근접/원거리 사용인 발소리, 거리 3단 |
| `FOL_DOOR_WOOD/GLASS/FACILITY/AIRLOCK` | `SFX_DOOR_LOCK`, `SFX_DOOR_UNLOCK` | 문짝·손잡이·걸쇠·수동 레버 |
| `FOL_PAPER/BOOK/GRAPHITE` | `SFX_ITEM_PICKUP`, `SFX_NOTEBOOK_WRITE`, `SFX_JOURNAL_RESTORE` | 서류·책·수첩·투명지 |
| `FOL_CLOTH/BRUSH/TOOL` | `SFX_ITEM_PICKUP`, `SFX_MIRROR_CLEAN` | P2 청소·C2/C4·마라 1 정비 |
| `FOL_GLASS/MIRROR` | `SFX_MIRROR_CLEAN`, `SFX_MIRROR_REVEAL` | 창·거울·약품병·온실 유리 |
| `FOL_LIQUID/TABLEWARE` | `SFX_ITEM_PICKUP`, `AUD_AMB_M1_KITCHEN` | 차·혼합액·물·식기·잔류 식탁 |
| `FOL_FAN/RELAY/PUMP/GEAR/FIXTURE` | H0·B1 앰비언스와 각 퍼즐 pack | 시설·수리·코어·현실 장치 |

## 3. 접근성·자막 규칙

- 짧은 UI focus마다 자막을 띄우지 않는다. 결과·상태 변화가 있을 때만 `sensory_caption_id`를 호출한다.
- `[금속이 잠긴다]` 대신 `[대시계의 잠금핀이 연달아 고정된다]`처럼 대상과 결과를 적는다.
- 음량 0에서는 초점 테두리, 상태명, 화면 pulse, 파형과 입력 로그가 같은 결과를 보여 준다.
- `SFX_CLOCK_BELL_13`, 심박 유사음, 저주파 압력은 각각 강도·반복·저주파 감소 variant를 제공한다.

## 4. 완료 조건

- 정본 SFX 20개가 정확히 한 번씩 존재하고 각 variation 수와 cooldown이 registry에 기록된다.
- 공통 폴리 7묶음이 사용 위치·부모·권리 정보와 연결된다.
- 퍼즐 pack·이벤트 pack과 중복되는 소리는 어느 부모가 본체/레이어를 소유하는지 명확하다.
- 저장·NORMAL_RESET·HARD FAILURE·숏컷·일반 확인음이 청각과 시각 모두에서 구분된다.
