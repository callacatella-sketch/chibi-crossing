class_name ChibiDNA
extends RefCounted

## Il genoma di un villager chibi: tutto ciò che serve per costruirlo
## (archetipo, palette, proporzioni, viso, coda, accessorio) e per dargli
## un'anima (nome, pesi della mente, tratti). Generato a caso ma
## deterministico dato un seed, e serializzabile in JSON: un residente
## salvato rinasce identico.

const ACCESSORIES := preload("res://scenes/npc/ChibiAccessories.gd")
# l'anima definisce i vocabolari (SOGNI, TRATTI): il DNA li tira a sorte ma
# non li ridefinisce — una fonte sola, o le copie divergono in silenzio
const ANIMO := preload("res://scenes/npc/Animo.gd")

const ARCHETYPES := ["gatto", "coniglio", "orsetto", "volpina", "topolino"]

const DESCR := {
	"gatto": "il gattino", "coniglio": "la coniglietta", "orsetto": "l'orsetto",
	"volpina": "la volpina", "topolino": "il topolino",
}

# Ventotto nomi per ventotto posti (Visitors.MAX_RESIDENTS): con 5 archetipi
# fanno 140 etichette possibili — l'unicità delle label resta facile anche
# a villaggio pieno (vedi Visitors._spawn_candidate).
const NAMES := [
	"Nocciola", "Miele", "Cannella", "Nuvola", "Fragolina", "Biscotto",
	"Mirtillo", "Vaniglia", "Zenzero", "Pepita", "Ciliegia", "Castagna",
	"Brioche", "Sesamo", "Loto", "Camomilla", "Pistacchio", "Mandorla",
	"Liquirizia", "Caramella", "Timo", "Malva", "Papavero", "Ginepro",
	"Amaretto", "Farina", "Cacao", "Prugna",
]

# I nomi di chi NASCE qui (vedi scenes/world/Nascite.gd). Sono in più
# rispetto a NAMES perché quei ventotto sono esattamente i posti del
# villaggio: se i cuccioli pescassero da lì, a paese pieno non
# resterebbe un nome per il primo che nasce.
const NAMES_NATI := [
	"Bergamotto", "Ribes", "Susina", "Mentuccia", "Semolino", "Cardamomo",
	"Melissa", "Anice", "Croccante", "Meringa", "Panna", "Zucchero",
	"Marzapane", "Cedro", "Bacca", "Tortino", "Nespola", "Girasole",
	"Ortica", "Trifoglio", "Rosmarino", "Salvia", "Pinolo", "Corniolo",
]

# I nomi femminili, tutti in un posto: il sesso di un chibi si LEGGE dal
# suo nome invece di essere un gene in più. Così i residenti salvati
# prima delle nascite hanno già il loro, sempre lo stesso, senza che una
# riga di salvataggio cambi — e in italiano suona giusto: Fragolina è
# una bambina, Timo un bambino. (Il genere grammaticale della specie —
# «la volpina», «il gattino» — è un'altra cosa e resta com'è: in italiano
# «la volpe» è femminile anche quando è un maschio.)
const NOMI_F := [
	"Nocciola", "Cannella", "Nuvola", "Fragolina", "Vaniglia", "Pepita",
	"Ciliegia", "Castagna", "Brioche", "Camomilla", "Mandorla",
	"Liquirizia", "Caramella", "Malva", "Prugna", "Farina",
	"Susina", "Mentuccia", "Melissa", "Meringa", "Panna", "Bacca",
	"Nespola", "Ortica", "Salvia",
]

# Il mazzo di sopracciglia di ogni archetipo (i doppioni pesano la pesca).
# I nomi puntano a FaceController.BROW_STYLES — la fonte unica della FORMA;
# qui vive solo la tendenza di famiglia. Un test tiene allineati i due file.
const BROW_DECKS := {
	"gatto": ["arcuate", "arcuate", "morbide", "decise", "sottili"],
	"coniglio": ["morbide", "morbide", "sottili", "arcuate", "dritte"],
	"orsetto": ["folte", "folte", "morbide", "dritte"],
	"volpina": ["decise", "decise", "arcuate", "folte", "dritte"],
	"topolino": ["sottili", "sottili", "dritte", "morbide"],
}

