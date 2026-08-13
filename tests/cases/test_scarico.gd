extends RefCounted
## IL BANCO DEL CORRIERE — il viaggio, senza rete e senza due gigabyte.
##
## Qui si prova quello che succede al modello mentre arriva: la ripresa, il
## server che ignora il `Range`, la linea che cade, i byte che non combaciano,
## l'annullamento, il disco pieno, la porta chiusa. Sono tutte cose che una
## rete vera fa e che **nessuna suite può aspettare** — la CI non ha rete, e
## due gigabyte e mezzo non ci starebbero comunque.
##
## ────────────────────────────────────────────────────────────────────────
## COME, SENZA MENTIRE
## ────────────────────────────────────────────────────────────────────────
##
## La macchina che cammina è **quella di produzione** (`ScaricoMacchina`), con
## i suoi passi, i suoi file, il suo SHA-256 e la sua rinomina. Quello che si
## toglie di mezzo è **il socket**: `_rete` è un tubo con sei metodi e nessuna
## decisione, e qui gliene si dà uno che ha i byte in pancia invece che sulla
## rete. Non è un doppio della cosa da provare — è la stessa lezione di
## `test_llm_banco.gd`: «un doppio che mente è peggio di nessun doppio; nessun
## doppio ti fa scrivere un test vero, uno che mente ti fa credere di averlo
## già scritto».
##
## Il tubo finto perciò **non sa niente di riprese, offset e impronte**: sa
## solo fare le tre cose che fa un server — mandare byte, smettere di mandarli,
## rispondere un codice. Se un giorno qualcuno gli aggiungesse un `if` che
## somiglia a una regola della macchina, questo file avrebbe smesso di provare
## qualcosa.
##
## ⚠️ **E L'ORACOLO NON È LA MACCHINA.** Alla fine di ogni viaggio si
## confrontano **i byte sul disco** con quelli che il tubo aveva in pancia, uno
## per uno. Chiedere alla macchina se è contenta di sé stessa è chiedere al
## giudice se è d'accordo con sé — l'errore che `tools/misura_cammino.gd`
## esiste per non commettere.

const MACCHINA := preload("res://systems/ScaricoMacchina.gd")
const RETE := preload("res://systems/ScaricoRete.gd")
const SCARICO := preload("res://systems/Scarico.gd")

## La cartella di lavoro del banco: **mai** quella vera. Il modello di chi sta
## giocando su questa macchina non si tocca, e un banco che cancella
## `user://modelli/pensieri.gguf` butterebbe venti minuti di scarico a
## qualcuno.
const CASA := "user://prova_scarico"


func run(t) -> void:
	_le_parti_pure(t)
	_l_indirizzo_si_spezza_bene(t)
	_il_viaggio_pulito(t)
	_la_linea_cade_e_si_riprende(t)
	_il_server_che_ignora_la_ripresa_non_cuce_un_mostro(t)
	_quello_che_arriva_rovinato_si_butta(t)
	_annullare_lascia_un_pezzo_riprendibile(t)
	_lo_spazio_si_guarda_prima_di_chiedere(t)
	_il_preflight_ferma_un_file_cambiato(t)
	_una_porta_chiusa_non_si_bussa_cinque_volte(t)
	_il_rimbalzo_porta_lo_stesso_pezzo(t)
	_una_linea_che_non_porta_niente_si_arrende(t)
	_il_thread_vero_fa_il_giro(t)
	_le_parole_ci_sono_tutte(t)
	_niente_rete_da_nessun_altra_parte(t)
	_il_banco_non_lo_chiama_nessuno(t)


# =========================================================================
# IL TUBO FINTO — tre manopole, e sono tre cose che fa un server
# =========================================================================

