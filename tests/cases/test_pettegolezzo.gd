extends RefCounted
## IL PETTEGOLEZZO — quello che uno ha visto arriva a chi non c'era
## (Fase 4, passo 5).
##
## La scena da cui si progetta all'indietro: Mochi regala un piatto a Nino
## nel bosco; Pina, unica testimone, gira la testa. Venti minuti dopo Pina
## incrocia Ada al falò e nella sua nuvoletta esce il simbolo del cibo —
## perché è quello che ha visto. Il giorno dopo Ada, **che non c'era**,
## saluta Mochi con lo stesso simbolo.
##
## Perché la scena funzioni devono essere vere quattro cose insieme, e tre
## di loro sono NEGATIVE: sono le cose che il sistema deve rifiutarsi di
## fare, e nessuna di loro produrrebbe un errore il giorno che si rompe.
##
##  1. **UNA COSA FUORI POSTO, MAI DUE.** Nel passaggio si perde il
##     SOGGETTO: Ada sa che qualcuno ha ricevuto un regalo, non chi. Il
##     verbo, la cosa e il luogo passano INTATTI — se si deformasse anche
##     uno solo di quelli, il simbolo in fondo alla catena non
##     significherebbe più niente, e un pettegolezzo che non significa
##     niente non è un pettegolezzo: è rumore. (Il difetto non si vedrebbe
##     mai come un errore: si vedrebbe come «i vicini dicono cose a caso»,
##     che è precisamente il danno permanente del Taccuino del Gufo — una
##     conseguenza senza premessa non attenua l'effetto, lo INVERTE.)
##
##  2. **UNA NOTIZIA NON È UN BROADCAST.** Da chi l'ha solo sentita non
##     riparte, e chi l'ha raccontata non la ripete. Misurato: ventotto
##     vicini, trenta minuti, cinquecento chiacchierate, UN fatto seminato
##     → lo sanno in DUE. Se lo sapessero tutti e ventotto, «l'ho colto»
##     diventerebbe «me l'hanno annunciato», e la magia sta tutta
##     nell'averlo colto.
##
##  3. **IL SILENZIO NON BRUCIA LA NOTIZIA.** Se l'altro la sa già non si
##     dice niente e non si marchia niente: la notizia resta in tasca per
##     il prossimo che non la sa. Il guasto opposto — bruciarla al primo
##     incontro — vuol dire che basta incontrare per primo qualcuno che ha
##     visto la stessa cosa perché quella notizia non la sappia mai più
##     nessuno.
##
##  4. **LO SMORZAMENTO SI PAGA UNA VOLTA SOLA.** `sistema_occ` sa smorzare
##     una voce in due posti (l'intensità nel dato, `peso_sentito` nella
##     lettura) e il piano della Fase 4 li nominava tutti e due senza
##     scegliere. Applicarli insieme fa 0.55 × 0.55 = 0.30 e non lo dice
##     nessuno: i numeri restano plausibili. Qui si misura il rapporto e si
##     pretende 0.55, non 0.30.

const DT := 1.0 / 60.0
const VILLAGGIO := preload("res://scenes/npc/Villaggio.gd")
## `racconta(a, b)` è asimmetrica per contratto, e chi sono `a` e `b` NON lo
## decide questo file: lo decide il villaggio. Perciò il verso, qui dentro,
## arriva sempre da `Visitors.scegli_chiacchiera` — la stessa funzione che
## gira in partita.
const VISITORS := preload("res://scenes/npc/Visitors.gd")

## Le tre bandiere e il soggetto nullo arrivano dal BINARIO, mai scritti a
## mano: un test che scrive «2» per R_SU_DI_ME resta verde il giorno che le
## bandiere cambiano valore.
var _sentito := 0
var _a_me := 0
var _detto := 0
var _nessuno := 0


func run(t) -> void:
	# GUARDIA DURA, non molle: se la GDExtension non è caricata questo test
	# deve essere ROSSO. Un `return` silenzioso direbbe «tutto bene» a un
	# villaggio senza cuore.
	if not ClassDB.class_exists("EcsMondo"):
		t.ok(false, "EcsMondo non registrata: la GDExtension non è caricata")
		return
	var m = ClassDB.instantiate("EcsMondo")
	if not m.has_method("racconta"):
		t.ok(false, "EcsMondo non espone «racconta»: il passaparola non è nel binario")
		m.free()
		return
	var c: Dictionary = m.debug_grafo_costanti()
	_sentito = int(c["r_sentito"])
	_a_me = int(c["r_su_di_me"])
	_detto = int(c["r_detto"])
	_nessuno = int(c["sogg_nessuno"])

	_osserva_incide(t, m)
	_la_ricevuta_e_su_di_me(t, m)
	_la_fusione_vale_anche_dal_vivo(t, m)
	_una_cosa_fuori_posto(t, m)
	_lo_smorzamento_si_paga_una_volta(t, m)
	_la_voce_non_risorge(t, m)
	_un_eco_spenta_non_tappa_la_notizia_fresca(t, m)
	_da_chi_l_ha_sentita_non_riparte(t, m)
	_chi_l_ha_raccontata_non_la_ripete(t, m)
	_cio_che_sa_gia_non_si_ripassa(t, m)
	_il_silenzio_non_brucia_la_notizia(t, m)
	_non_si_racconta_a_se_stessi(t, m)
	_e_deterministico(t, m)
	_la_novita_si_chiede_da_sola(t, m)
	_una_notizia_non_e_un_broadcast(t, m)
	_ma_il_pettegolezzo_e_vivo(t, m)
	_la_coppia_non_la_sceglie_l_anagrafe(t)
	_chi_apre_bocca_e_una_monetina(t)
	_senza_nessuno_a_portata_non_si_chiacchiera(t)
	_nessuno_resta_muto(t, m)
	_dove_muore_il_cervello_muore_l_entita(t, m)
	m.free()


# ------------------------------------------------------------------ ferri

func _righe(m, id: int) -> Array:
	return m.debug_grafo(id)["ricordi"] as Array


## Il ricordo di `id` che parla di quel verbo, o {} se non c'è.
func _ricordo_di(m, id: int, verbo: int) -> Dictionary:
	for r in _righe(m, id):
		if int(r["verbo"]) == verbo:
			return r
	return {}


func _sa(m, id: int, verbo: int) -> bool:
	return not _ricordo_di(m, id, verbo).is_empty()


