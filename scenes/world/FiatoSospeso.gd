extends Node

## IL FIATO SOSPESO — aspettare, finalmente, come verbo.
##
## Tieni premuto C e Mochi si abbassa nell'erba: le orecchie in avanti, il
## respiro che rallenta. Se non ti muovi DAVVERO, il prato smette di avere
## paura di te e ti viene addosso — la farfalla che inseguivi da un mese
## si posa sul tuo naso.
##
## È l'unica cosa che il gioco sa fare nei primi due minuti di partita, e
## l'unica in cui si può diventare bravi: non premendo meglio, ma
## imparando DOVE e QUANDO fermarsi, e come avvicinarsi senza spaventare
## quello che si vuole vedere.
##
## LE REGOLE DI DESIGN — le difende tests/cases/test_fiato.gd:
##
##  • NIENTE HUD. Non esiste una barra della quiete: si legge addosso a
##    Mochi (quanto è giù, quanto è lento il respiro) e nel prato che
##    torna. Una barra trasformerebbe l'attesa in un compito da sbrigare.
##  • NON SI CONGELA IL GIOCATORE. Muoversi non è impedito: è la ROTTURA,
##    ed è volontaria. Congelare avrebbe spento anche la E e l'ESC — non
##    si toglie il retino di mano a chi ha una farfalla sul naso per
##    proteggerlo da sé stesso, e non si chiude la via d'uscita a chi
##    vuole solo alzarsi.
##  • MUOVERSI NON TOGLIE NIENTE. Nessun punto, nessun malus, nessun
##    rimprovero: quello che era arrivato vola via, e hai perso una SCENA.
##    È lo stesso patto della pesca e delle Promesse — qui nessuno fallisce.
##  • CHI SI FIDA NON SI CATTURA. La farfalla posata è PRESTATA: sparisce
##    dai bersagli del retino e dall'appello del bestiario finché sta lì.
##    Prendere chi si è fidato di te è il gesto sbagliato, e il gioco non
##    deve nemmeno offrirtelo.
##  • LA CALMA HA UNA CASA SOLA. Le paure del mondo — farfalle, rane,
##    lucciole, e in C++ passerotti e farfalle del prato fitto — erano
##    formule scritte a mano in tre file diversi, con tre pavimenti di
##    paura che non si spegnevano mai. Adesso moltiplicano tutte QUESTO
##    numero, e c'è un posto solo da tarare.
##  • IL MOMENTO SI PUÒ FOTOGRAFARE. Con la farfalla sul naso la Modalità
##    Foto non rompe niente: il fiato si mette in pausa e aspetta te.

const POSTO := preload("res://scenes/world/PostoDiSempre.gd")
const CRIT := preload("res://scenes/world/Critters.gd")
const MOCHI := preload("res://scenes/characters/Mochi.gd")

## Quanta quiete emani stando semplicemente fermo in piedi. Non è uno:
## sei comunque un animale grosso che sta lì. Il resto lo dà il fiato.
const QUIETE_IN_PIEDI := 0.42
## Sopra questa quiete qualcuno si stacca dal prato e viene a vedere chi sei.
const SOGLIA_FIDUCIA := 0.70
## Sotto questa, chi si era fidato vola via.
const FIDUCIA_ROTTA := 0.44
## Quanto lontano può essere una farfalla perché valga la pena chiamarla.
const RICHIAMO_R := 7.5
## Il tempo caratteristico dell'oblio del prato: dopo ~4 s di immobilità
## sei quasi sparito, dopo ~12 s sei un sasso caldo.
const OBLIO := 5.5
## Dove va la camera quando sei tutto giù (posizione locale sul pivot):
## dalla spalla lontana alla riga dell'erba, vicino al muso.
const VICINO := Vector3(0.0, 1.15, 1.95)

var quiete := 0.0        # 0 = fai paura a tutti · 1 = il prato ti ha dimenticato
var giu := 0.0           # quanto sei accovacciato (0..1)
var fermo_da := 0.0      # secondi di immobilità VERA, senza interruzioni
## Il fiato più lungo che tu abbia mai tenuto. Oggi non lo legge nessuno,
## ed è voluto: è un dato che il giocatore si guadagna adesso, così il
## giorno che il Gufo avrà qualcosa da dirgli sopra lo troverà già lì —
## e non ricomincerà da zero per tutti quelli che hanno già giocato.
var record := 0.0
var fidati := {}         # specie -> quante volte si è posata su di te

