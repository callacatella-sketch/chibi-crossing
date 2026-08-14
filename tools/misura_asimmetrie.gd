extends SceneTree
## IL METRO DELLE DUE METÀ — e il metro dello SCATTO dei livelli.
##
##   ~/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . \
##     --script res://tools/misura_asimmetrie.gd
##
## Due domande che nessuna asserzione booleana sa fare, e per cui non serve
## nessun modello né nessun mondo:
##
## 1. **DUE ARTI SONO UN FILO SOLO?** Non lo dice il fatto che i due numeri
##    siano diversi: `0,30` e `0,22` sono diversi e restano un filo solo,
##    perché uno è l'altro moltiplicato per una costante — partono insieme,
##    arrivano insieme, e in mezzo stanno sempre nello stesso rapporto. Il
##    metro giusto è il **RESIDUO DI FORMA**: si cerca la costante `k` che
##    meglio sovrappone la destra alla sinistra, e si guarda quanto resta.
##    Zero = un filo solo, e nessuna differenza di ampiezza può salvarlo.
##    Poi si cerca lo **SFASAMENTO**: il ritardo τ che sovrappone meglio le
##    due — se il minimo è a τ = 0, le due metà stanno sullo stesso orologio.
##
## 2. **UN LIVELLO CHE SI SOSPENDE SALTA?** Si misura lo scatto per
##    fotogramma sul rig vero, entrando e uscendo da una scena scritta a
##    mano, coi due livelli accesi addosso.
##
## ⚠️ **L'ORACOLO È INDIPENDENTE DAL CODICE CHE GIUDICA.** Il residuo e lo
## sfasamento si calcolano qui, sui campioni, senza chiedere niente a
## `Gesti` se non i valori dei canali: chiedere alla tabella se è
## asimmetrica sarebbe chiedere al giudice se è d'accordo con sé stesso.

const GESTI := preload("res://scenes/npc/Gesti.gd")
const VISITOR := preload("res://scenes/npc/Visitor.gd")
const DNAG := preload("res://scenes/npc/ChibiDNA.gd")

const DT := 1.0 / 60.0
## ⚠️ **NON UNA FASE SOLA.** La fase è del genoma e governa quanto è pigra la
## metà che segue: misurarne una vuol dire misurare UN vicino. E la prima
## stesura di questo banco aveva pescato proprio 1,7 — che è il minimo esatto
## della pigrizia, cioè il vicino più simmetrico del villaggio — e leggeva
## metà della cura credendo di leggerla tutta. Si campiona la ruota, e si
## riporta il PEGGIORE: la garanzia è per ogni corpo, non per il corpo medio.
const FASI := 16

## Cosa si misura: nome, gesto, dati, quanto dura il campionamento.
const PROVE := [
	["il RACCOLTO · le braccia", "raccolto", {}, 5.1, "ax0", "ax1"],
	["il RACCOLTO · le orecchie", "raccolto", {}, 5.1, "ear", "ear+dx"],
	["il RACCOLTO→RIALZO · orecchie", "raccolto", {"rialzo": 0.6}, 5.1, "ear", "ear+dx"],
	["il LARGO · le braccia", "largo", {}, 3.0, "ax0", "ax1"],
	["il LARGO · le orecchie", "largo", {}, 3.0, "ear", "ear+dx"],
	["il PUNTO · le orecchie", "punto", {}, 3.4, "ear", "ear+dx"],
	["il RIALZO · le orecchie", "rialzo", {}, 1.6, "ear", "ear+dx"],
]


func _init() -> void:
	_go()


func _go() -> void:
	print("\n" + "█".repeat(74))
	print("  IL METRO DELLE DUE METÀ")
	print("█".repeat(74))
	print("  %-30s %7s %8s %8s %8s %9s"
			% ["  (il PEGGIORE dei corpi)", "scarto", "residuo", "peggio%",
					"meglio%", "sfas.max"])
	for p: Array in PROVE:
		_una(p)
	_i_livelli()
	print("\n" + "█".repeat(74))
	print("  LO SCATTO DEI LIVELLI (rig vero, scena scritta a mano)")
	print("█".repeat(74))
	await process_frame
	await _lo_scatto()
	quit(0)


# =========================================================================
# 1 · IL RESIDUO DI FORMA e LO SFASAMENTO
# =========================================================================

