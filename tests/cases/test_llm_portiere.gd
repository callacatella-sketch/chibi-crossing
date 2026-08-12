extends RefCounted
## IL PORTIERE — si prova ROMPENDO un file, un byte per volta.
##
## `src/llm_gguf.cpp` è la cosa che sta fra un `.gguf` e llama.cpp, e la
## ragione per cui esiste è che `GGML_ABORT` chiama `abort()`: non è
## `assert()`, `NDEBUG` non lo spegne, non ha callback, e nessun `try` lo
## prende. Un file guasto poteva portarsi via il processo del giocatore.
##
## ────────────────────────────────────────────────────────────────────────
## COME SI PROVA UNA COSA CHE DEVE DIRE DI NO
## ────────────────────────────────────────────────────────────────────────
##
## Non si può provare con un modello vero: sono due gigabyte, non stanno nel
## repository, e in CI non ci sono. E soprattutto un modello vero è SANO —
## proverebbe l'unico caso che non interessa.
##
## Perciò qui il `.gguf` si COSTRUISCE, in GDScript, byte per byte: una
## ventina di righe che scrivono un modellino di trecento byte, valido in
## tutto. Poi lo si rompe in quindici modi diversi, uno per volta, e si
## pretende che il portiere dica di no per la ragione GIUSTA — non «un no
## qualunque»: il motivo si legge, perché un portiere che rifiuta tutto
## sarebbe verde qui e inutile in partita.
##
## E la controprova che rende il resto credibile: il file INTATTO deve
## passare, e i suoi fatti (architettura, tensori, parametri, byte dei pesi)
## devono essere quelli che ci abbiamo scritto dentro.
##
## ⚠️ QUESTO FILE GIRA SOLO NEL BINARIO COMPILATO CON `llm=yes` (il job
## `test-llm` di tests.yml). Senza, `Llm.disponibile()` è falso e non c'è
## niente da provare — ed è la configurazione NORMALE, non un guasto.

const LLM := preload("res://systems/Llm.gd")

const DOVE := "user://prova_portiere.gguf"

# I tipi GGUF, che sono un numero sul disco.
const T_U32 := 4
const T_I32 := 5
const T_F32 := 6
const T_STRINGA := 8
const T_ARRAY := 9


func run(t) -> void:
	if not LLM.disponibile():
		return
	var cuore := LLM.apri()
	if cuore == null:
		return

	_il_file_sano_passa(t, cuore)
	_ogni_guasto_ha_il_suo_no(t, cuore)
	_l_impronta_e_quella_vera(t, cuore)
	_la_stima_cresce_con_la_finestra(t, cuore)
	_il_carico_vero_passa_dal_portiere(t, cuore)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DOVE))


# ─────────────────────────────────────────── la controprova
## Un portiere che dice sempre di no è verde in tutti i test di rifiuto e
## rompe il gioco. Questo caso viene per primo apposta.
func _il_file_sano_passa(t, cuore) -> void:
	_scrivi(_modellino())
	var e = cuore.esamina(DOVE, false)
	t.ok(e["ok"], "il modellino intatto passa (invece: %s)" % str(e["motivo"]))
	t.eq(str(e["architettura"]), "prova", "legge l'architettura")
	t.eq(int(e["tensori"]), 1, "conta i tensori")
	t.eq(int(e["parametri"]), 32, "conta gli elementi dei tensori")
	t.eq(int(e["byte_pesi"]), 128, "conta i byte dei pesi (32 numeri da 4 byte)")
	t.eq(int(e["vocabolario"]), 2, "conta le parole del vocabolario")
	t.eq(int(e["versione"]), 3, "legge la versione del formato")


