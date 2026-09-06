extends RefCounted

## LA REGOLAZIONE ARRIVA AL CORPO — e ci arriva con la parola GIUSTA.
##
## ⚠️ **PERCHÉ QUESTO FILE ESISTE.** Il cablaggio della rilettura vive in
## `Visitors._tick_confronti`, e in tutta la suite non aveva **un solo
## lettore comportamentale**: l'unica guardia era
## `test_rilettura._la_frase_e_cablata`, che cerca nel SORGENTE la stringa
## `chiedi_gesto(label, "ha_riletto")` e l'assenza di `limbico.trattieni()`.
## Due modifiche plausibili la superano tutte e due:
##
##  (a) **togliere il `continue`** del ramo `rilettura`: chi rilegge cade
##      nell'`else` e riceve ANCHE `chiedi_gesto(label, "si_e_trattenuto")`
##      — il corpo del morso addosso a chi non si è morso la lingua;
##  (b) **scambiare le due occasioni** fra il ramo `rilettura` e l'`else`:
##      tutte e due le stringhe restano nel sorgente, quindi il `contains`
##      passa identico.
##
## In tutti e due i casi il giocatore vede la **premessa sbagliata**, che è
## il guasto che «non attenua l'effetto, lo inverte»: il Rialzo del sollievo
## dove si è pagato, e il Raccolto della rinuncia dove non si è pagato
## niente. Un source-check non può vederlo perché guarda le PAROLE nel file,
## non quale delle due esce da quale ramo.
##
## Perciò qui non si legge nessun sorgente. Si monta un registro VERO con
## corpi VERI, si costruiscono tre storie che portano ai tre modi di
## `Animo.regola` (rilettura · morso · scoppio), si chiama `_tick_confronti`
## e si guarda **quale occasione arriva a `chiedi_gesto`**.
##
## ⚠️ **L'OCCASIONE SI REGISTRA ALL'INGRESSO, prima dei sette cancelli del
## villaggio.** Se quel gesto sia poi CONCESSO è un'altra domanda, e ce l'ha
## già `test_gesti`: qui la domanda è quale parola il villaggio abbia detto,
## e un gesto rifiutato dal gettone o dal buio l'ha detta lo stesso.
##
## ⚠️ **E il terzo residente non è decorazione: è la CONTROPROVA.** «Chi
## rilegge non lascia traccia» non vuol dire niente finché non si vede
## qualcuno che la traccia la lascia davvero — lo `scoppio`, che nello stesso
## identico giro scrive il toast e impone la postura.
##
## Le trappole di banco già pagate scrivendolo stanno accanto a ogni riga che
## le riguarda; le tre grosse in cima al `_banco`.
##
## ── LE CINQUE MUTAZIONI, provate una per volta, tutte ROSSE ───────────────
## Non si è toccato `Visitors.gd` (lo stava editando un'altra sessione): la
## mutazione si è applicata a una COPIA temporanea del file, con una copia di
## questo caso che la estendeva al posto dell'originale. Numeri misurati:
##
##  | mutazione, in `Visitors._tick_confronti`            | rosse |
##  |-----------------------------------------------------|-------|
##  | (a) via il `continue` del ramo `rilettura`           |   2   |
##  | (b) le due occasioni scambiate fra i due rami        |   4   |
##  | (c) la rilettura impone anche lei una postura        |   1   |
##  | (d) via il raffreddamento (`_sussulto_cd["morso_…"]`)|   3   |
##  | (e) il ramo `rilettura` non chiede nessun gesto      |   2   |
##
## (a) e (b) sono le due che il source-check di `test_rilettura` non può
## vedere, ed è per loro che questo file esiste.

const DNA := preload("res://scenes/npc/ChibiDNA.gd")
const ANIMO := preload("res://scenes/npc/Animo.gd")

## Un carattere qualunque: il modo NON dipende dai tratti (lo prova
## `test_rilettura._non_e_un_tratto`), quindi qui non ne serve uno scelto.
const TRATTI := {"codardia": 0.50, "grinta": 0.50, "lealta": 0.50,
		"ambizione": 0.50, "orgoglio": 0.50}