class Tubo extends RefCounted:
	var byte := PackedByteArray()      ## quello che il server ha
	var etag := ""                     ## l'impronta che dichiara nel preflight
	var dimensione_detta := -1         ## quanto dice di pesare (-1 = la verità)
	var cade_a := -1                   ## chiude la connessione dopo N byte di QUESTA risposta
	var ignora_range := false          ## risponde 200 anche a chi chiede un pezzo
	var codice_forzato := 0            ## risponde sempre questo codice
	var sporca_da := -1                ## da qui in poi manda byte diversi
	var rimbalza_a := ""               ## la prima richiesta risponde 302 verso qui
	var a_pezzi := 8192                ## quanti byte per volta
	var ritardo_us := 0                ## quanto ci mette a mandarne uno (una linea vera non è istantanea)
	var content_range_storto := 0      ## dichiara di mandare un pezzo che comincia altrove

	# quello che il banco guarda dopo
	var richieste: Array[String] = []
	var range_chiesti: Array[String] = []
	var teste_viste := 0

	var _da := 0
	var _mandati := 0
	var _codice := 200
	var _teste := {}
	var _teste_date := false
	var _solo_testa := false
	var _pezzo := PackedByteArray()
	var _chiusa := true
	var _gia_rimbalzato := false

	func chiedi(url: String, teste: PackedStringArray, solo_testa: bool) -> int:
		richieste.append(url)
		_da = 0
		var r := ""
		for riga in teste:
			if riga.to_lower().begins_with("range:"):
				r = riga
				_da = int(riga.split("=")[1].split("-")[0])
		range_chiesti.append(r)
		_solo_testa = solo_testa
		_teste_date = false
		_mandati = 0
		_chiusa = false
		_pezzo = PackedByteArray()
		_teste = {}
		var quanto := byte.size() if dimensione_detta < 0 else dimensione_detta
		if solo_testa:
			teste_viste += 1
			_codice = codice_forzato if codice_forzato > 0 else 200
			if etag != "":
				_teste["x-linked-etag"] = '"%s"' % etag
			_teste["x-linked-size"] = str(quanto)
			return OK
		# L'ORIGINE rimbalza SEMPRE (è quello che fa Hugging Face: ogni
		# richiesta al repository risponde 302 verso un indirizzo firmato
		# nuovo). Chi è già arrivato alla CDN, no.
		if rimbalza_a != "" and url != rimbalza_a:
			_gia_rimbalzato = true
			_codice = 302
			_teste["location"] = rimbalza_a
			return OK
		if codice_forzato > 0:
			_codice = codice_forzato
			return OK
		if _da > 0 and not ignora_range:
			_codice = 206
			var dichiarato := _da + content_range_storto
			_teste["content-range"] = "bytes %d-%d/%d" % [dichiarato, byte.size() - 1, quanto]
		else:
			_codice = 200
			_da = 0
			_teste["content-length"] = str(quanto)
		return OK

	func avanza() -> int:
		if _chiusa:
			return RETE.GUASTO
		if not _teste_date:
			_teste_date = true
			return RETE.TESTE
		if _solo_testa or _codice >= 300:
			return RETE.FINE
		if cade_a >= 0 and _mandati >= cade_a:
			return RETE.FINE
		var resto := byte.size() - (_da + _mandati)
		if resto <= 0:
			return RETE.FINE
		if ritardo_us > 0:
			OS.delay_usec(ritardo_us)
		var quanti := mini(resto, a_pezzi)
		if cade_a >= 0:
			quanti = mini(quanti, cade_a - _mandati)
		# ⚠️ IL SERVER CHE SBAGLIA PEZZO MANDA DAVVERO I BYTE SBAGLIATI, non
		# solo un'intestazione bugiarda: la prima stesura del banco dichiarava
		# un `Content-Range` storto e poi mandava i byte giusti, quindi
		# spegnere il controllo lasciava il file **corretto lo stesso** e
		# nessuna asserzione se ne accorgeva. Un doppio che mente in favore
		# del codice è peggio di nessun doppio.
		var da := _da + (content_range_storto if _codice == 206 else 0) + _mandati
		_pezzo = byte.slice(da, da + quanti)
		if sporca_da >= 0 and da + quanti > sporca_da:
			for i in _pezzo.size():
				if da + i >= sporca_da:
					_pezzo[i] = (_pezzo[i] + 1) & 0xFF
		_mandati += quanti
		return RETE.CORPO

	func codice() -> int: return _codice
	func testa(nome: String) -> String: return str(_teste.get(nome.to_lower(), ""))
	func pezzo() -> PackedByteArray: return _pezzo
	func chiudi() -> void: _chiusa = true


# =========================================================================
# 1. LE PARTI CHE SI POSSONO INTERROGARE DA SOLE
# =========================================================================

## FALSIFICATO una per una: mandando il `Range` anche a zero (1 rossa: si
## chiederebbe un 206 dove basta un 200); togliendo la rincorsa all'indietro
## (1); contando lo spazio sull'intero file invece che su quel che manca (1:
## chi riprende a tre quarti si sentirebbe dire che non ha spazio); non
## togliendo le virgolette all'etag (1: il preflight direbbe SEMPRE che a
## monte c'è un altro file).
func _le_parti_pure(t) -> void:
	var senza := MACCHINA.teste_di(0)
	var con := MACCHINA.teste_di(1048576)
	var testa := MACCHINA.teste_di(-1)
	t.ok(not "\n".join(senza).to_lower().contains("range"),
			"dall'inizio non si chiede nessun pezzo: si chiede il file")
	t.ok("\n".join(con).contains("Range: bytes=1048576-"),
			"riprendendo si chiede da dove eravamo, fino alla fine")
	t.ok(not "\n".join(testa).to_lower().contains("range"),
			"e il preflight non chiede pezzi affatto")

	t.eq(MACCHINA.offset_di_ripresa(10_000_000, 1 << 20), 10_000_000 - (1 << 20),
			"si riprende un mebibyte più indietro di dove si era arrivati")
	t.eq(MACCHINA.offset_di_ripresa(1000, 1 << 20), 0,
			"e se si era arrivati a meno di così, si ricomincia")

	t.eq(MACCHINA.serve_spazio(2_489_757_856, 0, 0), 2_489_757_856,
			"da zero serve tutto il file")
	t.eq(MACCHINA.serve_spazio(2_489_757_856, 2_000_000_000, 0), 489_757_856,
			"riprendendo serve solo quel che manca")
	t.eq(MACCHINA.serve_spazio(100, 500, 0), 0,
			"e non serve mai un numero negativo")

	# ⚠️ ZERO VUOL DIRE «NON LO SO», E «NON LO SO» NON È MAI UN NO. Una
	# piattaforma che non sa rispondere non deve spegnere la funzione a
	# nessuno: è la stessa regola con cui `llm_memoria.cpp` legge la RAM.
	t.ok(MACCHINA.spazio_basta(12_000_000_000, 2_600_000_000), "dodici giga bastano")
	t.ok(not MACCHINA.spazio_basta(1_000_000_000, 2_600_000_000), "uno no, e si dice")
	t.ok(MACCHINA.spazio_basta(0, 2_600_000_000),
			"e un disco che non sa dire quanto è libero non è un disco pieno")

	t.eq(MACCHINA.etag_pulito('"882E8D2D"'), "882e8d2d",
			"l'etag arriva fra virgolette, e Hugging Face lo scrive come gli pare")
	t.eq(MACCHINA.etag_pulito('W/"abc"'), "abc", "e a volte con la W davanti")

	t.eq(MACCHINA.inizio_di_content_range("bytes 1048576-2097151/2489757856"), 1048576,
			"del pezzo che arriva si legge da dove comincia")
	t.eq(MACCHINA.totale_di_content_range("bytes 1048576-2097151/2489757856"), 2489757856,
			"e quanto pesa il file intero")
	t.eq(MACCHINA.inizio_di_content_range("roba a caso"), -1,
			"e quello che non si capisce si dichiara, non si indovina")
	t.eq(MACCHINA.totale_di_content_range("bytes 0-1/*"), -1,
			"un totale sconosciuto non è zero")


