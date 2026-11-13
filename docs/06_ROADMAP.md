# 06. Roadmap

Milestone incrementali: alla fine di ognuna il gioco si avvia, è giocabile per quello che contiene e tutti i test
passano (`tools/run_checks.ps1` verde). L'MVP è M0-M9; M10 (riforma del bottino e dei nomi, prima di far provare il gioco agli amici) e M11-M15+ vengono dopo (M12 = Riforma 2, M13 = Fratture come mappe, M14 = Alpha). Il dettaglio dei task è in `07_TASKS.md`.
Da M4 vale la direzione "combattimento al centro" (decisioni D1-D6, `DECISIONS_LOG.md`); M0-M3 restano valide.

```mermaid
flowchart LR
    M0[M0 Setup] --> M1[M1 Prima skill completa]
    M1 --> M2[M2 Maestria a nodi + raccolta]
    M2 --> M3[M3 Artigianato, shop, equip]
    M3 --> M4[M4 Riforma: personaggio + Armeria]
    M4 --> M5[M5 Combattimento a gruppi]
    M5 --> M6[M6 Abilità e tratti]
    M6 --> M7[M7 Bottino: drop rari, raffinazione, Pietre del Rift]
    M7 --> M8[M8 Legatura: Altare, castoni, valute]
    M8 --> M9[M9 Offline + polish = MVP]
    M9 --> M10[M10 Riforma del bottino e dei nomi]
    M10 --> M11[M11 Guida in gioco]
    M11 --> M12[M12 Riforma 2: Deposito, aiutanti, Incisore]
    M12 --> M13[M13 Fratture come mappe]
    M13 --> M14[M14 Alpha: equipaggiamento vero]
    M14 --> M15[M15+ Seconda classe, dungeon]
```

