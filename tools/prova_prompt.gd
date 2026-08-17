extends SceneTree
## IL FOGLIO CHE SI DÀ A CHI SCRIVE — costruito da un villaggio VERO.
##
##   CHIBI_PROMPT=/dove ~/Downloads/Godot.app/Contents/MacOS/Godot --path . \
##       --script res://tools/prova_prompt.gd
##
## ────────────────────────────────────────────────────────────────────────
## PERCHÉ ESISTE, VISTO CHE C'È GIÀ `test_suggeritore.gd`
## ────────────────────────────────────────────────────────────────────────
##
## La suite prova che, dato un ritratto, il prompt dice tutto e solo il vero.
## Tutto giusto, e tutto **dentro un dizionario scritto a mano**: prova la
## funzione, non il ponte. Qui invece i ricordi arrivano da dove arrivano in
## partita — Mochi annaffia un'aiuola davvero, costruisce davvero, regala un
## piatto davvero, e un vicino racconta a un altro una cosa che ha visto —
## e il foglio si costruisce dal grafo che ne esce, passando per il cuore
## C++, `debug_grafo`, `debug_grafo_peso` e `debug_emozioni`.
##
## È anche l'unico modo di accorgersi di una intera classe di guasti: un
## ritratto scritto a mano non sbaglia mai una chiave. Il collettore sì.
##
## Alla fine scrive quattro file (nella cartella di `CHIBI_PROMPT`):
##   prompt_esempio.txt       il prompt intero, pronto da dare a un modello
##   prompt_sistema.txt       la sola parte di sistema
##   prompt_utente.txt        la sola parte utente
##   grammatica_esempio.gbnf  la grammatica generata da QUESTO grafo
##
## e stampa le verifiche. Non è una prova «di stampa»: le ultime tre sezioni
## misurano che ogni frase del foglio sia rintracciabile in una riga del
## grafo, che una frase quasi-vera venga bocciata, e che togliendo un ricordo
## la sua frase sparisca da tutte e due le uscite.

const BANCO := preload("res://tools/banco.gd")
const SUG := preload("res://scenes/npc/Suggeritore.gd")
const BRAIN := preload("res://scenes/npc/VillagerBrain.gd")
const PIANI := preload("res://scenes/npc/Piani.gd")
const ORA := preload("res://scenes/ui/OraDelGiorno.gd")

# ------------------------------------------------------------- il villaggio
const CASA_A := Vector2i(4, 6)      # il nostro: quello di cui parlerà la lettera
const CASA_B := Vector2i(9, 4)      # chi ha visto pescare, e glielo racconterà
const AIUOLA := Vector2i(5, 7)      # a due passi da casa A

## Il posto lontano: la costruzione che il nostro vede mentre è in giro.
## Trentacinque metri da casa sua, cioè ben oltre i venticinque della fascia
## grigia — se fosse più vicino, il foglio non direbbe dov'era, e la prova
## non mostrerebbe quel pezzo di frase.
const LONTANO := Vector3(34.0, 0, 32.0)

## Il giorno: 16 cade nella terza settimana, che è l'autunno
## (`DayNight.SEASON_DAYS` = 7). L'ora 0.55 è primo pomeriggio: nessuno è
## ancora rientrato in casa, e chi è dentro non vede niente.
const GIORNO := 16
const OROLOGIO := 0.55

var b
var _dove := ""


func _init() -> void:
	_go()


func _m(c: Vector2i) -> Vector3:
	return Vector3(c.x, 0, c.y)


func _righe(r: Dictionary) -> Array:
	return (b.cuore.call("debug_grafo", int(r["ecs"])) as Dictionary).get("ricordi", [])


