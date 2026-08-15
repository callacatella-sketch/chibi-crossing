extends SceneTree
## GUARDARE LE CRICCHE — un villaggio vero, tante giornate, e le foto.
##
##   CHIBI_FOTO=/dove/le/foto CHIBI_GIORNI=12 CHIBI_ARRIVO=5 CHIBI_MOCHI=1 \
##     ~/Downloads/Godot.app/Contents/MacOS/Godot --path . \
##     --resolution 1280x720 --script res://tools/guarda_cricche.gd
##
## `misura_cricche.gd` conta le righe del registro; `prova_si_trovano.gd`
## prova il momento **seminando** un'abitudine a mano. Nessuno dei due ha
## mai fatto la cosa che decide se questa fase esiste: **far vivere un
## villaggio finché le cricche si formano da sole, e poi GUARDARE.**
##
## ============================================================
## COSA SI SEMINA E COSA NO — la riga che rende onesta questa misura
## ============================================================
## Si semina **il villaggio**: dove stanno le case, dove stanno le panchine,
## dove ci sono i cespugli. È quello che fa un giocatore, ed è l'unica leva
## che CLAUDE.md dichiara («il gruppo a tre è un evento raro, che
## probabilmente lo fa succedere il GIOCATORE mettendo un posto dove tre
## persone convergono»).
##
## **NON si semina una sola riga del registro.** `_incontri` non viene mai
## toccato da questo file: le abitudini nascono da `Visitors._chats`, che è
## il codice di produzione, o non nascono. Se alla fine il referto dice
## «zero cricche», quello È il risultato.
##
## Le tre forme di villaggio sono scelte apposta perché il predicato abbia
## qualcosa da distinguere:
##   LA CORTE    tre case a due metri l'una dall'altra — il posto in cui una
##               cricca può nascere
##   LA FILA     quattro case a tre metri — vicini, ma non addosso
##   LA SPONDA   tre case in fila a due metri: gli estremi NON si toccano
##               (il collaudo di «nessuno entra per catena»)
##   I LONTANI   due case in disparte — **e questi non sono un esperimento
##               sulla solitudine**: sono il caso di controllo che dice se
##               chi non si ritrova con nessuno riceve qualcosa di diverso.
##
## ============================================================
## L'OSSERVATORE — l'unica cosa che questo banco muove
## ============================================================
## Mochi cammina come cammina un giocatore, e alla loro ora va **dove sanno
## di trovarsi**. Non è un trucco: è il gioco. `Visitors._cancelli_gesto`
## pretende il giocatore entro `GESTO_RAGGIO` (9 m), in inquadratura e non
## coperto — un momento che nessuno guarda **non deve** succedere, e infatti
## non succede. Chi non porta lì il giocatore non sta misurando il momento:
## sta misurando la propria assenza.
##
## Un giorno sì e uno no l'osservatore si mette **a 6,5 m** dal loro punto
## (il duetto vuole i due corpi fra 2,2 e 6 m: da lì si prendono in uno
## sguardo) e l'altro giorno **dentro il loro posto** (che è la condizione
## di «ci sei anche tu»). Due mestieri diversi, e nessuno dei due inventa un
## incontro.

const CRICCHE := preload("res://scenes/npc/Cricche.gd")

# ------------------------------------------------------------- il villaggio
const CORTE := [Vector2i(5, -2), Vector2i(7, -2), Vector2i(6, -4)]
const FILA := [Vector2i(3, 6), Vector2i(6, 6), Vector2i(9, 6), Vector2i(12, 6)]
const SPONDA := [Vector2i(3, 10), Vector2i(5, 10), Vector2i(7, 10)]
const LONTANI := [Vector2i(14, -2), Vector2i(14, 10)]
const CASA_NUOVA := Vector2i(6, 0)

## ⚠️ **I POSTI SI TOCCANO, E QUESTA È LA LEVA DEL GIOCATORE.** La prima
## stesura spargeva dieci panchine in quattro angoli: MISURATO, **tre righe
## in una giornata intera** — perché `_chats` guarda entro 1,9 m e due
## panchine a due metri mettono due corpi a due metri, cioè **fuori** per
## dieci centimetri. Un villaggio con le panchine sparse non è un villaggio
## in cui non si fa amicizia: è un villaggio in cui non ci si sfiora mai.
##
## Adesso ci sono TRE ritrovi, ognuno di quattro panchine in celle
## ADIACENTI, e ognuno serve il suo quartiere. Tre e non uno: un unico
## giardino per tutti farebbe una macchia sola di gente che si ritrova con
## tutti — cioè `TETTO_COMPONENTE`, cioè *«un villaggio in cui tutti si
## ritrovano con tutti non ha cricche: ha una piazza»*.
const RITROVO_CORTE := [Vector2i(8, -2), Vector2i(9, -2), Vector2i(8, -3),
		Vector2i(9, -3)]
const RITROVO_FILA := [Vector2i(7, 7), Vector2i(8, 7), Vector2i(7, 8),
		Vector2i(8, 8)]
const RITROVO_SPONDA := [Vector2i(4, 12), Vector2i(5, 12), Vector2i(4, 13),
		Vector2i(5, 13)]
## …e chi sta in disparte ha comunque il suo posto: se gli mancasse una
## panchina, «sta da solo» sarebbe una cosa che gli ha fatto il banco.
const PANCHINE_SOLE := [Vector2i(14, 0), Vector2i(13, 11)]

const PANCHINE := RITROVO_CORTE + RITROVO_FILA + RITROVO_SPONDA \
		+ PANCHINE_SOLE
