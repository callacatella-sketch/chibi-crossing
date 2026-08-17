extends RefCounted
## LE CRICCHE — la prova che il gruppo è OSSERVATO, non deciso.
##
## Tutto quello che decide qui è puro: entra un elenco di incontri, esce un
## bool o un elenco di nomi. Nessun `randf` nel codice di produzione — e se
## un giorno ce ne fosse uno, una di queste prove diventerebbe intermittente
## e lo direbbe.
##
## ============================================================
## COSA CERCA DI ROMPERE, QUESTO FILE
## ============================================================
## Il modo in cui questa meccanica può fallire non è «non funziona»: è
## **funzionare su un dato che il gioco si è fabbricato da solo**. Un
## registro alimentato dai gesti che servono a MOSTRARE una cricca è una
## profezia, non un'osservazione — e la prima riga di questo file
## (`_l_invariante_del_campione`) è quella che lo rende impossibile, per
## costruzione e non per attenzione.
##
## L'altra metà è il falò: la sera i posti li assegna `_posto_al_falo(i)`,
## cioè l'ordine in cui la gente ha traslocato, e ne uscirebbero clique
## perfette che passano OGNI collaudo. Le prove vive qui sotto montano
## l'anello vero del fuoco e pretendono il silenzio — con la controprova
## nello stesso caso (lo stesso anello, di giorno, registra).

const CRICCHE := preload("res://scenes/npc/Cricche.gd")
const POSTO := preload("res://scenes/world/PostoDiSempre.gd")
const VISITORS := preload("res://scenes/npc/Visitors.gd")


func run(t) -> void:
	_l_invariante_del_campione(t)
	_una_riga_non_ha_verso(t)
	_tre_giornate_diverse_non_tre_ore(t)
	_l_ora_deve_combaciare(t)
	_l_ora_e_circolare(t)
	_il_posto_deve_combaciare(t)
	_niente_griglia(t)
	_il_futuro_non_si_legge(t)
	_l_isteresi_non_lampeggia(t)
	_l_isteresi_e_derivata(t)
	_la_memoria_copre_quel_che_l_isteresi_legge(t)
	_restare_non_costa_come_formarsi(t)
	_la_dissoluzione_non_e_un_evento(t)
	_una_coppia_non_e_un_gruppo(t)
	_niente_catene(t)
	_l_unione_deve_reggere(t)
	_mai_la_maggioranza(t)
	_sopra_il_tetto_si_tace(t)
	_la_piazza_non_e_una_cricca(t)
	_a_pari_merito_non_si_elegge(t)
	_le_cricche_si_sovrappongono(t)
	_due_macchie_non_si_confondono(t)
	_l_anagrafe_non_decide(t)
	_i_quattro_cancelli(t)
	_il_falo_non_conta(t)
	_il_giro_aspetta_l_anagrafe(t)
	_la_catena_intera(t)
	_il_nodo_e_nel_livello(t)
	_il_registro_sopravvive_al_salvataggio(t)


# ============================================================ gli attrezzi

## Un registro, passando dalla PORTA VERA (`registra`): così ogni banco di
## questo file eredita la regola del campione unico invece di aggirarla.
static func _reg(righe: Array) -> Array:
	var inc: Array = []
	for r in righe:
		var v := r as Array
		CRICCHE.registra(inc, str(v[0]), str(v[1]), int(v[2]), float(v[3]),
				Vector3(float(v[4]), 0.0, float(v[5])))
	return inc


## Una coppia che si trova nei `giorni` dati, sempre alla stessa ora e nello
## stesso punto.
static func _coppia(inc: Array, a: String, b: String, giorni: Array,
		ora: float, dove: Vector2) -> void:
	for g in giorni:
		CRICCHE.registra(inc, a, b, int(g), ora, Vector3(dove.x, 0.0, dove.y))


## Tutti con tutti, dentro un gruppo.
static func _gruppo(inc: Array, nomi: Array, giorni: Array, ora: float,
		dove: Vector2) -> void:
	for i in nomi.size():
		for j in range(i + 1, nomi.size()):
			_coppia(inc, str(nomi[i]), str(nomi[j]), giorni, ora, dove)


