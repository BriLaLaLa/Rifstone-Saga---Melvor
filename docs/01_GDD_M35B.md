# 01. GDD, §43: Risorse per zona con percentuali (M35B; V45)

Estensione di `01_GDD.md`: **sostituisce `01_GDD_M35.md` §42.3 (raccolta mirata) e la parte «scelta» di §42.4**; il resto di §42 (attrezzi con teste, Falcetto, salvataggio, offline) resta.
Formule in `02_FORMULAS_M35B.md` (F-200…F-203), dati in `04_DATA_SCHEMA_M35B.md` (§36), contratto in `05_INTERFACES_M35B.md`.

## 43.1 Perché
L'utente ha respinto «Raccogli questa» (V44, M1): «per farmare il rame devo andare nella zona dove il rame è più presente… zona 1 il rame al 60% dei nodi miniera, il 30% il ferro e il
ferro scuro 10% (esempio a caso): non esiste che io prima scelga cosa trovo». La risorsa non si sceglie: **si sceglie la zona**. Prima (F-154) il nodo dava sempre la risorsa migliore
lavorabile, quindi non c'era motivo di cambiare zona per un materiale basso; ora ogni zona ha una **tabella di percentuali** per disciplina e la scelta della zona è la leva del giocatore.

## 43.2 Regole
- Ogni zona ha, per ognuna delle quattro discipline di raccolta, una **tabella di risorse con percentuali** (somma 100; es. zona 1 Minatore: Rame 79%, Ferro 21%).
- All'**inizio** di un nodo (viaggio finito, nodo che parte) la risorsa si tira con quei pesi, **solo tra le risorse con `level ≤` livello della disciplina** (le altre si scartano e le restanti
  si ripartiscono la probabilità in proporzione). Una sola idonea: quella, senza tiro. Nessuna idonea (livello molto basso in una zona alta): la migliore che il giocatore sa lavorare
  (regola del fallback, F-200). Nodo saltato (disciplina non appresa o livello sotto il minimo): nessun tiro, la risorsa «che si sarebbe lavorata» è la più probabile.
- Il **tetto della zona** (`max_level`) non limita più la risorsa: lo sostituisce la tabella (una zona non contiene i gradini troppo lontani dal suo livello).
- **Colore** (livello della disciplina meno livello della risorsa): invariato (F-154). Chi è molto sopra la risorsa che esce la lavora grigia (XP 0%, prodotto e maestria pieni): per
  rendere di più si va dove la risorsa alta è più presente. Durata, resa, XP e maestria del nodo invariati (F-155, F-161…F-165).
- **Niente raccolta mirata**: tolti il comando `set_focus`, il segnale `gather_focus_changed`, il bottone «Raccogli questa», il badge «Mirata», la riga «Qui lavori solo fino a …» e il
  valore «Automatico» (non esiste più nulla da scegliere). La scelta del giocatore è la zona della Mappa.
- Le percentuali sono **dati** (`data/encounters/nodes.json`, generato da `tools/gen_nodes.gd`, regola F-201): ogni gradino è «di casa» in almeno una zona; il Rame lo è nelle Pianure
  di Roccarossa (79%), dove è dominante; più avanti diventa raro (zona 3: 5%) e dalla zona 4 non compare più.

## 43.3 Pagina di raccolta: tabella «Risorse» (solo informativa)
La tabella di M35 §42.4 resta con le sue colonne (livello e colore per il livello attuale, scorta, «Serve a», prezzo, maestria), ma:
- la colonna **«Si trova in»** mostra le **percentuali per zona** (F-202): una riga «Zona NN%» per zona dove la risorsa compare, dalla più probabile; la zona in cui il giocatore
  si trova ora è evidenziata; nel tooltip, anche la probabilità **al livello attuale** (F-202 effettiva);
- **via** il bottone «Raccogli questa», il badge «Mirata» e la voce «Automatico»; le righe non sono cliccabili (colore, scorta e maestria restano);
- una risorsa con livello maggiore del livello della disciplina è bloccata come oggi (grigia, «Livello N»), e «Si trova in» la mostra comunque (si vede dove la si troverà).
La **scheda del nodo** (`NodeCard`) non mostra più «Mirata» né «Qui lavori solo fino a …»: solo la risorsa tirata, colore e avanzamento, come prima di M35.

## 43.4 Salvataggio e offline
- **Save v12 invariato** (`format_version` 12): la chiave `disciplines.focus` non si scrive più e, se un salvataggio la contiene, **si ignora** al caricamento (nessun errore e nessun
  avviso sopra `debug`; al salvataggio successivo sparisce). Un nodo in corso salvato conserva la sua risorsa (`combat.node.action`, `ne`): nessun tiro al caricamento.
- Il tiro sta in `NodeWork.begin` su `session.rng`: lo stato resta funzione dell'ordine dei tiri, quindi **12 h in un colpo = passi da 100 ms = blocchi da 60 s** (test). Il tiro
  consuma il generatore solo con almeno 2 risorse idonee e nodo lavorato: il tutorial a livello basso e i nodi forzati restano senza tiri.

## 43.5 Economia
Il valore atteso di un nodo cala per chi sta in una zona sopra il livello della risorsa «di casa» (F-203): è voluto (si cambia zona) e **non si ritara** (Q122). Le simulazioni
(`tools/sim_encounters.gd`) misurano le nuove medie per zona e disciplina; le soglie (2) e (3) di F-156 si riportano come misura (Q226).

## 43.6 Fuori scope
Teste che spostano le percentuali verso le risorse alte, un bottone «Vai alla zona», pesi diversi per disciplina (oggi un solo profilo, Q222), nuove risorse o zone, un «Ciò che serve»
automatico (M3 di V44: abrogato da V45).
