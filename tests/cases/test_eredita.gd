extends RefCounted
## LA TRASMISSIONE — la prova che un cucciolo si porta via dai suoi UN posto,
## e che se lo porta via **una volta sola**.
##
## ============================================================
## COSA CERCA DI ROMPERE, QUESTO FILE
## ============================================================
## Il modo in cui questa meccanica può fallire non è «non funziona»: sono
## quattro, e tre su quattro sono invisibili in partita.
##
## 1. **LO SPECCHIO INVECE DELLA MEMORIA.** Se il posto si riscrivesse ogni
##    giorno, i genitori resterebbero una sorgente permanente e il figlio un
##    riflesso — e in partita non si distinguerebbe da un'eredità vera finché
##    i suoi non traslocano. È la mutazione designata di questo file
##    (`_si_impara_UNA_volta_sola`).
## 2. **IL `Vector3` NEL SALVATAGGIO.** Funziona per tutta la sessione in cui
##    nasce e sparisce al primo riavvio — e chi la prova la prova sempre nella
##    prima sessione (`_sopravvive_al_JSON`, `_gli_assi_non_si_invertono`).
## 3. **IL FILO FANTASMA.** Un `_filo()` al posto di un `_fili.has()` fabbrica
##    un filo per ogni nome sconosciuto, che poi invecchia e finisce nel
##    salvataggio (`_non_si_creano_fili_fantasma`, con la controprova sul
##    `Legami` VERO).
## 4. **LA PAROLA.** Un toast, un momento sul filo, una lettera: basta uno e
##    l'unica conseguenza invisibile di questa meccanica diventa un annuncio
##    (`_niente_testo_e_niente_momento`).
##
## ============================================================
## QUI DENTRO NON C'È NESSUN DOPPIO CHE DECIDE
## ============================================================
## I ritrovi si fabbricano passando dalla PORTA VERA di `Cricche`
## (`registra` + `ritrovo_vivo`), i fili da un `Legami` VERO messo in scena, e
## la persistenza si prova dalla strada vera (`save_extra` → JSON →
## `migra_fili`, che è quella di `load_extra`). Di finto c'è **solo
## l'orologio**, che è un dato e non una decisione — l'idioma di
## `test_deriva`.
##
## ⚠️ E l'adattatore di `Legami` (`_impara`, `_posto`, `_puo`) chiama il
## metodo VERO appena esiste: finché il cablaggio non è atterrato usa il
## proprio testo — che è, riga per riga, quello consegnato al proprietario di
## `Legami.gd`. Il giorno che atterra, questo file lo sorveglia senza che
## nessuno tocchi una virgola.
##
## ============================================================
## ⚠️ COSA QUESTO FILE **NON** DICE, dichiarato
## ============================================================
## 1. **DUE GUARDIE DI TIPO SI VEDONO SOLO NEL CONTO DEGLI `SCRIPT ERROR`,
##    NON IN QUELLO DELLE ASSERZIONI.** Sono `riga is not Array` in
##    `posto_sul_filo` e `d is not Vector3` in `posto_dal_ritrovo`.
##    MISURATO, togliendole una per volta: **118 verdi, 0 rossi** tutte e due
##    le volte, con **4** e **1** `SCRIPT ERROR`. La ragione è che un errore
##    di assegnazione tipizzata interrompe la funzione CHIAMATA e le fa
##    tornare `null` — cioè, per chi asserisce, esattamente il valore giusto.
##    Restano falsificabili nella forma *plausibile e silenziosa* («degrada a
##    `Vector3.ZERO` invece che a `null`»), che è rossa; e restano
##    intercettate dal criterio d'accettazione del progetto, che pretende zero
##    `SCRIPT ERROR` oltre a zero rossi. **Chi le tocca conti gli errori, non
##    solo i rossi.**
## 2. **IL CABLAGGIO IN `Visitors.gd` NON È SORVEGLIATO DA QUI.** Il quinto
##    anello di `_panchina_per`, `_ancora_dei_suoi` e il giro giornaliero
##    vivono in un file che questa consegna non possiede: i due casi che li
##    provano (`_l_ancora_non_allunga_il_guinzaglio` e
##    `_l_ordine_dei_CINQUE_anelli`) sono già scritti e consegnati al
##    proprietario di `Visitors.gd`, e atterrano **nello stesso commit del
##    cablaggio** — che è la regola del passaggio di consegna. Finché non
##    atterrano, di questa meccanica è provata la REGOLA e non il suo
##    ESECUTORE, ed è bene saperlo invece di leggere il verde come «finita».

const EREDITA := preload("res://scenes/npc/Eredita.gd")
const CRICCHE := preload("res://scenes/npc/Cricche.gd")
const LEGAMI := preload("res://scenes/world/Legami.gd")


func run(t) -> void:
	_il_posto_e_di_CHI_lo_ha_cresciuto(t)
	_l_ordine_dei_GENITORI_non_conta(t)
	_si_impara_solo_da_cuccioli(t)
	_si_impara_UNA_volta_sola(t)
	_senza_ritrovo_non_si_impara_niente(t)
	_l_ancora_si_accende_al_compimento(t)
	_le_due_finestre_non_si_sovrappongono(t)
	_il_posto_non_e_una_persona(t)
	_sopravvive_al_JSON(t)
	_gli_assi_non_si_invertono(t)
	_non_si_creano_fili_fantasma(t)
	_niente_testo_e_niente_momento(t)
	_il_degrado_va_verso_ieri(t)
	_la_catena_intera(t)


# ============================================================ gli attrezzi

