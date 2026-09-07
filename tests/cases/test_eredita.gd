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
## 2. **IL GIRO GIORNALIERO NON È SORVEGLIATO DA QUI.**
##    `Visitors._impara_il_posto_dei_suoi` vive in un file che questa
##    consegna non possiede, e non ha un adattatore: quello che si prova qui
##    è la sua ARITMETICA (`_giornata`, che fa gli stessi tre passi con le
##    funzioni vere), non che qualcuno la chiami. È la cosa che in questo
##    progetto è mancata sei volte con la suite verde, e va saputa invece di
##    leggere il verde come «finita».
##
##    I due casi che sorvegliano la CASCATA
##    (`_l_ancora_non_allunga_il_guinzaglio`, `_l_ordine_dei_CINQUE_anelli`)
##    e il cancello d'arresto G3 (`_fin_dove_arriva_l_ancora`) invece ci
##    sono, e girano **sulla `_panchina_per` e sulla `_free_bench` di
##    produzione**: oggi provano la cascata a QUATTRO anelli (Mochi prima di
##    tutto, il ritrovo sopra il posto, casa come ripiego — cioè le tre
##    proprietà che il quinto anello non deve rompere), e il giorno che
##    `_ancora_dei_suoi` atterra passano da sole a sorvegliare il quinto.
##    L'adattatore è `_ancora`, e la sua ragione è la stessa di `_puo` /
##    `_impara` / `_posto`.

const EREDITA := preload("res://scenes/npc/Eredita.gd")
const CRICCHE := preload("res://scenes/npc/Cricche.gd")
const LEGAMI := preload("res://scenes/world/Legami.gd")
const VIS := preload("res://scenes/npc/Visitors.gd")
const VISITOR := preload("res://scenes/npc/Visitor.gd")
const DNA := preload("res://scenes/npc/ChibiDNA.gd")

const DT := 1.0 / 60.0


func run(t) -> void:
	_il_posto_e_di_CHI_lo_ha_cresciuto(t)
	_il_giro_del_giorno_lo_fa_imparare(t)
	_senza_cricche_il_giro_non_impara_niente(t)
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
	_l_ancora_non_allunga_il_guinzaglio(t)
	_fin_dove_arriva_l_ancora(t)
	_l_ordine_dei_CINQUE_anelli(t)


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
		# ⚠️ **IL GRUPPO NON È DECORATIVO**, e senza di lui la metà di
		# cablaggio di questo file sarebbe un ritratto: `_ancora_dei_suoi` e
		# `_impara_il_posto_dei_suoi` trovano il Filo Rosso **solo** con
		# `get_first_node_in_group("legami")` — è la trappola del figlio
		# runtime di CozyWorld, quella che ha ucciso il taccuino del Gufo.
		# Un fixture che lo perde fa degradare il cablaggio a «come ieri» e
		# lo lascia verde. («persistable» invece resta fuori apposta: qui non
		# c'è nessun salvataggio da tenere aggiornato, e un banco che si
		# offre a un BuildSystem altrui è un banco che scrive sul disco.)
		add_to_group("legami")
		var o := Orologio.new()
		add_child(o)
		_daynight = o

	func giorno(g: int) -> void:
		_daynight.set("day", g)


## Il registro dei vicini VERO, col solo `_ready` scavalcato: quello di
## produzione vuole `%Player` e `../BuildSystem`, cioè il villaggio intero.
## `_panchina_per`, `_seduta_da`, `_free_bench`, `ancora_riposo` e
## `_ancora_ritrovo` restano il codice che gira in partita: qui non si
## sostituisce **nessuna decisione**.
class Registro extends "res://scenes/npc/Visitors.gd":
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
		_build_ui()


## L'elenco dei pezzi posati. **Non è un BuildSystem finto**: non ha una
## regola dentro — risponde a due lookup, e la regola che questo file sta
## provando (quale seduta si sceglie) vive in `_free_bench`, che è quella
## vera. È l'idioma del `Magazzino` di `test_cuore_vicini`.
class Magazzino extends Node3D:
	var pezzi := {}
	func get_placed_by_name(n: String) -> Array:
		return pezzi.get(n, [])
	func raggiungibile(_a: Vector2i, _b: Vector2i) -> bool:
		return true