static func _nomi(a: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for n in a:
		out.append(str(n))
	return out


static func _elenco(cricche: Array) -> Array:
	var out: Array = []
	for c in cricche:
		out.append("+".join(c as PackedStringArray))
	out.sort()
	return out


# ============================================================ il campione

## ⚠️ **L'INVARIANTE CENTRALE, e regge tutta la meccanica.**
##
## Si tiene il PRIMO incontro della giornata e basta. Quindi: aggiungere
## incontri in giornate GIÀ CONTATE non cambia un bit dell'uscita — a
## qualunque ora, in qualunque punto, quante volte si vuole.
##
## Non è una gentilezza verso il risparmio di memoria: è la proprietà per
## cui **nessun sostegno che il gioco vorrà dare a una cricca potrà mai
## alimentarla**. Il giorno che due vicini si fermeranno l'uno per l'altro
## perché si sono trovati, quel fermarsi cade su una giornata già contata e
## vale ZERO. Senza questa riga il sistema si nutre di sé stesso, e nessun
## test sulle soglie se ne accorgerebbe.
func _l_invariante_del_campione(t) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260814
	var tutti := _nomi(["Anna", "Bruno", "Carla", "Dino", "Emma"])
	var uguali := 0
	var rifiutati := 0
	for _giro in 40:
		var inc: Array = []
		for _k in 60:
			var a := str(tutti[rng.randi() % tutti.size()])
			var b := str(tutti[rng.randi() % tutti.size()])
			CRICCHE.registra(inc, a, b, rng.randi_range(1, 12),
					rng.randf(), Vector3(rng.randf_range(-8.0, 8.0), 0.0,
					rng.randf_range(-8.0, 8.0)))
		var prima := _elenco(CRICCHE.cricche(inc, tutti, 12, 12))
		var quante := inc.size()
		# adesso si insiste: le STESSE coppie, negli STESSI giorni, ma con
		# ore e posti completamente diversi. È il caso peggiore possibile —
		# se una sola di queste righe entrasse, le medie si sposterebbero.
		for r in inc.duplicate():
			var riga := r as Dictionary
			var scritto := CRICCHE.registra(inc, str(riga["a"]), str(riga["b"]),
					int(riga["d"]), rng.randf(),
					Vector3(rng.randf_range(-40.0, 40.0), 0.0,
					rng.randf_range(-40.0, 40.0)))
			if not scritto:
				rifiutati += 1
		t.eq(inc.size(), quante, "nessuna riga in più su una giornata già contata")
		if _elenco(CRICCHE.cricche(inc, tutti, 12, 12)) == prima:
			uguali += 1
	t.eq(uguali, 40, "l'uscita non cambia di un bit su quaranta registri a caso")
	t.ok(rifiutati > 500, "…e i rifiuti sono tanti quanti i tentativi (%d)"
			% rifiutati)


## LA RIGA NON HA UN VERSO: i due nomi in ordine alfabetico, cioè in un
## ordine che non vuol dire niente. Da una riga senza verso non si ricava
## chi cercava chi, quindi non si ricava un giudizio — è l'opposto esatto
## di `Affetti.ASIMMETRIA`, e qui è voluto.
func _una_riga_non_ha_verso(t) -> void:
	var uno: Array = []
	CRICCHE.registra(uno, "Zoe", "Anna", 3, 0.5, Vector3(1, 0, 2))
	t.eq(str((uno[0] as Dictionary)["a"]), "Anna", "il primo nome è il minore")
	t.eq(str((uno[0] as Dictionary)["b"]), "Zoe", "…e il secondo il maggiore")
	# e chiamarla al contrario è la stessa riga: non se ne scrive una seconda
	t.ok(not CRICCHE.registra(uno, "Anna", "Zoe", 3, 0.9, Vector3(9, 0, 9)),
			"l'incontro rovesciato è lo stesso incontro")
	t.eq(uno.size(), 1, "…e il registro resta di una riga sola")
	t.eq(CRICCHE.chiave("Zoe", "Anna"), CRICCHE.chiave("Anna", "Zoe"),
			"la chiave della coppia non ha un verso")
	t.eq(CRICCHE.campioni(uno, "Zoe", "Anna").size(), 1,
			"e la si ritrova chiedendo nei due versi")
	# ⚠️ LA GRANA DEL DISCO NON PUÒ TOCCARE UNA DECISIONE. Il registro va nel
	# salvataggio e si arrotonda per non gonfiarlo (49,6 KB → 33,6 KB su un
	# `village.json` che ne pesa 85), ma il passo deve restare enormemente
	# più fine delle soglie che alimenta: chi lo allargasse per risparmiare
	# altri byte comincerebbe a spostare le medie.
	t.ok(CRICCHE.PASSO_ORA * 100.0 <= CRICCHE.ORA_STRETTA,
			"la grana dell'ora è almeno cento volte più fine della soglia")
	t.ok(CRICCHE.PASSO_POSTO * 100.0 <= CRICCHE.POSTO_STRETTO,
			"…e quella del posto pure")
	var fine: Array = []
	CRICCHE.registra(fine, "Anna", "Bruno", 1, 0.4712345678, Vector3(1.23456, 0, -7.89123))
	var riga: Dictionary = fine[0]
	t.ok(absf(float(riga["o"]) - 0.4712345678) <= CRICCHE.PASSO_ORA,
			"l'ora scritta non si scosta più di un passo da quella vera")
	t.ok(absf(float(riga["x"]) - 1.23456) <= CRICCHE.PASSO_POSTO,
			"…e nemmeno il posto")


# ============================================================ le tre soglie

## TRE GIORNATE DIVERSE, non tre ore. È `PostoDiSempre`: tre pomeriggi di
## fila sullo stesso sasso sono un'abitudine, tre ore nello stesso
## pomeriggio no.
func _tre_giornate_diverse_non_tre_ore(t) -> void:
	t.eq(CRICCHE.GIORNATE_RITROVO, POSTO.GIORNI_ABITUDINE,
			"le giornate che fanno un'abitudine si leggono da PostoDiSempre")
	var stesso_giorno := _reg([
		["Anna", "Bruno", 3, 0.50, 4, 4],
		["Anna", "Bruno", 3, 0.51, 4, 4],
		["Anna", "Bruno", 3, 0.52, 4, 4],
	])
	t.ok(not CRICCHE.abitudine(stesso_giorno, "Anna", "Bruno", 3),
			"tre incontri nello stesso pomeriggio non sono un'abitudine")
	var tre_giorni := _reg([
		["Anna", "Bruno", 1, 0.50, 4, 4],
		["Anna", "Bruno", 2, 0.52, 4, 4],
		["Anna", "Bruno", 3, 0.54, 4, 4],
	])
	t.ok(CRICCHE.abitudine(tre_giorni, "Anna", "Bruno", 3),
			"tre giornate diverse sì")
	# due sole non bastano MAI a formarla (l'isteresi tiene, non forma)
	var due := _reg([
		["Anna", "Bruno", 2, 0.50, 4, 4],
		["Anna", "Bruno", 3, 0.50, 4, 4],
	])
	t.ok(not CRICCHE.abitudine(due, "Anna", "Bruno", 3),
			"due giornate non formano niente")


## L'ORA DEVE COMBACIARE, e la soglia non è un numero di gusto: è la fascia
## di `PostoDiSempre` (un ottavo di giornata) tradotta in dispersione
## circolare. Cinque centesimi di giornata di sbandamento — dodici secondi
## reali — sono già troppi.
func _l_ora_deve_combaciare(t) -> void:
	var stretti := _reg([
		["Anna", "Bruno", 1, 0.50, 4, 4],
		["Anna", "Bruno", 2, 0.52, 4, 4],
		["Anna", "Bruno", 3, 0.54, 4, 4],
	])
	t.ok(CRICCHE.abitudine(stretti, "Anna", "Bruno", 3),
			"quattro centesimi di giornata di scarto sono la stessa ora")
	var larghi := _reg([
		["Anna", "Bruno", 1, 0.50, 4, 4],
		["Anna", "Bruno", 2, 0.55, 4, 4],
		["Anna", "Bruno", 3, 0.60, 4, 4],
	])
	t.ok(not CRICCHE.abitudine(larghi, "Anna", "Bruno", 3),
			"dieci centesimi no: quello è essersi visti, non ritrovarsi")
	var sparsi := _reg([
		["Anna", "Bruno", 1, 0.20, 4, 4],
		["Anna", "Bruno", 2, 0.50, 4, 4],
		["Anna", "Bruno", 3, 0.80, 4, 4],
	])
	t.ok(not CRICCHE.abitudine(sparsi, "Anna", "Bruno", 3),
			"e a ore sparse per la giornata, tanto meno")


## L'ORA È CIRCOLARE. Mezzanotte meno un attimo e mezzanotte più un attimo
## sono LA STESSA ORA: con una media lineare quei tre incontri darebbero
## mezzogiorno, e una deviazione standard enorme — cioè il ritrovo notturno
## sarebbe l'unico che il gioco non sa vedere.
func _l_ora_e_circolare(t) -> void:
	var notte := _reg([
		["Anna", "Bruno", 1, 0.99, 4, 4],
		["Anna", "Bruno", 2, 0.00, 4, 4],
		["Anna", "Bruno", 3, 0.01, 4, 4],
	])
	t.ok(CRICCHE.abitudine(notte, "Anna", "Bruno", 3),
			"ci si ritrova anche a cavallo della mezzanotte")
	var rit := CRICCHE.ritrovo_vivo(notte, "Anna", "Bruno", 3)
	var ora := float(rit.get("ora", -1.0))
	t.ok(ora > 0.99 or ora < 0.01,
			"…e l'ora del ritrovo è la mezzanotte (%.4f), non mezzogiorno" % ora)


## IL POSTO DEVE COMBACIARE, e la soglia è `PostoDiSempre.CELLA`: il lato
## del quadrato che in questo gioco vuol già dire «lo stesso posto».
func _il_posto_deve_combaciare(t) -> void:
	t.almost(CRICCHE.POSTO_STRETTO, POSTO.CELLA,
			"il metro del posto si legge da PostoDiSempre", 0.0001)
	var vicini := _reg([
		["Anna", "Bruno", 1, 0.50, 0, 0],
		["Anna", "Bruno", 2, 0.50, 3, 0],
		["Anna", "Bruno", 3, 0.50, -3, 0],
	])
	t.ok(CRICCHE.abitudine(vicini, "Anna", "Bruno", 3),
			"tre metri di sbandamento sono ancora lo stesso angolo")
	var lontani := _reg([
		["Anna", "Bruno", 1, 0.50, 0, 0],
		["Anna", "Bruno", 2, 0.50, 4, 0],
		["Anna", "Bruno", 3, 0.50, -4, 0],
	])
	t.ok(not CRICCHE.abitudine(lontani, "Anna", "Bruno", 3),
			"quattro no: tre punti sparsi sul prato non sono un posto")


## ⚠️ **NIENTE GRIGLIA.** `PostoDiSempre.chiave()` quantizza in quadrati da
## tre metri, ed è giusto per lui (guarda UN corpo che si ferma). Qui no:
## un trio che si trova a cavallo di un confine cadrebbe in celle diverse
## ogni giorno e non si formerebbe MAI — un gruppo che non nasce perché una
## linea invisibile gli passa in mezzo è un guasto che non lascia tracce.
## Si eredita la costante, non la quantizzazione.
func _niente_griglia(t) -> void:
	var punti := [Vector2(2.9, 0.1), Vector2(3.1, -0.1), Vector2(3.0, 0.2)]
	var chiavi := {}
	for p in punti:
		chiavi[POSTO.chiave(Vector3(p.x, 0.0, p.y), 0.5)] = true
	t.ok(chiavi.size() > 1,
			"il banco è quello giusto: la griglia spezzerebbe questi tre punti"
			+ " in %d celle diverse" % chiavi.size())
	var inc: Array = []
	for i in punti.size():
		CRICCHE.registra(inc, "Anna", "Bruno", i + 1, 0.50,
				Vector3(punti[i].x, 0.0, punti[i].y))
	t.ok(CRICCHE.abitudine(inc, "Anna", "Bruno", 3),
			"…e per noi restano lo stesso posto")


## ⚠️ **IL FUTURO NON SI LEGGE.** Il setaccio dell'isteresi rifà la storia
## giorno per giorno: se in una lettura del passato entrassero i campioni
## di dopo, ogni giornata saprebbe come è andata a finire.
func _il_futuro_non_si_legge(t) -> void:
	var inc := _reg([
		["Anna", "Bruno", 1, 0.50, 4, 4],
		["Anna", "Bruno", 2, 0.50, 4, 4],
		["Anna", "Bruno", 3, 0.50, 4, 4],
		["Anna", "Bruno", 6, 0.50, 4, 4],
		["Anna", "Bruno", 7, 0.50, 4, 4],
	])
	var prof := CRICCHE.profilo(CRICCHE.campioni(inc, "Anna", "Bruno"), 10)
	var al_cinque := CRICCHE.rapporto_da(prof, 5, CRICCHE.FINESTRA)
	t.eq(int(al_cinque["giorni"]), 3,
			"guardando dal giorno 5 si vedono tre giornate, non cinque")
	t.eq(int(al_cinque["ultimo"]), 3,
			"…e l'ultima volta che ci si è visti è il giorno 3")
	var oggi := CRICCHE.rapporto_da(prof, 10, CRICCHE.FINESTRA)
	t.eq(int(oggi["giorni"]), 2,
			"guardando da oggi (10) ne restano due: le prime tre sono uscite"
			+ " dalla settimana")
	t.eq(int(CRICCHE.rapporto_da(prof, 10, CRICCHE.FINESTRA_LUNGA)["giorni"]), 5,
			"…e la finestra lunga le vede tutte e cinque")
	t.ok(CRICCHE.rapporto_da(prof, 11, CRICCHE.FINESTRA).is_empty(),
			"e al di là di oggi non c'è niente da leggere")


# ============================================================ l'isteresi

## FORMARSI COSTA, RESTARE NO. Senza, una cricca sul filo lampeggia a
## giorni alterni e il calendario fa il lavoro che devono fare gli incontri.
##
## Il banco: ci si trova nei giorni 1, 2, 3 e poi l'8. Il giorno 8 la
## finestra corta ne conta ancora tre (2, 3, 8) e l'abitudine si FORMA; il
## 9 ne conta due e con le sole soglie strette morirebbe — per riaccendersi
## al primo incontro dopo. È esattamente il lampeggio.
func _l_isteresi_non_lampeggia(t) -> void:
	var inc := _reg([
		["Anna", "Bruno", 1, 0.50, 4, 4],
		["Anna", "Bruno", 2, 0.50, 4, 4],
		["Anna", "Bruno", 3, 0.50, 4, 4],
		["Anna", "Bruno", 8, 0.50, 4, 4],
	])
	t.ok(CRICCHE.abitudine(inc, "Anna", "Bruno", 8),
			"l'ottavo giorno si ritrovano")
	# la controprova: con le sole soglie di FORMAZIONE, il nono giorno è morto
	t.ok(CRICCHE.ritrovo(inc, "Anna", "Bruno", 9, CRICCHE.GIORNATE_RITROVO,
			CRICCHE.ORA_STRETTA, CRICCHE.POSTO_STRETTO,
			CRICCHE.FINESTRA).is_empty(),
			"…e il nono, a chiedere le soglie strette, non si ritroverebbero")
	t.ok(CRICCHE.abitudine(inc, "Anna", "Bruno", 9),
			"ma restare non costa: il nono giorno si ritrovano ancora")
	# IL REFERTO È LA RISPOSTA PIÙ AGGIORNATA, non il riassunto di due
	# settimane: chi vorrà sapere DOVE e A CHE ORA si trovano deve ricevere
	# quel che è successo nell'ultima settimana, non la media di quattro
	# incontri di cui due vecchi di dieci giorni.
	var rit := CRICCHE.ritrovo_vivo(inc, "Anna", "Bruno", 9)
	t.eq(int(rit["giorni"]), 2, "il referto conta le giornate dell'ultima settimana")
	t.eq(int(rit["ultimo"]), 8, "…e sa quand'è stata l'ultima volta")
	t.ok(not CRICCHE.abitudine(inc, "Anna", "Bruno", 12),
			"e senza più incontri, prima o poi smette di essere vero")


## ⚠️ **L'ISTERESI È DERIVATA, NON RICORDATA.** Non c'è nessun
## `_cricche_ieri` da nessuna parte, e la prova è che la risposta di oggi si
## ottiene chiamando la funzione UNA VOLTA SOLA, senza averla mai chiamata
## ieri: il passato lo tiene il registro.
##
## (Vale anche fuori di qui: dimostra che `Affetti._coppie_ieri`, oggi
## dentro `save_extra()`, è uno stato che si potrebbe togliere.)
func _l_isteresi_e_derivata(t) -> void:
	var inc := _reg([
		["Anna", "Bruno", 1, 0.50, 4, 4],
		["Anna", "Bruno", 2, 0.50, 4, 4],
		["Anna", "Bruno", 3, 0.50, 4, 4],
		["Anna", "Bruno", 8, 0.50, 4, 4],
	])
	# nessuno ha mai chiesto del giorno 8: si chiede del 9 e basta
	t.ok(CRICCHE.abitudine(inc, "Anna", "Bruno", 9),
			"il nono giorno è vivo senza che nessuno abbia chiesto dell'ottavo")
	# e l'ordine delle domande non cambia nessuna risposta
	var a_ritroso: Array = []
	for g in [12, 9, 8, 3]:
		a_ritroso.append(CRICCHE.abitudine(inc, "Anna", "Bruno", int(g)))
	var in_avanti: Array = []
	for g2 in [3, 8, 9, 12]:
		in_avanti.append(CRICCHE.abitudine(inc, "Anna", "Bruno", int(g2)))
	in_avanti.reverse()
	t.eq(a_ritroso, in_avanti,
			"le stesse quattro domande, in due ordini, danno le stesse risposte")


## ⚠️ **LA MEMORIA DEL REGISTRO COPRE QUEL CHE L'ISTERESI LEGGE**, e non è
## un numero di gusto.
##
## Il setaccio rifà la storia da `oggi - FINESTRA_LUNGA`, e in quel giorno
## legge la SUA finestra lunga: la riga più vecchia che serve ha
## `2·FINESTRA_LUNGA − 1` giorni. Potare più corto non fa risparmiare: fa
## leggere un passato TRONCATO, e il predicato comincia a rispondere «non si
## sono mai trovati» su gente che si trovava — in silenzio, e solo alle
## partite lunghe.
##
## Il banco è una coppia che si è FORMATA nei giorni 1-3 e da allora si vede
## due volte a settimana: abbastanza per restare, mai abbastanza per
## riformarsi.
func _la_memoria_copre_quel_che_l_isteresi_legge(t) -> void:
	t.ok(CRICCHE.MEMORIA >= CRICCHE.FINESTRA_LUNGA + CRICCHE.FINESTRA,
			"la memoria dichiarata copre la lettura più vecchia del setaccio")
	var inc := _reg([
		["Anna", "Bruno", 1, 0.50, 4, 4],
		["Anna", "Bruno", 2, 0.50, 4, 4],
		["Anna", "Bruno", 3, 0.50, 4, 4],
		["Anna", "Bruno", 7, 0.50, 4, 4],
		["Anna", "Bruno", 10, 0.50, 4, 4],
		["Anna", "Bruno", 14, 0.50, 4, 4],
		["Anna", "Bruno", 17, 0.50, 4, 4],
	])
	t.ok(CRICCHE.abitudine(inc, "Anna", "Bruno", 20),
			"venti giorni dopo si ritrovano ancora")
	var potato := CRICCHE.pota(inc, 20, CRICCHE.MEMORIA)
	t.eq(potato.size(), inc.size(), "la potatura vera non butta niente di utile")
	t.ok(CRICCHE.abitudine(potato, "Anna", "Bruno", 20),
			"…e infatti la risposta non cambia")
	# e la controprova: potare a quattordici giorni cancella il giorno in cui
	# si erano trovati, e la coppia sparisce
	var corto := CRICCHE.pota(inc, 20, CRICCHE.FINESTRA_LUNGA)
	t.ok(corto.size() < inc.size(), "potando a due settimane si butta qualcosa")
	t.ok(not CRICCHE.abitudine(corto, "Anna", "Bruno", 20),
			"…ed è proprio quello che li teneva insieme: sparisce la coppia")
	# E IL REGISTRO NON CONSERVA COSE CHE NON SONO ANCORA SUCCESSE: un
	# salvataggio storto (o un orologio che torna indietro) può portare una
	# riga datata domani, e una riga così resterebbe lì finché il calendario
	# non la raggiunge.
	var domani := inc.duplicate(true)
	CRICCHE.registra(domani, "Anna", "Bruno", 45, 0.5, Vector3(4, 0, 4))
	t.eq(domani.size(), inc.size() + 1, "la riga di domani entra nel registro")
	t.eq(CRICCHE.pota(domani, 20, CRICCHE.MEMORIA).size(), inc.size(),
			"…e la potatura la butta")
	t.ok(CRICCHE.abitudine(domani, "Anna", "Bruno", 20),
			"e intanto non ha spostato nessuna risposta")


## ⚠️ **RESTARE NON COSTA COME FORMARSI, E NON SOLO NEL CONTEGGIO.** Le tre
## soglie si allargano insieme: chi resta può vedersi meno spesso, può
## cominciare a sbagliare l'ora, può spostarsi di un metro. Se si allargasse
## solo il numero di giornate, una cricca si scioglierebbe perché il ritrovo
## si è spostato di poco — e sarebbe il calendario travestito da gesto,
## esattamente quello che l'isteresi esiste per impedire.
##
## Le due scene sono tarate sul filo: al nono giorno la lettura sta FRA la
## soglia stretta e quella larga.
func _restare_non_costa_come_formarsi(t) -> void:
	# l'ORA che comincia a ballare
	var ora := _reg([
		["Anna", "Bruno", 1, 0.50, 4, 4],
		["Anna", "Bruno", 2, 0.50, 4, 4],
		["Anna", "Bruno", 3, 0.50, 4, 4],
		["Anna", "Bruno", 8, 0.59, 4, 4],
	])
	var lettura := CRICCHE.rapporto_da(
			CRICCHE.profilo(CRICCHE.campioni(ora, "Anna", "Bruno"), 9),
			9, CRICCHE.FINESTRA)
	t.ok(float(lettura["disp"]) > CRICCHE.ORA_STRETTA
			and float(lettura["disp"]) <= CRICCHE.ORA_LARGA,
			"il banco è sul filo: l'ora balla %.4f, fra %.3f e %.3f"
			% [lettura["disp"], CRICCHE.ORA_STRETTA, CRICCHE.ORA_LARGA])
	t.ok(CRICCHE.abitudine(ora, "Anna", "Bruno", 9),
			"chi si è già trovato resta anche se l'ora comincia a ballare")
	# il POSTO che si sposta
	var posto := _reg([
		["Anna", "Bruno", 1, 0.50, 0, 0],
		["Anna", "Bruno", 2, 0.50, 0, 0],
		["Anna", "Bruno", 3, 0.50, 0, 0],
		["Anna", "Bruno", 8, 0.50, 7, 0],
	])
	var l2 := CRICCHE.rapporto_da(
			CRICCHE.profilo(CRICCHE.campioni(posto, "Anna", "Bruno"), 9),
			9, CRICCHE.FINESTRA)
	t.ok(float(l2["rms"]) > CRICCHE.POSTO_STRETTO
			and float(l2["rms"]) <= CRICCHE.POSTO_LARGO,
			"…e qui il posto balla %.2f m, fra %.1f e %.1f"
			% [l2["rms"], CRICCHE.POSTO_STRETTO, CRICCHE.POSTO_LARGO])
	t.ok(CRICCHE.abitudine(posto, "Anna", "Bruno", 9),
			"…e resta anche se il ritrovo si sposta di qualche metro")
	# ma nessuna delle due FORMEREBBE niente da zero
	var da_zero := _reg([
		["Carla", "Dino", 7, 0.50, 0, 0],
		["Carla", "Dino", 8, 0.50, 7, 0],
		["Carla", "Dino", 9, 0.59, 0, 0],
	])
	t.ok(not CRICCHE.abitudine(da_zero, "Carla", "Dino", 9),
			"ma con quelle stesse larghezze, da zero, non si forma niente")


## LA DISSOLUZIONE NON È UN EVENTO. Non c'è nessuna riga «si sono
## lasciati», nessun contatore che scende, nessuna posa da togliere: il
## predicato smette di essere vero, e il registro non cambia di una virgola.
func _la_dissoluzione_non_e_un_evento(t) -> void:
	var inc := _reg([
		["Anna", "Bruno", 1, 0.50, 4, 4],
		["Anna", "Bruno", 2, 0.50, 4, 4],
		["Anna", "Bruno", 3, 0.50, 4, 4],
	])
	var prima := inc.duplicate(true)
	t.ok(CRICCHE.abitudine(inc, "Anna", "Bruno", 3), "il terzo giorno sì")
	t.ok(not CRICCHE.abitudine(inc, "Anna", "Bruno", 40), "il quarantesimo no")
	t.eq(inc.size(), prima.size(),
			"e chiederlo non ha scritto niente da nessuna parte")
	t.eq(str(inc), str(prima), "…proprio niente: il registro è identico")


# ============================================================ le cricche

## UNA COPPIA NON È UN GRUPPO: le coppie il gioco ce le ha già
## (`Affetti.coppia()`), e sono un'altra cosa. Una cricca comincia da tre.
func _una_coppia_non_e_un_gruppo(t) -> void:
	var inc: Array = []
	_coppia(inc, "Anna", "Bruno", [1, 2, 3], 0.5, Vector2(4, 4))
	var tutti := _nomi(["Anna", "Bruno", "Carla", "Dino", "Emma", "Fiore"])
	t.ok(CRICCHE.abitudine(inc, "Anna", "Bruno", 3), "loro due si ritrovano")
	t.eq(CRICCHE.cricca_di(inc, "Anna", tutti, 6, 3).size(), 0,
			"…ma non sono una cricca")
	t.eq(CRICCHE.cricche(inc, tutti, 6, 3).size(), 0,
			"e nel villaggio non c'è nessuna cricca")


## NESSUNO ENTRA PER CATENA. Se bastasse essere connessi, due coppie che
## condividono una persona sarebbero un gruppo di tre — e i due agli estremi
## non si sono mai trovati.
func _niente_catene(t) -> void:
	var inc: Array = []
	_coppia(inc, "Anna", "Bruno", [1, 2, 3], 0.5, Vector2(4, 4))
	_coppia(inc, "Bruno", "Carla", [1, 2, 3], 0.5, Vector2(4, 4))
	var tutti := _nomi(["Anna", "Bruno", "Carla", "Dino", "Emma", "Fiore"])
	t.eq(CRICCHE.cricca_di(inc, "Bruno", tutti, 6, 3).size(), 0,
			"chi conosce due persone che non si conoscono non ha una cricca")
	# la controprova: basta che i due estremi si trovino, e la cricca c'è
	_coppia(inc, "Anna", "Carla", [1, 2, 3], 0.5, Vector2(4, 4))
	t.eq("+".join(CRICCHE.cricca_di(inc, "Bruno", tutti, 6, 3)),
			"Anna+Bruno+Carla", "chiuso il triangolo, la cricca c'è")


## LA STESSA REGOLA, A DUE SCALE. Un gruppo non è vero perché le sue coppie
## lo sono una per una: l'UNIONE delle loro righe deve superare lo stesso
## identico collaudo. Senza, tre coppie che si trovano in tre angoli diversi
## del villaggio sarebbero una cricca — e non si sono mai visti in tre.
func _l_unione_deve_reggere(t) -> void:
	var inc: Array = []
	_coppia(inc, "Anna", "Bruno", [1, 2, 3], 0.5, Vector2(0, 0))
	_coppia(inc, "Bruno", "Carla", [1, 2, 3], 0.5, Vector2(30, 0))
	_coppia(inc, "Anna", "Carla", [1, 2, 3], 0.5, Vector2(0, 30))
	var tutti := _nomi(["Anna", "Bruno", "Carla", "Dino", "Emma", "Fiore"])
	t.ok(CRICCHE.abitudine(inc, "Anna", "Bruno", 3), "a due a due si ritrovano")
	t.ok(CRICCHE.abitudine(inc, "Bruno", "Carla", 3), "…tutte e tre le coppie")
	t.ok(CRICCHE.abitudine(inc, "Anna", "Carla", 3), "…davvero tutte e tre")
	t.eq(CRICCHE.cricca_di(inc, "Anna", tutti, 6, 3).size(), 0,
			"ma in tre angoli diversi del prato non sono un gruppo")
	# e la stessa scena con gli stessi giorni, nello stesso angolo, sì
	var insieme: Array = []
	_gruppo(insieme, ["Anna", "Bruno", "Carla"], [1, 2, 3], 0.5, Vector2(0, 0))
	t.eq("+".join(CRICCHE.cricca_di(insieme, "Anna", tutti, 6, 3)),
			"Anna+Bruno+Carla", "nello stesso angolo sì")
	# ⚠️ E ALLA SCALA DEL GRUPPO SI CONTANO LE GIORNATE, NON LE RIGHE: tre
	# coppie che si trovano negli stessi tre giorni scrivono nove righe, e
	# nove non è «nove giornate» — a contarle si formerebbero gruppi che non
	# hanno mai passato insieme il tempo che la soglia chiede.
	var prof := CRICCHE.profilo(insieme, 3)
	t.eq(int(CRICCHE.rapporto_da(prof, 3, CRICCHE.FINESTRA)["giorni"]), 3,
			"nove righe in tre giornate restano tre giornate")


## MAI LA MAGGIORANZA: `2·membri ≤ presenti`. Un villaggio di cinque persone
## in cui tre «sono un gruppo» ha due esclusi, e li ha fatti il gioco.
func _mai_la_maggioranza(t) -> void:
	var inc: Array = []
	_gruppo(inc, ["Anna", "Bruno", "Carla"], [1, 2, 3], 0.5, Vector2(2, 2))
	var tutti := _nomi(["Anna", "Bruno", "Carla", "Dino", "Emma", "Fiore"])
	t.eq(CRICCHE.cricca_di(inc, "Anna", tutti, 4, 3).size(), 0,
			"in un villaggio di quattro, tre non sono una cricca")
	t.eq(CRICCHE.cricca_di(inc, "Anna", tutti, 5, 3).size(), 0,
			"…e nemmeno in uno di cinque")
	t.eq(CRICCHE.cricca_di(inc, "Anna", tutti, 6, 3).size(), 3,
			"da sei in su sì: tre non sono più la maggioranza")


## SOPRA IL TETTO SI TACE — non si tronca. *Scegliere quattro su cinque vuol
## dire che è stato il gioco a lasciare fuori il quinto*, e il quinto lo
## vedrebbe.
##
## ⚠️ **E IL BANCO HA DOVUTO DIVENTARE PIÙ CATTIVO**, perché la prima
## stesura non provava questa riga: con cinque che si ritrovano tutti allo
## stesso modo, i quattro sottogruppi possibili PAREGGIANO, e a troncare
## sarebbe uscito silenzio comunque — per merito della regola del pareggio,
## non di questa. Qui i giorni sono fatti apposta perché un sottogruppo da
## quattro STACCHI gli altri: se si tronca, quel gruppo esce.
func _sopra_il_tetto_si_tace(t) -> void:
	var cinque := ["Anna", "Bruno", "Carla", "Dino", "Emma"]
	var inc: Array = []
	_gruppo(inc, cinque, [1, 2, 3], 0.5, Vector2(2, 2))
	# due incontri in più che rompono ogni pareggio: il sottogruppo
	# Anna+Bruno+Dino+Emma ha cinque giornate, tutti gli altri quattro o tre
	_coppia(inc, "Dino", "Emma", [5], 0.5, Vector2(2, 2))
	_coppia(inc, "Bruno", "Dino", [6], 0.5, Vector2(2, 2))
	var tutti := _nomi(cinque + ["Fiore", "Gigi", "Hana", "Iris", "Lea",
			"Milo", "Nina", "Olmo", "Pino", "Rea", "Sole", "Tino", "Ugo",
			"Vera", "Zeno"])
	t.eq(int(tutti.size()), 20, "il villaggio del banco ha venti presenti")
	for n in cinque:
		t.eq(CRICCHE.cricca_di(inc, str(n), tutti, 20, 6).size(), 0,
				"%s non riceve un gruppo di quattro su cinque: silenzio" % n)
	t.eq(CRICCHE.cricche(inc, tutti, 20, 6).size(), 0,
			"e nel villaggio non risulta nessuna cricca")
	# la controprova: in quattro, lo stesso identico gruppo esiste
	var quattro: Array = []
	_gruppo(quattro, ["Anna", "Bruno", "Carla", "Dino"], [1, 2, 3], 0.5,
			Vector2(2, 2))
	t.eq("+".join(CRICCHE.cricca_di(quattro, "Anna", tutti, 20, 3)),
			"Anna+Bruno+Carla+Dino", "in quattro sì, ed è il tetto")


## *Un villaggio in cui tutti si ritrovano con tutti non ha cricche: ha una
## piazza.* Sopra la macchia massima si tace, invece di ritagliare dentro la
## folla il sottogruppo che il gioco preferisce.
##
## ⚠️ **E ANCHE QUESTO BANCO HA DOVUTO DIVENTARE PIÙ CATTIVO.** Con nove
## persone tutte appiccicate, togliere il tetto della macchia non cambiava
## niente: la clique da nove sfonda comunque il tetto dei membri, e il
## silenzio arrivava da quell'altra regola. La scena che distingue le due è
## una FOLLA LARGA — nove che si ritrovano tutti a due a due, ma ognuno in
## un angolo suo — con dentro un quartetto compatto: senza il tetto della
## macchia, il gioco pescherebbe quei quattro da una piazza di nove.
func _la_piazza_non_e_una_cricca(t) -> void:
	var nomi: Array = []
	for i in CRICCHE.TETTO_COMPONENTE + 1:
		nomi.append("Vicino%d" % i)
	var stretti: Array = []
	_gruppo(stretti, nomi, [1, 2, 3], 0.5, Vector2(2, 2))
	var tutti := _nomi(nomi)
	for i2 in 6:
		tutti.append("Estraneo%d" % i2)
	t.eq(CRICCHE.cricca_di(stretti, str(nomi[0]), tutti, tutti.size(),
			3).size(), 0,
			"nove che si ritrovano tutti con tutti non sono una cricca")
	t.eq(CRICCHE.cricche(stretti, tutti, tutti.size(), 3).size(), 0,
			"…e il villaggio non ne ha nessuna")
	# la piazza LARGA: gli stessi nove, ma ogni coppia in un angolo suo —
	# tranne i primi quattro, che stanno sempre nello stesso punto
	var larghi: Array = []
	for i3 in nomi.size():
		for j in range(i3 + 1, nomi.size()):
			var dove := Vector2(0, 0)
			if i3 > 3 or j > 3:
				dove = Vector2(float((i3 * 17) % 61 - 30),
						float((j * 23) % 61 - 30))
			_coppia(larghi, str(nomi[i3]), str(nomi[j]), [1, 2, 3], 0.5, dove)
	# il quartetto compatto esiste davvero, e da solo sarebbe una cricca
	var soli: Array = []
	_gruppo(soli, [nomi[0], nomi[1], nomi[2], nomi[3]], [1, 2, 3], 0.5,
			Vector2(0, 0))
	t.eq(CRICCHE.cricca_di(soli, str(nomi[0]), tutti, tutti.size(), 3).size(), 4,
			"quei quattro, da soli, sarebbero una cricca")
	t.eq(CRICCHE.cricca_di(larghi, str(nomi[0]), tutti, tutti.size(),
			3).size(), 0,
			"…ma dentro una piazza di nove non si ritaglia nessun gruppo")


## A PARI MERITO NON SI ELEGGE NESSUNO. Due triangoli identici che passano
## per la stessa persona: l'unica cosa che romperebbe il pareggio sarebbe
## l'ordine dell'anagrafe, e questo gioco non sceglie con quello.
func _a_pari_merito_non_si_elegge(t) -> void:
	var inc: Array = []
	_gruppo(inc, ["Anna", "Bruno", "Carla"], [1, 2, 3], 0.50, Vector2(0, 0))
	_gruppo(inc, ["Anna", "Dino", "Emma"], [1, 2, 3], 0.50, Vector2(40, 0))
	var tutti := _nomi(["Anna", "Bruno", "Carla", "Dino", "Emma", "Fiore",
			"Gigi", "Hana"])
	t.eq(CRICCHE.cricca_di(inc, "Anna", tutti, 8, 3).size(), 0,
			"chi sta al crocevia di due gruppi identici non ne riceve nessuno")
	# …ma per gli altri non c'è nessun pareggio, e la loro cricca esiste
	t.eq("+".join(CRICCHE.cricca_di(inc, "Bruno", tutti, 8, 3)),
			"Anna+Bruno+Carla", "per Bruno non c'è nessun dubbio")
	t.eq("+".join(CRICCHE.cricca_di(inc, "Dino", tutti, 8, 3)),
			"Anna+Dino+Emma", "…né per Dino")


## ⚠️ **LE CRICCHE SI SOVRAPPONGONO**, e non è una svista: si può stare in
## due gruppi. Una partizione avrebbe un COMPLEMENTO, e il complemento di un
## gruppo è l'elenco di chi ne è fuori — il dato che questo sistema si è
## ripromesso di non rendere calcolabile, nemmeno per chi fra due anni
## aggiungerà un consumatore che nessuno ha previsto.
func _le_cricche_si_sovrappongono(t) -> void:
	var inc: Array = []
	_gruppo(inc, ["Anna", "Bruno", "Carla"], [1, 2, 3, 4], 0.50, Vector2(0, 0))
	_gruppo(inc, ["Anna", "Dino", "Emma"], [1, 2, 3], 0.50, Vector2(40, 0))
	var tutti := _nomi(["Anna", "Bruno", "Carla", "Dino", "Emma", "Fiore",
			"Gigi", "Hana"])
	var tutte := CRICCHE.cricche(inc, tutti, 8, 4)
	t.eq(_elenco(tutte), ["Anna+Bruno+Carla", "Anna+Dino+Emma"],
			"il villaggio ha due cricche")
	var in_quante := 0
	for c in tutte:
		if (c as PackedStringArray).has("Anna"):
			in_quante += 1
	t.eq(in_quante, 2, "e Anna sta in tutte e due: nessuna partizione")


## ⚠️ **DUE MACCHIE DI GENTE NON SI CONFONDONO.** Il collaudo dell'unione si
## paga una volta e si annota, perché quattro persone della stessa cricca si
## fanno le stesse identiche domande. Ma la nota va intestata ai NOMI del
## sottogruppo: intestandola alla maschera di bit — che è un numero valido
## solo dentro una macchia — il primo gruppo del villaggio risponderebbe per
## il secondo, e un trio che si vede in tre angoli diversi si ritroverebbe
## la promozione di un trio che non c'entra niente.
func _due_macchie_non_si_confondono(t) -> void:
	var inc: Array = []
	# la prima macchia è una cricca vera: stesso angolo, stessa ora
	_gruppo(inc, ["Anna", "Bruno", "Carla"], [1, 2, 3], 0.50, Vector2(0, 0))
	# la seconda no: tre coppie abituali in tre angoli lontanissimi
	_coppia(inc, "Dino", "Emma", [1, 2, 3], 0.50, Vector2(40, 0))
	_coppia(inc, "Emma", "Fiore", [1, 2, 3], 0.50, Vector2(40, 40))
	_coppia(inc, "Dino", "Fiore", [1, 2, 3], 0.50, Vector2(80, 40))
	var tutti := _nomi(["Anna", "Bruno", "Carla", "Dino", "Emma", "Fiore",
			"Gigi", "Hana"])
	t.eq("+".join(CRICCHE.cricca_di(inc, "Anna", tutti, 8, 3)),
			"Anna+Bruno+Carla", "la prima macchia è una cricca")
	t.eq(CRICCHE.cricca_di(inc, "Dino", tutti, 8, 3).size(), 0,
			"la seconda no, e non eredita la risposta della prima")
	t.eq(_elenco(CRICCHE.cricche(inc, tutti, 8, 3)), ["Anna+Bruno+Carla"],
			"nel villaggio c'è una cricca sola")


## L'ANAGRAFE NON DECIDE. L'uscita è ordinata per nome — cioè per una cosa
## che non vuol dire niente — e non dipende dall'ordine in cui il villaggio
## elenca i suoi abitanti (che cambia a ogni arrivo e a ogni nascita).
func _l_anagrafe_non_decide(t) -> void:
	var inc: Array = []
	_gruppo(inc, ["Anna", "Bruno", "Carla"], [1, 2, 3], 0.50, Vector2(0, 0))
	var dritto := _nomi(["Anna", "Bruno", "Carla", "Dino", "Emma", "Fiore"])
	var storto := _nomi(["Fiore", "Carla", "Dino", "Anna", "Emma", "Bruno"])
	t.eq(_elenco(CRICCHE.cricche(inc, dritto, 6, 3)),
			_elenco(CRICCHE.cricche(inc, storto, 6, 3)),
			"rimescolare l'anagrafe non cambia una virgola")
	# …e l'uscita è ORDINATA PER NOME, cioè per una cosa che non vuol dire
	# niente. Un ordine qualunque altro (per giornate, per data, per anagrafe)
	# sarebbe una classifica resa leggibile.
	_gruppo(inc, ["Dino", "Emma", "Fiore"], [1, 2, 3, 4, 5], 0.50, Vector2(40, 0))
	var due := CRICCHE.cricche(inc, dritto, 6, 5)
	t.eq(due.size(), 2, "il villaggio ha due cricche")
	t.ok("+".join(due[0] as PackedStringArray)
			< "+".join(due[1] as PackedStringArray),
			"e arrivano in ordine di nome, non di quanto sono forti")
	# e un arrivo in mezzo alla giornata non intesta gli incontri a nessun altro
	var con_nuovo := _nomi(["Zeno", "Anna", "Bruno", "Carla", "Dino", "Emma",
			"Fiore"])
	t.eq("+".join(CRICCHE.cricca_di(inc, "Anna", con_nuovo, 7, 3)),
			"Anna+Bruno+Carla", "e un nuovo arrivato non sposta niente")


# ============================================================ il banco vivo
# Qui sotto non si simula niente: il `_chats` VERO del gioco, il `Cricche`
# VERO nel suo gruppo, corpi veri in scena. L'unica cosa che il banco
# sostituisce è la MESSA IN SCENA della chiacchierata (`_run_chat`), che è
# il lavoro che con questa domanda non c'entra — non la decisione.

class FintoGiorno extends Node3D:
	var day := 1
	var time := 0.5


class Corpo extends Node3D:
	var _state := "r_idle"
	var _nascosto := false
	var _in_scena := false
	func is_hidden() -> bool:
		return _nascosto
	func in_scena() -> bool:
		return _in_scena


class ViciniDaBanco extends "res://scenes/npc/Visitors.gd":
	var chiacchiere := 0
	## si sostituisce SOLO la messa in scena: `_chats` e `_segna_incontro`
	## restano quelli del gioco
	func _run_chat(_a: Node3D, _b: Node3D) -> void:
		chiacchiere += 1


## L'anagrafe che `Cricche` cerca in `../Visitors`: tiene LO STESSO array di
## `_residents` del nodo vero (gli Array sono per riferimento), così le due
## metà del banco non possono scollarsi.
class Anagrafe extends Node:
	var _residents: Array[Dictionary] = []


class Banco extends RefCounted:
	var casa: Node3D
	var giorno: FintoGiorno
	var cric: Node
	var vicini: Node
	var anagrafe: Anagrafe
	var corpi: Array = []

	func _init(t, quanti: int) -> void:
		casa = Node3D.new()
		casa.name = "Villaggio"
		t.stage(casa)
		giorno = FintoGiorno.new()
		giorno.name = "DayNight"
		casa.add_child(giorno)
		anagrafe = Anagrafe.new()
		anagrafe.name = "Visitors"
		casa.add_child(anagrafe)
		cric = preload("res://scenes/npc/Cricche.gd").new()
		cric.name = "Cricche"
		casa.add_child(cric)
		vicini = ViciniDaBanco.new()
		# il nodo di Visitors NON entra nell'albero (il suo `_ready` vuole
		# il villaggio intero): il registro glielo si dà in mano, ed è
		# l'unico punto in cui questo banco tocca il cablaggio
		vicini.set("_daynight", giorno)
		vicini.set("_cricche", cric)
		var res: Array[Dictionary] = []
		for i in quanti:
			var c := Corpo.new()
			c.name = "Corpo%d" % i
			casa.add_child(c)
			corpi.append(c)
			res.append({"node": c, "dna": {"name": "Vicino%d" % i},
					"label": "v%d" % i, "next_act": 0.0, "phase": "day"})
		vicini.set("_residents", res)
		anagrafe._residents = res

	func metti(i: int, p: Vector3) -> void:
		(corpi[i] as Node3D).global_position = p

	func scatto() -> void:
		vicini.set("_chat_acc", 0.0)
		vicini.call("_chats", 1.0)

	func righe() -> int:
		return int((cric.get("_incontri") as Array).size())

	func chiudi() -> void:
		vicini.free()


## I QUATTRO CANCELLI: si conta solo dove si va da sé.
func _i_quattro_cancelli(t) -> void:
	var b := Banco.new(t, 2)
	b.metti(0, Vector3(10, 0, 10))
	b.metti(1, Vector3(11, 0, 10))
	b.scatto()
	t.eq(b.righe(), 1, "due vicini a un metro, di giorno, si sono trovati")
	var riga: Dictionary = (b.cric.get("_incontri") as Array)[0]
	t.eq(str(riga["a"]), "Vicino0", "la riga porta i NOMI, non gli indici")
	t.almost(float(riga["x"]), 10.5, "…e il punto di mezzo fra i due corpi", 0.01)
	t.almost(float(riga["o"]), 0.5, "…e l'ora vera del villaggio", 0.001)

	# ancora lo stesso giorno: nessuna seconda riga (il campione è unico)
	b.scatto()
	b.scatto()
	t.eq(b.righe(), 1, "restare lì tutto il pomeriggio non conta di più")

	# un giorno nuovo, e la seconda riga arriva
	b.giorno.day = 2
	b.scatto()
	t.eq(b.righe(), 2, "il giorno dopo, un secondo incontro")

	# 1. il falò: la fase della sera non registra
	b.giorno.day = 3
	b.giorno.time = 0.70
	b.scatto()
	t.eq(b.righe(), 2, "nella fase del falò non si registra niente")
	b.giorno.time = 0.5

	# 2. chi è seduto al fuoco, mai
	b.giorno.day = 4
	(b.corpi[0] as Corpo)._state = "r_fire"
	b.scatto()
	t.eq(b.righe(), 2, "chi è al fuoco non si è avvicinato da sé")
	(b.corpi[0] as Corpo)._state = "r_idle"

	# 3. chi è in mezzo a una scena
	b.giorno.day = 5
	(b.corpi[1] as Corpo)._in_scena = true
	b.scatto()
	t.eq(b.righe(), 2, "chi è in mezzo a una scena ce l'hanno messo")
	(b.corpi[1] as Corpo)._in_scena = false

	# 4. chi ha un lease lungo: l'ha messo lì un sistema
	b.giorno.day = 6
	((b.vicini.get("_residents") as Array)[0] as Dictionary)["next_act"] = 45.0
	b.scatto()
	t.eq(b.righe(), 2, "chi è stato mandato lì da un sistema non ci è andato")
	((b.vicini.get("_residents") as Array)[0] as Dictionary)["next_act"] = 0.0

	# e la controprova: tolte le valvole, lo stesso identico scatto registra
	b.giorno.day = 7
	b.scatto()
	t.eq(b.righe(), 3, "senza nessuna valvola addosso, lo stesso scatto registra")

	# chi è nascosto (dentro casa) non incontra nessuno
	b.giorno.day = 8
	(b.corpi[0] as Corpo)._nascosto = true
	b.scatto()
	t.eq(b.righe(), 3, "chi è dentro casa non si trova con nessuno")
	(b.corpi[0] as Corpo)._nascosto = false

	# e a quattro metri non ci si è trovati
	b.giorno.day = 9
	b.metti(1, Vector3(14, 0, 10))
	b.scatto()
	t.eq(b.righe(), 3, "a quattro metri non ci si è trovati")
	b.chiudi()


## ⚠️ **IL FALÒ NON CONTA, E IL BANCO È QUELLO VERO.** Dodici vicini
## sull'anello di `_posto_al_falo`, che è dove il villaggio li mette ogni
## sera: ne uscirebbero decine di coppie, sempre le stesse, con l'ora
## concentratissima e il posto fisso — cioè clique perfette la cui forma è
## l'ordine in cui la gente ha traslocato.
##
## La controprova sta nello stesso caso: lo stesso identico anello, di
## giorno e senza lo stato del fuoco, registra a man bassa.
func _il_falo_non_conta(t) -> void:
	var b := Banco.new(t, 12)
	for i in 12:
		b.metti(i, b.vicini.call("_posto_al_falo", i))
		(b.corpi[i] as Corpo)._state = "r_fire"
	b.giorno.time = 0.70
	for g in 5:
		b.giorno.day = g + 1
		b.scatto()
	t.eq(b.righe(), 0, "cinque sere attorno al fuoco non scrivono una riga")

	# la controprova: stessi corpi, stessi posti, ma è pomeriggio e ci sono
	# andati da sé
	b.giorno.time = 0.45
	for i2 in 12:
		(b.corpi[i2] as Corpo)._state = "r_idle"
	b.giorno.day = 20
	b.scatto()
	t.ok(b.righe() > 8, "…e di pomeriggio lo stesso anello ne scrive %d"
			% b.righe())
	b.chiudi()


## ⚠️ **IL GIRO DEL GIORNO ASPETTA L'ANAGRAFE.** I nodi del villaggio non
## nascono tutti insieme (il mondo si genera su più fotogrammi): segnare la
## giornata come fatta e poi uscire perché l'anagrafe non c'era ancora vuol
## dire saltare il giro **proprio del giorno in cui il villaggio è nato**, e
## nessuno se ne accorgerebbe mai.
func _il_giro_aspetta_l_anagrafe(t) -> void:
	var casa := Node3D.new()
	casa.name = "Villaggio"
	t.stage(casa)
	var giorno := FintoGiorno.new()
	giorno.name = "DayNight"
	casa.add_child(giorno)
	var cric := preload("res://scenes/npc/Cricche.gd").new()
	cric.name = "Cricche"
	casa.add_child(cric)
	# il registro c'è già (è arrivato dal salvataggio), l'anagrafe no
	var inc: Array = []
	_gruppo(inc, ["Vicino0", "Vicino1", "Vicino2"], [1, 2, 3], 0.5, Vector2(0, 0))
	cric.call("load_extra", {"incontri": inc})
	# ⚠️ E INTANTO GLI INCONTRI SI INCASSANO LO STESSO: per scrivere una riga
	# serve l'OROLOGIO, non l'anagrafe. Pretendere tutto il cablaggio per
	# ogni cosa vuol dire buttare via una giornata di incontri perché un nodo
	# che non c'entra non era ancora nato — in silenzio.
	var quante := int((cric.get("_incontri") as Array).size())
	giorno.day = 3
	cric.call("incontro", "Vicino0", "Vicino3", Vector3(1, 0, 1))
	t.eq(int((cric.get("_incontri") as Array).size()), quante + 1,
			"un incontro si registra anche prima che il villaggio sia in piedi")
	cric.call("giro_del_giorno", 3)
	t.eq(int((cric.call("debug_stato") as Dictionary)["giorno"]), -1,
			"senza anagrafe la giornata NON risulta fatta")
	# e appena il villaggio nasce, lo stesso giorno viene fatto davvero
	var an := Anagrafe.new()
	an.name = "Visitors"
	var res: Array[Dictionary] = []
	for i in 6:
		res.append({"dna": {"name": "Vicino%d" % i}, "label": "v%d" % i})
	an._residents = res
	casa.add_child(an)
	cric.call("giro_del_giorno", 3)
	t.eq("+".join(cric.call("cricca", "Vicino0") as PackedStringArray),
			"Vicino0+Vicino1+Vicino2",
			"…e appena l'anagrafe arriva, il giro si fa lo stesso")


## LA CATENA INTERA, dal `_chats` vero alla cricca: nessun pezzo di questo
## caso è simulato tranne la messa in scena della chiacchierata.
func _la_catena_intera(t) -> void:
	var b := Banco.new(t, 6)
	for g in 3:
		b.giorno.day = g + 1
		# tre vicini in un angolo, tre dall'altra parte del prato
		b.metti(0, Vector3(10.0, 0, 10.0))
		b.metti(1, Vector3(10.8, 0, 10.2))
		b.metti(2, Vector3(10.4, 0, 10.9))
		b.metti(3, Vector3(-40, 0, -40))
		b.metti(4, Vector3(-41, 0, -40))
		b.metti(5, Vector3(-60, 0, 20))
		b.scatto()
	b.cric.call("giro_del_giorno", 3)
	t.eq("+".join(b.cric.call("cricca", "Vicino0") as PackedStringArray),
			"Vicino0+Vicino1+Vicino2",
			"i tre dell'angolo sono una cricca, e nessuno gliel'ha detto")
	t.eq((b.cric.call("cricca", "Vicino3") as PackedStringArray).size(), 0,
			"i due dall'altra parte sono una coppia, non un gruppo")
	t.eq((b.cric.call("cricca", "Vicino5") as PackedStringArray).size(), 0,
			"e chi non incontra nessuno non ha nessuna cricca")
	t.eq((b.cric.call("debug_stato") as Dictionary)["cricche"].size(), 1,
			"in tutto il villaggio c'è una cricca sola")
	b.chiudi()


## IL NODO È IN SCENA NEL LIVELLO VERO. Questa è la sola asserzione debole
## del file — guarda il sorgente, e un `add_child` commentato la
## soddisferebbe lo stesso. La prova forte è viva e sta in
## `tools/misura_cricche.gd`, che apre il MainLevel e stampa «Cricche in
## scena: sì» prima di misurare: senza il nodo, quel banco si ferma subito.
func _il_nodo_e_nel_livello(t) -> void:
	var f := FileAccess.open("res://scenes/levels/MainLevel.gd", FileAccess.READ)
	t.ok(f != null, "MainLevel.gd si legge")
	if f == null:
		return
	var src := f.get_as_text()
	f.close()
	t.ok(src.contains("_spawn_system(\"res://scenes/npc/Cricche.gd\""),
			"il livello mette in scena le Cricche")


## Il registro sopravvive al salvataggio, e le cricche NO: sono derivate, e
## ricalcolarle costa meno che tenerle in ordine. (Il giorno torna `float`
## dal JSON: `profilo` lo legge con `int()`, o la finestra si sposta tutta.)
func _il_registro_sopravvive_al_salvataggio(t) -> void:
	var b := Banco.new(t, 2)
	b.metti(0, Vector3(10, 0, 10))
	b.metti(1, Vector3(11, 0, 10))
	for g in 3:
		b.giorno.day = g + 1
		b.scatto()
	var salvato: Dictionary = b.cric.call("save_extra")
	t.eq(int((salvato["incontri"] as Array).size()), 3,
			"il registro va nel salvataggio")
	t.ok(not salvato.has("cricche"), "le cricche no: sono derivate")
	# il giro del JSON, che trasforma gli interi in float
	var testo := JSON.stringify(salvato)
	var tornato: Dictionary = JSON.parse_string(testo)
	var altro := preload("res://scenes/npc/Cricche.gd").new()
	altro.call("load_extra", tornato)
	var inc: Array = altro.get("_incontri")
	t.eq(inc.size(), 3, "…e torna indietro tutto")
	t.ok(CRICCHE.abitudine(inc, "Vicino0", "Vicino1", 3),
			"e dopo il giro dal disco si ritrovano ancora")
	altro.free()
	b.chiudi()
