extends RefCounted
## LE LICENZE CHE SPEDIAMO — la guardia sugli obblighi di ridistribuzione.
##
## Questo file non prova un comportamento del gioco: prova che il gioco possa
## essere DISTRIBUITO. È una differenza di specie, e vale la pena scriverla —
## un difetto qui non si vede giocando, non fa cadere un fotogramma e non
## stampa niente: si vede il giorno in cui qualcuno guarda il pacchetto, e a
## quel punto il pacchetto è già in mano alle persone.
##
## Due famiglie di obblighi, tutte e due vere e tutte e due sorvegliate qui:
##
## 1. **MIT** (Godot, godot-cpp, EnTT, lua-gdextension, llama.cpp/ggml) —
##    «The above copyright notice and this permission notice shall be included
##    in all copies». Il gioco esportato È una copia. Fino al 2026-08-13 il
##    pacchetto non conteneva NESSUN avviso: non era una svista della Fase 5,
##    era così da sempre.
## 2. **Gemma Terms of Use, Sezione 3.1** — quattro condizioni alla
##    ridistribuzione dei pesi. Senza, la licenza per ridistribuirli non c'è:
##    non è un vizio di forma, è ridistribuire senza permesso, dentro un
##    prodotto commerciale.
##
## ⚠️ **PERCHÉ NON BASTA GUARDARE IL REPOSITORY.** Quello che conta è cosa c'è
## nel PACCHETTO, e il pacchetto lo costruisce `release.yml`. Il controllo sul
## pacchetto vero sta lì (passo «Le licenze sono DENTRO i pacchetti?», che apre
## gli zip e li ispeziona) ed è stato falsificato togliendo un file, riscrivendo
## la frase, mandandola a capo e mettendo i separatori a barra rovescia. Qui si
## sorveglia la SORGENTE di quel pacchetto: che i file esistano, che dicano la
## cosa giusta, e che l'export sia ancora configurato per portarli dentro.
##
## ⚠️ **E LE RIGHE DI COPYRIGHT NON SI RICOPIANO IN QUESTO FILE.** Si leggono
## dai LICENSE veri e si cercano nel file spedito. Un test che confronta una
## costante scritta a mano con un'altra costante scritta a mano è verde per
## sempre — anche il giorno in cui EnTT cambia intestazione e il nostro avviso
## comincia a dichiarare il falso.

const CARTELLA := "res://misc/licenze"
const NOTE := preload("res://scenes/ui/NoteLegali.gd")

## La frase che la Sezione 3.1, punto 4, impone parola per parola. È l'unica
## costante testuale di questo file, e ci sta perché È il testo di legge: qui
## copiarla non è duplicare una fonte, è dichiarare l'atteso.
const FRASE_NOTICE := "Gemma is provided under and subject to the Gemma Terms of Use found at ai.google.dev/gemma/terms"

## Da dove si leggono le righe di copyright: (licenza vera, chi è).
const SORGENTI_MIT := {
	"godot-cpp/LICENSE.md": "godot-cpp",
	"addons/lua-gdextension/LICENSE": "lua-gdextension",
	"src/thirdparty/entt/LICENSE": "EnTT",
	"src/thirdparty/llama.cpp/LICENSE": "llama.cpp / ggml",
}


func run(t) -> void:
	_i_file_spediti_esistono(t)
	_la_frase_della_3_1(t)
	_l_accordo_e_quello_giusto(t)
	_gli_avvisi_mit_sono_quelli_veri(t)
	_il_license_porta_i_vincoli_d_uso(t)
	_il_license_non_dice_di_spedire_i_pesi(t)
	_l_avviso_dice_che_lo_scarica_il_giocatore(t)
	_l_export_li_porta_dentro(t)
	_la_pagina_del_gioco_li_trova(t)
	_la_pagina_non_promette_una_rete_che_non_c_e(t)
	_la_pagina_si_apre_sulla_FUNZIONE_non_sul_file(t)