## ⚠️ **L'INDIRIZZO FIRMATO DELLA CDN HA LE BARRE DENTRO LA FIRMA.** Hugging
## Face rimbalza su `us.aws.cdn.hf.co` con `Policy=` e `Signature=` in base64,
## e il base64 usa `/`: chi ricostruisce la via con uno `split("/")` la taglia
## a metà e si becca un `403` senza capire perché. (MISURATO il 2026-08-13
## sulla risposta vera.)
##
## FALSIFICATO: spezzando la via con `split("/")` (2 rosse); togliendo la
## guardia sulle parentesi quadre dell'IPv6 (1); togliendo il ramo del
## `Location` relativo (1).
func _l_indirizzo_si_spezza_bene(t) -> void:
	var casa = RETE.pezzi_di_url(SCARICO.url())
	t.eq(str(casa["host"]), "huggingface.co", "l'indirizzo di casa si spezza bene")
	t.eq(int(casa["porta"]), 443, "e https è la 443")
	t.ok(str(casa["percorso"]).ends_with(".gguf"), "la via finisce col file")

	var cdn := "https://us.aws.cdn.hf.co/xet-bridge-us/67d1/7088?Policy=eyJTdGF0/ZW1lbnQi&Signature=MEUCIA_x/y"
	var pezzi = RETE.pezzi_di_url(cdn)
	t.eq(str(pezzi["host"]), "us.aws.cdn.hf.co", "la CDN è un'altra casa")
	t.eq(str(pezzi["percorso"]), cdn.substr(cdn.find("hf.co") + 5),
			"e la via arriva intera, barre della firma comprese")

	t.eq(int(RETE.pezzi_di_url("http://127.0.0.1:8080/x")["porta"]), 8080,
			"una porta scritta si legge")
	t.eq(str(RETE.pezzi_di_url("http://[::1]:8080/x")["host"]), "[::1]",
			"e i due punti di un IPv6 non sono una porta")
	t.ok(RETE.pezzi_di_url("ftp://qualcosa/x").is_empty(),
			"quello che non è http non si capisce, e si dice")

	t.eq(MACCHINA._assoluto("https://cdn.hf.co/z", "https://huggingface.co/a/b"),
			"https://cdn.hf.co/z", "un Location intero porta dove dice")
	t.eq(MACCHINA._assoluto("/z?x=1", "https://huggingface.co/a/b"),
			"https://huggingface.co/z?x=1", "una via sola resta a casa")
	t.eq(MACCHINA._assoluto("/z", "http://127.0.0.1:8080/a"),
			"http://127.0.0.1:8080/z", "e si porta dietro la porta")


# =========================================================================
# 2. I VIAGGI
# =========================================================================

## Il caso normale: si parte, arriva tutto, l'impronta combacia, il file
## prende il suo nome.
##
## FALSIFICATO: togliendo la rinomina finale (2 rosse); togliendo il
## `flush()` prima di rileggere (1: l'impronta legge un file più corto di
## quello che c'è).
func _il_viaggio_pulito(t) -> void:
	var d := _dati(300000, 7)
	var tubo := _tubo(d)
	var m = _macchina(tubo, d)
	_corri(m)
	t.eq(m.esito(), MACCHINA.ESITO_FATTO, "il viaggio pulito arriva in fondo")
	_uguale(t, d, "e sul disco ci sono ESATTAMENTE i byte della sorgente")
	t.ok(not FileAccess.file_exists(_dove() + ".parte"),
			"del file di lavoro non resta niente")


## LA COSA PER CUI ESISTE QUESTO CODICE. Una linea domestica cade; riprendere
## da dove si era è la differenza fra una funzione usabile e una che nessuno
## riesce ad accendere.
##
## ⚠️ Il tubo cade due volte, e il banco guarda TRE cose: che si chieda il
## pezzo giusto (con la rincorsa all'indietro), che il file finale sia byte
## per byte quello vero — cioè che la cucitura non abbia un buco né una
## sovrapposizione — e che il viaggio finisca bene.
##
## FALSIFICATO: togliendo la `seek()` prima di scrivere (2 rosse: si
## riscriverebbe da capo sopra quel che c'era); chiedendo `bytes=<fatti>-`
## senza rincorsa e togliendo la `seek` insieme (2); trattando la caduta come
## un guasto invece che come un tentativo (2).
func _la_linea_cade_e_si_riprende(t) -> void:
	var d := _dati(300000, 11)
	var tubo := _tubo(d)
	tubo.cade_a = 100000
	var m = _macchina(tubo, d)
	m.indietro = 4096  # la rincorsa vera è 1 MiB: su 300 KB non riprenderebbe mai
	_corri(m)
	t.eq(m.esito(), MACCHINA.ESITO_FATTO, "cadendo due volte, si arriva lo stesso")
	_uguale(t, d, "e il file cucito è identico alla sorgente, byte per byte")
	t.ok(tubo.richieste.size() >= 3, "ci sono voluti più tentativi (%d)" % tubo.richieste.size())
	# la PRIMA richiesta con un Range è la prima ripresa: le due prima sono il
	# preflight e la partenza da zero, che un Range non ce l'hanno per scelta
	var primo_pezzo := ""
	for r in tubo.range_chiesti:
		if r != "":
			primo_pezzo = r
			break
	t.eq(primo_pezzo, "Range: bytes=%d-" % (100000 - 4096),
			"si riprende da poco PRIMA di dove si era arrivati, non da dopo")


