extends SceneTree
## LA FINESTRA SENSIBILE — e la domanda dell'autore, che ha una risposta
## misurabile perche' **qui il genotipo vero c'e'**.
##
##   ~/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . \
##     --script res://tools/misura_finestra.gd
##   CHIBI_QUANTI=600 CHIBI_GIORNI=42 …
##
## In genetica del comportamento l'ereditabilita' di un tratto **sale** con
## l'eta' (l'effetto Wilson), e la spiegazione corrente e' che la plasticita'
## si chiude: da grandi l'ambiente sposta meno, quindi la quota di varianza
## che il genotipo spiega cresce. La domanda era se chiudere la plasticita'
## con l'eta', in questo motore, riproduce quella firma.
##
## Si puo' rispondere perche' `tratto = base + delta`: `base` E' il genotipo
## (viene da `ChibiDNA`, e' scritto nel salvataggio, non cambia mai) e
## `delta` e' tutto ambiente. In un essere umano non si possono separare;
## qui si', e la quota di varianza spiegata dal genotipo e' semplicemente
## `r²(base, tratto)` sulla popolazione.
##
## ────────────────────────────────────────────────────────────────────────
## I CANCELLI — e i primi che ho scritto erano CONTRADDITTORI FRA LORO
## ────────────────────────────────────────────────────────────────────────
##
## La prima stesura ne dichiarava tre: (a) il controllo non deve salire da
## solo; (b) col braccio della finestra la quota deve salire e **finire piu'
## in alto** del controllo; (c) da adulti i due bracci devono **coincidere**,
## perche' li' la plasticita' e' 1.0 per costruzione.
##
## ⚠️ **(b) E (c) NON POSSONO ESSERE VERI INSIEME.** Se i due bracci
## coincidono da adulti, il braccio della finestra non puo' finire piu' in
## alto: finisce esattamente uguale. Il cancello (b) era scritto male — non
## severo, **impossibile** — ed e' la stessa forma dell'errore gia' pagato
## una volta in questo progetto (un cancello con un tetto piu' basso della
## propria soglia). Non si ritara: si dichiara sbagliato e si sostituisce
## con la domanda che era davvero da fare.
##
## I cancelli VERI, e sono tre:
##
## (a) col CONTROLLO — plasticita' inchiodata a 1.0, cioe' il gioco di oggi —
##     la quota non deve salire da sola. Se salisse, qualunque cosa faccia la
##     finestra non sarebbe della finestra;
## (b) da adulti i due bracci devono COINCIDERE alla cifra: e' il pavimento
##     dell'autore reso osservabile. Se restassero separati, la plasticita'
##     sarebbe scesa sotto quella di oggi da qualche parte;
## (c) **DENTRO la finestra** la quota deve SALIRE dal suo minimo fino
##     all'eta' adulta, e il controllo sullo stesso intervallo NON deve
##     salire. E' qui che la firma dell'effetto Wilson puo' vivere, perche'
##     e' l'unico tratto di vita in cui la plasticita' cambia.
##
## ⚠️⚠️ **E DUE DI QUESTI TRE NON SANNO FALLIRE COM'ERANO SCRITTI. Chi legge
## il referto deve saperlo prima dei numeri, o legge tre «sì» e ne conta tre.**
##
## · **(b), dentro `_blocco`, È UN'IDENTITÀ e non una misura.** Per
##   `g >= GIORNI_ADULTO` la `crescita` vale 1.0, quindi `plasticita_di(1.0)`
##   torna il pavimento — che è **1.0 esatto**, per il `clampf` dentro
##   `Deriva.delta` — e i due bracci valutano *letteralmente la stessa
##   espressione*, `delta(b, pres, 1.0)`, sugli stessi identici ingressi. La
##   divergenza non può che essere zero in virgola mobile: non ci sono due
##   cammini da confrontare. Un cancello che non può fallire **si dichiara,
##   non si toglie in silenzio** — e quello che PUÒ fallire è il blocco
##   `_blocco_vero`, che rifà lo stesso A/B ad anello chiuso passando dalla
##   porta vera (`Animo.ricorda` → la chimica → l'umore → il `sentito` che si
##   incide). Il residuo di là è una misura; questa divergenza è aritmetica.
##
## · **(c) ERA FORZATO DALL'ALGEBRA, per come sceglieva l'indice.** `i_min`
##   era l'argmin del braccio della FINESTRA, e `salita_c` veniva letta allo
##   **stesso** indice: cioè l'indice più favorevole al braccio che doveva
##   vincere, applicato d'ufficio anche all'altro. E il resto è aritmetica:
##   `delta` è lineare in `plasticita`, quindi `q_fin` sta sotto `q_ctrl`
##   dovunque la plasticità sia > 1 e ci coincide all'età adulta; siccome le
##   prove si accumulano `q_ctrl` scende; quindi «la finestra sale dal minimo
##   di `q_fin`» e «il controllo non sale da lì» erano vere **per
##   costruzione** ogni volta che la plasticità decresce.
##   Adesso **ogni braccio si misura dal PROPRIO minimo**, e il referto
##   stampa accanto la lettura a **indice FISSO** (g = 1 → età adulta),
##   dichiarata prima e uguale per tutti e due.
##   ⚠️ Dal proprio minimo la salita non può essere negativa: il numero che
##   discrimina non è il SEGNO ma la GRANDEZZA, e il controllo viene giudicato
##   nel suo caso più favorevole — se anche lì non sale, non sale.
##
## ⚠️ **E C'E' UN CONFONDENTE STRUTTURALE, che va detto prima dei numeri.**
## Le prove si ACCUMULANO col tempo: piu' uno vive, piu' ambiente ha addosso,
## quindi `Var(delta)` cresce e la quota del genotipo scende — in tutti e due
## i bracci, per una ragione che con la plasticita' non c'entra. Questo e' il
## motivo per cui la domanda si fa DENTRO la finestra e non sull'intera vita.
##
## ⚠️ **E IL MODELLO NON HA CORRELAZIONE GENOTIPO-AMBIENTE.** Nella
## letteratura l'effetto Wilson si attribuisce in buona parte alla rGE: chi
## ha un certo genotipo si SCEGLIE l'ambiente che gli somiglia, quindi
## invecchiando ambiente e genotipo tirano nella stessa direzione. Nel primo
## blocco qui sotto il giocatore e' gentile con chi capita, indipendentemente
## dal carattere; nel secondo blocco lo e' *di piu' con chi e' gia' in un
## certo modo*, e si guarda se la firma compare. Il secondo blocco e' una
## LETTURA ESPLORATIVA, non un cancello: nessuno ha misurato se il gioco vero
## abbia una rGE, e inventarla nel banco per farla uscire sarebbe barare.
##
## ⚠️ **I BRACCI HANNO LO STESSO IDENTICO AMBIENTE.** Stesso seme, stessa
## storia individuo per individuo, giorno per giorno: l'unica cosa che cambia
## e' la plasticita'. Due popolazioni diverse darebbero due villaggi diversi,
## e la differenza misurata non sarebbe della regola.
##
## ⚠️ **E QUESTO NON DIMOSTRA L'EFFETTO WILSON, ne' lo spiega.** Verifica che
## il meccanismo, come e' scritto, ne porti o non ne porti la FIRMA.

