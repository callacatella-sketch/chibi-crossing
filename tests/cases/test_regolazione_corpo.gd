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
const GESTI := preload("res://scenes/npc/Gesti.gd")
const VISITORS := preload("res://scenes/npc/Visitors.gd")

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

## I DUE ESTREMI VERI DI QUESTO RAMO, e nemmeno questi si scrivono a indice.
## Sotto «svogliato» il ramo non gira; da «confronto» in su si passa dall'altra
## parte (lo sfogo). Quindi la tensione del confronto può nascere soltanto
## dentro questa finestra, e il gradino più alto che possa MAI vedere è quello
## appena sotto «confronto» — che è dove va provato il suo tetto, perché è lì
## che vale di più.
const GRADINO_BASSO := "svogliato"
const GRADINO_ALTO := "sabotaggio"

## ⚠️ **IL METRO DELLA TENSIONE NON È LA TENSIONE.** La forza minima che uno
## SPAVENTO vero produce in questo gioco, MISURATA sul rig con la catena vera
## (`tools/provino_carattere.gd`, cinque caratteri davanti allo stesso
## soprassalto: la forza esce fra **0,447 e 1,000**). Un confronto non è uno
## spavento — chi ha un torto da rinfacciarti non deve indossare la faccia di
## chi ha appena avuto paura di te — e questo numero è l'unico modo di
## giudicare `TENSIONE_CONFRONTO` con qualcosa che non sia lei stessa.
const SPAVENTO_MINIMO := 0.447

## QUANTO SI PORTA AVANTI LA RAMPA DI RILASCIO prima di chiedere il buio, in
## frazione di `Gesti.SPEGNI` — mai in secondi.
##
## ⚠️ **In frazione perché così sta DENTRO la rampa per costruzione**, anche
## il giorno che qualcuno ritocca `SPEGNI`. A rampa finita `coda_rilascio`
## vale zero, `_gesto_soma` spegne il canale da sé, e il banco si ritroverebbe
## a interrogare un corpo che non sta sciogliendo più niente — cioè a provare
## un'altra cosa, restando verde. Che il numero sia quello giusto non si
## spera: lo dice il gemello in coda a `_la_tensione_non_annulla_uno_scioglimento`.
const RILASCIO_AVANTI := 0.6

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
	_il_confronto_arma_il_buio(t)
	_la_tensione_cresce_col_torto(t)
	_la_tensione_non_si_arma_su_chi_non_la_puo_mostrare(t)
	_la_tensione_non_annulla_uno_scioglimento(t)


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


