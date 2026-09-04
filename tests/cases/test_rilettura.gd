extends RefCounted

## LA RILETTURA — la guardia, e non e' un source-check.
##
## Si costruiscono `Animo` VERI con storie vere, si chiama la porta VERA
## (`Animo.regola`), e si guarda cosa succede alla `regolazione`, al
## cortisolo, alle `attese` e ai ricordi. Le mutazioni stanno in
## `tools/muta_rilettura.txt`.

const ANIMO := preload("res://scenes/npc/Animo.gd")
const RIL := preload("res://scenes/npc/Rilettura.gd")
const REGIA := preload("res://scenes/npc/Regia.gd")
const GESTI := preload("res://scenes/npc/Gesti.gd")

const TRATTI_A := {"codardia": 0.15, "grinta": 0.85, "lealta": 0.80,
		"ambizione": 0.20, "orgoglio": 0.25}
const TRATTI_B := {"codardia": 0.85, "grinta": 0.15, "lealta": 0.20,
		"ambizione": 0.80, "orgoglio": 0.75}


func _animo(tratti := TRATTI_A, sogno := "combattere") -> RefCounted:
	var a = ANIMO.new()
	a.setup({"name": "Prova", "tratti": tratti, "sogno": sogno})
	return a


func _gentilezze(a: RefCounted, quante: int, valenza := 0.8) -> void:
	for i in quante:
		a.ricorda("regalo", "giocatore", valenza, 0.9)


func _torti(a: RefCounted, quanti: int, valenza := -0.8) -> void:
	for i in quanti:
		a.ricorda("ignorato", "giocatore", valenza, 0.9)


## Il CODICE di un file, senza i commenti: una guardia che scandaglia un
## sorgente e non li salta finisce per giudicare quello che c'e' scritto
## invece di quello che succede.
func _codice(percorso: String) -> String:
	var out := ""
	for riga in FileAccess.get_file_as_string(percorso).split("\n"):
		var r := str(riga)
		var i := r.find("#")
		if i >= 0:
			r = r.substr(0, i)
		out += r + "\n"
	return out


## Una fotografia di TUTTO lo stato che una rilettura potrebbe toccare.
func _fotografia(a: RefCounted) -> Dictionary:
	var neuro := {}
	for k in a.limbico.neuro:
		neuro[k] = float(a.limbico.neuro[k])
	return {"attese": (a.limbico.attese as Dictionary).duplicate(true),
			"marchi": (a.limbico.marchi as Dictionary).duplicate(true),
			"ricordi": (a.ricordi as Array).duplicate(true),
			"sommario": (a.sommario as Dictionary).duplicate(true),
			"neuro": neuro,
			"regolazione": float(a.limbico.regolazione),
			"arousal": float(a.limbico.arousal),
			"umore": float(a.limbico.umore),
			"morsi": int(a.limbico.morsi_oggi)}


func run(t) -> void:
	_il_modulo_non_tira_dadi(t)
	_non_e_un_tratto(t)
	_solo_la_prova_che_assolve(t)
	_una_gentilezza_sola_non_compra_un_torto_grosso(t)
	_il_torto_minimo_morde(t)
	_il_divario_e_il_materiale_delle_attese(t)
	_rileggere_non_tocca_NIENTE(t)
	_chi_rilegge_non_paga_e_chi_si_morde_si(t)
	_non_punisce_chi_e_stato_gentile(t)
	_le_prove_invecchiano(t)
	_senza_prove_il_gioco_e_quello_di_prima(t)
	_la_leva_del_banco_e_DAVVERO_il_gioco_di_prima(t)
	_il_perdono_legge_anche_il_sommario(t)
	_il_rancore_e_derivato_dal_conto(t)
	_la_frase_e_cablata(t)
	_la_leva_del_banco_non_la_accende_nessuno(t)


