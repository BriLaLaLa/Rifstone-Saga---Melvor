# 05. Interfacce, M27: Casa d'Aste v2 e monete (§1d, §3e, §4d, §5.38-§5.40, §6e, §7.o)

Estensione di `05_INTERFACES.md` (che supera le 400 righe): **è contratto** con le stesse regole (lo modifica solo il Reviewer; un task che ha bisogno di una firma
nuova si ferma e la chiede). Dove contraddice `05_INTERFACES.md` o `_M24`…`_M26` vale questo file. Design `01_GDD_M27.md` (§39), formule `02_FORMULAS_M27.md`
(F-177…F-184), dati `04_DATA_SCHEMA_M27.md` (§32). Accanto a ogni firma il task che la scrive.

## 1d. Motivi (`core/common/reasons.gd`)
`MAILBOX_FULL` = `&"mailbox_full"` (M27-05); `INVALID_PRICE` = `&"invalid_price"`, `LISTINGS_FULL` = `&"listings_full"` (M27-06). Durata sconosciuta e inserzione o messaggio
sconosciuti → `unknown_id`. Il conteggio di `tests/core/common/test_reasons.gd` sale di 1 (M27-05) e di 2 (M27-06).

## 3e. Segnali (`core/autoload/event_bus.gd`)
```gdscript
signal mail_changed(unread: int, total: int)   # M27-05: dopo ogni consegna, fusione, ritiro (Ritira tutto: una volta), mark_read; mai in new_game/from_save
signal auction_listings_changed()              # M27-06: dopo list_item/cancel_listing e una volta per advance in cui un'inserzione ha venduto, si è chiusa o è scaduta
```
Invariati: `gold_changed` (ora in rame), `auction_sold(item_id, qty, gold)` (Vendi subito: `gold` = ricavo **messo in Posta**, nessun `gold_changed`), `auction_bought`,
`auction_updated(blocks)` (una volta per advance, somma dei blocchi).

## 4d. Dati (`core/data/`)
```gdscript
# M27-02
class_name CurrencyParams extends RefCounted          # core/data/defs/currency_params.gd (§32.1)
var copper_per_silver: int = 100; var silver_per_gold: int = 100
var symbols: Dictionary[StringName, String] = {}; var names: Dictionary[StringName, String] = {}   # chiavi &"gold", &"silver", &"copper"
func copper_per_gold() -> int
# GameData: func currency() -> CurrencyParams
# M27-05
class_name MailTemplateDef extends RefCounted         # core/data/defs/mail_template_def.gd (§32.5)
var kind: StringName; var sender: String; var subject: String; var body: String
# GameData: func mail_templates(kind: StringName) -> Array[MailTemplateDef]   # ordine di file; [] se nessuno
# GameData: balance_value("mail.capacity")
# M27-06
class_name AuctionDuration extends RefCounted         # core/data/defs/auction_duration.gd (§32.4)
var id: StringName; var hours: int; var blocks: int; var deposit_ppm: int
# AuctionParams guadagna: book_persist, book_lo_ppm, book_hi_ppm, book_sellers_per_listing, book_min_listings, book_max_listings, book_fill_ppm, book_fill_max_ppm,
#   listing_max_active, listing_cut_ppm, listing_max_price_ppm: int; durations: Array[AuctionDuration]
# AuctionPopulationBand guadagna: var stack: int = 1
```
Validatori: sezione `currency` di `balance.json` (M27-02); `DataValidatorVillage`/`DataValidatorQuests`: passo di arrotondamento `10 × copper_per_silver` (M27-02);
`DataValidatorAuction` (§32.3-§32.4, M27-06); `DataValidatorMail` nuovo (§32.5, M27-05); `DataValidatorGuide.ROUTES` + `"mail"` (M27-07).

