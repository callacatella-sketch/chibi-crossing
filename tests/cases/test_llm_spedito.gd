extends RefCounted
## IL MODELLO CHE SPEDIAMO — dove sta, chi lo scavalca, e chi lo verifica.
##
## Dal 2026-08-13 il gioco viaggia con dentro il suo modello (gemma-3-4b
## Q4_K_M, 2,4 GB), e con lui arrivano tre cose che prima non c'erano: un
## terzo posto in cui cercarlo, un'impronta SHA-256 che dice se è ancora
## quello collaudato, e una casella nel pannello per spegnerlo.
##
## ────────────────────────────────────────────────────────────────────────
## PERCHÉ QUESTO FILE ESISTE, E COSA NON PUÒ FARE
## ────────────────────────────────────────────────────────────────────────
##
## Tutte e tre le cose vivono in posti che un banco non può toccare: il
## modello sta dentro il pacchetto di un gioco ESPORTATO (e piantarne uno
## dentro il bundle di Godot per provare vorrebbe dire romperne la firma),
## pesa due gigabyte e mezzo (in CI non c'è, e non ci sarà mai), e la casella
## compare solo a chi ce l'ha.
##
## La risposta non è rinunciare: è **prendere a parte le regole**, che sono
## tre righe pure, e interrogarle con i percorsi delle tre piattaforme.
##  · `Llm.spedito_accanto_a(exe)` — la mappa eseguibile → modello. È l'unica
##    riga di questa fase che decide qualcosa su **Windows**, e da un Mac non
##    si può verificare in nessun altro modo.
##  · `Llm.il_primo_che_c_e(a, b, c)` — l'ordine dei tre candidati.
##  · `Llm.impronta_attesa(percorso)` — su QUALE dei tre si arma l'impronta.
##
## E il resto si prova dove sta: il verso della leva su `Settings` vero, e la
## riga del pannello costruendo il pannello VERO e cercandoci dentro
## l'etichetta.
##
## ⚠️ **COSA QUESTO FILE NON PROVA, ed è scritto qui per non dimenticarlo:**
##  1. che `Llm.IMPRONTA_SPEDITO` sia davvero lo SHA-256 del file spedito.
##     Per saperlo bisogna avere il file: qui si controlla solo che abbia la
##     FORMA di uno SHA-256 (una costante troncata o con una lettera
##     maiuscola spegnerebbe la funzione per tutti, in silenzio). La verifica
##     vera è `tools/misura_impronta.gd`, che legge il file e confronta.
##  2. l'ORDINE DEI CANCELLI dentro `Traduttore::_carica` (forma → tetto →
##     riserva → impronta). `Traduttore::apri()` si può chiamare **una volta
##     sola per processo**, e quel gettone è già speso da
##     `test_llm_portiere._il_carico_vero_passa_dal_portiere`. La guardia di
##     quell'ordine è la misura: 37431 ms prima, 490 ms dopo.

const LLM := preload("res://systems/Llm.gd")
const PANNELLO := preload("res://scenes/ui/CozySettingsPanel.gd")
const PENSIERI := preload("res://scenes/npc/Pensieri.gd")
## Il file delle preferenze si chiede a chi lo scrive, non si ricopia: è la
## stessa regola delle fonti uniche, e un percorso ricopiato qui resterebbe
## verde su un gioco che salva altrove.
const SETTINGS := preload("res://systems/Settings.gd")

## Un file vero da usare come esca per i candidati 1 e 2. Non è un modello e
## non deve esserlo: qui si prova **quale percorso viene scelto**, non cosa
## c'è dentro (quello è il mestiere del portiere, e ha il suo file).
const ESCA_UTENTE := "user://modelli/pensieri.gguf"
const ESCA_FUORI := "user://esca_chibi_modello.gguf"


func run(t) -> void:
	_dove_finisce_nel_pacchetto(t)
	_l_ordine_dei_tre_candidati(t)
	_i_due_candidati_veri(t)
	_l_impronta_e_di_un_percorso_solo(t)
	_l_impronta_ha_la_forma_giusta(t)
	_la_leva_del_giocatore(t)
	_la_riga_del_pannello(t)


# =========================================================================
# 1. DOVE FINISCE IL MODELLO DENTRO IL PACCHETTO
# =========================================================================

