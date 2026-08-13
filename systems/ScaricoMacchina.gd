class_name ScaricoMacchina
extends RefCounted

## Il contrassegno di provenienza lo scrive qui, ma la sua forma la conosce
## `Llm`: e' li' che vive la domanda «che impronta deve avere questo file».
const LLM := preload("res://systems/Llm.gd")

## IL VIAGGIO — due gigabyte e mezzo presi bene, o non presi affatto.
##
## Questa è la macchina che scarica il modello: **tutte** le decisioni stanno
## qui dentro, e non c'è un thread, non c'è un `HTTPClient`, non c'è un nodo.
## Si muove a passi (`passo()`), e chi la fa camminare è
## [`systems/Scarico.gd`](Scarico.gd) — dal suo thread, un passo dopo l'altro,
## finché non arriva in fondo o si arrende.
##
## ⚠️ **PERCHÉ NON `HTTPRequest`, che ce l'avremmo già.** Perché non sa
## RIPRENDERE, e non è un'opinione: `download_file` apre il file in
## scrittura, cioè lo **tronca**. MISURATO il 2026-08-13 (`--headless`, 4.7.1):
## un file di 1 MiB pieno di `0xAA`, una richiesta con `Range:
## bytes=1048576-2097151` e `download_file` su quel file → dopo, il file è
## 1 MiB e comincia con `00000000`. I byte di prima non ci sono più. Con una
## linea domestica che cade a metà, «riprendere» diventa «ricominciare», e una
## funzione che chiede quaranta minuti e ne butta venti a ogni singhiozzo non
## la accende nessuno. `HTTPClient` invece lascia in mano il corpo un pezzo
## per volta, e il file lo apriamo noi dove vogliamo: è tutta la differenza.
##
## ────────────────────────────────────────────────────────────────────────
## LE SETTE REGOLE, e ognuna chiude un guasto vero
## ────────────────────────────────────────────────────────────────────────
##
## 1. **IL FILE BUONO NASCE ALL'ULTIMO ISTANTE.** Finché non è arrivato tutto
##    e l'impronta non combacia, quello che c'è sul disco si chiama
##    `pensieri.gguf.parte` — un nome che `Llm.percorso_modello()` non guarda
##    nemmeno. Il nome vero glielo dà una `rename` alla fine, che è atomica.
##    Un download interrotto perciò non «sembra valido» mai: non è una
##    convenzione, è una proprietà del nome.
## 2. **L'IMPRONTA NON È FACOLTATIVA.** Il modello si scarica da una rete che
##    non controlliamo, e un bit girato dentro i pesi non lo vede né il
##    portiere né llama (`src/llm_gguf.h`): la sola difesa è lo SHA-256, e
##    l'unico modo di renderlo utile è **buttare** quel che non combacia. Un
##    file rovinato lasciato lì spegne la funzione per sempre, e chi gioca non
##    ha modo di collegare le due cose. Senza impronta attesa la macchina non
##    parte affatto (`ESITO_SENZA_IMPRONTA`).
## 3. **LO SPAZIO SI GUARDA PRIMA.** Scaricare due gigabyte e finire il disco
##    a tre quarti è il modo più ostile di fallire: si perde il tempo di tutti
##    e si lascia il disco pieno. `DirAccess.get_space_left()` risponde su
##    tutte e tre le piattaforme (verificato: 4.7.1 lo espone davvero), e il
##    conto si fa sul BISOGNO VERO — quel che manca, non l'intero file, perché
##    la ripresa non riscarica quel che c'è già.
## 4. **LA VERIFICA NON COSTA UN BYTE DI DISCO.** Si legge il file dov'è e si
##    rinomina: nessuna copia, nessun doppione. Il gesto ingenuo («scarico nel
##    temporaneo, poi copio») chiederebbe cinque gigabyte invece di due e
##    mezzo, e il secondo lo chiederebbe proprio alla fine, dopo aver già
##    fatto aspettare.
## 5. **SI RIPRENDE INDIETRO DI UN PEZZO** (`INDIETRO`, 1 MiB). Se il gioco
##    muore mentre scrive, la coda del file può essere monca senza che la
##    lunghezza lo dica. Un mebibyte riscaricato costa un decimo di secondo e
##    chiude il buco; senza, la sola difesa sarebbe l'impronta, cioè buttare
##    due gigabyte e mezzo per una coda storta.
## 6. **IL DEGRADO VA SEMPRE VERSO «RICOMINCIARE», MAI VERSO «SCRIVERE STORTO».**
##    Se il server ignora il `Range` e risponde 200, non si appende: si
##    tronca e si riparte da zero. Se il `Content-Range` non comincia dove
##    abbiamo chiesto, idem. Un file cucito male passerebbe tutti i controlli
##    tranne l'ultimo, e l'ultimo costa una lettura di due gigabyte e mezzo.
## 7. **UN TENTATIVO CHE NON PORTA BYTE NON CONTA COME PROGRESSO.** I
##    tentativi si contano solo quando la linea non ha dato niente: così una
##    connessione che cade ogni due minuti arriva in fondo lo stesso (ogni
##    caduta ha portato dei byte), e una che non si apre proprio si arrende
##    dopo `TENTATIVI` invece di rimbalzare per sempre.
##
## ────────────────────────────────────────────────────────────────────────
## LA RETE È UN SEAM, E IL DOPPIO NON REIMPLEMENTA NIENTE
## ────────────────────────────────────────────────────────────────────────
##
## `_rete` è un oggetto con sei metodi (`chiedi`, `avanza`, `codice`, `testa`,
## `pezzo`, `chiudi`) e **nessuna decisione**: è un tubo. Quello vero è
## [`ScaricoRete`](ScaricoRete.gd) e parla `HTTPClient`; quello dei test è un
## tubo finto che restituisce i byte che gli si mettono in bocca, e sa fare le
## tre cose che una rete vera fa e un test non saprebbe aspettare: cadere a
## metà, ignorare il `Range`, mandare byte diversi da quelli promessi.
##
## Il doppio quindi **non ri-scrive la macchina**: la macchina è questa, ed è
## la stessa che gira in partita. È la lezione di `test_llm_banco.gd` — «un
## doppio che mente è peggio di nessun doppio: nessun doppio ti fa scrivere un
## test vero, uno che mente ti fa credere di averlo già scritto».