## Un server (o un proxy in mezzo) può ignorare il `Range` e rimandare il file
## intero. Appendere quei byte in coda a quelli che c'erano darebbe un file
## lungo e sbagliato: si tronca e si ricomincia.
##
## FALSIFICATO: togliendo il ramo del 200-con-ripresa (2 rosse — il file
## finisce lungo 400000 byte invece di 300000, e l'impronta lo butta: cioè si
## paga il viaggio due volte e non si arriva mai).
func _il_server_che_ignora_la_ripresa_non_cuce_un_mostro(t) -> void:
	var d := _dati(300000, 13)
	_pulisci()
	# un pezzo di viaggio di ieri
	var f := FileAccess.open(_dove() + ".parte", FileAccess.WRITE)
	f.store_buffer(d.slice(0, 100000))
	f.close()

	var tubo := _tubo(d)
	tubo.ignora_range = true
	var m = MACCHINA.new(tubo, "https://esempio/x.gguf", _dove(), d.size(), _impronta(d))
	m.pausa_ms = 0
	m.indietro = 4096
	_corri(m)
	t.eq(m.esito(), MACCHINA.ESITO_FATTO, "si arriva lo stesso")
	_uguale(t, d, "e il file è quello giusto, non quello con l'inizio due volte")
	t.ok(_diario(m).contains("ignorato la ripresa"),
			"e nel diario c'è scritto cosa è successo, o nessuno lo saprebbe mai")

	# ⚠️ L'ALTRA FORMA DELLO STESSO GUASTO, e questa è più cattiva: il server
	# risponde 206 — «eccoti il pezzo» — ma il `Content-Range` dice che
	# comincia da un'altra parte. Fidarsi del codice e non leggere il
	# `Content-Range` vuol dire scrivere byte giusti nel posto sbagliato: il
	# file finisce lungo esattamente quanto deve, e se ne accorge solo
	# l'impronta, dopo aver riletto tutto.
	_pulisci()
	var f2 := FileAccess.open(_dove() + ".parte", FileAccess.WRITE)
	f2.store_buffer(d.slice(0, 100000))
	f2.close()
	var tubo2 := _tubo(d)
	tubo2.content_range_storto = 12345
	var m2 = MACCHINA.new(tubo2, "https://esempio/x.gguf", _dove(), d.size(), _impronta(d))
	m2.pausa_ms = 0
	m2.indietro = 4096
	_corri(m2)
	t.eq(m2.esito(), MACCHINA.ESITO_FATTO, "un pezzo che comincia altrove non fa saltare il viaggio")
	_uguale(t, d, "e il file resta quello vero: si è ricominciato da capo, non cucito storto")


## ⚠️ IL GUASTO CHE QUESTA FASE ESISTE PER RENDERE IMPOSSIBILE: un file
## rovinato che resta sul disco. `Llm.percorso_modello()` lo troverebbe, il
## portiere lo rifiuterebbe, e la funzione resterebbe spenta **per sempre**
## senza che chi gioca possa collegare le due cose.
##
## FALSIFICATO: togliendo il `remove_absolute` dopo l'impronta sbagliata (2
## rosse); confrontando l'impronta senza `to_lower()` (1).
func _quello_che_arriva_rovinato_si_butta(t) -> void:
	var d := _dati(300000, 17)
	var tubo := _tubo(d)
	tubo.sporca_da = 250000
	var m = _macchina(tubo, d)
	_corri(m)
	t.eq(m.esito(), MACCHINA.ESITO_IMPRONTA, "i byte non combaciano, e il viaggio non è riuscito")
	t.ok(not FileAccess.file_exists(_dove()),
			"il modello NON c'è: un file rovinato col nome giusto è il guasto peggiore")
	t.ok(not FileAccess.file_exists(_dove() + ".parte"),
			"e non resta nemmeno il pezzo, o si riprenderebbe da roba marcia")


## Annullare deve fermare davvero, e lasciare qualcosa di riprendibile — non
## un file che «sembra valido».
##
## FALSIFICATO: facendo prendere alla macchina il nome definitivo prima
## dell'impronta (2 rosse); ignorando `annulla()` dentro `passo()` (2).
func _annullare_lascia_un_pezzo_riprendibile(t) -> void:
	var d := _dati(300000, 19)
	var tubo := _tubo(d)
	tubo.a_pezzi = 4096
	var m = _macchina(tubo, d)
	# venti passi, poi ci si ferma: siamo in mezzo al corpo
	for i in 20:
		m.passo()
	m.annulla()
	t.eq(m.passo(), MACCHINA.PASSO_FINE, "annullare ferma al primo passo dopo")
	t.eq(m.esito(), MACCHINA.ESITO_ANNULLATO, "e lo dice")
	t.ok(not FileAccess.file_exists(_dove()),
			"quello che c'è sul disco NON ha il nome del modello")
	var pezzo := _peso(_dove() + ".parte")
	t.ok(pezzo > 0 and pezzo < d.size(),
			"ma c'è, ed è un pezzo (%d byte): domani si riprende da lì" % pezzo)

	# e la controprova: da quel pezzo si arriva in fondo
	var tubo2 := _tubo(d)
	var m2 = MACCHINA.new(tubo2, "https://esempio/x.gguf", _dove(), d.size(), _impronta(d))
	m2.pausa_ms = 0
	m2.indietro = 4096
	_corri(m2)
	t.eq(m2.esito(), MACCHINA.ESITO_FATTO, "ripartendo dal pezzo si arriva in fondo")
	_uguale(t, d, "e il file è giusto")
	t.ok(tubo2.range_chiesti[1].begins_with("Range: bytes="),
			"riprendendo si è chiesto un pezzo, non tutto da capo")