## CHI PARLA E CHI ASCOLTA, chiesto al VILLAGGIO.
##
## Il sorteggio della coppia, nei banchi qui sotto, è la GEOMETRIA: chi
## incontra chi. In un banco senza corpi non c'è altro modo di dirlo, e non
## è quello il soggetto. Il VERSO invece — l'unica cosa che `racconta`
## legge, perché A parla e B ascolta — non si sorteggia qui: lo dà
## `Visitors.scegli_chiacchiera`, la stessa funzione che gira in partita.
##
## ⚠️ PRIMA QUESTI BANCHI TIRAVANO `a` E `b` CON DUE `randi_range`
## INDIPENDENTI, cioè modellavano un canale SIMMETRICO che in partita non
## esisteva: `_chats` chiamava `_run_chat(a, b)` con sempre i < j. Sessanta-
## duemila asserzioni restavano verdi su un villaggio in cui l'ultimo
## dell'anagrafe non raccontava niente a nessuno.
func _verso(a: int, b: int, rng: RandomNumberGenerator) -> Vector2i:
	return VISITORS.scegli_chiacchiera(
			[Vector2i(mini(a, b), maxi(a, b))], rng)


# ------------------------------------------------------------------ i casi

## HA VISTO. `osserva` è l'unica porta d'ingresso della memoria in partita,
## e quel che incide dev'essere esattamente il gesto: il verbo che le è
## stato detto, la cosa che la tabella unica gli assegna, il posto dove è
## successo. Il verbo sbagliato si RIFIUTA (e lo dice): il bus della
## percezione traduce una parola in un indice, e una parola sbagliata di là
## dev'essere un errore visibile, non un gesto che nessuno ha mai visto.
func _osserva_incide(t, m) -> void:
	var id: int = m.registra(PackedStringArray([]), "")
	var v: int = m.indice_verbo("pesca")
	var i: int = m.osserva(id, v, Vector3(3.5, 9.0, -7.25), -1)
	t.eq(i, 0, "il primo ricordo va nella prima riga")
	var r := _ricordo_di(m, id, v)
	t.ok(not r.is_empty(), "e il ricordo c'è")
	t.eq(int(r["cosa"]), m.indice_cosa("pesce"),
			"la cosa la decide la tabella unica, non chi chiama")
	t.almost(float(r["px"]), 3.5, "il posto è quello del gesto (x)", 1e-6)
	t.almost(float(r["pz"]), -7.25, "…e la sua z (la y non serve: il villaggio è piano)", 1e-6)
	t.eq(int(r["intensita"]), 255,
			"chi vede con i propri occhi vede al massimo: l'unica cosa che smorza è il passaparola")
	t.eq(int(r["quante"]), 1, "una volta sola, per ora")
	t.eq(int(r["soggetto"]), _nessuno, "e non era per nessuno")
	t.eq(int(r["bandiere"]), 0, "né sentito, né raccontato, né per me")

	# un verbo che non esiste non entra, e lo dice
	var prima := _righe(m, id).size()
	t.eq(m.osserva(id, 99, Vector3.ZERO, -1), -1, "un verbo fuori tabella si rifiuta")
	t.eq(_righe(m, id).size(), prima, "…e non scrive niente")
	m.dimentica(id)


## LA RICEVUTA. `R_SU_DI_ME` non è un parametro: si DERIVA dal confronto fra
## il destinatario del gesto e chi guarda. Un booleano in più sarebbe un
## secondo modo di dire la stessa cosa — cioè la possibilità di dirla
## diversa, e un vicino che si prende la gratitudine di un regalo fatto a un
## altro è un guasto che nessuno vedrebbe mai.
func _la_ricevuta_e_su_di_me(t, m) -> void:
	var nino: int = m.registra(PackedStringArray([]), "")
	var pina: int = m.registra(PackedStringArray([]), "")
	var v: int = m.indice_verbo("dona")
	# Mochi regala a Nino; tutti e due guardano
	m.osserva(nino, v, Vector3(1.0, 0.0, 1.0), nino)
	m.osserva(pina, v, Vector3(1.0, 0.0, 1.0), nino)
	var rn := _ricordo_di(m, nino, v)
	var rp := _ricordo_di(m, pina, v)
	t.eq(int(rn["bandiere"]) & _a_me, _a_me, "per Nino il regalo era PER LUI")
	t.eq(int(rp["bandiere"]) & _a_me, 0, "per Pina no: l'ha visto, non l'ha ricevuto")
	t.eq(int(rn["soggetto"]), nino, "e tutti e due sanno a chi è andato")
	t.eq(int(rp["soggetto"]), nino, "…anche chi guardava")

	# e pesa il doppio, per chi l'ha ricevuto
	var en: Dictionary = m.debug_emozioni(nino)
	var ep: Dictionary = m.debug_emozioni(pina)
	var amico: int = m.indice_cosa("amico")
	t.almost(float(en["interesse"][amico]) / float(ep["interesse"][amico]), 2.0,
			"un gesto fatto a me pesa il doppio di uno che ho solo visto", 1e-9)
	t.ok(float(en["gratitudine"]) > 0.0, "e per Nino c'è della gratitudine")
	t.almost(float(ep["gratitudine"]), 0.0,
			"…mentre Pina non ha niente da ringraziare: non era per lei", 0.0)
	m.dimentica(nino)
	m.dimentica(pina)


## Sei aiuole annaffiate nello stesso gesto sono UN ricordo, e la fusione
## deve valere anche dalla porta d'ingresso vera (non solo sull'oracolo
## puro): sei righe separate riempirebbero l'anello e cancellerebbero tutto
## il resto — cioè un giocatore diligente si farebbe dimenticare quello che
## ha fatto prima.
func _la_fusione_vale_anche_dal_vivo(t, m) -> void:
	var id: int = m.registra(PackedStringArray([]), "")
	var v: int = m.indice_verbo("annaffia")
	for k in 6:
		m.osserva(id, v, Vector3(float(k), 0.0, 0.0), -1)
	t.eq(_righe(m, id).size(), 1, "sei aiuole nello stesso gesto sono UN ricordo")
	t.eq(int(_ricordo_di(m, id, v)["quante"]), 6, "…con «quante» a sei")
	m.dimentica(id)


