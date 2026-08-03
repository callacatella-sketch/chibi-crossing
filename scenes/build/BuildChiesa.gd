class_name BuildChiesa
extends RefCounted

## LA CHIESA DEL PAESE — i pezzi con cui il giocatore la tira su.
##
## Non una cattedrale: la chiesa di un paese di due strade, alta quanto due
## chibi uno sull'altro. Non ha un credo — questo mondo non ne ha — ma ha le
## soglie: la campana che chiama tutti in piazza, il lume che si accende per
## chi e partito per il Grande Prato, la conca d'acqua dove si scrive il nome
## di chi e appena nato. E l'unica stanza del villaggio che non chiede niente:
## non da bonus, non tiene il conto di chi non e venuto, e chi entra ci sta e
## basta.
##
## DA LONTANO la comprano tre cose sole: il campanile (l'unica verticale del
## paese), il frontone che sale oltre la linea dei tetti col rosone acceso, e
## l'abside tondo — che da tre quarti smaschera qualunque capannone. DA VICINO
## la comprano il ritmo delle vetrate tutte uguali e l'asse portale-navata-
## altare: e l'unico asse simmetrico di tutto il villaggio, e qui la storta
## cozy che altrove da vita ucciderebbe la lettura.
##
## NIENTE CROCE: in cima al campanile una banderuola a rondine, e nel rosone
## un cuore di vetro rosso. Il congedo, in questo gioco, non e mai morte.
##
## Vive in un file suo — come la palestra — perche il catalogo e gia lungo e
## ci lavorano in tanti: primitive e colori di casa restano in BuildCatalog
## (`CAT.`), qui ci sono solo le forme della chiesa.

const CAT := preload("res://scenes/build/BuildCatalog.gd")
## I tubi spazzati lungo una curva: servono ai costoloni della volta.
const BUILDER := preload("res://scenes/npc/ChibiBuilder.gd")


# ------------------------------------------------------------ i vetri
# La tavolozza delle vetrate sta QUI e solo qui: la usano Vetrata, Portale,
# Frontone, Abside e la lampada della Volta. Cinque liste di colori copiate
# in cinque pezzi divergerebbero entro due sessioni — e una chiesa con due
# rossi diversi nelle finestre non e una chiesa, e un errore.

const VETRO_RUBINO := Color("c4485a")
const VETRO_COBALTO := Color("4a6bb0")
const VETRO_AMBRA := Color("e2a44e")
const VETRO_SMERALDO := Color("5aa377")
const VETRO_VIOLA := Color("8a6bb0")
const VETRO_LATTE := Color("f2e8d8")

const FERRO := Color("3d3a36")            # i piombi e le ferramenta


# ------------------------------------------------------- gli helper condivisi

## L'ARCO A TUTTO SESTO in conci: il pezzo di matematica piu riusato del set
## (portale, arcata, vetrata, campanile, nicchie).
##
## Il concio i-esimo sta a theta = PI * (i + 0.5) / conci sulla semicirconferenza
## di raggio medio R. La sua lunghezza deve stare sulla TANGENTE, che nel punto
## theta punta in direzione (-sin theta, cos theta), cioe a PI/2 + theta: col
## segno sbagliato (PI/2 - theta) alla chiave non si vede niente — una scatola
## e simmetrica — ma scendendo verso i reni ogni concio si gira dalla parte
## opposta e l'arco si sbriciola in una manciata di sassi per aria. E successo,
## e il test non se n'era accorto perche guardava solo le posizioni.
##
## La CORDA si prende al raggio ESTERNO e maggiorata di un filo: presa al raggio
## interno lascia all'estradosso spifferi di sfondo fra un concio e l'altro, ed
## e il difetto che fa sembrare l'arco tratteggiato.
static func arco_conci(parent: Node3D, mat: Material, mat_chiave: Material,
		r_int: float, spessore: float, prof: float, conci: int,
		pos: Vector3) -> Node3D:
	var arco := Node3D.new()
	arco.position = pos
	parent.add_child(arco)
	var raggio := r_int + spessore * 0.5
	var corda := 2.0 * (r_int + spessore) * sin(PI / (2.0 * conci)) * 1.04
	var chiave := conci / 2
	for i in conci:
		var theta := PI * (float(i) + 0.5) / float(conci)
		var in_chiave := (conci % 2 == 1 and i == chiave)
		var alto := corda * (1.08 if in_chiave else 1.0)
		var c := CAT._box(arco, Vector3(alto, spessore, prof),
				mat_chiave if in_chiave else mat,
				Vector3(cos(theta) * raggio, sin(theta) * raggio, 0))
		c.rotation.z = PI * 0.5 + theta
	return arco


## L'arco come NASTRO invece che come fila di conci: una nervatura sola,
## spazzata lungo la semicirconferenza. E la ragione per cui la volta costa
## venticinque nodi invece di centoventi.
##
## La curva sta tutta nel piano XY, quindi schiacciare Z sul MeshInstance
## schiaccia SOLO la sezione del tubo (che diventa ovale), non l'arco.
static func arco_nastro(parent: Node3D, mat: Material, r: float,
		sezione: float, appiattimento: float, pos: Vector3,
		giro := 0.0) -> MeshInstance3D:
	var punti := []
	var raggi := []
	for i in 7:
		var t := float(i) / 6.0
		var theta := PI * t
		punti.append(Vector3(cos(theta) * r, sin(theta) * r, 0.0))
		# la nervatura si assottiglia salendo: in chiave porta meno peso
		raggi.append(sezione * (1.0 - 0.22 * sin(theta)))
	var mi := BUILDER.tube(parent, punti, raggi, mat, 24, 8)
	mi.position = pos
	mi.scale.z = appiattimento
	mi.rotation.y = giro
	return mi


