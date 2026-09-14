class_name BlackMirrorDisplayTexts
extends RefCounted

const OBJECTIVES := {
	"C_SLEEP": ["J2를 기억한 채 잠들어 다음 아침을 맞는다", "Sleep while holding J2 in mind, then face the next morning"],
	"C0": ["대응접실 남쪽 거울 회랑의 검은 거울을 확인한다", "Inspect the black mirror in the gallery south of the parlor"],
	"C1": ["거울의 코팅과 일지의 신호를 연결한다", "Connect the mirror coating to the journal's signal"],
	"C2": ["청소도구실 기록과 주방 약품 라벨을 비교한다", "Compare the tool-room record with the kitchen chemical label"],
	"C3": ["주방에서 직접 계량·혼합하고 시험지로 검증한다", "Measure and mix the solution in the kitchen, then verify it with a test strip"],
	"C_BELL": ["대시계에서 검증한 열세 번째 신호를 다시 보낸다", "Replay the verified thirteenth signal at the great clock"],
	"C4": ["거울에서 중첩과 경로를 시험한 뒤 실제로 닦는다", "Test the overlay and route on the mirror before cleaning it"],
	"CF": ["당일 거울 잠김 · 같은 침실에서 잠든다", "Mirror locked for today · Sleep in the same bedroom"],
	"C5_INFO": ["다섯 채널을 대조해 회로 투명지를 기록한다", "Compare all five channels and record the circuit tracing"],
	"J3": ["기록 내실에서 탁본과 일지 문장을 비교한다", "Compare the rubbing with the journal fragments in the inner archive"],
	"J3_COMPLETE": ["지하의 기준점을 기억한다 · 다음은 저택의 심장", "Remember the underground reference point · Next: the manor's heart"],
	"default": ["기록을 확인한다", "Review the records"],
}

