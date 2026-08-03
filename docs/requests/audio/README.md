# GGB 전체 사운드 의뢰 부속 명세

## 1. 역할

이 폴더는 정본 오디오 97행을 실제 제작·검수 가능한 cue로 설명한다. 부모 실행 의뢰는 `REQ-AUD-2026-0001~0003`이며, 담당·수락·일정은 [request_register.csv](../request_register.csv)에서 관리한다.

| 문서 | 범위 | 정본 수량 |
| --- | --- | ---: |
| [공간 앰비언스 전수 명세](01_공간앰비언스_전수명세.md) | M2·M1·B1·H0·R0 공간음 | 39 |
| [BGM·인격 서명음 전수 명세](02_BGM_인격서명음_전수명세.md) | 상태 음악 10·서명음 6 | 16 |
| [퍼즐·전환 전수 명세](03_퍼즐_전환_전수명세.md) | 퍼즐 14·주요 사건 8 | 22 |
| [공통 SFX 전수 명세](04_공통SFX_전수명세.md) | 시스템·시계·오브젝트·UI | 20 |
| **합계** | `asset_manifest.csv`의 `owner=NOne` | **97** |

## 2. 공통 제작 계약

- 플랫폼은 Windows 10/11 64-bit PC이며, 음성 연기는 현재 제품 범위에 포함하지 않는다.
- 납품 기본은 WAV 48kHz/24-bit다. BGM·앰비언스는 stereo, 방향 위치가 필요한 효과는 mono 원본을 우선한다.
- 시작 기준은 BGM -22~-18 LUFS-I, 앰비언스 -28~-22 LUFS-I, UI -24~-20 LUFS-I, true peak -1 dBTP 이하다. 숫자만 맞추지 말고 실제 동시 발음 검수로 조정한다.
- `asset_id`는 매니페스트 부모다. 한 부모 안의 개별 소리는 `cue_part_id`로 추적하며 정본 registry 승인 전에는 새 runtime ID로 간주하지 않는다.
- 필수 정보가 있는 소리는 `sensory_caption_id`, 화면 파형·문양·상태명 중 하나 이상과 연결한다. 방향음만으로 정답을 요구하지 않는다.
- 반복음 감소, 저주파 감소, 호흡·심박 감소를 켜도 진행 정보와 리듬 정답이 유지돼야 한다.
- 기존 VS 19개 cue는 `EXTEND`, 나머지 78개는 `NEW`다. `EXTEND`는 버리지 않고 전체 게임 변형·스템·재개 상태를 추가한다.

## 3. 공통 납품

| 묶음 | 요구 |
| --- | --- |
| 원본 | DAW 프로젝트, stem·MIDI·녹음 원음, 플러그인·샘플·권리 정보 |
| 마스터 | WAV 48kHz/24-bit, peak·LUFS 측정, 무음·tail·loop 경계 검증 |
| 게임 적용본 | `asset_id__variant__rNN.wav`, loop sample, bus, priority, cooldown, 동시 발음 수 |
| 접근성 | `sensory_caption_id`, 한국어 의미 설명, 비청각 신호, 감소 설정 대체 |
| 검증 | waveform, 인게임 캡처, 저장·로드·스킵·재개, 28 voice 동시 발음 stress |
| 증거 | 제작자·revision·license/rights·검토자·실제 제작 시간 |

## 4. 열린 연결 사항

- `GGB-CNF-2026-0018` 해결 전 `AUD_PUZ_B3_A`의 외부 서고 시계는 `OBJ_LIBRARY_RECORD_CLOCK`에 연결하지 않는다.
- 이벤트 매니페스트의 그룹형 `source_entity_id`는 부모 오디오 ID를 유지하되 실제 재생 노드는 CNT/이벤트 추적표에서 배열로 연결한다.
- `AUD_EVT_JOURNAL_RESTORE`는 연출 묶음, `SFX_JOURNAL_RESTORE`는 짧은 결합 효과다. 퍼즐 pack과 공통 검증음도 같은 방식으로 부모/레이어 관계를 유지한다.
