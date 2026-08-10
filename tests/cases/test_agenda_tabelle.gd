extends RefCounted
## LE FONTI UNICHE FRA LE DUE LINGUE.
##
## Il motore di utilità vive in C++, ma i NOMI restano in GDScript: le
## azioni in `VillagerBrain.AZIONI`, i bisogni nelle chiavi di `needs`, i
## fatti in `Visitors._fatti_di`. Il C++ ne tiene solo la traduzione
## nome→indice.
##
## Due tabelle parallele sono esattamente il modo in cui questo progetto ha
## già visto divergere una cosa in silenzio (la scala della ribellione).
## Qui si legano: **aggiungere un'azione, un bisogno o un fatto di là senza
## insegnarlo di qua fa diventare la suite ROSSA**, invece di far decidere
## ai vicini sul bisogno sbagliato senza che nessuno se ne accorga.

const BRAIN := preload("res://scenes/npc/VillagerBrain.gd")
const VISITORS := preload("res://scenes/npc/Visitors.gd")


func run(t) -> void:
	if not ClassDB.class_exists("EcsMondo"):
		t.ok(false, "EcsMondo non registrata: la GDExtension non è caricata")
		return
	var m = ClassDB.instantiate("EcsMondo")
	_le_azioni(t, m)
	_i_bisogni(t, m)
	_i_fatti(t, m)
	_le_azioni_le_sa_recitare(t, m)
	m.free()


## Ogni azione dichiarata in GDScript ha lo STESSO indice in C++, e nessuna
## si sovrappone. L'ordine conta: è con quello che il dado attraversa il
## ponte, e un rimescolamento darebbe a ognuno il dado di un altro.
func _le_azioni(t, m) -> void:
	t.eq(BRAIN.AZIONI.size(), 8, "le azioni sono otto")
	for i in BRAIN.AZIONI.size():
		t.eq(m.indice_azione(str(BRAIN.AZIONI[i])), i,
				"«%s» è l'azione numero %d anche in C++" % [BRAIN.AZIONI[i], i])
	t.eq(m.indice_azione("azione_inventata"), -1, "un'azione ignota vale -1")
	t.eq(m.indice_azione(""), -1, "e nessuna azione pure")
	# le costanti che il GDScript legge dall'oggetto invece di scrivere a mano
	t.eq(m.AZ_SPUNTINO, 0, "AZ_SPUNTINO vale 0")
	t.eq(m.AZ_GIRONZOLA, 7, "AZ_GIRONZOLA vale 7")
	t.eq(m.AZ_NESSUNA, -1, "AZ_NESSUNA vale -1")


## I bisogni viaggiano sul ponte come cinque double NUDI: se l'ordine di
## qua cambia senza cambiare di là, ogni vicino comincia a decidere sul
## bisogno sbagliato. In silenzio.
func _i_bisogni(t, m) -> void:
	t.eq(BRAIN.BISOGNI.size(), 5, "i bisogni sono cinque")
	for i in BRAIN.BISOGNI.size():
		t.eq(m.indice_bisogno(str(BRAIN.BISOGNI[i])), i,
				"«%s» è il bisogno numero %d anche in C++" % [BRAIN.BISOGNI[i], i])
	t.eq(m.indice_bisogno("fame"), -1, "un bisogno ignoto vale -1")
	# e l'elenco dei nomi combacia con le CHIAVI vere del dizionario, che
	# sono quelle che vengono salvate su disco
	var b: RefCounted = BRAIN.new()
	t.eq(b.needs.size(), BRAIN.BISOGNI.size(),
			"l'elenco dei nomi copre tutte le chiavi di `needs`")
	for k in b.needs:
		t.ok(str(k) in BRAIN.BISOGNI,
				"la chiave salvata «%s» è nell'elenco del ponte" % k)
	# e l'impacchettamento rispetta l'ordine dichiarato
	b.needs["pancino"] = 0.11
	b.needs["cura"] = 0.99
	var p: PackedFloat64Array = b.bisogni_packed()
	t.eq(p.size(), 5, "il pacchetto ha cinque valori")
	t.almost(p[m.indice_bisogno("pancino")], 0.11,
			"e ogni valore sta al posto suo (pancino)", 1e-12)
	t.almost(p[m.indice_bisogno("cura")], 0.99, "e (cura)", 1e-12)


## I fatti del mondo: ogni nome che il GDScript produce deve accendere un
## bit, e bit distinti. Un fatto che non accende niente è un'azione che non
## diventa mai fattibile — e non lo direbbe nessuno.
func _i_fatti(t, m) -> void:
	var nomi := ["mattina", "sera_stellata", "aiuola_da_annaffiare",
			"spuntino_vicino", "amico_in_giro", "regia",
			"meraviglia_posto", "regia_pronta"]
	var visti := {}
	var somma := 0
	for n in nomi:
		var bit: int = m.maschera_fatti(PackedStringArray([n]))
		t.ok(bit != 0, "il fatto «%s» accende il suo bit" % n)
		t.ok(not visti.has(bit), "e il bit di «%s» non è di nessun altro" % n)
		visti[bit] = true
		somma |= bit
	var accesi := 0
	for i in 32:
		if somma & (1 << i):
			accesi += 1
	t.eq(accesi, nomi.size(), "i fatti conosciuti sono esattamente quelli dichiarati")
	t.eq(m.maschera_fatti(PackedStringArray(["fatto_inventato"])), 0,
			"un fatto inventato non accende niente")
	t.eq(m.maschera_fatti(PackedStringArray(["mattina", "regia"])),
			m.maschera_fatti(PackedStringArray(["mattina"]))
					| m.maschera_fatti(PackedStringArray(["regia"])),
			"due fatti insieme sono l'OR dei loro bit")


## E ogni azione che il motore può scegliere, l'esecutore la sa recitare.
## Non è un dettaglio: `_recita` fa un `match` sui NOMI, e un'azione che
## non trova il suo ramo cade nel ripiego senza dire niente — che è
## esattamente il difetto che «gironzola» esiste per rendere visibile.
func _le_azioni_le_sa_recitare(t, m) -> void:
	var sorgente := FileAccess.get_file_as_string("res://scenes/npc/Visitors.gd")
	t.ok(sorgente.length() > 0, "il sorgente di Visitors si legge")
	for a in BRAIN.AZIONI:
		var nome := str(a)
		if nome == "gironzola":
			# è il ripiego dichiarato: cade apposta nel ramo finale di
			# `_recita`, e non ha (né deve avere) un suo `match`
			continue
		t.ok(sorgente.contains('"%s"' % nome),
				"«%s» compare fra i rami che _recita sa mettere in scena" % nome)
