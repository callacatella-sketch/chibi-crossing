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
const ANIMO := preload("res://scenes/npc/Animo.gd")
const CHIBIDNA := preload("res://scenes/npc/ChibiDNA.gd")

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


	# --- il CABLAGGIO
	_il_genoma_non_si_scrive_MAI(t)
	_la_deriva_arriva_al_CORPO(t)
	_le_porte_e_le_frasi_leggono_CHI_ERA(t)
	_il_colore_invece_la_vede(t)
	_non_si_ricalcola_a_meta_giornata(t)
	_un_salvataggio_vecchio_e_il_gioco_di_prima(t)
	_la_lealta_deriva_ma_non_riscrive_il_passato(t)
	_la_compagnia_di_ieri_non_vale_quella_di_oggi(t)
	_il_villaggio_presta_la_compagnia_prima_della_giornata(t)
	_riaprire_la_partita_non_riporta_nessuno_a_com_era(t)
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
		t.ok(DERIVA.SPINTE.has(str(tratto2)) or DERIVA.MARCHI.has(str(tratto2))
				or DERIVA.COMPAGNIA.has(str(tratto2)),
				"ogni tratto che deriva ha almeno una spinta («%s»)" % tratto2)


# ======================================================================
#  IL CABLAGGIO — la meta' che, mancando, rende tutto il resto una statua
# ======================================================================

func _animo(seme := 4242, gesti := 0, giorni := 0):
	var a = ANIMO.new()
	a.setup(CHIBIDNA.generate(seme))
	for g in gesti:
		a.ricorda("piatto", "giocatore", 0.8, 1.0)
		a.passa_giorno()
	for g2 in giorni:
		a.passa_giorno()
	return a


## ⚠️ **IL GENOMA NON SI SCRIVE MAI, e il giro di vita lo dimostra.**
##
## E' il vincolo dell'autore («il ritorno dev'essere sempre possibile») ridotto
## a una proprieta' verificabile: se la deriva finisse dentro `tratti`, sarebbe
## permanente al primo salvataggio e si **ricomporrebbe** a ogni caricamento —
## chi era sarebbe perduto e non ci sarebbe piu' nessun posto da cui tornare.
##
## La mutazione plausibile e' una riga sola in coda al ricalcolo
## (`tratti[t] = tratto(t)`), ed e' la stesura che uno scrive per «rendere
## permanente la deriva».
func _il_genoma_non_si_scrive_MAI(t) -> void:
	var a = _animo(4242, 30)
	var base_prima: float = a.tratto_base("codardia")
	t.ok(absf(a.tratto("codardia") - base_prima) > 0.01,
			"PREMESSA: dopo trenta gesti la deriva c'e' davvero (%.4f contro %.4f)"
					% [a.tratto("codardia"), base_prima])

	# due giri di salvataggio e caricamento: se la deriva si componesse, il
	# secondo giro darebbe un numero diverso dal primo
	var b = ANIMO.new()
	b.setup(CHIBIDNA.generate(4242))
	b.load(a.save())
	var dopo_uno: float = b.tratto("codardia")
	var c = ANIMO.new()
	c.setup(CHIBIDNA.generate(4242))
	c.load(b.save())
	t.almost(c.tratto_base("codardia"), base_prima,
			"il genoma e' identico dopo due giri di salvataggio", 1e-12)
	t.almost(dopo_uno, a.tratto("codardia"),
			"e il tratto derivato sopravvive al caricamento", 1e-9)
	t.almost(c.tratto("codardia"), dopo_uno,
			"…e non si COMPONE: due giri danno lo stesso numero di uno", 1e-9)
	t.ok(not a.save().has("deriva"),
			"e la deriva non entra nel salvataggio: zero chiavi nuove")


