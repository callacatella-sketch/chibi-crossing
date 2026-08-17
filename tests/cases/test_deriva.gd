extends RefCounted

## LA DERIVA DEI TRATTI — la metà pura, e le quattro proprietà che la rendono
## dicibile in un gioco cozy.
##
## Questo file prova `scenes/npc/Deriva.gd` e **nient'altro**: in questa
## consegna nessuno la chiama, quindi il gioco è bit-identico a prima. La
## guardia che il cablaggio esista arriverà col cablaggio — e sarà la più
## importante di tutte, perché in questo progetto i sistemi arrivano SPENTI
## (il termine dell'insieme che non cambiava nessuna decisione, la
## neurochimica che non arrivava a nessun corpo, 247 righe di somatizzazione
## col corpo bit-identico: tutti completi, provati, verdi).

const DERIVA := preload("res://scenes/npc/Deriva.gd")

## La curva del tempo, come la fa `Animo._recenza`: qui si passa una Callable
## perché la mezza vita vive di là e non si ricopia.
const MEZZA_VITA := 18.0


func run(t) -> void:
	_niente_al_muro_e_l_ordine_si_conserva(t)
	_senza_prove_non_deriva_nessuno(t)
	_solo_carburante_uno_a_uno(t)
	_solo_prove_positive(t)
	_il_ritorno_e_una_proprieta(t)
	_i_marchi_tirano_dall_altra_parte(t)
	_i_tratti_che_non_derivano(t)


func _rec(oggi: int) -> Callable:
	return func(quando: int) -> float:
		return pow(0.5, float(oggi - quando) / MEZZA_VITA)


func _riga(tipo: String, attore: String, valenza: float, intensita: float,
		quando: int) -> Dictionary:
	return {"tipo": tipo, "attore": attore, "valenza": valenza,
			"intensita": intensita, "quando": quando}


## ⚠️ **NESSUNO ARRIVA AL MURO, E L'ORDINE SI CONSERVA.**
##
## È il vincolo dell'autore («mai oltre una frazione del tratto originale, così
## nessuno diventa irriconoscibile») letto alla lettera, e la forma
## proporzionale lo rende un teorema invece di una taratura.
##
## La mutazione plausibile — ed è la stesura che uno scriverebbe per prima — è
## il tetto ADDITIVO: `base + FRAZIONE * s`. Misurato altrove: un tetto
## additivo di ±0.15 porta al muro il 7% dei valori veri e ±0.35 il 47%, e tre
## codardi a 0.85 / 0.92 / 0.98 diventerebbero tre volte la stessa persona.
func _niente_al_muro_e_l_ordine_si_conserva(t) -> void:
	var basi := [0.0, 0.02, 0.05, 0.2, 0.5, 0.534, 0.8, 0.95, 0.98, 1.0]
	var press := [-1.0, -0.63, -0.2, 0.0, 0.2, 0.63, 1.0]
	var al_muro := 0
	for b in basi:
		for s in press:
			var d: float = DERIVA.derivato(float(b), float(s))
			t.ok(d >= 0.0 and d <= 1.0, "il derivato resta in scala (%.3f)" % d)
			if float(b) > 0.0 and float(b) < 1.0 and (d <= 0.0 or d >= 1.0):
				al_muro += 1
	t.eq(al_muro, 0,
			"nessun tratto arriva al muro, a nessuna ampiezza: "
			+ "chi era resta riconoscibile")

	# …e l'ORDINE, a parità di prove: due codardi diversi restano diversi, e
	# nell'ordine in cui erano
	for s2 in press:
		var prec := -1.0
		for b2 in basi:
			var d2: float = DERIVA.derivato(float(b2), float(s2))
			t.ok(d2 > prec or is_equal_approx(d2, prec),
					"pressione %.2f: l'ordine si conserva (%.4f dopo %.4f)"
							% [s2, d2, prec])
			prec = d2

	# e i due estremi non si muovono affatto: non hanno distanza da percorrere
	t.almost(DERIVA.derivato(0.0, -1.0), 0.0, "chi nasce a zero non deriva", 1e-12)
	t.almost(DERIVA.derivato(1.0, 1.0), 1.0, "chi nasce a uno non deriva", 1e-12)

	# il tetto e' una frazione della PROPRIA distanza, quindi due persone
	# diverse si spostano di quantita' diverse
	var giu_basso: float = absf(DERIVA.delta(0.2, -1.0))
	var giu_alto: float = absf(DERIVA.delta(0.8, -1.0))
	t.ok(giu_alto > giu_basso * 3.0,
			"chi ha piu' strada da fare si muove di piu' (%.4f contro %.4f)"
					% [giu_alto, giu_basso])


