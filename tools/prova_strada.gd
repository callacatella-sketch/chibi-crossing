extends SceneTree
## LA STRADA DEL GIOCATORE — quello che succede DAVVERO a chi accende la
## casella, e a chi non l'accende.
##
##   Godot --headless --fixed-fps 60 --path . --script res://tools/prova_strada.gd
##
## Gli altri banchi della Fase 5 provano un PEZZO per volta: il corriere coi
## suoi byte (`test_scarico`), la pagina coi suoi `Label`
## (`test_offerta_modello`), il portiere coi suoi quindici guasti
## (`test_llm_portiere`). Nessuno di loro cammina la strada intera **come la
## cammina una persona**: la casella, la pagina, il sì, la rete che cade, il
## file che arriva rotto, e il gioco che deve restare giocabile in mezzo a
## tutto questo.
##
## ⚠️ **E LA DOMANDA NON È «TORNA IL CODICE GIUSTO».** È: cosa vede chi sta
## davanti allo schermo, e quello che vede è VERO? Un `ESITO_RETE` è giusto
## per il codice e non vuol dire niente per nessuno; «la linea si è
## interrotta, quello che era arrivato è al sicuro» è la stessa cosa detta a
## una persona, e va verificato che sia vera — cioè che il pezzo ci sia
## davvero, e che riprendendo si riparta da lì.
##
## Le scene:
##   1. chi dice di NO                — il gioco è quello di prima?
##   2. la rete che CADE a metà       — che gli si dice, e il pezzo resta?
##   3. la rete LENTA                 — la stima è vera?
##   4. il DISCO che finisce          — si dice prima o dopo?
##   5. il file che arriva ROTTO      — l'impronta lo becca, e si butta?
##   6. la macchina che NON CE LA FA  — si evita il download per niente?
##
## Il tubo è quello di `test_scarico` (`Tubo`): un server finto con le
## manopole di un server vero — cade, rallenta, sbaglia byte. **Non è un
## doppio del corriere**: il corriere è quello di produzione, con le sue
## frasi, i suoi tentativi e i suoi conti. Quello che manca è solo il socket.

const SCARICO := preload("res://systems/Scarico.gd")
const MACCHINA := preload("res://systems/ScaricoMacchina.gd")
const OFFERTA := preload("res://scenes/ui/OffertaModello.gd")
const PANNELLO := preload("res://scenes/ui/CozySettingsPanel.gd")
const CAPIENZA := preload("res://systems/Capienza.gd")
const LLM := preload("res://systems/Llm.gd")
const CASI := preload("res://tests/cases/test_scarico.gd")

const GB := 1024 * 1024 * 1024
## Il file finto. ⚠️ **DEVE ESSERE PIÙ GRANDE DI `ScaricoMacchina.INDIETRO`**
## (la rincorsa di 1 MiB con cui si riprende), o il banco misura sé stesso:
## con un file da trecento kilobyte ogni ripresa rincorre fino a zero, nessun
## tentativo guadagna un byte, e quello che si osserva è la costante del
## corriere invece del suo comportamento. Cinque mebibyte lasciano a ogni
## tentativo un guadagno vero.
const QUANTI := 5 << 20
## Dove cade la linea, dentro una singola risposta. Più della rincorsa, o
## vale lo stesso discorso.
const CADE := 5 << 19

var _dove := ""
var _falliti := 0


func _init() -> void:
	_go()


# =========================================================================
# GLI ATTREZZI
# =========================================================================

func _riga(s: String) -> void:
	print(s)


func _titolo(n: int, s: String) -> void:
	print("")
	print("══════════════════════════════════════════════════════════════")
	print(" SCENA %d — %s" % [n, s])
	print("══════════════════════════════════════════════════════════════")


## Il metro di ogni scena: quello che si voleva, e quello che è successo.
func _pretendi(vero: bool, cosa: String) -> void:
	print("   %s  %s" % ["·" if vero else "✗ NO:", cosa])
	if not vero:
		_falliti += 1


func _byte_finti(n: int) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(n)
	for i in n:
		b[i] = (i * 37 + (i >> 8) * 11) & 0xFF
	return b


func _parziale() -> int:
	var p := _dove + ".parte"
	if not FileAccess.file_exists(p):
		return 0
	var f := FileAccess.open(p, FileAccess.READ)
	return 0 if f == null else f.get_length()


