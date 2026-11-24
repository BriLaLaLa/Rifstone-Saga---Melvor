# M38: Casa d'Aste come quella di World of Warcraft (proposta)

> **Stato**: proposta del Reviewer, in attesa delle scelte dell'utente. Nessun codice toccato. Dopo la scelta: V in `DECISIONS_LOG.md`, Q in `OPEN_QUESTIONS.md`, GDD/formule/schema/interfacce
> `_M38`, `07_TASKS_M38.md`. (WoW solo come idea di meccanica e di UI; clean room invariata.)

## 1. Richiesta dell'utente
«Come mai la %media è sempre +160 o più? Inoltre perché c'è disponibili 500/500? C'è un tetto massimo? Non ha senso. Questa asta deve simulare una casa aste reale tipo quella di World of Warcraft.»

## 2. Diagnosi (verificata nel codice e nei dati)
La diagnosi dell'Orchestratore è **confermata** e ha una causa in più.

1. **Due prezzi per lo stesso oggetto.** `AuctionPricing.buy_quote` (`systems/auction/auction_pricing.gd:65`) = `qty × buy_unit(v, idx)` = `ceil_div(v × (idx + SPREAD), 1.000.000)` (F-151),
   con `SPREAD` 150 % fisso (`balance.json` `auction.buy.spread_pct`). Il **libro** (F-178, `npc_asks`) mostra invece inserzioni PNG a `v × idx × (1 + 0…25 %)`. Quindi per `redbirch_grip` (`v` 200 r, blocco 0, seed 12345)
   il libro mostra «241 × 69, 247 × 169, …» e «prezzo di mercato 240», mentre **comprare costa 541**. Il libro è solo una vetrina: non si compra da lì.
2. **«% sulla media» sempre rossa.** F-210 confronta `buy_quote` con `value_of` (il valore base `v`, non un prezzo di mercato). `unit / v` sta in `[MIN + SPREAD, MAX + SPREAD]` = **2,20 … 2,76** (`MIN` 70 %, `MAX` 126 %),
   cioè **+120 … +176 %**; al valore tipico dell'indice (115 %) **+165 %**. Non può scendere sotto +120 %: lo spread è imposto dal validatore (`SPREAD > MAX − MIN`, F-151) per il non-arbitraggio.
3. **«500/500».** `S(v) = clamp(stock.gold ÷ v, stock.min, stock.max)` (F-150, `stock.gold` 600.000 r, `stock.max` 500). È un valore **salvato** per oggetto (`auction.stock`), che si rifornisce dell'1,4 % di `S` a blocco.
   Il tetto 500 taglia **17 dei 58** oggetti acquistabili (quelli con `v ≤ 1.200` r = 12 a): `redbirch_grip` avrebbe 3.000, ne mostra 500. Serve solo a tenere finito il calcolo offline; per il giocatore è un numero senza senso.
   Contraddizione visibile: per `redbirch_grip` il libro mostra **1.193 pezzi** (`V`, F-178) e la scorta dice 500.

Numeri veri (blocco 0, `seed` 12345, `sat` 0; `idx` da F-174):
| Oggetto | `v` (r) | prezzo di acquisto oggi | % sul valore | scorta `S` | prezzo di mercato (vendita) | libro: più economica / pezzi `V` |
|---|---|---|---|---|---|---|
| `redbirch_grip` | 200 | 541 | +171 % | 500 (tetto; calcolata 3.000) | 240 | 241 / 1.193 |
| `shardcedar_grip` | 3.600 | ≈ 9.540 | ≈ +165 % | 166 | ≈ 4.140 | (calcolabile dal test F-178) |
| `seared_riftmaw` | 17.000 | ≈ 45.000 | ≈ +165 % | 35 | ≈ 19.500 | idem |
| `riftite_plate` | 59.500 | 160.402 | +170 % | 10 | 71.151 | 72.640 / 27 |
Intervallo teorico del prezzo di acquisto: 2,20 v … 2,76 v; della vendita 0,70 v … 1,26 v. Un giocatore compra a 2,2-2,76 e vende a 0,7-1,26: per questo ogni confronto «con la media» è rosso.

