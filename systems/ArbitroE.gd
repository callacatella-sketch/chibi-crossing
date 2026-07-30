extends Node
## L'ARBITRO DELLA E — chi vince quando il tasto è uno e le cose sono tante.
##
## IL DIFETTO. Trentanove ascoltatori si contendevano l'azione "interact",
## trentadue consumavano l'evento, e non c'era nessun arbitro: vinceva chi
## capitava prima nell'albero della scena, cioè un ordine ACCIDENTALE —
## deciso da quale riga di `_ready` aveva istanziato quel sistema. Il
## risultato lo vedeva il giocatore, non il programmatore:
##   · con un semino in tasca, OGNI E dentro il villaggio piantava un
##     albero — sopra la panchina, sopra la posta, sopra l'aiuola;
##   · premevi E per lanciare la canna sullo stagno e calava un'asciata;
##   · mentre aspettavi lo strattone del pesce non ti potevi più alzare
##     da niente: la canna mangiava la E e non ne faceva nulla;
##   · il guardaroba non vedeva mai la E: perdeva sempre, sempre.
##
## LA REGOLA, in una frase:
##   «Vince chi ti tira FUORI da dove sei; poi ciò che sta per SCAPPARE;
##    poi chi ha un VOLTO; poi il GESTO sul mondo; poi i MOBILI.
##    A parità di gradino, il più vicino.»
##
## Si legge ad alta voce e si capisce — che è la prova migliore per una
## regola di gioco. Restare intrappolati è il male peggiore, perciò
## l'uscita vince su tutto; una farfalla che passa non ripassa, perciò
## batte un cassetto che sarà lì anche domani.
##
## COME SI MIGRA (a ondate, senza una giornata di rotture). L'arbitro
## intercetta la E in `_input`, che in Godot arriva PRIMA di ogni
## `_unhandled_input`: se un iscritto è in gioco, l'arbitro assegna e
## consuma, e nessun vecchio ascoltatore vede niente. Se NESSUN iscritto
## è in gioco, l'arbitro non tocca l'evento e i non ancora migrati si
## comportano esattamente come prima.
## Perciò iscriversi è ADDITIVO: si aggiunge la chiamata a `iscrivi()` e
## non si toglie niente. Il vecchio `_unhandled_input` resta lì come
## rete e non dà fastidio — quando l'arbitro assegna non viene chiamato,
## e quando l'arbitro tace vuol dire che quel sito non era in gioco.

## I GRADINI. Numeri bassi = vince prima.
enum {
	USCITA = 0,   ## tirarsi fuori da dove si è: alzarsi, sbarcare, smettere
	FUGACE = 1,   ## ciò che passa e non ripassa: la farfalla, la bottiglia
	VOLTO = 2,    ## una persona davanti a te: regalare, consegnare, parlare
	GESTO = 3,    ## gli attrezzi e i gesti sul mondo: pesca, taglia, semina
	ARREDO = 4,   ## i mobili e i pannelli: siediti, ricettario, lavagna
	SFONDO = 5,   ## tutto il resto
}

const NOMI_GRADINI := ["uscita", "fugace", "volto", "gesto", "arredo", "sfondo"]

# gli iscritti: {chi, nome, gradino, in_gioco: Callable, agisci: Callable}
var _iscritti: Array = []
# l'ultimo verdetto, per il registro e per i test
var _ultimo := {}
var _player: Node


func _ready() -> void:
	add_to_group("arbitro_e")
	# PAUSABILE, non ALWAYS: a gioco in pausa l'arbitro deve TACERE, o si
	# metterebbe in mezzo fra il menu di pausa e i suoi tasti. Chi governa
	# la pausa è il menu di pausa.
	process_mode = Node.PROCESS_MODE_PAUSABLE
	(func(): _player = get_parent().get_node_or_null("Player")).call_deferred()


## Un candidato si iscrive UNA VOLTA, nel suo `_ready`, e resta.
##
## [param in_gioco] deve rispondere «quanto sei lontano da me?»: la
## DISTANZA in metri se il gesto è disponibile adesso, oppure un numero
## NEGATIVO se non lo è. Non è un booleano di proposito: a parità di
## gradino la distanza è ciò che decide, ed è anche l'unica risposta che
## un candidato può dare onestamente senza sapere nulla degli altri.
##
## [param agisci] fa la cosa. L'arbitro ha già consumato l'evento.
func iscrivi(chi: Node, nome: String, gradino: int,
		in_gioco: Callable, agisci: Callable) -> void:
	for i in _iscritti:
		if i["chi"] == chi and str(i["nome"]) == nome:
			return   # due volte no: succede coi nodi che rinascono
	_iscritti.append({"chi": chi, "nome": nome, "gradino": gradino,
			"in_gioco": in_gioco, "agisci": agisci})


