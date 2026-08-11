extends RefCounted
## LE CURVE DI UTILITÀ (IAUS) E LA TABELLA DELLE AZIONI.
##
## La macchina delle curve vive in C++ (src/curve_utilita.cpp) e non è
## raggiungibile direttamente dal GDScript: la si interroga attraverso
## `debug_punteggi`, che è la stessa strada che percorre il gioco. Un test
## che chiamasse una scorciatoia proverebbe una funzione che il gioco non
## usa — è il difetto che la revisione della Fase 1 ha trovato, e non si
## ripete.
##
## Qui si prova che la tabella delle otto azioni si comporta come deve:
## i pesi, i gate, il pavimento, le indoli. L'uguaglianza con le formule di
## PRIMA sta in test_agenda_equivalenza.gd.

const BRAIN := preload("res://scenes/npc/VillagerBrain.gd")

# i cinque bisogni nell'ordine del ponte (pancino, energia, compagnia,
# meraviglia, cura): l'ordine è un contratto, e test_agenda_tabelle lo prova
## `var` e non `const`: un PackedFloat64Array costruito da un Array non è
## un'espressione costante per il parser di GDScript.
var PIENI := PackedFloat64Array([1.0, 1.0, 1.0, 1.0, 1.0])


func run(t) -> void:
	if not ClassDB.class_exists("EcsMondo"):
		t.ok(false, "EcsMondo non registrata: la GDExtension non è caricata")
		return
	var m = ClassDB.instantiate("EcsMondo")
	_api(t, m)
	_bisogno_pieno_niente_voglia(t, m)
	_il_peso_conta(t, m)
	_le_indoli_pesano(t, m)
	_i_gate_spengono(t, m)
	_il_pavimento_chiama_chiunque(t, m)
	_la_stella_vuole_il_nottambulo(t, m)
	_gironzola_si_puo_sempre(t, m)
	_niente_punteggi_fuori_scala(t, m)
	m.free()


func _api(t, m) -> void:
	for nome in ["riferisci_bisogni", "riferisci_agenda", "semina_agenda",
			"vuole_dado", "azione", "azione_cambiata", "azione_desiderata",
			"azione_da", "maschera_fatti", "indice_azione", "indice_bisogno",
			"debug_punteggi", "debug_punteggi_mod", "debug_costanti_agenda",
			"debug_agenda", "debug_tara_agenda"]:
		t.ok(m.has_method(nome), "EcsMondo espone «%s» nel binario" % nome)


func _p(m, bisogni: PackedFloat64Array, fatti: Array, indole: Array, quirk := "") -> PackedFloat64Array:
	return m.debug_punteggi(bisogni, m.maschera_fatti(PackedStringArray(fatti)),
			m.maschera_indole(PackedStringArray(indole)), m.indice_quirk(quirk))


## Un bisogno pieno non chiama: è la forma della curva (1 − bisogno), ed è
## la ragione per cui i vicini non mangiano a pancia piena.
func _bisogno_pieno_niente_voglia(t, m) -> void:
	var p := _p(m, PIENI, ["spuntino_vicino", "amico_in_giro",
			"aiuola_da_annaffiare", "meraviglia_posto"], [])
	t.almost(p[m.AZ_SPUNTINO], 0.0, "a pancia piena non si cerca da mangiare", 1e-12)
	t.almost(p[m.AZ_RIPOSO], 0.0, "riposato non si cerca riposo", 1e-12)
	t.almost(p[m.AZ_CHIACCHIERE], 0.0, "in compagnia non si cerca compagnia", 1e-12)
	t.almost(p[m.AZ_MERAVIGLIA], 0.0, "sazio di meraviglia non se ne cerca", 1e-12)


## Il peso di ogni azione, letto sul vuoto assoluto del bisogno.
func _il_peso_conta(t, m) -> void:
	var vuoti := PackedFloat64Array([0.0, 0.0, 0.0, 0.0, 0.0])
	var p := _p(m, vuoti, ["spuntino_vicino", "amico_in_giro",
			"aiuola_da_annaffiare", "meraviglia_posto"], [])
	t.almost(p[m.AZ_SPUNTINO], 2.0, "il peso della fame è 2.0", 1e-12)
	t.almost(p[m.AZ_RIPOSO], 1.6, "quello del riposo 1.6", 1e-12)
	t.almost(p[m.AZ_CHIACCHIERE], 1.8, "quello della compagnia 1.8", 1e-12)
	t.almost(p[m.AZ_CURA_GIARDINO], 1.5, "quello del giardino 1.5", 1e-12)
	t.almost(p[m.AZ_MERAVIGLIA], 1.4, "quello della meraviglia 1.4", 1e-12)


