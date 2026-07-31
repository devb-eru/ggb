# GGB 아트·애니메이션·오디오 제작 규격

## 1. 목적과 우선순위

본 문서는 `docs/asset_manifest.csv`의 deliverable을 실제 제작·검토 가능한 단위로 만드는 기술 규격이다. 감정·색·공간 의미는 `ideas/md/v04/`를 따르고, 해상도·레이어·파일·오디오 cue·승인 형식은 본 문서를 따른다. 제작자는 [팀별 제작 의뢰](requests/README.md)에서 지정한 subset·사용 장면·승인 조건을 확인하고, 완료물을 [에셋 접수 절차](asset_intake.md)로 전달한다.

우선순위:

1. 퍼즐과 접근성 정보 보존.
2. 1280x720~4K와 90~220% UI 대응.
3. 재사용 가능한 pose·표정·room layer.
4. 성능 예산.
5. 장식적 추가 프레임과 효과.

## 2. 파일·색·좌표 공통 규칙

| 항목 | 규칙 |
| --- | --- |
| master color | sRGB, 8-bit 기본. 후처리용 mask만 grayscale 허용 |
| alpha | straight alpha. export 가장자리 RGB 오염 검사 |
| master 보관 | 승인된 Drive 원본과 버전. Git에는 실제 런타임 export·필요 source만 LFS |
| runtime 이름 | `asset_id__variant__rNN.ext` |
| 좌표 | 1920x1080 논리 기준, 원점 좌상단 |
| 안전 영역 | 필수 UI·단서 x=64~1856, y=48~1032 안. 200% UI에서는 별도 reflow |
| 클릭 영역 | 최소 44x44 논리 px. 작은 오브젝트는 투명 hotspot을 확대 |
| 미리보기 | 1920x1080 PNG + 1280x720 + 200% UI 증거 |

master와 runtime export를 같은 파일로 덮어쓰지 않는다. 색상 HEX는 source palette token이고 최종 화면색은 renderer·배경 대비 검수 뒤 잠근다.

## 3. 배경·공간

### 3.1 캔버스

| 용도 | master 권장 | runtime 기준 |
| --- | ---: | ---: |
| 고정 한 화면 방 | 3840x2160 | 1920x1080 기본, High 선택 export는 성능 시험 뒤 |
| 수평 이동 방 | 높이 2160, 폭 최대 6144 | 논리 viewport 1920x1080, 화면 1.5배 이내 권장 |
| 퍼즐 확대 패널 | 2048x2048 또는 실제 비율 | 화면 점유 960x960 이하 기준 |
| 소형 오브젝트 | 표시 크기의 2배 master | 1x runtime에서 선 두께 1px 미만 금지 |

4K 모니터 지원이 모든 배경을 4K texture로 상주시킨다는 뜻은 아니다. 실제 export variant는 `technical_performance_budget.md`의 VRAM 결과로 결정한다.

### 3.2 방 레이어

```text
00_bg_far
10_bg_mid
20_interact_back
30_character_back
40_character
50_interact_front
60_world_fx
70_guidance_overlay
80_ui
```

| 레이어 | 최대 권장 | 역할 |
| --- | ---: | --- |
| base background | 1 | 고정 구조 |
| phase overlay | 3 동시 | S0~S5 중 현재 단계 차이 |
| interaction states | 화면당 12 visible | 문·서랍·퍼즐 상태 |
| ambient fx | 4 동시 | 먼지·잔광·증기. 단서와 겹치지 않음 |
| foreground mask | 2 | 캐릭터·오브젝트 가림 |

각 방 sheet는 `location_id`, 노출 world phase, 카메라 범위, hotspot ID, 캐릭터 anchor, foreground mask, ambient cue를 포함한다.

### 3.3 카메라

- 기본은 고정 카메라다.
- 이동은 플레이어 확정 입력 또는 방 전환에만 사용한다.
- 자동 pan은 0.4~1.2초, 모션 감소에서는 컷 전환으로 대체한다.
- 퍼즐 확대 뒤 취소하면 이전 방 좌표와 포커스로 돌아간다.
- 필수 hotspot은 카메라 경계 밖에 조용히 남겨 두지 않는다.

## 4. 캐릭터 deliverable

### 4.1 공통 sheet

캐릭터별 `character_sheet`는 아래를 한 번에 검토한다.

- 정면·3/4·측면·후면.
- 키 비교와 눈높이.
- 종족 특징의 최대 가동 범위.
- 소품 휴대·사용 위치.
- 대표색, 보조색, 회색조 실루엣.
- S0 고딕 외형, S2 누수, S3 파열, S5 안정화 표기.
- 128px 흑백 실루엣 식별.

master 세로는 3000px 이상을 권장하되, 실제 런타임 full-body 표시 높이는 1080p에서 900px 이하로 둔다.