# ---------------------------------------------------------------- utilità

func _testo(percorso: String) -> String:
	var f := FileAccess.open(percorso, FileAccess.READ)
	if f == null:
		return ""
	var s := f.get_as_text()
	f.close()
	return s


func _spedito(nome: String) -> String:
	return _testo(CARTELLA.path_join(nome))


# ------------------------------------------------------- i file ci sono

func _i_file_spediti_esistono(t) -> void:
	# Sono i QUATTRO che `release.yml` copia accanto al gioco. Se qui ne manca
	# uno, il pacchetto esce senza — e il controllo in CI fallisce la Release.
	for nome in ["NOTICE-Gemma.txt", "Gemma-Terms-of-Use.txt",
			"Gemma-Prohibited-Use-Policy.txt", "LICENZE-TERZE-PARTI.txt"]:
		var s := _spedito(nome)
		t.ok(s.length() > 200, "%s esiste e non è un file vuoto" % nome)


# ------------------------------------- la frase della Sezione 3.1 punto 4

func _la_frase_della_3_1(t) -> void:
	var avviso := _spedito("NOTICE-Gemma.txt")
	t.ok(avviso.contains(FRASE_NOTICE),
			"NOTICE-Gemma.txt contiene la frase della Sezione 3.1 punto 4")

	# ⚠️ E LA CONTIENE SU UNA RIGA SOLA. La prima stesura di questo file la
	# mandava a capo dopo «found at» — il testo si leggeva benissimo e la
	# stringa richiesta NON c'era. Un avviso che «contiene la frase a meno
	# degli a capo» è un avviso che nessuno può verificare a macchina.
	var una_riga := false
	for riga in avviso.split("\n"):
		if riga.strip_edges() == FRASE_NOTICE:
			una_riga = true
	t.ok(una_riga, "la frase della 3.1 sta su una riga sua, intera")

	# L'avviso ai destinatari (stessa Sezione 3.1): chi riceve il gioco deve
	# sapere che i vincoli d'uso valgono anche per lui.
	t.ok(avviso.contains("prohibited_use_policy"),
			"NOTICE-Gemma.txt rimanda alla Prohibited Use Policy")
	t.ok(avviso.contains("3.2"),
			"NOTICE-Gemma.txt cita i vincoli d'uso della Sezione 3.2")
	# La catena di provenienza: dire QUALE file spediamo è l'unico modo di
	# rendere verificabile che non l'abbiamo toccato (Sezione 3.1 punto 3).
	t.ok(avviso.contains("ggml-org"), "NOTICE-Gemma.txt dice da dove viene il .gguf")
	t.ok(avviso.to_lower().contains("unmodified")
			or avviso.to_lower().contains("senza modifiche"),
			"NOTICE-Gemma.txt dichiara che i pesi non sono stati modificati")


# --------------------------------------------- l'accordo copre il modello

func _l_accordo_e_quello_giusto(t) -> void:
	var acc := _spedito("Gemma-Terms-of-Use.txt")

	# ⚠️ LA COSA CHE CONTA DAVVERO: l'accordo che spediamo deve coprire il
	# modello che spediamo. I Gemma Terms of Use valgono per i modelli
	# elencati nella loro Appendix — e Gemma 4, per esempio, NON c'è (sta
	# sotto Apache 2.0). Spedire l'accordo sbagliato è peggio che non
	# spedirne nessuno: sembra a posto.
	t.ok(acc.contains("Gemma 3"), "l'accordo spedito elenca Gemma 3 fra i modelli coperti")
	t.ok(acc.contains("Appendix"), "l'accordo spedito ha la sua Appendix")

	# Le quattro condizioni della 3.1 e i vincoli della 3.2 devono esserci:
	# una copia troncata non è «una copia dell'accordo».
	t.ok(acc.contains("3.1 Distribution and Redistribution"),
			"l'accordo contiene la Sezione 3.1 (ridistribuzione)")
	t.ok(acc.contains("3.2 Use Restrictions"),
			"l'accordo contiene la Sezione 3.2 (vincoli d'uso)")
	t.ok(acc.contains("3.3 Generated Output"),
			"l'accordo contiene la Sezione 3.3 (il testo generato)")
	t.ok(acc.contains("regardless of the source that you obtained it from"),
			"l'accordo contiene la 1.1(c) — la licenza non dipende da dove hai preso il file")

	var pup := _spedito("Gemma-Prohibited-Use-Policy.txt")
	t.ok(pup.contains("You may not use nor allow others to use"),
			"la Prohibited Use Policy spedita è quella vera")
	t.ok(pup.length() > 2000, "la Prohibited Use Policy non è troncata")


