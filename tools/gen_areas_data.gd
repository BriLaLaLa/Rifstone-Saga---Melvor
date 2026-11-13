extends RefCounted
## Content tables of tools/gen_areas.gd and tools/gen_metin.gd (M17-04): the ten narrow areas (docs/02_FORMULAS.md §8.5),
## their monsters (name, level, role, icon, text), the material kit each area drops and the names of the Rift Stones.
## Only names, texts and picks live here; every number (hp, bonuses, xp, weights) is computed by the generators.
## Texts are Italian, original; ids are English snake_case (docs/09_CONVENTIONS.md).

const ICON_DIR: String = "res://assets/icons/monsters/"

## Roles: [style, attack_interval_ms, hp_mult, accuracy_mult, power_mult, evasion_mult, damage_reduction_mult].
const ROLES: Dictionary = {
	"brute": ["blade", 3200, 1.35, 0.9, 1.0, 0.6, 1.3],
	"warrior": ["blade", 2800, 1.0, 1.0, 1.0, 1.0, 1.0],
	"skirmisher": ["marksmanship", 2300, 0.8, 1.1, 0.95, 1.2, 0.5],
	"mystic": ["arcana", 2800, 0.85, 1.1, 1.1, 0.9, 0.6],
	"swarm": ["arcana", 2100, 0.6, 1.0, 0.9, 1.0, 0.3],
}

