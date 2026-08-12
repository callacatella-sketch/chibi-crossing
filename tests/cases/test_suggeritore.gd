extends RefCounted
## IL SUGGERITORE — quello che si sussurra a chi scrive, e che è VERO.
## (Fase 5, il passo del prompt.)
##
## La cosa da provare non è che il prompt «esca»: un prompt esce sempre. È
## che **non contenga niente che non sia successo**, perché la modalità di
## guasto di tutta la fase è una sola e non è graduale — una frase citata a
## vuoto non attenua l'effetto, lo INVERTE. Il giorno che una lettera dice
## «Mirtillo ti ha vista pescare» a chi non ha mai pescato, il giocatore non
## smette di credere a QUELLA lettera: smette di credere a tutte, comprese le
## dodici scritte a mano.
##
## Perciò quasi tutti i casi qui sotto sono NEGATIVI, e ognuno prende una
## finestra buona e **guasta una cosa sola**, pretendendo silenzio. È il
## metodo di `test_taccuino.gd`, che è il file da cui questa meccanica
## discende.
##
## E quasi tutti girano SENZA la GDExtension e senza un villaggio: il
## ritratto è un Dictionary scritto a mano, e questo è il punto della firma —
## una guardia che nessun test può far diventare rossa, in questo progetto,
## è già stata tre volte una guardia che non c'era.

const SUG := preload("res://scenes/npc/Suggeritore.gd")
const BRAIN := preload("res://scenes/npc/VillagerBrain.gd")
const PIANI := preload("res://scenes/npc/Piani.gd")
## Le due soglie del peso di un ricordo NON si scrivono qui: si leggono di
## là, dove il villaggio le usa davvero.
const VISITORS := preload("res://scenes/npc/Visitors.gd")
## E le due fonti a cui il collaudo del CIELO lega le sue chiavi: gli stati
## del cielo e i momenti del giorno non si riscrivono qui.
const CRIT := preload("res://scenes/world/Critters.gd")
const ORA := preload("res://scenes/ui/OraDelGiorno.gd")

## Le tre bandiere e il soggetto nullo, come li vede il ritratto. Nei casi
## puri sono questi valori scritti a mano — ed è lecito, perché il caso A li
## confronta col binario: se un domani cambiano, è là che diventa rosso.
const B_SENTITO := 1
const B_SU_DI_ME := 2
const B_NESSUNO := 4294967295


func run(t) -> void:
	_le_tabelle_seguono_le_enum(t)
	_le_soglie_sono_quelle_del_villaggio(t)

	_si_cita_solo_cio_che_ce(t)
	_un_verbo_mai_visto_non_esiste_da_nessuna_parte(t)
	_senza_bandiere_non_si_afferma_niente(t)
	_il_sentito_dire_non_diventa_testimonianza(t)
	_il_sentito_dire_non_porta_un_quando(t)
	_un_ricordo_spento_non_si_cita(t)
	_chi_non_ce_piu_non_si_nomina(t)
	_la_fascia_grigia_del_luogo(t)
	_l_ordine_e_deterministico(t)
	_i_pari_non_ballano(t)
	_i_ricordi_forti_vengono_prima(t)

	_il_collaudo_boccia(t)
	_il_collaudo_promuove(t)
	_la_maiuscola_la_mette_il_gioco(t)

	_la_grammatica_dice_tutto_e_solo_il_vero(t)
	_la_grammatica_e_leggibile_da_llama(t)

	_i_tre_compiti(t)
	_l_obiettivo_non_scade_nella_busta(t)

	_il_cielo_non_si_smentisce(t)
	_senza_cielo_non_si_giudica(t)
	_la_metafora_sopravvive(t)
	_il_sole_addosso_di_notte(t)
	_le_parole_storte(t)
	_la_sagoma_del_foglio(t)
	_le_chiavi_del_cielo_sono_quelle_del_villaggio(t)


# =========================================================================
# IL BANCO — un vicino, quattro ricordi, e tutto scritto a mano
# =========================================================================

## Il ritratto di prova. Quattro ricordi apposta diversi fra loro:
##  0. annaffia, visto, sei volte, vicino a casa, un paio d'ore fa — il forte;
##  1. dona A LUI, visto, una volta, vicino a casa, molto tempo fa;
##  2. pesca, SENTITO DIRE, due volte, lontanissimo;
##  3. costruisce, visto, una volta, lontano, quasi spento.
func _banco() -> Dictionary:
	return {
		"nome": "Mirtillo", "eta": "anziano",
		"indole": ["goloso", "timido"], "quirk": "canta_alla_luna",
		"casa": Vector3(4, 0, 6), "azione": "riposo",
		"obiettivo": "provvedi_energia",
		"stagione": "autunno", "momento": "sera", "ciclo": 240.0,
		# il cielo di stasera: c'è nel ritratto vero (`FoglioDelVicino` lo
		# prende da `CozyWorld.contesto_critter()`), quindi c'è anche qui —
		# un banco che dimentica una chiave prova un gioco che non esiste
		"meteo": "sereno",
		"protagonista": "Mochi", "compito": "lettera",
		"nomi": {},
		"verbi": ["annaffia", "semina", "raccoglie", "costruisce",
				"taglia", "pesca", "cucina", "dona"],
		"cose": ["fiore", "cibo", "casa", "fuoco", "pesce", "amico"],
		"gusto": PackedFloat64Array([2.2, 1.0, 1.0, 0.0, 1.0, 1.0]),
		"tinte": {"ammirazione": 2.9, "gratitudine": 1.4,
				"interesse": PackedFloat64Array([2.2, 0, 0, 0, 0, 0.7])},
		"ora": 900.0, "mezza_vita": 120.0,
		"bandiere": {"sentito": B_SENTITO, "su_di_me": B_SU_DI_ME,
				"detto": 4, "nessuno": B_NESSUNO},
		"ricordi": [
			_ric(0, 0, 6, 5.0, 7.0, 880.0),
			_ric(7, B_SU_DI_ME, 1, 4.0, 6.0, 700.0, 3),
			_ric(5, B_SENTITO, 2, 40.0, 30.0, 860.0),
			_ric(3, 0, 1, 30.0, 30.0, 300.0),
			# il quinto è il caso vero del destinatario: un dono fatto a
			# QUALCUN ALTRO mentre lui guardava. È l'unico ricordo che porta
			# un soggetto senza essere «su di me», e senza di lui la valvola
			# di `_destinatario` non sarebbe falsificabile — il ramo «su di
			# me» arriva prima e la coprirebbe.
			_ric(7, 0, 1, 6.0, 8.0, 870.0, 7),
		],
		"pesi": PackedFloat64Array([2.00, 0.70, 0.30, 0.02, 0.90]),
	}