# ─────────────────────────────────────────── i quindici guasti
func _ogni_guasto_ha_il_suo_no(t, cuore) -> void:
	# Ogni riga: nome, come si rompe, una parola che DEVE comparire nel
	# motivo. La parola non è decorativa — è ciò che distingue «ha rifiutato»
	# da «ha rifiutato per la ragione giusta», e senza di lei questo test
	# resterebbe verde anche se il portiere tornasse sempre `false`.
	var casi := [
		["la firma", func(b): b.encode_u8(0, 88), "GGUF"],
		["la versione 1", func(b): b.encode_u32(4, 1), "versione"],
		["la versione 9", func(b): b.encode_u32(4, 9), "versione"],
		["troppi tensori", func(b): b.encode_u64(8, 1 << 40), "tensori"],
		["troppi metadati", func(b): b.encode_u64(16, 1 << 40), "metadati"],
	]
	for caso in casi:
		var dati := _modellino()
		caso[1].call(dati)
		_scrivi(dati)
		var e = cuore.esamina(DOVE, false)
		t.ok(not e["ok"], "rifiuta: %s" % caso[0])
		t.ok(str(e["motivo"]).to_lower().contains(str(caso[2]).to_lower()),
				"e lo dice giusto (%s → «%s»)" % [caso[0], str(e["motivo"])])

	# I guasti che si fanno con un modellino diverso, non con una toppa.
	var speciali := [
		["il file troncato", _modellino_troncato(), "troncato"],
		["il vocabolario di interi", _modellino(T_I32), "tokenizer.ggml.tokens"],
		["la dimensione a zero", _modellino_ne_zero(), "dimensione"],
		["il tipo di tensore inventato", _modellino_tipo_matto(), "tipo ggml"],
		["l'offset spostato", _modellino_offset_storto(), "byte"],
		["l'allineamento dispari", _modellino_allineamento(3), "allineamento"],
		# ⚠️ QUESTA RIGA È L'UNICA CHE SORVEGLIA UN abort() MISURATO.
		# `general.alignment` non lo legge llama: lo legge ggml, dentro
		# `gguf_init_from_file`, con `gguf_get_val_u32` — che fa
		# `GGML_ASSERT(tipo == u32)`. Tutti gli altri metadati passano dal ramo
		# di llama, che TIRA un'eccezione e il gioco la vede come «modello non
		# caricato». Questo no: `tools/rovina_gguf.py` lo prova su un modello
		# vero e la colonna di llama dice MORTO(6). Se qualcuno togliesse il
		# controllo, questo caso diventa rosso e il gioco torna a poter
		# sparire dallo schermo di chi ci sta giocando.
		["l'allineamento di tipo sbagliato", _modellino_allineamento(32, T_F32), "alignment"],
		["il metadato doppio", _modellino_doppione(), "due volte"],
		["senza architettura", _modellino_senza("general.architecture"), "architecture"],
		["senza vocabolario", _modellino_senza("tokenizer.ggml.tokens"), "vocabolario"],
	]
	for caso in speciali:
		_scrivi(caso[1])
		var e = cuore.esamina(DOVE, false)
		t.ok(not e["ok"], "rifiuta: %s" % caso[0])
		t.ok(str(e["motivo"]).to_lower().contains(str(caso[2]).to_lower()),
				"e lo dice giusto (%s → «%s»)" % [caso[0], str(e["motivo"])])


# ─────────────────────────────────────────── l'impronta
## Lo SHA-256 del portiere è scritto a mano in C++ (cento righe, nessuna
## dipendenza: le librerie di sistema sono diverse su ogni piattaforma, e
## questa funzione decide se un file entra nel gioco). Un'implementazione a
## mano si prova contro un ORACOLO INDIPENDENTE, e Godot ce l'ha in casa.
func _l_impronta_e_quella_vera(t, cuore) -> void:
	_scrivi(_modellino())
	var mio := str(cuore.impronta(DOVE))
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update(FileAccess.get_file_as_bytes(DOVE))
	var suo := h.finish().hex_encode()
	t.eq(mio, suo, "lo SHA-256 del portiere è quello di Godot")
	t.eq(mio.length(), 64, "e ha la lunghezza di uno SHA-256")
	# E su un file che non c'è non esplode: torna vuoto.
	t.eq(str(cuore.impronta("user://questo_non_esiste_mai.gguf")), "",
			"su un file assente l'impronta è vuota, non un errore")


# ─────────────────────────────────────────── la stima
## La stima serve a UNA cosa: dire di no PRIMA di allocare due gigabyte. Se
## non crescesse con la finestra sarebbe un numero decorativo, e il tetto
## dell'autore non avrebbe un metro.
func _la_stima_cresce_con_la_finestra(t, cuore) -> void:
	_scrivi(_modellino())
	var e = cuore.esamina(DOVE, false)
	t.ok(int(e["byte_stimati_2k"]) >= int(e["byte_pesi"]),
			"la stima comprende almeno i pesi")
	t.ok(int(e["byte_stimati_4k"]) > int(e["byte_stimati_2k"]),
			"e cresce con la finestra (la cache di attenzione è lineare nei gettoni)")


