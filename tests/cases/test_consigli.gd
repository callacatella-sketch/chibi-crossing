extends RefCounted
## IL TACCUINO DELL'ATELIER — la guardia che non c'era.
##
## `Consigli.consiglia` è pura, statica e headless: gira in un test senza
## un albero della scena, senza un villaggio e senza uno schermo. Eppure
## fino al 2026-08-31 **non aveva un solo lettore in tutta la suite** —
## invertire un confronto faceva sparire il consiglio più importante (il
## letto scoperto, l'unico che cambia CHI abita il villaggio) e la suite
## restava completamente verde. È la forma di guasto che la REGOLA ZERO
## chiama «guardia che nessun test può far fallire»: una guardia che non c'è.
##
## Questo file prova COSA ESCE dai fatti, non come è scritto il sorgente.
## Le mutazioni provate una per volta, e le asserzioni che arrossiscono:
##
##  - `scoperti == 1` → `> 1`               .......... 3 rosse
##  - il peso del letto sotto quello del corredo .... 2 rosse
##  - `MAX` da 4 a 99 ............................... 1 rossa
##  - la carta del corredo senza il ramo singolare .. 2 rosse
##  - «quasi sempre» al posto del conto ............. 2 rosse
##  - il primo giorno che NON svuota le altre carte .. 2 rosse
const CONSIGLI := preload("res://scenes/build/Consigli.gd")

func run(t) -> void:
	_il_letto_scoperto_viene_prima(t)
	_il_singolare_del_corredo(t)
	_il_vicino_dice_il_conto_non_un_giudizio(t)
	_il_primo_giorno_zittisce_tutto(t)
	_il_silenzio_e_un_esito(t)
	_non_si_riempie_mai_la_colonna(t)
	_nessuna_carta_mette_in_debito(t)
	_il_carretto_non_promette_quel_che_non_ha(t)


## 1 — Il letto scoperto è il consiglio che cambia il villaggio, e sta
## SOPRA tutti: se scendesse sotto il corredo, il taglio a MAX potrebbe
## portarselo via proprio nel villaggio che ne ha più bisogno.
func _il_letto_scoperto_viene_prima(t) -> void:
	var uno: Array = CONSIGLI.consiglia({"posati": 12, "letti_scoperti": 1})
	t.eq(uno.size(), 1, "un letto scoperto produce una carta")
	t.ok(str(uno[0]["testo"]).contains("Un letto"), "e parla di UN letto")
	t.eq(str(uno[0]["pezzo"]), "Tetto", "e il bottone porta il Tetto")

	var tre: Array = CONSIGLI.consiglia({"posati": 12, "letti_scoperti": 3})
	t.ok(str(tre[0]["testo"]).contains("3"), "tre letti scoperti si contano")

	# con tutte le altre carte in gara, il letto resta il primo
	var pieno: Array = CONSIGLI.consiglia(_fatti_pieni())
	t.eq(str(pieno[0]["tono"]), "letto", "il letto scoperto sta davanti a tutto")


## 2 — «hai posato 1 pezzi su 14» è la macchina che si vede attraverso, e
## capita al PRIMO pezzo di ogni corredo: cioè proprio la prima volta che
## quella carta si legge.
func _il_singolare_del_corredo(t) -> void:
	var uno: Array = CONSIGLI.consiglia({"posati": 3, "corredo":
			{"capo": "Bancone bar", "messi": 1, "totale": 14, "prossimo": "Tenda bar"}})
	t.eq(uno.size(), 1, "il corredo cominciato produce una carta")
	var s := str(uno[0]["testo"])
	t.ok(not s.contains("1 pezzi"), "e NON dice «1 pezzi» (esce: %s)" % s)
	t.ok(s.contains("14"), "il totale si legge comunque")

	var nove: Array = CONSIGLI.consiglia({"posati": 3, "corredo":
			{"capo": "Bancone bar", "messi": 9, "totale": 14, "prossimo": "Tenda bar"}})
	t.ok(str(nove[0]["testo"]).contains("9 pezzi"), "e dal secondo in poi è plurale")

	# un corredo intatto NON è una cosa lasciata a metà: non se ne parla
	var zero: Array = CONSIGLI.consiglia({"posati": 3, "corredo":
			{"capo": "Bancone bar", "messi": 0, "totale": 14, "prossimo": "Tenda bar"}})
	t.eq(zero.size(), 0, "un corredo mai cominciato non è un debito")


## 3 — LA REGOLA DEL GUFO APPLICATA AL TACCUINO: si afferma solo ciò che
## si è visto, e con il suo campione accanto. «Quasi sempre» è
## un'inferenza, e un'inferenza il giocatore la può smentire — e una carta
## smentita non attenua la fiducia nel taccuino, la INVERTE.
func _il_vicino_dice_il_conto_non_un_giudizio(t) -> void:
	var c: Array = CONSIGLI.consiglia({"posati": 20, "vicino":
			{"perno": "Panchina", "nome": "Lampione", "quante": 3, "su": 4}})
	t.eq(c.size(), 1, "la carta del vicino esce")
	var s := str(c[0]["testo"])
	t.ok(s.contains("3") and s.contains("4"), "e porta il CONTO (%s)" % s)
	t.ok(not s.to_lower().contains("quasi sempre"),
			"e non dice «quasi sempre», che è un'inferenza (%s)" % s)
	t.eq(str(c[0]["pezzo"]), "Lampione", "il bottone porta il vicino, non il perno")


