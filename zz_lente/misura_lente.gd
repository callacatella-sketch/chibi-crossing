extends SceneTree
## IL METRO DELLA LENTE — numeri, non opinioni. Serve a legare le soglie dei
## test nuovi a misure che NON sono la costante sorvegliata.

const GESTI := preload("res://scenes/npc/Gesti.gd")

func _initialize() -> void:
	_orecchie()
	_coda_residuo()
	_capo_istanti()
	quit(0)


## 1 · QUANTO SI PIEGANO LE ORECCHIE, per ogni evento e per ogni variante.
## La tabella del verso misurata in Gesti.gd dice: 1,97 a 0,20 · 1,78 a 0,30
## · 1,62 a 0,40 · 1,39 a 0,55 ✗ · 1,12 a 0,75 ✗ (criterio 1,6).
func _orecchie() -> void:
	print("--- 1 · le ORECCHIE degli eventi (max |ear| su tutte e due le metà)")
	for nome: String in GESTI.EVENTI:
		var peggio := 0.0
		for d: Dictionary in [{}, {"decisa": true}, {"rialzo": 0.6},
				{"via": -1.0}, {"tenuta": 2.4}, {"buio": true}]:
			for f in 16:
				var fase := TAU * float(f) / 16.0
				var dur: float = GESTI.durata(nome, d)
				var i := 0
				while float(i) / 240.0 <= dur:
					var c: Dictionary = GESTI.bersagli(nome, float(i) / 240.0, d, fase)
					peggio = maxf(peggio, absf(float(c["ear"])))
					peggio = maxf(peggio, absf(float(c["ear"]) + float(c["ear_dx"])))
					i += 1
		print("    %-10s max |ear| = %.4f" % [nome, peggio])
	# e i due livelli, che NON sono parole
	var p2 := 0.0
	var i2 := 0
	while float(i2) / 240.0 <= GESTI.CODA_VITA:
		var c: Dictionary = GESTI.coda_canali(GESTI.coda_ampiezza(1.0, float(i2) / 240.0),
				float(i2) / 240.0, 0.9)
		p2 = maxf(p2, absf(float(c["ear"])))
		p2 = maxf(p2, absf(float(c["ear"]) + float(c["ear_dx"])))
		i2 += 1
	print("    %-10s max |ear| = %.4f  (LIVELLO, non una parola)" % ["coda", p2])


## 2 · IL RESIDUO DI FORMA della Coda, per vedere quanto pesa TREM_DX.
func _coda_residuo() -> void:
	print("--- 2 · la CODA: residuo di forma delle due metà (peggiore su 16 fasi)")
	var peggio_or := 1.0e9
	var peggio_br := 1.0e9
	for f in 16:
		var fase := 0.05 + TAU * float(f) / 16.0
		var sx_or: Array[float] = []
		var dx_or: Array[float] = []
		var sx_br: Array[float] = []
		var dx_br: Array[float] = []
		var n := int(GESTI.CODA_VITA * 60.0)
		for i in n:
			var tt := float(i) / 60.0
			var c: Dictionary = GESTI.coda_canali(GESTI.coda_ampiezza(1.0, tt), tt, fase)
			sx_or.append(float(c["ear"]))
			dx_or.append(float(c["ear"]) + float(c["ear_dx"]))
			sx_br.append(float(c["ax0"]))
			dx_br.append(float(c["ax1"]))
		peggio_or = minf(peggio_or, _residuo(sx_or, dx_or))
		peggio_br = minf(peggio_br, _residuo(sx_br, dx_br))
	print("    orecchie %.4f   braccia %.4f   (TREM_DX = %.2f)"
			% [peggio_or, peggio_br, GESTI.TREM_DX])


func _residuo(sx: Array[float], dx: Array[float]) -> float:
	var num := 0.0
	var den := 0.0
	var amp := 0.0
	for i in sx.size():
		num += sx[i] * dx[i]
		den += sx[i] * sx[i]
		amp = maxf(amp, absf(sx[i]))
	if den <= 1.0e-12 or amp <= 1.0e-9:
		return 0.0
	var k := num / den
	var peggio := 0.0
	for i in sx.size():
		peggio = maxf(peggio, absf(dx[i] - k * sx[i]))
	return peggio / amp


## 3 · GLI ISTANTI del capo: due genomi si sincronizzano?
func _capo_istanti() -> void:
	print("--- 3 · il CAPO: intervalli fra un trasferimento e l'altro")
	for fase: float in [0.7, 2.9]:
		var t := 0.0
		var iv: Array[float] = []
		for _i in 12:
			var d: float = GESTI.capo_intervallo(t, fase)
			iv.append(d)
			t += d
		var s := ""
		for x in iv:
			s += "%.2f " % x
		print("    fase %.1f: %s" % [fase, s])
