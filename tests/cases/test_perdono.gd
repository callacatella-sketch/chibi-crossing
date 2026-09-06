## IL PERDONO COLLETTIVO — la voce buona viaggia sulla stessa strada.
##
## Il malcontento si propagava e il sollievo no: `simula_giorno` passava
## `senti_dire(da, "giocatore", -1.0, forza)` con la valenza CABLATA a meno
## uno, e la forza era `eco()`, che vale zero per chiunque stia bene. Ma
## `senti_dire` è a due segni per costruzione e `opinione` pure: il canale
## del sollievo esisteva ed era vuoto. Il giocatore poteva riparare con la
## persona ferita ma non col villaggio.
##
## Qui si guardano le due cose che rendono la meccanica onesta invece che
## una macchina che si autoconsola:
##
##  1. IL SOLLIEVO NON COSTA MENO DEL RANCORE. Se smorzasse di più, la
##     rivolta diventerebbe reversibile in un giorno e la scala perderebbe
##     senso. La valenza si DERIVA da `Animo.SCONTO_PERDONO` — lo stesso
##     sconto con cui un ricordo bello smorza il rancore dentro una persona
##     sola — invece di essere un secondo numero da tenere allineato.
##  2. SI IRRADIA L'EVENTO, MAI IL LIVELLO. `eco()` guarda dove uno STA e
##     lo racconta ogni giorno finché ci resta; `eco_serena()` guarda cosa
##     è SUCCESSO ieri e lo racconta una volta sola. Irradiare il livello
##     farebbe dei sereni una sorgente permanente, e il villaggio si
##     rimetterebbe a posto da solo — cioè la riparazione del giocatore non
##     varrebbe più niente.
##
## LA MUTAZIONE CHE QUESTI CASI DEVONO FAR ARROSSIRE: in `eco_serena`,
## `return (1.0 - frazione(gradino)) * (0.5 + 0.5 * tratto("orgoglio"))`
## — il livello al posto dell'evento.

extends RefCounted

const ANIMO := preload("res://scenes/npc/Animo.gd")
const VILLAGGIO := preload("res://scenes/npc/Villaggio.gd")


func run(t) -> void:
	_le_due_valenze_si_derivano(t)
	_una_voce_buona_pesa_quanto_una_cattiva(t)
	_la_salita_non_produce_sollievo(t)
	_il_sollievo_e_un_giorno_solo(t)
	_l_ampiezza_e_il_gradino_di_partenza(t)
	_un_sereno_non_e_una_sorgente_permanente(t)
	_la_tensione_non_conta_il_sollievo(t)
	_il_sollievo_gira_come_il_rancore(t)
	_il_sollievo_passa_dagli_stessi_cancelli(t)
	_il_sollievo_ripetuto_si_abitua(t)
	_la_cronaca_dice_il_verso(t)
	_la_cronaca_dice_da_dove_veniva(t)
	_chi_ha_una_notizia_buona_tace_quella_cattiva(t)
	_un_disertore_non_porta_nemmeno_le_buone_notizie(t)
	_il_sollievo_sopravvive_al_salvataggio(t)
	_il_sollievo_non_costa_meno_del_rancore(t)
	_la_cronaca_della_rivolta_resta_identica(t)
	_chi_ha_visto_tutta_la_storia_non_finisce_meglio_di_prima(t)


func _abitante(nome: String, tratti := {}, sogno := "boscaiolo"):
	var a = ANIMO.new()
	a.setup({"name": nome, "seed": abs(hash(nome)), "sogno": sogno, "tratti": tratti})
	return a


## Un carattere che la scala la sale davvero: fedele a sé stesso e per
## niente al villaggio. Sono i tratti con cui `test_villaggio` fabbrica la
## sua rivolta, e stanno qui una volta sola.
func _ribelle(nome: String):
	return _abitante(nome, {"lealta": 0.0, "orgoglio": 0.9, "codardia": 0.05,
			"grinta": 0.8, "ambizione": 0.9}, "guerriero")


## Porta un animo in alto sulla scala, e torna il gradino raggiunto.
##
## ⚠️ LA SCALA NON SI METTE A MANO, e non la guida la FATICA. `aggiorna_scala`
## tiene tutto ciò che sta sopra il «rifiuto» dietro `rancore >= 0.30`: senza
## torti veri attribuiti al giocatore, un vicino stanco morto resta al primo
## gradino per sempre. La prima stesura di questo banco lo faceva lavorare e
## basta, e misurava un gradino 0 credendo di aver fabbricato una rivolta.
func _fai_salire(a, giorni := 60) -> int:
	for g in giorni:
		a.esegue("taglia_legna")   # tradisce il sogno del guerriero: è un torto
		if g == 20:
			a.lutto("Pepe")
		a.aggiorna_scala()
		a.passa_giorno()
	return a.gradino