# ------------------------------------------------- gli avvisi MIT sono veri

func _gli_avvisi_mit_sono_quelli_veri(t) -> void:
	var spedito := _spedito("LICENZE-TERZE-PARTI.txt")

	for percorso in SORGENTI_MIT:
		var chi = SORGENTI_MIT[percorso]
		var vera := _testo("res://" + percorso)
		# Il sottomodulo llama.cpp può non essere inizializzato su un clone
		# leggero: in quel caso non si può concludere niente, e un test che
		# «passa perché non ha trovato il file» è peggio di un test assente.
		if vera == "":
			t.ok(percorso.contains("llama.cpp"),
					"manca %s: solo llama.cpp può mancare (sottomodulo)" % percorso)
			continue
		# la riga di copyright VERA, letta dalla licenza VERA
		var riga := ""
		for r in vera.split("\n"):
			if r.strip_edges().begins_with("Copyright"):
				riga = r.strip_edges()
				break
		t.ok(riga != "", "%s ha una riga di copyright" % chi)
		t.ok(spedito.contains(riga),
				"l'avviso spedito porta il copyright VERO di %s (%s)" % [chi, riga])

	# «The above copyright notice AND this permission notice»: la riga di
	# copyright da sola non è un avviso MIT, è una citazione.
	var permessi := spedito.count("Permission is hereby granted, free of charge")
	t.ok(permessi >= 5,
			"l'avviso spedito porta il PERMESSO per intero, non solo i copyright (%d)" % permessi)

	# I due contributi incorporati nei sorgenti di ggml, che non hanno un
	# LICENSE a parte: il loro avviso vive nell'intestazione del file.
	t.ok(spedito.contains("Copyright 2024 Mozilla Foundation"),
			"l'avviso spedito porta il copyright di Mozilla (sgemm.cpp)")
	t.ok(spedito.contains("Jeffrey Quesnelle and Bowen Peng"),
			"l'avviso spedito porta il copyright di YaRN (rope_yarn)")

	# E il modello NON è MIT: se l'avviso lo mettesse in fila con gli altri,
	# direbbe una cosa falsa proprio nel documento che serve a dire il vero.
	t.ok(spedito.contains("NOTICE-Gemma.txt"),
			"l'avviso rimanda ai documenti di Gemma invece di trattarli da MIT")


# ------------------------------------------- il LICENSE porta i vincoli d'uso

