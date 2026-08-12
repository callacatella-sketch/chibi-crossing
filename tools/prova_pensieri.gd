extends SceneTree
## LA PROVA VIVA DELLA FASE 5 — il modello acceso, dentro il gioco vero.
##
##   CHIBI_MODELLO=/percorso/al.gguf CHIBI_PENSIERI=/dove/mettere/le/foto \
##     ~/Downloads/Godot.app/Contents/MacOS/Godot --path . \
##     --script res://tools/prova_pensieri.gd
##
## (senza `--headless`: le foto vogliono un renderer. Con `--headless` gira
## lo stesso e stampa tutto, ma non scatta niente — ed è metà del lavoro.)
##
## ────────────────────────────────────────────────────────────────────────
## PERCHÉ ESISTE, E COSA NESSUNA ASSERZIONE PUÒ DIRE
## ────────────────────────────────────────────────────────────────────────
##
## La Fase 5 ha quattro banchi di prova, e ognuno prova una cosa che la suite
## non sa dire: `misura_pensieri` dice quanto costa al frame, `prova_giudice`
## dice quanto spesso il giudice tace, `prova_deduzione` dice se la scena si
## legge, `prova_identico` dice che senza il modello non cambia niente. Tutti
## e quattro, però, provano UN PEZZO — e tre su quattro lo provano **senza il
## modello**, con bozze scritte a mano.
##
## Questo è l'unico posto in cui il modello vero scrive dentro il villaggio
## vero, e si guarda cosa succede. Le domande sono cinque, e non se ne può
## fare nessuna con un `assert`:
##
##  1. **cosa legge il modello?** Il prompt in partita è invisibile per
##     definizione. Qui si stampa per esteso, com'è, senza riassunti.
##  2. **cosa scrive?** TUTTE le bozze, non la vincitrice: lo scarto è il
##     lavoro del giudice, e un banco che stampa solo chi ha vinto racconta
##     una gara senza gli altri corridori.
##  3. **cosa entra nel mondo?** La deduzione che diventa un nodo del grafo,
##     con l'obiettivo che ne esce.
##  4. **cosa fa il CORPO, e cosa vede il giocatore?** La ricevuta — la testa
##     che si gira — fotografata prima e durante, dalla stessa macchina: una
##     posa non si giudica in un fotogramma, e una differenza non si giudica
##     su due inquadrature diverse.
##  5. **con che RITMO?** Ogni quanto un vicino pensa, quante bozze si
##     buttano, e quanto spesso l'esito è il silenzio — che deve essere un
##     esito frequente e legittimo, non un guasto.
##
## ────────────────────────────────────────────────────────────────────────
## LE SCELTE DI BANCO, e ognuna è una rinuncia dichiarata
## ────────────────────────────────────────────────────────────────────────
##
##  · **TRE VICINI, NON VENTOTTO.** Il costo sul frame l'ha già misurato
##    `misura_pensieri` col villaggio pieno; qui interessa il CONTENUTO, e
##    ventotto vicini vorrebbero dire ventotto minuti di attesa per vedere
##    la seconda lettera. Il ritmo che questo banco misura è perciò il
##    **pavimento** (quanto ci mette UNA generazione), non la cadenza di una
##    partita vera: quella si ricava da lì con `Pensatoio.attesa_stimata`, e
##    si stampa in fondo.
##  · **DUE PENSATOI, uno per le lettere e uno per le deduzioni.** Non è un
##    doppione: `RIPOSO` tiene fermo per cinque minuti chi ha appena
##    pensato, e con tre vicini il secondo atto aspetterebbe un orologio che
##    in un villaggio vero è riempito dagli altri venticinque. Il ritmo che
##    si misura resta quello del primo, che non salta niente.
##  · **IL CORPO SI POSA E SI GIRA A MANO** prima della ricevuta (una
##    posizione e un'imbardata: due cose che il gioco produce di continuo).
##    Serve a poter scattare la stessa inquadratura PRIMA e DOPO — che è
##    l'unico modo di far vedere una testa che si gira. `prova_deduzione`
##    invece lo lascia gironzolare, ed è giusto così: lì si misura se la
##    ricevuta si paga da sola, qui se si VEDE.
##  · **NIENTE DADO DEL BANCO.** I semi dei pensieri sono derivati
##    dall'etichetta del vicino e dal numero del giro: due corse dello stesso
##    banco chiedono al modello le stesse cose. Quello che cambia è la
##    macchina.

const FOGLIO := preload("res://scenes/npc/FoglioDelVicino.gd")
const PENSATOIO := preload("res://scenes/npc/Pensatoio.gd")
const GIUDICE := preload("res://scenes/npc/Giudice.gd")
const DED := preload("res://scenes/npc/Deduzioni.gd")
const SUG := preload("res://scenes/npc/Suggeritore.gd")
const PERCEZIONE := preload("res://scenes/npc/Percezione.gd")
const VISITOR := preload("res://scenes/npc/Visitor.gd")
const LLM := preload("res://systems/Llm.gd")

# ---------------------------------------------------------------- il villaggio

## Tre case, tre vicini. Le celle sono distanti abbastanza che i tre gesti di
## Mochi non li vedano tutti (il raggio della percezione è nove metri): un
## villaggio in cui tutti hanno visto tutto è il caso più facile, e i tre
## prompt uscirebbero uguali.
##
## ⚠️ LE CELLE NON SI SCELGONO A MEMORIA: il letto del fiume rifiuta ogni
## pezzo (`place_cell`), in silenzio, e un `debug_settle` su una cella
## rifiutata non insedia nessuno — il banco parte con due vicini invece di
## tre e non lo dice. Queste sono state provate una per una; chi le sposta
## ricontrolli che i letti posati siano tre.
const CASE := [Vector2i(2, 4), Vector2i(14, 4), Vector2i(4, 15)]

## ⚠️ LE DUE GEOMETRIE, ED È IL CUORE DI QUESTO BANCO.
##
## La ricevuta della deduzione punta il posto di un RICORDO
## (`EcsMondo::deduzione_dove`); il corpo, dopo, va dove lo manda la messa in
## scena dell'obiettivo (`Visitors._free_bench`, `_aiuola_da_curare`). Sono
## due posti diversi, e **coincidono solo se il mondo li ha messi vicini** —
## la nota di consegna dell'injection lo dichiara come residuo, ma nessuno
## l'aveva ancora VISTO in scena.
##
## Perciò qui il villaggio è costruito apposta per fare la prova affiancata,
## che è l'unico modo di giudicare una cosa che si guarda:
##
##  · **VICINO 0 — la premessa LONTANA dalla meta.** Mochi annaffia in mezzo
##    al prato, dove non c'è niente: qualunque cosa deduca, il posto in cui
##    va è da un'altra parte (il cespuglio a 10 m, la panchina a 9).
##  · **VICINO 1 — la premessa NEL posto della meta.** Mochi gli porta un
##    piatto proprio davanti alla panchina di casa sua. Guarda lì, e lì va.
##
## Stessa fase, stesso codice, due mondi: la differenza che si vede nelle
## foto è tutta del mondo.
const GESTO_LONTANO := Vector2i(1, 8)     # per il vicino 0: prato nudo
const CESPUGLIO := Vector2i(12, 9)
const PANCA_LONTANA := Vector2i(9, 13)    # 9.4 m dal ricordo del vicino 0
const PANCA_VICINA := Vector2i(12, 7)     # per il vicino 1: È il suo ricordo

## Il centro del villaggio costruito: serve a posare il corpo dalla parte
## buona (vedi `_posa_buona`), non dentro il fiume.
const CENTRO := Vector3(7.0, 0.0, 9.0)

## `Visitors.AMMIRA_SOGLIA`: quanto deve pesare un ricordo perché il
## villaggio lo consideri ancora vivo. Si legge di là, non si sceglie qui.
const SOGLIA := 0.35

## ⚠️ **DOVE STA MOCHI MENTRE IL VICINO PAGA LA RICEVUTA**, e questa riga è
## cambiata di segno.
##
## Diceva: LONTANO — «se Mochi fosse nell'inquadratura, chi guarda la foto
## leggerebbe *sta guardando lei*». La foto usciva più pulita, e il banco
## misurava una scena che in partita non succede: **la ricevuta non si paga a
## chi non ha nessuno che lo guardi** (`Deduzioni.RAGGIO`), e in partita la
## camera sta addosso a Mochi — se lei non c'è, quella testa non la vede
## nessuno.
##
## Adesso Mochi resta a `MOCHI_GUARDA_DA` metri dal vicino, **dalla parte
## opposta all'ancora**: dentro il raggio perché la ricevuta si paghi, e
## fuori dalla linea di sguardo perché la testa non si legga come rivolta a
## lei. Le due condizioni non sono in conflitto — sono la scena vera.
const MOCHI_GUARDA_DA := 3.2

## DOVE STA MOCHI ADESSO. Senza giocatore (non capita nel MainLevel) si
## risponde con un punto impossibile, così `_si_vede` dice NO invece di
## mentire.
func _dove_mochi() -> Vector3:
	if _player == null or not is_instance_valid(_player):
		return Vector3(1e6, 0.0, 1e6)
	return _player.global_position


## LA DOMANDA VERA DELLA RICEVUTA, la stessa che fa `Deduzioni.consegna`:
## il corpo si può guardare **e** c'è qualcuno a guardarlo.
func _si_vede(corpo: Node3D) -> bool:
	return PERCEZIONE.puo_vedere(corpo, _dove_mochi(), DED.RAGGIO)


