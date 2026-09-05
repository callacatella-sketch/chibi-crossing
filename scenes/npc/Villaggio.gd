extends RefCounted

## IL VILLAGGIO: il grafo delle relazioni e il passaparola.
##
## Ogni chibi ha il suo Animo (pressioni, ricordi, carattere). Qui si guarda
## l'insieme: chi parla con chi, e cosa si dicono di te.
##
## È la parte da cui nascono le RIVOLTE COLLETTIVE che nessuno ha scritto.
## Nessuno decide «adesso si ribellano tutti»: uno solo supera la sua soglia,
## i suoi amici lo sentono dire, chi era già al limite scivola oltre, e il
## giorno dopo quelli fanno da megafono a loro volta. Con le soglie giuste
## esce una cascata; con le soglie sbagliate esce o l'apatia o l'isteria — ed
## è per questo che `simula_giorno` restituisce la CRONACA di ogni passaggio:
## bilanciarla a occhio, guardando i chibi camminare, sarebbe impossibile.
##
## Tutto puro e testabile: entra un pugno di Animi, esce cosa si sono detti.

## Quanto si smorza una voce a ogni passaggio di bocca. Sotto 1.0, o il
## pettegolezzo diventa un moto perpetuo e il villaggio esplode ogni volta.
const ANIMO := preload("res://scenes/npc/Animo.gd")
## LE DUE VALENZE del passaparola. Il rancore era CABLATO a -1.0 dentro il
## passo 2; il sollievo non esisteva, benche' `senti_dire` sia a due segni
## per costruzione e `opinione` pure — il canale c'era ed era vuoto.
##
## ⚠️ IL SOLLIEVO NON COSTA MENO DEL RANCORE, e il numero non e' scelto:
## si deriva da `Animo.SCONTO_PERDONO`, cioe' dallo stesso sconto con cui
## un ricordo bello smorza il rancore dentro una persona sola. Se il
## sollievo smorzasse di piu', la rivolta diventerebbe reversibile in un
## giorno e la scala perderebbe senso.
##
## ⚠️ E LA LEVA E' LA VALENZA, MAI LA FORZA: i due cancelli di `senti_dire`
## (0.001 per attecchire, 0.18 per lasciare un ricordo) guardano il PESO.
## Smorzando la forza il sollievo passerebbe il primo e non il secondo:
## mezzo canale, che si legge come un canale intero.
const VALENZA_RANCORE := -1.0
const VALENZA_SOLLIEVO := 1.0 / ANIMO.SCONTO_PERDONO

const SMORZAMENTO := 0.55
## Sotto questa forza la voce non vale più la pena di essere riportata.
const SOGLIA_VOCE := 0.06
## Quanti passaggi di bocca al giorno: oltre, la cascata è istantanea e il
## giocatore non ha il tempo di accorgersene e rimediare.
const PASSAGGI := 2

var animi := {}        # nome -> Animo
var amicizie := {}     # nome -> {altro_nome: 0..1}
## Chi se n'è andato: nome -> {giorno, gradino, scatti}. Un disertore smette
## di spettegolare e di pesare sulla tensione — ma la sua storia resta, o la
## cronaca non saprebbe più dire chi ha acceso la miccia.
var partiti := {}


## Aggiunge un abitante al villaggio.
func aggiungi(animo) -> void:
	animi[animo.nome] = animo
	if not amicizie.has(animo.nome):
		amicizie[animo.nome] = {}


## Lega due abitanti (l'amicizia è reciproca ma può avere pesi diversi:
## uno può tenerci più dell'altro, come nella vita).
func lega(a: String, b: String, forza := 0.7, forza_inversa := -1.0) -> void:
	if not amicizie.has(a):
		amicizie[a] = {}
	if not amicizie.has(b):
		amicizie[b] = {}
	amicizie[a][b] = clampf(forza, -1.0, 1.0)
	amicizie[b][a] = clampf(forza if forza_inversa < 0.0 else forza_inversa, -1.0, 1.0)
	# ogni Animo tiene la sua copia: è lui a decidere a chi crede
	if animi.has(a):
		animi[a].legami[b] = amicizie[a][b]
	if animi.has(b):
		animi[b].legami[a] = amicizie[b][a]