## ⚠️ **IL GRADINO NON SI SCRIVE «2»: SI RICAVA DALLA SCALA.** Il ramo che si
## prova vive in una finestra — almeno «svogliato», e **sotto** «confronto»,
## che porta da un'altra parte (lo sfogo). Un indice a mano si sposta in
## silenzio il giorno che qualcuno infila un gradino in mezzo, e il banco
## finirebbe a provare l'altro ramo restando verde: è la stessa mina che
## `Animo.SCALA` è diventata fonte unica per disinnescare.
const GRADINO := "attrezzi"

## Etichette LUNGHE e distinte apposta: il toast dello scoppio si riconosce
## cercandoci dentro il nome, e con etichette da un carattere qualunque
## parola italiana della frase le farebbe combaciare per sbaglio.
const CHI_RILEGGE := "Chi_rilegge"
const CHI_MORDE := "Chi_morde"
const CHI_SCOPPIA := "Chi_scoppia"


func run(t) -> void:
	_ogni_modo_porta_la_sua_occasione(t)
	_chi_rilegge_non_lascia_traccia_e_chi_scoppia_si(t)
	_i_contatori_dicono_i_modi_giusti(t)


# ==========================================================================
# IL BANCO
# ==========================================================================

## Il registro dei vicini VERO, col solo `_ready` scavalcato — la stessa
## forma di `test_cricche_corpo.Registro`, e per la stessa ragione: il suo
## `_ready` vuole `%Player` e `../BuildSystem`, cioè il villaggio intero.
##
## Di finto ci sono DUE cose sole, e nessuna delle due decide niente:
##
## · `chiedi_gesto` REGISTRA la coppia e poi chiama `super()`, così l'usciere
##   vero gira davvero (è l'idioma di `guarda_gesto` in `test_deduzioni`: un
##   doppio che reimplementa la cosa da provare la lascia senza lettori);
## · `_show_toast` registra e basta — e qui il `super()` **non si può**
##   chiamare: la Label del toast la costruisce `Visitors._ready`, che questo
##   banco salta apposta, e chiamarlo darebbe «null instance», cioè un errore
##   a runtime che **non fa fallire niente** e tronca il caso lasciando la
##   suite verde. Registrarlo, oltre a essere l'unica strada, è anche quello
##   che serve: la traccia a schermo è proprio la cosa da guardare.
class Registro extends "res://scenes/npc/Visitors.gd":
	var chieste: Array = []   # [label, occasione], nell'ordine di arrivo
	var toast: Array = []     # ogni frase mandata a schermo

	func _ready() -> void:
		set_process(false)
		set_physics_process(false)

	func _process(_d: float) -> void:
		pass

	func chiedi_gesto(label: String, occasione: String, extra := {},
			conta := true) -> bool:
		chieste.append([label, occasione])
		return super(label, occasione, extra, conta)

	func _show_toast(text: String) -> void:
		toast.append(text)


## Il corpo VERO, con una cosa sola di finto: `chat_bubble` REGISTRA invece
## di disegnare.
##
## ⚠️ **E registrarla è anche l'unica cosa che si POSSA guardare qui: la
## bolla vera è un nodo con un tween che si libera da sé, e in un banco dove
## non passa nessun fotogramma quel tween non viene mai smaltito** — il
## processo esce con «ObjectDB instances were leaked», in modo intermittente,
## che è il rumore peggiore che un banco possa lasciare (una riga che qualche
## volta c'è e qualche volta no non la si può nemmeno diagnosticare). Quello
## che si prova qui è CHE una bolla venga chiesta, e a chi — non come la si
## disegna, che è il mestiere del vocabolario del corpo. Tutto il resto —
## `frase`, `is_hidden`, `dorme`, `in_scena`, il rig — resta di produzione.
class Corpo extends "res://scenes/npc/Visitor.gd":
	var bolle: Array = []     # ogni simbolo chiesto sopra la testa

	func chat_bubble(sym: String) -> void:
		bolle.append(sym)