const CESPUGLI := [
	Vector2i(10, -3), Vector2i(6, 8), Vector2i(3, 13), Vector2i(13, 0),
	Vector2i(12, 11), Vector2i(10, 3),
]
const AIUOLE := [Vector2i(10, -2), Vector2i(6, 7), Vector2i(3, 12)]

## Il centro del villaggio, per la macchina dall'alto. La quota è PROVINATA:
## a 34 m i corpi sono granelli e «le distanze non sono più uniformi» non è
## una domanda che si possa fare a quell'immagine.
const CENTRO := Vector3(8.5, 0.0, 4.5)
const QUOTA_ALTO := 21.0
## I due ritrovi che si fotografano da vicino: quello della corte (dove una
## cricca può nascere) e quello della fila (dove sono in quattro).
const CENTRO_GIARDINO := Vector3(8.5, 0.0, -2.5)
const CENTRO_GIARDINO2 := Vector3(7.5, 0.0, 7.5)
const QUOTA_GIARDINO := 11.0
const CLEARING := Vector3(-1.0, 0.0, -46.0)

## Gli stati in cui un corpo è fermo (la stessa lista di
## `Visitors.STATI_A_RIPOSO`, letta da lì: ricopiarla vorrebbe dire misurare
## una definizione di «fermo» che il gioco non usa).
const A_RIPOSO := ["r_idle", "r_wander", "r_fire", "r_bench", "r_sniff"]

## Quanto è lontano l'osservatore quando guarda senza entrare.
const GUARDA_DA := 6.5
## …e quanto ci mette a camminare (m/s: un giocatore che cammina).
const PASSO_MOCHI := 3.4

var _liv: Node = null
var _vis: Node = null
var _cric: Node = null
var _dn: Node = null
var _build: Node = null
var _player: Node3D = null

var _dove := ""
var _giorni := 12
var _arrivo := 5
var _scatti := 0
var _celle: Array = []          # [cella, quartiere] nell'ordine di insediamento
var _giorno0 := 0
var _giorno_arrivo := -1
var _nome_nuovo := ""
var _seme_nuovo := 90210

var _t_prec := 0.0
var _g_prec := 0
var _fatto_oggi := {}
var _meta_mochi := Vector3.ZERO
var _mestiere := "giro"
var _tappa := 0
var _momenti_prec := {}
var _filma := 0
var _pellicola := ""
var _pellicola_n := 0
var _pellicola_acc := 0.0
var _fermo := 0.0

## il diario: una riga per giornata
var _diario: Array = []
## le distanze: chiave coppia -> giorno -> [somma, quanti]
var _dist := {}
var _sample_acc := 0.0
## i momenti visti, con la loro scena
var _visti: Array = []


func _init() -> void:
	_go()


func _go() -> void:
	_dove = OS.get_environment("CHIBI_FOTO")
	if _dove != "":
		DirAccess.make_dir_recursive_absolute(_dove)
	if OS.get_environment("CHIBI_GIORNI") != "":
		_giorni = int(OS.get_environment("CHIBI_GIORNI"))
	if OS.get_environment("CHIBI_ARRIVO") != "":
		_arrivo = int(OS.get_environment("CHIBI_ARRIVO"))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await process_frame
	change_scene_to_file("res://scenes/levels/MainLevel.tscn")
	for _i in 30:
		await process_frame
	_liv = current_scene
	_vis = _liv.get_node_or_null("Visitors")
	_cric = _liv.get_node_or_null("Cricche")
	_dn = _liv.get_node_or_null("DayNight")
	_build = _liv.get_node_or_null("BuildSystem")
	_player = _liv.get_node_or_null("Player") as Node3D
	if _vis == null or _cric == null or _dn == null or _build == null \
			or _player == null:
		print("GUASTO: manca un nodo — Visitors=%s Cricche=%s DayNight=%s "
				% [_vis, _cric, _dn] + "BuildSystem=%s Player=%s"
				% [_build, _player])
		quit(1)
		return
	# ⚠️ NIENTE VA SUL DISCO. Il salvataggio è di chi gioca, non del banco.
	_build.call("set_persist_for_debug", false)
	await create_timer(2.0).timeout

	_svuota()
	await _costruisci()
	await _insedia()
	# L'OROLOGIO PARTE DA UN'ORA NOTA (e non si accelera: una giornata resta
	# quattro minuti, o si misurerebbe un villaggio che non esiste). Senza,
	# la prima giornata comincia all'ora che aveva il salvataggio e i momenti
	# della giornata cadono a metà.
	# ⚠️ **SI PARTE A METÀ POMERIGGIO, e non è un dettaglio: è l'ora in cui
	# si FINISCE.** N giornate esatte riportano l'orologio dove l'hai messo,
	# e i ritratti — la parte che decide questa fase — si scattano subito
	# dopo l'ultima. Partendo dall'alba si finisce di notte, con tutti dentro
	# casa: il ritratto di chi sta da solo sarebbe una porta chiusa, e
	# sembrerebbe una risposta.
	_dn.call("set_time", 0.46)
	# ⚠️ **E DA UNA STAGIONE CHE SI VEDE.** MISURATO: il salvataggio partiva
	# dal giorno 49, cioè a due giornate dall'inverno — e la foto dall'alto
	# della seconda giornata è un rettangolo BIANCO in cui i corpi non si
	# distinguono dalla neve. Una stagione dura sette giornate
	# (`DayNight.SEASON_DAYS`), quindi una corsa da quattordici ne attraversa
	# comunque due: si parte dal giorno 35 (ultimo di primavera) e si finisce
	# al 49 (ultimo d'autunno), che è l'unica finestra da quattordici che
	# **non tocca l'inverno**. Non è una taratura del sistema: è la luce in
	# cui si fotografa.
	_dn.set("day", 35)
	await process_frame
	_giorno0 = int(_dn.get("day"))
	print("  stagione: %s (giorno %d)"
			% [str(_dn.call("season_name")), int(_dn.get("day"))])
	print("\n  giorno di partenza: %d — si vive per %d giornate (%.0f minuti reali)"
			% [_giorno0, _giorni, float(_giorni) * 4.0])
	await _vivi()
	await _ritratti()
	_referto()
	print("\n  scatti: %d%s" % [_scatti, "" if _dove == "" else " in " + _dove])
	quit(0)