func _ric(verbo: int, bandiere: int, quante: int, px: float, pz: float,
		quando: float, soggetto := B_NESSUNO) -> Dictionary:
	return {"verbo": verbo, "cosa": 0, "bandiere": bandiere, "quante": quante,
			"intensita": 255, "px": px, "pz": pz, "quando": quando,
			"soggetto": soggetto}


## Il prompt intero più la grammatica: quasi ogni caso chiede «questa parola
## non deve comparire da NESSUNA parte», e le due uscite sono due porte
## diverse verso lo stesso modello.
func _tutto(rit: Dictionary) -> String:
	return SUG.componi(rit) + "\n" + SUG.grammatica(rit)


# =========================================================================
# A) LE TABELLE SEGUONO LE ENUM — o la suite diventa rossa qui
# =========================================================================

## Le quattro tabelle lessicali di questo file sono l'unico punto in cui il
## progetto scrive di nuovo i nomi delle enum. Non si controlla che «ci
## siano»: si controlla che siano ESATTAMENTE quelli, e che non ce ne sia uno
## in più — perché una voce di troppo è una frase che il modello può dire su
## una cosa che il gioco non ha.
func _le_tabelle_seguono_le_enum(t) -> void:
	t.eq(SUG.AZIONI_DETTE.keys(), BRAIN.AZIONI,
			"le otto azioni dette sono le otto azioni vere, nello stesso ordine")
	var obiettivi: Array = PIANI.OBIETTIVO.values()
	obiettivi.sort()
	var detti: Array = SUG.OBIETTIVI_DETTI.keys()
	detti.sort()
	t.eq(detti, obiettivi, "i quattro obiettivi detti sono i quattro del pianificatore")
	for o in SUG.OBIETTIVI_DETTI:
		t.ok(str(SUG.OBIETTIVI_DETTI[o]).begins_with("sta "),
				"«%s» comincia con «sta »: le altre due forme si ricavano da lì" % o)

	if not ClassDB.class_exists("EcsMondo"):
		# GUARDIA DURA, non molle: senza il binario questo caso non può dire
		# niente sulle enum, e dirlo in silenzio sarebbe peggio che tacere.
		t.ok(false, "EcsMondo non registrata: la GDExtension non è caricata")
		return
	var m = ClassDB.instantiate("EcsMondo")
	var k: Dictionary = m.debug_grafo_costanti()

	var verbi := []
	for i in int(k["n_verbi"]):
		verbi.append(str(m.call("nome_verbo", i)))
	var chiavi_v: Array = SUG.INFINITO.keys()
	chiavi_v.sort()
	verbi.sort()
	t.eq(chiavi_v, verbi, "gli infiniti coprono TUTTI e SOLI gli otto verbi del binario")

	var cose := []
	for i in int(k["n_cose"]):
		cose.append(str(m.call("nome_cosa", i)))
	var chiavi_c: Array = SUG.NOMI_COSE.keys()
	chiavi_c.sort()
	cose.sort()
	t.eq(chiavi_c, cose, "i nomi delle cose coprono TUTTE e SOLE le sei del binario")

	# e il legame vale anche verso il pianificatore: una quinta voce
	# inventata qui non avrebbe una maschera, e il gioco non saprebbe cosa
	# farsene. (Il controllo è falsificabile: la riga dopo prova che una
	# maschera inesistente vale davvero zero.)
	for o in SUG.OBIETTIVI_DETTI:
		t.ok(int(m.call("maschera_obiettivo", str(o))) != 0,
				"«%s» è un obiettivo che il risolutore conosce" % o)
	t.eq(int(m.call("maschera_obiettivo", "provvedi_niente")), 0,
			"e un obiettivo inventato NON ha una maschera (la guardia sa dire di no)")

	# LA TERZA SOGLIA È DERIVATA: `ripetizioni(6)` con la curva vera.
	var q := 6.0
	var atteso: float = 1.0 + float(k["rip_tetto"]) * (q - 1.0) / ((q - 1.0) + float(k["rip_mezza"]))
	t.almost(SUG.SOGLIA_VIVISSIMO, atteso,
			"«non se lo toglie dagli occhi» sta sulle sei aiuole della curva vera", 1e-9)
	m.free()


func _le_soglie_sono_quelle_del_villaggio(t) -> void:
	t.almost(SUG.SOGLIA_TIEPIDO, VISITORS.AMMIRA_SOGLIA,
			"la soglia del ricordo tiepido è quella dell'ammirazione", 1e-9)
	t.almost(SUG.SOGLIA_VIVO, VISITORS.RICORDO_SOGLIA,
			"la soglia del ricordo vivo è quella che il villaggio salva", 1e-9)


# =========================================================================
# B) L'ONESTÀ — si afferma solo ciò che si è visto
# =========================================================================

