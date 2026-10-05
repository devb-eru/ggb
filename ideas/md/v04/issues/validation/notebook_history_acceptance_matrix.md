# 통합 수첩 인수 항목 대조표

- 기준: develop `30a376b4a6ec207a5908e5bf4434c5bc7bba294f`.
- 정본: [검토·구현 계획](notebook_history_review_plan.md), [전체 ToDo](notebook_history_TODO.md).
- 목적: NB-Q01~20, NB-AQ01~18 각각의 코드 검사 위치와 남은 인수 증거를 연결한다. 이번 문서는 **완료 선언이 아닌 T26 중간 감사**다.
- 코드 파일명은 `game/scripts/tests/` 기준이다. 함수 검색은 검사 위치를 찾는 데 사용했으며 그 자체를 실행 PASS로 세지 않았다.
- `자동 근거 있음`: 연결 보고서의 명시된 범위만 실행 확인됨. 모든 요구의 동시 충족이나 실제 OS 입력을 뜻하지 않는다.
- `대조 필요`: 검사 소스는 있지만 요구의 모든 축과 실행 원자료를 최종 연결하지 못함. NOT_COVERED 0으로 취급하지 않는다.
- `실기 미완료`: headless로 대체할 수 없는 요구가 남음.

## 1. 읽은 현재 근거

| 묶음 | 근거와 적용 범위 |
| --- | --- |
| 조회·초기 화면·호스트 | [최초 화면 구성](2026-10-05_수첩_최초화면_중복구성_제거.md): query 4,675, view 223, host 548. 검색·공개·갤러리 하위 검사는 같은 query suite에 포함되지만 총수를 개별 인수 항목의 수로 나누지 않음 |
| 준비 중 손상 | [디스크 손상·복구](2026-10-05_수첩_진입중_저장손상_복구검증.md): opening 426. 처음부터 손상된 슬롯·정상 백업 fallback·OS 파일 잠금은 별개 |
| 일반 대사·모달 재개 | [최초 진입·완료 범위](2026-10-05_수첩_최초진입_비동기준비_검증.md), [완료 상태 보존](2026-10-05_보존한도_완료상태_복귀검증.md): 별도 프로세스와 완료 커서 경계. 모든 생산자의 모든 입력 조합 증거는 아님 |
| 관계 | [이리스 144조건](2026-10-05_이리스_관계수치_전조합_공개검증.md), [5인 선택 저장 재시도](2026-10-05_사용인_선택창_저장재시도_검증.md): 완료 시점 공개·저장. 이후 F2/엔딩의 모든 조합은 별도 |
| 선택·물리 수첩 | [현장 수첩 복귀](2026-10-05_현장수첩_선택창복귀_공개조건검증.md), [엔딩 결정 복귀](2026-10-05_엔딩결정_저장실패_복귀검증.md): 읽기/확정과 단순 조회의 경계 |
| 생산자·명칭 | [생산자 감사](../../../../../docs/notebook_producer_audit_validation.md), [공개 명칭](../../../../../docs/notebook_public_labels_validation.md), [전 버전 메타데이터](2026-10-05_수첩_메타데이터_전버전감사.md): 과거 보고서의 기준 패키지 실패와 후속 수정 PASS를 구별 |
| 성능 | [읽기 모델 비동기 갱신](2026-10-05_수첩_비동기모델갱신_검증.md), 최초 화면 구성 보고서: 병목 수정과 단일 탐색 표본. 정식 장비별 cold/warm 합격 자료가 아님 |

## 2. NB-Q 필수 시나리오