## 5.38 Monete (M27-02; F-177)
```gdscript
class_name Money extends RefCounted                   # core/common/money.gd — logica pura, nessuno stato
static func split(copper: int, p: CurrencyParams) -> Vector3i          # (oro, argento, rame) di |copper|
static func from_parts(gold: int, silver: int, copper: int, p: CurrencyParams) -> int   # parti < 0 → Log.error e 0
static func text(copper: int, p: CurrencyParams) -> String             # F-177: "1g 25s 40c", "0c", "−2s 50c"
```
- **Wallet** (§5.4): firme, segnali e motivi **invariati**; gli importi sono in **rame**. `to_save()` → `{"copper": int}`; `from_save(d)` legge `copper` (assente, non intero o negativo →
  `Log.warn` e 0); una chiave `gold` in un save v11 è ignorata con `Log.warn`. `new_game` = `start.gold` (già convertito).
- **Nomi**: `gold` negli identificatori (dati, `get_gold`, `add_gold`, `gold_changed`, `not_enough_gold`, `ShopEntryDef`, `cost.gold`, `gold_drop_pct`) = denaro in rame (Q167).
  Nessuna rinomina in M27.
- `core/guide/` (tabelle della Guida) e la UI formattano il denaro **solo** con `Money.text` o con `MoneyLabel` (§7.o); nessuna divisione per 100 sparsa nel codice.