## MOCHI SI METTE A GUARDARE: dentro il raggio della ricevuta, dalla parte
## opposta all'ancora. Vedi `MOCHI_GUARDA_DA`.
func _mochi_guarda(dove_lui: Vector3, ancora: Vector3) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var indietro: Vector3 = dove_lui - ancora
	indietro.y = 0.0
	indietro = indietro.normalized() if indietro.length() > 0.01 else Vector3.FORWARD
	var p: Vector3 = dove_lui + indietro * MOCHI_GUARDA_DA
	_player.global_position = Vector3(p.x, _player.global_position.y, p.z)


## LA POSA DELLA RICEVUTA. Sei metri dal posto guardato: dentro il raggio
## della percezione, e abbastanza lontano che nell'inquadratura larga ci
## stiano tutti e due — il vicino e la cosa che guarda.
const POSA_DISTANZA := 6.0
## DI QUANTO DEVE MANCARE LA TESTA, prima che la ricevuta si paghi. Sotto il
## tetto del collo (`Visitor.tetto_ricevuta()`, 44°) perché la ricevuta si
## possa pagare, ma non zero: una testa che si gira di zero gradi non è una
## scena, ed è quello che il giocatore vedrebbe.
##
## ⚠️ NON SI IMPOSTA L'IMBARDATA E BASTA, e la prima stesura di questo banco
## sbagliava proprio qui: si girava il corpo di 36° e si misurava una testa
## già **sul bersaglio**, perché il collo aveva un suo scostamento addosso
## (la mira personale, l'ondeggio dell'inattività, il residuo di uno sguardo
## di prima). La foto «prima» usciva identica alla foto «dopo» — cioè il
## banco fotografava una ricevuta che non c'era, e con la luce verde. Si
## MISURA il muso e si corregge finché ci si arriva: vedi `_punta`.
const POSA_SCARTO := 0.52

# ------------------------------------------------------------------- le foto

## Le tre inquadrature. Gli angoli sono presi dal MUSO del corpo (il rig
## guarda −Z) e ruotati verso il lato in cui la testa si girerà: da lì si vede
## l'angolo fra le spalle e il muso, che È la ricevuta. Provinati guardando
## le immagini, non scelti a memoria.
const TRE_QUARTI_ANGOLO := 0.62   # ~35° dalla linea di sguardo: la faccia
const PROFILO_ANGOLO := 1.57      # 90°: la sagoma, dove l'angolo si misura
const SPALLA_ANGOLO := 0.42       # ~24° dietro: l'inquadratura oltre la testa
const OCCHIO_DIST := 2.05
const OCCHIO_ALTEZZA := 0.62
const SPALLA_DIST := 1.55
const SPALLA_ALTEZZA := 0.78
const FOV_STRETTO := 42.0
const FOV_LARGO := 55.0

var _dove := ""
var _cam: Camera3D = null
var _scatti := 0

# ------------------------------------------------------------------ lo stato

var _vis: Node = null
var _build: Node = null
var _dn: Node = null
var _mondo_nodo: Node = null
var _player: Node3D = null
var _cuore: Object = null
var _llm: Object = null
var _pens: RefCounted = null
var _residenti: Array = []
var _guasti := 0

# la memoria del giudice: cosa ha già detto lui, cosa ha già detto il villaggio
var _memoria_sue := {}
var _memoria_villaggio := []

# il registro del ritmo
var _t0 := 0
var _lettere := 0
var _silenzi := 0
var _bozze_tot := 0
var _bozze_ammesse := 0
var _porte := {}
var _durate := []
var _gram_vista := {}
var _in_attesa := false
var _copie := 0


func _init() -> void:
	_go()


func _dico(ok: bool, testo: String) -> void:
	if not ok:
		_guasti += 1
	print(("  ok      " if ok else "  GUASTO  ") + testo)


func _t() -> float:
	return float(Time.get_ticks_msec() - _t0) / 1000.0


func _mondo(c: Vector2i) -> Vector3:
	return Vector3(c.x, 0.0, c.y)


func _riquadro(titolo: String, corpo: String) -> void:
	print("┌── %s %s" % [titolo, "─".repeat(maxi(4, 66 - titolo.length()))])
	for riga in corpo.split("\n"):
		print("│ " + str(riga))
	print("└" + "─".repeat(70))


# =========================================================================
# LE FOTO
# =========================================================================

## UNO SCATTO. Costa qualche frame (la camera si muove, e il disegno viene
## dopo `_process`): si aspetta `frame_post_draw` due volte, che è l'idioma
## già pagato dagli altri provini — il primo `save` prenderebbe il frame
## PRECEDENTE.
func _scatta(nome: String, occhio: Vector3, centro: Vector3, fov: float) -> void:
	if _dove == "" or _cam == null:
		return
	_cam.fov = fov
	_cam.global_position = occhio
	_cam.look_at(centro, Vector3.UP)
	await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_root().get_texture().get_image()
	img.save_jpg(_dove.rstrip("/") + "/" + nome + ".jpg", 0.93)
	_scatti += 1


## LE QUATTRO MACCHINE, calcolate UNA volta e riusate: prima e dopo devono
## essere la stessa inquadratura, o la differenza che si vede è quella della
## camera. Torna [larga, tre_quarti, profilo, spalla].
##
## ⚠️ **GLI ANGOLI SI PRENDONO DALLA LINEA DI SGUARDO (corpo → ancora), NON
## DAL MUSO DEL CORPO**, e la differenza è tutta la leggibilità di queste
## foto. La prima taratura li prendeva da `-basis.z` del corpo: il «profilo»
## a 95° finiva **dietro la nuca**, perché il corpo è già girato di trenta
## gradi rispetto a quello che conta. La linea di sguardo invece è la stessa
## nei tre momenti, quindi la stessa macchina vuol dire la stessa domanda:
##
##  · **tre quarti** — la faccia: si vede DOVE guarda;
##  · **profilo** — a 90° dalla linea di sguardo: si vede l'ANGOLO fra le
##    spalle e il muso, che è la ricevuta;
##  · **spalla** — da dietro, oltre la testa: nello stesso fotogramma ci
##    sono il vicino E la cosa che guarda. È l'inquadratura che risponde
##    alla domanda vera, e nessuna delle altre lo fa.
##
## ⚠️ E una trappola di MISURA, pagata qui: una giostra di otto azimut
## scattata DURANTE il movimento non risponde alla domanda «da che parte si
## vede meglio» — a 45° si vedeva la faccia, a 90° la nuca, a 315° di nuovo
## la faccia. Non è l\'angolo: fra uno scatto e l\'altro la testa si è mossa.
## Una giostra si guarda a movimento finito, o confonde l\'angolo col tempo.
func _macchine(corpo: Node3D, bersaglio: Vector3) -> Array:
	var testa := _testa(corpo)
	var avanti: Vector3 = -corpo.global_transform.basis.z
	avanti.y = 0.0
	avanti = avanti.normalized() if avanti.length() > 0.001 else Vector3.FORWARD
	var verso: Vector3 = bersaglio - corpo.global_position
	verso.y = 0.0
	verso = verso.normalized() if verso.length() > 0.001 else avanti
	# DA CHE PARTE STA IL CORPO rispetto alla linea di sguardo: la macchina va
	# di là, o le spalle escono schiacciate contro il muso.
	var lato: float = signf(verso.cross(avanti).y)
	if absf(lato) < 0.5:
		lato = 1.0
	var alto := Vector3(0.0, OCCHIO_ALTEZZA, 0.0)
	var d34: Vector3 = verso.rotated(Vector3.UP, TRE_QUARTI_ANGOLO * lato)
	var dpr: Vector3 = verso.rotated(Vector3.UP, PROFILO_ANGOLO * lato)
	var dsp: Vector3 = -verso.rotated(Vector3.UP, SPALLA_ANGOLO * lato)

	# LA LARGA inquadra tutti e due — il vicino e la cosa che guarda — perché
	# è la sola foto in cui si legge il RAPPORTO fra i due, che è quello che
	# la ricevuta racconta. Si mette di lato alla loro congiungente.
	var mezzo: Vector3 = (corpo.global_position + bersaglio) * 0.5
	var span: float = corpo.global_position.distance_to(bersaglio)
	var fianco: Vector3 = verso.rotated(Vector3.UP, PI * 0.5) * lato
	var occhio_l: Vector3 = mezzo + fianco * (span * 0.80 + 2.0) \
			+ Vector3(0.0, span * 0.40 + 1.8, 0.0)

	return [
		{"occhio": occhio_l, "centro": mezzo + Vector3(0.0, 0.35, 0.0), "fov": FOV_LARGO},
		{"occhio": testa + d34 * OCCHIO_DIST + alto, "centro": testa, "fov": FOV_STRETTO},
		{"occhio": testa + dpr * OCCHIO_DIST + alto, "centro": testa, "fov": FOV_STRETTO},
		# la spalla guarda OLTRE la testa: il centro non è il vicino, è il
		# punto a mezza strada fra lui e quello che sta guardando
		{"occhio": testa + dsp * SPALLA_DIST + Vector3(0.0, SPALLA_ALTEZZA, 0.0),
				"centro": testa + verso * (span * 0.55), "fov": FOV_LARGO},
	]


