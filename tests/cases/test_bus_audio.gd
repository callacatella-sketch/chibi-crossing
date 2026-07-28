extends RefCounted
## OGNI SUONO SUL SUO BUS.
##
## Il difetto che questo test impedisce non dà errore e non si vede: un
## AudioStreamPlayer senza `.bus` finisce sul Master, quindi resta SORDO
## a ogni cursore tranne il generale. È successo davvero: le voci del
## Chibiese (i vicini, il mercante, la Coop, il coro del concertino) si
## costruivano il player a mano e nessuna assegnava il bus — il cursore
## «Effetti» non le toccava, e nessuno se ne accorgeva perché il suono
## c'era comunque.
##
## Perciò qui si scandagliano i SORGENTI: ogni `AudioStreamPlayer*.new()`
## del gioco deve avere un `.bus =` a portata di mano. E si verifica
## l'albero dei bus, che è la parte che rende il tutto coerente:
##     Voci ─→ Sfx ─→ Master · Music ─→ Master

const SFX := preload("res://audio/Sfx.gd")
const SET := preload("res://systems/Settings.gd")

# quante righe dopo la creazione si accetta l'assegnazione del bus
const FINESTRA := 14


func run(t) -> void:
	_test_albero(t)
	_test_ogni_player_ha_il_bus(t)
	_test_api_bus(t)
	_test_voci_cablate(t)
	_test_cursore(t)


## L'albero dei bus: le Voci sono FIGLIE degli Effetti, non sorelle. Così
## il cursore «Effetti» governa anche loro (che è quello che il giocatore
## si aspetta) e quello «Voci» fa la regolazione fine.
func _test_albero(t) -> void:
	var albero: Array = SET.BUS_ALBERO
	var verso := {}
	for c in albero:
		verso[str(c[0])] = str(c[1])
	t.eq(verso.get("Music", ""), "Master", "la musica va al Master")
	t.eq(verso.get("Sfx", ""), "Master", "gli effetti vanno al Master")
	t.eq(verso.get("Voci", ""), "Sfx",
			"le VOCI passano dagli effetti: il cursore «Effetti» le governa")
	# l'ORDINE conta: un bus non può mandare a uno che non esiste ancora
	var visti := {"Master": true}
	for c in albero:
		t.ok(visti.has(str(c[1])),
				"'%s' manda a '%s', che a quel punto esiste già" % [c[0], c[1]])
		visti[str(c[0])] = true


## La scansione: ogni player creato in GDScript dichiara il suo bus.
func _test_ogni_player_ha_il_bus(t) -> void:
	var re := RegEx.new()
	re.compile("AudioStreamPlayer(2D|3D)?\\.new\\(\\)")
	var trovati := 0
	var orfani: Array = []
	for path in _tutti_gli_script("res://"):
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			continue
		var righe := f.get_as_text().split("\n")
		for i in righe.size():
			if re.search(righe[i]) == null:
				continue
			trovati += 1
			# il nome della variabile appena creata (per accettare sia
			# `p.bus = …` sia `_voice_player.bus = …`)
			var nome := str(righe[i]).split("=")[0].strip_edges() \
					.trim_prefix("var ").strip_edges()
			var ok := false
			for j in range(i, mini(i + FINESTRA, righe.size())):
				var r := str(righe[j])
				if r.contains(".bus = ") or r.contains(".bus=") :
					ok = true
					break
			if not ok:
				orfani.append("%s:%d (%s)" % [path.get_file(), i + 1, nome])
	t.ok(trovati >= 9,
			"la scansione vede i player del gioco (%d)" % trovati)
	t.eq(orfani.size(), 0,
			"nessun player senza bus — finirebbe sul Master, sordo ai cursori: %s"
			% ", ".join(PackedStringArray(orfani)))


## Sfx è la FONTE UNICA del nome del bus: chi fa parlare qualcuno lo
## chiede a lui invece di ricordarselo (e sbagliarselo).
func _test_api_bus(t) -> void:
	var sfx := SFX.new()
	for metodo in ["bus_voci", "bus_sfx", "bus_musica"]:
		t.ok(sfx.has_method(metodo), "Sfx espone %s()" % metodo)
	# il contratto: il bus vero se c'è, il Master se manca. Mai il
	# silenzio, e mai un nome inventato che l'AudioServer rifiuta.
	for coppia: Array in [["Voci", sfx.bus_voci()], ["Sfx", sfx.bus_sfx()],
			["Music", sfx.bus_musica()]]:
		var atteso: String = str(coppia[0]) \
				if AudioServer.get_bus_index(str(coppia[0])) != -1 else "Master"
		t.eq(str(coppia[1]), atteso,
				"bus '%s': il nome vero se esiste, il Master se manca" % coppia[0])
		t.ok(AudioServer.get_bus_index(str(coppia[1])) != -1,
				"il bus restituito ESISTE davvero nell'AudioServer")
	sfx.free()

	# e l'albero è cablato per davvero, non solo dichiarato: qui gli
	# autoload girano, quindi Settings ha già creato i bus. È QUESTA la
	# prova che il cursore «Effetti» arriva alle voci.
	var i_voci := AudioServer.get_bus_index("Voci")
	if i_voci != -1:
		t.eq(AudioServer.get_bus_send(i_voci), &"Sfx",
				"nell'AudioServer VERO le Voci mandano agli Effetti")
		var i_sfx := AudioServer.get_bus_index("Sfx")
		t.eq(AudioServer.get_bus_send(i_sfx), &"Master",
				"…e gli Effetti al Master: la catena è intera")