## Il giorno del villaggio si DÀ, come si dà il cielo.
## ⚠️ Dev'essere un `Node3D`: `Legami._daynight` è tipizzato, e un `set()` col
## tipo sbagliato **non assegna e non dice niente** (lezione di `test_deriva`).
class Orologio extends Node3D:
	var day := 1


## Il Filo Rosso VERO, col solo `_ready` scavalcato: l'originale cerca il
## cielo nell'albero con un `call_deferred`, che qui non troverebbe niente e
## lascerebbe `_day()` inchiodato a 1 — cioè nessuno crescerebbe mai.
class FiloVero extends "res://scenes/world/Legami.gd":
	func _ready() -> void:
		var o := Orologio.new()
		add_child(o)
		_daynight = o

	func giorno(g: int) -> void:
		_daynight.set("day", g)


func _filo_vero(t):
	return t.stage(FiloVero.new())


## Un ritrovo VERO, costruito dalle porte vere di `Cricche`: tre giornate
## diverse, stessa ora, stesso punto. Torna il referto `{giorni, dove, ora,
## ultimo}` — o `{}`, che è quello che si vuole quando le giornate non
## bastano.
static func _ritrovo(a: String, b: String, giorni: Array, ora: float,
		dove: Vector3, oggi: int) -> Dictionary:
	var inc: Array = []
	for g in giorni:
		CRICCHE.registra(inc, a, b, int(g), ora, dove)
	return CRICCHE.ritrovo_vivo(inc, a, b, oggi)


## Tre giornate consecutive che finiscono oggi: il minimo per un'abitudine
## (`Cricche.GIORNATE_RITROVO`), letto di là e mai riscritto.
static func _giornate(oggi: int) -> Array:
	var out: Array = []
	for i in range(CRICCHE.GIORNATE_RITROVO):
		out.append(oggi - (CRICCHE.GIORNATE_RITROVO - 1) + i)
	return out


# --- l'adattatore di `Legami`: il metodo VERO se c'è, altrimenti il testo
#     esatto della richiesta d'innesto (vedi la testata).

static func _puo(lg, nome: String) -> bool:
	if lg.has_method("puo_imparare_il_posto"):
		return bool(lg.call("puo_imparare_il_posto", nome))
	var chiave: String = lg.nome_da_chiave(nome)
	var fili: Dictionary = lg.get("_fili")
	if not fili.has(chiave):
		return false
	return EREDITA.puo_imparare(fili[chiave], float(lg.crescita(chiave)))


static func _impara(lg, nome: String, dove: Vector3) -> bool:
	if lg.has_method("impara_il_posto"):
		return bool(lg.call("impara_il_posto", nome, dove))
	var chiave: String = lg.nome_da_chiave(nome)
	var fili: Dictionary = lg.get("_fili")
	if not fili.has(chiave):   # ⚠️ mai `_filo()`: creerebbe un fantasma
		return false
	return EREDITA.incidi(fili[chiave], float(lg.crescita(chiave)), dove)


static func _posto(lg, nome: String):
	if lg.has_method("posto_dei_suoi"):
		return lg.call("posto_dei_suoi", nome)
	var chiave: String = lg.nome_da_chiave(nome)
	var fili: Dictionary = lg.get("_fili")
	if not fili.has(chiave):
		return null
	return EREDITA.posto_ereditato(fili[chiave], float(lg.crescita(chiave)))


## Il giro di una giornata, come lo farà `Visitors._impara_il_posto_dei_suoi`:
## per ogni cucciolo che può imparare si chiede il ritrovo dei suoi e, se c'è,
## si incide. Torna quanti hanno imparato oggi.
static func _giornata(lg, cuccioli: Array, ritrovi: Dictionary) -> int:
	var n := 0
	for nome in cuccioli:
		var chiave: String = lg.nome_da_chiave(str(nome))
		var fili: Dictionary = lg.get("_fili")
		if not fili.has(chiave):
			continue
		var rit: Dictionary = ritrovi.get(chiave, {})
		var dove: Variant = EREDITA.da_imparare(
				fili[chiave], float(lg.crescita(chiave)), rit)
		if dove == null:
			continue
		if _impara(lg, str(nome), dove as Vector3):
			n += 1
	return n


# ============================================================ i casi