## Tre residenti a un metro da Mochi, con tre storie che portano ai tre modi.
##
## ⚠️ **TRE TRAPPOLE PAGATE QUI DENTRO:**
##
## 1. **In un caso di test non passa nessun fotogramma**, quindi niente
##    `await` e niente `call_deferred`: `_tick_confronti` si chiama a mano, e
##    i corpi hanno il `_process` spento perché non lo faccia girare nessun
##    altro.
## 2. **I corpi sono `Visitor` VERI, non un `Node3D` con due metodi.** Il
##    ramo del morso tocca il corpo (la postura, la bolla, e quel che ci
##    verrà messo domani): un doppio con solo i metodi di oggi trasforma
##    l'aggiunta di riga di domani in un errore a runtime — che non fa
##    fallire niente, tronca il caso e lascia la suite verde. Di finto c'è
##    solo la bolla, e il perché sta sopra `Corpo`.
## 3. **La storia si scrive PRIMA del gradino.** `Animo.ricorda` non tocca
##    `gradino` (lo muove `passa_giorno`), ma l'ordine giusto è comunque
##    quello: prima i fatti, poi dove sta sulla scala.
func _banco(t) -> Dictionary:
	var casa := Node3D.new()
	casa.name = "Villaggio"
	t.stage(casa)

	# Mochi all'origine: il ramo che si prova vuole il giocatore a meno di
	# 2,6 m (è la condizione scritta in `_tick_confronti`).
	var mochi := Node3D.new()
	mochi.name = "Mochi"
	casa.add_child(mochi)
	mochi.global_position = Vector3.ZERO

	var vis = Registro.new()
	vis.name = "Visitors"
	casa.add_child(vis)
	vis.set("_player", mochi)

	var animi := {}
	var corpi := {}
	var i := 0
	for label in [CHI_RILEGGE, CHI_MORDE, CHI_SCOPPIA]:
		var c = Corpo.new()
		# il genoma si dà PRIMA che l'albero chiami `_ready`: senza, il
		# `Visitor` monta un riccio invece di un chibi
		c.species = "chibi"
		c.mode = "resident"
		c.dna = DNA.generate(4507 + i * 131)
		casa.add_child(c)
		c.set_process(false)     # nessun fotogramma deve muovere questo corpo
		c.dna["name"] = label
		c.global_position = Vector3(0.8 + 0.3 * float(i), 0.0, 0.0)

		var a = ANIMO.new()
		a.setup({"name": label, "tratti": TRATTI.duplicate(),
				"sogno": "combattere"})
		# LE TRE STORIE. Dieci gentilezze e tre torti sono la storia che
		# `test_rilettura` misura come «si rilegge»; senza le gentilezze non
		# c'è nessuna prova che assolva, e si scende al morso.
		if label == CHI_RILEGGE:
			for _g in 10:
				a.ricorda("regalo", "giocatore", 0.8, 0.9)
		for _x in 3:
			a.ricorda("ignorato", "giocatore", -0.8, 0.9)
		# …e chi scoppia è chi la forza di trattenersi l'ha finita. Non è una
		# scorciatoia del banco: è lo stato che `Limbico.trattieni` produce
		# dopo qualche morso, e l'unico modo di averlo senza far passare una
		# giornata intera.
		if label == CHI_SCOPPIA:
			a.limbico.regolazione = 0.0
		a.gradino = ANIMO.indice(GRADINO)

		animi[label] = a
		corpi[label] = c
		(vis.get("_animi") as Dictionary)[label] = a
		vis._residents.append({"node": c, "label": label, "dna": c.dna,
				"cell": Vector2i(0, 0), "species": "chibi",
				"gradino": a.gradino, "next_act": 0.0, "phase": "day"})
		i += 1

	return {"casa": casa, "vis": vis, "mochi": mochi, "animi": animi,
			"corpi": corpi}


## Le occasioni chieste per un'etichetta, nell'ordine.
func _occasioni(vis, label: String) -> Array:
	var out: Array = []
	for c in vis.chieste:
		if str((c as Array)[0]) == label:
			out.append(str((c as Array)[1]))
	return out


