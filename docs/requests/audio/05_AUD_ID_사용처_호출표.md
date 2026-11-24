# GGB AUD ID 사용처·호출표

## 1. 문서 목적

이 문서는 [AUD 전수 명세](README.md)의 정본 오디오 부모 ID 97종이 **어디에서, 어떤 조건으로, 어떤 방식으로** 사용되는지 정의한다. 제작 의도와 음색은 `01~04` 전수 명세, 생성 입력문은 [Suno 프롬프트](suno/README.md), 본 문서는 런타임 호출 책임과 장면 연결을 담당한다.

표의 사용처는 기획상 목표다. `현재 연결`은 실제 프로젝트의 `game/data/registries/audio_cue_registry.json`과 호출 코드를 근거로 별도 표기한다. `PLANNED`이거나 `resource_path`가 빈 항목은 호출 요청이 있어도 실제 음원이 재생되지 않는다.

## 2. 읽는 법과 호출 계약

| 항목 | 의미 |
| --- | --- |
| 부모 ID | `asset_manifest.csv`에 등록되는 정본 단위. 한 부모 아래 변형·스템·`cue_part_id`가 존재할 수 있음 |
| 사용처 | `location_id`, 이벤트 ID 또는 시스템 화면 |
| 시작 조건 | 해당 소리의 재생 요청을 보내는 순간 |
| 종료·전환 | 멈추거나 다른 소리로 교체되는 조건 |
| 사용 방식 | 반복·단발·스템 변경·다른 부모와의 레이어 관계 |

공통 규칙:

1. `BGM`은 기본적으로 한 곡만 활성화하며 `world_phase` 또는 엔딩 컨테이너가 바뀔 때 크로스페이드한다.
2. `AUD_AMB_*`는 해당 공간 진입 시 시작하고 공간 이탈 시 정지한다. 같은 공간을 다시 그리거나 확대 UI를 열 때는 재시작하지 않는다.
3. 퍼즐·전환 부모는 하위 `cue_part_id`를 호출한다. 부모 ID만 재생해 묶음 전체를 한 번에 울리지 않는다.
4. `SFX_*`는 공통 UI·오브젝트 층이다. 퍼즐 본체·전환 본체와 겹칠 때 재질음과 역할이 중복되지 않게 한쪽을 생략하거나 시간차를 둔다.
5. 이벤트를 건너뛰거나 저장 상태에서 재개하면 완료된 단발 cue를 다시 재생하지 않는다. 반복 베드만 현재 상태에 맞춰 복구한다.
6. 필수 진행 정보는 감각 자막·상태명·문양·화면 반응을 함께 사용한다. 음원 재생 성공 여부가 플래그·퍼즐 판정·분기 결과를 바꾸지 않는다.

## 3. 공간 앰비언스 39종

모든 항목은 `AMB` 채널의 반복 베드다. 위치 기반 3D 단발 폴리는 이 베드와 별도로 호출한다. 상태 변형은 공간 진입 때 현재 `world_phase`와 이벤트 상태를 읽어 선택하며, 체류 중 상태가 바뀌면 승인된 전환 시간으로 스템을 교체한다.

### 3.1 저택·지하 27종

