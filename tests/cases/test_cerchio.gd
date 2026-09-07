extends RefCounted

## IL CERCHIO DEL FALÒ — la metà PURA, e le proprietà che la rendono dicibile
## in un gioco cozy.
##
## Questo file prova `scenes/npc/Cerchio.gd` e **nient'altro**: in questa
## consegna nessuno lo chiama, quindi il gioco è bit-identico a ieri. La
## guardia che il cablaggio esista arriverà col cablaggio, e sarà la più
## importante di tutte — in questo progetto i sistemi arrivano SPENTI (il
## termine dell'insieme che non cambiava nessuna decisione, la neurochimica
## che non arrivava a nessun corpo, 247 righe di somatizzazione col corpo
## bit-identico: tutti completi, provati, verdi).
##
## ⚠️ **DOVE STANNO I CASI CHE QUI NON CI SONO.** Il piano elenca in un file
## solo (`test_falo.gd`) i casi puri e quelli del cablaggio; questi due
## atterrano in commit diversi e da mani diverse, quindi i puri stanno qui e i
## comportamentali restano al cablatore, insieme a `Visitors.gd`. I nomi che
## non compaiono in questo file — `_la_coppia_si_siede_accanto_davvero`,
## `_il_cerchio_si_compone_una_volta_per_sera`, `_chi_e_seduto_non_si_alza`,
## `_senza_i_registri_e_il_falo_di_sempre`,
## `_il_vuoto_si_apre_prima_della_rimozione`, `_il_vuoto_dura_quanto_il_lutto`
## — sono suoi, e nessuno dei due elenchi va accorciato.
##
## E i casi non cercano stringhe nei sorgenti: chiamano le funzioni vere e
## guardano dove finisce la gente. Un source-check resta verde anche
## cancellando il codice che sorveglia.

const CERCHIO := preload("res://scenes/npc/Cerchio.gd")
const VISITORS := preload("res://scenes/npc/Visitors.gd")
const ANIMO := preload("res://scenes/npc/Animo.gd")


func run(t) -> void:
	# --- il degrado, che qui è il caso limite e non un ramo
	_senza_predicati_e_il_falo_di_sempre(t)
	_chi_sta_da_solo_non_si_muove(t)
	_due_omonimi_e_il_falo_di_sempre(t)
	_i_partiti_non_siedono(t)

	# --- ⚜️ l'ancora, cioè la regola che tiene questo cerchio fuori dal podio
	_l_ordine_delle_ancore_e_l_anzianita(t)
	_la_stessa_sera_due_volte(t)

	# --- chi siede accanto a chi
	_una_coppia_siede_accanto(t)
	_il_cucciolo_sta_in_mezzo(t)
	_i_fratelli_in_fila_per_eta(t)
	_una_famiglia_alla_volta(t)
	_il_ritrovo_non_spezza_una_coppia(t)
	_la_catenella_ha_un_tetto(t)
	_non_si_chiude_ad_anello(t)

	# --- il posto di chi non c'è più
	_il_vuoto_tiene_il_posto(t)
	_il_buco_si_richiude_dopo_N_sere(t)
	_il_vicino_resta_accanto_al_vuoto(t)
	_il_vicino_del_vuoto_puo_essere_sparito(t)
	_al_massimo_due_vuoti(t)
	_un_fantasma_ha_una_sedia_sola(t)
	_i_vuoti_tornano_a_ritroso(t)
	_dal_disco_tornano_interi(t)
	_una_riga_sporca_non_ruba_una_sedia(t)

	# --- la geometria vera del falò
	_i_posti_non_si_pestano_neanche_coi_vuoti(t)
	_il_vuoto_e_una_spaziatura_doppia(t)

	# --- il genere
	_il_cerchio_non_scrive_niente(t)
	_nessuno_lo_nomina(t)
	_il_cerchio_arriva_ai_corpi(t)
	_senza_registri_il_cablaggio_e_il_falo_di_sempre(t)
	_il_vuoto_si_apre_prima_della_rimozione(t)
	_i_vuoti_sopravvivono_al_salvataggio(t)
	_la_sera_il_cerchio_si_compone(t)


# ------------------------------------------------------------------ attrezzi

func _base(quanti: int) -> PackedStringArray:
	var b := PackedStringArray()
	for i in quanti:
		b.append("N%d" % i)
	return b


func _slot(giro: PackedStringArray, chi: String) -> int:
	return giro.find(chi)


## Sono seduti l'uno accanto all'altro? Il cerchio è una fila di sedie: due
## nomi sono adiacenti se i loro slot distano uno.
func _accanto(giro: PackedStringArray, a: String, b: String) -> bool:
	var ia := giro.find(a)
	var ib := giro.find(b)
	return ia >= 0 and ib >= 0 and absi(ia - ib) == 1


func _e_permutazione(giro: PackedStringArray, base: PackedStringArray) -> bool:
	if giro.size() != base.size():
		return false
	var visti := {}
	for n in giro:
		if visti.has(n):
			return false
		visti[n] = true
	for n in base:
		if not visti.has(n):
			return false
	return true


# --------------------------------------------------------------- il degrado

## ⚜️ **IL DEGRADO È IL CASO LIMITE DELL'ALGORITMO, NON UN `if`.**
##
## Un villaggio appena nato, un banco, il diorama del titolo: senza registri
## non c'è niente da spostare, e quel che esce è il falò di sempre — **bit per
## bit**, non «quasi». È la proprietà che va difesa in revisione più di ogni
## altra: chi la ottenesse con un `if predicati.is_empty(): return base`
## avrebbe due algoritmi invece di uno, e il secondo non lo prova nessuno.
func _senza_predicati_e_il_falo_di_sempre(t) -> void:
	for quanti in [0, 1, 2, 7, 28]:
		var base := _base(quanti)
		t.eq(CERCHIO.cerchio(base, [], [], [], {}), base,
				"senza registri il cerchio è l'ordine di trasloco (%d vicini)"
				% quanti)
	# e non basta il vuoto: anche i registri PIENI DI NIENTE devono tacere
	var b := _base(6)
	t.eq(CERCHIO.cerchio(b, [{"genitori": [], "figli": []}], [[]], [{}],
			{"N0": PackedStringArray()}), b,
			"registri vuoti dentro: sempre il falò di sempre")
	# …e le righe che parlano di gente che qui non c'è
	t.eq(CERCHIO.cerchio(b, [], [["Ignoto", "Nessuno"]], [],
			{"Ignoto": PackedStringArray(["Nessuno"])}), b,
			"legami fra nomi che non sono nella base: nessuno si muove")
	# l'anello da solo ha la stessa proprietà, ed è quella che la regge
	t.eq(CERCHIO.anello(b, []), b, "anello(base, []) è base")


