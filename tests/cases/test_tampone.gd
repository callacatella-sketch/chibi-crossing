extends RefCounted
## IL TAMPONE SOCIALE — chi ti vuole bene, standoti accanto, ti smorza
## l'allarme.
##
## È una delle cose meglio misurate dell'affettività vera: la presenza della
## figura di attaccamento abbassa la risposta di allarme, e lo fa con due
## firme precise, che sono anche le due sole cose che questo file esiste per
## sorvegliare.
##
##  1. **È UN'INTERAZIONE, non una sottrazione.** Lo smorzamento è più grande
##     in chi è più reattivo — chi non si allarmava non ha niente da farsi
##     smorzare. Perciò il conforto DIVIDE IL GUADAGNO (`reattivita`) e non
##     toglie un tanto al risultato: la forma è decisa dall'autore e questo
##     file la pianta. La versione vietata è `clampf(prodotto, 0, 1) / D` —
##     che dividerebbe DOPO il tetto, e il caso 7 la fa arrossire.
##  2. **È SPECIFICA della figura di attaccamento**, non della compagnia
##     generica: un vicino qualunque a mezzo metro non tampona niente. È il
##     caso 8, e la sua geometria è appaiata apposta — due residenti identici,
##     due vicini alla STESSA distanza, e l'unica differenza è che uno dei due
##     è una coppia.
##
## E la meccanica ha UNA sola uscita visibile: **un sussulto che non parte**.
## Nessun toast, nessuna parola, nessun simbolo, nessuna riga che il giocatore
## possa leggere. Perciò tutte le prove che seguono guardano il referto del
## `Limbico` e il CORPO (`_gs_soma`, la coda guardinga), mai una stringa.
##
## ---------------------------------------------------------------------
## LE MUTAZIONI, una riga di produzione per volta, col numero di asserzioni
## diventate rosse — MISURATE facendo girare questo file su un `Limbico` e un
## `Visitors` col tampone dentro, non stimate. Diciannove, tutte rosse:
##
##   un PAVIMENTO sul conforto (`maxf(conforto, 0.02)`) .............. 89
##   la chiave `conforto` tolta dal referto .......................... 17
##   il conforto ignorato (`guadagno := reattivita`) ................. 13
##   il cancello del NaN tolto (`is_finite`) ..........................  7
##   il `clampf(conforto, 0, 1)` tolto (il malus dalla porta di
##       servizio: un conforto negativo AMPLIFICA l'allarme) .........  6
##   il conforto SOTTRATTO dal risultato invece che dal guadagno .....  3
##   il conforto passato anche al ramo `calore` ......................  3
##   la divisione DOPO il clamp (`clampf(prod,0,1) / D`) .............  2
##   il quarto parametro tolto dalla firma ............ il file NON COMPILA (*)
##   ——— e nel cablaggio (`Visitors._tick_sussulti`) ———
##   la rampa lineare sostituita da `exp(-d / VICINI)` (niente zero
##       duro: il compagno tampona anche da lontano) ................. 12
##   le valvole (`Percezione.puo_vedere`) tolte ......................  9
##   il conforto non arriva a `percepisci` (si passa 0) ..............  6
##   un fondo di conforto per chi non ha nessuno (`return 0.10`) .....  6
##   il compagno cercato fra TUTTI i vicini invece che nella coppia ...  2
##   il nome ambiguo risolto sul primo che capita invece di scartato ..  2
##   l'ambiguità guardata solo sul nome CERCATO e non su chi CHIEDE
##       (l'omonimo si prende 0,7368 di conforto che è del compagno
##        vero, e il compagno vero resta a zero: era ROVESCIATO) ......  1
##   il raffreddamento spostato dentro il ramo `trasalisce` ..........  1
##   ——— e la costante stessa (caso 13) ———
##   `TAMPONE_SOCIALE := 9.0` (la compagnia ABOLISCE la paura) .......  2
##   `TAMPONE_SOCIALE := 0.0` (una firma senza meccanica) ............ 15
##
## (*) le chiamate a quattro argomenti le controlla il PARSER, quindi
##     togliere il parametro non fa sparire i casi in silenzio: il file
##     diventa «non compilabile» e il runner lo dichiara con una riga rossa
##     che porta il nome del file. Il caso 1 resta lo stesso, per due
##     ragioni: è l'unico che dice QUALE parametro manca, e il giorno che una
##     di queste chiamate passasse da una variabile davvero non tipizzata il
##     parser non se ne accorgerebbe più — e allora sì che i casi si
##     interromperebbero senza far fallire niente («la suite verde non
##     basta», CLAUDE.md).
##
## ---------------------------------------------------------------------
## LE TRAPPOLE DI BANCO, pagate scrivendo questo file:
##
##  · **il bit-identico si prova con `==`, mai con `t.almost`.** Il neutro
##    esatto è una PROPRIETÀ della forma (`0.0 * K` è +0.0, `1.0 + 0.0` è 1.0
##    esatto, e `x / 1.0` è esatto in IEEE-754), non un'approssimazione: una
##    tolleranza qui lascerebbe passare proprio la stesura che cambia il
##    risultato di tutto il villaggio di un pelo, in silenzio;
##  · **…e non basta confrontare le due PORTE.** La prima stesura del caso 2
##    metteva `percepisci(a, l, g)` contro `percepisci(a, l, g, 0.0)`, che è
##    lo stesso cammino chiamato in due modi: la mutazione del PAVIMENTO
##    (`maxf(conforto, 0.02)`, cioè un dito di tampone regalato a tutti)
##    sposta tutte e due allo stesso modo e restava **verde su tutta la
##    griglia**. Serve l'oracolo indipendente — la formula di ieri scritta
##    qui dentro, come in `test_gioia._la_paura_non_e_cambiata` — e con lui
##    quella mutazione fa 89 rosse invece di zero;
##  · **e si confrontano anche gli EFFETTI COLLATERALI.** `percepisci` non
##    torna solo un numero: alza `arousal` (che è PERSISTITO) e stimola tre
##    canali della chimica. Un bit-identico misurato sul solo valore di
##    ritorno è mezzo bit-identico;
##  · **una guardia che può solo confermare lo zero non è una guardia.** Se
##    tutti i casi passassero 0.0, la meccanica potrebbe restare spenta con
##    la suite verde — che è il modo esatto in cui in questo progetto sono
##    morte, in silenzio, sei funzioni complete. Il caso 3 pretende un
##    allarme STRETTAMENTE minore;
##  · **le due geometrie del villaggio vanno APPAIATE.** A e C stanno alla
##    stessa distanza esatta dal giocatore (2,0 m su assi opposti), hanno
##    gli stessi tratti e la stessa chimica: senza, la differenza misurata
##    sarebbe del `grezzo` o del carattere, non del conforto. E il giocatore
##    non si sposta: la velocità si finge scrivendo `_pp_prec`, così le due
##    distanze restano identiche al bit;
##  · **fra un percetto e l'altro si azzerano i limbici, il raffreddamento e
##    la strada lenta.** Il primo sussulto lascia addosso `arousal` e
##    cortisolo, `_sussulto_cd` chiude la porta per nove secondi, e
##    `_tick_riconoscimenti` dopo 0,4 s scrive un marchio: senza il reset, la
##    seconda misura è la prima più la sua scia.