# ── 1 ─────────────────────────────────────────────────────────────────────
## «La disponibilita' non va tirata a dadi.» Due controlli: il codice non
## nomina nessun generatore, e cento chiamate identiche danno cento risposte
## identiche.
##
## ⚠️ **SI SALTANO I COMMENTI**: la testata di quel file NOMINA `randf()` per
## dire che non c'e', e la prima stesura di questa riga arrossiva sul proprio
## commento. E' la stessa disciplina di `test_vento`.
func _il_modulo_non_tira_dadi(t) -> void:
	var src := _codice("res://scenes/npc/Rilettura.gd")
	t.ok(not src.contains("randf") and not src.contains("randi")
			and not src.contains("RandomNumber"),
			"la rilettura non tira dadi: nessun generatore nel codice")
	var primo := RIL.rapporto(0.7, 1.0)
	for i in 100:
		t.almost(RIL.rapporto(0.7, 1.0), primo,
				"la stessa storia da' sempre la stessa risposta", 1e-12)


# ── 2 ─────────────────────────────────────────────────────────────────────
## ⚠️ **«E NON DEVE DIVENTARE UN TRATTO».** Tre controlli, e il terzo e'
## l'unico che conta davvero.
##
## La prima stesura di questo caso aveva due TAUTOLOGIE (`f(x) == f(x)`) e
## non asseriva mai la proprieta' del titolo. E il buco che lasciava aperto
## era concreto: il source-check guarda `Rilettura.gd`, ma **il tratto puo'
## entrare al sito di chiamata** — `RILETTURA.scheda(torti, prove * (0.5 +
## tratto("lealta")))` in `Animo.regola` passerebbe il source-check e non
## toccherebbe nessuna delle due tautologie. Perciò si passa da `regola()`.
func _non_e_un_tratto(t) -> void:
	var src := _codice("res://scenes/npc/Rilettura.gd")
	for nome in ["codardia", "grinta", "lealta", "ambizione", "orgoglio"]:
		t.ok(not src.contains('"%s"' % nome),
				"la rilettura non conosce il tratto «%s»" % nome)

	# (a) la funzione pura: gli stessi numeri danno la stessa risposta
	t.eq(RIL.disponibile(1.0, 2.0, 0.5), RIL.disponibile(1.0, 2.0, 0.5),
			"la disponibilita' e' una funzione dei soli numeri")

	# (b) e la PORTA: due caratteri opposti, la stessa identica storia
	var a := _animo(TRATTI_A)
	var b := _animo(TRATTI_B)
	for x in [a, b]:
		_gentilezze(x, 10)
		_torti(x, 3)
	var ra: Dictionary = a.regola("giocatore")
	var rb: Dictionary = b.regola("giocatore")
	t.eq(str(ra["modo"]), str(rb["modo"]),
			"due caratteri OPPOSTI con la stessa storia scelgono lo stesso modo")
	t.eq(str(ra["modo"]), "rilettura", "e con quel passato rileggono")


# ── 3 ─────────────────────────────────────────────────────────────────────
## ⚠️ IL CANCELLO STRUTTURALE. Un mucchio di righe OSTILI deve dare
## **esattamente** la stessa risposta di zero righe: il modulo non sa
## accusare nessuno, e non e' una promessa ma un `maxf(0.0, …)`.
func _solo_la_prova_che_assolve(t) -> void:
	t.almost(RIL.peso_prova(-0.9, 1.0, 1.0), 0.0,
			"una riga ostile pesa ZERO, non poco", 1e-12)
	t.almost(RIL.peso_prova(-0.01, 1.0, 1.0), 0.0,
			"e anche una appena ostile", 1e-12)

	var pulito := _animo()
	_torti(pulito, 3)
	var vuoto := _animo()
	_torti(vuoto, 3)
	for i in 12:
		pulito.ricorda("urlato", "giocatore", -0.9, 1.0)
	var cp: Dictionary = pulito.conto_verso("giocatore")
	var cv: Dictionary = vuoto.conto_verso("giocatore")
	t.almost(float(cp["prove"]), 0.0, "nessuna prova da righe ostili", 1e-9)
	t.almost(float(cv["prove"]), 0.0, "ne' da nessuna riga", 1e-9)
	t.eq(RIL.disponibile(float(cp["torti"]), float(cp["prove"])), false,
			"con dodici torti in piu' non si rilegge di piu'")
	t.almost(RIL.rapporto(float(cp["torti"]), float(cp["prove"])),
			RIL.rapporto(float(cv["torti"]), float(cv["prove"])),
			"le righe ostili non spostano il rapporto di un bit", 1e-12)


