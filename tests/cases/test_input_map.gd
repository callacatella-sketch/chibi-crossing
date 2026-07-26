extends RefCounted
## LA MAPPA INPUT NON DEVE AVERE TASTI CONTESI.
##
## È già successo due volte: build_rotate e ricordi entrambi su R, poi lavori
## e p2_right entrambi su L (aprire il registro muoveva il secondo giocatore).
## Questo test scandisce le azioni di project.godot e si accende se due azioni
## di GIOCO condividono lo stesso tasto fisico.
##
## Le azioni ui_* restano fuori dal controllo: sono la navigazione dei menu e
## condividono i tasti col movimento per scelta (WASD + frecce).


func run(t) -> void:
	var owner_of := {}
	var conflitti: Array[String] = []
	var azioni := 0
	for p in ProjectSettings.get_property_list():
		var pname = str(p.get("name", ""))
		if not pname.begins_with("input/"):
			continue
		var azione = pname.trim_prefix("input/")
		if azione.begins_with("ui_"):
			continue
		var cfg = ProjectSettings.get_setting(pname)
		if cfg is not Dictionary:
			continue
		azioni += 1
		for ev in cfg.get("events", []):
			if ev is InputEventKey:
				var pk = int((ev as InputEventKey).physical_keycode)
				if pk == 0:
					continue
				if owner_of.has(pk) and owner_of[pk] != azione:
					conflitti.append("tasto %s conteso fra '%s' e '%s'" %
							[OS.get_keycode_string(pk), owner_of[pk], azione])
				owner_of[pk] = azione
	t.ok(azioni >= 10, "azioni di gioco trovate nella mappa (%d)" % azioni)
	t.ok(conflitti.is_empty(), "nessun tasto fisico conteso: %s" % str(conflitti))

	# la regressione appena corretta resta corretta: lavori su N, L al 2° giocatore
	var lav = ProjectSettings.get_setting("input/lavori", {})
	var lav_keys := []
	for ev in lav.get("events", []):
		if ev is InputEventKey:
			lav_keys.append(int((ev as InputEventKey).physical_keycode))
	t.ok(lav_keys.has(KEY_N), "l'azione 'lavori' sta su N")
	t.ok(not lav_keys.has(KEY_L), "l'azione 'lavori' ha lasciato L al secondo giocatore")