const UI := {
	"mirror_door": ["남쪽 거울 회랑", "South Mirror Gallery"],
	"tool_door": ["청소도구실", "Cleaning Tool Room"],
	"kitchen_door": ["주방 조합대", "Kitchen Mixing Bench"],
	"color_door": ["색분해실 외부", "Color-Separation Room Entrance"],
	"location_tool": ["청소도구실", "Cleaning Tool Room"],
	"location_kitchen": ["주방 · 세정제 조합대", "Kitchen · Cleaning-Solution Bench"],
	"location_mirror": ["대응접실 남쪽 · 거울 회랑", "South of the Parlor · Mirror Gallery"],
	"location_color": ["색분해실 외부", "Color-Separation Room Entrance"],
	"location_copy": ["거울 회랑 · 수첩의 진단면 사본 검토", "Mirror Gallery · Reviewing the Notebook Diagnostic Copy"],
	"cleaning_record": ["마라 1의 청소 기록", "Mara 1's Cleaning Record"],
	"tool_room_board": ["기록은 사용인이 자리를 비워도 읽을 수 있다.\n눈금병과 부드러운 천, 고정 공구가 가지런히 놓여 있다.", "The record remains readable while the servant is away.\nA graduated bottle, soft cloth, and fastening tools lie in careful order."],
	"back_common": ["사용인 공용실로", "To the Servants' Common Room"],
	"back_parlor": ["대응접실로", "To the Parlor"],
	"back_north": ["북쪽 기록 회랑으로", "To the North Archive Hall"],
	"color_open": ["외부 렌즈에 다섯 문양이 겹친다. 내부 기능은 아직 열리지 않았다.", "Five glyphs overlap on the outer lens. Its inner function is still unavailable."],
	"color_closed": ["장식처럼 보이는 렌즈와 필터판. 아직 기능을 알 수 없다.", "A lens and filter plate disguised as decoration. I cannot tell what they do yet."],
	"shortcut": ["기록한 동선으로 재료만 다시 준비한다", "Use the recorded route to gather fresh materials"],
	"bell_board": ["두 번째 일지가 말한 것은 열쇠가 아니라 표면을 잠시 느슨하게 만드는 신호다.\n수첩에 검증한 설정으로 신호를 다시 보낼 수 있다.", "The second journal described a signal that briefly loosens the surface, not a key.\nI can replay it using the verified settings in my notebook."],
	"bell_replay": ["검증한 시계망으로 열세 번째 종 재현", "Replay the thirteenth chime with the verified clock network"],
	"chemical_record": ["약품 라벨·접힌 메모 조사", "Inspect the chemical label and folded note"],
	"prepare": ["새 재료와 천 준비", "Prepare fresh materials and cloth"],
	"disperse": ["안정제 확산 확인", "Disperse the stabilizer"],
	"mix": ["천천히 혼합", "Mix slowly"],
	"settle": ["거품 가라앉히기", "Let the foam settle"],
	"test": ["시험지로 검증", "Verify with a test strip"],
	"discard": ["폐기하고 병 헹구기", "Discard and rinse the bottle"],
	"cleaner_ready": ["중성 세정제 확보", "Neutral cleaning solution ready"],
	"cleaner_mirror": ["거울 회랑에서 경로를 대조한다", "Compare the route in the mirror gallery"],
	"cleaner_clock": ["다음 목적지는 서쪽 대시계", "Next destination: West Great Clock"],
	"observe": ["검은 거울 조사", "Inspect the black mirror"],
	"hypothesis": ["일지의 신호와 코팅을 연결한다", "Connect the journal signal to the coating"],
	"locked_board": ["당일 코팅 경화 또는 도구 회수\n기록은 남았다. 잠든 뒤 재료를 다시 준비할 수 있다.", "Coating hardened or tool confiscated for today\nThe record remains. After sleeping, I can gather fresh materials."],
	"scan_done": [" · 대조 완료", " · Compared"],
	"record_channels": ["회로·기준점·다섯 채널을 수첩에 고정", "Fix the circuit, reference points, and five channels in the notebook"],
	"rotate": ["90° 회전", "Rotate 90°"],
	"flip": ["좌우 반전", "Mirror horizontally"],
	"anchor": ["하단 큰 파동 고정", "Anchor the large wave at the bottom"],
	"clear_plan": ["경로 다시 놓기", "Clear the route"],
	"trace_compare": ["거울 홈과 투명지 확대 대조", "Compare the mirror grooves and tracing up close"],
	"dry": ["마른 천으로 시험", "Test with a dry cloth"],
	"verify": ["시험한 계획 확정", "Confirm the tested plan"],
	"wet": ["젖은 천으로 실행", "Apply with the wet cloth"],
	"patrol": ["에드가의 순찰 확인·대응", "Check and handle Edgar's patrol"],
	"overlay_title": ["거울 홈과 투명지", "Mirror Grooves and Tracing"],
	"overlay_body": ["굵은 실선·원: 거울 회로와 하단 진동점\n가는 점선·사각: 투명지 파형과 열세 번째 큰 파동\n두 기준과 비대칭 분기가 함께 맞는지 비교한다.", "Thick solid line and circle: mirror circuit and lower vibration point\nThin dotted line and square: tracing waveform and thirteenth large wave\nCompare whether both references and the asymmetric fork align together."],
	"overlay_back": ["현재 배치로 돌아간다", "Return to the current layout"],
	"patrol_title": ["회랑의 발소리", "Footsteps in the Gallery"],
	"patrol_body": ["경계가 높으면 에드가가 젖은 천을 점검할 수 있다. 처리 방식은 정답 경로를 바꾸지 않는다.", "At high alert, Edgar may inspect the wet cloth. How I handle him does not change the correct route."],
	"patrol_wait": ["순찰이 지나갈 때까지 기다린다", "Wait for the patrol to pass"],
	"patrol_question": ["일지 문장을 질문한다", "Ask about a line in the journal"],
	"patrol_cloth": ["일반 천을 앞에 둔다", "Leave the ordinary cloth in view"],
	"wet_title": ["오늘은 되돌릴 수 없는 닦기", "An Irreversible Cleaning for Today"],
	"wet_body": ["세정제를 묻히면 오류가 있는 경로의 코팅이 굳을 수 있다. 에드가의 순찰도 확인해야 한다. 실패하면 같은 침실에서 잠든 뒤 재료를 다시 준비한다.", "Once the solution touches the surface, a wrong route may harden the coating. I should also account for Edgar's patrol. If this fails, I must sleep in the same bedroom and prepare fresh materials."],
	"wet_review": ["계획을 다시 확인한다", "Review the plan again"],
	"wet_dry": ["마른 천으로 시험한다", "Test with a dry cloth"],
	"wet_execute": ["세정제를 묻혀 실행한다", "Apply the cleaning solution"],
	"j3_overlay": ["C5 투명지를 빈 테두리에 놓고 세 기준점 비교", "Place the C5 tracing in the empty frame and compare three reference points"],
	"j3_clear": ["문장 배열 다시 놓기", "Clear the sentence order"],
	"j3_restore": ["세 번째 페이지 복원", "Restore the third page"],
}

