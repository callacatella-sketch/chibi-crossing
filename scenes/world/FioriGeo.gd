extends RefCounted
## GLI ORGANI DI UN FIORE: petalo, lamina, stelo, capolino, spiga.
##
## Tutte funzioni `static`, senza stato e senza albero della scena. È la
## casa UNICA delle leggi di forma dei fiori: prima vivevano in tre posti
## che il prato non poteva chiamare — `_fio_corolla` e `_bis_petalo` in
## [BuildCatalog] (il petalo obovato con la punta INCISA), `_cesto_lembo_mesh`
## (la lamina che si incurva e ha la nervatura) — e il prato, che non
## poteva raggiungerle, si costruiva i petali con delle SFERE SCALATE.
##
## ⚠️ ED È QUELLO IL DIFETTO, non il conteggio dei poligoni. Una margherita
## del prato costa 1464 triangoli e sembra una girandola di confetti,
## perché un ellissoide schiacciato **porta le normali di una sfera**: la
## luce ci cade sopra come su una biglia, non come su un petalo. La regola
## che tutto questo file serve a rispettare sta già scritta in casa, in
## [BuildCatalog._bis_petalo]: «è la forma, non la tinta, a togliere il
## sapore di caramella: un ellissoide schiacciato resta un confetto».
##
## LE CINQUE LEGGI DEL PETALO (tutte misurabili sulla mesh, tutte visibili):
##  1. OBOVATO — base stretta, massimo oltre la metà, apice largo:
##     `w = W · sin(π·(0.20 + 0.62·u))^0.45`. Un rettangolo arrotondato è
##     un nastro; questo è un petalo.
##  2. LA PUNTA È INCISA — `x -= incisione·u¹⁰·(1−v²)` tira indietro la
##     mezzeria del margine. È l'incisione a far leggere «fiore» invece
##     di «girandola»: senza, cinque punte a mandorla fanno una stella.
##  3. LA PUNTA CADE — la spina `y = L·(arco·u − (arco+caduta)·u²)` sale e
##     poi ricade. Un petalo dritto è un raggio di ruota.
##  4. LA CONCA — positiva i bordi salgono (petalo a doccia), negativa
##     sale la mezzeria (nervatura di foglia). È la legge del cesto:
##     «la luce ci scorre sopra invece di spegnersi tutta insieme, ed è
##     quella la differenza fra una foglia e un adesivo».
##  5. LA TORSIONE — `roll = torsione·u²`: nessun petalo è planare, e due
##     petali della stessa corolla non prendono mai la stessa luce.
##
## E HA DUE FACCE. Dorso e ventre sono due fogli con normali OPPOSTE,
## separati da uno spessore che si annulla sul margine (`(1−v²)·(1−u³)`):
## il petalo si chiude da solo, senza un triangolo in più, e in controluce
## il bordo diventa una LINEA DI SPESSORE invece di un taglio — che è la
## sola cosa che rende visibile il `translucency` che i materiali dei
## fiori hanno già a 0.5 e che oggi non si vede.
##
## LA MASCHERA D'ORGANO viaggia nel COLOR dei vertici — `r` petalo, `g`
## cuore, `b` verde, e `a` la FASE DEL PETALO (per il fremito nel vento).
## Serve a mettere un fiore intero in UNA superficie sola: tre superfici
## sono tre draw call per un oggetto grande otto centimetri.
## È la stessa convenzione che `wildflower.gdshader` usa già.

## Le maschere. Il quarto canale lo riempie chi costruisce, petalo per
## petalo: due petali con la stessa fase sono lo stesso timbro due volte.
const PETALO := Color(1.0, 0.0, 0.0, 0.0)
const CUORE := Color(0.0, 1.0, 0.0, 0.0)
const VERDE := Color(0.0, 0.0, 1.0, 0.0)


# ------------------------------------------------------------- IL PETALO

