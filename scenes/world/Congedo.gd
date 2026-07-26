extends Node

## Il Congedo e i Ricordi che Restano — Fasi 3, 4 e 5 del Filo Rosso
## (docs/SISTEMA_EMOZIONALE.md). I DATI vivono in Legami.gd; qui vive
## l'orchestrazione: la settimana delle ultime cose, la partenza per il
## Grande Prato, il lutto giocato e la trasformazione — il fiore che non
## esiste da nessun'altra parte, la costellazione, l'anello, il capo.
##
## Le regole cozy della mortalità (non negoziabili):
## - mai casuale né punitiva: solo dopo una lunga vita piena, con una
##   settimana di congedo annunciata;
## - mai durante l'assenza del giocatore (il trigger vive in day_changed,
##   che scatta solo giocando: il congedo aspetta che tu torni);
## - mai due partenze vicine (minimo un ciclo intero di calendario);
## - il villaggio non resta mai vuoto (servono almeno due residenti);
## - impostazione «Prato Eterno»: chi vuole può spegnere le partenze.

const HANDPAINT := preload("res://shaders/handpaint.gdshader")
const UI_BROWN := Color("6a4a3a")
# i racconti dei momenti vivono in Legami.TIPI: una fonte sola
const TIPI := preload("res://scenes/world/Legami.gd").TIPI
# il corpo degli echi-presenza: lo stesso builder dei chibi vivi
const BUILDER := preload("res://scenes/npc/ChibiBuilder.gd")
const DNA_GEN := preload("res://scenes/npc/ChibiDNA.gd")

# quando è tempo: ben oltre l'autunno del Filo (Legami.GIORNI_ANZIANO=40)
const ETA_PARTENZA := 55
# la settimana delle ultime cose: un desiderio al giorno
const GIORNI_CONGEDO := 7
# mai due partenze vicine: almeno un anno di calendario (28 giorni)
const DISTANZA_PARTENZE := 28

## Dove si torna, per ogni tipo di momento del filo. I tipi che non sono
## luoghi da rivivere (oro, addio, partenza) restano fuori apposta.
const LUOGHI := {
	"benvenuto": "casa", "trasloco": "casa", "primo_saluto": "piazza",
	"piatto": "casa", "regalo": "piazza", "festa": "piazza",
	"onsen": "onsen", "desiderio": "casa",
}

## L'ultimo desiderio, raccontato: la riga del toast e della lettera.
const DESIDERI_TESTO := {
	"benvenuto": "rivedere la soglia del primo giorno",
	"trasloco": "sedersi ancora davanti a casa sua",
	"primo_saluto": "una zampina alzata in piazza, come la prima volta",
	"piatto": "sentire il profumo di un piatto davanti a casa",
	"regalo": "tornare dove i regali passavano di zampa in zampa",
	"festa": "la piazza delle feste, un'ultima volta",
	"onsen": "un ultimo bagno alle terme, fianco a fianco",
	"desiderio": "il posto del desiderio esaudito, vicino a casa",
}

const PIAZZA := Vector3(2.5, 0, 5.5)

# il congedo in corso: {nome, label, cell: [x,z], giorno_inizio,
#   esauditi: int, falo_fatto: bool, oggi: {tipo, dove: [x,y,z], fatto}}
var _congedo := {}
var _ultima_partenza := -1

var _daynight: Node3D
var _visitors: Node
var _legami: Node
var _mail: Node
var _build: Node3D
var _sfx

# i fiori-ricordo vivi in scena: nome -> Node3D
var _fiori := {}
# la finestra accesa di chi è partito (per la settimana del lutto)
var _luce: OmniLight3D
# gli echi del ricordo durante il lutto: luogo -> giorno in cui è già brillato
var _echi := {}
var _echo_cd := 0.0
var _conforto_oggi := false
var _rimando_cd := 0.0

var _prompt: PanelContainer
var _prompt_label: Label
var _fiore_vicino := ""     # il nome del fiore a portata di zampa