# Come sopra, per la bocca: i nomi puntano a FaceController.MOUTH_STYLES.
# NON confondere col gene storico "mouth" (w/smile/o), che è la FORMA di
# riposo e resta com'è nei salvataggi.
const MOUTH_DECKS := {
	"gatto": ["morbida", "minuta", "minuta", "larga"],
	"coniglio": ["minuta", "minuta", "morbida", "piena"],
	"orsetto": ["piena", "piena", "morbida", "larga"],
	"volpina": ["larga", "larga", "morbida", "minuta"],
	"topolino": ["minuta", "minuta", "morbida"],
}

const FURS := ["f7e6d0", "e8d5b8", "d9c4a8", "cfc4bd", "f2d8c8", "e8e4dc", "c9a889", "b89f8a"]
const DRESSES := ["f2a9bc", "9fd8cf", "b7c6ff", "ffd76e", "c9a8f0", "8fc0c8", "f4c48f", "b8e0a0"]

const TRAIT_LINES := {
	"garden": "adora i giardini fioriti",
	"warmth": "cerca il calore del camino",
	"comfort": "sogna una casa ben arredata",
	"window": "vuole finestre da cui guardare il prato",
	"walls": "tiene alla sua privacy",
	"door": "vuole una porta tutta sua",
	"roof": "non sopporta la pioggia sul naso",
}


## Maschio o femmina, letto dal nome: "f" o "m". Non è un gene salvato —
## è una lettura — così vale anche per i residenti nati prima che il
## villaggio sapesse cosa fosse una nascita. Serve alle nascite (una
## coppia è un lui e una lei) e all'accordo delle frasi ("è nato" /
## "è nata"), MAI all'aspetto o al carattere.
static func sesso(dna: Dictionary) -> String:
	return "f" if str(dna.get("name", "")) in NOMI_F else "m"