**Causa di fondo**: in M23 il mercato era un banco di PNG (prezzo per indice, vendi e compri contro il banco); M27 ha aggiunto il libro delle inserzioni ma **solo** per vendere (inserzioni del giocatore) e per mostrare. Il lato acquisto non è mai stato collegato al libro.

## 3. Come funziona la Casa d'Aste di WoW (idee di meccanica)
- Ogni oggetto ha **inserzioni** (di altri giocatori) a prezzo diverso; compri **dalla più economica**, e se la quantità non basta si passa alla successiva. **Non esistono scorte massime né spread fisso**: la quantità disponibile è la somma delle inserzioni.
- Il **prezzo di mercato** (di riferimento) è una **media/mediana recente** dei prezzi vera: il «% sulla media» confronta con quello; sotto = affare, sopra = caro.
- Chi vende sotto altri «undercut»; chi vende in blocco abbassa il prezzo; i prezzi derivano nei giorni e si riprendono. Ogni vendita costa **commissione + deposito**.

## 4. Opzioni

### Opzione 1: «solo i sintomi» (taglia **S**)
- Il «% sulla media» si calcola sul **prezzo di mercato** (`market_price = sell_quote(1)`, F-181) e non su `v`; `SPREAD` 150 → **60 %** (minimo del validatore: `SPREAD > MAX − MIN` = 56 %): prezzo di acquisto 1,30-1,86 v, scarto sul mercato ≈ **+45 … +60 %**, ancora sempre rosso in Compra.
- `stock.max` 500 → **99.999** (o tolto) e la UI mostra «Disponibili: N» senza «/ max»; la scorta resta una variabile nascosta.
- **Economia**: il prezzo di acquisto scende ≈ 30-35 %; nessuna fonte di oro nuova (F-151 vale ancora: `unit > vendita al tetto`). Il validatore dei progetti (F-151, margine 3 %) va rieseguito: con 60 % il caso peggiore (`bp_mw_shield_14`) potrebbe violare il margine (da verificare con `sim_market`). **Save**: invariato (v13). **Offline**: invariato (12 h = 100 ms = 60 s).
- **Formule**: parametri soltanto (F-151, F-150, F-210). **Non risolve** l'incoerenza libro/acquisto né il senso di «mercato vero». Utile solo come ripiego.