# ------------------------------------------------------------------ il banco

## Via i residenti caricati dal salvataggio di chi gioca: questo banco vuole
## un'anagrafe che conosce, o «chi si ritrova con chi» parlerebbe di gente
## che il villaggio si è portato dietro da un'altra partita.
##
## ⚠️ **E VIA ANCHE IL REGISTRO, che la prima corsa non toglieva.** Il
## salvataggio di chi gioca porta i suoi `incontri` (48 righe, giorno 49), e
## `Cricche` è intestata al NOME: i nomi che `ChibiDNA` genera sono pochi, e
## quattro dei miei residenti si chiamavano come quelli di là. Risultato:
## alla PRIMA giornata il banco dichiarava due coppie vive «da 5 giornate»
## fra gente che si era appena trasferita, con il loro punto di ritrovo in
## mezzo alla radura del falò. Azzerare qui non è seminare: è **partire da
## zero**, che è l'unico modo perché «quante cricche si formano in N giorni»
## voglia dire qualcosa.
func _svuota() -> void:
	_vis.call("debug_reset")
	_cric.set("_incontri", [])
	_cric.set("_oggi", [])
	_cric.set("_coppie", [])
	_cric.set("_ultimo_giorno", -1)
	print("  residenti del salvataggio: rimossi (%d restano) · registro: azzerato"
			% (_vis.get("_residents") as Array).size())


func _posa(cella: Vector2i, pezzo: String) -> bool:
	_build.call("place_cell", cella, pezzo, 0, false)
	return true


func _costruisci() -> void:
	var letti: Array = []
	for gruppo in [[CORTE, "corte"], [FILA, "fila"], [SPONDA, "sponda"],
			[LONTANI, "lontano"]]:
		for c in (gruppo[0] as Array):
			_posa(c, "Letto")
			_posa(c, "Tetto")
			if not bool(_build.call("has_cover", c)):
				print("  ⚠️  la cella %s non tiene una casa — saltata" % str(c))
				continue
			letti.append([c, str(gruppo[1])])
	for c2 in PANCHINE:
		_posa(c2, "Panchina")
	for c3 in CESPUGLI:
		_posa(c3, "Cespuglio")
	for c4 in AIUOLE:
		_posa(c4, "Aiuola")
	_build.call("aggiorna_varchi_ora")
	_celle = letti
	await create_timer(1.0).timeout
	print("  costruito: %d case, %d panchine, %d cespugli, %d aiuole"
			% [letti.size(), PANCHINE.size(), CESPUGLI.size(), AIUOLE.size()])


## ⚠️ **I SEMI SI SCELGONO PERCHÉ I NOMI SIANO DIVERSI**, e non è pignoleria
## di banco: `Cricche` è intestata al NOME (le sue righe sono `a`/`b`, due
## stringhe), e i nomi che `ChibiDNA` sa generare sono una manciata. Alla
## prima corsa due residenti si chiamavano tutti e due «Fragolina», e per il
## predicato erano **la stessa persona**: uno si sarebbe ritrovato con sé
## stesso a due quartieri di distanza. È la trappola delle due anagrafi
## (nome vs label) vista da questo lato.
func _semi(quanti: int) -> Array:
	var DNAG := load("res://scenes/npc/ChibiDNA.gd")
	var out: Array = []
	var visti := {}
	var s := 4100
	while out.size() < quanti and s < 4100 + 6000:
		var nome := str((DNAG.generate(s) as Dictionary).get("name", ""))
		if nome != "" and not visti.has(nome):
			visti[nome] = true
			out.append(s)
		s += 7
	return out


func _insedia() -> void:
	var semi := _semi(_celle.size() + 1)
	if semi.size() <= _celle.size():
		print("  ⚠️  non ho trovato abbastanza nomi diversi")
	_seme_nuovo = int(semi[semi.size() - 1])
	for i in _celle.size():
		var c: Vector2i = (_celle[i] as Array)[0]
		_vis.call("debug_settle", int(semi[i]), c)
	await create_timer(1.5).timeout
	var res: Array = _vis.get("_residents")
	for j in res.size():
		var cc: Vector2i = (res[j] as Dictionary)["cell"]
		_vis.call("debug_stage_resident", j, Vector3(cc.x, 0, cc.y))
	await create_timer(0.6).timeout
	# ⚠️ `debug_stage_resident` lascia il lease a 9999: senza questa riga il
	# villaggio resta fermo per dodici giornate e il banco misura un
	# fermo immagine.
	for k in res.size():
		(res[k] as Dictionary)["next_act"] = randf_range(0.4, 1.8)
	print("  insediati %d residenti:" % res.size())
	for m in res.size():
		var r := res[m] as Dictionary
		print("    %-16s %-8s casa %s"
				% [_nome(r), _quartiere(r["cell"]), str(r["cell"])])