# ─────────────────────────────────────────── il cablaggio
## ⚠️ QUESTO CASO CONSUMA IL TRADUTTORE DEL PROCESSO, e lo fa apposta.
##
## `Traduttore::apri()` si può chiamare una volta sola per processo (il
## modello è una risorsa del processo, non dell'oggetto). Spendere quell'unica
## volta QUI è una scelta: è l'unica asserzione che prova che il portiere è
## davvero DAVANTI al caricamento vero, e non un pezzo di codice bellissimo
## che nessuno chiama. Senza, si potrebbe cancellare la chiamata dentro
## `Traduttore::_carica()` e la suite resterebbe tutta verde.
##
## Chi un domani volesse aprire un modello vero dentro la suite deve sapere
## che questo caso ha già speso il gettone — e che il posto giusto per quella
## prova è un provino (`tools/sonda_llm.gd`), non la suite.
func _il_carico_vero_passa_dal_portiere(t, cuore) -> void:
	if int(cuore.stato()) != 0:
		return # qualcun altro l'ha già acceso: non litigo
	_scrivi(_modellino_troncato())
	var partito: bool = cuore.apri_modello(DOVE, {})
	t.ok(partito, "il carico parte (il file esiste)")
	if not partito:
		return
	# Il caricamento è su un thread: si aspetta che si pronunci.
	var giri := 0
	while int(cuore.stato()) != 2 and int(cuore.stato()) != 4 and giri < 2000:
		OS.delay_msec(5)
		giri += 1
	t.eq(int(cuore.stato()), 4, "un file troncato NON diventa un modello pronto")
	var m = cuore.misure()
	t.ok(str(m["diagnosi"]).to_lower().contains("troncato"),
			"e il no viene dal portiere, con la sua ragione (invece: «%s»)"
					% str(m["diagnosi"]))
	cuore.chiudi()


# ─────────────────────────────────────────── il fabbro
## Un GGUF minimo ma completo: intestazione, tre metadati, un tensore da 32
## numeri, e i suoi 128 byte di dati. `p_tipo_tokens` serve a rompere il tipo
## dell'unico elenco che llama.cpp legge senza controllarlo.
func _modellino(p_tipo_tokens := T_STRINGA) -> PackedByteArray:
	var b := PackedByteArray()
	b.append_array("GGUF".to_utf8_buffer())
	_u32(b, 3) # versione
	_u64(b, 1) # tensori
	_u64(b, 7) # metadati

	# I tre numeri con cui si stima la cache di attenzione. Ci sono perché
	# senza di loro la stima varrebbe zero e il tetto dei 2 GB non avrebbe
	# niente da confrontare: un modellino senza testa proverebbe un portiere
	# che in partita non esiste.
	_stringa(b, "prova.block_count")
	_u32(b, T_U32)
	_u32(b, 4)

	_stringa(b, "prova.embedding_length")
	_u32(b, T_U32)
	_u32(b, 64)

	_stringa(b, "prova.attention.head_count")
	_u32(b, T_U32)
	_u32(b, 2)

	_stringa(b, "general.architecture")
	_u32(b, T_STRINGA)
	_stringa(b, "prova")

	_stringa(b, "general.alignment")
	_u32(b, T_U32)
	_u32(b, 32)

	_stringa(b, "tokenizer.ggml.model")
	_u32(b, T_STRINGA)
	_stringa(b, "prova")

	_stringa(b, "tokenizer.ggml.tokens")
	_u32(b, T_ARRAY)
	_u32(b, p_tipo_tokens)
	_u64(b, 2)
	if p_tipo_tokens == T_STRINGA:
		_stringa(b, "a")
		_stringa(b, "b")
	else:
		_u32(b, 1)
		_u32(b, 2)

	_tensore(b, "pesi", 32, 0, 0)
	return _con_dati(b, 128)


func _modellino_troncato() -> PackedByteArray:
	var b := _modellino()
	b.resize(b.size() - 40) # i pesi finiscono prima di quanto dichiarano
	return b


func _modellino_ne_zero() -> PackedByteArray:
	var b := PackedByteArray()
	_intestazione(b, 1, 3)
	_tre_metadati(b)
	_tensore(b, "pesi", 0, 0, 0) # zero: ggml lo accetta, llama ci abortisce
	return _con_dati(b, 0)


func _modellino_tipo_matto() -> PackedByteArray:
	var b := PackedByteArray()
	_intestazione(b, 1, 3)
	_tre_metadati(b)
	_tensore(b, "pesi", 32, 900, 0)
	return _con_dati(b, 128)


