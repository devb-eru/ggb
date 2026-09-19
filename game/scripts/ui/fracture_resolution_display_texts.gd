extends RefCounted

const TEXT_EN := {
	# J4 controller and confirmation UI.
	"조사 종료 확인": "End the Investigation?",
	"계속 조사한다": "Continue Investigating",
	"기록을 정리한다": "Organize the Records",
	"네 번째 일지 · 약속과 권한": "Journal IV · Promises and Authority",
	"에드가의 전체 관계 사건은 종료되었다.": "Edgar's full relationship event is now closed.",
	"최소 접근 핀은 기록이나 관계 보상이 아니다.": "The minimum-access pin grants neither a record nor a relationship reward.",
	"코어 접근 핀을 받아 꽂는다": "Take and Insert the Core-Access Pin",
	"약속과 권한의 모순 문장을 읽는다": "Read the Contradiction Between Promise and Authority",
	"획득하지 않은 기록은 빈 인덱스다.": "Records not acquired remain empty indices.",
	"아버지 일지와 시스템 날짜만으로도 네 사건을 배열할 수 있다.": "Father's journal and the system dates are enough to order the four events.",
	"없음": "None",
	"다시 펼친다": "Lay Them Out Again",
	"순서를 확인한다": "Verify the Order",
	"중앙홀": "Central Hall",
	"중앙 홀": "Central Hall",
	"식당": "Dining Room",

	# J4 source labels and restored text.
	"대각선 · 마라 1": "Diagonal Line · Mara 1",
	"꽃잎 · 이리스": "Petal · Iris",
	"이중 맥박 · 루카": "Paired Pulse · Luca",
	"수직선 · 에드가": "Vertical Line · Edgar",
	"이중 액자 · 마라 2": "Double Frame · Mara 2",
	"에드가 · 수직선": "Edgar · Vertical Line",
	"마라 1 · 대각선": "Mara 1 · Diagonal Line",
	"루카 · 이중 맥박": "Luca · Paired Pulse",
	"이리스 · 꽃잎": "Iris · Petal",
	"마라 2 · 이중 액자": "Mara 2 · Double Frame",
	"약속 · 미래의 삶을 약속한 날짜 조각": "Promise · Dated Fragment Promising a Future Life",
	"전환 · 약속 뒤 생체 신경 코어와 인격 프로세스 결합": "Conversion · Bio-Neural Cores Joined to Personality Processes After the Promise",
	"역할 고정 · 전환된 연구원들이 저택의 관리자가 됨": "Roles Fixed · Converted Researchers Became the Mansion's Custodians",
	"주인공 기동 · 역할이 고정된 뒤 사용인들이 의식을 강제로 깨움": "Protagonist Activated · After Their Roles Were Fixed, the Servants Forced Her Consciousness Awake",
	"나는 그들에게 미래의 삶을 약속했다.": "I promised them a life in the future.",
	"그 약속이 육체를 뜻하는지, 기억의 지속을 뜻하는지 끝까지 분명하게 말하지 않았다.": "I never made clear whether that promise meant bodies or merely the continuation of memory.",
	"그들은 집을 움직일 수 있다. 계절을 고치고, 심장을 유지하고, 문을 잠글 수 있다.": "They can move the house, repair its seasons, keep a heart beating, and lock its doors.",
	"하지만 집 밖으로 나가는 문과 누가 이 삶의 주인인지 정하는 권한은 주지 않았다.": "But I gave them neither the door out of the house nor the authority to decide who owns this life.",
	"그들이 너를 깨운 것은 보호만도, 복수만도 아니었다. 너를 붙잡으면 내가 남긴 약속도 아직 끝나지 않았다고 믿을 수 있었기 때문이다.": "They woke you for more than protection and more than revenge. By holding on to you, they could believe the promise I left behind was not yet over.",
	"마지막 문은 내가 열 수 없도록 남겨 두었다. 그것을 배려라고 부를 생각은 없다.": "I left the final door where I could not open it. I will not call that consideration.",
	"너에게 선택권을 돌려준 것이 아니라, 내가 끝내 빼앗지 못한 한 조각이 남아 있었을 뿐이다.": "I did not return your choice. One fragment simply remained that I failed to take from you.",
	"이번에는 누구도 네 대답을 대신 적어서는 안 된다.": "This time, no one must write your answer for you.",
	"복원 인덱스: 사용인들은 연구원 인격이다. 저택의 관리 권한과 주인공 자신의 결정을 실행하는 권한은 서로 다르다.": "Restored index: the servants are researcher personalities. Authority to maintain the mansion is separate from authority to enact the Protagonist's own decision.",
	"마라 2는 다른 네 사람의 이름과 감정 주석을 자기 저장 영역에 나누어 보관했다. 공간이 모자랄 때마다 자기 이름의 확인 기록부터 비웠다. 나는 중단시킬 권한을 끝까지 나누지 않았다.": "Mara 2 divided her own storage to preserve the other four names and emotional annotations. Whenever space ran short, she erased the records that confirmed her own name first. I never shared the authority to stop it.",

	# J4 feedback.
	"파열 이후 합의를 먼저 확인한다.": "Confirm the agreement made after the fracture first.",
	"중앙홀에서 남은 사건을 확인한 뒤 진행한다.": "Review the remaining events in the central hall before proceeding.",
	"완충 전력을 코어 경로와 마지막 저녁에 재배분한다. 남은 사건의 진행은 보관된다. 이는 실패나 완료가 아니다.": "Buffer power is reassigned to the core route and the final evening. Progress in remaining events is archived. This is neither failure nor completion.",
	"조사 종료를 먼저 확인한다.": "Confirm the end of the investigation first.",
	"최소 접근 절차가 필요한 상태가 아니다.": "The minimum-access procedure is not required in the current state.",
	"대시계 기계실 입구에서 에드가가 수직 핀을 건넨다.": "At the entrance to the great-clock machine room, Edgar hands me a vertical pin.",
	"이것으로 코어 접근로까지는 열립니다. 그 이상은 귀하께서 확인해야 합니다. 지금 설명하면 제 변명이 먼저 남습니다.": "This will open the route as far as the core approach. You must verify anything beyond it yourself. If I explain now, my excuses will be what remains first.",
	"주인공이 핀을 꽂는다. 연구원 기록이나 관계 완료는 추가되지 않는다.": "The Protagonist inserts the pin. No researcher record or relationship completion is added.",
	"네 번째 일지는 이미 복원했다.": "Journal IV has already been restored.",
	"일지의 날짜 조각을 확인한다.": "Inspect a dated journal fragment.",
	"날짜 조각을 다시 펼친다. 없는 연구원 기록은 오답이 아니라 빈 인덱스다.": "I lay out the dated fragments again. Missing researcher records are empty indices, not wrong answers.",
	"앞 사건과 뒤 사건이 맞지 않는다. 약속과 전환, 고정된 역할과 기동을 대조한다.": "The earlier and later events do not align. Compare the promise with conversion, then the fixed roles with activation.",
	"네 사건 축이 이어진다. 미래를 약속했지만 선택 권한을 나누지 않았다는 모순이 남는다.": "The four-event axis connects. The contradiction remains: a future was promised, but authority to choose was never shared.",
	"페이지를 배열한 뒤 모순 문장을 조사한다.": "Arrange the pages before examining the contradictory statement.",
	"정의되지 않은 결산 행동이다.": "That record-review action is not defined.",

	# E5 controller UI.
	"마지막으로 정상인 저녁": "The Last Normal Evening",
	"저녁 준비를 따라 식당으로 간다": "Follow the Evening Preparations to the Dining Room",
	"식당으로 돌아간다": "Return to the Dining Room",
	"식탁의 목재와 프레임": "The Table's Wood and Life-Support Frame",
	"다섯 사용인의 자리와 문양": "The Five Servants' Seats and Glyphs",
	"중앙홀 시계를 다시 본다": "Look at the Central-Hall Clock Again",
	"북쪽 정면의 내 자리에 앉는다": "Sit in My North-Facing Seat",
	"코어 접근 준비를 마친다": "Complete Preparations for the Core Approach",
	"코어 접근 준비": "Core-Approach Preparations",
	"저녁의 결산을 마칩니다. 남을지 떠날지는 코어에서 다시 확인합니다.": "Conclude the final evening. Whether to remain or leave will be confirmed again at the core.",
	"아직 준비되지 않았다": "I Am Not Ready Yet",
	"준비를 마친다": "Complete the Preparations",

	# E5 questions and responses.
	"나한테 무엇을 바라고 있어요?": "What do you want from me?",
	"내가 떠나면 여러분은 어떻게 돼요?": "What happens to all of you if I leave?",
	"내가 남으면 무엇이 달라져요?": "What changes if I stay?",
	"에드가: 안전을 확보하고 싶습니다. 그렇다고 귀하의 답을 대신 정할 권한은 없습니다.": "Edgar: I want to secure your safety. That does not give me the right to decide your answer for you.",
	"루카: 다치지 않으셨으면... 해요. 제 바람과 아가씨의 결정은... 같은 것이 아니니까요.": "Luca: I hope you won't be hurt... But what I want and what you decide... are not the same thing.",
	"루카: 여기 남은 생체 신경 코어의 유지가 바로 끝나는 건... 아니에요. 다만 얼마나 오래 가능한지, 바깥에서 무엇을 만날지는... 보장할 수 없어요.": "Luca: The bio-neural cores left here will not shut down at once... But we cannot guarantee how long they will last or what you will find outside.",
	"에드가: 귀하의 기상과 저희의 육체 복원은 별개의 절차입니다.": "Edgar: Your awakening and the restoration of our bodies are separate procedures.",
	"에드가: 이전의 강제 기동을 정당화하는 선택이 아닙니다. 남는다면 귀하가 알고 동의한 안정화 절차여야 합니다.": "Edgar: Staying would not justify the earlier forced activation. If you remain, it must be through a stabilization procedure you understand and accept.",
	"루카: 익숙한 아침이어도... 모르던 때로 돌아가는 건 아니에요.": "Luca: Even if the morning is familiar... it will not return you to when you did not know.",

	# E5 completed and incomplete servant inserts.
	"에드가: 강제 기동을 막지 않았고, 돌려드릴 권한을 붙잡았습니다. 관리였다는 말로 책임을 지우지 않겠습니다.": "Edgar: I failed to stop the forced activation and held on to authority that should have been returned. I will not erase that responsibility by calling it management.",
	"마라 1: 고친 손이 지운 손이기도 했슴다. 스패너만 닦는다고 없어지는 건 아니더라고요.": "Mara 1: The hand that fixed things was also the hand that erased them. Turns out cleaning the spanner doesn't make that disappear.",
	"루카: 위험을 말하지 않으면... 보호할 수 있을 줄 알았어요. 결정할 시간을 제가 가져간 건데...": "Luca: I thought I could protect you... by not telling you the risks. But I was taking away your time to decide...",
	"이리스: 우후후... 돌봐 주고 싶다는 말 안에, 제 바람도 섞여 있었네요. 오늘은 당신의 말부터 들을게요.": "Iris: Ohoho... My own wishes were mixed into saying I wanted to care for you. Tonight, I will listen to you first.",
	"마라 2: 남의 이름은 다 외워 놓고 내 이름만 자꾸 확인했어! ...지금은 한 번만 물어볼게. 기억해 줄 거지?": "Mara 2: I memorized everyone else's names, then kept checking only mine! ...I'll ask just once now. You'll remember me, right?",
	"에드가: 최소 접근 절차를 확인했습니다. 코어 경로까지 안내하겠습니다.": "Edgar: The minimum-access procedure is confirmed. I will guide you to the core route.",
	"마라 1: 배선은 버티고 있슴다. 저녁에 정전은 없을 겁니다! ...아마 같은 말은 안 붙일게요.": "Mara 1: The wiring is holding. There won't be a blackout during dinner! ...I won't add 'probably' this time.",
	"루카: 지금 생존 신호는... 유지되고 있어요. 외부 안전까지 뜻하는 건... 아니에요.": "Luca: Your vital signs are stable... for now. That does not mean the outside is safe...",
	"이리스: 환경 전력 로그는 확인할 수 있어요. 창밖의 계절로 바깥 안전을 판단하지는 말아요.": "Iris: The environmental power logs are available. Do not judge the outside's safety by the season beyond this window.",
	"익명 인덱스: 기록 채널 응답 정상. 사용 가능한 사건 인덱스를 제공합니다.": "Anonymous index: record channel responding normally. Available event indices are provided.",

	# E5 outcome overlays and private-result handling.
	"에드가가 감사 로그를 식탁에 둔다.": "Edgar places the audit log on the table.",
	"에드가가 비어 있는 SUBJECT 슬롯을 주인공 쪽으로 돌린다.": "Edgar turns the empty SUBJECT slot toward the Protagonist.",
	"마라 1의 기록에 모든 책임자 이름이 남아 있다.": "Every responsible name remains in Mara 1's record.",
	"마라 1의 기록에서 보호 대상 식별자는 가려져 있다.": "Protected identities are obscured in Mara 1's record.",
	"루카가 생존 신호 옆에 위험 수치도 나란히 놓는다.": "Luca places the risk readings beside the vital signs.",
	"루카가 안정화 완료 시각을 먼저 보여 준다. 위험 기록은 그 아래 남아 있다.": "Luca shows the stabilization time first. The risk record remains beneath it.",
	"이리스 앞의 계절 표시는 실제 외부 센서값이다.": "The seasonal display before Iris shows real external-sensor readings.",
	"이리스 앞의 투영 계절은 채도를 낮췄다. 투영이라는 표시는 지우지 않는다.": "The projected season before Iris is desaturated. Its projection label remains visible.",
	"마라 2의 한 목소리에 잠깐 낯선 억양이 섞인다.": "An unfamiliar accent briefly enters Mara 2's single voice.",
	"마라 2의 두 인덱스가 서로의 문장을 확인하며 교차 응답한다.": "Mara 2's two indices cross-respond while checking each other's sentences.",
	"이리스: 아까 둘이 나눈 말을, 여기서 다른 사람의 말로 바꾸지는 않을게요.": "Iris: I will not turn what we said in private into someone else's words here.",
	"이리스: 그때의 계절이 그리웠어요. 당신이 바라는 계절까지 같다고 생각해서는 안 됐겠죠.": "Iris: I missed the seasons from back then. I should not have assumed you wanted the same season.",
	"이리스는 환경 전력 로그를 접는다. 더 사적인 말은 덧붙이지 않는다.": "Iris folds the environmental power log and adds nothing more personal.",
	"마라 2: 에드가, 마라 1, 루카, 이리스... 그리고 나는?": "Mara 2: Edgar, Mara 1, Luca, Iris... and me?",
	"다섯 이름표의 문양은 경계를 유지한 채 한 식탁에 남는다. 누구도 다른 사람의 책임을 대신 용서하지 않는다.": "The five nameplate glyphs remain at one table while keeping their boundaries. No one forgives another person's responsibility for them.",

	# E5 feedback and observations.
	"일지와 최소 접근 절차를 먼저 확인한다.": "Review the journal and minimum-access procedure first.",
	"저녁의 결산은 이미 마쳤다.": "The final evening has already concluded.",
	"이미 저녁 자리에 도착했다.": "I have already arrived for the evening.",
	"중앙홀의 시계는 저녁인데 창밖은 아침의 같은 프레임이다.": "The central-hall clock says evening, but the window still holds the same morning frame.",
	"에드가: 저녁 준비가 되었습니다.": "Edgar: The evening preparations are complete.",
	"자리에 가셔도 괜찮겠습니까?": "May I show you to your seat?",
	"식당 문이 열린다. 긴 식탁의 절반은 목재, 절반은 생명 유지 프레임이다.": "The dining-room door opens. Half of the long table is wood; the other half is a life-support frame.",
	"루카: 음식은... 향과 온도, 식감 데이터예요. 오늘은... 숨기지 않을게요.": "Luca: The food is... scent, temperature, and texture data. Tonight... I won't hide that.",
	"식당에 먼저 들어간다.": "Enter the dining room first.",
	"목재와 금속이 맞닿은 경계에 손끝을 댄다. 따뜻한 접시 아래 프레임이 일정하게 진동한다. 배고픔을 달래는 감각과 바깥 몸의 생존은 같은 일이 아니다.": "I touch the boundary where wood meets metal. The frame beneath the warm plate vibrates steadily. Soothing hunger here is not the same as keeping my body outside alive.",
	"북쪽 정면은 내 자리. 왼쪽에는 이리스와 마라 2, 오른쪽에는 루카와 마라 1. 출입문 쪽 에드가의 자리에는 수직선이 있다. 사용인의 의자는 내 착석 지점이 아니다.": "The north-facing seat is mine. Iris and Mara 2 are to the left, Luca and Mara 1 to the right. A vertical line marks Edgar's seat by the door. A servant's chair is not my sitting point.",
	"홀로 돌아와 시계를 본다. 저녁을 가리키는 바늘 아래 아침빛이 멈춰 있다. 종료한 관계 사건을 다시 시작할 수는 없다.": "I return to the hall and look at the clock. Morning light is frozen beneath hands that point to evening. Closed relationship events cannot be restarted.",
	"식당의 주인공 자리로 돌아온다. 아무도 대답을 재촉하지 않는다.": "I return to the Protagonist's seat in the dining room. No one presses me for an answer.",
	"확인할 대상을 고른다.": "Choose something to inspect.",
	"식당의 자기 자리에서 시작한다.": "Begin from my own seat in the dining room.",
	"공동 질문은 하나만 고른다.": "Choose only one question for everyone.",
	"대화를 마친 뒤 준비 여부를 직접 확인한다.": "Finish the conversation, then confirm readiness directly.",
	"이 저녁의 말을 가지고 코어 접근 준비를 마친다. 아직 남을지 떠날지는 정하지 않았다.": "I carry the words from this evening into the core-approach preparations. I have not decided whether to stay or leave.",
	"정의되지 않은 저녁 행동이다.": "That evening action is not defined.",

	# E6 controller UI.
	"코어 접근 · 남은 후속 반응": "Core Approach · Remaining Follow-Ups",
	"마라 2가 자신의 이름을 확인해 달라고 한다.": "Mara 2 asks me to confirm her name.",
	"기록하거나 불러 주거나 장난으로 답할 수 있다.": "I can write it down, call her by it, or answer with a joke.",
	"수첩에 마라 2(가칭)를 적는다": "Write Mara 2 (Working Name) in the Notebook",
	"이름을 다시 불러 준다": "Call Her by Her Name Again",
	"장난으로 넘긴다": "Answer with a Joke",
	"열어 주세요.": "Please open it.",
	"명령이에요. 열어요.": "That is an order. Open it.",
	"아무 말 없이 기다린다": "Wait Without Speaking",
	"후속 대화 없이 접근로를 연다": "Open the Approach Without a Follow-Up Conversation",
	"코어 경로 진입 확인": "Confirm Entry to the Core Route",
	"남은 후속 반응은 선택 사항이다.": "The remaining follow-up conversations are optional.",
	"코어 문턱을 넘기 전까지 확인할 수 있다.": "They remain available until I cross the core threshold.",
	"북쪽 기록 회랑 · 마라 2 후속": "North Archive Hall · Mara 2 Follow-Up",
	"보안 기계실 · 다음 경로": "Security Machine Room · Next Route",
	"중앙홀로 돌아간다": "Return to the Central Hall",
	"코어 경로 진입": "Enter the Core Route",
	"진입하면 이전 공간으로 돌아갈 수 없고, 미확인 후속 반응은 종료됩니다. 완료한 관계와 저녁의 결산은 유지됩니다. 현실·잔류 선택은 아직 하지 않습니다.": "After entering, I cannot return to earlier rooms, and unseen follow-ups will close. Completed relationships and the final-evening record will remain. This is not yet the choice between reality and staying.",
	"아직 조사한다": "Keep Investigating",
	"문턱을 넘는다": "Cross the Threshold",

	# E6 feedback and conditional follow-ups.
	"저녁의 결산과 코어 접근 권한을 확인한다.": "Confirm the final-evening record and core-access authority.",
	"코어 경로에 진입했다. 이전 후속 반응은 종료되었다.": "The core route has been entered. Earlier follow-up conversations are closed.",
	"안내된 후속 장소를 선택한다.": "Choose one of the indicated follow-up locations.",
	"중앙홀의 안내선을 따라 이동한다. 종료한 관계 사건은 다시 시작되지 않는다.": "I follow the guide line through the central hall. Closed relationship events do not restart.",
	"기록 회랑의 미확인 이름 반응을 확인한다.": "Review the unseen name response in the archive hall.",
	"마라 2: 이번에도 네가 먼저 알아봤네!": "Mara 2: You recognized me first again!",
	"마라 2: 내 이름부터 확인해 봐! ...아니, 확인해 줄래?": "Mara 2: Check my name first! ...No, would you check it for me?",
	"시끄러운 웃음 속에서 자기 목소리의 경계를 찾는다.": "Inside her loud laughter, she searches for the boundary of her own voice.",
	"두 인덱스가 번갈아 자신을 가리킨다. 어느 쪽도 없는 이름이 되지 않으려 한다.": "The two indices take turns pointing to themselves. Neither wants to become a name belonging to neither.",
	"마라 2: 방금 거, 기록하지 않아도 돼. 대신 네가 기억해. 그게 더 오래 갈 수도 있잖아!": "Mara 2: You don't have to record that. Just remember it. That might last longer!",
	"마라 2(가칭)": "Mara 2 (working name)",
	"수첩에 '마라 2(가칭)'를 적는다. 빠른 세 음이 이번에는 끝까지 이어진다.": "I write 'Mara 2 (working name)' in the notebook. This time, the three quick tones play through to the end.",
	"주인공이 이름을 다시 부른다. 이중 윤곽이 잠깐 같은 속도로 맞물린다.": "The Protagonist calls her name again. The double outlines briefly interlock at the same speed.",
	"주인공이 장난으로 답한다. 마라 2는 짐짓 더 큰 소리로 웃는다.": "The Protagonist answers with a joke. Mara 2 makes a show of laughing even louder.",
	"문 앞의 마지막 점검을 확인한다.": "Review the final check at the door.",
	"에드가: 문은 열겠습니다. 다만, 제가 지키려던 것이 문인지 아가씨인지 아직도 확신하지 못하겠습니다.": "Edgar: I will open the door. I am still not certain whether I meant to guard the door or you.",
	"에드가: 가십시오. 이번에는 제가 뒤에서 따라가겠습니다.": "Edgar: Go ahead. This time, I will follow behind you.",
	"에드가: 최소 권한은 복구되었습니다. 그 이상은, 아가씨의 몫입니다.": "Edgar: Minimum authority has been restored. Anything beyond that belongs to you.",
	"에드가: 명령을 받들겠습니다. 제가 돌려드려야 할 책임입니다.": "Edgar: I will obey. It is a responsibility I must return to you.",
	"에드가: 외부 안전은 확인되지 않았습니다. 경고는 드리되, 권한은 막지 않겠습니다.": "Edgar: External safety remains unconfirmed. I will give you the warning, but I will not block your authority.",
	"열쇠 없이 잠금 해제음이 울린다. 수직선이 문틀에서 풀린다.": "An unlocking tone sounds without a key. The vertical line releases from the doorframe.",
	"보안 기계실의 코어 문에서 확인한다.": "Check at the core door in the security machine room.",
	"권한 프레임이 열린다. 마지막 대화를 하지 않아도 길은 열려 있다. 아직 문턱은 넘지 않았다.": "The authority frame opens. The route remains available without a final conversation. I have not crossed the threshold yet.",
	"열린 코어 경로의 일방향 진입을 확인한다.": "Confirm one-way entry into the open core route.",
	"문턱을 넘는다. 뒤의 복도는 끊어지고, 서로 다른 방의 조각이 앞에서 맞물린다. 아직 현실이나 잔류를 선택한 것은 아니다.": "I cross the threshold. The corridor behind me breaks away, and fragments of different rooms interlock ahead. I have not yet chosen reality or staying.",
	"정의되지 않은 코어 접근 행동이다.": "That core-approach action is not defined.",
}