## Il genoma di chi nasce: due genitori, un seme, e — se il villaggio ha
## già salutato qualcuno — un gene che torna da lui.
##
## Le regole sono quelle vere, in piccolo:
##  · i caratteri CONTINUI (occhi, orecchie, sopracciglia, taglia) sono la
##    media dei due con un filo di scarto, così un figlio somiglia a
##    entrambi senza essere la fotocopia di nessuno;
##  · quelli DISCRETI (archetipo, bocca, coda, indole, sogno) si ereditano
##    interi da uno dei due: non esistono mezze code;
##  · le lentiggini sono RECESSIVE, come si deve: due genitori lentigginosi
##    le passano sempre, uno solo a metà, e da due senza riaffiorano di
##    rado — sono la sorpresa che salta una generazione;
##  · i valori DERIVATI (fur2, belly, dress2, label, coda, tratti
##    raccontabili) non si mescolano mai: si ricalcolano, o divergono in
##    silenzio dal gene da cui nascono.
##
## `eredita` è il gene di chi è partito: {"da": nome, "cosa": chiave,
## "dna": il suo genoma}. Vedi Legami.dna_ricordo().
static func incrocia(a: Dictionary, b: Dictionary, seed_v: int,
		nome := "", eredita := {}) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v

	# --- i geni interi: uno dei due, mai una media ---
	var arche := str(a.get("archetype", "gatto")) if rng.randf() < 0.5 \
			else str(b.get("archetype", "gatto"))
	if not arche in ARCHETYPES:
		arche = "gatto"

	var figlio := {}

	# --- il manto: quasi sempre una mescolanza, ogni tanto tutto di uno ---
	var fur_a := Color(str(a.get("fur", "f7e6d0")))
	var fur_b := Color(str(b.get("fur", "f7e6d0")))
	var fur := fur_a.lerp(fur_b, rng.randf_range(0.15, 0.85))
	if rng.randf() < 0.22:
		fur = fur_a if rng.randf() < 0.5 else fur_b

	# --- il vestitino non è un gene: è la stoffa che gli hanno cucito
	# addosso, e i genitori usano quella che hanno in casa ---
	var dress := Color(str(a.get("dress", "f2a9bc"))) if rng.randf() < 0.5 \
			else Color(str(b.get("dress", "f2a9bc")))
	if rng.randf() < 0.25:
		dress = Color(DRESSES[rng.randi() % DRESSES.size()])

	# --- i pesi della mente: la media dei genitori, poi l'inclinazione
	# del proprio archetipo (che è del corpo in cui nasce, non dei due) ---
	var wa: Dictionary = a.get("weights", {})
	var wb: Dictionary = b.get("weights", {})
	var w := {"bias": -6.0}
	for k in ["roof", "walls", "door", "window", "comfort", "garden",
			"warmth", "welcome", "sunny"]:
		var m := (float(wa.get(k, 0.8)) + float(wb.get(k, 0.8))) * 0.5
		w[k] = maxf(0.0, m + rng.randf_range(-0.12, 0.12))
	match arche:
		"coniglio": w["garden"] += 0.3
		"orsetto": w["warmth"] += 0.35
		"gatto": w["comfort"] += 0.25
		"volpina":
			w["walls"] += 0.25
			w["door"] += 0.2
		"topolino":
			w["comfort"] += 0.2
			w["window"] += 0.2

	# --- il carattere: la media dei due, con lo scarto di chi è nuovo ---
	var ta: Dictionary = a.get("tratti", {})
	var tb: Dictionary = b.get("tratti", {})
	var tratti := {}
	for tr in ANIMO.TRATTI:
		var m := (float(ta.get(tr, 0.5)) + float(tb.get(tr, 0.5))) * 0.5
		tratti[tr] = clampf(m + rng.randf_range(-0.14, 0.14), 0.0, 1.0)

	# --- le indoli: una per genitore, e devono restare due diverse ---
	var brain_script := preload("res://scenes/npc/VillagerBrain.gd")
	var ind_keys: Array = brain_script.INDOLI.keys()
	var ia: Array = a.get("indole", [])
	var ib: Array = b.get("indole", [])
	var i1 := str(ia[rng.randi() % ia.size()]) if not ia.is_empty() \
			else str(ind_keys[rng.randi() % ind_keys.size()])
	var i2 := str(ib[rng.randi() % ib.size()]) if not ib.is_empty() \
			else str(ind_keys[rng.randi() % ind_keys.size()])
	if i2 == i1:
		# la seconda scivola sulla successiva: mai due indoli uguali
		var j := ind_keys.find(i1)
		i2 = str(ind_keys[(j + 1 + rng.randi() % (ind_keys.size() - 1)) % ind_keys.size()])
	var indole: Array[String] = [i1, i2]

	# --- la stravaganza: si eredita se ce l'ha un genitore, e ogni tanto
	# ne spunta una tutta sua (nessuno sa da chi l'abbia presa) ---
	var qa := str(a.get("quirk", ""))
	var qb := str(b.get("quirk", ""))
	var quirk := ""
	var pool: Array = []
	if qa != "": pool.append(qa)
	if qb != "": pool.append(qb)
	if not pool.is_empty() and rng.randf() < 0.55:
		quirk = str(pool[rng.randi() % pool.size()])
	elif rng.randf() < 0.18:
		quirk = str(brain_script.QUIRKS[rng.randi() % brain_script.QUIRKS.size()])

	var nome_f := nome
	if nome_f == "":
		nome_f = str(NAMES_NATI[rng.randi() % NAMES_NATI.size()])

	# --- le orecchie: il gene va confrontato SENZA il fattore di specie,
	# o un cucciolo di coniglio nato da due gatti avrebbe orecchie corte
	# come loro (e viceversa: uno di gatto le porterebbe da coniglio) ---
	var ka := 1.6 if str(a.get("archetype", "")) == "coniglio" else 1.0
	var kb := 1.6 if str(b.get("archetype", "")) == "coniglio" else 1.0
	var ear_base := (float(a.get("ear_len", 1.0)) / ka
			+ float(b.get("ear_len", 1.0)) / kb) * 0.5
	var kf := 1.6 if arche == "coniglio" else 1.0

	# le lentiggini, recessive
	var la := bool(a.get("freckles", false))
	var lb := bool(b.get("freckles", false))
	var lentiggini := false
	if la and lb:
		lentiggini = true
	elif la or lb:
		lentiggini = rng.randf() < 0.5
	else:
		lentiggini = rng.randf() < 0.12

	var tails := {"gatto": "ricciolo", "coniglio": "ponpon", "orsetto": "ponpon",
			"volpina": "volpe", "topolino": "filo"}
	var fluff := _media(a, b, "fluff", 0.6, rng, 0.08)
	match arche:
		"orsetto", "volpina": fluff = minf(fluff + 0.15, 1.0)
		"topolino": fluff = maxf(fluff - 0.12, 0.25)

	figlio = {
		"name": nome_f,
		"seed": seed_v,
		"sogno": str(a.get("sogno", "boscaiolo")) if rng.randf() < 0.5 \
				else str(b.get("sogno", "boscaiolo")),
		"tratti": tratti,
		"label": "%s %s" % [DESCR[arche], nome_f],
		"archetype": arche,
		"fur": fur.to_html(false),
		"fur2": fur.darkened(0.22).to_html(false),
		"belly": fur.lightened(0.18).to_html(false),
		"inner_ear": Color(str(a.get("inner_ear", "ffb4c8"))).lerp(
				Color(str(b.get("inner_ear", "ffb4c8"))), rng.randf()).to_html(false),
		"dress": dress.to_html(false),
		"dress2": dress.lightened(0.25).to_html(false),
		"size": clampf(_media(a, b, "size", 0.69, rng, 0.03), 0.6, 0.78),
		"head_scale": clampf(_media(a, b, "head_scale", 1.0, rng, 0.04), 0.9, 1.12),
		"ear_len": clampf(ear_base + rng.randf_range(-0.08, 0.08), 0.8, 1.3) * kf,
		"ear_ang": clampf(_media(a, b, "ear_ang", 0.35, rng, 0.04), 0.2, 0.5),
		"eye_r": clampf(_media(a, b, "eye_r", 0.084, rng, 0.004), 0.07, 0.098),
		"eye_gap": clampf(_media(a, b, "eye_gap", 0.15, rng, 0.008), 0.13, 0.175),
		"eye_h": clampf(_media(a, b, "eye_h", 0.025, rng, 0.008), -0.01, 0.06),
		"mouth": str(a.get("mouth", "w")) if rng.randf() < 0.5 else str(b.get("mouth", "w")),
		"blush": clampf(_media(a, b, "blush", 0.55, rng, 0.06), 0.3, 0.85),
		"freckles": lentiggini,
		"fluff": fluff,
		"tail": tails[arche],
		"acc": str(a.get("acc", "")) if rng.randf() < 0.5 else str(b.get("acc", "")),
		"weights": w,
		"indole": indole,
		"quirk": quirk,
	}

	# le sopracciglia e la bocca: lo stile si eredita solo se sta anche nel
	# mazzo della propria specie (un orsetto non porta le sopracciglia
	# sottili del topolino), altrimenti lo pesca dal suo
	figlio["brow"] = _stile_ereditato(a, b, "brow", BROW_DECKS[arche], rng)
	figlio["brow_folto"] = clampf(_media(a, b, "brow_folto", 1.0, rng, 0.06), 0.82, 1.22)
	figlio["brow_arco"] = clampf(_media(a, b, "brow_arco", 1.0, rng, 0.06), 0.8, 1.25)
	figlio["brow_len"] = clampf(_media(a, b, "brow_len", 1.0, rng, 0.05), 0.9, 1.15)
	figlio["bocca"] = _stile_ereditato(a, b, "bocca", MOUTH_DECKS[arche], rng)
	figlio["bocca_larg"] = clampf(_media(a, b, "bocca_larg", 1.0, rng, 0.04), 0.92, 1.1)
	figlio["bocca_spess"] = clampf(_media(a, b, "bocca_spess", 1.0, rng, 0.05), 0.85, 1.2)
	# LA VOCE È SUA E DI NESSUN ALTRO. Non si eredita e non si media: due
	# fratelli hanno gli stessi occhi e due timbri diversi, come si deve.
	# Senza questa riga il figlio resterebbe senza `voce_seed` e Chibiese
	# ripiegherebbe sul vecchio hash di pelo e taglia — cioè la voce
	# tornerebbe a dipendere da che colore ha.
	figlio["voce_seed"] = int(rng.randi())

	# --- e infine il gene che torna: qualcosa di chi è partito ricompare
	# addosso a chi arriva. È tutta la meccanica in una riga. ---
	if not eredita.is_empty():
		figlio = applica_eredita(figlio, eredita)

	# i tratti raccontabili sono DERIVATI: si ricalcolano dai pesi veri di
	# questo figlio, esattamente come in generate()
	figlio["traits"] = _tratti_raccontabili(w, indole, quirk)
	return figlio


