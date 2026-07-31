extends RefCounted

## COM'È MESSO IL VILLAGGIO, in poche righe — e SOPRATTUTTO come sta.
##
## Il menù principale non carica la partita: sarebbe assurdo (mezzo minuto
## di mondo procedurale per mostrare un pulsante). Legge `village.json` e
## se ne fa un ritratto: quanti giorni, che stagione, chi ci abita, quanti
## momenti avete accumulato, se c'è un lutto, se qualcuno sta per partire.
##
## E da quel ritratto ricava la cosa che conta davvero: il CLIMA.
##
## Un menù principale che è sempre la stessa cartolina dice al giocatore
## che quello che ha vissuto sta di là, in un altro posto. Se invece la
## sera in cui è morto qualcuno il menù è grigio e i vicini stanno seduti
## in silenzio sotto l'albero — senza una scritta, senza una notifica —
## allora il gioco si ricorda, e il giocatore lo sente prima ancora di
## premere Continua.
##
## Tutto puro: entra un Dictionary (il JSON già letto), esce il ritratto.
## Nessun file, nessun nodo — così si prova headless con villaggi finti
## (tests/cases/test_menu_vivo.gd).

const ALBERO := preload("res://scenes/world/AlberoGeo.gd")

## Quanti giorni dura una stagione (deve combaciare con DayNight).
const GIORNI_STAGIONE := 28
const GIORNI_ANNO := GIORNI_STAGIONE * 4

## Entro quanti giorni dall'inizio un lutto pesa ancora sul menù. Dopo,
## il villaggio non ha dimenticato — ha ricominciato a respirare, che è
## un'altra cosa (e il fiore del ricordo resta nel gioco).
const LUTTO_GIORNI := 6
## Quanti momenti sul Filo Rosso fanno di un villaggio un villaggio in
## ARMONIA: non «tanti amici», tanta STORIA insieme.
const MOMENTI_ARMONIA := 40
## Sotto tanti giorni si è ancora agli inizi: il clima è l'attesa.
const GIORNI_ATTESA := 3

var giorno := 1
var stagione := 0
var residenti: Array = []      # [{dna, label, amicizia}]
var momenti := 0               # i nodi del Filo Rosso, tutti insieme
var amici_stretti := 0         # chi ha almeno tre cuoricini
var lutto := {}                # {nome, giorno_inizio} se c'è
var congedo := {}              # chi sta vivendo la settimana delle ultime cose
var partiti: Array = []        # chi è al Grande Prato
var umore_mochi := 0.0         # -1..1, dal suo Limbico
var paura_temporale := 0.0     # 0..1, il marchio del Prologo


## Il ritratto di un salvataggio. `{}` (o un file rotto) dà un villaggio
## al giorno uno: il menù di chi non ha ancora giocato.
static func da_salvataggio(dati: Dictionary) -> RefCounted:
	var r = new()
	r.giorno = maxi(1, int(dati.get("day", 1)))
	r.stagione = int(floor(float((r.giorno - 1) % GIORNI_ANNO)
			/ float(GIORNI_STAGIONE))) % 4

	var fili_grezzi: Variant = dati.get("legami", {})
	var per_nome: Dictionary = fili_grezzi if fili_grezzi is Dictionary else {}
	for riga in (dati.get("residents", []) as Array):
		if riga is not Dictionary:
			continue
		var dna: Variant = riga.get("dna", {})
		if dna is not Dictionary or (dna as Dictionary).is_empty():
			continue
		var amicizia := int(riga.get("friend", 0))
		r.residenti.append({"dna": dna, "label": str(riga.get("label", "")),
				"amicizia": amicizia,
				# gli anni: il filo li tiene già, e nel diorama diventano
				# gobba, orecchie basse, passo posato — gli stessi canali
				# del villaggio. Un anziano che nel menù saltella sarebbe
				# un altro personaggio.
				"eta": _eta_dal_filo(per_nome.get(str((dna as Dictionary).get("name", "")), {}))})
		if amicizia >= 3:
			r.amici_stretti += 1

	var fili: Variant = dati.get("legami", {})
	if fili is Dictionary:
		for nome in fili:
			var filo: Variant = fili[nome]
			if filo is not Dictionary:
				continue
			var f: Dictionary = filo
			# `n` è il conto VISSUTO (il filo ne conserva solo gli ultimi):
			# è quello giusto per dire quanta storia c'è stata
			r.momenti += maxi(int(f.get("n", 0)), (f.get("momenti", []) as Array).size())
			# chi non c'è più: partito per il Grande Prato o andato via da
			# sé. Il filo resta comunque — è quello il punto del Filo Rosso
			if bool(f.get("partito", false)) or bool(f.get("andato_via", false)):
				r.partiti.append(str(f.get("label", nome)))

	var l: Variant = dati.get("lutto", {})
	if l is Dictionary and not (l as Dictionary).is_empty():
		r.lutto = l
	var c: Variant = dati.get("congedo", {})
	if c is Dictionary and not (c as Dictionary).is_empty():
		r.congedo = c
	var cuore: Variant = dati.get("cuore_mochi", {})
	if cuore is Dictionary:
		r.umore_mochi = clampf(float((cuore as Dictionary).get("umore", 0.0)), -1.0, 1.0)
		var marchi: Variant = (cuore as Dictionary).get("marchi", {})
		if marchi is Dictionary and (marchi as Dictionary).has("luogo|temporale"):
			r.paura_temporale = absf(float(
					((marchi as Dictionary)["luogo|temporale"] as Dictionary).get("carica", 0.0)))
	return r


