extends RefCounted
## LA PROVA CHE IL VILLAGGIO NON È CAMBIATO.
##
## L'utility AI di questo gioco esisteva già: `VillagerBrain.choose()`
## pesava sette azioni su bisogni, indole e contesto. La Fase 2 non l'ha
## inventata — l'ha portata in C++ e le ha dato una macchina IAUS vera
## (curve parametriche invece di formule moltiplicative scritte a mano).
##
## Il rischio numero uno, quindi, non è che non funzioni: è che i vicini si
## comportino DIVERSAMENTE senza che nessuno se ne accorga. Qui si misura.
## `tests/oracolo_agenda.gd` conserva le formule di prima, congelate, e si
## pretende l'uguaglianza ESATTA su tutte e sette le azioni — non `almost`,
## che nasconderebbe proprio la classe di errore che si sta cercando.
##
## Le divergenze VOLUTE sono tre, e sono provate una per una come casi
## nominati: un test che le infilasse in un `if` generico non proverebbe
## niente.
##
## --- FASE 4 (P3) -------------------------------------------------------
## `punteggi()` ha preso un nono argomento: gli otto modulatori
## dell'emozione, OBBLIGATORI e mai nullable. La stessa spazzata si rifà
## adesso TRE volte, e le tre non sono la stessa cosa:
##
##  1. `debug_punteggi` — gli otto 1.0 nascono in C++;
##  2. `debug_punteggi_mod` con otto 1.0 che arrivano DAL PONTE: prova che
##     la neutralità sopravvive al viaggio (un 1.0 che diventasse
##     0.99999999 in mezzo farebbe cadere l'uguaglianza bit-esatta);
##  3. `debug_punteggi_mod` con un modulatore che MORDE, e qui non si
##     confronta col passato: si pretende il valore ESATTO che l'innesto
##     deve produrre. È questa la prova che il codice nuovo gira davvero —
##     le prime due restano verdi anche se qualcuno cancella la
##     moltiplicazione, perché con mod = 1.0 cancellarla non si vede.

const ORACOLO := preload("res://tests/oracolo_agenda.gd")
const BRAIN := preload("res://scenes/npc/VillagerBrain.gd")

# i nomi dei bisogni nell'ordine del ponte
const ORDINE := ["pancino", "energia", "compagnia", "meraviglia", "cura"]

## IL MODULATORE CHE MORDE, uno per azione, scelto perché ogni voce provi
## una cosa diversa (i valori veri di `modulatori()` stanno in [1.0, 1.5];
## qui si esplora anche fuori, perché `punteggi()` è una funzione pura e il
## suo contratto non può dipendere da chi la chiama oggi):
##   spuntino  1.5 → scarto oltre il tetto, si pinza
##   riposo    0.5 → scarto NEGATIVO oltre il tetto, si pinza dall'altra parte
##   chiacch.  1.2 → scarto piccolo o grande secondo il punteggio
##   giardino  1.5 → e sotto c'è il PAVIMENTO, che deve vincere lo stesso
##   meravig.  1.0 → neutro: se qualcuno leggesse p_mod[0] per tutti, salta
##   stella    1.3 → e il nottambulo la spegne DOPO, quindi resta zero
##   regia     0.0 → e non è un veto: 0.75 non diventa 0, diventa 0.30
##   gironzola 2.0
var MORDE := PackedFloat64Array([1.5, 0.5, 1.2, 1.5, 1.0, 1.3, 0.0, 2.0])
var UNO := PackedFloat64Array([1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0])


func run(t) -> void:
	if not ClassDB.class_exists("EcsMondo"):
		t.ok(false, "EcsMondo non registrata: la GDExtension non è caricata")
		return
	var m = ClassDB.instantiate("EcsMondo")
	_equivalenza_esatta(t, m)
	_non_e_una_tautologia(t, m)
	_divergenza_meraviglia(t, m)
	_divergenza_regia(t, m)
	_divergenza_gironzola(t, m)
	m.free()