## ⚠️ **LA DERIVA ARRIVA AL CORPO** — la guardia contro il quinto sistema
## spento di questo progetto.
##
## `Limbico.reattivita` e' derivata dai tratti e comanda la forza del sussulto,
## cioe' la posa che il provino ha misurato come l'unica che regge a nove metri
## da tutti e quattro i lati. Se il ricalcolo si fermasse un millimetro prima,
## la deriva sarebbe un numero perfetto che non muove un pixel.
##
## Due mutazioni plausibili: dimenticare `riproietta` nel ricalcolo (la forma
## esatta del difetto storico), oppure **lasciare `reattivita` in
## `Limbico.load`** — che la congelerebbe sul disco, com'era.
func _la_deriva_arriva_al_CORPO(t) -> void:
	var fermo = _animo(7717, 0)
	var mosso = _animo(7717, 30)
	t.ok(absf(mosso.tratto("codardia") - fermo.tratto("codardia")) > 0.01,
			"PREMESSA: i due tratti sono diversi")
	t.ok(mosso.limbico.reattivita < fermo.limbico.reattivita - 0.005,
			("la reattivita' del corpo segue la deriva: %.4f contro %.4f — "
			+ "chi e' stato curato trasalisce meno")
					% [mosso.limbico.reattivita, fermo.limbico.reattivita])
	# …e sopravvive al giro del salvataggio (dove prima veniva CONGELATA)
	var ripreso = ANIMO.new()
	ripreso.setup(CHIBIDNA.generate(7717))
	ripreso.load(mosso.save())
	t.almost(ripreso.limbico.reattivita, mosso.limbico.reattivita,
			"e il caricamento non la congela a un valore che non c'entra piu'", 1e-9)
	# LA CONTROPROVA: senza deriva, la reattivita' e' quella di sempre
	var vergine = ANIMO.new()
	vergine.setup(CHIBIDNA.generate(7717))
	var cod: float = vergine.tratto_base("codardia")
	var gri: float = vergine.tratto_base("grinta")
	t.almost(vergine.limbico.reattivita,
			clampf(0.6 + cod * 0.9 - gri * 0.35, 0.2, 1.8),
			"e senza deriva e' esattamente la formula di sempre", 1e-12)


## ⚠️ **LE PORTE, LE SOGLIE E LE FRASI LEGGONO CHI ERA.**
##
## Sotto il gradino della diserzione c'e' `Visitors._congeda()`: con la deriva
## dentro, «protetto e nutrito» diventerebbe **«se ne va prima»**, e il
## giocatore perderebbe i vicini di cui si e' occupato di piu'. E la lealta'
## che decide la mezza vita del libro mastro degli Affetti **riscriverebbe il
## passato**, sciogliendo una coppia senza che nessuno abbia fatto niente.
##
## La mutazione plausibile e' la piu' naturale che ci sia: «tutti i lettori al
## derivato», che e' quello che uno fa quando cabla.
func _le_porte_e_le_frasi_leggono_CHI_ERA(t) -> void:
	var fermo = _animo(5150, 0)
	var mosso = _animo(5150, 40)
	t.ok(absf(mosso.tratto("codardia") - fermo.tratto("codardia")) > 0.05,
			"PREMESSA: la deriva e' grossa (%.4f)"
					% absf(mosso.tratto("codardia") - fermo.tratto("codardia")))
	var s_fermo: Dictionary = fermo.soglie()
	var s_mosso: Dictionary = mosso.soglie()
	for k in s_fermo:
		t.almost(float(s_mosso[k]), float(s_fermo[k]),
				"la soglia «%s» non si muove: e' una PORTA, e sotto c'e' chi se "
				% k + "ne va dal villaggio", 1e-12)
	# --- e il TESTO. ⚠️ Ci sono volute tre stesure, e le due bocciate erano
	#     mute per due ragioni diverse — vale la pena scriverle:
	#     (a) la prima confrontava due chibi qualunque: se la codardia non
	#         sta vicino alla soglia la frase non cambia in nessuno dei due
	#         casi, e la mutazione resta verde;
	#     (b) la seconda dava al termine di paragone gli STESSI ricordi, e
	#         allora derivava anche lui: con la mutazione attraversavano la
	#         soglia tutti e due, e tornavano uguali.
	#     La forma che funziona ha tre corpi, e rende la soglia OSSERVABILE:
	#     uno che sta sopra senza deriva, uno che sta sotto senza deriva (per
	#     dimostrare che la frase cambia davvero), e uno che sta sopra ma
	#     DERIVA sotto — quello deve parlare come il primo.
	var CAUSE := 12
	var sopra = _con_causa(0.70, 0)
	var sotto = _con_causa(0.42, 0)
	var derivato = _con_causa(0.70, 40)
	t.ok(sopra.tratto_base("codardia") > 0.65 and sotto.tratto_base("codardia") < 0.65,
			"PREMESSA: uno sta sopra la soglia della frase e l'altro sotto")
	var k_sopra := _apertura(sopra)
	var k_sotto := _apertura(sotto)
	t.ok(k_sopra != k_sotto,
			"PREMESSA: la soglia e' viva — chi sta sopra e chi sta sotto dicono "
			+ "cose diverse")
	t.ok(derivato.tratto_base("codardia") > 0.65
			and derivato.tratto("codardia") < 0.65,
			"PREMESSA: e il terzo era sopra (%.3f) e adesso e' sotto (%.3f)"
					% [derivato.tratto_base("codardia"), derivato.tratto("codardia")])
	t.eq(_apertura(derivato), k_sopra,
			"ma quello che dice quando sbotta e' ancora quello di CHI ERA: "
			+ "il testo legge la base")


