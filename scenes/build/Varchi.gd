extends RefCounted
## I VARCHI: dove si passa, e dove no.
##
## La Fase 3 chiede al mondo una domanda sola, ed è la sua tesi: **ci
## arrivo?**. Questo file è l'oracolo che risponde, e non ha bisogno di un
## navmesh — la topologia giusta è **già nel salvataggio**, ed è migliore
## di quella che un navmesh ricostruirebbe: i muri di questo gioco non
## stanno dentro le celle, stanno **sui bordi**, con la chiave raddoppiata
## (`BuildSystem.passo_bordo`). Un bordo è letteralmente un arco del grafo,
## e mettere una staccionata è letteralmente tagliarlo. Non c'è niente da
## ricavare: c'è da leggere.
##
## ## Cosa blocca, e perché NON è una tabella
##
## La tentazione era un elenco: «Muro blocca, Porta no». Sarebbe la
## quattordicesima tabella parallela di questo progetto, e le tabelle
## parallele qui hanno già divorziato in silenzio una volta (la scala della
## ribellione). Invece la risposta **si deriva** dall'unico posto in cui
## quella verità vive davvero: le `cols` del catalogo, cioè le scatole di
## collisione che il pezzo pianta per terra.
##
## La regola è una frase: **si passa se resta una luce larga almeno mezzo
## metro, nella fascia in cui un chibi cammina.** Le conseguenze le decide
## la geometria, non io, e sono tutte giuste:
##
## - la Porta e il Portale hanno due stipiti a ±0.42 e in mezzo 0.68 m di
##   niente → **si passa** (ed è per questo che una casa con la porta non
##   diventa una prigione);
## - la Staccionata è una lastra da 0.95 alta 0.95 → **non si passa**, ed è
##   il pezzo con cui il giocatore chiude il recinto;
## - l'Insegna guardia è un palo da 0.14 su un lato → **si passa**, perché
##   un cartello appeso non è un muro;
## - il Casco appeso e la Tenda bar non hanno `cols` affatto → **si passa**,
##   senza che nessuno debba ricordarsi di scriverlo da qualche parte.
##
## Aggiungere domani un pezzo di bordo non richiede di aggiornare questo
## file: se ha una collisione che sbarra la strada, sbarra la strada.
##
## ## L'onestà su cosa questo NON fa
##
## I vicini si muovono con `position += dir * _speed` su un `Node3D`: non
## hanno collisioni, e non le avevano prima di questa fase. Quindi qui NON
## si sta rendendo il muro solido — si sta rendendo il muro **conosciuto**.
## Il vicino che sa di non poter arrivare al cespuglio non ci prova: cambia
## piano.
##
## E adesso **il corpo segue la ROTTA**: `Visitor._walk_to` chiede al
## villaggio (`BuildSystem.deviazione`) la strada che gira attorno, e
## `_process` la percorre tappa per tappa. Vale per TUTTI i cammini — la
## routine, il vagabondaggio, i mestieri — non solo per quelli che qualcuno
## ha pianificato, perché la coda delle tappe sta sotto, dove il corpo
## cammina. Il muro resta attraversabile in un caso, ed è una resa
## dichiarata: quando la strada non esiste si va dritti, che è meglio che
## restare piantati.
##
## ## E il MONDO, non solo i muri
##
## Finché il grafo conosceva soltanto i bordi costruiti, aveva un buco a
## forma di fiume. `BuildSystem.place_cell` **rifiuta** una cella nel letto
## («il letto del fiume resta del fiume»), quindi lì un muro non ci può
## essere: il letto era, per costruzione, il corridoio più sgombro
## dell'intera mappa, e la ricerca ci si infilava dentro ogni volta che
## doveva aggirare un recinto vicino alla riva. Misurato: un vicino che
## doveva fare tre metri ne faceva quasi nove, e per cinque secondi
## camminava sospeso quarantacinque centimetri sopra il pelo dell'acqua.
##
## Adesso la ricerca conosce anche il SUOLO (vedi la classe `Suolo` qui
## sotto, e `CozyWorld.terreno_vietato`), e il patto è preciso:
##
##  · **i pezzi bloccano un BORDO, il mondo toglie una CELLA.** Restano due
##    cose diverse. Un bordo è un arco del grafo; una cella senza pavimento
##    non è quattro muri attorno a un cortile, è un buco.
##  · **si guarda la cella in cui si ARRIVA, mai quella da cui si parte.**
##    Chi si trovasse dentro l'acqua (il ponte, un salvataggio vecchio, il
##    banco di prova) ne può sempre uscire: il degrado va SEMPRE verso «si
##    cammina», e un vicino piantato in mezzo al guado sarebbe il guasto
##    peggiore dei due.
##  · **`componenti()` NON lo guarda**, ed è voluto: vedi la sua nota.