## 5.39 Casa d'Aste v2 (M27-06; sostituisce in parte §5.30 e §5.37) — `systems/auction/`
**Confine (V15 esteso)**: `AuctionMath` la usano solo `AuctionPricing` e `AuctionBook`; `AuctionBook` (funzioni pure del libro) la usano `AuctionPricing` e `AuctionListings`;
`AuctionHouse` usa solo i metodi pubblici di `AuctionPricing` e `AuctionListings`; la UI usa solo `AuctionHouse`.
```gdscript
class_name AuctionBook extends RefCounted             # systems/auction/auction_book.gd — logica pura, interi
static func listing_count(sellers: int, p: AuctionParams) -> int                          # F-178: K
static func ask_offset(item_id: StringName, seed_value: int, epoch: int, j: int, p: AuctionParams) -> int   # F-178: off_j (ppm)
static func ask_qty(item_id: StringName, seed_value: int, epoch: int, j: int, stack: int) -> int             # F-178: q_j
static func ask_price(value: int, index_ppm: int, offset_ppm: int) -> int                 # F-178: max(1, v·idx·(PPM+off) ÷ PPM²)
static func demand(volume: int, buyers: int, sellers: int, p: AuctionParams) -> int       # F-179: D
static func fill(demand: int, ahead: int, remaining: int) -> int                          # F-179: clamp(D − ahead, 0, r)
static func deposit(value: int, qty: int, deposit_ppm: int) -> int                        # F-180
static func cut(gross: int, p: AuctionParams) -> int                                      # F-180: ceil_div(gross·CUT, PPM)

# AuctionPricing (aggiunte; firme di §5.30/§5.37 invariate)
func block() -> int; func pending_ms() -> int
func ms_to_next_block() -> int                         # block_ms − pending_ms (1…block_ms)
func npc_asks(item_id: StringName) -> Array[Vector2i]  # F-178 al blocco corrente con la sat corrente: (prezzo, quantità) in ordine; [] se non in elenco
func demand(item_id: StringName) -> int                # F-179 al blocco corrente; 0 se non in elenco
func value_of(item_id: StringName) -> int              # value in rame (0 se non in elenco)

class_name AuctionListings extends RefCounted          # systems/auction/auction_listings.gd — stato delle inserzioni del giocatore
func _init(params: AuctionParams) -> void
func all() -> Array[Dictionary]       # copie, id crescente: {"id","item","qty","sold","earned","price","duration","start","end"} (qty = rimasti)
func of_item(item_id: StringName) -> Array[Dictionary]  # attive sull'oggetto, ordine (price, id)
func get_listing(listing_id: int) -> Dictionary        # {} se assente
func count() -> int
func add(item_id: StringName, qty: int, price: int, duration: AuctionDuration, start_block: int) -> int   # id nuovo (contatore)
func remove(listing_id: int) -> Dictionary             # l'inserzione tolta ({} se assente)
func ahead_of(listing_id: int, npc: Array[Vector2i]) -> int   # F-179 sul libro dato e sulle inserzioni attive dello stesso oggetto
func process_block(pricing: AuctionPricing, block: int) -> Array[Dictionary]
    # F-180 passi 2-4 e 6 al blocco `block` (pricing già avanzato): vendite, commissione, record_sale per oggetto, scadenze.
    # Eventi in ordine: {"kind": &"sold", "id", "item", "qty", "price", "net"} per inserzione (id crescente), poi {"kind": &"closed"|&"expired", "id", "item", "qty" (rimasti)}
func to_save() -> Dictionary; func from_save(d: Dictionary) -> void
```
```gdscript
# AuctionHouse (aggiunte e cambi; dipendenza nuova: mail, letta pigra da session.mail)
func market_price(item_id: StringName) -> int          # F-181 = sell_quote(id, 1)
func suggested_price(item_id: StringName) -> int       # F-181; 0 se non in elenco
func book(item_id: StringName) -> Array[Dictionary]    # F-181: [{"price": int, "qty": int, "mine": bool, "listing": int (0 se PNG)}] in ordine
func population(item_id: StringName) -> Dictionary     # §5.37 + "listings": int, "units": int (F-181)
func durations() -> Array[AuctionDuration]
func max_price(item_id: StringName) -> int; func listing_deposit(item_id: StringName, qty: int, duration_id: StringName) -> int
func listing_net(item_id: StringName, qty: int, price: int) -> int    # qty·price − cut (ricavo se si vende tutto, prima del deposito)
func my_listings() -> Array[Dictionary]
    # [{"id","item","qty","sold","earned","price","duration","ends_in_ms","status": &"selling"|&"undercut"}] in ordine di id (F-181)
func max_listings() -> int
func can_list(item_id: StringName, qty: int, price: int, duration_id: StringName) -> CommandResult
    # in ordine: invalid_amount (qty ≤ 0), unknown_id (oggetto o durata), not_tradable, requirement_not_met (level 0), item_locked, not_enough_items,
    #            invalid_price (price < 1 o > max_price), listings_full, mailbox_full, not_enough_gold (deposito)
func list_item(item_id: StringName, qty: int, price: int, duration_id: StringName) -> CommandResult
    # stessi controlli; poi bank.remove, wallet.spend(deposito), listings.add(…, block), auction_listings_changed
func can_cancel(listing_id: int) -> CommandResult      # unknown_id
func cancel_listing(listing_id: int) -> CommandResult  # listings.remove, mail.post(auction_cancelled, oggetti), auction_listings_changed
func can_sell(item_id: StringName, qty: int) -> CommandResult   # CAMBIATA: dopo not_sellable anche mailbox_full
func sell(item_id: StringName, qty: int) -> CommandResult       # CAMBIATA: bank.remove, mail.post(auction_sale, money = sell_quote), record_sale, auction_sold
func advance(delta_ms: int) -> void                             # CAMBIATA: F-184 (a pezzi fino ai confini di blocco se ci sono inserzioni attive)
```
- `advance`: senza inserzioni come oggi. Con inserzioni: `while delta > 0`: `step = min(delta, pricing.ms_to_next_block())`; `pricing.advance(step)`; se è passato un blocco →
  `events = listings.process_block(pricing, pricing.block())` e per ogni evento `sold` → `mail.post(&"auction_sold", …)`, `expired` → `mail.post(&"auction_expired", …)`; alla fine
  `auction_updated(blocchi totali)` se > 0 e `auction_listings_changed()` se c'è stato almeno un evento. Quando non restano inserzioni attive il resto del `delta` passa in un colpo.
- **Atomicità**: `list_item` non fallisce dopo `can_list` ok (oggetti tolti, deposito speso, inserzione creata insieme). Nessun tiro dell'`RngService`.
- **Save** (§6e): `modules.auction` guadagna `"listings": [...]` e `"next_listing": int` (additivi). `from_save` tollerante (`Log.warn`): inserzione con oggetto sconosciuto o non in elenco,
  id doppio o < 1, `qty < 1`, `sold`/`earned` < 0, `price < 1`, `start < 0` o `end ≤ start` → scartata; `duration` sconosciuta → la prima durata dei dati; `next_listing` ≤ id massimo → id massimo + 1.