| 부모 ID | 사용 장소·이벤트 | 시작 조건 | 종료·전환 | 사용 방식 |
| --- | --- | --- | --- | --- |
| `AUD_AMB_M2_BEDROOM` | `M2_BEDROOM`; P1·P6·A1·A2·E1, 모든 정상 아침 | 침실 장면 진입 또는 `NORMAL_RESET`의 `MORNING` 도착 | 상부 회랑 이동 시 정지. 정상 리셋 직후 같은 승인 구간·위상으로 복귀 | S0/S1/S2/S3 변형. 같은 아침 비교를 위해 임의 시작점 금지. E1에서는 파열 후 시설 환기층 노출 |
| `AUD_AMB_M2_UPPER_HALL` | `M2_UPPER_HALL`; P1 첫 이동·P6 귀환·반복 이동 | 침실 문을 나와 회랑 장면이 활성화될 때 | 침실 또는 계단 상부 진입 시 정지 | 첫 회는 전체 베드, 반복 루프의 이동 몽타주는 짧은 승인 구간. S2부터 벽 속 배선층 추가 |
| `AUD_AMB_M2_STAIR_LANDING` | `M2_STAIR_LANDING`; 중앙홀 첫 조망·아침 하강 | 계단 상부 장면 진입 | 중앙홀 또는 상부 회랑 이동 시 정지 | S1 반복 흔적, S3 시설 공명 변형. 중앙홀 앰비언스를 이 파일에 중복 삽입하지 않음 |
| `AUD_AMB_M1_CENTRAL_HALL` | `M1_CENTRAL_HALL`; 일과 선택, E2_INTRO·E_HUB·E5 도입·EDS_CENTRAL_HALL | 중앙홀 진입 또는 E 허브 복귀 | 다른 방 진입 시 정지; E 수리 결과는 스템만 갱신 | S0~S3/S5. E3 완료마다 해당 설비의 흔들림만 안정화. 관계 수에 따른 승리감 변화 금지 |
| `AUD_AMB_M1_PARLOR` | `M1_PARLOR`; P2 창문 닦기, BSHORT 탁본 몽타주 | 대응접실 진입; BSHORT에서는 탁본 확대 장면 시작 | 중앙홀·거울 회랑 이탈 또는 몽타주 종료 | P2 청소 전/후 표면층 교체, S1 창밖 반복층. 실제 닦기 소리는 `FOL_CLOTH`/`SFX_MIRROR_CLEAN` 계열이 담당 |
| `AUD_AMB_M1_MIRROR_GALLERY` | `M1_MIRROR_GALLERY`; C0·C1·C4·CF·C5·C5_INFO, EDGAR_S2·MARA1_S2 | 거울 회랑 진입 | 대응접실 이동 또는 CSHORT 몽타주 종료 | C0 지연 반사, C4 실패 경화층, C5 릴레이 노출, S3 시설 변형. 지연 감소 설정에서는 반복 지연 대신 건조한 단일 반사 사용 |
| `AUD_AMB_M1_DINING_ROOM` | `M1_DINING_ROOM`; E5 저녁·EDS_DINING_ROOM·EDS_TABLE_OBJECTS | 식당 진입 또는 E5 식탁 장면 전환 | 중앙홀·주방 이동 또는 잔류 마지막 화면 종료 | S0, E5 LOW/MID/HIGH/ALL, S5. 관계 단계는 인간적 재질 수만 바꾸고 전체 음량·화성의 보상성은 고정 |
| `AUD_AMB_M1_LIBRARY_OUTER` | `M1_LIBRARY_OUTER`; P3·B3-A 조사·BSHORT 서재 경유 | 외부 서고 진입 | 중앙홀·기록 내실·대시계 이동 시 정지 | S0/S1/B3-A/S2. B3-A 조작 중 종이 전경을 위해 베드 중역을 낮춤. 기록 내실 경계 시계는 포함하지 않음 |
| `AUD_AMB_M1_LIBRARY_INNER` | `M1_LIBRARY_INNER`; B2·B2_EDGAR_ENTRY/HIDE/CAUGHT·J1·B5·J2·J3·D0·D0-A·J4 | 기록 내실 진입 | 외부 서고/기록 회랑 이탈 시 정지 | B2 경계도 3단으로 문밖 발소리 거리를 조절하되 실패 판정 없음. 일지 복원 중 종이층 duck, S3에서 냉각기층 노출 |
| `AUD_AMB_M1_NORTH_ARCHIVE_HALL` | `M1_NORTH_ARCHIVE_HALL`; P3B·MARA2_FU·북쪽 이동 허브 | 기록 회랑 진입 | 연결 공간 진입 시 정지 | P3B/S1/S2/S3. 3음 서명 본체는 `AUD_SIG_MARA2`; 앰비언스에는 잔향 자리만 남김 |
| `AUD_AMB_M1_PORTRAIT_STORAGE` | `M1_PORTRAIT_STORAGE`; P3B 후속 조사·MARA2_S1 | 초상화 보관실 진입 | 기록 회랑 복귀 시 정지 | 정상/이중 윤곽/손상 사본 변형. 초상화가 말하는 음성이나 필수 정답음은 넣지 않음 |
| `AUD_AMB_M1_COLOR_ROOM_ENTRY` | `M1_COLOR_ROOM_ENTRY`; C5 이후 조사·MARA2_S2·E3_5 진입 전 | 색분해실 외부 장면 진입 | 기록 회랑 또는 `H0_COLOR_SEPARATION` 이동 시 정지 | C5 이전에는 장치를 숨기고, 이후 채널층 노출, S3에서 벽의 음향 외피 제거 |
| `AUD_AMB_M1_WEST_HALL` | `M1_WEST_HALL`; B3·D구간·E3_4 이동 | 서쪽 복도 진입 | 중앙홀·대시계·지하 입구 진입 시 정지 | S0~S3. 대시계 접근감을 제공하지만 B3 정답 박자를 전달하지 않음. 저주파 감소판 제공 |
| `AUD_AMB_M1_GREAT_CLOCK` | `M1_GREAT_CLOCK`; B3-B·BF·B4·E3_4 진입 | 대시계실 진입 | 서쪽 복도/시설 시계실 이동 시 정지 | 정상/당일 잠금/리셋 복원/성공/S3. `COMMIT` 중 -3dB duck. 열세 번째 종은 `SFX_CLOCK_BELL_13`만 담당 |
| `AUD_AMB_M1_BASEMENT_ENTRY` | `M1_BASEMENT_ENTRY`; D1·DF·D2 | 지하 계단문 조사 장면 진입 | 서쪽 복도 또는 지하 계단 진입 시 정지 | 잠김/D1 실패/해금 변형. 실패 충격을 반복하지 않고 고정된 압력만 유지 |
| `AUD_AMB_M1_EAST_HALL` | `M1_EAST_HALL`; P4·P5·C2-1·E3_2·E3_3 이동 | 동쪽 복도 진입 | 중앙홀·주방·온실 앞 진입 시 정지 | S0~S3. 양쪽 공간의 방향 단서는 제공하되 방향음만으로 선택을 요구하지 않음 |
| `AUD_AMB_M1_KITCHEN` | `M1_KITCHEN`; P4·C2-1·C3·LUCA_S1/S2·E3_3 출발 | 주방 진입 | 식당·동쪽 복도·시설 생명 유지실 이동 시 정지 | P4/C3/S2/S3. 끓임·붓기·식기는 별도 폴리. P4 생체 전조는 `AUD_SIG_LUCA`가 담당 |
| `AUD_AMB_M1_GREENHOUSE_VESTIBULE` | `M1_GREENHOUSE_VESTIBULE`; P5·IRIS_S1·E3_2 이동 | 온실 앞 진입 | 동쪽 복도 또는 온실 진입 시 정지 | 잠김/날씨 모순/S3. 두 날씨층은 동등한 음량으로 분리하고 필수 정보는 시각 표지 병행 |
| `AUD_AMB_M1_GREENHOUSE` | `M1_GREENHOUSE`; IRIS_S2·E3_2 전반부 | 온실 진입 | 온실 앞 또는 `H0_CLIMATE_CONTROL` 이동 시 정지 | 인공 계절 2층/S2/교정/S3. 센서 고역 감소판에서도 교정 상태를 화면으로 확인 가능 |
| `AUD_AMB_M1_SERVICE_HALL` | `M1_SERVICE_HALL`; B1 시간표 조사·MARA1_S1·E3_1 출발 | 사용인 정비 복도 진입 | 공용실·도구실·주방·중앙홀 이동 시 정지 | S0 업무/S2 잔상/S3 시설. 발소리는 별도 거리 폴리로 호출 |
| `AUD_AMB_M1_SERVANT_COMMON` | `M1_SERVANT_COMMON`; 사용인 짧은 반응·관계 후속 조사 | 공용실 진입 | 정비 복도 이동 시 정지 | 완료 관계의 서명 재질을 낮은 거리층으로 삽입. 미완료 인물도 소실하지 않고 거리·잡음으로 유지 |
| `AUD_AMB_M1_TOOL_ROOM` | `M1_TOOL_ROOM`; C2 코팅 조사·도구 회수, E3_1 이동 | 청소도구실 진입 | 정비 복도 또는 배선실 이동 시 정지 | 회수 전/후/리셋 복원. 회수한 도구의 잔향만 제거하고 다른 물건은 유지 |
| `AUD_AMB_M1_WIRING_ROOM` | `M1_WIRING_ROOM`; E3_1 마라 1 배선 수리 | 배선실 진입 | 도구실/시설 척추 이동 시 정지 | 잠김/손상/수리 변형. 수리 선택 결과는 기능을 바꾸되 축하 음악을 추가하지 않음 |
| `AUD_AMB_B1_BASEMENT_STAIR` | `B1_BASEMENT_STAIR`; D2 첫 진입·DSHORT | 지하 계단문 해금 뒤 계단 장면 진입 | 지하 입구 또는 축실 진입 시 정지 | 첫 진입/DSHORT/S3. 위층 생활음이 사라지는 방향을 전달하되 정답 단서 아님 |
| `AUD_AMB_B1_AXIS_CHAMBER` | `B1_AXIS_CHAMBER`; D1·DF·D2 | 세 축 장치실 진입 | 지하 계단/창고 이동 시 정지 | 기본/확정 실패/리셋/성공. 압력 대기는 `AUD_PUZ_D1.PRESSURE_WAIT_LOOP`와 중복되지 않게 베드 또는 퍼즐층 중 하나만 전경화 |
| `AUD_AMB_B1_STORAGE` | `B1_STORAGE`; D2 이후 지하창고 조사·D4 이동 | 지하창고 진입 | 축실 또는 태엽 심장실 진입 시 정지 | 잠김 실루엣/개방/S3. 서류 획득음은 `SFX_ITEM_PICKUP` |
| `AUD_AMB_B1_CLOCKWORK_HEART` | `B1_CLOCKWORK_HEART`; D4·D5·D6 | 태엽 심장실 진입 | D5 데모 종료 또는 시설 척추/수면 전환 시 정지 | D4 입력/D5 직전/외피 박리. 심박 감소 시 생체 유사 압력을 비주기 공기·기어층으로 대체 |

