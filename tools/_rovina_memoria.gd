extends SceneTree

## BANCO TEMPORANEO (lente «rovina») — LA MEMORIA CHE CRESCE.
##
## `tools/prova_giudice.gd` azzera la memoria ogni tre sere: misura il giudice
## su due lettere di storia. Qui la memoria e' quella di una PARTITA LUNGA —
## non si azzera mai — ed e' l'unica condizione in cui la domanda «il
## villaggio diventa una filastrocca?» ha senso.
##
##   CHIBI_GIUDICE=<cartella provino> Godot --headless --path . --script res://tools/_rovina_memoria.gd

const SUG := preload("res://scenes/npc/Suggeritore.gd")
const GIU := preload("res://scenes/npc/Giudice.gd")

const MAZZETTO := 5
const SERE := 3
const GIRI := 50
const B_SENTITO := 1
const B_SU_DI_ME := 2
const B_NESSUNO := 4294967295

var _dove := ""


func _init() -> void:
	_dove = OS.get_environment("CHIBI_GIUDICE")
	if _dove == "":
		print("serve CHIBI_GIUDICE")
		quit(1)
		return
	_go()
	quit(0)


func _go() -> void:
	var rit := _ritratto()
	var cit: Array = SUG.citazioni(rit)
	print("%-12s %-24s %7s %8s %s" % ["modello", "memoria", "lettere", "silenzio",
			"silenzio per quinto della partita"])
	for f in _mazzi():
		var d: Dictionary = f
		var bozze: Array = d["B_gram"]
		for modo in ["azzerata ogni 3 sere", "che CRESCE (partita lunga)"]:
			var e := _simula(bozze, rit, cit, modo.begins_with("che"))
			print("%-12s %-24s %7d %7.0f%%   %s" % [str(d["modello"]), modo,
					int(e["lettere"]), 100.0 * float(e["silenzi"]) / float(e["sere"]),
					str(e["per_quinto"])])
	print("")
	print("«per quinto» = percentuale di sere mute nei cinque quinti successivi della partita")


func _simula(bozze: Array, rit: Dictionary, cit: Array, cresce: bool) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260811
	var tutte := []
	var sere := 0
	var silenzi := 0
	var muti_per_sera := []
	for giro in GIRI:
		var ordine := _mescola(bozze, rng)
		var mandate := [] if not cresce else tutte
		for s in SERE:
			var mazzetto := ordine.slice(s * MAZZETTO, (s + 1) * MAZZETTO)
			if mazzetto.size() < MAZZETTO:
				break
			sere += 1
			var memoria := {"sue": mandate.slice(max(0, mandate.size() - 6)) if not cresce
					else mandate.duplicate()}
			var e: Dictionary = GIU.scegli(mazzetto, rit, memoria)
			if int(e["scelta"]) < 0:
				silenzi += 1
				muti_per_sera.append(1)
			else:
				muti_per_sera.append(0)
				mandate.append(str(e["testo"]))
				if not cresce:
					tutte.append(str(e["testo"]))
	var per_quinto := []
	var n := muti_per_sera.size()
	for q in 5:
		var a := int(float(n) * float(q) / 5.0)
		var b := int(float(n) * float(q + 1) / 5.0)
		var somma := 0
		for k in range(a, b):
			somma += int(muti_per_sera[k])
		per_quinto.append("%d%%" % int(round(100.0 * float(somma) / float(max(1, b - a)))))
	return {"lettere": (tutte if not cresce else tutte).size(), "sere": sere,
			"silenzi": silenzi, "per_quinto": " ".join(per_quinto)}


