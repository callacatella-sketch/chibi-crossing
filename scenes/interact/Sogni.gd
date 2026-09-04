extends Node

## I SOGNI — sette secondi di lampada sopra un ricordo, e nessuno che parla.
##
## Nei cozy, dormire è il momento in cui si tirano le somme: quante monete,
## quanti pesci, quanti giorni. Qui è il momento in cui il gioco ti
## restituisce QUALCUNO. `Legami.partiti()` sa chi se n'è andato, e quelle
## persone non possono più fare momenti nuovi: il loro filo può soltanto
## accorciarsi. Il sogno è l'unica cosa che lo tiene fermo.
##
## ============================================================
## LA TRAPPOLA, E LE SEI REGOLE CHE LA TENGONO FUORI
## ============================================================
## «Se il sogno diventa una schermata con i numeri della giornata, è morto».
## Non basta togliere i numeri: un riepilogo può essere muto e restare un
## referto. Le regole, in ordine di quanto costa violarle:
##
## 1. NIENTE PAROLE. Nessun nome, nessuna data, nessuna icona, nessuna UI.
##    Chi è si riconosce dal CORPO — il suo pelo, le sue orecchie, la sua
##    gobba d'anziano, il suo fiore — e da nient'altro.
## 2. NIENTE PROP-PITTOGRAMMA. Una stellina per «desiderio», una busta per
##    «risposta», un pacchetto per «regalo» non sono oggetti di scena: sono
##    icone di interfaccia modellate in 3D, e dicono al giocatore che cosa
##    sta guardando. Un oggetto entra in scena SOLO se il giocatore quella
##    cosa l'ha tenuta in zampa da sveglio (la ciotola del pasto). Tutto il
##    resto è un cartello.
## 3. I GESTI NON SI COMPIONO. La ciotola si ferma a quattro centimetri e
##    resta lì sospesa; le zampe alzate non si toccano. Un gesto interrotto
##    è strutturalmente incapace di informare — e dice «non c'è più» nel
##    corpo, prima che nella testa.
## 4. NIENTE SEGNO AL RISVEGLIO. Niente filo dorato che punta al Prato
##    Eterno (sarebbe un waypoint), niente fiore acceso tutto il giorno
##    (sarebbe un marcatore su una tomba), niente riga in grassetto quando
##    sfogli la storia (sarebbe la schermata di riepilogo con una riga
##    evidenziata). L'unica conseguenza è INVISIBILE: `Legami.segna_sognato`,
##    e il ricordo non si pota più. Lo scopri cento giorni dopo.
## 5. IL SOGNO SBAGLIA. Un ricordo riprodotto senza errori non è un sogno:
##    è un replay, cioè un montaggio dei momenti migliori, cioè la forma
##    emotiva del riepilogo anche senza un numero a schermo. Qui il fiore
##    può stare sull'orecchio sbagliato, la taglia può essere quella di
##    quand'era più giovane di quanto sia mai stato, il colore può virare.
##    Costa una riga di scarto e trasforma un archivio in un sogno.
## 6. NESSUNO STACCO. Il sonno porta già la tenda a nero: nel nero si
##    spegne il mondo, poi la tenda scende senza che a schermo cambi
##    nulla — il nero del velo diventa il nero del mondo. Senza stacco non
##    c'è cornice; senza cornice non c'è cutscene.
##
## ============================================================
## LE QUATTRO GRAMMATICHE (non venti scene)
## ============================================================
## Ci sono ~20 tipi di momento in `Legami.TIPI` e sarebbe follia scrivere
## venti coreografie. Il corpo umano ne conosce quattro, e ogni tipo cade
## in una: stare ACCANTO, PORGERE qualcosa, CERCARSI, e il CONTATTO.
## Il tipo sceglie la grammatica; il resto lo fa la persona.
##
## ============================================================
## LE TRAPPOLE DEL MOTORE (verificate, non immaginate)
## ============================================================
##  · IL MONDO NON SI SPEGNE ABBASSANDO LE LUCI. `DayNight._apply()` gira
##    ogni frame e riscrive energia del sole, ambiente, nebbia, glow e
##    saturazione: qualunque cosa si scriva sull'Environment sparisce al
##    frame dopo. Si SOSTITUISCE la risorsa sul WorldEnvironment (DayNight
##    tiene il suo riferimento e continua a scrivere su quella vera, a
##    vuoto) e si spegne il sole con `visible = false`, che `_apply()` non
##    tocca. Al risveglio si rimette la risorsa vera e non c'è niente da
##    ripristinare.
##  · IL RIG GUARDA −Z. `ChibiBuilder` lo dichiara alla riga 11, e tutto il
##    gioco usa `atan2(-dir.x, -dir.z)`.
##  · `Legami.mostra_filo()` NON FUNZIONA per chi è partito: cicla su
##    `Visitors._residents`, da cui i partiti sono stati tolti, ed esce in
##    silenzio. Perciò il sogno NON mostra il filo rosso — e va bene così:
##    un nastro luminoso fra le zampe sarebbe un segno, e la regola 4 dice
##    che il sogno non ne lascia. Se un giorno lo si volesse, la strada è
##    `FiloRosso.annoda(mochi, <il corpo del sogno>, …)`, che chiede solo
##    due Node3D — ma oggi non è cablato, e questo commento diceva il
##    contrario.

