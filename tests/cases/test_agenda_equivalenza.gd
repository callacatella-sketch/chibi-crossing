extends RefCounted
## LA PROVA CHE IL VILLAGGIO NON È CAMBIATO.
##
## L'utility AI di questo gioco esisteva già: `VillagerBrain.choose()`
## pesava sette azioni su bisogni, indole e contesto. La Fase 2 non l'ha
## inventata — l'ha portata in C++ e le ha dato una macchina IAUS vera
## (curve parametriche invece di formule moltiplicative scritte a mano).
##
## Il rischio numero uno, quindi, non è che non funzioni: è che i vicini si
## comportino DIVERSAMENTE senza che nessuno se ne accorga. Qui si misura.
## `tests/oracolo_agenda.gd` conserva le formule di prima, congelate, e si
## pretende l'uguaglianza ESATTA su tutte e sette le azioni — non `almost`,
## che nasconderebbe proprio la classe di errore che si sta cercando.
##
## Le divergenze VOLUTE sono tre, e sono provate una per una come casi
## nominati: un test che le infilasse in un `if` generico non proverebbe
## niente.

const ORACOLO := preload("res://tests/oracolo_agenda.gd")
const BRAIN := preload("res://scenes/npc/VillagerBrain.gd")

# i nomi dei bisogni nell'ordine del ponte
const ORDINE := ["pancino", "energia", "compagnia", "meraviglia", "cura"]


func run(t) -> void:
	if not ClassDB.class_exists("EcsMondo"):
		t.ok(false, "EcsMondo non registrata: la GDExtension non è caricata")
		return
	var m = ClassDB.instantiate("EcsMondo")
	_equivalenza_esatta(t, m)
	_non_e_una_tautologia(t, m)
	_divergenza_meraviglia(t, m)
	_divergenza_regia(t, m)
	_divergenza_gironzola(t, m)
	m.free()


func _needs(v: Array) -> Dictionary:
	var d := {}
	for i in ORDINE.size():
		d[ORDINE[i]] = float(v[i])
	return d


func _packed(v: Array) -> PackedFloat64Array:
	var p := PackedFloat64Array()
	p.resize(5)
	for i in 5:
		p[i] = float(v[i])
	return p


## LA SPAZZATA. Bisogni × fatti × caratteri: per ogni combinazione i sette
## punteggi del C++ devono essere gli STESSI double di quelli di prima.
func _equivalenza_esatta(t, m) -> void:
	var livelli := [0.0, 0.13, 0.5, 0.87, 1.0]
	var caratteri := [
		[], ["goloso"], ["dormiglione"], ["chiacchierone"], ["timido"],
		["sognatore"], ["ordinato"], ["chiacchierone", "timido"],
		["goloso", "ordinato"], ["sognatore", "dormiglione"],
	]
	var quirks := ["", "canta_alla_luna", "ballerino"]
	# i sei fatti di sempre, in tutte le combinazioni
	var nomi_fatti := ["mattina", "sera_stellata", "aiuola_da_annaffiare",
			"spuntino_vicino", "amico_in_giro", "regia"]
	var azioni := ["spuntino", "riposo", "quattro_chiacchiere",
			"cura_giardino", "meraviglia", "stella", "regia"]

	var confronti := 0
	var divergenze := 0
	var peggiore := ""
	for c in caratteri:
		for q in quirks:
			for combo in 64:
				var ctx := {}
				var acc: Array = []
				for b in 6:
					var on: bool = (combo & (1 << b)) != 0
					ctx[nomi_fatti[b]] = on
					if on:
						acc.append(nomi_fatti[b])
				# i due gate nuovi si accendono SEMPRE qui: in questa prova
				# si confronta il motore, non le divergenze (che hanno i
				# loro casi nominati qui sotto)
				acc.append("meraviglia_posto")
				acc.append("regia_pronta")
				for l in livelli:
					var vals := [l, 1.0 - l, l * 0.5 + 0.25, 1.0 - l * 0.5, l]
					var vecchio: Dictionary = ORACOLO.punteggi(_needs(vals), ctx, c, q)
					var nuovo: PackedFloat64Array = m.debug_punteggi(_packed(vals),
							m.maschera_fatti(PackedStringArray(acc)),
							m.maschera_indole(PackedStringArray(c)),
							m.indice_quirk(q))
					for a in azioni.size():
						confronti += 1
						if nuovo[a] != float(vecchio[azioni[a]]):
							divergenze += 1
							if peggiore == "":
								peggiore = "%s: C++ %.17g, prima %.17g (car %s, q %s, fatti %s)" \
										% [azioni[a], nuovo[a], float(vecchio[azioni[a]]),
										str(c), q, str(acc)]
	t.ok(confronti > 60000, "la spazzata è ampia (%d confronti)" % confronti)
	t.eq(divergenze, 0,
			"i punteggi in C++ sono IDENTICI a quelli di prima — %s" % peggiore)


