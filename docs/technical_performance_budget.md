# GGB Windows 렌더러·성능 예산

## 1. 상태와 목적

| 항목 | 값 |
| --- | --- |
| 상태 | PROVISIONAL_UNTIL_VERTICAL_SLICE |
| 대상 | Windows 10/11 64-bit, Godot 4.7 계열 |
| 기준 화면 | 1920x1080, 60Hz |
| 최소 레이아웃 | 1280x720 |
| 결정 게이트 | `TECH_01_FOUNDATION` 후보 구성, `PROD_01_VERTICAL_SLICE` 실측 잠금 |

현재 `game/project.godot`의 Forward+·D3D12 설정은 연습 프로젝트의 현재값이지 제품 렌더러 확정 근거가 아니다. 구현 시작 전에는 아래 예산과 시험 절차를 제작 계약으로 사용하고, 실제 기기 결과 없이 Steam 최소 사양을 확정하지 않는다.

## 2. 렌더러 결정 규칙

같은 버티컬 슬라이스 장면을 두 후보로 export한다.

| 후보 | 우선 가설 | 통과 조건 |
| --- | --- | --- |
| Compatibility | 2D 배경·UI·정적 글리치만으로 연출을 보존할 수 있으면 기본 후보 | 필수 단서·S0~S3 전환·200% UI가 동일하게 작동 |
| Forward+ | Compatibility로 필수 연출을 재현할 수 없을 때 사용 | 최소 장비에서 Low preset 30fps 하한과 드라이버 안정성 통과 |

선택 순서:

1. C5, D5, E1, 색 제거 모드가 포함된 동일 장면을 두 렌더러로 만든다.
2. 이미지 비교에서 필수 단서 손실과 글리치 대체 가능성을 판정한다.
3. 저사양·중간·기준 장비에서 프레임, 메모리, 시작·전환 시간을 잰다.
4. Compatibility가 기능·연출 합격선을 만족하면 이를 우선한다.
5. Forward+만 합격하면 Low 효과 대체와 최소 GPU를 같은 결정에서 잠근다.
6. 결과를 `GGB-DEC`로 남기고 `project.godot`, export preset, Steam 사양을 함께 갱신한다.

## 3. 성능 목표

| 지표 | 기준 장비·Standard | 최소 후보 장비·Low | 실패 등급 |
| --- | ---: | ---: | --- |
| 평균 프레임 | 60fps | 30fps 이상 | 30fps 미만 지속 P1 |
| 1% low | 50fps 이상 | 24fps 이상 | 입력 가능한 장면에서 20fps 미만 P1 |
| 프레임 시간 급증 | 50ms 초과 1회 이하/방 전환 | 100ms 초과 1회 이하/방 전환 | 퍼즐 입력 중 100ms 초과 P1 |
| 입력→포커스 반응 | 100ms 이하 | 150ms 이하 | 250ms 이상 P1 |
| 냉간 시작 | SSD 8초 이하 | SATA SSD/HDD 후보 15초 이하 | 25초 이상 P1 |
| 방 전환 | 1.5초 이하 | 3초 이하 | 5초 이상 P1 |
| 저장 커밋 | 300ms 이하, 비동기 표시 | 750ms 이하 | UI 정지 1초 이상 P1 |
| RAM peak | 1.5GB 이하 | 2GB 이하 | 3GB 초과 P1 |
| VRAM 추정 peak | 1GB 이하 | 1.5GB 이하 | 2GB 초과 시 원인 승인 필요 |
| 데모 설치 크기 | 2GB 이하 | 동일 | 초과 시 에셋 심사 |
| 정식판 설치 크기 | 5GB 이하 | 동일 | 초과 시 에셋 심사 |

수치는 첫 실측 전 예산이다. 장르 특성상 평균 fps보다 입력 시 프레임 급증, 방 전환, 고해상도 배경의 VRAM 사용을 우선 본다.

## 4. 시험 장비 계층

실제 보유 장비를 아래 역할에 매핑하고 CPU·GPU·RAM·저장장치·드라이버·Windows 빌드를 결과에 기록한다.