## Il grafo com'è adesso, riga per riga: verbo, bandiere, quante, peso. Serve
## a leggere una prova viva quando qualcosa non torna — e il primo giro di
## questa prova è servito esattamente a quello (un ricordo spariva, e senza
## questa stampa la spiegazione più comoda era «il peso è sceso»).
func _dump(r: Dictionary, quando: String) -> void:
	var ritmo: Dictionary = b.cuore.call("debug_ritmo")
	var righe := _righe(r)
	print("       [%s] t=%.1f  %d ricordi" % [quando, float(ritmo["tempo"]), righe.size()])
	for riga in righe:
		var d := riga as Dictionary
		print("         %-11s band=%d quante=%d quando=%.1f peso=%.3f (%.1f,%.1f)"
				% [str(b.cuore.call("nome_verbo", int(d["verbo"]))), int(d["bandiere"]),
				int(d["quante"]), float(d["quando"]),
				float(b.cuore.call("debug_grafo_peso", d, float(ritmo["tempo"]),
						float(ritmo["mezza_vita"]))), float(d["px"]), float(d["pz"])])


## IL GESTO COSTRUITO: la stessa chiamata che fa il gioco. `BuildSystem` e
## `Collection` emettono da dentro l'interazione del giocatore (il cursore
## che posa, la retina che si chiude), che qui non c'è: si chiama il bus
## esattamente come lo chiamano loro — è quello che fa già
## `tools/prova_percezione.gd`, ed è la sola parte della catena che questa
## prova non attraversa dal principio.
func _gesto(verbo: String, pos: Vector3, a_chi := "") -> void:
	call_group("percezione", "accaduto", verbo, pos, a_chi)


func _posa_villaggio() -> bool:
	b.daynight.day = GIORNO
	for c in [CASA_A, CASA_B]:
		b.build.call("place_cell", c, "Letto", 0, false)
		b.build.call("place_cell", c, "Tetto", 0, false)
	b.build.call("place_cell", AIUOLA, "Aiuola", 0, false)
	b.build.call("aggiorna_varchi_ora")
	await create_timer(1.0).timeout
	if (b.build.call("get_placed_by_name", "Aiuola") as Array).is_empty():
		print("GUASTO: l'aiuola non è stata posata")
		return false

	b.visitors.call("debug_reset")
	b.visitors.call("debug_settle", 4242, CASA_A)
	b.visitors.call("debug_settle", 7171, CASA_B)
	await create_timer(1.5).timeout
	var residenti: Array = b.visitors.get("_residents")
	if residenti.size() != 2:
		print("GUASTO: servono due residenti, ce ne sono %d" % residenti.size())
		return false
	b.cuore = b.visitors.call("cuore")
	if b.cuore == null:
		print("GUASTO: il cuore ECS non c'è (GDExtension non caricata?)")
		return false
	return true


## Il chiacchiericcio d'ambiente si zittisce a mano: `_chats` accoppia da sé
## chiunque stia sotto 1,9 m, e la notizia passerebbe LÌ, un istante prima
## della chiacchierata che vogliamo guardare.
func _zitti() -> void:
	b.visitors.set("_chat_acc", 99.0)