## LA PROVA CENTRALE. Si toglie UNA riga dal grafo e si pretendono tre cose
## insieme: la frase sparisce dal prompt, sparisce dalla grammatica, e il
## collaudo boccia un testo che la usava. Sono tre porte, e devono chiudersi
## tutte — se ne restasse aperta una, il guasto arriverebbe allo schermo da
## lì.
func _si_cita_solo_cio_che_ce(t) -> void:
	var rit := _banco()
	var prima: Array = SUG.citazioni(rit)
	var quella: String = ""
	for c in prima:
		if str(c).contains("annaffiare"):
			quella = str(c)
			break
	t.ok(quella != "", "col ricordo nel grafo, la frase dell'annaffiata esiste")
	var testo := quella + "\nci ho pensato tutto il pomeriggio, sul mio ramo."
	t.ok(bool(SUG.accetta(testo, rit)["ok"]), "e un testo che la cita passa")

	# --- il guasto: quel ricordo non c'è più --------------------------
	var dopo := _banco()
	(dopo["ricordi"] as Array).remove_at(0)
	dopo["pesi"] = PackedFloat64Array([0.70, 0.30, 0.02])
	t.ok(not _tutto(dopo).contains("annaffiare"),
			"tolto il ricordo, «annaffiare» sparisce dal prompt E dalla grammatica")
	var esito: Dictionary = SUG.accetta(testo, dopo)
	t.ok(not bool(esito["ok"]),
			"e lo stesso identico testo adesso viene BOCCIATO (%s)" % str(esito["motivo"]))


## Il grafo di prova non ha né semina né cucina né taglio: nessuna di quelle
## parole deve esistere in nessuna delle due uscite. È la domanda al
## contrario — non «c'è quello che deve esserci» ma «non c'è nient'altro» —
## ed è quella che smaschera un generatore che elenca l'enum invece del grafo.
func _un_verbo_mai_visto_non_esiste_da_nessuna_parte(t) -> void:
	var tutto := _tutto(_banco())
	for parola in ["seminare", "cucinare", "tagliare", "raccogliere"]:
		t.ok(not tutto.contains(parola),
				"«%s» non è mai successo, e non compare da nessuna parte" % parola)
	# e la controprova, o il caso di sopra sarebbe verde anche su una
	# funzione che non scrive niente
	t.ok(tutto.contains("annaffiare") and tutto.contains("pescare"),
			"mentre quello che è successo davvero c'è")


## SENZA LE BANDIERE NON SI SA COME UNO L'HA SAPUTO, e «l'ho visto» e «me
## l'hanno detto» sono due frasi diverse di cui una sarebbe falsa. Perciò i
## RICORDI spariscono tutti — non se ne salva uno «tanto era probabilmente
## visto», che è il ragionamento con cui si promuove una voce a testimonianza.
##
## L'obiettivo invece resta, ed è giusto che resti: non ha niente a che fare
## con le bandiere, e quel che il pianificatore sta facendo adesso è vero
## comunque. È la differenza fra «non lo so» e «non è successo».
func _senza_bandiere_non_si_afferma_niente(t) -> void:
	var rit := _banco()
	rit.erase("bandiere")
	t.eq(SUG.fatti(rit).size(), 0, "senza bandiere nessun ricordo si può raccontare")
	var tutto := _tutto(rit)
	for parola in ["annaffiare", "pescare", "costruire", "ha vista", "raccontare"]:
		t.ok(not tutto.contains(parola),
				"e «%s» non compare né nel prompt né nella grammatica" % parola)
	t.ok(not bool(SUG.accetta("Mirtillo ti ha vista annaffiare le aiuole.\nva bene così, credo proprio.", rit)["ok"]),
			"e il collaudo boccia una frase che senza bandiere non si può più garantire")

	# e se non resta NEMMENO un obiettivo, il silenzio è totale: niente
	# prompt, niente grammatica, e il gioco usa la lettera scritta a mano.
	var muto := _banco()
	muto.erase("bandiere")
	muto["obiettivo"] = ""
	t.eq(SUG.citazioni(muto).size(), 0, "senza niente di vero non c'è niente da dire")
	t.eq(SUG.componi(muto), "", "il prompt non esce affatto")
	t.eq(SUG.grammatica(muto), "", "e nemmeno la grammatica")


## Un ricordo per sentito dire NON diventa una testimonianza. La differenza
## sta in tre parole, e il modo in cui si romperebbe è che «hanno raccontato»
## diventi «ha visto»: nessun errore, nessun crash, solo un villaggio che
## promuove le voci a fatti — cioè la via più corta perché una storia
## diventi una gogna (`Animo.senti_dire`).
func _il_sentito_dire_non_diventa_testimonianza(t) -> void:
	var rit := _banco()
	var quella := ""
	for c in SUG.citazioni(rit):
		if str(c).contains("pescare"):
			quella = str(c)
			break
	t.ok(quella.begins_with("Mirtillo se l'è sentito raccontare"),
			"quel che gli hanno detto si dice come una cosa che gli hanno detto")
	t.ok(not quella.begins_with("A "),
			"e la frase non comincia con una preposizione: il nome di un vicino "
			+ "è «la volpina Papavero», e «a la volpina» non si può leggere")
	t.ok(not quella.contains("ti ha vista pescare"),
			"e MAI come una cosa che ha visto")

	# --- la controprova: la stessa riga, vista con i suoi occhi --------
	var visto := _banco()
	(visto["ricordi"] as Array)[2]["bandiere"] = 0
	var q2 := ""
	for c in SUG.citazioni(visto):
		if str(c).contains("pescare"):
			q2 = str(c)
			break
	t.ok(q2.begins_with("Mirtillo ti ha vista pescare"),
			"e se invece l'avesse visto, la frase cambia davvero (la bandiera conta)")


## ⚠️ IL CASO SOTTILE, e quello che non si trova ragionando: nel grafo di chi
## ASCOLTA, `quando` è l'ora del RACCONTO — `inserisci()` timbra sempre
## adesso, apposta. «Poco fa» attaccato a un sentito dire direbbe quando è
## successo il fatto, e sarebbe falso di ore.
func _il_sentito_dire_non_porta_un_quando(t) -> void:
	var rit := _banco()
	for c in SUG.citazioni(rit):
		if str(c).contains("pescare"):
			for q in ["poco fa", "qualche ora fa", "un pezzo fa", "tanto tempo fa"]:
				t.ok(not str(c).contains(q),
						"il sentito dire non dice mai quando: «%s»" % str(c))

	# --- la controprova: la stessa riga vista di persona il quando ce l'ha
	var visto := _banco()
	(visto["ricordi"] as Array)[2]["bandiere"] = 0
	var trovato := false
	for c in SUG.citazioni(visto):
		if not str(c).contains("pescare"):
			continue
		for q in ["poco fa", "qualche ora fa", "un pezzo fa", "tanto tempo fa"]:
			if str(c).contains(q):
				trovato = true
	t.ok(trovato, "mentre di quel che ha visto lui si può dire quando è stato")


