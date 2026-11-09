# 00. Visione: RiftStone Saga: Idle

Nome provvisorio: **RiftStone Saga: Idle**. Motore: Godot 4.5 stable, GDScript tipizzato, renderer GL Compatibility.
Piattaforma: PC desktop (Windows per primo). Gioco **solo interfaccia**: niente mondo 3D.

## Pitch

Nel mondo di RiftStone le Pietre del Rift si sono incrinate e ogni giorno ne cadono frammenti sulle Pianure di
Roccarossa. Il giocatore è uno **Spadaccino**, che caccia i mostri attirati dai frammenti: affronta
**gruppi** di nemici, raccoglie bottino con **rarità e affissi**, lo **raffina** e lo incastona, e costruisce la sua
build con **tratti** e **abilità** che cambiano il modo di combattere. Per sostenere la caccia taglia legna, scava,
pesca, forgia i componenti, cucina, lavora il legno e impara a **incidere** in rune, pietre e cristalli ciò che i mostri lasciano cadere. Il gioco va avanti da solo, anche a
finestra chiusa (fino a 12 ore): il giocatore decide la build, dove combattere, cosa tenere e cosa potenziare.

È un idle/incremental con il **combattimento al centro** (D1): il ciclo principale (combatti → bottino → potenziamento
→ build → zone più dure) prende le idee del farming a gruppi e della raffinazione a rischio di Metin2 e del bottino a
affissi di Path of Exile; il ciclo di supporto ha la struttura dei grandi "skiller" testuali (azione → esperienza →
livello → sblocchi, maestria per oggetto, bank, shop). Contenuti, nomi, numeri e formule sono **originali** (clean
room esteso a Melvor Idle, Metin2, Path of Exile e No Rest for the Wicked: si prendono idee, mai forme o nomi).

## Pilastri

1. **Progressione sempre leggibile.** Ogni azione mostra cosa dà (XP, oggetti, maestria) e quanto manca al prossimo
   sblocco. Ogni numero visibile ha una formula in `02_FORMULAS.md` e un test.
2. **Scelte che contano nel lungo periodo.** Assetto (spadone, spada e scudo, due spade), tratti, abilità, bottino da
   tenere e potenziare, maestria a nodi, rune dell'Altare e aiutanti creano build e percorsi diversi tra un giocatore e
   l'altro. Ogni skill di supporto produce qualcosa che serve al combattimento o al potenziamento.
3. **Rispetto del tempo del giocatore.** Progressione offline fino a 12 ore con riepilogo dettagliato al rientro;
   nessuna punizione per chi chiude il gioco.
4. **Atmosfera dark fantasy viva.** Stile "D" di RiftStone (oro su fondo scuro, Cinzel e Alegreya Sans) con più vita
   di un idle testuale: barre animate, particelle sui drop, banner dei livelli, piccole illustrazioni per skill.
5. **Solidità tecnica.** Logica testabile separata dalla UI, dati in JSON, salvataggi per slot con versione: le
   lezioni di RiftStone Saga diventano regole di progetto.

## Il personaggio e le 7 skill di supporto dell'MVP

**Personaggio** (D2, D3, D4, D6): una classe, "Spadaccino" (`rift_blade`, era "Lama del Rift"), solo spade in tre
assetti (spadone a due mani, spada e scudo, due spade); un unico **livello del personaggio** (1-99, XP per uccisione)
al posto delle 5 skill di combattimento; nessun attributo da distribuire: **tratti** passivi a slot che cambiano il
modo di combattere e **abilità** attive automatiche. Altre classi, con le loro armi, arrivano dopo l'MVP come dati.

Nomi visibili dalla riforma R4 (M10; fonte `NOMI.md`, gli **id non cambiano**, Q52):

| Categoria | Id | Nome | Produce / scopo |
|---|---|---|---|
| Raccolta | `forestry` | Boscaiolo (era Selvicoltura) | legni |
| Raccolta | `quarrying` | Minatore (era Cavatura) | minerali e pietre |
| Raccolta | `angling` | Pescatore (era Lenza) | pesci crudi |
| Artigianato | `forging` | Fabbro (era Forgiatura) | lingotti e **piastre**; i **progetti** (craft singolo di un pezzo con rarità) |
| Artigianato | `hearthcraft` | Cuoco (era Focolare) | cibo cucinato (cura in combattimento) |
| Artigianato | `woodwright` | Falegname (era Intaglio) | **componenti**: impugnature, telai degli scudi, manici |
| Rift | `riftbinding` | **Incisore** (era Legatura del Rift, R-03/W5) | trasforma i **drop dei mostri**: pietre (Fondere), Cristalli (Cristallizzare), rune a 5 gradi (Incidere, Potenziare) per l'Altare |

La classe `rift_blade` si chiama **Spadaccino** (era "Lama del Rift"). La UI dice **Deposito** dove i documenti dicono
"bank". Nei documenti tecnici i nomi precedenti compaiono ancora in alcuni riferimenti storici: vale questa tabella.

**Equipaggiamento (R1-R3)**: i pezzi arrivano **dai mostri** (fonte principale), dal **kit iniziale** o da **un singolo
craft fatto come si deve** (un progetto + molti materiali + un componente raro = un pezzo almeno magico). Le skill
artigiane non producono più equipaggiamento in serie. Un solo **attrezzo unico** per mestiere (accetta, piccone, canna),
potenziato con la raffinazione +0…+9 che riesce sempre.