## LA GIOSTRA: lo stesso istante da otto azimut, a passi di 45°. Serve a
## SCEGLIERE gli angoli guardando, invece di dedurli — «il rig guarda −Z» è
## vero per la logica, ma quale angolo faccia leggere una testa girata non lo
## dice nessuna formula (la prima taratura di questo banco metteva il
## «profilo» dietro la nuca). Si accende con CHIBI_GIOSTRA=1 e si spegne
## quando gli angoli sono scelti.
func _giostra(prefisso: String, corpo: Node3D) -> void:
	var testa := _testa(corpo)
	var avanti: Vector3 = -corpo.global_transform.basis.z
	avanti.y = 0.0
	avanti = avanti.normalized() if avanti.length() > 0.001 else Vector3.FORWARD
	for k in 8:
		var dir: Vector3 = avanti.rotated(Vector3.UP, float(k) * PI * 0.25)
		await _scatta("%s_%03d" % [prefisso, k * 45],
				testa + dir * OCCHIO_DIST + Vector3(0, OCCHIO_ALTEZZA, 0),
				testa, FOV_STRETTO)


func _terna(prefisso: String, macchine: Array) -> void:
	var nomi := ["larga", "tre_quarti", "profilo", "spalla"]
	for i in macchine.size():
		var m: Dictionary = macchine[i]
		await _scatta("%s_%s" % [prefisso, nomi[i]], m["occhio"], m["centro"], m["fov"])


## LA PELLICOLA: la stessa macchina, tanti fotogrammi. Un movimento non si
## giudica in una posa — la regola è del progetto, e la testa che si gira è
## esattamente il caso per cui è stata scritta.
func _pellicola(prefisso: String, m: Dictionary, quanti: int, passo: float,
		corpo: Node3D, bersaglio: Vector3) -> void:
	for k in quanti:
		await _scatta("%s_%02d" % [prefisso, k], m["occhio"], m["centro"], m["fov"])
		print("        · fotogramma %d a t=%.2f — scarto della testa %.1f°"
				% [k, _t(), rad_to_deg(_scarto(corpo, bersaglio))])
		var fine := Time.get_ticks_msec() + int(passo * 1000.0)
		while Time.get_ticks_msec() < fine:
			await process_frame


# =========================================================================
# LE MISURE DEL CORPO — le stesse di `prova_deduzione`, e per la stessa
# ragione: si misura il MUSO, non un angolo interno. È quello che si vede.
# =========================================================================

func _testa(corpo: Node3D) -> Vector3:
	var t = corpo.get("_head")
	if t != null and is_instance_valid(t):
		return (t as Node3D).global_position
	return corpo.global_position + Vector3(0.0, 0.55, 0.0)


func _collo(corpo: Node3D) -> float:
	var t = corpo.get("_head")
	if t == null or not is_instance_valid(t):
		return 0.0
	return wrapf(float((t as Node3D).rotation.y), -PI, PI)


func _scarto(corpo: Node3D, bersaglio: Vector3) -> float:
	return absf(_scarto_segnato(corpo, bersaglio))


## DI QUANTO IL MUSO MANCA IL BERSAGLIO, **col segno**: quanto bisognerebbe
## girare la testa (attorno a Y, verso positivo) perché ci arrivi.
##
## Il segno non è un ornamento: senza, `_punta` non converge — corregge
## sempre nello stesso verso e finisce a mezzo giro dal bersaglio, con la
## luce verde. È successo alla seconda stesura di questo banco: la posa
## dichiarava 0.8° e la testa guardava dall'altra parte.
func _scarto_segnato(corpo: Node3D, bersaglio: Vector3) -> float:
	var t = corpo.get("_head")
	if t == null or not is_instance_valid(t):
		return PI
	var n := t as Node3D
	var avanti: Vector3 = -n.global_transform.basis.z
	avanti.y = 0.0
	var verso: Vector3 = bersaglio - n.global_position
	verso.y = 0.0
	if avanti.length() < 0.001 or verso.length() < 0.001:
		return PI
	avanti = avanti.normalized()
	verso = verso.normalized()
	return atan2(avanti.cross(verso).y, avanti.dot(verso))


func _dove_va(corpo: Node3D) -> Vector3:
	if corpo.has_method("meta_cammino"):
		var m: Vector3 = corpo.call("meta_cammino")
		if m != Vector3.ZERO:
			return m
	return corpo.global_position


# =========================================================================
# IL GIRO DEL PENSATOIO
# =========================================================================

## Aspetta pompando il Pensatoio, che è quello che fa il `_process` di chi lo
## ospiterà. Il delta è quello VERO: un banco che passa un delta nominale
## misura un orologio che non esiste.
func _aspetta(secondi: float) -> void:
	var fine := Time.get_ticks_usec() + int(secondi * 1_000_000.0)
	var prima := Time.get_ticks_usec()
	while Time.get_ticks_usec() < fine:
		await process_frame
		var ora := Time.get_ticks_usec()
		if _pens != null:
			_pens.passo(float(ora - prima) / 1_000_000.0)
		prima = ora


## Aspetta che il pensiero in volo torni (o che il tetto scada).
func _aspetta_pensiero(tetto: float) -> bool:
	_in_attesa = true
	var t_inizio := Time.get_ticks_msec()
	while _in_attesa and float(Time.get_ticks_msec() - t_inizio) / 1000.0 < tetto:
		await _aspetta(0.25)
	var ok := not _in_attesa
	_in_attesa = false
	return ok


func _fonte_tutti() -> Array:
	var out := []
	for r in _residenti:
		var riga: Dictionary = r
		if riga.has("ecs"):
			out.append({"chi": int(riga["ecs"]), "id": str(riga.get("label", "")), "r": riga})
	return out


func _foglio_lettera(c) -> Dictionary:
	var d: Dictionary = c
	# IL SEME È DERIVATO, mai tirato: due corse di questo banco chiedono al
	# modello le stesse cose (è la regola dei dadi di questo gioco, applicata
	# a un banco di prova).
	var seme := absi(hash(str(d.get("id", "")) + str(_lettere))) & 0x7FFFFFFF
	return FOGLIO.foglio(_vis, _dn, _cuore, d["r"], "lettera", "Mochi", seme)


# =========================================================================
# LA CONSEGNA DI UNA LETTERA — è qui che si stampa tutto
# =========================================================================

func _consegna_lettera(c, bozze: PackedStringArray, foglio: Dictionary) -> void:
	var d: Dictionary = c
	var chi := str(d.get("id", ""))
	var rit: Dictionary = foglio.get("ritratto", {})
	var u: Dictionary = _pens.misure().get("ultimo", {})
	_durate.append(float(u.get("secondi_prompt", 0.0)) + float(u.get("secondi_generazione", 0.0)))

	print("\n" + "═".repeat(72))
	print("PENSIERO %d — %s, a t=%.1f s" % [_lettere + 1, chi, _t()])
	print("═".repeat(72))
	print("  il motore: prompt %d gettoni in %.2f s (%.1f g/s) · %d bozze, %d gettoni in %.2f s (%.1f g/s) · riletture %d"
			% [int(u.get("token_prompt", 0)), float(u.get("secondi_prompt", 0.0)),
			float(u.get("token_prompt", 0)) / maxf(float(u.get("secondi_prompt", 0.0)), 0.001),
			bozze.size(), int(u.get("token_generati", 0)), float(u.get("secondi_generazione", 0.0)),
			float(u.get("token_generati", 0)) / maxf(float(u.get("secondi_generazione", 0.0)), 0.001),
			int(u.get("riletture_prompt", 0))])

	# ---- QUELLO CHE IL MODELLO HA LETTO ------------------------------
	print("")
	_riquadro("IL PROMPT VERO — messaggio di sistema", str(foglio.get("sistema", "")))
	_riquadro("IL PROMPT VERO — messaggio dell'utente", str(foglio.get("utente", "")))
	var gram := str(foglio.get("grammatica", ""))
	if not _gram_vista.has(chi):
		_gram_vista[chi] = true
		_riquadro("LA GRAMMATICA GBNF (generata dalle enum chiuse)", gram)
	else:
		print("  (la grammatica è quella di prima: %d byte, %d citazioni ammesse)"
				% [gram.length(), SUG.citazioni(rit).size()])

	# ---- IL GIUDIZIO --------------------------------------------------
	var mem := {"sue": _memoria_sue.get(chi, []), "villaggio": _memoria_villaggio}
	var v: Dictionary = GIUDICE.scegli(Array(bozze), rit, mem)
	var schede: Array = v["schede"]
	print("\n  ── LE %d BOZZE, e cosa ne ha detto il giudice ──" % bozze.size())
	for i in bozze.size():
		var s: Dictionary = schede[i]
		_bozze_tot += 1
		if bool(s["ok"]):
			_bozze_ammesse += 1
		else:
			var p := str(s["porta"])
			_porte[p] = int(_porte.get(p, 0)) + 1
		var segno := "   " if not bool(s["ok"]) else " ✓ "
		if i == int(v["scelta"]):
			segno = "⇒✓ "
		print("")
		print("  %s[%d] %s" % [segno, i,
				("AMMESSA · rarità %.2f · lontananza %.2f · punti %.2f"
						% [float(s["rarita"]), float(s["lontananza"]), float(s["punti"])])
				if bool(s["ok"]) else ("BUTTATA (porta «%s») — %s" % [str(s["porta"]), str(s["perche"])])])
		for riga in str(bozze[i]).split("\n"):
			if str(riga).strip_edges() != "":
				print("        %s" % str(riga).strip_edges())

	# ---- L'ESITO ------------------------------------------------------
	print("")
	if int(v["scelta"]) < 0:
		_silenzi += 1
		print("  ⇒ SILENZIO: %s" % str(v["motivo"]))
		print("    (il gioco manda la lettera scritta a mano, come su qualunque")
		print("     macchina senza modello. Il silenzio è un esito, non un guasto.)")
	else:
		_lettere += 1
		var testo := str(v["testo"])
		if not _memoria_sue.has(chi):
			_memoria_sue[chi] = []
		(_memoria_sue[chi] as Array).append(testo)
		_memoria_villaggio.append(testo)
		print("  ⇒ SCELTA la %d: %s" % [int(v["scelta"]), str(v["motivo"])])
		_riquadro("LA LETTERA COM'È SULLO SCHERMO (Suggeritore.rifinisci)", str(v["lettera"]))
	_in_attesa = false


