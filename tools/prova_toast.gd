extends SceneTree
## IL CANALE DELLA VITA QUOTIDIANA — cosa il villaggio ti dice, e quanto spesso.
##
##   ~/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . \
##       --script res://tools/prova_toast.gd
##
## ────────────────────────────────────────────────────────────────────────
## PERCHÉ ESISTE
## ────────────────────────────────────────────────────────────────────────
##
## La Fase 4 ha una conseguenza che nessuno aveva previsto e che nessun
## test poteva vedere, perché non aggiunge **una riga di testo nuova**: chi
## ti ha vista annaffiare ha voglia di annaffiare (il modulatore di
## `cura_giardino` sale fino a +47%), quindi lo fa più spesso, quindi il
## villaggio te lo SCRIVE IN FACCIA più spesso. Fai il gesto gentile, e il
## gioco comincia a mandarti notifiche.
##
## È la regola «il villaggio non commenta MAI» violata per una via
## laterale, e si vede solo mettendo in fila i toast di un quarto d'ora.
##
## ────────────────────────────────────────────────────────────────────────
## COME SI MISURA UN FILTRO
## ────────────────────────────────────────────────────────────────────────
##
## **Guardando anche quello che ha fermato.** Un canale che sceglie cosa
## NON dire non si giudica dai messaggi usciti: due tarature molto diverse
## danno lo stesso numero di toast se il lucchetto globale è saturo. Perciò
## la prova accende il DIARIO (`debug_registra_vita`) e legge le notizie
## OFFERTE, non solo quelle uscite — e poi le rigioca attraverso il
## predicato VERO (`Visitors.vita_zitta`, statico e puro) a cinque
## tarature diverse, stampando i cinque feed uno sotto l'altro.
##
## Le notizie offerte non dipendono dalla taratura (un toast non cambia il
## comportamento di nessuno): il confronto fra i cinque feed è quindi
## ESATTO, non una simulazione — è lo stesso villaggio, letto con cinque
## filtri.
##
## ────────────────────────────────────────────────────────────────────────
## LE DUE FASI
## ────────────────────────────────────────────────────────────────────────
##
## **Freddo**: quattro vicini che non hanno mai visto Mochi fare niente.
## **Caldo**: gli stessi corpi, gli stessi bisogni di partenza, la stessa
## durata — ma con addosso il ricordo di averti vista annaffiare.
##
## Fra le due fasi cambia UNA cosa: il modulatore. Se il numero di toast
## cambia, il colpevole è quello.

const BANCO := preload("res://tools/banco.gd")
const VISITORS := preload("res://scenes/npc/Visitors.gd")

## Quanto dura una fase, in secondi: un quarto d'ora di gioco, cioè quasi
## quattro giornate del villaggio. Sotto i dieci minuti il rumore del dado
## copre la differenza fra le due fasi (provato).
const FASE := 900.0

const CELLA_0 := Vector2i(-14, 12)
const QUANTI := 4
## Sei aiuole, tenute assetate per tutta la prova: il villaggio non deve
## MAI restare senza un'aiuola da annaffiare, o si misura la scarsità
## invece della voglia.
const AIUOLE: Array[Vector2i] = [
	Vector2i(-14, 9), Vector2i(-12, 9), Vector2i(-10, 9),
	Vector2i(-8, 9), Vector2i(-13, 7), Vector2i(-9, 7),
]
## Ogni quanto si ricontrollano le aiuole (e si contano le annaffiature).
const RIARMO := 3.0

## Mochi lontanissima: da vicino `Percezione` semina ricordi veri e la
## fase «fredda» smetterebbe di essere fredda a metà misura.
const MOCHI_VIA := Vector3(-40.0, 0.0, -40.0)

## Le cinque tarature del provino, in secondi di quiete per GENERE.
## 0 = il canale di oggi (solo il lucchetto globale).
const TARATURE: Array[float] = [0.0, 60.0, 120.0, 240.0, 480.0]

var b: RefCounted = null
var _annaffiate := 0


func _init() -> void:
	b = BANCO.new(self, "")
	_via.call_deferred()


func _via() -> void:
	if not await b.apri():
		quit(1)
		return
	if b.cuore == null:
		print("GUASTO: il cuore ECS non c'è (GDExtension non caricata?)")
		quit(1)
		return
	b.player.global_position = MOCHI_VIA
	var rr := await _posa()
	if rr.size() < QUANTI:
		quit(1)
		return

	var freddo := await _fase(rr, false)
	var caldo := await _fase(rr, true)

	_referto("FREDDO", freddo)
	_referto("CALDO", caldo)
	_confronto(freddo, caldo)
	_provino(freddo, caldo)

	quit(b.verdetto("IL CANALE DELLA VITA QUOTIDIANA"))


