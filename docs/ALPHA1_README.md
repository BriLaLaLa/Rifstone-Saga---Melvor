# RiftStone Saga: Idle — Alpha 1

Versione di prova per i soci. È un'**alpha**: il gioco si avvia e si gioca dall'inizio, ma i numeri (drop, pesi, tempi) non sono
ancora tarati e alcune immagini sono segnaposto. Ci servono le vostre impressioni e i bug che trovate.

## Installazione
1. Scompattate la cartella che vi abbiamo mandato dove volete (Windows, PC desktop).
2. Avviate l'eseguibile (`RiftStoneSaga_Alpha1.exe`). Non serve installare altro.
3. Dal menu: **Nuova partita** → scegliete uno slot (ce ne sono 4) → date un nome al personaggio.

## Come si gioca (in breve)
1. Siete uno **Spadaccino**: combattete da soli, in automatico, contro **gruppi** di mostri; voi scegliete l'area, l'assetto
   (spadone, spada e scudo, due spade), i **tratti** e le **abilità**.
2. I mostri lasciano **pezzi di equipaggiamento** con rarità e bonus: tenete i migliori, **raffinateli** e incastonate le pietre.
3. Tra uno scontro e l'altro il personaggio viaggia e a volte trova un **nodo** (albero, vena, banco di pesci, erbe): lo lavora da
   solo, in alcuni **tentativi**, e mette il bottino nel **Deposito**. Lavora solo i nodi delle discipline che avete imparato.
4. Nel **Villaggio** i **Maestri** vi insegnano le discipline (al massimo 2 di raccolta e 2 di produzione); la produzione
   (forgia, falegnameria, cucina) va in **coda** mentre combattete. Nel Villaggio ci sono anche Bacheca, Mercato e Casa d'Aste.
5. Il gioco va avanti **anche a gioco chiuso** (fino a 12 ore): al rientro un riepilogo "Mentre eri via…" vi dice cosa è successo.

## Provare l'offline e la progressione lenta: "Avanza il tempo"
Per non aspettare ore vere c'è uno strumento di prova:
- in partita premete **Esc** (o il pulsante del menu) → **Impostazioni** → sezione **Debug** → **Avanza il tempo (ore)**;
- scegliete le ore (al massimo quelle dell'offline, 12) e premete **Avanza**;
- il gioco fa passare quelle ore esattamente come un'assenza vera e mostra lo stesso riepilogo "Mentre eri via…".

Si può ripetere quante volte volete per vedere come cresce il personaggio in giorni di gioco. Attenzione: **cambia davvero la
partita dello slot** (come se foste stati via). Per esperimenti usate uno slot a parte.

## Problemi noti (non segnalateli, li conosciamo)
- **Bilanciamento non tarato**: drop dei mostri e pesi dei nodi sono valori di partenza. Una nuova lista di drop è in preparazione.
- **Nodi troppo rari o troppo frequenti** in alcune aree: le discipline con nodi molto rari o molto frequenti in un'area danno
  troppe o troppe poche risorse (e poca XP) rispetto alle altre. Si sistema con la ritaratura.
- I nodi durano un po' meno del previsto con attrezzo e maestria alti: è voluto (sono bonus), se ne terrà conto nella taratura.
- **Casa d'Aste**: i prezzi seguono regole semplici, senza una "popolazione" di compratori e venditori simulati.
- **Immagini dei nodi**: animazioni segnaposto disegnate dal gioco; le immagini vere arriveranno dopo.
- **Scheda del nodo**: il bottino è mostrato su una sola riga (la risorsa principale); doppi, Frammenti e sottoprodotti
  arrivano nel Deposito ma non hanno una riga propria nella scheda.
- Il nodo "ricco" ha solo più tentativi e più risorse, nessuna ricompensa speciale, e il riepilogo offline non lo conta a parte.
- **Grafica a 1280×720**: nel Villaggio alcuni bordi sottili (1 pixel) possono sparire. A 1600×900 e oltre non succede.
- Lo strumento "Avanza il tempo" è visibile a tutti: è voluto per l'alpha.

## Come segnalare un bug
Scriveteci (chat del gruppo) con:
1. **Slot** usato (1-4) e **cosa stavate facendo** (pagina aperta, area, ultimo clic; se è dopo "Avanza il tempo", quante ore).
2. **Cosa vi aspettavate** e **cosa è successo**; se potete, uno screenshot.
3. Il **log** e, se possibile, il **salvataggio**. Su Windows sono in:
   `%APPDATA%\Godot\app_userdata\RiftStone Saga- Idle\`
   (incollate questo percorso nella barra di Esplora file). Dentro:
   - `logs\godot.log` — il log dell'ultima sessione (le sessioni precedenti sono i `godot<data>.log` accanto);
   - `saves\slot_<n>.json` — il salvataggio dello slot `n` (e la copia precedente `slot_<n>.json.bak`);
   - `settings.cfg` — le impostazioni (finestra, volume, ore di "Avanza il tempo").

Mandate il log **subito dopo** il problema, prima di riavviare più volte: a ogni avvio il gioco ne comincia uno nuovo.
