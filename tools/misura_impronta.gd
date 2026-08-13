extends SceneTree

## IL METRO DELL'IMPRONTA — quanto costa sapere che il modello è quello giusto.
##
## Dal 2026-08-13 il gioco spedisce il suo modello (gemma-3-4b Q4_K_M, 2,4 GB)
## dentro il pacchetto, e con lui si accende l'impronta: `Llm.IMPRONTA_SPEDITO`
## è lo SHA-256 di quei byte, e `Traduttore::_carica` rifiuta il file che non
## combacia. È l'unica difesa contro il residuo dichiarato in `llm_gguf.h` —
## un bit girato dentro i pesi non lo vede né il portiere né llama, e gli
## iperparametri hanno invarianti che finiscono in `abort()`, cioè nel gioco
## del giocatore che sparisce.
##
## Ma una difesa che costa una lettura di due gigabyte e mezzo non si accende
## a occhio: si misura. Questo banco risponde alle quattro domande che nessuna
## asserzione booleana sa dare, e ognuna ha cambiato il codice:
##
##  1. **QUANTO COSTA**, e a quale priorità. Il gioco fa girare il thread del
##     traduttore alla priorità di fondo (`Pensieri.PRIORITA = 2`), e su macOS
##     quella QoS **strozza anche l'I/O**: non è un dettaglio, è un fattore
##     tre. Misurare l'impronta a priorità normale e chiamarla «undici
##     secondi» sarebbe una misura di un gioco che non esiste.
##  2. **CHI LA PAGA.** L'ordine dei cancelli in `_carica` è FORMA → TETTO →
##     RISERVA → IMPRONTA, e prima del 2026-08-13 l'impronta stava per prima:
##     su una macchina che il modello non l'avrebbe aperto mai, il no arrivava
##     dopo trentasette secondi di lettura, a ogni avvio, per niente. Qui il
##     rifiuto si forza (riserva enorme) così il numero è dell'ORDINE e non
##     della RAM che questa macchina ha oggi.
##  3. **SI PUÒ MOLLARE?** `Traduttore::chiudi()` fa `_thread.join()`. Senza
##     una via d'uscita, chi torna al titolo mentre l'impronta si calcola
##     aspetterebbe fino a trentasette secondi con lo schermo fermo — cioè
##     riaprirebbe da un'altra porta il guasto che le «tre uscite» della Fase 5
##     hanno chiuso (40 s → 6 ms).
##  4. **E DOVE STA IL MODELLO**, secondo `Llm.gd`: i tre candidati, in ordine,
##     e quale di loro ha l'impronta armata.
##
## ⚠️ **GUARDA IL CARICO DELLA MACCHINA PRIMA DI CREDERE A QUESTI NUMERI.**
## Il banco lo stampa da solo. Con altre sessioni addosso una lettura da 2,4 GB
## balla di parecchi secondi: sono pavimenti, non misure pulite.
##
## ⚠️ **UN'APERTURA PER PROCESSO, E NON È UNA PIGRIZIA DEL BANCO.**
## `Traduttore::apri()` si chiama **una volta sola in tutta la vita del
## processo** (`if (_thread.joinable() || _fermati) return false`), e
## `chiudi()` non la riabilita: la spegne per sempre, anche su un traduttore
## che non ha mai avuto un thread. È giusto così — il modello è una risorsa
## del processo, e riaprire due gigabyte e mezzo a ogni cambio di scena
## sarebbe la cura peggiore della malattia — ma vuol dire che le scene che
## APRONO vanno in tre corse diverse. La prima stesura le metteva in fila e
## la seconda scena stampava «apri_modello: false» misurando il niente.
##
##     CHIBI_MODELLO=<file.gguf> Godot --headless --path . \
##         --script res://tools/misura_impronta.gd
##     ... CHIBI_SCENA=molla ...      # chiudere mentre l'impronta legge
##     ... CHIBI_SCENA=apre  ...      # l'impronta GIUSTA non impedisce nulla
##     ... CHIBI_SCENA=falsa ...      # e quella sbagliata ferma tutto
##
## Le due scene che non aprono niente (dove sta il modello, quanto costa)
## girano sempre, in tutte e quattro le corse.
##
## `apre` vuole abbastanza RAM libera per tenere il modello, o si misura lo
## swap del sistema invece del nostro codice: su una macchina piccola si dia
## un modello piccolo, che la scena usa **l'impronta del file che riceve** e
## non quella del modello spedito.

const LLM := preload("res://systems/Llm.gd")

