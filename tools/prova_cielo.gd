extends SceneTree

## IL METRO DEL CIELO — quante righe rotte arrivano al giocatore, prima e dopo.
##
## Le altre verifiche della Fase 5 dicono se una regola SCATTA. Questa dice
## l'unica cosa che conta davvero: **su un mazzo vero di lettere già mandate,
## quante ne erano rotte e quante ne restano** — e, dall'altra parte,
## **quante lettere buone il filtro nuovo butta per sbaglio**. Senza il
## secondo numero il primo non vuol dire niente: un collaudo che boccia tutto
## azzera le righe rotte e spegne il gioco.
##
## ────────────────────────────────────────────────────────────────────────
## PERCHÉ NON SERVE IL MODELLO, e perché è più onesto così
## ────────────────────────────────────────────────────────────────────────
##
## Rigenerare il mazzo con un altro modello darebbe due villaggi diversi, e
## la differenza misurata non sarebbe della regola: sarebbe del dado. Qui si
## fa la cosa APPAIATA — le stesse bozze, gli stessi punteggi, la stessa
## sera — e si cambia soltanto il collaudo. Il mazzo registrato porta con sé
## tutto quello che serve per farlo in modo ESATTO:
##
##  · `bozze`      — le stringhe che il modello ha scritto quella sera;
##  · `schede`     — il verdetto di IERI, bozza per bozza, con la sua porta;
##  · `citazioni`  — per sapere quale riga è la citazione e quali sono libere;
##  · `mondo`      — {ora, pioggia, stagione}: che tempo faceva DAVVERO.
##
## Il verdetto di oggi è quello di ieri **più** le porte nuove: una bozza che
## ieri cadeva sulla forma cade anche oggi, e quella che ieri passava viene
## ripassata dalle porte nuove. Rarità e lontananza NON cambiano — si
## misurano contro tutto quello che il modello ha scritto, bocciate comprese
## (`Giudice._scheda`) — quindi la gara si rigioca con gli stessi punti e la
## differenza è tutta e sola del filtro.
##
## ⚠️ LA CONTROPROVA STA DENTRO: prima di misurare qualunque cosa, il banco
## rigioca la gara di IERI con le regole di ieri e pretende di ritrovare la
## stessa scelta registrata, lettera per lettera. Se non la ritrova, il
## replay non è fedele e i numeri di dopo non valgono niente — e lo dice
## invece di stampare una tabella bella.
##
##     CHIBI_MAZZO=<pensieri.jsonl> \
##       Godot --headless --path . --script res://tools/prova_cielo.gd
##
## Il mazzo è quello che `tools/prova_pensieri.gd` (e i banchi che ne
## discendono) registrano riga per riga.

const SUG := preload("res://scenes/npc/Suggeritore.gd")
const GIU := preload("res://scenes/npc/Giudice.gd")
const ORA := preload("res://scenes/ui/OraDelGiorno.gd")
const CRIT := preload("res://scenes/world/Critters.gd")

## Gli stessi pesi del Giudice, non due numeri riscritti qui.
const PESO_RARITA := GIU.PESO_RARITA
const PESO_LONTANANZA := GIU.PESO_LONTANANZA


func _init() -> void:
	var percorso := OS.get_environment("CHIBI_MAZZO")
	if percorso == "":
		print("serve CHIBI_MAZZO=<pensieri.jsonl>")
		quit(2)
		return
	var righe := _leggi(percorso)
	if righe.is_empty():
		print("mazzo vuoto o illeggibile: ", percorso)
		quit(2)
		return

	var lettere := []
	for r in righe:
		var d: Dictionary = r
		if str(d.get("tipo", "")) != "lettera":
			continue
		if not (d.has("bozze") and d.has("schede") and d.has("mondo")):
			continue
		lettere.append(d)
	print("=== IL METRO DEL CIELO ===")
	print("mazzo: %s" % percorso)
	print("pensieri con le bozze registrate: %d" % lettere.size())

	if not _la_controprova(lettere):
		quit(1)
		return

	_la_misura(lettere)
	_il_costo_riga_per_riga(lettere)
	_le_lettere_di_dopo(lettere)
	quit(0)


# =========================================================================
# LA CONTROPROVA — il replay è fedele?
# =========================================================================

