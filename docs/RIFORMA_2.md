# Riforma 2: Deposito, aiutanti, maestria, Incisore e nomi (M12)

Stato: **APPROVATA dall'utente** (2026-11-08), dalla review tab per tab. Fonte per il task R-03 (come R-01): dopo R-03
valgono i documenti canonici. Numeri = valori di partenza, da fissare in `02_FORMULAS.md` con esempi e da tarare con
`tools/sim_combat.gd`. Clean room: dai giochi di riferimento si prendono i **criteri** di naming, mai i nomi.

## 1. Decisioni dell'utente

| # | Decisione |
|---|---|
| W1 | **Deposito unico**: due schede, Oggetti ed Equipaggiamento, **una sola capienza**. L'inventario della pagina Equipaggiamento mostra gli stessi pezzi |
| W2 | **Borse**: 6 slot borsa; ogni borsa aggiunge caselle al Deposito. Sostituiscono gli "spazi" dello shop |
| W3 | **Aiutanti** per i mestieri di raccolta (Boscaiolo, Minatore, Pescatore): lavorano mentre il giocatore combatte, danno **tutte le risorse** ma solo il **25% dell'XP** e sono **più lenti** del giocatore. Sostituiscono le corsie parallele |
| W4 | **Maestria per risorsa unica**: ogni risorsa di raccolta ha traguardi propri; l'albero dei nodi è diverso per ogni mestiere (chiude Q26) |
| W5 | **Legatura del Rift → Incisore**: non crea dal nulla, **trasforma i drop dei mostri**; sale di livello solo consumando drop (più un'azione base) |
| W6 | Pietre, valute e materia grezza **cadono dai mostri** (e dai Monoliti); le valute cadono anche già pronte (rare) |
| W7 | **Nomi nuovi** (§7), con i criteri: il nome dice cosa fa; la grandezza dice quanto vale; una famiglia, una parola |

## 2. Deposito unico e borse (W1, W2)

- Un solo contenitore con capienza `deposit.base_slots` + caselle delle borse. Le schede Oggetti / Equipaggiamento sono
  solo una vista: un pezzo occupa una casella come un tipo di oggetto impilato.
- Le caselle vuote sono visibili fino alla capienza.
- **Slot borsa**: 6, in cima al Deposito. Una borsa è un oggetto (`category: bag`, campo `slots`); messa nello slot
  aggiunge le sue caselle; si toglie solo se le caselle in più sono vuote (`deposit_not_empty`).
- Borse (default Q58): Borsa di tela +6 (Falegname, comune), Borsa di cuoio +10 (drop delle Pianure e del Bosco),
  Borsa rinforzata +14 (progetto), Borsa del viandante +18 (drop raro delle Miniere), Borsa runica +24 (Monoliti).
- Spariscono "Spazio nel deposito" e "Spazio nell'armeria" dello shop; gli acquisti già fatti nei salvataggi non
  contano (salvataggi incompatibili, `format_version` +1).
- La borsa del bottino del combattimento resta com'è.

## 3. Aiutanti (W3)

- Oggetto **Contratto** (`category: contract`, mestiere e grado) che cade dai mostri; usarlo assume l'aiutante di quel
  mestiere al suo grado (sostituisce quello di grado più basso).
- Gradi: **Apprendista, Garzone, Esperto, Maestro** (default Q59: intervallo × 3,0 / 2,5 / 2,0 / 1,5 rispetto al
  giocatore, XP al 25%, maestria al 25%).
- Un aiutante lavora una **risorsa già sbloccata** dal giocatore (livello del mestiere sufficiente), in parallelo a
  qualunque cosa faccia il giocatore, anche offline; i prodotti vanno nel Deposito (Deposito pieno → si ferma).
- Non usa l'attrezzo del giocatore; i bonus della maestria della risorsa valgono anche per lui.
- UI: nella pagina del mestiere una riga "Aiutante: <grado> — lavora: <risorsa> [Cambia] [Ferma]".
- Il bilanciamento (sim) verifica: combattere con 3 aiutanti attivi non dà più XP di mestiere all'ora del lavorare di
  persona su un solo mestiere.

## 4. Maestria per risorsa (W4)

- Ogni risorsa di raccolta ha **3 traguardi** di maestria (default Q60):
  - **25**: sottoprodotto raro della risorsa (es. Betulla → Resina; Rame → Pepita; Trota → Squama), componente per
    progetti o borse;
  - **50**: bonus solo per quella risorsa (velocità o doppio prodotto);
  - **99**: bonus **permanente per tutto il mestiere** (piccolo, si somma tra risorse): padroneggiare anche le risorse
    basse conviene.
- L'albero dei nodi della maestria cambia per ogni mestiere (stat e temi diversi; chiude Q26).
- I nomi delle azioni di raccolta sono solo il nome della risorsa ("Betulla"), già in P-04.

## 5. Incisore (W5, W6)

- **Drop** (mostri e Monoliti): **Polvere del Rift** (comune), **Schegge** (gemme piccole), raramente Pietre intere,
  raramente **Cristalli** pronti.
- **Azioni dell'Incisore** (tutte consumano drop, tranne la base):
  - **Lastra runica** (base, sempre disponibile): Pietra grezza del Minatore + Frammenti del Rift; poca XP; serve per
    le rune;
  - **Fondere**: 3 Schegge → 1 Pietra; 3 Pietre → 1 Pietra perfetta (stessa famiglia);
  - **Cristallizzare**: Polvere del Rift → un Cristallo, con probabilità che cresce con il livello (fallimento = polvere
    persa a metà);
  - **Incidere una runa**: Lastra runica + drop del mostro tematico (es. Zanna di lupo) → Runa di grado I;
  - **Potenziare una runa**: 3 rune di grado N → 1 di grado N+1 (fino a V).
- Le rune vanno negli Incavi dell'Altare (togliere una runa la distrugge, come oggi).
- Sparisce la produzione di valute e pietre da soli frammenti e materiali di raccolta.

## 6. Monoliti del Rift

Le "Pietre del Rift" (bersagli speciali nelle aree) si chiamano **Monoliti del Rift**, per non confonderle con le pietre
dei castoni. Solo il nome cambia (id invariati).

## 7. Nomi (W7) — da riportare in `NOMI.md`

| Cosa | Nome |
|---|---|
| Mestiere `riftbinding` | **Incisore** |
| Drop grezzo | **Polvere del Rift** |
| Valuta comune → magico | **Cristallo del risveglio** |
| Valuta magico → raro | **Cristallo dell'ascesa** |
| Valuta che ritira gli affissi | **Cristallo del mutamento** |
| Famiglie delle pietre dei castoni | **di forza** (danno), **di precisione**, **di agilità** (schivata), **di tempra** (armatura) |
| Gradi delle pietre | **Scheggia** → **Pietra** → **Pietra perfetta** (es. "Pietra perfetta di forza") |
| Base delle rune | **Lastra runica** |
| Gradi delle rune | "Runa della rapidità I" … "V" |
| Bersagli speciali nelle aree | **Monoliti del Rift** |
| Aiutanti | Apprendista, Garzone, Esperto, Maestro ("Contratto: Garzone boscaiolo") |
| Borse | Borsa di tela, di cuoio, rinforzata, del viandante, runica |

Criteri usati (dalla ricerca su Path of Exile, Metin2 e World of Warcraft, solo come metodo): il nome dice l'effetto;
la grandezza dice il valore; una famiglia, una parola.

## 8. Domande aperte nuove (vale il default)

| # | Domanda | Default |
|---|---|---|
| Q58 | Borse: caselle e fonti | §2 |
| Q59 | Aiutanti: lentezza per grado, XP e maestria | intervallo ×3,0/2,5/2,0/1,5; XP e maestria al 25% |
| Q60 | Traguardi della maestria per risorsa | 25 sottoprodotto, 50 bonus della risorsa, 99 bonus del mestiere |
| Q61 | Cristallizzare: probabilità per livello e fallimento | 40% al livello 1 → 90% al 99; fallimento = metà polvere persa |

## 9. Proposta di milestone (R-03 la porta in `07_TASKS.md`)

M12 = **Riforma 2**; M13 = Fratture come mappe; le corsie parallele spariscono (sostituite dagli aiutanti); M14+ resta.

| ID | Titolo | Ruolo |
|---|---|---|
| R-03 | Documenti da questo file e `NOMI.md`; roadmap rinumerata | REV |
| M12-01 | Deposito unico (capienza unica, vista a schede) e borse; migrazione dei moduli bank/armory nel save | CORE |
| M12-02 | Aiutanti: contratti, gradi, corsia dell'aiutante per mestiere di raccolta, offline | CORE |
| M12-03 | Maestria per risorsa: traguardi 25/50/99 e alberi diversi per mestiere | CORE |
| M12-04 | Incisore: azioni a drop (Lastra, Fondere, Cristallizzare, Incidere, Potenziare); drop di Polvere, Schegge, Cristalli | CORE |
| M12-05 | Contenuti: borse, contratti, sottoprodotti, alberi dei nodi, ricette dell'Incisore, tabelle dei drop, nomi §7 | DATA |
| M12-06 | UI: Deposito a schede con slot borsa e caselle vuote; riga Aiutante nei mestieri; pagina Incisore; Guida aggiornata | UI |
| M12-07 | Bilanciamento con sim: aiutanti (§3), Incisore, drop di schegge e cristalli, progetti (Q49) | COMBAT/QA |
| M12-08 | Test di M12 | QA |
| M12-09 | Integrazione, tag `m12-done` | REV |

## 10. Accettazione

- Un solo Deposito con capienza unica e 6 slot borsa; caselle vuote visibili; niente spazi in vendita.
- Un aiutante per mestiere di raccolta, che lavora in parallelo al combattimento e offline, con XP al 25% e più lento
  del giocatore; la sim conferma §3.
- Ogni risorsa di raccolta ha i suoi 3 traguardi; alberi dei nodi diversi per Boscaiolo, Minatore, Pescatore.
- L'Incisore sale di livello solo consumando drop (più la Lastra runica); pietre, valute e polvere cadono dai mostri.
- Tutti i nomi seguono §7 e `NOMI.md`; Guida aggiornata (Deposito, borse, aiutanti, maestria, Incisore, Monoliti).
