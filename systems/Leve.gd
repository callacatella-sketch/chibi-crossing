class_name Leve
extends RefCounted

## LE LEVE — un interruttore per meccanismo, e un posto solo dove stanno.
##
## ────────────────────────────────────────────────────────────────────────
## A COSA SERVE, e non è al gioco
## ────────────────────────────────────────────────────────────────────────
##
## Un meccanismo di questo villaggio si giudica in un modo solo: **lo si
## spegne e si guarda cosa cambia.** È così che si è scoperto che il fattore
## dell'insieme, da solo, non era debole ma INERTE — zero decisioni cambiate
## su seicentoventotto, in tutte e tre le corse. Senza l'interruttore, quel
## numero non si poteva nemmeno chiedere.
##
## Il precedente è `Visitors.debug_occlusione`: un booleano pubblico, acceso
## di serie, letto a un cancello, che **nel gioco non tocca nessuno** (un
## caso di `test_regia` scandaglia i sorgenti perché resti così). Funzionava,
## e aveva tre limiti che si vedono solo quando le leve diventano cinque:
## viveva su un nodo (quindi il banco doveva trovarlo), non aveva un elenco
## (quindi non si poteva sapere quali esistessero), e non si poteva chiedere
## dalla riga di comando (quindi ogni banco riscriveva il suo cablaggio).
##
## ────────────────────────────────────────────────────────────────────────
## LE QUATTRO REGOLE
## ────────────────────────────────────────────────────────────────────────
##
## 1. **DI SERIE È TUTTO ACCESO.** Una leva è uno strumento di misura, non
##    una configurazione: il gioco che gira sulla macchina di chi gioca non
##    ne ha nessuna spenta, mai. Il degrado va verso «il meccanismo c'è».
## 2. **UNA LEVA DICHIARATA DEVE AVERE UN LETTORE, e un lettore deve usare
##    un nome dichiarato.** Le due cose sono sorvegliate da un test nei due
##    versi: una leva senza lettore è una promessa vuota (il banco la spegne
##    e non succede niente, e si legge come «il meccanismo non conta»), e un
##    nome non dichiarato è un errore di battitura che non fallisce da
##    nessuna parte.
## 3. **UN NOME SCONOSCIUTO NON SPEGNE NIENTE.** `acceso()` di una leva che
##    non esiste torna `true` e si lamenta: il verso opposto — spegnere per
##    un nome scritto male — è il guasto che si legge come un risultato.
## 4. **NEL GIOCO NON LE TOCCA NESSUNO.** Si accendono e si spengono da
##    `CHIBI_LEVE` o da un banco. Un caso di test scandaglia `scenes/` e
##    `systems/` perché nessun file di gioco chiami `spegni()`.
##
## ────────────────────────────────────────────────────────────────────────
## COME SI USA
## ────────────────────────────────────────────────────────────────────────
##
##     CHIBI_LEVE="insieme:off,deriva:off" Godot --headless --path . \
##         --script res://tools/misura_insieme.gd
##
## e nel codice, al cancello del meccanismo:
##
##     if Leve.acceso(Leve.INSIEME) and ...


## I MECCANISMI, con la ragione per cui hanno una leva. L'elenco è la fonte
## unica: `tests/cases/test_leve.gd` lo confronta coi lettori veri.
const INSIEME := "insieme"
const RITROVI := "ritrovi"
const DERIVA := "deriva"
const GESTI := "gesti"

## ⚠️ `Visitors.debug_occlusione` NON È STATO PORTATO QUI, ed è una scelta.
## Ha già il suo lettore, la sua guardia in `test_regia` e un banco che la
## alterna a blocchi dentro la stessa corsa (`tools/misura_occlusione.gd`):
## spostarla vorrebbe dire riscrivere una guardia che funziona per
## un'uniformità che non compra niente. Resta l'antenata, dov'è.
const MECCANISMI := {
	INSIEME: "il posto che ha già qualcuno accanto pesa di più",
	RITROVI: "il duetto e gli altri canali del ritrovarsi",
	DERIVA: "i tratti che derivano da come è andata la vita",
	GESTI: "il vocabolario del corpo che pensa",
}

## Le sole spente. Un dizionario e non un elenco: la domanda che si fa
## sessanta volte al secondo è «è spenta?», e su un dizionario costa uguale
## con cinque leve o con cinquanta.
static var _spente := {}
static var _lette := false


## È acceso questo meccanismo? Vedi la regola 3: un nome sconosciuto è
## acceso, e si lamenta.
static func acceso(nome: String) -> bool:
	if not _lette:
		_leggi_ambiente()
	if not MECCANISMI.has(nome):
		push_error("Leve: meccanismo sconosciuto «%s» — resta acceso" % nome)
		return true
	return not _spente.has(nome)


static func spegni(nome: String) -> void:
	if not MECCANISMI.has(nome):
		push_error("Leve: non posso spegnere «%s»: non esiste" % nome)
		return
	_lette = true
	_spente[nome] = true


static func accendi(nome: String) -> void:
	_lette = true
	_spente.erase(nome)


## Le leve spente adesso, in ordine, per il referto di un banco. Un banco
## che non dichiara in che condizione ha misurato non ha misurato niente.
static func spente() -> Array:
	if not _lette:
		_leggi_ambiente()
	var v := _spente.keys()
	v.sort()
	return v


## La condizione, in una parola, per intestare una colonna di risultati.
static func condizione() -> String:
	var v := spente()
	return "tutto" if v.is_empty() else "senza:" + "+".join(v)


## Rimette tutto acceso. Serve a un banco che fa più condizioni dentro lo
## stesso processo: senza, la seconda condizione erediterebbe la prima.
static func dimentica() -> void:
	_spente = {}
	_lette = false


## `CHIBI_LEVE="insieme:off,deriva:off"`. Si legge una volta sola, alla
## prima domanda: leggerla a ogni domanda costerebbe una syscall per
## fotogramma per meccanismo.
static func _leggi_ambiente() -> void:
	_lette = true
	var s := OS.get_environment("CHIBI_LEVE")
	if s == "":
		return
	for pezzo in s.split(",", false):
		var p := pezzo.strip_edges()
		if p == "":
			continue
		var nome := p
		var stato := "off"
		if ":" in p:
			var due := p.split(":", false, 1)
			nome = due[0].strip_edges()
			stato = due[1].strip_edges().to_lower() if due.size() > 1 else "off"
		if not MECCANISMI.has(nome):
			push_error("CHIBI_LEVE: meccanismo sconosciuto «%s» — ignorato" % nome)
			continue
		if stato in ["off", "no", "0", "spento"]:
			_spente[nome] = true
		else:
			_spente.erase(nome)
