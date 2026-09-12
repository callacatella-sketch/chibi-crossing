extends SceneTree
## Il runner CORTO: fa girare UN SOLO caso della suite, per nome.
##
##   CHIBI_CASO=test_due_strade.gd Godot --headless --path . \
##       --script res://tools/prova_un_caso.gd
##
## ⚠️ **NON È UN SECONDO RUNNER, ed è la ragione per cui sta qui e non in
## `tests/`.** Carica l'harness VERO (`tests/test_util.gd`) e il file di caso
## VERO: l'unica cosa che cambia è l'elenco dei file. Un harness riscritto
## sarebbe un doppio, e un doppio che mente è peggio di nessun doppio — questo
## progetto l'ha già pagato col `MotoreFinto`.
##
## Serve alla BATTERIA DI MUTAZIONI: su una macchina carica la suite intera
## costa decine di minuti, e otto mutazioni non si provano. Il verdetto finale
## si dà comunque con la suite intera: questo dice solo dove guardare.
##
## Conserva le tre cose che il runner vero fa e che contano: un caso per
## FRAME (le differite del `_ready` devono trovare il loro nodo), la lingua
## rimessa alla sorgente prima del caso, e la pulizia dei nodi messi in scena.

var _t
var _fname := ""
var _fatto := false


func _initialize() -> void:
	_t = load("res://tests/test_util.gd").new()
	_fname = OS.get_environment("CHIBI_CASO")
	if _fname == "":
		push_error("serve CHIBI_CASO=test_qualcosa.gd")


func _process(_delta: float) -> bool:
	if L10n.lingua_corrente() != L10n.SORGENTE:
		L10n.imposta(L10n.SORGENTE)
	_t.cleanup_staged()
	if _fatto or _fname == "":
		_t.report()
		quit(1 if _t.failures > 0 else 0)
		return true
	_fatto = true
	_t.current_file = _fname
	var script := load("res://tests/cases/" + _fname)
	if script == null or not (script is GDScript) or not script.can_instantiate():
		_t.ok(false, "%s: non compilabile (errore di parse)" % _fname)
		return false
	var caso = script.new()
	if caso.has_method("run"):
		caso.run(_t)
	return false
