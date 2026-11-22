# 04. Schema dei dati, §34: Tutorial e incarichi «Primi passi» (M30; V39, `01_GDD_M30.md` §41)

Estensione di `04_DATA_SCHEMA.md` (che supera le 400 righe): vale come la sua sezione **§34**. Regole generali di §0-§1 invariate (id `snake_case`, nessun campo sconosciuto, nessun
fallback silenzioso). Gli intervalli sono **limiti di formato** del validatore (`DataValidatorTutorial`, M30-02), non valori di design. File nuovi in `data/tutorial/`; un kind nuovo in
`data/mail/templates.json` (§34.5). Il contenuto (testi, ordine, valori) è nelle tabelle di `01_GDD_M30.md` §41.4 e §41.7: i JSON ne sono la trascrizione (M30-03).

## 34.1 `data/tutorial/steps.json`
```json
{
  "stuck_ms": 180000,
  "always_open": ["guide", "help"],
  "steps": [
    {"id": "welcome", "page": "", "target": "", "title": "Benvenuto, Lama del Rift", "text": "<testo>", "done_when": {"type": "ack"}},
    {"id": "equipment", "page": "equipment", "target": "equipment.inventory", "title": "…", "text": "…",
     "done_when": {"type": "event", "signal": "equipment_changed", "args": {"slot_id": "weapon"}}},
    {"id": "trainers", "page": "trainers", "target": "trainers.learn.forestry", "title": "…", "text": "…",
     "done_when": {"type": "event", "signal": "discipline_changed", "args": {"skill_id": ["forestry", "quarrying", "angling", "herbalism"], "grade": 1}}},
    {"id": "mail", "page": "mail", "target": "mail.list", "title": "…", "text": "…",
     "on_enter": {"mail": {"kind": "tutorial_gift", "money": 3000}},
     "done_when": [{"type": "metric", "metric": "mail_collected", "gte": 1}]}
  ]
}
```
| Campo | Tipo | Vincoli |
|---|---|---|
| `stuck_ms` | int | ≥ 10000; tempo di gioco dopo il quale un passo non-Avanti offre "Continua comunque" (§41.2) |
| `always_open` | Array[String] | route sempre aperte durante il tutorial; ognuna in `ROUTES` (§34.4) |
| `steps` | Array | almeno 1; **ordine = ordine del tutorial**; **ultimo passo con `done_when` `ack`** (la fine) |
| `id` | String | `snake_case` unico |
| `page` | String | `""` oppure una route di `ROUTES` (§34.4); **senza argomento** (`skill`, non `skill:forestry`) |
| `target` | String | `""` oppure un id di §34.4 la cui pagina coincide con `page` (o `page.<route>` della stessa pagina); vuoto = pannello al centro |
| `title` | String | 1..40 caratteri |
| `text` | String | 1..280 caratteri, nessuna graffa; senza cifre di design che stanno nei dati (i numeri citati devono avere un controllo, §34.6) |
| `done_when` | condizione o Array di condizioni | §34.2; più condizioni = basta una |
| `on_enter` | oggetto, facoltativo | solo `{"mail": {"kind": "tutorial_gift", "money": int ≥ 1}}` oppure `"items": [{"item", "qty"}]` (denaro **o** oggetti, come la Posta); consegnato entrando nel passo |

## 34.2 Condizioni (stesso formato per i passi e per gli incarichi)
```json
{"type": "ack"}
{"type": "event", "signal": "monster_killed", "args": {"monster_id": "ember_rat"}, "count": 5}
{"type": "metric", "metric": "disciplines_learned", "arg": "gathering", "gte": 1}
```
| Tipo | Campi | Significato |
|---|---|---|
| `ack` | nessuno (solo nei **passi**) | il giocatore preme Avanti (`acknowledge`) |
| `event` | `signal` String, `args` Dictionary (facoltativo), `count` int ≥ 1 (facoltativo, 1) | arriva un segnale dell'EventBus i cui argomenti passano il filtro; si conta fino a `count`. Per un passo si contano solo gli eventi **da quando il passo è corrente**; per un incarico da quando gli incarichi sono attivi |
| `metric` | `metric` String (§5.42), `arg` String (facoltativo), `gte` int ≥ 0 | la misura letta dal modello è ≥ `gte`; si rilegge a ogni segnale della misura e quando il passo diventa corrente (già vera = il passo finisce subito) |

- **Filtro `args`**: chiavi = **nomi degli argomenti del segnale** (letti dallo script di `GameEvents`: il validatore rifiuta un nome che il segnale non ha). Valore **scalare** = uguale;
  **array** = uguale a uno qualsiasi; **oggetto** `{"gte": n}` / `{"lte": n}` / `{"gt": n}` / `{"lt": n}` = confronto numerico. Confronto di `StringName` con String.