# ── 1. le due valenze non sono due numeri scritti a mano ────────────────
func _le_due_valenze_si_derivano(t) -> void:
	t.almost(VILLAGGIO.VALENZA_SOLLIEVO, 1.0 / ANIMO.SCONTO_PERDONO,
			"la valenza del sollievo si DERIVA dallo sconto del perdono", 1e-9)
	t.eq(VILLAGGIO.VALENZA_RANCORE, -1.0, "e quella del rancore resta quella di sempre")
	# LA DIREZIONE CHE CONTA: il sollievo non può smorzare più del rancore,
	# o la rivolta diventa reversibile in un giorno
	t.ok(absf(VILLAGGIO.VALENZA_SOLLIEVO) <= absf(VILLAGGIO.VALENZA_RANCORE),
			"il sollievo non costa MENO del rancore (%.3f contro %.3f)"
			% [absf(VILLAGGIO.VALENZA_SOLLIEVO), absf(VILLAGGIO.VALENZA_RANCORE)])


# ── 1b. e la SIMMETRIA sta nella valenza, non nel peso ──────────────────
##
## `senti_dire` non guarda il segno: il peso è `credito * forza * (1 -
## resistenza * 0.75)`, e la valenza entra solo dopo, moltiplicando lo
## spostamento dell'opinione. È questa simmetria a tenere in piedi
## l'invariante «chi rompe e ripara non ci guadagna»: se una notizia buona
## pesasse di più, l'asimmetria fra i due canali si potrebbe recuperare
## dalla porta di servizio, e la somma delle forze in cronaca smetterebbe
## di essere il numero che racconta la storia.
##
## E i due gemelli devono essere VERGINI di voci: l'attesa di `Limbico` è
## una sola per la coppia `sentito_dire|giocatore`, quindi due chiamate
## sullo stesso animo non sono più confrontabili.
func _una_voce_buona_pesa_quanto_una_cattiva(t) -> void:
	var buona = _abitante("Gemella")
	var cattiva = _abitante("Gemella")
	buona.legami["Fonte"] = 0.7
	cattiva.legami["Fonte"] = 0.7
	var p_buona: float = buona.senti_dire("Fonte", "giocatore", VILLAGGIO.VALENZA_SOLLIEVO, 0.9)
	var p_cattiva: float = cattiva.senti_dire("Fonte", "giocatore", VILLAGGIO.VALENZA_RANCORE, 0.9)
	t.ok(p_buona > 0.0, "la voce buona attecchisce (peso %.6f)" % p_buona)
	t.almost(p_buona, p_cattiva,
			"…e pesa ESATTAMENTE quanto una cattiva: il peso non guarda il segno", 1e-6)
	# lo scarto sta tutto nello spostamento dell'opinione, e vale lo sconto
	# del perdono: 1.4, lo stesso con cui un ricordo bello smorza il rancore
	# dentro una persona sola
	var s_buona: float = float(buona.opinione["giocatore"])
	var s_cattiva: float = float(cattiva.opinione["giocatore"])
	t.ok(s_buona > 0.0 and s_cattiva < 0.0, "…e i due versi sono opposti")
	t.almost(absf(s_cattiva / s_buona), ANIMO.SCONTO_PERDONO,
			"…nel rapporto esatto dello sconto del perdono", 1e-6)


# ── 2. chi PEGGIORA non porta buone notizie ─────────────────────────────
func _la_salita_non_produce_sollievo(t) -> void:
	var a = _ribelle("Salita")
	_fai_salire(a)
	t.ok(a.gradino > 0, "è salito sulla scala (gradino %d)" % a.gradino)
	t.eq(a.eco_serena(), 0.0,
			"chi ieri è SALITO non irradia sollievo: la buona notizia è la discesa")
	t.ok(a.eco() > 0.0, "…mentre il malcontento lo irradia eccome")


