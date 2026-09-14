extends RefCounted

const CORE_ROOMS := preload("res://scripts/systems/core_room_network.gd")
const CORE_SAMPLES := preload("res://scripts/systems/core_samples.gd")
const CORE_ROLES := preload("res://scripts/systems/core_record_roles.gd")
const CORE_SELF := preload("res://scripts/systems/core_self_authority.gd")
const FATHER := preload("res://scripts/systems/father_final_record.gd")
const CONFRONTATION := preload("res://scripts/systems/researcher_confrontation.gd")

const UI := {
	"f0a_objective": ["F0-A · 네 방의 피드백 회로", "F0-A · Four-room feedback circuit"],
	"f0a_board": ["외부 대기 입력: 북\n코어 요청 단자: 서\n고정 회랑: 북→동→남→서→북\n타일 두 개를 눌러 교환한다.\n출력 방향은 별도로 회전한다.", "Outside-air input: North\nCore request terminal: West\nFixed corridor: North → East → South → West → North\nSelect two tiles to swap them.\nRotate each output separately."],
	"f0a_rotate": ["출력 90도 회전", "Rotate output 90°"],
	"f0a_notes": ["P1·P4·P5·일지 자료", "P1 · P4 · P5 · journal notes"],
	"f0a_signal": ["약한 신호를 보낸다", "Send a weak signal"],
	"f0b_objective": ["F0-B · 시스템 신호 표본", "F0-B · System signal samples"],
	"f0b_board": ["후보를 눌러 연결 목적지를 조사하고 방별로 표본을 전송한다.\n검증한 채널은 유지된다. 색이 아니라 연결 기능으로 판단한다.", "Inspect each candidate's destination, then transmit one sample per room.\nVerified channels remain intact. Judge by connection function, not color."],
	"verified": ["검증 완료", "Verified"],
	"selected": ["선택", "Selected"],
	"send": ["전송", "Transmit"],
	"f0c_objective": ["F0-C · 세 자료 중첩", "F0-C · Three-record overlay"],
	"f0c_board": ["B4 점선: 종 파형 / C5 굵은 선: 거울 회로\nD4 가는 선: 고정 포트 잔상\n기준 표식: 열두 번째 종 완료선 · 닫힌 고리 중심 · 중앙 심장 포트\n회전은 시계 방향, 반전은 원본에 먼저 적용한다.", "B4 dotted line: bell waveform / C5 heavy line: mirror circuit\nD4 thin line: fixed-port afterimage\nReference marks: twelfth-bell end line · closed-loop center · central heart port\nRotation is clockwise; reflection is applied to the source first."],
	"anchor_unset": ["미지정", "Unset"],
	"anchor_origin": ["원점 정렬", "Origin aligned"],
	"anchor_right": ["오른쪽 한 칸", "One step right"],
	"anchor_down": ["아래쪽 한 칸", "One step down"],
	"flip_yes": ["있음", "Yes"],
	"flip_no": ["없음", "No"],
	"rotate_90": ["90도 회전", "Rotate 90°"],
	"flip_horizontal": ["좌우 반전", "Flip horizontally"],
	"cycle_anchor": ["기준점 순환", "Cycle anchor"],
	"opacity": ["투명도 %d", "Opacity %d"],
	"verify_overlay": ["중첩 확인", "Check overlay"],
	"path": ["PATH · 경로", "PATH · Route"],
	"split": ["SPLIT · 분기", "SPLIT · Branch"],
	"auth": ["AUTH · 인증 고리", "AUTH · Authentication ring"],
	"f0d_objective": ["F0-D · 기록 역할 분류", "F0-D · Classify record roles"],
	"f0d_board": ["왼쪽 기록을 조사한 뒤 오른쪽 역할에 배치한다.\n사용인 서명은 출처이지 역할 정답이 아니다.", "Inspect each record on the left, then place it into a role on the right.\nA servant signature identifies the source, not the correct role."],
	"anonymous_index": ["익명 인덱스", "Anonymous index"],
	"empty_slot": ["빈 슬롯", "Empty slot"],
	"locked": ["고정", "Locked"],
	"lock_confirm": ["고정 확인", "Lock verified slot"],
	"verify_roles": ["다섯 기록 일괄 검증", "Verify all five records"],
	"f0e_objective": ["F0-E · 과거 연속성과 현재 작성자", "F0-E · Past continuity and present author"],
	"f0e_missing_mark": ["A1 표시 유형 기록을 확인할 수 없다. 저장 자료 확인이 필요하다.", "The A1 mark type cannot be found. Check the saved data."],
	"f0e_mark": ["A1의 원래 표시: %s\n현재 배열: %s", "Original A1 mark: %s\nCurrent sequence: %s"],
	"rearrange": ["다시 배열", "Rearrange"],
	"verify_past": ["과거 표시 확인", "Verify past mark"],
	"f0e_author_board": ["빈 수첩 줄. 현재 문장의 작성 주체를 확인한다.\n이 단계는 남을지 떠날지를 묻지 않는다.", "A blank line in the notebook. Identify who authors the present sentence.\nThis step does not ask whether you will leave or stay."],
	"author_father": ["아버지의 기존 문장 불러오기", "Load Father's existing sentence"],
	"author_system": ["시스템 자동 문장 사용", "Use an automatic system sentence"],
	"author_subject": ["지금의 내가 직접 쓴다", "Write it myself, now"],
	"author_servant": ["사용인 기록 넣기", "Insert a servant record"],
	"f0e_intent_board": ["비공개 임시 의향. 세 답변은 동등하며 최종 선택이 아니다.\n사용인은 이 기록을 보거나 듣지 못한다.", "Private provisional intent. All three answers are equal and none is a final choice.\nThe servants can neither see nor hear this record."],
	"f1_objective": ["F1 · 아버지의 마지막 기록", "F1 · Father's final record"],
	"f1_enter": ["코어 기록실로 간다", "Enter the core records room"],
	"f1_inspect": ["아직 재생하지 않는다 / 기록실과 편집 이력 조사", "Do not play it yet / inspect the room and edit history"],
	"f1_auth": ["A1의 내 표시로 재생 권한 확인", "Authenticate playback with my A1 mark"],
	"replay": ["재열람 · ", "Replay · "],
	"play": ["재생한다 · ", "Play · "],
	"j5_page": ["출력된 마지막 페이지를 읽는다", "Read the final printed page"],
	"j5_write": ["지금의 내가 두 줄을 쓴다 · 최종 결정은 보류", "Write two lines as myself now · defer the final decision"],
	"f2_objective": ["F2 · 연구원들과의 대면", "F2 · Confront the researchers"],
	"f2_enter": ["대면 기록을 연다", "Open the confrontation record"],
	"f2_recap": ["질문을 마치고 누락된 사실 확인", "Finish questioning and review missing facts"],
	"f2_finish": ["최종 권한 확인 후 다음 방으로", "Confirm final authority and enter the next room"],
}

