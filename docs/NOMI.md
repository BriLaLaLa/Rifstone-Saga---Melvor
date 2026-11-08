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
