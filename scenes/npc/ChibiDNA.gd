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

const NAMES := [
	"Nocciola", "Miele", "Cannella", "Nuvola", "Fragolina", "Biscotto",
	"Mirtillo", "Vaniglia", "Zenzero", "Pepita", "Ciliegia", "Castagna",
	"Brioche", "Sesamo", "Loto", "Camomilla",
]

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

	# i due desideri più forti diventano i tratti raccontabili
	var ranked := ["garden", "warmth", "comfort", "window", "walls", "door", "roof"]
	ranked.sort_custom(func(a, b): return w[a] > w[b])
	var traits: Array[String] = [TRAIT_LINES[ranked[0]], TRAIT_LINES[ranked[1]]]

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
	traits.append(str(brain_script.INDOLI[indole[0]][0]))
	if quirk != "":
		traits.append(str(brain_script.QUIRK_LINES[quirk]))

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

	return {
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