func _c_e_il_file() -> bool:
	return FileAccess.file_exists(_dove)


func _pulisci() -> void:
	for p in [_dove, _dove + ".parte"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


## Fa camminare il corriere VERO col tubo dato, fino alla fine o alla
## scadenza.
##
## ⚠️ **SI ASPETTA COL TEMPO VERO, NON A FOTOGRAMMI.** Fra un tentativo e
## l'altro il corriere riposa davvero (`pausa_ms` raddoppiata a ogni giro:
## 2+4+8+16 s per arrivare alla resa), ed è giusto — è quello che fa chi non
## vuole martellare un server che sta già male. Ma in headless con
## `--fixed-fps` i fotogrammi volano, quindi un tetto a fotogrammi scade
## mentre il corriere sta ancora aspettando il suo turno, e il banco
## dichiarerebbe «non ha fatto niente» di uno che stava facendo la cosa
## giusta.
func _scarica(tubo, secondi := 12.0, ferma_a := -1) -> Scarico:
	var s := SCARICO.new()
	s.name = SCARICO.NODO
	root.add_child(s)
	s.usa_questa_rete(tubo)
	s.usa_questi_estremi("https://finto/modello.gguf", _dove, tubo.byte.size(),
			_impronta(tubo.byte))
	s.comincia()
	var scade := Time.get_ticks_msec() + int(secondi * 1000.0)
	while s.esito() == MACCHINA.ESITO_NIENTE and Time.get_ticks_msec() < scade:
		if ferma_a >= 0 and s.fatti() >= ferma_a:
			s.annulla()
			ferma_a = -1
		await process_frame
	return s


func _impronta(b: PackedByteArray) -> String:
	var c := HashingContext.new()
	c.start(HashingContext.HASH_SHA256)
	c.update(b)
	return c.finish().hex_encode()


func _sul_disco() -> String:
	var f := FileAccess.open(_dove, FileAccess.READ)
	if f == null:
		return "<niente>"
	return _impronta(f.get_buffer(f.get_length()))


# =========================================================================
# LE SCENE
# =========================================================================

func _go() -> void:
	print("╔══════════════════════════════════════════════════════════════╗")
	print("║  LA STRADA DEL GIOCATORE — il modello che si scarica al primo ║")
	print("║  uso, provata dove la cammina una persona.                    ║")
	print("╚══════════════════════════════════════════════════════════════╝")
	print("  binario che sa scrivere : %s" % LLM.disponibile())
	print("  modello sul disco       : %s" % LLM.modello_in_casa())
	_dove = "user://prova_strada/pensieri.gguf"
	DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(_dove.get_base_dir()))
	await process_frame

	await _scena_no()
	await _scena_cade()
	await _scena_lenta()
	await _scena_disco()
	await _scena_rotto()
	await _scena_macchina()

	print("")
	print("══════════════════════════════════════════════════════════════")
	if _falliti == 0:
		print(" TUTTE LE SCENE HANNO FATTO QUELLO CHE DOVEVANO.")
	else:
		print(" ⚠️  %d PRETESE NON MANTENUTE — vedi le righe con ✗" % _falliti)
	print("══════════════════════════════════════════════════════════════")
	quit(1 if _falliti > 0 else 0)


