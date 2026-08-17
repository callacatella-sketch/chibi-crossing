extends RefCounted
## IL RITMO DEI PENSIERI — e ogni caso è stato FALSIFICATO guastando la riga
## che sorveglia (l'elenco dei guasti provati sta accanto a ogni funzione).
##
## Niente modello, niente thread, niente GDExtension: il `Pensatoio` prende
## il motore dall'esterno, e qui gliene si dà uno FINTO che risponde a
## comando. È la stessa ragione per cui `Suggeritore` è puro — una guardia
## che nessun test può far diventare rossa, in questo progetto, è già stata
## tre volte una guardia che non c'era.
##
## ⚠️ IL FINTO NON È UNA SEMPLIFICAZIONE DEL VERO: risponde alle stesse
## quattro domande (`libero`, `accoda`, `raccogli`, `annulla`) con la stessa
## disciplina (biglietto crescente, 0 = rifiutato, `{}` = niente da ritirare).
## Un finto che semplifica il dato è come nasce un test che passa per il
## motivo sbagliato — è già successo in questo progetto, con la fixture dei
## Legami che «normalizzava» il nome e rendeva il difetto invisibile.
##
## ⚠️⚠️ E UN DOPPIO PUÒ ANCHE MENTIRE AL CONTRARIO — È SUCCESSO QUI, ED È
## COSTATO IL VILLAGGIO MUTO PER SEMPRE.
##
## `MotoreFinto.annulla()` faceva `occupato = false`, sempre: cioè
## IMPLEMENTAVA IL COMPORTAMENTO GIUSTO CHE IL C++ NON AVEVA. Nel motore vero
## `accoda()` accendeva `_in_volo` e a spegnerlo c'era un posto solo — la fine
## di un lavoro ESEGUITO; un `annulla()` arrivato prima che il thread avesse
## preso la richiesta (una finestra vera: mediana 27 µs a macchina scarica,
## punte di 117 ms a macchina carica) buttava il lavoro e lasciava il motore
## occupato PER SEMPRE. Nessun test poteva vederlo, perché il doppio era più
## corretto dell'originale.
##
## Adesso il finto sa la cosa che il vero sa: **un lavoro può essere ancora in
## coda o già in mano al thread**, e `annulla()` si comporta diversamente nei
## due casi (`prende()` / `molla()` qui sotto). Un doppio che mente è peggio di
## nessun doppio: nessun doppio ti fa scrivere un test vero, un doppio che
## mente ti fa credere di averlo già scritto.

const PENSATOIO := preload("res://scenes/npc/Pensatoio.gd")
const LLM := preload("res://systems/Llm.gd")