## Gli stati del viaggio. Il nome è quello che sta facendo ADESSO.
enum {
	FASE_SPAZIO,    ## il disco basta?
	FASE_TESTA,     ## il preflight: c'è ancora, ed è ancora quello?
	FASE_APRE,      ## la richiesta col Range, e i redirect
	FASE_CORPO,     ## i byte che arrivano
	FASE_IMPRONTA,  ## lo SHA-256 di quello che è sul disco
	FASE_POSA,      ## la rinomina: adesso il file si chiama col nome vero
	FASE_FINE,      ## finito, in bene o in male: `esito()` lo dice
}

## Cosa ha fatto un `passo()`. `ATTESA` vuol dire «adesso non c'è niente da
## fare»: chi mi fa camminare può dormire un millisecondo senza perdere niente.
enum { PASSO_AVANTI, PASSO_ATTESA, PASSO_FINE }

## Come è finita. Tutti gli esiti tranne `FATTO` lasciano il gioco **identico**
## a prima: nessuno di questi è un guasto del gioco, sono tutti «non stavolta».
enum {
	ESITO_NIENTE,          ## non è ancora finita
	ESITO_FATTO,           ## il modello è al suo posto, verificato
	ESITO_ANNULLATO,       ## l'ha fermato chi gioca (il parziale resta)
	ESITO_SPAZIO,          ## sul disco non ci sta
	ESITO_RETE,            ## la linea non ha retto, dopo N tentativi
	ESITO_IMPRONTA,        ## è arrivato rovinato: buttato
	ESITO_SORGENTE,        ## a monte non c'è più, o è cambiato
	ESITO_CHIUSO,          ## a monte adesso chiedono le credenziali
	ESITO_DISCO,           ## non si riesce a scrivere
	ESITO_SENZA_IMPRONTA,  ## nessuno sa che impronta debba avere: non si parte
}

## Quanti tentativi SENZA UN BYTE prima di arrendersi (vedi regola 7).
const TENTATIVI := 5

## Quanto si riscarica all'indietro quando si riprende (vedi regola 5).
const INDIETRO := 1 << 20

## Il cuscino di disco che si lascia comunque libero. Riempire il disco
## dell'ultimo mebibyte è un modo di rompere il computer di chi gioca, non di
## installare una funzione facoltativa.
const MARGINE := 256 << 20

## Quanti redirect si seguono. Hugging Face ne fa UNO (origine → CDN firmato);
## tre è un tetto che nessuna catena onesta raggiunge.
const SALTI := 4

## Quanto si legge per volta quando si calcola l'impronta. A 312 MB/s
## (MISURATO su questa macchina) sono ~3 ms a passo: un annullamento non
## aspetta mai più di così.
const BOCCONE := 1 << 20


