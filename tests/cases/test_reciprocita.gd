extends RefCounted
## LA RECIPROCITÀ — la prova che il debito è LETTO, non tenuto.
##
## Chi ha ricevuto più di quanto ha dato se ne ricorda, e attraversa il
## villaggio per mettersi accanto a chi si è preso cura di lui. Non c'è
## nessun dato nuovo dietro quella frase: il libro mastro degli affetti è
## DATATO e DIREZIONALE da sempre, e `ASIMMETRIA` esiste apposta perché «un
## rapporto a senso unico si legga storto dai due lati». `squilibrio()` è
## quella storta, letta.
##
## ============================================================
## PERCHÉ QUESTI CASI NON STANNO IN `test_affetti.gd`
## ============================================================
## Quel file dichiara in testa «nessun `randf` da nessuna parte», ed è una
## proprietà che vale: se un giorno ce ne fosse uno nel codice, una di quelle
## prove diventerebbe intermittente e lo direbbe. La metà comportamentale
## della reciprocità invece attraversa `Visitors._recita`, che tira un dado
## per lo scostamento del fianco (`randf_range(-0.9, 0.9)`). Tenerle insieme
## costerebbe quella dichiarazione; tenerle separate costa un file.
##
## ============================================================
## LE DUE COSE CHE QUESTO FILE DEVE IMPEDIRE
## ============================================================
## 1. **CHE IL GIOCO DICA A QUALCUNO CHE NON HA RICAMBIATO.** `squilibrio()`
##    è antisimmetrica: per ogni debitore esiste un creditore con lo stesso
##    numero cambiato di segno, già calcolato, a un `if` di distanza. Il ramo
##    su quel segno — «vado a riscuotere» — è il gioco che accusa qualcuno, e
##    `_non_si_va_a_riscuotere` esiste per renderlo impossibile invece che
##    sconsigliato.
## 2. **CHE IL LIBRO MASTRO COMINCI A SCRIVERSI DA SÉ.** Una lettura che
##    scrive è un quinto scrittore autonomo su `_righe`: sposta `conto()`,
##    quindi `il_piu_caro()`, quindi le soglie di `coppia()`. È la strada
##    aperta e mai percorsa che il sorgente dichiara, e `_la_lettura_non_scrive`
##    è il lucchetto.

const AFF := preload("res://scenes/npc/Affetti.gd")
const VISITOR := preload("res://scenes/npc/Visitor.gd")
const DNA := preload("res://scenes/npc/ChibiDNA.gd")
## per il caso del FIREWALL, nel pacchetto in fondo: le righe di
## co-presenza si leggono e si giudicano con le funzioni pure di casa
const CRICCHE := preload("res://scenes/npc/Cricche.gd")


func run(t) -> void:
	# ---- la parte PURA: entra un elenco di gesti accaduti, esce un numero
	_lo_squilibrio_e_l_ombra_dell_asimmetria(t)
	_un_gesto_ricambiato_non_e_un_debito(t)
	_il_debito_e_fatto_di_gesti_veri(t)
	_il_debito_sbiadisce(t)
	_non_si_va_a_riscuotere(t)
	_il_pareggio_non_elegge_nessuno(t)
	_chi_non_ha_ricevuto_niente_non_e_punito(t)
	_da_ringraziare_dice_lo_STESSO_numero(t)
	# ---- la parte INCAPSULATA: le tre porte che `Visitors` chiamerà
	_i_candidati_sono_un_argomento(t)
	_la_lealta_e_quella_di_chi_legge(t)
	_il_piu_caro_e_una_migrazione_finita(t)
	_le_coppie_di_oggi_sono_gia_pagate(t)
	_la_lettura_non_scrive(t)
	# ---- la parte COMPORTAMENTALE che vive già oggi: il terzo anello, il
	#      degrado, e il libro mastro dentro il villaggio vero
	_il_ripiego_e_quello_di_sempre(t)
	_senza_libro_mastro_il_villaggio_e_quello_di_sempre(t)
	_il_libro_mastro_vive_nel_villaggio(t)
	# ── IL PACCHETTO PER IL CABLATORE: undici casi scritti contro un'API che
	#    al momento della consegna non esisteva ancora. Adesso esiste.
	_il_corpo_va_da_chi_si_e_preso_cura_di_lui(t)
	_la_riconoscenza_viene_prima_dell_abitudine(t)
	_la_preferenza_non_allarga_i_candidati(t)
	_chi_e_in_una_scena_non_viene_disturbato(t)
	_il_grazie_e_uno_al_giorno(t)
	_e_uno_al_giorno_anche_per_chi_lo_riceve(t)
	_la_riconoscenza_non_diventa_un_orbita(t)
	_la_visita_non_puo_fabbricare_un_ritrovo(t)
	_il_pareggio_non_elegge_nessuno_nel_corpo(t)
	_il_debito_non_e_una_classifica_visibile(t)
	_il_referto_conta_i_silenzi(t)


func _riga(a: String, b: String, tipo: String, giorno: int) -> Dictionary:
	return {"a": a, "b": b, "t": tipo, "d": giorno}


# ======================================================================
#  L'ORACOLO, e non è `conto()`
# ======================================================================
#
# ⚠️ SCRITTO A MANO, e la ragione è la stessa per cui `tools/misura_cammino.gd`
# non chiede a `Varchi` se il corpo ha attraversato un muro: `squilibrio()` è
# `conto(a,b) - conto(b,a)`, quindi un oracolo costruito con `conto()`
# chiederebbe al giudice se è d'accordo con sé stesso. Qui la formula è
# DERIVATA a mano, e viene fuori più semplice dell'originale:
#
#   una riga da `altro` verso `io` entra nel primo conto con 1.0 e nel
#   secondo con ASIMMETRIA  ->  contributo  +peso*recenza*(1 - ASIMMETRIA)
#   una riga da `io` verso `altro`, per simmetria  ->  −lo stesso
#
#   squilibrio(io, altro) = (1 - ASIMMETRIA) * Σ (±peso * recenza)
#
# Cioè: **lo squilibrio è il saldo dei gesti, visto attraverso la sola parte
# che i due lati NON leggono uguale.** Le costanti si LEGGONO da `Affetti`
# invece di essere ricopiate: l'indipendenza di un oracolo sta nella formula,
# non nel ricopiare dei numeri che poi divergono in silenzio.
static func _oracolo(righe: Array, io: String, altro: String, oggi: int,
		lealta := 0.5) -> float:
	var mezza_vita := lerpf(AFF.RECENZA_BASE, AFF.RECENZA_LEALE,
			clampf(lealta, 0.0, 1.0))
	var saldo := 0.0
	for r in righe:
		var riga := r as Dictionary
		var peso := float(AFF.GESTI.get(str(riga.get("t", "")), 0.0))
		if is_zero_approx(peso):
			continue
		var da := str(riga.get("a", ""))
		var verso := str(riga.get("b", ""))
		var giorni := maxf(0.0, float(oggi - int(riga.get("d", 0))))
		var recenza: float = pow(0.5, giorni / mezza_vita)
		if da == altro and verso == io:
			saldo += peso * recenza
		elif da == io and verso == altro:
			saldo -= peso * recenza
	return saldo * (1.0 - AFF.ASIMMETRIA)


# ======================================================================
#  LA PARTE PURA
# ======================================================================

## LO SQUILIBRIO È L'OMBRA DELL'ASIMMETRIA, e si misura contro l'oracolo
## indipendente su un libro mastro che ha di tutto — versi misti, date
## sparse, un tipo sconosciuto che deve pesare zero.
##
## ⚠️ E L'ANTISIMMETRIA SI PROVA A `lealta = 1.0`, non solo a 0.5. È il
## vincolo che tiene in piedi tutta la meccanica — «una sola lealtà, quella
## di chi legge» — e a lealtà media `RECENZA_BASE` e `RECENZA_LEALE`
## potrebbero mascherare uno sbilanciamento fra i due rami. Il confronto è
## `==` su double e non `almost`, ed è lecito: in IEEE754 `fl(x−y)` è
## esattamente `−fl(y−x)`, quindi un'antisimmetria vera qui non ha residuo.
func _lo_squilibrio_e_l_ombra_dell_asimmetria(t) -> void:
	var libro := [
		_riga("Cannella", "Prugna", "piatto", 40),
		_riga("Prugna", "Cannella", "chiacchiera", 44),
		_riga("Cannella", "Prugna", "veglia", 46),
		_riga("Prugna", "Cannella", "musica", 41),
		_riga("Nocciola", "Prugna", "coraggio", 30),      # non li riguarda
		_riga("Cannella", "Prugna", "carriola", 45),      # tipo sconosciuto
	]
	for lealta in [0.0, 0.5, 1.0]:
		var mio := AFF.squilibrio(libro, "Prugna", "Cannella", 50, float(lealta))
		var suo := _oracolo(libro, "Prugna", "Cannella", 50, float(lealta))
		t.almost(mio, suo,
				("lo squilibrio è il saldo dei gesti letto attraverso la sola"
				+ " parte che i due non leggono uguale (lealtà %.1f)")
						% [float(lealta)], 1e-12)
	# l'antisimmetria: per ogni debitore c'è un creditore con lo stesso numero
	for lealta2 in [0.0, 0.5, 1.0]:
		var a := AFF.squilibrio(libro, "Prugna", "Cannella", 50, float(lealta2))
		var b := AFF.squilibrio(libro, "Cannella", "Prugna", 50, float(lealta2))
		t.ok(a == -b,
				("squilibrio(a,b) è ESATTAMENTE −squilibrio(b,a) a lealtà %.1f"
				+ " (%.17f contro %.17f): con due lealtà diverse il carattere"
				+ " di UNA persona entrerebbe nel conto di quanto le si deve")
						% [float(lealta2), a, b])
	t.ok(AFF.squilibrio(libro, "Prugna", "Cannella", 50, 0.5) > 0.0,
			"…e in questo libro mastro c'è davvero un debito da leggere")