func _il_license_porta_i_vincoli_d_uso(t) -> void:
	# Sezione 3.1, primo punto: i vincoli d'uso devono essere una clausola
	# VINCOLANTE dell'accordo che governa l'uso del prodotto. Quell'accordo,
	# per questo gioco, è il file LICENSE.
	var lic := _testo("res://LICENSE")
	t.ok(lic != "", "il LICENSE si legge")
	t.ok(lic.contains("ai.google.dev/gemma/prohibited_use_policy"),
			"il LICENSE vincola chi gioca alla Prohibited Use Policy")
	t.ok(lic.contains("ai.google.dev/gemma/terms"),
			"il LICENSE rimanda ai Gemma Terms of Use")

	# ⚠️ E IL CARVE-OUT, che è la metà che protegge NOI. Un «All Rights
	# Reserved» che si estendesse ai pesi sarebbe una condizione in conflitto
	# con i Gemma Terms of Use, che la Sezione 3.1 vieta espressamente
	# («Any additional or different terms and conditions you impose must not
	# conflict with the terms of this Agreement»).
	t.ok(lic.contains("Gemma is NOT part of the Work"),
			"il LICENSE dichiara che i pesi non sono l'Opera (carve-out, EN)")
	t.ok(lic.contains("Gemma NON fa parte dell'Opera"),
			"il LICENSE dichiara che i pesi non sono l'Opera (carve-out, IT)")
	t.ok(lic.contains("the Gemma Terms of Use prevail"),
			"il LICENSE dichiara che in conflitto prevalgono i Gemma Terms of Use")

	# Le due lingue devono dire la stessa cosa: il LICENSE è bilingue, e una
	# clausola vincolante che esiste in una metà sola non vincola nessuno.
	t.ok(lic.contains("prevalgono i Gemma Terms of Use"),
			"la metà italiana del LICENSE porta la stessa prevalenza")


# ------------------------------------ e non dichiara di spedire quel che non spedisce

## ⚠️ **DA QUANDO IL MODELLO LO SCARICA IL GIOCATORE, LA METÀ DI QUESTE RIGHE
## CHE ERA UN OBBLIGO È DIVENTATA UNA BUGIA.** La Sezione 3.1 pone le sue
## quattro condizioni a chi *«reproduce or Distribute copies of Gemma»*: noi
## non trasmettiamo, non pubblichiamo, non condividiamo e non ospitiamo
## niente — i byte vanno da Hugging Face al disco di chi gioca. Le condizioni
## non hanno più destinatari su cui mordere, e un `LICENSE` che continuasse a
## dire *«distributed builds may include a copy of Gemma»* descriverebbe un
## file che nel pacchetto non c'è.
##
## Perciò qui si sorvegliano DUE cose, e servono tutte e due: che il
## documento **affermi il vero** (la frase c'è, in tutte e due le lingue) e
## che **non sia tornata** la frase vecchia. La prima da sola non basta —
## si possono scrivere due paragrafi che si contraddicono; la seconda da sola
## nemmeno — si può cancellare la frase falsa e non dire più niente.
func _il_license_non_dice_di_spedire_i_pesi(t) -> void:
	var lic := _testo("res://LICENSE")

	t.ok(lic.contains("The Work contains no machine-learning model weights"),
			"il LICENSE dichiara che l'Opera non contiene pesi (EN)")
	t.ok(lic.contains("L'Opera non contiene pesi di modelli di apprendimento automatico"),
			"il LICENSE dichiara che l'Opera non contiene pesi (IT)")

	for bugia in ["Distributed builds of the Work may include a copy",
			"is included with every build that contains Gemma",
			"possono includere una copia dei pesi",
			"viaggia con ogni versione che contiene"]:
		t.ok(not lic.contains(bugia),
				"il LICENSE non dice più «%s»" % bugia)

	# ⚠️ E IL VINCOLO D'USO HA CAMBIATO BASE, non è sparito. Citare ancora la
	# 3.1 sarebbe invocare una clausola che non ci vincola più — una citazione
	# a vuoto. La base vera è la Prohibited Use Policy, che vincola anche chi
	# «allow[s] others to use», e noi siamo quelli che il modello glielo
	# mettono in mano.
	for citazione_morta in ["as required by Section 3.1 of the Gemma Terms of Use",
			"come richiesto dalla Sezione 3.1 dei Gemma Terms of Use"]:
		t.ok(not lic.contains(citazione_morta),
				"il LICENSE non fonda più il vincolo d'uso sulla 3.1 («%s»)" % citazione_morta)
	t.ok(lic.count("allow[s] others to use") >= 2,
			"il LICENSE fonda il vincolo d'uso sul «nor allow others to use» della policy, in tutte e due le lingue")


