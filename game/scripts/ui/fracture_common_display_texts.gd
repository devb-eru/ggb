extends RefCounted

const UI := {
	"e1_location": ["같은 침실의 다른 아침", "The Same Bedroom, a Different Morning"],
	"e1_objective": ["서로 다른 세 곳을 확인한다", "Inspect three different places"],
	"e1_objective_done": ["문이 열렸다. 남은 조사도 할 수 있다", "The door is open. I can still finish investigating"],
	"e1_bed": ["천 아래의 침대", "Bed Beneath the Fabric"],
	"e1_window": ["그림자 없는 창문", "Window Without a Shadow"],
	"e1_mirror": ["늦게 숨 쉬는 거울", "Mirror That Breathes Late"],
	"e1_call_cord": ["응답 없는 호출끈", "Unanswered Call Cord"],
	"checked": ["확인함", "Inspected"],
	"e1_exit": ["침실 문을 연다", "Open the Bedroom Door"],
	"luca_guide_objective": ["주방의 이중 맥박 표식을 확인한다", "Follow the paired-pulse mark toward the kitchen"],
	"luca_guide_board": ["중앙홀은 잠깐 비어 있다.\n연두 보조등과 이중 맥박 문양이 주방 쪽을 가리킨다.", "The central hall is empty for a moment.\nA secondary indicator and paired-pulse glyph point toward the kitchen."],
	"luca_guide_action": ["사용인 통로를 지나 주방으로", "Take the Servants' Passage to the Kitchen"],
	"e1_return": ["침실의 남은 조사", "Finish Investigating the Bedroom"],
	"luca_s2_objective": ["루카의 차가운 손", "Luca's Cold Hand"],
	"luca_s2_board": ["조리대 아래 낮은 경고음이 손목 맥박과 맞물린다.\n루카는 손을 숨긴다. 가까이 다가가자 피부가 아니라 냉각관 같은 한기가 닿는다.", "A low warning beneath the counter interlocks with the pulse in my wrist.\nLuca hides her hand. When I step closer, the cold feels less like skin than a cooling pipe."],
	"luca_s2_ask": ["무슨 소리예요?", "What is that sound?"],
	"luca_s2_hold": ["손을 잡는다", "Take Her Hand"],
	"luca_s2_withdraw": ["물러난다", "Step Back"],
	"e2_objective": ["다섯 사용인의 보고와 합의", "The Five Servants' Report and Agreement"],
	"e2_report": ["에드가의 보고를 듣는다", "Hear Edgar's Report"],
	"e2_question_house": ["저택은 어떻게 된 거예요?", "What happened to the mansion?"],
	"e2_question_body": ["제 몸은 괜찮아요?", "Is my body all right?"],
	"e2_question_memory": ["왜 모두 기억하고 있어요?", "Why do all of you remember?"],
	"e2_finish": ["목적지와 핵심 보고를 정리한다", "Review the Destinations and Key Findings"],
	"hub_finish": ["조사를 마치고 기록 정리", "End the Investigation and Organize the Records"],
	"hub_objective": ["사용인을 찾아가거나 지금까지의 기록을 정리한다", "Visit a servant or organize the records gathered so far"],
	"hub_board": ["마라 1은 배선실로 향했다.\n이리스는 온실에서 기다리고 있다.\n루카는 주방 아래의 장치를 살피고 있다.\n에드가는 대시계 쪽에 있다.\n마라 2는 북쪽 기록 회랑으로 돌아갔다.\n누구를 먼저 찾아갈지, 조사를 언제 마칠지는 내가 정한다.", "Mara 1 has gone to the wiring room.\nIris is waiting in the greenhouse.\nLuca is inspecting a mechanism below the kitchen.\nEdgar is by the great clock.\nMara 2 has returned to the north archive hall.\nI decide whom to visit first and when to end the investigation."],
	"hub_mara1": ["마라 1 · 배선실로", "Mara 1 · To the Wiring Room"],
	"hub_iris": ["이리스 · 온실로", "Iris · To the Greenhouse"],
	"hub_luca": ["루카 · 생명 유지실로", "Luca · To Life Support"],
	"hub_edgar": ["에드가 · 대시계로", "Edgar · To the Great Clock"],
	"hub_mara2": ["마라 2 · 북쪽 기록 회랑", "Mara 2 · North Archive Hall"],
}