## Per area: id, name, description, map position, tier (0-3: loot, chance and stone icon template), rare/common materials of the
## kit, stone icon and monsters [id, name, level, role, style override or "", icon, description].
const AREAS: Array = [
	{"id": "redrock_plains", "name": "Pianure di Roccarossa", "pos": [0.10, 0.80], "tier": 0, "stone_icon": "redrock_stone",
		"desc": "Campi battuti dal vento ai piedi delle rocce rosse.",
		"kit": ["boar_tusk", "scorched_fur", "redrock_flint", "raider_bandage"],
		"monsters": [
			["plains_boar", "Cinghiale", 1, "warrior", "", "plains_boar", "Testardo e affamato, carica a testa bassa tra le stoppie."],
			["ember_rat", "Ratto rosso", 3, "swarm", "", "ember_rat", "Il pelo fuma ancora: scappa dai camini del Rift e morde per fame."],
			["dust_jackal", "Sciacallo di polvere", 5, "skirmisher", "blade", "whisper_wolf", "Gira in tondo alzando polvere, poi scatta alle caviglie."],
			["redrock_raider", "Predone", 8, "skirmisher", "", "redrock_raider", "Tira dalle rocce con archi di fortuna e non lascia testimoni."],
			["rock_ram", "Ariete di roccia", 10, "brute", "", "plains_boar", "Cozza contro tutto, e la roccia si scheggia prima di lui."]]},
	{"id": "whisper_wood", "name": "Bosco dei Sussurri", "pos": [0.22, 0.62], "tier": 1, "stone_icon": "whisper_stone",
		"desc": "Alberi fitti dove ogni fruscio sembra una voce.",
		"kit": ["wolf_fang", "troll_moss", "hollow_arrowhead", "whisper_resin"],
		"monsters": [
			["whisper_wolf", "Lupo grigio", 11, "warrior", "", "whisper_wolf", "Si muove senza rumore, ma il bosco parla al suo posto."],
			["bark_spider", "Ragno di corteccia", 13, "swarm", "marksmanship", "deep_crawler", "Si confonde col tronco e cala dall'alto sulla preda."],
			["hollow_archer", "Bracconiere", 15, "skirmisher", "", "hollow_archer", "Armatura vuota che scocca frecce da sola, finché resta un ricordo."],
			["moss_troll", "Troll del bosco", 18, "brute", "arcana", "moss_troll", "Una collina che cammina, coperta di muschio e di rancore."],
			["elder_stag", "Cervo antico", 20, "warrior", "", "moss_troll", "Le corna portano licheni e secoli: nessuno l'ha mai visto cadere."]]},
	{"id": "dry_uplands", "name": "Altipiani del Vento Secco", "pos": [0.12, 0.42], "tier": 1, "stone_icon": "whisper_stone",
		"desc": "Pietra spaccata e vento senza pioggia: ogni passo alza polvere rossa.",
		"kit": ["hollow_arrowhead", "wolf_fang", "troll_moss", "whisper_resin"],
		"monsters": [
			["wind_hawk", "Falco del vento", 21, "skirmisher", "", "hollow_archer", "Cade dal cielo come una freccia e risale prima che tu alzi lo sguardo."],
			["canyon_lynx", "Lince del canyon", 23, "warrior", "", "whisper_wolf", "Pelo del colore della roccia, occhi che non si chiudono mai."],
			["sand_shaman", "Sciamano della sabbia", 25, "mystic", "", "vein_witch", "Parla al vento secco e il vento risponde con tempeste piccole."],
			["dust_ogre", "Orco di polvere", 27, "brute", "", "moss_troll", "Si rialza ogni volta che lo spacchi, un po' più polvere e un po' più furia."],
			["dune_wyrm", "Viverna delle dune", 30, "brute", "arcana", "deep_crawler", "Striscia sotto la sabbia e riemerge dove il terreno trema."]]},
	{"id": "cracked_mines", "name": "Miniere Abbandonate", "pos": [0.30, 0.30], "tier": 2, "stone_icon": "mine_stone",
		"desc": "Gallerie spaccate dal Rift, dove la roccia pulsa di luce viola.",
		"kit": ["golem_core", "crawler_carapace", "witch_charm", "mine_dust"],
		"monsters": [
			["tunnel_bat", "Pipistrello di galleria", 31, "swarm", "marksmanship", "ember_rat", "Vive dove non arriva la luce e arriva in branchi di stridii."],
			["deep_crawler", "Ragno delle gallerie", 33, "skirmisher", "", "deep_crawler", "Dalle gallerie più basse, ha troppe zampe e nessuna fretta."],
			["lost_miner", "Minatore perduto", 35, "warrior", "", "redrock_raider", "Scava ancora, anche se la miniera lo ha già sepolto."],
			["crack_golem", "Golem di pietra", 38, "brute", "", "crack_golem", "Roccia tenuta insieme da una crepa di luce viola."],
			["vein_witch", "Strega della miniera", 40, "mystic", "", "vein_witch", "Ascolta il battito della miniera e lo restituisce in maledizioni."]]},
	{"id": "ash_marsh", "name": "Paludi di Cenere", "pos": [0.45, 0.48], "tier": 2, "stone_icon": "mine_stone",
		"desc": "Acqua grigia e fumo basso: la palude brucia piano, da sotto.",
		"kit": ["crawler_carapace", "witch_charm", "golem_core", "mine_dust"],
		"monsters": [
			["marsh_leech", "Sanguisuga grigia", 41, "swarm", "", "ember_rat", "Si attacca alle gambe e beve finché l'acqua non diventa rossa."],
			["bog_hound", "Segugio della palude", 43, "warrior", "", "whisper_wolf", "Annusa la paura nel fango e la segue senza abbaiare."],
			["ash_heron", "Airone di cenere", 46, "skirmisher", "", "hollow_archer", "Immobile nell'acqua per ore, poi un solo colpo di becco."],
			["mire_hag", "Megera del fango", 48, "mystic", "", "vein_witch", "Cuoce nel suo calderone ciò che la palude restituisce."],
			["peat_titan", "Titano di torba", 50, "brute", "", "crack_golem", "Un argine che cammina: dove passa, la palude cambia strada."]]},
	{"id": "weeping_gorge", "name": "Gole dei Cristalli Piangenti", "pos": [0.52, 0.22], "tier": 2, "stone_icon": "mine_stone",
		"desc": "Pareti di cristallo che gocciolano luce: ogni goccia ricorda qualcosa.",
		"kit": ["wraith_veil", "knight_plate", "witch_charm", "mine_dust"],
		"monsters": [
			["glass_scorpion", "Scorpione di vetro", 51, "skirmisher", "", "deep_crawler", "Il pungiglione è una scheggia trasparente: lo vedi solo quando è tardi."],
			["crystal_sentry", "Sentinella di cristallo", 53, "warrior", "", "crack_golem", "Veglia sulla gola da prima che ci fosse una gola."],
			["echo_harpy", "Arpia dell'eco", 56, "mystic", "", "shard_wraith", "Ripete il tuo nome con la voce di chi non c'è più."],
			["geode_brute", "Bruto di geode", 58, "brute", "", "crack_golem", "Cavo dentro, pieno di cristalli che sbattono come denti."],
			["tear_warden", "Custode del pianto", 60, "mystic", "", "shard_wraith", "Piange luce liquida, e quella luce brucia."]]},
	{"id": "rift_threshold", "name": "Soglia del Rift", "pos": [0.68, 0.38], "tier": 3, "stone_icon": "threshold_stone",
		"desc": "Il confine instabile dove il mondo si strappa e il Rift si affaccia.",
		"kit": ["wraith_veil", "knight_plate", "colossus_shard", "threshold_ash"],
		"monsters": [
			["shard_wraith", "Spettro cristallino", 61, "mystic", "", "shard_wraith", "Un'ombra tenuta insieme da schegge di Rift che tintinnano."],
			["gate_hound", "Cane del varco", 63, "skirmisher", "blade", "whisper_wolf", "Esce dallo strappo con il pelo che fuma e non smette di correre."],
			["rift_knight", "Cavaliere caduto", 66, "warrior", "", "rift_knight", "Giurò di custodire la soglia; ora la soglia custodisce lui."],
			["void_acolyte", "Accolito del vuoto", 68, "mystic", "", "vein_witch", "Prega qualcosa che sta dall'altra parte e riceve risposte."],
			["threshold_warden", "Guardiano della Soglia", 70, "brute", "", "rift_knight", "Armatura nera, scudo spaccato: non lascia passare nessuno, nemmeno chi se ne va."]]},
	{"id": "black_glass_desert", "name": "Deserto di Vetro Nero", "pos": [0.80, 0.60], "tier": 3, "stone_icon": "threshold_stone",
		"desc": "Dune di vetro scuro che tagliano i piedi e riflettono un cielo che non c'è.",
		"kit": ["knight_plate", "wraith_veil", "colossus_shard", "threshold_ash"],
		"monsters": [
			["glass_serpent", "Serpe di vetro", 71, "skirmisher", "", "deep_crawler", "Scivola sul vetro senza un rumore e lascia solcature che sanguinano."],
			["mirage_stalker", "Cacciatore di miraggi", 73, "warrior", "", "rift_knight", "Ti segue per giorni, sempre un passo dentro il miraggio."],
			["obsidian_idol", "Idolo d'ossidiana", 76, "brute", "", "crack_golem", "Una statua senza volto che si volta quando nessuno guarda."],
			["sun_cultist", "Zelota del sole nero", 78, "mystic", "", "vein_witch", "Venera una stella spenta e ne chiede ancora il fuoco."],
			["dune_leviathan", "Leviatano delle dune", 80, "brute", "marksmanship", "riftborn_colossus", "Nuota nel vetro come in un mare e inghiotte carovane."]]},
	{"id": "sunken_citadel", "name": "Cittadella Sommersa", "pos": [0.62, 0.74], "tier": 3, "stone_icon": "threshold_stone",
		"desc": "Torri affondate in un mare di luce ferma: i corridoi sono ancora pieni di guardie.",
		"kit": ["knight_plate", "colossus_shard", "wraith_veil", "threshold_ash"],
		"monsters": [
			["drowned_sentinel", "Sentinella annegata", 81, "warrior", "", "rift_knight", "Fa la ronda sott'acqua da secoli e non ha mai dato il cambio."],
			["tide_wraith", "Spettro della marea", 83, "mystic", "", "shard_wraith", "Va e viene con la marea, e porta via un ricordo a ogni ritorno."],
			["citadel_archer", "Arciere della cittadella", 86, "skirmisher", "", "hollow_archer", "Dalle feritoie sommerse scocca frecce che l'acqua non rallenta."],
			["coral_juggernaut", "Colosso di corallo", 88, "brute", "", "riftborn_colossus", "Un'armata di polipi cresciuta attorno a un'armatura."],
			["abyss_chancellor", "Cancelliere degli abissi", 90, "mystic", "", "vein_witch", "Siede ancora sul trono allagato e firma ordini che nessuno legge."]]},
	{"id": "rift_heart", "name": "Cuore del Rift", "pos": [0.88, 0.28], "tier": 3, "stone_icon": "threshold_stone",
		"desc": "Il punto in cui il Rift pulsa: l'aria è fatta di battiti e il suolo non sta fermo.",
		"kit": ["colossus_shard", "knight_plate", "threshold_ash"],
		"monsters": [
			["riftborn_scout", "Esploratore del Rift", 91, "skirmisher", "", "shard_wraith", "Nato dallo strappo, conosce ogni via del cuore e ti ci porta."],
			["heart_leech", "Parassita del cuore", 93, "swarm", "", "ember_rat", "Si nutre del battito: più il Rift pulsa, più si moltiplica."],
			["faceless_blade", "Lama senza volto", 95, "warrior", "", "rift_knight", "Un'armatura piena di vuoto che ricorda solo come si combatte."],
			["pulse_horror", "Orrore del battito", 97, "mystic", "", "shard_wraith", "Si sente prima di vederlo: un battito sordo nelle ossa."],
			["riftborn_colossus", "Colosso del Rift", 99, "brute", "marksmanship", "riftborn_colossus", "Si è staccato dalla crepa un pezzo per volta, e continua a crescere."]]},
]