## Rigioca la gara di ieri con le regole di ieri. Deve ridare, lettera per
## lettera, la scelta che sta scritta nel mazzo.
func _la_controprova(lettere: Array) -> bool:
	var storti := 0
	for d in lettere:
		var scelta := _gara(d as Dictionary, false)
		if scelta != int((d as Dictionary).get("scelta", -1)):
			storti += 1
			print("  ⚠️ replay infedele: registrato %d, rigiocato %d — %s"
					% [int((d as Dictionary).get("scelta", -1)), scelta,
					str((d as Dictionary).get("chi", ""))])
	if storti > 0:
		print("\nIL REPLAY NON È FEDELE (%d su %d): i numeri di dopo non valgono."
				% [storti, lettere.size()])
		return false
	print("controprova: la gara di ieri, rigiocata con le regole di ieri, dà")
	print("             la stessa scelta in tutti e %d i casi.\n" % lettere.size())
	return true


## La gara di una sera. `nuove` accende le porte nuove.
func _gara(d: Dictionary, nuove: bool) -> int:
	var schede: Array = d.get("schede", [])
	var bozze: Array = d.get("bozze", [])
	var cit: Array = d.get("citazioni", [])
	var rit := _mondo_di(d)
	var vince := -1
	var punti_vince := 0.0
	for i in schede.size():
		var s: Dictionary = schede[i]
		if not bool(s.get("ok", false)):
			continue
		if nuove and i < bozze.size() and _porta_nuova(str(bozze[i]), cit, rit) != "":
			continue
		var p := _punti(s)
		if vince < 0 or p > punti_vince:
			vince = i
			punti_vince = p
	return vince


## Il punteggio di una scheda già scritta: la rarità è un campo, la
## lontananza sta nel motivo («ammessa (rarità 0.65, lontananza 1.00)») —
## che è come il gioco l'ha raccontata quella sera.
func _punti(s: Dictionary) -> float:
	return PESO_RARITA * float(s.get("rarita", 0.0)) \
			+ PESO_LONTANANZA * _lontananza(str(s.get("perche", "")))


func _lontananza(perche: String) -> float:
	var k := perche.find("lontananza ")
	if k < 0:
		return 0.0
	var coda := perche.substr(k + 11)
	return coda.to_float()


# =========================================================================
# LE PORTE NUOVE — le sole tre righe di produzione che questo banco chiama
# =========================================================================

## Il motivo per cui una bozza NON passerebbe più, o "". Le tre funzioni
## sono quelle vere di `Suggeritore`, chiamate con le stesse righe libere
## che userebbe `accetta()` (`Giudice.righe_libere`).
func _porta_nuova(testo: String, cit: Array, rit: Dictionary) -> String:
	for riga in GIU.righe_libere(testo, cit):
		var c := SUG.afferma_sul_cielo(str(riga), rit)
		if c != "":
			return "cielo: " + c
		var p := SUG.parole_storte(str(riga))
		if p != "":
			return "parola: " + p
		var s := SUG.sagoma_del_foglio(str(riga))
		if s != "":
			return "sagoma: " + s
	return ""


## IL MONDO DI QUELLA SERA, ricostruito da com'è stato registrato. Le due
## derivazioni non sono inventate qui: `momento` è la stessa funzione che il
## foglio chiama (`OraDelGiorno.momento`), e «d'inverno la precipitazione è
## una nevicata» è la riga di `CozyWorld.contesto_critter()`.
##
## Il mazzo non ha registrato la NEBBIA (allora nessuno la guardava): un
## villaggio nebbioso letto come sereno farebbe bocciare una riga sulla
## nebbia che era vera. Sarebbe un falso positivo di QUESTO banco, non del
## gioco — e va nella direzione prudente, cioè peggiora i numeri di dopo
## invece di abbellirli.
func _mondo_di(d: Dictionary) -> Dictionary:
	var m: Dictionary = d.get("mondo", {})
	var stagione := str(m.get("stagione", ""))
	var meteo := str(CRIT.METEO[0])
	if bool(m.get("pioggia", false)):
		meteo = str(CRIT.METEO[2]) if stagione == "inverno" else str(CRIT.METEO[1])
	return {
		"meteo": meteo,
		"stagione": stagione,
		"momento": ORA.momento(int(float(m.get("ora", 0.5)) * 24.0)),
	}


# =========================================================================
# LA MISURA
# =========================================================================