var _rete                       ## il tubo (vero o finto): sei metodi, zero decisioni
var _url := ""                  ## l'ORIGINE, sempre. Mai il CDN: vedi `_url_ora`
var _url_ora := ""              ## dove sta puntando adesso (dopo i redirect)
var _destinazione := ""         ## `.../pensieri.gguf`
var _parte := ""                ## `.../pensieri.gguf.parte`
var _dimensione := 0            ## quanto deve pesare, al byte
var _impronta := ""             ## lo SHA-256 che deve avere

var _fase := FASE_SPAZIO
var _esito := ESITO_NIENTE
var _diagnosi := ""
var _annullato := false

var _da := 0                    ## da che byte stiamo chiedendo adesso
var _fatti := 0                 ## quanti byte ci sono sul disco, adesso
var _massimo_mai := 0           ## il punto più lontano a cui si sia MAI arrivati
var _tentativi := 0
var _salti := 0
var _chiesto := false           ## la richiesta di questa fase è già partita?

var _f: FileAccess = null       ## il file di lavoro, aperto
var _h: HashingContext = null   ## l'impronta in corso
var _letti := 0                 ## quanti byte ha già digerito l'impronta
var _fr: FileAccess = null      ## il file aperto in lettura per l'impronta

var _attesa_fino := 0           ## `Time.get_ticks_msec()` fino a cui si aspetta
var _diario: Array[String] = [] ## cosa è successo, per i banchi e per i test

## La pausa fra due tentativi, in millisecondi (raddoppia a ogni tentativo a
## vuoto). I test la mettono a zero: aspettare davvero renderebbe la suite
## lenta senza provare niente di più.
var pausa_ms := 1000

## Di quanto si torna indietro riprendendo. È `INDIETRO` e basta, in partita;
## sta in una variabile perché un banco che prova la ripresa su un file di
## trecentomila byte, con un mebibyte di rincorsa, non riprenderebbe MAI —
## proverebbe soltanto il ramo «ricomincio da capo», e crederebbe di aver
## provato la ripresa.
var indietro := INDIETRO


## Si costruisce con tutto quello che le serve, e **niente di implicito**: i
## percorsi arrivano da fuori così un banco può lavorare in una cartella sua
## senza sfiorare il modello vero di chi sta giocando su questa macchina.
func _init(rete, url: String, destinazione: String, dimensione: int, impronta: String) -> void:
	_rete = rete
	_url = url
	_url_ora = url
	_destinazione = destinazione
	_parte = destinazione + ".parte"
	_dimensione = dimensione
	_impronta = impronta.to_lower()


# =========================================================================
# QUELLO CHE SI CHIEDE DA FUORI
# =========================================================================

func fase() -> int:
	return _fase


func esito() -> int:
	return _esito


## La riga per i log — MAI per chi gioca. Le frasi di chi gioca stanno in
## `Scarico.frase()`, e sono un'altra cosa: qui c'è il perché tecnico.
func diagnosi() -> String:
	return _diagnosi


func fatti() -> int:
	return _fatti


func totali() -> int:
	return _dimensione


## Quanto è avanzata l'impronta (0.0–1.0). Serve perché la verifica di due
## gigabyte e mezzo dura una manciata di secondi, e una barra ferma è una
## barra rotta.
func impronta_avanti() -> float:
	if _dimensione <= 0:
		return 0.0
	return clampf(float(_letti) / float(_dimensione), 0.0, 1.0)


func diario() -> Array[String]:
	return _diario.duplicate()


## Fermati. Si può chiamare in qualunque momento e da chiunque abbia in mano
## la macchina — nel gioco è il thread stesso a chiamarla, sul fronte della
## richiesta di chi gioca.
func annulla() -> void:
	_annullato = true


# =========================================================================
# IL PASSO
# =========================================================================

## Un'unità di lavoro. Torna `PASSO_FINE` quando non c'è più niente da fare.
##
## ⚠️ Nessun passo può bloccare: il più lungo è un mebibyte di SHA-256 (3 ms
## misurati). È la proprietà che rende l'annullamento vero — «annullato» non
## deve voler dire «fra un minuto».
func passo() -> int:
	if _fase == FASE_FINE:
		return PASSO_FINE
	if _annullato:
		_chiudi_tutto()
		_finisci(ESITO_ANNULLATO, "fermato da chi gioca")
		return PASSO_FINE
	if _attesa_fino > 0:
		if Time.get_ticks_msec() < _attesa_fino:
			return PASSO_ATTESA
		_attesa_fino = 0
	match _fase:
		FASE_SPAZIO:
			return _passo_spazio()
		FASE_TESTA:
			return _passo_testa()
		FASE_APRE:
			return _passo_apre()
		FASE_CORPO:
			return _passo_corpo()
		FASE_IMPRONTA:
			return _passo_impronta()
		FASE_POSA:
			return _passo_posa()
	return PASSO_FINE