## IL MOTORE FINTO. Conta tutto quello che gli si chiede, così i test possono
## pretendere non solo che una cosa succeda, ma che le altre NON succedano.
class MotoreFinto extends RefCounted:
	var pronto := true
	var occupato := false
	## ⚠️ «IL LAVORO È GIÀ IN MANO A CHI SCRIVE», che nel motore vero è
	## `_preso`: la richiesta è stata tolta dalla coda e llama ci sta dentro.
	## Fra `accoda()` e questo istante passa una finestra vera, ed è lì che il
	## villaggio ammutoliva (vedi la nota in cima).
	var preso := false
	var biglietto := 0
	var accodate: Array = []
	var annullamenti := 0
	var _pronti: Array = []

	func libero() -> bool:
		return pronto and not occupato

	func accoda(chi: int, sistema: String, utente: String, gramm: String,
			opz: Dictionary) -> int:
		if not libero() or gramm == "" or utente == "":
			return 0
		biglietto += 1
		occupato = true
		preso = false   # è IN CODA: chi scrive non l'ha ancora visto
		accodate.append({"chi": chi, "sistema": sistema, "utente": utente,
				"gramm": gramm, "opz": opz, "biglietto": biglietto})
		return biglietto

	func raccogli() -> Dictionary:
		if _pronti.is_empty():
			return {}
		return _pronti.pop_front()

	## ⚠️ E QUI IL FINTO SMETTE DI MENTIRE. I due rami sono quelli veri:
	##  · il lavoro è ancora in coda → sparisce, e il motore torna LIBERO
	##    subito (misurato sul vero: 0 ms);
	##  · il lavoro è già in mano a chi scrive → il motore resta OCCUPATO
	##    finché non molla (misurato sul vero: 1–35 ms, perché
	##    `abort_callback` ferma `llama_decode` a metà di un gettone).
	## Prima c'era solo il primo ramo, per tutti e due i casi: il doppio
	## garantiva una cosa che il motore non faceva.
	func annulla() -> void:
		annullamenti += 1
		_pronti.clear()
		if not preso:
			occupato = false

	## Chi scrive prende il lavoro: da qui in poi un `annulla()` non libera
	## niente all'istante. È l'evento che nel vero apre la finestra.
	func prende() -> void:
		preso = true

	## E lo molla (fine di una generazione abbandonata): il motore torna
	## libero senza consegnare niente.
	func molla() -> void:
		preso = false
		occupato = false

	## Il motore finisce: mette un esito da ritirare e (di norma) torna libero.
	##
	## ⚠️ `libera = false` serve al caso del biglietto ESTRANEO: un esito di
	## un altro giro può arrivare mentre il lavoro NOSTRO è ancora in corso, e
	## in quel caso il motore NON è libero. Farlo tornare libero sarebbe un
	## finto che mente — direbbe «ho finito» di un lavoro che sta ancora
	## facendo — e metterebbe alla prova la rete del pensiero perso invece
	## della guardia del biglietto. È la stessa lezione della fixture dei
	## Legami che «normalizzava» il nome: un finto che semplifica il dato
	## sposta il test su un'altra domanda, e nessuno se ne accorge.
	func finisci(b: int, bozze: PackedStringArray, libera := true) -> void:
		if libera:
			occupato = false
			preso = false
		_pronti.append({"biglietto": b, "chi": 1, "bozze": bozze,
				"secondi_prompt": 0.5, "secondi_generazione": 2.0,
				"token_prompt": 700, "token_generati": 60, "errore": ""})


func run(t) -> void:
	_uno_alla_volta(t)
	_il_biglietto_si_controlla(t)
	_svuota_non_consegna_piu(t)
	_annulla_mentre_il_motore_ha_gia_preso(t)
	_il_pensatoio_morendo_butta_il_volo(t)
	_il_giro_e_un_giro_non_una_classifica(t)
	_il_muto_va_a_riposo(t)
	_la_ripresa_e_un_pavimento(t)
	_un_pensiero_perso_non_zittisce_il_villaggio(t)
	_senza_motore_non_succede_niente(t)
	_il_foglio_si_scrive_alla_partenza(t)
	_l_attesa_si_calcola(t)
	_il_thread_non_puo_toccare_il_mondo(t)
	_il_ponte_se_c_e(t)


# =========================================================================

func _banco(candidati: Array, foglio: Callable) -> Array:
	var m := MotoreFinto.new()
	var p = PENSATOIO.new()
	var consegne := []
	p.collega(m, func(): return candidati, foglio,
			func(c, b, f): consegne.append({"c": c, "b": b, "f": f}))
	return [p, m, consegne]


func _cand(n: int) -> Array:
	var out := []
	for k in n:
		out.append({"chi": 100 + k, "id": "vicino%d" % k})
	return out


func _pieno(_c) -> Dictionary:
	return {"sistema": "sei il Gufo", "utente": "LE FRASI", "grammatica": "root ::= \"a\"",
			"seme": 7}