## UN GESTO RICAMBIATO NON È UN DEBITO, e non serve nessun caso speciale:
## i due contributi si cancellano da soli. Con lo scambio nello stesso
## giorno lo zero è ESATTO — le due righe hanno lo stesso peso e la stessa
## recenza, e il saldo è `peso − peso`.
func _un_gesto_ricambiato_non_e_un_debito(t) -> void:
	var pari := [
		_riga("Cannella", "Prugna", "piatto", 10),
		_riga("Prugna", "Cannella", "piatto", 10),
	]
	t.ok(AFF.squilibrio(pari, "Prugna", "Cannella", 10) == 0.0,
			"due piatti nello stesso giorno si annullano esattamente")
	t.eq(str(AFF.da_ringraziare(pari, "Prugna", ["Cannella"], 10)[0]), "",
			"e a un debito nullo non corrisponde nessun grazie")
	# e nemmeno a qualche giorno di distanza: chi ha ricambiato per ultimo è
	# semmai in credito di un soffio, mai in debito
	var sfasato := [
		_riga("Cannella", "Prugna", "piatto", 10),
		_riga("Prugna", "Cannella", "piatto", 13),
	]
	t.ok(AFF.squilibrio(sfasato, "Prugna", "Cannella", 13) < 0.0,
			"chi ha ricambiato tre giorni dopo non deve più niente")


## LA SOGLIA È IL FILTRO, e questo caso chiude la tabella intera.
##
## `SQUILIBRIO_MIN` è `PESO_VERO * (1 - ASIMMETRIA)`, cioè lo squilibrio che
## produce UNA riga di peso esattamente `PESO_VERO`. Quindi su una riga sola,
## letta il giorno stesso, «è un debito» e «è un gesto vero» sono la STESSA
## domanda — ed è per questo che accanto non serve (e non deve esserci) un
## secondo filtro «solo i gesti veri»: sarebbe una regola gemella che diverge
## in silenzio il giorno che qualcuno tocca `GESTI`.
##
## Si asserisce la BIIMPLICAZIONE su tutte e nove le voci, non su due esempi:
## una voce nuova con un peso in mezzo farebbe arrossire questo caso invece
## di scivolare dentro senza che nessuno ci pensi.
func _il_debito_e_fatto_di_gesti_veri(t) -> void:
	t.almost(AFF.SQUILIBRIO_MIN, AFF.PESO_VERO * (1.0 - AFF.ASIMMETRIA),
			"la soglia del debito è DERIVATA, mai un letterale", 1e-12)
	for tipo in AFF.GESTI:
		var peso := float(AFF.GESTI[tipo])
		var una := [_riga("Cannella", "Prugna", str(tipo), 12)]
		var s := AFF.squilibrio(una, "Prugna", "Cannella", 12)
		var vero := peso >= AFF.PESO_VERO
		t.eq(s >= AFF.SQUILIBRIO_MIN, vero,
				("«%s» (peso %.2f) è un debito se e solo se è un gesto vero"
				+ " — squilibrio %.4f contro soglia %.4f")
						% [str(tipo), peso, s, AFF.SQUILIBRIO_MIN])
	# e l'accumulazione resta onesta: due gesti leggeri a senso unico la
	# passano insieme, che è esattamente quello che dice il sorgente
	var due_musiche := [
		_riga("Cannella", "Prugna", "musica", 12),
		_riga("Cannella", "Prugna", "musica", 12),
	]
	t.ok(AFF.squilibrio(due_musiche, "Prugna", "Cannella", 12) >= AFF.SQUILIBRIO_MIN,
			"due volte «seduti al buio ad ascoltare» e mai una in cambio sono"
			+ " davvero uno squilibrio")


## IL DEBITO SBIADISCE DA SOLO, ed è la seconda chiave della porta: la prima
## è in mano al giocatore (fa dare qualcosa all'altro), la seconda è il tempo.
## Un piatto smette di essere un debito dopo ~26 giorni.
func _il_debito_sbiadisce(t) -> void:
	var una := [_riga("Cannella", "Prugna", "piatto", 0)]
	var oggi := AFF.squilibrio(una, "Prugna", "Cannella", 0)
	var venti := AFF.squilibrio(una, "Prugna", "Cannella", 20)
	var trentacinque := AFF.squilibrio(una, "Prugna", "Cannella", 35)
	t.ok(oggi > venti and venti > trentacinque,
			"lo stesso identico piatto vale sempre meno (%.4f > %.4f > %.4f)"
					% [oggi, venti, trentacinque])
	t.ok(venti >= AFF.SQUILIBRIO_MIN,
			"a venti giorni è ancora un debito (%.4f)" % venti)
	t.ok(trentacinque < AFF.SQUILIBRIO_MIN,
			"a trentacinque non lo è più (%.4f), e nessuno ha dovuto fare"
			% trentacinque + " niente perché smettesse di esserlo")
	t.eq(str(AFF.da_ringraziare(una, "Prugna", ["Cannella"], 35)[0]), "",
			"e allora non c'è più nessun grazie da portare")
	t.eq(str(AFF.da_ringraziare(una, "Prugna", ["Cannella"], 20)[0]), "Cannella",
			"mentre a venti giorni c'era ancora")


## ⚠️ NON SI VA A RISCUOTERE. È il cuore del genere, non un di-più.
##
## Il creditore ha lo stesso identico numero cambiato di segno — è già
## calcolato, sta in una variabile, e un `if` sul suo segno sarebbe il gioco
## che dice a qualcuno che non ha ricambiato. Qui si prova che quel ramo non
## ha un posto dove stare: la soglia è positiva e il massimo parte da zero,
## quindi un negativo non può vincere per costruzione — a qualunque ampiezza.
##
## ⚠️ E SICCOME LE GUARDIE SONO DUE, NESSUNA DELLE DUE DA SOLA FA ARROSSIRE
## QUESTO CASO, ed è il punto invece che un buco: portare il massimo iniziale
## a `-INF` non basta (li ferma la soglia), spegnere la soglia non basta (li
## ferma il massimo). La mutazione che le scavalca tutte e due in una riga è
## anche la sola plausibile — leggere lo squilibrio in VALORE ASSOLUTO, cioè
## «quanto questi due sono sbilanciati» invece di «quanto io ho ricevuto in
## più» — e quella arrossisce. MISURATO: 2 asserzioni.
func _non_si_va_a_riscuotere(t) -> void:
	var tutti := ["Cannella", "Prugna", "Nocciola", "Malva"]
	# Cannella si è presa cura di TUTTI: è il creditore puro. ⚠️ E di ognuno
	# si è presa cura in modo DIVERSO, apposta: con tre crediti identici
	# sarebbe il margine del pareggio a far tacere il grazie, e la mutazione
	# del valore assoluto resterebbe muta perché la ferma un'altra guardia —
	# la trappola in cui un cancello ne copre un altro.
	var libro := [
		_riga("Cannella", "Prugna", "coraggio", 60),
		_riga("Cannella", "Prugna", "consolazione", 55),
		_riga("Cannella", "Prugna", "veglia", 50),
		_riga("Cannella", "Nocciola", "coraggio", 60),
		_riga("Cannella", "Malva", "piatto", 58),
	]
	var suo := AFF.squilibrio(libro, "Cannella", "Prugna", 60)
	t.ok(suo < -1.0,
			"il creditore ha un numero grosso e NEGATIVO sotto mano (%.4f)"
					% suo)
	t.eq(str(AFF.da_ringraziare(libro, "Cannella", tutti, 60)[0]), "",
			"e non lo usa: chi ha dato non deve un grazie a nessuno")
	t.almost(float(AFF.da_ringraziare(libro, "Cannella", tutti, 60)[1]), 0.0,
			"…e nemmeno un numero da mostrare", 1e-12)
	# la controprova, o questo caso non proverebbe niente: dall'altro lato il
	# grazie c'è, e i tre debitori lo devono tutti alla stessa persona
	for debitore in ["Prugna", "Nocciola", "Malva"]:
		t.eq(str(AFF.da_ringraziare(libro, str(debitore), tutti, 60)[0]),
				"Cannella",
				"%s invece un grazie lo deve, e sa a chi" % str(debitore))


## IL PAREGGIO NON ELEGGE NESSUNO — la stessa guardia di `il_piu_caro()`, e
## per la stessa ragione: a pari merito l'unica cosa che romperebbe il
## pareggio sarebbe l'ordine dell'array dei residenti, cioè il gioco che
## sceglie al posto di chi deve il grazie.
##
## I tre gradini si misurano sulla RECENZA, che è la leva più fine che questo
## file ha: due piatti identici a due giorni di distanza stanno dentro il
## margine (rapporto 1,026), a sei giorni lo superano (1,080).
func _il_pareggio_non_elegge_nessuno(t) -> void:
	var tutti := ["Cannella", "Prugna", "Nocciola"]
	var identici := [
		_riga("Cannella", "Prugna", "piatto", 30),
		_riga("Nocciola", "Prugna", "piatto", 30),
	]
	t.eq(str(AFF.da_ringraziare(identici, "Prugna", tutti, 30)[0]), "",
			"due piatti nello stesso giorno: nessuno viene eletto")
	var quasi := [
		_riga("Cannella", "Prugna", "piatto", 30),
		_riga("Nocciola", "Prugna", "piatto", 28),
	]
	t.eq(str(AFF.da_ringraziare(quasi, "Prugna", tutti, 30)[0]), "",
			"e nemmeno a due giorni di distanza: sotto il margine è ancora"
			+ " un pareggio")
	var stacca := [
		_riga("Cannella", "Prugna", "piatto", 30),
		_riga("Nocciola", "Prugna", "piatto", 24),
	]
	t.eq(str(AFF.da_ringraziare(stacca, "Prugna", tutti, 30)[0]), "Cannella",
			"a sei giorni il primo stacca il secondo, e allora si elegge")
	# ⚠️ IL PAREGGIO SI GUARDA FRA I SOLI DEBITI. Due creditori sotto soglia
	# non pareggiano niente, perché nessuno dei due è un creditore: senza
	# questo, una chiacchiera qualsiasi in giro per il villaggio spegnerebbe
	# un grazie vero.
	var con_rumore := [
		_riga("Cannella", "Prugna", "coraggio", 30),
		_riga("Nocciola", "Prugna", "chiacchiera", 30),
	]
	t.eq(str(AFF.da_ringraziare(con_rumore, "Prugna", tutti, 30)[0]), "Cannella",
			"una chiacchiera non è un secondo classificato: non è un debito")