- **File** < 400 righe: `auction_house.gd` (oggi 177) non deve superare ~330; il ciclo dei blocchi sta in `AuctionListings`.

## 5.40 Posta (M27-05; F-183) — `systems/mail/` — dipendenze: data, events, wallet, bank
```gdscript
class_name MailBox extends RefCounted                 # systems/mail/mail_box.gd
const SAVE_KEY := &"mail"
const KINDS: Array[StringName] = [&"auction_sold", &"auction_sale", &"auction_expired", &"auction_cancelled"]
func _init(session: GameSession) -> void
func messages() -> Array[Dictionary]
    # copie, id decrescente: {"id": int, "kind": StringName, "item": StringName, "qty": int, "price": int, "listing": int, "money": int, "items": Array[Dictionary], "read": bool}
func get_message(message_id: int) -> Dictionary        # {} se assente
func count() -> int; func unread() -> int; func capacity() -> int
func is_full() -> bool                                 # count() ≥ capacity()
func post(kind: StringName, fields: Dictionary) -> int
    # F-183: fields = {"item", "qty", "price"?, "listing"?, "money"? | "items"?}; fonde se possibile; restituisce l'id del messaggio; consegna SEMPRE (la capienza la controllano i comandi)
    # kind sconosciuto, money < 0 o money e items insieme → push_error e 0
func mark_read(message_id: int) -> CommandResult       # unknown_id
func can_collect(message_id: int) -> CommandResult     # unknown_id, bank_full
func collect(message_id: int) -> CommandResult         # denaro → wallet.add_gold, oggetti → bank.add, messaggio tolto
func collect_all() -> int                              # F-183: quanti ritirati
func new_game() -> void; func to_save() -> Dictionary; func from_save(d: Dictionary) -> void
```
- **Sessione** (M27-05): `var mail: MailBox`, creata **prima** di `auction` (dopo `bank` e `wallet`); `_join(MailBox.SAVE_KEY, mail.new_game, mail.to_save, mail.from_save)`; nessuna fase di
  `advance`. `MAX_SESSION_LINES` di `tests/core/session/test_game_session.gd` da 243 a **246**.
- **Offline** (M27-05): `SessionSnapshot` registra `mail_unread`; `OfflineSummary` guadagna `mail_new: int` (= non letti dopo − prima, ≥ 0). La riga del riepilogo la mostra M27-07.
- `from_save` tollerante: messaggio con `kind` sconosciuto, id doppio o < 1, `money < 0`, oggetti sconosciuti o `qty < 1`, denaro e oggetti insieme → scartato con `Log.warn`; `next_id` ≤ id
  massimo → id massimo + 1. `to_save`: `{"next_id": int, "messages": [...]}` in ordine di id crescente.

## 6e. Salvataggio v11 (M27-02 migrazione; M27-05 e M27-06 additivi)
```json
"wallet": {"copper": 125000},
"auction": {"seed": 918274, "block": 1440, "pending_ms": 120000, "items": {"redbirch_grip": {"sat": 40000}},
            "listings": [{"id": 3, "item": "redbirch_grip", "qty": 400, "sold": 200, "earned": 47500, "price": 250, "duration": "short", "start": 1439, "end": 1583}],
            "next_listing": 4},
"mail": {"next_id": 8, "messages": [{"id": 7, "kind": "auction_sold", "item": "redbirch_grip", "qty": 200, "price": 250, "listing": 3, "money": 47500, "items": [], "read": false}]}
```
- **`core/save/migrations/migration_10_to_11.gd`** (`static func migrate(d) -> Dictionary`, copia profonda; nessuna lettura dei dati): costante storica **`V11_COPPER_PER_GOLD: int = 100`**.
  In `modules.wallet`: `gold` intero ≥ 0 (o float intero) → `copper = gold × 100` e `gold` tolta; `gold` non valida → `gold` tolta (il caricamento dà 0 con `Log.warn`); `wallet` assente → invariato.
  Nient'altro cambia. `SaveMigrator.CURRENT_VERSION` = **11**; catena v5…v10 → v11.
