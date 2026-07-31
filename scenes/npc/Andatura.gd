extends RefCounted

## L'ANDATURA CHIBI — il modo di camminare di questa specie, in un posto solo.
##
## Non è «un ciclo di camminata»: è il modo in cui si muovono le creature di
## questo gioco, e sono i dettagli a dirlo. La fase avanza coi METRI
## PERCORSI (mai moonwalk); il blend accende e spegne il passo da solo, così
## fermarsi a metà passo sfuma invece di scattare; il corpo si PIEGA dentro
## le curve; la punta della coda è in ritardo di fase sulla base — il colpo
## di frusta che rende viva una coda; le orecchie sbattono col saltello e
## restano basse se chi cammina è anziano; e il passo SUONA nell'istante
## dell'appoggio, non a intervalli.
##
## Viveva dentro `Visitor.gd`, dove serviva ai vicini del villaggio. Poi il
## menù principale ha avuto bisogno degli stessi vicini che camminano nel
## diorama, e c'erano due strade: riscrivere il passo (due andature diverse
## per gli stessi personaggi, e la seconda peggiore) oppure tirarlo fuori di
## lì. È tirato fuori di qui. `Visitor` lo chiama come prima — i suoi
## `_gait_misura`/`_gait_chibi` adesso sono due righe che delegano — e il
## diorama del titolo usa lo stesso oggetto.
##
## Puro nel senso che conta: non conosce l'albero della scena, non cerca
## nodi, non ha stati. Gli si danno le parti del corpo (quelle che
## `ChibiBuilder.build` restituisce) e ogni frame la posizione: fa il resto.

## Quanti radianti di fase per ogni metro percorso. Alla velocità di
## crociera è la cadenza di sempre.
const RAD_PER_METRO := 5.5
## Sopra questa velocità è un teletrasporto, non un passo.
const VELOCITA_ASSURDA := 2.8
## Sotto questa velocità si è fermi.
const VELOCITA_FERMO := 0.12

# le parti che muove (da ChibiBuilder.build)
var vis: Node3D               # il nodo che porta tutto il corpo
var testa: Node3D
var braccia: Array = []
var gambe: Array = []
var orecchie: Array = []
var coda: Node3D
var coda_punta: Node3D

# --- lo stato del passo ---
var fase := 0.0               # la fase del ciclo, in radianti
var blend := 0.0              # 0 fermo, 1 in cammino: si accende e spegne
var banco := 0.0              # l'inclinazione in curva, fusa
var wag := 0.0                # l'orologio dello scodinzolio
var _prev_pos := Vector3.INF
var _prev_yaw := 0.0
var _prev_cos := 1.0
var _t := 0.0

## Quanto è vecchio chi cammina, 0..1: la gobba, le orecchie stanche, la
## coda che scodinzola meno.
var eta := 0.0
## Quanto sta cercando riparo dalla pioggia, 0..1: passetto più fitto e
## più basso.
var riparo := 0.0

## Chi suona il passo. Lasciarlo null per un'andatura muta (il diorama del
## titolo: dodici passi che scricchiolano dietro un menù sono rumore).
var sfx = null
## Il volume del passo, in dB.
var passo_db := -22.0


func parti(p: Dictionary, nodo_vis: Node3D) -> void:
	vis = nodo_vis
	testa = p.get("head")
	braccia = p.get("arms", [])
	gambe = p.get("legs", [])
	orecchie = p.get("ears", [])
	coda = p.get("tail")
	coda_punta = p.get("tail_tip")


