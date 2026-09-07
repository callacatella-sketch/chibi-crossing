extends RefCounted
## Mini-framework di test dependency-free (nessun addon, nessuna rete).
## I casi di test stanno in tests/cases/test_*.gd ed espongono `func run(t)`.
## Si esegue con:
##   Godot --headless --path . --script res://tests/test_runner.gd

var passes := 0
var failures := 0
var current_file := ""
var _fails: Array[String] = []

# I casi "vivi" (volto, Mochi, economia) hanno bisogno di nodi VERI in scena:
# _ready deve scattare, i materiali esistere, _process girare. Li si mette in
# scena con stage() e il runner li libera a fine caso — così nessun test lascia
# nodi in eredità al successivo.
var _staged: Array[Node] = []


func ok(cond: bool, msg: String) -> void:
	if cond:
		passes += 1
	else:
		failures += 1
		_fails.append("[%s] %s" % [current_file, msg])


func eq(a, b, msg: String) -> void:
	ok(a == b, "%s (atteso %s, ottenuto %s)" % [msg, str(b), str(a)])


func almost(a: float, b: float, msg: String, eps := 0.0001) -> void:
	ok(absf(a - b) <= eps, "%s (atteso ~%s, ottenuto %s)" % [msg, str(b), str(a)])


# ---------------------------------------------------------------- scena viva

## L'albero del runner (il runner stesso È un SceneTree).
func tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


## Mette un nodo in scena e lo prende in carico: verrà liberato a fine caso.
## Restituisce il nodo, così si può incatenare: var m = t.stage(M.new())
func stage(node: Node) -> Node:
	var st := tree()
	if st == null or st.root == null:
		ok(false, "nessun albero di scena disponibile per stage()")
		return node
	st.root.add_child(node)
	_staged.append(node)
	return node


## Libera i nodi messi in scena dal caso appena eseguito. Chiamata dal runner.
## free() e non queue_free(): nel runner non gira alcun frame, una coda di
## cancellazioni non verrebbe mai smaltita.
func cleanup_staged() -> void:
	for n in _staged:
		if is_instance_valid(n):
			n.free()
	_staged.clear()


func report() -> void:
	print("")
	print("==== TEST: %d passati, %d falliti ====" % [passes, failures])
	for f in _fails:
		print("  FAIL: ", f)


## ⚠️ **IL SORGENTE SENZA I COMMENTI — e ce n'è UNA casa sola.**
##
## Un guardiano che cerca una stringa nel sorgente crudo sbaglia in tutti e due
## i versi: chi ha PAGATO un difetto lo racconta nei propri commenti — e allora
## la chiamata vietata ci è NOMINATA, e il guardiano dichiara rotto proprio il
## file che l'ha tolta; e all'inverso un commento che promette una cosa fa
## passare un codice che non la fa.
##
## Toglie anche i commenti IN CODA a una riga di codice, e rispetta le
## virgolette (un `#` dentro una stringa non è un commento). La versione
## ingenua — scartare le righe che *cominciano* con `#` — lascia passare
## `var x = 1  # nome_vietato`, che è esattamente il caso in cui una cura
## nomina la cosa che ha tolto.
##
## ⚠️ Ne esistevano TRE copie (`test_fiato`, `test_dadi`, più una versione
## debole in `test_vento`): la tabella gemella che questo progetto vieta, su
## un ferro che i guardiani usano per giudicare. Adesso sta qui, e tutti la
## chiamano — una lezione ricopiata invecchia.
static func codice(percorso: String) -> String:
	return senza_commenti(FileAccess.get_file_as_string(percorso))


static func senza_commenti(src: String) -> String:
	var out := ""
	for riga in src.split("\n"):
		var pulita := ""
		var in_str := false
		var i := 0
		while i < riga.length():
			var c := riga[i]
			if c == "\"":
				in_str = not in_str
			elif c == "#" and not in_str:
				break
			pulita += c
			i += 1
		out += pulita + "\n"
	return out