const MATERIALS := {
	"water": ["증류수", "Distilled water"],
	"stabilizer": ["안정제", "Stabilizer"],
	"active": ["원액", "Active solution"],
}

const SEGMENTS := {
	"entry": ["직선 진입", "Straight entry"],
	"short_branch": ["짧은 분기", "Short branch"],
	"long_branch": ["긴 분기", "Long branch"],
	"clockwise_ring": ["고리 시계 방향", "Clockwise loop"],
	"counterclockwise_ring": ["고리 반시계 방향", "Counterclockwise loop"],
}

const CHANNELS := {
	"EDGAR": ["에드가 · 수직 잠금선 · 낮은 시계음", "Edgar · vertical lock line · low clock tone"],
	"MARA1": ["마라 1 · 대각 닦임 · 마른 솔", "Mara 1 · diagonal wipe · dry brush"],
	"LUCA": ["루카 · 이중 맥박 · 생체음", "Luca · double pulse · vital tone"],
	"IRIS": ["이리스 · 꽃잎 · 유리와 바람", "Iris · petal halo · glass and wind"],
	"MARA2": ["마라 2 · 이중 액자 · 빠른 세 음", "Mara 2 · double frame · quick three-note trill"],
}

const J3_PARTS := [
	["거울은 네가 건넨 방향을 그대로 돌려주지 않는다.\n보이는 길을 집 위에 놓기 전에, 어느 쪽이 네 손에서 시작됐는지 먼저 되짚어라.", "The mirror does not return the direction you give it unchanged.\nBefore laying the visible route over the house, trace which side began in your hand."],
	["집의 심장은 가장 낮은 곳에서 뛴다.\n하지만 아래로 내려가는 것만으로는 닿지 못한다.", "The heart of the house beats at its lowest point.\nBut simply descending will not reach it."],
	["침실의 고요한 점, 온실의 계절이 멈추는 점,\n종이 없는데도 울리는 큰 시계를 한 장 위에 맞춰라.", "Align three points on one sheet: the bedroom's silent point, where the greenhouse season stops,\nand the great clock that rings without a bell."],
	["세 점이 모두 맞는 방향에서만\n입구는 집의 일부였다고 인정할 것이다.", "Only in the orientation where all three points align\nwill the entrance admit that it was part of the house."],
]

