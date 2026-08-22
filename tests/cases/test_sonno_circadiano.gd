## LA FASE CIRCADIANA — «è la MIA sera», e non decide niente.
##
## Il canale della melatonina seguiva la LUCE, e il difetto non era «una
## seconda risposta a che ora è»: era che **quella riga non era un orologio,
## era un barometro**. Il cielo cala col `weather_gloom`, quindi a mezzogiorno
## sotto un temporale il punto di riposo della melatonina saliva a 0.202 —
## addosso a tutti e ventotto insieme. Un ritmo circadiano non si sposta
## perché piove.
##
## Adesso la sorgente è la propria finestra di sonno, che è già il genoma
## persistito di quella persona. Questi casi sorvegliano le tre cose che
## potrebbero romperlo in silenzio: che la fase non diventi un'autorità sul
## sonno, che il colore non diventi una porta, e che il degrado vada dove va
## sempre.

extends RefCounted

const LIMBICO := preload("res://scenes/npc/Limbico.gd")
const ORACOLO := preload("res://tests/oracolo_sonno.gd")


func run(t) -> void:
	var m = ClassDB.instantiate("EcsMondo")
	if m == null:
		t.ok(false, "EcsMondo non registrato: la GDExtension non si e' caricata")
		return
	_la_forma_della_rampa(t, m)
	_anticipo_zero_e_il_gioco_di_ieri(t, m)
	_gli_estremi_hanno_una_casa_sola(t, m)
	_la_fase_non_decide_il_sonno(t, m)
	_il_temporale_non_e_piu_una_sera(t)
	_il_colore_non_e_una_porta(t)
	_senza_notte_non_succede_niente(t)
	_un_anticipo_malato_non_avvelena(t, m)
	_il_villaggio_passa_la_notte_alla_chimica(t)
	m.free()


## 0.80 è l'inizio di chi non è nottambulo, 0.92 di chi lo è. Con l'anticipo
## la rampa sale prima, ed è monotòna.
func _la_forma_della_rampa(t, m) -> void:
	t.almost(float(m.debug_fase_circadiana(0, -1, 0.85, 0.08)), 1.0,
			"dentro la propria finestra la fase e' piena", 1e-9)
	t.almost(float(m.debug_fase_circadiana(0, -1, 0.50, 0.08)), 0.0,
			"a meta' pomeriggio non e' la sera di nessuno", 1e-9)
	var prima := -1.0
	var cresce := true
	for i in 9:
		var ora := 0.80 - 0.08 + float(i) * 0.01
		var f: float = float(m.debug_fase_circadiana(0, -1, ora, 0.08))
		if f < prima - 1e-9:
			cresce = false
		prima = f
	t.ok(cresce, "e nell'anticipo sale senza mai tornare indietro")
	t.almost(float(m.debug_fase_circadiana(0, -1, 0.76, 0.08)), 0.5,
			"a meta' anticipo vale mezza", 1e-9)

	# ⚠️ **IL GIRO DELLA MEZZANOTTE.** L'inizio del nottambulo e' 0.92: la sua
	# rampa comincia a 0.84, e la distanza va misurata sul CERCHIO. Una
	# sottrazione ingenua darebbe un numero negativo e la rampa non partirebbe
	# mai — o peggio, partirebbe a mezzogiorno.
	t.almost(float(m.debug_fase_circadiana(32, -1, 0.88, 0.08)), 0.5,
			"il nottambulo comincia piu' tardi, e a meta' anticipo vale mezza",
			1e-9)
	t.almost(float(m.debug_fase_circadiana(32, -1, 0.80, 0.08)), 0.0,
			"…e quando gli altri sono gia' dentro, lui e' ancora a zero", 1e-9)
	# e chi ha la finestra che attraversa la mezzanotte: a 0.005 e' DENTRO
	t.almost(float(m.debug_fase_circadiana(32, -1, 0.005, 0.08)), 1.0,
			"dopo mezzanotte si e' dentro, e il cerchio non si spezza", 1e-9)


