# Registro delle decisioni

Ogni decisione presa durante lo sviluppo (risposte alle open question, deviazioni dai documenti), con data e motivazione.
Lo aggiorna l'Orchestratore.

| Data | Rif. | Decisione | Motivazione | Deciso da |
|---|---|---|---|---|
| 2026-11-02 | Q1 | La sottocartella `rifstone-saga---melvor/` si elimina se contiene solo il progetto vuoto creato dall'editor; prima dell'eliminazione se ne mostra il contenuto all'utente. Contenuto mostrato (project.godot vuoto, icon.svg, config dell'editor, cache .godot/) ed eliminazione confermata il 2026-11-02. | Il progetto vive nella root (`res://` = root); la sottocartella è un duplicato vuoto. | Utente |
| 2026-11-02 | Q2 | Si resta su Godot 4.5 per tutto l'MVP. | Stabilità della toolchain; GUT 9.5.0 già verificato su 4.5. | Utente |
| 2026-11-02 | Q6 | Nessuna munizione e nessuna runa nell'MVP: i tre stili usano solo l'arma. | Conferma del default di `OPEN_QUESTIONS.md`. | Utente |
| 2026-11-02 | Q15 | Il bilanciamento (razioni da campo, prezzi dello shop, mostri) si rivede dopo la prova di gioco a fine M4; fino ad allora valgono i valori di `02_FORMULAS.md`. | Servono dati di gioco reali prima di ritoccare i numeri. | Utente |
| 2026-11-02 | Setup | `git init` (branch `main`) e primo commit con `docs/`, `CLAUDE.md`, `.claude/` e un `.gitignore` minimo fatti dall'Orchestratore prima di M0-01. M0-01 completa `.gitignore`, `.gitattributes` e il resto. | I worktree dei task richiedono almeno un commit. | Orchestratore (su istruzione dell'utente) |
| 2026-11-02 | Processo | I worktree si creano a mano con `git worktree add` in `C:/Users/Davide/Desktop/AI/RSI-worktrees/<ID>` sul branch `task/<ID>` (`08_TEAM.md` §3); massimo 3 sub-agenti in parallelo. | Nomi dei branch e posizione dei worktree come da `08_TEAM.md`; limite di 3 indicato dall'utente (più stretto del 4 di `08_TEAM.md` §7). | Utente / Orchestratore |
| 2026-11-02 | M0-01 | Criterio di accettazione `godot --headless --path . --quit` sostituito da `godot --headless --editor --path . --quit` (esce con 0); il criterio `--quit` passa a M0-06, quando esiste la scena principale. | Contraddizione interna al task: senza scena principale `--quit` esce con 1 ("no main scene defined"), ma il task vieta la scena principale. Dettaglio tecnico, nessun impatto sul design. | Orchestratore |
| 2026-11-02 | M0-01 | La sottocartella `rifstone-saga---melvor/` è stata svuotata; la cartella vuota non si rimuove (bloccata da un processo, cartella di avvio della sessione). Resta vuota e non tracciata; va rimossa a mano a sessione chiusa. Non blocca M0-01. | Vincolo dell'ambiente; git non traccia cartelle vuote. | Orchestratore |
| 2026-11-02 | M0-01 | Accettate le deviazioni: `.gitkeep` in `addons/` (non in `addons/gut/`), `icon.svg.import` versionato, `/android/` nel `.gitignore`. | Pratiche standard di Godot 4; nessun impatto su ownership futura. | Orchestratore |
