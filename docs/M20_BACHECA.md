# M20: Bacheca e Mercato (V7)

Seguito di `M19_VILLAGGIO.md`: i due segnaposto del Villaggio diventano edifici costruibili. Design completo in
`01_GDD.md` §31, `02_FORMULAS.md` §5i (F-134…F-136), `04_DATA_SCHEMA.md` §25, `05_INTERFACES.md` §5.28/§7.s,
task M20-02…06 in `07_TASKS.md`, simulazione `tools/sim_quests.gd` (e `tools/sim_village.gd` per i costi).

## Fissato da M20-01 (2026-11-13)
- **Bacheca**: livello `n` → `n` incarichi attivi (stat `quest_slots`, nuova); incarichi `kill`, `gather`, `craft` (56, generati); ricompense di oro, XP di mestiere e cibo; **nessun timer**: una casella libera riceve il prossimo incarico (cursore + finestra di 3 gradini + memoria dei 6 recenti) solo quando si riscuote o si abbandona; offline gli eventi contano come online.
- **Mercato**: nessuna stat; il livello sblocca 15 voci dello shop (`requires.village`, bancarella `mercato`), tutte di comodità.
- **Save**: modulo additivo `quests`, `format_version` 7 invariata, nessuna migrazione (il brief di V7 prevedeva "nuova migrazione": non serve, nessun formato esistente cambia).
- **Scartati**: incarichi di consegna (spendere oggetti: duplicano `gather`/`craft` e complicano il Deposito), incarichi di Frattura o di Monolite (dipendono da sistemi che il giocatore sblocca tardi; Q88), ricompense di pezzi, rune o XP del personaggio (potere di combattimento indiretto), voci del Mercato che vendono oggetti (rompono la raccolta), rinnovo giornaliero (timer).