const SCENE_OPENINGS_EN := {
	"주인공이 북쪽 정면석에 앉는다. 사용인들은 업무 위치에 서 있다. 식기 소리가 멎고 긴 침묵이 남는다.": "The Protagonist takes the north-facing seat. The servants remain at their work positions. The sound of tableware stops, leaving a long silence.",
	"주인공이 북쪽 정면석에 앉는다. 이야기를 나눈 사용인들은 앉고, 나머지는 서비스 경계에 선다. 가까워진 몇 사람의 선이 닿지만 하나로 섞이지 않는다.": "The Protagonist takes the north-facing seat. The servants she spoke with sit; the others remain at the service boundary. A few lines draw close and touch without merging.",
	"주인공이 북쪽 정면석에 앉는다. 네 사람이 앉는다. 남은 의자에도 원래 문양이 있다. 그 주인은 출입문 곁에서 이곳을 보고 있다.": "The Protagonist takes the north-facing seat. Four servants sit. The remaining chair still bears its original glyph; its owner watches from beside the doorway.",
	"주인공이 북쪽 정면석에 앉는다. 다섯 자리에 이름표가 놓였다. 주인공이 바라보자 마지막까지 서 있던 에드가도 앉는다.": "The Protagonist takes the north-facing seat. Nameplates rest at all five places. When she looks toward him, Edgar, the last one standing, sits as well.",
}