# ── 4 ─────────────────────────────────────────────────────────────────────
## Il rapporto, non la quantita' assoluta: un torto grosso vuole
## proporzionalmente piu' passato. E' la riga che impedisce la lavanderia.
##
## ⚠️ E si giudica `scheda()["riletto"]`, che e' quello che il gioco legge —
## non `disponibile()` per conto suo. Le due devono anche COINCIDERE, o una
## delle due sarebbe una funzione che nessuno esegue.
func _una_gentilezza_sola_non_compra_un_torto_grosso(t) -> void:
	t.eq(bool(RIL.scheda(2.0, 0.72)["riletto"]), false,
			"una gentilezza sola non rilegge un torto grosso")
	t.eq(bool(RIL.scheda(1.0, 0.72)["riletto"]), true,
			"ma contro un torto piccolo si")
	for i in 30:
		var torto := 0.2 + 0.3 * float(i)
		for j in 20:
			var prove := 0.1 * float(j) * torto
			t.eq(bool(RIL.scheda(torto, prove)["riletto"]),
					RIL.disponibile(torto, prove),
					"la scheda e la disponibilita' non divergono mai")
	# piu' grosso e' il torto, meno lo si rilegge
	var prima := true
	for k in 12:
		var torto := 0.3 + 0.3 * float(k)
		var ok: bool = bool(RIL.scheda(torto, 2.0)["riletto"])
		t.ok(prima or not ok,
				"la disponibilita' non torna dopo essere sparita (%.2f)" % torto)
		prima = ok


# ── 5 ─────────────────────────────────────────────────────────────────────
## ⚠️ **`TORTO_MIN` NON ERA SORVEGLIATA DA NIENTE.** Serve a non dividere per
## un denominatore che tende a zero — cioe' a non fabbricare un infinito che
## poi si legge come «rilettura sempre disponibile». Toglierla lasciava tutta
## la suite verde.
func _il_torto_minimo_morde(t) -> void:
	t.almost(RIL.rapporto(0.0, 5.0), 0.0,
			"senza torto il rapporto e' zero, non infinito", 1e-12)
	t.eq(bool(RIL.scheda(0.0, 5.0)["riletto"]), false,
			"e senza torto non c'e' niente da rileggere")
	var sotto: float = RIL.TORTO_MIN * 0.5
	var sopra: float = RIL.TORTO_MIN * 2.0
	t.almost(RIL.rapporto(sotto, 5.0), 0.0,
			"sotto la soglia il rapporto resta zero", 1e-12)
	t.ok(RIL.rapporto(sopra, 5.0) > RIL.RAPPORTO_MIN,
			"e appena sopra torna un numero vero (%.2f)" % RIL.rapporto(sopra, 5.0))
	t.ok(is_finite(RIL.rapporto(1e-12, 5.0)),
			"e non esce mai un infinito")


# ── 6 ─────────────────────────────────────────────────────────────────────
## IL DIVARIO — il materiale che le `attese` mettono a disposizione. Chi si
## aspetta gia' esattamente quello che ha ricevuto non ha una lettura
## alternativa da trovare: ha un fatto, e i fatti si tengono.
func _il_divario_e_il_materiale_delle_attese(t) -> void:
	t.eq(RIL.disponibile(1.0, 5.0, 0.0), false,
			"senza divario non si rilegge, per quante prove ci siano")
	t.eq(RIL.disponibile(1.0, 5.0, -0.3), false, "ne' con un divario negativo")
	t.eq(RIL.disponibile(1.0, 5.0, 0.4), true, "col divario si")
	t.eq(RIL.disponibile(1.0, 5.0, NAN), false, "e un NaN non e' un divario")

	var a := _animo()
	_gentilezze(a, 10)
	_torti(a, 3)
	var c: Dictionary = a.conto_verso("giocatore")
	var d: float = a.limbico.divario("giocatore", float(c["media_prove"]))
	t.ok(d > 0.0, "chi ha subito un torto ha un divario da colmare (%.3f)" % d)
	t.almost(a.limbico.divario("Nessuno", float(c["media_prove"])), 0.0,
			"e verso chi non conosce non c'e' nessun divario", 1e-12)
	# ⚠️ ed e' di SOLA LETTURA
	var prima: Dictionary = (a.limbico.attese as Dictionary).duplicate()
	a.limbico.divario("giocatore", 0.9)
	t.eq(a.limbico.attese, prima, "chiedere il divario non scrive un bit")


