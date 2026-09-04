extends RefCounted

## LE GUARDIE DELLA RIPRODUCIBILITÀ — i dadi nominati, le leve, e l'orologio
## che non deve tornare in posizione di seme.
##
## Il difetto che questo file sorveglia è costato la validità di TUTTE le
## misure psicologiche del progetto: due corse della stessa misura con gli
## stessi parametri davano 0,31 e 1,77 righe di co-presenza per residente,
## perché il dado di ogni vicino partiva dall'orologio
## (`VillagerBrain.setup`). Senza ripetizione non c'è ablazione, e senza
## ablazione un numero non è un risultato.
##
## ⚠️ Tre lezioni di banco sono cablate qui dentro, e vengono da guardie che
## in questo progetto erano già state pagate:
##
## 1. **si spogliano i commenti PRIMA di accusare** — e qui più che altrove,
##    perché la cura all'epicentro NOMINA la chiamata vietata per spiegare
##    cosa c'era prima. Una guardia che legge i commenti accusa chi ha già
##    curato il difetto. Lo spogliatore è quello di `test_fiato`, che è
##    l'unico che toglie anche i commenti in coda e rispetta le virgolette,
##    e si AUTOCOLLAUDA prima di essere creduto;
## 2. **si conta quanti file si sono davvero letti** — una guardia che per
##    un percorso sbagliato ne legge zero è verde (solo `test_cablaggio`
##    aveva questa riga);
## 3. **la proprietà che conta si prova COMPORTAMENTALMENTE**, non cercando
##    stringhe: un `contains()` resta verde anche svuotando la funzione.

const RADICI := ["res://scenes", "res://systems"]


func run(t) -> void:
	_lo_spogliatore_sa_leggere(t)
	_una_chiave_da_lo_stesso_dado(t)
	_chiavi_diverse_dadi_diversi(t)
	_la_radice_cambia_tutto(t)
	_un_consumatore_in_piu_non_sposta_gli_altri(t)
	_la_radice_si_posa_e_si_dimentica(t)
	_il_canale_libero_e_dichiarato(t)
	_lorologio_non_semina_piu(t)
	_ogni_leva_ha_un_lettore(t)
	_ogni_lettore_usa_un_nome_dichiarato(t)
	_le_leve_partono_accese(t)
	_una_leva_sconosciuta_non_spegne_niente(t)
	_il_gioco_non_tocca_le_leve(t)
	_la_condizione_si_sa_dire(t)


# ────────────────────────────────────────────────────────── i dadi

func _una_chiave_da_lo_stesso_dado(t) -> void:
	Dadi.posa_radice(4242)
	var a := _tira(Dadi.rng(Dadi.VILLAGGIO, "Ciliegia"), 8)
	var b := _tira(Dadi.rng(Dadi.VILLAGGIO, "Ciliegia"), 8)
	t.eq(a, b, "lo stesso (flusso, chiave, radice) dà la stessa vita")


func _chiavi_diverse_dadi_diversi(t) -> void:
	Dadi.posa_radice(4242)
	var a := _tira(Dadi.rng(Dadi.VILLAGGIO, "Ciliegia"), 8)
	var b := _tira(Dadi.rng(Dadi.VILLAGGIO, "Nocciola"), 8)
	t.ok(a != b, "due vicini non tirano gli stessi numeri")
	var c := _tira(Dadi.rng(Dadi.AMBIENTE, "Ciliegia"), 8)
	t.ok(a != c, "…e nemmeno lo stesso nome in due flussi diversi")


func _la_radice_cambia_tutto(t) -> void:
	Dadi.posa_radice(1)
	var a := _tira(Dadi.rng(Dadi.VILLAGGIO, "Ciliegia"), 8)
	Dadi.posa_radice(2)
	var b := _tira(Dadi.rng(Dadi.VILLAGGIO, "Ciliegia"), 8)
	t.ok(a != b, "cambiare radice cambia la partita")
	Dadi.posa_radice(1)
	var c := _tira(Dadi.rng(Dadi.VILLAGGIO, "Ciliegia"), 8)
	t.eq(a, c, "…e tornare alla radice di prima la ridà identica")