## ⚠️ **IL POSTO È DI CHI LO HA CRESCIUTO, e le due negative valgono quanto
## le due positive.**
##
## Due cuccioli, due coppie di genitori, due angoli del villaggio distanti
## più di `Cricche.POSTO_LARGO` (che è la misura, letta di là, di «lo stesso
## posto»). Se l'eredità prendesse il ritrovo sbagliato — o, peggio, il primo
## ritrovo vivo che trova nel villaggio — le due positive resterebbero verdi
## per metà e nessuno se ne accorgerebbe: sono le negative a dire che i due
## punti si distinguono davvero.
func _il_posto_e_di_CHI_lo_ha_cresciuto(t) -> void:
	var lg = _filo_vero(t)
	var oggi := 20
	lg.giorno(oggi)
	lg.nascita("Pepita", "Nocciola", "Malva")
	lg.nascita("Timo", "Cannella", "Prugna")

	var angolo_a := Vector3(-9.0, 0.0, 4.0)
	var angolo_b := Vector3(11.0, 0.0, -6.0)
	t.ok(angolo_a.distance_to(angolo_b) > CRICCHE.POSTO_LARGO,
			"i due angoli sono davvero due posti diversi (%.2f m > %.2f)"
					% [angolo_a.distance_to(angolo_b), CRICCHE.POSTO_LARGO])

	var ritrovi := {
		"Pepita": _ritrovo("Nocciola", "Malva", _giornate(oggi), 0.62,
				angolo_a, oggi),
		"Timo": _ritrovo("Cannella", "Prugna", _giornate(oggi), 0.71,
				angolo_b, oggi),
	}
	t.eq(_giornata(lg, ["Pepita", "Timo"], ritrovi), 2,
			"i due cuccioli imparano, ognuno dai suoi")

	# e da grandi
	lg.giorno(oggi + LEGAMI.GIORNI_ADULTO)
	var pa = _posto(lg, "Pepita")
	var ti = _posto(lg, "Timo")
	t.ok(pa != null and ti != null, "tutti e due hanno un posto")
	if pa == null or ti == null:
		return
	var vp: Vector3 = pa
	var vt: Vector3 = ti
	t.ok(vp.distance_to(angolo_a) <= CRICCHE.POSTO_LARGO,
			"Pepita si siede dove stavano i SUOI (%.2f m)"
					% vp.distance_to(angolo_a))
	t.ok(vt.distance_to(angolo_b) <= CRICCHE.POSTO_LARGO,
			"Timo si siede dove stavano i SUOI (%.2f m)"
					% vt.distance_to(angolo_b))
	t.ok(vp.distance_to(angolo_b) > CRICCHE.POSTO_LARGO,
			"…e Pepita NON nell'angolo dei genitori di Timo (%.2f m)"
					% vp.distance_to(angolo_b))
	t.ok(vt.distance_to(angolo_a) > CRICCHE.POSTO_LARGO,
			"…né Timo in quello dei genitori di Pepita (%.2f m)"
					% vt.distance_to(angolo_a))


## ⚠️ **L'ORDINE DEI DUE GENITORI NON CONTA**, ed è l'assunzione su cui poggia
## tutto il cablaggio: chi impara chiede `Cricche.ritrovo_di(padre, madre)` coi
## due nomi **nell'ordine in cui `Legami.genitori_di` li restituisce** — cioè
## quello della nascita (`filo["padre"]`, `filo["madre"]`), che con l'alfabeto
## non c'entra niente.
##
## Se il registro avesse un verso, metà dei cuccioli del villaggio non
## imparerebbe niente — quelli il cui padre viene dopo la madre nell'alfabeto —
## e sarebbe invisibile: nessun errore, nessuna riga di log, solo un canale che
## funziona per la metà delle famiglie. Il cancello non è nostro (`Cricche`
## ordina i due nomi in `registra` e in `campioni`), ma la dipendenza sì: se un
## giorno di là si smette di normalizzare, questo caso lo dice qui invece che a
## una misura in partita.
func _l_ordine_dei_GENITORI_non_conta(t) -> void:
	var oggi := 20
	var dove := Vector3(-9.0, 0.0, 4.0)
	# «Nocciola» viene DOPO «Malva»: è il caso che si romperebbe
	t.ok("Nocciola" > "Malva", "i due nomi sono in ordine non alfabetico")
	var dritto := _ritrovo("Nocciola", "Malva", _giornate(oggi), 0.62, dove, oggi)
	var rovescio := _ritrovo("Malva", "Nocciola", _giornate(oggi), 0.62, dove, oggi)
	t.ok(not dritto.is_empty(), "il ritrovo c'è, coi nomi come li dà la nascita")
	t.ok(not rovescio.is_empty(), "…e c'è anche scambiandoli")

	var a: Variant = EREDITA.posto_dal_ritrovo(dritto)
	var b: Variant = EREDITA.posto_dal_ritrovo(rovescio)
	t.ok(a != null and b != null, "e tutti e due danno un punto")
	if a != null and b != null:
		t.ok((a as Vector3).is_equal_approx(b as Vector3),
				"…lo STESSO punto (%s / %s)" % [str(a), str(b)])

	# e la controprova sul cablaggio: un cucciolo impara passando i genitori
	# nell'ordine di `genitori_di`, qualunque esso sia
	var lg = _filo_vero(t)
	lg.giorno(oggi)
	lg.nascita("Pepita", "Nocciola", "Malva")
	var suoi: Array = lg.genitori_di("Pepita")
	t.eq(suoi, ["Nocciola", "Malva"],
			"`genitori_di` li dà nell'ordine della nascita, non alfabetico")
	var rit := _ritrovo(str(suoi[0]), str(suoi[1]), _giornate(oggi), 0.62,
			dove, oggi)
	t.eq(_giornata(lg, ["Pepita"], {"Pepita": rit}), 1,
			"…e con quell'ordine si impara lo stesso")