## L'UNICA COSA FUORI POSTO. Qui si contano i campi uno per uno: cinque
## cose che la notizia dice (verbo, cosa, dove-x, dove-z, quante) devono
## arrivare INTATTE, e l'unica che si perde è CHI.
func _una_cosa_fuori_posto(t, m) -> void:
	var a: int = m.registra(PackedStringArray([]), "")
	var b: int = m.registra(PackedStringArray([]), "")
	var v: int = m.indice_verbo("dona")
	m.osserva(a, v, Vector3(-4.5, 0.0, 12.75), a) # a Mochi l'ha dato proprio a lui
	m.osserva(a, v, Vector3(-4.5, 0.0, 12.75), a) # due volte: quante = 2

	var cosa: int = m.racconta(a, b, 0.55)
	t.eq(cosa, m.indice_cosa("amico"),
			"il racconto torna la COSA di cui si è parlato: è quella che finisce nella nuvoletta")

	var orig := _ricordo_di(m, a, v)
	var eco := _ricordo_di(m, b, v)
	t.ok(not eco.is_empty(), "e chi ascolta adesso lo sa")
	var intatti := 0
	if int(eco["verbo"]) == int(orig["verbo"]):
		intatti += 1
	if int(eco["cosa"]) == int(orig["cosa"]):
		intatti += 1
	if float(eco["px"]) == float(orig["px"]):
		intatti += 1
	if float(eco["pz"]) == float(orig["pz"]):
		intatti += 1
	if int(eco["quante"]) == int(orig["quante"]):
		intatti += 1
	t.eq(intatti, 5,
			"delle cinque cose che la notizia dice (verbo, cosa, dove, quante) ne arrivano cinque")
	t.eq(int(eco["soggetto"]), _nessuno,
			"e l'unica che si perde è CHI: chi ascolta sa che è successo a «qualcuno»")
	t.eq(int(eco["bandiere"]), _sentito,
			"le bandiere dicono SOLO «me l'hanno detto»: né su di me, né già raccontato")
	t.eq(int(eco["bandiere"]) & _a_me, 0,
			"…e soprattutto la gratitudine non si trasmette a voce: un regalo fatto ad A non è fatto a B")
	m.dimentica(a)
	m.dimentica(b)


## LO SMORZAMENTO SI PAGA UNA VOLTA SOLA. La leva è una riga che si vede
## (il costruttore del registro mette `peso_sentito = 1.0` perché la
## smorzatura sta ormai nel dato); se un domani tornasse 0.55 senza che
## `racconta` smetta di smorzare l'intensità, il rapporto qui sotto
## crollerebbe a 0.30 e questo caso diventerebbe rosso.
func _lo_smorzamento_si_paga_una_volta(t, m) -> void:
	# LA COSTANTE SI LEGGE DA DOVE VIVE, non si ricopia. Qui c'era un `0.55`
	# scritto a mano con accanto il commento «Villaggio.SMORZAMENTO»: cioè una
	# copia che si dichiarava copia. Il giorno che qualcuno tarasse la
	# costante, questo caso continuerebbe a raccontare del vecchio numero — e
	# l'ultima asserzione (che distingue una applicazione da due) smetterebbe
	# di parlare del villaggio vero senza diventare rossa.
	var smorza: float = VILLAGGIO.SMORZAMENTO
	t.almost(float(m.debug_ritmo()["peso_sentito"]), 1.0,
			"la LETTURA non smorza più niente: la smorzatura è nel dato, e si paga una volta", 0.0)

	var a: int = m.registra(PackedStringArray([]), "")
	var b: int = m.registra(PackedStringArray([]), "")
	var v: int = m.indice_verbo("annaffia")
	m.osserva(a, v, Vector3(5.0, 0.0, 6.0), -1)
	m.racconta(a, b, smorza)

	var atteso := int(255.0 * smorza + 0.5)
	t.eq(int(_ricordo_di(m, b, v)["intensita"]), atteso,
			"l'intensità arriva smorzata, e arrotondata al più vicino (%d)" % atteso)
	t.eq(int(_ricordo_di(m, a, v)["intensita"]), 255,
			"…mentre chi l'ha visto la conserva intera")

	# il RAPPORTO fra i due pesi, che è la cosa che si vede in partita
	var fiore: int = m.indice_cosa("fiore")
	var ia := float((m.debug_emozioni(a)["interesse"] as PackedFloat64Array)[fiore])
	var ib := float((m.debug_emozioni(b)["interesse"] as PackedFloat64Array)[fiore])
	var rapporto := ib / ia
	t.almost(rapporto, float(atteso) / 255.0,
			"un sentito dire pesa esattamente l'intensità smorzata (%s)" % str(rapporto), 1e-12)
	t.ok(absf(rapporto - smorza * smorza) > 0.2,
			"…e NON lo smorzamento al quadrato (%s contro %s): sarebbe la doppia applicazione, e nessun numero sembrerebbe strano"
					% [str(rapporto), str(smorza * smorza)])

	# una voce non può MAI pesare più dell'averlo visto, nemmeno con una
	# taratura assurda dall'altra parte del ponte
	var c: int = m.registra(PackedStringArray([]), "")
	var d: int = m.registra(PackedStringArray([]), "")
	m.osserva(c, v, Vector3.ZERO, -1)
	m.racconta(c, d, 5.0)
	t.eq(int(_ricordo_di(m, d, v)["intensita"]), 255,
			"con uno smorzamento maggiore di uno si pinza: una voce non batte mai un occhio")
	var e: int = m.registra(PackedStringArray([]), "")
	var f: int = m.registra(PackedStringArray([]), "")
	m.osserva(e, v, Vector3.ZERO, -1)
	m.racconta(e, f, -3.0)
	t.eq(int(_ricordo_di(m, f, v)["intensita"]), 0,
			"e con uno negativo la voce arriva spenta, non capovolta")
	for x in [a, b, c, d, e, f]:
		m.dimentica(x)


