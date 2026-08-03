class_name BuildCatalog
extends RefCounted

## Il catalogo del builder: pezzi d'arredo procedurali "dipinti a mano".
## Ogni builder restituisce un Node3D con pivot al centro, appoggiato a
## terra (1 cella = 1 metro).
##
## Campi di ogni voce:
##   name     nome mostrato in UI
##   cat      0 Struttura · 1 Arredo · 2 Giardino · 3 Palestra · 4 Chiesa
##   type     "cell" (occupa una cella) | "edge" (sta sul bordo tra due celle)
##   layer    per le celle: 0 pavimenti · 1 tappeti/decori · 2 oggetti
##   builder  Callable che costruisce il visual
##   cols     collisioni: array di [dimensioni Box, posizione centro] con
##            un terzo elemento opzionale: rotazione X (per le rampe)
##   up       true = il pezzo vive al piano di sopra (Solaio, Ponticello)

const HANDPAINT := preload("res://shaders/handpaint.gdshader")
## Le forme che non sono scatole: tubi spazzati lungo una curva e
## superfici di rivoluzione. Vivono in ChibiBuilder perché lì sono nate
## (code, orecchie, musetti): un attrezzo di legno curvo è lo stesso
## problema di geometria, e si risolve con lo stesso strumento.
const BUILDER := preload("res://scenes/npc/ChibiBuilder.gd")

const WOOD := Color("c89a6b")
const WOOD_DARK := Color("a87c50")
const WOOD_PALE := Color("e8cfa8")
const PLASTER := Color("f2e8d5")
const PLASTER_SHADE := Color("e2d4b8")
const TERRACOTTA := Color("d98d6a")
const LEAF := Color("7fbc62")
const LEAF_DARK := Color("5f9c48")
const PINK := Color("f4b8c8")
const PINK_DEEP := Color("eba4b8")
const CREAM := Color("fff3e0")
const STONE := Color("c9c2b4")
const STONE_DARK := Color("a89f92")
const METAL := Color("8a7f72")

# --- la caserma dei pompieri: il rosso lacca e gli ottoni lucidati ---
# Un rosso CALDO, mai da allarme: qui non si spegne niente, si tiene tutto
# pronto — e il pronto, in un villaggio cozy, è una forma di affetto.
const POMPA_ROSSO := Color("d1594e")
const POMPA_ROSSO_SCURO := Color("a8443c")
const OTTONE := Color("d9a441")
const OTTONE_SCURO := Color("b0812c")
const GOMMA := Color("4a4640")
const VETRO := Color("cfe6ee")


static func items() -> Array[Dictionary]:
	return [
		# --- Struttura ---
		{"name": "Pavimento", "cat": 0, "type": "cell", "layer": 0, "builder": _floor_tile, "cols": []},
		{"name": "Sentiero", "cat": 0, "type": "cell", "layer": 0, "builder": _path_tile, "cols": []},
		{"name": "Tappeto", "cat": 0, "type": "cell", "layer": 1, "builder": _rug, "cols": []},
		{"name": "Muro", "cat": 0, "type": "edge", "layer": 2, "builder": _wall,
			"cols": [[Vector3(1.0, 2.1, 0.14), Vector3(0, 1.05, 0)]]},
		{"name": "Finestra", "cat": 0, "type": "edge", "layer": 2, "builder": _window_wall,
			"cols": [[Vector3(1.0, 2.1, 0.14), Vector3(0, 1.05, 0)]]},
		{"name": "Porta", "cat": 0, "type": "edge", "layer": 2, "builder": _door_wall,
			"cols": [[Vector3(0.16, 2.1, 0.14), Vector3(-0.42, 1.05, 0)],
					[Vector3(0.16, 2.1, 0.14), Vector3(0.42, 1.05, 0)]]},
		{"name": "Staccionata", "cat": 0, "type": "edge", "layer": 2, "builder": _fence,
			"cols": [[Vector3(0.95, 0.95, 0.1), Vector3(0, 0.47, 0)]]},
		{"name": "Tetto", "cat": 0, "type": "cell", "layer": 3, "builder": _roof_tile, "cols": []},
		{"name": "Scala", "cat": 0, "type": "cell", "layer": 2, "builder": _stairs,
			"cols": [[Vector3(0.9, 0.12, 2.44), Vector3(0, 1.07, 0), 1.135]]},
		{"name": "Solaio", "cat": 0, "type": "cell", "layer": 0, "up": true, "builder": _floor_slab,
			"cols": [[Vector3(1.0, 0.14, 1.0), Vector3(0, -0.07, 0)]]},
		{"name": "Ponticello", "cat": 0, "type": "cell", "layer": 0, "up": true, "builder": _rope_bridge,
			"cols": [[Vector3(1.0, 0.12, 1.0), Vector3(0, -0.1, 0)]]},
		{"name": "Casa albero", "cat": 0, "type": "cell", "layer": 2, "builder": _treehouse,
			"cols": [[Vector3(0.62, 2.4, 0.62), Vector3(0, 1.2, 0)],
					[Vector3(3.0, 0.12, 3.0), Vector3(0, 2.5, 0)],
					[Vector3(0.7, 0.1, 2.85), Vector3(0, 1.28, 1.95), 1.165]]},

		# --- Arredo ---
		{"name": "Tavolino", "cat": 1, "type": "cell", "layer": 2, "builder": _table,
			"cols": [[Vector3(0.75, 0.72, 0.75), Vector3(0, 0.36, 0)]]},
		{"name": "Sedia", "cat": 1, "type": "cell", "layer": 2, "builder": _chair,
			"cols": [[Vector3(0.46, 0.95, 0.46), Vector3(0, 0.47, 0)]]},
		{"name": "Sgabello", "cat": 1, "type": "cell", "layer": 2, "builder": _stool,
			"cols": [[Vector3(0.4, 0.5, 0.4), Vector3(0, 0.25, 0)]]},
		{"name": "Letto", "cat": 1, "type": "cell", "layer": 2, "builder": _bed,
			"cols": [[Vector3(0.92, 0.55, 0.98), Vector3(0, 0.27, 0)]]},
		{"name": "Libreria", "cat": 1, "type": "cell", "layer": 2, "builder": _bookshelf,
			"cols": [[Vector3(0.9, 1.55, 0.32), Vector3(0, 0.77, 0)]]},
		{"name": "Comodino", "cat": 1, "type": "cell", "layer": 2, "builder": _nightstand,
			"cols": [[Vector3(0.46, 0.55, 0.42), Vector3(0, 0.27, 0)]]},
		{"name": "Camino", "cat": 1, "type": "cell", "layer": 2, "builder": _fireplace,
			"cols": [[Vector3(0.92, 1.1, 0.42), Vector3(0, 0.55, 0)]]},
		{"name": "Lampada", "cat": 1, "type": "cell", "layer": 2, "builder": _lamp,
			"cols": [[Vector3(0.2, 1.75, 0.2), Vector3(0, 0.87, 0)]]},
		# il salone dell'estetista: ci si siede e se ne esce diversi.
		# Le collisioni lasciano libero il DAVANTI (da lì ci si entra):
		# fermano la console dello specchio, la poltrona e il carrello.
		{"name": "Salone", "cat": 1, "type": "cell", "layer": 2, "builder": _salone,
			"cols": [[Vector3(0.82, 1.15, 0.24), Vector3(0, 0.57, -0.33)],
					[Vector3(0.36, 0.66, 0.34), Vector3(0, 0.33, 0.07)],
					[Vector3(0.24, 0.44, 0.20), Vector3(0.40, 0.22, 0.13)]]},

		# l'ANFITEATRO: tre pezzi che si mettono insieme — il palco col
		# fondale, le gradinate da disporre in curva, e il pianoforte.
		# E' grande perche' l'hai fatto grande tu.
		{"name": "Palco", "cat": 0, "type": "cell", "layer": 0, "builder": _palco,
			"cols": []},
		{"name": "Fondale", "cat": 0, "type": "cell", "layer": 2, "builder": _fondale,
			"cols": [[Vector3(1.02, 0.95, 0.30), Vector3(0, 0.50, -0.30)]]},
		{"name": "Gradinata", "cat": 0, "type": "cell", "layer": 2, "builder": _gradinata,
			"cols": [[Vector3(1.04, 0.42, 0.34), Vector3(0, 0.21, -0.10)],
					[Vector3(1.04, 0.68, 0.34), Vector3(0, 0.34, -0.40)]]},
		{"name": "Pianoforte", "cat": 1, "type": "cell", "layer": 2, "builder": _pianoforte,
			"cols": [[Vector3(0.66, 0.34, 0.92), Vector3(0, 0.17, -0.22)]]},

		# --- Giardino ---
		{"name": "Pianta", "cat": 2, "type": "cell", "layer": 2, "builder": _plant,
			"cols": [[Vector3(0.32, 0.55, 0.32), Vector3(0, 0.27, 0)]]},
		{"name": "Aiuola", "cat": 2, "type": "cell", "layer": 1, "builder": _flowerbed, "cols": []},
		{"name": "Orto", "cat": 2, "type": "cell", "layer": 1, "builder": _vegetable_patch, "cols": []},
		{"name": "Alberello", "cat": 2, "type": "cell", "layer": 2, "builder": _sapling,
			"cols": [[Vector3(0.26, 1.3, 0.26), Vector3(0, 0.65, 0)]]},
		{"name": "Cespuglio", "cat": 2, "type": "cell", "layer": 2, "builder": _bush,
			"cols": [[Vector3(0.7, 0.65, 0.7), Vector3(0, 0.32, 0)]]},
		{"name": "Fungo", "cat": 2, "type": "cell", "layer": 2, "builder": _mushroom, "cols": []},
		{"name": "Cassetta posta", "cat": 2, "type": "cell", "layer": 2, "builder": _mailbox,
			"cols": [[Vector3(0.18, 1.1, 0.3), Vector3(0, 0.55, 0)]]},
		{"name": "Panchina", "cat": 2, "type": "cell", "layer": 2, "builder": _bench,
			"cols": [[Vector3(0.95, 0.85, 0.42), Vector3(0, 0.42, 0)]]},
		{"name": "Lavagna", "cat": 2, "type": "cell", "layer": 2, "builder": _blackboard,
			"cols": [[Vector3(1.05, 1.6, 0.16), Vector3(0, 0.8, 0.05)]]},

		# --- PALESTRA (le forme stanno in BuildPalestra.gd) ---
		# Una categoria sua: «Arredo» e «Giardino» sono già righe lunghissime,
		# e questi otto pezzi si scelgono insieme — chi tira su una palestra
		# non vuole scorrere venti sedie per trovare il sacco.
		{"name": "Tappetino", "cat": 3, "type": "cell", "layer": 1,
			"builder": BuildPalestra.tappetino, "cols": []},
		{"name": "Panca dei pesi", "cat": 3, "type": "cell", "layer": 2,
			"builder": BuildPalestra.panca_pesi,
			"cols": [[Vector3(0.62, 0.62, 0.92), Vector3(0, 0.31, 0)],
					[Vector3(0.92, 0.5, 0.14), Vector3(0, 0.8, -0.36)]]},
		{"name": "Sacco", "cat": 3, "type": "cell", "layer": 2,
			"builder": BuildPalestra.sacco,
			"cols": [[Vector3(0.44, 2.0, 0.44), Vector3(0, 1.0, 0.32)],
					[Vector3(0.44, 0.94, 0.44), Vector3(0, 1.52, -0.08)]]},
		{"name": "Cyclette", "cat": 3, "type": "cell", "layer": 2,
			"builder": BuildPalestra.cyclette,
			"cols": [[Vector3(0.5, 1.1, 1.14), Vector3(0, 0.55, -0.11)]]},
		{"name": "Sbarra da trazione", "cat": 3, "type": "cell", "layer": 2,
			"builder": BuildPalestra.sbarra_trazione,
			"cols": [[Vector3(0.3, 2.16, 0.3), Vector3(-0.4, 1.08, 0)],
					[Vector3(0.3, 2.16, 0.3), Vector3(0.4, 1.08, 0)]]},
		{"name": "Specchio", "cat": 3, "type": "cell", "layer": 2,
			"builder": BuildPalestra.specchio,
			"cols": [[Vector3(0.78, 1.7, 0.34), Vector3(0, 0.85, -0.06)]]},
		{"name": "Fontanella", "cat": 3, "type": "cell", "layer": 2,
			"builder": BuildPalestra.fontanella,
			"cols": [[Vector3(0.72, 0.95, 0.62), Vector3(0, 0.48, 0.02)]]},
		{"name": "Rastrelliera", "cat": 3, "type": "cell", "layer": 2,
			"builder": BuildPalestra.rastrelliera,
			"cols": [[Vector3(0.92, 0.78, 0.42), Vector3(0, 0.39, 0)]]},

		# --- CHIESA (le forme stanno in BuildChiesa.gd) ---
		# Categoria sua per lo stesso motivo della palestra: le tre righe
		# storiche sono gia lunghissime, e le scorciatoie 1-9 indicizzano i
		# PRIMI NOVE pezzi della categoria — un pezzo appeso in fondo a
		# «Struttura» non avrebbe mai un tasto. I primi nove qui sono quelli
		# che si piazzano a decine; gli arredi vengono dopo.
		# L'ancora e il Campanile: comprarlo porta tutta la chiesa (Economy.CORREDO).
		{"name": "Muro di pietra", "cat": 4, "type": "edge", "layer": 2,
			"builder": BuildChiesa.muro_pietra,
			"cols": [[Vector3(1.0, 2.1, 0.16), Vector3(0, 1.05, 0)]]},
		{"name": "Lastricato", "cat": 4, "type": "cell", "layer": 0,
			"builder": BuildChiesa.lastricato, "cols": []},
		{"name": "Vetrata", "cat": 4, "type": "edge", "layer": 2,
			"builder": BuildChiesa.vetrata,
			"cols": [[Vector3(1.0, 2.1, 0.16), Vector3(0, 1.05, 0)]]},
		{"name": "Banco", "cat": 4, "type": "cell", "layer": 2,
			"builder": BuildChiesa.banco,
			"cols": [[Vector3(0.95, 0.9, 0.46), Vector3(0, 0.45, -0.06)]]},
		{"name": "Volta", "cat": 4, "type": "cell", "layer": 3,
			"builder": BuildChiesa.volta, "cols": []},
		{"name": "Sagrato", "cat": 4, "type": "cell", "layer": 0,
			"builder": BuildChiesa.sagrato, "cols": []},
		{"name": "Arcata", "cat": 4, "type": "cell", "layer": 2,
			"builder": BuildChiesa.arcata,
			"cols": [[Vector3(0.26, 2.6, 0.26), Vector3(-0.4, 1.3, 0)],
					[Vector3(0.26, 2.6, 0.26), Vector3(0.4, 1.3, 0)]]},
		{"name": "Portale", "cat": 4, "type": "edge", "layer": 2,
			"builder": BuildChiesa.portale,
			"cols": [[Vector3(0.18, 2.1, 0.16), Vector3(-0.41, 1.05, 0)],
					[Vector3(0.18, 2.1, 0.16), Vector3(0.41, 1.05, 0)]]},
		{"name": "Frontone", "cat": 4, "type": "edge", "layer": 2,
			"builder": BuildChiesa.frontone,
			"cols": [[Vector3(1.0, 2.1, 0.16), Vector3(0, 1.05, 0)]]},
		{"name": "Abside", "cat": 4, "type": "cell", "layer": 2,
			"builder": BuildChiesa.abside,
			"cols": [[Vector3(1.0, 2.3, 0.18), Vector3(0, 1.15, -0.41)],
					[Vector3(0.18, 2.3, 0.62), Vector3(-0.41, 1.15, -0.05)],
					[Vector3(0.18, 2.3, 0.62), Vector3(0.41, 1.15, -0.05)]]},
		{"name": "Altare", "cat": 4, "type": "cell", "layer": 2,
			"builder": BuildChiesa.altare,
			"cols": [[Vector3(0.78, 0.95, 0.52), Vector3(0, 0.47, 0)]]},
		{"name": "Candeliere", "cat": 4, "type": "cell", "layer": 2,
			"builder": BuildChiesa.candeliere,
			"cols": [[Vector3(0.6, 0.85, 0.34), Vector3(0, 0.42, 0)]]},
		{"name": "Fonte dei nomi", "cat": 4, "type": "cell", "layer": 2,
			"builder": BuildChiesa.fonte_dei_nomi,
			"cols": [[Vector3(0.52, 0.95, 0.52), Vector3(0, 0.47, 0)]]},
		{"name": "Armonium", "cat": 4, "type": "cell", "layer": 2,
			"builder": BuildChiesa.armonium,
			"cols": [[Vector3(0.8, 0.95, 0.46), Vector3(0, 0.47, -0.02)]]},
		{"name": "Campanile", "cat": 4, "type": "cell", "layer": 2,
			"builder": BuildChiesa.campanile,
			"cols": [[Vector3(0.84, 2.6, 0.84), Vector3(0, 1.3, 0)]]},

		# --- pezzi del NEGOZIO (si comprano dal mercante · vedi Economy.gd) ---
		{"name": "Casetta uccellini", "cat": 2, "type": "cell", "layer": 2, "builder": _birdhouse,
			"cols": [[Vector3(0.28, 1.5, 0.28), Vector3(0, 0.75, 0)]]},
		{"name": "Lampione", "cat": 2, "type": "cell", "layer": 2, "builder": _streetlamp,
			"cols": [[Vector3(0.22, 2.3, 0.22), Vector3(0, 1.15, 0)]]},
		{"name": "Amaca", "cat": 1, "type": "cell", "layer": 2, "builder": _hammock,
			"cols": [[Vector3(0.95, 0.95, 0.4), Vector3(0, 0.45, 0)]]},
		{"name": "Altalena", "cat": 2, "type": "cell", "layer": 2, "builder": _swing,
			"cols": [[Vector3(1.1, 1.65, 0.14), Vector3(0, 0.82, 0)]]},
		{"name": "Fontana", "cat": 2, "type": "cell", "layer": 2, "builder": _fountain,
			"cols": [[Vector3(0.98, 0.6, 0.98), Vector3(0, 0.3, 0)]]},
		{"name": "Gazebo", "cat": 0, "type": "cell", "layer": 2, "builder": _gazebo,
			# sei colonnine ai vertici dell'esagono, piu' il tavolino del te'
			"cols": [[Vector3(0.14, 1.6, 0.14), Vector3(0.860, 0.8, 0.000)],
					[Vector3(0.14, 1.6, 0.14), Vector3(0.430, 0.8, 0.745)],
					[Vector3(0.14, 1.6, 0.14), Vector3(-0.430, 0.8, 0.745)],
					[Vector3(0.14, 1.6, 0.14), Vector3(-0.860, 0.8, 0.000)],
					[Vector3(0.14, 1.6, 0.14), Vector3(-0.430, 0.8, -0.745)],
					[Vector3(0.14, 1.6, 0.14), Vector3(0.430, 0.8, -0.745)],
					[Vector3(0.50, 0.5, 0.50), Vector3(0.0, 0.25, 0.10)]]},
		{"name": "Giostrina", "cat": 2, "type": "cell", "layer": 2, "builder": _carousel,
			"cols": [[Vector3(0.5, 1.6, 0.5), Vector3(0, 0.8, 0)]]},
		{"name": "Braciere stellato", "cat": 1, "type": "cell", "layer": 2, "builder": _brazier,
			"cols": [[Vector3(0.5, 0.8, 0.5), Vector3(0, 0.4, 0)]]},
		{"name": "Bancarella", "cat": 2, "type": "cell", "layer": 2, "builder": _player_stall,
			"cols": [[Vector3(1.3, 1.0, 0.7), Vector3(0, 0.5, 0)]]},
		{"name": "Stendino", "cat": 2, "type": "cell", "layer": 2, "builder": _clothesline,
			"cols": [[Vector3(0.12, 1.15, 0.12), Vector3(-0.55, 0.57, 0)],
					[Vector3(0.12, 1.15, 0.12), Vector3(0.55, 0.57, 0)]]},
		{"name": "Carillon", "cat": 1, "type": "cell", "layer": 2, "builder": _musicbox,
			"cols": [[Vector3(0.45, 0.75, 0.4), Vector3(0, 0.37, 0)]]},
		{"name": "Serra", "cat": 2, "type": "cell", "layer": 2, "builder": _greenhouse,
			"cols": [[Vector3(0.98, 1.35, 0.98), Vector3(0, 0.67, 0)]]},
		{"name": "Mongolfiera", "cat": 2, "type": "cell", "layer": 2, "builder": _balloon,
			"cols": [[Vector3(0.6, 0.7, 0.6), Vector3(0, 0.35, 0)],
					[Vector3(1.05, 1.3, 1.05), Vector3(0, 2.05, 0)]]},

		# --- Il posto di guardia (vedi in fondo al file) ---------------
		# La guardiola è il pezzo-àncora: comprarla porta con sé tutto il
		# corredo (Economy.CORREDO), perché un posto arriva con le sue cose.
		# La guardiola è CAVA: il fronte e i fianchi sono solidi, i quattro
		# smussi hanno il loro tassello d'angolo, e il RETRO resta aperto
		# fra i due tasselli posteriori — è il varco da cui la guardia
		# entra per il turno (il nodo "PostoGuardia" all'interno). Il tetto
		# ha la sua lastra sopra le teste.
		{"name": "Guardiola", "cat": 0, "type": "cell", "layer": 2, "builder": _guardiola,
			"cols": [[Vector3(0.98, 1.8, 0.14), Vector3(0, 0.9, -0.44)],
					[Vector3(0.14, 1.8, 0.98), Vector3(-0.44, 0.9, 0)],
					[Vector3(0.14, 1.8, 0.98), Vector3(0.44, 0.9, 0)],
					[Vector3(0.26, 1.8, 0.26), Vector3(-0.35, 0.9, -0.35)],
					[Vector3(0.26, 1.8, 0.26), Vector3(0.35, 0.9, -0.35)],
					[Vector3(0.26, 1.8, 0.26), Vector3(-0.35, 0.9, 0.35)],
					[Vector3(0.26, 1.8, 0.26), Vector3(0.35, 0.9, 0.35)],
					[Vector3(1.1, 0.5, 1.1), Vector3(0, 2.15, 0)]]},
		{"name": "Insegna guardia", "cat": 0, "type": "edge", "layer": 2,
			"builder": _insegna_guardia,
			"cols": [[Vector3(0.14, 2.0, 0.14), Vector3(-0.36, 1.0, 0)]]},
		{"name": "Sbarra", "cat": 0, "type": "edge", "layer": 2, "builder": _sbarra,
			"cols": [[Vector3(0.2, 0.9, 0.2), Vector3(-0.42, 0.45, 0)]]},
		{"name": "Bancone guardia", "cat": 1, "type": "cell", "layer": 2,
			"builder": _bancone_piantone,
			"cols": [[Vector3(1.0, 0.8, 0.5), Vector3(0, 0.4, 0)]]},
		{"name": "Armadio smarriti", "cat": 1, "type": "cell", "layer": 2,
			"builder": _armadio_smarriti,
			"cols": [[Vector3(0.92, 1.55, 0.45), Vector3(0, 0.77, 0.03)]]},
		{"name": "Bacheca avvisi", "cat": 1, "type": "edge", "layer": 2,
			"builder": _bacheca_avvisi,
			"cols": [[Vector3(1.0, 1.4, 0.12), Vector3(0, 0.7, 0.04)]]},
		{"name": "Attaccapanni", "cat": 1, "type": "cell", "layer": 2,
			"builder": _attaccapanni_berretto,
			"cols": [[Vector3(0.3, 1.55, 0.3), Vector3(0, 0.77, 0)]]},
		{"name": "Brandina", "cat": 1, "type": "cell", "layer": 2, "builder": _brandina_turno,
			"cols": [[Vector3(0.95, 0.5, 0.68), Vector3(0, 0.25, 0)]]},
		{"name": "Lanterna blu", "cat": 2, "type": "cell", "layer": 2,
			"builder": _lanterna_blu,
			"cols": [[Vector3(0.2, 1.8, 0.2), Vector3(0, 0.9, 0)]]},
		{"name": "Cono", "cat": 2, "type": "cell", "layer": 2, "builder": _cono_segnaletico,
			"cols": []},
		{"name": "Transenna", "cat": 2, "type": "edge", "layer": 2, "builder": _transenna,
			"cols": [[Vector3(0.98, 0.75, 0.3), Vector3(0, 0.37, 0)]]},
		{"name": "Bicicletta", "cat": 2, "type": "cell", "layer": 2,
			"builder": _bicicletta_servizio,
			"cols": [[Vector3(0.45, 0.8, 0.9), Vector3(0, 0.4, 0)]]},
		{"name": "Cassetta smarriti", "cat": 2, "type": "cell", "layer": 2,
			"builder": _cassetta_smarriti,
			"cols": [[Vector3(0.45, 1.2, 0.35), Vector3(0, 0.6, 0)]]},

		# --- La caserma dei pompieri (vedi in fondo al file) -----------
		# Stessa regola del posto di guardia: l'Autopompa è l'àncora, e
		# comprarla porta con sé tutto il corredo (Economy.CORREDO).
		{"name": "Autopompa", "cat": 0, "type": "cell", "layer": 2, "builder": _autopompa,
			"cols": [[Vector3(1.5, 0.95, 0.7), Vector3(0, 0.48, 0)]]},
		{"name": "Portone rimessa", "cat": 0, "type": "edge", "layer": 2,
			"builder": _portone_rimessa,
			"cols": [[Vector3(1.0, 2.1, 0.14), Vector3(0, 1.05, 0)]]},
		{"name": "Torretta", "cat": 0, "type": "cell", "layer": 2, "builder": _torretta,
			"cols": [[Vector3(0.78, 1.97, 0.78), Vector3(0, 0.98, 0)]]},
		{"name": "Palo pompieri", "cat": 0, "type": "cell", "layer": 2,
			"builder": _palo_pompieri,
			"cols": [[Vector3(0.16, 2.15, 0.16), Vector3(0, 1.07, 0)]]},
		{"name": "Scala a pioli", "cat": 0, "type": "cell", "layer": 2,
			"builder": _scala_pioli,
			"cols": [[Vector3(0.38, 1.9, 0.34), Vector3(0, 0.95, -0.16)]]},
		{"name": "Insegna caserma", "cat": 0, "type": "edge", "layer": 2,
			"builder": _insegna_caserma,
			"cols": [[Vector3(0.86, 1.3, 0.14), Vector3(0, 0.65, -0.02)]]},
		{"name": "Campana caserma", "cat": 1, "type": "cell", "layer": 2,
			"builder": _campana_caserma,
			"cols": [[Vector3(0.62, 1.15, 0.2), Vector3(-0.1, 0.57, 0)]]},
		{"name": "Casco appeso", "cat": 1, "type": "edge", "layer": 2,
			"builder": _casco_appeso, "cols": []},
		{"name": "Stivali", "cat": 1, "type": "cell", "layer": 2, "builder": _stivali,
			"cols": []},
		{"name": "Secchi", "cat": 1, "type": "cell", "layer": 2, "builder": _secchi,
			"cols": [[Vector3(0.6, 0.45, 0.36), Vector3(0.02, 0.22, -0.04)]]},
		{"name": "Idrante", "cat": 2, "type": "cell", "layer": 2, "builder": _idrante,
			"cols": [[Vector3(0.3, 0.7, 0.3), Vector3(0, 0.35, 0)]]},
		{"name": "Manichetta", "cat": 2, "type": "cell", "layer": 2, "builder": _manichetta,
			"cols": [[Vector3(0.56, 0.58, 0.34), Vector3(0, 0.29, 0)]]},
		{"name": "Faro caserma", "cat": 2, "type": "cell", "layer": 2,
			"builder": _faro_caserma,
			"cols": [[Vector3(0.2, 1.25, 0.2), Vector3(0, 0.62, 0)]]},
		{"name": "Cuccia", "cat": 2, "type": "cell", "layer": 2, "builder": _cuccia_caserma,
			"cols": [[Vector3(0.62, 0.5, 0.56), Vector3(0, 0.25, 0)]]},
		{"name": "Pennone", "cat": 2, "type": "cell", "layer": 2,
			"builder": _pennone_caserma,
			"cols": [[Vector3(0.12, 2.0, 0.12), Vector3(0, 1.0, 0)]]},

		# --- Il bar del paese (vedi in fondo al file) ------------------
		# Il bancone è il pezzo-àncora: comprarlo porta con sé tutto il
		# resto del bar (Economy.CORREDO), come per la guardiola.
		{"name": "Bancone bar", "cat": 0, "type": "cell", "layer": 2,
			"builder": _bancone_bar,
			"cols": [[Vector3(1.06, 1.06, 0.62), Vector3(0, 0.53, 0)]]},
		{"name": "Tenda bar", "cat": 0, "type": "edge", "layer": 2,
			"builder": _tenda_bar, "cols": []},
		{"name": "Insegna bar", "cat": 0, "type": "edge", "layer": 2,
			"builder": _insegna_bar,
			"cols": [[Vector3(0.12, 2.3, 0.12), Vector3(-0.4, 1.15, 0)]]},
		{"name": "Macchina caffè", "cat": 1, "type": "cell", "layer": 2,
			"builder": _macchina_caffe,
			"cols": [[Vector3(0.65, 0.7, 0.4), Vector3(0, 0.35, 0)]]},
		{"name": "Vetrina dolci", "cat": 1, "type": "cell", "layer": 2,
			"builder": _vetrina_dolci,
			"cols": [[Vector3(0.96, 0.96, 0.48), Vector3(0, 0.48, 0)]]},
		{"name": "Sgabello alto", "cat": 1, "type": "cell", "layer": 2,
			"builder": _sgabello_alto,
			"cols": [[Vector3(0.4, 0.8, 0.4), Vector3(0, 0.4, 0)]]},
		{"name": "Mensola bottiglie", "cat": 1, "type": "edge", "layer": 2,
			"builder": _mensola_bottiglie,
			"cols": [[Vector3(0.98, 1.0, 0.24), Vector3(0, 0.9, 0.04)]]},
		{"name": "Tavolino bar", "cat": 1, "type": "cell", "layer": 2,
			"builder": _tavolino_bar,
			"cols": [[Vector3(0.82, 0.78, 0.82), Vector3(0, 0.39, 0)]]},
		{"name": "Sedia vimini", "cat": 1, "type": "cell", "layer": 2,
			"builder": _sedia_vimini,
			"cols": [[Vector3(0.44, 0.9, 0.44), Vector3(0, 0.45, 0)]]},
		{"name": "Lavagnetta", "cat": 1, "type": "cell", "layer": 2,
			"builder": _lavagnetta,
			"cols": [[Vector3(0.56, 0.9, 0.4), Vector3(0, 0.45, 0)]]},
		{"name": "Biliardino", "cat": 1, "type": "cell", "layer": 2,
			"builder": _biliardino,
			"cols": [[Vector3(1.0, 1.0, 0.7), Vector3(0, 0.5, 0)]]},
		{"name": "Ombrellone", "cat": 2, "type": "cell", "layer": 2,
			"builder": _ombrellone,
			"cols": [[Vector3(0.2, 2.2, 0.2), Vector3(0, 1.1, 0)]]},
		{"name": "Fioriera", "cat": 2, "type": "cell", "layer": 2,
			"builder": _fioriera,
			"cols": [[Vector3(1.0, 0.5, 0.4), Vector3(0, 0.25, 0)]]},
		{"name": "Lucine", "cat": 2, "type": "cell", "layer": 2, "builder": _lucine,
			"cols": [[Vector3(0.12, 1.9, 0.12), Vector3(-0.46, 0.95, 0)],
					[Vector3(0.12, 1.9, 0.12), Vector3(0.46, 0.95, 0)]]},
		{"name": "Frigo gelati", "cat": 2, "type": "cell", "layer": 2,
			"builder": _frigo_gelati,
			"cols": [[Vector3(0.96, 0.72, 0.52), Vector3(0, 0.36, 0)]]},

		# --- LA BOUTIQUE (le forme stanno in BuildBoutique.gd) ----------
		# Categoria sua, come la palestra e la chiesa: chi allestisce un
		# negozio sceglie questi quindici pezzi insieme, e non vuole
		# scorrere trenta sedie per trovare lo stender.
		# La Vetrina è l'àncora: comprarla porta con sé tutto il resto
		# (Economy.CORREDO).
		{"name": "Vetrina moda", "cat": 5, "type": "edge", "layer": 2,
			"builder": BuildBoutique.vetrina,
			"cols": [[Vector3(1.0, 2.1, 0.16), Vector3(0, 1.05, 0)],
					[Vector3(0.86, 0.15, 0.38), Vector3(0, 0.07, 0.22)]]},
		{"name": "Insegna boutique", "cat": 5, "type": "edge", "layer": 2,
			"builder": BuildBoutique.insegna, "cols": []},
		{"name": "Manichino", "cat": 5, "type": "cell", "layer": 2,
			"builder": BuildBoutique.manichino,
			"cols": [[Vector3(0.38, 1.15, 0.38), Vector3(0, 0.57, 0)]]},
		{"name": "Busto sartoriale", "cat": 5, "type": "cell", "layer": 2,
			"builder": BuildBoutique.busto,
			"cols": [[Vector3(0.34, 1.12, 0.34), Vector3(0, 0.56, 0)]]},
		{"name": "Stender", "cat": 5, "type": "cell", "layer": 2,
			"builder": BuildBoutique.stender,
			"cols": [[Vector3(0.94, 1.18, 0.44), Vector3(0, 0.59, 0)]]},
		{"name": "Tavolo piegati", "cat": 5, "type": "cell", "layer": 2,
			"builder": BuildBoutique.tavolo_piegati,
			"cols": [[Vector3(0.94, 0.78, 0.64), Vector3(0, 0.39, 0)]]},
		{"name": "Scaffale a giorno", "cat": 5, "type": "edge", "layer": 2,
			"builder": BuildBoutique.scaffale,
			"cols": [[Vector3(1.0, 2.0, 0.34), Vector3(0, 1.0, 0.04)]]},
		{"name": "Camerino", "cat": 5, "type": "cell", "layer": 2,
			"builder": BuildBoutique.camerino,
			"cols": [[Vector3(0.06, 2.0, 0.74), Vector3(-0.45, 1.0, 0.10)],
					[Vector3(0.06, 2.0, 0.74), Vector3(0.45, 1.0, 0.10)],
					[Vector3(0.92, 2.0, 0.08), Vector3(0, 1.0, 0.44)]]},
		{"name": "Specchiera", "cat": 5, "type": "cell", "layer": 2,
			"builder": BuildBoutique.specchiera,
			"cols": [[Vector3(0.88, 1.72, 0.40), Vector3(0, 0.86, 0.10)]]},
		{"name": "Cassa boutique", "cat": 5, "type": "cell", "layer": 2,
			"builder": BuildBoutique.cassa,
			"cols": [[Vector3(1.02, 1.0, 0.56), Vector3(0, 0.5, 0)]]},
		{"name": "Poltroncina", "cat": 5, "type": "cell", "layer": 2,
			"builder": BuildBoutique.poltroncina,
			"cols": [[Vector3(0.56, 0.8, 0.52), Vector3(0, 0.4, 0.05)]]},
		{"name": "Cesto saldi", "cat": 5, "type": "cell", "layer": 2,
			"builder": BuildBoutique.cesto_saldi,
			"cols": [[Vector3(0.7, 0.5, 0.7), Vector3(0, 0.25, 0)]]},
		{"name": "Faretti", "cat": 5, "type": "cell", "layer": 2,
			"builder": BuildBoutique.faretti,
			"cols": [[Vector3(0.34, 1.78, 0.34), Vector3(0, 0.89, 0)]]},
		{"name": "Passatoia", "cat": 5, "type": "cell", "layer": 1,
			"builder": BuildBoutique.passatoia, "cols": []},
		{"name": "Sacchetti", "cat": 5, "type": "cell", "layer": 2,
			"builder": BuildBoutique.sacchetti, "cols": []},
	]


# ---------------------------------------------------------------- helper

static func _mat(a: Color, b: Color, scale := 6.0, amount := 0.5, trans := 0.0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = HANDPAINT
	mat.set_shader_parameter("color_a", a)
	mat.set_shader_parameter("color_b", b)
	mat.set_shader_parameter("noise_scale", scale)
	mat.set_shader_parameter("noise_amount", amount)
	if trans > 0.0:
		mat.set_shader_parameter("translucency", trans)
	return mat


static func _box(parent: Node3D, size: Vector3, mat: Material, pos: Vector3) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


static func _cyl(parent: Node3D, top: float, bottom: float, height: float, mat: Material, pos: Vector3) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


static func _ball(parent: Node3D, radius: float, mat: Material, pos: Vector3, scl := Vector3.ONE) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	parent.add_child(mi)
	return mi


## Un tratto di fune teso fra DUE PUNTI: lunghezza e inclinazione le danno i
## capi, così non restano numeri scelti a mano da riallineare a occhio quando
## l'ancoraggio si sposta. (Gli angoli sono nell'ordine YXZ di Godot: rz porta
## l'asse del cilindro sul piano XY, rx lo inclina in profondità.)
static func _fune(parent: Node3D, da: Vector3, a: Vector3, raggio: float,
		mat: Material) -> MeshInstance3D:
	var d := a - da
	var seg := _cyl(parent, raggio, raggio, d.length(), mat, da + d * 0.5)
	var u := d.normalized()
	seg.rotation = Vector3(atan2(u.z, u.y), 0.0, asin(clampf(-u.x, -1.0, 1.0)))
	return seg


# ---------------------------------------------------------------- struttura

static func _floor_tile() -> Node3D:
	var n := Node3D.new()
	_box(n, Vector3(1.0, 0.05, 1.0), _mat(WOOD_PALE, WOOD, 3.0, 0.55), Vector3(0, 0.025, 0))
	var groove := _mat(WOOD_DARK, WOOD_DARK, 1.0, 0.0)
	for i in 2:
		_box(n, Vector3(1.0, 0.012, 0.015), groove, Vector3(0, 0.052, -0.17 + 0.34 * i))
	return n


static func _path_tile() -> Node3D:
	var n := Node3D.new()
	var mat := _mat(STONE, STONE_DARK, 4.0, 0.55)
	_cyl(n, 0.4, 0.44, 0.05, mat, Vector3(0.05, 0.025, 0.03))
	_cyl(n, 0.16, 0.18, 0.045, mat, Vector3(-0.32, 0.022, -0.3))
	_cyl(n, 0.12, 0.14, 0.04, mat, Vector3(0.35, 0.02, -0.33))
	return n


static func _rug() -> Node3D:
	var n := Node3D.new()
	_cyl(n, 0.46, 0.46, 0.025, _mat(CREAM, Color("f3dfc8"), 5.0, 0.5), Vector3(0, 0.065, 0))
	_cyl(n, 0.32, 0.32, 0.02, _mat(PINK, PINK_DEEP, 5.0, 0.45), Vector3(0, 0.085, 0))
	return n


## Il muro a graticcio: zoccolo di pietra, intonaco fra i legni a vista,
## e i legni che sporgono di un soffio dall'intonaco — è quel gradino di
## profondità (l'ombra che ci si posa dentro) a dire "costruito", non
## "estruso". I muri si AFFIANCANO: ogni linea orizzontale corre per
## tutta la larghezza del modulo, così da un muro all'altro prosegue
## senza cuciture; i montanti stanno DENTRO il modulo (±0.435), mai
## sulla mezzeria condivisa, o due muri adiacenti li sovrapporrebbero
## in z-fighting. La traversa a quota 1.61 è la STESSA dell'architrave
## della Porta: una stanza con porte e finestre ha un'unica linea che
## le lega tutte.
static func _wall() -> Node3D:
	return _ossatura_muro(false)


## L'ossatura condivisa di Muro e Finestra: zoccolo, battiscopa, graticcio
## e trave di colmo sono identici — cambia solo l'INTONACO, che per la
## finestra lascia un'apertura vera (x ±0.29, y 0.89–1.61) invece di
## correre pieno dietro al vetro. La prima stesura riusava il muro pieno
## e ci appoggiava sopra il telaio: da fuori la finestra era un riquadro
## color intonaco — il vetro, incassato, restava sepolto DENTRO il muro.
static func _ossatura_muro(con_apertura: bool) -> Node3D:
	var n := Node3D.new()
	var plaster := _mat(PLASTER, PLASTER_SHADE, 2.5, 0.5)
	var wood := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	var wood_scuro := _mat(WOOD_DARK, Color("8a6540"), 3.5, 0.5)
	var stone := _mat(STONE, STONE_DARK, 3.0, 0.55)

	# lo zoccolo di pietra: il muro non nasce dall'erba, si appoggia a un
	# basamento — la stessa pietra di fiume dei sentieri e della palestra
	_box(n, Vector3(1.0, 0.09, 0.22), stone, Vector3(0, 0.045, 0))
	# il battiscopa di legno, sopra la pietra
	_box(n, Vector3(1.0, 0.07, 0.19), wood, Vector3(0, 0.125, 0))
	# l'intonaco: un filo più sottile dei legni (0.13 contro 0.17), così
	# il graticcio sta in rilievo e si porta dietro la sua ombra
	if con_apertura:
		# quattro campi attorno all'apertura della finestra
		for sx0: float in [-1.0, 1.0]:
			_box(n, Vector3(0.21, 1.84, 0.13), plaster, Vector3(sx0 * 0.395, 1.08, 0))
		_box(n, Vector3(0.58, 0.75, 0.13), plaster, Vector3(0, 0.535, 0))
		_box(n, Vector3(0.58, 0.41, 0.13), plaster, Vector3(0, 1.795, 0))
	else:
		_box(n, Vector3(1.0, 1.84, 0.13), plaster, Vector3(0, 1.08, 0))
	# i due montanti del graticcio
	for sx: float in [-1.0, 1.0]:
		_box(n, Vector3(0.09, 1.84, 0.17), wood, Vector3(sx * 0.435, 1.08, 0))
	# la traversa: prosegue l'architrave della Porta (quota 1.61) e divide
	# l'intonaco in due campi, come in un graticcio vero
	_box(n, Vector3(1.0, 0.08, 0.17), wood, Vector3(0, 1.61, 0))
	# i cavicchi al giunto montante-traversa: passano da parte a parte,
	# le testine si vedono su entrambe le facce
	for sx2: float in [-1.0, 1.0]:
		var cav := _cyl(n, 0.013, 0.013, 0.19, wood_scuro, Vector3(sx2 * 0.435, 1.61, 0))
		cav.rotation.x = PI * 0.5
	# le mensoline sotto la trave di colmo, in asse coi montanti: il
	# gradino d'ombra che fa da capitello
	for sx3: float in [-1.0, 1.0]:
		_box(n, Vector3(0.07, 0.07, 0.2), wood, Vector3(sx3 * 0.435, 1.965, 0))
	# la trave di colmo col suo coprigiunto scuro: due piani sfalsati
	# prendono la luce in modo diverso, un box solo no
	_box(n, Vector3(1.0, 0.08, 0.18), wood, Vector3(0, 2.04, 0))
	_box(n, Vector3(1.0, 0.03, 0.22), wood_scuro, Vector3(0, 2.095, 0))
	return n


## La finestra: telaio VERO (montanti e traverse che sporgono dal muro,
## non un box pieno con il vetro appiccicato sopra), vetro INCASSATO fra
## le due facce — è il rientro a dire "qui il muro si apre" — davanzale
## sporgente su entrambi i lati e una fioriera coi fiori sul fronte (-Z:
## il giocatore la gira col flip del pezzo). La traversa del graticcio a
## 1.61 fa da architrave alla finestra, senza pezzi in più.
##
## ATTENZIONE, contratto con PozzeDiLuce._trova_vetro(): il vetro deve
## restare FIGLIO DIRETTO di questo nodo, ed essere l'unico figlio col
## StandardMaterial3D a emissione — è così che la sera lo trova e lo
## scalda. Le lame di riflesso qui sotto sono additive SENZA emissione
## proprio per non fargli ombra.
static func _window_wall() -> Node3D:
	var n := _ossatura_muro(true)
	var wood := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	var wood_scuro := _mat(WOOD_DARK, Color("8a6540"), 3.5, 0.5)

	# il telaio: due montanti e due traverse, in rilievo sull'intonaco
	for sx: float in [-1.0, 1.0]:
		_box(n, Vector3(0.07, 0.68, 0.19), wood, Vector3(sx * 0.255, 1.25, 0))
	_box(n, Vector3(0.58, 0.06, 0.19), wood, Vector3(0, 0.94, 0))
	_box(n, Vector3(0.58, 0.05, 0.19), wood, Vector3(0, 1.565, 0))

	# il vetro, sottile e INCASSATO: sta a metà dello spessore del muro,
	# arretrato rispetto a entrambe le facce (il vecchio vetro sporgeva
	# fuori dal telaio, e una lastra a filo muro è una vetrofania)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color("cfe8f5")
	glass.emission_enabled = true
	glass.emission = Color("bfe0f2")
	glass.emission_energy_multiplier = 0.35
	glass.roughness = 0.2
	_box(n, Vector3(0.5, 0.6, 0.05), glass, Vector3(0, 1.25, 0))

	# la crociera, più fine del telaio: è la parte che si guarda in
	# controluce, e due barre grosse fanno una grata
	var bar := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	_box(n, Vector3(0.46, 0.03, 0.08), bar, Vector3(0, 1.25, 0))
	_box(n, Vector3(0.03, 0.58, 0.08), bar, Vector3(0, 1.25, 0))

	# il davanzale, sporgente su entrambe le facce: dentro casa è la
	# mensola del gatto, fuori è il cappello della fioriera. Sale di un
	# soffio DENTRO la traversa bassa del telaio (0.915 contro 0.91):
	# due facce esattamente a filo si tagliano con una cucitura chiara
	_box(n, Vector3(0.7, 0.055, 0.26), wood, Vector3(0, 0.8875, 0))

	# due lame di riflesso oblique, una per faccia: additive e SENZA
	# emissione (vedi il contratto con PozzeDiLuce qui sopra) — è il
	# trucco già collaudato dallo specchio della palestra
	var lama := StandardMaterial3D.new()
	lama.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lama.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lama.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	lama.albedo_color = Color(1, 1, 1, 0.3)
	for sz: float in [-1.0, 1.0]:
		var l := _box(n, Vector3(0.05, 0.4, 0.004), lama, Vector3(-0.04, 1.27, sz * 0.028))
		l.rotation.z = 0.45

	# LA FIORIERA, sul fronte: la cassetta di legno con l'orlo chiaro e le
	# staffe che la reggono al muro (una cassetta senza staffe fluttua),
	# il verde che TRABOCCA oltre il bordo — è la fogliolina che ricade
	# davanti a rompere la linea dritta della cassetta — e quattro fiori
	# nei rosa del villaggio, ad altezze diverse: una fila di fiori tutti
	# alla stessa quota è un pettine, non un'aiuola. È il dettaglio che
	# trasforma "un'apertura nel muro" in "qualcuno abita qui".
	_box(n, Vector3(0.52, 0.09, 0.08), wood_scuro, Vector3(0, 0.81, -0.17))
	# l'orlo chiaro della cassetta, e le due staffe fino al muro
	_box(n, Vector3(0.54, 0.022, 0.095), wood, Vector3(0, 0.851, -0.17))
	for sxf: float in [-1.0, 1.0]:
		_box(n, Vector3(0.035, 0.055, 0.14), wood_scuro, Vector3(sxf * 0.19, 0.75, -0.135))
	var verde := _mat(LEAF, LEAF_DARK, 5.0, 0.5)
	_ball(n, 0.055, verde, Vector3(-0.15, 0.872, -0.175), Vector3(1.2, 0.75, 0.85))
	_ball(n, 0.058, verde, Vector3(0.02, 0.878, -0.17), Vector3(1.25, 0.8, 0.8))
	_ball(n, 0.055, verde, Vector3(0.17, 0.87, -0.175), Vector3(1.1, 0.72, 0.85))
	# le foglie che ricadono oltre l'orlo, davanti alla cassetta
	_ball(n, 0.04, verde, Vector3(-0.08, 0.815, -0.212), Vector3(0.9, 1.3, 0.55))
	_ball(n, 0.036, verde, Vector3(0.12, 0.8, -0.21), Vector3(0.85, 1.2, 0.5))
	var rosa := _mat(PINK, PINK_DEEP, 4.0, 0.4)
	var crema := _mat(CREAM, Color("f3dfc8"), 4.0, 0.4)
	var rosa_fondo := _mat(PINK_DEEP, PINK, 4.0, 0.4)
	_ball(n, 0.026, rosa, Vector3(-0.19, 0.9, -0.2))
	_ball(n, 0.022, crema, Vector3(-0.05, 0.932, -0.198))
	_ball(n, 0.025, rosa_fondo, Vector3(0.08, 0.888, -0.202))
	_ball(n, 0.021, rosa, Vector3(0.2, 0.915, -0.198))
	return n


static func _door_wall() -> Node3D:
	# muro con porta socchiusa: il varco centrale è attraversabile
	var n := Node3D.new()
	var plaster := _mat(PLASTER, PLASTER_SHADE, 2.5, 0.5)
	var wood := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	for side: float in [-1.0, 1.0]:
		_box(n, Vector3(0.16, 2.0, 0.14), plaster, Vector3(side * 0.42, 1.0, 0))
	_box(n, Vector3(1.0, 0.44, 0.14), plaster, Vector3(0, 1.78, 0))
	_box(n, Vector3(1.0, 0.08, 0.18), wood, Vector3(0, 2.04, 0))
	# il coprigiunto scuro sul colmo: la stessa linea del Muro e della
	# Finestra, così la corona corre ininterrotta lungo tutta la casa
	_box(n, Vector3(1.0, 0.03, 0.22), _mat(WOOD_DARK, Color("8a6540"), 3.5, 0.5),
			Vector3(0, 2.095, 0))
	_box(n, Vector3(0.76, 0.1, 0.16), wood, Vector3(0, 1.61, 0))
	for side: float in [-1.0, 1.0]:
		_box(n, Vector3(0.08, 1.56, 0.16), wood, Vector3(side * 0.38, 0.78, 0))
	# l'anta: riempie tutto il varco (0.68 × 1.56, a filo di stipiti e
	# architrave). Chiusa di default, il BuildSystem la apre all'avvicinarsi.
	var hinge := Node3D.new()
	hinge.name = "Hinge"
	hinge.position = Vector3(-0.34, 0, 0)
	n.add_child(hinge)
	var door_mat := _mat(Color("b3805a"), Color("96683f"), 3.0, 0.55)
	_box(hinge, Vector3(0.68, 1.56, 0.05), door_mat, Vector3(0.34, 0.78, 0))
	# doghe decorative
	var slat := _mat(Color("a2734e"), Color("8a5f3e"), 2.0, 0.4)
	_box(hinge, Vector3(0.56, 0.03, 0.055), slat, Vector3(0.34, 0.5, 0))
	_box(hinge, Vector3(0.56, 0.03, 0.055), slat, Vector3(0.34, 1.06, 0))
	_ball(hinge, 0.032, _mat(CREAM, WOOD_PALE, 4.0, 0.3), Vector3(0.6, 0.82, 0.05))
	return n


static func _fence() -> Node3D:
	var n := Node3D.new()
	var mat := _mat(WOOD_PALE, WOOD, 3.5, 0.5)
	for x in [-0.38, 0.38]:
		_box(n, Vector3(0.09, 0.85, 0.09), mat, Vector3(x, 0.425, 0))
		_ball(n, 0.06, mat, Vector3(x, 0.88, 0), Vector3(1, 0.7, 1))
	_box(n, Vector3(0.95, 0.08, 0.05), mat, Vector3(0, 0.62, 0))
	_box(n, Vector3(0.95, 0.08, 0.05), mat, Vector3(0, 0.32, 0))
	return n


static func _roof_tile() -> Node3D:
	# lastra di coppi: si affianca cella per cella sopra i muri (h 2.0)
	var n := Node3D.new()
	_box(n, Vector3(1.02, 0.1, 1.02), _mat(Color("d97e5f"), Color("c26847"), 3.0, 0.55), Vector3(0, 2.06, 0))
	var ridge := _mat(Color("b55c3e"), Color("a34f34"), 2.0, 0.4)
	for i in 3:
		_box(n, Vector3(1.02, 0.035, 0.07), ridge, Vector3(0, 2.115, -0.3 + 0.3 * i))
	# la pioggia si ferma sulle tegole: dentro casa non piove
	var pcol := GPUParticlesCollisionBox3D.new()
	pcol.size = Vector3(1.04, 0.14, 1.04)
	pcol.position = Vector3(0, 2.06, 0)
	n.add_child(pcol)
	return n


# ---------------------------------------------------------------- arredo

static func _table() -> Node3D:
	var n := Node3D.new()
	var wood := _mat(WOOD, WOOD_DARK, 4.0, 0.55)
	_cyl(n, 0.42, 0.42, 0.06, _mat(WOOD_PALE, WOOD, 3.0, 0.5), Vector3(0, 0.63, 0))
	_cyl(n, 0.055, 0.07, 0.6, wood, Vector3(0, 0.3, 0))
	_cyl(n, 0.2, 0.24, 0.05, wood, Vector3(0, 0.025, 0))
	return n


static func _chair() -> Node3D:
	var n := Node3D.new()
	var wood := _mat(WOOD, WOOD_DARK, 4.0, 0.55)
	_box(n, Vector3(0.42, 0.06, 0.42), wood, Vector3(0, 0.45, 0))
	for x in [-0.17, 0.17]:
		for z in [-0.17, 0.17]:
			_box(n, Vector3(0.055, 0.45, 0.055), wood, Vector3(x, 0.225, z))
	var back := _box(n, Vector3(0.42, 0.55, 0.05), wood, Vector3(0, 0.75, -0.19))
	back.rotation.x = 0.08
	_cyl(n, 0.17, 0.17, 0.05, _mat(PINK, PINK_DEEP, 5.0, 0.4), Vector3(0, 0.505, 0.01))
	return n


static func _stool() -> Node3D:
	var n := Node3D.new()
	var wood := _mat(WOOD, WOOD_DARK, 4.0, 0.55)
	_cyl(n, 0.19, 0.21, 0.06, wood, Vector3(0, 0.4, 0))
	for i in 4:
		var a := (float(i) + 0.5) / 4.0 * TAU
		var leg := _box(n, Vector3(0.05, 0.4, 0.05), wood, Vector3(cos(a) * 0.13, 0.2, sin(a) * 0.13))
		leg.rotation.z = cos(a) * 0.12
		leg.rotation.x = -sin(a) * 0.12
	_cyl(n, 0.16, 0.16, 0.05, _mat(Color("bfe0c8"), Color("a8ccb2"), 5.0, 0.4), Vector3(0, 0.45, 0))
	return n


static func _bed() -> Node3D:
	var n := Node3D.new()
	var wood := _mat(WOOD, WOOD_DARK, 4.0, 0.55)
	_box(n, Vector3(0.92, 0.22, 0.98), wood, Vector3(0, 0.11, 0))
	_box(n, Vector3(0.92, 0.5, 0.07), wood, Vector3(0, 0.35, -0.46))
	_box(n, Vector3(0.86, 0.12, 0.9), _mat(CREAM, Color("f3e6d0"), 4.0, 0.4), Vector3(0, 0.28, 0))
	_box(n, Vector3(0.5, 0.1, 0.26), _mat(Color.WHITE, Color("f0ecdf"), 5.0, 0.35), Vector3(0, 0.37, -0.3))
	_box(n, Vector3(0.88, 0.07, 0.55), _mat(PINK, PINK_DEEP, 3.0, 0.5), Vector3(0, 0.35, 0.18))
	return n


static func _bookshelf() -> Node3D:
	# guscio aperto sul fronte (-Z): schiena, fianchi, cima e base, coi
	# ripiani e i libri BEN visibili — e la cima libera per la collezione
	var n := Node3D.new()
	var wood := _mat(WOOD, WOOD_DARK, 4.0, 0.55)
	var pale := _mat(WOOD_PALE, WOOD, 3.0, 0.45)
	_box(n, Vector3(0.9, 1.55, 0.06), pale, Vector3(0, 0.775, 0.12))
	for side in [-0.435, 0.435]:
		_box(n, Vector3(0.06, 1.55, 0.3), wood, Vector3(side, 0.775, 0))
	_box(n, Vector3(0.9, 0.06, 0.3), wood, Vector3(0, 1.52, 0))
	_box(n, Vector3(0.9, 0.06, 0.3), wood, Vector3(0, 0.03, 0))
	for row in 3:
		var base_y := 0.06 + row * 0.48
		if row > 0:
			_box(n, Vector3(0.78, 0.04, 0.26), wood, Vector3(0, base_y - 0.02, 0))
		var rng := RandomNumberGenerator.new()
		rng.seed = row * 17 + 3
		var x := -0.36
		while x < 0.3:
			var w := rng.randf_range(0.055, 0.09)
			var h := rng.randf_range(0.24, 0.36)
			var col: Color = [Color("d97f7f"), Color("7fa8d9"), Color("d9c27f"), Color("8fbc8a"), Color("b78ac2")][rng.randi() % 5]
			_box(n, Vector3(w, h, 0.2), _mat(col, col.darkened(0.2), 6.0, 0.4),
					Vector3(x + w * 0.5, base_y + h * 0.5, -0.02))
			x += w + rng.randf_range(0.005, 0.03)
	return n


static func _nightstand() -> Node3D:
	var n := Node3D.new()
	var wood := _mat(WOOD, WOOD_DARK, 4.0, 0.55)
	_box(n, Vector3(0.45, 0.45, 0.4), wood, Vector3(0, 0.28, 0))
	_box(n, Vector3(0.36, 0.16, 0.03), _mat(WOOD_PALE, WOOD, 3.0, 0.45), Vector3(0, 0.34, 0.2))
	_ball(n, 0.025, _mat(CREAM, WOOD_PALE, 4.0, 0.3), Vector3(0, 0.34, 0.225))
	# candelina
	_cyl(n, 0.035, 0.035, 0.09, _mat(CREAM, Color("f3e6d0"), 5.0, 0.35), Vector3(0.1, 0.55, 0))
	var flame := StandardMaterial3D.new()
	flame.albedo_color = Color("ffd382")
	flame.emission_enabled = true
	flame.emission = Color("ffb84d")
	flame.emission_energy_multiplier = 2.5
	_ball(n, 0.02, flame, Vector3(0.1, 0.62, 0), Vector3(1, 1.5, 1))
	return n


static func _fireplace() -> Node3D:
	var n := Node3D.new()
	var stone := _mat(STONE, STONE_DARK, 3.0, 0.55)
	_box(n, Vector3(0.9, 0.9, 0.4), stone, Vector3(0, 0.45, 0))
	_box(n, Vector3(1.0, 0.1, 0.48), _mat(WOOD, WOOD_DARK, 4.0, 0.5), Vector3(0, 0.95, 0))
	_box(n, Vector3(0.54, 0.5, 0.42), _mat(Color("3a3230"), Color("2a2422"), 3.0, 0.4), Vector3(0, 0.32, 0.01))
	# braci
	var coal := StandardMaterial3D.new()
	coal.albedo_color = Color("ff9440")
	coal.emission_enabled = true
	coal.emission = Color("ff7a26")
	coal.emission_energy_multiplier = 1.8
	_ball(n, 0.06, coal, Vector3(-0.08, 0.12, 0.08), Vector3(1, 0.6, 1))
	_ball(n, 0.05, coal, Vector3(0.09, 0.11, 0.05), Vector3(1, 0.6, 1))

	# fuoco
	var tex := GradientTexture2D.new()
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	grad.colors = PackedColorArray([Color(1.0, 0.85, 0.4, 0.9), Color(1.0, 0.55, 0.2, 0.5), Color(1.0, 0.4, 0.1, 0.0)])
	tex.gradient = grad
	var quad := QuadMesh.new()
	quad.size = Vector2(0.16, 0.16)
	var fmat := StandardMaterial3D.new()
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fmat.albedo_texture = tex
	fmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	fmat.vertex_color_use_as_albedo = true
	quad.material = fmat
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.16, 0.02, 0.1)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 12.0
	pm.initial_velocity_min = 0.25
	pm.initial_velocity_max = 0.5
	pm.gravity = Vector3(0, 0.6, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.0)])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex
	var fire := GPUParticles3D.new()
	fire.amount = 16
	fire.lifetime = 0.7
	fire.process_material = pm
	fire.draw_pass_1 = quad
	fire.position = Vector3(0, 0.16, 0.05)
	n.add_child(fire)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.7, 0.4)
	light.light_energy = 1.1
	light.omni_range = 3.2
	light.position = Vector3(0, 0.4, 0.3)
	n.add_child(light)

	# il COMIGNOLO: la canna che sale sopra la mensola e il vaso in
	# terracotta col cappello. È da qui che la sera esce il filo di fumo
	# (l'emettitore lo aggancia VitaSecondaria, in cima alla canna)
	_box(n, Vector3(0.34, 0.52, 0.3), stone, Vector3(0, 1.26, 0))
	_box(n, Vector3(0.42, 0.06, 0.38), _mat(TERRACOTTA, Color("c47a58"), 3.0, 0.5),
			Vector3(0, 1.55, 0))
	_cyl(n, 0.085, 0.105, 0.18, _mat(TERRACOTTA, Color("c47a58"), 3.0, 0.5),
			Vector3(0, 1.65, 0))
	_box(n, Vector3(0.26, 0.035, 0.26), stone, Vector3(0, 1.78, 0))
	return n


static func _lamp() -> Node3D:
	var n := Node3D.new()
	var metal := _mat(METAL, Color("6f665b"), 5.0, 0.4)
	_cyl(n, 0.11, 0.15, 0.06, metal, Vector3(0, 0.03, 0))
	_cyl(n, 0.028, 0.035, 1.45, metal, Vector3(0, 0.78, 0))
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color("ffe6b0")
	glow.emission_enabled = true
	glow.emission = Color("ffd382")
	glow.emission_energy_multiplier = 2.2
	_ball(n, 0.16, glow, Vector3(0, 1.6, 0))
	_cyl(n, 0.05, 0.19, 0.1, metal, Vector3(0, 1.74, 0))
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.86, 0.6)
	light.light_energy = 1.6
	light.omni_range = 4.5
	light.omni_attenuation = 1.4
	light.position = Vector3(0, 1.58, 0)
	n.add_child(light)
	return n


# ---------------------------------------------------------------- giardino

static func _plant() -> Node3D:
	var n := Node3D.new()
	_cyl(n, 0.17, 0.12, 0.22, _mat(TERRACOTTA, Color("bd7455"), 4.0, 0.5), Vector3(0, 0.11, 0))
	_cyl(n, 0.13, 0.13, 0.03, _mat(Color("6a4a38"), Color("53382a"), 6.0, 0.4), Vector3(0, 0.225, 0))
	var leaf := _mat(LEAF, LEAF_DARK, 3.0, 0.6)
	_ball(n, 0.17, leaf, Vector3(0, 0.42, 0))
	_ball(n, 0.12, leaf, Vector3(0.1, 0.52, 0.05))
	_ball(n, 0.11, leaf, Vector3(-0.1, 0.5, -0.04))
	_ball(n, 0.035, _mat(PINK, Color("ffd7e2"), 6.0, 0.4), Vector3(0.05, 0.62, 0.02))
	return n


static func _flowerbed() -> Node3D:
	# aiuola da giardinaggio: terra smossa pronta per i semi. I germogli e
	# i fiori li fa crescere il sistema Garden, notte dopo notte.
	var n := Node3D.new()
	_cyl(n, 0.44, 0.46, 0.07, _mat(Color("7a5a42"), Color("64483a"), 4.0, 0.5), Vector3(0, 0.035, 0))
	# solchi di semina
	var furrow := _mat(Color("5e4534"), Color("50392c"), 3.0, 0.4)
	for i in 3:
		_box(n, Vector3(0.58, 0.012, 0.055), furrow, Vector3(0, 0.071, -0.2 + 0.2 * i))
	# sassolini sul bordo
	var pebble := _mat(Color("c9c2b4"), Color("a89f92"), 5.0, 0.5)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 7:
		var a := float(i) / 7.0 * TAU + 0.2
		_ball(n, rng.randf_range(0.03, 0.045), pebble,
				Vector3(cos(a) * 0.44, 0.035, sin(a) * 0.44), Vector3(1, 0.7, 1))
	return n


static func _vegetable_patch() -> Node3D:
	# l'orto: terra squadrata coi solchi e i picchetti agli angoli.
	# Semina, annaffia e il Garden fa crescere carote, zucche o bacche.
	var n := Node3D.new()
	_box(n, Vector3(0.92, 0.07, 0.92), _mat(Color("6f5240"), Color("5a4234"), 4.0, 0.5), Vector3(0, 0.035, 0))
	var furrow := _mat(Color("543d2e"), Color("463327"), 3.0, 0.4)
	for i in 3:
		_box(n, Vector3(0.8, 0.014, 0.07), furrow, Vector3(0, 0.072, -0.24 + 0.24 * i))
	var stake := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	for sx in [-0.42, 0.42]:
		for sz in [-0.42, 0.42]:
			_box(n, Vector3(0.05, 0.24, 0.05), stake, Vector3(sx, 0.12, sz))
	return n


static func _blackboard() -> Node3D:
	# la lavagna del villaggio: i nuovi abitanti ci scrivono il loro
	# compleanno, il Calendario ci appende gli eventi. Fronte verso -Z.
	var n := Node3D.new()
	var wood := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	for sx: float in [-0.48, 0.48]:
		_box(n, Vector3(0.09, 1.6, 0.09), wood, Vector3(sx, 0.8, 0.06))
	_box(n, Vector3(1.06, 0.1, 0.1), wood, Vector3(0, 1.52, 0.05))
	_box(n, Vector3(1.06, 0.08, 0.1), wood, Vector3(0, 0.42, 0.05))
	# il quadro nero-verde, appena inclinato all'indietro
	var slate := _box(n, Vector3(0.94, 1.02, 0.05),
			_mat(Color("3d4a40"), Color("32403a"), 5.0, 0.35), Vector3(0, 0.97, 0.06))
	slate.rotation.x = 0.05
	# la vaschetta dei gessetti, coi gessetti
	_box(n, Vector3(0.9, 0.05, 0.12), wood, Vector3(0, 0.47, -0.02))
	_box(n, Vector3(0.12, 0.025, 0.025), _mat(Color("fff8ee"), Color("efe6da"), 6.0, 0.3),
			Vector3(-0.2, 0.51, -0.02))
	_box(n, Vector3(0.1, 0.025, 0.025), _mat(Color("f4c2cf"), Color("e8aebe"), 6.0, 0.3),
			Vector3(0.14, 0.51, -0.02))
	return n


# ------------------------------------------------- verticalità

static func _stairs() -> Node3D:
	# scala di legno ripida ma percorribile: sale verso -Z (R per girarla)
	var n := Node3D.new()
	var step_mat := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	var dark := _mat(WOOD_DARK, Color("8a6440"), 4.0, 0.5)
	for i in 8:
		var y := (float(i) + 0.5) * 0.269
		var z := 0.4375 - float(i) * 0.125
		_box(n, Vector3(0.86, 0.269, 0.125), step_mat, Vector3(0, y, z))
	# fiancate e corrimano inclinati
	for sx: float in [-0.45, 0.45]:
		var stringer := _box(n, Vector3(0.06, 0.16, 2.44), dark, Vector3(sx, 1.07, 0))
		stringer.rotation.x = 1.135
		var rail := _box(n, Vector3(0.05, 0.07, 2.5), step_mat, Vector3(sx, 1.85, 0))
		rail.rotation.x = 1.135
		# I PILASTRINI SI RICAVANO DALLE DUE RETTE, non si mettono a occhio.
		# Cosciale e corrimano sono paralleli (stessa rotazione, 1.135 rad:
		# 0.906 di salita ogni 0.423 di corsa, cioè 2.142 di pendenza), e a
		# una data z passano per 1.07 − 2.142·z e 1.85 − 2.142·z. Messi a
		# mano erano lunghi uguali a tutte le quote: in basso pendevano sotto
		# il cosciale nel vuoto, in alto si fermavano mezzo metro prima del
		# corrimano. Un parapetto senza un punto d'attacco visibile.
		for t: float in [0.12, 0.88]:
			var pz := 0.4 - t * 0.8
			var y_rampa := 1.07 - 2.142 * pz + 0.06     # dentro il cosciale
			var y_mano := 1.85 - 2.142 * pz - 0.03      # dentro il corrimano
			_box(n, Vector3(0.06, y_mano - y_rampa, 0.06), dark,
					Vector3(sx, (y_rampa + y_mano) * 0.5, pz))
	return n


static func _floor_slab() -> Node3D:
	# il solaio: assito di legno col piano di calpestio a y 0 (vive già
	# alzato a quota piano: le travi sotto si vedono da giù)
	var n := Node3D.new()
	_box(n, Vector3(1.0, 0.08, 1.0), _mat(WOOD_PALE, WOOD, 5.0, 0.4), Vector3(0, -0.04, 0))
	var dark := _mat(WOOD_DARK, Color("8a6440"), 4.0, 0.5)
	for gz: float in [-0.17, 0.17]:
		_box(n, Vector3(1.0, 0.006, 0.018), dark, Vector3(0, 0.002, gz))
	for bx: float in [-0.42, 0.42]:
		_box(n, Vector3(0.09, 0.1, 1.0), dark, Vector3(bx, -0.12, 0))
	return n


static func _rope_bridge() -> Node3D:
	# ponticello di corda: assi che incurvano appena, corde e paletti.
	# Corre lungo Z (R per orientarlo); il piano resta camminabile.
	var n := Node3D.new()
	var plank := _mat(WOOD, WOOD_DARK, 4.0, 0.55)
	var rope := _mat(Color("c9b088"), Color("ab9066"), 5.0, 0.5)
	for i in 6:
		var t := float(i) / 5.0
		var z := -0.415 + t * 0.83
		var dip := -0.05 - 0.045 * sin(PI * t)
		var p := _box(n, Vector3(0.86, 0.045, 0.145), plank, Vector3(0, dip, z))
		p.rotation.z = 0.03 if i % 2 == 0 else -0.03
	for sx: float in [-0.46, 0.46]:
		# paletti agli angoli e corrimano in due tratti che si abbassano al centro
		for sz: float in [-0.48, 0.48]:
			_cyl(n, 0.032, 0.04, 0.52, rope, Vector3(sx, 0.16, sz))
		for half: float in [-1.0, 1.0]:
			var seg := _cyl(n, 0.02, 0.02, 0.54, rope, Vector3(sx, 0.33, half * 0.25))
			seg.rotation.x = PI * 0.5 + half * 0.17
		# cordine verticali tra corrimano e assi
		for i in 3:
			var z := -0.25 + float(i) * 0.25
			_cyl(n, 0.011, 0.011, 0.36, rope, Vector3(sx, 0.12, z))
	return n


static func _treehouse() -> Node3D:
	# il premio finale: la casetta sull'albero. Tronco, chioma, piattaforma
	# con ringhiera, casetta con la finestrella accesa, scala a pioli e la
	# lanterna che dondola (l'oscillazione la anima il BuildSystem).
	var n := Node3D.new()
	var bark := _mat(Color("9a6b4f"), Color("7e563f"), 3.0, 0.55)
	var leaf := _mat(LEAF, LEAF_DARK, 2.0, 0.6, 0.4)
	var plank := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	var dark := _mat(WOOD_DARK, Color("8a6440"), 4.0, 0.5)
	var plaster := _mat(PLASTER, PLASTER_SHADE, 2.5, 0.5)
	var tile := _mat(TERRACOTTA, Color("c47a58"), 3.0, 0.5)

	# tronco, radici — e il nodo del legno, che ogni albero vero ha.
	# NIENTE rami sopra la piattaforma: partirebbero da dentro la casa e
	# sbucherebbero da muri e tetto (è successo: un ramo usciva sopra la
	# porta come un braccio). Lassù il tronco sparisce nella chioma, e
	# alla chioma bastano le sfere.
	_cyl(n, 0.26, 0.38, 2.7, bark, Vector3(0, 1.35, 0))
	# il tronco alto si ferma SOTTO la falda sud (a 4.0 la sfiorava e
	# faceva capolino dal tetto)
	_cyl(n, 0.15, 0.22, 1.25, bark, Vector3(0, 3.22, 0))
	for i in 5:
		var a := float(i) / 5.0 * TAU + 0.4
		var root := _cyl(n, 0.08, 0.15, 0.5, bark, Vector3(cos(a) * 0.36, 0.16, sin(a) * 0.36))
		root.rotation.x = cos(a) * 0.5
		root.rotation.z = sin(a) * 0.5
	_ball(n, 0.055, _mat(Color("6e4a35"), Color("59391f"), 4.0, 0.5),
			Vector3(0.2, 1.7, 0.24), Vector3(0.8, 1.0, 0.5))

	# la chioma SI POSA sul tetto, non lo inghiotte: le sfere sono
	# tangenti al colmo (prima la centrale aveva la trave DENTRO e la
	# falda rossa affiorava in mezzo al verde), arretrate a nord così la
	# facciata resta in vista — una chioma che copre tutto è un cespuglio
	# col mutuo. Il grappolo resta fitto: da sopra niente buchi di cielo.
	_ball(n, 0.95, leaf, Vector3(0, 5.2, -0.37))
	_ball(n, 0.72, leaf, Vector3(0.9, 4.98, -0.37))
	_ball(n, 0.72, leaf, Vector3(-0.9, 4.98, -0.45))
	_ball(n, 0.72, leaf, Vector3(0.1, 4.95, -0.95))
	_ball(n, 0.62, leaf, Vector3(0.25, 5.55, 0.1))

	# LA PIATTAFORMA GRANDE: tre metri di assito — la terrazza a sud è
	# profonda più di un metro, ci si cammina davvero. Fascia perimetrale,
	# righe delle assi, e i puntoni che ora reggono un piano più largo.
	_box(n, Vector3(3.0, 0.1, 3.0), _mat(WOOD_PALE, WOOD, 5.0, 0.4), Vector3(0, 2.51, 0))
	for gz: float in [-1.0, -0.5, 0.0, 0.5, 1.0]:
		_box(n, Vector3(3.0, 0.006, 0.02), dark, Vector3(0, 2.562, gz))
	for e: float in [-1.51, 1.51]:
		_box(n, Vector3(3.08, 0.1, 0.08), dark, Vector3(0, 2.5, e))
		_box(n, Vector3(0.08, 0.1, 3.08), dark, Vector3(e, 2.5, 0))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var strut := _cyl(n, 0.055, 0.055, 1.75, bark, Vector3(sx * 0.6, 1.85, sz * 0.6))
			strut.rotation.x = -sz * 0.62
			strut.rotation.z = sx * 0.62

	# la ringhiera: paletti col pomello tondo, corrimano CILINDRICO e
	# mezza traversa — il varco a sud è per la scala
	var posts: Array[Vector3] = []
	for x: float in [-1.44, -0.96, -0.48, 0.0, 0.48, 0.96, 1.44]:
		posts.append(Vector3(x, 0, -1.44))
	for x: float in [-1.44, -0.96, -0.48, 0.48, 0.96, 1.44]:
		posts.append(Vector3(x, 0, 1.44))
	for z: float in [-0.96, -0.48, 0.0, 0.48, 0.96]:
		posts.append(Vector3(-1.44, 0, z))
		posts.append(Vector3(1.44, 0, z))
	for p in posts:
		_box(n, Vector3(0.065, 0.5, 0.065), plank, Vector3(p.x, 2.81, p.z))
		_ball(n, 0.05, plank, Vector3(p.x, 3.09, p.z))
	for quota: Array in [[3.08, 0.032], [2.84, 0.02]]:
		var y_c := float(quota[0])
		var r_c := float(quota[1])
		for lato_r: float in [-1.44, 1.44]:
			var fianco := _cyl(n, r_c, r_c, 2.94, plank, Vector3(lato_r, y_c, 0))
			fianco.rotation.x = PI * 0.5
		var nord := _cyl(n, r_c, r_c, 2.94, plank, Vector3(0, y_c, -1.44))
		nord.rotation.z = PI * 0.5
		for sx: float in [-1.0, 1.0]:
			var sud := _cyl(n, r_c, r_c, 1.06, plank, Vector3(sx * 0.92, y_c, 1.44))
			sud.rotation.z = PI * 0.5

	# la casetta: pareti intonacate, montanti, porta a sud, finestrella accesa
	var hy := 3.13
	for sxw: float in [-1.0, 1.0]:
		_box(n, Vector3(0.42, 1.1, 0.1), plaster, Vector3(sxw * 0.54, hy, 0.32))
		_box(n, Vector3(0.1, 1.1, 1.42), plaster, Vector3(sxw * 0.7, hy, -0.37))
	_box(n, Vector3(1.5, 1.1, 0.1), plaster, Vector3(0, hy, -1.06))
	_box(n, Vector3(1.5, 0.28, 0.1), plaster, Vector3(0, 3.54, 0.32))
	# l'anta del varco a sud: cardine sul montante sinistro, la apre il
	# BuildSystem al passaggio (era un buco: si entrava da fantasmi)
	var anta_hinge := Node3D.new()
	anta_hinge.name = "Hinge"
	anta_hinge.position = Vector3(-0.33, 2.58, 0.32)
	n.add_child(anta_hinge)
	var anta_mat := _mat(Color("b3805a"), Color("96683f"), 3.0, 0.55)
	_box(anta_hinge, Vector3(0.64, 1.0, 0.05), anta_mat, Vector3(0.32, 0.5, 0))
	var anta_slat := _mat(Color("a2734e"), Color("8a5f3e"), 2.0, 0.4)
	_box(anta_hinge, Vector3(0.52, 0.03, 0.055), anta_slat, Vector3(0.32, 0.3, 0))
	_box(anta_hinge, Vector3(0.52, 0.03, 0.055), anta_slat, Vector3(0.32, 0.72, 0))
	_ball(anta_hinge, 0.028, _mat(CREAM, WOOD_PALE, 4.0, 0.3), Vector3(0.56, 0.52, 0.045))
	for cx: float in [-0.7, 0.7]:
		for cz: float in [-1.06, 0.32]:
			_box(n, Vector3(0.11, 1.16, 0.11), dark, Vector3(cx, hy, cz))
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color("ffd9a0")
	glow.emission_enabled = true
	glow.emission = Color("ffc978")
	glow.emission_energy_multiplier = 1.1
	# l'oblò acceso sul fianco est, stavolta con la sua cornice scura e
	# la crocera — una finestra, non un faro appiccicato
	var win := MeshInstance3D.new()
	var wm := CylinderMesh.new()
	wm.top_radius = 0.14
	wm.bottom_radius = 0.14
	wm.height = 0.03
	win.mesh = wm
	win.material_override = glow
	win.position = Vector3(0.76, 3.24, -0.37)
	win.rotation.z = PI * 0.5
	n.add_child(win)
	var oblo := MeshInstance3D.new()
	var om := TorusMesh.new()
	om.inner_radius = 0.13
	om.outer_radius = 0.175
	oblo.mesh = om
	oblo.material_override = dark
	oblo.position = Vector3(0.762, 3.24, -0.37)
	oblo.rotation.z = PI * 0.5
	n.add_child(oblo)
	var cr_v := _cyl(n, 0.012, 0.012, 0.27, dark, Vector3(0.775, 3.24, -0.37))
	cr_v.rotation.x = 0.0
	var cr_o := _cyl(n, 0.012, 0.012, 0.27, dark, Vector3(0.775, 3.24, -0.37))
	cr_o.rotation.x = PI * 0.5
	# la finestra QUADRATA che guarda la terrazza, con la fioriera sotto:
	# da dentro si controlla chi sale dalla scala, come in ogni casa vera
	_lastra(n, 0.14, 0.26, 0.03, 0.04, dark, Vector3(0.54, 3.32, 0.33),
			Vector3(0, PI * 0.5, 0))
	var pane := MeshInstance3D.new()
	var pm2 := BoxMesh.new()
	pm2.size = Vector3(0.22, 0.2, 0.03)
	pane.mesh = pm2
	pane.material_override = glow
	pane.position = Vector3(0.54, 3.32, 0.345)
	n.add_child(pane)
	_box(n, Vector3(0.24, 0.018, 0.018), dark, Vector3(0.54, 3.32, 0.36))
	_box(n, Vector3(0.018, 0.21, 0.018), dark, Vector3(0.54, 3.32, 0.36))
	_box(n, Vector3(0.3, 0.07, 0.1), _mat(Color("6e4a35"), Color("59391f"), 4.0, 0.5),
			Vector3(0.54, 3.14, 0.4))
	for fx in 3:
		var fc: Color = [PINK, Color("ffd76e"), Color("cdbff0")][fx]
		_ball(n, 0.035, _mat(fc, fc.darkened(0.15), 5.0, 0.4),
				Vector3(0.46 + 0.08 * float(fx), 3.2, 0.4), Vector3(1, 0.75, 1))

	# tetto a falde INTERE e larghe, coi frontoni CHIUSI a triangolo e il
	# colmo coi pomelli. ATTENZIONE AL SEGNO della rotazione: con
	# -half*0.62 le falde salivano VERSO FUORI — un tetto a V di
	# farfalla, non a capanna — e nessuno l'aveva mai visto perché la
	# chioma di prima ci stava seduta sopra. È il segno POSITIVO a far
	# scendere ogni falda dal colmo verso la gronda.
	for half: float in [-1.0, 1.0]:
		var slope := _box(n, Vector3(1.9, 0.07, 1.1), tile,
				Vector3(0, 3.965, -0.37 + half * 0.415))
		slope.rotation.x = half * 0.62
	for lato_g: float in [-1.0, 1.0]:
		var perno_g := Node3D.new()
		perno_g.position = Vector3(lato_g * 0.64, 0, 0)
		perno_g.rotation.z = -lato_g * PI * 0.5
		n.add_child(perno_g)
		if lato_g > 0.0:
			_prisma(perno_g, [Vector2(-4.24, -0.37), Vector2(-3.64, 0.41),
					Vector2(-3.64, -1.15)], 0.0, 0.08, plaster)
		else:
			_prisma(perno_g, [Vector2(4.24, -0.37), Vector2(3.64, -1.15),
					Vector2(3.64, 0.41)], 0.0, 0.08, plaster)
	var colmo := _cyl(n, 0.06, 0.06, 1.94, dark, Vector3(0, 4.26, -0.37))
	colmo.rotation.z = PI * 0.5
	for lato_c: float in [-1.0, 1.0]:
		_ball(n, 0.075, dark, Vector3(lato_c * 0.97, 4.26, -0.37))

	# scala a pioli (sale da sud, fino al bordo NUOVO della terrazza):
	# montanti tondi inclinati e pioli tondi. ATTENZIONE all'asse: il box
	# di prima era lungo in Z, un cilindro è lungo in Y — stessa rotazione,
	# scala sdraiata a mezz'aria (pagato col provino)
	for sx: float in [-0.3, 0.3]:
		var stringer := _cyl(n, 0.042, 0.048, 2.85, dark, Vector3(sx, 1.28, 1.95))
		stringer.rotation.x = 1.165 - PI * 0.5
	for i in 8:
		var t := (float(i) + 0.7) / 9.0
		var rung := _cyl(n, 0.03, 0.03, 0.62, plank,
				Vector3(0, 0.25 + t * 2.25, 2.39 - t * 0.96))
		rung.rotation.z = PI * 0.5

	# LA VITA SULLA TERRAZZA: lo sgabellino, il vaso di coccio con la
	# piantina, e il secchiello di legno vicino alla porta — le cose di
	# chi ci ABITA, non un belvedere vuoto
	_cyl(n, 0.13, 0.11, 0.045, plank, Vector3(-0.95, 2.71, 0.85))
	for g3 in 3:
		var ag := TAU / 3.0 * float(g3)
		var gambetta := _cyl(n, 0.022, 0.026, 0.15, dark,
				Vector3(-0.95 + cos(ag) * 0.08, 2.63, 0.85 + sin(ag) * 0.08))
		gambetta.rotation.x = sin(ag) * 0.15
		gambetta.rotation.z = -cos(ag) * 0.15
	BUILDER.lathe(n, [Vector2(0.075, 0.0), Vector2(0.09, 0.05),
			Vector2(0.1, 0.13), Vector2(0.115, 0.16), Vector2(0.1, 0.175)],
			tile, Vector3(1.05, 2.56, 0.9), 16)
	_ball(n, 0.12, leaf, Vector3(1.05, 2.82, 0.9))
	_ball(n, 0.08, leaf, Vector3(1.12, 2.92, 0.85))
	_cyl(n, 0.075, 0.06, 0.1, plank, Vector3(0.62, 2.62, 0.6))
	var manico_s := MeshInstance3D.new()
	var msm := TorusMesh.new()
	msm.inner_radius = 0.055
	msm.outer_radius = 0.072
	manico_s.mesh = msm
	manico_s.material_override = dark
	manico_s.position = Vector3(0.62, 2.67, 0.6)
	manico_s.rotation.x = PI * 0.5
	n.add_child(manico_s)

	# LA CARRUCOLA sul fianco est: il braccio, la puleggia, la fune e il
	# cestino che sale e scende — è così che in una casa sull'albero
	# arriva la merenda
	var braccio_c := _box(n, Vector3(0.5, 0.06, 0.06), dark, Vector3(1.62, 3.06, -0.85))
	braccio_c.rotation.z = 0.12
	var puleggia := MeshInstance3D.new()
	var pum := TorusMesh.new()
	pum.inner_radius = 0.03
	pum.outer_radius = 0.062
	puleggia.mesh = pum
	puleggia.material_override = plank
	puleggia.position = Vector3(1.84, 3.02, -0.85)
	puleggia.rotation.x = PI * 0.5
	puleggia.rotation.z = PI * 0.5
	n.add_child(puleggia)
	_cyl(n, 0.008, 0.008, 0.62, dark, Vector3(1.84, 2.68, -0.85))
	_cyl(n, 0.1, 0.085, 0.16, plank, Vector3(1.84, 2.32, -0.85))
	_cyl(n, 0.085, 0.085, 0.02, dark, Vector3(1.84, 2.41, -0.85))

	# I FESTONI: la corda di bandierine dal colmo del tetto al pomello
	# della ringhiera a sud-est — una casa dei giochi lo dice da lontano
	var corda_f: Array = [Vector3(0.93, 3.60, 0.2), Vector3(1.15, 3.42, 0.65),
			Vector3(1.32, 3.25, 1.05), Vector3(1.44, 3.11, 1.44)]
	BUILDER.tube(n, corda_f, [0.008, 0.008, 0.008, 0.008], dark, 18, 6)
	var colori_f := [PINK, Color("ffd76e"), LEAF, Color("cdbff0"), CREAM]
	for bf in 5:
		var tb := (float(bf) + 0.75) / 6.0
		var seg := int(tb * 3.0)
		var pf: Vector3 = corda_f[seg].lerp(corda_f[mini(seg + 1, 3)],
				tb * 3.0 - float(seg))
		var fc2: Color = colori_f[bf]
		var bandierina := _prisma(n, [Vector2(-0.05, 0.0), Vector2(0.0, 0.13),
				Vector2(0.05, 0.0)], 0.0, 0.014,
				_mat(fc2, fc2.darkened(0.15), 5.0, 0.35))
		bandierina.position = pf + Vector3(0, -0.01, 0)
		bandierina.rotation.x = PI * 0.5
		bandierina.rotation.z = PI
		bandierina.rotation.y = 0.7 - tb * 0.9

	# il cuore intagliato sulla parete nord: anche il retro di una casa
	# vera dice qualcosa di chi ci abita
	for cx_c: float in [-0.035, 0.035]:
		_ball(n, 0.055, dark, Vector3(cx_c, 3.42, -1.12), Vector3(1, 1, 0.35))
	var punta_c := _box(n, Vector3(0.095, 0.095, 0.035), dark,
			Vector3(0, 3.36, -1.12))
	punta_c.rotation.z = PI * 0.25

	# la lanterna sul braccio della gronda: il pivot dondola nel vento
	_box(n, Vector3(0.42, 0.055, 0.055), dark, Vector3(0.78, 3.585, 0.5))
	var pivot := Node3D.new()
	pivot.name = "LanternaPivot"
	pivot.position = Vector3(0.97, 3.57, 0.5)
	n.add_child(pivot)
	var chain := _cyl(pivot, 0.012, 0.012, 0.26, dark, Vector3(0, -0.13, 0))
	chain.rotation.z = 0.0
	_cyl(pivot, 0.085, 0.075, 0.19, _mat(METAL, Color("6f665b"), 4.0, 0.4), Vector3(0, -0.36, 0))
	var core := MeshInstance3D.new()
	var cm := SphereMesh.new()
	cm.radius = 0.058
	cm.height = 0.116
	core.mesh = cm
	core.material_override = glow
	core.position = Vector3(0, -0.36, 0)
	pivot.add_child(core)
	_cyl(pivot, 0.02, 0.05, 0.06, dark, Vector3(0, -0.245, 0))
	var light := OmniLight3D.new()
	light.light_color = Color("ffc98a")
	light.light_energy = 1.3
	light.omni_range = 4.5
	light.shadow_enabled = false
	light.position = Vector3(0, -0.42, 0)
	pivot.add_child(light)
	return n


static func _sapling() -> Node3D:
	var n := Node3D.new()
	_cyl(n, 0.05, 0.08, 0.55, _mat(Color("9a6b4f"), Color("7e563f"), 4.0, 0.5), Vector3(0, 0.27, 0))
	var leaf := _mat(Color("97cc74"), Color("74b05c"), 2.0, 0.6, 0.45)
	_ball(n, 0.32, leaf, Vector3(0, 0.75, 0))
	_ball(n, 0.22, leaf, Vector3(0.16, 0.95, 0.05))
	_ball(n, 0.2, leaf, Vector3(-0.15, 0.92, -0.05))
	return n


static func _bush() -> Node3D:
	var n := Node3D.new()
	var leaf := _mat(Color("8cc873"), Color("6cae5b"), 2.0, 0.6, 0.4)
	_ball(n, 0.32, leaf, Vector3(0, 0.28, 0))
	_ball(n, 0.24, leaf, Vector3(0.2, 0.24, 0.08), Vector3(1, 0.9, 1))
	_ball(n, 0.22, leaf, Vector3(-0.2, 0.22, -0.06), Vector3(1, 0.9, 1))
	_ball(n, 0.035, _mat(PINK_DEEP, PINK, 6.0, 0.4), Vector3(0.12, 0.5, 0.12))
	_ball(n, 0.03, _mat(Color("fff6f9"), CREAM, 6.0, 0.4), Vector3(-0.16, 0.42, 0.1))
	return n


static func _mushroom() -> Node3D:
	var n := Node3D.new()
	_cyl(n, 0.05, 0.07, 0.14, _mat(CREAM, Color("f0e2cc"), 5.0, 0.4), Vector3(0, 0.07, 0))
	_ball(n, 0.14, _mat(Color("d96a6a"), Color("c25454"), 4.0, 0.5), Vector3(0, 0.16, 0), Vector3(1, 0.62, 1))
	var dot := _mat(Color.WHITE, CREAM, 4.0, 0.2)
	_ball(n, 0.025, dot, Vector3(0.06, 0.21, 0.05))
	_ball(n, 0.02, dot, Vector3(-0.05, 0.22, -0.03))
	_ball(n, 0.018, dot, Vector3(0.0, 0.19, -0.09))
	return n


static func _mailbox() -> Node3D:
	# cassetta animabile dal sistema posta: "Lid" (sportello incernierato in
	# basso), "Flag" (bandierina, alzata = c'è posta), "Letter" (la busta
	# che fa capolino). Il fronte guarda verso -Z.
	var n := Node3D.new()
	_cyl(n, 0.03, 0.04, 0.85, _mat(WOOD, WOOD_DARK, 4.0, 0.5), Vector3(0, 0.42, 0))
	var body := _mat(Color("d97f7f"), Color("c26a6a"), 4.0, 0.45)
	_box(n, Vector3(0.24, 0.2, 0.34), body, Vector3(0, 0.94, 0.01))
	_cyl(n, 0.12, 0.12, 0.36, body, Vector3(0, 1.04, 0)).rotation.x = PI * 0.5
	# fondo scuro dell'imboccatura, svelato dallo sportello aperto
	_box(n, Vector3(0.2, 0.16, 0.012), _mat(Color("4a3230"), Color("3a2624"), 3.0, 0.4), Vector3(0, 0.94, -0.155))

	# la busta, nascosta finché non arriva posta
	var letter := _box(n, Vector3(0.15, 0.105, 0.012), _mat(CREAM, Color("f3e6d0"), 5.0, 0.35), Vector3(0, 0.95, -0.125))
	letter.name = "Letter"
	letter.rotation.x = -0.3
	letter.visible = false
	# sigillo a cuoricino
	_ball(letter, 0.016, _mat(PINK_DEEP, PINK, 4.0, 0.3), Vector3(0, 0.0, -0.01))

	# sportello incernierato sul bordo basso del fronte
	var lid := Node3D.new()
	lid.name = "Lid"
	lid.position = Vector3(0, 0.845, -0.175)
	n.add_child(lid)
	_box(lid, Vector3(0.22, 0.19, 0.016), _mat(Color("e89090"), Color("d47a7a"), 4.0, 0.45), Vector3(0, 0.095, 0))
	_ball(lid, 0.018, _mat(CREAM, WOOD_PALE, 4.0, 0.3), Vector3(0, 0.155, -0.014))

	# bandierina: abbassata di default, si alza quando arriva una lettera
	var flag := Node3D.new()
	flag.name = "Flag"
	flag.position = Vector3(0.135, 0.99, 0.08)
	flag.rotation.x = -1.35
	n.add_child(flag)
	var yellow := _mat(Color("ffd76e"), Color("eec254"), 4.0, 0.4)
	_box(flag, Vector3(0.016, 0.15, 0.03), yellow, Vector3(0, 0.075, 0))
	_box(flag, Vector3(0.016, 0.05, 0.09), yellow, Vector3(0, 0.13, -0.05))
	return n


static func _bench() -> Node3D:
	var n := Node3D.new()
	var wood := _mat(WOOD_PALE, WOOD, 3.5, 0.5)
	var dark := _mat(WOOD, WOOD_DARK, 4.0, 0.55)
	for x in [-0.36, 0.36]:
		_box(n, Vector3(0.08, 0.42, 0.34), dark, Vector3(x, 0.21, 0))
	_box(n, Vector3(0.95, 0.05, 0.17), wood, Vector3(0, 0.44, 0.09))
	var seduta := _box(n, Vector3(0.95, 0.05, 0.17), wood, Vector3(0, 0.44, -0.1))
	var incl := 0.15
	var back_a := _box(n, Vector3(0.95, 0.14, 0.04), wood, Vector3(0, 0.62, -0.19))
	var back_b := _box(n, Vector3(0.95, 0.14, 0.04), wood, Vector3(0, 0.8, -0.22))
	back_a.rotation.x = incl
	back_b.rotation.x = incl
	# I MONTANTI: senza, lo schienale era un'isola sospesa — 8,3 cm d'aria fra
	# la cima della seduta (0.465) e il bordo basso della doga bassa (0.548), e
	# altri 3,6 cm fra le due doghe. Salgono dalla seduta, che attraversano per
	# tutto lo spessore, fino a filo della doga alta. Pendenza, lunghezza e
	# arretramento sono RICAVATI da doghe e seduta — non scelti a occhio: chi
	# domani alza una doga o la porta più indietro se li ritrova ancora dietro.
	var doga: Vector3 = (back_b.mesh as BoxMesh).size
	var salita := back_b.position - back_a.position
	var pendenza := atan2(salita.z, salita.y)
	var spessore := 0.05
	var cima := back_b.position.y + (doga.y * cos(incl) + doga.z * sin(incl)) * 0.5
	var piede: float = seduta.position.y - (seduta.mesh as BoxMesh).size.y * 0.5
	var mezzo := (cima + piede) * 0.5
	var lungo := (cima - piede) / cos(pendenza)
	# arretrati di mezzo spessore loro più mezzo di doga, meno un centimetro di
	# morso: le doghe si appoggiano DAVANTI al montante invece di sbucargli
	# fuori dalla faccia, che è quella su cui uno appoggia la schiena
	var mont_z := back_a.position.z + (mezzo - back_a.position.y) * tan(pendenza) \
			- (spessore + doga.z - 0.02) * 0.5 / cos(pendenza)
	for mx: float in [-0.36, 0.36]:  # in asse con le gambe, che continuano
		var montante := _box(n, Vector3(0.07, lungo, spessore), dark,
				Vector3(mx, mezzo, mont_z))
		montante.rotation.x = pendenza
	return n


# ================================================================ NEGOZIO
# I pezzi che si comprano dal mercante (con le noccioline o le stelline).
# Stessa mano pastello del resto del catalogo.

# la bancarella di Mochi: il banco di legno chiaro col tendone menta e
# crema (MAI rosa: quello è il carretto del mercante), tre piedistalli
# per la merce esposta e il cartellino di legno sul fianco. La merce vera
# e i prezzi li mette il sistema Bancarella.gd: qui solo il banco.
static func _player_stall() -> Node3D:
	var n := Node3D.new()
	var pale := _mat(WOOD_PALE, WOOD, 3.0, 0.45)
	var wood := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	# il banco: cassa piena, piano sporgente, zoccolo
	_box(n, Vector3(1.16, 0.08, 0.62), wood, Vector3(0, 0.04, 0))
	_box(n, Vector3(1.08, 0.72, 0.5), pale, Vector3(0, 0.44, 0))
	_box(n, Vector3(1.26, 0.07, 0.62), wood, Vector3(0, 0.83, 0))
	# la fascia frontale coi listelli
	for i in 5:
		_box(n, Vector3(0.16, 0.5, 0.03), wood, Vector3(-0.44 + float(i) * 0.22, 0.5, 0.26))
	# i montanti e il tendone a strisce menta e crema
	for sx: float in [-0.56, 0.56]:
		_box(n, Vector3(0.06, 1.5, 0.06), wood, Vector3(sx, 0.78, -0.18))
	for i in 6:
		var stripe := _box(n, Vector3(0.22, 0.045, 0.78),
				_mat(Color("9fd8cf"), Color("86c2b8"), 4.0, 0.4) if i % 2 == 0 \
				else _mat(CREAM, Color("f0e2cc"), 4.0, 0.4),
				Vector3(-0.55 + float(i) * 0.22, 1.56, -0.02))
		stripe.rotation.z = 0.07
		stripe.rotation.x = -0.12
	# i tre piedistalli della merce (gli stessi offset che usa Bancarella.gd)
	for sx: float in [-0.38, 0.0, 0.38]:
		_cyl(n, 0.1, 0.11, 0.05, wood, Vector3(sx, 0.89, 0.02))
	# il cartellino di legno appeso sul fianco, con lo spago
	var targa := _box(n, Vector3(0.26, 0.18, 0.03), pale, Vector3(0.66, 0.62, 0.12))
	targa.rotation.z = -0.08
	_cyl(n, 0.008, 0.008, 0.14, _mat(Color("d9c08a"), Color("c0a878"), 10.0, 0.4),
			Vector3(0.64, 0.76, 0.12))
	return n


# lo stendino: due pali a T, la corda che fa la pancia in mezzo e il
# cestello di vimini alla base. Nasce VUOTO: i teli ce li mettono Mochi
# (E — stendi il bucato) o i residenti, ed è VitaSecondaria a gestirli.
static func _clothesline() -> Node3D:
	var n := Node3D.new()
	var wood := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	for sx: float in [-0.55, 0.55]:
		_box(n, Vector3(0.07, 1.15, 0.07), wood, Vector3(sx, 0.57, 0))
		_box(n, Vector3(0.24, 0.05, 0.06), wood, Vector3(sx, 1.12, 0))
		# il picchetto di sbieco che tiene il palo
		var picchetto := _box(n, Vector3(0.05, 0.4, 0.05), wood, Vector3(sx * 0.82, 0.2, 0.12))
		picchetto.rotation.x = -0.5
		picchetto.rotation.z = -sx * 0.35
	# la corda, in tre segmenti con la pancia al centro
	var corda := _mat(Color("d9c08a"), Color("c0a878"), 10.0, 0.4)
	var seg1 := _cyl(n, 0.012, 0.012, 0.4, corda, Vector3(-0.35, 1.09, 0))
	seg1.rotation.z = PI * 0.5 - 0.1
	var seg2 := _cyl(n, 0.012, 0.012, 0.34, corda, Vector3(0, 1.055, 0))
	seg2.rotation.z = PI * 0.5
	var seg3 := _cyl(n, 0.012, 0.012, 0.4, corda, Vector3(0.35, 1.09, 0))
	seg3.rotation.z = PI * 0.5 + 0.1
	# il cestello del bucato, di vimini, appoggiato a un palo
	var vimini := _mat(Color("c9a86a"), Color("a8874c"), 5.0, 0.5)
	_box(n, Vector3(0.24, 0.15, 0.17), vimini, Vector3(0.36, 0.08, 0.16))
	_box(n, Vector3(0.26, 0.03, 0.19), _mat(Color("b8935a"), Color("97783f"), 5.0, 0.5),
			Vector3(0.36, 0.16, 0.16))
	return n


# il carillon: cassa di ciliegio, rullo d'ottone e la manovella sul fianco.
# La musica vera la mette Interactions (E per caricarlo): qui solo il corpo.
static func _musicbox() -> Node3D:
	var n := Node3D.new()
	var ciliegio := _mat(Color("b06a4a"), Color("8f5238"), 4.0, 0.5)
	var ottone := _mat(Color("e8c46a"), Color("c49c48"), 5.0, 0.35)
	_box(n, Vector3(0.42, 0.1, 0.36), _mat(WOOD_DARK, Color("7a5636"), 4.0, 0.5), Vector3(0, 0.05, 0))
	_box(n, Vector3(0.38, 0.3, 0.32), ciliegio, Vector3(0, 0.25, 0))
	_box(n, Vector3(0.4, 0.04, 0.34), ottone, Vector3(0, 0.42, 0))
	# il rullo a pettine, coi dentini che pizzicano le note
	var rullo := _cyl(n, 0.07, 0.07, 0.26, ottone, Vector3(0, 0.52, 0))
	rullo.rotation.z = PI * 0.5
	for i in 5:
		_box(n, Vector3(0.015, 0.02, 0.09), ciliegio, Vector3(-0.1 + i * 0.05, 0.44, 0.1))
	# la manovella sul fianco
	var perno := _cyl(n, 0.018, 0.018, 0.1, ottone, Vector3(0.23, 0.3, 0))
	perno.rotation.z = PI * 0.5
	_box(n, Vector3(0.03, 0.11, 0.03), ottone, Vector3(0.28, 0.25, 0))
	_ball(n, 0.028, ciliegio, Vector3(0.28, 0.19, 0))
	return n


# la serra: un giardino di vetro col telaio chiaro e il tetto a capanna.
# Dentro, due vasi che sognano l'estate anche a gennaio.
static func _greenhouse() -> Node3D:
	var n := Node3D.new()
	var telaio := _mat(Color("e8e2d2"), Color("cfc8b4"), 4.0, 0.4)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.81, 0.91, 0.96, 0.42)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.emission_enabled = true
	glass.emission = Color("bfe0f2")
	glass.emission_energy_multiplier = 0.25
	glass.roughness = 0.15
	_box(n, Vector3(1.0, 0.06, 1.0), _mat(STONE, STONE_DARK, 4.0, 0.45), Vector3(0, 0.03, 0))
	# i quattro montanti e le pareti di vetro
	for sx: float in [-0.46, 0.46]:
		for sz: float in [-0.46, 0.46]:
			_box(n, Vector3(0.07, 0.95, 0.07), telaio, Vector3(sx, 0.51, sz))
	_box(n, Vector3(0.92, 0.85, 0.03), glass, Vector3(0, 0.51, -0.46))
	_box(n, Vector3(0.92, 0.85, 0.03), glass, Vector3(0, 0.51, 0.46))
	_box(n, Vector3(0.03, 0.85, 0.92), glass, Vector3(-0.46, 0.51, 0))
	_box(n, Vector3(0.03, 0.85, 0.92), glass, Vector3(0.46, 0.51, 0))
	_box(n, Vector3(1.0, 0.05, 1.0), telaio, Vector3(0, 0.96, 0))
	# il tetto a capanna, due falde di vetro sul colmo
	for lato: float in [-1.0, 1.0]:
		var falda := _box(n, Vector3(1.02, 0.03, 0.62), glass, Vector3(0, 1.17, lato * 0.26))
		falda.rotation.x = lato * 0.56
		# LA TRAVE STA SUL BORDO BASSO DELLA FALDA, e quel bordo si CALCOLA:
		# messa alla quota del colmo ma più in fuori restava sospesa quindici
		# centimetri sopra il vetro, in aria, e da tre quarti la si vedeva
		# volare. La gronda è il centro della falda più mezza falda lungo la
		# pendenza: sempre in giù di sin(0.56), in fuori di cos(0.56).
		var gronda := Vector3(0, -sin(0.56), lato * cos(0.56)) * 0.30
		var trave := _box(n, Vector3(1.04, 0.05, 0.06), telaio,
				Vector3(0, 1.15, lato * 0.26) + gronda)
		trave.rotation.x = lato * 0.56
	_box(n, Vector3(1.06, 0.06, 0.06), telaio, Vector3(0, 1.32, 0))
	# dentro: due vasi col verde che non teme l'inverno
	for sx: float in [-0.22, 0.24]:
		_cyl(n, 0.09, 0.11, 0.14, _mat(TERRACOTTA, Color("c47a58"), 3.0, 0.5), Vector3(sx, 0.13, 0.05 * sx * 10.0))
		_ball(n, 0.11, _mat(LEAF, LEAF_DARK, 4.0, 0.5), Vector3(sx, 0.27, 0.05 * sx * 10.0), Vector3(1.0, 0.85, 1.0))
	return n


# la mongolfiera decorativa: pallone a spicchi rosa e crema, cesto di vimini
# e quattro corde. Resta ormeggiata e DONDOLA piano: il respiro glielo dà un
# AnimationPlayer in loop, niente script (i pezzi piazzati sono nodi nudi).
static func _balloon() -> Node3D:
	var n := Node3D.new()
	var vimini := _mat(Color("c9a86a"), Color("a8874c"), 4.0, 0.5)
	# il cesto, con l'orlo e due sacchetti di zavorra
	_box(n, Vector3(0.5, 0.42, 0.5), vimini, Vector3(0, 0.31, 0))
	_box(n, Vector3(0.56, 0.07, 0.56), _mat(WOOD, WOOD_DARK, 4.0, 0.5), Vector3(0, 0.54, 0))
	_ball(n, 0.09, _mat(Color("d9c4a8"), Color("c4ae90"), 3.0, 0.5), Vector3(0.3, 0.2, 0.22), Vector3(1.0, 1.25, 1.0))
	_ball(n, 0.09, _mat(Color("d9c4a8"), Color("c4ae90"), 3.0, 0.5), Vector3(-0.28, 0.2, -0.2), Vector3(1.0, 1.25, 1.0))
	# tutto ciò che dondola sta sotto questo nodo: il pallone e le corde
	var su := Node3D.new()
	su.name = "Pallone"
	n.add_child(su)
	# il pallone: centro, raggio e schiacciamento in chiaro, perché lassù ci
	# si attaccano le corde e un numero ricopiato è un numero che diverge
	var cuore := Vector3(0, 2.05, 0)
	var r_pal := 0.5
	var sagoma := Vector3(0.42, 1.0, 0.95)
	for i in 8:
		var a := float(i) * TAU / 8.0
		var mat := _mat(PINK, PINK_DEEP, 4.0, 0.4) if i % 2 == 0 else _mat(CREAM, Color("f3dfc8"), 4.0, 0.4)
		var spicchio := _ball(su, r_pal, mat, cuore, sagoma)
		spicchio.rotation.y = a
	_ball(su, 0.5, _mat(Color("f2cf7e"), Color("d9a84a"), 3.0, 0.4), Vector3(0, 1.38, 0), Vector3(0.36, 0.36, 0.36))
	# quanto sale il pallone col respiro: lo usano il piede delle corde e la
	# traccia dell'animazione, e devono essere lo STESSO numero
	var respiro := 0.12
	# LE QUATTRO CORDE. Erano un cilindro di 0.75 messo a mano e finivano a
	# mezz'aria: la punta usciva a 0.3199 dall'asse alla quota 1.3232, dove la
	# sfera del bruciatore misura 0.1708 e il pallone non comincia nemmeno (la
	# sua pancia parte a 1.55). Quindici centimetri di vuoto: il pallone non
	# era appeso a niente. Adesso i capi sono due PUNTI — il legno del cesto e
	# la stoffa del pallone — e lunghezza e inclinazione si RICAVANO da loro:
	# se il pallone cambia, le corde lo seguono.
	var q45 := cos(PI * 0.25)      # seno e coseno di 45° sono lo stesso numero
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var diag := Vector3(sx, 0.0, sz).normalized()
			# in alto: sullo spicchio in diagonale — ce n'è uno per ogni corda,
			# ed è il suo meridiano largo — a 45° sotto l'equatore
			var attacco := cuore + diag * (r_pal * sagoma.z * q45) \
					- Vector3(0, r_pal * sagoma.y * q45, 0)
			# in basso: DENTRO al cesto, più a fondo di quanto il pallone salga
			# col respiro (l'orlo di legno ha la faccia di sopra a 0.575), o a
			# ogni dondolio la corda uscirebbe dal cesto e tornerebbe a penzolare
			var piede := Vector3(sx * 0.174, 0.575 - respiro - 0.025, sz * 0.174)
			var verso := (attacco - piede).normalized()
			# cinque centimetri dentro la stoffa: a filo, il capo tondo
			# lascerebbe vedere lo sfondo appena il pallone si inclina
			var lunga := piede.distance_to(attacco) + 0.05
			var corda := _cyl(su, 0.012, 0.012, lunga, vimini, piede + verso * (lunga * 0.5))
			# l'asse del cilindro è +Y: prima l'inclinazione attorno a X, poi il
			# giro attorno a Y — l'ordine YXZ di Godot è già questo
			corda.rotation = Vector3(acos(clampf(verso.y, -1.0, 1.0)), atan2(verso.x, verso.z), 0.0)
	# il respiro: su e giù di sei dita, con una punta di rollio
	var anim := Animation.new()
	anim.length = 6.0
	anim.loop_mode = Animation.LOOP_LINEAR
	var tr_pos := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(tr_pos, NodePath("Pallone:position:y"))
	anim.track_insert_key(tr_pos, 0.0, 0.0)
	anim.track_insert_key(tr_pos, 3.0, respiro)
	anim.track_insert_key(tr_pos, 6.0, 0.0)
	var tr_rot := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(tr_rot, NodePath("Pallone:rotation:z"))
	anim.track_insert_key(tr_rot, 0.0, -0.02)
	anim.track_insert_key(tr_rot, 3.0, 0.02)
	anim.track_insert_key(tr_rot, 6.0, -0.02)
	anim.track_set_interpolation_type(tr_pos, Animation.INTERPOLATION_CUBIC)
	anim.track_set_interpolation_type(tr_rot, Animation.INTERPOLATION_CUBIC)
	var lib := AnimationLibrary.new()
	lib.add_animation("dondola", anim)
	var player := AnimationPlayer.new()
	n.add_child(player)
	player.add_animation_library("", lib)
	player.autoplay = "dondola"
	return n


static func _glow(albedo: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.emission_enabled = true
	m.emission = emission
	m.emission_energy_multiplier = energy
	return m


# uno zampillo / scintillio di particelle morbide (fontana, braciere)
static func _emit_fx(parent: Node3D, pos: Vector3, color: Color, up_vel: float, grav: float, amount: int, life: float, size: float) -> void:
	var tex := GradientTexture2D.new()
	tex.width = 32
	tex.height = 32
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([color, Color(color, 0.5), Color(color, 0.0)])
	tex.gradient = g
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_texture = tex
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	quad.material = mat
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = size * 0.5
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 22.0
	pm.initial_velocity_min = up_vel * 0.6
	pm.initial_velocity_max = up_vel
	pm.gravity = Vector3(0, grav, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.1
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.0)])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.process_material = pm
	p.draw_pass_1 = quad
	p.position = pos
	parent.add_child(p)


static func _birdhouse() -> Node3D:
	var n := Node3D.new()
	var wood := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	_cyl(n, 0.035, 0.05, 1.05, wood, Vector3(0, 0.52, 0))
	_box(n, Vector3(0.28, 0.3, 0.26), _mat(PLASTER, PLASTER_SHADE, 3.0, 0.45), Vector3(0, 1.18, 0))
	var tile := _mat(TERRACOTTA, Color("c47a58"), 3.0, 0.5)
	for s: float in [-1.0, 1.0]:
		var r := _box(n, Vector3(0.24, 0.03, 0.32), tile, Vector3(s * 0.08, 1.36, 0))
		r.rotation.z = -s * 0.6
	var hole := _cyl(n, 0.05, 0.05, 0.04, _mat(Color("4a3226"), Color("31201a"), 3.0, 0.4), Vector3(0, 1.18, 0.14))
	hole.rotation.x = PI * 0.5
	var perch := _cyl(n, 0.012, 0.012, 0.12, wood, Vector3(0, 1.1, 0.17))
	perch.rotation.x = PI * 0.5
	return n


static func _streetlamp() -> Node3D:
	var n := Node3D.new()
	var metal := _mat(METAL, Color("6f665b"), 5.0, 0.4)
	_cyl(n, 0.14, 0.18, 0.1, metal, Vector3(0, 0.05, 0))
	_cyl(n, 0.035, 0.05, 2.0, metal, Vector3(0, 1.0, 0))
	_box(n, Vector3(0.24, 0.06, 0.24), metal, Vector3(0, 2.02, 0))
	_box(n, Vector3(0.17, 0.2, 0.17), _glow(Color("ffe6b0"), Color("ffd382"), 2.0), Vector3(0, 2.14, 0))
	var cap := _cyl(n, 0.02, 0.14, 0.12, metal, Vector3(0, 2.3, 0))
	cap.name = "cap"
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.86, 0.6)
	light.light_energy = 1.6
	light.omni_range = 5.5
	light.position = Vector3(0, 2.14, 0)
	n.add_child(light)
	return n


static func _hammock() -> Node3D:
	var n := Node3D.new()
	var wood := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	# i numeri dei pali servono anche al letto e alle funi (dove finisce una
	# doga, dove si annoda una corda): stanno scritti una volta sola
	var palo_x := 0.42
	var palo_y := 0.45
	var palo_h := 0.9
	var incl := 0.12
	for x: float in [-palo_x, palo_x]:
		var post := _cyl(n, 0.04, 0.06, palo_h, wood, Vector3(x, palo_y, 0))
		post.rotation.z = -signf(x) * incl
	# l'asse del palo DESTRO alla quota y e la sua faccia interna: il palo è
	# inclinato e rastremato, quindi tutti e due si spostano salendo (il palo
	# sinistro è speculare)
	var asse := func(y: float) -> float:
		return palo_x + sin(incl) * (y - palo_y) / cos(incl)
	var faccia := func(y: float) -> float:
		var h: float = (y - palo_y) / cos(incl)
		return float(asse.call(y)) \
				- lerpf(0.06, 0.04, h / palo_h + 0.5) / cos(incl)
	var a := _mat(PINK, PINK_DEEP, 5.0, 0.4)
	var b := _mat(CREAM, Color("f3dfc8"), 5.0, 0.4)
	var corda := _mat(Color("c9b088"), Color("ab9066"), 5.0, 0.5)
	# Le nove doghe erano nove isole: niente le infilava, e le due terminali
	# finivano DENTRO i pali (bordo esterno a 0.40 contro la faccia interna a
	# 0.368: 3,2 cm di legno attraversato, e di tre quarti sbucavano dall'altra
	# parte). Ora la campata si RICAVA dal palo e sono le due funi a reggere il
	# letto: seguono la stessa catenaria, infilano tutte le doghe e vanno ad
	# annodarsi al legno — in un'amaca vera al palo ci arriva la corda, non il
	# letto.
	var quota := 0.44                        # la quota dei due capi del letto
	# mezza campata: l'ultima doga ci deve stare TUTTA dentro, e la doga è a sua
	# volta ricavata dal passo → mezza + doga/2 = limite; con doga = 2·mezza/9
	# viene mezza = limite · 0.9, e il vuoto fra le doghe resta 1/9 del passo
	var limite := float(faccia.call(quota)) - 0.008
	var mezza := limite * 0.9
	var passo := mezza / 4.0                 # otto intervalli fra nove doghe
	var doga := passo * 8.0 / 9.0
	var punti: Array[Vector3] = []
	for i in 9:
		var t := float(i) / 8.0
		var x := -mezza + t * mezza * 2.0
		var dip := quota - 0.16 * sin(PI * t)
		_box(n, Vector3(doga, 0.02, 0.34), a if i % 2 == 0 else b, Vector3(x, dip, 0))
		punti.append(Vector3(x, dip, 0))
	var nodo_y := 0.56                       # dove la fune abbraccia il palo
	for lato: float in [-1.0, 1.0]:
		var fianco := Vector3(0, 0, lato * 0.175)     # sul filo delle doghe
		for i in 8:
			_fune(n, punti[i] + fianco, punti[i + 1] + fianco, 0.016, corda)
		for capo: float in [-1.0, 1.0]:
			_fune(n, punti[0 if capo < 0.0 else 8] + fianco,
					Vector3(capo * float(faccia.call(nodo_y)), nodo_y, 0), 0.014, corda)
	# la fasciatura di corda attorno al palo: chiude i quattro capi e nasconde
	# gli attacchi, come le legature degli attrezzi della palestra
	for capo: float in [-1.0, 1.0]:
		var fascia := _cyl(n, 0.058, 0.058, 0.05, corda,
				Vector3(capo * float(asse.call(nodo_y)), nodo_y, 0))
		fascia.rotation.z = -capo * incl
	return n


static func _swing() -> Node3D:
	var n := Node3D.new()
	var wood := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	for x: float in [-0.48, 0.48]:
		_cyl(n, 0.035, 0.05, 1.55, wood, Vector3(x, 0.77, 0))
	var bar := _cyl(n, 0.04, 0.04, 1.05, wood, Vector3(0, 1.53, 0))
	bar.rotation.z = PI * 0.5
	var rope := _mat(Color("c9b088"), Color("ab9066"), 5.0, 0.5)
	for x: float in [-0.16, 0.16]:
		_cyl(n, 0.01, 0.01, 0.95, rope, Vector3(x, 1.05, 0.05))
	_box(n, Vector3(0.44, 0.05, 0.22), _mat(WOOD_PALE, WOOD, 3.0, 0.5), Vector3(0, 0.6, 0.05))
	return n


static func _fountain() -> Node3D:
	var n := Node3D.new()
	var stone := _mat(STONE, STONE_DARK, 3.0, 0.5)
	_cyl(n, 0.46, 0.5, 0.16, stone, Vector3(0, 0.08, 0))
	_cyl(n, 0.42, 0.42, 0.02, stone, Vector3(0, 0.02, 0))
	var water := _glow(Color(0.55, 0.82, 0.95, 0.75), Color(0.4, 0.7, 0.9), 0.15)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cyl(n, 0.42, 0.42, 0.02, water, Vector3(0, 0.14, 0))
	_cyl(n, 0.09, 0.13, 0.36, stone, Vector3(0, 0.32, 0))
	_cyl(n, 0.17, 0.2, 0.05, stone, Vector3(0, 0.5, 0))
	var wtop := _glow(Color(0.6, 0.84, 0.95, 0.8), Color(0.45, 0.72, 0.92), 0.2)
	wtop.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cyl(n, 0.15, 0.15, 0.02, wtop, Vector3(0, 0.53, 0))
	_emit_fx(n, Vector3(0, 0.62, 0), Color(0.72, 0.9, 1.0), 1.4, -3.2, 20, 1.0, 0.08)
	return n


# «Un gazebo esagonale col tetto a pagoda: il salotto all'aperto» — così
# promette il negozio, e la prima stesura consegnava un'altra cosa: quattro
# stecchi quadrati e un tetto fatto di QUATTRO SCATOLE RUOTATE che si
# trapassavano a caso (le punte spigolose che si vedevano in foto erano le
# scatole che si intersecano). La lezione: una falda di tetto NON è una
# scatola — è un triangolo, e i triangoli si fanno con `_prisma`, che
# estrude il profilo vero. Le falde si chiudono in punta perché SONO
# triangoli, non perché una scatola copre l'altra.

## Una falda del tetto: il profilo (triangolo o trapezio) steso in piano e
## poi ruotato in opera — prima attorno a Y per il suo spicchio, poi
## attorno a X per la pendenza. L'ordine YXZ di Godot fa esattamente
## questo: l'inclinazione avviene attorno alla gronda già orientata.
static func _falda(n: Node3D, punti: Array, mat: Material, pos: Vector3,
		giro: float, pendenza: float, spessore := 0.035) -> MeshInstance3D:
	var f := _prisma(n, punti, 0.0, spessore, mat)
	f.position = pos
	f.rotation.y = giro
	f.rotation.x = pendenza
	return f


static func _gazebo() -> Node3D:
	var n := Node3D.new()
	var legno := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	var chiaro := _mat(WOOD_PALE, WOOD, 3.0, 0.45)
	var pietra := _mat(STONE, STONE_DARK, 3.0, 0.5)
	var crema := _mat(CREAM, Color("ecdcc4"), 3.5, 0.4)
	var tegola := _mat(TERRACOTTA, Color("c47a58"), 3.0, 0.5)
	var tegola_scura := _mat(Color("c47a58"), Color("a86348"), 3.5, 0.45)
	var oro := _mat(Color("f2cf7e"), Color("d9a84a"), 6.0, 0.35)
	var verde := _mat(LEAF, LEAF_DARK, 3.0, 0.5)

	# ---- IL BASAMENTO: uno zoccolo di pietra esagonale, il pavimento di
	# assi chiare, e il gradino d'invito sul fronte (-Z, come tutto il
	# catalogo). L'esagono è VERO, non una scatola: _prisma.
	var esa_pietra: Array = []
	var esa_legno: Array = []
	for k in 6:
		var a := float(k) * TAU / 6.0
		esa_pietra.append(Vector2(cos(a) * 0.98, sin(a) * 0.98))
		esa_legno.append(Vector2(cos(a) * 0.92, sin(a) * 0.92))
	_prisma(n, esa_pietra, 0.0, 0.06, pietra)
	_prisma(n, esa_legno, 0.06, 0.06, chiaro)
	# le fughe delle assi: righe sottili e scure sul piano di calpestio
	for fx: float in [-0.60, -0.30, 0.0, 0.30, 0.60]:
		var mezza: float = 0.92 * (1.0 - absf(fx) / 1.10)
		_box(n, Vector3(0.012, 0.004, mezza * 1.7), _mat(WOOD, WOOD_DARK, 3.0, 0.4),
				Vector3(fx, 0.121, 0))
	_box(n, Vector3(0.46, 0.05, 0.18), pietra, Vector3(0, 0.025, -1.00))

	# ---- LE SEI COLONNINE TORNITE: base, fusto che si assottiglia,
	# capitello. Ai vertici dell'esagono, col fronte libero per entrare.
	var r_col := 0.86
	for k2 in 6:
		var a2 := float(k2) * TAU / 6.0
		var cx := cos(a2) * r_col
		var cz := sin(a2) * r_col
		_box(n, Vector3(0.11, 0.07, 0.11), legno, Vector3(cx, 0.155, cz))
		_cyl(n, 0.036, 0.048, 1.24, legno, Vector3(cx, 0.81, cz))
		_cyl(n, 0.052, 0.038, 0.05, legno, Vector3(cx, 1.455, cz))
		_box(n, Vector3(0.105, 0.045, 0.105), crema, Vector3(cx, 1.503, cz))

	# ---- L'ARCHITRAVE: sei travi fra i capitelli, e sotto una mantovana
	# smerlata di crema coi suoi pendenti — il ricamo che fa «gazebo da
	# giardino» invece di «tettoia».
	var ap_col := r_col * cos(TAU / 12.0)
	for k3 in 6:
		var a3 := float(k3) * TAU / 6.0 + TAU / 12.0
		var mx := cos(a3) * ap_col
		var mz := sin(a3) * ap_col
		var giro := PI * 0.5 - a3
		var trave := _box(n, Vector3(r_col, 0.075, 0.06), legno,
				Vector3(mx, 1.565, mz))
		trave.rotation.y = giro
		var mantova := _box(n, Vector3(r_col * 0.92, 0.035, 0.02), crema,
				Vector3(mx * 0.985, 1.51, mz * 0.985))
		mantova.rotation.y = giro
		# tre pendenti a goccia sotto la mantovana
		for q in 3:
			var t := (float(q) - 1.0) * 0.30
			var px := mx * 0.985 - sin(a3) * t
			var pz := mz * 0.985 + cos(a3) * t
			_ball(n, 0.016, crema, Vector3(px, 1.485, pz), Vector3(1, 1.5, 1))

	# ---- LA BALAUSTRA su quattro lati (fronte e retro aperti): corrimano,
	# zoccolo, e tre colonnini torniti per campata. È il parapetto su cui
	# ci si appoggia a guardare il prato.
	for k4 in [0, 2, 3, 5]:
		var a4 := float(k4) * TAU / 6.0 + TAU / 12.0
		var bx := cos(a4) * ap_col
		var bz := sin(a4) * ap_col
		var giro2 := PI * 0.5 - a4
		var cima := _box(n, Vector3(r_col * 0.86, 0.05, 0.055), legno,
				Vector3(bx * 0.99, 0.50, bz * 0.99))
		cima.rotation.y = giro2
		var piede := _box(n, Vector3(r_col * 0.86, 0.04, 0.05), legno,
				Vector3(bx * 0.99, 0.17, bz * 0.99))
		piede.rotation.y = giro2
		for q2 in 3:
			var t2 := (float(q2) - 1.0) * 0.145
			var vx := bx * 0.99 - sin(a4) * t2
			var vz := bz * 0.99 + cos(a4) * t2
			_cyl(n, 0.016, 0.02, 0.29, chiaro, Vector3(vx, 0.335, vz))

	# ---- IL TETTO A PAGODA, DUE ORDINI. Ogni falda è un profilo VERO
	# estruso con _prisma e ruotato in opera: si chiudono in punta perché
	# sono triangoli, non scatole. I colmi di legno sui displuvi coprono le
	# cuciture e disegnano la pagoda.
	#
	# Ordine basso: un tronco di piramide (falde a trapezio), largo e
	# gentile, con la gronda che sborda. Ordine alto: la piramide vera
	# (falde a triangolo), più ripida. In mezzo, il tamburo.
	var re1 := 1.18          # gronda bassa (sborda oltre le colonne: è un tetto)
	var rm := 0.52           # dove l'ordine basso si ferma
	var y1 := 1.62
	var h1 := 0.36
	var ap1 := re1 * cos(TAU / 12.0)
	var apm := rm * cos(TAU / 12.0)
	var corsa1 := ap1 - apm
	var l1 := sqrt(corsa1 * corsa1 + h1 * h1)
	var pende1 := atan2(h1, corsa1)
	for k5 in 6:
		var a5 := float(k5) * TAU / 6.0 + TAU / 12.0
		var gx := cos(a5) * ap1
		var gz := sin(a5) * ap1
		var trapezio: Array = [Vector2(-re1 * 0.5, 0.0), Vector2(re1 * 0.5, 0.0),
				Vector2(rm * 0.5, -l1), Vector2(-rm * 0.5, -l1)]
		_falda(n, trapezio, tegola, Vector3(gx, y1, gz), PI * 0.5 - a5, pende1)
		# la fascia di gronda color crema, sotto il filo della falda
		var fascia := _box(n, Vector3(re1, 0.045, 0.03), crema,
				Vector3(gx * 1.0, y1 - 0.02, gz * 1.0))
		fascia.rotation.y = PI * 0.5 - a5
	# i colmi dell'ordine basso, dai vertici di gronda al tamburo — e il
	# CORNO rialzato in punta di gronda, il ricciolo che fa pagoda
	for k6 in 6:
		var a6 := float(k6) * TAU / 6.0
		var da := Vector3(cos(a6) * re1, y1, sin(a6) * re1)
		var fino := Vector3(cos(a6) * rm, y1 + h1, sin(a6) * rm)
		var mezzo := (da + fino) * 0.5
		var colmo := _box(n, Vector3(0.05, 0.035, da.distance_to(fino) + 0.06),
				tegola_scura, mezzo)
		colmo.rotation.y = PI * 0.5 - a6
		colmo.rotation.x = atan2(h1, re1 - rm)
		var corno := _box(n, Vector3(0.055, 0.03, 0.10), tegola_scura,
				da + Vector3(cos(a6) * 0.02, 0.025, sin(a6) * 0.02))
		corno.rotation.y = PI * 0.5 - a6
		corno.rotation.x = -0.5
	# il tamburo fra i due ordini
	var esa_tamburo: Array = []
	for k7 in 6:
		var a7 := float(k7) * TAU / 6.0
		esa_tamburo.append(Vector2(cos(a7) * (rm - 0.02), sin(a7) * (rm - 0.02)))
	_prisma(n, esa_tamburo, y1 + h1 - 0.01, 0.10, crema)
	# ordine alto: la piramide, più ripida
	var re2 := 0.66
	var y2 := y1 + h1 + 0.08
	var h2 := 0.40
	var ap2 := re2 * cos(TAU / 12.0)
	var l2 := sqrt(ap2 * ap2 + h2 * h2)
	var pende2 := atan2(h2, ap2)
	for k8 in 6:
		var a8 := float(k8) * TAU / 6.0 + TAU / 12.0
		var gx2 := cos(a8) * ap2
		var gz2 := sin(a8) * ap2
		var triangolo: Array = [Vector2(-re2 * 0.5, 0.0), Vector2(re2 * 0.5, 0.0),
				Vector2(0.0, -l2)]
		_falda(n, triangolo, tegola, Vector3(gx2, y2, gz2), PI * 0.5 - a8, pende2)
	for k9 in 6:
		var a9 := float(k9) * TAU / 6.0
		var da2 := Vector3(cos(a9) * re2, y2, sin(a9) * re2)
		var fino2 := Vector3(0.0, y2 + h2, 0.0)
		var mezzo2 := (da2 + fino2) * 0.5
		var colmo2 := _box(n, Vector3(0.045, 0.032, da2.distance_to(fino2) + 0.04),
				tegola_scura, mezzo2)
		colmo2.rotation.y = PI * 0.5 - a9
		colmo2.rotation.x = atan2(h2, re2)

	# ---- IL PUNTALE dorato: sfera, guglia, perlina. È la firma in cima.
	_ball(n, 0.075, oro, Vector3(0, y2 + h2 + 0.05, 0))
	_cyl(n, 0.008, 0.02, 0.14, oro, Vector3(0, y2 + h2 + 0.15, 0))
	_ball(n, 0.028, oro, Vector3(0, y2 + h2 + 0.23, 0))

	# ---- LA LANTERNA APPESA nel mezzo: il cuore caldo del salotto. Di
	# sera è lei a dire «venite a sedervi».
	_cyl(n, 0.006, 0.006, 0.56, legno, Vector3(0, 1.44, 0))
	_cyl(n, 0.058, 0.066, 0.032, legno, Vector3(0, 1.115, 0))
	_cyl(n, 0.06, 0.052, 0.125, _glow(Color("ffe6b8"), Color("ffc978"), 1.2),
			Vector3(0, 1.038, 0))
	_cyl(n, 0.066, 0.056, 0.028, legno, Vector3(0, 0.962, 0))
	var luce := OmniLight3D.new()
	luce.light_color = Color(1.0, 0.86, 0.62)
	luce.light_energy = 0.9
	luce.omni_range = 3.4
	luce.position = Vector3(0, 0.95, 0)
	n.add_child(luce)

	# ---- IL FESTONE: bandierine di carta fra le colonne del fronte, i due
	# lati aperti. Triangolini VERI (_prisma), appesi con un filo che
	# scende appena al centro — la festa che non finisce mai.
	var colori_festa: Array = [PINK, Color("9ec9e8"), CREAM, LEAF]
	for lato_f: int in [1, 4]:
		var af := float(lato_f) * TAU / 6.0 + TAU / 12.0
		var fx2 := cos(af) * ap_col
		var fz2 := sin(af) * ap_col
		for q3 in 4:
			var t3 := (float(q3) - 1.5) * 0.20
			var bx2 := fx2 * 0.97 - sin(af) * t3
			var bz2 := fz2 * 0.97 + cos(af) * t3
			var giu := 0.03 + 0.025 * (1.0 - absf(float(q3) - 1.5) / 1.5)
			var col_f: Color = colori_festa[q3 % colori_festa.size()]
			var bandiera := _falda(n,
					[Vector2(-0.035, 0.0), Vector2(0.035, 0.0), Vector2(0.0, 0.075)],
					_mat(col_f, col_f.darkened(0.18), 3.0, 0.4),
					Vector3(bx2, 1.44 - giu, bz2), PI * 0.5 - af, PI * 0.5, 0.006)
			bandiera.rotation.z = 0.06 if q3 % 2 == 0 else -0.06

	# ---- IL RAMPICANTE su una colonna del retro: foglie che salgono a
	# spirale e tre fiorellini rosa. Il giardino che si riprende il legno.
	# sulla colonna LATERALE (k=0), lontana dagli sgabelli: sulla colonna
	# dietro-destra le foglie sporgevano verso l'interno fino a sfiorare il
	# braccio di chi sedeva al posto A — misurato: 0.21 m dal centro del
	# corpo, meno della mezza larghezza di un chibi.
	var ar := 0.0
	var vx2 := cos(ar) * r_col
	var vz2 := sin(ar) * r_col
	for q4 in 7:
		var sal := 0.24 + float(q4) * 0.15
		var att := float(q4) * 1.1
		_ball(n, 0.045, verde,
				Vector3(vx2 + cos(att) * 0.055, sal, vz2 + sin(att) * 0.055),
				Vector3(1.3, 0.75, 1.0))
	for q5 in 3:
		var sal2 := 0.42 + float(q5) * 0.30
		var att2 := float(q5) * 1.9 + 0.8
		_ball(n, 0.028, _mat(PINK, PINK_DEEP, 4.0, 0.4),
				Vector3(vx2 + cos(att2) * 0.075, sal2, vz2 + sin(att2) * 0.075))
		_ball(n, 0.012, crema,
				Vector3(vx2 + cos(att2) * 0.085, sal2 + 0.012, vz2 + sin(att2) * 0.085))

	# ---- IL SALOTTO: il tavolino tondo con la teiera, e due cuscini a
	# terra. È il motivo per cui si entra.
	_cyl(n, 0.24, 0.24, 0.03, chiaro, Vector3(0.0, 0.42, 0.10))
	_cyl(n, 0.028, 0.038, 0.28, legno, Vector3(0.0, 0.265, 0.10))
	_cyl(n, 0.10, 0.11, 0.025, legno, Vector3(0.0, 0.135, 0.10))
	_ball(n, 0.055, crema, Vector3(-0.06, 0.475, 0.06), Vector3(1, 0.85, 1))
	_cyl(n, 0.008, 0.012, 0.045, crema, Vector3(-0.06, 0.52, 0.06))
	_ball(n, 0.014, oro, Vector3(-0.06, 0.545, 0.06))
	var becco := _cyl(n, 0.008, 0.012, 0.06, crema, Vector3(-0.005, 0.49, 0.06))
	becco.rotation.z = -0.9
	_ball(n, 0.026, _mat(PINK, PINK_DEEP, 4.0, 0.4), Vector3(0.10, 0.455, 0.14),
			Vector3(1, 0.5, 1))
	# ---- LE TRE SEDUTE. Sgabelli torniti col cuscino, attorno al tavolino,
	# col fronte lasciato libero per entrare. E sono sedute VERE: ogni
	# sgabello ha il suo ancoraggio «Posto» col meta `seduta` (il punto
	# esatto del cuscino) e col meta `tavolo` (dove guardare da seduti) —
	# è il contratto di `r_bench`, lo stesso della poltrona del salone.
	# L'ancoraggio guarda VIA dal tavolo (+Z locale verso l'esterno), così
	# ci si avvicina e ci si rialza dal lato giusto, mai attraverso il tè.
	var tavolo_locale := Vector3(0.0, 0.45, 0.10)
	var cuscini_sg: Array = [PINK, Color("9ec9e8"), Color("d8d0a8")]
	var posti_sg: Array = [Vector3(0.46, 0, 0.44), Vector3(-0.46, 0, 0.44),
			Vector3(0.06, 0, -0.42)]
	for q6 in 3:
		var ps: Vector3 = posti_sg[q6]
		_cyl(n, 0.030, 0.040, 0.21, legno, Vector3(ps.x, 0.135, ps.z))
		_cyl(n, 0.115, 0.115, 0.035, chiaro, Vector3(ps.x, 0.255, ps.z))
		var col_c: Color = cuscini_sg[q6]
		_ball(n, 0.10, _mat(col_c, col_c.darkened(0.18), 4.0, 0.45),
				Vector3(ps.x, 0.28, ps.z), Vector3(1.0, 0.42, 1.0))
		var posto := Node3D.new()
		posto.name = "Posto%d" % q6
		posto.position = Vector3(ps.x, 0.318, ps.z)
		var via := Vector2(ps.x - tavolo_locale.x, ps.z - tavolo_locale.z)
		posto.rotation.y = atan2(via.x, via.y)
		posto.set_meta("seduta", Vector3.ZERO)
		posto.set_meta("tavolo", tavolo_locale)
		n.add_child(posto)
	# le tazze degli ospiti: il tè è per tre
	for q7 in 2:
		var pt: Vector3 = posti_sg[q7]
		var vt := Vector2(tavolo_locale.x - pt.x, tavolo_locale.z - pt.z).normalized()
		_cyl(n, 0.022, 0.018, 0.028, crema,
				Vector3(tavolo_locale.x - vt.x * 0.13, 0.45, tavolo_locale.z - vt.y * 0.13))
	for cusc: Array in [[Vector3(-0.66, 0.145, 0.04), PINK, PINK_DEEP],
			[Vector3(0.66, 0.145, -0.12), Color("9ec9e8"), Color("7fb2d8")]]:
		_ball(n, 0.10, _mat(cusc[1], cusc[2], 4.0, 0.45), cusc[0],
				Vector3(1.0, 0.42, 1.0))
	return n


static func _carousel() -> Node3D:
	var n := Node3D.new()
	var pole := _mat(METAL, Color("6f665b"), 5.0, 0.4)
	_cyl(n, 0.42, 0.44, 0.04, _mat(WOOD_PALE, WOOD, 3.0, 0.4), Vector3(0, 0.03, 0))
	_cyl(n, 0.03, 0.05, 1.5, pole, Vector3(0, 0.77, 0))
	for i in 8:
		var a := float(i) * TAU / 8.0
		var mat := _mat(PINK, PINK_DEEP, 4.0, 0.4) if i % 2 == 0 else _mat(CREAM, Color("f3dfc8"), 4.0, 0.4)
		var stripe := _box(n, Vector3(0.34, 0.04, 0.16), mat, Vector3(cos(a) * 0.22, 1.48, sin(a) * 0.22))
		stripe.rotation.y = a
		stripe.rotation.x = -0.5
	_ball(n, 0.06, _mat(Color("f2cf7e"), Color("d9a84a"), 3.0, 0.4), Vector3(0, 1.6, 0))
	for i in 3:
		var a := float(i) * TAU / 3.0
		var hx := cos(a) * 0.3
		var hz := sin(a) * 0.3
		# L'ASTINA PARTE DAL BALDACCHINO. Lunga 0.62 e centrata a 0.60,
		# cominciava a 0.91 — mezzo metro sotto la copertura (che sta a
		# 1.48): i seggiolini pendevano da niente, e una giostra si regge
		# tutta lì. Adesso va da sotto la falda fino alla testa del cavalluccio.
		_cyl(n, 0.008, 0.008, 1.02, pole, Vector3(hx, 0.91, hz))
		_ball(n, 0.075, _mat(CREAM, PINK, 4.0, 0.4), Vector3(hx, 0.42, hz), Vector3(1.5, 0.95, 0.7))
	return n


static func _brazier() -> Node3D:
	var n := Node3D.new()
	var metal := _mat(METAL, Color("5f564c"), 5.0, 0.4)
	_cyl(n, 0.22, 0.13, 0.16, metal, Vector3(0, 0.55, 0))
	_cyl(n, 0.2, 0.2, 0.02, _glow(Color("ff9440"), Color("ff7a26"), 1.8), Vector3(0, 0.6, 0))
	for i in 3:
		var a := (float(i) + 0.5) * TAU / 3.0
		var leg := _cyl(n, 0.015, 0.022, 0.5, metal, Vector3(cos(a) * 0.14, 0.25, sin(a) * 0.14))
		leg.rotation.z = cos(a) * 0.24
		leg.rotation.x = -sin(a) * 0.24
	_emit_fx(n, Vector3(0, 0.66, 0), Color("ffd257"), 0.9, 0.5, 22, 1.1, 0.09)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.82, 0.5)
	light.light_energy = 1.7
	light.omni_range = 4.2
	light.position = Vector3(0, 0.72, 0)
	n.add_child(light)
	return n


# ================================================================ IL SALONE
# L'ESTETISTA — la poltrona, lo specchio e il carrello dei colori.
#
# È il posto dove un vicino (e un giorno Mochi) si siede e ne esce
# diverso: manto, sopracciglia, guanciotte, vestitino. Il genoma
# estetico esiste già (ChibiDNA.ESTETICI) e un corpo si sa rifare da
# solo (Visitor.rifai_il_look); questo è il LUOGO, e viene prima del
# resto perché una meccanica senza un posto dove accade è un menù.
#
# Il pezzo sta in una cella ma la riempie tutta, come la casa
# sull'albero: specchio in fondo, poltrona al centro rivolta a chi
# entra, carrello dei colori sul fianco, tappeto a terra.
#
# COSA LO FA SEMBRARE VERO, in ordine di quanto si nota:
#   · LO SPECCHIO non è una lastra grigia. Il vetro ha un gradiente
#     verticale (il cielo in alto, la stanza in basso), una LAMA di
#     luce in diagonale — il riflesso che l'occhio legge come vetro
#     prima di qualunque altra cosa — e un bordo smussato che raccoglie
#     un filo di luce. La cornice è ovale con due volute.
#   · LA POLTRONA ha il pistone e la ghiera zigrinata, il poggiapiedi
#     ad anello e la base a cinque razze coi piedini: sono i dettagli
#     che dicono «poltrona da salone» e non «sedia».
#   · I BARATTOLI dei colori sono davvero di colori diversi, col tappo
#     di sughero e il livello che non arriva mai all'orlo.
#   · GLI ATTREZZI: forbici aperte a X con gli anelli, il pettine coi
#     denti veri, il pennello nel bicchiere.
#
# Il nodo "Seggiola" marca dove ci si siede: lo cercherà il sistema del
# salone quando arriverà (un ancoraggio nominato, non una costante
# copiata in due file).
static func _salone() -> Node3D:
	var n := Node3D.new()
	var legno := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	var legno_chiaro := _mat(WOOD_PALE, WOOD, 3.0, 0.45)
	var ottone := _mat(Color("d9b978"), Color("b8965a"), 7.0, 0.35)
	var acciaio := _mat(Color("cfc9c0"), Color("a8a29a"), 8.0, 0.3)
	var velluto := _mat(Color("f0b3c4"), Color("dd9aae"), 5.0, 0.55)
	var velluto_scuro := _mat(Color("dd9aae"), Color("c48196"), 5.0, 0.5)

	_salone_tappeto(n)
	_salone_specchio(n, legno_chiaro, ottone)
	_salone_poltrona(n, velluto, velluto_scuro, acciaio, ottone)
	_salone_carrello(n, legno, legno_chiaro, acciaio, ottone)
	_salone_insegna(n, legno_chiaro, ottone)

	# l'ancoraggio della seduta: ci si siede QUI (lo cerchera' il salone)
	var seggiola := Node3D.new()
	seggiola.name = "Seggiola"
	seggiola.position = Vector3(0.0, SAL_SEDUTA + 0.02, 0.07)
	# l'ancoraggio E' gia' il posto: nessun sollevamento
	seggiola.set_meta("seduta", Vector3.ZERO)
	n.add_child(seggiola)
	return n


# LA SCALA. Un chibi e' alto ~0.70 e si siede a ~0.28 da terra: TUTTO
# qui dentro e' tarato su di lui. Alla prima stesura la poltrona gli
# arrivava alla testa e lo specchio pareva un portale — bello e inutile:
# un salone deve sembrare a misura di chi ci si siede.
const SAL_SEDUTA := 0.29     # quota del cuscino
const SAL_SPECCHIO := 0.92   # centro della cornice
const SAL_CONSOLE := 0.46    # piano della console


# il tappetino: due ovali sovrapposti, quello sopra piu' chiaro — il
# bordo che si vede e' quello che lo fa sembrare un tappeto e non una
# macchia di colore
static func _salone_tappeto(n: Node3D) -> void:
	var fondo := _mat(Color("c9b6d8"), Color("b09cc4"), 3.0, 0.5)
	var sopra := _mat(Color("e0d2ea"), Color("cbb9da"), 3.5, 0.45)
	_cyl(n, 0.46, 0.46, 0.012, fondo, Vector3(0, 0.006, 0.02)).scale = Vector3(1.3, 1, 1)
	_cyl(n, 0.39, 0.39, 0.014, sopra, Vector3(0, 0.014, 0.02)).scale = Vector3(1.3, 1, 1)


# LO SPECCHIO. La console col cassetto, i due montanti, la cornice
# ovale, e dentro il vetro vero: gradiente, lama di luce, bordo.
static func _salone_specchio(n: Node3D, legno_chiaro: Material, ottone: Material) -> void:
	var z := -0.33
	# la console: piano, fascia, due gambe tornite col piedino
	_box(n, Vector3(0.78, 0.035, 0.20), legno_chiaro, Vector3(0, SAL_CONSOLE, z))
	_box(n, Vector3(0.70, 0.09, 0.16), legno_chiaro, Vector3(0, SAL_CONSOLE - 0.06, z))
	# il cassetto, con la maniglia d'ottone
	_box(n, Vector3(0.40, 0.065, 0.015), _mat(WOOD, WOOD_DARK, 5.0, 0.4),
			Vector3(0, SAL_CONSOLE - 0.06, z + 0.085))
	_cyl(n, 0.014, 0.014, 0.024, ottone,
			Vector3(0, SAL_CONSOLE - 0.06, z + 0.10)).rotation.x = PI * 0.5
	for sx: float in [-0.32, 0.32]:
		_cyl(n, 0.020, 0.026, 0.36, legno_chiaro, Vector3(sx, 0.19, z))
		_cyl(n, 0.034, 0.034, 0.022, legno_chiaro, Vector3(sx, 0.011, z))
		_ball(n, 0.032, legno_chiaro, Vector3(sx, 0.34, z), Vector3(1, 0.6, 1))

	# i montanti dello specchio, leggermente aperti a V
	for sx2: float in [-0.215, 0.215]:
		var m := _cyl(n, 0.016, 0.019, 0.30, legno_chiaro, Vector3(sx2, 0.63, z))
		m.rotation.z = -sx2 * 0.14

	# LA CORNICE OVALE: un toro schiacciato, che e' la forma giusta —
	# un rettangolo qui sembrerebbe una finestra, non uno specchio
	var cornice := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.195
	tm.outer_radius = 0.225
	tm.rings = 40
	tm.ring_segments = 10
	cornice.mesh = tm
	cornice.material_override = legno_chiaro
	cornice.position = Vector3(0, SAL_SPECCHIO, z)
	cornice.rotation.x = PI * 0.5
	cornice.scale = Vector3(1.0, 1.0, 1.20)   # ovale: piu' alto che largo
	n.add_child(cornice)

	# IL VETRO. Non una lastra grigia: un gradiente verticale (il cielo
	# in alto, la stanza in basso) piu' una LAMA di luce in diagonale.
	# E' quella lama che l'occhio legge come "vetro" prima di tutto.
	var vetro := StandardMaterial3D.new()
	vetro.albedo_color = Color(0.80, 0.87, 0.93)
	vetro.roughness = 0.06
	vetro.metallic = 0.35
	vetro.emission_enabled = true
	vetro.emission = Color(0.62, 0.74, 0.86)
	vetro.emission_energy_multiplier = 0.22
	var lastra := _cyl(n, 0.198, 0.198, 0.010, vetro, Vector3(0, SAL_SPECCHIO, z + 0.005))
	lastra.rotation.x = PI * 0.5
	lastra.scale = Vector3(1.0, 1.0, 1.20)

	# il fondo del vetro, piu' caldo: la stanza che ci si specchia
	var basso := StandardMaterial3D.new()
	basso.albedo_color = Color(0.74, 0.71, 0.71)
	basso.roughness = 0.12
	basso.metallic = 0.2
	var giu := _cyl(n, 0.193, 0.193, 0.005, basso, Vector3(0, SAL_SPECCHIO - 0.075, z + 0.008))
	giu.rotation.x = PI * 0.5
	giu.scale = Vector3(1.0, 1.0, 0.60)

	# LA LAMA DI LUCE: un nastro sottile in diagonale, unshaded e
	# additivo — non "colora" il vetro, ci si somma sopra come un
	# riflesso vero
	var lama_mat := StandardMaterial3D.new()
	lama_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lama_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lama_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	lama_mat.albedo_color = Color(1, 1, 1, 0.26)
	var lama := _box(n, Vector3(0.048, 0.34, 0.003), lama_mat,
			Vector3(-0.055, SAL_SPECCHIO + 0.02, z + 0.011))
	lama.rotation.z = -0.62
	var lama2 := _box(n, Vector3(0.020, 0.19, 0.003), lama_mat,
			Vector3(0.045, SAL_SPECCHIO - 0.055, z + 0.011))
	lama2.rotation.z = -0.62


# LA POLTRONA, a misura di chibi: si siede a 0.29 e lo schienale gli
# arriva alle spalle, non sopra la testa.
#
# LO SCHIENALE E' UN PANNELLO, non una sfera schiacciata: alla prima
# stesura era un ellissoide e leggeva come un palloncino rosa: la forma
# di un imbottito e' squadrata con gli spigoli tondi, e il tondo lo
# fanno il tubolare in cima e ai fianchi — non la sagoma intera.
static func _salone_poltrona(n: Node3D, velluto: Material, velluto_scuro: Material,
		acciaio: Material, ottone: Material) -> void:
	var z := 0.07
	# la base: cinque razze coi piedini, come le poltrone vere
	for i in 5:
		var a := float(i) / 5.0 * TAU + 0.3
		var razza := _box(n, Vector3(0.04, 0.026, 0.17), acciaio,
				Vector3(cos(a) * 0.085, 0.026, z + sin(a) * 0.085))
		razza.rotation.y = -a
		_cyl(n, 0.024, 0.021, 0.022, acciaio,
				Vector3(cos(a) * 0.165, 0.011, z + sin(a) * 0.165))
	_cyl(n, 0.05, 0.065, 0.035, acciaio, Vector3(0, 0.045, z))

	# il pistone e la GHIERA ZIGRINATA: e' questo dettaglio che dice
	# «poltrona da salone» invece di «sgabello»
	_cyl(n, 0.030, 0.030, 0.20, acciaio, Vector3(0, 0.155, z))
	for i in 12:
		var a2 := float(i) / 12.0 * TAU
		_box(n, Vector3(0.009, 0.032, 0.009), ottone,
				Vector3(cos(a2) * 0.037, 0.135, z + sin(a2) * 0.037)).rotation.y = -a2
	_cyl(n, 0.039, 0.039, 0.036, ottone, Vector3(0, 0.135, z))
	# la leva dell'altezza
	var leva := _cyl(n, 0.009, 0.009, 0.11, ottone, Vector3(0.075, 0.145, z + 0.03))
	leva.rotation.z = PI * 0.5
	leva.rotation.y = 0.4
	_ball(n, 0.016, ottone, Vector3(0.128, 0.145, z + 0.052))

	# LA SEDUTA: cassa bassa col cuscino sopra e il bordo tondo davanti
	# (il tubolare sul filo anteriore e' cio' che la fa "imbottita")
	_box(n, Vector3(0.30, 0.045, 0.29), velluto_scuro, Vector3(0, SAL_SEDUTA - 0.028, z))
	_box(n, Vector3(0.29, 0.035, 0.275), velluto, Vector3(0, SAL_SEDUTA + 0.002, z))
	var orlo := _cyl(n, 0.021, 0.021, 0.29, velluto,
			Vector3(0, SAL_SEDUTA - 0.002, z + 0.137))
	orlo.rotation.z = PI * 0.5
	_box(n, Vector3(0.007, 0.008, 0.20), velluto_scuro, Vector3(0, SAL_SEDUTA + 0.021, z))

	# LO SCHIENALE: pannello imbottito appena reclinato, col tubolare
	# tondo in cima e sui due fianchi
	var sch := Node3D.new()
	sch.position = Vector3(0, SAL_SEDUTA + 0.015, z - 0.128)
	sch.rotation.x = -0.17
	n.add_child(sch)
	_box(sch, Vector3(0.275, 0.235, 0.055), velluto, Vector3(0, 0.118, 0))
	_box(sch, Vector3(0.255, 0.215, 0.012), velluto_scuro, Vector3(0, 0.118, -0.030))
	var cima := _cyl(sch, 0.028, 0.028, 0.275, velluto, Vector3(0, 0.236, 0))
	cima.rotation.z = PI * 0.5
	for sx0: float in [-1.0, 1.0]:
		_cyl(sch, 0.024, 0.024, 0.235, velluto, Vector3(sx0 * 0.137, 0.118, 0))
	# la cucitura verticale al centro
	_box(sch, Vector3(0.008, 0.20, 0.008), velluto_scuro, Vector3(0, 0.115, 0.028))
	# il poggiatesta: un cuscinetto staccato, sospeso su due astine
	for sx1: float in [-1.0, 1.0]:
		_cyl(sch, 0.006, 0.006, 0.05, acciaio, Vector3(sx1 * 0.045, 0.275, 0.0))
	_box(sch, Vector3(0.15, 0.062, 0.052), velluto, Vector3(0, 0.325, 0.0))
	var cima2 := _cyl(sch, 0.026, 0.026, 0.15, velluto, Vector3(0, 0.352, 0.0))
	cima2.rotation.z = PI * 0.5

	# I BRACCIOLI: il cuscinetto poggia su DUE montanti che scendono
	# alla seduta — prima galleggiava, e si vedeva
	for sx: float in [-1.0, 1.0]:
		var bx := sx * 0.172
		_cyl(n, 0.010, 0.010, 0.10, acciaio, Vector3(bx, SAL_SEDUTA + 0.045, z - 0.085))
		_cyl(n, 0.010, 0.010, 0.075, acciaio, Vector3(bx, SAL_SEDUTA + 0.032, z + 0.075))
		_box(n, Vector3(0.045, 0.030, 0.20), velluto,
				Vector3(bx, SAL_SEDUTA + 0.100, z - 0.008))
		var tondo := _cyl(n, 0.019, 0.019, 0.045, velluto,
				Vector3(bx, SAL_SEDUTA + 0.100, z + 0.092))
		tondo.rotation.x = PI * 0.5

	# IL POGGIAPIEDI ad anello: un toro d'ottone davanti al pistone
	var anello := MeshInstance3D.new()
	var am := TorusMesh.new()
	am.inner_radius = 0.078
	am.outer_radius = 0.092
	am.rings = 24
	am.ring_segments = 8
	anello.mesh = am
	anello.material_override = ottone
	anello.position = Vector3(0, 0.135, z + 0.015)
	anello.rotation.x = PI * 0.5
	n.add_child(anello)


# IL CARRELLO DEI COLORI: tre ripiani, due ruote, i barattoli delle
# tinte, il bicchiere coi pennelli, le forbici e il pettine.
static func _salone_carrello(n: Node3D, legno: Material, legno_chiaro: Material,
		acciaio: Material, ottone: Material) -> void:
	var x := 0.40
	var z := 0.13
	# i montanti e i tre ripiani
	for sx: float in [-0.075, 0.075]:
		for sz: float in [-0.058, 0.058]:
			_cyl(n, 0.007, 0.009, 0.40, acciaio, Vector3(x + sx, 0.21, z + sz))
	for y: float in [0.13, 0.265, 0.40]:
		_box(n, Vector3(0.205, 0.015, 0.165), legno_chiaro, Vector3(x, y, z))
	# le due ruote piroettanti
	for sx2: float in [-0.068, 0.068]:
		var ruota := _cyl(n, 0.022, 0.022, 0.013,
				_mat(Color("6a625a"), Color("4e4841"), 8.0, 0.3),
				Vector3(x + sx2, 0.022, z + 0.050))
		ruota.rotation.z = PI * 0.5

	# I BARATTOLI DELLE TINTE: colori veri e diversi, tappo di sughero,
	# e il livello che non arriva mai all'orlo (un barattolo pieno raso
	# sembra un cilindro colorato, non un barattolo)
	var tinte := [Color("d98d9c"), Color("9ec9e8"), Color("cbb2e0"),
			Color("f0c98a"), Color("a8d6b8")]
	var vetro_b := StandardMaterial3D.new()
	vetro_b.albedo_color = Color(0.92, 0.95, 0.97, 0.42)
	vetro_b.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	vetro_b.roughness = 0.1
	var sughero := _mat(Color("d9b98a"), Color("bd9c6c"), 9.0, 0.4)
	var posti := [Vector3(-0.065, 0.408, -0.040), Vector3(0.0, 0.408, -0.040),
			Vector3(0.065, 0.408, -0.040), Vector3(-0.045, 0.408, 0.040),
			Vector3(0.045, 0.408, 0.040)]
	for i in tinte.size():
		var p: Vector3 = posti[i]
		var bx := x + p.x
		var by := p.y
		var bz := z + p.z
		_cyl(n, 0.019, 0.019, 0.055, vetro_b, Vector3(bx, by + 0.028, bz))
		_cyl(n, 0.016, 0.016, 0.032, _mat(tinte[i], Color(tinte[i]).darkened(0.18), 6.0, 0.4),
				Vector3(bx, by + 0.018, bz))
		_cyl(n, 0.015, 0.017, 0.013, sughero, Vector3(bx, by + 0.061, bz))

	# il bicchiere coi pennelli
	_cyl(n, 0.022, 0.019, 0.056, vetro_b, Vector3(x + 0.062, 0.158, z - 0.040))
	for i in 3:
		var px := x + 0.062 + (float(i) - 1.0) * 0.009
		var pz := z - 0.040 + float(i) * 0.006
		var pennello := _cyl(n, 0.004, 0.005, 0.13, legno, Vector3(px, 0.202, pz))
		pennello.rotation.z = (float(i) - 1.0) * 0.13
		_cyl(n, 0.007, 0.005, 0.032,
				_mat(Color("6a5a4a"), Color("50432f"), 10.0, 0.4),
				Vector3(px + (float(i) - 1.0) * 0.009, 0.263, pz))

	# LE FORBICI, aperte a X, con gli anelli
	var scuro := _mat(Color("4e4237"), Color("362d25"), 9.0, 0.35)
	for lato: float in [-1.0, 1.0]:
		var lama := _box(n, Vector3(0.009, 0.003, 0.085), acciaio,
				Vector3(x - 0.058, 0.278, z + 0.040))
		lama.rotation.y = lato * 0.20
		var occhiello := MeshInstance3D.new()
		var om := TorusMesh.new()
		om.inner_radius = 0.010
		om.outer_radius = 0.015
		om.rings = 14
		om.ring_segments = 6
		occhiello.mesh = om
		occhiello.material_override = ottone
		occhiello.position = Vector3(x - 0.058 + lato * 0.013, 0.279, z + 0.089)
		n.add_child(occhiello)
	_cyl(n, 0.005, 0.005, 0.010, ottone, Vector3(x - 0.058, 0.279, z + 0.020))

	# IL PETTINE: il dorso e i denti, allineati sullo stesso asse
	var ang := -0.25
	var base := Vector3(x + 0.042, 0.276, z + 0.048)
	var lungo := Vector3(cos(ang), 0, -sin(ang))
	var trasv := Vector3(sin(ang), 0, cos(ang))
	var dorso := _box(n, Vector3(0.085, 0.006, 0.012), scuro, base)
	dorso.rotation.y = ang
	for i in 9:
		var d := _box(n, Vector3(0.0035, 0.005, 0.020), scuro,
				base + lungo * ((float(i) - 4.0) * 0.0098) + trasv * 0.015)
		d.rotation.y = ang


# L'INSEGNA appesa: una tavoletta ovale con le forbici incise e due
# nastri. Sta in alto sul montante, dove si vede da fuori.
static func _salone_insegna(n: Node3D, legno_chiaro: Material, ottone: Material) -> void:
	var pivot := Node3D.new()
	pivot.name = "InsegnaPivot"
	pivot.position = Vector3(-0.36, 0.88, -0.29)
	n.add_child(pivot)
	# il braccetto e la catenella
	var braccio := _cyl(n, 0.009, 0.009, 0.12, ottone, Vector3(-0.31, 0.94, -0.30))
	braccio.rotation.z = PI * 0.5
	_cyl(pivot, 0.004, 0.004, 0.075, ottone, Vector3(0, 0.034, 0))
	# la tavoletta ovale
	var tavola := _cyl(pivot, 0.072, 0.072, 0.013, legno_chiaro, Vector3(0, -0.068, 0))
	tavola.rotation.x = PI * 0.5
	tavola.scale = Vector3(1.0, 1.0, 0.72)
	# le forbici incise: due lamette a X piu' due anellini
	for lato: float in [-1.0, 1.0]:
		var l := _box(pivot, Vector3(0.006, 0.040, 0.003), ottone,
				Vector3(lato * 0.009, -0.058, 0.009))
		l.rotation.z = lato * 0.30
		_cyl(pivot, 0.008, 0.008, 0.003, ottone,
				Vector3(lato * 0.020, -0.087, 0.009)).rotation.x = PI * 0.5
	# i due nastri
	for lato2: float in [-1.0, 1.0]:
		var nastro := _box(pivot, Vector3(0.016, 0.036, 0.003),
				_mat(PINK, PINK_DEEP, 6.0, 0.45), Vector3(lato2 * 0.040, -0.024, 0.005))
		nastro.rotation.z = lato2 * 0.5


# ============================================================================
# IL POSTO DI GUARDIA
# ============================================================================
# La stazione di questo villaggio non è autorità: è il posto dove si va a
# CHIEDERE, non dove si viene portati. In un gioco che non punisce nessuno,
# una caserma con le celle sarebbe una nota stonata; una guardiola col
# lume azzurro acceso tutta la notte, la bacheca degli avvisi e soprattutto
# l'armadio degli OGGETTI SMARRITI è invece la cosa più cozy che ci sia —
# il posto dove le cose perse tornano da chi le ha perse.
#
# È anche la casa che mancava al lavoro «guardia» (Lavori.LAVORI): finora
# si poteva assegnare, costava rancore al residente e non produceva NIENTE,
# perché non c'era un posto dove farlo.
#
# Fronte di tutti i pezzi: verso -Z, come il resto del catalogo.

const BLU := Color("7d9bd8")
const BLU_CUPO := Color("5f7cba")
const SEGNALE_ROSSO := Color("dd8474")
const SEGNALE_BIANCO := Color("f7f2e6")
# l'ottone lo dichiara già la tavolozza in cima al file: qui si riusa il suo,
# o due tonalità diverse dello stesso metallo convivrebbero nel villaggio
const SUGHERO := Color("d8b487")


## Il lume azzurro: il segnale che di notte dice «qui c'è qualcuno sveglio».
## Ritorna il nodo della lanterna, così i pezzi che la montano possono
## chiamarlo "Lume" e accenderlo o spegnerlo.
static func _lume_azzurro(parent: Node3D, pos: Vector3, scala := 1.0) -> Node3D:
	var lume := Node3D.new()
	lume.name = "Lume"
	lume.position = pos
	lume.scale = Vector3.ONE * scala
	parent.add_child(lume)
	var ottone := _mat(OTTONE, OTTONE_SCURO, 5.0, 0.4)
	# la montatura: cappellino sopra, coppa sotto, quattro montanti
	_cyl(lume, 0.02, 0.085, 0.06, ottone, Vector3(0, 0.135, 0))
	_cyl(lume, 0.07, 0.055, 0.03, ottone, Vector3(0, -0.09, 0))
	for i in 4:
		var a := PI * 0.5 * float(i) + PI * 0.25
		_box(lume, Vector3(0.012, 0.19, 0.012), ottone,
				Vector3(cos(a) * 0.055, 0.015, sin(a) * 0.055))
	# il vetro. Il blu va SATURO e l'emissione tenuta bassa: con l'energia
	# alta il vetro si sbianca e la lanterna «blu» esce color miele come
	# tutte le altre — il segnale del posto di guardia non si riconosce più.
	var vetro := _ball(lume, 0.072, _glow(Color("4f78d4"), Color("5f8ce8"), 0.9),
			Vector3(0, 0.015, 0), Vector3(1.0, 1.25, 1.0))
	vetro.name = "Vetro"
	var luce := OmniLight3D.new()
	luce.light_color = Color(0.72, 0.82, 1.0)
	luce.light_energy = 1.15
	luce.omni_range = 4.6
	luce.position = Vector3(0, 0.015, 0)
	lume.add_child(luce)
	return lume


## Le fasce oblique bianche e rosse di una sbarra o di una transenna.
static func _fasce(parent: Node3D, lung: float, spess: float, alt: float,
		y: float, quante: int) -> void:
	var bianco := _mat(SEGNALE_BIANCO, Color("e9e2d2"), 4.0, 0.35)
	var rosso := _mat(SEGNALE_ROSSO, Color("c96f60"), 4.0, 0.4)
	_box(parent, Vector3(lung, alt, spess), bianco, Vector3(0, y, 0))
	var passo := lung / float(quante)
	for i in quante:
		if i % 2 == 1:
			continue
		_box(parent, Vector3(passo * 0.98, alt * 1.02, spess * 1.05), rosso,
				Vector3(-lung * 0.5 + passo * (float(i) + 0.5), y, 0))


static func _guardiola() -> Node3D:
	# LA GUARDIOLA: una garitta a pianta ottagonale — un box coi quattro
	# angoli smussati in legno: è lo smusso, con le sue otto facce che
	# prendono la luce una diversa dall'altra, a toglierle l'aria da
	# scatolone. La finestra sul fronte è APERTA, ad arco, col bancone da
	# cui si sporge chi è di turno; il retro ha la porta SENZA anta: chi fa
	# la guardia ENTRA davvero (le collisioni lasciano il varco libero e
	# l'interno cavo), e il nodo "PostoGuardia" all'interno è il punto in
	# cui la Veglia lo manda per il turno di giorno.
	var n := Node3D.new()
	var legno := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	var legno_chiaro := _mat(WOOD_PALE, WOOD, 3.5, 0.5)
	var legno_scuro := _mat(WOOD_DARK, Color("8a6540"), 3.5, 0.5)
	var muro := _mat(PLASTER, PLASTER_SHADE, 3.0, 0.45)
	var tetto := _mat(TERRACOTTA, Color("c07a58"), 3.5, 0.5)
	var ottone := _mat(OTTONE, OTTONE_SCURO, 5.0, 0.4)

	# lo zoccolo di pietra, ottagonale come il corpo: due corsi sfalsati
	for corso in [[0.56, 0.09, 0.045], [0.52, 0.07, 0.115]]:
		var zoc := CylinderMesh.new()
		zoc.top_radius = corso[0]
		zoc.bottom_radius = corso[0] + 0.015
		zoc.height = corso[1]
		zoc.radial_segments = 8
		var zmi := MeshInstance3D.new()
		zmi.mesh = zoc
		zmi.material_override = _mat(STONE, STONE_DARK, 4.0, 0.5)
		zmi.position = Vector3(0, corso[2], 0)
		zmi.rotation.y = PI / 8.0
		n.add_child(zmi)

	# LE PARETI: quattro facce principali + quattro smussi a 45°. Ogni
	# faccia principale è in due registri — zoccalatura di legno sotto,
	# intonaco sopra — perché una parete monocolore alta 1.8 metri torna
	# a essere uno scatolone anche se ottagonale.
	var alto_legno := 0.58        # la zoccalatura: da 0.14 a 0.72
	var alto_muro := 1.20         # l'intonaco: da 0.72 a 1.92

	# fronte (-Z): zoccalatura piena, il PARAPETTO sotto il bancone (senza,
	# dal retro si vedeva il rovescio della targa attraverso il buco), e
	# sopra l'intonaco aperto attorno alla finestra ad arco
	_box(n, Vector3(0.52, alto_legno, 0.09), legno, Vector3(0, 0.43, -0.44))
	_box(n, Vector3(0.4, 0.18, 0.09), muro, Vector3(0, 0.81, -0.44))
	for sx: float in [-1.0, 1.0]:
		_box(n, Vector3(0.06, alto_muro, 0.09), muro, Vector3(sx * 0.23, 1.32, -0.44))
	# il fondale sopra il vano: un pannello PIENO da 1.45 alla gronda,
	# arretrato di un soffio (il rientro fa da battuta d'ombra). È quello
	# che rende impossibile il taglio di cielo della prima stesura ad
	# arco: cinque conci su una curva non chiudevano mai del tutto
	_box(n, Vector3(0.52, 0.47, 0.05), muro, Vector3(0, 1.685, -0.42))
	# il TIMPANO a capanna sopra la finestra: due faldine di legno chiaro
	# col concio di chiave in colmo — l'angolo sta bene a una garitta
	# fatta di facce, molto meglio di una curva finta a segmenti
	for sx2: float in [-1.0, 1.0]:
		var falda_t := _box(n, Vector3(0.27, 0.055, 0.11), legno_chiaro,
				Vector3(sx2 * 0.115, 1.51, -0.44))
		falda_t.rotation.z = sx2 * -0.32
	_box(n, Vector3(0.07, 0.1, 0.115), legno_scuro, Vector3(0, 1.56, -0.44))
	# lo scudetto sul fondale, sopra il timpano: la stessa araldica
	# dell'insegna (scudo blu, borchia d'ottone) — riempie il campo alto
	# e dice da lontano CHI abita la garitta
	_box(n, Vector3(0.15, 0.18, 0.025), _mat(BLU, BLU_CUPO, 5.0, 0.4),
			Vector3(0, 1.75, -0.45))
	var punta_scudo := _box(n, Vector3(0.105, 0.105, 0.025), _mat(BLU, BLU_CUPO, 5.0, 0.4),
			Vector3(0, 1.655, -0.45))
	punta_scudo.rotation.z = PI * 0.25
	_ball(n, 0.026, ottone, Vector3(0, 1.74, -0.465), Vector3(1.0, 1.0, 0.5))
	# il BANCONE della finestra: la mensola da cui ci si sporge, coi due
	# modiglioni sotto — è il gesto della garitta, «chiedi pure»
	_box(n, Vector3(0.56, 0.05, 0.2), legno_chiaro, Vector3(0, 0.9, -0.47))
	for sx3: float in [-1.0, 1.0]:
		var modiglione := _box(n, Vector3(0.045, 0.1, 0.1), legno,
				Vector3(sx3 * 0.2, 0.83, -0.5))
		modiglione.rotation.x = 0.5
	# e il piano interno del bancone, visibile attraverso il vano
	_box(n, Vector3(0.44, 0.04, 0.14), legno_chiaro, Vector3(0, 0.885, -0.34))

	# i fianchi (±X): due registri pieni, con l'oblò tondo in alto
	for lx: float in [-1.0, 1.0]:
		_box(n, Vector3(0.09, alto_legno, 0.52), legno, Vector3(lx * 0.44, 0.43, 0))
		_box(n, Vector3(0.09, alto_muro, 0.52), muro, Vector3(lx * 0.44, 1.32, 0))
		# l'oblò: vetro scuro in una GHIERA vera — un toro, non un cilindro:
		# il cilindro ha i tappi, e la prima stesura era un piatto di legno
		# appeso al muro col vetro sepolto dietro
		var oblo := _cyl(n, 0.08, 0.08, 0.02, _mat(Color("3f4a58"), Color("333d49"), 4.0, 0.4),
				Vector3(lx * 0.49, 1.32, 0))
		oblo.rotation.z = PI * 0.5
		var ghiera := TorusMesh.new()
		ghiera.inner_radius = 0.075
		ghiera.outer_radius = 0.115
		ghiera.rings = 24
		ghiera.ring_segments = 8
		var gmi := MeshInstance3D.new()
		gmi.mesh = ghiera
		gmi.material_override = legno_chiaro
		gmi.position = Vector3(lx * 0.49, 1.32, 0)
		gmi.rotation.z = PI * 0.5
		n.add_child(gmi)

	# il retro (+Z): la porta APERTA — niente anta, la guardia entra e
	# esce cento volte al giorno. Due spallette strette nei due registri,
	# e l'architrave di legno sopra il varco (largo 0.4, alto fino a 1.62)
	for sx4: float in [-1.0, 1.0]:
		_box(n, Vector3(0.06, alto_legno, 0.09), legno, Vector3(sx4 * 0.23, 0.43, 0.44))
		_box(n, Vector3(0.06, alto_muro, 0.09), muro, Vector3(sx4 * 0.23, 1.32, 0.44))
	_box(n, Vector3(0.52, 0.08, 0.1), legno_scuro, Vector3(0, 1.66, 0.44))
	_box(n, Vector3(0.52, 0.22, 0.09), muro, Vector3(0, 1.81, 0.44))
	# il gradino di pietra davanti alla soglia, consumato al centro
	_box(n, Vector3(0.4, 0.06, 0.18), _mat(STONE, STONE_DARK, 4.0, 0.5),
			Vector3(0, 0.03, 0.56))

	# gli SMUSSI a 45°: pannelli di legno a doghe (tutto legno, dallo
	# zoccolo alla gronda) — il materiale che cambia sull'angolo è quello
	# che spezza la scatola
	for ang_i in 4:
		var ay := PI * 0.25 + PI * 0.5 * float(ang_i)
		var giro := Node3D.new()
		giro.rotation.y = ay
		n.add_child(giro)
		_box(giro, Vector3(0.3, 1.78, 0.08), legno, Vector3(0, 1.03, -0.47))
		# le due righe di doga che danno il verso verticale
		for dx: float in [-0.075, 0.075]:
			_box(giro, Vector3(0.016, 1.7, 0.012), legno_scuro, Vector3(dx, 1.03, -0.512))
		# il montante d'angolo su ciascun bordo dello smusso: sta IN FUORI
		# rispetto a entrambe le facce che copre, o la giunzione fra parete
		# e smusso resta una fessura di luce
		for bx: float in [-1.0, 1.0]:
			_box(giro, Vector3(0.07, 1.84, 0.07), legno_scuro, Vector3(bx * 0.175, 1.06, -0.49))

	# IL TETTO: cono a OTTO SPICCHI, ruotato per allineare gli spigoli
	# ai vertici dell'ottagono, con la fascia di gronda sotto e il
	# coroncino d'ottone in punta
	var gronda := CylinderMesh.new()
	gronda.top_radius = 0.62
	gronda.bottom_radius = 0.66
	gronda.height = 0.07
	gronda.radial_segments = 8
	var grmi := MeshInstance3D.new()
	grmi.mesh = gronda
	grmi.material_override = legno_scuro
	grmi.position = Vector3(0, 1.955, 0)
	grmi.rotation.y = PI / 8.0
	n.add_child(grmi)
	var falda := CylinderMesh.new()
	falda.top_radius = 0.03
	falda.bottom_radius = 0.64
	falda.height = 0.56
	falda.radial_segments = 8
	var fmi := MeshInstance3D.new()
	fmi.mesh = falda
	fmi.material_override = tetto
	fmi.position = Vector3(0, 2.27, 0)
	fmi.rotation.y = PI / 8.0
	n.add_child(fmi)
	# il comignolo, su una falda di dietro: dentro si sta al caldo
	var comignolo := _box(n, Vector3(0.13, 0.3, 0.13), _mat(TERRACOTTA, Color("b06a4e"), 4.0, 0.5),
			Vector3(0.24, 2.32, 0.24))
	comignolo.rotation.y = PI / 8.0
	_box(n, Vector3(0.17, 0.035, 0.17), _mat(STONE, STONE_DARK, 4.0, 0.5),
			Vector3(0.24, 2.48, 0.24)).rotation.y = PI / 8.0
	# la BANDERUOLA in punta: sfera d'ottone, astina e freccia che dice
	# da dove viene il vento — la guardia lo sa sempre per prima
	_ball(n, 0.045, ottone, Vector3(0, 2.58, 0))
	_cyl(n, 0.012, 0.012, 0.26, ottone, Vector3(0, 2.72, 0))
	var freccia := Node3D.new()
	freccia.name = "Banderuola"
	freccia.position = Vector3(0, 2.8, 0)
	freccia.rotation.y = 0.65
	n.add_child(freccia)
	_box(freccia, Vector3(0.26, 0.018, 0.018), ottone, Vector3(0, 0, 0))
	var punta_fr := _box(freccia, Vector3(0.06, 0.05, 0.014), ottone, Vector3(-0.15, 0, 0))
	punta_fr.rotation.z = PI * 0.25
	for pv: float in [-1.0, 1.0]:
		_box(freccia, Vector3(0.05, 0.035, 0.014), ottone, Vector3(0.14, pv * 0.02, 0))

	# il lume azzurro su un braccio al montante, DI LATO: appeso al centro
	# pendeva esattamente sulla chiave dell'arco, e lanterna e arco si
	# mangiavano a vicenda — da un braccio, come fuori da un'osteria,
	# resta il segnale di notte senza coprire niente
	_box(n, Vector3(0.05, 0.035, 0.18), legno_scuro, Vector3(-0.3, 1.82, -0.53))
	_lume_azzurro(n, Vector3(-0.3, 1.67, -0.6), 0.7)

	# la targa blu col fregio, sul parapetto sotto il bancone
	var targa := _box(n, Vector3(0.34, 0.11, 0.03), _mat(BLU, BLU_CUPO, 5.0, 0.4),
			Vector3(0, 0.8, -0.5))
	targa.name = "Targa"
	_box(n, Vector3(0.24, 0.026, 0.012), _mat(SEGNALE_BIANCO, CREAM, 6.0, 0.2),
			Vector3(0, 0.81, -0.518))

	# la CAMPANELLA d'ottone accanto alla porta: si suona per chiamare la
	# guardia quando è in giro di ronda
	var staffa := _box(n, Vector3(0.03, 0.025, 0.14), legno_scuro, Vector3(0.3, 1.52, 0.5))
	staffa.name = "StaffaCampanella"
	_cyl(n, 0.028, 0.055, 0.07, ottone, Vector3(0.3, 1.45, 0.55))
	_ball(n, 0.016, _mat(OTTONE_SCURO, Color("8a6520"), 4.0, 0.4), Vector3(0.3, 1.4, 0.55))

	# IL POSTO DELLA GUARDIA, dentro: dove la Veglia manda chi è di turno.
	# Guarda -Z: verso la finestra, verso chi arriva a chiedere.
	var posto := Node3D.new()
	posto.name = "PostoGuardia"
	posto.position = Vector3(0, 0.14, 0.06)
	n.add_child(posto)
	return n


static func _insegna_guardia() -> Node3D:
	# L'INSEGNA DELLA GUARDIA: il palo tornito con la basetta di pietra e
	# il pomello d'ottone, il braccio con la staffa che lo stringe, e la
	# tavola APPESA che ondeggia piano — con lo scudetto blu a punta,
	# bordato d'ottone, e al centro il glifo della LANTERNA col vetrino
	# caldo: è la guardia quella che tiene il lume acceso per tutti, ed è
	# giusto che lo dica anche la sua insegna. Si monta sul bordo di una
	# cella, come un muro.
	var n := Node3D.new()
	var legno := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	var legno_scuro := _mat(WOOD_DARK, Color("8a6540"), 3.5, 0.5)
	var ottone := _mat(OTTONE, OTTONE_SCURO, 5.0, 0.4)
	var pietra := _mat(STONE, STONE_DARK, 4.0, 0.5)

	# il palo: basetta di pietra, fusto rastremato, collarino e pomello —
	# un palo piantato nudo nell'erba è un'asta, questo è un ARREDO
	_cyl(n, 0.075, 0.09, 0.07, pietra, Vector3(-0.36, 0.035, 0))
	_cyl(n, 0.042, 0.056, 1.95, legno, Vector3(-0.36, 1.045, 0))
	_cyl(n, 0.058, 0.058, 0.035, legno_scuro, Vector3(-0.36, 2.03, 0))
	_ball(n, 0.036, ottone, Vector3(-0.36, 2.08, 0))
	# la traversa col pomellino in punta, il puntone diagonale, e la
	# staffa d'ottone che stringe il palo dove il braccio si aggancia
	_box(n, Vector3(0.64, 0.06, 0.06), legno, Vector3(-0.05, 1.94, 0))
	_cyl(n, 0.02, 0.024, 0.05, legno_scuro, Vector3(0.255, 1.895, 0))
	_ball(n, 0.02, legno_scuro, Vector3(0.255, 1.865, 0))
	var puntone := _box(n, Vector3(0.04, 0.36, 0.04), legno, Vector3(-0.22, 1.78, 0))
	puntone.rotation.z = -0.72
	var staffa := TorusMesh.new()
	staffa.inner_radius = 0.048
	staffa.outer_radius = 0.066
	staffa.rings = 16
	staffa.ring_segments = 6
	var smi := MeshInstance3D.new()
	smi.mesh = staffa
	smi.material_override = ottone
	smi.position = Vector3(-0.36, 1.94, 0)
	n.add_child(smi)

	# la tavola appesa: nodo a parte, così può dondolare
	var appesa := Node3D.new()
	appesa.name = "Insegna"
	# stessa regola dell'insegna del bar: le astine stanno DENTRO la
	# campata della traversa (da −0.37 a +0.25), o restano appese all'aria
	appesa.position = Vector3(0.0, 1.91, 0)
	n.add_child(appesa)
	for dx: float in [-0.22, 0.22]:
		_cyl(appesa, 0.008, 0.008, 0.16, ottone, Vector3(dx, -0.08, 0))
	# la cornice con la battuta: due piani sfalsati, non un'asse sola —
	# è il gradino d'ombra a dire «falegname», non «compensato»
	var tavola := _box(appesa, Vector3(0.6, 0.44, 0.045), legno_scuro, Vector3(0, -0.38, 0))
	tavola.name = "Tavola"
	_box(appesa, Vector3(0.54, 0.38, 0.026), _mat(WOOD_PALE, WOOD, 3.5, 0.5),
			Vector3(0, -0.38, -0.014))
	# le borchie d'ottone agli angoli
	for bx: float in [-1.0, 1.0]:
		for by: float in [-1.0, 1.0]:
			_ball(appesa, 0.013, ottone,
					Vector3(bx * 0.25, -0.38 + by * 0.16, -0.024), Vector3(1, 1, 0.5))

	# lo scudetto blu con la punta, bordato d'ottone — ogni lastra sul
	# SUO piano: due facce complanari si tagliano in z-fighting
	_box(appesa, Vector3(0.2, 0.2, 0.012), ottone, Vector3(0, -0.322, -0.028))
	var bordo_punta := _box(appesa, Vector3(0.145, 0.145, 0.012), ottone,
			Vector3(0, -0.408, -0.026))
	bordo_punta.rotation.z = PI * 0.25
	var scudo := _box(appesa, Vector3(0.17, 0.17, 0.014), _mat(BLU, BLU_CUPO, 5.0, 0.4),
			Vector3(0, -0.325, -0.036))
	scudo.name = "Scudo"
	var punta_blu := _box(appesa, Vector3(0.12, 0.12, 0.014), _mat(BLU, BLU_CUPO, 5.0, 0.4),
			Vector3(0, -0.402, -0.0335))
	punta_blu.rotation.z = PI * 0.25

	# il glifo della lanterna, d'ottone col vetrino caldo: cappellino,
	# montanti, vetro appena acceso, coppa e anellino
	_ball(appesa, 0.009, ottone, Vector3(0, -0.262, -0.048))
	_cyl(appesa, 0.012, 0.038, 0.032, ottone, Vector3(0, -0.288, -0.048))
	for mx: float in [-1.0, 1.0]:
		_box(appesa, Vector3(0.008, 0.052, 0.008), ottone, Vector3(mx * 0.026, -0.331, -0.048))
	var vetro_lume := _glow(Color("ffe9b8"), Color("ffd27a"), 0.42)
	_box(appesa, Vector3(0.04, 0.05, 0.014), vetro_lume, Vector3(0, -0.331, -0.048))
	_cyl(appesa, 0.026, 0.03, 0.014, ottone, Vector3(0, -0.364, -0.048))

	# l'ondeggio, con un periodo diverso dall'insegna della caserma: due
	# insegne che dondolano all'unisono tradiscono il metronomo
	var oscilla := Animation.new()
	oscilla.length = 5.7
	oscilla.loop_mode = Animation.LOOP_LINEAR
	var tr := oscilla.add_track(Animation.TYPE_VALUE)
	oscilla.track_set_path(tr, NodePath("Insegna:rotation:x"))
	oscilla.track_insert_key(tr, 0.0, -0.017)
	oscilla.track_insert_key(tr, 2.85, 0.021)
	oscilla.track_insert_key(tr, 5.7, -0.017)
	oscilla.track_set_interpolation_type(tr, Animation.INTERPOLATION_CUBIC)
	var lib := AnimationLibrary.new()
	lib.add_animation("dondola", oscilla)
	var player := AnimationPlayer.new()
	n.add_child(player)
	player.add_animation_library("", lib)
	player.autoplay = "dondola"
	return n


static func _sbarra() -> Node3D:
	# LA SBARRA: si alza davvero. L'asta vive in un pivot chiamato "Asta"
	# incernierato sul montante, così chi vuole può farla sollevare con un
	# tween di 90 gradi (e il contrappeso scende dall'altra parte).
	var n := Node3D.new()
	var metallo := _mat(METAL, Color("6f665b"), 5.0, 0.4)
	_cyl(n, 0.16, 0.2, 0.09, _mat(STONE, STONE_DARK, 4.0, 0.5), Vector3(-0.42, 0.045, 0))
	_box(n, Vector3(0.14, 0.86, 0.14), metallo, Vector3(-0.42, 0.48, 0))
	_cyl(n, 0.075, 0.075, 0.14, metallo, Vector3(-0.42, 0.86, 0)).rotation.x = PI * 0.5
	var asta := Node3D.new()
	asta.name = "Asta"
	asta.position = Vector3(-0.42, 0.86, 0)
	n.add_child(asta)
	# il braccio a fasce, che parte dal perno e va a destra
	var braccio := Node3D.new()
	braccio.position = Vector3(0.62, 0, 0)
	asta.add_child(braccio)
	_fasce(braccio, 1.2, 0.07, 0.07, 0, 6)
	# il contrappeso, dalla parte corta
	_ball(asta, 0.075, metallo, Vector3(-0.17, 0, 0), Vector3(1, 0.85, 1))
	# il piedino d'appoggio all'altro capo
	_cyl(n, 0.05, 0.07, 0.5, metallo, Vector3(0.86, 0.25, 0))
	return n


static func _bancone_piantone() -> Node3D:
	# IL BANCONE: il piano dove si consegna e si chiede. Il registro aperto,
	# il timbro, e il campanello che si suona quando non c'è nessuno —
	# nodo "Campanello", così un domani può fare tin.
	var n := Node3D.new()
	var legno := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	var piano := _mat(WOOD_PALE, WOOD, 3.5, 0.5)
	_box(n, Vector3(0.94, 0.72, 0.42), legno, Vector3(0, 0.36, 0.02))
	# la modanatura del fronte e il piano che sporge
	_box(n, Vector3(0.9, 0.1, 0.03), piano, Vector3(0, 0.62, -0.2))
	_box(n, Vector3(1.02, 0.07, 0.52), piano, Vector3(0, 0.76, 0))
	# il registro aperto: due pagine appena inclinate
	for lato: float in [-1.0, 1.0]:
		var pag := _box(n, Vector3(0.15, 0.012, 0.2),
				_mat(CREAM, Color("f0e4cc"), 6.0, 0.25),
				Vector3(lato * 0.08, 0.8, 0.02))
		pag.rotation.z = lato * 0.06
	_box(n, Vector3(0.03, 0.02, 0.2), _mat(WOOD_DARK, WOOD_DARK, 3.0, 0.2),
			Vector3(0, 0.805, 0.02))
	# il timbro col manico
	var ottone := _mat(OTTONE, OTTONE_SCURO, 5.0, 0.4)
	_cyl(n, 0.045, 0.045, 0.05, _mat(WOOD_DARK, WOOD_DARK, 4.0, 0.4), Vector3(0.33, 0.82, -0.06))
	_cyl(n, 0.018, 0.026, 0.07, ottone, Vector3(0.33, 0.87, -0.06))
	_ball(n, 0.028, _mat(WOOD, WOOD_DARK, 4.0, 0.4), Vector3(0.33, 0.92, -0.06))
	# il campanello da banco
	var campanello := Node3D.new()
	campanello.name = "Campanello"
	campanello.position = Vector3(-0.34, 0.8, -0.05)
	n.add_child(campanello)
	_cyl(campanello, 0.06, 0.062, 0.012, ottone, Vector3(0, 0, 0))
	_ball(campanello, 0.055, ottone, Vector3(0, 0.035, 0), Vector3(1, 0.72, 1))
	_ball(campanello, 0.014, ottone, Vector3(0, 0.075, 0))
	return n


static func _armadio_smarriti() -> Node3D:
	# L'ARMADIO DEGLI OGGETTI SMARRITI: il cuore del posto. Tanti cassettini
	# con la maniglia d'ottone e il cartellino; due sono socchiusi, e da uno
	# spunta una sciarpa che qualcuno prima o poi verrà a riprendersi.
	var n := Node3D.new()
	var legno := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	var fronte := _mat(WOOD_PALE, WOOD, 3.5, 0.45)
	var ottone := _mat(OTTONE, OTTONE_SCURO, 5.0, 0.4)
	_box(n, Vector3(0.9, 1.5, 0.42), legno, Vector3(0, 0.75, 0.03))
	# la cornice del tetto e il piedino
	_box(n, Vector3(0.98, 0.07, 0.48), fronte, Vector3(0, 1.53, 0.03))
	_box(n, Vector3(0.94, 0.09, 0.45), legno, Vector3(0, 0.045, 0.03))
	# quattro file da tre cassettini
	for riga in 4:
		for col in 3:
			var y := 0.28 + 0.33 * float(riga)
			var x := -0.28 + 0.28 * float(col)
			# due cassetti socchiusi: la vita è storta, gli armadi anche
			var fuori := 0.0
			if (riga == 2 and col == 0) or (riga == 0 and col == 2):
				fuori = 0.07
			var cass := _box(n, Vector3(0.25, 0.28, 0.38), fronte,
					Vector3(x, y, -0.03 - fuori))
			cass.name = "Cassetto%d%d" % [riga, col]
			_cyl(n, 0.022, 0.022, 0.03, ottone,
					Vector3(x, y, -0.22 - fuori)).rotation.x = PI * 0.5
			# il cartellino col numero
			_box(n, Vector3(0.09, 0.045, 0.008), _mat(CREAM, Color("efe2ca"), 6.0, 0.2),
					Vector3(x, y + 0.085, -0.225 - fuori))
	# la sciarpa che sporge dal cassetto socchiuso in alto
	var sciarpa := _box(n, Vector3(0.16, 0.035, 0.1), _mat(PINK, PINK_DEEP, 5.0, 0.45),
			Vector3(0.0, 0.255, -0.28))
	sciarpa.rotation.x = 0.35
	sciarpa.name = "Sciarpa"
	return n


static func _bacheca_avvisi() -> Node3D:
	# LA BACHECA: sughero, cornice di legno e i bigliettini appuntati di
	# sghembo — nessuno appende un avviso dritto.
	var n := Node3D.new()
	var legno := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	for sx: float in [-0.46, 0.46]:
		_box(n, Vector3(0.08, 1.35, 0.08), legno, Vector3(sx, 0.68, 0.04))
	_box(n, Vector3(1.0, 0.09, 0.09), legno, Vector3(0, 1.36, 0.04))
	_box(n, Vector3(0.94, 0.72, 0.05), _mat(SUGHERO, Color("c39a6c"), 6.0, 0.5),
			Vector3(0, 1.0, 0.04))
	# la cornicetta interna
	for dy: float in [-0.38, 0.38]:
		_box(n, Vector3(0.96, 0.04, 0.07), legno, Vector3(0, 1.0 + dy, 0.04))
	# i bigliettini, ognuno storto a modo suo
	var carte := [[-0.28, 1.14, -0.13, Color("fff6e2")], [0.02, 1.18, 0.09, Color("e8f2e0")],
			[0.3, 1.1, -0.06, Color("fde8e4")], [-0.14, 0.88, 0.14, Color("fff6e2")],
			[0.22, 0.85, -0.11, Color("e4eef8")]]
	for c in carte:
		var carta := _box(n, Vector3(0.2, 0.16, 0.008),
				_mat(Color(c[3]), Color(c[3]).darkened(0.08), 6.0, 0.2),
				Vector3(float(c[0]), float(c[1]), 0.015))
		carta.rotation.z = float(c[2])
		# la puntina
		_ball(n, 0.014, _mat(SEGNALE_ROSSO, Color("c96f60"), 4.0, 0.3),
				Vector3(float(c[0]), float(c[1]) + 0.06, 0.005))
	return n


static func _attaccapanni_berretto() -> Node3D:
	# L'ATTACCAPANNI COL BERRETTO: il turno finisce, il berretto resta lì.
	var n := Node3D.new()
	var legno := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	_cyl(n, 0.09, 0.14, 0.06, legno, Vector3(0, 0.03, 0))
	_cyl(n, 0.035, 0.045, 1.5, legno, Vector3(0, 0.75, 0))
	# i tre bracci
	for i in 3:
		var a := PI * 2.0 / 3.0 * float(i)
		var braccio := _cyl(n, 0.018, 0.022, 0.17, legno,
				Vector3(cos(a) * 0.07, 1.44, sin(a) * 0.07))
		braccio.rotation.x = cos(a) * 0.0 + 0.6
		braccio.rotation.y = -a
		braccio.rotation.z = 0.7
		_ball(n, 0.026, legno, Vector3(cos(a) * 0.14, 1.5, sin(a) * 0.14))
	# il berretto d'ordinanza appeso al braccio davanti
	var berretto := Node3D.new()
	berretto.name = "Berretto"
	berretto.position = Vector3(0.0, 1.44, -0.15)
	n.add_child(berretto)
	var panno := _mat(BLU, BLU_CUPO, 5.0, 0.45)
	_cyl(berretto, 0.11, 0.105, 0.09, panno, Vector3(0, 0, 0))
	_cyl(berretto, 0.125, 0.125, 0.02, _mat(BLU_CUPO, Color("4c6699"), 4.0, 0.4),
			Vector3(0, -0.05, 0))
	# la visiera
	var visiera := _cyl(berretto, 0.13, 0.13, 0.015,
			_mat(Color("3f4a5c"), Color("323b4a"), 4.0, 0.35), Vector3(0, -0.055, -0.09))
	visiera.scale = Vector3(1.0, 1.0, 0.55)
	visiera.rotation.x = 0.22
	# lo stemmino d'ottone
	_box(berretto, Vector3(0.05, 0.05, 0.01), _mat(OTTONE, OTTONE_SCURO, 5.0, 0.35),
			Vector3(0, 0.005, -0.105))
	return n


static func _brandina_turno() -> Node3D:
	# LA BRANDINA DEL TURNO DI NOTTE: una branda da campo, la coperta
	# piegata in fondo e il cuscino ammaccato da chi ci ha dormito.
	var n := Node3D.new()
	var legno := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	var telo := _mat(Color("cfd8c8"), Color("b8c2b0"), 5.0, 0.45)
	# le due X delle gambe
	for sz: float in [-0.3, 0.3]:
		for lato: float in [-1.0, 1.0]:
			var g := _box(n, Vector3(0.045, 0.42, 0.045), legno,
					Vector3(lato * 0.3, 0.2, sz))
			g.rotation.z = lato * 0.34
	_box(n, Vector3(0.9, 0.05, 0.05), legno, Vector3(0, 0.2, -0.3))
	_box(n, Vector3(0.9, 0.05, 0.05), legno, Vector3(0, 0.2, 0.3))
	# il telo teso, che cede appena al centro
	_box(n, Vector3(0.88, 0.05, 0.62), telo, Vector3(0, 0.4, 0))
	_box(n, Vector3(0.8, 0.03, 0.5), telo, Vector3(0, 0.385, 0))
	# il cuscino e la coperta piegata
	var cuscino := _ball(n, 0.13, _mat(CREAM, Color("f0e4cc"), 5.0, 0.35),
			Vector3(-0.28, 0.45, 0), Vector3(1.0, 0.52, 1.3))
	cuscino.name = "Cuscino"
	_box(n, Vector3(0.34, 0.09, 0.6), _mat(BLU, BLU_CUPO, 5.0, 0.5),
			Vector3(0.24, 0.46, 0))
	_box(n, Vector3(0.34, 0.03, 0.6), _mat(BLU_CUPO, Color("4c6699"), 5.0, 0.4),
			Vector3(0.24, 0.51, 0))
	return n


static func _lanterna_blu() -> Node3D:
	# LA LANTERNA BLU su un palo: il faro del posto di guardia. Di notte si
	# vede da lontano, e vuol dire che c'è qualcuno sveglio per te.
	var n := Node3D.new()
	var metallo := _mat(METAL, Color("6f665b"), 5.0, 0.4)
	_cyl(n, 0.13, 0.17, 0.09, _mat(STONE, STONE_DARK, 4.0, 0.5), Vector3(0, 0.045, 0))
	_cyl(n, 0.035, 0.05, 1.72, metallo, Vector3(0, 0.86, 0))
	_cyl(n, 0.07, 0.05, 0.05, metallo, Vector3(0, 1.72, 0))
	_lume_azzurro(n, Vector3(0, 1.86, 0), 1.15)
	return n


static func _cono_segnaletico() -> Node3D:
	# IL CONO: piccolo, storto, con la fascia riflettente. Ne bastano due
	# per dire «qui stanno facendo qualcosa».
	var n := Node3D.new()
	var arancio := _mat(Color("e8956a"), Color("d07a52"), 4.0, 0.45)
	_box(n, Vector3(0.3, 0.035, 0.3), _mat(Color("d07a52"), Color("b8663f"), 4.0, 0.4),
			Vector3(0, 0.018, 0))
	var cono := _cyl(n, 0.03, 0.115, 0.38, arancio, Vector3(0, 0.22, 0))
	cono.name = "Cono"
	cono.rotation.z = 0.05    # nessun cono è mai perfettamente dritto
	_cyl(n, 0.078, 0.09, 0.06, _mat(SEGNALE_BIANCO, Color("e9e2d2"), 5.0, 0.3),
			Vector3(0.006, 0.25, 0))
	return n


static func _transenna() -> Node3D:
	# LA TRANSENNA: due cavalletti e l'asse a fasce. Sta sul bordo, come una
	# staccionata, ma si sposta — è provvisoria per definizione.
	var n := Node3D.new()
	var legno := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	for sx: float in [-0.36, 0.36]:
		for lato: float in [-1.0, 1.0]:
			var g := _box(n, Vector3(0.05, 0.72, 0.05), legno,
					Vector3(sx, 0.34, lato * 0.12))
			g.rotation.x = lato * 0.26
	var asse := Node3D.new()
	asse.position = Vector3(0, 0.56, 0)
	n.add_child(asse)
	_fasce(asse, 0.96, 0.06, 0.17, 0, 5)
	_box(n, Vector3(0.96, 0.06, 0.05), legno, Vector3(0, 0.34, 0))
	return n


static func _bicicletta_servizio() -> Node3D:
	# LA BICICLETTA DI SERVIZIO: appoggiata sul cavalletto, col cestino
	# davanti. Nessuno insegue nessuno, in questo villaggio: si fa il giro.
	var n := Node3D.new()
	var telaio := _mat(BLU, BLU_CUPO, 5.0, 0.45)
	var gomma := _mat(Color("4a4640"), Color("3a3733"), 4.0, 0.35)
	var ottone := _mat(OTTONE, OTTONE_SCURO, 5.0, 0.4)
	# appoggiata: tutta la bici pende di un soffio sul cavalletto
	var bici := Node3D.new()
	bici.name = "Bici"
	bici.rotation.z = 0.09
	n.add_child(bici)
	for dz: float in [-0.34, 0.34]:
		var ruota := _cyl(bici, 0.27, 0.27, 0.05, gomma, Vector3(0, 0.28, dz))
		ruota.rotation.x = PI * 0.5
		var cerchio := _cyl(bici, 0.21, 0.21, 0.055, _mat(SEGNALE_BIANCO, CREAM, 5.0, 0.25),
				Vector3(0, 0.28, dz))
		cerchio.rotation.x = PI * 0.5
		var mozzo := _cyl(bici, 0.035, 0.035, 0.07, ottone, Vector3(0, 0.28, dz))
		mozzo.rotation.x = PI * 0.5
	# il telaio: tubi GROSSI, o da lontano la bici sparisce e restano due
	# ruote per aria. Il triangolo posteriore è quello che la fa leggere
	# come una bicicletta e non come un monociclo.
	_box(bici, Vector3(0.075, 0.075, 0.66), telaio, Vector3(0, 0.52, 0))
	var t2 := _box(bici, Vector3(0.075, 0.46, 0.075), telaio, Vector3(0, 0.44, 0.28))
	t2.rotation.x = -0.3
	var t3 := _box(bici, Vector3(0.075, 0.5, 0.075), telaio, Vector3(0, 0.42, -0.3))
	t3.rotation.x = 0.36
	# i foderi: dal movimento centrale alla ruota dietro
	for dy: float in [0.0, 0.26]:
		var fodero := _box(bici, Vector3(0.05, 0.05, 0.4), telaio,
				Vector3(0, 0.3 + dy * 0.6, 0.18))
		fodero.rotation.x = -0.32 - dy * 0.5
	# la corona e il pedale: il dettaglio che dice «ci si va davvero»
	var corona := _cyl(bici, 0.075, 0.075, 0.02, ottone, Vector3(0, 0.3, 0.02))
	corona.rotation.x = PI * 0.5
	_box(bici, Vector3(0.05, 0.02, 0.09), gomma, Vector3(0.09, 0.24, 0.02))
	# sella e manubrio
	var sella := _box(bici, Vector3(0.09, 0.05, 0.22), _mat(WOOD_DARK, Color("6b4a33"), 4.0, 0.4),
			Vector3(0, 0.68, 0.28))
	sella.name = "Sella"
	var manubrio := _box(bici, Vector3(0.36, 0.045, 0.045), telaio, Vector3(0, 0.72, -0.3))
	manubrio.name = "Manubrio"
	for sx: float in [-0.16, 0.16]:
		_cyl(bici, 0.028, 0.028, 0.09, gomma, Vector3(sx, 0.72, -0.3)).rotation.z = PI * 0.5
	# il cestino di vimini davanti
	var cesto := _cyl(bici, 0.14, 0.11, 0.19, _mat(WOOD_PALE, WOOD, 7.0, 0.6),
			Vector3(0, 0.63, -0.34))
	cesto.name = "Cestino"
	# il campanello e il cavalletto
	_cyl(bici, 0.032, 0.032, 0.035, ottone, Vector3(-0.12, 0.76, -0.3))
	var cavalletto := _cyl(n, 0.018, 0.018, 0.34, gomma, Vector3(-0.13, 0.17, 0.16))
	cavalletto.rotation.z = 0.32
	return n


static func _cassetta_smarriti() -> Node3D:
	# LA CASSETTA DEGLI SMARRITI: quella fuori, con la fessura e il tettuccio,
	# per quando trovi qualcosa e il posto è chiuso. Si lascia lì e domani
	# torna a chi l'ha perso. Sportello "Sportello", come la cassetta posta.
	var n := Node3D.new()
	var legno := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	var corpo := _mat(BLU, BLU_CUPO, 4.5, 0.45)
	_cyl(n, 0.05, 0.07, 0.72, legno, Vector3(0, 0.36, 0))
	_box(n, Vector3(0.42, 0.44, 0.3), corpo, Vector3(0, 0.94, 0))
	# il tettuccio spiovente
	var tetto := _box(n, Vector3(0.5, 0.05, 0.38), legno, Vector3(0, 1.19, -0.02))
	tetto.rotation.x = -0.16
	# la fessura, con la sua ombra
	_box(n, Vector3(0.26, 0.045, 0.02), _mat(Color("2f3742"), Color("262d36"), 3.0, 0.3),
			Vector3(0, 1.05, -0.152))
	_box(n, Vector3(0.3, 0.02, 0.03), _mat(OTTONE, OTTONE_SCURO, 5.0, 0.35),
			Vector3(0, 1.085, -0.155))
	# lo sportello di ritiro, incernierato in basso
	var sportello := Node3D.new()
	sportello.name = "Sportello"
	sportello.position = Vector3(0, 0.76, -0.15)
	n.add_child(sportello)
	_box(sportello, Vector3(0.34, 0.24, 0.02), _mat(BLU_CUPO, Color("4c6699"), 4.0, 0.4),
			Vector3(0, 0.12, 0))
	_cyl(sportello, 0.02, 0.02, 0.02, _mat(OTTONE, OTTONE_SCURO, 5.0, 0.35),
			Vector3(0, 0.2, -0.018)).rotation.x = PI * 0.5
	# il cartellino
	_box(n, Vector3(0.2, 0.07, 0.012), _mat(CREAM, Color("efe2ca"), 6.0, 0.25),
			Vector3(0, 0.66, -0.152))
	return n


# ============================================================================
# LA CASERMA DEI POMPIERI
# ============================================================================
# Qui non brucia niente, e non brucerà mai: la regola cozy non si tocca.
# Questa caserma non serve a SPEGNERE, serve a TENERE PRONTO — che in un
# villaggio dove nessuno è in pericolo è un'altra forma di affetto. La
# manichetta annaffia gli orti, la campana chiama tutti in piazza, il palo
# d'ottone porta giù dal solaio in un fiato, e l'autopompa sta lì lucidata
# da qualcuno che ci tiene, anche se non la chiamerà mai nessuno.
#
# Come il posto di guardia, l'àncora è un pezzo solo (l'Autopompa) e il
# resto arriva col corredo (Economy.CORREDO): un posto arriva con le sue
# cose. Fronte di tutti i pezzi: verso -Z, come il resto del catalogo.
#
# La tavolozza (POMPA_ROSSO, GOMMA, VETRO) è in cima al file; l'ottone è
# quello condiviso di tutto il villaggio.


## La sezione del loft: un rettangolo ad angoli tondi nel piano YZ,
## percorso in senso antiorario (visto con +Z a destra e +Y in su).
## w = mezza larghezza, y0/y1 = base e cima, r = raggio degli angoli,
## k = campioni per arco. Ritorna coppie (z, y).
static func _anello_tondo(w: float, y0: float, y1: float, r: float, k: int) -> PackedVector2Array:
	var rr := clampf(r, 0.0, minf(w, (y1 - y0) * 0.5))
	var cz := w - rr
	var centri := [Vector2(cz, y0 + rr), Vector2(cz, y1 - rr),
			Vector2(-cz, y1 - rr), Vector2(-cz, y0 + rr)]
	var partenze := [-PI * 0.5, 0.0, PI * 0.5, PI]
	var out := PackedVector2Array()
	for c in 4:
		for i in k + 1:
			var a := float(partenze[c]) + float(i) / float(k) * PI * 0.5
			out.append((centri[c] as Vector2) + Vector2(cos(a), sin(a)) * rr)
	return out


## IL LOFT lungo X a sezione stondata: ogni stazione è [x, w, y0, y1, r]
## e la sezione cambia da una all'altra con le normali che restano
## morbide. È l'attrezzo che toglie la squadratura ai volumi grossi —
## cofani bombati, tetti a botte, spalle tonde, code arrotondate — dove
## una scatola resterebbe una scatola. Tappi piatti alle estremità
## (vertici doppi: il bordo resta un bordo, non si «fonde» col fianco).
static func _loft(parent: Node3D, stazioni: Array, mat: Material,
		pos := Vector3.ZERO, k := 5) -> MeshInstance3D:
	var ns := stazioni.size()
	var anelli: Array[PackedVector2Array] = []
	for s in stazioni:
		anelli.append(_anello_tondo(float(s[1]), float(s[2]), float(s[3]),
				float(s[4]), k))
	var giro := anelli[0].size()
	var vg: Array = []
	for si in ns:
		var riga: Array[Vector3] = []
		for i in giro:
			riga.append(Vector3(float(stazioni[si][0]),
					anelli[si][i].y, anelli[si][i].x))
		vg.append(riga)
	# normali per vertice: tangente lungo X per tangente lungo il giro
	var ng: Array = []
	for si in ns:
		var riga_n: Array[Vector3] = []
		for i in giro:
			var t_giro: Vector3 = vg[si][(i + 1) % giro] - vg[si][(i - 1 + giro) % giro]
			var t_x: Vector3 = vg[mini(si + 1, ns - 1)][i] - vg[maxi(si - 1, 0)][i]
			riga_n.append(t_x.cross(t_giro).normalized())
		ng.append(riga_n)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for si in ns - 1:
		for i in giro:
			var i2 := (i + 1) % giro
			st.set_normal(ng[si][i]);      st.add_vertex(vg[si][i])
			st.set_normal(ng[si + 1][i2]); st.add_vertex(vg[si + 1][i2])
			st.set_normal(ng[si + 1][i]);  st.add_vertex(vg[si + 1][i])
			st.set_normal(ng[si][i]);      st.add_vertex(vg[si][i])
			st.set_normal(ng[si][i2]);     st.add_vertex(vg[si][i2])
			st.set_normal(ng[si + 1][i2]); st.add_vertex(vg[si + 1][i2])
	# i tappi
	var c0 := Vector3(float(stazioni[0][0]),
			(float(stazioni[0][2]) + float(stazioni[0][3])) * 0.5, 0)
	var c1 := Vector3(float(stazioni[ns - 1][0]),
			(float(stazioni[ns - 1][2]) + float(stazioni[ns - 1][3])) * 0.5, 0)
	for i in giro:
		var i2 := (i + 1) % giro
		st.set_normal(Vector3(-1, 0, 0)); st.add_vertex(c0)
		st.set_normal(Vector3(-1, 0, 0)); st.add_vertex(vg[0][i2])
		st.set_normal(Vector3(-1, 0, 0)); st.add_vertex(vg[0][i])
		st.set_normal(Vector3(1, 0, 0));  st.add_vertex(c1)
		st.set_normal(Vector3(1, 0, 0));  st.add_vertex(vg[ns - 1][i])
		st.set_normal(Vector3(1, 0, 0));  st.add_vertex(vg[ns - 1][i2])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


## LA LASTRA: un pannello ad angoli tondi, centrato sull'origine, spesso
## `sp` lungo X (le facce guardano ±X: per un fianco si ruota di PI/2).
## Portelli, vetri, cornici: tutto ciò che era un _box con gli spigoli
## a coltello e adesso ha gli angoli di un giocattolo laccato.
static func _lastra(parent: Node3D, w: float, h: float, r: float, sp: float,
		mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := _loft(parent, [[-sp * 0.5, w, -h * 0.5, h * 0.5, r],
			[sp * 0.5, w, -h * 0.5, h * 0.5, r]], mat, pos)
	mi.rotation = rot
	return mi


## L'AUTOPOMPA. Il pezzo grosso della caserma, e nemmeno una squadra:
## cofano bombato che scende sul muso fino alla griglia d'ottone,
## parafanghi ad arco sulle ruote, gomme a toro col coprimozzo lucidato,
## cabina col tetto a botte e il parabrezza inclinato di vetro vero,
## spalle tonde, coda arrotondata col mulinello della manichetta, la
## campana davanti e la scala d'ottone sul tetto. Un'autopompa
## d'anteguerra in lacca da giocattolo: paffuta, corta, e tonda ovunque —
## se fosse in scala sembrerebbe un mezzo di lavoro, e questo è un villaggio.
static func _autopompa() -> Node3D:
	var n := Node3D.new()
	var rosso := _mat(POMPA_ROSSO, POMPA_ROSSO_SCURO, 3.0, 0.45)
	var scuro := _mat(POMPA_ROSSO_SCURO, POMPA_ROSSO_SCURO.darkened(0.2), 4.0, 0.5)
	var ottone := _mat(OTTONE, OTTONE_SCURO, 5.0, 0.4)
	var gomma := _mat(GOMMA, GOMMA.darkened(0.25), 6.0, 0.35)
	var crema := _mat(CREAM, PLASTER_SHADE, 4.0, 0.4)
	var vetro := _vetro(0.4)

	# il telaio basso, ed è lui la fascia chiara che dice «pompieri»:
	# gira intera da paraurti a coda, sotto tutto il rosso, e finisce
	# tondo davanti e dietro come il resto
	_loft(n, [[-0.70, 0.26, 0.275, 0.385, 0.05],
			[-0.64, 0.29, 0.275, 0.385, 0.03],
			[0.70, 0.29, 0.275, 0.385, 0.03],
			[0.76, 0.26, 0.275, 0.385, 0.05]], crema)

	# IL COFANO: si bomba in alto e scende sul muso, restringendosi fino
	# a un naso tondo — la sagoma che nessuna scatola sa fare. Finisce
	# DENTRO il torpedo della cabina, un filo più basso: il giunto è suo.
	_loft(n, [[-0.88, 0.11, 0.52, 0.62, 0.054],
			[-0.86, 0.16, 0.47, 0.68, 0.078],
			[-0.82, 0.20, 0.43, 0.72, 0.088],
			[-0.74, 0.22, 0.40, 0.74, 0.09],
			[-0.62, 0.235, 0.375, 0.76, 0.09],
			[-0.50, 0.245, 0.365, 0.775, 0.085]], rosso)
	# la gonna che raccorda il fianco del cofano alla cima del parafango:
	# senza, fra i due resta una fessura d'ombra passante
	for z: float in [-0.245, 0.245]:
		_loft(n, [[-0.78, 0.055, 0.35, 0.44, 0.02],
				[-0.48, 0.055, 0.35, 0.46, 0.02]], rosso, Vector3(0, 0, z))

	# LA CABINA: il torpedo davanti (appena più alto del cofano), il
	# parabrezza è la salita ripida, il tetto una botte tonda anche dietro
	_loft(n, [[-0.56, 0.305, 0.36, 0.79, 0.075],
			[-0.50, 0.305, 0.36, 0.80, 0.075],
			[-0.42, 0.305, 0.36, 1.00, 0.09],
			[-0.34, 0.305, 0.36, 1.03, 0.11],
			[-0.22, 0.305, 0.36, 1.03, 0.11],
			[-0.14, 0.30, 0.36, 1.00, 0.10],
			[-0.06, 0.295, 0.36, 0.92, 0.08]], rosso)

	# IL CASSONE: spalle tonde, e la coda che si chiude arrotondata
	_loft(n, [[-0.10, 0.30, 0.365, 0.88, 0.07],
			[0.50, 0.30, 0.365, 0.88, 0.07],
			[0.62, 0.295, 0.37, 0.875, 0.09],
			[0.70, 0.27, 0.38, 0.85, 0.12],
			[0.74, 0.22, 0.42, 0.80, 0.16]], rosso)

	# LA GRIGLIA del radiatore: cornice d'ottone, cuore scuro proud della
	# cornice (chi guarda da davanti vede l'anello d'ottone attorno), e le
	# canne verticali. Sopra, il tappo del radiatore.
	_lastra(n, 0.145, 0.23, 0.07, 0.035, ottone, Vector3(-0.885, 0.60, 0))
	_lastra(n, 0.115, 0.18, 0.05, 0.02, scuro, Vector3(-0.90, 0.60, 0))
	for z: float in [-0.08, -0.04, 0.0, 0.04, 0.08]:
		_cyl(n, 0.0055, 0.0055, 0.155, ottone, Vector3(-0.912, 0.60, z))
	_cyl(n, 0.012, 0.016, 0.02, ottone, Vector3(-0.86, 0.735, 0))
	_ball(n, 0.011, ottone, Vector3(-0.86, 0.75, 0))

	# IL PARAURTI: una barra d'ottone che curva indietro alle estremità e
	# si rincalza DENTRO i parafanghi — un tubo tagliato a mezz'aria
	# mostra il tappo, e un paraurti non finisce nel vuoto
	BUILDER.tube(n, [Vector3(-0.83, 0.315, -0.33), Vector3(-0.905, 0.325, -0.26),
			Vector3(-0.925, 0.325, -0.12), Vector3(-0.925, 0.325, 0.12),
			Vector3(-0.905, 0.325, 0.26), Vector3(-0.83, 0.315, 0.33)],
			[0.026, 0.026, 0.026, 0.026, 0.026, 0.026], ottone)

	# I PARAFANGHI: archi spazzati sopra le ruote — il gesto che più di
	# ogni altro toglie la squadratura a un camion. Toccano la fascia del
	# telaio (un parafango che galleggia è un croissant, non un parafango)
	# e fra i due corrono le pedane.
	for z: float in [-0.345, 0.345]:
		BUILDER.tube(n, [Vector3(-0.84, 0.30, z), Vector3(-0.77, 0.41, z),
				Vector3(-0.69, 0.48, z), Vector3(-0.60, 0.48, z),
				Vector3(-0.50, 0.40, z), Vector3(-0.44, 0.30, z)],
				[0.03, 0.048, 0.055, 0.055, 0.048, 0.03], rosso)
		BUILDER.tube(n, [Vector3(0.26, 0.30, z), Vector3(0.33, 0.40, z),
				Vector3(0.41, 0.47, z), Vector3(0.51, 0.475, z),
				Vector3(0.62, 0.42, z), Vector3(0.70, 0.30, z)],
				[0.03, 0.048, 0.055, 0.055, 0.048, 0.03], rosso)
		_loft(n, [[-0.42, 0.05, 0.345, 0.375, 0.012],
				[0.27, 0.05, 0.345, 0.375, 0.012]], crema,
				Vector3(0, 0, z))

	# LE RUOTE: la gomma è un toro vero, il mozzo chiaro col coprimozzo
	# d'ottone a cupola; sotto il telaio corrono gli assali
	for x: float in [-0.62, 0.50]:
		var assale := _cyl(n, 0.024, 0.024, 0.72, scuro, Vector3(x, 0.19, 0))
		assale.rotation.x = PI * 0.5
		for sz: float in [-1.0, 1.0]:
			var gz := sz * 0.335
			var t := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.08
			tm.outer_radius = 0.19
			t.mesh = tm
			t.material_override = gomma
			t.position = Vector3(x, 0.19, gz)
			t.rotation.x = PI * 0.5
			n.add_child(t)
			var mozzo := _cyl(n, 0.088, 0.088, 0.115, crema, Vector3(x, 0.19, gz))
			mozzo.rotation.x = PI * 0.5
			_ball(n, 0.032, ottone, Vector3(x, 0.19, sz * 0.395),
					Vector3(1, 1, 0.55))

	# IL PARABREZZA, inclinato come la salita del tetto: cornice d'ottone,
	# interno in penombra e vetro vero davanti (l'ordine dei tre strati fa
	# vedere l'anello d'ottone attorno al vetro)
	var pb := Node3D.new()
	pb.position = Vector3(-0.465, 0.895, 0)
	pb.rotation.z = -0.35
	n.add_child(pb)
	_lastra(pb, 0.26, 0.23, 0.05, 0.016, ottone, Vector3.ZERO)
	_lastra(pb, 0.235, 0.18, 0.042, 0.016, scuro, Vector3(-0.005, 0, 0))
	_lastra(pb, 0.24, 0.19, 0.045, 0.012, vetro, Vector3(-0.012, 0, 0))

	# I FINESTRINI delle portiere (stessi tre strati), le portiere
	# profilate d'oro come le carrozze, e le maniglie
	for sz: float in [-1.0, 1.0]:
		var giro_y := sz * PI * 0.5
		_lastra(n, 0.112, 0.194, 0.048, 0.014, ottone,
				Vector3(-0.30, 0.885, sz * 0.306), Vector3(0, giro_y, 0))
		_lastra(n, 0.094, 0.166, 0.04, 0.014, scuro,
				Vector3(-0.30, 0.885, sz * 0.310), Vector3(0, giro_y, 0))
		_lastra(n, 0.098, 0.17, 0.042, 0.01, vetro,
				Vector3(-0.30, 0.885, sz * 0.316), Vector3(0, giro_y, 0))
		_lastra(n, 0.105, 0.26, 0.05, 0.008, ottone,
				Vector3(-0.30, 0.60, sz * 0.307), Vector3(0, giro_y, 0))
		_lastra(n, 0.09, 0.23, 0.045, 0.008, rosso,
				Vector3(-0.30, 0.60, sz * 0.310), Vector3(0, giro_y, 0))
		_cyl(n, 0.008, 0.008, 0.055, ottone, Vector3(-0.20, 0.66, sz * 0.318))

	# I PORTELLI del cassone: lastre chiare ad angoli tondi, maniglie
	# d'ottone coricate — tre per fianco, come sui camion veri
	for i in 3:
		var x := 0.10 + float(i) * 0.26
		for sz: float in [-1.0, 1.0]:
			_lastra(n, 0.105, 0.30, 0.04, 0.016, crema,
					Vector3(x, 0.65, sz * 0.306), Vector3(0, sz * PI * 0.5, 0))
			var mn := _cyl(n, 0.007, 0.007, 0.05, ottone,
					Vector3(x, 0.55, sz * 0.318))
			mn.rotation.z = PI * 0.5

	# LA SCALA sul tetto del cassone: correnti cilindrici, pioli tondi,
	# staffe che la tengono staccata dalle spalle. Comincia DOPO la
	# cabina: una scala che taglia la nuca del tetto non è una scala.
	for sz: float in [-1.0, 1.0]:
		var corrente := _cyl(n, 0.016, 0.016, 0.72, ottone,
				Vector3(0.38, 0.965, sz * 0.115))
		corrente.rotation.z = PI * 0.5
	for i in 6:
		var piolo := _cyl(n, 0.011, 0.011, 0.21, ottone,
				Vector3(0.06 + float(i) * 0.12, 0.965, 0))
		piolo.rotation.x = PI * 0.5
	for x: float in [0.10, 0.62]:
		for sz: float in [-1.0, 1.0]:
			_cyl(n, 0.013, 0.013, 0.09, ottone, Vector3(x, 0.92, sz * 0.115))

	# LA CAMPANA d'ottone davanti, appesa al suo archetto sul cofano:
	# tornita col profilo vero di una campana, col battaglio sotto
	for sz: float in [-1.0, 1.0]:
		_cyl(n, 0.009, 0.009, 0.10, ottone, Vector3(-0.80, 0.78, sz * 0.055))
	var traversa := _cyl(n, 0.008, 0.008, 0.13, ottone, Vector3(-0.80, 0.828, 0))
	traversa.rotation.x = PI * 0.5
	BUILDER.lathe(n, [Vector2(0.052, 0.0), Vector2(0.056, 0.008),
			Vector2(0.05, 0.022), Vector2(0.04, 0.042), Vector2(0.03, 0.058),
			Vector2(0.018, 0.07), Vector2(0.006, 0.078), Vector2(0.0, 0.08)],
			ottone, Vector3(-0.80, 0.742, 0))
	_ball(n, 0.011, ottone, Vector3(-0.80, 0.742, 0))

	# I FANALI sui parafanghi: coppa d'ottone su un gambo corto, lente
	# che fa luce — dove stavano sulle autopompe d'anteguerra
	for sz: float in [-1.0, 1.0]:
		_cyl(n, 0.011, 0.011, 0.045, ottone, Vector3(-0.78, 0.44, sz * 0.345))
		_ball(n, 0.044, ottone, Vector3(-0.78, 0.49, sz * 0.345),
				Vector3(0.85, 1, 1))
		_ball(n, 0.034, _glow(Color("fff0cf"), Color("ffd98f"), 0.8),
				Vector3(-0.805, 0.49, sz * 0.345), Vector3(0.45, 0.9, 0.9))

	# IL LAMPEGGIANTE piccolo sul tetto, di quelli a cupola: acceso appena
	_cyl(n, 0.022, 0.026, 0.014, ottone, Vector3(-0.36, 1.036, 0))
	_ball(n, 0.03, _glow(POMPA_ROSSO, Color("ff6a5a"), 0.6),
			Vector3(-0.36, 1.05, 0), Vector3(1, 0.9, 1))

	# IL MULINELLO della manichetta, a poppa: due guance rosse, la canapa
	# avvolta in mezzo, il bocchello d'ottone pronto. Sta FUORI dalla
	# coda tonda, sul suo asse — mezzo sepolto sarebbe un adesivo.
	var asse := _cyl(n, 0.014, 0.014, 0.16, ottone, Vector3(0.81, 0.62, 0))
	asse.rotation.z = PI * 0.5
	for x: float in [0.77, 0.85]:
		var guancia := _cyl(n, 0.115, 0.115, 0.016, scuro, Vector3(x, 0.62, 0))
		guancia.rotation.z = PI * 0.5
	for x: float in [0.794, 0.826]:
		var spira := MeshInstance3D.new()
		var sm := TorusMesh.new()
		sm.inner_radius = 0.05
		sm.outer_radius = 0.11
		spira.mesh = sm
		spira.material_override = crema
		spira.position = Vector3(x, 0.62, 0)
		spira.rotation.z = PI * 0.5
		n.add_child(spira)
	_ball(n, 0.02, ottone, Vector3(0.865, 0.62, 0), Vector3(0.6, 1, 1))
	_cyl(n, 0.009, 0.017, 0.05, ottone, Vector3(0.81, 0.545, 0.06))
	# i fanalini di coda, mezzi affondati nel tappo della coda
	for sz: float in [-1.0, 1.0]:
		_ball(n, 0.02, _glow(Color("ff8878"), Color("ff5040"), 0.5),
				Vector3(0.75, 0.47, sz * 0.16), Vector3(0.6, 1, 1))
	return n


## IL PORTONE DELLA RIMESSA. Pezzo edge come la porta: il grande portone
## rosso a serranda, l'architrave chiaro e i due oblò da cui, di sera, si
## vede il muso dell'autopompa.
static func _portone_rimessa() -> Node3D:
	var n := Node3D.new()
	var rosso := _mat(POMPA_ROSSO, POMPA_ROSSO_SCURO, 3.0, 0.45)
	var crema := _mat(CREAM, PLASTER_SHADE, 4.0, 0.4)
	var vetro := _mat(VETRO, VETRO.darkened(0.12), 3.0, 0.3, 0.5)
	var ottone := _mat(OTTONE, OTTONE_SCURO, 5.0, 0.4)
	_box(n, Vector3(0.96, 1.9, 0.1), rosso, Vector3(0, 0.95, 0))
	for i in 5:
		_box(n, Vector3(0.98, 0.03, 0.12), crema, Vector3(0, 0.3 + float(i) * 0.33, 0))
	_box(n, Vector3(1.02, 0.16, 0.16), crema, Vector3(0, 2.0, 0))
	for x: float in [-0.24, 0.24]:
		var o := _cyl(n, 0.11, 0.11, 0.13, crema, Vector3(x, 1.5, 0))
		o.rotation.x = PI * 0.5
		var v := _cyl(n, 0.085, 0.085, 0.15, vetro, Vector3(x, 1.5, 0))
		v.rotation.x = PI * 0.5
	for x: float in [-0.18, 0.18]:
		var mn := _cyl(n, 0.02, 0.02, 0.16, ottone, Vector3(x, 0.62, 0.07))
		mn.rotation.z = PI * 0.5
	return n


## LA TORRETTA DI VEDETTA. Quattro gambe che si stringono salendo, la
## piattaforma con la ringhiera, il tetto rosso a punta e la lanterna
## appesa sotto: di sera è un punto caldo in mezzo al villaggio.
static func _torretta() -> Node3D:
	var n := Node3D.new()
	var pale := _mat(WOOD_PALE, WOOD, 3.0, 0.45)
	var wood := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	var rosso := _mat(POMPA_ROSSO, POMPA_ROSSO_SCURO, 3.0, 0.45)
	var ottone := _mat(OTTONE, OTTONE_SCURO, 5.0, 0.4)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var g := _box(n, Vector3(0.09, 1.95, 0.09), wood,
					Vector3(sx * 0.3, 0.97, sz * 0.3))
			g.rotation.z = -sx * 0.05
			g.rotation.x = sz * 0.05
	# le croci di controvento sui quattro lati
	for lato in 4:
		var a := float(lato) * PI * 0.5
		for verso: float in [-1.0, 1.0]:
			var c := _box(n, Vector3(0.8, 0.04, 0.04), wood,
					Vector3(sin(a) * 0.3, 0.9, cos(a) * 0.3))
			c.rotation.y = a
			c.rotation.z = verso * 0.62
	# la piattaforma e la ringhiera
	_box(n, Vector3(0.88, 0.07, 0.88), pale, Vector3(0, 1.97, 0))
	for lato in 4:
		var a := float(lato) * PI * 0.5
		var r := _box(n, Vector3(0.88, 0.05, 0.05), pale,
				Vector3(sin(a) * 0.42, 2.24, cos(a) * 0.42))
		r.rotation.y = a
		var m := _cyl(n, 0.03, 0.03, 0.3, pale,
				Vector3(sin(a) * 0.42, 2.12, cos(a) * 0.42))
		m.rotation.y = a
	# il tetto a punta
	var t := _cyl(n, 0.0, 0.66, 0.44, rosso, Vector3(0, 2.66, 0))
	t.rotation.y = PI * 0.25
	# la lanterna appesa sotto il tetto
	_cyl(n, 0.012, 0.012, 0.14, ottone, Vector3(0, 2.4, 0))
	_ball(n, 0.08, _glow(Color("ffe6b0"), Color("ffcf86"), 1.4), Vector3(0, 2.28, 0))
	var luce := OmniLight3D.new()
	luce.light_color = Color(1.0, 0.85, 0.62)
	luce.light_energy = 1.1
	luce.omni_range = 4.5
	luce.position = Vector3(0, 2.28, 0)
	n.add_child(luce)
	return n


## IL PALO DEI POMPIERI. Un palo vero non spunta dal pavimento: SCENDE da
## un piano di sopra. Da qui la flangia in cima — la piastra di legno coi
## quattro tiranti d'ottone, come se fosse imbullonato al solaio che un
## giorno il giocatore ci costruirà sopra davvero (è alto quanto un piano
## apposta). E chi scende deve atterrare su qualcosa: la pedana è una
## piazzola vera — gomma, piatto smaltato rosso con l'anello crema, e i
## bulloni che la tengono a terra. Sull'ultimo tirante, l'elmetto rosso
## appeso al gancio: qualcuno è appena sceso.
static func _palo_pompieri() -> Node3D:
	var n := Node3D.new()
	var ottone := _mat(OTTONE, OTTONE_SCURO, 8.0, 0.3)
	var scuro := _mat(OTTONE_SCURO, OTTONE_SCURO.darkened(0.25), 5.0, 0.4)
	var gomma := _mat(GOMMA, GOMMA.darkened(0.2), 6.0, 0.3)
	var rosso := _mat(POMPA_ROSSO, POMPA_ROSSO_SCURO, 4.0, 0.4)
	var crema := _mat(CREAM, Color("ecdcc4"), 3.5, 0.4)
	var legno := _mat(WOOD, WOOD_DARK, 4.0, 0.5)

	# ---- LA PIAZZOLA D'ATTERRAGGIO: gomma, smalto rosso, anello crema
	# dipinto, e sei bulloni sul bordo. È il punto in cui si arriva.
	_cyl(n, 0.40, 0.43, 0.05, gomma, Vector3(0, 0.025, 0))
	_cyl(n, 0.345, 0.36, 0.035, rosso, Vector3(0, 0.062, 0))
	_cyl(n, 0.30, 0.30, 0.006, crema, Vector3(0, 0.082, 0))
	_cyl(n, 0.22, 0.22, 0.006, rosso, Vector3(0, 0.084, 0))
	for b in 6:
		var ab := float(b) * TAU / 6.0 + 0.3
		_ball(n, 0.018, scuro,
				Vector3(cos(ab) * 0.375, 0.055, sin(ab) * 0.375), Vector3(1, 0.6, 1))

	# ---- IL PALO: ottone lucido, base svasata, e le ghiere di giunzione
	# doppie (un palo vero è fatto a segmenti, e le giunzioni si vedono)
	_cyl(n, 0.075, 0.10, 0.10, ottone, Vector3(0, 0.13, 0))
	_cyl(n, 0.052, 0.058, 2.0, ottone, Vector3(0, 1.08, 0))
	for gy: float in [0.72, 1.38]:
		_cyl(n, 0.068, 0.068, 0.035, scuro, Vector3(0, gy, 0))
		_cyl(n, 0.062, 0.062, 0.018, ottone, Vector3(0, gy + 0.032, 0))

	# ---- LA FLANGIA AL SOFFITTO: la piastra di legno coi quattro tiranti.
	# È lei che racconta la storia: questo palo scende da un piano di sopra.
	_box(n, Vector3(0.52, 0.045, 0.52), legno, Vector3(0, 2.13, 0))
	_box(n, Vector3(0.46, 0.02, 0.46), _mat(WOOD_PALE, WOOD, 3.0, 0.45),
			Vector3(0, 2.10, 0))
	_cyl(n, 0.085, 0.085, 0.05, scuro, Vector3(0, 2.06, 0))
	for t in 4:
		var at := float(t) * TAU / 4.0 + TAU / 8.0
		var tx := cos(at) * 0.20
		var tz := sin(at) * 0.20
		var tir := _cyl(n, 0.012, 0.012, 0.34, ottone,
				Vector3(tx * 0.62, 1.93, tz * 0.62))
		tir.rotation.z = -cos(at) * 0.42
		tir.rotation.x = sin(at) * 0.42
		_ball(n, 0.016, scuro, Vector3(tx, 2.085, tz), Vector3(1, 0.7, 1))

	# ---- L'ELMETTO APPESO. Prima stesura: appeso «al tirante» — ma il
	# gancio stava a sette centimetri dalla traiettoria vera dell'asta, e
	# l'elmetto galleggiava a mezz'aria. Un gancio si avvita dove c'è
	# LEGNO: sotto lo spigolo della piastra. Qualcuno è appena sceso, e
	# l'ha lasciato lì.
	var hx := 0.215
	var hz := 0.215
	_cyl(n, 0.006, 0.006, 0.06, scuro, Vector3(hx, 2.075, hz))
	var gancio := _cyl(n, 0.005, 0.005, 0.045, scuro, Vector3(hx, 2.042, hz))
	gancio.rotation.x = 1.1
	var elmo := Node3D.new()
	elmo.position = Vector3(hx, 1.965, hz)
	elmo.rotation.z = 0.18
	elmo.rotation.y = -0.6
	n.add_child(elmo)
	# calotta, falda che la TOCCA, cresta bassa e fregio d'ottone
	_ball(elmo, 0.082, rosso, Vector3(0, 0.012, 0), Vector3(1.0, 0.70, 1.12))
	_cyl(elmo, 0.108, 0.114, 0.016, rosso, Vector3(0, -0.030, 0.008))
	var cresta := _ball(elmo, 0.055, rosso, Vector3(0, 0.045, -0.005),
			Vector3(0.22, 0.75, 1.25))
	cresta.rotation.x = -0.1
	_ball(elmo, 0.020, ottone, Vector3(0, 0.008, -0.088), Vector3(1, 1.25, 0.45))
	return n



## LA CAMPANA DELLA CASERMA. Sul suo montante di legno, col cordino che
## pende fino a mezz'aria: è quella che chiama tutti in piazza — l'unico
## allarme di questo villaggio è «venite a vedere».
static func _campana_caserma() -> Node3D:
	var n := Node3D.new()
	var wood := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	var ottone := _mat(OTTONE, OTTONE_SCURO, 5.0, 0.4)
	var corda := _mat(WOOD_PALE, WOOD, 6.0, 0.4)
	_box(n, Vector3(0.12, 1.15, 0.12), wood, Vector3(-0.28, 0.57, 0))
	_box(n, Vector3(0.58, 0.09, 0.09), wood, Vector3(-0.02, 1.1, 0))
	var puntone := _box(n, Vector3(0.42, 0.06, 0.06), wood, Vector3(-0.15, 0.87, 0))
	puntone.rotation.z = -0.7
	# tutto quello che dondola sta sotto questo nodo
	var giogo := Node3D.new()
	giogo.name = "Campana"
	giogo.position = Vector3(0.16, 1.06, 0)
	n.add_child(giogo)
	_ball(giogo, 0.035, ottone, Vector3.ZERO)
	_cyl(giogo, 0.09, 0.155, 0.24, ottone, Vector3(0, -0.14, 0))
	_cyl(giogo, 0.17, 0.155, 0.04, ottone, Vector3(0, -0.27, 0))
	_ball(giogo, 0.03, _mat(OTTONE_SCURO, OTTONE_SCURO.darkened(0.3), 5.0, 0.4),
			Vector3(0, -0.28, 0))
	_cyl(giogo, 0.008, 0.008, 0.5, corda, Vector3(0, -0.52, 0))
	_ball(giogo, 0.028, corda, Vector3(0, -0.77, 0))
	# il respiro della corda: appena appena, come una campana ferma da poco
	var anim := Animation.new()
	anim.length = 5.0
	anim.loop_mode = Animation.LOOP_LINEAR
	var tr := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(tr, NodePath("Campana:rotation:z"))
	anim.track_insert_key(tr, 0.0, -0.02)
	anim.track_insert_key(tr, 2.5, 0.02)
	anim.track_insert_key(tr, 5.0, -0.02)
	anim.track_set_interpolation_type(tr, Animation.INTERPOLATION_CUBIC)
	var lib := AnimationLibrary.new()
	lib.add_animation("dondola", anim)
	var player := AnimationPlayer.new()
	n.add_child(player)
	player.add_animation_library("", lib)
	player.autoplay = "dondola"
	return n


## L'IDRANTE. Tozzo, rosso, col cappellino e le due bocche laterali dalla
## ghiera d'ottone. Da qui parte l'acqua per gli orti: l'unica cosa che
## questa caserma bagna davvero.
static func _idrante() -> Node3D:
	var n := Node3D.new()
	var rosso := _mat(POMPA_ROSSO, POMPA_ROSSO_SCURO, 3.5, 0.45)
	var scuro := _mat(POMPA_ROSSO_SCURO, POMPA_ROSSO_SCURO.darkened(0.2), 4.0, 0.5)
	var ottone := _mat(OTTONE, OTTONE_SCURO, 5.0, 0.4)
	_cyl(n, 0.15, 0.19, 0.1, scuro, Vector3(0, 0.05, 0))
	_cyl(n, 0.11, 0.13, 0.42, rosso, Vector3(0, 0.31, 0))
	_cyl(n, 0.14, 0.14, 0.05, scuro, Vector3(0, 0.54, 0))
	_ball(n, 0.12, rosso, Vector3(0, 0.58, 0), Vector3(1, 0.75, 1))
	_cyl(n, 0.03, 0.03, 0.06, ottone, Vector3(0, 0.69, 0))
	for z: float in [-1.0, 1.0]:
		var b := _cyl(n, 0.055, 0.06, 0.12, scuro, Vector3(0, 0.38, z * 0.14))
		b.rotation.x = PI * 0.5
		var g := _cyl(n, 0.065, 0.065, 0.03, ottone, Vector3(0, 0.38, z * 0.2))
		g.rotation.x = PI * 0.5
	return n


## LA MANICHETTA ARROTOLATA. Il cavalletto di legno, le spire avvolte
## strette e la lancia d'ottone appoggiata davanti.
static func _manichetta() -> Node3D:
	var n := Node3D.new()
	var wood := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	var tubo := _mat(CREAM.darkened(0.08), WOOD_PALE.darkened(0.15), 7.0, 0.45)
	var ottone := _mat(OTTONE, OTTONE_SCURO, 5.0, 0.4)
	# il cavalletto: le due fiancate stanno DI TAGLIO al fronte, così la
	# bobina si vede in faccia da davanti (girata di 90° si vedrebbe solo
	# lo spessore del tubo, ed era la cosa che non si capiva)
	for z: float in [-0.18, 0.18]:
		for x: float in [-0.19, 0.19]:
			var gamba := _box(n, Vector3(0.05, 0.34, 0.05), wood,
					Vector3(x, 0.17, z))
			gamba.rotation.z = -signf(x) * 0.13
		_box(n, Vector3(0.44, 0.05, 0.05), wood, Vector3(0, 0.02, z))
	var perno := _cyl(n, 0.035, 0.035, 0.44, wood, Vector3(0, 0.3, 0))
	perno.rotation.x = PI * 0.5
	# le spire: anelli concentrici che si stringono verso il perno
	for i in 4:
		var r := 0.28 - float(i) * 0.055
		var spira := TorusMesh.new()
		spira.inner_radius = r - 0.026
		spira.outer_radius = r
		var mi := MeshInstance3D.new()
		mi.mesh = spira
		mi.material_override = tubo
		mi.position = Vector3(0, 0.3, 0.0)
		mi.rotation.x = PI * 0.5
		n.add_child(mi)
	# il capo del tubo che scende, e la lancia d'ottone appoggiata
	_cyl(n, 0.026, 0.026, 0.24, tubo, Vector3(0.28, 0.16, 0))
	var lancia := _cyl(n, 0.028, 0.045, 0.2, ottone, Vector3(0.29, 0.045, -0.1))
	lancia.rotation.x = PI * 0.5
	lancia.rotation.y = 0.4
	return n


## IL CASCO E IL GIUBBETTO APPESI. Pezzo da muro: l'asse coi ganci, il
## casco d'ottone con la cresta e il giubbetto scuro dalle bande chiare —
## appesi come li lascia chi torna a casa e sa che domani li ritrova lì.
static func _casco_appeso() -> Node3D:
	var n := Node3D.new()
	var wood := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	var ottone := _mat(OTTONE, OTTONE_SCURO, 5.0, 0.4)
	var giubbe := _mat(GOMMA.lightened(0.3), GOMMA.lightened(0.1), 5.0, 0.4)
	var crema := _mat(CREAM, PLASTER_SHADE, 4.0, 0.4)
	_box(n, Vector3(0.8, 0.1, 0.05), wood, Vector3(0, 1.5, -0.03))
	for x: float in [-0.26, 0.22]:
		var gancio := _cyl(n, 0.014, 0.014, 0.1, ottone, Vector3(x, 1.45, -0.08))
		gancio.rotation.x = PI * 0.5
	# il casco: la tesa larga (è lei che lo fa leggere come un casco da
	# pompiere e non come una palla d'ottone), la calotta sopra, la cresta
	# e lo scudetto rosso davanti
	var casco := Node3D.new()
	casco.position = Vector3(-0.26, 1.28, -0.12)
	casco.rotation.x = -0.42       # appeso di sghembo: si vede la calotta
	n.add_child(casco)
	_cyl(casco, 0.155, 0.165, 0.022, ottone, Vector3(0, -0.03, 0))
	_ball(casco, 0.115, ottone, Vector3(0, 0.0, 0), Vector3(1, 0.95, 1.05))
	_box(casco, Vector3(0.04, 0.1, 0.22), ottone, Vector3(0, 0.07, 0))
	# lo scudetto rosso sul frontino
	_box(casco, Vector3(0.11, 0.1, 0.02),
			_mat(POMPA_ROSSO, POMPA_ROSSO_SCURO, 4.0, 0.4), Vector3(0, 0.0, -0.12))
	# il giubbetto: le spalle larghe, il busto che si stringe, le maniche
	# staccate e DUE bande della larghezza del busto (più larghe leggevano
	# come un codice a barre appeso al muro)
	_box(n, Vector3(0.34, 0.08, 0.1), giubbe, Vector3(0.22, 1.4, -0.08))
	_box(n, Vector3(0.28, 0.4, 0.1), giubbe, Vector3(0.22, 1.18, -0.08))
	# la falda in fondo, che si allarga: senza, il giubbetto è una lastra
	_box(n, Vector3(0.32, 0.08, 0.11), giubbe, Vector3(0.22, 1.0, -0.08))
	# la chiusura davanti, con i due bottoni d'ottone
	_box(n, Vector3(0.04, 0.42, 0.02), crema, Vector3(0.22, 1.19, -0.14))
	for y: float in [1.24, 1.06]:
		_ball(n, 0.016, ottone, Vector3(0.22, y, -0.15))
	for x: float in [0.06, 0.38]:
		var manica := _box(n, Vector3(0.08, 0.32, 0.09), giubbe,
				Vector3(x, 1.22, -0.08))
		manica.rotation.z = (0.12 if x < 0.22 else -0.12)
	for y: float in [1.12, 1.3]:
		_box(n, Vector3(0.29, 0.035, 0.11), crema, Vector3(0.22, y, -0.08))
	# il colletto chiaro
	_box(n, Vector3(0.16, 0.05, 0.11), crema, Vector3(0.22, 1.44, -0.08))
	return n


## GLI STIVALI IN FILA. Tre paia col risvolto rosso, allineati sulla
## soglia: il pezzo più piccolo della caserma e quello che la racconta
## meglio — nessuno li sta indossando, e va benissimo così.
static func _stivali() -> Node3D:
	var n := Node3D.new()
	var gomma := _mat(GOMMA, GOMMA.darkened(0.25), 6.0, 0.35)
	var rosso := _mat(POMPA_ROSSO, POMPA_ROSSO_SCURO, 4.0, 0.45)
	for i in 3:
		var x := -0.3 + float(i) * 0.3
		for z: float in [-0.07, 0.07]:
			_cyl(n, 0.055, 0.06, 0.2, gomma, Vector3(x, 0.1, z))
			_cyl(n, 0.062, 0.062, 0.035, rosso, Vector3(x, 0.2, z))
			_box(n, Vector3(0.1, 0.05, 0.17), gomma, Vector3(x, 0.025, z - 0.06))
	return n


## LA SCALA A PIOLI. Appoggiata al muro con la sua inclinazione, correnti
## di legno e pioli d'ottone.
static func _scala_pioli() -> Node3D:
	var n := Node3D.new()
	var wood := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	var ottone := _mat(OTTONE, OTTONE_SCURO, 5.0, 0.4)
	var scala := Node3D.new()
	scala.rotation.x = 0.22
	scala.position = Vector3(0, 0, -0.16)
	n.add_child(scala)
	for x: float in [-0.16, 0.16]:
		_box(scala, Vector3(0.05, 1.9, 0.05), wood, Vector3(x, 0.95, 0))
	for i in 7:
		_box(scala, Vector3(0.37, 0.035, 0.035), ottone,
				Vector3(0, 0.25 + float(i) * 0.24, 0))
	return n


## L'INSEGNA DELLA CASERMA. Non più un cartello inchiodato a due pali: un
## portale coi montanti torniti su basette di pietra, la traversa coi
## puntoni, il TETTINO di terracotta che ripara la tavola (lo stesso rosso
## del tetto della caserma: da lontano si capisce di che famiglia è), e la
## tavola APPESA alle astine d'ottone, che ondeggia appena nel vento come
## le insegne del bar e della guardia. Sopra, l'araldica dei pompieri
## rifatta perché si LEGGA: scudo rosso con la punta e il bordo d'ottone,
## l'elmetto con falda e crestina, le manichette incrociate con gli UGELLI
## alle punte — prima erano due bastoni su una macchia rossa. E al
## montante, il secchiello appeso: il gesto della caserma.
static func _insegna_caserma() -> Node3D:
	var n := Node3D.new()
	var wood := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	var wood_scuro := _mat(WOOD_DARK, Color("8a6540"), 3.5, 0.5)
	var crema := _mat(CREAM, PLASTER_SHADE, 4.0, 0.4)
	var rosso := _mat(POMPA_ROSSO, POMPA_ROSSO_SCURO, 3.5, 0.45)
	var ottone := _mat(OTTONE, OTTONE_SCURO, 5.0, 0.4)
	var pietra := _mat(STONE, STONE_DARK, 4.0, 0.5)
	var tetto := _mat(TERRACOTTA, Color("c07a58"), 3.5, 0.5)

	# I MONTANTI torniti: basetta di pietra, fusto rastremato, collarino
	for x: float in [-0.38, 0.38]:
		_cyl(n, 0.075, 0.09, 0.07, pietra, Vector3(x, 0.035, -0.02))
		_cyl(n, 0.042, 0.052, 1.62, wood, Vector3(x, 0.88, -0.02))
		_cyl(n, 0.058, 0.058, 0.035, wood_scuro, Vector3(x, 1.7, -0.02))
	# LA TRAVERSA coi due puntoni diagonali: il telaio si vede lavorare
	_box(n, Vector3(0.98, 0.07, 0.07), wood, Vector3(0, 1.76, -0.02))
	for px: float in [-1.0, 1.0]:
		var puntone := _box(n, Vector3(0.05, 0.28, 0.05), wood,
				Vector3(px * 0.28, 1.65, -0.02))
		puntone.rotation.z = px * 0.7
	# IL TETTINO a due falde di terracotta col colmo: ripara la tavola
	# e dice da lontano che questa è roba della caserma
	for fz: float in [-1.0, 1.0]:
		var falda := _box(n, Vector3(1.06, 0.035, 0.17), tetto,
				Vector3(0, 1.85, -0.02 + fz * 0.065))
		falda.rotation.x = fz * -0.5
	_box(n, Vector3(1.08, 0.035, 0.06), wood_scuro, Vector3(0, 1.9, -0.02))

	# LA TAVOLA APPESA: un nodo a sé col pivot sulla traversa, come le
	# insegne del bar e della guardia — e ondeggia appena (vedi in fondo)
	var appesa := Node3D.new()
	appesa.name = "Insegna"
	appesa.position = Vector3(0, 1.76, -0.02)
	n.add_child(appesa)
	for ax: float in [-0.3, 0.3]:
		_cyl(appesa, 0.008, 0.008, 0.15, ottone, Vector3(ax, -0.1, 0))
	# la cornice con la battuta: due piani, non un box solo
	_box(appesa, Vector3(0.84, 0.5, 0.05), wood_scuro, Vector3(0, -0.42, 0))
	_box(appesa, Vector3(0.76, 0.42, 0.026), crema, Vector3(0, -0.42, -0.02))
	# le borchie d'ottone agli angoli della cornice
	for bx: float in [-1.0, 1.0]:
		for by: float in [-1.0, 1.0]:
			_ball(appesa, 0.014, ottone,
					Vector3(bx * 0.36, -0.42 + by * 0.19, -0.028), Vector3(1, 1, 0.5))

	# L'ARALDICA (tutta sulla tavola appesa, così dondola con lei).
	# Le manichette incrociate, con l'ugello rastremato alle quattro punte
	for s: float in [-1.0, 1.0]:
		var manica := _cyl(appesa, 0.015, 0.015, 0.36, _mat(OTTONE_SCURO, Color("8a6520"), 4.0, 0.4),
				Vector3(0, -0.42, -0.036))
		manica.rotation.z = s * 0.75
		for e: float in [-1.0, 1.0]:
			# la punta sta sull'ASSE della sua manichetta (x = −s·e·sin θ),
			# e il cono si capovolge sull'estremità bassa — o l'ugello
			# finisce sulla manichetta sbagliata, storto di novanta gradi
			var ugello := _cyl(appesa, 0.008, 0.021, 0.07, ottone,
					Vector3(-s * e * sin(0.75) * 0.21, -0.42 + e * cos(0.75) * 0.21, -0.036))
			ugello.rotation.z = s * 0.75 + (0.0 if e > 0.0 else PI)
	# lo scudo rosso con la punta, bordato d'ottone. Ogni lastra sul SUO
	# piano (quadrato e rombo sfalsati di qualche millimetro): due facce
	# complanari si tagliano in z-fighting, e dentro il campo rosso
	# affiorava un triangolo fantasma
	_box(appesa, Vector3(0.22, 0.21, 0.012), ottone, Vector3(0, -0.4, -0.039))
	var bordo_punta := _box(appesa, Vector3(0.156, 0.156, 0.012), ottone,
			Vector3(0, -0.5, -0.037))
	bordo_punta.rotation.z = PI * 0.25
	_box(appesa, Vector3(0.19, 0.19, 0.014), rosso, Vector3(0, -0.405, -0.048))
	var punta_scudo := _box(appesa, Vector3(0.134, 0.134, 0.014), rosso,
			Vector3(0, -0.49, -0.0455))
	punta_scudo.rotation.z = PI * 0.25
	# l'elmetto d'ottone sopra lo scudo: falda, calotta e crestina
	_ball(appesa, 0.09, ottone, Vector3(0, -0.295, -0.05), Vector3(1, 0.22, 0.5))
	_ball(appesa, 0.065, ottone, Vector3(0, -0.275, -0.05), Vector3(1, 0.8, 0.5))
	_box(appesa, Vector3(0.014, 0.075, 0.024), ottone, Vector3(0, -0.235, -0.05))

	# IL SECCHIELLO appeso al montante: gancio, secchio rosso col bordo
	# scuro e il manico d'ottone — l'eco dei secchi della caserma
	_box(n, Vector3(0.028, 0.02, 0.09), wood_scuro, Vector3(0.38, 0.98, -0.06))
	_cyl(n, 0.052, 0.04, 0.085, rosso, Vector3(0.38, 0.885, -0.1))
	_cyl(n, 0.054, 0.054, 0.012, _mat(POMPA_ROSSO_SCURO, POMPA_ROSSO_SCURO.darkened(0.2), 5.0, 0.5),
			Vector3(0.38, 0.93, -0.1))
	var manico_s := TorusMesh.new()
	manico_s.inner_radius = 0.042
	manico_s.outer_radius = 0.052
	var msi := MeshInstance3D.new()
	msi.mesh = manico_s
	msi.material_override = ottone
	msi.position = Vector3(0.38, 0.955, -0.085)
	msi.rotation.y = PI * 0.5
	msi.scale = Vector3(1, 1, 0.6)
	n.add_child(msi)

	# l'ondeggio: piccolo, lento, cubico — un'insegna appesa e immobile
	# per sempre è un'insegna incollata
	var oscilla := Animation.new()
	oscilla.length = 6.3
	oscilla.loop_mode = Animation.LOOP_LINEAR
	var tr := oscilla.add_track(Animation.TYPE_VALUE)
	oscilla.track_set_path(tr, NodePath("Insegna:rotation:x"))
	oscilla.track_insert_key(tr, 0.0, -0.015)
	oscilla.track_insert_key(tr, 3.15, 0.02)
	oscilla.track_insert_key(tr, 6.3, -0.015)
	oscilla.track_set_interpolation_type(tr, Animation.INTERPOLATION_CUBIC)
	var lib := AnimationLibrary.new()
	lib.add_animation("dondola", oscilla)
	var player := AnimationPlayer.new()
	n.add_child(player)
	player.add_animation_library("", lib)
	player.autoplay = "dondola"
	return n


## I SECCHI ROSSI. Tre impilati e uno di fianco col manico d'ottone in
## vista: la cosa più semplice della caserma, e la più vera.
static func _secchi() -> Node3D:
	var n := Node3D.new()
	var rosso := _mat(POMPA_ROSSO, POMPA_ROSSO_SCURO, 4.0, 0.45)
	var scuro := _mat(POMPA_ROSSO_SCURO, POMPA_ROSSO_SCURO.darkened(0.2), 5.0, 0.5)
	var ottone := _mat(OTTONE, OTTONE_SCURO, 5.0, 0.4)
	for i in 3:
		var y := 0.1 + float(i) * 0.13
		_cyl(n, 0.135, 0.1, 0.2, rosso, Vector3(-0.14, y, 0))
		_cyl(n, 0.14, 0.14, 0.02, scuro, Vector3(-0.14, y + 0.1, 0))
	_cyl(n, 0.135, 0.1, 0.2, rosso, Vector3(0.2, 0.1, -0.08))
	_cyl(n, 0.14, 0.14, 0.02, scuro, Vector3(0.2, 0.2, -0.08))
	var manico := TorusMesh.new()
	manico.inner_radius = 0.125
	manico.outer_radius = 0.14
	var mi := MeshInstance3D.new()
	mi.mesh = manico
	mi.material_override = ottone
	mi.position = Vector3(0.2, 0.24, -0.08)
	mi.rotation.x = PI * 0.5
	mi.scale = Vector3(1, 1, 0.55)
	n.add_child(mi)
	return n


## IL FARO DELLA CASERMA. Non una sirena che urla: una lanterna che GIRA
## piano sul suo palo, e la sera fa il giro del cortile come un piccolo
## faro di terra. Il giro glielo dà un AnimationPlayer in loop — i pezzi
## piazzati sono nodi nudi, come la mongolfiera.
static func _faro_caserma() -> Node3D:
	var n := Node3D.new()
	var wood := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	var scuro := _mat(POMPA_ROSSO_SCURO, POMPA_ROSSO_SCURO.darkened(0.25), 5.0, 0.45)
	var ottone := _mat(OTTONE, OTTONE_SCURO, 5.0, 0.4)
	_cyl(n, 0.06, 0.09, 1.2, wood, Vector3(0, 0.6, 0))
	_cyl(n, 0.16, 0.16, 0.04, scuro, Vector3(0, 1.22, 0))
	# la testa che gira
	var testa := Node3D.new()
	testa.name = "Girella"
	testa.position = Vector3(0, 1.38, 0)
	n.add_child(testa)
	# il vetro rosso: acceso ma non slavato — con l'emissione alta il rosso
	# sbianca e il faro sembra una lampadina qualunque
	_cyl(testa, 0.13, 0.13, 0.22, _glow(POMPA_ROSSO, POMPA_ROSSO_SCURO, 0.45),
			Vector3.ZERO)
	for y: float in [-0.12, 0.12]:
		_cyl(testa, 0.15, 0.15, 0.035, ottone, Vector3(0, y, 0))
	# la gabbia d'ottone attorno al vetro
	for i in 4:
		var a := float(i) * PI * 0.5 + PI * 0.25
		_cyl(testa, 0.016, 0.016, 0.24, ottone,
				Vector3(sin(a) * 0.13, 0, cos(a) * 0.13))
	# LA LENTE STA DENTRO IL TAMBURO. Larga 0.20 in z e messa a x 0.11, in un
	# cilindro di raggio 0.13, sporgeva da tutte e due le parti: un
	# rettangolo bianco che usciva dalla lanterna invece di accendersi
	# dentro. A x 0.10 il vetro è largo 2·√(0.13²−0.10²) = 0.166.
	_box(testa, Vector3(0.05, 0.15, 0.15), _glow(CREAM, Color("ffd9a8"), 1.6),
			Vector3(0.10, 0, 0))
	var fascio := SpotLight3D.new()
	fascio.light_color = Color(1.0, 0.74, 0.58)
	fascio.light_energy = 1.6
	fascio.spot_range = 6.5
	fascio.spot_angle = 26.0
	fascio.shadow_enabled = false
	fascio.position = Vector3(0.14, 0, 0)
	fascio.rotation = Vector3(0, -PI * 0.5, 0)
	testa.add_child(fascio)
	# il giro: lento, continuo, senza scatti al riavvolgimento
	var anim := Animation.new()
	anim.length = 9.0
	anim.loop_mode = Animation.LOOP_LINEAR
	var tr := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(tr, NodePath("Girella:rotation:y"))
	anim.track_insert_key(tr, 0.0, 0.0)
	anim.track_insert_key(tr, 4.5, PI)
	anim.track_insert_key(tr, 9.0, TAU)
	anim.track_set_interpolation_type(tr, Animation.INTERPOLATION_LINEAR)
	var lib := AnimationLibrary.new()
	lib.add_animation("gira", anim)
	var player := AnimationPlayer.new()
	n.add_child(player)
	player.add_animation_library("", lib)
	player.autoplay = "gira"
	return n


## LA CUCCIA DELLA CASERMA. Nessun cane, per ora: la cuccia rossa col
## tetto a falde e la ciotola d'ottone davanti — chi passa ci mette il
## naso dentro, e un giorno magari ci resta qualcuno.
static func _cuccia_caserma() -> Node3D:
	var n := Node3D.new()
	var rosso := _mat(POMPA_ROSSO, POMPA_ROSSO_SCURO, 3.5, 0.45)
	var crema := _mat(CREAM, PLASTER_SHADE, 4.0, 0.4)
	var wood := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	var ottone := _mat(OTTONE, OTTONE_SCURO, 5.0, 0.4)
	# le misure del corpo in chiaro: da qui si ricava dove sta la ciotola
	var corpo := Vector3(0.6, 0.42, 0.54)
	_box(n, corpo, crema, Vector3(0, corpo.y * 0.5, 0))
	# l'ingresso: un arco, non un buco quadrato
	var buio := _mat(GOMMA.lightened(0.05), GOMMA, 5.0, 0.3)
	_box(n, Vector3(0.24, 0.22, 0.06), buio, Vector3(0, 0.11, -0.27))
	var arco := _cyl(n, 0.12, 0.12, 0.06, buio, Vector3(0, 0.22, -0.27))
	arco.rotation.x = PI * 0.5
	# il tetto a due falde: la falda di sinistra scende verso sinistra e
	# quella di destra verso destra, o invece di una punta viene una V
	for s: float in [-1.0, 1.0]:
		var f := _box(n, Vector3(0.48, 0.05, 0.6), rosso, Vector3(s * 0.18, 0.5, 0))
		f.rotation.z = -s * 0.51
	_box(n, Vector3(0.09, 0.06, 0.62), wood, Vector3(0, 0.6, 0))
	# LA CIOTOLA STA DAVANTI, NON DENTRO. Era piantata nello spigolo del corpo
	# (centro x=0.3, z=-0.3, bordo di raggio 0.09) contro un muro che arriva a
	# x=0.30 e z=-0.27: un morso di 8,5 cm dentro l'intonaco — l'angolo retto
	# che di profilo si vedeva in una ciotola tonda. Ora la posa si RICAVA dal
	# corpo: davanti alla facciata, staccata del proprio raggio più un dito
	# d'aria, così non ci rientra più nemmeno se la cuccia cambia misura.
	var bordo := 0.09
	_cyl(n, bordo, 0.07, 0.05, ottone, Vector3(0.3, 0.025, -corpo.z * 0.5 - bordo - 0.02))
	return n


## IL PENNONE COL GAGLIARDETTO. Il palo chiaro e la bandierina rossa
## della caserma, che ondeggia con lo stesso vento del bucato steso.
static func _pennone_caserma() -> Node3D:
	var n := Node3D.new()
	var crema := _mat(CREAM, PLASTER_SHADE, 4.0, 0.4)
	var ottone := _mat(OTTONE, OTTONE_SCURO, 5.0, 0.4)
	var stoffa := _mat(POMPA_ROSSO, POMPA_ROSSO_SCURO, 2.5, 0.4)
	stoffa.set_shader_parameter("wind_strength", 0.02)
	stoffa.set_shader_parameter("wind_speed", 2.4)
	_cyl(n, 0.035, 0.05, 2.0, crema, Vector3(0, 1.0, 0))
	_ball(n, 0.05, ottone, Vector3(0, 2.02, 0))
	# il gagliardetto attaccato al palo, con la coda a due punte
	var f := _box(n, Vector3(0.02, 0.32, 0.4), stoffa, Vector3(0.02, 1.72, -0.24))
	f.rotation.y = -0.1
	for y: float in [1.6, 1.84]:
		var punta := _box(n, Vector3(0.02, 0.1, 0.14), stoffa,
				Vector3(0.03, y, -0.49))
		punta.rotation.y = -0.1
	# i due anelli d'ottone che la tengono su
	for y: float in [1.58, 1.86]:
		var anello := _cyl(n, 0.055, 0.055, 0.014, ottone, Vector3(0, y, 0))
		anello.rotation.x = PI * 0.5
	return n


# ============================================================ L'ANFITEATRO
# Il posto dove l'ARTISTA finalmente lavora.
#
# Il sogno «artista» esisteva da sempre nel genoma e non aveva NESSUN
# mestiere che lo realizzasse: chi lo sognava non prendeva mai il bonus
# del lavoro giusto ne' il x1.5 della resa — sognava una cosa che nel
# villaggio non si poteva fare. L'anfiteatro e' la sua bottega.
#
# Non e' UN pezzo: sono TRE, e si costruisce mettendoli insieme —
# il PALCO col suo fondale a conchiglia, le GRADINATE da disporre in
# curva davanti, e il PIANOFORTE. Un anfiteatro grande e' grande perche'
# l'hai fatto grande tu, non perche' un builder ha deciso quanto.


## L'ESTRUSIONE DI UN PROFILO: il pezzo mancante del catalogo. Con soli
## box e cilindri un pianoforte a coda non si puo' fare — la sua sagoma
## e' una curva, ed e' quella a renderlo riconoscibile in una silhouette.
## `punti` e' il contorno chiuso sul piano XZ, in senso antiorario.
static func _prisma(parent: Node3D, punti: Array, y: float, altezza: float,
		mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := punti.size()
	# il coperchio e il fondo, a ventaglio dal baricentro
	var centro := Vector2.ZERO
	for p in punti:
		centro += p as Vector2
	centro /= float(n)
	for lato in 2:
		var yy := y + altezza if lato == 0 else y
		var su := 1.0 if lato == 0 else -1.0
		for i in n:
			var a: Vector2 = punti[i]
			var b: Vector2 = punti[(i + 1) % n]
			var terna := [Vector3(centro.x, yy, centro.y),
					Vector3(a.x, yy, a.y), Vector3(b.x, yy, b.y)]
			if lato == 1:
				terna = [terna[0], terna[2], terna[1]]
			for v in terna:
				st.set_normal(Vector3(0, su, 0))
				st.add_vertex(v)
	# la parete laterale
	for i in n:
		var a2: Vector2 = punti[i]
		var b2: Vector2 = punti[(i + 1) % n]
		var nrm := Vector3(b2.y - a2.y, 0, a2.x - b2.x).normalized()
		var quad := [Vector3(a2.x, y, a2.y), Vector3(b2.x, y, b2.y),
				Vector3(b2.x, y + altezza, b2.y), Vector3(a2.x, y + altezza, a2.y)]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_normal(nrm)
			st.add_vertex(quad[k])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	parent.add_child(mi)
	return mi


## Il contorno di un pianoforte a CODA, in senso antiorario. Il lato
## dritto e' la tastiera; il fianco destro e' la curva. Le proporzioni
## sono quelle vere, rimpicciolite su un chibi (0.70 di altezza).
static func _profilo_coda(lung: float, larg: float) -> Array:
	var out: Array = []
	out.append(Vector2(-larg * 0.5, 0.0))          # spigolo tastiera sinistro
	out.append(Vector2(larg * 0.5, 0.0))           # spigolo tastiera destro
	# il fianco destro e' quasi dritto, poi rientra
	out.append(Vector2(larg * 0.5, -lung * 0.42))
	# LA CURVA: la coda, in sette campioni
	for i in range(1, 8):
		var t := float(i) / 7.0
		var ang := t * PI * 0.62
		out.append(Vector2(larg * 0.5 - sin(ang) * larg * 0.62,
				-lung * 0.42 - cos(ang * 0.62) * lung * 0.30 - t * lung * 0.24))
	out.append(Vector2(-larg * 0.5, -lung * 0.72))  # il fianco sinistro, dritto
	return out


# IL PIANOFORTE A CODA. Il pezzo forte dell'anfiteatro, e il piu' difficile:
# un pianoforte si riconosce da tre cose, e mancandone una diventa un mobile.
#   1. LA SAGOMA a coda — una curva, non una scatola: la fa `_prisma` su un
#      profilo vero;
#   2. IL COPERCHIO APERTO col suo asta di sostegno, che e' cio' che dice
#      «sta suonando» anche da lontano e in silhouette;
#   3. I TASTI VERI — bianchi e neri, nel loro ordine (2 e 3 alternati).
#      Una tastiera a righe uniformi si legge come una tastiera di computer.
# Piu' la cordiera dorata che si vede sotto il coperchio, le tre gambe
# tornite, la lira dei pedali e il leggio.
static func _pianoforte() -> Node3D:
	var n := Node3D.new()
	var lacca := _mat(Color("2f2a2e"), Color("1d1a1d"), 12.0, 0.22)
	var lacca_int := _mat(Color("4a3f45"), Color("332b30"), 10.0, 0.25)
	var oro := _mat(Color("d9b978"), Color("b8965a"), 8.0, 0.32)
	var avorio := _mat(Color("fdf6e8"), Color("ece2cf"), 14.0, 0.2)
	var ebano := _mat(Color("241f22"), Color("151214"), 14.0, 0.2)
	var feltro := _mat(Color("b4485e"), Color("943a4d"), 6.0, 0.5)

	var lung := 0.92
	var larg := 0.62
	var h := 0.20          # spessore della cassa
	var y := 0.30          # quota del piano della tastiera
	var prof := _profilo_coda(lung, larg)

	# LA CASSA e il suo fondo piu' scuro
	_prisma(n, prof, y - h, h, lacca)
	var interno: Array = []
	for p in prof:
		interno.append((p as Vector2) * 0.90)
	_prisma(n, interno, y - h + 0.012, h - 0.03, lacca_int)

	# LA CORDIERA: la piastra dorata e le corde, che si vedono dentro
	_prisma(n, interno, y - 0.035, 0.012, oro)
	for i in 14:
		var t := float(i) / 13.0
		var x := -larg * 0.42 + t * larg * 0.84
		var l := 0.62 - absf(t - 0.15) * 0.34
		var corda := _box(n, Vector3(0.005, 0.004, l), oro,
				Vector3(x, y - 0.028, -0.10 - l * 0.5 + 0.10))
		corda.rotation.y = t * 0.10
	# i due ponticelli
	for sz: float in [-0.22, -0.46]:
		_box(n, Vector3(larg * 0.80, 0.016, 0.022), oro, Vector3(0, y - 0.022, sz))

	# LA TASTIERA. Sette ottave non ci stanno su un chibi: undici tasti
	# bianchi bastano a leggerla, purche' i neri stiano al loro posto —
	# a coppie e a terne, come nella realta'.
	var nb := 11
	var passo := (larg * 0.86) / float(nb)
	var x0 := -larg * 0.43 + passo * 0.5
	for i in nb:
		var bianco := _box(n, Vector3(passo * 0.88, 0.018, 0.115), avorio,
				Vector3(x0 + float(i) * passo, y + 0.009, 0.062))
		bianco.name = "Tasto%d" % i
	# i neri: nel giro di 7 tasti bianchi stanno dopo il 1°,2° e 4°,5°,6°
	var neri := [0, 1, 3, 4, 5, 7, 8, 10]
	for i in neri:
		if i >= nb - 1:
			continue
		var nero := _box(n, Vector3(passo * 0.52, 0.022, 0.072), ebano,
				Vector3(x0 + (float(i) + 0.5) * passo, y + 0.020, 0.038))
		nero.name = "TastoNero%d" % i
	# il frontalino e il feltro rosso che orla la tastiera
	_box(n, Vector3(larg, 0.05, 0.022), lacca, Vector3(0, y - 0.012, 0.125))
	_box(n, Vector3(larg * 0.88, 0.006, 0.010), feltro, Vector3(0, y + 0.020, 0.004))

	# IL COPERCHIO, APERTO, e la sua asta: e' questo che dice «suona»
	var cop := Node3D.new()
	cop.position = Vector3(-larg * 0.5, y, 0.0)
	cop.rotation.z = 0.62
	n.add_child(cop)
	var sopra: Array = []
	for p in prof:
		sopra.append((p as Vector2) - Vector2(-larg * 0.5, 0.0))
	_prisma(cop, sopra, 0.0, 0.022, lacca)
	_prisma(cop, sopra, -0.006, 0.006, lacca_int)
	# L'ASTA DI SOSTEGNO SI FERMA SOTTO IL COPERCHIO, e il punto si CALCOLA.
	# Lunga 0.40 a occhio lo BUCAVA: la punta usciva quindici centimetri
	# sopra la laccatura, in tutte e tre le viste, come un chiodo piantato
	# al contrario. Il coperchio è il piano che parte dalla cerniera
	# (−larg/2, y) inclinato di 0.62; l'asta parte dalla cassa, sale a 0.42,
	# e finisce esattamente dove incontra quel piano.
	var a_piede := Vector3(-larg * 0.10, y + 0.012, -lung * 0.30)
	var a_dir := Vector3(sin(0.42), cos(0.42), 0.0)
	var t_cop: float = ((a_piede.x + larg * 0.5) * sin(0.62) - 0.012 * cos(0.62)) \
			/ (a_dir.y * cos(0.62) - a_dir.x * sin(0.62))
	var asta := _cyl(n, 0.010, 0.012, t_cop, lacca, a_piede + a_dir * (t_cop * 0.5))
	asta.rotation.z = -0.42

	# LE TRE GAMBE tornite, con la loro rotella
	for p3: Vector2 in [Vector2(-larg * 0.40, 0.02), Vector2(larg * 0.40, 0.02),
			Vector2(0.0, -lung * 0.60)]:
		_cyl(n, 0.030, 0.040, y - h, lacca, Vector3(p3.x, (y - h) * 0.5, p3.y))
		_cyl(n, 0.044, 0.044, 0.022, oro, Vector3(p3.x, 0.011, p3.y))

	# LA LIRA DEI PEDALI
	_box(n, Vector3(0.05, 0.11, 0.035), lacca, Vector3(0, 0.075, -0.02))
	_box(n, Vector3(0.16, 0.016, 0.09), lacca, Vector3(0, 0.030, -0.04))
	for sx: float in [-0.045, 0.0, 0.045]:
		var ped := _box(n, Vector3(0.026, 0.008, 0.075), oro, Vector3(sx, 0.036, -0.055))
		ped.rotation.x = -0.12

	# IL LEGGIO, appena inclinato
	var leg := _box(n, Vector3(larg * 0.62, 0.10, 0.010), lacca,
			Vector3(0, y + 0.10, -0.055))
	leg.rotation.x = -0.28
	for sx2: float in [-1.0, 1.0]:
		_cyl(n, 0.006, 0.006, 0.07, lacca, Vector3(sx2 * larg * 0.24, y + 0.05, -0.04))

	# LA PANCHETTA, davanti: senza, il pianoforte sembra un oggetto da
	# guardare e non uno da suonare
	var panca := Node3D.new()
	panca.name = "Panchetta"
	panca.position = Vector3(0, 0, 0.42)
	# ci si siede SULLA TAVOLA, non 52 cm sopra l'origine del pezzo (che e'
	# la misura della Panchina, l'unico mobile per cui `r_bench` era nato)
	# 0.315 e non 0.30: 0.30 e' il CENTRO della scatola del feltro, e il
	# mezzo spessore (0.015) fa la differenza fra sedersi sopra e affondarci
	panca.set_meta("seduta", Vector3(0, 0.315, 0))
	n.add_child(panca)
	_box(panca, Vector3(0.38, 0.035, 0.17), lacca, Vector3(0, 0.28, 0))
	_box(panca, Vector3(0.34, 0.030, 0.14), feltro, Vector3(0, 0.30, 0))
	for px: float in [-0.15, 0.15]:
		for pz: float in [-0.06, 0.06]:
			_cyl(panca, 0.014, 0.017, 0.28, lacca, Vector3(px, 0.14, pz))
	return n


# IL TAVOLATO DEL PALCO. È un PAVIMENTO (livello 0), non un mobile, e
# questa non è pignoleria: sul livello degli oggetti ci sta una cosa sola
# per cella, quindi un palco-mobile non avrebbe mai potuto avere sopra il
# pianoforte. Da pavimento, invece, se ne posano quanti se ne vuole — e
# l'anfiteatro diventa GRANDE perché l'hai fatto grande tu.
#
# Un tavolato si riconosce da quattro cose, e qui ci sono tutte:
#  - le assi hanno larghezze DIVERSE e giunti di testa sfalsati (un
#    tavolato di assi tutte intere e identiche sembra linoleum);
#  - le FUGHE sono vere: passanti, e sotto c'è il buio e i travetti,
#    non una riga dipinta;
#  - i chiodi stanno DOVE servono (in coppia sui giunti, alle teste),
#    non a griglia da foglio a quadretti;
#  - ogni asse ha il suo micro-ribasso (±2 mm) e ogni tanto un NODO:
#    il legno vero non è mai in bolla.
static func _palco() -> Node3D:
	var n := Node3D.new()
	var asse := _mat(WOOD, WOOD_DARK, 3.0, 0.5)
	var asse2 := _mat(Color("bb8f62"), Color("9c7448"), 3.5, 0.5)
	var asse3 := _mat(Color("cba274"), Color("a9834f"), 3.2, 0.5)
	var trave := _mat(WOOD_DARK, Color("8a6440"), 4.0, 0.5)
	var ferro := _mat(Color("6b625c"), Color("4e4742"), 5.0, 0.3)
	var mats := [asse, asse2, asse3]

	# sotto: il buio della fuga è VERO — un fondo scuro e tre travetti
	# lungo Z che portano le assi (spuntano nelle fughe e sul bordo,
	# e staccano il tavolato da terra di due centimetri)
	var fondo := _mat(Color("54463a"), Color("3f342b"), 4.0, 0.3)
	_box(n, Vector3(0.99, 0.006, 0.99), fondo, Vector3(0, 0.009, 0))
	for tx2: float in [-0.35, 0.0, 0.35]:
		var trav := _prisma(n, _rrect_xz(0.07, 0.96, 0.02), 0.0, 0.018, trave)
		trav.position.x = tx2

	# ogni riga: [larghezza, giunto_x (0 = asse intera), ribasso, mat].
	# La QUOTA DEL PIANO resta 0.05 (i ribassi vanno solo in giù): chi
	# sta sul palco sta alla quota di sempre.
	var righe := [
		[0.113, 0.16, 0.0, 0], [0.096, 0.0, -0.002, 1],
		[0.108, -0.21, -0.001, 0], [0.121, 0.0, 0.0, 2],
		[0.099, 0.05, -0.0025, 1], [0.111, -0.30, -0.001, 0],
		[0.093, 0.0, -0.0015, 2], [0.115, 0.24, 0.0, 0],
		[0.099, 0.0, -0.002, 1],
	]
	var centri: Array = []
	var zc := -0.5
	for r in righe.size():
		var w := float(righe[r][0])
		var xg := float(righe[r][1])
		var alto := 0.05 + float(righe[r][2])
		var mat: Material = mats[int(righe[r][3])]
		var z := zc + w * 0.5
		zc += w + 0.0056
		centri.append([z, alto])
		var tratti: Array = [[-0.5, 0.5]] if xg == 0.0 else \
				[[-0.5, xg - 0.003], [xg + 0.003, 0.5]]
		for tr in tratti:
			var x0 := float(tr[0])
			var x1 := float(tr[1])
			var tavola := _prisma(n, _rrect_xz(x1 - x0, w, 0.012), 0.018,
					alto - 0.018, mat)
			tavola.position = Vector3((x0 + x1) * 0.5, 0.0, z)
		# le teste dei chiodi: in coppia ai due lati del giunto; sulle
		# assi intere, alle estremità di una fila sì e una no
		var teste: Array = []
		if xg != 0.0:
			teste = [xg - 0.028, xg + 0.028]
		elif r % 2 == 0:
			teste = [-0.462, 0.462]
		for tx in teste:
			for dz2: float in [-1.0, 1.0]:
				_cyl(n, 0.0052, 0.0052, 0.003, ferro,
						Vector3(float(tx), alto + 0.0012,
						z + dz2 * (w * 0.5 - 0.022)))

	# tre nodi del legno, mai sulla stessa asse e mai in fila
	for k in [[0.21, 2, 0.0075], [-0.33, 5, 0.007], [0.08, 7, 0.0065]]:
		var riga: Array = centri[int(k[1])]
		_ball(n, float(k[2]), trave,
				Vector3(float(k[0]), float(riga[1]) + 0.0006, float(riga[0])),
				Vector3(1.0, 0.14, 0.75))
	return n


# IL FONDALE A CONCHIGLIA: la volta che in un anfiteatro vero spinge il
# suono verso le gradinate, e che qui serve a dire «si sta guardando
# qualcosa» anche quando il palco è vuoto. Si posa DIETRO al tavolato.
static func _fondale() -> Node3D:
	var n := Node3D.new()
	var trave := _mat(WOOD_DARK, Color("8a6440"), 4.0, 0.5)
	var intonaco := _mat(Color("efe3cd"), Color("dccdb2"), 2.5, 0.45)
	var oro := _mat(Color("d9b978"), Color("b8965a"), 8.0, 0.32)
	var h := 0.05          # poggia sul tavolato, che è alto 5 cm

	# LA CONCHIGLIA. E' un QUARTO DI CUPOLA, e va parametrizzata come tale:
	# ogni concio sta in (angolo attorno, salita lungo l'arco) e il raggio
	# orizzontale si stringe salendo — se non si stringe, la volta non
	# chiude e si legge come una scala a chiocciola (e' successo).
	#
	# La rotazione non e' decorativa: il +Z locale del concio deve puntare
	# DENTRO la volta. Con l'ordine YXZ di Godot esce y = -angolo, x = +salita.
	# Col segno sbagliato i conci si aprono a ventaglio e la superficie
	# scompare.
	var raggio := 0.452       # quasi tutta la cella: il fondale DOMINA il palco
	var centro_z := 0.10
	var alto := 1.86          # la volta e' piu' alta che profonda: e' un guscio
	var apertura := 1.72      # mezzo cono d'abbraccio, in radianti
	var cima := 1.30          # ci si ferma prima del polo: li' si strozza
	var nang := 11
	var narc := 7
	var d_ang := 2.0 * apertura / float(nang - 1)
	for a in nang:
		var ang := -apertura + d_ang * float(a)
		for k in narc:
			var salita := cima * float(k) / float(narc - 1)
			var rr := raggio * cos(salita)
			var largh := rr * d_ang + 0.022
			var mat_c: Material = intonaco
			if (a + k) % 3 == 0:
				mat_c = _mat(Color("e8dcc4"), Color("d2c3a6"), 2.5, 0.45)
			var concio := _box(n, Vector3(largh, 0.20, 0.040), mat_c,
					Vector3(sin(ang) * rr, h + 0.03 + raggio * sin(salita) * alto,
					centro_z - cos(ang) * rr))
			concio.rotation.y = -ang
			concio.rotation.x = salita
	# LE COSTE: i nervi di legno che salgono lungo l'arco, uno ogni due
	for a2 in range(0, nang, 2):
		var ang2 := -apertura + d_ang * float(a2)
		for k2 in narc:
			var sal2 := cima * float(k2) / float(narc - 1)
			var rr2 := raggio * cos(sal2)
			var costa := _box(n, Vector3(0.038, 0.21, 0.030), trave,
					Vector3(sin(ang2) * (rr2 + 0.030),
					h + 0.03 + raggio * sin(sal2) * alto,
					centro_z - cos(ang2) * (rr2 + 0.030)))
			costa.rotation.y = -ang2
			costa.rotation.x = sal2
	# la cimasa dorata che orla la bocca della conchiglia, a terra
	for a3 in nang:
		var ang3 := -apertura + d_ang * float(a3)
		var cim := _box(n, Vector3(raggio * d_ang + 0.03, 0.032, 0.055), oro,
				Vector3(sin(ang3) * (raggio + 0.012), h + 0.016,
				centro_z - cos(ang3) * (raggio + 0.012)))
		cim.rotation.y = -ang3
	# LA CHIAVE DI VOLTA CHIUDE L'ARCO, quindi sta DOVE FINISCE L'ARCO. Era
	# alzata di 0.10 e tirata indietro a metà raggio (`* 0.5`): due errori
	# nella stessa riga, e il fiore d'oro galleggiava staccato sopra la
	# conchiglia. Il concio in cima sta a `centro_z − raggio·cos(cima)`,
	# come tutti gli altri: la chiave si posa lì sopra e basta.
	_ball(n, 0.048, oro, Vector3(0, h + 0.03 + raggio * sin(cima) * alto + 0.035,
			centro_z - raggio * cos(cima) * 0.98), Vector3(1.0, 0.62, 1.0))

	# le due lanterne d'angolo: un palco si accende
	for sx3: float in [-0.418, 0.418]:
		_cyl(n, 0.016, 0.020, 0.34, trave, Vector3(sx3, h + 0.17, 0.20))
		_cyl(n, 0.055, 0.048, 0.10, _glow(Color("ffe6b8"), Color("ffc978"), 1.4),
				Vector3(sx3, h + 0.39, 0.20))
		_cyl(n, 0.020, 0.052, 0.05, trave, Vector3(sx3, h + 0.46, 0.20))
	var luce := OmniLight3D.new()
	luce.light_color = Color(1.0, 0.86, 0.62)
	# PIANO con l'energia: le conchiglie si AFFIANCANO, e tre luci da 1.6
	# che si sommano dentro l'intonaco chiaro bruciano il fondale in tre
	# macchie bianche. Una luce per campata, tenue, e insieme fanno la
	# ribalta.
	luce.light_energy = 0.85
	luce.omni_range = 4.2
	luce.position = Vector3(0, h + 0.55, 0.10)
	n.add_child(luce)

	# l'ancoraggio di chi si esibisce: sotto la volta, un passo avanti
	var posto := Node3D.new()
	posto.name = "Ribalta"
	posto.position = Vector3(0, h, 0.26)
	n.add_child(posto)
	return n



# LA GRADINATA. Due file di sedute in pietra coi braccioli alle
# estremita'. Affiancarne piu' d'una nella stessa direzione fa UNA
# platea: BuildSystem spegne i braccioli sui fianchi condivisi
# (rinfresca_braccioli) e la seduta corre continua da un capo all'altro
# — e' cosi' che l'anfiteatro diventa GRANDE, perche' l'hai fatto tu.
#
# LE LEZIONI DELLA PRIMA VERSIONE (bocciata guardando il catalogo):
#  · era fatta di _box e leggeva come un cassonetto, perche' una
#    gradinata la si guarda spesso DA DIETRO (sta fra il prato e il
#    palco) e il retro era una parete cieca con quattro righe verticali.
#    Adesso ogni alzata e' fatta di CONCI VERI: blocchi pieni ad angoli
#    tondi, a corsi sfalsati, con la malta scura che affiora nei giunti.
#    Blocchi pieni = la muratura si legge sul fronte, sul retro e sui
#    fianchi CON LA STESSA geometria;
#  · la fila alta partiva dalla quota della bassa: di profilo era una
#    mensola a sbalzo sul vuoto. Una gradinata vera e' PIENA fino a
#    terra, e i corsi si moltiplicano da soli con l'altezza;
#  · il muschio appoggiato PER TERRA accanto al muro leggeva come una
#    fila di ninfee: va incassato a meta' nella pietra e deve
#    arrampicarsi sul primo corso, piu' alto che largo.


## Il contorno di un rettangolo ad angoli tondi sul piano XZ, antiorario,
## centrato sull'origine: e' il profilo che _prisma estrude. Con questo
## le pedate, i conci e i cuscini perdono gli spigoli a coltello.
static func _rrect_xz(w: float, d: float, r: float, k := 4) -> Array:
	var out: Array = []
	var hw := w * 0.5 - r
	var hd := d * 0.5 - r
	var centri := [Vector2(hw, hd), Vector2(-hw, hd),
			Vector2(-hw, -hd), Vector2(hw, -hd)]
	for c in 4:
		var a0 := PI * 0.5 * float(c)
		for i in k + 1:
			var a := a0 + PI * 0.5 * float(i) / float(k)
			out.append((centri[c] as Vector2) + Vector2(cos(a), sin(a)) * r)
	return out


static func _gradinata() -> Node3D:
	var n := Node3D.new()
	# la pietra e' PIU' SCURA di STONE: al sole del prato il grigio chiaro
	# si sbianca e la gradinata leggeva come una lastra di gesso
	var pietra := _mat(Color("b3aa9a"), Color("948b7c"), 2.2, 0.5)
	var concio_a := _mat(Color("9a917f"), Color("7d7565"), 2.6, 0.5)
	var concio_b := _mat(Color("a49a88"), Color("867d6c"), 2.4, 0.5)
	var malta := _mat(Color("6b644f"), Color("564f3e"), 3.0, 0.4)
	var muschio := _mat(Color("8aa870"), Color("6f8d58"), 5.0, 0.5)

	# DUE FILE. Ogni gradino e' un'ALZATA di conci pieni con sopra la
	# PEDATA che sporge tutt'attorno: e' quello sbalzo, col suo filo
	# d'ombra, a farlo leggere come un gradino da qualunque lato.
	for i in 2:
		var cima := 0.26 + float(i) * 0.28        # quota del piano di seduta
		var zc := -0.03 - float(i) * 0.32         # centro della pedata
		var base := 0.0                           # PIENA fino a terra
		# ogni fila ha la SUA z, o la fila alta resta al centro della cella
		var zr := zc - 0.01

		# il CUORE di malta scura: affiora nei giunti fra i conci
		_prisma(n, _rrect_xz(0.93, 0.29, 0.04), base,
				cima - 0.06 - base, malta).position.z = zr

		# i CONCI a corsi sfalsati (running bond), quanti ne servono per
		# arrivare in quota: la fila bassa ne ha due, l'alta quattro.
		# Blocchi PIENI in profondita': fronte, retro e fianchi sono la
		# stessa muratura.
		var h_tot := cima - 0.06 - base
		var n_corsi := maxi(2, roundi(h_tot / 0.107))
		var h_corso := (h_tot - 0.012 * float(n_corsi - 1)) / float(n_corsi)
		var corsi := [[0.35, 0.27, 0.35], [0.23, 0.36, 0.35]]
		for c in n_corsi:
			var y0 := base + float(c) * (h_corso + 0.012)
			var xs := -0.48
			var fila: Array = corsi[c % 2]
			for b in fila.size():
				var wb := float(fila[b])
				var mat_c: Material = concio_a if (c + b) % 2 == 0 else concio_b
				var blocco := _prisma(n, _rrect_xz(wb, 0.315, 0.030),
						y0, h_corso, mat_c)
				blocco.position = Vector3(xs + wb * 0.5, 0.0, zr)
				xs += wb + 0.012

		# la PEDATA: TRE lastroni ad angoli tondi che sporgono di 4-5 cm
		# su tre lati, ognuno col suo naso bombato. Tre e non uno: i
		# giunti in quota riprendono il running bond dei conci sotto —
		# una lastra unica da un metro leggeva come cemento colato, non
		# come pietra posata a mano. (Ed e' anche il contratto di
		# test_sedersi: sotto ogni Posto ci dev'essere la SUA lastra.)
		var lastre: Array = [[0.34, 0.30, 0.34], [0.30, 0.34, 0.34]][i]
		var xl := -0.498
		for l in lastre.size():
			var wl := float(lastre[l])
			var ped := _prisma(n, _rrect_xz(wl, 0.38, 0.05), cima - 0.06,
					0.06, pietra)
			ped.position = Vector3(xl + wl * 0.5, 0.0, zc)
			var naso := _cyl(n, 0.032, 0.032, wl - 0.05, pietra,
					Vector3(xl + wl * 0.5, cima - 0.030, zc + 0.185))
			naso.rotation.z = PI * 0.5
			xl += wl + 0.008

	# IL MUSCHIO: incassato a meta' nella pietra, si arrampica sul primo
	# corso — davanti, DIETRO (e' il lato che si vede dal prato), su un
	# fianco e un ciuffo sull'orlo in alto
	for m in [[-0.38, 0.098, 1.25], [0.30, 0.102, 1.05]]:
		_ball(n, 0.11, muschio,
				Vector3(float(m[0]), 0.045, float(m[1])),
				Vector3(float(m[2]), 0.52, 0.5))
	for m2 in [[-0.26, -0.500, 1.15], [0.34, -0.505, 0.95]]:
		_ball(n, 0.11, muschio, Vector3(float(m2[0]), 0.05, float(m2[1])),
				Vector3(float(m2[2]), 0.55, 0.5))
	_ball(n, 0.095, muschio, Vector3(0.470, 0.06, -0.30), Vector3(0.5, 0.50, 1.15))
	_ball(n, 0.075, muschio, Vector3(-0.47, 0.545, -0.30), Vector3(1.0, 0.26, 1.3))

	# I POSTI, sulla pietra nuda. C'erano i cuscini e il lume, ed erano
	# belli NEL CATALOGO: in gioco gli spettatori ci si siedono SOPRA (i
	# corpi li coprono o li attraversano), e affiancando le gradinate la
	# stessa fila di cuscini identici si ripeteva a ogni cella — il
	# contrario di una platea viva. Gli oggetti che uno spettatore seduto
	# nasconderebbe non vanno modellati: vanno lasciati al pubblico vero.
	var posti := [[-0.31, 0], [0.06, 0], [-0.08, 1], [0.33, 1]]
	for i3 in posti.size():
		var cx := float(posti[i3][0])
		var fila := int(posti[i3][1])
		var cy := 0.26 + float(fila) * 0.28
		var cz := -0.01 - float(fila) * 0.32 + 0.02 * float(i3 % 2)
		# l'ancoraggio del posto: e' qui che si siede chi ascolta
		# (Concerto cerca "Posto*" e ordina per distanza dal pianoforte).
		# Sta ESATTAMENTE sulla pietra: il punto dichiarato e' dove il
		# corpo viene posato, e 3 cm di "morbidezza" avevano senso sul
		# cuscino — sulla pietra nuda erano un posto a mezz'aria.
		var posto := Node3D.new()
		posto.name = "Posto%d" % i3
		posto.position = Vector3(cx, cy, cz)
		posto.set_meta("seduta", Vector3.ZERO)
		n.add_child(posto)

	# I BRACCIOLI: la spalletta di pietra che segue le due file, una per
	# fianco, come nei teatri di pietra. Coi NOMI, perche' non sono solo
	# decorazione: quando un'altra gradinata continua la fila (stessa
	# rotazione, cella accanto), BuildSystem.rinfresca_braccioli spegne
	# quello sul fianco condiviso — la seduta resta continua e le
	# spallette vivono solo alle due estremita' della platea.
	for lato in [["BraccioloSx", -1.0], ["BraccioloDx", 1.0]]:
		var br := Node3D.new()
		br.name = str(lato[0])
		br.position.x = float(lato[1]) * 0.462
		n.add_child(br)
		for f in 2:
			var quota := 0.26 + float(f) * 0.28
			var zf := -0.03 - float(f) * 0.32
			var corpo := _prisma(br, _rrect_xz(0.070, 0.33, 0.028), quota,
					0.085, concio_b)
			corpo.position.z = zf
			# il coperchio bombato, piu' largo di un filo: lo stesso
			# sbalzo della pedata, in piccolo
			var capp := _prisma(br, _rrect_xz(0.084, 0.35, 0.034),
					quota + 0.085, 0.032, pietra)
			capp.position.z = zf
	return n


# ============================================================================
# IL BAR DEL PAESE
# ============================================================================
# «Punto di ritrovo» non è un'etichetta: è un posto con dentro le cose
# giuste. Il bancone di zinco su cui si appoggia il gomito, la macchina
# del caffè che sbuffa, i tavolini fuori sotto l'ombrellone, e il
# biliardino — perché gli amici non si ritrovano per stare in silenzio,
# si ritrovano per litigare su un gol di stecca.
#
# È il pezzo di villaggio che mancava fra la casa e la piazza: un dentro
# che non è di nessuno e quindi è di tutti.
#
# Fronte di tutti i pezzi: verso -Z, come il resto del catalogo.

const ZINCO := Color("b6bbc2")
const ZINCO_CUPO := Color("969ba3")
const CROMO := Color("dce0e6")
const CAFFE := Color("6b4634")
const BAR_ROSSO := Color("c26057")
const BAR_ROSSO_CUPO := Color("a44c45")
const BOTTIGLIA := Color("6f9a76")
const MARMO := Color("efe9dd")


## IL VETRO VERO. `_mat(..., trans)` NON è trasparenza: nell'handpaint
## `translucency` è la retro-illuminazione (la luce che passa attraverso
## una foglia), e una vetrina fatta così esce OPACA — coi cornetti dentro
## che non si vedono, cioè senza il motivo per cui esiste una vetrina.
## Il vetro del progetto è quello della serra: alpha vero, un filo di
## emissione azzurra e roughness bassa.
static func _vetro(alpha := 0.34) -> StandardMaterial3D:
	var g := StandardMaterial3D.new()
	g.albedo_color = Color(0.83, 0.92, 0.97, alpha)
	g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	g.emission_enabled = true
	g.emission = Color("bfe0f2")
	g.emission_energy_multiplier = 0.22
	g.roughness = 0.14
	return g


## Un cornetto: mezzaluna dorata. Ne serve più d'uno, e tutti diversi.
static func _cornetto(parent: Node3D, pos: Vector3, giro: float) -> void:
	var pasta := _mat(Color("e8bd78"), Color("d4a45e"), 7.0, 0.5)
	var c := Node3D.new()
	c.position = pos
	c.rotation.y = giro
	parent.add_child(c)
	_ball(c, 0.036, pasta, Vector3(0, 0, 0), Vector3(1.5, 0.62, 0.85))
	for lato: float in [-1.0, 1.0]:
		var punta := _ball(c, 0.02, pasta, Vector3(lato * 0.05, -0.004, 0.018),
				Vector3(1.1, 0.6, 0.9))
		punta.rotation.y = lato * 0.5


## Una bottiglia da mensola, TORNITA: il corpo che sale, la spalla che
## curva, il collo, il tappo. L'altezza e il colore cambiano, o la
## mensola sembra stampata.
static func _bottiglia(parent: Node3D, pos: Vector3, alt: float, col: Color) -> void:
	var vetro := _mat(col, col.darkened(0.2), 5.0, 0.4, 0.35)
	BUILDER.lathe(parent, [Vector2(0.038, 0.0), Vector2(0.04, alt * 0.1),
			Vector2(0.038, alt * 0.72), Vector2(0.032, alt * 0.92),
			Vector2(0.02, alt * 1.08), Vector2(0.014, alt * 1.22),
			Vector2(0.013, alt * 1.42)], vetro, pos, 16)
	_cyl(parent, 0.016, 0.016, 0.022, _mat(OTTONE, OTTONE_SCURO, 5.0, 0.3),
			pos + Vector3(0, alt * 1.44, 0))


static func _bancone_bar() -> Node3D:
	# IL BANCONE: zinco sopra, legno sotto, il poggiapiedi d'ottone
	# consumato da chi ci sta in piedi a chiacchierare. È l'àncora del bar:
	# comprarlo porta con sé tutto il resto (Economy.CORREDO).
	# Belle époque, non compensato: corpo coi fianchi tondi, zoccolo,
	# pannelli in cornice con le lesene tornite, il piano a becco tondo
	# col profilo d'ottone che gira sugli angoli — e sul piano la vita
	# vera del banco: tazzine, piattini, zuccheriera, campanella, cassa.
	var n := Node3D.new()
	var legno := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	var noce := _mat(WOOD_DARK, WOOD_DARK.darkened(0.22), 4.0, 0.45)
	var pannello := _mat(BAR_ROSSO, BAR_ROSSO_CUPO, 4.5, 0.45)
	var zinco := _mat(ZINCO, ZINCO_CUPO, 6.0, 0.35)
	var ottone := _mat(OTTONE, OTTONE_SCURO, 5.0, 0.4)
	var porcellana := _mat(Color.WHITE, CREAM, 6.0, 0.2)
	var piatto := _mat(CREAM, Color("efe4d2"), 6.0, 0.2)

	# il corpo, coi fianchi che si arrotondano, e lo zoccolo scuro sotto
	_loft(n, [[-0.50, 0.21, 0.06, 0.97, 0.10],
			[-0.46, 0.24, 0.06, 0.97, 0.04],
			[0.46, 0.24, 0.06, 0.97, 0.04],
			[0.50, 0.21, 0.06, 0.97, 0.10]], legno, Vector3(0, 0, 0.03))
	_loft(n, [[-0.52, 0.23, 0.015, 0.14, 0.05],
			[-0.48, 0.26, 0.015, 0.14, 0.03],
			[0.48, 0.26, 0.015, 0.14, 0.03],
			[0.52, 0.23, 0.015, 0.14, 0.05]], noce, Vector3(0, 0, 0.03))

	# il piano di zinco a becco tondo, che sporge davanti, e il profilo
	# d'ottone che ne veste il bordo girando sugli angoli
	_loft(n, [[-0.545, 0.28, 0.97, 1.05, 0.038],
			[-0.51, 0.31, 0.97, 1.05, 0.025],
			[0.51, 0.31, 0.97, 1.05, 0.025],
			[0.545, 0.28, 0.97, 1.05, 0.038]], zinco, Vector3(0, 0, -0.02))
	BUILDER.tube(n, [Vector3(-0.495, 1.028, -0.19), Vector3(-0.535, 1.042, -0.315),
			Vector3(-0.46, 1.042, -0.345), Vector3(0.46, 1.042, -0.345),
			Vector3(0.535, 1.042, -0.315), Vector3(0.495, 1.028, -0.19)],
			[0.014, 0.016, 0.016, 0.016, 0.016, 0.014], ottone)

	# il fronte: le due modanature, i tre pannelli rossi DENTRO le loro
	# cornici di noce (una borchia d'ottone al centro), e le lesene
	# tornite agli angoli con base e capitello
	for y: float in [0.225, 0.845]:
		BUILDER.tube(n, [Vector3(-0.43, y, -0.235), Vector3(0.0, y, -0.243),
				Vector3(0.43, y, -0.235)], [0.011, 0.012, 0.011], noce)
	for dx: float in [-0.32, 0.0, 0.32]:
		_lastra(n, 0.125, 0.54, 0.032, 0.022, noce,
				Vector3(dx, 0.535, -0.243), Vector3(0, PI * 0.5, 0))
		_lastra(n, 0.102, 0.49, 0.026, 0.018, pannello,
				Vector3(dx, 0.535, -0.251), Vector3(0, PI * 0.5, 0))
		_ball(n, 0.011, ottone, Vector3(dx, 0.535, -0.262))
	for sx: float in [-1.0, 1.0]:
		_cyl(n, 0.026, 0.03, 0.72, legno, Vector3(sx * 0.45, 0.52, -0.235))
		_cyl(n, 0.035, 0.04, 0.05, noce, Vector3(sx * 0.45, 0.175, -0.235))
		_cyl(n, 0.04, 0.033, 0.045, noce, Vector3(sx * 0.45, 0.895, -0.235))
		_ball(n, 0.024, ottone, Vector3(sx * 0.45, 0.935, -0.235))
		# e il fianco non resta nudo: un pannello in cornice anche lì,
		# perché il bancone si guarda anche di profilo
		_lastra(n, 0.14, 0.54, 0.032, 0.022, noce,
				Vector3(sx * 0.505, 0.535, 0.03))
		_lastra(n, 0.115, 0.49, 0.026, 0.018, pannello,
				Vector3(sx * 0.513, 0.535, 0.03))
		_ball(n, 0.011, ottone, Vector3(sx * 0.524, 0.535, 0.03))

	# il poggiapiedi d'ottone: la barra rientra nel corpo alle estremità
	# invece di finire a mezz'aria, e due zampette la reggono
	BUILDER.tube(n, [Vector3(-0.47, 0.155, -0.18), Vector3(-0.44, 0.16, -0.30),
			Vector3(0.0, 0.16, -0.305), Vector3(0.44, 0.16, -0.30),
			Vector3(0.47, 0.155, -0.18)],
			[0.02, 0.022, 0.022, 0.022, 0.02], ottone)
	for dx2: float in [-0.30, 0.30]:
		_cyl(n, 0.014, 0.017, 0.13, ottone, Vector3(dx2, 0.085, -0.30))

	# il lato del barista: due cassetti col pomello e lo sportello basso
	for dx3: float in [-0.20, 0.20]:
		_lastra(n, 0.155, 0.115, 0.025, 0.016, noce,
				Vector3(dx3, 0.855, 0.276), Vector3(0, PI * 0.5, 0))
		_ball(n, 0.013, ottone, Vector3(dx3, 0.855, 0.29))
	_lastra(n, 0.16, 0.44, 0.035, 0.016, noce,
			Vector3(0, 0.43, 0.276), Vector3(0, PI * 0.5, 0))
	_ball(n, 0.013, ottone, Vector3(0.10, 0.43, 0.29))

	# due tazzine col piattino, pronte — e stavolta col manico
	for dx4: float in [-0.24, 0.08]:
		var piatt := _cyl(n, 0.05, 0.038, 0.012, piatto, Vector3(dx4, 1.056, -0.12))
		piatt.name = "Piattino"
		_cyl(n, 0.028, 0.022, 0.038, porcellana, Vector3(dx4, 1.08, -0.12))
		_cyl(n, 0.021, 0.021, 0.006, _mat(CAFFE, Color("52351f"), 5.0, 0.4),
				Vector3(dx4, 1.096, -0.12))
		var manico := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.008
		tm.outer_radius = 0.017
		manico.mesh = tm
		manico.material_override = porcellana
		manico.position = Vector3(dx4 + 0.028, 1.082, -0.12)
		manico.rotation.x = PI * 0.5
		n.add_child(manico)
	# la pila di piattini di scorta e la zuccheriera col coperchio
	for i in 3:
		_cyl(n, 0.05, 0.038, 0.012, piatto,
				Vector3(-0.06, 1.056 + float(i) * 0.013, 0.10))
	_ball(n, 0.036, porcellana, Vector3(0.18, 1.078, 0.08), Vector3(1, 0.82, 1))
	_cyl(n, 0.026, 0.03, 0.012, porcellana, Vector3(0.18, 1.105, 0.08))
	_ball(n, 0.008, ottone, Vector3(0.18, 1.117, 0.08))
	# la campanella da banco: si suona per chiamare, e per salutare
	_ball(n, 0.032, ottone, Vector3(-0.40, 1.048, -0.14), Vector3(1, 0.62, 1))
	_cyl(n, 0.004, 0.004, 0.014, ottone, Vector3(-0.40, 1.072, -0.14))
	_ball(n, 0.006, ottone, Vector3(-0.40, 1.082, -0.14))

	# il registratore di cassa d'ottone, di quelli d'epoca: il corpo, il
	# rullo con lo scontrino che spunta, i tasti su due file e la
	# manovella sul fianco
	var cassa := Node3D.new()
	cassa.name = "Cassa"
	cassa.position = Vector3(0.36, 1.05, 0.04)
	n.add_child(cassa)
	_loft(cassa, [[-0.095, 0.083, 0.0, 0.16, 0.02],
			[0.095, 0.083, 0.0, 0.16, 0.02]], ottone)
	var rullo := _cyl(cassa, 0.052, 0.052, 0.185, ottone, Vector3(0, 0.165, 0.028))
	rullo.rotation.z = PI * 0.5
	var carta := _cyl(cassa, 0.02, 0.02, 0.11, porcellana, Vector3(0, 0.185, -0.035))
	carta.rotation.z = PI * 0.5
	_lastra(cassa, 0.045, 0.075, 0.012, 0.006, porcellana,
			Vector3(0, 0.225, -0.038), Vector3(0.22, 0, 0))
	for fila in 2:
		for i in 3:
			_ball(cassa, 0.011, porcellana,
					Vector3(-0.04 + 0.04 * float(i), 0.065 + float(fila) * 0.045,
					-0.088 - float(fila) * 0.012))
	var braccio := _cyl(cassa, 0.007, 0.007, 0.05, ottone, Vector3(0.115, 0.09, 0))
	braccio.rotation.z = PI * 0.5
	_cyl(cassa, 0.009, 0.009, 0.04, noce, Vector3(0.138, 0.07, 0))
	return n


static func _macchina_caffe() -> Node3D:
	# LA MACCHINA DEL CAFFÈ: quella a leva, cromata, con l'aquila d'ottone
	# in cima e la lancia del vapore. Il nodo "Vapore" è il punto da cui
	# un domani esce lo sbuffo. Base stondata con la griglia
	# raccogligocce, targa bombata col manometro ad ago, manici torniti,
	# vassoio scaldatazze con la ringhierina: da bar vero, non da dado.
	var n := Node3D.new()
	var cromo := _mat(CROMO, Color("b9bec6"), 7.0, 0.3)
	var ottone := _mat(OTTONE, OTTONE_SCURO, 6.0, 0.35)
	var rosso := _mat(BAR_ROSSO, BAR_ROSSO_CUPO, 4.5, 0.45)
	var manico_legno := _mat(WOOD_DARK, Color("5c4030"), 4.0, 0.4)
	var porcellana := _mat(Color.WHITE, CREAM, 6.0, 0.2)
	# la base stondata, la vaschetta incassata e la griglia raccogligocce
	_loft(n, [[-0.31, 0.14, 0.0, 0.085, 0.05],
			[-0.27, 0.17, 0.0, 0.085, 0.025],
			[0.27, 0.17, 0.0, 0.085, 0.025],
			[0.31, 0.14, 0.0, 0.085, 0.05]], cromo)
	_box(n, Vector3(0.5, 0.024, 0.24), _mat(ZINCO_CUPO, Color("7d838b"), 5.0, 0.3),
			Vector3(0, 0.078, -0.04))
	for i in 7:
		var stecca := _cyl(n, 0.005, 0.005, 0.22, cromo,
				Vector3(-0.15 + float(i) * 0.05, 0.091, -0.05))
		stecca.rotation.x = PI * 0.5
	# la caldaia orizzontale. I tappi d'ottone vanno PIÙ STRETTI del corpo:
	# più larghi diventano due dischi pieni visti di faccia, e da tre
	# quarti la macchina non è più una macchina del caffè — è una botte
	# d'oro. Qui sono anelli incassati, e il cromo resta il padrone.
	var caldaia := _cyl(n, 0.2, 0.2, 0.6, cromo, Vector3(0, 0.36, 0.02))
	caldaia.rotation.z = PI * 0.5
	for lato: float in [-1.0, 1.0]:
		# la ghiera cromata resta il bordo esterno, l'ottone è il tondo
		# in mezzo: così di tre quarti si vede una macchina, non un fondo
		# d'ottone grande quanto tutta la fiancata
		var ghiera := _cyl(n, 0.2, 0.2, 0.04, cromo,
				Vector3(lato * 0.3, 0.36, 0.02))
		ghiera.rotation.z = PI * 0.5
		var anello := _cyl(n, 0.14, 0.14, 0.05, ottone,
				Vector3(lato * 0.305, 0.36, 0.02))
		anello.rotation.z = PI * 0.5
		# i bulloncini attorno al coperchio
		for k in 6:
			var a := PI * 2.0 / 6.0 * float(k)
			_ball(n, 0.013, ottone, Vector3(lato * 0.322,
					0.36 + cos(a) * 0.115, 0.02 + sin(a) * 0.115))
	# la targa rossa bombata sul fronte, in cornice d'ottone, e il
	# manometro con l'ago: un quadrante senza ago è un adesivo
	_lastra(n, 0.30, 0.15, 0.055, 0.016, ottone, Vector3(0, 0.37, -0.196),
			Vector3(0, PI * 0.5, 0))
	_lastra(n, 0.28, 0.125, 0.048, 0.018, rosso, Vector3(0, 0.37, -0.203),
			Vector3(0, PI * 0.5, 0))
	var ghiera_mano := _cyl(n, 0.046, 0.046, 0.018, ottone, Vector3(-0.16, 0.42, -0.212))
	ghiera_mano.rotation.x = PI * 0.5
	var quadrante := _cyl(n, 0.034, 0.034, 0.008, porcellana, Vector3(-0.16, 0.42, -0.221))
	quadrante.rotation.x = PI * 0.5
	var ago := _box(n, Vector3(0.026, 0.004, 0.004), manico_legno,
			Vector3(-0.152, 0.428, -0.227))
	ago.rotation.z = 0.65
	# i due gruppi, sporgenti in avanti, con la coppetta e il manico
	# TORNITO che pende: è il dettaglio che dice «macchina del caffè»
	# prima ancora della forma
	for i in 2:
		var dx := -0.14 + 0.28 * float(i)
		_cyl(n, 0.042, 0.047, 0.11, ottone, Vector3(dx, 0.235, -0.19))
		var coppetta := _cyl(n, 0.047, 0.04, 0.042, ottone, Vector3(dx, 0.16, -0.19))
		coppetta.name = "Coppetta%d" % i
		var giro := 0.28 - 0.5 * float(i)
		var manico := _cyl(n, 0.009, 0.012, 0.11, manico_legno,
				Vector3(dx + sin(giro) * 0.045, 0.153, -0.235 - cos(giro) * 0.035))
		manico.rotation.x = -1.62
		manico.rotation.y = giro
		_ball(n, 0.014, manico_legno,
				Vector3(dx + sin(giro) * 0.085, 0.148, -0.288 - cos(giro) * 0.03))
		# la levetta cromata sopra ogni gruppo
		var leva := _cyl(n, 0.013, 0.013, 0.17, cromo, Vector3(dx, 0.29, -0.19))
		leva.rotation.x = -0.9
		_ball(n, 0.022, manico_legno, Vector3(dx, 0.35, -0.255))
	# la lancia del vapore: un gomito vero, col rubinetto d'ottone alla
	# radice e l'ugello in punta — e di là, il rubinetto dell'acqua calda
	BUILDER.tube(n, [Vector3(0.26, 0.33, -0.10), Vector3(0.30, 0.26, -0.16),
			Vector3(0.31, 0.17, -0.185), Vector3(0.315, 0.115, -0.20)],
			[0.013, 0.011, 0.009, 0.008], cromo)
	_ball(n, 0.016, ottone, Vector3(0.27, 0.335, -0.115))
	_cyl(n, 0.005, 0.009, 0.02, cromo, Vector3(0.315, 0.10, -0.20))
	var vapore := Node3D.new()
	vapore.name = "Vapore"
	vapore.position = Vector3(0.315, 0.09, -0.20)
	n.add_child(vapore)
	_ball(n, 0.016, ottone, Vector3(-0.27, 0.335, -0.115))
	_cyl(n, 0.009, 0.011, 0.055, cromo, Vector3(-0.30, 0.28, -0.14))
	# il vassoio scaldatazze sopra la caldaia (le tazzine ci si APPOGGIANO:
	# prima galleggiavano a mezz'aria sopra il tondo), con la ringhierina
	# d'ottone tutt'attorno che le tiene
	_lastra(n, 0.16, 0.54, 0.03, 0.014, cromo, Vector3(0, 0.575, 0.06),
			Vector3(0, 0, PI * 0.5))
	for sz: float in [-0.10, 0.22]:
		var asta := _cyl(n, 0.007, 0.007, 0.5, ottone, Vector3(0, 0.615, sz))
		asta.rotation.z = PI * 0.5
	for sx: float in [-0.25, 0.25]:
		var asta2 := _cyl(n, 0.007, 0.007, 0.32, ottone, Vector3(sx, 0.615, 0.06))
		asta2.rotation.x = PI * 0.5
		for sz2: float in [-0.10, 0.22]:
			_cyl(n, 0.005, 0.005, 0.035, ottone, Vector3(sx, 0.596, sz2))
			_ball(n, 0.009, ottone, Vector3(sx, 0.615, sz2))
	# l'aquila in cima: nessuna macchina del caffè seria ne è priva.
	# Colonnina, cupola, e l'uccello INTERO: petto, testa, becco, ali
	# aperte e coda — non una palla con due stecche
	_cyl(n, 0.055, 0.08, 0.05, ottone, Vector3(0, 0.615, 0.06))
	_ball(n, 0.05, ottone, Vector3(0, 0.652, 0.06), Vector3(1, 0.5, 1))
	# l'aquila sta APPOLLAIATA, ali chiuse sul petto: a questa scala un
	# uccello raccolto si riconosce, un'aquila spiegata diventa un'elica
	var aquila := _ball(n, 0.036, ottone, Vector3(0, 0.695, 0.062),
			Vector3(0.75, 1.0, 0.65))
	aquila.name = "Aquila"
	aquila.rotation.x = -0.1
	for lato: float in [-1.0, 1.0]:
		var ala := _ball(n, 0.034, ottone, Vector3(lato * 0.028, 0.693, 0.068),
				Vector3(0.4, 0.9, 0.55))
		ala.rotation.z = lato * -0.12
	_ball(n, 0.018, ottone, Vector3(0, 0.738, 0.05))
	var becco := _cyl(n, 0.002, 0.008, 0.022, ottone, Vector3(0, 0.734, 0.03))
	becco.rotation.x = -1.3
	var coda_aq := _ball(n, 0.026, ottone, Vector3(0, 0.672, 0.096), Vector3(0.42, 0.22, 0.85))
	coda_aq.rotation.x = 0.55
	# le tazzine che si scaldano sopra, col manico, appoggiate davvero
	for i in 3:
		var cx := -0.18 + 0.18 * float(i)
		_cyl(n, 0.026, 0.022, 0.032, porcellana, Vector3(cx, 0.605, 0.06))
		var manico_t := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.007
		tm.outer_radius = 0.015
		manico_t.mesh = tm
		manico_t.material_override = porcellana
		manico_t.position = Vector3(cx + 0.026, 0.607, 0.06 + 0.01 * float(i - 1))
		manico_t.rotation.x = PI * 0.5
		manico_t.rotation.z = 0.4 * float(i - 1)
		n.add_child(manico_t)
	return n


## LA FALDA DI VETRO CURVO: un profilo (z, y) spazzato lungo X, a due
## facce (il vetro si guarda da fuori E da dentro), coi fianchi chiusi
## a ventaglio dal punto in basso dietro. Il vetro curvo è ciò che fa
## «vetrina da bar»: un box di vetro è una teca da museo.
static func _vetro_curvo(parent: Node3D, x0: float, x1: float,
		profilo: Array, mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var np := profilo.size()
	for i in np - 1:
		var a: Vector2 = profilo[i]
		var b: Vector2 = profilo[i + 1]
		var d := (b - a).normalized()
		var nn := Vector3(0, d.x, -d.y)   # (z,y): fuori = (-dy, dz)
		var q := [Vector3(x0, a.y, a.x), Vector3(x1, a.y, a.x),
				Vector3(x1, b.y, b.x), Vector3(x0, b.y, b.x)]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_normal(nn)
			st.add_vertex(q[k])
		for k in [0, 2, 1, 0, 3, 2]:
			st.set_normal(-nn)
			st.add_vertex(q[k])
	# i fianchi: ventaglio dall'angolo in basso dietro
	var c := Vector2((profilo[np - 1] as Vector2).x, (profilo[0] as Vector2).y)
	for lato in 2:
		var xx := x0 if lato == 0 else x1
		var fuori := -1.0 if lato == 0 else 1.0
		for i in np - 1:
			var a2: Vector2 = profilo[i]
			var b2: Vector2 = profilo[i + 1]
			var terna := [Vector3(xx, c.y, c.x), Vector3(xx, a2.y, a2.x),
					Vector3(xx, b2.y, b2.x)]
			if lato == 0:
				terna = [terna[0], terna[2], terna[1]]
			for v in terna:
				st.set_normal(Vector3(fuori, 0, 0))
				st.add_vertex(v)
			for v_idx in [0, 2, 1]:
				st.set_normal(Vector3(-fuori, 0, 0))
				st.add_vertex(terna[v_idx])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	parent.add_child(mi)
	return mi


static func _vetrina_dolci() -> Node3D:
	# LA VETRINA DEI DOLCI: il vetro curvo DAVVERO curvo (con le centine
	# cromate che lo incorniciano), il corpo in tinta col bancone —
	# pannelli rossi in cornice e zoccolo di noce — e dentro i cornetti,
	# le ciambelle glassate e la torta a spicchio. Si guarda prima di
	# ordinare, sempre; il retro è aperto, come al banco vero.
	var n := Node3D.new()
	var legno := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	var noce := _mat(WOOD_DARK, WOOD_DARK.darkened(0.22), 4.0, 0.45)
	var pannello := _mat(BAR_ROSSO, BAR_ROSSO_CUPO, 4.5, 0.45)
	var vetro := _vetro(0.26)
	var zinco := _mat(ZINCO, ZINCO_CUPO, 6.0, 0.35)
	var cromo := _mat(CROMO, Color("b9bec6"), 7.0, 0.3)
	var ottone := _mat(OTTONE, OTTONE_SCURO, 5.0, 0.4)

	# il corpo coi fianchi tondi, lo zoccolo, e i pannelli in cornice
	_loft(n, [[-0.46, 0.19, 0.03, 0.42, 0.07],
			[-0.42, 0.21, 0.03, 0.42, 0.03],
			[0.42, 0.21, 0.03, 0.42, 0.03],
			[0.46, 0.19, 0.03, 0.42, 0.07]], legno)
	_loft(n, [[-0.475, 0.20, 0.012, 0.10, 0.04],
			[-0.44, 0.225, 0.012, 0.10, 0.025],
			[0.44, 0.225, 0.012, 0.10, 0.025],
			[0.475, 0.20, 0.012, 0.10, 0.04]], noce)
	for dx: float in [-0.24, 0.24]:
		_lastra(n, 0.14, 0.20, 0.03, 0.02, noce,
				Vector3(dx, 0.265, -0.207), Vector3(0, PI * 0.5, 0))
		_lastra(n, 0.115, 0.16, 0.024, 0.016, pannello,
				Vector3(dx, 0.265, -0.214), Vector3(0, PI * 0.5, 0))
		_ball(n, 0.010, ottone, Vector3(dx, 0.265, -0.224))

	# il piano di zinco a becco tondo su cui stanno i dolci
	_loft(n, [[-0.49, 0.215, 0.42, 0.47, 0.04],
			[-0.46, 0.235, 0.42, 0.47, 0.02],
			[0.46, 0.235, 0.42, 0.47, 0.02],
			[0.49, 0.215, 0.42, 0.47, 0.04]], zinco)

	# LA CAMPANA DI VETRO CURVO, con le centine cromate ai fianchi e i
	# correnti lungo gli spigoli: la curva è un quarto d'ellisse
	var arco: Array = []
	for i in 9:
		var th := float(i) / 8.0 * PI * 0.5
		arco.append(Vector2(-0.205 + (1.0 - cos(th)) * 0.255,
				0.475 + sin(th) * 0.44))
	arco.append(Vector2(0.19, 0.915))
	_vetro_curvo(n, -0.42, 0.42, arco, vetro)
	for sx: float in [-0.42, 0.42]:
		var centina: Array = []
		for p in arco:
			centina.append(Vector3(sx, (p as Vector2).y, (p as Vector2).x))
		BUILDER.tube(n, centina, [0.012, 0.012, 0.012, 0.012, 0.012,
				0.012, 0.012, 0.012, 0.012, 0.012], cromo, 24, 8)
	for spigolo: float in [-0.205, 0.19]:
		var y_sp := 0.475 if spigolo < 0.0 else 0.915
		var corrente := _cyl(n, 0.011, 0.011, 0.86, cromo,
				Vector3(0, y_sp, spigolo))
		corrente.rotation.z = PI * 0.5

	# il ripiano sospeso sulle colonnine cromate
	_lastra(n, 0.145, 0.76, 0.02, 0.012, zinco, Vector3(0, 0.70, 0.02),
			Vector3(0, 0, PI * 0.5))
	for sx2: float in [-0.34, 0.34]:
		for sz: float in [-0.08, 0.12]:
			_cyl(n, 0.008, 0.008, 0.23, cromo, Vector3(sx2, 0.585, sz))

	# i dolci: cornetti sotto e sopra, le ciambelle glassate, e la torta
	# a SPICCHIO (un prisma, non un mattone) con la fragolina in cima
	for k in 4:
		_cornetto(n, Vector3(-0.34 + 0.16 * float(k), 0.505,
				-0.05 + 0.06 * float(k % 2)), 0.4 * float(k))
	for k2 in 3:
		_cornetto(n, Vector3(-0.30 + 0.19 * float(k2), 0.735,
				-0.03 + 0.05 * float(k2 % 2)), 0.5 * float(k2) + 0.8)
	for cd in 2:
		var ciambella := MeshInstance3D.new()
		var cm := TorusMesh.new()
		cm.inner_radius = 0.018
		cm.outer_radius = 0.052
		ciambella.mesh = cm
		ciambella.material_override = _mat(PINK, PINK_DEEP, 5.0, 0.4)
		ciambella.position = Vector3(0.30 + 0.02 * float(cd), 0.727,
				-0.06 + 0.13 * float(cd))
		ciambella.rotation.x = 0.12 * float(cd)
		n.add_child(ciambella)
	var torta := _prisma(n, [Vector2(-0.07, 0.0), Vector2(0.10, 0.06),
			Vector2(0.10, -0.06)], 0.475, 0.085,
			_mat(CREAM, Color("f0e2c8"), 6.0, 0.3))
	torta.name = "Torta"
	torta.position = Vector3(0.27, 0.0, 0.04)
	torta.rotation.y = -0.5
	var glassa := _prisma(n, [Vector2(-0.07, 0.0), Vector2(0.105, 0.063),
			Vector2(0.105, -0.063)], 0.56, 0.022, _mat(PINK, PINK_DEEP, 5.0, 0.4))
	glassa.position = Vector3(0.27, 0.0, 0.04)
	glassa.rotation.y = -0.5
	_ball(n, 0.016, _mat(BAR_ROSSO, BAR_ROSSO_CUPO, 5.0, 0.35),
			Vector3(0.29, 0.59, 0.055))
	return n


static func _sgabello_alto() -> Node3D:
	# LO SGABELLO ALTO: quello da bancone, col poggiapiedi. Ci si sta in
	# bilico e si parla per ore. Il poggiapiedi è un ANELLO vero (un toro,
	# non un disco pieno) e il cuscino è bombato col bordino cucito.
	var n := Node3D.new()
	var cromo := _mat(CROMO, Color("b9bec6"), 7.0, 0.3)
	var cuoio := _mat(BAR_ROSSO, BAR_ROSSO_CUPO, 4.5, 0.5)
	var cupo := _mat(BAR_ROSSO_CUPO, Color("8f3f39"), 4.0, 0.4)
	for i in 3:
		var a := PI * 2.0 / 3.0 * float(i)
		var g := _cyl(n, 0.02, 0.026, 0.72, cromo,
				Vector3(cos(a) * 0.12, 0.36, sin(a) * 0.12))
		g.rotation.x = cos(a + PI * 0.5) * 0.12
		g.rotation.z = -sin(a + PI * 0.5) * 0.12
	var anello := MeshInstance3D.new()
	var am := TorusMesh.new()
	am.inner_radius = 0.155
	am.outer_radius = 0.183
	anello.mesh = am
	anello.material_override = cromo
	anello.position = Vector3(0, 0.24, 0)
	anello.name = "Poggiapiedi"
	n.add_child(anello)
	# la seduta: base, cuscino bombato, bordino cucito e il bottone
	_cyl(n, 0.185, 0.185, 0.035, cupo, Vector3(0, 0.715, 0))
	_ball(n, 0.19, cuoio, Vector3(0, 0.748, 0), Vector3(1, 0.42, 1))
	var bordino := MeshInstance3D.new()
	var bm := TorusMesh.new()
	bm.inner_radius = 0.176
	bm.outer_radius = 0.192
	bordino.mesh = bm
	bordino.material_override = cupo
	bordino.position = Vector3(0, 0.737, 0)
	n.add_child(bordino)
	_ball(n, 0.02, cuoio, Vector3(0, 0.788, 0), Vector3(1, 0.4, 1))
	return n


static func _mensola_bottiglie() -> Node3D:
	# LA MENSOLA DELLE BOTTIGLIE: sciroppi e amari dietro il bancone, di
	# tutte le altezze e di tutti i colori. Sta sul bordo, come una
	# mensola. Da retrobanco vero: fianchi ad angoli tondi, la cimasa che
	# li lega in alto, e su ogni ripiano la ringhierina d'ottone che
	# impedisce alle bottiglie il volo.
	var n := Node3D.new()
	var legno := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	var noce := _mat(WOOD_DARK, WOOD_DARK.darkened(0.22), 4.0, 0.45)
	var ottone := _mat(OTTONE, OTTONE_SCURO, 5.0, 0.4)
	for sx: float in [-0.44, 0.44]:
		_lastra(n, 0.10, 1.0, 0.045, 0.055, legno, Vector3(sx, 0.9, 0.04))
	_loft(n, [[-0.485, 0.115, 1.38, 1.44, 0.022],
			[0.485, 0.115, 1.38, 1.44, 0.022]], noce, Vector3(0, 0, 0.04))
	var colori := [Color("8a6fb0"), BOTTIGLIA, Color("c48a4a"), Color("b05a5a"),
			Color("6f93b8"), Color("d0a860")]
	for i in 2:
		var y := 0.62 + 0.42 * float(i)
		_lastra(n, 0.11, 0.92, 0.025, 0.05, _mat(WOOD_PALE, WOOD, 3.5, 0.5),
				Vector3(0, y, 0.04), Vector3(0, 0, PI * 0.5))
		BUILDER.tube(n, [Vector3(-0.42, y + 0.035, -0.04),
				Vector3(-0.42, y + 0.075, -0.06), Vector3(0, y + 0.075, -0.065),
				Vector3(0.42, y + 0.075, -0.06), Vector3(0.42, y + 0.035, -0.04)],
				[0.007, 0.008, 0.008, 0.008, 0.007], ottone)
		for k in 3:
			var idx := i * 3 + k
			_bottiglia(n, Vector3(-0.28 + 0.28 * float(k),
					y + 0.025, 0.05 + 0.02 * float((idx * 5) % 2)),
					0.13 + 0.035 * float((idx * 7) % 3), colori[idx])
	return n


static func _tavolino_bar() -> Node3D:
	# IL TAVOLINO DEL BAR: piano di marmo tondo su un piede di ghisa
	# TORNITO — la curva a campana dei bistrot, non tre cilindri
	# impilati — col bordo d'ottone attorno al marmo. Due tazzine col
	# manico e il conto sotto la moneta.
	var n := Node3D.new()
	var ghisa := _mat(Color("4f4a45"), Color("3d3935"), 5.0, 0.4)
	var ottone := _mat(OTTONE, OTTONE_SCURO, 5.0, 0.4)
	var porcellana := _mat(Color.WHITE, CREAM, 6.0, 0.2)
	var piatto := _mat(CREAM, Color("efe4d2"), 6.0, 0.2)
	BUILDER.lathe(n, [Vector2(0.225, 0.0), Vector2(0.235, 0.018),
			Vector2(0.185, 0.045), Vector2(0.105, 0.085), Vector2(0.06, 0.14),
			Vector2(0.042, 0.24), Vector2(0.038, 0.42), Vector2(0.045, 0.56),
			Vector2(0.065, 0.64), Vector2(0.105, 0.695), Vector2(0.115, 0.715)],
			ghisa)
	var piano := _cyl(n, 0.4, 0.4, 0.05, _mat(MARMO, Color("ddd5c6"), 8.0, 0.35),
			Vector3(0, 0.74, 0))
	piano.name = "Piano"
	var bordo := MeshInstance3D.new()
	var bm := TorusMesh.new()
	bm.inner_radius = 0.385
	bm.outer_radius = 0.412
	bordo.mesh = bm
	bordo.material_override = ottone
	bordo.position = Vector3(0, 0.737, 0)
	n.add_child(bordo)
	# due tazzine col piattino e il manico: un tavolino da bar non è mai
	# per uno solo
	for dx: float in [-0.14, 0.15]:
		_cyl(n, 0.05, 0.038, 0.012, piatto, Vector3(dx, 0.771, 0.02))
		_cyl(n, 0.028, 0.022, 0.038, porcellana, Vector3(dx, 0.795, 0.02))
		_cyl(n, 0.021, 0.021, 0.006, _mat(CAFFE, Color("52351f"), 5.0, 0.4),
				Vector3(dx, 0.811, 0.02))
		var manico := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.008
		tm.outer_radius = 0.017
		manico.mesh = tm
		manico.material_override = porcellana
		manico.position = Vector3(dx + 0.028 * signf(dx), 0.797, 0.02)
		manico.rotation.x = PI * 0.5
		n.add_child(manico)
	# il conto, fermato da una moneta
	var conto := _box(n, Vector3(0.08, 0.004, 0.06), piatto,
			Vector3(0.02, 0.767, -0.16))
	conto.rotation.y = 0.18
	_cyl(n, 0.016, 0.016, 0.006, ottone, Vector3(0.03, 0.772, -0.17))
	return n


static func _sedia_vimini() -> Node3D:
	# LA SEDIA DI VIMINI: quella del dehors, alla maniera delle Thonet —
	# gambe tornite un filo svasate, la seduta intrecciata col bordo a
	# giunco, e lo schienale AD ARCO: un tubo piegato a vapore, non due
	# paletti con le assi.
	var n := Node3D.new()
	var telaio := _mat(WOOD_PALE, WOOD, 4.0, 0.5)
	var intreccio := _mat(Color("e0c08c"), Color("c9a670"), 9.0, 0.6)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			# la CIMA della gamba rientra sotto la seduta, il piede si
			# allarga: è la svasatura giusta — al contrario, le cime
			# sbucavano oltre il bordo e la sedia era smontata a mezz'aria
			var g := _cyl(n, 0.016, 0.022, 0.45, telaio,
					Vector3(sx * 0.15, 0.22, sz * 0.15))
			g.rotation.x = -sz * 0.09
			g.rotation.z = sx * 0.09
	_cyl(n, 0.21, 0.21, 0.035, intreccio, Vector3(0, 0.45, 0))
	var giunco := MeshInstance3D.new()
	var gm := TorusMesh.new()
	gm.inner_radius = 0.195
	gm.outer_radius = 0.225
	giunco.mesh = gm
	giunco.material_override = telaio
	giunco.position = Vector3(0, 0.455, 0)
	n.add_child(giunco)
	# lo schienale: l'arco piegato a vapore ANCORATO dentro la seduta,
	# l'archetto interno idem, e le canne che li congiungono davvero
	BUILDER.tube(n, [Vector3(-0.15, 0.43, 0.14), Vector3(-0.17, 0.72, 0.20),
			Vector3(-0.115, 0.90, 0.235), Vector3(0, 0.945, 0.245),
			Vector3(0.115, 0.90, 0.235), Vector3(0.17, 0.72, 0.20),
			Vector3(0.15, 0.43, 0.14)],
			[0.018, 0.017, 0.016, 0.016, 0.016, 0.017, 0.018], telaio)
	BUILDER.tube(n, [Vector3(-0.125, 0.44, 0.15), Vector3(-0.10, 0.60, 0.20),
			Vector3(0, 0.65, 0.212), Vector3(0.10, 0.60, 0.20),
			Vector3(0.125, 0.44, 0.15)],
			[0.011, 0.011, 0.011, 0.011, 0.011], telaio)
	return n


## UNA RIGA SCRITTA COL GESSO. Il segreto perché sembri scrittura e non
## una barra di caricamento è tutto qui: PAROLE separate da spazi, di
## lunghezze diverse, spessori diversi, appena storte e appena disallineate
## in verticale, e il margine destro SFRANGIATO. Allineate a sinistra:
## nessuno scrive centrando le righe su una lavagnetta.
## `x0` è il margine da cui si comincia a scrivere COME SI VEDE, e le
## parole marciano verso la x locale NEGATIVA: la faccia scritta guarda
## verso -Z (convenzione del catalogo), e chi la guarda ha la x locale
## positiva alla propria destra. Impaginare verso +x metteva le righe
## specchiate — col prezzo a sinistra e il margine sfrangiato a destra.
## Ritorna la x dove la riga è finita, così chi vuole ci mette il prezzo.
static func _riga_gesso(parent: Node3D, mat: Material, x0: float, y: float,
		parole: Array, z: float, alt: float, rng: RandomNumberGenerator) -> float:
	var x := x0
	for w in parole:
		var lung := float(w)
		var s := _box(parent, Vector3(lung, alt * rng.randf_range(0.85, 1.15), 0.008),
				mat, Vector3(x - lung * 0.5, y + rng.randf_range(-0.006, 0.006), z))
		s.rotation.z = rng.randf_range(-0.035, 0.035)
		x -= lung + 0.022    # lo spazio fra le parole
	return x + 0.022


static func _lavagnetta() -> Node3D:
	# LA LAVAGNETTA DEI GUSTI: il cavalletto A LIBRO fuori dalla porta, col
	# gesso di oggi. È la lavagna PICCOLA: quella grande del villaggio è
	# un'altra cosa (_blackboard).
	#
	# Rifatta da zero: prima era una tavola su quattro gambe diritte con
	# QUATTRO BARRE BIANCHE identiche, centrate e perfettamente parallele —
	# sembravano barre di caricamento, non una scritta. Una lavagnetta da
	# bar deve dire tre cose a colpo d'occhio: che è un cavalletto a libro
	# (due pannelli incernierati in cima, con la catenella fra le gambe),
	# che qualcuno ci ha SCRITTO a mano (parole di lunghezze diverse,
	# storte, con gli spazi), e che è USATA (l'alone di gesso mezzo
	# cancellato, il gessetto nella bacinella, il cancellino di feltro).
	var n := Node3D.new()
	var legno := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	var legno_chiaro := _mat(WOOD_PALE, WOOD, 3.5, 0.5)
	var ardesia := _mat(Color("2f3a33"), Color("26302a"), 5.5, 0.3)
	var gesso := _mat(Color("fdf6e8"), Color("ece2cf"), 6.0, 0.22)
	# l'alone di ieri è appena più chiaro dell'ardesia, non bianco: un
	# grigio chiaro pieno non è «cancellato», è una toppa
	var gesso_tenue := _mat(Color("55605a"), Color("48524d"), 7.0, 0.35)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260729    # sempre la stessa: due lavagnette non si scrivono da sole in modo diverso

	# --- la cerniera in cima, e i due pannelli che si aprono a libro ---
	var cerniera := Vector3(0, 0.94, 0)
	_cyl(n, 0.02, 0.02, 0.5, legno, cerniera).rotation.z = PI * 0.5
	for lato: float in [-1.0, 1.0]:
		var perno := Node3D.new()
		# l'ANTA è il pannello che si legge: quello che col rotation.x
		# POSITIVO porta il proprio bordo basso verso -Z, cioè verso chi
		# guarda. Chiamare «Anta» l'altro metteva la scritta sul pannello
		# di dietro — perfetta, e invisibile.
		perno.name = "Anta" if lato > 0.0 else "Retro"
		perno.position = cerniera
		perno.rotation.x = lato * 0.24
		n.add_child(perno)
		# il telaio del pannello: quattro liste ad angoli tondi, non una
		# tavola piena
		_lastra(perno, 0.28, 0.05, 0.018, 0.045, legno, Vector3(0, -0.02, 0),
				Vector3(0, PI * 0.5, 0))
		_lastra(perno, 0.28, 0.05, 0.018, 0.045, legno, Vector3(0, -0.86, 0),
				Vector3(0, PI * 0.5, 0))
		for sx: float in [-0.255, 0.255]:
			_lastra(perno, 0.025, 0.86, 0.012, 0.045, legno, Vector3(sx, -0.44, 0),
					Vector3(0, PI * 0.5, 0))
		# le gambe che continuano il telaio sotto, appena svasate
		for sx2: float in [-0.245, 0.245]:
			var g := _box(perno, Vector3(0.05, 0.1, 0.045), legno,
					Vector3(sx2, -0.9, 0))
			g.rotation.z = -sx2 * 0.3
		# l'ardesia incassata, un filo più indietro del telaio
		_box(perno, Vector3(0.47, 0.8, 0.02), ardesia,
				Vector3(0, -0.44, lato * -0.02))
	# LA CATENELLA VA DA UN'ANTA ALL'ALTRA, cioè lungo Z: un cavalletto a
	# libro si apre avanti-indietro, non a destra e a sinistra. Tre pallini
	# in fila sull'asse X restavano appesi in mezzo al vano senza toccare
	# nessuna delle due gambe — tre sassolini a mezz'aria, e di profilo si
	# vedeva solo quello. Alla quota 0.25 le ante stanno a ±0.169 (0.710 di
	# anta per sin 0.24): la catena parte da lì, ci arriva, e si affloscia.
	for i in 7:
		var u := float(i) / 6.0
		_ball(n, 0.013, _mat(METAL, Color("6f665b"), 5.0, 0.35),
				Vector3(0.0, 0.25 - sin(u * PI) * 0.035, lerpf(-0.169, 0.169, u)),
				Vector3(1.0, 0.75, 1.0))

	# --- il fronte scritto. Tutto dentro l'anta, così segue la sua
	# inclinazione: una scritta appesa in verticale davanti a un pannello
	# inclinato «galleggia» e si vede subito ---
	var anta: Node3D = n.get_node(^"Anta")
	var zs := -0.036          # il gesso sta DAVANTI all'ardesia
	# il titolo, più grosso, e la sottolineatura tirata di fretta
	_riga_gesso(anta, gesso, 0.16, -0.13, [0.075, 0.055, 0.05], zs, 0.03, rng)
	var sotto := _box(anta, Vector3(0.215, 0.012, 0.008), gesso,
			Vector3(0.055, -0.175, zs))
	sotto.rotation.z = -0.02
	# tre righe di menù: parole vere, margine destro sfrangiato, e su due
	# righe il prezzo staccato in fondo
	var righe := [[0.062, 0.038, 0.052], [0.045, 0.07], [0.058, 0.034, 0.046]]
	for i in righe.size():
		var y := -0.27 - 0.115 * float(i)
		var fine := _riga_gesso(anta, gesso, 0.2, y, righe[i], zs, 0.019, rng)
		if i != 1:
			# il prezzo, staccato in fondo alla riga
			_riga_gesso(anta, gesso, minf(fine - 0.05, -0.1), y,
					[0.024, 0.02], zs, 0.019, rng)
	# l'ALONE di quello che c'era scritto ieri, mezzo cancellato: è il
	# dettaglio che rende la lavagna usata invece che nuova. Tre macchie
	# sovrapposte e appena storte — una sola era un rettangolo incollato.
	for m in [[0.22, 0.05, -0.02, 0.02], [0.14, 0.038, 0.09, -0.035],
			[0.1, 0.03, -0.11, 0.015]]:
		var macchia := _box(anta, Vector3(float(m[0]), float(m[1]), 0.005),
				gesso_tenue, Vector3(float(m[2]), -0.635, zs + 0.003))
		macchia.rotation.z = float(m[3])
	# il cuore col gesso nell'angolo (a destra di chi guarda = x locale
	# negativa), due palline e una punta
	_ball(anta, 0.018, gesso, Vector3(-0.155, -0.7, zs), Vector3(1, 1, 0.35))
	_ball(anta, 0.018, gesso, Vector3(-0.12, -0.7, zs), Vector3(1, 1, 0.35))
	var punta := _box(anta, Vector3(0.031, 0.031, 0.006), gesso,
			Vector3(-0.1375, -0.727, zs))
	punta.rotation.z = PI * 0.25

	# --- la bacinella dei gessetti, col gessetto e il cancellino ---
	# il fondo va SCURO: su legno chiaro un gessetto bianco non si vede,
	# ed era l'unica cosa che in quella bacinella si deve vedere
	_box(anta, Vector3(0.44, 0.022, 0.055), _mat(WOOD_DARK, Color("5c4030"), 4.0, 0.45),
			Vector3(0, -0.815, -0.045))
	_box(anta, Vector3(0.44, 0.03, 0.012), legno_chiaro, Vector3(0, -0.8, -0.07))
	var gessetto := _cyl(anta, 0.013, 0.013, 0.085, gesso, Vector3(-0.11, -0.793, -0.05))
	gessetto.rotation.z = PI * 0.5
	gessetto.rotation.y = 0.2
	gessetto.name = "Gessetto"
	# un mozzicone rosa, di quelli che restano sempre
	var mozzicone := _cyl(anta, 0.01, 0.01, 0.035, _mat(PINK, PINK_DEEP, 6.0, 0.35),
			Vector3(0.02, -0.795, -0.05))
	mozzicone.rotation.z = PI * 0.5
	var cancellino := _box(anta, Vector3(0.075, 0.028, 0.04),
			_mat(Color("6f665b"), Color("585047"), 5.0, 0.4),
			Vector3(0.145, -0.79, -0.05))
	cancellino.name = "Cancellino"
	_box(anta, Vector3(0.075, 0.014, 0.042), _mat(Color("cfd4c8"), Color("b8bdb0"), 7.0, 0.4),
			Vector3(0.145, -0.803, -0.05))
	# e la lavagnetta non sta mai perfettamente dritta
	n.rotation.y = 0.04
	return n


static func _biliardino() -> Node3D:
	# IL BILIARDINO: la ragione vera per cui ci si ritrova. Le stecche coi
	# omini, i contapunti e la pallina in mezzo al campo.
	var n := Node3D.new()
	var legno := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	var sponda := _mat(BAR_ROSSO, BAR_ROSSO_CUPO, 4.5, 0.45)
	var campo := _mat(Color("6f9c68"), Color("5c8656"), 6.0, 0.5)
	var acciaio := _mat(CROMO, Color("b9bec6"), 7.0, 0.3)
	var ottone := _mat(OTTONE, OTTONE_SCURO, 5.0, 0.3)
	# le quattro gambe tornite, un filo svasate, col piedino d'ottone
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var g := _cyl(n, 0.032, 0.045, 0.72, legno,
					Vector3(sx * 0.4, 0.36, sz * 0.28))
			g.rotation.x = sz * 0.045
			g.rotation.z = -sx * 0.045
			_cyl(n, 0.045, 0.048, 0.035, ottone,
					Vector3(sx * 0.415, 0.018, sz * 0.295))
	# la cassa coi fianchi tondi e il campo verde
	_loft(n, [[-0.49, 0.30, 0.70, 0.86, 0.05],
			[-0.45, 0.33, 0.70, 0.86, 0.03],
			[0.45, 0.33, 0.70, 0.86, 0.03],
			[0.49, 0.30, 0.70, 0.86, 0.05]], legno)
	_box(n, Vector3(0.9, 0.02, 0.58), campo, Vector3(0, 0.865, 0))
	# le sponde: pannelli ad angoli tondi, non assi a coltello
	for sz2: float in [-0.32, 0.32]:
		_lastra(n, 0.49, 0.10, 0.03, 0.04, sponda, Vector3(0, 0.9, sz2),
				Vector3(0, PI * 0.5, 0))
	for sx2: float in [-0.48, 0.48]:
		_lastra(n, 0.34, 0.10, 0.03, 0.04, sponda, Vector3(sx2, 0.9, 0))
	# le righe del campo
	_box(n, Vector3(0.012, 0.004, 0.56), _mat(Color("e8efe4"), CREAM, 6.0, 0.2),
			Vector3(0, 0.876, 0))
	var cerchio := _cyl(n, 0.1, 0.1, 0.004, _mat(Color("e8efe4"), CREAM, 6.0, 0.2),
			Vector3(0, 0.874, 0))
	cerchio.scale = Vector3(1, 1, 1)
	# LE STECCHE: devono SPORGERE dai fianchi, o il biliardino sembra un
	# banco da lavoro con dei pupazzetti sopra. Sono lunghe una volta e
	# mezzo il tavolo, e l'impugnatura di legno sta fuori, dove si afferra.
	var squadre := [BAR_ROSSO, Color("6f93b8")]
	for i in 4:
		var x := -0.33 + 0.22 * float(i)
		var stecca := _cyl(n, 0.016, 0.016, 0.95, acciaio, Vector3(x, 0.95, 0))
		stecca.rotation.x = PI * 0.5
		stecca.name = "Stecca%d" % i
		# l'impugnatura da un lato solo, alternata come nei biliardini
		# veri — la stecca sporge quanto serve alla presa, non il doppio
		var lato := -1.0 if i % 2 == 0 else 1.0
		_cyl(n, 0.034, 0.034, 0.18, _mat(WOOD_DARK, Color("5c4030"), 4.0, 0.4),
				Vector3(x, 0.95, lato * 0.52)).rotation.x = PI * 0.5
		_ball(n, 0.038, _mat(WOOD_DARK, Color("5c4030"), 4.0, 0.4),
				Vector3(x, 0.95, lato * 0.63))
		# due omini per stecca, appesi SOTTO la stecca, con la testa tonda
		var col: Color = squadre[i % 2]
		var panno := _mat(col, col.darkened(0.2), 4.0, 0.4)
		for k in 2:
			var z := -0.15 + 0.3 * float(k)
			# il corpo è un torace bombato, non un mattoncino
			_ball(n, 0.046, panno, Vector3(x, 0.895, z), Vector3(0.7, 1.35, 0.6))
			# le gambette aperte, che è come stanno gli omini veri
			for lg: float in [-1.0, 1.0]:
				var gamba := _cyl(n, 0.011, 0.013, 0.075, panno,
						Vector3(x + lg * 0.028, 0.815, z))
				gamba.rotation.z = lg * 0.3
			_ball(n, 0.034, _mat(CREAM, Color("efe4d2"), 5.0, 0.3),
					Vector3(x, 0.985, z))
	# la pallina e i contapunti
	_ball(n, 0.022, _mat(Color("f2ead6"), CREAM, 5.0, 0.25), Vector3(0.06, 0.895, 0.08))
	for lato2: float in [-1.0, 1.0]:
		for k2 in 5:
			_ball(n, 0.016, _mat(OTTONE, OTTONE_SCURO, 5.0, 0.3),
					Vector3(-0.34 + 0.04 * float(k2), 0.965, lato2 * 0.33))
		var filo := _cyl(n, 0.004, 0.004, 0.3, acciaio,
				Vector3(-0.28, 0.965, lato2 * 0.33))
		filo.rotation.z = PI * 0.5
	return n


## LA FALDA TORNITA FRA DUE ANGOLI: la stessa superficie di rivoluzione
## del lathe, ma solo da a0 ad a1 — è ciò che rende possibili gli
## SPICCHI bicolori veri di un ombrellone: due mesh alternate sullo
## stesso profilo, senza costole che sbucano e senza fasce dipinte.
## A due facce: un ombrellone si guarda soprattutto da sotto.
static func _lathe_spicchio(parent: Node3D, profilo: Array, mat: Material,
		a0: float, a1: float, passi := 6) -> MeshInstance3D:
	var np := profilo.size()
	var n2: Array[Vector2] = []
	for i in np:
		var d: Vector2 = ((profilo[mini(i + 1, np - 1)] as Vector2)
				- (profilo[maxi(i - 1, 0)] as Vector2)).normalized()
		n2.append(Vector2(d.y, -d.x).normalized())
	var punto := func(i: int, j: int) -> Vector3:
		var a := lerpf(a0, a1, float(j) / float(passi))
		var p: Vector2 = profilo[i]
		return Vector3(cos(a) * p.x, p.y, -sin(a) * p.x)
	var norma := func(i: int, j: int) -> Vector3:
		var a := lerpf(a0, a1, float(j) / float(passi))
		return Vector3(cos(a) * n2[i].x, n2[i].y, -sin(a) * n2[i].x).normalized()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in np - 1:
		for j in passi:
			var q := [punto.call(i, j), punto.call(i + 1, j),
					punto.call(i + 1, j + 1), punto.call(i, j + 1)]
			var qn := [norma.call(i, j), norma.call(i + 1, j),
					norma.call(i + 1, j + 1), norma.call(i, j + 1)]
			for k in [0, 1, 2, 0, 2, 3]:
				st.set_normal(qn[k])
				st.add_vertex(q[k])
			for k in [0, 2, 1, 0, 3, 2]:
				st.set_normal(-(qn[k] as Vector3))
				st.add_vertex(q[k])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	parent.add_child(mi)
	return mi


static func _ombrellone() -> Node3D:
	# L'OMBRELLONE: GRANDE, che l'ombra deve coprire due tavolini e mezzo
	# pomeriggio. Dodici spicchi bicolori VERI sulla stessa curva di tela,
	# le stecche di legno sotto la falda, il colletto che le raccoglie sul
	# palo, la frangia a onde che segue i colori, e in cima il pomello
	# tornito con la puntina d'ottone.
	var n := Node3D.new()
	var legno := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	var telo_a := _mat(CREAM, Color("f0e4cc"), 5.0, 0.35)
	var telo_b := _mat(BAR_ROSSO, BAR_ROSSO_CUPO, 4.5, 0.4)
	# la base di pietra tornita, col collare di legno che ferma il palo
	BUILDER.lathe(n, [Vector2(0.33, 0.0), Vector2(0.34, 0.025),
			Vector2(0.295, 0.06), Vector2(0.175, 0.10), Vector2(0.07, 0.13)],
			_mat(STONE, STONE_DARK, 4.0, 0.5))
	_cyl(n, 0.052, 0.058, 0.05, legno, Vector3(0, 0.15, 0))
	_cyl(n, 0.035, 0.045, 2.25, legno, Vector3(0, 1.125, 0))
	var cupola := Node3D.new()
	cupola.name = "Cupola"
	cupola.position = Vector3(0, 2.12, 0)
	n.add_child(cupola)
	# la tela: un'unica curva che si incurva scendendo, percorsa a
	# spicchi alternati panna e rosso
	var tela: Array = [Vector2(1.0, -0.30), Vector2(0.985, -0.268),
			Vector2(0.92, -0.185), Vector2(0.80, -0.09), Vector2(0.63, 0.0),
			Vector2(0.44, 0.075), Vector2(0.24, 0.13), Vector2(0.06, 0.165)]
	for s in 12:
		var a0 := TAU / 12.0 * float(s)
		_lathe_spicchio(cupola, tela, telo_a if s % 2 == 0 else telo_b,
				a0, a0 + TAU / 12.0)
	# le stecche sotto la tela, una per cucitura, raccolte dal mozzo
	for s2 in 12:
		var a := TAU / 12.0 * float(s2)
		var giro := Basis(Vector3.UP, -a)
		var punti: Array = []
		for p in [Vector2(0.10, 0.135), Vector2(0.44, 0.058),
				Vector2(0.80, -0.107), Vector2(0.975, -0.30)]:
			punti.append(giro * Vector3((p as Vector2).x, (p as Vector2).y, 0))
		BUILDER.tube(cupola, punti, [0.013, 0.012, 0.011, 0.009], legno, 14, 8)
	_cyl(cupola, 0.055, 0.075, 0.075, legno, Vector3(0, 0.115, 0))
	# il pomello tornito in cima, con la puntina d'ottone
	BUILDER.lathe(cupola, [Vector2(0.035, 0.16), Vector2(0.052, 0.185),
			Vector2(0.048, 0.215), Vector2(0.028, 0.245), Vector2(0.012, 0.27),
			Vector2(0.0, 0.28)], legno)
	_ball(cupola, 0.014, _mat(OTTONE, OTTONE_SCURO, 5.0, 0.4),
			Vector3(0, 0.285, 0))
	# la frangia a onde sul bordo, un dente per mezzo spicchio, del
	# colore del suo spicchio
	for i in 24:
		var a2 := TAU / 24.0 * (float(i) + 0.5)
		var dente := _ball(cupola, 0.056,
				telo_a if (i >> 1) % 2 == 0 else telo_b,
				Vector3(cos(a2) * 0.985, -0.318, -sin(a2) * 0.985),
				Vector3(1.0, 0.5, 0.42))
		dente.rotation.y = a2 + PI * 0.5
	return n


static func _fioriera() -> Node3D:
	# LA FIORIERA DEL DEHORS: la cassetta di legno che delimita i tavolini
	# dalla strada. Fiori dentro, e un filo d'edera che scende.
	var n := Node3D.new()
	var legno := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	var doghe := _mat(WOOD_PALE, WOOD, 3.5, 0.5)
	# la cassa: quattro montanti torniti con il pomello, le doghe ad
	# angoli tondi COI VUOTI in mezzo (una cassetta di doghe senza
	# fessure è un blocco dipinto), e la vasca scura dentro
	_box(n, Vector3(0.88, 0.38, 0.28), legno, Vector3(0, 0.21, 0))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_cyl(n, 0.032, 0.036, 0.46, legno,
					Vector3(sx * 0.455, 0.23, sz * 0.155))
			_ball(n, 0.036, legno, Vector3(sx * 0.455, 0.47, sz * 0.155))
	for i in 3:
		var y := 0.10 + 0.13 * float(i)
		for sz2: float in [-1.0, 1.0]:
			_lastra(n, 0.42, 0.095, 0.022, 0.032, doghe,
					Vector3(0, y, sz2 * 0.175), Vector3(0, PI * 0.5, 0))
		for sx2: float in [-1.0, 1.0]:
			_lastra(n, 0.145, 0.095, 0.022, 0.032, doghe,
					Vector3(sx2 * 0.46, y, 0))
	_loft(n, [[-0.46, 0.185, 0.415, 0.455, 0.015],
			[0.46, 0.185, 0.415, 0.455, 0.015]], doghe)
	# la terra e i fiori
	_box(n, Vector3(0.84, 0.06, 0.28), _mat(Color("6b5340"), Color("57432f"), 5.0, 0.5),
			Vector3(0, 0.44, 0))
	var verde := _mat(LEAF, LEAF_DARK, 6.0, 0.55)
	var petali := [PINK, Color("ffd76e"), Color("cdbff0"), Color("f6c39c")]
	for i in 6:
		var x := -0.36 + 0.145 * float(i)
		var z := -0.06 + 0.09 * float(i % 3)
		_cyl(n, 0.012, 0.016, 0.2, verde, Vector3(x, 0.56, z))
		_ball(n, 0.05, verde, Vector3(x + 0.03, 0.52, z), Vector3(1.2, 0.5, 1.0))
		var c: Color = petali[i % petali.size()]
		for k in 5:
			var a := PI * 2.0 / 5.0 * float(k)
			_ball(n, 0.026, _mat(c, c.darkened(0.15), 5.0, 0.4),
					Vector3(x + cos(a) * 0.03, 0.66, z + sin(a) * 0.03),
					Vector3(1.0, 0.6, 1.0))
		_ball(n, 0.018, _mat(Color("ffd76e"), Color("eec254"), 5.0, 0.3),
				Vector3(x, 0.668, z))
	# il filo d'edera che scende dal bordo (il commento lo prometteva da
	# sempre, ma nessuno l'aveva mai piantato)
	BUILDER.tube(n, [Vector3(0.30, 0.46, -0.14), Vector3(0.37, 0.40, -0.19),
			Vector3(0.42, 0.30, -0.21), Vector3(0.43, 0.19, -0.19),
			Vector3(0.41, 0.10, -0.16)],
			[0.012, 0.011, 0.009, 0.008, 0.006], verde)
	for f in 5:
		var t := float(f) / 4.0
		var fp := Vector3(lerpf(0.31, 0.42, t), lerpf(0.45, 0.11, t),
				lerpf(-0.15, -0.17, t) - sin(t * PI) * 0.045)
		var foglia := _ball(n, 0.032, verde, fp, Vector3(1.0, 0.35, 0.75))
		foglia.rotation.y = t * 2.2
		foglia.rotation.z = 0.3 - t * 0.5
	return n


static func _lucine() -> Node3D:
	# LE LUCINE: il filo di lampadine fra due paletti, quello che accende
	# il dehors la sera e fa sembrare festa una sera qualunque.
	var n := Node3D.new()
	var legno := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	for sx: float in [-0.46, 0.46]:
		_cyl(n, 0.03, 0.04, 1.9, legno, Vector3(sx, 0.95, 0))
		_ball(n, 0.04, legno, Vector3(sx, 1.9, 0))
	# il filo: una catenaria VERA, un tubo continuo che pende — non una
	# spezzata di bastoncini — con le lampadine appese
	var filo := _mat(Color("4f4a45"), Color("3d3935"), 4.0, 0.3)
	var colori := [Color("ffd08a"), Color("ffb0a0"), Color("bfe0ff"),
			Color("ffe6a8"), Color("d8c0f0")]
	var corda: Array = []
	var raggi: Array = []
	for i in 7:
		var t := float(i) / 6.0
		corda.append(Vector3(lerpf(-0.46, 0.46, t), 1.88 - 0.26 * sin(t * PI), 0))
		raggi.append(0.006)
	BUILDER.tube(n, corda, raggi, filo, 30, 8)
	var passi := 9
	for i in passi:
		# le due lampadine d'estremità finivano DENTRO i paletti: restano
		# gli attacchi sul filo, le lampadine vivono fra i pali, non nei pali
		if i == 0 or i == passi - 1:
			continue
		var t0 := float(i) / float(passi - 1)
		var xl := lerpf(-0.46, 0.46, t0)
		var yl := 1.88 - 0.26 * sin(t0 * PI)
		var c: Color = colori[i % colori.size()]
		_cyl(n, 0.012, 0.016, 0.02, _mat(OTTONE, OTTONE_SCURO, 5.0, 0.3),
				Vector3(xl, yl - 0.025, 0))
		var bulbo := _ball(n, 0.032, _glow(c, c, 1.1), Vector3(xl, yl - 0.062, 0),
				Vector3(1.0, 1.25, 1.0))
		bulbo.name = "Bulbo%d" % i
	var luce := OmniLight3D.new()
	luce.light_color = Color(1.0, 0.88, 0.72)
	luce.light_energy = 0.9
	luce.omni_range = 4.2
	luce.position = Vector3(0, 1.7, 0)
	n.add_child(luce)
	return n


static func _frigo_gelati() -> Node3D:
	# IL FRIGO DEI GELATI: il pozzetto col coperchio a strisce e il cartello
	# col cono. D'estate ci si appoggiano i gomiti aspettando il proprio.
	var n := Node3D.new()
	var bianco := _mat(SEGNALE_BIANCO, Color("e6dfd0"), 5.0, 0.3)
	var rosso := _mat(BAR_ROSSO, BAR_ROSSO_CUPO, 4.5, 0.45)
	var cromo := _mat(CROMO, Color("b9bec6"), 7.0, 0.3)
	# il pozzetto bombato sugli angoli, sul basamento cromato stondato
	_loft(n, [[-0.47, 0.22, 0.08, 0.65, 0.09],
			[-0.43, 0.25, 0.08, 0.65, 0.045],
			[0.43, 0.25, 0.08, 0.65, 0.045],
			[0.47, 0.22, 0.08, 0.65, 0.09]], bianco)
	_loft(n, [[-0.48, 0.235, 0.015, 0.09, 0.035],
			[-0.44, 0.26, 0.015, 0.09, 0.02],
			[0.44, 0.26, 0.015, 0.09, 0.02],
			[0.48, 0.235, 0.015, 0.09, 0.035]], cromo)
	# la fascia a strisce, pannellini ad angoli tondi
	for i in 5:
		_lastra(n, 0.075, 0.16, 0.025, 0.025, rosso if i % 2 == 0 else bianco,
				Vector3(-0.34 + 0.17 * float(i), 0.5, -0.253), Vector3(0, PI * 0.5, 0))
	# i due coperchi scorrevoli a bordo tondo, col maniglione ad arco
	for lato: float in [-1.0, 1.0]:
		var cop := _lastra(n, 0.23, 0.44, 0.03, 0.05, cromo,
				Vector3(lato * 0.24, 0.675, lato * 0.02), Vector3(0, 0, PI * 0.5))
		cop.name = "Coperchio%d" % int(lato)
		BUILDER.tube(n, [Vector3(lato * 0.24 - 0.08, 0.70, lato * 0.02 - 0.19),
				Vector3(lato * 0.24, 0.735, lato * 0.02 - 0.20),
				Vector3(lato * 0.24 + 0.08, 0.70, lato * 0.02 - 0.19)],
				[0.011, 0.012, 0.011], _mat(ZINCO_CUPO, Color("7d838b"), 5.0, 0.3))
	# il cartello col cono: targa tonda in cornice rossa, sul palo
	var palo := _cyl(n, 0.014, 0.014, 0.34, cromo, Vector3(0.36, 0.82, 0.12))
	palo.rotation.z = 0.06
	var cartello := _lastra(n, 0.145, 0.32, 0.06, 0.02, rosso,
			Vector3(0.37, 1.06, 0.12), Vector3(0, PI * 0.5, 0))
	cartello.name = "Cartello"
	_lastra(n, 0.125, 0.28, 0.05, 0.02, bianco,
			Vector3(0.37, 1.06, 0.114), Vector3(0, PI * 0.5, 0))
	var cialda := _cyl(n, 0.07, 0.012, 0.15, _mat(Color("e8bd78"), Color("d4a45e"), 6.0, 0.45),
			Vector3(0.37, 1.0, 0.098))
	cialda.rotation.z = 0.1
	_ball(n, 0.044, _mat(PINK, PINK_DEEP, 5.0, 0.4), Vector3(0.35, 1.10, 0.095))
	_ball(n, 0.041, _mat(CREAM, Color("f0e4cc"), 5.0, 0.35), Vector3(0.395, 1.125, 0.095))
	_ball(n, 0.014, _mat(BAR_ROSSO, BAR_ROSSO_CUPO, 5.0, 0.35),
			Vector3(0.40, 1.16, 0.093))
	return n


static func _tenda_bar() -> Node3D:
	# LA TENDA: la falda a strisce sopra la porta, con la frangia ondulata.
	# Sta sul bordo di una cella, come un muro.
	var n := Node3D.new()
	var metallo := _mat(METAL, Color("6f665b"), 5.0, 0.4)
	# i due bracci: ferro battuto che curva, non squadrette
	for sx: float in [-0.44, 0.44]:
		BUILDER.tube(n, [Vector3(sx, 2.32, 0.04), Vector3(sx, 2.28, -0.06),
				Vector3(sx, 2.16, -0.24), Vector3(sx, 2.03, -0.42),
				Vector3(sx, 1.985, -0.47)],
				[0.018, 0.017, 0.016, 0.015, 0.014], metallo)
		BUILDER.tube(n, [Vector3(sx, 2.30, 0.02), Vector3(sx, 2.16, -0.02),
				Vector3(sx, 2.04, 0.02)],
				[0.012, 0.012, 0.012], metallo)
	var barra := _cyl(n, 0.022, 0.022, 0.96, metallo, Vector3(0, 2.3, 0.02))
	barra.rotation.z = PI * 0.5
	# la falda a strisce, inclinata, che SI INSACCA fra la barra e il
	# bordo: ogni striscia è una tela incurvata (la stessa falda del
	# vetro curvo, con la stoffa al posto del vetro), non un'asse rigida
	var falda := Node3D.new()
	falda.name = "Falda"
	falda.position = Vector3(0, 2.06, -0.26)
	falda.rotation.x = -0.42
	n.add_child(falda)
	var bianco := _mat(CREAM, Color("f0e4cc"), 5.0, 0.3)
	var rosso := _mat(BAR_ROSSO, BAR_ROSSO_CUPO, 4.5, 0.4)
	var sagoma: Array = [Vector2(0.31, 0.015), Vector2(0.155, -0.012),
			Vector2(0.0, -0.026), Vector2(-0.155, -0.012), Vector2(-0.31, 0.015)]
	for i in 6:
		var x0 := -0.4915 + 0.163 * float(i)
		_vetro_curvo(falda, x0, x0 + 0.163, sagoma,
				rosso if i % 2 == 0 else bianco)
	# la frangia a onde sul bordo davanti: scende SOTTO l'orlo — mezza
	# affondata nel telo sembrava un rotolo di salsicce
	for i in 6:
		var dente := _ball(falda, 0.068, rosso if i % 2 == 0 else bianco,
				Vector3(-0.41 + 0.163 * float(i), -0.028, -0.312),
				Vector3(1.0, 0.5, 0.4))
		dente.name = "Dente%d" % i
	return n


static func _insegna_bar() -> Node3D:
	# L'INSEGNA DEL BAR: la tazzina d'ottone su fondo crema, appesa al
	# braccio di ferro battuto. Si vede da tutta la piazza.
	var n := Node3D.new()
	var ferro := _mat(Color("4f4a45"), Color("3d3935"), 5.0, 0.4)
	var ottone := _mat(OTTONE, OTTONE_SCURO, 5.0, 0.4)
	# la piastra al muro e il braccio di ferro battuto: un tubo che
	# curva, col RICCIOLO vero avvolto sotto — non tre palline in fila
	_lastra(n, 0.05, 0.30, 0.02, 0.04, ferro, Vector3(-0.41, 2.0, 0),
			Vector3(0, PI * 0.5, 0))
	BUILDER.tube(n, [Vector3(-0.40, 2.02, 0), Vector3(-0.40, 2.10, 0),
			Vector3(-0.32, 2.13, 0), Vector3(-0.05, 2.138, 0),
			Vector3(0.34, 2.128, 0)],
			[0.019, 0.019, 0.018, 0.016, 0.014], ferro)
	BUILDER.tube(n, [Vector3(-0.33, 2.115, 0), Vector3(-0.24, 2.05, 0),
			Vector3(-0.285, 2.005, 0), Vector3(-0.33, 2.035, 0),
			Vector3(-0.305, 2.075, 0)],
			[0.011, 0.010, 0.009, 0.008, 0.007], ferro)
	var appesa := Node3D.new()
	appesa.name = "Insegna"
	# LE ASTINE DEVONO STARE DENTRO LA CAMPATA DEL BRACCIO, che va da −0.41
	# a +0.21: appese a ±0.18 attorno a x 0.10, la destra usciva a 0.28 e
	# restava agganciata al niente. Un tirante che non tira è la cosa più
	# facile da non vedere e la più impossibile da spiegare.
	appesa.position = Vector3(-0.06, 2.1, 0)
	n.add_child(appesa)
	# gli anelli AVVOLGONO il braccio (asse lungo il braccio, centro sul
	# suo asse: un anello posato sotto è un'insegna che levita), e i
	# tiranti scendono dagli anelli alla targa
	for dx: float in [-0.16, 0.16]:
		var anello := MeshInstance3D.new()
		var am := TorusMesh.new()
		am.inner_radius = 0.019
		am.outer_radius = 0.031
		anello.mesh = am
		anello.material_override = ottone
		anello.position = Vector3(dx, 0.033, 0)
		anello.rotation.z = PI * 0.5
		appesa.add_child(anello)
		_cyl(appesa, 0.006, 0.006, 0.13, ottone, Vector3(dx, -0.048, 0))
	_lastra(appesa, 0.29, 0.42, 0.06, 0.035, ottone, Vector3(0, -0.32, 0),
			Vector3(0, PI * 0.5, 0))
	_lastra(appesa, 0.265, 0.375, 0.05, 0.04, _mat(CREAM, Color("f0e4cc"), 5.0, 0.3),
			Vector3(0, -0.32, 0), Vector3(0, PI * 0.5, 0))
	# la tazzina dipinta — corpo svasato, piattino, manico ad anello — e
	# il vapore che sale storto come il vapore vero
	_cyl(appesa, 0.085, 0.062, 0.1, ottone, Vector3(-0.02, -0.33, -0.032))
	_cyl(appesa, 0.105, 0.085, 0.015, ottone, Vector3(-0.02, -0.395, -0.032))
	var manico := MeshInstance3D.new()
	var mm := TorusMesh.new()
	mm.inner_radius = 0.018
	mm.outer_radius = 0.036
	manico.mesh = mm
	manico.material_override = ottone
	manico.position = Vector3(0.075, -0.325, -0.032)
	manico.rotation.x = PI * 0.5
	appesa.add_child(manico)
	for i in 3:
		_ball(appesa, 0.014, ottone,
				Vector3(-0.02 + sin(float(i) * 1.5) * 0.03, -0.24 + 0.045 * float(i), -0.032),
				Vector3(1, 1, 0.4))
	return n