var _player: Node3D
var _mochi: Node
var _cozy: Node
var _foto: Node
var _mail: Node
var _sfx
var _cercato := false
var _rotto_cd := 0.0     # dopo una rottura il fiato non riparte nello stesso istante
var _ospite := ""        # la specie posata adesso ("" = nessuna)
var _dove := "naso"      # dove si posa: "naso" o "cocuzzolo"
var _ospite_t := 0.0
var _durata_visita := 20.0
var _in_arrivo := false
var _resp_fase := -1.0   # la fase del respiro udibile (-1 = da capo)
var _fov_base := 0.0
var _cam_base := Vector3.ZERO
var _cam: Camera3D


func _ready() -> void:
	add_to_group("persistable")
	add_to_group("fiato_sospeso")
	# col menu aperto non si accumula fiato: il gioco è in pausa, e anche
	# l'attesa lo è
	process_mode = Node.PROCESS_MODE_PAUSABLE


## I fratelli si cercano finché non ci sono TUTTI: il CozyWorld nasce
## differito (costruisce il mondo su più frame) e i sistemi di MainLevel
## si montano in fila. Una ricerca «una volta sola» al primo frame
## troverebbe metà mondo e resterebbe cieca per sempre — senza errori,
## senza farfalle, e nessuno capirebbe perché.
func _trova() -> void:
	if _cercato:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player_controller") as Node3D
	if _player and _mochi == null:
		_mochi = _player.get_node_or_null("Mochi")
	if _cozy == null or not is_instance_valid(_cozy):
		_cozy = get_tree().get_first_node_in_group("cozy_world")
	_cercato = _player != null and _mochi != null and _cozy != null
	# PhotoMode e Mail sono nodi di MainLevel, non gruppi: si trovano per
	# nome dal fratello (i sistemi montati con _spawn_system stanno lì)
	_foto = get_node_or_null("../PhotoMode")
	_mail = get_node_or_null("../Mail")
	_sfx = get_node_or_null(^"/root/Sfx")


# ---------------------------------------------------------------- la calma

## LA CALMA — la fonte unica. Quanto il prato si fida di te adesso: 0 se
## stai correndo addosso a tutti, 1 se sei fermo nell'erba da abbastanza
## a lungo da essere diventato paesaggio.
##
## In piedi la calma non supera mai QUIETE_IN_PIEDI, per quanto tu stia
## immobile: un animale grosso in piedi resta un animale grosso in piedi.
## È il fiato che apre l'altra metà, e la apre COL TEMPO — perché senza
## una dimensione temporale «aspettare» non aggiungerebbe niente a quello
## che stare fermi già faceva.
##
## PURA: entra la velocità (m/s), quanto sei giù (0..1) e da quanti
## secondi non ti muovi; esce la calma. La prova la fa il test.
static func calma(velocita: float, quanto_giu: float, da_quanto: float) -> float:
	# la velocità è un FATTORE su tutto, non solo sulla parte in piedi: chi
	# si muove non è calmo, accovacciato o no. (Nel gioco «fermo_da» non
	# cresce mentre ti muovi, quindi il caso non capita — ma una funzione
	# pura non deve mentire a chi la chiama con altri numeri.)
	var fermo := clampf(1.0 - velocita / 3.0, 0.0, 1.0)
	var in_piedi := QUIETE_IN_PIEDI * fermo
	if quanto_giu <= 0.01 or da_quanto <= 0.0:
		return in_piedi
	var dimenticato := (1.0 - exp(-maxf(da_quanto, 0.0) / OBLIO)) * fermo
	return lerpf(in_piedi, maxf(in_piedi, dimenticato), clampf(quanto_giu, 0.0, 1.0))


# ---------------------------------------------------------------- il ciclo