- `listings`/`next_listing` e `mail` sono **additivi** (assenti = nessuna inserzione, casella vuota): li scrivono M27-06 e M27-05 senza cambiare la versione.
- Test: `tests/core/save/test_migration_10_to_11.gd` (esempi di F-177; altri moduli identici; catena v9 → v11 con gli schemi di v10 e il portafoglio); `test_save_migrator.gd` con 11;
  **slot v10 reale** `tests/fixtures/saves/slot_v10.json` (scritto da una sessione vera **prima** dei cambi di M27-02) caricato senza perdite: portafoglio ×100, il resto uguale.

## 7.o UI di M27 (nessuno stato di gioco nella UI; `01_GDD_M27.md` §39.8)
- **M27-04 (monete)**: `ui/components/money/money_label.gd` (`class_name MoneyLabel extends HBoxContainer`, `set_amount(copper: int, params: CurrencyParams)`: per ogni parte non zero un
  numero e un'icona a moneta colorata; zero = "0" e la moneta di rame); icone `assets/icons/ui/coin_gold.svg`, `coin_silver.svg`, `coin_copper.svg` (originali, o `coins.svg` tinta) e colori
  `UiStyle.GOLD`, `UiStyle.SILVER`, `UiStyle.COPPER`. Ogni punto della UI che mostra denaro usa `MoneyLabel` (o `Money.text` nei testi composti): barra in alto, Shop, Mercante,
  Maestri, Villaggio, Bacheca, raffinazione e attrezzi, Deposito e tooltip (valore), Combattimento, riepilogo offline, Guida (`core/guide/`), Casa d'Aste (solo formato). Le parole "oro"
  usate per il denaro diventano "monete" nei testi (`*_texts.gd`).
- **M27-07 (Posta)**: `ui/pages/mail/mail_page.gd` (+ `.tscn`), `mail_row.gd`, `mail_texts.gd` (composizione del testo dai modelli: segnaposto sostituiti, `{price}` e `{money}` con
  `Money.text`); rotta `&"mail"` in `page_host.gd`; voce "Posta" nella barra laterale (gruppo Villaggio, icona `mail` del set Tabler) con il contatore dei non letti (`mail_changed`);
  aprire un messaggio = `mark_read`; **Ritira** (motivo accanto se `can_collect` fallisce), **Ritira tutto**; riga del riepilogo offline "n messaggi nuovi nella Posta".
- **M27-08 (Casa d'Aste)**: `auction_detail.gd` mostra il **libro** (`book`, proprie inserzioni evidenziate) e il riepilogo (`population`: compratori, venditori, domanda, pezzi e
  inserzioni); pannello di vendita con **Vendi subito** (come oggi, "il ricavo arriva in Posta") e **Metti in vendita** (quantità, prezzo con tre campi o/a/r ricomposti da
  `Money.from_parts` e precompilati col suggerito, durata da `durations()`, deposito `listing_deposit`, ricavo `listing_net`, motivo da `can_list`); scheda **Le mie inserzioni**
  (`my_listings`: oggetto, venduti/totale, prezzo, tempo rimasto, stato, **Annulla** con `can_cancel`). Redraw anche su `auction_listings_changed` e `mail_changed`.
- **Test della UI** (lezione (a)): ogni comando nuovo ha un test con **clic vero** (`Viewport.push_input` con `InputEventMouseButton` premuto e rilasciato sul centro del controllo):
  Posta (riga, Ritira, Ritira tutto), Casa d'Aste (categoria dell'albero, oggetto, Metti in vendita, Annulla), barra laterale (voce Posta). Un solo smoke test per pagina; nessun
  test su testi esatti; screenshot a 1280×720 e 1600×900 in cartelle separate, guardati davvero.