## Quanto è avanti nella vita, 0..1, dal gradino che il Filo Rosso gli ha
## già scritto addosso (`s`: giovane / adulto / anziano). Si legge quello
## e non si ricontano i giorni: il conto è affare di Legami, e due conti
## per la stessa cosa divergono sempre.
static func _eta_dal_filo(filo: Variant) -> float:
	if filo is not Dictionary:
		return 0.0
	match str((filo as Dictionary).get("s", "giovane")):
		"anziano":
			return 1.0
		"adulto":
			return 0.35
		_:
			return 0.0


## Il ritratto letto dal disco. Torna il villaggio-al-giorno-uno se il
## file non c'è o è rotto: il menù non deve MAI rompersi per colpa di un
## salvataggio (è l'unica schermata da cui si può ancora rimediare).
static func dal_disco(percorso := "user://village.json") -> RefCounted:
	if not FileAccess.file_exists(percorso):
		return da_salvataggio({})
	var f := FileAccess.open(percorso, FileAccess.READ)
	if f == null:
		return da_salvataggio({})
	var dati: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	return da_salvataggio(dati if dati is Dictionary else {})


# ============================================================== il clima

## IL CLIMA EMOTIVO. Uno solo, quello che pesa di più adesso.
##
## L'ordine NON è arbitrario: è una scala di priorità del dolore e della
## gioia, e mette il lutto sopra tutto. Un villaggio può essere pieno di
## amici e di storia e avere comunque perso qualcuno ieri — e quel giorno
## il menù deve essere grigio, per quanti fiori ci siano in giro. Il
## contrario (un lutto coperto dall'allegria della statistica) sarebbe la
## cosa più fredda che questo gioco potrebbe fare.
##
##   "lutto"       qualcuno se n'è andato, ed è appena successo
##   "commiato"    qualcuno sta vivendo la sua ultima settimana
##   "malinconia"  c'è un vuoto: qualcuno è partito, o Mochi sta giù
##   "armonia"     tanta storia insieme, e tanti amici: il villaggio pieno
##   "allegria"    un villaggio vivo e in salute
##   "serena"      va tutto bene, senza niente di speciale
##   "attesa"      i primi giorni: il prato è vuoto e aspetta
func clima() -> String:
	if _lutto_fresco():
		return "lutto"
	if not congedo.is_empty():
		return "commiato"
	if umore_mochi < -0.30 or (not partiti.is_empty() and residenti.is_empty()):
		return "malinconia"
	if giorno <= GIORNI_ATTESA and residenti.size() <= 1:
		return "attesa"
	if momenti >= MOMENTI_ARMONIA and amici_stretti >= 3:
		return "armonia"
	if residenti.size() >= 3 and (amici_stretti >= 1 or momenti >= 12):
		return "allegria"
	return "serena"


func _lutto_fresco() -> bool:
	if lutto.is_empty():
		return false
	var da := int(lutto.get("giorno_inizio", giorno))
	return giorno - da <= LUTTO_GIORNI


## Quanto è «acceso» il villaggio, 0..1: quanti vicini si muovono, quanto
## corrono, quanti petali cadono. Il lutto lo spegne quasi del tutto.
func vivacita() -> float:
	match clima():
		"lutto":
			return 0.0
		"commiato":
			return 0.25
		"malinconia":
			return 0.35
		"attesa":
			return 0.45
		"serena":
			return 0.68
		"allegria":
			return 0.88
		_:
			return 1.0


## La taglia del Grande Albero di QUESTO salvataggio (fonte unica: la
## stessa formula del villaggio).
func stage_albero() -> float:
	return ALBERO.stage_per_giorno(giorno)


## La frase sotto il titolo. Cambia col clima: è l'unica cosa che il menù
## DICE, e dice pochissimo — il resto lo fa vedere.
func sottotitolo() -> String:
	match clima():
		"lutto":
			return "Il villaggio è più silenzioso, in questi giorni."
		"commiato":
			return "Qualcuno sta salutando il mondo, sotto il Grande Albero."
		"malinconia":
			return "Il Grande Albero ti aspetta. C'è un posto vuoto, all'ombra."
		"attesa":
			return "Un villaggio ti aspetta sotto il Grande Albero."
		"armonia":
			return "Sono tutti qui, sotto il Grande Albero. Ti stavano aspettando."
		"allegria":
			return "Sotto il Grande Albero non si sta mai fermi."
		_:
			return "Il Grande Albero ti aspetta, e i tuoi vicini anche."