# =========================================================================
# IL GO
# =========================================================================

func _go() -> void:
	_t0 = Time.get_ticks_msec()
	_dove = OS.get_environment("CHIBI_PENSIERI")
	if _dove != "":
		DirAccess.make_dir_recursive_absolute(_dove)
	var percorso := OS.get_environment("CHIBI_MODELLO")
	_copie = int(OS.get_environment("CHIBI_COPIE")) \
			if OS.get_environment("CHIBI_COPIE") != "" else PENSATOIO.COPIE
	var quanti_giri := int(OS.get_environment("CHIBI_GIRI")) \
			if OS.get_environment("CHIBI_GIRI") != "" else 4

	print("=== LA PROVA VIVA DELLA FASE 5 ===")
	print("  %s" % LLM.riga_di_stato())
	if not LLM.disponibile():
		print("\n  Questo banco esiste per provare il gioco CON il cuore che scrive.")
		print("  Il binario è compilato senza (`scons llm=yes` per averlo), e il")
		print("  gioco senza modello è già provato da `tools/prova_identico.gd`.")
		quit(1)
		return
	if percorso == "":
		print("\n  serve CHIBI_MODELLO=/percorso/al.gguf")
		quit(1)
		return

	# ------------------------------------------------------- il villaggio
	await process_frame
	if change_scene_to_file("res://scenes/levels/MainLevel.tscn") != OK:
		print("GUASTO: il MainLevel non si apre")
		quit(1)
		return
	for _i in 12:
		await process_frame
	var livello := current_scene
	if livello == null:
		print("GUASTO: il MainLevel non si è caricato")
		quit(1)
		return
	_build = livello.get_node_or_null("BuildSystem")
	_vis = livello.get_node_or_null("Visitors")
	_dn = livello.get_node_or_null("DayNight")
	_mondo_nodo = livello.get_node_or_null("CozyWorld")
	_player = livello.get_node_or_null("Player") as Node3D
	if _build == null or _vis == null or _dn == null:
		print("GUASTO: BuildSystem=%s Visitors=%s DayNight=%s" % [_build, _vis, _dn])
		quit(1)
		return
	_build.call("set_persist_for_debug", false)
	# ⚠️ **L'OROLOGIO SI FERMA, E NON È UN VEZZO DI ILLUMINAZIONE.** Un giorno
	# di questo gioco dura **quattro minuti** (`DayNight.cycle_seconds = 240`)
	# e questo banco ne dura venti: senza fermarlo, a metà prova cala la notte
	# e i residenti vanno a dormire. Un vicino che dorme è `_hidden`, e
	# `resident_sleep()` gli rimpicciolisce il corpo a **scala 0.03** — cioè
	# la ricevuta non si paga più (`Percezione.puo_vedere` esclude chi è
	# dentro casa) E la foto inquadra un puntino invisibile in mezzo all'erba
	# al buio. È successo: la prima tornata di scatti è tutta di notte, con un
	# granello al centro del fotogramma e la colonna del banco che diceva
	# soltanto «la ricevuta non è stata pagata».
	_dn.set("cycle_seconds", 100000.0)
	_dn.call("set_time", 0.42)   # primo pomeriggio: nessuno dorme, c'è luce
	# la presa sulla posa gira su `process_frame` — cioè PRIMA del `_process`
	# dei nodi, come tutte le sonde di questo progetto
	process_frame.connect(_mantieni)
	await create_timer(1.2).timeout

	if _dove != "":
		_cam = Camera3D.new()
		_cam.fov = FOV_STRETTO
		_cam.current = true
		root.add_child(_cam)
		# VIA L'INTERFACCIA, con lo stesso gesto della Modalità Foto
		# (`PhotoMode._hide_ui`): le barre della fame e il cartellino «B —
		# modalità costruzione» in un fotogramma che deve mostrare una testa
		# che si gira sono rumore, e in più dicono una bugia (qui non c'è
		# nessun giocatore che gioca).
		for layer in root.find_children("*", "CanvasLayer", true, false):
			(layer as CanvasLayer).visible = false

	_vis.call("debug_reset")
	for c in CASE:
		_build.call("place_cell", c, "Letto", 0, false)
		_build.call("place_cell", c, "Tetto", 0, false)
	_build.call("place_cell", CESPUGLIO, "Cespuglio", 0, false)
	_build.call("place_cell", PANCA_LONTANA, "Panchina", 0, false)
	_build.call("place_cell", PANCA_VICINA, "Panchina", 0, false)
	_build.call("aggiorna_varchi_ora")
	var letti: Array = _build.call("get_placed_by_name", "Letto")
	if letti.size() != CASE.size():
		print("GUASTO: %d letti su %d — una cella è nel letto del fiume (place_cell rifiuta in silenzio)"
				% [letti.size(), CASE.size()])
		quit(1)
		return
	for i in CASE.size():
		_vis.call("debug_settle", 4242 + i * 1013, CASE[i])
		await create_timer(0.7).timeout
	_residenti = _vis.get("_residents")
	_cuore = _vis.call("cuore")
	if _residenti.size() < 3 or _cuore == null:
		print("GUASTO: residenti=%d cuore=%s" % [_residenti.size(), _cuore])
		quit(1)
		return
	for _i in 30:
		await process_frame
	var nomi := []
	for r in _residenti:
		nomi.append(str((r as Dictionary).get("label", "?")))
	print("  villaggio: %s" % ", ".join(nomi))

	# --------------------------------------------- I GESTI DI MOCHI
	#
	# Il bus vero della percezione, con gli stessi tre verbi che il gioco
	# emette da tre posti diversi: `Garden._water`, `Visitors._give_dish`,
	# `BuildSystem._try_place`. Non si scrive niente nel grafo da fuori — un
	# banco che si costruisce lo stato a mano prova il banco.
	print("\n--- Mochi lavora sotto i loro occhi ---")
	# I TRE VERBI DEL GIOCATORE, dai tre siti veri (`Garden._water`,
	# `Visitors._give_dish`, `BuildSystem._try_place`), e ognuno **davanti a
	# un vicino solo**: il raggio è nove metri, e le case sono messe apposta
	# perché nessuno veda il gesto di un altro. Un villaggio in cui tutti
	# hanno visto tutto è il caso più facile, e i tre prompt uscirebbero
	# uguali.
	#
	# TRE VOLTE (o due) dentro la finestra di fusione: fanno UN ricordo con
	# `quante = 3` — «ti ho vista lavorare lì per un pezzo» — che pesa più del
	# doppio della soglia e non scade a metà della prova.
	var gesti := [
		# ⚠️ VERBI E POSTI DIVERSI DA QUELLI DELLE DUE SCENE dell'atto II, e
		# la ragione è misurata: quando l'apertura e la scena facevano lo
		# STESSO gesto nello STESSO posto, il grafo si ritrovava due righe
		# che in italiano si leggono quasi uguali — «l'ho vista annaffiare le
		# aiuole, più di una volta, poco fa» e «…, tanto tempo fa» — e il
		# modello ha citato quella VECCHIA in cinque bozze su cinque. Il
		# ponte l'ha giustamente rifiutata (il ricordo pesava 0.07, sotto la
		# soglia del villaggio) e la scena non è mai successa. È un dato
		# vero sul modello, ed è raccontato nella nota di consegna; ma un
		# banco non deve rendere impossibile la cosa che vuole fotografare.
		{"chi": 0, "verbo": "raccoglie", "dove": _mondo(CASE[0]) + Vector3(2.2, 0, 1.4),
				"volte": 2},
		{"chi": 1, "verbo": "cucina", "dove": _mondo(CASE[1]) + Vector3(-1.8, 0, 1.6),
				"volte": 2},
		{"chi": 2, "verbo": "costruisce", "dove": _mondo(CASE[2]) + Vector3(-1.5, 0, 1.2),
				"volte": 2},
	]
	for g in gesti:
		var gg: Dictionary = g
		# ⚠️ SI PORTA IL VICINO DAVANTI AL GESTO, e non è una comodità: un
		# vicino vero cammina, e la prima stesura di questo banco faceva i
		# gesti «davanti a casa sua» trovando **zero testimoni** perché in
		# quel momento era dall'altra parte del prato. Un banco che emette un
		# gesto che nessuno vede prova il bus della percezione, non la Fase 5.
		var chi := int(gg["chi"])
		await _porta_vicino(chi, (gg["dove"] as Vector3) + Vector3(3.0, 0, 3.0))
		for _k in int(gg["volte"]):
			call_group("percezione", "accaduto", str(gg["verbo"]), gg["dove"],
					str((_residenti[chi] as Dictionary).get("label", "")) \
							if str(gg["verbo"]) == "dona" else "")
			await create_timer(1.8).timeout
		print("  · «%s» a %s per %s — testimoni: %d" % [str(gg["verbo"]), gg["dove"],
				str((_residenti[chi] as Dictionary).get("label", "?")),
				(_vis.call("testimoni", gg["dove"], PERCEZIONE.RAGGIO) as Array).size()])

	for i in _residenti.size():
		var r: Dictionary = _residenti[i]
		var g2: Dictionary = _cuore.call("debug_grafo", int(r["ecs"]))
		print("  %s ricorda %d cose" % [str(r.get("label", "?")),
				(g2.get("ricordi", []) as Array).size()])

	# lo sguardo dei gesti si deve SPEGNERE prima di misurare le ricevute
	await create_timer(PERCEZIONE.DURATA_SGUARDO + 1.0).timeout

	# ---------------------------------------------------------- il motore
	print("\n--- il cuore che scrive ---")
	_llm = LLM.apri()
	var opz := {"priorita": int(OS.get_environment("CHIBI_PRIORITA"))
					if OS.get_environment("CHIBI_PRIORITA") != "" else 1}
	if OS.get_environment("CHIBI_CTX") != "":
		opz["n_ctx"] = int(OS.get_environment("CHIBI_CTX"))
	if OS.get_environment("CHIBI_THREAD") != "":
		opz["n_thread"] = int(OS.get_environment("CHIBI_THREAD"))
	# IL PORTIERE PRIMA DI TUTTO: è la stessa funzione che sta davanti al
	# caricamento vero, e qui si stampa quello che ha visto.
	var esame: Dictionary = _llm.call("esamina", percorso, false)
	print("  portiere: %s · %s %s · %d parametri · vocabolario %d · %.0f MB su disco · stima a 2k %.0f MB (%.0f ms)"
			% [("ok" if bool(esame.get("ok", false)) else "NO — " + str(esame.get("motivo", ""))),
			str(esame.get("architettura", "?")), str(esame.get("quantizzazione", "?")),
			int(esame.get("parametri", 0)), int(esame.get("vocabolario", 0)),
			float(esame.get("byte_file", 0)) / 1048576.0,
			float(esame.get("byte_stimati_2k", 0)) / 1048576.0,
			float(esame.get("ms_esame", 0))])
	var t_car := Time.get_ticks_msec()
	if not bool(_llm.call("apri_modello", percorso, opz)):
		print("GUASTO: apri_modello ha detto no: %s" % percorso)
		quit(1)
		return
	while int(_llm.call("stato")) == 1:
		await process_frame
	if int(_llm.call("stato")) != 2:
		print("GUASTO: il modello non è pronto — %s"
				% str((_llm.call("misure") as Dictionary).get("diagnosi", "")))
		quit(1)
		return
	var mm: Dictionary = _llm.call("memoria")
	print("  aperto in %d ms · %s · priorità %s · memoria del processo: impronta %.0f MB"
			% [Time.get_ticks_msec() - t_car, str(_llm.call("versione")),
			str(opz["priorita"]), float(mm.get("impronta", 0)) / 1048576.0])

	# ============================================================ ATTO I
	print("\n\n" + "█".repeat(72))
	print("ATTO I — I PENSIERI: cosa legge il modello, cosa scrive, cosa esce")
	print("█".repeat(72))
	_pens = PENSATOIO.new()
	_pens.collega(_llm, _fonte_tutti, _foglio_lettera, _consegna_lettera)
	var t_atto1 := Time.get_ticks_msec()
	var tentativi := 0
	if quanti_giri <= 0:
		print("  (CHIBI_GIRI=0: si salta l'atto delle lettere — serve a tarare le")
		print("   inquadrature senza pagare tre minuti di generazione)")
	while quanti_giri > 0 and _lettere + _silenzi < quanti_giri \
			and tentativi < quanti_giri * 3:
		tentativi += 1
		# ⚠️ IL TETTO STA SOPRA `Pensatoio.RIPOSO`, e non è generosità: con tre
		# vicini il giro naturale finisce dopo tre pensieri, e dal quarto in
		# poi si aspetta che scada il riposo di cinque minuti. Un tetto più
		# corto misurerebbe solo il primo giro — cioè il caso in cui il ritmo
		# non è ancora il ritmo.
		if not await _aspetta_pensiero(PENSATOIO.RIPOSO + 120.0):
			var mp0: Dictionary = _pens.misure()
			if int(mp0["muti"]) > 0 and not bool(mp0["in_volo"]):
				# NON HA NIENTE DI VERO DA DIRE: è il caso normale, e il
				# Pensatoio l'ha già messo a riposo. Si continua il giro.
				continue
			print("\n  (nessun pensiero entro il tetto: %s)" % str(mp0))
			break
	var dt_atto1 := float(Time.get_ticks_msec() - t_atto1) / 1000.0
	_pens.svuota()

	# ============================================================ ATTO II
	print("\n\n" + "█".repeat(72))
	print("ATTO II — LA DEDUZIONE: il JSON che diventa un gesto")
	print("█".repeat(72))
	print("  Due volte lo stesso codice, due mondi diversi. La differenza che")
	print("  si vede nelle foto è tutta del mondo — ed è la domanda vera di")
	print("  questa fase: il giocatore sa attribuire quello che vede?")
	await _scena_deduzione(0, "A", "la premessa LONTANA dalla meta",
			GESTO_LONTANO, "annaffia")
	await _scena_deduzione(1, "B", "la premessa NEL posto della meta",
			PANCA_VICINA, "dona")

	# ============================================================ IL RITMO
	_ritmo(dt_atto1, quanti_giri)
	_llm.call("chiudi")
	print("\n==== PROVA VIVA: %s ====" % ("TUTTO A POSTO" if _guasti == 0
			else "%d GUASTI" % _guasti))
	quit(1 if _guasti > 0 else 0)