# ==========================================================================
# LA TENSIONE DEL CONFRONTO — il buio, e nessuno lo guardava
# ==========================================================================
#
# ⚠️ **PERCHÉ QUESTA SECONDA METÀ ESISTE.** `Visitors.TENSIONE_CONFRONTO` non
# compariva in un solo file della suite, e `_gs_soma` non veniva letto da
# nessuno dopo `_tick_confronti`. Applicando la mutazione già scritta in
# `tools/muta_rilettura.txt` («la tensione del confronto non si arma piu'» →
# `pass`) si torna ESATTAMENTE allo stato misurato prima della cura — 9
# riletture, **0 gesti concessi**, la meccanica invisibile in partita — con
# **zero asserzioni rosse**. Cioè la riga che rende visibile la generosità
# del giocatore si poteva cancellare senza che niente se ne accorgesse.
#
# La catena è tutta qui, ed è per questo che si guarda il CORPO e non la
# costante: la rilettura è un Rialzo (`Gesti.FRASI`), ogni Rialzo dichiara il
# buio, e `Visitor._sussulto_fresco()` si rifiuta se quel buio non c'è. Il
# ramo `trasalisce` non lo arma mai a chi rilegge (per definizione non ha un
# marchio negativo addosso, e a passo d'uomo `indizio_grezzo` vale 0,185
# contro `RIFLESSO_GREZZO` 0,25): senza la tensione, quel corpo non ha
# NESSUNA strada per avere il buio, e il gesto è rifiutato sempre.
#
# ── LE MUTAZIONI ──────────────────────────────────────────────────────────
#
# ⚠️ **ONESTÀ SUI NUMERI: queste rosse sono DERIVATE, non fatte girare.** La
# sessione che ha scritto questi casi non poteva eseguire la suite (una
# trentina di processi Godot di altre sessioni sulla stessa macchina, e un'ora
# a corsa): la verifica è stata `--check-only`. I conti qui sotto però sono
# esatti e si rifanno a mano, perché la forza è un `lerpf` deterministico fra
# `CODA_SOGLIA*2` = 0,12 e `TENSIONE_CONFRONTO` = 0,45, e i tre gradini di
# questo banco danno frazioni 1/7 · 2/7 · 4/7:
#
#   svogliato 0,1671 · attrezzi 0,2143 · sabotaggio 0,3086
#
#  | mutazione, in `Visitors`                              | rosse derivate |
#  |-------------------------------------------------------|----------------|
#  | la tensione non si arma più (il `somatico` → `pass`)   |    9 (4+2+3)   |
#  | `TENSIONE_CONFRONTO` 0.45 → 0.05                       |    6 (3+3)     |
#  | `TENSIONE_CONFRONTO` 0.45 → 1.0                        |    1           |
#  | la forza non viene dal gradino (`frazione` → costante) |    1           |
#  | la tensione si arma DENTRO il solo ramo `rilettura`    |    4 (2+2)     |
#  | `_buio_armabile` → `return true` (valvole spente)      |    3           |
#
# I due conti che vale la pena rifare, perché sono quelli che tengono la
# costante ancorata a numeri che non sono lei:
#
#  · **a 0,05** il `lerp` va all'INGIÙ e a «attrezzi» dà 0,10: sotto il doppio
#    della soglia, dove `coda_ampiezza` smorza a 0,074 — il livello resta
#    acceso in RAM e invisibile sullo schermo, e a «sabotaggio» (0,08) è
#    perfino più debole che a «svogliato» (0,11), cioè la tensione
#    DIMINUIREBBE col torto;
#  · **a 1,0** a «sabotaggio» dà 0,6229, cioè più forte di uno spavento vero
#    (0,447): la faccia della paura addosso a chi ha solo un torto.
#
# ⚠️ E una nota su un'asserzione che da sola NON basta: `coda_ampiezza(0, 0)`
# torna 0, quindi il confronto «l'ampiezza non è smorzata» PASSA su un corpo
# senza tensione. È il motivo per cui accanto c'è sempre `soma > 0`: separate
# sono due domande, insieme sono la guardia.
#
# ⚠️ E il tetto e il pavimento NON si giudicano contro `TENSIONE_CONFRONTO`:
# quello sarebbe il numero che giudica sé stesso, ed è il difetto che questo
# progetto ha già pagato in cinque punti diversi. Il tetto è
# `SPAVENTO_MINIMO`, misurato altrove e su un'altra meccanica; il pavimento è
# la LEGGE di `Gesti.coda_ampiezza`, che sotto il doppio della soglia smorza
# — un livello armato là sotto è acceso in RAM e invisibile sullo schermo.


## La coda somatica di quel corpo, adesso: è il buio, e non si legge da un
## registro del banco ma dal `Visitor` VERO.
func _tensione(b: Dictionary, label: String) -> float:
	return float((b["corpi"][label] as Node).get("_gs_soma"))


## Sposta un residente su un altro gradino della scala PRIMA del giro.
##
## ⚠️ Si scrive su `animo.gradino`, che è quello che `_tick_confronti` legge;
## la copia dentro la riga del residente si aggiorna per non lasciare in giro
## due verità sullo stesso dato, ma non è lei a decidere.
func _rimetti_gradino(b: Dictionary, label: String, gradino: String) -> void:
	var idx := ANIMO.indice(gradino)
	var a = b["animi"][label]
	a.gradino = idx
	var vis = b["vis"]
	for r in vis._residents:
		if str((r as Dictionary).get("label", "")) == label:
			(r as Dictionary)["gradino"] = idx


## Spegne un corpo scrivendogli lo STATO VERO, mai un booleano di comodo: è
## l'idioma di `test_deduzioni` (un doppio che si inventa una valvola prova la
## valvola del doppio, non quella del gioco).
func _fuori_gioco(b: Dictionary, label: String, come: String) -> void:
	var c = b["corpi"][label]
	match come:
		"dorme":
			c.set("_state", "tk_nap")     # il pisolino: nel mondo, a occhi chiusi
		"e' rientrato in casa":
			c.set("_hidden", true)        # la notte: il corpo sparisce dal prato
		"e' a un appuntamento":
			c.call("apri_scena", 3.0)     # la porta vera delle scene rare