func _go() -> void:
	_dove = OS.get_environment("CHIBI_PROMPT")
	b = BANCO.new(self, "")      # nessuna immagine: qui si guardano le parole
	if not await b.apri(OROLOGIO):
		quit(1)
		return
	if not await _posa_villaggio():
		quit(1)
		return
	var rr: Array = b.visitors.get("_residents")
	var ra := rr[0] as Dictionary      # il nostro
	var rb := rr[1] as Dictionary      # quello che gli racconterà del pesce
	var na := ra["node"] as Node3D
	var nb := rb["node"] as Node3D
	print("=== il nostro: %s · l'altro: %s ===" % [ra["label"], rb["label"]])
	_zitti()

	# ============================================ 1) l'annaffiata, e insiste
	print("\n--- 1) Mochi annaffia l'aiuola sotto casa sua, e insiste ---")
	await b.porta(0, _m(CASA_A) + Vector3(1.5, 0, 1.0))
	await b.porta(1, Vector3(-24, 0, -18))
	b.player.global_position = _m(AIUOLA) + Vector3(0.6, 0, 0.6)
	# LA SEMINA SI FA ADESSO, NON PRIMA. `Garden` registra le aiuole in un
	# `_process` differito (`_beds_dirty`), e `debug_set_stage` su una cella
	# che non ha ancora un'aiuola registrata **non fa niente e non lo dice**:
	# lo stage resta a −1, `bed_needing_water` torna null, il ciclo qui sotto
	# esce al primo giro e il gesto non accade mai. Nel primo giro di questa
	# prova il risultato era un grafo senza l'annaffiata e una diagnosi
	# comodissima e sbagliata («il peso è sceso sotto zero»).
	b.garden.call("debug_set_stage", AIUOLA, 1, false)
	await create_timer(0.4).timeout
	var annaffiate := 0
	for _k in 4:
		var aiuola: Node3D = b.garden.call("bed_needing_water", _m(AIUOLA), 2.0)
		if aiuola == null:
			break
		b.garden.call("_water", aiuola)
		annaffiate += 1
		await create_timer(0.35).timeout
		b.garden.call("debug_set_stage", AIUOLA, 1, false)
	b.dico(annaffiate == 4, "Mochi ha annaffiato quattro volte (%d)" % annaffiate)
	_dump(ra, "dopo l'annaffiata")
	b.dico(_righe(ra).size() == 1, "l'annaffiata è UN ricordo, non quattro (la fusione)")

	# ================================== 2) il dono: a lui, e poi a un altro
	print("\n--- 2) un piatto a lui, e uno all'altro mentre lui guarda ---")
	var cucina: Node = b.livello.get_node_or_null("Cooking")
	if cucina != null:
		cucina.set("held_dish", {"name": "Zuppetta", "warm": true, "art": "la"})
	b.player.global_position = na.global_position + Vector3(1.0, 0, 0)
	await create_timer(0.3).timeout
	b.visitors.call("debug_give_dish", 0)
	await create_timer(0.6).timeout
	# e adesso l'altro, portato qui vicino: il nostro lo vede ricevere
	await b.porta(1, na.global_position + Vector3(2.2, 0, 0.6))
	if cucina != null:
		cucina.set("held_dish", {"name": "Zuppetta", "warm": true, "art": "la"})
	b.player.global_position = nb.global_position + Vector3(1.0, 0, 0)
	await create_timer(0.3).timeout
	b.visitors.call("debug_give_dish", 1)
	await create_timer(0.6).timeout
	_dump(ra, "dopo i doni")
	b.dico(_righe(ra).size() == 3, "adesso ha tre ricordi: l'aiuola, il suo dono, quello dell'altro")

	# ============================================ 3) la costruzione, lontano
	print("\n--- 3) in giro, dall'altra parte del villaggio: Mochi costruisce ---")
	await b.porta(0, LONTANO + Vector3(3.0, 0, 2.0))
	await b.porta(1, Vector3(-24, 0, -18))
	b.player.global_position = LONTANO
	await create_timer(0.4).timeout
	_gesto("costruisce", LONTANO)
	await create_timer(0.5).timeout

	# ====================================== 4) il pesce, che lui NON vede
	print("\n--- 4) Mochi pesca dove c'è solo l'altro: il nostro non c'è ---")
	await b.porta(0, _m(CASA_A))
	await b.porta(1, Vector3(-24, 0, -18))
	b.player.global_position = Vector3(-24, 0, -20)
	await create_timer(0.4).timeout
	_gesto("pesca", Vector3(-24, 0, -20))
	await create_timer(0.5).timeout
	_dump(ra, "dopo il pesce")
	b.dico(_righe(ra).size() == 4 and _righe(rb).size() >= 1,
			"il pesce lo sa solo l'altro")

	# =============================================== 5) e glielo racconta
	print("\n--- 5) si incontrano, e l'altro glielo racconta ---")
	await b.porta(1, na.global_position + Vector3(1.2, 0, 0.4))
	_zitti()
	b.visitors.call("_run_chat", nb, na)
	await create_timer(0.6).timeout
	var sentiti := 0
	for riga in _righe(ra):
		if (int((riga as Dictionary)["bandiere"]) & int(b.cuore.R_SENTITO)) != 0:
			sentiti += 1
	_dump(ra, "dopo il racconto")
	b.dico(sentiti == 1, "adesso ha in testa anche una cosa che gli hanno detto")

	# ==================================================== 6) IL FOGLIO
	print("\n--- 6) il foglio ---")
	_dump(ra, "al foglio")
	var rit := _ritratto(ra)
	var testo: String = SUG.componi(rit)
	var gram: String = SUG.grammatica(rit)
	b.dico(testo != "", "il prompt esce")
	print("\n" + "=".repeat(72) + "\n" + testo + "\n" + "=".repeat(72))
	_scrivi("prompt_esempio.txt", testo)
	var p: Dictionary = SUG.parti(rit)
	_scrivi("prompt_sistema.txt", str(p.get("sistema", "")))
	_scrivi("prompt_utente.txt", str(p.get("utente", "")))
	_scrivi("grammatica_esempio.gbnf", gram)

	# =========================== 7) e le verifiche, che sono il vero motivo
	print("\n--- 7) ogni frase del foglio torna a una riga del grafo ---")
	_ogni_frase_ha_un_ricordo(rit, ra)
	_una_frase_quasi_vera_non_passa(rit)
	_togliendo_il_ricordo_sparisce_la_frase(rit)

	_scrivi_le_prove(rit)

	b.sfila()
	quit(b.verdetto("IL FOGLIO PER CHI SCRIVE"))