const DERIVA := preload("res://scenes/npc/Deriva.gd")
const DNAG := preload("res://scenes/npc/ChibiDNA.gd")
const ANIMO := preload("res://scenes/npc/Animo.gd")
const LEGAMI := preload("res://scenes/world/Legami.gd")

const TRATTO := "codardia"


func _init() -> void:
	_go()


## `r²` fra genotipo e fenotipo: la quota di varianza del tratto che il
## genotipo spiega. Torna -1 se una delle due varianze e' nulla (e allora
## non c'e' niente da spiegare, e va detto invece che stampare uno zero).
func _quota_genetica(base: Array, fen: Array) -> float:
	var n := base.size()
	if n < 3:
		return -1.0
	var mb := 0.0
	var mf := 0.0
	for i in n:
		mb += float(base[i])
		mf += float(fen[i])
	mb /= float(n)
	mf /= float(n)
	var sbb := 0.0
	var sff := 0.0
	var sbf := 0.0
	for i in n:
		var db := float(base[i]) - mb
		var df := float(fen[i]) - mf
		sbb += db * db
		sff += df * df
		sbf += db * df
	if sbb <= 1e-12 or sff <= 1e-12:
		return -1.0
	return (sbf * sbf) / (sbb * sff)


func _go() -> void:
	var quanti := 500
	if OS.get_environment("CHIBI_QUANTI") != "":
		quanti = int(OS.get_environment("CHIBI_QUANTI"))
	var giorni := 42
	if OS.get_environment("CHIBI_GIORNI") != "":
		giorni = int(OS.get_environment("CHIBI_GIORNI"))

	print("")
	print("█".repeat(76))
	print("LA FINESTRA SENSIBILE — %d individui, %d giornate, tratto «%s»"
			% [quanti, giorni, TRATTO])
	print("  plasticita': cucciolo %.2f → adulto %.2f (pavimento) · tetto duro %.2f"
			% [DERIVA.PLASTICITA_CUCCIOLO, DERIVA.plasticita_di(1.0),
			1.0 / DERIVA.FRAZIONE])
	print("  giorni per crescere: %d · mezza vita del ricordo: %.0f"
			% [LEGAMI.GIORNI_ADULTO, ANIMO.MEZZA_VITA])
	print("█".repeat(76))

	var esito_ind := _blocco(quanti, giorni, 0.0,
			"AMBIENTE INDIPENDENTE DAL GENOTIPO (il gioco com'è)")
	var residuo := _blocco_vero(mini(quanti, 80), giorni)
	var esito_rge := _blocco(quanti, giorni, 1.0,
			"AMBIENTE CORRELATO AL GENOTIPO (lettura esplorativa: rGE)")

	print("")
	print("█".repeat(76))
	print("I CANCELLI, sul blocco senza rGE — che è il gioco vero")
	print("█".repeat(76))
	print("(a) col CONTROLLO la quota non sale da sola: %.4f → %.4f   %s"
			% [esito_ind["c0"], esito_ind["cN"], "sì" if esito_ind["a"] else "NO"])
	print("(b) da adulti i due bracci COINCIDONO (divergenza max %.12f)   %s"
			% [esito_ind["div"], "sì" if esito_ind["b"] else "NO"])
	print("    ⚠️ QUI NON È UNA MISURA, È UN'IDENTITÀ: per g ≥ %d la crescita"
			% LEGAMI.GIORNI_ADULTO)
	print("    vale 1.0, `plasticita_di(1.0)` torna il pavimento 1.0, e i due")
	print("    bracci valutano la STESSA espressione sugli stessi ingressi. Un")
	print("    cancello che non può fallire va dichiarato, non tolto in silenzio:")
	print("    quello che PUÒ fallire è il blocco qui sotto, ad anello chiuso.")
	print("(c) DENTRO la finestra, ogni braccio dal PROPRIO minimo:")
	print("      finestra  %+.4f  (dal giorno %d all'età adulta, giorno %d)"
			% [esito_ind["salita_f"], int(esito_ind["i_min_f"]),
			int(esito_ind["i_ad"])])
	print("      controllo %+.4f  (dal giorno %d — il suo caso più favorevole)"
			% [esito_ind["salita_c"], int(esito_ind["i_min_c"])])
	print("      ⇒ %s" % ("sì" if esito_ind["c"] else "NO"))
	print("    ⚠️ dal proprio minimo la salita non può essere negativa: a")
	print("    discriminare non è il segno ma la GRANDEZZA, e il controllo è")
	print("    giudicato nel suo caso migliore. A INDICE FISSO (giorno 1 → %d),"
			% int(esito_ind["i_ad"]))
	print("    che è la lettura senza nessuna scelta di indice: finestra %+.4f,"
			% esito_ind["fisso_f"])
	print("    controllo %+.4f — e lì la quota parte da ~1 con la storia ancora"
			% esito_ind["fisso_c"])
	print("    vuota, quindi può quasi solo scendere in tutti e due i bracci.")
	print("")
	if esito_ind["a"]:
		if esito_ind["c"]:
			print("⇒ LA FIRMA C'È, ED È DENTRO LA FINESTRA. Dal proprio minimo")
			print("  all'età adulta la quota di varianza spiegata dal genotipo")
			print("  sale di %+.4f, mentre nello stesso tratto di vita il gioco"
					% esito_ind["salita_f"])
			print("  di oggi — misurato dal SUO minimo, cioè nel suo caso più")
			print("  favorevole — la porta di %+.4f." % esito_ind["salita_c"])
			print("  ⚠️ E il «sì» di (b) non è una prova: è l'identità dichiarata")
			print("  qui sopra. Questa conclusione poggia su (a) e (c) soltanto.")
		else:
			print("⇒ LA FIRMA NON C'È: dentro la finestra la quota fa %+.4f,"
					% esito_ind["salita_f"])
			print("  e il controllo, dal suo minimo, %+.4f."
					% esito_ind["salita_c"])
		print("")
		print("  E SULL'INTERA VITA la quota SCENDE in tutti e due i bracci —")
		print("  %.4f → %.4f col controllo, %.4f → %.4f con la finestra — per un"
				% [esito_ind["c0"], esito_ind["cN"], esito_ind["f0"], esito_ind["fN"]])
		print("  confondente che con la plasticità non c'entra: le prove si")
		print("  ACCUMULANO, quindi l'ambiente pesa sempre di più. Chi volesse")
		print("  la firma sull'intera vita deve guardare la rGE, non questo.")
	else:
		print("⇒ LA MISURA NON È PRONTA: (a) non passa — la quota sale da sola")
		print("  anche col controllo, e allora niente di quello che fa la")
		print("  finestra si può attribuire alla finestra. (c) non si legge.")
	print("")
	print("  Il blocco rGE, come lettura esplorativa (ogni braccio dal PROPRIO")
	print("  minimo, come sopra): dentro la finestra %+.4f con la finestra"
			% esito_rge["salita_f"])
	print("  contro %+.4f col controllo; a indice fisso %+.4f contro %+.4f; e"
			% [esito_rge["salita_c"], esito_rge["fisso_f"], esito_rge["fisso_c"]])
	print("  sull'intera vita %.4f → %.4f contro %.4f → %.4f."
			% [esito_rge["f0"], esito_rge["fN"], esito_rge["c0"], esito_rge["cN"]])
	print("")
	print("")
	print("█".repeat(76))
	print("E IL CANCELLO (b) PROVATO DALLA PORTA VERA")
	print("█".repeat(76))
	print("  divergenza a %d giornate (7 dopo l'età adulta), attraversando"
			% (LEGAMI.GIORNI_ADULTO + 7))
	print("  `Animo.ricorda` → `Limbico.rivaluta` → la chimica → l'umore:")
	print("     tratto:  media %.6f · massima %.6f"
			% [float(residuo["tratto_media"]), float(residuo["tratto_max"])])
	print("     rancore: media %.6f · massima %.6f"
			% [float(residuo["rancore_media"]), float(residuo["rancore_max"])])
	print("     (dentro la finestra la finestra sposta il tratto di %.4f)"
			% float(residuo["dentro_max"]))
	print("  CONTROLLO — a due giornate dall'età adulta i due bracci")
	print("  divergono di %.6f: se fosse zero anche qui, il banco non"
			% float(residuo["meta_max"]))
	print("  saprebbe distinguerli e lo zero finale non direbbe niente.")
	print("  %s" % ("⇒ il residuo è sotto un decimo dell'effetto: il pavimento"
			+ " tiene anche ad anello chiuso"
			if float(residuo["tratto_max"]) <= 0.1 * float(residuo["dentro_max"])
			else "⇒ ⚠️ IL RESIDUO NON È TRASCURABILE: un'infanzia amplificata"
			+ " lascia un segno, e la regola 4 va riguardata"))
	print("")
	print("(non è una dimostrazione dell'effetto Wilson né una sua spiegazione:")
	print(" è la verifica che il meccanismo, come è scritto, ne porti la firma)")
	quit(0)