- **Segnali ammessi** = tutti quelli di `GameEvents` **tranne** (rumorosi o interni): `combat_hit`, `monster_hp_changed`, `player_hp_changed`, `node_attempt_done`, `modifiers_changed`,
  `xp_gained`, `bank_changed`, `gold_changed`, `deposit_changed`, `offline_started`, `offline_progress`, `offline_completed`, `save_completed`, `save_failed`, `notification_requested`,
  `session_started`, `session_ended`, `hint_triggered` e i segnali `tutorial_*` / `starter_*`. Elenco in `DataValidatorTutorial.DENIED_SIGNALS`.
- **Metriche ammesse**: elenco chiuso di `TutorialMetrics` (§5.42 di `05_INTERFACES_M30.md`); `arg` obbligatorio solo dove indicato.

## 34.3 `data/tutorial/starter_quests.json`
```json
{
  "groups": [{"id": "character", "title": "Personaggio"}, {"id": "combat", "title": "Combattimento"}],
  "quests": [
    {"id": "first_trait", "group": "character", "name": "Il primo tratto", "description": "<testo>",
     "goal": {"type": "event", "signal": "traits_changed", "count": 1},
     "reward": {"money": 1000, "character_xp": 50}},
    {"id": "eat_once", "group": "combat", "name": "Un pasto sul campo", "description": "…",
     "goal": {"type": "event", "signal": "food_eaten"},
     "reward": {"items": [{"item": "seared_brookfin", "qty": 10}]}}
  ]
}
```
| Campo | Tipo | Vincoli |
|---|---|---|
| `groups[].id` / `title` | String | id unico `snake_case`; `title` 1..30 caratteri; **ordine = ordine delle sezioni nella pagina** |
| `quests[].id` | String | `snake_case` unico; **ordine = ordine di file** (= suggerimento "prossimo") |
| `group` | String | un `groups[].id`; ogni gruppo ha almeno un incarico |
| `name` | String | 1..40 caratteri |
| `description` | String | 1..140 caratteri |
| `goal` | condizione | **solo** `event` o `metric` (mai `ack`) |
| `reward` | oggetto | `money` int ≥ 1 **oppure** `items` Array non vuoto di `{item, qty ≥ 1}` (mai insieme: limite della Posta); `character_xp` int 1..1000 facoltativo; almeno uno dei tre; ogni `item` esiste ed è vendibile (V37); nessun oggetto di categoria `weapon`, `armor`, `offhand`, `tool`, `bag`, `map` (niente pezzi né potere diretto) |

## 34.4 Route e id dei bersagli (fissati qui, usati da dati e UI)
`ROUTES` del tutorial (`DataValidatorTutorial.ROUTES`): `character`, `equipment`, `combat`, `bank`, `shop`, `rift`, `trainers`, `skill`, `village`, `noticeboard`, `auction`, `mail`, `fractures`,
`dungeon`, `guide`, `help`, `starter`. Un bersaglio è un id `<scope>.<nome>`; **la UI lo risolve** con la tabella `TutorialTargets` (`ui/screens/tutorial/`, §7.ab), mai i dati col percorso di nodi.

| Id | Pagina | Controllo evidenziato |
|---|---|---|
| `page.<route>` | `<route>` | l'intera area della pagina (per `skill`: la pagina della disciplina mostrata) |
| `equipment.inventory` | `equipment` | l'elenco dei pezzi dell'Armeria |
| `combat.map_button` | `combat` | il pulsante Mappa (`%MapButton`) |
| `combat.enemy_zone` | `combat` | la zona dei nemici / scheda del nodo (`%EnemyZone`) |
| `combat.eat_button` | `combat` | il pulsante Mangia (`%EatButton`) |
| `trainers.learn.forestry` | `trainers` | il pulsante «Impara» della riga del Boscaiolo (`trainers.learn.<id disciplina>` vale per ogni disciplina; il tutorial usa solo `forestry`) |
| `skill.header` | `skill` | l'intestazione della pagina del mestiere |
| `mail.list` | `mail` | l'elenco dei messaggi |

Il validatore controlla il **formato** (`page.<route>` con route valida; gli altri id sono in `DataValidatorTutorial.TARGETS`, elenco chiuso) e che `target` appartenga alla `page` del passo.
Un bersaglio che la UI non trova a runtime ripiega sull'area della pagina (mai blocca).