## 4 — Il primo giorno non si deduce niente, e allora si dice l'unica cosa
## vera. ⚠️ E si SVUOTA il resto: un villaggio vuoto che riceve tre
## consigli su cose che non ha è un cruscotto, non un taccuino.
func _il_primo_giorno_zittisce_tutto(t) -> void:
	var f := _fatti_pieni()
	f["posati"] = 0
	var c: Array = CONSIGLI.consiglia(f)
	t.eq(c.size(), 1, "il primo giorno c'è UNA carta sola")
	t.eq(str(c[0]["tono"]), "inizio", "ed è quella dell'inizio")
	t.eq(str(c[0]["pezzo"]), "Pavimento", "col posto da cui cominciare")


## 5 — Il silenzio è un esito. Un villaggio che non ha niente da farsi
## dire non riceve fondi di magazzino per riempire la colonna.
func _il_silenzio_e_un_esito(t) -> void:
	var c: Array = CONSIGLI.consiglia({"posati": 40})
	t.eq(c.size(), 0, "niente da dedurre, nessuna carta")


## 6 — Oltre quattro carte non è più un taccuino: è una lista di avvisi.
func _non_si_riempie_mai_la_colonna(t) -> void:
	var c: Array = CONSIGLI.consiglia(_fatti_pieni())
	t.ok(c.size() <= CONSIGLI.MAX,
			"al massimo %d carte (sono %d)" % [CONSIGLI.MAX, c.size()])
	t.ok(c.size() >= 3, "ma con cinque fatti veri non ne esce una sola")
	# e sono ordinate per peso: il taglio deve portarsi via le ultime
	for i in c.size() - 1:
		t.ok(int(c[i]["peso"]) >= int(c[i + 1]["peso"]),
				"le carte scendono di peso (%d prima di %d)"
				% [int(c[i]["peso"]), int(c[i + 1]["peso"])])


## 7 — LA REGOLA SACRA, terza domanda: il villaggio resta un posto dove si
## sta bene. Nessuna carta può mettere fretta o mettere in debito — e
## «ce l'hai da un po', e non l'hai mai posato» faceva tutte e due, per
## giunta su un pezzo comprato dal carretto dieci secondi prima (il fatto
## `mai_usato` non guarda da quanto lo possiedi).
func _nessuna_carta_mette_in_debito(t) -> void:
	var vietate := ["devi", "dovresti", "ti manca", "non hai mai",
			"da un po'", "completa", "sbrigati", "ancora non"]
	var f := _fatti_pieni()
	for prova in [f, {"posati": 0}, {"posati": 5, "mai_usato": "Sedia vimini"},
			{"posati": 5, "letti_scoperti": 2}]:
		for carta in CONSIGLI.consiglia(prova):
			var s := str(carta["testo"]).to_lower()
			for parola in vietate:
				t.ok(not s.contains(parola),
						"nessuna carta dice «%s» (%s)" % [parola, s])


## 8 — IL CARRETTO NON PROMETTE QUEL CHE NON HA. Il mercante vende 3-4
## pezzi per visita a rotazione, e passa ogni cinque-sette giorni: dire «ti
## aspetta al carretto» di un pezzo qualunque del listino è una promessa
## che il gioco non può mantenere — il giocatore mette da parte le
## noccioline, aspetta, apre il carretto e trova altre tre voci.
## ⚠️ E LA CURA NON È SPEGNERE LA CARTA: filtrare ai soli pezzi in banco la
## farebbe sparire cinque giorni su sei. Si dice la PROVENIENZA, che è vera
## sempre, invece della presenza.
func _il_carretto_non_promette_quel_che_non_ha(t) -> void:
	var base := {"nome": "Fontana", "costo": 120, "manca": 60, "cur": "nut",
			"puoi": false}
	var fuori := base.duplicate()
	fuori["oggi"] = false
	var c1: Array = CONSIGLI.consiglia({"posati": 9, "affare": fuori})
	t.eq(c1.size(), 1, "la carta esce anche se il pezzo non è sul banco oggi")
	var s1 := str(c1[0]["testo"])
	t.ok(not s1.contains("ti aspetta"),
			"e NON promette che è lì ad aspettarti (%s)" % s1)
	t.ok(s1.contains("60") and s1.contains("Fontana"),
			"ma dice quanto manca e per cosa (%s)" % s1)

	# la controprova: quando il pezzo È sul banco, la promessa si può fare
	var dentro := base.duplicate()
	dentro["oggi"] = true
	var c2: Array = CONSIGLI.consiglia({"posati": 9, "affare": dentro})
	t.eq(c2.size(), 1, "e la carta esce anche quando è sul banco")
	t.ok(str(c2[0]["testo"]).contains("ti aspetta"),
			"lì sì che ti aspetta (%s)" % str(c2[0]["testo"]))
	t.ok(str(c1[0]["testo"]) != str(c2[0]["testo"]),
			"e le due frasi sono DIVERSE, o la bandiera non serve a niente")


func _fatti_pieni() -> Dictionary:
	return {
		"posati": 30,
		"letti_scoperti": 2,
		"corredo": {"capo": "Bancone bar", "messi": 9, "totale": 14,
				"prossimo": "Tenda bar"},
		"vicino": {"perno": "Panchina", "nome": "Lampione", "quante": 3, "su": 4},
		"affare": {"nome": "Fontana", "costo": 120, "manca": 60, "cur": "nut",
				"puoi": false, "oggi": true},
		"mai_usato": "Sedia vimini",
	}