func _ready() -> void:
	add_to_group("congedo")
	add_to_group("persistable")
	_sfx = get_node_or_null(^"/root/Sfx")
	_build_ui()
	(func():
		_daynight = get_node_or_null("../../DayNight")
		_visitors = get_node_or_null("../../Visitors")
		_mail = get_node_or_null("../../Mail")
		_build = get_tree().get_first_node_in_group("build_system")
		_legami = get_tree().get_first_node_in_group("legami")
		if _daynight and _daynight.has_signal("day_changed"):
			_daynight.day_changed.connect(_nuovo_giorno)
		# i fiori di chi è già partito rinascono dal filo (e la finestra
		# accesa, se il lutto è ancora in corso)
		_ricostruisci_ricordi()).call_deferred()


func _day() -> int:
	return int(_daynight.get("day")) if _daynight else 1


# ------------------------------------------------------------ il cuore puro
# (testabile senza SceneTree: vedi tests/cases/test_filo.gd)

## È tempo di cominciare un congedo? Tutte le regole cozy in una funzione.
static func pronto_al_congedo(giorni_amicizia: int, oggi: int,
		ultima_partenza: int, residenti: int, prato_eterno: bool,
		occupato: bool) -> bool:
	if prato_eterno or occupato:
		return false
	if residenti < 2:
		return false            # il villaggio non resta mai vuoto
	if giorni_amicizia < ETA_PARTENZA:
		return false
	if ultima_partenza >= 0 and oggi - ultima_partenza < DISTANZA_PARTENZE:
		return false            # mai due partenze vicine
	return true


## L'ultimo desiderio del giorno `idx` (0..6): PURO e deterministico, nato
## dai momenti del filo — i tipi nell'ordine in cui la storia li ha
## vissuti, a rotazione. Un filo vuoto sogna comunque casa sua.
static func desiderio_del_giorno(momenti: Array, idx: int) -> Dictionary:
	var tipi := []
	for m in momenti:
		var t := str(m.get("t", ""))
		if t != "" and LUOGHI.has(t) and not t in tipi:
			tipi.append(t)
	if tipi.is_empty():
		tipi = ["trasloco"]
	var tipo: String = tipi[idx % tipi.size()]
	return {"tipo": tipo, "luogo": LUOGHI.get(tipo, "casa"),
			"testo": DESIDERI_TESTO.get(tipo, "un ultimo giro del villaggio")}


# ------------------------------------------------------------ il calendario

func _nuovo_giorno(day: int) -> void:
	_echi.clear()
	_conforto_oggi = false
	# 1) il lutto in corso cammina coi giorni
	if _legami and bool(_legami.call("lutto_attivo")):
		_giorno_di_lutto(day)
		return
	# 2) il congedo in corso avanza: un desiderio al giorno, poi l'alba
	if not _congedo.is_empty():
		# conflitto fra sistemi: la scala dell'Animo corre per conto suo, e
		# se nel frattempo l'anziana ha DISERTATO (Visitors._congeda l'ha già
		# rimossa, con la lettera di rancore) il congedo si annulla — niente
		# memoriale dorato per chi ha sbattuto la porta
		if _visitors and (_visitors.call("dna_di", str(_congedo["label"])) as Dictionary).is_empty():
			_congedo = {}
			_salva()
			return
		var idx: int = day - int(_congedo["giorno_inizio"])
		if idx >= GIORNI_CONGEDO:
			_partenza()
		else:
			_prepara_desiderio(idx)
		return
	# 3) niente in corso: è tempo per qualcuno?
	_cerca_chi_saluta(day)


func _cerca_chi_saluta(day: int) -> void:
	if _visitors == null or _legami == null:
		return
	var settings := get_node_or_null(^"/root/Settings")
	var eterno: bool = settings != null and bool(settings.get("prato_eterno"))
	var residenti: Array = _visitors.get("_residents")
	var anziano := {}
	var anziano_giorni := -1
	for r in residenti:
		if str(r.get("species", "")) != "chibi":
			continue
		var nome := str((r.get("dna", {}) as Dictionary).get("name", ""))
		var g: int = int(_legami.call("giorni_di_amicizia", nome))
		if g > anziano_giorni:
			anziano_giorni = g
			anziano = r
	if anziano.is_empty():
		return
	if not pronto_al_congedo(anziano_giorni, day, _ultima_partenza,
			residenti.size(), eterno, not _congedo.is_empty()):
		return
	_inizia_congedo(anziano)