func _la_misura(lettere: Array) -> void:
	var mandate_prima := 0
	var mandate_dopo := 0
	var rotte_prima := 0
	var rotte_dopo := 0
	var mute_nuove := 0
	var cambiate := 0
	var uguali := 0
	var righe_rotte_prima := 0
	var righe_rotte_dopo := 0

	print("=== LE LETTERE, UNA PER UNA ===")
	for d in lettere:
		var dd: Dictionary = d
		var bozze: Array = dd.get("bozze", [])
		var cit: Array = dd.get("citazioni", [])
		var rit := _mondo_di(dd)
		var prima := int(dd.get("scelta", -1))
		var dopo := _gara(dd, true)

		var rp := 0
		var rd := 0
		if prima >= 0 and prima < bozze.size():
			mandate_prima += 1
			rp = _righe_rotte(str(bozze[prima]), cit, rit)
			righe_rotte_prima += rp
			if rp > 0:
				rotte_prima += 1
		if dopo >= 0 and dopo < bozze.size():
			mandate_dopo += 1
			rd = _righe_rotte(str(bozze[dopo]), cit, rit)
			righe_rotte_dopo += rd
			if rd > 0:
				rotte_dopo += 1

		if prima >= 0 and dopo < 0:
			mute_nuove += 1
		elif prima != dopo:
			cambiate += 1
		elif prima >= 0:
			uguali += 1

		if prima != dopo:
			print("  %-22s %s → %s   %s" % [
					str(dd.get("chi", "")), _dimmi(prima), _dimmi(dopo),
					"(%s)" % _perche(dd, prima, cit, rit) if prima >= 0 else ""])
			if prima >= 0:
				for riga in GIU.righe_libere(str(bozze[prima]), cit):
					print("        prima: %s" % str(riga))
			if dopo >= 0:
				for riga in GIU.righe_libere(str(bozze[dopo]), cit):
					print("        dopo:  %s" % str(riga))

	print("\n=== IL CONTO ===")
	print("  lettere mandate               %3d  →  %3d" % [mandate_prima, mandate_dopo])
	print("  ...di cui con una riga rotta  %3d  →  %3d" % [rotte_prima, rotte_dopo])
	print("  righe rotte, in tutto         %3d  →  %3d" % [righe_rotte_prima, righe_rotte_dopo])
	print("  lettere diventate SILENZIO    %3d" % mute_nuove)
	print("  lettere cambiate di bozza     %3d" % cambiate)
	print("  lettere rimaste identiche     %3d" % uguali)
	print("")
	print("  ⚠️ LO ZERO DI DESTRA È UNA TAUTOLOGIA, e va detto: la gara nuova")
	print("     ammette solo bozze che passano queste porte, e «righe rotte» le")
	print("     conta con le stesse porte. Quel numero dice «il filtro fa quello")
	print("     che dice di fare», non «le lettere adesso sono giuste» — le")
	print("     righe rotte che nessuna regola vede (le non-parole con le")
	print("     vocali, le righe ripetute) restano, e per contarle bisogna")
	print("     LEGGERE le %d lettere di dopo, che sono stampate in fondo." % mandate_dopo)
	print("")
	print("  IL NUMERO CHE NON È UNA TAUTOLOGIA È QUESTO:")
	print("    lettere toccate dal filtro           %3d" % (mute_nuove + cambiate))
	print("    ...di cui erano ROTTE                %3d" % _quante_rotte_toccate(lettere))
	print("    lettere sane cambiate per sbaglio    %3d" % _sane_toccate(lettere))


func _dimmi(i: int) -> String:
	return "silenzio" if i < 0 else "bozza %d" % i


func _perche(d: Dictionary, i: int, cit: Array, rit: Dictionary) -> String:
	var bozze: Array = d.get("bozze", [])
	if i < 0 or i >= bozze.size():
		return ""
	return _porta_nuova(str(bozze[i]), cit, rit)


## QUANTE RIGHE LIBERE DI QUESTA BOZZA SONO ROTTE, secondo le porte nuove.
## Non è lo stesso conto di `_porta_nuova`, che si ferma alla prima: qui
## servono le RIGHE, perché è così che il guasto si legge sullo schermo.
func _righe_rotte(testo: String, cit: Array, rit: Dictionary) -> int:
	var n := 0
	for riga in GIU.righe_libere(testo, cit):
		if SUG.afferma_sul_cielo(str(riga), rit) != "" \
				or SUG.parole_storte(str(riga)) != "" \
				or SUG.sagoma_del_foglio(str(riga)) != "":
			n += 1
	return n


## QUANTE DELLE LETTERE CHE IL FILTRO HA TOCCATO ERANO GIÀ ROTTE.
func _quante_rotte_toccate(lettere: Array) -> int:
	var n := 0
	for d in lettere:
		var dd: Dictionary = d
		var prima := int(dd.get("scelta", -1))
		if prima < 0 or prima == _gara(dd, true):
			continue
		var bozze: Array = dd.get("bozze", [])
		if prima < bozze.size() and _righe_rotte(str(bozze[prima]),
				dd.get("citazioni", []), _mondo_di(dd)) > 0:
			n += 1
	return n