## CHI NON HA RICEVUTO NIENTE NON È PUNITO, e non c'è nessun ramo che si
## accenda sul vuoto: la risposta è la stessa che dà un villaggio appena
## nato, cioè il silenzio.
func _chi_non_ha_ricevuto_niente_non_e_punito(t) -> void:
	var vuoto: Array = []
	t.eq(str(AFF.da_ringraziare(vuoto, "Prugna", ["Cannella", "Malva"], 12)[0]),
			"", "libro mastro vuoto: nessun grazie, e nessuna penale")
	# e nemmeno in mezzo agli affari degli altri
	var altrui := [
		_riga("Cannella", "Nocciola", "coraggio", 10),
		_riga("Malva", "Nocciola", "nascita", 11),
		_riga("Nocciola", "Cannella", "veglia", 12),
	]
	t.eq(str(AFF.da_ringraziare(altrui, "Prugna", ["Cannella", "Malva",
			"Nocciola"], 12)[0]), "",
			"chi non compare in nessuna riga resta esattamente dov'era")
	t.almost(AFF.squilibrio(altrui, "Prugna", "Cannella", 12), 0.0,
			"il suo squilibrio verso chiunque è zero", 1e-12)


## L'ANTI-GEMELLO. `da_ringraziare` deve dire sul vincitore LO STESSO numero
## che dice `squilibrio` — `==` su double, non `almost`.
##
## Serve il giorno che qualcuno, per «ottimizzare», riscrivesse il conto
## dentro `da_ringraziare` invece di chiamare `squilibrio`: da lì in poi le
## due colonne divergerebbero in silenzio, e il gioco sceglierebbe la meta
## con un numero e la mostrerebbe (o la misurerebbe) con un altro.
func _da_ringraziare_dice_lo_STESSO_numero(t) -> void:
	var libro := [
		_riga("Cannella", "Prugna", "consolazione", 20),
		_riga("Prugna", "Cannella", "musica", 22),
		_riga("Malva", "Prugna", "piatto", 21),
		_riga("Prugna", "Malva", "chiacchiera", 23),
	]
	var tutti := ["Cannella", "Malva", "Nocciola"]
	for lealta in [0.0, 0.5, 1.0]:
		var esito := AFF.da_ringraziare(libro, "Prugna", tutti, 25, float(lealta))
		var chi := str(esito[0])
		t.ok(chi != "", "a lealtà %.1f un creditore c'è" % [float(lealta)])
		if chi == "":
			continue
		var diretto := AFF.squilibrio(libro, "Prugna", chi, 25, float(lealta))
		t.ok(float(esito[1]) == diretto,
				("il numero eletto è ESATTAMENTE lo squilibrio verso %s"
				+ " (%.17f contro %.17f)") % [chi, float(esito[1]), diretto])


# ======================================================================
#  LE TRE PORTE, incapsulate
# ======================================================================

## ⚠️ I CANDIDATI SONO UN ARGOMENTO, e `fra` non ha un valore di serie.
##
## `_tutti()` sta venti righe più giù nel sorgente, e la tentazione è ovvia.
## Ma `_tutti()` comprende chi dorme, chi è nascosto e chi è dentro una
## scena: usarlo come ripiego trasformerebbe «non c'è nessuno in giro» in
## «non ti ho detto chi è in giro», e manderebbe un corpo verso una casa
## chiusa. Chi chiama sa chi è in piedi; questo file no.
func _i_candidati_sono_un_argomento(t) -> void:
	var reg = _registro(t, [
		_riga("Cannella", "Prugna", "coraggio", 78),
	])
	t.eq(reg.chi_ringraziare("Prugna", ["Cannella"]), "Cannella",
			"col creditore fra i candidati il grazie si porta")
	t.eq(reg.chi_ringraziare("Prugna", []), "",
			"con NESSUNO in giro non si va da nessuna parte — e non si va"
			+ " comunque dal creditore, che è la scorciatoia che manderebbe"
			+ " un corpo verso una casa chiusa")
	t.eq(reg.chi_ringraziare("Prugna", ["Malva", "Nocciola"]), "",
			"e se in giro c'è qualcun altro, il grazie aspetta: la lista è"
			+ " la lista")
	t.eq(reg.chi_ringraziare("", ["Cannella"]), "",
			"senza un nome non c'è nemmeno la domanda")


## ⚠️ UNA SOLA LEALTÀ, E DEV'ESSERE QUELLA DI CHI LEGGE.
##
## È il vincolo che tiene in piedi l'antisimmetria — provata qui sopra sul
## puro — nel momento in cui il conto passa dalla porta incapsulata:
## `chi_ringraziare` deve chiedere `_lealta_di(nome)`, cioè la lealtà del
## DEBITORE. Con quella del creditore, il carattere di UNA persona entrerebbe
## nel conto di quanto le si deve — chi è leale «meriterebbe» più
## riconoscenza; con una costante, il carattere sparirebbe del tutto.
##
## Il discriminatore è la MEZZA VITA, che è la sola cosa che la lealtà tocca
## (`lerpf(RECENZA_BASE, RECENZA_LEALE, lealtà)`). Un piatto a senso unico
## vale 0,315 e la soglia è 0,225, quindi smette di essere un debito quando la
## recenza scende sotto 0,7143 — cioè dopo 0,4854 mezze vite: **17,5 giorni**
## per chi non ricorda, **26,2** per la media, **34,9** per chi non dimentica.
## La fixture si siede a TRENTA giorni, in mezzo alle ultime due, con un
## margine del 5% da tutte e due le parti.
##
## ⚠️ E LO STESSO NUMERO FA DA GUARDIA AL GIORNO: cinque giorni di scarto su
## quello che la porta legge fanno cadere una delle due metà. Nel resto del
## file `_giorno()` è dettato e nessuno lo guarda; qui è il fulcro.
func _la_lealta_e_quella_di_chi_legge(t) -> void:
	# il piatto è del giorno 50, e il registro legge il giorno 80: trenta
	var libro := [_riga("Cannella", "Prugna", "piatto", 50)]
	# PRIMA si prova che la fixture DISCRIMINA, sul puro, dove non c'è
	# nessuna porta di mezzo: senza questa metà, le due dopo potrebbero
	# essere verdi soltanto perché il libro mastro tace comunque.
	var mai := AFF.squilibrio(libro, "Prugna", "Cannella", 80, 0.0)
	var media := AFF.squilibrio(libro, "Prugna", "Cannella", 80, 0.5)
	var sempre := AFF.squilibrio(libro, "Prugna", "Cannella", 80, 1.0)
	t.ok(mai < AFF.SQUILIBRIO_MIN,
			"per chi non ricorda, a trenta giorni non è più un debito (%.4f)"
					% mai)
	t.ok(media < AFF.SQUILIBRIO_MIN,
			"e nemmeno per la media (%.4f): è il valore che uscirebbe da una"
					% media + " lealtà scritta a mano")
	t.ok(sempre >= AFF.SQUILIBRIO_MIN,
			"per chi non dimentica invece sì (%.4f)" % sempre)
	# …e adesso la porta. Il debitore è leale, il creditore no.
	var leale = _registro(t, libro, {"Prugna": 1.0, "Cannella": 0.0})
	t.eq(leale.chi_ringraziare("Prugna", ["Cannella"]), "Cannella",
			"chi non dimentica deve ancora il suo grazie — e lo deve con la"
			+ " PROPRIA memoria, non con quella di chi gliel'ha dato")
	# la controprova, coi due caratteri scambiati: adesso è il creditore a
	# non dimenticare, e non deve cambiare niente
	var smemorato = _registro(t, libro, {"Prugna": 0.0, "Cannella": 1.0})
	t.eq(smemorato.chi_ringraziare("Prugna", ["Cannella"]), "",
			"e chi non ricorda non deve più niente, per quanto bene se lo"
			+ " ricordi l'altro")


## `chi_e_il_piu_caro` è una MIGRAZIONE FINITA, non una meccanica nuova:
## sostituisce `VillagerBrain.migliore_amico()`, che leggeva `affinita` — un
## contatore di prossimità in circolo chiuso (si sale stando vicini, e si sta
## vicini perché si è saliti). Alla stessa domanda il libro mastro risponde
## con le cose che sono successe davanti al giocatore.
##
## ⚠️ E DEVE POTER TACERE. Il degrado va dove va sempre: libro mastro muto,
## si risponde "", e chi chiama ripiega esattamente come ha sempre fatto.
func _il_piu_caro_e_una_migrazione_finita(t) -> void:
	var muto = _registro(t, [])
	t.eq(muto.chi_e_il_piu_caro("Prugna", ["Cannella", "Malva"]), "",
			"libro mastro vuoto: nessun più caro, e chi chiede ripiega")
	var reg = _registro(t, [
		_riga("Cannella", "Prugna", "nascita", 70),
		_riga("Prugna", "Cannella", "consolazione", 72),
		_riga("Malva", "Prugna", "chiacchiera", 79),
	])
	t.eq(reg.chi_e_il_piu_caro("Prugna", ["Cannella", "Malva"]), "Cannella",
			"chi ha fatto una vita con te conta più di chi ti passa accanto")
	t.eq(reg.chi_e_il_piu_caro("Prugna", ["Malva"]), "Malva",
			"…ma la lista resta la lista, anche qui")
	# a pari merito non si elegge nessuno: è la stessa guardia del grazie
	var pari = _registro(t, [
		_riga("Cannella", "Prugna", "piatto", 79),
		_riga("Malva", "Prugna", "piatto", 79),
	])
	t.eq(pari.chi_e_il_piu_caro("Prugna", ["Cannella", "Malva"]), "",
			"e a pari merito il gioco non sceglie al posto suo")


