# GGB 프롤로그·EP01·EP02 스토리 검토

검토일: 2026-11-06 · 기준: 연결된 Google Sheets의 현재 원문과 진행·조건·효과 표

세 시트의 플롯, 대상별 대사·관계·호감, 퍼즐 단서와 실패·재진입을 검토했다. 시트와 게임 파일은 변경하지 않았다. 대체 문구는 수정 제안이며 확정 원문이 아니다.

**인물명은 사용자 확정대로 마라 1=마라, 마라 2=비피로 사용한다.** 출처의 원문 인용과 `SERVANT_MARA1/2` 같은 기술 ID에는 기존 표기를 남겼다.

## 먼저 볼 항목

큰 플롯은 일과의 이상 징후를 체험하고, 반복을 직접 검증한 뒤, 저택의 기능과 자신의 신체를 발견하는 순서로 이어진다. 일과에서 배운 천·순서·문양이 뒤의 퍼즐에 다시 쓰이고, 에드가의 권한과 책임, 마라의 보존, 루카의 돌봄, 이리스의 감각, 비피의 이름과 결손이 서로 다른 질문을 만든다는 점은 유지할 만하다.

우선 고칠 것은 더 많은 설명을 추가하는 일보다 **실제로 본 사실·선택한 행동·대사가 인정하는 사실을 맞추는 일**이다. 다음 항목이 발견의 신뢰와 퍼즐의 공정성에 직접 영향을 준다.