# ── 3. l'EVENTO, non il livello: una volta sola ─────────────────────────
func _il_sollievo_e_un_giorno_solo(t) -> void:
	var a = _ribelle("Giorno")
	_fai_salire(a)
	var alto = a.gradino
	# lo si rimette a posto: ricordi belli finché non ridiscende
	var sceso := false
	for g in 40:
		a.ricorda("regalo", "giocatore", 1.0, 1.0)
		a.passa_giorno()
		if a.aggiorna_scala() and a.gradino < alto:
			sceso = true
			break
	t.ok(sceso, "una riparazione lo fa scendere di gradino")
	if not sceso:
		return
	# il giorno DOPO la discesa (la finestra è ieri, non oggi)
	a.oggi += 1
	var primo = a.eco_serena()
	t.ok(primo > 0.0, "il giorno dopo la discesa il sollievo si irradia (%.3f)" % primo)
	# e il giorno ancora dopo, TACE
	a.oggi += 1
	t.eq(a.eco_serena(), 0.0,
			"…e il giorno dopo ancora TACE: è l'evento che si racconta, non lo stato")


# ── 4. l'ampiezza è quella del gradino da cui si è scesi ────────────────
func _l_ampiezza_e_il_gradino_di_partenza(t) -> void:
	var basso = _abitante("Poco")
	var alto = _abitante("Molto")
	# due discese finte, dallo stesso arrivo ma da partenze diverse
	basso.scatti = [{"giorno": 4, "da": ANIMO.SCALA[2], "a": ANIMO.SCALA[1]}]
	alto.scatti = [{"giorno": 4, "da": ANIMO.SCALA[5], "a": ANIMO.SCALA[1]}]
	basso.oggi = 5
	alto.oggi = 5
	t.ok(alto.eco_serena() > basso.eco_serena(),
			"chi torna in sé da più in alto è una notizia più grande (%.3f > %.3f)"
			% [alto.eco_serena(), basso.eco_serena()])


# ── 5. LA GUARDIA CENTRALE: un sereno non è una sorgente ────────────────
func _un_sereno_non_e_una_sorgente_permanente(t) -> void:
	var v = VILLAGGIO.new()
	for nome in ["Serena", "Quieta", "Calma"]:
		v.aggiungi(_abitante(nome))
	v.lega("Serena", "Quieta")
	v.lega("Quieta", "Calma")
	# trenta giorni di villaggio contento: nessuno è mai sceso da niente,
	# perché nessuno è mai salito
	var sollievi := 0
	for g in 30:
		for nome in v.animi:
			v.animi[nome].esegue("taglia_legna")
		for r in v.simula_giorno():
			if str(r.get("tipo", "")) == "voce" \
					and str(r.get("verso", "")) == "sollievo":
				sollievi += 1
	t.eq(sollievi, 0,
			"un villaggio che sta bene da sempre NON irradia sollievo: non è successo niente")
	for nome in v.animi:
		t.eq(v.animi[nome].eco_serena(), 0.0,
				"…e nessuno dei sereni è una sorgente (%s)" % nome)


# ── 6. la tensione somma solo il malcontento ────────────────────────────
func _la_tensione_non_conta_il_sollievo(t) -> void:
	var v = VILLAGGIO.new()
	var a = _ribelle("Teso")
	v.aggiungi(a)
	_fai_salire(a)
	var t_prima = v.tensione()
	# gli si appiccica una discesa di ieri: il sollievo c'è…
	a.scatti = [{"giorno": a.oggi - 1, "da": ANIMO.SCALA[5], "a": ANIMO.SCALA[2]}]
	t.ok(a.eco_serena() > 0.0, "…il sollievo c'è")
	t.almost(v.tensione(), t_prima,
			"…ma la tensione NON lo conta: misura il malcontento, non l'umore", 1e-9)


# ── 7. il sollievo gira sulla STESSA strada ─────────────────────────────
func _il_sollievo_gira_come_il_rancore(t) -> void:
	var v = VILLAGGIO.new()
	for nome in ["Ponte", "AmicoA", "AmicoB"]:
		v.aggiungi(_abitante(nome))
	v.lega("Ponte", "AmicoA")
	v.lega("Ponte", "AmicoB")
	var p = v.animi["Ponte"]
	# Ponte è quello che ieri è tornato in sé
	p.scatti = [{"giorno": p.oggi, "da": ANIMO.SCALA[6], "a": ANIMO.SCALA[2]}]
	for nome in v.animi:
		v.animi[nome].oggi += 1
	var prima_a: float = float(v.animi["AmicoA"].opinione.get("giocatore", 0.0))
	v.simula_giorno()
	var dopo_a: float = float(v.animi["AmicoA"].opinione.get("giocatore", 0.0))
	# ⚠️ IL CONFRONTO E' STRETTO, e la prima stesura lo aveva largo: un `>=`
	# e' soddisfatto anche da «non e' successo niente», quindi quel caso non
	# sapeva fallire se il sollievo smetteva di girare. MISURATO: parte da
	# zero esatto (e' vergine di voci) e arriva a +0.1466.
	t.almost(prima_a, 0.0, "AmicoA parte vergine di voci", 1e-9)
	t.ok(dopo_a > prima_a,
			"la buona notizia arriva addosso agli amici di chi è tornato in sé (%.4f → %.4f)"
			% [prima_a, dopo_a])