## ⚠️ **IL DEGRADO E' IL GIOCO DI IERI, e si dimostra invece di prometterlo.**
## Con anticipo zero la fase dev'essere ESATTAMENTE il si'/no della finestra,
## per ogni ora e per ogni profilo: e' la garanzia che un banco, il Prologo o
## un binario vecchio non vedano un mondo diverso.
func _anticipo_zero_e_il_gioco_di_ieri(t, m) -> void:
	var profili := [[0, -1], [4, -1], [2, -1], [32, -1], [0, 2], [6, -1]]
	var storti := 0
	for p in profili:
		for i in 201:
			var ora := float(i) / 200.0
			var si: bool = bool(m.debug_in_finestra(int(p[0]), int(p[1]), ora))
			var f: float = float(m.debug_fase_circadiana(int(p[0]), int(p[1]),
					ora, 0.0))
			if absf(f - (1.0 if si else 0.0)) > 1e-12:
				storti += 1
	t.eq(storti, 0,
			("con anticipo zero la fase e' il si'/no di sempre, su %d ore x %d "
			+ "profili") % [201, profili.size()])


## ⚠️ **UNA CASA SOLA PER I CINQUE NUMERI.** `estremi_finestra` è stata
## estratta apposta, e `finestra_di_sonno` la chiama: se qualcuno riscrivesse
## gli orari nella rampa, i due smetterebbero di combaciare. Qui si rileggono
## gli estremi ATTRAVERSO la rampa (dove comincia a salire) e si confrontano
## col si'/no — mutare 0.80 in 0.81 fa arrossire tutti e due.
func _gli_estremi_hanno_una_casa_sola(t, m) -> void:
	for p in [[0, -1], [32, -1], [4, -1]]:
		# il primo istante in cui la fase e' piena = l'inizio della finestra
		var inizio := -1.0
		for i in 1000:
			var ora := float(i) / 1000.0
			if float(m.debug_fase_circadiana(int(p[0]), int(p[1]), ora, 0.0)) > 0.5 \
					and float(m.debug_fase_circadiana(int(p[0]), int(p[1]),
							ora - 0.001, 0.0)) < 0.5:
				inizio = ora
				break
		t.ok(inizio > 0.0, "profilo %s: la finestra ha un inizio" % str(p))
		# e la rampa, con un anticipo minuscolo, comincia LI'
		t.ok(float(m.debug_fase_circadiana(int(p[0]), int(p[1]),
				inizio - 0.004, 0.005)) > 0.0,
				"…e la rampa comincia dallo stesso inizio (%.3f)" % inizio)
		t.almost(float(m.debug_fase_circadiana(int(p[0]), int(p[1]),
				inizio - 0.006, 0.005)), 0.0,
				"…e non un istante prima", 1e-9)

	# il mattiniero vince sul dormiglione anche qui: e' l'`else if`
	var solo_dorm: float = 0.0
	var tutti_e_due: float = 0.0
	for i in 400:
		var ora := float(i) / 1000.0
		solo_dorm += float(m.debug_fase_circadiana(2, -1, ora, 0.0))
		tutti_e_due += float(m.debug_fase_circadiana(6, -1, ora, 0.0))
	t.ok(tutti_e_due < solo_dorm,
			"col mattiniero E il dormiglione insieme vince il mattiniero")