## Chi si ritrova con chi — e anche questo è un lookup, non una decisione:
## `_ancora_ritrovo` prende l'elenco e ne fa il punto medio delle CASE da sé,
## con le funzioni vere (`label_di_nome`, `cella_di`).
class Compagnie extends Node:
	var loro := PackedStringArray()
	func _ready() -> void:
		add_to_group("cricche")
	func compagni(_nome: String) -> PackedStringArray:
		return loro


## Chi si ritrova con chi, per il giro del giorno. **Non decide niente**: il
## referto glielo costruiscono le porte VERE di `Cricche` (`registra` +
## `ritrovo_vivo`), lui lo consegna. È l'idioma del `Magazzino` e di
## `Compagnie` — un doppio che REIMPLEMENTA la cosa da provare la lascia
## senza lettori, ed è il difetto che questo progetto ha già pagato col
## `MotoreFinto` della Fase 5.
class Ritrovi extends Node:
	var rit := {}
	func _ready() -> void:
		add_to_group("cricche")
	func ritrovo_di(_a: String, _b: String) -> Dictionary:
		return rit


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


## --- l'adattatore della CASCATA: la funzione VERA se c'è, altrimenti il
##     testo esatto della richiesta d'innesto consegnata al proprietario di
##     `Visitors.gd`. Ha la stessa forma di `_ancora_ritrovo` — il lookup, il
##     degrado a `home` ESATTO, e lo spostamento di al massimo `SPOSTA_MAX`.
##
## ⚠️ **`home` esatto e non «quasi»**: il quinto anello si salta con
## `if verso != home`, e otto asserzioni di `test_cuore_vicini` poggiano su
## quell'uguaglianza. Un degrado che tornasse `home + 0.0001` accenderebbe
## l'anello per tutto il villaggio, sempre.
static func _ancora(vis, lg, r: Dictionary, home: Vector3) -> Vector3:
	if vis.has_method("_ancora_dei_suoi"):
		return vis.call("_ancora_dei_suoi", r, home)
	var nome := str((r.get("dna", {}) as Dictionary).get("name", ""))
	if nome == "":
		return home
	var p: Variant = _posto(lg, nome)
	if p == null:
		return home
	return home.move_toward(p as Vector3, VIS.SPOSTA_MAX)


## Il villaggio minimo per la cascata: registro VERO in scena, N corpi veri,
## un magazzino di pezzi. Torna `{"vis", "righe", "build"}`.
func _villaggio(t, quanti: int) -> Dictionary:
	var vis = t.stage(Registro.new())
	var righe: Array = []
	for i in quanti:
		var v = VISITOR.new()
		v.dna = DNA.generate(4400 + i * 37)
		v.mode = "resident"
		t.stage(v)
		v._enter_state("r_idle")
		v._timer = 9999.0
		var r := {"node": v, "label": "Erede%d" % i, "dna": v.dna,
				"cell": Vector2i(0, 0), "species": "chibi"}
		vis._residents.append(r)
		righe.append(r)
		# niente quirk: `_quirk_tick` andrebbe a cercare funghi in un
		# villaggio che qui non c'è
		var b: RefCounted = vis._ensure_brain(r)
		b.quirk = ""
	var build = t.stage(Magazzino.new())
	vis._build = build
	return {"vis": vis, "righe": righe, "build": build}