## Mette un corpo nello stato del SOLLIEVO: un sussulto vero addosso, e il
## Rialzo che l'ha appena mollato — con la rampa di rilascio già cominciata.
##
## ⚠️ **Lo stato NON si scrive a mano su `_gs_soma_sciolto`.** Si accende con
## le due porte VERE di quel canale (`somatico` · `soma_sciogli`) e lo si
## porta avanti col passo VERO (`_gesto_soma`, che in partita lo muove un
## fotogramma per volta, e qui di fotogrammi non ne passa nessuno). Un banco
## che si scrive addosso lo stato prova la propria idea del rilascio, non
## quello del gioco — ed è esattamente il difetto che il `MotoreFinto` della
## Fase 5 ha già fatto pagare a questo progetto.
##
## La forza è il sussulto più DEBOLE che questo gioco produca, e non è un
## dettaglio: più la coda armata è debole, più bassa è la soglia di riarmo di
## `somatico()` e più facilmente la tensione si prenderebbe il canale. È il
## caso peggiore per la valvola, cioè quello da provare.
##
## Il guadagno è 0: qui serve solo l'orologio del canale, non i canali del rig
## (che in questo banco non disegna nessuno), e `_gesto_soma` esce prima di
## toccarli.
func _in_scioglimento(c) -> void:
	c.call("somatico", SPAVENTO_MINIMO)
	c.call("soma_sciogli")
	c.call("_gesto_soma", GESTI.SPEGNI * RILASCIO_AVANTI,
			{"r": 1.0, "sy": 1.0}, 0.0)


# ── 4 ─────────────────────────────────────────────────────────────────────
## ⚠️ **IL BUIO ARRIVA AL CORPO, e ci arriva PER TUTTI E TRE GLI ESITI.**
##
## La tensione si arma quando la decisione si PRENDE, cioè prima di
## `Animo.regola()`: chi si trova davanti qualcuno a cui deve qualcosa la
## sente comunque, e quello che i tre esiti fanno di diverso è come la
## lasciano andare (chi rilegge la SCIOGLIE col Rialzo, gli altri due se la
## tengono). Armarla dentro il solo ramo della rilettura sarebbe una posa
## scritta apposta per quel ramo — cioè l'adesivo che la REGOLA ZERO vieta —
## e questo caso lo rende rosso da due parti: chi morde e chi scoppia
## resterebbero a zero.
##
## E l'ultima asserzione è quella che conta davvero: non «c'è un numero
## dentro `_gs_soma`», ma **`_sussulto_fresco()` risponde di sì** — che è
## letteralmente la porta su cui il Rialzo della rilettura sbatteva, e la
## ragione per cui in dodici minuti di MainLevel i gesti concessi erano zero.
##
## ⚠️ **DA SAPERE PRIMA DI DIAGNOSTICARE UN ROSSO QUI:** l'ultima domanda di
## `Visitors._buio_armabile` è `_nell_inquadratura`, e nel runner non c'è
## nessuna `Camera3D` — quindi degrada a sì, che è la regola dichiarata («zero
## vuol dire non lo so, e non lo so non è mai un no»). Il giorno che un banco
## mettesse una camera in scena, questi casi andrebbero messi davanti al
## corpo, non indeboliti.
func _il_confronto_arma_il_buio(t) -> void:
	var b := _banco(t)
	var vis = b["vis"]
	vis.call("_tick_confronti", 0.1)

	# il giro è passato da tutti e tre i modi: senza questa riga, «per tutti e
	# tre gli esiti» sarebbe una cosa sperata invece che vista.
	var c: Dictionary = vis.call("debug_regola_contatori")
	t.eq([int(c.get("rilettura", 0)), int(c.get("morso", 0)),
			int(c.get("scoppio", 0))], [1, 1, 1],
			"il giro ha prodotto i tre modi, uno per residente (referto: %s)"
					% str(c))

	for label in [CHI_RILEGGE, CHI_MORDE, CHI_SCOPPIA]:
		var soma := _tensione(b, label)
		t.ok(soma > 0.0,
				("%s ha la tensione addosso: la si arma quando la decisione "
				+ "si prende, non dentro un ramo solo (coda %.4f)")
						% [label, soma])
		# …e non è accesa solo in RAM: `coda_ampiezza` sotto il doppio della
		# soglia SMORZA, e un livello smorzato non si vede sullo schermo.
		t.almost(GESTI.coda_ampiezza(soma, 0.0), soma,
				("…e si VEDE: sopra il doppio di `CODA_SOGLIA` l'ampiezza non "
				+ "è più smorzata (%s, coda %.4f)") % [label, soma], 1e-9)

	t.ok(bool((b["corpi"][CHI_RILEGGE] as Node).call("_sussulto_fresco")),
			("e chi rilegge ha finalmente IL BUIO che il Rialzo chiede: senza, "
			+ "`frase(\"rilettura\")` si rifiuta sempre e la generosità del "
			+ "giocatore non ha un corpo (misurato prima della cura: 9 "
			+ "riletture, 0 gesti concessi)"))