## E NON RISORGE — cioè la regola di sopra vale ANCHE DOPO, non solo
## nell'istante del racconto.
##
## Il difetto che questo caso esiste per tenere chiuso non si vedeva
## guardando `racconta` una volta sola: lo smorzamento stava nell'intensità,
## e l'intensità è giusta. Ma `inserisci` **ritimbra sempre** `quando` ad
## adesso, e nessuno metteva nell'eco il freddo che il ricordo aveva già
## preso. Risultato: la voce ripartiva da capo mentre il testimone
## continuava a dimenticare. MISURATO, con mezza vita 120 s:
##
##   raccontata subito     B/A = 0.55    (giusto)
##   raccontata dopo 104 s B/A = 1.00    PAREGGIO
##   raccontata dopo 300 s B/A = 3.11
##   raccontata dopo 1200 s B/A = 562
##
## La scena: A ti vede annaffiare; venti minuti dopo A ha dimenticato
## (sotto soglia, l'ancora è tornata a casa). Proprio allora incrocia B, e
## B — CHE NON C'ERA — si ritrova sopra soglia con la posizione esatta
## dell'aiuola, e ci va. Era anche l'unico modo in cui un fatto
## sopravviveva alla mezza vita che il progetto dichiara.
##
## Le due asserzioni: il rapporto non supera MAI lo smorzamento (a nessun
## ritardo, né subito dopo il racconto né più tardi), e resta COSTANTE nel
## tempo — che è la forma misurabile di «l'eco decade come l'originale».
func _la_voce_non_risorge(t, m) -> void:
	var smorza: float = VILLAGGIO.SMORZAMENTO
	var v: int = m.indice_verbo("annaffia")
	var peggio := -1.0
	var quando_peggio := 0.0
	var visti: Array = []
	var rapporti: Array = []

	for ritardo in [0.0, 104.0, 300.0, 1200.0]:
		var n = ClassDB.instantiate("EcsMondo")
		n.imposta_ritmo(240.0)
		var a: int = n.registra(PackedStringArray([]), "")
		var b: int = n.registra(PackedStringArray([]), "")
		n.osserva(a, v, Vector3(3.0, 0.0, 4.0), -1)
		for _k in int(float(ritardo) / 4.0):
			n.avanza(4.0, 0.5)
		t.ok(int(n.racconta(a, b, smorza)) >= 0,
				"PREMESSA: dopo %.0f s A gliela racconta comunque (il silenzio non è la riparazione)"
						% float(ritardo))
		visti.append(float(n.ammirazione(a)))
		# il rapporto SUBITO dopo il racconto, e un minuto dopo: l'eco deve
		# decadere insieme all'originale, non per conto suo
		for passo in 2:
			var pa := float(n.ammirazione(a))
			var pb := float(n.ammirazione(b))
			var rap := (pb / pa) if pa > 0.0 else 0.0
			rapporti.append(rap)
			if rap > peggio:
				peggio = rap
				quando_peggio = float(ritardo)
			for _k in 15:
				n.avanza(4.0, 0.5)
		n.free()

	# LA PREMESSA CHE RENDE NON-VACUA LA SPAZZATA: nell'ultimo caso il
	# testimone ha davvero quasi dimenticato. Senza questa riga, un banco che
	# per sbaglio non facesse passare il tempo sarebbe verde su tutto.
	t.ok(float(visti[3]) < 0.01 * float(visti[0]),
			"PREMESSA: dopo venti minuti chi ha VISTO pesa %.6f contro %.6f: ha quasi dimenticato"
					% [float(visti[3]), float(visti[0])])

	# LA REGOLA, presa alla lettera: una voce non può pesare più di un occhio.
	# È quella che a 1200 s di ritardo valeva 562, e a 104 pareggiava.
	t.ok(peggio < 1.0,
			"una voce non pesa MAI più dell'averlo visto, a nessun ritardo (il peggiore è %.3f, a %.0f s dal fatto)"
					% [peggio, quando_peggio])
	# …e non pesa nemmeno «un po' meno»: pesa ESATTAMENTE lo smorzamento, a
	# meno dell'arrotondamento dell'intensità a otto bit (che su un'eco già
	# fredda vale qualche millesimo, e verso l'alto quanto verso il basso).
	t.ok(peggio <= smorza + 0.015,
			"…e resta lo smorzamento del villaggio, non qualcosa che gli somiglia (%.4f contro %.2f)"
					% [peggio, smorza])
	t.almost(float(rapporti[0]), smorza,
			"PREMESSA: raccontata subito, l'eco pesa lo smorzamento (%.4f)" % float(rapporti[0]),
			0.005)
	t.ok(float(rapporti[4]) > 0.4,
			"PREMESSA: e a cinque minuti l'eco arriva ancora, non è spenta per caso (%.4f)"
					% float(rapporti[4]))
	t.ok(absf(float(rapporti[0]) - float(rapporti[1])) < 1e-5,
			"e l'eco decade INSIEME all'originale: il rapporto non si muove col tempo (%.6f poi %.6f)"
					% [float(rapporti[0]), float(rapporti[1])])
	t.ok(absf(float(rapporti[4]) - float(rapporti[5])) < 1e-5,
			"…nemmeno per una notizia vecchia di cinque minuti (%.6f poi %.6f)"
					% [float(rapporti[4]), float(rapporti[5])])


## UN'ECO SPENTA NON TAPPA LA NOTIZIA FRESCA.
##
## È la porta che il freddo nell'eco ha aperto, e va chiusa nello stesso
## commit: una voce arrivata molto tardi entra nel grafo di chi ascolta a
## intensità ZERO, cioè come una riga che non pesa niente. La maschera
## `saputi` di `racconta` guardava TUTTI i ricordi di chi ascolta, quindi
## quella riga morta gli avrebbe tappato quel verbo per sempre: chi la cosa
## l'aveva vista fresca non poteva più raccontargliela, e la notizia vera
## restava fuori per colpa di una che non significa più niente.
##
## Adesso `saputi` conta solo quello che chi ascolta si RICORDA ancora.
func _un_eco_spenta_non_tappa_la_notizia_fresca(t, m) -> void:
	var n = ClassDB.instantiate("EcsMondo")
	n.imposta_ritmo(240.0)
	var a: int = n.registra(PackedStringArray([]), "")
	var b: int = n.registra(PackedStringArray([]), "")
	var c: int = n.registra(PackedStringArray([]), "")
	var v: int = n.indice_verbo("pesca")

	n.osserva(a, v, Vector3(1.0, 0.0, 1.0), -1)
	for _k in 300: # venti minuti di gioco: dieci mezze vite
		n.avanza(4.0, 0.5)
	t.ok(int(n.racconta(a, b, 0.55)) >= 0,
			"PREMESSA: A gliela racconta lo stesso, tardi com'è")
	var eco := _ricordo_di(n, b, v)
	t.ok(not eco.is_empty(), "PREMESSA: e a B la riga è arrivata")
	t.eq(int(eco["intensita"]), 0,
			"PREMESSA: ma arriva SPENTA — non pesa più niente, ed è giusto così")

	# adesso C, che l'ha vista un attimo fa
	n.osserva(c, v, Vector3(2.0, 0.0, 2.0), -1)
	t.ok(int(n.racconta(c, b, 0.55)) >= 0,
			"e la notizia FRESCA arriva a B lo stesso: una riga morta non gli tappa un verbo per sempre")
	var forte := 0
	for r in _righe(n, b):
		if int(r["verbo"]) == v:
			forte = maxi(forte, int(r["intensita"]))
	t.ok(forte > 0,
			"…e stavolta arriva con qualcosa dentro (intensità %d)" % forte)

	# LA CONTROPROVA, che è ciò che tiene in piedi la regola di sempre: se B
	# la sa DAVVERO (fresca), non gliela si ripassa. Senza questa riga il
	# filtro di sopra potrebbe essere diventato «non filtro niente».
	var d: int = n.registra(PackedStringArray([]), "")
	n.osserva(d, v, Vector3(3.0, 0.0, 3.0), -1)
	t.eq(int(n.racconta(d, b, 0.55)), -1,
			"ma quello che B si ricorda per davvero non gli si ripassa: il tappo giusto c'è ancora")
	n.free()