func _seduta(t, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	t.stage(n)
	n.global_position = pos
	return n


## Un cucciolo VERO che ha già imparato il suo punto ed è diventato grande.
## Torna il Filo Rosso in scena (nel gruppo, come in partita).
func _erede(t, r: Dictionary, punto: Vector3):
	# ⚠️ **UN FILO ROSSO SOLO NEL GRUPPO, e non è pignoleria.** Il runner
	# libera i nodi messi in scena a fine FILE, non a fine caso: i dieci casi
	# qui sopra hanno già lasciato dieci `FiloVero` nel gruppo «legami», e
	# `_ancora_dei_suoi` chiederà `get_first_node_in_group`. Senza questa
	# riga il cablaggio, il giorno che atterra, interrogherebbe il filo di un
	# ALTRO caso — non troverebbe il nostro erede, degraderebbe a `home`, e
	# la guardia della cascata diventerebbe un ritratto proprio nel commit in
	# cui deve mordere.
	for vecchio in t.tree().get_nodes_in_group("legami"):
		vecchio.remove_from_group("legami")
	var lg = _filo_vero(t)
	# …e lo si DICE, o sarebbe una guardia che nessun test può far fallire:
	# oggi il gruppo non lo interroga ancora nessuno, e senza questa riga
	# togliere il ciclo qui sopra resterebbe verde fino al commit sbagliato.
	t.eq(t.tree().get_nodes_in_group("legami").size(), 1,
			"nel gruppo «legami» c'è UN filo solo: quello di questo caso")
	var nome := str((r["dna"] as Dictionary)["name"])
	lg.giorno(20)
	lg.nascita(nome, "Nocciola", "Malva")
	_impara(lg, nome, punto)
	lg.giorno(20 + LEGAMI.GIORNI_ADULTO)
	return lg


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


## ⚠️ **L'ANCORA NON ALLUNGA IL GUINZAGLIO DI UN METRO.**
##
## `Visitors.SPOSTA_MAX` non è un raggio di ricerca: la sua ragione scritta è
## che **nessuno cammini verso una PERSONA** — si cambia solo QUALE panchina,
## fra quelle che c'erano già. Un'ancora ereditata che si spostasse più in là
## porterebbe l'adulto dove non sarebbe mai potuto andare da sé, e siccome il
## punto ereditato può stare dall'altra parte del villaggio (viene dagli
## incontri di due persone, non dalla sua casa) sarebbe il caso peggiore
## possibile.
##
## Il numero si LEGGE da `Visitors`, mai riscritto qui: chi un domani lo
## cambia sposta le quattro ancore insieme e questo caso continua a valere.
func _l_ancora_non_allunga_il_guinzaglio(t) -> void:
	var mondo := _villaggio(t, 2)
	var vis = mondo["vis"]
	var r: Dictionary = mondo["righe"][0]
	var senza: Dictionary = mondo["righe"][1]
	var punto := Vector3(30.0, 0.0, 0.0)
	var lg = _erede(t, r, punto)
	var nome := str((r["dna"] as Dictionary)["name"])
	t.ok(_posto(lg, nome) != null,
			"PREMESSA: l'erede ha davvero un posto acceso")
	t.ok(_posto(lg, str((senza["dna"] as Dictionary)["name"])) == null,
			"…e l'altro residente no (non è nato qui)")

	var casa := Vector3.ZERO
	# (a) SENZA POSTO: `home` ESATTO. È l'uguaglianza su cui poggiano il
	#     salto dell'anello (`if verso != home`) e otto asserzioni di
	#     `test_cuore_vicini`, la cui fixture non mette nessun Legami in scena.
	t.ok(_ancora(vis, lg, senza, casa) == casa,
			"chi non ha imparato niente ha l'ancora a casa, IDENTICA")

	# (b) COL POSTO: ci si sposta verso, e non più di SPOSTA_MAX
	var a := _ancora(vis, lg, r, casa)
	t.ok(a != casa, "l'erede invece l'ancora la sposta (controprova)")
	t.almost(a.distance_to(casa), VIS.SPOSTA_MAX,
			"…di ESATTAMENTE SPOSTA_MAX, perché il punto è lontano", 1e-4)
	t.ok(a.distance_to(punto) < casa.distance_to(punto),
			"…e nella direzione giusta")

	# (c) LA SPAZZATA: il guinzaglio non esiste per NESSUNA configurazione.
	#     Il posto si riscrive a mano sul filo — `incidi` rifiuterebbe la
	#     seconda incisione, ed è il suo mestiere: qui si sta misurando la
	#     GEOMETRIA, non la regola (che ha già il suo caso).
	var fili: Dictionary = lg.get("_fili")
	var filo: Dictionary = fili[nome]
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260906
	var fuori := 0
	var mossi := 0
	var oltre := 0
	for _k in 600:
		var h := Vector3(rng.randf_range(-40.0, 40.0), 0.0,
				rng.randf_range(-40.0, 40.0))
		var p := Vector3(rng.randf_range(-40.0, 40.0), 0.0,
				rng.randf_range(-40.0, 40.0))
		filo[EREDITA.CHIAVE_POSTO] = [p.x, p.z]
		var an := _ancora(vis, lg, r, h)
		if an.distance_to(h) > VIS.SPOSTA_MAX + 1e-4:
			fuori += 1
		if an != h:
			mossi += 1
		# e non si SUPERA mai il punto: chi è già lì ci resta
		if an.distance_to(p) > h.distance_to(p) + 1e-4:
			oltre += 1
	t.eq(fuori, 0,
			"su seicento configurazioni a caso l'ancora non esce MAI da %.1f m da casa"
					% VIS.SPOSTA_MAX)
	t.eq(oltre, 0, "…e non supera mai il punto: ci arriva e si ferma")
	t.ok(mossi > 60,
			"…e si è mossa davvero (%d volte su 600): una garanzia rispettata da un canale spento non prova niente"
					% mossi)


## ⚠️ **IL CANCELLO D'ARRESTO G3, provato sulla `_free_bench` DI PRODUZIONE.**
##
## G3 chiede che la seduta scelta cada entro `Cricche.POSTO_LARGO` dal posto
## appreso; sotto la metà, questa meccanica **non si consegna come «il posto
## dei suoi»** — si legge «si siede da quella parte», che è un'altra frase.
##
## Qui non si misura la frequenza (quella la dà il banco in partita, e vuole
## dei cuccioli veri): si misura **fin dove è possibile**, che è una cosa che
## si sa senza il villaggio ed è quella che decide. Il punto ereditato è la
## media dei punti-medi degli incontri dei genitori — un punto in mezzo al
## prato — e l'adulto non abita a casa dei suoi (`accogli_nato` gli dà
## `_free_house()`, e il debito è dichiarato lì): la distanza fra casa e
## punto è quindi arbitraria, ed è **lei** a decidere.
##
## La soglia si COMPONE dai tre numeri veri, non si riscrive: oltre
## `SPOSTA_MAX + RAGGIO_SEDUTA + POSTO_LARGO` una seduta vicino al punto non
## è nemmeno un candidato di `_free_bench`, e G3 è zero per costruzione.
##
## ⚠️ E quando succede **la cura non è alzare `SPOSTA_MAX`** (quel guinzaglio
## tiene su le altre tre ancore): è `accogli_nato`.
func _fin_dove_arriva_l_ancora(t) -> void:
	var mondo := _villaggio(t, 1)
	var vis = mondo["vis"]
	var r: Dictionary = mondo["righe"][0]
	var punto := Vector3(0.0, 0.0, 0.0)
	var lg = _erede(t, r, punto)
	var nome := str((r["dna"] as Dictionary)["name"])
	var filo: Dictionary = (lg.get("_fili") as Dictionary)[nome]

	var soglia: float = VIS.SPOSTA_MAX + VIS.RAGGIO_SEDUTA + CRICCHE.POSTO_LARGO
	t.ok(soglia > 0.0,
			"la soglia si compone dai tre numeri veri: %.1f + %.1f + %.1f = %.1f m"
					% [VIS.SPOSTA_MAX, VIS.RAGGIO_SEDUTA, CRICCHE.POSTO_LARGO,
					soglia])

	# due sedute e basta: una SUL punto, una a casa. Chi vince dice tutto.
	var sul_punto := _seduta(t, punto)

	# (a) CASA VICINA AL PUNTO — la meccanica mantiene la sua frase
	var vicina := punto + Vector3(0.0, 0.0, 3.0)
	var a_casa_v := _seduta(t, vicina)
	(mondo["build"] as Node).set("pezzi",
			{"Panchina": [sul_punto, a_casa_v]})
	filo[EREDITA.CHIAVE_POSTO] = [punto.x, punto.z]
	var scelta_v: Node3D = vis._seduta_da(_ancora(vis, lg, r, vicina),
			r["node"] as Node3D)
	t.eq(scelta_v, sul_punto,
			"a %.1f m da casa si sceglie la seduta SUL punto dei suoi"
					% vicina.distance_to(punto))
	t.ok(scelta_v != null
			and scelta_v.global_position.distance_to(punto) <= CRICCHE.POSTO_LARGO,
			"…cioè G3 passa (%.2f m <= %.2f)"
					% [scelta_v.global_position.distance_to(punto)
							if scelta_v else -1.0, CRICCHE.POSTO_LARGO])

	# (b) CASA OLTRE LA SOGLIA — la seduta sul punto non è più candidata
	var lontana := punto + Vector3(0.0, 0.0, soglia + 5.0)
	var a_casa_l := _seduta(t, lontana)
	(mondo["build"] as Node).set("pezzi",
			{"Panchina": [sul_punto, a_casa_l]})
	var scelta_l: Node3D = vis._seduta_da(_ancora(vis, lg, r, lontana),
			r["node"] as Node3D)
	t.eq(scelta_l, a_casa_l,
			"a %.1f m da casa (oltre la soglia) si ripiega sulla seduta di casa"
					% lontana.distance_to(punto))
	t.ok(scelta_l != null
			and scelta_l.global_position.distance_to(punto) > CRICCHE.POSTO_LARGO,
			"…e G3 è zero PER COSTRUZIONE, non per sfortuna")

	# (c) DOVE STA IL CONFINE, MISURATO invece che dedotto — e sono DUE, e il
	#     più stretto è quello che decide in partita.
	#
	#     ⚠️ La soglia composta qui sopra è il limite ASSOLUTO: oltre, la
	#     seduta sul punto non è nemmeno un candidato. Ma `_free_bench` prende
	#     la più vicina ALL'ANCORA, non al punto — e l'ancora sta sempre a
	#     `SPOSTA_MAX` da casa. Quindi appena c'è **una qualunque seduta
	#     vicino a casa** (cioè sempre: l'adulto una casa ce l'ha) la seduta
	#     sul punto perde già a `2 · SPOSTA_MAX`, meno della METÀ del limite
	#     assoluto. MISURATO qui sotto: **11 m contro 22**.
	#
	#     È il numero che il banco in partita deve confrontare con la
	#     distanza casa→punto, e la ragione per cui questa meccanica non si
	#     ripara con `SPOSTA_MAX`: raddoppiarlo raddoppierebbe tutti e due i
	#     confini e allungherebbe il guinzaglio delle altre TRE ancore.
	var con_casa := -1.0
	var da_sola := -1.0
	for i in range(0, 61):
		var d := float(i)
		var h := punto + Vector3(0.0, 0.0, d)
		var a_casa := _seduta(t, h)
		var an := _ancora(vis, lg, r, h)
		(mondo["build"] as Node).set("pezzi", {"Panchina": [sul_punto, a_casa]})
		if vis._seduta_da(an, r["node"] as Node3D) == sul_punto:
			con_casa = d
		(mondo["build"] as Node).set("pezzi", {"Panchina": [sul_punto]})
		if vis._seduta_da(an, r["node"] as Node3D) == sul_punto:
			da_sola = d
	t.ok(con_casa >= 0.0 and da_sola >= 0.0,
			"i due confini si sono visti (con una seduta a casa: %.0f m; senza: %.0f m)"
					% [con_casa, da_sola])
	t.ok(con_casa < 2.0 * VIS.SPOSTA_MAX,
			"con una seduta a casa il punto perde entro 2·SPOSTA_MAX (%.0f < %.1f)"
					% [con_casa, 2.0 * VIS.SPOSTA_MAX])
	t.ok(da_sola > 2.0 * VIS.SPOSTA_MAX,
			"…e senza, si arriva molto più lontano (%.0f > %.1f): i due confini "
			% [da_sola, 2.0 * VIS.SPOSTA_MAX]
			+ "sono davvero due, e il più stretto è quello che si vive")
	t.ok(da_sola <= soglia,
			"…ma nemmeno quello supera il limite assoluto (%.0f <= %.1f)"
					% [da_sola, soglia])


## ⚠️ **L'ORDINE DEGLI ANELLI È LA TERZA DOMANDA DELLA REGOLA SACRA SCRITTA
## IN UN ORDINE**, ed è l'unico modo in cui questa meccanica può uscire dai
## binari senza che niente se ne accorga.
##
## Il quinto anello sta **sotto il ritrovo e sopra casa**, e **mai sopra
## Mochi**. Se salisse sopra `ancora_riposo`, un adulto se ne andrebbe
## nell'angolo dei suoi genitori **proprio nel momento in cui il giocatore
## arriva** — e il giocatore avrebbe imparato, senza una parola, di essere
## quello di troppo. Non si vede in nessun caso di test che guardi una
## funzione sola: si vede solo mettendo quattro sedute nello stesso villaggio
## e guardando quale si sceglie.
##
## ⚠️ E la guardia che c'era — `test_cricche_corpo._ordine_delle_ancore` — è
## un SOURCE-CHECK che conosce TRE nomi: aggiungere righe non la rompe, e la
## quinta ancora non la vede proprio. Questa è comportamentale, e gira sulla
## `_panchina_per` vera.
##
## Le scene 1, 3 e 4 valgono **oggi**: sono le tre proprietà della cascata a
## quattro anelli che il quinto non deve rompere. La scena 2 è l'unica che
## cambia risposta quando il cablaggio atterra, e in tutte e due le versioni
## dice una cosa vera — è lo stesso contratto di `_puo` / `_impara` /
## `_posto`.
func _l_ordine_dei_CINQUE_anelli(t) -> void:
	var mondo := _villaggio(t, 2)
	var vis = mondo["vis"]
	var r: Dictionary = mondo["righe"][0]
	var corpo := r["node"] as Node3D
	var casa := Vector3.ZERO

	# il punto dei suoi, a 24 m: l'ancora del quinto anello cade a (0,0,-6)
	var punto := Vector3(0.0, 0.0, -24.0)
	var lg = _erede(t, r, punto)
	var nome := str((r["dna"] as Dictionary)["name"])

	# il compagno di ritrovo abita a 24 m dall'altra parte: l'ancora del
	# terzo anello cade a (6,0,0) — le calcola `_ancora_ritrovo` da sé
	var altro: Dictionary = mondo["righe"][1]
	altro["cell"] = Vector2i(24, 0)
	var cric = t.stage(Compagnie.new())

	# quattro sedute, una per anello, ognuna ESATTAMENTE sulla sua ancora
	var s_mochi := _seduta(t, Vector3(0.0, 0.0, 6.0))
	var s_loro := _seduta(t, Vector3(6.0, 0.0, 0.0))
	var s_suoi := _seduta(t, Vector3(0.0, 0.0, -6.0))
	var s_casa := _seduta(t, casa)
	(mondo["build"] as Node).set("pezzi",
			{"Panchina": [s_mochi, s_loro, s_suoi, s_casa]})

	var mochi := t.stage(Node3D.new()) as Node3D
	mochi.global_position = Vector3(0.0, 0.0, 80.0)   # lontanissima
	vis._player = mochi

	# --- SCENA 3: niente posto, niente ritrovo → CASA (il ripiego)
	var fili: Dictionary = lg.get("_fili")
	var filo: Dictionary = fili[nome]
	var inciso: Variant = filo[EREDITA.CHIAVE_POSTO]
	filo.erase(EREDITA.CHIAVE_POSTO)
	t.ok(_posto(lg, nome) == null, "PREMESSA: adesso non ha nessun posto")
	t.eq(vis._panchina_per(r, casa), s_casa,
			"senza niente si ripiega su casa — e l'eredità AGGIUNGE, mai toglie")
	filo[EREDITA.CHIAVE_POSTO] = inciso
	t.ok(_posto(lg, nome) != null, "…e il posto è tornato (controprova)")

	# --- SCENA 2: col posto, e senza nient'altro
	var scelta_2 = vis._panchina_per(r, casa)
	if vis.has_method("_ancora_dei_suoi"):
		t.eq(scelta_2, s_suoi,
				"col posto dei suoi, e nient'altro, si va NEL POSTO DEI SUOI")
	else:
		t.eq(scelta_2, s_casa,
				"il quinto anello non è ancora cablato: si ripiega su casa "
				+ "(e la materia prima c'è già, vedi la riga sopra)")

	# --- SCENA 4: il RITROVO suo batte il posto dei suoi. Chi ha una vita
	#     propria la vive; l'eredità è quello che resta quando non ce l'ha.
	cric.loro = PackedStringArray([str((altro["dna"] as Dictionary)["name"])])
	t.ok(vis._ancora_ritrovo(r, casa) != casa,
			"PREMESSA: adesso il terzo anello ha davvero un'ancora")
	t.eq(vis._panchina_per(r, casa), s_loro,
			"il ritrovo SUO sta sopra il posto dei suoi genitori")
	cric.loro = PackedStringArray()

	# --- SCENA 1: MOCHI PRIMA DI TUTTO, e non si negozia
	vis._ciclo_sonno(DT, 0.5)          # nasce l'entità nel registro C++
	var id: int = int(r.get("ecs", -1))
	t.ok(id >= 0, "PREMESSA: il cuore C++ ha dato un'entità a questo corpo")
	if id < 0:
		return
	vis._ecs.osserva(id, vis._ecs.indice_verbo("annaffia"), Vector3(1, 0, 1), -1)
	t.ok(float(vis._ecs.ammirazione(id)) > VIS.AMMIRA_SOGLIA,
			"…e una sola occhiata basta a spostare l'ancora di Mochi (%.3f)"
					% float(vis._ecs.ammirazione(id)))
	mochi.global_position = Vector3(0.0, 0.0, 10.0)
	t.eq(vis._panchina_per(r, casa), s_mochi,
			"quando arrivi, il villaggio NON si raggruppa altrove: Mochi prima "
			+ "di tutto, posto dei suoi compreso")

	# …e col ritrovo vivo INSIEME a Mochi, vince comunque Mochi
	cric.loro = PackedStringArray([str((altro["dna"] as Dictionary)["name"])])
	t.eq(vis._panchina_per(r, casa), s_mochi,
			"…anche col ritrovo suo acceso nello stesso istante")


## ⚠️ LA PROVA CHE IL CABLAGGIO ESISTE — e prima di lei non esisteva.
##
## MISURATO il 2026-09-06, togliendo `_impara_il_posto_dei_suoi()` dal giro
## del giorno di `Visitors`: questo file restava verde su **158 asserzioni su
## 158**. L'aritmetica dell'eredità era provata da undici casi; la riga che la
## fa ACCADERE, da nessuno. È la forma di guasto che questo progetto ha già
## pagato sette volte — il Filo Rosso, le 247 righe di somatizzazione, il
## canale della melatonina: sistemi interi completi, provati, verdi, e senza
## un solo chiamante in partita.
##
## Qui si attraversa `Visitors._on_new_day` VERO, e l'osservabile è che il
## cucciolo NON PUÒ PIÙ imparare: si impara una volta sola, quindi «non può
## più» è esattamente «l'ha appena fatto».
func _il_giro_del_giorno_lo_fa_imparare(t) -> void:
	for vecchio in t.tree().get_nodes_in_group("legami"):
		vecchio.remove_from_group("legami")
	for vecchio in t.tree().get_nodes_in_group("cricche"):
		vecchio.remove_from_group("cricche")
	var oggi := 20
	var lg = _filo_vero(t)
	lg.giorno(oggi)
	lg.nascita("Erede", "Nocciola", "Malva")
	var punto := Vector3(7.0, 0.0, -4.0)
	var rit := _ritrovo("Nocciola", "Malva", _giornate(oggi), 0.55, punto, oggi)
	t.ok(not rit.is_empty(), "la materia prima c'è: i suoi si ritrovano davvero")
	var cric = t.stage(Ritrovi.new())
	cric.rit = rit
	var vis = t.stage(Registro.new())
	vis._residents.append({"dna": {"name": "Erede"}, "label": "Erede",
			"cell": Vector2i(0, 0), "species": "chibi"})
	t.ok(lg.puo_imparare_il_posto("Erede"),
			"prima del giro non ha ancora imparato niente")

	vis._on_new_day(oggi)

	t.ok(not lg.puo_imparare_il_posto("Erede"),
			"IL GIRO DEL GIORNO LO FA IMPARARE: adesso non può più, e si impara una volta sola")
	# …e quel che ha imparato è il posto dei SUOI, non un punto qualunque:
	# da adulto l'ancora lo sa dire
	lg.giorno(oggi + LEGAMI.GIORNI_ADULTO + 1)
	var p = lg.posto_dei_suoi("Erede")
	t.ok(p != null, "da adulto il posto dei suoi c'è")
	if p != null:
		t.almost((p as Vector3).distance_to(punto), 0.0,
				"…ed è ESATTAMENTE il punto in cui si ritrovavano", 0.001)


## LA CONTROPROVA, e senza di lei la riga qui sopra non direbbe niente: il
## degrado va verso «oggi non si impara», mai verso un errore. Senza nessuno
## nel gruppo «cricche» — i banchi, il diorama del titolo, il Prologo, e i
## parecchi frame dopo un caricamento — il giro del giorno passa e non
## succede niente.
func _senza_cricche_il_giro_non_impara_niente(t) -> void:
	for vecchio in t.tree().get_nodes_in_group("legami"):
		vecchio.remove_from_group("legami")
	for vecchio in t.tree().get_nodes_in_group("cricche"):
		vecchio.remove_from_group("cricche")
	var oggi := 20
	var lg = _filo_vero(t)
	lg.giorno(oggi)
	lg.nascita("Solo", "Nocciola", "Malva")
	var vis = t.stage(Registro.new())
	vis._residents.append({"dna": {"name": "Solo"}, "label": "Solo",
			"cell": Vector2i(0, 0), "species": "chibi"})
	vis._on_new_day(oggi)
	t.ok(lg.puo_imparare_il_posto("Solo"),
			"senza il registro dei ritrovi non si impara niente, e non si rompe niente")