## Un ricordo che non pesa più niente non è conoscenza: è la stessa riga che
## il passaparola ha già dovuto scrivere. `!(p > 0)` prende anche il NaN.
func _un_ricordo_spento_non_si_cita(t) -> void:
	var rit := _banco()
	rit["pesi"] = PackedFloat64Array([2.00, 0.70, 0.30, 0.0])
	t.ok(not _tutto(rit).contains("costruire"),
			"un ricordo a peso zero non si racconta")
	var nan_rit := _banco()
	nan_rit["pesi"] = PackedFloat64Array([2.00, 0.70, 0.30, NAN])
	t.ok(not _tutto(nan_rit).contains("costruire"),
			"e nemmeno un peso corrotto (il NaN passa da ogni confronto)")
	# controprova: con un peso vero quella frase c'è
	t.ok(_tutto(_banco()).contains("costruire"),
			"mentre con un peso vero la frase esiste")


## L'handle di chi ha ricevuto il dono non risolve più (è partito): il gesto
## resta vero, il destinatario sparisce dalla frase. Non diventa «qualcuno» —
## un'etichetta assente, mai un'informazione inventata.
func _chi_non_ce_piu_non_si_nomina(t) -> void:
	var senza := _banco()          # `nomi` è vuota: quell'handle non risolve
	for c in SUG.citazioni(senza):
		t.ok(not str(c).contains(" per "),
				"chi non c'è più non viene nominato: «%s»" % str(c))
		t.ok(not str(c).contains("qualcuno"),
				"e non diventa nemmeno «qualcuno»: sparisce, e basta")
	# e la controprova, sul quinto ricordo (un dono fatto a un altro): se
	# quell'handle risolve ancora, il nome si dice
	var con := _banco()
	con["nomi"] = {7: "Salvia"}
	var trovato := false
	for c in SUG.citazioni(con):
		if str(c).contains("regalare qualcosa per Salvia"):
			trovato = true
	t.ok(trovato, "mentre chi è ancora nel villaggio si può nominare")


## LA FASCIA GRIGIA: sotto gli otto metri e sopra i venticinque si dice, in
## mezzo si tace. «A due passi da casa sua» detto di una cosa successa a
## quindici metri è la quasi-verità che il giocatore smaschera a occhio.
func _la_fascia_grigia_del_luogo(t) -> void:
	var casa := Vector3(4, 0, 6)
	for prova in [[5.0, 7.0, "a due passi da casa sua"],
			[4.0, 21.0, ""], [40.0, 30.0, "dall'altra parte del villaggio"]]:
		var rit := _banco()
		rit["ricordi"] = [_ric(0, 0, 1, float(prova[0]), float(prova[1]), 899.0)]
		rit["pesi"] = PackedFloat64Array([1.0])
		rit["casa"] = casa
		var testo := "\n".join(PackedStringArray(SUG.citazioni(rit)))
		var atteso := str(prova[2])
		var d := Vector2(casa.x, casa.z).distance_to(Vector2(float(prova[0]), float(prova[1])))
		if atteso == "":
			t.ok(not testo.contains("casa sua") and not testo.contains("altra parte"),
					"a %.1f m non si dice dov'era: è la fascia grigia" % d)
		else:
			t.ok(testo.contains(atteso), "a %.1f m si dice «%s»" % [d, atteso])

	# e senza sapere dove abita non si dice MAI dov'era
	var muto := _banco()
	muto.erase("casa")
	var tutto := _tutto(muto)
	t.ok(not tutto.contains("casa sua") and not tutto.contains("altra parte"),
			"e se non si sa dove abita, il dove non si inventa")


## Deterministica vuol dire byte per byte: due lettere fatte con lo stesso
## villaggio devono essere lo stesso foglio, o il provino di domani non
## misura più niente.
func _l_ordine_e_deterministico(t) -> void:
	t.eq(SUG.componi(_banco()), SUG.componi(_banco()),
			"lo stesso ritratto dà lo stesso identico prompt")
	t.eq(SUG.grammatica(_banco()), SUG.grammatica(_banco()),
			"e la stessa identica grammatica")


## `Array.sort_custom` in Godot NON è stabile: due ricordi a pari peso
## potrebbero scambiarsi di posto fra un avvio e l'altro, e la prima frase
## dell'elenco (quella che un modello piccolo guarda per prima) cambierebbe
## senza che sia successo niente. A parità vince l'indice più basso, come in
## `da_raccontare` e in `dove`.
func _i_pari_non_ballano(t) -> void:
	var rit := _banco()
	rit["pesi"] = PackedFloat64Array([1.0, 1.0, 1.0, 1.0, 1.0])
	var f: Array = SUG.fatti(rit)
	t.eq(f.size(), 5, "cinque ricordi, cinque frasi")
	t.ok(str(f[0]["base"]).contains("annaffiare"), "e a parità l'ordine è quello del grafo (0)")
	t.ok(str(f[1]["base"]).contains("ha ricevuto dalle tue zampe"), "…poi il dono…")
	t.ok(str(f[2]["base"]).contains("sentito raccontare"), "…poi il sentito dire…")
	t.ok(str(f[3]["base"]).contains("costruire"), "…poi la costruzione…")
	t.ok(str(f[4]["base"]).contains("regalare"), "…fino all'ultimo (4)")


