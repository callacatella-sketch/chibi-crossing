extends RefCounted
## ⚠️ I MURI DELLA CHIESA E DELLA BOUTIQUE NON SI DISSOLVEVANO MAI.
##
## `BuildSystem._register` è l'unico scrittore di `_walls`, e passa da
## `WALL_ITEMS` — che era ferma ai tre pezzi del PRIMO COMMIT del repository
## (`git log -S"WALL_ITEMS"` non dà altro). Nel frattempo il catalogo ha
## preso la chiesa, la caserma e la boutique: entrare in una chiesa voleva
## dire **guardare il muro di pietra**, perché dentro non si vedeva niente.
## Non è un dettaglio di resa — quelle categorie esistono per l'interno che
## contengono.
##
## ⚠️ **E LA LISTA RESTA SCRITTA A MANO, dopo averlo provato a derivare.**
## Misurato su tutti e ventuno i pezzi di bordo: la regola «`cols` alto e
## largo quanto la cella» prende i sei muri nuovi e **perde le PORTE** — il
## `cols` di una porta è lo STIPITE (0,16 m), perché ci si deve passare:
## quel dizionario dice dove si CAMMINA, non cosa si VEDE.
##
## Quello che questo caso fa è impedire che la lista resti indietro **da
## sola**: ogni pezzo di bordo con la collisione alta E larga quanto la cella
## è un muro senza discussioni, e deve stare in `WALL_ITEMS`. Un pezzo nuovo
## che ne ha bisogno lo dice qui, invece che sette anni dopo.

const CAT := preload("res://scenes/build/BuildCatalog.gd")
const BS := preload("res://scenes/build/BuildSystem.gd")

## Alto e largo quanto la cella: sotto questi, o non toglie la vista, o è un
## palo. Non sono tarati — sono la misura del «Muro» (2.10 × 1.00) con un
## margine, e il pezzo che ci sta più vicino sotto è la Staccionata (0.95).
const ALTO := 1.8
const LARGO := 0.8


func run(t) -> void:
	var items = CAT.items()
	if items == null or (items as Array).is_empty():
		t.ok(false, "il catalogo si legge (senza, il caso non prova niente)")
		return
	t.ok((items as Array).size() > 100,
			"il catalogo è quello vero (%d pezzi)" % (items as Array).size())

	var mancanti: Array = []
	var bordi := 0
	for it in (items as Array):
		var d: Dictionary = it
		if str(d.get("type", "")) != "edge":
			continue
		bordi += 1
		var h := 0.0
		var w := 0.0
		for cc in (d.get("cols", []) as Array):
			var box: Vector3 = (cc as Array)[0]
			h = maxf(h, box.y)
			w = maxf(w, box.x)
		if h >= ALTO and w >= LARGO and not (str(d.get("name", "")) in BS.WALL_ITEMS):
			mancanti.append(str(d.get("name", "")))

	t.ok(bordi >= 20, "i pezzi di BORDO sono tanti (%d): la scena esiste" % bordi)
	t.eq(mancanti.size(), 0,
			"ogni pezzo alto e largo quanto la cella si dissolve: manca %s"
					% str(mancanti))

	# ⚠️ LA CONTROPROVA, e serve: una lista che contenesse TUTTO passerebbe
	# la riga qui sopra e farebbe sparire staccionate e insegne.
	for nome in ["Staccionata", "Insegna guardia", "Transenna", "Sbarra"]:
		t.ok(not (nome in BS.WALL_ITEMS),
				"«%s» NON è un muro: non deve dissolversi" % nome)

	# e i tre storici ci sono ancora — comprese le PORTE, che la regola
	# derivata perde perché il loro `cols` è lo stipite
	for nome in ["Muro", "Finestra", "Porta"]:
		t.ok(nome in BS.WALL_ITEMS, "«%s» c'è ancora" % nome)