## SI IMPARA SOLO DA CUCCIOLI, e non è prudenza: un adulto che raccogliesse
## adesso l'angolo dei suoi non starebbe ricordando l'infanzia — starebbe
## imitando due persone che vede oggi, che è un'altra frase.
##
## E chi è arrivato col trolley non impara niente MAI: non è nato qui, non ha
## genitori sul filo, e la prima riga di `puo_imparare` lo dice.
func _si_impara_solo_da_cuccioli(t) -> void:
	var cucciolo := {"nato": true, "momenti": []}
	t.ok(EREDITA.puo_imparare(cucciolo, 0.0), "appena nato: può imparare")
	t.ok(EREDITA.puo_imparare(cucciolo, 0.5), "a metà strada: può imparare")
	t.ok(EREDITA.puo_imparare(cucciolo, 0.999), "il giorno prima: può ancora")
	t.ok(not EREDITA.puo_imparare(cucciolo, 1.0),
			"il giorno del compimento la finestra è chiusa")
	t.ok(not EREDITA.puo_imparare(cucciolo, 1.0 + 1.0),
			"e da lì in poi non si riapre")

	var rit := _ritrovo("Nocciola", "Malva", _giornate(30), 0.62,
			Vector3(3, 0, 3), 30)
	t.ok(not rit.is_empty(), "il ritrovo dei genitori c'è (controprova)")
	t.ok(EREDITA.da_imparare(cucciolo, 0.5, rit) != null,
			"da cucciolo, con un ritrovo vivo, si impara")
	t.ok(EREDITA.da_imparare(cucciolo, 1.0, rit) == null,
			"da adulto, con lo STESSO ritrovo vivo, non si impara più")

	var arrivato := {"momenti": []}   # nessun `nato`: è venuto dal bosco
	t.ok(not EREDITA.puo_imparare(arrivato, 0.0),
			"chi non è nato qui non impara, nemmeno a crescita zero")
	t.ok(EREDITA.da_imparare(arrivato, 0.0, rit) == null,
			"…e nemmeno con un ritrovo vivo davanti")
	t.ok(not arrivato.has(EREDITA.CHIAVE_POSTO),
			"e il suo filo non è stato toccato")


## ⚠️ **LA MUTAZIONE DESIGNATA DI QUESTO FILE.**
##
## Togliere da `Eredita.puo_imparare` la riga «ce l'ha già» è lo SPECCHIO
## invece della MEMORIA: il posto si riscriverebbe ogni giorno, i genitori
## tornerebbero una sorgente permanente e il figlio un riflesso. In partita
## non si distinguerebbe da un'eredità vera finché i suoi non traslocano —
## cioè per settimane.
func _si_impara_UNA_volta_sola(t) -> void:
	var lg = _filo_vero(t)
	lg.giorno(20)
	lg.nascita("Pepita", "Nocciola", "Malva")

	var primo := Vector3(-9.0, 0.0, 4.0)
	var poi := Vector3(11.0, 0.0, -6.0)
	t.ok(_impara(lg, "Pepita", primo), "la prima volta si incide")
	t.ok(not _puo(lg, "Pepita"),
			"e da quel momento non si può più imparare, pur essendo cucciolo")
	t.ok(not _impara(lg, "Pepita", poi), "un secondo posto viene rifiutato")

	lg.giorno(20 + LEGAMI.GIORNI_ADULTO)
	var v = _posto(lg, "Pepita")
	t.ok(v != null, "il posto c'è")
	if v != null:
		t.ok((v as Vector3).is_equal_approx(primo),
				"ed è il PRIMO, non l'ultimo (%s)" % str(v))

	# e la finestra non si riapre nemmeno saltando l'adattatore: la regola sta
	# in `Eredita`, non nel suo chiamante
	var fili: Dictionary = lg.get("_fili")
	t.ok(not EREDITA.incidi(fili["Pepita"], 0.5, poi),
			"nemmeno chiamando `incidi` a mano, da cucciolo")
	t.ok(EREDITA.da_imparare(fili["Pepita"], 0.5,
			_ritrovo("Nocciola", "Malva", _giornate(20), 0.5, poi, 20)) == null,
			"…e `da_imparare` tace anche con un ritrovo nuovo e vivo")


## SENZA RITROVO NON SI IMPARA NIENTE — e il filo non viene toccato di un bit,
## così domani si può ancora imparare. `null` vuol dire «oggi no», mai «mai
## più».
##
## ⚠️ La metà che manca qui è di chi cabla: senza posto, `_ancora_dei_suoi`
## deve tornare `home` **esatto**, e la cascata delle sedute non cambia una
## virgola di quello che il villaggio faceva prima.
func _senza_ritrovo_non_si_impara_niente(t) -> void:
	var lg = _filo_vero(t)
	var oggi := 20
	lg.giorno(oggi)
	lg.nascita("Pepita", "Nocciola", "Malva")

	# i suoi non si sono ritrovati: nessuna riga nel registro
	t.eq(_giornata(lg, ["Pepita"], {"Pepita": {}}), 0, "non impara niente")
	var fili: Dictionary = lg.get("_fili")
	t.ok(not (fili["Pepita"] as Dictionary).has(EREDITA.CHIAVE_POSTO),
			"e sul filo non compare nessuna chiave a metà")
	t.ok(_puo(lg, "Pepita"), "domani si può ancora imparare")

	# e due sole giornate insieme non sono un'abitudine: il cancello è di
	# `Cricche`, e questa meccanica non lo aggira
	var poche := _ritrovo("Nocciola", "Malva",
			[oggi - 1, oggi], 0.62, Vector3(3, 0, 3), oggi)
	t.ok(poche.is_empty(),
			"due giornate non fanno un ritrovo (il cancello è di Cricche)")
	t.eq(_giornata(lg, ["Pepita"], {"Pepita": poche}), 0,
			"…quindi non si impara da due pomeriggi")

	# da grande, senza aver imparato, è bit-identico a chi non è mai nato qui
	lg.giorno(oggi + LEGAMI.GIORNI_ADULTO)
	t.ok(_posto(lg, "Pepita") == null,
			"chi non ha imparato niente non ha nessuna ancora")
	t.ok(_posto(lg, "Sconosciuto") == null,
			"…esattamente come chi non ha nemmeno un filo")