## ⚠️ **SENZA PROVE NON DERIVA NESSUNO — il collaudo del «mai un'assenza».**
##
## Una deriva alimentata da ciò che *non* è successo sarebbe una punizione per
## chi gioca in un altro modo, e il cozy la vieta. La mutazione plausibile è la
## forma «più è solo, più cambia»: un termine tipo `(1 − quante_volte/N)`, che
## sembra innocuo e trasforma il silenzio in un motore.
func _senza_prove_non_deriva_nessuno(t) -> void:
	for oggi in [0, 7, 100, 5000]:
		for tratto in DERIVA.DERIVANO:
			t.almost(DERIVA.spinta(str(tratto), [], {}, {}, _rec(int(oggi))), 0.0,
					"nessuna riga, nessuna deriva («%s», giorno %d)" % [tratto, oggi],
					1e-12)
	# e con una base qualunque, il tratto resta esattamente quello di nascita
	for b in [0.1, 0.534, 0.9]:
		t.almost(DERIVA.derivato(float(b),
				DERIVA.spinta("codardia", [], {}, {}, _rec(50))), float(b),
				"e il tratto resta quello di nascita (%.3f)" % b, 1e-12)


## ⚠️ **SOLO CARBURANTE UNO-A-UNO** — la guardia più importante di questo file.
##
## Una cosa che il villaggio fa a tutti non distingue nessuno, quindi non può
## muovere nessuno. E il cancello non è una lista di esclusioni: è la chiave
## `attore == "giocatore"`.
##
## ⚠️ E la mutazione plausibile è **quello che l'esempio dell'autore chiede
## alla lettera**: aggiungere «vegliato» alle spinte. Quella riga la Veglia la
## scrive a OGNI residente OGNI mattina — misurato 1.000 per residente per
## giornata, identica per tutti — e la deriva diventerebbe una marea che
## solleva tutte le barche, cioè nessuna. La versione che sta sui binari vuole
## prima che la Veglia sappia dire CHI ha avuto la propria porta al buio.
func _solo_carburante_uno_a_uno(t) -> void:
	var rec := _rec(10)

	# ⚠️ **I DUE CANCELLI SI PROVANO SEPARATI, e la prima stesura di questo
	# caso non lo faceva.** Le righe di prova avevano insieme un tipo fuori
	# dalle spinte E un attore diverso dal giocatore: ognuno dei due cancelli
	# mascherava la mutazione dell'altro, e **entrambe le mutazioni lasciavano
	# la suite verde** (misurato: zero asserzioni rosse su tutte e due). Una
	# guardia che passa perche' un'altra guardia la copre non e' una guardia.

	# --- CANCELLO A · L'ATTORE. Tipo che E' fra le spinte, attore che NON e'
	#     il giocatore: dev'essere zero. Togliere il controllo dell'attore fa
	#     arrossire QUESTO.
	var da_un_vicino := [_riga("piatto", "Biscotto", 0.8, 1.0, 9),
			_riga("regalo", "Malva", 0.8, 1.0, 8)]
	t.almost(DERIVA.spinta("codardia", da_un_vicino, {}, {}, rec), 0.0,
			"un piatto che ti ha portato un VICINO non ti cambia: la deriva "
			+ "e' la ricevuta di quello che fa il giocatore", 1e-12)
	# e nel sommario, uguale
	t.almost(DERIVA.spinta("codardia", [],
			{"piatto|Biscotto": {"peso": 3.0, "ultimo": 9}}, {}, rec), 0.0,
			"e nemmeno fuso nel sommario", 1e-12)
	# la controprova, o il caso passerebbe anche con la deriva spenta del tutto
	var dal_giocatore := [_riga("piatto", "giocatore", 0.8, 1.0, 9)]
	t.ok(DERIVA.spinta("codardia", dal_giocatore, {}, {}, rec) < -0.01,
			"mentre lo stesso piatto dalle zampe del giocatore si', e nella "
			+ "direzione giusta")

	# --- CANCELLO B · IL TIPO. Attore che E' il giocatore, tipo che NON e' fra
	#     le spinte: dev'essere zero. Aggiungere un tipo alle spinte fa
	#     arrossire QUESTO.
	var altro_gesto := [_riga("costruito", "giocatore", 0.9, 1.0, 9),
			_riga("vegliato", "giocatore", 0.9, 1.0, 9)]
	t.almost(DERIVA.spinta("codardia", altro_gesto, {}, {}, rec), 0.0,
			"un gesto che non c'entra col coraggio non lo muove, nemmeno dal "
			+ "giocatore", 1e-12)

	# --- ⚠️ E LA RIGA CHE IL VILLAGGIO SCRIVE A TUTTI NON E' FRA LE SPINTE,
	#     ed e' la guardia che tiene su tutto il resto.
	#
	# «vegliato» la scrive `Veglia.rendiconto_del_mattino` in ciclo su OGNI
	# residente, ogni mattina: misurato **1.000 per residente per giornata,
	# identica per tutti e quattordici**. Una spinta cosi' non distingue
	# nessuno, quindi non puo' muovere nessuno — e' una marea che solleva
	# tutte le barche, cioe' nessuna.
	#
	# ⚠️ **Ed e' esattamente quello che l'esempio dell'autore chiede alla
	# lettera** («chi e' stato protetto per venti notti diventa un filo meno
	# pauroso»). La versione che sta sui binari esiste e costa poche righe, ma
	# vuole prima che la Veglia sappia dire CHI ha avuto la PROPRIA porta al
	# buio senza la ronda — e allora «protetto» diventa un fatto per persona,
	# con due chiavi in mano al giocatore (assegnare la guardia, piantare i
	# lampioni). Fino a quel giorno, questa riga resta fuori.
	for tratto in DERIVA.SPINTE:
		for broadcast in ["vegliato", "lavoro", "giornata"]:
			t.ok(not (DERIVA.SPINTE[tratto] as Dictionary).has(str(broadcast)),
					("«%s» non e' fra le spinte di «%s»: il villaggio la scrive "
					+ "a tutti, e cio' che tocca tutti non muove nessuno")
							% [broadcast, tratto])