func _process(delta: float) -> void:
	_trova()
	if _player == null or not is_instance_valid(_player):
		return
	_rotto_cd = maxf(0.0, _rotto_cd - delta)

	# LA MODALITÀ FOTO NON ROMPE IL MOMENTO. È l'inquadratura più bella che
	# questo gioco possa offrire: se sei giù nell'erba con qualcuno sul
	# naso, il fiato si ferma dov'è e aspetta che tu abbia scattato.
	if _foto and _foto.has_method("is_active") and bool(_foto.call("is_active")):
		_scrivi_mochi()
		_pubblica_calma()
		return

	var vel := 0.0
	var v: Variant = _player.get("velocity")
	if v is Vector3:
		vel = (v as Vector3).length()
	var si_muove := vel > POSTO.FERMA or _tasti_di_movimento()

	var vuole := Input.is_action_pressed("fiato") and _rotto_cd <= 0.0 and _si_puo()
	# si scende piano (è una decisione), si risale di scatto (è un riflesso)
	var k := 3.4 if vuole and not si_muove else 11.0
	giu = lerpf(giu, 1.0 if (vuole and not si_muove) else 0.0, 1.0 - exp(-k * delta))

	if si_muove or not vuole:
		# LASCIARE IL TASTO NON È FUGGIRE. Se ti sei mosso, quello che era
		# arrivato si spaventa e scatta via; se hai solo tolto il dito
		# stando fermo, si stacca e riprende il suo giro senza drammi —
		# sono due scene diverse, e il giocatore le distingue.
		if fermo_da > 0.5 and giu > 0.25:
			_rompi(si_muove)
		fermo_da = 0.0
	elif giu > 0.55:
		fermo_da += delta
		record = maxf(record, fermo_da)

	quiete = calma(vel, giu, fermo_da)
	_aggiorna_ospite(delta)
	_respira(delta)
	_scrivi_mochi()
	_pubblica_calma()
	_atmosfera(delta)


## IL RESPIRO SI SENTE. Un sospiro quando ti abbassi, poi il fiato che
## rallenta insieme a quello del corpo — e quando qualcosa si posa su di
## te, si ferma del tutto. È il silenzio a dire che sta succedendo.
func _respira(delta: float) -> void:
	if _sfx == null:
		return
	if giu < 0.25 or _ospite != "":
		_resp_fase = -1.0     # da capo: il prossimo abbassarsi è un sospiro
		return
	# il periodo viene dalla fonte unica: il respiro che si sente e quello
	# che si vede devono essere lo STESSO respiro
	var periodo: float = MOCHI.periodo_fiato(giu, false)
	if _resp_fase < 0.0:
		_resp_fase = 0.0
		_sfx.play("respiro_in", -21.0, randf_range(0.96, 1.04))
		return
	var prima := _resp_fase
	_resp_fase = fposmod(_resp_fase + delta / periodo, 1.0)
	var vol := lerpf(-25.0, -31.0, giu)
	if _resp_fase < prima:
		_sfx.play("respiro_in", vol, randf_range(0.96, 1.04))
	elif prima < 0.36 and _resp_fase >= 0.36:
		_sfx.play("respiro_out", vol - 2.0, randf_range(0.94, 1.02))


## Il fiato si tiene solo in piedi sull'erba, da svegli e con le zampe
## libere: seduti, in barca, a mollo o con la canna in mano non è che non
## si possa — è che sarebbe un'altra scena.
func _si_puo() -> bool:
	if _mochi == null or not is_instance_valid(_mochi):
		return false
	if str(_mochi.get("_pose")) != "stand":
		return false
	if float(_mochi.get("_hold_target")) > 0.0 or float(_mochi.get("_hold")) > 0.05:
		return false
	if float(_mochi.get("_climb")) > 0.05:
		return false
	# e non mentre un altro sistema ha in mano il giocatore
	return _player.is_physics_processing()


func _tasti_di_movimento() -> bool:
	return Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down").length() > 0.05


