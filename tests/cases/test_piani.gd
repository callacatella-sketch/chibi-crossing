extends RefCounted
## L'UFFICIO DEI PIANI, legato al risolutore.
##
## `test_goap_piani` prova il C++ da solo, su stati inventati a mano.
## Questo prova il PONTE: che i nomi che il GDScript spedisce esistano
## davvero di là, che i cinque tempi arrivino nell'ordine giusto, e che la
## scena del recinto esca dalla catena vera — non da una maschera scritta
## a mano per farla uscire.
##
## Due tabelle parallele, in questo progetto, hanno già divorziato in
## silenzio una volta. Questo file è il matrimonio.

const PIANI := preload("res://scenes/npc/Piani.gd")
const BRAIN := preload("res://scenes/npc/VillagerBrain.gd")


func run(t) -> void:
	if not ClassDB.class_exists("EcsMondo"):
		t.ok(false, "EcsMondo non registrata: la GDExtension non è caricata")
		return
	var m = ClassDB.instantiate("EcsMondo")
	_gli_obiettivi(t, m)
	_i_fatti_di_raggiungibilita(t, m)
	_i_cinque_tempi(t, m)
	_il_recinto_dal_vero(t, m)
	_chi_non_ha_piano(t, m)
	m.free()


## Ogni azione che dichiara un obiettivo ne dichiara uno che ESISTE.
func _gli_obiettivi(t, m) -> void:
	for act in PIANI.OBIETTIVO:
		t.ok(str(act) in BRAIN.AZIONI,
				"«%s» è un'azione vera della Fase 2" % act)
		var ob := str(PIANI.OBIETTIVO[act])
		t.ok(int(m.maschera_obiettivo(ob)) != 0,
				"e il suo obiettivo «%s» accende un bit in C++" % ob)
	t.eq(int(m.maschera_obiettivo("provvedi_niente")), 0,
			"un obiettivo inventato non accende niente")


## I cinque fatti di raggiungibilità: esistono, e sono cinque BIT DIVERSI.
## Se due luoghi finissero sullo stesso bit, chiudere il recinto attorno al
## cespuglio spegnerebbe anche la panchina.
func _i_fatti_di_raggiungibilita(t, m) -> void:
	t.eq(PIANI.FATTO_RAGG.size(), PIANI.LUOGHI.size(),
			"ogni luogo ha il suo fatto")
	var visti := {}
	for luogo in PIANI.LUOGHI:
		t.ok(PIANI.FATTO_RAGG.has(luogo), "«%s» ha un fatto dichiarato" % luogo)
		var nome := str(PIANI.FATTO_RAGG[luogo])
		var bit := int(m.maschera_fatti(PackedStringArray([nome])))
		t.ok(bit != 0, "il fatto «%s» esiste in C++" % nome)
		t.ok(not visti.has(bit), "e il bit di «%s» non è di nessun altro" % nome)
		visti[bit] = true


## I CINQUE TEMPI, nell'ordine. Un luogo che non si raggiunge parte
## negativo: è la doppia sicurezza del risolutore.
func _i_cinque_tempi(t, m) -> void:
	var luoghi := []
	for i in PIANI.LUOGHI.size():
		luoghi.append({"ok": true, "metri": float(i + 1) * PIANI.PASSO, "pos": Vector3.ZERO})
	var c: PackedFloat64Array = PIANI.cammino(luoghi)
	t.eq(c.size(), PIANI.LUOGHI.size(), "cinque tempi, uno per luogo")
	for i in c.size():
		t.almost(c[i], float(i + 1), "il tempo del luogo %d è al posto suo" % i, 1e-9)
	# e i cinque nomi ci sono tutti
	t.eq(PIANI.fatti(luoghi).size(), PIANI.LUOGHI.size(),
			"con tutti raggiungibili si accendono tutti i fatti")

	luoghi[0]["ok"] = false
	c = PIANI.cammino(luoghi)
	t.ok(c[0] < 0.0, "un luogo irraggiungibile ha un tempo negativo")
	t.ok(c[1] > 0.0, "e non contagia i vicini")
	t.ok(not (str(PIANI.FATTO_RAGG["cibo"]) in PIANI.fatti(luoghi)),
			"e il suo fatto non si accende")

	# una lista corta non deve rompere niente: il mondo può non aver
	# ancora finito di costruirsi
	var mozza: PackedFloat64Array = PIANI.cammino([])
	t.eq(mozza.size(), PIANI.LUOGHI.size(), "anche senza luoghi i tempi sono cinque")
	for v in mozza:
		t.ok(v < 0.0, "e sono tutti «non si arriva»")


