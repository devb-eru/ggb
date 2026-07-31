# GGB 1.0 플랫폼 기능·지원·개인정보·법적 범위

## 1. 상태 분류

| 상태 | 의미 |
| --- | --- |
| `REQUIRED_1_0` | 상점에 표기하고 RC에서 검증해야 출시 가능 |
| `CONDITIONAL_1_0` | 외부 계정·기술 시험을 통과하면 1.0 포함, 실패 시 상점에서 제외하고 결정 기록 |
| `EXCLUDED_1_0` | 1.0에서 제공하지 않으며 상점에 지원으로 표기하지 않음 |
| `POST_LAUNCH_CANDIDATE` | 출시 뒤 수요·용량이 있을 때만 검토 |

## 2. 기능표

| 기능 | 상태 | 1.0 계약·게이트 |
| --- | --- | --- |
| Windows 10/11 64-bit | REQUIRED_1_0 | clean-PC 설치·실행·업데이트 |
| single-player offline | REQUIRED_1_0 | 첫 설치·Steam 인증 뒤 네트워크 없이 본편 진행·저장 |
| 한국어·영어 | REQUIRED_1_0 | UI·자막·대사·상점 일치 |
| 마우스 전용·키보드 전용 | REQUIRED_1_0 | 필수 경로 각각 완주 |
| 3 진행 슬롯·백업 | REQUIRED_1_0 | current·backup·transaction 복구 |
| 데모 저장 가져오기 | REQUIRED_1_0 | 원본 보존, 수동 선택, 실패 복구 |
| Steam Cloud | CONDITIONAL_1_0 | full AppID 슬롯만 동기화. demo 자동 공유 금지, 충돌·rollback 시험 통과 시 포함 |
| Steam Achievements | EXCLUDED_1_0 | 서사 선택을 보상 점수화하지 않음. 상점 기능 미표기 |
| 게임패드 | EXCLUDED_1_0 | action 구조만 향후 확장 가능하게 유지 |
| 터치·콘솔·Steam Deck 인증 | EXCLUDED_1_0 | 지원 또는 호환 인증을 주장하지 않음 |
| 온라인·협동·Workshop | EXCLUDED_1_0 | 네트워크 게임 기능 없음 |
| 트레이딩 카드 | POST_LAUNCH_CANDIDATE | 아트·운영 용량과 Steam 자격 확인 뒤 |
| Rich Presence | POST_LAUNCH_CANDIDATE | 스포일러 없는 상태명 설계가 가능할 때 |
| 자동 telemetry | EXCLUDED_1_0 | 플레이 행동·선택·관계·퍼즐 데이터를 서버로 전송하지 않음 |
| 제3자 crash reporting | EXCLUDED_1_0 | 자동 업로드 없음 |
| 로컬 진단 로그 | REQUIRED_1_0 | 사용자 PC에 순환 저장, 사용자가 직접 내보낼 때만 공유 |
| 접근성 사전 설정·콘텐츠 고지 | REQUIRED_1_0 | 새 게임 전에 진입 가능 |
| 사용자 지원 | REQUIRED_1_0 | Steam Discussions + 공개 전용 support email, 한·영 기본 응답 템플릿 |

Steam Cloud가 `CONDITIONAL_1_0` 게이트를 통과하지 못하면 출시를 자동 차단하지 않는다. 대신 1.0에서 명시적으로 제외하고 상점의 Cloud 기능 표기를 제거하며, 데모 import는 로컬 읽기 방식으로 유지한다.

## 3. 저장·Cloud 정책

- full과 demo는 별도 사용자 데이터 경로와 AppID를 사용한다.
- demo 원본 저장을 Cloud에서 full 위치로 자동 이동하지 않는다.
- Cloud 동기화 대상은 완료된 current·backup과 슬롯 메타이며 `.tmp`, active transaction, debug log는 제외한다.
- 두 장치 충돌 시 수정 시각만으로 덮어쓰지 않고 build ID, save point, 플레이 시간, checksum을 비교해 사용자가 고른다.
- 엔딩 프로필과 접근성 설정의 동기화 여부는 슬롯과 별도로 시험한다.
- 삭제는 로컬·Cloud 범위를 명시하고 한쪽만 지운 상태를 보여 준다.

## 4. 개인정보와 진단

1. 게임은 자동 gameplay telemetry를 수집하지 않는다.
2. 관계 선택, 엔딩, 퍼즐 실패, 접근성 설정은 로컬 저장에만 둔다.
3. 로컬 로그에는 계정 토큰, Windows 사용자명 전체, 개인 문서 경로와 자유 입력을 기록하지 않는다.
4. 지원 요청에서 로그·세이브 첨부는 사용자가 명시적으로 선택한다.
5. 지원 email로 받은 주소와 첨부 파일의 보관 기간·삭제 요청 방법을 Coming Soon 공개 전 개인정보 안내에 명시한다.
6. Steam이 처리하는 계정·결제·플랫폼 데이터는 Valve의 정책 영역임을 구분한다.