| 계층 | 후보 특성 | 용도 |
| --- | --- | --- |
| LOW-IGPU | 4코어급 CPU, 통합 GPU, RAM 8GB | Compatibility 우선, 720p Low 하한 |
| LOW-DGPU | VRAM 2GB급 구형 독립 GPU, RAM 8GB | Forward+ 사용 가능성 하한 |
| MID | VRAM 4GB 이상, RAM 16GB | 1080p Standard 기준 |
| HIGH-DPI | 1440p/4K, Windows 배율 150~200% | UI·텍스트·VRAM 확대 |

정확한 모델이 없는 계층은 `NOT_COVERED`로 남긴다. 팀원 PC 한 대의 통과를 최소 사양 근거로 사용하지 않는다.

## 5. 품질 프리셋

| 기능 | Low | Standard | High |
| --- | --- | --- | --- |
| 글리치 왜곡 | 정적 이중 윤곽·라벨 | 제한된 마스크 왜곡 | 추가 잔광·공간 왜곡 |
| 화면 후처리 | 최소 | 기본 | 장식성 추가 효과 |
| 파티클 | 25%·정적 대체 | 100% 기준 | 150% 상한 |
| 배경 overlay | 필수 단계만 | 필수+감정 잔상 | 장식 레이어 추가 |
| 그림자·조명 | baked 또는 정적 | 제한적 동적 | 장식 동적 허용 |
| 애니메이션 | 필수 pose 유지, 장식 프레임 축소 | 기준 | 장식 보간 추가 |

- 품질 프리셋은 퍼즐 단서, 핫스폿, 문양, 텍스트와 상호작용 타이밍을 바꾸지 않는다.
- 광과민·모션·글리치 접근성 설정은 품질 프리셋보다 우선한다.
- Low에서도 캐릭터 식별과 S0~S5 상태 판독이 가능해야 한다.

## 6. 2D 에셋 메모리 예산

| 대상 | 예산 |
| --- | --- |
| 방 base background | 논리 1920x1080 기준. 4K 원본을 런타임에 그대로 상주시킬 경우 별도 승인 |
| 동시 room layer | base 포함 최대 8개, 필수 상호작용 layer 4개 이하 권장 |
| 캐릭터 동시 표시 | 본편 일반 3명, E2·F2 예외 5명. 예외 장면을 별도 계측 |
| 표정 atlas | owner별 현재 장면 필요 세트만 로드, 전 캐릭터 전 표정 상주 금지 |
| 전환 texture | D5·엔딩 전용은 장면 종료 후 해제 가능해야 함 |
| UI atlas | 720p~4K에서 9-slice·vector/font 우선, 해상도별 중복 bitmap 최소화 |

압축 형식과 texture 크기는 시각 비교 뒤 확정한다. 원본 작업 파일의 해상도와 런타임 export 해상도를 같은 값으로 오인하지 않는다.

## 7. 계측 장면

| 장면 | 최악 조건 |
| --- | --- |
| `PERF_ROOM_S0_S3` | 한 방에서 고딕 base와 S3 시설 overlay 전환 |
| `PERF_D5_TRANSITION` | 다섯 색 서명, 글리치, 전환 오디오 동시 |
| `PERF_E2_FIVE_SERVANTS` | 사용인 5명, 대사 로그, 200% 텍스트 |
| `PERF_F0_META_PUZZLE` | 다중 패널·오브젝트·힌트 overlay |
| `PERF_INVENTORY_4K` | 4K·200% UI·pseudo-localization·최대 아이템 |
| `PERF_SAVE_RESET` | NORMAL_RESET 원자 저장과 방 재구성 |

각 장면은 60초 capture와 방 전환 10회, `Alt+Tab` 5회, 창 모드 전환 3회를 실행한다.

## 8. 잠금과 후속

| 게이트 | 산출물 |
| --- | --- |
| TECH foundation | 두 renderer debug export, 장비 표, 계측 방법, Low 대체 목록 |
| Vertical slice | renderer 결정, provisional 최소 장비, frame/RAM/VRAM 결과 |
| Demo feature complete | demo 전체 방 spike 검사, 설치 크기, shader cache 확인 |
| Full content complete | F2·엔딩 포함 최악 장면 재검사 |
| Release candidate | Steam용 최소·권장 사양과 실제 clean-PC 근거 |

현재 구현물이 없으므로 본 문서는 렌더러 선택 완료가 아니라 **선택을 늦추지 않기 위한 시험 계약 완료**로 판정한다.