### 3.2 시설·현실 12종

| 부모 ID | 사용 장소·이벤트 | 시작 조건 | 종료·전환 | 사용 방식 |
| --- | --- | --- | --- | --- |
| `AUD_AMB_H0_SERVICE_SPINE` | `H0_SERVICE_SPINE`; D5 이후 D6·E2_INTRO·E_HUB 이동 | 시설 척추가 최초 노출되거나 진입할 때 | 각 기능실·저택 투영 공간 이동 시 정지 | BROKEN_RESET 직후/허브 안정화 후 변형. 저택 목재 잔향을 지워 버리지 않고 원형 공간임을 연결 |
| `AUD_AMB_H0_CLOCK_MACHINE` | `H0_CLOCK_MACHINE`; E3_4·E3_4M·E6 | 보안 기계실 진입 | 시설 척추 또는 코어 접근로 이동 시 정지 | 손상/E3_4 선택/E3_4M 최소 복구/복원. 권한 반환을 성공 팡파르로 평가하지 않음 |
| `AUD_AMB_H0_LIFE_SUPPORT` | `H0_LIFE_SUPPORT`; E3_3 | 루카 경로에서 생명 유지실 진입 | 시설 척추 또는 주방 투영 공간 이동 시 정지 | 누출/우회/안정화. 심박 감소판은 steady air로 대체하고 결과 정보 유지 |
| `AUD_AMB_H0_CLIMATE_CONTROL` | `H0_CLIMATE_CONTROL`; E3_2 | 이리스 경로에서 기후 제어실 진입 | 시설 척추 또는 온실 이동 시 정지 | 손상과 outcome 2종. 두 선택을 선악·밝기·음량으로 평가하지 않음 |
| `AUD_AMB_H0_COLOR_SEPARATION` | `H0_COLOR_SEPARATION`; E3_5 전반부 | 색분해실 문이 열리고 조작 공간 진입 | 인격 아카이브 또는 기록 회랑 이동 시 정지 | 잠김/접근/E3_5. 다섯 채널은 비트 없는 분리층이며 실제 인격 표본은 각 `AUD_SIG_*` 사용 |
| `AUD_AMB_H0_PERSONALITY_ARCHIVE` | `H0_PERSONALITY_ARCHIVE`; E3_5 후반부 | 원본·손상 사본 대조 공간 진입 | 색분해실/시설 척추 이동 시 정지 | 익명/마라2 복원/병합/분리. 병합과 분리를 같은 음량·길이로 취급 |
| `AUD_AMB_H0_CORE_PATH` | `H0_CORE_PATH`; F0-A~F0-E | E6 뒤 코어 접근로 진입 | 코어 기록실 진입 시 정지 | 단계별 공간 조각 스템을 연결. 퍼즐 입력 중 해당 `AUD_PUZ_F0_*` 전경을 위해 duck |
| `AUD_AMB_H0_CORE_RECORDS` | `H0_CORE_RECORDS`; F1·J5 | F0-E 완료 뒤 기록실 진입 | 코어실 이동 시 정지 | F1 구간별 duck, J5 작성 여백. 아버지 기록을 음성으로 자동 낭독하지 않음 |
| `AUD_AMB_H0_CORE_CHAMBER` | `H0_CORE_CHAMBER`; F2·F3·EDC | 코어실 진입 | 현실 연결 해제 또는 잔류 안정화 시작 시 정지/전환 | 두 선택 장치를 동등한 체감으로 유지. EDC에서 선택 방향을 소리 위치·음량으로 유도하지 않음 |
| `AUD_AMB_R0_CRYO_CHAMBER` | `R0_CRYO_CHAMBER`; EDR_WAKE_BODY·BODY_CHECK·FIELD_NOTEBOOK | EDR_WAKE의 현실 공기가 정착하고 냉각실 장면 활성화 | 시설 출구 이동 시 정지 | 기상/신체 확인/출구 전. 호흡은 사건층이며 베드 반복에 고정하지 않음; 호흡 감소판 제공 |
| `AUD_AMB_R0_FACILITY_EXIT` | `R0_FACILITY_EXIT`; EDR_EXIT_PANEL·FREE_LOOK·AIRLOCK_CONFIRM | 냉각실에서 출구 구역 진입 | 냉각실 복귀 또는 지표 경계 이동 시 정지 | 패널 확인/에어록 준비/개방 변형. 출구 해제를 승리음으로 표현하지 않음 |
| `AUD_AMB_R0_SURFACE_THRESHOLD` | `R0_SURFACE_THRESHOLD`; EDR_SURFACE_THRESHOLD·DISTANT_SIGNAL·FINAL_FRAME | 에어록이 열리고 지표 경계 장면 진입 | 크레딧 진입 시 페이드아웃 | 문턱/먼 신호/최종 프레임. 불확실한 신호는 별도 1회층이며 생존자 존재를 확정하지 않음 |

## 4. BGM 10종