## DA CHI L'HA SENTITA NON RIPARTE. È la regola che tiene il pettegolezzo un
## pettegolezzo invece di un'epidemia: senza, una notizia raggiungerebbe
## tutto il villaggio in pochi minuti e non ci sarebbe più niente da
## cogliere.
func _da_chi_l_ha_sentita_non_riparte(t, m) -> void:
	var a: int = m.registra(PackedStringArray([]), "")
	var b: int = m.registra(PackedStringArray([]), "")
	var c: int = m.registra(PackedStringArray([]), "")
	var v: int = m.indice_verbo("cucina")
	m.osserva(a, v, Vector3.ZERO, -1)
	t.ok(m.racconta(a, b, 0.55) >= 0, "A racconta a B quel che ha visto")
	t.eq(m.racconta(b, c, 0.55), -1, "ma B non lo ripassa a C: l'ha solo sentito dire")
	t.ok(not _sa(m, c, v), "…e C non ne sa niente")
	for x in [a, b, c]:
		m.dimentica(x)


## CHI L'HA RACCONTATA NON LA RIPETE. Il marchio si mette DOVE IL RACCONTO
## ACCADE — non dentro `da_raccontare`, che è una domanda, e una domanda non
## deve cambiare niente.
func _chi_l_ha_raccontata_non_la_ripete(t, m) -> void:
	var a: int = m.registra(PackedStringArray([]), "")
	var b: int = m.registra(PackedStringArray([]), "")
	var c: int = m.registra(PackedStringArray([]), "")
	var v: int = m.indice_verbo("taglia")
	m.osserva(a, v, Vector3.ZERO, -1)
	t.ok(m.racconta(a, b, 0.55) >= 0, "la prima volta la racconta")
	t.eq(int(_ricordo_di(m, a, v)["bandiere"]) & _detto, _detto,
			"e il suo ricordo porta il marchio di chi l'ha già detta")
	t.eq(m.racconta(a, c, 0.55), -1, "la seconda volta tace: non ha altro da dire")
	t.ok(not _sa(m, c, v), "…e la notizia si ferma dov'era")
	for x in [a, b, c]:
		m.dimentica(x)


## CIÒ CHE L'ALTRO SA GIÀ NON SI RIPASSA — e la notizia SCENDE di un
## gradino invece di tacere.
##
## In un villaggio dove Mochi annaffia tutti i giorni, il ricordo più
## pesante di TUTTI è «annaffia». Se la scelta non potesse scendere,
## ogni chiacchierata proverebbe a raccontare l'unica notizia che sanno già
## tutti, e le altre non uscirebbero MAI: il pettegolezzo si tapperebbe da
## solo, con la suite verde e senza un errore.
func _cio_che_sa_gia_non_si_ripassa(t, m) -> void:
	var a: int = m.registra(PackedStringArray([]), "")
	var b: int = m.registra(PackedStringArray([]), "")
	var annaffia: int = m.indice_verbo("annaffia")
	var pesca: int = m.indice_verbo("pesca")
	# A ha visto tutte e due; B ha visto solo l'annaffiata
	m.osserva(a, annaffia, Vector3(1.0, 0.0, 1.0), -1)
	m.osserva(a, pesca, Vector3(2.0, 0.0, 2.0), -1)
	m.osserva(b, annaffia, Vector3(1.0, 0.0, 1.0), -1)

	var cosa: int = m.racconta(a, b, 0.55)
	t.eq(cosa, m.indice_cosa("pesce"),
			"non gli ripete l'annaffiata che ha visto anche lui: gli racconta la pesca")
	t.eq(_righe(m, b).size(), 2, "e a B è arrivata UNA notizia sola, non un doppione")
	t.eq(int(_ricordo_di(m, a, pesca)["bandiere"]) & _detto, _detto,
			"la pesca risulta raccontata…")
	t.eq(int(_ricordo_di(m, a, annaffia)["bandiere"]) & _detto, 0,
			"…e l'annaffiata NO: resta in tasca per qualcuno che non c'era")
	for x in [a, b]:
		m.dimentica(x)


## IL SILENZIO NON BRUCIA LA NOTIZIA. Quando non c'è niente da dirsi non
## succede proprio niente — nessun marchio, nessuna versione che sale — e la
## stessa notizia trova un altro orecchio più tardi.
func _il_silenzio_non_brucia_la_notizia(t, m) -> void:
	var a: int = m.registra(PackedStringArray([]), "")
	var b: int = m.registra(PackedStringArray([]), "")
	var c: int = m.registra(PackedStringArray([]), "")
	var v: int = m.indice_verbo("costruisce")
	m.osserva(a, v, Vector3(7.0, 0.0, 8.0), -1)
	m.osserva(b, v, Vector3(7.0, 0.0, 8.0), -1)

	var versione_prima := int(m.debug_grafo(a)["versione"])
	t.eq(m.racconta(a, b, 0.55), -1, "con chi c'era non c'è niente da dirsi")
	t.eq(int(m.debug_grafo(a)["versione"]), versione_prima,
			"e non si scrive niente: nemmeno la versione del grafo si muove")
	t.eq(_righe(m, b).size(), 1, "…e a B non arriva un doppione di quel che ha visto")

	t.eq(m.racconta(a, c, 0.55), m.indice_cosa("casa"),
			"la stessa notizia esce, più tardi, con chi non c'era")
	t.ok(_sa(m, c, v), "…e stavolta arriva")
	for x in [a, b, c]:
		m.dimentica(x)


