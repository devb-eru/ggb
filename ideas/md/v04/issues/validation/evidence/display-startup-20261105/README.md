# 초기 디스플레이 잘림 검증 근거

검증 ID `DISPLAY-STARTUP-20261105`, 관련 이슈 ERR-0078.

## 실행 구분

| 구분 | 조건 | 결과 |
| --- | --- | --- |
| 정식 원본 대조 | 정상 main 시작, 기본 borderless 프로필 | native 1, 70확인 중 창 모드·native 모드·원점·화면 경계 4실패 |
| 최종 후보 | 기본 프로필 | native 0, 150확인 PASS |
| 최종 후보 | 저장된 windowed 1280×720 | native 0, 154확인 PASS |
| 최종 후보 | 저장된 borderless | native 0, 152확인 PASS |
| 최종 후보 | 저장된 fullscreen | native 0, 152확인 PASS |
| 최종 후보 | 기본 프로필 + CLI 강제 창·해상도·위치 | native 0, 150확인 PASS |

최종 native 성공은 5조건/758확인이다. 기준 실패와 성공을 합산하지 않는다. Godot 4.6.3 후보, native Windows renderer, 단일 `2560×1600` 화면에서 확인했다. 전편 OS 입력·모든 모니터/DPI 조합·엔진 정식 채택의 증거가 아니다.

`game/scripts/tests/display_startup_smoke.gd`를 격리 사본의 마지막 autoload로만 등록하고 정상 `run/main_scene`을 실행했다. 테스트는 `--display-startup-smoke`가 없으면 아무 설정도 준비하지 않는다. 프로필은 별도 APPDATA 안에 준비하고 실제 StartScreen `_ready()`가 첫 process frame보다 먼저 실행됐는지 확인한다. 테스트에서 창 모드나 위치를 직접 보정하지 않는다.

후보의 HUD 검사는 시작 창 검사를 통과한 다음 실제 controller를 직접 구성해 inventory 6칸·읽기 영역·대화기록·메뉴의 경계를 검사한다. 개발 체크포인트와 직접 presentation 설정을 사용한 **geometry 검사이며 OS 입력 완주가 아니다**.

## 실제 화면 비교

`windows-ui/`의 원본/수정 후 PNG는 실제 격리 게임을 관찰한 캡처다. 원래 자연 마우스 진행의 P2/P3 완료 슬롯을 별도 APPDATA로 복사했다. 수정 후에는 진단 스크립트 없는 정상 실행에서 실제 마우스로 이어하기를 눌러 인벤토리 6칸과 하단 수첩·대화기록 버튼이 모두 표시됨을 확인했다. 실제 사용자 세이브는 사용하지 않았다.

실제 화면 비교의 기존 GUI 소스는 `c4abc09e`의 307스크립트/63data이며 수정은 startup 한 파일이다. 후속 native 회귀의 소스는 ERR-0077 수정과 검사들을 포함한 311스크립트/63data다. 동일 소스의 전편 실제 입력으로 혼동하지 않는다.

읽기 전용 probe는 창 크기·모드·위치·뷰포트와 UI 경계만 측정한다. 원본은 native 크기인 창이 windowed mode와 잘못된 위치에 남았고, 후보는 fullscreen mode 3·화면 원점에 위치했다. UI 전역 좌표나 아트를 이동하는 방식은 사용하지 않았다.

## 원자료 구성

`raw.zip`과 `manifest.json`은 최종 native 6실행(기준 1+후보 5)의 영수증·결과·로그·runner·소스 ZIP, 초기 검사 진단, 별도 headless 회귀, 실제 화면 캡처·측정값을 구분한다. 전체 사용자 프로필·사용자 세이브·외부 앱 알림은 포함하지 않는다.

초기 검사 이력도 삭제하지 않는다. 최초 SceneTree 검사는 current_scene 준비 전 검사와 native 창 생성 전 조회로 실패했다. 대기 교정 뒤에는 SceneTree 자체가 정상 main의 시작 타이밍을 바꿔 원래 결함을 재현하지 못함을 확인했다. 정상 main과 관찰용 autoload 방식으로 바꾼 뒤 원본의 4실패를 확인했다. 저장 프로필의 JSON 정수/실수 표현을 엄격 Dictionary 비교한 오판도 정상 값 검증과 정수 변환으로 교정했다. 이전 기본 후보 성공은 최신 5조건에 중복 합산하지 않는다.

소스 복사가 끝나기 전 실행한 GUI 시도는 preload 누락으로 폐기했다. 복사 완료·startup 한 파일의 변경을 확인한 후 새 프로세스로 재실행했다. 해당 폐기 시도는 성공 근거에 포함하지 않는다.

별도 headless 시작 화면 및 전체 캠페인 회귀는 각각 native 0, `START_SCREEN_SMOKE: PASS` / `FULL_CAMPAIGN_SMOKE: PASS`다. 이 두 실행은 OS 입력으로 세지 않는다. 원자료는 76파일이며 독립 감사에서 최종 native 6실행·관련 headless 2실행·311스크립트/63data 지문을 대조해 PASS했다. 제품 엔진 기대값 4.7과 후보 4.6.3의 경고는 그대로 보존한다.

## 독립 감사

```powershell
& ./scripts/audit_display_startup.ps1 `
  -EvidencePath ./ideas/md/v04/issues/validation/evidence/display-startup-20261105 `
  -RepoPath .
```

명령은 저장소 루트 기준이다. 현재 source/data가 manifest의 311/63 지문과 정확히 같아야 한다. 이후 개발본에 다른 변경이 생기면 과거 manifest를 최신 소스 검증으로 사용하지 않는다.

감사는 raw 파일·ZIP·로그 지문, native 시작 순서, 기준 실패와 startup 한 파일만의 차이, 후보 모드·geometry·CLI 조건, 각 소스 ZIP의 311스크립트, headless 관련 회귀를 대조한다. 감사 자체는 게임 재실행이나 OS 입력이 아니다. 소스 ZIP은 코드 재구성용이며 모든 아트/전체 프로젝트가 포함된 재실행 패키지는 아니다.