| 항목 | 우선 조치 |
| --- | --- |
| [CROSS-01](#cross-01) | 이름표·대사·진단 채널의 표시명을 마라·비피로 맞춘다. |
| [P00-03](#p00-03) | 장부 발견 장소와 수첩에 기록되는 낙서의 관찰을 맞춘다. |
| [EP01-02](#ep01-02) | 표식 확인을 마친 아침 안에 다시 삽입된 밤·기상을 정리한다. |
| [EP01-03](#ep01-03) | 문장·도형·잉크 중 고른 표식만 확인 대사에 반영한다. |
| [EP01-04](#ep01-04) | 호감이 낮아도 필수 시간 단서는 같은 사실을 전달한다. |
| [EP01-10](#ep01-10), [EP02-14](#ep02-14) | 극중 발화·독백에 남은 ‘주인공’ 지칭을 정리한다. |
| [EP02-01](#ep02-01) | 주방을 먼저 조사해도 아직 얻지 않은 단서·정답을 먼저 말하지 않는다. |
| [EP02-03](#ep02-03) | 호감·경계가 변하는 보존/삭제 선택의 목적어를 분명히 한다. |
| [EP02-06](#ep02-06) | 비피의 셋째 음 소실인지, 셋째 음 뒤 공백인지 통일한다. |
| [EP02-09](#ep02-09), [EP02-10](#ep02-10) | 검증된 계획·도구 회수·당일 실패가 연결되는 규칙을 확정한다. |

## 검토 기준과 범위

| 원본 | 현재 대사 정본 | 노드 행 | 개별 의견 |
| --- | --- | ---: | ---: |
| [프롤로그](https://docs.google.com/spreadsheets/d/1rUrohB4V_zdzkrJlPRBWq_ZCrWImoihkc7AM5kgO0Ys/edit#gid=1910202603&range=B4:AL249) | `09_Runtime_Master` | 246 | 13 |
| [EP01 · 반복과 시계망](https://docs.google.com/spreadsheets/d/1cHx28-B4lG-p9iMyxt7HkQ4Dgk9QeI14UiAJC512v5w/edit#gid=497322651&range=B4:AL560) | `09_Runtime_Master` | 557 | 17 |
| [EP02 · 검은 거울](https://docs.google.com/spreadsheets/d/1IPKDxXgujecsgbn3hnD6sfCYqwcXdr1cZd3icv0_mZI/edit#gid=844893755&range=B4:AL493) | `09_Runtime_Master` | 490 | 14 |

공통 의견 3건을 포함해 중복을 정리한 의견은 **47건**이다. 원문 오류 9건 · 시트 명세 오류 4건 · 설정 확인 12건 · 보완 22건.

- **원문 오류**: 현재 문장·관찰·선택이 서로 맞지 않는 항목이다.
- **시트 명세 오류**: 연결·완료·기록 표와 집필된 내용이 맞지 않는 항목이다. 실제 게임의 현재 오류를 뜻하지 않는다.
- **설정 확인**: 작가 의도·연출·별도 실행 계약에 따라 판정이 달라지는 항목이다.
- **보완**: 성립하는 장면의 동기·감정·전달을 더 분명하게 만드는 제안이다.

확인한 대사 정본은 총 1,293개 노드 행이다. 프롤로그와 EP01에 중복된 첫 취침·아침 36개 행을 포함하므로 고유 대사 수와 같지는 않다. 숨김 Legacy·복제 탭은 현재 정본으로 취급하지 않았다.

기존 결정과 구현 기록도 대조했다. A1 반응을 다음 아침 표식 확인 때 재생하는 정책, 첫 취침·아침의 EP01 우선, 프롤로그 P4 공식 응답 6줄 재생 보정은 존중했다. 시트의 `NOT_CONNECTED`나 오래된 QA 상태만으로 게임 미구현을 판정하지 않았다. 이번 작업에서 게임을 재실행하거나 모든 분기를 직접 재플레이하지는 않았다. 아래 ‘수정 후 확인’은 완료한 테스트 결과가 아니라 수정 시 사용할 검증 조건이다.

## 에피소드 간 연결

일과의 이상 징후 → 반복의 검증 → 신체·인격 채널의 발견이라는 큰 흐름은 이어진다. 이름, 기억의 범위, 관찰에서 해석으로 넘어가는 시점을 맞추면 각 장의 발견이 더 선명해진다.

<a id="cross-01"></a>
### CROSS-01 · 마라·비피의 표시명

높음 · 보완 · 인물명

- [프롤로그 / 09_Runtime_Master!S170:S171](https://docs.google.com/spreadsheets/d/1rUrohB4V_zdzkrJlPRBWq_ZCrWImoihkc7AM5kgO0Ys/edit#gid=1910202603&range=S170:S171) · `P3B_MARA1 / P3B_MARA2` — 초상화 이름표에는 ‘마라 1 · MAINT’, ‘마라 2 · ARCHIVE’가 표시된다.
- [EP01 · 반복과 시계망 / 09_Runtime_Master!S126:S127](https://docs.google.com/spreadsheets/d/1cHx28-B4lG-p9iMyxt7HkQ4Dgk9QeI14UiAJC512v5w/edit#gid=497322651&range=S126:S127) · `EP01_AS_MARA2_005 / 006` — 같은 기록 담당 인물을 서술과 호칭에서 ‘비피’라고 부른다.
- [EP02 · 검은 거울 / 09_Runtime_Master!S416:S423](https://docs.google.com/spreadsheets/d/1IPKDxXgujecsgbn3hnD6sfCYqwcXdr1cZd3icv0_mZI/edit#gid=844893755&range=S416:S423) · `EP02_C5_CH_MARA1_FIRST / EP02_C5_CH_MARA2_FIRST` — 진단 채널은 다시 ‘마라 1’, ‘마라 2’로 표시된다.

**문제와 영향**  사용자가 2026-11-06 검토 중 확정한 이름은 마라 1=마라, 마라 2=비피다. 현재 시트 표시명은 이 결정과 섞여 있다. 이름과 기억을 다루는 이야기라 두 이름의 혼용은 의도된 정체성 단서로 오인되기 쉽다. 초상화에서 배운 인물과 일상 대화·진단 채널의 인물이 동일한지 불필요하게 추론해야 한다.

**보완안**  플레이어에게 보이는 이름표·문서·대사·감각 자막은 ‘마라’, ‘비피’로 맞춘다. ‘마라 1/2’는 제작용 구분으로만 남긴다. SERVANT_MARA1/2, 기존 node_id·저장 키는 표시명과 분리해 유지한다. 이 보고서의 인물별 평가도 확정 이름을 사용한다.

**수정 후 확인**  프롤로그 이름표 → EP01 일상 → EP02 진단 채널을 연속해서 읽었을 때 동일 인물이 같은 이름으로 인식되고, 기술 ID 참조는 유지되는지 확인한다.

<a id="cross-02"></a>
### CROSS-02 · 아버지에 대한 기억과 선택 기억의 결론

보통 · 설정 확인 · 플롯·기억

- [프롤로그 / 09_Runtime_Master!S14](https://docs.google.com/spreadsheets/d/1rUrohB4V_zdzkrJlPRBWq_ZCrWImoihkc7AM5kgO0Ys/edit#gid=1910202603&range=S14) · `P1_INSPECT_PHOTO` — 얼굴은 익숙하지만 사진의 장면으로 이어지는 기억은 없다고 말한다.
- [EP01 · 반복과 시계망 / 09_Runtime_Master!S148:S149](https://docs.google.com/spreadsheets/d/1cHx28-B4lG-p9iMyxt7HkQ4Dgk9QeI14UiAJC512v5w/edit#gid=497322651&range=S148:S149) · `EP01_A1_AFTER_002 / 003` — 아버지와 함께 본 연극, 여운이 남는 극을 좋아하던 취향을 구체적으로 떠올린다.
- [EP02 · 검은 거울 / 09_Runtime_Master!S30:S32](https://docs.google.com/spreadsheets/d/1IPKDxXgujecsgbn3hnD6sfCYqwcXdr1cZd3icv0_mZI/edit#gid=844893755&range=S30:S32) · `EP02_C0_FATHER_007~009` — 에드가가 ‘기억나는 게 하나라도’ 있는지 묻자 주인공은 침묵한다.
- [EP02 · 검은 거울 / 09_Runtime_Master!S175:S180](https://docs.google.com/spreadsheets/d/1IPKDxXgujecsgbn3hnD6sfCYqwcXdr1cZd3icv0_mZI/edit#gid=844893755&range=S175:S180) · `EP02_J3_MEMORY_001~003 / EP02_J3_COMMIT_002` — 문을 그리는 손의 기억은 선택 조사지만 완료 독백은 공통으로 ‘이 집과 문을 만든 사람’의 책임을 말한다.

**문제와 영향**  사진 한 장의 기억이 없다는 것과 아버지에 대한 모든 기억이 없다는 것은 다르므로 그 자체가 모순은 아니다. 다만 EP01의 구체적 회상 뒤 EP02의 포괄적 질문·침묵이 이어지면 기억 회복의 정도가 뒤로 돌아간 듯 보인다. J3는 선택 기억을 생략해도 동일한 책임 판단에 도달한다. J1의 집 설계 기록은 근거가 되지만, 집의 설계·문의 제작·현재 잠금 책임을 같은 사실로 묶는지는 확인이 필요하다. 주인공이 무엇을 기억하고 무엇을 기록에서 추론하는지 흐려져 아버지를 향한 신뢰와 의심의 변화가 편의적으로 느껴질 수 있다.

**보완안**  사진 장면·감각 기억·연극 일화·연구 기록에서 얻은 사실을 집필 기준에서 구분한다. 에드가의 질문은 ‘지금 그분이 무엇을 원하시는지 기억하십니까?’처럼 쟁점을 좁히거나, 기존 질문 뒤 주인공에게 ‘기억나는 장면은 있다. 그게 지금의 아빠를 설명하지는 못한다’는 반응을 준다. J3 기억 미열람 시에는 ‘이 집의 형태를 고른 사람. 이 문에도 그 책임이 닿아 있는 걸까’처럼 추론으로 두고, 열람 시 감각을 연결한 독백을 사용한다.

**수정 후 확인**  P4 기억 확인/추가 질문 유무, A1 표식 세 종류, J3 기억 건너뛰기/열람 경로에서 새로 확인한 정보만 독백의 근거가 되는지 읽어 본다. 기억 단편의 존재를 곧 완전한 기억 회복으로 처리하지 않는다.

<a id="cross-03"></a>
### CROSS-03 · 프롤로그 문양 기록과 EP02 정체 발견

보통 · 보완 · 복선·정보 공개

- [프롤로그 / 09_Runtime_Master!S46:S50](https://docs.google.com/spreadsheets/d/1rUrohB4V_zdzkrJlPRBWq_ZCrWImoihkc7AM5kgO0Ys/edit#gid=1910202603&range=S46:S50) · `P3B_HINT / P3B_PATTERNS / P3B_NAME` — 외형·프레임·기능 라벨을 맞추며 다섯 문양을 관찰한다.
- [프롤로그 / 09_Runtime_Master!S142](https://docs.google.com/spreadsheets/d/1rUrohB4V_zdzkrJlPRBWq_ZCrWImoihkc7AM5kgO0Ys/edit#gid=1910202603&range=S142) · `NOTE_P_SIGNATURES` — 수첩은 관찰을 ‘다섯 사용인의 데이터 서명’이라고 정리한다.
- [EP02 · 검은 거울 / 09_Runtime_Master!S145:S152](https://docs.google.com/spreadsheets/d/1IPKDxXgujecsgbn3hnD6sfCYqwcXdr1cZd3icv0_mZI/edit#gid=844893755&range=S145:S152) · `EP02_C5_INFO_001~EP02_C5_REQUIRED_001` — 진단면에서 인격 채널 5와 시뮬레이션 밖 신체의 의미를 본격적으로 해석한다.

**문제와 영향**  프롤로그의 문양·기능명 노출은 유효한 복선이다. 다만 주인공 수첩이 처음부터 ‘데이터 서명’으로 확정하면, 낯선 업무 문양이 나중에 인격 채널로 재해석되는 발견의 폭이 작아진다. 세계가 디지털임을 초반부터 명시하는 의도라면 오류는 아니다. 플레이어가 관찰보다 앞선 해설을 받으며, C5의 폭로가 새로운 인식보다 이미 아는 정보의 확인으로 약해질 수 있다.

**보완안**  프롤로그 기록은 ‘다섯 이름과 업무 문양. 색이 없어도 모양과 소리로 구별된다’로 관찰 범위에 맞춘다. C5 이후 같은 기록을 다시 볼 때 ‘이 문양이 인격 채널의 서명이었다’는 새 주석을 붙인다. LOCK/MAINT/BIO/CLIMATE/ARCHIVE와 비색상 단서는 유지한다.

**수정 후 확인**  처음 플레이하는 독자가 P3B에서는 업무·문양 대응을, C5에서는 그 대응의 정체를 새로 이해할 수 있는지 확인한다. 접근성 정보를 숨겨 미스터리를 만드는 방식은 피한다.

초상화 정리에서 다섯 음의 대응을 이미 들려주는 연출이 있다면 그 출처를 명세에 연결한다. 소리 대응의 접근성 설명과 주인공이 정체를 알아낸 시점은 구분한다.

## 프롤로그

일과를 통해 다섯 사용인과 저택의 규칙을 익히고, 사물의 반복·신체 기억·기억 보존을 의심하게 만드는 도입 구조는 일관된다. 우선 정리할 것은 장부 관찰과 수첩의 사실 불일치, P4 6줄 응답을 반영하지 못한 시트 연결 명세, 첫 취침 복제 원문의 시간 전환 표기다. 이미 검증된 게임 어댑터 수정은 미해결 실행 오류로 재분류하지 않았다.

| 검토 구간 | 평가 |
| --- | --- |
| 플롯·진행 | P1→P2/P3/P3B 자유 순서→P4→선택 P5→P6→첫 반복을 확인. 신체와 저택을 병치하는 도입은 유효. 주인공이 일과를 받아들이는 이유와 차 준비 추가 시점은 보완 여지가 있다. |
| 에드가·아버지 | 일과 안내의 절제, 아버지 권한의 우선, 기록 접근 거부가 일관된다. 사진 속 익숙한 얼굴과 차 장면에서 얼굴이 떠오르지 않는 것은 인물 인지와 일화 기억의 차이로 읽을 수 있어 확정 모순으로 보지 않았다. |
| 마라 | 과장된 도구 농담과 실패 복구 안내가 성격·튜토리얼에 함께 기여한다. 수첩의 정밀 관찰을 실제 표시와 맞출 필요가 있다. |
| 비피 | 이름·역할·외형을 짝짓는 활동과 놀리는 말투가 연결된다. 자유 순서에서 '늦었다'의 맥락, 주인공이 기술 용어를 아는 시점을 점검할 것. |
| 루카 | 맥박·손의 습관·같은 날짜 발언을 통해 돌봄과 불안을 연결한다. 아버지 차 6줄의 감정 전환과 1문답 제한이 중요. |
| 이리스 | 선택 방문을 유도하는 선행 인사와 감각 중심 답변이 일관된다. 온실의 비를 결정적 '모순'으로 취급할 때는 관찰 근거가 더 필요. |
| 퍼즐·실패·재진입 | 창 3개, 책 3개, 초상화 5개, 차 6단계, 선택 관찰 3개를 확인했다. 창문 오염 복구, 장부 질문 복귀, 수면 취소·저장 거절 안내는 존재한다. NOT_CONNECTED/PROPOSED 자체를 실행 실패로 단정하지 않았다. |
| 관계·호감 | 현재 프롤로그 효과 9개는 진행 완료 기록이며 관계 수치 변화는 이 범위에 명시되지 않는다. EP01/EP02와의 시작 관계 계약을 확인할 항목으로 남겼다. |
| 기존 QA·적용 결정 | QA의 오래된 완료·재검토 표시를 최신 게임 동작의 보증으로 쓰지 않았다. 로컬 2026-11-03 검증 기록의 P4 6줄 재생·마지막 완료 및 EP01 우선 결정은 해결된 전제로 존중했다. |

<a id="p00-02"></a>
### P00-02 · 아버지의 차 6줄과 완료 참조

높음 · 시트 명세 오류 · 루카·대사 연결

- [09_Runtime_Master!B68:AL76](https://docs.google.com/spreadsheets/d/1rUrohB4V_zdzkrJlPRBWq_ZCrWImoihkc7AM5kgO0Ys/edit#gid=1910202603&range=B68:AL76) · `P4_Q_FATHER_TEA; P4_A_FATHER_TEA_001~006` — _001은 '응답 종료 후 P4 완료 저장'·NOT_CONNECTED, _002~006은 대사가 있으나 next_type/next_id가 비어 있다.
- [Conversation_Index!A12:T12](https://docs.google.com/spreadsheets/d/1rUrohB4V_zdzkrJlPRBWq_ZCrWImoihkc7AM5kgO0Ys/edit#gid=1910202714&range=A12:T12) · `EP00_CONV_P4_FATHER_TEA` — completion_node_ids가 P4_A_FATHER_TEA_001이다.
- [12_State_Effect!A8:Q8](https://docs.google.com/spreadsheets/d/1rUrohB4V_zdzkrJlPRBWq_ZCrWImoihkc7AM5kgO0Ys/edit#gid=1910202607&range=A8:Q8) · `EFF_EP00_P4_COMPLETE_FATHER_TEA` — 완료 효과 node_id도 _001을 가리킨다.

**문제와 영향**  현재 시트의 연결·완료 명세는 공식 6줄 대화 전체와 불일치한다. 2026-11-03 로컬 검증 기록에는 게임 어댑터가 6줄 재생과 마지막 줄 이후 완료를 이미 지원한다고 명시되어 있어 실제 게임이 끊긴다는 지적은 아니다. 시트만 읽는 집필자·차기 생성기가 _002~006을 선택되지 않는 초안 또는 완료 뒤 대사로 오해할 수 있다.

**보완안**  차기 시트 동기화 시 _001→_002→…→_006의 연결, _006 뒤 완료·이리스 인사, Conversation_Index 완료 노드, Effect 완료 노드·시점의 기준을 한 계약으로 맞춘다. 한국어 원문은 별도 승인 없이 바꾸지 않는다.

**수정 후 확인**  시트 내 진입에서 6줄 모두 도달하고 완료 참조가 마지막 줄과 일치하는지 정적으로 확인한다. 기존 56개 공식 응답 검사 및 중간 저장 복원 결과와 일치해야 한다.

<a id="p00-03"></a>
### P00-03 · 발견 위치와 자기 낙서의 수첩 기록

높음 · 원문 오류 · 플롯·장부 단서

- [09_Runtime_Master!B26:V28](https://docs.google.com/spreadsheets/d/1rUrohB4V_zdzkrJlPRBWq_ZCrWImoihkc7AM5kgO0Ys/edit#gid=1910202603&range=B26:V28) · `P3_DISCOVER; P3_LEDGER; P3_RESUME` — 장부는 '반납 슬롯 안쪽'에서 떨어지며, 표지 불가독과 겹친 잉크만 묘사된다.
- [09_Runtime_Master!B140:T140](https://docs.google.com/spreadsheets/d/1rUrohB4V_zdzkrJlPRBWq_ZCrWImoihkc7AM5kgO0Ys/edit#gid=1910202603&range=B140:T140) · `NOTE_P_JOURNAL` — '기계 도면집 뒤'에서 떨어졌고 '내가 그린 듯한 고딕 저택 낙서'가 안쪽에 있다고 기록한다.

**문제와 영향**  같은 발견을 장면과 수첩이 다른 위치로 서술한다. 자기 필체/그림이라는 핵심 단서도 현재 발견 장면에서는 관찰되지 않는다. 플레이어가 기록의 신뢰성을 의심하는 이유가 의도된 기억 조작인지 단순 편집 차이인지 구분하기 어렵고, 후속 추론이 보지 못한 증거에 기대게 된다.

**보완안**  발견 물리 상황을 하나로 정한다. 예: '반납 슬롯에 꽂힌 기계 도면집을 꺼내자 뒤에서 장부가 떨어진다'로 두 위치를 연결하고, 수첩 추가 직전에 장부 안쪽의 낙서를 보고 침실 수첩과 닮았다고 느끼는 짧은 관찰을 둔다. 낙서 공개를 뒤로 미룰 의도라면 현재 노트에서는 제거하고 실제 열람 후 갱신한다.

**수정 후 확인**  장부 발견·무응답 내려놓기·각 질문·중도 종료 후 재진입 모두에서, 실제 본 사실만 동일한 발견 위치로 수첩에 남는지 확인한다.

<a id="p00-04"></a>
### P00-04 · 18초의 정밀도

보통 · 설정 확인 · 퍼즐·새의 반복

- [09_Runtime_Master!B20:V21](https://docs.google.com/spreadsheets/d/1rUrohB4V_zdzkrJlPRBWq_ZCrWImoihkc7AM5kgO0Ys/edit#gid=1910202603&range=B20:V21) · `P2_TOOL_BIRD; P2_TOOL_BIRD_LINE` — 장면은 '같은 새가 같은 날갯짓'으로 다시 지나갔다고만 말한다.
- [09_Runtime_Master!B137:T137](https://docs.google.com/spreadsheets/d/1rUrohB4V_zdzkrJlPRBWq_ZCrWImoihkc7AM5kgO0Ys/edit#gid=1910202603&range=B137:T137) · `NOTE_P_BIRD` — 수첩에는 '18초 간격'이라는 수치가 확정적으로 적힌다.

**문제와 영향**  현재 시트에는 주인공이 18초를 세거나 시계와 비교한 관찰이 없다. 영상/연출에서 계측이 표시되는지 확인해야 한다. 후속 시간 퍼즐의 근거가 되면 플레이어의 관찰이 아니라 수첩이 정답을 제공한 것으로 느껴진다.

**보완안**  18초가 퍼즐용 정밀 단서라면 시계나 실제 반복 표시와 비교하는 관찰을 먼저 제공한다. 분위기 단서라면 노트를 '같은 간격으로' 정도로 낮추고 수치 확정은 계측 이후에 한다.

**수정 후 확인**  자막·저소음 모드·메뉴를 열어 기다린 경우에도 18초를 인지할 동일한 근거가 있는지 확인한다. 실제 애니메이션이 이미 계측을 제공한다면 해당 연출 출처만 명세에 보강한다.

<a id="p00-05"></a>
### P00-05 · 천보다 먼저 움직이는 닦임 자국

보통 · 설정 확인 · 퍼즐·창문 단서

- [09_Runtime_Master!B16:V23](https://docs.google.com/spreadsheets/d/1rUrohB4V_zdzkrJlPRBWq_ZCrWImoihkc7AM5kgO0Ys/edit#gid=1910202603&range=B16:V23) · `P2_TOOL_GUIDE; P2_TOOL_COMPLETE_LINE` — 안내·새 반복·완료 대사는 있으나 선행하는 닦임 자국의 관찰 대사는 없다.
- [09_Runtime_Master!B145:T145](https://docs.google.com/spreadsheets/d/1rUrohB4V_zdzkrJlPRBWq_ZCrWImoihkc7AM5kgO0Ys/edit#gid=1910202603&range=B145:T145) · `NOTE_P_WINDOWS` — '주황빛 닦임 자국이 천보다 한순간 먼저 움직였다'고 수첩에 남는다.

**문제와 영향**  중요한 인과 역전 단서가 수첩에만 서술된다. 실제 청소 연출에서 충분히 관찰되는지 시트만으로 확인되지 않는다. 빠르게 조작한 플레이어나 비시각 피드백을 쓰는 플레이어는 원인이 뒤따르는 장면을 보지 못한 채 그 사실을 알고 있는 것으로 처리될 수 있다.

**보완안**  실제 연출이 있다면 첫 성공 창에서 천과 자국의 어긋남을 다시 볼 수 있도록 하고 짧은 감각 자막을 제공한다. 연출이 없다면 관찰을 추가하거나 노트의 해당 문장을 실제 확인 뒤에만 기록한다.

**수정 후 확인**  청소 순서·정상/오도구 복구·완료 직후 재열람·저시력 대체 표시에 상관없이 같은 관찰을 확인할 수 있어야 한다.

<a id="p00-06"></a>
### P00-06 · 자유 순서와 지각 질책

보통 · 보완 · 대상별 이야기·비피

- [01_Scene!A2:H8](https://docs.google.com/spreadsheets/d/1rUrohB4V_zdzkrJlPRBWq_ZCrWImoihkc7AM5kgO0Ys/edit#gid=1910202606&range=A2:H8) · `P2; P3; P3B` — P2·P3·P3B의 순서를 바꿀 수 있다고 설명한다.
- [09_Runtime_Master!B9:V9](https://docs.google.com/spreadsheets/d/1rUrohB4V_zdzkrJlPRBWq_ZCrWImoihkc7AM5kgO0Ys/edit#gid=1910202603&range=B9:V9) · [09_Runtime_Master!B45:V46](https://docs.google.com/spreadsheets/d/1rUrohB4V_zdzkrJlPRBWq_ZCrWImoihkc7AM5kgO0Ys/edit#gid=1910202603&range=B45:V46) · `P1_HALL_EDGAR; P3B_INTRO` — 에드가는 '순서는 정하지 않겠습니다', 마라 2는 진입 즉시 '늦었어! 엄청 늦었어!'라고 말한다.

**문제와 영향**  비피를 첫 방문해도 질책하는 고정 대사는 자유 순서 안내와 충돌해 숨은 시간 제한이 있다고 느끼게 할 수 있다. 조급한 성격 표현이라면 그 의도를 드러내는 받침이 약하다. 실제 제약이 없는 튜토리얼에서 플레이어가 불필요한 실패·호감 손해를 걱정한다.

**보완안**  첫 방문 순서에 따라 '벌써 왔네? 내가 준비할 시간이 없잖아!'와 '드디어 왔네!'로 나누거나, 고정 대사를 유지하면 '내가 기다리면 다 늦은 거야!' 같은 한 줄로 개인적 과장을 분명히 한다.

**수정 후 확인**  P3B를 첫째·둘째·셋째로 방문했을 때 모두 성격 묘사로 자연스럽게 읽히고 시간 제한/관계 페널티를 암시하지 않는지 확인한다.

<a id="p00-07"></a>
### P00-07 · 차 취향에서 찻잎 폐기로 이어지는 감정

보통 · 보완 · 대상별 이야기·루카

- [09_Runtime_Master!B71:T76](https://docs.google.com/spreadsheets/d/1rUrohB4V_zdzkrJlPRBWq_ZCrWImoihkc7AM5kgO0Ys/edit#gid=1910202603&range=B71:T76) · `P4_A_FATHER_TEA_001~006` — '같은지는 자신이 없지만'→'왜 그렇게 생각해?'→'차는 같은 향을 즐기는 취미'→'변하는 것에 예민'→'찻잎들이 다 버려지면'로 이어진다.

**문제와 영향**  차가 예전과 같은지 불확실하다는 말에서 주인공의 '왜 그렇게 생각해?'가 무엇을 묻는지 모호하고, 향의 변화가 찻잎 전량 폐기로 이어지는 이유가 생략돼 있다. 루카의 돌봄·불안이 구체적인 기억이나 경험보다 단순한 걱정 많은 성격으로 축소된다.

**보완안**  주인공 질문의 대상을 '향이 달라진 것 같아?'처럼 분명히 하고, '조금 달라졌다고 남은 잎까지 치우신 적이 있어서…'처럼 폐기를 걱정하는 작은 경험을 연결한다. 아버지의 통제 성향을 아직 드러내지 않을 의도라면 기억의 불확실성 자체를 두려워하는 방향으로 마지막 걱정을 조정한다.

**수정 후 확인**  6줄을 연속으로 읽을 때 지시어의 대상과 루카의 걱정 원인을 독자가 한 번에 설명할 수 있는지 확인한다. 아버지에 관한 폭로 강도는 다른 두 질문과 균형을 맞춘다.

<a id="p00-08"></a>
### P00-08 · 한 가지만 고르는 P4 질문의 정보 편차

보통 · 보완 · 선택·주인공과 아버지

- [09_Runtime_Master!B68:V80](https://docs.google.com/spreadsheets/d/1rUrohB4V_zdzkrJlPRBWq_ZCrWImoihkc7AM5kgO0Ys/edit#gid=1910202603&range=B68:V80) · [09_Runtime_Master!B136:V136](https://docs.google.com/spreadsheets/d/1rUrohB4V_zdzkrJlPRBWq_ZCrWImoihkc7AM5kgO0Ys/edit#gid=1910202603&range=B136:V136) · `P4_PROMPT; P4_Q_FATHER_TEA; P4_Q_MANSION_AGE; P4_Q_LUCA_TENURE` — '한 가지만 물어볼 수 있을 것 같다'며 아버지의 차·저택 역사·루카 근무 기간 중 하나만 고른다.
- [02_Branch!A7:F7](https://docs.google.com/spreadsheets/d/1rUrohB4V_zdzkrJlPRBWq_ZCrWImoihkc7AM5kgO0Ys/edit#gid=1910202610&range=A7:F7) · `P4_FATHER` — 선택한 한 질문의 응답 후 P4 완료·이리스 인사로 진행한다.

**문제와 영향**  선택의 제한은 차가 식는 상황으로 납득 가능하지만, 아버지 성향·자기 기억과 저택의 관계·반복 날짜라는 서로 다른 핵심 정보가 상호 배타적이다. 후속 에피소드가 이 중 특정 정보를 이미 안다고 가정하면 공백이 생긴다. 가벼운 관심 선택이 이후 이해도 차이를 크게 만들 수 있다.

**보완안**  필수 공통 정보는 선택 전후의 짧은 관찰에 두고, 질문별 정보는 인물 해석과 관계 반응의 차이로 유지한다. 특정 질문 정보가 후속 진행에 필요하다면 미선택자에게만 나중에 다른 출처를 제공하거나 후속 대사를 알고/모름으로 나눈다.

**수정 후 확인**  세 질문을 각각 선택한 저장으로 EP01/EP02를 읽어, 미선택 답변의 정보를 전제하는 대사가 없는지 대조한다. 선택의 가치가 사라지도록 모든 답변을 강제로 읽히지는 않는다.

<a id="p00-09"></a>
### P00-09 · 잠겨 있는 대상과 금지 이유

보통 · 설정 확인 · 대상별 이야기·에드가

- [09_Runtime_Master!B25:V44](https://docs.google.com/spreadsheets/d/1rUrohB4V_zdzkrJlPRBWq_ZCrWImoihkc7AM5kgO0Ys/edit#gid=1910202603&range=B25:V44) · [09_Runtime_Master!B179:T179](https://docs.google.com/spreadsheets/d/1rUrohB4V_zdzkrJlPRBWq_ZCrWImoihkc7AM5kgO0Ys/edit#gid=1910202603&range=B179:T179) · `P3_RESTRICTED; P3_DOOR; P3_Q_LOCKED; P3_A_LOCKED_001; P3_SILENT_STATUS` — 기록 내실 유리문과 장부가 같은 장면에 있고 '여긴 왜 잠겨있어?' 뒤에는 손상된 기록 이야기, 내려놓기 뒤에는 잠금쇠 확인이 나온다.

**문제와 영향**  질문의 '여기'가 내실 문인지 장부의 잠금 부분인지 모호하다. 장부 발견 때 본문 잉크를 볼 수 있었다는 묘사와 '나도 못 열어봐?'·잠금쇠가 함께 있어 어디까지 열람했는지도 불명확하다. 에드가가 접근을 막는 범위와 이후 잠금 해제 퍼즐의 목표가 다르게 이해될 수 있다.

**보완안**  대상을 '장부 뒷부분은 왜 잠겨 있어?' 또는 '기록 내실은 왜 잠겨 있어?'로 확정하고, 펼쳐볼 수 있는 겉장/잠긴 본문 구획을 한 줄로 구분한다. 물리 잠금과 열람 권한은 다른 규칙이라면 둘을 분리해 설명한다.

**수정 후 확인**  질문 없이 내려놓기, 잠긴 이유부터 질문, 작성자부터 질문하는 세 경로에서 같은 물체와 같은 접근 범위를 상상할 수 있는지 확인한다.

<a id="p00-10"></a>
### P00-10 · 비의 모순과 감각 질문의 근거

보통 · 보완 · 퍼즐·이리스·온실

- [09_Runtime_Master!B81:V87](https://docs.google.com/spreadsheets/d/1rUrohB4V_zdzkrJlPRBWq_ZCrWImoihkc7AM5kgO0Ys/edit#gid=1910202603&range=B81:V87) · [09_Runtime_Master!B144:T144](https://docs.google.com/spreadsheets/d/1rUrohB4V_zdzkrJlPRBWq_ZCrWImoihkc7AM5kgO0Ys/edit#gid=1910202603&range=B144:T144) · [09_Runtime_Master!B245:T245](https://docs.google.com/spreadsheets/d/1rUrohB4V_zdzkrJlPRBWq_ZCrWImoihkc7AM5kgO0Ys/edit#gid=1910202603&range=B245:T245) · `P5_GLASS; P5_THRESHOLD; P5_QUESTION; P5_ANSWER; NOTE_P_WEATHER; P5_RECORD` — 온실 안 비·배관 소리·밖의 맑음·마른 문턱을 보고 '모순'을 기록한다. 이리스는 차갑게 느끼는지로 진짜 여부를 답한다.

**문제와 영향**  온실 내부 살수와 외부 맑음, 실내 문턱의 건조함은 일반적인 환경 제어로도 설명된다. 세 관찰에는 빗물에 접촉하는 행위가 없어 이리스의 감각 기준을 직접 시험할 수도 없다. 이상감을 주는 장면으로는 유효하지만 물리 모순의 확정 증거로 쓰기에는 약하다. 뒤의 인공 세계 추론이 이 장면을 필수 증명으로 사용하면 결론이 관찰보다 앞서 보일 수 있다.

**보완안**  초기 노트를 '이상한 날씨'라는 가설 수준으로 두거나, 경계에서 빗방울이 사라짐·보이는 비와 맞지 않는 젖음 등 통상 살수로 설명하기 어려운 관찰을 하나만 추가한다. 손을 내밀거나 물방울을 만지는 선택을 제공하면 이리스 답변을 플레이로 검증할 수 있다.

**수정 후 확인**  온실 방문 생략자도 필수 플롯을 이해하고, 방문자는 관찰 사실과 해석을 구분할 수 있는지 확인한다. '진짜'의 감각·물리·인공 생성 의미를 후속 대사와 일관되게 유지한다.

<a id="p00-11"></a>
### P00-11 · 일과를 따르는 이유와 차 준비 추가

보통 · 보완 · 플롯·주인공 동기

- [09_Runtime_Master!B7:V14](https://docs.google.com/spreadsheets/d/1rUrohB4V_zdzkrJlPRBWq_ZCrWImoihkc7AM5kgO0Ys/edit#gid=1910202603&range=B7:V14) · [09_Runtime_Master!B51:V52](https://docs.google.com/spreadsheets/d/1rUrohB4V_zdzkrJlPRBWq_ZCrWImoihkc7AM5kgO0Ys/edit#gid=1910202603&range=B51:V52) · `P1_WAKE_TASKS; P1_INSPECT_PHOTO; P4_LINK_INTRO` — 아버지와의 기억이 비어 있는데 주인공은 세 가지 집안일을 받고 진행한다. 이후 루카는 차도 '오늘 일과에 들어 있다'고 말한다.
- [01_Scene!A5:H9](https://docs.google.com/spreadsheets/d/1rUrohB4V_zdzkrJlPRBWq_ZCrWImoihkc7AM5kgO0Ys/edit#gid=1910202606&range=A5:H9) · `P1; P2; P3; P3B; P4` — 세 오전 일과를 완료해야 차 준비로 진행한다.

**문제와 영향**  저택 주인의 딸이 집안일을 필수로 수행하는 이유와 기억 공백을 당장 묻지 않는 이유가 짧은 도입에 드러나지 않는다. 첫 일과 안내에 없던 차 준비가 추가될 때 누구의 지시인지도 흐리다. 주인공이 자기 의문보다 튜토리얼 순서를 우선하는 인상이며 P4 진입 동기가 약해질 수 있다.

**보완안**  기억을 깨우는 익숙한 일과인지, 아버지의 규칙인지, 정해진 일을 마쳐야 질문할 수 있는 상황인지 한 가지를 작가가 정한다. 예: 주인공 독백 '일단 몸이 기억하는 일부터 해 보자.'와 세 일과 완료 후 '주방에서 마지막 준비를 부탁드린다'는 짧은 전환으로 동기와 다음 목표를 연결한다.

**수정 후 확인**  첫 안내부터 P4까지 읽은 독자가 왜 주인공이 일과를 수행하고 주방으로 가는지 설명할 수 있는지 확인한다. 회복/통제 중 택한 이유가 아버지·에드가의 후속 설정과 충돌하지 않아야 한다.

<a id="p00-12"></a>
### P00-12 · 프롤로그에서 다음 에피소드로 넘기는 관계 상태

보통 · 설정 확인 · 관계·호감

- [12_State_Effect!A4:Q12](https://docs.google.com/spreadsheets/d/1rUrohB4V_zdzkrJlPRBWq_ZCrWImoihkc7AM5kgO0Ys/edit#gid=1910202607&range=A4:Q12) · `EFF_EP00_P1_COMPLETE~EFF_EP00_P4_COMPLETE_LUCA_TENURE` — 효과 9개가 P1~P6 진행 완료 플래그를 쓰며 호감·경계 변화는 이 범위에 없다.
- [Conversation_Index!A4:T19](https://docs.google.com/spreadsheets/d/1rUrohB4V_zdzkrJlPRBWq_ZCrWImoihkc7AM5kgO0Ys/edit#gid=1910202714&range=A4:T19) · `프롤로그 대화 16개` — 선택 질문·과업·인사는 있으나 관계 전이 규칙은 별도 명시되지 않는다.

**문제와 영향**  현재 범위에서는 실수 복구, 장부의 질문/침묵, 루카 질문, 선택 온실 방문이 관계 수치에 영향을 주는지 선언되지 않는다. 이는 호감 시스템 누락이라는 확정 오류가 아니라 후속 시작 상태의 계약 확인 사항이다. EP01/EP02 관계 기반 대사가 프롤로그 행동의 결과인지 기본 친분인지 집필자마다 다르게 가정할 수 있다.

**보완안**  프롤로그는 관계 수치 변화 없음·기본 관계로 시작한다고 명시하거나, 의미 있는 소수 선택만 관계/기억 플래그로 넘긴다. 단순 청소 오답·지각 농담은 페널티로 읽히지 않게 하고, 수치 변화가 있다면 그 원인이 되는 인물 반응을 함께 둔다.

**수정 후 확인**  최단 동선/모든 선택 조사/도구 반복 실수/온실 생략 저장을 각각 EP01로 넘겨 초기 호감·경계·기억의 차이가 선언된 규칙에 정확히 맞는지 확인한다.

<a id="p00-14"></a>
### P00-14 · 튜토리얼에 집중된 이상 징후의 위계

보통 · 보완 · 플롯·단서 배치

- [09_Runtime_Master!B12:T23](https://docs.google.com/spreadsheets/d/1rUrohB4V_zdzkrJlPRBWq_ZCrWImoihkc7AM5kgO0Ys/edit#gid=1910202603&range=B12:T23) · [09_Runtime_Master!B26:T30](https://docs.google.com/spreadsheets/d/1rUrohB4V_zdzkrJlPRBWq_ZCrWImoihkc7AM5kgO0Ys/edit#gid=1910202603&range=B26:T30) · [09_Runtime_Master!B48:T65](https://docs.google.com/spreadsheets/d/1rUrohB4V_zdzkrJlPRBWq_ZCrWImoihkc7AM5kgO0Ys/edit#gid=1910202603&range=B48:T65) · [09_Runtime_Master!B77:T87](https://docs.google.com/spreadsheets/d/1rUrohB4V_zdzkrJlPRBWq_ZCrWImoihkc7AM5kgO0Ys/edit#gid=1910202603&range=B77:T87) · [09_Runtime_Master!B93:T94](https://docs.google.com/spreadsheets/d/1rUrohB4V_zdzkrJlPRBWq_ZCrWImoihkc7AM5kgO0Ys/edit#gid=1910202603&range=B93:T94) · [09_Runtime_Master!B137:T145](https://docs.google.com/spreadsheets/d/1rUrohB4V_zdzkrJlPRBWq_ZCrWImoihkc7AM5kgO0Ys/edit#gid=1910202603&range=B137:T145) · `P1_INSPECT_*; P2_TOOL_BIRD; P2_CLOCK_OBSERVATION; P3_DISCOVER; P4_MEMORY_*; P4_A_LUCA_TENURE; P5_*; NOTE_P_*` — 단단한 침대·기억 공백·선행 필압·반복 새·여분 홈·장부·다섯 문양·동기 맥박·되돌아가는 손잡이·같은 날짜·내부 비·빈 방의 종이 소리가 연속으로 나온다.

**문제와 영향**  개별 단서는 서로 어울리지만 도입의 과업 조작과 동시에 많은 종류가 쌓인다. 모두 같은 무게로 기록되면 플레이어가 첫 반복에서 무엇을 비교해야 하는지 선택하기 어렵다. 퍼즐의 추론보다 설정의 기이함을 빠르게 소비하고, EP01/EP02에서 단서를 재발견하는 힘이 약해질 수 있다.

**보완안**  프롤로그의 중심 질문을 '어제가 반복되는가'와 '몸은 무엇을 기억하는가' 정도로 두고, 첫 비교에 쓸 소수 관찰을 필수 흐름에 배치한다. 나머지는 선택 관찰로 남기되 다음 에피소드에서 어떤 사건에 회수되는지 원문 ID 단위로 연결한다. 새 보조 레이블을 화면에 늘리기보다 재방문 시 사물 변화로 위계를 보여준다.

**수정 후 확인**  초회 플레이어가 첫 취침 전 핵심 의문 두 가지와 확인하고 싶은 사물을 스스로 말할 수 있는지 확인한다. 선택 조사를 건너뛰어도 EP01 필수 추론의 근거가 남아 있어야 한다.

<a id="p00-15"></a>
### P00-15 · 가운데를 눌렀을 때 '아래부터'라는 응답

낮음 · 원문 오류 · 퍼즐·창문 오류 피드백

- [09_Runtime_Master!B153:T153](https://docs.google.com/spreadsheets/d/1rUrohB4V_zdzkrJlPRBWq_ZCrWImoihkc7AM5kgO0Ys/edit#gid=1910202603&range=B153:T153) · [09_Runtime_Master!B159:T159](https://docs.google.com/spreadsheets/d/1rUrohB4V_zdzkrJlPRBWq_ZCrWImoihkc7AM5kgO0Ys/edit#gid=1910202603&range=B159:T159) · `P2_TOOL_BOTTOM_ORDER; P2_TOOL_MIDDLE_ORDER` — 아래 영역과 가운데 영역의 선행 순서 오류가 모두 '아래부터 닦자'로 시작한다.

**문제와 영향**  가운데를 먼저 조작한 경우에도 아래부터 닦았다고 설명해 실제 행동과 피드백이 어긋난다. 실패 원인은 상단 먼지 미처리인데 플레이어가 클릭 영역을 잘못 인식했다고 생각할 수 있다.

**보완안**  가운데 오류는 '위쪽 먼지가 남아 있어 가운데가 다시 더러워졌다. 위쪽부터 정리해야 한다.'처럼 실제 영역과 원인을 맞춘다. 아래 오류의 표현은 유지할 수 있다.

**수정 후 확인**  먼지 남음 상태에서 가운데/아래를 각각 조작해 메시지가 실제 영역과 선행 조건을 정확히 가리키는지 확인한다.

## EP01 · 반복과 시계망

필수 퍼즐의 순서, 안전 시험/실제 작동 구분, 비난 없는 실패 지원, B2 비실패 합류는 잘 잡혀 있다. 우선 손볼 부분은 A2 시간축, 표식별 공통 독백, 마라의 접근 시간 모순, 제작용 호칭이다. 시트 정본의 완료 효과와 분기 합류 문제는 현재 게임 오류와 구별해 별도 표시했다.

| 검토 구간 | 평가 |
| --- | --- |
| 필수 플롯 Scene 1~12 | 필수 사건 전부 검토. 첫 취침과 A2 시간 기준 보완 필요. |
| 선택·실패 Branch 5-E/6-S/7-E/9-R/10-F/10-W | B2 숨기/발견/침묵/추궁 및 B3 실패·수면·숏컷·목격 변주 검토. |
| 에드가 | 일상 2주제·조사·권한 갈등·경계도 반응 검토. |
| 마라 | 반복 감각·청소 시간·사다리·지원 반응 검토. |
| 루카 | 잔 순서/우리 지칭·기억·걱정·호칭 검토. |
| 이리스 | 몸의 기억·날씨 모순·미소와 경고·호칭 검토. |
| 비피 | 이름표 장난·기록·체크섬·지원과 성공 재촉 검토. 확정 오류 없이 역할 차별화가 유지됨. |
| B1/B2 | 정답 구간·단서 결합·압박·비실패 합류 검토. |
| J1/B3A/B3B/BF/BSHORT | 복원·배선·위상·원인별 실패·재수집·고정 검토. |
| B4/B5/J2 및 EP02 연결 | 파형·중첩·문서/주인공 해석·거울 회랑 목표 검토. C3 정답 비율을 공개하지 않는 점 유지. |
| 수동 QA·상태 계약 | QA 완료를 실검증으로 간주하지 않음. 승인된 최초1회·무호감 변화 정책 유지. 11/03 게임 반영 검증과 구별. |

<a id="ep01-01"></a>
### EP01-01 · 첫 취침의 악몽·기상·취침 전환

보통 · 보완 · 스토리 플롯

- [09_Runtime_Master!S4:S17](https://docs.google.com/spreadsheets/d/1cHx28-B4lG-p9iMyxt7HkQ4Dgk9QeI14UiAJC512v5w/edit#gid=497322651&range=S4:S17) · `EP01_SLEEP_FIRST_001~EP01_SLEEP_FIRST_CHOICE_001` — 침대 포커스 → 악몽 → '상체를 일으키자' → '오늘은 정말 오래 걸었다' → 취침 확인

**문제와 영향**  첫 취침 장면 안에 악몽에서 깨어난 아침처럼 보이는 비트가 들어가고, 바로 하루를 마친 취침으로 돌아간다. 회상인지 잠깐 졸았다 깬 것인지 구별하는 전환이 없다. 실제 첫 리셋 이전에 이미 한 번 리셋한 것으로 읽혀 반복의 횟수와 발견 순서가 흔들린다.

**보완안**  악몽을 지우기보다 시작에 '침대에 앉은 채 잠깐 의식이 끊겼다', 에드가 이후에 '꿈에서 깬 저녁이었다'처럼 시간 기준을 한 번 고정한다. 낮의 기억을 불러온 회상이라면 프레임과 복귀 비트를 명시한다.

**수정 후 확인**  첫 취침 전 졸음/회상, 수면 승인, 첫 정상 리셋을 처음 보는 독자가 각각 구별할 수 있는지 확인한다.

프롤로그 [09_Runtime_Master!B98:V118](https://docs.google.com/spreadsheets/d/1rUrohB4V_zdzkrJlPRBWq_ZCrWImoihkc7AM5kgO0Ys/edit#gid=1910202603&range=B98:V118)에도 같은 취침 구간이 인용되어 있다. 첫 취침부터 EP01을 우선한다는 기존 결정에 따라 원본의 의도와 재생 시점을 먼저 확정한다.

<a id="ep01-02"></a>
### EP01-02 · A2 안의 추가 수면·기상 서술

높음 · 원문 오류 · 스토리 플롯

- [09_Runtime_Master!S133:S170](https://docs.google.com/spreadsheets/d/1cHx28-B4lG-p9iMyxt7HkQ4Dgk9QeI14UiAJC512v5w/edit#gid=497322651&range=S133:S170) · `EP01_RESET_REPEAT_001 / EP01_A2_* / EP01_A2_OBSERVE_001~017` — 두 번째 정상 리셋과 표식 확인 뒤 '하루가 끝나는 지점', '졸리니까 일단 자고', 다시 햇살·수첩 확인

**문제와 영향**  Scene 4에서 두 번째 정상 리셋을 끝내고 Scene 5에서 표식이 남았음을 확인했는데, 같은 Scene 5의 후속 독백이 다시 하루의 끝과 수면·기상을 연속 서술한다. A1 독백을 다음 아침에 재생하는 승인된 보정과 별개인 시간축 충돌이다. 표식 검증이 두 번 일어나고 추가 하루가 아무 일과·리셋 확인 없이 지나간 것처럼 보인다. 다음 B1이 어느 날인지 모호하다.

**보완안**  A2_OBSERVE_001~017을 전날 밤을 떠올리는 회상으로 읽도록 '어젯밤에는'과 현재 복귀 표시를 두거나, 다음 개정에서 밤의 의심과 아침의 확신을 AS 종료/실제 A2로 분리한다. 기존 승인대로 원문·행 순서를 보존할 경우 재생 시점 메타데이터와 회상 연출만 먼저 명시한다.

**수정 후 확인**  A1 작성→일과→정상 리셋→A2 확인→B1의 한 번씩인 시간선을 대사 순서에 대입한다. 현재 게임 버그라고 단정하지 않고 원문/시트 재생 계약의 문맥 문제로 검증한다.

<a id="ep01-03"></a>
### EP01-03 · 문장·도형·잉크 표식의 공통 확인 대사

높음 · 원문 오류 · 선택·대사

- [09_Runtime_Master!S46:S51](https://docs.google.com/spreadsheets/d/1cHx28-B4lG-p9iMyxt7HkQ4Dgk9QeI14UiAJC512v5w/edit#gid=497322651&range=S46:S51) · `EP01_A1_CH01~CH03 / EP01_A1_SENTENCE_001~INK_001` — 선택은 문장·집 도형·모서리 잉크로 갈린다.
- [09_Runtime_Master!S134:S138](https://docs.google.com/spreadsheets/d/1cHx28-B4lG-p9iMyxt7HkQ4Dgk9QeI14UiAJC512v5w/edit#gid=497322651&range=S134:S138) · `EP01_A2_SENTENCE_001~INK_001 / EP01_A1_REACTION_002` — 분기별 확인 뒤 공통으로 '구석의 잉크 한 방울까지 그대로'
- [09_Runtime_Master!S170](https://docs.google.com/spreadsheets/d/1cHx28-B4lG-p9iMyxt7HkQ4Dgk9QeI14UiAJC512v5w/edit#gid=497322651&range=S170) · `EP01_A2_002` — 공통으로 '내 손이 쓴 문장은 남았다'

**문제와 영향**  선택별 A2 첫 반응은 마련되어 있지만 공통 독백이 잉크 선택과 문장 선택을 모두 한 것처럼 말한다. 도형만 고른 플레이어는 하지 않은 행동을 증거로 듣는다. 플레이어가 직접 만든 유일한 검증 표식의 신뢰가 약해진다.

**보완안**  공통 문장은 '내가 남긴 흔적까지 그대로'와 '내 손으로 남긴 표식은 남았다'로 중립화하고, 잉크 결·문장 획·도형 순서는 이미 있는 세 분기 대사에 남긴다. 승인된 원문 보존 정책에 따라 이는 차기 콘텐츠 개정안으로 제시한다.

**수정 후 확인**  세 표식 각각을 선택해 확인 시점의 모든 독백을 읽고, 선택하지 않은 문장·잉크가 언급되지 않는지 확인한다.

<a id="ep01-04"></a>
### EP01-04 · 청소 종료 시간과 내실 접근 창

높음 · 원문 오류 · 퍼즐 B1 · 마라

- [09_Runtime_Master!S219:S227](https://docs.google.com/spreadsheets/d/1cHx28-B4lG-p9iMyxt7HkQ4Dgk9QeI14UiAJC512v5w/edit#gid=497322651&range=S219:S227) · `EP01_B1_MARA1_INTRO_001~EP01_B1_MARA1_002` — 낮은 관계: '차를 치우고 나서 종소리가 울리면 전부 끝'; 높은 관계: '차를 치운 다음부터 종이 울리기 전까지는 복도를 비워'
- [09_Runtime_Master!S475](https://docs.google.com/spreadsheets/d/1cHx28-B4lG-p9iMyxt7HkQ4Dgk9QeI14UiAJC512v5w/edit#gid=497322651&range=S475) · `EP01_DOC_CLEAN_001` — 차 회수 전 바닥 마감, 차 회수 뒤 도구 반납, 저녁 종 전 재진입 없음
- [09_Runtime_Master!S203](https://docs.google.com/spreadsheets/d/1cHx28-B4lG-p9iMyxt7HkQ4Dgk9QeI14UiAJC512v5w/edit#gid=497322651&range=S203) · `EP01_B1_SUCCESS_001` — 정답은 차 회수 뒤~저녁 종 전

**문제와 영향**  낮은 관계의 첫 답변은 종이 울릴 때까지 청소하는 것으로 읽히고, 문서·높은 관계 답변은 그 전에 이미 복도를 비운다고 한다. 동일 사실을 관계 수치가 바꾸는 상태다. 낮은 관계에서 합리적으로 추론한 플레이어가 정답 시간대를 피하게 될 수 있다.

**보완안**  핵심 시간은 모든 관계에서 '차를 치우면 청소는 끝, 종 전까지 복도에 돌아오지 않음'으로 통일한다. 관계별 차이는 이유를 덧붙이는지, 사다리 주의를 자발적으로 주는지에 둔다.

**수정 후 확인**  관계 낮음·중간·높음에서 청소표와 답변을 비교해 동일한 접근 창 하나가 도출되는지 확인한다.

<a id="ep01-05"></a>
### EP01-05 · 핵심 단서 2개와 빈 방 결론의 증명

보통 · 설정 확인 · 퍼즐 B1

- [09_Runtime_Master!S193:S204](https://docs.google.com/spreadsheets/d/1cHx28-B4lG-p9iMyxt7HkQ4Dgk9QeI14UiAJC512v5w/edit#gid=497322651&range=S193:S204) · `EP01_B1_003~SUCCESS_002` — 핵심 단서 2개 이상으로 추론판 활성; '네 사람의 동선선이 동시에 비는 구간'
- [09_Runtime_Master!S199](https://docs.google.com/spreadsheets/d/1cHx28-B4lG-p9iMyxt7HkQ4Dgk9QeI14UiAJC512v5w/edit#gid=497322651&range=S199) · `EP01_B1_BOARD_002` — 아침에는 외부 서고 감독이므로 기록 내실이 비는 구간이 아님
- [09_Runtime_Master!S469:S480](https://docs.google.com/spreadsheets/d/1cHx28-B4lG-p9iMyxt7HkQ4Dgk9QeI14UiAJC512v5w/edit#gid=497322651&range=S469:S480) · `EP01_DOC_WORK/DELIVERY/CLEAN/EXPORT` — 문서별로 다른 담당자·반환 시점을 설명

**문제와 영향**  추론판을 여는 임의의 두 단서가 네 사람 모두의 부재를 증명하는지 명세에서 분명하지 않다. 특히 아침의 '외부 서고 감독'만으로는 기록 내실이 점유 중임을 바로 증명하지 못한다. 자료로 결론을 내리는 추론보다 정해진 시간 카드를 고르는 문제로 느껴질 수 있다.

**보완안**  '2개 확보'는 조작판 개방과 정답 확정을 구분한다. 인물별 부재 근거를 제출하게 하거나, 한 문서에 공통 업무 교대 규칙을 명시한다. 아침 오답은 내실 서명/왕복 점검 등 실제 접근 불가 근거를 보여 준다.

**수정 후 확인**  가능한 단서 2개 조합에서 보이는 정보만으로 정답을 설명해 본다. 설명 불가능한 조합은 가설만 허용하고 추가 근거를 요청한다.

<a id="ep01-06"></a>
### EP01-06 · 엄격한 통제와 기록 열람 허용의 경계

보통 · 보완 · 대상별 스토리 · 에드가

- [09_Runtime_Master!S178:S188](https://docs.google.com/spreadsheets/d/1cHx28-B4lG-p9iMyxt7HkQ4Dgk9QeI14UiAJC512v5w/edit#gid=497322651&range=S178:S188) · `EP01_A2_EDGAR_001~003` — 반복 기록은 규율 위반, 높은 alert에서 레이피어에 손
- [09_Runtime_Master!S273:S310](https://docs.google.com/spreadsheets/d/1cHx28-B4lG-p9iMyxt7HkQ4Dgk9QeI14UiAJC512v5w/edit#gid=497322651&range=S273:S310) · `EP01_B2_CAUGHT_*` — 가족 기록을 금지할 권한 없음; 막을 권한 없음; 필요한 책을 고르라며 퇴장

**문제와 영향**  에드가는 수첩의 반복 기록은 금지하면서 위험한 방의 일지는 허용한다. 이 모순을 보호와 복종 사이의 갈등으로 읽을 단서는 있으나, 플레이어가 이해할 최소한의 행동 경계가 없다. 위협이 결과 없는 연출처럼 보이거나 진상을 숨기려고 대화만 피하는 인물로 굳어질 수 있다.

**보완안**  진상을 밝히지 않는 범위에서 '열람은 막지 않지만 장치 조작은 막을 수 있다' 또는 '읽지 말라는 명령은 받지 않았다'처럼 권한 범위를 한 번 드러낸다. 높은 경계에서는 말보다 손을 막으려다 거두는 동작 등 갈등을 보여 준다.

**수정 후 확인**  에드가의 금지·허용 사례를 나열했을 때 독자가 하나의 보호 규칙으로 설명할 수 있는지 확인한다.

<a id="ep01-07"></a>
### EP01-07 · 아버지 질문 대화의 정보 보상

보통 · 보완 · 대상별 스토리 · 에드가

- [09_Runtime_Master!S549:S560](https://docs.google.com/spreadsheets/d/1cHx28-B4lG-p9iMyxt7HkQ4Dgk9QeI14UiAJC512v5w/edit#gid=497322651&range=S549:S560) · `EP01_DLG_EDGAR_002_010~120` — 칭찬에는 반응하지만 아버지 정보는 '안 되는 건 안 됩니다'로 종료
- [00_가이드!C35:D35](https://docs.google.com/spreadsheets/d/1cHx28-B4lG-p9iMyxt7HkQ4Dgk9QeI14UiAJC512v5w/edit#gid=1035511335&range=C35:D35) · `에드가 일상 2주제 반복 정책` — 주제별 최초 1회 완료 후 해당 선택지 숨김

**문제와 영향**  정서적으로 중요한 아버지 질문이 한번뿐인 기회인데, 얻는 정보가 에드가의 허영심과 거절뿐이다. 아버지를 찾는 동기와 한 번이라도 연결되는 작은 보상이 없다. 탐문을 해도 아무것도 얻지 못한다는 학습이 생겨 후속 선택 대화의 기대가 낮아진다.

**보완안**  거절은 유지하되 좋아하던 차·말버릇처럼 비밀을 해치지 않는 사실 하나, 또는 에드가가 호칭을 바꾸려다 멈추는 흔적을 준다. 기존 'bond 변화 없음/최초 1회' 승인은 그대로 두고 대사 차기 개정에만 반영한다.

**수정 후 확인**  대화를 읽은 전후에 플레이어가 아버지 또는 에드가에 관해 새롭게 말할 수 있는 문장이 하나 이상인지 확인한다.

<a id="ep01-08"></a>
### EP01-08 · 관계가 높다는 이유만으로 전날 사건을 전제하는 대사

보통 · 설정 확인 · 대상별 스토리 · 사용인 기억·호감

- [09_Runtime_Master!S227:S232](https://docs.google.com/spreadsheets/d/1cHx28-B4lG-p9iMyxt7HkQ4Dgk9QeI14UiAJC512v5w/edit#gid=497322651&range=S227:S232) · `EP01_B1_MARA1_002~CONT_005` — '어제도 말씀드리지 않았슴까?'
- [09_Runtime_Master!S387:S396](https://docs.google.com/spreadsheets/d/1cHx28-B4lG-p9iMyxt7HkQ4Dgk9QeI14UiAJC512v5w/edit#gid=497322651&range=S387:S396) · `EP01_B3_WIT_*_FAIL_HIGH` — 높은 관계 실패 반응에 '같은 손상을 다시 확인', '다음번에'
- [10_Route_Edge_Master!K61:K64](https://docs.google.com/spreadsheets/d/1cHx28-B4lG-p9iMyxt7HkQ4Dgk9QeI14UiAJC512v5w/edit#gid=984194965&range=K61:K64) · `EP01_ROUTER_B1_MARA1` — 마라 1 bond로 반응 구분; 실제 세부 임계는 Session 계약에서 판정

**문제와 영향**  높은 친밀도와 해당 사건을 전에 함께 경험했다는 사실은 다르다. 프롤로그에서 친밀해졌어도 B1 질문이나 시계 실패는 처음일 수 있다. 플레이어가 하지 않은 대화·실패를 사용인이 기억한다고 느끼면 잔류 기억이라는 핵심 장치의 규칙이 흐려진다.

**보완안**  회상형 문장에는 상대에게 실제로 질문/실패를 보여 준 기록을 추가 조건으로 둔다. 높은 친밀도+첫 사건에는 적극적인 도움, 실제 재경험에는 '어제도' 대사를 둔다. 숫자 호감도 안내를 추가할 필요는 없다.

**수정 후 확인**  높은 bond를 가진 채 B1을 처음 질문하고 첫 실패를 내는 경우, 실제 목격 없이 어제의 사건을 말하지 않는지 확인한다. 현 게임 조건에 이미 이 기록이 있으면 시트에 조건 근거만 보완한다.

<a id="ep01-09"></a>
### EP01-09 · '우리 말고는 모를'의 지시 대상

보통 · 보완 · 대상별 스토리 · 루카

- [09_Runtime_Master!S100:S111](https://docs.google.com/spreadsheets/d/1cHx28-B4lG-p9iMyxt7HkQ4Dgk9QeI14UiAJC512v5w/edit#gid=497322651&range=S100:S111) · `EP01_AS_LUCA_001~012` — 주인공이 잔 순서를 맞춤 → '하지만 잔의 모양은, 우리 말고는 모를 텐데' → 부정
- [09_Runtime_Master!S240:S242](https://docs.google.com/spreadsheets/d/1cHx28-B4lG-p9iMyxt7HkQ4Dgk9QeI14UiAJC512v5w/edit#gid=497322651&range=S240:S242) · `EP01_B1_LUCA_001~003` — 반복 동선 기억·걱정으로 변주

**문제와 영향**  루카의 놀람은 좋은 불안 단서지만 '우리'가 사용인 전원인지, 루카와 주인공인지, 이전 참여자인지 구별할 작은 반응도 없다. 이후에는 배달 장소와 걱정으로 넘어가 이 단서가 관계 진전에 연결되지 않는다. 의도된 떡밥보다 문맥을 놓친 문장으로 읽히거나 루카가 무엇을 두려워하는지 흐려질 수 있다.

**보완안**  바로 정체를 밝히지 말고 '우리?'라는 짧은 되물음에 루카가 잔의 표시를 숨기는 동작을 둔다. 나중의 높은 관계 대사에서 '순서를 맞춰서 무서웠던 게 아니에요' 같은 작은 회수로 감정을 구체화한다.

**수정 후 확인**  단서 이후에도 '누가 누구와 무엇을 공유했다는 의문인가'가 한 문장으로 남고, 루카의 회피가 추적 가능한지 확인한다.

<a id="ep01-10"></a>
### EP01-10 · 발화에 남은 제작용 호칭

높음 · 원문 오류 · 대상별 대사 · 이리스·루카

- [09_Runtime_Master!S394](https://docs.google.com/spreadsheets/d/1cHx28-B4lG-p9iMyxt7HkQ4Dgk9QeI14UiAJC512v5w/edit#gid=497322651&range=S394) · `EP01_B3_WIT_IRIS_FAIL_HIGH` — '아침이 지워도 주인공의 몸에는 남을 거예요'
- [09_Runtime_Master!S419](https://docs.google.com/spreadsheets/d/1cHx28-B4lG-p9iMyxt7HkQ4Dgk9QeI14UiAJC512v5w/edit#gid=497322651&range=S419) · `EP01_B3_WIT_LUCA_SUCCESS` — '주인공도 그랬죠...?'

**문제와 영향**  극중 사용인이 상대를 '주인공'이라고 부른다. 이 장면에 메타 발언이라는 근거가 없어 제작용 지칭이 대사에 남은 형태다. 성공·실패의 감각을 공유하는 중요한 순간에 몰입이 끊어진다.

**보완안**  현재 확정된 극중 호칭인 '아가씨' 또는 '당신'으로 통일하되 각 인물 말투를 따른다. 예: 이리스 '아침이 지워도 아가씨의 몸에는 남을 거예요.' 루카 '아가씨도 그랬죠...?' 이름·나이는 새로 확정하지 않는다.

**수정 후 확인**  전체 ko_KR 발화에서 '주인공' 등 제작용 지칭을 검색하고 실제 메타 발언 의도 여부를 확인한다.

<a id="ep01-11"></a>
### EP01-11 · 다나까체 QA와 현재 말투

낮음 · 설정 확인 · 대상별 대사 · 에드가

- [09_Runtime_Master!S15](https://docs.google.com/spreadsheets/d/1cHx28-B4lG-p9iMyxt7HkQ4Dgk9QeI14UiAJC512v5w/edit#gid=497322651&range=S15) · `EP01_SLEEP_FIRST_011` — '악몽이라도 꾸신 걸까요?'
- [09_Runtime_Master!S274:S305](https://docs.google.com/spreadsheets/d/1cHx28-B4lG-p9iMyxt7HkQ4Dgk9QeI14UiAJC512v5w/edit#gid=497322651&range=S274:S305) · `EP01_B2_CAUGHT_*` — '기억하세요', '여기지는 마세요'
- [08_Content_QA!B11:C11](https://docs.google.com/spreadsheets/d/1cHx28-B4lG-p9iMyxt7HkQ4Dgk9QeI14UiAJC512v5w/edit#gid=28481388&range=B11:C11) · `QA 7` — 완료: 에드가의 모든 발화를 다나까체로 유지

**문제와 영향**  QA는 모든 발화를 다나까체로 제한하지만 현재 대사에는 해요체가 여러 번 있다. 두 말투 자체가 오류는 아니며 인물 연출의 기준과 완료 판정이 어긋난다. 콘텐츠 담당자마다 말투를 다르게 고치거나 긴장 완화의 의도된 변화를 단순 오타로 지울 수 있다.

**보완안**  에드가의 기본 말투를 엄격한 격식체로 할지, 보호 반응에서만 해요체가 섞이게 할지 정한다. 전자면 해당 어미를 고치고, 후자면 예외 상황과 QA 문구를 바꾼다.

**수정 후 확인**  모든 에드가 발화를 장면별로 읽고 격식 변화가 감정·권한 변화와 일치하는지 확인한다.

<a id="ep01-12"></a>
### EP01-12 · 배선 연결 검증에서 실제 위상 위험으로의 동기

보통 · 보완 · 퍼즐 B3-A·B3-B

- [09_Runtime_Master!S352:S365](https://docs.google.com/spreadsheets/d/1cHx28-B4lG-p9iMyxt7HkQ4Dgk9QeI14UiAJC512v5w/edit#gid=497322651&range=S352:S365) · `EP01_B3A_SUCCESS_001 / EP01_B3B_TEST_PHASE_001 / EP01_B3B_COMMIT_001` — 역할 배치 검증 → 약한 시험은 연결만 확인 → 실제 작동은 핀 파손 위험
- [09_Runtime_Master!S504:S505](https://docs.google.com/spreadsheets/d/1cHx28-B4lG-p9iMyxt7HkQ4Dgk9QeI14UiAJC512v5w/edit#gid=497322651&range=S504:S505) · `EP01_DOC_CLOCK_001~002` — 열두 번이 끝난 뒤 다음 홈에 출력

**문제와 영향**  안전 시험이 연결만 검증하고 위상은 확인 못 한다는 규칙은 명시되어 있지만 왜 그런지, 주인공이 이 위험을 감수해야 하는지 서사적 이유가 얇다. 실패가 장치의 성질보다 게임이 재시도를 만들기 위해 둔 제한처럼 느껴질 수 있다.

**보완안**  장치 조사에 '약한 신호는 공명통을 깨우지 못해 도착 시각을 읽을 수 없다' 정도의 한 줄을 두고, 실행 직전 주인공이 아버지의 글과 XIII 흔적을 근거로 위험을 선택하게 한다. 현재의 취소·재검토 선택과 실패 보존은 유지한다.

**수정 후 확인**  첫 실행 전에 플레이어가 안전 시험의 한계·정답 근거·실패 대가를 자기 말로 설명할 수 있는지 확인한다.

<a id="ep01-13"></a>
### EP01-13 · HALF와 다른 전달 시점의 표현

낮음 · 보완 · 퍼즐 B3-B

- [09_Runtime_Master!S513:S516](https://docs.google.com/spreadsheets/d/1cHx28-B4lG-p9iMyxt7HkQ4Dgk9QeI14UiAJC512v5w/edit#gid=497322651&range=S513:S516) · `EP01_B3B_PHASE_M1 / 0 / P1 / HALF` — -1: 마지막 종 전 / 0: 열두 번째 동시 / +1: 끝난 뒤 한 칸 / HALF: 두 종 사이
- [09_Runtime_Master!S382:S383](https://docs.google.com/spreadsheets/d/1cHx28-B4lG-p9iMyxt7HkQ4Dgk9QeI14UiAJC512v5w/edit#gid=497322651&range=S382:S383) · `EP01_BF_PHASE_HALF_001~002` — 두 종 사이에 걸려 불완전한 진동

**문제와 영향**  '두 종 사이'가 어느 두 타격 사이인지 불명확해서 -1과 HALF의 시간 관계를 다르게 해석할 수 있다. 내부 수치가 자연어 설명을 대신하면 시간 추론이 어려워진다. 선택 오답이 단서 추론 실패인지 용어 해석 실패인지 구분되지 않는다.

**보완안**  모든 선택을 동일한 종 순서 도식 위에 표시하고 HALF를 'XII가 끝난 뒤, 다음 홈에 닿기 전'처럼 정확한 구간으로 명명한다. 수치·색 없이도 타격 번호와 커서 위치로 읽히게 한다.

**수정 후 확인**  색·소리 없이 네 후보의 선후관계가 명확하며 -1과 HALF가 같은 위치로 해석되지 않는지 확인한다.

<a id="ep01-14"></a>
### EP01-14 · 파형 기록으로 손상된 문장이 복원되는 매개

보통 · 보완 · 퍼즐 B4·B5·J2

- [09_Runtime_Master!S422:S432](https://docs.google.com/spreadsheets/d/1cHx28-B4lG-p9iMyxt7HkQ4Dgk9QeI14UiAJC512v5w/edit#gid=497322651&range=S422:S432) · `EP01_B4_001~B5_SUCCESS_001` — 공명통에 투명지를 대어 파형 기록 → 일지 눌림과 중첩 → 문단 연결
- [09_Runtime_Master!S328:S331](https://docs.google.com/spreadsheets/d/1cHx28-B4lG-p9iMyxt7HkQ4Dgk9QeI14UiAJC512v5w/edit#gid=497322651&range=S328:S331) · `EP01_J1_001~WRONG_002` — J1은 압지·눌림·잉크·종이 결로 복원

**문제와 영향**  J1의 물리 복원은 재료 단서가 분명하지만, B5는 왜 공명통의 파형이 아버지의 손상 문장과 같은 간격인지 연결이 한 번에 주어진다. 필연적 장치인지 우연히 맞는 퍼즐인지 판단할 단서가 부족하다. 플롯을 전진시키는 일지 복원이 세계의 원리보다 임의의 자물쇠로 보일 수 있다.

**보완안**  J1 완료나 일지 여백 조사에서 공명통 눈금과 같은 세 구간 문양을 미리 보여 준다. B5 성공에 '손상 아래 있던 압인 홈이 공명통과 같은 규격'이라는 관찰을 보태 설계된 기록 장치라는 점만 확인한다. 이후의 정밀 방향·재료 비율 정답은 공개하지 않는다.

**수정 후 확인**  파형 중첩 전에 플레이어가 두 대상이 관련 있을 가설을 세울 수 있고, 성공 후 무엇이 복원 원리였는지 설명할 수 있는지 확인한다.

<a id="ep01-15"></a>
### EP01-15 · 선택적 에드가 관찰에 붙은 필수 표식 확인 효과

높음 · 시트 명세 오류 · 시트의 진행·기록 계약

- [09_Runtime_Master!U171:V190](https://docs.google.com/spreadsheets/d/1cHx28-B4lG-p9iMyxt7HkQ4Dgk9QeI14UiAJC512v5w/edit#gid=497322651&range=U171:V190) · `EP01_A2_003 / EP01_A2_ROUTE_CH01~CH02 / EP01_A2_CH03 / EP01_A2_EDGAR_005` — 표식은 이미 확인됨. 시간표 직행/대화/흠집 조사로 분기
- [12_State_Effect!C9:I10](https://docs.google.com/spreadsheets/d/1cHx28-B4lG-p9iMyxt7HkQ4Dgk9QeI14UiAJC512v5w/edit#gid=244026749&range=C9:I10) · `EFF_EP01_0006~0007` — notebook_persistence_confirmed=true와 loop_awareness=confirmed가 EP01_A2_EDGAR_005에만 연결

**문제와 영향**  시트 정본에서 필수 수첩 검증 효과가 선택적 찻잔 흠집 조사 노드에 붙어 있다. 원문상 검증을 끝내도 바로 B1로 가거나 에드가에게 질문하면 이 노드를 지나지 않는다. 표식 검증과 영구 기록의 의미가 분기에 따라 달라지는 계약이다. 현재 Godot에는 별도 보정이 있을 수 있으므로 실제 진행 장애로 단정하지 않는다.

**보완안**  차기 시트 계약 개정에서 필수 A2 공통 완료 노드에 확인 효과를 옮기고, 찻잔 흠집은 선택 관찰 효과만 갖게 한다. 이미 게임에서 처리한다면 시트에 어댑터 책임과 대응 완료 지점을 명시한다.

**수정 후 확인**  질문/시간표 직행/흠집 조사 세 경로 모두 같은 필수 검증 상태를 남기는지 시트와 Session 계약을 대조한다.

<a id="ep01-16"></a>
### EP01-16 · B3-A 보조 반응 후 공통 검증 기록 합류

보통 · 시트 명세 오류 · 시트의 진행·기록 계약

- [09_Runtime_Master!U354:V357](https://docs.google.com/spreadsheets/d/1cHx28-B4lG-p9iMyxt7HkQ4Dgk9QeI14UiAJC512v5w/edit#gid=497322651&range=U354:V357) · `EP01_B3A_ROUTE_COMPLETE / EP01_B3A_MARA1_001 / MARA2_001 / EDGAR_001` — 세 인물 반응은 Scene 10으로 직접 이동
- [10_Route_Edge_Master!A89:N92](https://docs.google.com/spreadsheets/d/1cHx28-B4lG-p9iMyxt7HkQ4Dgk9QeI14UiAJC512v5w/edit#gid=984194965&range=A89:N92) · `EP01_ROUTER_B3A_REACTION` — 인물 반응이 없을 때만 EP01_B3A_ROUTE_COMPLETE로 이동
- [12_State_Effect!C17:I18](https://docs.google.com/spreadsheets/d/1cHx28-B4lG-p9iMyxt7HkQ4Dgk9QeI14UiAJC512v5w/edit#gid=244026749&range=C17:I18) · `EFF_EP01_0014~0015` — 배치 검증·시계망 역할 지식은 EP01_B3A_ROUTE_COMPLETE에 연결

**문제와 영향**  시트에서는 보조 반응이 있는 경로가 검증 기록 노드를 건너뛴다. 도움을 받은 플레이어만 완성 배치의 기록 계약이 달라진다. 관계 보상이 기록 누락의 조건이 되어 서사와 퍼즐 보존 원칙을 해친다. 실제 게임의 Session 완료 처리 여부는 별도다.

**보완안**  세 반응을 모두 EP01_B3A_ROUTE_COMPLETE로 합류시키거나 공통 퍼즐 성공 커밋에 효과를 둔다. 개별 대사에 같은 효과를 복제하지 않는다.

**수정 후 확인**  보조 없음/마라/비피/에드가 경로의 완료 뒤 기록·리셋·숏컷 준비가 동일한지 확인한다.

<a id="ep01-17"></a>
### EP01-17 · 실패 원인별 대사와 성공 목격 효과

보통 · 시트 명세 오류 · 시트의 진행·기록 계약

- [10_Route_Edge_Master!A98:N99](https://docs.google.com/spreadsheets/d/1cHx28-B4lG-p9iMyxt7HkQ4Dgk9QeI14UiAJC512v5w/edit#gid=984194965&range=A98:N99) · `EP01_ROUTER_B3B_ACTUAL_RESULT` — 실패 fallback이 기준 오류 EP01_BF_REF_001로만 이동
- [09_Runtime_Master!S372:S383](https://docs.google.com/spreadsheets/d/1cHx28-B4lG-p9iMyxt7HkQ4Dgk9QeI14UiAJC512v5w/edit#gid=497322651&range=S372:S383) · `EP01_BF_REF/RELAY/OUTPUT/PHASE_*` — 원인별 실패 설명은 따로 존재
- [12_State_Effect!C24:I25](https://docs.google.com/spreadsheets/d/1cHx28-B4lG-p9iMyxt7HkQ4Dgk9QeI14UiAJC512v5w/edit#gid=244026749&range=C24:I25) · `EFF_EP01_0021~0022` — 마라2 성공 목격 노드에 '실패 시 BF'를 failure_knowledge로 추가

**문제와 영향**  시트 라우트만 따라가면 중계·출력·위상 오류도 기준 오류 설명으로 빠진다. 별도로 성공 목격 노드에 실패 기록 효과가 연결되어 결과 의미가 섞여 있다. 현재 게임은 controller에서 실패 category별 시작 노드를 별도 선택하고 있어 실제 실패 설명이 전부 잘못된다고 보지는 않는다. 시트가 정본이라는 설명과 실제 어댑터 책임이 어긋나 향후 대사 개정·이식 때 원인별 학습 정보가 소실될 수 있다.

**보완안**  원인별 실패 간선을 시트에 명시하거나 category 매핑이 외부 Session 책임임을 계약 열에 적는다. 비피 성공 노드의 실패 기록 효과는 실제 의도에 맞는 별도 실패 노드/효과로 분리한다.

**수정 후 확인**  모든 실패 범주에서 다른 원인을 정답처럼 기록하지 않는지 확인하고, 성공만 한 상태에 active failure가 새로 생기지 않는지 대조한다.

## EP02 · 검은 거울

현재 원본 Runtime 490행을 모두 읽고 Scene 12개·Branch 10개·사용인 주제 5개·Route 71행·Predicate 369행·Effect 50행을 대조했다. 배합 정답(물5·안정제1·원액2), 현장 재시도와 당일 비가역 실패의 구분, 색·문양·음향 대체, C5 필수 BODY/PERSONALITY와 선택 채널, J3의 방향 미확정은 설계 의도가 일관되며 유지할 만하다. 우선 수정은 자유 조사 순서에서 지식을 선취하는 C21_007, 비피 음향 결손 설명 불일치, 선택 대상이 생략된 마라 문장이다. C4 검증과 실패·도구 회수의 인과는 규칙 확정이 필요하다.

| 검토 구간 | 평가 |
| --- | --- |
| 플롯 C0~C1 | 출구·함정·보호 책임의 긴장은 유효하다. 금지 권한과 실제 방관의 기준을 한 번 밝혀 주면 개연성이 좋아진다. |
| 조사 C2/C2_1 | 양 관계·순서 단서가 두 장소에 분산된 구조는 좋다. 주방 선행 때 미관측 단서 선취를 수정해야 한다. |
| 중성 세정제 C3 | 물+안정제+원액=8, 원액=2×안정제, 물=첨가제합+2이므로 유일한 양의 정수해는 5:1:2다. 과교반은 거품을 기다리는 설명이 있으며 무조건 폐기로 해석하지 않는다. 물 없는 첨가제 차단은 최신 로컬 반영 이력에 있으므로 새 미구현 버그로 지적하지 않는다. |
| 파형·마른 시험·실제 닦기 C4 | 중첩(반전 없음·시계90도·하단)과 경로(직선→짧은→긴→고리시계) 근거 및 단계별 피드백이 있다. 마른 시험 통과 이후 어떤 변화가 실제 실패를 만드는지 계약을 더 명확히 할 필요가 있다. |
| 실패·목격·수면·CSHORT | 실패 뒤 조사 또는 수면을 고르고 재료 동선만 축약하는 구조가 명시되어 있다. 관계 도움은 정답을 바꾸지 않는다. 도구 회수와 코팅 경화의 인과만 별도 확인한다. |
| 진단면·채널·탁본 C5 | 외부 기준 미달을 종말 확정으로, 안정 상태를 안전 확정으로 읽지 않게 하는 반복 문구가 좋다. 다섯 사용인과 SUBJECT 권한은 구분되어 있어 여섯 번째 사용인 오류로 보지 않는다. |
| 사용인 5명 | 다섯 사용인 모두 검토했다. 마라 선택 목적어, 비피 설명/인덱스 상태, 루카의 정답 비공개 대사, 이리스 계절 선택의 개별 반응을 보완하면 관계 장면이 선명해진다. |
| J3·기억·EP03 이행 | 세 기준점과 앞뒤 비교를 주고 정확한 회전값은 평면도 D0로 남기는 구분은 유지한다. 선택 기억을 생략했을 때 집의 설계·문의 제작·현재 잠금 책임을 연결하는 독백의 근거는 교차 검토가 필요하다. |
| 기존 QA·최신 구현 이력 | 시트의 NOT_CONNECTED·미착수 표기만으로 게임 미연동을 단정하지 않았다. 내부 ID 자연어 대체·장소 정규화·감각 자막 설정 연결은 2026-11-03 로컬 검증 이력을 반영해 새 버그 목록에서 제외했다. |

<a id="ep02-01"></a>
### EP02-01 · C2_1을 먼저 조사하는 경로 / C21_007

높음 · 원문 오류 · 퍼즐·정보 순서

- [01_Scene!A7:G7](https://docs.google.com/spreadsheets/d/1IPKDxXgujecsgbn3hnD6sfCYqwcXdr1cZd3icv0_mZI/edit#gid=1743682860&range=A7:G7) · `Scene 3` — C2·C2_1 조사 순서 자유
- [09_Runtime_Master!B74:AL80](https://docs.google.com/spreadsheets/d/1IPKDxXgujecsgbn3hnD6sfCYqwcXdr1cZd3icv0_mZI/edit#gid=844893755&range=B74:AL80) · `EP02_C21_001~007` — 안정제 하나, 원액 둘, 그리고 둘을 합한 것보다 물이 둘 더 많다.
- [09_Runtime_Master!B61:S66](https://docs.google.com/spreadsheets/d/1IPKDxXgujecsgbn3hnD6sfCYqwcXdr1cZd3icv0_mZI/edit#gid=844893755&range=B61:S66) · `EP02_C2_003·006` — 물의 양 관계와 총량 8은 도구실 기록에서 얻음

**문제와 영향**  주방 C2_1을 먼저 읽어도 C21_007이 아직 보지 않은 C2의 물 관계와 정답의 일부를 알고 말한다. C21_007의 display_condition_id는 NONE이다. 두 기록을 조합하는 C3보다 앞서 '안정제 하나, 원액 둘'을 확정하는 점도 추리 단계를 앞당긴다. 조사 순서 자유라는 약속과 주인공의 지식이 맞지 않고, 정보를 모아 스스로 배합을 푸는 성취가 줄어든다.

**보완안**  C21_007은 '원액은 안정제의 두 배. 물을 먼저 넣고 충분히 퍼뜨린 뒤 원액을 넣는다.'처럼 그 장소에서 확인한 사실만 요약한다. C2와 C2_1을 모두 읽은 합류에서 총량·물 관계를 합치고, 1·2·5의 수치는 카드 검증 성공 뒤 공개한다.

**수정 후 확인**  도구실→주방과 주방→도구실 두 경로를 대조해, 아직 읽지 않은 단서나 검증 전 정답 수치가 대사·수첩에 나오지 않는지 확인한다.

<a id="ep02-02"></a>
### EP02-02 · C0 접근 금지 → C4 개입

높음 · 설정 확인 · 플롯·에드가

- [09_Runtime_Master!B7:S53](https://docs.google.com/spreadsheets/d/1IPKDxXgujecsgbn3hnD6sfCYqwcXdr1cZd3icv0_mZI/edit#gid=844893755&range=B7:S53) · `EP02_C0_004~011, EP02_C0_MERGE_001~006, EP02_EDGAR_S2_001~007` — 이 공간에는 가까이 오지 않는 편이 좋습니다. / 그의 충고에도 길은 닫히지 않았다.
- [09_Runtime_Master!B99:S105](https://docs.google.com/spreadsheets/d/1IPKDxXgujecsgbn3hnD6sfCYqwcXdr1cZd3icv0_mZI/edit#gid=844893755&range=B99:S105) · `EP02_C4_EDGAR_001~WAIT_001` — 준비하신 천을 확인하겠습니다. / 순찰이 끝날 때까지 기다린다.

**문제와 영향**  에드가는 위험을 경고하고 책임을 강조하지만, 주인공이 버티자 물러선다. 뒤에는 도구를 검사·회수할 권한까지 드러난다. '말려야 하지만 막을 수 없는 이유'가 대사에 없어, 보호 책임과 행동의 기준이 흔들려 보인다. 미스터리의 의도적인 침묵이 편의적인 방관으로 읽힐 수 있고, 높은 경계에서만 개입하는 이유도 약해진다.

**보완안**  에드가가 가진 권한의 한계를 한 문장 또는 동작으로 보인다. 예: '출입을 금할 권한은 제게 없습니다. 다만 위험한 도구는 확인하겠습니다.' 비밀 때문에 직접 설명 못 하는 경우에는 거짓말 대신 말끝을 멈추는 연출을 둔다. 핵심 정답은 그대로 유지한다.

**수정 후 확인**  C0 세 선택과 C4 고·저경계 경로 모두에서 에드가의 금지·허용·도구 개입 기준이 같은 원칙으로 설명되는지 검토한다.

<a id="ep02-03"></a>
### EP02-03 · 마라의 기록 보존·삭제 선택

높음 · 보완 · 대상별 대사·호감

- [09_Runtime_Master!B67:S73](https://docs.google.com/spreadsheets/d/1IPKDxXgujecsgbn3hnD6sfCYqwcXdr1cZd3icv0_mZI/edit#gid=844893755&range=B67:S73) · `EP02_MARA1_S2_001, CH01~03, KEEP_001, DELETE_001` — 빨간 줄 친 건 쓰지 마십쇼. / 남겨 두는 게 좋겠어. / 깨끗하게 지워야지.
- [12_State_Effect!A10:Q14](https://docs.google.com/spreadsheets/d/1IPKDxXgujecsgbn3hnD6sfCYqwcXdr1cZd3icv0_mZI/edit#gid=2091366464&range=A10:Q14) · `EFF_EP02_0007~0011` — 보존 bond+1, 삭제 alert+1

**문제와 영향**  직전 대사는 '망한 제조법을 쓰지 말라'인데 선택지의 '남기다/지우다'에는 목적어가 없다. 장부의 실패 기록을 지우는 것인지, 거울 코팅을 지우는 것인지, 위험한 제조법을 폐기하는 것인지 갈릴 수 있다. 사용자가 의도한 뜻과 달리 경계가 오르며, 마라의 기록 철학을 알아보는 선택이 문장 해석 함정이 될 수 있다.

**보완안**  선택지에 대상을 명시한다. 예: '실패한 기록도 장부에 남겨 두자.' / '실패한 기록은 장부에서 지우는 게 낫겠어.' 이 선택이 실제 삭제 명령이 아니라 의견이라면 응답도 그 선에서 유지한다.

**수정 후 확인**  직전 대사만 읽은 독자에게 선택지별 지시 대상과 예상되는 마라의 감정이 분명한지 확인한다. 효과는 실제 선택 본문 완료 뒤 한 번만 적용한다.

<a id="ep02-04"></a>
### EP02-04 · 에드가의 이유 질문 보상

보통 · 보완 · 대상별 대사·호감

- [09_Runtime_Master!B15:S32](https://docs.google.com/spreadsheets/d/1IPKDxXgujecsgbn3hnD6sfCYqwcXdr1cZd3icv0_mZI/edit#gid=844893755&range=B15:S32) · `EP02_C0_CH01~02, REASON_001~006, FATHER_001~009` — 내가 왜? → 그러니 이만 돌아가십시오. / 아빠라면 허락하셨을 걸.
- [12_State_Effect!A4:Q5](https://docs.google.com/spreadsheets/d/1IPKDxXgujecsgbn3hnD6sfCYqwcXdr1cZd3icv0_mZI/edit#gid=2091366464&range=A4:Q5) · `EFF_EP02_0001~0002` — 이유 질문 bond+1 / 아버지 언급 alert+1

**문제와 영향**  이유를 직접 묻는 태도를 좋아하고 아버지 권위에 기대는 태도를 경계하는 설계는 가능하다. 다만 현재 이유 질문 응답은 끝까지 퇴거 요구라서, bond가 오른 감정적 근거가 거의 드러나지 않는다. 관계가 선택지 문구의 정답 맞히기처럼 느껴질 수 있다.

**보완안**  bond가 오르는 분기 끝에 짧은 인정 또는 누그러진 동작을 넣는다. 예: '이유를 물으시는 편이 낫습니다. 누군가의 허락을 빌리는 것보다.' 아버지 분기의 상처 주는 말에는 기존 실언 인정 이후 잠시 기다리는 동작을 더해 경계와 악의를 구별한다.

**수정 후 확인**  수치 표시는 감춰도 두 응답의 온도 차이와 에드가가 존중하는 태도를 독자가 설명할 수 있는지 확인한다.

<a id="ep02-05"></a>
### EP02-05 · 비피의 비교·설명 선택과 인덱스 지식

보통 · 설정 확인 · 대상별 대사·단서 상태

- [09_Runtime_Master!B157:S163](https://docs.google.com/spreadsheets/d/1IPKDxXgujecsgbn3hnD6sfCYqwcXdr1cZd3icv0_mZI/edit#gid=844893755&range=B157:S163) · `EP02_MARA2_S2_CH01~03, COMPARE_001, EXPLAIN_001` — 비교: 나눠진 거라는 정도 / 설명: 내 기록 일부가 다른 네 줄의 끝에 붙어 있다
- [12_State_Effect!A41:Q45](https://docs.google.com/spreadsheets/d/1IPKDxXgujecsgbn3hnD6sfCYqwcXdr1cZd3icv0_mZI/edit#gid=2091366464&range=A41:Q45) · `EFF_EP02_0038~0042` — COMPARE에만 mara2_archive_index_known=true, EXPLAIN에는 완료만 기록
- [09_Runtime_Master!B422:S436](https://docs.google.com/spreadsheets/d/1IPKDxXgujecsgbn3hnD6sfCYqwcXdr1cZd3icv0_mZI/edit#gid=844893755&range=B422:S436) · `EP02_C5_CH_MARA2_REPEAT, EP02_REL_MARA2_INDEX` — 반복 채널 조사에서도 다른 네 채널 끝의 분산을 설명

**문제와 영향**  명시적으로 더 자세한 설명을 들은 선택에는 인덱스 지식이 생기지 않고, 비교를 택했을 때만 생긴다. '분산 사실을 들음'과 '직접 비교해 인덱스를 검증함'을 구분하려는 의도일 수 있지만 현재 대사와 플래그 이름만으로는 구별이 보이지 않는다. 같은 사실을 알아도 후속 반응이 다르거나 이미 들은 사실을 다시 모르는 듯 말할 수 있다. 익명 인덱스 fallback이 있으므로 필수 진행 차단 오류로 단정하지 않는다.

**보완안**  인덱스가 실제 참조표라면 비교 결과에 좌표·끝점 표식 등 획득 증거를 보여주고, 설명 선택에는 '분산 가능성 관찰' 상태만 남긴다. 단순히 분산 사실을 아는 뜻이라면 설명·반복 조사도 같은 지식 상태를 갱신한다.

**수정 후 확인**  비교·걱정·설명 세 선택과 반복 채널 조사 뒤 수첩 및 후속 '인덱스를 안다' 대사를 대조한다. 정보를 실제로 확인한 수준보다 앞선 해금을 주지 않는다.

<a id="ep02-06"></a>
### EP02-06 · 비피의 빠른 세 음

보통 · 원문 오류 · 퍼즐·감각 단서

- [09_Runtime_Master!B155:S155](https://docs.google.com/spreadsheets/d/1IPKDxXgujecsgbn3hnD6sfCYqwcXdr1cZd3icv0_mZI/edit#gid=844893755&range=B155:S155) · `EP02_C5_TRACE_003` — 빠른 세 음 중 마지막만이 비어 있다.
- [09_Runtime_Master!B412:S412](https://docs.google.com/spreadsheets/d/1IPKDxXgujecsgbn3hnD6sfCYqwcXdr1cZd3icv0_mZI/edit#gid=844893755&range=B412:S412) · `EP02_CAP_PURPLE` — 마지막 음 뒤가 비정상적으로 길게 비어 있다.
- [09_Runtime_Master!B450:S450](https://docs.google.com/spreadsheets/d/1IPKDxXgujecsgbn3hnD6sfCYqwcXdr1cZd3icv0_mZI/edit#gid=844893755&range=B450:S450) · `EP02_OBJ_COLOR_SOUND_ALT` — 셋째 음 뒤의 무음이 다른 채널보다 길다.

**문제와 영향**  핵심 탁본 대사는 셋째 음 자체가 없다고 하지만, 감각 자막과 외부 패널 대사는 셋째 음을 들은 뒤의 공백이 길다고 한다. 같은 채널 결손을 서로 다른 리듬으로 설명한다. 음향·자막으로 기록 길이와 결손 위치를 비교할 때 어떤 신호를 정답 근거로 삼아야 하는지 흔들린다.

**보완안**  셋째 음 소실인지, 셋째 음 뒤의 데이터 구간 소실인지 먼저 확정하고 탁본·관계 대화의 direction·채널 자막을 같은 구조로 맞춘다. 후자가 의도라면 S155를 '세 음은 들리지만 마지막 음 뒤의 구간이 유난히 길게 비어 있다.'로 수정한다.

**수정 후 확인**  음향을 끄고 자막만 읽는 경우와 실제 리듬을 듣는 경우 모두 같은 위치의 결손을 인식하는지 확인한다.

<a id="ep02-07"></a>
### EP02-07 · 루카의 실패 목격 반응

보통 · 보완 · 대상별 대사

- [09_Runtime_Master!B126:S128](https://docs.google.com/spreadsheets/d/1IPKDxXgujecsgbn3hnD6sfCYqwcXdr1cZd3icv0_mZI/edit#gid=844893755&range=B126:S128) · `EP02_C4_WITNESS_LUCA_001~003` — 시험지를 두 장 두는 게 좋겠어요... / 그리고 정답은··· 제가 말하지 않을게요.
- [09_Runtime_Master!B78:S82](https://docs.google.com/spreadsheets/d/1IPKDxXgujecsgbn3hnD6sfCYqwcXdr1cZd3icv0_mZI/edit#gid=844893755&range=B78:S82) · `EP02_C21_005~LUCA_001` — 위험하면 멈추라고 꼭 말씀드릴게요.

**문제와 영향**  루카는 안전 정보와 도움을 끝까지 주는 인물인데, 실패한 직후 '정답을 말하지 않겠다'는 말은 작중 이유 없이 게임의 힌트 제한을 직접 선언한다. 배합이 이미 중성으로 검증된 뒤 경로에서 실패한 상황에 시험지 추가만 제안하는 것도 원인 대응이 흐리다. 걱정하는 인물이 도움을 일부러 아끼는 듯 보이고, 화학 실패와 경로 실패를 혼동시킬 수 있다.

**보완안**  정답 비공개 대신 그가 실제로 확인한 범위와 역할을 말한다. 예: '세정제는 괜찮았어요. 제가 본 건 천이 멈춘 자리까지예요. 손이 당기면 바로 말씀해 주세요.' 원인이 제조 문제일 때만 시험지를 제안한다.

**수정 후 확인**  각 실패 원인에서 루카 반응이 이미 검증한 배합을 의심하게 만들지 않으면서 안전 역할을 유지하는지 확인한다.

<a id="ep02-08"></a>
### EP02-08 · 이리스의 네 계절 선택

낮음 · 보완 · 대상별 대사·호감

- [09_Runtime_Master!B164:S169](https://docs.google.com/spreadsheets/d/1IPKDxXgujecsgbn3hnD6sfCYqwcXdr1cZd3icv0_mZI/edit#gid=844893755&range=B164:S169) · `EP02_IRIS_S2_001, CH01~04, RESULT_001` — 봄·여름·가을·겨울이 모두 같은 '온도가 사라져요' 응답으로 합류
- [12_State_Effect!A46:Q48](https://docs.google.com/spreadsheets/d/1IPKDxXgujecsgbn3hnD6sfCYqwcXdr1cZd3icv0_mZI/edit#gid=2091366464&range=A46:Q48) · `EFF_EP02_0043~0045` — 어느 계절이든 bond+1, iris_season_image=<choice> 기록

**문제와 영향**  정답 없는 선호 선택이라는 설계와 선택값 보존은 적절하다. 다만 네 계절이 당장 같은 대사로만 끝나 선택한 기억을 이리스에게 건넸다는 감각이 약하다. 관계 장면의 상호성이 줄고, 계절 선택이 형식적 입력처럼 보일 수 있다.

**보완안**  공통 결말 앞에 계절마다 한 줄의 감각을 붙인다. 예: 봄은 '젖은 흙의 냄새부터 떠올려 볼게요.', 겨울은 '차갑다는 말 말고, 손끝이 아팠던 쪽부터요.' 다음 짧은 반응에서는 저장된 계절을 한 번 다시 부른다. 보상과 필수 진행은 동일하게 둔다.

**수정 후 확인**  네 선택 모두 정답 판정 없이 통과하고, 이후 반응이 실제로 고른 계절을 기억하며 수면 뒤에도 바뀌지 않는지 확인한다.

<a id="ep02-09"></a>
### EP02-09 · 마른 천 검증과 실제 닦기의 실패 조건

높음 · 설정 확인 · 퍼즐·실패 공정성

- [01_Scene!A11:G12](https://docs.google.com/spreadsheets/d/1IPKDxXgujecsgbn3hnD6sfCYqwcXdr1cZd3icv0_mZI/edit#gid=1743682860&range=A11:G12) · `Scene 7·8` — Scene 8 진입: 계획 verified
- [09_Runtime_Master!B110:S114](https://docs.google.com/spreadsheets/d/1IPKDxXgujecsgbn3hnD6sfCYqwcXdr1cZd3icv0_mZI/edit#gid=844893755&range=B110:S114) · `EP02_C4_DRY_SUCCESS_001, COMMIT_001~CH03` — 경로를 확인했다. / 계획을 다시 확인한다. / 세정제를 묻혀 실행한다.
- [09_Runtime_Master!B307:S311](https://docs.google.com/spreadsheets/d/1IPKDxXgujecsgbn3hnD6sfCYqwcXdr1cZd3icv0_mZI/edit#gid=844893755&range=B307:S311) · `EP02_C4_FB_FAIL_ANCHOR~RING` — 시작점·진입·분기·순서·고리 오류에 HARD FAILURE

**문제와 영향**  시트는 완전히 검증된 계획으로 실제 닦기에 들어간다고 쓰면서 동일한 계획 요소의 오답을 실제 실패로 둔다. 검증 후 계획을 바꿀 수 있는지, 검증하지 않고 위험을 감수해 실행할 수 있는지, 실제 조작에서 별도의 실수가 발생하는지 명세가 분리되지 않았다. 로컬 구현은 계획 변경 시 마른 시험 통과를 해제하며, wet 실행 자체는 dry_passed를 필수로 요구하지 않는 것으로 읽힌다. 플레이어가 '검증 완료'를 안전 보증으로 읽으면, 이미 맞다고 확인한 행동에서 하루를 잃는 결과가 불공정하게 느껴진다.

**보완안**  검증된 계획 그대로 실행하면 성공한다는 계약을 우선 확정한다. 미검증 계획 실행을 허용한다면 확인창에 '현재 계획은 마른 시험을 통과하지 않았음'을 함께 표시한다. 실제 손동작 차이가 실패 원인이라면 그 입력 규칙을 마른 시험에서 먼저 연습시킨다. Scene 8 진입 설명도 같은 계약으로 맞춘다.

**수정 후 확인**  검증 직후 그대로 실행, 검증 뒤 한 카드 변경, 중첩 변경, 검증 없이 실행을 각각 확인해 경고·성공·실패 사유가 현재 계획과 일치하는지 검토한다.

<a id="ep02-10"></a>
### EP02-10 · tool_confiscated가 코팅 경화 실패가 되는 이유

보통 · 설정 확인 · 퍼즐·에드가 개입

- [09_Runtime_Master!B99:S105](https://docs.google.com/spreadsheets/d/1IPKDxXgujecsgbn3hnD6sfCYqwcXdr1cZd3icv0_mZI/edit#gid=844893755&range=B99:S105) · `EP02_C4_EDGAR_001~WAIT_001` — 천 검사·질문·대기로 개입 우회
- [09_Runtime_Master!B115:S119](https://docs.google.com/spreadsheets/d/1IPKDxXgujecsgbn3hnD6sfCYqwcXdr1cZd3icv0_mZI/edit#gid=844893755&range=B115:S119) · `EP02_C4_ACTUAL_001~003, CF_001~002` — 젖은 천이 닿는 공통 본문 뒤 검은 막이 다시 닫힘
- [09_Runtime_Master!B312:S312](https://docs.google.com/spreadsheets/d/1IPKDxXgujecsgbn3hnD6sfCYqwcXdr1cZd3icv0_mZI/edit#gid=844893755&range=B312:S312) · `EP02_C4_FB_FAIL_TOOL` — 에드가가 도구를 회수했다. tool_confiscated를 기록했다.

**문제와 영향**  도구를 회수당한 사건이 경로를 잘못 닦아 코팅이 굳은 사건과 같은 당일 비가역 실패로 묶인다. 젖은 천이 닿기 전에 회수했다면 물리 상태까지 영구적으로 실패하는 이유가 부족하다. 로컬 구현도 미처리 고경계 개입에서 도구 회수→cleaner 소모→locked를 함께 처리하므로 원인 설명이 필요하다. 에드가가 안전을 위해 회수했는데 더 위험한 결과를 만든 것처럼 보이거나, 플레이어가 실제로 시작하지 않은 행동 때문에 하루를 잃는 느낌이 생긴다.

**보완안**  젖은 실행 전에 회수했다면 코팅은 유지하고 도구 재확보·순찰 처리로 되돌린다. 당일 실패를 유지하려면 '접촉 직후 에드가가 손을 잡아 선이 끊겼다'처럼 개입 시점을 분명히 보여주고 책임 반응을 다르게 둔다. 어느 계약인지 확정한 후에 구현을 맞춘다.

**수정 후 확인**  회수 발생 시점, 세정제 소비, 거울 접촉 여부, 경화 원인, 수첩 실패 원인이 한 사건으로 연결되는지 확인한다.

<a id="ep02-11"></a>
### EP02-11 · 기상 권한 잠김의 의미

보통 · 보완 · 플롯·증거 해석

- [09_Runtime_Master!B150:S150](https://docs.google.com/spreadsheets/d/1IPKDxXgujecsgbn3hnD6sfCYqwcXdr1cZd3icv0_mZI/edit#gid=844893755&range=B150:S150) · `EP02_C5_WAKE_001` — 절차가 없다는 뜻이 아니라 누군가 권한을 막았다는 뜻이다.
- [09_Runtime_Master!B399:S400](https://docs.google.com/spreadsheets/d/1IPKDxXgujecsgbn3hnD6sfCYqwcXdr1cZd3icv0_mZI/edit#gid=844893755&range=B399:S400) · `EP02_C5_HOT_WAKE_FIRST~REPEAT` — 절차가 존재한다는 사실만 확인된다. / 그가 혼자 설정했다는 증거는 없다.

**문제와 영향**  핵심 독백은 LOCKED만으로 '누군가가 막았다'고 확정하고, 반복 핫스폿은 잠금의 작성자·의도는 불명이라고 신중하게 구분한다. 주인공의 의심이라면 가능하지만 현재 문장은 진단 사실의 번역처럼 읽힌다. 플레이어가 아직 밝혀지지 않은 행위자·악의를 이미 검증한 사실로 받아들여 이후 보호/통제 갈등의 여지가 줄어든다.

**보완안**  '잠겨 있다. 누군가 막아 둔 걸까, 아니면 아직 충족하지 못한 조건이 있는 걸까.'처럼 관측과 추론을 분리한다. 수첩에는 잠김만 검증 사실로, 에드가 서명과 연관성은 의심으로 남긴다.

**수정 후 확인**  최초·반복·수첩을 모두 읽어도 누가 왜 잠갔는지는 미확정으로 이해되는지 확인한다.

<a id="ep02-12"></a>
### EP02-12 · 중성 세정제가 거울 회로를 보존하는 이유

보통 · 보완 · 퍼즐·세계관

- [09_Runtime_Master!B62:S64](https://docs.google.com/spreadsheets/d/1IPKDxXgujecsgbn3hnD6sfCYqwcXdr1cZd3icv0_mZI/edit#gid=844893755&range=B62:S64) · `EP02_C2_002~004` — 강한 약품과 마찰은 하부 선을 지움
- [09_Runtime_Master!B75:S79](https://docs.google.com/spreadsheets/d/1IPKDxXgujecsgbn3hnD6sfCYqwcXdr1cZd3icv0_mZI/edit#gid=844893755&range=B75:S79) · `EP02_C21_002~006` — 안정제·원액 비율과 중성 문양
- [09_Runtime_Master!B140:S141](https://docs.google.com/spreadsheets/d/1IPKDxXgujecsgbn3hnD6sfCYqwcXdr1cZd3icv0_mZI/edit#gid=844893755&range=B140:S141) · `EP02_C5_001~002` — 코팅은 떨어지지 않고 안쪽으로 접힘

**문제와 영향**  실험 장부는 배합과 표면 손상의 경험칙은 충분히 제공한다. 다만 왜 '중성'인 특정 약품이 코팅을 지우는 대신 접고 회로를 여는지는 징후만 있고 역할 연결이 약하다. 청소 퍼즐이 전자식 연결 장치를 여는 단계로 바뀌는 순간에 작은 인과 다리가 있으면 좋다. 수학 배합·종 파형·닦기라는 서로 다른 입력이 작가가 정한 연속 열쇠처럼 보일 수 있다.

**보완안**  장부에 작중 실험 사실 한 줄을 추가한다. 예: '중성 상태에서 막은 녹지 않았다. 종이 울린 동안만 홈의 진동을 따라 접혔다.' 안정제와 원액의 실제 화학 성분을 설명하기보다는 이 장치에서 관찰한 작동을 서술한다.

**수정 후 확인**  플레이어가 강한 약품 대신 중성 배합을 만들고 종 신호·홈 경로를 함께 써야 하는 이유를 문서 근거로 설명할 수 있는지 확인한다.

<a id="ep02-13"></a>
### EP02-13 · 몸·인격 채널 발견 이후의 에드가·마라·루카

보통 · 보완 · 플롯·대상별 반응

- [09_Runtime_Master!B143:S156](https://docs.google.com/spreadsheets/d/1IPKDxXgujecsgbn3hnD6sfCYqwcXdr1cZd3icv0_mZI/edit#gid=844893755&range=B143:S156) · `EP02_C5_004, C5_BODY_001, C5_PERSONALITY_001, TRACE_001~004` — 시뮬레이션 밖에 내 몸이 있다. / 다섯 이름과 다섯 문양
- [09_Runtime_Master!B157:S169](https://docs.google.com/spreadsheets/d/1IPKDxXgujecsgbn3hnD6sfCYqwcXdr1cZd3icv0_mZI/edit#gid=844893755&range=B157:S169) · `EP02_MARA2_S2, EP02_IRIS_S2` — C5 뒤 선택 대화는 비피 기록·이리스 계절
- [09_Runtime_Master!B138:S139](https://docs.google.com/spreadsheets/d/1IPKDxXgujecsgbn3hnD6sfCYqwcXdr1cZd3icv0_mZI/edit#gid=844893755&range=B138:S139) · `EP02_C4_SUCCESS_EDGAR_001, EP02_C4_SUCCESS_MARA1_001` — 두 사용인의 반응은 진단 내용을 읽기 전 표면 개방에 머묾

**문제와 영향**  주인공이 자신의 바깥 신체와 사용인 인격 채널을 발견하는 큰 전환인데, 선택 관계 반응은 비피·이리스에 집중된다. 에드가의 통제, 루카의 생명 유지, 마라의 손상 기록에 대한 새 의문을 당사자에게 짧게라도 표현할 기회가 부족하다. 진단면이 인물 관계를 재해석하는 장면보다 설정 설명 화면으로 소비될 수 있다.

**보완안**  C5 뒤 각자의 확정 장소에 짧은 선택 후속 질문 하나씩을 둔다. 예: 에드가에게 '잠금선이 네 문양과 닮았어.', 루카에게 '화면의 박동이 네 문양과 같았어.', 마라에게 '지워진 기록에도 네 흔적이 남았어.' 답은 관찰 범위만 인정하고 범인·신체 위치·후반 비밀은 확정하지 않는다. J3 필수 진행은 열어 둔다.

**수정 후 확인**  후속 대화를 건너뛰어도 J3에 갈 수 있고, 들은 경우에는 해당 인물에 대한 의문·신뢰 변화가 구체적으로 느껴지는지 확인한다.

<a id="ep02-14"></a>
### EP02-14 · 실제 닦기 중 주인공 지칭

낮음 · 원문 오류 · 대사·시점

- [09_Runtime_Master!B117:S117](https://docs.google.com/spreadsheets/d/1IPKDxXgujecsgbn3hnD6sfCYqwcXdr1cZd3icv0_mZI/edit#gid=844893755&range=B117:S117) · `EP02_C4_ACTUAL_003` — 고리를 닫는 동안 거울 속 주인공의 호흡만 실제보다 늦다.
- [09_Runtime_Master!B34:S34](https://docs.google.com/spreadsheets/d/1IPKDxXgujecsgbn3hnD6sfCYqwcXdr1cZd3icv0_mZI/edit#gid=844893755&range=B34:S34) · `EP02_C0_SILENT_002` — 거울 속 빈자리가 나의 호흡보다 한 박자 늦게 오므라든다.

**문제와 영향**  SUBJECT의 1인칭 독백에서 자기 자신을 '주인공'이라고 부른다. 주변은 '나·내'를 사용하므로 기획서 지칭이 대사 안으로 들어온 것으로 읽힌다. 비가역 실행의 긴장 순간에 독백의 시점과 몰입이 잠시 깨진다.

**보완안**  '고리를 닫는 동안 거울 속 내 호흡만 실제보다 늦다.'로 바꾼다. 외부 관찰자의 시점이 의도라면 content_type과 연출을 별도로 정한다.

**수정 후 확인**  SUBJECT 독백에서 '주인공·플레이어' 같은 바깥 지칭이 남아 있는지 확인한다.

## 수정 작업 순서

- [ ] 이름·시점·선택 불일치처럼 판단이 분명한 원문을 먼저 정리한다.
- [ ] 수첩에는 실제 관찰한 사실을 기록하고, 가설은 확인된 사실과 구분한다.
- [ ] 필수 퍼즐 사실은 호감과 무관하게 유지하고, 호감은 말투·자발적 도움·감정의 깊이에 반영한다.
- [ ] 자유 조사 순서와 선택 조사 생략 경로에서 주인공의 지식이 앞서지 않는지 대조한다.
- [ ] C4 검증·회수·실패 규칙과 기억 범위처럼 의도 확인이 필요한 사항을 결정한다.
- [ ] 마지막으로 시트의 공통 완료·효과 참조를 실제 실행 계약과 맞춘다.

대사 수정은 기존 원문 보존 정책을 고려해 차기 콘텐츠 개정안으로 적용한다. 이번 검토는 제안 작성까지이며 원문 교체나 새 설정 확정을 수행하지 않았다.

## 참조한 적용 결정

- [세 시트 게임 반영 검증](../../decisions/세시트_게임반영_검증.md): 2026-11-03 기준 공식 응답·시트 어댑터·실행 검증 범위.
- [EP01 수정 대사 재생 시점](../../decisions/GGB-DEC-2026-0013_EP01_수정대사_재생시점.md): 표식 작성과 다음 아침 확인의 분리, 첫 취침·아침 정본.
- [EP02 대사 장소 정규화](../../decisions/EP02_시트대사_장소정규화.md): 인물별 확정 대화 장소.
- [EP02 내부 식별자와 안내 분리](../../decisions/EP02_플레이어안내_내부식별자_분리.md), [감각 자막·접근성 연결](../../decisions/EP02_감각자막_접근성_연결.md): 이미 반영한 자연어 안내와 접근성 범위.

## 원문 대조 범위

### 프롤로그

- 플롯·진행: `01_Scene!A5:H12; 02_Branch!A5:F9; 09_Runtime_Master!B4:AL145`
- 에드가·아버지: `09_Runtime_Master!B6:V44; B88:V89; B119:V133`
- 마라: `09_Runtime_Master!B16:V23; B151:V166`
- 비피: `09_Runtime_Master!B45:V50; B167:T171; 04_Script_View!N221:O226`
- 루카: `09_Runtime_Master!B51:V80; 12_State_Effect!A8:Q12`
- 이리스: `09_Runtime_Master!B66:V67; B81:V87; B144:T144`
- 퍼즐·실패·재진입: `01_Scene!A5:H12; 02_Branch!A5:F9; 09_Runtime_Master!B151:V249; 11_State_Predicate!A4:L25`
- 관계·호감: `Conversation_Index!A4:T19; 12_State_Effect!A4:Q12`
- 기존 QA·적용 결정: `08_Content_QA!A4:J8; 13_Technical_Lint!A4:M21`

### EP01 · 반복과 시계망

- 필수 플롯 Scene 1~12: `01_Scene!A4:H16;09_Runtime_Master!B4:AL442`
- 선택·실패 Branch 5-E/6-S/7-E/9-R/10-F/10-W: `02_Branch!A4:F10;10_Route_Edge_Master!A4:N145`
- 에드가: `09_Runtime_Master!S63:S82;S175:S190;S205:S217;S268:S327;S533:S560`
- 마라: `09_Runtime_Master!S83:S99;S218:S238;S355;S389:S390;S410`
- 루카: `09_Runtime_Master!S100:S111;S239:S242;S391:S392;S419`
- 이리스: `09_Runtime_Master!S112:S121;S243:S245;S393:S394;S420`
- 비피: `09_Runtime_Master!S122:S131;S246:S249;S356;S395:S396;S412;S421`
- B1/B2: `09_Runtime_Master!S191:S327;S469:S486`
- J1/B3A/B3B/BF/BSHORT: `09_Runtime_Master!S328:S421;S487:S526`
- B4/B5/J2 및 EP02 연결: `09_Runtime_Master!S422:S442`
- 수동 QA·상태 계약: `08_Content_QA!A4:J20;Conversation_Index!A2:T18;11_State_Predicate!A3:L164;12_State_Effect!A3:Q38`

### EP02 · 검은 거울

- 플롯 C0~C1: `09_Runtime_Master!B4:AL60`
- 조사 C2/C2_1: `09_Runtime_Master!B61:AL82`
- 중성 세정제 C3: `09_Runtime_Master!B83:AL95; B194:AL292`
- 파형·마른 시험·실제 닦기 C4: `09_Runtime_Master!B96:AL139; B293:AL364`
- 실패·목격·수면·CSHORT: `09_Runtime_Master!B118:AL139; 10_Route_Edge_Master!A39:N52`
- 진단면·채널·탁본 C5: `09_Runtime_Master!B140:AL156; B365:AL453`
- 사용인 5명: `Conversation_Index!A4:T8; 09_Runtime_Master!B47:S53; B67:S73; B81:S82; B157:S169`
- J3·기억·EP03 이행: `09_Runtime_Master!B170:AL182; B454:AL493`
- 기존 QA·최신 구현 이력: `08_Content_QA!A4:J36; docs/decisions/세시트_게임반영_검증.md`
