# Data Contract

이 문서는 기획 문서와 Godot 구현 데이터 사이의 연결 규칙입니다.

## Source Of Truth

- 사람이 읽는 기획 원본: `ideas/md/v04/`
- 게임에서 읽을 구현 데이터: `game/data/`

기획 문서를 게임이 직접 읽지 않습니다. 구현에 필요한 내용은 JSON, CSV, Godot Resource 등으로 정제해 `game/data/`에 둡니다.

## Data Folders

- `game/data/events/`: 이벤트 정의, 선행 조건, 결과 플래그입니다.
- `game/data/dialogue/`: 사용인별 대사, 분기 대사, 반복 반응입니다.
- `game/data/puzzles/`: 퍼즐 규칙, 입력, 힌트, 실패 기록입니다.
- `game/data/states/`: 전역 플래그, 관계 변수, 리셋 지속 정보입니다.

## ID Rule

기획 문서의 이벤트 ID를 구현 데이터에서도 유지합니다.

예:

```text
B2
B2_EDGAR_ENTRY
B2_HIDE
B2_CAUGHT
J1
J4
F1
J5
E3_5
MARA2_S1
```

## State Rule

상태 변수는 다음 기준으로 나눕니다.

- 물리 리셋 대상: 방 상태, 오브젝트 위치, 당일 도구 상태
- 영구 유지 대상: 수첩 정보, 일지 복원 단계, 사용인 잔류 기억, 관계 변화
- D5 이후 별도 상태: 위장 필터 해제, 파열 상태, 복구 불가능한 공간 변화

## Implementation Note

초기 구현에서는 JSON을 사용해도 좋습니다. Godot Resource로 전환할 경우에도 ID와 필드 의미는 유지합니다.

