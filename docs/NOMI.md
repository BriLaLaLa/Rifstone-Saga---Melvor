# Nomi del gioco (proposta approvata nello stile, 2026-11-07)

Regola dell'utente: **classici e diretti** per le cose comuni, **più esotici** per le rare. Cambiano solo i nomi
visibili; gli **id restano** (Q52). Regole generali:
- niente aggettivi ripetuti ovunque ("di brace", "del Rift"): "Rift" solo per ciò che viene davvero dal Rift;
- i gradi bassi (1-4) hanno nomi reali e semplici, i gradi alti (5-8) nomi più rari ed evocativi;
- ogni grado di un'arma o armatura è un **modello** con un nome suo (non "Spada di metallo X");
- niente nomi presi da Melvor, Metin2, Path of Exile o altri giochi;
- la UI dice **Deposito** al posto di "Bank".

## Skill e classe
| Id | Oggi | Nuovo |
|---|---|---|
| `forestry` | Selvicoltura | Boscaiolo |
| `quarrying` | Cavatura | Minatore |
| `angling` | Lenza | Pescatore |
| `forging` | Forgiatura | Fabbro |
| `hearthcraft` | Focolare | Cuoco |
| `woodwright` | Intaglio | Falegname |
| `riftbinding` | Legatura del Rift | **Incisore** (R-03, W7: ex "Legatura del Rift", sostituito) |
| classe `rift_blade` | Lama del Rift | Spadaccino |

## Gradi dei materiali (1 → 8)
| Grado | Metallo (minerale / lingotto / piastra) | Legno | Pesce crudo | Pesce cotto |
|---|---|---|---|---|
| 1 | Rame | Betulla | Trota | Trota alla griglia |
| 2 | Ferro | Pino | Persico | Persico arrosto |
| 3 | Acciaio (minerale: Ferro scuro) | Quercia | Carpa | Carpa affumicata |
| 4 | Acciaio nero (minerale: Ferro nero) | Olmo | Luccio | Luccio al forno |
| 5 | Argento runico | Tasso | Anguilla | Anguilla glassata |
| 6 | Ossidiana | Ebano | Storione | Storione in crosta |
| 7 | Astrite | Legno ardente | Pesce lanterna | Pesce lanterna laccato |
| 8 | Riftite | Legno del Rift | Leviatano del Rift | Stufato di leviatano |

Nomi composti: "Minerale di rame", "Lingotto di rame", "Piastra di rame"; "Legno di betulla", "Impugnatura di
betulla", "Telaio di scudo in betulla", "Manico di betulla". Id attuali per grado: `emberbronze`→1, `ashlead`→2,
`stormzinc`→3, `duskcobalt`→4, `glimmerite`→5, `palecinnabar`→6, `emberheart`→7, `riftite`→8 (legni e pesci nello
stesso ordine dei file).

## Modelli dell'equipaggiamento per grado (1 → 8) — **SOSTITUITA da M14 (sezione "Alpha" in fondo): 15 gradi, materiali delle armature**
| Pezzo | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
|---|---|---|---|---|---|---|---|---|
| Spada | Spada corta | Gladio | Sciabola | Spada lunga | Lama runica | Falce d'ossidiana | Lama stellare | Lama del Rift |
| Spadone | Spadone grezzo | Montante | Flamberga | Claymore | Spadone runico | Spezzaferro | Mietitore d'astrite | Giudizio del Rift |
| Scudo | Rotella | Brocchiere | Scudo a goccia | Scudo torre | Pavese runico | Egida d'ossidiana | Scudo stellare | Bastione del Rift |
| Elmo | Calotta | Elmetto | Barbuta | Celata | Elmo runico | Elmo d'ossidiana | Corona d'astrite | Visiera del Rift |
| Corpo | Giaco | Cotta di maglia | Corazza | Usbergo | Corazza runica | Corazza d'ossidiana | Armatura stellare | Corazza del Rift |
| Gambe | Brache imbottite | Cosciali | Gambali di maglia | Gambali a piastre | Gambali runici | Gambali d'ossidiana | Gambali stellari | Gambali del Rift |
| Piedi | Stivali di cuoio | Stivali chiodati | Calzari | Schinieri | Stivali runici | Stivali d'ossidiana | Passi stellari | Stivali del Rift |
| Mani | Guanti di cuoio | Guanti di maglia | Manopole | Guanti a piastre | Guanti runici | Manopole d'ossidiana | Artigli stellari | Guanti del Rift |
| Anello | Fede di rame | Anello di ferro | Anello d'argento | Anello con sigillo | Anello runico | Anello d'ossidiana | Anello stellare | Anello del Rift |
| Amuleto | Ciondolo | Medaglione | Talismano | Amuleto | Amuleto runico | Amuleto d'ossidiana | Stella d'astrite | Occhio del Rift |

