extends SceneTree

## BANCO TEMPORANEO (lente «rovina») — la partita LUNGA.
##
## Fa girare la catena vera della Fase 5 per N pensieri di fila su un
## villaggio vero, e scrive una riga JSON per pensiero. Non giudica niente:
## registra. Il giudizio si fa dopo, in Python, con un oracolo indipendente.
##
## CHIBI_MODELLO=/percorso.gguf CHIBI_OUT=/dir CHIBI_N=110 [CHIBI_COPIE=5]

const FOGLIO := preload("res://scenes/npc/FoglioDelVicino.gd")
const GIUDICE := preload("res://scenes/npc/Giudice.gd")
const DED := preload("res://scenes/npc/Deduzioni.gd")
const SUG := preload("res://scenes/npc/Suggeritore.gd")
const PERCEZIONE := preload("res://scenes/npc/Percezione.gd")
const PENSATOIO := preload("res://scenes/npc/Pensatoio.gd")
const LLM := preload("res://systems/Llm.gd")

const CASE := [Vector2i(2, 4), Vector2i(14, 4), Vector2i(4, 15),
	Vector2i(15, 14), Vector2i(9, 3), Vector2i(3, 10)]
const CESPUGLIO := Vector2i(12, 9)
const PANCA := Vector2i(9, 13)
const PANCA2 := Vector2i(6, 6)
const SOGLIA := 0.35
const MOCHI_VIA := Vector3(-26.0, 0.0, -20.0)

var _vis: Node = null
var _build: Node = null
var _dn: Node = null
var _cuore: Object = null
var _llm: Object = null
var _residenti: Array = []
var _out := ""
var _f: FileAccess = null
var _memoria_sue := {}
var _memoria_villaggio: Array = []
var _copie := 5
var _ultimo_ms := 0.0


func _init() -> void:
	_go()


func _riga(d: Dictionary) -> void:
	if _f != null:
		_f.store_line(JSON.stringify(d))
		_f.flush()


func _go() -> void:
	var percorso := OS.get_environment("CHIBI_MODELLO")
	_out = OS.get_environment("CHIBI_OUT")
	var quanti := int(OS.get_environment("CHIBI_N")) if OS.get_environment("CHIBI_N") != "" else 110
	_copie = int(OS.get_environment("CHIBI_COPIE")) if OS.get_environment("CHIBI_COPIE") != "" \
			else PENSATOIO.COPIE
	if not LLM.disponibile() or percorso == "" or _out == "":
		print("serve un binario llm=yes + CHIBI_MODELLO + CHIBI_OUT")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	_f = FileAccess.open(_out + "/pensieri.jsonl", FileAccess.WRITE)

	await process_frame
	if change_scene_to_file("res://scenes/levels/MainLevel.tscn") != OK:
		print("GUASTO: MainLevel")
		quit(1)
		return
	for _i in 12:
		await process_frame
	var livello := current_scene
	_build = livello.get_node_or_null("BuildSystem")
	_vis = livello.get_node_or_null("Visitors")
	_dn = livello.get_node_or_null("DayNight")
	var player := livello.get_node_or_null("Player") as Node3D
	if _build == null or _vis == null or _dn == null:
		print("GUASTO: nodi")
		quit(1)
		return
	_build.call("set_persist_for_debug", false)
	# ⚠️ IL CICLO RESTA QUELLO VERO (240 s), o `Suggeritore._quando` dice
	# «poco fa» a TUTTO (l'ora della frase si divide per ciclo/24) e due
	# ricordi dello stesso verbo diventano due righe identiche nel prompt —
	# un artefatto del banco, non del gioco. Quello che si blocca e' l'ORA,
	# ripuntata a ogni giro: cosi' nessuno va a dormire.
	_dn.call("set_time", 0.42)
	await create_timer(1.2).timeout

	_vis.call("debug_reset")
	for c in CASE:
		_build.call("place_cell", c, "Letto", 0, false)
		_build.call("place_cell", c, "Tetto", 0, false)
	_build.call("place_cell", CESPUGLIO, "Cespuglio", 0, false)
	_build.call("place_cell", PANCA, "Panchina", 0, false)
	_build.call("place_cell", PANCA2, "Panchina", 0, false)
	_build.call("aggiorna_varchi_ora")
	var letti: Array = _build.call("get_placed_by_name", "Letto")
	print("letti posati: %d su %d" % [letti.size(), CASE.size()])
	for i in CASE.size():
		_vis.call("debug_settle", 4242 + i * 1013, CASE[i])
		await create_timer(0.7).timeout
	_residenti = _vis.get("_residents")
	_cuore = _vis.call("cuore")
	if _residenti.size() < 3 or _cuore == null:
		print("GUASTO: residenti=%d" % _residenti.size())
		quit(1)
		return
	for _i in 30:
		await process_frame
	var nomi := []
	for r in _residenti:
		nomi.append(str((r as Dictionary).get("label", "?")))
	print("villaggio: %s" % ", ".join(nomi))

	# ------------------------------------------------- il motore
	_llm = LLM.apri()
	var prio := int(OS.get_environment("CHIBI_PRIORITA")) \
			if OS.get_environment("CHIBI_PRIORITA") != "" else 1
	if not bool(_llm.call("apri_modello", percorso, {"priorita": prio})):
		print("GUASTO: apri_modello")
		quit(1)
		return
	while int(_llm.call("stato")) == 1:
		await process_frame
	if int(_llm.call("stato")) != 2:
		print("GUASTO: modello non pronto")
		quit(1)
		return
	print("modello aperto")

	await _onda_di_gesti(0, player)

	var t0 := Time.get_ticks_msec()
	var ogni_lettera := int(OS.get_environment("CHIBI_OGNI_LETTERA")) \
			if OS.get_environment("CHIBI_OGNI_LETTERA") != "" else 3
	for giro in quanti:
		# il giocatore lavora sotto i loro occhi: senza, i ricordi scendono
		# sotto soglia (mezza vita 120 s) e il foglio esce vuoto
		_dn.call("set_time", 0.42)
		await _onda_di_gesti(giro, player)
		_dn.call("set_time", 0.42)
		var i := giro % _residenti.size()
		if giro % ogni_lettera == 0:
			await _pensiero_lettera(giro, i)
		await _pensiero_deduzione(giro, i)
		if giro % 5 == 0:
			print("  giro %d/%d — %.1f min" % [giro, quanti,
					float(Time.get_ticks_msec() - t0) / 60000.0])
	_llm.call("chiudi")
	if _f != null:
		_f.close()
	print("FINITO in %.1f min" % [float(Time.get_ticks_msec() - t0) / 60000.0])
	quit(0)