## The miniboss of each area (F-139, M22-03), in the order of AREAS: [name, description]. It has the level, role, style and icon of the
## strongest monster of its area (the last of the list); its multipliers (`balance.json` `miniboss`) apply when it is spawned, not here.
## The id is `miniboss_<area id>`.
const MINIBOSSES: Array = [
	["Rocciatesta, l'Ariete Antico", "Ha cozzato contro ogni masso delle Pianure e ne porta le schegge incastrate nelle corna: nessuna roccia gli resiste."],
	["Cornargento, il Cervo Re", "Le sue corna sono cariche di licheni e di anni: quando le abbassa, il bosco intero trattiene il fiato."],
	["Ventoglio, la Viverna Tempesta", "Sale dalle dune portando il vento secco sulle ali, e ogni suo passaggio taglia come sabbia lanciata."],
	["Madrepietra, la Strega Cieca", "Ha perso gli occhi in fondo alla miniera e da allora vede solo le crepe dove sta per aprirsi il Rift."],
	["Fangonero, il Titano Zoppo", "Trascina una gamba di torba e un rancore di cenere: dove cade, la palude si apre."],
	["Lacrima Nera, Custode del Pianto", "Ha pianto così a lungo che le sue lacrime sono diventate vetro, e il vetro taglia."],
	["Portaferro, il Guardiano Spezzato", "Regge ancora la soglia con metà armatura e tutta l'ostinazione: nessuno passa se lui non vuole."],
	["Vetrospina, il Leviatano", "Nuota nelle dune come in un mare nero e porta sulla schiena il vetro di cento carovane."],
	["Cancelliere Muto, Sigillo degli Abissi", "Non parla più da secoli, ma firma ancora: e ogni firma è una sentenza."],
	["Battito Primo, il Colosso Ardente", "Il primo pezzo staccato dalla crepa: pulsa più forte di tutto il resto e non si ferma."],
]