# ── 7 ─────────────────────────────────────────────────────────────────────
## ⚠️ **RILEGGERE NON TOCCA NIENTE — e non e' una promessa, e' la forma piu'
## forte in cui «una rilettura non cancella il fatto» si possa scrivere.**
##
## La prima stesura rialzava le `attese` verso quella persona. Una revisione
## avversariale ha mostrato che il conto non tornava: la `regolazione`
## risparmiata si rigenera ogni notte, un'attesa alzata sbiadisce di 0,04 al
## giorno; e le chiavi che salivano erano quelle dei COMPITI (le altre erano
## gia' sopra la media), cioe' lo stesso incarico si incideva peggio a chi ti
## aveva portato da mangiare. Adesso non si scrive niente, e questo caso
## fotografa TUTTO quello che si potrebbe toccare.
func _rileggere_non_tocca_NIENTE(t) -> void:
	var a := _animo()
	_gentilezze(a, 10)
	_torti(a, 3)
	var prima := _fotografia(a)
	var r: Dictionary = a.regola("giocatore")
	t.eq(str(r["modo"]), "rilettura", "si rilegge")
	var dopo := _fotografia(a)
	for k in prima:
		t.eq(dopo[k], prima[k],
				"rileggere non tocca «%s»" % k)


# ── 8 ─────────────────────────────────────────────────────────────────────
## ⚠️ **LA PREVISIONE FALSIFICABILE DI TUTTO IL LAVORO.** Chi rilegge non
## spende `regolazione` e non alza il cortisolo; chi si morde la lingua fa
## tutti e due. Se un domani questa asserzione diventasse rossa, la
## rilettura sarebbe diventata una seconda soppressione con un altro nome.
func _chi_rilegge_non_paga_e_chi_si_morde_si(t) -> void:
	var legge := _animo()
	_gentilezze(legge, 10)
	_torti(legge, 2)
	var morde := _animo()
	_torti(morde, 2)

	var reg_l: float = legge.limbico.regolazione
	var cort_l: float = legge.limbico.livello_neuro("cortisolo")
	var reg_m: float = morde.limbico.regolazione
	var cort_m: float = morde.limbico.livello_neuro("cortisolo")

	var rl: Dictionary = legge.regola("giocatore")
	var rm: Dictionary = morde.regola("giocatore")

	t.eq(str(rl["modo"]), "rilettura", "con un passato buono si rilegge")
	t.eq(str(rm["modo"]), "morso", "senza, ci si morde la lingua")

	t.almost(legge.limbico.regolazione, reg_l,
			"chi rilegge non spende un grammo di regolazione", 1e-9)
	t.almost(legge.limbico.livello_neuro("cortisolo"), cort_l,
			"e non alza il cortisolo di un millesimo", 1e-9)
	t.ok(morde.limbico.regolazione < reg_m - 0.05,
			"chi si morde la lingua paga (%.3f -> %.3f)"
			% [reg_m, morde.limbico.regolazione])
	t.ok(morde.limbico.livello_neuro("cortisolo") > cort_m + 1e-4,
			"e il corpo resta attivato (%.4f -> %.4f)"
			% [cort_m, morde.limbico.livello_neuro("cortisolo")])


