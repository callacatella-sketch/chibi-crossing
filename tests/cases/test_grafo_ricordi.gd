extends RefCounted
## IL GRAFO DEI RICORDI — quello che un vicino ha visto fare a Mochi.
##
## Qui non si cerca una stringa nei file: il gioco obbedisce alla .dylib, non
## al .cpp. Si interroga il BINARIO, si fanno girare le funzioni VERE
## (`chibi::inserisci`, `chibi::peso`, `chibi::da_raccontare` attraverso i
## quattro oracoli const di EcsMondo) e si guarda cosa esce.
##
## Le cinque cose che questo file esiste per tenere chiuse, e ognuna ha il suo
## guasto già scritto nel piano della Fase 4:
##
##  1. IL PESO DECADE IN LETTURA. Nel dato non deve esistere nessun intero che
##     decade: un `int16 × 0.999994` TORNA A SÉ STESSO, e il grafo diventerebbe
##     eterno con la suite verde. Qui si legge lo stesso identico ricordo a due
##     ore diverse e si pretende che pesi la metà — mentre i suoi byte non si
##     sono mossi di un bit.
##  2. `inserisci` FONDE le ripetizioni ravvicinate. Sei aiuole annaffiate nello
##     stesso gesto sono UN ricordo con `quante = 6`: sei ricordi separati
##     riempirebbero l'anello e cancellerebbero tutto il resto — cioè un
##     giocatore diligente si farebbe dimenticare quello che ha fatto prima.
##  3. LA POTATURA VA PER PESO, NON PER ETÀ. Un ricordo forte sopravvive a
##     ventiquattro tiepidi. Si semina un fatto ANTICO e fortissimo, gli si
##     buttano addosso trenta ricordi giovani e insipidi, e si pretende che
##     ci sia ancora.
##  4. `da_raccontare` È DETERMINISTICO. In C++ non c'è e non ci sarà un RNG: i
##     dadi del villaggio si salvano, e un secondo generatore qui sarebbe una
##     seconda storia che nessun salvataggio racconta.
##  5. IL SOGGETTO PORTA LA VERSIONE. EnTT ricicla gli slot: con un indice nudo,
##     chi arriva la settimana prossima erediterebbe l'ammirazione di chi è
##     partito il mese scorso — in silenzio, dopo cento giorni, e solo in un
##     villaggio che ha avuto partenze, cioè dove nessun collaudo arriva. Il
##     test prende due handle che condividono lo SLOT e pretende che il grafo
##     li tratti come due persone diverse.

# Le cose che si possono ricordare sono le cose che si sanno DIRE: la prova
# vive qui sotto, e ha bisogno del dizionario vero dei simboli.
const VISITOR := preload("res://scenes/npc/Visitor.gd")

# La mezza vita di prova. NON è la taratura del gioco (quella la deriva
# `imposta_ritmo` dal ciclo del giorno): qui è un numero tondo, così le
# uguaglianze si leggono a occhio nudo.
const MV := 1000.0

var _c = {} # le costanti, lette dal BINARIO e mai scritte a mano
var _sogg := 0 # SOGG_NESSUNO


func run(t) -> void:
	# GUARDIA DURA, non molle: se la GDExtension non è caricata questo test
	# deve essere ROSSO. Un `return` silenzioso direbbe «tutto bene» a un
	# villaggio senza cuore.
	if not ClassDB.class_exists("EcsMondo"):
		t.ok(false, "EcsMondo non registrata: la GDExtension non è caricata")
		return
	var m = ClassDB.instantiate("EcsMondo")
	_c = m.debug_grafo_costanti()
	_sogg = int(_c["sogg_nessuno"])
	_api(t, m)
	_le_costanti_non_divergono(t, m)
	_le_cose_si_sanno_dire(t, m)
	_il_peso_decade_in_lettura(t, m)
	_le_ripetizioni_saturano(t, m)
	_il_peso_non_impazzisce(t, m)
	_la_fusione(t, m)
	_la_fusione_non_confonde(t, m)
	_quante_satura(t, m)
	_il_tempo_lo_decide_chi_inserisce(t, m)
	_la_cosa_si_deriva_dal_verbo(t, m)
	_un_verbo_che_non_esiste_non_entra(t, m)
	_la_potatura_va_per_peso(t, m)
	_il_nuovo_non_scaccia_il_piu_forte(t, m)
	_lanello_non_trabocca(t, m)
	_la_versione_e_il_latch(t, m)
	_da_raccontare(t, m)
	_da_raccontare_e_deterministico(t, m)
	_il_soggetto_porta_la_versione(t, m)
	_niente_dado(t, m)
	m.free()


# ------------------------------------------------------------------ i ferri

func _ric(verbo: int, soggetto: int, opt := {}) -> Dictionary:
	var r := {
		"soggetto": soggetto,
		"verbo": verbo,
		"cosa": 0,
		"bandiere": 0,
		"quante": 1,
		"intensita": 255,
		"px": 0.0,
		"pz": 0.0,
		"quando": 0.0,
	}
	for k in opt:
		r[k] = opt[k]
	return r


func _vuoto() -> Dictionary:
	return {"ricordi": [], "versione": 0}


## Torna [grafo_dopo, indice_scritto]. L'indice è -1 se non ha scritto niente.
func _ins(m, g, r: Dictionary, ora: float) -> Array:
	var res = m.debug_grafo_inserisci(g, r, ora, MV)
	return [res["grafo"], int(res["indice"])]


func _righe(g) -> Array:
	return g["ricordi"]


# ------------------------------------------------------------------ i casi