## La fascia in cui cammina un chibi. Sotto `BANDA_BASSA` c'è la soglia di
## una vetrina, che si scavalca; sopra `BANDA_ALTA` c'è la tenda del bar,
## che passa sopra la testa.
const BANDA_BASSA := 0.20
const BANDA_ALTA := 0.80

## Mezzo metro: sotto questo, due stipiti non sono una porta, sono una
## fessura. (La Porta vera ne lascia 0.68.)
const VARCO_MIN := 0.50

## Il tetto del flood fill. Oltre, si smette di rispondere e si dichiara
## tutto raggiungibile: **il degrado va sempre verso «nessuno è in
## trappola»**, perché il guasto opposto — un vicino che si crede murato
## in mezzo al prato — è quello che si vede.
const MAX_CELLE := 32768
const MARGINE := 2

## ---------------------------------------------------- il prezzo di una rotta
##
## `componenti()` si paga una volta per villaggio; `rotta()` si paga **una
## volta per viaggio**, e da quando il corpo segue la strada i viaggi sono
## quelli veri dei vicini. Il prezzo va quindi conosciuto, non sperato — e
## in GDScript è alto: una BFS a quattro vicini esplora un rombo di ~2d²
## celle prima di trovare una meta a distanza d, e **misurato** su questo
## motore fa
##
##   d = 6 celle → 60 µs · d = 28 → 1.9 ms · d = 84 → 17 ms
##
## Un vicino che ricalcola la strada ogni volta che cambia idea, a
## diciassette millisecondi, sarebbe un singhiozzo visibile.
##
## Misurato col tetto scelto, in un villaggio di dieci case murate e cinque
## staccionate: viaggi corti 21 µs di media (p95 133), medi 100 µs (p95
## 545), il caso peggiore visto 2.1 ms. E nel MainLevel con dieci residenti
## VIVI, per trenta secondi: **0.57 domande al secondo**, 0.068 ms al
## secondo in tutto. È il numero che conta, ed è il motivo per cui i
## cancelli di `BuildSystem.deviazione` valgono più di qualunque
## ottimizzazione della ricerca.
##
## Il passaggio del filo da CELLE a PUNTI (vedi `filo_libero`) non ha
## cambiato il conto: rimisurato con `tools/misura_cammino.gd` su mille
## viaggi, un `_walk_to` completo — rotta compresa, e con il 60% dei viaggi
## che una rotta ce l'ha davvero — costa **156 µs contro i 148 di prima**.
## Cinque per cento, per una garanzia che prima non c'era.
##
## ## IL RAGGIO NON C'È PIÙ, ed è la seconda metà della riparazione del falò
##
## C'era un `ROTTA_RAGGIO := 24`: oltre ventiquattro celle, la strada non
## si chiedeva. Sembrava prudenza e invece era una decisione di gioco presa
## da un numero — perché **la radura del falò sta a cinquantasei celle
## dalla piazza**, e ogni sera ventotto vicini attraversavano in fila
## indiana qualunque staccionata avessero davanti, nell'unico evento
## comunitario della giornata.
##
## Alzarlo non bastava: con la BFS in ampiezza una meta a cinquantasei
## celle voleva 5.176 espansioni, e il tetto ne concede 2.048. Togliere il
## raggio è stato possibile solo *dopo* aver reso la ricerca guidata (vedi
## `rotta`). E una volta tolta la BFS, il raggio non serviva più a niente:
##
##  · **il costo NON dipende dalla distanza.** Misurato sui ventotto
##    tragitti veri piazza→falò con una staccionata di traverso: da 232 a
##    546 celle espanse — tutti alla stessa distanza. Quel che fa il
##    prezzo è **quanto sono simili i due giri**, non quanto è lontana la
##    meta.
##  · **il cancello che precede la ricerca è già lineare nella distanza**
##    (`filo_libero` sul segmento vero: 0,18 µs per cella, cioè 10 µs per
##    il falò), quindi non c'è niente da proteggere con una soglia.
##
## Resta **un guardiano solo, ed è quello che misura la spesa vera**. Una
## soglia sulla distanza è per sua natura una lista di posti che il gioco
## smette di considerare, e non lo dice a nessuno.

## Il tetto della ricerca di un VIAGGIO (diverso da `MAX_CELLE`, che è il
## tetto dell'etichettatura): quante celle si possono ESPANDERE. Superato,
## la rotta torna vuota — e vuota vuol dire «cammina dritto come prima»,
## mai «resta fermo».
##
## Duemilaquarantotto è il numero di prima, tenuto: con la ricerca guidata
## il tragitto più caro del gioco (il falò con una staccionata di traverso)
## ne spende 546, quindi c'è quasi il quadruplo di margine per i recinti
## che nessuno ha ancora costruito.
const ROTTA_TETTO := 2048

