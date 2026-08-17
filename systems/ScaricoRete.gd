class_name ScaricoRete
extends RefCounted

## IL TUBO — l'unico pezzo del gioco che parla con la rete, e non decide niente.
##
## Sei metodi, nessuna politica: chiedi, avanza, che codice è, che intestazione
## c'è, dammi un pezzo, chiudi. Tutte le decisioni — riprendere, ricominciare,
## seguire un redirect, arrendersi, buttare — stanno in
## [`ScaricoMacchina`](ScaricoMacchina.gd), che di `HTTPClient` non sa niente.
##
## È questa separazione a rendere provabile il resto: nei test la macchina VERA
## cammina con un tubo finto che sa cadere a metà, ignorare il `Range` e mandare
## byte sbagliati — tre cose che una rete vera fa e che nessuna suite può
## aspettare.
##
## ⚠️ **LA TRAPPOLA DI TLS, MISURATA (Godot 4.7.1, 2026-08-13): prima del primo
## fotogramma la cifratura NON si accende.** Un `HTTPClient.connect_to_host(…,
## TLSOptions.client())` chiamato dentro `_init()` di uno script `SceneTree`
## risponde `SSL module failed to initialize!` e lo stato resta
## `STATUS_CANT_CONNECT`; lo stesso identico codice, dopo un solo
## `await process_frame`, si connette in 190 ms — **e funziona anche da un
## thread**. In partita non capita mai (si scarica da un bottone, non dal
## caricamento), ma un banco che parte in `_init` diagnosticherebbe «rete
## morta» con la rete perfettamente viva. I banchi aspettano un fotogramma
## prima di chiedere qualunque cosa.
##
## ⚠️ **E IL TEMPO SI CONTA SUI BYTE, NON SULLA RICHIESTA.** Un timeout
## sull'intera richiesta è sbagliato per un file da due gigabyte e mezzo: su
## una linea lenta il viaggio dura mezz'ora, ed è normale. Quello che NON è
## normale è una connessione che sta aperta e non porta più niente: perciò il
## cronometro si azzera a ogni byte che arriva (`STALLO_MS`).

## Cosa sta facendo il tubo. Sono le stesse costanti che usa la macchina, e
## stanno qui perché qui c'è il tubo: chi ne scrive un altro (i test) copia il
## vocabolario, non la logica.
enum {
	ATTENDE,  ## sta lavorando, non c'è niente da fare adesso
	TESTE,    ## le intestazioni sono arrivate (una volta sola per richiesta)
	CORPO,    ## c'è un pezzo di corpo da prendere con `pezzo()`
	FINE,     ## il corpo è finito
	GUASTO,   ## la connessione non c'è più
}

## Quanti millisecondi si accetta di stare attaccati senza ricevere un byte.
## Trenta secondi è lungo per un fotogramma e cortissimo per una linea che sta
## soltanto andando piano: qui non si aspetta la LENTEZZA, si aspetta il NULLA.
const STALLO_MS := 30000

## Quanto si chiede al motore per volta. Non cambia la velocità (MISURATO: 7.35
## MB/s con 64 KiB, 7.38 con 1 MiB — la linea è il collo di bottiglia, non
## noi), ma tiene corti i giri del thread.
const BOCCONE := 1 << 16


var _c: HTTPClient = null
var _teste_date := false
var _teste := {}
var _pezzo := PackedByteArray()
var _chiesto := false
var _percorso := ""
var _intestazioni := PackedStringArray()
var _solo_testa := false
var _ultimo_byte := 0


## Apre e chiede. Non blocca: il lavoro vero lo fa `avanza()`, un pezzo per
## volta, così chi ci cammina sopra può annullare in qualunque momento.
func chiedi(url: String, intestazioni: PackedStringArray, solo_testa: bool) -> int:
	chiudi()
	var u := pezzi_di_url(url)
	if u.is_empty():
		return ERR_INVALID_PARAMETER
	_c = HTTPClient.new()
	_c.set_read_chunk_size(BOCCONE)
	_percorso = u.percorso
	_intestazioni = intestazioni
	_solo_testa = solo_testa
	_teste_date = false
	_teste = {}
	_pezzo = PackedByteArray()
	_chiesto = false
	_ultimo_byte = Time.get_ticks_msec()
	var tls: TLSOptions = TLSOptions.client() if u.cifrata else null
	return _c.connect_to_host(u.host, u.porta, tls)