## I quattro geni che si possono riconoscere a occhio in un cucciolo, e
## la frase con cui il villaggio li nota. Le chiavi NON si traducono: la
## frase sì, al momento di mostrarla.
const EREDITABILI := {
	"occhi": ["eye_r", "eye_gap", "eye_h"],
	"manto": ["fur", "fur2", "belly"],
	"orecchie": ["ear_len", "ear_ang"],
	"sguardo": ["brow", "brow_folto", "brow_arco", "brow_len"],
}


## Ricalca sul figlio il gene di chi è partito. `eredita` = {"cosa": una
## chiave di EREDITABILI, "dna": il genoma del partito}.
static func applica_eredita(figlio: Dictionary, eredita: Dictionary) -> Dictionary:
	var cosa := str(eredita.get("cosa", ""))
	var da: Dictionary = eredita.get("dna", {})
	if not EREDITABILI.has(cosa) or da.is_empty():
		return figlio
	for k in EREDITABILI[cosa]:
		if da.has(k):
			figlio[k] = da[k]
	# le orecchie di un'altra specie vanno riportate alla propria, o un
	# cucciolo di topo si ritrova le orecchie lunghe di una coniglietta
	if cosa == "orecchie":
		var kd := 1.6 if str(da.get("archetype", "")) == "coniglio" else 1.0
		var kf := 1.6 if str(figlio.get("archetype", "")) == "coniglio" else 1.0
		figlio["ear_len"] = float(da.get("ear_len", 1.0)) / kd * kf
	# lo stile delle sopracciglia deve stare nel mazzo della propria specie
	if cosa == "sguardo":
		var deck: Array = BROW_DECKS.get(str(figlio.get("archetype", "gatto")), [])
		if not str(figlio.get("brow", "")) in deck and not deck.is_empty():
			figlio["brow"] = str(deck[0])
	figlio["eredita"] = {"da": str(eredita.get("da", "")), "cosa": cosa}
	return figlio


