# 타이틀 위의 창 · 2026-10-24

새 게임·불러오기·설정·첫 실행 접근성은 기존 타이틀 위에 열린다. 같은 배경과 주인공 노드를 계속 사용하며, 마우스에 따른 배경과 캐릭터의 시차 움직임도 유지한다. 줄이기·끄기 설정, 창의 포커스 상실, 입력 중단 상태에서는 기존처럼 움직임을 멈춘다.

종이 창의 위치·크기·글자·컨트롤 배치는 유지했다. 창이 열린 동안 메인 메뉴의 마우스와 키보드 포커스를 막고, 닫으면 타이틀 조작을 복원한다.

`game/scenes/ui/start_screen.tscn`의 다음 인스턴스에서 자체 Background의 Visible만 끈다. 따라서 편집기에서 타이틀을 열어도 실제 합성을 확인할 수 있다.

- `ModalLayer/SlotPanel/NewGamePanel/Background`
- `ModalLayer/SlotPanel/LoadGamePanel/Background`
- `ModalLayer/SettingsPanel/Surface/Background`
- `ModalLayer/FirstRunPanel/Surface/Background`

개별 창 씬에는 단독 미리보기용 배경이 남아 있다. 창 자체의 편집은 기존 `new_game_panel.tscn`, `load_game_panel.tscn`, `settings/settings_screen.tscn`에서 한다. 타이틀 인스턴스의 Editable Children도 켜 두었다.

큰 종이 창의 배경 어둡기는 StartScreen Inspector의 `Paper Modal Dimmer Color`로 조절한다. 기본 알파는 0.22이다. 종료·덮어쓰기 같은 작은 확인창은 `ModalLayer/ModalDimmer`에 저장한 기존 색을 사용한다.

`start_screen_scene_edit_smoke.tscn`은 네 창의 배경, 원래 아트 인스턴스 유지, 창 크기 보존, 포커스 제한, 창 뒤의 시차 움직임, 정적 모드와 입력 중단 처리를 검사한다. 실제 렌더링과 보고서는 `outputs/title-scene-2026-10-24/`에 저장한다.