## UN BLOCCO: la stessa popolazione, i due bracci, e `rge` da 0 (il
## giocatore è gentile con chi capita) a 1 (è gentile *di più con chi è già
## in un certo modo*).
func _blocco(quanti: int, giorni: int, rge: float, titolo: String) -> Dictionary:
	var base: Array = []
	var ritmo: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242         # LO STESSO per i due blocchi: cambia solo la rGE
	for i in quanti:
		var dna: Dictionary = DNAG.generate(7000 + i * 13)
		var b := float((dna.get("tratti", {}) as Dictionary).get(TRATTO, 0.5))
		base.append(b)
		var caso := rng.randf_range(0.0, 1.0)
		ritmo.append(clampf(lerpf(caso, b, rge), 0.0, 1.0))

	var storie: Array = []
	for i in quanti:
		storie.append([])
	for g in giorni:
		for i in quanti:
			for _k in 3:
				if rng.randf() < float(ritmo[i]) * 0.55:
					(storie[i] as Array).append({"tipo": "regalo",
							"attore": "giocatore", "quando": g,
							"valenza": rng.randf_range(0.4, 0.95),
							"intensita": rng.randf_range(0.5, 1.0)})

	print("")
	print("─".repeat(76))
	print(titolo)
	print("─".repeat(76))
	print("  eta'   crescita  plast.  │  CONTROLLO (oggi)  │  FINESTRA")
	print("  ─────  ────────  ──────  │  quota   |δ| medio │  quota   |δ| medio")

	var q_ctrl: Array = []
	var q_fin: Array = []
	for g in range(1, giorni + 1):
		var crescita := clampf(float(g) / float(LEGAMI.GIORNI_ADULTO), 0.0, 1.0)
		var plast: float = DERIVA.plasticita_di(crescita)
		var fen_c: Array = []
		var fen_f: Array = []
		var sc := 0.0
		var sf := 0.0
		for i in quanti:
			var vive: Array = []
			for r in (storie[i] as Array):
				if int((r as Dictionary)["quando"]) < g:
					vive.append(r)
			var oggi := g
			var rec := func(quando: int) -> float:
				return pow(0.5, float(oggi - quando) / ANIMO.MEZZA_VITA)
			var pres: float = DERIVA.spinta(TRATTO, vive, {}, {}, rec)
			var b: float = float(base[i])
			var dc: float = DERIVA.delta(b, pres, 1.0)
			var df: float = DERIVA.delta(b, pres, plast)
			fen_c.append(clampf(b + dc, 0.0, 1.0))
			fen_f.append(clampf(b + df, 0.0, 1.0))
			sc += absf(dc)
			sf += absf(df)
		var qc := _quota_genetica(base, fen_c)
		var qf := _quota_genetica(base, fen_f)
		q_ctrl.append(qc)
		q_fin.append(qf)
		if g <= 3 or g % 3 == 0 or g == giorni:
			print("  %4d   %6.3f   %5.2f   │  %6.4f  %6.4f    │  %6.4f  %6.4f"
					% [g, crescita, plast, qc, sc / float(quanti),
					qf, sf / float(quanti)])

	var c0: float = float(q_ctrl[0])
	var cN: float = float(q_ctrl[q_ctrl.size() - 1])
	var f0: float = float(q_fin[0])
	var fN: float = float(q_fin[q_fin.size() - 1])
	# l'indice dell'eta' adulta (crescita == 1 la prima volta)
	var i_ad: int = mini(LEGAMI.GIORNI_ADULTO, q_fin.size()) - 1
	# ⚠️ **OGNI BRACCIO DAL PROPRIO MINIMO — e la prima stesura no.** `i_min`
	# era l'argmin del solo braccio della FINESTRA, e `salita_c` veniva letta
	# allo STESSO indice: un indice scelto per essere il piu' favorevole al
	# braccio che doveva vincere, e poi applicato d'ufficio anche all'altro.
	# Con `delta` lineare in `plasticita`, `q_fin <= q_ctrl` dovunque la
	# plasticita' superi 1 e le due coincidono all'eta' adulta; e `q_ctrl`
	# scende perche' le prove si accumulano. Le due meta' di (c) passavano
	# percio' **per costruzione**, non per una proprieta' del meccanismo.
	var i_min_f := 0
	var i_min_c := 0
	for k in range(0, i_ad + 1):
		if float(q_fin[k]) < float(q_fin[i_min_f]):
			i_min_f = k
		if float(q_ctrl[k]) < float(q_ctrl[i_min_c]):
			i_min_c = k
	var salita_f: float = float(q_fin[i_ad]) - float(q_fin[i_min_f])
	var salita_c: float = float(q_ctrl[i_ad]) - float(q_ctrl[i_min_c])
	# e la lettura a INDICE FISSO, dichiarata prima e IDENTICA per i due
	# bracci: al primo giorno la storia e' quasi vuota, quindi la quota parte
	# da ~1 e di li' puo' quasi solo scendere. Serve da contrappeso — se le
	# due letture raccontano due cose diverse, e' l'indice che sta parlando.
	var fisso_f: float = float(q_fin[i_ad]) - float(q_fin[0])
	var fisso_c: float = float(q_ctrl[i_ad]) - float(q_ctrl[0])
	var div_max := 0.0
	for k in range(i_ad, q_ctrl.size()):
		div_max = maxf(div_max, absf(float(q_ctrl[k]) - float(q_fin[k])))

	return {"c0": c0, "cN": cN, "f0": f0, "fN": fN, "div": div_max,
			"salita_f": salita_f, "salita_c": salita_c,
			"i_min_f": i_min_f + 1, "i_min_c": i_min_c + 1,
			"fisso_f": fisso_f, "fisso_c": fisso_c, "i_ad": i_ad + 1,
			"a": cN <= c0 + 0.010, "b": div_max <= 1e-9,
			"c": salita_f > 0.010 and salita_c <= 0.010}