## LE COPPIE DI OGGI SONO GIÀ PAGATE — è la fotografia che `giro_del_giorno()`
## ha fatto all'ultimo cambio di giorno, non un ricalcolo.
##
## ⚠️ La differenza non è di stile: `le_coppie()` gira una volta per giornata
## di gioco apposta, e il giorno che il libro mastro si è riempito è costata
## **55 secondi**. Un lettore che se la rifacesse per conto proprio pagherebbe
## quel prezzo dentro la sera del falò.
##
## ⚠️ E TORNA UNA COPIA: `save_extra()` restituisce `_coppie_ieri` per
## riferimento, quindi un consumatore che mutasse l'array riscriverebbe lo
## stato persistito degli affetti senza passare da nessuna porta.
## ⚠️ E LE ASSERZIONI NON INDICIZZANO NIENTE. Un caso che accede a `lette[0]`
## dopo essere diventato rosso va fuori dall'array, cioè si INTERROMPE — e le
## asserzioni che vengono dopo (quelle sulla copia) non girano più, lasciando
## il verde su un buco. È successo alla prima stesura, con la mutazione che
## rimette il ricalcolo: una rossa invece di tre. Si confronta il testo intero.
func _le_coppie_di_oggi_sono_gia_pagate(t) -> void:
	# due nomi che NESSUN ricalcolo potrebbe produrre: il libro mastro è vuoto
	var reg = _registro(t, [])
	reg.set("_coppie_ieri", [["Cannella", "Prugna"]])
	var lette: Array = reg.coppie_di_oggi()
	t.eq(JSON.stringify(lette), '[["Cannella","Prugna"]]',
			"si legge la fotografia di ieri, intera, e non si rifà la"
			+ " scansione (che su un libro mastro vuoto non produrrebbe"
			+ " nessuna coppia)")
	# la mutazione del chiamante non deve arrivare allo stato persistito
	lette.append(["Malva", "Loto"])
	for c in lette:
		(c as Array)[0] = "Nocciola"
	t.eq(JSON.stringify(reg.coppie_di_oggi()), '[["Cannella","Prugna"]]',
			"chi legge non può allungare l'elenco vero, e nemmeno riscrivere"
			+ " una coppia dentro di esso")
	t.eq(JSON.stringify(reg.save_extra()["coppie_ieri"]),
			'[["Cannella","Prugna"]]',
			"…quindi il salvataggio non se ne accorge")


## ⚠️ LA LETTURA NON SCRIVE, ed è il lucchetto sulla strada aperta.
##
## Il debito si estingue in un modo solo — l'altro riceve qualcosa a sua volta
## — più il tempo che passa. La variante elegante (far scrivere alla visita
## una riga `fianco` vera, che estinguerebbe il debito e regalerebbe il
## raffreddamento) è stata esaminata e SCARTATA nel sorgente: è un quinto
## scrittore autonomo sul libro mastro, sposta `conto()`, quindi
## `il_piu_caro()`, quindi le soglie di `coppia()`. Va fatta con la misura in
## mano, non di contrabbando — e questo caso è il posto in cui il contrabbando
## si vede.
func _la_lettura_non_scrive(t) -> void:
	var libro := [
		_riga("Cannella", "Prugna", "coraggio", 74),
		_riga("Prugna", "Malva", "piatto", 76),
		_riga("Malva", "Cannella", "veglia", 71),
	]
	var reg = _registro(t, libro)
	var prima := JSON.stringify(reg.get("_righe"))
	var chiavi_prima := (reg.save_extra() as Dictionary).keys()
	chiavi_prima.sort()
	for i in 3:
		reg.chi_ringraziare("Prugna", ["Cannella", "Malva"])
		reg.chi_e_il_piu_caro("Prugna", ["Cannella", "Malva"])
		reg.quanto("Prugna", "Cannella")
		reg.coppie_di_oggi()
	t.eq(JSON.stringify(reg.get("_righe")), prima,
			"tre giri di letture, e il libro mastro è byte per byte quello"
			+ " di prima")
	var chiavi_dopo := (reg.save_extra() as Dictionary).keys()
	chiavi_dopo.sort()
	t.eq(str(chiavi_dopo), str(chiavi_prima),
			"e il salvataggio ha le stesse identiche chiavi")
	t.eq(str(chiavi_dopo), str(["affetti", "coppie_ieri", "ferite"]),
			"…che sono ancora quelle tre, e non una in più")


## Il libro mastro VERO, col solo `_ready` scavalcato e una sola sorgente di
## dati dettata: le righe. `conto()`, `squilibrio()`, la soglia e il margine
## restano quelli del gioco — è quello che si sta provando.
##
## ⚠️ Non chiama `add_to_group("affetti")`: un registro di banco nel gruppo
## verrebbe trovato dai casi comportamentali di questo stesso file, che
## devono misurare un villaggio SENZA libro mastro.
class RegistroAffetti extends "res://scenes/npc/Affetti.gd":
	func _ready() -> void:
		set_process(false)

	func _process(_d: float) -> void:
		pass

	## `_cabla` andrebbe a cercare `../Visitors` e `../DayNight` nell'albero:
	## senza villaggio non li troverebbe e girerebbe a vuoto a ogni chiamata.
	func _cabla() -> void:
		pass

	## Il giorno si DÀ. Con `_daynight` nullo il vero risponderebbe 1, e un
	## libro mastro datato al giorno 70 si leggerebbe tutto «nel futuro»:
	## `maxf(0, oggi - d)` salva dal negativo, ma la recenza varrebbe 1.0 per
	## ogni riga e le prove sullo sbiadimento misurerebbero un altro gioco.
	func _giorno() -> int:
		return 80

	## ⚠️ CHI ESISTE È UN DATO, e si detta come `FintoBuild` detta dove sono
	## le panchine. Senza `_visitors` il vero risponderebbe una lista VUOTA, e
	## allora la mutazione che conta — «se `fra` è vuoto ripiega su `_tutti()`»
	## — resterebbe muta per il motivo sbagliato: non perché la guardia regge,
	## ma perché in banco il ripiego non ha nessuno da restituire.
	func _tutti() -> Array:
		return ["Cannella", "Prugna", "Malva", "Nocciola"]

	## ⚠️ E ANCHE LE LEALTÀ SI DÀNNO. Vengono da `Animo`, che qui non c'è, e
	## sono un DATO come chi esiste e come che giorno è — non una decisione:
	## quello che si prova è CHI di loro la porta va a chiedere. Vuoto vuol
	## dire «la media», cioè esattamente quello che risponde il vero quando il
	## villaggio non c'è, e per tutti gli altri casi di questo file non cambia
	## un bit.
	var lealta_dettata := {}

	func _lealta_di(nome: String) -> float:
		return float(lealta_dettata.get(nome, 0.5))


func _registro(t, righe: Array, lealta := {}):
	var reg = RegistroAffetti.new()
	t.stage(reg)
	reg.set("_righe", righe.duplicate(true))
	reg.set("lealta_dettata", lealta.duplicate())
	return reg


# ======================================================================
#  IL TERZO ANELLO — e questo vive già oggi
# ======================================================================

class FintoGiorno extends Node3D:
	var day := 30
	var time := 0.5
	## `_ensure_ecs` lo legge per derivare il ritmo della memoria: senza,
	## l'accesso esplode e la funzione si INTERROMPE a metà — cioè il caso si
	## ferma lì e la suite resta verde.
	var cycle_seconds := 240.0


## Il registro dei vicini VERO, col solo `_ready` scavalcato: il suo vuole
## `%Player` e `../BuildSystem`, cioè il villaggio intero. Tutto quello che
## decide — `_recita`, la cascata dei candidati, il ripiego — resta quello
## del gioco.
class Registro extends "res://scenes/npc/Visitors.gd":
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
		add_to_group("visitors")

	func _process(_d: float) -> void:
		pass