const FEEDBACK_EN := {
	"일지 2단계를 먼저 복원한다.": "Restore the journal's second page first.",
	"일지의 두 번째 페이지를 기억한 채 잠들고, 다음 아침의 거울을 확인한다.": "Sleep while holding the journal's second page in mind, then inspect the mirror the next morning.",
	"대응접실 남쪽의 거울 회랑에서 조사한다.": "Inspect it in the mirror gallery south of the parlor.",
	"그 표면은 닦는 대상이 아닙니다. 보존 처리가 되어 있습니다.": "That surface is not meant to be cleaned. It has been preserved.",
	"지난번 조사와 연결해서 생각하고 계십니까? 손에 드는 물건부터 확인하겠습니다.": "Are you connecting this to your previous investigation? I will inspect what you are carrying first.",
	"거울이 호흡보다 조금 늦게 흐려진다. 에드가는 청소가 아니라 보존이라는 말을 썼다.": "The mirror fogs a little later than my breath. Edgar called it preservation, not cleaning.",
	"먼저 거울과 금지 이유를 확인한다.": "First inspect the mirror and learn why it is forbidden.",
	"얼룩이 아니라 코팅일지도 모른다. 일지의 신호와 청소 기록, 약품 라벨을 비교해 보자.": "It may be a coating rather than a stain. I should compare the journal's signal, the cleaning record, and the chemical label.",
	"무엇을 닦으려는지부터 확인한다.": "First determine what I am trying to clean.",
	"청소도구실의 기록을 확인한다.": "Check the record in the cleaning tool room.",
	"청소 기록: 강한 용제는 코팅을 굳힌다. 중성 세정과 부드러운 천을 사용할 것.": "Cleaning record: Strong solvent hardens the coating. Use a neutral solution and a soft cloth.",
	"물의 양은 두 첨가제를 합친 양보다 2단위 많게 한다.": "Use two more units of water than the two additives combined.",
	"마라 1의 추기: 물때랑 코팅을 헷갈리면 안 됨다. 제가 한 번 크게 배웠슴다.": "Mara 1's addendum: Don't confuse scale with coating. I learned that one the loud way.",
	"주방 약품장의 라벨을 확인한다.": "Check the label in the kitchen chemical cabinet.",
	"라벨: 전체 8단위. 원액은 안정제의 두 배.": "Label: Eight units total. Active solution is twice the stabilizer.",
	"마른 병에 활성 성분을 넣지 말 것. 물에 안정제가 퍼진 뒤 원액을 넣을 것.": "Do not add active solution to a dry bottle. Add it after the stabilizer disperses in water.",
	"접힌 메모: 손이 떨릴 때도 읽을 수 있게... 큰 글씨로 다시 써 뒀어요.": "Folded note: I rewrote it in large letters... so I can read it even when my hands shake.",
	"청소 기록과 약품 라벨이 모두 필요하다.": "I need both the cleaning record and the chemical label.",
	"오늘의 거울 표면은 돌아오지 않는다. 먼저 잠든다.": "The mirror surface will not recover today. I need to sleep first.",
	"실패 뒤 같은 침실에서 기록한 준비 동선을 사용한다. 이미 확보한 거울 회로는 수첩에서 이어서 조사한다.": "After a failed attempt, use the recorded preparation route from the same bedroom. If the mirror circuit is already recorded, continue from the notebook instead.",
	"주방 조합대에서 재료를 준비한다.": "Prepare the materials at the kitchen mixing bench.",
	"빈 눈금병, 물, 안정제와 원액, 부드러운 천을 새로 준비했다. 공식은 남아 있어도 세정액은 직접 다시 만든다.": "I gathered a clean graduated bottle, water, stabilizer, active solution, and a soft cloth. The formula survives, but I must make the solution again.",
	"주방에서 재료를 먼저 준비한다.": "Prepare the materials in the kitchen first.",
	"검증한 세정액은 밀봉해 두었다. 거울을 준비한다.": "The verified solution is sealed. I should prepare the mirror.",
	"폐기 쟁반에 용액을 비우고 병을 헹군다. 같은 날 다시 계량할 수 있다.": "I empty the solution into the disposal tray and rinse the bottle. I can measure again today.",
	"표시된 재료를 선택한다.": "Select one of the displayed materials.",
	"안전 라벨: 마른 병에는 첨가하지 않는다. 물이 먼저 필요하다.": "Safety label: Do not add this to a dry bottle. Water must go in first.",
	"원액은 물속에서 안정제가 확산된 뒤에 넣는다.": "Add the active solution only after the stabilizer disperses in the water.",
	"병의 최대 눈금이다. 넘치기 전에 멈추고 폐기 쟁반을 사용한다.": "The bottle is at its maximum mark. Stop before it overflows and use the disposal tray.",
	"아직 확산시킬 안정제가 없다.": "There is no stabilizer to disperse yet.",
	"물 표면이 숨을 고르듯 내려앉는다. 안정제가 퍼졌다.": "The water's surface settles as if catching its breath. The stabilizer has dispersed.",
	"병을 내려놓고 기다리자 거품이 가라앉는다.": "I set the bottle down and wait. The foam subsides.",
	"검증한 공식: 물 5, 안정제 1, 원액 2. 물 → 안정제 확산 → 원액, 천천히 혼합.": "Verified formula: water 5, stabilizer 1, active solution 2. Water -> disperse stabilizer -> active solution, then mix slowly.",
	"검증한 세정액을 준비한 뒤 대시계의 신호를 다시 보낸다.": "Prepare the verified solution, then replay the signal at the great clock.",
	"수첩에 검증한 시계망 설정을 다시 놓는다. 정상 종이 끝난 뒤 한 칸, 열세 번째 떨림이 벽을 지난다.": "I restore the verified clock-network settings from my notebook. One step after the normal chimes end, the thirteenth tremor passes through the wall.",
	"회랑에서 순찰을 확인한다.": "Check the patrol in the gallery.",
	"순찰이 지나갈 때까지 기다린다. 에드가의 발소리가 멀어진다.": "I wait for the patrol to pass. Edgar's footsteps recede.",
	"일지 문장에 관해 묻자 에드가가 복도 쪽에서 보존 원칙을 설명한다. 점검은 끝났다.": "When I ask about the journal, Edgar explains the preservation rules from the corridor. His inspection is over.",
	"일반 천을 앞에 두자 에드가가 그 천을 점검하고 나간다.": "I leave the ordinary cloth in view. Edgar inspects it and leaves.",
	"거울 앞에서 일지의 가설을 확인한다.": "Review the journal's hypothesis in front of the mirror.",
	"코팅이 굳었다. 기록을 챙기고 같은 침실에서 잠든다.": "The coating has hardened. Keep the record and sleep in the same bedroom.",
	"진단면이 이미 드러났다. 회로를 기록한다.": "The diagnostic surface is already exposed. Record the circuit.",
	"경로는 네 구간까지 놓는다. 수정하려면 계획을 다시 펼친다.": "The route accepts four segments. Clear the plan before revising it.",
	"아직 진동이 닿지 않았다. 세정액을 준비하고 대시계에서 신호를 보낸다.": "The vibration has not reached the mirror yet. Prepare the solution and send the signal from the great clock.",
	"마른 천으로 전체 경로를 시험한 뒤 계획을 확정한다.": "Test the full route with a dry cloth before confirming the plan.",
	"마른 시험에서 확인한 계획을 수첩에 확정했다. 아직 코팅에는 손대지 않았다.": "I fixed the dry-tested plan in my notebook. The coating remains untouched.",
	"검증한 세정액과 되돌릴 수 없는 실행에 대한 확인이 필요하다.": "I need the verified solution and confirmation before this irreversible action.",
	"에드가가 젖은 천을 거둔다. 아직 점검을 마치지 않았다는 말만 남긴다.": "Edgar confiscates the wet cloth, saying only that his inspection is not finished.",
	"검은 표면 아래 진단 패널과 냉각 장치 같은 긴 윤곽이 드러난다. 거울 속 호흡만 한 박자 늦다.": "A diagnostic panel and the long outline of something like a cooling unit appear beneath the black surface. Only the breath in the mirror lags by one beat.",
	"드러난 원도를 우선 수첩에 옮겼다. 다섯 문양의 해석과 대조는 아직 남아 있다.": "I copy the exposed tracing into my notebook first. The five glyphs still need to be identified and compared.",
	"오늘은 다시 닦을 수 없다. 잠든 뒤 기록으로 준비를 줄인다.": "I cannot clean it again today. After sleeping, the record will shorten the preparation.",
	"거울의 진단면을 먼저 드러낸다.": "Expose the mirror's diagnostic surface first.",
	"표시된 채널을 선택한다.": "Select one of the displayed channels.",
	"서로 다른 문양이 같은 면 아래에서 겹친다. 이것이 무엇인지는 아직 단정할 수 없다.": "Different glyphs overlap beneath the same surface. I still cannot say what they are.",
	"색 대신 문양과 이름으로 다섯 출처를 모두 대조한다.": "Compare all five sources by glyph and name rather than color alone.",
	"직선·분기·고리의 반사 원도, 침실 창·온실 유리·대시계 기준점과 지하 좌표를 수첩에 고정했다.": "I fixed the reflected straight line, fork, and loop, along with the bedroom-window, greenhouse-glass, great-clock reference points and underground coordinates, in my notebook.",
	"자료를 기록한 뒤 조용한 기록 내실에서 일지를 펼친다.": "Record the evidence, then open the journal in the quiet inner archive.",
	"세 번째 페이지는 복원되어 있다.": "The third page has already been restored.",
	"탁본을 그대로 놓으면 세 점이 동시에 맞지 않는다. 거울의 방향과 집의 방향을 아직 같은 것으로 믿을 수 없다.": "If I place the rubbing unchanged, the three points do not align together. I cannot assume the mirror and the house share the same orientation.",
	"문장 조각을 선택한다.": "Select a sentence fragment.",
	"눌림 자국과 문장이 이어지지 않는다. 탁본의 모순을 확인하고 다시 배열한다.": "The impressions and sentences do not connect. Review the contradiction in the rubbing and rearrange them.",
	"짧은 연필이 종이 가루를 밀어 낸다. 더 큰 손이 외벽을 짚자 없던 문 윤곽이 생긴다. '문은 네가 고르는 곳에...' 기억은 거기서 끊긴다.": "A short pencil pushes paper dust aside. When a larger hand touches the outer wall, the outline of a door appears where none existed. 'The door goes where you choose...' The memory breaks there.",
	"아직 정의되지 않은 조사다.": "That investigation is not defined yet.",
	"눈금이 8단위에 맞지 않는다. 폐기 쟁반에서 비우고 다시 계량한다.": "The level does not reach eight units. Empty it into the disposal tray and measure again.",
	"시험지: 중성 아님 · 빗금 문양. 첨가제 사이의 비율과 물의 양을 다시 비교한다.": "Test strip: Not neutral · hatched glyph. Recheck the additive ratio and the amount of water.",
	"작은 결정이 남는다. 물에서 안정제를 확산시킨 뒤 원액을 넣어야 한다.": "Small crystals remain. Disperse the stabilizer in water before adding the active solution.",
	"혼합 상태가 고르지 않다. 천천히 섞고 거품이 가라앉는지 확인한다.": "The mixture is uneven. Stir slowly and make sure the foam settles.",
	"시험지: 중성 · 평행선 문양. 무색의 세정액이 천에 고르게 스며든다.": "Test strip: Neutral · parallel-line glyph. The colorless solution soaks evenly into the cloth.",
	"큰 파동과 거울 하단 진동점이 겹치지 않는다. 기준점을 먼저 맞춘다.": "The large wave does not overlap the vibration point below the mirror. Align the reference point first.",
	"긴 진입 진동, 두 갈래 반사, 마지막 잔류파가 끊김 없이 이어진다.": "The long entry vibration, two reflected branches, and final residual wave connect without interruption.",
	"분기 한쪽의 반응이 없다. 두 반사 구간을 비교한다.": "One side of the fork does not respond. Compare the two reflected segments.",
	"시작 압력이 만들어지지 않는다. 파형의 진입부를 찾는다.": "No starting pressure forms. Find the entry section of the waveform.",
	"가장자리의 닫힌 홈이 역방향으로 눌린다.": "The closed groove at the edge presses in the wrong direction.",
	"두 반사압이 역순으로 겹친다.": "The two reflected pressures overlap in reverse order.",
}