# ── 5 ─────────────────────────────────────────────────────────────────────
## ⚠️ **LA FORZA VIENE DAL TORTO, E STA SOTTO UNO SPAVENTO.**
##
## Due banchi identici — stesso genoma, stessa storia, stesso corpo, stessa
## distanza — che differiscono per UNA cosa sola: dove sta quel vicino sulla
## scala della ribellione. È l'unico modo di misurare il gradino senza
## incrociarlo con la storia, e per farlo servono due giri (dentro un banco
## solo, il raffreddamento di dodici secondi ne concede uno).
##
## Le tre asserzioni si ancorano a tre cose che NON sono
## `TENSIONE_CONFRONTO`: la legge di `coda_ampiezza` in basso, la forza di uno
## spavento vero in alto, e il gradino in mezzo.
func _la_tensione_cresce_col_torto(t) -> void:
	var basso := _banco(t)
	_rimetti_gradino(basso, CHI_MORDE, GRADINO_BASSO)
	basso["vis"].call("_tick_confronti", 0.1)
	var t_basso := _tensione(basso, CHI_MORDE)

	var alto := _banco(t)
	_rimetti_gradino(alto, CHI_MORDE, GRADINO_ALTO)
	alto["vis"].call("_tick_confronti", 0.1)
	var t_alto := _tensione(alto, CHI_MORDE)

	# il banco sta davvero nella finestra che crede
	t.ok(ANIMO.almeno(ANIMO.indice(GRADINO_BASSO), "svogliato")
			and not ANIMO.almeno(ANIMO.indice(GRADINO_ALTO), "confronto"),
			("i due gradini di prova stanno dentro la finestra di questo ramo "
			+ "(«%s» … «%s»)") % [GRADINO_BASSO, GRADINO_ALTO])

	t.ok(t_alto > t_basso + 1e-6,
			("chi ha un torto più grosso è più teso: la forza viene dalla "
			+ "scala della ribellione, non da un numero scelto "
			+ "(«%s» %.4f -> «%s» %.4f)")
					% [GRADINO_BASSO, t_basso, GRADINO_ALTO, t_alto])

	t.ok(t_basso >= GESTI.CODA_SOGLIA * 2.0 - 1e-9,
			("…e perfino al gradino più basso la tensione ESISTE sullo schermo: "
			+ "sotto il doppio della soglia `coda_ampiezza` smorza, e il "
			+ "Rialzo si rifiuterebbe lo stesso (%.4f, pavimento %.4f)")
					% [t_basso, GESTI.CODA_SOGLIA * 2.0])

	t.ok(t_alto < SPAVENTO_MINIMO,
			("…e al gradino più alto che questo ramo possa vedere resta SOTTO "
			+ "uno spavento vero (%.4f < %.3f): un confronto non è una paura, "
			+ "e chi alzasse quel numero metterebbe addosso a chi ha un torto "
			+ "la faccia di chi ha appena avuto paura di te")
					% [t_alto, SPAVENTO_MINIMO])

	# …e il tetto della propria formula non lo sfonda comunque (sanità del
	# lerp: questa sola, delle quattro, è giudicata contro sé stessa).
	t.ok(t_alto <= VISITORS.TENSIONE_CONFRONTO + 1e-9,
			"…e non sfora il proprio tetto (%.4f <= %.4f)"
					% [t_alto, VISITORS.TENSIONE_CONFRONTO])