## ⚠️ **IL RIPIEGO DI SEMPRE NON SI TOCCA MAI**, ed è la ragione per cui
## questo caso atterra PRIMA del cablaggio della riconoscenza.
##
## `RIPIEGO := "quattro_chiacchiere"` è dove finisce chiunque cambi idea: è la
## strada più battuta del motore, non un ramo raro. Oggi la sua ultima parola
## è «il PRIMO residente valido nell'ordine di `_residents`, saltando sé
## stesso, i null, gli invalidi e i nascosti» — non è un dado, non salta chi
## dorme, non salta chi è dentro una scena.
##
## Chi riscriverà quel ramo per infilarci la riconoscenza lo riscriverà tutto,
## e la tentazione di «aggiustare» il ripiego mentre ci si passa è enorme.
## Ma è il ripiego che rende la reciprocità puramente ADDITIVA: chi ha il
## libro mastro vuoto — che è tutto il villaggio, quasi sempre — deve
## ricevere ESATTAMENTE quello che riceveva prima. Toccarlo trasformerebbe
## un'assenza in una penalità, che è il modo in cui un sistema acceso su un
## fatto positivo comincia ad accendersi sul vuoto.
##
## E siccome qui non c'è nessun `Affetti` nell'albero, questo caso è anche la
## prova del degrado: **senza libro mastro il villaggio è quello di sempre.**
func _il_ripiego_e_quello_di_sempre(t) -> void:
	var v := _villaggio(t, 3)
	var vis = v["vis"]
	var corpi: Array = v["corpi"]
	var r: Dictionary = (vis.get("_residents") as Array)[0]
	var io := corpi[0] as Node3D
	vis._recita(r, io, vis._ensure_brain(r), "quattro_chiacchiere", "day")
	t.eq(str(io.get("_state")), "walk", "il corpo si mette in cammino")
	t.eq(str(io.get("_next_state")), "r_sniff",
			"e alla fine del viaggio si annusa: è lo stato del ripiego, ed è"
			+ " lo stesso che dovrà avere la visita grata")
	_va_da(t, io, corpi[1], "il primo residente valido dell'elenco")
	t.ok(io.call("meta_cammino").distance_to(
			(corpi[2] as Node3D).global_position) > 10.0,
			"…e non dal secondo, che è lì e sarebbe valido uguale")
	# CHI NON C'È NON È UN CANDIDATO: il ripiego salta i nascosti, e allora
	# tocca a quello dopo. È l'unica valvola che il terzo anello ha.
	(corpi[1] as Node3D).set("_hidden", true)
	var io2 := corpi[0] as Node3D
	io2.set("_state", "r_idle")
	vis._recita(r, io2, vis._ensure_brain(r), "quattro_chiacchiere", "day")
	_va_da(t, io2, corpi[2], "il primo VALIDO, saltando chi è dentro casa")


## Il fianco è `meta.global_position + Vector3(randf_range(-0.9, 0.9), 0, 0.9)`:
## c'è un dado dentro, quindi si asserisce sulla DISTANZA e non sul punto —
## fra 0,90 m (dado a zero) e 1,2728 (dado al fondo della corsa).
##
## ⚠️ E quella distanza è SOTTO `Visitors.VICINI` (1,9 m) per costruzione: è
## la riga che fabbrica la co-presenza, ed è la ragione per cui la visita
## grata ha bisogno di un raffreddamento (vedi `Affetti.GIORNI_RIPETIZIONE`).
func _va_da(t, io: Node3D, meta: Node3D, perche: String) -> void:
	var d: float = io.call("meta_cammino").distance_to(meta.global_position)
	t.ok(d >= 0.89 and d <= 1.28,
			"si ferma a un passo da %s (%.3f m)" % [perche, d])


## Il MONDO, non il comportamento: dice dove sono i pezzi e se ci si arriva,
## che sono dati.
## ⚠️ `Node3D` e non `Node`: `Visitors._build` è TIPIZZATO, e un `set()` col
## tipo sbagliato **non assegna e non dice niente** — il campo resta `null` e
## ogni chiamata al mondo esplode a runtime, cioè interrompe il caso lasciando
## la suite verde.
class FintoBuild extends Node3D:
	func get_placed_by_name(_nome: String) -> Array:
		return []

	func raggiungibile(_a: Vector2i, _b: Vector2i) -> bool:
		return true


func _corpo(t, seme: int) -> Node3D:
	var v = VISITOR.new()
	v.species = "chibi"
	# ⚠️ `do_routine` ESCE IN SILENZIO se il modo non è "resident": senza
	# questa riga il corpo non si muove e non lo dice nessuno.
	v.mode = "resident"
	v.dna = DNA.generate(seme)
	t.stage(v)
	v.set_process(false)
	return v


## ⚠️ E SI SGOMBRA ANCHE IL GRUPPO «affetti», non solo «visitors». I nodi
## messi in scena da un caso restano vivi fino al frame dopo, cioè fino alla
## FINE DI TUTTO IL FILE: un `Affetti` vero staged dal caso di prima sarebbe
## ancora nel gruppo mentre il caso del degrado misura un villaggio che deve
## essere senza libro mastro — e quel caso passerebbe, o fallirebbe, per
## l'ordine in cui `run()` chiama le funzioni invece che per il codice.
func _villaggio(t, quanti: int) -> Dictionary:
	for vecchio in t.tree().get_nodes_in_group("visitors"):
		(vecchio as Node).remove_from_group("visitors")
	for vecchio2 in t.tree().get_nodes_in_group("affetti"):
		(vecchio2 as Node).remove_from_group("affetti")
	var casa := Node3D.new()
	casa.name = "Villaggio"
	t.stage(casa)
	var giorno := FintoGiorno.new()
	giorno.name = "DayNight"
	casa.add_child(giorno)
	var vis = Registro.new()
	vis.name = "Visitors"
	casa.add_child(vis)
	var build = FintoBuild.new()
	build.name = "BuildSystem"
	casa.add_child(build)
	vis.set("_build", build)
	vis.set("_daynight", giorno)
	var corpi: Array = []
	for i in quanti:
		var c := _corpo(t, 4242 + i * 97)
		c.global_position = Vector3(float(i) * 30.0, 0, 0)
		c.dna["name"] = "Vicino%d" % i
		(vis.get("_residents") as Array).append({
			"node": c, "label": "V%d" % i, "dna": c.dna,
			"cell": Vector2i(i * 30, 0), "species": "chibi",
			"next_act": 0.0, "phase": "day"})
		corpi.append(c)
	return {"casa": casa, "vis": vis, "corpi": corpi, "giorno": giorno}


## SENZA LIBRO MASTRO IL VILLAGGIO È QUELLO DI SEMPRE, ed è il contratto che
## deve restare vero DOPO il cablaggio, non solo prima.
##
## `Affetti` è un figlio RUNTIME di `MainLevel`: nel bosco, nel Prologo, nel
## diorama del titolo e in mezza suite quel nodo non c'è. Il degrado va dove
## va sempre in questo progetto — verso quello che si faceva ieri — e qui si
## scrive una volta per tutte: **niente libro mastro, niente riconoscenza, e
## il ripiego decide come ha sempre deciso.**
##
## ⚠️ E LA PREMESSA SI ASSERISCE, invece di darla per buona. Un caso che
## misura un villaggio senza `Affetti` e non controlla che `Affetti` non ci
## sia è verde tanto per il degrado quanto per un cablaggio spento: dichiara
## il MOTIVO, che è la lezione già pagata dal banco delle cricche.
func _senza_libro_mastro_il_villaggio_e_quello_di_sempre(t) -> void:
	var v := _villaggio(t, 3)
	var vis = v["vis"]
	var corpi: Array = v["corpi"]
	t.ok(t.tree().get_nodes_in_group("affetti").is_empty(),
			"la premessa: in questo villaggio non c'è nessun libro mastro")
	var r: Dictionary = (vis.get("_residents") as Array)[0]
	var io := corpi[0] as Node3D
	vis._recita(r, io, vis._ensure_brain(r), "quattro_chiacchiere", "day")
	t.eq(str(io.get("_next_state")), "r_sniff",
			"il corpo va ad annusare, come ha sempre fatto")
	_va_da(t, io, corpi[1], "il primo residente valido dell'elenco")


## IL LIBRO MASTRO DENTRO IL VILLAGGIO VERO — e questa è la fixture che il
## cablaggio userà, provata PRIMA che il cablaggio esista.
##
## `RegistroAffetti` detta tre cose (il giorno, chi esiste, le lealtà) perché
## le prove pure non vogliono mezzo villaggio addosso. Ma il giorno che
## `Visitors` chiamerà `chi_ringraziare` per davvero, quelle tre cose
## arriveranno dall'albero — e se `_cabla()` non trovasse i suoi due fratelli
## `_giorno()` risponderebbe **1** e `_lealta_di` **0,5**, in silenzio: un
## libro mastro datato al giorno 50 si leggerebbe tutto «nel futuro», la
## recenza varrebbe 1,0 per ogni riga, e un banco costruito male misurerebbe
## un villaggio che non esiste.
##
## Perciò qui c'è un `Affetti` VERO, coi nomi giusti (`../Visitors`,
## `../DayNight`), e si prova che il giorno arriva davvero dal cielo: spostare
## l'orologio in avanti fa sbiadire il debito. Se il cablaggio non ci fosse,
## questa sarebbe una fixture che nessuno ha mai acceso.
##
## ⚠️ E QUI `_tutti()` È QUELLO VERO. Nel registro di banco è dettato, quindi
## la mutazione «se `fra` è vuoto ripiega su `_tutti()`» arrossisce per il
## motivo giusto solo se il ripiego avrebbe davvero qualcuno da restituire:
## in questo villaggio ce l'ha, ed è l'unico posto del file in cui quella
## guardia è provata contro l'anagrafe vera.
func _il_libro_mastro_vive_nel_villaggio(t) -> void:
	# Vicino0 ci è andato per primo, per Vicino1: trenta giorni fa
	var v := _villaggio_con_libro(t, 3, [
		_riga("Vicino0", "Vicino1", "coraggio", 50),
	], 80)
	var aff = v["aff"]
	t.ok(bool(aff.get("_cablato")),
			"il libro mastro ha trovato i suoi due fratelli nell'albero")
	t.eq(int(aff.call("_giorno")), 80,
			"…e il giorno gli arriva dal cielo, non da un valore di serie")
	t.eq(aff.chi_ringraziare("Vicino1", ["Vicino0"]), "Vicino0",
			"chi ci è andato per primo per te è ancora lì da ringraziare")
	t.eq(aff.chi_ringraziare("Vicino0", ["Vicino1"]), "",
			"e chi ci è andato non deve niente a nessuno")
	# `fra` resta un argomento anche quando l'anagrafe vera avrebbe di che
	# rispondere: è la guardia contro il ripiego su `_tutti()`
	t.ok((aff.call("_tutti") as Array).has("Vicino0"),
			"la premessa: l'anagrafe vera qui ha davvero dei nomi da dare")
	t.eq(aff.chi_ringraziare("Vicino1", []), "",
			"…e con nessuno in giro non si va comunque dal creditore")
	# l'orologio: portato avanti, il debito sbiadisce da sé — è la prova che
	# `_giorno()` è vivo e non una costante
	(v["giorno"] as Node3D).set("day", 200)
	t.eq(aff.chi_ringraziare("Vicino1", ["Vicino0"]), "",
			"e centocinquanta giorni dopo non c'è più niente da ringraziare:"
			+ " il tempo è la seconda chiave di questa porta")