# =========================================================================
#  l'apparecchiatura
# =========================================================================

func _posa() -> Array:
	b.visitors.call("debug_reset")
	for k in QUANTI:
		var cella := CELLA_0 + Vector2i(k * 2, 0)
		b.build.call("place_cell", cella, "Letto", 0, false)
		b.build.call("place_cell", cella, "Tetto", 0, false)
	for a in AIUOLE:
		b.build.call("place_cell", a, "Aiuola", 0, false)
	b.build.call("aggiorna_varchi_ora")
	await create_timer(0.8).timeout
	_riarma()
	for k in QUANTI:
		b.visitors.call("debug_settle", 2000 + k * 311, CELLA_0 + Vector2i(k * 2, 0))
	await create_timer(1.5).timeout
	var rr: Array = b.visitors.get("_residents")
	b.dico(rr.size() == QUANTI, "ci sono %d residenti" % rr.size())
	b.dico((b.build.call("get_placed_by_name", "Aiuola") as Array).size() == AIUOLE.size(),
			"e %d aiuole" % AIUOLE.size())
	return rr


## Rimette sete a tutte le aiuole, e conta quelle che erano state
## annaffiate: è il conto delle ANNAFFIATURE VERE, il gesto — da tenere
## separato dal conto dei TOAST, che è quello che il giocatore legge.
func _riarma() -> void:
	for a in AIUOLE:
		var bed: Node3D = _aiuola(a)
		if bed != null and bool(b.garden.get("_beds")[bed]["watered"]):
			_annaffiate += 1
		b.garden.call("debug_set_stage", a, 1, false)


func _aiuola(cella: Vector2i) -> Node3D:
	for node in (b.garden.get("_beds") as Dictionary):
		if ((b.garden.get("_beds")[node] as Dictionary)["cell"] as Vector2i) == cella:
			return node as Node3D
	return null


## I bisogni di partenza, identici nelle due fasi: senza questa riga la
## seconda fase parte da dove la prima è finita e il confronto misura
## soprattutto quello.
func _rimetti_bisogni(rr: Array) -> void:
	for k in rr.size():
		var brain: RefCounted = b.visitors.call("debug_brain", k)
		if brain == null:
			continue
		brain.needs["pancino"] = 0.85
		brain.needs["energia"] = 0.95
		brain.needs["compagnia"] = 0.70
		brain.needs["cura"] = 0.30
		brain.needs["meraviglia"] = 0.60


func _fase(rr: Array, caldo: bool) -> Dictionary:
	print("\n--- fase %s ---" % ("CALDA (ti hanno vista annaffiare)" if caldo else "FREDDA"))
	_rimetti_bisogni(rr)
	_annaffiate = 0
	b.visitors.call("debug_registra_vita", true)
	var i_giardino := int(b.cuore.call("indice_azione", "cura_giardino"))
	var v_annaffia := int(b.cuore.call("indice_verbo", "annaffia"))
	var mod_max := 0.0
	var t := 0.0
	var t_riarmo := 0.0
	var t_semina := 0.0
	var t_spia := 0.0
	while t < FASE:
		await process_frame
		var dt := get_root().get_process_delta_time()
		t += dt
		t_riarmo += dt
		t_semina += dt
		t_spia += dt
		if t_riarmo >= RIARMO:
			t_riarmo = 0.0
			_riarma()
		# IL CALDO SI TIENE ACCESO: un ricordo dimezza ogni mezza giornata,
		# quindi senza rinfrescarlo la fase «calda» sarebbe calda solo nel
		# primo minuto e la misura direbbe che non succede niente.
		if caldo and t_semina >= 20.0:
			t_semina = 0.0
			for r in rr:
				b.cuore.call("osserva", int((r as Dictionary)["ecs"]), v_annaffia,
						Vector3(-11.0, 0.0, 9.0), -1)
		# il modulatore si guarda ogni cinque secondi: `debug_emozioni`
		# alloca un dizionario e tre array, e a ogni frame per quattro
		# vicini il banco costerebbe più del villaggio che sta misurando
		if t_spia >= 5.0:
			t_spia = 0.0
			for r in rr:
				var e: Dictionary = b.cuore.call("debug_emozioni", int((r as Dictionary)["ecs"]))
				mod_max = maxf(mod_max, float((e["mod"] as PackedFloat64Array)[i_giardino]))
	var diario: Array = (b.visitors.get("debug_vita_diario") as Array).duplicate(true)
	b.visitors.call("debug_registra_vita", false)
	print("  modulatore di cura_giardino, il più alto visto: %.4f" % mod_max)
	print("  annaffiature VERE (il gesto): %d" % _annaffiate)
	return {"diario": diario, "mod": mod_max, "annaffiate": _annaffiate}


# =========================================================================
#  i referti
# =========================================================================

