# GGB 제작 전환 백로그

## 1. 목적

이 문서는 확정된 기획을 실제 제작 작업으로 나누는 등록 대기 목록이다. GitHub Issue·Project가 작업 상태의 정본이며, 아래 `PB-*`는 Issue를 만들기 전 범위 누락을 막는 **로컬 계획 키**다. 등록할 때 실제 `GGB-WRK-*`를 발급하고 매핑 열을 갱신한다.

현재 요청에 따라 게임 구현은 시작하지 않는다. 따라서 코드·씬·export가 필요한 항목은 `IMPLEMENTATION_NOT_STARTED`로 유지하고, 문서 계약과 제작 준비만 진행한다.

## 2. 우선순위 원칙

```text
제품 계약
→ 실제 팀 capacity 확인
→ 기술 기반선
→ 20~30분 버티컬 슬라이스
→ 측정·재산정
→ 데모 기능 완료
→ 데모 콘텐츠 락
→ 전편 콘텐츠 완료
→ 콘텐츠·현지화 락
→ 출시 후보
```

운영 자동화, 대시보드 고도화와 편의 기능이 기술 기반선 또는 버티컬 슬라이스의 담당 시간을 선점하지 않는다.

## 3. 상위 작업 패키지

| 계획 키 | 우선순위 | 결과물 | 책임 영역 | 선행 | 현재 상태 | GitHub 작업 |
| --- | --- | --- | --- | --- | --- | --- |
| `PB-001` | P1 | 제품·접근성·데모·저장 계약 통합 | 기획·개발 | 없음 | DOC_COMPLETE | 미등록 |
| `PB-002` | P1 | 개인별 capacity 확인과 전체 일정 재산정 | 프로젝트 관리 | PB-001 | NEEDS_TEAM_INPUT | 미등록 |
| `PB-003` | P1 | 제작 epic과 하위 Issue 등록 | 프로젝트 관리 | PB-001 | PARTIAL_AUTH_GH_CLI_BLOCKED | 미등록 |
| `PB-004` | P1 | 데모·본편 에셋 BOM과 승인 레지스트리 | 아트·사운드·기획 | PB-001 | DOC_COMPLETE | 미등록 |
| `PB-005` | P1 | 민감 콘텐츠·상점 고지 기준 | 기획·QA·릴리즈 | PB-001 | DOC_COMPLETE | 미등록 |
| `PB-006` | P1 | 정식명·인물명·연령·palette 잠금 | 기획·아트 | PB-001 | NEEDS_TEAM_DECISION | 미등록 |
| `PB-007` | P1 | 아트·애니메이션·오디오 제작 규격 | 아트·사운드·개발 | PB-004 | DOC_COMPLETE | 미등록 |
| `PB-008` | P1 | 1.0 플랫폼·Cloud·지원·라이선스 범위 | 릴리즈·개발 | PB-001 | DOC_COMPLETE | 미등록 |
| `PB-009` | P1 | 팀 기여물 권리 증거와 비공개 서명 기록 | 프로젝트 관리·릴리즈 | PB-008 | POLICY_READY_SIGNATURES_PENDING | 미등록 |
| `PB-010` | P1 | `TECH_01_FOUNDATION` | 개발 | PB-002, PB-003 | IMPLEMENTATION_NOT_STARTED_AT_RISK | 미등록; 목표일 경과·재산정 필요 |
| `PB-011` | P1 | `PROD_01_VERTICAL_SLICE` | 전 영역 | PB-010 | IMPLEMENTATION_NOT_STARTED_AT_RISK | 미등록; 기술·요청별 일정 재산정 필요 |
| `PB-012` | P1 | 저장·리셋·복구·대화 기록 최소 경로 | 개발·QA | PB-010 | IMPLEMENTATION_NOT_STARTED | 미등록 |
| `PB-013` | P1 | 마우스·키보드·접근성 최소 경로 | 개발·QA | PB-010 | IMPLEMENTATION_NOT_STARTED | 미등록 |
| `PB-014` | P1 | 한국어·영어 저작·검수 파이프라인 | 기획·QA | PB-001 | DESIGN_READY | 미등록 |
| `PB-015` | P1 | 재현 가능한 문서·데이터·빌드 검증 | 개발·QA | PB-010 | IMPLEMENTATION_NOT_STARTED | 미등록 |
| `PB-016` | P1 | 대표 에셋 샘플 배치와 역할별 처리량 기준선 | 아트·사운드·개발·PM | PB-002, PB-004, PB-007 | REQUEST_ACCEPTED_ALLOCATION_PENDING | `REQ-ART-2026-0001`, `REQ-AUD-2026-0001`; 팀 수락 완료, Issue 미등록 |
| `PB-017` | P1 | 버티컬 슬라이스 문자열 정본·분량·번역 처리량 기준선 | 기획·현지화·QA | PB-006, PB-014 | REQUEST_ACCEPTED_ALLOCATION_PENDING | `REQ-CNT-2026-0001`; 팀 수락 완료, Issue 미등록 |
| `PB-020` | P2 | 프롤로그·1장 알파 | 전 영역 | PB-011 재산정 | NOT_READY | 미등록 |
| `PB-021` | P2 | 데모 compact/extended 편집 비교 | 기획·QA | PB-011 | NOT_READY | 미등록 |
| `PB-022` | P2 | 데모 기능 완료·콘텐츠 락 | 전 영역 | PB-020, PB-021 | NOT_READY | 미등록 |
| `PB-030` | P2 | 전편 콘텐츠 완료·락 | 전 영역 | PB-022 | NOT_READY | 미등록 |
| `PB-031` | P2 | Steam 비공개 QA·출시 후보 | 개발·QA·릴리즈 | PB-030 | NOT_READY | 미등록 |