## LA LUCE ATTORNO A UNO SPIGOLO: quanto deve tenersi largo un filo che
## passa vicino al punto in cui quattro celle si toccano, prima che quel
## passaggio venga giudicato «per lo spigolo» (e quindi debba avere tutti e
## due i giri aperti).
##
## Il numero non è di gusto, è **misurato sul pezzo**. La Staccionata
## (`BuildCatalog._fence`) ha i due correnti che arrivano **a filo del
## bordo**, ±0.5, e li chiude con una pallina di raggio 0.030 centrata
## ESATTAMENTE sullo spigolo, ad altezze 0.315 e 0.585 — cioè in mezzo alla
## fascia in cui cammina un chibi. Un filo che passasse a tre centimetri
## dallo spigolo, nel grafo, sarebbe libero; addosso a un corpo passerebbe
## dentro il legno.
##
## Dieci centimetri lasciano al corpo almeno cinque centimetri di aria dal
## corrente nel caso peggiore (il filo a quarantacinque gradi), e molti di
## più in tutti gli altri. E servono anche a una seconda cosa, meno
## romantica e altrettanto necessaria: **l'aritmetica**. Un filo teso passa
## per gli spigoli veri per costruzione, e in virgola mobile «esattamente
## sullo spigolo» diventa «a 10⁻¹⁶ dallo spigolo» — cioè da una parte o
## dall'altra a caso. Una fascia larga un decimo di cella toglie di mezzo
## la questione: dentro la fascia si decide sempre allo stesso modo.
const SPIGOLO_LUCE := 0.14


# ------------------------------------------------------------ il bordo

## La LUCE di un bordo: quanti metri di passaggio restano liberi, dentro la
## fascia di cammino. Pura: legge le `cols` del catalogo e basta.
##
## Il bordo è largo 1 m e le scatole sono in coordinate locali del pezzo
## (x lungo il bordo, y in alto, z attraverso). Il ribaltamento (`flip`) è
## uno specchio su x e non cambia la luce più larga: la funzione è perciò
## invariante al verso, come deve essere.
static func luce(cols: Array) -> float:
	var occupati: Array[Vector2] = []
	for c in cols:
		if c.size() < 2:
			continue
		var mis: Vector3 = c[0]
		var pos: Vector3 = c[1]
		# una scatola inclinata (terzo elemento: rotazione su X) alza il
		# proprio ingombro verticale: si tiene il caso peggiore
		var mezza_y := mis.y * 0.5
		if c.size() > 2 and absf(float(c[2])) > 1e-6:
			var rx := float(c[2])
			mezza_y = absf(cos(rx)) * mis.y * 0.5 + absf(sin(rx)) * mis.z * 0.5
		if pos.y + mezza_y <= BANDA_BASSA or pos.y - mezza_y >= BANDA_ALTA:
			continue  # tutta sotto la soglia, o tutta sopra la testa
		var a := clampf(pos.x - mis.x * 0.5, -0.5, 0.5)
		var b := clampf(pos.x + mis.x * 0.5, -0.5, 0.5)
		if b > a:
			occupati.append(Vector2(a, b))
	if occupati.is_empty():
		return 1.0
	occupati.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
	var piu_larga := 0.0
	var x := -0.5
	for iv in occupati:
		if iv.x > x:
			piu_larga = maxf(piu_larga, iv.x - x)
		x = maxf(x, iv.y)
	return maxf(piu_larga, 0.5 - x)


## Si passa?
static func e_varco(cols: Array) -> bool:
	return luce(cols) >= VARCO_MIN


## Il bordo (chiave raddoppiata) fra due celle adiacenti. Simmetrica:
## `bordo_fra(a, b) == bordo_fra(b, a)`.
static func bordo_fra(a: Vector2i, b: Vector2i) -> Vector2i:
	return a * 2 + (b - a)