## IL VENTAGLIO RADIALE del rosone: petali di vetro schiacciati sul cerchio,
## le bacchette di piombo fra l'uno e l'altro, i due anelli e il bottone.
##
## Niente spicchi triangolari veri: con box e cilindri lasciano sempre un
## vuoto o al centro o al bordo. E tre quote separate (fondo, petali, raggi)
## o e z-fighting.
static func rosa(parent: Node3D, petali: int, r: float, mat_vetri: Array,
		mat_pietra: Material, mat_cuore: Material, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	var quanti := clampi(petali, 6, 16)
	# IL VERSO CONTA: il rosone cresce verso -Z, cioe verso il FRONTE del
	# pezzo (tutto il catalogo guarda -Z). Costruito verso +Z finisce dentro
	# il muro che lo ospita e si vede solo il filo dell'anello: e successo, e
	# dal davanti sembrava una finestra murata.
	for i in quanti:
		var a := float(i) * TAU / float(quanti)
		var mat: Material = mat_vetri[i % mat_vetri.size()]
		var p := CAT._ball(n, r * 0.42, mat,
				Vector3(cos(a) * r * 0.56, sin(a) * r * 0.56, -0.014),
				Vector3(1.0, 1.0, 0.15))
		p.rotation.z = a
	for i in quanti:
		var a := float(i) * TAU / float(quanti) + PI / float(quanti)
		var b := CAT._box(n, Vector3(r * 0.92, r * 0.055, 0.016), mat_pietra,
				Vector3(cos(a) * r * 0.48, sin(a) * r * 0.48, -0.026))
		b.rotation.z = a
	for raggio: float in [r * 0.99, r * 0.3]:
		var anello := TorusMesh.new()
		anello.inner_radius = raggio - r * 0.06
		anello.outer_radius = raggio
		var mi := MeshInstance3D.new()
		mi.mesh = anello
		mi.material_override = mat_pietra
		mi.position = Vector3(0, 0, -0.026)
		# l'anello di TorusMesh sta nel piano XZ: senza questa rotazione lo
		# si vede DI TAGLIO, cioe non lo si vede
		mi.rotation.x = PI * 0.5
		mi.scale.y = 0.5
		n.add_child(mi)
	CAT._ball(n, r * 0.2, mat_cuore, Vector3(0, 0, -0.032), Vector3(1, 1, 0.4))
	return n


## Un cilindro col numero di lati che dici tu: l'_cyl di casa non lo espone e
## resta a sessantaquattro. Con top=0 e quattro lati e il tetto piramidale del
## campanile, con otto il coperchio della fonte, con dodici il tamburo
## dell'abside. Un cono liscio a sessantaquattro lati e un cappello da strega:
## gli spigoli sono tutta la differenza.
static func cono_lati(parent: Node3D, top: float, bottom: float, h: float,
		lati: int, mat: Material, pos: Vector3) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = maxi(3, lati)
	m.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


## Un vetro colorato. La banda di sicurezza sta DENTRO l'helper: energia fra
## 0.4 e 1.0 e albedo mai schiarito. E la lezione gia pagata dal faro della
## caserma — emissione alta su un colore chiaro e il vetro sbianca, e una
## vetrata diventa una fila di lampadine.
static func vetro(colore: Color, energia := 0.7) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colore
	m.emission_enabled = true
	m.emission = colore
	m.emission_energy_multiplier = clampf(energia, 0.4, 1.0)
	# un vetro e vetro: di sera si accende, di giorno lo attraversa la luce
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color.a = 0.92
	return m


## Le bacchette di piombo che tengono i vetri. Sono LORO il disegno di una
## vetrata: senza, resta una tovaglia a quadretti.
static func piombo() -> ShaderMaterial:
	return CAT._mat(FERRO, FERRO.darkened(0.3), 7.0, 0.25)


## Una fiamma di candela, dentro un nodo suo cosi qualcuno puo farla respirare.
## La luce vera non sta qui: e emissione e basta, perche di questi pezzi il
## giocatore ne piazza tanti.
static func fiamma(parent: Node3D, pos: Vector3, scala := 1.0) -> Node3D:
	var n := Node3D.new()
	n.name = "Fiamma"
	n.position = pos
	n.scale = Vector3.ONE * scala
	parent.add_child(n)
	CAT._ball(n, 0.022, CAT._glow(Color("ffcf7a"), Color("ffb54a"), 1.4),
			Vector3(0, 0.022, 0), Vector3(0.72, 1.55, 0.72))
	CAT._ball(n, 0.011, CAT._glow(Color("fff4d2"), Color("fff0c0"), 1.6),
			Vector3(0, 0.018, 0), Vector3(0.7, 1.35, 0.7))
	return n


# ==========================================================================
# IL MURO, IL BANCO, L'ARCATA, L'ABSIDE, LA FONTE
# ==========================================================================

# ============================================== LA PIETRA E IL LEGNO
# Il muro, il banco, l'arcata, l'abside e la fonte: la parte della chiesa
# che si tocca con le mani. Il vetro e la fiamma li fanno gli altri; qui
# c'è quello che sta in piedi da solo e che il tempo ha già consumato.
#
# I colori nuovi sono pochi di proposito: pietra, intonaco, terracotta e
# legno stanno già nella tavolozza di casa (CAT.*) e da lì si prendono —
# una chiesa fatta con colori tutti suoi si stacca dal villaggio, e questa
# chiesa deve sembrare tirata su dagli stessi vicini che hanno fatto le case.

const PIETRA_CONCIO := Color("c4bba7")        # il concio d'accento: un tono sotto STONE
const PIETRA_CONCIO_CALDO := Color("d2c1a4")  # l'altra cava: la pietra non viene mai da una sola
const PIETRA_LUCIDA := Color("ded6c4")        # la pietra levigata: cornici, abachi, il bordo della fonte
const PIETRA_GIUNTO := Color("8d8579")        # la malta fra i conci — e, più cupa, la crepa
const PIETRA_MUSCHIO := Color("8ea36f")       # il lichene che sale dallo zoccolo
const PIETRA_NOTTE := Color("2b3a63")         # il cielo dipinto nel catino dell'abside
const PIETRA_NOTTE_CUPA := Color("1b2545")
const PIETRA_STELLA := Color("fff7e0")        # le stelle: la stessa luce crema delle costellazioni di Mochi
const LEGNO_BANCO := Color("b07a4a")
const LEGNO_BANCO_SCURO := Color("8a5a34")
const LEGNO_CONSUMO := Color("dcb684")        # dove il legno è lucidato dall'uso SCHIARISCE, non si scurisce
const LEGNO_INCHIOSTRO := Color("6a4a3a")     # i tratti sul registro, il seppia di chi scrive a penna

# La geometria dell'abside vive in const perché la usano in tre (il tamburo,
# il tetto, il catino) e un mezzo tamburo con tre raggi diversi non è più
# un mezzo tamburo.
const ABSIDE_R := 0.41          # raggio medio del muro curvo
const ABSIDE_SPESS := 0.15
const ABSIDE_FACCE := 7         # mezzo poligono di 14 lati (vedi abside())
const ABSIDE_CENTRO := Vector3(0, 0, 0.06)


# ------------------------------------------------ il muro di pietra

## IL MURO DI PIETRA. Il pezzo che si piazza quaranta volte e che da solo
## trasforma quattro muri qualunque in una chiesa: stessa sagoma del Muro
## di casa (zoccolo in basso, cornice in alto alla STESSA quota, 2.04), ma
## la faccia è muratura vera invece che intonaco.
##
## Tutto il carattere sta in due cose: i corsi sfalsati — il giunto
## verticale non cade MAI su quello del corso di sotto — e il fatto che le
## pietre d'accento sono PASSANTI: un solo box che attraversa il muro e
## sporge da tutt'e due le facce, come il "diatono" che il muratore mette
## ogni tanto per legare i due paramenti. Costa la metà dei nodi di due
## facce separate, e dentro la chiesa si vede la stessa pietra di fuori.
static func muro_pietra() -> Node3D:
	var n := Node3D.new()
	var lastra := CAT._mat(CAT.STONE, CAT.STONE_DARK, 2.6, 0.5)
	var zoccolo := CAT._mat(CAT.STONE_DARK, Color("8f8779"), 3.2, 0.55)
	var cornice := CAT._mat(PIETRA_LUCIDA, CAT.STONE, 3.0, 0.4)

	# la lastra: 2.0 netti come il Muro di casa, ma 16 mm di spessore
	# invece di 14 — la pietra si sente anche nella soglia della porta
	CAT._box(n, Vector3(1.0, 2.0, 0.16), lastra, Vector3(0, 1.0, 0))

	# LO ZOCCOLO. Sporge fino a 0.25 e scende scuro: è la parte che prende
	# gli schizzi di pioggia, e in ogni edificio vero è più grossa e più
	# sporca del resto. Sopra, lo scivolo che butta via l'acqua.
	CAT._box(n, Vector3(1.0, 0.2, 0.25), zoccolo, Vector3(0, 0.1, 0))
	CAT._box(n, Vector3(1.0, 0.055, 0.215), zoccolo, Vector3(0, 0.222, 0))

	# IL MARCAPIANO A 1.45. La stessa quota del Campanile e dell'Abside:
	# è la riga orizzontale che tiene insieme pezzi costruiti da mani
	# diverse. Se qualcuno la sposta di dieci centimetri, l'edificio si
	# slega e torna a essere una fila di pezzi affiancati.
	CAT._box(n, Vector3(1.0, 0.06, 0.23), cornice, Vector3(0, 1.45, 0))
	CAT._box(n, Vector3(1.0, 0.03, 0.195), cornice, Vector3(0, 1.497, 0))

	# la cornice alta: 1.99 → 2.08, esattamente come quella del Muro di
	# casa, così un muro di pietra e uno d'intonaco in fila si allineano
	CAT._box(n, Vector3(1.0, 0.035, 0.2), cornice, Vector3(0, 1.972, 0))
	CAT._box(n, Vector3(1.0, 0.09, 0.235), cornice, Vector3(0, 2.035, 0))

	_muro_conci(n)
	_muro_eta(n)
	return n


## I conci d'accento, corso per corso.
##
## MAI randf() NUDO QUI DENTRO: il fantasma sotto il cursore viene
## ricostruito da _refresh_ghost() a ogni movimento del mouse, e un muro
## che si rimescola mentre lo trascini scintilla come uno schermo rotto.
## Seme fisso, come i libri della Libreria: questo muro è SEMPRE questo
## muro, e quaranta copie in fila restano la stessa muratura.
static func _muro_conci(n: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1445
	var chiaro := CAT._mat(PIETRA_CONCIO, CAT.STONE_DARK, 3.6, 0.5)
	var caldo := CAT._mat(PIETRA_CONCIO_CALDO, PIETRA_CONCIO, 3.2, 0.45)

	# i corsi sono orizzontali per definizione — quello che cambia da corso
	# a corso è DOVE cadono i giunti verticali. Cinque sotto il marcapiano,
	# due sopra: la fascia alta è più stretta e va tenuta più povera.
	var corsi := [0.36, 0.58, 0.80, 1.02, 1.24, 1.63, 1.85]
	# TRE larghezze e non una: con un formato solo la faccia diventa una
	# scacchiera, e una scacchiera è piastrellatura, non muratura.
	var larghezze := [0.33, 0.225, 0.15]
	for i in corsi.size():
		var y: float = corsi[i]
		# lo sfalsamento a corsi alterni: la prima regola di chi alza un
		# muro a mano è che due giunti non si incolonnano mai
		var x := -0.44 + (0.0 if i % 2 == 0 else 0.13) + rng.randf_range(0.0, 0.07)
		for j in 1 + (i % 2):
			var w: float = larghezze[rng.randi() % 3]
			if x + w > 0.46:
				break
			# la sporgenza: sopra i 2 cm il concio esce dalla cella e si
			# morde con il pezzo del bordo accanto
			var sp := rng.randf_range(0.012, 0.018)
			var c := CAT._box(n, Vector3(w, 0.175, 0.16 + sp * 2.0),
					caldo if rng.randf() < 0.38 else chiaro,
					Vector3(x + w * 0.5, y, 0))
			# l'assestamento: nessuna pietra posata a mano resta in bolla,
			# e sono questi due gradi a dire che il muro è vecchio
			c.rotation.z = rng.randf_range(-0.014, 0.014)
			x += w + rng.randf_range(0.09, 0.2)


## Gli anni addosso: il lichene, il segno dello scalpellino, la crepa.
## Sono tre dettagli su ventiquattro nodi, e sono tutta la differenza fra
## «un muro di pietra» e «un muro che c'era già quando sono arrivati loro».
static func _muro_eta(n: Node3D) -> void:
	var muschio := CAT._mat(PIETRA_MUSCHIO, CAT.LEAF_DARK, 7.0, 0.55)
	var giunto := CAT._mat(PIETRA_GIUNTO, PIETRA_GIUNTO.darkened(0.2), 5.0, 0.35)
	var crepa := CAT._mat(PIETRA_GIUNTO.darkened(0.45), Color("4a443c"), 6.0, 0.3)

	# il lichene sale dallo zoccolo, dove l'acqua resta: cuscinetti
	# schiacciati contro la pietra, mai bolle appiccicate sopra
	CAT._ball(n, 0.09, muschio, Vector3(-0.3, 0.06, -0.125), Vector3(1.3, 0.42, 0.22))
	CAT._ball(n, 0.055, muschio, Vector3(-0.13, 0.13, -0.126), Vector3(1.0, 0.5, 0.2))
	CAT._ball(n, 0.07, muschio, Vector3(0.34, 0.05, 0.126), Vector3(1.2, 0.4, 0.2))

	# IL SEGNO DELLO SCALPELLINO: due tacche a V su un concio solo. Chi
	# tagliava la pietra firmava il pezzo per farsi pagare a cottimo; qui
	# è la prova che questo muro l'ha fatto qualcuno con un nome.
	# Sta nella fascia LIBERA fra due corsi (0.4475 → 0.4925) e a filo
	# della lastra: appoggiato su un concio d'accento resterebbe per aria
	# il giorno che il seme sposta quella pietra di dieci centimetri.
	for verso: float in [-1.0, 1.0]:
		var tacca := CAT._box(n, Vector3(0.007, 0.04, 0.006), giunto,
				Vector3(-0.2 + verso * 0.012, 0.47, -0.0825))
		tacca.rotation.z = verso * 0.5

	# LA CREPA. Due segmenti con inclinazioni diverse che si incontrano su
	# un giunto: una crepa dritta è un graffio, una crepa che cambia
	# direzione dove trova la malta è una crepa.
	var c1 := CAT._box(n, Vector3(0.009, 0.36, 0.005), crepa, Vector3(0.16, 1.12, -0.0815))
	c1.rotation.z = 0.17
	var c2 := CAT._box(n, Vector3(0.007, 0.26, 0.005), crepa, Vector3(0.09, 0.86, -0.0815))
	c2.rotation.z = -0.1


# ------------------------------------------------------- il banco

## IL BANCO. Una panca sola per cella, lunga 0.9: è il passo vero di una
## navata, e due banchi in un metro non lasciano lo spazio per passare.
## Il corridoio centrale non lo disegna nessuno — nasce dalle celle che il
## giocatore lascia vuote, ed è per questo che è sempre al posto giusto.
##
## La differenza dalla Panchina già in catalogo, quella che lo salva dal
## doppione, è una sola e sta nella silhouette: una panchina ha le GAMBE,
## un banco ha i FIANCHI. Due assi piene fino a terra, e i piedi di chi si
## siede spariscono dietro.
static func banco() -> Node3D:
	var n := Node3D.new()
	var legno := CAT._mat(LEGNO_BANCO, LEGNO_BANCO_SCURO, 3.6, 0.5)
	var scuro := CAT._mat(LEGNO_BANCO_SCURO, Color("6b431f"), 4.2, 0.45)
	var lucido := CAT._mat(LEGNO_CONSUMO, LEGNO_BANCO, 2.4, 0.32)

	# le due fiancate. Quella di destra ha il piede più corto: il pavimento
	# di una chiesa di paese non è mai in piano, e c'è sempre un banco che
	# balla finché qualcuno non ci infila sotto un pezzo di cartone.
	for sx: float in [-1.0, 1.0]:
		var fianco := Node3D.new()
		fianco.position = Vector3(sx * 0.42, 0, 0)
		n.add_child(fianco)
		_banco_fiancata(fianco, legno, scuro, sx, sx > 0.0)
	CAT._box(n, Vector3(0.1, 0.007, 0.16),
			CAT._mat(CAT.CREAM, Color("d9c9a8"), 6.0, 0.3),
			Vector3(0.42, 0.0035, -0.05))

	# LA SEDUTA, a 0.42 come la Panchina — chi si siede qui e chi si siede
	# là deve stare alla stessa altezza, o il villaggio traballa
	CAT._box(n, Vector3(0.84, 0.045, 0.3), legno, Vector3(0, 0.42, -0.005))
	var bordo := CAT._cyl(n, 0.024, 0.024, 0.84, legno, Vector3(0, 0.418, -0.153))
	bordo.rotation.z = PI * 0.5
	# LE DUE CONCHE. Non due buchi scuri: un incavo dipinto di scuro legge
	# come sporco, non come usura. Il legno consumato SCHIARISCE e si
	# lucida — due lenti pallide, appena in rilievo, nei due punti dove si
	# siedono sempre gli stessi due. Tutto il resto della seduta non ce
	# l'ha, ed è quello che le fa esistere.
	CAT._ball(n, 0.13, lucido, Vector3(-0.22, 0.4425, -0.01), Vector3(1.0, 0.06, 0.72))
	CAT._ball(n, 0.115, lucido, Vector3(0.19, 0.4425, 0.0), Vector3(1.0, 0.055, 0.7))
	# la traversa che tiene insieme i due fianchi, sotto la seduta
	CAT._box(n, Vector3(0.84, 0.05, 0.05), scuro, Vector3(0, 0.22, 0.1))

	# LO SCHIENALE, dritto ma non verticale: sette centesimi di radiante
	# all'indietro sono la differenza fra una seduta e una punizione
	var spalliera := CAT._box(n, Vector3(0.84, 0.3, 0.045), legno, Vector3(0, 0.63, 0.146))
	spalliera.rotation.x = 0.07
	var cresta := CAT._box(n, Vector3(0.86, 0.075, 0.06), legno, Vector3(0, 0.788, 0.157))
	cresta.rotation.x = 0.07
	# il bordo alto lucidato: è il legno che tocca la mano di chi entra nel
	# banco appoggiandosi allo schienale di quello davanti
	CAT._box(n, Vector3(0.66, 0.012, 0.03), lucido, Vector3(0, 0.826, 0.163))

	_banco_mensola(n, legno, scuro)
	_banco_inginocchiatoio(n, legno)

	# IL POSTO: dove ci si mette e da che parte si guarda. Guarda -Z come
	# tutto il catalogo, cioè verso l'altare: è l'unico verso che ha senso
	# in una navata, e ricavarlo dopo a occhio dai numeri del builder è il
	# modo sicuro di far sedere qualcuno di spalle.
	var posto := Node3D.new()
	posto.name = "posto"
	posto.position = Vector3(0, 0.33, 0.02)
	n.add_child(posto)
	return n


## Una fiancata: l'asse piena sagomata a profilo che fa il banco.
## `verso` è il lato (-1 sinistra, +1 destra) e serve per mettere il
## rosone intagliato sulla faccia ESTERNA, l'unica che si vede.
static func _banco_fiancata(f: Node3D, legno: Material, scuro: Material,
		verso: float, zeppa: bool) -> void:
	# l'asse principale, da terra alla cimasa
	CAT._box(f, Vector3(0.05, 0.84, 0.255), legno, Vector3(0, 0.42, 0.043))
	# la parte davanti, più bassa: è il taglio che dà il PROFILO — un'asse
	# rettangolare da terra al soffitto è una porta, non una fiancata
	CAT._box(f, Vector3(0.05, 0.75, 0.09), legno, Vector3(0, 0.375, -0.13))
	# la testa tonda sull'angolo davanti: quello è lo spigolo che sfiora
	# ogni singola persona che entra nel banco, e negli anni si arrotonda
	var testa := CAT._cyl(f, 0.085, 0.085, 0.05, legno, Vector3(0, 0.755, -0.085))
	testa.rotation.z = PI * 0.5
	# l'orecchia bassa che porta l'inginocchiatoio
	CAT._box(f, Vector3(0.05, 0.3, 0.15), legno, Vector3(0, 0.15, -0.225))
	# il rosone intagliato sulla faccia esterna: una borchia sola, piatta.
	# È la firma del falegname del villaggio, la stessa su tutti i banchi.
	# (schiacciato in X: è la faccia del fianco a guardare di lato, e una
	# borchia appiattita sull'asse sbagliato resta una mezza palla che
	# sporge cinque centimetri dal banco)
	CAT._ball(f, 0.052, scuro, Vector3(verso * 0.03, 0.56, 0.02), Vector3(0.22, 1.0, 1.0))
	# IL PIEDE. Allarga l'appoggio (un'asse di 5 cm in piedi si ribalta) e,
	# su un fianco solo, è più corto di 7 mm: è quello che chiede la zeppa.
	var h := 0.038 if zeppa else 0.045
	CAT._box(f, Vector3(0.09, h, 0.46), scuro, Vector3(0, (0.007 if zeppa else 0.0) + h * 0.5, -0.05))


## La mensolina dietro lo schienale, coi due libretti.
## Sta DIETRO perché non serve a chi è seduto qui: serve a quelli del
## banco di dietro. È il dettaglio che dice che questa fila non è sola.
static func _banco_mensola(n: Node3D, legno: Material, scuro: Material) -> void:
	CAT._box(n, Vector3(0.82, 0.028, 0.11), legno, Vector3(0, 0.715, 0.238))
	CAT._box(n, Vector3(0.82, 0.03, 0.018), scuro, Vector3(0, 0.736, 0.288))
	# due libretti impilati storti: nessuno rimette a posto un libretto
	var a := CAT._box(n, Vector3(0.125, 0.028, 0.088),
			CAT._mat(Color("9a5f5a"), Color("7c4844"), 6.0, 0.4),
			Vector3(-0.17, 0.743, 0.236))
	a.rotation.y = 0.13
	var b := CAT._box(n, Vector3(0.11, 0.024, 0.08),
			CAT._mat(Color("5f7a72"), Color("47615a"), 6.0, 0.4),
			Vector3(-0.155, 0.769, 0.243))
	b.rotation.y = -0.22
	# il taglio delle pagine, crema, che sporge dalla copertina di sopra
	var pag := CAT._box(n, Vector3(0.1, 0.014, 0.072),
			CAT._mat(CAT.CREAM, Color("efe0c4"), 7.0, 0.25),
			Vector3(-0.16, 0.769, 0.239))
	pag.rotation.y = -0.22


## L'inginocchiatoio: l'asse bassa davanti e il cuscinetto di stoffa
## consumato in mezzo — consumato IN MEZZO, non da un capo all'altro,
## perché si inginocchia sempre chi sta al centro del banco.
static func _banco_inginocchiatoio(n: Node3D, legno: Material) -> void:
	CAT._box(n, Vector3(0.86, 0.05, 0.15), legno, Vector3(0, 0.1, -0.225))
	var stoffa := CAT._mat(Color("b9846a"), Color("9a6b53"), 6.0, 0.45)
	CAT._box(n, Vector3(0.52, 0.022, 0.105), stoffa, Vector3(0, 0.134, -0.225))
	CAT._ball(n, 0.075, stoffa, Vector3(-0.03, 0.138, -0.225), Vector3(1.6, 0.16, 0.62))


# ------------------------------------------------------ l'arcata

## L'ARCATA. Il pezzo che dà PROFONDITÀ a un interno: due o tre in fila e
## una stanza da tre metri diventa una navata. Sotto ci si passa — la luce
## netta è 0.6 e le collisioni stanno solo sulle due colonne.
##
## L'arco è a tutto sesto di 11 conci: sotto i 9 il profilo esterno
## diventa un poligono spigoloso che si smaschera appena lo guardi di
## profilo. La corda dei conci la calcola arco_conci al raggio ESTERNO —
## presa a quello interno lascia spifferi di sfondo all'estradosso, ed è
## il difetto che fa sembrare l'arco tratteggiato.
static func arcata() -> Node3D:
	var n := Node3D.new()
	var pietra := CAT._mat(CAT.STONE, CAT.STONE_DARK, 2.8, 0.5)
	var chiara := CAT._mat(PIETRA_LUCIDA, CAT.STONE, 3.0, 0.42)

	for sx: float in [-1.0, 1.0]:
		_arcata_colonna(n, sx * 0.4, pietra, chiara, sx)

	# L'ARCO. Nasce a 1.90, dove finisce l'abaco. r interno 0.30 → luce
	# netta 0.60 tonda, e spessore 0.20: il RAGGIO ESTERNO è 0.50, cioè
	# mezza cella esatta. Non è un'eleganza, è una condizione: con 0.64 di
	# estradosso (0.34 + 0.30) l'arco usciva di quattordici centimetri per
	# parte e due arcate in fila si mordevano i conci d'imposta. Così
	# invece l'estradosso al piano d'imposta cade ESATTAMENTE sull'abaco
	# (0.30 → 0.50) e il colonnato si può stendere per tutta la navata.
	arco_conci(n, pietra, chiara, 0.3, 0.2, 0.28, 11, Vector3(0, 1.9, 0))

	# LA CORNICE, tre fasce dai 2.40 ai 2.60. È lei a fare di due arcate in
	# fila un colonnato invece di due archi che si guardano, e le tre fasce
	# (fascia liscia, gola, cimasa) sono quello che separa una cornice da
	# un'asse messa di piatto sopra un arco.
	CAT._box(n, Vector3(1.0, 0.09, 0.26), chiara, Vector3(0, 2.445, 0))
	CAT._box(n, Vector3(1.0, 0.055, 0.3), pietra, Vector3(0, 2.5175, 0))
	CAT._box(n, Vector3(1.0, 0.055, 0.34), chiara, Vector3(0, 2.5725, 0))

	# IL FIORONE SULLA CHIAVE. Quattro petali e un bottone, sul concio in
	# mezzo: è l'unico intaglio del pezzo e sta esattamente sull'asse.
	# Le chiavi di volta di paese hanno tutte qualcosa sopra, e quel
	# qualcosa è sempre piccolo e sempre sbilenco.
	var fiore := Node3D.new()
	fiore.position = Vector3(0, 2.3, -0.138)
	fiore.rotation.z = 0.09
	n.add_child(fiore)
	for k in 4:
		var a := float(k) * PI * 0.5
		CAT._ball(fiore, 0.036, chiara, Vector3(sin(a) * 0.034, cos(a) * 0.034, -0.006),
				Vector3(1.0, 1.0, 0.3))
	CAT._ball(fiore, 0.022, pietra, Vector3(0, 0, -0.009), Vector3(1.0, 1.0, 0.5))

	# il lichene alla base della colonna di sinistra (una sola: il muschio
	# cresce dove batte l'ombra, non a specchio) e una sbrecciatura
	# sull'abaco di destra, dove qualcuno ci ha sbattuto una scala
	CAT._ball(n, 0.075, CAT._mat(PIETRA_MUSCHIO, CAT.LEAF_DARK, 7.0, 0.55),
			Vector3(-0.4, 0.03, -0.135), Vector3(1.2, 0.4, 0.3))
	var sbrec := CAT._box(n, Vector3(0.06, 0.05, 0.06),
			CAT._mat(CAT.STONE_DARK, PIETRA_GIUNTO, 5.0, 0.45),
			Vector3(0.315, 1.878, -0.095))
	sbrec.rotation = Vector3(0.5, 0.4, 0.6)
	return n


## Una colonnina: plinto, base, fusto con l'entasi, capitello a dado,
## abaco. Due quote comandano tutto e non si toccano:
##
##  · la sommità sta a 1.90 tonda, ed è il piano d'imposta dell'arco;
##  · NIENTE esce dalla fascia larga 0.20 attorno all'asse della colonna
##    (0.30 → 0.50). È la stessa impronta dell'estradosso dell'arco al
##    piano d'imposta, e soprattutto è la condizione perché due arcate in
##    fila si possano piazzare: con l'abaco largo 0.30 gli abachi di due
##    celle vicine si compenetravano di dieci centimetri, e il colonnato
##    — che è tutto il motivo per cui questo pezzo esiste — diventava una
##    catasta di pietre.
static func _arcata_colonna(n: Node3D, x: float, pietra: Material,
		chiara: Material, verso: float) -> void:
	CAT._box(n, Vector3(0.2, 0.06, 0.2), pietra, Vector3(x, 0.03, 0))
	CAT._cyl(n, 0.085, 0.1, 0.075, pietra, Vector3(x, 0.0975, 0))
	CAT._cyl(n, 0.08, 0.085, 0.03, chiara, Vector3(x, 0.15, 0))

	# IL FUSTO CON L'ENTASI. Una colonna a pareti dritte legge come un
	# tubo: si gonfia di tre millimetri a un terzo dell'altezza e si
	# stringe salendo. Non si vede — si vede solo quando NON c'è. Un solo
	# lathe a 16 lati: il fusto è un pezzo di tornio, non una pila di
	# cilindri, e con 16 spigoli la luce ci gira attorno per gradini.
	CAT.BUILDER.lathe(n, [
		Vector2(0.078, 0.0), Vector2(0.081, 0.36), Vector2(0.079, 0.72),
		Vector2(0.074, 1.08), Vector2(0.068, 1.47),
	], pietra, Vector3(x, 0.165, 0), 16)
	CAT._cyl(n, 0.083, 0.074, 0.03, chiara, Vector3(x, 1.65, 0))

	# IL CAPITELLO A DADO: un tronco di piramide che porta il tondo del
	# fusto al quadrato dell'abaco. cono_lati a 4 lati ruotato di PI/4 —
	# lo stesso mestiere del tetto della Torretta. I due capitelli sono
	# girati di due centesimi diversi: gemelli, non fotocopie.
	var cap := cono_lati(n, 0.134, 0.1, 0.14, 4, pietra, Vector3(x, 1.735, 0))
	cap.rotation.y = PI * 0.25 + verso * 0.022
	CAT._box(n, Vector3(0.176, 0.05, 0.176), chiara, Vector3(x, 1.83, 0))
	CAT._box(n, Vector3(0.2, 0.04, 0.2), pietra, Vector3(x, 1.878, 0))


# ------------------------------------------------------ l'abside

## L'ABSIDE. Il pezzo che salva il set dalla vista di tre quarti: di
## fianco, una navata rettangolare è un fienile, mentre un'abside tonda
## col suo tettuccio a mezzo cono è soltanto e solamente una chiesa.
##
## Il tamburo è mezzo poligono di quattordici lati, cioè SETTE facce. Non
## dodici (sei mezze) come il resto del set: con un numero pari di facce
## il giunto verticale cade in mezzo, sull'asse — e l'asse portale-navata-
## altare è l'unica simmetria di tutto il villaggio, quella che qui non si
## tocca. Sette facce mettono una faccia intera sull'asse, e la feritoia
## di mezzo ci sta dentro.
##
## Il lato +Z resta aperto verso la navata: le collisioni sono a U, così
## l'Altare ci sta dentro.
static func abside() -> Node3D:
	var n := Node3D.new()
	var intonaco := CAT._mat(CAT.PLASTER, CAT.PLASTER_SHADE, 2.8, 0.45)
	var pietra := CAT._mat(CAT.STONE, CAT.STONE_DARK, 3.0, 0.5)
	var chiara := CAT._mat(PIETRA_LUCIDA, CAT.STONE, 3.0, 0.42)
	var vetro_amb := vetro(VETRO_AMBRA, 0.55)

	# la corda maggiorata del 6%: presa esatta, due facce adiacenti
	# lasciano uno spiffero di sfondo sullo spigolo — lo stesso difetto
	# che fa sembrare tratteggiato un arco di conci
	var corda := 2.0 * ABSIDE_R * sin(PI / float(ABSIDE_FACCE * 2)) * 1.06

	for i in ABSIDE_FACCE:
		var b := -PI * 0.5 + PI * (float(i) + 0.5) / float(ABSIDE_FACCE)
		var dir := Vector3(sin(b), 0, -cos(b))
		# rotation.y = -b porta la faccia del box sul piano della faccia
		# del poligono; il suo +Z locale guarda il centro (serve dopo)
		var muro := CAT._box(n, Vector3(corda, 2.3, ABSIDE_SPESS), intonaco,
				ABSIDE_CENTRO + dir * ABSIDE_R + Vector3(0, 1.15, 0))
		muro.rotation.y = -b
		# LA SCARPA. Il tamburo si allarga scendendo di due centimetri e
		# mezzo: un cilindro a pareti dritte legge come un bidone, e la
		# scarpa è l'unica cosa che gli dà il peso di un edificio.
		muro.rotate_object_local(Vector3.RIGHT, 0.026)

		# lo zoccolo di pietra e il marcapiano a 1.45 — la stessa quota
		# del Muro di pietra e del Campanile: la riga che tiene insieme
		# l'edificio deve girare anche sul tondo, o l'abside sembra
		# appoggiata contro la chiesa invece che nata con lei
		var zoc := CAT._box(n, Vector3(corda * 1.04, 0.28, ABSIDE_SPESS + 0.07), pietra,
				ABSIDE_CENTRO + dir * (ABSIDE_R + 0.02) + Vector3(0, 0.14, 0))
		zoc.rotation.y = -b
		var marca := CAT._box(n, Vector3(corda * 1.02, 0.06, ABSIDE_SPESS + 0.06), chiara,
				ABSIDE_CENTRO + dir * (ABSIDE_R + 0.015) + Vector3(0, 1.45, 0))
		marca.rotation.y = -b

		# le tre feritoie: sulle facce 1, 3 e 5, cioè simmetriche attorno
		# a quella centrale. Tre e non cinque: una feritoia è una fessura
		# rara, se ce n'è una per faccia diventa un traforo.
		if i % 2 == 1:
			_abside_feritoia(n, b, dir, intonaco, pietra, vetro_amb)

	# i due risvolti che chiudono il tamburo dove si apre sulla navata:
	# senza, il muro curvo finisce nel vuoto e il pezzo legge come mezzo
	# tubo. Con, l'apertura ha due stipiti e diventa un arco trionfale.
	for sx: float in [-1.0, 1.0]:
		CAT._box(n, Vector3(0.16, 2.3, ABSIDE_SPESS + 0.02), intonaco,
				ABSIDE_CENTRO + Vector3(sx * ABSIDE_R, 1.15, 0.02))
		CAT._box(n, Vector3(0.19, 0.28, ABSIDE_SPESS + 0.09), pietra,
				ABSIDE_CENTRO + Vector3(sx * ABSIDE_R, 0.14, 0.02))

	_abside_tetto(n)
	_abside_catino(n)
	return n


## Una feritoia strombata: stretta fuori, larga dentro. Lo strombo non è
## un vezzo — è come si fa entrare luce in un muro spesso senza aprire un
## buco, ed è quello che trasforma un taglio nell'intonaco in una finestra
## di pietra. Il vetro attraversa tutto lo spessore: così di giorno
## illumina dentro e di sera si vede da fuori che la chiesa è accesa.
static func _abside_feritoia(n: Node3D, b: float, dir: Vector3,
		intonaco: Material, pietra: Material, vetro_amb: Material) -> void:
	var fer := Node3D.new()
	fer.position = ABSIDE_CENTRO + dir * ABSIDE_R + Vector3(0, 1.35, 0)
	fer.rotation.y = -b     # nel locale: +X tangente, +Z verso il centro
	n.add_child(fer)
	CAT._box(fer, Vector3(0.078, 0.44, ABSIDE_SPESS + 0.04), vetro_amb, Vector3.ZERO)
	# gli sguanci: divergono ANDANDO DENTRO (il +Z locale), e sono in
	# intonaco perché è la parete a smussarsi, non un telaio a stringersi
	for sx: float in [-1.0, 1.0]:
		var sg := CAT._box(fer, Vector3(0.05, 0.5, 0.17), intonaco,
				Vector3(sx * 0.105, 0.02, 0.105))
		sg.rotation.y = sx * 0.3
	# il davanzale in pendenza verso fuori: butta via l'acqua, e in
	# controluce è la riga che dice da che parte è il fuori
	var dav := CAT._box(fer, Vector3(0.21, 0.045, 0.22), pietra, Vector3(0, -0.25, 0.02))
	dav.rotation.x = -0.16


## Il mezzo cono di coppi. Tenuto BASSO di proposito: è la falda più bassa
## di tutta la chiesa, e questo — non la forma — è quello che fa leggere
## l'abside come un'aggiunta cresciuta addosso alla navata invece che come
## un bitorzolo. Le sette falde ripetono le sette facce, così i colmi
## cadono sugli spigoli del tamburo come nei tetti veri.
static func _abside_tetto(n: Node3D) -> void:
	var coppi := CAT._mat(CAT.TERRACOTTA, Color("c07a58"), 3.2, 0.5)
	var coppi_b := CAT._mat(Color("cf8163"), Color("b06a4e"), 3.6, 0.5)
	for i in ABSIDE_FACCE:
		var b := -PI * 0.5 + PI * (float(i) + 0.5) / float(ABSIDE_FACCE)
		var dir := Vector3(sin(b), 0, -cos(b))
		var falda := CAT._box(n, Vector3(0.25, 0.055, 0.6),
				coppi if i % 2 == 0 else coppi_b,
				ABSIDE_CENTRO + dir * 0.25 + Vector3(0, 2.465, 0))
		falda.rotation.y = -b
		# il -Z locale è il fuori: va giù, o il tetto si apre a imbuto
		falda.rotate_object_local(Vector3.RIGHT, -0.494)
	# il comignolino di terracotta che copre il nodo delle sette punte
	CAT._cyl(n, 0.05, 0.085, 0.09, coppi, ABSIDE_CENTRO + Vector3(0, 2.63, 0))
	CAT._ball(n, 0.055, coppi_b, ABSIDE_CENTRO + Vector3(0, 2.7, 0), Vector3(1, 0.8, 1))


## IL MEZZO GIRO. Una rivoluzione INTERA dentro un tamburo che è mezzo
## poligono lascia fuori mezza cupola, appesa sopra il vuoto della navata.
## Qui il profilo (raggio, altezza) gira solo da +X a -X passando per -Z:
## esattamente il mezzo giro che il muro copre. Niente tappo sotto — il
## bordo muore contro la faccia interna del tamburo, e una cupola si guarda
## da dentro: un fondo piatto la chiuderebbe proprio davanti alle stelle.
static func _mezza_rivoluzione(parent: Node3D, profilo: Array, mat: Material,
		pos: Vector3, spicchi: int) -> MeshInstance3D:
	var pr: Array[Vector2] = []
	for p in profilo:
		pr.append(Vector2(p.x, p.y))
	# la normale di ogni giunto: la tangente del profilo girata di un quarto
	var nr: Array[Vector2] = []
	for i in pr.size():
		var d := (pr[mini(i + 1, pr.size() - 1)] - pr[maxi(i - 1, 0)]).normalized()
		nr.append(Vector2(d.y, -d.x).normalized())
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var giro := func(i: int, j: int) -> Vector3:
		var a := PI * float(j) / float(spicchi)
		return Vector3(cos(a) * pr[i].x, pr[i].y, -sin(a) * pr[i].x)
	var verso := func(i: int, j: int) -> Vector3:
		var a := PI * float(j) / float(spicchi)
		return Vector3(cos(a) * nr[i].x, nr[i].y, -sin(a) * nr[i].x).normalized()
	# niente `% spicchi` sull'ultimo spicchio: il mezzo giro NON si richiude,
	# e riportare l'ultimo anello sul primo rifarebbe la cupola intera
	for i in pr.size() - 1:
		for j in spicchi:
			st.set_normal(verso.call(i, j))
			st.add_vertex(giro.call(i, j))
			st.set_normal(verso.call(i + 1, j))
			st.add_vertex(giro.call(i + 1, j))
			st.set_normal(verso.call(i + 1, j + 1))
			st.add_vertex(giro.call(i + 1, j + 1))
			st.set_normal(verso.call(i, j))
			st.add_vertex(giro.call(i, j))
			st.set_normal(verso.call(i + 1, j + 1))
			st.add_vertex(giro.call(i + 1, j + 1))
			st.set_normal(verso.call(i, j + 1))
			st.add_vertex(giro.call(i, j + 1))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


## IL CATINO DIPINTO. Un cielo notturno con una manciata di stelle nei
## colori delle costellazioni, e in basso — piccolissimi — una valigia e
## un cappello posati nell'erba. Niente figure, nessuno di spalle che si
## allontana, nessuna porta di luce: il congedo, in questo gioco, non è
## mai morte, e l'unica iconografia ammessa è quella che le parole usano
## già. Chi alza la testa deve vedere un posto dove si va, non un posto da
## cui non si torna.
static func _abside_catino(n: Node3D) -> void:
	# UNA CUPOLA SI GUARDA DA SOTTO, e una superficie chiusa vista da
	# dentro sparisce: le facce di dietro se le mangia il culling. Questo è
	# l'unico materiale della chiesa che lo disattiva — non è un vezzo, è
	# la condizione perché il catino esista.
	var cielo := CAT._glow(PIETRA_NOTTE, PIETRA_NOTTE_CUPA, 0.16)
	cielo.cull_mode = BaseMaterial3D.CULL_DISABLED
	# IL MEZZO GIRO, non il giro intero: il catino era un lathe a 360° dentro
	# un tamburo che è mezzo poligono, e la metà verso la navata restava
	# scoperta — raggio 0.335 contro un muro che sul lato aperto finisce a
	# 0.08, cioè 0.31 di cupola sospesa nel vuoto, che di profilo si vedeva
	# sporgere blu da dietro l'intonaco. Dieci spicchi sul mezzo giro sono gli
	# stessi 18° dei venti sul giro intero: la superficie che resta è identica
	# a prima. E la base (0.335 = ABSIDE_R meno mezzo spessore) muore sulla
	# faccia interna del muro, fra i due stipiti: la volta parte dall'arco.
	_mezza_rivoluzione(n, [
		Vector2(0.335, 0.0), Vector2(0.325, 0.09), Vector2(0.29, 0.175),
		Vector2(0.225, 0.245), Vector2(0.13, 0.295), Vector2(0.0, 0.315),
	], cielo, ABSIDE_CENTRO + Vector3(0, 2.02, 0), 10)

	# le stelle: crema calda e appena luminose. Con l'emissione alta il
	# crema sbianca e il catino diventa un soffitto di lampadine.
	var luce := CAT._glow(PIETRA_STELLA, PIETRA_STELLA, 0.7)
	var filo := CAT._glow(PIETRA_STELLA, PIETRA_STELLA, 0.3)
	var stelle := [
		[-0.62, 0.5, 0.021], [-0.29, 0.68, 0.016], [0.03, 0.82, 0.025],
		[0.35, 0.66, 0.017], [0.63, 0.47, 0.02],
		[-0.92, 0.27, 0.013], [0.86, 0.3, 0.012], [0.14, 0.33, 0.011],
	]
	var punti: Array[Vector3] = []
	for s in stelle:
		var az: float = s[0]
		var el: float = s[1]
		var p := ABSIDE_CENTRO + Vector3(sin(az) * cos(el) * 0.3, 0, -cos(az) * cos(el) * 0.3) \
				+ Vector3(0, 2.02 + sin(el) * 0.27, 0)
		punti.append(p)
		CAT._ball(n, float(s[2]), luce, p, Vector3(1.0, 1.0, 0.55))
	# il tratto che unisce le prime cinque: senza le linee sono stelle
	# sparse, con le linee è UNA costellazione — e una costellazione, qui,
	# è il nome di qualcuno che è partito
	for k in 4:
		_abside_tratto(n, punti[k], punti[k + 1], filo)

	# LA VALIGIA E IL CAPPELLO, in basso e sull'asse, posati nell'erba.
	# Un nodo solo, appoggiato alla curva del catino: dipingerli in
	# coordinate assolute li avrebbe lasciati per aria davanti alla volta.
	var ricordo := Node3D.new()
	ricordo.position = ABSIDE_CENTRO + Vector3(0, 2.075, -0.305)
	ricordo.rotation = Vector3(-0.35, PI, 0)
	n.add_child(ricordo)
	var erba := CAT._mat(CAT.LEAF, CAT.LEAF_DARK, 8.0, 0.5)
	var paglia := CAT._mat(Color("cfa96b"), Color("a8874f"), 6.0, 0.45)
	# il -Z locale è il fuori: dopo il mezzo giro attorno a Y il +Z guarda
	# dentro la volta, e un rilievo messo lì lo si dipinge dietro il muro
	CAT._box(ricordo, Vector3(0.3, 0.018, 0.008), erba, Vector3(0, 0, -0.002))
	CAT._box(ricordo, Vector3(0.062, 0.042, 0.012),
			CAT._mat(Color("a5713f"), Color("7d5330"), 6.0, 0.45), Vector3(0.05, 0.026, -0.005))
	CAT._box(ricordo, Vector3(0.02, 0.009, 0.014),
			CAT._mat(CAT.OTTONE, CAT.OTTONE_SCURO, 6.0, 0.35), Vector3(0.05, 0.051, -0.005))
	CAT._ball(ricordo, 0.03, paglia, Vector3(-0.055, 0.03, -0.006), Vector3(1.0, 0.7, 0.35))
	CAT._ball(ricordo, 0.048, paglia, Vector3(-0.055, 0.014, -0.006), Vector3(1.0, 0.28, 0.3))


## Un tratto fra due stelle. Niente look_at: il nodo non è ancora
## nell'albero quando lo costruiamo, e look_at su un nodo fuori albero
## non ha un transform globale da cui partire.
static func _abside_tratto(n: Node3D, a: Vector3, b: Vector3, mat: Material) -> void:
	var d := b - a
	var l := d.length()
	if l < 0.001:
		return
	var dn := d / l
	var seg := CAT._cyl(n, 0.0035, 0.0035, l, mat, a + d * 0.5)
	# l'asse del cilindro è +Y: prima lo si inclina attorno a X (che porta
	# +Y verso +Z), poi lo si gira attorno a Y. L'ordine di Godot è YXZ,
	# cioè esattamente questo.
	seg.rotation = Vector3(acos(clampf(dn.y, -1.0, 1.0)), atan2(dn.x, dn.z), 0.0)


# --------------------------------------------- la fonte dei nomi

## LA FONTE DEI NOMI. La chiesa deve tenere tutti e due i capi di una vita
## o non ne tiene nessuno: di là si accende un lume per chi è partito per
## il Grande Prato, e qui si scrive il nome di chi è appena nato. Non un
## battesimo — questo mondo non ha un credo: una conca d'acqua di fiume e
## un registro dove il paese si segna chi è arrivato.
##
## Piede, fusto e vasca sono UN SOLO lathe, ed è il miglior rapporto
## bellezza/nodi di tutto il set. Ma il profilo è tutto: senza una
## strozzatura netta a metà fusto e un toro che RIENTRA sotto la vasca,
## la stessa identica tecnica tira fuori una coppa da gelato. Il profilo
## scavalca il labbro e ridiscende dentro: la conca, l'interno e il fondo
## nascono dalla stessa superficie continua.
static func fonte_dei_nomi() -> Node3D:
	var n := Node3D.new()
	var pietra := CAT._mat(CAT.STONE, CAT.STONE_DARK, 3.0, 0.5)
	var lucida := CAT._mat(PIETRA_LUCIDA, CAT.STONE, 2.2, 0.3)
	var ottone := CAT._mat(CAT.OTTONE, CAT.OTTONE_SCURO, 5.0, 0.4)

	CAT.BUILDER.lathe(n, [
		Vector2(0.235, 0.0), Vector2(0.232, 0.03), Vector2(0.2, 0.055),
		Vector2(0.145, 0.075), Vector2(0.118, 0.105),
		Vector2(0.098, 0.155),                        # la strozzatura del piede
		Vector2(0.079, 0.26), Vector2(0.072, 0.38),   # il punto più stretto: il fusto non è un tubo
		Vector2(0.078, 0.46),
		Vector2(0.108, 0.515), Vector2(0.138, 0.545), # il toro parte di scatto
		Vector2(0.132, 0.575),                        # e RIENTRA: senza il rientro il toro non si vede
		Vector2(0.168, 0.615), Vector2(0.216, 0.675),
		Vector2(0.244, 0.745), Vector2(0.25, 0.8), Vector2(0.243, 0.822),
		# da qui il profilo scavalca il bordo e torna giù: è l'interno
		Vector2(0.222, 0.815), Vector2(0.207, 0.775), Vector2(0.19, 0.735),
		Vector2(0.12, 0.712), Vector2(0.0, 0.706),
	], pietra, Vector3.ZERO, 26)

	# IL LABBRO OTTAGONALE. Otto conci di pietra chiara sul bordo: gli
	# spigoli sono tutta la differenza fra una fonte e un vaso. Quello
	# davanti — il -Z, il lato da cui ci si avvicina — è di pietra
	# LUCIDATA: è lì che si appoggiano le mani da sempre, e il liscio si
	# vede solo se il resto attorno non ce l'ha.
	for i in 8:
		var a := float(i) * TAU / 8.0
		var faccia := CAT._box(n, Vector3(0.2, 0.055, 0.062),
				lucida if i == 0 else pietra,
				Vector3(sin(a) * 0.235, 0.852, -cos(a) * 0.235))
		faccia.rotation.y = -a
	# l'anello d'ottone attorno al labbro. Un toro sta già nel piano XZ:
	# qui NON va ruotato — è l'anello di un bordo, non un rosone.
	var anello := TorusMesh.new()
	anello.inner_radius = 0.254
	anello.outer_radius = 0.272
	anello.rings = 26
	anello.ring_segments = 7
	var am := MeshInstance3D.new()
	am.mesh = anello
	am.material_override = ottone
	am.position = Vector3(0, 0.848, 0)
	n.add_child(am)

	_fonte_acqua(n)
	_fonte_coperchio(n, ottone)
	_fonte_registro(n, ottone)

	# due gocce sulla pietra, appena fuori dal labbro: qualcuno ci ha
	# bagnato le dita poco fa, ed è tutto quello che serve per dire che
	# questa conca non è un soprammobile
	var goccia := CAT._glow(Color(0.72, 0.88, 0.96, 0.75), Color(0.5, 0.76, 0.92), 0.18)
	goccia.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	CAT._ball(n, 0.016, goccia, Vector3(-0.06, 0.884, -0.216), Vector3(1.0, 0.22, 1.3))
	CAT._ball(n, 0.011, goccia, Vector3(0.02, 0.883, -0.228), Vector3(1.1, 0.2, 1.0))
	return n


## L'acqua ferma e la sua increspatura lentissima.
##
## I due orologi non si richiudono mai: il pelo dell'acqua respira su 7.3
## secondi, il cerchio si allarga su 9.1. Un solo seno si smaschera in due
## cicli — e in una stanza dove si viene per stare fermi, l'unica cosa che
## si muove va guardata a lungo.
static func _fonte_acqua(n: Node3D) -> void:
	var acqua := Node3D.new()
	acqua.name = "Acqua"
	acqua.position = Vector3(0, 0.745, 0)
	n.add_child(acqua)
	var pelo := CAT._glow(Color(0.62, 0.85, 0.94, 0.72), Color(0.42, 0.72, 0.9), 0.13)
	pelo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	CAT._cyl(acqua, 0.192, 0.192, 0.012, pelo, Vector3.ZERO)

	# il cerchio che si allarga e si spegne: un toro piatto, nel piano
	# dell'acqua (nessuna rotazione: il toro ci nasce, nel piano XZ)
	var onda_mat := CAT._glow(Color(0.86, 0.95, 1.0, 0.5), Color(0.7, 0.88, 1.0), 0.3)
	onda_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var t := TorusMesh.new()
	t.inner_radius = 0.048
	t.outer_radius = 0.056
	t.rings = 24
	t.ring_segments = 5
	var onda := MeshInstance3D.new()
	onda.name = "Onda"
	onda.mesh = t
	onda.material_override = onda_mat
	onda.position = Vector3(0, 0.007, 0)
	acqua.add_child(onda)

	var anim := Animation.new()
	anim.length = 9.1
	anim.loop_mode = Animation.LOOP_LINEAR
	var t_pelo := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(t_pelo, NodePath("Acqua:position:y"))
	anim.track_insert_key(t_pelo, 0.0, 0.745)
	anim.track_insert_key(t_pelo, 3.65, 0.7465)
	anim.track_insert_key(t_pelo, 7.3, 0.745)
	anim.track_set_interpolation_type(t_pelo, Animation.INTERPOLATION_CUBIC)
	var t_scala := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(t_scala, NodePath("Acqua/Onda:scale"))
	anim.track_insert_key(t_scala, 0.0, Vector3(0.25, 1, 0.25))
	anim.track_insert_key(t_scala, 9.1, Vector3(3.4, 1, 3.4))
	var t_alfa := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(t_alfa, NodePath("Acqua/Onda:material_override:albedo_color"))
	anim.track_insert_key(t_alfa, 0.0, Color(0.86, 0.95, 1.0, 0.0))
	anim.track_insert_key(t_alfa, 1.4, Color(0.86, 0.95, 1.0, 0.42))
	anim.track_insert_key(t_alfa, 9.1, Color(0.86, 0.95, 1.0, 0.0))
	var lib := AnimationLibrary.new()
	lib.add_animation("respiro", anim)
	var player := AnimationPlayer.new()
	n.add_child(player)
	player.add_animation_library("", lib)
	player.autoplay = "respiro"


## Il coperchio di legno, scostato di lato a metà sulla sua catenella.
## Scostato e non tolto: un coperchio appoggiato per bene dice che la
## fonte è chiusa, uno scostato dice che qualcuno l'ha aperta stamattina
## e non l'ha più richiusa perché tanto oggi si scrive un nome.
static func _fonte_coperchio(n: Node3D, ottone: Material) -> void:
	var legno := CAT._mat(Color("b98a58"), Color("946b40"), 3.4, 0.5)
	# DOVE SI FERMA. Il disco è più largo della bocca della conca (0.225
	# contro 0.21): scostato non ci cade dentro, resta a cavallo — un
	# bordo appoggiato sul labbro a +X, quello opposto calato dentro fino
	# alla parete della vasca. Il piano che unisce i due appoggi è
	# inclinato di 0.187, e sono quei due punti a decidere posizione e
	# rotazione, non l'occhio: un coperchio "buttato lì" a stima resta
	# sempre sospeso per aria da qualche parte.
	var cop := Node3D.new()
	cop.position = Vector3(0.026, 0.885, 0.0)
	cop.rotation = Vector3(0, 0.22, -0.187)
	n.add_child(cop)
	# ottagonale come il labbro: due ottagoni che si guardano si
	# riconoscono, un cono liscio sopra un ottagono è un cappello prestato
	cono_lati(cop, 0.032, 0.225, 0.09, 8, legno, Vector3.ZERO)
	CAT._ball(cop, 0.026, ottone, Vector3(0, 0.058, 0), Vector3(1, 0.85, 1))
	# la catenella dal pomello all'anello del bordo: molla, non tesa —
	# una catena tesa è un tirante, e nessuno tira un coperchio
	CAT.BUILDER.tube(n, [Vector3(0.05, 0.945, 0.015), Vector3(0.155, 0.878, 0.065),
			Vector3(0.235, 0.851, 0.093)], [0.006, 0.0065, 0.006], ottone, 12, 6)


## IL REGISTRO APERTO. Due pagine crema e tratti fini, mai lettere
## leggibili: una lettera vera si legge, e appena si legge diventa
## sbagliata per qualcuno. Le righe hanno lunghezze diverse perché i nomi
## hanno lunghezze diverse, e sono poche: questo villaggio è piccolo.
static func _fonte_registro(n: Node3D, ottone: Material) -> void:
	# i due bracci d'ottone avvitati al labbro, che tengono il registro
	# perché non scivoli dentro: senza, un libro appoggiato su un bordo di
	# sei centimetri è un libro che sta per cadere nell'acqua
	for sx: float in [-1.0, 1.0]:
		var braccio := CAT._box(n, Vector3(0.012, 0.008, 0.11), ottone,
				Vector3(-0.182 + sx * 0.075, 0.8795, -0.182 - sx * 0.02))
		braccio.rotation.y = PI * 0.25

	var reg := Node3D.new()
	reg.position = Vector3(-0.182, 0.878, -0.182)
	reg.rotation = Vector3(0, PI * 0.25 + 0.07, 0)   # nessuno lo riappoggia dritto
	n.add_child(reg)
	var carta := CAT._mat(CAT.CREAM, Color("efe0c4"), 7.0, 0.25)
	var inchiostro := CAT._mat(LEGNO_INCHIOSTRO, LEGNO_INCHIOSTRO.darkened(0.2), 5.0, 0.2)
	for lato: float in [-1.0, 1.0]:
		var pag := CAT._box(reg, Vector3(0.115, 0.012, 0.155), carta,
				Vector3(lato * 0.062, 0.006, 0))
		pag.rotation.z = lato * 0.05
		# tre righe per pagina, lunghezze diverse
		var lung := [0.072, 0.055, 0.084] if lato < 0.0 else [0.066, 0.08, 0.048]
		for k in 3:
			CAT._box(reg, Vector3(float(lung[k]), 0.003, 0.005), inchiostro,
					Vector3(lato * 0.062 - 0.02 + float(lung[k]) * 0.5, 0.013,
							-0.045 + float(k) * 0.036))
	CAT._box(reg, Vector3(0.022, 0.016, 0.155),
			CAT._mat(Color("8a5a3a"), Color("6a4128"), 4.0, 0.4), Vector3(0, 0.004, 0))
	# il nastro segnalibro, che esce dalla piega e ricasca sul bordo
	CAT._box(reg, Vector3(0.011, 0.003, 0.19),
			CAT._mat(Color("c0554f"), Color("9c403b"), 5.0, 0.4), Vector3(0.012, 0.014, 0.02))
	var coda := CAT._box(reg, Vector3(0.011, 0.003, 0.07),
			CAT._mat(Color("c0554f"), Color("9c403b"), 5.0, 0.4), Vector3(0.012, 0.005, 0.13))
	coda.rotation.x = -0.5
	# la penna posata nella piega: è il dettaglio che dice che il registro
	# è aperto perché qualcuno sta per scrivere, non perché è in mostra
	var penna := CAT._cyl(reg, 0.004, 0.007, 0.15,
			CAT._mat(Color("e8ddc4"), Color("c9bb9a"), 6.0, 0.3), Vector3(0.004, 0.02, 0.01))
	penna.rotation = Vector3(PI * 0.5, 0.35, 0.12)


# ==========================================================================
# IL LASTRICATO, LA VOLTA, IL PORTALE, L'ALTARE, L'ARMONIUM
# ==========================================================================

# ============================================================ LA CHIESA (1)
# IL DENTRO: il pavimento che rende visibili tutti gli altri pezzi, la
# volta che ripaga chi alza la testa, il portale che non si è mai chiuso,
# l'altare dove il paese posa quello che ha, e l'armonium che dà alla
# stanza la sua seconda voce dopo la campana.
#
# Non è una cattedrale: è alta quanto due chibi uno sull'altro, e non
# chiede niente a nessuno. L'unica regola di composizione è l'ASSE
# portale-navata-altare: qui la storta cozy che altrove dà vita uccide la
# lettura, quindi tutto quello che sta sull'asse è simmetrico sul serio, e
# la vita la mettono le cose POSATE sopra (le candele di altezza diversa,
# le ante socchiuse in modo disuguale, le lastre consumate).

# --- la pietra: una cava sola per tutto il set --------------------------
# Il pavimento e la soglia del portale sono la STESSA pietra: in un paese
# di due strade non si compra due volte.
const PIETRA_LASTRA := Color("e2dbcc")
const PIETRA_LASTRA_B := Color("d3ccbd")
const PIETRA_LASTRA_C := Color("ece6d8")
const PIETRA_CALCE := Color("8b8479")        # la malta scura delle fughe
const PIETRA_LISCIA := Color("e9e3d3")       # dove il passo ha lucidato
const PIETRA_CONCIO_ARCO := Color("d8cbb0")       # i conci dell'arco: più caldi
const PIETRA_CONCIO_ARCO_SCURO := Color("bcae90")
const PIETRA_CHIAVE := Color("ecdcb6")       # il concio in chiave, più chiaro
const PIETRA_INTONACO := Color("f0e9d8")     # le vele della volta
# --- i legni: il rovere del portale e il noce del mobile ----------------
const LEGNO_ROVERE := Color("6b4a33")
const LEGNO_ROVERE_SCURO := Color("4e3524")
const LEGNO_NOCE := Color("7d5233")
const LEGNO_NOCE_SCURO := Color("5c3a24")
const LEGNO_NOCE_CONSUMATO := Color("a3714a")  # dove si appoggiano le mani

# La volta: due quote sole, e da queste discende tutto il resto (le vele,
# i peducci, la falda del tetto). Scriverle a mano in sei punti era il
# modo sicuro di ritrovarsi un costolone che buca l'intonaco.
const VOLTA_IMPOSTA := 2.06   # da dove nasce: il filo di sopra dei muri
const VOLTA_FRECCIA := 0.40   # quanto sale la chiave sopra l'imposta


## Il ferro battuto di questa chiesa: cardini, borchie, chiavistelli.
## Sta in una funzione e non in una const perché la tavolozza condivisa
## accetta solo colori VETRO_/PIETRA_/LEGNO_ — e un ferro leggermente
## diverso su ogni pezzo si vede subito, su oggetti che stanno vicini.
static func _ferro_chiesa() -> ShaderMaterial:
	return CAT._mat(Color("4a443d"), Color("332f2a"), 5.0, 0.35)


## Il respiro di una fiamma, dato da DUE orologi che non si richiudono:
## `c1` e `c2` sono i cicli compiuti dentro la stessa animazione, e vanno
## presi PRIMI FRA LORO — così dentro il giro la coppia di fasi non si
## ripete mai e l'occhio non trova il punto in cui il nastro ricomincia.
## Un sin() puro si smaschera in due cicli: si vede che la fiamma "conta".
## La fiamma inoltre si ASSOTTIGLIA quando si allunga (una fiamma non è
## un palloncino che gonfia): X e Z vanno all'indietro rispetto a Y.
static func _fiamma_respiro(anim: Animation, percorso: String, c1: int, c2: int,
		amp := 0.16) -> void:
	var tr := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(tr, NodePath(percorso + ":scale"))
	anim.track_set_interpolation_type(tr, Animation.INTERPOLATION_CUBIC)
	var passi := 32
	for i in passi + 1:
		var u := float(i) / float(passi)
		var v := amp * sin(TAU * float(c1) * u) + amp * 0.45 * sin(TAU * float(c2) * u + 1.1)
		anim.track_insert_key(tr, anim.length * u,
				Vector3(1.0 - v * 0.3, 1.0 + v, 1.0 - v * 0.3))


## Un'oscillazione lenta su un canale singolo (il dondolio della lampada,
## il mantice dei pedali): `cicli` interi dentro la lunghezza, o al
## riavvolgimento si vede lo scatto.
static func _oscilla(anim: Animation, percorso: String, cicli: int,
		da: float, a: float) -> void:
	var tr := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(tr, NodePath(percorso))
	anim.track_set_interpolation_type(tr, Animation.INTERPOLATION_CUBIC)
	var passi := cicli * 2
	for i in passi + 1:
		# l'ampiezza non è mai due volte la stessa: 3% di deriva basta a
		# togliere il tic-tac senza che si veda "un'animazione". Il modulo
		# serve a far combaciare l'ultima chiave con la prima: senza, al
		# riavvolgimento resta uno scatto piccolo ma regolare — e sono
		# proprio le cose regolari che l'occhio impara.
		var respiro := 1.0 + 0.03 * sin(float(i % passi) * 2.399)
		anim.track_insert_key(tr, anim.length * float(i) / float(passi),
				(da if i % 2 == 0 else a) * respiro)


# ------------------------------------------------------------ il lastricato

## IL LASTRICATO. È il pezzo che rende visibili tutti gli altri: le
## vetrate posano le loro pozze colorate QUI, e su un pavimento di legno
## caldo quelle pozze non esistono più — si perdono nel colore del legno.
## Quindi pietra quasi bianca, corsi irregolari, e la calce scura sotto a
## fare le fughe: sono le fughe a dire "lastricato" e non "lastra unica".
##
## Le due lastre sull'asse (quelle che il portale mette in fila con
## l'altare) sono consumate: più basse di 4 mm, con lo spigolo mangiato e
## una pietra più liscia. L'usura che viene DOPO — quella dei passi veri —
## la dipinge da sé la tela dei Sentieri consumati: qui non si tocca.
static func lastricato() -> Node3D:
	var n := Node3D.new()
	# il letto di calce: riempie le fughe e fa da fondo scuro.
	# Senza, fra una lastra e l'altra si vedrebbe l'erba del prato.
	CAT._box(n, Vector3(1.0, 0.04, 1.0),
			CAT._mat(PIETRA_CALCE, PIETRA_CALCE.darkened(0.22), 5.0, 0.5),
			Vector3(0, 0.02, 0))
	var toni := [
		CAT._mat(PIETRA_LASTRA, PIETRA_LASTRA.darkened(0.10), 3.0, 0.42),
		CAT._mat(PIETRA_LASTRA_B, PIETRA_LASTRA_B.darkened(0.10), 2.6, 0.46),
		CAT._mat(PIETRA_LASTRA_C, PIETRA_LASTRA_C.darkened(0.08), 3.4, 0.36),
	]
	# la pietra consumata è più LISCIA, non più scura: il piede lucida, non
	# sporca. Rumore fitto e poco profondo = superficie quasi uniforme.
	var liscia := CAT._mat(PIETRA_LISCIA, PIETRA_LISCIA.darkened(0.05), 9.0, 0.2)

	# Tre corsi di altezza diversa, e i giunti verticali SFALSATI fra un
	# corso e l'altro: allineati, il pavimento diventa una scacchiera e la
	# cella si legge come una piastrella sola.
	#   x, z, larghezza, profondità, tono, consumata
	var lastre := [
		[-0.28, -0.335, 0.44, 0.33, 0, false],
		[0.22, -0.335, 0.56, 0.33, 1, false],
		[-0.35, -0.010, 0.30, 0.32, 2, false],
		[0.00, -0.010, 0.40, 0.32, 1, true],
		[0.35, -0.010, 0.30, 0.32, 0, false],
		[-0.33, 0.325, 0.34, 0.35, 1, false],
		[0.04, 0.325, 0.40, 0.35, 2, true],
		[0.37, 0.325, 0.26, 0.35, 0, false],
	]
	for i in lastre.size():
		var riga: Array = lastre[i]
		var x := float(riga[0])
		var z := float(riga[1])
		# la fuga: 1,8 cm di calce fra una lastra e l'altra. Non è un numero
		# estetico — è il margine che tiene la lastra GIRATA dentro la sua
		# cella: due lastricati accostati con gli angoli che si toccano si
		# compenetrano a filo, e due facce complanari sfarfallano.
		var w := float(riga[2]) - 0.018
		var d := float(riga[3]) - 0.018
		var usata: bool = riga[5]
		var mat: Material = liscia if usata else toni[int(riga[4])]
		# la lastra consumata sta 4 mm più in basso: il piano di calpestio
		# del pavimento di casa è a 0.05, e da lì si scende
		var alt := 0.046 if usata else 0.05
		var lastra := CAT._box(n, Vector3(w, alt, d), mat, Vector3(x, alt * 0.5, z))
		# poco più di un grado, sempre lo stesso ad ogni avvio: il seme è
		# l'indice. Una lastra perfettamente allineata all'altra non è
		# posata a mano da nessuno.
		lastra.rotation.y = (0.019 if i % 2 == 0 else -0.022) + float(i) * 0.0015
		if usata:
			# lo spigolo smussato: una lastra appena più larga e più bassa
			# sotto quella consumata. Due quote invece di una e l'occhio
			# legge un bordo mangiato, non un gradino tagliato col coltello.
			var orlo := CAT._box(n, Vector3(w + 0.014, 0.036, d + 0.014), mat,
					Vector3(x, 0.018, z))
			orlo.rotation.y = lastra.rotation.y

	# le scaglie: i cunei di pietra che il selciatore infila dove il corso
	# non torna. Sono la firma del lavoro fatto a occhio.
	var scaglia := CAT._mat(PIETRA_LASTRA_B, PIETRA_CALCE, 4.0, 0.5)
	CAT._box(n, Vector3(0.055, 0.042, 0.075), scaglia,
			Vector3(-0.062, 0.021, -0.175)).rotation.y = 0.34
	CAT._box(n, Vector3(0.048, 0.04, 0.055), scaglia,
			Vector3(0.243, 0.02, 0.152)).rotation.y = -0.5
	CAT._box(n, Vector3(0.04, 0.038, 0.062), scaglia,
			Vector3(-0.455, 0.019, 0.14)).rotation.y = 0.22
	return n


# ----------------------------------------------------------------- la volta

## LA VOLTA. Occupa lo slot del Tetto (layer 3): una navata coperta è una
## FILA di Volte, e alzare la testa dentro la chiesa deve servire a
## qualcosa. Vive tutta sopra il filo dei muri (2.06) perché è lassù che
## c'è aria: dentro, la stanza da 2 m diventa una stanza da 2,46.
##
## È la risposta ONESTA alla volta. La superficie curva vista da sotto non
## si può fare: il materiale handpaint non ha cull_disabled, il TorusMesh
## non si taglia a metà e un cilindro cavo, da sotto, sarebbe INVISIBILE.
## Ma di una volta l'occhio riconosce due cose sole — i COSTOLONI e la
## CHIAVE — e quelle si possono fare vere.
##
## LA GEOMETRIA, perché i numeri non sembrino tirati a caso:
##  · i costoloni sono DUE semicerchi di raggio 0,707 (la mezza diagonale
##    della cella) girati a ±45°: due archi, quattro nervature che si
##    incontrano in mezzo. Schiacciati in Y a 0.566 danno una freccia di
##    0,40 — una volta ribassata, da chiesa di paese, non da cattedrale.
##  · le vele sono quattro coppie di falde piane. Una vela vera è una
##    porzione di botte: la sua altezza sopra l'imposta segue
##    0.8*sqrt(0.25 - z²), che è ESATTAMENTE la stessa curva su cui corre
##    il costolone lungo la diagonale (la groin di due botti uguali è
##    l'ellisse del costolone). Quindi le due falde di ogni vela sono
##    tagliate per stare SOPRA quella curva: così i costoloni sporgono
##    verso il basso, e non finiscono sepolti dentro l'intonaco.
##  · dove le falde non ce la fanno a stare sopra la curva — negli ultimi
##    venti centimetri verso l'angolo, dove un'ellisse è quasi verticale
##    per definizione e nessuna corda la può inseguire — ci va il
##    PEDUCCIO: la mensola di pietra da cui il costolone nasce. Non è un
##    cerotto: è il pezzo che in una volta vera sta esattamente lì.
##  · le quattro falde piane si intersecano fra loro sulle diagonali per
##    pura simmetria: le pieghe che si vedono da sotto sono i groin, e
##    cadono precise sotto i costoloni. Gratis.
static func volta() -> Node3D:
	var n := Node3D.new()
	var pietra := CAT._mat(CAT.STONE, CAT.STONE_DARK, 3.0, 0.45)
	var pietra_cupa := CAT._mat(CAT.STONE_DARK, CAT.STONE_DARK.darkened(0.18), 3.5, 0.45)
	var intonaco := CAT._mat(PIETRA_INTONACO, PIETRA_INTONACO.darkened(0.09), 2.4, 0.36)
	var ottone := CAT._mat(CAT.OTTONE, CAT.OTTONE_SCURO, 5.0, 0.4)
	# gli stessi coppi del Tetto, volutamente: da fuori il paese ha UN
	# tetto solo, e una chiesa con le tegole di un altro colore sembrerebbe
	# arrivata da un altro gioco
	var coppo := CAT._mat(Color("d97e5f"), Color("c26847"), 3.0, 0.55)
	var coppo_cupo := CAT._mat(Color("b55c3e"), Color("a34f34"), 2.0, 0.4)

	# I COSTOLONI. Un mesh l'uno: è la ragione per cui questa volta costa
	# una quarantina di nodi invece di centoventi.
	for giro: float in [PI * 0.25, -PI * 0.25]:
		var costolone := arco_nastro(n, pietra, 0.707, 0.05, 0.55,
				Vector3(0, VOLTA_IMPOSTA, 0), giro)
		# lo schiacciamento in Y arriva DOPO l'helper (che ha già scritto
		# scale.z): scriverlo con un scale intero cancellerebbe la sezione
		# ovale del nastro e tornerebbe un tubo tondo
		costolone.scale.y = VOLTA_FRECCIA / 0.707

	# I QUATTRO LATI: cornice d'imposta, peduccio d'angolo e le due falde
	# della vela. Un nodo girato per lato, così si scrive una volta sola.
	for lato in 4:
		var g := Node3D.new()
		g.rotation.y = float(lato) * PI * 0.5
		n.add_child(g)
		# la cornice d'imposta: la modanatura da cui la volta nasce. Serve
		# anche a nascondere il filo di sotto delle vele, che parte 10 cm
		# sopra l'imposta — senza, in cima al muro resterebbe una fessura.
		# (la cornice resta DENTRO la cella: due campate in fila hanno la
		# cornice sullo stesso filo e alla stessa quota — un centimetro di
		# sbordo e le due facce si mettono a sfarfallare)
		CAT._box(g, Vector3(1.02, 0.10, 0.14), pietra,
				Vector3(0, VOLTA_IMPOSTA + 0.05, -0.43))
		CAT._box(g, Vector3(1.02, 0.03, 0.10), pietra_cupa,
				Vector3(0, VOLTA_IMPOSTA + 0.015, -0.45))
		# il peduccio: due blocchi girati di 45°, quello di sotto più
		# piccolo. Una mensola si stringe scendendo, o è una scatola.
		CAT._box(g, Vector3(0.12, 0.07, 0.12), pietra_cupa,
				Vector3(-0.38, VOLTA_IMPOSTA + 0.035, -0.38)).rotation.y = PI * 0.25
		CAT._box(g, Vector3(0.19, 0.06, 0.19), pietra,
				Vector3(-0.38, VOLTA_IMPOSTA + 0.10, -0.38)).rotation.y = PI * 0.25
		# LA VELA, in due falde. La prima è ripida (sale 26 cm in 22),
		# la seconda quasi piatta: è così che è fatta una botte, e questa
		# è mezza botte.
		var bassa := CAT._box(g, Vector3(1.02, 0.035, 0.345), intonaco,
				Vector3(0, VOLTA_IMPOSTA + 0.2325, -0.39))
		bassa.rotation.x = -0.878
		var alta := CAT._box(g, Vector3(1.02, 0.035, 0.285), intonaco,
				Vector3(0, VOLTA_IMPOSTA + 0.39, -0.14))
		alta.rotation.x = -0.177

	# LA CHIAVE, scolpita e SPORGENTE verso il basso: senza, l'incrocio dei
	# quattro nastri è un nodo confuso in mezzo al soffitto. È anche il
	# posto giusto da cui appendere qualcosa.
	var chiave := VOLTA_IMPOSTA + VOLTA_FRECCIA
	cono_lati(n, 0.145, 0.10, 0.07, 8, pietra, Vector3(0, chiave - 0.045, 0))
	cono_lati(n, 0.10, 0.035, 0.10, 8, pietra, Vector3(0, chiave - 0.13, 0))
	CAT._ball(n, 0.035, pietra_cupa, Vector3(0, chiave - 0.185, 0), Vector3(1, 0.8, 1))
	# le foglie scolpite attorno al bottone: sei, e una più corta — a un
	# metro di distanza si legge solo che qualcuno ci ha lavorato sopra
	for i in 6:
		var a := TAU * float(i) / 6.0
		CAT._ball(n, 0.032 if i != 2 else 0.026, pietra,
				Vector3(cos(a) * 0.115, chiave - 0.075, sin(a) * 0.115),
				Vector3(1.0, 0.45, 0.75)).rotation.y = -a

	# LA LAMPADA A TRE CERI, appesa alla chiave. Sta in un nodo suo perché
	# deve poter dondolare: una lampada appesa che non si muove MAI è la
	# cosa che più di ogni altra dice "questo è un modello 3D".
	var lampada := Node3D.new()
	lampada.name = "Lampada"
	lampada.position = Vector3(0, chiave - 0.19, 0)
	n.add_child(lampada)
	# l'anello di sospensione, poi la catena
	var anello := TorusMesh.new()
	anello.inner_radius = 0.018
	anello.outer_radius = 0.026
	anello.rings = 12
	anello.ring_segments = 6
	var am := MeshInstance3D.new()
	am.mesh = anello
	am.material_override = ottone
	am.rotation.x = PI * 0.5
	lampada.add_child(am)
	# la catena è LUNGA: una lampada appesa a filo del soffitto non entra
	# nella stanza, e questa deve scendere dentro la navata fin dove la si
	# guarda dal basso (resta comunque un metro e venti sopra la testa)
	CAT._cyl(lampada, 0.005, 0.005, 0.34, ottone, Vector3(0, -0.19, 0))
	# la corona che porta i ceri. Questa NON si gira: il toro nasce già
	# coricato nel piano XZ, che è come sta un cerchio di lampadario.
	# (L'anello di sospensione qui sopra invece è girato, perché quello
	# pende in verticale dal gancio: stesso mesh, due orientamenti veri.)
	var corona := TorusMesh.new()
	corona.inner_radius = 0.098
	corona.outer_radius = 0.115
	corona.rings = 22
	corona.ring_segments = 6
	var cm := MeshInstance3D.new()
	cm.mesh = corona
	cm.material_override = ottone
	cm.position = Vector3(0, -0.37, 0)
	lampada.add_child(cm)
	for i in 3:
		var a := TAU * float(i) / 3.0 + 0.4
		var px := cos(a) * 0.107
		var pz := sin(a) * 0.107
		# la coppetta, la candela e la cera colata sull'orlo: tre ceri
		# accesi in tre momenti diversi non possono essere alti uguali
		var h: float = [0.075, 0.055, 0.066][i]
		CAT._cyl(lampada, 0.028, 0.02, 0.022, ottone, Vector3(px, -0.355, pz))
		CAT._cyl(lampada, 0.016, 0.018, h,
				CAT._mat(CAT.CREAM, Color("efe2c8"), 6.0, 0.28),
				Vector3(px, -0.33 + h * 0.5, pz))
		CAT._ball(lampada, 0.012, CAT._mat(CAT.CREAM, Color("efe2c8"), 6.0, 0.28),
				Vector3(px * 1.12, -0.34, pz * 1.12), Vector3(0.8, 1.6, 0.8))
		var f := Node3D.new()
		f.name = "Fiamma%d" % i
		f.position = Vector3(px, -0.325 + h, pz)
		lampada.add_child(f)
		fiamma(f, Vector3.ZERO, 0.75)

	# IL TETTO, per chi guarda la chiesa da fuori: due falde e il colmo.
	# Il colmo corre lungo Z (il verso della navata), le falde scendono a
	# destra e a sinistra — con s = -1/+1 la falda va girata di -s*angolo,
	# o invece della punta viene fuori una V e nessun errore lo dice.
	# NIENTE SBORDO IN Z. Le Volte stanno in fila lungo la navata: falda,
	# colmo e muretto di due campate vicine sono superfici PARALLELE alla
	# stessa quota, e basta un centimetro di sovrapposizione perché le
	# facce complanari si mettano a sfarfallare. Si accostano, non si
	# accavallano — il Tetto se lo può permettere, questa no.
	for s: float in [-1.0, 1.0]:
		var falda := CAT._box(n, Vector3(0.62, 0.06, 1.0), coppo,
				Vector3(s * 0.245, 2.52, 0))
		falda.rotation.z = -s * 0.675
		# i filari di coppi corrono NEL VERSO della pendenza
		for cz: float in [-0.31, 0.0, 0.31]:
			CAT._box(falda, Vector3(0.6, 0.03, 0.07), coppo_cupo, Vector3(0, 0.045, cz))
	CAT._box(n, Vector3(0.13, 0.08, 1.0), coppo_cupo, Vector3(0, 2.735, 0))
	# il muretto sotto la gronda: da fuori, fra il filo dei muri e la falda
	# ci sarebbero 25 cm di vele nude. Questo è il cleristorio della navata.
	for s2: float in [-1.0, 1.0]:
		CAT._box(n, Vector3(0.1, 0.28, 1.0), pietra, Vector3(s2 * 0.47, 2.2, 0))

	# sotto la volta NON piove: la stessa scatola di collisione del Tetto,
	# alzata alla quota della copertura
	var pcol := GPUParticlesCollisionBox3D.new()
	pcol.size = Vector3(1.04, 0.16, 1.04)
	pcol.position = Vector3(0, 2.46, 0)
	n.add_child(pcol)

	# Il dondolio della lampada e il respiro dei ceri. Il giro dura 12 s e
	# dentro ci stanno cicli PRIMI FRA LORO (2 e 3 per la lampada): la
	# figura che ne esce si richiude solo alla fine, e nessuno guarda una
	# lampada per dodici secondi di fila aspettando il momento.
	var anim := Animation.new()
	anim.length = 12.0
	anim.loop_mode = Animation.LOOP_LINEAR
	_oscilla(anim, "Lampada:rotation:z", 2, -0.022, 0.022)
	_oscilla(anim, "Lampada:rotation:x", 3, 0.016, -0.016)
	_fiamma_respiro(anim, "Lampada/Fiamma0", 5, 8)
	_fiamma_respiro(anim, "Lampada/Fiamma1", 4, 7, 0.19)
	_fiamma_respiro(anim, "Lampada/Fiamma2", 6, 11, 0.14)
	var lib := AnimationLibrary.new()
	lib.add_animation("respira", anim)
	var player := AnimationPlayer.new()
	n.add_child(player)
	player.add_animation_library("", lib)
	player.autoplay = "respira"
	return n


# --------------------------------------------------------------- il portale

## IL PORTALE. La porta di una chiesa non è una porta: è più larga, più
## tonda, più vecchia — ed è l'unica parte dell'edificio che il giocatore
## guarda DA VICINO ogni volta che entra. Quindi qui si spende.
##
## Ossatura del Muro con la porta (stipiti, varco attraversabile, spessore
## 0.16) ma l'apertura è a tutto sesto, con l'arco fatto di conci VERI —
## un semicerchio dipinto si smaschera appena la camera scende.
##
## Le ante non hanno una posa chiusa. Non è una dimenticanza: è la frase
## che questo pezzo deve dire. Chi arriva alle tre di notte entra.
static func portale() -> Node3D:
	var n := Node3D.new()
	var concio := CAT._mat(PIETRA_CONCIO_ARCO, PIETRA_CONCIO_ARCO_SCURO, 3.0, 0.5)
	var chiave := CAT._mat(PIETRA_CHIAVE, PIETRA_CONCIO_ARCO, 3.2, 0.45)
	var muro := CAT._mat(CAT.PLASTER, CAT.PLASTER_SHADE, 2.5, 0.5)
	var pietra := CAT._mat(PIETRA_LASTRA, PIETRA_LASTRA.darkened(0.12), 3.0, 0.45)
	var rovere := CAT._mat(LEGNO_ROVERE, LEGNO_ROVERE_SCURO, 3.0, 0.55)
	var rovere_cupo := CAT._mat(LEGNO_ROVERE_SCURO, LEGNO_ROVERE_SCURO.darkened(0.25), 2.4, 0.5)
	var ferro := _ferro_chiesa()
	var ruggine := CAT._mat(Color("7a5439"), Color("5a3c28"), 6.0, 0.45)

	# IL TIMPANO CHIUSO. Sopra l'architrave non c'è nessun buco: la lunetta
	# è muratura piena con la rosa dentro. Questo pannello sul retro chiude
	# in un colpo solo tutti gli spicchi fra l'arco e lo spigolo del muro —
	# la stessa cosa fatta a gradini lascia sempre una fessura da cui si
	# vede il cielo, e il cielo dentro un muro è il difetto che uccide.
	CAT._box(n, Vector3(1.0, 0.76, 0.05), muro, Vector3(0, 1.66, 0.055))

	# gli stipiti: base, fusto, capitello. Un montante liscio dal
	# pavimento all'arco è un tubo; è la BASE che dice "pietra posata".
	# (base e capitello sporgono in AVANTI, non di lato: un pezzo edge che
	# esce dalla sua cella si infila dentro il muro accanto — l'aggetto
	# che si vede, da davanti, è comunque solo quello in Z)
	for s: float in [-1.0, 1.0]:
		CAT._box(n, Vector3(0.19, 0.13, 0.22), pietra, Vector3(s * 0.405, 0.065, 0))
		CAT._box(n, Vector3(0.18, 1.07, 0.16), concio, Vector3(s * 0.41, 0.665, 0))
		CAT._box(n, Vector3(0.19, 0.12, 0.21), chiave, Vector3(s * 0.405, 1.26, 0))
		# la scanalatura del fusto, dalla parte del varco: una modanatura
		# verticale che prende luce e fa leggere lo spessore dello stipite
		CAT._box(n, Vector3(0.03, 1.02, 0.03), CAT._mat(PIETRA_CONCIO_ARCO_SCURO,
				PIETRA_CONCIO_ARCO_SCURO.darkened(0.2), 4.0, 0.4),
				Vector3(s * 0.325, 0.66, -0.083))

	# L'ARCO A TUTTO SESTO: undici conci, quello in chiave più chiaro e più
	# alto. UN SOLO ordine di archivolto: il secondo giro raddoppia i nodi
	# e a distanza di gioco non lo vede nessuno.
	arco_conci(n, concio, chiave, 0.32, 0.14, 0.16, 11, Vector3(0, 1.32, 0))

	# i cunei di muratura fra l'estradosso e lo spigolo, a gradini come li
	# posa un muratore vero (il timpano dietro copre quello che avanza)
	# (x, y, larghezza, altezza — ogni gradino parte appena DENTRO
	# l'estradosso del giro che ha sopra: fra un gradino e l'arco non deve
	# restare una fessura, e l'ultimo si ferma a 14 cm dall'asse per non
	# seppellire il concio in chiave, che è il pezzo che si guarda)
	var gradini := [[0.415, 1.40, 0.17, 0.16], [0.40, 1.55, 0.20, 0.14],
			[0.36, 1.67, 0.28, 0.10], [0.32, 1.775, 0.36, 0.11]]
	for s2: float in [-1.0, 1.0]:
		for gr in gradini:
			CAT._box(n, Vector3(float(gr[2]), float(gr[3]), 0.15), muro,
					Vector3(s2 * float(gr[0]), float(gr[1]), 0))
	# la fascia sopra l'arco e il cornicione, alla stessa quota del Muro di
	# casa (2.04): un pezzo edge che non allinea la sua cornice a quella
	# dei muri accanto si vede da cento metri
	CAT._box(n, Vector3(1.0, 0.2, 0.15), muro, Vector3(0, 1.93, 0))
	CAT._box(n, Vector3(1.02, 0.08, 0.19), CAT._mat(CAT.WOOD, CAT.WOOD_DARK, 4.0, 0.5),
			Vector3(0, 2.04, 0))

	# L'ARCHITRAVE: la pietra su cui muore la porta e da cui parte l'arco.
	CAT._box(n, Vector3(0.8, 0.12, 0.2), pietra, Vector3(0, 1.26, 0))
	CAT._box(n, Vector3(0.84, 0.03, 0.22), chiave, Vector3(0, 1.335, 0))

	# LA ROSA DELLA LUNETTA. Otto petali d'ambra: è il primo vetro colorato
	# che si incontra, e prepara il rosone del frontone. Le bacchette sono
	# di PIOMBO e non di pietra: qui il tondo è largo 30 cm, una raggiera
	# di pietra a quella scala sarebbe una ruota di carro.
	rosa(n, 8, 0.155, [vetro(VETRO_AMBRA, 0.75), vetro(VETRO_AMBRA.darkened(0.18), 0.6)],
			piombo(), vetro(VETRO_AMBRA, 0.9), Vector3(0, 1.475, -0.055))

	# LA SOGLIA. Sporge di 4 cm da tutti e due i lati (una soglia a filo del
	# muro non la si nota, e una soglia che non si nota non si consuma) e
	# in mezzo è più bassa di 5 mm: lì passano tutti.
	CAT._box(n, Vector3(0.84, 0.05, 0.24), pietra, Vector3(0, 0.025, 0))
	CAT._box(n, Vector3(0.36, 0.045, 0.25),
			CAT._mat(PIETRA_LISCIA, PIETRA_LISCIA.darkened(0.05), 9.0, 0.2),
			Vector3(0, 0.0225, 0))

	# LE ANTE. Due, socchiuse in modo DISUGUALE: due ante aperte dello
	# stesso angolo sono una porta a battenti di un centro commerciale.
	# I cardini stanno su nodi loro, pronti per il giorno in cui si
	# vorranno aprire davvero.
	for s3: float in [-1.0, 1.0]:
		var cardine := Node3D.new()
		cardine.name = "HingeSx" if s3 < 0.0 else "HingeDx"
		cardine.position = Vector3(s3 * 0.32, 0, 0)
		# verso l'esterno (-Z): una porta di chiesa si spinge da dentro
		cardine.rotation.y = 0.52 if s3 < 0.0 else -0.26
		n.add_child(cardine)
		var cx := -s3 * 0.158    # il centro dell'anta, dal lato del varco
		# le assi verticali: cinque per anta, con la fuga fra l'una e
		# l'altra. Un pannello unico non è un portone, è un compensato.
		for k in 5:
			var ax := cx + (float(k) - 2.0) * s3 * 0.062
			# due millimetri di scarto in profondità fra un'asse e l'altra:
			# il legno vecchio si imbarca, e una facciata di assi
			# perfettamente complanari è un pannello di truciolato
			CAT._box(cardine, Vector3(0.058, 1.15, 0.045),
					rovere if k % 2 == 0 else rovere_cupo,
					Vector3(ax, 0.625, 0.002 if k % 2 == 0 else -0.002))
		# le due traverse di ferro (i cardini a fascia): partono dal
		# cardine e arrivano a metà anta, come nelle porte vecchie
		for ty: float in [0.28, 1.0]:
			CAT._box(cardine, Vector3(0.2, 0.045, 0.05), ferro,
					Vector3(-s3 * 0.08, ty, -0.028))
			CAT._box(cardine, Vector3(0.11, 0.035, 0.048), ferro,
					Vector3(-s3 * 0.215, ty, -0.028))
			CAT._ball(cardine, 0.028, ferro, Vector3(-s3 * 0.28, ty, -0.028),
					Vector3(1.0, 0.9, 0.5))
		# LE BORCHIE: sei per anta, a quinconce. In fila regolare sembrano
		# viti; sfalsate sembrano piantate a martello.
		for r in 3:
			for c in 2:
				var bx := cx + (float(c) - 0.5) * 0.13 + (0.02 if r == 1 else 0.0)
				CAT._ball(cardine, 0.019, ferro,
						Vector3(bx, 0.5 + float(r) * 0.26, -0.024),
						Vector3(1.0, 1.0, 0.55))
		# L'ANELLO. Il toro sta nel piano XZ: per vederlo in faccia da
		# davanti ci vuole rotation.x = PI*0.5, e poi si schiaccia in
		# scale.z — come il manico dei Secchi. Un anello tondo perfetto
		# non pende: pende un ovale.
		var ring := TorusMesh.new()
		ring.inner_radius = 0.038
		ring.outer_radius = 0.05
		ring.rings = 18
		ring.ring_segments = 7
		var rm := MeshInstance3D.new()
		rm.mesh = ring
		rm.material_override = ferro
		rm.position = Vector3(cx - s3 * 0.09, 0.7, -0.04)
		rm.rotation.x = PI * 0.5
		rm.scale = Vector3(1, 1, 0.6)
		cardine.add_child(rm)
		CAT._ball(cardine, 0.026, ferro, Vector3(cx - s3 * 0.09, 0.755, -0.036),
				Vector3(1.0, 0.7, 0.6))

	# IL CHIAVISTELLO, arrugginito e TIRATO: sta nella posizione aperta,
	# perché in questa chiesa non è mai stato chiuso. La bandella vuota
	# sull'altra anta è la metà che racconta la storia.
	var anta_sx := n.get_node("HingeSx") as Node3D
	CAT._box(anta_sx, Vector3(0.22, 0.035, 0.03), ruggine, Vector3(0.14, 0.86, -0.045))
	CAT._ball(anta_sx, 0.022, ruggine, Vector3(0.25, 0.86, -0.045), Vector3(1, 1, 0.8))
	CAT._box(anta_sx, Vector3(0.045, 0.06, 0.045), ferro, Vector3(0.03, 0.86, -0.045))
	var anta_dx := n.get_node("HingeDx") as Node3D
	CAT._box(anta_dx, Vector3(0.05, 0.07, 0.05), ruggine, Vector3(-0.03, 0.86, -0.045))
	return n


# ---------------------------------------------------------------- l'altare

## L'ALTARE. Il fuoco prospettico della navata: il punto in fondo verso
## cui puntano banchi, arcate e lastricato. Qui non è un luogo di
## sacrificio — questo mondo non ha un credo — è il tavolo su cui il paese
## posa quello che ha.
##
## La cosa che fa "altare" e non "bancone da cucina" è LA TOVAGLIA: è
## l'unico colore caldo e saturo del set, e casca su tre lati con le
## pieghe vere. Cinque volumi di larghezza calante costano cinque nodi e
## valgono l'intero pezzo; una texture a pieghe, da vicino, è carta da
## parati.
static func altare() -> Node3D:
	var n := Node3D.new()
	# la pietra della predella è quella del Lastricato: la predella è il
	# pavimento che sale, non un mobile appoggiato sopra
	var lastra := CAT._mat(PIETRA_LASTRA, PIETRA_LASTRA.darkened(0.1), 3.0, 0.42)
	var lastra_b := CAT._mat(PIETRA_LASTRA_B, PIETRA_LASTRA_B.darkened(0.1), 2.6, 0.46)
	var mensa_mat := CAT._mat(PIETRA_LASTRA_C, PIETRA_LASTRA, 3.4, 0.34)
	var lino := CAT._mat(CAT.CREAM, Color("f0e4c8"), 5.0, 0.4)
	var lino_ombra := CAT._mat(Color("f0e4c8"), Color("ddceac"), 5.0, 0.45)
	var rosso := CAT._mat(Color("c0453f"), Color("9a332f"), 6.0, 0.45)
	var ottone := CAT._mat(CAT.OTTONE, CAT.OTTONE_SCURO, 5.0, 0.4)
	var cera := CAT._mat(CAT.CREAM, Color("efe2c8"), 6.0, 0.28)

	# LA PREDELLA: due gradini. Un altare a filo del pavimento non è il
	# fondo di niente — è il gradino che dice "da qui in poi si sale".
	CAT._box(n, Vector3(0.98, 0.08, 0.88), lastra_b, Vector3(0, 0.04, 0))
	CAT._box(n, Vector3(0.86, 0.08, 0.74), lastra, Vector3(0, 0.12, 0))
	# il naso del gradino, appena più chiaro: è lo spigolo che si consuma
	CAT._box(n, Vector3(0.98, 0.02, 0.03), mensa_mat, Vector3(0, 0.075, -0.435))

	# le quattro colonnine, con base e capitello
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var px := sx * 0.24
			var pz := sz * 0.14
			CAT._cyl(n, 0.06, 0.07, 0.05, mensa_mat, Vector3(px, 0.185, pz))
			CAT._cyl(n, 0.043, 0.05, 0.47, mensa_mat, Vector3(px, 0.445, pz))
			CAT._cyl(n, 0.07, 0.055, 0.05, mensa_mat, Vector3(px, 0.705, pz))

	# LA MENSA: il piano SPORGE di 4 cm su tutti i lati e ha lo smusso. A
	# filo del corpo sembrerebbe un blocco unico colato, e la mensa di un
	# altare è una lastra POSATA su qualcosa.
	CAT._box(n, Vector3(0.7, 0.1, 0.46), mensa_mat, Vector3(0, 0.775, 0))
	CAT._box(n, Vector3(0.74, 0.025, 0.5), mensa_mat, Vector3(0, 0.8375, 0))
	CAT._box(n, Vector3(0.78, 0.045, 0.54), lastra, Vector3(0, 0.8725, 0))

	# LA TOVAGLIA. Cade su tre lati (dietro c'è l'abside: nessuno guarda
	# lì) e l'orlo NON è dritto.
	CAT._box(n, Vector3(0.82, 0.022, 0.58), lino, Vector3(0, 0.906, 0))
	CAT._box(n, Vector3(0.8, 0.35, 0.02), lino, Vector3(0, 0.73, -0.285))
	for sx2: float in [-1.0, 1.0]:
		CAT._box(n, Vector3(0.02, 0.31, 0.56), lino, Vector3(sx2 * 0.405, 0.75, 0))
	# LE PIEGHE: cinque volumi di larghezza calante, ognuno un filo più
	# stretto e un filo più corto del precedente, e nessuno centrato. È la
	# disuguaglianza a fare la stoffa: cinque pieghe uguali sono una
	# grondaia.
	var pieghe := [[-0.3, 0.34, 0.15], [-0.13, 0.31, 0.12], [0.04, 0.35, 0.1],
			[0.19, 0.29, 0.085], [0.32, 0.32, 0.065]]
	for p in pieghe:
		var pw := float(p[2])
		var ph := float(p[1])
		var piega := CAT._box(n, Vector3(pw, ph, 0.035), lino_ombra,
				Vector3(float(p[0]), 0.917 - ph * 0.5, -0.292))
		piega.rotation.z = (float(p[0]) - 0.02) * 0.06
	# l'orlo dentellato: la stoffa finisce a punte, come un pizzo
	for i in 11:
		var ox := -0.36 + float(i) * 0.072
		CAT._ball(n, 0.036, lino_ombra, Vector3(ox, 0.556, -0.29),
				Vector3(1.0, 0.55, 0.4))
	# IL FILO ROSSO ricamato sull'orlo. È l'unico colore saturo del pezzo,
	# ed è lui a dire "altare" prima di qualunque forma. (Ed è anche, senza
	# che nessuno lo abbia deciso, lo stesso rosso del Filo Rosso.)
	CAT._box(n, Vector3(0.8, 0.012, 0.028), rosso, Vector3(0, 0.585, -0.297))
	for i in 9:
		# i punti del ricamo: corti, obliqui, alternati — un filo dritto
		# è un nastro incollato
		var px2 := -0.33 + float(i) * 0.0825
		var punto := CAT._box(n, Vector3(0.03, 0.008, 0.026), rosso,
				Vector3(px2, 0.6, -0.297))
		punto.rotation.z = 0.5 if i % 2 == 0 else -0.5
	for sx3: float in [-1.0, 1.0]:
		CAT._box(n, Vector3(0.028, 0.012, 0.56), rosso, Vector3(sx3 * 0.412, 0.6, 0))

	# I DUE CANDELIERI d'ottone torniti, ALTI DIVERSI: non sono mai stati
	# accesi insieme, e questa è tutta la storia che serve.
	for i in 2:
		var s := -1.0 if i == 0 else 1.0
		var scala := 1.0 if i == 0 else 0.86
		var base := Vector3(s * 0.26, 0.917, 0.055)
		CAT.BUILDER.lathe(n, [
			Vector2(0.062, 0.0), Vector2(0.058, 0.016), Vector2(0.026, 0.03),
			Vector2(0.034, 0.056), Vector2(0.019, 0.078), Vector2(0.033, 0.104),
			Vector2(0.017, 0.13), Vector2(0.024, 0.152), Vector2(0.015, 0.172),
			Vector2(0.04, 0.196), Vector2(0.031, 0.211), Vector2(0.013, 0.219),
		], ottone, base, 18, 1.0, scala)
		var h := 0.219 * scala
		var alt_cera := 0.1 if i == 0 else 0.062
		CAT._cyl(n, 0.016, 0.018, alt_cera, cera,
				base + Vector3(0, h + alt_cera * 0.5, 0))
		# la cera colata sull'orlo del piattello: due gocce, di lunghezza
		# diversa, dal lato dove la fiamma tira
		CAT._ball(n, 0.011, cera, base + Vector3(0.026 * s, h - 0.012, 0.004),
				Vector3(0.8, 2.2, 0.8))
		CAT._ball(n, 0.009, cera, base + Vector3(-0.02 * s, h - 0.006, -0.014),
				Vector3(0.8, 1.4, 0.8))
		var f := Node3D.new()
		f.name = "Cero%d" % i
		f.position = base + Vector3(0, h + alt_cera + 0.012, 0)
		n.add_child(f)
		fiamma(f, Vector3.ZERO, 0.9 if i == 0 else 0.8)

	# L'OFFERTA: il vassoietto di legno dove un giorno il paese poserà il
	# primo raccolto della stagione. Vuoto, e in un nodo suo: un sistema
	# che vuole posarci qualcosa cerca il nodo, non ricalcola una quota.
	var offerta := Node3D.new()
	offerta.name = "Offerta"
	offerta.position = Vector3(0, 0.917, -0.13)
	n.add_child(offerta)
	var legno := CAT._mat(CAT.WOOD, CAT.WOOD_DARK, 4.0, 0.5)
	CAT._box(offerta, Vector3(0.22, 0.018, 0.16), legno, Vector3(0, 0.009, 0))
	for sz2: float in [-1.0, 1.0]:
		CAT._box(offerta, Vector3(0.22, 0.028, 0.016), legno, Vector3(0, 0.022, sz2 * 0.072))
	for sx4: float in [-1.0, 1.0]:
		CAT._box(offerta, Vector3(0.016, 0.028, 0.16), legno, Vector3(sx4 * 0.102, 0.022, 0))

	# il respiro delle due fiamme: cicli primi fra loro, e due ampiezze
	# diverse (la candela più bassa è più corta di stoppino, tremola di più)
	var anim := Animation.new()
	anim.length = 15.0
	anim.loop_mode = Animation.LOOP_LINEAR
	_fiamma_respiro(anim, "Cero0", 5, 9, 0.15)
	_fiamma_respiro(anim, "Cero1", 4, 7, 0.21)
	var lib := AnimationLibrary.new()
	lib.add_animation("respira", anim)
	var player := AnimationPlayer.new()
	n.add_child(player)
	player.add_animation_library("", lib)
	player.autoplay = "respira"
	return n


# -------------------------------------------------------------- l'armonium

## L'ARMONIUM. La seconda voce della chiesa dopo la campana, e la ragione
## per entrare quando non sta succedendo niente di solenne: questo
## villaggio canta già — il coro in Chibiese armonizzato dal DNA — e quel
## canto non ha una stanza.
##
## Un organo a canne è stato scartato: 42 nodi e un registro da
## cattedrale. Qui siamo in un paese di due strade, e un mobiletto di noce
## con due pedali dice la stessa cosa con più tenerezza.
##
## Lo sgabello NON si fa: c'è già lo Sgabello in catalogo.
static func armonium() -> Node3D:
	var n := Node3D.new()
	var noce := CAT._mat(LEGNO_NOCE, LEGNO_NOCE_SCURO, 3.5, 0.5)
	var noce_cupo := CAT._mat(LEGNO_NOCE_SCURO, LEGNO_NOCE_SCURO.darkened(0.25), 3.0, 0.45)
	# il legno consumato dove si appoggiano le mani e i polsi: più chiaro,
	# più liscio. È il dettaglio che dice "questo mobile è stato suonato".
	var consumato := CAT._mat(LEGNO_NOCE_CONSUMATO, LEGNO_NOCE, 8.0, 0.25)
	var avorio := CAT._mat(Color("f6efdc"), Color("e4dac2"), 7.0, 0.25)
	var tasto_scuro := CAT._mat(Color("3a322c"), Color("2a2420"), 6.0, 0.3)
	var panno := CAT._mat(Color("9c4740"), Color("7a3630"), 5.0, 0.5)
	var osso := CAT._mat(Color("efe6d2"), Color("d8ccb2"), 6.0, 0.3)
	var ottone := CAT._mat(CAT.OTTONE, CAT.OTTONE_SCURO, 5.0, 0.4)

	# LA CASSA. I due fianchi scendono fino a terra con i piedi ricavati,
	# come nei mobili veri; il fondo chiude dietro (il mobile è addossato
	# alla parete, il retro non lo vede nessuno ma un buco sì).
	for sx: float in [-1.0, 1.0]:
		CAT._box(n, Vector3(0.05, 0.79, 0.36), noce, Vector3(sx * 0.335, 0.505, 0))
		CAT._box(n, Vector3(0.075, 0.12, 0.38), noce_cupo, Vector3(sx * 0.335, 0.06, 0))
	CAT._box(n, Vector3(0.68, 0.5, 0.03), noce_cupo, Vector3(0, 0.42, 0.165))
	# il piano di sopra, che sporge da tutti i lati
	CAT._box(n, Vector3(0.8, 0.045, 0.42), noce, Vector3(0, 0.8775, 0))
	CAT._box(n, Vector3(0.8, 0.018, 0.03), consumato, Vector3(0, 0.877, -0.205))

	# LA TASTIERA. Tastini VERI: i bianchi lunghi e a filo, i neri più
	# corti, più stretti e RIALZATI. Una striscia dipinta con le righe
	# nere, da vicino, è una tastiera di cartone — e questo è un pezzo che
	# si guarda da vicino, perché ci si siede davanti.
	CAT._box(n, Vector3(0.68, 0.05, 0.26), noce_cupo, Vector3(0, 0.585, -0.03))
	CAT._box(n, Vector3(0.72, 0.03, 0.035), consumato, Vector3(0, 0.6, -0.152))
	var bianchi := 15
	for k in bianchi:
		var kx := -0.28 + float(k) * 0.04
		CAT._box(n, Vector3(0.037, 0.016, 0.17), avorio, Vector3(kx, 0.618, -0.07))
	# i neri stanno FRA i bianchi, e nel loro posto vero: due, poi tre.
	for k2 in bianchi - 1:
		var grado := k2 % 7
		if grado == 2 or grado == 6:
			continue
		CAT._box(n, Vector3(0.021, 0.024, 0.105),
				tasto_scuro, Vector3(-0.26 + float(k2) * 0.04, 0.63, -0.098))

	# I QUATTRO POMELLI D'OSSO coi cartellini: i registri. Nessuno li
	# leggerà mai, e devono esserci lo stesso.
	for i in 4:
		var px := (-0.285 + float(i) * 0.055) if i < 2 else (0.175 + float(i - 2) * 0.055)
		var pom := CAT._cyl(n, 0.019, 0.016, 0.045, osso, Vector3(px, 0.665, -0.155))
		pom.rotation.x = PI * 0.5
		CAT._box(n, Vector3(0.042, 0.018, 0.006), osso, Vector3(px, 0.7, -0.145))

	# IL PANNELLO TRAFORATO con la stoffa dietro: è da lì che esce la voce.
	# La stoffa scura dietro il traforo è quello che fa leggere i vuoti
	# come vuoti; senza, il traforo è un disegno inciso su un'asse.
	CAT._box(n, Vector3(0.62, 0.22, 0.012), panno, Vector3(0, 0.755, -0.02))
	CAT._box(n, Vector3(0.66, 0.035, 0.03), noce, Vector3(0, 0.878, -0.035))
	CAT._box(n, Vector3(0.66, 0.035, 0.03), noce, Vector3(0, 0.638, -0.035))
	for sx2: float in [-1.0, 1.0]:
		CAT._box(n, Vector3(0.04, 0.24, 0.03), noce, Vector3(sx2 * 0.31, 0.758, -0.035))
		# le volute: due riccioli di legno per lato, uno grande e uno
		# piccolo, che si rincorrono verso il centro
		for j in 4:
			var a := PI * 0.5 * float(j) + 0.4
			CAT._ball(n, 0.026 - float(j) * 0.003, noce,
					Vector3(sx2 * (0.22 + cos(a) * 0.055), 0.79 + sin(a) * 0.05, -0.038),
					Vector3(1.0, 1.0, 0.4))
		CAT._box(n, Vector3(0.2, 0.028, 0.028), noce,
				Vector3(sx2 * 0.16, 0.672, -0.038)).rotation.z = sx2 * 0.22
	# l'arcatella al centro del traforo: tre archetti, e sotto si vede il
	# panno rosso
	for j2 in 3:
		arco_nastro(n, noce, 0.036, 0.011, 0.5,
				Vector3(-0.075 + float(j2) * 0.075, 0.7, -0.04))

	# IL LEGGÌO pieghevole, col foglio sopra: due righi e due note. Non
	# serve che si legga la musica — serve che si veda che qualcuno l'ha
	# lasciato aperto.
	var leggio := Node3D.new()
	leggio.name = "Leggio"
	leggio.position = Vector3(0, 0.9, 0.06)
	leggio.rotation.x = 0.26
	n.add_child(leggio)
	CAT._box(leggio, Vector3(0.5, 0.24, 0.018), noce, Vector3(0, 0.12, 0))
	CAT._box(leggio, Vector3(0.52, 0.022, 0.035), noce, Vector3(0, 0.005, -0.012))
	var foglio := CAT._box(leggio, Vector3(0.28, 0.19, 0.005),
			CAT._mat(Color("f7f0dd"), Color("e6dcc2"), 7.0, 0.2),
			Vector3(0.01, 0.125, -0.014))
	foglio.rotation.z = -0.04
	for r in 4:
		CAT._box(leggio, Vector3(0.24, 0.004, 0.004), tasto_scuro,
				Vector3(0.01, 0.185 - float(r) * 0.035, -0.018))
	CAT._ball(leggio, 0.011, tasto_scuro, Vector3(-0.04, 0.15, -0.02),
			Vector3(1.3, 0.9, 0.4))
	CAT._ball(leggio, 0.011, tasto_scuro, Vector3(0.05, 0.115, -0.02),
			Vector3(1.3, 0.9, 0.4))

	# IL MOZZICONE DI CANDELA nel braccetto laterale, con la cera colata
	# lungo il piattello: si suona anche quando è buio, e nessuno ha
	# ancora comprato una candela nuova.
	CAT._cyl(n, 0.012, 0.012, 0.09, ottone, Vector3(0.36, 0.86, -0.06)).rotation.z = PI * 0.5
	CAT._cyl(n, 0.042, 0.03, 0.012, ottone, Vector3(0.4, 0.865, -0.06))
	CAT._cyl(n, 0.017, 0.019, 0.045, CAT._mat(CAT.CREAM, Color("efe2c8"), 6.0, 0.28),
			Vector3(0.4, 0.893, -0.06))
	CAT._ball(n, 0.01, CAT._mat(CAT.CREAM, Color("efe2c8"), 6.0, 0.28),
			Vector3(0.422, 0.868, -0.055), Vector3(0.8, 1.8, 0.8))

	# I DUE PEDALI DEL MANTICE, ognuno sul suo pivot: il giorno che
	# qualcuno si siede, pompano davvero. Sporgono da sotto la cassa,
	# perché è lì che ci arrivano i piedi.
	for s: float in [-1.0, 1.0]:
		var pedale := Node3D.new()
		pedale.name = "PedaleSx" if s < 0.0 else "PedaleDx"
		pedale.position = Vector3(s * 0.15, 0.115, -0.01)
		n.add_child(pedale)
		CAT._box(pedale, Vector3(0.2, 0.022, 0.24), noce, Vector3(0, 0, -0.13))
		# il tappetino di panno inchiodato sopra, consumato dal tacco
		CAT._box(pedale, Vector3(0.15, 0.012, 0.15), panno, Vector3(0, 0.015, -0.15))
		# la biella che sparisce dentro la cassa
		CAT._cyl(pedale, 0.008, 0.008, 0.1, ottone, Vector3(0, 0.03, -0.02))
	# le due staffe fisse su cui i pedali sono incernierati
	for s2: float in [-1.0, 1.0]:
		CAT._box(n, Vector3(0.23, 0.03, 0.04), noce_cupo, Vector3(s2 * 0.15, 0.115, 0.01))

	# IL MANTICE CHE RESPIRA. I due pedali stanno in controfase e non
	# tornano MAI in fase: sette cicli uno, sei l'altro, dentro lo stesso
	# giro da 21 secondi. Sette e sei sono primi fra loro, quindi dentro il
	# giro la coppia non si ripete: chi passa non trova il punto in cui
	# l'animazione ricomincia — e un mobile che respira è un mobile che
	# qualcuno ha appena smesso di suonare.
	var anim := Animation.new()
	anim.length = 21.0
	anim.loop_mode = Animation.LOOP_LINEAR
	_oscilla(anim, "PedaleSx:rotation:x", 7, -0.03, 0.12)
	_oscilla(anim, "PedaleDx:rotation:x", 6, 0.12, -0.03)
	var lib := AnimationLibrary.new()
	lib.add_animation("mantice", anim)
	var player := AnimationPlayer.new()
	n.add_child(player)
	player.add_animation_library("", lib)
	player.autoplay = "mantice"
	return n


# ==========================================================================
# LA VETRATA, IL SAGRATO, IL FRONTONE, IL CANDELIERE, IL CAMPANILE
# ==========================================================================

# ============================================================================
# LA CHIESA · IL MURO CHE FA ENTRARE LA LUCE, LA SOGLIA, LA FACCIATA,
#             IL LUME PER CHI NON C'È, LA VERTICALE DEL PAESE
# ============================================================================
# Cinque pezzi che stanno insieme per una ragione sola: da lontano la chiesa
# la comprano il campanile, il frontone e il ritmo delle vetrate; da vicino
# la compra l'asse portale-navata-altare. Qui la storta cozy che altrove dà
# vita (l'insegna storta, il cassetto socchiuso) UCCIDE la lettura: la
# simmetria è il senso del posto, e va tenuta pulita.
#
# Fronte di tutti i pezzi: -Z, come il resto del catalogo. Fuori è -Z,
# dentro è +Z: gli sguanci si aprono verso +Z perché la luce entra, e la
# lastra annerita del Candeliere sta a +Z perché non deve coprire le fiamme.

# La pietra della chiesa NON è quella dei sentieri: è calda, di cava, cotta
# da cent'anni di sole. Con CAT.STONE (grigio freddo) la chiesa diventava un
# muretto di recinzione — e la stessa pietra dev'essere identica in Vetrata,
# Frontone e Campanile, o il fianco si legge come tre edifici accostati.
const PIETRA_CHIARA := Color("d2c8b3")
const PIETRA_OMBRA := Color("a99e88")
# il grigio di cava delle lastre calpestate: più freddo del muro, perché
# viene dal fiume e non dalla collina
const PIETRA_FREDDA := Color("bdb8ae")
const PIETRA_FREDDA_CUPA := Color("9d988e")
# l'unica lastra venuta da un'altra cava: senza di lei il sagrato è un
# marciapiede: sono le eccezioni che dicono «l'ha fatto qualcuno»
const PIETRA_ROSATA := Color("c8ac9c")
# la terra scura delle fughe, che si vede solo dove il passo non arriva
const PIETRA_TERRA := Color("6b5b47")
# il legno affumicato della portella e dell'anta: più cupo del WOOD di casa,
# è legno vecchio tenuto all'aperto
const LEGNO_FUMO := Color("8d6742")


## Il ferro battuto: scuro, opaco, MAI lucido. Non è l'ottone (che canta) e
## non è il piombo dei vetri (che sparisce): è il metallo di un fabbro che
## ha battuto una cosa sola per un pomeriggio. Lo usano le traverse della
## Vetrata e la banderuola del Campanile: un solo posto, o fra tre pezzi
## vicini escono tre metalli diversi.
static func _ferro_battuto() -> ShaderMaterial:
	return CAT._mat(Color("463f36"), Color("2d2823"), 6.0, 0.35)


## I CORSI di pietra. Un muro non è una lastra: è una PILA. Ogni corso è un
## box a sé, di tinta alternata e sporgente quattro millimetri più del
## vicino — basta quello a far correre la luce radente sui letti di malta, e
## costa UN nodo per corso invece di uno per pietra (venti Vetrate in fila
## sono venti volte quello che scrivi qui).
## `alterno` dev'essere una pietra QUASI UGUALE alla prima (5% più scura, non
## di più): con la pietra d'ombra vera il fianco della chiesa esce a righe
## bianche e grigie come una tenda da sole — visto a schermo, e non si
## dimentica.
## Dove c'è il vano della finestra il corso si spezza in due tronchi: è così
## che un muratore vero gira attorno a un'apertura, e il vano deve cadere su
## un confine di corso (passo 0.24 da quota 0.18: l'imposta a 1.62 ci cade
## esatta) o restano fessure che si vedono in controluce.
static func _corsi(n: Node3D, pietra: Material, alterno: Material,
		y_da: float, y_a: float, larghezza: float,
		vano_meta := 0.0, vano_y0 := 0.0, vano_y1 := 0.0) -> void:
	var y := y_da
	var i := 0
	while y < y_a - 0.002:
		var h: float = minf(0.24, y_a - y)
		var scuro: bool = i % 2 == 1
		var mat: Material = alterno if scuro else pietra
		var prof: float = 0.164 if scuro else 0.156
		var cy := y + h * 0.5
		if vano_meta > 0.0 and y < vano_y1 - 0.002 and y + h > vano_y0 + 0.002:
			var tronco := larghezza * 0.5 - vano_meta
			for s: float in [-1.0, 1.0]:
				CAT._box(n, Vector3(tronco, h, prof), mat,
						Vector3(s * (vano_meta + tronco * 0.5), cy, 0))
		else:
			CAT._box(n, Vector3(larghezza, h, prof), mat, Vector3(0, cy, 0))
		y += h
		i += 1


## Zoccolo e cornice: le due quote che DEVONO combaciare fra Vetrata,
## Frontone e Muro di pietra. Sono loro a far leggere il fianco della chiesa
## come un muro solo invece che come una fila di pannelli: se lo zoccolo di
## un pezzo sta due centimetri più su, si vede da trenta metri.
static func _zoccolo_e_cornice(n: Node3D, pietra: Material, ombra: Material,
		cornice := true) -> void:
	CAT._box(n, Vector3(1.02, 0.18, 0.21), ombra, Vector3(0, 0.09, 0))
	CAT._box(n, Vector3(1.0, 0.035, 0.195), pietra, Vector3(0, 0.185, 0))
	if cornice:
		CAT._box(n, Vector3(1.06, 0.075, 0.225), pietra, Vector3(0, 2.037, 0))
		CAT._box(n, Vector3(1.02, 0.02, 0.205), ombra, Vector3(0, 1.99, 0))


## Un'oscillazione pulita su una traccia: `cicli` andate-e-ritorni dentro la
## lunghezza dell'animazione, interpolata cubica. Due tracce con un numero
## di cicli DIVERSO e primo fra loro non si richiudono mai insieme dentro il
## giro: è così che si ottengono gli orologi incommensurabili (un sin() puro
## si smaschera in due cicli) restando dentro un AnimationPlayer in loop,
## che è tutto quello che un pezzo piazzato può avere.
static func _ondeggia(anim: Animation, percorso: String, cicli: int,
		a: float, b: float) -> void:
	var tr := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(tr, NodePath(percorso))
	var passi := cicli * 2
	for k in passi + 1:
		anim.track_insert_key(tr, anim.length * float(k) / float(passi),
				a if k % 2 == 0 else b)
	anim.track_set_interpolation_type(tr, Animation.INTERPOLATION_CUBIC)


# ------------------------------------------------------------- LA VETRATA

## LA VETRATA. L'unica cosa in tutto il gioco che fa entrare luce COLORATA
## in una stanza, e il pezzo che si compra il fianco della chiesa: una casa
## ha UNA finestra per stanza, una chiesa RIPETE la stessa finestra stretta
## lungo tutti e due i fianchi. È il ritmo, non il vetro, che l'occhio legge
## come «sacro» prima di saperlo nominare — perciò questo pezzo non ha
## nessuna variante storta: venti vetrate in fila devono essere venti volte
## la stessa vetrata.
##
## Tre cose non si toccano:
##  · GLI SGUANCI. I due lati dell'apertura si aprono verso l'interno di
##    ~13°. Sono l'unica cosa che fa SENTIRE lo spessore del muro: senza,
##    il vetro è una toppa incollata sull'intonaco.
##  · L'ORDINE IN PROFONDITÀ. Vetro dietro, piombi davanti al vetro, arco e
##    traverse di ferro davanti a tutto (lezione della finestrella della
##    guardiola: un architrave messo DAVANTI tappa la finestra invece di
##    incorniciarla).
##  · NIENTE LETTERE nella lunetta. Una figurina a tre colori piatti — una
##    rondine — perché il testo dipinto su una mesh non si traduce in
##    inglese, e questo gioco è bilingue.
static func vetrata() -> Node3D:
	var n := Node3D.new()
	var pietra := CAT._mat(PIETRA_CHIARA, PIETRA_OMBRA, 3.0, 0.5)
	var ombra := CAT._mat(PIETRA_OMBRA, PIETRA_OMBRA.darkened(0.16), 3.5, 0.5)
	# il corso alternato: appena appena più scuro. La differenza dev'essere
	# quasi invisibile da vicino e sparire del tutto da lontano — serve solo
	# a rompere la superficie, non a disegnarci sopra delle righe.
	var corso_b := CAT._mat(PIETRA_CHIARA.darkened(0.055), PIETRA_OMBRA, 3.5, 0.5)
	var chiave := CAT._mat(PIETRA_ROSATA, PIETRA_OMBRA, 3.0, 0.45)
	# lo sguancio è più chiaro del muro: è la faccia che raccoglie la luce
	# che entra, e schiarirla è metà dell'effetto «il muro è spesso»
	var interno := CAT._mat(PIETRA_CHIARA.lightened(0.12), PIETRA_CHIARA, 3.0, 0.4)
	var pb := piombo()
	var ferro := _ferro_battuto()

	# le quote del vano, tutte insieme perché è l'unico posto in cui contano
	var meta := 0.19      # mezza luce dell'apertura
	var davanzale := 0.74
	var imposta := 1.62   # da qui in su è arco: cade su un confine di corso
	var spess_arco := 0.085

	_zoccolo_e_cornice(n, pietra, ombra)
	_corsi(n, pietra, corso_b, 0.18, imposta, 1.0, meta, davanzale, imposta)
	# i rinfianchi e il cielo dell'arco. Partono da |x| = 0.19 (la luce) e
	# non dall'estradosso: la corona di conci copre esattamente il cuneo che
	# resta scoperto, e siccome l'arco è più PROFONDO del muro (0.20 contro
	# 0.16) le facce non sono mai complanari — niente z-fighting.
	for s: float in [-1.0, 1.0]:
		CAT._box(n, Vector3(0.31, 0.24, 0.156), pietra,
				Vector3(s * 0.345, 1.74, 0))
	CAT._box(n, Vector3(1.0, 0.14, 0.164), ombra, Vector3(0, 1.93, 0))

	# IL DAVANZALE: una pietra sola, lunga, che sporge e chiude il muro
	# sotto il vano (il corso spezzato lì sotto si ferma a 0.66)
	var soglia := CAT._box(n, Vector3(0.62, 0.10, 0.225), pietra,
			Vector3(0, 0.69, -0.01))
	soglia.rotation.x = 0.05   # il gocciolatoio: l'acqua deve cadere via
	CAT._box(n, Vector3(0.56, 0.022, 0.20), ombra, Vector3(0, 0.632, -0.02))

	# GLI SGUANCI: dal filo esterno (|x| 0.19, z -0.078) al filo interno
	# (|x| 0.227, z +0.078). Il box è lungo quanto la diagonale e girato di
	# atan(0.037/0.156) ≈ 0.23 rad attorno a Y.
	for s: float in [-1.0, 1.0]:
		var sg := CAT._box(n, Vector3(0.03, 0.88, 0.165), interno,
				Vector3(s * 0.2085, 1.18, 0))
		sg.rotation.y = s * 0.23

	# IL CAMPO DI VETRI: 2 x 4 riquadri, e UNA TINTA CHE COMANDA.
	# La prima versione aveva rosso, giallo e blu in parti uguali a scacco:
	# da sei metri usciva un MONDRIAN — otto quadretti primari che gridano,
	# nessuna vetrata. Una vetrata vera è quasi tutta di un colore (qui il
	# cobalto, che è anche il colore del cielo di questo gioco) con due o tre
	# tessere calde che accendono il campo. Il rubino sta in basso a destra,
	# dove l'occhio arriva per ultimo e si ferma.
	var fondo := vetro(VETRO_COBALTO, 0.45)
	var caldo := vetro(VETRO_AMBRA, 0.5)
	var cuore := vetro(VETRO_RUBINO, 0.5)
	var trama: Array[Material] = [fondo, fondo, caldo, fondo,
			fondo, cuore, fondo, caldo]
	for r in 4:
		for c in 2:
			CAT._box(n, Vector3(0.17, 0.20, 0.02), trama[r * 2 + c],
					Vector3(-0.10 + 0.20 * float(c), 0.86 + 0.22 * float(r), -0.03))
	# la lunetta: un disco intero, di cui si vede solo la metà alta (sotto
	# c'è già il campo di vetri, e la bacchetta d'imposta nasconde la
	# giunzione — è come sono fatte le vetrate vere).
	# NON bianco latte: un disco chiaro incastonato in un arco di pietra
	# chiara si legge come una NUVOLA appoggiata al muro (provato a schermo:
	# sembrava fumo). Ambra, che è il colore della luce che entra.
	var disco := CAT._cyl(n, 0.185, 0.185, 0.016, vetro(VETRO_AMBRA, 0.75),
			Vector3(0, imposta, -0.026))
	disco.rotation.x = PI * 0.5

	# LA RONDINE della lunetta: tre colori piatti, nessuna lettera. È la
	# stessa rondine della banderuola in cima al campanile: in una chiesa
	# senza credo, il segno che si ripete è quello che parte e torna.
	# Va in piombo e non in vetro scuro: dentro l'ambra deve essere una
	# SAGOMA, come sono sagome tutte le figure delle vetrate vere.
	CAT._ball(n, 0.045, pb, Vector3(0, 1.715, -0.024), Vector3(1.0, 0.62, 0.16))
	var ala := CAT._box(n, Vector3(0.15, 0.032, 0.014), pb, Vector3(0.02, 1.745, -0.023))
	ala.rotation.z = 0.62
	for v: float in [-1.0, 1.0]:
		var coda := CAT._box(n, Vector3(0.075, 0.018, 0.014), pb,
				Vector3(-0.065, 1.70, -0.023))
		coda.rotation.z = 0.34 * v
	CAT._box(n, Vector3(0.035, 0.02, 0.012), vetro(VETRO_RUBINO, 0.7),
			Vector3(0.042, 1.70, -0.022))

	# I PIOMBI. Senza di loro una vetrata è una tovaglia a quadretti: sono
	# LORO il disegno, e vanno GROSSI — a un centimetro spariscono da tre
	# metri e i vetri tornano a essere piastrelle. Due montanti sui filetti,
	# uno in mezzo, tre traverse sui giunti e la bacchetta d'imposta.
	for x: float in [-0.178, 0.0, 0.178]:
		CAT._box(n, Vector3(0.02, 0.88, 0.018), pb, Vector3(x, 1.18, -0.052))
	for y: float in [0.97, 1.19, 1.41]:
		CAT._box(n, Vector3(0.38, 0.018, 0.018), pb, Vector3(0, y, -0.052))
	CAT._box(n, Vector3(0.40, 0.022, 0.02), pb, Vector3(0, imposta, -0.052))
	# i due raggi della lunetta: la dividono in tre spicchi, e sono quelli
	# che le tolgono l'aria di oblò
	for a: float in [0.7, PI - 0.7]:
		var raggio := CAT._box(n, Vector3(0.018, 0.185, 0.018), pb,
				Vector3(cos(a) * 0.09, imposta + sin(a) * 0.09, -0.052))
		raggio.rotation.z = a - PI * 0.5

	# L'ARCO A TUTTO SESTO, sette conci, con la chiave di pietra rosata: è
	# il pezzo che si ripete in tutto il set, e la chiave è l'unica licenza
	# di colore che questo muro si concede.
	arco_conci(n, pietra, chiave, meta, spess_arco, 0.20, 7,
			Vector3(0, imposta, 0))

	# LE TRAVERSE DI FERRO, davanti a tutto: sono le barrette che hanno
	# tutte le vetrate vere, e nessuno le nota finché non ci sono.
	for y: float in [1.00, 1.38]:
		CAT._box(n, Vector3(0.50, 0.016, 0.016), ferro, Vector3(0, y, -0.095))

	# due dettagli e basta: un concio più sporgente (la pietra che il
	# muratore non ha squadrato) e un dito di muschio sullo zoccolo, dove
	# l'acqua ristagna
	CAT._box(n, Vector3(0.19, 0.24, 0.176), pietra, Vector3(-0.40, 0.54, 0))
	CAT._ball(n, 0.07, CAT._mat(CAT.LEAF.darkened(0.25), PIETRA_OMBRA, 7.0, 0.6),
			Vector3(0.33, 0.20, -0.10), Vector3(1.4, 0.28, 0.5))
	return n


# ------------------------------------------------------------- IL SAGRATO

## IL SAGRATO. Metà della vita di una chiesa di paese succede sui suoi
## scalini: non si entra mai a filo della strada, si sale di due gradini e
## sotto i piedi il terreno cambia. È il pavimento più calpestato del
## villaggio — la tela dei sentieri consumati ci lavorerà sopra da sé — e il
## miglior candidato del paese a diventare un Posto di Sempre.
##
## Parente del Sentiero ma SQUADRATO: lastroni, non ciottoli. Le due regole
## che lo separano da un marciapiede sono la varietà di grigi (tutte le
## lastre della stessa tinta = cemento) e le fughe di terra con l'erba che
## ci cresce: le lastre non si toccano mai, ed è il buio fra l'una e
## l'altra a farle leggere come pietre e non come un disegno.
static func sagrato() -> Node3D:
	var n := Node3D.new()
	var terra := CAT._mat(PIETRA_TERRA, PIETRA_TERRA.darkened(0.3), 5.0, 0.55)
	var tinte: Array[Material] = [
		CAT._mat(PIETRA_FREDDA, PIETRA_FREDDA_CUPA, 3.0, 0.5),
		CAT._mat(PIETRA_FREDDA_CUPA, PIETRA_FREDDA_CUPA.darkened(0.15), 3.5, 0.5),
		CAT._mat(PIETRA_CHIARA, PIETRA_OMBRA, 3.0, 0.5),
		CAT._mat(PIETRA_ROSATA, PIETRA_ROSATA.darkened(0.18), 3.5, 0.5),
	]
	# il letto di terra battuta: si vede solo nelle fughe, ed è lui a dare
	# il buio che fa staccare le lastre
	CAT._box(n, Vector3(1.0, 0.062, 1.0), terra, Vector3(0, 0.031, 0))

	# otto lastroni, scritti a mano uno per uno: un rumore casuale dà otto
	# lastre tutte «un po' storte uguale», una tabella dà una pavimentazione
	# che qualcuno ha POSATO — la grande davanti alla porta, le strette sui
	# fianchi, quella rosata fuori posto.
	# x, z, larghezza, profondità, giro, tinta, ottagonale
	var lastre := [
		[-0.30, -0.31, 0.36, 0.33, 0.045, 0, false],
		[0.10, -0.32, 0.40, 0.31, -0.03, 2, false],
		[0.38, -0.27, 0.19, 0.39, 0.06, 1, false],
		[-0.35, 0.04, 0.26, 0.37, -0.05, 1, false],
		[0.36, 0.07, 0.23, 0.40, -0.04, 3, false],
		[-0.27, 0.37, 0.42, 0.22, 0.035, 2, false],
		[0.21, 0.37, 0.48, 0.24, -0.02, 0, true],
		[0.02, 0.03, 0.44, 0.38, 0.015, 0, false],  # la lastra dell'asse
	]
	for l in lastre:
		var x: float = l[0]
		var z: float = l[1]
		var largo: float = l[2]
		var fondo: float = l[3]
		var mat: Material = tinte[int(l[5])]
		# la lastra sull'asse è CONSUMATA: sta un pelo più bassa, perché è
		# quella su cui passa tutto il paese. È il dettaglio che l'occhio
		# non nota e il piede sì.
		var consumata: bool = absf(x) < 0.06
		var y: float = 0.058 if consumata else 0.062
		var mi: MeshInstance3D
		if bool(l[6]):
			# la lastra ottagonale: un cilindro a otto lati è TONDO in x e in
			# z, quindi la profondità va data schiacciando il nodo — senza,
			# questa lastra esce larga come lunga e sborda dalla cella
			mi = cono_lati(n, largo * 0.5, largo * 0.52, 0.06, 8, mat,
					Vector3(x, y, z))
			mi.scale.z = fondo / largo
		else:
			mi = CAT._box(n, Vector3(largo, 0.06, fondo), mat, Vector3(x, y, z))
		mi.rotation.y = float(l[4])
		if consumata:
			# la conca: una lente appena più scura al centro della lastra,
			# lì dove il passo ha portato via la pelle della pietra
			CAT._ball(n, 0.14, tinte[1], Vector3(x, 0.082, z - 0.02),
					Vector3(1.0, 0.055, 0.85))

	# IL LABBRO DEL GRADINO sul bordo -Z: uno spigolo vivo non è mai stato
	# uno scalino, è una lastra tagliata. Il naso è un mezzo cilindro
	# coricato, ed è la parte che si consuma per prima.
	CAT._box(n, Vector3(1.0, 0.09, 0.09), tinte[1], Vector3(0, 0.045, -0.455))
	# IL NASO SI CHIUDE A CALOTTA ALLE DUE ESTREMITÀ. Un cilindro tagliato
	# netto mostra il TAPPO, e il tappo di un cilindro è un ventaglio di
	# triangoli che parte dal centro: di tre quarti, all'angolo del sagrato,
	# si vedeva una raggiera di spicchi appuntiti invece di uno spigolo
	# consumato. Due mezze sfere dello stesso raggio e il cordolo finisce
	# come finisce la pietra vera.
	var naso := CAT._cyl(n, 0.032, 0.032, 0.94, tinte[2], Vector3(0, 0.072, -0.474))
	naso.rotation.z = PI * 0.5
	for sx: float in [-0.47, 0.47]:
		CAT._ball(n, 0.032, tinte[2], Vector3(sx, 0.072, -0.474))

	# l'erba che vince nelle fughe (dove il piede non arriva: agli angoli) e
	# due sassolini portati dalle scarpe
	var erba := CAT._mat(CAT.LEAF, CAT.LEAF.darkened(0.3), 6.0, 0.55)
	CAT._cyl(n, 0.0, 0.035, 0.09, erba, Vector3(-0.44, 0.10, 0.20)).rotation.z = 0.2
	CAT._cyl(n, 0.0, 0.028, 0.07, erba, Vector3(0.44, 0.09, -0.06)).rotation.z = -0.18
	CAT._ball(n, 0.022, tinte[1], Vector3(-0.06, 0.075, -0.42), Vector3(1, 0.6, 1))
	CAT._ball(n, 0.016, tinte[0], Vector3(0.28, 0.072, 0.21), Vector3(1, 0.6, 1))

	# la soglia: il punto dove ci si ferma un attimo prima di entrare, e
	# dove si resta a parlare dopo. Un ancoraggio nominato, non una
	# costante ricopiata in due file, per chi verrà a farci stare la gente.
	var soglia := Node3D.new()
	soglia.name = "Soglia"
	soglia.position = Vector3(0, 0.092, -0.18)
	n.add_child(soglia)
	return n


# ------------------------------------------------------------ IL FRONTONE

## IL FRONTONE. È il pezzo che separa una chiesa da un capannone con una
## croce sopra: la facciata «a vento» delle chiese povere vere, un muro che
## sale sopra la linea dei tetti e che dietro non ha niente.
##
## Parte come gli altri muri (stesso zoccolo, stessi corsi, stessa cornice a
## 2.0: in fila devono combaciare) e invece di fermarsi lì sale in timpano
## fino a 3.0. Il timpano è fatto di CORSI che si accorciano — un triangolo
## liscio è un cartone ritagliato, una scaletta di pietre è un muro — e i
## gradini se li mangia la cornice degli spioventi.
##
## Attenzione al segno delle falde: con s = -1/+1, rotation.z = -s * angolo.
## Sbagliarlo fa una V al posto di una punta e NESSUN errore lo dice.
##
## Il rosone non è un disco appiccicato: è una STROMBATURA, un imbuto di
## pietra profondo sei centimetri col buio in fondo. E al centro non c'è un
## simbolo di fede — questo mondo non ne ha — c'è un cuore di vetro rosso:
## il Filo Rosso, che è la cosa in cui questo villaggio crede davvero.
static func frontone() -> Node3D:
	var n := Node3D.new()
	var pietra := CAT._mat(PIETRA_CHIARA, PIETRA_OMBRA, 3.0, 0.5)
	var ombra := CAT._mat(PIETRA_OMBRA, PIETRA_OMBRA.darkened(0.16), 3.5, 0.5)
	# (vedi la Vetrata: il corso alternato è quasi identico al primo, o il
	# muro esce a righe da tenda da sole)
	var corso_b := CAT._mat(PIETRA_CHIARA.darkened(0.055), PIETRA_OMBRA, 3.5, 0.5)
	var buio := CAT._mat(Color("241f1a"), Color("15120f"), 4.0, 0.25)

	_zoccolo_e_cornice(n, pietra, ombra)
	_corsi(n, pietra, corso_b, 0.18, 2.0, 1.0)

	# IL TIMPANO a corsi calanti. La larghezza si prende a metà corso: così
	# metà gradino sporge e metà rientra rispetto allo spiovente, e la
	# cornice (spessa 0.14) li copre tutti senza lasciar vedere il cielo.
	var y := 2.0
	var i := 0
	while y < 2.90:
		var larg := 3.0 - (y + 0.06)
		var scuro: bool = i % 2 == 1
		CAT._box(n, Vector3(larg, 0.12, 0.164 if scuro else 0.156),
				corso_b if scuro else pietra, Vector3(0, y + 0.06, 0))
		y += 0.12
		i += 1
	# la punta, e l'acroterio che la chiude (un timpano che finisce a
	# spigolo vivo sembra tagliato con le forbici)
	CAT._box(n, Vector3(0.14, 0.10, 0.16), pietra, Vector3(0, 2.93, 0))
	CAT._ball(n, 0.052, pietra, Vector3(0, 2.99, 0), Vector3(1.0, 1.25, 0.85))

	# LE FALDE: cornice di pietra lungo i due spioventi, che sporge oltre il
	# muro (0.24 contro 0.16) — è l'ombra sotto questa sporgenza a disegnare
	# la sagoma del frontone contro il cielo, di sera.
	# ATTENZIONE AL SEGNO: la falda di destra deve SCENDERE verso destra.
	# Con s = -1/+1 → rotation.z = -s * angolo; l'angolo è quello dello
	# spiovente, atan2(1.0, 0.5) = 1.107 su un timpano alto quanto è largo.
	# La lunghezza (1.16) è tarata perché il piede della cornice arrivi alla
	# gronda senza invadere la cella accanto: allungarla la porta addosso al
	# pezzo vicino.
	for s: float in [-1.0, 1.0]:
		var falda := CAT._box(n, Vector3(1.16, 0.14, 0.24), pietra,
				Vector3(s * 0.2504, 2.504, 0))
		falda.rotation.z = -s * 1.107
		# I DENTELLI sotto la gronda: sono LORO a far sembrare la facciata
		# costruita invece che estrusa. Quattro per falda bastano; otto
		# diventano una dentiera.
		for k in 4:
			var t := 0.32 + 0.22 * float(k)
			var mens := CAT._box(n, Vector3(0.055, 0.06, 0.215), ombra,
					Vector3(s * (0.4472 * t - 0.103), 2.955 - 0.8944 * t, 0))
			mens.rotation.z = -s * 1.107

	# LA STROMBATURA DEL ROSONE: imbuto svasato verso fuori (bottom_radius è
	# il lato -Z dopo la rotazione di PI*0.5 su X) e il buio in fondo. Senza
	# questi sei centimetri di profondità il rosone è uno sticker.
	# IL ROSONE STA TUTTO SOPRA LA CORNICE. Prima era centrato a 2.14 con
	# raggio 0.23: la cornice del muro, che corre a 2.0, gli passava DAVANTI
	# a un quarto d'altezza e da fuori sembrava una mensola piantata in
	# mezzo alla vetrata. Alzato a 2.28 e stretto a 0.17, il vetro comincia
	# a 2.11 (la cornice non lo sfiora) e l'anello arriva a 2.50, dove il
	# timpano e ancora largo 0.44: giusto giusto, senza sbordare.
	var cono := CAT._cyl(n, 0.19, 0.222, 0.06, ombra, Vector3(0, 2.28, -0.05))
	cono.rotation.x = PI * 0.5
	# il buio in fondo è più STRETTO dei petali (0.20 contro 0.23): largo
	# uguale se li mangia, e da lontano il rosone diventa un buco nero con
	# un anello attorno
	var fondo := CAT._cyl(n, 0.148, 0.148, 0.02, buio, Vector3(0, 2.28, -0.01))
	fondo.rotation.x = PI * 0.5

	# IL ROSONE: dodici petali (sotto i dieci è una ruota di carro, sopra i
	# quattordici è poltiglia), tre tinte che girano, e il cuore rosso.
	# (i raggetti vanno in PIOMBO, non in pietra: sono le bacchette che
	# tengono i vetri, e in pietra chiara il rosone diventa una ruota da
	# mulino invece che una trina)
	rosa(n, 12, 0.17,
			[vetro(VETRO_AMBRA, 0.8), vetro(VETRO_COBALTO, 0.9),
			vetro(VETRO_SMERALDO, 0.75)],
			piombo(), vetro(VETRO_RUBINO, 1.0), Vector3(0, 2.28, -0.062))
	# l'anello di pietra: TorusMesh con rotation.x = PI*0.5, SEMPRE, o lo si
	# vede di taglio e sparisce. Copre anche il bordo dell'imbuto.
	var anello := TorusMesh.new()
	anello.inner_radius = 0.181
	anello.outer_radius = 0.222
	anello.rings = 26
	anello.ring_segments = 8
	var am := MeshInstance3D.new()
	am.mesh = anello
	am.material_override = pietra
	am.position = Vector3(0, 2.28, -0.085)
	am.rotation.x = PI * 0.5
	n.add_child(am)

	# il nido di rondine sotto la gronda: due nodi, e la facciata smette di
	# essere un monumento e diventa un posto dove abita qualcuno
	# di TERRA, non di pietra schiarita: col colore del muro si vedeva solo
	# il buco dentro, e sembrava un foro nella facciata invece di un nido
	CAT._ball(n, 0.082, CAT._mat(PIETRA_TERRA, PIETRA_TERRA.darkened(0.25), 6.0, 0.55),
			Vector3(0.33, 2.42, -0.115), Vector3(1.0, 0.66, 0.75))
	CAT._ball(n, 0.026, buio, Vector3(0.33, 2.43, -0.155), Vector3(1.0, 0.5, 0.4))
	return n


# ----------------------------------------------------------- IL CANDELIERE

## IL CANDELIERE. È il motivo per cui questa chiesa esiste in Chibi
## Crossing: il villaggio sa già salutare, regalare, consolare, aspettare —
## e non ha un verbo per RINGRAZIARE, men che meno chi non c'è più.
##
## REGOLA DI TONO, la più importante di tutto il set: accendere non muove
## NESSUN contatore. Non dà bonus, non registra chi è venuto, e soprattutto
## non accorcia il lutto. Se un giorno qualcuno ci attacca una ricompensa,
## il pezzo è morto: la sua unica funzione è dare il permesso di stare lì.
##
## Quello che lo fa vero, in ordine di quanto si nota:
##  · LE CANDELE SONO TUTTE DIVERSE. Qualcuna è un mozzicone, una è nuova,
##    tre bussole sono vuote (qualcuno deve ancora venire). Dodici fiammelle
##    uguali e allineate sono una torta di compleanno.
##  · LE FIAMME RESPIRANO CON OROLOGI DIVERSI. Quattro (o tre) cicli dentro
##    lo stesso giro: non si richiudono mai insieme, e l'occhio non trova
##    il loop.
##  · LA CERA COLATA e la lastra annerita dal calore di anni: dicono che il
##    lume è acceso da prima che arrivasse il giocatore.
static func candeliere() -> Node3D:
	var n := Node3D.new()
	# il ferro del candeliere è più CHIARO di quello delle inferriate: nero
	# pieno, contro il prato, il pezzo diventa la sagoma di un lampione — e
	# un lampione non lo accende nessuno per qualcuno che non c'è più
	var ferro := CAT._mat(Color("6a6157"), Color("484138"), 6.0, 0.4)
	var ottone := CAT._mat(CAT.OTTONE, CAT.OTTONE_SCURO, 5.0, 0.4)
	var cera := CAT._mat(Color("f4e7cc"), Color("dcc9a4"), 4.0, 0.35)
	var sabbia := CAT._mat(Color("cbb894"), Color("a8926c"), 5.0, 0.5)
	var ardesia := CAT._mat(Color("4a4c50"), Color("35373b"), 4.0, 0.4)
	var gesso := CAT._mat(Color("efeadd"), Color("d8d2c2"), 6.0, 0.2)

	# LE TRE GAMBE, curve: un treppiede di bastoni dritti è un cavalletto,
	# la curva è quella che dà il ferro battuto a caldo.
	for i in 3:
		var a := TAU * float(i) / 3.0 + 0.4
		BUILDER.tube(n, [Vector3(0, 0.15, 0),
				Vector3(cos(a) * 0.085, 0.062, sin(a) * 0.085),
				Vector3(cos(a) * 0.165, 0.027, sin(a) * 0.165)],
				[0.019, 0.016, 0.026], ferro, 12, 7)
	# lo stelo: NON dritto. Due millimetri di serpeggio e un nodo a metà, ed
	# è battuto a mano invece che tornito.
	BUILDER.tube(n, [Vector3(0, 0.10, 0), Vector3(0.013, 0.30, 0.005),
			Vector3(-0.009, 0.50, 0), Vector3(0, 0.685, 0)],
			[0.026, 0.019, 0.019, 0.028], ferro, 20, 9)
	CAT._ball(n, 0.036, ferro, Vector3(0.006, 0.36, 0.002), Vector3(1, 0.7, 1))

	# IL VASSOIO: concavo (una lastra piatta non tiene la sabbia) e OVALE,
	# perché il pezzo è largo e poco profondo. L'ovale si ottiene schiacciando
	# in Z il nodo che contiene le due superfici di rivoluzione — le candele
	# NON stanno qui dentro, o si schiaccerebbero anche loro.
	var vassoio := Node3D.new()
	vassoio.position = Vector3(0, 0.70, 0)
	vassoio.scale = Vector3(1.0, 1.0, 0.58)
	n.add_child(vassoio)
	BUILDER.lathe(vassoio, [
		Vector2(0.0, -0.022), Vector2(0.10, -0.030), Vector2(0.19, -0.014),
		Vector2(0.243, 0.012), Vector2(0.252, 0.036),
	], ferro, Vector3.ZERO, 26)
	BUILDER.lathe(vassoio, [
		Vector2(0.0, -0.006), Vector2(0.10, -0.012), Vector2(0.19, 0.002),
		Vector2(0.232, 0.018),
	], sabbia, Vector3.ZERO, 24)

	# DODICI BUSSOLE SU DUE FILE SFALSATE. In fila unica sono i tasti di una
	# fisarmonica; sfalsate diventano un vassoio su cui la gente ha messo
	# candele quando ne aveva voglia.
	# x, z, lunghezza (0 = bussola vuota, qualcuno deve ancora venire), accesa
	var posti := [
		[-0.175, -0.055, 0.14, true], [-0.105, -0.055, 0.05, false],
		[-0.035, -0.055, 0.10, true], [0.035, -0.055, 0.0, false],
		[0.105, -0.055, 0.16, true], [0.175, -0.055, 0.04, false],
		[-0.210, 0.055, 0.08, false], [-0.140, 0.055, 0.12, true],
		[-0.070, 0.055, 0.0, false], [0.0, 0.055, 0.03, false],
		[0.070, 0.055, 0.09, false], [0.140, 0.055, 0.0, false],
	]
	var accese := 0
	for p in posti:
		var x: float = p[0]
		var z: float = p[1]
		var lung: float = p[2]
		CAT._cyl(n, 0.019, 0.023, 0.02, ottone, Vector3(x, 0.723, z))
		if lung <= 0.0:
			continue
		CAT._cyl(n, 0.0145, 0.016, lung, cera, Vector3(x, 0.733 + lung * 0.5, z))
		if not bool(p[3]):
			continue
		# la fiamma sta in un nodo MIO, non in quello dell'helper: così il
		# respiro moltiplica la sua scala invece di sovrascriverla, qualunque
		# cosa faccia fiamma() con la propria.
		var culla := Node3D.new()
		culla.name = "Fiamma%d" % accese
		culla.position = Vector3(x, 0.735 + lung, z)
		n.add_child(culla)
		fiamma(culla, Vector3.ZERO, 0.85 + 0.12 * float(accese % 2))
		accese += 1

	# LA CERA COLATA: gocce vere che scendono dal bordo della candela e
	# pozze sul vassoio. È il dettaglio che dice «acceso da anni» meglio di
	# qualunque texture.
	for g in [[-0.175, -0.055, 0.840, 2.6], [0.105, -0.055, 0.822, 3.4],
			[-0.140, 0.055, 0.790, 2.1]]:
		CAT._ball(n, 0.010, cera,
				Vector3(float(g[0]) + 0.014, float(g[2]), float(g[1])),
				Vector3(1.0, float(g[3]), 1.0))
	for pozza in [[-0.16, -0.05], [0.12, -0.05], [-0.09, 0.055]]:
		CAT._ball(n, 0.032, cera, Vector3(float(pozza[0]), 0.728, float(pozza[1])),
				Vector3(1.0, 0.17, 0.8))

	# LA LASTRA ANNERITA, dietro (a +Z: davanti coprirebbe le fiamme, ed è
	# la lezione del sacco della palestra).
	# (0.42 x 0.20, non 0.54 x 0.26: la prima versione era una lavagna nera
	# larga quanto il vassoio, e in silhouette il pezzo diventava un
	# televisore su un treppiede. La lastra deve essere PIÙ STRETTA delle
	# candele, così le fiamme le escono ai lati.)
	var lastra := CAT._box(n, Vector3(0.42, 0.20, 0.014),
			CAT._mat(Color("7a7168"), Color("4a4239"), 5.0, 0.45),
			Vector3(0, 0.815, 0.145))
	lastra.rotation.x = -0.1
	# l'annerimento NON è dipinto uniforme: è la macchia sopra le fiamme che
	# bruciano da più tempo, ed è più stretta della lastra
	CAT._box(n, Vector3(0.24, 0.11, 0.004), CAT._mat(Color("3a332c"), Color("221d18"), 6.0, 0.4),
			Vector3(-0.02, 0.845, 0.136)).rotation.x = -0.1
	for s: float in [-1.0, 1.0]:
		CAT._cyl(n, 0.007, 0.007, 0.16, ferro, Vector3(s * 0.22, 0.74, 0.12)).rotation.x = -0.35

	# L'ARDESIA COL GESSO: tratti, non lettere (le lettere non si traducono,
	# e questo gioco è bilingue). I segni sono FIGLI dell'ardesia, o alla
	# prima inclinazione il gesso resta a mezz'aria fuori dalla lavagna.
	var slate := Node3D.new()
	slate.position = Vector3(-0.205, 0.645, -0.088)
	slate.rotation = Vector3(-0.22, 0.12, 0.09)
	n.add_child(slate)
	CAT._box(slate, Vector3(0.15, 0.10, 0.012), ardesia, Vector3.ZERO)
	for k in 4:
		var seg := CAT._box(slate, Vector3(0.006, 0.05, 0.004), gesso,
				Vector3(-0.042 + 0.024 * float(k), 0.004, -0.008))
		seg.rotation.z = 0.06 if k % 2 == 0 else -0.05
	var barra := CAT._box(slate, Vector3(0.006, 0.062, 0.004), gesso,
			Vector3(-0.006, 0.004, -0.009))
	barra.rotation.z = 1.15

	# L'UNICA LUCE VERA del set. Calda, corta, e una sola: di questi pezzi
	# il giocatore ne piazza venti, e venti Omni sono venti volte il costo.
	var luce := OmniLight3D.new()
	luce.light_color = Color(1.0, 0.82, 0.55)
	luce.light_energy = 1.0
	luce.omni_range = 4.0
	luce.position = Vector3(0, 0.87, -0.02)
	n.add_child(luce)
	# UN SOLO emettitore per tutto il vassoio, non uno per cero
	CAT._emit_fx(n, Vector3(0, 0.92, 0), Color("ffd49a"), 0.16, 0.05, 10, 2.4, 0.05)

	# IL RESPIRO. Quattro fiamme, due orologi a testa (scala Y e scala X) e
	# nessuna coppia di cicli uguale: 4/3, 5/3, 3/4, 5/4 dentro lo stesso
	# giro da 6.9 s. Non si richiudono mai insieme — e appena si richiudono
	# insieme, l'occhio vede il loop e il lume diventa un'insegna.
	var anim := Animation.new()
	anim.length = 6.9
	anim.loop_mode = Animation.LOOP_LINEAR
	var ritmi := [[4, 3], [5, 3], [3, 4], [5, 4]]
	for f in mini(accese, ritmi.size()):
		var r: Array = ritmi[f]
		_ondeggia(anim, "Fiamma%d:scale:y" % f, int(r[0]), 0.90, 1.14)
		_ondeggia(anim, "Fiamma%d:scale:x" % f, int(r[1]), 1.05, 0.93)
	var lib := AnimationLibrary.new()
	lib.add_animation("respiro", anim)
	var player := AnimationPlayer.new()
	n.add_child(player)
	player.add_animation_library("", lib)
	player.autoplay = "respiro"
	return n


# ----------------------------------------------------------- IL CAMPANILE

## IL CAMPANILE. Il pezzo-àncora: si compra lui e arriva la chiesa intera.
## È l'UNICA verticale del villaggio — 3.6 m alla banderuola, l'eccezione
## deliberata al limite dei tre metri: se un secondo pezzo compete col cielo
## la sagoma del paese muore, e questo è l'unico che ha il permesso.
##
## Le tre cose che lo fanno riconoscere a trenta metri, in controluce, di
## tre quarti (ed è così che va verificato, non di faccia):
##  · LA RASTREMAZIONE. Il fusto si stringe dell'8% salendo. A sezione
##    costante è un silo; e per farlo servono i quattro lati veri di
##    cono_lati, girati di PI*0.25 come la Torretta.
##  · LA CELLA CAMPANARIA BUCATA, col BUIO dentro. Il buio è UN box: è lui
##    che fa staccare il bronzo e che rende «vuota» la cima, che è la cosa
##    che distingue un campanile da un pilastro.
##  · LA GRONDA CHE SPORGE sul tetto a piramide. Un cono liscio a 64 lati è
##    un cappello da strega: gli spigoli sono tutta la differenza.
##
## Niente croce: una banderuola a rondine. E niente luci vere: brilla di
## emissione e basta, perché di questo pezzo ne basta uno per villaggio ma
## sta acceso tutte le notti.
static func campanile() -> Node3D:
	var n := Node3D.new()
	var pietra := CAT._mat(PIETRA_CHIARA, PIETRA_OMBRA, 3.0, 0.5)
	var ombra := CAT._mat(PIETRA_OMBRA, PIETRA_OMBRA.darkened(0.16), 3.5, 0.5)
	var chiave := CAT._mat(PIETRA_ROSATA, PIETRA_OMBRA, 3.0, 0.45)
	var intonaco := CAT._mat(CAT.PLASTER, CAT.PLASTER_SHADE, 2.5, 0.5)
	var coppo := CAT._mat(CAT.TERRACOTTA, Color("c07a58"), 3.5, 0.5)
	# IL BRONZO È EMISSIVO, appena: dentro la cella non entra nessuna luce
	# (il buio è un box) e con un materiale normale la campana spariva in
	# ombra — cioè spariva l'unica cosa per cui esiste un campanile. Niente
	# luci vere: brilla di emissione e basta.
	var bronzo := CAT._glow(CAT.OTTONE, CAT.OTTONE_SCURO, 0.25)
	var buio := CAT._mat(Color("221e1a"), Color("14110e"), 4.0, 0.25)
	var legno := CAT._mat(LEGNO_FUMO, CAT.WOOD_DARK, 4.0, 0.5)
	var canapa := CAT._mat(CAT.WOOD_PALE, CAT.WOOD, 6.0, 0.4)
	var ferro := _ferro_battuto()

	# LO ZOCCOLO: nessuna torre di paese nasce dall'erba nuda
	CAT._box(n, Vector3(0.94, 0.16, 0.94), ombra, Vector3(0, 0.08, 0))
	CAT._box(n, Vector3(0.88, 0.05, 0.88), pietra, Vector3(0, 0.185, 0))

	# IL FUSTO rastremato: quattro lati veri (cono_lati) girati di PI*0.25,
	# raggio = mezzo lato per radice di due. Da 0.80 di lato a 0.736: l'8%.
	var fusto := cono_lati(n, 0.5204, 0.5657, 2.29, 4, intonaco,
			Vector3(0, 1.355, 0))
	fusto.rotation.y = PI * 0.25

	# I CONCI D'ANGOLO, appena sporgenti e sfalsati in altezza: sono la
	# cosa che dice «pietra sotto l'intonaco». Seguono la rastremazione, o
	# a mezza altezza galleggiano staccati dal muro.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			for k in 3:
				var q := 0.44 + 0.66 * float(k) + (0.14 if sx * sz < 0.0 else 0.0)
				var m := _meta_fusto(q) - 0.055
				CAT._box(n, Vector3(0.17, 0.22, 0.17), pietra,
						Vector3(sx * m, q, sz * m))

	# LA CORNICE MARCAPIANO a 1.45: la quota che si allinea coi Muri di
	# pietra della navata. È lei a legare la torre all'edificio invece di
	# lasciarla piantata accanto.
	CAT._box(n, Vector3(0.90, 0.07, 0.90), pietra, Vector3(0, 1.45, 0))
	CAT._box(n, Vector3(0.86, 0.03, 0.86), ombra, Vector3(0, 1.50, 0))

	# LA PORTELLA ad arco, cinque conci. Parte SOPRA lo zoccolo (0.20): a
	# quota zero la porta finirebbe sepolta nella pietra di base, che è
	# alta sedici centimetri e sporge più del muro. Il buio dentro è un
	# box solo, e si ferma a 0.70 perché i suoi spigoli alti devono restare
	# sotto la corona dei conci: lì non si vedono mai.
	CAT._box(n, Vector3(0.30, 0.50, 0.05), buio, Vector3(0, 0.45, -0.392))
	arco_conci(n, pietra, chiave, 0.15, 0.07, 0.10, 5, Vector3(0, 0.58, -0.398))
	var anta := CAT._box(n, Vector3(0.27, 0.52, 0.04), legno, Vector3(0, 0.46, -0.404))
	anta.rotation.z = 0.012   # l'unica storta concessa: la porta, non il muro
	for y: float in [0.30, 0.62]:
		CAT._box(n, Vector3(0.28, 0.03, 0.012), ferro, Vector3(0, y, -0.427))
	var maniglia := CAT._cyl(n, 0.026, 0.026, 0.012, ferro, Vector3(0.09, 0.46, -0.43))
	maniglia.rotation.x = PI * 0.5
	# la soglia consumata, appoggiata sul cappello dello zoccolo
	CAT._box(n, Vector3(0.34, 0.03, 0.11), ombra, Vector3(0, 0.222, -0.45))

	# LA CORDA. Scende fino a 0.55: altezza di chibi, si tira davvero. Vive
	# in un nodo col pivot in alto, così il suo respiro parte da dove è
	# legata e non dal pavimento. Sta a -0.47 e non a filo di muro: più
	# vicina, passerebbe DENTRO la cornice marcapiano a 1.45.
	CAT._box(n, Vector3(0.05, 0.05, 0.13), ferro, Vector3(0.14, 2.44, -0.40))
	# la corda è VIVA e pende da un capo solo: il vento la fa oscillare
	# piano, e chi le passa accanto la scosta col fianco — una corda di
	# campanile ferma come un tubo era la cosa meno chiesa di tutte.
	# Il pomello in punta la segue come appeso.
	var da_c := Vector3(0.14, 2.44, -0.472)
	var corda := CAT._corda_viva(n, da_c, da_c + Vector3(0, -1.89, 0),
			0.0, 0.008, canapa, 1.2, 12, 6, true)
	corda.name = "Corda"
	var pomello := CAT._ball(n, 0.024, canapa, da_c + Vector3(0, -1.90, 0),
			Vector3(1, 1.4, 1))
	pomello.name = "Pomello"
	var meta_c: Dictionary = corda.get_meta("corda")
	meta_c["appesi"] = [{"path": NodePath("../Pomello"), "t": 1.0, "giu": 0.01}]
	corda.set_meta("corda", meta_c)

	# LA CELLA CAMPANARIA. Quattro pilastrini, il buio in mezzo (UN box), e
	# gli archi: sette conci sul fronte, cinque sugli altri tre lati. Quattro
	# archi completi sarebbero quaranta nodi di sola apertura, e tre non si
	# vedono mai insieme.
	CAT._box(n, Vector3(0.88, 0.06, 0.88), pietra, Vector3(0, 2.53, 0))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			CAT._box(n, Vector3(0.13, 0.58, 0.13), pietra,
					Vector3(sx * 0.305, 2.85, sz * 0.305))
	CAT._box(n, Vector3(0.56, 0.56, 0.56), buio, Vector3(0, 2.84, 0))
	for lato in 4:
		var giro := Node3D.new()
		giro.rotation.y = PI * 0.5 * float(lato)
		n.add_child(giro)
		arco_conci(giro, pietra, chiave if lato == 0 else pietra,
				0.17, 0.065, 0.11, 7 if lato == 0 else 5,
				Vector3(0, 2.78, -0.335))
	CAT._box(n, Vector3(0.94, 0.07, 0.94), pietra, Vector3(0, 3.11, 0))
	CAT._box(n, Vector3(0.90, 0.03, 0.90), ombra, Vector3(0, 3.06, 0))

	# LA CAMPANA. Il giogo corre lungo Z (l'asse davanti-dietro) così il
	# bronzo dondola di fianco, che è come lo si vede dal fronte. Tutto
	# quello che si muove sta sotto il nodo «Campana», col pivot SUL giogo:
	# se il pivot scivola al centro della campana, dondola come un pendolo
	# appeso al nulla.
	CAT._box(n, Vector3(0.07, 0.05, 0.50), legno, Vector3(0, 2.98, 0))
	var giogo := Node3D.new()
	giogo.name = "Campana"
	giogo.position = Vector3(0, 2.96, 0)
	n.add_child(giogo)
	CAT._ball(giogo, 0.032, bronzo, Vector3(0, 0.01, 0))
	CAT._cyl(giogo, 0.085, 0.15, 0.22, bronzo, Vector3(0, -0.13, 0))
	CAT._cyl(giogo, 0.165, 0.15, 0.035, bronzo, Vector3(0, -0.255, 0))
	# IL BATTAGLIO in un nodo suo: deve arrivare IN RITARDO. Un battaglio
	# incollato al bronzo è l'adesivo che smaschera tutta la torre.
	var battaglio := Node3D.new()
	battaglio.name = "Battaglio"
	battaglio.position = Vector3(0, -0.055, 0)
	giogo.add_child(battaglio)
	CAT._cyl(battaglio, 0.007, 0.007, 0.15, ferro, Vector3(0, -0.075, 0))
	CAT._ball(battaglio, 0.028, ferro, Vector3(0, -0.165, 0))

	# IL TETTO a piramide di coppi, girato di PI*0.25 come la Torretta, con
	# la gronda che sporge oltre la cornice: è l'ombra della gronda a fare
	# la silhouette contro il cielo.
	var tetto := cono_lati(n, 0.0, 0.70, 0.34, 4, coppo, Vector3(0, 3.32, 0))
	tetto.rotation.y = PI * 0.25

	# IL PERNO E LA BANDERUOLA A RONDINE. Niente croce: questo mondo non ha
	# un credo, ha le partenze e i ritorni — ed è una rondine a raccontarli.
	# La lamiera è sottile in X e lunga in Z, così la banderuola si legge di
	# profilo e sparisce di faccia, come tutte le banderuole vere.
	CAT._cyl(n, 0.013, 0.02, 0.16, ferro, Vector3(0, 3.53, 0))
	var vento := Node3D.new()
	vento.name = "Banderuola"
	vento.position = Vector3(0, 3.55, 0)
	n.add_child(vento)
	CAT._ball(vento, 0.05, ferro, Vector3(0, 0, 0.02), Vector3(0.16, 0.72, 2.2))
	var ala := CAT._box(vento, Vector3(0.012, 0.085, 0.17), ferro, Vector3(0, 0.03, 0.01))
	ala.rotation.x = 0.55
	for v: float in [-1.0, 1.0]:
		var coda := CAT._box(vento, Vector3(0.012, 0.055, 0.12), ferro,
				Vector3(0, 0.006, 0.155))
		coda.rotation.x = 0.42 * v
	CAT._box(vento, Vector3(0.01, 0.02, 0.06), ferro, Vector3(0, -0.004, -0.13))

	# IL MOTO. Tre orologi che non si richiudono insieme: la campana fa un
	# giro, il battaglio lo insegue con 0.9 s di ritardo (è il ritardo a fare
	# il suono anche senza suono), la banderuola gira tre volte più spesso
	# perché il vento non aspetta la campana. La corda respira con la
	# campana, perché è legata a lei.
	var anim := Animation.new()
	anim.length = 4.0
	anim.loop_mode = Animation.LOOP_LINEAR
	_ondeggia(anim, "Campana:rotation:z", 1, -0.055, 0.055)
	_ondeggia(anim, "Corda:rotation:z", 1, 0.012, -0.012)
	_ondeggia(anim, "Banderuola:rotation:y", 3, -0.28, 0.28)
	var tr := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(tr, NodePath("Campana/Battaglio:rotation:z"))
	anim.track_insert_key(tr, 0.0, 0.07)
	anim.track_insert_key(tr, 0.9, -0.10)
	anim.track_insert_key(tr, 2.9, 0.10)
	anim.track_insert_key(tr, 4.0, 0.07)
	anim.track_set_interpolation_type(tr, Animation.INTERPOLATION_CUBIC)
	var lib := AnimationLibrary.new()
	lib.add_animation("dondola", anim)
	var player := AnimationPlayer.new()
	n.add_child(player)
	player.add_animation_library("", lib)
	player.autoplay = "dondola"
	return n


## Mezza sezione del fusto alla quota y: serve ai conci d'angolo, che devono
## seguire la rastremazione. Ricavarla a occhio significa vederli galleggiare
## staccati dal muro a metà altezza — ed è il genere di errore che si nota
## solo di tre quarti, cioè quando è tardi.
static func _meta_fusto(y: float) -> float:
	return lerpf(0.40, 0.368, clampf((y - 0.21) / 2.29, 0.0, 1.0))