## **CHI STA DA SOLO NON SI MUOVE PER CAUSA SUA.** Non esiste un ramo che
## chieda «e chi non sta con nessuno?»: chi non ha coppia, non si ritrova con
## nessuno e non ha figli è catenella di uno, ancora uguale al proprio indice.
##
## Si prova nel modo più stretto che il meccanismo permette: se le catenelle si
## formano tutte DIETRO di lui, il suo slot è quello di ieri **identico**; e in
## ogni caso nessun solitario scavalca un altro solitario, perché fra loro
## l'ordine è ancora e sempre l'anzianità.
func _chi_sta_da_solo_non_si_muove(t) -> void:
	var base := _base(8)
	# una coppia fra il sesto e l'ottavo: tutto quel che succede sta dietro
	var giro := CERCHIO.cerchio(base, [], [["N5", "N7"]], [], {})
	for i in 5:
		t.eq(_slot(giro, "N%d" % i), i,
				"N%d è solo e nessuno davanti a lui si è mosso: stessa sedia"
				% i)
	# e chi si muove è chi ha un legame, non chi non ce l'ha
	t.ok(_accanto(giro, "N5", "N7"), "i due che stanno insieme siedono insieme")
	t.eq(_slot(giro, "N6"), 7,
			"N6 non ha perso il posto: ha chiuso la fila dopo chi si è unito")

	# --- e adesso il villaggio pieno, con TRE solitari sparsi in mezzo
	#
	# ⚠️ chi è solo NON si scrive a mano: si RICAVA dai registri di questo
	# caso. Una versione precedente lo cablava (`return chi in ["N5"]`), e
	# siccome quel fixture aveva un solitario solo il ciclo che segue trovava
	# un elemento e basta: `fuori_ordine` era zero PER COSTRUZIONE, cioè
	# un'asserzione che nessuna mutazione poteva far diventare rossa.
	var base2 := _base(10)
	var fam := [{"genitori": ["N1", "N7"], "figli": ["N4"]}]
	var cop := [["N2", "N8"]]
	var rit := {"N5": PackedStringArray(["N9"])}
	var soli := _soli(base2, fam, cop, rit)
	t.eq(soli.size(), 3,
			"il banco ha davvero più di un solitario, o il caso non prova "
			+ "niente (%s)" % str(soli))
	var giro2 := CERCHIO.cerchio(base2, fam, cop, [], rit)
	var prima := -1
	var fuori_ordine := 0
	for chi in soli:
		var s := _slot(giro2, str(chi))
		if prima >= 0 and s < prima:
			fuori_ordine += 1
		prima = s
	t.eq(fuori_ordine, 0,
			"nessun solitario scavalca un altro solitario: fra loro è ancora "
			+ "l'anzianità (%s)" % str(giro2))

	# ⚜️ e una catenella che CRESCE tutta dietro di lui non lo muove di una
	# sedia. È la lettura misurabile dell'ancora: siccome una catenella si
	# mette dove sta il suo più anziano, allungarla alle spalle di qualcuno non
	# può scavalcarlo. Se le catenelle si ordinassero per lunghezza — o per
	# quanto sono care — allungarne una dietro lo sposterebbe eccome.
	#
	# ⚠️ «dietro di lui» si misura sull'ANCORA, non sugli indici dei due nomi:
	# un ritrovo fra due che stanno dopo N3 può benissimo attaccarsi a una
	# catenella ancorata PRIMA di lui, e allora tirarsela avanti è la meccanica
	# che funziona, non un difetto. Qui N5 e N6 sono ancorati a 5 e 6.
	var rit2 := rit.duplicate(true)
	rit2["N6"] = PackedStringArray(["N5"])
	var giro3 := CERCHIO.cerchio(base2, fam, cop, [], rit2)
	t.ok(_accanto(giro3, "N6", "N5"),
			"il ritrovo nuovo ha davvero cucito qualcuno (%s)" % str(giro3))
	t.eq(_slot(giro3, "N0"), _slot(giro2, "N0"),
			"una catenella che si allunga in fondo non muove chi sta davanti")
	t.eq(_slot(giro3, "N3"), _slot(giro2, "N3"),
			"…e nemmeno il solitario che le sta appena prima")


## Chi non compare in NESSUN registro di questo caso: si legge dai registri
## veri invece di scriverlo a mano, o il banco finisce per provare la propria
## lista invece del cerchio.
func _soli(base: PackedStringArray, famiglie: Array, coppie: Array,
		ritrovi: Dictionary) -> Array:
	var legati := {}
	for f in famiglie:
		for chiave in ["genitori", "figli"]:
			for n in ((f as Dictionary).get(chiave, []) as Array):
				legati[str(n)] = true
	for c in coppie:
		for n in (c as Array):
			legati[str(n)] = true
	for k in ritrovi:
		legati[str(k)] = true
		for n in ritrovi[k]:
			legati[str(n)] = true
	var fuori: Array = []
	for n in base:
		if not legati.has(str(n)):
			fuori.append(str(n))
	return fuori


## ⚠️ **DUE OMONIMI: CI SI TIRA INDIETRO.** `ChibiDNA` garantisce l'unicità
## delle LABEL, non quella dei nomi, e tutto ciò che in questo gioco è chiavato
## per nome (`Cricche`, `Affetti`, `Legami`) già li confonde. Non è questo file
## a doverlo chiudere — ma non lo si peggiora: senza questa guardia uno dei due
## perderebbe la sedia e il cablaggio metterebbe **due corpi sullo stesso
## punto**, che è il guasto che si vede.
func _due_omonimi_e_il_falo_di_sempre(t) -> void:
	var base := PackedStringArray(["A", "B", "A", "C"])
	var giro := CERCHIO.cerchio(base, [], [["A", "C"]], [], {})
	t.eq(giro.size(), base.size(),
			"con due omonimi nessuno perde la sedia (%s)" % str(giro))
	t.eq(giro, base, "…e il cerchio resta quello di ieri")


## `Legami.figli_di` e `genitori_di` ciclano anche chi è partito — è il loro
## mestiere, e il filo di chi se n'è andato resta per sempre. Il cerchio deve
## filtrare contro la base VIVA, o proverebbe a far sedere qualcuno che non c'è.
func _i_partiti_non_siedono(t) -> void:
	var base := _base(5)
	var giro := CERCHIO.cerchio(base,
			[{"genitori": ["N0", "Andato"], "figli": ["N2", "Andata"]}],
			[["N4", "Sparito"]], [],
			{"N1": PackedStringArray(["Perduto"])})
	t.ok(_e_permutazione(giro, base),
			"chi non è nella base non siede, e nessuno dei vivi resta in piedi")
	t.ok(_accanto(giro, "N0", "N2"),
			"e la famiglia mutilata funziona lo stesso: il genitore rimasto "
			+ "siede col figlio")

	# ⚠️ E LO STESSO SI CHIEDE AD `anello` DA SOLA, o il suo filtro non ha
	# lettori. Passando da `cerchio()` i partiti non arrivano mai fin qui —
	# `catenelle` li ha già tolti costruendo i legami — quindi la riga di
	# `anello` che li scarta è una SECONDA rete, e le reti seconde non le prova
	# nessuno: MISURATO, togliendola la suite restava verde. Ma `anello` è
	# pubblica, il cablatore può chiamarla, e il suo contratto scritto è
	# proprio questo: `Legami.figli_di` e `genitori_di` elencano anche chi è
	# partito, ed è il loro mestiere.
	var viva := _base(3)
	var con_partito := [PackedStringArray(["N0", "Andato", "N1"])]
	var g2: PackedStringArray = CERCHIO.anello(viva, con_partito)
	t.eq(g2, PackedStringArray(["N0", "N1", "N2"]),
			"`anello` scarta da sé chi non è nella base di stasera (%s)" % str(g2))
	t.ok(_accanto(g2, "N0", "N1"),
			"…e i due che restano si ritrovano accanto: il buco di un partito "
			+ "dentro una famiglia si chiude, non lascia una sedia")


# ------------------------------------------------ ⚜️ l'ancora, cioè il genere

## ⚜️⚜️ **L'ANCORA È L'ANZIANITÀ, E QUESTA È LA GUARDIA CHE TIENE IL CERCHIO
## FUORI DAL PODIO.**
##
## Una catenella si mette dove sta il suo membro più anziano. La mutazione da
## temere non è un errore: è un'idea — ordinare le catenelle per `conto()`, per
## `quanto()`, per quanto sono lunghe, o mettere i più cari più vicini al
## fuoco. Qualunque di quelle rende il falò **la classifica resa visibile**,
## che è l'esempio che la regola 2 degli Affetti vieta per iscritto.
##
## Si prova sull'unica cosa osservabile che lo dice: la successione delle
## ancore attorno al cerchio dev'essere **strettamente crescente**.
func _l_ordine_delle_ancore_e_l_anzianita(t) -> void:
	var base := _base(10)
	var fam := [{"genitori": ["N7", "N9"], "figli": ["N8"]}]
	var cop := [["N1", "N6"]]
	var rit := {"N3": PackedStringArray(["N5"])}
	var cat: Array = CERCHIO.catenelle(base, fam, cop, [], rit)
	var giro := CERCHIO.anello(base, cat)
	t.ok(_e_permutazione(giro, base), "il cerchio è una permutazione della base")

	# la successione delle ancore, letta sul giro vero
	var indice := {}
	for i in base.size():
		indice[base[i]] = i
	var ancore: Array = []
	var vista := {}
	for c in cat:
		var m := -1
		for n in (c as PackedStringArray):
			var k: int = indice[str(n)]
			if m < 0 or k < m:
				m = k
		t.ok(not vista.has(m),
				"due catenelle non possono avere la stessa ancora (%d)" % m)
		vista[m] = true
		ancore.append(m)
	# …e nell'ordine in cui si siedono
	var lette: Array = []
	var gia := {}
	for n in giro:
		var k: int = indice[str(n)]
		var mia := k
		for c in cat:
			if (c as PackedStringArray).find(str(n)) < 0:
				continue
			var m2 := -1
			for x in (c as PackedStringArray):
				var kx: int = indice[str(x)]
				if m2 < 0 or kx < m2:
					m2 = kx
			mia = m2
		if gia.has(mia):
			continue
		gia[mia] = true
		lette.append(mia)
	var crescente := true
	for i in range(1, lette.size()):
		if int(lette[i]) <= int(lette[i - 1]):
			crescente = false
	t.ok(crescente,
			"le catenelle si siedono in ordine di ANZIANITÀ, mai di affetto "
			+ "né di lunghezza (%s)" % str(lette))

	# e la lettura che lo dice in una riga: fra due coppie, siede prima quella
	# del più anziano — comunque siano elencate
	var due := CERCHIO.cerchio(_base(6), [], [["N4", "N5"], ["N0", "N3"]], [], {})
	t.ok(_slot(due, "N0") < _slot(due, "N4"),
			"fra due coppie siede prima quella del più anziano, e l'ordine in "
			+ "cui il registro le elenca non conta")