func _nome(r: Dictionary) -> String:
	return str((r.get("dna", {}) as Dictionary).get("name", ""))


func _quartiere(cella: Vector2i) -> String:
	for g in [[CORTE, "corte"], [FILA, "fila"], [SPONDA, "sponda"],
			[LONTANI, "lontano"]]:
		for c in (g[0] as Array):
			if c == cella:
				return str(g[1])
	if cella == CASA_NUOVA:
		return "NUOVO"
	return "?"


func _nomi() -> PackedStringArray:
	var out := PackedStringArray()
	for r in (_vis.get("_residents") as Array):
		var n := _nome(r as Dictionary)
		if n != "":
			out.append(n)
	return out


# ------------------------------------------------------------------ la vita

func _vivi() -> void:
	_t_prec = float(_dn.get("time"))
	_g_prec = int(_dn.get("day"))
	var passate := 0.0
	var prima := _t_prec
	while passate < float(_giorni):
		await process_frame
		var delta := get_root().get_process_delta_time()
		var t := float(_dn.get("time"))
		var g := int(_dn.get("day"))
		passate += fposmod(t - prima, 1.0)
		prima = t
		if g != _g_prec:
			_fatto_oggi.clear()
			_giro_del_giorno(g)
			_g_prec = g
		_regia(delta, t, g)
		_orologio(t, g)
		await _pellicola_passo(delta)
		await _preroll(delta)
		_campiona(delta, g)
		_t_prec = t
	print("\n  … %d giornate vissute" % _giorni)


## I MOMENTI DELLA GIORNATA — ognuno una volta sola, e il confronto sulla
## soglia gestisce da sé il cambio di giorno (il tempo torna a zero).
func _orologio(t: float, g: int) -> void:
	if _passa(0.34, t):
		await _scatta_alto("alto_g%02d" % (g - _giorno0), CENTRO, QUOTA_ALTO)
	if _passa(0.52, t):
		await _scatta_alto("corte_g%02d" % (g - _giorno0),
				CENTRO_GIARDINO, QUOTA_GIARDINO)
		await _scatta_alto("fila_g%02d" % (g - _giorno0),
				CENTRO_GIARDINO2, QUOTA_GIARDINO)
	# ⚠️ **IL FALÒ SI FOTOGRAFA TARDI.** La radura sta a cinquanta metri dalle
	# case e la fase del fuoco dura trentotto secondi reali: alle 0,72 —
	# quattordici secondi dopo la campanella — nella foto c'è **il fuoco e
	# nessuno**, perché sono ancora tutti per strada. Si scatta a 0,80, e si
	# tiene anche lo scatto presto: due immagini che dicono due cose diverse
	# sono meglio di una che sembra dire «al falò non ci va nessuno».
	if _passa(0.72, t):
		await _scatta_alto("falo_presto_g%02d" % (g - _giorno0),
				CLEARING, 16.0)
	if _passa(0.80, t):
		await _scatta_alto("falo_g%02d" % (g - _giorno0), CLEARING, 16.0)
		await _scatta_gioco("falo_camera_g%02d" % (g - _giorno0))
	if _passa(0.90, t):
		print("     · fine giornata %d: %d righe, stagione %s, %s"
				% [g - _giorno0, (_cric.get("_incontri") as Array).size(),
				str(_dn.call("season_name")), _mestiere])
	# IL NUOVO ARRIVATO: il giocatore gli costruisce una casa nella corte
	if _giorno_arrivo < 0 and g - _giorno0 >= _arrivo and _passa(0.30, t):
		await _arriva_qualcuno(g)


func _passa(soglia: float, t: float) -> bool:
	if _fatto_oggi.has(soglia):
		return false
	if t < soglia:
		return false
	_fatto_oggi[soglia] = true
	return true


func _arriva_qualcuno(g: int) -> void:
	_posa(CASA_NUOVA, "Letto")
	_posa(CASA_NUOVA, "Tetto")
	if not bool(_build.call("has_cover", CASA_NUOVA)):
		print("  ⚠️  la casa del nuovo non sta in piedi")
		return
	_build.call("aggiorna_varchi_ora")
	var res: Array = _vis.get("_residents")
	var prima := res.size()
	_vis.call("debug_settle", _seme_nuovo, CASA_NUOVA)
	await create_timer(0.8).timeout
	res = _vis.get("_residents")
	if res.size() <= prima:
		print("  ⚠️  il nuovo non si è insediato")
		return
	var r := res[res.size() - 1] as Dictionary
	_vis.call("debug_stage_resident", res.size() - 1,
			Vector3(CASA_NUOVA.x, 0, CASA_NUOVA.y))
	r["next_act"] = 1.0
	_nome_nuovo = _nome(r)
	_giorno_arrivo = g
	print("\n  ★ giorno %d: si trasferisce %s, casa nella CORTE %s"
			% [g - _giorno0, _nome_nuovo, str(CASA_NUOVA)])


# ------------------------------------------------------------- l'osservatore

## Dove va Mochi adesso, e perché. Nessuna di queste righe tocca un vicino.
func _regia(delta: float, t: float, g: int) -> void:
	if _fermo > 0.0:
		_fermo -= delta
		return
	var meta := _dove_guardare(t, g)
	var p := _player.global_position
	var piatta := Vector3(meta.x, p.y, meta.z)
	if p.distance_to(piatta) > 0.35:
		var d := (piatta - p).normalized()
		_player.global_position = p + d * PASSO_MOCHI * delta


