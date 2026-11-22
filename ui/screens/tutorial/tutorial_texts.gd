class_name TutorialTexts
extends RefCounted
## Italian presentation texts of the tutorial overlay (docs/05_INTERFACES_M30.md §7.ab). No game number here.

const STEP_TEXT: String = "Passo %d di %d"
const NEXT_TEXT: String = "Avanti"
const SKIP_TEXT: String = "Continua comunque"
const GO_TO_TEXT: String = "Vai a %s"
const CLOSED_PAGE_HINT: String = "Lo scoprirai nel tutorial"
const PROGRESS_TEXT: String = "%d / %d"
const REFUSED_TEXT: String = "Non puoi ancora andare avanti."
## Page route -> name shown in "Vai a ...", the same as the sidebar rows.
const PAGE_NAMES: Dictionary[StringName, String] = {
	&"character": "Personaggio", &"equipment": "Equipaggiamento", &"rift": RiftTexts.TITLE_TEXT, &"bank": "Deposito",
	&"combat": ItemTooltipLines.COMBAT_TEXT, &"fractures": FractureTexts.TITLE_TEXT, &"dungeon": DungeonTexts.TITLE_TEXT,
	&"village": VillageTexts.TITLE_TEXT, &"trainers": TrainersTexts.SIDEBAR_TEXT, &"noticeboard": NoticeboardTexts.TITLE_TEXT,
	&"auction": AuctionTexts.TITLE_TEXT, &"mail": MailTexts.TITLE_TEXT, &"shop": "Shop", &"guide": "Guida", &"skill": "Mestiere",
	&"starter": "Primi passi",
}


static func page_name(route: StringName) -> String:
	return PAGE_NAMES.get(route, String(route))
const SKIP_TUTORIAL_TEXT: String = "Salta tutorial"
const SKIP_CONFIRM_TEXT: String = "Vuoi saltare il tutorial? Potrai rivedere la Guida in ogni momento"
const YES_TEXT: String = "Sì"
const NO_TEXT: String = "No"