# ── 8. la cronaca dice da che parte tira la voce ────────────────────────
func _la_cronaca_dice_il_verso(t) -> void:
	var v = VILLAGGIO.new()
	for nome in ["Uno", "Due"]:
		v.aggiungi(_abitante(nome))
	v.lega("Uno", "Due")
	var u = v.animi["Uno"]
	u.scatti = [{"giorno": u.oggi, "da": ANIMO.SCALA[6], "a": ANIMO.SCALA[1]}]
	for nome in v.animi:
		v.animi[nome].oggi += 1
	var cronaca: Array = v.simula_giorno()
	var con_verso := 0
	var senza := 0
	for r in cronaca:
		if str(r.get("tipo", "")) != "voce":
			continue
		if r.has("verso"):
			con_verso += 1
		else:
			senza += 1
	# IL TIPO RESTA "voce": test_villaggio._test_niente_fantasmi filtra su
	# quello, e con un tipo nuovo coprirebbe metà del canale continuando a
	# passare
	t.eq(senza, 0, "ogni voce dice il suo verso, e il tipo resta «voce»")
	t.ok(con_verso > 0, "…e qualche voce è girata (%d)" % con_verso)


# ── 9. una notizia per oratore ──────────────────────────────────────────
func _chi_ha_una_notizia_buona_tace_quella_cattiva(t) -> void:
	var v = VILLAGGIO.new()
	for nome in ["Misto", "Ascolta"]:
		v.aggiungi(_abitante(nome))
	v.lega("Misto", "Ascolta")
	var m = v.animi["Misto"]
	# è sceso di un gradino, ma è ancora in alto: ha ENTRAMBE le notizie
	_fai_salire(m)
	m.scatti = [{"giorno": m.oggi, "da": ANIMO.SCALA[6], "a": ANIMO.SCALA[4]}]
	m.gradino = 4
	for nome in v.animi:
		v.animi[nome].oggi += 1
	t.ok(m.eco() > 0.0 and m.eco_serena() > 0.0,
			"ha davvero tutte e due le notizie (eco %.2f, serena %.2f)"
			% [m.eco(), m.eco_serena()])
	var cronaca: Array = v.simula_giorno()
	var rancori := 0
	for r in cronaca:
		if str(r.get("tipo", "")) == "voce" and str(r.get("da", "")) == "Misto" \
				and str(r.get("verso", "")) == "rancore":
			rancori += 1
	t.eq(rancori, 0,
			"chi ha una notizia buona TACE quella cattiva: non dice e disdice nello stesso giro")


# ── 10. e sopravvive al giro dal disco ──────────────────────────────────
func _il_sollievo_sopravvive_al_salvataggio(t) -> void:
	var a = _abitante("Salvata")
	a.scatti = [{"giorno": 9, "da": ANIMO.SCALA[5], "a": ANIMO.SCALA[2]}]
	a.oggi = 10
	var atteso = a.eco_serena()
	t.ok(atteso > 0.0, "prima del salvataggio il sollievo c'è (%.3f)" % atteso)
	# il giro VERO: JSON, dove gli interi tornano float
	var salvato: Dictionary = JSON.parse_string(JSON.stringify(a.save()))
	var b = _abitante("Salvata")
	b.load(salvato)
	t.almost(b.eco_serena(), atteso,
			"…e dopo il giro da JSON è identico: il giorno rientra come float", 1e-6)