## ⭐ LA PROPRIETÀ CHE TIENE IN PIEDI TUTTO IL LAVORO, e l'unica che si
## perderebbe «ottimizzando» i dadi in un flusso condiviso.
##
## Con un generatore per flusso, aggiungere un chiamante sposta tutti i
## numeri a valle: spegnere un meccanismo per misurarlo cambierebbe anche
## tutti gli altri, e il banco delle repliche direbbe numeri che non vogliono
## dire niente. Qui si dimostra il contrario: B non si accorge di A.
func _un_consumatore_in_piu_non_sposta_gli_altri(t) -> void:
	Dadi.posa_radice(4242)
	var prima := _tira(Dadi.rng(Dadi.VILLAGGIO, "B"), 6)
	# adesso arriva un consumatore nuovo, e ne tira cento
	var nuovo := Dadi.rng(Dadi.VILLAGGIO, "A")
	for i in 100:
		nuovo.randf()
	var dopo := _tira(Dadi.rng(Dadi.VILLAGGIO, "B"), 6)
	t.eq(prima, dopo,
			"un consumatore in più non sposta di un bit la vita degli altri")


func _la_radice_si_posa_e_si_dimentica(t) -> void:
	Dadi.posa_radice(7)
	t.eq(Dadi.radice(), 7, "la radice posata è quella che si legge")
	t.ok(Dadi.radice_posata(), "e il modulo sa che qualcuno l'ha posata")
	Dadi.posa_radice(0)
	t.eq(Dadi.radice(), 0, "zero è una radice legittima, non «nessuna»")
	t.ok(Dadi.radice_posata(), "…e non va scambiata per «non ancora deciso»")
	Dadi.dimentica()
	t.ok(not Dadi.radice_posata(), "dimentica() rimette il modulo com'era")
	# e senza nessuno che l'abbia posata se ne conia una: il degrado va verso
	# «il gioco funziona», mai verso «tutti i villaggi nascono identici».
	var coniata := Dadi.radice()
	t.ok(Dadi.radice_posata(), "chiederla la conia")
	t.eq(Dadi.radice(), coniata, "…e da lì in poi è ferma")
	Dadi.posa_radice(4242)


func _il_canale_libero_e_dichiarato(t) -> void:
	t.ok(Dadi.FLUSSI.has(Dadi.LIBERO),
			"il canale cosmetico è DICHIARATO, non sottinteso")
	t.eq(Dadi.FLUSSI.size(), 4, "i flussi sono quattro e si contano")
	# il libero non è seminato, ed è tutta la sua definizione
	Dadi.posa_radice(4242)
	var a := _tira(Dadi.libero(), 6)
	var b := _tira(Dadi.libero(), 6)
	t.ok(a != b, "il canale libero NON è riproducibile, ed è la sua natura")


# ─────────────────────────────────────────── l'orologio in posizione di seme

## Le sorgenti che non devono mai finire dentro un seme. Non è un divieto
## generico: `Time.get_ticks_usec()` cronometra (ed è giusto), e
## `get_instance_id()` fa da chiave a dei dizionari (ed è giusto). Quello che
## non si può fare è **seminarci un dado**, e la guardia guarda la RIGA:
## deve contenere insieme una di queste e un'assegnazione di seme.
const VIETATE := ["get_ticks_msec", "get_ticks_usec", "get_unix_time_from_system",
		"get_instance_id", "randomize()"]


func _lorologio_non_semina_piu(t) -> void:
	var colpevoli: Array = []
	var visti := 0
	for radice in RADICI:
		for path in _tutti_i_gd(radice):
			visti += 1
			# ⚠️ L'UNICA ESENZIONE, ed è la definizione stessa del modulo:
			# `Dadi.conia()` e `Dadi.libero()` SONO l'entropia autorizzata di
			# questo progetto. Esentare il file è il modo di dire che è UNO,
			# e che si vede: chiunque altro chieda entropia vera compare in
			# questo elenco.
			if path.ends_with("/Dadi.gd"):
				continue
			var src := _senza_commenti(FileAccess.get_file_as_string(path))
			var n := 0
			for riga in src.split("\n"):
				n += 1
				if not _e_una_seminatura(riga):
					continue
				for cattiva in VIETATE:
					if riga.contains(cattiva):
						colpevoli.append("%s:%d (%s)"
								% [path.get_file(), n, cattiva])
	# la soglia è sotto il numero vero (140 file al 2026-09-04): serve a
	# beccare uno scandaglio che per un percorso sbagliato legge zero file e
	# passa in silenzio — è la riga di sanità che solo `test_cablaggio` aveva.
	t.ok(visti >= 120,
			"lo scandaglio ha davvero letto i sorgenti (%d file)" % visti)
	t.eq(colpevoli.size(), 0,
			"nessun dado seminato dall'orologio o da un indirizzo: %s"
			% ", ".join(colpevoli))