## Il villaggio di sopra, più un `Affetti` VERO come terzo fratello. Il libro
## mastro si detta (è un dato); tutto il resto — il cablaggio, il giorno, la
## lealtà, la soglia, il margine — resta quello del gioco.
##
## ⚠️ L'ORDINE DEI FIGLI CONTA: `Affetti._ready` chiama `_cabla()` nell'istante
## in cui entra nell'albero, e `casa` è già in scena. Se entrasse per primo non
## troverebbe nessuno — `_cablato` resterebbe falso, e siccome `_cabla()` si
## riprova a ogni chiamata la cosa si aggiusterebbe da sé, ma l'asserzione che
## la sorveglia perderebbe il suo senso.
func _villaggio_con_libro(t, quanti: int, righe: Array,
		giorno := 80) -> Dictionary:
	var v := _villaggio(t, quanti)
	(v["giorno"] as Node3D).set("day", giorno)
	var aff = AFF.new()
	aff.name = "Affetti"
	(v["casa"] as Node3D).add_child(aff)
	aff.set("_righe", righe.duplicate(true))
	v["aff"] = aff
	return v


# ======================================================================
#  IL PACCHETTO PER IL CABLATORE — undici casi già scritti, MAI ESEGUITI
# ======================================================================
#
# ⚠️ LEGGERE PRIMA DI TOCCARLI. Questi undici casi sorvegliano il CABLAGGIO
# della riconoscenza, che vive in `Visitors.gd` — un file che non appartiene
# a chi ha scritto questo. Sono qui, e non in un documento, perché il
# protocollo del pacchetto dice che il proprietario **innesta, non
# riscrive**: un caso ricopiato a mano da un referto è un caso in cui la
# ragione scritta nel commento smette di corrispondere al codice.
#
# **NON SONO CHIAMATI DA `run()`, ED È VOLUTO.** Alla fine della fase 0 la
# suite dev'essere verde e nel gioco non dev'essere cambiato niente: le
# query pure di `Affetti` non hanno ancora un lettore. Chiamarli adesso
# vorrebbe dire quindici rossi su un lavoro che sta andando come deve.
#
# **CHI CABLA AGGIUNGE QUESTE UNDICI RIGHE IN `run()`**, in coda, e nello
# STESSO COMMIT del cablaggio (un cablaggio senza guardia è la forma di
# guasto che questo progetto ha già pagato sei volte):
#
#	_il_corpo_va_da_chi_si_e_preso_cura_di_lui(t)
#	_la_riconoscenza_viene_prima_dell_abitudine(t)
#	_la_preferenza_non_allarga_i_candidati(t)
#	_chi_e_in_una_scena_non_viene_disturbato(t)
#	_il_grazie_e_uno_al_giorno(t)
#	_e_uno_al_giorno_anche_per_chi_lo_riceve(t)
#	_la_riconoscenza_non_diventa_un_orbita(t)
#	_la_visita_non_puo_fabbricare_un_ritrovo(t)
#	_il_pareggio_non_elegge_nessuno_nel_corpo(t)
#	_il_debito_non_e_una_classifica_visibile(t)
#	_il_referto_conta_i_silenzi(t)
#
# ⚠️ E OGNUNO VA FATTO DIVENTARE ROSSO PRIMA DI DICHIARARLO VERDE. Sono
# scritti contro un'API che ancora non esiste: nessuno li ha mai eseguiti, e
# un caso mai eseguito è una promessa, non una guardia. In particolare la
# MUTAZIONE DESIGNATA di questa meccanica — togliere il raffreddamento della
# coppia da `_riconoscenza`, tornando al solo gettone giornaliero — deve far
# arrossire `_la_riconoscenza_non_diventa_un_orbita` **e**
# `_la_visita_non_puo_fabbricare_un_ritrovo`. Se ne arrossisce una sola, il
# firewall verso il falò e l'eredità non è sorvegliato.
#
# L'API contro cui sono scritti è quella consegnata al cablatore:
#
#	var _grazie_oggi := {}    # NOME -> giorno (dato O ricevuto)
#	var _grazie_verso := {}   # CRICCHE.chiave(a, b) -> giorno dell'ultimo
#	func _riconoscenza(r: Dictionary, candidati: Array) -> String
#	func _compagnia_per(r: Dictionary, brain: RefCounted) -> Node3D
#	func debug_reciprocita() -> Dictionary


## IL CORPO VA DA CHI SI È PRESO CURA DI LUI, ed è tutta la meccanica.
##
## Senza libro mastro questo stesso villaggio manda Vicino0 dal PRIMO valido
## dell'elenco (Vicino1) — è quello che prova `_il_ripiego_e_quello_di_sempre`
## trenta righe più su. Con un debito vivo verso Vicino2, ci va invece da lui:
## la differenza fra le due scene è il libro mastro, e nient'altro.
##
## ⚠️ MA QUESTO CASO NON ISOLA IL PRIMO ANELLO DAL SECONDO, e va detto: qui
## il creditore è anche l'unico con cui Vicino0 abbia una riga, quindi è pure
## il suo più caro — togliendo la riconoscenza, l'abitudine manderebbe il
## corpo nello stesso posto e il caso resterebbe verde. A separare le due
## domande è il caso qui sotto, ed è quello che tiene l'ORDINE.
func _il_corpo_va_da_chi_si_e_preso_cura_di_lui(t) -> void:
	var v := _villaggio_con_libro(t, 3, [
		_riga("Vicino2", "Vicino0", "coraggio", 50),
	], 80)
	var vis = v["vis"]
	var corpi: Array = v["corpi"]
	var r: Dictionary = (vis.get("_residents") as Array)[0]
	var io := corpi[0] as Node3D
	vis._recita(r, io, vis._ensure_brain(r), "quattro_chiacchiere", "day")
	t.eq(str(io.get("_next_state")), "r_sniff",
			"il corpo va ad annusare — lo STESSO stato del ripiego, perché"
			+ " da fuori le due scene devono essere la stessa scena")
	_va_da(t, io, corpi[2], "chi ci è andato per primo per lui")


## LA RICONOSCENZA VIENE PRIMA DELL'ABITUDINE — l'ordine dei tre anelli.
##
## ⚠️ E LA FIXTURE DEVE SEPARARE LE DUE DOMANDE, che sul libro mastro sono
## vicinissime: «chi conta di più» e «a chi devo un grazie» leggono la stessa
## colonna. Una nascita a SENSO UNICO farebbe di Vicino1 il più caro E il
## creditore, e il caso sarebbe verde in tutti e due i mondi. Qui la nascita è
## RECIPROCA — stesso giorno, tutti e due i versi — quindi il conto è enorme e
## lo squilibrio è zero esatto: Vicino1 è il più caro e non è creditore di
## niente.
func _la_riconoscenza_viene_prima_dell_abitudine(t) -> void:
	var v := _villaggio_con_libro(t, 3, [
		_riga("Vicino1", "Vicino0", "nascita", 78),
		_riga("Vicino0", "Vicino1", "nascita", 78),
		_riga("Vicino2", "Vicino0", "piatto", 78),
	], 80)
	var aff = v["aff"]
	# la premessa, dichiarata invece che sperata
	t.eq(aff.chi_e_il_piu_caro("Vicino0", ["Vicino1", "Vicino2"]), "Vicino1",
			"la premessa: il più caro è quello con cui ha fatto una vita")
	t.eq(aff.chi_ringraziare("Vicino0", ["Vicino1", "Vicino2"]), "Vicino2",
			"…e il creditore è un altro: le due domande sono separate")
	var vis = v["vis"]
	var corpi: Array = v["corpi"]
	var r: Dictionary = (vis.get("_residents") as Array)[0]
	var io := corpi[0] as Node3D
	vis._recita(r, io, vis._ensure_brain(r), "quattro_chiacchiere", "day")
	_va_da(t, io, corpi[2], "il creditore, e non l'affetto di sempre")


## LA PREFERENZA NON ALLARGA I CANDIDATI. Il creditore che non è in piedi non
## è un candidato, e il primo anello non può andarselo a prendere: `fra` è la
## lista di chi c'è, e chi la costruisce sa cose che il libro mastro non sa.
func _la_preferenza_non_allarga_i_candidati(t) -> void:
	var v := _villaggio_con_libro(t, 3, [
		_riga("Vicino2", "Vicino0", "coraggio", 50),
	], 80)
	var vis = v["vis"]
	var corpi: Array = v["corpi"]
	(corpi[2] as Node3D).set("_hidden", true)
	var r: Dictionary = (vis.get("_residents") as Array)[0]
	var io := corpi[0] as Node3D
	vis._recita(r, io, vis._ensure_brain(r), "quattro_chiacchiere", "day")
	_va_da(t, io, corpi[1], "il ripiego di sempre, perché il creditore è"
			+ " dentro casa e non lo si va a chiamare")