func _una(p: Array) -> void:
	var nome := str(p[0])
	var g := str(p[1])
	var d: Dictionary = p[2]
	var dur := float(p[3])
	var quale := str(p[4])
	var n := int(dur / DT)
	var righe: Array = []
	for f in FASI:
		var fase := 0.05 + TAU * float(f) / float(FASI)
		var sx: Array[float] = []
		var dx: Array[float] = []
		for i in n:
			var c: Dictionary = GESTI.bersagli(g, float(i) * DT, d, fase)
			if quale == "ax0":
				sx.append(float(c["ax0"]))
				dx.append(float(c["ax1"]))
			else:
				sx.append(float(c["ear"]))
				dx.append(float(c["ear"]) + float(c["ear_dx"]))
		righe.append(_conta(sx, dx))
	_stampa(nome, righe)


func _i_livelli() -> void:
	# la coda somatica è un LIVELLO: non ha una busta, ha un'ampiezza che
	# decade. Si campiona come la vede il corpo (`_gesto_soma`: l'orologio è
	# quello del vicino, non quello del sussulto).
	for quale: String in ["ax0", "ear"]:
		var n := int(GESTI.CODA_VITA / DT)
		var righe: Array = []
		for f in FASI:
			var fase := 0.05 + TAU * float(f) / float(FASI)
			var sx: Array[float] = []
			var dx: Array[float] = []
			for i in n:
				var t := float(i) * DT
				var a: float = GESTI.coda_ampiezza(1.0, t)
				var c: Dictionary = GESTI.coda_canali(a, t, fase)
				if quale == "ax0":
					sx.append(float(c["ax0"]))
					dx.append(float(c["ax1"]))
				else:
					sx.append(float(c["ear"]))
					dx.append(float(c["ear"]) + float(c["ear_dx"]))
			righe.append(_conta(sx, dx))
		_stampa("la CODA · %s" % ("le braccia" if quale == "ax0" else "le orecchie"),
				righe)


## Il residuo di forma e lo sfasamento. `k` è la costante che meglio
## sovrappone la destra alla sinistra (minimi quadrati); il residuo è quel che
## resta, in frazione dell'ampiezza della sinistra.
func _conta(sx: Array[float], dx: Array[float]) -> Array:
	var amp := 0.0
	var scarto := 0.0
	for i in sx.size():
		amp = maxf(amp, absf(sx[i]))
		scarto = maxf(scarto, absf(dx[i] - sx[i]))
	var res := _residuo(sx, dx, 0)
	# lo sfasamento: il ritardo che sovrappone meglio le due metà
	var best := res
	var lag := 0
	for l in range(-30, 31):
		var r := _residuo(sx, dx, l)
		if r < best:
			best = r
			lag = l
	return [scarto, res, 100.0 * res / maxf(amp, 1e-9), float(lag) * DT * 1000.0]


## Il PEGGIORE fra i corpi, non la media: la garanzia è per ogni corpo.
func _stampa(nome: String, righe: Array) -> void:
	var peggio: Array = righe[0]
	var meglio: Array = righe[0]
	var lag_max := 0.0
	for r: Array in righe:
		if float(r[2]) < float(peggio[2]):
			peggio = r
		if float(r[2]) > float(meglio[2]):
			meglio = r
		lag_max = maxf(lag_max, absf(float(r[3])))
	print("  %-30s %7.4f %8.5f %7.2f%% %7.2f%% %6.0f ms"
			% [nome, float(peggio[0]), float(peggio[1]), float(peggio[2]),
					float(meglio[2]), lag_max])


func _residuo(sx: Array[float], dx: Array[float], lag: int) -> float:
	# k ai minimi quadrati sulla porzione sovrapposta
	var num := 0.0
	var den := 0.0
	for i in sx.size():
		var j := i + lag
		if j < 0 or j >= sx.size():
			continue
		num += sx[i] * dx[j]
		den += sx[i] * sx[i]
	if den <= 1e-12:
		return 0.0
	var k := num / den
	var peggio := 0.0
	for i in sx.size():
		var j := i + lag
		if j < 0 or j >= sx.size():
			continue
		peggio = maxf(peggio, absf(dx[j] - k * sx[i]))
	return peggio


# =========================================================================
# 2 · LO SCATTO DEI LIVELLI
# =========================================================================