## L'ANCORA SI ACCENDE AL COMPIMENTO, non prima. Un cucciolo che si sedesse
## nel posto dei suoi mentre ancora li ha davanti agli occhi non racconterebbe
## niente: è quando quel gesto sopravvive alle persone che diventa
## un'eredità.
func _l_ancora_si_accende_al_compimento(t) -> void:
	var filo := {"nato": true, "momenti": []}
	var dove := Vector3(-9.0, 0.0, 4.0)
	t.ok(EREDITA.incidi(filo, 0.2, dove), "impara da piccolo")

	t.ok(EREDITA.posto_ereditato(filo, 0.2) == null, "a un quinto: muta")
	t.ok(EREDITA.posto_ereditato(filo, 0.9) == null, "a nove decimi: muta")
	t.ok(EREDITA.posto_ereditato(filo, 0.999) == null,
			"il giorno prima del compimento: ancora muta")
	var v = EREDITA.posto_ereditato(filo, 1.0)
	t.ok(v != null and (v as Vector3).is_equal_approx(dove),
			"al compimento l'ancora si accende, e sul punto giusto")

	# e il posto sul filo c'era da sempre: a essere chiusa era la porta, non
	# la memoria — se fosse il contrario, il compimento dovrebbe andare a
	# ripescare un ritrovo che potrebbe non esserci più
	t.ok(EREDITA.posto_sul_filo(filo) != null,
			"il posto era inciso da quando l'ha imparato")

	# la soglia si legge dal gioco, non si riscrive: chi alza `GIORNI_ADULTO`
	# sposta le due finestre insieme, e questo caso continua a valere
	var lg = _filo_vero(t)
	lg.giorno(50)
	lg.nascita("Pepita", "Nocciola", "Malva")
	t.ok(_impara(lg, "Pepita", dove), "…e lo stesso col Filo Rosso vero")
	lg.giorno(50 + LEGAMI.GIORNI_ADULTO - 1)
	t.ok(_posto(lg, "Pepita") == null,
			"a un giorno dal compimento l'ancora è ancora spenta")
	lg.giorno(50 + LEGAMI.GIORNI_ADULTO)
	t.ok(_posto(lg, "Pepita") != null, "e il giorno dopo si accende")


## LE DUE FINESTRE NON SI SOVRAPPONGONO MAI: non esiste un istante in cui uno
## possa imparare *e* avere l'ancora accesa. Se si sovrapponessero, un adulto
## potrebbe cambiare posto mentre ci sta già seduto — cioè lo specchio dalla
## porta di servizio, con `puo_imparare` intatta.
func _le_due_finestre_non_si_sovrappongono(t) -> void:
	var sovrapposti := 0
	var visto_imparare := 0
	var visto_ancora := 0
	for i in range(0, 101):
		var c := float(i) / 100.0
		var filo := {"nato": true, "momenti": []}
		if EREDITA.puo_imparare(filo, c):
			visto_imparare += 1
		# lo stesso filo, ma che ha già imparato: è l'unico che può avere
		# un'ancora
		var inciso := {"nato": true, "momenti": []}
		EREDITA.incidi(inciso, 0.0, Vector3(1, 0, 2))
		var puo := EREDITA.puo_imparare(inciso, c)
		var ha := EREDITA.posto_ereditato(inciso, c) != null
		if ha:
			visto_ancora += 1
		if puo and ha:
			sovrapposti += 1
	t.eq(sovrapposti, 0, "nessun istante in cui si impara e si è già seduti")
	t.ok(visto_imparare > 0 and visto_imparare < 101,
			"la finestra dell'apprendimento esiste e finisce (%d/101)"
					% visto_imparare)
	t.ok(visto_ancora > 0 and visto_ancora < 101,
			"e quella dell'ancora comincia e non copre tutto (%d/101)"
					% visto_ancora)


## ⚠️ **IL POSTO NON È UNA PERSONA.** I genitori possono cambiare angolo,
## smettere di ritrovarsi, partire col fagotto: l'ancora del figlio non si
## muove di un millimetro. È la differenza fra un'eredità e un guinzaglio a
## due estremità.
func _il_posto_non_e_una_persona(t) -> void:
	var lg = _filo_vero(t)
	var oggi := 20
	lg.giorno(oggi)
	lg.nascita("Pepita", "Nocciola", "Malva")

	var da_piccola := Vector3(-9.0, 0.0, 4.0)
	var rit := _ritrovo("Nocciola", "Malva", _giornate(oggi), 0.62,
			da_piccola, oggi)
	t.eq(_giornata(lg, ["Pepita"], {"Pepita": rit}), 1, "impara l'angolo dei suoi")

	# --- i suoi TRASLOCANO: un ritrovo nuovo, vivo, in tutt'altro posto
	var dopo := oggi + 30
	lg.giorno(dopo)
	var altrove := Vector3(11.0, 0.0, -6.0)
	var rit2 := _ritrovo("Nocciola", "Malva", _giornate(dopo), 0.30,
			altrove, dopo)
	t.ok(not rit2.is_empty(), "il ritrovo NUOVO è vivo (controprova)")
	t.eq(_giornata(lg, ["Pepita"], {"Pepita": rit2}), 0,
			"e non riscrive niente")

	# --- e poi PARTONO: il registro non ha più nessuna riga per quei due
	t.ok(_ritrovo("Nocciola", "Malva", [], 0.0, Vector3.ZERO, dopo).is_empty(),
			"senza righe non c'è più nessun ritrovo (controprova)")
	t.eq(_giornata(lg, ["Pepita"], {"Pepita": {}}), 0,
			"e nemmeno la loro assenza tocca il filo")

	lg.giorno(dopo + LEGAMI.GIORNI_ADULTO)
	var v = _posto(lg, "Pepita")
	t.ok(v != null, "l'ancora c'è ancora")
	if v != null:
		t.ok((v as Vector3).is_equal_approx(da_piccola),
				"…ed è dov'era quando lei era piccola (%s)" % str(v))
		t.ok(not (v as Vector3).is_equal_approx(altrove),
				"…non dove i suoi vanno adesso")


