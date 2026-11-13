# M19-M21 — Villaggio (V7)

Decisioni in `DECISIONS_LOG.md` (riga V7, 2026-11-13). Questo file è il brief per l'Orchestratore: i numeri NON sono
fissati qui, li fissa il Reviewer in un task REV (formule/dati con esempi = test) e li misura con uno `sim_*` in `tools/`.

## Idea
Pagina **Villaggio**: pochi edifici unici, ognuno con livelli. Si costruiscono e migliorano pagando materiali del
Falegname (assi, componenti dei legni 1-8), oro e qualche materiale di Fabbro e Cuoco. Effetti solo di **comodità**.
Edifici proposti (5-6, da confermare nel task REV): Magazzino (caselle di Deposito), Locanda (efficienza del cibo,
aiuta Q86), Fucina (sconti/XP Fabbro), Mercato (shop esclusivi, M20), Bacheca (quest, M20), Santuario (comodità del
Rift, solo se serve). Livello dell'edificio richiede un livello del Falegname.

## Vincoli
- Clean room: niente popolazione, felicità, istruzione, salute, tasse, risorse da gestire (Township di Melvor). Edifici
  unici, una riga di livelli, costo fisso in materiali, effetto fisso.
- Costruzione **istantanea**, niente timer, niente caso offline.
- Effetti solo con `ModifierService` e stat in `data/config/stats.json` (effetto, formula, test). Nessuna stat
  decorativa. Niente potere di combattimento diretto.
- Dati in `data/` (nuovo file edifici), validati; contenuti ripetitivi (livelli, costi) generati da `tools/`.
- Stato per slot (`GameSession` compone un nuovo modulo `Village`, niente god object). Nuova chiave di save = nuova
  migrazione e `05_INTERFACES.md` (lo cambia solo il Reviewer). Pagina nuova con file < 400 righe; testi in italiano
  in `*_texts.gd`; un solo smoke test per la UI.
- Costi dei legni alti non devono obbligare a ore di farm: verificare con `sim_*` (ore per livello) e tarare.

## Milestone
| ID | Titolo | Ruolo |
|---|---|---|
| M19-01 | Design: GDD, formula costi/effetti (F-xx), schema dati, contratto del modulo `Village`, task | REV |
| M19-02 | Modulo `Village`, dati edifici (generati), stat in `stats.json`, save + migrazione, test | CORE, DATA |
| M19-03 | Pagina Villaggio a box (livello, costo, effetto, Costruisci/Migliora), voce nella sidebar | UI |
| M19-04 | Sim di bilanciamento (ore per livello), QA, `run_checks`, tag `m19-done` | QA, REV |
| M20 | Bacheca e quest con ricompense, shop esclusivi del Mercato (nuova migrazione) | da progettare in M20-01 |
| M21 | Mappa del Villaggio (schema di `combat_map.gd`) | progettata da M21-01 (`M21_MAPPA.md`) |

M19-02 e M19-03 partono in parallelo solo dopo M19-01 (contratto fissato). Max 2 agenti insieme.

## Fissato da M19-01 (2026-11-13)
Design completo in `01_GDD.md` §30, `02_FORMULAS.md` §5h (F-131…F-133), `04_DATA_SCHEMA.md` §24, `05_INTERFACES.md` §5.27/§7.t, task M19-02…04 in `07_TASKS.md`, sim `tools/sim_village.gd`.
Scostamenti dal brief: nessuna migrazione (modulo additivo, `format_version` 7 invariata); componenti del Falegname = impugnature/manici/telai (non esistono "assi"); Santuario rimandato.

## M20
Bacheca e Mercato: design fissato da M20-01 in `M20_BACHECA.md`.
