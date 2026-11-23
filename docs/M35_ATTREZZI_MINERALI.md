# M35-D: attrezzi di raccolta e tab delle risorse (proposta, da scegliere)

Stato: **PROPOSTA**, nessun codice. Autore: Reviewer (sessione D). Dopo la scelta dell'utente: V in `DECISIONS_LOG.md`, Q in `OPEN_QUESTIONS.md`,
GDD/formule/schema/interfacce e `07_TASKS_M35.md`.

Richieste dell'utente: (1) gli attrezzi sono diventati inutili o quasi, ripensarli e ripensare l'upgrade; (2) la tab dei minerali del Minatore è solo
visiva: cosa può diventare ("Altro" o un'altra vista), come renderla utile.

## 1. Cosa fa oggi (verificato su dati, formule e UI)

### 1.1 Attrezzi (`01_GDD.md` §9, §23.1; F-94; `data/items/tools.json`; `balance.json` `tool_upgrade`)
- Tre attrezzi unici (Accetta, Piccone, Canna), sempre indossati, +0…+9, riuscita certa. **L'Erboristeria non ne ha** (`TOOL_SKILLS` in `skill_page.gd` ha 3 voci).
- Effetto: `skill_interval_pct` da −5 (+0) a −23 (+9), più `double_item_chance` +2 a +5 / +3 a +9 (Pesca: `rift_shard_chance` +10 / +15).
- Costo: piastre e manici del grado, oro, livello del mestiere. Nota: in `balance.json` l'oro del passo è **100 volte** la tabella di F-94
  (10.000 … 4.000.000 contro 100 … 40.000): `02_FORMULAS.md` è rimasta indietro, da riallineare in ogni caso.

### 1.2 Perché sono inutili
Dal M24 la raccolta avviene solo nei **nodi** del ciclo degli incontri e il nodo rende **unità fisse** (`encounters.node_units` 80, F-155/F-162):
- `skill_interval_pct` accorcia solo la **durata** del nodo (12.000 ms, minimo 3.000), **non** le unità. Un nodo è ~12,6 s su un ciclo medio di ~41,8 s
  (F-165) e i nodi di una disciplina sono ~8% dei cicli. Stima da F-165 (da confermare con `sim_encounters`): −23% di durata = circa **+0,6% di unità/ora**.
  (Prima del M24 l'intervallo era la velocità di raccolta e contava davvero: il valore è rimasto, il significato no.)
- Conta davvero solo `double_item_chance`: circa **+5% di unità/ora** a +9 (+2% a +5), per ~4M di oro e 8 gradi di componenti.
- `rift_shard_chance` della Pesca: marginale (Frammento, F-07).
- L'attrezzo non cambia **cosa** o **come** raccogli. L'upgrade è lineare, senza scelte, riesce sempre: è solo una coda di costi.

## 2. La tab dei minerali (pagina del Minatore, uguale per Boscaiolo, Pescatore, Erbalista)
Dal M24 (`skill_page.gd` `_build_extras`, `ActionCard`, `NodeColorPreview`, `GatheringInfo`) la pagina di raccolta è **sola lettura**: una scheda per
risorsa (livello, XP, intervallo, prodotto, "Colore ora", maestria), la riga "Si trova in" e il pannello attrezzo. Non si avvia nulla.
Il giocatore **non può influire su quale risorsa** esce: F-154 sceglie sempre la più alta ≤ `min(L, M)`. Conseguenze:
- il **rame** non si raccoglie più dopo il livello 10 del Minatore (resta la Casa d'Aste), ma serve per le piastre del grado 1 e per le ricette basse;
- la **maestria** per risorsa non si può far crescere sulle risorse basse;
- "Colore ora" informa ma non c'è nulla da fare con quell'informazione.
È un listino. Due leve la rendono utile: **scegliere** la risorsa (M1) e **leggere** a cosa serve ciò che si ha (M2).

---

## 3. Opzioni per gli attrezzi

### A1. Effetti sul nodo (rendere reali gli stessi valori)
Stesso schema +0…+9, ma gli effetti passano da `skill_interval_pct` a stat che lavorano sul nodo: **unità per nodo** (`node_units_pct`, F-162 `Ne`),
**probabilità di nodo ricco** (`node_rich_chance`, F-164), `double_item_chance`, sottoprodotto (`byproduct_chance_pct`, F-103). Sempre lineare.
- Economia: +10…+25% di unità/ora a +9 invece di +5%; costi invariati (da ritarare con `sim_encounters`).
- Save: **nessuna modifica** (cambiano `tools.json` e `balance.json`; le istanze hanno `upgrade`, gli effetti si ricalcolano).
- Bilanciamento: facile (una curva); resta "solo numeri", poca identità. Codice: S (3 stat in `stats.json`, `NodeWork`/`GatheringResolver`).

### A2. Specializzazioni (consigliata, include A1)
Ai passi **+3, +6, +9** il giocatore sceglie **una di due teste** dell'attrezzo. Esempi: Piccone «Punta da filone» (+unità per nodo) oppure «Martello da
cava» (+probabilità di nodo ricco e +tentativi in nodo ricco); Accetta «Lama larga» (+unità) / «Scure fine» (+sottoprodotto); Canna «Rete» (+unità) /
«Amo fine» (+Frammento e nodo ricco). Le scelte si cambiano pagando solo oro (`respec_gold`). Gli effetti base di ogni passo sono uguali per tutti e piccoli
(A1). In più un **quarto attrezzo** per l'Erboristeria: **Falcetto** (slot `tool_herbalism`, kit iniziale come gli altri; «Cesto» +unità / «Mazzo scelto» +doppio).
- Economia: potenza totale come A1 (le scelte sono laterali, non più forti); il respec è un pozzo di oro nuovo e piccolo; nessuna fonte di oro.
- Save: **additivo** nella v12: `equipment.tool_choices` (`{slot: [scelta+3, scelta+6, scelta+9]}`); lo slot `tool_herbalism` si crea al caricamento se
  manca e il Falcetto si dà a +0 a chi non lo ha (test). Nessuna migrazione di versione.
- Bilanciamento: tabella `tool_upgrade.choices` in `balance.json` (unica definizione) e formula nuova «effetto della scelta»; la sim controlla che nessuna
  scelta superi l'altra di oltre il 10%. Codice: M-L (stat, scelta, comando `Armory.choose_tool_head`, UI di scelta, Falcetto, validatore).

### A3. Attrezzo che sblocca (gate)
Il grado dell'attrezzo (+N) decide la **risorsa più alta** lavorabile (es. Piccone +4 per il Ferro nero), oltre al livello della disciplina.
- Economia: attrezzo **obbligatorio**, progressione legata all'oro (4M a +9): blocco duro per chi non ha oro.
- Save: additivo, ma **contraddice** F-154 («si lavora sempre») e il tutorial. Sconsigliata: punisce invece di dare interesse.

**Raccomandazione attrezzi: A2.**

## 4. Opzioni per la tab delle risorse

### M1. Raccolta mirata (consigliata)
Ogni disciplina di raccolta ha una **risorsa scelta** (`focus`), impostabile dalla scheda («Raccogli questa»), oppure **Automatico** (oggi). Nei nodi di
quella disciplina la risorsa è la scelta **se** `level(a) ≤ min(L, M)`, altrimenti la migliore (come oggi) e la UI lo dice («Qui puoi lavorare fino a X»).
Il colore resta F-154: una risorsa bassa dà **XP grigia**, quindi la scelta è reale (materiale/maestria contro XP) e non inflaziona: unità per nodo uguali.
- Economia: nessuna fonte nuova; sposta l'offerta di materiali bassi verso chi li serve (piastre, attrezzi, Bacheca), meno pressione sulla Casa d'Aste.
- Save: **additivo**: `disciplines.focus: {skill: action_id}` nella v12 (assente = Automatico). Id non valido al caricamento: torna ad Automatico (test).
- Formule: **F-154 modificata** (solo la risorsa); durata, resa e colore invariati. Offline già deterministico (il focus è stato fisso).
- Codice: S-M (`NodeWork.begin`, comando `Disciplines.set_focus`, segnale, UI).

### M2. Vista "Risorse" (informazione, senza stato)
La scheda diventa **riga di tabella** con filtro: scorta nel Deposito, **a cosa serve** (ricette, attrezzi, incarichi: indice «Serve a» esistente), prezzo
di vendita, maestria e prossimo bonus. Tab «Altro» del Deposito = vista per tipo (minerali, legni, pesci, erbe) con le stesse righe.
- Economia/save/bilanciamento: nessuno (solo UI). Da sola resta di sola lettura.

### M3. «Ciò che serve» (modo derivato di M1, seconda fase)
Terzo valore del focus: il nodo lavora la risorsa **più scarsa** tra quelle richieste dalla **coda di produzione** e dagli incarichi attivi (ingredienti
mancanti), nei limiti di F-154; niente da fare → Automatico. Dato derivato.
- Economia: come M1. Save: solo il valore `need` del focus (additivo). La risorsa si fissa all'inizio del nodo (la coda può cambiare durante).
- Codice: M (fabbisogno nel modello, test).

**Raccomandazione tab: M1 + M2; M3 in un task separato dopo.**

## 5. Riepilogo
| | Save | Migrazione | Economia | Taglia |
|---|---|---|---|---|
| A1 | nessuno | no | +10-25% unità/ora a +9 | S |
| **A2** | `tool_choices`, slot Falcetto (additivo) | no | come A1 + piccolo pozzo di oro | M-L |
| A3 | additivo | no | blocco progressione | M |
| **M1** | `disciplines.focus` (additivo) | no | neutra | S-M |
| M2 | nessuno | no | neutra | S |
| M3 | `focus = need` (additivo) | no | neutra | M |

Il save resta v12 con tutte le opzioni.

## 6. Domande per l'utente
1. Attrezzi: A1, **A2** o A3 (o altra idea)?
2. Erboristeria: aggiungere il **Falcetto** (4º attrezzo) sì/no?
3. Tab: **M1 + M2**; M3 ora o dopo?
4. Con M1, risorsa scelta troppo alta per l'area: cade su **Automatico** (default) o il nodo si salta?
5. Oro degli upgrade: tenere i valori di `balance.json` (×100 rispetto a F-94) e correggere il documento? (default sì)