## La griglia di un petalo, nel suo frame: x lungo (radice→punta), y su,
## z attraverso. `u` ∈ [0,1] va dalla radice alla punta, `v` ∈ [−1,1]
## attraversa il lembo.
##
## Opzioni (tutte con un valore di serie che fa un petalo di margherita):
##   incisione · arco · caduta · conca · torsione · spessore · ventre
static func petalo_griglia(lung: float, largo: float, nu: int, nv: int,
		o := {}) -> Array:
	var incisione: float = o.get("incisione", 0.17)
	var arco: float = o.get("arco", 0.30)
	var caduta: float = o.get("caduta", 0.26)
	var conca: float = o.get("conca", 0.20)
	var torsione: float = o.get("torsione", 0.10)
	# ⚠️ I VALORI DI SERIE SONO QUELLI DELLA MARGHERITA, e devono essere
	# quelli BUONI: con `0.20 · 0.62 · 0.45` il seno diventa un plateau —
	# la mezza larghezza va 0.79 → 1.00 → 0.75, cioè un rettangolo con la
	# punta intaccata. Un nastro.
	var ventre: float = o.get("ventre", 0.10)
	var apertura: float = o.get("apertura", 0.72)
	var punta: float = o.get("punta", 0.75)
	var righe: Array = []
	for iu in nu + 1:
		var u := float(iu) / float(nu)
		var riga: Array[Vector3] = []
		# la spina: sale e ricade. `caduta` è dove finisce la punta,
		# in frazioni della lunghezza, sotto l'attacco
		var spina := lung * (arco * u - (arco + caduta) * u * u)
		var mezza := largo * pow(sin(PI * (ventre + apertura * u)), punta)
		var rr := torsione * u * u
		var cr := cos(rr)
		var sr := sin(rr)
		for iv in nv + 1:
			var v := lerpf(-1.0, 1.0, float(iv) / float(nv))
			# l'INCISIONE: la mezzeria del margine (v = 0) rientra, i due
			# lobi (v = ±1) restano avanti. L'esponente 10 la tiene tutta
			# sull'ultimo decimo del petalo, dove sta un'incisione vera
			var px := lung * (u - incisione * pow(u, 10.0) * (1.0 - v * v))
			# LA CONCA, ruotata insieme al lembo dalla torsione.
			# ⚠️ Si misura sulla MEZZA LARGHEZZA, non sulla lunghezza: è
			# una curvatura TRASVERSALE, e legarla alla lunghezza la fa
			# esplodere sui petali lunghi e stretti. Con `conca` sulla
			# lunghezza, un petalo di tulipano lungo 62 mm prendeva 16 mm
			# di incurvatura per lato: i bordi attraversavano il fiore e
			# uscivano dall'altra parte, e in cima usciva una corona
			# sfrangiata che sembrava un bicchiere di carta strappato.
			var su := conca * mezza * v * v * u
			var lato := mezza * v
			riga.append(Vector3(px, spina + su * cr - lato * sr,
					su * sr + lato * cr))
		righe.append(riga)
	return righe


## Le normali di una griglia APERTA (un lembo, non un anello): differenze
## centrali all'interno, one-sided ai bordi. `grid_normals` di WorldGeo
## non va bene qui — quella chiude l'anello con il modulo, e un petalo
## non è un anello: il suo margine è un bordo vero.
static func lembo_normali(g: Array) -> Array:
	var nu: int = g.size()
	var nv: int = (g[0] as Array).size()
	var out: Array = []
	for i in nu:
		var riga: Array[Vector3] = []
		var sotto: Array = g[maxi(i - 1, 0)]
		var sopra: Array = g[mini(i + 1, nu - 1)]
		for j in nv:
			var t_u: Vector3 = (sopra[j] as Vector3) - (sotto[j] as Vector3)
			var t_v: Vector3 = (g[i][mini(j + 1, nv - 1)] as Vector3) \
					- (g[i][maxi(j - 1, 0)] as Vector3)
			var n := t_v.cross(t_u)
			if n.length_squared() < 1e-12:
				riga.append(Vector3.UP)
				continue
			riga.append(n.normalized())
		out.append(riga)
	return out