## Il banco sta DAVVERO nella finestra che crede: la geometria e il gradino
## si asseriscono invece di essere sperati. Senza, il giorno che qualcuno
## sposta una soglia questo file proverebbe un altro ramo restando verde.
func _il_banco_e_nella_finestra(t, b: Dictionary) -> void:
	t.ok(ANIMO.almeno(ANIMO.indice(GRADINO), "svogliato"),
			"il gradino di prova e' almeno «svogliato»: sotto, il ramo della "
			+ "regolazione non gira affatto")
	t.ok(not ANIMO.almeno(ANIMO.indice(GRADINO), "confronto"),
			"…e sta sotto «confronto», o si proverebbe lo sfogo invece della "
			+ "regolazione")
	var mochi: Node3D = b["mochi"]
	for label in [CHI_RILEGGE, CHI_MORDE, CHI_SCOPPIA]:
		var d: float = mochi.global_position.distance_to(
				(b["corpi"][label] as Node3D).global_position)
		t.ok(d < 2.6, "%s e' dentro i 2,6 m da Mochi (%.2f m)" % [label, d])


# ── 1 ─────────────────────────────────────────────────────────────────────
## ⚠️ **IL CASO CHE CHIUDE LE DUE MUTAZIONI.** Un giro solo di
## `_tick_confronti`, tre storie diverse, e si guarda la parola che esce.
##
## · togliendo il `continue` del ramo `rilettura`, chi rilegge riceve DUE
##   occasioni e la seconda e' quella del morso → tre asserzioni rosse;
## · scambiando le due occasioni fra i rami, tutte e due le etichette
##   ricevono la parola dell'altra → quattro asserzioni rosse.
func _ogni_modo_porta_la_sua_occasione(t) -> void:
	var b := _banco(t)
	_il_banco_e_nella_finestra(t, b)
	var vis = b["vis"]
	vis.call("_tick_confronti", 0.1)

	var ril := _occasioni(vis, CHI_RILEGGE)
	t.ok(ril.has("ha_riletto"),
			"chi rilegge riceve l'occasione della RILETTURA (ottenute %s)"
					% str(ril))
	t.ok(not ril.has("si_e_trattenuto"),
			("…e MAI quella del morso: il Raccolto addosso a chi non ha "
			+ "pagato niente e' la premessa sbagliata, e una premessa "
			+ "sbagliata inverte l'effetto (ottenute %s)") % str(ril))
	t.eq(ril.size(), 1,
			("e ne riceve UNA SOLA: il ramo della rilettura esce col "
			+ "`continue`, non cade nell'else (ottenute %s)") % str(ril))

	var mor := _occasioni(vis, CHI_MORDE)
	t.ok(mor.has("si_e_trattenuto"),
			"chi si morde la lingua riceve l'occasione del MORSO (ottenute %s)"
					% str(mor))
	t.ok(not mor.has("ha_riletto"),
			("…e MAI quella della rilettura: il Rialzo del sollievo su chi "
			+ "ha appena speso la sua forza (ottenute %s)") % str(mor))

	# ⚠️ e chi scoppia non prende la parola di nessuno degli altri due: la
	# sua scena e' il toast e la postura, non un gesto del vocabolario.
	var sco := _occasioni(vis, CHI_SCOPPIA)
	t.ok(not sco.has("ha_riletto"),
			"chi scoppia non riceve l'occasione della rilettura (ottenute %s)"
					% str(sco))