const BUILDER := preload("res://scenes/npc/ChibiBuilder.gd")
const LEGAMI := preload("res://scenes/world/Legami.gd")
const DNA_GEN := preload("res://scenes/npc/ChibiDNA.gd")

# ------------------------------------------------------------- i tempi
## Quanto dura un sogno, dall'accendersi della lampada al suo spegnersi.
const DURATA := 7.6
## Il riconoscimento ha bisogno di tempo: prima del gesto, il corpo non fa
## NIENTE. Tagliare questo secondo fa partire il gesto prima che il
## giocatore capisca a chi appartiene.
const RICONOSCIMENTO := 1.0
## Quanto dura il gesto, e quanto resta il silenzio dopo.
const GESTO := 2.2
## Chi è partito SOPRAVVIVE alla luce di mezzo secondo: chi c'è ancora si
## spegne insieme alla lampada, chi non c'è più le resta addosso un
## istante. Nessuno lo spiega e non serve.
const SOPRAVVIVE := 0.55
## Quanto forte arde la lanterna. NON alzarlo: a un mezzo metro dal muso
## una lampada da 1.6 brucia la testona, gli occhi svaniscono nel bianco e
## la faccia si legge come una NUCA. È il difetto che ha imitato per
## quattro rese un errore di rotazione che non c'era.
const PIENA := 1.15
## Quanto avanti sta la lanterna, in multipli della profondità della testa.
const AVANTI := 0.95
## Le manopole che il provino spazzola (CHIBI_PROVLUCE): la messa in scena
## legge queste, non le costanti, così una taratura non chiede di
## ricompilare la scena a mano.
## Lo yaw di partenza del corpo del sogno: i gesti ci si appoggiano sopra
## in ASSOLUTO, o la posa deriva col framerate.
var _yaw_base := 0.0
var prov_energia := -1.0
var prov_avanti := -1.0

# ------------------------------------------------------------- le regole
## Mai due notti di fila: un sogno che arriva ogni volta diventa una
## schermata di fine giornata con un'altra faccia.
const RIPOSO_NOTTI := 2
## Quanto spesso, quando si può: non ogni notte utile.
const PROBABILITA := 0.62
## Quanto pesa chi è partito rispetto a un vicino ancora qui. Chi c'è
## ancora lo puoi vedere domani; chi è partito no.
const PESO_PARTITO := 4.0

# ------------------------------------------------------- le grammatiche
## Ogni tipo di momento cade in uno dei quattro modi che ha il corpo di
## stare con qualcuno. Non è una tabella di scene: è una tabella di VERBI.
const GRAMMATICA := {
	# stare seduti vicini, senza fare niente: è il verbo più difficile e il
	# più bello, ed è il ripiego giusto per tutto ciò che non ha un gesto
	"onsen": "accanto", "posto": "accanto", "promessa": "accanto",
	"benvenuto": "accanto", "trasloco": "accanto", "partenza": "accanto",
	"addio": "accanto", "nascita": "accanto", "battesimo": "accanto",
	# porgere qualcosa, e non finire mai di porgerlo
	"piatto": "porgere", "regalo": "porgere", "oro": "porgere",
	"desiderio": "porgere", "risposta": "porgere",
	# il reperto della Stratigrafia: il piccolo oggetto che chi è partito
	# ha lasciato alla terra — nel sogno lo si porge, non lo si spiega
	"reperto": "porgere",
	# cercarsi: uno si sporge da dietro qualcosa, e non esce mai del tutto
	"nascondino": "cercarsi", "prima_parola": "cercarsi",
	# il contatto: per mezzo secondo i due corpi sono una massa sola
	"primo_saluto": "contatto", "festa": "contatto",
}
const GRAMMATICA_DEFAULT := "accanto"

# ------------------------------------------------------------- lo stato

var _legami: Node
var _daynight: Node3D
var _visitors: Node
var _world_env: WorldEnvironment
var _sun: Node3D
var _moon: Node3D

## l'ultima notte in cui si è sognato, e chi
var _ultima_notte := -99
var _ultimo_chi := ""
var _quanti := 0

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("sogni")
	add_to_group("persistable")
	# uno solo per villaggio: il suo nome È la sua chiave.
	_rng = Dadi.rng(Dadi.VILLAGGIO, "sogni")
	_cabla()