## PORTA UN VICINO DOVE SERVE, e ce lo tiene per il tempo del gesto. È lo
## stesso `debug_stage_resident` dei banchi di prova, ripetuto finché il
## corpo non ci è arrivato davvero: chi si sta alzando da una panchina ha un
## tween addosso che riscrive `position` il frame dopo (la trappola già
## pagata da `prova_conseguenze`).
func _porta_vicino(i: int, dove: Vector3) -> void:
	var r: Dictionary = _residenti[i]
	var n := r.get("node") as Node3D
	if n == null:
		return
	for _k in 10:
		_vis.call("debug_stage_resident", i, dove)
		await create_timer(0.25).timeout
		if n.global_position.distance_to(dove) < 0.8:
			return


func _pos_di(i: int) -> Vector3:
	var r: Dictionary = _residenti[i]
	var n := r.get("node") as Node3D
	return n.global_position if n != null else Vector3.ZERO


# =========================================================================
# ATTO II — la deduzione, dalla grammatica al corpo
# =========================================================================

## DOVE POSARE IL CORPO: a `POSA_DISTANZA` dall'ancora, dalla parte del
## villaggio. Non è un vezzo di inquadratura — i vicini camminano senza
## collisioni, quindi una posa scelta «dalla parte in cui si trovava» può
## finire **dentro il fiume**, e la foto mostrerebbe un chibi sospeso
## sull'acqua. Si prova la direzione naturale e, se il terreno la vieta
## (`CozyWorld.terreno_vietato`, la stessa fonte della deviazione), si gira
## di 45° finché non se ne trova una buona.
func _posa_buona(mondo: Node, ancora: Vector3, corpo: Node3D) -> Vector3:
	var dir: Vector3 = corpo.global_position - ancora
	dir.y = 0.0
	if dir.length() < 0.5:
		dir = CENTRO - ancora
		dir.y = 0.0
	if dir.length() < 0.5:
		dir = Vector3(1, 0, 1)
	dir = dir.normalized()
	for k in 8:
		var p: Vector3 = ancora + dir.rotated(Vector3.UP, float(k) * PI * 0.25) * POSA_DISTANZA
		if mondo == null or not is_instance_valid(mondo):
			return p
		if not bool(mondo.call("terreno_vietato", Vector2i(roundi(p.x), roundi(p.z)))):
			return p
	return ancora + dir * POSA_DISTANZA


## ⚠️ IL BANCO TIENE LA POSA, e va detto forte perché è l'unica cosa che
## questo file fa e che il gioco non fa.
##
## La ricevuta si paga in mezzo secondo (la cadenza dei fatti), e in mezzo
## secondo un vicino vero è già ripartito: l'agenda gli assegna un mestiere,
## il corpo si mette in cammino e l'imbardata cambia. Fotografare una testa
## che si gira mentre le spalle girano anche loro vuol dire non fotografare
## niente. Perciò, finché la ricevuta non è pagata e finché dura la
## pellicola, questo banco rimette il corpo dov'era (`debug_stage_resident`,
## che è il gesto di sempre dei banchi) e gli ridà l'imbardata che gli ha
## dato.
##
## **Quello che NON si tocca è chi decide se la ricevuta si paga**: le due
## valvole restano `Percezione.puo_vedere` e `Visitor.collo_ci_arriva`,
## chiamate dal registro vero sulla cadenza vera. Il banco tiene ferma la
## macchina fotografica, non la mano di chi firma.
var _tieni := false
var _tieni_indice := -1
var _tieni_pos := Vector3.ZERO
var _tieni_yaw := NAN
var _tieni_corpo: Node3D = null