## IL SUOLO: quali celle non hanno un pavimento su cui posare le zampe.
##
## Non è una tabella e non è un secondo grafo: è **una memoria**. La verità
## la dice il mondo (`CozyWorld.terreno_vietato`, che sa dov'è il fiume, lo
## stagno e la parete), e questa classe si limita a non chiederglielo due
## volte per la stessa cella.
##
## ## Perché una memoria che non scade mai
##
## Perché il terreno non si muove. Il fiume di stasera è quello di
## stamattina: nessun gesto del giocatore lo sposta — al contrario, è il
## giocatore che non ci può costruire. Un dato che non cambia si chiede una
## volta e basta, e il tetto della memoria è il numero di celle che il
## villaggio ha davvero visitato in tutta la partita (misurato: **998**
## celle dopo la sera del falò con ventotto ricerche vere, cioè una
## manciata di kB).
##
## Il conto della spesa è `domande`: se qualcuno domani rendesse il terreno
## mutevole e cominciasse a invalidare la memoria, quel numero glielo
## direbbe subito. La stessa sera, con un quaderno nuovo per ogni vicino,
## costerebbe **14.695** domande al mondo invece di 998.
class Suolo:
	extends RefCounted

	var _chiedi: Callable
	## IL QUADERNO, e sta APERTO. `passa()` lo legge di suo invece di
	## chiamare `vietata()`, e non è sciatteria: in GDScript una chiamata di
	## funzione costa più di una domanda a dizionario, e questo quaderno si
	## legge quattro volte per ogni cella che la ricerca espande. Misurato
	## sul tragitto del falò, togliendo quella chiamata (e srotolando
	## `bordo_fra` dentro `passa`): la ricerca da **863 a 784 µs**, il filo
	## teso da **676 a 527** — il quindici per cento del conto, per due
	## righe. Chi scrive qui dentro da fuori rompe tutto: si scrive solo in
	## `vietata()`.
	var memo := {}
	## Quante volte si è dovuto disturbare il mondo. Per la misura, non per
	## la logica.
	var domande := 0

	func _init(chiedi := Callable()) -> void:
		_chiedi = chiedi

	## Vietata? Senza oracolo, MAI: un suolo che non sa niente lascia
	## camminare dappertutto, che è il comportamento di prima di conoscere
	## il mondo (e il degrado va sempre verso «si cammina»).
	func vietata(c: Vector2i) -> bool:
		var v = memo.get(c)
		if v != null:
			return v
		var r := false
		if _chiedi.is_valid():
			domande += 1
			r = bool(_chiedi.call(c))
		memo[c] = r
		return r

	## C'è un mondo a cui chiedere? Un suolo senza oracolo non vieta niente
	## e non è un errore — fuori dal villaggio (il bosco, il prologo, il
	## diorama del menù) è la risposta giusta. Ma chi lo tiene in cache deve
	## poter distinguere «non c'è niente da vietare» da «non l'ho ancora
	## chiesto a nessuno».
	func sa_qualcosa() -> bool:
		return _chiedi.is_valid()

	## Quante celle si ricorda. Per la misura.
	func ricordate() -> int:
		return memo.size()


## SI PASSA da `a` a `b`?
##
## Due domande diverse in una riga sola: il **bordo** fra le due celle non
## dev'essere murato (i pezzi costruiti), e la cella in cui si **arriva**
## dev'essere terreno buono (il mondo). Mai quella da cui si parte — vedi la
## nota in testa al file: da un guado si deve poter uscire.
##
## È l'anello più caldo del villaggio: la ricerca la chiama quattro volte
## per ogni cella che espande, il filo teso una volta per ogni cella che
## attraversa. Per questo `bordo_fra` è srotolata qui dentro (è la stessa
## riga: `a*2 + (b−a)`) e il quaderno del suolo si legge diretto,
## chiamando `vietata()` solo quando la cella è nuova. Sono le uniche due
## libertà che si prende, e `test_varchi` le tiene inchiodate alle
## funzioni da cui vengono.
static func passa(muri: Dictionary, a: Vector2i, b: Vector2i,
		suolo: Suolo = null) -> bool:
	if muri.has(a * 2 + (b - a)):
		return false
	if suolo == null:
		return true
	var v = suolo.memo.get(b)
	if v == null:
		return not suolo.vietata(b)
	return not v


## LA CELLA DI UN PUNTO, in metri di mondo (x, z). Una riga sola, e sta
## qui: è la conversione che lega il corpo al grafo, e il filo continuo qui
## sotto deve usare **la stessa**. Due arrotondamenti diversi fra chi
## cammina e chi giudica sono la stessa specie di guasto delle tabelle
## parallele — silenzioso, e visibile solo di sguincio.
static func cella(p: Vector2) -> Vector2i:
	return Vector2i(roundi(p.x), roundi(p.y))


const INTORNO: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
]


# ------------------------------------------------------- le componenti

