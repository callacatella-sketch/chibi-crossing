extends RefCounted

## LA FINESTRA SENSIBILE DELLO SVILUPPO — la guardia.
##
## Non e' un source-check: si costruiscono `Animo` VERI, si presta l'eta'
## come la presta il villaggio, e si guarda il tratto che ne esce.
## Le mutazioni stanno in `tools/muta_finestra.txt`.

const DERIVA := preload("res://scenes/npc/Deriva.gd")
const ANIMO := preload("res://scenes/npc/Animo.gd")
const LEGAMI := preload("res://scenes/world/Legami.gd")

const TRATTI := {"codardia": 0.60, "grinta": 0.50, "lealta": 0.50,
		"ambizione": 0.50, "orgoglio": 0.50}


func _animo(crescita := 1.0) -> RefCounted:
	var a = ANIMO.new()
	a.setup({"name": "Prova", "tratti": TRATTI.duplicate(), "sogno": "combattere"})
	a.crescita = crescita
	a.set("_deriva_giorno", -1)
	return a


func run(t) -> void:
	_a_plasticita_uno_e_il_gioco_di_ieri(t)
	_il_pavimento_e_uno_e_non_si_puo_dire_troppo_tardi(t)
	_la_finestra_si_apre_solo_verso_l_alto(t)
	_il_tetto_non_rompe_l_ordine_dei_caratteri(t)
	_i_tre_teoremi_reggono_anche_al_massimo(t)
	_un_cucciolo_e_segnato_di_piu(t)
	_l_eta_arriva_davvero_alla_DERIVA(t)
	_l_eta_non_si_salva_e_di_serie_si_e_adulti(t)
	_derivato_propaga_la_plasticita(t)
	_il_ponte_porta_l_eta_davvero(t)
	_niente_barra_niente_contatore_niente_lettera(t)


# ── 1 ─────────────────────────────────────────────────────────────────────
## ⚠️ **IL CANCELLO DELL'AUTORE: «1.0 = oggi bit per bit».** Non «quasi», non
## «entro tolleranza»: la stessa identica aritmetica di prima, che qui si
## riscrive per esteso invece di chiamare la funzione (chiedere alla
## funzione se e' d'accordo con se' stessa non prova niente).
func _a_plasticita_uno_e_il_gioco_di_ieri(t) -> void:
	for i in 21:
		for j in 21:
			var b := float(i) / 20.0
			var s := -1.0 + float(j) / 10.0
			var ieri: float = DERIVA.FRAZIONE * s * (1.0 - b) if s >= 0.0 \
					else DERIVA.FRAZIONE * s * b
			t.almost(DERIVA.delta(b, s, 1.0), ieri,
					"a plasticita' 1.0 e' il gioco di ieri (b=%.2f s=%.2f)"
					% [b, s], 1e-12)
			t.almost(DERIVA.delta(b, s), ieri,
					"e senza il parametro pure", 1e-12)


# ── 2 ─────────────────────────────────────────────────────────────────────
## ⚠️ **«TROPPO TARDI» E' LA FRASE CHE QUESTO GIOCO NON PUO' DIRE.** Il
## pavimento sta dentro il `clampf`, quindi nemmeno un chiamante sbagliato,
## un salvataggio corrotto o un banco possono portare la plasticita' sotto
## quella di oggi. Si prova passando i valori che quel guasto produrrebbe.
func _il_pavimento_e_uno_e_non_si_puo_dire_troppo_tardi(t) -> void:
	t.almost(DERIVA.plasticita_di(1.0), 1.0,
			"a crescita finita la plasticita' e' ESATTAMENTE quella di oggi",
			1e-12)
	for p in [0.0, 0.3, 0.999, -1.0, -100.0]:
		for b in [0.1, 0.5, 0.9]:
			for s in [-0.8, -0.2, 0.3, 0.9]:
				t.almost(DERIVA.delta(b, s, p), DERIVA.delta(b, s, 1.0),
						"plasticita' %.3f non puo' scendere sotto uno" % p, 1e-12)
	# e nemmeno un NaN puo' spegnere la deriva
	t.almost(DERIVA.plasticita_di(NAN), 1.0, "un NaN torna il pavimento", 1e-12)
	t.almost(DERIVA.delta(0.6, -0.5, NAN), 0.0,
			"e un NaN nel delta non propaga: torna zero", 1e-12)