## ⚠️ **L'IMBARDATA DEL CORPO NON SI SCRIVE SU `rotation.y`: SI SCRIVE SU
## `_yaw`.** Questa riga costa due stesure di questo banco.
##
## `Visitor._process` finisce con `rotation.y = _yaw`, **per ogni stato,
## ogni frame** (è la riga accanto a `_corpo_rete()`, e c'è per la stessa
## ragione: un canale del rig che nessuno azzera si avvita). Quindi una
## rotazione scritta da fuori vive esattamente **un frame** e poi sparisce.
## Le due stesure precedenti giravano il corpo, misuravano subito e
## trovavano un numero che al frame dopo non c'era più: la posa dichiarava
## 30° e il muso ne aveva 172, la testa non arrivava al bersaglio (il tetto
## del collo è 44°), la ricevuta non si pagava mai — e il banco dichiarava
## un silenzio che era suo.
##
## Si scrive `_yaw` (e si specchia subito su `rotation.y`, o la misura del
## frame stesso leggerebbe ancora la posa vecchia).
func _gira(corpo: Node3D, delta: float) -> void:
	_metti_yaw(corpo, float(corpo.get("_yaw")) + delta)


func _metti_yaw(corpo: Node3D, y: float) -> void:
	corpo.set("_yaw", y)
	corpo.rotation.y = y


func _mantieni() -> void:
	if not _tieni or _tieni_corpo == null or not is_instance_valid(_tieni_corpo):
		return
	if str(_tieni_corpo.get("_state")) != "r_idle":
		_vis.call("debug_stage_resident", _tieni_indice, _tieni_pos)
	if not is_nan(_tieni_yaw):
		_metti_yaw(_tieni_corpo, _tieni_yaw)


## PUNTA IL CORPO in modo che il MUSO manchi il bersaglio di `voluto`.
##
## Non si imposta l'imbardata e basta: fra il corpo e quello che si misura
## c'è il collo, che ha una mira sua (`Visitor._taratura_sguardo`,
## l'ondeggio dell'inattività di ±17°, il residuo di uno sguardo di prima).
## Impostare il corpo a 30° e fidarsi vuol dire, qualche volta, fotografare
## una testa **già sul bersaglio** — cioè fotografare una ricevuta che non
## c'è, con la luce verde. Si misura il muso, si corregge, si rimisura.
func _punta(corpo: Node3D, bersaglio: Vector3, voluto: float) -> float:
	# si porta il MUSO sul bersaglio (non il corpo: è il muso che si misura)
	_gira(corpo, _scarto_segnato(corpo, bersaglio))
	_tieni_yaw = float(corpo.get("_yaw"))
	for _f in 3:
		await process_frame
	# e ci si arretra sopra, sempre dallo stesso lato: cambiare lato a metà
	# correzione fa oscillare senza mai arrivare
	var lato: float = 1.0 if _scarto_segnato(corpo, bersaglio) >= 0.0 else -1.0
	for _giro in 8:
		var s := _scarto_segnato(corpo, bersaglio)
		if absf(absf(s) - voluto) < deg_to_rad(7.0):
			break
		_gira(corpo, s - lato * voluto)
		_tieni_yaw = float(corpo.get("_yaw"))
		for _f in 3:
			await process_frame
	_tieni_yaw = float(corpo.get("_yaw"))
	return _scarto(corpo, bersaglio)