# ── 6 ─────────────────────────────────────────────────────────────────────
## ⚠️ **E NON SI ARMA SU CHI NON HA UN CORPO DA MOSTRARE.**
##
## La porta è `Visitors._buio_armabile`, e la ragione per cui una porta serve
## è che questa chiamata **non passa da `chiedi_gesto`**: scavalcherebbe da
## sola tutte le valvole dell'usciere.
##
## Un livello è una cosa che il giocatore VEDE: armarlo su chi dorme, su chi è
## rientrato in casa (di notte il corpo sparisce dal prato) o su chi sta a un
## appuntamento vuol dire spendere il raffreddamento di dodici secondi per una
## tensione che nessuno guarderà — e per chi sta in una scena rara è peggio,
## perché quelle sono le poche pagine scritte a mano perché una volta ogni
## tanto succeda qualcosa di preciso.
##
## ⚠️ **UN BANCO PER VALVOLA, CON LA CONTROPROVA DENTRO LO STESSO GIRO.** Chi
## rilegge resta nel mondo e la tensione la prende: senza di lui «non si arma»
## sarebbe verde anche se `_tick_confronti` non girasse affatto — che è
## l'asserzione che non sa fallire, cioè nessuna asserzione.
##
## ⚠️ E qui si misura l'ARMAMENTO, non la resa: nel banco non passa nessun
## fotogramma, quindi `Visitor._gesto_passo` — che sospende i livelli di chi è
## in scena — non gira mai. È la forma giusta della domanda: la valvola deve
## stare a monte, dove si decide, non a valle dove si disegna.
func _la_tensione_non_si_arma_su_chi_non_la_puo_mostrare(t) -> void:
	for come in ["dorme", "e' rientrato in casa", "e' a un appuntamento"]:
		var b := _banco(t)
		_fuori_gioco(b, CHI_MORDE, str(come))
		b["vis"].call("_tick_confronti", 0.1)

		t.almost(_tensione(b, CHI_MORDE), 0.0,
				("a chi %s non si arma nessuna tensione: un livello che "
				+ "nessuno può vedere spende il raffreddamento per niente")
						% str(come), 1e-12)
		t.ok(_tensione(b, CHI_RILEGGE) > 0.0,
				("…e nello stesso identico giro chi è nel mondo la prende "
				+ "(controprova, mentre l'altro %s)") % str(come))