# ── 2 ─────────────────────────────────────────────────────────────────────
## ⚠️ **«RILEGGERE È NON PAGARE», e qui si guarda che non paghi DAVVERO.**
## Nello stesso identico giro: chi rilegge non spende regolazione, non manda
## niente a schermo e non si ritrova addosso nessuna postura; chi si morde la
## lingua la regolazione la spende; chi scoppia lascia la traccia che è la
## CONTROPROVA — senza di lei «nessuna traccia» sarebbe un'asserzione che non
## sa fallire, perché in quel giro nessuno ne lascia.
func _chi_rilegge_non_lascia_traccia_e_chi_scoppia_si(t) -> void:
	var b := _banco(t)
	var vis = b["vis"]
	var animi: Dictionary = b["animi"]
	var corpi: Dictionary = b["corpi"]

	var prima := {}
	var posture_prima := {}
	for label in [CHI_RILEGGE, CHI_MORDE, CHI_SCOPPIA]:
		prima[label] = float(animi[label].limbico.regolazione)
		posture_prima[label] = str(
				(corpi[label] as Node3D).get_meta("postura", ""))

	vis.call("_tick_confronti", 0.1)

	# --- la forza di trattenersi
	t.almost(float(animi[CHI_RILEGGE].limbico.regolazione),
			float(prima[CHI_RILEGGE]),
			"chi rilegge non spende un bit di regolazione", 1e-12)
	t.ok(float(animi[CHI_MORDE].limbico.regolazione)
			< float(prima[CHI_MORDE]) - 1e-6,
			("…e chi si morde la lingua la spende (%.4f -> %.4f): e' la "
			+ "controprova che il giro e' passato dalla porta vera")
					% [float(prima[CHI_MORDE]),
							float(animi[CHI_MORDE].limbico.regolazione)])

	# --- la postura imposta
	t.eq(str((corpi[CHI_RILEGGE] as Node3D).get_meta("postura", "")),
			str(posture_prima[CHI_RILEGGE]),
			"a chi rilegge non si impone nessuna postura: non c'e' una "
			+ "faccia da rilettura")
	t.eq(str((corpi[CHI_SCOPPIA] as Node3D).get_meta("postura", "")),
			"spalle_basse",
			"…mentre a chi scoppia SI: e' la controprova che l'asserzione "
			+ "qui sopra sa fallire")

	# --- la bolla sopra la testa
	t.eq((corpi[CHI_RILEGGE].bolle as Array).size(), 0,
			"…e nessuna bolla: chi rilegge non ha niente da dire a nessuno")
	t.ok((corpi[CHI_SCOPPIA].bolle as Array).size() >= 1,
			"…mentre a chi scoppia esce il suo «…» (%s)"
					% str(corpi[CHI_SCOPPIA].bolle))

	# --- e quello che arriva a schermo
	var suoi := 0
	var altrui := 0
	for frase in vis.toast:
		if str(frase).contains(CHI_RILEGGE):
			suoi += 1
		else:
			altrui += 1
	t.eq(suoi, 0,
			"chi rilegge non manda niente a schermo (toast: %s)"
					% str(vis.toast))
	t.ok(altrui >= 1,
			"…e nello stesso giro chi scoppia sì (toast: %s)" % str(vis.toast))


# ── 3 ─────────────────────────────────────────────────────────────────────
## I contatori del referto contano i MODI, uno per residente e uno per giro —
## e il giro dopo tace, perché ogni residente ha il suo raffreddamento.
##
## ⚠️ **IL RAFFREDDAMENTO NON È UN DETTAGLIO DI BANCO.** Senza,
## `_tick_confronti` chiederebbe a ogni residente di regolare un impulso
## SESSANTA VOLTE AL SECONDO: la regolazione finirebbe in un fotogramma e
## tutto il villaggio scoppierebbe insieme. È la ragione per cui la seconda
## chiamata qui sotto deve trovare i contatori fermi.
func _i_contatori_dicono_i_modi_giusti(t) -> void:
	var b := _banco(t)
	var vis = b["vis"]
	vis.call("_tick_confronti", 0.1)

	var c: Dictionary = vis.call("debug_regola_contatori")
	t.eq(int(c.get("rilettura", 0)), 1,
			"una rilettura contata (referto: %s)" % str(c))
	t.eq(int(c.get("morso", 0)), 1, "un morso contato (referto: %s)" % str(c))
	t.eq(int(c.get("scoppio", 0)), 1,
			"uno scoppio contato (referto: %s)" % str(c))

	# ⚠️ il secondo giro, subito dopo, non deve contare NIENTE: fra un
	# impulso e l'altro passano dodici secondi per persona.
	vis.call("_tick_confronti", 0.1)
	var c2: Dictionary = vis.call("debug_regola_contatori")
	t.eq(int(c2.get("rilettura", 0)), 1,
			"il giro dopo non ricomincia da capo: il raffreddamento tiene "
			+ "(referto: %s)" % str(c2))
	t.eq(int(c2.get("morso", 0)), 1, "…e vale per tutti i modi (%s)" % str(c2))
	t.eq(int(c2.get("scoppio", 0)), 1, "…tutti e tre (%s)" % str(c2))
