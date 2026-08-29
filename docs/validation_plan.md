# GGB 검증·CI 계획

## 1. 목적

같은 커밋을 누구나 같은 명령으로 검사하고, 문서·데이터·빌드 회귀를 단계적으로 차단한다. 검증을 수행하지 않은 항목은 계획 문구만으로 통과 처리하지 않는다.

## 2. 검증 단계

| 단계 | 실행 시점 | 현재 상태 | 범위 |
| --- | --- | --- | --- |
| `V0_DOCS` | 모든 PR·develop/main push | ACTIVE | UTF-8, H1, fence, 로컬 링크, 결정·이슈 ID, 에셋 manifest, 기획 계약 회귀, 임시 파일 |
| `V1_GODOT_IMPORT` | 기술 기반선 이후 | NOT_IMPLEMENTED | headless import, GDScript parse, Resource load |
| `V2_DATA_CONTRACT` | 첫 사건 Resource 이후 | NOT_IMPLEMENTED | ID·state path·writer·graph·locale 참조 |
| `V3_SAVE_FIXTURE` | 첫 배포 저장 이후 | NOT_IMPLEMENTED | save/load, checksum, backup, migration, 데모 import |
| `V4_WINDOWS_EXPORT` | export preset 이후 | NOT_IMPLEMENTED | Windows debug/release export, artifact smoke test |
| `V5_PLAYTHROUGH` | 버티컬 슬라이스 이후 | NOT_IMPLEMENTED | 마우스·키보드·접근성·한영 필수 경로 |

현재 게임 구현이 시작되지 않았으므로 `V1~V5`를 통과했다고 주장하지 않는다. 이번 기준선에서 자동 실행되는 것은 `V0_DOCS`뿐이다.

## 3. 로컬 실행

저장소 루트의 PowerShell에서 실행한다.

```powershell
./scripts/validate_docs.ps1
```

성공 시 요약과 `PASS`를 출력하고 종료 코드 0을 반환한다. 오류가 하나라도 있으면 파일·규칙·대상을 출력하고 종료 코드 1을 반환한다.

운영 스크립트는 Node.js 24 환경에서 별도로 실행한다.

```powershell
node --test scripts/discord_notifications.test.mjs
```

2026-08-29 Codex 번들 Node.js `v24.19.0` 실행 결과는 15개 통과, 실패 0개다. 이는 운영 스크립트 검증이며 미구현 상태인 Godot `V1~V5`를 통과시킨 것이 아니다.

## 4. V0 검사 계약

- 루트 운영 문서와 `docs/`, `ideas/`, `game/`의 Markdown은 BOM 없는 strict UTF-8로 읽을 수 있다.
- 모든 Markdown에 H1이 하나 이상 있다.
- 코드 fence 수가 짝수다.
- 상대 Markdown 링크 대상 파일이 존재한다.
- 결정 파일명 ID와 본문의 ID가 같고 중복되지 않는다.
- 충돌·오류 파일명 ID와 H1 ID가 같고 중복되지 않으며, 개별 색인과 운영 레지스트리에 모두 연결된다.
- 레지스트리의 CNF·ERR·전체 `VERIFIED` 집계가 실제 개별 파일 수와 같다.
- 승인 결정문의 해결된 CNF·ERR 후속 작업이 과거 `READY`·`BLOCKED` 상태로 남지 않는다.
- 문서 17·통합본·이슈 레지스트리에 현재 검증 기준일이 함께 반영된다.
- `asset_manifest.csv`에 필수 열, 고유 `asset_id`, 유효 상태·bool·양수 `unit_count`가 있다.
- 마일스톤 정본은 `milestones.md`의 ID이며, 에셋·의뢰·개별 충돌/오류의 목표 마일스톤이 모두 정본에 존재한다.
- 정본 오브젝트 ID는 `game_object_catalog.csv`에서 유일하며, 현행 계약 문서와 에셋 source가 등록되지 않은 구체 ID를 참조하지 않는다.
- 정본 오브젝트의 `art_asset_id`가 모두 에셋 manifest에 존재한다.
- 외부 서고 중계 시계는 `OBJ_LIBRARY_OUTER_CLOCK`·`M1_LIBRARY_OUTER`, 기록 내실 경계 시계는 `OBJ_LIBRARY_RECORD_CLOCK`·`M1_LIBRARY_INNER`이며 ART·CNT 버티컬 슬라이스 요청이 이를 혼용하지 않는다.
- `APPROVED` 또는 `INTEGRATED`인 내부 제작물은 `evidence`에 유효한 `rights_ref=RIGHTS-YYYY-NNNN`를 가진다. `PLANNED` placeholder에는 이를 강제하지 않는다.
- credits registry는 고유 ID·허용 상태를 사용하고, 권리 증거가 없는 내부 제작물을 `VERIFIED`·`INCLUDED`로 표시하지 않는다.
- Godot 프로젝트가 존재하면 credits registry에 `GODOT_ENGINE` 런타임 라이선스 계획이 존재한다.
- 데모 임시 에셋 비율은 `demo_full`, required, non-CUT 행의 `unit_count` 가중 산식을 사용한다.
- `SAVE_D5_COMPLETE`는 demo에서 `DEMO_END_SCREEN`, full과 승인된 import에서만 `D6_FREE_INSPECTION`으로 재개한다.
- 현행 정본에 상태 모델 개정 번호를 런타임 schema로 오인하는 구식 표기가 다시 생기지 않는다.
- F2 필수 지식 6종, 엔딩 9~15분, J4 의미 placeholder, 전체 플레이타임 합산, 1.0 입력 범위와 Windows 10/11 확정 범위가 구식 문구로 회귀하지 않는다.
- `game/` 실제 파일 트리에 이름에 `tmp`가 든 중단 저장 파일이 남지 않는다.