## UNO ALLA VOLTA, IN TUTTO IL VILLAGGIO. Finché un pensiero è in volo non se
## ne chiede un altro — e non perché il motore lo rifiuti (quello è il
## secondo guardiano), ma perché il Pensatoio non lo chiede proprio: costruire
## un foglio per poi buttarlo è il costo che questa riga esiste per non pagare.
##
## FALSIFICATO togliendo `if _biglietto != 0: return` da `passo()`: il conto
## delle accodate sale a 5 (una per giro) invece di 1.
func _uno_alla_volta(t) -> void:
	var b := _banco(_cand(4), _pieno)
	var p = b[0]
	var m = b[1]
	for _i in 5:
		p.passo(1.0)
	t.eq(m.accodate.size(), 1, "un pensiero alla volta: una sola accodata in cinque giri")
	t.eq(int(m.biglietto), 1, "e un solo biglietto")


## IL BIGLIETTO SI CONTROLLA SEMPRE. Un esito che porta un numero diverso da
## quello che stiamo aspettando non si consegna: in mezzo può esserci stato un
## cambio di scena, un salvataggio ricaricato, un vicino partito. È la stessa
## disciplina dell'handle dentro un ricordo — «un'etichetta assente, mai un
## comportamento sbagliato».
##
## FALSIFICATO togliendo `b != _biglietto` dalla condizione di scarto in
## `_ritira()`: la consegna arriva lo stesso e il test diventa rosso.
func _il_biglietto_si_controlla(t) -> void:
	var b := _banco(_cand(3), _pieno)
	var p = b[0]
	var m = b[1]
	var consegne: Array = b[2]
	p.passo(1.0)
	t.eq(m.accodate.size(), 1, "è partito un pensiero")
	# arriva un esito con un biglietto di un altro giro, MENTRE il nostro è
	# ancora in corso (il motore resta occupato: vedi la nota su `finisci`)
	m.finisci(999, PackedStringArray(["una riga.\nuna citazione.\naltra riga."]), false)
	p.passo(1.0)
	t.eq(consegne.size(), 0, "un biglietto che non è il nostro non si consegna")
	t.eq(int(p.misure()["buttati"]), 1, "e si conta fra i buttati")
	t.ok(bool(p.misure()["in_volo"]), "e il NOSTRO resta in volo: non è il suo esito")
	# e adesso quello giusto
	m.finisci(1, PackedStringArray(["una riga.\nuna citazione.\naltra riga."]))
	p.passo(1.0)
	t.eq(consegne.size(), 1, "il biglietto giusto invece si consegna")


## SVUOTA() BUTTA IL VOLO. Dopo un cambio di scena nessun esito ha più un
## destinatario: uno che arrivasse sarebbe un pensiero di un altro mondo
## addosso a qualcuno che non l'ha pensato.
##
## FALSIFICATO non azzerando `_biglietto` in `svuota()`: l'esito in arrivo
## trova ancora il suo numero e viene consegnato.
func _svuota_non_consegna_piu(t) -> void:
	var b := _banco(_cand(3), _pieno)
	var p = b[0]
	var m = b[1]
	var consegne: Array = b[2]
	p.passo(1.0)
	var bg: int = int(m.accodate[0]["biglietto"])
	p.svuota()
	t.eq(int(m.annullamenti), 1, "svuota() lo dice anche al motore")
	m.finisci(bg, PackedStringArray(["tardi.\ntardi.\ntardi."]))
	p.passo(1.0)
	t.eq(consegne.size(), 0, "quello che arriva dopo svuota() non si consegna")


