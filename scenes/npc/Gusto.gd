extends RefCounted

## IL GUSTO — quanto importa a un vicino di ciascuna delle sei cose che può
## vedere fare a Mochi (fiore, cibo, casa, fuoco, pesce, amico).
##
## È lo SPECCHIO che il C++ riceve in sola lettura (`chibi::Gusto`, vedi
## src/sistema_occ.h): il proprietario del dato resta di qua, perché nasce
## dal DNA e dall'indole — che il salone di bellezza e `debug_quirk` possono
## cambiare a partita in corso. Di là c'è una copia, e la si riproietta
## quando i valori CAMBIANO davvero, come si fa già per il DnaComponent.
##
## PERCHÉ ESISTE QUESTO FILE, e non tre righe dentro `Visitors._ciclo_sonno`:
## la formula che dice «quanto ti importa» avrà due consumatori — il cablaggio
## che la spinge nel registro (non ancora scritto: è il passo 6 della Fase 4)
## e il test che pretende che due caratteri diversi si comportino DIVERSAMENTE
## (`tests/cases/test_occ.gd`, che c'è già). Se la formula nascesse dentro il
## cablaggio, il test dovrebbe riscriverla: due copie della stessa formula in
## due posti sono la cosa che questo progetto ha già pagato tre volte (le
## specie, la scala della ribellione, il salvataggio). Qui ce n'è una, e chi
## scriverà `_ciclo_sonno` deve CHIAMARLA, non rifarla.
##
## LA REGOLA CHE VIENE PRIMA DI TUTTE, e sta scritta anche di là: **nessun
## valore negativo**. Un gusto sotto zero vorrebbe dire «mi dà fastidio che
## tu annaffi», cioè contenuto negativo su una persona — che nella Fase 4 non
## esiste per costruzione, non per taratura. Chi non tiene a una cosa ha 0.0
## e quella cosa smette semplicemente di parlargli.
##
## PURA: niente albero della scena, niente stato, niente rng. Si usa come
## `Gusto.da_dna(dna)` previo `const GUSTO := preload(...)`.

const BRAIN := preload("res://scenes/npc/VillagerBrain.gd")

## I NOMI DELLE SEI COSE, nell'ordine dell'enum `chibi::Cosa`
## (src/grafo_ricordi.h). L'ordine È il contratto: l'array che parte da qui
## viene indicizzato di là con `C_FIORE`, `C_CIBO`… Un test lo lega alla
## tabella vera del C++ (COSA_DEL_VERBO) invece di fidarsi di questo commento.
const COSE := ["fiore", "cibo", "casa", "fuoco", "pesce", "amico"]

## Da quali pesi del DNA nasce l'interesse di BASE. Sono i pesi con cui il
## candidato giudica una casa (`ChibiDNA.generate` → `weights`): non è una
## coincidenza che servano anche qui — sono l'unico posto in cui questo gioco
## scrive «ecco a cosa tiene questa creatura», e ricavarne un secondo elenco
## sarebbe inventarsi un secondo carattere per la stessa persona.
## Dove ce n'è più d'uno si fa la media: la casa È il tetto, i muri, la porta
## e la finestra.
const DA_PESO := {
	"fiore": ["garden"],
	"cibo": ["comfort"],
	"casa": ["roof", "walls", "door", "window"],
	"fuoco": ["warmth"],
	"pesce": ["sunny"],
	"amico": ["welcome"],
}

## Il BISOGNO che ogni cosa serve, ed è il ponte con `VillagerBrain.INDOLI`.
## L'indole non ha una sua tabella di gusti: si legge quella che c'è già —
## ogni indole accelera un bisogno con un suo moltiplicatore, e chi ha sempre
## fame guarda con più interesse chi cucina. Aggiungere un'indole di là
## sposta i gusti di qua da sola, senza che nessuno se ne ricordi.
const COSA_DEL_BISOGNO := {
	"pancino": "cibo",
	"energia": "casa",
	"compagnia": "amico",
	"meraviglia": "pesce",
	"cura": "fiore",
}

## Il tetto. Due indoli che spingono la stessa cosa si moltiplicano
## (mattiniero + ordinato fanno 2.34 sui fiori): il tetto non è una taratura
## del carattere, è la sbarra che tiene i numeri in un intervallo raccontabile
## anche se un domani qualcuno alza un moltiplicatore di là. La saturazione
## vera la fa `chibi::valuta` con x/(x+k).
const TETTO := 4.0


## Il gusto di questo DNA, pronto per il ponte. Sei double, nell'ordine di
## COSE. Regge un DNA malmesso: un genoma senza `weights` è neutro (1.0),
## non rotto — è la stessa disciplina di `RiassuntoSalvataggio.da_salvataggio`,
## che da qualunque schifezza tira fuori un villaggio.
##
## L'INDOLE SI PUÒ PASSARE A PARTE, e non è un ornamento della firma: a
## runtime il proprietario dell'indole **non è il genoma, è il cervello**
## (`VillagerBrain.setup` la DERIVA quando il DNA non ce l'ha — cioè per ogni
## villaggio salvato prima che le indoli entrassero nel genoma — e
## `Visitors.debug_quirk` scrive su un cervello vivo). Lo specchio del gusto
## deve seguire la stessa indole che segue la proiezione del sonno
## (`Visitors._ecs_id`), o due copie della stessa persona comincerebbero a
## divergere in silenzio: uno andrebbe a letto da nottambulo e l'altro
## terrebbe ai fiori da mattiniero. Chi non passa niente ottiene il
## comportamento di prima — quella del genoma.
static func da_dna(dna: Dictionary, indole = null) -> PackedFloat64Array:
	var pesi: Dictionary = dna.get("weights", {})
	var out := PackedFloat64Array()
	out.resize(COSE.size())
	for i in COSE.size():
		var cosa := str(COSE[i])
		var chiavi: Array = DA_PESO.get(cosa, [])
		var somma := 0.0
		for k in chiavi:
			somma += maxf(0.0, float(pesi.get(str(k), 1.0)))
		out[i] = somma / float(maxi(1, chiavi.size()))

	var indoli: Array = (dna.get("indole", []) if indole == null else (indole as Array))
	for ind in indoli:
		var voce = BRAIN.INDOLI.get(str(ind), null)
		if voce == null or voce.size() < 3:
			continue
		var cosa := str(COSA_DEL_BISOGNO.get(str(voce[1]), ""))
		var i := COSE.find(cosa)
		if i < 0:
			continue
		out[i] *= maxf(0.0, float(voce[2]))

	for i in out.size():
		out[i] = minf(out[i], TETTO)
	return out