## Etichetta ogni cella con la sua **isola**. Zero è IL FUORI: il prato
## grande, che non ha muri e in cui tutto si tocca. Un'isola con etichetta
## ≥ 1 è un posto chiuso — un cortile, una stanza, un recinto.
##
## Si etichetta una volta sola per ogni cambio del villaggio, non una volta
## per domanda: il fill parte da un anello **fuori** dalla scatola dei muri,
## e tutto quello che l'anello raggiunge è il fuori. Quello che resta
## dentro e non è stato toccato è chiuso, e prende un'etichetta sua.
##
## Ritorna `{"celle": {Vector2i: int}, "isole": int, "troncato": bool}`, e
## in `celle` ci sono **soltanto i posti chiusi**: le celle assenti valgono
## zero, cioè il fuori è il default. Non è un'ottimizzazione furba, è la
## forma giusta — il prato è quasi tutto, e ricordarselo cella per cella
## vorrebbe dire tenere in memoria un villaggio intero per descrivere il
## niente. Un mondo senza recinti produce un dizionario vuoto.
##
## ## QUI IL MONDO NON ENTRA, ed è una decisione
##
## La rotta conosce il fiume; l'etichettatura no. Non è una dimenticanza:
## sono due domande diverse.
##
##  · La rotta chiede **«dove metto le zampe»**, e il fiume conta perché è
##    un buco nel pavimento.
##  · `componenti()` chiede **«mi hanno chiuso dentro?»**, e la risposta
##    finisce in `raggiungibile()`, che è l'oracolo con cui un vicino
##    decide di RINUNCIARE a un posto (`Visitors._nearest_named`,
##    `Piani`). Il fiume non è una porta che qualcuno ha chiuso: è
##    attraversato da due ponti che vivono nella geometria del mondo e non
##    in questo grafo. Metterlo qui dichiarerebbe **prigioniera l'intera
##    riva est** — e un vicino che si crede murato in mezzo al prato è
##    esattamente il guasto che `MAX_CELLE` esiste per non commettere.
##
## Il residuo, dichiarato: un recinto che si appoggia alla riva non viene
## riconosciuto come chiusura (l'acqua sembra un'uscita). Chi ci abita
## crede di poter arrivare al cespuglio, ci si incammina, la rotta non
## trova strada e va dritto attraverso la staccionata — cioè la resa che
## c'era già ed è scritta in testa al file. È il guasto MITE dei due, e si
## sceglie sempre quello.
static func componenti(muri: Dictionary) -> Dictionary:
	var vuoto := {"celle": {}, "isole": 0, "troncato": false}
	if muri.is_empty():
		return vuoto
	var lo := Vector2i(1 << 30, 1 << 30)
	var hi := Vector2i(-(1 << 30), -(1 << 30))
	for k: Vector2i in muri:
		for cell in _celle_del_bordo(k):
			lo.x = mini(lo.x, cell.x)
			lo.y = mini(lo.y, cell.y)
			hi.x = maxi(hi.x, cell.x)
			hi.y = maxi(hi.y, cell.y)
	lo -= Vector2i(MARGINE, MARGINE)
	hi += Vector2i(MARGINE, MARGINE)
	var larghezza := hi.x - lo.x + 1
	var altezza := hi.y - lo.y + 1
	if larghezza * altezza > MAX_CELLE:
		# villaggio enorme: si rinuncia, e si rinuncia DICHIARANDO che tutto
		# è raggiungibile (vedi MAX_CELLE)
		vuoto["troncato"] = true
		return vuoto

	var visti := {}
	var celle := {}
	# 1) IL FUORI. Si semina da tutto il bordo della scatola: quell'anello è
	#    per costruzione oltre l'ultimo muro, quindi è prato aperto.
	var coda: Array[Vector2i] = []
	for x in range(lo.x, hi.x + 1):
		coda.append(Vector2i(x, lo.y))
		coda.append(Vector2i(x, hi.y))
	for y in range(lo.y + 1, hi.y):
		coda.append(Vector2i(lo.x, y))
		coda.append(Vector2i(hi.x, y))
	for c in coda:
		visti[c] = true
	_espandi(muri, visti, celle, coda, 0, lo, hi)

	# 2) LE ISOLE. Quel che il fuori non ha toccato è chiuso, e SOLO questo
	#    si ricorda.
	var isole := 0
	for y in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			var c := Vector2i(x, y)
			if visti.has(c):
				continue
			isole += 1
			visti[c] = true
			celle[c] = isole
			var semi: Array[Vector2i] = [c]
			_espandi(muri, visti, celle, semi, isole, lo, hi)
	return {"celle": celle, "isole": isole, "troncato": false}


static func _espandi(muri: Dictionary, visti: Dictionary, celle: Dictionary,
		coda: Array[Vector2i], etichetta_: int, lo: Vector2i, hi: Vector2i) -> void:
	var i := 0
	while i < coda.size():
		var c: Vector2i = coda[i]
		i += 1
		for d in INTORNO:
			var n: Vector2i = c + d
			if n.x < lo.x or n.x > hi.x or n.y < lo.y or n.y > hi.y:
				continue
			if visti.has(n):
				continue
			if not passa(muri, c, n):
				continue
			visti[n] = true
			if etichetta_ != 0:
				celle[n] = etichetta_
			coda.append(n)


static func _celle_del_bordo(key: Vector2i) -> Array[Vector2i]:
	if posmod(key.y, 2) == 1:
		@warning_ignore("integer_division")
		var cy := (key.y - 1) / 2
		@warning_ignore("integer_division")
		return [Vector2i(key.x / 2, cy), Vector2i(key.x / 2, cy + 1)]
	@warning_ignore("integer_division")
	var cx := (key.x - 1) / 2
	@warning_ignore("integer_division")
	return [Vector2i(cx, key.y / 2), Vector2i(cx + 1, key.y / 2)]


