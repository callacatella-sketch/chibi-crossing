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
	print("(c) DENTRO la finestra la quota sale (%+.4f) e il controllo no (%+.4f)   %s"
			% [esito_ind["salita_f"], esito_ind["salita_c"],
			"sì" if esito_ind["c"] else "NO"])
	print("")
	if esito_ind["a"] and esito_ind["b"]:
		if esito_ind["c"]:
			print("⇒ LA FIRMA C'È, ED È DENTRO LA FINESTRA. Dal minimo all'età")
			print("  adulta la quota di varianza spiegata dal genotipo sale di")
			print("  %+.4f, mentre nello stesso identico tratto di vita il gioco"
					% esito_ind["salita_f"])
			print("  di oggi la porta di %+.4f." % esito_ind["salita_c"])
		else:
			print("⇒ LA FIRMA NON C'È: dentro la finestra la quota fa %+.4f."
					% esito_ind["salita_f"])
		print("")
		print("  E SULL'INTERA VITA la quota SCENDE in tutti e due i bracci —")
		print("  %.4f → %.4f col controllo, %.4f → %.4f con la finestra — per un"
				% [esito_ind["c0"], esito_ind["cN"], esito_ind["f0"], esito_ind["fN"]])
		print("  confondente che con la plasticità non c'entra: le prove si")
		print("  ACCUMULANO, quindi l'ambiente pesa sempre di più. Chi volesse")
		print("  la firma sull'intera vita deve guardare la rGE, non questo.")
	else:
		print("⇒ LA MISURA NON È PRONTA: (a) o (b) non passa, e (c) non si legge.")
	print("")
	print("  Il blocco rGE, come lettura esplorativa: dentro la finestra")
	print("  %+.4f con la finestra contro %+.4f col controllo, e sull'intera"
			% [esito_rge["salita_f"], esito_rge["salita_c"]])
	print("  vita %.4f → %.4f contro %.4f → %.4f."
			% [esito_rge["f0"], esito_rge["fN"], esito_rge["c0"], esito_rge["cN"]])
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
	# il MINIMO dentro la finestra, e da li' si guarda la salita
	var i_min := 0
	for k in range(0, i_ad + 1):
		if float(q_fin[k]) < float(q_fin[i_min]):
			i_min = k
	var salita_f: float = float(q_fin[i_ad]) - float(q_fin[i_min])
	var salita_c: float = float(q_ctrl[i_ad]) - float(q_ctrl[i_min])
	var div_max := 0.0
	for k in range(i_ad, q_ctrl.size()):
		div_max = maxf(div_max, absf(float(q_ctrl[k]) - float(q_fin[k])))

	return {"c0": c0, "cN": cN, "f0": f0, "fN": fN, "div": div_max,
			"salita_f": salita_f, "salita_c": salita_c,
			"a": cN <= c0 + 0.010, "b": div_max <= 1e-9,
			"c": salita_f > 0.010 and salita_c <= 0.010}