| 부모 ID | 사용 구간·이벤트 | 시작 조건 | 종료·전환 | 사용 방식 |
| --- | --- | --- | --- | --- |
| `BGM_TITLE` | 타이틀 화면·타이틀 복귀 | 앱 기동 후 타이틀 준비 또는 게임에서 타이틀 복귀 | 새 게임/불러오기 확정 시 페이드아웃 | intro→loop. 세이브 유무로 편곡을 바꾸지 않음. 현재 코드 호출 있음, 실제 리소스는 미등록 |
| `BGM_S0_ROUTINE` | P1~P6, 첫 일상과 정상 아침의 S0 구간 | 새 게임 P1 또는 정상 루프의 일상 시작 | 첫 리셋 비교에서 S1로 크로스페이드; 수면 중 duck | 반복 루프에서는 장식 스템 1개 감소. 일과 완료·관계값을 보상음으로 표현하지 않음 |
| `BGM_S1_SUSPICION` | A1·A2·B1·B2·J1·B3·J2, BSHORT | 수첩 지속성 의심이 활성화되는 A구간 진입 | J2 이후 C0에서 S2로 크로스페이드 | 주제/어긋남/저역 3스템. `alert` 상승은 거리·밀도만 바꾸고 정답 정보량은 동일 |
| `BGM_S2_LEAK` | C0~D4; C3·C4·C5·D0-A·D1·D4 | C0에서 검은 거울 조사 시작 | D5 전환 시 `BGM_D5_BREAK`로 교체 | C0 전조, C5 채널층 추가. 퍼즐 집중 중 중역 duck; 기계층을 악으로 판정하지 않음 |
| `BGM_D5_BREAK` | D5 위장 필터 해제 | D4 `XIII_START` 뒤 D5 원자 전환이 시작될 때 | 데모는 `demo_stinger` 뒤 종료, 본편은 `full_transition` 뒤 D6로 인계 | 35초 도입→20초 hold 반복. `AUD_EVT_D5_FILTER_BREAK`의 재질 전환과 동기화하되 충격을 중복하지 않음 |
| `BGM_S3_FRACTURE` | D6·BROKEN_RESET 이후 E1~E6; E5 | 깨진 리셋 뒤 S3 세계가 생성될 때 | E6에서 코어 접근로 진입 시 S4로 교체 | 수리 완료마다 끊긴 주제 조각 1개 정렬. E5 LOW/MID/HIGH/ALL은 악기 수·사람 흔적만 변화하고 평가성 종지 금지 |
| `BGM_S4_CORE` | F0-A~F0-E·F1·J5·F2·F3·EDC | `H0_CORE_PATH` 진입 | EDC 원자 커밋 뒤 현실은 R0, 잔류는 S5로 전환 | F0 단계 동기 마커, F1/J5 중 얇게 duck. F0-E reality/stay/undecided는 같은 조성·길이·체감 음량 |
| `BGM_S5_STAY` | EDS_ENTRY 이후 EDS_STABILIZE·헌장·중앙홀·식당·FINAL_FRAME | 잔류 선택 커밋 뒤 S5 안정화가 시작될 때 | `CREDITS_STAY` 시작 시 크로스페이드 | 반복. 생활 재질과 합성 공기층 공존. 거짓을 안다는 사실을 벌점이나 완전한 안락 종지로 만들지 않음 |
| `BGM_R0_REALITY` | EDR_WAKE 이후 냉각실·시설 출구·지표 경계 | 기상 직후 6~10초 무음이 끝났을 때 | `CREDITS_REALITY` 시작 시 페이드아웃 | 반복. 몸의 무게와 불확실성을 유지하며 탈출 승리음·절망 장송곡 금지 |
| `BGM_CREDITS` | CREDITS_REALITY·CREDITS_STAY | `ENDING_META_COMMIT` 완료 뒤 선택한 크레딧 컨테이너 진입 | 곡 완료 또는 사용자의 스킵/메뉴 이동 | 두 엔딩은 첫 12초 스템만 다르고 공통 본곡에 합류. 재관람은 저장된 재개·스킵 정책 적용 |

## 5. 인격 서명음 6종

서명음은 `SFX` 채널의 짧은 비언어 one-shot이다. 대사 음성·호감도 상승음이 아니며, 인물 데이터가 **노출되거나 권한을 행사하는 순간**에만 재생한다. 같은 문장 재표시·같은 프레임의 반복 클릭은 쿨다운과 사건 플래그로 중복 호출하지 않는다.

| 부모 ID | 사용 장소·이벤트 | 호출 조건 | 변형·역할 |
| --- | --- | --- | --- |
| `AUD_SIG_EDGAR` | P1 소개 보조, EDGAR_S1, B2 접근/에드가 진입, E3_4·E3_4M, EDGAR_S3, F2·엔딩 권한 반응 | 에드가의 잠금·정렬·운영 권한이 화면 문양과 함께 처음 드러날 때 | S1 기억 누수/B2 접근/S3 포트/권한 반환. 일반 대사마다 재생하지 않으며 250ms cooldown |
| `AUD_SIG_MARA1` | P2 소개 보조, MARA1_S1/S2, E3_1, 엔딩 정비 반응 | 마라 1의 정비 식별자나 배선 소유권이 활성화될 때 | S1 반응/S2 배선/E3_1 손상·복원. 공구 충격 SFX와 같은 프레임에 겹쳐 과장하지 않음; 200ms cooldown |
| `AUD_SIG_LUCA` | P4 생명 유지 전조, LUCA_S1/S2, E3_3, 엔딩 호흡·위험 정보 반응 | P4의 첫 감각 문장 또는 루카의 생명 유지 권한이 처음 제시될 때 | S1 차/S2 배관/E3_3 안정화. 반복 감소에서는 단일 압력+공기로 대체. 현재 P4 호출 코드 있음, 실제 리소스 미등록 |
| `AUD_SIG_IRIS` | P4_IRIS_GREETING 보조, P5·IRIS_S1/S2, E3_2, F2 고백 변형, 엔딩 반응 | 이리스의 기후·보호 기억 출처가 감각 문양과 함께 식별될 때 | S1 날씨/S2 센서/E3_2 두 outcome/고백·비고백. 고백을 자동 재생 조건으로 삼지 않고 관계 판정 결과에 맞춤 |
| `AUD_SIG_MARA2` | P3B, MARA2_S1/S2, E3_5, MARA2_FU, F0-D, 엔딩 이름·보존 반응 | 이름·액자·체크섬·아카이브 인덱스가 마라 2 소유임을 제시할 때 | S1 이름/S2 결손/E3_5 병합·분리/FU. 익명 대체 경로에서는 정체를 선공개하지 않음; 300ms cooldown |
| `AUD_SIG_SUBJECT` | A1·A2, J1~J5 결합 확인, C5 SUBJECT_TRACE, F0-E·EDC, EDS_TABLE_OBJECTS | 주인공이 다른 인격의 권한이 아닌 자기 기록·선택을 직접 작성할 때 | 흑연 3변형 순환. `SFX_NOTEBOOK_WRITE`와 겹치면 서명은 끝 압흔층만 사용; 엔딩 방향별 승패 변화 없음 |

## 6. 퍼즐 cue pack 14종

부모 ID는 퍼즐 컨테이너를 선택하고, 실제 재생은 아래 `cue_part_id`가 담당한다. `LOCAL RETRY`는 현재 보드에서 계속 조작할 수 있으며 영구 상태를 지우지 않는다. `HARD FAILURE`는 당일 물리 상태가 잠기므로 단발 결과 뒤 해당 공간의 실패 앰비언스로 전환한다.