## IL CABLAGGIO SI RIPROVA, e non è pignoleria: `Legami` (come il Regista)
## è un figlio RUNTIME di CozyWorld, creato durante la generazione differita
## del mondo. Un `call_deferred` nel `_ready` lo trova `null` — e un
## riferimento preso allora resta null per sempre: il sistema girerebbe a
## vuoto senza un errore, e la prima volta che te ne accorgi è guardando
## un sogno che non arriva mai. È già successo due volte in questo
## progetto: qui si riprova finché non c'è tutto, e poi la porta si chiude.
var _cablato := false

func _cabla() -> void:
	if _cablato:
		return
	if _legami == null:
		_legami = get_tree().get_first_node_in_group("legami")
	if _daynight == null:
		_daynight = get_node_or_null("../DayNight")
	if _visitors == null:
		_visitors = get_node_or_null("../Visitors")
	if _world_env == null:
		_world_env = get_node_or_null("../WorldEnvironment")
	if _sun == null:
		_sun = get_node_or_null("../Sun")
	_cablato = _legami != null and _daynight != null and _world_env != null


# ============================================================ la logica pura
# Tutto ciò che decide COSA si sogna è puro e si prova headless: quale filo,
# quale momento, quale grammatica. La messa in scena è un'altra cosa e si
# guarda con gli occhi.

## SI SOGNA STANOTTE? Puro. Mai due notti di fila, e non tutte le notti
## utili: l'attesa fa parte del dono.
static func si_sogna(notte: int, ultima: int, tiro: float) -> bool:
	if notte - ultima < RIPOSO_NOTTI:
		return false
	return tiro < PROBABILITA


## QUALE MOMENTO. Ed è qui che sta il cuore del sistema.
##
## `Legami` ha una potatura gentile: oltre trenta momenti il filo comincia
## a lasciar andare, e `indice_da_potare()` sa esattamente quale ricordo
## sacrificherebbe per primo — quello che lascia il buco più piccolo, del
## tipo meno raro. Il sogno va a prendere PROPRIO QUELLO.
##
## Così sognare non è una carezza narrativa: è il gesto che salva un
## ricordo dall'essere dimenticato. Su una partita lunga, i momenti che
## sopravvivono sono quelli che hai sognato — e nessuno te lo dice mai.
##
## `fili`: [{nome, momenti, partito}]. Ritorna {} se non c'è niente da
## sognare. PURA: niente nodi, niente tempo di gioco.
static func scegli(fili: Array, ultimo_chi: String, tiro: float) -> Dictionary:
	var pesati: Array = []
	var totale := 0.0
	for f in fili:
		var momenti: Array = (f as Dictionary).get("momenti", [])
		if momenti.is_empty():
			continue
		# E NEMMENO UN FILO GIA' TUTTO SOGNATO. Prima si estraeva comunque, e
		# se `indice_da_sognare` tornava -1 la notte era buttata: chi e'
		# partito pesa 4 contro 1 e il suo filo e' CONGELATO, quindi appena
		# esaurito quella quota di peso diventava silenzio — mentre i vivi
		# avevano ricordi freschi da salvare. Peggiorava con la partita.
		if indice_da_sognare(momenti) < 0:
			continue
		var nome := str((f as Dictionary).get("nome", ""))
		if nome == "":
			continue
		# chi è partito pesa di più: chi c'è ancora lo puoi vedere domani
		var peso := PESO_PARTITO if bool((f as Dictionary).get("partito", false)) else 1.0
		# e non due notti di seguito la stessa persona, se c'è altro
		if nome == ultimo_chi:
			peso *= 0.15
		pesati.append({"f": f, "peso": peso})
		totale += peso
	if pesati.is_empty():
		return {}
	var soglia := tiro * totale
	var scelto: Dictionary = (pesati[pesati.size() - 1] as Dictionary)["f"]
	var acc := 0.0
	for p in pesati:
		acc += float((p as Dictionary)["peso"])
		if acc >= soglia:
			scelto = (p as Dictionary)["f"]
			break
	var momenti: Array = scelto.get("momenti", [])
	var i := indice_da_sognare(momenti)
	if i < 0:
		return {}
	var m: Dictionary = momenti[i]
	return {
		"nome": str(scelto.get("nome", "")),
		"partito": bool(scelto.get("partito", false)),
		"indice": i,
		"tipo": str(m.get("t", "")),
		"giorno": int(m.get("d", 0)),
		"grammatica": grammatica_di(str(m.get("t", ""))),
	}