## CHI È IN UNA SCENA NON VIENE DISTURBATO, e le tre valvole sono tre.
##
## Il concerto, il congedo, il nascondino: durante una scena quel corpo non è
## di nessuno di noi. E chi dorme il suo pisolino non è «uno che è lì».
func _chi_e_in_una_scena_non_viene_disturbato(t) -> void:
	for guasto in ["_hidden", "scena", "nap"]:
		var v := _villaggio_con_libro(t, 3, [
			_riga("Vicino2", "Vicino0", "coraggio", 50),
		], 80)
		var vis = v["vis"]
		var corpi: Array = v["corpi"]
		var creditore := corpi[2] as Node3D
		match str(guasto):
			"_hidden": creditore.set("_hidden", true)
			"scena": creditore.set("_scena_t", 4.0)
			"nap": creditore.set("_state", "tk_nap")
		var r: Dictionary = (vis.get("_residents") as Array)[0]
		var io := corpi[0] as Node3D
		vis._recita(r, io, vis._ensure_brain(r), "quattro_chiacchiere", "day")
		_va_da(t, io, corpi[1],
				"il ripiego: il creditore non è disponibile (%s)" % str(guasto))


## UNO AL GIORNO, PER PERSONA. Il secondo grazie della stessa giornata non
## parte: si ripiega, in silenzio, come se non ci fosse nessun debito.
func _il_grazie_e_uno_al_giorno(t) -> void:
	# ⚠️ LA NASCITA RECIPROCA CON VICINO1 NON È DECORAZIONE. Senza, l'unica
	# riga di Vicino0 sarebbe quella col creditore, che diventerebbe anche il
	# suo più caro: alla seconda occasione il SECONDO anello lo rimanderebbe
	# nello stesso identico posto e il gettone sembrerebbe non aver fatto
	# niente. Il gettone spegne la RICONOSCENZA, non la compagnia.
	var v := _villaggio_con_libro(t, 3, [
		_riga("Vicino2", "Vicino0", "coraggio", 50),
		_riga("Vicino1", "Vicino0", "nascita", 78),
		_riga("Vicino0", "Vicino1", "nascita", 78),
	], 80)
	var vis = v["vis"]
	var corpi: Array = v["corpi"]
	var r: Dictionary = (vis.get("_residents") as Array)[0]
	var io := corpi[0] as Node3D
	vis._recita(r, io, vis._ensure_brain(r), "quattro_chiacchiere", "day")
	_va_da(t, io, corpi[2], "il creditore, la prima volta")
	io.set("_state", "r_idle")
	vis._recita(r, io, vis._ensure_brain(r), "quattro_chiacchiere", "day")
	_va_da(t, io, corpi[1],
			"e alla seconda occasione della stessa giornata la riconoscenza"
			+ " tace: decide l'anello dopo, e va dal suo più caro")


## ⚠️ …E VALE ANCHE PER CHI LO RICEVE — è la trappola più cara di M3.
##
## Con il gettone sul solo debitore, un cuoco che ha cucinato per tutti
## riceve tredici visite grate nello stesso pomeriggio: il libro mastro degli
## affetti disegnato sul prato come un corteo, cioè la classifica dalla porta
## di servizio che questo sistema si è ripromesso di non scrivere. E il
## raffreddamento della coppia NON lo ferma, perché le coppie sono diverse.
##
## Qui due debitori distinti devono un grazie alla stessa persona, lo stesso
## giorno: il secondo si ripiega.
func _e_uno_al_giorno_anche_per_chi_lo_riceve(t) -> void:
	# la nascita reciproca dà al secondo debitore un più caro che NON è il
	# generoso: senza, sarebbe il secondo anello a rimandarcelo, e il gettone
	# del ricevente sembrerebbe reggere mentre non regge (vedi il caso sopra)
	var v := _villaggio_con_libro(t, 4, [
		_riga("Vicino3", "Vicino0", "coraggio", 50),
		_riga("Vicino3", "Vicino1", "coraggio", 50),
		_riga("Vicino2", "Vicino1", "nascita", 78),
		_riga("Vicino1", "Vicino2", "nascita", 78),
	], 80)
	var vis = v["vis"]
	var corpi: Array = v["corpi"]
	var residenti: Array = vis.get("_residents") as Array
	var primo := corpi[0] as Node3D
	vis._recita(residenti[0], primo, vis._ensure_brain(residenti[0]),
			"quattro_chiacchiere", "day")
	_va_da(t, primo, corpi[3], "il generoso, per il primo dei suoi debitori")
	var secondo := corpi[1] as Node3D
	vis._recita(residenti[1], secondo, vis._ensure_brain(residenti[1]),
			"quattro_chiacchiere", "day")
	_va_da(t, secondo, corpi[2],
			"e il secondo se ne va dal suo più caro: nessuno riceve un corteo")
	t.ok(secondo.call("meta_cammino").distance_to(
			(corpi[3] as Node3D).global_position) > 2.0,
			"…cioè non addosso al generoso, che oggi ha già avuto il suo")


## ⚠️ LA RICONOSCENZA NON DIVENTA UN'ORBITA — è la correzione di genere di
## questo collaudo, e la sua mutazione designata.
##
## Senza raffreddamento, un debito da un piatto manda lo stesso corpo dallo
## stesso creditore **ogni giorno per ventisei giorni** (un atto di coraggio
## per sessantotto). Ventisei giornate di gioco con la stessa persona che ti
## attraversa il villaggio e ti si mette accanto non è un momento: è
## un'orbita, e «nessuno ti orbita attorno» vale fra vicini come vale per il
## giocatore.
##
## Il numero si LEGGE da `Affetti.GIORNI_RIPETIZIONE`, mai ricopiato: è lo
## stesso che tiene l'abitudine fuori dal libro mastro, per la stessa ragione
## — una cosa che si ripete ogni giorno smette di essere quella cosa.
##
## ⚠️ E LA CONTROPROVA STA NELLO STESSO CASO: una coppia DIVERSA, il giorno
## dopo, passa. Il raffreddamento è sulla coppia, non sulla persona; senza la
## controprova, un raffreddamento sbagliato (per persona, o per villaggio)
## resterebbe verde.
func _la_riconoscenza_non_diventa_un_orbita(t) -> void:
	# ⚠️ E ANCHE QUI LA NASCITA RECIPROCA SERVE: nei sei giorni di silenzio
	# il corpo deve avere un posto DOVE ANDARE che non sia il creditore, o a
	# rimandarcelo sarebbe il secondo anello e il raffreddamento sembrerebbe
	# non mordere. Il raffreddamento spegne la riconoscenza, non la vita.
	var v := _villaggio_con_libro(t, 4, [
		_riga("Vicino3", "Vicino0", "coraggio", 50),
		_riga("Vicino3", "Vicino1", "coraggio", 50),
		_riga("Vicino1", "Vicino0", "nascita", 78),
		_riga("Vicino0", "Vicino1", "nascita", 78),
	], 80)
	var vis = v["vis"]
	var corpi: Array = v["corpi"]
	var giorno := v["giorno"] as Node3D
	var residenti: Array = vis.get("_residents") as Array
	var io := corpi[0] as Node3D
	vis._recita(residenti[0], io, vis._ensure_brain(residenti[0]),
			"quattro_chiacchiere", "day")
	_va_da(t, io, corpi[3], "il creditore, il primo giorno")
	# i giorni in mezzo: il debito è ancora vivo, e non succede niente
	for g in range(81, 80 + AFF.GIORNI_RIPETIZIONE):
		giorno.set("day", g)
		io.set("_state", "r_idle")
		vis._recita(residenti[0], io, vis._ensure_brain(residenti[0]),
				"quattro_chiacchiere", "day")
		t.ok(io.call("meta_cammino").distance_to(
				(corpi[3] as Node3D).global_position) > 2.0,
				"giorno %d: non ci torna — e il debito è ancora lì" % g)
		_va_da(t, io, corpi[1],
				"giorno %d: se ne va dal suo più caro, come farebbe" % g
				+ " chiunque non abbia niente da ringraziare")
	# LA CONTROPROVA: un'ALTRA coppia, dentro la stessa finestra, passa
	giorno.set("day", 81)
	var altro := corpi[1] as Node3D
	vis._recita(residenti[1], altro, vis._ensure_brain(residenti[1]),
			"quattro_chiacchiere", "day")
	_va_da(t, altro, corpi[3],
			"…ma un'altra coppia sì: il raffreddamento è sulla COPPIA, non"
			+ " sulla persona e non sul villaggio")
	# e alla settima giornata la stessa coppia torna
	giorno.set("day", 80 + AFF.GIORNI_RIPETIZIONE)
	io.set("_state", "r_idle")
	vis._recita(residenti[0], io, vis._ensure_brain(residenti[0]),
			"quattro_chiacchiere", "day")
	_va_da(t, io, corpi[3],
			"e dopo %d giorni ci si torna: non è un divieto, è una cadenza"
					% AFF.GIORNI_RIPETIZIONE)