| 부모 ID | 사용 이벤트·장소 | 진입·종료 | 사용 방식 |
| --- | --- | --- | --- |
| `AUD_PUZ_B3_A` | B3-A; 외부 서고 중계 시계 `OBJ_LIBRARY_OUTER_CLOCK` 확대·탁본 조립 | B3-A 패널 활성 시 active loop 시작; 해결·패널 종료 시 정지 | 탁본 회전·반전·연결 검증. `OBJ_LIBRARY_RECORD_CLOCK`에는 연결 금지 |
| `AUD_PUZ_B3_B` | B3-B·BF·BSHORT 재도전; `M1_GREAT_CLOCK` | 역할·위상 패널 활성 시 loop; 성공 또는 HARD FAILURE에서 종료 | 첫 실패는 핀 휨·당일 잠금, 다음 루프 BSHORT는 검증 역할만 유지하고 위상 재입력 |
| `AUD_PUZ_C3` | C3; `M1_KITCHEN` 세정제 조합 | 두 조사 정보 확보 뒤 조합대 진입; 용액 완성·취소 시 종료 | 계량·붓기·혼합·시험. 오답은 현장 폐기 후 로컬 재시도, 세계 리셋 불필요 |
| `AUD_PUZ_C4` | C4·CF·CSHORT; `M1_MIRROR_GALLERY` | 젖은 청소 확정 전 패널 활성; 성공/코팅 경화 뒤 종료 | 천 이동·파형 정렬·젖은 확정. HARD FAILURE는 당일 코팅 경화 후 정상 리셋 요구 |
| `AUD_PUZ_C5` | C5·C5_INFO; 검은 거울 진단 패널 | C4 성공의 진단면 노출 직후 | 다섯 채널 스캔·겹침·SUBJECT 추적·기록. 채널 원재료는 5인 서명에서 공급 |
| `AUD_PUZ_D0_A` | D0-A; `M1_LIBRARY_INNER` 도면·투명지 중첩 | D0 단서 재확인 뒤 확대 패널 진입; 해결 시 D1로 인계 | 지도·도면 회전/반전/고정. 오답은 로컬 재시도이며 종이 상태를 리셋하지 않음 |
| `AUD_PUZ_D1` | D1·DF·DSHORT; `B1_AXIS_CHAMBER` | 세 축 패널 진입; 성공 또는 HARD FAILURE에서 종료 | 축 깊이·압력·검토·실행. 실패는 압력핀 고정과 당일 잠금, 다음 루프 검증 축 유지 |
| `AUD_PUZ_D4` | D4; `B1_CLOCKWORK_HEART` | 태엽 심장 조작 진입; XIII 기동 뒤 D5에 인계 | XII와 +1을 결합. 조립 오답은 로컬 재시도, 성공은 실패가 아닌 필터 해제 트리거 |
| `AUD_PUZ_E3_5` | E3_5; `H0_COLOR_SEPARATION`→`H0_PERSONALITY_ARCHIVE` | 마라 2 관계 경로 선택 뒤 채널 패널 활성; 병합/분리 결산 뒤 종료 | 원본·사본·결손·체크섬 비교. 병합·분리는 모두 성공이며 음량·길이로 평가하지 않음 |
| `AUD_PUZ_F0_A` | F0-A; `H0_CORE_PATH` | 코어 접근로 첫 단계 진입; 회로 해결 뒤 F0-B | 이전 방 피드백 타일 연결. 완성 회로만 짧은 유지 loop, 충돌은 로컬 재시도 |
| `AUD_PUZ_F0_B` | F0-B; `H0_CORE_PATH` | F0-A 완료 뒤 표본 분류 패널 활성; 해결 뒤 F0-C | 물리·기억·생체 표본 재생/분류. 표본별 시각 파형을 병행하고 심박 감소판도 같은 범주 유지 |
| `AUD_PUZ_F0_C` | F0-C; `H0_CORE_PATH` | F0-B 완료 뒤 B4·C5·D4 자료 중첩 패널 활성 | 세 자료를 중첩해 모순과 코어 경로 출력. 해결 뒤 F0-D, 오답은 현장 유지 |
| `AUD_PUZ_F0_D` | F0-D·F0-D-ANON; `H0_CORE_PATH` | F0-C 완료 뒤 기록 출처 분류 시작 | 출처·행동·의도를 분리. REC_MARA2가 없으면 익명 인덱스를 써도 해결 가능하며 서명을 선공개하지 않음 |
| `AUD_PUZ_F0_E` | F0-E; `H0_CORE_PATH` | F0-D 완료 뒤 과거·현재 이중 인증 시작; SUBJECT 권한 복원 뒤 종료 | 외부 권한은 거부하고 수정 가능. reality/stay/undecided 세 의향은 모두 성공·비구속이며 EDC 결정을 잠그지 않음 |

### 6.1 하위 cue 호출 기준

