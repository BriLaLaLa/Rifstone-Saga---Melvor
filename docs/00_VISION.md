# 00. Visione: RiftStone Saga: Idle

Nome provvisorio: **RiftStone Saga: Idle**. Motore: Godot 4.5 stable, GDScript tipizzato, renderer GL Compatibility.
Piattaforma: PC desktop (Windows per primo). Gioco **solo interfaccia**: niente mondo 3D.

## Pitch

Nel mondo di RiftStone le Pietre del Rift si sono incrinate e ogni giorno ne cadono frammenti sulle Pianure di
Roccarossa. Il giocatore è un avventuriero che ricostruisce la propria vita un mestiere alla volta: taglia legna,
scava, pesca, forgia, cucina, intaglia, combatte e impara a **legare** i frammenti del Rift per piegare a suo favore
le regole del mondo. Il gioco va avanti da solo, anche a finestra chiusa (fino a 12 ore): il giocatore sceglie cosa
fare, quando cambiare, come spendere la maestria accumulata e quali infusioni incastonare.

È un idle/incremental con la struttura dei grandi "skiller" testuali (azione → esperienza → livello → sblocchi,
maestria per oggetto, bank, shop, equipaggiamento, combattimento automatico), ma con contenuti, nomi, numeri e
formule **originali** e con meccaniche proprie legate al Rift.

## Pilastri

1. **Progressione sempre leggibile.** Ogni azione mostra cosa dà (XP, oggetti, maestria) e quanto manca al prossimo
   sblocco. Ogni numero visibile ha una formula in `02_FORMULAS.md` e un test.
2. **Scelte che contano nel lungo periodo.** Maestria a nodi, infusioni del Rift e ordine degli acquisti nello shop
   creano percorsi diversi tra un giocatore e l'altro.
3. **Rispetto del tempo del giocatore.** Progressione offline fino a 12 ore con riepilogo dettagliato al rientro;
   nessuna punizione per chi chiude il gioco.
4. **Atmosfera dark fantasy viva.** Stile "D" di RiftStone (oro su fondo scuro, Cinzel e Alegreya Sans) con più vita
   di un idle testuale: barre animate, particelle sui drop, banner dei livelli, piccole illustrazioni per skill.
5. **Solidità tecnica.** Logica testabile separata dalla UI, dati in JSON, salvataggi per slot con versione: le
   lezioni di RiftStone Saga diventano regole di progetto.

## Le 12 skill dell'MVP

| Categoria | Id | Nome | Produce / scopo |
|---|---|---|---|
| Raccolta | `forestry` | Selvicoltura | legni |
| Raccolta | `quarrying` | Cavatura | minerali e pietre |
| Raccolta | `angling` | Lenza | pesci crudi |
| Artigianato | `forging` | Forgiatura | lingotti, armi a lama, armature, attrezzi |
| Artigianato | `hearthcraft` | Focolare | cibo cucinato (cura in combattimento) |
| Artigianato | `woodwright` | Intaglio | archi, bastoni arcani, impugnature |
| Combattimento | `blade` | Lama | precisione e danno in mischia |
| Combattimento | `marksmanship` | Mira | precisione e danno a distanza |
| Combattimento | `arcana` | Arcano | precisione e danno arcani |
| Combattimento | `vitality` | Vitalità | punti vita massimi |
| Combattimento | `guard` | Guardia | evasione |
| Rift | `riftbinding` | Legatura del Rift | infusioni da incastonare nell'Altare del Rift |

## Differenze rispetto al modello di riferimento (Melvor Idle)

| Area | Nel modello di riferimento | In RiftStone Saga: Idle |
|---|---|---|
| Maestria | Pool con 4 soglie fisse che danno bonus finché il pool resta pieno | **Maestria a nodi**: il pool si spende per comprare nodi permanenti di un piccolo albero per skill (o per alzare la maestria di un oggetto) |
| Potenziamenti | Molte fonti diverse | **Infusioni del Rift**: la skill Legatura del Rift crea infusioni da incastonare nelle prese dell'Altare; ogni infusione è un insieme di modificatori |
| Eventi | Nessun evento periodico nel gioco base | **Fratture del Rift** (dopo l'MVP, M7): finestre a tempo con bonus o mostri speciali |
| Azioni | Una sola azione alla volta | **Due azioni in parallelo** (dopo l'MVP, M8): una seconda corsia per un'azione non di combattimento, con penalità di velocità |
| Morte | Si perde un oggetto equipaggiato a caso | Si perde il **contenuto della borsa del bottino** (loot non ancora raccolto); l'equipaggiamento è al sicuro |
| Precisione | Formula a due rami | Formula originale a rapporto: `AR / (AR + ER)`, limitata tra 5% e 95% |
| Triangolo | Mischia > distanza > magia > mischia | **Lama > Arcano > Mira > Lama** |
| Cibo automatico | La quantità curata non conta | La cura del cibo conta: si mangia un pezzo alla volta finché non si supera la soglia obiettivo |
| Attrezzi di raccolta | Potenziamenti comprati nello shop | Attrezzi **forgiati** (Forgiatura) ed equipaggiati in uno slot per skill |
| Tono e mondo | Fantasy generico | Universo RiftStone (Roccarossa, Rift, frammenti) |

## Fuori scope

Nell'MVP (M0-M6) **non** ci sono:

- mondo 3D, terreno, modelli, rotte, cavallo, villaggio, dungeon esplorabili (scelta: solo UI);
- elementi (fuoco/ghiaccio/fulmine), affissi casuali sugli oggetti, gemme, potenziamento +N degli equip;
- munizioni per Mira e rune/consumabili per Arcano (vedi `OPEN_QUESTIONS.md`);
- dungeon a ondate, boss con meccaniche, incarichi di caccia, preghiere, farming, agricoltura, pozioni;
- schede (tab) multiple della bank (vedi `OPEN_QUESTIONS.md`);
- multiplayer, cloud save, achievement di piattaforma, mobile, web, localizzazione oltre l'italiano;
- Fratture del Rift (M7) e azioni in parallelo (M8): documentate, ma pianificate dopo l'MVP.

## Riferimenti

- Regole di gioco: `01_GDD.md`; numeri: `02_FORMULAS.md`; architettura: `03_ARCHITECTURE.md`.
- Approccio clean room: le meccaniche del modello di riferimento sono state studiate sulla wiki pubblica e
  riscritte con parole, nomi, numeri e formule originali. Nessun codice, asset, testo o tabella è copiato.