## ⚠️ **SOPRAVVIVE AL JSON — e la controprova dice perché.**
##
## MISURATO (Godot 4.7.1): un `Vector3` dentro un Dictionary, passato dal
## salvataggio, torna indietro come **stringa**. Il filo va su disco intero
## (`save_extra` restituisce `_fili` per riferimento), quindi il difetto si
## manifesterebbe solo a partita ricaricata — e chi prova questa meccanica la
## prova sempre nella prima sessione.
##
## La strada provata è quella VERA: `save_extra` → JSON → `migra_fili`, che è
## esattamente quello che fa `load_extra`.
func _sopravvive_al_JSON(t) -> void:
	var lg = _filo_vero(t)
	lg.giorno(20)
	lg.nascita("Pepita", "Nocciola", "Malva")
	var dove := Vector3(7.25, 0.0, -3.5)
	t.ok(_impara(lg, "Pepita", dove), "impara")

	var salvato: Dictionary = lg.save_extra()
	var testo := JSON.stringify(salvato.get("legami", {}))
	var tornato: Variant = JSON.parse_string(testo)
	t.ok(tornato is Dictionary, "il salvataggio si rilegge")
	if tornato is not Dictionary:
		return
	var migrato: Dictionary = lg.migra_fili(tornato)
	t.ok(migrato.has("Pepita"), "il filo di Pepita è tornato")
	var v = EREDITA.posto_ereditato(migrato["Pepita"], 1.0)
	t.ok(v != null, "…e il posto dei suoi con lui")
	if v != null:
		t.ok((v as Vector3).is_equal_approx(dove),
				"…intatto al centimetro (%s)" % str(v))

	# --- LA CONTROPROVA: com'era il difetto, se il posto fosse un `Vector3`
	var crudo: Variant = JSON.parse_string(
			JSON.stringify({"p": Vector3(1.0, 0.0, 2.0)}))
	var riletto: Variant = (crudo as Dictionary)["p"]
	t.ok(riletto is String,
			"un Vector3 nel salvataggio torna indietro come STRINGA (%s)"
					% str(riletto))
	t.ok(EREDITA.posto_sul_filo({EREDITA.CHIAVE_POSTO: riletto}) == null,
			"…e una riga così viene rifiutata invece di leggersi storta")
	t.ok(EREDITA.posto_sul_filo({EREDITA.CHIAVE_POSTO: Vector3(1, 0, 2)}) == null,
			"…e un Vector3 crudo pure, subito e non al prossimo riavvio")


## GLI ASSI NON SI INVERTONO. `[x, z]` va scritta e riletta nello stesso
## ordine: uno scambio darebbe un punto plausibile, dentro il villaggio, a
## qualche metro da quello giusto — cioè il difetto che nessuna asserzione
## sulla presenza del posto vedrebbe.
##
## E la `y` non c'è: il villaggio si siede sul piano.
func _gli_assi_non_si_invertono(t) -> void:
	var dove := Vector3(7.0, 0.0, -3.0)
	var riga: Variant = EREDITA.posto_da_salvare(dove)
	t.ok(riga is Array and (riga as Array).size() == 2,
			"la riga è due numeri, non un Vector3")
	if riga is Array:
		t.almost(float((riga as Array)[0]), 7.0, "il primo numero è la x")
		t.almost(float((riga as Array)[1]), -3.0, "il secondo è la z")

	var v = EREDITA.posto_sul_filo({EREDITA.CHIAVE_POSTO: riga})
	t.ok(v != null, "e si rilegge")
	if v != null:
		t.almost((v as Vector3).x, 7.0, "la x è tornata x")
		t.almost((v as Vector3).z, -3.0, "la z è tornata z")

	# lo stesso, passando davvero dal disco
	var tornato: Variant = JSON.parse_string(JSON.stringify({"r": riga}))
	var v2 = EREDITA.posto_sul_filo(
			{EREDITA.CHIAVE_POSTO: (tornato as Dictionary)["r"]})
	t.ok(v2 != null, "anche dopo un giro nel JSON")
	if v2 != null:
		t.almost((v2 as Vector3).x, 7.0, "…la x è ancora la x")
		t.almost((v2 as Vector3).z, -3.0, "…e la z la z")

	# la quota si butta: un terreno spianato non deve poter sollevare
	# un'ancora di ieri
	var alto: Variant = EREDITA.posto_da_salvare(Vector3(2.0, 9.0, 5.0))
	var v3 = EREDITA.posto_sul_filo({EREDITA.CHIAVE_POSTO: alto})
	t.ok(v3 != null and is_zero_approx((v3 as Vector3).y),
			"la y non si salva e torna a zero")
	var dal_rit = EREDITA.posto_dal_ritrovo(
			{"dove": Vector3(2.0, 9.0, 5.0), "giorni": 3, "ora": 0.5,
			"ultimo": 1})
	t.ok(dal_rit != null and is_zero_approx((dal_rit as Vector3).y),
			"…e nemmeno il referto di Cricche porta la quota")