# ── 11. la buona notizia passa dai cancelli del rancore, non dai suoi ────
##
## `PASSAGGI`, `SMORZAMENTO` e `SOGLIA_VOCE` sono gli stessi per le due
## notizie, e questo caso lo guarda dal comportamento invece che dalle
## costanti: quante volte una voce arriva addosso a un amico, e quanto si
## consuma per strada. Un sollievo con cancelli suoi sarebbe la stessa
## famiglia di guasto della forza smorzata — mezzo canale che si legge come
## un canale intero.
func _il_sollievo_passa_dagli_stessi_cancelli(t) -> void:
	# una discesa GRANDE: sopravvive a tutti e due i giri di bocca
	var grandi := _voci_di_una_discesa(6, 1, 0.9)
	t.eq(grandi.size(), VILLAGGIO.PASSAGGI,
			"una buona notizia grande fa tutti i giri di bocca che fa una cattiva")
	# e si consuma per strada dello STESSO smorzamento. ⚠️ la cronaca
	# arrotonda la forza a 0.01, quindi su 0.31 e 0.17 il rapporto porta
	# ±0.025 di incertezza per costruzione: la tolleranza è quella, non un
	# numero scelto per far passare il caso
	if grandi.size() == VILLAGGIO.PASSAGGI:
		t.almost(grandi[1] / grandi[0], VILLAGGIO.SMORZAMENTO,
				"…e si smorza dello stesso smorzamento (%.2f → %.2f)"
				% [grandi[0], grandi[1]], 0.03)
	# una discesa PICCOLA: il secondo giro cade sotto la soglia. MISURATO:
	# 0.0714 di ampiezza, che per 0.55 fa 0.0393 — sotto SOGLIA_VOCE (0.06)
	var piccole := _voci_di_una_discesa(1, 0, 0.0)
	t.eq(piccole.size(), 1,
			"una buona notizia piccola non arriva al secondo giro: la soglia è la stessa")
	t.ok(piccole.size() >= 1 and piccole[0] > 0.0,
			"…ma il primo giro lo fa (%s)" % str(piccole))


## Le forze, giro per giro, delle voci prodotte da UNA discesa scritta a
## mano. Un abitante fresco ha rancore zero e gradino zero, quindi
## `aggiorna_scala` non lo tocca e lo scatto appiccicato sopravvive al
## passo 1 di `simula_giorno` — è l'idioma con cui questo file fabbrica una
## discesa senza doverne prima montare una vera.
func _voci_di_una_discesa(da_g: int, a_g: int, orgoglio: float) -> Array:
	var v = VILLAGGIO.new()
	var fonte = _abitante("Fonte", {"orgoglio": orgoglio})
	v.aggiungi(fonte)
	v.aggiungi(_abitante("Ascolta"))
	v.lega("Fonte", "Ascolta")
	fonte.scatti = [{"giorno": fonte.oggi, "da": ANIMO.SCALA[da_g], "a": ANIMO.SCALA[a_g]}]
	for nome in v.animi:
		v.animi[nome].oggi += 1
	var forze := []
	for r in v.simula_giorno():
		if str(r.get("tipo", "")) == "voce" and str(r.get("verso", "")) == "sollievo":
			forze.append(float(r.get("forza", 0.0)))
	return forze


# ── 12. e ci si abitua, come a qualunque altra cosa ─────────────────────
##
## Il sollievo passa dal `Limbico` come ogni altro fatto: quello che resta
## non è la notizia, è quanto ha sorpreso. Sentirsi dire ogni giorno che va
## tutto bene si incide sempre meno — ed è la ragione per cui il canale non
## si può usare per rimettere a posto un villaggio a forza di ripetizioni.
##
## Gli oratori sono DIVERSI ogni giorno apposta: `senti_dire` ha un gettone
## giornaliero per oratore, e l'attesa del Limbico è invece una sola per
## `sentito_dire|giocatore`. Così l'abitudine si vede senza toccare niente
## di privato.
func _il_sollievo_ripetuto_si_abitua(t) -> void:
	var a = _abitante("Abitudine")
	var incisi := []
	for g in 6:
		a.oggi = g
		var chi := "Voce%d" % g
		a.legami[chi] = 0.9
		var quanti: int = a.ricordi.size()
		a.senti_dire(chi, "giocatore", VILLAGGIO.VALENZA_SOLLIEVO, 1.0)
		if a.ricordi.size() > quanti:
			incisi.append(float(a.ricordi[a.ricordi.size() - 1]["valenza"]))
	t.eq(incisi.size(), 6, "ogni giorno la voce ha lasciato il suo ricordo")
	if incisi.size() < 6:
		return
	var sempre_meno := true
	for i in range(1, incisi.size()):
		if incisi[i] >= incisi[i - 1]:
			sempre_meno = false
	t.ok(sempre_meno,
			"la stessa buona notizia si incide sempre meno (%.4f → %.4f)"
			% [incisi[0], incisi[incisi.size() - 1]])
	t.ok(incisi[incisi.size() - 1] > 0.0,
			"…ma resta una buona notizia: l'abitudine smorza, non capovolge")


