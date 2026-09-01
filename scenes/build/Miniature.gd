extends Node
## LO STUDIO DELLE MINIATURE — il ritratto di ogni pezzo, fatto in casa.
##
## Il catalogo del builder è geometria PROCEDURALE: non esiste nessuna
## immagine da caricare, esiste una funzione che costruisce un `Node3D`.
## Qui c'è il piccolo studio fotografico che la trasforma in un ritratto:
## un `SubViewport` con un mondo tutto suo, tre luci, un disco d'ombra
## morbida sotto i piedi, e una camera che **calcola** l'inquadratura
## invece di indovinarla.
##
## LE QUATTRO REGOLE, e ognuna toglie un modo di far cadere il fotogramma:
##
##  1. **LA CODA È SERVITA A GETTONI, NON A RAFFICA.** Costruire un pezzo
##     vuol dire far girare il suo builder (per il Campanile sono migliaia
##     di triangoli cuciti a mano): senza un tetto, aprire l'Atelier
##     costruirebbe centotrentasette pezzi nello stesso fotogramma. I
##     gettoni sono gli STUDI (vedi la costante, con la misura A/B), e chi
##     non ne trova uno libero aspetta il fotogramma dopo. Le miniature
##     entrano con una dissolvenza, che è anche più bello di trovarle lì.
##  2. **SI PAGA UNA VOLTA SOLA.** Il ritratto finito resta in cache per
##     tutta la sessione: riaprire l'Atelier, cambiare categoria, cercare
##     e tornare indietro non costano un microsecondo.
##  3. **SI CHIEDE SOLO CIÒ CHE SI GUARDA.** Chi chiama passa i pezzi che
##     stanno davvero sotto gli occhi (vedi `BuildSystem._chiedi_visibili`),
##     e a ogni cambio di vista la coda si SVUOTA: sfogliare in fretta sei
##     categorie non deve lasciare in coda centotrenta ritratti che non
##     interessano più a nessuno.
##  4. **SENZA SCHERMO NON SI DISEGNA.** In `--headless` non c'è un
##     fotogramma da aspettare: lo studio nasce spento e non alloca
##     niente. Le prove e la suite non pagano nulla.
##
## L'inquadratura è la stessa del catalogo visivo
## ([`tools/scatto_catalogo.gd`](../../tools/scatto_catalogo.gd)): si misura
## l'ingombro VERO delle mesh visibili e si arretra quanto chiedono gli
## otto spigoli. Una camera fissa lascerebbe il fungo in un puntino e il
## campanile fuori campo — e con centotrentasette pezzi che vanno da dieci
## centimetri a due metri e mezzo, questa non è una raffinatezza.

## Il ritratto è pronto: chi ha una carta appesa a questo nome la vesta.
signal pronta(nome: String, tex: Texture2D)

## Il lato in pixel del ritratto. 128 e non 96: le carte si disegnano a 80
## e i bordi curvi di un tetto a 96 diventano una scaletta. Sono
## 128·128·4 = 64 KiB a pezzo, cioè 8,6 MiB per il catalogo INTERO — e in
## partita non si arriva mai a chiederlo tutto.
const LATO := 128
const FOV := 34.0
## ~23° sopra l'orizzonte: l'angolo delle foto dei cataloghi. Più in basso
## si vede solo la faccia, e un letto visto di faccia è una tavola.
const ELEVAZIONE := 0.42
## L'azimut del ritratto: tre quarti. Di fronte, metà dei pezzi è un
## rettangolo; di tre quarti si legge sempre di che cosa si tratta.
const AZIMUT := 0.7

const GEO := preload("res://scenes/world/WorldGeo.gd")