## ⚠️ LA RIGA DI macOS È QUELLA CHE VALE IL PREZZO DI QUESTO CASO.
## L'eseguibile di un gioco Godot esportato sta in `<gioco>.app/Contents/
## MacOS/`, e un file di dati lì dentro non ci può stare: `codesign` sigilla
## il bundle, e tutto ciò che finisce fuori da `Contents/Resources/` diventa
## «unsealed contents» — una firma che non verifica e una notarizzazione che
## non passa (RELEASE_SIGNING.md). Il guasto non si vedrebbe provando il
## gioco: si vedrebbe il giorno della release, in CI, su una macchina che
## nessuno può interrogare.
##
## FALSIFICATO: mettendo `MacOS` al posto di `Resources` (2 asserzioni
## rosse), togliendo del tutto il ramo del bundle (2), e togliendo la guardia
## sulla stringa vuota (1).
func _dove_finisce_nel_pacchetto(t) -> void:
	t.eq(LLM.spedito_accanto_a("/Applicazioni/ChibiCrossing.app/Contents/MacOS/ChibiCrossing"),
			"/Applicazioni/ChibiCrossing.app/Contents/Resources/pensieri.gguf",
			"macOS: il modello sta in Contents/Resources, o codesign non sigilla il bundle")
	t.ok(not LLM.spedito_accanto_a(
			"/Applicazioni/ChibiCrossing.app/Contents/MacOS/ChibiCrossing").contains("/MacOS/"),
			"macOS: e NON accanto all'eseguibile (sarebbe «unsealed contents»)")

	# Windows e Linux: accanto all'eseguibile, e basta.
	t.eq(LLM.spedito_accanto_a("C:/Giochi/ChibiCrossing/ChibiCrossing.exe"),
			"C:/Giochi/ChibiCrossing/pensieri.gguf",
			"Windows: accanto al .exe")
	t.eq(LLM.spedito_accanto_a("/opt/chibi/ChibiCrossing"),
			"/opt/chibi/pensieri.gguf",
			"Linux: accanto all'eseguibile")

	# Un percorso che finisce per «MacOS» ma non è un bundle non deve
	# ingannare la regola: il pezzo che conta è `/Contents/MacOS`.
	t.eq(LLM.spedito_accanto_a("/giochi/MacOS/ChibiCrossing"),
			"/giochi/MacOS/pensieri.gguf",
			"una cartella che si chiama MacOS non è un bundle")

	t.eq(LLM.spedito_accanto_a(""), "",
			"senza eseguibile non c'è nessun posto (e non un percorso monco)")

	# E il nome del file è UNO, non una scansione della cartella: un `.gguf`
	# qualunque trovato per caso è il modo in cui il gioco finisce a caricare
	# due gigabyte che non sono suoi.
	t.ok(LLM.spedito_accanto_a("/x/gioco").ends_with(LLM.NOME_MODELLO),
			"il file spedito ha il nome fisso di Llm.NOME_MODELLO")


# =========================================================================
# 2. L'ORDINE DEI TRE CANDIDATI
# =========================================================================

## Tutte e otto le combinazioni, perché sono otto e enumerarle costa meno che
## sceglierne tre e sperare che siano quelle giuste.
##
## L'ordine non è una preferenza di gusto: `percorso_modello()` dà UN
## percorso, non una catena di ripieghi — se il C++ rifiuta quello scelto (il
## tetto, la riserva di RAM, il portiere) la funzione si spegne e non prova
## il successivo. Il modello spedito è un 4B che chiede 2640 MB e su una
## macchina da 8 GB viene rifiutato: se stesse sopra `user://`, chi ha una
## macchina piccola non potrebbe far funzionare la funzione in nessun modo.
##
## FALSIFICATO: scambiando `suo` e `spedito` (2 asserzioni rosse),
## scambiando `da_fuori` e `suo` (3), e tornando sempre `spedito` (4).
func _l_ordine_dei_tre_candidati(t) -> void:
	const F := "/1/fuori.gguf"
	const U := "/2/utente.gguf"
	const S := "/3/spedito.gguf"
	t.eq(LLM.il_primo_che_c_e(F, U, S), F, "CHIBI_MODELLO batte tutti")
	t.eq(LLM.il_primo_che_c_e(F, U, ""), F, "CHIBI_MODELLO batte user://")
	t.eq(LLM.il_primo_che_c_e(F, "", S), F, "CHIBI_MODELLO batte il modello spedito")
	t.eq(LLM.il_primo_che_c_e(F, "", ""), F, "CHIBI_MODELLO da solo")
	t.eq(LLM.il_primo_che_c_e("", U, S), U,
			"user:// batte il modello spedito (è la via d'uscita di chi ha una macchina piccola)")
	t.eq(LLM.il_primo_che_c_e("", U, ""), U, "user:// da solo")
	t.eq(LLM.il_primo_che_c_e("", "", S), S, "il modello spedito, quando è l'unico")
	t.eq(LLM.il_primo_che_c_e("", "", ""), "",
			"nessuno dei tre: «» — che è la risposta normale, non un guasto")


