# Interfaccia GDR: Combattimento ed Equipaggiamento (M6-00)

Stato: **APPROVATA dall'utente** (2026-11-04). Riferimento visivo: le due tavole in `docs/mockups/` (`combat.dc.html`,
`equipment.dc.html`: HTML con stili inline, da leggere come specifica di layout, non da eseguire). Ispirazione: la
schermata di combattimento di Aethyr Idle (idee, non grafica né disposizione esatta) e la disposizione a sagoma del
pannello equipaggiamento del vecchio RiftStone Saga. Clean room: **nessun asset riusato**; la vecchia
`inventoryPg.png` è troppo vicina alla finestra di Metin2 (Q25): si prende solo la disposizione.

## 1. Decisioni dell'utente

| # | Decisione |
|---|---|
| U1 | Pagina del combattimento con **distinzione netta** personaggio / nemici |
| U2 | L'equipaggiamento indossato è visibile **nella pagina del combattimento**, con tooltip al passaggio del mouse |
| U3 | Ogni mostro ha un'**icona** (ora); poi un piccolo **sprite** con animazioni minime |
| U4 | **Armeria ed Equipaggiamento sono una sola pagina** ("Equipaggiamento"): sagoma con gli slot + inventario a griglia |
| U5 | Equipaggiare con **trascinamento** sullo slot o **tasto destro**; tasto destro su una spada a una mano quando ne impugni già una → **seconda mano**, se libera |
| U6 | **Tooltip di confronto** con il pezzo indossato nello stesso slot |
| U7 | Slot vuoti con la **propria icona** (elmo, corpo, …) |

## 2. Pagina del combattimento (`docs/mockups/combat.dc.html`)

Una sola schermata, nessuna sottoscheda.
- **Intestazione**: nome dell'area, numero del gruppo e quanti nemici, scelta dell'area, cibo scelto con quantità,
  Mangia, Ferma.
- **Colonna del personaggio** (a sinistra, cornice oro):
  - ritratto (icona della classe), nome della classe, livello, assetto, promemoria del triangolo;
  - PV e barra dell'attacco con l'intervallo;
  - abilità con la barra di ricarica e lo stato (pronta / ricarica N s), slot non ancora aperto con il suo livello
    (dati veri da M6-03; fino ad allora la sezione mostra gli slot vuoti);
  - tratti negli slot (dati veri da M6-01), slot chiuso con il livello;
  - **griglia dell'equipaggiamento**: 12 slot piccoli con il bordo del colore della rarità; tooltip del pezzo al
    passaggio del mouse (lo stesso componente della pagina Equipaggiamento).
- **Separatore** "VS" tra le due colonne.
- **Zona dei nemici** (a destra, cornice rossa):
  - **bersaglio** grande: icona, nome, livello, stile con l'etichetta del triangolo ("sei in vantaggio" /
    "alla pari" / "svantaggio"), intervallo d'attacco, riduzione del danno, PV, barra dell'attacco;
  - **in fila**: gli altri nemici come carte piccole (icona, nome, stile, PV, barra dell'attacco); i morti dell'incontro
    restano sbiaditi fino al gruppo successivo;
  - **numeri dei colpi** sopra i ritratti: più grandi e oro per i colpi forti, "Parato" per le parate; spariscono a fine
    combattimento (bug della prova visiva di M5: un numero restava dopo la sconfitta).
- **Riga in basso**:
  - **bottino**: ultime icone con il colore della rarità, borsa N/M, Raccogli tutto;
  - **rendimento** dell'ultima ora: uccisioni/ora, XP/ora, oro/ora, danno/s (letture derivate dai contatori della
    sessione: nessuno stato nuovo nel salvataggio, nessuna stat nuova);
  - **registro** chiuso su una riga di riepilogo (colpi, abilità, parate, cibi); aperto mostra le ultime righe.
- Messaggio di sconfitta come oggi.

## 3. Pagina Equipaggiamento (`docs/mockups/equipment.dc.html`)

La pagina Armeria sparisce dalla sidebar; la sua logica UI (filtri, pannello del pezzo, vendita, blocco) passa qui.
- **Inventario** (a sinistra): griglia dei pezzi dell'Armeria non indossati, filtri slot e rarità, contatore
  "usati/capienza (+N indossati)".
