extends Node

## ACCOMPAGNARE — il verbo che disinnesca una paura appresa.
##
## Il Limbico sa già fare la cosa più difficile: un residente mandato
## novanta giorni alla catasta si prende un MARCHIO su quel posto, e da
## allora ci gira al largo (`Limbico.evita`). E sa già dire il perché
## (`perche_evita`), e sa già guarire (`visita_serena`): tornarci senza
## che accada nulla spegne la paura. Era tutto scritto, testato — e senza
## un verbo, quindi invisibile.
##
## La trappola della paura appresa è che si autoalimenta: chi evita un
## posto non ci torna mai, e non tornandoci non scopre mai che adesso non
## succede niente. Da solo, quel marchio non si spegne più. Serve
## qualcuno che ci vada insieme.
##
## COME SI GIOCA:
##  1. ti avvicini a un vicino che gira al largo da qualche parte. Il
##     prompt te lo dice, e lui — se glielo chiedi — ti dice anche PERCHÉ;
##  2. E, e ci andate insieme. Lui cammina, ma sulla soglia si ferma:
##     postura «esita», una nuvoletta con tre punti. Aspetta te;
##  3. gli resti accanto. E NON SUCCEDE NIENTE. È tutto qui, e non è poco:
##     l'estinzione è esattamente questo — il tempo passato in un posto
##     temuto senza che il male torni;
##  4. il marchio si dimezza. Bastano poche volte perché quel posto torni
##     un posto qualunque, e il giorno in cui non lo evita più si annoda
##     un momento sul Filo Rosso.
##
## Non c'è nessuna barra e nessun timer a schermo: l'unico segnale è il
## corpo di chi hai accanto. Se ti allontani, la scena si scioglie in
## silenzio — nessun fallimento, nessun rimprovero.

const LEGAMI_TIPO := "coraggio"

## Quanto si resta insieme nel posto perché conti come visita serena.
## Abbastanza da sentire il vuoto, non tanto da annoiarsi.
const SECONDI_INSIEME := 4.5

## Oltre questa distanza dal vicino la scena si scioglie: accompagnare
## vuol dire stare accanto, non mandarlo avanti.
const DISTANZA_MASSIMA := 5.0

## Quanto vicino al posto deve arrivare perché valga come «ci siamo».
const RAGGIO_LUOGO := 3.0

## Il vicino va rimandato ogni tanto: `Visitors.manda` lo trattiene solo
## 45 secondi, poi la sua agenda si riprende lo stato e la scena si
## scioglierebbe da sola mentre il giocatore è ancora lì.
const RINNOVO := 9.0

var _visitors: Node
var _build: Node3D
var _cozy: Node3D
var _player: Node3D
var _legami: Node

# la scena in corso: {label, luogo, fase, t, rinnovo}
var _scena := {}
var _prompt: PanelContainer
var _prompt_label: Label
var _detto_perche := {}     # label|luogo -> true (il perché si dice una volta)


func _ready() -> void:
	add_to_group("accompagna")
	_visitors = get_tree().get_first_node_in_group("visitors")
	_legami = get_tree().get_first_node_in_group("legami")
	_build = get_tree().get_first_node_in_group("build_system")
	_costruisci_prompt()
	(func():
		_player = get_node_or_null("../../Player") as Node3D
		_cozy = get_parent() as Node3D
	).call_deferred()


# ============================================================ le regole pure

## Fra i posti che teme, quello da cui si comincia: il primo che il mondo
## sappia mostrare. PURA: entra la lista dei temuti e quella dei posti che
## hanno una posizione vera, esce il nome del posto (o "").
static func luogo_da_affrontare(temuti: Array, localizzabili: Array) -> String:
	for l in temuti:
		if str(l) in localizzabili:
			return str(l)
	return ""