func _lo_scatto() -> void:
	var v = VISITOR.new()
	v.species = "chibi"
	v.dna = DNAG.generate(4242)
	root.add_child(v)
	v.set_process(false)
	for _i in 4:
		v._process(DT)
	v._enter_state("r_idle")
	v.set("_timer", 1.0e9)
	# ⚠️ E PRIMA DI TUTTO: quanto salta il livello quando NASCE. Il sussulto
	# è istantaneo per definizione (è uno spavento), ma il numero va saputo —
	# è l'unico gradino che resta in tutto il vocabolario, ed è dichiarato.
	# …e si LASCIA ASSESTARE il corpo prima di misurare, o si misura
	# l'assestamento dello stato invece del sussulto: senza questi due
	# secondi il banco leggeva **0,5817 sul BRACCIO**, e quel canale al
	# sussulto vale 0,30 — la differenza era il ciclo del passo che si
	# spegneva, cioè una cosa che col livello non c'entra niente.
	for _i in 120:
		v._process(DT)
	var pre := _rig(v)
	v.call("somatico", 1.0)
	v._process(DT)
	var nasce := 0.0
	var q_nasce := ""
	for c in _rig(v):
		var dd: float = absf(float(_rig(v)[c]) - float(pre[c]))
		if dd > nasce:
			nasce = dd
			q_nasce = c
	print("  il SUSSULTO che nasce (dichiarato, non curato): %.4f su «%s»"
			% [nasce, q_nasce])
	# i DUE livelli addosso, dalle porte vere
	v.call("capo_pende", true)
	v.call("somatico", 1.0)
	# si aspetta che il capo sia LONTANO da zero: uno scatto da zero non è
	# uno scatto. Si campiona finché il rollio non è al suo colmo.
	var meglio := 0.0
	var giri := 0
	while giri < 600:
		v._process(DT)
		giri += 1
		var x := absf(float(v.get("_gs_capo_x")))
		if x > meglio:
			meglio = x
		if x > 0.06 and giri > 30:
			break
	print("  il rollio del capo, all'istante della scena: %.4f rad" % meglio)
	# LA SOSPENSIONE, dalla porta vera: una scena scritta a mano. Corta,
	# perché la coda somatica deve essere ANCORA VIVA quando la scena
	# finisce — o all'uscita non ci sarebbe niente da rimettere e il banco
	# misurerebbe zero su un codice qualunque.
	#
	# ⚠️ E NON SI RIACCENDE NIENTE ALL'USCITA. Una prima stesura chiamava
	# `somatico(1.0)` prima di misurare l'uscita e leggeva 0,4079: era il
	# SUSSULTO — che è istantaneo per definizione — non la rampa. Un banco
	# che riaccende la cosa che sta misurando misura sé stesso.
	v.call("apri_scena", 6.0)
	print("  ENTRANDO nella scena: %s" % _finestra(v, 45))
	for _i in 30:
		v._process(DT)
	print("  dentro la scena:      ritmo %.3f   coda viva %s   orecchio %.4f"
			% [float(v.get("_gs_r")),
					"sì" if float(v.get("_gs_soma")) > 0.0 else "no",
					float(_rig(v)["ear1"])])
	v.call("chiudi_scena")
	print("  USCENDO dalla scena:  %s" % _finestra(v, 45))
	v.free()


## Lo scatto per fotogramma su una finestra di N fotogrammi: il massimo su
## tutti i canali del rig, più quello del RITMO (che non è un canale del rig
## ma è quello che cambia i tempi di una coreografia).
func _finestra(v, n: int) -> String:
	var prima := _rig(v)
	var r_prima := float(v.get("_gs_r"))
	var salto := 0.0
	var quale := ""
	var salto_r := 0.0
	for _i in n:
		v._process(DT)
		var ora := _rig(v)
		for c in ora:
			var dd: float = absf(float(ora[c]) - float(prima[c]))
			if dd > salto:
				salto = dd
				quale = c
		prima = ora
		var r_ora := float(v.get("_gs_r"))
		salto_r = maxf(salto_r, absf(r_ora - r_prima))
		r_prima = r_ora
	return "rig %.4f su «%s» · ritmo %.4f" % [salto, quale, salto_r]


func _rig(v) -> Dictionary:
	var out := {}
	var vis: Node3D = v.get("_vis")
	var testa: Node3D = v.get("_head")
	var corpo: Node3D = v.get("_corpo")
	out["vis.x"] = vis.position.x
	out["vis.rz"] = vis.rotation.z
	out["vis.y"] = vis.position.y
	out["vis.z"] = vis.position.z
	out["testa.rz"] = testa.rotation.z
	out["testa.y"] = testa.position.y
	out["corpo.sy"] = corpo.scale.y
	var orecchie: Array = v.get("_c_ears")
	if orecchie.size() == 2:
		out["ear0"] = (orecchie[0] as Node3D).rotation.x
		out["ear1"] = (orecchie[1] as Node3D).rotation.x
	var braccia: Array = v.get("_c_arms")
	if braccia.size() == 2:
		out["arm0"] = (braccia[0] as Node3D).rotation.x
		out["arm1"] = (braccia[1] as Node3D).rotation.x
	var coda: Node3D = v.get("_tail_p")
	if coda != null:
		out["coda"] = coda.rotation.x
	return out