## SI PUÒ ANNULLARE ANCHE MENTRE CHI SCRIVE HA GIÀ IL LAVORO IN MANO, e in
## quel caso il motore NON torna libero all'istante: resta occupato per il
## tempo che gli serve a mollare (misurato sul vero: 1–35 ms, perché
## `abort_callback` ferma `llama_decode` a metà di un gettone).
##
## È il caso che il doppio non sapeva raccontare — diceva sempre «annulla e
## sono libero» — e finché lo diceva, questa riga del Pensatoio non era
## provata da nessuno: **si aspetta, e appena il motore è libero si ricomincia
## a pensare**. Un cambio di scena non deve lasciare il villaggio muto né
## fargli chiedere un pensiero a un motore che sta ancora mollando il
## precedente.
##
## FALSIFICATO togliendo `butta_il_volo(_motore)` da `svuota()`: il conto
## degli annullamenti resta 0 e due asserzioni diventano rosse.
##
## ⚠️ E UNA FALSIFICAZIONE CHE NON HA FUNZIONATO, scritta qui perché è più
## utile di una che funziona: togliendo `if not bool(_motore.call("libero")):
## return` da `passo()` la prima stesura di questo caso restava VERDE. Il
## Pensatoio chiedeva a un motore occupato, il finto rifiutava, e alla fine il
## conto delle accodate tornava lo stesso. Quella riga però un prezzo ce
## l'ha, e si vede da altre due parti: **si costruisce un foglio per buttarlo**
## (è il costo che il ritmo esiste per non pagare) e **qualcuno perde il suo
## turno**, perché il cursore avanza comunque. Le due asserzioni in fondo
## guardano quelle, e con la riga tolta diventano rosse tutte e due.
func _annulla_mentre_il_motore_ha_gia_preso(t) -> void:
	var fogli := [0]
	var foglio := func(c):
		fogli[0] += 1
		return _pieno(c)
	var b := _banco(_cand(3), foglio)
	var p = b[0]
	var m = b[1]
	var consegne: Array = b[2]
	p.passo(1.0)
	t.eq(m.accodate.size(), 1, "è partito un pensiero")
	m.prende()   # chi scrive l'ha tolto dalla coda: da qui è dentro llama
	p.svuota()   # il cambio di scena
	t.eq(int(m.annullamenti), 1, "svuota() lo dice al motore")
	t.ok(not bool(m.libero()),
			"e il motore resta occupato finché non molla (il doppio non mente più)")
	p.passo(1.0)
	t.eq(m.accodate.size(), 1, "a un motore che sta mollando non si chiede niente")
	t.eq(fogli[0], 1, "e non gli si costruisce nemmeno il foglio (invece: %d)" % fogli[0])
	m.molla()    # il thread se ne accorge dentro llama e lascia lì
	p.passo(PENSATOIO.RIPRESA)
	t.eq(m.accodate.size(), 2, "appena è libero, il villaggio torna a pensare")
	t.eq(int(m.accodate[1]["chi"]), 101,
			"e tocca a chi era di turno: nessuno perde il giro perché il motore era occupato")
	t.eq(consegne.size(), 0, "e la generazione abbandonata non consegna niente")


## IL PENSATOIO, MORENDO, SI PORTA DIETRO IL LAVORO IN VOLO — ed è l'uscita
## che mancava (`NOTIFICATION_PREDELETE`).
##
## Un pensiero dura secondi; in quei secondi il giocatore torna al titolo o
## ricarica la partita. Chi ospitava il ritmo se ne va, e prima NON SUCCEDEVA
## NIENTE: misurato con `tools/prova_uscita.gd` su un modello vero, il thread
## continuava a scrivere per quaranta secondi — fino in fondo — mentre il
## gioco caricava un'altra scena. La documentazione dava per esistente un
## `Pensatoio._exit_tree` che non può esistere: questo è un `RefCounted`, non
## sta nell'albero.
##
## ⚠️ E QUESTO CASO SORVEGLIA ANCHE LA TRAPPOLA DI GODOT che c'è sotto: dentro
## `NOTIFICATION_PREDELETE` i PROPRI metodi non si possono chiamare («in base
## 'null instance'», misurato su 4.7.1). La prima stesura chiamava `svuota()`
## e non annullava niente, lasciando solo un `SCRIPT ERROR` — che in questo
## runner non fa fallire nulla. Se qualcuno riportasse il gesto dentro un
## metodo d'istanza, il conto degli annullamenti torna a zero e questo caso
## diventa rosso.
##
## FALSIFICATO togliendo `_notification()` da `Pensatoio.gd` (annullamenti
## resta 0), e rimettendoci dentro `svuota()` al posto della statica (idem).
func _il_pensatoio_morendo_butta_il_volo(t) -> void:
	var m := MotoreFinto.new()
	var p = PENSATOIO.new()
	p.collega(m, func(): return _cand(2), _pieno, func(_c, _b, _f): pass)
	p.passo(1.0)
	t.eq(m.accodate.size(), 1, "c'è un pensiero in volo")
	t.eq(int(m.annullamenti), 0, "e nessuno ha ancora annullato niente")
	p = null   # il cambio di scena: chi lo teneva se ne va
	t.eq(int(m.annullamenti), 1,
			"morendo, il Pensatoio dice al motore di lasciar perdere (invece: %d)"
					% int(m.annullamenti))