**Riforma 2 (M12; decisioni W1-W7, `DECISIONS_LOG.md`)**: i tre mestieri di raccolta hanno ciascuno un **aiutante** (contratti che cadono dai mostri; gradi Apprendista,
Garzone, Esperto, Maestro) che lavora anche offline; ogni risorsa ha i suoi traguardi di maestria; l'**Incisore** (ex Legatura del Rift) non crea dal nulla ma trasforma i drop
dei mostri; pietre, valute e polvere **cadono dai mostri** e dai Monoliti; un solo **Deposito** con borse; nomi nuovi in `NOMI.md`. Le corsie parallele non esistono più.

## Differenze rispetto al modello di riferimento (Melvor Idle)

| Area | Nel modello di riferimento | In RiftStone Saga: Idle |
|---|---|---|
| Maestria | Pool con 4 soglie fisse che danno bonus finché il pool resta pieno | **Maestria a nodi**: il pool si spende per comprare nodi permanenti di un piccolo albero per skill (o per alzare la maestria di un oggetto) |
| Potenziamenti | Molte fonti diverse | **Rune del Rift**: l'Incisore trasforma i drop dei mostri in rune (5 gradi) da mettere negli incavi dell'Altare; ogni runa è un insieme di modificatori |
| Combattimento | Duello contro un mostro alla volta, skill di combattimento separate | **Gruppi di mostri** (1-6) con bersagli e motore a eventi; un **livello del personaggio** unico; tratti e abilità della classe |
| Equipaggiamento | Oggetti impilabili e uguali tra loro, prodotti in serie dall'artigianato | **Pezzi unici** nell'Armeria con rarità e affissi a gradi, dai **mostri** o da **un singolo craft** (progetto + materiali + componente raro); raffinazione +0…+9 che non distrugge; castoni |
| Eventi | Nessun evento periodico nel gioco base | **Monoliti del Rift** (M7, ex "Pietre del Rift"): incontri speciali con garanzia; **Fratture del Rift** come mappe (M13): si aprono quando vuole il giocatore con una **Carta** di grado 1-10, N gruppi più un boss, se muori perdi la Carta e il bottino della Frattura |
| Azioni | Una sola azione alla volta | Una azione (o il combattimento) alla volta, più gli **aiutanti** (M12): un aiutante per mestiere di raccolta lavora mentre il giocatore combatte, con tutte le risorse ma il 25% dell'XP e più lento di lui |
| Maestria della raccolta | Bonus per oggetto uguali per ogni risorsa | **3 traguardi per ogni risorsa** (sottoprodotto, bonus della risorsa, bonus del mestiere) e un albero di nodi **diverso per ogni mestiere** (M12) |
| Inventario | Una bank a caselle comprate | Un **Deposito unico** (oggetti ed equipaggiamento sulla stessa capienza) che cresce con **6 slot borsa** (M12), non con caselle in vendita |
| Morte | Si perde un oggetto equipaggiato a caso | Si perde il **contenuto della borsa del bottino** (loot non ancora raccolto); l'equipaggiamento è al sicuro |
| Precisione | Formula a due rami | Formula originale a rapporto: `AR / (AR + ER)`, limitata tra 5% e 95% |
| Triangolo | Mischia > distanza > magia > mischia | **Lama > Arcano > Mira > Lama** |
| Cibo automatico | La quantità curata non conta | La cura del cibo conta: si mangia un pezzo alla volta finché non si supera la soglia obiettivo |
| Attrezzi di raccolta | Potenziamenti comprati nello shop | **Un attrezzo unico per mestiere**, dal kit iniziale, potenziato con la raffinazione +0…+9 (sempre riuscita; costo in componenti, oro e livello del mestiere) |
| Tono e mondo | Fantasy generico | Universo RiftStone (Roccarossa, Rift, frammenti) |

## Fuori scope

Nell'MVP (M0-M9) **non** ci sono:

- mondo 3D, terreno, modelli, rotte, cavallo, villaggio, dungeon esplorabili (scelta: solo UI);
- elementi (fuoco/ghiaccio/fulmine) e resistenze, oggetti unici, supporti delle abilità;
- classi oltre la Lama del Rift, e quindi archi, bastoni e le loro munizioni o rune (Q6, Q37);
- dungeon a ondate, boss con meccaniche, incarichi di caccia, preghiere, farming, agricoltura, pozioni;
- schede (tab) per categoria della bank: il Deposito ha solo le due schede Oggetti ed Equipaggiamento, sulla stessa capienza (M12, W1);
- multiplayer, cloud save, achievement di piattaforma, mobile, web, localizzazione oltre l'italiano;
- Fratture del Rift come mappe con boss (M13), seconda classe e dungeon (M14+): documentati
  o accennati, pianificati dopo l'MVP.

Nell'MVP **ci sono** (prima erano fuori scope): affissi casuali, rarità, raffinazione +N, castoni e pietre (M4-M8).

## Riferimenti

- Regole di gioco: `01_GDD.md`; numeri: `02_FORMULAS.md`; architettura: `03_ARCHITECTURE.md`.
- La direzione da M4 è stata decisa in `VISIONE_V2.md` (D1-D6) e riportata nei documenti canonici con R-00: in caso
  di differenza valgono i documenti canonici.
- Approccio clean room: le meccaniche del modello di riferimento sono state studiate sulla wiki pubblica e
  riscritte con parole, nomi, numeri e formule originali. Nessun codice, asset, testo o tabella è copiato.