Progetti: "Progetto: <modello>" (es. "Progetto: Claymore").

## Attrezzi (unici, R3)
Accetta, Piccone, Canna da pesca (con "+N" nel nome: "Accetta +4").

## Aree e mostri
| Id | Oggi | Nuovo |
|---|---|---|
| `redrock_plains` | Pianure di Roccarossa | Pianure di Roccarossa |
| `whisper_wood` | Bosco dei Sussurri | Bosco dei Sussurri |
| `cracked_mines` | Miniere Crepate | Miniere Abbandonate |
| `rift_threshold` | Soglia del Rift | Soglia del Rift |
| `plains_boar` | Cinghiale delle pianure | Cinghiale |
| `ember_rat` | Ratto di brace | Ratto rosso |
| `redrock_raider` | Predone di Roccarossa | Predone |
| `whisper_wolf` | Lupo dei sussurri | Lupo grigio |
| `moss_troll` | Troll di muschio | Troll del bosco |
| `hollow_archer` | Arciere cavo | Bracconiere |
| `crack_golem` | Golem crepato | Golem di pietra |
| `deep_crawler` | Strisciatore profondo | Ragno delle gallerie |
| `vein_witch` | Strega delle vene | Strega della miniera |
| `shard_wraith` | Spettro di frammenti | Spettro cristallino |
| `rift_knight` | Cavaliere del Rift | Cavaliere caduto |
| `riftborn_colossus` | Colosso nato dal Rift | Colosso del Rift |
| *(M17-04: 10 aree strette, vedi `02_FORMULAS.md` §8.5; qui le aree e i mostri nuovi)* | | |
| `dry_uplands` | — | Altipiani del Vento Secco |
| `ash_marsh` | — | Paludi di Cenere |
| `weeping_gorge` | — | Gole dei Cristalli Piangenti |
| `black_glass_desert` | — | Deserto di Vetro Nero |
| `sunken_citadel` | — | Cittadella Sommersa |
| `rift_heart` | — | Cuore del Rift |
| `dust_jackal` | — | Sciacallo di polvere |
| `rock_ram` | — | Ariete di roccia |
| `bark_spider` | — | Ragno di corteccia |
| `elder_stag` | — | Cervo antico |
| `wind_hawk` | — | Falco del vento |
| `canyon_lynx` | — | Lince del canyon |
| `sand_shaman` | — | Sciamano della sabbia |
| `dust_ogre` | — | Orco di polvere |
| `dune_wyrm` | — | Viverna delle dune |
| `tunnel_bat` | — | Pipistrello di galleria |
| `lost_miner` | — | Minatore perduto |
| `marsh_leech` | — | Sanguisuga grigia |
| `bog_hound` | — | Segugio della palude |
| `ash_heron` | — | Airone di cenere |
| `mire_hag` | — | Megera del fango |
| `peat_titan` | — | Titano di torba |
| `glass_scorpion` | — | Scorpione di vetro |
| `crystal_sentry` | — | Sentinella di cristallo |
| `echo_harpy` | — | Arpia dell'eco |
| `geode_brute` | — | Bruto di geode |
| `tear_warden` | — | Custode del pianto |
| `gate_hound` | — | Cane del varco |
| `void_acolyte` | — | Accolito del vuoto |
| `threshold_warden` | — | Guardiano della Soglia |
| `glass_serpent` | — | Serpe di vetro |
| `mirage_stalker` | — | Cacciatore di miraggi |
| `obsidian_idol` | — | Idolo d'ossidiana |
| `sun_cultist` | — | Zelota del sole nero |
| `dune_leviathan` | — | Leviatano delle dune |
| `drowned_sentinel` | — | Sentinella annegata |
| `tide_wraith` | — | Spettro della marea |
| `citadel_archer` | — | Arciere della cittadella |
| `coral_juggernaut` | — | Colosso di corallo |
| `abyss_chancellor` | — | Cancelliere degli abissi |
| `riftborn_scout` | — | Esploratore del Rift |
| `heart_leech` | — | Parassita del cuore |
| `faceless_blade` | — | Lama senza volto |
| `pulse_horror` | — | Orrore del battito |

Drop (componenti rari dei progetti): Zanna di cinghiale, Pelliccia di ratto, Benda del predone, Selce di Roccarossa,
Zanna di lupo, Muschio di troll, Punta di freccia, Resina del bosco, Nucleo di golem, Chitina di ragno, Feticcio della
strega, Polvere di miniera, Velo dello spettro, Placca del caduto, Scheggia di colosso, Cenere della Soglia.