func avanza() -> int:
	if _c == null:
		return GUASTO
	var stato := _c.get_status()

	if stato == HTTPClient.STATUS_RESOLVING or stato == HTTPClient.STATUS_CONNECTING:
		_c.poll()
		return _scaduto()

	if stato == HTTPClient.STATUS_CONNECTED and not _chiesto:
		var metodo := HTTPClient.METHOD_HEAD if _solo_testa else HTTPClient.METHOD_GET
		var err := _c.request(metodo, _percorso, _intestazioni)
		if err != OK:
			return GUASTO
		_chiesto = true
		return ATTENDE

	if stato == HTTPClient.STATUS_REQUESTING:
		_c.poll()
		return _scaduto()

	if stato == HTTPClient.STATUS_BODY or stato == HTTPClient.STATUS_CONNECTED:
		# ⚠️ **`has_response()` SI PUÒ CHIEDERE SOLO PRIMA DI AVER LETTO LE
		# INTESTAZIONI**, e questa riga è costata un download intero.
		# `HTTPClient.get_response_headers()` in Godot **svuota** la lista
		# mentre la consegna (`response_headers.clear()` dentro il motore):
		# subito dopo, `has_response()` torna **false** anche se la risposta
		# c'è, lo stato è `STATUS_BODY` e i byte stanno arrivando.
		#
		# MISURATO il 2026-08-13 sulla sorgente vera: con la guardia messa
		# prima del ramo delle intestazioni, il tubo restituiva `ATTENDE`
		# **7932 volte in dodici secondi** e ZERO byte — con la suite
		# completamente verde, perché il tubo finto dei test non ha (e non
		# deve avere) questo comportamento. È la ragione per cui il seam sta
		# esattamente qui: quello che i test non possono coprire è il tubo, e
		# il tubo si prova scaricando davvero.
		if not _teste_date:
			if not _c.has_response():
				# connesso, richiesto, e ancora niente: si aspetta
				_c.poll()
				return _scaduto()
			_teste_date = true
			_prendi_le_teste()
			return TESTE
		if stato != HTTPClient.STATUS_BODY:
			return FINE
		var err := _c.poll()
		if err != OK:
			return GUASTO
		_pezzo = _c.read_response_body_chunk()
		if _pezzo.size() > 0:
			_ultimo_byte = Time.get_ticks_msec()
			return CORPO
		# vuoto: o sta arrivando, o è finita. Lo dice lo stato al giro dopo.
		if _c.get_status() != HTTPClient.STATUS_BODY:
			return FINE
		return _scaduto()

	if stato == HTTPClient.STATUS_DISCONNECTED:
		# Il corpo può essere finito con la connessione chiusa dal server: se
		# le intestazioni erano arrivate, è una fine; altrimenti è un guasto.
		return FINE if _teste_date else GUASTO

	return GUASTO


func codice() -> int:
	if _c == null:
		return 0
	return _c.get_response_code()


## Un'intestazione per nome (minuscolo), "" se non c'è. Le teste HTTP non
## distinguono maiuscole e minuscole, e Hugging Face manda `X-Linked-ETag`
## dall'origine e `content-range` dal CDN: chiederle col nome esatto è un modo
## di non trovarle mai.
func testa(nome: String) -> String:
	return str(_teste.get(nome.to_lower(), ""))


func pezzo() -> PackedByteArray:
	return _pezzo


func chiudi() -> void:
	if _c != null:
		_c.close()
		_c = null
	_pezzo = PackedByteArray()


## `https://host:443/percorso?query` a pezzi. Vuoto se non si capisce.
##
## ⚠️ **DUE TRAPPOLE, TUTTE E DUE NELLA RISPOSTA VERA DI HUGGING FACE.**
##  1. **La firma della CDN contiene delle BARRE.** L'indirizzo a cui rimbalza
##     (`us.aws.cdn.hf.co/xet-bridge-us/…?…&Policy=<base64>&Signature=<base64>`)
##     porta due campi in base64, e il base64 usa `/`. Uno `split("/")` per
##     ricostruire la via la taglia a metà, e l'unica traccia che se ne vede è
##     un `403`. Qui la via è **tutto quello che viene dopo la prima barra**,
##     per sottrazione: le altre non si guardano nemmeno.
##  2. **I due punti di un IPv6 non sono una porta.** `http://[::1]:8080/x` ha
##     tre `:` e uno solo separa la porta. Si guarda dopo la parentesi quadra
##     chiusa, che è esattamente perché quelle parentesi esistono.
static func pezzi_di_url(url: String) -> Dictionary:
	var cifrata := url.begins_with("https://")
	if not cifrata and not url.begins_with("http://"):
		return {}
	var resto := url.substr(url.find("://") + 3)
	var barra := resto.find("/")
	var autorita := resto if barra < 0 else resto.substr(0, barra)
	var percorso := "/" if barra < 0 else resto.substr(barra)
	var host := autorita
	var porta := 443 if cifrata else 80
	var da := autorita.rfind("]") if autorita.begins_with("[") else 0
	var duepunti := autorita.find(":", da)
	if duepunti > 0:
		host = autorita.substr(0, duepunti)
		porta = int(autorita.substr(duepunti + 1))
	if host == "":
		return {}
	return {"host": host, "porta": porta, "percorso": percorso, "cifrata": cifrata}


func _prendi_le_teste() -> void:
	for riga in _c.get_response_headers():
		var duepunti := riga.find(":")
		if duepunti <= 0:
			continue
		_teste[riga.substr(0, duepunti).strip_edges().to_lower()] = riga.substr(duepunti + 1).strip_edges()


func _scaduto() -> int:
	if Time.get_ticks_msec() - _ultimo_byte > STALLO_MS:
		return GUASTO
	return ATTENDE