## Congeda un abitante. Da questo momento non parla più, non ascolta più e
## non pesa più sulla tensione: prima di questa funzione un disertore restava
## nel grafo come un fantasma — continuava a spettegolare contro di te e a
## tenere alta la tensione di un villaggio che aveva già lasciato.
func rimuovi(nome: String) -> void:
	if not animi.has(nome):
		return
	var a = animi[nome]
	# la storia si archivia PRIMA di cancellare: la cronaca ne avrà bisogno
	partiti[nome] = {"giorno": a.oggi, "gradino": a.stato(),
			"scatti": a.scatti.duplicate(true)}
	animi.erase(nome)
	amicizie.erase(nome)
	# e nessun arco deve più puntare a lui: un lato solo del grafo reciso
	# lascerebbe voci dirette a qualcuno che non c'è
	for altro in amicizie:
		(amicizie[altro] as Dictionary).erase(nome)
	# nota: i `legami` personali degli altri NON si toccano — il ricordo di
	# un'amicizia sopravvive alla partenza, e non fa girare nessuna voce
	# (senti_dire parte solo da chi è ancora in `animi`)


## Un giorno di villaggio: prima ognuno fa i conti con sé stesso, poi le
## voci girano. Ritorna la CRONACA — chi ha detto cosa a chi, e chi è
## scattato — perché una cascata che non si può leggere non si può bilanciare.
func simula_giorno() -> Array:
	var cronaca := []

	# 1) ognuno aggiorna la propria scala: qualcuno scatta
	for nome in animi:
		var a = animi[nome]
		if a.aggiorna_scala():
			# il "da" serve a chi mostra il toast: la battuta del gradino
			# d'arrivo, letta su una DISCESA, rimprovera chi sta guarendo
			# («Oggi no. Chiedilo a qualcun altro.» nel giorno in cui il
			# giocatore l'ha appena rimesso a posto). Un gesto di cura a
			# cui il gioco risponde con un rimbrotto non attenua la
			# ricompensa: la inverte.
			cronaca.append({"tipo": "scatto", "chi": nome,
					"da": a.scatti[a.scatti.size() - 1].get("da", "") if not a.scatti.is_empty() else "",
					"a": a.stato(), "perche": a.racconta()})

	# 2) il passaparola. Chi è sceso in basso irradia il MALCONTENTO verso i
	#    suoi amici — e da oggi chi ieri è RISALITO irradia il SOLLIEVO
	#    sulla stessa identica strada, con gli stessi passaggi, lo stesso
	#    smorzamento e la stessa soglia. Prima solo il peggioramento
	#    viaggiava: il giocatore poteva riparare con la persona ferita ma
	#    non col villaggio, e chi si era preso il malumore da lei se lo
	#    teneva. Adesso rimetti a posto le cose con chi aveva cominciato, e
	#    il giorno dopo lo vedi arrivare addosso a due dei suoi amici.
	#
	#    ⚠️ UNA NOTIZIA PER ORATORE, e chi ne ha una buona TACE quella
	#    cattiva: uno che ieri è risalito ha ancora un `eco()` alto (è
	#    sceso di un gradino, non è tornato sereno), e senza questa regola
	#    porterebbe le due notizie insieme — dicendo e disdicendo nello
	#    stesso giro, a due passanti diversi.
	for giro in PASSAGGI:
		var voci := []
		for nome in animi:
			var a = animi[nome]
			var buona: float = a.eco_serena()
			var forza: float = (buona if buona > 0.0 else a.eco()) \
					* pow(SMORZAMENTO, float(giro))
			if forza < SOGLIA_VOCE:
				continue
			var valenza: float = VALENZA_SOLLIEVO if buona > 0.0 else VALENZA_RANCORE
			for amico in amicizie.get(nome, {}):
				if not animi.has(amico):
					continue
				voci.append([nome, amico, forza, valenza])
		# si applicano tutte insieme: nessuno "sente" due volte lo stesso
		# giro solo perché il dizionario lo mette prima nell'ordine
		for v in voci:
			var da: String = v[0]
			var a_chi: String = v[1]
			var val: float = float(v[3])
			var peso: float = animi[a_chi].senti_dire(da, "giocatore", val, float(v[2]))
			if peso > 0.01:
				# ⚠️ IL TIPO RESTA "voce" e il verso è un CAMPO. Con un tipo
				# nuovo, `test_villaggio._test_niente_fantasmi` — che filtra
				# su `tipo == "voce"` — continuerebbe a passare coprendo
				# metà del canale.
				cronaca.append({"tipo": "voce", "da": da, "a": a_chi,
						"verso": ("sollievo" if val > 0.0 else "rancore"),
						"forza": snappedf(peso, 0.01)})

	# 3) chi ha sentito le voci può scattare a sua volta: è il secondo anello
	#    della catena, quello che trasforma un malcontento in una rivolta
	for nome in animi:
		var a = animi[nome]
		if a.aggiorna_scala():
			# il "da" serve a chi mostra il toast: la battuta del gradino
			# d'arrivo, letta su una DISCESA, rimprovera chi sta guarendo
			# («Oggi no. Chiedilo a qualcun altro.» nel giorno in cui il
			# giocatore l'ha appena rimesso a posto). Un gesto di cura a
			# cui il gioco risponde con un rimbrotto non attenua la
			# ricompensa: la inverte.
			cronaca.append({"tipo": "scatto", "chi": nome,
					"da": a.scatti[a.scatti.size() - 1].get("da", "") if not a.scatti.is_empty() else "",
					"a": a.stato(), "perche": a.racconta()})

	for nome in animi:
		animi[nome].passa_giorno()
	return cronaca