### 4.2 표정 matrix

| 캐릭터 | 필수 표정 token | 목표 수 |
| --- | --- | ---: |
| 주인공 | neutral, curious, uneasy, fear, avoidant, determined, hurt, quiet_relief | 8 |
| 에드가 | neutral, report, disapprove, guarded, startled, guilt, request, restrained_farewell | 8 |
| 마라 1 | smile, broad_laugh, smug, confused, panic, serious, anger, guilt, soft, farewell | 10 |
| 루카 | timid, sweat, startled, focus, firm, guilt, relief, farewell | 8 |
| 이리스 | maternal_smile, warm_laugh, concern, blank_smile, resentment, denial, confession, grief | 8 |
| 마라 2 | grin, boast, tease, calculate, name_check, error, fear, anger, request, farewell | 10 |

표정 token은 대사 데이터에서 직접 참조한다. 같은 의미의 새 이름을 장면마다 만들지 않는다. 눈·입·눈썹을 무제한 조합하지 않고 승인된 합성만 registry에 둔다.

### 4.3 pose matrix

| token | 공통 용도 |
| --- | --- |
| `idle` | 기본 대화 |
| `work` | 역할 소품 사용 |
| `guarded` | 감정·정보 방어 |
| `interact` | 오브젝트 지시·전달 |
| `fracture` | S3 기계 외형 노출 |
| `farewell_or_charter` | 엔딩 분기 변형 |

각 캐릭터 최소 6 pose를 기본으로 하되, 기존 pose의 손·소품 overlay로 해결 가능한 장면은 새 full pose를 만들지 않는다. 전용 pose 추가는 event ID와 예상 재사용 횟수를 manifest evidence에 적는다.

### 4.4 종족 특징과 소품 layer

| owner | 분리 layer | 충돌 검사 |
| --- | --- | --- |
| 에드가 | 뿔, 꼬리, 레이피어 | 대화창·문틀·다른 인물과 수직선 충돌 |
| 마라 1 | 여우 귀, 큰 꼬리, 스패너 | 큰 동작이 hotspot을 가리지 않음 |
| 루카 | 쥐 귀, 수염형 센서, 땀 | 귀 연두가 배경에서 단독 단서가 되지 않음 |
| 이리스 | 백금발, 플라스틱 날개 | 흰 의상·날개가 밝은 배경에서 사라지지 않음 |
| 마라 2 | 박쥐 귀, 날개막, 이름표 | 보라 이중 윤곽과 날개 실루엣 분리 |

## 5. 제한 애니메이션

| state | 프레임·시간 | 규칙 |
| --- | --- | --- |
| idle | 4~8 frame, 2~5초 loop | 모든 인물 같은 박자 금지 |
| blink | 2~3 frame | 말 중 자동 반복 최소화 |
| speak | 입·상체 2~4 state | 음성 없으므로 글자마다 lip sync 금지 |
| react_short | 4~12 frame | 짧은 반응 1회, 취소 가능 지점 뒤 |
| work_loop | 6~16 frame | 역할 소품, 퍼즐 입력을 가리지 않음 |
| fracture_reveal | 8~24 frame | 광과민 대체 정적 state 필수 |
| ending_beat | 6~18 frame | 분기 공통 timing, 선악 색 코딩 금지 |

캐릭터 애니메이션은 12fps 기준으로 제작하고 UI·카메라·입력은 60fps 논리 갱신을 유지한다. 보간은 실루엣과 소품 위치를 흐리지 않을 때만 사용한다.

## 6. UI 시각 규격

- 패널은 9-slice 또는 vector로 90~220%에서 모서리 두께를 유지한다.
- 본문 최소 18px @1080p, 기본 22px 권장. 실제 폰트 x-height로 조정한다.
- focus ring은 3px 이상, 색 외에 외곽선·corner marker를 함께 쓴다.
- hover, focus, selected, disabled, invalid, confirmed를 각각 별도 state로 만든다.
- 인벤토리 아이콘은 128x128 master, 64x64 기준 표시, 44x44 hotspot 하한을 지킨다.
- 수첩의 흑연 texture는 글자 대비를 낮추지 않으며 plain background 접근성 모드를 제공한다.

## 7. 오디오 master와 export

| 유형 | master | runtime |
| --- | --- | --- |
| BGM·ambient | WAV 48kHz/24-bit stereo | Godot import 압축, loop 검증 |
| 위치 SFX | WAV 48kHz/24-bit mono 권장 | 공간화가 없으면 stereo 허용 |
| UI SFX | WAV 48kHz/24-bit mono/stereo | 짧은 tail, 중복 억제 |
| signature cue | WAV 48kHz/24-bit | owner별 pattern과 자막 ID |