## LA ROTTURA. Ti sei mosso: quello che era arrivato vola via. Non perdi
## niente — solo la scena. Ed è per questo che la prossima volta starai
## più attento a dove ti metti.
func _rompi(spaventata := true) -> void:
	fermo_da = 0.0
	_rotto_cd = 0.35 if spaventata else 0.0
	if _ospite != "" or _in_arrivo:
		if _cozy and _cozy.has_method("congeda_farfalla"):
			_cozy.call("congeda_farfalla", spaventata)
		if _sfx:
			# uno scatto secco se l'hai spaventata, un frullo piano se se
			# n'è andata per conto suo
			_sfx.call("frullo", -12.0 if spaventata else -22.0)
	_ospite = ""
	_in_arrivo = false


# ------------------------------------------------------------- chi si fida

func _aggiorna_ospite(delta: float) -> void:
	if _cozy == null or not _cozy.has_method("chiama_farfalla"):
		return
	var posato: Dictionary = _cozy.call("farfalla_posata")
	if not posato.is_empty():
		_cozy.call("aggiorna_posatoio", _posatoio(), _direzione())
	if quiete < FIDUCIA_ROTTA:
		if not posato.is_empty():
			_cozy.call("congeda_farfalla", false)
			_ospite = ""
			_in_arrivo = false
		return
	if posato.is_empty():
		_ospite = ""
		_in_arrivo = false
		if quiete >= SOGLIA_FIDUCIA:
			_dove = _scegli_dove()
			var chi := str(_cozy.call("chiama_farfalla", _posatoio(), RICHIAMO_R))
			_in_arrivo = chi != ""
		return
	_in_arrivo = str(posato.get("stato", "")) == "arriva"
	if str(posato.get("stato", "")) == "posata":
		if _ospite == "":
			_ospite = str(posato.get("specie", ""))
			_ospite_t = 0.0
			_durata_visita = 17.0 + float(hash(_ospite) % 900) / 100.0
			_si_e_fidata(_ospite)
		_ospite_t += delta
		# e prima o poi se ne va da sola, com'è giusto: un momento che non
		# finisce mai smette di essere un momento. Quanto dura dipende da
		# CHI è: due visite non si somigliano mai del tutto.
		if _ospite_t > _durata_visita:
			_rompi(false)


## Il posatoio. Lo dà Mochi, perché è lei che sa dove ha il naso — a mano
## si sbaglierebbe (il suo nodo ha scala 0.75 e mezzo giro su Y).
##
## Naso o cocuzzolo: si SCEGLIE al momento della chiamata, e non si cambia
## più. La camera di gioco sta dietro le spalle, e con Mochi girata di là
## un naso è dietro una sfera di quaranta centimetri: la scena più bella
## del gioco succederebbe fuori campo. Chi si fida si posa dove si vede.
func _posatoio() -> Vector3:
	if _mochi == null:
		return _player.global_position + Vector3(0, 0.7, 0)
	if _dove == "cocuzzolo" and _mochi.has_method("punto_cocuzzolo"):
		return _mochi.call("punto_cocuzzolo")
	if _mochi.has_method("punto_naso"):
		return _mochi.call("punto_naso")
	return _player.global_position + Vector3(0, 0.7, 0)


## Il muso guarda dalla parte della camera? Allora il naso si vede.
func _scegli_dove() -> String:
	var cam := get_viewport().get_camera_3d()
	if cam == null or _mochi == null or not _mochi.has_method("direzione_muso"):
		return "cocuzzolo"
	var verso_cam := cam.global_position - _player.global_position
	verso_cam.y = 0.0
	var muso: Vector3 = _mochi.call("direzione_muso")
	if verso_cam.length() < 0.01 or muso.length() < 0.01:
		return "cocuzzolo"
	return "naso" if muso.normalized().dot(verso_cam.normalized()) > 0.05 else "cocuzzolo"


## Dove guarda il musetto: la farfalla posata si orienta come lui, così
## le ali si aprono di traverso all'inquadratura invece che di taglio.
func _direzione() -> Vector3:
	if _mochi and _mochi.has_method("direzione_muso"):
		return _mochi.call("direzione_muso")
	return Vector3.FORWARD


