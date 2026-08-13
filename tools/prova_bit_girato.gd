extends SceneTree
## UN BIT GIRATO NEL MODELLO GIA' INSTALLATO — chi se ne accorge, e chi no.
##
##   CHIBI_MODELLO=<file.gguf> ~/Downloads/Godot.app/Contents/MacOS/Godot \
##       --headless --path . --script res://tools/prova_bit_girato.gd
##
## Il corriere verifica l'impronta UNA volta, quando il file arriva, e butta
## quello che non combacia (`test_scarico`, `prova_strada` scena 5). Ma dopo
## la rinomina quel file resta sul disco di chi gioca per mesi, e nessuno lo
## guarda più: `Llm.impronta_attesa()` risponde con l'impronta attesa SOLO
## per il modello spedito accanto all'eseguibile — e da quando il modello
## non viaggia più nel pacchetto, quel posto non esiste per nessuno.
##
## Quindi la domanda è: **fra il download e llama, che cosa protegge chi
## gioca?** La risposta è il portiere (`src/llm_gguf`), e questo banco la
## mette alla prova sul modello VERO, girando un bit per volta in tre posti
## diversi. Non è una simulazione: è il file da due gigabyte e mezzo, la
## classe nativa vera, e i suoi motivi di rifiuto scritti in italiano.
##
## ⚠️ **SI LAVORA SU UNA COPIA.** Il file vero è costato mezz'ora di rete a
## chi l'ha scaricato; un banco che gira un bit sull'originale e poi muore a
## metà glielo distrugge.

const LLM := preload("res://systems/Llm.gd")


func _init() -> void:
	_go()


func _bit(percorso: String, dove: int) -> int:
	var f := FileAccess.open(percorso, FileAccess.READ_WRITE)
	if f == null:
		return -1
	f.seek(dove)
	var prima := f.get_8()
	f.seek(dove)
	f.store_8(prima ^ 0x01)
	f.close()
	return prima


func _rimetti(percorso: String, dove: int, valore: int) -> void:
	var f := FileAccess.open(percorso, FileAccess.READ_WRITE)
	f.seek(dove)
	f.store_8(valore)
	f.close()


func _chiedi(L, percorso: String) -> Dictionary:
	return L.esamina(percorso, false)


func _go() -> void:
	if not LLM.disponibile():
		print("binario senza llama: non c'è nessun portiere da interrogare")
		quit(0)
		return
	var vero := OS.get_environment("CHIBI_MODELLO")
	if vero == "" or not FileAccess.file_exists(vero):
		print("serve CHIBI_MODELLO=<un .gguf vero>")
		quit(1)
		return

	var L = LLM.apri()
	print("=== IL MODELLO VERO, INTATTO ===")
	var sano := _chiedi(L, vero)
	print("  ok=%s  «%s»" % [sano.get("ok"), sano.get("motivo")])
	print("  %s · %s · %d tensori · %d chiavi · vocabolario %d"
			% [sano.get("architettura"), sano.get("quantizzazione"),
			int(sano.get("tensori", 0)), int(sano.get("chiavi", 0)),
			int(sano.get("vocabolario", 0))])
	print("  byte file %d · esame %.0f ms" % [int(sano.get("byte_file", 0)),
			float(sano.get("ms_esame", 0.0))])

	print("")
	print("=== CHI RIVERIFICA IL FILE AL CARICAMENTO? ===")
	var suo := "user://modelli/pensieri.gguf"
	print("  impronta_attesa(scaricato in user://) : «%s»" % LLM.impronta_attesa(suo))
	print("  impronta_attesa(accanto all'eseguibile): «%s»"
			% LLM.impronta_attesa(LLM.spedito_accanto_a(OS.get_executable_path())).substr(0, 24))
	print("  → per il file SCARICATO nessuno confronta l'impronta: la difesa")
	print("    è tutta del portiere, e questo banco misura fin dove arriva.")

	# ── LA COPIA ─────────────────────────────────────────────────────────
	var copia := "user://prova_bit/copia.gguf"
	DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(copia.get_base_dir()))
	print("")
	print("=== copio %s… ===" % LLM.NOME_MODELLO)
	var t0 := Time.get_ticks_msec()
	var err := DirAccess.copy_absolute(vero, ProjectSettings.globalize_path(copia))
	if err != OK:
		print("  la copia non riesce (errore %d): disco pieno?" % err)
		quit(1)
		return
	print("  copiato in %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))

	# ── I TRE POSTI ──────────────────────────────────────────────────────
	# Il .gguf comincia con la firma, poi i conti, poi i metadati, poi i
	# pesi. Un bit girato non è lo stesso guasto a seconda di dove cade.
	var byte_file := int(sano.get("byte_file", 0))
	var posti := [
		["nella FIRMA (i primi 4 byte)", 1],
		["nei CONTI di testa (n. tensori)", 12],
		["dentro i METADATI", 2000],
		["dentro i PESI, a metà file", byte_file / 2],
		["dentro i PESI, in fondo", byte_file - 4096],
	]
	print("")
	print("=== UN BIT GIRATO, UN POSTO PER VOLTA ===")
	for p in posti:
		var dove: int = int(p[1])
		var prima := _bit(copia, dove)
		if prima < 0:
			print("  %-34s non riesco a scrivere" % p[0])
			continue
		var d := _chiedi(L, copia)
		var ok: bool = bool(d.get("ok"))
		print("  %-34s → %s   %s" % [p[0], "PASSA " if ok else "FERMATO",
				("«" + str(d.get("motivo")) + "»") if not ok else ""])
		_rimetti(copia, dove, prima)

	# la copia rimessa a posto deve tornare sana: se no, il banco ha
	# sporcato e tutto quello che ha detto non vale niente
	var dopo := _chiedi(L, copia)
	print("")
	print("  controprova — la copia rimessa a posto: ok=%s" % dopo.get("ok"))

	DirAccess.remove_absolute(ProjectSettings.globalize_path(copia))
	print("  (la copia è stata buttata)")
	quit(0)
