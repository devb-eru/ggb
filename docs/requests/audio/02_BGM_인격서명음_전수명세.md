# GGB BGM·인격 서명음 전수 명세

## 1. 음악 공통 방향

음악은 플레이어의 선택을 평가하지 않고 현재 세계 단계와 감각 압박을 조절한다. 고딕 악기와 전자 음향의 비율은 S0에서 S4로 갈수록 뒤집히지만, “전자음=악, 어쿠스틱=선”이라는 가치 판단은 만들지 않는다.

| 항목 | 요구 |
| --- | --- |
| 용도 | 세계 단계·장면 정서·긴장 호흡 조절; 퍼즐 정답과 엔딩 가치 판정 금지 |
| 반복 여부 | 상태 BGM은 loop=true, 전환곡은 intro→hold loop→outro; 크레딧은 완결곡 |
| 악기·음색 | 실내악·피아노/하프시코드 계열·유리/금속 타악·가공 테이프·절제된 합성음; 과도한 공포 드론 금지 |
| 변형 | 동일 주제의 S0~S5·R0 변형, E5 LOW/MID/HIGH/ALL은 밀도만 변화 |
| 접근성 | 음악 자막은 곡 시작과 의미 있는 stem 변화 때만; 리듬이 필수인 경우 화면 pulse 병행 |

## 2. BGM 10종

| asset_id | 용도·느낌 | 길이 | 악기·음색 | 반복 여부·구조 | 주요 사용·변형 | sensory_caption_id |
| --- | --- | ---: | --- | --- | --- | --- |
| `BGM_TITLE` | 아름답지만 제목을 완전히 말하지 않는 고딕/SF 이중 인상 | 100초 | 준비 피아노, 비올라 저음, 유리 harmonics, 아주 얇은 tape noise | loop=true; 8초 intro, 76초 loop, 16초 tail | 타이틀·첫 실행; 세이브 유무로 orchestration 차이 없음 | `CAP_BGM_TITLE_START` |
| `BGM_S0_ROUTINE` | 일과의 정돈과 편안함, 미세하게 닫힌 호흡 | 160초 | 하프시코드 음색을 부드럽게 가공, 클라리넷 저음, 현악 pizzicato, 목재 타악 | loop=true; 명확한 cadence 없이 연결 | P1~P6·정상 아침; 반복 루프에서는 1 stem 감소 | `CAP_BGM_S0_ROUTINE` |
| `BGM_S1_SUSPICION` | 같은 패턴에 한 칸 늦는 소리가 끼어드는 의심 | 150초 | S0 악기, detuned 피아노 잔향, 비대칭 금속 click, 숨은 저역 pulse | loop=true; 3개 stem을 상태에 따라 교체 | A~B·서재 압박; alert가 높아도 정보량은 동일 | `CAP_BGM_S1_SUSPICION` |
| `BGM_S2_LEAK` | 고딕 외피 아래 기계층이 새어 나오는 감각 | 165초 | 현악 sul ponticello, 필터된 relay, 유리 마찰, 좁은 합성 drone | loop=true; C0 전조→C5 채널층 추가 | C~D4; 퍼즐 집중 시 중역 stem duck | `CAP_BGM_S2_LEAK` |
| `BGM_D5_BREAK` | 실패가 아니라 세계 설명 방식이 갈라지는 순간 | 55초+hold | 태엽 리듬, 찢긴 현악 sustain, 필터 해제 noise, 낮은 시설 공명 | one-shot intro 35초→20초 hold loop; demo/full outro 2종 | D5 `demo_stinger`는 질문에서 멈춤, `full_transition`은 D6로 호흡 연결 | `CAP_BGM_D5_BREAK` |
| `BGM_S3_FRACTURE` | 익숙한 방과 시설이 동시에 존재하는 불안정한 일상 | 175초 | S0 주제의 끊긴 조각, 팬·펌프 리듬, 비올라, 불규칙 piano resonance | loop=true; 수리 완료마다 조각 하나 정렬 | D6~E6; E5 LOW/MID/HIGH/ALL은 악기 수와 인간적 숨결만 변화 | `CAP_BGM_S3_FRACTURE` |
| `BGM_S4_CORE` | 진실과 선택 사이를 냉정하게 보게 하는 집중 | 190초 | 낮은 피아노 단음, 모듈러 texture, bow metal, 종이·흑연 타악 | loop=true; F0 단계 sync marker, F1에서 얇게 duck | F0~EDC; F0-E 3의향에 동일 조성·음량 | `CAP_BGM_S4_CORE` |
| `BGM_S5_STAY` | 알고 남은 세계의 안온함과 미세한 부자연스러움이 공존 | 185초 | 부드러운 실내악, 식기/시계의 생활 pulse, 약한 합성 공기층 | loop=true; 완전 종지 없이 마지막 프레임 tail | 잔류 헌장·중앙홀·식탁; good-ending fanfare 금지 | `CAP_BGM_S5_STAY` |
| `BGM_R0_REALITY` | 황폐함, 몸의 무게, 아직 판정되지 않은 가능성 | 185초 | 넓은 바람, 금속 현장음, 아주 적은 피아노, 숨과 겹치지 않는 저현 | loop=true; 기상 직후 무음 6~10초 뒤 진입 | 현실 냉각실→표면; 승리 fanfare·희망 강요 금지 | `CAP_BGM_R0_REALITY` |
| `BGM_CREDITS` | 두 선택의 공통 기억을 회수하되 결론을 대신하지 않음 | 225초 | S0·서명 6종·S4 주제를 같은 비중으로 편곡, 피아노·현악·유리·전자층 | loop=false; 완결곡, 스킵·재시작 지점 제공 | 두 엔딩 공통; 엔딩별 첫 12초 stem만 다르고 본곡 합류 | `CAP_BGM_CREDITS` |

