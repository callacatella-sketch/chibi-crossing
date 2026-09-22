extends RefCounted
## COSA SCANDAGLIA L'IMPORTER — la guardia su `src/.gdignore`.
##
## L'importer di Godot scandaglia `src/` sul serio, e SCons scrive gli oggetti
## compilati ACCANTO ai sorgenti. Su macOS e Linux escono `.os` e non succede
## niente; su **Windows** escono `.obj`, e `.obj` per Godot è un formato 3D:
## il `ResourceImporterOBJ` prova a leggere un file COFF di MSVC come un
## Wavefront OBJ.
##
## ⚠️ **E NON È TEORICO: È VIVO NELLA RELEASE.** `release.yml` compila il
## cuore su `windows-latest` (passo «Compila il cuore C++», che lascia 21
## `.obj` in `src/`) e **poi** fa `--import` (passo «Importa le risorse»),
## con `exclude_filter=""` in `export_presets.cfg`. Ventuno oggetti compilati
## dati in pasto all'importer di mesh, a ogni tag.
##
## RIPRODOTTO su Mac, che è l'unico modo di vederlo da qui: copiando un
## `src/*.os` in `src/_prova.obj` e chiedendo un `--import`, Godot risponde
##
##     at: _parse_obj (editor/import/3d/resource_importer_obj.cpp:280)
##     ERROR: Error importing 'res://src/_prova_difetto.obj'.
##
## e lascia uno stub `.import` con `valid=false`. Col `.gdignore`: zero righe,
## nessuno stub.
##
## ⚠️ **LA PROVA CHE È SUCCESSO DAVVERO ERA NEL REPOSITORY.** Cinque
## `src/*.obj.import` erano TRACCIATI in git dal primo commit — orfani, perché
## i `.obj` a cui puntavano non esistono più — e ci erano finiti perché
## `.gitignore` ignorava `*.obj` ma non `*.obj.import`, quindi `git add -A`
## dell'hook di backup se li prendeva. Tolti, e `*.obj.import` aggiunto.
##
## ⚠️ **COSA QUESTA GUARDIA NON PUÒ FARE, dichiarato.** Il difetto vive su
## Windows, e da un Mac non è verificabile: il giudice resta la CI. La prima
## metà è quindi un controllo di ESISTENZA, non un comportamento — ma è un
## fatto (un file c'è o non c'è), non un commento che si matcha da sé, ed è
## falsificabile: si toglie `src/.gdignore` e diventa rossa.
##
## La seconda metà invece è comportamentale, e sorveglia il rischio della
## CURA: quattro test di questo progetto (`test_fiato`, `test_teoria_mente`,
## `test_llm_terreno`, `test_pensatoio`) leggono i sorgenti C++ con
## `FileAccess.open("res://src/...")`. Se un `.gdignore` li rendesse
## irraggiungibili, quelle quattro guardie smetterebbero di giudicare **in
## silenzio** — che è peggio del difetto che si sta curando.


const SORGENTI_DA_LEGGERE := [
	"res://src/ecs_mondo.cpp",
	"res://src/sistema_sonno.h",
	"res://src/intreccio.cpp",
]


func run(t) -> void:
	_la_cartella_degli_oggetti_e_ignorata(t)
	_nessuno_stub_dell_importer_e_rimasto(t)
	_i_sorgenti_restano_leggibili(t)


## `src/` deve portare il suo `.gdignore`: è la sola cosa che tiene gli
## oggetti di MSVC fuori dall'importer, e `src/thirdparty/.gdignore` — che
## esiste da sempre — non copre la cartella che sta sopra.
func _la_cartella_degli_oggetti_e_ignorata(t) -> void:
	t.ok(FileAccess.file_exists("res://src/.gdignore"),
			"src/ ha il suo .gdignore (o l'importer legge i .obj di MSVC come mesh)")
	t.ok(FileAccess.file_exists("res://src/thirdparty/.gdignore"),
			"e src/thirdparty/ tiene comunque il suo, come rete")


## Se ne resta anche uno, o il `.gdignore` non c'è o qualcuno ha importato
## prima di metterlo: in tutti e due i casi è la traccia del difetto.
func _nessuno_stub_dell_importer_e_rimasto(t) -> void:
	var d := DirAccess.open("res://src")
	if d == null:
		t.ok(false, "src/ si apre")
		return
	var stub: Array = []
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		if f.ends_with(".import"):
			stub.append(f)
		f = d.get_next()
	d.list_dir_end()
	t.eq(stub.size(), 0,
			"nessuno stub .import in src/ (trovati: %s)" % str(stub))


## La cura non deve accecare i quattro source-check che leggono il C++.
func _i_sorgenti_restano_leggibili(t) -> void:
	for p in SORGENTI_DA_LEGGERE:
		var fa := FileAccess.open(p, FileAccess.READ)
		t.ok(fa != null, "%s si apre anche con il .gdignore" % p)
		if fa == null:
			continue
		var testo := fa.get_as_text()
		fa.close()
		t.ok(testo.length() > 200,
				"%s ha ancora un contenuto (%d byte)" % [p, testo.length()])