## Non ci si racconta niente da soli. Non è un caso di scuola: a `_run_chat`
## una coppia arriva da due cicli annidati, e il giorno che gli indici
## sbagliassero, uno che si racconta una notizia a se stesso se la
## marchierebbe «già detta» — perdendola per tutti gli altri, in silenzio.
func _non_si_racconta_a_se_stessi(t, m) -> void:
	var a: int = m.registra(PackedStringArray([]), "")
	var v: int = m.indice_verbo("raccoglie")
	m.osserva(a, v, Vector3.ZERO, -1)
	t.eq(m.racconta(a, a, 0.55), -1, "nessuno si racconta le notizie da solo")
	t.eq(int(_ricordo_di(m, a, v)["bandiere"]) & _detto, 0,
			"…e soprattutto non se la brucia: la notizia è ancora sua")
	t.eq(_righe(m, a).size(), 1, "e non se ne è fatta una copia")
	m.dimentica(a)


## DETERMINISMO: in C++ non c'è e non ci sarà un RNG. Lo stesso villaggio,
## la stessa coppia, lo stesso istante → lo stesso racconto, dieci volte.
## Si RICOSTRUISCE lo stato ogni giro apposta: `racconta` cambia il mondo, e
## un determinismo misurato senza rifare lo stato misurerebbe soltanto che
## la seconda volta non succede niente.
func _e_deterministico(t, m) -> void:
	var esiti := {}
	var grafi := {}
	for k in 10:
		var a: int = m.registra(PackedStringArray([]), "")
		var b: int = m.registra(PackedStringArray([]), "")
		# tre notizie di pari peso: se ci fosse un dado, uscirebbero diverse
		for v in ["annaffia", "pesca", "cucina"]:
			m.osserva(a, m.indice_verbo(v), Vector3(1.0, 0.0, 2.0), -1)
		esiti[m.racconta(a, b, 0.55)] = true
		grafi[str(m.debug_grafo(b))] = true
		m.dimentica(a)
		m.dimentica(b)
	t.eq(esiti.size(), 1, "dieci racconti uguali danno dieci esiti uguali")
	t.eq(grafi.size(), 1, "…e dieci grafi identici in chi ascolta, campo per campo")


## La scelta filtrata si può interrogare da sola, e deve: se si potesse
## provare solo di rimbalzo attraverso `racconta`, il giorno che qualcuno
## togliesse la maschera resterebbe da capire QUALE delle due cose si è
## rotta.
func _la_novita_si_chiede_da_sola(t, m) -> void:
	var id: int = m.registra(PackedStringArray([]), "")
	var annaffia: int = m.indice_verbo("annaffia")
	var pesca: int = m.indice_verbo("pesca")
	m.osserva(id, annaffia, Vector3.ZERO, -1)
	m.osserva(id, pesca, Vector3.ZERO, -1)
	var g: Dictionary = m.debug_grafo(id)
	var mv := float(m.debug_ritmo()["mezza_vita"])
	var ora := float(m.debug_ritmo()["tempo"])
	t.eq(m.debug_grafo_novita(g, ora, mv, 0), 0,
			"a chi non sa niente si racconta la prima delle due (a parità vince l'indice più basso)")
	t.eq(m.debug_grafo_novita(g, ora, mv, 1 << annaffia), 1,
			"a chi sa già dell'annaffiata si racconta la pesca")
	t.eq(m.debug_grafo_novita(g, ora, mv, (1 << annaffia) | (1 << pesca)), -1,
			"a chi sa già tutto non si dice niente, ed è il caso normale")
	m.dimentica(id)


## LA SATURAZIONE, ed è la misura che dice se questo sistema è un
## pettegolezzo o un megafono.
##
## Ventotto vicini, trenta minuti, e il ritmo VERO delle chiacchiere di
## `Visitors._chats`: UNA per volta in tutto il villaggio ogni 3,5 s, e la
## stessa coppia non si riparla per 35 s — cioè il massimo teorico, 514
## chiacchierate. Un solo fatto seminato.
##
## L'orologio va a scatti di 3,5 s invece che a frame: il passaparola guarda
## solo il grafo e l'orologio, e il risultato è IDENTICO (verificato: 2 su
## 28 in tutti e due i modi) al costo di duecento chiamate invece di
## centomila.
func _una_notizia_non_e_un_broadcast(t, m) -> void:
	var uno := _semina_e_chiacchiera(1, 4243)
	t.ok(uno["sanno"] <= 4,
			"un fatto seminato, %d chiacchierate in mezz'ora: lo sanno in %d su 28, non tutti"
					% [uno["chiacchiere"], uno["sanno"]])
	t.ok(uno["sanno"] >= 2,
			"…ma qualcuno lo sa: se restasse a uno, il passaparola sarebbe spento e la riga di sopra non direbbe niente")
	t.ok(uno["chiacchiere"] >= 400,
			"e le occasioni non sono mancate (%d incontri)" % uno["chiacchiere"])

	# e cresce con i TESTIMONI, non da solo: otto che hanno visto la stessa
	# cosa la portano a sedici, non a ventotto
	var otto := _semina_e_chiacchiera(8, 4250)
	t.ok(otto["sanno"] <= 16,
			"con otto testimoni lo sanno in %d: due a testa, non tutto il villaggio"
					% otto["sanno"])
	t.ok(otto["sanno"] > uno["sanno"],
			"…e più testimoni fanno più portata (%d contro %d): la notizia non è un'epidemia, è una catena corta"
					% [otto["sanno"], uno["sanno"]])