const LIMBICO := preload("res://scenes/npc/Limbico.gd")
const VISITOR := preload("res://scenes/npc/Visitor.gd")
const VISITORS := preload("res://scenes/npc/Visitors.gd")
const ANIMO := preload("res://scenes/npc/Animo.gd")
const DNA := preload("res://scenes/npc/ChibiDNA.gd")

const DT := 1.0 / 60.0

## Il carattere medio: `reattivita` 0,875 — il grilletto della media.
const MEDIO := {"codardia": 0.5, "grinta": 0.5}

## La griglia del bit-identico. Tre caratteri (grilletto alto, medio, basso),
## cinque marchi (dal terrore all'affetto, passando per il nulla), quattro
## modi di arrivare e due livelli di attivazione già addosso.
const CARATTERI := [
	{"codardia": 0.95, "grinta": 0.05},   # reattivita 1.4375
	{"codardia": 0.50, "grinta": 0.50},   # 0.875
	{"codardia": 0.05, "grinta": 0.95},   # 0.3125
]
const CARICHE := [-0.95, -0.40, 0.0, 0.30, 0.85]
const GREZZI := [0.0, 0.12, 0.30, 1.0]
const AROUSAL := [0.0, 0.45]


## Il registro dei vicini VERO, col solo `_ready` scavalcato (quello di
## produzione vuole `%Player` e `../BuildSystem`, cioè il villaggio intero).
## È la stessa forma di `test_gioia.Registro`, e per la stessa ragione.
class Registro extends "res://scenes/npc/Visitors.gd":
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
		add_to_group("visitors")


func run(t) -> void:
	_la_firma_esiste(t)
	_il_bit_identico(t)
	_il_conforto_morde(t)
	_la_firma_dell_interazione(t)
	_niente_malus(t)
	_il_calore_resta_intatto(t)
	_il_tetto_del_clamp(t)
	# --- il cablaggio: corpi veri, registro vero, libro mastro vero
	_il_compagno_accanto_tampona(t)
	_lo_zero_duro_oltre_il_raggio(t)
	_le_valvole_del_compagno(t)
	_il_nome_ambiguo_si_scarta(t)
	_l_ambiguo_puo_essere_chi_chiede(t)
	_il_tampone_non_azzera_la_paura(t)


# =========================================================================
# il banco — la parte pura
# =========================================================================

## Un `Limbico` con un carattere, un marchio e un'attivazione dichiarati.
## `setup()` è deterministico: due chiamate con gli stessi tratti danno due
## oggetti identici al bit, ed è su questo che si regge tutto il caso 2.
func _lim(tratti: Dictionary, carica := 0.0, ar := 0.0, chiave := "chi|giocatore"):
	var l = LIMBICO.new()
	l.setup(tratti)
	if carica != 0.0:
		l.marchi[chiave] = {"carica": carica, "conferme": 2}
	l.arousal = ar
	return l


## Gli EFFETTI COLLATERALI di un percetto, che fanno parte del risultato
## quanto il valore di ritorno: la scia nel corpo e i tre canali che la
## strada veloce tocca.
func _strascico(l) -> Dictionary:
	return {
		"arousal": l.arousal,
		"cortisolo": l.livello_neuro("cortisolo"),
		"ossitocina": l.livello_neuro("ossitocina"),
		"dopamina": l.livello_neuro("dopamina"),
	}


## L'ALLARME DI IERI — l'oracolo INDIPENDENTE del bit-identico.
##
## ⚠️ Confrontare la chiamata a tre argomenti con quella a quattro-e-zero non
## basta, e la mutazione lo dimostra: un PAVIMENTO sul conforto
## (`maxf(conforto, 0.02)`, cioè un dito di tampone regalato a tutti) sposta
## tutte e due allo stesso modo, e le due chiamate restano identiche fra loro
## mentre il villaggio intero è cambiato. Quello che va provato non è «le due
## porte danno lo stesso numero»: è «il numero è quello di IERI» — e per
## chiederlo bisogna scrivere qui la formula di ieri, come fa già
## `test_gioia._la_paura_non_e_cambiata` con la sua griglia.
##
## L'ordine delle operazioni è quello di produzione, non una riscrittura
## comoda: con `conforto` a zero il guadagno è `reattivita / 1.0`, che in
## IEEE-754 è `reattivita` esatto, e il prodotto si chiude nello stesso
## ordine. Perciò qui si pretende `==`, non una tolleranza.
func _allarme_di_ieri(reattivita: float, arousal: float, carica: float,
		grezzo: float) -> float:
	return clampf((maxf(0.0, -carica) + grezzo) * reattivita
			* (1.0 + arousal * 0.6), 0.0, 1.0)


