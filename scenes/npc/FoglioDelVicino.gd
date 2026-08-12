extends RefCounted

## IL FOGLIO DI UN VICINO — il collettore, cioè l'unico posto che sa dove
## abitano le cose che servono a `Suggeritore`.
##
## `Suggeritore` è puro: prende un Dictionary e torna un prompt. Ma quel
## Dictionary va RIEMPITO, e le sue chiavi vivono in sette posti diversi —
## il cuore C++ (i ricordi, le tinte), `Legami` (l'età), `VillagerBrain` (le
## otto azioni), `Piani` (i quattro obiettivi), `DayNight` (la stagione e il
## ciclo), `OraDelGiorno` (i sei momenti), il registro dei residenti (i nomi
## vivi). Questo file è quel raccordo, e per questo è l'unico pezzo della
## Fase 5 che tocca il villaggio.
##
## ⚠️ **UN COLLETTORE SBAGLIA DOVE UN DIZIONARIO SCRITTO A MANO NON PUÒ.** Un
## ritratto di prova non dimentica mai una chiave; questo sì. Ed è la ragione
## per cui esiste UNA sola copia di questa funzione: quando `tools/
## prova_prompt.gd` costruiva la sua, la stessa domanda aveva già due
## risposte possibili, e il giorno che una delle sette fonti si sposta ne
## resterebbe una giusta e una che racconta un altro villaggio.
##
## Sta a valle del thread e non dentro: il foglio si monta SUL THREAD
## PRINCIPALE, nel momento in cui la generazione comincia. Due ragioni, e la
## seconda è quella che decide:
##  1. le parole di questo gioco vivono tutte in GDScript (è la stessa
##     ragione, per esteso, in cima a `Suggeritore.gd`);
##  2. **il thread non deve poter leggere il registro vivo.** Se il foglio si
##     montasse di là, il thread avrebbe bisogno del grafo, delle tinte e del
##     DNA — cioè di un puntatore dentro l'ECS — mentre `avanza()` ci scrive
##     dentro sessanta volte al secondo. Montandolo di qua, quello che
##     attraversa il confine sono BYTE, e i byte non hanno un puntatore al
##     mondo.
##
## Costa (misurato: vedi `tools/misura_pensieri.gd`), e per questo si chiama
## una volta per generazione — non una per vicino per frame. Il ritmo lo
## tiene `Pensatoio.gd`.

const SUG := preload("res://scenes/npc/Suggeritore.gd")
const BRAIN := preload("res://scenes/npc/VillagerBrain.gd")
const PIANI := preload("res://scenes/npc/Piani.gd")
const ORA := preload("res://scenes/ui/OraDelGiorno.gd")


## Il ritratto di UN residente. `r` è la sua riga in `Visitors._residents`.
## Torna `{}` se manca il cuore o l'handle: il degrado è il silenzio.
static func ritratto(visitors: Node, daynight: Node, cuore: Object, r: Dictionary,
		compito: String, protagonista: String) -> Dictionary:
	if cuore == null or not is_instance_valid(cuore) or not r.has("ecs"):
		return {}
	var id := int(r["ecs"])
	var nome := str(r.get("label", ""))

	# L'ETÀ la sa solo il Filo Rosso, e non è un numero: è una parola
	# («cucciolo», «anziano»). Se non c'è nessun Legami — i banchi di prova,
	# il prologo — non si inventa un'età: resta vuota, e il foglio non ne
	# parla.
	var eta := ""
	var legami: Node = visitors.get_tree().get_first_node_in_group("legami") \
			if visitors.is_inside_tree() else null
	if legami != null and is_instance_valid(legami):
		eta = str(legami.call("eta_di", nome))

	# L'AZIONE la decide il C++ (Fase 2) e il nome sta in `VillagerBrain`:
	# l'indice non si traduce a mano da nessuna parte.
	var i_az := int(cuore.call("azione", id))
	var azione := "" if (i_az < 0 or i_az >= BRAIN.AZIONI.size()) else str(BRAIN.AZIONI[i_az])
	var obiettivo := str(PIANI.OBIETTIVO.get(azione, ""))

	# CHI È ANCORA QUI: handle → nome. Chi è partito NON è in questa mappa, e
	# per questo il suo nome non può finire in una frase. È il degrado che il
	# grafo dichiara di suo: «un'etichetta assente, mai un comportamento
	# sbagliato».
	var nomi := {}
	for altro in (visitors.get("_residents") as Array):
		var a := altro as Dictionary
		if a.has("ecs"):
			nomi[int(a["ecs"])] = str(a.get("label", ""))

	var cervello = visitors.call("_ensure_brain", r)
	var chi := {
		"nome": nome,
		"eta": eta,
		"indole": (cervello.indole as Array).duplicate(),
		"quirk": str(cervello.quirk),
		"casa": _mondo(r.get("cell", Vector2i.ZERO)),
		"azione": azione,
		"obiettivo": obiettivo,
	}
	var mondo := {
		"protagonista": protagonista,
		"nomi": nomi,
		"compito": compito,
	}
	# FASE 5: PER COSA IL MONDO HA UNA STRADA, adesso. Lo sa solo il registro
	# (ha i luoghi e il risolutore), e serve alla grammatica delle deduzioni,
	# che così non può nemmeno campionare un obiettivo irraggiungibile. Il
	# `has_method` non è prudenza generica: `visitors` nei banchi di prova è
	# un finto, e un finto non deve dover implementare tutto il registro per
	# far girare il resto del foglio. Assente = «non filtrare», che è il
	# comportamento di prima.
	if visitors != null and visitors.has_method("obiettivi_fattibili"):
		mondo["fattibili"] = visitors.call("obiettivi_fattibili", r)
	if daynight != null and is_instance_valid(daynight):
		mondo["stagione"] = str(daynight.call("season_name"))
		mondo["momento"] = ORA.momento(int(float(daynight.get("time")) * 24.0))
		mondo["ciclo"] = float(daynight.get("cycle_seconds"))
	return SUG.ritratto(cuore, id, chi, mondo)


