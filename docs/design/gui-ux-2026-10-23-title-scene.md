# 시작 화면 씬 갱신 · 2026-10-23

`game/scenes/ui/start_screen.tscn` 자체에 최신 로비를 배치했다. 배경·오른쪽 주인공·왼쪽 제목/메뉴/저장 상태가 런타임 코드 없이도 표시된다. 과거 SafeArea, 색상 로고 레이어, 임시 아트 및 숨겨진 보조 문구 노드를 제거했다.

편집 위치:

- 배경: `TitleBackground`
- 주인공: `HtmlTitleComposition/TitleProtagonist`
- 제목·메뉴 영역: `HtmlTitleComposition/TitleMenuLayout`
- 제목: 위 노드의 `LogoStack/Logo`
- 버튼: 위 노드의 `TitleMenuScroll/Menu`
- 어두운 배경 효과: `HtmlTitleComposition/TitleShade`

메뉴·아트 위치/크기, 그림자, 기본 폰트와 버튼 스타일은 씬에서 정한다. `title_composition.gd`는 씬을 재구성하지 않고 아트의 원래 위치를 기준으로 시차만 적용한다. `GothicTitleButton`은 편집기에서도 장식을 그리며 저장된 스타일을 덮어쓰지 않는다. 접근성 설정은 씬의 기본 글자 크기와 높이를 기준으로 확대한다. 제목/버튼 문구의 번역, 저장 유무, 모달과 기능 연결은 기존 StartScreen이 담당한다.

검증:

- `--start-screen-smoke` PASS: 슬롯, 새 게임, 첫 실행, 설정, 언어, 키, 포커스와 큰 글자 회귀.
- `start_screen_scene_edit_smoke.tscn`은 루트 런타임 스크립트 없이 씬을 렌더링한다. Inspector에 해당하는 위치/크기/색상 변경을 실제 PackedScene으로 저장하고 다시 로드해 실행 중 유지되는지 확인한다. 중복 노드, 시차 시 메뉴 영역 고정, 정적 설정 복원과 200% 확대도 검사한다.
- 런타임 없이 렌더링한 기본 한국어 씬과 정상 실행 한국어 화면의 RGB 픽셀이 일치했다. 영어 화면도 확인했다.

증거: `outputs/title-scene-2026-10-23/`. 테스트 프로필과 APPDATA는 이 폴더 안에 격리한다. 내부 프로젝트 이름과 플레이 저장 경로는 변경하지 않는다.