func _inizia_congedo(r: Dictionary) -> void:
	var nome := str((r.get("dna", {}) as Dictionary).get("name", ""))
	var label := str(r.get("label", ""))
	var cell: Vector2i = r.get("cell", Vector2i.ZERO)
	_congedo = {"nome": nome, "label": label, "cell": [cell.x, cell.y],
			"giorno_inizio": _day(), "esauditi": 0, "falo_fatto": false,
			"oggi": {}}
	# il Gufo scrive a Mochi: è LEI ad accompagnare le ultime cose
	if _mail:
		_mail.call("queue_letter", {"from": "Il Gufo",
			"text": "%s sente che è quasi tempo di partire\nper il Grande Prato. Vuole salutare il mondo:\naccompagnala tu, un desiderio al giorno.\nSarà la settimana più piena di tutte." % label,
			"gift": false})
	_toast("🍂 Per %s comincia la settimana delle ultime cose." % label)
	_prepara_desiderio(0)
	_salva()


func _prepara_desiderio(idx: int) -> void:
	var momenti: Array = _legami.call("momenti_di", str(_congedo["nome"])) \
			if _legami else []
	var d := desiderio_del_giorno(momenti, idx)
	var dove := _risolvi_luogo(str(d["luogo"]))
	_congedo["oggi"] = {"tipo": d["tipo"], "dove": [dove.x, dove.y, dove.z],
			"fatto": false, "testo": d["testo"]}
	_toast("Oggi %s vorrebbe: %s. Raggiungila là." %
			[_congedo["label"], d["testo"]])
	if _visitors:
		_visitors.call("manda", str(_congedo["label"]), dove)
	_salva()


## Dal nome del luogo alle coordinate di OGGI (il mondo cambia: si
## ricalcola ogni volta, coi fallback sempre pieni).
func _risolvi_luogo(luogo: String) -> Vector3:
	match luogo:
		"onsen":
			var onsen := get_tree().get_first_node_in_group("onsen") as Node3D
			if onsen:
				return onsen.global_position + Vector3(-2.2, 0, 1.6)
		"casa":
			var cell: Array = _congedo.get("cell", [0, 0])
			return Vector3(float(cell[0]) + 0.8, 0, float(cell[1]) + 1.1)
		"piazza":
			return PIAZZA
	var albero := get_tree().get_first_node_in_group("grande_albero") as Node3D
	if albero:
		return albero.global_position + Vector3(1.6, 0, 1.2)
	return PIAZZA


func _process(delta: float) -> void:
	_rimando_cd -= delta
	_echo_cd -= delta
	_tick_congedo()
	_tick_lutto()
	_update_prompt()


# il giro delle ultime cose: l'anziana aspetta al posto del ricordo; se
# Mochi la raggiunge lì, il desiderio è esaudito — un momento d'ORO
func _tick_congedo() -> void:
	if _congedo.is_empty() or _visitors == null:
		return
	var oggi: Dictionary = _congedo.get("oggi", {})
	var label := str(_congedo["label"])
	var node: Node3D = _visitors.call("node_di", label)
	if node == null or not is_instance_valid(node):
		return
	if not oggi.is_empty() and not bool(oggi.get("fatto", false)):
		var dove_a: Array = oggi.get("dove", [0, 0, 0])
		var dove := Vector3(float(dove_a[0]), float(dove_a[1]), float(dove_a[2]))
		# se l'agenda l'ha distratta, la si rimanda al suo posto (con calma)
		if node.global_position.distance_to(dove) > 3.2 and _rimando_cd <= 0.0:
			_rimando_cd = 18.0
			_visitors.call("manda", label, dove)
		# Mochi è arrivata da lei, nel posto giusto: esaudito
		var player := get_node_or_null("../../Player") as Node3D
		if player and node.global_position.distance_to(dove) <= 3.2 \
				and player.global_position.distance_to(node.global_position) < 2.6:
			_esaudito(node, oggi)
	# l'ultima sera: il falò con tutti i vicini, il Chibiese sottovoce
	var idx: int = _day() - int(_congedo["giorno_inizio"])
	if idx == GIORNI_CONGEDO - 1 and not bool(_congedo.get("falo_fatto", false)) \
			and _daynight and float(_daynight.get("time")) >= 0.66 \
			and float(_daynight.get("time")) < 0.82:
		_congedo["falo_fatto"] = true
		_visitors.call("gather_fire")
		_toast("Stasera, al falò: tutto il villaggio è con %s." % label)
		node.call("speak", ["amico", "grazie", "~"], "triste")
		_salva()


