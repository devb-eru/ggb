extends RefCounted

const KO := [
	"마지막 링이 XIII에서 멈춘다. 기계는 멎지 않는다. 처음으로 고른 작동음이 이어진다.",
	"SYNC COMPLETE\nXIII SYNCHRONIZED\n완료 표시 아래에 다음 문장이 나타난다. CAMOUFLAGE FILTER OFF.",
	"손잡이를 놓는다. 손바닥에는 톱니의 진동이 아직 남아 있다.",
	"벽지 문양이 배선 격자에서 미끄러져 떨어진다. 촛불은 그대로인데 열이 없다. 향초 냄새 사이로 오존과 소독약 냄새가 스민다.",
	"기둥의 그림자가 구조물과 다른 방향으로 남았다가 늦게 사라진다. 황동 톱니의 일부는 같은 회전을 되풀이하는 얇은 겉면이었다.",
	"망가진 소리가 아니었다. 너무 잘 맞물린 소리였다. 그래서 더 늦게 손을 뗐다.",
	"진단 투사에 다섯 윤곽이 겹친다. 사용인들이 이 방에 온 것은 아니다. 에드가의 뿔과 꼬리에서 수직 잠금선이 떨어지고, 레이피어 위에 가느다란 포인터가 겹친다.",
	"마라의 귀와 꼬리 뒤로 대각선 잔상이 남는다. 스패너의 윤곽이 정비 표식과 어긋난다.",
	"루카의 몸과 귀가 서로 다른 박자로 반응한다. 이중 맥박선 사이의 틈이 잠깐 길어진다.",
	"이리스의 머리카락 둘레와 플라스틱 날개 관절이 따로 떠오른다. 꽃잎 같은 후광은 몸보다 늦게 움직인다.",
	"마라 2의 이중 윤곽은 겹친 액자처럼 벌어진다. 두 입 중 한쪽만 말을 시작하는 모양을 만든다. 말은 알아들을 수 없다.",
	"창문 없는 지하의 천장 틈에서 밤하늘이 드러난다. 별은 깜빡이지 않는다. 고개를 돌리면 한 장의 그림처럼 따라온다.",
	"방송: 오늘도 수고하셨습니다.\n같은 목소리가 잠시 뒤 이어진다.\n복구 기준점 없음.",
	"투사된 안내에 침실과 가까운 비상 휴식 캡슐의 두 방향이 나타난다. 주인공은 수첩을 쥔다. 벽은 달라졌지만 적어 둔 글자는 남아 있다."
]

const EN := [
	"The final ring stops at XIII. The machine does not stop. For the first time, its rhythm is perfectly even.",
	"SYNC COMPLETE\nXIII SYNCHRONIZED\nAnother line appears beneath the completion notice. CAMOUFLAGE FILTER OFF.",
	"You release the handle. The vibration of the gears remains in your palm.",
	"The wallpaper slides away from a grid of wiring. The candle still burns, but gives off no heat. Ozone and disinfectant seep through its familiar scent.",
	"A column's shadow points away from the structure, then disappears a moment late. Some of the brass gears were only a thin surface repeating the same rotation.",
	"It did not sound broken. Everything meshed too well. That was why I let go too late.",
	"Five outlines overlap in a diagnostic projection. The servants have not entered the room. Vertical locking lines separate from Edgar's horns and tail. A thin pointer overlaps his rapier.",
	"Diagonal traces linger behind Mara's ears and tail. Her spanner's outline slips out of alignment with a maintenance mark.",
	"Luca's body and ears respond at different tempos. The gap between the paired pulse lines briefly grows longer.",
	"The light around Iris's hair and the joints of her plastic wings separate into different layers. A petal-like halo follows her body a moment late.",
	"Mara 2's double outline opens like overlapping frames. Only one of the two mouths starts to form a word. You cannot make it out.",
	"A night sky appears through a gap in the ceiling of the windowless basement. The stars do not twinkle. They follow your gaze like a single painted sheet.",
	"Broadcast: Thank you for your work today.\nA moment later, the same voice continues.\nNo recovery reference point.",
	"The projected guide shows two directions: the bedroom and a nearby emergency rest capsule. You hold your notebook. The walls have changed, but your writing remains."
]

static func lines(locale: String) -> Array:
	var result: Array = []
	var source: Array = EN if locale.begins_with("en") else KO
	for index in range(source.size()):
		result.append({"speaker": "주인공" if index == 5 else "SYSTEM", "text": source[index]})
	return result