## QUANTI STUDI. Un ritratto costa **DUE fotogrammi d'attesa** — uno perché
## le mesh esistano davvero (l'ingombro si MISURA, e misurare un albero che
## non c'è ancora dà una scatola vuota), uno perché il quadro sia disegnato.
## Non è tempo di CPU: è latenza strutturale. Servendone uno per volta il
## catalogo si riempie alla velocità del FRAME RATE, non a quella della
## macchina, e trenta ritratti sono sessanta fotogrammi in fila.
##
## MISURATO nel MainLevel vero (Arredo, 30 ritratti, vsync SPENTO), e i
## numeri sono **scarti dal riposo della propria corsa** — mai millisecondi
## nudi: due corse diverse non sono confrontabili, e in questa serie il
## riposo è passato da 38,6 a 44,3 ms secondo quanto era carica la macchina.
##
## | studi | la griglia è piena dopo | fotogramma mentre dipinge | il PEGGIORE |
## |---|---|---|---|
## | 1 | **3175 ms** | +7,66 ms | +48,40 ms |
## | 4 | **935 ms** | +16,81 ms | +47,93 ms |
##
## Il **fotogramma peggiore non cambia** — mezzo millisecondo su quarantotto:
## lo fa un singolo builder pesante, non la concorrenza. Quello che cambia è
## il transitorio di carte bianche, da tre secondi a meno di uno, ed è
## l'unica delle due cose che il giocatore vede. Ogni studio ha un mondo suo:
## due pezzi nello stesso mondo si fotograferebbero a vicenda.
##
## ⚠️ La prima stesura di questa tabella deduceva «non cambia» da 87,9
## contro 86,3 — millisecondi NUDI di due corse diverse, cioè proprio il
## confronto che la riga sopra vieta, e per giunta col vsync acceso (che
## allinea i delta ai refresh e nasconde una differenza più piccola di
## 16,67 ms). La conclusione reggeva, il modo di ricavarla no.
const STUDI := 4

var _studi: Array[Dictionary] = []      # {sv, cam, disco}
var _liberi: Array[int] = []
var _spento := true

var _cache := {}                  # nome -> ImageTexture
var _coda: Array[String] = []     # i nomi da ritrarre, in ordine di vista
var _in_coda := {}
var _builder := {}                # nome -> Callable (il builder del catalogo)

# --- il metro (si legge con `misure()`): un banco deve poter dire quanto
# costa una miniatura senza che nessuno debba crederci sulla parola ---
var _n := 0
var _us_tot := 0
var _us_max := 0
var _us_ultimo := 0


func _ready() -> void:
	set_process(false)
	# NIENTE SCHERMO, NIENTE STUDIO. `await RenderingServer.frame_post_draw`
	# in headless è un'attesa che non finisce: la coda resterebbe piena e
	# gli studi occupati per sempre, in silenzio.
	if DisplayServer.get_name() == "headless":
		return
	_spento = false
	for i in STUDI:
		_studi.append(_studio_nuovo())
		_liberi.append(i)
	set_process(true)


func spento() -> bool:
	return _spento


# ------------------------------------------------------------- l'anagrafe

## Il ritratto se c'è già (mai un'attesa): `null` vuol dire «non ancora».
func presa(nome: String) -> Texture2D:
	return _cache.get(nome, null)


## Mettiti in coda. L'ordine di chiamata È l'ordine di servizio, quindi chi
## chiama passa prima quello che sta in cima allo schermo.
func chiedi(nome: String, builder: Callable) -> void:
	if _spento or _cache.has(nome) or _in_coda.has(nome) or not builder.is_valid():
		return
	_builder[nome] = builder
	_in_coda[nome] = true
	_coda.append(nome)


## Si cambia vista: quello che nessuno guarda più esce dalla coda. Il
## ritratto in corso si lascia finire — è già mezzo pagato.
func svuota_coda() -> void:
	_coda.clear()
	_in_coda.clear()


## Quanto è costato, davvero. (n, medio, peggiore, memoria)
func misure() -> Dictionary:
	return {
		"n": _n,
		"us_medio": int(float(_us_tot) / float(maxi(_n, 1))),
		"us_max": _us_max,
		"us_ultimo": _us_ultimo,
		"kib": _n * LATO * LATO * 4 / 1024,
		"in_coda": _coda.size(),
	}


# ------------------------------------------------------------- lo studio

