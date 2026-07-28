class_name L10n
extends RefCounted

## LA VOCE DEL VILLAGGIO IN ALTRE LINGUE.
##
## Chibi Crossing è scritto in italiano — e l'italiano resta la LINGUA
## SORGENTE: nel codice le frasi restano quelle vere, leggibili, che
## l'autore ha scritto. Non ci sono chiavi opache tipo `MAIL_LETTER_3`
## sparse nei sorgenti: la chiave È la frase italiana.
##
##     L10n.t("Buongiorno!")           -> "Good morning!"   (locale en)
##     L10n.t("Buongiorno!")           -> "Buongiorno!"     (locale it)
##
## Perché così e non con le chiavi:
##   1. il codice resta LEGGIBILE (è la regola di questa casa: si deve
##      capire cosa dice il gioco leggendo il sorgente, non un CSV);
##   2. una traduzione mancante non produce mai una schermata di sigle:
##      produce la frase italiana, che è brutta ma comprensibile;
##   3. le stringhe che viaggiano nei SALVATAGGI (nomi dei pezzi del
##      catalogo, id delle specie, gradini della scala) non vanno mai
##      toccate — qui si traduce solo al momento di MOSTRARE, mai il dato.
##      Un salvataggio fatto in inglese si riapre in italiano, e viceversa.
##
## Le tabelle vivono in `locale/en/*.gd` (una per area, così più persone —
## o più agenti — ci lavorano senza pestarsi). Sono GDScript e non JSON/CSV
## di proposito: nessun passaggio di import, nessun filtro di export da
## ricordare, e il testo con gli a capo e gli accenti non ha bisogno di
## essere protetto da virgolette e virgole.
##
## Aggiungere una lingua: una cartella `locale/<codice>/` con le stesse
## parti, e una riga in TABELLE qui sotto.

# Le parti della traduzione inglese. Elencarle qui è l'unico passo per
# aggiungerne una nuova (la lista esplicita è voluta: un file dimenticato
# in una cartella non deve poter sparire in silenzio).
const EN := [
	preload("res://locale/en/ui.gd"),
	preload("res://locale/en/lettere.gd"),
	preload("res://locale/en/mondo.gd"),
	preload("res://locale/en/npc.gd"),
]

const TABELLE := {"en": EN}

## Le lingue che il giocatore può scegliere: codice -> nome nella lingua
## stessa (mai tradotto: "Italiano" si scrive così anche in inglese).
const LINGUE := {"it": "Italiano", "en": "English"}

## La lingua sorgente: per lei non serve nessuna tabella (la chiave è già
## la frase giusta).
const SORGENTE := "it"

## Con "auto", a chi ha il sistema in una lingua che non parliamo si dà
## l'INGLESE, non l'italiano: è la lingua che il maggior numero di persone
## riesce a leggere. L'italiano tocca a chi ha il sistema in italiano (e a
## chi lo sceglie a mano).
const PREDEFINITA := "en"

static var _tabella := {}
static var _lingua := ""
static var _pronta := false


## La frase nella lingua di adesso. Se la traduzione manca, torna la frase
## italiana: mai una sigla, mai una stringa vuota.
static func t(frase: String) -> String:
	if frase.is_empty():
		return frase
	_assicura()
	if _tabella.is_empty():
		return frase
	return String(_tabella.get(frase, frase))


## Come `t()` ma con i parametri di formato già applicati. Comodo perché
## l'ordine giusto è SEMPRE «prima traduci, poi formatta»: formattare prima
## produrrebbe una frase con dentro i valori, che nella tabella non c'è.
##     L10n.tf("Hai preso %s! (n. %d)", [nome, quanti])
static func tf(frase: String, argomenti: Array) -> String:
	return t(frase) % argomenti


## Ricarica la tabella se la lingua è cambiata (o alla prima chiamata).
static func _assicura() -> void:
	var ora := lingua_corrente()
	if _pronta and ora == _lingua:
		return
	_lingua = ora
	_pronta = true
	_tabella = {}
	if ora == SORGENTE or not TABELLE.has(ora):
		return
	for parte in TABELLE[ora]:
		for chiave in parte.tabella():
			_tabella[chiave] = parte.tabella()[chiave]
	_registra_in_godot()


## Monta la tabella anche dentro il TranslationServer di Godot: così i nodi
## Control che traducono da soli il loro `text` (l'auto-translate di Godot)
## pescano dalla nostra stessa tabella, senza una seconda copia da tenere
## allineata.
static func _registra_in_godot() -> void:
	var tr_res := Translation.new()
	tr_res.locale = _lingua
	for chiave in _tabella:
		tr_res.add_message(chiave, str(_tabella[chiave]))
	TranslationServer.add_translation(tr_res)


## Il codice a due lettere della lingua di adesso ("it", "en").
static func lingua_corrente() -> String:
	var loc := TranslationServer.get_locale()
	return loc.substr(0, 2).to_lower() if loc.length() >= 2 else SORGENTE


## Applica una lingua ("auto" = quella del sistema, se la conosciamo).
## La chiama Settings; è static perché serve anche prima che l'albero esista.
static func imposta(codice: String) -> void:
	var scelto := codice
	if codice == "auto":
		var sistema := OS.get_locale_language()
		scelto = sistema if LINGUE.has(sistema) else PREDEFINITA
	if not LINGUE.has(scelto):
		scelto = SORGENTE
	TranslationServer.set_locale(scelto)
	_pronta = false
	_assicura()


## Quante frasi conosce la lingua data (per il test di copertura e per il
## rapporto di traduzione).
static func quante(codice: String) -> int:
	if not TABELLE.has(codice):
		return 0
	var viste := {}
	for parte in TABELLE[codice]:
		for chiave in parte.tabella():
			viste[chiave] = true
	return viste.size()
