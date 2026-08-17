extends SceneTree
## IL PICCO DEI FATTI — la spesa che una media non racconta.
##
## `_fatti_di` rinfresca i FATTI del mondo per un residente ogni
## FATTI_OGNI frame, e il commento dice «sfalsato per residente, così a
## ogni frame se ne rinfresca circa uno». La MEDIA lo confermerebbe sempre,
## anche se fosse falso — ventotto rinfreschi ogni trenta frame fanno circa
## uno per frame comunque siano distribuiti. Quello che si sente giocando
## non è la media: è il PICCO, cioè quanti `_brain_ctx` +
## `_luoghi_del_piano` cadono nello STESSO frame.
##
## Qui si misura nel villaggio VERO, con ventotto vicini veri creati tutti
## nello stesso frame — che è quel che fa `load_extra` aprendo una partita.
##
## COME SI RILEVA UN RINFRESCO SENZA TOCCARE IL CODICE VERO: fra una
## chiamata e l'altra `fatti_scad` cala di ESATTAMENTE 1.0 quando la cache
## risponde. Se il valore dopo non è quello prima meno uno, quel residente
## ha ricalcolato. È esatto anche quando il seme vale zero (dove un
## confronto «è cresciuto?» sbaglierebbe), e non chiede di sporcare
## `_fatti_di` con un contatore.
##
##   Godot --headless --path . --script res://tools/misura_picco_fatti.gd
##
## Si legge così: «frame caldi» è in quanti frame distinti è caduto almeno
## un rinfresco (più alti sono, meglio è distribuito), «picco» è il massimo
## in un frame solo. Il frame del CARICAMENTO si conta a parte: lì nessuno
## ha ancora i fatti e devono calcolarli tutti, ed è giusto così — succede
## una volta, mentre il mondo si sta ancora costruendo.

const VICINI := 28
const FRAME := 600

## I nomi veri che il villaggio dà ai suoi abitanti: il seme è
## `hash(label)`, quindi misurare con «Prova0..27» misurerebbe la
## distribuzione di una stringa che nel gioco non esiste.
const NOMI := ["Mochi", "Pino", "Bea", "Nocciola", "Tilly", "Gigi", "Momo",
		"Rana", "Ciuffo", "Bruno", "Lilla", "Pepe", "Rosa", "Tobia", "Mela",
		"Vento", "Fiocco", "Grillo", "Nube", "Sasso", "Trilli", "Bacca",
		"Cocco", "Dado", "Elmo", "Fava", "Gelso", "Iride"]


func _init() -> void:
	_go()


func _trova(gruppo: String) -> Node:
	for n in get_nodes_in_group(gruppo):
		return n
	return null


func _go() -> void:
	var ok: int = change_scene_to_file("res://scenes/levels/MainLevel.tscn")
	if ok != OK:
		push_error("MainLevel non si apre")
		quit(1)
		return
	for _i in 24:
		await process_frame

	var vis := _trova("visitors")
	if vis == null:
		push_error("manca Visitors")
		quit(1)
		return
	if vis.get_node_or_null("CuoreSonno") == null:
		# senza EcsMondo `_fatti_di` esce dalla porta di servizio e non
		# misuri niente: meglio dirlo che stampare degli zeri
		push_error("EcsMondo assente: la GDExtension non è caricata")
		quit(1)
		return

	# I VICINI NASCONO TUTTI NELLO STESSO FRAME. Non è una comodità della
	# prova: è esattamente quel che fa `load_extra` quando si apre una
	# partita salvata, ed è la condizione che mette in fase i contatori.
	var VS := load("res://scenes/npc/Visitor.gd")
	var DNAG := load("res://scenes/npc/ChibiDNA.gd")
	var residenti: Array = vis.get("_residents")
	for k in VICINI:
		var v = VS.new()
		v.dna = DNAG.generate(7000 + k * 31)
		vis.add_child(v)
		v.mode = "resident"
		v.position = Vector3(float(k % 7) * 1.6 - 5.0, 0, float(k / 7) * 1.6 + 2.0)
		v._enter_state("r_idle")
		residenti.append({"node": v, "label": NOMI[k], "dna": v.dna,
				"cell": Vector2i(k % 7, k / 7), "species": "chibi"})
		vis.call("_ensure_brain", residenti[residenti.size() - 1])
	print("residenti insediati: ", residenti.size())

	# il primo frame dopo la nascita: è il caricamento, e si conta a parte
	var prima := _istantanea(residenti)
	await process_frame
	var carico := _conta(prima, _istantanea(residenti))

	var per_frame: Array[int] = []
	for _i in FRAME:
		prima = _istantanea(residenti)
		await process_frame
		per_frame.append(_conta(prima, _istantanea(residenti)))

	var caldi := 0
	var picco := 0
	var totale := 0
	var isto := {}
	for c in per_frame:
		if c > 0:
			caldi += 1
		picco = maxi(picco, c)
		totale += c
		isto[c] = int(isto.get(c, 0)) + 1

	print("")
	print("=== PICCO DEI FATTI · %d vicini · %d frame ===" % [VICINI, FRAME])
	print("frame del caricamento: %d rinfreschi insieme (una volta sola)" % carico)
	print("frame caldi:  %d su %d" % [caldi, FRAME])
	print("picco:        %d rinfreschi nello stesso frame" % picco)
	print("totale:       %d rinfreschi" % totale)
	print("media:        %.2f per frame" % (float(totale) / float(FRAME)))
	print("attesa:       %.2f per frame (%d vicini / %d)"
			% [float(VICINI) / 31.0, VICINI, 31])
	var chiavi := isto.keys()
	chiavi.sort()
	for c in chiavi:
		print("   %2d rinfreschi in un frame · %d volte" % [int(c), int(isto[c])])
	print("")
	print("VERDETTO: ", "sfalsato" if picco <= VICINI / 4 else "IN FASE (picco = quasi tutti insieme)")
	quit()


## `fatti_scad` di ogni residente, con la marca «aveva già i fatti».
func _istantanea(residenti: Array) -> Array:
	var out: Array = []
	for r in residenti:
		var rr := r as Dictionary
		out.append({
			"c": rr.has("fatti_scad"),
			"v": float(rr.get("fatti_scad", 0.0)),
		})
	return out


## Un rinfresco = il contatore NON è calato di uno.
func _conta(prima: Array, dopo: Array) -> int:
	var n := 0
	for i in prima.size():
		var a: Dictionary = prima[i]
		var b: Dictionary = dopo[i]
		if not bool(a["c"]):
			n += 1  # il primo giro in assoluto
			continue
		if not is_equal_approx(float(b["v"]), float(a["v"]) - 1.0):
			n += 1
	return n
