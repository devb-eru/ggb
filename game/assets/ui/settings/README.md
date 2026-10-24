# 설정 UI 에셋

`docs/design/gui-ux-2026-10-20/images/15-settings-accessibility-v1.png`부터 `19-settings-language-v1.png`까지의 승인 시안을 위한 공통 부품이다. 1920×1080 화면에서 사용한다.

## 이미지

| ID | 용도 | 표시 크기 기준 |
| --- | --- | --- |
| settings_paper | 설정 전용 종이·리본·아래쪽 토끼 장식 | 1580×940 |
| bookmark_normal | 왼쪽 책갈피 기본 상태 | 240×92 |
| bookmark_selected | 왼쪽 책갈피 선택 상태 | 240×92 |
| field_frame | 입력칸·선택칸·언어 행의 투명 테두리 | 480×64 |
| field_selected | 선택한 옵션의 보라색 바탕 | 180×64 |
| keycap | 키 배정 버튼의 빈 바탕 | 150×64 |
| preview_paper | 접근성·언어 미리보기 종이 | 500×440 |
| confirmation_paper | 화면 설정 유지 확인창 바탕 | 660×260 |
| slider_grabber | 음량 슬라이더 손잡이 | 38×38 |
| display_preview | 화면 크기 예시용 삽화 | 440×180 |

10개 PNG 모두 글자를 포함하지 않는다. 내장 image_gen으로 제작했고 원본은 그대로 보존했다. 파일별 생성 프롬프트와 참조 경로는 `manifest.json` 및 `*.receipt.json`에 있다.

`textures/`의 AtlasTexture는 낮은 알파의 잔여 여백을 제외한 영역을 참조한다(알파 16 초과 영역 + 2px). `TextureRect`에서 `expand_mode = EXPAND_IGNORE_SIZE`로 지정하고 필요한 표시 크기로 사용한다. PNG 원본 크기는 UI 표시 크기와 다르다.

## 공통 에셋 재사용

`menu_background`, `primary_button`, `ink_divider`, `close_icon`은 `../save_load/textures/`의 기존 정의와 같은 원본 PNG를 참조한다. 중첩 AtlasTexture를 만들지 않고 작은 리소스 정의만 복사했다. 저장 경로를 바꿀 때 공통 PNG 의존성을 함께 유지한다. 배경 PNG 자체는 `../design_2026_10/`에 있다.

## Godot 리소스

`themes/bookmark.tres`, `option.tres`, `keycap.tres`, `primary.tres`를 각각 Button의 Theme에 지정한다. 기본·호버·선택(pressed)·선택 호버·비활성·키보드 포커스가 정의되어 있다. 선택형 버튼은 `toggle_mode = true` 및 ButtonGroup으로 관리한다. 책갈피 문구는 왼쪽 문양을 피해서 오른쪽 영역에 배치한다.

테마는 전체 텍스처를 표시 크기에 맞춰 늘리는 방식이다. 소스 픽셀 기준의 큰 9-slice 마진을 설정하지 않았다. 표의 기준 크기와 검증 렌더의 범위에서 쓰며, 매우 좁은 버튼에 긴 문구를 넣을 때에는 버튼 폭을 먼저 늘린다.

`styles/slider_track.tres`, `slider_fill.tres`는 길이가 바뀌는 선을 위한 StyleBoxFlat이다. 선 높이 8px, 손잡이 38px를 기준으로 사용한다. 손잡이는 TextureRect 또는 CanvasItem.draw_texture_rect로 표시 크기를 지정한다. 고해상도 원본을 HSlider의 grabber 아이콘에 크기 조정 없이 바로 넣지 않는다. 선의 비율과 손잡이 위치는 같은 0–1 값으로 갱신한다.

`styles/radio_unchecked.tres`, `radio_checked.tres`는 32×32 원형 선택 표시다. `styles/focus.tres`는 포커스 외곽선이다. 모두 Godot 기본 도형이며 별도 래스터 이미지를 필요로 하지 않는다.

글자·현재 수치·단축키 이름·방향 화살표·선택기 꺾쇠는 게임의 폰트로 표시한다. 창 뒤를 어둡게 하는 막은 ColorRect 색상 `(0.04, 0.03, 0.12, 0.23)`을 사용한다. 이 값이나 텍스트를 PNG에 구워 넣지 않는다.

## 화면별 구성

| 화면 | 사용하는 전용 부품 |
| --- | --- |
| 접근성 | 옵션 테마, 미리보기 종이, 동적 글자·선택값 |
| 화면 | 옵션 테마, 창 크기 삽화, 확인창 종이, 어두운 막 |
| 소리 | 슬라이더 선·채움·손잡이, 음소거 옵션 |
| 조작 | 키 버튼 테마, 선택된 키의 옵션 바탕, 방향키 글자 |
| 언어 | 언어 행 옵션 바탕, 선택 원, 미리보기 종이 |

모든 화면에 배경·설정 종이·책갈피·구분선·닫기·적용 버튼을 공통 사용한다. 따라서 카테고리마다 중복 PNG가 필요하지 않다.

## 검증

검증 스크립트와 결과는 프로젝트 루트의 `outputs/settings-assets/`에 있다. PNG 알파/해시 검사, Godot 임포트·리소스 로드 검사, 1920×1080 조합 렌더 다섯 장으로 검증한다. 조합 렌더는 에셋 배치 검증용이며 실제 설정 저장 로직이나 기존 설정 화면을 교체하지 않는다. 예시 글꼴은 시스템 바탕체로 배포 폰트에 포함되지 않는다.

Godot 4.7.2에서 14개 텍스처, 테마의 24개 상태, 25개 StyleBox 로드를 통과했다. 신규 PNG 10개는 모두 무손실·straight alpha로 임포트되었다. 에디터 임포트 작업 자체는 완료됐지만 해당 프로세스의 종료 대기가 60초 제한에 걸렸다. 이후 실제 프로젝트에서 실행한 별도 로드 검사와 OpenGL 조합 렌더는 오류 없이 종료 코드 0으로 완료됐다.

조합 렌더: `accessibility-preview.png`, `display-preview.png`, `audio-preview.png`, `controls-preview.png`, `language-preview.png`. 각 이미지에서 글자와 그림을 겹쳐 최종 표시 크기를 확인했다.