# ── 9 ─────────────────────────────────────────────────────────────────────
## ⚠️ **NON PUNISCE CHI E' STATO GENTILE.** Il torto DOPO una rilettura deve
## sentirsi esattamente come si sarebbe sentito senza: la rilettura non puo'
## avere un costo differito da nessuna parte. E' l'invariante che la
## revisione avversariale ha chiesto, ed e' la ragione per cui il rialzo
## delle attese e' stato tolto.
func _non_punisce_chi_e_stato_gentile(t) -> void:
	var legge := _animo()
	var no := _animo()
	for x in [legge, no]:
		_gentilezze(x, 10)
		_torti(x, 3)
	t.eq(str(legge.regola("giocatore")["modo"]), "rilettura", "uno dei due rilegge")
	# e adesso, lo STESSO identico compito, a tutti e due
	var dopo_l: Dictionary = legge.limbico.rivaluta("taglia_legna", "giocatore",
			-0.6, "", true)
	var dopo_n: Dictionary = no.limbico.rivaluta("taglia_legna", "giocatore",
			-0.6, "", true)
	t.almost(float(dopo_l["sentito"]), float(dopo_n["sentito"]),
			"lo stesso incarico si sente IDENTICO a chi ha riletto", 1e-9)
	t.almost(float(dopo_l["sorpresa"]), float(dopo_n["sorpresa"]),
			"e sorprende identico", 1e-9)


# ── 10 ────────────────────────────────────────────────────────────────────
## ⚠️ **LE PROVE INVECCHIANO, e questo caso e' nato da una mutazione MUTA.**
##
## Togliere la recenza dal peso delle prove lasciava la suite verde, e non
## perche' il test fosse pigro: la recenza moltiplica **anche** i torti,
## quindi un invecchiamento uniforme si semplifica dentro il rapporto. Conta
## solo quando le due cose stanno in tempi DIVERSI — ed e' esattamente la
## scena vera: «sei stato buono con me mesi fa, ma ultimamente no».
func _le_prove_invecchiano(t) -> void:
	# ⚠️ **IL NUMERO E' MISURATO, non scelto.** Con dieci gentilezze contro
	# quattro torti il rapporto scende sotto `RAPPORTO_MIN` fra la
	# trentesima e la quarantesima giornata (2.21 · 0.83 a 20 · 0.57 a 30 ·
	# 0.38 a 40): la prima stesura ne metteva trenta e restava «rilettura» —
	# e l'attesa sbagliata era la mia, non il codice.
	var vecchio := _animo()
	_gentilezze(vecchio, 10)
	for _g in 45:
		vecchio.passa_giorno()
	_torti(vecchio, 4)
	var fresco := _animo()
	for _g in 45:
		fresco.passa_giorno()
	_gentilezze(fresco, 10)
	_torti(fresco, 4)

	var cv: Dictionary = vecchio.conto_verso("giocatore")
	var cf: Dictionary = fresco.conto_verso("giocatore")
	t.ok(float(cv["prove"]) < float(cf["prove"]) * 0.5,
			"le prove di quarantacinque giorni fa pesano meno della meta' "
			+ "(%.3f contro %.3f)" % [float(cv["prove"]), float(cf["prove"])])
	t.ok(RIL.rapporto(float(cv["torti"]), float(cv["prove"]))
			< RIL.rapporto(float(cf["torti"]), float(cf["prove"])),
			"e il rapporto scende col tempo, non resta fermo")
	t.eq(str(vecchio.regola("giocatore")["modo"]), "morso",
			"chi e' stato gentile solo mesi fa non compra una rilettura")
	t.eq(str(fresco.regola("giocatore")["modo"]), "rilettura",
			"chi lo e' stato adesso si")


# ── 11 ────────────────────────────────────────────────────────────────────
## ⚠️ IL DEGRADO VA DOVE VA SEMPRE: senza prove, il gioco e' quello di
## prima, riga per riga.
func _senza_prove_il_gioco_e_quello_di_prima(t) -> void:
	var via_porta := _animo()
	var via_morso := _animo()
	for x in [via_porta, via_morso]:
		_torti(x, 4)
	for i in 3:
		var r: Dictionary = via_porta.regola("giocatore")
		var ok: bool = via_morso.limbico.trattieni()
		t.eq(str(r["modo"]), "morso" if ok else "scoppio",
				"stesso esito del gioco di prima, giro %d" % i)
		t.almost(via_porta.limbico.regolazione, via_morso.limbico.regolazione,
				"stessa regolazione al giro %d" % i, 1e-9)
		t.almost(via_porta.limbico.livello_neuro("cortisolo"),
				via_morso.limbico.livello_neuro("cortisolo"),
				"stesso cortisolo al giro %d" % i, 1e-9)


