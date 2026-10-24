# 새 게임·불러오기 씬 · 2026-10-24

제공된 `game/assets/ui/save_load/` 에셋으로 두 화면을 별도 Godot 씬으로 구성했다. `start_screen.tscn`의 `ModalLayer/SlotPanel`에서 두 씬을 사용한다.

| 편집 대상 | 파일과 노드 |
| --- | --- |
| 새 게임 | `game/scenes/ui/new_game_panel.tscn` |
| 불러오기 | `game/scenes/ui/load_game_panel.tscn` |
| 공통 슬롯 행 | `game/scenes/ui/save_slot_row.tscn` |
| 배경·종이 | 각 패널의 `Background`, `Paper` |
| 제목·구분선·닫기 | `Content/Title`, `HeaderRule`, `Close` |
| 행 간격·높이 | `Content/RowsScroll/Rows`, 각 행의 Custom Minimum Size |
| 뒤로·확정 | `Content/Back`, `Content/Confirm` |
| 썸네일·글자 배치 | 공통 행의 `Thumbnail`, `ThumbnailFrame`, `Text`, `Timing`, `Empty` |

위치·크기·텍스처·기본 글꼴은 씬에서 수정한다. `save_load_panel.gd`는 저장 정보·번역·선택 상태를 연결하고, 씬에서 읽은 글자 크기와 행 높이를 기준으로 접근성 확대를 적용한다. 확대 시 슬롯 영역을 스크롤하며 키보드 포커스를 따라간다.

행을 선택한 뒤 하단 버튼으로 시작하거나 불러온다. 저장된 슬롯의 새 게임 시작에는 기존 덮어쓰기 확인을 사용한다. 첫 실행에서는 접근성 설정을 먼저 표시한다.

자동 저장 행은 기존 슬롯 중 최신 저장을 가리킨다. 별도 자동 저장 슬롯은 만들지 않는다. 저장 위치·일차·날짜는 검증된 저장 요약에서 읽는다. 표시 정보가 없는 기존 저장에는 예시 플레이 시간이나 예시 스크린샷을 넣지 않는다.

`save_presentation.gd`가 앞으로의 실제 플레이 시간과 저장 직후 렌더된 화면을 기록한다. 게임 화면이 활성화되어 있고 창에 포커스가 있으며 일시 정지 상태가 아닐 때 시간을 누적한다. 타이틀로 돌아오면 측정을 끝낸다. 썸네일은 중앙을 비율에 맞게 잘라 560×252 PNG로 저장한다.

표시 정보는 기존 슬롯 폴더의 `presentation.json`과 `thumbnail_<checksum 앞 16자리>.png`에 저장한다. 게임 저장의 체크섬·플레이 회차가 일치할 때만 읽는다. 새 회차와 다른 저장으로 복구된 경우 이전 표시 정보를 사용하지 않는다. 기존 게임 저장 형식과 저장 파일 바이트는 변경하지 않는다.

검증 결과:

- `save_load_ui_smoke.tscn`: 실제 마우스 선택·확정, 덮어쓰기 취소, 자동 저장 연결, 빈 슬롯 비활성화, 닫기, 200% 확대, 영어 표시 PASS.
- 씬 속성을 변경한 뒤 PackedScene으로 저장·재로드해 위치와 글자 크기가 실행 중에도 유지되는지 확인 PASS.
- 실제 게임 부트스트랩에서 저장 썸네일·시간 생성, 같은 회차 장면 전환 시 시간 유지, 새 회차 초기화, 저장 실패 시 표시 정보 보존 PASS.
- 기존 `START_SCREEN_SMOKE` PASS. 첫 실행 접근성 설정 순서 포함.
- 기존 `NOTEBOOK_MIGRATION_SMOKE` PASS. 저장 안전성 381개 검사 포함. 이 검사 실행 당시 다른 인스턴스가 사용하던 MCP Runtime 포트 7777 경고는 별도로 기록되어 있다.

스크린샷·로그·`audit.json`: `outputs/save-load-ui-2026-10-24/`. 검사용 APPDATA는 이 폴더 아래에 격리했다.