func _studio_nuovo() -> Dictionary:
	var _sv := SubViewport.new()
	_sv.size = Vector2i(LATO, LATO)
	# IL MONDO È SUO. Senza, il ritratto si prenderebbe il villaggio come
	# sfondo — il cielo, la nebbia, i vicini che passano.
	_sv.own_world_3d = true
	_sv.world_3d = World3D.new()
	_sv.transparent_bg = true
	_sv.msaa_3d = Viewport.MSAA_4X
	_sv.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_sv)

	var we := WorldEnvironment.new()
	var env := Environment.new()
	# CLEAR_COLOR e non COLOR: è quello che lascia passare la trasparenza,
	# e una miniatura ritagliata si posa sulla carta della sua scheda
	# invece di metterci sopra un francobollo grigio.
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.90, 0.90, 0.95)
	env.ambient_light_energy = 0.95
	we.environment = env
	_sv.add_child(we)

	var chiave := DirectionalLight3D.new()
	chiave.rotation_degrees = Vector3(-42, -38, 0)
	chiave.light_energy = 0.9
	_sv.add_child(chiave)
	var contro := DirectionalLight3D.new()
	contro.rotation_degrees = Vector3(-14, 146, 0)
	contro.light_energy = 0.30
	contro.light_color = Color(1.0, 0.96, 0.88)
	_sv.add_child(contro)

	# L'OMBRA. Senza, ogni pezzo galleggia in un vuoto bianco e le carte
	# sembrano ritagli. Non è l'ombra vera (una sola luce con la mappa
	# d'ombra accesa costa più di tutto il resto messo insieme): è il
	# disco morbido dei cataloghi, che dice «poggia per terra» e basta.
	var _disco := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(1, 1)
	qm.orientation = PlaneMesh.FACE_Y
	_disco.mesh = qm
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.albedo_texture = GEO.soft_circle(Color(0.30, 0.22, 0.16, 0.34), 0.45)
	dm.albedo_color = Color(1, 1, 1, 1)
	_disco.material_override = dm
	_sv.add_child(_disco)

	var _cam := Camera3D.new()
	_cam.fov = FOV
	_cam.current = true
	_sv.add_child(_cam)
	return {"sv": _sv, "cam": _cam, "disco": _disco}


func _process(_delta: float) -> void:
	# si servono tutti gli studi liberi, non uno: è questo a dare il x4
	while not _coda.is_empty() and not _liberi.is_empty():
		_ritrai(_coda.pop_front(), _liberi.pop_back())


func _ritrai(nome: String, studio: int) -> void:
	_in_coda.erase(nome)
	var st: Dictionary = _studi[studio]
	var _sv: SubViewport = st["sv"]
	var _cam: Camera3D = st["cam"]
	var _disco: MeshInstance3D = st["disco"]
	var t0 := Time.get_ticks_usec()
	var b: Callable = _builder.get(nome, Callable())
	var nodo: Node3D = null
	if b.is_valid():
		nodo = b.call() as Node3D
	if nodo == null:
		_liberi.append(studio)
		return
	_prepara(nodo)
	_sv.add_child(nodo)
	# un fotogramma perché le mesh esistano davvero: l'ingombro si MISURA,
	# e misurare un albero che non c'è ancora dà una scatola vuota
	await get_tree().process_frame
	if not is_instance_valid(nodo) or not is_instance_valid(_sv):
		_liberi.append(studio)
		return
	var ing := _ingombro(nodo)
	# I PEZZI DEL PIANO DI SOPRA STANNO SOTTO ZERO. Il Solaio ha il
	# calpestio a quota zero e le travi che pendono sotto: nello studio
	# finirebbe mezzo dentro l'ombra, e sembrerebbe un asset rotto.
	if ing.position.y < -0.001:
		nodo.position.y = -ing.position.y
		ing.position.y = 0.0
	var largo: float = maxf(maxf(ing.size.x, ing.size.z), 0.25)
	_disco.scale = Vector3(largo * 1.7, 1.0, largo * 1.7)
	_disco.position = Vector3(ing.position.x + ing.size.x * 0.5, 0.004,
			ing.position.z + ing.size.z * 0.5)
	_inquadra(_cam, ing)
	_sv.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	if not is_instance_valid(_sv):
		_liberi.append(studio)
		return
	var img := _sv.get_texture().get_image()
	var tex := ImageTexture.create_from_image(img)
	_cache[nome] = tex
	if is_instance_valid(nodo):
		_sv.remove_child(nodo)
		nodo.queue_free()
	var costo := Time.get_ticks_usec() - t0
	_us_ultimo = costo
	_us_tot += costo
	_us_max = maxi(_us_max, costo)
	_n += 1
	_liberi.append(studio)
	pronta.emit(nome, tex)


