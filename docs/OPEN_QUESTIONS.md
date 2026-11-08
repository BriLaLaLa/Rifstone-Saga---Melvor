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
| Q26 | I nodi della maestria di Cavatura e Lenza devono differire da quelli di Selvicoltura (es. Cavatura più `double_item_chance`, Lenza più `rift_shard_chance`)? Le stat di raccolta del registro sono solo cinque e Selvicoltura le usa tutte | No per ora: stessi costi, prerequisiti, stat e valori di §8.8, nomi e testi a tema (M2-02); da rivedere con Q15 dopo una prova di gioco |

## Offline

| # | Domanda | Default proposto |
|---|---|---|
| Q16 | Limite offline aumentabile (es. voce dello shop)? | No: 12 ore fisse |
| Q17 | Si può interrompere la simulazione offline? | No; deve durare < 10 s |
| Q18 | Le Fratture (M12) avanzano anche offline? | Sì, con la stessa simulazione |

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
| Q33 | Capienza iniziale dell'Armeria | 40 + caselle nello shop (`armory_slot`) | F-82 |
| Q34 | Livello massimo del personaggio | 99, curva `character_curve` | F-71 |
| Q35 | Livelli di apertura degli slot dei tratti | 1, 10, 25, 50 | F-78 |
| Q36 | Slot delle abilità | 2, il 3° al livello 30 | F-78 |
| Q37 | Archi e bastoni restano nei dati (non equipaggiabili) o si tolgono fino alle loro classi? | Si tolgono: oggetti e ricette tornano con le classi future | M4-02 |
| Q38 | Dimensione dei gruppi | 1-6, più grandi nelle aree alte | §8.5, `combat.max_pack_size` |
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
| Q49 | Frequenza dei progetti | circa 1 progetto all'ora nell'area del proprio livello; 1 su 3 Pietre del Rift | M10-04, F-84 |
| Q50 | Livello del Fabbro per scegliere un affisso | 50 | F-92, `blueprint.choose_affix_level` |
| Q51 | Kit iniziale | spada, spadone, scudo comuni di grado 1 + 3 attrezzi a +0 + 20 pesci cotti di grado 1; spada e scudo indossati, cibo scelto (assunzione di R-01, da confermare) | `start.*`, `01_GDD.md` §1.1 |
| Q52 | Gli id interni cambiano con i nomi? | No: cambiano solo i nomi visibili (`name`, `description`); gli id restano | M10-05 |
| Q53 | Valori di partenza della riforma **non presenti nelle fonti** (da tarare con `sim_combat`/`sim_gear_economy` in M10-07 o dopo la prova): quantità di piastre/impugnature/telai e del componente raro per progetto (02 §8.2: 4-10 piastre, 0-2 componenti di legno, 3 rari); `blueprint.xp_mult` 1,5; `rare_base_pct` 10 e `rare_per_forging_level` 0,5 (F-91); `chosen_affix_tier` 2 (F-92); `per_level` del Fabbro 0,4 (F-93); tabella F-94 (livelli minimi dei passi tranne +4 = 25, componenti, oro, `interval_base_pct` 5, `interval_per_level_pct` 2, `upgrade_extras`); `component_ratio` 0,4 (invariato); piastra = 2 lingotti; un'area di grado `g` lascia progetti di grado `g` e `g+1`; un solo componente raro per grado | come scritto in `02_FORMULAS.md` §5c e §8.2 | F-90…F-95, M10-04, M10-07 |
| Q54 | B1: come rallentare il livello del personaggio (da ~50 → 95 in una notte offline a: livello 99 in 250-350 h; da 50 a 60 in una notte; massimo +12 livelli dopo il 50 in una notte) | **Tarato in M10-07**: `combat.kill_xp_mult` = 0,11 e XP delle Miniere Crepate a 0,8 × (4 × PV) (moltiplica l'XP per uccisione, F-28), da tarare con `tools/sim_combat.gd` (anche offline) in M10-07; in alternativa o in aggiunta si può cambiare `character_curve` (F-71). Conseguenza: gli esempi di F-28 e i test cambiano insieme al valore | F-28, F-71, M10-07, Q41 |

## Chiuse

| # | Domanda | Decisione | Data |
|---|---|---|---|
| Q6 | Munizioni per Mira e rune/consumabili per Arcano? | Niente munizioni né rune; la classe dell'MVP usa solo spade (D6); archi e bastoni tornano con le loro classi | 2026-11-03 (`VISIONE_V2.md` §8) |
| Q9 | Stance con bonus nascosti? | La stance è tolta: tutta l'XP va al personaggio (D3, F-28) | 2026-11-03 |
| Q10 | Attacchi speciali o abilità delle armi? | Sì: abilità attive automatiche della classe, 2 per assetto (`01_GDD.md` §20.2, M6) | 2026-11-03 |
