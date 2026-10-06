# GGB-ERR-2026-0045: 개발 F3 복사본 수첩 namespace 분류 누락

| 항목 | 값 |
| --- | --- |
| 유형 | 오류 ERR |
| 심각도 | 중간 |
| 해결 상태 | VERIFIED |
| 작업 상태 | DONE |
| 우선순위 | P2 |
| 담당자 | `Codex` |
| 목표 마일스톤 | `FULL_00_CONTENT_COMPLETE` |
| 최초 확인 | 2026-10-07 |
| 영역 | 수첩 scope / 개발 F3 재선택 복사본 |

## 원인과 영향

`SaveManager.create_f3_reselect_slot`은 개발 체크포인트에서도 `reselect_<random>` 슬롯을 만들고 `reselect_source_slot_id`를 보존한다. `basement_controller._make_session`은 이 출처로 개발 엔딩 프로필을 선택하지만 `notebook_host._current_scope`와 `_same_live_scope`는 슬롯명의 `__dev_` 접두사만 본다. 복사본의 수첩 편의 상태와 캐시가 full로 분류되며 출처가 제품/개발 사이에 바뀌어도 namespace 변경을 감지하지 못한다.

슬롯·run·branch 키가 따로 있으므로 이 발견만으로 실제 일반 슬롯 본문 유출이나 덮어쓰기를 주장하지 않는다. 개발 소비의 영역 분리 계약 불일치다.

## 해결과 검증

현재 namespace 계산을 commands의 순수 함수로 통일하고, 기존 개발 접두사 및 debug build의 개발 체크포인트 재선택 출처를 반영한다. 슬롯·run·원장 origin/branch는 바꾸지 않는다. host 생성/`_same_live_scope`·commands 토큰·비동기 작업자 모두 같은 계산을 사용한다. worker는 전달받은 snapshot의 출처만 읽고 live Node에 접근하지 않는다. 본편 writer나 개발 체크포인트 원본을 수정하지 않는다.

정상/개발 슬롯 × demo/full × 네 출처의 초기 집중 검사 52개 중 수정 전 7개 단언 실패. 이후 commands 대조를 추가한 68조건에서는 host만 수정한 중간 상태의 commands 불일치 4개를 따로 재현했다. worker 불일치도 비동기 저장 시험의 성공/summary/commit 3개 실패 단언으로 재현했다. 최종 공통 정책 68조건과 비동기 출처 저장·재로드 20조건 PASS. 실제 개발 F3 생성·로드 후 namespace/run/commands 검사를 기존 developer suite에 추가해 PASS했다. 최종 host 548개(비동기 저장 340개 포함) 종료 0/PASS. query 6,863개는 worker 추가 수정 전 회귀이며 그 뒤의 순수 정책·worker 변경은 집중/host 검사로 검증했다.

기존 잘못된 full 편의 파일은 자동 이관·삭제하지 않는다. 올바른 development 위치에서 초기화되며 본문·고정은 슬롯 snapshot에서 유지한다.

[NP22 검증 보고서](../validation/2026-10-07_갤러리개발소비_scope_대조.md).

```yaml
resolved_in:
  - game/scripts/systems/notebook_host.gd
  - game/scripts/systems/notebook_commands.gd
  - game/scripts/systems/notebook_save_worker.gd
verification_ids:
  - NOTEBOOK_SCOPE_CHECKS (68 focused checks)
  - DEV_COPY_ASYNC_RESULT (20 focused checks)
resolution_summary: retain developer checkpoint provenance in notebook namespace and live scope validation
verified_on: 2026-10-07
```