## La prima volta che una specie si posa su di te, il Gufo se ne accorge e
## te ne scrive. Le volte dopo restano tue e basta: il registro cresce in
## silenzio, come è giusto per una cosa che nessuno ti ha chiesto di fare.
func _si_e_fidata(specie: String) -> void:
	if specie == "":
		return
	var prima := not fidati.has(specie)
	fidati[specie] = int(fidati.get(specie, 0)) + 1
	if _sfx:
		_sfx.call("frullo", -20.0)
	if prima:
		if _mail and _mail.has_method("queue_letter"):
			_mail.call("queue_letter", {
				"from_key": "Gufo",
				"text_key": "Mi dicono che %s\nsi è posata su di te e non è scappata.\nNon si insegna: si aspetta e basta.\nHai imparato il verbo più difficile.",
				# il nome della creatura è un argomento DA TRADURRE, non un
				# dato: si conserva la sua chiave italiana e si traduce
				# quando la busta si apre
				"args": [{"k": CRIT.con_articolo_chiave(specie)}],
				"gift": false,
			})
	var build := get_tree().get_first_node_in_group("build_system")
	if build and build.has_method("request_save"):
		build.call("request_save")


# ------------------------------------------------------------- il corpo

func _scrivi_mochi() -> void:
	if _mochi and is_instance_valid(_mochi) and _mochi.has_method("set_fiato"):
		# …e dove sta l'ospite, così gli occhi lo cercano davvero
		var dove := Vector3.ZERO
		if _ospite != "" and _cozy and _cozy.has_method("farfalla_posata"):
			var po: Dictionary = _cozy.call("farfalla_posata")
			if not po.is_empty():
				dove = _posatoio()
		_mochi.call("set_fiato", giu, _ospite != "", dove)


## La calma va a TUTTI quelli che hanno paura di te: il prato di CozyWorld
## (farfalle, rane), le lucciole della Collezione, e il C++ dell'ecosistema
## (passerotti e le novanta farfalle del prato fitto, che prima non
## sapevano nemmeno che tu esistessi).
func _pubblica_calma() -> void:
	# …e all'ERBA, che quando ti accovacci si richiude attorno a te invece
	# di scansarsi (grass_blade.gdshader). Il canale è di questo sistema:
	# CozyWorld non sa niente del fiato, e non deve saperlo.
	RenderingServer.global_shader_parameter_set("mochi_giu", giu)
	get_tree().call_group("calma_listener", "set_calma", quiete,
			_player.global_position if _player else Vector3.ZERO)


# ------------------------------------------------------------ atmosfera

func _atmosfera(delta: float) -> void:
	# il mondo si abbassa la voce mentre stai giù: non è un effetto, è
	# quello che succede davvero quando smetti di fare rumore tu
	if _sfx and _sfx.has_method("quiete_del_prato"):
		_sfx.call("quiete_del_prato", giu)
	# LA CAMERA SCENDE CON TE. Da lassù — quattro metri e mezzo dietro le
	# spalle — un'ala che si apre piano è tre pixel: la scena più delicata
	# del gioco si perderebbe nella distanza. Mentre ti abbassi, l'occhio
	# si avvicina e scende nell'erba con Mochi. È anche il vero premio
	# dello stare fermi: il mondo diventa più vicino.
	if _cam == null or not is_instance_valid(_cam):
		if _player == null:
			return
		_cam = _player.get_node_or_null("CameraPivot/Camera3D") as Camera3D
		if _cam == null:
			return
		_cam_base = _cam.position
		_fov_base = _cam.fov
	# si scrive SEMPRE, anche a peso zero: un canale che smette di essere
	# scritto lascia la camera dov'era, per sempre
	var meta_pos := _cam_base.lerp(VICINO, giu)
	_cam.position = _cam.position.lerp(meta_pos, 1.0 - exp(-3.2 * delta))
	_cam.fov = lerpf(_cam.fov, lerpf(_fov_base, _fov_base - 6.0, giu),
			1.0 - exp(-3.2 * delta))


# ---------------------------------------------------------- persistenza

func save_extra() -> Dictionary:
	return {"fiato": {"record": record, "fidati": fidati}}


func load_extra(data: Dictionary) -> void:
	var d: Dictionary = data.get("fiato", {})
	record = float(d.get("record", 0.0))
	fidati = d.get("fidati", {})
