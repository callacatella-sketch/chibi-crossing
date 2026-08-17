extends RefCounted
## L'ORACOLO DEL SONNO: la copia CONGELATA di com'era prima dell'ECS.
##
## Sta FUORI da tests/cases/ apposta — il runner esegue solo
## tests/cases/test_*.gd — perché non è un caso di test: è il metro con cui
## si misura che la migrazione non ha cambiato il gioco.
##
## Queste diciassette righe erano `Visitors._sleep_window()` e
## `VillagerBrain.nottambulo()`. Di là ADESSO NON CI SONO PIÙ: la finestra
## del sonno vive in un posto solo, in C++ (src/sistema_sonno.cpp). Qui
## restano solo per il confronto, e proprio perché non sono più codice di
## produzione non sono una seconda fonte di verità: nessuno le chiama in
## partita, e se un domani il C++ cambia idea di proposito, questo file si
## aggiorna a mano — deliberatamente, con un commit che lo dice.
##
## NON CANCELLARE senza cancellare anche la prova di equivalenza: sarebbe
## come togliere il campione di riferimento e continuare a pesare.


## Era VillagerBrain.nottambulo() — «resta alzato quando gli altri rientrano».
static func nottambulo(indole: Array, quirk: String) -> bool:
	return "sognatore" in indole or quirk == "canta_alla_luna"


## Era Visitors._sleep_window(brain, t), riga per riga.
static func finestra(indole: Array, quirk: String, t: float) -> bool:
	var inizio := 0.80
	var fine := 0.295
	if "mattiniero" in indole:
		fine = 0.262
	elif "dormiglione" in indole:
		fine = 0.36
	if nottambulo(indole, quirk):
		inizio = 0.92
	return t >= inizio or t < fine