## **NIENTE DADI, E NESSUNA DIPENDENZA DALL'ORDINE DEI REGISTRI.** A villaggio
## fermo il cerchio è lo stesso, sera dopo sera: un cerchio che si rimescola
## senza causa non ricorda niente. E siccome i legami si applicano in ordine di
## anzianità e non di arrivo, `Cricche` e `Affetti` possono elencare le proprie
## righe come vogliono.
func _la_stessa_sera_due_volte(t) -> void:
	var base := _base(9)
	var fam := [{"genitori": ["N0", "N5"], "figli": ["N3"]}]
	var cop := [["N1", "N7"], ["N2", "N8"]]
	var rit := {"N4": PackedStringArray(["N6"]), "N6": PackedStringArray(["N4"])}
	var atteso := CERCHIO.cerchio(base, fam, cop, [], rit)
	for _giro in 20:
		t.eq(CERCHIO.cerchio(base, fam, cop, [], rit), atteso,
				"la stessa sera due volte dà lo stesso cerchio")
	# gli stessi legami elencati al contrario
	var cop2 := [["N8", "N2"], ["N7", "N1"]]
	var rit2 := {"N6": PackedStringArray(["N4"]), "N4": PackedStringArray(["N6"])}
	t.eq(CERCHIO.cerchio(base, fam, cop2, [], rit2), atteso,
			"l'ordine in cui i registri elencano i legami non cambia un posto")

	# ⚠️ MA CON QUESTI LEGAMI L'ORDINE NON POTEVA CAMBIARE NIENTE, e il
	# rovesciamento qui sopra non provava quel che dice: sono coppie isolate,
	# che si cuciono uguale da qualunque parte si cominci. L'ordine conta solo
	# dove i legami COMPETONO, e a farli competere è il tetto: una fila di
	# quattro conoscenze consecutive ne concede tre, quindi **quella che resta
	# fuori dipende da dove si è cominciato**. Le catenelle vanno sui PARI,
	# così chi si siede insieme si porta dietro un cambio di posto visibile
	# invece di restare nell'ordine di trasloco.
	# MISURATO: togliendo l'ordinamento dal sorgente, queste due letture danno
	# «N0 N2 N4 N6 …» e «N0 N1 N2 N4 …» — e prima nessun caso le distingueva.
	var b10 := _base(10)
	var su := {"N0": PackedStringArray(["N2"]), "N2": PackedStringArray(["N4"]),
			"N4": PackedStringArray(["N6"]), "N6": PackedStringArray(["N8"])}
	var giu := {"N6": PackedStringArray(["N8"]), "N4": PackedStringArray(["N6"]),
			"N2": PackedStringArray(["N4"]), "N0": PackedStringArray(["N2"])}
	t.eq(CERCHIO.cerchio(b10, [], [], [], giu), CERCHIO.cerchio(b10, [], [], [], su),
			"e nemmeno quando è il TETTO a decidere chi resta fuori")


# --------------------------------------------------- chi siede accanto a chi

func _una_coppia_siede_accanto(t) -> void:
	var base := _base(7)
	var giro := CERCHIO.cerchio(base, [], [["N1", "N5"]], [], {})
	t.ok(_accanto(giro, "N1", "N5"), "due che stanno insieme siedono insieme")
	t.ok(_e_permutazione(giro, base), "e nessuno resta in piedi")
	# la coppia sta dove sta il più anziano dei due
	t.eq(_slot(giro, "N1"), 1, "la coppia si mette al posto del più anziano")


## **IL CUCCIOLO STA IN MEZZO, E I GENITORI NON SI TOCCANO PIÙ.** È la frase,
## non un effetto collaterale da compensare: chi in revisione trovasse «brutto»
## che due che stanno insieme non siedano più accanto, sta guardando la
## famiglia da fuori.
func _il_cucciolo_sta_in_mezzo(t) -> void:
	var base := _base(6)
	var giro := CERCHIO.cerchio(base,
			[{"genitori": ["N0", "N4"], "figli": ["N2"]}], [], [], {})
	t.ok(_accanto(giro, "N0", "N2"), "il cucciolo ha un genitore da una parte")
	t.ok(_accanto(giro, "N2", "N4"), "…e l'altro dall'altra")
	t.ok(not _accanto(giro, "N0", "N4"),
			"e i genitori non si toccano più: in mezzo c'è il cucciolo")
	t.ok(_e_permutazione(giro, base), "e il cerchio resta intero")


## **I FRATELLI IN FILA PER ETÀ.** L'ordine arriva già fatto da
## `Legami.figli_di` (che ordina per `giorno_arrivo`) e qui non si rimescola:
## riordinarli a mano sarebbero due risposte alla stessa domanda.
##
## Un cerchio non ha un verso privilegiato, quindi quel che si pretende è che
## fra due fratelli non si infili nessuno e che l'ordine non si mescoli — da
## che parte lo si legge non è una proprietà del villaggio.
##
## ⚠️ I tre fratelli si chiamano apposta in un ordine d'età che NON è quello
## alfabetico: con `C1, C2, C3` un `figli.sort()` — la mutazione plausibile,
## «tanto vale metterli in ordine» — avrebbe lasciato il caso verde, e il banco
## avrebbe certificato una proprietà che non stava provando.
func _i_fratelli_in_fila_per_eta(t) -> void:
	var base := PackedStringArray(["P", "M", "Zaffiro", "Anice", "Malva", "Z"])
	var giro := CERCHIO.cerchio(base,
			[{"genitori": ["P", "M"],
			"figli": ["Zaffiro", "Anice", "Malva"]}], [], [], {})
	var s1 := _slot(giro, "Zaffiro")
	var s2 := _slot(giro, "Anice")
	var s3 := _slot(giro, "Malva")
	t.ok(absi(s1 - s2) == 1 and absi(s2 - s3) == 1,
			"i fratelli sono contigui, uno dopo l'altro (%s)" % str(giro))
	t.ok((s1 < s2 and s2 < s3) or (s1 > s2 and s2 > s3),
			"…e in fila per età, non mescolati")
	t.ok(_accanto(giro, "P", "Zaffiro") or _accanto(giro, "P", "Malva"),
			"un genitore chiude la fila da una parte")
	t.ok(_accanto(giro, "M", "Zaffiro") or _accanto(giro, "M", "Malva"),
			"…e l'altro dall'altra")
	t.eq(_slot(giro, "Z"), 5,
			"e chi non è di quella famiglia non si è mosso di una sedia")


## **UNA FAMIGLIA ALLA VOLTA.** Chi è insieme cucciolo di qualcuno e genitore
## di qualcun altro non può stare in mezzo a due blocchi: il primo — cioè
## quello del più anziano — resta intero, e il secondo si accorcia. Non si
## sceglie quale famiglia spezzare per il gusto di far quadrare un conto.
func _una_famiglia_alla_volta(t) -> void:
	var base := PackedStringArray(["P", "M", "X", "S", "Z"])
	var giro := CERCHIO.cerchio(base, [
			{"genitori": ["P", "M"], "figli": ["X"]},
			{"genitori": ["X", "S"], "figli": ["Z"]}], [], [], {})
	t.ok(_e_permutazione(giro, base),
			"nessuno siede due volte e nessuno resta in piedi (%s)" % str(giro))
	t.ok(_accanto(giro, "P", "X") and _accanto(giro, "X", "M"),
			"la famiglia più anziana resta intera: X sta fra i suoi")
	t.ok(_accanto(giro, "Z", "S"),
			"e la seconda si accorcia invece di sparire: Z siede col genitore "
			+ "che gli è rimasto libero")