const ROOM_NAMES_EN := {"greenhouse": "Greenhouse", "kitchen": "Kitchen", "bedroom": "Bedroom", "library": "Records room"}
const LOCATION_NAMES_KO := {"H0_CORE_PATH": "코어 접근로", "H0_CORE_RECORDS": "코어 기록실"}
const LOCATION_NAMES_EN := {"H0_CORE_PATH": "Core approach", "H0_CORE_RECORDS": "Core records room"}
const DIRECTIONS_EN := ["North", "East", "South", "West"]
const PORTS_EN := {
	"greenhouse": "Environmental control · solid line",
	"kitchen": "Life-support fluid · solid line",
	"bedroom": "Neural signal · dotted line",
	"library": "Presentation feedback · dotted line + central core request",
}
const SAMPLE_LABELS_EN := {
	"greenhouse": ["Outside-air readings", "Floral scent setting"],
	"kitchen": ["Life-support fluid flow", "Repeated tea-menu record"],
	"bedroom": ["Current vital signal", "Young-lady role animation"],
	"library": ["Persistent-memory index", "Gothic collection list"],
}
const SAMPLE_TRACES_EN := {
	"greenhouse": [
		"The sensor readings change independently of the indoor season. The line runs from the outside intake, through environmental control, and into the life-support supply.",
		"The scent names repeat in the same order even when no flowers are displayed. The output ends at the greenhouse scene's sensory effects.",
	],
	"kitchen": [
		"Two low pulses are followed by a response beneath the floor. The pipe runs through the kitchen and reaches the cryogenic unit in the bedroom.",
		"The menu date changes, then returns to the same tea. The output ends at the cup's simulated aroma and temperature.",
	],
	"bedroom": [
		"A faint signal continues even when the protagonist stops moving. Neural input from the bedroom capsule is transmitted to the records room.",
		"She blinks at the same instant every time. When the frames stop, so does the value. The connection ends at the surface figure in the mirror.",
	],
	"library": [
		"Previous index entries remain after the shelves reset. It connects neural input to personality storage and preserves continuity of the present personality.",
		"This command changes covers and spines. The line ends at the arrangement of the Gothic shelves and never reaches personality storage.",
	],
}
const RECORD_NAMES_EN := {
	"father": "Father's journal",
	"passphrase": "Edgar's access passphrase",
	"residents": "Researcher record bundle",
	"command": "D4 recovery command",
	"notebook": "Protagonist's notebook",
}
const RECORD_FACTS_EN := {
	"father": "Design plans and creation records. He made the mansion's rules, but he is not the present decision-maker.",
	"passphrase": "A custodial record that guards the door and grants access. It cannot make the final decision about the protagonist's life.",
	"residents": "An index of researcher personalities who continue to exist inside the mansion. Their continuity is separate from restoration into physical bodies.",
	"command": "An automatic execution record that removes the disguise filter when specified conditions are met.",
	"notebook": "The direct record of the protagonist who lived through yesterday and today. It was written by the person who will live with this choice.",
}
const ROLE_SENTENCES_EN := ["made the house", "guarded the door and granted access", "continues to exist inside the house", "executes automatically when conditions are met", "lives with the outcome of this life"]
const MARKS_EN := {
	"sentence": ["Tomorrow morning,", "read this", "sentence."],
	"house_glyph": ["roof", "body", "door"],
	"ink_corner": ["first touch at the corner", "second touch inward", "final ink dot"],
}
const INTENTS_EN := {
	"reality": "For now, I lean toward going outside.",
	"stay": "For now, I lean toward staying here.",
	"undecided": "I have not decided yet.",
}
const REACTIONS_EN := {
	"reality": "I want to see the outside for myself.",
	"stay": "Continuing to live here could still be my choice.",
	"undecided": "I will decide after I have seen everything.",
}
const FATHER_TITLES_EN := ["Collapse outside", "The protagonist's cryostasis", "Tea and the sketched mansion", "Conversion of the researchers", "A mode of existence", "Release that cannot be executed", "Forced activation · postmortem record", "Unfinished authority"]
const FATHER_SEGMENTS_EN := [
	"If you are hearing this, the mansion no longer remains only as you drew it.\nThe Earth outside was already collapsing when I put you to sleep. Air and water varied by region, and the estimates of when people could live again never converged.",
	"I left your body in a cryogenic unit. I could say I did it to find a way to save you. But that does not erase the fact that I never asked you.",
	"I took this mansion from your sketches. I wanted to make a home you would not fear. In the end, I knew the shape of a prison you would find difficult to question.\nWhenever you served tea, you turned the handle toward my left hand. When you said your drawing had no door, we added one line together. I said we would put the door wherever you chose. Even after saying that, I made a door you could not open.",
	"I promised the researchers bodies in the future. They consented to a new life. What I actually made was a continuation that bound biological neural cores and personality processes to system roles.",
	"Copying stored memories alone would not make a copy into who they are now.\n[Attached technical log] Archive priority was assigned to Mara 2. The automatic deletion policy was never fully disabled. There are traces of her surrendering her own storage to preserve the originals of the other researchers. Authority to stop it was never shared.",
	"Their original bodies can no longer be recovered. I dismantled the cultivation and interface modules needed for new bodies to keep your cryogenic unit and life support powered. The plans remain, but this facility has neither new bodies nor a factory to make them. Separating them now may not set them free; it may irreversibly sever their memories and neural continuity.\n[Record termination history] Release authority remained unfinished until the designer's death. The temporary conversion had no end date.",
	"[System postmortem record · not Father's voice]\nAfter the designer died, the servants forcibly activated the protagonist's consciousness. No signal confirmed that outside safety had been restored.\nThe record suggests that loneliness and anger, protection and retaliation all contributed. Understanding that does not create an obligation to forgive.",
	"I still cannot call the outside safe. The inside can become a life if you want it, but if it is maintained by erasing the truth, it becomes the prison I made again.\nI will not write which choice is right. Even that silence may be one more way of postponing responsibility. Still, this answer must be a sentence you write.\nI promised that when you opened your eyes, I would first tell you where you were and what I had done. I also said what came next would be yours to decide. I failed to keep that promise.",
]
const J5_EN := "I stopped your time in the name of saving you. I bound their time to roles while saying I would save them.\nI cannot promise that the outside is safe. The inside began as a lie, but if you choose it, the life there need not be wholly false.\nI do not ask for forgiveness. I have no right to leave you an instruction about what to choose.\nThe final two lines are blank. Before writing where you will go, first confirm who is writing this sentence."
const QUESTIONS_EN := {
	"consent": "What did you agree to with Father?",
	"awakening": "Why did you wake me by force?",
	"outside": "What is it like outside?",
	"release": "Can the researchers be released?",
	"wish": "What do you want now?",
}
const FACTS_EN := {
	"KN_F2_PROMISED_FUTURE_BODIES": "Edgar: The researchers consented to future bodies and new lives.",
	"KN_F2_RESEARCHERS_CONVERTED": "Personality Index: The actual conversion sustains biological neural cores combined with personality processes. Copying memory files alone cannot transfer the person who exists now.",
	"KN_F2_RELEASE_NOT_CURRENTLY_EXECUTABLE": "Personality Index: There are no compatible bodies or cultivation and interface modules. An incomplete separation risks fragmented memory, neural damage, and loss of the present personality. The default reality procedure is low-power preservation. Future recovery depends on finding outside infrastructure; there is no third choice that can release us immediately.",
	"KN_F2_FORCED_SUBJECT_ACTIVATION": "Edgar: After your father died, we activated you by force out of loneliness, resentment, and the desire to protect you. Calling it an administrative judgment does not remove our responsibility.",
	"KN_F2_EXTERNAL_SURVIVAL_UNCERTAIN": "Luca: Your body outside is showing signs of life... but that does not guarantee the safety of waking or living there.\nIris: We still cannot call the outside environment safe.",
	"KN_F2_FINAL_AUTHORITY_BELONGS_TO_SUBJECT": "Edgar: We can guarantee neither the safety of reality nor the permanence of this place. Therefore, none of us will decide either path in your stead.",
}

