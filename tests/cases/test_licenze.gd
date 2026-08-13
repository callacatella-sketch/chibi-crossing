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
	_l_export_li_porta_dentro(t)
	_la_pagina_del_gioco_li_trova(t)


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