`DOC_COMPLETE`는 구현이 끝났다는 뜻이 아니다. 문서 계약만 검토 가능한 상태라는 의미다.

## 4. 기술 기반선 분해

`PB-010`을 GitHub에 등록할 때 다음 하위 작업을 각각 추적한다.

| 작업 | 결과 | 최소 완료 조건 |
| --- | --- | --- |
| production bootstrap | 정식 main scene과 앱 식별자 | 연습 씬과 제품 진입 분리 |
| 상태 기반 | GameState·writer·event registry | 선언되지 않은 상태 쓰기 차단 |
| 입력 기반 | InputMap·focus·pointer | 같은 필수 동작을 마우스·키보드로 확정 |
| 저장 기반 | schema 1·3슬롯·backup | fixture 저장·로드·손상 복구 |
| 현지화 기반 | `ko-KR`, `en-US`, pseudo | placeholder·누락 검사 |
| 표시 기반 | 1280x720~4K·DPI | 200% 텍스트 기본 화면 통과 |
| export 기반 | Windows debug build | 깨끗한 PC 설치·실행 절차 기록 |
| 검증 기반 | 로컬 명령·CI 후보 | 같은 커밋에서 재실행 가능 |

## 5. 버티컬 슬라이스 분해

| 축 | 포함 범위 | 측정값 |
| --- | --- | --- |
| 콘텐츠 | 짧은 일과→수첩→리셋→B3형 실패→숏컷→성공→S2 누수 | 완주 시간, 정체 구간 |
| 루프 | 물리 초기화·영구 정보·사용인 잔류 기억 | 수면/저장 구분 이해율 |
| 퍼즐 | 비가역 실패, 검증 부분 보존, 다음 루프 확장 | 정답 설명률, 재시도 시간 |
| 관계 | 기억하는 사용인의 짧은 반응 | 즉시 차단하지 않는 이유 이해율 |
| 저장 | 5개 강제 종료 지점 | 손상·중복·진행 손실 0건 |
| 입력 | 마우스 전용, 키보드 전용 | 완주·포커스 손실 |
| 접근성 | 색 제거, 음량 0, 모션 감소, 200% 텍스트 | 필수 정보 누락·레이아웃 오류 |
| 언어 | 한국어, 영어, pseudo | 진행 checksum·placeholder·잘림 |
| 성능 | 렌더러·해상도·DPI별 계측 | frame time, VRAM, 로딩 |

## 6. capacity 입력과 재산정

개인별 값은 공개 저장소에 상세 사유를 남기지 않고 GitHub Project에 다음 형식으로 기록한다.

```yaml
capacity_period: YYYY-MM-DD..YYYY-MM-DD
available_hours: 0
new_production_limit: available_hours * 0.70
review_fix_rest_reserve: available_hours * 0.30
unavailable_days: []
roles_in_same_pool: []
```

재산정은 다음 순서로 한다.

1. 버티컬 슬라이스의 역할별 실제 시간을 기록한다.
2. 남은 사건, 방, 퍼즐, 대사와 에셋 수에 단위 시간을 적용한다.
3. 겸임 역할 시간을 한 사람의 capacity 안에서 합산한다.
4. 결함 수정, 통합, QA와 현지화 시간을 별도 합산한다.
5. 20% 일정 위험 버퍼를 추가한다.
6. 가용 용량을 넘으면 먼저 날짜를 이동하고, 범위 변경은 별도 결정으로 남긴다.