# ── 3 ─────────────────────────────────────────────────────────────────────
## La finestra si APRE verso l'alto per i piccoli; non si CHIUDE verso il
## basso per i grandi. Monotona, e mai sotto uno.
func _la_finestra_si_apre_solo_verso_l_alto(t) -> void:
	var prima := DERIVA.plasticita_di(0.0)
	t.almost(prima, DERIVA.PLASTICITA_CUCCIOLO,
			"appena nato e' la plasticita' del cucciolo", 1e-12)
	for k in 41:
		var c := float(k) / 40.0
		var p := DERIVA.plasticita_di(c)
		t.ok(p >= 1.0 - 1e-12, "mai sotto il pavimento (crescita %.2f)" % c)
		t.ok(p <= prima + 1e-12, "e non risale crescendo")
		prima = p


# ── 4 ─────────────────────────────────────────────────────────────────────
## ⚠️ **IL TETTO NON E' UN GUSTO: SOPRA `1/FRAZIONE` UN TEOREMA CADE.** La
## derivata di `delta` rispetto alla base vale `1 − FRAZIONE·p·|s|`: a 2.5
## esatti si annulla, e sopra due codardi diversi si INVERTONO d'ordine.
## Il numero non si ricopia — si ricalcola qui, e poi si guarda il
## comportamento.
func _il_tetto_non_rompe_l_ordine_dei_caratteri(t) -> void:
	t.ok(DERIVA.FRAZIONE * DERIVA.PLASTICITA_MAX < 1.0,
			"il tetto sta sotto 1/FRAZIONE = %.3f (e vale %.2f)"
			% [1.0 / DERIVA.FRAZIONE, DERIVA.PLASTICITA_MAX])
	t.ok(DERIVA.PLASTICITA_CUCCIOLO <= DERIVA.PLASTICITA_MAX,
			"e il cucciolo ci sta dentro")
	# ⚠️ **E `FRAZIONE` VA ANCORATA A UN NUMERO CHE NON È LEI.** Ogni
	# asserzione di questo file la riscrive su tutti e due i lati, quindi la
	# costante si annullava: `FRAZIONE := 0.05` restava verde in tutta la
	# suite, cioè sotto il pavimento di leggibilità (0.20 di spostamento)
	# che `Deriva.gd` si impone da sé. Il numero che la fissa è nella sua
	# stessa testata, ed è MISURATO: al valore mediano della codardia
	# (0.534) una pressione piena sposta di una deviazione standard, 0.2146.
	t.almost(absf(DERIVA.delta(0.534, -1.0, 1.0)), 0.2136,
			"a pressione piena la codardia mediana si sposta di ~una "
			+ "deviazione standard", 0.02)
	t.ok(DERIVA.FRAZIONE >= 0.30 and DERIVA.FRAZIONE <= 0.45,
			"e FRAZIONE resta nella banda che il suo file si impone")
	# e l'ordine si conserva DAVVERO, alla plasticita' massima
	for j in 21:
		var s := -1.0 + float(j) / 10.0
		var prima := -2.0
		for i in 21:
			var b := float(i) / 20.0
			var dopo: float = b + DERIVA.delta(b, s, DERIVA.PLASTICITA_MAX)
			t.ok(dopo > prima,
					"chi partiva piu' in alto resta piu' in alto (s=%.2f)" % s)
			prima = dopo


# ── 5 ─────────────────────────────────────────────────────────────────────
## I tre teoremi di `delta` valgono anche col terzo parametro al massimo:
## nessuno al muro, e chi nasce al bordo non deriva.
func _i_tre_teoremi_reggono_anche_al_massimo(t) -> void:
	for i in 41:
		for j in 21:
			var b := float(i) / 40.0
			var s := -1.0 + float(j) / 10.0
			var d: float = DERIVA.delta(b, s, DERIVA.PLASTICITA_MAX)
			var fin := b + d
			t.ok(fin > -1e-9 and fin < 1.0 + 1e-9,
					"nessuno esce dai bordi (b=%.3f s=%.2f -> %.4f)"
					% [b, s, fin])
	for s in [-1.0, -0.4, 0.4, 1.0]:
		var giu: float = DERIVA.delta(0.0, s, DERIVA.PLASTICITA_MAX)
		var su: float = DERIVA.delta(1.0, s, DERIVA.PLASTICITA_MAX)
		if s < 0.0:
			t.almost(giu, 0.0, "chi nasce a zero non scende", 1e-12)
		else:
			t.almost(su, 0.0, "chi nasce a uno non sale", 1e-12)