## Quanti abitanti sono oltre un certo gradino della scala.
## La soglia si interroga PER NOME (ANIMO.almeno): con il `.find()` a mano un
## nome sbagliato dava -1, e `gradino >= -1` è vero per tutti — la domanda
## «quanti sono oltre X?» rispondeva "tutto il villaggio" invece di zero.
func quanti_oltre(gradino: String) -> int:
	var n := 0
	for nome in animi:
		if ANIMO.almeno(int(animi[nome].gradino), gradino):
			n += 1
	return n


## Il termometro del villaggio: 0 = tutti sereni, 1 = ammutinamento generale.
func tensione() -> float:
	if animi.is_empty():
		return 0.0
	var s := 0.0
	for nome in animi:
		s += animi[nome].eco()
	return clampf(s / float(animi.size()), 0.0, 1.0)


## Chi ha acceso la miccia: il primo che è sceso in basso sulla scala.
## È la domanda che il giocatore si farà davanti a una rivolta, e deve avere
## una risposta precisa — con nome, giorno e motivo.
func primo_focolaio() -> Dictionary:
	var best := {}
	var quando := 999999
	# si guarda fra i presenti E fra i partiti: molto spesso chi ha acceso la
	# miccia è proprio quello che poi se n'è andato, e una cronaca che lo
	# dimenticasse racconterebbe una rivolta senza inizio
	var cronache := {}
	for nome in animi:
		cronache[nome] = animi[nome].scatti
	for nome in partiti:
		cronache[nome] = partiti[nome]["scatti"]
	for nome in cronache:
		for s in (cronache[nome] as Array):
			if int(s["giorno"]) < quando and str(s["a"]) != "lavoro":
				quando = int(s["giorno"])
				var c: Array = s["cause"]
				best = {"chi": nome, "giorno": quando, "gradino": str(s["a"]),
						"perche": str(c[0]["testo"]) if not c.is_empty() else "malessere"}
	return best


## Il racconto della rivolta, dall'inizio: chi ha cominciato, chi l'ha
## seguito e perché. È questa la storia che il giocatore racconterà agli
## amici — e se il sistema non sa produrla, la rivolta sembra un bug.
func cronaca_rivolta() -> Array:
	var out := []
	var focolaio := primo_focolaio()
	if focolaio.is_empty():
		return ["Il villaggio è sereno."]
	out.append("Ha cominciato %s il giorno %d (%s): %s." % [
			focolaio["chi"], focolaio["giorno"], focolaio["gradino"], focolaio["perche"]])
	var seguaci := []
	for nome in animi:
		if nome == focolaio["chi"]:
			continue
		var a = animi[nome]
		if a.gradino > 0:
			seguaci.append("%s (%s)" % [nome, a.stato()])
	for nome in partiti:
		if nome != focolaio.get("chi", ""):
			seguaci.append("%s (se n'è andato)" % nome)
	if not seguaci.is_empty():
		out.append("Poi si sono uniti: %s." % ", ".join(seguaci))
	out.append("Tensione del villaggio: %d%%." % int(tensione() * 100.0))
	return out