## ─────────────────────────────────────────────────────────────────────────
## 1. CHI DICE DI NO
## ─────────────────────────────────────────────────────────────────────────
func _scena_no() -> void:
	_titolo(1, "il giocatore che dice di no")
	_pulisci()
	var s: Node = root.get_node_or_null("/root/Settings")
	var bit_prima: bool = bool(s.get("llm_spento"))

	var pan: Control = PANNELLO.new()
	root.add_child(pan)
	await process_frame
	await process_frame

	var casella: CheckButton = null
	for c in pan.find_children("*", "CheckButton", true, false):
		var p := c.get_parent()
		for f in p.get_children():
			if f is Label and (f as Label).text == "Il villaggio pensa":
				casella = c
	# ⚠️ SU UN BINARIO SENZA LLAMA LA RIGA NON DEVE ESISTERE, e non è un caso
	# minore: è il gioco che la CI normale compila, ed è il gioco di chiunque
	# finché il cuore non viaggia con llama dentro. Una riga «Il villaggio
	# pensa» mostrata lì offrirebbe due gigabyte e mezzo che quel binario non
	# saprebbe aprire — il modo più costoso di non fare niente.
	_pretendi((casella != null) == LLM.disponibile(),
			"la riga «Il villaggio pensa» c'è ESATTAMENTE se questo binario sa scrivere (qui: %s)"
			% LLM.disponibile())
	if casella == null:
		_riga("   → binario senza llama: non c'è niente da offrire, e infatti non si offre.")
		pan.queue_free()
		await process_frame
		return
	_pretendi(not casella.button_pressed,
			"la casella nasce SPENTA (il villaggio non pensa: sarebbe una bugia)")

	casella.button_pressed = true
	casella.toggled.emit(true)
	await process_frame
	await process_frame
	var off = pan.get("_offerta")
	_pretendi(off != null and is_instance_valid(off) and off.visible,
			"toccandola si apre la pagina che chiede — e SOPRAVVIVE al frame dopo")
	if off != null and is_instance_valid(off):
		_riga("   quello che c'è scritto in cima: «%s»" % str(off.get("_titolo").text))

	_pretendi(_parziale() == 0 and not FileAccess.file_exists(OFFERTA.RICEVUTA),
			"aprire la pagina non ha scritto NIENTE sul disco")

	# IL NO.
	if off != null and is_instance_valid(off):
		off.closed.emit()
	await process_frame
	await process_frame
	await process_frame
	var casella2: CheckButton = null
	for c in pan.find_children("*", "CheckButton", true, false):
		var p := c.get_parent()
		for f in p.get_children():
			if f is Label and (f as Label).text == "Il villaggio pensa":
				casella2 = c
	_pretendi(casella2 != null and not casella2.button_pressed,
			"detto «non adesso», la casella è tornata spenta da sola")
	_pretendi(bool(s.get("llm_spento")) == bit_prima,
			"e la preferenza di chi gioca non è stata toccata")
	_pretendi(not FileAccess.file_exists(OFFERTA.RICEVUTA),
			"nessuna ricevuta: il consenso si dà premendo, non guardando")
	_pretendi(root.get_node_or_null(SCARICO.NODO) == null,
			"e nessuno è andato a prendere niente")
	_riga("   → il gioco è quello di prima, e la casella non insiste.")
	pan.queue_free()
	await process_frame