static func is_english(locale: String) -> bool:
	return locale.begins_with("en")


static func objective(stage: String, locale: String) -> String:
	var pair: Array = OBJECTIVES.get(stage, OBJECTIVES["default"])
	return String(pair[1 if is_english(locale) else 0])


static func ui(id: String, locale: String) -> String:
	if not UI.has(id):
		return id
	return String(UI[id][1 if is_english(locale) else 0])


static func material_name(id: String, locale: String) -> String:
	return String(MATERIALS.get(id, [id, id])[1 if is_english(locale) else 0])


static func segment_name(id: String, locale: String) -> String:
	return String(SEGMENTS.get(id, [id, id])[1 if is_english(locale) else 0])


static func channel(owner: String, locale: String) -> String:
	return String(CHANNELS.get(owner, [owner, owner])[1 if is_english(locale) else 0])


static func j3_part(index: int, locale: String) -> String:
	return String(J3_PARTS[index][1 if is_english(locale) else 0])


static func mixture_status(mix: Dictionary, locale: String) -> String:
	if not is_english(locale):
		return "8단위 병: 물 %d / 안정제 %d / 원액 %d\n확산: %s · 혼합: %d회 · %s" % [mix["water"], mix["stabilizer"], mix["active"], "완료" if mix["dispersed"] else "미확인", mix["mixed"], "거품 있음" if mix["foamy"] else "거품 없음"]
	return "8-unit bottle: Water %d / Stabilizer %d / Active %d\nDispersion: %s · Mixed: %d time(s) · %s" % [mix["water"], mix["stabilizer"], mix["active"], "Complete" if mix["dispersed"] else "Unverified", mix["mixed"], "Foamy" if mix["foamy"] else "No foam"]


