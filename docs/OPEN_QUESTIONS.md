# Domande aperte

Tutto ciò che non è deciso, con la proposta di default. Finché l'utente non risponde **vale il default** (gli altri
documenti sono già scritti così). Quando una domanda si chiude, il Reviewer aggiorna i documenti e la sposta in fondo
in "Chiuse".

## Più urgenti (prima o durante M0-M1)

| # | Domanda | Default proposto | Dove impatta |
|---|---|---|---|
| Q1 | Posso eliminare la sottocartella `rifstone-saga---melvor/` (progetto vuoto creato dall'editor, Godot 4.5 GL Compatibility) e mettere `project.godot` nella root? | Sì: M0-01 chiede conferma e la elimina | M0-01 |
| Q2 | Restare su Godot 4.5 per tutto l'MVP? | Sì; valutare l'aggiornamento solo dopo M9 | tutti |
| Q3 | Nome definitivo del gioco | resta "RiftStone Saga: Idle" | `project.godot`, menu |
| Q4 | Numero di slot | 4 | `balance.json` `slots.count` |
| Q5 | Salvataggio sincrono o in un thread | sincrono; M1-06 misura, thread solo se > 30 ms | M1-06 |

## Gameplay

| # | Domanda | Default proposto |
|---|---|---|
| Q7 | Penalità di morte: solo la borsa del bottino? | Sì; niente perdita di equipaggiamento o oro |
| Q8 | Togliere un'infusione dall'Altare la distrugge? | Sì (consumo); alternativa futura: recupero con costo in frammenti |
| Q11 | Mostri "boss" o dungeon a ondate? | Dopo l'MVP (M14+) |
| Q12 | Le razioni da campo devono funzionare anche senza acquisto (livello base)? | **Cambiata da B2 (M10)**: le Razioni da campo I sono gratuite dall'inizio (`start.purchases`); livello 0 non esiste più in partita; avviso se si combatte senza cibo scelto |
| Q13 | Livelli oltre il 99? | No; l'XP continua fino a `xp_cap` |
| Q14 | Skill da sbloccare (a pagamento) o tutte subito? | Tutte subito |
| Q15 | Valori delle soglie delle razioni da campo, dei prezzi dello shop, dei mostri | quelli di `02_FORMULAS.md` §8-9, da rivedere dopo una prova di gioco a fine M5 (combattimento), con `tools/sim_combat.gd` |

## Offline

| # | Domanda | Default proposto |
|---|---|---|
| Q16 | Limite offline aumentabile (es. voce dello shop)? | No: 12 ore fisse |
| Q17 | Si può interrompere la simulazione offline? | No; deve durare < 10 s |
| Q18 | Le Fratture (M13) avanzano anche offline? | Sì, con lo stesso motore a eventi (una Frattura aperta prima di uscire finisce durante l'assenza; R-04) |

## UI, contenuti, piattaforma

| # | Domanda | Default proposto |
|---|---|---|
| Q19 | Schede (tab) multiple nella bank? | No nell'MVP: ordinamento + ricerca |
| Q20 | Icone definitive: chi le produce? | MVP con segnaposto originali; dopo l'MVP icone illustrate (anche con generatore di immagini, con revisione dell'utente e nessuna immagine di altri giochi) |
| Q21 | Audio | M9 solo pochi suoni di interfaccia (clic, livello, frammento) con licenza libera o creati; musica dopo l'MVP |
| Q22 | Lingua inglese | No nell'MVP; i testi restano nei dati, così una traduzione futura tocca solo i JSON |
| Q23 | Piattaforme oltre Windows | Dopo l'MVP (Linux/Mac: export senza cambi di codice) |
| Q24 | Backup del salvataggio | un solo `.bak`; più copie a rotazione solo se richiesto |
| Q25 | Riuso delle icone degli oggetti di RiftStone (`Item_Texture/`, `Icons/`) | No (nomi e temi legati a Metin2, provenienza da verificare); eventualmente il Porting Engineer le valuta una per una su richiesta |

## Riforma da M4 (combattimento al centro, `VISIONE_V2.md` §8)

I documenti sono già scritti con questi default (R-00).

| # | Domanda | Default proposto | Dove impatta |
|---|---|---|---|
| Q27 | La raffinazione può distruggere un pezzo? | No: da +4 il fallimento fa scendere di un livello | F-86, `01_GDD.md` §23 |
| Q28 | Raffinazione massima | +9 | F-86 |
| Q29 | Unici nell'MVP? | No (M14+) | `01_GDD.md` §22 |
| Q30 | Anelli e amuleti forgiabili? | No, solo drop (M7) | §8.4, `01_GDD.md` §22 |
| Q31 | Raffinazione istantanea o azione a tempo? | Istantanea | `01_GDD.md` §23 |
| Q32 | Attrezzi di raccolta con rarità e affissi? | ~~Sì~~ **Superata da R3 (M10)**: gli attrezzi sono tre oggetti unici senza rarità né affissi | §8.9, `01_GDD.md` §22 |
| Q33 | Capienza iniziale dell'Armeria | SUPERATA da M12 (W1): capienza unica del Deposito, `deposit.base_slots` (Q58) | F-100 |
| Q34 | Livello massimo del personaggio | 99, curva `character_curve` | F-71 |
| Q35 | Livelli di apertura degli slot dei tratti | 1, 10, 25, 50 | F-78 |
| Q36 | Slot delle abilità | 2, il 3° al livello 30 | F-78 |
| Q37 | Archi e bastoni restano nei dati (non equipaggiabili) o si tolgono fino alle loro classi? | Si tolgono: oggetti e ricette tornano con le classi future | M4-02 |
| Q38 | Dimensione dei gruppi | **Chiusa da V4/M17-01**: 1-8, media 4,07 (`pack_size_weights`) | §8.5, `combat.max_pack_size` |
| Q39 | Doppia spada: moltiplicatore dell'intervallo e penalità di precisione | `combat.dual_wield.interval_mult` 0,75, precisione −10% (modificatore dell'assetto), da rivedere con `tools/sim_combat.gd` | F-73, `04_DATA_SCHEMA.md` §14 |
| Q40 | Parata con lo scudo: cosa blocca? | Tutto il danno di un colpo; `block_chance` dello scudo 5-15% per grado, massimo 50% | F-75 |
| Q41 | XP dei mostri | **M10 (B1): vedi Q54, `combat.kill_xp_mult`.** Default 4 × PV, **confermato da M5-06 senza cambi** (decide l'utente). Tempi stimati con `tools/sim_combat.gd` per area, per arrivare al 99 (report di M5-06): Pianure circa 10-12 min, Bosco 25-45 min, Miniere 2,5-3,5 h, Soglia 36-52 h (uccisioni/ora sull'area intera al livello medio dei mostri: 213 / 115 / 80 / 62) | F-28, `02_FORMULAS.md` §8.5, M5-06 |
| Q42 | Tooltip dei pezzi senza le skill di combattimento: da dove vengono il nome dello stile e il testo del requisito del personaggio? | Testi della UI in costanti di `ItemTooltipLines` (stili `blade`/`marksmanship`/`arcana` → Lama/Mira/Arcano; requisito «Richiede il livello N del personaggio»), come gli altri testi di presentazione | M4-08, `05_INTERFACES.md` §7 |
| Q43 | A quale livello del personaggio vale il criterio di `02_FORMULAS.md` §8.5 (0 morti nel gruppo più facile, almeno 60 uccisioni/ora nell'area)? §8.5 fissa solo il grado del set e del cibo | Livello medio dei mostri dell'area (4 / 23 / 46 / 78): criterio soddisfatto (213 / 115 / 80 / 62 uccisioni/ora, 0 morti). Al livello d'ingresso (1 / 16 / 38 / 65) Miniere e Soglia restano sotto 60 (156 / 60 / 56 / 45) e i pesi dei gruppi non bastano (i gruppi singoli lenti restano sotto 60): servirebbe toccare i mostri o il personaggio | `02_FORMULAS.md` §8.5, M5-06, `tools/sim_combat.gd` (`level=`) |
| Q44 | Valori provvisori di tratti e abilità di M6-04 (scelti dal DATA agent, in attesa di bilanciamento): cooldown, `power_mult`, `pct`, livelli di sblocco, buff di Frenesia gemella (`attack_interval_pct` −25% per 8 s) | **DECISA (2026-11-06), RITARATA in M7-07** con `tools/sim_combat.gd`: valgono i valori di `data/classes/rift_blade.json` dopo la ritaratura (Mulinello `power_mult` 1,0; Maglio del Rift 2,0; Colpo di scudo 1,8 con ricarica 6500 ms); i tre assetti restano entro ±30% di uccisioni/ora | M6-04, F-79/F-81, `01_GDD.md` §20.2 |
| Q45 | Valori provvisori di M7-05 (scelti dal DATA agent): prezzo di vendita di anelli, amuleti e Sigillo di salvaguardia, statistiche delle 4 Pietre del Rift (PV, XP, `pulse_damage`, `pulse_ms`, `summon_pack`, `shards`), chance e assegnazione dei drop di pezzi e gioielli ai mostri e alle Pietre | **RITARATI in M7-07** con `tools/sim_combat.gd` (`loot=1`): `pulse_damage` delle Pietre Miniere 10 e Soglia 15 (Pianure 2 e Bosco 6 invariati); drop dei mostri alzati (gioielli 3-4%, pezzi di arma e armatura 4-6%); drop delle Pietre: Sigillo 25/30/35/40%, pezzi 30-40%. Prezzi di vendita invariati. Valori in `data/combat/monsters.json` e `rift_stones.json` | M7-05, M7-07, F-84, F-87 |
| Q46 | Frequenza delle Pietre del Rift: `rift_stone.chance_pct` 0,5 e `pity_kills` 300 (`balance.json`) danno una Pietra ogni circa 0,8 h in Pianure ma ogni 2,4-2,6 h in Miniere e Soglia (meno uccisioni/ora) | **CHIUSA** (decisa dall'utente il 2026-11-07): probabilità per area, campo facoltativo `rift_stone_chance_pct` (0..100) in `data/combat/areas.json`, default `rift_stone.chance_pct`; `pity_kills` resta globale (300). Valori: Pianure 0,0 (la garanzia a 300 uccisioni dà già 1,1 Pietre/h con 343 uccisioni/h; sotto 300 uccisioni/h per Pietra non si può scendere), Bosco 0,3, Miniere 0,5, Soglia 0,8. Misurato (48 h, `loot=1 loadout=auto`): 1,13; 1,00; 1,00; 0,96 Pietre/h | M7-07, M7-08, F-87 |
| Q47 | Pity per area dopo l'MVP: con la pity globale a 300 uccisioni le Pietre del Rift sono sotto 1/h sull'intera area (24 h, `loot=1`: Pianure 0,67, Bosco 0,63, Miniere 0,50, Soglia 0,83; sul gruppo più facile circa 1/h) | **Default**: pity globale 300 (`pity_kills` in `balance.json`, invariato). Accettato dall'utente il 2026-11-07 per l'MVP; dopo l'MVP valutare `pity_kills` per area (campo facoltativo in `areas.json`) | M9-07, Q46 |

## Riforma del bottino e dei nomi (M10, `RIFORMA_BOTTINO.md`)

I documenti sono già scritti con questi default (R-01). Valgono finché l'utente non risponde.

| # | Domanda | Default proposto | Dove impatta |
|---|---|---|---|
| Q48 | Durata del craft di un progetto | 10 min al grado 1, +7 min per grado: 10, 17, 24, 31, 38, 45, 52, **59** min (la fonte dice "60 al grado 8": con +7 per grado il grado 8 dà 59; vale la regola +7) | F-90, `balance.json` `blueprint.duration_*` |
| Q50 | Livello del Fabbro per scegliere un affisso | 50 | F-92, `blueprint.choose_affix_level` |
| Q51 | Kit iniziale | spada, spadone, scudo comuni di grado 1 + 3 attrezzi a +0 + 20 pesci cotti di grado 1; spada e scudo indossati, cibo scelto (assunzione di R-01, da confermare) | `start.*`, `01_GDD.md` §1.1 |
| Q52 | Gli id interni cambiano con i nomi? | No: cambiano solo i nomi visibili (`name`, `description`); gli id restano | M10-05 |
| Q53 | Valori di partenza della riforma **non presenti nelle fonti** (da tarare con `sim_combat`/`sim_gear_economy` in M10-07 o dopo la prova): quantità di piastre/impugnature/telai e del componente raro per progetto (02 §8.2: 4-10 piastre, 0-2 componenti di legno, 3 rari); `blueprint.xp_mult` 1,5; `rare_base_pct` 10 e `rare_per_forging_level` 0,5 (F-91); `chosen_affix_tier` 2 (F-92); `per_level` del Fabbro 0,4 (F-93); tabella F-94 (livelli minimi dei passi tranne +4 = 25, componenti, oro, `interval_base_pct` 5, `interval_per_level_pct` 2, `upgrade_extras`); `component_ratio` 0,4 (invariato); piastra = 2 lingotti; un'area di grado `g` lascia progetti di grado `g` e `g+1`; un solo componente raro per grado | come scritto in `02_FORMULAS.md` §5c e §8.2 | F-90…F-95, M10-04, M10-07 |
| Q54 | B1: come rallentare il livello del personaggio (da ~50 → 95 in una notte offline a: livello 99 in 250-350 h; da 50 a 60 in una notte; massimo +12 livelli dopo il 50 in una notte) | **Tarato in M10-07**: `combat.kill_xp_mult` = 0,11 e XP delle Miniere Crepate a 0,8 × (4 × PV) (moltiplica l'XP per uccisione, F-28), da tarare con `tools/sim_combat.gd` (anche offline) in M10-07; in alternativa o in aggiunta si può cambiare `character_curve` (F-71). Conseguenza: gli esempi di F-28 e i test cambiano insieme al valore | F-28, F-71, M10-07, Q41 |

## Guida in gioco (M11)

| # | Domanda | Default proposto | Dove impatta |
|---|---|---|---|
| Q56 | Con la borsa piena i progetti dai mostri si perdono (~0,38 progetti/h in un seme, Q49) | Accettato: la perdita è visibile in `sim_combat` (`bp lost/h`); nessuna modifica. **Accettata** da M12-07 (`sim_m12`): perdita ~0/h con svuotamento ogni 10 min, 1-2,6/h ogni 4 h | Q49, M10-02, M12-07 |
| Q57 | I titoli di gruppo dell'indice della Guida sono costanti in `guide_nav.gd`, non in dati | Restano costanti di presentazione (come Q42); spostarli in `data/guide/` se serviranno traduzioni o modifiche frequenti | M11-04 |

## Riforma 2 (M12, `RIFORMA_2.md` riportata da R-03)

I documenti sono già scritti con questi default. I numeri non presenti nella fonte sono valori di partenza **da tarare**
in M12-07 (`tools/sim_combat.gd`).

| # | Domanda | Default proposto | Dove impatta |
|---|---|---|---|
| Q58 | Borse: caselle e fonti | 6 slot borsa; Borsa di tela +6 (ricetta del Falegname, comune), di cuoio +10 (drop di Pianure e Bosco), rinforzata +14 (ricetta del Falegname con sottoprodotti della maestria: la fonte dice "progetto"), del viandante +18 (drop raro delle Miniere), runica +24 (Monoliti). `deposit.base_slots` 60 (non nella fonte: 24 + 40 di oggi meno il surplus, da tarare). **Misura M12-07**: la base di 60 si riempie dopo 8-10 h senza vendere; ingredienti delle borse di tela e rinforzata e oro dei sottoprodotti scelti dal Data Designer = valori di partenza da tarare | F-100, `balance.json` `deposit.*`, M12-01, M12-05 |
| Q59 | Aiutanti: lentezza per grado, XP e maestria | Intervallo × 3,0 / 2,5 / 2,0 / 1,5 (Apprendista, Garzone, Esperto, Maestro) rispetto al giocatore senza attrezzo; XP e maestria al 25%. **Misura M12-07** (sim 8 h, 3 semi): tre aiutanti Maestro = 0,448 dell'XP/h del giocatore (invariante ≤ 1 rispettata); contratto Maestro con `chance_pct` 0,01 (minimo del validatore, invece di 0,005): ~1 ogni 50 h | F-101, F-102, `balance.json` `helper.*`, M12-02, M12-07 |
| Q60 | Traguardi della maestria per risorsa | 25 sottoprodotto raro, 50 bonus della risorsa, 99 bonus permanente del mestiere (piccolo, si somma tra le risorse); valori in `02_FORMULAS.md` §8.8b. **Misura M12-07**: Polvere ~38-79/h, Schegge 2,6-4,1/h per famiglia, Pietre 0,16-0,25/h; i Cristalli diretti non cadono nelle Miniere | F-103, `data/actions/` (`milestones`), `data/mastery/`, M12-03, M12-05 |
| Q61 | Cristallizzare: probabilità per livello e fallimento | 40% al livello 1 → 90% al 99 (lineare); fallimento = metà della polvere persa. **Misura M12-07**: primo Cristallo del risveglio dopo 0,2-0,4 h, del mutamento 0,5-1,0 h, dell'ascesa 0,8-1,7 h; prima Pietra perfetta dopo 1,9-2,9 h | F-104, `balance.json` `engraver.*`, M12-04 |
| Q62 | Runa di grado V troppo costosa da farmare: V = 81 rune di grado I (`rune.upgrade_ratio`^4); farming 7,7-37 h, la Runa del baluardo V ≈ 93 h (misura M12-07) | **CHIUSA 2026-11-09**: regola III in 5-10 h, V in 50-100 h per tutte le rune (`DECISIONS_LOG.md` Q62), dati ritarati. Default originale: lasciare; da tarare dopo la prova (quantità o frequenza del drop delle rune più rare, o `rune.upgrade_ratio`) | F-107, `balance.json` `rune.*`, M12-07 |

## Fratture come mappe (M13, `FRATTURE.md` riportata da R-04)

I documenti sono già scritti con questi default. I numeri non presenti nella fonte sono valori di partenza **da tarare** in M13-06 (`tools/sim_fracture.gd`).

| # | Domanda | Default proposto | Dove impatta |
|---|---|---|---|
| Q63 | Gruppi per Frattura | **Tarata in M13-06**: 16 più il boss (`fracture.groups`, erano 30: con 30 i gradi alti superavano i 45 minuti); obiettivo di durata 15-30 minuti nel grado giusto: la sim dà 14-29 minuti (il grado 1 è a 13,9, appena sotto); boss ritarati (PV, livelli, `heavy_strike` più deboli, evocazioni più rade) e `monster_pct` 0,5 (Q64). Deviazione: a 10 livelli sotto il consigliato i gradi 2-4 e 8-9 si vincono comunque quasi sempre (il personaggio della sim ha pezzi comuni +0 del suo livello); misure in `06_ROADMAP.md` | F-50, `balance.json` `fracture.groups`, M13-02, M13-06 |
| Q64 | Probabilità di Carte da mostri, Monoliti, Fratture e boss; grado dalle fonti; scala dei gradi | tarate per l'obiettivo "~1 Carta di grado uguale o superiore per Frattura" e "una Carta ogni 2-4 ore di combattimento nell'area giusta" fuori dalle Fratture; valori di partenza in F-113 (`monster_pct` 0,4, `boss_pct` 70, delta [70, 27, 3] e [20, 70, 10]), gradi dalle fonti e tabella dei gradi in F-110. Scelte di R-04 incluse nel default: la Carta si **consuma all'apertura**; dopo la Frattura il combattimento **torna all'area** in cui si stava combattendo; il bottino non consegnato per Deposito pieno resta **in attesa** (non si perde), una Carta caduta con il Deposito pieno invece **si perde** | F-110, F-113, F-116, `balance.json`, `loot_tables.json`, M13-02, M13-04, M13-06 |
| Q65 | Modificatori per rarità e tabella iniziale | comune 0, magica 1-2, rara 3-4; 12 modificatori (F-111), un solo tipo di rischio per Carta; rischio e premio con la stessa intensità (11 gradini); i quattro più forti da grado 5 in su | F-109, F-111, `data/maps/map_mods.json`, M13-01, M13-04 |
| Q66 | Gradi e livelli dell'equipaggiamento | 15 gradi, requisiti di livello 1, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 60, 70, 80, 90 (`equipment.grade_levels`); i materiali restano 8 (`equipment.grade_material` 1,1,2,2,3,3,4,4,5,5,6,6,7,7,8) **[Chiusa in M14-10: confermati, nessun cambio]** | F-118, `04_DATA_SCHEMA.md` §5, M14-05 |
| Q67 | Formula di Armatura e Barriera | `A / (A + k × (livello + 10))` con `k` 6 e massimo 75% (`combat.armor.{k, level_offset, cap_pct}`); budget per set `8 × livello + 4`; da tarare con la sim **[Chiusa in M14-10: confermati `k` 6, offset 10, tetto 75%; set completo al livello 1, 50 e 90 = 15,4%, 52,9% e 54,7% (stat principale), nessun set raggiunge il tetto]** | F-25, F-117, M14-02, M14-10 |
| Q68 | Costo dei progetti | circa 3× le quantità di oggi più 2 componenti rari diversi (`blueprint.cost_mult` 3, `blueprint.extra_rare`); durata invariata **[Chiusa in M14-10: confermati `cost_mult` 3 e `extra_rare` 2; progetti 0,4% a uccisione, 0,8-1,6 all'ora]** | F-90, F-119, M14-03 |
| Q69 | Obiettivi di drop | 3-5 pezzi ogni 30 minuti nell'area giusta, circa 1 magico ogni 30 minuti, 1 raro ogni 2-3 ore, 1 leggendario ogni 15-30 ore di Fratture del grado giusto; valori di partenza in F-121 (`loot.equipment`) **[Chiusa in M14-10: `loot.equipment.chance_pct` 2,5 -> 2,9; `rarity.drop` resta 25 e 5: 3,6-4,7 pezzi ogni 30 minuti, 0,7-1,0 magici ogni 30 minuti, un raro ogni 1,9-2,8 ore; leggendari dei boss 0,8% -> 0,6% (un leggendario ogni 17-26 ore di Fratture), Monoliti 0,3%]** | F-84, F-121, M14-05, M14-10 |
| Q70 | Bonus di maestria ogni 10 livelli | raccolta: −2% intervallo e +1% prodotto doppio; artigianato: +2% conservazione e −2% intervallo, per ogni 10 livelli di maestria dell'azione (`mastery.step`) **[Chiusa in M14-10: confermati `mastery.step` ogni 10 livelli con i valori indicati]** | F-122, M14-08 |
| Q71 | Drop di Polvere del Rift | 8% per uccisione, 1 pezzo (era 20%, 1-2); usi nuovi: raffinazione dal +5, borse rinforzate e oltre, Cristalli **[Chiusa in M14-10: confermata 8% x 1: 58-109 Polvere all'ora (era ~150); raffinazione dal +5 con 10-50]** | `02_FORMULAS.md` §8.5b, F-86, M14-05 |
| Q72 | Tetto ai rischi delle Carte | somma dei punti di rischio ≤ 40 al grado 1, +10 per grado (`fracture.risk_cap`); unità di `pack_bonus` 20 e `pulse` 5 (`fracture.risk_unit`) **[Chiusa in M14-10: confermati `fracture.risk_cap` 40 + 10 per grado e `risk_unit` 20 e 5]** | F-123, M14-09 |
| Q73 | Numero di leggendari per l'alpha | 3 per slot (39 in tutto: 10 slot di pezzo + 3 attrezzi); un quarto per slot solo dove avanza tempo **[Chiusa in M14-10: confermati 39 (30 pezzi + 9 attrezzi)]** | `NOMI.md`, M14-04, M14-05 |
| Q74 | Barriera su quali armature | solo Tessuto runico (alta) e Cuoio (bassa); le Piastre non hanno Barriera (`combat.armor.materials`) **[Chiusa in M14-10: confermato]** | F-117, F-118, M14-02 |
| Q75 | Capolavori di Cuoio e Tessuto runico | **No nell'alpha**: i progetti creano Capolavori di Piastre (armature), armi e scudi; manca un mestiere che produca cuoio e tessuto (seconda classe o mestiere futuro) **[Chiusa in M14-10: confermato: No nell'alpha]** | `01_GDD.md` §28, M14-03 |
| Q76 | Fonti dei leggendari | 30 leggendari di pezzo dai boss delle Fratture (3 per boss, ognuno ~0,8% a vittoria) e 9 attrezzi dai Monoliti (~0,3% per Monolito); niente "boss rari" nell'alpha **[Chiusa in M14-10: boss 0,6% a vittoria (era 0,8%), Monolito 0,3%]** | F-120, `NOMI.md`, M14-04 |
| Q77 | Danno delle armi e velocità | spada: 2000 ms, `dmg_max` 6 + 4 (g−1), minimo 60%; spadone: 3200 ms, 12 + 8 (g−1), minimo 50%; con due spade ogni colpo usa il danno e la velocità dell'arma che colpisce **[Chiusa in M14-10: confermati; la ritaratura di M14-10 ha cambiato PV, oro e XP dei mostri (F-28, `combat.kill_xp_mult` 0,11 -> 0,064), non i danni delle armi]** | F-22, F-118, M14-01 |

## Monoliti da Metin (M15, `METIN.md` riportata da M15-01)

| # | Domanda | Default | Chi/quando |
|---|---|---|---|
| Q79 | Livello e forza degli evocati: oggi solo i livelli sono quelli del Monolito (PV, danno, ricompense invariati); serve una scala in più (come F-110 con `hp_mult`)? | solo livelli, `min(99, L)` | QA, M15-08 |
| Q80 | I pezzi nel Bottino occupano una casella del Bottino (F-33) come un tipo di oggetto? Con 28 mostri e molti pezzi il Bottino può riempirsi | no, come implementato: nessun limite di pezzi nel Bottino (M15-04) | utente / QA |
| Q81 | Nel Deposito i pezzi restano a occupare una casella ciascuno (F-100) o la sezione "Pezzi" non occupa slot? | invariato: una casella ciascuno | utente |
| Q83 | Pezzi nel Bottino: online la morte li perde, offline sono messi al sicuro a ogni blocco da 60 s (`collect_pieces`). Va allineato (online al sicuro, o offline a rischio)? | invariato (differenza accettata) | utente |
| Q84 | Falegname (V7): RISOLTA 2026-11-13 → Villaggio (DECISIONS_LOG V7, brief in `M19_VILLAGGIO.md`) | M19 | utente |

## Aperte da M17

| # | Domanda | Default | Chi/quando |
|---|---|---|---|
| Q86 | Cibo con il kit iniziale fuori dalle Pianure: `sim_survival` stima 2.700-18.800 pezzi di cibo/h senza armatura ai livelli 20-60. Le aree si sbloccano con un requisito di equipaggiamento (oltre al livello), oppure il kit/il cibo scalano con l'area? | nessun cambio: oggi il solo requisito è il livello; l'armatura va forgiata prima di salire | utente / M18 |
| Q87 | Ritratto e layout a 1280x720 della pagina di combattimento (M17-05/07: mappa cliccabile, gruppi fino a 8, effetti) da verificare a schermo | nessun cambio finché non verificato da una persona | utente / QA |

## Chiuse

| # | Domanda | Decisione | Data |
|---|---|---|---|
| Q78 | Taratura dei PV del Monolito | Decisione utente: PV invariati (`metin.hp_base` 200, `metin.hp_per_level` 0,25) anche se i tempi variano da 182 s (Pianure L10) a 54 s (Soglia L80); ritaratura rimandata | 2026-11-10 (M15-09) |
| Q82 | Frequenza dei Monoliti per area e pietà | 1-2 Monoliti/h per area, Pianure 0,6, pietà `rift_stone.pity_kills` 300 confermati | 2026-11-10 (M15-09) |
| Q85 | Tasso di drop equip (V5): ritarare o no dopo la misura di M17-02? | Applicato **4,0%** (`sim_drop_rate`), progetti allo 0,5%; in M17-03b | 2026-11-12 (M17-03b) |
| Q26 | Nodi della maestria di Minatore e Pescatore uguali a quelli del Boscaiolo? | Chiusa dalla decisione W4: albero dei nodi diverso per ogni mestiere di raccolta, più 3 traguardi propri per ogni risorsa (`02_FORMULAS.md` §8.8, §8.8b) | 2026-11-08 (R-03) |
| Q55 | Nomi delle valute in `NOMI.md` scambiati rispetto ai dati | `NOMI.md` corretto, i dati restano | 2026-11-08 (P-04) |
| Q6 | Munizioni per Mira e rune/consumabili per Arcano? | Niente munizioni né rune; la classe dell'MVP usa solo spade (D6); archi e bastoni tornano con le loro classi | 2026-11-03 (`VISIONE_V2.md` §8) |
| Q9 | Stance con bonus nascosti? | La stance è tolta: tutta l'XP va al personaggio (D3, F-28) | 2026-11-03 |
| Q10 | Attacchi speciali o abilità delle armi? | Sì: abilità attive automatiche della classe, 2 per assetto (`01_GDD.md` §20.2, M6) | 2026-11-03 |
| Q49 | Frequenza dei progetti (in 8 h offline nelle Miniere liv. 50 nessun progetto) | Verificata, nessuna ritaratura dei dati: ~1 progetto/h (mostri + 1 Pietra su 3) in tutte le aree; lo zero osservato era varianza (probabilità < 0,5% con il valore atteso). `sim_combat` riporta ora `bp/h` e `bp lost/h`. Confermata da M12-07 (`sim_m12`): 0,9-1,0 progetti/h | 2026-11-08 |