## Lo spazio si guarda PRIMA di chiedere qualunque cosa: scaricare due
## gigabyte e finire il disco a tre quarti è il modo più ostile di fallire.
##
## ⚠️ L'asserzione che conta non è «ha detto di no»: è **che non ha chiesto
## niente a nessuno**. L'ordine dei cancelli è la cosa provata qui.
##
## FALSIFICATO: mettendo il controllo dello spazio dopo il preflight (1
## rossa); guardando `libero < serve` senza il ramo «zero vuol dire non lo so»
## (1 — su una piattaforma che non sa rispondere la funzione si spegnerebbe
## per tutti).
func _lo_spazio_si_guarda_prima_di_chiedere(t) -> void:
	var d := _dati(1000, 23)
	var tubo := _tubo(d)
	_pulisci()
	# un file che non ci sta su nessun disco di questo mondo
	var enorme := 900_000_000_000_000
	var m = MACCHINA.new(tubo, "https://esempio/x.gguf", _dove(), enorme, _impronta(d))
	m.pausa_ms = 0
	_corri(m)
	t.eq(m.esito(), MACCHINA.ESITO_SPAZIO, "un file più grande del disco non si comincia nemmeno")
	t.eq(tubo.richieste.size(), 0, "e non si è chiesto NIENTE alla rete")
	t.ok(m.diagnosi().contains("MiB"), "la diagnosi dice quanto serviva e quanto c'era")


## Il preflight costa un decimo di secondo e risponde alla sola domanda che
## conta prima di venti minuti: a monte c'è ancora QUEL file?
##
## FALSIFICATO: togliendo il confronto con l'impronta (2 rosse); togliendo
## quello con la dimensione (1); trattando l'assenza dell'intestazione come un
## guasto (1 — e allora basterebbe che Hugging Face cambiasse un dettaglio per
## spegnere la funzione a tutti).
func _il_preflight_ferma_un_file_cambiato(t) -> void:
	var d := _dati(1000, 29)
	var tubo := _tubo(d)
	tubo.etag = "0000000000000000000000000000000000000000000000000000000000000000"
	var m = _macchina(tubo, d)
	_corri(m)
	t.eq(m.esito(), MACCHINA.ESITO_SORGENTE, "se a monte c'è un altro file, non si scarica")
	t.eq(tubo.richieste.size(), 1, "e si è speso solo il preflight, non il file")

	# e senza l'intestazione (Hugging Face potrebbe smettere di mandarla) si
	# scarica lo stesso: l'autorità è l'impronta calcolata alla fine
	var tubo2 := _tubo(d)
	tubo2.etag = ""
	var m2 = _macchina(tubo2, d)
	_corri(m2)
	t.eq(m2.esito(), MACCHINA.ESITO_FATTO, "senza impronta a monte si va avanti e si verifica dopo")

	# E IL PESO È L'ALTRA META DEL PREFLIGHT: l'impronta giusta su un file di
	# un'altra lunghezza vuol dire che a monte hanno ricaricato qualcosa. Non
	# si scarica: si dice.
	var tubo3 := _tubo(d)
	tubo3.dimensione_detta = d.size() + 1
	var m3 = _macchina(tubo3, d)
	_corri(m3)
	t.eq(m3.esito(), MACCHINA.ESITO_SORGENTE, "un peso diverso ferma il viaggio prima di cominciarlo")
	t.eq(tubo3.richieste.size(), 1, "e anche qui si spende solo il preflight")


## Riprovare cinque volte una porta chiusa a chiave fa aspettare per niente, e
## fa credere che sia un problema di linea.
##
## FALSIFICATO: togliendo `_codice_fermo` (1 rossa: sei richieste invece di
## una, e l'esito diventa «la linea non ha retto» — la diagnosi sbagliata).
func _una_porta_chiusa_non_si_bussa_cinque_volte(t) -> void:
	var d := _dati(1000, 31)
	var tubo := _tubo(d)
	tubo.codice_forzato = 403
	var m = _macchina(tubo, d)
	_corri(m)
	t.eq(m.esito(), MACCHINA.ESITO_CHIUSO, "una porta chiusa si chiama col suo nome")
	t.eq(tubo.richieste.size(), 1, "e ci si bussa una volta sola")