static func _media(a: Dictionary, b: Dictionary, k: String, dflt: float,
		rng: RandomNumberGenerator, scarto: float) -> float:
	var m := (float(a.get(k, dflt)) + float(b.get(k, dflt))) * 0.5
	return m + rng.randf_range(-scarto, scarto)


static func _stile_ereditato(a: Dictionary, b: Dictionary, k: String,
		deck: Array, rng: RandomNumberGenerator) -> String:
	var scelti: Array = []
	for g in [a, b]:
		var s := str(g.get(k, ""))
		if s != "" and s in deck:
			scelti.append(s)
	if not scelti.is_empty():
		return str(scelti[rng.randi() % scelti.size()])
	return str(deck[rng.randi() % deck.size()])


## I due desideri più forti + l'indole + l'eventuale stravaganza: la
## stessa derivazione di generate(), in un posto solo.
static func _tratti_raccontabili(w: Dictionary, indole: Array,
		quirk: String) -> Array[String]:
	var brain_script := preload("res://scenes/npc/VillagerBrain.gd")
	var ranked := ["garden", "warmth", "comfort", "window", "walls", "door", "roof"]
	ranked.sort_custom(func(x, y): return float(w[x]) > float(w[y]))
	var out: Array[String] = [TRAIT_LINES[ranked[0]], TRAIT_LINES[ranked[1]]]
	if not indole.is_empty():
		out.append(str(brain_script.INDOLI[str(indole[0])][0]))
	if quirk != "":
		out.append(str(brain_script.QUIRK_LINES[quirk]))
	return out


