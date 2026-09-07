extends RefCounted
## LA TEORIA DELLA MENTE — le guardie, e la piu' importante e' ESAUSTIVA.
##
## Il modello di cio' che l'altro sa apre la porta all'inganno: «so che tu non
## sai» e' la premessa della menzogna, e questo progetto ha gia' rifiutato per
## iscritto gli abitanti che mentono per danneggiare un rivale. La cura non e'
## una taratura prudente, e' una restrizione della STRUTTURA — e una
## restrizione della struttura si prova, non si promette.
##
## ⚠️ E QUI SI PUO' PROVARE PER INTERO. Lo spazio e' finito (256 maschere di
## partenza x 8 verbi), quindi il primo caso non campiona: ENUMERA. Non
## «abbiamo provato e non e' successo»: **non puo' succedere**.

func run(t) -> void:
	var m = ClassDB.instantiate("EcsMondo") if ClassDB.class_exists("EcsMondo") else null
	if m == null:
		t.ok(false, "EcsMondo assente: la GDExtension non e' caricata")
		return
	var K: Dictionary = m.call("debug_credenze_costanti")
	var n_verbi := int(K.get("n_verbi", 8))
	var max_con := int(K.get("max_conosciuti", 32))
	t.ok(n_verbi > 0 and max_con > 0, "le costanti arrivano dal C++ (%d verbi, %d conosciuti)" % [n_verbi, max_con])
	# ⚠️ E IL QUADERNO DEVE BASTARE PER TUTTO IL VILLAGGIO. `credenze.h`
	# promette per iscritto che un test lo confronti con la costante di la';
	# la prima stesura si limitava a `> 0`, e col fallback a 32 sarebbe
	# rimasta verde perfino se la chiave fosse sparita dal dizionario. Se
	# MAX_RESIDENTS salisse sopra MAX_CONOSCIUTI, ogni residente comincerebbe
	# a sfrattare credenze VIVE a ogni gesto nuovo — la potatura girerebbe di
	# continuo, in silenzio.
	var vis := load("res://scenes/npc/Visitors.gd")
	t.ok(max_con >= int(vis.MAX_RESIDENTS),
			"il quaderno (%d) tiene tutto il villaggio (%d residenti)" % [max_con, int(vis.MAX_RESIDENTS)])

	_il_caso_che_separa_le_due_regole(t)

	# ⚠️ IL SENTINELLA SI LEGGE, NON SI RISCRIVE. Scritto a mano (`-1.0`)
	# valeva un timestamp VERO: tutte le credenze risultavano accese, e nove
	# guardie su ventitre' fallivano dicendo una cosa che non era. Il C++ lo
	# espone apposta — «cosi' nessun test ne riscrive una a mano» — e io
	# l'avevo riscritto a mano.
	var mai := float(K.get("credenza_mai", -1.0e9))
	t.ok(mai < -1000.0, "il sentinella arriva dal C++ (%.0f), non da qui" % mai)

	_la_monotonia_e_esaustiva(t, m, n_verbi, mai)
	_un_verbo_fuori_tabella_non_scrive(t, m, n_verbi, mai)
	_non_esiste_una_funzione_che_spegne(t)
	_chi_non_conosco_non_lo_credo(t, m)
	_la_credenza_eterna_non_scade(t, m, mai)
	_la_credenza_scade_e_scadere_non_e_mentire(t, m, mai)
	_il_riciclo_non_regala_credenze(t, m, mai)
	_il_cablaggio_non_aggira_l_api(t)
	m.free()