## 7. GitHub 등록 완료 조건

- [ ] `PB-002~004`, `PB-009~017`에 실제 `GGB-WRK-*`가 연결돼 있다.
- [ ] 각 작업에 담당자, 검토자, 목표 마일스톤, 선행 작업과 완료 조건이 있다.
- [ ] 기술 기반선과 버티컬 슬라이스가 독립 epic 또는 부모 Issue로 보인다.
- [ ] 운영 자동화 작업과 제작 작업의 우선순위 충돌이 Project에서 드러난다.
- [ ] `BLOCKED`는 원인과 해제 조건을 가진다.
- [ ] 구현을 시작할 때만 해당 작업을 `IN_PROGRESS`로 바꾼다.

GitHub 등록이 완료되기 전까지 `GGB-REV-2026-0009`는 해결 완료가 아니다.

## 8. GitHub 등록 차단 기록

2026-07-31에 `PB-002`, `PB-004`, `PB-010~015`, `PB-021`에 대응하는 9개 Issue 생성을 시도했으나 GitHub integration이 모두 HTTP 403 `Resource not accessible by integration`을 반환했다. 이들을 등록·연결하는 상위 작업 `PB-003`과 이후 검토에서 추가된 권리 증빙 `PB-009`, 에셋 처리량 `PB-016`, 문자열 생산 기준선 `PB-017`도 같은 쓰기 권한이 필요하므로 영향 목록에 포함한다. `PB-009`, `PB-016`, `PB-017`은 동일 장애가 확인된 뒤 중복 실패를 피하려고 별도 생성 시도를 하지 않았다. 이 문단은 당시 실패 이력이며 현재의 모든 GitHub 경로가 차단됐다는 뜻이 아니다.

```yaml
blocker_id: PB-GITHUB-AUTH-2026-07-31
affected: [PB-002, PB-003, PB-004, PB-009, PB-010, PB-011, PB-012, PB-013, PB-014, PB-015, PB-016, PB-017, PB-021]
status: HISTORICAL_403
retry_when:
  - GitHub integration에 repository issue write 권한 부여
  - 또는 유효한 gh 인증 복구
forbidden:
  - 생성되지 않은 Issue 번호를 문서에 매핑
  - 로컬 PB key를 실제 GitHub 작업으로 표시
```

권한이 복구되면 `PB-003`과 `PB-009`부터 재시도하고, 중복 생성을 피하기 위해 저장소에서 `GGB-WRK-2026-0013` 이후 후보 제목을 먼저 검색한다.

### 8.1 2026-08-29 인증 재시험

| 경로 | 현재 판정 | 근거 | 허용되는 다음 행동 |
| --- | --- | --- | --- |
| Git fetch·push | AVAILABLE | `develop` 원격 동기화와 브랜치 원격 작업 성공 이력 | 일반 Git 전송 가능 |
| 공개 GitHub REST 읽기 | AVAILABLE | 저장소 Issue #15~#26 상태 조회 성공 | 중복 후보·공개 Issue 상태 확인 가능 |
| `gh` CLI 계정 인증 | BLOCKED | `gh auth status`가 기본 계정 token 무효를 보고 | 사용자가 `gh auth login`으로 재인증하기 전 write 명령 금지 |
| 기존 운영 Issue | PARTIAL_EVIDENCE | 공개 Issue #24는 CLOSED, #26은 OPEN. Project custom status는 인증 없이 확인하지 못함 | 로컬 문서에는 공개 Issue 상태와 Project 미확인을 분리 표기 |
| 제작 PB Issue 등록 | NOT_STARTED_AUTH_REQUIRED | 대응 `GGB-WRK-*` 매핑이 없고 현재 `gh` write 인증이 무효 | 재인증 뒤 제목 중복 검색, 미등록 항목만 생성 |

```yaml
blocker_id: PB-GITHUB-AUTH-2026-08-29
status: PARTIAL
blocked_capability: gh_cli_issue_and_project_write
unblocked_capabilities: [git_transport, public_rest_read]
production_pb_registration: UNREGISTERED
release_condition:
  - gh auth status가 유효 계정을 보고
  - Issue·Project write 권한을 최소 1건 dry-run 또는 비파괴 조회로 확인하고
  - 후보 제목 중복 검색 뒤 미등록 PB만 생성
```

`PB-003`의 현재 상태는 `PARTIAL_AUTH_GH_CLI_BLOCKED`다. 인증 복구 전에는 로컬 PB 키를 실제 GitHub Issue로 표시하지 않으며, 인증 복구 자체를 제작 완료로 간주하지 않는다.