## **UN RITROVO NON SI INFILA FRA DUE CHE STANNO INSIEME.** Si cuce solo agli
## ESTREMI di una catenella: infilarsi in mezzo spezzerebbe un'adiacenza già
## promessa. È la ragione per cui i legami esclusivi (famiglie, coppie, vuoti)
## si applicano prima di quelli molti-a-molti.
func _il_ritrovo_non_spezza_una_coppia(t) -> void:
	var base := _base(5)
	# N2 si ritrova con tutti e due quelli della coppia: da qualche parte deve
	# mettersi, ma non in mezzo a loro
	var giro := CERCHIO.cerchio(base, [], [["N1", "N3"]], [],
			{"N2": PackedStringArray(["N1", "N3"])})
	t.ok(_accanto(giro, "N1", "N3"),
			"la coppia resta accanto (%s)" % str(giro))
	t.ok(_accanto(giro, "N2", "N1") or _accanto(giro, "N2", "N3"),
			"…e chi si ritrova con loro si mette a un capo, non in mezzo")
	t.ok(_e_permutazione(giro, base), "e il cerchio resta intero")

	# ⚠️ UNA COPPIA NON HA UN MEZZO: con una catenella di DUE, «non ci si cuce
	# in mezzo» non ha nessun posto in cui essere falso, e il caso qui sopra
	# vive tutto sul controllo dell'estremo di CHI ARRIVA. Serve una catenella
	# di TRE — e chi bussa deve avere l'indice PIÙ BASSO del centro, perché
	# `_riga_legame` mette sempre davanti il più anziano: solo così il centro
	# finisce dalla parte del legame che l'altro controllo non guarda.
	# MISURATO: senza questo blocco, togliere quel controllo dal sorgente
	# lasciava la suite completamente verde.
	var b5 := _base(5)
	var catena := [["N2", "N3"], ["N3", "N4"]]     # N3 sta in MEZZO
	var senza := CERCHIO.cerchio(b5, [], catena, [], {})
	var con := CERCHIO.cerchio(b5, [], catena, [],
			{"N0": PackedStringArray(["N3"])})      # N0 bussa al centro
	t.eq(con, senza,
			"un ritrovo che bussa al CENTRO di una catenella non entra: la sera è quella di prima (%s)"
			% str(con))
	t.ok(_accanto(con, "N2", "N3") and _accanto(con, "N3", "N4"),
			"la catenella resta intera")
	t.ok(not _accanto(con, "N0", "N2"),
			"e non nasce un'adiacenza che nessun registro ha chiesto")


## **IL TETTO, e vale solo per i legami molli.** Quattro sedie sono 126° del
## primo anello: sopra, un gruppo di conoscenti non si legge più come un
## gruppo. Le catenelle DURE — le famiglie — possono andare oltre, ed è
## dichiarato: mettere un tetto lì vorrebbe dire scegliere quale famiglia
## spezzare.
func _la_catenella_ha_un_tetto(t) -> void:
	# gli anelli di ritrovo sono sparsi apposta, o una catenella troncata
	# darebbe lo stesso cerchio della base e il caso sarebbe cieco
	var base := PackedStringArray(["A", "X", "B", "Y", "C", "Z", "D", "W", "E"])
	var rit := {
		"A": PackedStringArray(["B"]),
		"B": PackedStringArray(["C"]),
		"C": PackedStringArray(["D"]),
		"D": PackedStringArray(["E"]),
	}
	var cat: Array = CERCHIO.catenelle(base, [], [], [], rit)
	var piu_lunga := 0
	for c in cat:
		piu_lunga = maxi(piu_lunga, (c as PackedStringArray).size())
	t.eq(piu_lunga, CERCHIO.CATENELLA_MAX,
			"una catena di conoscenze si ferma al tetto")
	var giro := CERCHIO.anello(base, cat)
	t.ok(not _accanto(giro, "D", "E"),
			"il quinto resta dov'era: non si allunga la fila (%s)" % str(giro))
	t.ok(_accanto(giro, "A", "B") and _accanto(giro, "B", "C")
			and _accanto(giro, "C", "D"),
			"…e i primi quattro sì")

	# le catenelle DURE passano il tetto, ed è la nota scritta nel sorgente
	var fam := PackedStringArray(["P", "M", "C1", "C2", "C3", "Q"])
	var dura: Array = CERCHIO.catenelle(fam,
			[{"genitori": ["P", "M"], "figli": ["C1", "C2", "C3"]}], [], [], {})
	var max_dura := 0
	for c in dura:
		max_dura = maxi(max_dura, (c as PackedStringArray).size())
	t.eq(max_dura, 5,
			"una famiglia di cinque siede tutta insieme: il tetto è dei "
			+ "ritrovi, non dei legami esclusivi")


## **IL CERCHIO NON SI CHIUDE AD ANELLO.** Tre che si ritrovano a due a due
## chiudono un triangolo nel registro, ma attorno al fuoco si siede in fila: se
## si potessero cucire i due capi della stessa catenella, qualcuno finirebbe
## seduto due volte.
func _non_si_chiude_ad_anello(t) -> void:
	var base := _base(4)
	var rit := {
		"N0": PackedStringArray(["N1", "N2"]),
		"N1": PackedStringArray(["N0", "N2"]),
		"N2": PackedStringArray(["N0", "N1"]),
	}
	var giro := CERCHIO.cerchio(base, [], [], [], rit)
	t.ok(_e_permutazione(giro, base),
			"nessuno siede due volte, nemmeno con un triangolo di ritrovi (%s)"
			% str(giro))
	var cat: Array = CERCHIO.catenelle(base, [], [], [], rit)
	var quanti := 0
	for c in cat:
		quanti += (c as PackedStringArray).size()
	t.eq(quanti, base.size(), "e ogni sedia è di uno solo")

	# ⚠️ E IL TRIANGOLO VA FATTO CON LEGAMI **DURI**, o questo caso è un
	# ritratto. MISURATO: col triangolo di soli ritrovi qui sopra, a rifiutare
	# la terza cucitura non è la guardia dell'anello — è il TETTO
	# (`3 + 3 > CATENELLA_MAX`), che morde per primo. Togliendo `ia == ib` dal
	# sorgente il cerchio restava identico e questo caso restava VERDE: un
	# cancello ne copriva un altro, ed è la famiglia di buchi che questo
	# progetto ha già pagato tre volte. Le coppie passano con `tetto = 0`,
	# quindi qui non c'è più niente che copra.
	var tri := [["N0", "N1"], ["N0", "N2"], ["N1", "N2"]]
	var g2 := CERCHIO.cerchio(_base(3), [], tri, [], {})
	t.ok(_e_permutazione(g2, _base(3)),
			"nemmeno un triangolo di COPPIE chiude l'anello (%s)" % str(g2))
	var cat2: Array = CERCHIO.catenelle(_base(3), [], tri, [], {})
	var q2 := 0
	for c in cat2:
		q2 += (c as PackedStringArray).size()
	t.eq(q2, 3, "e le tre sedie ci sono ancora tutte")


# --------------------------------------------- il posto di chi non c'è più

func _vuoto(chi: String, vicino: String, posto: int, giorno: int,
		giorni: int) -> Dictionary:
	return {"chi": chi, "vicino": vicino, "posto": posto,
			"giorno": giorno, "giorni": giorni}


## **IL VUOTO TIENE IL POSTO.** Chi è partito lascia una sedia, e la sedia
## resta. È la metà che vale di questa meccanica: l'ordinamento è la cornice,
## il posto vuoto è il quadro.
func _il_vuoto_tiene_il_posto(t) -> void:
	var base := _base(5)
	var v := [_vuoto("Papavero", "", 2, 10, 5)]
	var giro := CERCHIO.cerchio(base, [], [], CERCHIO.vuoti_vivi(v, 10), {})
	t.eq(giro.size(), base.size() + 1,
			"il cerchio ha una sedia in più: quella di chi non c'è")
	t.eq(_slot(giro, CERCHIO.chiave_vuoto("Papavero")), 2,
			"e sta dove stava lui")
	t.eq(_slot(giro, "N2"), 3, "chi veniva dopo non ha chiuso la fila")
	t.eq(_slot(giro, "N1"), 1, "e chi veniva prima non si è mosso")


## **IL BUCO SI RICHIUDE DOPO N SERE**, e la richiusura non è un evento: il
## predicato smette di essere vero e basta. Nessuna riga da cancellare, nessuna
## posa da togliere — la stessa grammatica con cui una cricca si scioglie.
##
## E N lo porta la RIGA, scritta quando il vuoto si è aperto leggendo
## `Legami.giorni_di_vuoto`: qui non si ricopia la formula del lutto, o
## sarebbero due orologi per la stessa cosa.
func _il_buco_si_richiude_dopo_N_sere(t) -> void:
	var base := _base(5)
	for giorni in [3, 5, 8]:
		var v := [_vuoto("Papavero", "", 2, 10, giorni)]
		for d in range(0, giorni):
			var giro := CERCHIO.cerchio(base, [], [], CERCHIO.vuoti_vivi(v, 10 + d), {})
			t.eq(giro.size(), base.size() + 1,
					"sera %d di %d: il posto è ancora lì" % [d + 1, giorni])
		var dopo := CERCHIO.cerchio(base, [], [], CERCHIO.vuoti_vivi(v, 10 + giorni), {})
		t.eq(dopo, base,
				"e la sera dopo il cerchio si è richiuso da sé (%d sere)"
				% giorni)
	# una riga che viene dal futuro (orologio indietro, banco) non apre niente
	var f := [_vuoto("Papavero", "", 2, 20, 5)]
	t.eq(CERCHIO.cerchio(base, [], [], CERCHIO.vuoti_vivi(f, 10), {}), base,
			"un vuoto datato domani non apre un buco oggi")