# ── 13. la cronaca dice DA DOVE veniva, non solo dove è arrivato ────────
##
## È la metà pura della correzione M1a. La battuta del gradino d'arrivo,
## letta su una DISCESA, rimprovera chi sta guarendo: chi mostra il toast
## deve poter distinguere le due direzioni, e l'unico modo è che la cronaca
## porti il gradino di partenza. `Animo.scatti` lo scriveva già; la cronaca
## lo buttava.
##
## ⚠️ E IL DEGRADO VA VERSO IERI: `indice("")` vale -1, quindi con un `da`
## mancante — una cronaca vecchia, un doppio di banco — `indice(a) >
## indice(da)` resta vero e il toast esce come è sempre uscito. Chi cabla il
## cancello si appoggia a questa riga: sta qui perché non diventi un caso
## per errore.
func _la_cronaca_dice_da_dove_veniva(t) -> void:
	var arco := _arco_completo()
	var scatti: Array = arco["scatti"]
	t.ok(scatti.size() >= 4, "l'arco ha prodotto degli scatti (%d)" % scatti.size())
	var senza_da := 0
	var salite := 0
	var discese := 0
	for r in scatti:
		var i_da := ANIMO.indice(str(r.get("da", "")))
		var i_a := ANIMO.indice(str(r.get("a", "")))
		if i_da < 0 or i_a < 0:
			senza_da += 1
			continue
		if i_a > i_da:
			salite += 1
		elif i_a < i_da:
			discese += 1
	t.eq(senza_da, 0, "ogni scatto dice da quale gradino veniva, e nomina un gradino vero")
	# ⚠️ tutte e due le direzioni, o il campo resterebbe non provato proprio
	# nel verso per cui esiste
	t.ok(salite > 0, "…e la cronaca contiene salite (%d)" % salite)
	t.ok(discese > 0, "…e discese (%d): è la direzione per cui il campo esiste" % discese)
	# il degrado, che il cablaggio del toast legge alla lettera
	t.eq(ANIMO.indice(""), -1, "un «da» mancante non nomina nessun gradino")
	t.ok(ANIMO.indice(ANIMO.SCALA[0]) > ANIMO.indice(""),
			"…quindi senza «da» il confronto legge una salita: si degrada verso ieri")


# ── 14. un disertore non porta NESSUNA notizia, nemmeno buona ───────────
##
## `simula_giorno` cicla solo `animi`, e `rimuovi` archivia in `partiti`:
## chi se n'è andato smette di spettegolare in tutti e due i versi. Non è
## una regola scritta apposta — è la stessa struttura che gli toglieva la
## voce cattiva — ma va provata, o la prossima stesura del passo 2 potrebbe
## andarsela a ripescare per «non perdere una buona notizia».
func _un_disertore_non_porta_nemmeno_le_buone_notizie(t) -> void:
	var v = VILLAGGIO.new()
	for nome in ["Partito", "Resta"]:
		v.aggiungi(_abitante(nome))
	v.lega("Partito", "Resta")
	var p = v.animi["Partito"]
	p.scatti = [{"giorno": p.oggi, "da": ANIMO.SCALA[6], "a": ANIMO.SCALA[1]}]
	for nome in v.animi:
		v.animi[nome].oggi += 1
	# LA CONTROPROVA: finché è qui, la buona notizia gira davvero
	t.ok(p.eco_serena() > 0.0,
			"il partito AVEVA una buona notizia da portare (%.3f)" % p.eco_serena())
	v.rimuovi("Partito")
	var voci := 0
	for r in v.simula_giorno():
		if str(r.get("tipo", "")) == "voce":
			voci += 1
	t.eq(voci, 0, "…ma se n'è andato, e chi se n'è andato non parla più")
	t.almost(float(v.animi["Resta"].opinione.get("giocatore", 0.0)), 0.0,
			"…e chi resta non ha sentito niente", 1e-9)