static func generate(seed_v := -1) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	if seed_v >= 0:
		rng.seed = seed_v
	else:
		rng.randomize()

	var arche: String = ARCHETYPES[rng.randi() % ARCHETYPES.size()]
	var fur := Color(FURS[rng.randi() % FURS.size()])
	var dress := Color(DRESSES[rng.randi() % DRESSES.size()])

	# la personalità: pesi base + carattere dell'archetipo + rumore
	var w := {
		"bias": -6.0,
		"roof": 1.2 + rng.randf_range(0.0, 0.4),
		"walls": 0.7 + rng.randf_range(0.0, 0.5),
		"door": 0.5 + rng.randf_range(0.0, 0.4),
		"window": 0.5 + rng.randf_range(0.0, 0.6),
		"comfort": 0.9 + rng.randf_range(0.0, 0.6),
		"garden": 0.8 + rng.randf_range(0.0, 0.6),
		"warmth": 0.5 + rng.randf_range(0.0, 0.6),
		"welcome": 1.5 + rng.randf_range(0.0, 0.4),
		"sunny": 0.3 + rng.randf_range(0.0, 0.4),
	}
	match arche:
		"coniglio":
			w["garden"] += 0.6
		"orsetto":
			w["warmth"] += 0.7
		"gatto":
			w["comfort"] += 0.5
		"volpina":
			w["walls"] += 0.5
			w["door"] += 0.4
		"topolino":
			w["comfort"] += 0.4
			w["window"] += 0.4

	# l'indole (due, distinte) e l'eventuale stravaganza: la vita
	# interiore del VillagerBrain nasce qui, nel genoma
	var brain_script := preload("res://scenes/npc/VillagerBrain.gd")
	var indole_keys: Array = brain_script.INDOLI.keys()
	var i1 := rng.randi() % indole_keys.size()
	var i2 := (i1 + 1 + rng.randi() % (indole_keys.size() - 1)) % indole_keys.size()
	var indole: Array[String] = [str(indole_keys[i1]), str(indole_keys[i2])]
	var quirk := ""
	if rng.randf() < 0.65:
		quirk = brain_script.QUIRKS[rng.randi() % brain_script.QUIRKS.size()]
	# i due desideri più forti + l'indole + la stravaganza: DERIVATI dai
	# pesi, con la stessa funzione che usa incrocia() — erano due copie
	# della stessa regola e sarebbero divergite alla prima modifica
	var traits := _tratti_raccontabili(w, indole, quirk)

	var name: String = NAMES[rng.randi() % NAMES.size()]
	var tails := {"gatto": "ricciolo", "coniglio": "ponpon", "orsetto": "ponpon",
			"volpina": "volpe", "topolino": "filo"}

	# quanto pelo: orsetti e volpine sono i più spettinati, i topolini
	# restano lisci e ordinati
	var fluff := rng.randf_range(0.35, 0.9)
	match arche:
		"orsetto", "volpina":
			fluff = minf(fluff + 0.25, 1.0)
		"topolino":
			fluff = maxf(fluff - 0.2, 0.25)

	# --- l'ANIMA (vedi scenes/npc/Animo.gd) ---------------------------------
	# Il sogno e i cinque tratti nascono qui, col resto del genoma: due chibi
	# non reagiscono mai allo stesso torto nello stesso modo, ma ciascuno
	# reagisce sempre in modo coerente con chi è. I tratti NON sono uniformi:
	# si tira due volte e si fa la media, così i caratteri estremi restano
	# rari e il villaggio non diventa un carnevale di orgogliosi e codardi.
	var sogni: Array = ANIMO.SOGNI
	var sogno: String = sogni[rng.randi() % sogni.size()]
	var tratti := {}
	for tr in ANIMO.TRATTI:
		tratti[tr] = clampf((rng.randf() + rng.randf()) * 0.5, 0.0, 1.0)
	# l'archetipo inclina il carattere, senza determinarlo
	match arche:
		"orsetto":
			tratti["grinta"] = clampf(float(tratti["grinta"]) + 0.18, 0.0, 1.0)
		"topolino":
			tratti["codardia"] = clampf(float(tratti["codardia"]) + 0.20, 0.0, 1.0)
		"volpina":
			tratti["ambizione"] = clampf(float(tratti["ambizione"]) + 0.18, 0.0, 1.0)
		"gatto":
			tratti["orgoglio"] = clampf(float(tratti["orgoglio"]) + 0.16, 0.0, 1.0)
		"coniglio":
			tratti["lealta"] = clampf(float(tratti["lealta"]) + 0.16, 0.0, 1.0)

	var dna := {
		"name": name,
		"seed": seed_v if seed_v >= 0 else int(rng.seed),
		"sogno": sogno,
		"tratti": tratti,
		"label": "%s %s" % [DESCR[arche], name],
		"archetype": arche,
		"fur": fur.to_html(false),
		"fur2": fur.darkened(0.22).to_html(false),
		"belly": fur.lightened(0.18).to_html(false),
		"inner_ear": Color(1.0, rng.randf_range(0.62, 0.75), rng.randf_range(0.7, 0.8)).to_html(false),
		"dress": dress.to_html(false),
		"dress2": dress.lightened(0.25).to_html(false),
		"size": rng.randf_range(0.6, 0.78),
		"head_scale": rng.randf_range(0.9, 1.12),
		"ear_len": rng.randf_range(0.8, 1.3) * (1.6 if arche == "coniglio" else 1.0),
		"ear_ang": rng.randf_range(0.2, 0.5),
		"eye_r": rng.randf_range(0.07, 0.098),
		"eye_gap": rng.randf_range(0.13, 0.175),
		"eye_h": rng.randf_range(-0.01, 0.06),
		"mouth": ["w", "smile", "o"][rng.randi() % 3],
		"blush": rng.randf_range(0.3, 0.85),
		"freckles": rng.randf() < 0.28,
		"fluff": fluff,
		"tail": tails[arche],
		"acc": ACCESSORIES.POOL[rng.randi() % ACCESSORIES.POOL.size()],
		"weights": w,
		"traits": traits,
		"indole": indole,
		"quirk": quirk,
	}

	# le sopracciglia: lo stile dal mazzo dell'archetipo, poi il singolo
	# individuo le porta più folte o più sottili, più arcuate o più piatte.
	# Tiri IN CODA a tutti gli altri: a parità di seed i geni storici non si
	# spostano (un residente salvato prima delle sopracciglia rinasce uguale).
	var deck: Array = BROW_DECKS[arche]
	dna["brow"] = deck[rng.randi() % deck.size()]
	dna["brow_folto"] = rng.randf_range(0.82, 1.22)
	dna["brow_arco"] = rng.randf_range(0.8, 1.25)
	dna["brow_len"] = rng.randf_range(0.9, 1.15)

	# la bocca, con la stessa regola (e SEMPRE in coda: mai tiri in mezzo)
	var mdeck: Array = MOUTH_DECKS[arche]
	dna["bocca"] = mdeck[rng.randi() % mdeck.size()]
	dna["bocca_larg"] = rng.randf_range(0.92, 1.1)
	dna["bocca_spess"] = rng.randf_range(0.85, 1.2)

	# IL SEME DELLA VOCE — che non si tocca mai più.
	# La voce del Chibiese nasceva da nome+PELO+archetipo+taglia, e finché
	# il pelo era per sempre andava bene. Dal momento in cui un aspetto si
	# può CAMBIARE, quella formula diventa un difetto grave: una tinta ti
	# cambierebbe il timbro, cioè chi sei a orecchio. La voce si pianta qui,
	# alla nascita, e da qui non si muove più. (In coda a tutti gli altri
	# tiri, come vuole la regola: a parità di seed i geni storici non si
	# spostano di una virgola.)
	dna["voce_seed"] = int(rng.randi())
	return dna


