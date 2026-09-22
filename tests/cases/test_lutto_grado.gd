extends RefCounted
## IL GRADO DEL LUTTO — quanto contava chi se n'è andato.
##
## `Animo.lutto(amico, consolato_da, quanto)` esiste perché una partenza NON
## deve toccare dodici persone allo stesso identico modo: il grado lo scrive
## il libro mastro degli Affetti, non una curva inventata. Il commento sopra
## `Visitors.lutto_di` lo dichiara per iscritto.
##
## ⚠️ **E per un pezzo non è stato vero: valeva ZERO per tutti, sempre.**
## `lutto_di` riceve il NOME del partito e lo rimandava a `label_di_nome()`
## per rifarne una label — ma quando il lutto si chiude
## (`Congedo._giorno_di_lutto`, giorni DOPO la partenza) quel corpo non è più
## in `_residents`: la label tornava `""`, `_nome_da_label("")` cadeva nel suo
## ripiego silenzioso, e `quanto("Vivo", "")` non trovava nessuna riga.
## Nessun errore, nessuna traccia — e il rancore verso il giocatore
## (`lutto_ignorato`), che NON è scalato dal grado, restava intero: il dolore
## inerte e l'accusa piena.
##
## La guardia è appaiata apposta: **lo stesso identico libro mastro, letto
## per un partito e per uno ancora in paese**. Una misura sola non
## distinguerebbe «non contava niente» da «non lo trova più».
## ⚠️ Il registro è QUELLO VERO, col solo `_ready` scavalcato: è l'idioma di
## `test_insieme.Registro`. `lutto_di`, `_affetto_col_nome`, `_nome_da_label`
## e `label_di_nome` restano le funzioni del gioco — se le rifacessimo qui,
## la cura non avrebbe nessun lettore e questa guardia proverebbe sé stessa.
class Registro extends "res://scenes/npc/Visitors.gd":
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)


## Un libro mastro finto che risponde solo per NOME, come quello vero.
class FintiAffetti extends Node:
	var conti := {}
	func quanto(io: String, altro: String) -> float:
		return float(conti.get("%s|%s" % [io, altro], 0.0))


func run(t) -> void:
	_test_il_grado_sopravvive_alla_partenza(t)


func _villaggio(t) -> Dictionary:
	for vecchio in t.tree().get_nodes_in_group("affetti"):
		(vecchio as Node).remove_from_group("affetti")
	var casa := Node3D.new()
	casa.name = "VillaggioLutto"
	t.stage(casa)
	var aff := FintiAffetti.new()
	aff.name = "Affetti"
	casa.add_child(aff)
	aff.add_to_group("affetti")
	var vis = Registro.new()
	vis.name = "Visitors"
	casa.add_child(vis)
	return {"casa": casa, "aff": aff, "vis": vis}


## Mette in scena un residente col suo animo, SENZA passare dal corpo:
## `lutto_di` guarda solo `_animi` e `_residents`.
func _abita(vis, nome: String, label: String) -> RefCounted:
	var animo = load("res://scenes/npc/Animo.gd").new()
	animo.setup({"name": nome, "tratti": {}, "sogno": "casa"})
	(vis.get("_residents") as Array).append({
		"species": "chibi", "label": label, "cell": Vector2i(0, 0),
		"dna": {"name": nome}, "node": null})
	(vis.get("_animi") as Dictionary)[label] = animo
	return animo


func _intensita_del_lutto(animo) -> float:
	for r in (animo.ricordi as Array):
		if str((r as Dictionary).get("tipo", "")) == "lutto":
			return float((r as Dictionary).get("intensita", -1.0))
	return -1.0


func _test_il_grado_sopravvive_alla_partenza(t) -> void:
	var v := _villaggio(t)
	var vis = v["vis"]
	var aff = v["aff"]

	# due che restano, e lo stesso identico affetto verso due persone:
	# una è ancora in paese, l'altra è già partita
	var a := _abita(vis, "Anna", "la volpina Anna")
	var b := _abita(vis, "Bruno", "il gattino Bruno")
	_abita(vis, "Carla", "la coniglietta Carla")     # Carla ABITA ancora qui
	aff.conti["Anna|Partito"] = 0.62
	aff.conti["Bruno|Carla"] = 0.62

	# il caso VERO: chi è partito non è più in `_residents`
	vis.call("lutto_di", "la volpina Anna", "Partito")
	var i_partito := _intensita_del_lutto(a)

	# il caso di controllo: la stessa cifra, per qualcuno ancora in paese
	vis.call("lutto_di", "il gattino Bruno", "Carla")
	var i_presente := _intensita_del_lutto(b)

	t.almost(i_presente, 0.62,
			"il grado di chi è ancora in paese viene dal libro mastro", 1e-6)
	t.ok(i_partito > 0.0,
			"e il lutto per chi è PARTITO non vale zero (%.4f)" % i_partito)
	t.almost(i_partito, i_presente,
			"a parità di affetto, partire non cambia quanto quella persona contava",
			1e-6)

	# e la controprova: chi non conta niente resta a zero, o la cura sarebbe
	# un pavimento travestito da lettura del libro mastro
	var c := _abita(vis, "Dario", "il topolino Dario")
	vis.call("lutto_di", "il topolino Dario", "Sconosciuto")
	t.almost(_intensita_del_lutto(c), 0.0,
			"chi non contava niente resta a zero", 1e-6)