const J4_NAME_EN := {
	"대각선 · 마라 1": "Diagonal Line · Mara 1",
	"꽃잎 · 이리스": "Petal · Iris",
	"이중 맥박 · 루카": "Paired Pulse · Luca",
	"수직선 · 에드가": "Vertical Line · Edgar",
	"이중 액자 · 마라 2": "Double Frame · Mara 2",
}

const J4_SHORT_EN := {
	"약속": "Promise",
	"전환": "Conversion",
	"역할 고정": "Roles Fixed",
	"주인공 기동": "Protagonist Activated",
}

const LOCATION_ID_EN := {
	"M1_CENTRAL_HALL": "Central Hall",
	"M1_DINING_ROOM": "Dining Room",
	"M1_NORTH_ARCHIVE_HALL": "North Archive Hall",
	"H0_CLOCK_MACHINE": "Security Machine Room",
}

static func is_english(locale: String) -> bool:
	return locale.begins_with("en")


static func text(source: String, locale: String) -> String:
	if source.is_empty() or not is_english(locale):
		return source
	if TEXT_EN.has(source):
		return String(TEXT_EN[source])
	if SCENE_OPENINGS_EN.has(source):
		return String(SCENE_OPENINGS_EN[source])
	var translated := PackedStringArray()
	for line in source.split("\n", true):
		translated.append(_line(String(line)))
	return "\n".join(translated)


