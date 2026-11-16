# M24: Incontri e Mestieri (high level design, bozza)

**Stato: BOZZA di high level design, decisioni A-F fissate dall'utente il 2026-11-16 (restano G-I).** Nessun numero, nessuna formula, nessun dato. Serve a fissare ruoli, regole e confini prima
che il Reviewer scriva il design vero (GDD, formule, schema, contratto). Non cambia codice né dati.
Sostituisce, quando sarà approvata, il modello attuale delle 7 skill di supporto (`00_VISION.md`, "Il personaggio e le 7 skill").

## Perché
Le skill di oggi sono "premi un pulsante, aspetta, ottieni un materiale": fini a se stesse, troppo simili a Melvor Idle.
Il giocatore vuole che il combattimento resti al centro e che tutto il resto serva a ciò che lo fa tornare:
**numeri che salgono, equipaggiamento più forte, collezione**. La raccolta e la produzione devono far parte del mondo
in cui si combatte, non essere attività da avviare.

## Richiesta dell'utente (testo originale, fonte del design: non cambiarne l'intento)
> "Raccolta è assolutamente automatica. Il loop di gioco vorrei fosse questo: combat, finisce un combattimento...
> inizialmente parte un timer che dopo X tempo fa partire un altro combattimento, poi ci sarà una piccola mappetta che farà
> vedere un'icona del personaggio che si muove, per far capire che si è spostato. Tutto idle, il player non decide nulla.
> Può essere che l'incontro sia uno scontro, un nodo da fare harvesting, quindi fishing, mining, woodcutting, herbalism ecc.
> Il giocatore farà quell'azione ovviamente.
> Vorrei però che ci fossero i trainer come in WoW. Che tu ti devi specializzare in 2 discipline di harvesting e 2 di crafting.
> Non puoi sceglierne più di 2."

## Il ciclo (in breve)
1. Un **combattimento** finisce.
2. Parte un **timer di viaggio**; una **piccola mappa** mostra l'icona del personaggio che si sposta (solo effetto visivo).
3. Il viaggio porta a un **incontro**, scelto dal gioco in base alla zona: uno **scontro** oppure un **nodo di raccolta**
   (pesca, miniera, taglialegna, erboristeria, e altri che il Reviewer potrà aggiungere).
4. Se è un nodo, il personaggio lo lavora **da solo** (raccolta automatica); poi si riparte dal punto 2.
Il giocatore non decide nulla durante il ciclo. Il Dungeon resta l'unica parte interattiva (V12).

## Le decisioni del giocatore: i Trainer
- Nel **Villaggio** ci sono i **Trainer**, uno per disciplina. Il giocatore impara **al massimo 2 discipline di raccolta e 2 di
  produzione**. Non se ne possono avere di più.
- La scelta è **l'unica decisione di build** di questo livello: definisce che cosa il personaggio sa raccogliere e
  produrre, quindi di che cosa ha bisogno e che cosa compra o vende.
- **Conseguenza voluta**: con solo 2 raccolte su 4, il giocatore non ha tutto da solo. La **Casa d'Aste** (M23) diventa il
  luogo dove si procura ciò che non raccoglie e si vende ciò che ha in eccesso. Il mercato acquista così uno scopo, e il
  futuro modello a popolazione (`M23_CASA_ASTE.md`) vale la spesa.

## Ruolo della produzione
- La produzione serve **l'equipaggiamento e la collezione**, non è fine a se stessa: ingredienti di potenziamento,
  consumabili, componenti per il singolo craft, quest della Bacheca. L'oro è un extra, non lo scopo.
- Le ricette si **scoprono** (da incontri, quest, drop) e non si ricevono tutte per livello. Questo alimenta la
  collezione senza un "museo" vero.
- I pezzi continuano a venire dai **mostri** o da **un singolo craft fatto bene** (decisione R1-R3, invariata).

