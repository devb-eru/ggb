# 통합 수첩 성능 계측 및 1차 개선

기준 develop `e6100a8`, 2026-10-04. [NB-P17 계획](../ideas/md/v04/issues/validation/notebook_history_review_plan.md#17-성능과-접근성-측정-계약-nb-p17)의 계측 기반을 추가하고 실제 병목 일부를 수정했다. **탐색 계측이며 성능 인수 PASS가 아니다.** [ERR-0027](../ideas/md/v04/issues/items/GGB-ERR-2026-0027_대용량_수첩_표시검색저장_지연.md)은 IN_PROGRESS다.

## 1. 범위와 재현

- 실행기: [measure_notebook_performance.ps1](../scripts/measure_notebook_performance.ps1). Godot debug PCK의 `--notebook-performance-probe --ggb-dev-notebook-v2` 진입점을 사용한다.
- 시험 자료: [fixture](../game/scripts/tests/notebook_performance_fixture.gd), 측정 경계: [probe](../game/scripts/tests/notebook_performance_probe.gd).
- 이번 실행은 네 fixture × 한영 × cold 1회, 각 프로세스에서 warm 3회다. 변경 전후 각각 8개 프로세스가 기능 검사를 통과했다. cold 20회/warm 100회 조건은 아직 충족하지 않았다.
- Windows 10.0.26200, Intel Core i7-12700H, 논리 스레드 20개, Godot 4.7.2 stable Steam, headless. GPU/드라이버/RAM/SSD 실사와 LOW/MID 등급 분류는 하지 않았다. CPU 전력·온도를 고정한 반복 실험도 아니다.
- 각 프로세스는 빈 실행 폴더와 별도 APPDATA/LOCALAPPDATA를 사용한다. 실제 사용자 슬롯을 열거나 fixture를 GameState에 설치하지 않는다. 자체 시험 슬롯만 생성·검증·삭제한다.
- 원시 시간 배열, fixture 해시, 본문 바이트 수, 실행기 해시와 프로세스 peak는 [보관 원자료](evidence/notebook_performance_trial_20261004.json)에 있다. 기존 사용자 변경 씬·리소스·플러그인은 검증용 PCK에 합치지 않았다.

```powershell
# 프로젝트 루트에서, 별도로 export한 debug PCK와 Godot 실행 파일 지정
./scripts/measure_notebook_performance.ps1 `
  -GodotPath 'C:/path/to/godot.exe' `
  -PackPath 'C:/path/to/notebook.pck' `
  -OutputDirectory 'C:/path/to/new-empty-output' `
  -ColdRuns 1 -WarmRuns 3
# 정식 표본 수는 -ColdRuns 20 -WarmRuns 100 (기본값).
# 이 수를 충족해도 headless 계측만으로 실제 입력/시각/장비 인수는 완료되지 않는다.
```

실행기는 기존 결과가 들어 있는 폴더를 거부한다. 매번 새로운 OS 프로세스를 만들지만 OS 디스크 캐시는 비우지 않는다. p95는 `ceil(0.95*n)`번째 값이며 20개/100개 자체 검산을 포함한다. 적은 표본에도 수학적 통계값은 기록하되 이를 인수용 p95로 해석하지 않는다. `sampling_complete`는 요청한 표본 수의 충족 여부이고 `acceptance`는 항상 `MEASUREMENT_ONLY`다.

## 2. 고정 시험 자료

고정 seed는 `ggb-notebook-perf-v1`이다. UID·분기·출처·관찰 토큰도 결정적이며 두 언어와 변경 전후에서 입력 해시가 일치했다. 일반 대사 보존 상한은 여전히 2,000개다.

| fixture | normal / protected / legacy | 정규 JSON UTF-8 바이트 | 부가 조건 |
| --- | --- | ---: | --- |
| N2000 | 2,000 / 6 / 0 | 1,815,265 | 실제 공개 선택지·선택·H1·B4/C5/D4 관찰 6개 추가 |
| L10000 | 2,000 / 6 / 10,000 | 5,434,278 | 한영 원문이 교대로 있는 기존 미분류 기록 |
| P2001 | 2,001 / 2,001 / 0 | 3,692,933 | 잘라내기 직전 부하; 책갈피 50개, 비교 묶음 12개 |
| LONG | 1,980 / 26 / 0 | 2,472,815 | 일반 20개를 보호 문서 20개로 대체, 공통 관찰 6개 유지 |

LONG 문서는 각각 공개 앞/뒤 페이지 본문 합계 32,768 UTF-8 바이트다. 페이지 연결 구분자는 이 크기에 포함하지 않는다. 한영 제목/접두문 뒤 ASCII 반복문으로 바이트 수를 맞춘 **합성 부하**다. 실제 장문 원고의 줄바꿈 특성이나 200% 배치 인수를 대신하지 않는다. 미공개 세 번째 페이지의 sentinel과 요청하지 않은 H2~H5 본문은 검색에서 배제한다. 시험용 문서 정의는 해당 프로세스 메모리에만 추가하며 출시 카탈로그는 수정하지 않는다.

지식 ledger는 비어 있다. B4/C5/D4는 공개 관찰·비교 참조이지 수천 개의 획득 revision을 가진 지식 그래프 부하가 아니다. 후자의 병목과 비어 있지 않은 ledger의 최악 비용은 별도 시험해야 한다.

## 3. 측정 경계

| 지표 | 포함 | 제외 / 해석 주의 |
| --- | --- | --- |
| fixture build/parse | 결정적 생성과 JSON 파싱, 각각 별도 시간 | 수첩 열기 시간에 생성 비용을 합산하지 않음 |
| query open | 검증·복제·메타 모델 생성 | 실제 수첩 입력 전후 전체 호스트 작업 아님 |
| model→panel | query open부터 첫 50행과 headless 프레임 두 번·유효 포커스까지 | 실제 OS 입력/화면 표시 지연 아님 |
| first search UI | 실제 패널의 text_changed 신호, 200ms debounce, 점진 색인, 결과 갱신 | 한영 IME 조작과 OS 입력은 실행하지 않음 |
| warm page/facets/search | 모델 호출, 일치/불일치/숨은 페이지/긴 문서 키워드 | 입력·debounce·패널 재배치 제외 |
| two materials | 비교 묶음에서 두 자료만 상세 조회 | 실제 이미지 GPU 업로드/키보드 자료 교체 아님 |
| append/prune | 새 일반 관찰 추가와 일반 2,000개 상한 적용 | 매번 같은 원본에서 시작; 누적 변경 부하 아님 |
| durable save/load | SaveManager 실제 원자 저장과 첫 저장의 roundtrip 검증 | 파일 쓰기만 재거나 검증을 생략하지 않음 |
| process peak | Windows PeakWorkingSet64 표본, fixture 생성 비용 포함 | 열기 전후 RAM 증분·50회 회수·실제 아트 포함 전체 게임 RAM 아님 |

## 4. 변경 전후 탐색 결과

단위 ms. 각 첫 화면/검색은 표본 1개이며 저장은 3개 중 최대값이다. 인수 p95나 보장된 개선율이 아니다.

| fixture / 언어 | 첫 화면 전→후 | 최초 검색 전→후 | 저장 최대 전→후 |
| --- | ---: | ---: | ---: |
| N2000 / ko | 667.206 → 506.179 | 1,357.299 → 564.905 | 1,000.484 → 1,016.047 |
| N2000 / en | 481.297 → 308.249 | 1,352.394 → 502.942 | 993.566 → 1,009.987 |
| L10000 / ko | 2,437.885 → 1,574.392 | 8,982.596 → 2,904.529 | 3,364.157 → 3,346.202 |
| L10000 / en | 2,397.544 → 1,531.545 | 8,958.387 → 2,839.710 | 3,373.592 → 3,349.620 |
| P2001 / ko | 1,031.997 → 835.000 | 2,496.170 → 966.820 | 2,267.606 → 2,233.816 |
| P2001 / en | 821.059 → 596.142 | 2,500.609 → 989.514 | 2,251.498 → 2,291.663 |
| LONG / ko | 672.403 → 509.881 | 1,358.690 → 531.339 | 1,079.709 → 1,062.409 |
| LONG / en | 459.764 → 322.835 | 1,356.097 → 549.627 | 1,098.912 → 1,082.748 |

L10000 변경 후 프로세스 peak는 ko 약 1,016.9 MiB, en 약 1,023.9 MiB다. 수첩 닫은 뒤 회수 여부나 전체 게임 메모리 합격을 뜻하지 않는다. 저장 세 번의 증가에는 첫 실행의 슬롯 없음 → 본파일 존재 → 본파일+백업 존재에 따른 읽기/검증 부하가 포함된다. 세 값만 보고 메모리 누수로 판정하지 않는다.

## 5. 코드 개선과 보존 계약

1. `notebook_query.gd`: 필터마다 선택 결과 전체를 정렬하던 것을 동결된 모델의 정렬 모드 3개 캐시로 바꿨다. 대화 세션/본문 순서·인물 순서·최근 순서와 anchor 위치를 유지한다. 실제 선택한 필터만 검사한다. 닫기·재개·언어/스코프 변경 시 캐시를 폐기한다.
2. `notebook_panel.gd`: 매 프레임 12개 고정 색인 대신 짧은 협력적 시간 예산을 사용한다. 기본 4ms, 4개 묶음 처리 후 시간을 확인한다. 한 묶음은 예산을 초과할 수 있으므로 엄격한 4ms 프레임 상한이라고 주장하지 않는다. debounce·IME 대기·부분 결과 표시·stale key 거부는 유지한다.
3. `notebook_knowledge.gd`: 전체 archive와 ledger 및 고아 출처 링크 검사를 이미 마친 뒤, 참조가 없는 경우 같은 archive를 다시 검증하지 않는다. 빈 ledger로 잘못된 archive나 남은 knowledge_source 링크를 숨기는 반례는 계속 거부한다.

저장 원자성, 성공 전 영속 완료 조건, 스키마, 기록 보호, 구 원문·번역·참조, 퍼즐 답안과 엔딩은 바꾸지 않았다. 현재 저장 지연은 해결되지 않았다.

## 6. 실행 근거와 남은 게이트

- 변경 전 PCK: `B124D204FB8481B831512B5D3CF77E71442ECCA2D8904334D3E547D8E1C6C56B`.
- 변경 후 PCK: `4B03DF809F8B54A2B6A7B77EBEAED03E90F37837B4924FDFB018A355B527E77C`.
- 변경 후 editor import 20.4초, export 8.0초. query 1,411개 및 하위 검색 180개 등 38.8초 PASS, knowledge 8.2초 PASS. 정렬 기준 참조 비교·anchor·캐시 상한/폐기·점진 검색·빈 ledger 반례를 포함한다.
- 같은 PCK의 후속 회귀: migration 4.8초, host 301개/34.7초, presentation seed 106개/19.2초, prologue presentation seed 66개/24.8초, modal presentation seed 397개/56.6초, surface resume 108개/6.7초 모두 PASS. 이 실행에서는 presentation의 별도 resume/completed 프로세스와 전체 캠페인은 재실행하지 않았다. 이전 커밋의 전체 회귀를 이번 변경의 실행 결과로 계산하지 않는다.
- 로컬 로그: `%TEMP%/ggb-notebook-perf-baseline2-20261004`, `ggb-notebook-perf-trial-20261004`, `ggb-notebook-perf-optimized-20261004`, `ggb-notebook-perf-optimized-trial-20261004`. 후속 회귀는 `ggb-notebook-perf-regression-20261004`에 분리한다.
- 최초 `ggb-notebook-perf-baseline-20261004` 실행은 fixture 불변 검사에서 실패했다. 파싱 전 정수 JSON과 파싱 후 수 표현을 비교한 시험 결함을, 파싱 직후 동결본과 종료 시 값을 비교하도록 교정했다. 입력 내용 해시 검사는 별도 유지하며 이 실패 실행을 통과 표본에 넣지 않았다.

남은 작업은 대용량 첫 화면 검증/복제/레이아웃과 최초 색인 비용 분리, 저장의 안전한 비차단 처리 설계·내구성 회귀, 네 장비 계층의 cold 20/warm 100 실제 입력 p95, 긴 문서 200% 표시, 50회 열고 닫기 RAM 회수, 60초 프레임 캡처, Alt+Tab 및 IME다. 오래된 기록 삭제·저장 검증 생략·완료 선표시로 예산을 맞추지 않는다. 전체 목표와 rollout은 각각 IN_PROGRESS·기본 비활성이다.

## 7. 저장 직렬화와 복구 안전성 후속

기준 develop `e5ce209`, 같은 날짜의 후속 작업이다. 위 4절의 측정과 섞지 않는다.

### 7.1 수정과 사전 재현

`save_manager.gd`에서 이미 schema 2인 기록의 저장에도 이관용 전체 digest를 계산하고, 서명 전후 같은 중첩 payload를 여러 번 정렬·복제하는 것을 확인했다. 이관 digest는 실제 구형 기록 이관이 필요한 경우에만 계산한다. 새 `_encode_payload`는 정규 순서를 한 번 만든 뒤 기존 checksum 키의 값만 갱신한다. JSON 공백·순서·UTF-8·서명 알고리즘과 저장 스키마는 그대로다. 원래 인코더와의 바이트 비교, 한글·이스케이프·StringName·중첩 배열·숫자, 입력 불변과 구 기록 이관 ID를 검사한다.

성능 검토 중 [ERR-0028](../ideas/md/v04/issues/items/GGB-ERR-2026-0028_손상된_본파일이_정상_백업을_덮어씀.md)도 재현했다. 수정 전 `%TEMP%/ggb-notebook-save-repro-20261004`의 이관 검사는 새 재현 조건 5개 중 백업 바이트 유지/독립 로드 두 건이 실패했다. 이제 검증된 본파일만 백업을 대체하며, 본파일 제거 실패를 보고하고, 마지막 승격 실패 시 확인된 복구본을 유지한다. 미래 버전 차단과 임시파일 재검증은 생략하지 않는다.

### 7.2 저장 시간 비교

이번에도 같은 네 fixture·두 언어, cold 1/warm 3의 탐색 계측이다. [새 원자료](evidence/notebook_save_trial_20261004.json)의 입력 해시는 앞선 8개 실행과 모두 일치한다. 비교 기준은 4절의 조회 개선 후 코드이며 이번 저장 수정 이전이다. 아래 단위는 ms이고 세 표본 중 최대값이므로 인수용 p95가 아니다.

| fixture / 언어 | 저장 3회 최대 전→후 |
| --- | ---: |
| N2000 / ko | 1,016.047 → 834.412 |
| N2000 / en | 1,009.987 → 867.960 |
| L10000 / ko | 3,346.202 → 2,744.065 |
| L10000 / en | 3,349.620 → 2,783.215 |
| P2001 / ko | 2,233.816 → 1,902.182 |
| P2001 / en | 2,291.663 → 1,879.745 |
| LONG / ko | 1,062.409 → 877.886 |
| LONG / en | 1,082.748 → 881.274 |

대량 동기 저장은 여전히 초 단위다. ERR-0027은 IN_PROGRESS이며 비차단 영속 저장·정식 표본·실제 입력 인수는 남아 있다. 평균/최대의 감소를 저장 성능 문제 전체 해결로 치환하지 않는다.

### 7.3 실행 범위

- 최종 PCK: `864F1013E64001F35B3C171F45D1E292088B07C999D83D64111D96D84FB1B5AE`.
- `%TEMP%/ggb-notebook-save-fixed-20261004`: editor import 21.4초, export 8.2초, 이관·신규 저장 안전성 46개 5.7초, 조회 1,411개 및 하위 검사 44.5초, knowledge 8.7초 PASS.
- `%TEMP%/ggb-notebook-save-trial-20261004`: 8개 별도 프로세스의 원본/공개/할당량/실제 저장 및 load roundtrip 검사 PASS.
- 후속 기존 동작 회귀는 `%TEMP%/ggb-notebook-save-regression-20261004`에 분리한다. 실제 OS 파일 잠금·전원 차단은 시험하지 않았으며 승격 오류는 실제 temp 쓰기/검증 이후 주입했다.
- 같은 최종 PCK의 v2 회귀: foundation 8.2초, dialogue history 5.9초, presentation seed/resume/completed 106/7/4개(15.5/4.6/4.4초), prologue 66/26/16개(19.7/10.2/5.0초), modal 397/7/4개(43.4/4.8/4.6초), surface resume 108개/6.0초 PASS. resume/completed는 seed와 별도 OS 프로세스이며 같은 격리된 시험 APPDATA를 공유한다. 이번 후속에서 전체 캠페인 완주 검사는 재실행하지 않았다.
- rollout 플래그 없는 기존 모드는 `%TEMP%/ggb-notebook-save-legacy-20261004`에서 foundation 7.4초, dialogue history 5.8초 PASS했다. 저장 스키마를 강제로 올리거나 기본 rollout을 활성화하지 않았다.

## 8. 패널 50회 재사용과 모델 해제 검사

기준 develop `2002782`. [lifecycle probe](../game/scripts/tests/notebook_lifecycle_probe.gd)를 선택적으로 실행하도록 계측 도구에 `-LifecycleCycles`를 추가했다. 기본값 0은 기존 시간 계측을 유지한다. 다음은 메모리 수명 시험이며 cold 20/warm 100이나 실제 입력 인수를 대체하지 않는다.

```powershell
./scripts/measure_notebook_performance.ps1 `
  -GodotPath 'C:/path/to/godot.exe' `
  -PackPath 'C:/path/to/notebook.pck' `
  -OutputDirectory 'C:/path/to/new-empty-output' `
  -ColdRuns 1 -WarmRuns 0 -LifecycleCycles 50 -DeadlineSeconds 3600
```

### 8.1 검사 경계

각 fixture·locale 프로세스에서 같은 실제 `NotebookPanel`을 50회 재사용한다. 매회 새 조회 모델과 load_epoch를 사용하고 100/150/200% 글자 배율을 순환한다. 50회에서 각 배율은 17/17/16회다.

- 네 상위 탭·최대 50행·필터 결과 캐시 8개/정렬 모드 캐시 3개 상한을 검사한다.
- 공개 검색 색인을 끝까지 채우고 숨은 페이지 키워드가 조회되지 않는지 확인한다. 직접 고정 분량으로 색인하는 것은 메모리 부하를 만들기 위한 것으로, 실제 패널의 시간 예산 검색 지연 시험이 아니다. 한 번의 처리 상한은 조회 API의 PAGE_SIZE=50을 따른다.
- 비교 묶음의 모든 자료를 두 칸에 번갈아 교체한다. 12개 묶음도 동시 두 자료 모델을 유지한다. 시각 자료 확대창과 필터 탐색창을 실제로 생성·닫는다.
- LONG의 첫 합성 문서 앞/뒤 페이지를 각 배율에서 열고, 실제 Control의 문단들을 다시 합친 본문이 공개 원문과 정확히 일치하는지 검사한다. 20개 문서 전체는 검색 부하에 포함하지만 20개 모두의 모든 확대 배치를 육안 확인하는 검사는 아니다.
- 닫은 뒤 두 프레임을 기다려 queue_free를 처리한다. 모델 WeakRef 해제, 패널·보조창의 모델 참조 제거, 조회/검색/정렬 캐시 비움, 이전 키 접근 거부, 동적 화면 자식 제거, 기준 노드 수 복귀와 고아 노드 수 불변을 확인한다.
- 실제 GameState와 fixture는 시작/종료 전체 JSON을 비교해 불변인지 검사한다. 슬롯 저장이나 원문 재구성은 하지 않는다.

측정값은 Godot `MEMORY_STATIC`, 전체 Object/Node/OrphanNode 수다. 첫·중간·마지막 열린 상태/닫힌 상태, 패널 자체 제거 뒤 수치를 기록한다. 프로세스 working set·GPU 메모리·정상 본편 호스트 전체의 증분 RAM은 아니다. 글꼴/엔진 캐시와 측정 samples 배열의 유지 비용도 포함하므로 정적 바이트가 조금 증가한 사실만으로 누수라고 단정하지 않으며, Node/WeakRef 통과를 전체 RAM 회수 완료로 확대하지 않는다.

모든 조작은 실제 Control 메서드에 대한 프로그램 호출이다. Windows OS 입력/IME, 호스트의 읽음 저장·sidecar, 실제 720p/1080p 렌더링·줄바꿈·겹침 육안 QA, Alt+Tab은 별도 인수다. 결과의 `50_open_close_memory` 미검증 표시는 이 전체 범위를 가리키며 엔진 모델 해제 검사의 실행 결과와 구분한다.

### 8.2 50회 반복 실행 결과

네 fixture × 두 언어 × 50회, 총 400회가 완료됐다. 56,816개 단언이 모두 PASS했다. [보관 원자료](evidence/notebook_lifecycle_trial_20261004.json)는 각 회의 수치를 `sample_columns`와 숫자 행으로 보존한다. 입력 fixture 해시는 앞선 시간 계측과 같으며 원문/게임 상태 불변도 검사했다.

| fixture / 언어 | 검사 수 | 실행 시간(초) | 매회 닫힌 Node 수 | 고아 Node 수 | 프로세스 peak(MiB) |
| --- | ---: | ---: | ---: | ---: | ---: |
| N2000 / ko | 3,802 | 387.3 | 486 | 0 | 396.9 |
| N2000 / en | 3,802 | 150.5 | 486 | 0 | 401.7 |
| L10000 / ko | 13,802 | 1,269.8 | 486 | 0 | 615.9 |
| L10000 / en | 13,802 | 1,242.6 | 486 | 0 | 615.8 |
| P2001 / ko | 6,702 | 555.6 | 486 | 0 | 479.4 |
| P2001 / en | 6,702 | 297.8 | 486 | 0 | 495.9 |
| LONG / ko | 4,102 | 626.6 | 486 | 0 | 478.9 |
| LONG / en | 4,102 | 388.0 | 486 | 0 | 484.8 |

486은 이 시험 프로세스의 패널을 만든 직후 기준값이며 제품의 고정 허용 Node 수가 아니다. 패널 자체를 제거한 뒤에는 모두 359개로 돌아왔다. 매회 조회 모델 WeakRef는 해제됐고 검색/정렬/결과 캐시와 동적 비교 화면 자식은 비워졌다. 세 번째부터 마지막까지 닫힌 Object 수는 각 조건에서 같았다.

반면 Godot 정적 할당량은 세 번째부터 50번째 사이 약 1.02MB 증가했다. 400개 관찰의 원자료에 증가도 그대로 남겼다. 측정 samples와 엔진/글꼴 캐시 유지 비용을 별도 분해하지 않았으므로 이 차이를 제품 누수나 완전 회수 중 어느 쪽으로도 단정하지 않는다. 노드·모델 누적은 확인되지 않았지만 전체 RAM 인수는 여전히 미완료다. 위 약 81.97분은 부하 검사의 총 실행 시간이지 사용자 입력 지연이나 p95가 아니다.

### 8.3 원본 페이지 교차 검사와 패키지 구분

50회 실행은 PCK `FAE7289EE4C1C30679D51FCE40D6F15A1CDD58BA6B0FD9334576A72638F2F1E5`로 수행했다. 이 버전은 화면 문단을 합친 본문과 조회 결과의 일치를 검사했다. 그 뒤 둘 다 잘리는 경우를 막기 위해 원본 정의와 페이지당 UTF-8 16,384바이트를 직접 비교하는 단언을 추가했다.

추가 단언의 최종 PCK는 `80037044FEBA790D6B6BF6CB6F6943FA62B16923CD50B891764A6B75E8EFD176`이다. LONG 한영 각각 3회, 100/150/200%에서 각 254개 검사가 통과했다(47.1/39.3초). 각 회 공개 앞/뒤 두 페이지를 비교했다. 이 6회 교차 검사를 이전 400회 모두에서 새 단언을 실행한 것처럼 소급하지 않는다. 색인 요청 크기를 API의 실제 상한인 PAGE_SIZE로 명시했으며, 이전 요청 256도 내부에서 50으로 제한되어 실제 처리량은 같았다. 제품 UI·저장·조회 코드는 이번 작업에서 변경하지 않았다.

로그 위치:

- `%TEMP%/ggb-notebook-lifecycle-20261004`: 최초 import에서 WeakRef 반환형 추론 경고가 오류로 처리됐다. 명시적 타입으로 수정했으며 실패한 빌드를 통과로 세지 않는다.
- `%TEMP%/ggb-notebook-lifecycle-final-20261004`: 400회 검사 패키지, import 20.6초/export 10.2초.
- `%TEMP%/ggb-notebook-lifecycle-preflight-20261004`: LONG ko 3회 사전 검사, 248개/42.9초 PASS.
- `%TEMP%/ggb-notebook-lifecycle-trial-20261004`: 8개 프로세스의 400회 본 검사. 알려진 root certificate 환경 오류 외의 스크립트/엔진 오류는 없었다.
- `%TEMP%/ggb-notebook-lifecycle-source-20261004`, `ggb-notebook-lifecycle-source-trial-20261004`: 추가 원본 대조 검사 패키지(import 49.9초/export 13.3초)와 한영 실행.

다음 인수는 호스트 전체의 실제 입력·읽음 저장·슬롯/언어 전환, OS working set 증분/닫기 후 회수, 200% 렌더링과 IME, cold 20/warm 100이다. 대량 표시·검색·동기 저장 지연(ERR-0027)도 남아 있다. 이번 결과는 모델·노드 수명 검증을 보강한 것이며 전체 목표 완료나 rollout 승인이 아니다.