- master peak는 -1 dBTP 이하를 기본으로 한다.
- 최종 loudness는 단일 파일 숫자보다 in-engine bus mix에서 승인한다.
- BGM은 대체로 -22~-18 LUFS-I, ambient -28~-22, UI -24~-20 범위를 출발점으로 삼되 장면 비교로 조정한다.
- 과도한 저주파는 심박·기계 불안 연출에서만 제한적으로 사용하고 감소 옵션을 제공한다.

## 8. 오디오 bus·동시 발음

```text
Master
├─ BGM
├─ Ambient
├─ WorldSFX
├─ Signature
├─ UI
└─ AccessibilityCue
```

| bus | 최대 동시 voice | 우선순위 |
| --- | ---: | --- |
| BGM | 2 | 전환 crossfade |
| Ambient | 6 | 현재 room 1, 인접 room fade |
| WorldSFX | 16 | 퍼즐 확정>상호작용>장식 |
| Signature | 5 | 필수 owner cue>감정 잔상 |
| UI | 6 | confirm/error>hover |
| AccessibilityCue | 4 | 필수 정보, 다른 bus에 ducking 가능 |

전체 동시 voice는 28을 넘지 않게 시작한다. 동일 cue가 100ms 안에 반복되면 하나로 합치고, 퍼즐 입력 확인음은 ambient에 묻히지 않게 한다.

## 9. BGM 상태

| cue group | world state | 기능 |
| --- | --- | --- |
| `BGM_TITLE` | title | 저택의 주제 제시, 엔딩 가치 선취 금지 |
| `BGM_S0_ROUTINE` | S0 | 정갈한 일상, 완전 해결감 금지 |
| `BGM_S1_SUSPICION` | S1 | 반복 잔향 |
| `BGM_S2_LEAK` | S2 | 고딕·기계 layer 교차 |
| `BGM_D5_BREAK` | D5 | 전환, 광과민 대체와 timing 공유 |
| `BGM_S3_FRACTURE` | E_HUB | 불안은 유지하되 카운트다운처럼 들리지 않음 |
| `BGM_S3_FRACTURE` + `E5_SETTLEMENT` variant | E5 | 같은 asset의 LOW~ALL 편곡 variant; 편성만 변화 |
| `BGM_S4_CORE` | F0~F3 | 메타퍼즐·선택 중립 |
| `BGM_R0_REALITY` | 현실 | 희망 승리 fanfare 금지 |
| `BGM_S5_STAY` | 잔류 | 안락한 굿엔딩 cadence 금지 |
| `BGM_CREDITS` | 공통 | 두 엔딩 공통 주제 회수 |

일반 fade는 1.0~2.5초, 방 ambient는 0.3~1.0초를 시작값으로 사용한다. D5와 EDC는 event marker를 사용하되 프레임률에 종속하지 않는다.

`E5_SETTLEMENT`는 현재 `BGM_S3_FRACTURE`의 편곡·stem variant다. 독립 loop와 별도 승인 단위가 필요하다고 실측되면 새 manifest 행을 발급하고 임의 파일명만 늘리지 않는다.

## 10. cue registry 계약

```yaml
audio_cue:
  audio_id: SFX_MARA2_ARCHIVE_TRILL
  asset_id: AUD_SIG_MARA2
  source_event_ids: [P3B, MARA2_S1, E3_5, F0_D]
  bus: Signature
  priority: required_information
  max_instances: 1
  cooldown_ms: 250
  loop: false
  sensory_caption_id: CAP_MARA2_ARCHIVE_TRILL
  reduced_sensory_replacement: CAP_MARA2_ARCHIVE_TRILL
```

모든 퍼즐 필수 cue는 `audio_id`, `asset_id`, event ID, bus, priority, caption ID를 가진다. 파일 경로를 이벤트 데이터에 직접 쓰지 않는다.

## 11. 승인 패키지

### 아트

- `request_id`와 수락된 asset subset.
- master 링크·revision.
- runtime export와 import 설정.
- 1080p 기본, 720p, 4K, 200% UI screenshot.
- 색 제거·고대비 screenshot.
- 관련 `asset_id`, location/object/event ID.
- 메모리 계측 또는 budget 추정.

### 오디오

- `request_id`와 수락된 cue subset.
- master·runtime 파일.
- waveform, loop point, peak·loudness 측정.
- in-engine 녹화 또는 capture.
- 음량 0 대체 자막과 cue ID.
- 동시 발음 stress 결과.

## 12. 완료 게이트

- 캐릭터 expression·pose token이 대사·이벤트 데이터와 일치한다.
- 방별 layer/camera sheet가 모든 demo location에 있다.
- 필수 audio cue가 caption ID와 일대일 연결된다.
- 1280x720·200%·색 제거에서 필수 단서가 유지된다.
- runtime export가 성능 예산을 넘지 않는다.
- manifest 행의 `unit_count`, owner, reviewer, license와 evidence가 채워진다.
