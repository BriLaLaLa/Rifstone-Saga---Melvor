# 08. Team dei sub-agenti

L'**Orchestratore** (agente principale) legge `07_TASKS.md`, assegna i task ai ruoli qui sotto rispettando le dipendenze,
lancia in parallelo solo i task marcati "Parallelizzabile: sì" con ownership disgiunte, e passa ogni report al
Reviewer/Integrator. Ogni ruolo ha un file agente in `.claude/agents/`.

## 1. Ruoli

| Ruolo (file agente) | Responsabilità | Cartelle di proprietà | NON tocca | Input | Output |
|---|---|---|---|---|---|
| **Core Systems Dev** (`core-systems-dev.md`) | autoload, dati, modificatori, sessione, salvataggio, offline, sistemi non di combattimento (wallet, bank, skill, maestria, azioni, equipaggiamento, Altare, suggerimenti, fratture) | `res://core/**`, `res://systems/**` esclusa `systems/combat/` e `systems/shop/`, i test speculari in `res://tests/core/**`, `res://tests/systems/**`, `res://tests/helpers/test_factory.gd`, `res://tests/fixtures/data/**` (M1-04) | `ui/`, `data/` (contenuti), `systems/combat/`, `addons/`, `docs/` | task, `01`-`05`, `09` | codice + test unitari + report |
| **Combat Dev** (`combat-dev.md`) | formule e motore del combattimento, statistiche dei combattenti, cibo automatico, borsa del bottino | `res://systems/combat/**`, `res://tests/systems/combat/**` | tutto il resto; in `game_session.gd` solo la riga di registrazione | task, `01` §10, `02` §5, `05` §5.10 | codice + test + report |
| **Data/Content Designer** (`data-content-designer.md`) | contenuti JSON (skill, oggetti, azioni, nodi, mostri, shop, suggerimenti, fratture), nomi e testi originali, icone segnaposto, bilanciamento secondo `02_FORMULAS.md` | `res://data/**`, `res://assets/icons/items/**`, `icons/skills/**`, `icons/monsters/**`, `res://tests/data/test_data_validity.gd`, `test_config_files.gd` | codice (`.gd`) di qualunque tipo, `ui/`, `docs/` | task, `00`, `02` §8-11, `04` | JSON validi + test dei dati + elenco dei nomi nel report |
| **UI Dev** (`ui-dev.md`) | scene e script UI, componenti, pagine, feedback visivo | `res://ui/**` (escluse le parti assegnate al Porting Engineer nei task), `res://tests/ui/**` | `core/`, `systems/`, `data/`; mai stato di gioco nella UI | task, `01`, `03` §11, `05` §3, §7, `09` §2-3 | scene + script + smoke test + report (con foto se possibile) |
| **Porting Engineer** (`porting-engineer.md`) | unico ruolo che legge `../RIFTSTONE SAGA/`; copia e adatta i moduli dei task di porting | i file di destinazione indicati nei task di porting (M0-02, M0-04, M1-16, M1-17, M3-02, M6-03) | `../RIFTSTONE SAGA/` in scrittura (mai), file non elencati nel task | task, `03` §13, il file sorgente | file portati + test + tabella "cosa ho cambiato" nel report |
| **QA/Test Engineer** (`qa-test-engineer.md`) | test di integrazione, copertura delle stat, prestazioni, strumenti di controllo, foto della UI | `res://tests/integration/**`, `res://tests/data/test_stat_registry_coverage.gd`, `res://tests/tools/**`, `res://tools/**` (esclusi `build_ui_theme.gd` del Porting Engineer e `validate_data.gd` del Core Systems Dev), `res://tests/helpers/gut_pre_run.gd` (dopo M0-02) | codice di produzione (se un test trova un bug: report, non correzione) | task, `02`, `03` §12, `05` §8 | test + report dei bug trovati |
| **Reviewer/Integrator** (`reviewer-integrator.md`) | revisione, merge su `main`, tag di milestone, unico che modifica `docs/05_INTERFACES.md` e gli altri documenti, unico che risolve conflitti, setup del progetto (M0-01), rilascio (M6-08) | `main`, `res://docs/**`, `res://CLAUDE.md`, `res://.claude/**`, `res://project.godot` (fuori dalle sezioni assegnate ai task), `res://export_presets.cfg` | codice di produzione salvo correzioni minime di merge, segnalate | report dei task, diff | merge, report di milestone, aggiornamenti dei documenti |

## 2. Ownership dei file
- Un file ha **un** proprietario per task: il task che lo elenca in "Ownership". Due task in parallelo non hanno mai file in
  comune; l'Orchestratore controlla prima di lanciarli.
- Eccezioni dichiarate nei task (es. `game_session.gd` "solo registrazione", `bank_item_panel.gd` per sezioni): il secondo
  task che chiude fa rebase su `main` e risolve; se il conflitto non è banale lo risolve il Reviewer.