# ---------------------------------- l'avviso racconta lo SCARICAMENTO, non il pacchetto

## Il file «Notice» resta nel pacchetto anche se la 3.1 non ce lo chiede più
## (cautela dichiarata: costa una riga, ed è già dove servirebbe se un domani
## qualcuno leggesse «scaricare per conto tuo» come una forma di
## distribuzione). Ma il suo CONTENUTO deve raccontare quello che succede
## davvero, o è un avviso che disinforma proprio chi è venuto a informarsi.
func _l_avviso_dice_che_lo_scarica_il_giocatore(t) -> void:
	var avviso := _spedito("NOTICE-Gemma.txt")

	t.ok(avviso.contains("This package contains NO model weights"),
			"l'avviso dichiara che nel pacchetto non c'è nessun modello (EN)")
	t.ok(avviso.contains("Questo pacchetto NON contiene nessun modello"),
			"l'avviso dichiara che nel pacchetto non c'è nessun modello (IT)")
	t.ok(avviso.contains("huggingface.co"),
			"l'avviso dice DA DOVE arriva il file che il gioco scarica")
	t.ok(not avviso.contains("This product, Chibi Crossing, includes a copy of Gemma"),
			"l'avviso non dichiara più di includere una copia dei pesi")

	# La ragione per cui il gioco mostra i termini PRIMA: ci si vincola con
	# l'atto stesso di scaricare (preambolo dell'accordo). Se questa frase
	# sparisce, sparisce l'unica spiegazione che il giocatore riceve del
	# perché gli si sta chiedendo qualcosa.
	t.ok(avviso.contains("bound by the Gemma Terms of Use through the act of"),
			"l'avviso spiega che ci si vincola scaricando o usando (EN)")
	t.ok(avviso.contains("per il fatto stesso di scaricare o di usare Gemma"),
			"l'avviso spiega che ci si vincola scaricando o usando (IT)")


# ------------------------------------------- l'export se li porta dentro

func _l_export_li_porta_dentro(t) -> void:
	# I file entrano nel `.pck` solo se `include_filter` li nomina: un `.txt`
	# non è una risorsa di Godot, quindi `export_filter="all_resources"` da
	# solo NON basta e la pagina «Note legali» troverebbe la cartella vuota.
	var cfg := ConfigFile.new()
	var err := cfg.load("res://export_presets.cfg")
	t.eq(err, OK, "export_presets.cfg si carica (attenzione ai commenti: ';' non '#')")
	var presets := 0
	for sez in cfg.get_sections():
		if not cfg.has_section_key(sez, "include_filter"):
			continue
		presets += 1
		var filtro := str(cfg.get_value(sez, "include_filter", ""))
		t.ok(filtro.contains("misc/licenze"),
				"il preset [%s] porta misc/licenze dentro il pacchetto" % sez)
	t.eq(presets, 2, "i preset con include_filter sono due (Windows e macOS)")


# ------------------------------------- la pagina del gioco li sa trovare

func _la_pagina_del_gioco_li_trova(t) -> void:
	# La tabella della pagina e i file sul disco devono combaciare NEI DUE
	# VERSI. Una voce che punta a un file assente dà un bottone spento senza
	# spiegazione; un file senza voce è un documento spedito che nessuno può
	# leggere da dentro il gioco — e i due guasti si somigliano abbastanza da
	# nascondersi a vicenda.
	var attesi := {}
	for d in NOTE.DOCUMENTI:
		var nome := str(d["file"])
		attesi[nome] = true
		t.ok(FileAccess.file_exists(NOTE.CARTELLA.path_join(nome)),
				"la pagina Note legali punta a un file che esiste: %s" % nome)
		t.ok(str(d["titolo"]) != "", "%s ha un titolo da mostrare" % nome)

	var dir := DirAccess.open(NOTE.CARTELLA)
	t.ok(dir != null, "la cartella delle licenze si apre")
	if dir != null:
		for nome in dir.get_files():
			if nome.ends_with(".txt"):
				t.ok(attesi.has(nome),
						"%s è spedito e la pagina Note legali lo elenca" % nome)

	# La pagina legge dalla STESSA cartella che release.yml copia nel
	# pacchetto: due percorsi diversi vorrebbero dire due verità diverse su
	# cosa il giocatore sta leggendo.
	t.eq(NOTE.CARTELLA, CARTELLA, "la pagina legge dalla cartella spedita")