## ...E QUANTE ERANO SANE. È il falso positivo al livello che il giocatore
## vede: una lettera che non aveva niente che non andasse, e che il filtro
## nuovo ha comunque cambiato o fatto tacere.
func _sane_toccate(lettere: Array) -> int:
	var n := 0
	for d in lettere:
		var dd: Dictionary = d
		var prima := int(dd.get("scelta", -1))
		if prima < 0 or prima == _gara(dd, true):
			continue
		var bozze: Array = dd.get("bozze", [])
		if prima < bozze.size() and _righe_rotte(str(bozze[prima]),
				dd.get("citazioni", []), _mondo_di(dd)) == 0:
			n += 1
	return n


# =========================================================================
# IL COSTO — quante righe BUONE si perdono, e per quale porta
# =========================================================================

## Il falso positivo non si stima: si guarda. Qui si stampano TUTTE le righe
## libere del mazzo che le porte nuove bocciano, divise per porta, così che
## chi legge decida con gli occhi se erano righe da buttare. È lo stesso
## metodo del provino delle luci: cinque varianti affiancate, e si sceglie
## guardando.
func _il_costo_riga_per_riga(lettere: Array) -> void:
	var conta := {}
	var viste := {}
	var totali := 0
	print("\n=== OGNI RIGA LIBERA DEL MAZZO CHE LE PORTE NUOVE BOCCIANO ===")
	for d in lettere:
		var dd: Dictionary = d
		var cit: Array = dd.get("citazioni", [])
		var rit := _mondo_di(dd)
		var schede: Array = dd.get("schede", [])
		var bozze: Array = dd.get("bozze", [])
		# SOLO LE BOZZE CHE IERI PASSAVANO. Le altre non sarebbero mai
		# arrivate al giocatore, e contarle gonfierebbe il costo con righe
		# che erano già state buttate da un'altra porta.
		for i in bozze.size():
			if i >= schede.size() or not bool((schede[i] as Dictionary).get("ok", false)):
				continue
			var b: String = str(bozze[i])
			for riga in GIU.righe_libere(b, cit):
				totali += 1
				var porta := ""
				var motivo := ""
				var c := SUG.afferma_sul_cielo(str(riga), rit)
				var p := SUG.parole_storte(str(riga))
				var s := SUG.sagoma_del_foglio(str(riga))
				if c != "":
					porta = "cielo"
					motivo = c
				elif p != "":
					porta = "parola"
					motivo = p
				elif s != "":
					porta = "sagoma"
					motivo = s
				if porta == "":
					continue
				conta[porta] = int(conta.get(porta, 0)) + 1
				var chiave := porta + "|" + str(riga)
				if viste.has(chiave):
					continue
				viste[chiave] = true
				print("  [%s] %-52s  %s" % [porta, str(riga), motivo])
	print("\n  righe libere in tutto il mazzo: %d" % totali)
	for porta in conta:
		print("  bocciate da «%s»: %d" % [str(porta), int(conta[porta])])


# =========================================================================
# E ADESSO SI LEGGONO
# =========================================================================

## LE LETTERE CHE IL GIOCATORE AVREBBE RICEVUTO, dopo. Stampate com'è la
## busta (`Suggeritore.rifinisci`), perché l'ultima parola su una lettera non
## ce l'ha un contatore: ce l'ha chi legge. È la stessa regola per cui una
## posa si guarda in un provino e non in una suite verde.
func _le_lettere_di_dopo(lettere: Array) -> void:
	print("\n=== LE LETTERE DI DOPO, DA LEGGERE ===")
	var n := 0
	for d in lettere:
		var dd: Dictionary = d
		var i := _gara(dd, true)
		if i < 0:
			continue
		var bozze: Array = dd.get("bozze", [])
		if i >= bozze.size():
			continue
		n += 1
		var m: Dictionary = dd.get("mondo", {})
		print("\n--- %02d  %s   (%s, %s)" % [n, str(dd.get("chi", "")),
				_mondo_di(dd)["momento"], _mondo_di(dd)["meteo"]])
		for riga in SUG.rifinisci(str(bozze[i])).split("\n"):
			print("    " + str(riga))
	print("\n(%d lettere)" % n)


# =========================================================================

func _leggi(percorso: String) -> Array:
	var f := FileAccess.open(percorso, FileAccess.READ)
	if f == null:
		return []
	var out := []
	while not f.eof_reached():
		var riga := f.get_line().strip_edges()
		if riga == "":
			continue
		var d = JSON.parse_string(riga)
		if d is Dictionary:
			out.append(d)
	return out