## Si può contare la visita come serena? Serve che il vicino sia ARRIVATO,
## che il giocatore gli sia ACCANTO, e che sia passato abbastanza tempo
## senza che succeda niente. PURA, e per questo provabile senza aspettare.
static func visita_compiuta(dist_luogo: float, dist_giocatore: float,
		secondi: float) -> bool:
	return dist_luogo <= RAGGIO_LUOGO and dist_giocatore <= DISTANZA_MASSIMA \
			and secondi >= SECONDI_INSIEME


## La scena si scioglie? Solo se il giocatore si è allontanato. Non è un
## fallimento: è che accompagnare qualcuno vuol dire restare.
static func scena_persa(dist_giocatore: float) -> bool:
	return dist_giocatore > DISTANZA_MASSIMA * 1.6


# ============================================================ i posti veri

## Dove sta, nel mondo, un posto che il Limbico conosce solo per nome.
## {} se non si sa: e allora Accompagnare non lo propone — meglio non
## offrire un verbo che non si può mantenere.
func posizione_del_luogo(luogo: String) -> Dictionary:
	match luogo:
		"orto":
			return _primo_pezzo(["Orto", "Aiuola"])
		"cucina":
			return _primo_pezzo(["Camino"])
		"catasta":
			# la catasta non è un pezzo: è dove si taglia la legna, cioè
			# dove stanno gli alberi. Chi si è spaventato spaccando legna
			# si è spaventato lì.
			var vicino: Node3D = null
			var best := INF
			var rif: Vector3 = _player.global_position if _player else Vector3.ZERO
			for a in get_tree().get_nodes_in_group("albero"):
				var n3 := a as Node3D
				if n3 == null or not is_instance_valid(n3):
					continue
				var d: float = rif.distance_to(n3.global_position)
				if d < best:
					best = d
					vicino = n3
			if vicino != null:
				return {"pos": vicino.global_position}
		"bosco":
			if _cozy != null and "CLEARING_CENTER" in _cozy:
				return {"pos": _cozy.get("CLEARING_CENTER")}
			return {"pos": Vector3(-1.0, 0.0, -46.0)}
	return {}


func _primo_pezzo(nomi: Array) -> Dictionary:
	if _build == null:
		return {}
	var rif: Vector3 = _player.global_position if _player else Vector3.ZERO
	var best := INF
	var out := {}
	for nome in nomi:
		for p in _build.call("get_placed_by_name", str(nome)):
			var n3 := p as Node3D
			if n3 == null or not is_instance_valid(n3):
				continue
			var d: float = rif.distance_to(n3.global_position)
			if d < best:
				best = d
				out = {"pos": n3.global_position}
	return out


func _localizzabili() -> Array:
	var out: Array = []
	for l in ["catasta", "orto", "cucina", "bosco"]:
		if not posizione_del_luogo(l).is_empty():
			out.append(l)
	return out


# ============================================================ il prompt

## Il vicino più vicino che gira al largo da qualche posto: [label, luogo].
func _candidato() -> Array:
	if _visitors == null or _player == null:
		return []
	var pp: Vector3 = _player.global_position
	var loc := _localizzabili()
	var best := 2.6
	var out: Array = []
	for r in (_visitors.get("_residents") as Array):
		var label := str(r.get("label", ""))
		if label == "":
			continue
		var nodo := r.get("node") as Node3D
		if nodo == null or not is_instance_valid(nodo):
			continue
		var d: float = pp.distance_to(nodo.global_position)
		if d > best:
			continue
		var temuti: Array = _visitors.call("luoghi_evitati", label)
		var luogo := luogo_da_affrontare(temuti, loc)
		if luogo == "":
			continue
		best = d
		out = [label, luogo]
	return out


func _process(delta: float) -> void:
	if not _scena.is_empty():
		_avanza(delta)
		_aggiorna_prompt(_scena_prompt())
		return
	var c := _candidato()
	if c.is_empty():
		_aggiorna_prompt("")
		return
	_aggiorna_prompt(L10n.tf("E — accompagna %s (%s)",
			[str(c[0]), L10n.t(str(c[1]))]))


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact") or not _scena.is_empty():
		return
	var c := _candidato()
	if c.is_empty():
		return
	get_viewport().set_input_as_handled()
	_comincia(str(c[0]), str(c[1]))