## UNA SCENA DELLA DEDUZIONE, dall'inizio alla fine. Si chiama due volte, con
## due vicini che hanno intorno due mondi diversi (vedi le costanti in cima).
func _scena_deduzione(indice: int, sigla: String, titolo: String,
		posto: Vector2i, verbo: String) -> void:
	var r: Dictionary = _residenti[indice]
	var corpo := r.get("node") as Node3D
	var id := int(r["ecs"])
	var nome := str(r.get("label", "?"))
	print("\n\n" + "─".repeat(72))
	print("SCENA %s — %s (%s)" % [sigla, titolo, nome])
	print("─".repeat(72))

	# ---- 0) MOCHI FA UNA COSA, QUI E ADESSO ----------------------------
	#
	# ⚠️ IL GESTO DELLA SCENA SI FA ADESSO, e non all'inizio del banco. Un
	# ricordo si raffredda: `deduci()` rifiuta una catena il cui anello più
	# debole pesa meno di `AMMIRA_SOGLIA`, e dopo cinque lettere (tre minuti
	# e mezzo di macchina) i gesti dell'apertura pesavano **0.17** — il ponte
	# le rifiutava tutte e due le scene, e il banco non fotografava niente.
	# È lo stesso decadimento che in partita fa dire al villaggio «quel
	# ricordo non conta più», ed è giusto che ci sia: qui vuol dire che la
	# premessa va messa vicino alla conseguenza NEL TEMPO, non solo nello
	# spazio.
	var ancora_attesa := _mondo(posto)
	var posa: Vector3 = _posa_buona(_mondo_nodo, ancora_attesa, corpo)
	await _porta_vicino(indice, posa)
	_mochi_guarda(posa, ancora_attesa)
	_tieni_indice = indice
	_tieni_pos = posa
	_tieni_corpo = corpo
	_tieni_yaw = NAN
	_tieni = true
	print("  Mochi «%s» a %s, e lui è a %.1f m" % [verbo, ancora_attesa,
			corpo.global_position.distance_to(ancora_attesa)])
	for _k in 3:
		call_group("percezione", "accaduto", verbo, ancora_attesa,
				nome if verbo == "dona" else "")
		await create_timer(1.6).timeout
	print("  testimoni: %d · lui ricorda %d cose"
			% [(_vis.call("testimoni", ancora_attesa, PERCEZIONE.RAGGIO) as Array).size(),
			((_cuore.call("debug_grafo", id) as Dictionary).get("ricordi", []) as Array).size()])
	# lo sguardo del gesto deve SPEGNERSI, o si misurerebbe quello invece
	# della ricevuta
	await create_timer(PERCEZIONE.DURATA_SGUARDO + 1.2).timeout

	# SI ZITTISCE L'AGENDA (lo stesso lease dei sistemi a evento): fra il
	# gesto e la deduzione il registro cambierebbe mestiere da solo, e
	# l'obiettivo che sta già perseguendo esce dai deducibili — il banco
	# proverebbe una cosa diversa a ogni corsa.
	_vis.call("debug_force_activity", indice, "gironzola")
	await create_timer(0.5).timeout

	var rit: Dictionary = FOGLIO.ritratto(_vis, _dn, _cuore, r, "pensiero", "Mochi")
	var offerti := SUG.obiettivi_deducibili(rit)
	print("  sta facendo «%s» · può dedurre: %s"
			% [str(rit.get("azione", "?")), str(offerti)])
	_dico(not offerti.is_empty(), "c'è qualcosa da dedurre")
	if offerti.is_empty():
		_tieni = false
		return

	# ---- 1) IL FOGLIO E LA GRAMMATICA DELLA DEDUZIONE ------------------
	#
	# ⚠️ NESSUN MODELLO VERO HA MAI VISTO QUESTA GRAMMATICA prima di adesso
	# (la nota di consegna dell'injection lo dichiara): è verificata
	# strutturalmente, non da un parse di llama.cpp. Se il tasso di
	# ammissione qui sotto fosse zero, l'injection non esisterebbe in
	# partita — e nessun test lo direbbe.
	var seme := absi(hash(nome + "deduzione")) & 0x7FFFFFFF
	var f: Dictionary = FOGLIO.foglio_deduzione(_vis, _dn, _cuore, r, "Mochi", seme)
	_dico(not f.is_empty(), "il foglio della deduzione si costruisce")
	if f.is_empty():
		_tieni = false
		return
	print("")
	if sigla == "A":
		# per esteso una volta sola: la seconda scena ha lo stesso sistema e
		# la stessa forma di grammatica, e ristamparli seppellisce quello che
		# CAMBIA (i ricordi, e le scelte che restano)
		_riquadro("IL PROMPT DELLA DEDUZIONE — sistema", str(f["sistema"]))
		_riquadro("LA GRAMMATICA DELLA DEDUZIONE", str(f["grammatica"]))
	_riquadro("IL PROMPT DELLA DEDUZIONE — utente", str(f["utente"]))

	# ---- 2) IL MODELLO SCRIVE ------------------------------------------
	var b := int(_llm.call("accoda", id, str(f["sistema"]), str(f["utente"]),
			str(f["grammatica"]),
			{"copie": _copie, "max_token": 48, "seme": seme}))
	_dico(b != 0, "il motore ha accettato la richiesta")
	if b == 0:
		_tieni = false
		return
	var t_gen := Time.get_ticks_msec()
	var e := {}
	while e.is_empty() and float(Time.get_ticks_msec() - t_gen) / 1000.0 < 180.0:
		await process_frame
		e = _llm.call("raccogli")
	if e.is_empty():
		_dico(false, "il modello non ha risposto entro il tetto")
		_tieni = false
		return
	var bozze: PackedStringArray = e.get("bozze", PackedStringArray())
	print("\n  ── LE %d BOZZE DELLA DEDUZIONE (%.1f s) ──"
			% [bozze.size(), float(Time.get_ticks_msec() - t_gen) / 1000.0])
	for i in bozze.size():
		print("     [%d] %s" % [i, str(bozze[i]).strip_edges()])
	if str(e.get("errore", "")) != "":
		print("     errore del motore: %s" % str(e["errore"]))

	var aperte := DED.bozze_da(Array(bozze))
	_dico(aperte.size() == bozze.size(),
			"tutte le bozze sono JSON validi (%d su %d) — è la grammatica che lo garantisce"
					% [aperte.size(), bozze.size()])

	# ---- 3) IL GIUDICE, e poi il ponte ---------------------------------
	var fattibili: Array = _vis.call("obiettivi_fattibili", r)
	var scelta: Dictionary = GIUDICE.scegli_deduzione(aperte, rit, {"fattibili": fattibili})
	print("\n  ── IL GIUDIZIO (il mondo ha una strada per: %s) ──" % str(fattibili))
	for i in aperte.size():
		var s: Dictionary = (scelta["schede"] as Array)[i]
		print("     %s[%d] %s — %s" % [("⇒" if i == int(scelta["scelta"]) else " "), i,
				("AZIONABILE" if bool(s["ok"]) else "BUTTATA"), str(s["perche"])])
	var esito: Dictionary = DED.incassa(_cuore, id, aperte, rit,
			{"fattibili": fattibili}, SOGLIA)
	print("\n  ⇒ nel grafo: %s" % str(esito))
	_dico(int(esito["indice"]) >= 0, "una deduzione è entrata nel grafo")
	if int(esito["indice"]) < 0:
		_tieni = false   # la presa non deve sopravvivere alla scena
		return
	var dedotto := str(esito["obiettivo"])
	# LA META e l'ANCORA, chieste come le chiede la ricevuta vera: l'ancora è
	# il perché più pesante FRA QUELLI CHE SI LEGGONO da dove sta il corpo,
	# cioè quelli nella direzione in cui andrà.
	var meta_ded: Dictionary = DED.meta_del_gesto(_cuore, id, int(esito["indice"]),
			r.get("luoghi", []), int(r.get("fatti", 0)))
	var ancora: Vector3 = _cuore.call("deduzione_dove", id, int(esito["indice"]),
			corpo.global_position,
			meta_ded.get("pos", corpo.global_position), DED.APERTURA)
	print("     obiettivo «%s» · andrà al luogo «%s» %s"
			% [dedotto, str(meta_ded.get("luogo", "—")),
			str(meta_ded.get("pos", "(nessuna meta)"))])
	print("     l'ANCORA della ricevuta (il posto del ricordo): %s%s" % [ancora,
			"" if ancora.distance_to(corpo.global_position) > 0.05
					else "  ⚠️ nessun perché si legge da qui: la ricevuta tacerà"])

	# ---- 4) LA POSA, e le tre macchine ---------------------------------
	#
	# Si posa il corpo e lo si punta: due cose che il gioco produce di
	# continuo, e servono a poter scattare la STESSA inquadratura prima e
	# dopo. Una testa che si gira non si vede in una foto sola.
	#
	# ⚠️ LA DEDUZIONE È GIÀ NEL GRAFO, e la ricevuta la paga `_cuore_di` alla
	# cadenza dei fatti (mezzo secondo): la posa deve arrivare PRIMA che il
	# collo ci arrivi, o la foto «prima» è già la foto «dopo». Per questo si
	# posa girati di 35° — dentro il tetto del collo, ma non zero.
	# ⚠️ SI ASPETTA CHE SIA IN CONDIZIONE DI GUARDARE, e questa attesa È una
	# misura, non un espediente. `Percezione.puo_vedere` esclude chi dorme,
	# chi è dentro casa e **chi è a un appuntamento** (`in_scena`): un vicino
	# che sta chiacchierando non paga ricevute. Misurato qui: alla prima
	# corsa la scena B è rimasta muta per venticinque secondi con la testa
	# perfettamente puntata sull'ancora, e la sola colonna che lo diceva era
	# `vede? NO`. In partita la deduzione ha minuti per trovare il suo
	# momento; se non lo trova muore in silenzio, che è l'esito buono.
	var t_attesa := _t()
	while _t() - t_attesa < 45.0 and not _si_vede(corpo):
		await create_timer(0.25).timeout
	print("     (in condizione di guardare dopo %.1f s: %s%s)" % [_t() - t_attesa,
			"sì" if _si_vede(corpo) else "MAI",
			"" if _si_vede(corpo)
					else " — dentro casa: %s · dorme: %s · a un appuntamento: %s · Mochi a %.1f m"
							% [str(corpo.call("is_hidden")), str(corpo.call("dorme")),
							str(corpo.call("in_scena")),
							corpo.global_position.distance_to(_dove_mochi())]])

	if ancora.distance_to(ancora_attesa) > 1.5:
		# l'ancora non è il gesto di questa scena: il vicino ha citato un
		# ricordo più vecchio. Si riposa il corpo di conseguenza, o le foto
		# inquadrerebbero il posto sbagliato.
		print("     (l'ancora NON è il gesto di adesso: si riposa il corpo)")
		posa = _posa_buona(_mondo_nodo, ancora, corpo)
		await _porta_vicino(indice, posa)
		_mochi_guarda(posa, ancora)
		_tieni_pos = posa
	var sc_prima := await _punta(corpo, ancora, POSA_SCARTO)
	var cervello = _vis.call("debug_brain", indice)
	print("\n  ── LA POSA ── a %.1f m dall'ancora · il muso la manca di %.1f° (tetto del collo %.0f°)"
			% [corpo.global_position.distance_to(ancora), rad_to_deg(sc_prima),
			rad_to_deg(VISITOR.tetto_ricevuta())])
	if cervello != null:
		print("     (i suoi bisogni adesso: %s)" % str(cervello.get("needs")))
	var macchine := _macchine(corpo, ancora)
	await _terna("%s_1_prima" % sigla, macchine)

	# ---- 5) LA RICEVUTA, frame per frame -------------------------------
	#
	# Non la chiama nessuno: la paga `Visitors._cuore_di` sulla cadenza dei
	# fatti. Qui si guarda soltanto.
	print("\n  ── LA RICEVUTA (la paga il registro da solo) ──")
	# ⚠️ LE DUE VALVOLE SI STAMPANO. Una ricevuta che non arriva ha due sole
	# ragioni — «non può vedere» (dorme, è dentro casa, è a un appuntamento) e
	# «il collo non ci arriva» — e un banco che dice soltanto «non è stata
	# pagata» lascia indovinare quale delle due. Sono le stesse due domande
	# che si fa `Deduzioni.consegna`, chieste dallo stesso posto.
	print("     t       collo    scarto   stato        vede? collo? muta? pronta?")
	var t_att := _t()
	var t_ric := -1.0
	var girata := false
	var picco := PI
	while _t() - t_att < 25.0:
		await process_frame
		var muta := int(_cuore.call("deduzione_muta", id, SOGLIA)) >= 0
		var sc := _scarto(corpo, ancora)
		if not muta and t_ric < 0.0:
			t_ric = _t()
			print("     ---- pagata a t=%.2f, il muso la mancava di %.1f° ----"
					% [t_ric, rad_to_deg(sc)])
			# LA PELLICOLA COMINCIA QUI, nel frame in cui la ricevuta si paga:
			# la testa ci mette meno di un secondo ad arrivare, e una foto
			# scattata «dopo tot secondi» prende la posa a movimento finito.
			# LA PELLICOLA VA DI TRE QUARTI, e la scelta è di provino: sul
			# profilo la stessa imbardata di venticinque gradi su una testona
			# tonda si legge appena (la si è guardata), mentre di tre quarti
			# la faccia passa da frontale a girata e **gli occhi vanno dove va
			# il muso**. È la differenza fra una posa e un movimento.
			await _pellicola("%s_2_ricevuta_tre_quarti" % sigla, macchine[1], 6, 0.30,
					corpo, ancora)
			await _scatta("%s_2_ricevuta_profilo" % sigla, macchine[2]["occhio"],
					macchine[2]["centro"], macchine[2]["fov"])
			await _scatta("%s_2_ricevuta_larga" % sigla, macchine[0]["occhio"],
					macchine[0]["centro"], macchine[0]["fov"])
			await _scatta("%s_2_ricevuta_spalla" % sigla, macchine[3]["occhio"],
					macchine[3]["centro"], macchine[3]["fov"])
			if OS.get_environment("CHIBI_GIOSTRA") != "":
				await _giostra("%s_2_giostra" % sigla, corpo)
		if t_ric >= 0.0:
			picco = minf(picco, sc)
			if absf(_collo(corpo)) > 0.12:
				girata = true
			if _t() - t_ric > 5.0:
				break
		if fmod(_t(), 1.0) < 0.017:
			print("     %5.1f  %+6.1f°  %6.1f°   %-12s %-5s %-6s %-5s %s"
					% [_t(), rad_to_deg(_collo(corpo)), rad_to_deg(sc),
					str(corpo.get("_state")),
					"sì" if _si_vede(corpo) else "NO",
					"sì" if bool(corpo.call("collo_ci_arriva", ancora)) else "NO",
					"sì" if muta else "—",
					"sì" if int(_cuore.call("deduzione_pronta", id, SOGLIA, DED.ATTESA,
							DED.finestra(_cuore))) >= 0 else "—"])
	_dico(t_ric >= 0.0, "la ricevuta è stata pagata (t=%.2f)" % t_ric)
	_dico(girata, "la testa si è girata davvero (non è restata a zero)")
	# ⚠️ **QUESTA RIGA È DIVENTATA ROSSA DUE VOLTE SU NOVE RICEVUTE, E NON SO
	# ANCORA PERCHÉ.** Misurato su sei corse (nove ricevute pagate): sette
	# volte la testa arriva sul posto (picco fra 0.0° e 6.3°), due volte si
	# muove di pochi gradi e basta (26.2° → 28.2° e 25.6° → 23.3°) — cioè la
	# ricevuta è pagata, il bit è acceso, e il giocatore NON VEDE NIENTE. È il
	# guasto che tutta la ricevuta esiste per rendere impossibile, e vale la
	# pena che il banco lo faccia diventare rosso invece di arrotondarlo.
	#
	# Quello che si sa: tutte e due le volte era la SECONDA scena di una corsa
	# lunga (t=104 s e t=624 s), mentre le sette buone stavano sotto gli 80 s.
	# Due candidati che non ho saputo separare, e stanno tutti e due in
	# `Visitor._sguardo_applica`: (a) `bersaglio = mira - base * (1 -
	# CEDE_ALLO_STATO)`, cioè quanto la posa dello stato mangia lo scostamento;
	# (b) la stanchezza — questo banco FERMA l'orologio, quindi nessuno va mai
	# a dormire e il bisogno di energia può solo scendere. Chi ci torna misuri
	# `Visitors.debug_brain(i).needs["energia"]` all'istante della ricevuta.
	_dico(picco < deg_to_rad(20.0),
			"e ha PUNTATO l'ancora: dai %.1f° della posa ai %.1f° del picco"
					% [rad_to_deg(sc_prima), rad_to_deg(picco)])

	# IL TERZO TERMINE DEL CONFRONTO: la stessa inquadratura a sguardo
	# finito. Senza, «prima» e «durante» sarebbero due foto e basta — con,
	# sono un movimento che comincia e finisce, cioè l'unica cosa che
	# dimostra che quello che si è visto era la ricevuta e non la posa.
	await create_timer(PERCEZIONE.DURATA_SGUARDO + 0.8).timeout
	print("     a sguardo finito il muso la manca di nuovo di %.1f°"
			% rad_to_deg(_scarto(corpo, ancora)))
	await _terna("%s_3_dopo" % sigla, macchine)

	# ---- 6) IL CORPO ---------------------------------------------------
	#
	# DA QUI IN POI IL BANCO MOLLA LA PRESA: il corpo torna del gioco.
	_tieni = false
	print("\n  ── IL CORPO: l'agenda dice una cosa, la deduzione un'altra ──")
	_dico(int(_cuore.call("deduzione_pronta", id, SOGLIA, DED.ATTESA,
			DED.finestra(_cuore))) >= 0, "la deduzione è pronta a diventare un obiettivo")
	var azione_dedotta := DED.azione_di(dedotto)
	# L'AGENDA VUOLE QUATTRO CHIACCHIERE: è la stessa domanda che il registro
	# fa da solo al primo fronte, ed è quella che il dirottamento intercetta.
	_vis.call("debug_force_activity", indice, "quattro_chiacchiere")
	await create_timer(1.5).timeout
	var meta := _dove_va(corpo)
	print("     l'agenda: «quattro_chiacchiere» · la deduzione: «%s»" % azione_dedotta)
	print("     il corpo va verso %s (stato «%s»)" % [meta, str(corpo.get("_state"))])
	_dico(str(corpo.get("_state")) != "r_idle",
			"il corpo si è mosso: la deduzione è diventata un gesto")
	await create_timer(1.2).timeout
	await _terna("%s_3_in_cammino" % sigla, _macchine(corpo, ancora))
	var atteso := 0.0
	while atteso < 30.0 and str(corpo.get("_state")) == "walk":
		await create_timer(0.5).timeout
		atteso += 0.5
	var arrivo := corpo.global_position
	print("     arrivato dopo %.1f s in %s (stato «%s»)" % [atteso, arrivo, str(corpo.get("_state"))])
	# L'INQUADRATURA CHE CONTIENE TUTTI E DUE i posti: è la sola foto che
	# risponde alla domanda vera («il giocatore sa attribuire quello che
	# vede?»), perché ci si legge dentro la distanza fra la premessa e la
	# conseguenza.
	await _scatta("%s_4_arrivato_larga" % sigla,
			(ancora + arrivo) * 0.5 + Vector3(0, ancora.distance_to(arrivo) * 0.5 + 4.0,
					ancora.distance_to(arrivo) * 0.75 + 5.0),
			(ancora + arrivo) * 0.5, FOV_LARGO)
	await _terna("%s_4_arrivato" % sigla, _macchine(corpo, ancora))

	# ---- 7) LA DOMANDA VERA --------------------------------------------
	#
	# ⚠️ QUI SI GIUDICA LA FASE, non il codice. La ricevuta serve a rendere
	# ATTRIBUIBILE quello che viene dopo: «ha guardato lì, poi ci è andato».
	# Se il posto guardato e il posto in cui va sono due, il giocatore vede
	# un vicino che dà un'occhiata a una cosa e cammina verso un'altra — e
	# «una conseguenza che il giocatore non sa attribuire non attenua
	# l'effetto: LO INVERTE».
	var scarto_m := ancora.distance_to(arrivo)
	print("\n  ── LA DOMANDA VERA ──")
	print("     ha guardato : %s   (l'ancora del ricordo)" % ancora)
	print("     è andato    : %s   (la messa in scena di «%s»)" % [arrivo, azione_dedotta])
	print("     distanza    : %.2f m" % scarto_m)
	_dico(scarto_m < 3.0,
			"LA PREMESSA E LA CONSEGUENZA SONO LO STESSO POSTO (%.2f m): la scena si legge"
					% scarto_m)
	if scarto_m >= 3.0:
		print("     ⚠️  guarda un posto e ne raggiunge un altro a %.1f m: il giocatore" % scarto_m)
		print("         vede un'occhiata e un viaggio, e non ha modo di legarli.")

	# ---- 8) E POI PIÙ NIENTE -------------------------------------------
	_dico(int(_cuore.call("deduzione_pronta", id, SOGLIA, DED.ATTESA,
			DED.finestra(_cuore))) < 0, "la deduzione è spesa: non c'è più niente di pronto")
	var stessa := str(DED.dirotta(_cuore, id, "quattro_chiacchiere",
			r.get("luoghi", []), int(r.get("fatti", 0)), SOGLIA))
	_dico(stessa == "quattro_chiacchiere",
			"e il dirottamento restituisce la stessa Stringa che gli è arrivata")