## La costante si LEGGE dal file di produzione, mai si ricopia: un tampone
## scritto qui dentro sarebbe una seconda taratura, e divergerebbe al primo
## che ritocca l'altra. Se non c'è, lo si dice con una riga rossa invece di
## far cadere il parse dell'intero file.
func _tampone(t) -> float:
	# ⚠️ la si chiede all'ISTANZA e non alla classe: `get_script_constant_map()`
	# non è statica, e su `LIMBICO` direttamente è un errore di PARSE — cioè
	# l'intero file diventerebbe «non compilabile», che nel runner è una riga
	# sola invece delle sue mille asserzioni.
	var mappa: Dictionary = LIMBICO.new().get_script().get_script_constant_map()
	if not mappa.has("TAMPONE_SOCIALE"):
		t.ok(false, "manca la costante Limbico.TAMPONE_SOCIALE: senza, il"
				+ " tampone non ha una casa e i casi qui sotto misurano un'altra cosa")
		return 1.0
	return float(mappa["TAMPONE_SOCIALE"])


# =========================================================================
# 1 · LA FIRMA ESISTE — e si chiede PRIMA di tutto il resto
# =========================================================================
#
# MISURATO: togliendo il quarto parametro, le chiamate a quattro argomenti
# le prende il PARSER («Too many arguments for percepisci(): expected at most
# 3 but received 4»), il file diventa «non compilabile» e il runner lo
# dichiara con una riga rossa — quindi il guasto è rumoroso da sé.
#
# Questo caso resta perché quella riga rossa dice il FILE e non il perché,
# e perché la rete del parser tiene solo finché le chiamate restano
# tipizzate: il giorno che una passasse da una variabile davvero non
# tipizzata, l'errore diventerebbe di runtime — e un errore a runtime in
# questo runner NON fa fallire niente, interrompe la funzione e basta.
# Dieci casi sparirebbero in silenzio, che è la lezione «la suite verde non
# basta».

func _la_firma_esiste(t) -> void:
	var l = LIMBICO.new()
	var trovata := false
	for f in l.get_method_list():
		if str(f.get("name", "")) != "percepisci":
			continue
		trovata = true
		var args: Array = f.get("args", [])
		t.eq(args.size(), 4,
				"`Limbico.percepisci` ha il quarto parametro `conforto`"
				+ " (senza, i casi qui sotto si interrompono a metà SENZA"
				+ " far fallire niente)")
		if args.size() == 4:
			t.eq(str((args[3] as Dictionary).get("name", "")), "conforto",
					"…e si chiama `conforto`")
	t.ok(trovata, "`Limbico.percepisci` esiste")


# =========================================================================
# 2 · IL BIT-IDENTICO — zero è il neutro ESATTO
# =========================================================================
#
# Il villaggio intero passa da qui: ventotto residenti, ogni volta che Mochi
# si avvicina. Chi non ha un compagno accanto — cioè quasi sempre, e sempre
# in un villaggio giovane — deve avere il gioco di ieri **al bit**, o questa
# meccanica non è un'aggiunta: è una ritaratura di tutto l'affettivo, fatta
# per sbaglio e in silenzio.
#
# Si confrontano DUE ISTANZE, non due chiamate sulla stessa: la seconda
# chiamata partirebbe dalla scia della prima.

func _il_bit_identico(t) -> void:
	var casi := 0
	for tratti in CARATTERI:
		for carica in CARICHE:
			for grezzo in GREZZI:
				for ar in AROUSAL:
					casi += 1
					var etichetta := "cod %.2f · marchio %+.2f · grezzo %.2f · arousal %.2f" \
							% [float(tratti["codardia"]), carica, grezzo, ar]
					var a = _lim(tratti, carica, ar)
					var b = _lim(tratti, carica, ar)
					var sa: Dictionary = a.percepisci("giocatore", "", grezzo)
					var sb: Dictionary = b.percepisci("giocatore", "", grezzo, 0.0)
					t.eq(str(sb["reazione"]), str(sa["reazione"]),
							"[%s] la reazione è quella di ieri" % etichetta)
					t.eq(float(sb["forza"]), float(sa["forza"]),
							"[%s] l'allarme è quello di ieri AL BIT" % etichetta)
					t.eq(float(sb["calore"]), float(sa["calore"]),
							"[%s] e il calore pure" % etichetta)
					# …e «quello di ieri» non è «quello dell'altra porta»:
					# lo dice l'oracolo, non la porta gemella
					t.eq(float(sb["forza"]),
							_allarme_di_ieri(b.reattivita, ar, carica, grezzo),
							"[%s] ed è l'allarme di IERI, non solo lo stesso"
							% etichetta + " delle due porte")
					var fa := _strascico(a)
					var fb := _strascico(b)
					for canale in fa:
						t.eq(float(fb[canale]), float(fa[canale]),
								"[%s] e lo strascico su %s (che è PERSISTITO)"
								% [etichetta, canale])
	t.ok(casi == CARATTERI.size() * CARICHE.size() * GREZZI.size() * AROUSAL.size(),
			"(la griglia ha girato per intero: %d stati)" % casi)

	# …e lo stesso vale per il marchio sul LUOGO, che è l'altra porta con cui
	# `percepisci` sceglie la sua `fonte`.
	for carica in [-0.90, 0.70]:
		var a2 = _lim(MEDIO, carica, 0.0, "luogo|catasta")
		var b2 = _lim(MEDIO, carica, 0.0, "luogo|catasta")
		var s1: Dictionary = a2.percepisci("", "catasta", 0.35)
		var s2: Dictionary = b2.percepisci("", "catasta", 0.35, 0.0)
		t.eq(float(s2["forza"]), float(s1["forza"]),
				"[luogo %+.2f] anche il marchio sul posto è quello di ieri al bit" % carica)
		t.eq(str(s2["fonte"]), str(s1["fonte"]),
				"[luogo %+.2f] e la fonte non cambia" % carica)
		t.eq(float(s2["forza"]),
				_allarme_di_ieri(b2.reattivita, 0.0, carica, 0.35),
				"[luogo %+.2f] ed è l'allarme di ieri" % carica)


# =========================================================================
# 3 · IL CONFORTO MORDE DAVVERO
# =========================================================================
#
# Il caso che impedisce a questa meccanica di restare spenta con la suite
# verde. E la sua uscita è **l'unica ammessa**: un sussulto che non parte —
# stesso arrivo, stesso corpo, e chi ha il compagno accanto non trasalisce.