# ── 15. l'ARCO: il sollievo non costa meno del rancore, misurato ────────
##
## Il confronto fra le due costanti (caso 1) dice che il sollievo non
## smorza di più a parità di voce. Questo dice la cosa più grande, e la
## dice sulla storia intera: il rancore si irradia OGNI GIORNO finché uno
## resta lassù, il sollievo UNA VOLTA per discesa. È l'asimmetria
## strutturale, e i due numeri si stampano perché un rapporto che si
## restringe è la prima cosa che si vedrebbe cambiare.
func _il_sollievo_non_costa_meno_del_rancore(t) -> void:
	var arco := _arco_completo()
	var rancore: float = float(arco["rancore"])
	var sollievo: float = float(arco["sollievo"])
	t.ok(sollievo > 0.0, "sull'arco il sollievo è girato davvero (Σ %.3f)" % sollievo)
	t.ok(rancore > 0.0, "…e il rancore pure (Σ %.3f)" % rancore)
	t.ok(sollievo <= rancore,
			"su una storia intera il sollievo NON costa meno del rancore (Σ %.3f contro Σ %.3f)"
			% [sollievo, rancore])


# ── 16. e il racconto della rivolta non cambia ─────────────────────────
##
## `primo_focolaio` cerca il `giorno` minimo fra gli scatti scartando solo
## quelli arrivati a «lavoro»: una DISCESA verso un gradino qualunque entra
## in gara come una salita. Oggi non morde, perché una discesa arriva
## sempre dopo la salita che l'ha preceduta — ma è una cosa da provare, non
## da dedurre: chi ha acceso la miccia deve restare quello che l'ha accesa
## anche dopo che il giocatore ha rimesso tutto a posto.
func _la_cronaca_della_rivolta_resta_identica(t) -> void:
	var arco := _arco_completo()
	var prima: Dictionary = arco["focolaio_a_meta"]
	var dopo: Dictionary = arco["focolaio_finale"]
	t.ok(not prima.is_empty(), "a rivolta montata c'è un focolaio")
	t.eq(str(dopo.get("chi", "")), str(prima.get("chi", "")),
			"chi ha acceso la miccia resta quello, anche dopo la riparazione")
	t.eq(int(dopo.get("giorno", -1)), int(prima.get("giorno", -2)),
			"…e il giorno pure: una discesa non ruba il posto di focolaio")
	t.eq(str(dopo.get("gradino", "")), str(prima.get("gradino", "")),
			"…e il gradino con cui è cominciata")
	# e il focolaio è davvero la PRIMA SALITA, non la prima riga qualunque
	var prima_salita := 999999
	for r in (arco["scatti"] as Array):
		var i_da := ANIMO.indice(str(r.get("da", "")))
		var i_a := ANIMO.indice(str(r.get("a", "")))
		if i_a > i_da and int(r.get("giorno_villaggio", -1)) >= 0:
			prima_salita = mini(prima_salita, int(r["giorno_villaggio"]))
	t.eq(int(prima.get("giorno", -1)), prima_salita,
			"il focolaio è il giorno della prima SALITA della storia")


# ── 17. M1b: chi ha visto tutta la storia non ci guadagna ───────────────
##
## LA GUARDIA CHE RENDE IL CICLO «ROMPO E RIPARO» NON REDDITIZIO, ed è la
## domanda che nessuno dei due lati si era fatto: dopo una rivolta montata
## e riparata per intero, il villaggio resta più ben disposto di com'era
## prima che cominciasse? Se sì, il gioco paga chi fa del male e poi
## rimedia — e in un gioco cozy questo è peggio di un exploit: è una
## lezione.
##
## Regge per costruzione (il rancore si irradia ogni giorno, il sollievo
## una volta per discesa), ma «regge per costruzione» è esattamente il tipo
## di cosa che una taratura futura può portarsi via in silenzio. MISURATO
## su quest'arco: Σ 42.24 di rancore contro Σ 2.36 di sollievo, e le
## opinioni finiscono a -0.86.
##
## ⚠️ L'INVARIANTE VALE SU CHI ERA QUI DAL PRIMO GIORNO, e chi arriva dopo
## si esclude NOMINANDOLO: uno che ha sentito solo la buona notizia può
## legittimamente finire sopra zero — il villaggio gli ha parlato bene di
## te. La controprova sta qui sotto, o l'esclusione sarebbe una riga che
## nessun test può far fallire.
func _chi_ha_visto_tutta_la_storia_non_finisce_meglio_di_prima(t) -> void:
	var arco := _arco_completo()
	var v = arco["villaggio"]
	# senza questi due, l'invariante sarebbe vera su un villaggio in cui non
	# è successo niente
	t.ok(int(arco["salite"]) >= 3,
			"la rivolta è montata davvero (%d salite)" % int(arco["salite"]))
	t.ok(int(arco["discese"]) >= 1,
			"…ed è stata riparata davvero (%d discese)" % int(arco["discese"]))
	t.almost(v.tensione(), 0.0, "…fino a rimettere la tensione a zero", 1e-9)
	for nome in (arco["dal_primo_giorno"] as Array):
		var o: float = float(v.animi[nome].opinione.get("giocatore", 0.0))
		t.ok(o <= 0.0,
				"%s ha visto tutta la storia e non finisce meglio di prima (%.5f)"
				% [nome, o])
	# LA CONTROPROVA, che rende l'esclusione una cosa vera invece di una
	# cautela: il nuovo arrivato è entrato il giorno in cui il capo è tornato
	# sereno, ha sentito solo la buona notizia, e finisce sopra zero
	var tardi: String = str(arco["arrivato_dopo"])
	t.ok(v.animi.has(tardi), "il villaggio ha davvero un arrivato dopo (%s)" % tardi)
	if v.animi.has(tardi):
		var o_t: float = float(v.animi[tardi].opinione.get("giocatore", 0.0))
		t.ok(o_t > 0.0,
				"…e chi ha sentito solo il sollievo finisce sopra zero (%.5f): per questo l'invariante lo esclude"
				% o_t)


