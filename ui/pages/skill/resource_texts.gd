class_name ResourceTexts
extends RefCounted
## Texts of the resource table and of the tool heads section (docs/05_INTERFACES_M35.md §7.ac, docs/05_INTERFACES_M36.md §7.ae). Italian,
## no numbers of design: costs, levels, colours and stocks come from the model. No state.

const COLUMNS: Array[String] = ["Risorsa", "Liv.", "Scorta", "Zona", "Colore"]
const WHERE_LINE_TEXT: String = "%s %d%%"
const WHERE_HERE_TEXT: String = "> %s %d%%"
const WHERE_NONE_TEXT: String = "-"
const WHERE_LOCKED_TEXT: String = "%s · livello %s"
const WHERE_TIP_TEXT: String = "%s: %s%% al tuo livello"
const WHERE_TIP_LOCKED_TEXT: String = "%s: non ancora lavorabile al tuo livello"
const LEVEL_TEXT: String = "%s"
const NO_USE_TEXT: String = "-"
const MASTERY_TEXT: String = "Maestria: livello %s"
const NEXT_BONUS_TEXT: String = "Prossimo bonus: %s"
const NO_MASTERY_TEXT: String = "Nessuna maestria"
const COLOR_TEXT: String = "%s (%s%% XP)"
const GO_TEXT: String = "Vai"
const GO_HERE_TIP: String = "Sei già in questa zona"
const GO_LOCKED_TIP: String = "Serve livello %s per lavorare questa risorsa"
const USES_TEXT: String = "Serve a: %s"
const PRICE_TEXT: String = "Prezzo: %s"

const HEADS_TITLE: String = "Teste"
const HEAD_STEP_TEXT: String = "+%d"
const HEAD_LOCKED_TEXT: String = "bloccata (serve +%d)"
const HEAD_FREE_TEXT: String = "gratis"
const HEAD_CHANGE_TEXT: String = "cambio: %s"
const HEAD_CONFIRM_TEXT: String = "Conferma: %s"
const HEAD_CHOOSE_WARNING: String = "Scegli una testa: finché non la scegli il passo non dà nulla."
const HEAD_NEXT_WARNING: String = "Al prossimo passo potrai scegliere una testa."
const HEAD_BUTTON_FMT: String = "%s\n%s"
const HEAD_NONE_TEXT: String = "nessuna"