| ID | 요구 요약 | 코드 검사·기존 근거 | 남은 판정 / 담당 ToDo |
| --- | --- | --- | --- |
| NB-Q01 | 장 없는 과거 기록 전부 조회·원본 보존 | `notebook_query_smoke.gd::_test_legacy_and_damage`, legacy-notes 하위 suite | 자동 근거 있음. 구형 실제 저장 입력과 Q02의 혼합을 최종 묶음 대조 / T26 |
| NB-Q02 | 미등록 장도 조회 가능·자동 삭제 금지 | query의 legacy/damage, browse·metadata suite | 대조 필요. 장 없는 경우와 미등록 장을 별도 행으로 증거화 / T26 |
| NB-Q03 | 장 이름 한영·내부 ID 없음 | metadata 전 버전 보고서, query·browse | 자동 근거 있음. 컨트롤러 실제 화면 전편 검수는 별개 / T25·T26 |
| NB-Q04 | 정상 2개+잘못된 변수 1개 부분 경고 | query `_test_legacy_and_damage`, 원본 snapshot validator | 자동 근거 있음. 조회 허용과 손상 저장 로드 거부를 혼합하지 않고 최종 대조 / T26 |
| NB-Q05 | J3/D4/D5/E6/F0 사건 당시 장 | chapter/mirror/basement/fracture/settlement/core 생산자 suite | 전체 경계의 독립 경로 합집합 대조 필요 / T10~T19 |
| NB-Q06 | 빈/1개 기록 초기 포커스·닫기·포커스 격리 | query `_test_panel`, host `_prologue`, opening suite | 자동 근거 + 실기 미완료 / T22 |
| NB-Q07 | 출처 이동 후 대사·스크롤·필터·포커스 복원 | view `_navigation_restore`, `_body_and_store`; 최초 화면 구성 | 자동 근거 + 실제 키보드 경로 미완료 / T22 |
| NB-Q08 | 조회 전체 상태 불변·핀은 허용 필드만 | query, host `_commands`, async-save, migration `_validate_commands` | 자동 근거 있음. 전체 쓰기 경로 허용목록 최종 대조 / T21·T26 |
| NB-Q09 | 리셋 뒤 지식 유지·물리 복원·자동 숏컷 금지 | chapter-one-notes, fracture, 휴식 리셋 보고서 | 자동 근거 있음. 전환별 필수 경로 최종 합집합 / T11·T13 |
| NB-Q10 | 비공개 이름·기록의 제목/검색/건수/링크 차단 | query `_test_disclosure`, memory-disclosure, metadata | 자동 근거 있음. 전 생산자 공개 경계 대조 / T10~T19 |
| NB-Q11 | 새 기록 현재 언어·legacy 당시 원문 안내 | query·metadata·legacy-notes, 생산자 버전 재생 | 자동 근거 있음. 저장 불변과 UI 번역 검사를 분리해 최종 대조 / T26 |
| NB-Q12 | 일반 2000·보호/legacy/출처/핀 별도 유지 | archive `_validate_retention/_validate_protection_index`, migration `_validate_retention_commit`, person-retention | 대조 필요. 소비자별 보호 원문과 전체 부하 fixture를 Q12/AQ06/AQ15로 나눠 연결 / T24·T26 |
| NB-Q13 | 이관 반복·중단·손상·원문 보존 | migration `_validate_primary/_validate_failure_and_future/_validate_backup`; save-safety | 대조 필요. 계획 15절 모든 저장 입구별 정상/손상/미래 버전 행렬 / T26 |
| NB-Q14 | 선택 중 조회·Enter/Esc 복귀 중복/자동확정 금지 | modal-presentation, host `_pause_points`, 관계/엔딩 선택 복귀 | 자동 근거 + 실제 OS 키 입력 미완료 / T12·T22 |
| NB-Q15 | B2 숨기·Alt+Tab 시 월드 중단 | host `_pause_points`, 자연 서재 방문 조건 보고서 | 실제 Alt+Tab과 방문 결과/타이머 동시 검사 미완료 / T22·T23 |
| NB-Q16 | 현실 로그 재열람은 field_read 등 불변 | reality `_field`, host `_physical`, 현장 수첩 보고서 | 자동 근거 있음. 두 엔딩 실제 진행 경계와 연결 / T16·T23 |
| NB-Q17 | 물리 수첩 확인/다음 장은 기존 읽음·해금 유지 | 현장 수첩 144경로, reality suite | 자동 근거 있음. 순수 재열람과 실제 읽기 완료 최종 경로 분리 / T16 |
| NB-Q18 | 슬롯/과거 저장 간 핀·미래 정보 격리 | host scope guards, migration F3/demo, gallery·reselect | 자동 근거 있음. 저장 입구별 최종 대조 / T17·T26 |
| NB-Q19 | 200%·한영·해상도·IME·색 제거 | view·visual·search 자동검사 | 실제 Windows 배율/IME/색 제거 화면 인수 미완료 / T22 |
| NB-Q20 | 모든 장 마우스/키보드 전용 완료 | 실제 완주 검증이 필요. headless 호출로 대체 불가 | 실기 미완료 / T23 |

## 3. NB-AQ 추가 인수