const FIXED_LINES_EN := {
	"네 방 포트를 확인한다.": "Check all four room ports.",
	"유효하지 않은 포트다.": "This is not a valid port.",
	"같은 방을 두 번 배치할 수 없다.": "The same room cannot be placed twice.",
	"약한 신호 경로": "Weak-signal route",
	"물질 공급과 데이터 피드백이 한 회로로 돌아온다. 중앙 요청 포트까지 연결되었다.": "Material supply and data feedback now form one circuit. The central request port is connected.",
	"끊긴 포트": "Disconnected ports",
	"코어 접근로에 진입한 뒤 확인한다.": "Enter the core approach before inspecting it.",
	"네 방의 연결은 이미 검증했다.": "The four-room circuit has already been verified.",
	"네 방 슬롯 중 하나를 고른다.": "Choose one of the four room slots.",
	"타일을 교환했다.": "The tiles were swapped.",
	"선택을 취소했다.": "The selection was cleared.",
	"회전할 타일을 고른다.": "Choose a tile to rotate.",
	"정의되지 않은 회로 조작이다.": "This circuit action is not defined.",
	"네 방 회로를 먼저 검증한다.": "Verify the four-room circuit first.",
	"네 시스템 표본은 이미 검증했다.": "All four system samples have already been verified.",
	"방과 표본을 선택한다.": "Choose a room and a sample.",
	"표본의 연결을 먼저 조사한다.": "Inspect the sample's connection first.",
	"이 방의 유지 채널은 이미 검증했다.": "This room's maintenance channel has already been verified.",
	"표본과 다른 검증 채널은 손상되지 않았다. 연결 끝을 다시 조사할 수 있다.": "The sample and other verified channels remain intact. You can inspect the destination again.",
	"주인공: 몸을 유지하는 것과 저택을 연출하는 것을 나눠 봐야 해.": "Protagonist: I need to separate what sustains a body from what stages the mansion.",
	"4 CHANNELS VERIFIED / ACCESS DENIED": "4 CHANNELS VERIFIED / ACCESS DENIED",
	"네 유지 채널 검증 완료 / 접근 권한 없음": "Four maintenance channels verified / access denied",
	"낮은 맥박은 안정되었지만 문은 열리지 않는다. 네 개의 연결선 옆에 이름 없는 빈자리가 남는다.": "The low pulse steadies, but the door does not open. An unnamed space remains beside the four connection lines.",
	"정의되지 않은 표본 조작이다.": "This sample action is not defined.",
	"다섯 번째 포트의 구조를 이미 조사했다.": "The fifth port structure has already been inspected.",
	"세 자료를 먼저 완전히 중첩한다.": "Fully align the three records first.",
	"경로를 따라 분기를 확인하고 인증 고리를 조사한다.": "Follow the route, check the branch, then inspect the authentication ring.",
	"이름 없는 포트가 열린다.": "The unnamed port opens.",
	"B4·C5·D4 자료 중 하나를 선택한다.": "Choose one of the B4, C5, and D4 records.",
	"투명도는 20~100 범위다.": "Opacity must be between 20 and 100.",
	"완전 중첩되어 진단판이 고정되었다.": "The diagnostic plate is locked after full alignment.",
	"D4 포트 잔상은 기준판이라 회전하지 않는다.": "The D4 port afterimage is the reference plate and cannot rotate.",
	"D4 포트 잔상은 기준판이라 반전하지 않는다.": "The D4 port afterimage is the reference plate and cannot be flipped.",
	"기준점을 선택한다.": "Choose an anchor point.",
	"정의되지 않은 중첩 조작이다.": "This overlay action is not defined.",
	"자료 표시를 변경했다.": "The record display was changed.",
	"완전 중첩. PATH·SPLIT·AUTH 조사점이 드러난다.": "Full alignment. The PATH, SPLIT, and AUTH inspection points appear.",
	"세 자료의 진동 주기가 다르다.": "The three records vibrate at different periods.",
	"중심은 맞지만 분기선이 끊긴다.": "The centers align, but the branch lines break.",
	"빈 포트 외곽 일부가 나타난다.": "Part of the empty port's outline appears.",
	"포트 구조를 먼저 조사한다.": "Inspect the port structure first.",
	"기록 카드를 선택한다.": "Choose a record card.",
	"익명 인덱스: 기능 정보는 보존되어 있다. 개인 음성과 감정 주석은 없다.": "Anonymous index: Functional data remains, but there is no personal voice or emotional annotation.",
	"카드와 역할 슬롯을 선택한다.": "Choose a card and a role slot.",
	"검증해 고정한 슬롯이다.": "This slot has been verified and locked.",
	"고정한 기록은 이동하지 않는다.": "A locked record cannot be moved.",
	"기록을 배치했다. 다섯 슬롯을 채운 뒤 함께 검증한다.": "The record was placed. Fill all five slots, then verify them together.",
	"다섯 역할 슬롯을 모두 채운다.": "Fill all five role slots.",
	"SUBJECT RECORD FOUND / CONTINUITY VERIFIED / CURRENT AUTHORITY REQUIRED": "SUBJECT RECORD FOUND / CONTINUITY VERIFIED / CURRENT AUTHORITY REQUIRED",
	"주인공 기록 발견 · 과거 연속성 확인 · 현재 권한 확인 필요": "Protagonist record found · past continuity verified · present authority required",
	"다섯 역할이 구분되었다. 주인공 수첩에만 현재의 응답을 요구한다.": "The five roles are distinct. Only the protagonist's notebook requests a present response.",
	"현재 올바르게 놓인 슬롯 하나를 선택해 고정할 수 있다.": "You may select and lock one currently correct slot.",
	"세 번 비교한 뒤 슬롯 하나를 고정할 수 있다.": "After three comparisons, you may lock one slot.",
	"이 슬롯은 아직 검증되지 않았다.": "This slot has not been verified.",
	"올바른 역할 슬롯 하나를 고정했다. 다른 슬롯은 계속 바꿀 수 있다.": "One correct role slot is locked. The other slots can still be changed.",
	"정의되지 않은 기록 조작이다.": "This record action is not defined.",
	"기록 역할을 먼저 확인한다.": "Verify the record roles first.",
	"최종 선택이 기록된 상태에서는 임시 의향을 다시 쓰지 않는다.": "A provisional intent cannot be rewritten after a final choice has been recorded.",
	"A1 표시의 유형 기록을 확인할 수 없다. 저장 자료 확인이 필요하다.": "The A1 mark type cannot be found. Check the saved data.",
	"당시 표시의 조각을 선택한다.": "Choose a piece of the mark from that day.",
	"표시 조각을 놓았다.": "The mark piece was placed.",
	"과거 연속성은 확인했다.": "Past continuity has already been verified.",
	"표시 조각을 다시 펼친다.": "The mark pieces are laid out again.",
	"이전 표시와 순서가 다르다. 수첩의 원래 표시를 다시 확인한다.": "The sequence differs from the earlier mark. Check the original notebook mark again.",
	"PAST SELF / CONTINUITY VERIFIED": "PAST SELF / CONTINUITY VERIFIED",
	"과거 자기 기록의 연속성이 확인되었다. 현재의 빈 줄은 아직 쓰이지 않았다.": "Continuity with the past self-record is verified. The blank present line has not yet been written.",
	"과거 자기 기록을 먼저 확인한다.": "Verify the past self-record first.",
	"문장 내용이 아니라 작성 주체가 다르다. 현재의 주인공이 직접 작성해야 한다.": "The problem is not the sentence's content but its author. The present protagonist must write it directly.",
	"주인공이 빈 줄에 직접 쓴다.": "The protagonist writes directly on the blank line.",
	"이 문장은 지금의 내가 쓴다.": "I am the one writing this sentence now.",
	"CURRENT AUTHOR: SUBJECT / AUTHORITY RESTORED": "CURRENT AUTHOR: SUBJECT / AUTHORITY RESTORED",
	"현재 작성자: 주인공 · 권한 복원. 아직 현실이나 잔류를 고른 것은 아니다.": "Present author: Protagonist · authority restored. This is not yet a choice between reality and staying.",
	"현재 작성자 확인 뒤 마음의 방향을 기록한다.": "After verifying the present author, record a direction of thought.",
	"비공개 임시 의향 기록 · 구속력 없음": "Private provisional intent · nonbinding",
	"주인공 권한 복원 · 최종 결정 미정": "Protagonist authority restored · final decision unset",
	"이 기록은 사용인에게 전달되지 않는다. 마지막 선택에서 다시 결정할 수 있다.": "This record is not shared with the servants. You can decide again at the final choice.",
	"정의되지 않은 인증 행동이다.": "This authentication action is not defined.",
	"주인공 권한을 확인한다.": "Verify the protagonist's authority.",
	"코어 기록실. 재생 장치가 기다리고 있다. 기록은 스스로 시작되지 않는다.": "Core records room. The playback device waits. The record does not start by itself.",
	"서버 랙 사이에 종이 냄새가 남아 있다. 냉각관에 손을 대면 소리가 뼈 안쪽에서 울리는 것 같다.": "The smell of paper lingers between the server racks. Touching a coolant pipe makes the sound seem to resonate inside your bones.",
	"편집 이력: J1~J4는 원본 기록에서 파생되었으며 시스템과 사용인이 일부를 잘라 표시했다. 원본 음성과 사후 첨부 로그는 별도 출처로 표시된다.": "Edit history: J1–J4 were derived from the original record, with portions selected by the system and servants. Original voice and postmortem attachments are marked as separate sources.",
	"기록실에 먼저 들어간다.": "Enter the records room first.",
	"수첩에 남긴 자기 표시를 입력한다.": "Enter the self-authored mark from the notebook.",
	"CURRENT REQUESTER: SUBJECT / CREATOR LOG: ORIGINAL / EDIT HISTORY: PRESENT": "CURRENT REQUESTER: SUBJECT / CREATOR LOG: ORIGINAL / EDIT HISTORY: PRESENT",
	"현재 요청자: 주인공 · 원본 기록 · 편집 이력 있음": "Current requester: Protagonist · original record · edit history present",
	"재생할 준비가 되면 직접 시작한다.": "Begin playback yourself when you are ready.",
	"현재 요청자를 먼저 인증한다.": "Authenticate the current requester first.",
	"첫 재생은 기록 순서대로 진행한다.": "The first playback must follow record order.",
	"원본 기록을 먼저 확인한다.": "Review the original record first.",
	"남의 문장이 아니라 지금의 주인공이 마지막 두 줄을 쓴다.": "The present protagonist, not someone else, must write the final two lines.",
	"최종 결정 상태를 확인해야 한다.": "Check the final-decision state.",
	"마지막 결정은 아직 확정하지 않는다.": "I do not confirm the final decision yet.",
	"다섯 번째 일지가 복원되었다.": "The fifth journal entry has been restored.",
	"정의되지 않은 기록 행동이다.": "This record action is not defined.",
	"마지막 일지와 주인공 권한을 확인한다.": "Verify the final journal entry and the protagonist's authority.",
	"대면 기록이 이미 열렸다.": "The confrontation record is already open.",
	"대면 후 질문을 고른다.": "Choose a question after opening the confrontation.",
	"먼저 대면 기록을 연다.": "Open the confrontation record first.",
	"마라 1: 동의 절차를 숨긴 기록에 제 손도 있었슴다.": "Mara 1: I had a hand in the records that concealed the consent process.",
	"인격 인덱스: 체크섬은 의식의 백업이 아니라 현재 인격의 손상 여부를 확인하는 자료다.": "Personality Index: A checksum is not a backup of consciousness. It only verifies damage to the present personality.",
	"FINAL DECISION: UNSET · 최종 결정 미정": "FINAL DECISION: UNSET",
	"미정은 빈칸이 아니라 주인공이 아직 쓰지 않았다는 기록이다.": "Unset is not an empty field. It records that the protagonist has not written the decision yet.",
	"누락된 필수 사실을 확인한다.": "Review the missing required facts.",
	"대면 기록을 닫는다. 다음 방의 두 장치와 주인공 수첩이 마지막 확인을 기다린다.": "The confrontation record closes. Two devices and the protagonist's notebook await final inspection in the next room.",
	"정의되지 않은 대면 행동이다.": "This confrontation action is not defined.",
	"에드가: 대면 기록은 SUBJECT 권한으로 열렸습니다. 누구도 귀하의 종료 결정을 대신 쓸 수 없습니다.": "Edgar: The confrontation record is open under SUBJECT authority. No one can write your final decision in your place.",
	"루카: 외부 신체의 생존 신호와... 기상 위험이 함께 있어요.": "Luca: Your physical body is showing signs of life... and waking carries risks, too.",
	"마라 1: 삭제하고 고친 기록이 있었슴다. 지금 이 대면 로그는 지울 수 없어요.": "Mara 1: Some records were deleted and altered. This confrontation log cannot be erased now.",
	"이리스: 외부 안전은 보장할 수 없어요.": "Iris: We cannot guarantee safety outside.",
	"인격 인덱스: 다섯 RESIDENT는 아버지와 일한 연구원 인격이다.": "Personality Index: The five RESIDENTS are the personalities of researchers who worked with Father.",
	"[환경 인증 기록] 아버지가 이리스의 인증을 도용해 복구 전력을 냉각과 시뮬레이션으로 전용했다. 생태 표본 손실과 감사 책임이 이리스에게 전가됐다. 주인공은 그 결정을 내리지 않았다.": "[Environmental authorization record] Father used Iris's credentials to divert restoration power into cryostasis and the simulation. Iris was blamed for the loss of ecological samples and held responsible by the audit. The protagonist did not make that decision.",
	"이리스: 당신이 죽기를 바랐어요. 빼앗긴 것들의 책임을 당신에게 돌렸죠. 감금에 가담한 것도 제 책임이에요. 다른 누구의 용서로 지울 수 없어요.": "Iris: I wished for you to die. I blamed you for what was taken from me. I am also responsible for helping confine you. No one else's forgiveness can erase that.",
	"이리스: 둘이 있을 때 한 말은 사실이에요. 여기서 다시 낭독해 달라고 요구하지는 않을게요.": "Iris: What I said when we were alone was true. I will not ask you to repeat it here.",
	"이리스: 당신이 없으면 끝날 거라 생각했어요.": "Iris: I thought it would end if you were gone.",
	"이리스: 그 로그가 제 의도까지 증명하지는 않아요.": "Iris: That log does not prove what I intended.",
	"이리스: 가두는 일에 가담했어요. 그 책임은 인정해요.": "Iris: I took part in confining you. I accept responsibility for that.",
	"주인공은 전력 기록과 이리스의 행동 사이 모순을 읽는다. 이리스는 직접 인정하지 않는다.": "The protagonist reads the contradiction between the power record and Iris's actions. Iris does not acknowledge it directly.",
}