# ── 6 ─────────────────────────────────────────────────────────────────────
## Lo STESSO identico ambiente segna di piu' un cucciolo, e il rapporto e'
## esattamente la plasticita' — non «di piu' e basta».
func _un_cucciolo_e_segnato_di_piu(t) -> void:
	for b in [0.2, 0.5, 0.85]:
		for s in [-0.9, -0.3, 0.4, 0.8]:
			var adulto: float = DERIVA.delta(b, s, DERIVA.plasticita_di(1.0))
			var cucciolo: float = DERIVA.delta(b, s, DERIVA.plasticita_di(0.0))
			t.ok(absf(cucciolo) >= absf(adulto) - 1e-12,
					"il cucciolo non e' mai segnato di meno")
			if not is_zero_approx(adulto):
				t.almost(cucciolo / adulto, DERIVA.PLASTICITA_CUCCIOLO,
						"e il rapporto e' esattamente la plasticita'", 1e-9)
	# e a meta' crescita sta in mezzo
	var meta: float = DERIVA.plasticita_di(0.5)
	t.almost(meta, (DERIVA.PLASTICITA_CUCCIOLO + 1.0) * 0.5,
			"a meta' strada la plasticita' e' a meta'", 1e-12)


# ── 7 ─────────────────────────────────────────────────────────────────────
## ⚠️ **IL CABLAGGIO, e senza questo caso tutto il resto sarebbe aritmetica
## che nessuno esegue.** Due `Animo` con la stessa identica storia e due
## eta' diverse devono avere DUE TRATTI DIVERSI — passando dalla porta vera
## (`tratto()`), non da `Deriva`.
func _l_eta_arriva_davvero_alla_DERIVA(t) -> void:
	var grande := _animo(1.0)
	var piccolo := _animo(0.0)
	for x in [grande, piccolo]:
		for _i in 8:
			x.ricorda("regalo", "giocatore", 0.8, 0.9)
		# ⚠️ **`tratto()` NON RICALCOLA NIENTE**: legge la cache. A rifarla
		# sono `setup`, `load`, il prestito e `passa_giorno` — e al `setup`
		# le prove non c'erano ancora. Si passa dalla porta vera, o si
		# misurerebbe una deriva di zero credendo che il cablaggio sia rotto.
		x.passa_giorno()
	var dg: float = grande.tratto("codardia") - grande.tratto_base("codardia")
	var dp: float = piccolo.tratto("codardia") - piccolo.tratto_base("codardia")
	t.ok(absf(dg) > 1e-4, "l'adulto deriva (%.5f)" % dg)
	t.ok(absf(dp) > absf(dg) * 1.5,
			"e il cucciolo deriva molto di piu' (%.5f contro %.5f)" % [dp, dg])
	t.almost(dp / dg, DERIVA.PLASTICITA_CUCCIOLO,
			"esattamente della plasticita' del cucciolo", 1e-6)
	# la base non si muove di un bit: chi era resta scritto
	t.almost(grande.tratto_base("codardia"), piccolo.tratto_base("codardia"),
			"e il genotipo e' identico nei due", 1e-12)


# ── 8 ─────────────────────────────────────────────────────────────────────
## Di serie si e' adulti (chi arriva col trolley), e l'eta' NON si salva: la
## sua casa e' `legami → <nome> → giorno_arrivo`, e una seconda copia qui
## sarebbe la seconda casa di un dato solo.
func _l_eta_non_si_salva_e_di_serie_si_e_adulti(t) -> void:
	var a = ANIMO.new()
	a.setup({"name": "P", "tratti": TRATTI.duplicate(), "sogno": "combattere"})
	t.almost(a.crescita, 1.0, "di serie si e' adulti: il gioco di ieri", 1e-12)
	a.crescita = 0.0
	var d: Dictionary = a.save()
	t.eq(d.has("crescita"), false, "e la crescita non entra nel salvataggio")
	# `Legami.crescita` torna 1.0 per chi non e' nato qui: e' la riga che
	# impedisce di dichiarare neonato ogni nuovo arrivato
	var lg = LEGAMI.new()
	t.almost(float(lg.crescita("MaiVisto")), 1.0,
			"chi non e' nato qui e' gia' cresciuto", 1e-12)
	lg.free()


# ── 9 ─────────────────────────────────────────────────────────────────────
func _derivato_propaga_la_plasticita(t) -> void:
	for b in [0.15, 0.5, 0.9]:
		for s in [-0.7, 0.6]:
			for p in [1.0, 1.5, DERIVA.PLASTICITA_MAX]:
				t.almost(DERIVA.derivato(b, s, p),
						clampf(b + DERIVA.delta(b, s, p), 0.0, 1.0),
						"derivato = base + delta, con la stessa plasticita'",
						1e-12)
			t.ok(absf(DERIVA.derivato(b, s, 2.0) - DERIVA.derivato(b, s, 1.0))
					> 1e-6, "e il parametro arriva davvero (b=%.2f)" % b)