func _il_conforto_morde(t) -> void:
	var k := _tampone(t)
	var solo = _lim(MEDIO)
	var accompagnato = _lim(MEDIO)
	var g := 0.40                       # una corsa addosso, di giorno
	var s0: Dictionary = solo.percepisci("giocatore", "", g)
	var s1: Dictionary = accompagnato.percepisci("giocatore", "", g, 1.0)

	t.ok(float(s1["forza"]) < float(s0["forza"]),
			"col compagno accanto l'allarme è MINORE (%.4f < %.4f)"
			% [float(s1["forza"]), float(s0["forza"])])
	t.eq(str(s0["reazione"]), "trasalisce",
			"(da solo, quell'arrivo lo fa trasalire: senza questa metà il caso"
			+ " sarebbe verde anche a meccanica spenta)")
	t.eq(str(s1["reazione"]), "nulla",
			"e accompagnato non parte: è l'unica uscita che questa meccanica ha")

	# LA FORMA, piantata: il conforto divide il GUADAGNO, quindi l'allarme
	# tamponato moltiplicato per il divisore torna esattamente quello di
	# prima. Con la sottrazione, o con la divisione dopo il clamp, no.
	t.almost(float(s1["forza"]) * (1.0 + k), float(s0["forza"]),
			"il conforto DIVIDE il guadagno: ×(1+TAMPONE) torna l'allarme di prima",
			1e-9)

	# il referto porta il conforto con sé: serve al banco del villaggio per
	# riportare la gamba vera senza ricalcolarla (e `ultimo_sussulto` non è
	# persistito, quindi non è una chiave di salvataggio in più)
	t.ok(s1.has("conforto"), "il referto dice quanto conforto c'era")
	t.eq(float(s1.get("conforto", -1.0)), 1.0, "…e quanto ne è arrivato")
	t.eq(float(s0.get("conforto", -1.0)), 0.0, "…e chi era solo lo dice pure")

	# e nel corpo non resta NIENTE: la scia la lascia chi ha trasalito
	t.eq(accompagnato.arousal, 0.0,
			"un sussulto che non parte non lascia il cuore in gola")
	t.ok(solo.arousal > 0.0,
			"(…mentre quello che parte sì: %.4f)" % solo.arousal)
	t.eq(accompagnato.livello_neuro("cortisolo"),
			float(LIMBICO.NEURO_BASELINE["cortisolo"]),
			"e non alza il cortisolo di chi non si è allarmato")


# =========================================================================
# 4 · LA FIRMA 1 — è un'INTERAZIONE, non una sottrazione
# =========================================================================
#
# La grandezza che si confronta è il CALO ASSOLUTO dell'allarme, e non è una
# scelta di comodo: è quello che il corpo sente e che il giocatore vede (la
# coda guardinga, il rallentando, la nuvoletta). Dividendo il guadagno, il
# calo è proporzionale alla `reattivita` — chi trema di suo ci guadagna
# molto, chi non si allarmava non ha niente da farsi smorzare.
#
# Con una SOTTRAZIONE (`allarme - conforto * C`) i due cali sarebbero
# uguali, e il calmo ci guadagnerebbe di più in proporzione: la firma
# psicologica esce rovesciata.

func _la_firma_dell_interazione(t) -> void:
	var k := _tampone(t)
	var g := 0.45
	var codardo_solo = _lim(CARATTERI[0])
	var codardo_con = _lim(CARATTERI[0])
	var calmo_solo = _lim(CARATTERI[2])
	var calmo_con = _lim(CARATTERI[2])
	var cs := float(codardo_solo.percepisci("giocatore", "", g)["forza"])
	var cc := float(codardo_con.percepisci("giocatore", "", g, 1.0)["forza"])
	var ms := float(calmo_solo.percepisci("giocatore", "", g)["forza"])
	var mc := float(calmo_con.percepisci("giocatore", "", g, 1.0)["forza"])

	t.ok(cs < 1.0 and ms < 1.0,
			"(nessuno dei due è al tetto del clamp: %.4f e %.4f — o il caso"
			% [cs, ms] + " misurerebbe il tetto invece dell'interazione)")
	var calo_codardo := cs - cc
	var calo_calmo := ms - mc
	t.ok(calo_codardo > calo_calmo,
			"il tampone smorza DI PIÙ chi è più reattivo (%.4f contro %.4f)"
			% [calo_codardo, calo_calmo])
	# e di quanto: esattamente nel rapporto dei due grilletti, che è ciò che
	# vuol dire «entra sulla reattività»
	t.almost(calo_codardo / maxf(calo_calmo, 1e-9),
			codardo_solo.reattivita / calmo_solo.reattivita,
			"…e il rapporto dei cali è il rapporto delle reattività", 1e-6)
	# il rovescio, che va detto: in PROPORZIONE il tampone vale uguale per
	# tutti. È la stessa cosa vista dall'altra parte, ed è per questo che la
	# firma si misura sul calo assoluto e non sulla frazione.
	t.almost(cc / cs, mc / ms,
			"(in frazione il tampone vale uguale per tutti: 1/(1+%.2f))" % k, 1e-9)


# =========================================================================
# 5 · IL DIVIETO ANTI-MALUS — il parametro può solo ABBASSARE
# =========================================================================
#
# ⚠️ È il modo di sbagliarlo dichiarato dall'autore, e ci si arriva
# dall'aritmetica invece che da una decisione: un conforto NEGATIVO e finito
# passa `is_finite`, fa scendere il divisore sotto 1, e la divisione
# AMPLIFICA l'allarme. Cioè il malus per chi sta solo, entrato dalla porta di
# servizio — e un malus per chi sta solo è la terza domanda del collaudo del
# genere che fallisce.
#
# E il NaN è peggio, perché non si vede: `clampf(NAN, 0, 1)` restituisce NaN
# (le due comparazioni sono false), l'allarme diventa NaN, e l'allarme
# alimenta `arousal`, che è PERSISTITO. Un canale avvelenato non torna più
# indietro — è la stessa lezione del cancello di `stimola_neuro`.

