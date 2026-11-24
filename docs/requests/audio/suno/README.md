# GGB AUD 전수 Suno 프롬프트

## 범위와 사용법

2026-09-08 기준 [AUD 전수 명세](../README.md)의 부모 97종, 퍼즐 하위 입력음, 지정 변형과 공통 폴리용 프롬프트다. 음원 제작·Suno 업로드·유료 생성·권리 승인을 수행한 문서가 아니다. 정본 명세의 재질·의미·길이·접근성 계약은 유지한다.

| 문서 | 부모 수 | 포함 내용 |
| --- | ---: | --- |
| [공간음](01_공간음.md) | 39 | 공간별 기본 입력문, 도달 상태별 추가 입력문 |
| [음악과 서명](02_음악과서명.md) | 16 | 음악 10곡, 서명 6종, 관계·엔딩·감소 변형 |
| [퍼즐](03_퍼즐.md) | 14 | 각 조작·결과·유지 반복음 |
| [전환](04_전환.md) | 8 | 정상/깨진 리셋, 파열, 일지 5단계, 엔딩 |
| [공통 효과음과 폴리](05_효과음과폴리.md) | 20 | 시스템 효과음, 재질별 변형, 폴리 7묶음 |

Suno Custom 모드에서 Instrumental을 켜고 가사 생성은 사용하지 않는다. `Styles`에는 아래 공통 입력문 + 대상 기본 입력문 + 필요한 변형 입력문 **하나**를 연결해 붙인다. 별도 생성한다고 적은 층은 다른 생성으로 분리한다. Title에는 `부모ID__하위ID또는변형__r01`을 쓴다. 표의 한국어 설명·시간·ID 자체는 가사나 프롬프트에 붙이지 않는다. 영문은 복사할 입력문, 한국어는 제작 지시다. 영문 사용은 이 문서의 통일 방식이지 한국어가 지원되지 않는다는 뜻이 아니다.

## 공통 입력문과 제외 입력

| 분류 | Styles 앞에 붙일 공통 입력문 | Exclude에 붙일 문구 |
| --- | --- | --- |
| MUSIC | `Instrumental psychological mystery game underscore. Intimate, restrained and attentive, gothic chamber textures gradually revealing a quiet technological environment. Leave room for reading and interaction. Stable dynamics, no moral judgement of the player's choices.` | `vocals, lyrics, spoken words, choir, screams, jump scares, trailer booms, EDM drops, triumphant fanfare` |
| AMBIENCE | `Non-musical environmental soundscape for a quiet point-and-click game. Continuous natural room tone, restrained material detail, irregular unobtrusive activity, stable level, no opening or ending gesture. Leave space for foreground interaction sounds.` | `vocals, speech, choir, melody, song structure, chord progression, drum beat, jump scares, sirens, cinematic risers` |
| CUE | `Isolated non-musical game sound design source. A single brief tactile gesture followed by clear silence, close and dry recording, clean onset and natural short decay. No background bed. If more gestures occur, keep them widely separated for editing.` | `vocals, speech, singing, choir, music, melody, drums, backing track, long reverb, jump scares, explosions` |
| SIGNATURE | `Isolated miniature nonverbal identity sound for a psychological mystery game. Quiet, concise and recognizable by material and contour, not an emotional reward. Clean onset, silence after the natural decay, no backing track.` | `vocals, speech, singing, choir, drums, full song, fanfare, jump scares, long reverb` |
| TRANSITION | `Non-musical scene transition sound design for a psychological mystery game. A deliberate sequence of tactile materials and environmental perspective changes, restrained dynamics, clear beginning and end, no spoken narration or musical score.` | `vocals, speech, choir, melody, drums, musical climax, jump scares, explosions, victory fanfare` |

한 번의 생성에는 한 대상만 요청한다. 여러 표 행을 한꺼번에 붙여 묶음 전체를 한 음원으로 만들지 않는다.

## 생성과 편집의 경계