## Il binario ha davvero i metodi? `has_method` interroga l'oggetto vivo: un
## controllo sul sorgente resterebbe verde anche svuotando la funzione.
func _api(t, m) -> void:
	for nome in ["debug_grafo_inserisci", "debug_grafo_peso",
			"debug_grafo_da_raccontare", "debug_grafo_costanti",
			"indice_verbo", "indice_cosa", "nome_verbo", "nome_cosa"]:
		t.ok(m.has_method(nome), "EcsMondo espone «%s» nel binario" % nome)


## LE DUE COPIE DELLE COSTANTI NON DEVONO DIVERGERE. `chibi::Verbo` vive in
## C++ e la sua gemella `EcsMondo::Verbo` attraversa il ponte: sono due
## tabelle, e in questo progetto due tabelle gemelle hanno già preso strade
## diverse in silenzio (la scala della ribellione). Qui si legano: la costante
## esposta al GDScript, il nome, e l'indice tornato dal binario devono essere
## la stessa cosa per tutti e otto i verbi e tutte e sei le cose.
func _le_costanti_non_divergono(t, m) -> void:
	t.eq(m.N_VERBI, int(_c["n_verbi"]), "N_VERBI: la costante del ponte è quella del sistema")
	t.eq(m.N_COSE, int(_c["n_cose"]), "N_COSE: idem")
	t.eq(int(_c["max_fatti"]), 24, "l'anello dei ricordi è da 24")
	t.eq(int(_c["byte_ricordo"]), 24, "e un Ricordo pesa 24 byte (nessun campo è ingrassato)")
	t.almost(float(_c["finestra_fusione"]), 8.0, "la finestra di fusione è 8 secondi", 1e-9)
	t.eq(_sogg, 0xFFFFFFFF,
			"SOGG_NESSUNO è l'intero di entt::null: 32 bit tutti accesi, non un indice a 8")

	# i verbi, uno per uno: costante ↔ nome ↔ indice
	var attesi := {
		"annaffia": m.V_ANNAFFIA, "semina": m.V_SEMINA, "raccoglie": m.V_RACCOGLIE,
		"costruisce": m.V_COSTRUISCE, "taglia": m.V_TAGLIA, "pesca": m.V_PESCA,
		"cucina": m.V_CUCINA, "dona": m.V_DONA,
	}
	var visti := {}
	for nome in attesi:
		var i: int = m.indice_verbo(nome)
		t.eq(i, int(attesi[nome]), "il verbo «%s» ha lo stesso numero di qua e di là" % nome)
		t.ok(not visti.has(i), "e il numero di «%s» non è di nessun altro" % nome)
		visti[i] = true
		t.eq(str(m.nome_verbo(i)), nome, "e il giro di ritorno rende lo stesso nome")
	t.eq(visti.size(), m.N_VERBI, "gli otto verbi ci sono tutti e otto")

	var attese_cose := {
		"fiore": m.C_FIORE, "cibo": m.C_CIBO, "casa": m.C_CASA,
		"fuoco": m.C_FUOCO, "pesce": m.C_PESCE, "amico": m.C_AMICO,
	}
	var viste := {}
	for nome in attese_cose:
		var i: int = m.indice_cosa(nome)
		t.eq(i, int(attese_cose[nome]), "la cosa «%s» ha lo stesso numero di qua e di là" % nome)
		viste[i] = true
		t.eq(str(m.nome_cosa(i)), nome, "e il giro di ritorno rende lo stesso nome")
	t.eq(viste.size(), m.N_COSE, "le sei cose ci sono tutte e sei")

	# le tre bandiere: potenze di due distinte, e le stesse dei due lati
	t.eq(m.R_SENTITO, int(_c["r_sentito"]), "R_SENTITO è lo stesso bit di qua e di là")
	t.eq(m.R_SU_DI_ME, int(_c["r_su_di_me"]), "R_SU_DI_ME idem")
	t.eq(m.R_DETTO, int(_c["r_detto"]), "R_DETTO idem")
	t.eq(m.R_SENTITO & m.R_SU_DI_ME, 0, "le bandiere non si sovrappongono (sentito/su_di_me)")
	t.eq(m.R_SENTITO & m.R_DETTO, 0, "le bandiere non si sovrappongono (sentito/detto)")
	t.eq(m.R_SU_DI_ME & m.R_DETTO, 0, "le bandiere non si sovrappongono (su_di_me/detto)")

	# un nome inventato non accende niente, e un indice fuori tabella non ha nome
	t.eq(m.indice_verbo("sgraffigna"), -1, "un verbo inventato vale -1")
	t.eq(m.indice_cosa("nostalgia"), -1, "una cosa inventata vale -1")
	t.eq(str(m.nome_verbo(-1)), "", "un verbo fuori tabella non ha nome")
	t.eq(str(m.nome_verbo(m.N_VERBI)), "", "e nemmeno quello subito dopo l'ultimo")
	t.eq(str(m.nome_cosa(m.N_COSE)), "", "idem per le cose")