# ------------------------------------------------------------ 1. lo spazio
func _passo_spazio() -> int:
	if _impronta.length() != 64:
		# REGOLA 2. Non si scarica un file di cui non sappiamo riconoscere i
		# byte: sarebbe due gigabyte e mezzo presi sulla fiducia.
		_finisci(ESITO_SENZA_IMPRONTA, "nessuna impronta attesa: non si scarica alla cieca")
		return PASSO_FINE

	var cartella := _destinazione.get_base_dir()
	if not DirAccess.dir_exists_absolute(cartella):
		var err := DirAccess.make_dir_recursive_absolute(cartella)
		if err != OK:
			_finisci(ESITO_DISCO, "non riesco a creare %s (errore %d)" % [cartella, err])
			return PASSO_FINE

	# C'È GIÀ? Allora non c'è niente da fare, e dirlo è meglio che rifarlo.
	if FileAccess.file_exists(_destinazione):
		_nota("c'era già")
		_finisci(ESITO_FATTO, "il modello c'era già")
		return PASSO_FINE

	# Quel che è rimasto da un viaggio di ieri.
	var gia := _quanto_pesa(_parte)
	if gia > _dimensione:
		# Non è nostro (o è di un modello diverso): non si riprende un file
		# più lungo di quello che aspettiamo, si ricomincia.
		_nota("il parziale era più lungo del dovuto: buttato")
		DirAccess.remove_absolute(_parte)
		gia = 0

	var d := DirAccess.open(cartella)
	if d == null:
		_finisci(ESITO_DISCO, "non riesco ad aprire %s" % cartella)
		return PASSO_FINE
	var libero := d.get_space_left()
	var serve := serve_spazio(_dimensione, gia, MARGINE)
	if not spazio_basta(libero, serve):
		_finisci(ESITO_SPAZIO, "servono %d MiB liberi, ce ne sono %d"
				% [serve >> 20, libero >> 20])
		return PASSO_FINE
	_nota("spazio: servono %d MiB, liberi %d" % [serve >> 20, libero >> 20])
	_fase = FASE_TESTA
	return PASSO_AVANTI


# ------------------------------------------------------- 2. il preflight
## C'È ANCORA, ED È ANCORA QUELLO? — in un decimo di secondo e senza scaricare
## un byte. Hugging Face pubblica lo SHA-256 del file nell'intestazione
## `x-linked-etag` e la dimensione in `x-linked-size` (i `.gguf` sono file
## LFS/Xet: l'etag È l'oid, cioè l'impronta). È lo stesso controllo che fa la
## CI in `release.yml`, e la ragione è la stessa: se a monte il file è
## cambiato, saperlo **prima** di quaranta minuti di scarico.
##
## ⚠️ E non è LA verifica: è un fumo. L'autorità resta l'impronta ricalcolata
## sui byte che sono atterrati sul disco. Se l'intestazione non arriva — è un
## dettaglio di come Hugging Face serve i file grossi, e può cambiare — non
## succede niente: si scarica e si verifica alla fine.
func _passo_testa() -> int:
	if not _chiesto:
		_url_ora = _url
		var err = _rete.chiedi(_url_ora, teste_di(-1), true)
		if err != OK:
			return _riprova("non riesco a chiedere (errore %d)" % err)
		_chiesto = true
		return PASSO_AVANTI

	var stato = _rete.avanza()
	match stato:
		ScaricoRete.ATTENDE:
			return PASSO_ATTESA
		ScaricoRete.GUASTO:
			return _riprova("la richiesta non è arrivata a destinazione")
		ScaricoRete.TESTE:
			var c := int(_rete.codice())
			var fermo := _codice_fermo(c)
			if fermo != ESITO_NIENTE:
				_rete.chiudi()
				_finisci(fermo, "a monte: codice %d" % c)
				return PASSO_FINE
			if c >= 400:
				_rete.chiudi()
				return _riprova("a monte: codice %d" % c)
			var etag := etag_pulito(str(_rete.testa("x-linked-etag")))
			var dim := int(str(_rete.testa("x-linked-size")))
			_rete.chiudi()
			_chiesto = false
			if etag != "" and etag != _impronta:
				_finisci(ESITO_SORGENTE,
						"a monte c'è un altro file: impronta %s invece di %s" % [etag, _impronta])
				return PASSO_FINE
			if dim > 0 and dim != _dimensione:
				_finisci(ESITO_SORGENTE,
						"a monte il file pesa %d byte invece di %d" % [dim, _dimensione])
				return PASSO_FINE
			_nota("preflight: %s" % ("impronta e dimensione combaciano" if etag != "" else "nessuna impronta a monte, si verifica alla fine"))
			_fase = FASE_APRE
			return PASSO_AVANTI
	# CORPO/FINE su una HEAD: non ci interessa il corpo, si va avanti.
	return PASSO_AVANTI