func _esaudito(node: Node3D, oggi: Dictionary) -> void:
	oggi["fatto"] = true
	_congedo["esauditi"] = int(_congedo.get("esauditi", 0)) + 1
	if _legami:
		_legami.call("momento", str(_congedo["nome"]), "oro",
				str(oggi.get("testo", "")))
	_toast("✨ Desiderio esaudito: %s. Un momento d'oro sul filo." %
			str(oggi.get("testo", "")))
	var player := get_node_or_null("../../Player") as Node3D
	if player:
		node.call("face_towards", player.global_position)
	node.call("speak", ["grazie", "amico"], "felice")
	node.call("_spawn_heart")
	if _sfx:
		_sfx.place_ok()
	_salva()


# ------------------------------------------------------------- la partenza

func _partenza() -> void:
	var nome := str(_congedo["nome"])
	var label := str(_congedo["label"])
	var cell: Array = _congedo.get("cell", [0, 0])
	var dna: Dictionary = _visitors.call("dna_di", label) if _visitors else {}
	var momenti: Array = _legami.call("momenti_di", nome) if _legami else []
	var oro := 0
	for m in momenti:
		if str(m.get("t", "")) == "oro":
			oro += 1

	# la lettera sul letto: l'accessorio piegato e le sue parole
	if _mail:
		var testo := "Sono partita all'alba, col cappello in zampa.\nPorto con me %d momenti del nostro filo" % momenti.size()
		if oro > 0:
			testo += ",\ne i %d d'oro dell'ultima settimana" % oro
		testo += ".\nTi lascio il mio ricordino: portalo tu.\nNon serbo che gratitudine. — %s" % nome
		_mail.call("queue_letter", {"from": label, "text": testo, "gift": true})

	# la trasformazione (Fase 5): capo, costellazione, anello, fiore
	var wr := get_tree().get_first_node_in_group("guardaroba")
	if wr and not dna.is_empty():
		wr.call("unlock_ricordo", nome, Color(str(dna.get("dress", "f2a9bc"))))
	var stelle := get_tree().get_first_node_in_group("stelle")
	if stelle and stelle.has_method("memorial"):
		stelle.call("memorial", nome, int(dna.get("seed", nome.hash())))
	var gtree := get_tree().get_first_node_in_group("grande_albero")
	if gtree:
		gtree.call("engrave", "❀", "%s è partito per il Grande Prato" % label)
	var fiore := {"x": float(cell[0]) + 0.7, "z": float(cell[1]) + 0.9,
			"dress": str(dna.get("dress", "f2a9bc")),
			"fur": str(dna.get("fur", "e8d5b8")),
			"petali": 5 + absi(int(dna.get("seed", 0))) % 4}
	if _legami:
		_legami.call("momento", nome, "partenza", "")
		# il DNA parte col filo: gli echi del lutto rivestiranno il suo corpo
		_legami.call("segna_partito", nome, fiore, dna)
	_spawn_fiore(nome, fiore)
	_accendi_finestra(Vector3(float(cell[0]), 0, float(cell[1])))

	# il lutto comincia: chi resta ha bisogno di un pensiero, uno a uno
	var da_consolare := []
	if _visitors:
		for r in _visitors.get("_residents"):
			var l := str(r.get("label", ""))
			if l != "" and l != label:
				da_consolare.append(l)
		_visitors.call("parte_per_il_grande_prato", label)
	if _legami:
		_legami.call("inizia_lutto", nome, da_consolare)

	_toast("🌸 %s è partita per il Grande Prato, con la valigia piccola.\nDavanti a casa sua è sbocciato un fiore mai visto." % label)
	_ultima_partenza = _day()
	_congedo = {}
	_salva()


# ---------------------------------------------------------------- il lutto
# (Fase 4) GIOCATO, non raccontato: gli echi nei luoghi dei momenti, la
# finestra accesa, il raduno della prima sera, e i vicini che vengono a
# consolare Mochi. Non c'è un bottone per superarlo: passa coi giorni.

