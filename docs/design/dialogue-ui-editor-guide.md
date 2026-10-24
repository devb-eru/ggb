# 대화창을 Godot 화면에서 수정하기

## 여는 방법

1. Godot에서 `game/project.godot` 프로젝트를 연다.
2. FileSystem에서 `res://scenes/ui/dialogue_hud.tscn`을 더블 클릭한다.
3. 상단 **2D**를 선택한다. 샘플 배경·주인공·대사가 이미 배치되어 있다.
4. 왼쪽 Scene 트리에서 바꿀 노드를 선택하고 화면에서 옮기거나 오른쪽 Inspector 값을 조절한다.
5. **Ctrl+S**로 저장한다. **F6**은 이 씬의 정적인 디자인 미리보기, **F5**는 실제 게임 동작 확인이다.

이 씬은 프롤로그와 이후 챕터가 공통으로 사용한다. 씬에서 저장한 위치·크기·색·폰트가 실제 게임에도 적용된다. 샘플 대사와 캐릭터 텍스처는 실제 플레이 때 현재 대사·인물로 교체된다. PreviewBackground는 디자인용 배경이며 게임에서는 실제 방 배경을 사용한다. 오른쪽 192 영역은 게임의 인벤토리 자리다.

## 어떤 노드를 수정하나요?

선택지 창은 `res://scenes/ui/choice_window.tscn`을 따로 열어 편집할 수 있다. 독립 씬에서는 기본으로 표시되며, 대화창에서는 선택할 때만 나타난다. 이 파일이 `dialogue_hud.tscn`에 인스턴스로 연결되어 실제 게임에도 반영된다.

선택지 씬의 루트 `DialogueChoicePanel`에서 전체 위치·크기·배경(Theme Overrides → Styles → panel), `Margin`에서 안쪽 여백, `Margin/Choices`에서 버튼 간격(separation), `DialogueChoice1~3`에서 글꼴·색·버튼 높이·스타일을 편집한다. 샘플 문구는 게임에서 실제 선택지로 바뀐다. 선택지 노드의 이름과 경로는 유지한다.

선택지 배경은 `res://assets/ui/dialogue_editor/choice_window_theme.tres`에서 편집한다. `DialogueChoiceSelectedButton`은 마름모가 있는 원본, `DialogueChoiceButton`은 마름모가 없는 원본을 사용한다. 왼쪽 글자 여백은 모든 상태에서 104로 동일하다. 루트의 `Preview Selected Index`를 0~2로 바꾸면 에디터에서 선택 상태를 미리 볼 수 있다. 게임에서는 마우스·키보드 포커스와 현재 선택 인덱스가 이 상태를 결정한다. 별도 `▶` 문자는 붙이지 않는다.

| 노드 | 바꿀 수 있는 것 |
| --- | --- |
| `StandingPortrait` | 캐릭터 위치·크기. Layout의 Offset 또는 Transform으로 조절한다. |
| `DialogueBacking` | 이름과 본문 전체 위치·너비·높이. 화면에서 이 그룹을 옮긴다. |
| `DialogueBacking/Margin` | 글자 영역 안쪽 여백. Theme Overrides → Constants → margin 항목. |
| `DialogueBacking/Margin/Body` | 이름과 본문 사이 간격. Theme Overrides → Constants → separation. |
| `…/Body/SpeakerLabel` | 이름의 폰트·크기·색. Theme Overrides → Fonts / Font Sizes / Colors. |
| `…/Body/DialogueScroll/DialogueText` | 본문의 폰트·크기·색. Theme Overrides에서 조절한다. |
| `DialogueOrnament` | 하단 장식 이미지·위치·크기·불투명도. CanvasItem → Visibility → Self Modulate의 A가 불투명도다. 현재 0.8. |
| `DialogueReadability` | 검은 그라데이션의 영역·진하기. Texture의 Gradient 리소스를 펼쳐 색과 알파를 바꾼다. |
| `SpeakerNameplateArt` | 이름의 마름모·금색 선 이미지와 위치·크기. |
| `DialogueHistory` | 대화기록 버튼의 위치·크기·폰트·색. |
| `NotebookButton` | 수첩 버튼의 위치·크기·아이콘·글꼴·프레임. |
| `MenuButton` | 상단 메뉴 버튼의 위치·크기·아이콘·글꼴·프레임. |
| `MenuButton/IconDivider` | 메뉴 버튼 안의 아이콘과 글자 사이 구분선. |
| `LocationLabel` | 현재 지역명의 위치·크기·글꼴·색. 샘플 문구는 게임에서 실제 지역명으로 바뀐다. |
| `LocationDivider` | 메뉴 버튼과 현재 지역명 사이 구분선의 위치·크기·색. |
| `DialogueChoicePanel` | 선택지 전체 위치·너비. Scene 트리의 눈 아이콘으로 표시한 뒤 편집한다. |
| `…/Choices/DialogueChoice1~3` | 선택지의 최소 높이·글꼴·배경 스타일. |