## I GENI ESTETICI — la fonte unica di ciò che si può cambiare in un corpo
## già nato. È il vocabolario su cui poggerà l'estetista: quello che NON è
## in questa lista non si tocca, e non è pignoleria — è la differenza fra
## cambiare pettinatura e cambiare persona.
##
## Restano fuori, apposta:
##   · `archetype`, `size`, `head_scale`, gli occhi, le orecchie, la coda —
##     il corpo con cui sei nato;
##   · `name`, `sogno`, `tratti`, `indole`, `quirk`, `weights` — chi sei;
##   · `seed` e `voce_seed` — la tua identità e la tua voce.
const ESTETICI := [
	"fur", "fur2", "belly", "inner_ear",   # il manto e la sua tinta
	"dress", "dress2",                      # il vestitino
	"blush", "freckles", "fluff",           # guanciotte, lentiggini, spettinatura
	"brow", "brow_folto", "brow_arco", "brow_len",   # le sopracciglia
	"bocca", "bocca_larg", "bocca_spess",   # la bocca
	"acc",                                  # l'accessorio
]


## Applica dei geni estetici a un genoma, IGNORANDO tutto ciò che non è
## estetico. È la guardia contro l'errore che rovinerebbe tutto: passare
## per sbaglio un `sogno` o un `voce_seed` dentro un cambio di look.
## PURA: torna un genoma nuovo, non tocca quello dato.
static func con_estetica(dna: Dictionary, nuovi: Dictionary) -> Dictionary:
	var out := dna.duplicate(true)
	for g in nuovi:
		if str(g) in ESTETICI:
			out[str(g)] = nuovi[g]
	return out


## I soli geni estetici di un genoma: quello che l'estetista ha davanti
## quando ti guarda, e quello che si salva quando cambi.
static func estetica_di(dna: Dictionary) -> Dictionary:
	var out := {}
	for g in ESTETICI:
		if dna.has(g):
			out[g] = dna[g]
	return out