func _dove_guardare(t: float, g: int) -> Vector3:
	# 1. LA SERA SI VA AL FALÒ, come ci va tutto il villaggio
	if t >= 0.62 and t < 0.82:
		_mestiere = "falò"
		return CLEARING + Vector3(0, 0, 8.0)
	# 2. È L'ORA DI QUALCUNO? Allora si è lì.
	var coppie: Array = _cric.get("_coppie")
	var scelta := {}
	var migliore := 999.0
	for c in coppie:
		var rit: Dictionary = (c as Dictionary)["rit"]
		var s: float = CRICCHE._scarto_ora(t, float(rit["ora"]))
		if s < migliore:
			migliore = s
			scelta = c as Dictionary
	if not scelta.is_empty() and migliore <= CRICCHE.FINESTRA_ORA * 3.0:
		var dove: Vector3 = (scelta["rit"] as Dictionary)["dove"]
		# un giorno si guarda da fuori (il duetto), un giorno si sta dentro
		# il loro posto («ci sei anche tu»)
		if (g % 2) == 0:
			_mestiere = "il loro posto, da 6,5 m"
			return dove + Vector3(0, 0, GUARDA_DA)
		_mestiere = "dentro il loro posto"
		return dove + Vector3(0, 0, 1.4)
	# 3. IL GIRO DEL VILLAGGIO — e ogni tanto si passa da chi sta da solo
	_mestiere = "il giro"
	var tappe := [Vector3(9, 0, 3), Vector3(6, 0, 8), Vector3(14, 0, 0),
			Vector3(4, 0, 11), Vector3(6, 0, -1), Vector3(14, 0, 8)]
	var meta: Vector3 = tappe[_tappa % tappe.size()]
	if _player.global_position.distance_to(
			Vector3(meta.x, _player.global_position.y, meta.z)) < 1.2:
		_tappa += 1
	return meta


# --------------------------------------------------------------- i campioni

func _campiona(delta: float, g: int) -> void:
	_sample_acc -= delta
	if _sample_acc > 0.0:
		return
	_sample_acc = 2.0
	var res: Array = _vis.get("_residents")
	for i in res.size():
		for j in range(i + 1, res.size()):
			var a := (res[i] as Dictionary).get("node") as Node3D
			var b := (res[j] as Dictionary).get("node") as Node3D
			if a == null or b == null or not is_instance_valid(a) \
					or not is_instance_valid(b):
				continue
			if bool(a.call("is_hidden")) or bool(b.call("is_hidden")):
				continue
			var k := CRICCHE.chiave(_nome(res[i] as Dictionary),
					_nome(res[j] as Dictionary))
			if not _dist.has(k):
				_dist[k] = {}
			var per_giorno: Dictionary = _dist[k]
			var gg := g - _giorno0
			if not per_giorno.has(gg):
				per_giorno[gg] = [0.0, 0, 0]
			var v: Array = per_giorno[gg]
			var d := a.global_position.distance_to(b.global_position)
			v[0] = float(v[0]) + d
			v[1] = int(v[1]) + 1
			# …e QUANTO STANNO INSIEME: due corpi a meno di 2,5 m (che è
			# `Cricche.ACCANTO`, cioè la distanza che questo sistema chiama
			# «lì accanto») e tutti e due fermi. È il numero che risponde a
			# «chi sta con chi» senza chiedere al predicato se è d'accordo
			# con sé stesso.
			if d <= 2.5 and str(a.get("_state")) in A_RIPOSO \
					and str(b.get("_state")) in A_RIPOSO:
				v[2] = int(v[2]) + 1
	# i momenti: si guarda il contatore, e quando cresce si FILMA
	var m: Dictionary = _cric.call("debug_momenti")
	for k2 in ["✓ ci si trova", "✓ ci sei anche tu"]:
		var ora := int(m.get(k2, 0))
		if ora > int(_momenti_prec.get(k2, 0)):
			_momento_visto(k2, g)
		_momenti_prec[k2] = ora


## LA PELLICOLA COMINCIA PRIMA DEL MOMENTO, o non è una pellicola.
##
## ⚠️ La prima corsa cominciava a filmare quando il contatore cresceva, cioè
## **quando il gesto era già stato concesso**: le tessere mostravano un corpo
## già fermo, e da lì non si può dire se si è fermato per qualcosa o se era
## fermo da sempre. Un momento è un CAMBIO DI STATO, e un cambio di stato si
## vede solo se si vede anche il prima. Perciò, finché la finestra della
## coppia è aperta, si gira a vuoto in un anello di sedici tessere; quando il
## momento arriva, l'anello si copia nell'ordine giusto e la ripresa prosegue.
const PRE_N := 16
var _pre_i := 0
var _pre_pieno := false
var _pre_acc := 0.0


func _preroll(delta: float) -> void:
	if _dove == "" or _filma > 0:
		return
	# si gira solo quando c'è qualcosa da aspettare: siamo nel posto di
	# qualcuno, alla sua ora
	if not _mestiere.begins_with("il loro posto") \
			and not _mestiere.begins_with("dentro"):
		return
	_pre_acc -= delta
	if _pre_acc > 0.0:
		return
	_pre_acc = 0.25
	await _scatta_gioco("_pre_%02d" % _pre_i)
	_pre_i = (_pre_i + 1) % PRE_N
	if _pre_i == 0:
		_pre_pieno = true