## IL GIRO È UN GIRO, NON UNA CLASSIFICA. Tutti passano una volta prima che
## qualcuno passi due. Ordinare i vicini per «quanto sono interessanti»
## sarebbe la classifica visibile che questo gioco si è già vietato una volta
## (`Affetti`, regola 2), e uscirebbe come «i soliti tre parlano sempre».
##
## FALSIFICATO fissando `var i := 0` in `_prova_a_chiedere()`: il primo
## vicino riceve tutti e quattro i pensieri.
func _il_giro_e_un_giro_non_una_classifica(t) -> void:
	var b := _banco(_cand(4), _pieno)
	var p = b[0]
	var m = b[1]
	var visti := {}
	for k in 4:
		p.passo(1.0)
		if m.accodate.size() > k:
			visti[int(m.accodate[k]["chi"])] = true
		m.finisci(k + 1, PackedStringArray(["a.\nb.\nc."]))
		p.passo(1.0)
	t.eq(visti.size(), 4, "in quattro giri hanno parlato quattro vicini diversi (invece: %d)"
			% visti.size())


## CHI NON HA NIENTE DI VERO DA DIRE VA A RIPOSO. Il silenzio è il
## comportamento normale; ma senza il riposo il cursore tornerebbe da lui al
## giro dopo, e il villaggio spenderebbe la giornata a costruire ritratti
## vuoti — che è il costo che il ritmo esiste per non pagare.
##
## FALSIFICATO togliendo `_riposo[id] = RIPOSO` dal ramo `f.is_empty()`: con
## due candidati muti su tre il conto dei tentativi muti esplode.
func _il_muto_va_a_riposo(t) -> void:
	# il primo tace, gli altri due parlano
	var foglio := func(c):
		return {} if str((c as Dictionary)["id"]) == "vicino0" else _pieno(c)
	var b := _banco(_cand(3), foglio)
	var p = b[0]
	var m = b[1]
	for k in 6:
		p.passo(1.0)
		if m.accodate.size() > 0 and not m.occupato:
			pass
		m.finisci(m.biglietto, PackedStringArray(["a.\nb.\nc."]))
		p.passo(1.0)
	t.eq(int(p.misure()["muti"]), 1,
			"il muto si prova UNA volta e poi riposa (invece: %d)" % int(p.misure()["muti"]))


## LA RIPRESA È UN PAVIMENTO. Due generazioni non si toccano nemmeno sulla
## macchina più veloce del mondo: mezzo secondo è lo spazio in cui il sistema
## si riprende i core che ggml ha appena mollato.
##
## FALSIFICATO togliendo `if _da_ultimo < RIPRESA: return`: la seconda
## accodata parte nello stesso istante della prima consegna.
func _la_ripresa_e_un_pavimento(t) -> void:
	var b := _banco(_cand(4), _pieno)
	var p = b[0]
	var m = b[1]
	p.passo(1.0)
	t.eq(m.accodate.size(), 1, "il primo parte")
	m.finisci(1, PackedStringArray(["a.\nb.\nc."]))
	# passi piccolissimi: in tutto 0.2 s, sotto la ripresa
	for _i in 20:
		p.passo(0.01)
	t.eq(m.accodate.size(), 1, "sotto la ripresa non ne parte un altro")
	p.passo(PENSATOIO.RIPRESA)
	t.eq(m.accodate.size(), 2, "passata la ripresa, sì")