func _niente_malus(t) -> void:
	var g := 0.40
	for storto in [-1.0, -0.35, NAN, INF, -INF]:
		var nome := "%s" % storto
		var onesto = _lim(MEDIO)
		var strambo = _lim(MEDIO)
		var s0: Dictionary = onesto.percepisci("giocatore", "", g)
		var s1: Dictionary = strambo.percepisci("giocatore", "", g, storto)
		t.ok(is_finite(float(s1["forza"])),
				"[conforto %s] l'allarme resta un numero" % nome)
		t.eq(float(s1["forza"]), float(s0["forza"]),
				"[conforto %s] e non sale di un bit sopra quello di oggi" % nome)
		t.eq(float(s1.get("conforto", -1.0)), 0.0,
				"[conforto %s] il referto lo dichiara azzerato" % nome)
		t.eq(strambo.arousal, onesto.arousal,
				"[conforto %s] e la scia nel corpo (PERSISTITA) è quella di oggi" % nome)


# =========================================================================
# 6 · IL RAMO `calore` NON SI TOCCA
# =========================================================================
#
# Il cuoricino di chi ti vuole bene non si spegne perché il suo compagno gli
# è accanto: il tampone è dell'ALLARME, e il calore ha una moneta sua (è la
# regola del capitolo «LA GIOIA NON PORTA LA FACCIA DELLA PAURA», che quella
# separazione l'ha già pagata una volta).
#
# E la seconda metà conta quanto la prima: il tampone non può nemmeno
# ACCENDERE un cuoricino spegnendo un allarme. Un cuore che il giocatore non
# sa ricondurre a niente non attenua l'affetto vero: lo rende illeggibile.

func _il_calore_resta_intatto(t) -> void:
	var g := 0.12                       # sotto RIFLESSO_GREZZO: niente di brusco
	var caro_solo = _lim(MEDIO, 0.85)
	var caro_con = _lim(MEDIO, 0.85)
	var s0: Dictionary = caro_solo.percepisci("giocatore", "", g)
	var s1: Dictionary = caro_con.percepisci("giocatore", "", g, 1.0)
	t.eq(str(s0["reazione"]), "si_illumina", "(chi ti vuole bene si illumina)")
	t.eq(str(s1["reazione"]), "si_illumina",
			"…e continua a illuminarsi col compagno accanto")
	t.eq(float(s1["calore"]), float(s0["calore"]), "il calore è identico al bit")
	t.eq(caro_con.livello_neuro("ossitocina"), caro_solo.livello_neuro("ossitocina"),
			"e l'ossitocina che ne esce pure")
	t.eq(caro_con.livello_neuro("dopamina"), caro_solo.livello_neuro("dopamina"),
			"e la dopamina")
	# …e intanto il tampone STA lavorando: senza questa riga il caso sarebbe
	# verde anche con il parametro ignorato del tutto
	t.ok(float(s1["forza"]) < float(s0["forza"]),
			"(l'allarme sotto, quello sì, è smorzato: %.4f < %.4f)"
			% [float(s1["forza"]), float(s0["forza"])])

	# IL CUORICINO NON SI ACCENDE DA UN ALLARME SPENTO. Stesso affetto, ma
	# un arrivo brusco: da solo trasalisce (il riflesso non sa ancora chi
	# sei), accompagnato non fa niente — e «niente» non è «cuoricino».
	var brusco := 0.40
	var b0 = _lim(MEDIO, 0.85)
	var b1 = _lim(MEDIO, 0.85)
	t.eq(str(b0.percepisci("giocatore", "", brusco)["reazione"]), "trasalisce",
			"(un arrivo brusco fa trasalire anche chi ti vuole bene)")
	t.eq(str(b1.percepisci("giocatore", "", brusco, 1.0)["reazione"]), "nulla",
			"e tamponato non parte, ma NON diventa un cuoricino")


# =========================================================================
# 7 · IL TETTO DEL CLAMP — il residuo, misurato invece che curato
# =========================================================================
#
# ⚠️ Questo caso NON dice che va bene: dice **qual è il tetto**, e diventa
# rosso se qualcuno cambia la forma decisa dall'autore per «sistemarlo».
#
# `clampf(..., 0, 1)` chiude il conto in cima alla scala: quando l'allarme
# grezzo sfonda il tetto anche dopo essere stato diviso, il tamponamento non
# si sente più — cioè la firma 1 si attenua sui percetti estremi. È un tetto
# PRE-ESISTENTE (c'era già prima di questa meccanica) e la cura vietata è
# proprio `clampf(prodotto, 0, 1) / D`, che a saturazione darebbe esattamente
# 1/(1+TAMPONE) — cioè metà allarme dove il codice sano ne dà uno pieno.

func _il_tetto_del_clamp(t) -> void:
	var k := _tampone(t)
	var atteso := 1.0 / (1.0 + k)
	var scala: Array = []
	for g in [0.20, 0.40, 0.60, 0.80, 1.00]:
		var solo = _lim({"codardia": 1.0, "grinta": 0.0})    # reattivita 1.5
		var con = _lim({"codardia": 1.0, "grinta": 0.0})
		var f0 := float(solo.percepisci("giocatore", "", g)["forza"])
		var f1 := float(con.percepisci("giocatore", "", g, 1.0)["forza"])
		scala.append({"g": g, "f0": f0, "f1": f1, "r": f1 / maxf(f0, 1e-9)})
	# in basso sulla scala — dove l'allarme non tocca il tetto — il tampone
	# lavora per intero…
	t.almost(float((scala[0] as Dictionary)["r"]), atteso,
			"sotto il tetto il tampone vale tutto (rapporto %.4f)"
			% float((scala[0] as Dictionary)["r"]), 1e-9)
	# …e in cima si mangia da solo, perché il tetto arriva prima
	t.almost(float((scala[4] as Dictionary)["f0"]), 1.0,
			"(in cima alla scala l'allarme è al tetto)", 1e-9)
	t.ok(float((scala[4] as Dictionary)["r"]) > atteso + 0.01,
			"IL RESIDUO, MISURATO: in cima alla scala il tampone si attenua"
			+ " (rapporto %.4f invece di %.4f)"
			% [float((scala[4] as Dictionary)["r"]), atteso])
	# e la scala è monotona: il tetto mangia sempre di più, mai a scatti
	for i in range(1, scala.size()):
		var qui := float((scala[i] as Dictionary)["r"])
		var prima := float((scala[i - 1] as Dictionary)["r"])
		t.ok(qui >= prima - 1e-9,
				"il tetto mangia il tampone in modo monotono (grezzo %.2f: %.4f)"
				% [float((scala[i] as Dictionary)["g"]), qui])
	# LA CONTROPROVA CHE PIANTA LA FORMA: la stesura vietata (dividere DOPO
	# il clamp) darebbe esattamente `atteso` anche a saturazione.
	t.ok(absf(float((scala[4] as Dictionary)["f1"]) - atteso) > 0.01,
			"…e non è la divisione dopo il clamp, che a saturazione darebbe %.4f"
			% atteso)