## **IL VICINO RESTA ACCANTO AL VUOTO.** La sedia vuota resta al fianco di chi
## ci stava accanto, ed è tutta la frase: non c'è un cartello, non c'è un
## fiore, non c'è una riga sul filo — c'è che quello con cui parlavi ha ancora
## il tuo posto di fianco.
func _il_vicino_resta_accanto_al_vuoto(t) -> void:
	var base := _base(6)
	var v := [_vuoto("Papavero", "N4", 1, 10, 4)]
	var giro := CERCHIO.cerchio(base, [], [], CERCHIO.vuoti_vivi(v, 11), {})
	t.ok(_accanto(giro, CERCHIO.chiave_vuoto("Papavero"), "N4"),
			"la sedia vuota è rimasta accanto al suo vicino (%s)" % str(giro))
	t.eq(giro.size(), base.size() + 1, "e c'è una sedia in più, non una in meno")


## …**E IL VICINO PUÒ ESSERE SPARITO A SUA VOLTA.** Se chi gli sedeva accanto è
## partito il giorno dopo, quel nome non esiste più. Il fantasma resta
## catenella di uno e torna al posto che teneva: si tollera, non si inventa.
func _il_vicino_del_vuoto_puo_essere_sparito(t) -> void:
	var base := _base(5)
	var v := [_vuoto("Papavero", "Ortica", 3, 10, 4)]
	var giro := CERCHIO.cerchio(base, [], [], CERCHIO.vuoti_vivi(v, 11), {})
	t.eq(giro.size(), base.size() + 1,
			"il vuoto c'è lo stesso, anche senza più nessuno accanto")
	t.eq(_slot(giro, CERCHIO.chiave_vuoto("Papavero")), 3,
			"e tiene il posto che teneva")
	# e nemmeno un vicino vuoto o uguale a sé stesso lo fa sparire
	for cattivo in ["", "Papavero"]:
		var v2 := [_vuoto("Papavero", cattivo, 3, 10, 4)]
		t.eq(CERCHIO.cerchio(base, [], [], CERCHIO.vuoti_vivi(v2, 11), {}).size(),
				base.size() + 1,
				"vicino «%s»: il posto resta comunque" % cattivo)


## **AL MASSIMO DUE VUOTI.** Due sedie vuote in ventotto sono un'assenza;
## cinque sono un villaggio che si sta svuotando — cioè un grafico a barre
## delle partenze, e un cerchio che racconta quanta gente se n'è andata sta
## dicendo al giocatore che ha sbagliato qualcosa.
func _al_massimo_due_vuoti(t) -> void:
	var v := [
		_vuoto("Uno", "", 1, 10, 6),
		_vuoto("Due", "", 2, 11, 6),
		_vuoto("Tre", "", 3, 12, 6),
	]
	var vivi: Array = CERCHIO.vuoti_vivi(v, 13)
	t.eq(vivi.size(), CERCHIO.VUOTI_MAX, "non più di due sedie vuote per sera")
	var nomi := []
	for r in vivi:
		nomi.append(str((r as Dictionary).get("chi", "")))
	t.ok(nomi.has("Tre") and nomi.has("Due"),
			"si tengono i più freschi: i vecchi stavano per richiudersi da sé "
			+ "(%s)" % str(nomi))
	# il pareggio si rompe A MANO, perché sort_custom non è stabile: a parità
	# di giorno tiene il posto il più anziano, che è l'ancora di tutto il file
	var pari := [
		_vuoto("Tardi", "", 9, 11, 6),
		_vuoto("Presto", "", 2, 11, 6),
		_vuoto("Vecchio", "", 5, 10, 6),
	]
	var due: Array = CERCHIO.vuoti_vivi(pari, 12)
	t.eq(str((due[0] as Dictionary).get("chi", "")), "Presto",
			"a parità di sera tiene il posto il più anziano")
	t.eq(str((due[1] as Dictionary).get("chi", "")), "Tardi",
			"…e poi l'altro dello stesso giorno")
	# il cerchio non ne mostra mai più del tetto
	var base := _base(6)
	var giro := CERCHIO.cerchio(base, [], [], CERCHIO.vuoti_vivi(v, 13), {})
	t.eq(giro.size(), base.size() + CERCHIO.VUOTI_MAX,
			"e il cerchio ne mostra due, non tre")


## **UNA PERSONA, UNA SEDIA VUOTA** — anche quando le righe sono due.
##
## `vuoti_vivi` pota per CALENDARIO e non guarda i nomi: due righe per lo stesso
## nome ci passano tutte e due, ed è giusto che ci passino — succede a chi se ne
## va, torna e riparte, e succede a un salvataggio riletto due volte. A non dare
## due sedie alla stessa assenza è `_infila_i_vuoti`, e finché nessuno gliene
## chiedeva due quella riga era spenta: MISURATO, togliendone metà la suite
## restava verde.
##
## Due sedie vuote per una persona sola non sono un errore di conteggio: sono
## **la stessa assenza raccontata due volte**, cioè il buco che smette di essere
## la spaziatura doppia di qualcuno e diventa un vuoto generico nel cerchio.
func _un_fantasma_ha_una_sedia_sola(t) -> void:
	var base := _base(4)
	var doppia := [
		_vuoto("Fiordaliso", "N1", 2, 5, 6),
		_vuoto("Fiordaliso", "N2", 1, 4, 6),      # la stessa persona, due righe
	]
	var vivi: Array = CERCHIO.vuoti_vivi(doppia, 6)
	t.eq(vivi.size(), 2, "le due righe arrivano tutte e due (potare è del calendario)")
	var giro := CERCHIO.cerchio(base, [], [], vivi, {})
	var quante := 0
	for n in giro:
		if str(n) == CERCHIO.chiave_vuoto("Fiordaliso"):
			quante += 1
	t.eq(quante, 1, "ma la sedia vuota è UNA (%s)" % str(giro))
	t.eq(giro.size(), base.size() + 1, "e il cerchio ha una sedia in più, non due")

	# …e l'altra metà della stessa riga: chi è TORNATO non lascia un fantasma.
	# È il caso di un salvataggio in cui la riga del vuoto è sopravvissuta al
	# ritorno: il vivo ha sempre la precedenza sul proprio ricordo.
	var tornato := [_vuoto("N2", "N1", 2, 5, 6)]
	var g2 := CERCHIO.cerchio(base, [], [], CERCHIO.vuoti_vivi(tornato, 6), {})
	t.eq(g2, base, "chi è seduto non ha anche una sedia vuota (%s)" % str(g2))