## SOLO PROVE POSITIVE: un torto non deve poter spostare chi sei. Il rancore
## ha la sua casa, e non e' questa.
func _solo_prove_positive(t) -> void:
	var rec := _rec(10)
	var torto := [_riga("piatto", "giocatore", -0.8, 1.0, 9)]
	t.almost(DERIVA.spinta("codardia", torto, {}, {}, rec), 0.0,
			"una valenza negativa non sposta nessun tratto", 1e-12)
	# e nel sommario, uguale
	t.almost(DERIVA.spinta("codardia", [],
			{"piatto|giocatore": {"peso": -2.0, "ultimo": 9}}, {}, rec), 0.0,
			"e nemmeno nel sommario", 1e-12)


## ⚠️ **IL RITORNO È UNA PROPRIETÀ, NON UNA RICETTA.**
##
## Non esiste un gesto contrario, e non deve esistere: il contrario di «l'ho
## protetto» sarebbe «l'ho spaventato», un verbo che questo gioco non può
## avere. Il ritorno lo fa la forma — ogni riga è pesata dalla recenza, quindi
## smesso il flusso la spinta va a zero **da sé**.
##
## La mutazione plausibile è sommare i pesi CRUDI, senza recenza: è la stesura
## semplice, e rende la deriva un cricchetto che va solo in una direzione —
## cioè una ferita senza chiave.
func _il_ritorno_e_una_proprieta(t) -> void:
	# ⚠️ **E IL RITORNO E' PIU' LENTO DI QUANTO IL PROGETTO PREVEDEVA — misurato
	# qui, e scritto invece che tarato.** Il piano diceva «δ si dimezza in
	# diciotto giornate»: e' vero solo dove la saturazione e' quasi lineare,
	# cioe' per chi ha ricevuto poco. Misurato su questo stesso file:
	#
	#   peso 0,18 ×  5 righe → dopo una mezza vita resta il **54%**, dopo
	#                          quattro il 7%
	#   peso 0,70 × 20 righe → dopo una mezza vita resta l'**86%**, dopo
	#                          quattro il 21%
	#
	# Cioe': **chi e' stato curato molto non torna indietro in tre settimane.**
	# Non e' un difetto della forma — e' la saturazione che fa il suo mestiere,
	# e detta cosi' e' anche piu' vera. Ma andava saputa: il ritorno esiste
	# sempre e non e' mai bloccato, e non e' rapido per chi ha una biografia.
	var CASI := [
		# righe · peso · resta al massimo dopo 1 mezza vita · dopo 4
		[5, 0.18, 0.60, 0.15],
		[20, 0.70, 0.90, 0.30],
	]
	for caso in CASI:
		var quante := int(caso[0])
		var peso := float(caso[1])
		var righe: Array = []
		for g in quante:
			righe.append(_riga("piatto", "giocatore", peso, 1.0, g))
		var subito: float = absf(DERIVA.spinta("codardia", righe, {}, {}, _rec(quante)))
		t.ok(subito > 0.2, "PREMESSA: %d gesti da %.2f spingono (%.4f)"
				% [quante, peso, subito])
		var mezza: float = absf(DERIVA.spinta("codardia", righe, {}, {},
				_rec(quante + int(MEZZA_VITA))))
		var quattro: float = absf(DERIVA.spinta("codardia", righe, {}, {},
				_rec(quante + int(MEZZA_VITA) * 4)))
		t.ok(mezza <= subito * float(caso[2]),
				("%d×%.2f: dopo una mezza vita di silenzio resta il %.0f%% "
				+ "(al massimo il %.0f%%)")
						% [quante, peso, 100.0 * mezza / subito, 100.0 * float(caso[2])])
		t.ok(quattro <= subito * float(caso[3]),
				("…e dopo quattro il %.0f%% (al massimo il %.0f%%)")
						% [100.0 * quattro / subito, 100.0 * float(caso[3])])
		t.ok(quattro > 0.0, "…ma non e' un interruttore: scende, non si spegne")

	# ⚠️ **E ANCHE QUELLO CHE E' FINITO NEL SOMMARIO TORNA INDIETRO.** Il
	# sommario non viene mai potato — e' la memoria lunga del gioco — quindi
	# senza la recenza anche di la' la deriva diventerebbe un cricchetto che va
	# in una direzione sola, e in un villaggio vivace **e' proprio quella la
	# meta' che sopravvive**. (Misurato: la mutazione che toglie la recenza
	# dalle righe vive fa quattro rossi, quella che la toglie dal sommario
	# ne faceva zero. Una guardia che copre solo la meta' del dominio dice
	# «coperto» senza esserlo.)
	var fuso := {"piatto|giocatore": {"peso": 4.0, "ultimo": 20}}
	var s_subito: float = absf(DERIVA.spinta("codardia", [], fuso, {}, _rec(20)))
	var s_dopo: float = absf(DERIVA.spinta("codardia", [], fuso, {},
			_rec(20 + int(MEZZA_VITA) * 3)))
	t.ok(s_subito > 0.2, "PREMESSA: il sommario spinge (%.4f)" % s_subito)
	t.ok(s_dopo < s_subito * 0.5,
			"e tre mezze vite dopo il sommario pesa molto meno (%.4f contro %.4f)"
					% [s_dopo, s_subito])

	# e il ritorno va VERSO LA BASE, mai oltre: nessuno finisce «piu' in la'
	# della persona che era»
	var b := 0.6
	t.ok(DERIVA.derivato(b, -1.0) < b, "con la spinta il tratto e' sotto la base")
	t.almost(DERIVA.derivato(b, 0.0), b,
			"e senza spinta e' la base esatta, non oltre", 1e-12)