# --------------------------------------------------- 3. la richiesta vera
func _passo_apre() -> int:
	if not _chiesto:
		var gia := _quanto_pesa(_parte)
		_da = offset_di_ripresa(gia, indietro)
		_fatti = _da
		_massimo_mai = maxi(_massimo_mai, gia)
		_url_ora = _url  # SEMPRE dall'origine: vedi la nota sui redirect firmati
		_salti = 0
		var err = _rete.chiedi(_url_ora, teste_di(_da), false)
		if err != OK:
			return _riprova("non riesco a chiedere (errore %d)" % err)
		_chiesto = true
		if _da > 0:
			_nota("riprendo da %d MiB" % (_da >> 20))
		return PASSO_AVANTI

	var stato = _rete.avanza()
	match stato:
		ScaricoRete.ATTENDE:
			return PASSO_ATTESA
		ScaricoRete.GUASTO:
			return _riprova("la connessione non si è aperta")
		ScaricoRete.FINE:
			return _riprova("la risposta è finita prima di cominciare")
		ScaricoRete.TESTE:
			return _teste_del_corpo()
	return PASSO_AVANTI


## Le intestazioni della risposta vera. Qui si decide tutto: se si appende, se
## si ricomincia, se si va a verificare, se si molla.
func _teste_del_corpo() -> int:
	var c := int(_rete.codice())

	# 3xx — si segue, con LO STESSO Range.
	# ⚠️ MISURATO il 2026-08-13: l'URL firmato del CDN di Hugging Face è
	# legato al Range che si è chiesto all'ORIGINE. Riusarlo con un altro
	# intervallo risponde `403 Auth failed: invalid range`. Perciò (a) il
	# redirect si segue mandando le stesse identiche intestazioni, e (b) un
	# indirizzo del CDN non si conserva MAI fra un tentativo e l'altro: ogni
	# ripresa riparte da `_url`, l'origine.
	if c in [301, 302, 303, 307, 308]:
		var dove = _rete.testa("location")
		_rete.chiudi()
		if dove == "" or _salti >= SALTI:
			return _riprova("redirect senza destinazione (o troppi salti)")
		_salti += 1
		_url_ora = _assoluto(dove, _url_ora)
		var err = _rete.chiedi(_url_ora, teste_di(_da), false)
		if err != OK:
			return _riprova("non riesco a seguire il redirect (errore %d)" % err)
		return PASSO_AVANTI

	var fermo := _codice_fermo(c)
	if fermo != ESITO_NIENTE:
		_rete.chiudi()
		_finisci(fermo, "a monte: codice %d" % c)
		return PASSO_FINE

	# 416 — «quel pezzo non esiste»: il parziale è lungo quanto (o più di)
	# tutto il file. Se è esattamente lungo, i byte ci sono già tutti e
	# l'unica cosa che manca è la verifica.
	if c == 416:
		_rete.chiudi()
		var gia := _quanto_pesa(_parte)
		if gia == _dimensione:
			_nota("c'era già tutto: vado a verificare")
			_fatti = gia
			_fase = FASE_IMPRONTA
			return PASSO_AVANTI
		_nota("il parziale non va bene (416): ricomincio da capo")
		DirAccess.remove_absolute(_parte)
		return _riprova("il server ha rifiutato la ripresa")

	if c != 200 and c != 206:
		_rete.chiudi()
		return _riprova("a monte: codice %d" % c)

	# 200 con una ripresa in corso = il server ha IGNORATO il Range. Non si
	# appende: si tronca e si riparte (regola 6). Appendere qui vorrebbe dire
	# scrivere un file che ha due volte il suo inizio, scoprirlo solo alla
	# fine, e buttare tutto.
	if c == 200 and _da > 0:
		_nota("il server ha ignorato la ripresa: ricomincio da capo")
		_da = 0
		_fatti = 0

	# 206: il pezzo che ci dà è quello che abbiamo chiesto?
	if c == 206:
		var cr = _rete.testa("content-range")
		var inizio := inizio_di_content_range(cr)
		var totale := totale_di_content_range(cr)
		if inizio != _da or (totale > 0 and totale != _dimensione):
			_rete.chiudi()
			_nota("il pezzo non è quello chiesto (%s): ricomincio da capo" % cr)
			DirAccess.remove_absolute(_parte)
			_da = 0
			_fatti = 0
			return _riprova("ripresa storta")

	# Il file: si apre adesso, non prima. Aprirlo in cima al viaggio vorrebbe
	# dire tenerlo aperto anche mentre si aspetta la rete.
	if not _apri_il_file():
		return PASSO_FINE
	_fase = FASE_CORPO
	return PASSO_AVANTI


