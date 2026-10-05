# 수첩 저장 입구별 검증 대조

- 기준: develop `1223290`, 2026-10-05.
- 정본: [검토 계획](notebook_history_review_plan.md) 15절. [전체 ToDo](notebook_history_TODO.md)의 T26 하위 감사다.
- 검사 함수의 존재는 현재 실행 성공이나 각 행의 최종 완료를 뜻하지 않는다. 아래는 실제 코드와 검사 본문을 읽어 확인한 범위이며, 부족한 조건을 다른 입구의 PASS로 대체하지 않는다.

## 후속 완료 범위

2026-10-06: [ERR-0040](../items/GGB-ERR-2026-0040_미지원설계버전_저장덮어쓰기.md)에서 아래 표의 design revision 보호 부족분을 해결했다. 일반 저장/읽기/요약 × main/bak/tmp, F3 capture/읽기/정리 × main/bak/tmp와 비동기 수첩 저장 main/bak를 검증했다. 따라서 **아래 표는 최초 감사 기준의 목록이며, design revision의 해당 호출부는 더 이상 미검증 잔여가 아니다**. demo/full·갤러리 자체 형식·실제 용량/종료·선택 필드 조건은 여전히 남는다.

## 1. 입구와 증거

| 입구 | 구현 | 기존 검사에서 확인한 범위 | 남은 직접 확인 |
| --- | --- | --- | --- |
| 현재 progress | `SaveManager.load_slot`, `_promote_legacy`, `save_snapshot` | migration `_validate_primary`: 원본 checksum·결정적 UID·원본 별도 백업·두 번째 읽기 멱등성. `_validate_failure_and_future`: checksum 변조·미래 envelope/기록/원장·쓰기 실패 재시도. save-safety: 정상/손상/미존재 본파일의 승격 실패 복구 | 선택 필드 누락별 매핑, 알 수 없는 design revision의 읽기뿐 아니라 쓰기 보호, 실제 공간 부족과 중단 시점별 결과 |
| progress backup | `load_slot`의 복구 분기, `_failed_backup_recovery` | migration `_validate_backup`: 구형 bak·손상 main·임시 경로 쓰기 거부·재시도·원본 보존·새 branch. save-safety: 정상 백업 보존 | 복구 중 미래 tmp 보호는 신규 검사에 연결. 선택 필드 누락·미래 design·손상 조합 전체 및 복구 UI 실기 |
| F3 | `capture_f3_reselect`, `load_f3_reselect`, `create_f3_reselect_slot` | migration `_validate_f3*`: 정상 분기, tmp 단독 거부, main/tmp/bak의 미래 형식, 잘못된 본파일의 bak 보호와 승격 실패. reselect-presentation: 공개 기록과 커서의 새 branch 복원 | F3 선택 필드·checksum·용량 실패를 각각 해당 입구에서 확인. 일반 저장의 PASS를 그대로 이식하지 않음 |
| demo → full | `inspect_demo_import`, `import_demo_to_new_slot` | migration `_validate_demo`: namespace 전환·원본 바이트 유지·관찰 UID 유지·새 branch. 대상은 별도 빈 테스트 슬롯 | import 자체의 잘못된 checksum/지원 불가·대상 실패·반복 실행·용량 부족, 실패 후 불완전 대상 슬롯 취급 |
| 갤러리 | `EndingGalleryStore.read_entry`, `_read_path` | migration `_validate_gallery_and_development`: hash ID와 원본·현재 게임 불변. gallery `_legacy_and_damage`: 구형 열람·손상·미래 편의상태 보호 | 불변 payload 형식의 미래 버전과 편의상태 버전은 별개로 대조. 기록 생성 도중 종료·용량 부족, 원본과 캐시 경계 |
| 개발 체크포인트 | `developer_checkpoints.snapshot_for` 및 개발용 수첩 host | migration `_validate_gallery_and_development`: 동일 체크포인트의 결정적 snapshot | development scope와 실제 취득 증거 분리의 전 체크포인트 대조. 파일 checksum/디스크 용량은 메모리 fixture 생성에는 직접 적용하지 않고 개발 저장 입구에서 검사 |
| 미래 버전/알 수 없는 design | `_validate_save_text`와 각 호출자의 오류 처리 | 미래 schema를 읽기 검증에서 식별. F3 미래 후보 보호는 ERR-0037, 일반 progress 임시 후보는 신규 감사 | design 오류가 단순 손상으로 취급되어 쓰기/백업 fallback에서 사라지지 않는지 별도 확인. 미래 기록·원장·표시 커서 형식의 차이도 유지 |

검사 경로: `game/scripts/tests/notebook_migration_smoke.gd`, `notebook_save_safety_smoke.gd`, `notebook_gallery_smoke.gd`, `notebook_reselect_presentation_smoke.gd`. 구현 경로: `game/scripts/autoload/save_manager.gd`, `game/scripts/systems/ending_gallery_store.gd`.

## 2. 적용 범위

- 정상 읽기와 파일을 교체하는 이관/복구/저장을 분리한다. 미래 tmp는 확정 관찰의 출처로 채택하지 않지만 쓰기 시 지워도 되는 파일로 취급하지 않는다.
- 테스트의 `ERR_CANT_CREATE` 주입은 그 경계의 복구 동작 증거다. 실제 디스크 용량 부족·운영체제 종료·전원 차단과 동일한 시험으로 보고하지 않는다.
- 갤러리의 원본 불변 정책은 progress의 자동 승격 정책과 다르다. 모든 입구를 한 가지 변환 함수 성공 여부만으로 완료하지 않는다.
- 다음 종료 조건: 표의 각 부족분을 기존 실행 근거와 연결하거나 재현·보완하고, 적용 불가 조건은 해당 입력 형식의 근거를 붙인다. 현재 표 작성만으로 T26/Q13/AQ03/AQ04를 완료하지 않는다.