const FEEDBACK_EN := {
	"먼저 달라진 아침을 확인한다.": "Inspect the changed morning first.",
	"루카와의 첫 만남은 이미 지나갔다.": "The first meeting with Luca has already passed.",
	"괜찮아요... 아직은요. 이 소리가 빨라지면, 제가 먼저 말할게요. 그건... 꼭 말할게요.": "I'm all right... for now. If that sound gets faster, I'll tell you first. I... promise I will.",
	"손을 잡거나 물러날 수 있다.": "I can take her hand or step back.",
	"따뜻한 쪽이 어느 쪽인지 헷갈렸어요... 같이 돌아가요.": "I couldn't tell which side was warm... Let's go back together.",
	"괜찮아요... 천천히 오세요. 같이 돌아가요.": "It's all right... Take your time. Let's go back together.",
	"중앙홀의 보고를 먼저 확인한다.": "Hear the report in the central hall first.",
	"보고드리겠습니다. 정상 리셋 복구가 불가능합니다.\n마라 1의 웃음이 두 번 재생되고 멎는다. 루카는 손목과 진단 신호를 번갈아 본다. 이리스의 미소 아래 플라스틱 날개가 닫힌다.\n마라 2가 겹친 이름표를 붙든다. '너무 오래 쓴 표지야! 이제 안쪽 기능실이 보이는 거지.'": "I will report. Restoring the normal reset is impossible.\nMara 1's laugh plays twice and stops. Luca looks between my wrist and the diagnostic signal. Iris's plastic wings close beneath her smile.\nMara 2 grips the overlapping nameplate. 'That cover was up for way too long! Now we can see the function rooms underneath.'",
	"에드가의 보고를 먼저 듣는다.": "Hear Edgar's report first.",
	"위장 필터는 돌아오지 않습니다. 외부 신체의 생존 신호는 있으나 기상의 안전을 보장하지 못합니다. 저희 기억은 물리 리셋 대상이 아니었습니다.\n각 장치를 조사할지, 바로 기록 결산으로 갈지는 귀하가 결정합니다. 더는 그 선택을 잠그지 않겠습니다.": "The camouflage filter will not return. Your external body still shows vital signs, but we cannot guarantee that waking is safe. Our memories were never subject to the physical reset.\nYou will decide whether to inspect each mechanism or proceed directly to the record review. We will not lock that choice again.",
	"확인할 질문을 선택한다.": "Select a question to ask.",
	"침실에서 확인할 수 있는 대상이 아니다.": "That is not something I can inspect in the bedroom.",
	"천은 부드럽다. 그 아래가 무엇인지는 이제 안다.": "The fabric is soft. Now I know what lies beneath it.",
	"침실 문 걸쇠가 풀린다. 잠들었는데도, 돌아오지 않았다.": "The bedroom door latch releases. I slept, but the world did not return.",
	"달라진 것이 네 개가 아니었다. 달라지지 않은 척하는 방법이 네 군데에서 끝난 것이다.": "There were not four changed things. Four places had simply stopped pretending they were unchanged.",
	"어제의 일과와 장치 조작은 끝났다. 달라진 아침을 확인한다.": "Yesterday's routine and mechanism work are over. Inspect the changed morning.",
	"같은 아침이 아니다. 방 안의 서로 다른 세 곳을 확인한다.": "This is not the same morning. Inspect three different places in the room.",
	"모두 중앙홀에 모이고 있다.": "Everyone is gathering in the central hall.",
	"이중 맥박 표식을 따라 사용인 통로를 지나 주방으로 간다.": "I follow the paired-pulse mark through the servants' passage to the kitchen.",
	"조용한 복도를 지나간다.": "I pass through the quiet corridor.",
	"사용인 조사 단계가 종료되었다. 기록 정리와 다음 저녁으로 이어진다.": "The servant-investigation phase is over. Continue to the record review and the final evening.",
	"파열 이후 합의를 먼저 확인한다.": "Confirm the agreement made after the fracture first.",
}

