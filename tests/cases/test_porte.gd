extends RefCounted
## Le porte che si aprono DAVVERO: il cardine ruota via da chi spinge,
## l'anta esiste su ogni varco (Porta del catalogo E casa sull'albero),
## il cigolio è un suono vero, e le porte ascoltano anche i residenti
## (gruppo "passanti") — prima Mochi era l'unico a non fare il fantasma.

const BUILD := preload("res://scenes/build/BuildSystem.gd")
const CATALOGO := preload("res://scenes/build/BuildCatalog.gd")
const SFX := preload("res://audio/Sfx.gd")


func run(t) -> void:
	_test_verso(t)
	_test_ante(t)
	_test_cigolio(t)
	_test_cablaggio_passanti(t)


## Una porta vera si SPINGE: ruota sempre via da chi la attraversa.
func _test_verso(t) -> void:
	t.almost(BUILD.verso_porta(0.8), 1.95, "chi arriva da z>0 la spinge verso -z")
	t.almost(BUILD.verso_porta(-0.8), -1.95, "chi arriva da z<0 la spinge verso +z")
	t.ok(signf(BUILD.verso_porta(1.0)) != signf(BUILD.verso_porta(-1.0)),
			"i due lati aprono in versi opposti: mai un'anta in faccia")


## Ogni varco ha la sua anta col cardine ("Hinge"), pronta per il BuildSystem.
func _test_ante(t) -> void:
	var porta: Node3D = t.stage(CATALOGO._door_wall())
	var hinge := porta.find_child("Hinge", true, false)
	t.ok(hinge != null, "la Porta del catalogo ha il cardine")
	t.ok(hinge.get_child_count() >= 1, "e sul cardine c'è l'anta")
	var albero: Node3D = t.stage(CATALOGO._treehouse())
	var anta := albero.find_child("Hinge", true, false)
	t.ok(anta != null, "anche la casa sull'albero ha l'anta (era un buco)")
	t.ok(anta.position.y > 2.0, "l'anta della casetta sta in quota, sul varco a sud")


## Il cigolio: un'onda vera (stick-slip), registrata nel mazzo dei suoni.
func _test_cigolio(t) -> void:
	var sfx = SFX.new()
	var wav = sfx._gen_cigolio()
	t.ok(wav is AudioStreamWAV and wav.data.size() > 4000,
			"il cigolio del cardine è un suono vero, non un silenzio")
	# lo stick-slip non è un tono piatto: l'onda ha momenti pieni e vuoti
	var picchi := 0
	var quieti := 0
	var dati: PackedByteArray = wav.data
	var passo := 256
	var i := 0
	while i + 1 < dati.size():
		var v: int = absi(dati.decode_s16(i))
		if v > 9000:
			picchi += 1
		elif v < 1200:
			quieti += 1
		i += passo * 2
	t.ok(picchi > 3 and quieti > 3,
			"il cigolio va a strappi: squittii (%d) e pause (%d)" % [picchi, quieti])
	sfx.free()
	var f := FileAccess.open("res://audio/Sfx.gd", FileAccess.READ)
	t.ok(f != null and f.get_as_text().contains("_streams[\"cigolio\"]"),
			"il cigolio è nel mazzo dei suoni (play(\"cigolio\") lo trova)")


## Il cablaggio: i residenti sono "passanti" e le porte li ascoltano.
func _test_cablaggio_passanti(t) -> void:
	var visitor := FileAccess.open("res://scenes/npc/Visitor.gd", FileAccess.READ)
	t.ok(visitor != null and visitor.get_as_text().contains(
			"add_to_group(\"passanti\")"),
			"ogni residente entra nel gruppo dei passanti")
	var build := FileAccess.open("res://scenes/build/BuildSystem.gd", FileAccess.READ)
	var src := build.get_as_text() if build else ""
	t.ok(src.contains("get_nodes_in_group(\"passanti\")"),
			"le porte interrogano i passanti: niente più residenti-fantasma")
	t.ok(src.contains("hinge.global_position"),
			"la soglia si misura sul CARDINE (la casa sull'albero sta in quota)")
	t.ok(src.contains("cigolio"),
			"al passaggio la porta cigola (il suono è cablato)")