### Opzione 2: «Libro unico» (**consigliata**, taglia **M-L**)
Si compra **dal libro** che si vede. Un solo prezzo, un solo numero di pezzi.
- **Acquisto** = percorso del libro dalla più economica (F-178): comprare `q` pezzi costa la somma dei `q` prezzi più bassi, **passando alla successiva** quando una finisce. Il prezzo mostrato «più economica» è quello a cui compri 1 pezzo. Niente spread fisso: il premio è nelle inserzioni (`ask_min_pct` `LO` 0 → ≈ **20 %**, `ask_max_pct` `HI` 25 → ≈ **60 %**, da tarare con la simulazione). Le inserzioni del giocatore sono nel libro ma non si comprano da soli.
- **Quantità disponibile** = `V − taken` (somma delle inserzioni del libro meno quanto già comprato): **nessun tetto, nessuna `S`**. Stato nuovo per oggetto `taken` (pezzi comprati dal libro), che torna a 0 col rifornimento già esistente `r_i` a blocco (F-172, F-175: la stessa regola, solo senza tetto), `taken ≤ V` letto con clamp. Dopo un acquisto il libro è «più vuoto» in basso: il prezzo successivo sale, come in WoW.
- **Prezzo di riferimento («media recente»)**: mediana delle `ask` minime degli ultimi `W` mezzi-orari (epoche di F-178; `W` = 24 ≈ 12 h) calcolate senza saturazione, **derivate** da seme e blocco (F-146/F-173/F-178), niente stato salvato. «% sulla media» (F-210 riscritta) = scarto del prezzo mostrato da quel riferimento: in Compra le inserzioni economiche sono verdi (−), le care rosse (+); in Vendi il «Vendi subito» è sotto il riferimento (vale come offerta al banco; `v × idx` contro ≈ 1,2 v × idx) e **metti in vendita** si confronta col riferimento: il giocatore capisce che conviene l'inserzione.
- **Deriva dei prezzi PNG con seme**: già c'è (drift F-146, onde F-173, ricarichi F-178 per epoca); nessuna formula nuova per la deriva.
- **Non-arbitraggio**: tolto lo spread, serve un nuovo vincolo: per ogni oggetto, prezzo di acquisto del pezzo più economico `v × idx × (PPM + LO)/PPM²` > ricavo di un pezzo in qualunque vendita futura (Vendi subito `v × MAX`, inserzione al massimo del libro `v × MAX × (PPM + HI)/PPM²` al netto di commissione). Con `LO` ≈ 20 % **non basta da solo** sull'oscillazione 1,05-1,254 dell'equilibrio (comprare basso e vendere alto): serve `(PPM + LO) × (BASE − AMP − PB−) > MAX × PPM` (≈ `LO ≥ 20 %` con i valori di partenza) **e** che anche l'acquisto sposti la saturazione (stesso `STEP_i`, simmetrico alla vendita), così sell-then-buy perde sempre. Si verifica con `sim_market` (strategie (2) e (7) estese all'acquisto sul libro). Resta come oggi: gli acquistabili non sono ingredienti, i progetti hanno margine 3 % (da rieseguire).
- **Economia**: il prezzo di acquisto scende da 2,2-2,76 v a ≈ 1,35-1,9 v (−30 … −35 %): è un cambio di bilanciamento visibile (comprare componenti diventa più comodo rispetto a produrli). **Nessuna fonte di oro nuova**: l'oro esce dal giocatore ai PNG come oggi; il tetto di arbitraggio vale per vincolo. Da dire al giocatore nelle note di versione.
- **Save**: **v13 → v14 additivo**: nuovo `auction.taken` `{item: int}`; `auction.stock` si **ignora** alla lettura (a v14 non esiste più; migrazione banale: scarta `stock`, `taken` = 0). Un save v13 si carica; i pezzi comprati prima restano nel Deposito.
- **Bilanciamento**: `sim_market` (soglie (1)-(8) di F-151/F-176/F-182) da rivedere: (1) «`unit` > vendita al tetto» diventa «ask minima > vendita»; (5) e (8) invariati; nuova (10): compra-vendi su 48 h con acquisto sul libro non guadagna. Costo di un acquisto: 58 oggetti × `K` inserzioni per calcolare il libro, già fatto per la vista; **cache per epoca**.
- **Offline**: il libro e `W` mediane si ricalcolano **per epoca**, non per blocco; l'avanzamento di `taken` è lineare (`max(0, taken − n·r_i)`), additivo in `n`: **12 h = passi da 100 ms = blocchi da 60 s** invariato (test F-184 esteso). Costo: nessuno in `advance` (la mediana è derivata solo quando la UI la chiede).
- **Formule da cambiare**: F-150 (sostituita: `taken` al posto della scorta), F-151 (sostituita: acquisto = percorso del libro; nuovo vincolo di non-arbitraggio), F-152/F-176 (tendenza invariata nella forma), F-178 (invariata; la vista «più economica» e `V` sono già lì), F-181 (suggerito invariato), F-182 (vincoli: ricalcolati con `LO`), F-210 (riferimento = mediana recente), F-211 (`max_buyable` sul libro), F-172 (`r_i` senza tetto `S`). Nuove: F-214 mediana recente, F-215 acquisto sul libro, F-216 `taken`. F-172, F-173, F-174 (indice), F-175 (vendita) restano.
- **Interfacce**: `buy_quote` e `stock` restano come firme (`stock` ritorna `V − taken`), `stock_max` è tolta o ritorna `V`; nuova `reference_price(item)`; `buy` consuma `taken`. Cambia il significato di segnali già esistenti, non le firme (05 §5.30; sono solo da leggere con il Reviewer).
- **Lacuna nota** (da dire): le inserzioni PNG non si «consumano» una per una come in WoW (`taken` consuma le più economiche): una persona che compra la prima inserzione la vede sparire, ma non c'è un registro che si ricorda quale.