func _mescola(bozze: Array, rng: RandomNumberGenerator) -> Array:
	var out := []
	for b in bozze:
		out.append(str(b))
	for i in range(out.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = out[i]
		out[i] = out[j]
		out[j] = tmp
	return out


func _ritratto() -> Dictionary:
	return {
		"nome": "la volpina Papavero", "eta": "giovane",
		"indole": ["dormiglione"], "quirk": "canta_alla_luna",
		"casa": Vector3(4, 0, 6), "azione": "quattro_chiacchiere",
		"obiettivo": "", "stagione": "autunno", "momento": "pomeriggio",
		"ciclo": 240.0, "protagonista": "Mochi", "compito": "lettera",
		"nomi": {3: "la volpina Prugna"},
		"verbi": ["annaffia", "semina", "raccoglie", "costruisce",
				"taglia", "pesca", "cucina", "dona"],
		"cose": ["fiore", "cibo", "casa", "fuoco", "pesce", "amico"],
		"gusto": PackedFloat64Array([1.0, 1.0, 2.2, 0.0, 1.0, 1.0]),
		"tinte": {"ammirazione": 2.9, "gratitudine": 1.4,
				"interesse": PackedFloat64Array([0, 0, 2.2, 0, 0, 0])},
		"ora": 900.0, "mezza_vita": 120.0,
		"pesi": PackedFloat64Array([1.6, 1.4, 0.8, 0.6, 0.5]),
		"bandiere": {"sentito": B_SENTITO, "su_di_me": B_SU_DI_ME,
				"detto": 4, "nessuno": B_NESSUNO},
		"ricordi": [
			# ha ricevuto un dono dalle zampe di Mochi, poco fa, vicino a casa
			{"verbo": 7, "bandiere": B_SU_DI_ME, "quante": 1,
					"px": 5.0, "pz": 7.0, "quando": 895.0, "soggetto": B_NESSUNO},
			# l'ha vista annaffiare a lungo, poco fa, vicino a casa
			{"verbo": 0, "bandiere": 0, "quante": 6,
					"px": 5.0, "pz": 7.0, "quando": 895.0, "soggetto": B_NESSUNO},
			# costruire, poco fa, dall'altra parte del villaggio
			{"verbo": 3, "bandiere": 0, "quante": 1,
					"px": 34.0, "pz": 32.0, "quando": 895.0, "soggetto": B_NESSUNO},
			# regalare qualcosa alla volpina Prugna, poco fa, vicino
			{"verbo": 7, "bandiere": 0, "quante": 1,
					"px": 5.0, "pz": 7.0, "quando": 895.0, "soggetto": 3},
			# pescare: gliel'hanno raccontato, dall'altra parte
			{"verbo": 5, "bandiere": B_SENTITO, "quante": 1,
					"px": 34.0, "pz": 32.0, "quando": 895.0, "soggetto": B_NESSUNO},
		],
	}


## LE FRASI DELLA GRAMMATICA con cui i modelli hanno davvero scritto.

func _mazzi() -> Array:
	var out := []
	var dir := DirAccess.open(_dove + "/risultati_provino")
	if dir == null:
		return out
	var nomi := dir.get_files()
	nomi.sort()
	for n in nomi:
		if not str(n).ends_with(".json"):
			continue
		var f := FileAccess.open(_dove + "/risultati_provino/" + str(n), FileAccess.READ)
		var d = JSON.parse_string(f.get_as_text())
		if d == null:
			continue
		var voce := {"modello": str(d["modello"])}
		for cond in ["A_gram", "B_gram", "B_libero", "EN_gram"]:
			var testi := []
			for g in (d[cond] as Array):
				testi.append(str((g as Dictionary)["testo"]))
			voce[cond] = testi
		out.append(voce)
	return out


## TANTI GIRI DI TRE SERE. Ogni giro rimescola il mazzo e lo taglia in tre
## mazzetti da cinque; dentro un giro nessuna bozza torna due volte.
##
## Il dado sta QUI, nel banco, e non nel giudice: mescolare le bozze è il
## mestiere del modello (due generazioni non escono mai nello stesso ordine),
## e un giudice con un dado dentro non sarebbe riproducibile. Il seme è fisso,
## così due esecuzioni di questo file danno gli stessi numeri.