## ⚠️ **IL CANCELLO (b) DALLA PORTA VERA — e senza questo blocco era vero per
## COSTRUZIONE.**
##
## `_blocco` qui sopra fabbrica le righe a mano e chiama solo `Deriva`: i due
## bracci ricevono prove identiche perché nessuno gliele fa divergere. Ma nel
## gioco l'anello è CHIUSO — `_ricalcola_deriva` → `limbico.riproietta` →
## `tinta_carattere` → `neuro_base` → `bersaglio_umore` → `umore`, e
## `Limbico.rivaluta` legge `letto = valenza + umore·0.22`, il cui `sentito`
## è quello che si incide **per sempre** nei ricordi. Un'infanzia amplificata
## scrive quindi ricordi di VALORE diverso, e quei ricordi sono l'ingresso
## della deriva dell'adulto.
##
## Se quel residuo non fosse trascurabile, «un bambino non è ottimizzabile»
## sarebbe falso — ed è l'unica promessa su cui poggia la regola 4 degli
## Affetti. Perciò si rifà lo stesso A/B con gli `Animo` VERI, lo stesso
## copione di eventi, e si guarda quanto resta SETTE GIORNATE DOPO l'età
## adulta.
##
## ⚠️⚠️ **E LA PRIMA STESURA DI QUESTO BLOCCO NON MISURAVA NIENTE.** Dava
## residuo **esattamente 0.000000**, ed era un'IDENTITÀ, non una misura: la
## catena che dichiarava di chiudere è severa in due punti, e una revisione
## avversariale li ha trovati tutti e due.
##
##  · **`bersaglio_umore()` raggiunge `umore` SOLO dentro `passo_neuro`**, e
##    `passo_neuro` ha un chiamante solo in tutto il gioco
##    (`Visitors._ciclo_sonno`). Il blocco chiamava `ricorda` e
##    `passa_giorno` e mai `passo_neuro`: il ramo chimico era reciso.
##  · **`abitudine` deriva dall'AMBIZIONE**, il cui unico carburante è il
##    sogno servito — e il copione scrive solo righe `regalo`, quindi δ
##    ambizione = 0 in tutti e due i bracci. L'altra grandezza che
##    `riproietta` scrive, `reattivita`, moltiplica soltanto `arousal`, che
##    non tocca né `letto`, né `attese`, né `ricordi`, né `rancore()`.
##
## Adesso il blocco chiama `passo_neuro` come lo chiama il villaggio, e
## somma al copione delle righe di COMPITO-DEL-SOGNO, che fanno derivare
## l'ambizione e quindi `abitudine`, che `rivaluta` legge davvero. Il numero
## che ne esce è una misura; quello di prima era un ritratto.
func _blocco_vero(quanti: int, giorni: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 987654
	var copioni: Array = []
	var semi: Array = []
	for i in quanti:
		semi.append(7000 + i * 13)
		var righe: Array = []
		var ritmo := rng.randf_range(0.0, 1.0)
		for g in giorni:
			var oggi_righe: Array = []
			for _k in 3:
				if rng.randf() < ritmo * 0.55:
					oggi_righe.append([rng.randf_range(0.4, 0.95),
							rng.randf_range(0.5, 1.0)])
			# ⚠️ e un COMPITO-DEL-SOGNO ogni tanto: è l'unico carburante
			# dell'ambizione, e senza di lui `abitudine` non deriva — cioè
			# la catena che questo blocco esiste per chiudere resta aperta.
			oggi_righe.append([-1.0, 1.0] if rng.randf() < ritmo * 0.3 else [0.0, 0.0])
			righe.append(oggi_righe)
		copioni.append(righe)

	var fine := mini(LEGAMI.GIORNI_ADULTO + 7, giorni)
	var t_somma := 0.0
	var t_max := 0.0
	var r_somma := 0.0
	var r_max := 0.0
	var dentro_max := 0.0
	var meta_max := 0.0
	for i in quanti:
		var esiti: Array = []
		for finestra in [false, true]:
			var dna: Dictionary = DNAG.generate(int(semi[i]))
			var a = ANIMO.new()
			a.setup(dna)
			var dentro := 0.0
			var meta_finestra := 0.0
			for g in fine:
				var crescita := 1.0
				if finestra:
					crescita = clampf(float(g) / float(LEGAMI.GIORNI_ADULTO),
							0.0, 1.0)
				a.set("crescita", crescita)
				a.set("_deriva_giorno", -1)
				a.call("_ricalcola_deriva")
				for riga in (copioni[i] as Array)[g]:
					var v0 := float(riga[0])
					if v0 < 0.0:
						# il marcatore del compito-del-sogno: il nome lo dice
						# `Animo.compiti_del_sogno()`, perché il sogno di
						# ognuno lo tira `ChibiDNA` e un compito scritto qui
						# servirebbe il sogno di qualcun altro.
						var suoi: Array = a.compiti_del_sogno()
						if not suoi.is_empty():
							a.esegue(str(suoi[0]), "giocatore")
					elif v0 > 0.0:
						a.ricorda("regalo", "giocatore", v0, float(riga[1]))
				# ⚠️ **E LA CHIMICA SI FA SCORRERE**, come la fa scorrere il
				# villaggio (`Visitors._ciclo_sonno`): è l'unica porta di
				# `bersaglio_umore`, cioè l'unico modo in cui la deriva
				# arriva all'umore e da lì a quello che si incide nei
				# ricordi. Senza, il residuo è zero per costruzione.
				a.limbico.passo_neuro(60.0, {}, false, 0.0)
				a.passa_giorno()
				if g == LEGAMI.GIORNI_ADULTO - 2:
					# ⚠️ **IL CONTROLLO DEL BANCO**: dentro la finestra i due
					# bracci DEVONO essere diversi. Uno zero alla fine non
					# vuol dire niente se il banco non sa distinguerli
					# nemmeno quando la differenza c'e' per costruzione.
					meta_finestra = a.tratto(TRATTO)
				if finestra and g < LEGAMI.GIORNI_ADULTO:
					dentro = maxf(dentro,
							absf(a.tratto(TRATTO) - a.tratto_base(TRATTO)))
			esiti.append({"tratto": a.tratto(TRATTO), "meta": meta_finestra,
					"rancore": a.rancore("giocatore"), "dentro": dentro})
		var dt: float = absf(float((esiti[1] as Dictionary)["tratto"])
				- float((esiti[0] as Dictionary)["tratto"]))
		var dr: float = absf(float((esiti[1] as Dictionary)["rancore"])
				- float((esiti[0] as Dictionary)["rancore"]))
		var dm: float = absf(float((esiti[1] as Dictionary)["meta"])
				- float((esiti[0] as Dictionary)["meta"]))
		meta_max = maxf(meta_max, dm)
		t_somma += dt
		r_somma += dr
		t_max = maxf(t_max, dt)
		r_max = maxf(r_max, dr)
		dentro_max = maxf(dentro_max, float((esiti[1] as Dictionary)["dentro"]))
	var n := float(maxi(quanti, 1))
	return {"tratto_media": t_somma / n, "tratto_max": t_max,
			"rancore_media": r_somma / n, "rancore_max": r_max,
			"dentro_max": dentro_max, "meta_max": meta_max}
