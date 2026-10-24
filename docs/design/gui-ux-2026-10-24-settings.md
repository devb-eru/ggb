# 설정 화면 편집 · 2026-10-24

Godot에서 `res://scenes/ui/settings/settings_screen.tscn`을 열면 설정 전체를 편집할 수 있다. 타이틀·첫 실행·프롤로그·이후 챕터가 이 씬을 사용한다. F6으로 실제 설정 동작을 확인할 수 있다.

타이틀과 첫 실행에서는 이 씬의 `Surface/Background`를 인스턴스에서 숨겨 기존 메인 배경과 움직이는 캐릭터 위에 창을 띄운다. 종이 크기는 유지한다. 편집 위치는 [타이틀 위의 창](gui-ux-2026-10-24-title-popups.md)에 정리했다.

| 편집 대상 | 파일 / 노드 |
| --- | --- |
| 공통 배경·종이 | `settings_screen.tscn` → `Surface/Background`, `Surface/Paper` |
| 제목·책갈피·하단 버튼 | `Surface/Title`, `Category`, `Tabs`, `Defaults`, `Back`, `Apply`, `Close` |
| 접근성 | `accessibility.tscn` → `Fields`, `Preview` |
| 화면 | `display.tscn` → `Fields/Mode`, `Fields/Resolution`, `Illustration` |
| 소리 | `audio.tscn` → `Master`, `Bgm`, `Ambience`, `Effects`, `Mute` |
| 조작 | `controls.tscn` → `Left`, `Right` 및 각 `Keys/Key_…` 버튼 |
| 언어 | `language.tscn` → `Languages`, `Preview` |
| 화면 변경 확인창 | `display_confirmation.tscn` → `Center/Paper`, `Margin/Body` |

페이지는 전체 씬의 `Surface/ContentScroll/Pages`에 인스턴스로 배치했다. 페이지 파일을 따로 열거나 전체 씬에서 Editable Children으로 수정할 수 있다. 모든 글자·선택칸·키 버튼·음량 슬라이더·선택 원은 Godot 기본 노드다. 제공된 이미지는 프레임과 장식으로 사용한다.

Container 안의 행 간격과 정렬은 Theme Overrides의 separation, Custom Minimum Size, Size Flags로 조절한다. 공통 종이·버튼의 위치는 Anchors와 Offsets로 조절한다. 기본 폰트는 `assets/ui/settings/themes/settings_font.tres`이며 개별 노드의 Theme Overrides에서 크기·색·스타일을 바꿀 수 있다.

씬에서 정한 글자 크기와 최소 크기를 기준으로 접근성 확대를 적용한다. 긴 항목은 줄바꿈하고, 열이 함께 들어가지 않으면 다음 줄로 배치하며, 페이지 영역은 세로로 스크롤한다. 상단 제목·페이지 제목·하단 버튼은 최대 130%까지, 책갈피 문구는 기본 크기로 유지한다. 선택값·수치·키 이름·실제 미리보기 문구와 번역은 실행 중 갱신한다. 레이아웃과 스타일을 코드에서 다시 생성하지 않는다.

## 적용 동작

- 접근성·소리·조작은 변경 즉시 프로필에 저장하고 실행 중인 화면·음량·키 배정에 적용한다. 이 페이지에는 적용 버튼을 표시하지 않는다.
- 화면과 언어에는 적용 버튼이 있다. 두 페이지의 미적용 선택은 탭 이동 중 유지하고 설정을 닫으면 취소한다. 다른 페이지의 즉시 저장으로 미적용 값을 함께 저장하지 않는다.
- 화면 변경은 기존 15초 미리보기 트랜잭션을 사용한다. ‘유지’를 눌러야 저장되며, 시간 초과·되돌리기·화면 닫기에는 이전 화면으로 복구한다. 확인창이 열려 있는 동안 포커스와 마우스 입력은 확인창 안에 제한한다.
- 키 배정은 중복·지원하지 않는 키를 거부한다. Enter와 Space의 두 배정은 각각 변경할 수 있다. 저장 실패 시 이전 키 배정과 실제 InputMap을 유지한다.
- 기본값은 현재 페이지에 적용한다. 접근성·소리·조작의 기본값도 즉시 저장되며 화면 기본값은 적용·유지 확인을 거친다.
- 첫 실행에서는 같은 디자인의 접근성 화면을 새 게임 슬롯 선택보다 먼저 표시한다. 설정 변경은 즉시 적용되며, ‘시작하기’를 눌렀을 때 첫 설정을 마치고 슬롯 화면으로 넘어간다.
- 게임에서 언어를 바꾼 뒤 타이틀로 돌아오면 저장된 언어를 반영한다. 플레이 진행 데이터는 변경하지 않는다.

## 확인

`settings_ui_smoke.tscn`은 실제 마우스·키 입력, 즉시 저장, 키 중복 거부, 언어의 미적용 상태, 화면 미리보기 유지·시간 초과·저장 실패 복구, 첫 실행 순서, 프롤로그와 세 챕터의 메뉴 연결을 검사한다. 다섯 페이지의 편집값을 PackedScene으로 저장·재로드한 뒤 실행 중 유지되는지도 확인한다. 200% 영어 화면의 실제 자식 컨트롤 경계와 확인창 경계도 검사한다.

기존 `START_SCREEN_SMOKE`, `PROLOGUE_SCENE_SMOKE` 268개 검사와 `APPLICATION_FOCUS_SMOKE`를 통과했다. 프로필·저장·스크린샷·로그는 `outputs/settings-ui-2026-10-24/` 아래의 격리된 APPDATA에서 생성한다. 동시에 실행한 검사에서는 기존 MCP Runtime 포트 7777 경고가 별도로 기록되어 있다.

`scripts/prepare_settings_scenes.py`는 최초 씬 배치를 재생성하는 제작용 스크립트다. Inspector에서 수정한 뒤에는 실행하지 않는다. 정상 게임 실행과 편집에는 필요하지 않다.