- Se serve cambiare un file non posseduto: **fermarsi**, scrivere nel report "Richiesta di modifica" (file, motivo, diff
  proposto). L'Orchestratore crea un task o lo passa al proprietario.

## 3. Branch e worktree
- Un branch e un worktree per task, creati dal `main` aggiornato:
  ```bash
  git -C "C:/Users/Davide/Desktop/AI/RIFTSTONE SAGA - Melvor" worktree add "C:/Users/Davide/Desktop/AI/RSI-worktrees/<ID>" -b task/<ID> main
  ```
  (cartella `RSI-worktrees` accanto al progetto; mai dentro `../RIFTSTONE SAGA/`). Nel worktree, prima di tutto:
  `godot --headless --path . --import` (cache `.godot/` propria).
- Commit piccoli con il formato di `09_CONVENTIONS.md` §7, con l'id del task. Nessun push forzato, nessun rebase di `main`.
- "Dipendenza soddisfatta" = il task dipendente è **mergiato su `main`**. Il Reviewer mergia ogni task appena approvato
  (integrazione continua); i task REV di fine milestone sono punti di controllo con tag.
- A fine task il worktree si rimuove dopo il merge (`git worktree remove`).

## 4. Regole fisse
1. `05_INTERFACES.md` lo cambia solo il Reviewer/Integrator. Un task che ha bisogno di un metodo o segnale nuovo si ferma
   e lo chiede nel report.
2. `../RIFTSTONE SAGA/` è in **sola lettura** e la legge **solo** il Porting Engineer. Nessun file del nuovo progetto
   contiene percorsi verso quella cartella (`tools/check_forbidden_refs.gd` lo controlla).
3. Contenuti originali: nessun nome, testo, codice, asset o tabella copiati da Melvor Idle.
4. Le Lezioni da RiftStone (`CLAUDE.md`) sono vincoli: un task che le viola non passa la revisione.
5. Nessun lancio del gioco su uno slot vero durante lo sviluppo automatico: si usano la `TestFactory` e
   `user://test_saves`.

## 5. Definition of Done
Un task è finito quando **tutto** questo è vero:
- [ ] criteri di accettazione del task soddisfatti e verificati;
- [ ] test richiesti scritti e verdi; `tools/run_checks.ps1` verde nel worktree;
- [ ] firme e segnali identici a `05_INTERFACES.md`; nessun metodo pubblico non documentato;
- [ ] toccati solo i file in Ownership;
- [ ] static typing su variabili, parametri e ritorni; nessun `print` (solo `Log`); nessun `get_node("/root/...")` fuori dagli autoload;
- [ ] **Lezioni da RiftStone**: nessuna classe con più responsabilità; nessuno stato di gioco nella UI né fuori dallo slot;
      nessuna scrittura senza slot; ogni stat usata è nel registro e ha effetto e test; modificatori solo da `ModifierService`;
      nessun numero di design nel codice; ogni file ≤ 400 righe;
- [ ] nessun riferimento a `../RIFTSTONE SAGA/`; contenuti originali;
- [ ] report di fine task consegnato nel formato del §6.

## 6. Formato del report di fine task
```markdown
## Report <ID> · <titolo>
**Esito**: completato | bloccato | parziale
**Branch**: task/<ID> · **Commit**: <hash brevi>
### File toccati
| File | Azione (creato/modificato/eliminato) | Righe |
### Criteri di accettazione
- [x] <criterio> — come l'ho verificato
### Test
- comando: tools/run_checks.ps1 → esito (n test, n passati, n pending)
- test nuovi: <elenco>
### Lezioni da RiftStone
- <una riga per lezione: rispettata / non applicabile, con il motivo>
### Porting (solo Porting Engineer)
| Sorgente | Destinazione | Cosa ho cambiato |
### Nomi e testi nuovi (solo Data/Content Designer)
- <id> → "<nome>"
### Richieste di modifica (file non posseduti / interfacce)
- <file o firma> — motivo — proposta
### Note per il task successivo
- <cose da sapere>
```

## 7. Flusso dell'Orchestratore
1. Prendere i task con dipendenze tutte su `main` e ownership disgiunte; massimo 3 in parallelo.
2. Per ogni task: creare il worktree, lanciare il sub-agente del ruolo con il testo del task (copiato da `07_TASKS.md`).
3. Ricevuto il report: se "completato", passarlo al Reviewer; se "bloccato", leggere le richieste e decidere (nuovo task,
   richiesta al Reviewer per `05_INTERFACES.md`, domanda all'utente).
4. Dopo il merge: rimuovere il worktree, aggiornare lo stato del task (nel report di milestone del Reviewer).
5. A fine milestone: task REV, poi la milestone successiva. Domande di design aperte → `OPEN_QUESTIONS.md` e all'utente.