func dimentica(chi: Node) -> void:
	_iscritti = _iscritti.filter(func(i): return i["chi"] != chi)


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact"):
		return
	# LA VALVOLA CHE RENDE SICURA OGNI ONDATA. Se Mochi è congelata, in
	# questo gioco vuol dire che un pannello o una posa la tiene: e i
	# pannelli non sono ancora migrati. L'arbitro allora TACE e non
	# consuma, così la E arriva intatta a chi ha congelato — che è
	# l'unico a sapere come liberarla. Senza questa riga, un iscritto
	# ancora "in gioco" ruberebbe la E a un pannello aperto e il
	# giocatore resterebbe chiuso dentro.
	if _player != null and is_instance_valid(_player) \
			and _player.has_method("is_physics_processing") \
			and not _player.is_physics_processing():
		return
	var vincitore := scegli()
	if vincitore.is_empty():
		return   # nessun iscritto in gioco: la E prosegue com'è sempre stata
	# se il vincitore dichiara di NON avercela fatta (false), l'evento
	# prosegue: meglio una E che scivola che una E che sparisce
	var esito = (vincitore["agisci"] as Callable).call()
	if esito is bool and not esito:
		return
	get_viewport().set_input_as_handled()


## IL VERDETTO, separato dall'input per poterlo provare headless.
## Interroga gli iscritti, scarta i morti e i non-in-gioco, e ordina per
## (gradino, distanza). Ritorna {} se non c'è nessuno in gioco.
func scegli() -> Dictionary:
	var c := candidato()
	if c.is_empty():
		_ultimo = {}
		return {}
	_ultimo = {"nome": str(c["nome"]), "gradino": int(c["gradino"]),
			"d": float(c["distanza"]), "contesi": int(c["contesi"])}
	return c["iscritto"]


## CHI VINCEREBBE ADESSO, senza toccare niente. È `scegli()` meno l'atto di
## registrare il verdetto — e la differenza conta: il taccuino del Gufo
## chiede «cosa farebbe il giocatore se premesse E?» cinque volte al
## secondo, e se quelle domande finissero in `ultimo_verdetto()` il
## registro delle contese diventerebbe il registro dei sondaggi.
##
## Ritorna {} se nessuno è in gioco, altrimenti
## {iscritto, nome, gradino, distanza, chi, contesi}.
func candidato() -> Dictionary:
	var candidati: Array = []
	var vivi: Array = []
	for i in _iscritti:
		var chi := i["chi"] as Node
		if chi == null or not is_instance_valid(chi):
			continue      # un sistema smontato non si porta dietro la E
		vivi.append(i)
		if not (i["in_gioco"] as Callable).is_valid():
			continue
		var d: float = float((i["in_gioco"] as Callable).call())
		if d < 0.0:
			continue
		candidati.append({"i": i, "d": d})
	_iscritti = vivi
	if candidati.is_empty():
		return {}
	candidati.sort_custom(func(a, b):
		var ga: int = int(a["i"]["gradino"])
		var gb: int = int(b["i"]["gradino"])
		if ga != gb:
			return ga < gb
		if not is_equal_approx(float(a["d"]), float(b["d"])):
			return float(a["d"]) < float(b["d"])
		# spareggio STABILE sul nome: a parità esatta di gradino e
		# distanza, l'ordine non deve dipendere da come il motore ha
		# ordinato l'array — sarebbe l'ordine dell'albero da capo
		return str(a["i"]["nome"]) < str(b["i"]["nome"]))
	var vinto: Dictionary = candidati[0]["i"]
	return {"iscritto": vinto, "nome": str(vinto["nome"]),
			"gradino": int(vinto["gradino"]), "distanza": float(candidati[0]["d"]),
			"chi": vinto["chi"], "contesi": candidati.size()}


## Chi ha vinto l'ultima contesa (per il registro e per le prove).
func ultimo_verdetto() -> Dictionary:
	return _ultimo.duplicate()


## Quanti sistemi si sono iscritti finora (la migrazione avanza a ondate).
func quanti_iscritti() -> int:
	return _iscritti.size()