## Materials that are rare components of the projects (higher drop chance is not wanted: lower, with qty 1).
const RARE_MATERIALS: Array[String] = ["boar_tusk", "scorched_fur", "wolf_fang", "troll_moss", "hollow_arrowhead",
	"golem_core", "crawler_carapace", "witch_charm", "wraith_veil", "knight_plate", "colossus_shard"]

## Rift Stones in the order of the pool of the areas (two per area, the last area only one): [name, description].
const STONES: Array = [
	["Monolito del Sentiero Rosso", "Un sasso rosso piantato nel sentiero: batte piano, come un cuore addormentato."],
	["Monolito della Brace Sepolta", "Sotto la crosta di terra cova una brace che non si spegne mai."],
	["Monolito del Muschio Cupo", "Una lastra coperta di muschio scuro che mormora quando nessuno la guarda."],
	["Monolito dell'Eco Fitto", "Ogni colpo ritorna dagli alberi più forte, come se il bosco rispondesse."],
	["Monolito del Vento di Ruggine", "Il vento ci gira attorno e porta un odore di ferro e di cenere."],
	["Monolito dell'Altopiano Nudo", "Nessun albero, nessuna ombra: solo lui, e il vento che lo scolpisce."],
	["Monolito della Vena Viola", "Una vena di luce viola corre nella roccia e si ferma proprio qui."],
	["Monolito del Pozzo Crepato", "Il cristallo si è incastrato in un pozzo franato e ne tiene su il soffitto."],
	["Monolito della Torba Ardente", "Fuma sotto l'acqua grigia e il fango attorno a lui ribolle piano."],
	["Monolito dello Scavo Cieco", "In fondo allo scavo non c'è lampada che regga: la luce la fa lui."],
	["Monolito della Goccia Lenta", "Una goccia di luce si stacca dalla parete ogni minuto e, cadendo, suona."],
	["Monolito del Filone Spezzato", "Il filone si è spezzato attorno a lui e le crepe respirano insieme."],
	["Monolito dell'Orlo Strappato", "Il bordo del mondo si sfilaccia attorno a questa pietra nera."],
	["Monolito della Cucitura Aperta", "Una cucitura nell'aria si è aperta e il monolito la tiene spalancata."],
	["Monolito del Vetro Cieco", "Una scheggia nera alta come una torre: dentro non si riflette niente."],
	["Monolito dell'Ultima Marea", "Sorge dall'acqua ferma e la tiene ferma: se cade, la marea torna."],
	["Monolito del Velo Sottile", "L'aria è così sottile che si vede attraverso, e dall'altra parte qualcosa guarda."],
	["Monolito del Cuore Vuoto", "Il monolito è cavo: dentro non c'è nulla, ed è questo che pesa."],
	["Monolito dell'Ultimo Confine", "Oltre questa pietra il mondo non ha più un nome."],
]