## LA SCENA, dal ponte in giù. Si costruisce lo stato come lo costruisce
## `_fatti_di` — dai NOMI, mai da un numero — e si guarda che catena esce.
func _il_recinto_dal_vero(t, m) -> void:
	var luoghi := []
	for i in PIANI.LUOGHI.size():
		luoghi.append({"ok": true, "metri": 4.0, "pos": Vector3.ZERO})

	# 1) IL CESPUGLIO C'È E CI SI ARRIVA: si va al cespuglio.
	var nomi := ["spuntino_vicino"]
	nomi.append_array(PIANI.fatti(luoghi))
	var stato := int(m.maschera_fatti(PackedStringArray(nomi)))
	var ob := int(m.maschera_obiettivo(str(PIANI.OBIETTIVO["spuntino"])))
	var passi: PackedInt32Array = m.pianifica(stato, ob, PIANI.cammino(luoghi))
	t.eq(passi.size(), 2, "il piano è di due gesti")
	t.eq(int(passi[0]), int(m.indice_operatore("vai_al_cibo")), "si va al cespuglio")
	t.eq(int(passi[1]), int(m.indice_operatore("sgranocchia")), "e si sgranocchia")

	# 2) IL GIOCATORE CHIUDE IL RECINTO. Il cespuglio è ancora lì — quello
	#    che cambia è una cosa sola: non ci si arriva.
	luoghi[PIANI.LUOGHI.find("cibo")]["ok"] = false
	nomi = ["spuntino_vicino"]
	nomi.append_array(PIANI.fatti(luoghi))
	stato = int(m.maschera_fatti(PackedStringArray(nomi)))
	passi = m.pianifica(stato, ob, PIANI.cammino(luoghi))
	t.eq(passi.size(), 2, "il piano resta di due gesti")
	t.eq(int(passi[0]), int(m.indice_operatore("vai_alla_lavagna")),
			"ma adesso si va alla Lavagna…")
	t.eq(int(passi[1]), int(m.indice_operatore("chiedi_cibo")),
			"…e si chiede da mangiare a Mochi: È LA SCENA DELLA FASE 3")

	# 3) E SE ANCHE LA LAVAGNA NON SI RAGGIUNGE (o c'è già un biglietto di
	#    questo vicino), non si inventa niente: nessun piano.
	luoghi[PIANI.LUOGHI.find("lavagna")]["ok"] = false
	nomi = ["spuntino_vicino"]
	nomi.append_array(PIANI.fatti(luoghi))
	stato = int(m.maschera_fatti(PackedStringArray(nomi)))
	passi = m.pianifica(stato, ob, PIANI.cammino(luoghi))
	t.ok(passi.is_empty(), "senza strade non si consegna un piano a metà")

	# 4) LA REGOLA CHE TIENE IN PIEDI LA SCENA: finché al cespuglio ci si
	#    arriva, alla Lavagna NON ci si va. Altrimenti i vicini passerebbero
	#    la giornata a chiedere invece che a vivere.
	luoghi[PIANI.LUOGHI.find("cibo")]["ok"] = true
	luoghi[PIANI.LUOGHI.find("lavagna")]["ok"] = true
	nomi = ["spuntino_vicino"]
	nomi.append_array(PIANI.fatti(luoghi))
	stato = int(m.maschera_fatti(PackedStringArray(nomi)))
	for costo in [0.5, 4.0, 20.0]:
		var lu := luoghi.duplicate(true)
		lu[PIANI.LUOGHI.find("cibo")]["metri"] = costo * PIANI.PASSO
		passi = m.pianifica(stato, ob, PIANI.cammino(lu))
		t.eq(int(passi[0]), int(m.indice_operatore("vai_al_cibo")),
				"a %.1f s di cammino si va ancora al cespuglio, non a chiedere" % costo)


## Le azioni SENZA piano restano senza piano: non è una dimenticanza da
## riempire un giorno, è che non si pianifica su una cosa che cammina.
func _chi_non_ha_piano(t, m) -> void:
	for act in BRAIN.AZIONI:
		if PIANI.ha_obiettivo(str(act)):
			continue
		t.ok(not PIANI.OBIETTIVO.has(str(act)),
				"«%s» non ha obiettivo, e va bene così" % act)
	t.ok(PIANI.ha_obiettivo("spuntino"), "ma «spuntino» ce l'ha")
	t.ok(not PIANI.ha_obiettivo("quattro_chiacchiere"),
			"e «quattro_chiacchiere» no: dipende da dove sta andando un altro")