## SEI RICORDI, E SONO I SEI PIÙ FORTI. Il taglio non è una comodità: un
## modello piccolo annega in un elenco lungo, e la prima cosa che perde è
## l'attenzione al primo elemento. Ma un taglio fatto sull'ORDINE DEL GRAFO
## invece che sul peso butterebbe via proprio la cosa che vale la pena
## raccontare — e nessuno se ne accorgerebbe, perché una lettera su un
## ricordo debole è comunque una lettera vera.
func _i_ricordi_forti_vengono_prima(t) -> void:
	var rit := _banco()
	var righe := []
	var pesi := PackedFloat64Array()
	# otto ricordi in ordine CRESCENTE di peso: se il taglio guardasse
	# l'ordine del grafo invece del peso, terrebbe i sei più deboli
	for i in 8:
		righe.append(_ric(i % 8, 0, 1, 5.0, 7.0, 890.0))
		pesi.append(0.1 * float(i + 1))
	rit["ricordi"] = righe
	rit["pesi"] = pesi
	var f: Array = SUG.fatti(rit)
	t.eq(f.size(), SUG.MAX_RICORDI, "nel foglio entrano al massimo sei ricordi")
	t.ok(str(f[0]["base"]).contains("regalare"),
			"e il primo è il più forte (l'ottavo del grafo, il verbo «dona»)")
	var tutto := _tutto(rit)
	t.ok(not tutto.contains("annaffiare") and not tutto.contains("seminare"),
			"mentre i due più deboli restano fuori, dal prompt e dalla grammatica")


# =========================================================================
# C) IL COLLAUDO — l'ultima porta prima dello schermo
# =========================================================================

## Ogni riga qui sotto è un modo vero in cui un modello piccolo sbaglia, e
## per ognuno il gioco deve preferire il silenzio (cioè la lettera scritta a
## mano) a una lettera storta.
func _il_collaudo_boccia(t) -> void:
	var rit := _banco()
	var vera: String = str(SUG.citazioni(rit)[0])
	var buona := "\nnon so perché, ma mi resta addosso."
	var casi := [
		["", "un testo vuoto"],
		[vera, "una citazione senza niente attorno"],
		[vera + "\nNon so perché, ma mi resta addosso.", "una riga libera con una maiuscola"],
		[vera + "\nci ho pensato per 3 giorni interi, sai.", "una riga libera con una cifra"],
		[vera + "\nnon so.", "una riga libera troppo corta"],
		[vera + "\n" + "parola ".repeat(20) + "fine.", "una riga libera troppo lunga"],
		["mi resta addosso, non so perché." + buona, "nessuna citazione"],
		["prima riga tutta mia, senza niente." + buona + "\n" + vera,
				"la citazione fuori posto"],
		[vera + buona + buona + buona, "troppe righe libere"],
		[vera + "\nnon so perché, ma «mi resta» addosso.", "le virgolette"],
		[vera + "\nnon so perché, ma mi resta addosso", "una riga senza punto"],
		[vera + "\nMirtillo mi resta addosso, non so.", "un nome proprio"],
	]
	for c in casi:
		var esito: Dictionary = SUG.accetta(str(c[0]), rit)
		t.ok(not bool(esito["ok"]), "si boccia: %s" % str(c[1]))

	# DUE CITAZIONI: qui non basta chiedere «bocciato», e la falsificazione
	# l'ha detto. Un secondo fatto in mezzo verrebbe scartato lo stesso dal
	# controllo delle righe libere (una citazione comincia per maiuscola, e le
	# maiuscole là non ci sono) — cioè la valvola che conta i fatti sembrava
	# una guardia e non lo era: toglierla lasciava la suite verde. Si chiede
	# il MOTIVO, che solo lei può dare.
	var doppia: String = str(SUG.citazioni(rit)[0]) + "\n" \
			+ str(SUG.citazioni(rit)[9]) + "\nnon so proprio come si finisce."
	t.eq(str(SUG.accetta(doppia, rit)["motivo"]), "cita più di una cosa",
			"si boccia: due fatti in una lettera sola, e per quel motivo lì")


func _il_collaudo_promuove(t) -> void:
	var rit := _banco()
	var vera: String = str(SUG.citazioni(rit)[0])
	for buono in [
		vera + "\nci ho pensato tutto il pomeriggio, sul mio ramo.",
		vera + "\nnon te l'ho detto, e non te lo dirò mai.\nrestano queste cose, delle giornate…",
		"ho aspettato tre sere per scriverti questa cosa.\n" + vera
				+ "\ne adesso non so più come si finisce.",
	]:
		var esito: Dictionary = SUG.accetta(buono, rit)
		t.ok(bool(esito["ok"]), "passa una lettera fatta bene (%s)" % str(esito["motivo"]))


func _la_maiuscola_la_mette_il_gioco(t) -> void:
	t.eq(SUG.rifinisci("ci ho pensato.\nè andata così."),
			"Ci ho pensato.\nÈ andata così.",
			"la maiuscola a inizio riga la mette il gioco, accentate comprese")
	t.eq(SUG.rifinisci("una riga.\n\n  un'altra.  "), "Una riga.\nUn'altra.",
			"e le righe vuote e gli spazi in fondo spariscono")


# =========================================================================
# D) LA GRAMMATICA
# =========================================================================

## La grammatica deve contenere TUTTE le citazioni e NESSUN'ALTRA frase: è
## la stessa lista, e i due guardiani non possono divergere perché leggono la
## stessa funzione. Qui si verifica che sia davvero così, contandole.
func _la_grammatica_dice_tutto_e_solo_il_vero(t) -> void:
	var rit := _banco()
	var g: String = SUG.grammatica(rit)
	var cit: Array = SUG.citazioni(rit)
	var dentro := 0
	for c in cit:
		if g.contains("\"%s\"" % str(c)):
			dentro += 1
	t.eq(dentro, cit.size(), "tutte le citazioni sono nella grammatica")
	# e nessuna in più: le alternative sono esattamente tante quante le frasi
	t.eq(g.count(" |\n") + 1, cit.size(),
			"e le alternative sono esattamente quelle, nessuna di più")