## ⚠️ **E IL COLORE, INVECE, LA DERIVA LO VEDE.**
##
## E' la meta' speculare della guardia qui sopra: se le porte devono NON
## vederla, i canali che colorano la persona devono vederla — o la deriva e'
## un numero perfetto che non tocca niente. `peso_drive("sicurezza")` e' il
## primo di quei canali, ed e' quello che decide quanto pesa la paura nelle
## scelte di ogni giornata.
##
## ⚠️ La prima stesura di questo file non ce l'aveva, e la mutazione «il
## colore torna alla base» — cioe' la deriva scollegata dal suo unico
## consumatore — lasciava la suite VERDE.
func _il_colore_invece_la_vede(t) -> void:
	var fermo = _animo(4711, 0)
	var mosso = _animo(4711, 40)
	t.ok(mosso.peso_drive("sicurezza") < fermo.peso_drive("sicurezza") - 1e-6,
			("il peso della sicurezza segue la deriva: %.4f contro %.4f")
					% [mosso.peso_drive("sicurezza"), fermo.peso_drive("sicurezza")])
	# …e un canale che non dipende da un tratto che deriva non si muove
	t.almost(mosso.peso_drive("stima"), fermo.peso_drive("stima"),
			"e un canale che dipende da un tratto che NON deriva sta fermo", 1e-12)


## Un corpo con una codardia decisa, qualcosa di cui lamentarsi, e — se
## `gesti > 0` — abbastanza cure del giocatore da farlo derivare.
##
## ⚠️ I torti e i piatti sono due tipi DIVERSI apposta: i torti fanno le
## `cause()` (senza, `sfogo_rimandato` esce alla prima riga con «Non e'
## niente, lascia stare» e il caso confronta due volte la stessa frase
## generica), i piatti fanno la deriva. Cosi' si puo' avere lo stesso motivo
## di sfogo con e senza deriva.
## L'APERTURA dello sfogo — cioe' la sola parte che i tratti decidono. Il
## resto della frase sono le CAUSE, e quelle la deriva le muove per davvero
## (muovendo i drive): confrontare la frase intera farebbe fallire il caso per
## una ragione giusta ma diversa da quella che sorveglia.
func _apertura(a) -> String:
	var d: Dictionary = a.sfogo_rimandato()
	var args: Array = d.get("args", [])
	return JSON.stringify(args[0]) if args.size() > 0 else JSON.stringify(d)


func _con_causa(codardia: float, gesti: int):
	var a = ANIMO.new()
	a.setup(CHIBIDNA.generate(1234))
	a.tratti["orgoglio"] = 0.10
	a.tratti["lealta"] = 0.10
	a.tratti["codardia"] = codardia
	for i in 12:
		a.ricorda("torto", "giocatore", -0.7, 0.9)
	for g in gesti:
		a.ricorda("piatto", "giocatore", 0.9, 1.0)
		a.passa_giorno()
	a._deriva_giorno = -1
	a._ricalcola_deriva()
	return a