## IL FOGLIO PRONTO DA DARE AL MOTORE: `{sistema, utente, grammatica, seme}`,
## oppure `{}` — e `{}` è il caso normale, non un errore: un vicino che non ha
## visto niente non ha niente da raccontare, e il gioco usa i testi scritti a
## mano.
##
## Il SEME arriva da fuori e non si tira qui: in questo gioco i dadi si
## salvano (`Animo._rng`), e un dado nuovo dentro un generatore di prompt
## sarebbe una seconda storia che nessun salvataggio racconta.
static func foglio(visitors: Node, daynight: Node, cuore: Object, r: Dictionary,
		compito: String, protagonista: String, seme: int) -> Dictionary:
	var rit := ritratto(visitors, daynight, cuore, r, compito, protagonista)
	if rit.is_empty():
		return {}
	var parti: Dictionary = SUG.parti(rit)
	if parti.is_empty():
		return {}
	var gram: String = SUG.grammatica(rit)
	if gram == "":
		# NON PUÒ SUCCEDERE per costruzione (`parti` è vuoto quando non ci sono
		# citazioni, e la grammatica è vuota nello stesso caso). Ma se un
		# giorno succedesse, si tace: un modello senza grammatica ha inventato
		# nel 27% dei casi misurati, e una citazione falsa non attenua
		# l'effetto — lo inverte.
		return {}
	return {
		"sistema": str(parti["sistema"]),
		"utente": str(parti["utente"]),
		"grammatica": gram,
		"seme": seme,
		# il ritratto viaggia col foglio: chi riceve le bozze deve poterle
		# passare da `Suggeritore.accetta()`, e quel collaudo vuole lo STESSO
		# ritratto con cui è stata fatta la grammatica. Ricostruirlo dopo
		# vorrebbe dire collaudare contro un villaggio di qualche secondo dopo.
		"ritratto": rit,
	}


## IL FOGLIO DELLA DEDUZIONE: stessa forma dell'altro, altra grammatica.
##
## È l'altra metà della Fase 5 — non una lettera, un JSON — e passa dalla
## stessa coda, dallo stesso motore e dallo stesso ritratto. La sola cosa che
## cambia è cosa il modello ha il permesso di scrivere, ed è per quello che
## qui non c'è nessun ramo nuovo: si chiedono le due parti e la grammatica a
## `Suggeritore`, e se una delle due è vuota si tace.
##
## Il `compito` del ritratto resta «pensiero», e non è un dettaglio: le frasi
## chiuse che il vicino può citare devono essere in PRIMA PERSONA, perché è
## lui che sta pensando — è la stessa scelta di registro del pensiero, e
## `_blocco_ricordi_numerati` le riusa così come sono.
static func foglio_deduzione(visitors: Node, daynight: Node, cuore: Object,
		r: Dictionary, protagonista: String, seme: int) -> Dictionary:
	var rit := ritratto(visitors, daynight, cuore, r, "pensiero", protagonista)
	if rit.is_empty():
		return {}
	var parti: Dictionary = SUG.parti_deduzione(rit)
	if parti.is_empty():
		return {}
	var gram: String = SUG.grammatica_deduzione(rit)
	if gram == "":
		# non può succedere per costruzione (`parti_deduzione` è vuoto
		# esattamente quando la grammatica lo è). Se succedesse si tace: un
		# JSON senza grammatica è un JSON che può chiedere qualunque cosa, e
		# «qualunque cosa» qui vuol dire muovere un corpo.
		return {}
	return {
		"sistema": str(parti["sistema"]),
		"utente": str(parti["utente"]),
		"grammatica": gram,
		"seme": seme,
		"ritratto": rit,
	}


static func _mondo(c) -> Vector3:
	var v: Vector2i = c if c is Vector2i else Vector2i.ZERO
	return Vector3(v.x, 0.0, v.y)