## Il carattere pesa: un goloso ha più fame di fame.
func _le_indoli_pesano(t, m) -> void:
	var vuoti := PackedFloat64Array([0.0, 0.0, 0.0, 0.0, 0.0])
	var normale := _p(m, vuoti, ["spuntino_vicino"], [])
	var goloso := _p(m, vuoti, ["spuntino_vicino"], ["goloso"])
	t.almost(goloso[m.AZ_SPUNTINO], normale[m.AZ_SPUNTINO] * 1.6,
			"il goloso vuole mangiare 1.6 volte tanto", 1e-12)
	var dormiglione := _p(m, vuoti, [], ["dormiglione"])
	t.almost(dormiglione[m.AZ_RIPOSO], normale[m.AZ_RIPOSO] * 1.4,
			"il dormiglione ha 1.4 volte la voglia di riposare", 1e-12)
	# chiacchierone E timido si MOLTIPLICANO, non si escludono: è così anche
	# nel gioco di prima, e un test che lo dà per scontato lascerebbe passare
	# una «correzione» che cambia il carattere di qualcuno
	var doppio := _p(m, vuoti, ["amico_in_giro"], ["chiacchierone", "timido"])
	var solo := _p(m, vuoti, ["amico_in_giro"], [])
	t.almost(doppio[m.AZ_CHIACCHIERE], solo[m.AZ_CHIACCHIERE] * 1.5 * 0.6,
			"chiacchierone e timido insieme si moltiplicano (x0.9)", 1e-12)


## I gate: senza il posto o senza la persona, l'azione non si può.
func _i_gate_spengono(t, m) -> void:
	var vuoti := PackedFloat64Array([0.0, 0.0, 0.0, 0.0, 0.0])
	var senza := _p(m, vuoti, [], [])
	t.almost(senza[m.AZ_CHIACCHIERE], 0.0,
			"senza nessuno in giro non si va a chiacchierare", 1e-12)
	t.almost(senza[m.AZ_CURA_GIARDINO], 0.0,
			"senza un'aiuola assetata non si va ad annaffiare", 1e-12)
	t.almost(senza[m.AZ_MERAVIGLIA], 0.0,
			"e senza un posto da guardare non ci si incanta")
	t.almost(senza[m.AZ_REGIA], 0.0, "né si recita un piano che non c'è", 1e-12)
	# lo spuntino invece NON ha un gate: è un ATTENUATORE a 0.25, perché la
	# fame vera fa camminare anche lontano
	var lontano := _p(m, vuoti, [], [])
	t.almost(lontano[m.AZ_SPUNTINO], 2.0 * 0.25,
			"col cibo lontano la fame si attenua ma non si spegne", 1e-12)


## L'aiuola assetata chiama chiunque, anche a bisogno soddisfatto: è il
## «pavimento», e senza di lui un giardino curato morirebbe di sete perché
## nessuno ha voglia di curarlo.
func _il_pavimento_chiama_chiunque(t, m) -> void:
	var p := _p(m, PIENI, ["aiuola_da_annaffiare"], [])
	t.almost(p[m.AZ_CURA_GIARDINO], 0.9,
			"un'aiuola secca vale almeno 0.9, anche a cura piena", 1e-12)
	t.ok(p[m.AZ_CURA_GIARDINO] > 0.75,
			"cioè batte sempre il piano del Regista, che vale 0.75")


## La stella è dei nottambuli, e «chi è nottambulo» è scritto in un posto
## solo (sistema_sonno.cpp): qui si prova che l'agenda usa QUELLA frase.
func _la_stella_vuole_il_nottambulo(t, m) -> void:
	var sera := ["sera_stellata"]
	t.almost(_p(m, PIENI, sera, [])[m.AZ_STELLA], 0.0,
			"chi va a letto presto non resta a guardare le stelle", 1e-12)
	t.almost(_p(m, PIENI, sera, ["sognatore"])[m.AZ_STELLA], 3.0,
			"il sognatore sì, e vince su tutto (3.0)", 1e-12)
	t.almost(_p(m, PIENI, sera, [], "canta_alla_luna")[m.AZ_STELLA], 3.0,
			"e chi canta alla luna pure")
	t.almost(_p(m, PIENI, [], ["sognatore"])[m.AZ_STELLA], 0.0,
			"ma non di giorno", 1e-12)


## GIRONZOLA si può sempre, ed è il punto: un vicino che non ha niente da
## fare deve poterlo DIRE, invece di restare incastrato su un'azione
## impossibile credendosi giardiniere.
func _gironzola_si_puo_sempre(t, m) -> void:
	var p := _p(m, PIENI, [], [])
	t.ok(p[m.AZ_GIRONZOLA] > 0.0, "gironzolare si può sempre")
	var somma := 0.0
	for i in 7:
		somma += p[i]
	t.almost(somma, 0.0,
			"e in un mondo che non offre niente è l'unica cosa possibile", 1e-12)