## Il petalo dentro un SurfaceTool già aperto, portato dove serve da
## `base`. Due fogli, normali opposte, spessore che si chiude sul margine.
## `fase` finisce in COLOR.a: è la fase personale di QUESTO petalo.
static func petalo_su(st: SurfaceTool, base: Transform3D, lung: float,
		largo: float, nu := 3, nv := 2, o := {}, fase := 0.0,
		maschera := PETALO) -> void:
	var g := petalo_griglia(lung, largo, nu, nv, o)
	var nrm := lembo_normali(g)
	var spessore: float = o.get("spessore", lung * 0.012)
	var col := Color(maschera.r, maschera.g, maschera.b, fase)
	# i due fogli: + lungo la normale il dorso, − il ventre. Lo spessore
	# si annulla sul margine (v = ±1) e sulla punta (u = 1), quindi i due
	# fogli CONDIVIDONO il bordo: il petalo è chiuso senza cuciture
	var facce: Array = []
	for lato in [1.0, -1.0]:
		var pos: Array = []
		for iu in nu + 1:
			var u := float(iu) / float(nu)
			var riga: Array[Vector3] = []
			for iv in nv + 1:
				var v := lerpf(-1.0, 1.0, float(iv) / float(nv))
				var sp: float = spessore * (1.0 - v * v) * (1.0 - pow(u, 3.0))
				riga.append((g[iu][iv] as Vector3)
						+ (nrm[iu][iv] as Vector3) * sp * float(lato))
			pos.append(riga)
		facce.append(pos)
	for lato in 2:
		var segno := 1.0 if lato == 0 else -1.0
		var pos: Array = facce[lato]
		for iu in nu:
			for iv in nv:
				var quad: Array = [[iu, iv], [iu, iv + 1], [iu + 1, iv],
						[iu + 1, iv], [iu, iv + 1], [iu + 1, iv + 1]]
				if lato == 1:
					quad.reverse()
				for idx: Array in quad:
					st.set_color(col)
					st.set_normal(base.basis * ((nrm[idx[0]][idx[1]] as Vector3)
							* segno))
					st.add_vertex(base * (pos[idx[0]][idx[1]] as Vector3))


# ------------------------------------------------------------- LA LAMINA

## Il contorno LANCEOLATO di una foglia, campionato sul solo dorso: base
## all'origine, massimo a un terzo, punta fine. `dente` ondula il margine
## (una foglia liscia è una goccia; il margine è la firma della specie).
static func contorno_lancia(lung: float, largo: float, passi: int,
		dente := 0.0, denti := 7) -> Array:
	var out: Array = []
	for i in passi:
		var t := float(i) / float(passi - 1)
		var w := largo * pow(sin(PI * (0.06 + 0.90 * t)), 0.62)
		w *= 1.0 + dente * sin(float(denti) * t * TAU)
		out.append(Vector2(lung * t, w))
	return out


## La lamina: una superficie a sella dolce, non un prisma estruso.
## `curva` la fa ricadere in punta, `carena` alza la mezzeria sui bordi —
## la nervatura è FORMA, non una riga dipinta.
static func lamina_su(st: SurfaceTool, base: Transform3D, contorno: Array,
		curva: float, carena: float, maschera := VERDE) -> void:
	var passi: int = contorno.size()
	var nv := 2
	var g: Array = []
	for i in passi:
		var p: Vector2 = contorno[i]
		var riga: Array[Vector3] = []
		for iv in nv + 1:
			var v := lerpf(-1.0, 1.0, float(iv) / float(nv))
			var rho := Vector2(p.x, p.y * v)
			riga.append(Vector3(rho.x,
					-curva * rho.length_squared() - carena * absf(rho.y),
					rho.y))
		g.append(riga)
	var nrm := lembo_normali(g)
	var col := Color(maschera.r, maschera.g, maschera.b, 0.0)
	for lato in 2:
		var segno := 1.0 if lato == 0 else -1.0
		for iu in passi - 1:
			for iv in nv:
				var quad: Array = [[iu, iv], [iu, iv + 1], [iu + 1, iv],
						[iu + 1, iv], [iu, iv + 1], [iu + 1, iv + 1]]
				if lato == 1:
					quad.reverse()
				for idx: Array in quad:
					st.set_color(col)
					st.set_normal(base.basis * ((nrm[idx[0]][idx[1]] as Vector3)
							* segno))
					st.add_vertex(base * (g[idx[0]][idx[1]] as Vector3))


# -------------------------------------------------------------- LO STELO