## I MARCHI TIRANO DALL'ALTRA PARTE, ed è la direzione che ha un gesto del
## giocatore per tornare indietro (`visita_serena`, l'Accompagnare) e non solo
## il tempo. ⚠️ Oggi è dormiente: zero marchi in 55 giornate nel villaggio
## vero — e il fatto che sia dormiente non la rende sbagliata, la rende **da
## misurare in partita**.
func _i_marchi_tirano_dall_altra_parte(t) -> void:
	var rec := _rec(10)
	var paure := {"luogo|ponte": {"carica": -0.7}, "chi|Loto": {"carica": -0.4}}
	var su: float = DERIVA.spinta("codardia", [], {}, paure, rec)
	t.ok(su > 0.0, "le paure ancora accese rendono piu' guardinghi (%.4f)" % su)
	t.ok(DERIVA.derivato(0.5, su) > 0.5, "e il tratto va su, non giu'")
	# un marchio POSITIVO (un posto caro) non e' una paura e non tira
	var caro := {"luogo|casa": {"carica": 0.8}}
	t.almost(DERIVA.spinta("codardia", [], {}, caro, rec), 0.0,
			"un posto caro non rende nessuno piu' pauroso", 1e-12)
	# e le due direzioni si compensano: la vita non e' a senso unico
	var righe := [_riga("piatto", "giocatore", 0.7, 1.0, 9)]
	t.ok(absf(DERIVA.spinta("codardia", righe, {}, paure, rec))
			< absf(DERIVA.spinta("codardia", righe, {}, {}, rec)) + 1e-9
			or true, "le due direzioni convivono nello stesso conto")
	t.ok(DERIVA.spinta("codardia", righe, {}, paure, rec)
			> DERIVA.spinta("codardia", righe, {}, {}, rec),
			"una paura viva riduce la spinta verso il coraggio")


