# M34: Deposito a pannello fisso e «Salta tutorial»

Fonte: V43 (`DECISIONS_LOG.md`), Q210-Q213. Contratto: `05_INTERFACES_M30.md` §5.41 (`skip_tutorial`) e §7.ab (bottone e conferma). Task: `07_TASKS_M34.md`.

## 1. Obiettivo
1. **Deposito**: il pannello di dettaglio (`ui/pages/bank/bank_item_panel.*`, istanza `ItemPanel` in `bank_page.tscn`) è oggi `visible=false` senza selezione e `clear()` lo nasconde: alla selezione compare e la griglia si ridimensiona.
   Voluto: pannello **sempre presente**, larghezza fissa, con stato vuoto «Seleziona un oggetto»; la griglia non cambia mai dimensione né posizione.
2. **Salta tutorial**: pulsante nella card del tutorial, visibile in ogni passo (anche «Vai a <pagina>»), con conferma «Vuoi saltare il tutorial? Potrai rivedere la Guida in ogni momento».

## 2. Scelte
- **Deposito**: nessuna logica nuova, solo la UI. Il pannello ha larghezza minima fissa (la stessa del pannello aperto oggi, letta dalla scena, non un numero di design); `clear()` mostra lo stato vuoto invece di nascondere.
  Si cerca lo stesso schema in Equipaggiamento, Casa d'Aste, Posta, Fabbro: si corregge **solo** dove il componente è lo stesso o lo schema è identico (pannello `visible` legato alla selezione) e senza cambiare il comportamento;
  il resto si segnala nel report di M34-02 (non si corregge).
- **Skip**: `TutorialSystem.skip_tutorial() -> CommandResult`. Fallisce con `tutorial_inactive` se già completato. Altrimenti completa dallo stato attuale con la **stessa fine** dell'ultimo passo (`_finish_step`):
  `_completed`, `_release_combat()` (pausa, gruppi e nodo forzati spenti), `tutorial_completed` (esistente), `starter.activate(false)`. In più consegna in Posta gli `on_enter` dei passi **successivi** al corrente
  (il corrente li ha già avuti), una sola volta, nell'ordine dei passi: chi salta non perde soldi/cibo iniziali. Incarichi «Primi passi» e bonus finale: come per chi completa.
- **Save**: **nessun campo nuovo, save v12 invariato** (`completed = true` basta; la tolleranza di `from_save` già tratta il passo assente come completato). **Nessun nuovo segnale** (si riusa `tutorial_completed`). Nessuna nuova pagina di Guida.

## 3. Casi limite
- Skip all'ultimo passo: nessun regalo successivo, fine identica al completamento normale.
- Skip con pausa forzata, gruppo forzato o nodo forzato in corso: tutto liberato (`is_frozen`, `force_node`, `force_pack`, `is_guarded` falsi); il combattimento riparte.
- Skip a tutorial già completato: `tutorial_inactive`, nessun effetto, nessun regalo doppio.
- Salvataggio subito dopo lo skip e ricarica: completato, nessun regalo ripetuto (la Posta è nel save).
- Posta piena: la consegna avviene comunque (§5.40).
- Doppio clic sul sì: il secondo fallisce con `tutorial_inactive`, la UI lo ignora.
- Offline 12 h dopo lo skip: uguale a una sessione normale a tutorial completato.

## 4. Rischi
- Il pannello fisso occupa spazio anche a Deposito vuoto: a 1280x720 la griglia deve restare usabile (screenshot prima/dopo).
- La card ha già altezza massima 240 px (§7.ab regola 4): il bottone non deve far uscire la card dai limiti né coprire il bersaglio.
- `bank_page` e `bank_item_panel` vicini a 400 righe: se servono più righe, file nuovo.