## **I VUOTI TORNANO A RITROSO**, e questo caso è nato smontando la versione
## precedente, che si chiamava «si infilano dal fondo» e sbagliava.
##
## `posto` è l'indice che quella persona aveva **nell'istante in cui è uscita**,
## e i due `posto` di due fantasmi sono misurati su file DIVERSE. Rimetterli
## dentro è l'inverso di una sequenza di `remove_at`, quindi si applica
## rovesciata: **prima chi è uscito per ultimo**. Ordinare per `posto`
## decrescente — l'idioma con cui si tolgono più elementi da un array, e che
## sembra la cosa giusta — dava il secondo fantasma una sedia più in là.
##
## L'oracolo non è una lista di slot scritta a mano: si SIMULA la sequenza vera
## delle partenze e si confronta la fila che ne esce con quella che il villaggio
## aveva prima. Così il caso non può concordare col codice per costruzione.
func _i_vuoti_tornano_a_ritroso(t) -> void:
	var v := ["A", "B", "C", "D", "E"]
	# la sequenza più comune di tutte: `_tick_partenze` cicla ALL'INDIETRO,
	# quindi due che se ne vanno la stessa sera escono dall'indice alto verso
	# il basso — e per ridisfarle si va dal basso verso l'alto
	t.ok(_ricostruisce(v, [["D", 10], ["B", 10]]),
			"stessa sera, usciti a ritroso: la fila torna quella di prima")
	# e le due sere, nei due ordini possibili
	t.ok(_ricostruisce(v, [["B", 10], ["D", 11]]),
			"due sere, indici crescenti: idem")
	t.ok(_ricostruisce(v, [["D", 10], ["B", 11]]),
			"due sere, indici DECRESCENTI: è il caso su cui «dal fondo» "
			+ "sbagliava")
	t.ok(_ricostruisce(v, [["E", 10], ["A", 11]]),
			"…e anche dai due capi della fila")

	# LA SPAZZATA: ogni sequenza di due e di tre partenze, nei due modelli veri
	# (una per sera / tutte la stessa sera a ritroso). Misurato: con la regola
	# vecchia ne tornavano giuste 65 su 185.
	var sei := ["A", "B", "C", "D", "E", "F"]
	var storti := 0
	var primo := ""
	var quante := 0
	for a in sei:
		for b in sei:
			if b == a:
				continue
			quante += 1
			if not _ricostruisce(sei, [[a, 20], [b, 21]]):
				storti += 1
				if primo == "":
					primo = "%s poi %s, sere diverse" % [a, b]
	for i in sei.size():
		for j in range(i):
			quante += 1
			if not _ricostruisce(sei, [[sei[i], 20], [sei[j], 20]]):
				storti += 1
				if primo == "":
					primo = "%s poi %s, stessa sera" % [sei[i], sei[j]]
	t.eq(storti, 0,
			"su %d sequenze di partenza la fila si ricostruisce sempre (primo "
			% quante + "diverso: «%s»)" % primo)

	# un posto fuori scala non fa saltare niente: si appoggia al bordo
	var base := _base(5)
	var fuori := [_vuoto("Lontano", "", 99, 10, 6), _vuoto("Sotto", "", -4, 10, 6)]
	var g2 := CERCHIO.cerchio(base, [], [], CERCHIO.vuoti_vivi(fuori, 11), {})
	t.eq(g2.size(), base.size() + 2,
			"un posto fuori scala si appoggia al bordo invece di sparire")


## Simula una sequenza di partenze come la fa il villaggio — `remove_at`
## sull'indice del momento, e la riga del vuoto che si porta dietro QUELL'indice
## — e dice se il cerchio di stasera è la fila di prima con le sedie di chi non
## c'è più al loro posto. `uscite` è una lista di `[chi, giorno]`, in ordine di
## partenza.
func _ricostruisce(iniziale: Array, uscite: Array) -> bool:
	var vivi := iniziale.duplicate()
	var vuoti: Array = []
	var stasera := 0
	for u in uscite:
		var chi := str((u as Array)[0])
		var i := vivi.find(chi)
		var quando := int((u as Array)[1])
		stasera = maxi(stasera, quando)
		vivi.remove_at(i)
		# durata larga e orologio fermo alla sera dell'ultima partenza: qui si
		# prova l'ORDINE, e un vuoto che scade a metà spazzata misurerebbe il
		# calendario credendo di misurare le sedie
		vuoti.append(_vuoto(chi, "", i, quando, 900))
	var base := PackedStringArray()
	for n in vivi:
		base.append(str(n))
	var atteso := PackedStringArray()
	for n in iniziale:
		atteso.append(str(n) if vivi.has(n) else CERCHIO.chiave_vuoto(str(n)))
	# tetto alto: qui si prova la RICOSTRUZIONE, non la potatura (che ha il
	# suo caso). Con `VUOTI_MAX` le terne perderebbero un fantasma e questo
	# banco misurerebbe il tetto credendo di misurare l'ordine.
	return CERCHIO.cerchio(base, [], [],
			CERCHIO.vuoti_vivi(vuoti, stasera, 9), {}) == atteso


## **DAL DISCO TORNANO INTERI.** Le righe dei vuoti si salvano, e nel JSON gli
## interi tornano `float`: si rilegge con `int()` e mai con `is int`, che è
## falso proprio per il numero che è appena passato dal disco. È la trappola
## già pagata dal contrassegno `sognato` dei Sogni e dal ledger di `Strati`.
func _dal_disco_tornano_interi(t) -> void:
	var v := [_vuoto("Papavero", "N1", 2, 10, 5)]
	var riletti: Array = CERCHIO.vuoti_letti(JSON.parse_string(JSON.stringify(v)))
	t.eq(riletti.size(), 1, "la riga sopravvive al giro sul disco")
	var r := riletti[0] as Dictionary
	t.eq(typeof(r["posto"]), TYPE_INT, "il posto torna un intero")
	t.eq(typeof(r["giorno"]), TYPE_INT, "il giorno torna un intero")
	t.eq(typeof(r["giorni"]), TYPE_INT, "e la durata pure")
	var base := _base(5)
	t.eq(CERCHIO.cerchio(base, [], [], CERCHIO.vuoti_vivi(riletti, 11), {}),
			CERCHIO.cerchio(base, [], [], CERCHIO.vuoti_vivi(v, 11), {}),
			"e il cerchio riletto dal disco è quello di prima di salvare")

	# le righe malformate si buttano invece di far esplodere una sera
	var sporco: Array = CERCHIO.vuoti_letti([
			{"chi": "", "giorni": 5}, {"giorni": 5}, {"chi": "X", "giorni": 0},
			{"chi": "X", "giorni": -3}, "non un dizionario", 12,
			{"chi": "Buono", "giorni": 4}])
	t.eq(sporco.size(), 1, "delle sette righe sporche ne sopravvive una sola")
	t.eq(str((sporco[0] as Dictionary).get("chi", "")), "Buono",
			"…ed è quella buona")
	t.eq(CERCHIO.vuoti_letti("non un array").size(), 0,
			"e un salvataggio che non è nemmeno una lista non apre nessun buco")


## **UNA RIGA SPORCA NON RUBA UNA SEDIA A UNA PERSONA VERA.** Il tetto dei
## vuoti taglia in coda, quindi una riga senza nome che arrivasse in cima si
## prenderebbe uno dei due posti **senza produrre nessuna sedia**: dal prato non
## si vedrebbe un errore, si vedrebbe che il vuoto di qualcuno non si è mai
## aperto. Per questo `vuoti_vivi` la BUTTA invece di ignorarla dopo.
##
## ⚠️ E la seconda metà è COPERTURA, non una guardia falsificabile, e va detto:
## togliere un `is Dictionary` non fa diventare rosso niente — fa un errore a
## runtime, che in questo runner interrompe la funzione e lascia il verde
## (`suite verde non basta`). Quel che questo caso garantisce è che la strada
## sporca venga PERCORSA, non che il suo cancello sappia arrossire.
func _una_riga_sporca_non_ruba_una_sedia(t) -> void:
	var base := _base(6)
	# la riga senza nome è la più FRESCA, quindi in cima all'ordine: se
	# restasse, si mangerebbe il posto della sedia di Papavero
	var righe := [
		_vuoto("", "", 1, 12, 6),
		_vuoto("Papavero", "", 2, 11, 6),
		_vuoto("Ortica", "", 4, 10, 6),
	]
	var vivi: Array = CERCHIO.vuoti_vivi(righe, 12)
	t.eq(vivi.size(), CERCHIO.VUOTI_MAX,
			"restano due righe, e nessuna delle due è quella senza nome")
	var nomi: Array = []
	for r in vivi:
		nomi.append(str((r as Dictionary).get("chi", "")))
	t.ok(nomi.has("Papavero") and nomi.has("Ortica"),
			"le due sedie sono di chi è partito davvero (%s)" % str(nomi))
	var giro := CERCHIO.cerchio(base, [], [], vivi, {})
	t.eq(giro.size(), base.size() + 2,
			"e sul prato si vedono due sedie vuote, non una")

	# e le righe che non sono nemmeno dizionari attraversano tutto il cammino
	# senza portarsi via la sera
	var lurido := [12, "non un dizionario", _vuoto("Papavero", "N3", 2, 11, 6),
			null, {"vicino": "N3"}]
	var g2 := CERCHIO.cerchio(base, [], [], CERCHIO.vuoti_vivi(lurido, 12), {})
	t.eq(g2.size(), base.size() + 1,
			"delle cinque righe luride passa solo quella buona (%s)" % str(g2))
	t.eq(_slot(g2, CERCHIO.chiave_vuoto("Papavero")), 2,
			"…e sta dove stava lui")


# ----------------------------------------------- la geometria vera del falò