## REGOLA 3 DEL PIANO: nel grafo entra solo ciò che un chibi sa DIRE. Ogni
## `Cosa` è una chiave di `Visitor.LP_SIMBOLI`, cioè ha un simbolo che può
## uscire da una nuvoletta. Il guasto che questa riga evita è un dato che vive
## nel motore e non arriva mai allo schermo — il TransformComponent di nuovo,
## ma peggio, perché *sembra* funzionare.
func _le_cose_si_sanno_dire(t, m) -> void:
	var simboli: Dictionary = VISITOR.LP_SIMBOLI
	for i in m.N_COSE:
		var nome := str(m.nome_cosa(i))
		t.ok(simboli.has(nome),
				"la cosa «%s» è un simbolo che un chibi sa dire (LP_SIMBOLI)" % nome)
	# ed è un SOTTOINSIEME, non una biiezione: «pioggia», «felice», «ciao» sono
	# simboli che non sono cose fatte da Mochi. Dichiararlo qui impedisce che
	# qualcuno «sistemi» la corrispondenza allargando l'enum.
	t.ok(simboli.size() > m.N_COSE,
			"e i simboli sono di più delle cose ricordabili (%d > %d): è un sottoinsieme"
					% [simboli.size(), m.N_COSE])

	# OGNI VERBO PORTA A UNA COSA VALIDA, e ogni cosa è raggiungibile da almeno
	# un verbo: una `Cosa` che nessun gesto produce sarebbe una colonna morta
	# dentro `interesse[]` di sistema_occ.
	var cdv = _c["cosa_del_verbo"]
	t.eq(cdv.size(), m.N_VERBI, "la tabella verbo→cosa copre tutti i verbi")
	var raggiunte := {}
	for i in cdv.size():
		var c := int(cdv[i])
		t.ok(c >= 0 and c < m.N_COSE,
				"il verbo «%s» porta a una cosa vera" % m.nome_verbo(i))
		raggiunte[c] = true
	t.eq(raggiunte.size(), m.N_COSE,
			"e tutte e sei le cose sono prodotte da almeno un verbo")
	# le due che i verbi condividono, dichiarate: annaffiare e seminare parlano
	# dello stesso fiore, raccogliere e cucinare dello stesso cibo
	t.eq(int(cdv[m.V_ANNAFFIA]), int(cdv[m.V_SEMINA]),
			"annaffiare e seminare parlano dello stesso fiore")
	t.eq(int(cdv[m.V_RACCOGLIE]), int(cdv[m.V_CUCINA]),
			"raccogliere e cucinare parlano dello stesso cibo")
	t.eq(int(cdv[m.V_DONA]), m.C_AMICO, "donare parla di un amico")


## IL PESO DECADE IN LETTURA — è la riga più importante del file.
##
## Si legge LO STESSO IDENTICO RICORDO a due ore diverse: a una mezza vita di
## distanza deve pesare la metà, e i suoi byte non si devono essere mossi. Se
## un giorno qualcuno mettesse il decadimento nel dato (un intero moltiplicato
## per un numero minore di uno), il ricordo tornerebbe a sé stesso e il grafo
## diventerebbe eterno CON LA SUITE VERDE.
func _il_peso_decade_in_lettura(t, m) -> void:
	var r := _ric(m.V_ANNAFFIA, 1, {"quando": 0.0})
	t.almost(m.debug_grafo_peso(r, 0.0, MV), 1.0,
			"appena successo, un ricordo pieno pesa 1", 1e-12)
	t.almost(m.debug_grafo_peso(r, MV, MV), 0.5,
			"dopo una mezza vita pesa la metà", 1e-12)
	t.almost(m.debug_grafo_peso(r, 2.0 * MV, MV), 0.25,
			"dopo due mezze vite, un quarto", 1e-12)
	t.almost(m.debug_grafo_peso(r, 10.0 * MV, MV), 0.0009765625,
			"dopo dieci, quasi niente", 1e-12)

	# IL DATO NON SI È MOSSO: è la prova che il decadimento è in lettura.
	t.eq(int(r["intensita"]), 255, "e il ricordo letto non è cambiato: intensità intatta")
	t.eq(int(r["quante"]), 1, "né il conteggio delle volte")
	t.almost(float(r["quando"]), 0.0, "né il quando", 1e-12)
	t.almost(m.debug_grafo_peso(r, 0.0, MV), 1.0,
			"e riletto all'ora di prima pesa di nuovo 1", 1e-12)

	# UN FRAME SOLO deve già muovere il numero. È la forma misurabile della
	# frase «un int16 moltiplicato per 0.999994 torna a sé stesso»: se il
	# decadimento vivesse in un intero, questo confronto sarebbe un pareggio.
	var p0: float = m.debug_grafo_peso(r, 0.0, MV)
	var p1: float = m.debug_grafo_peso(r, 1.0 / 60.0, MV)
	t.ok(p1 < p0, "un solo frame di gioco muove già il peso verso il basso")
	t.ok(p0 - p1 < 1e-4, "ma di pochissimo: un ricordo non svanisce in un frame")

	# gli altri tre fattori della formula, uno per volta
	var mio := _ric(m.V_DONA, 1, {"bandiere": m.R_SU_DI_ME})
	t.almost(m.debug_grafo_peso(mio, 0.0, MV), 2.0,
			"quello che hai fatto A ME pesa il doppio", 1e-12)
	var sei := _ric(m.V_ANNAFFIA, 1, {"quante": 6})
	t.almost(m.debug_grafo_peso(sei, 0.0, MV), 2.25,
			"sei volte pesano 2.25, non sei: un pomeriggio non schiaccia tutto il resto", 1e-12)
	var mezzo := _ric(m.V_ANNAFFIA, 1, {"intensita": 128})
	t.almost(m.debug_grafo_peso(mezzo, 0.0, MV), 128.0 / 255.0,
			"e l'intensità entra come frazione di 255", 1e-12)
	var niente := _ric(m.V_ANNAFFIA, 1, {"intensita": 0})
	t.almost(m.debug_grafo_peso(niente, 0.0, MV), 0.0,
			"un ricordo a intensità zero non pesa niente", 1e-12)