func _modellino_offset_storto() -> PackedByteArray:
	var b := PackedByteArray()
	_intestazione(b, 1, 3)
	_tre_metadati(b)
	_tensore(b, "pesi", 32, 0, 64) # deve valere 0: è il primo
	return _con_dati(b, 192)


func _modellino_allineamento(p_valore: int, p_tipo := T_U32) -> PackedByteArray:
	var b := PackedByteArray()
	_intestazione(b, 1, 4)
	_stringa(b, "general.architecture")
	_u32(b, T_STRINGA)
	_stringa(b, "prova")
	_stringa(b, "general.alignment")
	_u32(b, p_tipo)
	_u32(b, p_valore)
	_stringa(b, "tokenizer.ggml.model")
	_u32(b, T_STRINGA)
	_stringa(b, "prova")
	_vocabolario(b)
	_tensore(b, "pesi", 32, 0, 0)
	return _con_dati(b, 128)


func _modellino_doppione() -> PackedByteArray:
	var b := PackedByteArray()
	_intestazione(b, 1, 4)
	_stringa(b, "general.architecture")
	_u32(b, T_STRINGA)
	_stringa(b, "prova")
	_stringa(b, "general.architecture") # due volte: uno dei due è spazzatura
	_u32(b, T_STRINGA)
	_stringa(b, "altra")
	_stringa(b, "tokenizer.ggml.model")
	_u32(b, T_STRINGA)
	_stringa(b, "prova")
	_vocabolario(b)
	_tensore(b, "pesi", 32, 0, 0)
	return _con_dati(b, 128)


func _modellino_senza(p_chiave: String) -> PackedByteArray:
	var b := PackedByteArray()
	_intestazione(b, 1, 2)
	if p_chiave != "general.architecture":
		_stringa(b, "general.architecture")
		_u32(b, T_STRINGA)
		_stringa(b, "prova")
	_stringa(b, "tokenizer.ggml.model")
	_u32(b, T_STRINGA)
	_stringa(b, "prova")
	if p_chiave != "tokenizer.ggml.tokens":
		_vocabolario(b)
	else:
		# senza il vocabolario servono comunque due metadati: si riempie
		_stringa(b, "general.name")
		_u32(b, T_STRINGA)
		_stringa(b, "prova")
	_tensore(b, "pesi", 32, 0, 0)
	return _con_dati(b, 128)


func _intestazione(b: PackedByteArray, p_tensori: int, p_chiavi: int) -> void:
	b.append_array("GGUF".to_utf8_buffer())
	_u32(b, 3)
	_u64(b, p_tensori)
	_u64(b, p_chiavi)


func _tre_metadati(b: PackedByteArray) -> void:
	_stringa(b, "general.architecture")
	_u32(b, T_STRINGA)
	_stringa(b, "prova")
	_stringa(b, "tokenizer.ggml.model")
	_u32(b, T_STRINGA)
	_stringa(b, "prova")
	_vocabolario(b)


func _vocabolario(b: PackedByteArray) -> void:
	_stringa(b, "tokenizer.ggml.tokens")
	_u32(b, T_ARRAY)
	_u32(b, T_STRINGA)
	_u64(b, 2)
	_stringa(b, "a")
	_stringa(b, "b")


func _tensore(b: PackedByteArray, p_nome: String, p_ne: int, p_tipo: int, p_offset: int) -> void:
	_stringa(b, p_nome)
	_u32(b, 1) # una dimensione
	_i64(b, p_ne)
	_u32(b, p_tipo)
	_u64(b, p_offset)


## Aggiunge il riempimento fino all'allineamento e poi i byte dei pesi.
func _con_dati(b: PackedByteArray, p_byte: int) -> PackedByteArray:
	while b.size() % 32 != 0:
		b.append(0)
	for i in p_byte:
		b.append(i % 251)
	return b


func _u32(b: PackedByteArray, v: int) -> void:
	for i in 4:
		b.append((v >> (i * 8)) & 0xff)


func _u64(b: PackedByteArray, v: int) -> void:
	for i in 8:
		b.append((v >> (i * 8)) & 0xff)


func _i64(b: PackedByteArray, v: int) -> void:
	_u64(b, v)


func _stringa(b: PackedByteArray, s: String) -> void:
	var u := s.to_utf8_buffer()
	_u64(b, u.size())
	b.append_array(u)


func _scrivi(dati: PackedByteArray) -> void:
	var f := FileAccess.open(DOVE, FileAccess.WRITE)
	if f == null:
		return
	f.store_buffer(dati)
	f.close()