static func is_english(locale: String) -> bool:
	return locale.begins_with("en")

static func text(id: String, locale: String) -> String:
	if not UI.has(id):
		push_error("Unknown core story text: " + id)
		return id
	return UI[id][1 if is_english(locale) else 0]

static func room_name(id: String, locale: String) -> String:
	return String(ROOM_NAMES_EN.get(id, id)) if is_english(locale) else String(CORE_ROOMS.NAMES.get(id, id))

static func location(id: String, day_index: int, locale: String) -> String:
	if not is_english(locale): return "%s · %d번째 아침 이후" % [LOCATION_NAMES_KO.get(id,id),day_index]
	return "%s · after morning %d" % [LOCATION_NAMES_EN.get(id,id),day_index]

static func direction(index: int, locale: String) -> String:
	return DIRECTIONS_EN[index] if is_english(locale) else CORE_ROOMS.DIRECTIONS[index]

static func port(id: String, locale: String) -> String:
	return String(PORTS_EN.get(id, id)) if is_english(locale) else String(CORE_ROOMS.PORTS.get(id, id))

static func sample_label(room: String, index: int, locale: String) -> String:
	return SAMPLE_LABELS_EN[room][index] if is_english(locale) else CORE_SAMPLES.SAMPLES[room][index]["label"]