## Cosa resta fisso
Combattimento a gruppi, Armeria, Altare, Fratture, Monoliti, Dungeon, Deposito, Villaggio, Casa d'Aste (M23),
offline fino a 12 ore, regole di `CLAUDE.md` (clean room, data-driven, un solo sistema di modificatori, niente stat decorative).

## Da rivedere (impatto stimato, da verificare dal Reviewer sul codice)
- **Aiutanti** di raccolta (M12): **eliminati** (decisione dell'utente, non esistono più). Il Reviewer rimuove codice, dati, UI, test, save e documenti che li riguardano.
- **Maestria** per skill e per risorsa (M12): resta solo per le discipline apprese; da decidere se si mantiene l'albero attuale.
- **Le 7 skill attuali** e la pagina per skill: si rimappano sulle discipline; alcune scompaiono (vedi domande aperte).
- **Drop e tabelle degli incontri**: i nodi entrano nei dati delle aree. Va fatto **prima** del modello a popolazione.
- **Offline**: il ciclo degli incontri va risolto in forma chiusa (probabilità per tipo di incontro, durata media), come il resto.

## Decisioni fissate dall'utente (2026-11-16)
- **Aiutanti**: eliminati.
- **A. Incisore**: **non è una disciplina da scegliere**. È una funzione presente nel Villaggio (per tutti, serve l'Altare).
- **B. Nodi di discipline non apprese**: compaiono e si saltano ("vedi un filone, non sai estrarlo"); mostrano ciò che manca e spingono al mercato.
- **C. Disimparare**: si può cambiare disciplina, con un costo e la **perdita totale** dell'avanzamento di quella disciplina (come in WoW).
- **D. Produzione**: coda di lavori **in parallelo** al ciclo.
- **E. Trainer**: hanno **gradi** che richiedono livello e oro.
- **F. Discipline**: raccolta = pesca, miniera, taglialegna, erboristeria (si scelgono 2); produzione = forgia, falegnameria, cucina o alchimia (si scelgono 2).

## Domande aperte (default tra parentesi; il Reviewer le porta in `OPEN_QUESTIONS.md`)
- **G. Incisione nell'elenco della produzione**: A dice che l'Incisore sta nel Villaggio e non si sceglie, ma l'elenco di F lo citava
  tra le discipline di produzione. Letture possibili: (a) scelta tra **3** discipline (forgia, falegnameria, cucina/alchimia), l'Incisore
  fuori; (b) scelta tra 4 con l'Incisore dentro. (a, coerente con A)
- **H. Cucina e alchimia**: sono una disciplina sola o due? Se sono due, la scelta di produzione è tra 4 e non tra 3. (una sola, "Cucina e alchimia")
- **I. Avanzamento dell'Incisore**: dato che è nel Villaggio, ha un livello proprio e una maestria o è sbloccato dagli edifici? (livello proprio, deciso dal Reviewer)

## Piano proposto (milestone M24, da affinare dal Reviewer)
1. **M24-01 REV**: design vero (GDD, formule, schema, contratto, roadmap, task), risolve le domande A-F, decide cosa si elimina.
2. **M24-02 CORE**: modulo del ciclo degli incontri (timer, scelta dell'incontro, nodo di raccolta automatico) e stato delle discipline
   apprese; offline in forma chiusa.
3. **M24-03 DATA**: discipline, Trainer, nodi per area, ricette da scoprire; script generatore dove i dati sono ripetitivi.
4. **M24-04 UI**: mappa di viaggio, pagina dei Trainer nel Villaggio, riepilogo delle discipline.
5. **M24-05 QA** e **M24-06 REV**: simulazione dei tempi, test d'integrazione, allineamento documenti, tag `m24-done`.
Parallelismo massimo 2 agenti. Ogni parametro nei dati; nessun numero nel codice.

## Scartati
Aiutanti di raccolta, raccolta decisa dal giocatore a ogni nodo, interruzioni durante il combattimento, più di 2+2 discipline, prezzi dei pezzi unici
nel mercato, produzione di equipaggiamento in serie, attese lunghe in tempo reale.
