# 07. Task, M34: Deposito a pannello fisso e «Salta tutorial»

Estensione di `07_TASKS.md`. Fonte: V43, **`M34_DEPOSITO_E_SALTA.md`**, `05_INTERFACES_M30.md` §5.41 e §7.ab, Q210-Q213. Il design non si riscrive nei brief. `sonnet`; due task in fila, nessun parallelismo; **niente M34-03**.
Lezioni valide (come `07_TASKS_M33.md`): clic vero con `Viewport.push_input` e `InputEventMouseButton` (GutLayer nascosto, modello `tests/ui/test_mail_page_smoke.gd`); `git checkout -B task/<ID> main`; mai `-gtest=`;
screenshot 1280x720 e 1600x900 in cartelle separate, guardati con Read; togliere i `*.uid` non tracciati prima del merge; nessun processo Godot in background; i test esistenti restano verdi senza cambiare i numeri attesi
(golden e `sim_*` invariati); file ≤ 400 righe.

| ID | Titolo | Ruolo | Dim. | Dip. | Accettazione |
|---|---|---|---|---|---|
| M34-01 | CORE: `skip_tutorial()` e test | CORE | S | m33-done | sotto |
| M34-02 | UI: Deposito a pannello fisso; bottone Salta con conferma; screenshot | UI | M | 01 | sotto |

## M34-01: CORE
- **Leggere**: `M34_DEPOSITO_E_SALTA.md` §2-§3; `05_INTERFACES_M30.md` §5.41; `systems/tutorial/tutorial_system.gd` (`_finish_step`, `_release_combat`, `skip_step`, consegna `on_enter`).
- **Ownership**: `systems/tutorial/**`; `core/common/reasons.gd` solo se serve (`TUTORIAL_INACTIVE` esiste: probabilmente no); `tests/systems/tutorial/**`; `tests/integration/test_m34_skip_tutorial.gd` (nuovo).
  **Non toccare**: `ui/**`, `core/save/**` (nessun campo: v12), `event_bus.gd` (nessun segnale), formule, dati.
- **Accettazione**:
  1. `skip_tutorial()` come §5.41: `tutorial_inactive` se completato (nessun effetto); altrimenti `ok`, `is_completed()`, emette `tutorial_completed` una volta, `starter` attivo.
  2. Salto da **ogni passo** (loop su tutti i 22): dopo lo skip `is_frozen`, `force_node`, `force_pack`, `is_guarded` liberi; nessuna pausa residua.
  3. Regali: gli `on_enter` dei passi successivi al corrente sono consegnati in Posta **una sola volta** (anche dopo `to_save`/`from_save` e secondo skip); quelli dei passi precedenti e del corrente non si duplicano; allo skip dall'ultimo passo nessun regalo.
  4. `to_save`/`from_save` dopo lo skip: completato, nessun campo nuovo (le chiavi di `to_save` identiche a prima).
  5. Incarichi «Primi passi» attivi e bonus finale riscuotibile come dopo il completamento normale.
  6. Offline 12 h dopo lo skip uguale a una sessione normale a tutorial completato.
  7. Regressione: i test esistenti del tutorial restano verdi invariati.
- **Test**: nei file di ownership, uno per punto sopra (il punto 2 è un loop sui 22 passi).

## M34-02: UI
- **Leggere**: `M34_DEPOSITO_E_SALTA.md` §1-§4; `05_INTERFACES_M30.md` §7.ab; `ui/pages/bank/bank_page.gd/.tscn`, `bank_item_panel.*`; `ui/screens/tutorial/tutorial_panel.gd`, `tutorial_texts.gd`.
- **Ownership**: `ui/pages/bank/**`; `ui/screens/tutorial/**`; altre pagine (Equipaggiamento, Casa d'Aste, Posta, Fabbro) **solo** se stesso componente o schema identico, senza cambiare comportamento; `tools/shot_*.gd`; `tests/ui/**`.
  **Non toccare**: modelli (`systems/**`, `core/**`).
- **Accettazione**:
  1. Deposito: `ItemPanel` sempre visibile, larghezza fissa; senza selezione mostra «Seleziona un oggetto»; `clear()` torna allo stato vuoto; nessun `visible=false` legato alla selezione.
  2. Selezionando e deselezionando un oggetto dimensione e posizione della griglia **non cambiano** (test con click vero, vedi sotto).
  3. Verificate Equipaggiamento, Casa d'Aste, Posta, Fabbro: corrette solo dove stesso schema; le altre elencate nel report con nome del file e motivo.
  4. Bottone «Salta tutorial» nella card, in ogni passo e nello stato «Vai a <pagina>»; rientra nei limiti 440x240 e non copre il bersaglio.
  5. Conferma con il testo «Vuoi saltare il tutorial? Potrai rivedere la Guida in ogni momento»; «No» annulla senza effetti; «Sì» chiama `skip_tutorial()`; a esito `ok` la card sparisce (nodo liberato, §7.ab regola 7). La UI non tiene stato di gioco.
  6. Screenshot 1280x720 e 1600x900, prima e dopo, in cartelle separate (Deposito vuoto, con selezione, card con Salta e con conferma), **guardati con Read**.
- **Test**: smoke del Deposito (pannello sempre presente, stato vuoto); **click vero** (`Viewport.push_input`, `InputEventMouseButton`, GutLayer nascosto, modello `tests/ui/test_mail_page_smoke.gd`) che seleziona un oggetto e verifica
  dimensione e posizione della griglia invariate; click veri su Salta, conferma «No» e «Sì» (stato finale `is_completed()`). Niente test su testi esatti.