## LA MONOTONIA, ENUMERATA TUTTA. Per ogni maschera di partenza e ogni verbo,
## `so_che_sa` deve dare esattamente `m | (1 << v)`: accende quello chiesto e
## **non spegne niente**. 256 x 8 = 2048 casi, cioe' tutti.
func _la_monotonia_e_esaustiva(t, m, n_verbi: int, mai: float) -> void:
	var tutte := 1 << n_verbi
	var storti := 0
	var spenti := 0
	var primo := ""
	for maschera in tutte:
		for v in n_verbi:
			var cred := _credenze_con(7777, maschera, n_verbi, 100.0, mai)
			var dopo: Dictionary = m.call("debug_credenze_so_che_sa", cred, 7777, v, 200.0)
			var letta := int(m.call("debug_credenze_saputi", dopo, 7777, 200.0, 0.0))
			var atteso := maschera | (1 << v)
			if letta != atteso:
				storti += 1
				if primo == "":
					primo = "m=%d v=%d atteso=%d letto=%d" % [maschera, v, atteso, letta]
			# e in particolare: nessun bit che c'era e' sparito
			if (maschera & ~letta) != 0:
				spenti += 1
	t.eq(storti, 0, "monotonia esaustiva: %d casi, ogni `so_che_sa` da' esattamente `m | (1<<v)` %s"
			% [tutte * n_verbi, ("(primo storto: " + primo + ")") if primo != "" else ""])
	t.eq(spenti, 0, "e in NESSUNO dei %d casi un bit acceso si e' spento" % (tutte * n_verbi))


## Un verbo fuori tabella non scrive: e' la funzione pura a doverlo rifiutare.
func _un_verbo_fuori_tabella_non_scrive(t, m, n_verbi: int, mai: float) -> void:
	for v in [n_verbi, n_verbi + 5, 200]:
		var cred := _credenze_con(4242, 0b0000_0101, n_verbi, 100.0, mai)
		var dopo: Dictionary = m.call("debug_credenze_so_che_sa", cred, 4242, v, 200.0)
		var letta := int(m.call("debug_credenze_saputi", dopo, 4242, 200.0, 0.0))
		t.eq(letta, 0b0000_0101, "il verbo %d e' fuori tabella e non scrive niente" % v)


## ⚠️ IL VETO STRUTTURALE. Non e' una prova di comportamento: e' una prova che
## una certa FUNZIONE NON ESISTE. Se un domani qualcuno ne aggiunge una che
## spegne, accetta una maschera o accetta un booleano, questo caso diventa
## rosso — ed e' l'unico modo di sorvegliare l'assenza di una cosa.
func _non_esiste_una_funzione_che_spegne(t) -> void:
	var f := FileAccess.open("res://src/credenze.h", FileAccess.READ)
	if f == null:
		t.ok(false, "credenze.h non si apre")
		return
	# ⚠️ SI SALTANO I COMMENTI, e la lezione e' mia: la prima stesura cercava
	# `dimentica_che_sa` nel sorgente e lo TROVAVA — dentro il commento che
	# spiega che non esiste. Una guardia che matcha la propria spiegazione e'
	# la stessa forma dei test di facciata che questo progetto ha gia'
	# smontato tre volte.
	var codice := ""
	for riga in f.get_as_text().split("\n"):
		var r := str(riga).strip_edges()
		if r.begins_with("//") or r.begins_with("*") or r.begins_with("/*"):
			continue
		codice += r + "\n"
	for vietata in ["dimentica_che_sa", "imposta_saputi", "spegni_credenza",
			"azzera_credenza"]:
		t.ok(not codice.contains(vietata),
				"non esiste `%s`: non c'e' un posto in cui scrivere «B non sa»" % vietata)
	var src := codice
	# e la firma dell'unica scrittura non prende ne' maschere ne' booleani
	var i := src.find("void so_che_sa(")
	t.ok(i >= 0, "l'unica scrittura si chiama `so_che_sa`")
	if i >= 0:
		var firma := src.substr(i, src.find(")", i) - i)
		t.ok(not firma.contains("bool"),
				"e non prende un booleano (un booleano ha un ramo `false`, e quel ramo e' la menzogna)")
		t.ok(firma.contains("uint8_t p_verbo"),
				"prende UN VERBO, non una maschera (una maschera si costruisce altrove, e «altrove» e' dove nasce la credenza che nessuno ha visto)")


## Chi non modello, non lo credo: maschera zero ⇒ glielo racconto. Il degrado
## va SEMPRE verso il comportamento che c'era prima del modello.
func _chi_non_conosco_non_lo_credo(t, m) -> void:
	var vuoto := {"voci": [], "n": 0}
	t.eq(int(m.call("debug_credenze_saputi", vuoto, 999, 100.0, 0.0)), 0,
			"di uno sconosciuto non credo niente, quindi gli racconto tutto")