## MISURA: la velocità VERA, il blend, la piega in curva, l'orologio della
## coda. Va chiamata ogni frame per OGNI stato — anche da fermo, anche
## mentre si dorme: è così che il passo si spegne in dolcezza invece di
## restare acceso a mezz'aria.
func misura(delta: float, posizione: Vector3, yaw: float) -> void:
	_t += delta
	if _prev_pos.x == INF:
		_prev_pos = posizione
		_prev_yaw = yaw
	var d := posizione - _prev_pos
	_prev_pos = posizione
	var v := Vector2(d.x, d.z).length() / maxf(delta, 0.0001)
	if v > VELOCITA_ASSURDA:
		v = 0.0
	blend = lerpf(blend, 1.0 if v > VELOCITA_FERMO else 0.0, 1.0 - exp(-8.0 * delta))
	if v > VELOCITA_FERMO:
		fase += v * delta * RAD_PER_METRO * (1.0 + 0.42 * riparo)
	var rate := wrapf(yaw - _prev_yaw, -PI, PI) / maxf(delta, 0.0001)
	_prev_yaw = yaw
	banco = lerpf(banco, clampf(-rate * 0.16, -0.13, 0.13) * blend,
			1.0 - exp(-7.0 * delta))
	wag += delta * (1.6 + 2.6 * blend)


## APPLICA: scrive il passo sul corpo, fuso col blend. Da fermo il ciclo si
## spegne da solo — è il blend a decidere quanto ciclo si vede, mai lo stato
## di chi cammina.
func applica() -> void:
	if vis == null:
		return
	var hop := absf(sin(fase)) * blend
	# respiro da fermo, saltello in cammino (che si posa con gli anni e si
	# abbassa sotto la pioggia), dondolio e banco in curva
	vis.position.y = absf(sin(_t * 3.0)) * 0.015 * (1.0 - blend) \
			+ hop * 0.045 * (1.0 - 0.5 * eta) * (1.0 - 0.35 * riparo)
	vis.rotation.z = sin(fase) * 0.05 * (1.0 - 0.4 * riparo) * blend + banco
	vis.rotation.x = -0.05 * blend - 0.28 * eta
	var swing := sin(fase) * 0.45 * blend
	if braccia.size() == 2:
		braccia[0].rotation.x = swing
		braccia[1].rotation.x = -swing
		# la torsione: il braccio RUOTA mentre oscilla
		braccia[0].rotation.y = -sin(fase - 0.4) * 0.12 * blend
		braccia[1].rotation.y = sin(fase - 0.4) * 0.12 * blend
	# i piedini: fase aerea e appoggio in controfase, fusi col blend
	for li in gambe.size():
		var gamba: Node3D = gambe[li]
		var pp := fase + (0.0 if li == 0 else PI)
		gamba.rotation.x = -sin(pp) * 0.6 * blend
		gamba.position.y = 0.16 + maxf(0.0, cos(pp)) * 0.05 * blend
	for ear: Node3D in orecchie:
		ear.rotation.x = -hop * 0.22 + 0.38 * eta   # orecchie stanche
	if coda:
		coda.rotation.y = sin(wag) * (0.22 + 0.12 * blend) * (1.0 - 0.55 * eta)
	if coda_punta:
		# la punta in ritardo di fase: il colpo di frusta
		coda_punta.rotation.y = sin(wag - 0.9) * (0.2 + 0.1 * blend) * (1.0 - 0.55 * eta)
	if testa:
		testa.rotation.x = hop * 0.05
		# da fermo la testolina si guarda intorno; in cammino guarda avanti
		testa.rotation.y = sin(_t * 0.8) * 0.25 * (1.0 - blend)
	# il passo suona nell'ISTANTE dell'appoggio
	var c := cos(fase)
	if blend > 0.4 and c * _prev_cos < 0.0 and sfx:
		sfx.play("step_grass" + str(1 + randi() % 3), passo_db, 1.05)
	_prev_cos = c


## LA RETE DI SICUREZZA. Riporta a riposo i canali che solo certe pose
## scrivono (la coda arrotolata del sonno, le spalle chiuse): se una posa
## viene troncata a metà — e succede — senza questa il corpo resterebbe
## storto per il resto della partita.
func rilassa(delta: float) -> void:
	var k := 1.0 - exp(-8.0 * delta)
	if coda:
		coda.rotation.x = lerpf(coda.rotation.x, 0.0, k)
	if coda_punta:
		coda_punta.rotation.x = lerpf(coda_punta.rotation.x, 0.0, k)
	if braccia.size() == 2:
		braccia[0].rotation.z = lerpf(braccia[0].rotation.z, -0.32, k)
		braccia[1].rotation.z = lerpf(braccia[1].rotation.z, 0.32, k)