## IL VENTESIMO GESTO CONTA MENO DEL SECONDO — e per mesi non era vero,
## mentre quattro commenti in quattro file lo dichiaravano.
##
## Il termine delle ripetizioni era `1 + 0.25·(quante-1)`, cioè LINEARE: il
## ventesimo gesto valeva esattamente quanto il secondo (+0.25 tondi tutti e
## due) e duecentocinquantacinque annaffiature pesavano 64,5 volte una. Non è
## un difetto di eleganza, è una MONETA: la durata di una conseguenza è
## `mezza_vita · log2(peso/soglia)`, quindi un peso senza tetto è una durata
## senza tetto, e quindici secondi di modalità costruzione davanti a un
## vicino compravano cinque volte l'effetto di un gesto solo.
##
## Le quattro asserzioni chiudono quattro modi di sbagliare, e la prima è
## quella che le altre tre rendono non-vacue:
##  1. **c'è un TETTO** (il salto da 1 a 255 volte non può superarlo);
##  2. **il ventesimo passo è più piccolo del secondo**, misurato: è la
##     frase, presa alla lettera;
##  3. **insistere serve ancora**: una curva che schiacciasse tutto a 1.0
##     passerebbe le due di sopra e cancellerebbe «ti ho vista lavorare
##     tutto il pomeriggio», che è una cosa vera da ricordare;
##  4. **l'esempio storico resta esatto**: sei aiuole valgono 2.25, bit per
##     bit come prima. `RIP_MEZZA` è derivato apposta da questo vincolo, e
##     chi ritara il tetto senza rifarne il conto lo rompe qui.
##
## I due numeri della curva si leggono dal BINARIO: un test che li ricopia
## resta verde il giorno che qualcuno li tara.
func _le_ripetizioni_saturano(t, m) -> void:
	var tetto := float(_c["rip_tetto"])
	var mezza := float(_c["rip_mezza"])
	t.ok(tetto > 0.0 and mezza > 0.0,
			"PREMESSA: la curva delle ripetizioni arriva dal binario (tetto %s, mezza %s)"
					% [str(tetto), str(mezza)])

	var p = func(q: int) -> float:
		return float(m.debug_grafo_peso(_ric(m.V_ANNAFFIA, 1, {"quante": q}), 0.0, MV))

	# 1. IL TETTO. Nessuna insistenza può portare un ricordo oltre 1 + tetto.
	t.ok(p.call(255) < 1.0 + tetto,
			"duecentocinquantacinque volte pesano %.4f, e il tetto è %.1f: insistere non paga senza fine"
					% [p.call(255), 1.0 + tetto])
	t.ok(p.call(255) < 4.0 * p.call(1),
			"cioè meno di quattro occhiate (%.4f contro %.4f): prima ne valeva 64,5"
					% [p.call(255), p.call(1)])

	# 2. IL VENTESIMO PASSO È PIÙ PICCOLO DEL SECONDO, letteralmente.
	var passo2 := float(p.call(2)) - float(p.call(1))
	var passo20 := float(p.call(20)) - float(p.call(19))
	t.ok(passo20 < passo2,
			"il ventesimo gesto conta meno del secondo (%.5f contro %.5f)" % [passo20, passo2])
	t.ok(passo20 < 0.2 * passo2,
			"…e non di un pelo: ne conta meno di un quinto (%.5f contro %.5f). Con la retta di prima erano IDENTICI"
					% [passo20, passo2])

	# 3. MA INSISTERE SERVE ANCORA. Una curva piatta passerebbe tutto il resto
	#    di questo caso e cancellerebbe una cosa vera.
	t.ok(p.call(6) > p.call(1),
			"un pomeriggio pesa comunque più di un'occhiata (%.4f contro %.4f)"
					% [p.call(6), p.call(1)])
	t.ok(p.call(30) > p.call(6),
			"…e mezza giornata più di un pomeriggio (%.4f contro %.4f)"
					% [p.call(30), p.call(6)])
	t.ok(p.call(2) > 1.0,
			"e già la seconda volta si sente (%.4f): è una delle due strade per restare in mente"
					% p.call(2))

	# 4. E L'ESEMPIO CHE IL PROGETTO HA GIÀ SCRITTO RESTA ESATTO.
	t.almost(p.call(1), 1.0, "un'occhiata sola vale sempre uno esatto", 1e-12)
	t.almost(p.call(6), 2.25,
			"e sei aiuole valgono ancora 2.25 volte una: la curva conserva l'esempio già provato",
			1e-12)


## Il peso non deve mai diventare NaN né crescere. Un NaN in un peso NON
## fallisce: fa fallire ogni confronto, quindi la potatura sceglierebbe sempre
## la riga zero e nessuno se ne accorgerebbe.
func _il_peso_non_impazzisce(t, m) -> void:
	var r := _ric(m.V_ANNAFFIA, 1, {"quando": 0.0})
	var p: float = m.debug_grafo_peso(r, 0.0, 0.0)
	t.ok(not is_nan(p), "con mezza vita zero il peso non è NaN (0/0 non deve uscire di qui)")
	t.ok(is_finite(p), "ed è un numero finito")
	var p2: float = m.debug_grafo_peso(r, 5.0, 0.0)
	t.ok(not is_nan(p2), "e nemmeno un istante dopo")
	t.almost(p2, 0.0, "con mezza vita nulla, un ricordo di un istante fa è già svanito", 1e-12)

	# UN RICORDO DAL FUTURO non deve pesare più di uno fresco: crescerebbe, e
	# non lo poterebbe più nessuno.
	var futuro := _ric(m.V_ANNAFFIA, 1, {"quando": 500.0})
	t.almost(m.debug_grafo_peso(futuro, 0.0, MV), 1.0,
			"un ricordo dal futuro pesa come uno appena successo, mai di più", 1e-12)