## Lo stelo: UN tubo su una curva vera, non due cilindri accostati.
## Il gomito dei due cilindri (0.12 rad a metà altezza) si vedeva a
## ottanta centimetri come uno spigolo aperto — e uno stelo non ha
## spigoli, ha una curva sola che parte dritta e si china verso la cima.
##
## `punti` è la spina (dal basso in alto), `raggi` il raggio a ogni punto.
## Si campiona una Catmull-Rom fra i punti, così tre controlli bastano.
static func stelo_su(st: SurfaceTool, base: Transform3D, punti: Array,
		raggi: Array, lati := 5, anelli := 6, maschera := VERDE) -> void:
	var col := Color(maschera.r, maschera.g, maschera.b, 0.0)
	var spina: Array = []
	var raggio: Array = []
	for k in anelli + 1:
		var t := float(k) / float(anelli)
		spina.append(_catmull(punti, t))
		raggio.append(_lerp_lista(raggi, t))
	var g: Array = []
	for k in spina.size():
		var p: Vector3 = spina[k]
		var avanti: Vector3 = (spina[mini(k + 1, spina.size() - 1)] as Vector3) \
				- (spina[maxi(k - 1, 0)] as Vector3)
		if avanti.length_squared() < 1e-10:
			avanti = Vector3.UP
		avanti = avanti.normalized()
		var destra := avanti.cross(Vector3.FORWARD)
		if destra.length_squared() < 1e-6:
			destra = avanti.cross(Vector3.RIGHT)
		destra = destra.normalized()
		var fuori := destra.cross(avanti).normalized()
		var riga: Array[Vector3] = []
		for j in lati:
			var a := TAU * float(j) / float(lati)
			riga.append(p + (destra * cos(a) + fuori * sin(a))
					* float(raggio[k]))
		g.append(riga)
	for k in g.size() - 1:
		for j in lati:
			var j2 := (j + 1) % lati
			for idx: Array in [[k, j], [k + 1, j], [k + 1, j2],
					[k, j], [k + 1, j2], [k, j2]]:
				var p: Vector3 = g[idx[0]][idx[1]]
				var asse: Vector3 = spina[idx[0]]
				st.set_color(col)
				st.set_normal(base.basis * (p - asse).normalized())
				st.add_vertex(base * p)


static func _catmull(p: Array, t: float) -> Vector3:
	var n: int = p.size()
	if n == 1:
		return p[0]
	var x := clampf(t, 0.0, 1.0) * float(n - 1)
	var i := clampi(int(floor(x)), 0, n - 2)
	var f := x - float(i)
	var p0: Vector3 = p[maxi(i - 1, 0)]
	var p1: Vector3 = p[i]
	var p2: Vector3 = p[i + 1]
	var p3: Vector3 = p[mini(i + 2, n - 1)]
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * f
			+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * f * f
			+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * f * f * f)


static func _lerp_lista(v: Array, t: float) -> float:
	var n: int = v.size()
	if n == 1:
		return float(v[0])
	var x := clampf(t, 0.0, 1.0) * float(n - 1)
	var i := clampi(int(floor(x)), 0, n - 2)
	return lerpf(float(v[i]), float(v[i + 1]), x - float(i))


# ------------------------------------------------------------ IL CAPOLINO