## E le due giunture che si possono piantare davvero: `CHIBI_MODELLO` e
## `user://`. Il terzo candidato non si può piantare da nessuna parte (vive
## dentro il pacchetto di un gioco esportato), e per questo la sua regola sta
## nel caso qui sopra.
##
## FALSIFICATO: togliendo la lettura di `CHIBI_MODELLO` (1 asserzione rossa),
## togliendo `globalize_path` sul ramo di `user://` (1), e togliendo la prova
## di esistenza su `CHIBI_MODELLO` (1: un percorso inventato non deve vincere).
func _i_due_candidati_veri(t) -> void:
	var vecchio := OS.get_environment("CHIBI_MODELLO")
	DirAccess.make_dir_recursive_absolute("user://modelli")
	_scrivi(ESCA_UTENTE)
	_scrivi(ESCA_FUORI)
	var fuori := ProjectSettings.globalize_path(ESCA_FUORI)
	var utente := ProjectSettings.globalize_path(ESCA_UTENTE)

	OS.set_environment("CHIBI_MODELLO", fuori)
	t.eq(LLM.percorso_modello(), fuori, "con CHIBI_MODELLO vince CHIBI_MODELLO")

	# Un `CHIBI_MODELLO` che punta a un file che non c'è non deve vincere:
	# altrimenti una variabile d'ambiente rimasta appesa in una shell
	# spegnerebbe la funzione per tutta la sessione, in silenzio.
	OS.set_environment("CHIBI_MODELLO", "/questo/non/esiste/mai.gguf")
	t.eq(LLM.percorso_modello(), utente,
			"un CHIBI_MODELLO che punta al nulla non scavalca niente")

	OS.set_environment("CHIBI_MODELLO", "")
	t.eq(LLM.percorso_modello(), utente,
			"senza CHIBI_MODELLO vince il modello di chi gioca, col percorso VERO su disco")
	t.ok(not LLM.percorso_modello().begins_with("user:"),
			"e il percorso è globalizzato: llama.cpp apre un file, non una risorsa di Godot")

	DirAccess.remove_absolute(utente)
	DirAccess.remove_absolute(fuori)
	OS.set_environment("CHIBI_MODELLO", vecchio)


# =========================================================================
# 3. L'IMPRONTA — di un percorso solo
# =========================================================================