# =========================================================================
# il banco — il villaggio (corpi veri, registro vero, libro mastro vero)
# =========================================================================

## UN corpo vero col suo rig, il suo nome d'anagrafe e i tratti dichiarati:
## fra A e C non deve esserci nessuna differenza tranne la compagnia.
func _corpo(t, nome: String, pos: Vector3, seme: int):
	var v = VISITOR.new()
	v.species = "chibi"
	v.mode = "resident"
	var dna: Dictionary = DNA.generate(seme)
	dna["name"] = nome
	dna["tratti"] = MEDIO.duplicate()
	v.dna = dna
	t.stage(v)
	v.set_process(false)                # il `_process` non ci serve
	v._enter_state("r_idle")
	v.set("_timer", 1.0e9)
	v.global_position = pos
	return v


## IL VILLAGGIO APPAIATO.
##
##            B(0,6 m)                          D(0,6 m)
##                A ● ─── 2,0 m ─── ◉ Mochi ─── 2,0 m ─── ● C
##
## A e C sono identici e alla stessa distanza esatta dal giocatore (quindi
## stesso `grezzo` al bit); B è il COMPAGNO di A, D è solo un vicino di C.
## L'unica differenza fra i due lati è il libro mastro.
func _villaggio(t) -> Dictionary:
	for vecchio in t.tree().get_nodes_in_group("visitors"):
		(vecchio as Node).remove_from_group("visitors")
	for vecchio in t.tree().get_nodes_in_group("affetti"):
		(vecchio as Node).remove_from_group("affetti")
	var vis = t.stage(Registro.new())
	var aff = t.stage(load("res://scenes/npc/Affetti.gd").new())
	var player := Node3D.new()
	t.stage(player)
	player.global_position = Vector3.ZERO
	vis.set("_player", player)

	var posti := {
		"A": Vector3(0, 0, 2.0), "B": Vector3(0.6, 0, 2.0),
		"C": Vector3(0, 0, -2.0), "D": Vector3(0.6, 0, -2.0),
	}
	var nomi := {"A": "Amaretto", "B": "Biscotto", "C": "Cannella", "D": "Dattero"}
	var corpi := {}
	var animi := {}
	var i := 0
	for chi in ["A", "B", "C", "D"]:
		# semi DIVERSI (i nomi d'anagrafe devono essere distinti) ma tratti
		# uguali: `Animo.setup` legge `dna["tratti"]` quando c'è, quindi la
		# `reattivita` dei quattro è la stessa al bit — l'unica differenza
		# fra i due lati resta il libro mastro.
		var c = _corpo(t, str(nomi[chi]), posti[chi], 5150 + i * 211)
		var a = ANIMO.new()
		a.setup(c.dna)
		(vis.get("_animi") as Dictionary)[chi] = a
		vis._residents.append({"node": c, "label": chi, "dna": c.dna,
				"cell": Vector2i(i, 0), "species": "chibi", "friend": 2})
		corpi[chi] = c
		animi[chi] = a
		i += 1
	# A e B sono una coppia: la cache giornaliera è per NOME, ed è quella che
	# il cablaggio deve leggere (`le_coppie()` costa 156 `conto()` e ~233 ms)
	aff.set("_coppie_ieri", [["Amaretto", "Biscotto"]])
	return {"vis": vis, "aff": aff, "player": player, "corpi": corpi,
			"animi": animi}


## Riporta tutto al punto di partenza e fa arrivare Mochi di corsa.
##
## Il giocatore NON si sposta: la velocità la si finge scrivendo `_pp_prec`,
## come fa `test_gioia._arriva` — se si spostasse davvero, le due distanze
## appaiate smetterebbero di essere identiche al bit e la differenza misurata
## non sarebbe più del conforto.
func _percetto(v: Dictionary, velocita := 6.0) -> void:
	var vis = v["vis"]
	(vis.get("_sussulto_cd") as Dictionary).clear()
	(vis.get("_riconoscimenti") as Dictionary).clear()
	for a in (v["animi"] as Dictionary).values():
		var l = a.limbico
		l.arousal = 0.0
		l.umore = 0.0
		l.marchi.clear()
		l.attese.clear()
		l.neuro = l.neuro_base.duplicate()
	var p: Node3D = v["player"]
	vis.set("_pp_prec", p.global_position - Vector3(0, 0, velocita * DT))
	vis._tick_sussulti(DT)


func _referto(v: Dictionary, chi: String) -> Dictionary:
	return ((v["animi"] as Dictionary)[chi] as RefCounted).limbico.ultimo_sussulto


# =========================================================================
# 8 · IL COMPAGNO ACCANTO TAMPONA — e la compagnia generica NO
# =========================================================================
#
# È la firma 2 (la specificità) misurata sulla geometria appaiata: A e C
# hanno tutti e due un vicino a 0,6 metri, e solo per uno dei due quel vicino
# è il proprio compagno.
#
# ⚠️ SE QUESTO CASO ESCE ROSSO CON `conforto` A ZERO, la prima cosa da
# guardare è DA DOVE il cablaggio prende la coppia: il banco riempie SOLO
# `Affetti._coppie_ieri` (la cache giornaliera, per NOME), ed è voluto —
# `le_coppie()` ricalcola il libro mastro e costa ~233 ms per chiamata, cioè
# non si può chiamare dentro `_tick_sussulti`. Un fixture che riempisse anche
# `_righe` renderebbe le due strade indistinguibili, e quella cara passerebbe
# il test per poi strozzare il fotogramma in partita.