## UN PENSIERO PERSO NON ZITTISCE IL VILLAGGIO — ed è il guasto più grave che
## questo file abbia avuto, perché non lascia traccia di sé.
##
## Aspettare il proprio biglietto è giusto; ma se l'esito non arriva MAI (un
## errore del motore, un annullamento venuto da fuori, una generazione finita
## mentre nessuno guardava) `_biglietto` resta acceso e da quel momento non si
## chiede più niente. Nessun errore, nessun avviso: il villaggio smette di
## pensare, per sempre, dopo un incidente solo.
##
## Il motore che si dichiara LIBERO mentre noi stiamo ancora aspettando vuol
## dire esattamente questo: lui ha finito, noi non abbiamo visto niente.
##
## FALSIFICATO togliendo la rete da `passo()` (il ramo `if bool(_motore.call(
## "libero"))` dentro `if _biglietto != 0`): il conto delle accodate resta a 1
## per sempre, e questo caso diventa rosso.
func _un_pensiero_perso_non_zittisce_il_villaggio(t) -> void:
	var b := _banco(_cand(4), _pieno)
	var p = b[0]
	var m = b[1]
	p.passo(1.0)
	t.eq(m.accodate.size(), 1, "il primo pensiero parte")
	# il motore finisce e torna libero, ma non lascia NIENTE da ritirare:
	# è esattamente quello che fa quando un esito viene scartato
	m.occupato = false
	p.passo(1.0)
	t.eq(int(p.misure()["persi"]), 1, "il pensiero perso viene notato")
	t.ok(not bool(p.misure()["in_volo"]), "e non si resta appesi ad aspettarlo")
	p.passo(PENSATOIO.RIPRESA)
	t.eq(m.accodate.size(), 2, "il villaggio torna a pensare")


## SENZA MOTORE NON SUCCEDE NIENTE, e non è un guasto: è la configurazione
## normale del gioco (chi non ha il modello ha un gioco meno sorprendente,
## non un gioco a cui manca un pezzo). Nessun errore, nessun avviso, nessuna
## chiamata: `passo()` torna e basta.
##
## ⚠️ Questo caso non fallirebbe da solo se `passo()` esplodesse: un errore a
## runtime NON fa fallire un test in questo runner, interrompe la funzione in
## silenzio. Quello che lo rende utile è l'asserzione DOPO, che non verrebbe
## mai eseguita — più il conteggio degli `SCRIPT ERROR`, che deve dare zero.
func _senza_motore_non_succede_niente(t) -> void:
	var p = PENSATOIO.new()
	p.passo(1.0)
	p.svuota()
	p.passo(10.0)
	t.eq(int(p.misure()["consegnati"]), 0, "senza motore non si consegna niente")
	t.ok(not bool(p.misure()["in_volo"]), "e non c'è niente in volo")


## IL FOGLIO SI SCRIVE ALLA PARTENZA, NON ALL'ISCRIZIONE. È la regola 1, e si
## vede da qui: il foglio viene chiesto UNA volta per generazione, non una per
## candidato. Se la coda portasse fogli già scritti, in un villaggio da
## ventotto ce ne sarebbero ventotto in giro, e l'ultimo racconterebbe un
## vicino di due minuti prima.
##
## FALSIFICATO facendo costruire il foglio a tutti i candidati dentro
## `_prova_a_chiedere()`: il contatore sale a 4 al primo giro.
func _il_foglio_si_scrive_alla_partenza(t) -> void:
	var quanti := [0]
	var foglio := func(c):
		quanti[0] += 1
		return _pieno(c)
	var b := _banco(_cand(28), foglio)
	var p = b[0]
	p.passo(1.0)
	t.eq(quanti[0], 1, "un foglio per generazione, non uno per abitante (invece: %d)" % quanti[0])