- 아래 초 수는 **최종 게임용 편집 목표**다. 프롬프트만으로 Suno가 정확한 길이, 타격 수, 음정, 무음, 독립 스템, 끊김 없는 반복을 보장하지 않는다. 특히 CUE·폴리는 후보 재료를 얻는 실험용 입력문이며, 음악처럼 생성되면 납품으로 채택하지 않는다. 반복 생성으로 해결되지 않으면 직접 녹음·합성으로 명세를 충족한다.
- 음악의 공통 주제는 먼저 승인한 S0의 짧은 모티프를 기준으로 편곡한다. 서로 다른 텍스트 생성물이 같은 선율을 유지한다고 가정하지 않는다. 새 곡마다 승인 음원의 실제 선율·박자·음역을 확인해 DAW에서 맞춘다. 타인 음악이나 권리가 불명확한 참조는 업로드하지 않는다.
- 상태 변형은 가능하면 승인 기본 테이크의 같은 구간에 별도 재질층을 추가·제거하는 편집으로 만든다. 여러 상태를 각각 통째로 재생성해서 방 규모·주제·재질이 바뀌지 않도록 한다. 아래 `추가 입력문`은 재생성 방향 또는 **분리할 재료의 생성 지시**이며, 혼합된 생성 결과를 독립 스템으로 간주하지 않는다.
- 음악/BGM은 스테레오, 위치 효과음은 모노 원본으로 정리한다. WAV 48kHz/24-bit 변환은 납품 형식이며 원본보다 실제 음질이 높아졌다는 뜻이 아니다. 진폭·LUFS·트루피크·테일은 [공통 규격](../README.md)에 따라 측정한다.
- 반복 구간은 파형·위상·잔향을 확인해 DAW에서 연결한다. 초 단위 목표만으로 반복 샘플 지점을 계산·확정하지 않는다. 정확한 종 13회, 3음 서명, 이중 맥박과 위상은 깨끗한 단발음을 편집 배열한다.
- 게임의 재생 조건, 자막, 쿨다운, 저장·로드 중복 방지는 프롬프트가 아니라 구현 계약이다. 필수 단서의 비청각 표시를 삭제하지 않는다. 감소 설정은 중요한 신호 삭제가 아니라 대체 음색/밀도·저역·호흡 조절로 만든다.
- F0-E 세 의향과 현실/잔류는 같은 길이·체감 음량·음악적 비중이다. LOW/MID/HIGH/ALL은 관계 평가의 승리/패배 효과가 아니다. 미완료 사용인도 거리·잡음으로 존재를 유지한다.
- 기존 VS EXTEND 음원은 먼저 청취한다. 승인 원음을 유지하고 빠진 변형만 제작한다. 공통 SFX와 퍼즐·전환 본체를 이중으로 합산하지 않는다.
- 생성 날짜·사용 모델·계정 조건·입력문·결과 링크·채택 구간·편집 내역·제작자·권리 근거를 기록한다. 생성물의 게임 배포 가능 여부는 생성 당시 이용 조건과 권리 검토로 확인하며 이 문서로 승인하지 않는다. 실제로 없는 MIDI·녹음 원음·분리 스템을 납품했다고 기록하지 않는다.

## 변형 표기와 검수

문서의 한국어 변형명과 `PRESSURE_WAIT_LOOP` 등 추가 작업용 명칭은 프롬프트/납품 추적 키다. 정본 runtime ID를 새로 발급하지 않는다. 명세가 수량만 정한 변형에는 이 문서에서 제작용 세부안을 제공한다. 분기 조건·퍼즐 정답은 변경하지 않는다.

1. 부모 97종과 퍼즐의 모든 명시 하위 cue가 문서에 대응하는지 확인한다.
2. 각 기본·변형을 생성할 때 대사/노래 유입, 불필요한 박자, 파열음, 길이·테일, 신호 식별을 청취한다.
3. 음악은 대화·퍼즐 위에서, 공간음은 10분 이상 반복해서 검수한다. 효과음은 연속 입력과 최대 동시 발음에서 확인한다.
4. 두 엔딩·세 의향·관계 4등급을 음량 보정 후 비교한다. 소리 없이 진행 가능한지도 별도로 검증한다.

현재 완료 범위는 **프롬프트 작성과 문서 대응 검사**다. 실제 Suno 생성 성공률, 음원 청취·인게임 검수는 미실시다.

[검증 기록](검증기록.md)에 원전 대조 범위와 남은 음원 제작 검수를 정리했다. 프로젝트 루트에서 `& 'docs/requests/audio/suno/validate_prompts.ps1'`로 부모 ID·퍼즐 하위 cue·폴리·링크 대응을 다시 검사할 수 있다.

## Suno 공식 확인 근거

- Custom·Instrumental·Styles 입력 흐름: [Suno Custom Mode 안내](https://help.suno.com/en/articles/3197377). 공식 문서가 웹과 같은 흐름임을 명시한다. 화면 배치나 계정별 기능은 실제 PC 웹에서 확인한다.
- 원하지 않는 악기·요소는 Advanced Options의 Exclude에 입력: [Suno Exclude 안내](https://help.suno.com/en/articles/3161921).

특정 모델 버전·유료 편집 기능은 필수로 지정하지 않는다. 위 안내를 확인한 날짜는 2026-09-08이다.