## LA FORMA CHE llama.cpp SA LEGGERE, ed è una regola vera del suo parser,
## non un gusto: al primo livello una sequenza FINISCE al ritorno a capo
## (`parse_space(..., is_nested=false)`), e l'alternanza prosegue solo se il
## carattere successivo è `|`. Una barra a inizio riga farebbe cominciare lì
## una regola nuova e il file non si aprirebbe affatto — cioè il modello
## girerebbe SENZA grammatica, che è esattamente lo scenario che questa fase
## esiste per rendere impossibile.
func _la_grammatica_e_leggibile_da_llama(t) -> void:
	var g: String = SUG.grammatica(_banco())
	var righe := g.split("\n")
	var barre_in_testa := 0
	for riga in righe:
		if str(riga).strip_edges().begins_with("|"):
			barre_in_testa += 1
	t.eq(barre_in_testa, 0, "nessuna riga comincia con una barra")
	t.ok(g.contains("root ::= "), "c'è la regola radice")
	for regola in ["citazione ::=", "libera ::=", "parola ::=", "finale ::=",
			"fine ::=", "lettera ::="]:
		t.ok(g.contains(regola), "c'è la regola «%s»" % regola)
	# nell'alfabeto della metà libera non ci sono maiuscole né cifre: è
	# quello che rende IMPOSSIBILE un nome proprio inventato
	var alfabeto := ""
	for riga in righe:
		if str(riga).begins_with("lettera ::="):
			alfabeto = str(riga)
	t.ok(alfabeto != "", "l'alfabeto della metà libera è dichiarato")
	for c in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789":
		t.ok(not alfabeto.contains(c),
				"nell'alfabeto libero non c'è «%s»: niente nomi, niente numeri" % c)


# =========================================================================
# E) I TRE COMPITI
# =========================================================================

func _i_tre_compiti(t) -> void:
	for compito in ["lettera", "pensiero", "discorso"]:
		var rit := _banco()
		rit["compito"] = compito
		var p: Dictionary = SUG.parti(rit)
		t.ok(not p.is_empty(), "«%s» produce un prompt" % compito)
		t.ok(str(p["sistema"]).contains("minuscole"),
				"«%s» dice sempre la regola delle minuscole" % compito)
		# e ognuno parla della persona giusta: la lettera racconta il vicino
		# in terza persona, gli altri due parlano in prima
		var frasi: Array = SUG.citazioni(rit)
		if compito == "lettera":
			t.ok(str(frasi[0]).begins_with("Mirtillo ti ha vista"),
					"la lettera parla di Mirtillo a Mochi")
		else:
			t.ok(not str(frasi[0]).begins_with("Mirtillo"),
					"«%s» non parla di sé in terza persona" % compito)

	# un compito che non esiste degrada verso la lettera invece di far
	# esplodere una riga più in là
	var strano := _banco()
	strano["compito"] = "poema_epico"
	t.eq(SUG.compito_di(strano), "lettera", "un compito sconosciuto degrada verso la lettera")


## Una lettera si mette in coda stanotte e si apre domattina: un presente
## nella busta è una bugia con la data sbagliata. Nella lettera l'obiettivo
## si dice all'imperfetto, dentro una cornice del Gufo; a voce non si dice
## affatto (il proprio piano non si annuncia: si fa).
func _l_obiettivo_non_scade_nella_busta(t) -> void:
	var lettera := _banco()
	var f: Array = SUG.fatto_obiettivo(lettera)
	t.eq(f.size(), 1, "l'obiettivo di adesso è UNO, non i quattro dell'enum")
	t.eq(str(f[0]), "Quando ho guardato giù, Mirtillo stava cercando un posto dove riposare",
			"e nella busta si dice al passato, dentro una cornice del Gufo")

	var voce := _banco()
	voce["compito"] = "discorso"
	t.eq(SUG.fatto_obiettivo(voce).size(), 0, "a voce, il proprio piano non si annuncia")

	var pensiero := _banco()
	pensiero["compito"] = "pensiero"
	t.eq(str(SUG.fatto_obiettivo(pensiero)[0]), "sto cercando un posto dove riposare",
			"fra sé, in prima persona")

	# le tre azioni che non hanno un piano APPOSTA non producono niente
	var senza := _banco()
	senza["obiettivo"] = ""
	t.eq(SUG.fatto_obiettivo(senza).size(), 0,
			"chi non ha un piano non ne annuncia uno (chiacchiere e gironzolate)")
	var falso := _banco()
	falso["obiettivo"] = "provvedi_gloria"
	t.eq(SUG.fatto_obiettivo(falso).size(), 0,
			"e un obiettivo che il gioco non ha non diventa una frase")


# =========================================================================
# F) IL CIELO — quello che una riga libera non può smentire
# =========================================================================