## Le tessere dell'anello, dalla più vecchia alla più nuova.
func _salva_preroll(nome: String) -> int:
	var d := DirAccess.open(_dove)
	if d == null:
		return 0
	var n := 0
	var quanti := PRE_N if _pre_pieno else _pre_i
	for k in quanti:
		var i := (_pre_i - quanti + k + PRE_N) % PRE_N
		var da := "_pre_%02d.jpg" % i
		if not d.file_exists(da):
			continue
		# numerate all'INDIETRO: −16 è la più vecchia, −01 l'ultima prima
		# del momento. Così l'ordine di lettura è l'ordine del tempo.
		d.copy(_dove.rstrip("/") + "/" + da,
				_dove.rstrip("/") + "/%s_pre%02d.jpg" % [nome, quanti - k])
		n += 1
	return n


func _momento_visto(quale: String, g: int) -> void:
	var ult: Dictionary = _vis.call("debug_duetto_ultimo")
	var riga := {"quale": quale, "giorno": g - _giorno0,
			"ora": float(_dn.get("time")), "duetto": ult.duplicate(),
			"mestiere": _mestiere}
	_visti.append(riga)
	print("\n  ★★ %s — giornata %d, ora %.3f  %s"
			% [quale, g - _giorno0, float(_dn.get("time")), str(ult)])
	if _dove == "":
		return
	_pellicola = "momento_%02d_%s" % [_visti.size(),
			"duetto" if quale.contains("trova") else "cisei"]
	var pre := _salva_preroll(_pellicola)
	riga["preroll"] = pre
	print("      (%d tessere di PRIMA salvate dall'anello)" % pre)
	_pellicola_n = 0
	_filma = 24
	_pellicola_acc = 0.0
	# ⚠️ **E L'OSSERVATORE SI FERMA.** Nella prima corsa Mochi continuava a
	# camminare verso la sua meta mentre il momento succedeva, e nella
	# pellicola il giocatore scivola di lato per due secondi: un movimento
	# che nessun giocatore farebbe proprio lì, e che si porta dietro
	# l'inquadratura. Chi guarda, guarda.
	_fermo = 7.0


## LA PELLICOLA: un fotogramma ogni 0,25 s, dalla camera VERA del gioco. Un
## momento non si giudica in una posa — si giudica in una pellicola.
func _pellicola_passo(delta: float) -> void:
	if _filma <= 0:
		return
	_pellicola_acc -= delta
	if _pellicola_acc > 0.0:
		return
	_pellicola_acc = 0.25
	_filma -= 1
	await _scatta_gioco("%s_%02d" % [_pellicola, _pellicola_n])
	_pellicola_n += 1


# -------------------------------------------------------------- i ritratti
#
# LA DOMANDA PIÙ IMPORTANTE DI TUTTA LA FASE — «chi sta da solo sembra che
# stia bene, o sembra escluso?» — non si risponde con un numero, e non si
# risponde nemmeno con una foto sola: si risponde **appaiando**. Stessa
# giornata, stessa ora, stessa distanza dell'obiettivo, stessa camera (quella
# vera del gioco, incollata a Mochi). Se le due immagini si somigliano, la
# risposta è «sta bene»; se una delle due è più povera dell'altra, il sistema
# sta dicendo qualcosa che non deve dire.
#
# ⚠️ **E L'OSSERVATORE CI VA A PIEDI.** Farlo comparire di colpo a sei metri
# cambia la scena che deve fotografare: la calma del prato è una funzione di
# quanto ti muovi, e ci sono tre sistemi che la leggono.

func _ritratti() -> void:
	print("")
	print("█".repeat(72))
	print("I RITRATTI — la stessa ora, la stessa distanza, due vite diverse")
	print("█".repeat(72))
	if _diario.is_empty():
		return
	var ultima: Dictionary = _diario[_diario.size() - 1]
	var res: Array = _vis.get("_residents")
	# LA COPPIA: quella che si ritrova da più giornate
	var coppie: Array = (ultima["coppie"] as Array).duplicate()
	coppie.sort_custom(func(x, y):
		return int((x as Dictionary)["giorni"]) > int((y as Dictionary)["giorni"]))
	if not coppie.is_empty():
		var c := coppie[0] as Dictionary
		var na := _corpo_di(str(c["a"]))
		var nb := _corpo_di(str(c["b"]))
		if na != null and nb != null:
			await _ritratto("ritratto_coppia",
					(na.global_position + nb.global_position) * 0.5,
					"%s + %s (si ritrovano da %d giornate)"
					% [c["a"], c["b"], int(c["giorni"])])
	# CHI STA DA SOLO: il primo dell'elenco, che è l'ordine dell'anagrafe,
	# cioè una cosa che non vuol dire niente
	var soli: Array = ultima["soli"] as Array
	if not soli.is_empty():
		var n := _corpo_di(str(soli[0]))
		if n != null:
			await _ritratto("ritratto_solo", n.global_position,
					"%s (non si ritrova con nessuno)" % str(soli[0]))
	# …e uno dei due che stanno in disparte, se non è già lui
	for r in res:
		var d := r as Dictionary
		if _quartiere(d["cell"]) != "lontano":
			continue
		if not soli.is_empty() and _nome(d) == str(soli[0]):
			continue
		var n2 := (d.get("node") as Node3D)
		if n2 != null and is_instance_valid(n2):
			await _ritratto("ritratto_lontano", n2.global_position,
					"%s (casa in disparte)" % _nome(d))
		break


func _corpo_di(nome: String) -> Node3D:
	for r in (_vis.get("_residents") as Array):
		if _nome(r as Dictionary) == nome:
			var n := (r as Dictionary).get("node") as Node3D
			return n if n != null and is_instance_valid(n) else null
	return null