## Quanto si legge davvero prima di chiudere di colpo, nella scena del
## «si può mollare?». Mezzo secondo di lettura vera basta e avanza: se la
## via d'uscita non ci fosse, da lì mancherebbero ancora trentasei secondi.
const LETTURA_PRIMA_DI_CHIUDERE := 800

var _llm: Object = null
var _percorso := ""
var _scene: Array[Callable] = []
var _in_corso := -1
var _attesa: Callable = Callable()


func _init() -> void:
	_percorso = OS.get_environment("CHIBI_MODELLO")
	if _percorso == "":
		_percorso = LLM.percorso_modello()
	print("\n══════════════════════════════════════════════════════════════")
	print("  IL METRO DELL'IMPRONTA")
	print("══════════════════════════════════════════════════════════════")
	print("carico della macchina: %s" % _carico())
	if not LLM.disponibile():
		print("\nquesto binario non ha llama.cpp dentro (llm=no):")
		print("nessuna impronta da misurare, e il gioco è identico.")
		print("  scons platform=macos arch=universal target=template_debug llm=yes -j8")
		quit(0)
		return
	if _percorso == "" or not FileAccess.file_exists(_percorso):
		print("\nnessun modello: CHIBI_MODELLO=<file.gguf>")
		quit(1)
		return
	_llm = LLM.apri()
	print("llama.cpp %s" % str(_llm.versione()))
	var m: Dictionary = _llm.memoria()
	print("memoria: %d MB in tutto · %d MB liberi adesso"
			% [int(m.get("totale_sistema", 0)) / 1048576,
			int(m.get("libera_sistema", 0)) / 1048576])
	print("modello: %s (%.2f GB)" % [_percorso, _byte(_percorso) / 1073741824.0])

	_scene = [_dove_sta, _quanto_costa]
	var quale := OS.get_environment("CHIBI_SCENA")
	match quale:
		"molla":
			_scene.append(_si_molla)
		"apre":
			_scene.append(_si_ripaga)
		"falsa":
			_scene.append(_impronta_falsa)
		_:
			_scene.append(_chi_la_paga)
	process_frame.connect(_giro_di_frame)
	_avanti()


# =========================================================================
# 4. DOVE STA IL MODELLO (la scena più corta, e la prima: se questa è
#    sbagliata tutte le altre misurano un file che il gioco non aprirà)
# =========================================================================

func _dove_sta() -> void:
	_titolo("DOVE STA IL MODELLO — i tre candidati di Llm.percorso_modello()")
	print("  1. CHIBI_MODELLO       %s" % _o_niente(OS.get_environment("CHIBI_MODELLO")))
	var suo := LLM.CARTELLA_MODELLI.path_join(LLM.NOME_MODELLO)
	print("  2. %-20s %s" % [LLM.CARTELLA_MODELLI,
			_o_niente(ProjectSettings.globalize_path(suo) if FileAccess.file_exists(suo) else "")])
	print("  3. spedito             %s" % _o_niente(LLM.percorso_spedito()))
	print("")
	print("  scelto:   %s" % _o_niente(LLM.percorso_modello()))
	print("  impronta: %s" % _o_niente(LLM.impronta_attesa(LLM.percorso_modello())))
	print("  attesa per il modello spedito: %s" % LLM.IMPRONTA_SPEDITO)
	print("\n  ⚠️ nell'editor il candidato 3 è vuoto per costruzione:")
	print("     `get_executable_path()` è il binario di Godot, e lì il")
	print("     modello non c'è. Si vede solo in un gioco esportato.")
	_avanti()


# =========================================================================
# 1. QUANTO COSTA, e a quale priorità
# =========================================================================

func _quanto_costa() -> void:
	_titolo("QUANTO COSTA — il portiere, e poi l'impronta")
	var t0 := Time.get_ticks_msec()
	var f: Dictionary = _llm.esamina(_percorso, false)
	var t_forma := Time.get_ticks_msec() - t0
	print("  la FORMA (il portiere, senza impronta): %d ms" % t_forma)
	print("     ok=%s · %s · %s · vocabolario %d · stima a 2048 gettoni %d MB"
			% [str(f.get("ok")), str(f.get("architettura")), str(f.get("quantizzazione")),
			int(f.get("vocabolario", 0)), int(f.get("byte_stimati_2k", 0)) / 1048576])
	var t1 := Time.get_ticks_msec()
	var imp := str(_llm.impronta(_percorso))
	var t_imp := Time.get_ticks_msec() - t1
	var mbs := (_byte(_percorso) / 1048576.0) / maxf(t_imp / 1000.0, 0.001)
	print("  l'IMPRONTA (a priorità NORMALE, questo thread): %d ms — %.0f MB/s"
			% [t_imp, mbs])
	print("     %s" % imp)
	print("     combacia con Llm.IMPRONTA_SPEDITO: %s"
			% ("SÌ" if imp == LLM.IMPRONTA_SPEDITO else "no (è un altro modello)"))
	print("  cioè l'impronta costa %d volte il portiere." % roundi(float(t_imp) / maxf(t_forma, 1)))
	print("\n  ⚠️ e in partita costa DI PIÙ: il thread del traduttore gira alla")
	print("     priorità di fondo (Pensieri.PRIORITA = 2), che su macOS")
	print("     strozza anche l'I/O. Il numero vero è la scena dopo.")
	_avanti()


