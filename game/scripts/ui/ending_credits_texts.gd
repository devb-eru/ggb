extends RefCounted

const RULES := preload("res://scripts/systems/ending_credits.gd")
const PAGES := [
	["Development credits", "GGB · Working title\nFinal credits for design, art, audio, and development are to be determined.\nThis is not the final production credit list for release."],
	["Tools and resources", "Game engine: Godot\nRelease copyright and license notices for individual fonts, images, and audio will be compiled after the resources are finalized.\nNo unverified creator names or rights notices are added."],
	["The scene ends; the records remain", "Your chosen ending remains unchanged. If you exit during the credits, you will resume from this page.\nThe ending viewing record is stored in your profile independently of credit completion.\nAfter the credits, you can explore another choice in a separate copy. The gallery lets you read scenes and observations you have seen; full scene playback is still in preparation."],
]
const LABELS := {
	"reality": ["현실 기상", "Waking into reality"],
	"stay": ["안정화 잔류", "Remaining in the stabilized mansion"],
	"objective": ["개발용 크레딧", "Development credits"],
	"post_body": ["크레딧 완료가 저장되었습니다.\n다른 선택은 F3 당시 상태를 보존한 별도 슬롯에서 확인합니다.\n감상 기록에서는 마지막 장면과 확인한 조사를 열람합니다.", "Credit completion has been saved.\nExplore another choice in a separate slot preserving your state at F3.\nThe gallery contains the final scene and observations you have seen."],
	"reselect": ["다른 선택 확인 / 사본 이어하기", "Explore another choice / Resume a copy"],
	"gallery": ["감상 기록 · 마지막 장면과 조사", "Viewing records · Final scene and observations"],
	"title": ["타이틀로", "Return to title"],
	"save_error": ["마지막 장면은 저장되었습니다.\n엔딩 감상 기록을 저장하지 못했습니다.\n저장 공간·파일 접근 상태를 확인한 뒤 다시 시도해 주세요.\n오류: %s", "The final scene has been saved.\nThe ending viewing record could not be saved.\nCheck storage space and file access, then try again.\nError: %s"],
	"retry": ["감상 기록 저장 재시도", "Retry saving the viewing record"],
	"start": ["개발용 크레딧을 확인한다", "View the development credits"],
	"next": ["다음 페이지", "Next page"],
	"finish": ["크레딧 확인 완료", "Finish viewing the credits"],
}

static func text(id: String, locale: String) -> String:
	return LABELS[id][1 if locale.begins_with("en") else 0]

static func page(index: int, locale: String) -> String:
	var data: Array = (PAGES if locale.begins_with("en") else RULES.PAGES)[index]
	return data[0] + "\n\n" + data[1]