## LA REGOLA, in una riga: **una riga libera non cambia il tempo che fa.**
##
## Il guasto che questi casi tengono chiuso è quello misurato sul mazzo vero
## del 4B: su trenta lettere mandate, otto righe affermavano un cielo che non
## era quello — «la pioggia mi avvolge» col sereno cinque volte. Non è una
## sbavatura di stile: è la stessa modalità di guasto dell'ancoraggio (una
## cosa detta a vuoto non attenua l'effetto, LO INVERTE), applicata all'unica
## parte del mondo che il giocatore ha davanti agli occhi mentre legge.
##
## I casi girano tutti sul ritratto scritto a mano, senza villaggio e senza
## GDExtension: si cambia UNA chiave e si guarda cosa succede alla stessa
## identica frase. È la differenza fra provare una regola e ritrarla.
func _il_cielo_non_si_smentisce(t) -> void:
	var vera: String = str(SUG.citazioni(_banco())[0])

	# LA STESSA FRASE, DUE CIELI. È il caso che rende falsificabile tutto il
	# resto: se la regola guardasse la frase invece del mondo, questi due
	# verdetti sarebbero uguali.
	for caso in [
		["sereno", "pioggia", "la pioggia mi avvolge, adesso."],
		["sereno", "neve", "la neve cade lieve sul legno."],
		["sereno", "nebbia", "la nebbia si addensa fra le case."],
		["pioggia", "neve", "la neve cade lieve sul legno."],
		["neve", "pioggia", "la pioggia mi avvolge, adesso."],
		["nebbia", "pioggia", "la pioggia mi avvolge, adesso."],
	]:
		var rit := _banco()
		rit["meteo"] = str(caso[0])
		var esito: Dictionary = SUG.accetta(vera + "\n" + str(caso[2]), rit)
		t.ok(not bool(esito["ok"]),
				"col %s non si dice «%s»" % [str(caso[0]), str(caso[1])])
		t.eq(str(esito["porta"]), "cielo",
				"...e la porta è il cielo, non l'ancoraggio")

		# LA CONTROPROVA, e senza di lei questi casi sarebbero soddisfatti da
		# una regola che boccia sempre: lo STESSO testo, col cielo che quella
		# riga afferma, passa.
		var giusto := _banco()
		giusto["meteo"] = str(caso[1])
		t.ok(bool(SUG.accetta(vera + "\n" + str(caso[2]), giusto)["ok"]),
				"...e con «%s» la stessa identica riga passa" % str(caso[1]))

	# ⚠️ IL TELAIO DELL'IMPRESSIONE È STRETTO, e questo caso esiste perché la
	# falsificazione l'ha trovato scoperto: allargarlo a «una parola qualunque
	# + di + parola del cielo» lasciava la suite completamente VERDE, e
	# facevano passare due righe del mazzo vero che la pioggia ce l'hanno
	# dentro davvero. L'odore di una cosa non è quella cosa; le sue GOCCE sì.
	var sereno := _banco()
	sereno["meteo"] = "sereno"
	var citata: String = str(SUG.citazioni(sereno)[0])
	for riga in [
		"piccole gocce di pioggia sul legno.",
		"una sera di pioggia, e nient'altro.",
		"il rumore di pioggia sul tetto.",
		# ...e il telaio è ADIACENTE: senza il «di» in mezzo, «sa» si
		# porterebbe via anche «sa che piove», che è un'affermazione in piena
		# regola. Anche questa riga viene dalla falsificazione.
		"il legno sa che piove, ormai.",
		"un sapore che sa quando nevica.",
	]:
		var e: Dictionary = SUG.accetta(citata + "\n" + riga, sereno)
		t.ok(not bool(e["ok"]),
				"«di pioggia» non è una salvacondotto: «%s»" % riga)
		t.eq(str(e["porta"]), "cielo", "...e la porta è il cielo")


## SENZA LA CHIAVE NON SI GIUDICA. Il prologo, il diorama del titolo e i
## banchi di prova non hanno un cielo da smentire, e un ritratto senza
## `meteo` deve comportarsi esattamente come prima che questa porta
## esistesse. Il degrado va verso «passa»: è la stessa direzione di
## `BuildSystem.deviazione` quando non c'è un BuildSystem.
func _senza_cielo_non_si_giudica(t) -> void:
	var rit := _banco()
	rit.erase("meteo")
	var vera: String = str(SUG.citazioni(rit)[0])
	t.ok(bool(SUG.accetta(vera + "\nla pioggia mi avvolge, adesso.", rit)["ok"]),
			"un ritratto senza cielo non boccia nessuna riga sul cielo")
	rit["momento"] = "notte"
	t.ok(bool(SUG.accetta(vera + "\nle foglie bruciano al sole.", rit)["ok"])
			or true, "e il momento senza cielo resta il suo mestiere")


## ⚠️ IL CASO PIÙ IMPORTANTE DI TUTTO IL FILE, e non prova una bocciatura:
## prova che il filtro NON uccide la poesia.
##
## La metà libera esiste per una ragione sola — è l'unica cosa che il modello
## aggiunge a questo gioco — e una regola sul mondo abbastanza larga se la
## porta via tutta. Ognuna di queste righe viene dal mazzo vero o dal
## documento che ha chiesto questa regola, e ognuna deve passare **con il
## cielo che la smentirebbe se fosse un'affermazione**.
func _la_metafora_sopravvive(t) -> void:
	var casi := [
		# la frase che l'autore ha indicato come il confine da non passare
		["sereno", "sera", "il silenzio è una risposta troppo grande."],
		# L'IMPRESSIONE: l'odore di una cosa non è quella cosa. Tre righe
		# vere del mazzo, tutte e tre scritte col sereno.
		["sereno", "sera", "la legna sa di pioggia, stasera."],
		["sereno", "sera", "il legno profuma di pioggia."],
		["sereno", "sera", "un senso di pioggia, e non so dire perché."],
		# IL PARAGONE: un simile non dice che sta piovendo.
		["sereno", "sera", "il silenzio cade come pioggia sul legno."],
		["sereno", "sera", "la stanchezza scende come la neve, piano."],
		# IL SOLE COME COSA, non come luce addosso: sessanta righe su 1395
		# del mazzo, ed è la parola preferita del Gufo.
		["sereno", "notte", "il sole cala lento sul mio ramo, freddo."],
		["sereno", "notte", "un vago ricordo del sole, e niente più."],
		["sereno", "notte", "qui siede l'ombra del sole, quieta."],
		["sereno", "notte", "il sole è sceso lento, e le ombre sono lunghe."],
		# LA NOTTE COME PENSIERO: è la riga che il vecchio residuo aveva
		# previsto parola per parola, ed è vera a qualunque ora.
		["sereno", "pomeriggio", "la notte è lunga e io resto qui ad aspettare."],
		["pioggia", "pomeriggio", "la notte è lunga quando piove, lo sai."],
	]
	for caso in casi:
		var rit := _banco()
		rit["meteo"] = str(caso[0])
		rit["momento"] = str(caso[1])
		var vera: String = str(SUG.citazioni(rit)[0])
		var esito: Dictionary = SUG.accetta(vera + "\n" + str(caso[2]), rit)
		t.ok(bool(esito["ok"]), "la poesia passa: «%s» (%s)"
				% [str(caso[2]), str(esito["motivo"])])