# ── 12 ────────────────────────────────────────────────────────────────────
## ⚠️ **LA LEVA DEL BANCO VA ESERCITATA, non solo trovata spenta.**
##
## `debug_niente_rilettura` e' il braccio di CONTROLLO di
## `tools/misura_rilettura.gd`: se non facesse davvero il gioco di prima, il
## banco misurerebbe due volte il codice nuovo, riporterebbe «zero
## differenza» e verrebbe creduto. E' la lezione del `MotoreFinto`: un doppio
## che mente e' peggio di nessun doppio.
func _la_leva_del_banco_e_DAVVERO_il_gioco_di_prima(t) -> void:
	var spento := _animo()
	var morso := _animo()
	for x in [spento, morso]:
		_gentilezze(x, 10)
		_torti(x, 3)
	spento.set("debug_niente_rilettura", true)
	# lo stesso animo, senza la leva, rileggerebbe: e' la controprova
	var acceso := _animo()
	_gentilezze(acceso, 10)
	_torti(acceso, 3)
	t.eq(str(acceso.regola("giocatore")["modo"]), "rilettura",
			"con la leva spenta si rilegge")
	for i in 3:
		var r: Dictionary = spento.regola("giocatore")
		var ok: bool = morso.limbico.trattieni()
		t.eq(str(r["modo"]), "morso" if ok else "scoppio",
				"con la leva accesa e' il gioco di prima, giro %d" % i)
		t.almost(spento.limbico.regolazione, morso.limbico.regolazione,
				"stessa regolazione al giro %d" % i, 1e-9)
		t.almost(spento.limbico.livello_neuro("cortisolo"),
				morso.limbico.livello_neuro("cortisolo"),
				"stesso cortisolo al giro %d" % i, 1e-9)


# ── 13 ────────────────────────────────────────────────────────────────────
## ⚠️ **IL PERDONO LEGGE ANCHE IL SOMMARIO, come il rancore.** Prima no, e
## finche' la potatura era un FIFO non si vedeva: se ne andavano i vecchi,
## buoni e cattivi in proporzione. Con la potatura per SCHEMA si sacrificano
## per prime le righe RIPETUTE — e le gentilezze del giocatore sono per
## definizione le righe ripetute. MISURATO su un piatto e una legna al
## giorno: le prove passavano da 3.79 (25 giornate) a 3.18 (60) mentre i
## torti salivano da 0.76 a 1.57.
func _il_perdono_legge_anche_il_sommario(t) -> void:
	var a := _animo()
	# si riempie oltre il tetto dei ricordi vivi, cosi' la potatura lavora
	for g in 30:
		a.ricorda("piatto", "giocatore", 0.7, 0.8)
		a.ricorda("ignorato", "giocatore", -0.7, 0.8)
		a.passa_giorno()
	t.ok(a.sommario.size() > 0, "il sommario si e' riempito")
	var somma_buona := 0.0
	for k in a.sommario:
		var p: PackedStringArray = str(k).split("|")
		if p.size() >= 2 and p[1] == "giocatore" and float(a.sommario[k]["peso"]) > 0.0:
			somma_buona += float(a.sommario[k]["peso"])
	t.ok(somma_buona > 0.0,
			"e c'e' roba BUONA dentro (%.3f): e' quella che si perdeva" % somma_buona)
	# le prove devono contenere anche quella
	var vive := 0.0
	for r in a.ricordi:
		if r["attore"] == "giocatore" and float(r["valenza"]) > 0.0:
			vive += RIL.peso_prova(float(r["valenza"]), float(r["intensita"]),
					pow(0.5, float(int(a.oggi) - int(r["quando"])) / ANIMO.MEZZA_VITA))
	var c: Dictionary = a.conto_verso("giocatore")
	t.ok(float(c["prove"]) > vive + 1e-6,
			"le prove valgono piu' delle sole righe vive (%.3f contro %.3f)"
			% [float(c["prove"]), vive])