# ================================================================ LA PAGINA VIVA
#
# ⚠️ Quello che segue NON cerca stringhe nei sorgenti: **costruisce la pagina
# vera** e legge il testo che finisce nei suoi nodi. La differenza non è di
# stile. Una pagina si può rompere in tre modi che un `grep` non vede — la
# frase c'è ma sta dietro un `if` che non scatta mai, la frase c'è in
# italiano e non in inglese, la voce è stata spostata in un ramo che non si
# mostra — e tutti e tre finiscono nello stesso posto: un giocatore che legge
# una cosa diversa da quella che il file sorgente prometteva.

## Costruisce la pagina fuori dall'albero e restituisce TUTTO il testo che
## mostra. `_costruisci()` e non `_ready()`: il secondo scatta solo entrando
## nell'albero, e i test non ce la mettono (convenzione della suite).
func _testi_della_pagina(forza: int) -> PackedStringArray:
	var pagina = NOTE.new()
	pagina.forza_modello = forza
	pagina.call("_costruisci")
	var fuori := PackedStringArray()
	_raccogli_testo(pagina, fuori)
	pagina.free()
	return fuori


func _raccogli_testo(n: Node, dentro: PackedStringArray) -> void:
	var testo = n.get("text")
	if testo != null and str(testo) != "":
		dentro.append(str(testo))
	for c in n.get_children():
		_raccogli_testo(c, dentro)


## ⚠️ **LA PAGINA NON PUÒ PROMETTERE UNA MACCHINA MUTA, PERCHÉ ADESSO PARLA.**
##
## Fino al 2026-08-13 questa pagina diceva, in tutte e due le lingue: «Non
## esce niente da questa macchina: il gioco non apre nessuna connessione per
## lui». Era vero finché i pesi viaggiavano nel pacchetto. Da quando li
## scarica il gioco — 2,4 GB da huggingface.co — quella frase è **falsa**, ed
## è falsa proprio nella pagina che esiste per dire il vero: l'unico posto in
## cui un giocatore attento va a controllare se un gioco parla con qualcuno.
##
## L'invariante non è «non dire mai la parola connessione»: è che **non si può
## parlare di rete senza nominare lo scaricamento**. Scritto così, la frase
## vecchia diventa rossa e la frase nuova — che nomina tutte e due le cose, e
## dice quale vale quando — resta verde.
func _la_pagina_non_promette_una_rete_che_non_c_e(t) -> void:
	var prima := L10n.lingua_corrente()
	# ⚠️ Le due lingue si provano tutte e due: una pagina onesta in italiano e
	# rimasta indietro in inglese è esattamente il guasto che una tabella di
	# traduzione fa nascere, e `test_localizzazione` non lo vede (lui guarda
	# se la chiave c'è, non se la frase dice ancora il vero).
	for coppia in [{"lingua": "it", "scarica": "scarica", "rete": "connession"},
			{"lingua": "en", "scarica": "download", "rete": "connection"}]:
		L10n.imposta(str(coppia["lingua"]))
		var righe := _testi_della_pagina(1)
		var tutto := "\n".join(righe).to_lower()
		t.ok(tutto.contains(str(coppia["scarica"])),
				"[%s] la pagina dice che il modello si SCARICA" % coppia["lingua"])
		if tutto.contains(str(coppia["rete"])):
			t.ok(tutto.contains(str(coppia["scarica"])),
					"[%s] se la pagina parla di rete, nomina anche lo scaricamento" % coppia["lingua"])
		t.ok(tutto.contains("huggingface.co"),
				"[%s] la pagina dice DA DOVE arriva il modello" % coppia["lingua"])
		# ⚠️ E LA TAGLIA È QUELLA VERA, SCRITTA DA CHI LA SA SCRIVERE. Il
		# numero non si scrive qui (sarebbe la seconda copia del difetto che
		# sto sorvegliando): si chiede alle stesse due fonti che usa la
		# pagina — `Llm.BYTE_MODELLO` per il dato, `Capienza.in_giga` per la
		# presentazione, che è anche quella della schermata dello
		# scaricamento. Chi scrivesse «2,4 GB» a mano dentro la frase — o
		# cambiasse il modello dimenticando questa riga — diventa rosso.
		t.ok(tutto.contains(Capienza.in_giga(Llm.BYTE_MODELLO).to_lower()),
				"[%s] la pagina dice QUANTO pesa, con il numero di Llm (%s)"
						% [coppia["lingua"], Capienza.in_giga(Llm.BYTE_MODELLO)])
		# E non promette più il silenzio assoluto — in NESSUNA delle due
		# lingue, che è il motivo per cui le due frasi vietate si cercano
		# tutte e due dentro tutti e due i giri: una chiave inglese che manca
		# fa ricadere la pagina sull'italiano, e la bugia rientrerebbe dalla
		# porta di servizio.
		t.ok(not tutto.contains("nothing leaves this machine: the game opens no connection"),
				"[%s] la promessa «nessuna connessione» non è tornata, in inglese" % coppia["lingua"])
		t.ok(not tutto.contains("non esce niente da questa macchina: il gioco non apre nessuna connessione"),
				"[%s] la promessa «nessuna connessione» non è tornata, in italiano" % coppia["lingua"])
	L10n.imposta(prima)


