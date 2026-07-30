extends RefCounted

## LA REGIA DEL DIORAMA — le regole di cosa può succedere, e quando.
##
## Il menù non deve mai mostrare due volte la stessa cosa. Ci arriva per
## tre strade, e questa è la terza (le prime due sono l'ORA vera di chi
## gioca e il CLIMA del villaggio):
##
##  1. ogni avvio ha la sua semina — chi fa cosa, e dove, cambia;
##  2. i mestieri SCADONO: chi guarda un minuto vede finire una rincorsa,
##     uno che si sveglia, uno che si alza e va all'altalena;
##  3. ogni tanto parte una SCENETTA a due — due vicini che si incontrano
##     e si salutano, uno che regala un fiore, una risata. Sono rare
##     apposta: quello che rende speciale una scenetta è non averla mai
##     vista, e chi gioca apre questo menù centinaia di volte.
##
## Qui c'è solo la LOGICA (pure: entrano clima e chi c'è, escono
## decisioni). Chi le esegue è il TitleScreen, chi le recita gli attori —
## così le regole si provano headless, senza aprire una finestra.

## Ogni quanto la regia prova a mettere in scena qualcosa, in secondi.
const PROVA_OGNI := 7.0
## Che probabilità ha di riuscire, se ci sono i presupposti. Bassa
## apposta: una scenetta ogni mezzo minuto buono è un dono, tre di fila
## sono un carosello.
const PROBABILITA := 0.34

## Le scenette, e cosa vogliono per poter partire.
##   attori:  quanti ne servono
##   climi:   dove ha senso (vuoto = ovunque tranne il lutto)
##   rara:    quanto è rara fra le altre possibili (peso)
const SCENETTE := {
	"incontro": {"attori": 2, "climi": [], "peso": 5},
	"fiore": {"attori": 2, "climi": ["serena", "allegria", "armonia"], "peso": 3},
	"risata": {"attori": 2, "climi": ["allegria", "armonia"], "peso": 3},
	"consolazione": {"attori": 2, "climi": ["malinconia", "commiato"], "peso": 4},
	"girotondo": {"attori": 3, "climi": ["armonia"], "peso": 1},
}

## Quali mestieri hanno senso in che clima. Il primo elenco è quello da
## cui si pesca quando un mestiere scade.
const REPERTORIO := {
	"lutto": ["veglia", "veglia", "guarda_in_su", "veglia"],
	"commiato": ["seduto", "guarda_in_su", "veglia", "annusa", "seduto"],
	"malinconia": ["seduto", "annusa", "guarda_in_su", "dorme", "gioca"],
	"attesa": ["seduto", "annusa", "gioca", "dorme"],
	"serena": ["gioca", "seduto", "annusa", "altalena", "dorme"],
	"allegria": ["gioca", "rincorre", "seduto", "altalena", "annusa", "dorme", "saluta"],
	"armonia": ["gioca", "rincorre", "altalena", "saluta", "annusa", "seduto", "dorme"],
}


## IL MESTIERE NUOVO di chi ha appena finito il suo.
##
## Non si ripesca mai quello appena fatto (vedere due rincorse di fila
## dallo stesso vicino è peggio che vederlo fermo), e «rincorre» esce solo
## se c'è qualcun altro libero con cui farlo — una rincorsa da soli attorno
## a un albero è tutta un'altra faccenda.
static func mestiere_nuovo(clima: String, adesso: String, liberi: int,
		rng: RandomNumberGenerator) -> String:
	var lista: Array = (REPERTORIO.get(clima, REPERTORIO["serena"]) as Array).duplicate()
	lista = lista.filter(func(m): return str(m) != adesso)
	if liberi < 1:
		lista = lista.filter(func(m): return str(m) not in ["rincorre", "scappa"])
	if lista.is_empty():
		return "seduto"
	return str(lista[rng.randi() % lista.size()])


## QUALE SCENETTA, se ne può partire una. "" se non è il caso.
##
## Nel lutto non ne parte nessuna, tranne la consolazione: è l'unico gesto
## che in quei giorni non stona — anzi, è l'unico che ci vuole.
static func scenetta(clima: String, disponibili: int,
		rng: RandomNumberGenerator) -> String:
	if rng.randf() > PROBABILITA:
		return ""
	var possibili: Array = []
	var pesi: Array = []
	for nome in SCENETTE:
		var s: Dictionary = SCENETTE[nome]
		if disponibili < int(s["attori"]):
			continue
		var climi: Array = s["climi"]
		if climi.is_empty():
			# le scenette «da sempre» non valgono nel lutto
			if clima == "lutto":
				continue
		elif clima not in climi:
			continue
		possibili.append(nome)
		pesi.append(int(s["peso"]))
	if possibili.is_empty():
		return ""
	var totale := 0
	for p in pesi:
		totale += int(p)
	var tiro := rng.randi() % totale
	for i in possibili.size():
		tiro -= int(pesi[i])
		if tiro < 0:
			return str(possibili[i])
	return str(possibili[0])


## Un OSPITE raro che attraversa la scena: "" quasi sempre.
##
##   farfalla   di giorno: passa, e tutti la seguono con gli occhi
##   lucciola   di notte: si accendono fra l'erba
##   stella     di notte: una cadente, e chi la vede la indica
##
## Sono i momenti che il giocatore racconta («hai visto che una volta è
## passata una farfalla e si sono girati tutti?»), e valgono proprio
## perché non capitano quasi mai.
static func ospite(quanto_e_notte: float, clima: String,
		rng: RandomNumberGenerator) -> String:
	if clima == "lutto":
		return ""            # in quei giorni non passa niente, ed è giusto
	var tiro := rng.randf()
	if quanto_e_notte > 0.5:
		if tiro < 0.10:
			return "stella"
		return ""
	if tiro < 0.14:
		return "farfalla"
	return ""


## La semina di questo avvio. Dal tempo vero: due aperture non danno mai
## lo stesso diorama, e non serve salvare niente.
static func semina() -> int:
	return int(Time.get_unix_time_from_system()) & 0x7FFFFFFF