# ── 14 ────────────────────────────────────────────────────────────────────
## `rancore()` e `Rilettura` leggono lo STESSO libro mastro. Se qualcuno
## rifacesse le prove per conto suo, i due divergerebbero in silenzio.
func _il_rancore_e_derivato_dal_conto(t) -> void:
	for n in [0, 1, 3, 7, 14]:
		var a := _animo()
		_gentilezze(a, n)
		_torti(a, 4)
		var c: Dictionary = a.conto_verso("giocatore")
		var atteso: float = 1.0 - exp(-maxf(0.0,
				float(c["torti"]) - float(c["prove"]) * 1.4)
				/ ANIMO.SATURAZIONE * 3.0)
		t.almost(a.rancore("giocatore"), atteso,
				"il rancore e' la saturazione del conto (%d gentilezze)" % n,
				1e-9)
	var poco := _animo()
	_gentilezze(poco, 1)
	_torti(poco, 4)
	var tanto := _animo()
	_gentilezze(tanto, 12)
	_torti(tanto, 4)
	t.ok(tanto.rancore("giocatore") < poco.rancore("giocatore"),
			"i ricordi belli scontano ancora il rancore")


# ── 15 ────────────────────────────────────────────────────────────────────
## La frase e' cablata da tutte e due le parti, e il villaggio non scende
## piu' dentro `animo.limbico` per decidere.
func _la_frase_e_cablata(t) -> void:
	t.eq(REGIA.frase_di("ha_riletto"), "rilettura",
			"l'occasione punta alla frase")
	t.ok(GESTI.FRASI.has("rilettura"), "e la frase esiste nel vocabolario")
	t.eq(str((GESTI.FRASI["rilettura"] as Dictionary)["g"]), "rialzo",
			"la rilettura e' il Rialzo")
	t.eq(bool(((GESTI.FRASI["rilettura"] as Dictionary)["d"] as Dictionary)
			.get("buio", false)), true,
			"e chiede il buio, come ogni Rialzo di questo gioco")
	t.ok(REGIA.frasi_coerenti(),
			"ogni occasione della regia punta a una frase che esiste")
	t.ok(REGIA.attesa_di("ha_riletto") < REGIA.attesa_di("si_e_trattenuto"),
			"e aspetta meno del morso, perche' e' piu' rara")

	var src := _codice("res://scenes/npc/Visitors.gd")
	t.ok(not src.contains("limbico.trattieni()"),
			"il villaggio chiede all'Animo, non al Limbico "
			+ "(source-check: la guardia vera e' _senza_prove…)")
	t.ok(src.contains('chiedi_gesto(label, "ha_riletto")'),
			"e chiede l'occasione GIUSTA, non quella del morso")
	# ⚠️ e il referto dei no legge la TABELLA: era `nome == \"sollievo\"`, e
	# ogni rifiuto della rilettura per mancanza di buio veniva contato come
	# «corpo occupato» — la causa sbagliata, nel banco scritto per misurarla
	t.ok(not src.contains('nome == "sollievo"'),
			"il referto dei no non ha un elenco di nomi ricopiato")


# ── 16 ────────────────────────────────────────────────────────────────────
## ⚠️ LA LEVA DEL BANCO NON LA ACCENDE NESSUNO.
func _la_leva_del_banco_non_la_accende_nessuno(t) -> void:
	var a := _animo()
	t.eq(a.debug_niente_rilettura, false,
			"di serie la leva e' spenta: il gioco rilegge")
	var accesa: Array = []
	for cartella: String in ["res://scenes", "res://systems"]:
		_scandaglia(cartella, accesa)
	t.eq(accesa.size(), 0,
			"e nessun file di gioco la accende: %s" % str(accesa))


func _scandaglia(dove: String, fuori: Array) -> void:
	var d := DirAccess.open(dove)
	if d == null:
		return
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		var via := dove + "/" + n
		if d.current_is_dir():
			if not n.begins_with("."):
				_scandaglia(via, fuori)
		elif n.ends_with(".gd"):
			for riga in FileAccess.get_file_as_string(via).split("\n"):
				var r := str(riga)
				var i := r.find("#")
				if i >= 0:
					r = r.substr(0, i)
				if r.contains("debug_niente_rilettura") and r.contains("true"):
					fuori.append(via)
		n = d.get_next()
	d.list_dir_end()