## Nessun punteggio deve uscire dalla scala per una taratura sbagliata: le
## curve pinzano l'uscita in [0,1] e il peso è dichiarato a parte.
##
## FASE 4: la stessa asserzione si rifà col MODULATORE dell'emozione acceso
## al massimo, e con lo STESSO tetto. Il modulatore non è inventato qui: si
## chiede a `modulatori()` (la fonte) cosa produce con le tinte a fondo
## scala, perché il tetto dev'essere provato contro quel che il gioco può
## davvero produrre — un vettore inventato a mano proverebbe un sistema che
## non esiste, in un senso o nell'altro.
func _niente_punteggi_fuori_scala(t, m) -> void:
	var strani := PackedFloat64Array([-5.0, 9.0, 0.5, -0.001, 1.001])
	var fatti := ["spuntino_vicino", "amico_in_giro",
			"aiuola_da_annaffiare", "meraviglia_posto", "mattina"]
	var p := _p(m, strani, fatti, ["goloso"])
	for i in 8:
		t.ok(not is_nan(p[i]), "il punteggio %d non è NaN nemmeno con bisogni assurdi" % i)
		t.ok(p[i] >= 0.0 and p[i] <= 3.5,
				"e resta in scala (%d = %.3f)" % [i, p[i]])

	var mod := _mod_al_massimo(m)
	t.eq(mod.size(), 8, "il modulatore dell'emozione ha una voce per azione")
	var q: PackedFloat64Array = m.debug_punteggi_mod(strani,
			m.maschera_fatti(PackedStringArray(fatti)),
			m.maschera_indole(PackedStringArray(["goloso"])), m.indice_quirk(""), mod)
	var mossi := 0
	for i in 8:
		t.ok(not is_nan(q[i]),
				"col modulatore acceso il punteggio %d non è NaN" % i)
		t.ok(q[i] >= 0.0 and q[i] <= 3.5,
				"e resta nella STESSA scala di prima (%d = %.3f)" % [i, q[i]])
		if q[i] != p[i]:
			mossi += 1
	# l'anti-tautologia: se il modulatore non muovesse niente, le sedici
	# asserzioni qui sopra sarebbero una copia di quelle di prima
	t.ok(mossi >= 1,
			"…e il modulatore ha davvero mosso qualcosa (%d punteggi su 8)" % mossi)
	t.ok(q[m.AZ_CHIACCHIERE] > p[m.AZ_CHIACCHIERE],
			"a muoversi sono le chiacchiere (%.3f → %.3f)"
					% [p[m.AZ_CHIACCHIERE], q[m.AZ_CHIACCHIERE]])
	# …e a NON muoversi è la cura del giardino, ed è la regola 9 vista qui
	# dentro: con la cura piena il punteggio grezzo è zero, l'emozione
	# moltiplica zero, e quel che resta è il PAVIMENTO — 0.9 per chiunque.
	t.almost(q[m.AZ_CURA_GIARDINO], 0.9,
			"e l'aiuola secca vale 0.9 anche per chi ti ammira: il mondo batte l'emozione",
			1e-12)


## IL MODULATORE PIÙ GRANDE CHE IL GIOCO SAPPIA PRODURRE, chiesto alla sua
## fonte (`chibi::modulatori`, via l'oracolo dell'occ) con un grafo dei
## ricordi pieno, caldo e con i gusti a fondo scala.
func _mod_al_massimo(m) -> PackedFloat64Array:
	var neutro := PackedFloat64Array([1.0, 1.0, 1.0, 1.0, 1.0, 1.0])
	var cost: Dictionary = m.debug_occ(PackedFloat64Array(), neutro, 0.0, {})
	var su_di_me := int(cost["su_di_me"])
	var v_annaffia: int = m.indice_verbo("annaffia")
	var v_dona: int = m.indice_verbo("dona")
	var ricordi := PackedFloat64Array()
	for i in 12:
		ricordi.append_array(PackedFloat64Array([float(v_annaffia), 0.0, 255.0, 255.0, 0.0]))
	for i in 12:
		ricordi.append_array(PackedFloat64Array([float(v_dona), float(su_di_me), 255.0, 255.0, 0.0]))
	var forti := PackedFloat64Array([4.0, 4.0, 4.0, 4.0, 4.0, 4.0])
	var letto: Dictionary = m.debug_occ(ricordi, forti, 0.0, {})
	return letto["mod"]