## M0: Setup del progetto
**Obiettivo**: progetto Godot 4.5 vuoto ma strutturato, test e controlli che girano.
**Contenuto**: pulizia della root (rimozione della sottocartella `rifstone-saga---melvor/` con conferma dell'utente),
`project.godot` (GL Compatibility, finestra 1600×900, minimo 1280×720), struttura delle cartelle, git, GUT 9.5.0,
autoload con le firme definitive (EventBus completo, Log, GameClock; stub per DataRegistry, SaveService, Game), tema
base portato da RiftStone, `balance.json` e `stats.json`, menu segnaposto, script di test e di controllo.
**Giocabile**: si apre la finestra con il menu nello stile D; "Esci" funziona.
**Uscita**: `tools/run_checks.ps1` verde (test, dimensione dei file, nessun riferimento a RiftStone).

## M1: Prima skill completa (Selvicoltura)
**Obiettivo**: il ciclo base end-to-end su una skill.
**Contenuto**: tabella XP, modificatori, livello dati con validazione, sessione, salvataggio per slot con versioni,
Wallet, Bank, Skill, maestria per oggetto e pool (senza nodi), ActionRunner e raccolta, `Game` vero (menu → slot →
partita → salvataggio), contenuto di Selvicoltura (8 azioni) e definizione delle 12 skill (ridotte a 7 in M4, D3), menu e scelta dello slot,
schermata principale (sidebar, barra in alto, pagine), pagina skill, bank minima, tooltip e toast portati.
**Giocabile**: nuova partita in uno slot, taglio della legna, XP e livelli, maestria per oggetto, oggetti nella bank,
uscita e rientro con il progresso intatto, slot separati.

## M2: Maestria a nodi e altre due skill di raccolta
**Contenuto**: nodi della maestria e spesa del pool; Cavatura e Lenza (8 azioni ciascuna); nodi delle 3 skill di
raccolta; pannello della maestria; bank completa (blocco, ordinamento, spostamento, pannello dell'oggetto).
**Giocabile**: tre skill di raccolta, alberi dei nodi, gestione della bank.

## M3: Artigianato, shop, equipaggiamento
**Contenuto**: risoluzione delle ricette (ingredienti, conservazione); Forgiatura, Focolare, Intaglio; shop portato da
RiftStone (caselle della bank, attrezzi, razioni da campo come voce già acquistabile); equipaggiamento e attrezzi;
pagine shop ed equipaggiamento; vendita dalla bank.
**Giocabile**: catena raccolta → artigianato → attrezzi che accelerano la raccolta; economia con oro.

## M4: Riforma (personaggio e Armeria)
**Obiettivo**: portare il gioco di M3 sulla nuova direzione senza ancora il combattimento.
**Contenuto**: R-00 (documenti); schema e validatore della riforma (classi, affissi, `kind` e `grade` dei pezzi,
requisiti `character`, gruppi delle aree); 5 skill di combattimento e stance tolte; modulo `character` (livello, XP,
classe unica, senza tratti); salvataggio v2; ItemRoller (rarità F-83, affissi F-85) e Armeria (istanze, `uid`,
capienza F-82, blocco, vendita); equipaggiamento con `uid`, tipi d'arma e assetti (spadone, spada e scudo, due spade);
Forgiatura e Intaglio adeguati (spade, spadoni, scudi, impugnature, anime, manici); UI: pagina Armeria, pagina del
personaggio, equipaggiamento, bank e shop adeguati, sidebar senza skill di combattimento.
**Giocabile**: il gioco di M3 con pezzi forgiati unici (comuni, magici, rari con affissi), Armeria, tre assetti
equipaggiabili e pagina del personaggio (livello 1: l'XP arriva con M5). Un save v1 appare "versione non supportata".

## M5: Combattimento a gruppi
**Contenuto**: formule F-20…F-27 sulla base F-70, F-73…F-77; statistiche dei combattenti (per mano con due spade),
parata, razioni da campo, borsa del bottino; motore a eventi con incontri e gruppi, bersagli, XP per uccisione, morte;
4 aree, 12 mostri, gruppi; pagina del combattimento; `tools/sim_combat.gd`.
**Giocabile**: combattimento automatico a gruppi con attacco base e i tre assetti, XP del personaggio, cibo, morte,
bottino; il triangolo contro i mostri arcani e arcieri.

## M6: Abilità e tratti
**Contenuto**: agganci del motore e 8 tipi di effetto (F-81); abilità (F-79, F-80); `Loadout` con slot (F-78); 12
tratti e 6 abilità della classe (2 per assetto); UI di scelta nella pagina del personaggio e abilità/tratti nella
pagina del combattimento.
**Giocabile**: build vere: i tratti cambiano come si combatte, ogni assetto ha le sue abilità.

## M7: Bottino
**Contenuto**: drop di equipaggiamento con rarità (F-84); anelli e amuleti; raffinazione (F-86); smantellamento (F-88)
e filtro automatico; Pietre del Rift (F-87); UI dell'Armeria completa.
**Giocabile**: caccia al drop e potenziamento a rischio.
**Misure di riferimento** (`tools/sim_combat.gd loot=1 loadout=auto`, set del grado dell'area, seme 1234; criteri
fissati in M7-08, non vincolanti come le formule): 0 morti/ora; 6-18 pezzi/ora (misurati 11,6-17,7 sull'area intera);
un pezzo raro ogni 2-5 ore (misurati 0,08-0,58/ora sull'area intera, 12 h; Bosco il più basso, follow-up di
bilanciamento non bloccante); scontro con la Pietra di 45-80 s con il 20-35% dei PV persi (misurati 46-77 s, 18-34%);
un Sigillo di salvaguardia ogni 3-5 ore di caccia (Pianure circa 1,8 h, Bosco 2,9, Miniere 3,4, Soglia 3); i tre assetti
entro ±30% di uccisioni/ora (misurati da -29% a +27% sullo scudo). Frequenza delle Pietre (Q46, per area): circa 1 Pietra/h in ogni area (misurate 1,13 / 1,00 / 1,00 / 0,96 su 48 h).

## M8: Legatura del Rift (dal M12 "Incisore")
**Contenuto**: Altare del Rift (5 prese) e infusioni; nodi della maestria delle 4 skill di artigianato; castoni (F-89),
pietre incastonabili e tre valute del Rift; pagine dell'Altare e dei castoni.
**Giocabile**: frammenti da raccolta, mostri e Pietre trasformati in infusioni, pietre e crafting degli affissi.

## M9: Offline e polish (fine dell'MVP)
**Contenuto**: simulazione offline fino a 12 ore con il motore a eventi e il filtro, con riepilogo; impostazioni portate
da RiftStone; suggerimenti per slot; feedback visivo (banner, particelle, numeri del danno); regressione completa,
prestazioni, foto automatiche della UI; preset di esportazione Windows e checklist di rilascio.
**Giocabile**: l'MVP completo. **Uscita**: tutti i test (incluso il controllo di copertura delle stat in modalità
rigida) verdi; 12 ore di offline con gruppi da 6 simulate in meno di 10 s.

## M10: Riforma del bottino e dei nomi (prima della prova con gli amici)
**Fonte**: decisioni R1-R4 e B1-B5 (`DECISIONS_LOG.md`); documenti di riferimento `01_GDD.md` §5.1 e §23.1, `02_FORMULAS.md` F-90…F-95
e §8.2, `04_DATA_SCHEMA.md` §18, `05_INTERFACES.md` §5.8b e §7.x. `docs/RIFORMA_BOTTINO.md` e `docs/NOMI.md` restano solo per i nomi.
**Contenuto**: l'equipaggiamento arriva dai **mostri**, dal **kit iniziale** o da un **progetto** (craft singolo a ciclo unico: progetto +
materiali + componente raro = un pezzo almeno magico, con affisso scelto dal livello Q50 del Fabbro); Fabbro e Falegname producono
**componenti** (lingotti, piastre, impugnature, telai, manici) al posto delle ricette in serie; **tre attrezzi unici** con raffinazione
+0…+9 sempre riuscita; bonus del Fabbro alla raffinazione delle armi (`upgrade_success_pct`); smantellamento a componenti; **nomi nuovi**
in tutti i dati e i testi (`NOMI.md`, "Deposito" al posto di "Bank"); correzioni B1-B5 (curva del livello, Razioni da campo gratuite, tempo
di morte offline, primo suggerimento, un solo toast per più livelli); `format_version` 3.
**Giocabile**: si parte con spada, spadone, scudo e i tre attrezzi, si caccia, si ottengono pezzi dai mostri e progetti, si fa un solo craft
importante invece di centinaia, si potenziano gli attrezzi con la raffinazione.
**Uscita**: accettazione di `RIFORMA_BOTTINO.md` §7 (riportata in `07_TASKS.md`): nessuna ricetta produce equipaggiamento in serie; progetto
= un pezzo almeno magico; tre attrezzi +0…+9; nomi di `NOMI.md` e nessun "Bank" nella UI; `sim_combat`: livello 99 in 250-350 h e al massimo
+12 livelli dopo il 50 in una notte offline; salvataggi precedenti "versione non supportata"; tutti i test verdi.
**Misure di riferimento di M10** (M10-07; `tools/sim_progress.gd` e `tools/sim_combat.gd`, seme 1234, 4 h per punto, set e cibo del grado,
non vincolanti come le formule). `combat.kill_xp_mult` = 0,11; XP delle Miniere Crepate a 0,8 × (4 × PV) (1024 / 1280 / 1664).
- **Livello 99**: circa **299 h** nell'area giusta (la più alta consentita dal livello; 1,0 / 4,8 / 27,2 h per i livelli 16 / 38 / 65). XP/h
  dopo il moltiplicatore: Pianure 1.526 (liv. 1) - 2.242 (liv. 4); Bosco 3.960 (16) - 6.752 (23); Miniere 7.530 (38) - 13.759 (56);
  Soglia 16.148 (65) - 34.315 (99). Offline = lo stesso motore: stessi valori.
- **Una notte offline (12 h)**: dal livello 50 **+11/+12 livelli** (livello 61-62; limite +12), dal 60 +7, dall'80 +2. La XP delle Pietre
  (circa 1/h nelle Miniere) aggiunge circa il 4%, dentro il margine.
- **Pezzi dai mostri** (attesi/h, area intera al livello medio): Pianure 2,9 (T1, un pezzo ogni 21 min); Bosco 2,7 (T2-T3, 22 min);
  Miniere 2,8 (T4-T5, 21 min); Soglia 2,7 (T6-T8, 22 min; T7-T8 da soli ogni 33 min). Obiettivo 20-40 min per pezzo del grado dell'area
  (con il solo grado intero del livello medio: 21 / 42 / 39 / 57 min). Probabilità dei pezzi della Soglia ritoccate (3 -> 2,5 / 4 -> 6 / 4 -> 5 %).
- **Progetti dai mostri**: 0,8 / 0,7 / 0,8 / 0,7 per ora (obiettivo ~1/h con le Pietre: Q49). Verifica Q49 (8 h, `sim_combat loot=1`, colonne `bp/h`): Pianure 1,13 / Bosco 0,88 / Miniere 0,75 (media di 6 semi al liv. 50: 1,0) / Soglia 1,38 per ora, Pietre incluse: obiettivo rispettato, nessuna ritaratura.
- Uccisioni/h: 208 / 110 / 83 / 62; morti 0; cibo 188 / 292 / 327 / 361 pezzi/h.



## M11: Guida in gioco (dopo l'MVP, prima delle mappe)
Pagina "Guida" generata dai dati (indice "da dove viene / a cosa serve", testi a mano in `data/guide/`, segnaposto verso
`balance.json` e `stats.json`), pulsanti "?" nelle pagine, righe "Si ottiene da / Serve a" nei tooltip (`01_GDD.md` §27, decisioni G1-G2).
- **Uscita** (verificata in M11-07, 2026-11-08):
  - [x] La Guida si apre dalla sidebar, con ricerca (`GuideNav.search`) e collegamenti (rotta `help` + `guide`; `test_guide_page.gd`).
  - [x] Ogni oggetto, mostro, area, mestiere, stat, tratto e abilità ha la sua pagina (`GuideTables.page_ids`, test in `tests/core/guide/`).
  - [x] Nessun segnaposto non risolto né numero scritto a mano nei testi (validatore di `data/guide/` e `test_guide_text.gd`; `validate_data` verde).
  - [x] Ogni pagina del gioco ha il suo "?" (`HelpButton` in Deposito, Personaggio, Combattimento, Equipaggiamento, Altare, Shop, Skill; `test_help_buttons.gd`); l'Altare non ha una pagina propria nel "?".
  - [x] Righe "Si ottiene da / Serve a" nei tooltip (M11-05).
  - [ ] Layout 1600x900 e 1280x720: verificato solo con test sulle dimensioni minime (`test_layout_fits_the_minimum_window`); foto di layout non fatta (`tools/ui_shots` vuota).
  - [ ] Prove manuali in gioco (Guida, ricerca, "?" in ogni pagina, tooltip): non fatte, a carico dell'utente.
  - Suite su main: 1958 test verdi, dati, righe per file e riferimenti vietati OK.
- **Task** M11-01…M11-07 (`07_TASKS.md`); tag `m11-done`.

## M12: Riforma 2 (Deposito, aiutanti, maestria per risorsa, Incisore, nomi)
**Fonte**: decisioni W1-W7 (`DECISIONS_LOG.md`, approvate dall'utente il 2026-11-08); documenti `01_GDD.md` §4.1, §6.4, §7, §11, `02_FORMULAS.md` F-100…F-108 e §8.5b-§8.8b,
`04_DATA_SCHEMA.md` §20, `05_INTERFACES.md` §5.20-§5.22 e §7.w. Le **corsie parallele (ex M13) sono tolte**: le sostituiscono gli aiutanti.
**Contenuto**: **Deposito unico** (oggetti ed Equipaggiamento sulla stessa capienza, 6 slot borsa, 5 borse; spariscono gli "spazi" dello shop); **aiutanti** per Boscaiolo, Minatore e
Pescatore (contratti dai mostri, gradi Apprendista…Maestro, XP al 25%, più lenti, anche offline); **maestria per risorsa** (3 traguardi per ogni risorsa, alberi dei nodi diversi per
mestiere: chiude Q26); **Incisore** al posto della Legatura (trasforma i drop: Fondere, Cristallizzare, Incidere e Potenziare rune a 5 gradi, Lastra runica); tabelle di drop con Polvere,
Schegge, Pietre, Cristalli, Contratti e borse; **Monoliti del Rift** (nome); nomi nuovi di `NOMI.md`; `format_version` 4 (salvataggi precedenti "versione non supportata").
**Giocabile**: si caccia, i mostri lasciano Polvere, Schegge e Contratti; si assume un aiutante che raccoglie mentre si combatte; si incidono rune e si fondono pietre; il Deposito cresce con le borse.
**Uscita** (accettazione di `RIFORMA_2.md` §10, riportata in `07_TASKS.md`): un solo Deposito con capienza unica e 6 slot borsa, caselle vuote visibili, niente spazi in vendita; un aiutante per
mestiere di raccolta, in parallelo al combattimento e offline, con XP al 25% e più lento del giocatore (la sim conferma F-102); ogni risorsa con i suoi 3 traguardi e alberi diversi per i tre
mestieri; l'Incisore sale di livello solo consumando drop (più la Lastra runica) e pietre, valute e polvere cadono dai mostri; nomi di `NOMI.md`; Guida aggiornata; tutti i test verdi.
**Task** M12-01…M12-09 (`07_TASKS.md`); tag `m12-done`.
**Misure di M12-07** (`tools/sim_m12.gd`, 8 h simulate, 3 semi; valori di partenza da tarare dopo la prova, domande Q56, Q58-Q62 in `OPEN_QUESTIONS.md`):
- Aiutanti: tre aiutanti Maestro insieme guadagnano **0,448** dell'XP/h del giocatore (invariante di F-102 ≤ 1 rispettata).
- Incisore: Polvere ~38-79/h; Schegge 2,6-4,1/h per famiglia; Pietre 0,16-0,25/h. Primo Cristallo del risveglio dopo 0,2-0,4 h, del mutamento 0,5-1,0 h, dell'ascesa 0,8-1,7 h; prima Pietra perfetta dopo 1,9-2,9 h.
- Rune: la Runa di grado V richiede 81 rune di grado I; dopo la taratura del 2026-11-09 (Q62 chiusa) il grado III costa 6,8-8,4 h e il grado V 61-76 h di farming nell area giusta, per tutte le famiglie.
- Borsa del bottino: perdita ~0/h con svuotamento ogni 10 min, fino a 1-2,6/h con svuotamento ogni 4 h (Q56 accettata). Progetti dai mostri 0,9-1,0/h (Q49 confermata).
- Deposito: la base di 60 caselle si riempie dopo 8-10 h senza vendere.
- Dati: contratto Maestro `chance_pct` 0,01 invece di 0,005 (minimo del validatore), circa 1 ogni 50 h; i Cristalli diretti non cadono nelle Miniere; ingredienti delle borse di tela e rinforzata e valori in oro dei
  sottoprodotti scelti dal Data Designer (vedi i dati) sono valori di partenza da tarare.

## M13: Fratture come mappe (dopo la Riforma 2)
**Fonte**: decisioni X1-X4 (`DECISIONS_LOG.md`, approvate dall'utente il 2026-11-09, riportate da R-04); documenti `01_GDD.md` §17, `02_FORMULAS.md` §7 (F-50, F-109…F-116), `04_DATA_SCHEMA.md` §11, `05_INTERFACES.md` §5.23 e §7.v.
La Frattura casuale ogni 2-4 ore è **eliminata**; le corsie parallele non esistono più (W3).
**Contenuto**: **Carte della Frattura** di grado 1-10 con rarità e modificatori (rischio + premio), che cadono dai mostri delle aree e dai Monoliti (gradi bassi) e soprattutto dalle Fratture; i Cristalli funzionano anche sulle Carte, lo smantellamento dà Polvere;
**Fratture** aperte dal giocatore con una Carta (16 gruppi di mostri scalati per grado, poi un **boss** con una abilità propria), borsa della Frattura separata consegnata solo alla vittoria, **se muori perdi la Carta e il bottino della Frattura**;
funzionano anche offline; pagina **Fratture**, Frattura in corso in Combattimento, Guida; nomi nuovi di `NOMI.md` (sezione Fratture); salvataggio `cards` e `fractures` (additivi, `format_version` 4 invariata).
**Giocabile**: si trova una Carta cacciando, la si migliora con i Cristalli, la si apre, si combattono 16 gruppi e un boss; vittoria = bottino e Carte più alte nel Deposito, morte = tutto perso.
**Uscita** (accettazione riportata in `07_TASKS.md`; **verificata in M13-07, tutti i punti soddisfatti** salvo la durata del grado 1, 13,9 minuti, e la regola "muore sotto di 10 livelli", vedi Q63): nessuna apertura automatica; Carte 1-10 con rarità e modificatori e Cristalli che funzionano; ogni Frattura ha N gruppi e un boss; vittoria = bottino nel Deposito, morte o abbandono = Carta e borsa perse;
offline con riepilogo; la sim dà 15-30 minuti per Frattura nel grado giusto e ~1 Carta di grado uguale o superiore per Frattura (la scala dei gradi non si interrompe); Guida aggiornata; tutti i test verdi.
**Task** M13-01…M13-07 (`07_TASKS.md`); tag `m13-done`. Domande Q63-Q65 (`OPEN_QUESTIONS.md`).

**Misure di bilanciamento (M13-06, `tools/sim_fracture.gd`: personaggio del livello consigliato, set del grado, tratti e abilità automatici, Carta magica, 6 semi; minuti medi, vittorie, Carte di grado ≥ al grado per Frattura, pezzi, Polvere, XP/h)**

| grado | livello | vittorie | minuti | Carte ≥ grado | pezzi | Polvere | XP/h |
|---|---|---|---|---|---|---|---|
| 1 | 45 | 6/6 | 13,9 | 1,00 | 1,5 | 25 | 16645 |
| 2 | 50 | 6/6 | 17,5 | 0,83 | 1,5 | 39 | 20125 |
| 3 | 56 | 6/6 | 22,6 | 0,67 | 2,0 | 35 | 25760 |
| 4 | 70 | 6/6 | 27,3 | 0,50 | 2,7 | 54 | 57072 |
| 5 | 76 | 6/6 | 23,5 | 0,83 | 1,3 | 59 | 48140 |
| 6 | 82 | 3/6 | 29,3 | 0,33 | 2,0 | 38 | 48593 |
| 7 | 88 | 5/6 | 26,5 | 0,83 | 2,3 | 71 | 68841 |
| 8 | 94 | 4/6 | 19,1 | 0,50 | 1,2 | 75 | 72984 |
| 9 | 99 | 5/6 | 25,5 | 0,50 | 1,7 | 93 | 59334 |
| 10 | 99 | 4/6 | 16,4 | 0,67 | 1,5 | 94 | 114193 |

Le Carte per Frattura sono mediate anche sulle sconfitte (con la sconfitta la borsa si perde): per Frattura vinta sono circa 1. Dieci livelli sotto il consigliato (`delta=-10`) il grado 1 non si vince mai (0/6), i gradi 5-7 si vincono 3-4 volte su 6, i gradi 2-4 e 8-9 quasi sempre (deviazione in Q63).

## M14: Alpha (dopo le Fratture come mappe)
**Fonte**: decisioni Y1-Y9 (`DECISIONS_LOG.md`, approvate dall'utente il 2026-11-09 dalla prova del gioco, riportate da R-05); documenti `01_GDD.md` §28-§29 e §27.1, `02_FORMULAS.md` §5e, §7 (F-123) e §8.4, `04_DATA_SCHEMA.md` §21, `05_INTERFACES.md` §5.24 e §7.u, `NOMI.md` (sezione Alpha). Obiettivo: **alpha giocabile**.
**Contenuto**: **armi** con danno minimo-massimo e velocità propri (danno al secondo nella scheda); **armature** in tre materiali (Piastre, Cuoio, Tessuto runico) con **Armatura** (riduce il danno fisico) e **Barriera** (danno arcano), formula a rendimenti decrescenti; **15 gradi** per slot (livelli 1…90) con nomi nuovi;
rarità **Capolavoro** (solo progetti, costo alto) e **Leggendario** (≥ 39: 3 per slot, attrezzi compresi, con un effetto che cambia le regole e la fonte dichiarata); **drop di equipaggiamento** su tutti gli slot (3-5 pezzi ogni 30 minuti); **Guida a scoperta** (oggetti e drop bloccati finché non trovati, niente "Si ottiene da" nei tooltip);
**maestria visibile** con bonus ogni 10 livelli; Polvere del Rift ridotta e con più usi; tetto ai rischi delle Carte; ritocchi UI (barra XP, "Altri nemici", sottoschede, Riordina, shop con i numeri). Salvataggio **v5**.
**Giocabile**: si cacciano pezzi di ogni slot, si sceglie un materiale e un'arma, si vedono Armatura e Barriera, si forgia un Capolavoro, si inseguono i leggendari nelle Fratture e nei Monoliti, la Guida si riempie scoprendo; sale la maestria con bonus visibili.
**Uscita** (accettazione in `07_TASKS.md` M14-10): armi con danno min-max, velocità e DPS; armature con materiali, Armatura % e Barriera %; 15 gradi per slot; Capolavori solo da progetti; ≥ 3 leggendari per slot con effetto e fonte; la sim dà 3-5 pezzi ogni 30 minuti nell'area giusta, 1 magico ogni 30 minuti, 1 raro ogni 2-3 ore;
Guida a scoperta senza "Si ottiene da"; maestria con prossimo bonus su ogni carta; ritocchi UI; tutti i test verdi.
**Task** R-05 → M14-01…M14-11 (`07_TASKS.md`); tag `m14-alpha`. Domande Q66-Q77 (`OPEN_QUESTIONS.md`).
**Stato**: **M14 completata** (M14-01…M14-11 DONE; tag `m14-alpha` e `m14-done` messi dall'Orchestratore dopo la suite completa). Misure e tarature di M14-10 qui sotto; Q66-Q77 chiuse in `OPEN_QUESTIONS.md`.

### Misure di M14-10 (sim sui dati veri, seme 1234; `tools/sim_m14.gd`, `sim_combat.gd`, `sim_fracture.gd`, `sim_progress.gd`)
Personaggio del livello dell'area, set forgiato del grado (spada e scudo, Piastre; per le Fratture Cuoio), 48 ore simulate per area. Test in `tests/balance/` (ogni riga è un test con tolleranza).

| Obiettivo (ALPHA.md §10) | Pianure | Bosco | Miniere | Soglia | Esito |
|---|---|---|---|---|---|
| Uccisioni/ora (sim) | 334 | 245 | 238 | 250 | ok (prima 332 / 195 / 163 / 118) |
| Pezzi ogni 30 min (obiettivo 3-5) | 4,7 | 3,7 | 3,6 | 3,6 | ok (da dati: 4,8 / 3,6 / 3,5 / 3,6) |
| Magici ogni 30 min (≈ 1) | 0,97 | 0,72 | 0,83 | 0,94 | ok (da dati 1,2 / 0,9 / 0,9 / 0,9) |
| Ore per un raro (obiettivo 2-3) | 1,9 (da dati 2,1) | 2,8 | 2,5 | 2,8 | ok |
| Progetti/ora (≈ 1) | 1,56 (da dati 1,3) | 0,83 | 1,00 | 0,90 | ok |
| Polvere del Rift/ora (Q71, era ≈ 150) | 58 | 66 | 95 | 109 | ok (Monoliti compresi) |
| Morti/ora nell'area del livello | 0 | 0 | 0 | 0 | ok |

| Riduzione (F-117), set completo con scudo | Livello 1 | Livello 50 | Livello 90 |
|---|---|---|---|
| Piastre: Armatura | 12 → 15,4% | 404 → 52,9% | 724 → 54,7% |
| Tessuto runico: Barriera | 12 → 15,4% | 404 → 52,9% | 724 → 54,7% |
| Cuoio: Armatura / Barriera | 9,6% / 5,7% | 40,1% / 30,8% | 41,9% / 32,5% |
Obiettivo 15-55% rispettato dalla stat principale del materiale; nessun set raggiunge il tetto 75.

| Frattura (livello consigliato, Cuoio, 10 seed) | G1 | G2 | G3 | G4 | G5 | G6 | G7 | G8 | G9 | G10 |
|---|---|---|---|---|---|---|---|---|---|---|
| Vinte | 10/10 | 10/10 | 10/10 | 10/10 | 10/10 | 9/10 | 8/10 | 9/10 | 10/10 | 8/10 |
| Minuti delle vinte (obiettivo 15-30) | 16,9 | 17,2 | 19,9 | 17,8 | 17,2 | 23,0 | 20,0 | 18,9 | 21,4 | 19,1 |
| Ore per un leggendario di boss (obiettivo 15-30) | 17,5 | 17,8 | 20,2 | 18,3 | 17,8 | 25,7 | 25,5 | 21,5 | 21,7 | 24,4 |
(Prima della taratura le Fratture duravano 6-13 minuti e i gradi 9-10 morivano al primo gruppo.) Leggendari: 3 per boss × 0,6% a vittoria, più 9 (attrezzi e pezzi) dai Monoliti a 0,3%.

B1: livello 99 in **319,6 ore** (obiettivo 250-350; prima della taratura 175), 12 ore offline dal 50: **+12** livelli (limite 12).

## M15: Monoliti da Metin, pezzi nel bottino, combattimento affollato (R-06)
**Fonte**: decisioni Z1-Z9 (`DECISIONS_LOG.md`, 2026-11-10), riportate da M15-01; `01_GDD.md` §24b, §10.13-10.14, `02_FORMULAS.md` §5f (F-125…F-128), `04_DATA_SCHEMA.md` §22, `05_INTERFACES.md` §5.25 e §6 (save v6). `METIN.md` resta come storico.
**Contenuto**: Monoliti di un tipo ogni 5 livelli con pool per area (Pianure 5-10-15); PV da F-125, impulso fisso da 1 danno, ondate di evocati al primo colpo e a 75/50/25%; bottino con pezzo garantito di rarità aumentata e un Progetto;
**pezzi nel Bottino** (non più direttamente nell'Armeria) e sezione "Pezzi" nel Deposito; **vista compatta** con 30+ nemici; impostazione "Salta i Monoliti fino al livello X" (stato dello slot).
**Giocabile**: appare un Monolito del livello giusto, si combatte con ondate di mostri, se ne ricava un pezzo; si raccolgono i pezzi dal Bottino; con tanti nemici la pagina resta leggibile e veloce; si possono saltare i Monoliti bassi.
**Uscita** (`07_TASKS.md` M15-08/09): suite verde; tasso di Monoliti per area tarato (Q78, Q82); 30 mostri offline senza rallentamenti; conservazione degli oggetti con il Bottino; migrazione v5 → v6 testata.
**Task** M15-01…M15-09 (`07_TASKS.md`); tag `m15-done`. Domande Q78-Q82 (`OPEN_QUESTIONS.md`). Miniboss rimandati (Z8).
**Stato**: **M15-01…M15-09 DONE, M15 completata** (tag `m15-done` dell'Orchestratore). Misure: Q78 chiusa con PV invariati (tempi da 182 s Pianure L10 a 54 s Soglia L80, ritaratura rimandata); Q82 chiusa (1-2 Monoliti/h per area, Pianure 0,6, pietà 300); ore al 99 con i Monoliti ≈ 369. Aperte Q79-Q81, Q83. Prossimo: M16+, miniboss rimandati.

## M16: Bug e ritocchi del primo giorno di alpha (R-07)
**Fonte**: `M16_M18.md` (V1-V11), riportate da M16-01 in `DECISIONS_LOG.md`, `01_GDD.md` §10.15, `02_FORMULAS.md` §5g, `04_DATA_SCHEMA.md` §23, `05_INTERFACES.md` §5.26.
**Contenuto**: bug della corazza di Roccamartello / potenziamento / progetto non consumato; mostri morti visibili con i Monoliti; livello dell'item e del mostro; artigianato con prodotti posseduti e riepilogo maestria; pallino del lavoro in corso; pezzi sempre visibili nel Deposito; nomi degli affissi in stile PoE.
**Task** M16-01…M16-08 (`07_TASKS.md`); tag `m16-done`.

## M17: Combattimento (precisione, XP, aree strette, mappa)
**Contenuto**: formula di precisione (F-129) e XP per differenza di livello (F-130) fissate da M17-01; misura del drop equip (V5); aree strette con gruppi 1-8 e Monoliti per area; mappa cliccabile e % di colpire; drop ridotto agli evocati; più peso visivo al combattimento.
**Task** M17-01…M17-08 (`07_TASKS.md`), tutti DONE; **M17 completata**, tag `m17-done`. Prossimo: M18.

## M18: Incisore e Fabbro (Falegname rimandato, V7)
**Contenuto**: ricette di basso livello dell'Incisore e XP da disincantare/fondere; riordino della sottoscheda del Fabbro.
**Task** M18-01…M18-03 (`07_TASKS.md`); tag `m18-done`. Falegname: Villaggio in M19 (Q84 risolta).

## M19: Villaggio, edifici a box (V7)
**Fonte**: `M19_VILLAGGIO.md`; design in `01_GDD.md` §30, `02_FORMULAS.md` §5h (F-131…F-133), `04_DATA_SCHEMA.md` §24, `05_INTERFACES.md` §5.27 e §7.t.
**Contenuto**: pagina Villaggio con 5 edifici unici a 8 livelli (Magazzino, Locanda, Fucina, Segheria, Rimessa del bottino), pagati con oro e componenti di Falegname, Fabbro e Cuoco; effetti solo di comodità via `ModifierService`; costruzione istantanea; segnaposto di Mercato e Bacheca.
**Task** M19-01…M19-04 (`07_TASKS.md`); M19-02 (CORE+DATA) e M19-03 (UI) in parallelo; tag `m19-done`.
**Giocabile**: costruire e migliorare gli edifici con i materiali dei legni 1-8; ogni livello costa al massimo 0,84 h di raccolta e oro (sim).

## M20: Bacheca, quest e Mercato
Bacheca con quest e ricompense, shop esclusivi del Mercato (i due segnaposto di M19 diventano costruibili); si progetta in M20-01 (REV). Può aggiungere un modulo al save (regola additiva, o una migrazione se cambia un formato).

## M21: Mappa del Villaggio
Mappa dell'insediamento sullo schema di `combat_map.gd`; si progetta in M21-01.

## M22+: Seconda classe, dungeon, altri boss (dopo M21; era M19+)
Seconda classe con le sue armi (es. arco o bastone, con i suoi progetti e componenti del Falegname), supporti delle abilità,
altri boss, dungeon a ondate, oggetti unici, elementi e resistenze.

## Percorso critico e parallelismo
- M14: R-05 → M14-01 → M14-02 → M14-03 → M14-04 → (M14-05 ∥ M14-07) → (M14-08 ∥ M14-09) → M14-06 → M14-10 → M14-11. I primi quattro toccano file comuni (`core/data/**`, `event_bus.gd`, `game_session.gd`, `systems/combat/**`): in sequenza; la UI (M14-06) per ultima.
- M13: R-04 → M13-01 → (M13-02 ∥ M13-04) → M13-03 → (M13-05 ∥ M13-06) → M13-07. M13-01 e M13-02 toccano file comuni (`core/data/**`, `event_bus.gd`, `reasons.gd`, `game_session.gd`): in sequenza; M13-02 (motore) e M13-04 (dati) hanno file diversi.
- M12: R-03 → M12-01 → M12-02 → M12-03 → M12-04 → M12-05 → (M12-06 ∥ M12-07) → M12-08 → M12-09. I task CORE toccano file comuni (`core/data/**`, `event_bus.gd`, `reasons.gd`, `game_session.gd`): vanno in sequenza; M12-06 (UI) e M12-07 (bilanciamento) hanno file diversi.
- M11: R-02 → (M11-01 ∥ M11-02) → M11-03 → M11-04 → M11-05 → M11-06 → M11-07.
- M10: R-01 → M10-01 → M10-02 → M10-03 → M10-04 (con M10-05) → M10-06 → M10-07 → M10-08 → M10-09. M10-02 e M10-03 si parallelizzano (file diversi).
- Percorso critico da M4: R-00 → M4-01 → M4-02 → M4-03 (con M4-04) → M4-05 → M4-06 → M4-07 → M4-08 → M4-10 → M4-11 →
  M5-01 → M5-02 → M5-03 → M5-07 → … → M9-08.
- Si possono parallelizzare (massimo 2 agenti, `CLAUDE.md`): M4-04 con M4-03; M4-09 con M4-06 o M4-07 (M4-08 parte dopo M4-09: stesso `page_host.gd`); M5-04 (dati) con
  M5-01…M5-03; M5-06 (`sim_combat`) dopo M5-03 con M5-05 (UI).