static func trace_status(local: Dictionary, locale: String) -> String:
	var names := PackedStringArray()
	for id in local["path"]:
		names.append(segment_name(String(id), locale))
	if not is_english(locale):
		return "투명지 %d° · %s · 하단 기준점 %s\n계획: %s" % [local["rotation"], "반전" if local["flipped"] else "반전 없음", "고정" if local["anchored"] else "미고정", " → ".join(names)]
	return "Tracing %d° · %s · Lower reference %s\nRoute: %s" % [local["rotation"], "Mirrored" if local["flipped"] else "Not mirrored", "Anchored" if local["anchored"] else "Not anchored", " -> ".join(names)]


static func feedback(source: String, locale: String) -> String:
	if source.is_empty() or not is_english(locale):
		return source
	if FEEDBACK_EN.has(source):
		return String(FEEDBACK_EN[source])
	for index in range(J3_PARTS.size()):
		if source == J3_PARTS[index][0]:
			return String(J3_PARTS[index][1])
	var translated := PackedStringArray()
	for line in source.split("\n"):
		translated.append(_line(String(line)))
	return "\n".join(translated)


static func _line(source: String) -> String:
	if source.is_empty():
		return source
	if FEEDBACK_EN.has(source):
		return String(FEEDBACK_EN[source])
	if source.begins_with("마른 천 시험: "):
		return "Dry-cloth test: " + String(FEEDBACK_EN.get(source.trim_prefix("마른 천 시험: "), source.trim_prefix("마른 천 시험: ")))
	for owner in CHANNELS:
		var korean := String(CHANNELS[owner][0])
		if source == korean:
			return String(CHANNELS[owner][1])
		if source == "진단면: " + korean:
			return "Diagnostic surface: " + String(CHANNELS[owner][1])
		if source == "수첩의 진단면 사본: " + korean:
			return "Notebook diagnostic copy: " + String(CHANNELS[owner][1])
	for part in J3_PARTS:
		var korean_lines := String(part[0]).split("\n")
		var english_lines := String(part[1]).split("\n")
		var index := korean_lines.find(source)
		if index >= 0:
			return String(english_lines[index])
	return source