## ─────────────────────────────────────────────────────────────────────────
## 2. LA RETE CHE CADE A META'
## ─────────────────────────────────────────────────────────────────────────
func _scena_cade() -> void:
	_titolo(2, "la rete che cade a metà (e poi torna)")
	_pulisci()
	var tutto := _byte_finti(QUANTI)

	# Il server chiude la connessione dopo 70000 byte, SEMPRE. Il corriere
	# riprova `TENTATIVI` volte e ogni volta ne porta a casa un altro pezzo.
	var tubo = CASI.Tubo.new()
	tubo.byte = tutto
	tubo.etag = _impronta(tutto)
	tubo.cade_a = CADE
	var s := await _scarica(tubo, 40.0)
	_riga("   esito: %s" % SCARICO.frase(s.esito()))
	_riga("   sul disco: %d byte di %d" % [_parziale(), QUANTI])
	_pretendi(s.esito() == MACCHINA.ESITO_FATTO or _parziale() > 70000,
			"cadendo e riprendendo, ogni tentativo porta a casa un altro pezzo")
	if s.esito() == MACCHINA.ESITO_FATTO:
		_pretendi(_sul_disco() == tubo.etag,
				"e il file rimesso insieme dai pezzi ha l'impronta GIUSTA")
	s.queue_free()
	await process_frame

	# Adesso la rete cade e NON torna: il corriere si arrende dopo i suoi
	# tentativi. La domanda è cosa resta e cosa gli si dice.
	_pulisci()
	var t2 = CASI.Tubo.new()
	t2.byte = tutto
	t2.etag = _impronta(tutto)
	t2.cade_a = 0            # non manda un byte: la linea è morta
	var s2 := await _scarica(t2, 90.0)
	_riga("   con la linea morta → esito «%s»" % SCARICO.frase(s2.esito()))
	_pretendi(s2.esito() == MACCHINA.ESITO_RETE,
			"si arrende dicendo che è la RETE, non un guasto del gioco")
	_pretendi(not _c_e_il_file(),
			"e NON lascia un file col nome buono: un mezzo modello non è un modello")
	var frase := SCARICO.frase(s2.esito())
	_pretendi(frase.length() > 20 and not frase.contains("ESITO"),
			"quello che legge chi gioca è una frase, non un codice: «%s»" % frase)
	s2.queue_free()
	await process_frame

	# E LA RIPRESA VERA: la linea torna, e si riparte da dove si era.
	_pulisci()
	var t3 = CASI.Tubo.new()
	t3.byte = tutto
	t3.etag = _impronta(tutto)
	var s3 := await _scarica(t3, 30.0, 2 << 20)   # chi gioca ferma a 2 MiB
	_riga("   fermato da chi gioca a %d byte → «%s»" % [_parziale(), SCARICO.frase(s3.esito())])
	var pezzo := _parziale()
	_pretendi(s3.esito() == MACCHINA.ESITO_ANNULLATO and pezzo > 0,
			"fermandolo, quello che era arrivato RESTA (%d byte)" % pezzo)
	_pretendi(not _c_e_il_file(),
			"e resta col nome sbagliato: chi cerca il modello non lo trova")
	s3.queue_free()
	await process_frame

	var t4 = CASI.Tubo.new()
	t4.byte = tutto
	t4.etag = _impronta(tutto)
	var s4 := await _scarica(t4, 40.0)
	_riga("   ripreso: chiesto «%s»" % str(t4.range_chiesti))
	var ha_chiesto_da_li := false
	for r in t4.range_chiesti:
		if r.contains("bytes=") and not r.contains("bytes=0-"):
			ha_chiesto_da_li = true
	_pretendi(ha_chiesto_da_li,
			"riprendendo si chiede il pezzo che manca, non tutto da capo")
	_pretendi(s4.esito() == MACCHINA.ESITO_FATTO and _sul_disco() == t4.etag,
			"e il file finito è giusto")
	s4.queue_free()
	await process_frame


## ─────────────────────────────────────────────────────────────────────────
## 3. LA RETE LENTA
## ─────────────────────────────────────────────────────────────────────────
func _scena_lenta() -> void:
	_titolo(3, "la rete lenta — la stima dice il vero?")
	_pulisci()
	var tutto := _byte_finti(QUANTI)
	var tubo = CASI.Tubo.new()
	tubo.byte = tutto
	tubo.etag = _impronta(tutto)
	tubo.a_pezzi = 2048
	tubo.ritardo_us = 900        # una linea lenta vera

	var s := SCARICO.new()
	s.name = SCARICO.NODO
	root.add_child(s)
	s.usa_questa_rete(tubo)
	s.usa_questi_estremi("https://finto/modello.gguf", _dove, QUANTI, _impronta(tutto))
	s.comincia()

	var t0 := Time.get_ticks_msec()
	var detto := ""
	var scade := t0 + 60000
	while s.esito() == MACCHINA.ESITO_NIENTE and Time.get_ticks_msec() < scade:
		await process_frame
		if s.fatti() > QUANTI / 3 and detto == "":
			var q = CAPIENZA.quanto_manca(s.totali() - s.fatti(), s.al_secondo())
			detto = L10n.rendi(q)
			_riga("   a un terzo: «%s» · %s · %s"
					% [detto, SCARICO.misura_umana(s.fatti()), CAPIENZA.velocita(s.al_secondo())])
	var vero_ms := Time.get_ticks_msec() - t0
	_riga("   finito davvero in %.1f s (esito «%s»)" % [vero_ms / 1000.0, SCARICO.frase(s.esito())])
	_pretendi(s.esito() == MACCHINA.ESITO_FATTO,
			"una linea lenta è lenta, non rotta: il file arriva lo stesso")
	_pretendi(detto != "" and not detto.contains("%"),
			"e mentre arriva gli si dice quanto manca A PAROLE, non in percentuale al secondo")
	_pretendi(s.al_secondo() > 0.0, "la velocità misurata è un numero vero")
	s.queue_free()
	await process_frame