# ── 10 ────────────────────────────────────────────────────────────────────
## ⚠️ **IL PONTE NON AVEVA UN SOLO LETTORE.** La fixture di questo file
## scriveva `crescita` e `_deriva_giorno` a mano, cioè ri-implementava
## esattamente `Visitors._presta_l_eta_a` — e nessun test della suite metteva
## un nodo nel gruppo `legami` guardando poi la deriva. Due mutazioni
## restavano verdi: «il ponte dichiara tutti adulti» (la finestra spenta in
## partita) e «il ponte non invalida la cache» (il prestito no-op, cioè
## **esattamente il difetto già pagato sulla compagnia**, che di là ha un
## caso e di qua non ce l'aveva).
func _il_ponte_porta_l_eta_davvero(t) -> void:
	var lg := FintiLegami.new()
	lg.crescite = {"Cucciolo": 0.2, "Grande": 1.0}
	t.stage(lg)
	var vis := RegistroVicini.new()
	t.stage(vis)

	var esiti: Dictionary = {}
	for nome in ["Cucciolo", "Grande"]:
		var a = ANIMO.new()
		a.setup({"name": nome, "tratti": TRATTI.duplicate(),
				"sogno": "combattere"})
		for _i in 8:
			a.ricorda("regalo", "giocatore", 0.8, 0.9)
		# la cache si riempie col valore di serie (adulto), come fa `load()`
		a.set("_deriva_giorno", -1)
		a.call("_ricalcola_deriva")
		var prima: float = a.tratto("codardia") - a.tratto_base("codardia")
		# ⇢ e adesso il PONTE VERO
		vis.call("_presta_l_eta_a", a, nome)
		esiti[nome] = {"crescita": float(a.get("crescita")),
				"prima": prima,
				"dopo": a.tratto("codardia") - a.tratto_base("codardia")}

	var cu: Dictionary = esiti["Cucciolo"]
	var gr: Dictionary = esiti["Grande"]
	t.almost(float(cu["crescita"]), 0.2,
			"il ponte porta la crescita vera dal gruppo «legami»", 1e-9)
	t.almost(float(gr["crescita"]), 1.0, "e l'adulto resta adulto", 1e-9)
	# ⚠️ e RICALCOLA: se invalidasse soltanto, `tratto()` leggerebbe ancora
	# la cache vecchia fino al prossimo `passa_giorno` — cioè la finestra
	# sarebbe spenta al caricamento e alla nascita, i due soli momenti in
	# cui c'è un cucciolo in scena.
	t.almost(float(gr["dopo"]), float(gr["prima"]),
			"per l'adulto non cambia un bit", 1e-12)
	t.ok(absf(float(cu["dopo"])) > absf(float(cu["prima"])) * 1.5,
			"e per il cucciolo la deriva si apre SUBITO (%.5f -> %.5f)"
			% [float(cu["prima"]), float(cu["dopo"])])
	t.almost(float(cu["dopo"]) / float(cu["prima"]),
			DERIVA.plasticita_di(0.2),
			"esattamente della plasticita' della sua eta'", 1e-6)


class FintiLegami extends Node:
	var crescite := {}
	func _ready() -> void:
		add_to_group("legami")
	func crescita(nome: String) -> float:
		return float(crescite.get(nome, 1.0))


class RegistroVicini extends "res://scenes/npc/Visitors.gd":
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
	func _process(_d: float) -> void:
		pass


# ── 11 ────────────────────────────────────────────────────────────────────
## ⚠️ **IL SECONDO CANCELLO DELL'AUTORE: nessuna barra, nessun contatore,
## nessuna lettera.** Se il giocatore capisce che esiste un periodo critico
## comincia a ottimizzare l'infanzia di un bambino, e un bambino
## ottimizzabile e' lo strumento che la regola 4 degli Affetti vieta per
## iscritto. La finestra si vede SOLO nel referto di un banco.
func _niente_barra_niente_contatore_niente_lettera(t) -> void:
	var sporchi: Array = []
	for cartella: String in ["res://scenes/ui", "res://systems"]:
		_scandaglia(cartella, sporchi)
	t.eq(sporchi.size(), 0,
			"la plasticita' non arriva a nessuna interfaccia: %s" % str(sporchi))
	# e non c'e' testo nuovo da nessuna parte
	var src := FileAccess.get_file_as_string("res://scenes/npc/Deriva.gd")
	t.ok(not src.contains("L10n."),
			"la finestra non ha una parola da dire a nessuno")


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
				if r.contains("plasticita") or r.contains("PLASTICITA"):
					fuori.append(via)
					break
		n = d.get_next()
	d.list_dir_end()