func _conta(diario: Array, solo_uscite: bool) -> Dictionary:
	var per_genere := {}
	for v in diario:
		var d := v as Dictionary
		if solo_uscite and not bool(d["uscita"]):
			continue
		var g := str(d["genere"])
		per_genere[g] = int(per_genere.get(g, 0)) + 1
	return per_genere


func _referto(nome: String, f: Dictionary) -> void:
	var offerte := _conta(f["diario"] as Array, false)
	var uscite := _conta(f["diario"] as Array, true)
	print("\n  [%s] in %d s: %d notizie offerte, %d uscite"
			% [nome, int(FASE), (f["diario"] as Array).size(),
			_quante(uscite)])
	var generi: Array = offerte.keys()
	generi.sort()
	for g in generi:
		print("     %-12s offerte %3d → uscite %3d"
				% [g, int(offerte[g]), int(uscite.get(g, 0))])


func _quante(d: Dictionary) -> int:
	var n := 0
	for k in d:
		n += int(d[k])
	return n


func _confronto(freddo: Dictionary, caldo: Dictionary) -> void:
	print("\n--- il confronto ---")
	var of_f := _conta(freddo["diario"] as Array, false)
	var of_c := _conta(caldo["diario"] as Array, false)
	var us_f := _conta(freddo["diario"] as Array, true)
	var us_c := _conta(caldo["diario"] as Array, true)
	print("  IL GESTO   annaffiature vere   freddo %3d → caldo %3d   (%+.0f%%)"
			% [int(freddo["annaffiate"]), int(caldo["annaffiate"]),
			_delta(float(freddo["annaffiate"]), float(caldo["annaffiate"]))])
	print("  L'OFFERTA  «annaffia» offerte  freddo %3d → caldo %3d   (%+.0f%%)"
			% [int(of_f.get("annaffia", 0)), int(of_c.get("annaffia", 0)),
			_delta(float(of_f.get("annaffia", 0)), float(of_c.get("annaffia", 0)))])
	print("  IL FEED    «annaffia» USCITE   freddo %3d → caldo %3d   (%+.0f%%)"
			% [int(us_f.get("annaffia", 0)), int(us_c.get("annaffia", 0)),
			_delta(float(us_f.get("annaffia", 0)), float(us_c.get("annaffia", 0)))])
	print("  IL FEED    toast in tutto      freddo %3d → caldo %3d   (%+.0f%%)"
			% [_quante(us_f), _quante(us_c),
			_delta(float(_quante(us_f)), float(_quante(us_c)))])


func _delta(a: float, b_: float) -> float:
	if a <= 0.0:
		return 0.0
	return (b_ / a - 1.0) * 100.0


# =========================================================================
#  il provino: gli stessi eventi, cinque filtri
# =========================================================================

## Rigioca il diario attraverso il PREDICATO VERO, alla taratura data, e
## torna i testi che il giocatore leggerebbe. Il lucchetto globale è quello
## di produzione (`Visitors.QUIETE`), letto di là.
func _rigioca(diario: Array, quiete_genere: float) -> Array:
	var ultimo_qualunque := -1.0e18
	var ultimo := {}
	var fuori: Array = []
	for v in diario:
		var d := v as Dictionary
		var t := float(d["t"])
		var g := str(d["genere"])
		if VISITORS.vita_zitta(t, ultimo_qualunque,
				float(ultimo.get(g, -1.0e18)), VISITORS.QUIETE, quiete_genere):
			continue
		ultimo_qualunque = t
		ultimo[g] = t
		fuori.append({"t": t, "genere": g, "testo": str(d["testo"])})
	return fuori


func _provino(freddo: Dictionary, caldo: Dictionary) -> void:
	print("\n=========================================================")
	print(" IL PROVINO — lo stesso quarto d'ora, cinque filtri")
	print("=========================================================")
	for q in TARATURE:
		var f := _rigioca(freddo["diario"] as Array, q)
		var c := _rigioca(caldo["diario"] as Array, q)
		print("\n  ### quiete per genere = %.0f s%s" % [q,
				"   (il canale di oggi)" if q == 0.0 else ""])
		print("      toast in tutto: freddo %d, caldo %d" % [f.size(), c.size()])
		print("      di cui «annaffia»: freddo %d, caldo %d"
				% [_solo(f, "annaffia").size(), _solo(c, "annaffia").size()])
		print("      --- quello che il giocatore LEGGE nel quarto d'ora CALDO:")
		for v in c:
			print("          %6.1f s  %s" % [float((v as Dictionary)["t"]),
					str((v as Dictionary)["testo"])])


func _solo(fuori: Array, genere: String) -> Array:
	var out: Array = []
	for v in fuori:
		if str((v as Dictionary)["genere"]) == genere:
			out.append(v)
	return out