## ⚠️ **NON SI CREANO FILI FANTASMA**, ed è la trappola con la controprova
## più importante di questo file: `Legami._filo()` **crea il filo se manca**,
## con `giorno_arrivo` a oggi. Chi scrivesse l'eredità passando di lì
## fabbricherebbe un filo per ogni nome sconosciuto, che poi `_nuovo_giorno`
## fa invecchiare e che finisce nel salvataggio — e da lì in poi
## `giorni_di_amicizia` risponde per una persona che non esiste.
func _non_si_creano_fili_fantasma(t) -> void:
	# la metà pura: un filo che non c'è non impara e non si lascia toccare
	var vuoto := {}
	t.ok(not EREDITA.puo_imparare(vuoto, 0.5), "un filo vuoto non impara")
	t.ok(not EREDITA.incidi(vuoto, 0.5, Vector3(1, 0, 2)),
			"…e non si lascia incidere")
	t.eq(vuoto.size(), 0, "…e resta vuoto: nemmeno una chiave a metà")

	# la metà di cablaggio, sul `Legami` VERO
	var lg = _filo_vero(t)
	lg.giorno(20)
	var fili: Dictionary = lg.get("_fili")
	t.eq(fili.size(), 0, "si parte da zero fili")
	t.ok(not _puo(lg, "NessunoDiQuestoNome"),
			"un nome sconosciuto non può imparare")
	t.ok(not _impara(lg, "NessunoDiQuestoNome", Vector3(1, 0, 2)),
			"…e non incide niente")
	t.eq((lg.get("_fili") as Dictionary).size(), 0,
			"…e soprattutto NON gli si è fabbricato un filo")

	# LA CONTROPROVA: la porta sbagliata lo fabbrica davvero
	lg.call("_filo", "NessunoDiQuestoNome")
	t.eq((lg.get("_fili") as Dictionary).size(), 1,
			"`_filo()` invece un filo lo crea: è la porta da non usare")


## ⚠️ **NIENTE TESTO E NIENTE MOMENTO.** `Legami.TIPI` ha già un tipo
## «posto» — *«quel posto dove ci si trovava senza dirselo»* — e `momento()`
## fa scattare il toast del PRIMO di ogni tipo. Annodarne uno qui
## trasformerebbe l'unica conseguenza invisibile di questa meccanica in un
## annuncio, e questo pacchetto ha per contratto **zero stringhe nuove**.
func _niente_testo_e_niente_momento(t) -> void:
	var lg = _filo_vero(t)
	lg.giorno(20)
	lg.nascita("Pepita", "Nocciola", "Malva")
	var fili: Dictionary = lg.get("_fili")
	var filo: Dictionary = fili["Pepita"]
	var prima := filo.size()
	var momenti_prima: int = (lg.momenti_di("Pepita") as Array).size()

	t.ok(_impara(lg, "Pepita", Vector3(-9, 0, 4)), "impara")

	t.eq((lg.momenti_di("Pepita") as Array).size(), momenti_prima,
			"non si annoda nessun momento sul filo")
	t.eq(filo.size(), prima + 1,
			"sul filo compare UNA chiave sola (%d -> %d)" % [prima, filo.size()])
	t.ok(filo.has(EREDITA.CHIAVE_POSTO), "…ed è il posto")
	t.ok(not filo.has("g"), "nessun giorno: non lo leggerebbe nessuno")
	t.ok(not filo.has("da"),
			"nessun «da»: chi glielo ha insegnato è già padre/madre, e una "
			+ "riga di Cricche non ha verso")
	# e la tabella dei racconti resta quella che era: nessun tipo nuovo
	t.ok(LEGAMI.TIPI.has("posto"),
			"il tipo «posto» del Filo Rosso esiste (ed è un'altra cosa)")
	t.ok(not LEGAMI.TIPI.has(EREDITA.CHIAVE_POSTO),
			"…e l'eredità non si è aggiunta ai momenti raccontabili")


