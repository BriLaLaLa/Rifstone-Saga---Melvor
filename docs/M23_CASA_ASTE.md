# M23 — Casa d'Aste (versione semplice) — richiesta del proprietario

Fonte storica delle decisioni V14… (da registrare in `DECISIONS_LOG.md`). I task leggono i documenti canonici, non questo file.

Nuova struttura del Villaggio in cui il giocatore vende e compra **materiali e consumabili** a prezzi di mercato variabili.
Si sblocca costruendola, come Bacheca e Mercato (M20-M21): stesso meccanismo di costruzione, `requires.village`, `map_pos` e
`page` sulla mappa, regola di non sovrapposizione del validatore. Nessun meccanismo di sblocco nuovo.

## Decisioni del proprietario
1. **Logica semplice.** Niente popolazione simulata, coorti, eventi, ordini, commercianti, inserzioni a scadenza.
2. Vale solo per **materiali, consumabili e ingredienti**. I pezzi unici dell'Armeria non si vendono né si comprano qui.
3. Prezzo di un oggetto = **valore base dei dati × indice di mercato**. L'indice **scende quando il giocatore vende**
   (saturazione), **risale col tempo** verso l'equilibrio, ed ha una **piccola variazione lenta e deterministica con seme**.
   Il giocatore deve contare poco: **tetto e minimo dell'indice sono nei dati**.
4. Il giocatore può anche **comprare** dal mercato, con **scorte limitate che si riforniscono nel tempo**.
5. **Offline**: calcolo in **forma chiusa a blocchi**, come per le altre parti del gioco; mai tick per tick.
6. **Confine**: tutta la logica dei prezzi dietro **una sola interfaccia piccola** (per esempio `MarketPricing`: dato un oggetto e
   lo stato, restituisce prezzo di vendita, prezzo di acquisto, scorta). Il resto del modulo e la UI non conoscono la formula.
   Motivo: più avanti sarà sostituita da un modello a popolazione.
7. Il **valore base** deriva dai dati già esistenti degli oggetti (campo `value`); **non duplicare prezzi** in un file nuovo.
8. Ogni parametro di design ha **una sola definizione** nei dati (`balance.json` o file della Casa d'Aste). Nessun numero nel codice.
9. **Salvataggio additivo** (nessuna migrazione se possibile; se serve, procedura di M19-M22).
10. **Non toccare** i dati di skill, ricette, drop o mostri (in revisione in un altro lavoro).

Clean room: nomi, testi e numeri originali in italiano. Nome visibile: **"Casa d'Aste"**.

## Task proposti
M23-01 REV design · M23-02 CORE modulo mercato · M23-03 DATA edificio, oggetti ammessi, parametri · M23-04 UI pagina ·
M23-05 QA `tools/sim_market.gd` + integrazione · M23-06 REV integrazione, `run_checks`, STATUS, tag `m23-done`, push.

## Criteri di accettazione
- Costruisci la Casa d'Aste dal Villaggio, la apri dalla mappa, vendi un materiale e vedi il prezzo calare, poi risalire col tempo;
  compri un oggetto con scorta limitata.
- Nessun guadagno infinito comprando e rivendendo (verificato dalla simulazione; considerare anche gli altri canali di vendita
  a prezzo fisso: Deposito, Mercato).
- Chiudere e riaprire il gioco applica il recupero dei prezzi in forma chiusa.
- `run_checks.ps1` verde; nessun file oltre ~400 righe; nessuna stat decorativa.

## Non fare
Modello a popolazione, eventi del Rift sul mercato, inserzioni a scadenza, vendita dei pezzi unici, modifiche alle skill o ai drop.
Ogni dubbio in `OPEN_QUESTIONS.md` con il default più prudente.