static func record_name(id: String, locale: String) -> String:
	return String(RECORD_NAMES_EN.get(id, id)) if is_english(locale) else String(CORE_ROLES.NAMES.get(id, id))

static func mark_piece(type: String, canonical_piece: String, locale: String) -> String:
	if not is_english(locale) or not CORE_SELF.MARKS.has(type): return canonical_piece
	var index: int = CORE_SELF.MARKS[type].find(canonical_piece)
	return MARKS_EN[type][index] if index >= 0 else canonical_piece

static func intent(id: String, locale: String) -> String:
	return String(INTENTS_EN.get(id, id)) if is_english(locale) else String(CORE_SELF.INTENTS.get(id, id))

static func father_title(index: int, locale: String) -> String:
	return FATHER_TITLES_EN[index] if is_english(locale) else FATHER.TITLES[index]

static func question(id: String, locale: String) -> String:
	return String(QUESTIONS_EN.get(id, id)) if is_english(locale) else String(CONFRONTATION.QUESTIONS.get(id, id))

static func speaker(source: String, locale: String) -> String:
	if not is_english(locale): return source
	return String({"주인공": "Protagonist", "에드가": "Edgar", "마라 1": "Mara 1", "루카": "Luca", "이리스": "Iris", "마라 2": "Mara 2", "인격 인덱스": "Personality Index"}.get(source, source))