## 3. 인격 서명음 6종

서명음은 사용인의 색과 같은 “스펙트럼 서명”의 청각 대응이다. 감정 효과음이나 대사 음성이 아니며, 색 제거·음량 0에서는 고유 문양·명칭·선 패턴으로 대체한다.

| asset_id | 소유자·용도 | 길이 | 악기·음색 | 반복 여부 | 필수 변형 | sensory_caption_id |
| --- | --- | ---: | --- | --- | --- | --- |
| `AUD_SIG_EDGAR` | 에드가; 잠금·정렬·책임 권한 | 0.9초 | 낮은 시계 톤, 금속 잠금핀, 짧은 직선 bow | one-shot; 250ms cooldown | S1 기억 누수, B2 접근, S3 포트, 권한 반환 | `CAP_SIG_EDGAR_LOCK_TONE` |
| `AUD_SIG_MARA1` | 마라 1; 정비·보호 식별자 | 0.7초 | 마른 솔, 스패너의 둔한 접촉, 빠른 대각 sweep | one-shot; 200ms cooldown | S1 반응, S2 배선, E3_1 손상/복원 | `CAP_SIG_MARA1_BRUSH` |
| `AUD_SIG_LUCA` | 루카; 생명 유지·이중 맥박 | 1.2초 | 낮고 높은 두 pulse, 부드러운 응답음, 쥐 귀 센서 click | one-shot; 반복 감소 시 단일 pulse | S1 차, S2 배관, E3_3 안정화 | `CAP_SIG_LUCA_DOUBLE_PULSE` |
| `AUD_SIG_IRIS` | 이리스; 기후·보호 기억 | 1.4초 | 얇은 유리, 짧은 바람, 꽃잎처럼 퍼지는 noise | one-shot; 긴 tail 0.8초 | S1 날씨, S2 센서, E3_2 outcome·고백 상태 | `CAP_SIG_IRIS_GLASS_WIND` |
| `AUD_SIG_MARA2` | 마라 2; 기록·체크섬·이름 | 0.8초 | 빠른 3음, 액자핀 click, 이중 윤곽 delay | one-shot; 300ms cooldown | S1 이름, S2 결손, E3_5 병합/분리, FU | `CAP_SIG_MARA2_ARCHIVE_TRILL` |
| `AUD_SIG_SUBJECT` | 주인공; 자기작성 권한 | 0.65초 | 흑연 필기, 종이 섬유, 손끝 마찰 | one-shot; 입력 연속 시 3개 variation | A1, J복원 확인, F0-E 작성, EDC | `CAP_SIG_SUBJECT_GRAPHITE` |

## 4. 관계·선택 중립성

- E5 LOW/MID/HIGH/ALL은 “좋아짐”의 화려한 상승이 아니라 함께 들리는 인간적 층의 수가 늘어나는 방식이다.
- F0-E 의향 3종은 같은 조성·길이·음량을 사용하고 음색만 현재 문장에 맞게 얇게 바꾼다.
- 현실은 밝은 장조, 잔류는 불협화음이라는 단순 판정을 금지한다.
- 사용인 관계 미완료는 서명음 소실이 아니라 거리·잡음·응답 지연으로 표현한다.

## 5. 완료 조건

- BGM 10, 서명음 6의 `asset_id`가 정확히 한 번씩 존재한다.
- intro·loop·outro sample과 저장·로드·스킵 재개 지점이 검증됐다.
- D5 demo/full, E5 4등급, F0-E 3의향, 두 엔딩의 비교 mix가 제출됐다.
- 음악·서명음을 0으로 해도 모든 진행 정보와 정체 식별이 유지된다.
