# 수첩 씬 편집 · 2026-11-15

수첩의 고정 UI를 `game/scenes/ui/notebook/`의 Godot 씬으로 분리했다. 실제 플레이와 감상 기록 수첩이 같은 씬을 사용한다. `.tscn`에 저장한 배치·스타일·폰트는 기본값으로 사용하고, 실행 중에는 공개된 기록·선택 상태·번역을 갱신한다.

| 편집 대상 | 파일 / 노드 |
| --- | --- |
| 수첩 전체·책갈피·검색·자료 및 비교 영역 | `notebook_panel.tscn` |
| 펼친 책·작은 화면의 종이 | `notebook_panel.tscn` → `NotebookArtwork/BookOpen`, `BookCompact` |
| 책의 위치·여백 | `NotebookArtwork`의 Margin Overrides |
| 왼쪽 책갈피 | `NotebookLeftBookmarks` 및 `NotebookTab_…` |
| 검색·상단 도구 | `NotebookSearch`, `NotebookToolsScroll` |
| 필터·대화 묶음·인물 및 조사 자료 탐색 | `notebook_browser.tscn` |
| 기록된 시각 자료의 확대·이동·되돌아가기 | `notebook_visual_viewer.tscn` |
| 전체 화면 배경·바깥 여백·준비 화면 | `notebook_overlay.tscn` → `Background`, `Margin`, `Margin/NotebookLoading` |
| 동적 목록 행·액션 버튼 | `notebook_record_row.tscn`, `notebook_action.tscn` |
| 실제 자료의 제목·장소·설명·보조 텍스트·그림 | `notebook_material.tscn` → `Field_…`, `NotebookMaterialBody`, `NotebookVisualPreview`, `VisualDescription` |
| 자료 본문·검색 일치 문단 | `notebook_paragraph.tscn`, `notebook_search_paragraph.tscn` |
| 탐색 화면의 동적 항목·분류 제목 | `notebook_browse_item.tscn`, `notebook_browse_label.tscn` |
| 공통 테마 | `game/assets/ui/notebook/themes/notebook.tres` |

수첩 전체를 보려면 `notebook_panel.tscn`을 연다. 게임과 동일한 전체 화면 합성은 `notebook_overlay.tscn`에서 볼 수 있다. Container 안의 간격은 Theme Overrides의 Separation, 크기는 Custom Minimum Size와 Size Flags로 바꾼다. 폰트 크기·색·버튼 스타일은 개별 노드의 Theme Overrides에서 조절한다. 접근성 확대는 저장된 글자 크기를 기준으로 적용한다.

자료 상세와 A/B 비교는 모두 `notebook_material.tscn`을 실제 렌더링에 사용한다. 제목은 `Field_title`, 장소는 `Field_location_label`, 자료 유형은 `Field_source_label`, 요약은 `Field_summary`, 화자는 `Field_speaker`에서 편집한다. 검색 중에 표시할 대응 글자는 같은 이름의 `FieldSearch_…` RichTextLabel에서 편집한다. `NotebookMaterialBody`의 문단은 획득한 원문으로 교체한다. 수첩 루트 Inspector의 `Material Scene`에 별도 PackedScene을 지정하면 실제 자료와 비교 양쪽에 그 씬을 적용한다.

자료 목록·본문·검색 일치·비교 내용은 저장된 플레이 기록에 따라 달라진다. 편집기와 F6 미리보기에는 제목·설명·장소 같은 예시를 표시하고, 실제 `present()`가 호출되면 획득한 기록으로 교체한다. 미리보기 예시는 플레이 기록으로 저장하지 않는다. 필터와 확대 화면도 같은 고정 노드를 재사용하며, 기록을 바꾸거나 화면을 다시 열어도 편집한 고정 버튼을 새로 생성하지 않는다.

현재 문장형 표식의 콘텐츠 버전 3에 정의된 `self_mark_v2` 그림도 표시한다. 그림은 관찰 기록에 저장된 콘텐츠 버전의 정의에서 읽으며, 과거 버전 2 기록을 새 문구나 그림으로 바꾸지 않는다. 씬 편집과 기록 열람은 게임 진행이나 표식의 판정을 변경하지 않는다.

`game/scripts/tests/notebook_scene_edit_smoke.tscn`은 런타임 스크립트 없이 씬을 렌더링하고, Inspector 방식의 실제 편집을 PackedScene으로 저장·다시 불러와 글자·간격·아트와 상대 확대가 유지되는지 확인한다. 기존 공개 기록 모델로 탭·검색·자료·비교·필터·확대 연결 및 기존 `.new()` 호출 호환성도 검사한다. 캡처와 보고서의 위치는 `outputs/notebook-scenes-2026-11-15/`이다.

F6 방식으로 실행한 예시 기록, 실제 모델로 교체된 자료, 편집된 200% 화면, 필터와 확대 화면의 캡처를 남긴다. 자료 씬을 실제로 수정·저장하고 수첩의 `Material Scene`에 지정한 뒤 제목 폰트·간격·시각 자료 높이가 실제 상세와 비교에서 유지되는지도 확인한다. 프로필과 저장 경로는 이 출력 폴더 아래의 별도 APPDATA로 격리한다.

GUI 검증 결과는 91개 검사 통과다. 자료 제목을 37px로 편집·저장한 뒤 실제 상세와 비교에서 유지되고, 200%에서 74px, 100%에서 다시 37px로 적용되는 것을 확인했다. 자료 씬의 간격 18과 시각 자료 미리보기 최소 높이 234도 실제 기록 화면에 반영됐다. F6 미리보기의 장 선택기에도 `장: 전체`가 표시된다. 동시 실행된 기존 MCP Runtime의 포트 7777 충돌 메시지는 UI 검증과 별도로 기록됐다.

`--notebook-host-smoke`는 550개 검사를 통과했다. 최신 EP01 대사 흐름을 실제 확인 입력으로 진행한 뒤 선택창·숨기 타이머를 검사하고, 편집된 닫기 버튼의 실제 위치에서 겹침 입력 방지를 검사한다. `notebook_self_mark_smoke.gd`의 288개 검사는 현재 문장 v3의 도안과 과거 v1/v2 기록 보존, 수면 후 A2의 출처 연결 및 저장 복원을 확인한다.

최종 `--notebook-query-smoke`도 통과했다. 읽기 모델 6,931개 검사와 하위 열람 위치·필터·확대·검색·조사·보존·표식·감상 기록 검사를 통과했고, 별도로 콘텐츠 메타데이터 76,442개 검사도 통과했다. 최종 로그는 출력 폴더의 `query-verified.log`, `host-verified.log`이다.

`prepare_notebook_scene_resources.gd`는 기존 이미지 테마를 최초 추출하는 제작용 스크립트이며, 정상 게임 실행에는 사용하지 않는다.