## La CUPOLA del ricettacolo: il bottone dorato di una margherita non è
## una sfera schiacciata, è un disco appena bombato di flosculi — con la
## conca al centro (i fiorellini di mezzo non sono ancora aperti) e il
## bordo che si rialza. `grana` fa i flosculi: senza, è un pulsante.
## `lobi` + `lobo` fanno una corolla a LOBI (un non-ti-scordar-di-me, un
## flox): il raggio si modula sull'angolo, e quello che esce non è un
## poligono ma un fiorellino. Modularne l'ALTEZZA — che era l'unica leva
## di prima, `grana` — su un disco alto due millimetri non si vede.
static func cupola_su(st: SurfaceTool, base: Transform3D, raggio: float,
		alt: float, segs := 10, anelli := 3, grana := 0.0,
		conca := 0.18, maschera := CUORE, lobi := 0, lobo := 0.0) -> void:
	var col := Color(maschera.r, maschera.g, maschera.b, 0.0)
	var g: Array = []
	for k in anelli + 1:
		var t := float(k) / float(anelli)
		var rho := raggio * t
		var riga: Array[Vector3] = []
		for j in segs:
			var a := TAU * float(j) / float(segs)
			var rr := rho
			if lobi > 0:
				# i lobi si aprono man mano che si va verso il bordo: al
				# centro la corolla è un tubo, fuori è una stella morbida
				rr *= 1.0 + lobo * cos(float(lobi) * a) * t
			# LA CONCA IN MEZZO. Il profilo è una calotta (la radice), e
			# `conca` le scava il centro: in un capolino vero i flosculi
			# di mezzo non sono ancora aperti e il disco è più basso lì.
			# Senza, è un pulsante — ed è quello che c'era.
			var incavo := maxf(0.0, 1.0 - t * 1.6)
			var y := alt * (1.0 - conca * incavo * incavo) \
					* sqrt(maxf(0.0, 1.0 - t * t * 0.86))
			if grana > 0.0:
				y += grana * alt * sin(float(segs) * 0.5 * a) * t
			riga.append(Vector3(cos(a) * rr, y, sin(a) * rr))
		g.append(riga)
	var nrm := anello_normali(g, segs)
	for k in g.size() - 1:
		for j in segs:
			var j2 := (j + 1) % segs
			for idx: Array in [[k, j], [k + 1, j], [k + 1, j2],
					[k, j], [k + 1, j2], [k, j2]]:
				st.set_color(col)
				st.set_normal(base.basis * (nrm[idx[0]][idx[1]] as Vector3))
				st.add_vertex(base * (g[idx[0]][idx[1]] as Vector3))


## Le normali di una griglia ad ANELLI CHIUSI: tangente lungo l'anello ×
## tangente lungo la colonna. È la stessa legge di `WorldGeo.grid_normals`,
## riscritta qui perché FioriGeo non dipende da nessuno — è la casa degli
## organi, e una casa non chiama i suoi inquilini.
static func anello_normali(pos: Array, segs: int) -> Array:
	var rows: int = pos.size()
	var out: Array = []
	for i in rows:
		var nrow: Array[Vector3] = []
		var sotto: Array = pos[maxi(i - 1, 0)]
		var sopra: Array = pos[mini(i + 1, rows - 1)]
		for j in segs:
			var t_lon: Vector3 = (pos[i][(j + 1) % segs] as Vector3) \
					- (pos[i][(j - 1 + segs) % segs] as Vector3)
			var t_lat: Vector3 = (sopra[j] as Vector3) - (sotto[j] as Vector3)
			var n := t_lon.cross(t_lat)
			if n.length_squared() < 1e-12:
				nrow.append(Vector3.UP)
				continue
			nrow.append(n.normalized())
		out.append(nrow)
	return out


## LA CAMPANELLA della lavanda e dei fiorellini a tubo: un calice che si
## apre in cima con quattro lobi. Otto triangoli, e non è una pallina —
## una spiga di palline è una pannocchia.
static func campanella_su(st: SurfaceTool, base: Transform3D, lung: float,
		largo: float, maschera := PETALO, fase := 0.0) -> void:
	var col := Color(maschera.r, maschera.g, maschera.b, fase)
	var lati := 4
	var g: Array = []
	# tre anelli: attacco stretto, pancia, e la bocca svasata
	for k in 3:
		var t := float(k) / 2.0
		# ⚠️ tipizzati a mano: `var r := lista[k]` non compila, l'inferenza
		# non sa che tipo esce da un array letterale
		var profilo: Array[float] = [0.28, 0.86, 1.0]
		var quota: Array[float] = [0.0, 0.55, 1.0]
		var r: float = largo * profilo[k]
		var y: float = lung * quota[k]
		var riga: Array[Vector3] = []
		for j in lati:
			var a := TAU * float(j) / float(lati) + 0.4
			# i lobi della bocca: la corolla si apre a stella, non a tubo
			var rr: float = r * (1.0 + (0.35 if k == 2 else 0.0))
			riga.append(Vector3(cos(a) * rr, y, sin(a) * rr))
		g.append(riga)
	var nrm := anello_normali(g, lati)
	for k in 2:
		for j in lati:
			var j2 := (j + 1) % lati
			for idx: Array in [[k, j], [k + 1, j], [k + 1, j2],
					[k, j], [k + 1, j2], [k, j2]]:
				st.set_color(col)
				st.set_normal(base.basis * (nrm[idx[0]][idx[1]] as Vector3))
				st.add_vertex(base * (g[idx[0]][idx[1]] as Vector3))