## LA FUSIONE. Sei aiuole annaffiate nello stesso gesto sono UN ricordo.
func _la_fusione(t, m) -> void:
	var g = _vuoto()
	var i := -1
	for k in 6:
		var r := _ric(m.V_ANNAFFIA, 42, {"px": float(k), "pz": 1.0})
		var res := _ins(m, g, r, float(k)) # 0,1,2,3,4,5 s: tutti dentro gli 8
		g = res[0]
		i = res[1]
		t.eq(i, 0, "la %d° annaffiatura ravvicinata finisce sulla stessa riga" % (k + 1))
	t.eq(_righe(g).size(), 1, "sei annaffiature di fila sono UN ricordo, non sei")
	var riga = _righe(g)[0]
	t.eq(int(riga["quante"]), 6, "e il ricordo sa di essere successo sei volte")
	t.almost(float(riga["quando"]), 5.0, "il ricordo si è rinfrescato all'ultima volta", 1e-6)
	t.almost(float(riga["px"]), 5.0,
			"e anche il POSTO è quello dell'ultima: un ricordo che si rinfresca si rinfresca tutto",
			1e-6)
	t.almost(m.debug_grafo_peso(riga, 5.0, MV), 2.25,
			"e adesso pesa 2.25, come sei volte devono pesare", 1e-9)

	# L'INTENSITÀ È IL MASSIMO, non l'ultima: se un gesto della serie è
	# arrivato forte, il ricordo resta forte anche se gli ultimi erano fiacchi.
	var f = _vuoto()
	f = _ins(m, f, _ric(m.V_CUCINA, 4, {"intensita": 60}), 0.0)[0]
	f = _ins(m, f, _ric(m.V_CUCINA, 4, {"intensita": 240}), 1.0)[0]
	t.eq(int(_righe(f)[0]["intensita"]), 240, "il gesto più forte alza l'intensità del ricordo")
	f = _ins(m, f, _ric(m.V_CUCINA, 4, {"intensita": 10}), 2.0)[0]
	t.eq(int(_righe(f)[0]["intensita"]), 240,
			"e uno fiacco dopo non gliela riabbassa: si tiene il massimo")

	# `quante` non può essere zero: sarebbe «è successo nessuna volta», e nella
	# formula del peso varrebbe 0.75 — cioè meno di una volta sola.
	var z = _vuoto()
	z = _ins(m, z, _ric(m.V_TAGLIA, 8, {"quante": 0}), 0.0)[0]
	t.eq(int(_righe(z)[0]["quante"]), 1, "un ricordo è successo almeno una volta")
	t.almost(m.debug_grafo_peso(_righe(z)[0], 0.0, MV), 1.0,
			"e pesa come una volta, non come tre quarti di volta", 1e-12)

	# FUORI DALLA FINESTRA non si fonde più: è un'altra volta, un altro giorno.
	var res2 := _ins(m, g, _ric(m.V_ANNAFFIA, 42), 5.0 + 8.001)
	g = res2[0]
	t.eq(res2[1], 1, "passata la finestra, la stessa annaffiatura è un ricordo nuovo")
	t.eq(_righe(g).size(), 2, "e nel grafo adesso ce ne sono due")
	# ...e sul FILO della finestra si fonde ancora (il confronto è `>`, non `>=`)
	var g3 = _vuoto()
	var a := _ins(m, g3, _ric(m.V_SEMINA, 9), 0.0)
	var b := _ins(m, a[0], _ric(m.V_SEMINA, 9), 8.0)
	t.eq(b[1], 0, "esattamente sugli otto secondi si fonde ancora")
	t.eq(_righe(b[0]).size(), 1, "e resta un ricordo solo")


## La fusione guarda la TERNA. Cambiare il verbo o il soggetto vuol dire un
## altro ricordo: se fondesse per il solo verbo, «hai dato da mangiare a Nino»
## e «hai dato da mangiare a Pina» diventerebbero la stessa cosa.
func _la_fusione_non_confonde(t, m) -> void:
	var g = _vuoto()
	g = _ins(m, g, _ric(m.V_DONA, 100), 0.0)[0]
	g = _ins(m, g, _ric(m.V_DONA, 200), 1.0)[0]
	t.eq(_righe(g).size(), 2, "lo stesso gesto verso due persone sono due ricordi")
	g = _ins(m, g, _ric(m.V_ANNAFFIA, 100), 2.0)[0]
	t.eq(_righe(g).size(), 3, "due gesti diversi verso la stessa persona sono due ricordi")
	# e le bandiere: VEDERLO cancella l'averlo solo SENTITO DIRE, se no chi ha
	# prima sentito una voce e poi visto la cosa non potrebbe più raccontarla
	var h = _vuoto()
	h = _ins(m, h, _ric(m.V_PESCA, 5, {"bandiere": m.R_SENTITO}), 0.0)[0]
	t.eq(int(_righe(h)[0]["bandiere"]) & m.R_SENTITO, m.R_SENTITO, "prima l'aveva solo sentito")
	t.eq(m.debug_grafo_da_raccontare(h, 0.0, MV), -1, "e non poteva raccontarlo")
	h = _ins(m, h, _ric(m.V_PESCA, 5), 1.0)[0]
	t.eq(int(_righe(h)[0]["bandiere"]) & m.R_SENTITO, 0,
			"poi l'ha visto con i suoi occhi, e il sentito dire è cancellato")
	t.eq(m.debug_grafo_da_raccontare(h, 1.0, MV), 0, "adesso può raccontarlo")
	# ...e il contrario NO: una voce non cancella quel che si è visto, e non
	# deve nemmeno marchiarlo come sentito
	var k = _vuoto()
	k = _ins(m, k, _ric(m.V_PESCA, 5), 0.0)[0]
	k = _ins(m, k, _ric(m.V_PESCA, 5, {"bandiere": m.R_SENTITO}), 1.0)[0]
	t.eq(int(_righe(k)[0]["bandiere"]) & m.R_SENTITO, m.R_SENTITO,
			"una voce su una cosa vista si somma (ed è l'unica direzione in cui si somma)")