## SEI LETTERE FINTE, DA DARE A TUTTI E DUE I GUARDIANI. Le scrive su disco
## accanto alla grammatica, con in coda il verdetto di `accetta()`: così chi
## ha in mano llama.cpp può passare gli stessi sei file al suo
## `llama-gbnf-validator` e vedere se la grammatica e il collaudo dicono la
## stessa cosa. Sono due strade diverse verso la stessa promessa, e l'unico
## modo di sapere che non divergono è misurarlo.
func _scrivi_le_prove(rit: Dictionary) -> void:
	var cit: Array = SUG.citazioni(rit)
	var vera := str(cit[0])
	# una citazione BEN FORMATA ma FALSA: stesso vicino, stessa forma, un
	# verbo che il gioco conosce — e che quel vicino non ha mai visto
	# maiuscola inclusa, come una frase vera: se cominciasse minuscola la
	# grammatica la boccerebbe per la ragione SBAGLIATA (una maiuscola in
	# mezzo a una riga libera), e la prova non direbbe niente sul verbo
	var chi := str(rit.get("nome", ""))
	var falsa := "%s%s ti ha vista seminare." % [chi.substr(0, 1).to_upper(), chi.substr(1)]
	var casi := {
		"buona": "non te l'ho detto, e non te lo dirò mai.\n%s\nci ho pensato tutto il pomeriggio, sul mio ramo.\n" % vera,
		"minima": "%s\nresta poco da dire, e va bene così.\n" % vera,
		"falsa": "%s\nresta poco da dire, e va bene così.\n" % falsa,
		"maiuscola": "%s\nCi ho pensato tutto il pomeriggio, sul ramo.\n" % vera,
		"cifra": "%s\nci ho pensato per 3 giorni interi, sai.\n" % vera,
		"nome_minuscolo": "%s\nprugna me lo diceva sempre, quel matto.\n" % vera,
		"senza_chiusura": "%s\n" % vera,
	}
	var riassunto := []
	for nome in casi:
		var esito: Dictionary = SUG.accetta(str(casi[nome]), rit)
		riassunto.append("%-16s collaudo=%s  %s"
				% [nome, "SI" if bool(esito["ok"]) else "no", str(esito["motivo"])])
		print("       %s" % riassunto[riassunto.size() - 1])
		_scrivi("prove/%s.txt" % nome, str(casi[nome]))
	_scrivi("prove/verdetti_del_collaudo.txt", "\n".join(riassunto) + "\n")