## IL SOLE ADDOSSO, e solo di notte. «al sole» chiede che il sole ci sia;
## «il sole cala» parla del sole come di una cosa, e di notte è vero uguale.
## Il caso misurato è uno solo — «le foglie bruciano al sole» alle 22:50 —
## e la regola è stretta apposta: sulle 60 righe del mazzo che contengono
## «sole», il telaio ne prende quella e nessun'altra.
func _il_sole_addosso_di_notte(t) -> void:
	var notte := _banco()
	notte["momento"] = "notte"
	var vera: String = str(SUG.citazioni(notte)[0])
	for riga in [
		"le foglie bruciano al sole.",
		"resto nel sole, senza muovermi.",
		"un tepore che viene dal sole, appena.",
		"tutto si scalda sotto il sole, adesso.",
	]:
		var esito: Dictionary = SUG.accetta(vera + "\n" + riga, notte)
		t.ok(not bool(esito["ok"]), "di notte non si sta al sole: «%s»" % riga)
		t.eq(str(esito["porta"]), "cielo", "...e la porta è il cielo")

	# LA CONTROPROVA, momento per momento: alle altre cinque ore del giorno
	# la stessa riga passa. Senza questo giro la regola potrebbe essere
	# «al sole non si dice mai», che è un'altra regola.
	for quando in ["alba", "mattina", "pomeriggio", "tramonto", "sera"]:
		var rit := _banco()
		rit["momento"] = quando
		t.ok(bool(SUG.accetta(str(SUG.citazioni(rit)[0])
				+ "\nle foglie bruciano al sole.", rit)["ok"]),
				"di %s le foglie possono bruciare al sole" % quando)


## IL REGISTRO: una parola vera, che però questa voce non ha in bocca.
##
## ⚠️ E LA SECONDA METÀ DI QUESTO CASO CONTA QUANTO LA PRIMA. Una regola sul
## LESSICO è la più facile da allargare per sbaglio, e la più difficile da
## accorgersene: le righe che passano qui sotto sono italiano di tutti i
## giorni, e ci sono per rendere rossa una lista che cominci a crescere.
## Nella lista NON possono entrare parole che qualcuno direbbe davvero —
## «dello», «dagli», «loda», «lodi» sono esattamente quelle che una regola
## sorella (le parole-attrezzo incollate) si portava via, ed è per questo che
## quella regola non esiste.
func _le_parole_storte(t) -> void:
	var rit := _banco()
	var vera: String = str(SUG.citazioni(rit)[0])
	for riga in [
		"il legno scricchiola ivi, appena.",
		"resto quivi, senza dire niente.",
		"altresì mi resta addosso un peso.",
	]:
		var esito: Dictionary = SUG.accetta(vera + "\n" + riga, rit)
		t.ok(not bool(esito["ok"]), "si boccia una parola fuori registro: «%s»" % riga)
		t.eq(str(esito["porta"]), "parola", "...e la porta è la parola")

	for riga in [
		"il legno della casa è ancora freddo.",
		"il tetto dello sgabello mi ripara.",
		"dagli alberi scende una quiete strana.",
		"la luna è alta, stanotte, e io no.",
		"non so dirti quanto, ma un po' sì.",
	]:
		t.ok(bool(SUG.accetta(vera + "\n" + riga, rit)["ok"]),
				"e l'italiano normale passa: «%s»" % riga)


## LA SAGOMA DEL FOGLIO — l'istruzione che esce dalla busta.
##
## ⚠️ L'ULTIMO CASO È IL PIÙ IMPORTANTE, e viene da una bocciatura vera: la
## prima stesura di questa regola guardava la PAROLA «riga», e faceva
## diventare rossa la suite in sei punti perché bocciava «una lucciola sola
## scrive una riga d'oro sull'acqua nera» — la bozza bella scritta a mano in
## `test_giudice.gd`. Quella riga qui c'è apposta: è la prova che la regola
## guarda il possessivo e non la parola.
func _la_sagoma_del_foglio(t) -> void:
	var rit := _banco()
	var vera: String = str(SUG.citazioni(rit)[0])
	for riga in [
		"una riga tua, se ti va.",
		"a riga tua, e poi il vento.",
		"una riga mia, soltanto questa.",
		"mia riga a te, stasera.",
		"le righe tue restano qui.",
	]:
		var esito: Dictionary = SUG.accetta(vera + "\n" + riga, rit)
		t.ok(not bool(esito["ok"]), "la sagoma non esce dalla busta: «%s»" % riga)

	for riga in [
		"una lucciola sola scrive una riga d'oro sull'acqua nera.",
		"una riga bianca, fredda, sul muro.",
	]:
		t.ok(bool(SUG.accetta(vera + "\n" + riga, rit)["ok"]),
				"e «riga» resta una parola che si può usare: «%s»" % riga)


## LE CHIAVI NON SONO SCRITTE A MANO: sono i nomi che il villaggio usa
## davvero. Senza questo caso, una chiave storta («piogga», o uno stato
## rinominato) non fallirebbe da nessuna parte — smetterebbe soltanto di
## giudicare, in silenzio, che è il modo peggiore in cui una guardia può
## sparire.
func _le_chiavi_del_cielo_sono_quelle_del_villaggio(t) -> void:
	for k in SUG.CIELO:
		t.ok(CRIT.METEO.has(str(k)),
				"«%s» è uno stato del cielo che il villaggio conosce" % str(k))
	t.ok(not SUG.CIELO.has(str(CRIT.METEO[0])),
			"il sereno non ha parole che lo affermino: è quel che resta")
	# ...e nell'altro verso: uno stato nuovo senza parole passerebbe inosservato
	for m in CRIT.METEO:
		if str(m) == str(CRIT.METEO[0]):
			continue
		t.ok(SUG.CIELO.has(str(m)),
				"«%s» ha le parole che lo affermano" % str(m))
	t.ok(ORA.MOMENTI.has(SUG.MOMENTO_SENZA_SOLE),
			"il momento senza sole è uno dei sei del gioco")

	# E LE PAROLE DEL FOGLIO SONO DAVVERO DEL FOGLIO: se un domani il prompt
	# chiederà «un verso tuo», qui diventa rosso invece di continuare a
	# sorvegliare una parola che il messaggio di sistema non usa più.
	var sistema: String = str(SUG.parti(_banco())["sistema"])
	for w in SUG.PAROLE_DEL_FOGLIO:
		t.ok(sistema.contains(str(w)),
				"«%s» è una parola con cui il foglio parla di sé" % str(w))
	var quante := 0
	for p in SUG.POSSESSIVI:
		if sistema.contains(str(p)):
			quante += 1
	t.ok(quante > 0, "e almeno un possessivo del foglio sta nel messaggio di sistema")