| ID | 요구 요약 | 코드 검사·기존 근거 | 남은 판정 / 담당 ToDo |
| --- | --- | --- | --- |
| NB-AQ01 | 핀 실패/응답 유실/강제 종료 뒤 prune | async-save, migration `_validate_commands/_validate_retention_commit` | 자동 근거 있음. 강제 종료 복구와 정리의 연속 시나리오 증거 대조 / T21·T26 |
| NB-AQ02 | 같은 sequence의 과거 분기 대사는 다른 UID | archive, query `_test_revisions`, migration F3 | 대조 필요. 핀과 검색 앵커 각각의 오연결 반례 확인 / T26 |
| NB-AQ03 | demo/full/F3/백업에 미래 편의상태 역유입 금지 | migration `_validate_f3/_validate_demo/_validate_gallery_and_development`, view store | 자동 근거 있음. namespace·run·branch·load_epoch 별 검증 행렬 정리 / T17·T26 |
| NB-AQ04 | 모든 저장 형식 정상/손상/미래/이관 중단 | migration, save-safety, gallery `_legacy_and_damage` | 대조 필요. Q13과 같은 저장 입구 행렬을 공유하되 checksum·UID·원본 검사를 별도 열로 구분 / T26 |
| NB-AQ05 | 안 본 뒷면은 검색/비교/페이지/대체 설명에도 없음 | query `_test_disclosure`, visual, metadata 부분 공개 | 자동 근거 있음. 실제 최초 공개 생산자와 자료 연결 대조 / T10~T19 |
| NB-AQ06 | 출처 보호·정리된 앵커 안내 | archive·person-retention·investigation `_test_sources`, view 복원 | [소비자별 대조](2026-10-06_출처보호_소비자별_감사.md)와 [반증/갤러리 결합](2026-10-06_대량정리후_가설갤러리_출처이동.md) PASS. 대표 한국어 경로의 headless 버튼 검증이며 전체 본편 출처 공급과 실제 입력은 별도 / T26i·T26j·T10~T19·T22 |
| NB-AQ07 | 의미 변경·최종 공개 후에도 과거 revision 불변 | query `_test_revisions`, public-labels 버전 보존, J4/field 재생 | 자동 근거 있음. J5/F1 실제 전환과 옛 일지 조합 대조 / T15·T26 |
| NB-AQ08 | 재방문/다른 선택만 새 발생, 재표시는 멱등 | surface-resume, presentation, chapter 반복 조사, Iris 전조합 | 자동 근거 있음. 나머지 생산자별 실제 발생/재표시 구분 / T10~T19 |
| NB-AQ09 | 자유 메모 제외, 기존 A1/SUBJECT 유지 | self-mark, authority-archive, view store·입력 메뉴 | 대조 필요. 저장 스키마/입력 필드 정적 목록과 A1/SUBJECT 실행 증거 결합 / T26 |
| NB-AQ10 | P/A1/A2/D5/E1/E2/F1 정체·루프 암시 순서 | memory-disclosure, prologue/fracture/final 생산자 | 자동 근거 + 실제 전편 화면/검색 검수 미완료 / T10~T19·T22 |
| NB-AQ11 | 요청한 힌트만 공개·실패 재시도·검색 | 힌트 분기·저장 실패 전구간 보고서, content suite | 자동 근거 있음. 최종 필수 호출 목록 대조 / T18 |
| NB-AQ12 | B4/C5/D4 다중 묶음·두 칸·확대·초안 보존 | host `_visual_materials`, visual·investigation | 자동 근거 + 실제 키보드 3자료 비교/200% 미완료 / T22·T23 |
| NB-AQ13 | 51행·필터 끝·갱신·언어 변경 안정성 | query `_test_order_cache`, view restore, search, host refresh | 자동 근거 있음. 긴 검색 및 실제 포커스 검사와 연결 / T22·T26 |
| NB-AQ14 | n/N·IME·Esc·Alt+Tab·예약 후 슬롯 변경 | host/opening input guards, query/search UI | 자동 scope 검사는 있음. IME·OS 입력의 한 계층 소비 미완료 / T22 |
| NB-AQ15 | 일반 2001+보호 2001+legacy10000 모두 보존 | archive retention, migration `_validate_retention_commit(true)` | [혼합 저장 검사](2026-10-06_혼합기록_저장보존_검증.md) PASS. 일반 초과 1개만 정리, 저장 거부/응답 유실/reload 검증. 성능 인수는 별도 미완료 / T24·T26h |
| NB-AQ16 | 22생산자·전 분기·한영·미매핑/미실행/ID 노출 0 | 생산자별 suite·카탈로그 감사·ERR-0026 | 전체 필수 경로 합집합·분모 확정과 실제 화면 미완료 / T10~T19·T25 |
| NB-AQ17 | 저장 객체 불변과 현재 언어 표시를 별도 비교 | query metadata/legacy, 생산자 과거 버전 재생 | 자동 근거 있음. 모든 저장 입구의 원본 바이트/객체 검사 연결 / T26 |
| NB-AQ18 | fixture·장비·cold/warm p95·메모리·프레임 | performance/lifecycle probe, 비동기/화면 구성 보고서 | 명시적 미완료. 현재 단일 headless 표본으로 대체 불가 / T20·T21·T24 |

## 4. 다음 작업의 종료 조건