## L'ANTI-TAUTOLOGIA: se l'oracolo e il C++ tornassero entrambi zero su
## tutto, la prova qui sopra sarebbe verde e non direbbe niente. È il
## difetto che la revisione della Fase 1 ha trovato due volte.
func _non_e_una_tautologia(t, m) -> void:
	var vals := [0.1, 0.2, 0.3, 0.4, 0.5]
	var ctx := {"mattina": true, "spuntino_vicino": true, "amico_in_giro": true,
			"aiuola_da_annaffiare": true, "regia": true, "sera_stellata": true}
	var vecchio: Dictionary = ORACOLO.punteggi(_needs(vals), ctx, ["sognatore"], "")
	var quanti_vivi := 0
	for k in vecchio:
		if float(vecchio[k]) > 0.0:
			quanti_vivi += 1
	t.ok(quanti_vivi >= 6,
			"l'oracolo produce punteggi VIVI (%d su 7), se no la prova sopra non prova niente"
					% quanti_vivi)
	var nuovo: PackedFloat64Array = m.debug_punteggi(_packed(vals),
			m.maschera_fatti(PackedStringArray(["mattina", "spuntino_vicino",
					"amico_in_giro", "aiuola_da_annaffiare", "regia",
					"sera_stellata", "meraviglia_posto", "regia_pronta"])),
			m.maschera_indole(PackedStringArray(["sognatore"])), -1)
	var vivi_cpp := 0
	for i in 7:
		if nuovo[i] > 0.0:
			vivi_cpp += 1
	t.ok(vivi_cpp >= 6, "e anche il C++ (%d su 7)" % vivi_cpp)


## DIVERGENZA 1, voluta: oggi «meraviglia» può vincere anche dove non c'è
## né lo stagno né il Grande Albero, e la scena cade su «wander» in
## silenzio. Adesso l'azione è INFATTIBILE senza il posto.
func _divergenza_meraviglia(t, m) -> void:
	# meraviglia a zero: la vuole tanto
	var vals := [1.0, 1.0, 1.0, 0.0, 1.0]
	var con_posto: PackedFloat64Array = m.debug_punteggi(_packed(vals),
			m.maschera_fatti(PackedStringArray(["meraviglia_posto"])), 0, -1)
	var senza: PackedFloat64Array = m.debug_punteggi(_packed(vals),
			m.maschera_fatti(PackedStringArray([])), 0, -1)
	t.ok(con_posto[m.AZ_MERAVIGLIA] > 1.0, "col posto, la meraviglia chiama forte")
	t.almost(senza[m.AZ_MERAVIGLIA], 0.0,
			"senza un posto da guardare l'azione non è fattibile (divergenza voluta)", 1e-12)
	var vecchio: Dictionary = ORACOLO.punteggi(_needs(vals), {}, [], "")
	t.ok(float(vecchio["meraviglia"]) > 1.0,
			"…e PRIMA vinceva lo stesso, per poi cadere su «wander» senza dirlo")


## DIVERGENZA 2, voluta: «regia» valeva 0.75 anche quando il Regista non
## aveva ancora un piano per quel residente.
func _divergenza_regia(t, m) -> void:
	var vals := [1.0, 1.0, 1.0, 1.0, 1.0]
	var pronta: PackedFloat64Array = m.debug_punteggi(_packed(vals),
			m.maschera_fatti(PackedStringArray(["regia", "regia_pronta"])), 0, -1)
	var non_pronta: PackedFloat64Array = m.debug_punteggi(_packed(vals),
			m.maschera_fatti(PackedStringArray(["regia"])), 0, -1)
	t.almost(pronta[m.AZ_REGIA], 0.75, "col piano pronto la regia vale 0.75", 1e-12)
	t.almost(non_pronta[m.AZ_REGIA], 0.0,
			"senza piano non è fattibile (divergenza voluta)", 1e-12)
	var vecchio: Dictionary = ORACOLO.punteggi(_needs(vals), {"regia": true}, [], "")
	t.almost(float(vecchio["regia"]), 0.75,
			"…e PRIMA valeva 0.75 comunque, anche senza piano", 1e-12)


## DIVERGENZA 3, voluta: «gironzola» non è un'azione nuova, è il ripiego
## silenzioso di prima che diventa una scelta dichiarata.
func _divergenza_gironzola(t, m) -> void:
	var vals := [1.0, 1.0, 1.0, 1.0, 1.0]
	var p: PackedFloat64Array = m.debug_punteggi(_packed(vals),
			m.maschera_fatti(PackedStringArray([])), 0, -1)
	t.ok(p[m.AZ_GIRONZOLA] > 0.0,
			"a bisogni pieni e mondo vuoto resta il gironzolare, e lo si DICE")
	for i in 7:
		t.almost(p[i], 0.0, "e nessuna delle sette di prima vince (%d)" % i, 1e-12)