# =========================================================================
# 2. CHI LA PAGA — l'ordine dei cancelli
# =========================================================================

func _chi_la_paga() -> void:
	_titolo("CHI LA PAGA — l'ordine dei cancelli, a rifiuto FORZATO")
	# La riserva si prende UN GIGA SOPRA quella che la macchina ha libera
	# adesso: così il no arriva di sicuro, su qualunque macchina, e il tempo
	# misurato è quello dell'ORDINE dei cancelli — non della RAM che c'è oggi
	# qui. (Un numero assurdo fisso funzionerebbe uguale e stamperebbe una
	# diagnosi da un milione di megabyte: si misura lo stesso e si legge peggio.)
	var m: Dictionary = _llm.memoria()
	var riserva := int(m.get("libera_sistema", 0)) + 1073741824
	print("  riserva forzata a %d MB (un giga sopra quella libera adesso):" % (riserva / 1048576))
	print("  il no è garantito, e il tempo è quello dell'ordine dei cancelli.")
	print("")
	_apri_e_cronometra("con impronta armata, priorità 2 (quella del gioco)",
			{"n_ctx": 2048, "priorita": 2, "riserva_byte": riserva,
			"impronta": LLM.IMPRONTA_SPEDITO},
			func(ms: int, _st: int, diagnosi: String) -> void:
				print("     → %d ms · %s" % [ms, diagnosi])
				print("")
				print("     ⚠️ PRIMA DEL 2026-08-13 questo numero era 37431 ms:")
				print("        l'impronta stava davanti al tetto e alla riserva, e")
				print("        chi il modello non l'avrebbe aperto mai leggeva")
				print("        comunque due gigabyte e mezzo a ogni avvio.")
				_avanti())


# =========================================================================
# 3. SI PUÒ MOLLARE? — il cambio di scena mentre l'impronta gira
# =========================================================================

func _si_molla() -> void:
	_titolo("SI PUÒ MOLLARE? — chiudere mentre l'impronta legge")
	print("  `chiudi()` fa `_thread.join()`. Se l'impronta non si potesse")
	print("  mollare, chi torna al titolo aspetterebbe la fine della lettura.")
	print("")
	# riserva 0: si vuole ARRIVARE all'impronta, non essere respinti prima.
	var ok: bool = _llm.apri_modello(_percorso, {
		"n_ctx": 2048, "priorita": 2, "riserva_byte": 0, "tetto_byte": 0,
		"impronta": LLM.IMPRONTA_SPEDITO})
	print("  apri_modello: %s" % str(ok))
	if not ok:
		print("  → non si è aperto: niente da mollare")
		_avanti()
		return
	# ⚠️ SI ASPETTA UN TEMPO VERO, non un numero di fotogrammi: headless i
	# fotogrammi volano, e trenta giri sono trenta millisecondi — il thread
	# non avrebbe ancora cominciato a leggere e si misurerebbe un `join()`
	# su un thread fermo, cioè la cosa sbagliata che sembra la cosa giusta.
	var t_via := Time.get_ticks_msec()
	_attesa = func() -> void:
		if Time.get_ticks_msec() - t_via < LETTURA_PRIMA_DI_CHIUDERE:
			return
		_attesa = Callable()
		print("  stato all'istante della chiusura: %d (1 = CARICA)" % int(_llm.stato()))
		var t0 := Time.get_ticks_usec()
		_llm.chiudi()
		var ms := float(Time.get_ticks_usec() - t0) / 1000.0
		print("  chiudi() a impronta iniziata: **%.1f ms**" % ms)
		print("  stato dopo: %d (0 = spento)" % int(_llm.stato()))
		print("")
		print("  ⚠️ senza la via d'uscita in `impronta_file` questo numero")
		print("     sarebbe il tempo che manca alla fine della lettura —")
		print("     fino a trentasette secondi di schermo fermo.")
		_avanti()