## L'isola di una cella. Fuori dalla scatola dei muri è sempre il fuori.
static func isola(mappa: Dictionary, cell: Vector2i) -> int:
	return int((mappa.get("celle", {}) as Dictionary).get(cell, 0))


## LA DOMANDA DELLA FASE 3. Due punti si toccano se stanno sulla stessa
## isola. Niente ricerca, niente costo: un confronto fra due interi.
static func raggiungibile(mappa: Dictionary, da: Vector2i, a: Vector2i) -> bool:
	return isola(mappa, da) == isola(mappa, a)


# ------------------------------------------------------------ la rotta

## La distanza di Manhattan: il numero di passi che servirebbero in campo
## libero. È la stima che guida la ricerca, ed è **ammissibile** (non
## promette mai meno del vero: i passi costano uno e sono quattro) e
## **consistente** (fra due celle vicine cambia di uno esatto). Da quelle
## due proprietà discende che il primo cammino trovato è il più corto.
static func manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## La strada vera fra due celle, che gira attorno ai muri e sta lontana
## dall'acqua. Quattro vicini: un chibi non sguscia per lo spigolo fra due
## staccionate che si toccano, e infilarlo lì sarebbe l'unico modo di
## attraversare un recinto chiuso. Ritorna le celle da percorrere, estremi
## compresi; **vuota** se non c'è strada o se si è speso il tetto — e vuota
## vuol dire «cammina dritto come prima», mai «resta fermo».
##
## ## Perché non è più una BFS in ampiezza
##
## Perché il falò. La radura sta a cinquantasei celle dalla piazza, ed è
## l'unico evento comunitario quotidiano — quello che si guarda per
## intero. Una BFS che cerca a cinquantasei celle esplora il rombo intero
## prima di trovarla, cioè ~2·d² celle, e il tetto di un viaggio ne
## concede duemila: la strada non si sarebbe trovata MAI. Il risultato era
## che il raggio della rotta (24 celle) escludeva il falò per forza, e ogni
## sera ventotto vicini attraversavano in fila indiana qualunque
## staccionata avessero davanti.
##
## Qui la ricerca è guidata dalla distanza che manca (A\*), e il conto
## cambia di categoria: si esplora **il rettangolo fra i due punti** invece
## del rombo attorno alla partenza. Misurato sul tragitto vero piazza→falò
## con una staccionata da quindici campate di traverso: **354 celle
## espanse contro 5.176, 0,8 ms contro 20 — e la BFS, col tetto vero,
## quelle 5.176 non le ha nemmeno, quindi torna a mani vuote.** La strada
## trovata è lunga uguale (65 celle contro 65): la guida non fa sconti
## sulla lunghezza, e `test_varchi` lo verifica su duecento villaggi a caso
## contro una BFS scritta apposta.
##
## ## La coda a SECCHI (e perché non serve un mucchio binario)
##
## I passi costano tutti uno e la stima è intera, quindi `f = g + h` è un
## intero e cambia **di zero o di due** a ogni passo (avvicinarsi tiene f,
## allontanarsi la alza di due). Una coda di priorità con un ordinamento
## generale sarebbe sprecata: basta un secchio per ogni valore di `f` e un
## indice che sale, e ogni inserimento costa quanto un `append`. È l'idea
## di Dial, e su una griglia a passo unitario è esatta.
##
## `tetto` conta le celle **espanse** (non le viste): è il numero che si
## paga davvero.
static func rotta(muri: Dictionary, da: Vector2i, a: Vector2i,
		tetto := MAX_CELLE, suolo: Suolo = null) -> Array[Vector2i]:
	var vuota: Array[Vector2i] = []
	if da == a:
		return [da] as Array[Vector2i]
	var padre := {da: da}
	var costo := {da: 0}
	var chiusi := {}
	var f := manhattan(da, a)
	var f_max := f + 2 * tetto
	var primo: Array[Vector2i] = [da]
	var secchi := {f: primo}
	var vivi := 1
	var espansi := 0
	while vivi > 0 and espansi < tetto and f <= f_max:
		var lista = secchi.get(f)
		if lista == null or (lista as Array).is_empty():
			secchi.erase(f)
			f += 2       # la parità di f non cambia mai: si salta di due
			continue
		var c: Vector2i = (lista as Array).pop_back()
		vivi -= 1
		if chiusi.has(c):
			continue     # voce vecchia: quella cella è già stata spesa meglio
		chiusi[c] = true
		espansi += 1
		if c == a:
			var giu: Array[Vector2i] = [a]
			var cur := a
			while cur != da:
				cur = padre[cur]
				giu.append(cur)
			giu.reverse()
			return giu
		var g: int = costo[c] + 1
		for d in INTORNO:
			var n: Vector2i = c + d
			if chiusi.has(n):
				continue
			# le due domande a dizionario PRIMA di quella al mondo: la
			# maggior parte dei vicini viene scartata senza disturbare
			# nessuno
			var vecchio = costo.get(n)
			if vecchio != null and int(vecchio) <= g:
				continue
			if not passa(muri, c, n, suolo):
				continue
			costo[n] = g
			padre[n] = c
			var fn: int = g + manhattan(n, a)
			var s = secchi.get(fn)
			if s == null:
				var nuovo: Array[Vector2i] = [n]
				secchi[fn] = nuovo
			else:
				(s as Array).append(n)
			vivi += 1
	return vuota