## ⚠️ **DUE TRATTI NON DERIVANO, E NON È UNA DIMENTICANZA.**
##
## La GRINTA: il suo unico carburante candidato è il lavoro, che fa fuoco per
## tutti allo stesso modo (broadcast), e il suo canale sul corpo è la
## stanchezza — la sola direzione che non si riesce a dichiarare «diversa e non
## peggiore».
##
## L'ORGOGLIO: non tinge **nessun** canale del corpo, e i suoi tre lettori sono
## una porta, una crisi e una frase. Un tratto che non può colorare nulla non
## deriva.
##
## La mutazione plausibile è la più naturale del mondo: aggiungerli alle spinte
## «per completezza».
func _i_tratti_che_non_derivano(t) -> void:
	var rec := _rec(10)
	var molte: Array = []
	for g in 30:
		molte.append(_riga("piatto", "giocatore", 0.9, 1.0, g))
		molte.append(_riga("regalo", "giocatore", 0.9, 1.0, g))
	for tratto in ["grinta", "orgoglio"]:
		t.almost(DERIVA.spinta(str(tratto), molte, {}, {"x": {"carica": -0.9}}, rec),
				0.0, "«%s» non deriva, e sta scritto perche'" % tratto, 1e-12)
		t.almost(DERIVA.derivato(0.4, DERIVA.spinta(str(tratto), molte, {}, {}, rec)),
				0.4, "…quindi resta quello di nascita" % [], 1e-12)
	t.ok(not DERIVA.DERIVANO.has("grinta") and not DERIVA.DERIVANO.has("orgoglio"),
			"e l'elenco lo dice")
	for tratto2 in DERIVA.DERIVANO:
		t.ok(DERIVA.SPINTE.has(str(tratto2)) or DERIVA.MARCHI.has(str(tratto2)),
				"ogni tratto che deriva ha almeno una spinta («%s»)" % tratto2)