| 부모 | `cue_part_id` → 호출 행동 |
| --- | --- |
| B3-A | `PICK` 조각 선택; `ROTATE` 90도 회전; `FLIP` 외부 서고 탁본 앞/뒤; `EDGE_VALID` 맞은 경계; `EDGE_INVALID` 끊긴 경계; `LOCAL_RETRY` 검증 뒤 계속; `SOLVED` 전체 배선 추적 성공; `ACTIVE_LOOP` 패널 조작 중 |
| B3-B | `ROLE_PLACE` 역할 슬롯 배치; `PHASE_SHIFT` 위상 변경; `EXCLUDE_SET` 제외 슬롯 지정; `REVIEW_OPEN` 실행 전 요약; `COMMIT` 실제 작동 확정; `HARD_FAILURE` 핀 휨 결과; `SHORTCUT_READY` 다음 루프 검증 역할 복구; `SUCCESS` 공명 전달; `ACTIVE_LOOP` 패널 활성 중 |
| C3 | `MEASURE` 계량; `POUR` 붓기; `MIX` 교반; `TEST_NEUTRAL` 중성 확인; `TEST_WRONG` 제약식 불일치; `DISCARD` 오답 용액 폐기; `SOLVED` 완성 용액 봉인 |
| C4 | `CLOTH_PASS` 거울 닦기; `OVERLAY_ADJUST` 파형 덧씌움 조정; `DRY_TEST` 마른 시험; `WET_COMMIT` 젖은 상태 확정; `COATING_WARN` 경화 직전; `HARD_FAILURE` 당일 코팅 경화; `REVEAL` 회로·진단면 노출 |
| C5 | `CHANNEL_SCAN` 한 채널 청취; `CHANNEL_LOCK` 채널 고정; `OVERLAP` 겹친 채널 비교; `SUBJECT_TRACE` 비사용인 흑연선 추적; `RECORD` 수첩 기록; `REVEAL` 다섯 채널 구조 공개 |
| D0-A | `LAYER_PICK` 자료 선택; `ROTATE` 회전; `FLIP` 투명지 반전; `ANCHOR` 기준핀 고정; `PARTIAL_MATCH` 일부 일치; `INVALID` 기준점 불일치; `SOLVED` 도면 변환 완료 |
| D1 | `AXIS_SELECT` 축 선택; `DEPTH` 깊이 변경; `PRESSURE_TEST` 약한 시험; `REVIEW` 실행 전 요약; `COMMIT` 실제 압력 적용; `HARD_FAILURE` 압력핀 변형; `UNLOCK` 지하 접근 해금; `PRESSURE_WAIT_LOOP` 압력 입력 대기 중 |
| D4 | `HANDLE` 손잡이 조작; `GEAR_PLACE` 기어 배치; `GEAR_TURN` 기어 회전; `XII_LOCK` 12단 잠금; `PLUS_ONE` 추가 기어 결합; `VALIDATE` 시험 공명; `XIII_START` 열세 번째 충격 기동; `SOLVED` D5 인계 상태 확정 |
| E3_5 | `SOURCE_AUDITION` 원본/사본 표본 청취; `CHANNEL_SPLIT` 겹침 분리; `NOTE_MISSING` 결손 표시; `CHECKSUM_MATCH` 일치; `CHECKSUM_FAIL` 불일치·재시도; `MERGE` 병합 선택; `SEPARATE` 분리 선택; `SOLVED` REC_MARA2 기록 |
| F0-A | `TILE_PICK` 방 타일 선택; `ROTATE` 회전; `SWAP` 자리 교환; `SIGNAL_PASS` 연결 통과; `FEEDBACK_CONFLICT` 되먹임 충돌; `VALIDATE` 회로 시험; `SOLVED` 단계 완료; `COMPLETE_CIRCUIT_LOOP` 완성 회로 유지 중 |
| F0-B | `SIGNAL_PLAY` 표본 1개 재생; `CLASSIFY` 범주 배치; `COMPARE` 두 표본 순차 비교; `MISCLASSIFY` 오분류 복귀; `CONFIRM` 검토 확정; `SOLVED` 세 범주 검증 완료 |
| F0-C | `LAYER_PICK` 자료 선택; `OVERLAY` 중첩; `FLIP` 반전; `ANCHOR` 기준점 고정; `CONTRADICTION` 모순 노출; `PATH_OUTPUT` 코어 경로 출력; `SOLVED` 단계 완료 |
| F0-D | `SOURCE_PICK` 기록 출처 선택; `ACTION_CLASSIFY` 행동 분류; `INTENT_CLASSIFY` 의도 분류; `ROLE_PLACE` 역할 복원; `ANON_INDEX` 마라2 미완료 대체; `INVALID` 조합 복귀; `SOLVED` 단계 완료 |
| F0-E | `PAST_AUTH` 과거 권한 확인; `SUBJECT_WRITE` 현재 문장 작성; `INTENT_REALITY` 현실 의향; `INTENT_STAY` 잔류 의향; `INTENT_UNDECIDED` 미정 의향; `AUTHORITY_REJECT` 타인 권한 입력 거부; `REVISE` 문장 수정; `SOLVED` SUBJECT 권한 복원 |

## 7. 주요 전환 cue pack 8종

| 부모 ID | 사용 이벤트·장소 | 호출 순서·종료 | 사용 방식 |
| --- | --- | --- | --- |
| `AUD_EVT_NORMAL_RESET` | P6 이후 및 D5 이전 모든 `NORMAL_SLEEP`→SYS_COMMIT→SYS_MEMORY→NORMAL_RESET→MORNING | `SLEEP` 수면 감각→`COMMIT` 영구 정보 보존 확인→`CUT` 물리 세계 단절→`MORNING` 같은 침실 접속. ROUTE 시작 전에 종료 | 첫 회 12~18초, 반복 3~5초. 물체 역재생 금지. 단계층 `SFX_NORMAL_RESET_SLEEP/COMMIT`와 순간을 나누며 중복 재생 금지 |
| `AUD_EVT_D5_FILTER_BREAK` | D5; `B1_CLOCKWORK_HEART` | D4 `XIII_START` 이후 기어 상승→외피 박리→시설 공명→5인 서명 분리. 데모/본편 tail에서 종료 | 실패음이 아닌 위장 필터 해제. `BGM_D5_BREAK`와 시간축을 공유하고 demo sting/full tail 분리 |
| `AUD_EVT_BROKEN_RESET` | FRACTURE_SLEEP→BROKEN_RESET; 침실/시설 투영 전환 | D6의 수면 선택 뒤 정상 복구 시도에서 1회 시작, E1의 다른 아침 room tone 정착 후 종료 | 정상 리셋 모티프의 끊김·이중 방·고정구 노출. 이후 POST_BROKEN_REST에는 재사용하지 않음 |
| `AUD_EVT_JOURNAL_RESTORE` | J1·J2·J3·J4·J5 | 각 일지 단계의 영구 트랜잭션이 성공한 뒤 stage 1~5 변형을 1회 재생 | 전체 3~7초 연출. 페이지 결합 순간의 `SFX_JOURNAL_RESTORE`는 내부 한 지점에만 얹고 두 번 울리지 않음 |
| `AUD_EVT_E_HUB_STABILIZE` | BROKEN_RESET 이후 E2_INTRO→E_HUB | 중앙홀에서 다섯 기능 경로가 처음 식별될 때 시작, 허브 선택 입력을 받기 전 종료 | 완료 인원에 따라 인물층의 명료도만 반영. E3 진행을 차단하거나 미완료 인물을 무음 처리하지 않음 |
| `AUD_EVT_F0_CORE_PATH` | E6→F0-A; `H0_CORE_PATH` | 코어 접근문이 열린 뒤 방 조각이 연결되기 시작할 때, F0-A 조작 가능 상태가 되면 종료 | 10~18초 단발. 공간 앰비언스 조각과 종이 기준점을 재접속하며 모션 감소 화면에서도 같은 사건 타이밍 유지 |
| `AUD_EVT_EDR_WAKE` | EDR_DISCONNECT→EDR_WAKE_BODY; `R0_CRYO_CHAMBER` | 시뮬레이션 접속 해제 뒤 첫 호흡·벨트·금속·현실 환기 순서, 냉각실 자유 입력 전에 종료 | 첫 호흡은 자동 성공. 호흡 감소판은 천·공기로 대체. BGM_R0_REALITY는 6~10초 무음 뒤 별도 진입 |
| `AUD_EVT_EDS_TABLEAU` | EDS_DINING_ROOM→EDS_TABLE_OBJECTS→EDS_FINAL_FRAME | 잔류 식탁 구도 정착 때 시계·차·식기·5인 서명을 배치하고 S5 공간음/BGM으로 크로스페이드 | 12~20초 단발. 관계 완료는 거리·응답만 바꾸며 인물을 지우거나 보상 화음을 추가하지 않음 |