## L'INNESTO, scritto una volta sola: scarto assoluto, pinzato a ±DELTA_MAX.
## È il contratto della Fase 4 espresso in GDScript — non una copia delle
## formule dell'utility (quelle stanno nell'oracolo e si leggono da lì).
## Il mod negativo si pinza a zero PRIMA, come in C++: se non lo facesse,
## un punteggio potrebbe scendere sotto zero.
static func _applica(v: float, mod: float, dmax: float) -> float:
	var mo := mod if mod > 0.0 else 0.0
	var d := v * mo - v
	if d > dmax:
		d = dmax
	elif d < -dmax:
		d = -dmax
	return v + d


func _needs(v: Array) -> Dictionary:
	var d := {}
	for i in ORDINE.size():
		d[ORDINE[i]] = float(v[i])
	return d


func _packed(v: Array) -> PackedFloat64Array:
	var p := PackedFloat64Array()
	p.resize(5)
	for i in 5:
		p[i] = float(v[i])
	return p


## LA SPAZZATA. Bisogni × fatti × caratteri: per ogni combinazione i sette
## punteggi del C++ devono essere gli STESSI double di quelli di prima.
func _equivalenza_esatta(t, m) -> void:
	var livelli := [0.0, 0.13, 0.5, 0.87, 1.0]
	var caratteri := [
		[], ["goloso"], ["dormiglione"], ["chiacchierone"], ["timido"],
		["sognatore"], ["ordinato"], ["chiacchierone", "timido"],
		["goloso", "ordinato"], ["sognatore", "dormiglione"],
	]
	var quirks := ["", "canta_alla_luna", "ballerino"]
	# i sei fatti di sempre, in tutte le combinazioni
	var nomi_fatti := ["mattina", "sera_stellata", "aiuola_da_annaffiare",
			"spuntino_vicino", "amico_in_giro", "regia"]
	var azioni := ["spuntino", "riposo", "quattro_chiacchiere",
			"cura_giardino", "meraviglia", "stella", "regia"]

	var cost: Dictionary = m.debug_costanti_agenda()
	var dmax := float(cost["delta_max"])
	# I NOMI SONO L'INDICE. Il ramo che morde legge `MORDE[a]` e l'oracolo
	# `azioni[a]`: se le due tabelle scivolassero di una riga il test
	# confronterebbe la voglia di mangiare col modulatore delle chiacchiere e
	# resterebbe verde per caso. Si chiede al C++ invece di fidarsi.
	for a in azioni.size():
		t.eq(m.indice_azione(azioni[a]), a,
				"«%s» è l'azione numero %d anche per il C++" % [azioni[a], a])
	var i_cura: int = m.indice_azione("cura_giardino")

	var confronti := 0
	var divergenze := 0
	var peggiore := ""
	# 2) la stessa spazzata con gli 1.0 che arrivano dal ponte
	var div_ponte := 0
	var peggiore_ponte := ""
	# 3) e con il modulatore che MORDE: qui il metro non è il passato, è la
	#    formula dell'innesto applicata al valore GREZZO (pre-pavimento)
	var confronti_mod := 0
	var div_mod := 0
	var peggiore_mod := ""
	var quanti_mordono := 0 # quante volte il mod ha davvero mosso il numero
	var quanti_pinzati := 0 # …e quante volte lo scarto è finito contro il tetto
	for c in caratteri:
		for q in quirks:
			for combo in 64:
				var ctx := {}
				var acc: Array = []
				for b in 6:
					var on: bool = (combo & (1 << b)) != 0
					ctx[nomi_fatti[b]] = on
					if on:
						acc.append(nomi_fatti[b])
				# i due gate nuovi si accendono SEMPRE qui: in questa prova
				# si confronta il motore, non le divergenze (che hanno i
				# loro casi nominati qui sotto)
				acc.append("meraviglia_posto")
				acc.append("regia_pronta")
				var aiuola: bool = bool(ctx.get("aiuola_da_annaffiare", false))
				var mf: int = m.maschera_fatti(PackedStringArray(acc))
				var mi: int = m.maschera_indole(PackedStringArray(c))
				var mq: int = m.indice_quirk(q)
				for l in livelli:
					var vals := [l, 1.0 - l, l * 0.5 + 0.25, 1.0 - l * 0.5, l]
					var bp := _packed(vals)
					var vecchio: Dictionary = ORACOLO.punteggi(_needs(vals), ctx, c, q)
					var grezzo: Dictionary = ORACOLO.punteggi_pre_pavimento(
							_needs(vals), ctx, c, q)
					var nuovo: PackedFloat64Array = m.debug_punteggi(bp, mf, mi, mq)
					var ponte: PackedFloat64Array = m.debug_punteggi_mod(bp, mf, mi, mq, UNO)
					var morso: PackedFloat64Array = m.debug_punteggi_mod(bp, mf, mi, mq, MORDE)
					for a in azioni.size():
						confronti += 1
						var atteso_base := float(vecchio[azioni[a]])
						if nuovo[a] != atteso_base:
							divergenze += 1
							if peggiore == "":
								peggiore = "%s: C++ %s, prima %s (car %s, q %s, fatti %s)" \
										% [azioni[a], str(nuovo[a]), str(atteso_base),
										str(c), q, str(acc)]
						if ponte[a] != atteso_base:
							div_ponte += 1
							if peggiore_ponte == "":
								peggiore_ponte = "%s: col mod dal ponte %s, prima %s (car %s, q %s, fatti %s)" \
										% [azioni[a], str(ponte[a]), str(atteso_base),
										str(c), q, str(acc)]
						# --- il ramo che morde
						var atteso_mod := _applica(float(grezzo[azioni[a]]),
								MORDE[a], dmax)
						if a == i_cura and aiuola:
							# il PAVIMENTO viene dopo l'emozione, e la batte
							atteso_mod = maxf(atteso_mod, 0.9)
						confronti_mod += 1
						if morso[a] != atteso_mod:
							div_mod += 1
							if peggiore_mod == "":
								peggiore_mod = "%s: col mod %s, atteso %s (car %s, q %s, fatti %s)" \
										% [azioni[a], str(morso[a]), str(atteso_mod),
										str(c), q, str(acc)]
						if morso[a] != atteso_base:
							quanti_mordono += 1
						if absf(morso[a] - atteso_base) >= dmax - 1e-15:
							quanti_pinzati += 1
	t.ok(confronti > 60000, "la spazzata è ampia (%d confronti)" % confronti)
	t.eq(divergenze, 0,
			"i punteggi in C++ sono IDENTICI a quelli di prima — %s" % peggiore)
	t.eq(div_ponte, 0,
			"…e restano identici anche con gli otto 1.0 passati dal ponte — %s"
					% peggiore_ponte)
	t.eq(div_mod, 0,
			"col modulatore acceso il punteggio è ESATTAMENTE quello dell'innesto — %s"
					% peggiore_mod)
	# LE DUE ANTI-TAUTOLOGIE del ramo che morde. Senza, un modulatore che non
	# muovesse mai niente renderebbe la prova qui sopra verde e muta — è lo
	# stesso difetto che `_non_e_una_tautologia` chiude per la spazzata
	# vecchia, e va chiuso anche qui.
	t.ok(quanti_mordono > confronti_mod / 4,
			"il modulatore MORDE davvero (%d punteggi su %d cambiano): se non li muovesse, "
			% [quanti_mordono, confronti_mod]
			+ "cancellare la moltiplicazione dal C++ lascerebbe tutto verde")
	t.ok(quanti_pinzati > 1000,
			"e il TETTO scatta davvero (%d scarti finiti contro DELTA_MAX): "
			% quanti_pinzati
			+ "una rete che nessun caso tocca è una rete che nessun test può falsificare")