## ⚠️ SE L'IMPRONTA FOSSE ARMATA SEMPRE, `CHIBI_MODELLO` NON SERVIREBBE PIÙ A
## NIENTE: ogni banco, ogni provino, ogni prova con un altro modello si
## prenderebbe «questo non è il modello collaudato», e il `.gguf` che un
## giocatore ha scelto di mettere in `user://` verrebbe rifiutato senza che
## lui possa capire perché. Dei tre candidati ce n'è uno solo di cui
## conosciamo i byte.
##
## FALSIFICATO: tornando sempre `IMPRONTA_SPEDITO` (3 asserzioni rosse),
## tornando sempre "" (1), e confrontando con `percorso_spedito()` invece che
## con `spedito_accanto_a()` (1: nell'editor il file non c'è, quindi il
## confronto sarebbe con "" e l'impronta non si armerebbe MAI — cioè la
## difesa spenta con la suite verde).
func _l_impronta_e_di_un_percorso_solo(t) -> void:
	var posto := LLM.spedito_accanto_a(OS.get_executable_path())
	t.ok(posto != "", "il posto del modello spedito si sa sempre (anche se il file non c'è)")
	t.eq(LLM.impronta_attesa(posto), LLM.IMPRONTA_SPEDITO,
			"sul modello spedito l'impronta è armata")
	t.eq(LLM.impronta_attesa("/un/altro/modello.gguf"), "",
			"su un modello qualunque non si chiede nessuna impronta")
	t.eq(LLM.impronta_attesa(ProjectSettings.globalize_path(ESCA_UTENTE)), "",
			"sul modello di chi gioca nemmeno: dei suoi byte non sappiamo niente")
	t.eq(LLM.impronta_attesa(""), "", "e su «» non c'è niente da verificare")

	# ⚠️ E LA GIUNTURA: chi apre il modello deve CHIEDERLA DAVVERO. Senza,
	# `impronta_attesa` sarebbe una funzione perfetta che non chiama nessuno —
	# lo stato in cui tutta la Fase 5 si trovava prima del cablaggio.
	#
	# La prima stesura di questa guardia cercava la parola «impronta_attesa»
	# nel sorgente di `Pensieri.gd`. MISURATO: sostituendo la chiamata con
	# `var imp := ""` — cioè spegnendo la difesa — **restava verde**, perché
	# la parola compare anche nel commento che spiega la riga. Adesso si
	# guarda il DIZIONARIO con cui il modello verrebbe aperto.
	var n = PENSIERI.new()
	var opz: Dictionary = n.opzioni_modello(posto)
	t.eq(str(opz.get("impronta", "")), LLM.IMPRONTA_SPEDITO,
			"il modello spedito si apre chiedendo la sua impronta")
	var altre: Dictionary = n.opzioni_modello("/un/altro/modello.gguf")
	t.ok(not altre.has("impronta"),
			"e un modello qualunque si apre senza chiederne nessuna")
	# le due opzioni che ci sono SEMPRE: se sparissero, la finestra e la
	# priorità tornerebbero ai valori di serie del C++ e tutte le misure
	# della fase (la tabella della RAM, il costo sul fotogramma) sarebbero
	# di un gioco diverso.
	t.eq(int(opz.get("n_ctx", 0)), PENSIERI.FINESTRA, "la finestra si passa sempre")
	t.eq(int(opz.get("priorita", -1)), PENSIERI.PRIORITA, "e la priorità del thread anche")
	n.free()


## La forma. Una costante troncata, con una lettera maiuscola o con uno spazio
## in fondo non fa fallire niente: fa **spegnere la funzione per tutti**, in
## silenzio, perché il confronto in C++ è fra stringhe e non combacerebbe mai.
##
## ⚠️ Questo caso NON dice che l'impronta sia quella giusta — per saperlo
## bisogna avere il file, e il file non sta nel repository. Lo dice
## `tools/misura_impronta.gd`, che lo legge e confronta.
##
## FALSIFICATO: troncando la costante di un carattere (2 rosse) e mettendoci
## una maiuscola (1).
func _l_impronta_ha_la_forma_giusta(t) -> void:
	var i: String = LLM.IMPRONTA_SPEDITO
	t.eq(i.length(), 64, "uno SHA-256 in esadecimale è lungo 64")
	t.eq(i, i.to_lower(), "e minuscolo (è così che lo scrive il C++)")
	var solo_esa := true
	for c in i:
		if not ("0123456789abcdef".contains(c)):
			solo_esa = false
	t.ok(solo_esa, "e sono tutte cifre esadecimali (invece: «%s»)" % i)


# =========================================================================
# 4. LA LEVA DEL GIOCATORE
# =========================================================================