2026-10-06: [ERR-0040](../items/GGB-ERR-2026-0040_미지원설계버전_저장덮어쓰기.md)의 design revision 보호를 일반/F3/비동기 저장에 적용하고 18조건·worker 두 조건을 검증했다. [실제 Windows 입력](2026-10-06_수첩_닫기_실제입력_재검증.md)도 사용자 잠금 해제 확인 후 재개해 ERR-0031 닫기 겹침을 종결했다. 아래 실기 대기는 잠금 해제 대기가 아니라 남은 IME·전편·접근성 시험이며 전체 인수 완료는 아니다.

[저장 입구별 구현·검사 대조](notebook_history_save_entry_matrix.md)를 분리했다. 그 과정에서 일반 progress의 미래 tmp 덮어쓰기 [ERR-0039](../items/GGB-ERR-2026-0039_progress_미래임시파일_덮어쓰기.md)를 재현·수정했다. 저장/이관/복구 × 미래 세 형식의 아홉 fixture와 확정 저장 읽기가 통과했다. 다른 저장 형식과 design revision·실제 공간 부족/종료 조건은 아직 남아 있다.

백업 교체 경계에서는 [ERR-0038](../items/GGB-ERR-2026-0038_F3_잘못된본파일이_정상백업을_덮어씀.md)을 재현·수정했다. 현재 run의 유효한 F3만 bak를 대체하며, 손상·비F3·다른 run·정상 본파일 네 조건을 정상 저장과 마지막 승격 실패 각각에서 검사했다. bak 바이트·확정 snapshot 복구와 기존 이관/재선택/기본 모드 집중 검사가 통과했다. 이는 Q13/AQ04의 F3 백업 교체 하위 근거이며 모든 저장 입구나 실제 전원 차단 검증을 대신하지 않는다.

후속 쓰기 감사에서는 [ERR-0037](../items/GGB-ERR-2026-0037_F3_미래버전_보조파일_덮어쓰기.md)을 재현·수정했다. capture가 미래 tmp/bak를 덮어쓰던 문제이며, 세 파일 × 세 미래 형식의 거부·전체 파일 바이트 보존과 이관/재선택 복원이 통과했다. 읽기에서 tmp를 제외하는 것만으로 쓰기 시 미래 데이터 보존을 충족하지 않으므로 별도 행으로 추적한다.

저장 입구 대조를 실제 코드까지 진행해 [ERR-0036](../items/GGB-ERR-2026-0036_F3_미확정임시파일_재선택채택.md)을 발견·재현·수정했다. F3의 유효한 tmp가 확정 bak보다 우선 채택되던 결함이다. 수정 후 migration과 reselect-presentation이 통과했다. 이 구체적인 반례는 기존 migration PASS만으로 Q13/AQ04 전체 합격을 선언할 수 없음을 보여 준다. 해당 tmp 단독/우선 채택 조건은 이제 검증됐지만 아래 저장 형식 전체 행렬은 여전히 남는다.

1. **저장 입구 행렬(Q13/AQ03/AQ04)**: 계획 15절의 각 형식을 migration/save-safety/gallery의 실제 함수·fixture·로그와 연결한다. 누락된 정상/손상/미래 버전·중단만 새로 실행하며 기존 검사와 동일한 시나리오를 다시 작성하지 않는다.
2. **보호 소비자 행렬(Q12/AQ06/AQ15)**: 일반/보호/legacy 합계와 여섯 소비자별 출처 유지·해제 조건을 실제 검사와 비교한다. fixture 이름이나 단언 총수만으로 합격시키지 않는다.
3. **생산자(T10~T19/AQ16)**: 각 생산자의 실제 진입/표시/실패/반복 호출을 분모로 확정하고 기존 tuple 결과와 차집합을 구한다. 허용 node 카탈로그의 전체 곱집합을 필수 분모로 삼지 않는다. 관계 수치 전조합을 다른 사건 완료로 재사용하지 않는다.
4. **성능(T20/T21/T24)**: 남은 지연 구간을 실제 수치로 분리하고 개선한다. 계획의 4개 fixture·한영·장비별 cold 20/warm 100, 50회 열기/닫기, 60초 프레임·Alt+Tab 5회는 최종 인수에서 그대로 남긴다. 미보유 장비는 NOT_COVERED다.
5. **실기(T22/T23)**: 사용자 잠금 해제 확인 후 격리 세이브에서 T22a 닫기 재검증을 수행했다. 나머지 IME·전편·접근성·Alt+Tab은 각각 실제 증거를 남겨야 하며 재개 시 입력 가능 상태를 다시 확인한다.

이 표는 인수 요구 38개의 추적 누락을 줄이는 산출물이다. 원래 NB-R01~10/NB-P01~18의 구현·정본 동기화, 계획 12·16절 산출물, 17절 측정 명령·불변 조건 전체의 최종 승인도 T26에 유지한다. 문서만 추가하고 T26을 완료시키지 않는다.