## Un villaggio in cui succedono cose: un gesto al minuto, otto testimoni per
## gesto. Serve a sapere che il pettegolezzo VIVE — senza questa misura,
## «lo sanno in due» non distinguerebbe «non è un broadcast» da «è spento».
##
## E serve anche a sapere che **la voce ce l'hanno TUTTI E VENTOTTO**: è
## l'unica asserzione che, in mezz'ora di villaggio pieno, guarda chi ha
## parlato invece di quanto si è parlato.
func _ma_il_pettegolezzo_e_vivo(t, m) -> void:
	var n = ClassDB.instantiate("EcsMondo")
	n.imposta_ritmo(240.0)
	var ids: Array = []
	for i in 28:
		ids.append(n.registra(PackedStringArray([]), ""))
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var cd := {}
	var detti := {}
	var con_notizia := 0
	var mute := 0
	var scatti := int(1800.0 / 3.5)
	for k in scatti:
		n.avanza(3.5, 0.5)
		if k % 17 == 0: # un gesto di Mochi al minuto, otto testimoni
			var v := rng.randi_range(0, 7)
			for _w in 8:
				n.osserva(ids[rng.randi_range(0, 27)], v,
						Vector3(rng.randf() * 20.0, 0.0, rng.randf() * 20.0), -1)
		for _try in 40:
			var a := rng.randi_range(0, 27)
			var b := rng.randi_range(0, 27)
			if a == b:
				continue
			var key := "%d_%d" % [mini(a, b), maxi(a, b)]
			if float(k) * 3.5 - float(cd.get(key, -1e9)) < 35.0:
				continue
			cd[key] = float(k) * 3.5
			var verso := _verso(a, b, rng)
			if n.racconta(ids[verso.x], ids[verso.y], 0.55) >= 0:
				con_notizia += 1
				detti[verso.x] = int(detti.get(verso.x, 0)) + 1
			else:
				mute += 1
			break
	var sentiti := 0
	for i in 28:
		for r in (n.debug_grafo(ids[i])["ricordi"] as Array):
			if int(r["bandiere"]) & _sentito:
				sentiti += 1
	t.ok(con_notizia >= 40,
			"in mezz'ora di villaggio vivo, %d chiacchierate portano una notizia" % con_notizia)
	t.ok(mute > con_notizia,
			"…ma il SILENZIO resta il comportamento normale (%d mute contro %d): non si commenta a ogni incontro"
					% [mute, con_notizia])
	t.ok(sentiti >= 40,
			"e nei grafi ci sono %d ricordi che nessuno ha visto con i propri occhi" % sentiti)
	# LA VOCE CE L'HANNO TUTTI. Con il verso deciso dall'anagrafe, il
	# residente k poteva raccontare solo a k+1…27 e il numero 27 a nessuno:
	# misurato su questo stesso banco, **il ventisettesimo non raccontava
	# MAI**. Ed è in coda che finiscono, per costruzione, chi è appena
	# arrivato e chi è appena nato.
	var muti: Array = []
	for i in 28:
		if int(detti.get(i, 0)) == 0:
			muti.append(i)
	t.eq(muti.size(), 0,
			"e in mezz'ora hanno raccontato tutti e ventotto (muti: %s)" % str(muti))
	n.free()


func _semina_e_chiacchiera(semi: int, seme: int) -> Dictionary:
	var n = ClassDB.instantiate("EcsMondo")
	n.imposta_ritmo(240.0)
	var ids: Array = []
	for i in 28:
		ids.append(n.registra(PackedStringArray([]), ""))
	var rng := RandomNumberGenerator.new()
	rng.seed = seme
	# la notizia: un verbo che nessun altro vedrà mai in questa mezz'ora
	var verbo: int = n.indice_verbo("pesca")
	for i in semi:
		n.osserva(ids[i], verbo, Vector3(3.0, 0.0, 4.0), -1)
	var cd := {}
	var chiacchiere := 0
	var scatti := int(1800.0 / 3.5)
	for k in scatti:
		n.avanza(3.5, 0.5)
		for _try in 40:
			var a := rng.randi_range(0, 27)
			var b := rng.randi_range(0, 27)
			if a == b:
				continue
			var key := "%d_%d" % [mini(a, b), maxi(a, b)]
			if float(k) * 3.5 - float(cd.get(key, -1e9)) < 35.0:
				continue
			cd[key] = float(k) * 3.5
			var verso := _verso(a, b, rng)
			n.racconta(ids[verso.x], ids[verso.y], 0.55)
			chiacchiere += 1
			break
	var sanno := 0
	for i in 28:
		for r in (n.debug_grafo(ids[i])["ricordi"] as Array):
			if int(r["verbo"]) == verbo:
				sanno += 1
				break
	n.free()
	return {"sanno": sanno, "chiacchiere": chiacchiere}


# ================================ IL VERSO E LA COPPIA (Visitors._chats)
#
# `racconta(a, b)` è asimmetrica per contratto: A parla, B ascolta. Chi
# sono A e B lo sceglie `Visitors.scegli_chiacchiera`, e per un anno intero
# non lo sceglieva nessuno — erano due cicli annidati, sempre i < j.
# Misurato nel villaggio vero (`tools/prova_chiacchiere.gd`): cinque vicini
# addosso per 300 s, 86 chiacchierate, e l'ULTIMO non raccontava mai;
# dodici vicini attorno al falò per 600 s, 181 chiacchierate, e CINQUE su
# dodici non aprivano bocca nemmeno una volta.


## LA COPPIA NON LA SCEGLIE L'ANAGRAFE.
##
## Il banco è l'anello VERO del falò (`Visitors._posto_al_falo`): dodici
## vicini in cerchio, e a portata di voce ognuno ha i due davanti e i due
## dietro — ventiquattro coppie. Con la scelta lessicografica ne
## chiacchierava UNA (la prima) e le altre ventitré mai.
func _la_coppia_non_la_sceglie_l_anagrafe(t) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260811
	var coppie: Array[Vector2i] = []
	for i in 12:
		for d in [1, 2]:
			var j: int = (i + d) % 12
			coppie.append(Vector2i(mini(i, j), maxi(i, j)))
	var giri := 24000
	var quante := {}
	var apre := {}
	for _k in giri:
		var s: Vector2i = VISITORS.scegli_chiacchiera(coppie, rng)
		var key := Vector2i(mini(s.x, s.y), maxi(s.x, s.y))
		quante[key] = int(quante.get(key, 0)) + 1
		apre[s.x] = int(apre.get(s.x, 0)) + 1
	t.eq(quante.size(), coppie.size(),
			"tutte e %d le coppie a portata di voce chiacchierano (ne hanno chiacchierato %d)"
					% [coppie.size(), quante.size()])
	# uniforme: 24000 / 24 = 1000 attesi per coppia, scarto tipo ≈ 31.
	# La forbice è ±20%, cioè sei scarti tipo: prende un dado storto, non
	# il rumore.
	var meno := giri
	var piu := 0
	for k in quante:
		meno = mini(meno, int(quante[k]))
		piu = maxi(piu, int(quante[k]))
	t.ok(meno >= 800 and piu <= 1200,
			"…e nessuna è privilegiata: fra %d e %d su 1000 attese" % [meno, piu])
	# e OGNUNO apre bocca: quattro coppie a testa, metà delle volte tocca a
	# lui → 24000·(4/24)·0.5 = 2000 attesi
	var muti: Array = []
	var meno_apre := giri
	for i in 12:
		if int(apre.get(i, 0)) == 0:
			muti.append(i)
		meno_apre = mini(meno_apre, int(apre.get(i, 0)))
	t.eq(muti.size(), 0, "e tutti e dodici aprono bocca (muti: %s)" % str(muti))
	t.ok(meno_apre >= 1600,
			"…e nessuno per sbaglio: il più zitto apre bocca %d volte su 2000 attese" % meno_apre)