# ------------------------------------------------------------ 4. i byte
func _passo_corpo() -> int:
	var stato = _rete.avanza()
	match stato:
		ScaricoRete.ATTENDE:
			return PASSO_ATTESA
		ScaricoRete.GUASTO:
			return _riprova("la linea è caduta a %d MiB" % (_fatti >> 20))
		ScaricoRete.FINE:
			_chiudi_file()
			_rete.chiudi()
			if _fatti < _dimensione:
				# È la caduta più comune: la connessione si chiude a metà. Non
				# è un errore da mostrare, è un tentativo in più.
				return _riprova("la risposta è finita a %d MiB su %d"
						% [_fatti >> 20, _dimensione >> 20])
			_fase = FASE_IMPRONTA
			return PASSO_AVANTI
		ScaricoRete.CORPO:
			var b: PackedByteArray = _rete.pezzo()
			if b.size() == 0:
				return PASSO_ATTESA
			if _fatti + b.size() > _dimensione:
				# Ne manda più del dovuto: non è il nostro file. Si butta
				# subito invece di scoprirlo dopo una lettura di due giga.
				_chiudi_file()
				_rete.chiudi()
				DirAccess.remove_absolute(_parte)
				_finisci(ESITO_SORGENTE, "a monte arrivano più byte del previsto")
				return PASSO_FINE
			_f.store_buffer(b)
			_fatti += b.size()
			return PASSO_AVANTI
	return PASSO_AVANTI


# -------------------------------------------------------- 5. l'impronta
func _passo_impronta() -> int:
	if _h == null:
		_fr = FileAccess.open(_parte, FileAccess.READ)
		if _fr == null:
			_finisci(ESITO_DISCO, "non riesco a rileggere il parziale")
			return PASSO_FINE
		if _fr.get_length() != _dimensione:
			_fr = null
			DirAccess.remove_absolute(_parte)
			_finisci(ESITO_IMPRONTA, "sul disco ci sono byte diversi da quelli attesi")
			return PASSO_FINE
		_h = HashingContext.new()
		_h.start(HashingContext.HASH_SHA256)
		_letti = 0
		return PASSO_AVANTI

	var b := _fr.get_buffer(BOCCONE)
	if b.size() > 0:
		_h.update(b)
		_letti += b.size()
	if _letti < _dimensione and b.size() > 0:
		return PASSO_AVANTI

	var vera := _h.finish().hex_encode()
	_h = null
	_fr = null
	if vera != _impronta:
		# REGOLA 2: si butta. Un file rovinato che resta sul disco spegne la
		# funzione per sempre, e chi gioca vede solo che «non funziona».
		DirAccess.remove_absolute(_parte)
		_nota("impronta sbagliata: buttato")
		_finisci(ESITO_IMPRONTA, "impronta %s invece di %s" % [vera, _impronta])
		return PASSO_FINE
	_nota("impronta giusta")
	_fase = FASE_POSA
	return PASSO_AVANTI


# ----------------------------------------------------------- 6. la posa
func _passo_posa() -> int:
	var err := DirAccess.rename_absolute(_parte, _destinazione)
	if err != OK:
		_finisci(ESITO_DISCO, "non riesco a rinominare il file (errore %d)" % err)
		return PASSO_FINE
	if not FileAccess.file_exists(_destinazione):
		_finisci(ESITO_DISCO, "dopo la rinomina il file non c'è")
		return PASSO_FINE
	# IL CONTRASSEGNO DI PROVENIENZA, e non è un doppione della verifica
	# appena fatta: dice a chi caricherà il modello FRA MESI che quel file
	# l'abbiamo portato noi, e che impronta deve avere. Senza, `user://`
	# resta il posto di chi sperimenta — e nessuno riverifica più niente.
	# Il corriere difende dal download storto; questo dal disco che marcisce,
	# che è il solo guasto contro cui l'impronta è l'unica difesa.
	if _impronta != "":
		LLM.segna_provenienza(_impronta)
	_nota("posato")
	_finisci(ESITO_FATTO, "")
	return PASSO_FINE