## IL DEGRADO VA SEMPRE VERSO IERI: qualunque cosa non si sappia leggere
## risponde `null`, e da lì in giù il vicino si siede come si è sempre seduto.
##
## ⚠️ `null` e **mai `Vector3.ZERO`**: l'origine è un punto vero del villaggio
## — ci passa il fiume — e usarla come «non lo so» manderebbe l'ancora
## nell'acqua per chiunque abbia un filo senza posto, cioè per quasi tutti.
func _il_degrado_va_verso_ieri(t) -> void:
	var k: String = EREDITA.CHIAVE_POSTO
	t.ok(EREDITA.posto_sul_filo({}) == null, "filo vuoto: null")
	t.ok(EREDITA.posto_sul_filo({"momenti": []}) == null, "senza la chiave: null")
	t.ok(EREDITA.posto_sul_filo({k: []}) == null, "riga vuota: null")
	t.ok(EREDITA.posto_sul_filo({k: [1.0]}) == null, "riga troncata: null")
	t.ok(EREDITA.posto_sul_filo({k: [1.0, 2.0, 3.0]}) == null,
			"riga di tre: null (non si indovina quale asse buttare)")
	t.ok(EREDITA.posto_sul_filo({k: ["1.0", "2.0"]}) == null,
			"due stringhe: null — `float(\"pippo\")` risponde 0.0 senza dirlo")
	t.ok(EREDITA.posto_sul_filo({k: {"x": 1, "z": 2}}) == null,
			"un dizionario: null")
	t.ok(EREDITA.posto_sul_filo({k: "(1.0, 0.0, 2.0)"}) == null,
			"il Vector3 stringato dal JSON: null")
	t.ok(EREDITA.posto_sul_filo({k: [NAN, 2.0]}) == null, "NaN: null")
	t.ok(EREDITA.posto_sul_filo({k: [INF, 2.0]}) == null, "infinito: null")
	t.ok(EREDITA.posto_sul_filo({k: [1, 2]}) != null,
			"…ma due interi si leggono (un banco può scriverli così)")

	t.ok(EREDITA.posto_dal_ritrovo({}) == null, "nessun ritrovo: null")
	t.ok(EREDITA.posto_dal_ritrovo({"giorni": 3}) == null,
			"un referto senza «dove»: null")
	t.ok(EREDITA.posto_dal_ritrovo({"dove": "(1, 0, 2)"}) == null,
			"un «dove» che non è un punto: null")
	t.ok(EREDITA.posto_dal_ritrovo({"dove": Vector3(NAN, 0, 2)}) == null,
			"un punto non finito: null")

	# e le crescite impossibili non aprono nessuna porta
	var filo := {"nato": true, "momenti": []}
	t.ok(not EREDITA.puo_imparare(filo, NAN), "crescita NaN: non si impara")
	t.ok(not EREDITA.puo_imparare(filo, INF), "crescita infinita: non si impara")
	# ⚠️ **E IL `-INF` È L'UNICO VALORE SU CUI `is_finite` DECIDE DA SOLA**, in
	# `puo_imparare`. NaN e `+INF` li rifiuta già il confronto (`NAN < 1.0` è
	# falso, e l'infinito positivo non è minore di uno): togliendo quella riga
	# il comportamento non cambierebbe di un bit per nessuno dei due. Ma
	# `-INF < 1.0` è **vero**, e senza la guardia aprirebbe la porta.
	# MISURATO: senza questa asserzione la mutazione «togli `is_finite` da
	# `puo_imparare`» lasciava **118 verdi su 118**, cioè una guardia che
	# nessun test poteva far fallire — che in questo progetto si toglie. La
	# riga resta perché ADESSO morde.
	t.ok(not EREDITA.puo_imparare(filo, -INF),
			"crescita meno infinito: non si impara")
	t.ok(EREDITA.posto_ereditato({k: [1.0, 2.0]}, NAN) == null,
			"crescita NaN: nessuna ancora")
	t.ok(EREDITA.posto_ereditato({k: [1.0, 2.0]}, INF) == null,
			"crescita infinita: nessuna ancora")
	t.ok(EREDITA.posto_ereditato({k: [1.0, 2.0]}, -1.0) == null,
			"crescita negativa: nessuna ancora")

	# un punto non finito non si incide, e non lascia niente a metà
	t.ok(EREDITA.posto_da_salvare(Vector3(NAN, 0, 1)) == null,
			"un punto NaN non si salva")
	t.ok(not EREDITA.incidi(filo, 0.5, Vector3(0, 0, INF)),
			"…e non si incide")
	t.ok(not filo.has(k), "…e il filo resta pulito")
	t.ok(EREDITA.puo_imparare(filo, 0.5),
			"…quindi domani si può ancora imparare davvero")


## LA CATENA INTERA, dal registro degli incontri all'ancora: `Cricche` vero →
## `Eredita` → `Legami` vero → salvataggio → riapertura → il punto.
##
## Ogni pezzo di questa catena ha già il suo caso; questo prova che i pezzi si
## parlano — che è la cosa che, in questo progetto, è mancata sei volte con la
## suite verde.
func _la_catena_intera(t) -> void:
	var lg = _filo_vero(t)
	var nascita := 40
	lg.giorno(nascita)
	lg.nascita("Pepita", "Nocciola", "Malva")
	t.ok(lg.e_nato("Pepita"), "è nata qui")
	t.eq(lg.genitori_di("Pepita"), ["Nocciola", "Malva"], "e ha i suoi due")

	# --- giorno per giorno, alla prima occasione buona: per i primi giorni i
	#     suoi non si ritrovano ancora, e non succede niente
	var imparati := 0
	for g in range(nascita, nascita + LEGAMI.GIORNI_ADULTO):
		lg.giorno(g)
		var rit: Dictionary = {}
		if g >= nascita + 6:
			rit = _ritrovo("Nocciola", "Malva", _giornate(g), 0.62,
					Vector3(-9.0, 0.0, 4.0), g)
		imparati += _giornata(lg, ["Pepita"], {"Pepita": rit})
	t.eq(imparati, 1,
			"in tutta l'infanzia si impara UNA volta (%d)" % imparati)

	# --- da grande, dopo un salvataggio e una riapertura
	lg.giorno(nascita + LEGAMI.GIORNI_ADULTO)
	t.almost(float(lg.crescita("Pepita")), 1.0, "ha finito di crescere")
	var migrato: Dictionary = lg.migra_fili(
			JSON.parse_string(JSON.stringify(lg.save_extra()["legami"])))
	var v = EREDITA.posto_ereditato(migrato["Pepita"],
			float(lg.crescita("Pepita")))
	t.ok(v != null, "l'ancora c'è, dall'altra parte del salvataggio")
	if v != null:
		t.ok((v as Vector3).is_equal_approx(Vector3(-9.0, 0.0, 4.0)),
				"…e punta l'angolo dei suoi (%s)" % str(v))

	# e chi non ha genitori nel villaggio non è cambiato di un bit
	lg.giorno(nascita)
	lg.registra_arrivo("Cannella")
	lg.giorno(nascita + LEGAMI.GIORNI_ADULTO)
	t.ok(not lg.e_nato("Cannella"), "Cannella è arrivata col trolley")
	t.ok(_posto(lg, "Cannella") == null, "…e per lei non è cambiato niente")