## CHI APRE BOCCA È UNA MONETINA, non l'indice più basso. Una coppia sola,
## quattromila incontri: se il verso venisse dall'anagrafe, uno dei due
## sarebbe a zero.
func _chi_apre_bocca_e_una_monetina(t) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var coppie: Array[Vector2i] = [Vector2i(3, 7)]
	var giri := 4000
	var apre_il_tre := 0
	for _k in giri:
		var s: Vector2i = VISITORS.scegli_chiacchiera(coppie, rng)
		if s.x == 3:
			apre_il_tre += 1
	# 4000 lanci, scarto tipo ≈ 32: la forbice è a sei scarti tipo
	t.ok(absi(apre_il_tre - 2000) <= 190,
			"su %d incontri della stessa coppia, il primo apre bocca %d volte (metà)"
					% [giri, apre_il_tre])


## Senza nessuno a portata di voce non si chiacchiera — e lo si DICE, invece
## di tornare una coppia che non esiste.
func _senza_nessuno_a_portata_non_si_chiacchiera(t) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	t.eq(VISITORS.scegli_chiacchiera([], rng), Vector2i(-1, -1),
			"nessuna coppia a portata di voce: nessuna chiacchierata")


## NESSUNO RESTA MUTO — il capannello, con la scelta VERA e `racconta` vero.
##
## È la riproduzione, dentro la suite, della misura fatta nel villaggio:
## cinque vicini addosso, una notizia DIVERSA a testa (verbi distinti, così
## la maschera «cosa sa già l'altro» non entra mai in gioco e l'unico limite
## è che una notizia si racconta una volta sola), 86 chiacchierate come
## quelle contate in 300 s di MainLevel. Il massimo possibile è cinque
## racconti, uno a testa.
##
## Con l'anagrafe che decideva il verso: quattro racconti su cinque, e
## **l'indice 4 a zero pur avendo chiacchierato 33 volte**.
func _nessuno_resta_muto(t, m) -> void:
	m.dimentica_tutti()
	var verbi := ["annaffia", "semina", "raccoglie", "costruisce", "taglia"]
	var ids: Array = []
	for i in 5:
		ids.append(m.registra(PackedStringArray([]), ""))
	for i in 5:
		m.osserva(ids[i], m.indice_verbo(verbi[i]), Vector3(3.0 + float(i), 0.0, 4.0), -1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	var cd := {}
	var detti := [0, 0, 0, 0, 0]
	var chiacchiere := [0, 0, 0, 0, 0]
	for k in 86:
		var ora := float(k) * 3.5
		var coppie: Array[Vector2i] = []
		for i in 5:
			for j in range(i + 1, 5):
				if ora - float(cd.get("%d_%d" % [i, j], -1.0e9)) < 35.0:
					continue
				coppie.append(Vector2i(i, j))
		var s: Vector2i = VISITORS.scegli_chiacchiera(coppie, rng)
		if s.x < 0:
			continue
		cd["%d_%d" % [mini(s.x, s.y), maxi(s.x, s.y)]] = ora
		chiacchiere[s.x] += 1
		chiacchiere[s.y] += 1
		if m.racconta(ids[s.x], ids[s.y], 0.55) >= 0:
			detti[s.x] += 1
	var muti: Array = []
	for i in 5:
		if detti[i] == 0:
			muti.append(i)
	t.eq(muti.size(), 0,
			"tutti e cinque hanno raccontato la loro (racconti %s, chiacchiere %s)"
					% [str(detti), str(chiacchiere)])
	for i in 5:
		t.eq(int(detti[i]), 1,
				"…e nessuno l'ha raccontata due volte: l'indice %d una sola" % i)
	for x in ids:
		m.dimentica(x)


## LA REGOLA DEL CIMITERO: dove muore il cervello muore l'entità, e con
## l'entità muoiono il suo grafo e le sue emozioni. Non c'è nessuna
## spazzata da fare sugli handle che i ricordi degli ALTRI portano dentro:
## `Ricordo.soggetto` è l'handle COMPLETO (indice + versione), e EnTT
## ricicla gli slot. Il guasto che questo evita si vedrebbe dopo cento
## giorni e solo in un villaggio che ha avuto partenze — cioè dove nessun
## collaudo arriva.
##
## (Le righe `ERROR:` che questo caso stampa sono volute: sono le guardie
## di `osserva` e `racconta` che rifiutano un handle morto invece di
## scrivere su memoria di nessuno.)
func _dove_muore_il_cervello_muore_l_entita(t, m) -> void:
	m.dimentica_tutti()
	var a: int = m.registra(PackedStringArray([]), "")
	var b: int = m.registra(PackedStringArray([]), "")
	var v: int = m.indice_verbo("dona")
	m.osserva(a, v, Vector3.ZERO, b) # Mochi ha regalato a B, e A l'ha visto
	t.eq(int(_ricordo_di(m, a, v)["soggetto"]), b, "il ricordo di A porta l'handle di B")

	m.dimentica(b)
	t.eq(m.quanti(), 1, "congedato B, nel registro ne resta uno")
	t.eq(m.debug_grafo(b).size(), 0, "e il grafo di B non esiste più")

	var c: int = m.registra(PackedStringArray([]), "")
	t.ok(c != b, "chi arriva dopo NON riusa l'handle del congedato")
	t.ok(int(_ricordo_di(m, a, v)["soggetto"]) != c,
			"…quindi non eredita il regalo di chi è partito: il ricordo di A parla ancora di un altro")
	t.eq(_righe(m, c).size(), 0, "e il nuovo arriva senza ricordi di nessuno")

	# le due porte rifiutano un handle morto invece di scrivere nel vuoto
	t.eq(m.osserva(b, v, Vector3.ZERO, -1), -1, "non si incide un ricordo su chi non c'è più")
	t.eq(m.racconta(a, b, 0.55), -1, "e non gli si racconta niente")
	t.eq(m.racconta(b, a, 0.55), -1, "…né lui racconta")
	t.eq(int(_ricordo_di(m, a, v)["bandiere"]) & _detto, 0,
			"e il racconto fallito non ha bruciato la notizia di A")

	m.dimentica_tutti()
	t.eq(m.quanti(), 0, "dimentica_tutti porta via tutto, grafi compresi")