역사 기록인 `ideas/md/v04/issues/`와 검토 보고서는 구식 표기 검사에서 제외한다. 해당 파일의 과거 근거를 현재 계약으로 오인하지 않는다.

### 4.1 제작 의뢰 데이터

`scripts/validate_docs.ps1`은 `docs/requests/request_register.csv`와 발행 준비 의뢰서를 함께 검사한다.

- `REQ-ART-*`, `REQ-AUD-*`, `REQ-CNT-*` ID 형식·중복·team 일치.
- 상태·배치 범위·담당·검토자와 source ID 존재.
- `READY_FOR_ACCEPTANCE` 이후 활성 의뢰의 상세 brief 경로·본문 ID·revision·상태·수락 게이트.
- 의뢰 대장과 상세 brief의 목표 마일스톤·revision 일치, 목표 마일스톤의 정본 존재 여부.
- 아트·사운드 의뢰의 모든 `asset_id`가 `asset_manifest.csv`에 존재하는지 여부.
- ART·AUD 의뢰의 `asset_id`가 서로 중복되지 않고 각 팀 소유 매니페스트 행을 빠짐없이 분할하는지 여부.
- 전 의뢰 수락 뒤에도 배치 설명이 수락 대기로 남거나, 범위 수락을 제작 착수 게이트와 혼용하는지 여부.
- VS 아트 요청 수가 바뀌었을 때 데모 잔여 의뢰서의 제외 수량이 같은 값인지 여부.
- 팀별 핵심 필드: 아트의 상태·접근성·납품, 사운드의 용도·길이·음색·loop·자막, 콘텐츠의 trigger·상태 읽기·쓰기·반복 정책.

GitHub Actions의 외부 `uses:` 참조는 tag가 아니라 40자리 commit SHA로 고정한다. SHA 주석의 버전명은 사람용 정보이며 실행 정본은 SHA다.

검증 통과는 팀이 범위를 수락했거나 실제 제작이 시작됐다는 뜻이 아니다. 상태 전이는 팀 회신과 제작 증거로 별도 확인한다.

## 5. 후속 단계 계약

### V1 Godot import

- Godot 버전을 하나로 고정한다.
- `--headless --editor --quit` import가 오류 없이 끝난다.
- 모든 `.gd`가 parse된다.
- main scene과 autoload 경로가 존재한다.
- placeholder 또는 sandbox scene이 production main scene이 아니다.

### V2 데이터 계약

- event·node·location·object·text·signature ID가 유일하고 등록돼 있다.
- prerequisite와 write state path가 선언돼 있다.
- 선택 관계 이벤트가 F0·엔딩을 차단하지 않는다.
- demo flavor가 E1 이후 event를 실행하지 않는다.
- `ko-KR`, `en-US` placeholder 집합이 같다.

### V3 저장 fixture

- 최초 runtime `schema_version=1` fixture를 저장·로드한다.
- 5개 강제 종료 지점에서 원자 효과가 중복되지 않는다.
- 손상 main은 backup으로 복구하고 둘 다 손상되면 원본을 보존한다.
- 대화 기록이 리셋·저장·언어 변경 뒤 유지된다.
- 데모 import 성공, 미지원 버전, 슬롯 충돌과 손상 경로를 검사한다.
- demo `SAVE_D5_COMPLETE`는 D6 Resource 없이 종료 화면으로, 승인된 복제 full 슬롯은 D6로 재개한다.

### V4 Windows export

- 인증 정보를 제외한 `export_presets.cfg`를 추적한다.
- debug export를 CI artifact로 만든다.
- 깨끗한 Windows 사용자에서 설치·실행·저장·종료를 확인한다.
- release export와 Steam depot은 비밀값을 저장소에 남기지 않는다.

### V5 플레이 경로

- 마우스 전용과 키보드 전용 필수 완주.
- 1280x720, UI·텍스트 200%.
- 색 제거·음량 0·모션 감소 동시 사용.
- 한국어·영어 진행 checksum 동등.
- 실패→영구 정보→숏컷의 반복 피로 측정.

## 6. 실패 처리

| 실패 | 조치 |
| --- | --- |
| PR의 V0 실패 | 병합 차단, 같은 PR에서 수정 |
| main/develop V0 회귀 | P1 작업으로 등록하고 다음 변경 전 복구 |
| Godot import·parse 실패 | 빌드 artifact 생성 금지 |
| save fixture 실패 | 해당 schema 배포·데모 import 금지 |
| 접근성 필수 경로 실패 | 공개 데모·RC 게이트 실패 |
| CI 환경만 실패 | 로컬 성공만으로 무시하지 않고 환경 차이를 기록 |

## 7. 책임

- 검증 스크립트·CI owner: 개발 팀장 `beru`.
- 문서·서사 오류 검토: 기획·QA 팀장 `gatam`.
- 공개 빌드 게이트 승인: `beru`와 가능하면 별도 검토자 1명.
- 검사 제외나 규칙 완화는 조용히 적용하지 않고 PR 이유와 영향 범위를 남긴다.