## L'ANTI-TAUTOLOGIA: se l'oracolo e il C++ tornassero entrambi zero su
## tutto, la prova qui sopra sarebbe verde e non direbbe niente. È il
## difetto che la revisione della Fase 1 ha trovato due volte.
func _non_e_una_tautologia(t, m) -> void:
	var vals := [0.1, 0.2, 0.3, 0.4, 0.5]
	var ctx := {"mattina": true, "spuntino_vicino": true, "amico_in_giro": true,
			"aiuola_da_annaffiare": true, "regia": true, "sera_stellata": true}
	var vecchio: Dictionary = ORACOLO.punteggi(_needs(vals), ctx, ["sognatore"], "")
	var quanti_vivi := 0
	for k in vecchio:
		if float(vecchio[k]) > 0.0:
			quanti_vivi += 1
	t.ok(quanti_vivi >= 6,
			"l'oracolo produce punteggi VIVI (%d su 7), se no la prova sopra non prova niente"
					% quanti_vivi)
	var nuovo: PackedFloat64Array = m.debug_punteggi(_packed(vals),
			m.maschera_fatti(PackedStringArray(["mattina", "spuntino_vicino",
					"amico_in_giro", "aiuola_da_annaffiare", "regia",
					"sera_stellata", "meraviglia_posto", "regia_pronta"])),
			m.maschera_indole(PackedStringArray(["sognatore"])), -1)
	var vivi_cpp := 0
	for i in 7:
		if nuovo[i] > 0.0:
			vivi_cpp += 1
	t.ok(vivi_cpp >= 6, "e anche il C++ (%d su 7)" % vivi_cpp)