- **Sagoma** (al centro, cornice oro): silhouette originale con gli slot intorno: Testa in alto; Collo e Anello a
  destra; Mani a sinistra; Corpo, Gambe, Piedi al centro; **In mano** e **Seconda mano** alti ai due lati; i 3 attrezzi
  in una riga sotto. Slot vuoto = icona dello slot in tono spento; slot pieno = icona del pezzo con il bordo della rarità.
- **Statistiche e pezzo selezionato** (a destra): valori finali del personaggio; azioni del pezzo: Rimuovi/Equipaggia,
  Blocca, Vendi (disattivata se indossato), Raffina (da M7, disattivato fino ad allora).
- **Interazioni**:
  - trascinamento da inventario a slot; durante il trascinamento si illuminano **solo** gli slot compatibili (regole
    di `Equipment.equip`, `05_INTERFACES.md` §5.9: tipo d'arma, assetti, requisiti);
  - trascinamento da slot a inventario = Rimuovi;
  - tasto destro su un pezzo dell'inventario = equipaggia nello slot naturale; per una `sword` con l'arma già in mano
    e la seconda mano libera → seconda mano (U5); tasto destro su uno slot pieno = Rimuovi;
  - clic sinistro = seleziona (pannello a destra);
  - ogni errore di `equip` mostra il suo motivo (toast o riga sotto la sagoma), nessuno stato cambia.
- **Tooltip di confronto** (U6): sotto i dati del pezzo, la differenza con il pezzo indossato nello stesso slot (verde
  ciò che migliora, rosso ciò che peggiora) e il cambio di assetto che ne risulta. Le differenze si calcolano con le
  stesse funzioni delle statistiche (nessuna formula nuova scritta nella UI).

## 4. Icone

- **Mostri**: campo nuovo `icon` in `monsters.json` (`04_DATA_SCHEMA.md` §8), obbligatorio, validato come le icone
  degli oggetti; 12 icone SVG segnaposto originali (una per mostro). Campo facoltativo **riservato** `sprite` per dopo
  (4 stati: fermo, attacco, colpito, morte): solo schema e validatore, nessun uso.
- **Animazioni minime** già ora, solo UI (tween): scatto quando un nemico attacca, lampo quando viene colpito,
  dissolvenza alla morte. Durate in `UiStyle`.
- **Slot**: 12 icone SVG originali per gli slot vuoti, nello stile D.
- **Classe**: un'icona per il ritratto (campo `icon` nel file della classe).

## 5. Fuori da M6-00

Mappe alla PoE (M12), sprite animati veri, regole condizionali delle abilità, preset delle build, registro completo
con filtri: idee annotate, non in questo task.

## 6. Proposta di task (per `07_TASKS.md`)

| ID | Titolo | Ruolo | Dipendenze | Ownership (sintesi) |
|---|---|---|---|---|
| M6-00a | Icone dei mostri, degli slot e della classe | DATA | — | `data/combat/monsters.json` (`icon`), `assets/icons/monsters/**`, `assets/icons/slots/**`, schema + validatore (`icon`, `sprite` riservato), i loro test |
| M6-00b | Pagina Equipaggiamento unita (sagoma, inventario, trascinamento, tasto destro, confronto) | UI (L) | M6-00a | `ui/pages/equipment/**`, `ui/pages/armory/**` (spostati o rimossi), `ui/screens/main/sidebar.gd`, `page_host.gd`, tooltip del pezzo, smoke |
| M6-00c | Pagina del combattimento GDR (colonne, bersaglio e fila, equipaggiamento con tooltip, numeri, bottino, rendimento, registro) | UI (L) | M6-00a, M6-00b (tooltip condiviso) | `ui/pages/combat/**`, smoke |

M6-05 (UI di tratti e abilità) costruisce sulle sezioni Abilità e Tratti create da M6-00c.

## 7. Accettazione

- Le due pagine seguono le tavole di `docs/mockups/` (disposizione e contenuti; colori e font dal tema esistente).
- Trascinamento, tasto destro e confronto funzionano per tutti i 12 slot e i 4 assetti; le regole restano quelle di
  `Equipment` (la UI non decide nulla).
- Nessuno stato nuovo nel salvataggio; nessuna stat nuova; nessun testo scritto a mano fuori da `ItemTooltipLines`,
  `ArmoryTexts`/`CombatTexts`.
- Layout verificato a 1600×900 e a 1280×720 (screenshot di prova).
