# Checklist di rilascio MVP (M9-08)

Data: 2026-11-07. Base: `main` dopo i merge M9-00..M9-07 e le correzioni di M9-08.

## 1. Controlli automatici
| Controllo | Esito |
|---|---|
| `tools/run_checks.ps1` | OK: 135 script, 1627 test, 1627 verdi, 38034 asserzioni |
| `validate_data.gd` (fixture e dati veri) | OK |
| `check_file_sizes.gd` | OK: 215 file, massimo 400 righe (i piu lunghi: `combat_engine.gd` 399, `armory.gd` 397) |
| `check_forbidden_refs.gd` | OK: 1279 file, nessun riferimento a `../RIFTSTONE SAGA/` |
| Esportazione Windows (`export_presets.cfg`, preset "Windows Desktop", senza firma) | OK: `export/RiftStoneSaga.exe` (98 MB, pck incorporato). Avvio headless con `--quit-after`: nessun errore dopo la correzione sotto |

Problemi trovati e corretti in M9-08:
- Prima run_checks: 3 test rossi, tutti test/doc non allineati a decisioni gia prese: `inf_scholar` +6 e `inf_deep_roots` +10
  (decisione utente M8, `DECISIONS_LOG.md`) nei test di `test_riftbinding_flow.gd` e nella tabella di `02_FORMULAS.md`; i suggerimenti
  reali sono 6 (M9-05) in `test_data_validator_hints.gd`.
- **Bloccante dell'eseguibile**: il validatore controllava le icone di mostri e classi con `FileAccess.file_exists`; nell'export gli
  svg esistono solo come remap di importazione, quindi i dati risultavano non validi (17 errori) e la partita non partiva. Corretto
  con `ResourceLoader.exists` in `core/data/data_validator_classes.gd` (due righe). Verificato: l'eseguibile esportato carica i dati senza errori.

## 2. Lezioni di CLAUDE.md
| Lezione | Esito | Evidenza |
|---|---|---|
| Niente god object | OK | `GameSession` 192 righe e `Game` 242 righe, solo composizione; nessun file oltre 400 righe; un modulo per dominio in `core/` e `systems/` |
| Unica fonte di verita | OK | la UI legge dal modello (`Bank`, `Equipment`, `Armory`, `RiftAltar`); le carte dei suggerimenti chiamano `HintsSystem.mark_seen` sul modello; `OfflineSummaryView` legge solo `OfflineSummary` |
| Nessuna stat decorativa | OK | `tests/data/test_stat_registry_coverage.gd`; `test_every_infusion_effect_reaches_its_formula`; le stat sono in `data/config/stats.json` |
| Stato del giocatore per slot | OK | `hints.seen`, stance, cibo, azione, Altare nel save dello slot; fuori dallo slot solo `GameSettings` (`user://settings.cfg`); nessun altro `user://` fuori da `save_service` e `core/settings` (grep) |
| Nessun salvataggio prima dello slot | OK | `Game.save_now` ritorna `slot_not_selected` senza sessione; il menu non scrive nulla (`main_menu.gd`, test `test_invalid_name_rejected_with_message_and_no_file`) |
| Un solo `ModifierService` | OK | unica classe `core/modifiers/modifier_service.gd`; sorgenti `rift_socket:<i>`, equip, maestria, tratti passano da li |
| Parametri con unica definizione | OK | `balance.json`, `stats.json`, `data/`; `test_data_validity.gd` e `validate_data.gd`; `offline.chunk_ms` e `offline.min_ms` letti da `balance_value` |
| File sotto 400 righe | OK | `check_file_sizes.gd`: 215 file, massimo 400 |
| Clean room (nomi/testi originali) | OK per quanto verificabile | `check_forbidden_refs`; nessun nome di Melvor nei dati rivisti nelle milestone |

## 3. Criteri dell'MVP (`06_ROADMAP.md`)
Automatici: offline fino a 12 h con prestazioni misurate da `test_offline_performance.gd` (M9-07), riepilogo, suggerimenti, impostazioni.
Da provare a mano (nessuna sessione grafica in questo ambiente): vedi sezione 4.

## 4. Prove manuali consigliate (da M8 e M9)
1. **Offline**: giocare un po', chiudere, portare indietro `saved_at` nel file dello slot (per esempio 2 h, poi 20 h per il tetto a 12 h),
   riaprire con Continua: barra di avanzamento "Mentre eri via..." solo oltre `offline.min_ms`, riepilogo con XP/livelli,
   oggetti, combattimento, Armeria (conservati, smantellati, persi), interruzioni con tempo; con tempo sotto la soglia nessuna schermata.
2. **Schede del pezzo** (M9-00): pannello del pezzo a schede (dettagli, castoni, raffinazione), pietre inattive in grigio dopo un calo della raffinazione, valute (anteprima, rifiuti, conferma del reroll).
3. **Altare del Rift**: 5 prese, sblocchi 1/20/40/60/80, Incastona, **Togli con conferma**, bonus attivi; Incastona dalla bank (non sceglie la presa: follow-up).
4. **Impostazioni in partita con Esc**: apre `SettingsPanel` con "Salva ed esci"; modalita finestra, dimensione, scala, VSync, FPS, volume, log; Applica; riaprire il gioco e controllare che i valori restino.
5. **Suggerimenti**: nuova partita (primo passo), banca piena, primo frammento, nodo di maestria acquistabile, morte, livello 10; ognuno una sola volta per slot, coda con "Altri suggerimenti in attesa", non compaiono sopra le schermate bloccanti.
6. **Armeria**: Raffina (costi e probabilita, esito, Sigillo), Smantella con conferma, filtro automatico per slot, "Nome +N".
7. **Combattimento**: carta della Pietra, testi volanti (max 3 per carta), toast (limite in coda `TOAST_PENDING_MAX` = 6).
8. **Layout** a 1600x900 e 1280x720 su tutte le pagine; scala automatica dell'interfaccia.
9. **Eseguibile esportato** (`export/RiftStoneSaga.exe`): menu, nuova partita, salvataggio, chiusura e Continua.

## 5. Limiti noti (non bloccanti)
- Eseguibile non firmato (SmartScreen avvisera); nessuna icona di applicazione impostata nel preset (`application/icon` vuoto).
- Follow-up gia annotati in `STATUS.md`: getter del livello di sblocco in `RiftAltar`; Incastona dalla bank senza scelta della presa; `CombatantStats.for_player` non in `05_INTERFACES.md`; pietre incastonabili tra i drop; bilanciamento dei pezzi rari/ora in Bosco.
- Decisioni aperte: Q26, Q27-Q43 (default in `OPEN_QUESTIONS.md`).