## ⚠️ **IL POSTO DA CUI SI GUARDA VA SCELTO, NON DATO PER BUONO.** La prima
## corsa piazzava l'obiettivo a 6,5 m esatti dietro il soggetto, e per la
## COPPIA — cioè per il ritratto che regge il confronto — fra i due corpi e la
## macchina c'era **un albero**: sei fotogrammi di chioma arancione e un
## chibi grande dieci pixel nell'angolo. La camera di questo gioco non si
## gira (sta sempre a −Z di Mochi), quindi l'unica libertà è di QUANTO e di
## QUANTO DI LATO ci si mette; e la domanda «si vede o è coperto?» la sa già
## fare il villaggio — è il settimo cancello dell'usciere, `_gesto_coperto`,
## quello che gli impedisce di regalare un gesto a un corpo dietro un muro.
func _posto_da_cui_guardare(dove: Vector3) -> Vector3:
	var candidati: Array = []
	for dz in [GUARDA_DA, GUARDA_DA + 1.5, GUARDA_DA - 1.5]:
		for dx in [0.0, 2.5, -2.5, 4.0, -4.0]:
			candidati.append(dove + Vector3(dx, 0, dz))
	# si torna DA DOVE SI ERA, e poi ci si va a piedi: la prova la fa
	# l'obiettivo, il viaggio lo fa il corpo (la calma del prato è una
	# funzione di quanto ti muovi, e la leggono in tre)
	var partenza := _player.global_position
	for c in candidati:
		_player.global_position = Vector3(c.x, partenza.y, c.z)
		await process_frame
		await process_frame
		if not bool(_vis.call("_gesto_coperto", dove)):
			_player.global_position = partenza
			await process_frame
			return c
	_player.global_position = partenza
	print("     ⚠️  nessun punto di ripresa scoperto: si scatta lo stesso, "
			+ "e la tessera va guardata sapendolo")
	return dove + Vector3(0, 0, GUARDA_DA)


func _ritratto(nome: String, dove: Vector3, chi: String) -> void:
	print("  %s — %s" % [nome, chi])
	var meta: Vector3 = await _posto_da_cui_guardare(dove)
	var t := 0.0
	while t < 25.0:
		await process_frame
		var delta := get_root().get_process_delta_time()
		t += delta
		var p := _player.global_position
		var piatta := Vector3(meta.x, p.y, meta.z)
		if p.distance_to(piatta) < 0.4:
			break
		_player.global_position = p + (piatta - p).normalized() \
				* PASSO_MOCHI * delta
	for k in 6:
		await create_timer(0.6).timeout
		await _scatta_gioco("%s_%02d" % [nome, k])


# ------------------------------------------------------------- il giro giorno

func _giro_del_giorno(g: int) -> void:
	var inc: Array = _cric.get("_incontri")
	var nomi := _nomi()
	var oggi := g
	var coppie := CRICCHE.coppie_vive(inc, nomi, oggi)
	var gruppi := CRICCHE.cricche(inc, nomi, nomi.size(), oggi)
	var soli: Array = []
	var con_qualcuno := {}
	for c in coppie:
		con_qualcuno[str((c as Dictionary)["a"])] = true
		con_qualcuno[str((c as Dictionary)["b"])] = true
	for n in nomi:
		if not con_qualcuno.has(str(n)):
			soli.append(str(n))
	var righe_coppie: Array = []
	for c2 in coppie:
		var d := c2 as Dictionary
		var rit: Dictionary = d["rit"]
		righe_coppie.append({"a": str(d["a"]), "b": str(d["b"]),
				"giorni": int(rit["giorni"]), "ora": float(rit["ora"]),
				"dove": [float((rit["dove"] as Vector3).x),
						float((rit["dove"] as Vector3).z)]})
	var righe_gruppi: Array = []
	for gr in gruppi:
		righe_gruppi.append(Array(gr as PackedStringArray))
	_diario.append({"giorno": g - _giorno0, "righe": inc.size(),
			"coppie": righe_coppie, "cricche": righe_gruppi, "soli": soli,
			"residenti": nomi.size()})
	print("  ── giornata %2d: %3d righe · %d coppie vive · %d cricche · %d soli"
			% [g - _giorno0, inc.size(), coppie.size(), gruppi.size(),
			soli.size()])
	for c3 in righe_coppie:
		print("       %s + %s   %d giornate, ora %.3f, in (%.1f, %.1f)"
				% [c3["a"], c3["b"], c3["giorni"], c3["ora"],
				(c3["dove"] as Array)[0], (c3["dove"] as Array)[1]])
	for gr2 in righe_gruppi:
		print("       CRICCA: %s" % " + ".join(PackedStringArray(gr2)))


# ------------------------------------------------------------------ le foto

## ⚠️ **LA UI VA VIA PRIMA DELLO SCATTO.** Le barre dei bisogni, il cartellino
## «E — dormi» e la riga della modalità costruzione stavano cotti dentro ogni
## foto della prima corsa: sono l'interfaccia di chi gioca, non il villaggio,
## e in una domanda come «sembra escluso?» un cartellino sopra la testa
## risponde al posto del corpo. È l'idioma di `PhotoMode._hide_ui`.
var _nascosti: Array = []


func _ui_via() -> void:
	_nascosti.clear()
	for layer in get_root().find_children("*", "CanvasLayer", true, false):
		var cl := layer as CanvasLayer
		if cl != null and cl.visible:
			cl.visible = false
			_nascosti.append(cl)