## Il cablaggio, file per file: le quattro bocche del Chibiese.
func _test_voci_cablate(t) -> void:
	for coppia: Array in [
			["res://scenes/npc/Visitor.gd", "i vicini"],
			["res://scenes/characters/Coop.gd", "la Coop"],
			["res://scenes/world/Calendar.gd", "il mercante"],
			["res://scenes/interact/Concertino.gd", "il coro"]]:
		var src := _sorgente(str(coppia[0]))
		t.ok(src.contains("bus_voci"),
				"%s parlano sul bus delle Voci" % str(coppia[1]))
	# la cassettina del concertino è uno STRUMENTO: va sulla musica
	t.ok(_sorgente("res://scenes/interact/Concertino.gd").contains("bus_musica"),
			"il carillon del concertino sta sulla musica, non sulle voci")

	# E IL MONDO NON È MUSICA. Vento, uccelli e pioggia stavano sul bus
	# «Music»: chi spegneva la colonna sonora restava senza temporale, e
	# chi calava gli «Effetti» sentiva il vento a tutto volume lo stesso.
	var s := _sorgente("res://audio/Sfx.gd")
	var solo_musica := 0
	for riga in s.split("\n"):
		# solo le ASSEGNAZIONI a un player, non l'accessore bus_musica()
		if str(riga).contains(".bus = _bus(\"Music\")"):
			solo_musica += 1
	t.eq(solo_musica, 1,
			"UN solo player sulla musica: il carillon. Vento, uccelli e pioggia sono mondo")
	for corpo: Array in [["_wind", "il vento"], ["_bird", "gli uccelli"],
			["_rain_p", "la pioggia"]]:
		t.ok(s.contains("%s.bus = _bus(\"Sfx\")" % str(corpo[0])),
				"%s stanno sugli Effetti, dove il giocatore li cerca" % str(corpo[1]))


## Il cursore esiste, si applica, si salva e si rilegge: una manopola che
## non fa tutte e quattro le cose è una manopola morta.
func _test_cursore(t) -> void:
	var s := _sorgente("res://systems/Settings.gd")
	t.ok(s.contains("var voci_volume"), "l'impostazione esiste")
	t.ok(s.contains("func set_voci_volume"), "ha il suo setter")
	t.ok(s.contains("_apply_bus(\"Voci\", voci_volume)"),
			"il setter la APPLICA al bus")
	t.ok(s.contains("cfg.set_value(\"audio\", \"voci\""), "si salva")
	t.ok(s.contains("cfg.get_value(\"audio\", \"voci\""), "e si rilegge")
	var p := _sorgente("res://scenes/ui/CozySettingsPanel.gd")
	t.ok(p.contains("set_voci_volume"), "il pannello ha il cursore")
	# e le etichette del pannello passano da L10n: restavano in italiano
	# dentro un gioco che parlava inglese
	t.ok(p.contains("CozyUI.body_label(L10n.t(label)"),
			"le etichette dei cursori si traducono (in un punto solo)")
	var en := _sorgente("res://locale/en/ui.gd")
	for frase in ["Volume generale", "Musica", "Effetti", "Voci",
			"Velocità di Mochi", "Schermo intero", "Riduci animazioni",
			"Indietro", "Qualità grafica"]:
		t.ok(en.contains("\"%s\":" % frase),
				"'%s' ha la sua traduzione inglese" % frase)


func _tutti_gli_script(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir_path)
	if d == null:
		return out
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		var p := dir_path.path_join(n) if dir_path != "res://" else "res://" + n
		if d.current_is_dir():
			if n != "addons" and not n.begins_with("."):
				out.append_array(_tutti_gli_script(p))
		elif n.ends_with(".gd"):
			out.append(p)
		n = d.get_next()
	d.list_dir_end()
	return out


func _sorgente(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f else ""