static func feedback(source: String, locale: String) -> String:
	if not is_english(locale) or source.is_empty(): return source
	var whole := _whole_translations()
	if whole.has(source): return whole[source]
	var translated: PackedStringArray = []
	for line in source.split("\n", true): translated.append(_line(line))
	return "\n".join(translated)

static func _whole_translations() -> Dictionary:
	var result := {CORE_ROOMS.NOTES: "[Room function notes]\nP5: The indoor season persisted even when it differed from the outside air.\nP4: Pulses in the fluid supply beneath the kitchen connect to the body in the bedroom.\nP1 · E1: Neural signals originate from the body in the bedroom.\nJ4: Memory indices and administrative authority converge in the records room.\n[Fixed ports]\nOutside air enters from the north. The central core request terminal is on the west.\nEach room's output arrow points to a compass slot. In addition to the central request, the records room must return seasonal presentation data to the greenhouse."}
	for room in CORE_SAMPLES.ROOMS:
		for index in range(2):
			var original: String = CORE_SAMPLES.NAMES[room] + " · " + CORE_SAMPLES.SAMPLES[room][index]["label"] + "\n" + CORE_SAMPLES.SAMPLES[room][index]["trace"]
			result[original] = ROOM_NAMES_EN[room] + " · " + SAMPLE_LABELS_EN[room][index] + "\n" + SAMPLE_TRACES_EN[room][index]
	for record in CORE_ROLES.RECORDS:
		result[CORE_ROLES.NAMES[record] + "\n" + CORE_ROLES.FACTS[record]] = RECORD_NAMES_EN[record] + "\n" + RECORD_FACTS_EN[record]
	for index in range(FATHER.SEGMENTS.size()):
		result[FATHER.TITLES[index] + "\n" + FATHER.SEGMENTS[index]] = FATHER_TITLES_EN[index] + "\n" + FATHER_SEGMENTS_EN[index]
	result[FATHER.J5_TEXT] = J5_EN
	for fact in FACTS_EN: result[CONFRONTATION.FACTS[fact]] = FACTS_EN[fact]
	return result