## ─────────────────────────────────────────────────────────────────────────
## 4. IL DISCO CHE FINISCE
## ─────────────────────────────────────────────────────────────────────────
func _scena_disco() -> void:
	_titolo(4, "il disco che finisce")
	_pulisci()
	# Non si riempie il disco vero: si chiede al corriere di scaricare una
	# cosa più grande di quanto ce ne stia. La domanda è QUANDO lo dice.
	var tutto := _byte_finti(QUANTI)
	var tubo = CASI.Tubo.new()
	tubo.byte = tutto
	tubo.etag = _impronta(tutto)

	var dd := DirAccess.open(_dove.get_base_dir())
	var libero: int = dd.get_space_left() if dd != null else 0
	_riga("   spazio libero vero: %s" % SCARICO.misura_umana(libero))

	var s := SCARICO.new()
	s.name = SCARICO.NODO
	root.add_child(s)
	s.usa_questa_rete(tubo)
	# gli si dice che il file pesa più di tutto il disco
	s.usa_questi_estremi("https://finto/modello.gguf", _dove,
			libero + 64 * GB, _impronta(tutto))
	s.comincia()
	var scade4 := Time.get_ticks_msec() + 20000
	while s.esito() == MACCHINA.ESITO_NIENTE and Time.get_ticks_msec() < scade4:
		await process_frame
	_riga("   esito: «%s»" % SCARICO.frase(s.esito()))
	_riga("   byte scaricati prima di dirlo: %d" % s.fatti())
	_pretendi(s.esito() == MACCHINA.ESITO_SPAZIO,
			"si accorge che non ci sta")
	_pretendi(s.fatti() == 0,
			"e lo dice PRIMA di scaricare un solo byte (non dopo mezz'ora)")
	var f := SCARICO.frase(s.esito())
	_pretendi(f.length() > 20, "con una frase vera: «%s»" % f)
	s.queue_free()
	await process_frame


## ─────────────────────────────────────────────────────────────────────────
## 5. IL FILE CHE ARRIVA ROTTO
## ─────────────────────────────────────────────────────────────────────────
func _scena_rotto() -> void:
	_titolo(5, "il file che arriva rotto — un bit solo")
	_pulisci()
	var tutto := _byte_finti(QUANTI)
	var giusta := _impronta(tutto)

	var tubo = CASI.Tubo.new()
	tubo.byte = tutto
	tubo.etag = giusta
	tubo.sporca_da = QUANTI - 40000   # da lì in poi, byte diversi

	var s := SCARICO.new()
	s.name = SCARICO.NODO
	root.add_child(s)
	s.usa_questa_rete(tubo)
	s.usa_questi_estremi("https://finto/modello.gguf", _dove, QUANTI, giusta)
	s.comincia()
	var scade5 := Time.get_ticks_msec() + 60000
	while s.esito() == MACCHINA.ESITO_NIENTE and Time.get_ticks_msec() < scade5:
		await process_frame

	_riga("   impronta attesa : %s" % giusta.substr(0, 24))
	_riga("   esito           : «%s»" % SCARICO.frase(s.esito()))
	_pretendi(s.esito() == MACCHINA.ESITO_IMPRONTA,
			"l'impronta becca un file rovinato che pesa il giusto")
	_pretendi(not _c_e_il_file(),
			"il file rotto NON prende il nome buono")
	_pretendi(_parziale() == 0,
			"e viene BUTTATO: non resta lì a spegnere la funzione per sempre")
	s.queue_free()
	await process_frame

	# SI PUO' RIPROVARE, ed è la metà che conta: buttare senza poter
	# riprovare vuol dire una funzione persa per sempre.
	var t2 = CASI.Tubo.new()
	t2.byte = tutto
	t2.etag = giusta
	var s2 := await _scarica(t2, 40.0)
	_riga("   riprovando      : «%s»" % SCARICO.frase(s2.esito()))
	_pretendi(s2.esito() == MACCHINA.ESITO_FATTO,
			"e riprovando, il file arriva e stavolta è quello giusto")
	_pretendi(_sul_disco() == giusta, "impronta verificata sul file posato")
	_pretendi(t2.range_chiesti.size() > 0 and not str(t2.range_chiesti[0]).contains("bytes="),
			"e si riparte da ZERO: di un file buttato non si riprende niente")
	s2.queue_free()
	_pulisci()
	await process_frame