func _giorno_di_lutto(day: int) -> void:
	var l: Dictionary = _legami.call("lutto")
	var nome := str(l.get("nome", ""))
	var trascorsi: int = day - int(l.get("giorno_inizio", day))
	if trascorsi >= int(l.get("giorni", 3)):
		# il lutto si chiude: chi non ha mai ricevuto un pensiero se lo
		# ricorda (è l'indifferenza a ferire, non la perdita)
		var ignorati: Array = _legami.call("fine_lutto")
		if _visitors:
			for label in ignorati:
				_visitors.call("lutto_di", str(label), nome)
		_spegni_finestra()
		_toast("Il villaggio riprende piano il suo respiro. %s è nei fiori, nelle stelle, negli anelli." % nome)
		_salva()
		return
	if trascorsi == 0:
		# la prima sera: tutti al Grande Albero, in silenzio
		_toast("Stasera il villaggio si raccoglie al Grande Albero.")
	else:
		_toast("Il villaggio è più silenzioso, senza %s." % nome)


func _tick_lutto() -> void:
	if _legami == null or not bool(_legami.call("lutto_attivo")):
		return
	var player := get_node_or_null("../../Player") as Node3D
	if player == null or _daynight == null:
		return
	var t: float = float(_daynight.get("time"))
	var l: Dictionary = _legami.call("lutto")
	# la prima sera: il raduno al Grande Albero
	if _day() == int(l.get("giorno_inizio", -99)) and t >= 0.7 and t < 0.85 \
			and not _echi.has("__raduno"):
		_echi["__raduno"] = true
		var albero := get_tree().get_first_node_in_group("grande_albero") as Node3D
		if albero and _visitors:
			for r in _visitors.get("_residents"):
				var node := r.get("node") as Node3D
				if node and is_instance_valid(node) and not node.call("is_hidden"):
					r["next_act"] = 9999.0
					node.call("do_routine", "sniff", albero.global_position +
							Vector3(randf_range(-1.8, 1.8), 0, randf_range(0.8, 2.4)),
							albero.global_position)
	# la sera, un amico viene a consolare Mochi (una premura al giorno)
	if t >= 0.66 and t < 0.9 and not _conforto_oggi and _visitors:
		_conforto_oggi = bool(_visitors.call("conforta_mochi", "lutto"))
	# gli echi del ricordo: passando dove i momenti sono accaduti, un
	# luccichio aspetta Mochi (una volta per luogo al giorno)
	if _echo_cd > 0.0:
		return
	_echo_cd = 2.0
	var nome := str(l.get("nome", ""))
	for luogo in _luoghi_del_ricordo(nome):
		var chiave := str(luogo[0])
		if _echi.has(chiave):
			continue
		var pos: Vector3 = luogo[1]
		if player.global_position.distance_to(pos) < 2.2:
			_echi[chiave] = true
			# non un luccichio: una PRESENZA — la sagoma di chi è partito,
			# seduta un attimo dove il momento accadde, rivolta a Mochi
			_eco_presenza(nome, pos, player.global_position)
			_toast("❀ Per un attimo, %s è lì di nuovo — %s." % [nome, str(luogo[2])])
			if _sfx:
				_sfx.play("select", -18.0, 0.85)
			return


## Il corpo per l'eco: il DNA salvato alla partenza, oppure — per i
## salvataggi di prima degli echi-presenza — un corpo rigenerato dal nome
## e tinto coi colori del fiore-ricordo. PURA e deterministica: la stessa
## partenza rimette in scena SEMPRE la stessa presenza.
static func dna_fantasma(nome: String, fiore: Dictionary, salvato: Dictionary) -> Dictionary:
	if not salvato.is_empty():
		return salvato
	var dna: Dictionary = DNA_GEN.generate(nome.hash())
	dna["name"] = nome
	if fiore.has("dress"):
		dna["dress"] = str(fiore["dress"])
		dna["dress2"] = Color(str(fiore["dress"])).lightened(0.25).to_html(false)
	if fiore.has("fur"):
		dna["fur"] = str(fiore["fur"])
	return dna


