# GGB 미확정 설정·이름·브랜딩 잠금 일정

## 1. 원칙

임시 명칭은 기획 탐색에는 유용하지만 파일 ID, 번역, 캐릭터 시트와 상점 제작이 시작된 뒤에는 변경 비용이 급격히 커진다. 아래 날짜는 콘텐츠 출시 약속이 아니라 **결정이 늦어질 때 해당 제작을 시작하지 않는 게이트**다.

결정 상태:

```text
OPEN → OPTIONS_READY → REVIEW → LOCKED
LOCKED → REOPENED  # 영향표와 beru 승인 필요
```

## 2. 잠금표

| ID | 결정 | 현재 | 책임·검토 | 필요일 | 늦으면 멈추는 작업 | 잠금 뒤 변경 비용 |
| --- | --- | --- | --- | --- | --- | --- |
| `LOCK_TITLE_PUBLIC` | 정식 게임명·영문명 | `ggb` 가칭 | beru / gatam·210 | 2026-08-14 | Steam AppID 표시명, 로고 탐색, 상점 카피 | 매우 높음: App·로고·검색·마케팅 전면 수정 |
| `LOCK_TAGLINE` | 한·영 한 문장 소개 | 초안 필요 | gatam / beru | 2026-08-21 | 상점 구조·트레일러 메시지 | 높음 |
| `LOCK_PROTAGONIST_PUBLIC_NAME` | 이름을 끝까지 `주인공`으로 둘지 화면명 부여 | 미정 | gatam / beru | 2026-08-21 | 대사 호칭·수첩 UI·번역 | 높음 |
| `LOCK_PROTAGONIST_AGE_BAND` | 정확한 나이 또는 공개 범위 | 소녀 연령대 | gatam / 210·beru | 2026-08-21 | 최종 신체 비율·콘텐츠 고지·상점 아트 | 매우 높음 |
| `LOCK_MARA_NAMES` | 마라 1·마라 2 최종 이름 | 임시명 | gatam / 210·NOne | 2026-08-21 | 대사 ID alias, 캐릭터 시트, 서명 cue | 매우 높음 |
| `LOCK_MARA2_APPARENT_AGE` | 아바타 외형 연령 인상 | 미정 | gatam·210 / beru | 2026-08-21 | 마라 2 최종 sheet·상점 노출 | 높음 |
| `LOCK_CHARACTER_PROPORTIONS` | 6인 키·실루엣·종족 비율 | 방향만 있음 | 210 / gatam | 2026-09-04 | portrait·pose 양산 | 매우 높음 |
| `LOCK_SIGNATURE_PALETTE` | 5인+SUBJECT 최종 화면 토큰 | 임시 HEX | 210 / beru·gatam | 2026-09-04 | 색 overlay·UI·접근성 QA | 중간~높음 |
| `LOCK_RENDERER` | Compatibility 또는 Forward+ | 시험 전 | beru / 210 | 2026-09-18 | 최종 shader·texture export | 매우 높음 |
| `LOCK_LOGO_KEY_ART` | 로고 구조·대표 구도 | 미정 | 210 / beru·gatam | 2026-10-09 | Steam capsule·trailer title card | 매우 높음 |
| `LOCK_DEMO_EDIT` | compact 또는 extended | A/B 대기 | beru / gatam | VS 뒤 5영업일 | 데모 최종 편집·번역·QA | 매우 높음 |
| `LOCK_PRICE` | 1.0 정가·출시 할인 | USD 14.99~19.99 가설 | beru | 2026-12-18 | 상점 가격·홍보 | 중간 |

기한을 넘겼는데 결정 근거가 없으면 상태를 임의로 `LOCKED`로 바꾸지 않는다. 연결 마일스톤을 `AT_RISK`로 갱신한다.

## 3. 이름 결정 기준

### 게임명

- 한국어·영어에서 읽고 검색하기 쉽다.
- 기존 주요 게임·브랜드와 혼동 위험을 조사한다.
- 고딕 저택, 루프, 기억 중 최소 한 정서를 전달하되 결말을 폭로하지 않는다.
- 16:9 capsule과 작은 라이브러리 capsule에서 식별된다.
- 파일·URL용 ASCII slug를 별도로 정한다.

### 주인공

화면명을 끝까지 숨기는 선택도 유효하다. 다만 `이름 미정`과 `의도적으로 이름을 공개하지 않음`은 다르므로 2026-08-21에 둘 중 하나를 잠근다. 이름을 숨기면 대사에서 반복되는 “주인공” 표기를 화면용 호칭으로 사용하지 않고 `아가씨`, `당신`, SUBJECT 등을 문맥에 맞게 쓴다.

### 마라 1·마라 2

- 최종 이름은 음절·첫 글자·실루엣 자막에서 구분되어야 한다.
- 별칭으로만 구분하지 않는다.
- 기존 `MARA1`, `MARA2` 내부 ID는 저장 호환을 위해 유지할 수 있다.
- 화면명 변경은 localization speaker table과 credits를 함께 갱신한다.

## 4. 색 잠금 기준

현재 HEX는 palette 후보이며 아래를 통과해야 최종이다.

1. S0 고딕 배경과 S3 시설 배경에서 모두 식별.
2. grayscale·색각 시뮬레이션에서 문양·선 패턴 병행.
3. 루카 검정과 이리스 흰색이 배경에 묻히지 않음.
4. 마라 1 빨강 보조색이 오류·위험 의미로 오인되지 않음.
5. 샘플 캐릭터 시트와 실제 renderer capture를 함께 검토.
6. UI 텍스트·focus·선택지 가치 판단에는 사용하지 않음.

## 5. 변경 요청

잠금 뒤 변경 PR에는 다음을 적는다.

```yaml
creative_lock_change:
  lock_id: LOCK_MARA_NAMES
  old_value: "..."
  new_value: "..."
  reason: "..."
  affected:
    - localization
    - portraits
    - audio_cues
    - store_assets
  estimated_rework_hours: 0
  owner_approval: beru
```

영향 목록과 재작업 용량이 없으면 잠금을 재개방하지 않는다.