## L'attesa fra due pensieri dello stesso vicino è un CONTO, non una
## costante: lega la cadenza al numero di abitanti e alla velocità della
## macchina. Il pavimento è il riposo — un villaggio di tre vicini non li fa
## pensare a raffica.
func _l_attesa_si_calcola(t) -> void:
	t.almost(PENSATOIO.attesa_stimata(28, 30.0), 840.0,
			"28 vicini a 30 s l'uno fanno 840 s di giro", 0.01)
	t.almost(PENSATOIO.attesa_stimata(3, 30.0), PENSATOIO.RIPOSO,
			"in tre, comanda il riposo e non il giro", 0.01)
	t.eq(PENSATOIO.attesa_stimata(0, 30.0), 0.0, "senza vicini non si aspetta niente")


## IL THREAD NON PUÒ TOCCARE IL MONDO — e la guardia sta nel TIPO, non nella
## buona volontà.
##
## Il traduttore gira mentre `EcsMondo::avanza()` scrive nel registro sessanta
## volte al secondo. Se il thread potesse leggere il grafo dei ricordi, le
## tinte o un componente, sarebbe una corsa contro il frame — e una corsa che
## si manifesta una volta ogni diecimila partite, mai in prova.
##
## Non c'è nessun lucchetto a difenderlo, e non serve: **nella coda entrano
## byte**. Un `std::string` non ha un puntatore al registro, non ha un handle
## di entità, non ha un `Node`. Perché il difetto rientrasse, qualcuno
## dovrebbe prima includere `ecs_mondo.h` (o EnTT, o godot-cpp) dentro il
## file del thread — e questo caso è lì per rendere quel gesto rosso invece
## che invisibile. È lo stesso idioma con cui `test_llm_terreno` tiene chiuso
## il confine di `llama.h`.
##
## FALSIFICATO aggiungendo `#include "ecs_mondo.h"` a `llm_pensieri.h`.
func _il_thread_non_puo_toccare_il_mondo(t) -> void:
	# ⚠️ SI CERCA UN `#include`, NON UNA MENZIONE — e questa riga è nata da un
	# falso allarme mio: la prima stesura cercava la stringa «ecs_mondo.h» e
	# diventava rossa per un COMMENTO che spiegava perché quell'include non
	# c'è. Un test che non distingue il codice dalla prosa che lo descrive
	# costringe chi verrà a togliere le spiegazioni per far passare la suite,
	# che è esattamente il contrario di quello che serve a questo progetto.
	var vietati := ["ecs_mondo.h", "ecs_entt.h", "entt.hpp", "grafo_ricordi.h",
			"sistema_occ.h", "godot_cpp/", "ecs_componenti.h"]
	for f in ["res://src/llm_pensieri.h", "res://src/llm_pensieri.cpp"]:
		var testo := FileAccess.get_file_as_string(f)
		t.ok(testo.length() > 0, "%s si legge" % f)
		for riga in testo.split("\n"):
			var r := str(riga).strip_edges()
			if not r.begins_with("#include"):
				continue
			for v in vietati:
				t.ok(not r.contains(v),
						"%s: il thread non può includere «%s» (riga: %s)" % [f, v, r])