## IL RICORDO CHE STAVI PER PERDERE. Si chiede alla potatura stessa quale
## momento sacrificherebbe: quello è il sogno. Se il filo è ancora corto e
## non c'è niente in pericolo (`indice_da_potare` torna -1 quando è tutto
## intoccabile), si sogna il più vecchio che non sia già stato sognato —
## perché è quello che arriverà in pericolo per primo.
static func indice_da_sognare(momenti: Array) -> int:
	var i: int = LEGAMI.indice_da_potare(momenti)
	if i >= 0 and not (momenti[i] as Dictionary).has("sognato"):
		return i
	for k in momenti.size():
		if not (momenti[k] as Dictionary).has("sognato"):
			return k
	return -1


static func grammatica_di(tipo: String) -> String:
	return str(GRAMMATICA.get(tipo, GRAMMATICA_DEFAULT))


## IL DIRITTO DI SBAGLIARE. Un sogno fedele è un replay; i sogni sbagliano.
## Dato un DNA e un seme, torna il DNA del sogno: qualcosa è fuori posto —
## il fiore sull'orecchio sbagliato, una taglia di quando era più giovane
## di quanto sia mai stato, un colore che vira. Mai due cose insieme: due
## errori non sono un sogno, sono un altro personaggio.
##
## PURA, e testata: è la riga che separa un archivio da un sogno.
static func dna_sognato(dna: Dictionary, seme: int) -> Dictionary:
	var out := dna.duplicate(true)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("sogno|%d" % seme)
	match rng.randi() % 3:
		0:
			# più piccolo di quanto sia mai stato: è così che ci si ricorda
			# di qualcuno da tanto tempo fa
			out["size"] = float(dna.get("size", 1.0)) * rng.randf_range(0.86, 0.94)
		1:
			# IL COLORE VIRA DI UN NIENTE, e resta il suo. Il ricordo di un
			# colore non è il colore — ma schiarirlo verso il bianco (come
			# faceva la prima stesura, fino a 0.30) spegne l'unico canale
			# che dice CHI hai sognato, e un sogno irriconoscibile non è
			# commovente: è una dissolvenza colorata. Si scalda appena.
			var c := Color(str(dna.get("fur", "e8d5c4")))
			out["fur"] = c.lerp(Color(1.0, 0.86, 0.68), rng.randf_range(0.05, 0.11)) \
					.to_html(false)
		2:
			# le orecchie di un'altra età: nei sogni le persone hanno
			# l'aria che avevano quando le hai conosciute
			out["ear_ang"] = float(dna.get("ear_ang", 0.0)) + rng.randf_range(-0.22, 0.22)
	return out


# ============================================================ la serata

## I fili da cui si può sognare, nella forma che vuole `scegli()`.
func fili_sognabili() -> Array:
	_cabla()
	if _legami == null or not is_instance_valid(_legami):
		return []
	var out: Array = []
	for coppia in (_legami.call("partiti") as Array):
		var nome := str((coppia as Array)[0])
		out.append({"nome": nome, "partito": true,
				"momenti": _legami.call("momenti_di", nome)})
	if _visitors != null and is_instance_valid(_visitors):
		for r in (_visitors.get("_residents") as Array):
			var nome2 := str((r.get("dna", {}) as Dictionary).get("name", ""))
			if nome2 == "":
				continue
			out.append({"nome": nome2, "partito": false,
					"momenti": _legami.call("momenti_di", nome2)})
	return out


## IL SOGNO. Lo chiama `Interactions._sleep_until_morning` quando la tenda
## è già a nero. Torna quando il sogno è finito e il mondo è tornato
## esattamente com'era: chi lo chiama non deve sapere niente di tutto
## questo, deve solo poter proseguire col «Buongiorno».
func sogna(fade: ColorRect) -> void:
	_cabla()
	var notte := _notte()
	if not si_sogna(notte, _ultima_notte, _rng.randf()):
		return
	var s := scegli(fili_sognabili(), _ultimo_chi, _rng.randf())
	if s.is_empty():
		return
	_ultima_notte = notte
	_ultimo_chi = str(s["nome"])
	_quanti += 1
	await _metti_in_scena(s, fade)
	# ---- L'UNICA CONSEGUENZA, e non si vede. Il ricordo sognato esce
	# dalla portata della potatura gentile: da stanotte quel momento non si
	# perde più. Nessun toast, nessun fiore acceso, nessuna riga in
	# grassetto: lo scopri cento giorni dopo, rileggendo il filo.
	if _legami and _legami.has_method("segna_sognato"):
		_legami.call("segna_sognato", str(s["nome"]), int(s["indice"]))


func _notte() -> int:
	return int(_daynight.get("day")) if _daynight else 0


# ------------------------------------------------------------ la messa in scena