func _ui_torna() -> void:
	for cl in _nascosti:
		if is_instance_valid(cl):
			(cl as CanvasLayer).visible = true
	_nascosti.clear()


func _scatta_gioco(nome: String) -> void:
	if _dove == "":
		return
	_ui_via()
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_jpg(
			_dove.rstrip("/") + "/" + nome + ".jpg", 0.92)
	_ui_torna()
	_scatti += 1


## Dall'alto: si monta una macchina propria, si scatta, e si RIDÀ la scena
## alla camera del gioco — che è quella che decide se un gesto è in
## inquadratura, e lasciargliela portare via sarebbe cambiare il gioco per
## fotografarlo.
func _scatta_alto(nome: String, centro: Vector3, quota: float) -> void:
	if _dove == "":
		return
	var prima := get_root().get_camera_3d()
	var cam := Camera3D.new()
	_liv.add_child(cam)
	cam.fov = 52.0
	cam.global_position = centro + Vector3(0, quota, quota * 0.62)
	cam.look_at(centro, Vector3.UP)
	cam.current = true
	for _i in 3:
		await process_frame
	_ui_via()
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_jpg(
			_dove.rstrip("/") + "/" + nome + ".jpg", 0.92)
	_ui_torna()
	_scatti += 1
	cam.queue_free()
	if prima != null and is_instance_valid(prima):
		prima.make_current()
	await process_frame


# ----------------------------------------------------------------- il referto

func _referto() -> void:
	print("")
	print("█".repeat(72))
	print("IL REFERTO")
	print("█".repeat(72))
	var inc: Array = _cric.get("_incontri")
	print("  righe del registro: %d" % inc.size())
	print("── L'ANCORA DEL RITROVO (dove uno va a sedersi) ──")
	for a in _ancore():
		var r := a as Dictionary
		print("    %-12s %-8s sposta %.2f m  panchina diversa: %s  (con %s)"
				% [r["nome"], r["quartiere"], float(r["sposta"]),
				"SÌ" if bool(r["panchina_cambia"]) else "no",
				"nessuno" if (r["compagni"] as Array).is_empty()
						else ", ".join(PackedStringArray(r["compagni"] as Array))])
	print("  momenti riconosciuti: %s" % str(_cric.call("debug_momenti")))
	print("  i no dell'usciere:")
	var no: Dictionary = _vis.call("debug_gesti_contatori")
	var kk: Array = no.keys()
	kk.sort()
	for k in kk:
		print("     %-52s %5d" % [str(k), int(no[k])])
	if _dove != "":
		var f := FileAccess.open(_dove.rstrip("/") + "/misure.json",
				FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify({
				"diario": _diario, "visti": _visti,
				"distanze": _dist_serializzato(),
				"arrivo": {"giorno": _giorno_arrivo - _giorno0,
						"nome": _nome_nuovo},
				"quartieri": _quartieri_serializzati(),
				"ancore": _ancore(),
				"registro": _cric.get("_incontri"),
				"momenti": _cric.call("debug_momenti"),
				"no_usciere": no,
			}, "  "))
			f.close()
			print("  misure in %s/misure.json" % _dove)


## L'ANCORA DEL RITROVO, misurata sul villaggio vero: di quanti metri il
## posto in cui uno va a sedersi si sposta perché si ritrova con qualcuno, e
## se questo gli fa scegliere una PANCHINA DIVERSA.
##
## ⚠️ **Si chiede a `Visitors`, non si rifà il conto.** La formula è
## `_ancora_ritrovo` (casa propria spostata verso il punto medio delle case
## di chi si ritrova con te, mai più di `SPOSTA_MAX`): riscriverla qui
## sarebbe la tabella gemella — e per giunta questo banco esiste proprio per
## dire se quella riga di codice **si vede**.
func _ancore() -> Array:
	var out: Array = []
	for r in (_vis.get("_residents") as Array):
		var d := r as Dictionary
		var cella: Vector2i = d["cell"]
		var home := Vector3(cella.x, 0.0, cella.y)
		var verso: Vector3 = _vis.call("_ancora_ritrovo", d, home)
		var p_home := _vis.call("_free_bench", home) as Node3D
		var p_verso := _vis.call("_free_bench", verso) as Node3D
		out.append({
			"nome": _nome(d), "quartiere": _quartiere(cella),
			"sposta": home.distance_to(verso),
			"compagni": Array(_cric.call("compagni", _nome(d)) as PackedStringArray),
			"panchina_cambia": p_home != p_verso,
			"panchina_da_casa": "" if p_home == null else str(p_home.global_position),
			"panchina_col_ritrovo": "" if p_verso == null else str(p_verso.global_position),
		})
	return out


func _dist_serializzato() -> Dictionary:
	var out := {}
	for k in _dist:
		var per_giorno: Dictionary = _dist[k]
		var righe := {}
		for g in per_giorno:
			var v: Array = per_giorno[g]
			if int(v[1]) > 0:
				righe[str(g)] = [float(v[0]) / float(v[1]),
						float(v[2]) * 2.0, int(v[1])]
		out[str(k).replace("\n", " + ")] = righe
	return out


func _quartieri_serializzati() -> Dictionary:
	var out := {}
	for r in (_vis.get("_residents") as Array):
		var d := r as Dictionary
		out[_nome(d)] = {"quartiere": _quartiere(d["cell"]),
				"cella": [int((d["cell"] as Vector2i).x),
						int((d["cell"] as Vector2i).y)]}
	return out