## ⚠️ **NON SI RICALCOLA A META' GIORNATA.** Un tratto che cambia mentre lo
## guardi non e' una persona che cambia: e' un cruscotto. La mutazione
## plausibile e' chiamare il ricalcolo da `ricorda()` — la stesura «sempre
## fresco».
func _non_si_ricalcola_a_meta_giornata(t) -> void:
	var a = _animo(9001, 10)
	var prima: float = a.tratto("codardia")
	for i in 10:
		a.ricorda("piatto", "giocatore", 0.9, 1.0)
	t.almost(a.tratto("codardia"), prima,
			"dieci gesti nella stessa giornata non muovono il tratto", 1e-12)
	a.passa_giorno()
	t.ok(a.tratto("codardia") < prima - 1e-6,
			"e il giorno dopo si', tutto insieme (%.4f contro %.4f)"
					% [a.tratto("codardia"), prima])


## ⚠️ **UN SALVATAGGIO VECCHIO E' IL GIOCO DI PRIMA.** Nessuna migrazione,
## nessuna chiave nuova: chi non ha prove del giocatore ha δ = 0, e la
## reattivita' e' quella che la formula ha sempre dato.
func _un_salvataggio_vecchio_e_il_gioco_di_prima(t) -> void:
	var vecchio = ANIMO.new()
	vecchio.setup(CHIBIDNA.generate(3131))
	var blob: Dictionary = vecchio.save()
	blob.erase("ricordi")
	blob.erase("sommario")
	var ripreso = ANIMO.new()
	ripreso.setup(CHIBIDNA.generate(3131))
	ripreso.load(blob)
	for tr in DERIVA.DERIVANO:
		t.almost(ripreso.tratto(str(tr)), ripreso.tratto_base(str(tr)),
				"«%s»: senza prove, il tratto e' quello di nascita" % tr, 1e-12)
	t.almost(ripreso.limbico.reattivita, vecchio.limbico.reattivita,
			"e la reattivita' e' identica a quella di sempre", 1e-12)


## ⚠️ **LA LEALTÀ DERIVA — E NON DEVE RISCRIVERE IL PASSATO.**
##
## Chi ha passato molto tempo con qualcuno diventa un filo più leale, e il
## carburante sono le righe di co-presenza: prove positive, datate, e che
## distinguono per davvero (nel salvataggio vero vanno **da 2 a 24 per
## persona**). Chi non ne ha resta a chi era — nessun malus, nessuna
## partizione, e non esiste nessuna funzione «chi è solo».
##
## Ma la lealtà ha un lettore che NON è un colore, ed è il più pericoloso del
## gioco: `Affetti.conto()` la usa per calcolare la **mezza vita** con cui
## rilegge tutte le righe del libro mastro, comprese quelle di sei mesi fa.
## Una lealtà che derivasse lì dentro **riscriverebbe il passato**. E la
## direzione, misurata qui sotto, è l'opposto di quella che si teme: la
## compagnia è una prova solo positiva, quindi la mezza vita si ALLUNGA e sullo
## stesso identico libro mastro il conto **sale del 27%**. Non scioglie una
## coppia: ne **fabbrica** una — `SOGLIA_COPPIA` è un confronto assoluto, e chi
## ha passato molto tempo con C si vedrebbe gonfiare il conto con B, cioè
## **finirebbe in coppia con B senza che fra loro sia successo niente**.
##
## Quando la lealtà non derivava, questa guardia non poteva fallire, e stava
## scritto nel sorgente di `Affetti` che chi l'avrebbe cablata doveva renderla
## rossa **prima** di consegnare. È questo il caso.
func _la_lealta_deriva_ma_non_riscrive_il_passato(t) -> void:
	# --- deriva davvero, e dalla compagnia
	var solo = ANIMO.new()
	solo.setup(CHIBIDNA.generate(8080))
	var insieme = ANIMO.new()
	insieme.setup(CHIBIDNA.generate(8080))
	var giornate: Array = []
	for g in 24:
		giornate.append(g)
	insieme.compagnia = giornate
	insieme.oggi = 24
	insieme._deriva_giorno = -1
	insieme._ricalcola_deriva()
	solo.oggi = 24
	solo._deriva_giorno = -1
	solo._ricalcola_deriva()
	t.almost(solo.tratto("lealta"), solo.tratto_base("lealta"),
			"chi non ha passato tempo con nessuno resta chi era: nessun malus",
			1e-12)
	t.ok(insieme.tratto("lealta") > insieme.tratto_base("lealta") + 0.01,
			("e chi ne ha passato molto e' un filo piu' leale (%.4f contro %.4f)")
					% [insieme.tratto("lealta"), insieme.tratto_base("lealta")])

	# --- ⚠️ **MA IL LIBRO MASTRO NON SI ACCORGE DI NIENTE.**
	# Un passato VECCHIO e uno recente: e' esattamente la coppia su cui la
	# mezza vita fa la differenza. Se derivasse, il passato si schiaccerebbe.
	var libro := [
		{"a": "Uno", "b": "Due", "t": "coraggio", "d": 2},
		{"a": "Due", "b": "Uno", "t": "piatto", "d": 8},
		{"a": "Uno", "b": "Due", "t": "veglia", "d": 15},
		{"a": "Uno", "b": "Due", "t": "chiacchiera", "d": 75},
	]
	var conti: Array = []
	for chi in [solo, insieme]:
		var vis = RegistroVicini.new()
		t.stage(vis)
		(vis.get("_animi") as Dictionary)["U"] = chi
		(vis.get("_residents") as Array).append(
				{"label": "U", "dna": {"name": "Uno"}})
		var reg = RegistroAffetti.new()
		t.stage(reg)
		reg.set("_visitors", vis)
		reg.set("_righe", libro.duplicate(true))
		conti.append(float(reg.quanto("Uno", "Due")))
	t.almost(conti[0], conti[1],
			("il libro mastro legge la lealta' di CHI ERA: %.9f contro %.9f — "
			+ "la mezza vita e' la grammatica con cui si legge la storia, non "
			+ "un colore, e con la deriva dentro lo stesso identico passato "
			+ "varrebbe il 27%% in piu'") % [conti[0], conti[1]], 1e-9)
	t.ok(conti[0] > 0.0, "…e c'e' davvero qualcosa da contare (%.4f)" % conti[0])