## IL PONTE, SE C'È. Gira solo nel binario con `llm=yes`; senza, tace — che è
## esattamente il punto della Fase 5. Prova le tre porte di `accoda()` (senza
## grammatica no, senza testo no, senza modello no) e che `raccogli()` a vuoto
## non costi e non esploda.
func _il_ponte_se_c_e(t) -> void:
	if not LLM.disponibile():
		return
	var cuore := LLM.apri()
	t.ok(cuore != null, "il ponte si apre")
	# NESSUN MODELLO APERTO: è lo stato di partenza, e in quello stato non si
	# accetta lavoro. Una coda che si riempie mentre il modello non c'è è una
	# coda di pensieri vecchi che arrivano tutti insieme.
	t.eq(int(cuore.stato()), 0, "senza `apri_modello` il traduttore è spento")
	t.ok(not cuore.libero(), "e spento non è libero")
	t.eq(int(cuore.accoda(1, "s", "u", "root ::= \"a\"", {})), 0,
			"spento, `accoda` rifiuta")
	t.ok((cuore.raccogli() as Dictionary).is_empty(),
			"e `raccogli` a vuoto torna un dizionario vuoto")
	# un percorso che non esiste NON è un guasto: è chi non ha il modello
	t.ok(not cuore.apri_modello("/non/esiste/mai.gguf", {}),
			"un modello che non c'è si rifiuta senza rumore")
	t.eq(int(cuore.stato()), 0, "e lo stato resta spento (non 'guasto')")
	# ANNULLARE A VUOTO NON DEVE ROMPERE NIENTE, ed è il caso NORMALE: si
	# cambia scena mentre il villaggio non stava pensando. Questa chiamata,
	# sul motore vero, passa dal ramo «nessuno ha in mano niente» —
	# quello che spegne `_in_volo` invece di aspettare un thread che non
	# arriverà mai.
	cuore.annulla()
	t.eq(int(cuore.stato()), 0, "annullare a vuoto non cambia lo stato")
	t.eq(int(cuore.accoda(1, "s", "u", "root ::= \"a\"", {})), 0,
			"e dopo un annulla a vuoto il motore è quello di prima")

	_il_tetto_e_la_macchina(t, cuore)

	# `chiudi()` su un traduttore mai acceso deve tornare, non appendersi
	cuore.chiudi()
	t.ok(true, "chiudi() su un traduttore spento torna")


## IL TETTO DELL'AUTORE E LA RAM DELLA MACCHINA — le due metà del cancello.
##
## Il tetto è **3 GB dal 2026-08-12** (erano 2, e sotto i 2 ci stava solo un
## modello da un miliardo di parametri: col 1B ventuno lettere su ventiquattro
## erano rotte). È una decisione dell'AUTORE, e sta scritta in un posto solo —
## `chibi::Config::tetto_byte` — che `limiti()` racconta: prima era ricopiato
## a mano dentro `tools/sonda_llm.gd`, e i due numeri erano già diversi.
##
## E il tetto da solo non basta: dice quanto costa il modello, non se quei
## byte ci sono. Su una macchina piena un modello che sta nel tetto è comunque
## il motivo per cui il gioco comincia a singhiozzare, e il giocatore non ha
## modo di collegare le due cose. Per questo il ponte sa dire quanta RAM ha la
## macchina — e questo caso pretende che il numero esista e sia sano.
##
## FALSIFICATO: riportando `tetto_byte` a 2 GB (la prima asserzione diventa
## rossa), mettendo `riserva_byte = 0` di serie (la seconda), e facendo
## tornare 0 a `memoria_libera_sistema()` (le ultime due).
func _il_tetto_e_la_macchina(t, cuore) -> void:
	var lim: Dictionary = cuore.limiti()
	t.eq(int(lim["tetto_byte"]), 3 * 1024 * 1024 * 1024,
			"il tetto dell'autore è 3 GB (invece: %d MB)" % (int(lim["tetto_byte"]) / 1048576))
	t.ok(int(lim["riserva_byte"]) > 0,
			"e alla macchina deve restare qualcosa: la riserva non è zero")
	var mem: Dictionary = cuore.memoria()
	var totale := int(mem["totale_sistema"])
	var libera := int(mem["libera_sistema"])
	# Zero vorrebbe dire «questa piattaforma non lo sa dire»: la suite gira su
	# macOS (e in CI anche su Linux col job `test-llm`), e tutte e due lo sanno.
	t.ok(totale > 0, "la macchina sa dire quanta RAM ha in tutto (invece: %d)" % totale)
	t.ok(libera > 0 and libera <= totale,
			"e quanta ne ha libera adesso, che non può essere più del totale (%d su %d)"
					% [libera, totale])