# ============================================================ la scena

func _comincia(label: String, luogo: String) -> void:
	var p := posizione_del_luogo(luogo)
	if p.is_empty():
		return
	_scena = {"label": label, "luogo": luogo, "pos": p["pos"],
			"fase": "cammino", "t": 0.0, "rinnovo": 0.0}
	# IL PERCHÉ, la prima volta: senza questa frase il giocatore vede un
	# vicino che fa un giro strano e pensa a un difetto di percorso
	var chiave := "%s|%s" % [label, luogo]
	if not _detto_perche.has(chiave):
		_detto_perche[chiave] = true
		var animo: RefCounted = _visitors.call("animo_oggetto_di", label)
		if animo != null:
			# il TEMPLATE e il numero separati: la frase si riempie DOPO
			# essere stata tradotta, o in inglese non si troverebbe mai
			var d: Dictionary = animo.limbico.perche_evita_dati(luogo)
			if not d.is_empty():
				_toast("%s: %s." % [label,
						L10n.tf(str(d["testo"]), [int(d["n"])])])
	_manda()
	var nodo := _nodo()
	if nodo != null and nodo.has_method("chat_bubble"):
		nodo.call("chat_bubble", "?")


func _avanza(delta: float) -> void:
	var nodo := _nodo()
	if nodo == null or _player == null:
		_scena = {}
		return
	var dg: float = _player.global_position.distance_to(nodo.global_position)
	if scena_persa(dg):
		# si scioglie in silenzio: nessun rimprovero, nessun fallimento
		if nodo.has_method("chat_bubble"):
			nodo.call("chat_bubble", "…")
		_scena = {}
		return
	var meta: Vector3 = _scena["pos"]
	var dl: float = nodo.global_position.distance_to(meta)
	_scena["rinnovo"] = float(_scena["rinnovo"]) - delta
	if float(_scena["rinnovo"]) <= 0.0:
		_manda()

	match str(_scena["fase"]):
		"cammino":
			if dl <= RAGGIO_LUOGO + 1.2:
				# LA SOGLIA: qui si ferma. È il momento in cui il giocatore
				# deve resistere alla tentazione di tirarlo dentro.
				_scena["fase"] = "soglia"
				_scena["t"] = 0.0
				nodo.set_meta("postura", "esita")
				if nodo.has_method("chat_bubble"):
					nodo.call("chat_bubble", "…")
		"soglia":
			_scena["t"] = float(_scena["t"]) + delta
			# se gli sei accanto, dopo un attimo di esitazione entra
			if dg <= DISTANZA_MASSIMA and float(_scena["t"]) > 1.6:
				_scena["fase"] = "insieme"
				_scena["t"] = 0.0
				_manda()
		"insieme":
			_scena["t"] = float(_scena["t"]) + delta
			if visita_compiuta(dl, dg, float(_scena["t"])):
				_guarisci()


func _guarisci() -> void:
	var label := str(_scena["label"])
	var luogo := str(_scena["luogo"])
	var nodo := _nodo()
	_scena = {}
	var animo: RefCounted = _visitors.call("animo_oggetto_di", label)
	if animo == null:
		return
	var prima: float = float(animo.limbico.carica_di(luogo))
	animo.limbico.visita_serena(luogo)
	var ancora: bool = bool(animo.limbico.evita(luogo))
	if nodo != null and is_instance_valid(nodo):
		nodo.set_meta("postura", "si_illumina")
		if nodo.has_method("speak"):
			nodo.call("speak", ["coraggio", "insieme"], "felice")
		if nodo.has_method("celebrate"):
			nodo.call("celebrate")
	if ancora:
		# non è finita: la paura si è dimezzata, non spenta
		_toast(L10n.tf("Siete stati lì, e non è successo niente. %s respira.",
				[label]))
	else:
		_toast(L10n.tf("%s non gira più al largo. Ci siete tornati insieme, e tanto è bastato.",
				[label]))
		# il giorno in cui una paura si spegne resta sul filo per sempre
		var nome := str(_visitors.call("nome_di_label", label)) if \
				_visitors.has_method("nome_di_label") else ""
		if nome == "":
			nome = _nome_da_label(label)
		if nome != "" and _legami != null:
			_legami.call("momento", nome, LEGAMI_TIPO, luogo)
	var sfx := get_node_or_null(^"/root/Sfx")
	if sfx:
		sfx.call("place_ok")
	# quel gesto vale come gentilezza: scioglie un po' di rancore
	_visitors.call("gesto_gentile", label, "accompagnato", 0.5)
	get_tree().call_group("regista", "note", "socievole")