## ⚠️ **IL REDIRECT SI SEGUE CON LO STESSO `Range`, E NON SI CONSERVA MAI.**
## MISURATO il 2026-08-13 sulla sorgente vera: l'indirizzo firmato della CDN
## di Hugging Face è legato al `Range` che si è chiesto all'ORIGINE — riusarlo
## con un altro intervallo risponde `403 Auth failed: invalid range`, e la
## firma scade. Perciò ogni tentativo riparte da casa.
##
## FALSIFICATO: non rimandando le stesse intestazioni dietro al rimbalzo (1
## rossa); tenendosi l'indirizzo della CDN fra un tentativo e l'altro (1).
func _il_rimbalzo_porta_lo_stesso_pezzo(t) -> void:
	var d := _dati(300000, 37)
	var tubo := _tubo(d)
	tubo.rimbalza_a = "https://cdn.esempio/firmato?Policy=aaa/bbb"
	var m = _macchina(tubo, d)
	_corri(m)
	t.eq(m.esito(), MACCHINA.ESITO_FATTO, "dietro un rimbalzo si arriva lo stesso")
	_uguale(t, d, "e i byte sono quelli")
	var dopo_il_rimbalzo := tubo.richieste[tubo.richieste.size() - 1]
	t.eq(dopo_il_rimbalzo, "https://cdn.esempio/firmato?Policy=aaa/bbb",
			"il rimbalzo si segue dove dice, firma intera")

	# ⚠️ E ADESSO LA PARTE CHE CONTA, che vuole una RIPRESA per esistere: il
	# pezzo chiesto all'origine deve arrivare **identico** alla CDN (o la
	# firma vale per un intervallo e noi ne chiediamo un altro: `403`), e ogni
	# tentativo deve ricominciare da CASA (l'indirizzo firmato scade, e vale
	# solo per quel pezzo).
	var cdn := "https://cdn.esempio/firmato?Policy=aaa/bbb"
	var tubo2 := _tubo(d)
	tubo2.rimbalza_a = cdn
	tubo2.cade_a = 100000
	var m2 = _macchina(tubo2, d)
	m2.indietro = 4096
	_corri(m2)
	t.eq(m2.esito(), MACCHINA.ESITO_FATTO, "cadendo dietro un rimbalzo si arriva lo stesso")
	_uguale(t, d, "e il file è quello")

	var casa := SCARICO.url()
	var pezzi_a_casa := 0
	var pezzi_alla_cdn := 0
	var ultimo_pezzo_di_casa := ""
	for i in tubo2.richieste.size():
		var r: String = tubo2.range_chiesti[i]
		if r == "":
			continue
		if tubo2.richieste[i] == casa:
			pezzi_a_casa += 1
			ultimo_pezzo_di_casa = r
		elif tubo2.richieste[i] == cdn:
			pezzi_alla_cdn += 1
			t.eq(r, ultimo_pezzo_di_casa,
					"dietro il rimbalzo si chiede lo STESSO pezzo chiesto a casa")
	t.ok(pezzi_a_casa >= 1,
			"ogni ripresa riparte dall'origine (%d volte), mai dall'indirizzo firmato" % pezzi_a_casa)
	t.ok(pezzi_alla_cdn >= 1, "e il pezzo arriva davvero dalla CDN (%d volte)" % pezzi_alla_cdn)


## ⚠️ **IL GIRO INFINITO CHE C'ERA DAVVERO.** La prima stesura contava un
## tentativo come «buono» se aveva portato byte da quando era cominciato: con
## la rincorsa all'indietro, una linea che cade prima di `INDIETRO` byte fa
## crescere e ricalare il file per sempre, con la CPU a mille e zero errori.
## MISURATO: il processo di prova è rimasto al 100% finché non l'ho ucciso.
## Adesso il metro è il punto più lontano a cui si sia MAI arrivati.
##
## FALSIFICATO: rimettendo il metro vecchio (questo caso non finisce più — ed
## è per questo che c'è un tetto di passi, o la suite si pianterebbe invece di
## diventare rossa).
func _una_linea_che_non_porta_niente_si_arrende(t) -> void:
	var d := _dati(300000, 41)
	var tubo := _tubo(d)
	tubo.cade_a = 0  # la connessione si apre e non porta niente
	var m = _macchina(tubo, d)
	var giri := _corri(m, 200000)
	t.eq(m.esito(), MACCHINA.ESITO_RETE, "una linea che non porta niente si arrende")
	t.ok(tubo.richieste.size() <= MACCHINA.TENTATIVI + 3,
			"e ci prova un numero FINITO di volte (%d)" % tubo.richieste.size())
	t.ok(giri < 200000, "senza girare a vuoto per sempre")

	# la controprova: la stessa linea, che porta qualcosa a ogni giro, arriva
	var tubo2 := _tubo(d)
	tubo2.cade_a = 50000
	var m2 = _macchina(tubo2, d)
	m2.indietro = 4096
	_corri(m2)
	t.eq(m2.esito(), MACCHINA.ESITO_FATTO, "mentre una che ne porta un po' per volta arriva in fondo")

	# ⚠️ **E IL CASO CHE FACEVA IL GIRO INFINITO**, che non è nessuno dei due:
	# una linea che porta qualcosa, ma MENO della rincorsa all'indietro. Il
	# file cresce di mille byte e ne ritorna indietro quattromila, cioè non
	# cresce mai — eppure «ha portato dei byte». Col metro sbagliato si
	# riprova per sempre; col punto più lontano di sempre ci si arrende, che è
	# l'unica cosa onesta da fare con una linea così.
	var tubo3 := _tubo(d)
	tubo3.cade_a = 1000
	var m3 = _macchina(tubo3, d)
	m3.indietro = 4096
	var giri3 := _corri(m3, 200000)
	t.eq(m3.esito(), MACCHINA.ESITO_RETE,
			"chi porta meno della rincorsa non sta avanzando, e ci si ferma")
	t.ok(giri3 < 200000, "senza girare a vuoto per sempre (%d passi)" % giri3)


# =========================================================================
# 3. IL NODO — il thread vero, il lucchetto vero
# =========================================================================