### Opzione 3: «Registro vero» (taglia **L-XL**)
Come l'opzione 2, ma le inserzioni PNG sono **oggetti con stato**: ogni oggetto ha un registro salvato di inserzioni (id, prezzo, quantità, scadenza), generato a ogni epoca da un generatore con seme, che **scade**, che **si consuma una per una** dai compratori PNG e dai giocatori, con **prezzo storico salvato** (un punto per ora, 7 giorni) per mediana vera e **grafico dei prezzi** (già rimandato da M37).
- **Economia**: come opzione 2, più «eventi» possibili (gluts, scarsità) fuori scope. **Save**: **v14** con un registro (≈ 130 oggetti × ~8 inserzioni ≈ 1.000 voci; ~40-60 KB per slot) + serie storica (130 × 168 punti): **migrazione non banale** (inizializzare dal libro derivato). **Offline**: il generatore gira per blocco (144 blocchi × 130 oggetti): da misurare (<100 ms è fattibile solo con cache e generazione per epoca). **Formule**: sostituisce F-178 e F-179 (libro, domanda) e F-180 (vendita del giocatore), quindi anche la migrazione di M27.
- **Rischio**: riscrive le inserzioni del giocatore di M27 e tutti i test di equivalenza; non è una correzione ma un nuovo sistema. Valore aggiunto sulla 2: serie storica reale e inserzioni che si consumano una a una.

## 5. Confronto
| | Opzione 1 | **Opzione 2** | Opzione 3 |
|---|---|---|---|
| Un solo prezzo (libro = acquisto) | no | **sì** | sì |
| «% sulla media» sensata | meno rossa, ancora sempre positiva | **sì (mediana recente)** | sì (mediana vera) |
| Tetto 500 | tolto o spiegato | **tolto: quantità = somma delle inserzioni** | tolto |
| Save | v13 invariato | **v14 additivo** (`taken`) | v14 con registro e storico |
| Offline 12 h = 100 ms = 60 s | invariato | **invariato** | da dimostrare |
| Economia | acquisti −30 %, margine progetti da riverificare | **acquisti −30…−35 %, progetti da riverificare** | come 2 |
| Taglia | S | **M-L** | L-XL |

**Raccomandazione: Opzione 2.** Risolve le tre incoerenze con poco rischio (stesso libro già testato, `taken` additivo, derivata senza stato), lascia M27 intatto e prepara l'Opzione 3 (grafico e storico) senza buttare nulla. L'Opzione 1 solo se si vuole una correzione immediata senza toccare il bilanciamento.

## 6. Domande per l'utente
1. **Opzione**: 1 (sintomi), **2 (libro unico, consigliata)**, 3 (registro vero)?
2. **Prezzo di acquisto**: accetti che scenda di circa il 30 % rispetto a oggi (default `LO` 20 %, `HI` 60 %, da tarare con la simulazione)? Oppure si resta più cari?
3. **Riferimento «media»**: mediana delle ultime **12 h** (default `W` 24) o altro (6 h / 24 h)?
4. **Vendi subito** (offerta al banco, sotto il riferimento) e **Metti in vendita** (prezzo pieno meno 5 % e deposito): confermi di tenerli entrambi? In WoW esiste solo l'inserzione.
5. **Save v14** ammesso? (scarta `auction.stock`, nessuna perdita di oggetti o monete.)
6. **Ambito**: includere ora il grafico dei prezzi (richiede l'Opzione 3 o una serie storica salvata), o dopo?
7. Cosa fare delle Q **Q237-Q245** (M37, filtri e storico): restano tutte valide con l'Opzione 2.

## 7. Task previsti dopo la scelta (opzione 2; file disgiunti)
CORE `systems/auction/` (acquisto sul libro, `taken`, riferimento, save v14, migrazione) · DATA (`balance.json`, `auction_items.json` invariato, `population.json` invariato) · UI dettaglio (`auction_page` di Compra: riga «Disponibili», prezzo, «% sulla media») · UI lista · QA (`sim_market` (10), equivalenza offline, v13→v14) · REV (docs, interfacce).