## ─────────────────────────────────────────────────────────────────────────
## 6. LA MACCHINA CHE NON CE LA FA
## ─────────────────────────────────────────────────────────────────────────
func _scena_macchina() -> void:
	_titolo(6, "la macchina che non ce la fa")
	# I numeri VERI di questo computer, dal ponte del cuore C++.
	var tot := 0
	var lib := 0
	var ris := 0
	var tet := 0
	if LLM.disponibile():
		var L = LLM.apri()
		var m = L.memoria()
		var lim = L.limiti()
		tot = int(m.get("totale_sistema", 0))
		lib = int(m.get("libera_sistema", 0))
		ris = int(lim.get("riserva_byte", 0))
		tet = int(lim.get("tetto_byte", 0))
		_riga("   (tetto e riserva letti dal ponte del cuore C++)")
	else:
		# Senza llama il ponte non c'è, e i quattro computer qui sotto vanno
		# giudicati lo stesso: `Capienza` è pura, e le sue risposte non
		# dipendono da chi le ha misurate. I due numeri sono quelli del
		# portiere, dichiarati in CLAUDE.md.
		ris = 1024 * 1024 * 1024
		tet = 3072 * 1024 * 1024
		_riga("   (binario senza llama: tetto e riserva presi dai valori dichiarati)")
	var serve: int = LLM.RAM_MODELLO
	_riga("   questo computer: %s in tutto, %s liberi adesso"
			% [SCARICO.misura_umana(tot), SCARICO.misura_umana(lib)])
	_riga("   il modello chiede %s, e al gioco ne devono restare %s"
			% [SCARICO.misura_umana(serve), SCARICO.misura_umana(ris)])
	_riga("   verdetto adesso: «%s»" % CAPIENZA.della_memoria(tot, lib, serve, ris, tet))

	# I TRE COMPUTER, e il terzo è quello dell'autore nel momento in cui il
	# 4B non si apriva (2583 MB liberi contro 2640 richiesti).
	var casi := [
		["un computer grande e libero", 16 * GB, 12 * GB, "ci_sta", true],
		["un computer piccolo (3 GB): non ce la farà mai", 3 * GB, 3 * GB, "mai", false],
		["uno da 4 GB, pieno a metà", 4 * GB, 2 * GB, "adesso_no", false],
		["quello dell'autore, quel giorno", 8 * GB, 2583 * 1024 * 1024, "adesso_no", false],
		["una piattaforma che non sa dirlo", 0, 0, "non_lo_so", true],
	]
	for c in casi:
		var v: String = CAPIENZA.della_memoria(int(c[1]), int(c[2]), serve, ris, tet)
		var offre: bool = CAPIENZA.si_puo_offrire(v)
		_pretendi(v == c[3] and offre == c[4],
				"%s → «%s», si offre il download: %s" % [c[0], v, offre])

	# E LA PAGINA VERA: con i numeri dell'autore, cosa si vede?
	var p = OFFERTA.new()
	p.forza_macchina = {"totale": 8 * GB, "libera": 2583 * 1024 * 1024,
			"riserva": ris, "tetto": tet}
	root.add_child(p)
	await process_frame
	var scritte := _tutte(p)
	var nomina_scarico := false
	for x in scritte:
		if x == "Scaricalo":
			nomina_scarico = true
	_riga("   la pagina dice: «%s»" % str(scritte.slice(0, 3)))
	var bottoni := ["Scaricalo", "Non adesso", "Va bene così", "Riprova"]
	_riga("   i bottoni: %s" % str(scritte.filter(func(x): return bottoni.has(x))))
	_pretendi(not nomina_scarico,
			"col computer dell'autore quel giorno, IL DOWNLOAD NON VIENE NEMMENO NOMINATO")
	var parla_di_memoria := false
	for x in scritte:
		if x.contains("memoria da prestargli"):
			parla_di_memoria = true
	_pretendi(parla_di_memoria, "e gli si dice perché, senza fargli fare un conto")
	p.queue_free()
	await process_frame


func _tutte(n: Node, fuori: Array = []) -> Array:
	if n is Label and (n as Label).text != "":
		fuori.append((n as Label).text)
	elif n is Button and (n as Button).text != "":
		fuori.append((n as Button).text)
	for c in n.get_children():
		_tutte(c, fuori)
	return fuori