func _metti_in_scena(s: Dictionary, fade: ColorRect) -> void:
	# ---- IL MONDO SI SPEGNE, e non abbassando le luci: DayNight le
	# riscrive ogni frame. Si sostituisce la risorsa e si nasconde il sole.
	var env_vero: Environment = null
	if _world_env:
		env_vero = _world_env.environment
		_world_env.environment = _env_del_sogno()
	var sole_era := true
	if _sun:
		sole_era = _sun.visible
		_sun.visible = false

	# ---- IL MONDO SI FA DA PARTE. Nel sogno non c'è nessun altro: né i
	# vicini, né Mochi (la sua assenza è il punto), né UN SOLO pannello.
	# Con le barre dei bisogni in alto a sinistra e il contatore delle
	# noccioline in alto a destra, il sogno È una schermata di riepilogo —
	# solo con una grafica più bella. Si spengono tutti i CanvasLayer
	# TRANNE quello del velo, che è la nostra tenda.
	var nascosti := _fai_spazio(fade)

	var scena := Node3D.new()
	add_child(scena)
	var centro := _dove(s)

	# il corpo. Il DNA è quello vero conservato dal filo — passato però
	# dalla mano del sogno, che sbaglia sempre una cosa.
	var corpo := _corpo_del_sogno(s, centro)
	if corpo.is_empty():
		scena.queue_free()
		for n in nascosti:
			if is_instance_valid(n):
				(n as Node).set("visible", true)
		if _world_env and env_vero:
			_world_env.environment = env_vero
		if _sun:
			_sun.visible = sole_era
		return
	scena.add_child(corpo["nodo"])

	# la lanterna: l'unica sorgente, e l'unica cosa che respira per tutti
	var lampada := OmniLight3D.new()
	lampada.light_color = Color(1.0, 0.86, 0.63)
	lampada.light_energy = 0.0
	lampada.omni_range = 3.6
	lampada.omni_attenuation = 1.6
	lampada.shadow_enabled = true
	scena.add_child(lampada)
	# appesa sopra la testa, dall'ingombro vero: la luce deve ORLARE il
	# cranio, e a quota fissa su un chibi piccolo finirebbe dietro
	# LA LAMPADA NON VA A PICCO. Appesa sopra la testa illumina la calotta
	# e lascia il muso nero: a schermo si legge come una NUCA, ed è il
	# difetto che ha resistito a quattro rese di fila mentre cercavo un
	# errore di rotazione che non c'era. Va davanti e di lato, fra chi
	# guarda e la faccia — dove si terrebbe una lanterna per vedere
	# qualcuno in faccia.
	var t_luce := (corpo["parts"] as Dictionary).get("head") as Node3D
	var alto := _ingombro(t_luce) if t_luce else _ingombro(corpo["nodo"] as Node3D)
	var avanti := -(corpo["nodo"] as Node3D).global_transform.basis.z
	var lampada_base := alto.get_center() + avanti * (alto.size.z * 0.85) \
			* (prov_avanti if prov_avanti > 0.0 else AVANTI) \
			+ Vector3(0, alto.size.y * 0.62, 0)
	lampada.global_position = lampada_base

	# ---- LA CAMERA SI RICAVA DAL CORPO, non da numeri indovinati. Il chibi
	# del sogno ha una taglia che varia (lo scarto di `dna_sognato`), e i
	# genomi hanno teste e orecchie diverse: qualunque altezza scritta a
	# mano inquadra la nuca di qualcuno. Si misura l'ingombro VERO dalle
	# mesh e si inquadra quello — la faccia sta nel terzo alto, e la
	# distanza esce dal campo visivo, non dal gusto.
	var cam := Camera3D.new()
	cam.fov = 38.0
	scena.add_child(cam)
	# SI INQUADRA LA TESTA, non l'ingombro del corpo. L'ingombro misurato
	# del rig viene fuori 1.38 m alto e 1.08 largo — un chibi e' alto 0.9 e
	# largo mezzo metro: qualche mesh del rig porta un AABB gonfio, e il
	# «terzo alto» di quella scatola cadeva SOPRA la testa. La camera
	# guardava il cielo e in quadro restava la calotta del cranio.
	# La testa invece il builder la consegna per nome, e la sua scatola e'
	# piccola e onesta: da lei escono sia il punto in cui guardare sia la
	# distanza, e funziona per qualunque taglia — compreso lo scarto del
	# sogno.
	var testa_n := (corpo["parts"] as Dictionary).get("head") as Node3D
	var bt := _ingombro(testa_n) if testa_n else _ingombro(corpo["nodo"] as Node3D)
	var muso := bt.get_center()
	# la testa occupa circa un terzo dell'altezza del quadro: sotto ci sta
	# il corpo, sopra ci sta il buio
	var d := (bt.size.y * 2.15 * 0.5) / tan(deg_to_rad(cam.fov) * 0.5)
	var indietro := Vector3(sin(0.38), 0.0, cos(0.38)) * d
	cam.global_position = muso + indietro + Vector3(0, bt.size.y * 0.10, 0)
	cam.look_at(muso)


	var cam_prec := get_viewport().get_camera_3d()
	cam.current = true

	# ---- IL TAGLIO INVISIBILE: la tenda scende sul mondo già spento, e a
	# schermo non cambia niente. Il nero del velo diventa il nero del mondo.
	if fade:
		var t0 := create_tween()
		t0.tween_property(fade, "color:a", 0.0, 1.2).set_trans(Tween.TRANS_SINE)
	var t := 0.0
	var acceso := false
	while t < DURATA:
		var dt := get_process_delta_time()
		await get_tree().process_frame
		t += dt
		# la lampada sale, sta, e cala. E non è mai ferma: due orologi
		# incommensurabili che non si richiudono mai.
		var piena: float = prov_energia if prov_energia > 0.0 else PIENA
		var e := 0.0
		if t < 1.2:
			e = ease(clampf(t / 1.2, 0.0, 1.0), 0.4) * piena
		elif t > DURATA - 1.4:
			e = clampf((DURATA - t) / 1.4, 0.0, 1.0) * piena
		else:
			e = piena
		lampada.light_energy = e
		# l'oscillazione si SOMMA alla base: scrivere `position.x` da sola
		# spediva la lampada all'origine del mondo (la scena è a zero) e il
		# diorama restava al buio — tutto in silhouette, e non si capiva
		# perché. Due orologi incommensurabili, che non si richiudono mai.
		lampada.global_position = lampada_base + Vector3(
				sin(t * TAU / 5.3) * 0.045, 0.0, cos(t * TAU / 7.1) * 0.031)
		acceso = acceso or e > 0.1
		# la camera deriva: la testa sul cuscino
		cam.position += cam.global_transform.basis.z * -0.008 * dt
		cam.rotation.z = sin(t * TAU / 9.7) * 0.006
		_anima(corpo, s, t)
	# ---- CHI È PARTITO SOPRAVVIVE ALLA LUCE. Le mesh restano visibili
	# mezzo secondo dopo che la lampada si è spenta, tenute su da un
	# materiale che si spegne più tardi: chi c'è ancora se ne va con la
	# luce, chi non c'è più le resta addosso.
	if bool(s.get("partito", false)):
		await _sopravvive(corpo)

	# ---- si richiude, e il mondo torna esatto: non c'è niente da
	# ripristinare, perché non è stato scritto niente.
	if fade:
		var t1 := create_tween()
		t1.tween_property(fade, "color:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)
		await t1.finished
	for n in nascosti:
		if is_instance_valid(n):
			(n as Node).set("visible", true)
	if cam_prec and is_instance_valid(cam_prec):
		cam_prec.current = true
	if _world_env and env_vero:
		_world_env.environment = env_vero
	if _sun:
		_sun.visible = sole_era
	scena.queue_free()


## L'ingombro VERO di un corpo, dai vertici delle sue mesh. Le misure a
## occhio mentono, e con una taglia che varia mentono ogni volta in modo
## diverso.
func _ingombro(n: Node3D) -> AABB:
	var out := AABB()
	var primo := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var a := m.global_transform * m.mesh.get_aabb()
		if primo:
			out = a
			primo = false
		else:
			out = out.merge(a)
	return out


## Tutto ciò che va spento perché il sogno sia un sogno. Torna la lista di
## chi era visibile, così si riaccende esattamente quello — e nient'altro.
##
## Il velo del sonno vive su un CanvasLayer suo (livello 10) e NON va
## toccato: è la tenda su cui il sogno si apre. `PhotoMode._hide_ui()`
## invece lo spegnerebbe insieme agli altri, ed è per questo che non si
## riusa qui.
func _fai_spazio(fade: ColorRect) -> Array:
	var out: Array = []
	var tenda: Node = fade.get_parent() if fade else null
	var radice := get_tree().root
	for n in radice.find_children("*", "CanvasLayer", true, false):
		if n == tenda or not (n as CanvasLayer).visible:
			continue
		(n as CanvasLayer).visible = false
		out.append(n)
	# Mochi: nel sogno l'assenza sei tu, e vederti lì accanto la
	# smentirebbe. (Ed è anche la grammatica che il gioco ha già insegnato:
	# la luce additiva È chi non c'è più — darla a Mochi la capovolgerebbe.)
	var pl := get_tree().get_first_node_in_group("player_controller")
	if pl and is_instance_valid(pl) and (pl as Node3D).visible:
		(pl as Node3D).visible = false
		out.append(pl)
	# IL VILLAGGIO. Si dorme dentro una casa, e nella prima resa una parete
	# riempiva mezzo quadro: il sogno era ambientato in camera da letto. E
	# nasconderlo non è un rimedio tecnico — in un sogno non c'è nient'altro
	# che voi due, e tutto quello che hai costruito non c'entra niente.
	var bs := get_tree().get_first_node_in_group("build_system")
	if bs:
		var radice_pezzi := bs.get("_placed_root") as Node3D
		if radice_pezzi and is_instance_valid(radice_pezzi) and radice_pezzi.visible:
			radice_pezzi.visible = false
			out.append(radice_pezzi)
	# e i vicini vivi: nel sogno c'è una persona sola
	if _visitors:
		for r in (_visitors.get("_residents") as Array):
			var n2 := r.get("node") as Node3D
			if n2 and is_instance_valid(n2) and n2.visible:
				n2.visible = false
				out.append(n2)
	return out


## L'Environment del sogno: nero oltre tre metri, la luce che sbava sui
## bordi, e il colore che c'è ma è RICORDATO, non visto.
func _env_del_sogno() -> Environment:
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.012, 0.012, 0.028)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.06, 0.055, 0.08)
	e.ambient_light_energy = 0.30
	e.fog_enabled = true
	e.fog_light_color = Color(0.015, 0.015, 0.035)
	e.fog_density = 0.62
	e.glow_enabled = true
	e.glow_intensity = 0.85
	e.glow_bloom = 0.10
	e.adjustment_enabled = true
	e.adjustment_saturation = 0.90
	return e