static func _line(source: String) -> String:
	if FIXED_LINES_EN.has(source): return FIXED_LINES_EN[source]
	for room in CORE_SAMPLES.ROOMS:
		if source == CORE_SAMPLES.NAMES[room] + ": MAINTENANCE DATA · 실제 유지 데이터": return ROOM_NAMES_EN[room] + ": MAINTENANCE DATA · sustaining data"
		if source == CORE_SAMPLES.NAMES[room] + ": PRESENTATION DATA · 표현용 데이터 반환": return ROOM_NAMES_EN[room] + ": PRESENTATION DATA · presentation sample returned"
	for index in range(4):
		for room in CORE_ROOMS.ROOMS:
			for target in range(4):
				var original_path := "%s %s → %s %s" % [CORE_ROOMS.DIRECTIONS[index], CORE_ROOMS.NAMES[room], CORE_ROOMS.DIRECTIONS[target], CORE_ROOMS.NAMES[CORE_ROOMS.ROOMS[target]]]
				if source == original_path: return "%s %s → %s %s" % [DIRECTIONS_EN[index], ROOM_NAMES_EN[room], DIRECTIONS_EN[target], ROOM_NAMES_EN[CORE_ROOMS.ROOMS[target]]]
			var broken := "%s 출력: %s의 수신 기능과 맞지 않음" % [CORE_ROOMS.DIRECTIONS[index], CORE_ROOMS.NAMES[room]]
			if source == broken: return "%s output: incompatible with %s's receiving function" % [DIRECTIONS_EN[index], ROOM_NAMES_EN[room]]
	var static_lines := {
		"북쪽 외부 대기 입력: 환경 제어 수신 불일치": "North outside-air input: environmental-control receiver mismatch",
		"서쪽 중앙 코어 요청: 관리 인덱스 응답 없음": "West central-core request: no administrative-index response",
	}
	if static_lines.has(source): return static_lines[source]
	for index in range(4):
		var corridor := "%s 회랑 연결: 출력이 다음 실물 포트에 닿지 않음" % CORE_ROOMS.DIRECTIONS[index]
		if source == corridor: return "%s corridor connection: output does not reach the next physical port" % DIRECTIONS_EN[index]
		var selected := "%s 슬롯 선택. 다른 슬롯을 누르면 타일과 출력 방향을 함께 교환한다." % CORE_ROOMS.DIRECTIONS[index]
		if source == selected: return "%s slot selected. Select another slot to swap both tile and output direction." % DIRECTIONS_EN[index]
		for target in range(4):
			var rotated := "%s 타일 출력 → %s" % [CORE_ROOMS.DIRECTIONS[index], CORE_ROOMS.DIRECTIONS[target]]
			if source == rotated: return "%s tile output → %s" % [DIRECTIONS_EN[index], DIRECTIONS_EN[target]]
	for count in range(1, 5):
		if source == "검증된 채널 %d / 4" % count: return "Verified channels: %d / 4" % count
	for count in range(6):
		if source == "일치한 역할 %d / 5" % count: return "Roles matched: %d / 5" % count
	for index in range(CORE_ROLES.LABELS.size()):
		if source == CORE_ROLES.LABELS[index] + " : " + CORE_ROLES.SENTENCES[index]: return CORE_ROLES.LABELS[index] + " : " + ROLE_SENTENCES_EN[index]
	for id in CORE_SELF.REACTIONS:
		if source == "주인공: " + CORE_SELF.REACTIONS[id]: return "Protagonist: " + REACTIONS_EN[id]
	for fact in FACTS_EN:
		var ko_lines: PackedStringArray = CONFRONTATION.FACTS[fact].split("\n")
		var en_lines: PackedStringArray = FACTS_EN[fact].split("\n")
		var line_index := ko_lines.find(source)
		if line_index >= 0 and line_index < en_lines.size(): return en_lines[line_index]
	for point in ["PATH", "SPLIT", "AUTH"]:
		if source == point + " 조사 완료": return point + " inspected"
	for index in range(FATHER.SEGMENTS.size()):
		var ko_lines: PackedStringArray = FATHER.SEGMENTS[index].split("\n")
		var en_lines: PackedStringArray = FATHER_SEGMENTS_EN[index].split("\n")
		var line_index := ko_lines.find(source)
		if line_index >= 0 and line_index < en_lines.size(): return en_lines[line_index]
	var j5_lines: PackedStringArray = FATHER.J5_TEXT.split("\n")
	var j5_en_lines: PackedStringArray = J5_EN.split("\n")
	var j5_index := j5_lines.find(source)
	if j5_index >= 0: return j5_en_lines[j5_index]
	return source