# =========================================================================
# LE FUNZIONI PURE — quelle che si possono interrogare da sole
# =========================================================================

## Le intestazioni della richiesta. `da_byte < 0` vuol dire «nessun Range»
## (il preflight); `0` vuol dire «dall'inizio», e allora il `Range` NON si
## manda affatto: una richiesta senza `Range` è quella che ogni server sa
## servire, e ci risparmia il ramo «206 quando volevamo 200».
static func teste_di(da_byte: int) -> PackedStringArray:
	var t := PackedStringArray([
		"User-Agent: ChibiCrossing (scarico del modello)",
		"Accept: */*",
	])
	if da_byte > 0:
		t.append("Range: bytes=%d-" % da_byte)
	return t


## Da che byte si riprende, dato quanto c'è sul disco. Si torna indietro di
## `indietro` byte (regola 5) senza mai andare sotto zero.
static func offset_di_ripresa(gia_sul_disco: int, indietro: int) -> int:
	if gia_sul_disco <= indietro:
		return 0
	return gia_sul_disco - indietro


## Quanto spazio serve DAVVERO: quel che manca, più il cuscino. Non l'intero
## file — chi riprende a tre quarti non deve avere due gigabyte liberi.
static func serve_spazio(dimensione: int, gia_sul_disco: int, margine: int) -> int:
	return maxi(0, dimensione - gia_sul_disco) + margine


## LO SPAZIO BASTA? — e **zero vuol dire «non lo so», non «no»**.
##
## `DirAccess.get_space_left()` risponde su tutte e tre le piattaforme che ci
## interessano, ma una piattaforma futura (o un filesystem di rete) può
## rispondere zero. Spegnere una funzione per un numero che non abbiamo è il
## degrado dalla parte sbagliata: è la stessa regola con cui `llm_memoria.cpp`
## legge la RAM libera — se non si sa, si passa oltre e si scopre scrivendo.
##
## Sta in una funzione sua perché è l'unica parte del cancello dello spazio
## che si possa interrogare: il resto chiede al disco vero, e un banco non può
## fabbricare un disco pieno.
static func spazio_basta(libero: int, serve: int) -> bool:
	if libero <= 0:
		return true
	return libero >= serve


## `"882e8d…"` da `"882E8D…"` o da `W/"882e8d…"`. L'etag di Hugging Face
## arriva fra virgolette; qualche proxy ci mette il prefisso `W/`.
static func etag_pulito(riga: String) -> String:
	var s := riga.strip_edges()
	if s.begins_with("W/"):
		s = s.substr(2)
	return s.replace("\"", "").strip_edges().to_lower()


## `bytes 1048576-2097151/2489757856` → 1048576. `-1` se non si capisce.
static func inizio_di_content_range(riga: String) -> int:
	var s := riga.strip_edges().to_lower()
	if not s.begins_with("bytes "):
		return -1
	s = s.substr(6).strip_edges()
	var barra := s.find("/")
	if barra >= 0:
		s = s.substr(0, barra)
	var trattino := s.find("-")
	if trattino <= 0:
		return -1
	return int(s.substr(0, trattino))


## `bytes 1048576-2097151/2489757856` → 2489757856. `-1` se non si capisce.
static func totale_di_content_range(riga: String) -> int:
	var s := riga.strip_edges()
	var barra := s.find("/")
	if barra < 0:
		return -1
	var coda := s.substr(barra + 1).strip_edges()
	if coda == "*" or not coda.is_valid_int():
		return -1
	return int(coda)


## Un `Location` relativo diventa assoluto. Hugging Face manda un URL intero,
## ma un proxy aziendale (o un mirror) può mandare `/percorso`, e allora
## chiederlo così com'è vuol dire chiederlo a nessuno.
static func _assoluto(dove: String, rispetto_a: String) -> String:
	if dove.begins_with("http://") or dove.begins_with("https://"):
		return dove
	var tre := rispetto_a.find("://")
	if tre < 0:
		return dove
	var dopo := rispetto_a.substr(tre + 3)
	var barra := dopo.find("/")
	var radice := rispetto_a if barra < 0 else rispetto_a.substr(0, tre + 3 + barra)
	if dove.begins_with("/"):
		return radice + dove
	return radice + "/" + dove