## `quante` è a 8 bit e SATURA. Senza, la duecentocinquantaseiesima
## annaffiatura riporta il contatore a zero e un pomeriggio intero di lavoro
## pesa meno di un gesto solo — con la suite verde.
func _quante_satura(t, m) -> void:
	var g = _vuoto()
	for k in 300:
		g = _ins(m, g, _ric(m.V_ANNAFFIA, 1), float(k) * 0.5)[0]
	t.eq(_righe(g).size(), 1, "trecento gesti attaccati restano un ricordo solo")
	t.eq(int(_righe(g)[0]["quante"]), 255,
			"e il contatore si ferma a 255 invece di rigirare a zero")


## IL TEMPO LO DECIDE CHI INSERISCE. Chi chiama non ha modo di antidatare un
## ricordo: un ricordo antidatato non si potrebbe più potare. (E serve al
## pettegolezzo: chi SENTE una cosa la sente adesso, non quando è successa.)
func _il_tempo_lo_decide_chi_inserisce(t, m) -> void:
	var g = _vuoto()
	g = _ins(m, g, _ric(m.V_TAGLIA, 3, {"quando": -9999.0}), 50.0)[0]
	t.almost(float(_righe(g)[0]["quando"]), 50.0,
			"il ricordo porta l'ora di chi lo inserisce, non quella che gli si è passata", 1e-6)


## `cosa` è una CACHE di COSA_DEL_VERBO, non un secondo dato: si riscrive
## sempre. Nel grafo non può esistere un ricordo la cui cosa contraddice il
## suo verbo, nemmeno se chi chiama si sbaglia.
func _la_cosa_si_deriva_dal_verbo(t, m) -> void:
	var g = _vuoto()
	g = _ins(m, g, _ric(m.V_ANNAFFIA, 1, {"cosa": m.C_PESCE}), 0.0)[0]
	t.eq(int(_righe(g)[0]["cosa"]), m.C_FIORE,
			"annaffiare parla di fiori anche se chi chiama scrive «pesce»")
	# e siccome si deriva, il bugiardo si FONDE col vero: è lo stesso ricordo
	g = _ins(m, g, _ric(m.V_ANNAFFIA, 1, {"cosa": m.C_CASA}), 1.0)[0]
	t.eq(_righe(g).size(), 1, "e resta un ricordo solo, perché la cosa è la stessa")


## Un verbo che non esiste non entra, e non si pinza a zero: pinzarlo vorrebbe
## dire inventarsi «annaffia», e la riga sbagliata finirebbe dentro
## `interesse[cosa]` di sistema_occ — che indicizza un array.
func _un_verbo_che_non_esiste_non_entra(t, m) -> void:
	var g = _vuoto()
	g = _ins(m, g, _ric(m.V_ANNAFFIA, 1), 0.0)[0]
	var v0 := int(g["versione"])
	var res := _ins(m, g, _ric(m.N_VERBI, 1), 1.0)
	t.eq(res[1], -1, "un verbo fuori tabella non entra, e chi chiama lo vede (-1)")
	t.eq(_righe(res[0]).size(), 1, "il grafo non è cresciuto")
	t.eq(int(res[0]["versione"]), v0, "e la versione non si è mossa")
	var res2 := _ins(m, g, _ric(200, 1), 1.0)
	t.eq(res2[1], -1, "e nemmeno un verbo assurdo")


## LA POTATURA VA PER PESO, NON PER ETÀ.
##
## Si semina UN ricordo antico e fortissimo, poi gli si buttano addosso trenta
## ricordi giovani e insipidi. Alla fine l'anello è pieno di roba nuova, ma il
## vecchio dev'esserci ancora: è l'unica cosa importante che quel vicino ha
## visto fare a Mochi, e nessuna quantità di noia deve poterla cancellare.
##
## Se la potatura fosse per età (o «esce il più vecchio», o «esce l'indice
## zero», o un anello circolare), il forte sarebbe il PRIMO a sparire.
func _la_potatura_va_per_peso(t, m) -> void:
	var g = _vuoto()
	# il forte: fatto A LUI, a piena intensità → peso 2.0
	g = _ins(m, g, _ric(m.V_DONA, 7777, {"bandiere": m.R_SU_DI_ME}), 0.0)[0]
	# trenta tiepidi, tutti DIVERSI fra loro (se no si fonderebbero) e tutti
	# molto più giovani: 8 verbi × 4 soggetti = 32 combinazioni disponibili
	for k in 30:
		var r := _ric(k % m.N_VERBI, 100 + int(k / m.N_VERBI), {"intensita": 40})
		g = _ins(m, g, r, 10.0)[0]
	t.eq(_righe(g).size(), int(_c["max_fatti"]), "l'anello è pieno: ventiquattro ricordi")

	var forti := 0
	var piu_vecchio := 1.0e30
	for riga in _righe(g):
		if int(riga["bandiere"]) & m.R_SU_DI_ME:
			forti += 1
		piu_vecchio = minf(piu_vecchio, float(riga["quando"]))
	t.eq(forti, 1,
			"IL RICORDO FORTE È SOPRAVVISSUTO a trenta ricordi più giovani di lui")
	t.almost(piu_vecchio, 0.0,
			"ed è il più VECCHIO del grafo: la potatura guarda il peso, non l'età", 1e-6)

	# la controprova, che è quella che rende l'asserzione di sopra non ovvia:
	# se il forte fosse tiepido come gli altri, sparirebbe.
	var h = _vuoto()
	h = _ins(m, h, _ric(m.V_DONA, 7777, {"intensita": 40}), 0.0)[0]
	for k in 30:
		var r := _ric(k % m.N_VERBI, 100 + int(k / m.N_VERBI), {"intensita": 40})
		h = _ins(m, h, r, 10.0)[0]
	var sopravvissuti := 0
	for riga in _righe(h):
		if int(riga["soggetto"]) == 7777:
			sopravvissuti += 1
	t.eq(sopravvissuti, 0,
			"e un ricordo vecchio SENZA peso invece sparisce: non è l'età a salvarlo")