func _la_credenza_eterna_non_scade(t, m, mai) -> void:
	var cred := _credenze_con(31, 0b0000_0011, 8, 0.0, mai)
	# durata <= 0 = non scade: e' il caso che il banco misura per primo
	t.eq(int(m.call("debug_credenze_saputi", cred, 31, 999999.0, 0.0)), 0b0000_0011,
			"con durata 0 la credenza e' ETERNA anche dopo un milione di secondi")


## ⚠️ LA SCADENZA ESISTE, ED E' CIO' CHE IMPEDISCE AL MODELLO DI DIVENTARE UN
## MURO. Una credenza monotona che non scade satura: al falo' ogni coppia
## accende ogni verbo, e da li' in poi quel verbo non e' piu' raccontabile fra
## quei due PER SEMPRE — il pettegolezzo si spegnerebbe in silenzio, con la
## suite verde. E sbiadire non e' mentire: si torna a raccontare.
func _la_credenza_scade_e_scadere_non_e_mentire(t, m, mai) -> void:
	var cred := _credenze_con(77, 0b0000_1111, 8, 0.0, mai)
	var subito := int(m.call("debug_credenze_saputi", cred, 77, 1.0, 100.0))
	var dopo := int(m.call("debug_credenze_saputi", cred, 77, 100000.0, 100.0))
	t.eq(subito, 0b0000_1111, "appena scritta, la credenza c'e' tutta")
	t.eq(dopo, 0, "molto dopo e' sbiadita del tutto — e sbiadire vuol dire RACCONTARE di nuovo, non mentire")


## ⚠️ IL RICICLO NON REGALA CREDENZE. Un vicino se ne va, uno nuovo eredita il
## suo indice: la versione cambia, quindi l'handle non combacia e le credenze
## del partito non si appiccicano addosso al nuovo. Senza, sarebbe una
## credenza falsa creata dall'ALLOCATORE — che nessuno ha scritto e che
## nessun test cercherebbe.
func _il_riciclo_non_regala_credenze(t, m, mai) -> void:
	# ⚠️ I NUMERI NON SONO A CASO, E LA PRIMA STESURA LI AVEVA SBAGLIATI.
	# In EnTT l'INDICE sta nei 20 bit BASSI e la versione nei 12 alti: i
	# valori che avevo scritto (0x0001_0005 / 0x0002_0005) non erano «lo
	# stesso indice con due versioni», erano DUE INDICI DIVERSI (65541 e
	# 131077) con la stessa versione zero. La guardia passava per la ragione
	# sbagliata: la mutazione che butta via la versione e tiene solo
	# l'indice la lasciava VERDE, perché anche mascherando a 20 bit quei due
	# valori restano diversi. Questi invece sono lo STESSO slot 5, riciclato.
	var vecchio := 0x0010_0005      # indice 5, versione 1
	var nuovo := 0x0020_0005        # stesso indice 5, versione 2
	t.eq(vecchio & 0xFFFFF, nuovo & 0xFFFFF,
			"i due handle hanno davvero lo STESSO indice (o la guardia non prova niente)")
	var cred := _credenze_con(vecchio, 0b0111_1111, 8, 0.0, mai)
	t.eq(int(m.call("debug_credenze_saputi", cred, vecchio, 10.0, 0.0)), 0b0111_1111,
			"del vicino partito credevo sapesse quasi tutto")
	t.eq(int(m.call("debug_credenze_saputi", cred, nuovo, 10.0, 0.0)), 0,
			"il vicino NUOVO che eredita lo stesso indice non eredita una sola credenza")