## Un pezzo posato nel villaggio ha una vita: le particelle emettono, le
## lanterne illuminano, i collettori fermano la pioggia. Un RITRATTO no —
## dura un fotogramma, e tutto quello che ha bisogno di tempo per farsi
## vedere qui è solo un costo.
func _prepara(nodo: Node3D) -> void:
	for l in nodo.find_children("*", "Light3D", true, false):
		# le luci restano ACCESE (un lampione spento non è un lampione),
		# ma senza mappa d'ombra: è la voce più cara di questo studio
		(l as Light3D).shadow_enabled = false
	for p in nodo.find_children("*", "GPUParticles3D", true, false):
		(p as GPUParticles3D).emitting = false
	for pc in nodo.find_children("*", "GPUParticlesCollision3D", true, false):
		(pc as GPUParticlesCollision3D).cull_mask = 0
	for c in nodo.find_children("*", "CollisionShape3D", true, false):
		(c as CollisionShape3D).disabled = true


## L'ingombro conta SOLO le mesh che si vedono: un pezzo si porta dietro
## nodi nascosti, e contandoli l'inquadratura si allarga su del vuoto.
func _mesh_aabb(n: Node, radice: Node3D) -> Array:
	var out: Array = []
	if n is Node3D and not (n as Node3D).visible:
		return out
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var tr := Transform3D.IDENTITY
		var cur := n as Node3D
		while cur != null and cur != radice:
			tr = cur.transform * tr
			cur = cur.get_parent() as Node3D
		out.append(tr * (n as MeshInstance3D).mesh.get_aabb())
	for f in n.get_children():
		out.append_array(_mesh_aabb(f, radice))
	return out


func _ingombro(n: Node3D) -> AABB:
	var tutti := _mesh_aabb(n, n)
	if tutti.is_empty():
		return AABB(Vector3(-0.3, 0, -0.3), Vector3(0.6, 0.6, 0.6))
	var out: AABB = tutti[0]
	for i in range(1, tutti.size()):
		out = out.merge(tutti[i])
	return out


## L'INQUADRATURA SI CALCOLA SUGLI OTTO SPIGOLI, non sul centro. Misurare
## la larghezza e arretrare in proporzione sembra giusto e non lo è: quella
## misura vale sul piano del centro, mentre la faccia davanti sta mezza
## profondità PIÙ VICINA — e in prospettiva, più vicino vuol dire più
## grande. Arretrando lungo l'asse gli scostamenti laterali degli spigoli
## non cambiano, quindi basta prendere l'arretramento più grande che
## chiedono gli otto: una passata sola, e vale per qualunque forma.
func _inquadra(_cam: Camera3D, a: AABB) -> void:
	var centro := a.position + a.size * 0.5
	var dir := Vector3(sin(AZIMUT), ELEVAZIONE, -cos(AZIMUT)).normalized()
	var t := tan(deg_to_rad(FOV * 0.5))
	var dist: float = maxf(a.size.length(), 0.2)
	var pos := centro + dir * dist
	var fwd := (centro - pos).normalized()
	var destra := fwd.cross(Vector3.UP).normalized()
	var su := destra.cross(fwd).normalized()
	var arretra := 0.0
	for ix in 2:
		for iy in 2:
			for iz in 2:
				var ang := a.position + Vector3(a.size.x * float(ix),
						a.size.y * float(iy), a.size.z * float(iz))
				var v := ang - pos
				var scarto: float = maxf(absf(v.dot(destra)), absf(v.dot(su)))
				arretra = maxf(arretra, scarto / t - v.dot(fwd))
	dist = (dist + arretra) * 1.10        # un filo d'aria attorno
	_cam.position = centro + dir * dist
	_cam.look_at(centro, Vector3.UP)