# =========================================================================
# 5. SI RIPAGA? — la lettura scalda la cache che llama poi mappa
# =========================================================================

func _si_ripaga() -> void:
	_titolo("L'IMPRONTA GIUSTA APRE — il modello si carica DAVVERO")
	print("  è la scena più lenta, e l'unica che carica i pesi. Prova la cosa")
	print("  che tutte le altre danno per scontata: **un'impronta armata e")
	print("  giusta non impedisce al modello di aprirsi.** Una difesa che")
	print("  rifiuta anche il file buono non è una difesa, è un interruttore.")
	print("  ⚠️ vuole RAM libera per tenere il modello, o si misura lo swap.")
	print("")
	var vera := str(_llm.impronta(_percorso))
	print("  impronta di QUESTO file: %s" % vera)
	_apri_e_cronometra("con la sua impronta, priorità 2, senza tetto né riserva",
			{"n_ctx": 2048, "priorita": 2, "riserva_byte": 0, "tetto_byte": 0,
			"impronta": vera},
			func(ms: int, st: int, d: String) -> void:
				print("     → %d ms · stato %d (2 = PRONTO) %s" % [ms, st, d])
				var m: Dictionary = _llm.memoria()
				print("     memoria del processo: impronta %d MB"
						% (int(m.get("impronta", 0)) / 1048576))
				_avanti())


## E IL CONTRARIO: un'impronta che non combacia deve fermare tutto PRIMA che
## llama apra qualcosa. È il caso per cui questa fase esiste — un `.gguf`
## sostituito, o un bit girato dentro i pesi, che né il portiere né llama
## vedono.
func _impronta_falsa() -> void:
	_titolo("L'IMPRONTA SBAGLIATA FERMA TUTTO — e lo dice")
	print("  si arma un'impronta che non è quella del file. Il modello non")
	print("  deve aprirsi, e il motivo dev'essere il SUO — non un no qualunque.")
	print("")
	_apri_e_cronometra("con un'impronta inventata",
			{"n_ctx": 2048, "priorita": 2, "riserva_byte": 0, "tetto_byte": 0,
			"impronta": "0000000000000000000000000000000000000000000000000000000000000000"},
			func(ms: int, st: int, d: String) -> void:
				print("     → %d ms · stato %d (4 = GUASTO)" % [ms, st])
				print("     «%s»" % d)
				print("     il no è quello dell'impronta: %s"
						% ("SÌ" if d.contains("impronta") else "NO ⚠️"))
				_avanti())


# =========================================================================
# la meccanica
# =========================================================================

func _apri_e_cronometra(che: String, opz: Dictionary, poi: Callable) -> void:
	print("  %s" % che)
	var t0 := Time.get_ticks_msec()
	var ok: bool = _llm.apri_modello(_percorso, opz)
	if not ok:
		print("     → rifiutato subito (il file non c'è?)")
		poi.call(0, 4, "")
		return
	_attesa = func() -> void:
		var st := int(_llm.stato())
		if st == 1:
			return
		_attesa = Callable()
		var ms := Time.get_ticks_msec() - t0
		poi.call(ms, st, str((_llm.call("misure") as Dictionary).get("diagnosi", "")))


## ⚠️ `process_frame`, NON un `_process` sovrascritto sul `SceneTree`. La
## prima stesura sovrascriveva `MainLoop._process` e il banco si è piantato
## per sempre alla terza scena: quel virtuale non arriva a uno script
## `--script`, l'attesa non veniva mai interrogata e il processo restava lì.
## È l'idioma di tutti gli altri banchi di questo progetto, e c'è una ragione.
func _giro_di_frame() -> void:
	if _attesa.is_valid():
		_attesa.call()


func _avanti() -> void:
	_in_corso += 1
	if _in_corso >= _scene.size():
		print("\n══════════════════════════════════════════════════════════════")
		print("carico alla fine: %s" % _carico())
		print("")
		quit(0)
		return
	_scene[_in_corso].call()


func _titolo(s: String) -> void:
	print("\n──────────────────────────────────────────────────────────────")
	print("  %s" % s)
	print("──────────────────────────────────────────────────────────────")


func _byte(p: String) -> float:
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return 0.0
	var n := float(f.get_length())
	f.close()
	return n


func _o_niente(s: String) -> String:
	return s if s != "" else "—"


func _carico() -> String:
	var out := []
	var _e := OS.execute("/usr/bin/uptime", [], out, false)
	if out.is_empty():
		return "(non lo so)"
	return str(out[0]).strip_edges()