## ⚠️ **LA REGOLA 1 DELL'ECS: il sonno ha UNA sola autorità, e il rifattoring
## non l'ha spostata.**
##
## `estremi_finestra` è stata estratta da `finestra_di_sonno` perché la rampa
## avesse i cinque numeri senza ricopiarli. Un'estrazione fatta male sposta
## l'autorità del sonno **in silenzio**: la finestra è l'unico ingresso di
## `passo_sonno` che dipende dal genoma e dall'ora, e se cambiasse di un
## millesimo il villaggio andrebbe a letto a un'ora diversa senza che nessuna
## asserzione se ne accorgesse.
##
## L'oracolo è quello CONGELATO (`tests/oracolo_sonno.gd`), che è una copia
## indipendente e non è stata toccata: chiedere al C++ se è d'accordo con sé
## stesso non proverebbe niente.
func _la_fase_non_decide_il_sonno(t, m) -> void:
	var profili := [[], ["mattiniero"], ["dormiglione"],
			["mattiniero", "dormiglione"], ["sognatore"], ["goloso"]]
	var quirk := ["", "canta_alla_luna", "ballerino"]
	var storti := 0
	var prove := 0
	for ind in profili:
		for q in quirk:
			var masc: int = int(m.maschera_indole(PackedStringArray(ind)))
			var iq: int = int(m.indice_quirk(str(q)))
			for i in 401:
				var ora := float(i) / 400.0
				prove += 1
				if bool(m.debug_in_finestra(masc, iq, ora)) \
						!= bool(ORACOLO.finestra(ind, str(q), ora)):
					storti += 1
	t.eq(storti, 0,
			("la finestra del sonno e' IDENTICA all'oracolo congelato dopo "
			+ "l'estrazione di `estremi_finestra`: %d prove su %d profili")
					% [prove, profili.size() * quirk.size()])


## IL NUMERO CHE DIMOSTRA LA CORREZIONE. A mezzogiorno con un temporale la
## luce scende a 0.55, e il vecchio `Π · (1 − luce)` dava un punto di riposo
## di **0.202** — il 94% del picco serale, addosso a tutti insieme.
func _il_temporale_non_e_piu_una_sera(t) -> void:
	var amb := {"luce": 0.55, "pioggia": 1.0, "temperatura": 18.0}
	var prod: Dictionary = LIMBICO.produzione_ambientale(amb, false, 0.0)
	t.almost(float(prod["melatonina"]), 0.0,
			("un temporale di mezzogiorno non produce piu' melatonina: prima "
			+ "il punto di riposo saliva a 0.202, cioe' il 94%% del picco "
			+ "serale, per tutti e ventotto insieme"), 1e-12)
	# e la controprova: la propria notte la produce eccome
	var notte: Dictionary = LIMBICO.produzione_ambientale(amb, false, 1.0)
	t.ok(float(notte["melatonina"]) > 0.04,
			"…e la propria notte si' (%.4f)" % float(notte["melatonina"]))
	# ⚠️ e la LUCE non entra piu' affatto: stessa notte, sole pieno
	var sole: Dictionary = LIMBICO.produzione_ambientale(
			{"luce": 1.0, "pioggia": 0.0, "temperatura": 20.0}, false, 1.0)
	t.almost(float(sole["melatonina"]), float(notte["melatonina"]),
			("la luce non entra piu' nella melatonina, nemmeno come "
			+ "soppressore: era una terza manopola con un perche' decorativo"),
			1e-12)


## ⚠️ **IL COLORE NON DEVE DIVENTARE UNA PORTA.** L'umore ha consumatori che
## decidono (`stato_corpo`, il capo che pende, `Animo.decide`): se la
## melatonina entrasse in `bersaglio_umore`, una sera abbasserebbe l'umore di
## tutto il villaggio — che non è un colore, è un giudizio quotidiano su
## chiunque.
func _il_colore_non_e_una_porta(t) -> void:
	var l = LIMBICO.new()
	l.setup({})
	var prima: float = float(l.bersaglio_umore())
	l.neuro["melatonina"] = 1.0
	t.almost(float(l.bersaglio_umore()), prima,
			"la melatonina non muove l'umore di un bit", 1e-12)
	l.neuro["melatonina"] = 0.0
	t.almost(float(l.bersaglio_umore()), prima, "…e nemmeno a zero", 1e-12)


## Il degrado: senza `notte` non succede niente. È la condizione dei banchi,
## del Prologo e del diorama del titolo — e di un binario vecchio, che il
## metodo `fase_circadiana` non ce l'ha proprio.
func _senza_notte_non_succede_niente(t) -> void:
	var amb := {"luce": 0.0, "pioggia": 0.0, "temperatura": 20.0}
	var prod: Dictionary = LIMBICO.produzione_ambientale(amb, false)
	t.almost(float(prod["melatonina"]), 0.0,
			("col buio pieno ma senza la propria notte la melatonina resta a "
			+ "zero: il degrado va verso «non succede niente»"), 1e-12)
	var l = LIMBICO.new()
	l.setup({})
	for _i in 600:
		l.passo_neuro(1.0, amb, false)
	t.almost(float(l.neuro["melatonina"]), 0.0,
			"…e resta zero anche dopo dieci minuti di buio", 1e-9)