## Dove si accende la lampada. Non è il posto vero del ricordo (il gioco
## non lo conserva), ed è giusto così: un sogno non ha coordinate. Si sta
## in un fazzoletto di prato accanto a Mochi che dorme, e il buio fa il
## resto — dichiararlo qui evita di far finta che il LUOGO sia un canale.
func _dove(_s: Dictionary) -> Vector3:
	var pl := get_tree().get_first_node_in_group("player_controller")
	if pl and is_instance_valid(pl):
		return (pl as Node3D).global_position + Vector3(0.9, 0.0, 0.9)
	return Vector3.ZERO


func _corpo_del_sogno(s: Dictionary, centro: Vector3) -> Dictionary:
	var nome := str(s["nome"])
	var ricordato: Dictionary = {}
	if _legami:
		ricordato = _legami.call("dna_ricordo", nome)
	if ricordato.is_empty() and _visitors:
		for r in (_visitors.get("_residents") as Array):
			if str((r.get("dna", {}) as Dictionary).get("name", "")) == nome:
				ricordato = (r.get("dna", {}) as Dictionary).duplicate(true)
				break
	# ---- CIÒ CHE NON RICORDI, IL SOGNO SE LO INVENTA. Il DNA conservato
	# nel filo è parziale (i salvataggi vecchi ne hanno solo qualche campo,
	# e il fiore ne porta due o tre), e `ChibiBuilder` vuole un genoma
	# intero: senza, il corpo non si costruisce affatto. Si parte da un
	# genoma completo generato dal NOME — così è sempre lo stesso, sogno
	# dopo sogno — e ci si scrive sopra quel che il filo ricorda davvero.
	# Non è un ripiego tecnico: è esattamente come funziona ricordare
	# qualcuno, e infatti i dettagli inventati sono quelli che non contano.
	var dna: Dictionary = DNA_GEN.generate(hash(nome))
	for k in ricordato:
		dna[k] = ricordato[k]
	dna["name"] = nome
	# IL DIRITTO DI SBAGLIARE
	dna = dna_sognato(dna, hash(nome) + int(s.get("giorno", 0)))
	var parts: Dictionary = BUILDER.build(dna)
	if not parts.has("root"):
		return {}
	var nodo := Node3D.new()
	nodo.add_child(parts["root"])
	nodo.position = centro
	# rivolta a chi guarda: il rig del builder guarda −Z, e la camera sta
	# indietro di 0.38 rad attorno a Y
	nodo.rotation.y = 0.38 + PI
	_yaw_base = nodo.rotation.y
	return {"nodo": nodo, "parts": parts}