# ---------------------------------------------------------------- il ritratto

## IL COLLETTORE, e questa funzione È il pezzo che la suite non può provare:
## mette insieme quello che sanno cinque posti diversi. Se un domani il
## Suggeritore verrà cablato in partita, questa è la forma che il cablaggio
## deve avere — e ogni riga qui sotto legge da dove il dato VIVE, mai da una
## copia.
func _ritratto(r: Dictionary) -> Dictionary:
	var id: int = int(r["ecs"])
	var cervello: RefCounted = b.visitors.call("debug_brain", 0)
	var nome := str(r.get("label", ""))

	# l'età dal Filo Rosso, che è l'unico a saperla
	var legami: Node = get_first_node_in_group("legami")
	var eta := "" if legami == null else str(legami.call("eta_di", nome))

	# l'azione dall'agenda in C++ (indice → nome, con la tabella di
	# VillagerBrain che è la fonte), e l'obiettivo dal pianificatore
	var i_az := int(b.cuore.call("azione", id))
	var azione := "" if (i_az < 0 or i_az >= BRAIN.AZIONI.size()) else str(BRAIN.AZIONI[i_az])
	var obiettivo := str(PIANI.OBIETTIVO.get(azione, ""))

	# chi è ancora nel villaggio: handle → nome. Chi è partito NON è qui, e
	# per questo il suo nome non può finire in una frase.
	var nomi := {}
	for altro in (b.visitors.get("_residents") as Array):
		if (altro as Dictionary).has("ecs"):
			nomi[int(altro["ecs"])] = str(altro.get("label", ""))

	var chi := {
		"nome": nome,
		"eta": eta,
		"indole": (cervello.indole as Array).duplicate(),
		"quirk": str(cervello.quirk),
		"casa": _m(r.get("cell", Vector2i.ZERO)),
		"azione": azione,
		"obiettivo": obiettivo,
	}
	var mondo := {
		"stagione": str(b.daynight.call("season_name")),
		# i sei momenti del giorno sono quelli del gioco, e la traduzione
		# ora→parola vive in un posto solo (`OraDelGiorno.momento`)
		"momento": ORA.momento(int(float(b.daynight.get("time")) * 24.0)),
		"ciclo": float(b.daynight.get("cycle_seconds")),
		"protagonista": "Mochi",
		"nomi": nomi,
		"compito": "lettera",
	}
	return SUG.ritratto(b.cuore, id, chi, mondo)


# ---------------------------------------------------------------- le verifiche

## LA PROVA CHE CONTA: ogni frase che il foglio permette di dire deve
## contenere il verbo di una riga che esiste davvero nel grafo di QUEL
## vicino. Non «somiglia»: si conta.
func _ogni_frase_ha_un_ricordo(rit: Dictionary, r: Dictionary) -> void:
	var righe := _righe(r)
	var citazioni: Array = SUG.citazioni(rit)
	print("       %d frasi ammesse, da %d ricordi veri" % [citazioni.size(), righe.size()])

	# LA PROVENIENZA SI CHIEDE, non si indovina cercando una parola dentro
	# una stringa: ogni fatto porta l'indice della riga da cui viene.
	var orfani := 0
	for f in SUG.fatti(rit):
		var i := int(f["riga"])
		if i < 0 or i >= righe.size():
			orfani += 1
			print("       ORFANA: %s (riga %d, ma il grafo ne ha %d)"
					% [str(f["base"]), i, righe.size()])
			continue
		var verbo := int((righe[i] as Dictionary)["verbo"])
		print("       riga %d (%s) → %s" % [i, str(b.cuore.call("nome_verbo", verbo)), str(f["base"])])
	b.dico(orfani == 0, "ogni frase del foglio porta l'indice del ricordo da cui viene")

	# e il contrario: i verbi che NON sono successi non compaiono da nessuna
	# parte — né nel prompt né nella grammatica
	var verbi_veri := {}
	for riga in righe:
		verbi_veri[str(SUG.INFINITO.get(
				str(b.cuore.call("nome_verbo", int((riga as Dictionary)["verbo"]))), "?"))] = true
	var tutto: String = SUG.componi(rit) + SUG.grammatica(rit)
	var intruse := 0
	for v in SUG.INFINITO.values():
		if tutto.contains(str(v)) and not verbi_veri.has(str(v)):
			intruse += 1
			print("       INTRUSA: «%s» non è mai successo" % str(v))
	b.dico(intruse == 0, "e nessun verbo mai visto compare nel foglio")