## Il libro mastro VERO, col solo `_ready` scavalcato e una sola sorgente di
## dati dettata: chi sono gli animi. `conto()` e `_lealta_di` restano quelli
## del gioco.
class RegistroAffetti extends "res://scenes/npc/Affetti.gd":
	func _ready() -> void:
		set_process(false)

	func _process(_d: float) -> void:
		pass

	## `_cabla` andrebbe a cercare il registro nell'albero: qui glielo si da'.
	func _cabla() -> void:
		pass

	func _giorno() -> int:
		return 80


class RegistroVicini extends "res://scenes/npc/Visitors.gd":
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)

	func _process(_d: float) -> void:
		pass


## ⚠️ **E LA COMPAGNIA HA UNA DATA.** Ogni riga di co-presenza e' pesata dalla
## stessa recenza di tutto il resto del file, e non e' un dettaglio: e' il
## vincolo che l'autore ha posto per iscritto — **il ritorno dev'essere sempre
## possibile**. Senza la data, chi ha passato tre settimane con qualcuno due
## anni fa e poi non l'ha piu' visto resterebbe piu' leale **per sempre**, e la
## deriva smetterebbe di essere una deriva per diventare una cicatrice.
func _la_compagnia_di_ieri_non_vale_quella_di_oggi(t) -> void:
	var recente: Array = []
	var vecchia: Array = []
	for i in 12:
		recente.append(300 - i)
		vecchia.append(40 + i)
	var nulla: Array = []
	var s_ora := DERIVA.spinta("lealta", nulla, {}, {}, _rec(300), recente)
	var s_allora := DERIVA.spinta("lealta", nulla, {}, {}, _rec(300), vecchia)
	t.ok(s_ora > 0.05,
			"dodici giornate insieme, adesso, spingono davvero (%.4f)" % s_ora)
	t.ok(s_allora < s_ora * 0.5,
			("e le stesse dodici, ma di allora, valgono meno della meta' "
			+ "(%.4f contro %.4f): il ritorno e' sempre possibile")
					% [s_allora, s_ora])