## IL RESPIRO, e i gesti che non si compiono. Non c'è una coreografia per
## ogni tipo: c'è un respiro sempre, e sopra ci si posa il verbo.
func _anima(corpo: Dictionary, s: Dictionary, t: float) -> void:
	if corpo.is_empty():
		return
	var parts: Dictionary = corpo["parts"]
	var testa := parts.get("head") as Node3D
	# IL RESPIRO ASIMMETRICO: inspiro corto, espiro lungo. E la rotazione
	# della testa arriva 0.15 s DOPO la traslazione — è quel ritardo che
	# dà peso al cranio. Un sin() puro si smaschera in due cicli.
	if testa:
		var f := fposmod(t / 4.1, 1.0)
		var alt := ease(clampf(f / 0.38, 0.0, 1.0), 0.5) if f < 0.38 \
				else 1.0 - ease(clampf((f - 0.38) / 0.62, 0.0, 1.0), 0.6)
		testa.position.y = alt * 0.012
		testa.rotation.x = sin((t - 0.15) * TAU / 4.1) * 0.021
	var orecchie: Array = parts.get("ears", [])
	for k in orecchie.size():
		var o := orecchie[k] as Node3D
		if o:
			# la molla, sfasata fra le due: mai simmetriche
			o.rotation.z = sin((t - 0.22) * TAU / 4.1 + float(k) * 0.7) * 0.035
	var coda := parts.get("tail") as Node3D
	if coda:
		coda.rotation.y = sin(t * TAU / 6.7) * 0.13

	# ---- IL VERBO. Comincia dopo il riconoscimento: prima, il corpo non
	# fa NIENTE, e quel secondo è il tempo che ci vuole a capire chi è.
	if t < RICONOSCIMENTO:
		return
	var u := clampf((t - RICONOSCIMENTO) / GESTO, 0.0, 1.0)
	var braccia: Array = parts.get("arms", [])
	match str(s.get("grammatica", GRAMMATICA_DEFAULT)):
		"porgere":
			# SI PORGE, E NON SI FINISCE MAI DI PORGERE: il braccio arriva
			# quasi in fondo e resta lì. Un gesto compiuto consegnerebbe
			# un oggetto, cioè un'informazione.
			var a := ease(u, 0.35) * 0.62 * (1.0 - 0.12 * u)
			for b in braccia:
				(b as Node3D).rotation.x = -a
			if testa:
				testa.rotation.x += a * 0.14
		"cercarsi":
			# si sporge, e non esce mai del tutto
			# ASSOLUTO, non `+=`: era l'unico incremento su un canale la
			# cui base non viene riscritta, dentro una funzione chiamata una
			# volta per FRAME. La deriva misurata andava da 9,6° a 30 fps a
			# 46° a 144 — e in un primo piano dove le parole sono vietate il
			# corpo e' l'unico canale che dice CHI hai sognato.
			(corpo["nodo"] as Node3D).rotation.y = _yaw_base + sin(u * PI) * 0.06
			if testa:
				testa.rotation.y = sin(u * PI) * 0.28
		"contatto":
			# per mezzo secondo i corpi sono una massa sola: qui è il
			# corpo che si china verso la lampada e la eclissa
			var c := sin(clampf(u * 1.4, 0.0, 1.0) * PI)
			corpo["nodo"].position.y = -c * 0.05
			for b in braccia:
				(b as Node3D).rotation.x = -c * 0.5
		_:
			# ACCANTO: il verbo più difficile. Non fa niente, e si vede che
			# non lo fa insieme a qualcuno — si assesta appena, come chi
			# sta comodo accanto a una persona.
			if testa:
				testa.rotation.z = sin(u * PI) * 0.05