# =========================================================================
# IL RITMO
# =========================================================================

func _ritmo(dt: float, giri: int) -> void:
	var mp: Dictionary = _pens.misure()
	var m: Dictionary = _llm.call("misure")
	print("\n\n" + "█".repeat(72))
	print("IL RITMO VERO, misurato adesso su questa macchina")
	print("█".repeat(72))
	var media := 0.0
	for x in _durate:
		media += float(x)
	media = media / maxf(float(_durate.size()), 1.0)
	print("  villaggio               : %d vicini · %d bozze per pensiero"
			% [_residenti.size(), _copie])
	print("  atto I                  : %.0f s per %d pensieri (%d lettere, %d silenzi)"
			% [dt, _lettere + _silenzi, _lettere, _silenzi])
	print("  una generazione          : %.1f s in media (prompt + %d bozze)"
			% [media, _copie])
	print("  tentativi muti           : %d (chi non aveva niente di vero da dire)"
			% int(mp["muti"]))
	print("  bozze generate           : %d · ammesse dal giudice %d (%.0f%%)"
			% [_bozze_tot, _bozze_ammesse,
			100.0 * float(_bozze_ammesse) / maxf(float(_bozze_tot), 1.0)])
	var pezzi := []
	for p in ["ancoraggio", "memoria", "forma", "parola"]:
		if _porte.has(p):
			pezzi.append("%d %s" % [int(_porte[p]), p])
	print("  bozze buttate, per porta : %s" % (", ".join(pezzi) if not pezzi.is_empty() else "nessuna"))
	print("  silenzio                 : %d volte su %d pensieri (%.0f%%)"
			% [_silenzi, _lettere + _silenzi,
			100.0 * float(_silenzi) / maxf(float(_lettere + _silenzi), 1.0)])
	print("  ⇒ UN VICINO OGNI        : %.0f s (%.1f min) con %d abitanti"
			% [PENSATOIO.attesa_stimata(_residenti.size(), media),
			PENSATOIO.attesa_stimata(_residenti.size(), media) / 60.0, _residenti.size()])
	print("  ⇒ e in un villaggio PIENO: %.0f min con 28 abitanti"
			% (PENSATOIO.attesa_stimata(28, media) / 60.0))
	print("  foglio (main thread)     : peggio %.3f ms — si paga una volta per generazione"
			% float(mp["foglio_ms_peggio"]))
	print("  motore                   : %s" % str(m))
	print("  foto scattate            : %d%s" % [_scatti,
			("" if _dove == "" else " in " + _dove)])
