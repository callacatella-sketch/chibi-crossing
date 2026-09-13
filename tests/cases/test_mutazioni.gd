extends RefCounted
## ⚠️ **UN FILE DI MUTAZIONI CHE SMETTE DI AGGANCIARE NON FA RUMORE.**
##
## `tools/muta.sh` guasta UNA riga per volta e conta le asserzioni rosse: è
## lo strumento con cui questo progetto dimostra che una guardia esiste
## davvero. Ma se il sorgente viene rifattorizzato, il «testo-da» di un
## blocco smette di combaciare, e il banco stampa `SALTATA` e va avanti: da
## quel momento **la guardia che quel blocco doveva provare non è più
## provata, in silenzio**, e lo si scopre solo la prossima volta che qualcuno
## lancia il banco a mano — mesi dopo.
##
## È successo due volte in un giorno solo:
##  · «la scheda si porta dietro l'attore» citava due righe che il
##    rifattorizzamento di `Schema.gd` aveva fatto sparire (`scheda()` adesso
##    chiede il verso una volta sola e ne deriva il modulo);
##  · «il rancore legge il SOMMARIO» e «il rancore smette di leggere il
##    conto» citavano `c["prove"]`, che il merge con `origin/main` ha
##    cambiato in `c["prove_totali"]` — cioè le due mutazioni che
##    sorvegliavano `rancore()` sono morte **nello stesso commit che ne
##    cambiava la semantica**, che è il momento peggiore possibile.
##
## Questo caso costa una passata su una dozzina di file di testo e rende la
## rottura RUMOROSA: rossa nella suite, il giorno stesso.
##
## ⚠️ **E controlla anche l'AMBIGUITÀ**, non solo l'assenza: `muta.sh`
## rifiuta un blocco il cui testo-da compare più di una volta, perché
## `replace(..., 1)` prenderebbe la prima occorrenza — magari dentro un
## commento — e la mutazione non sarebbe quella scritta. Anche quella è una
## guardia che smette di provare quel che dice, e va vista qui.


func run(t) -> void:
	_ogni_blocco_aggancia_una_volta_sola(t)


## Lo stesso spezzettamento che fa `muta.sh`: blocchi separati da «=====»,
## e ogni blocco è `nome / file / testo-da / --> / testo-a`. Non è una copia
## che può divergere per caso: se il formato cambia, questo caso diventa
## rosso, che è esattamente quello che deve succedere.
func _blocchi(testo: String) -> Array:
	var out: Array = []
	for b in testo.split("\n=====\n"):
		if b.strip_edges() == "":
			continue
		var righe: PackedStringArray = b.split("\n")
		if righe.size() < 4:
			out.append({"rotto": b})
			continue
		var resto: String = "\n".join(Array(righe).slice(2))
		var parti: PackedStringArray = resto.split("\n-->\n")
		if parti.size() != 2:
			out.append({"rotto": b})
			continue
		out.append({"nome": righe[0], "file": righe[1], "da": parti[0]})
	return out


func _ogni_blocco_aggancia_una_volta_sola(t) -> void:
	var dir := DirAccess.open("res://tools")
	t.ok(dir != null, "res://tools si apre")
	if dir == null:
		return
	var elenchi: Array = []
	for f in dir.get_files():
		if f.begins_with("muta_") and f.ends_with(".txt"):
			elenchi.append("res://tools/" + f)
	elenchi.sort()
	# ⚠️ se un domani questi file venissero spostati o rinominati, un caso che
	# non trova NIENTE resterebbe verde: la prima asserzione è quella che
	# impedisce a questo test di diventare un ritratto.
	t.ok(elenchi.size() >= 3,
			"ci sono elenchi di mutazioni da sorvegliare (%d trovati)"
			% elenchi.size())
	var blocchi_totali := 0
	for e in elenchi:
		var testo := FileAccess.get_file_as_string(e)
		t.ok(testo != "", "%s si legge" % e)
		for b in _blocchi(testo):
			if b.has("rotto"):
				t.ok(false, "%s: un blocco non ha la forma nome/file/da/-->/a"
						% e)
				continue
			blocchi_totali += 1
			var src: String = str(b["file"])
			var sorgente := FileAccess.get_file_as_string("res://" + src)
			t.ok(sorgente != "",
					"%s · «%s»: il file %s esiste" % [e, b["nome"], src])
			if sorgente == "":
				continue
			var n: int = sorgente.count(str(b["da"]))
			t.eq(n, 1,
					("%s · «%s»: il testo-da compare %d volte in %s "
					+ "(0 = ancora morta, la mutazione non prova piu' niente; "
					+ ">1 = ambiguo, muta.sh la rifiuta)")
					% [e, b["nome"], n, src])
	t.ok(blocchi_totali >= 40,
			"i blocchi sorvegliati sono tanti quanti ne esistono (%d)"
			% blocchi_totali)