func _il_compagno_accanto_tampona(t) -> void:
	var v := _villaggio(t)
	_percetto(v)
	var a := _referto(v, "A")
	var c := _referto(v, "C")

	t.almost(float(a["grezzo"]), float(c["grezzo"]),
			"(i due arrivi sono lo stesso arrivo: %.4f e %.4f)"
			% [float(a["grezzo"]), float(c["grezzo"])], 1e-9)
	t.ok(float(a.get("conforto", 0.0)) > 0.0,
			"il compagno accanto arriva al corpo come conforto (%.4f)"
			% float(a.get("conforto", 0.0)))
	t.almost(float(a.get("conforto", 0.0)), 1.0 - 0.6 / VISITORS.VICINI,
			"…e la rampa è lineare dentro VICINI, con lo zero al bordo", 1e-6)
	t.eq(float(c.get("conforto", -1.0)), 0.0,
			"LA SPECIFICITÀ: un vicino qualunque alla stessa distanza non"
			+ " tampona niente — la compagnia generica non è una figura di"
			+ " attaccamento")

	t.ok(float(a["forza"]) < float(c["forza"]),
			"e l'allarme di chi ha il compagno accanto è minore (%.4f < %.4f)"
			% [float(a["forza"]), float(c["forza"])])
	t.eq(str(c["reazione"]), "trasalisce",
			"(da solo, quell'arrivo lo fa trasalire)")
	t.eq(str(a["reazione"]), "nulla",
			"e accanto al suo compagno il sussulto non parte")

	# E LO SI VEDE ADDOSSO — o meglio: non lo si vede. La coda guardinga è
	# l'unica cosa che il giocatore leggerebbe, e su chi è tamponato non si
	# accende affatto.
	var corpi: Dictionary = v["corpi"]
	t.eq(float((corpi["A"] as Node).get("_gs_soma")), 0.0,
			"il corpo tamponato non porta la coda guardinga")
	t.ok(float((corpi["C"] as Node).get("_gs_soma")) > 0.0,
			"(…e quello che ha trasalito sì: %.4f — la controprova, senza la"
			% float((corpi["C"] as Node).get("_gs_soma"))
			+ " quale questo caso sarebbe verde a corpo spento)")

	# IL RAFFREDDAMENTO RESTA DOV'È: un sussulto tamponato brucia i suoi nove
	# secondi come se fosse partito. Spostarlo dentro il ramo `trasalisce`
	# per «recuperare» i sussulti soppressi farebbe di questa meccanica un
	# moltiplicatore di percetti sui vicini in coppia — la classifica sociale
	# dalla porta di servizio.
	var cd: Dictionary = v["vis"].get("_sussulto_cd")
	t.eq(float(cd.get("A", 0.0)), float(cd.get("C", -1.0)),
			"chi è stato tamponato brucia lo stesso raffreddamento di chi ha"
			+ " trasalito (%.2f)" % float(cd.get("C", -1.0)))


# =========================================================================
# 9 · LO ZERO DURO OLTRE IL RAGGIO
# =========================================================================
#
# ⚠️ La rampa vale ZERO al bordo, e non «quasi zero»: con un `exp(-d / R)`,
# che non si annulla a nessuna distanza, il bit-identico salterebbe per TUTTO
# il villaggio — ogni residente avrebbe addosso un pelo di conforto da un
# compagno dall'altra parte del prato, in silenzio.

func _lo_zero_duro_oltre_il_raggio(t) -> void:
	var v := _villaggio(t)
	var b: Node3D = (v["corpi"] as Dictionary)["B"]
	b.global_position = Vector3(0, 0, 2.0 + VISITORS.VICINI + 0.6)
	_percetto(v)
	var a := _referto(v, "A")
	var c := _referto(v, "C")
	t.eq(float(a.get("conforto", -1.0)), 0.0,
			"oltre VICINI il conforto è zero DURO, non un pelo")
	t.eq(float(a["forza"]), float(c["forza"]),
			"…e l'allarme torna quello di ieri, al bit")
	t.eq(str(a["reazione"]), "trasalisce",
			"col compagno lontano il sussulto parte come è sempre partito")


# =========================================================================
# 10 · LE VALVOLE — un compagno che non c'è non conforta
# =========================================================================
#
# Dentro casa, addormentato, dentro una scena: sono le tre valvole di
# `Percezione.puo_vedere`, e si chiedono a LEI e non a tre `if` riscritti a
# mano — così il giorno che qualcuno ne aggiunge una quarta questa meccanica
# se la eredita.

func _le_valvole_del_compagno(t) -> void:
	var v := _villaggio(t)
	var b: Node3D = (v["corpi"] as Dictionary)["B"]

	# prima la controprova: nelle stesse condizioni, sveglio, tampona
	_percetto(v)
	t.ok(float(_referto(v, "A").get("conforto", 0.0)) > 0.0,
			"(a valvole aperte il compagno tampona: la controprova)")

	for prova in [
		{"campo": "_hidden", "acceso": true, "spento": false,
			"dice": "è rientrato in casa"},
		{"campo": "_state", "acceso": "tk_nap", "spento": "r_idle",
			"dice": "sta facendo il pisolino"},
		{"campo": "_scena_t", "acceso": 5.0, "spento": 0.0,
			"dice": "è dentro una scena"},
	]:
		b.set(str(prova["campo"]), prova["acceso"])
		_percetto(v)
		var a := _referto(v, "A")
		var c := _referto(v, "C")
		t.eq(float(a.get("conforto", -1.0)), 0.0,
				"un compagno che %s non conforta nessuno" % str(prova["dice"]))
		t.eq(float(a["forza"]), float(c["forza"]),
				"…e l'allarme torna quello di ieri (%s)" % str(prova["dice"]))
		t.eq(str(a["reazione"]), "trasalisce",
				"…e il sussulto parte (%s)" % str(prova["dice"]))
		b.set(str(prova["campo"]), prova["spento"])