## Fin qui la macchina ha camminato a mano. Qui cammina come in partita: sul
## `Thread` di `Scarico`, con il lucchetto, i segnali e l'uscita.
##
## FALSIFICATO: togliendo `wait_to_finish` da `_process` (il thread resta
## appeso e la suite stampa un errore di Godot alla chiusura); non emettendo
## `finito` (1 rossa); leggendo `_fatti` senza lucchetto (non falsificabile
## da qui, ed è dichiarato: un dato di corsa non si riproduce a comando).
func _il_thread_vero_fa_il_giro(t) -> void:
	var d := _dati(300000, 43)
	_pulisci()
	var s = SCARICO.new()
	t.stage(s)
	# il corriere vero scrive dove dice `Llm`; qui si prova il THREAD, non il
	# percorso, quindi il tubo ha in pancia i byte che vuole il banco
	var tubo := _tubo(d)
	s.usa_questa_rete(tubo)
	s.usa_questi_estremi(SCARICO.url(), _dove(), d.size(), _impronta(d))
	var visti := []
	s.finito.connect(func(esito, _diagnosi): visti.append(esito))
	s.comincia()
	var t0 := Time.get_ticks_msec()
	while s.esito() == MACCHINA.ESITO_NIENTE and Time.get_ticks_msec() - t0 < 15000:
		OS.delay_msec(2)
	t.eq(s.esito(), MACCHINA.ESITO_FATTO, "sul thread vero il viaggio arriva in fondo")
	_uguale(t, d, "e i byte sono quelli")
	s._process(0.0)
	t.eq(visti.size(), 1, "il segnale `finito` esce una volta sola, sul fotogramma")
	t.eq(int(visti[0]), MACCHINA.ESITO_FATTO, "e porta l'esito vero")
	t.ok(s.al_secondo() >= 0.0, "la velocità si può chiedere senza esplodere")

	# ANNULLARE: il thread molla, e in fretta. Il tubo qui ha un RITARDO
	# apposta: un tubo istantaneo finirebbe il viaggio prima che il banco
	# faccia in tempo a dire «fermati», e questo caso sarebbe verde senza aver
	# provato niente.
	_pulisci()
	var lento := _dati(1_000_000, 47)
	var s2 = SCARICO.new()
	t.stage(s2)
	var tubo2 := _tubo(lento)
	tubo2.a_pezzi = 4096
	tubo2.ritardo_us = 2000
	s2.usa_questa_rete(tubo2)
	s2.usa_questi_estremi(SCARICO.url(), _dove(), lento.size(), _impronta(lento))
	s2.comincia()
	OS.delay_msec(30)
	var t1 := Time.get_ticks_usec()
	s2.annulla()
	while s2.esito() == MACCHINA.ESITO_NIENTE and Time.get_ticks_usec() - t1 < 5_000_000:
		OS.delay_msec(1)
	var quanto := (Time.get_ticks_usec() - t1) / 1000.0
	t.eq(s2.esito(), MACCHINA.ESITO_ANNULLATO, "annullare arriva al thread")
	t.ok(quanto < 500.0, "e ci mette pochissimo (%.1f ms)" % quanto)
	t.ok(not FileAccess.file_exists(_dove()), "senza lasciare niente col nome del modello")

	# ⚠️ **E DOPO SI DEVE POTER RIPRENDERE.** Il thread di prima va ASPETTATO
	# prima di accenderne un altro: `comincia()` su un corriere che ha ancora
	# il suo thread per le mani non fa niente — e chi gioca preme «riprendi»,
	# non succede NULLA, e non c'è nessun errore da nessuna parte. È la
	# ragione per cui `_process` chiude il thread appena l'esito è arrivato.
	var pezzo := _peso(_dove() + ".parte")
	t.ok(pezzo > 0, "l'annullamento ha lasciato un pezzo (%d byte)" % pezzo)
	s2._process(0.0)
	tubo2.ritardo_us = 0
	s2.comincia()
	var t2 := Time.get_ticks_msec()
	while s2.esito() != MACCHINA.ESITO_FATTO and Time.get_ticks_msec() - t2 < 15000:
		OS.delay_msec(2)
	t.eq(s2.esito(), MACCHINA.ESITO_FATTO, "e premendo «riprendi» il viaggio riparte davvero")
	_uguale(t, lento, "e finisce col file giusto")
	_pulisci()


# =========================================================================
# 4. LE PAROLE, E LA RETE CHE NON C'È
# =========================================================================

## Ogni modo di finire ha la sua frase, e nessuna nomina una macchina: chi
## gioca non deve leggere una diagnosi.
##
## FALSIFICATO: togliendo un ramo dal `match` di `frase()` (1 rossa per ramo);
## scrivendo il numero col punto in italiano (1).
func _le_parole_ci_sono_tutte(t) -> void:
	for esito in [MACCHINA.ESITO_FATTO, MACCHINA.ESITO_ANNULLATO, MACCHINA.ESITO_SPAZIO,
			MACCHINA.ESITO_RETE, MACCHINA.ESITO_IMPRONTA, MACCHINA.ESITO_SORGENTE,
			MACCHINA.ESITO_CHIUSO, MACCHINA.ESITO_DISCO]:
		var f: String = SCARICO.frase(esito)
		t.ok(f != "", "l'esito %d ha una frase" % esito)
		var b := f.to_lower()
		for parola in ["gguf", "llama", "sha", "thread", "http", "byte"]:
			t.ok(not b.contains(parola),
					"e non nomina «%s»: è una frase per chi gioca, non una diagnosi" % parola)

	var prima := L10n.lingua_corrente()
	L10n.imposta("it")
	t.eq(SCARICO.misura_umana(2_489_757_856), "2,3 GB", "in italiano la virgola è una virgola")
	L10n.imposta("en")
	t.eq(SCARICO.misura_umana(2_489_757_856), "2.3 GB", "in inglese è un punto")
	L10n.imposta(prima)