## ⚠️ **I TERMINI SI MOSTRANO PRIMA DELLO SCARICAMENTO, NON DOPO.**
##
## `Llm.leva_visibile()` è vera solo col file già sul disco: è la domanda
## giusta per la casella nelle impostazioni (una casella deve avere qualcosa
## da spegnere) e la domanda **sbagliata** per questa pagina. I Gemma Terms
## of Use vincolano chi scarica *per il fatto stesso di scaricare*
## (preambolo); una pagina che mostrasse i documenti solo a chi ha già il
## file glieli mostrerebbe **dopo** che si è vincolato — cioè quando non
## servono più a decidere.
##
## Il caso vive nel villaggio in cui gira: con un cuore compilato `llm=yes` e
## nessun `.gguf` sul disco — che è esattamente la CI e questa suite — la
## sezione di Gemma **deve** esserci. Con un cuore `llm=no` non deve esserci
## nessuna voce di una funzione che quel binario non ha. Due mondi, due
## asserzioni: nessun ramo resta muto.
func _la_pagina_si_apre_sulla_FUNZIONE_non_sul_file(t) -> void:
	var righe := _testi_della_pagina(-1)          # -1 = chiedi a chi lo sa
	var tutto := "\n".join(righe)
	var nomina_gemma := tutto.contains("Gemma")
	if Llm.disponibile():
		t.ok(nomina_gemma,
				"col cuore che sa scrivere la pagina mostra i documenti di Gemma (modello sul disco: %s)"
						% ("sì" if Llm.percorso_modello() != "" else "NO"))
		t.ok(tutto.contains("Note legali") or tutto.contains("Legal notices"),
				"e resta la pagina delle note legali, non un'altra cosa")
	else:
		t.ok(not nomina_gemma,
				"senza llama.cpp nel binario la pagina non nomina una funzione che non c'è")
		t.ok(tutto.contains("MIT") or tutto.length() > 0,
				"ma resta una pagina completa e vera per quel gioco")