## 8. 공통 SFX 20종

| 부모 ID | 사용 장소·이벤트 | 정확한 호출 조건 | 중복·종료 규칙 |
| --- | --- | --- | --- |
| `SFX_NORMAL_RESET_SLEEP` | P6·AS·BS·CS·D3 등 D5 이전 수면, `NORMAL_SLEEP` | 플레이어가 `잠든다`를 최종 확정하고 현재 이벤트 종료 검증을 통과할 때 | 첫/반복 변형. `AUD_EVT_NORMAL_RESET.SLEEP`의 단계층이며 별도 수면음 2개를 겹치지 않음 |
| `SFX_NORMAL_RESET_COMMIT` | SYS_COMMIT | 지식·관계·색상 영구 트랜잭션 쓰기가 성공하고 SYS_MEMORY로 넘어갈 때 1회 | 실패·재시도 중 재생 금지. 디스크 저장 `SFX_SAVE_COMPLETE`와 음색·문양 분리 |
| `SFX_CLOCK_BELL_13` | B3-B 성공·B4 파형 획득; `M1_GREAT_CLOCK` | 역할·위상 실행이 성공 판정된 뒤 12회+구조가 다른 13번째 타격 타임라인 실행 | 핵심 공명 중 BGM 약 2dB duck. 타격 수는 단발 원재료 배열로 보장, 앰비언스에 굽지 않음 |
| `SFX_CLOCK_NETWORK_LOCK` | B3-B HARD FAILURE→BF | 봉인핀 변형 cue 뒤 시계망 당일 잠금 트랜잭션이 확정될 때 | `AUD_PUZ_B3_B.HARD_FAILURE`의 충격과 시간차를 두고 순차 핀 잠금만 담당. 다음 정상 리셋까지 1회 |
| `SFX_MIRROR_CLEAN` | P2 창문 청소 보조·C4 거울 닦기 | 천이 실제 유리 표면을 한 번 통과할 때 | 마른/젖은·압력 4변형, 120ms cooldown. C4 판정음은 퍼즐 pack이 담당 |
| `SFX_MIRROR_REVEAL` | C4 성공→C5 | 젖은 확정이 성공하고 회로·진단면의 표면 노출 애니메이션이 시작될 때 | `AUD_PUZ_C4.REVEAL`이 본체면 이 SFX는 얇은 유리/릴레이 공통층만 사용. C5 재진입 때 반복 금지 |
| `SFX_JOURNAL_RESTORE` | J1~J5 | 문장/페이지 한 단위가 영구 복원 트랜잭션에 결합되는 정확한 순간 | 3변형 순환. 전체 전환은 `AUD_EVT_JOURNAL_RESTORE`; 단계마다 1회만 사용 |
| `SFX_NOTEBOOK_WRITE` | A1·A2 비교 기록·BF/CF/DF 실패 기록·B4/C5·J 확인·F0-E·EDS_TABLE_OBJECTS | 화면에 의미 있는 획/문장이 실제 확정될 때 | 5변형, 80ms cooldown. 글자마다 재생하지 않음. SUBJECT 서명과 겹치면 필기 본체만 담당 |
| `SFX_SHORTCUT_CONFIRM` | AS·BSHORT·CSHORT·DSHORT | 이미 검증한 준비·이동 범위를 축약하겠다는 선택을 확정할 때 | 축약 진입당 1회. 퍼즐 성공·문 해금음으로 재사용하지 않음 |
| `SFX_HARD_FAILURE_COMMIT` | B3-B·C4·D1 HARD FAILURE | 비가역 물리 변형이 당일 상태에 원자 확정되는 프레임 | 각 퍼즐의 실패 본체 위 공통 커밋층. 경고·무효 입력과 구분하고 정상 리셋 전 중복 금지 |
| `SFX_DOOR_LOCK` | 기록 내실 문·지하 계단문·기능실·에어록 등 잠금 상태 변화 | 열려 있던/미확정 문이 실제 `locked` 상태로 전환되거나 잠금 재확인 애니메이션이 실행될 때 | 목재/금속/시설 자석 변형. 단순 비활성 UI에는 재생하지 않음. 문짝 폴리와 걸쇠 순간만 정렬 |
| `SFX_DOOR_UNLOCK` | J1 내실 연결문·D2 지하 숏컷·C5 이후 색분해실 접근·E6 코어 접근·EDR 출구 | 접근 조건 트랜잭션이 성공하고 문/걸쇠 상태가 실제 열린 경로로 바뀔 때 | 걸쇠/압력/시설 relay 변형. `SFX_SHORTCUT_CONFIRM`과 같은 의미로 겹치지 않음 |
| `SFX_ITEM_PICKUP` | C2 도구·C2-1 재료·B4 파형 기록물·C5 투명지·문서·카드·현실 수첩 등 | 월드 오브젝트가 인벤토리/영구 정보 소유로 확정될 때 | 종이/유리/금속/천/전자 카드, 100ms cooldown. 조사만 하고 획득하지 않으면 재생 금지 |
| `SFX_PUZZLE_VALIDATE` | B3-A/B, C3/C4/C5, D0-A/D1/D4, E3_5, F0-A~E | 플레이어가 `검증/시험`을 눌러 현재 조합의 유효 결과가 반환될 때 | 퍼즐 재질 본체 위 얇은 UI층. 최종 성공 전용음이 아니며 `SOLVED`와 중복 강조 금지 |
| `SFX_PUZZLE_REJECT` | 모든 로컬 재시도 퍼즐·비활성 조작 | 입력이 무효지만 카드·재료·영구 상태를 잃지 않고 원위치로 돌아갈 때 | 3회 이후 부드러운 변형. HARD FAILURE·잠금·경고음으로 사용 금지 |
| `SFX_UI_FOCUS` | 대화 선택·수첩·퍼즐·설정·EDC의 키보드/마우스 초점 | 조작 초점이 실제 다른 항목으로 이동할 때 | 60ms cooldown, 반복 감소 시 50% 생략. 포인터가 같은 대상 안에서 흔들릴 때 재호출 금지 |
| `SFX_UI_CONFIRM` | 일반 가역 선택·탭·확인 | 선택이 즉시 되돌릴 수 있는 UI 상태로 확정될 때 | 비가역 퍼즐 COMMIT·EDC 원자 커밋·디스크 저장에는 사용하지 않음 |
| `SFX_UI_CANCEL` | 뒤로·취소·EDC 최종 확인 취소·취침 취소 | 불이익 없이 이전 UI/조사 상태로 복귀가 완료될 때 | 실패음 없음. 화면이 닫힌 뒤 1회, 중첩 모달마다 연쇄 재생하지 않음 |
| `SFX_SAVE_START` | 일반 세이브, SAVE_F3_COMPLETE·SAVE_ENDING_BRANCH·SAVE_ENDING_NODE·SAVE_ENDING_COMPLETE | 저장 트랜잭션이 유효성 검사를 통과하고 디스크 쓰기를 시작할 때 | 한 트랜잭션당 1회. SYS_COMMIT의 기억 보존과 별개이며 실패 시 완료음 재생 금지 |
| `SFX_SAVE_COMPLETE` | 위 저장 지점·자동 저장 완료 | 원자 쓰기와 교체가 성공해 재개 가능한 저장점이 확정될 때 | 같은 트랜잭션 1회. 실패/롤백 시 재생하지 않으며 재시도는 새 transaction ID에만 허용 |