## ⚠️ **LA REGOLA DELLA FASE 5: nessuna chiamata a un servizio esterno.**
## L'inferenza è tutta locale, e questo scarico è l'UNICO gesto di rete di
## tutto il gioco — voluto, chiesto da chi gioca, e fatto una volta sola. Qui
## si scandaglia il sorgente perché resti così: se qualcuno domani aggiunge un
## `HTTPRequest` da qualche parte, questo caso diventa rosso.
##
## Si saltano i commenti (questa lezione le classi vietate le nomina apposta),
## ed è la stessa forma della guardia di `test_vento.gd`.
##
## FALSIFICATO: mettendo un `HTTPRequest.new()` in un file di `scenes/` (1
## rossa, col nome del file).
func _niente_rete_da_nessun_altra_parte(t) -> void:
	var vietate := ["HTTPRequest", "HTTPClient", "StreamPeerTCP", "PacketPeerUDP",
			"WebSocketPeer", "TLSOptions", "ENetConnection", "MultiplayerPeer"]
	var permessi := ["res://systems/ScaricoRete.gd"]
	var colpevoli: Array[String] = []
	for cartella in ["res://scenes", "res://systems", "res://audio"]:
		for f in _tutti_i_gd(cartella):
			if permessi.has(f):
				continue
			var testo := FileAccess.get_file_as_string(f)
			for riga in testo.split("\n"):
				var pulita := riga.strip_edges()
				if pulita.begins_with("#") or pulita.begins_with("##"):
					continue
				for v in vietate:
					if pulita.contains(v):
						colpevoli.append("%s: %s" % [f, pulita])
	t.eq(colpevoli.size(), 0,
			"il gioco tocca la rete SOLO nel tubo del corriere (invece: %s)"
			% "\n".join(colpevoli))


## Il seam del banco (`usa_questa_rete`, `usa_questi_estremi`) esiste per i
## test e per i provini. Se un giorno lo chiamasse il gioco, il corriere
## andrebbe a prendere il modello da un posto deciso da qualcun altro.
##
## FALSIFICATO: chiamando `usa_questa_rete` da `OffertaModello` (1 rossa).
func _il_banco_non_lo_chiama_nessuno(t) -> void:
	var colpevoli: Array[String] = []
	for cartella in ["res://scenes", "res://systems", "res://audio"]:
		for f in _tutti_i_gd(cartella):
			if f == "res://systems/Scarico.gd":
				continue
			var testo := FileAccess.get_file_as_string(f)
			for riga in testo.split("\n"):
				var pulita := riga.strip_edges()
				if pulita.begins_with("#"):
					continue
				if pulita.contains("usa_questa_rete(") or pulita.contains("usa_questi_estremi("):
					colpevoli.append("%s: %s" % [f, pulita])
	t.eq(colpevoli.size(), 0, "nel gioco il banco non lo chiama nessuno (invece: %s)"
			% "\n".join(colpevoli))


# =========================================================================
# I FERRI
# =========================================================================

## Byte che non si comprimono e non si ripetono: un file di zeri passerebbe
## qualunque cucitura sbagliata senza lamentarsi.
func _dati(quanti: int, seme: int) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(quanti)
	var rng := RandomNumberGenerator.new()
	rng.seed = seme
	for i in quanti:
		b[i] = rng.randi() & 0xFF
	return b


func _impronta(b: PackedByteArray) -> String:
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update(b)
	return h.finish().hex_encode()


func _tubo(d: PackedByteArray) -> Tubo:
	var tubo := Tubo.new()
	tubo.byte = d
	tubo.etag = _impronta(d)
	return tubo


func _macchina(tubo, d: PackedByteArray):
	_pulisci()
	var m = MACCHINA.new(tubo, SCARICO.url(), _dove(), d.size(), _impronta(d))
	m.pausa_ms = 0
	return m


func _dove() -> String:
	return CASA.path_join("pensieri.gguf")


func _corri(m, tetto := 2000000) -> int:
	var giri := 0
	while giri < tetto:
		giri += 1
		if m.passo() == MACCHINA.PASSO_FINE:
			break
	return giri


func _pulisci() -> void:
	DirAccess.make_dir_recursive_absolute(CASA)
	for p in [_dove(), _dove() + ".parte"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func _peso(p: String) -> int:
	if not FileAccess.file_exists(p):
		return -1
	var f := FileAccess.open(p, FileAccess.READ)
	return -1 if f == null else f.get_length()


## I byte sul disco sono quelli della sorgente? Si confrontano lunghezza e
## impronta, non gli array: un `PackedByteArray` da trecentomila byte dentro il
## messaggio di un fallimento seppellisce tutto il resto della suite (misurato:
## 315 KB di numeri per una riga rossa).
func _uguale(t, atteso: PackedByteArray, messaggio: String) -> void:
	var vero := _byte(_dove())
	if vero.size() != atteso.size():
		t.ok(false, "%s (lunghezza %d invece di %d)" % [messaggio, vero.size(), atteso.size()])
		return
	t.eq(_impronta(vero), _impronta(atteso), messaggio)


func _byte(p: String) -> PackedByteArray:
	if not FileAccess.file_exists(p):
		return PackedByteArray()
	return FileAccess.get_file_as_bytes(p)


func _diario(m) -> String:
	return "\n".join(m.diario())


func _tutti_i_gd(cartella: String) -> Array[String]:
	var fuori: Array[String] = []
	var d := DirAccess.open(cartella)
	if d == null:
		return fuori
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		var p := cartella.path_join(n)
		if d.current_is_dir():
			if not n.begins_with("."):
				fuori.append_array(_tutti_i_gd(p))
		elif n.ends_with(".gd"):
			fuori.append(p)
		n = d.get_next()
	d.list_dir_end()
	return fuori