## TIRA IL FILO, SUI PUNTI VERI (metri di mondo, x e z).
##
## ## Perché in metri, e non più in celle
##
## Una rotta a quattro vicini è una scaletta, e un vicino che cammina a
## scaletta sembra un carrello elevatore: si tiene una tappa solo quando
## toglierla farebbe passare il filo dentro un muro. Fin qui, come prima.
##
## Quello che è cambiato è **su cosa** si tira. Finché il filo si tirava
## fra centri di cella, il villaggio giudicava una spezzata e il corpo ne
## camminava un'altra: partiva da dov'era (non dal centro della sua cella)
## e finiva sul punto chiesto (non sul centro dell'ultima). Gli estremi
## sbagliati sono mezzo metro, e mezzo metro basta a mandare dall'altra
## parte di un muro una gamba di filo che — per costruzione — gli
## rasentava lo spigolo. Misurato, su mille viaggi in un villaggio con una
## casa e due staccionate: 36 viaggi attraversavano un muro, 25 nella
## PRIMA tratta e 7 nell'ULTIMA.
##
## Adesso gli estremi veri sono nel filo, e ogni gamba che il corpo
## cammina è una gamba che è stata giudicata. Non è una costante tarata
## meglio: è la stessa spezzata.
##
## ## La spina dorsale dev'essere libera per costruzione
##
## Questo algoritmo **non verifica le gambe che tiene**, verifica solo le
## scorciatoie: quando la scorciatoia non passa, ripiega sul punto
## precedente della lista che gli è stata data. Quindi chi la costruisce
## deve garantire che ogni coppia CONSECUTIVA sia libera — e
## `BuildSystem.rotta_mondo` lo fa nel solo modo che si dimostra: punto
## vero → centro della propria cella (si resta dentro una cella, nessun
## confine attraversato), poi centri di celle adiacenti col bordo aperto,
## poi centro dell'ultima cella → punto vero.
static func tira_filo_mondo(muri: Dictionary, punti: Array[Vector2],
		suolo: Suolo = null) -> Array[Vector2]:
	if punti.size() <= 2:
		return punti.duplicate()
	var fuori: Array[Vector2] = [punti[0]]
	var ancora := 0
	var i := 1
	while i < punti.size():
		if not filo_libero(muri, punti[ancora], punti[i], suolo):
			# la scorciatoia non passa: si tiene il punto prima. (Il
			# confronto tiene fuori la tappa doppia, che darebbe al corpo una
			# gamba lunga zero — e una direzione indefinita.)
			if punti[i - 1].distance_squared_to(fuori[fuori.size() - 1]) > 1e-12:
				fuori.append(punti[i - 1])
			ancora = i - 1
		i += 1
	fuori.append(punti[punti.size() - 1])
	return fuori


## Lo stesso filo, sulle celle. Delega — non riscrive: le celle sono punti
## a coordinate intere, e il filo è uno solo.
static func tira_filo(muri: Dictionary, celle: Array[Vector2i],
		suolo: Suolo = null) -> Array[Vector2i]:
	var punti: Array[Vector2] = []
	for c in celle:
		punti.append(Vector2(c))
	var fuori: Array[Vector2i] = []
	for p in tira_filo_mondo(muri, punti, suolo):
		fuori.append(cella(p))
	return fuori