## I POSTI NON SI PESTANO NEANCHE COI VUOTI. `test_filo` ne controlla
## ventotto — il tetto dei residenti — ma coi fantasmi si arriva a trenta, e
## quel caso non li vedrebbe mai.
##
## ⚠️ Il numero non si riscrive qui: si chiede a `_posto_al_falo`, che è e resta
## la sola casa della geometria del falò.
func _i_posti_non_si_pestano_neanche_coi_vuoti(t) -> void:
	var v = VISITORS.new()
	var quanti: int = int(VISITORS.MAX_RESIDENTS) + CERCHIO.VUOTI_MAX
	var punti: Array = []
	for i in quanti:
		punti.append(v._posto_al_falo(i))
	var minima := 1e9
	var vicini := 0
	for i in punti.size():
		for j in range(i + 1, punti.size()):
			var d: float = (punti[i] as Vector3).distance_to(punti[j])
			minima = minf(minima, d)
			if d < 0.55:
				vicini += 1
	v.free()
	t.eq(vicini, 0,
			"al falò nessuno siede in braccio a un altro, nemmeno con le due "
			+ "sedie vuote (%d posti, la più stretta a %.4f m)"
			% [quanti, minima])


## **IL VUOTO È UNA SPAZIATURA DOPPIA**, e non lo dice nessuno: è la
## REGOLARITÀ a rendere visibile l'eccezione. In una fila dove tutte le
## distanze sono uguali, una distanza che non lo è si vede.
##
## ⚠️ Il numero da confrontare **non è una distanza in metri**: il passo del
## falò cambia con l'anello (0.9233 / 1.3849 / 1.8465 m), quindi una soglia
## scritta a mano fallirebbe su un codice sano appena il villaggio supera gli
## undici. La cosa costante è il RAPPORTO fra la corda del salto e il passo,
## `sin(0.55)/sin(0.275) = 2·cos(0.275) = 1.9249`, e si confronta dentro lo
## stesso anello.
func _il_vuoto_e_una_spaziatura_doppia(t) -> void:
	var v = VISITORS.new()
	var atteso := 2.0 * cos(0.275)
	for anello in 3:
		var i: int = anello * 11 + 2
		var passo: float = (v._posto_al_falo(i) as Vector3) \
				.distance_to(v._posto_al_falo(i + 1))
		var salto: float = (v._posto_al_falo(i) as Vector3) \
				.distance_to(v._posto_al_falo(i + 2))
		t.almost(salto / passo, atteso,
				"anello %d: saltare una sedia è una spaziatura doppia" % anello,
				0.0005)

	# e il cerchio la produce davvero: i due vivi che stavano accanto a chi è
	# partito si ritrovano a DUE sedie di distanza, non a una
	var base := _base(6)
	var vuoti := [_vuoto("Papavero", "", 3, 10, 4)]
	var con := CERCHIO.cerchio(base, [], [], CERCHIO.vuoti_vivi(vuoti, 11), {})
	var senza := CERCHIO.cerchio(base, [], [], CERCHIO.vuoti_vivi(vuoti, 14), {})
	t.eq(absi(_slot(senza, "N2") - _slot(senza, "N3")), 1,
			"a buco chiuso i due vicini distano una sedia")
	t.eq(absi(_slot(con, "N2") - _slot(con, "N3")), 2,
			"a buco aperto ne distano due")
	var d_con: float = (v._posto_al_falo(_slot(con, "N2")) as Vector3) \
			.distance_to(v._posto_al_falo(_slot(con, "N3")))
	var d_senza: float = (v._posto_al_falo(_slot(senza, "N2")) as Vector3) \
			.distance_to(v._posto_al_falo(_slot(senza, "N3")))
	t.almost(d_con / d_senza, atteso,
			"e sul prato la distanza fra loro è quasi il doppio "
			+ "(%.4f m contro %.4f)" % [d_con, d_senza], 0.0005)
	v.free()


# ------------------------------------------------------------------ il genere

## ⚜️ **IL CERCHIO NON SCRIVE NIENTE**, e questo è un firewall, non una
## cortesia. Se potesse toccare i registri che legge, la sera fabbricherebbe i
## ritrovi che la sera dopo rilegge: le catenelle diventerebbero clique per
## costruzione `(i, i+1, i+2)` che passano OGNI collaudo. È la forma esatta del
## guasto che `Affetti.GESTI` ha già chiuso togliendo la voce `falo`.
##
## Qui si prova la metà che questo file può garantire: **non tocca nemmeno gli
## argomenti che riceve.** L'altra metà — che nessuno chiami `registra` o
## `ricorda` dal falò — è del cablatore.
func _il_cerchio_non_scrive_niente(t) -> void:
	var base := _base(6)
	var fam := [{"genitori": ["N0", "N4"], "figli": ["N2"]}]
	var cop := [["N1", "N5"]]
	var vuoti := [_vuoto("Papavero", "N3", 2, 10, 4)]
	var rit := {"N3": PackedStringArray(["N5"])}
	var copia_base := base.duplicate()
	var copia_fam := fam.duplicate(true)
	var copia_cop := cop.duplicate(true)
	var copia_vuoti := vuoti.duplicate(true)
	var copia_rit := rit.duplicate(true)
	for _giro in 3:
		CERCHIO.cerchio(base, fam, cop, CERCHIO.vuoti_vivi(vuoti, 11), rit)
	t.eq(base, copia_base, "la base esce come è entrata")
	t.eq(str(fam), str(copia_fam), "il registro delle famiglie non si tocca")
	t.eq(str(cop), str(copia_cop), "quello delle coppie nemmeno")
	t.eq(str(vuoti), str(copia_vuoti), "e le righe dei vuoti restano quelle")
	t.eq(str(rit), str(copia_rit),
			"i ritrovi si LEGGONO: se il falò potesse scriverli, si "
			+ "fabbricherebbe da solo le catenelle che poi legge")


## ⚜️ **NESSUNO LO NOMINA.** Da qui non esce una sola parola destinata a chi
## gioca: il cerchio è un elenco di nomi che c'erano già più una chiave che non
## è un nome e non può essere scambiata per uno. Zero stringhe nuove, quindi
## zero voci in `locale/en/`, per costruzione — e `test_localizzazione` non
## cambia di un'asserzione.
func _nessuno_lo_nomina(t) -> void:
	var base := _base(5)
	var vuoti := [_vuoto("Papavero", "N1", 2, 10, 4)]
	var giro := CERCHIO.cerchio(base, [], [["N0", "N3"]], [],
			{"N1": PackedStringArray(["N4"])})
	for n in giro:
		t.ok(base.find(str(n)) >= 0,
				"nel cerchio non compare niente che non fosse già un nome "
				+ "del villaggio (%s)" % str(n))
	var con := CERCHIO.cerchio(base, [], [], CERCHIO.vuoti_vivi(vuoti, 11), {})
	var estranei := 0
	for n in con:
		if base.find(str(n)) < 0 and str(n) != CERCHIO.chiave_vuoto("Papavero"):
			estranei += 1
	t.eq(estranei, 0, "…e col vuoto, niente oltre alla chiave del vuoto")

	# la chiave non è leggibile, e non può attraversare un confine: `"\n"` è
	# lo stesso separatore di `Cricche.chiave`, quindi un fantasma finito là
	# dentro verrebbe scartato in SILENZIO
	t.ok(CERCHIO.e_un_vuoto(CERCHIO.chiave_vuoto("Papavero")),
			"la chiave di un vuoto si riconosce")
	for n in base:
		t.ok(not CERCHIO.e_un_vuoto(str(n)),
				"e nessun nome vero può essere scambiato per un vuoto (%s)" % n)
	t.ok(CERCHIO.chiave_vuoto("Papavero").begins_with("\n"),
			"comincia con un a-capo: nessun nome del gioco ne contiene uno")


# ═══════════════════════════════════════════ IL CABLAGGIO, e prima non c'era
#
# ⚠️ MISURATO il 2026-09-06, subito dopo aver cablato M2: guastando UNA PER
# VOLTA le tre righe che portano il cerchio nel gioco — lo slot che torna
# sempre l'ordine di trasloco, il vuoto che non si apre più, i vuoti che non
# si salvano più — questo file restava **169 verdi su 169, tutte e tre le
# volte**. L'intero collegamento si poteva cancellare senza che una sola
# asserzione se ne accorgesse: i casi qui sopra chiamano `CERCHIO.cerchio()`
# direttamente, cioè provano l'aritmetica e non il gioco.
#
# È la forma di guasto che questo progetto ha già pagato sette volte. Da qui
# in giù si passa da `Visitors`.


## L'orologio del villaggio. ⚠️ Dev'essere un `Node3D`: `Visitors._daynight` è
## tipizzato, e un `set()` col tipo sbagliato **non assegna e non dice
## niente** (la lezione di `test_deriva`).
class Orologio extends Node3D:
	var day := 10
	var time := 0.50      # pieno giorno: `_phase()` dice "day"