## I GESTI DI MOCHI, dal bus vero della percezione.
func _onda_di_gesti(giro: int, player: Node3D) -> void:
	var verbi := ["annaffia", "raccoglie", "costruisce", "cucina", "taglia",
		"semina", "pesca", "dona"]
	for i in _residenti.size():
		var r: Dictionary = _residenti[i]
		var n := r.get("node") as Node3D
		if n == null or not is_instance_valid(n):
			continue
		var v := str(verbi[(i + giro) % verbi.size()])
		var dove: Vector3 = n.global_position + Vector3(1.6, 0.0, 1.2)
		for _k in 2:
			call_group("percezione", "accaduto", v, dove,
					str(r.get("label", "")) if v == "dona" else "")
			await create_timer(0.35).timeout
	await create_timer(PERCEZIONE.DURATA_SGUARDO + 0.5).timeout
	if player != null:
		player.global_position = MOCHI_VIA


func _stato_mondo() -> Dictionary:
	var meteo = root.get_tree().get_first_node_in_group("weather")
	return {
		"ora": float(_dn.get("time")),
		"stagione": str(_dn.call("season_name")),
		"pioggia": bool(meteo.call("is_raining")) if meteo != null else false,
	}


func _pensiero_lettera(giro: int, i: int) -> void:
	var r: Dictionary = _residenti[i]
	var nome := str(r.get("label", "?"))
	var f: Dictionary = FOGLIO.foglio(_vis, _dn, _cuore, r, "lettera", "Mochi",
			hash(nome) + giro * 7919)
	if f.is_empty():
		_riga({"tipo": "lettera", "giro": giro, "chi": nome, "muto": true})
		return
	var rit: Dictionary = f["ritratto"]
	var bozze := await _genera(int(r["ecs"]), f, 128)
	if bozze.is_empty():
		_riga({"tipo": "lettera", "giro": giro, "chi": nome, "errore": true})
		return
	var mem := {"sue": _memoria_sue.get(nome, []), "villaggio": _memoria_villaggio}
	var scelta: Dictionary = GIUDICE.scegli(Array(bozze), rit, mem)
	var schede := []
	for s in (scelta["schede"] as Array):
		var sd: Dictionary = s
		schede.append({"ok": bool(sd["ok"]), "porta": str(sd["porta"]),
				"perche": str(sd["perche"]), "rarita": float(sd["rarita"])})
	var fatti := []
	for x in SUG.fatti(rit):
		var xx: Dictionary = x
		fatti.append({"riga": int(xx["riga"]), "base": str(xx["base"]),
				"mods": xx["mods"], "forza": str(xx["forza"])})
	var d := {
		"tipo": "lettera", "giro": giro, "chi": nome,
		"bozze": Array(bozze), "scelta": int(scelta["scelta"]),
		"motivo": str(scelta["motivo"]), "schede": schede,
		"lettera": str(scelta["lettera"]), "testo": str(scelta["testo"]),
		"citazioni": SUG.citazioni(rit), "fatti": fatti,
		"mondo": _stato_mondo(), "ms": _ultimo_ms,
		"azione": str(rit.get("azione", "")), "obiettivo": str(rit.get("obiettivo", "")),
	}
	if int(scelta["scelta"]) >= 0:
		var libere := []
		for l in GIUDICE.righe_libere(str(scelta["testo"]), SUG.citazioni(rit)):
			libere.append(str(l))
		d["libere"] = libere
		# LA MEMORIA CRESCE, come in una partita lunga
		var sue: Array = _memoria_sue.get(nome, [])
		sue.append(str(scelta["testo"]))
		_memoria_sue[nome] = sue
		_memoria_villaggio.append(str(scelta["testo"]))
	_riga(d)