## ⚠️ LA VISITA NON PUÒ FABBRICARE UN RITROVO — ed è il FIREWALL, non
## un'eleganza.
##
## Un corpo che si ferma a 0,9 m da un altro fa scrivere a `_segna_incontro`
## una riga di co-presenza (0,9 è sotto `VICINI`, ed è la riga del `fianco`
## che il ripiego usa da sempre). `Cricche.ritrovo_vivo()` diventa vero con
## `GIORNATE_RITROVO` giornate DIVERSE dentro `Cricche.FINESTRA`. Senza
## raffreddamento la visita ne scriverebbe una al giorno: tre in tre giorni,
## e il ritrovo si forma — cioè un debito da un piatto riordinerebbe il
## cerchio del falò e finirebbe nel filo di un cucciolo per sempre. Il libro
## mastro degli affetti entrato per la porta di servizio in due sistemi
## progettati apposta per non guardarlo.
##
## Con il raffreddamento è un'IMPOSSIBILITÀ, non un margine tarato:
## `Cricche.registra` tiene UNA riga al giorno per coppia, quindi in una
## finestra di sette giorni ci stanno al più `ceil(7 / GIORNI_RIPETIZIONE)`
## visite — cioè UNA, contro le TRE che servono.
##
## ⚠️ E SI FA GIRARE `_chats` VERO. Chiamare `Cricche.incontro` a mano nel
## banco vorrebbe dire provare il proprio doppio: `_segna_incontro` ha cinque
## cancelli suoi (la fase del falò, lo stato `r_fire`, `in_scena`, il lease
## sopra `LEASE_SPONTANEO`, la radura), e se il banco ne inciampasse uno per
## caso misurerebbe zero righe su un codice rotto.
func _la_visita_non_puo_fabbricare_un_ritrovo(t) -> void:
	# ⚠️ E LA NASCITA RECIPROCA CON VICINO1 È IL CUORE DELLA FIXTURE, non un
	# contorno. Nei sei giorni di silenzio il corpo deve avere un posto dove
	# andare che NON sia il creditore: se il secondo anello lo rimandasse lì
	# ogni giorno, le righe di co-presenza si accumulerebbero comunque e
	# questo caso arrossirebbe accusando il raffreddamento di una cosa che
	# non ha fatto. Che l'ABITUDINE fabbrichi un ritrovo è giusto — è la
	# frase che `Cricche` esiste per dire; quello che non deve poterlo fare
	# è il DEBITO.
	var v := _villaggio_con_libro(t, 3, [
		_riga("Vicino2", "Vicino0", "coraggio", 50),
		_riga("Vicino1", "Vicino0", "nascita", 78),
		_riga("Vicino0", "Vicino1", "nascita", 78),
	], 80)
	var vis = v["vis"]
	var corpi: Array = v["corpi"]
	var giorno := v["giorno"] as Node3D
	var residenti: Array = vis.get("_residents") as Array
	var cri = CRICCHE.new()
	cri.name = "Cricche"
	(v["casa"] as Node3D).add_child(cri)
	var visite := 0
	for g in range(80, 87):
		giorno.set("day", g)
		var io := corpi[0] as Node3D
		io.set("_state", "r_idle")
		vis._recita(residenti[0], io, vis._ensure_brain(residenti[0]),
				"quattro_chiacchiere", "day")
		# il corpo ARRIVA: la meta si posa addosso, e i due si trovano vicini
		var meta: Vector3 = io.call("meta_cammino")
		io.global_position = meta
		io.set("_state", "r_sniff")
		# tutti gli stati devono stare nella lista `chatty` di `_chats`, o la
		# coppia non viene nemmeno guardata e il caso misurerebbe il proprio
		# banco invece del cancello
		for altro in corpi:
			if altro != io:
				(altro as Node3D).set("_state", "r_idle")
		if meta.distance_to((corpi[2] as Node3D).global_position) < 2.0:
			visite += 1
		vis.set("_chat_acc", 0.0)
		vis._chats(0.0)
		cri.call("giro_del_giorno", g)
	var righe: Array = cri.get("_incontri") as Array
	var campioni: Array = CRICCHE.campioni(righe, "Vicino0", "Vicino2")
	t.ok(visite >= 1,
			"la premessa: in sette giornate almeno una visita c'è stata"
			+ " (altrimenti questo caso misurerebbe il proprio silenzio)")
	# ⚠️ E IL CONTROLLO DI SANITÀ: `_segna_incontro` ha cinque cancelli suoi,
	# e se il banco ne inciampasse uno per caso scriverebbe ZERO righe — il
	# firewall sembrerebbe reggere su un codice che non gira. Le righe
	# dell'ABITUDINE devono esserci.
	t.ok(righe.size() >= 3,
			"…e il registro delle co-presenze si è riempito davvero (%d"
					% righe.size() + " righe): il cancello non è un banco muto")
	t.ok(campioni.size() < CRICCHE.GIORNATE_RITROVO,
			("le righe di co-presenza fra i due restano sotto le %d che"
			+ " servono a un ritrovo (%d)")
					% [CRICCHE.GIORNATE_RITROVO, campioni.size()])
	# `abitudine()` È il predicato di casa — `ritrovo_vivo` torna il REFERTO
	# (un Dictionary, vuoto quando non c'è), e chiederne il valore di verità
	# non compila nemmeno. Si chiede al predicato, non alla scheda.
	t.ok(not CRICCHE.abitudine(righe, "Vicino0", "Vicino2", 86),
			"…e nessun ritrovo si è formato: il cerchio del falò e il filo"
			+ " di un cucciolo non sanno niente del libro mastro")


## IL PAREGGIO NON ELEGGE NESSUNO, NEMMENO NEL CORPO. È la stessa guardia del
## puro, vista da fuori: se due si sono presi cura di te lo stesso giorno e
## nello stesso modo, il gioco non sceglie al posto tuo — e il corpo se ne va
## dove sarebbe andato comunque.
func _il_pareggio_non_elegge_nessuno_nel_corpo(t) -> void:
	var v := _villaggio_con_libro(t, 3, [
		_riga("Vicino1", "Vicino0", "coraggio", 50),
		_riga("Vicino2", "Vicino0", "coraggio", 50),
	], 80)
	var vis = v["vis"]
	var corpi: Array = v["corpi"]
	var aff = v["aff"]
	t.eq(aff.chi_ringraziare("Vicino0", ["Vicino1", "Vicino2"]), "",
			"la premessa: due crediti identici non eleggono nessuno")
	var r: Dictionary = (vis.get("_residents") as Array)[0]
	var io := corpi[0] as Node3D
	vis._recita(r, io, vis._ensure_brain(r), "quattro_chiacchiere", "day")
	_va_da(t, io, corpi[1],
			"il ripiego di sempre — e non il primo dell'array dei crediti,"
			+ " che sarebbe il gioco che rompe il pareggio per conto suo")


## ⚠️ IL DEBITO NON È UNA CLASSIFICA VISIBILE, e questo è il caso che tiene
## la REGOLA SACRA.
##
## Se la visita grata avesse un toast, una nuvoletta, una postura o uno stato
## del corpo diverso dal ripiego, il gioco starebbe dicendo a schermo «questo
## qui ti deve qualcosa» — cioè accusando qualcuno di non aver ricambiato. Il
## libro mastro non ha una riga «tradimento», e non deve averne una scritta
## col corpo: da fuori, la visita grata e il giro di sempre devono essere la
## STESSA SCENA.
func _il_debito_non_e_una_classifica_visibile(t) -> void:
	var grato := _villaggio_con_libro(t, 3, [
		_riga("Vicino2", "Vicino0", "coraggio", 50),
	], 80)
	var normale := _villaggio_con_libro(t, 3, [], 80)
	var pose: Array = []
	var stati: Array = []
	for v in [grato, normale]:
		var vis = (v as Dictionary)["vis"]
		var corpi: Array = (v as Dictionary)["corpi"]
		var r: Dictionary = (vis.get("_residents") as Array)[0]
		var io := corpi[0] as Node3D
		vis._recita(r, io, vis._ensure_brain(r), "quattro_chiacchiere", "day")
		stati.append([str(io.get("_state")), str(io.get("_next_state"))])
		pose.append(str(io.get_meta("postura", "")))
	t.eq(str(stati[0]), str(stati[1]),
			"il corpo fa la stessa identica cosa nelle due scene: %s"
					% str(stati[0]))
	t.eq(str(pose[0]), str(pose[1]),
			"e non indossa nessuna posa che dica quale delle due è")
	t.eq(str(pose[0]), "",
			"…che è nessuna posa affatto")
	# e il libro mastro non si è mosso di un byte: la lettura non scrive
	var aff = grato["aff"]
	t.eq(JSON.stringify(aff.get("_righe")),
			JSON.stringify([_riga("Vicino2", "Vicino0", "coraggio", 50)]),
			"il libro mastro è byte per byte quello di prima")
	var chiavi := (aff.save_extra() as Dictionary).keys()
	chiavi.sort()
	t.eq(str(chiavi), str(["affetti", "coppie_ieri", "ferite"]),
			"e il salvataggio ha ancora le stesse tre chiavi")


## IL REFERTO CONTA I SILENZI, uno per uno.
##
## Un banco che dice «zero visite grate» lascia indovinare, e si finisce per
## accusare il cablaggio quando era il gettone — è la lezione già pagata dal
## vocabolario del corpo, dove il silenzio ha sei nomi diversi. Qui ne ha
## cinque, e vanno contati separatamente o il banco vivo non saprà mai se il
## primo anello è spento o solo prudente.
func _il_referto_conta_i_silenzi(t) -> void:
	var v := _villaggio_con_libro(t, 3, [
		_riga("Vicino2", "Vicino0", "coraggio", 50),
	], 80)
	var vis = v["vis"]
	var corpi: Array = v["corpi"]
	var r: Dictionary = (vis.get("_residents") as Array)[0]
	var io := corpi[0] as Node3D
	var prima: Dictionary = vis.debug_reciprocita()
	for k in ["grazie", "ripieghi", "no_gettone", "no_raffreddamento",
			"no_debito"]:
		t.ok(prima.has(str(k)), "il referto ha la voce «%s»" % str(k))
	vis._recita(r, io, vis._ensure_brain(r), "quattro_chiacchiere", "day")
	t.eq(int(vis.debug_reciprocita()["grazie"]), int(prima["grazie"]) + 1,
			"una visita grata si conta")
	io.set("_state", "r_idle")
	vis._recita(r, io, vis._ensure_brain(r), "quattro_chiacchiere", "day")
	t.eq(int(vis.debug_reciprocita()["no_gettone"]),
			int(prima["no_gettone"]) + 1,
			"…e il secondo silenzio della giornata si conta col SUO nome")