# ── 7 ─────────────────────────────────────────────────────────────────────
## ⚠️ **E NON SI ARMA SOPRA UN CORPO CHE SI STA SCIOGLIENDO — cioè sopra il
## SOLLIEVO APPENA MOSTRATO.**
##
## È la quinta valvola di `Visitors._buio_armabile`, l'unica che non riguarda
## chi guarda ma chi POSSIEDE il canale, e in tutta la suite non aveva un solo
## lettore: sostituendo le sue due righe con `pass` le 76000 asserzioni
## restavano verdi.
##
## Lo scenario è di due secondi ed è in faccia al giocatore (sta per esteso
## sopra `Visitor.sta_sciogliendo`): Mochi corre incontro di notte a un vicino
## che le vuole bene ma ha un torto → trasalisce → 0,4 s dopo il
## riconoscimento → «ah… sei tu», il Rialzo chiama `soma_sciogli()` e il corpo
## comincia a mollare. Nello stesso avvicinamento Mochi è già sotto i 2,6 m,
## quindi appena scade il raffreddamento del morso parte la tensione del
## confronto — e senza questa valvola **il rilascio viene annullato e la coda
## guardinga riparte da capo**: il sollievo si rimangia da sé, sotto gli occhi
## di chi lo stava guardando. Vale identico per il Rialzo della RILETTURA,
## cioè per il gesto che quella tensione esiste apposta per rendere possibile.
##
## ⚠️ **PERCHÉ `somatico()` DA SOLO NON SI DIFENDE, ed è la cosa che rende
## difficile scrivere bene questo caso.** Il suo riarmo confronta la forza
## nuova con `_gs_soma · exp(−t/CODA_TAU) · _soma_resto()`, e durante un
## rilascio `_soma_resto()` crolla verso zero in `Gesti.SPEGNI` secondi. A
## scioglimento **appena cominciato** vale ancora 1: la tensione (0,31 al
## gradino più alto di questo ramo) starebbe sotto un sussulto vero (0,447) e
## verrebbe rifiutata da `somatico` stesso. Un banco piazzato lì sarebbe VERDE
## anche con la valvola tolta — la stessa forma dell'asserzione che non sa
## fallire. Il guasto vive **dentro** la rampa, ed è dove questo banco si
## mette; che ci si sia messo davvero lo dice il gemello, in coda.
##
## | mutazione, in `Visitors._buio_armabile`              | rosse |
## |------------------------------------------------------|-------|
## | le due righe di `sta_sciogliendo` → `pass`            |   3   |
##
## ⚠️ **ONESTÀ SU QUEL 3.** `Visitors.gd` lo stavano editando altre sessioni,
## quindi la mutazione non è stata applicata al sorgente: si è **invertita
## l'attesa** delle tre asserzioni sensibili (il `not` della porta, il `not`
## dello scioglimento sopravvissuto, e la coda confrontata con la forza della
## tensione invece che con sé stessa) e si è fatta girare la suite intera.
## Rosse **esattamente quelle tre**, e la terza ha stampato i due numeri che
## chiudono il conto: coda addosso **0,4470** contro tensione **0,3086**. La
## soglia di riarmo di `somatico()` in quell'istante vale 0,146 — cioè la
## tensione la supera, cioè con la valvola tolta quelle tre asserzioni cadono
## davvero, e non per un epsilon.
func _la_tensione_non_annulla_uno_scioglimento(t) -> void:
	# ── LA PORTA, sullo stesso corpo, prima e dopo ────────────────────────
	var a := _banco(t)
	var corpo = a["corpi"][CHI_RILEGGE]

	# la CONTROPROVA per prima: senza, una valvola che rifiutasse TUTTO
	# passerebbe l'asserzione qui sotto e sembrerebbe viva.
	t.ok(bool(a["vis"].call("_buio_armabile", corpo)),
			"su un corpo che non sta sciogliendo niente il buio si arma")

	_in_scioglimento(corpo)
	t.ok(bool(corpo.call("sta_sciogliendo")),
			("…e adesso quello stesso corpo sta davvero mollando (forza "
			+ "addosso %.4f): il banco è nello stato che crede, non in uno "
			+ "sperato") % _tensione(a, CHI_RILEGGE))
	t.ok(not bool(a["vis"].call("_buio_armabile", corpo)),
			("…e sopra uno scioglimento in corso il buio NON si arma: sarebbe "
			+ "il sollievo appena mostrato, disfatto un attimo dopo"))

	# ── IL GIRO VERO: `_tick_confronti` non porta via il rilascio ─────────
	var b := _banco(t)
	# IL CASO PEGGIORE PER LA VALVOLA è la tensione più FORTE che questo ramo
	# possa produrre: più è forte, più facilmente si prende il canale.
	_rimetti_gradino(b, CHI_MORDE, GRADINO_ALTO)
	_rimetti_gradino(b, CHI_RILEGGE, GRADINO_ALTO)
	var che_molla = b["corpi"][CHI_MORDE]
	_in_scioglimento(che_molla)
	var prima := _tensione(b, CHI_MORDE)

	b["vis"].call("_tick_confronti", 0.1)

	# ⚠️ LA CONTROPROVA DENTRO LO STESSO GIRO, e vale doppio: dice che il giro
	# ha davvero armato qualcuno — senza, «il rilascio sopravvive» sarebbe
	# verde anche se `_tick_confronti` non facesse niente — e dice che i due
	# residenti stanno dentro la finestra di questo ramo, perché da
	# «confronto» in su si passa dall'altra parte e non si arma nulla.
	var forza_tensione := _tensione(b, CHI_RILEGGE)
	t.ok(forza_tensione > 0.0,
			"nello stesso giro chi non sta sciogliendo la tensione la prende "
			+ "(forza %.4f)" % forza_tensione)

	t.ok(bool(che_molla.call("sta_sciogliendo")),
			("…e chi stava mollando molla ancora: il giro non gli ha annullato "
			+ "il rilascio"))
	t.almost(_tensione(b, CHI_MORDE), prima,
			("…e la sua coda non è risalita di un bit: riarmarla vuol dire "
			+ "ricominciare da capo l'allerta che si era appena sciolta"),
			1e-12)

	# ── E IL BANCO SA FALLIRE ─────────────────────────────────────────────
	# La stessa forza, nello stesso stato, armata a mano dalla porta di
	# servizio: lo scioglimento se lo porta via. È la riga che tiene onesto
	# tutto il caso — il giorno che la geometria del banco finisse fuori dalla
	# rampa di rilascio, questa diventerebbe rossa e direbbe che le tre
	# asserzioni qui sopra sono diventate cieche, invece di lasciarle verdi
	# sopra una valvola tolta.
	var c := _banco(t)
	var gemello = c["corpi"][CHI_MORDE]
	_in_scioglimento(gemello)
	gemello.call("somatico", forza_tensione)
	t.ok(not bool(gemello.call("sta_sciogliendo")),
			("la stessa tensione, armata a mano su un corpo nello stesso stato, "
			+ "lo scioglimento se lo porta via (forza %.4f): è la prova che le "
			+ "asserzioni qui sopra sanno diventare rosse") % forza_tensione)