## E la stessa regola vale per il ricordo NUOVO: se è lui il più debole di
## tutti, è lui a restare fuori. Il grafo tiene i ventiquattro più forti, non
## gli ultimi ventiquattro.
func _il_nuovo_non_scaccia_il_piu_forte(t, m) -> void:
	var g = _vuoto()
	for k in 24:
		var r := _ric(k % m.N_VERBI, 100 + int(k / m.N_VERBI), {"bandiere": m.R_SU_DI_ME})
		g = _ins(m, g, r, 0.0)[0]
	t.eq(_righe(g).size(), 24, "ventiquattro ricordi forti riempiono l'anello")
	var v0 := int(g["versione"])
	var res := _ins(m, g, _ric(m.V_PESCA, 555, {"intensita": 1}), 0.0)
	t.eq(res[1], -1, "un ricordo più debole di tutti non entra, e chi chiama lo vede")
	t.eq(int(res[0]["versione"]), v0,
			"e la VERSIONE non si muove: un latch che scatta a vuoto farebbe rivalutare le emozioni per niente")
	var trovato := false
	for riga in _righe(res[0]):
		if int(riga["soggetto"]) == 555:
			trovato = true
	t.ok(not trovato, "e il ricordo debole non è nel grafo")
	# ...ma uno FORTE entra, e scaccia qualcuno: se no il grafo sarebbe morto
	var res2 := _ins(m, g, _ric(m.V_PESCA, 555, {"bandiere": m.R_SU_DI_ME, "quante": 9}), 0.0)
	t.ok(res2[1] >= 0, "un ricordo più forte invece entra: il grafo non si blocca mai")
	t.eq(_righe(res2[0]).size(), 24, "e l'anello resta da ventiquattro")


## L'anello non trabocca MAI, nemmeno con cento inserimenti tutti diversi.
func _lanello_non_trabocca(t, m) -> void:
	var g = _vuoto()
	var massimo := 0
	var scritti := 0
	var fuori := 0
	for k in 100:
		# tutti diversi: verbo × soggetto, e con intensità crescente così ogni
		# nuovo arrivato è più forte di qualcuno
		var r := _ric(k % m.N_VERBI, 1000 + k, {"intensita": 100 + (k % 150)})
		var res := _ins(m, g, r, float(k))
		g = res[0]
		if res[1] >= 0:
			scritti += 1
			if res[1] >= int(_c["max_fatti"]):
				fuori += 1
		massimo = maxi(massimo, _righe(g).size())
	t.eq(fuori, 0, "nessun inserimento ha mai reso un indice fuori dall'anello")
	t.eq(massimo, 24, "in cento inserimenti il grafo non ha MAI passato il tetto")
	t.eq(_righe(g).size(), 24, "e alla fine ne restano ventiquattro")
	t.ok(scritti > 24,
			"e non è che si sia bloccato subito: di scritture ce ne sono state %d" % scritti)


## LA VERSIONE È IL LATCH del modulatore: sale a ogni scrittura VERA e sta
## ferma quando non si è scritto niente. Se salisse a vuoto, il mod si
## ricalcolerebbe per un ricordo che non è entrato — e il rumore per-frame che
## il dado congelato ha tolto rientrerebbe dalla finestra.
func _la_versione_e_il_latch(t, m) -> void:
	var g = _vuoto()
	t.eq(int(g["versione"]), 0, "un grafo vuoto è alla versione zero")
	g = _ins(m, g, _ric(m.V_ANNAFFIA, 1), 0.0)[0]
	t.eq(int(g["versione"]), 1, "un ricordo nuovo alza la versione")
	g = _ins(m, g, _ric(m.V_ANNAFFIA, 1), 1.0)[0]
	t.eq(int(g["versione"]), 2, "e anche una FUSIONE è una scrittura: alza la versione")
	g = _ins(m, g, _ric(m.V_SEMINA, 2), 2.0)[0]
	t.eq(int(g["versione"]), 3, "e un altro ricordo ancora")
	var v := int(g["versione"])
	var res := _ins(m, g, _ric(m.N_VERBI, 3), 3.0)
	t.eq(int(res[0]["versione"]), v, "un inserimento RIFIUTATO non la muove")