## Tratti e abilità
Restano: Fendente a catena, Primo sangue, Occhio del cacciatore, Ultimo bastione, Postura di roccia, Lama di vetro,
Spine del Rift, Furia alle strette, Spezzagiganti, Zanne fameliche; Mulinello, Colpo di scudo, Frenesia gemella,
Raffica di lame.
Cambiano: Sete di brace → **Sete di sangue**; Brace vitale → **Linfa vitale**; Maglio del Rift → **Colpo
spaccaossa**; Respiro di brace → **Seconda forza**.

## Pietre, valute, rune, oggetti speciali
(Le righe sui nomi di pietre, valute e rune sono **sostituite dalla Riforma 2**, vedi la sezione in fondo: restano
qui come storico.)
- ~~Pietre (Scheggia / Pietra / Cuore): famiglia `ember` → di furia, `eye` → di precisione, `shade` → d'ombra, `root` →
  di roccia (es. "Cuore di furia")~~ → sostituito da R-03: famiglie **di forza / di precisione / di agilità / di tempra**,
  gradi **Scheggia → Pietra → Pietra perfetta**.
- ~~Valute: `currency_spark` Scintilla del Rift, `currency_flux` Sabbia del mutamento, `currency_crown` Essenza del
  Rift~~ → sostituiti da R-03: **Cristallo del risveglio**, **Cristallo del mutamento**, **Cristallo dell'ascesa**
  (id invariati; `spark` → risveglio, `flux` → mutamento, `crown` → ascesa).
- Rune (ex Infusioni, P-03): **Runa della rapidità**, **Runa dell'abbondanza**, **Runa della sapienza**, **Runa della
  precisione**, **Runa della pelle di pietra**, **Runa della pazienza**, **Runa del banchetto**, **Runa del senso del
  Rift**, **Runa del baluardo** (stessi id di prima); da R-03 ogni runa ha 5 gradi ("Runa della rapidità I" … "V").