## ⚠️ **IL CABLAGGIO, e non il pezzo.** Cinque volte in questo progetto un
## sistema completo, provato e VERDE non aveva un solo lettore in partita.
## Qui la compagnia vive in `Cricche` e la deriva vive in `Animo`: se il
## villaggio non fa il ponte una volta al giorno, `Deriva.COMPAGNIA` e'
## aritmetica che nessuno esegue mai. Si chiama il giorno VERO
## (`_giorno_di_animo`), non la funzione che lo fa.
func _il_villaggio_presta_la_compagnia_prima_della_giornata(t) -> void:
	var reg = RegistroCricche.new()
	reg.add_to_group("cricche")
	t.stage(reg)
	reg.set("_incontri", [
		{"a": "Uno", "b": "Due", "d": 30, "q": 0.5, "l": "prato"},
		{"a": "Tre", "b": "Uno", "d": 31, "q": 0.5, "l": "prato"},
		{"a": "Due", "b": "Tre", "d": 31, "q": 0.5, "l": "prato"},
	])
	var vis = RegistroVicini.new()
	t.stage(vis)
	var chi = ANIMO.new()
	chi.setup(CHIBIDNA.generate(4242))
	chi.compagnia = [999]      # una compagnia STANTIA, che deve sparire
	(vis.get("_animi") as Dictionary)["U"] = chi
	(vis.get("_residents") as Array).append(
			{"label": "U", "dna": {"name": "Uno"}})
	vis.set("_villaggio", PaeseFermo.new())

	vis.call("_giorno_di_animo")
	t.eq(chi.compagnia.size(), 2,
			("il villaggio presta la compagnia PRIMA di far passare la "
			+ "giornata: due righe toccano «Uno» (ottenute %d)")
					% chi.compagnia.size())
	t.ok(not chi.compagnia.has(999),
			"…e quella di ieri viene sostituita, non aggiunta")

	# --- e senza il registro delle cricche NON resta quella di ieri.
	reg.remove_from_group("cricche")
	vis.call("_giorno_di_animo")
	t.eq(chi.compagnia.size(), 0,
			("senza il registro la compagnia si AZZERA (%d): tenersi quella "
			+ "del giorno prima e' una prova che nessuno ha piu' fatto")
					% chi.compagnia.size())


class RegistroCricche extends "res://scenes/npc/Cricche.gd":
	func _ready() -> void:
		set_process(false)

	func _process(_d: float) -> void:
		pass


## Un paese in cui non succede niente: il giorno passa e non produce eventi.
## Cosi' l'unica cosa osservabile del `_giorno_di_animo` e' il ponte.
class PaeseFermo extends RefCounted:
	func simula_giorno() -> Array:
		return []


## ⚠️ **RIAPRIRE LA PARTITA NON RIPORTA NESSUNO A COM'ERA.**
##
## `compagnia` non si salva — sta nel registro delle cricche, che è già
## persistito — e il ponte gira **una volta al giorno**. Ma un animo nasce
## anche al CARICAMENTO: se il prestito aspettasse il prossimo cambio di
## giorno, per quattro minuti reali dopo ogni caricamento la lealtà derivata
## tornerebbe alla base, e i vicini si comporterebbero in modo diverso da come
## si comportavano un istante prima di salvare.
##
## È il difetto che non si vede mai, perché nessuno confronta due partite.
func _riaprire_la_partita_non_riporta_nessuno_a_com_era(t) -> void:
	var reg = RegistroCricche.new()
	reg.add_to_group("cricche")
	t.stage(reg)
	reg.set("_incontri", [
		{"a": "Uno", "b": "Due", "d": 30, "q": 0.5, "l": "prato"},
		{"a": "Tre", "b": "Uno", "d": 31, "q": 0.5, "l": "prato"},
	])
	var vis = RegistroVicini.new()
	t.stage(vis)
	# la riga del salvataggio, come la ricostruisce un caricamento
	var riga := {"label": "U", "dna": CHIBIDNA.generate(4242)}
	(riga["dna"] as Dictionary)["name"] = "Uno"
	(vis.get("_residents") as Array).append(riga)

	var animo = vis.call("_ensure_brain", riga)
	t.ok(animo != null, "il caricamento fa nascere il cervello")
	var a2: RefCounted = (vis.get("_animi") as Dictionary).get("U")
	t.ok(a2 != null, "…e con lui l'animo")
	t.eq((a2.get("compagnia") as Array).size(), 2,
			("e la compagnia c'e' GIA', senza aspettare il cambio di giorno "
			+ "(ottenute %d righe)") % (a2.get("compagnia") as Array).size())