## COSA RACCONTEREI, SE ADESSO INCONTRASSI QUALCUNO: il più pesante fra quelli
## che ho visto io e non ho già raccontato.
func _da_raccontare(t, m) -> void:
	t.eq(m.debug_grafo_da_raccontare(_vuoto(), 0.0, MV), -1,
			"chi non ha visto niente non ha niente da dire (ed è il caso normale)")

	var g = _vuoto()
	# IL PIÙ PESANTE È L'ULTIMO, apposta: se `da_raccontare` tornasse il primo
	# che va bene invece del massimo, questa riga sarebbe verde per sbaglio.
	g = _ins(m, g, _ric(m.V_ANNAFFIA, 1, {"intensita": 50}), 0.0)[0]
	g = _ins(m, g, _ric(m.V_SEMINA, 1, {"intensita": 100}), 0.0)[0]
	g = _ins(m, g, _ric(m.V_PESCA, 1, {"intensita": 200}), 0.0)[0]
	t.eq(m.debug_grafo_da_raccontare(g, 0.0, MV), 2, "si racconta il ricordo che pesa di più")

	# raccontato quello, si passa al secondo (è quel che farà `racconta`)
	_righe(g)[2]["bandiere"] = m.R_DETTO
	t.eq(m.debug_grafo_da_raccontare(g, 0.0, MV), 1,
			"quello già raccontato non si ripete: si passa al successivo")

	# quel che si è solo SENTITO DIRE non riparte: una notizia non è un broadcast
	_righe(g)[1]["bandiere"] = m.R_SENTITO
	t.eq(m.debug_grafo_da_raccontare(g, 0.0, MV), 0,
			"e quel che si è solo sentito dire non si ri-racconta")

	_righe(g)[0]["bandiere"] = m.R_DETTO
	t.eq(m.debug_grafo_da_raccontare(g, 0.0, MV), -1, "finite le notizie, si tace")

	# IL TEMPO CAMBIA LA RISPOSTA, perché il peso decade in lettura: un ricordo
	# fortissimo di ieri perde contro uno mediocre di adesso.
	var h = _vuoto()
	h = _ins(m, h, _ric(m.V_ANNAFFIA, 1, {"intensita": 255}), 0.0)[0]
	h = _ins(m, h, _ric(m.V_SEMINA, 1, {"intensita": 120}), 0.0)[0]
	t.eq(m.debug_grafo_da_raccontare(h, 0.0, MV), 0, "adesso vince il più forte")
	_righe(h)[1]["quando"] = 5.0 * MV
	t.eq(m.debug_grafo_da_raccontare(h, 5.0 * MV, MV), 1,
			"cinque mezze vite dopo vince quello fresco: il peso decade anche qui")


## DETERMINISMO: in C++ non c'è e non ci sarà un RNG. Stessa domanda, stessa
## risposta, sempre — e a parità di peso vince l'indice più basso.
func _da_raccontare_e_deterministico(t, m) -> void:
	var g = _vuoto()
	g = _ins(m, g, _ric(m.V_ANNAFFIA, 1, {"intensita": 200}), 0.0)[0]
	g = _ins(m, g, _ric(m.V_SEMINA, 1, {"intensita": 200}), 0.0)[0]
	g = _ins(m, g, _ric(m.V_PESCA, 1, {"intensita": 200}), 0.0)[0]
	var diverse := {}
	for _k in 40:
		diverse[m.debug_grafo_da_raccontare(g, 0.0, MV)] = true
	t.eq(diverse.size(), 1, "quaranta domande uguali danno quaranta risposte uguali")
	t.ok(diverse.has(0), "e a parità di peso vince l'indice più basso, non un dado")


## IL SOGGETTO PORTA LA VERSIONE — regola 10 del piano, e il guasto che evita
## è invisibile per costruzione: si vedrebbe dopo cento giorni, solo in un
## villaggio che ha avuto partenze.
##
## Si prende un handle vero, si congeda il residente, se ne registra un altro:
## EnTT gli dà LO STESSO SLOT con la versione successiva. Se `soggetto` fosse
## un indice (a 8 bit, o anche a 20), i due ricordi si fonderebbero e il nuovo
## arrivato erediterebbe l'ammirazione del partito. Qui devono restare DUE.
func _il_soggetto_porta_la_versione(t, m) -> void:
	m.dimentica_tutti()
	var a: int = m.registra(PackedStringArray([]), "")
	m.dimentica(a)
	var b: int = m.registra(PackedStringArray([]), "")
	t.ok(not m.conosce(a), "il congedato non è più nel registro")
	t.ok(m.conosce(b), "il nuovo arrivato sì")
	t.ok(a != b, "e i due handle sono diversi")
	# la parte che rende il caso VERO: lo slot è lo stesso, cambia la versione
	t.eq(a & 0xFFFFF, b & 0xFFFFF,
			"i due occupano LO STESSO SLOT di EnTT: è il caso che il guasto richiede")
	t.ok((a >> 20) != (b >> 20), "e a distinguerli c'è solo la VERSIONE")

	var g = _vuoto()
	g = _ins(m, g, _ric(m.V_DONA, a), 0.0)[0]
	g = _ins(m, g, _ric(m.V_DONA, b), 1.0)[0]
	t.eq(_righe(g).size(), 2,
			"quel che hai fatto al partito e quel che hai fatto al nuovo restano DUE ricordi")
	m.dimentica_tutti()


## Nessun dado, da nessuna parte: la stessa sequenza di inserimenti dà lo
## stesso grafo, bit per bit. (Un rng in C++ sarebbe una seconda storia che
## nessun salvataggio racconta.)
func _niente_dado(t, m) -> void:
	var a = _vuoto()
	var b = _vuoto()
	for k in 40:
		var r := _ric(k % m.N_VERBI, 100 + int(k / m.N_VERBI),
				{"intensita": 30 + (k * 7) % 200, "px": float(k)})
		a = _ins(m, a, r, float(k) * 3.0)[0]
		b = _ins(m, b, r, float(k) * 3.0)[0]
	t.eq(str(a), str(b), "due corse identiche danno lo stesso identico grafo")
	t.eq(int(a["versione"]), int(b["versione"]), "e la stessa versione")