## Una riga è una seminatura se ci si scrive dentro un seme. `randomize()` è
## una seminatura per definizione — è la sua unica funzione.
static func _e_una_seminatura(riga: String) -> bool:
	if riga.contains("randomize()"):
		return true
	return riga.contains(".seed") or riga.contains("seed(") \
			or riga.contains(".state")


func _lo_spogliatore_sa_leggere(t) -> void:
	t.ok(_senza_commenti("var x = 1  # randomize() qui è solo una parola")
			.find("randomize") < 0,
			"la guardia non accusa un commento in CODA")
	t.ok(_senza_commenti("# _rng.seed = Time.get_ticks_msec()")
			.find("get_ticks") < 0,
			"…né una riga interamente di commento")
	t.ok(_senza_commenti("\t_rng.seed = Time.get_ticks_msec()")
			.find("get_ticks") >= 0,
			"…ma vede il codice vero")
	t.ok(_senza_commenti("var s := \"# non è un commento\"")
			.find("non è un commento") >= 0,
			"…e non si fa ingannare da un cancelletto fra virgolette")
	t.ok(_e_una_seminatura("\t_rng.seed = 3"), "riconosce una seminatura")
	t.ok(not _e_una_seminatura("\tvar t := Time.get_ticks_usec()"),
			"…e lascia in pace un cronometro")


# ────────────────────────────────────────────────────────────── le leve

func _le_leve_partono_accese(t) -> void:
	Leve.dimentica()
	for nome in Leve.MECCANISMI:
		t.ok(Leve.acceso(str(nome)),
				"di serie «%s» è acceso: una leva è uno strumento di misura,"
				% nome + " non una configurazione")
	t.ok(Leve.spente().is_empty(), "e non ce n'è nessuna spenta")


func _una_leva_sconosciuta_non_spegne_niente(t) -> void:
	Leve.dimentica()
	t.ok(Leve.acceso("non_esiste_questa"),
			"un nome sconosciuto resta ACCESO: spegnere per un errore di"
			+ " battitura è il guasto che si legge come un risultato")
	Leve.spegni("non_esiste_questa")
	t.ok(Leve.spente().is_empty(), "…e non si può nemmeno spegnere")


func _la_condizione_si_sa_dire(t) -> void:
	Leve.dimentica()
	t.eq(Leve.condizione(), "tutto", "la condizione di controllo ha un nome")
	Leve.spegni(Leve.INSIEME)
	t.ok(not Leve.acceso(Leve.INSIEME), "spegnere spegne")
	t.eq(Leve.condizione(), "senza:insieme", "…e si sa dire in una parola")
	Leve.spegni(Leve.DERIVA)
	t.eq(Leve.condizione(), "senza:deriva+insieme",
			"due leve spente si dicono in ordine, o due referti della stessa"
			+ " condizione non si riconoscerebbero")
	Leve.accendi(Leve.INSIEME)
	t.ok(Leve.acceso(Leve.INSIEME), "e si riaccende")
	Leve.dimentica()


## ⚠️ UNA LEVA SENZA LETTORE È UNA PROMESSA VUOTA: il banco la spegne, non
## succede niente, e il referto si legge come «quel meccanismo non conta».
func _ogni_leva_ha_un_lettore(t) -> void:
	var sorgenti := _tutta_la_roba()
	for nome in Leve.MECCANISMI:
		# la costante è il nome in maiuscolo: è un'invariante, non una
		# comodità — è ciò che rende possibile risalire dal sorgente al
		# registro senza chiedere al modulo di riflettere su sé stesso.
		var costante := str(nome).to_upper()
		var letta := sorgenti.contains("Leve.acceso(Leve.%s)" % costante)
		t.ok(letta, "la leva «%s» ha almeno un lettore nel gioco" % nome)


