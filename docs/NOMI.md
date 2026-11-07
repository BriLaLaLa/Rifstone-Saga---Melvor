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
| `riftbinding` | Legatura del Rift | Legatura del Rift |
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

## Modelli dell'equipaggiamento per grado (1 → 8)
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

Drop (componenti rari dei progetti): Zanna di cinghiale, Pelliccia di ratto, Benda del predone, Selce di Roccarossa,
Zanna di lupo, Muschio di troll, Punta di freccia, Resina del bosco, Nucleo di golem, Chitina di ragno, Feticcio della
strega, Polvere di miniera, Velo dello spettro, Placca del caduto, Scheggia di colosso, Cenere della Soglia.

## Tratti e abilità
Restano: Fendente a catena, Primo sangue, Occhio del cacciatore, Ultimo bastione, Postura di roccia, Lama di vetro,
Spine del Rift, Furia alle strette, Spezzagiganti, Zanne fameliche; Mulinello, Colpo di scudo, Frenesia gemella,
Raffica di lame.
Cambiano: Sete di brace → **Sete di sangue**; Brace vitale → **Linfa vitale**; Maglio del Rift → **Colpo
spaccaossa**; Respiro di brace → **Seconda forza**.

## Pietre, valute, infusioni, oggetti speciali
- Pietre (Scheggia / Pietra / Cuore): famiglia `ember` → **di furia**, `eye` → **di precisione**, `shade` →
  **d'ombra**, `root` → **di roccia** (es. "Cuore di furia").
- Valute (rare, esotiche): `currency_spark` **Scintilla del Rift** (comune → magico), `currency_flux` **Essenza del
  Rift** (magico → raro), `currency_crown` **Sabbia del mutamento** (ritira gli affissi).
- Infusioni: Infusione **della rapidità**, **dell'abbondanza**, **della sapienza**, **della precisione**, **della
  pelle di pietra**, **della pazienza**, **del banchetto**, **del senso del Rift**, **del baluardo**.
- `rift_shard` Frammento del Rift (resta); `warding_seal` **Sigillo di protezione**.

## Shop e UI
Casella della bank → **Spazio nel deposito**; Casella dell'Armeria → **Spazio nell'armeria**; Razioni da campo I-III,
Raccolta automatica del bottino, Tasca della borsa restano; spariscono gli attrezzi del novizio. "Bank" → **Deposito**
ovunque nella UI.

## Restano come sono
Affissi (Affilato, Pesante, Preciso…), nodi della maestria, nomi delle prese dell'Altare.