## L'ECO COME PRESENZA. La mesh vera del chibi partito (stesso builder
## dei vivi), vestita di un materiale-fantasma additivo: traslucida e
## morbida, si abbassa seduta con le gambette raccolte e il capo appena
## chino, rivolta verso Mochi. Respira per due secondi, poi si scioglie
## nel luccichio di sempre — che ora è un congedo, non l'evento.
func _eco_presenza(nome: String, pos: Vector3, verso: Vector3) -> void:
	var dna := dna_fantasma(nome, _legami.call("fiore_di", nome),
			_legami.call("dna_ricordo", nome))
	var parts: Dictionary = BUILDER.build(dna)
	var root := parts["root"] as Node3D
	var eco := Node3D.new()
	add_child(eco)
	eco.global_position = pos
	eco.add_child(root)
	# rivolta a Mochi: è a lei che appare (il rig nudo del builder guarda
	# +z: verificato a schermo — con la convenzione di Mochi dava le spalle)
	var dir := (verso - pos) * Vector3(1, 0, 1)
	if dir.length() > 0.01:
		dir = dir.normalized()
		eco.rotation.y = atan2(dir.x, dir.z)
	# seduta: il corpo si posa, le gambette si raccolgono, il capo si china
	root.position.y -= 0.16
	for gamba in (parts.get("legs", []) as Array):
		(gamba as Node3D).scale.y = 0.45
	if parts.has("head"):
		(parts["head"] as Node3D).rotation.x = 0.1
	# il materiale-fantasma: UNO per tutte le mesh, così la dissolvenza è
	# una sola (additivo: la presenza è fatta di luce, non di corpo)
	var ghost := StandardMaterial3D.new()
	ghost.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ghost.albedo_color = Color(0.98, 0.9, 0.72, 0.0)
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = ghost
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# entra piano, resta seduta sollevandosi di un soffio, si scioglie
	var tw := create_tween()
	tw.tween_property(ghost, "albedo_color:a", 0.17, 0.55) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(eco, "position:y", pos.y + 0.035, 2.1) \
			.set_trans(Tween.TRANS_SINE)
	tw.tween_interval(0.9)
	tw.tween_property(ghost, "albedo_color:a", 0.0, 0.75) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		if is_instance_valid(eco):
			_sparkle(eco.global_position + Vector3(0, 0.6, 0), Color(1.0, 0.88, 0.62))
			eco.queue_free())


## I luoghi dove i momenti col partito sono accaduti: [chiave, pos, racconto].
func _luoghi_del_ricordo(nome: String) -> Array:
	var out := []
	var momenti: Array = _legami.call("momenti_di", nome) if _legami else []
	var visti := {}
	for m in momenti:
		var tipo := str(m.get("t", ""))
		if not LUOGHI.has(tipo) or visti.has(str(LUOGHI[tipo])):
			continue
		visti[str(LUOGHI[tipo])] = true
		out.append([str(LUOGHI[tipo]), _risolvi_luogo_ricordo(str(LUOGHI[tipo]), nome),
				str((TIPI[tipo] as Array)[0])])
	# il fiore è sempre un luogo del ricordo
	if _fiori.has(nome) and is_instance_valid(_fiori[nome]):
		out.append(["fiore", (_fiori[nome] as Node3D).global_position,
				"il suo fiore, che non appassisce"])
	return out


func _risolvi_luogo_ricordo(luogo: String, nome: String) -> Vector3:
	# come _risolvi_luogo, ma "casa" è quella del PARTITO (dal fiore)
	if luogo == "casa" and _fiori.has(nome) and is_instance_valid(_fiori[nome]):
		return (_fiori[nome] as Node3D).global_position
	var salvato: Dictionary = _congedo
	_congedo = {"cell": [0, 0]}
	var pos := _risolvi_luogo(luogo)
	_congedo = salvato
	return pos


## La consolazione (dal saluto T di Visitors, gruppo "congedo"): durante
## un lutto, la zampina alzata a un vicino È il pensiero che aspettava.
func consolato(label: String, _nome_salutato: String) -> void:
	if _legami == null or not bool(_legami.call("lutto_attivo")):
		return
	var nome := str((_legami.call("lutto") as Dictionary).get("nome", ""))
	if bool(_legami.call("consola", label)):
		if _visitors:
			_visitors.call("lutto_di", label, nome, "giocatore")
		_toast("♥ Hai consolato %s: il ricordo di %s adesso pesa meno." % [label, nome])
		# la consolazione È un momento che si annoda: il filo appare
		_legami.call("mostra_filo", label)


# --------------------------------------------------------- la finestra accesa