## …e il verso opposto: un nome non dichiarato non fallisce da nessuna parte,
## smette solo di spegnere qualcosa.
func _ogni_lettore_usa_un_nome_dichiarato(t) -> void:
	var fuori: Array = []
	var letture := 0
	for radice in RADICI:
		for path in _tutti_i_gd(radice):
			var src := _senza_commenti(FileAccess.get_file_as_string(path))
			var da := 0
			while true:
				var i := src.find("Leve.acceso(", da)
				if i < 0:
					break
				letture += 1
				da = i + 12
				var j := src.find(")", i)
				var arg := src.substr(i + 12, maxi(0, j - i - 12)).strip_edges()
				if not arg.begins_with("Leve."):
					fuori.append("%s: %s" % [path.get_file(), arg])
					continue
				var costante := arg.substr(5)
				if not Leve.MECCANISMI.has(costante.to_lower()):
					fuori.append("%s: %s" % [path.get_file(), arg])
	t.ok(letture >= 4, "lo scandaglio ha trovato le letture (%d)" % letture)
	t.eq(fuori.size(), 0,
			"ogni lettura di una leva usa una costante dichiarata: %s"
			% ", ".join(fuori))


## Nel gioco le leve non le tocca nessuno: si muovono da `CHIBI_LEVE` o da un
## banco. È la stessa guardia che `test_regia` fa su `debug_occlusione`, e
## cerca la SCRITTURA, mai la parola nuda.
func _il_gioco_non_tocca_le_leve(t) -> void:
	var colpevoli: Array = []
	for radice in RADICI:
		for path in _tutti_i_gd(radice):
			var src := _senza_commenti(FileAccess.get_file_as_string(path))
			for scrittura in ["Leve.spegni(", "Leve.accendi(", "Leve.dimentica(",
					"Dadi.posa_radice(", "Dadi.dimentica("]:
				if src.contains(scrittura):
					colpevoli.append("%s → %s" % [path.get_file(), scrittura])
	# il proprietario della radice è UNO, e si dichiara qui.
	var ammessi := ["BuildSystem.gd → Dadi.posa_radice("]
	var veri: Array = []
	for c in colpevoli:
		if not (c in ammessi):
			veri.append(c)
	t.eq(veri.size(), 0,
			"nel gioco nessuno spegne una leva né posa una radice: %s"
			% ", ".join(veri))


# ─────────────────────────────────────────────────────────────── ferri

static func _tira(g: RandomNumberGenerator, n: int) -> Array:
	var v: Array = []
	for i in n:
		v.append(g.randf())
	return v


func _tutta_la_roba() -> String:
	var s := ""
	for radice in RADICI:
		for path in _tutti_i_gd(radice):
			s += _senza_commenti(FileAccess.get_file_as_string(path))
	return s


static func _tutti_i_gd(radice: String) -> Array:
	var fuori: Array = []
	var d := DirAccess.open(radice)
	if d == null:
		return fuori
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		var p := radice + "/" + n
		if d.current_is_dir():
			if not n.begins_with("."):
				fuori.append_array(_tutti_i_gd(p))
		elif n.ends_with(".gd"):
			fuori.append(p)
		n = d.get_next()
	d.list_dir_end()
	return fuori


## Lo spogliatore di `test_fiato`: toglie anche i commenti in coda e rispetta
## le virgolette. Qui è obbligatorio, non consigliato — la cura all'epicentro
## nomina apposta la chiamata vietata per spiegare cosa c'era prima.
static func _senza_commenti(src: String) -> String:
	var out := ""
	for riga in src.split("\n"):
		var pulita := ""
		var in_str := false
		var i := 0
		while i < riga.length():
			var c := riga[i]
			if c == "\"":
				in_str = not in_str
			elif c == "#" and not in_str:
				break
			pulita += c
			i += 1
		out += pulita + "\n"
	return out
