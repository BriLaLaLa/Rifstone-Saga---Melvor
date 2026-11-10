# M15 — Monoliti da Metin, pezzi nel bottino, combattimento affollato (R-06)

Fonte del design di M15 (decisioni Z1-Z9 dell'utente, 2026-11-10). Il task M15-01 la riporta in `01_GDD.md`,
`02_FORMULAS.md` (F-125…F-128), `04_DATA_SCHEMA.md`, `05_INTERFACES.md`; poi questo file resta storico.
Nome di gioco invariato: **Monolito del Rift** (id `rift_stone` invariati). Idea ispirata alle "pietre" di Metin2, solo
come meccanica (clean room): nomi e numeri sono originali.

## Decisioni
- **Z1 Pezzi nel bottino.** Un pezzo di equipaggiamento che cade finisce nel **Bottino** (non più diretto nell'Armeria).
  "Raccogli tutto" lo sposta nel Deposito. Nel Deposito i pezzi compaiono come voce di una sezione "Pezzi"; la pagina
  Equipaggiamento mostra **solo** i pezzi. La fonte di verità resta una sola (Armeria, F-100/`armory.add_drop`): il
  Bottino tiene i pezzi in attesa, la UI non copia dati. Nella Frattura non cambia (già nel suo sacco).
- **Z2 Livelli dei Monoliti.** Un tipo ogni 5 livelli (5, 10, 15…). Il pool di un'area sono i multipli di 5 tra il
  suo livello minimo e il livello massimo (= minimo dell'area dopo − 1; ultima area: tetto del personaggio). Il
  livello minimo del pool è arrotondato **per eccesso a 5, ma almeno 5**, e il pool include sempre il multiplo di 5
  più alto sotto il massimo: nelle Pianure (1-15) sono 5, 10, 15, anche al livello 1. Scelta uniforme.
- **Z3 Comportamento ("sacco").** HP molti (F-125), nessun danno vero: ogni `pulse_ms` infligge **1 danno fisso**
  (ignora Armatura/Barriera). Al **primo colpo subito** e quando gli HP scendono sotto **75%, 50%, 25%** evoca un
  gruppo di mostri dell'area, di livello pari a quello del Monolito (scalati come i gruppi della Frattura, F-110).
  I mostri evocati attaccano come gli altri, non danno XP né drop se `summoned` (come i richiami del boss, F-112);
  il Monolito sì. Possono essere 30 o più in campo: vale Z6.
- **Z4 Bottino particolare.** Alla distruzione: Frammenti (come F-87), **un tiro garantito di equipaggiamento** con
  rarità aumentata (F-127) e un tiro di Progetto. I valori sono nei dati, non nel codice.
- **Z5 Frequenza.** Resta F-87 (pietà e probabilità per area); `rift_stone_chance_pct` delle Pianure sale da 0 a un
  valore > 0 (default 0.6, come il Bosco), tarato da QA.
- **Z6 Combattimento affollato.** Con più di `combat.crowd_threshold` nemici in campo (default 8) la zona nemici passa
  a **vista compatta**: il Monolito fisso in alto con barra HP e tacche 75/50/25; i mostri raggruppati per tipo
  ("Lupo del Bosco ×7") con barra HP del bersaglio e conteggio; elenco scorrevole; nessuna carta per nemico. Numeri
  dei colpi e log aggregati (un numero per tipo per tick), per costo di disegno e leggibilità.
- **Z7 Salto dei Monoliti.** Impostazione nella pagina Combattimento: "Salta i Monoliti fino al livello X" (0 =
  disattivato). Un Monolito di livello ≤ X viene scartato: non si combatte, non conta come uccisione, `since` si
  azzera e si estrae il gruppo successivo. È **stato dello slot** (salvato nel modulo combat), non delle impostazioni.
- **Z8 Miniboss.** Rimandati (nessun lavoro in M15).
- **Z9 Costi.** Un task = un agente `sonnet`, test mirati con `-glog=0`; i dati dei livelli si **generano** con
  `tools/gen_metin.gd` (regole 9-10 di CLAUDE.md § Consumi); test UI: uno smoke per pagina.

## Formule (da riportare in 02_FORMULAS.md)
- **F-125** HP del Monolito di livello `L`: `hp = round(metin.hp_base × (1 + metin.hp_per_level × L))`
  (`metin.hp_base`, `metin.hp_per_level` in `balance.json`; valori da tarare perché una difesa media lo abbatta in
  ~60-90 s con il DPS atteso a `L`). Impulso: `pulse_damage = 1`, `pulse_ms` dei dati (default 3000).
- **F-126** Soglie di evocazione: a ogni evento HP che attraversa 75, 50, 25 (% degli HP massimi), e al primo colpo,
  si evoca `metin.wave_size` mostri (default 7) pescati dai gruppi dell'area; ogni soglia scatta una volta sola.
  Un colpo che ne attraversa due fa scattare entrambe. Totale massimo 4 ondate = 28 mostri + il Monolito.
- **F-127** Bottino: tiro garantito di pezzo con `item_rarity_pct` aumentato di `metin.rarity_bonus_pct` (default 100);
  stessa tabella di F-121 con il livello del Monolito come livello del mostro.
- **F-128** Salto: se `rift_stone.level ≤ combat.skip_stone_level` (≠ 0) il Monolito pendente viene scartato prima
  dell'incontro.

## Task (anche in 07_TASKS.md)