static func feedback(source: String, locale: String) -> String:
	return text(source, locale)


static func j4_confirmation(totals: Dictionary, locale: String) -> String:
	var remaining := String(totals.get("remaining_names", ""))
	if not is_english(locale):
		var time_text := "남은 선택 사건 없음" if remaining.is_empty() else "%d~%d분" % [totals["minutes_min"], totals["minutes_max"]]
		var body := "남은 사용인 사건은 이후 완료할 수 없습니다. 메인 진행과 두 최종 선택지는 유지됩니다.\n완료: %d / 5 · 연구원 기록: %d / 5\n미완료: %s\n남은 예상 시간: %s" % [totals["core_complete_ids"].size(), totals["researcher_record_count"], "없음" if remaining.is_empty() else remaining, time_text]
		if not totals["edgar_core_complete"]:
			body += "\n에드가 전체 사건은 최소 접근 절차로 대체됩니다. 최소 절차는 기록·관계·완료 수를 제공하지 않습니다."
		return body
	var english_names := PackedStringArray()
	if not remaining.is_empty():
		for name in remaining.split(", "):
			english_names.append(String(J4_NAME_EN.get(String(name), name)))
	var time_text := "No optional events remain" if remaining.is_empty() else "%d-%d min" % [totals["minutes_min"], totals["minutes_max"]]
	var body := "Any remaining servant events will become unavailable. Main progression and both final choices remain open.\nCompleted: %d / 5 · Researcher records: %d / 5\nIncomplete: %s\nEstimated time remaining: %s" % [totals["core_complete_ids"].size(), totals["researcher_record_count"], "None" if remaining.is_empty() else ", ".join(english_names), time_text]
	if not totals["edgar_core_complete"]:
		body += "\nEdgar's full event will be replaced by the minimum-access procedure. It grants no record, relationship reward, or completion count."
	return body