- Incavi (ex Prese dell'Altare, P-03): i 5 incavi dell'Altare del Rift; i castoni dei pezzi dell'Armeria restano "castoni".
- Nota P-03: gli id nei dati (`infusion`, `socket`, `inf_*`...) restano invariati; cambiano solo i testi.
- `rift_shard` Frammento del Rift (resta); `warding_seal` **Sigillo di protezione**.

## Shop e UI
~~Casella della bank → Spazio nel deposito; Casella dell'Armeria → Spazio nell'armeria~~ (**tolte da R-03**: sostituite
dalle **borse**); Razioni da campo I-III, Raccolta automatica del bottino, Tasca della borsa restano; spariscono gli
attrezzi del novizio. "Bank" → **Deposito** ovunque nella UI.

## Restano come sono
Affissi (Affilato, Pesante, Preciso…), nodi della maestria, nomi degli incavi dell'Altare.

## Riforma 2 (M12, W7, R-03; fonte `RIFORMA_2.md` §7)

Criteri (metodo, mai nomi): il nome dice cosa fa; la grandezza dice quanto vale; una famiglia, una parola. Gli **id non
cambiano** (Q52) tranne gli oggetti nuovi (borse, contratti, polvere, lastra, sottoprodotti). **Sostituiscono** i nomi
precedenti di pietre, valute, mestiere `riftbinding` e Pietre del Rift (bersagli).

| Cosa | Id | Nome | Sostituisce |
|---|---|---|---|
| Mestiere | `riftbinding` | **Incisore** | Legatura del Rift |
| Drop grezzo | `rift_dust` (nuovo) | **Polvere del Rift** | — |
| Valuta comune → magico | `currency_spark` | **Cristallo del risveglio** | Scintilla del Rift |
| Valuta magico → raro | `currency_crown` | **Cristallo dell'ascesa** | Essenza del Rift |
| Valuta che ritira gli affissi | `currency_flux` | **Cristallo del mutamento** | Sabbia del mutamento |
| Famiglia delle pietre (danno) | `ember` | **di forza** | di furia |
| Famiglia delle pietre (precisione) | `eye` | **di precisione** | di precisione |
| Famiglia delle pietre (schivata) | `shade` | **di agilità** | d'ombra |
| Famiglia delle pietre (armatura) | `root` | **di tempra** | di roccia |
| Gradi delle pietre | `stone_<famiglia>_chip` / `_stone` / `_heart` | **Scheggia → Pietra → Pietra perfetta** (es. "Pietra perfetta di forza") | Scheggia / Pietra / Cuore |
| Base delle rune | `rune_slab` (nuovo) | **Lastra runica** | — |
| Gradi delle rune | `<runa>` (I), `<runa>_2`…`_5` | "Runa della rapidità I" … "V" | — |
| Bersagli speciali nelle aree | (id invariati) | **Monoliti del Rift** | Pietre del Rift (bersagli) |
| Aiutanti: gradi | `contract_<skill>_<grado>` (nuovi; gradi `apprentice`, `journeyman`, `expert`, `master`) | **Apprendista, Garzone, Esperto, Maestro** (es. "Contratto: Garzone boscaiolo") | — |
| Borse | `bag_*` (nuove) | **Borsa di tela, Borsa di cuoio, Borsa rinforzata, Borsa del viandante, Borsa runica** | Spazio nel deposito / nell'armeria |

Sottoprodotti della maestria (traguardo 25): nomi originali semplici, es. Resina (Betulla), Pepita (Rame), Squama
(Trota); gli altri li propone il task DATA (M12-05) nello stesso stile (una parola, dice cosa è).
Note: il termine "Pietra" resta solo per le pietre dei castoni; i Monoliti sono i bersagli speciali; "Frammento del Rift"
(`rift_shard`) resta com'è.


## Fratture come mappe (M13, X1-X4, R-04)

Criteri: il nome dice dove si va (Carta) o cosa cambia (modificatore); **classici ai gradi bassi, più esotici ai gradi alti**; nomi originali, nessuno da altri giochi. I testi di gioco sono in italiano; gli id sono i soli identificatori.

| Cosa | Id | Nome |
|---|---|---|
| Pagina e sistema | — | **Fratture** (voce della sidebar); l'oggetto è la **Carta della Frattura** (nelle liste: "Carta") |
| Contenitore del bottino | — | **Borsa della Frattura**; se la consegna non entra: **Bottino in attesa** ("Raccogli") |
| Comandi | — | **Apri**, **Abbandona**, **Raccogli** |
| Informazione | — | **Livello consigliato**, **Gruppo N/30**, **Boss** |

**Carte** (`fracture_card_<grado>`, categoria `map`):

| Grado | Nome |
|---|---|
| 1 | Carta della Radura |
| 2 | Carta del Sentiero |
| 3 | Carta della Palude |
| 4 | Carta della Cripta |
| 5 | Carta della Fucina spenta |
| 6 | Carta del Baratro |
| 7 | Carta della Guglia spezzata |
| 8 | Carta dell'Eclissi |
| 9 | Carta della Vertigine |
| 10 | Carta dell'Origine |

**Modificatori** (`data/maps/map_mods.json`; rischio / premio in `02_FORMULAS.md` F-111): Mostri robusti (`sturdy`), Assalto (`assault`), Fame (`famine`), Brutalità (`brutal`), Orde (`hordes`), Impulsi (`pulses`), Velati (`shrouded`), Digiuno (`fasting`),
Titani del Rift (`titans`), Lame spettrali (`spectral`), Frenesia del Rift (`frenzy`), Tempesta dell'Abisso (`abyssal`). Gli ultimi quattro (gradi alti) sono i più esotici.

**Boss** (`boss_grade_<grado>`, uno per grado; abilità tra parentesi, F-112):

| Grado | Nome | Abilità |
|---|---|---|
| 1 | Zannalunga, il Gran Cinghiale | colpo pesante |
| 2 | Capobranco Cenere | evocazione |
| 3 | Re del Fango | scudo |
| 4 | Cavaliere senza Nome | colpo pesante |
| 5 | Custode della Fucina | scudo |
| 6 | Strega delle Vene Nere | evocazione |
| 7 | Guardiano della Guglia | colpo pesante |
| 8 | Colosso d'Ossidiana | scudo |
| 9 | Araldo dell'Eclissi | evocazione |
| 10 | Il Primo Frammento | colpo pesante |

Nomi delle abilità visibili in gioco (testo di presentazione): "Colpo pesante", "Scudo", "Evocazione". Gli evocati sono mostri esistenti del grado (nessun nome nuovo).


## Alpha: 15 gradi, materiali, Capolavori e leggendari (M14, Y3-Y5, R-05)

Sostituisce "Modelli dell'equipaggiamento per grado (1 → 8)". Criteri: **classici e diretti in basso, sempre più esotici in alto** (gradi 11-15 portano il nome dei misteri del Rift); un modello per grado e per slot; nomi originali in italiano, nessuno da Melvor, Metin2, World of Warcraft, Path of Exile o altri giochi;
"Rift" solo per ciò che viene dal Rift. Gli id dei dati sono liberi (convenzione `<slot>_<materiale>_<grado>`, `mw_<slot>_<grado>`, `leg_<slot>_<n>`): contano solo `name` e `description`. Stat nuove nei testi: `armor` = **Armatura**, `barrier` = **Barriera**.

### Gradi
| Grado | Livello | Grado del materiale | Epiteto dell'armatura | Marchio del Capolavoro |
|---|---|---|---|---|
| 1 | 1 | 1 | del Novizio | di Fucina Prima |
| 2 | 5 | 1 | del Garzone | di Ferrovivo |
| 3 | 10 | 2 | del Fante | di Roccamartello |
| 4 | 15 | 2 | del Mercenario | di Valleincudine |
| 5 | 20 | 3 | del Soldato | di Brace Fedele |
| 6 | 25 | 3 | del Veterano | di Forgia Alta |
| 7 | 30 | 4 | del Capitano | di Cenere Bianca |
| 8 | 35 | 4 | del Campione | di Torre Nera |
| 9 | 40 | 5 | del Cavaliere | di Sole Battuto |
| 10 | 45 | 5 | del Condottiero | di Luna Forgiata |
| 11 | 50 | 6 | della Brace Antica | di Fiamma Eterna |
| 12 | 60 | 6 | dell'Alba Spezzata | di Stella Domata |
| 13 | 70 | 7 | dell'Eclissi | di Eclissi Vinta |
| 14 | 80 | 7 | dell'Abisso Stellato | di Abisso Domato |
| 15 | 90 | 8 | del Primo Rift | di Rift Domato |

### Materiali delle armature
| Materiale | Id (`equip.material`) | Identità (testo breve) | Elmo | Corpo | Gambe | Piedi | Mani | Scudo |
|---|---|---|---|---|---|---|---|---|
| **Piastre** | `plate` | Armatura alta, niente Barriera | Elmo | Corazza | Cosciali | Schinieri | Manopole | Scudo |
| **Cuoio** | `leather` | Armatura media, Schivata | Cappuccio | Giubba | Calzoni | Stivali | Guanti | Rotella |
| **Tessuto runico** | `cloth` | Armatura bassa, Barriera alta | Cappello runico | Veste runica | Brache runiche | Sandali runici | Mitene runiche | Sigillo runico |

**Nome del pezzo di armatura** = nome del tipo del materiale + epiteto del grado: "Corazza del Veterano" (corpo, Piastre, grado 6), "Giubba della Brace Antica" (Cuoio, grado 11), "Veste runica del Primo Rift" (Tessuto runico, grado 15), "Scudo dell'Eclissi", "Rotella del Novizio". Il Capolavoro usa i soli tipi delle Piastre più il marchio.

### Armi, anelli e colli (un modello per grado)
| Grado | Spada | Spadone | Anello | Collo (amuleto) |
|---|---|---|---|---|
| 1 | Spada d'addestramento | Spadone grezzo | Fede di rame | Ciondolo |
| 2 | Spada corta | Mandritto | Anello di ferro | Medaglione |
| 3 | Gladio | Montante | Anello di bronzo | Talismano |
| 4 | Sciabola | Flamberga | Anello d'argento | Amuleto |
| 5 | Spada lunga | Claymore | Anello con sigillo | Monile |
| 6 | Squarcina | Spezzaferro | Anello d'oro | Pendente |
| 7 | Spada d'ordinanza | Falciatore | Anello del Capitano | Collana del Capitano |
| 8 | Lama del Cavaliere | Spadone del Campione | Anello d'ossidiana | Collare |
| 9 | Fendente | Mietitore | Anello di giada | Amuleto del Cavaliere |
| 10 | Lama temprata | Spaccaelmi | Anello del Condottiero | Reliquia |
| 11 | Lama della Brace Antica | Spadone della Brace Antica | Anello della Brace Antica | Amuleto della Brace Antica |
| 12 | Lama dell'Alba Spezzata | Spadone dell'Alba Spezzata | Anello dell'Alba Spezzata | Amuleto dell'Alba Spezzata |
| 13 | Lama dell'Eclissi | Spadone dell'Eclissi | Anello dell'Eclissi | Amuleto dell'Eclissi |
| 14 | Lama dell'Abisso | Spadone dell'Abisso | Anello dell'Abisso | Amuleto dell'Abisso |
| 15 | Lama del Primo Rift | Giudizio del Primo Rift | Anello del Primo Rift | Occhio del Primo Rift |

### Capolavori (solo dai progetti, Piastre)
Nome = tipo + marchio del grado: **Lama** (spada), **Spadone**, **Scudo**, **Elmo**, **Corazza**, **Cosciali**, **Schinieri**, **Manopole**. Esempi: "Lama di Fucina Prima" (spada, grado 1), "Corazza di Fiamma Eterna" (corpo, grado 11), "Scudo di Luna Forgiata" (grado 10), "Spadone di Rift Domato" (grado 15).
Il progetto si chiama "Progetto: <nome>" (es. "Progetto: Corazza di Fiamma Eterna"). Colore del nome: viola. Descrizione tipo: "Un pezzo forgiato con cura, migliore di ogni altro del suo grado." Le armature di Cuoio e Tessuto runico non hanno Capolavoro (Q75).

### Leggendari (39: 3 per slot, colore arancione)
Statistiche: modello di slot, grado e materiale indicati (`02_FORMULAS.md` §8.4) × 1,4 (F-120). Requisito = livello del grado (grado 10: 45, 11: 50, 13: 70, 14: 80, 15: 90), per gli attrezzi il livello del mestiere indicato. Fonte: boss della Frattura 0,6% a vittoria; Monolito 0,3% a morte (tarati in M14-10, Q76).
Effetto: tipi e parametri di `02_FORMULAS.md` F-120 (e F-81). Testo di gioco: una riga che dice la regola con i numeri letti dai dati.

| Slot | Nome | Grado, materiale | Fonte | Effetto (tipo, parametri) | Che cosa fa |
|---|---|---|---|---|---|
| Elmo | Cimiero del Cinghiale Bianco | 10, Piastre | Zannalunga, il Gran Cinghiale | `hit_cap_pct` 35 | Nessun colpo toglie più del 35% dei PV |
| Piedi | Zoccoli del Gran Cinghiale | 10, Piastre | Zannalunga, il Gran Cinghiale | `target_rule` `lowest_hp` | Colpisci sempre il nemico più ferito |
| Anello | Zanna d'Argento | 10 | Zannalunga, il Gran Cinghiale | `monolith_loot_mult` 2 | Il bottino dei Monoliti è raddoppiato |
| Corpo | Pelliccia di Cenere | 11, Piastre | Capobranco Cenere | `reflect_pct` 25 | Il 25% del danno subito torna a chi ti colpisce |
| Mani | Artigli del Capobranco | 11, Piastre | Capobranco Cenere | `armor_pierce_pct` 30 | I colpi ignorano il 30% dell'Armatura dei nemici |
| Spada | Zanna Grigia | 11 | Capobranco Cenere | `double_hit_pct` 15 | 15% di probabilità di colpire due volte |
| Gambe | Cosciali del Fango Antico | 11, Piastre | Re del Fango | `on_kill_timer_cut` 30 | Dopo ogni uccisione il prossimo attacco è più vicino del 30% |
| Collo | Talismano della Palude | 11 | Re del Fango | `leech_pct` 6 | Recuperi il 6% del danno inflitto |
| Spadone | Spaccapalude | 11 | Re del Fango | `on_kill_timer_cut` 100 | Ogni uccisione fa partire subito il prossimo attacco |
| Piedi | Passi del Cavaliere Anonimo | 13, Cuoio | Cavaliere senza Nome | `every_nth_attack_all` n 5 | Ogni 5 attacchi colpisci tutti i nemici |
| Anello | Sigillo Senza Nome | 13 | Cavaliere senza Nome | `kill_heal_pct` 4 | Ogni uccisione cura il 4% dei PV |
| Scudo | Scudo del Giuramento Spezzato | 13, Piastre | Cavaliere senza Nome | `block_heal_pct` 10 | Una parata riuscita restituisce il 10% dei PV |
| Mani | Guanti del Custode | 13, Cuoio | Custode della Fucina | `double_hit_pct` 12 | 12% di probabilità di colpire due volte |
| Spada | Brace Custode | 13 | Custode della Fucina | `on_kill_timer_cut` 50 | Dopo ogni uccisione il prossimo attacco è più vicino del 50% |
| Elmo | Cappuccio della Fucina Spenta | 13, Cuoio | Custode della Fucina | `opening_strike` | Il primo attacco di ogni incontro parte subito |
| Collo | Amuleto delle Vene Nere | 14 | Strega delle Vene Nere | `every_nth_attack_all` n 4 | Ogni 4 attacchi colpisci tutti i nemici |
| Spadone | Mietitore di Vene | 14 | Strega delle Vene Nere | `every_nth_attack_all` n 3 | Ogni 3 attacchi colpisci tutti i nemici |
| Corpo | Giubba della Strega | 14, Cuoio | Strega delle Vene Nere | `low_hp_damage_mult` `hp_pct` 30, `mult` 1,5 | Sotto il 30% dei PV infliggi il 50% di danno in più |
| Anello | Anello della Guglia Spezzata | 14 | Guardiano della Guglia | `card_drop_mult` 2 | Le Carte cadono il doppio |
| Scudo | Rotella del Guardiano | 14, Cuoio | Guardiano della Guglia | `reflect_pct` 40 | Il 40% del danno subito torna a chi ti colpisce |
| Gambe | Calzoni del Vento Alto | 14, Cuoio | Guardiano della Guglia | `stat_convert` `evasion_bonus` → `armor` 20 | Il 20% dell'Evasione diventa Armatura |
| Spada | Scheggia di Ossidiana Viva | 15 | Colosso d'Ossidiana | `armor_pierce_pct` 50 | I colpi ignorano metà dell'Armatura dei nemici |
| Elmo | Cappello dell'Occhio Vitreo | 15, Tessuto runico | Colosso d'Ossidiana | `kill_heal_pct` 3 | Ogni uccisione cura il 3% dei PV |
| Piedi | Sandali del Colosso Lieve | 15, Tessuto runico | Colosso d'Ossidiana | `stat_convert` `barrier` → `evasion_bonus` 50 | La metà della Barriera diventa Evasione |
| Spadone | Annuncio dell'Eclissi | 15 | Araldo dell'Eclissi | `execute_mult` `hp_pct` 25, `mult` 2 | Contro nemici sotto il 25% dei PV il danno è doppio |
| Corpo | Veste dell'Araldo | 15, Tessuto runico | Araldo dell'Eclissi | `stat_convert` `barrier` → `armor` 50 | La metà della Barriera diventa Armatura |
| Mani | Mitene dell'Ombra Lunga | 15, Tessuto runico | Araldo dell'Eclissi | `execute_mult` `hp_pct` 30, `mult` 1,5 | Contro nemici sotto il 30% dei PV il danno è +50% |
| Scudo | Sigillo del Primo Frammento | 15, Tessuto runico | Il Primo Frammento | `stat_convert` `armor` → `barrier` 40 | Il 40% dell'Armatura diventa Barriera |
| Gambe | Brache dell'Origine | 15, Tessuto runico | Il Primo Frammento | `leech_pct` 4 | Recuperi il 4% del danno inflitto |
| Collo | Frammento Originario | 15 | Il Primo Frammento | `reflect_pct` 30 | Il 30% del danno subito torna a chi ti colpisce |
| Accetta | Accetta del Taglialegna Paziente | req. Boscaiolo 10 | Monolito delle Pianure | `byproduct_mult` 3 | I sottoprodotti della maestria escono 3 volte più spesso |
| Canna | Canna del Pescatore Sereno | req. Pescatore 10 | Monolito delle Pianure | `gather_bonus_item` `rune_slab` 2% | A volte la pesca dà una Lastra runica |
| Accetta | Accetta della Radura Cantante | req. Boscaiolo 30 | Monolito del Bosco | `gather_bonus_item` `rift_dust` 8% | A volte il taglio dà Polvere del Rift |
| Piccone | Piccone del Cercatore | req. Minatore 30 | Monolito del Bosco | `gather_bonus_item` le 4 Schegge 5% | Ogni minerale ha il 5% di dare una Scheggia |
| Piccone | Piccone della Vena Profonda | req. Minatore 50 | Monolito delle Miniere | `byproduct_mult` 3 | I sottoprodotti della maestria escono 3 volte più spesso |
| Canna | Canna dei Pozzi Neri | req. Pescatore 50 | Monolito delle Miniere | `byproduct_mult` 3 | I sottoprodotti della maestria escono 3 volte più spesso |
| Accetta | Accetta del Bosco Perduto | req. Boscaiolo 75 | Monolito della Soglia | `gather_grade_up_pct` 10 | Il 10% dei tagli dà il legno del grado superiore |
| Piccone | Piccone dell'Ultima Galleria | req. Minatore 75 | Monolito della Soglia | `gather_grade_up_pct` 10 | Il 10% dei minerali è del grado superiore |
| Canna | Canna del Leviatano Dormiente | req. Pescatore 75 | Monolito della Soglia | `gather_grade_up_pct` 10 | Il 10% delle catture dà il pesce del grado superiore |

Attrezzi leggendari: modificatori fissi con scope della skill, per fonte (valori di partenza): Pianure `skill_interval_pct` −26 e `double_item_chance` +3; Bosco −28 e +4; Miniere −30 e +5; Soglia −35 e +7; l'attrezzo unico a +9 ha −23. Nessuna raffinazione.
Boss di riferimento: i dieci di "Fratture come mappe" (grado 1…10). Distribuzione: ogni boss lascia 3 leggendari di slot diversi, ogni slot di pezzo compare 3 volte in tutto (10 slot × 3 = 30) più 9 attrezzi dai Monoliti = 39 (Q73, Q76). Un quarto leggendario per slot, dove avanza tempo, è una futura aggiunta.

### Testi di interfaccia dell'Alpha
| Dove | Testo |
|---|---|
| Stat | **Armatura** (`armor`), **Barriera** (`barrier`); l'ex "Armatura" di `damage_reduction` non esiste più |
| Rarità | Comune, Magico, Raro, **Capolavoro** (viola), **Leggendario** (arancione) |
| Arma | "Danno 4-6", "Velocità 2,0 s", "Danno al secondo 2,5" |
| Combattimento | "Altri nemici" (era "In fila"); "Forte contro di te" / "Debole contro di te" / "Alla pari" |
| Deposito | pulsante "Riordina" |
| Fabbro | sottoschede "Lingotti", "Piastre", "Progetti", "Banco del fabbro" |
| Incisore | sottoschede "Lastre", "Fondere", "Cristalli", "Rune" |
| Guida | casella bloccata "???"; "Si ottiene da" visibile solo dopo la scoperta; toast "Nuovo: <oggetto>" |
| Maestria | "Bonus attuali", "Al livello N: …" |
| Affisso nuovo | `runeward`: "Schermato" (Barriera); `warded` resta il nome attuale (ora Armatura) |

## Dungeon delle scimmie e miniboss di area (M22-03, V12; F-139, F-143)
Nomi originali, generati dai dati (`tools/gen_dungeon.gd`, `tools/gen_areas.gd`, `tools/gen_equipment.gd`). **Gorom, Ziki e Uuk-Maar** (provvisori in M22-01) sono confermati: nessun omonimo noto in Melvor Idle. Icone: i mostri riusano quelle esistenti di `assets/icons/monsters/` (segnaposto dichiarati); nuove sono solo `ui/dungeon.svg`, `items/dungeon_ticket_monkey_den.svg` e le sei dei leggendari (segnaposto di `gen_equipment_icons.gd`).

### Dungeon, Biglietto, mostri
| Id | Nome |
|---|---|
| `monkey_den` | Covo delle Scimmie |
| `dungeon_ticket_monkey_den` | Biglietto del Covo delle Scimmie |
| `monkey_imp` | Monello del branco |
| `monkey_grunt` | Scimmia predona |
| `monkey_slinger` | Lanciatrice di noci |
| `monkey_shaman` | Scimmia sciamana |
| `monkey_guard` | Guardia dei rami |
| `monkey_gorilla` | Gorilla guardiano |
| `monkey_packlead` | Capobranco |
| `monkey_gorom` | Gorom, il Braccio Destro (stadio 1, id `right_hand`, "Il Braccio Destro") |
| `monkey_ziki` | Ziki, la Stratega (stadio 2, id `strategist`, "La Stratega") |
| `monkey_king` | Uuk-Maar, il Re delle Scimmie (stadio 3, id `king`, "Il Re delle Scimmie") |
Tipi di stanza (id fissi; gli indizi sono stati tolti in M22-09): `pack` Branco, `horde` Orda, `elite` Guardiano, `miniboss` Capobranco, `trap` Trappola, `rest` Riposo; trappole `darts`, `pit`, `vines`; scelte degli eventi: "Attraversa di corsa", "Aggira", "Riposa", "Fruga" (testi in UI, M22-06).

### Miniboss di area (id `miniboss_<area>`)
| Id | Nome |
|---|---|
| `miniboss_redrock_plains` | Rocciatesta, l'Ariete Antico |
| `miniboss_whisper_wood` | Cornargento, il Cervo Re |
| `miniboss_dry_uplands` | Ventoglio, la Viverna Tempesta |
| `miniboss_cracked_mines` | Madrepietra, la Strega Cieca |
| `miniboss_ash_marsh` | Fangonero, il Titano Zoppo |
| `miniboss_weeping_gorge` | Lacrima Nera, Custode del Pianto |
| `miniboss_rift_threshold` | Portaferro, il Guardiano Spezzato |
| `miniboss_black_glass_desert` | Vetrospina, il Leviatano |
| `miniboss_sunken_citadel` | Cancelliere Muto, Sigillo degli Abissi |
| `miniboss_rift_heart` | Battito Primo, il Colosso Ardente |

### Leggendari del Covo (fonte `dungeon`, `monkey_den`, 3,5%; grado 11, livello 50)
| Id | Nome | Effetto |
|---|---|---|
| `leg_sword_monkey` | Lama della Liana Spezzata | `double_hit_pct` 12 |
| `leg_greatsword_monkey` | Randello del Re dei Rami | `execute_mult` sotto 25% dei PV, ×1,8 |
| `leg_shield_monkey` | Scudo di Gusci di Cocco | `block_heal_pct` 8 |
| `leg_ring_monkey` | Anello della Scimmia Avida | `kill_heal_pct` 2 |
| `leg_neck_monkey` | Amuleto della Stratega | `stat_convert` Barriera → Armatura 40% |
| `leg_hands_monkey` | Guanti da Cima d'Albero | `on_kill_timer_cut` 60 |
