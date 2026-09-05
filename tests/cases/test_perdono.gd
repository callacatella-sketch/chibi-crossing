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
	_la_salita_non_produce_sollievo(t)
	_il_sollievo_e_un_giorno_solo(t)
	_l_ampiezza_e_il_gradino_di_partenza(t)
	_un_sereno_non_e_una_sorgente_permanente(t)
	_la_tensione_non_conta_il_sollievo(t)
	_il_sollievo_gira_come_il_rancore(t)
	_la_cronaca_dice_il_verso(t)
	_chi_ha_una_notizia_buona_tace_quella_cattiva(t)
	_il_sollievo_sopravvive_al_salvataggio(t)


func _abitante(nome: String, tratti := {}, sogno := "boscaiolo"):
	var a = ANIMO.new()
	a.setup({"name": nome, "seed": abs(hash(nome)), "sogno": sogno, "tratti": tratti})
	return a


## Porta un animo in alto sulla scala dandogli lavoro che odia, e torna
## quanti giorni ci sono voluti. È il modo in cui una rivolta nasce davvero.
func _fai_salire(a, giorni := 24) -> int:
	for g in giorni:
		a.esegue("pulisci")
		a.passa_giorno(false)
		a.aggiorna_scala()
		if a.gradino >= 3:
			return g
	return giorni


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


# ── 2. chi PEGGIORA non porta buone notizie ─────────────────────────────
func _la_salita_non_produce_sollievo(t) -> void:
	var a = _abitante("Salita")
	_fai_salire(a)
	t.ok(a.gradino > 0, "è salito sulla scala (gradino %d)" % a.gradino)
	t.eq(a.eco_serena(), 0.0,
			"chi ieri è SALITO non irradia sollievo: la buona notizia è la discesa")
	t.ok(a.eco() > 0.0, "…mentre il malcontento lo irradia eccome")


# ── 3. l'EVENTO, non il livello: una volta sola ─────────────────────────
func _il_sollievo_e_un_giorno_solo(t) -> void:
	var a = _abitante("Giorno")
	_fai_salire(a)
	var alto := a.gradino
	# lo si rimette a posto: ricordi belli finché non ridiscende
	var sceso := false
	for g in 40:
		a.ricorda("regalo", "giocatore", 1.0, 1.0)
		a.passa_giorno(true)
		if a.aggiorna_scala() and a.gradino < alto:
			sceso = true
			break
	t.ok(sceso, "una riparazione lo fa scendere di gradino")
	if not sceso:
		return
	# il giorno DOPO la discesa (la finestra è ieri, non oggi)
	a.oggi += 1
	var primo := a.eco_serena()
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
	for g in 30:
		for nome in v.animi:
			v.animi[nome].esegue("taglia_legna")
		v.simula_giorno()
	var sollievi := 0
	for r in v.cronaca:
		if str(r.get("tipo", "")) == "voce" and str(r.get("verso", "")) == "sollievo":
			sollievi += 1
	t.eq(sollievi, 0,
			"un villaggio che sta bene da sempre NON irradia sollievo: non è successo niente")
	for nome in v.animi:
		t.eq(v.animi[nome].eco_serena(), 0.0,
				"…e nessuno dei sereni è una sorgente (%s)" % nome)


# ── 6. la tensione somma solo il malcontento ────────────────────────────
func _la_tensione_non_conta_il_sollievo(t) -> void:
	var v = VILLAGGIO.new()
	var a = _abitante("Teso")
	v.aggiungi(a)
	_fai_salire(a)
	var t_prima := v.tensione()
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
	t.ok(dopo_a >= prima_a,
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
	v.simula_giorno()
	var con_verso := 0
	var senza := 0
	for r in v.cronaca:
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
	v.simula_giorno()
	var rancori := 0
	for r in v.cronaca:
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
	var atteso := a.eco_serena()
	t.ok(atteso > 0.0, "prima del salvataggio il sollievo c'è (%.3f)" % atteso)
	# il giro VERO: JSON, dove gli interi tornano float
	var salvato: Dictionary = JSON.parse_string(JSON.stringify(a.save()))
	var b = _abitante("Salvata")
	b.load(salvato)
	t.almost(b.eco_serena(), atteso,
			"…e dopo il giro da JSON è identico: il giorno rientra come float", 1e-6)