## 34.5 Posta: due kind nuovi (`data/mail/templates.json`, schema §32.5 esteso)
`MailBox.KINDS` e `DataValidatorMail.KINDS` guadagnano **`tutorial_gift`** e **`starter_reward`**; ognuno ha **almeno due** modelli (varianti; il modello si sceglie con `id % n`, come per gli altri).
Segnaposto ammessi invariati (`{item}`, `{qty}`, `{price}`, `{money}`); i testi dei due kind **non** ne usano (valgono per denaro e oggetti insieme):
```json
{"kind": "tutorial_gift", "sender": "Il Villaggio", "subject": "Un benvenuto per te", "body": "Benvenuto, Lama del Rift. Nella busta c'è un piccolo aiuto per cominciare: ritiralo quando vuoi."},
{"kind": "starter_reward", "sender": "Il Villaggio", "subject": "Un premio per i tuoi primi passi", "body": "Hai fatto un altro passo: guarda l'allegato. Il Villaggio non dimentica chi si dà da fare."}
```
(testi di esempio per la forma; i testi veri li scrive M30-03, ≥ 2 per kind, originali, subject ≤ 60 e body ≤ 240.)

## 34.6 Controlli del validatore (`DataValidatorTutorial`, M30-02)
Oltre ai vincoli di §34.1-§34.5:
- **Segnali**: `signal` ∈ segnali di `GameEvents` e non in `DENIED_SIGNALS`; ogni chiave di `args` è un nome di argomento di quel segnale; un valore `{gte…}` solo su argomenti numerici.
- **Riferimenti**: `monster_id` e simili in un filtro si controllano **se** l'argomento si chiama `monster_id` (id esistente in `monsters.json` e presente in almeno un pacchetto di un'area); `skill_id` ∈ skill;
  `item` delle ricompense e dei regali esistono; `lane` e simili (stringhe libere di un segnale) non si controllano.
- **Raggiungibilità dei passi** (`01_GDD_M30.md` §41.4): ogni passo con un `done_when` diverso da `ack` ha un controllo dedicato nel validatore **o** nel test dei dati (M30-03):
  `equipment_changed` → l'Armeria iniziale contiene un'arma diversa da quella indossata; `combat_started` → `start.*` e un'area con `requirements.character` = 1; `discipline_changed` → `trainer.learn_gold` = 0
  e un Maestro per ogni `skill_id` elencato; `mail_collected` → `on_enter` con il regalo nello stesso passo o prima.
- **Testi**: `tests/data/test_tutorial_data.gd` controlla che i testi non citino cifre che esistono nei dati (es. «tre nemici» è il `count` del passo: il test lo confronta) e nessun nome di Melvor.
- **Fixture** (`tests/fixtures/data/tutorial/`, anche in `m10/`): 4 passi (uno per tipo di condizione, uno con `on_enter`) e 3 incarichi (evento, misura, con oggetti); casi rifiutati in
  `tests/core/data/test_data_validator_tutorial.gd`: id doppio, gruppo sconosciuto, segnale vietato o sconosciuto, argomento che il segnale non ha, `ack` in un incarico, metrica sconosciuta,
  `gte` mancante, `count` 0, ricompensa con denaro **e** oggetti, ricompensa vuota, oggetto non vendibile, `target` di un'altra pagina, `page` con argomento, ultimo passo non `ack`, testo troppo lungo,
  chiave sconosciuta, `on_enter` con kind diverso da `tutorial_gift`.

## 34.7 Hint e Guida
- `data/hints/hints.json`: **invariato** (l'hint `first_action` resta, inerte: `HintsSystem` non fa scattare nulla finché il tutorial è attivo e `session_started_new` non si ripete, Q190).
- `data/guide/tutorial.json` (M30-03): pagina `guide_tutorial`, sezione `first_steps`, titolo «Tutorial e Primi passi», ≤ 160 parole (`test_guide_texts`); `DataValidatorGuide` invariato salvo l'eventuale
  registrazione della pagina. Il testo non cita numeri che stanno nei dati senza il segnaposto `{balance:…}`.

## 34.8 Estensioni di M31 (V40)
Cinque campi facoltativi nei passi (`progress_text`, `ack_text`, `freeze_combat`, `force_node`, `wound_hp_pct`) e la chiave obbligatoria `final_reward` di `starter_quests.json`: definizione e vincoli in `M31_RITOCCHI_TUTORIAL.md` §2 (estendono §34.1 e §34.3). I passi diventano 22.

## 34.9 Estensioni di M33 (V42)
Campo facoltativo `force_pack` nei passi (`{"area", "monsters"}`), chiave di primo livello `force_pack_max_attack_level` di `steps.json`, `freeze_combat` ammesso su ogni passo senza eventi di combattimento e `skill_id` negli `args` del
passo `nodes`: definizione e vincoli in `M33_TUTORIAL_FORZATO.md` §3.1, §4, §5.2 (estendono §34.1 e `M31_RITOCCHI_TUTORIAL.md` §2.1). I passi restano 22 con gli stessi id.