## Il registro dei vicini VERO, col solo `_ready` scavalcato: quello di
## produzione vuole `%Player` e `../BuildSystem`, cioè il villaggio intero.
## `_componi_il_cerchio`, `_slot_di` e `_apri_un_vuoto` restano il codice che
## gira in partita — qui non si sostituisce nessuna decisione.
class Registro extends "res://scenes/npc/Visitors.gd":
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
		_build_ui()


## Il Filo Rosso VERO. ⚠️ E non un doppio con dentro `clampi(3 + n / 6, 3, 8)`
## ricopiato: `giorni_di_vuoto` è proprio la formula che si sta provando, e un
## doppio che la reimplementa la lascia senza lettori — è il difetto del
## `MotoreFinto` della Fase 5, dove il finto faceva la cosa GIUSTA che il vero
## non faceva, e nessun test poteva vederlo.
class Filo extends "res://scenes/world/Legami.gd":
	func _ready() -> void:
		add_to_group("legami")


## Chi sta in coppia. Un lookup, non una decisione.
class Coppie extends Node:
	var loro: Array = []
	func _ready() -> void:
		add_to_group("affetti")
	func coppie_di_oggi() -> Array:
		return loro


## Toglie dai gruppi i registri lasciati dai casi precedenti: il runner libera
## i nodi messi in scena a fine FILE, non a fine caso, e `_componi_il_cerchio`
## chiede `get_first_node_in_group`. Senza, si interrogherebbe il registro di
## un ALTRO caso e la guardia diventerebbe un ritratto.
func _sgombra(t) -> void:
	for g in ["legami", "affetti", "cricche"]:
		for vecchio in t.tree().get_nodes_in_group(g):
			vecchio.remove_from_group(g)


func _registro(t, quanti: int):
	var vis = t.stage(Registro.new())
	# ⚠️ l'orologio si crea TIPIZZATO e poi si mette in scena: `t.stage` torna
	# un valore non tipizzato, e `var oro := t.stage(...)` non compila.
	var oro := Orologio.new()
	t.stage(oro)
	vis._daynight = oro
	for i in quanti:
		vis._residents.append({"dna": {"name": "N%d" % i}, "label": "N%d" % i,
				"cell": Vector2i(i, 0), "species": "chibi"})
	return vis


## ⚜️ IL CERCHIO ARRIVA AI CORPI. Due che stanno in coppia si siedono
## ACCANTO, e l'intero che il corpo riceve è il posto nel cerchio — non più
## l'indice di trasloco.
func _il_cerchio_arriva_ai_corpi(t) -> void:
	_sgombra(t)
	var vis = _registro(t, 5)
	var aff = t.stage(Coppie.new())
	aff.loro = [["N0", "N3"]]
	vis._componi_il_cerchio()
	var giro: PackedStringArray = vis.debug_cerchio()
	t.eq(giro.size(), 5, "il cerchio ha tutti e cinque")
	t.eq(absi(giro.find("N0") - giro.find("N3")), 1,
			"chi sta in coppia si siede ACCANTO (%s)" % str(giro))
	# …e lo slot che arriva al corpo è quello del CERCHIO, non l'indice
	t.eq(vis._slot_di(vis._residents[3], 3), giro.find("N3"),
			"il corpo riceve il posto nel cerchio, non l'ordine di trasloco")
	t.ok(vis._slot_di(vis._residents[3], 3) != 3,
			"…e i due numeri sono davvero diversi, o questa guardia non direbbe niente")


## IL DEGRADO: senza registri, il falò di sempre — e ogni corpo riceve
## esattamente l'indice che riceveva ieri.
func _senza_registri_il_cablaggio_e_il_falo_di_sempre(t) -> void:
	_sgombra(t)
	var vis = _registro(t, 5)
	vis._componi_il_cerchio()
	for i in 5:
		t.eq(vis._slot_di(vis._residents[i], i), i,
				"senza registri il posto è quello di sempre (%d)" % i)


## ⚜️ IL VUOTO SI APRE **PRIMA** DELLA RIMOZIONE, e si prova sull'ORDINE.
##
## Dopo `remove_at` l'indice non è più il suo posto e la riga `r` è già
## uscita: chiamarlo dopo scriverebbe il vicino SBAGLIATO, e non si vedrebbe
## mai — è per questo che la guardia guarda `vicino` e non `posto`, che
## sarebbe giusto in tutti e due i casi.
func _il_vuoto_si_apre_prima_della_rimozione(t) -> void:
	_sgombra(t)
	var vis = _registro(t, 5)
	t.stage(Filo.new())
	var r: Dictionary = vis._residents[2]
	var animo = ANIMO.new()
	animo.setup({"name": "N2", "seed": 7, "sogno": "boscaiolo", "tratti": {}})
	vis._congeda(2, r, animo)
	t.eq(vis._vuoti.size(), 1, "chi parte lascia un vuoto")
	if vis._vuoti.is_empty():
		return
	var v: Dictionary = vis._vuoti[0]
	t.eq(str(v.get("chi", "")), "N2", "ed è il suo")
	t.eq(int(v.get("posto", -1)), 2, "nel posto che aveva")
	t.eq(str(v.get("vicino", "")), "N3",
			"e il vicino è quello di PRIMA della rimozione (dopo sarebbe N4)")
	t.ok(int(v.get("giorni", 0)) >= 3,
			"il vuoto dura quanto dice il filo (%d sere)" % int(v.get("giorni", 0)))


## ⚠️ I VUOTI SOPRAVVIVONO AL SALVATAGGIO. Senza, chiudere e riaprire
## richiude il buco: la metà che vale si spegnerebbe in silenzio, e solo per
## chi RIAPRE — cioè per tutti tranne chi comincia adesso.
func _i_vuoti_sopravvivono_al_salvataggio(t) -> void:
	_sgombra(t)
	var vis = _registro(t, 4)
	vis._vuoti = [_vuoto("Papavero", "N1", 2, 9, 5)]
	var salvato: Dictionary = vis.save_extra()
	# il giro dal DISCO: il JSON riporta gli interi come float
	var dal_disco: Dictionary = JSON.parse_string(JSON.stringify(salvato))
	var vis2 = _registro(t, 4)
	vis2.load_extra(dal_disco)
	t.eq(vis2._vuoti.size(), 1, "il vuoto ha attraversato il salvataggio")
	if vis2._vuoti.is_empty():
		return
	t.eq(str(vis2._vuoti[0].get("chi", "")), "Papavero", "…ed è ancora suo")
	t.eq(int(vis2._vuoti[0].get("posto", -1)), 2, "…e nel suo posto")
	# e da lì il cerchio lo rimette in scena
	vis2._daynight.day = 10
	vis2._componi_il_cerchio()
	var giro: PackedStringArray = vis2.debug_cerchio()
	t.eq(giro.size(), 5, "il fantasma tiene il posto anche dopo il caricamento")


## ⚠️ E QUALCUNO LO COMPONE DAVVERO, LA SERA. Le guardie qui sopra provano che
## il cerchio — **una volta composto** — arriva ai corpi, tiene il posto di
## chi non c'è più e sopravvive al salvataggio. Non provano che esista la riga
## che lo compone: MISURATO, togliendo le due righe dal fronte di fase di
## `_routine` restavano tutte e tre verdi. È lo stesso buco, un piano più su.
func _la_sera_il_cerchio_si_compone(t) -> void:
	_sgombra(t)
	var vis = _registro(t, 5)
	var aff = t.stage(Coppie.new())
	aff.loro = [["N0", "N3"]]
	vis._daynight.time = 0.50          # pieno giorno: non è la sera di nessuno
	vis._routine(0.016)
	t.eq(vis.debug_cerchio().size(), 0,
			"di giorno non si compone niente: il cerchio è una cosa della sera")
	vis._daynight.time = 0.70          # la fascia del falò
	vis._routine(0.016)
	var giro: PackedStringArray = vis.debug_cerchio()
	t.eq(giro.size(), 5,
			"ALLA SERA IL CERCHIO SI COMPONE, e a comporlo è il giro della routine")
	if giro.size() == 5:
		t.eq(absi(giro.find("N0") - giro.find("N3")), 1,
				"…e i due che stanno in coppia si ritrovano accanto")
	# e UNA VOLTA SOLA: il secondo giro della stessa sera non ricompone niente
	var prima := str(giro)
	vis._routine(0.016)
	t.eq(str(vis.debug_cerchio()), prima,
			"…e si compone una volta per sera, non a ogni fotogramma")