# ============================================================ utilità

func _nodo() -> Node3D:
	if _scena.is_empty() or _visitors == null:
		return null
	return _visitors.call("node_di", str(_scena["label"])) as Node3D


func _manda() -> void:
	if _scena.is_empty() or _visitors == null:
		return
	_scena["rinnovo"] = RINNOVO
	_visitors.call("manda", str(_scena["label"]), _scena["pos"])


## Il nome dal dna, passando dalla label: le due anagrafi del progetto.
func _nome_da_label(label: String) -> String:
	if _visitors == null:
		return ""
	var dna: Dictionary = _visitors.call("dna_di", label)
	return str(dna.get("name", ""))


func _scena_prompt() -> String:
	match str(_scena.get("fase", "")):
		"cammino":
			return L10n.tf("state andando %s…", [L10n.t(str(_scena["luogo"]))])
		"soglia":
			return L10n.t("si è fermato. Restagli accanto.")
		"insieme":
			return L10n.t("non succede niente. È esattamente il punto.")
	return ""


func _toast(testo: String) -> void:
	if _visitors and _visitors.has_method("_show_toast"):
		_visitors.call("_show_toast", testo)


func _aggiorna_prompt(testo: String) -> void:
	if _prompt == null:
		return
	var nodo: Node3D = null
	if not _scena.is_empty():
		nodo = _nodo()
	else:
		var c := _candidato()
		if not c.is_empty() and _visitors != null:
			nodo = _visitors.call("node_di", str(c[0])) as Node3D
	var cam := get_viewport().get_camera_3d()
	if testo == "" or nodo == null or not is_instance_valid(nodo) or cam == null:
		_prompt.visible = false
		return
	var wp: Vector3 = nodo.global_position + Vector3(0, 1.35, 0)
	if cam.is_position_behind(wp):
		_prompt.visible = false
		return
	_prompt_label.text = testo
	_prompt.reset_size()
	var p := cam.unproject_position(wp)
	_prompt.position = p - Vector2(_prompt.size.x * 0.5, _prompt.size.y)
	_prompt.visible = true


func _costruisci_prompt() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 11
	add_child(layer)
	_prompt = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.98, 0.95, 0.88, 0.92)
	sb.set_corner_radius_all(12)
	sb.border_color = Color(0.62, 0.46, 0.34, 0.5)
	sb.set_border_width_all(2)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	_prompt.add_theme_stylebox_override("panel", sb)
	_prompt.visible = false
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_prompt)
	_prompt_label = Label.new()
	_prompt_label.add_theme_font_size_override("font_size", 13)
	_prompt_label.add_theme_color_override("font_color", Color("6b4a33"))
	_prompt.add_child(_prompt_label)


# ============================================================ debug CLI

func debug_marchia(label: String, luogo := "catasta", quante := 3) -> void:
	var animo: RefCounted = _visitors.call("animo_oggetto_di", label)
	if animo == null:
		print("[accompagna] nessun animo per ", label)
		return
	for i in quante:
		animo.limbico.rivaluta("spavento", "qualcuno", -0.9, luogo)
	print("[accompagna] %s ora evita %s: %s (carica %.2f)"
			% [label, luogo, animo.limbico.evita(luogo),
			animo.limbico.carica_di(luogo)])