## DIVERGENZA 1, voluta: oggi «meraviglia» può vincere anche dove non c'è
## né lo stagno né il Grande Albero, e la scena cade su «wander» in
## silenzio. Adesso l'azione è INFATTIBILE senza il posto.
func _divergenza_meraviglia(t, m) -> void:
	# meraviglia a zero: la vuole tanto
	var vals := [1.0, 1.0, 1.0, 0.0, 1.0]
	var con_posto: PackedFloat64Array = m.debug_punteggi(_packed(vals),
			m.maschera_fatti(PackedStringArray(["meraviglia_posto"])), 0, -1)
	var senza: PackedFloat64Array = m.debug_punteggi(_packed(vals),
			m.maschera_fatti(PackedStringArray([])), 0, -1)
	t.ok(con_posto[m.AZ_MERAVIGLIA] > 1.0, "col posto, la meraviglia chiama forte")
	t.almost(senza[m.AZ_MERAVIGLIA], 0.0,
			"senza un posto da guardare l'azione non è fattibile (divergenza voluta)", 1e-12)
	var vecchio: Dictionary = ORACOLO.punteggi(_needs(vals), {}, [], "")
	t.ok(float(vecchio["meraviglia"]) > 1.0,
			"…e PRIMA vinceva lo stesso, per poi cadere su «wander» senza dirlo")


## DIVERGENZA 2, voluta: «regia» valeva 0.75 anche quando il Regista non
## aveva ancora un piano per quel residente.
func _divergenza_regia(t, m) -> void:
	var vals := [1.0, 1.0, 1.0, 1.0, 1.0]
	var pronta: PackedFloat64Array = m.debug_punteggi(_packed(vals),
			m.maschera_fatti(PackedStringArray(["regia", "regia_pronta"])), 0, -1)
	var non_pronta: PackedFloat64Array = m.debug_punteggi(_packed(vals),
			m.maschera_fatti(PackedStringArray(["regia"])), 0, -1)
	t.almost(pronta[m.AZ_REGIA], 0.75, "col piano pronto la regia vale 0.75", 1e-12)
	t.almost(non_pronta[m.AZ_REGIA], 0.0,
			"senza piano non è fattibile (divergenza voluta)", 1e-12)
	var vecchio: Dictionary = ORACOLO.punteggi(_needs(vals), {"regia": true}, [], "")
	t.almost(float(vecchio["regia"]), 0.75,
			"…e PRIMA valeva 0.75 comunque, anche senza piano", 1e-12)


## DIVERGENZA 3, voluta: «gironzola» non è un'azione nuova, è il ripiego
## silenzioso di prima che diventa una scelta dichiarata.
func _divergenza_gironzola(t, m) -> void:
	var vals := [1.0, 1.0, 1.0, 1.0, 1.0]
	var p: PackedFloat64Array = m.debug_punteggi(_packed(vals),
			m.maschera_fatti(PackedStringArray([])), 0, -1)
	t.ok(p[m.AZ_GIRONZOLA] > 0.0,
			"a bisogni pieni e mondo vuoto resta il gironzolare, e lo si DICE")
	for i in 7:
		t.almost(p[i], 0.0, "e nessuna delle sette di prima vince (%d)" % i, 1e-12)