자동 수집 기능을 나중에 추가하려면 목적, 필드, 보관 기간, 처리자, opt-in·opt-out, 삭제 절차를 새 결정으로 승인하기 전에는 배포하지 않는다.

## 5. 지원 계약

| 채널 | 용도 | 공개 시점 |
| --- | --- | --- |
| Steam Discussions | 설치·진행·일반 질문, 공지 | Coming Soon 공개 |
| 전용 support email | 세이브·로그처럼 공개 게시가 부적절한 자료 | Coming Soon 공개 전 생성 |
| GitHub Issues | 팀 제작 이슈 | 사용자 지원 채널로 홍보하지 않음 |
| Discord | 팀 내부 운영 | 사용자 공식 지원으로 사용하지 않음 |

목표 응답 시간은 팀 capacity 확인 전 보장하지 않는다. 자동 응답에는 접수 확인, 필요한 build ID·OS·재현 단계, 민감 정보 제거 안내를 포함한다.

## 6. 라이선스·크레딧

`docs/third_party_credits.csv`의 `status`는 다음 값만 사용한다.

| 상태 | 의미 |
| --- | --- |
| `POLICY_READY_SIGNATURES_PENDING` | 내부 권리 정책만 있고 실제 서명·증거는 대기 |
| `PLANNED_RELEASE_ATTRIBUTION` | 사용할 구성요소가 확정됐으나 실제 빌드 notice는 미검증 |
| `VERIFIED` | 원문 라이선스·권리·표기 문구 검토 완료 |
| `INCLUDED` | 특정 release build와 크레딧·notice에 반영 완료 |
| `BLOCKED` | 권리·출처·상업 이용 조건 문제로 반입 금지 |
| `EXCLUDED` | 제품 범위에서 제거, 배포물에 미포함 |

- 저장소 자체 코드·문서·아트는 별도 표기가 없으면 root `LICENSE`의 All Rights Reserved를 따른다.
- 저장소 표기와 Git 커밋은 개별 기여자의 상업 이용 허락을 대신하지 않는다. 내부 제작물은 [기여자 권리 증거 기준](contributor_rights.md)의 `rights_evidence_id`와 비공개 서명 기록을 가진다.
- 외부 폰트, 라이브러리, 브러시, texture, SFX, BGM, 플러그인은 `docs/third_party_credits.csv`에 등록한다.
- Godot Engine은 `GODOT_ENGINE`으로 선등록하고, 실제 export template의 엔진·제3자 고지를 배포 패키지와 크레딧에 반영한다.
- `license_id=TBD`인 에셋은 demo lock과 RC에 들어갈 수 없다.
- 수정 허용, 상업 이용, attribution 문구, 재배포 제한을 실제 license 원문으로 확인한다.
- 게임 내 크레딧, 배포 `THIRD_PARTY_NOTICES.md`, asset manifest의 `license_id`가 일치해야 한다.
- 생성형 도구를 사용한 자산은 도구·모델·사용일·원본 권리·수정 담당·상업 이용 근거를 evidence에 남기고 플랫폼 고지 요구를 출시 전에 재확인한다.
- `VERIFIED`는 라이선스 검토 완료, `INCLUDED`는 실제 build 반영 완료이므로 서로 대신하지 않는다.

## 7. 상점 기능 체크

상점 공개 전:

- [ ] 지원 OS·언어·입력과 실제 빌드 일치.
- [ ] Steam Cloud 조건 결과 반영.
- [ ] achievements, controller, Deck, online 기능을 잘못 체크하지 않음.
- [ ] 콘텐츠 고지 문구와 Steam 설문 일치.
- [ ] support email·개인정보 안내 링크 준비.
- [ ] credits·third-party registry에 `TBD` 없음.
- [ ] 포함된 내부 제작물의 `rights_ref`가 모두 `VERIFIED`.

RC 전:

- [ ] 네트워크 차단 상태에서 본편 필수 경로 시작·저장·종료.
- [ ] Cloud 포함 시 두 장치 충돌·롤백·삭제 검사.
- [ ] 진단 로그 export가 개인정보 금지 필드를 포함하지 않음.
- [ ] Steam Discussions와 support email 대응 리허설.
- [ ] 배포 패키지의 LICENSE·NOTICE·THIRD_PARTY_NOTICES 일치.