# =========================================================================
# LE COSE PICCOLE
# =========================================================================

## I codici davanti ai quali non ha senso riprovare: riprovare cinque volte
## una porta chiusa a chiave fa aspettare per niente.
func _codice_fermo(c: int) -> int:
	if c == 401 or c == 403:
		return ESITO_CHIUSO
	if c == 404 or c == 410:
		return ESITO_SORGENTE
	return ESITO_NIENTE


func _apri_il_file() -> bool:
	if _da > 0:
		# Il parziale DEVE esserci: `_da` è la sua lunghezza, letta poco fa. Se
		# è sparito nel frattempo, scrivere i byte che stanno arrivando (che
		# cominciano da `_da`) in cima a un file nuovo darebbe un file lungo
		# giusto e sbagliato dentro — il guasto che si scopre solo dopo aver
		# letto due gigabyte e mezzo per l'impronta.
		if not FileAccess.file_exists(_parte):
			_finisci(ESITO_DISCO, "il parziale è sparito mentre lo scrivevo")
			return false
		_f = FileAccess.open(_parte, FileAccess.READ_WRITE)
		if _f != null:
			_f.seek(_da)
	else:
		_f = FileAccess.open(_parte, FileAccess.WRITE)
	if _f == null:
		_finisci(ESITO_DISCO, "non riesco a scrivere %s (errore %d)"
				% [_parte, FileAccess.get_open_error()])
		return false
	return true


## ⚠️ Qui c'era un `flush()`, e non c'è più: MISURATO il 2026-08-13, toglierlo
## non fa diventare rossa **nessuna** asserzione — perché lasciar cadere
## l'ultimo riferimento a un `FileAccess` lo chiude, e chiudere scrive. Una
## guardia che nessun test può far fallire è una guardia che non c'è, e si
## toglie (è la stessa conclusione del `chiudi()` ridondante nel distruttore
## del ponte di llama).
func _chiudi_file() -> void:
	_f = null


func _chiudi_tutto() -> void:
	_chiudi_file()
	_h = null
	_fr = null
	if _rete != null:
		_rete.chiudi()


## Un tentativo è andato male. Se ha portato il file più in là di dove fosse
## MAI arrivato, non conta come tentativo (regola 7): la linea sta lavorando,
## sta solo cadendo.
##
## ⚠️ **E il metro è il punto più lontano di sempre, non l'inizio di questo
## tentativo.** Il primo metro era «byte portati da quando è cominciato», e su
## una linea che cade prima di `INDIETRO` byte fa un giro infinito, misurato:
## la ripresa torna indietro di un mebibyte, il tentativo ne porta meno, il
## file non cresce, ma «ha portato dei byte» azzera i tentativi — e si
## ricomincia per sempre, con la CPU a mille e nessun errore. Col massimo di
## sempre, un tentativo conta come progresso solo se il file è più lungo di
## quanto sia mai stato: la fine è garantita perché quel numero può salire al
## massimo `dimensione / INDIETRO` volte.
func _riprova(perche: String) -> int:
	_chiudi_file()
	if _rete != null:
		_rete.chiudi()
	_chiesto = false
	var avanzato := _fatti > _massimo_mai
	if avanzato:
		_massimo_mai = _fatti
		_tentativi = 0
	else:
		_tentativi += 1
	_nota("%s (tentativo %d, il file è a %d MiB)" % [perche, _tentativi, _fatti >> 20])
	if _tentativi > TENTATIVI:
		_finisci(ESITO_RETE, perche)
		return PASSO_FINE
	if pausa_ms > 0:
		_attesa_fino = Time.get_ticks_msec() + pausa_ms * (1 << mini(_tentativi, 4))
	# Si torna a fare la cosa che stava fallendo, non un'altra: un preflight
	# andato male non deve saltare il preflight.
	if _fase != FASE_TESTA:
		_fase = FASE_APRE
	return PASSO_ATTESA


func _finisci(quale: int, perche: String) -> void:
	_esito = quale
	_diagnosi = perche
	_fase = FASE_FINE
	_chiudi_tutto()


func _nota(riga: String) -> void:
	_diario.append(riga)
	if _diario.size() > 64:
		_diario.remove_at(0)


static func _quanto_pesa(percorso: String) -> int:
	if not FileAccess.file_exists(percorso):
		return 0
	var f := FileAccess.open(percorso, FileAccess.READ)
	if f == null:
		return 0
	return f.get_length()