이름과 본문은 Container 안에 있어 개별 위치를 드래그하는 대신 `DialogueBacking`을 옮기거나 `Margin`과 `Body` 간격을 조절한다. 배경·캐릭터·이름 장식·버튼은 개별 Control 노드로 배치할 수 있다.

버튼 프레임을 바꾸려면 Theme Overrides → Styles에 StyleBox 리소스를 지정한다. 기본 버튼 디자인은 `res://assets/ui/dialogue_editor/dialogue_theme.tres`에도 있다. 여러 버튼에 공통으로 적용하고 싶으면 이 Theme를 편집한다.

상단 메뉴·지역명·구분선은 대화가 닫힌 탐색 화면에도 유지된다. 게임 코드는 메뉴의 동작과 번역, 실제 지역명만 연결한다. 이 노드들의 배치·글꼴·색·아이콘·스타일을 실행 중에 다시 지정하지 않는다.

## 큰 글자와 화면 크기

앵커가 창 크기에 따라 배치를 유지한다. 가능하면 기존 Anchors를 유지하며 Offsets/Size를 조절한다. 본문은 긴 문장을 스크롤할 수 있고, 보이지 않는 진행 클릭 영역은 본문 영역을 자동으로 따라간다. `DialogueNext`는 별도로 디자인할 필요가 없다.

루트 `DialogueLayer`의 Inspector → **Reading accessibility**에는 다음 항목이 있다.

- **Enlarged Reading Extra Height**: 글자 200%일 때 대화창을 위로 확장할 양.
- **Align Name Rule To Speaker**: 큰 글자에서 이름 아래 장식선의 자동 정렬. 기본 글자 크기에서는 씬에서 배치한 위치를 유지한다.
- **Name Rule Gap**: 큰 글자 자동 정렬 때 이름과 장식선 사이 간격.
- **Scrollbar Click Clearance**: 본문 클릭 영역 오른쪽에 남기는 스크롤바 조작 공간.

글자 크기는 씬에서 정한 값을 기준으로 확대하므로 기본 크기를 바꿔도 접근성 설정이 그 새 크기를 따른다.

## 편집 시 유지할 것

스크립트가 찾는 노드 이름·트리 경로는 유지한다. 디자인 수정에는 이름 변경이 필요하지 않다. 실제 대사 내용은 게임 데이터에서 정하므로 이 씬의 샘플 문구만 바꿔도 실제 이야기 대사가 바뀌지는 않는다.

## 검증 기록

- `dialogue_scene_edit_smoke.tscn`: Inspector에 해당하는 속성을 수정하고 씬 파일로 저장·재로드한 뒤 게임에 연결했다. 폰트·색·위치·불투명도 적용, 100%→200%→100% 복원, 이동한 본문과 클릭 영역 일치를 확인했다. 오류 0.
- 2026-10-24 상단 HUD 확장 검사: 메뉴와 지역명·구분선의 위치·크기·글꼴·색·스타일·아이콘 변경을 씬에 저장하고 재로드했다. 프롤로그와 세 챕터에서 수정값 보존, 실제 지역명 표시, 대화 종료 후 상단 HUD 유지, 메뉴 열기와 Escape 동작을 확인했다. 증거는 `outputs/top-hud-scene-2026-10-24/`에 있다.
- `dialogue_hud_audit.tscn`: 실제 클릭·Enter·H·기록 버튼, 대사 복귀, 창 크기 변경, 큰 글자 검사 통과.
- `--prologue-smoke`: 268개 검사 PASS.

증거 캡처와 로그는 `outputs/dialogue-scene-editor/`에 있다. 검사는 격리된 APPDATA에서 실행했다.