## 9. 공통 폴리의 사용처

폴리는 정본 부모 수를 늘리지 않고 기존 부모의 `cue_part_id`로 납품한다.

| 폴리 묶음 | 사용처 | 호출 방식 |
| --- | --- | --- |
| `FOL_FOOTSTEP_WOOD/CARPET/STONE/METAL` | 저택·지하·시설의 이동, B2 에드가 진입·퇴장 | 애니메이션 발 접지점마다 1회. 재질·거리 3단 선택; 앰비언스에 일정한 보행 패턴을 굽지 않음 |
| `FOL_DOOR_WOOD/GLASS/FACILITY/AIRLOCK` | 침실·서재·온실·지하·기능실·현실 출구 | 문짝·손잡이·걸쇠·수동 레버 애니메이션 마커별 호출. 잠금/해금 순간은 공통 SFX가 소유 |
| `FOL_PAPER/BOOK/GRAPHITE` | P3 책 정리, B2~J5 기록, 수첩, 도면·투명지 | 펼침·넘김·집기·필기 동작에 맞춤. 영구 복원 결과음과 일반 페이지 넘김을 구분 |
| `FOL_CLOTH/BRUSH/TOOL` | P2·C2·C4·E3_1·마라1 상호작용 | 손/도구가 실제 표면·부품에 접촉할 때. 정비 완료 판정은 퍼즐/관계 이벤트가 담당 |
| `FOL_GLASS/MIRROR` | P2 창문, C3 병, C4/C5 검은 거울, 온실 | 접촉 대상 재질을 표시. 깨짐이 없는 장면에 파손음 사용 금지 |
| `FOL_LIQUID/TABLEWARE` | P4 차, C3 혼합, 주방, E5·EDS 식탁 | 붓기·젓기·놓기 마커에 호출. 지속 끓임은 행동 중에만 loop하고 공간 베드에 고정하지 않음 |
| `FOL_FAN/RELAY/PUMP/GEAR/FIXTURE` | B1·H0 설비, E3 수리, F0 코어, 현실 시설 | 장치별 동작·수리 마커 또는 짧은 상태 loop. 저주파/심박 감소 시 동일 의미의 중역·공기 재질로 대체 |

## 10. 현재 런타임 연결 상태

2026-09-20 현재 승인된 실제 음원은 등록되지 않았다. 아래 9개는 레지스트리와 호출 자리가 존재하지만 전부 `PLANNED`, `resource_path=""`이므로 `GameAudio.request_cue()`가 실제 재생을 거부한다.

| ID | 현재 호출 위치 | 코드 상태 | 실제 재생 |
| --- | --- | --- | --- |
| `BGM_TITLE` | bootstrap 기동·타이틀 복귀 | 직접 요청 연결 | 없음: 리소스 미등록 |
| `AUD_SIG_LUCA` | P4 첫 생명 유지 감각 문장 | 문장별 `audio_cue` 요청, 중복 방지 테스트 있음 | 없음: 리소스 미등록 |
| `AUD_AMB_M2_BEDROOM` | 프롤로그 침실 진입 | `AUD_AMB_<room_id>` 동적 요청 | 없음: 리소스 미등록 |
| `AUD_AMB_M1_CENTRAL_HALL` | 프롤로그 중앙홀 진입 | 동적 요청 | 없음: 리소스 미등록 |
| `AUD_AMB_M1_PARLOR` | P2 대응접실 진입 | 동적 요청 | 없음: 리소스 미등록 |
| `AUD_AMB_M1_LIBRARY_OUTER` | P3 외부 서고 진입 | 동적 요청 | 없음: 리소스 미등록 |
| `AUD_AMB_M1_NORTH_ARCHIVE_HALL` | P3B 기록 회랑 진입 | 동적 요청 | 없음: 리소스 미등록 |
| `AUD_AMB_M1_KITCHEN` | P4 주방 진입 | 동적 요청 | 없음: 리소스 미등록 |
| `AUD_AMB_M1_GREENHOUSE_VESTIBULE` | P5 온실 앞 진입 | 동적 요청 | 없음: 리소스 미등록 |

나머지 88개 부모는 기획·의뢰·매니페스트에만 존재하며 런타임 레지스트리·장면 호출 연결이 아직 없다. 이 표는 제작 완료나 실제 청취를 뜻하지 않는다.

## 11. 구현 연결 순서

1. 승인된 파일을 접수하고 권리·길이·반복점·채널·감각 자막을 검수한다.
2. 부모 ID와 하위 cue/변형을 오디오 레지스트리에 등록한다. pack을 단일 파일 경로로 뭉치지 않는다.
3. 공간 진입은 `location_id`, 음악은 `world_phase`, 사건음은 이벤트 phase/트랜잭션 마커로 호출한다.
4. 단발 호출 전에 해당 이벤트 phase가 이미 완료됐는지 검사하고, 완료 저장과 다음 phase를 같은 원자 트랜잭션으로 확정한다.
5. 무음·음량 0·리소스 누락에서도 진행 플래그와 퍼즐 결과가 동일한지 확인한다.
6. Windows PC에서 저장·로드·스킵·포커스 이탈·메뉴 일시정지·28 voice 동시 발음을 실제 승인 음원으로 검수한다.

## 12. ID별 완료 조건

- 부모 97종이 이 문서에 정확히 한 번씩 사용처 정의를 가진다.
- 공간음 39종은 하나의 `location_id`와 진입·이탈 규칙을 가진다.
- 퍼즐 14종과 전환 8종은 부모뿐 아니라 모든 명시 하위 cue의 호출 행동이 정의된다.
- 공통 SFX 20종은 퍼즐/전환 본체와의 소유권 경계와 중복 방지 조건이 있다.
- 설계 사용처, 현재 코드 연결, 실제 승인 음원 재생 여부를 서로 다른 상태로 추적한다.

프로젝트 루트에서 `& 'docs/requests/audio/validate_usage_map.ps1'`를 실행하면 부모 97종, 퍼즐 하위 cue, 정상 리셋 단계와 현재 레지스트리 연결 9종의 문서 대응을 검사한다.
