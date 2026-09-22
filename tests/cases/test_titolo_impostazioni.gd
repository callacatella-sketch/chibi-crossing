extends RefCounted
## ⚠️ IL TITOLO AVEVA UN VICOLO CIECO SUL SUO BOTTONE «IMPOSTAZIONI».
##
## `TitleScreen._build_ui` costruisce il pannello con `visible = false`, e
## `_open_settings` spegneva il menù e chiamava `CozyUI.appear(_settings)` —
## che toccava **solo** `modulate.a` e `scale`, mai `visible`. Risultato:
## schermo vuoto, e **nessuna via d'uscita**, perché l'unico modo di tornare
## indietro è il bottone di un pannello che non si vede, e in tutto
## `TitleScreen.gd` non c'è un `ui_cancel`.
##
## MISURATO facendo girare il titolo vero: dopo il clic
## `_settings.visible == false`, `is_visible_in_tree() == false`,
## `_menu.visible == false`, e `modulate.a` era salito a **0.21** — il tween
## stava lavorando su un nodo che nessuno vedeva. E succede sulla **PRIMA
## schermata del gioco**.
##
## ⚠️ IL GEMELLO LO FACEVA GIUSTO: `PauseMenu._show_settings` scrive
## `_settings.visible = true` prima di chiamare `appear`, e ha pure l'uscita
## con ESC. **È quell'asimmetria a dire dov'era il difetto.**
##
## La cura è in due punti, e il secondo chiude la CLASSE: `TitleScreen` fa
## come il suo gemello, e `CozyUI.appear` accende `visible` da sé — perché
## una funzione che si chiama «appare» deve far apparire. Per i dieci
## chiamanti che il nodo lo accendevano già (o che accendono il CONTENITORE)
## è un no-op esatto.
##
## ⚠️ **QUESTO FILE NON APRE IL TITOLO**: costruirlo vuol dire costruire
## anche il diorama 3D, che è metà del villaggio. Si prova la REGOLA
## (`appear` fa apparire) sul nodo vero di `CozyUI`, e il CABLAGGIO di
## `TitleScreen` leggendo la sua funzione — dichiarato: la prova viva di
## quella metà è il banco in `tools/`, non questo caso.

const COZYUI := preload("res://systems/CozyUI.gd")
const UTIL := preload("res://tests/test_util.gd")


func run(t) -> void:
	_appear_fa_apparire(t)
	_il_titolo_accende_il_pannello(t)


## LA REGOLA, sul nodo vero: un `Control` nascosto passato ad `appear` deve
## uscirne VISIBILE. È la cosa che per un pezzo non era vera, ed è l'unica
## metà che si può provare senza mezzo villaggio in scena.
func _appear_fa_apparire(t) -> void:
	var c := Control.new()
	c.visible = false
	c.modulate.a = 0.0
	COZYUI.appear(c, 0.3)
	t.ok(c.visible, "un Control nascosto passato ad appear() esce visibile")
	# e la controprova: uno già visibile non viene toccato al contrario
	var d := Control.new()
	d.visible = true
	COZYUI.appear(d, 0.3)
	t.ok(d.visible, "…e uno già visibile resta visibile (è un no-op)")
	c.free()
	d.free()


## E IL CABLAGGIO: `_open_settings` deve accendere il pannello come fa il suo
## gemello in `PauseMenu`. Si legge il sorgente SPOGLIATO DEI COMMENTI (la
## cura li nomina apposta, e un guardiano ingenuo matcherebbe la spiegazione
## invece del codice), e si guardano le DUE funzioni — così se un domani il
## gemello perde la sua riga, questo caso lo dice.
func _il_titolo_accende_il_pannello(t) -> void:
	for f in [["res://scenes/ui/TitleScreen.gd", "_open_settings"],
			["res://scenes/ui/PauseMenu.gd", "_show_settings"]]:
		var src: String = UTIL.codice(str(f[0]))
		t.ok(src.length() > 200, "%s si legge (%d byte)" % [str(f[0]), src.length()])
		var i := src.find("func %s(" % str(f[1]))
		t.ok(i >= 0, "%s ha %s" % [str(f[0]), str(f[1])])
		if i < 0:
			continue
		var j := src.find("\nfunc ", i + 1)
		var corpo: String = src.substr(i, (j - i) if j > i else -1)
		t.ok(corpo.contains("_settings.visible = true"),
				"%s accende il pannello: senza, il menu si spegne e non appare niente"
						% str(f[1]))
