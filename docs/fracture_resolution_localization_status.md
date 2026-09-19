# 파열 후 결산 구간 현지화 현황

## 기준일

2026-09-19

## 범위

J4, E3_4M, E5, E6의 조사 종료 확인, 네 번째 일지 복원, 최소 접근 절차, 관계 등급별 마지막 저녁, 선택형 후속 반응과 코어 경로 진입을 한국어와 영어로 표시한다. 관계 사건 완료 수, 기록 단계, 관계 증감, 후속 사건의 선택성, 코어 경로의 일방향 진입 계약은 변경하지 않는다.

## 구현

- fracture_resolution_display_texts.gd가 결산 구간의 위치·목표·버튼·상태판·확인창·피드백과 수첩 재열람 문구를 담당한다.
- J4 조사 종료 확인은 완료 수, 연구원 기록 수, 미완료 사용인, 예상 시간과 에드가 최소 절차 여부를 선택 언어로 조합한다.
- J4의 네 날짜 조각, 현재 배열, 기본·확장·완전 본문을 번역한다. 저장된 한국어 정본은 유지하고 수첩 표시 시 기존 관계 기록 번역과 합성한다.
- E5의 LOW·MID·HIGH·ALL 착석 장면, 완료·미완료 사용인 문장, 관계 결과 오버레이, 이리스의 공개 범위와 세 공동 질문을 번역한다.
- E6의 마라 2 이름 후속, 에드가 문 앞 점검, 후속 생략, 일방향 진입 확인을 번역한다. 후속 선택은 엔딩 선택으로 해석하지 않는다.
- 내부 위치 ID가 드러나던 식당과 보안 기계실 머리글을 사람이 읽는 영어 이름으로 변환한다.

## 검증

- Godot 4.7.2 프로젝트 가져오기: PASS
- BASEMENT_SESSION_SMOKE: PASS
- FULL_CAMPAIGN_SMOKE: PASS
- Windows OpenGL BASEMENT_SESSION_SMOKE: PASS
- 영어 화면 캡처: user://j4_ordering_english.png, j4_confirmation_low_english.png, j4_confirmation_english.png, e5_confirmation.png, e6_confirmation.png

자동 검사는 J4 원문·동적 배열·LOW와 ALL 종료 요약, J4_FULL 수첩 재열람, E5 네 관계 등급과 세 질문, E6 조건부 후속·확인창, 한국어 정본 보존을 확인한다. 기존 32개 관계 완료 조합, J4 세 본문 단계, 에드가 최소 절차, E5 등급, 후속 관계 증감, F0 진입과 저장 재개도 함께 통과했다.

Windows 2560×1600 캡처에서 가장 긴 LOW 종료 요약과 J4 페이지, E5·E6 확인창이 영역 안에 표시되는 것을 확인했다. M1_DINING_ROOM, H0_CLOCK_MACHINE 내부 ID는 각각 Dining Room, Security Machine Room으로 표시된다.

## 남은 범위

전편 영어 화면의 잔여 한국어·내부 ID 노출을 별도 감사하고 영어 완주 회귀를 확정해야 한다. 그 뒤 관계 LOW, MID, HIGH, ALL 전편 경로와 Windows 마우스 전용·키보드 전용 실제 완주를 순서대로 검증한다.