## Le mesh restano un istante dopo la luce. Si spengono da sole,
## dissolvendo un materiale additivo: la presenza è fatta di luce.
func _sopravvive(corpo: Dictionary) -> void:
	var root := (corpo["parts"] as Dictionary)["root"] as Node3D
	var resta := StandardMaterial3D.new()
	resta.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	resta.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	resta.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	resta.albedo_color = Color(0.98, 0.9, 0.72, 0.34)
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = resta
	var tw := create_tween()
	tw.tween_property(resta, "albedo_color:a", 0.0, SOPRAVVIVE) \
			.set_trans(Tween.TRANS_SINE)
	await tw.finished


# ============================================================ persistenza

func save_extra() -> Dictionary:
	return {"sogni": {"ultima": _ultima_notte, "chi": _ultimo_chi, "n": _quanti}}


func load_extra(data: Dictionary) -> void:
	var d: Variant = data.get("sogni")
	if d is not Dictionary:
		return
	_ultima_notte = int((d as Dictionary).get("ultima", -99))
	_ultimo_chi = str((d as Dictionary).get("chi", ""))
	_quanti = int((d as Dictionary).get("n", 0))


# ============================================================ debug CLI

func debug_stato() -> Dictionary:
	return {"ultima": _ultima_notte, "chi": _ultimo_chi, "n": _quanti,
			"fili": fili_sognabili().size()}


## Forza un sogno adesso, saltando il dado: serve all'harness per guardarlo.
func debug_sogna_ora(fade: ColorRect) -> Dictionary:
	_cabla()
	var s := scegli(fili_sognabili(), "", _rng.randf())
	if s.is_empty():
		return {}
	await _metti_in_scena(s, fade)
	if _legami and _legami.has_method("segna_sognato"):
		_legami.call("segna_sognato", str(s["nome"]), int(s["indice"]))
	return s