## Il cablaggio non aggira l'API: la co-testimonianza passa da `co_testimoni`,
## e nient'altro nel gioco tocca le credenze.
func _il_cablaggio_non_aggira_l_api(t) -> void:
	var f := FileAccess.open("res://scenes/npc/Percezione.gd", FileAccess.READ)
	t.ok(f != null, "Percezione.gd si apre")
	if f == null:
		return
	# ⚠️ SI SALTANO I COMMENTI, come fa il gemello qui sopra. Senza, basta
	# togliere la chiamata lasciando il paragrafo che la spiega — e quel
	# paragrafo, di venti righe, sta proprio li' — perche' questa guardia
	# resti verde su un cablaggio morto.
	var src := ""
	for riga in f.get_as_text().split("\n"):
		var r := str(riga).strip_edges()
		if r.begins_with("#"):
			continue
		src += r + "\n"
	t.ok(src.contains("co_testimoni"),
			"la co-testimonianza si incide (i `visti` non si buttano piu')")
	# e si incide solo chi ha DAVVERO memorizzato il ricordo
	t.ok(src.contains("_incisi"),
			"e passa solo chi ha inciso davvero: `osserva` torna -1 se l'anello rifiuta il ricordo, e accendere «B sa» su un ricordo che B non ha memorizzato sarebbe una credenza falsa dalla porta di servizio")


## Costruisce un Dictionary di credenze con una sola voce, nella forma che
## `credenze_da` sa leggere. Il `quando` e' lo stesso per tutti i bit accesi.
func _credenze_con(chi: int, maschera: int, n_verbi: int, quando: float, mai: float) -> Dictionary:
	var q := PackedFloat64Array()
	q.resize(n_verbi)
	for v in n_verbi:
		q[v] = quando if (maschera & (1 << v)) != 0 else mai
	return {"voci": [{"chi": chi, "quando": q}], "n": 1}


## ⚠️ IL CASO CHE SEPARA LE DUE REGOLE, e senza di lui tutto il resto non
## prova niente.
##
## Una revisione avversariale l'ha detto meglio di come l'avrei detto io:
## dopo aver aggiunto la co-testimonianza alle fixture del pettegolezzo,
## OGNI scenario della suite era finito dentro il ramo in cui il modello
## nuovo e l'onniscienza dicono la stessa cosa — «non contiene una sola
## asserzione che un binario onnisciente non passerebbe». La regola nuova
## c'era, girava, era misurata dal banco, e non aveva UN LETTORE.
##
## Questo e' il lettore. A e B hanno visto lo stesso verbo ma SEPARATAMENTE,
## in due momenti diversi: nessuno dei due ha visto l'altro guardare.
##  · l'ONNISCIENTE legge il grafo vero di B, vede che B lo sa, e TACE (-1);
##  · il MODELLO non ha nessuna credenza su B, quindi RACCONTA.
## Ed e' la ripetizione benigna: due che si raccontano la stessa cosa.
func _il_caso_che_separa_le_due_regole(t) -> void:
	var m = ClassDB.instantiate("EcsMondo")
	if m == null:
		return
	var a: int = m.registra(PackedStringArray([]), "")
	var b: int = m.registra(PackedStringArray([]), "")
	var v: int = m.indice_verbo("costruisce")
	# LO STESSO VERBO, IN DUE POSTI E DUE MOMENTI: non si sono visti.
	# (niente `co_testimoni`, ed e' il punto)
	m.osserva(a, v, Vector3(3.0, 0.0, 4.0), -1)
	m.osserva(b, v, Vector3(-9.0, 0.0, 11.0), -1)
	t.ok(int(m.racconta(a, b, 0.55)) >= 0,
			"A glielo racconta lo stesso: sa che LUI l'ha visto, non che l'ha visto B")

	# e la controprova nello stesso banco: con la co-testimonianza, tace.
	var c: int = m.registra(PackedStringArray([]), "")
	var d: int = m.registra(PackedStringArray([]), "")
	m.osserva(c, v, Vector3(1.0, 0.0, 1.0), -1)
	m.osserva(d, v, Vector3(1.0, 0.0, 1.0), -1)
	m.co_testimoni(PackedInt64Array([c, d]), v)
	t.eq(int(m.racconta(c, d, 0.55)), -1,
			"…e con chi era li' con lui, invece, non ha niente da dire")
	for x in [a, b, c, d]:
		m.dimentica(x)
	m.free()