const E1_DESCRIPTIONS_EN := {
	"매트리스의 푹신함 아래 둥근 캡슐 곡면이 만져진다. 손목의 고정구가 미세하게 떨린다. 귀를 대면 내 심장보다 느린 냉각 펌프음이 들린다. 같은 침대가 아니라, 같은 장치를 침대로 보았던 걸까.": "Beneath the mattress's softness, I feel the curved surface of a capsule. A restraint at my wrist trembles faintly. Pressing my ear down reveals a cooling pump slower than my heart. Was it never the same bed, but the same machine seen as one?",
	"겨울 아침인데 유리는 차갑지 않다. 체온보다 조금 낮을 뿐이다. 새 한 마리가 같은 궤도를 반복하다 중간에서 사라진다. [동일 궤도 반복 00:04] 바깥 풍경은 방 안에 그림자를 만들지 않는다.": "It is a winter morning, yet the glass is not cold, only a little below body temperature. One bird repeats the same path and disappears halfway through. [IDENTICAL PATH LOOP 00:04] The scene outside casts no shadow into the room.",
	"내가 숨을 내쉰 뒤에 거울 속 가슴이 내려간다. 반 박자 늦다. 손끝을 대자 유리 대신 얇은 막이 밀린다. 검은 거울 아래에서 보았던 진단 패널과 같은 감촉이다.": "The chest in the mirror falls after I exhale, half a beat late. At my fingertip, a thin membrane yields instead of glass. It feels like the diagnostic panel beneath the black mirror.",
	"천 끈 안에서 광섬유 다발이 꺾인다. 종 대신 루카의 생체 신호음과 빠른 세 음이 겹친다. 아래층은 조용하다. 주방 방향에 연두 보조등이 켜지고 이중 맥박 문양이 떠오른다.": "A bundle of optical fibers bends inside the cloth cord. Luca's vital signal overlaps a rapid three-note chime instead of a bell. Downstairs is silent. A secondary indicator lights toward the kitchen, and a paired-pulse glyph appears.",
}

const E2_ANSWERS_EN := {
	"위장 필터가 해제되었습니다. 수면으로 정상 리셋을 복구할 수는 없습니다. 눈앞의 장치가 사라진 저택을 대신하는 것이 아니라, 줄곧 그 아래에 있었습니다.": "The camouflage filter has been disabled. Sleep cannot restore the normal reset. The machinery before you did not replace the mansion. It was beneath it all along.",
	"아가씨의 바깥 몸은... 냉각 장치에 있어요. 생존 신호는 유지되고 있어요. 하지만 깨어나도 안전한지는... 아직 보장할 수 없어요.": "Your body outside is... in a cooling unit. Its vital signs are stable. But whether waking will be safe... we still cannot guarantee.",
	"저희의 생체 신경 코어와 인격 프로세스는 물리 리셋 대상이 아니었습니다. 귀하가 잊었다고 생각한 어제도 기억합니다. 오래 숨겼습니다.": "Our bio-neural cores and personality processes were never subject to the physical reset. We remember every yesterday you thought was lost. We concealed that for a long time.",
}

static func is_english(locale: String) -> bool:
	return locale.begins_with("en")

static func ui(id: String, locale: String) -> String:
	if not UI.has(id): return id
	return String(UI[id][1 if is_english(locale) else 0])

static func e1_object(id: String, locale: String) -> String:
	return ui("e1_" + id, locale)

static func checked_suffix(locale: String) -> String:
	return " · " + ui("checked", locale)

static func feedback(source: String, locale: String) -> String:
	if source.is_empty() or not is_english(locale): return source
	if FEEDBACK_EN.has(source): return String(FEEDBACK_EN[source])
	if E1_DESCRIPTIONS_EN.has(source): return String(E1_DESCRIPTIONS_EN[source])
	if E2_ANSWERS_EN.has(source): return String(E2_ANSWERS_EN[source])
	var translated := PackedStringArray()
	for line in source.split("\n", true):
		translated.append(_line(String(line)))
	return "\n".join(translated)

static func _line(source: String) -> String:
	if FEEDBACK_EN.has(source): return String(FEEDBACK_EN[source])
	if E1_DESCRIPTIONS_EN.has(source): return String(E1_DESCRIPTIONS_EN[source])
	if E2_ANSWERS_EN.has(source): return String(E2_ANSWERS_EN[source])
	return source