## LA RETTA BASTA? — cioè: **fra questi due punti del mondo, un corpo che
## va dritto attraversa un muro?**
##
## È la domanda che si fa il villaggio prima di ogni viaggio, ed è anche
## quella che tiene su il filo teso qui sopra: una sola implementazione,
## mai due. Costa una passata lineare (decine di µs) contro i
## millisecondi di una BFS, e nel villaggio vero la risposta è quasi
## sempre «sì, basta»: è per questo che ventotto vicini possono girare
## attorno ai muri senza che il gioco singhiozzi.
##
## ## Come si percorre, e perché non si campiona
##
## Non si campiona il segmento a passetti: si calcola **quando** attraversa
## ogni confine. I confini stanno sui mezzi interi, quindi da un punto
## qualunque il prossimo confine verticale è a distanza nota e i successivi
## a un metro l'uno dall'altro — la traversata di griglia classica. Un
## passo per cella attraversata invece di venti campioni, e nessuna
## domanda che dipende da dove sono caduti i campioni.
##
## La prima stesura di questo file campionava ogni 5 cm, e sbagliava
## esattamente dove conta: sugli SPIGOLI. Che il campionamento vedesse
## «due passi dritti» o «un passo in diagonale» dipendeva dal caso, e il
## corpo — che campiona a 2 cm a frame — ne vedeva un'altra ancora. La
## seconda stesura era aritmetica intera esatta, e risolveva quello ma
## sapeva rispondere **solo su coordinate intere**: cioè su una spezzata
## che il corpo non camminava.
##
## ## Il passaggio per lo SPIGOLO
##
## La scelta ovvia sbaglia da tutt'e due i lati: rifiutarlo sempre lascia i
## vicini a camminare a gradini; accettarlo sempre li fa sgusciare per lo
## spigolo fra due staccionate, cioè attraverso il recinto chiuso. La
## regola è: **si passa per lo spigolo solo se tutti e due i giri sono
## aperti**, che vuol dire «su quello spigolo non c'è nessun palo». In
## campo libero lo sono sempre — ed è per questo che il filo si tende
## dritto e non a scaletta.
##
## «Per lo spigolo» non è più solo «esattamente sul punto»: è **dentro
## `SPIGOLO_LUCE`** (vedi lassù il perché, che è mezzo di legno e mezzo di
## virgola mobile). I due confini si attraversano a due istanti; se quei
## due istanti distano meno della fascia, è lo stesso spigolo.
##
## ## E il SUOLO
##
## Con un `suolo`, la domanda diventa «un corpo che va dritto attraversa un
## muro **o mette una zampa dove il pavimento non c'è**?». Si guarda la
## cella in cui si ENTRA, mai quella di partenza (vedi la nota in testa al
## file). È quello che rende sicure le scorciatoie del filo teso: senza,
## una gamba tirata da un capo all'altro di una rotta pulita poteva
## rientrare nell'acqua che la rotta aveva appena schivato.
static func filo_libero(muri: Dictionary, p0: Vector2, p1: Vector2,
		suolo: Suolo = null) -> bool:
	var d := p1 - p0
	var sx := 0
	var sy := 0
	if absf(d.x) > 1e-12:
		sx = 1 if d.x > 0.0 else -1
	if absf(d.y) > 1e-12:
		sy = 1 if d.y > 0.0 else -1
	if sx == 0 and sy == 0:
		return true
	var cur := cella(p0)
	# `t` è la frazione di segmento percorsa. `tx` è quando si attraversa il
	# prossimo confine verticale, `dtx` quanto ne passa fra uno e il
	# successivo; oltre 1.0 il segmento è finito.
	var tx := INF
	var dtx := INF
	if sx != 0:
		tx = (float(cur.x) + 0.5 * sx - p0.x) / d.x
		dtx = 1.0 / absf(d.x)
	var ty := INF
	var dty := INF
	if sy != 0:
		ty = (float(cur.y) + 0.5 * sy - p0.y) / d.y
		dty = 1.0 / absf(d.y)
	# la fascia dello spigolo, portata da metri a frazioni di segmento
	var fascia := SPIGOLO_LUCE / maxf(d.length(), 1e-9)
	while tx <= 1.0 or ty <= 1.0:
		if sx != 0 and sy != 0 and absf(tx - ty) <= fascia:
			# LO SPIGOLO: si passa solo se non c'è nessun palo, di qua né di là
			var n := cur + Vector2i(sx, sy)
			var b := cur + Vector2i(sx, 0)
			var c := cur + Vector2i(0, sy)
			if not (passa(muri, cur, b, suolo) and passa(muri, b, n, suolo)):
				return false
			if not (passa(muri, cur, c, suolo) and passa(muri, c, n, suolo)):
				return false
			cur = n
			tx += dtx
			ty += dty
		elif tx < ty:
			var n2 := cur + Vector2i(sx, 0)
			if not passa(muri, cur, n2, suolo):
				return false
			cur = n2
			tx += dtx
		else:
			var n3 := cur + Vector2i(0, sy)
			if not passa(muri, cur, n3, suolo):
				return false
			cur = n3
			ty += dty
	return true


## Lo stesso filo, fra due celle. Delega: i centri di cella sono punti come
## gli altri.
static func filo_libero_celle(muri: Dictionary, da: Vector2i, a: Vector2i,
		suolo: Suolo = null) -> bool:
	return filo_libero(muri, Vector2(da), Vector2(a), suolo)


## La lunghezza in metri di una rotta (le celle sono un metro).
static func lunghezza(celle: Array[Vector2i]) -> float:
	var d := 0.0
	for i in range(1, celle.size()):
		d += Vector2(celle[i] - celle[i - 1]).length()
	return d