## Una frase QUASI vera — lo stesso vicino, un verbo che il gioco conosce, ma
## una cosa che non ha visto — deve essere bocciata. È la lettera che
## inverte l'effetto, ed è l'unica cosa che il collaudo esiste per fermare.
func _una_frase_quasi_vera_non_passa(rit: Dictionary) -> void:
	var falsa := "%s ti ha vista seminare.\nci ho pensato tutto il pomeriggio, sul mio ramo." \
			% str(rit.get("nome", ""))
	var esito: Dictionary = SUG.accetta(falsa, rit)
	b.dico(not bool(esito["ok"]), "una frase quasi vera viene bocciata (%s)" % str(esito["motivo"]))
	var vera: String = str(SUG.citazioni(rit)[0]) \
			+ "\nci ho pensato tutto il pomeriggio, sul mio ramo."
	b.dico(bool(SUG.accetta(vera, rit)["ok"]), "e una vera passa")


## Si toglie una riga dal grafo e si guardano le due uscite: la frase deve
## sparire da tutte e due, e il testo che la usava deve smettere di passare.
func _togliendo_il_ricordo_sparisce_la_frase(rit: Dictionary) -> void:
	var prima: Array = SUG.citazioni(rit)
	var quella := ""
	for c in prima:
		if str(c).contains("annaffiare"):
			quella = str(c)
			break
	if quella == "":
		b.dico(false, "serviva una frase sull'annaffiata da togliere")
		return
	var dopo := rit.duplicate(true)
	var righe: Array = dopo["ricordi"]
	var pesi: PackedFloat64Array = dopo["pesi"]
	for i in righe.size():
		if int((righe[i] as Dictionary)["verbo"]) == int(b.cuore.call("indice_verbo", "annaffia")):
			righe.remove_at(i)
			pesi.remove_at(i)
			break
	dopo["ricordi"] = righe
	dopo["pesi"] = pesi
	var tutto: String = SUG.componi(dopo) + SUG.grammatica(dopo)
	b.dico(not tutto.contains("annaffiare"),
			"tolto il ricordo, la frase sparisce dal prompt E dalla grammatica")
	b.dico(not bool(SUG.accetta(quella + "\nci ho pensato tutto il pomeriggio, sul mio ramo.", dopo)["ok"]),
			"e il testo che la usava non passa più")


func _scrivi(nome: String, testo: String) -> void:
	if _dove == "":
		return
	var percorso := _dove.rstrip("/") + "/" + nome
	DirAccess.make_dir_recursive_absolute(percorso.get_base_dir())
	var f := FileAccess.open(percorso, FileAccess.WRITE)
	if f == null:
		print("       (non riesco a scrivere %s)" % nome)
		return
	# il foglio finisce con un a capo: un file di testo senza l'ultimo a capo
	# fa attaccare il prompt al prossimo pezzo di riga di comando
	f.store_string(testo if testo.ends_with("\n") else testo + "\n")
	f.close()
	print("       scritto %s" % percorso)
