# REQ-AUD-YYYY-NNNN: 사운드 제작 의뢰 제목

> 안내 문구를 지운 뒤 사용한다. 기술 기본값은 `docs/content_pipeline_specs.md`를 따르고, 예외만 본문에 적는다.

## 1. 의뢰 정보

| 필드 | 값 |
| --- | --- |
| request_id | `REQ-AUD-YYYY-NNNN` |
| 상태 | `DRAFT` |
| 배치·우선순위 | `BATCH-*` · `P2` |
| 담당 팀장·검토자 | `UNASSIGNED` · `UNASSIGNED` |
| 목표 마일스톤 | `UNSCHEDULED` |
| 플랫폼 | Windows 10/11 64-bit PC |
| 참조 work_id | `미발급` |
| request revision | `1` |

## 2. 목적과 믹스 방향

장면의 정서, 플레이어에게 전달할 정보와 다른 bus와의 관계를 쓴다.

## 3. 범위

### 포함

- BGM / AMB / SFX / UI / puzzle / signature.

### 제외

- 이번 의뢰에서 만들지 않을 범위.

## 4. cue 목록

| asset_id | 용도 | trigger·source_event_id | 느낌 | 길이 | 악기·음색 | 반복 여부 | bus·공간 | sensory_caption_id |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `AUD_*` | BGM / AMB / SFX | `*` |  |  |  | loop / one-shot |  | `CAP_*` |

## 5. cue별 상세

각 cue의 intro, loop 구간, outro·tail, 변형, stem, 동시 발음과 ducking을 적는다. 반복하지 않는 소리는 `loop=false`를 명시한다.

## 6. 접근성

- 필수 정보 cue마다 `sensory_caption_id`와 화면상 비청각 신호가 있다.
- 음량 0에서도 진행 가능한 대체 문구를 정의한다.
- 과도한 저주파·날카로운 고역·반복 자극의 감소 대체를 정의한다.
- 방향성 오디오만으로 정답을 요구하지 않는다.

## 7. 납품

| 묶음 | 요구 |
| --- | --- |
| source | DAW 프로젝트·사용 플러그인·샘플 권리 정보 |
| master | WAV 48kHz/24-bit, peak·loudness 측정 |
| runtime | Godot import 대상과 loop metadata |
| preview | waveform·in-engine capture·동시 발음 stress 결과 |
| registry | audio_id·asset_id·event·bus·priority·caption·cooldown |

## 8. 수락·완료 조건

### 팀 수락

- [ ] 담당자와 예상 공수가 기록됐다.
- [ ] cue 수, 길이, loop·stem 범위에 합의했다.
- [ ] 샘플·플러그인 권리와 차단 사항을 기록했다.

### 제작 완료

- [ ] 모든 cue의 길이·loop·tail과 runtime metadata가 검증됐다.
- [ ] 필수 cue가 자막·비청각 신호와 일대일 연결됐다.
- [ ] in-engine mix와 동시 발음 기준을 통과했다.
- [ ] 권리 증거와 팀장·QA 검토 결과가 남았다.

## 9. 팀 회신·변경 이력

| 날짜 | 주체 | 내용 | 상태·revision |
| --- | --- | --- | --- |
| YYYY-MM-DD | 작성자 | 최초 작성 | DRAFT · r1 |