## L'ARCO COMPLETO: una rivolta montata in trenta giornate e poi riparata
## per intero, con la cronaca contata riga per riga.
##
## Costa una settantina di giornate di villaggio, e tre casi lo chiedono:
## si calcola UNA volta sola e si tiene. Non è una cache di comodo — due
## corse dello stesso arco sarebbero due villaggi, e i tre casi
## racconterebbero storie leggermente diverse. (MISURATO deterministico su
## tre corse: Σ 42.2400 / Σ 2.3600, opinioni identiche al quinto decimale.)
var _arco := {}


func _arco_completo() -> Dictionary:
	if not _arco.is_empty():
		return _arco
	var v = VILLAGGIO.new()
	var capo = _ribelle("Capo")
	v.aggiungi(capo)
	for nome in ["Vicina", "Altro"]:
		v.aggiungi(_ribelle(nome))
	v.lega("Capo", "Vicina")
	v.lega("Capo", "Altro")
	v.lega("Vicina", "Altro")
	var dal_primo_giorno := ["Capo", "Vicina", "Altro"]
	var sr := 0.0
	var ss := 0.0
	var salite := 0
	var discese := 0
	var scatti := []
	var focolaio_a_meta := {}
	var arrivato := ""

	# ── LA SALITA: il giocatore manda il Capo a tagliare legna, e il Capo
	#    sognava di fare il guerriero. È il torto di `test_villaggio`.
	for g in 30:
		capo.esegue("taglia_legna")
		if g == 20:
			capo.lutto("Pepe")
		_conta(v.simula_giorno(), capo.oggi, scatti, salite, discese, sr, ss)
	focolaio_a_meta = v.primo_focolaio()

	# ── LA RIPARAZIONE: nessun torto nuovo, e un gesto gentile al giorno.
	#    È la chiave a forma di giocatore, ed è l'unica sorgente di sollievo
	#    che questo villaggio abbia.
	for g in 60:
		for nome in v.animi:
			v.animi[nome].ricorda("regalo", "giocatore", 1.0, 1.0)
		var cronaca: Array = v.simula_giorno()
		_conta(cronaca, capo.oggi, scatti, salite, discese, sr, ss)
		if arrivato == "":
			for r in cronaca:
				if str(r.get("tipo", "")) == "scatto" \
						and str(r.get("a", "")) == ANIMO.SCALA[0]:
					# entra nel villaggio il giorno in cui qualcuno torna
					# sereno: sentirà solo la buona notizia
					var nuovo = _ribelle("Nuovo")
					nuovo.oggi = capo.oggi
					v.aggiungi(nuovo)
					v.lega("Capo", "Nuovo")
					arrivato = "Nuovo"
					break

	_arco = {"villaggio": v, "dal_primo_giorno": dal_primo_giorno,
			"arrivato_dopo": arrivato, "rancore": sr, "sollievo": ss,
			"salite": salite, "discese": discese, "scatti": scatti,
			"focolaio_a_meta": focolaio_a_meta, "focolaio_finale": v.primo_focolaio()}
	return _arco