## ⚠️ **UN ANTICIPO MALATO NON DEVE AVVELENARE LA CHIMICA.**
##
## `neuro` è ricorsivo e `clampf(NaN)` è NaN: **un NaN è assorbente**, e ne
## basta uno per un fotogramma solo — già misurato altrove, quattro canali su
## sette morti per sempre. La rampa divide per l'anticipo, quindi un anticipo
## NaN uscirebbe come NaN: il cancello sta nella forma NEGATA del confronto
## (`!(x > 0)`), che contro NaN è vera mentre `x >= 1.0` è falsa.
func _un_anticipo_malato_non_avvelena(t, m) -> void:
	for cattivo in [NAN, -1.0, INF]:
		var f: float = float(m.debug_fase_circadiana(0, -1, 0.70, cattivo))
		t.ok(is_finite(f), "anticipo %s: la fase resta un numero (%s)"
				% [str(cattivo), str(f)])
		t.almost(f, 0.0, "…e vale zero, che e' il gioco di ieri", 1e-12)


## ⚠️ **IL CABLAGGIO, e non il pezzo.** Sei volte in questo progetto un sistema
## completo, provato e VERDE non aveva un solo lettore in partita. Qui la fase
## la calcola il C++ e la chimica la consuma, ma in mezzo c'è UNA riga in
## `Visitors._ciclo_sonno`: se sparisce, tutto questo lavoro è aritmetica che
## nessuno esegue — e le altre guardie di questo file resterebbero verdi.
##
## Si chiama il ciclo VERO, con l'ora dentro la rampa di quel residente.
func _il_villaggio_passa_la_notte_alla_chimica(t) -> void:
	var vis = VicinoDiProva.new()
	t.stage(vis)
	var corpo := Node3D.new()
	corpo.set_script(preload("res://scenes/npc/Visitor.gd"))
	t.stage(corpo)
	corpo.set("dna", preload("res://scenes/npc/ChibiDNA.gd").generate(5150))
	var r := {"label": "N", "cell": Vector2i(0, 0), "species": "chibi",
			"node": corpo, "dna": corpo.get("dna")}
	(vis.get("_residents") as Array).append(r)
	# l'ora sta DENTRO la finestra di sonno di chiunque (0.85 > 0.80/0.92? no:
	# 0.95 lo e' per tutti e due i profili), quindi la fase e' piena.
	for _i in 40:
		vis.call("_ciclo_sonno", 0.5, 0.95)
	var a = (vis.get("_animi") as Dictionary).get("N")
	t.ok(a != null, "il ciclo del sonno ha fatto nascere l'animo")
	if a == null:
		return
	var m2: float = float((a.limbico.neuro as Dictionary).get("melatonina", 0.0))
	t.ok(m2 > 0.05,
			("il villaggio passa la propria notte alla chimica: dopo venti "
			+ "secondi dentro la finestra la melatonina e' %.4f") % m2)

	# --- la controprova: a mezzogiorno, con lo stesso buio, resta a zero
	var vis2 = VicinoDiProva.new()
	t.stage(vis2)
	var corpo2 := Node3D.new()
	corpo2.set_script(preload("res://scenes/npc/Visitor.gd"))
	t.stage(corpo2)
	corpo2.set("dna", preload("res://scenes/npc/ChibiDNA.gd").generate(5150))
	(vis2.get("_residents") as Array).append({"label": "N",
			"cell": Vector2i(0, 0), "species": "chibi", "node": corpo2,
			"dna": corpo2.get("dna")})
	for _j in 40:
		vis2.call("_ciclo_sonno", 0.5, 0.50)
	var b = (vis2.get("_animi") as Dictionary).get("N")
	var m3: float = float((b.limbico.neuro as Dictionary).get("melatonina", 0.0)) \
			if b != null else -1.0
	t.almost(m3, 0.0,
			("e a meta' pomeriggio col buio pieno resta a zero (%.4f): "
			+ "la sorgente e' la propria notte, non la luce") % m3, 1e-6)

	# ⚠️ **E IL DEGRADO PER UN BINARIO VECCHIO.** Le GDExtension si caricano
	# all'avvio: chi apre il gioco con una libreria compilata prima di questa
	# riga non ha il simbolo, e un metodo che non esiste e' un errore a
	# runtime per residente per fotogramma — milleseicento al secondo con
	# ventotto vicini, con la suite verde. Qui si spegne la bandiera a mano e
	# si pretende il gioco di ieri.
	#
	# ⚠️ **RESIDUO DICHIARATO:** questo caso prova che *con la bandiera
	# spenta* non succede niente, ma NON che la bandiera venga davvero
	# consultata: nel banco il binario ha sempre il simbolo, quindi la
	# mutazione che sostituisce `_ecs_sa_la_notte` con `true` e' inosservabile
	# — misurato, zero asserzioni rosse. Per vederla servirebbe una `.dylib`
	# senza il metodo, che una suite non puo' fabbricare.
	var vis3 = VicinoDiProva.new()
	t.stage(vis3)
	var corpo3 := Node3D.new()
	corpo3.set_script(preload("res://scenes/npc/Visitor.gd"))
	t.stage(corpo3)
	corpo3.set("dna", preload("res://scenes/npc/ChibiDNA.gd").generate(5150))
	(vis3.get("_residents") as Array).append({"label": "N",
			"cell": Vector2i(0, 0), "species": "chibi", "node": corpo3,
			"dna": corpo3.get("dna")})
	# ⚠️ un giro a vuoto PRIMA di spegnere: e' `_ensure_ecs` ad accendere la
	# bandiera, e succede al primo ciclo. Spegnendola dopo il primo giro si
	# misurerebbe quel giro (0.0031 di melatonina, misurato) e il caso
	# fallirebbe per una ragione che non e' quella che sorveglia.
	vis3.call("_ciclo_sonno", 0.5, 0.95)
	vis3.set("_ecs_sa_la_notte", false)
	var c3 = (vis3.get("_animi") as Dictionary).get("N")
	if c3 != null:
		(c3.limbico.neuro as Dictionary)["melatonina"] = 0.0
	for _k in 40:
		vis3.call("_ciclo_sonno", 0.5, 0.95)
	var m4: float = float((c3.limbico.neuro as Dictionary).get("melatonina", 0.0)) \
			if c3 != null else -1.0
	t.almost(m4, 0.0,
			("con un binario che non sa rispondere il gioco e' identico a "
			+ "ieri (%.4f): il degrado va sempre verso «non succede niente»")
					% m4, 1e-6)


## Il registro VERO col solo `_ready` scavalcato: `_ciclo_sonno`,
## `_ensure_ecs`, `_ensure_brain`, il ponte e il passo della chimica restano
## quelli del gioco.
##
## ⚠️ **E il cielo si DÀ, non si finge.** `_ciclo_sonno` rinfresca `_ambiente`
## da sé (`_leggi_ambiente`), e senza un `DayNight` nell'albero quel
## dizionario torna vuoto — che è il degrado dichiarato di `Limbico`, «senza
## mondo non succede niente». Qui si scavalca la sola LETTURA del cielo, che è
## un dato: tutto quello che decide qualcosa resta del gioco. (È lo stesso
## criterio del finto BuildSystem di `test_insieme`, che dice dove sono i
## pezzi e non decide niente.)
class VicinoDiProva extends "res://scenes/npc/Visitors.gd":
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)

	func _process(_d: float) -> void:
		pass

	func _leggi_ambiente() -> Dictionary:
		return {"luce": 0.0, "pioggia": 0.0, "temperatura": 20.0}