func _pensiero_deduzione(giro: int, i: int) -> void:
	var r: Dictionary = _residenti[i]
	var nome := str(r.get("label", "?"))
	var id := int(r["ecs"])
	var f: Dictionary = FOGLIO.foglio_deduzione(_vis, _dn, _cuore, r, "Mochi",
			hash(nome) + giro * 104729)
	if f.is_empty():
		_riga({"tipo": "deduzione", "giro": giro, "chi": nome, "muto": true})
		return
	var rit: Dictionary = f["ritratto"]
	var bozze := await _genera(id, f, 48)
	if bozze.is_empty():
		_riga({"tipo": "deduzione", "giro": giro, "chi": nome, "errore": true})
		return
	var aperte := DED.bozze_da(Array(bozze))
	var fattibili: Array = _vis.call("obiettivi_fattibili", r)
	var mondo := {"fattibili": fattibili}
	var scelta: Dictionary = GIUDICE.scegli_deduzione(aperte, rit, mondo)
	var esito: Dictionary = DED.incassa(_cuore, id, aperte, rit, mondo, SOGLIA)
	var fatti := []
	for x in SUG.fatti(rit):
		var xx: Dictionary = x
		fatti.append({"riga": int(xx["riga"]), "base": str(xx["base"]),
				"mods": xx["mods"], "peso": float((rit.get("pesi", []) as Array)[int(xx["riga"])])
						if (rit.get("pesi", []) as Array).size() > int(xx["riga"]) else -1.0})
	var d := {
		"tipo": "deduzione", "giro": giro, "chi": nome,
		"bozze": Array(bozze), "scelta": int(scelta["scelta"]),
		"motivo": str(scelta["motivo"]),
		"indice": int(esito["indice"]), "obiettivo": str(esito["obiettivo"]),
		"esito_motivo": str(esito["motivo"]),
		"fattibili": fattibili, "fatti": fatti, "ms": _ultimo_ms,
		"azione": str(rit.get("azione", "")), "obiettivo_corrente": str(rit.get("obiettivo", "")),
	}
	if int(scelta["scelta"]) >= 0:
		var ded: Dictionary = scelta["deduzione"]
		d["perche"] = ded.get("perche", [])
	if int(esito["indice"]) >= 0:
		var corpo := r.get("node") as Node3D
		var pos: Vector3 = corpo.global_position if corpo != null else Vector3.ZERO
		var dove: Vector3 = _cuore.call("deduzione_dove", id, int(esito["indice"]), pos)
		d["ancora"] = [dove.x, dove.y, dove.z]
		d["corpo"] = [pos.x, pos.y, pos.z]
		d["collo"] = bool(corpo.call("collo_ci_arriva", dove)) if corpo != null else false
		d["puo_vedere"] = PERCEZIONE.puo_vedere(corpo, pos, 1.0) if corpo != null else false
	_riga(d)


func _genera(chi: int, f: Dictionary, max_token: int) -> PackedStringArray:
	var b := int(_llm.call("accoda", chi, str(f["sistema"]), str(f["utente"]),
			str(f["grammatica"]),
			{"copie": _copie, "max_token": max_token, "seme": int(f["seme"])}))
	if b == 0:
		return PackedStringArray()
	var t0 := Time.get_ticks_msec()
	var e := {}
	while e.is_empty() and Time.get_ticks_msec() - t0 < 600000:
		await process_frame
		e = _llm.call("raccogli")
	_ultimo_ms = float(Time.get_ticks_msec() - t0)
	return e.get("bozze", PackedStringArray())