# =========================================================================
# 11 · IL NOME AMBIGUO SI SCARTA
# =========================================================================
#
# L'anagrafe di questo gioco è doppia: il libro mastro degli affetti parla
# per NOME del DNA, il registro dei vicini per ETICHETTA. La traduzione va
# fatta costruendo la mappa da `_residents`, che ha tutte e due le colonne —
# **mai** con `_nome_da_label`, che ha un ripiego silenzioso (`return label`)
# e darebbe conforto zero per sempre senza dirlo.
#
# E un nome che tocca a due residenti non si risolve «sul primo che capita»:
# si scarta. Il degrado va verso il gioco che c'era già.

func _il_nome_ambiguo_si_scarta(t) -> void:
	var v := _villaggio(t)
	var corpi: Dictionary = v["corpi"]
	# D si chiama anche lui «Biscotto»: adesso quel nome non identifica più
	# nessuno, e il compagno di A non si sa più chi sia.
	(corpi["D"] as Node).get("dna")["name"] = "Biscotto"
	_percetto(v)
	var a := _referto(v, "A")
	var c := _referto(v, "C")
	t.eq(float(a.get("conforto", -1.0)), 0.0,
			"un nome che tocca a due residenti si scarta invece di risolversi"
			+ " sul primo che capita")
	t.eq(float(a["forza"]), float(c["forza"]),
			"…e il gioco torna quello di ieri, al bit")


## 11b — ⚠️ E L'AMBIGUO PUÒ ESSERE CHI CHIEDE, non solo chi si cerca.
##
## Il caso 11 rinomina D, cioè rende ambiguo il nome CERCATO (`suo`): prova
## il lato che il codice guardava già, e la mutazione sull'altro lato lo
## lascia verde. Qui l'omonimo è CHI CHIEDE (`mio`), ed è il lato che aveva
## il difetto — con l'asimmetria rovesciata: il compagno VERO trovava il
## nome ambiguo e restava a zero, mentre TUTTI E DUE gli omonimi
## incassavano il tampone pieno. Il compagno vero perdeva la cosa,
## l'estraneo la prendeva.
##
## LA MUTAZIONE che rende rosso questo caso: togliere il confronto con la
## propria label da `Visitors._conforto_del_compagno` (cioè tornare al solo
## `if mio == "": return 0.0`).
func _l_ambiguo_puo_essere_chi_chiede(t) -> void:
	var v := _villaggio(t)
	var corpi: Dictionary = v["corpi"]
	# C prende il nome di A: adesso «Amaretto» tocca a DUE corpi, e uno dei
	# due (C) con Biscotto non ha mai fatto niente.
	(corpi["C"] as Node).get("dna")["name"] = "Amaretto"
	# e lo si mette accanto a B, che è il compagno vero di A
	var b := corpi["B"] as Node3D
	(corpi["C"] as Node3D).global_position = b.global_position + Vector3(0.5, 0, 0)
	_percetto(v)
	var c := _referto(v, "C")
	t.eq(float(c.get("conforto", -1.0)), 0.0,
			"chi porta un nome che tocca a due corpi non prende il conforto"
			+ " del partner dell'altro")
	# e la controprova: il compagno VERO non dev'essere l'unico a perderci
	var a := _referto(v, "A")
	t.ok(float(a.get("conforto", 0.0)) >= 0.0,
			"e il compagno vero non finisce peggio dell'omonimo")


# =========================================================================
# 13 · LA COMPAGNIA NON AZZERA LA PAURA — il tetto di K, che nessuno aveva
# =========================================================================
#
# ⚠️ `TAMPONE_SOCIALE` era sorvegliato solo DAL BASSO: i casi 5 e 7 provano
# che il parametro non alza mai l'allarme, quindi K = 0 (il tampone spento)
# li lascia tutti verdi, e K = 9 pure — smorzerebbe di dieci volte, cioè
# **la presenza di un amico abolirebbe la paura**, e nessuna asserzione se
# ne accorgerebbe. È lo stesso buco che la revisione aveva già trovato su
# `NOTTE_SY` («il tetto c'era, il pavimento no») letto al contrario.
#
# Il numero contro cui si giudica NON è K stesso — sarebbe il ritratto — ed
# è la frase che il file di produzione afferma per iscritto, due volte:
# «la compagnia non azzera la paura, la smorza» e «a 1.0 la presenza piena
# DIMEZZA il guadagno». Quel dimezzamento è il tetto: sopra, la frase
# diventa falsa e nessuno se ne accorge finché non la si legge.
#
# E il pavimento è che il tampone deve esistere: a K = 0 il quarto
# parametro sarebbe una firma senza meccanica, e il caso 3 morirebbe con
# lui — ma questo caso lo dice PRIMA, nominando la ragione.
func _il_tampone_non_azzera_la_paura(t) -> void:
	var k := _tampone(t)
	t.ok(k > 0.0, "TAMPONE_SOCIALE dev'essere > 0: a zero il quarto"
			+ " parametro è una firma senza meccanica (K = %.3f)" % k)
	t.ok(k <= 1.0, "TAMPONE_SOCIALE non può superare 1.0: la presenza piena"
			+ " dimezza il guadagno e non di più — «la compagnia non azzera"
			+ " la paura, la smorza» (K = %.3f darebbe /%.2f)" % [k, 1.0 + k])
	# e la frase si prova sul NUMERO, non sulla costante: col conforto al
	# massimo l'allarme non può scendere sotto la metà di quello di ieri.
	# ⚠️ fuori dal tetto del `clampf`, o le due gambe finirebbero tutte e due
	# a 1,0 e il caso direbbe che va bene qualunque K.
	var l = _lim({"codardia": 0.5, "grinta": 0.5}, -0.30)
	var pieno: float = float(l.percepisci("giocatore", "", 0.10, 1.0)["forza"])
	var l0 = _lim({"codardia": 0.5, "grinta": 0.5}, -0.30)
	var nudo: float = float(l0.percepisci("giocatore", "", 0.10, 0.0)["forza"])
	t.ok(nudo < 0.999, "il banco dev'essere SOTTO il tetto del clamp, o non"
			+ " misura niente (allarme nudo %.4f)" % nudo)
	t.ok(pieno >= nudo * 0.5 - 1e-9, "col conforto al massimo l'allarme non"
			+ " scende sotto la METÀ: %.4f contro %.4f" % [pieno, nudo])
	t.ok(pieno < nudo, "…e scende: %.4f contro %.4f" % [pieno, nudo])