func _accendi_finestra(pos: Vector3) -> void:
	_spegni_finestra()
	_luce = OmniLight3D.new()
	_luce.light_color = Color(1.0, 0.82, 0.5)
	_luce.omni_range = 3.2
	_luce.light_energy = 1.1
	_luce.shadow_enabled = false
	_luce.position = pos + Vector3(0, 1.1, 0)
	add_child(_luce)


func _spegni_finestra() -> void:
	if _luce and is_instance_valid(_luce):
		_luce.queue_free()
	_luce = null


# --------------------------------------------------------- il fiore-ricordo
# (Fase 5) Unico, generato dai colori di chi è partito, da nessun'altra
# parte nel mondo. Non appassisce mai. Sedendosi accanto, i momenti del
# filo riaffiorano uno a uno.

func _spawn_fiore(nome: String, f: Dictionary) -> void:
	if _fiori.has(nome) and is_instance_valid(_fiori[nome]):
		return
	var root := Node3D.new()
	root.position = Vector3(float(f.get("x", 0)), 0, float(f.get("z", 0)))
	add_child(root)
	_fiori[nome] = root
	var stelo_mat := _pm(Color("7fae72"), Color("689559"))
	var petalo_mat := _pm(Color(str(f.get("dress", "f2a9bc"))),
			Color(str(f.get("dress", "f2a9bc"))).darkened(0.18))
	var cuore_mat := _pm(Color(str(f.get("fur", "e8d5b8"))).lightened(0.1),
			Color(str(f.get("fur", "e8d5b8"))))
	var stelo := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.016
	sm.bottom_radius = 0.024
	sm.height = 0.42
	stelo.mesh = sm
	stelo.material_override = stelo_mat
	stelo.position = Vector3(0, 0.21, 0)
	root.add_child(stelo)
	var corolla := Node3D.new()
	corolla.position = Vector3(0, 0.44, 0)
	corolla.rotation.x = 0.35
	root.add_child(corolla)
	var petali := maxi(4, int(f.get("petali", 6)))
	for i in petali:
		var a := TAU * float(i) / float(petali)
		var petalo := MeshInstance3D.new()
		var pm := SphereMesh.new()
		pm.radius = 0.075
		pm.height = 0.15
		petalo.mesh = pm
		petalo.material_override = petalo_mat
		petalo.scale = Vector3(0.75, 0.3, 1.35)
		petalo.position = Vector3(cos(a) * 0.095, 0, sin(a) * 0.095)
		petalo.rotation.y = -a + PI * 0.5
		corolla.add_child(petalo)
	var cuore := MeshInstance3D.new()
	var cm := SphereMesh.new()
	cm.radius = 0.055
	cm.height = 0.11
	cuore.mesh = cm
	cuore.material_override = cuore_mat
	cuore.scale = Vector3(1, 0.62, 1)
	corolla.add_child(cuore)
	# il dondolio gentile: vivo, per sempre
	var tw := create_tween().set_loops()
	tw.tween_property(corolla, "rotation:z", 0.09, 2.6) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(corolla, "rotation:z", -0.09, 2.6) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	root.add_to_group("fiore_ricordo")


## Al load: i fiori (e la finestra, se il lutto corre ancora) rinascono
## dal filo — i colori vivono lì, il DNA del partito non serve più.
func _ricostruisci_ricordi() -> void:
	if _legami == null:
		return
	for riga in _legami.call("partiti"):
		var nome := str(riga[0])
		var filo: Dictionary = riga[1]
		var f: Dictionary = filo.get("fiore", {})
		if not f.is_empty():
			_spawn_fiore(nome, f)
	if bool(_legami.call("lutto_attivo")):
		var nome_l := str((_legami.call("lutto") as Dictionary).get("nome", ""))
		var fiore: Node3D = _fiori.get(nome_l)
		if fiore and is_instance_valid(fiore):
			_accendi_finestra(fiore.global_position + Vector3(-0.7, 0, -0.9))