## Il verso, la persistenza, e la porta.
##
## ⚠️ IL BIT SALVATO È «SPENTO», NON «ACCESO», e il verso si gira in un posto
## solo. Il valore di serie di un `bool` è `false`, e il valore di serie di
## questa funzione dev'essere ACCESA: un `llm_acceso` spegnerebbe il
## villaggio a chiunque non abbia mai aperto il pannello.
##
## FALSIFICATO: togliendo il `not` da `set_llm_acceso` (3 asserzioni rosse),
## togliendo la riga di `llm_spento` da `_save` (1) e da `_load` (1).
func _la_leva_del_giocatore(t) -> void:
	var s: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("/root/Settings")
	t.ok(s != null, "l'autoload delle impostazioni c'è")
	if s == null:
		return
	var prima: bool = bool(s.get("llm_spento"))

	s.call("set_llm_acceso", false)
	t.eq(bool(s.get("llm_spento")), true, "«il villaggio pensa» spento = llm_spento vero")
	t.eq(LLM.acceso(), false, "e la porta si chiude, col modello o senza")

	s.call("set_llm_acceso", true)
	t.eq(bool(s.get("llm_spento")), false, "e acceso = llm_spento falso")

	# LA PERSISTENZA, e sono DUE metà: scrivere e rileggere. Una leva che si
	# salva e non si rilegge è una leva che chi gioca deve ritirare ogni sera
	# — e MISURATO il 2026-08-13: guardando solo il file, togliere la riga da
	# `_load` lasciava la suite verde. Il giro si chiude, non si guarda a metà.
	s.call("set_llm_acceso", false)
	var cfg := ConfigFile.new()
	t.eq(cfg.load(SETTINGS.PATH), OK, "il file delle impostazioni si rilegge")
	t.eq(bool(cfg.get_value("gameplay", "llm_spento", false)), true,
			"la leva finisce nel file (altrimenti muore con il gioco)")

	# e adesso il ritorno: si sporca la memoria e si rilegge dal disco.
	s.set("llm_spento", false)
	s.call("_load")
	t.eq(bool(s.get("llm_spento")), true,
			"e torna indietro all'avvio dopo (altrimenti si ritira ogni sera)")

	s.set("llm_spento", prima)
	s.call("_save")


# =========================================================================
# 5. LA RIGA DEL PANNELLO
# =========================================================================

## LA RIGA C'È ESATTAMENTE QUANDO `Llm.leva_visibile()` È VERA, e l'asserzione
## è scritta come un'UGUAGLIANZA apposta: è l'unica forma che dice qualcosa in
## tutte e due le configurazioni del gioco.
##
##  · nel binario NORMALE (llm=no, quello che gioca la gente) `leva_visibile()`
##    è falsa e la riga non deve esistere: una casella «il villaggio pensa»
##    mostrata a chi non ha nessun modello racconta che gli manca un pezzo, e
##    non gli manca niente;
##  · nel binario con llama.cpp e un modello piantato, deve esserci.
##
## FALSIFICATO: aggiungendo la riga senza condizione (rossa su llm=no),
## togliendo la chiamata a `_llm_row()` (rossa su llm=yes col modello), e
## facendo tornare `leva_visibile()` sempre vero (rossa su llm=no).
func _la_riga_del_pannello(t) -> void:
	var vecchio := OS.get_environment("CHIBI_MODELLO")
	DirAccess.make_dir_recursive_absolute("user://modelli")
	_scrivi(ESCA_UTENTE)
	OS.set_environment("CHIBI_MODELLO", "")

	t.eq(LLM.leva_visibile(), LLM.disponibile() and LLM.percorso_modello() != "",
			"la condizione della riga ha una casa sola")
	t.ok(LLM.percorso_modello() != "", "il banco ha piantato un modello: c'è di che")

	var p: Control = PANNELLO.new()
	t.stage(p)
	t.eq(_c_e_la_riga(p, L10n.t("Il villaggio pensa")), LLM.leva_visibile(),
			"la riga «Il villaggio pensa» c'è esattamente quando c'è qualcosa da spegnere")

	# E la controprova: senza modello la riga non c'è MAI, in nessuna delle
	# due configurazioni. Senza di lei il caso sarebbe verde su un pannello
	# che mostra sempre la casella, purché il banco pianti sempre un modello.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ESCA_UTENTE))
	t.eq(LLM.percorso_modello(), "", "tolta l'esca, non c'è nessun modello")
	var q: Control = PANNELLO.new()
	t.stage(q)
	t.eq(_c_e_la_riga(q, L10n.t("Il villaggio pensa")), false,
			"senza modello la casella non esiste (non «esiste e ingrigita»)")

	OS.set_environment("CHIBI_MODELLO", vecchio)


func _c_e_la_riga(radice: Node, testo: String) -> bool:
	for n in radice.find_children("*", "Label", true, false):
		if str((n as Label).text) == testo:
			return true
	return false


func _scrivi(dove: String) -> void:
	var f := FileAccess.open(dove, FileAccess.WRITE)
	if f != null:
		f.store_string("non è un modello: è un'esca per provare quale percorso vince")
		f.close()