static func _line(source: String) -> String:
	if TEXT_EN.has(source):
		return String(TEXT_EN[source])
	if SCENE_OPENINGS_EN.has(source):
		return String(SCENE_OPENINGS_EN[source])
	for location_id in LOCATION_ID_EN:
		if source == location_id or source.begins_with(location_id + " · "):
			return source.replace(location_id, String(LOCATION_ID_EN[location_id]))
	if source.begins_with("현재 배열: "):
		var value := source.trim_prefix("현재 배열: ")
		if value == "없음":
			return "Current order: None"
		var parts := PackedStringArray()
		for part in value.split(" → "):
			parts.append(String(J4_SHORT_EN.get(String(part), part)))
		return "Current order: " + " -> ".join(parts)
	if source.ends_with(" · 획득한 기록 인덱스"):
		return source.trim_suffix(" · 획득한 기록 인덱스") + " · Acquired Record Index"
	if source.begins_with("주인공: "):
		return "Protagonist: " + String(TEXT_EN.get(source.trim_prefix("주인공: "), source.trim_prefix("주인공: ")))
	if source == "에드가: 저녁 준비가 되었습니다. 자리에 가셔도 괜찮겠습니까?":
		return "Edgar: The evening preparations are complete. May I show you to your seat?"
	return source