# davanti al fiore, i momenti riaffiorano uno a uno
func _riaffiora(nome: String) -> void:
	var momenti: Array = _legami.call("momenti_di", nome) if _legami else []
	if momenti.is_empty():
		_toast("💭 Il fiore di %s ondeggia piano." % nome)
		return
	var quanti := mini(momenti.size(), 5)
	_toast("💭 Accanto al fiore, i ricordi di %s riaffiorano…" % nome)
	for i in quanti:
		@warning_ignore("integer_division")
		var m: Dictionary = momenti[mini(i * momenti.size() / quanti,
				momenti.size() - 1)]
		var racconto := str((TIPI.get(str(m.get("t", "")), ["…"]) as Array)[0])
		get_tree().create_timer(1.6 + 2.0 * i).timeout.connect(func():
			if is_instance_valid(self):
				_toast("   giorno %d — %s" % [int(m.get("d", 0)), racconto]))
	var fiore: Node3D = _fiori.get(nome)
	if fiore and is_instance_valid(fiore):
		_sparkle(fiore.global_position + Vector3(0, 0.55, 0), Color(1.0, 0.85, 0.9))
	if _sfx:
		_sfx.ui_select()


func _unhandled_input(event: InputEvent) -> void:
	if _fiore_vicino != "" and event.is_action_pressed("interact"):
		_riaffiora(_fiore_vicino)
		get_viewport().set_input_as_handled()


func _update_prompt() -> void:
	_fiore_vicino = ""
	var player := get_node_or_null("../../Player") as Node3D
	var cam := get_viewport().get_camera_3d()
	if player == null or cam == null:
		_prompt.visible = false
		return
	var best_d := 1.7
	var best: Node3D = null
	for nome in _fiori:
		var fiore: Node3D = _fiori[nome]
		if fiore == null or not is_instance_valid(fiore):
			continue
		var d: float = player.global_position.distance_to(fiore.global_position)
		if d < best_d:
			best_d = d
			best = fiore
			_fiore_vicino = str(nome)
	if best == null:
		_prompt.visible = false
		return
	var wp: Vector3 = best.global_position + Vector3(0, 1.0, 0)
	if cam.is_position_behind(wp):
		_prompt.visible = false
		return
	_prompt_label.text = "E — ricorda %s" % _fiore_vicino
	_prompt.reset_size()
	var p := cam.unproject_position(wp)
	_prompt.position = p - Vector2(_prompt.size.x * 0.5, _prompt.size.y)
	_prompt.visible = true


# ---------------------------------------------------------------- servizi

func _pm(a: Color, b: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = HANDPAINT
	mat.set_shader_parameter("color_a", a)
	mat.set_shader_parameter("color_b", b)
	mat.set_shader_parameter("noise_scale", 5.0)
	mat.set_shader_parameter("noise_amount", 0.5)
	return mat


func _sparkle(pos: Vector3, color: Color) -> void:
	# la Posta sa già fare i luccichii colorati: si usa la sua mano
	var mail := get_node_or_null("../../Mail")
	if mail and mail.has_method("_sparkle"):
		mail.call("_sparkle", pos, color)


func _toast(text: String) -> void:
	if _visitors:
		_visitors.call("_show_toast", text)


func _salva() -> void:
	var bs := get_tree().get_first_node_in_group("build_system")
	if bs:
		bs.request_save()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 4
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
	_prompt_label.add_theme_color_override("font_color", UI_BROWN)
	_prompt.add_child(_prompt_label)


# ---------------------------------------------------------------- persistenza

func save_extra() -> Dictionary:
	return {"congedo": _congedo, "ultima_partenza": _ultima_partenza}


func load_extra(data: Dictionary) -> void:
	var c: Variant = data.get("congedo")
	if c is Dictionary:
		_congedo = c
	_ultima_partenza = int(data.get("ultima_partenza", -1))


# ---------------------------------------------------------------- debug CLI

func debug_stato() -> Dictionary:
	return {"congedo": _congedo.duplicate(true),
			"ultima_partenza": _ultima_partenza,
			"fiori": _fiori.keys(),
			"lutto": _legami.call("lutto") if _legami else {}}


## Forza l'inizio del congedo per un residente (per la verifica CLI).
func debug_forza_congedo(label: String) -> void:
	if _visitors == null:
		return
	for r in _visitors.get("_residents"):
		if str(r.get("label", "")) == label:
			_inizia_congedo(r)
			return


## Salta dritto alla partenza (per la verifica CLI).
func debug_salta_a_partenza() -> void:
	if not _congedo.is_empty():
		_partenza()
