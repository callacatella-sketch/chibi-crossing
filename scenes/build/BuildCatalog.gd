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
## La fisica della corda: la posa di riposo dei fili che POI, nel mondo,
## CordeVive.gd fa muovere davvero (vento, inerzia, la mano che li tocca).
const FISICA := preload("res://scenes/world/CordaFisica.gd")

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

# --- i due fuochi del catalogo ------------------------------------------
# L'energia di un fuoco vive in UN posto solo, perché ne esistono sempre
# DUE copie: il valore a riposo e i fotogrammi del tremolio. Scritti a
# mano, la prima ritaratura ne cambia uno e lascia l'altro — e la fiamma
# si accende al valore vecchio a ogni giro dell'animazione, senza un
# errore. I fotogrammi qui sotto sono FRAZIONI di queste due costanti.
const CAMINO_ENERGIA := 1.9
## ATTENZIONE, il braciere è il caso che ha smentito lo studio. Al buio
## del provino (pavimento blu-grigio, albedo bassa) 4.6 sembrava giusta;
## posato nel villaggio VERO, sulla sabbia chiara, bruciava un cerchio
## bianco largo sei metri. Una sorgente a 0.72 m sbatte sul terreno da
## vicino, e un lampione a 2.1 m no: la stessa energia non vuol dire la
## stessa pozza. Scelta guardando le foto nel mondo, non nello studio.
const BRACE_ENERGIA := 2.8


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
			"cols": [[Vector3(0.9, 0.12, 2.95), Vector3(0, 1.08, 0.46), 0.8425]]},
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
			# due scatole: il letto, e la TESTIERA — che arriva a 0.77, e
			# con la sola prima (alta 0.55) la si attraversava a piedi
			"cols": [[Vector3(0.96, 0.55, 0.98), Vector3(0, 0.27, 0)],
					[Vector3(0.96, 0.34, 0.10), Vector3(0, 0.55, 0.445)]]},
		{"name": "Libreria", "cat": 1, "type": "cell", "layer": 2, "builder": _bookshelf,
			"cols": [[Vector3(0.9, 1.55, 0.32), Vector3(0, 0.77, 0)]]},
		{"name": "Comodino", "cat": 1, "type": "cell", "layer": 2, "builder": _nightstand,
			"cols": [[Vector3(0.46, 0.55, 0.42), Vector3(0, 0.27, 0)]]},
		{"name": "Camino", "cat": 1, "type": "cell", "layer": 2, "builder": _fireplace,
			"cols": [[Vector3(0.92, 1.1, 0.42), Vector3(0, 0.55, 0)]]},
		{"name": "Lampada", "cat": 1, "type": "cell", "layer": 2, "builder": _lamp,
			"cols": [[Vector3(0.2, 1.75, 0.2), Vector3(0, 0.87, 0)]]},
		{"name": "Lampada semplice", "cat": 1, "type": "cell", "layer": 2,
			"builder": _lamp_liscia,
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
			"cols": [[Vector3(0.34, 0.62, 0.34), Vector3(0, 0.31, 0)]]},
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
			"cols": [[Vector3(0.96, 0.88, 0.46), Vector3(0, 0.44, 0)]]},
		{"name": "Lavagna", "cat": 2, "type": "cell", "layer": 2, "builder": _blackboard,
			"cols": [[Vector3(1.07, 1.72, 0.54), Vector3(0, 0.86, 0.05)]]},

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
			# due scatole, ricavate dall'ingombro MISURATO (x +-0.35,
			# y 0..1.024, z -0.562..0.323): la botte sullo zoccolo, e la
			# conca che sporge sul davanti a 62 cm — dentro cui non si
			# deve poter camminare
			"cols": [[Vector3(0.70, 1.04, 0.62), Vector3(0, 0.52, 0.02)],
					[Vector3(0.40, 0.22, 0.30), Vector3(0, 0.62, -0.42)]]},
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
			# ricavata dall'ingombro MISURATO (x +-0.541, y 0..0.919,
			# z +-0.274): la vecchia era 0.4 di profondita' e la tela le
			# usciva da tutte e due le parti
			"cols": [[Vector3(1.06, 0.94, 0.58), Vector3(0, 0.47, 0)]]},
		{"name": "Altalena", "cat": 2, "type": "cell", "layer": 2, "builder": _swing,
			"cols": [[Vector3(1.1, 1.65, 0.14), Vector3(0, 0.82, 0)],
					[Vector3(0.14, 1.6, 0.74), Vector3(-0.48, 0.8, 0)],
					[Vector3(0.14, 1.6, 0.74), Vector3(0.48, 0.8, 0)]]},
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
		# la giostra è GRANDE e gira: la pedana è bloccata (è un mezzo in
		# movimento, ci si sale dai Posti sulle selle, non a piedi)
		{"name": "Giostrina", "cat": 2, "type": "cell", "layer": 2, "builder": _carousel,
			"cols": [[Vector3(2.0, 0.32, 2.0), Vector3(0, 0.16, 0)],
					[Vector3(0.18, 2.4, 0.18), Vector3(0, 1.2, 0)]]},
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
			"cols": [[Vector3(2.0, 1.9, 0.12), Vector3(0, 0.95, 0.95)],
					[Vector3(0.12, 1.9, 2.0), Vector3(-0.95, 0.95, 0)],
					[Vector3(0.12, 1.9, 2.0), Vector3(0.95, 0.95, 0)],
					[Vector3(0.64, 1.9, 0.12), Vector3(-0.68, 0.95, -0.95)],
					[Vector3(0.64, 1.9, 0.12), Vector3(0.68, 0.95, -0.95)],
					[Vector3(0.8, 0.42, 0.12), Vector3(0, 1.76, -0.95)],
					[Vector3(0.5, 1.0, 1.6), Vector3(0.70, 0.5, 0.1)],
					[Vector3(0.5, 0.62, 1.6), Vector3(-0.70, 0.31, 0.1)]]},
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
		# il basamento e' largo e ci si inciampa: e' una collisione sua,
		# separata dal fusto (un cilindro solo lasciava camminare dentro
		# i gradini di pietra)
		{"name": "Lanterna blu", "cat": 2, "type": "cell", "layer": 2,
			"builder": _lanterna_blu,
			"cols": [[Vector3(0.56, 0.26, 0.56), Vector3(0, 0.13, 0)],
					[Vector3(0.2, 2.0, 0.2), Vector3(0, 1.0, 0)]]},
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
			"cols": [[Vector3(2.0, 2.24, 0.16), Vector3(0, 1.12, 0)]]},
		# La torretta è VISITABILE come la casa sull'albero: il traliccio
		# blocca, lo spiazzo è un pavimento calpestabile e la scaletta è
		# una rampa. Tetto alto: il chibi più alto (la volpina, orecchie
		# comprese) fa un metro e sessanta, e lassù non deve chinarsi.
		{"name": "Torretta", "cat": 0, "type": "cell", "layer": 2, "builder": _torretta,
			"cols": [[Vector3(0.95, 1.8, 0.95), Vector3(0, 0.9, 0)],
					[Vector3(1.3, 0.1, 1.3), Vector3(0, 1.87, 0)],
					[Vector3(0.62, 0.1, 2.1), Vector3(0, 1.0, -0.9), -1.33]]},
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
			"cols": [[Vector3(0.34, 1.62, 0.34), Vector3(0, 0.81, 0)]]},
		{"name": "Cuccia", "cat": 2, "type": "cell", "layer": 2, "builder": _cuccia_caserma,
			"cols": [[Vector3(0.76, 0.78, 0.74), Vector3(0, 0.39, 0.02)]]},
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
		# LE SORELLE DELLA FIORIERA. Quattro modi di tenere dei fiori, e
		# quattro caratteri diversi: la cassetta del dehors (sopra), il
		# cesto di vimini, la cassa laccata da bistrot, la rustica che
		# nessuno pota. Stessa cella, stesso mestiere, tre silhouette che
		# non si confondono da lontano — che è l'unico modo perché avere
		# quattro fioriere valga più che averne una.
		{"name": "Cesto fiorito", "cat": 2, "type": "cell", "layer": 2,
			"builder": _cesto_fiorito,
			"cols": [[Vector3(0.98, 0.46, 0.46), Vector3(0, 0.23, 0)]]},
		{"name": "Lucine", "cat": 2, "type": "cell", "layer": 2, "builder": _lucine,
			"cols": [[Vector3(0.14, 2.0, 0.14), Vector3(-0.46, 1.0, 0)],
					[Vector3(0.14, 2.0, 0.14), Vector3(0.46, 1.0, 0.06)]]},
		# I TRE PALI del festone. Da soli non fanno niente: il filo nasce
		# quando due pali si vedono (vedi la grammatica sopra _palo_festone
		# e BuildSystem.ricostruisci_festoni). Sono tre pezzi e non uno con
		# le varianti perché la veste dev'essere VISIBILE sullo scaffale e
		# nel fantasma: ognuno porta appeso il suo campione.
		{"name": "Palo lucine", "cat": 2, "type": "cell", "layer": 2,
			"builder": _palo_lucine,
			"cols": [[Vector3(0.14, 2.0, 0.14), Vector3(0, 1.0, 0)]]},
		{"name": "Palo lanterne", "cat": 2, "type": "cell", "layer": 2,
			"builder": _palo_lanterne,
			"cols": [[Vector3(0.14, 2.0, 0.14), Vector3(0, 1.0, 0)]]},
		{"name": "Palo bandierine", "cat": 2, "type": "cell", "layer": 2,
			"builder": _palo_bandierine,
			"cols": [[Vector3(0.14, 2.0, 0.14), Vector3(0, 1.0, 0)]]},
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

# IL PAVIMENTO DI CASA. Non e' il palco: quello e' un tavolato rustico da
# esterno (larghezze diverse, fughe larghe, chiodi in vista, travetti);
# questo e' un pavimento POSATO — assi a larghezza uniforme come le fa
# la piallatrice, giunti di testa sfalsati in ogni fila (la posa a
# corrersi dei pavimenti veri), fughe strette col buio dentro, e i
# TASSELLI di legno al posto dei chiodi: in casa le teste di ferro non
# si lasciano in vista. Prima era una scatola con due righe scure
# dipinte sopra: un pavimento senza fughe e' linoleum.
static func _floor_tile() -> Node3D:
	var n := Node3D.new()
	var miele := _mat(WOOD_PALE, WOOD, 4.0, 0.5)
	var ambra := _mat(Color("d9ae7e"), Color("b98d5c"), 4.5, 0.5)
	var noce := _mat(Color("c79b6c"), Color("a67c4e"), 4.2, 0.5)
	var scuro := _mat(Color("6b563f"), Color("52412f"), 4.0, 0.3)
	var mats := [miele, ambra, miele, noce]

	# il buio sotto le fughe: una lastra magra che si vede SOLO dentro
	# le righe, mai dal bordo (dal bordo il fianco e' tutto legno)
	_box(n, Vector3(0.996, 0.012, 0.996), scuro, Vector3(0, 0.006, 0))

	# otto file di assi uguali (larghezza da piallatrice), giunti di
	# testa sfalsati riga per riga, micro-ribassi da niente (in casa il
	# pavimento e' in bolla: il piano resta 0.05)
	var righe := [
		[[-0.16], 0, 0.0], [[0.21], 1, -0.0008],
		[[-0.35, 0.30], 2, -0.0004], [[0.06], 3, 0.0],
		[[-0.24, 0.36], 1, -0.0006], [[0.14], 0, 0.0],
		[[-0.06], 3, -0.0008], [[0.27, -0.31], 1, -0.0004],
	]
	var wa := 0.1225
	var zc := -0.5
	for r in righe.size():
		var giunti: Array = (righe[r][0] as Array).duplicate()
		giunti.sort()
		var alto := 0.05 + float(righe[r][2])
		var z := zc + wa * 0.5
		zc += wa + 0.0028
		# i confini delle tavole della fila: bordi cella + giunti
		var tagli: Array = [-0.5]
		tagli.append_array(giunti)
		tagli.append(0.5)
		for b in tagli.size() - 1:
			var x0 := float(tagli[b]) + (0.001 if b > 0 else 0.0)
			var x1 := float(tagli[b + 1]) - (0.001 if b < tagli.size() - 2 else 0.0)
			var mat: Material = mats[(int(righe[r][1]) + b) % mats.size()]
			var tavola := _prisma(n, _rrect_xz(x1 - x0, wa, 0.008), 0.0, alto, mat)
			tavola.position = Vector3((x0 + x1) * 0.5, 0.0, z)
		# i tasselli: due per giunto, tono piu' scuro, a filo del legno
		for g in giunti:
			for dxg: float in [-0.024, 0.024]:
				_cyl(n, 0.0058, 0.0058, 0.0016, scuro,
						Vector3(float(g) + dxg, alto + 0.0004, z))
	# un nodo solo, piccolo: e' un pavimento scelto, non un bancale
	_ball(n, 0.006, scuro, Vector3(0.185, 0.0502, -0.315),
			Vector3(1.0, 0.12, 0.7))
	return n


static func _path_tile() -> Node3D:
	return sentiero_cella({}, 20_260_803)


## IL SENTIERO DI PIETRA, cella per cella — e le celle SI PARLANO.
##
## Da solo è una posa di lastre irregolari; ma quando il giocatore ne
## mette due o più vicine, le pietre TENDONO verso i vicini e la fila
## diventa un sentiero vero: BuildSystem.rinfresca_sentieri richiama
## questa funzione con la mappa dei vicini a ogni posa e a ogni
## rimozione (stesso patto della Gradinata coi braccioli).
##
## LE PIETRE NON SONO CILINDRI: cerchi perfetti schiacciati leggono
## «frittelle», non pietra. Ogni lastra è un poligono irregolare a due
## piani — la base più larga, il coperchio rientrato: lo smusso consumato
## di una pietra calpestata — con la sua tinta, il suo giro e la sua
## quota, tutti dal seme della cella (due celle vicine non sono mai la
## stessa cella, ma la STESSA cella è sempre uguale a sé: le foto e i
## salvataggi non ballano).
##
## IL PATTO DEL CONFINE: la pietra a cavallo del bordo la mette UNA sola
## delle due celle — chi guarda il vicino in direzione POSITIVA (est,
## sud). L'altra arriva col suo passo interno fin quasi al bordo e la
## passata è continua senza che due pietre si contendano lo stesso punto
## (due prismi sovrapposti alla stessa quota sono z-fighting garantito).
static func sentiero_cella(vicini: Dictionary, seme: int) -> Node3D:
	var n := Node3D.new()
	var pietre := Node3D.new()
	pietre.name = "Pietre"
	n.add_child(pietre)
	var rng := RandomNumberGenerator.new()
	rng.seed = seme
	# quattro tinte con un vero SCARTO fra loro: a tinte quasi uguali le
	# lastre diventavano un'unica colata chiara — è il contrasto fra
	# pietra e pietra a dire «posate una a una»
	var tinte: Array = [
		_mat(STONE, STONE_DARK, 3.0, 0.5),
		_mat(Color("d8d0c2"), STONE, 3.5, 0.5),
		_mat(Color("a89f90"), Color("857c6e"), 3.0, 0.5),
		_mat(Color("c2b2a4"), Color("9c8b7c"), 3.5, 0.5),
	]

	# la posa di casa: una lastra grande scostata dal centro e due
	# compagne — mai in fila, mai alla stessa quota
	_lastra_sentiero(pietre, rng, tinte, Vector2(
			rng.randf_range(-0.10, 0.10), rng.randf_range(-0.08, 0.08)), 0.21)
	_lastra_sentiero(pietre, rng, tinte, Vector2(
			rng.randf_range(0.22, 0.30), rng.randf_range(-0.32, -0.22)), 0.13)
	_lastra_sentiero(pietre, rng, tinte, Vector2(
			rng.randf_range(-0.32, -0.24), rng.randf_range(0.20, 0.30)), 0.115)

	# i passi verso i vicini. `dir` è in coordinate MONDO: ci pensa il
	# rinfresco a compensare la rotazione del pezzo.
	var direzioni := {"e": Vector2(1, 0), "o": Vector2(-1, 0),
			"s": Vector2(0, 1), "n": Vector2(0, -1)}
	for nome in direzioni:
		if not bool(vicini.get(nome, false)):
			continue
		var dir: Vector2 = direzioni[nome]
		var fianco := Vector2(-dir.y, dir.x)
		# il passo interno, un filo fuori asse: un sentiero posato a mano
		# non è mai una retta
		_lastra_sentiero(pietre, rng, tinte,
				dir * rng.randf_range(0.26, 0.30)
				+ fianco * rng.randf_range(-0.07, 0.07), 0.125)
		# la pietra DEL CONFINE, solo verso est e sud: a cavallo del
		# bordo, così le due celle la condividono senza doppiarla
		if nome == "e" or nome == "s":
			_lastra_sentiero(pietre, rng, tinte,
					dir * 0.5 + fianco * rng.randf_range(-0.05, 0.05), 0.135)

	# i sassolini nelle fughe, e un ciuffetto d'erba che vince — la firma
	# del sagrato: sono le fughe a dire che le lastre sono POSATE
	for _i in 3:
		var a := rng.randf_range(0.0, TAU)
		var r := rng.randf_range(0.30, 0.44)
		_ball(pietre, rng.randf_range(0.014, 0.022), tinte[rng.randi_range(0, 3)],
				Vector3(cos(a) * r, 0.020, sin(a) * r),
				Vector3(1.0, rng.randf_range(0.5, 0.65), rng.randf_range(0.8, 1.2)))
	var erba := _mat(LEAF, LEAF_DARK, 6.0, 0.55)
	var ae := rng.randf_range(0.0, TAU)
	var ce := _cyl(pietre, 0.0, 0.026, 0.06, erba,
			Vector3(cos(ae) * 0.38, 0.045, sin(ae) * 0.38))
	ce.rotation.z = rng.randf_range(-0.25, 0.25)
	return n


## Una lastra del sentiero: poligono irregolare a DUE piani (base più
## larga, coperchio rientrato = lo smusso consumato), tinta e quota sue.
static func _lastra_sentiero(parent: Node3D, rng: RandomNumberGenerator,
		tinte: Array, centro: Vector2, raggio: float) -> void:
	var mat: Material = tinte[rng.randi_range(0, tinte.size() - 1)]
	var giro := rng.randf_range(0.0, TAU)
	var lati := rng.randi_range(7, 9)
	var raggi: Array = []
	for i in lati:
		raggi.append(raggio * rng.randf_range(0.78, 1.12))
	var alto := rng.randf_range(0.034, 0.052)
	var lastra := Node3D.new()
	lastra.position = Vector3(centro.x, 0, centro.y)
	# appena storta nel terreno: una lastra in bolla è una piastrella
	lastra.rotation.x = rng.randf_range(-0.025, 0.025)
	lastra.rotation.z = rng.randf_range(-0.025, 0.025)
	parent.add_child(lastra)
	for piano in 2:
		var scala := 1.0 if piano == 0 else rng.randf_range(0.80, 0.88)
		var da := 0.0 if piano == 0 else alto * 0.55
		var spess := alto * 0.55 if piano == 0 else alto * 0.45
		var punti: Array = []
		for i in lati:
			var a := giro + TAU * float(i) / float(lati)
			punti.append(Vector2(cos(a), sin(a)) * (float(raggi[i]) * scala))
		_prisma(lastra, punti, da, spess, mat)


## IL TAPPETO INTRECCIATO — il tappeto delle case cozy per eccellenza:
## la spirale di trecce di stoffa cucite in tondo, ovale come vengono
## davvero (una spirale tirata a mano non chiude mai un cerchio).
##
## Prima erano due cilindri concentrici: un piattino, non un tappeto. La
## differenza la fanno quattro cose, tutte piccole:
##  · le SPIRE: sei anelli di treccia (tori schiacciati) a colori
##    alternati, ognuno col suo appoggio — un'inclinazione di qualche
##    millesimo e una quota sua: la stoffa si adagia, non si stampa;
##  · i PUNTI DELLA TRECCIA: i nodini obliqui in rilievo sulle spire —
##    sono loro a dire «intrecciato» invece di «verniciato a righe»;
##  · il CAPO FINALE: la treccia non sparisce — l'ultimo capo esce dalla
##    spira più esterna, si adagia sul pavimento e finisce cucito con
##    due punti. È la firma di ogni tappeto a spirale vero;
##  · l'OVALE: tutto è scalato 1.06 × 0.94 — il cerchio perfetto è da
##    negozio, l'ovale è di casa.
##
## Le varianti di colore continuano a funzionare: ogni spira ha il suo
## ShaderMaterial e apply_variant le tinge tutte conservando gli scarti.
static func _rug() -> Node3D:
	var n := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20_260_804
	# crema e rosa che si alternano, e UN solo accento miele verso il
	# cuore: con due gialli il tappeto diventava un bersaglio da caramella
	var tinte: Array = [
		_mat(CREAM, Color("f3dfc8"), 8.0, 0.35),
		_mat(PINK, PINK_DEEP, 8.0, 0.35),
		_mat(CREAM, Color("f3dfc8"), 8.0, 0.35),
		_mat(Color("f0d29a"), Color("ddb977"), 8.0, 0.35),
		_mat(PINK, PINK_DEEP, 8.0, 0.35),
		_mat(CREAM, Color("f3dfc8"), 8.0, 0.35),
	]
	var tubo := 0.034
	var fondo := 0.052          # il tappeto POSA sul pavimento, non ci galleggia
	for i in 6:
		var r := 0.435 - float(i) * 0.063
		# il wrapper porta l'appoggio (tilt e quota); la scala ovale sta
		# sulla SOLA mesh, o distorcerebbe anche i punti della treccia
		var spira := Node3D.new()
		# l'appoggio: millesimi, non centesimi — a ±0.01 rad le spire
		# esterne si alzavano di 4 mm e fra gli anelli si aprivano
		# fessure d'ombra, come un giocattolo smontato
		spira.position = Vector3(0, fondo + tubo * 0.52 + rng.randf_range(0.0, 0.0015), 0)
		spira.rotation.x = rng.randf_range(-0.005, 0.005)
		spira.rotation.z = rng.randf_range(-0.005, 0.005)
		n.add_child(spira)
		var toro := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = r - tubo
		tm.outer_radius = r + tubo
		toro.mesh = tm
		toro.material_override = tinte[i]
		toro.scale = Vector3(1.06, 0.52, 0.94)
		spira.add_child(toro)
		# i punti della treccia, obliqui, sulle spire alterne
		if i % 2 == 0:
			# tono su tono, APPENA più scuro: il punto della treccia è una
			# trama, non un forellino — a contrasto pieno le spire crema
			# sembravano punteggiate dalle tarme
			var scuro: ShaderMaterial = (tinte[i] as ShaderMaterial).duplicate()
			scuro.set_shader_parameter("color_a",
					(scuro.get_shader_parameter("color_a") as Color).darkened(0.06))
			scuro.set_shader_parameter("color_b",
					(scuro.get_shader_parameter("color_b") as Color).darkened(0.06))
			var quanti := int(TAU * r / 0.085)
			for k in quanti:
				var a := TAU * float(k) / float(quanti) + rng.randf_range(-0.02, 0.02)
				var nodo := Node3D.new()
				nodo.position = Vector3(cos(a) * r * 1.06, tubo * 0.30,
						sin(a) * r * 0.94)
				nodo.rotation.y = -a
				# il giro obliquo attorno alla tangente: è la diagonale
				# della treccia, sempre nello stesso verso — una treccia
				# cambia colore, mai verso
				nodo.rotation.x = 0.6
				spira.add_child(nodo)
				_box(nodo, Vector3(0.006, 0.008, tubo * 1.25), scuro, Vector3.ZERO)
	# il cuore della spirale: quieto, rosa — l'accento resta uno solo
	_cyl(n, 0.098 * 1.06, 0.098 * 1.06, 0.030, tinte[1],
			Vector3(0, fondo + 0.015, 0)).scale.z = 0.89
	# IL CAPO FINALE: l'ultima treccia esce dalla spira esterna, si adagia
	# e finisce cucita con due punti. La firma del tappeto vero.
	var a0 := 0.42
	var fuori: Array = []
	var raggi_capo: Array = []
	for k2 in 5:
		var u := float(k2) / 4.0
		var rr := (0.435 + u * 0.055)
		var ang := a0 + u * 0.5
		fuori.append(Vector3(cos(ang) * rr * 1.06,
				fondo + tubo * 0.52 * (1.0 - u * 0.75), sin(ang) * rr * 0.94))
		raggi_capo.append(lerpf(0.030, 0.020, u))
	BUILDER.tube(n, fuori, raggi_capo, tinte[1], 14, 8)
	var filo := _mat(Color("b9a781"), Color("9d8b66"), 6.0, 0.3)
	for k3 in 2:
		var p: Vector3 = fuori[3 - k3]
		var punto := _box(n, Vector3(0.005, 0.006, 0.030), filo,
				p + Vector3(0, 0.012, 0))
		punto.rotation.y = -(a0 + float(3 - k3) / 4.0 * 0.5) + 0.5
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


## LA PORTA DEL COTTAGE. Parla la stessa lingua del Muro e della Finestra —
## zoccolo di pietra, battiscopa, graticcio coi cavicchi, trave di colmo col
## coprigiunto — così la casa corre ininterrotta da un pezzo all'altro. E
## l'anta è una porta VERA da bottega: doghe verticali coi giunti, due
## traverse e la CONTROVENTATURA diagonale (è la diagonale che toglie il
## «squadrato»: una porta a Z si legge costruita, non disegnata), bandelle
## di ferro coi bulloni sul lato dei cardini, pomello d'ottone con la
## bocchetta della serratura, e la finestrella a quattro vetri in alto.
##
## CONTRATTO CON BuildSystem: l'anta vive nel nodo «Hinge» a (-0.34, 0, 0)
## e riempie il varco 0.68 × 1.56 — è lui che la apre al passaggio, col
## cigolio. Non cambiare nome né perno.
static func _door_wall() -> Node3D:
	var n := Node3D.new()
	var plaster := _mat(PLASTER, PLASTER_SHADE, 2.5, 0.5)
	var wood := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	var wood_scuro := _mat(WOOD_DARK, Color("8a6540"), 3.5, 0.5)
	var stone := _mat(STONE, STONE_DARK, 3.0, 0.55)
	var ferro := _mat(Color("4a443c"), Color("332f29"), 5.0, 0.4)
	var ottone := _mat(OTTONE, OTTONE_SCURO, 6.0, 0.35)
	var crema := _mat(CREAM, Color("ecdcc4"), 3.5, 0.4)

	# ---- LA SOGLIA: la pietra su cui si entra, consumata al centro, e i
	# due monconi di zoccolo ai lati (lo zoccolo del Muro si interrompe
	# dove si passa — è una porta, non un davanzale)
	_box(n, Vector3(0.78, 0.05, 0.26), stone, Vector3(0, 0.025, 0))
	for sz0: float in [-1.0, 1.0]:
		_box(n, Vector3(0.16, 0.09, 0.22), stone, Vector3(sz0 * 0.42, 0.045, 0))
		_box(n, Vector3(0.16, 0.07, 0.19), wood, Vector3(sz0 * 0.42, 0.125, 0))
	# lo zerbino di paglia intrecciata sul fronte, col suo bordo
	_box(n, Vector3(0.36, 0.014, 0.20), _mat(Color("c9a86a"), Color("b08e52"), 2.0, 0.4),
			Vector3(0, 0.007, -0.24))
	_box(n, Vector3(0.38, 0.010, 0.22), _mat(Color("a8874c"), Color("8f7040"), 2.0, 0.4),
			Vector3(0, 0.004, -0.24))

	# ---- I FIANCHI: intonaco sottile (0.13) fra i legni in rilievo, come
	# nel Muro — e i montanti del graticcio sui bordi del pezzo
	for side: float in [-1.0, 1.0]:
		_box(n, Vector3(0.16, 1.40, 0.13), plaster, Vector3(side * 0.42, 0.86, 0))
	_box(n, Vector3(1.0, 0.44, 0.13), plaster, Vector3(0, 1.78, 0))
	for sx: float in [-1.0, 1.0]:
		_box(n, Vector3(0.09, 1.84, 0.17), wood, Vector3(sx * 0.435, 1.08, 0))

	# ---- GLI STIPITI e la traversa del graticcio che fa da architrave
	# (quota 1.61, la stessa linea che attraversa Muro e Finestra), coi
	# cavicchi ai giunti. Sopra la porta, il GOCCIOLATOIO: la mensolina
	# inclinata che butta fuori la pioggia — è il dettaglio che dice che
	# questa casa vive sotto un cielo vero.
	for side2: float in [-1.0, 1.0]:
		_box(n, Vector3(0.08, 1.56, 0.16), wood, Vector3(side2 * 0.38, 0.78, 0))
	_box(n, Vector3(1.0, 0.10, 0.17), wood, Vector3(0, 1.61, 0))
	for sx2: float in [-1.0, 1.0]:
		var cav := _cyl(n, 0.013, 0.013, 0.19, wood_scuro, Vector3(sx2 * 0.435, 1.61, 0))
		cav.rotation.x = PI * 0.5
	# il gocciolatoio POGGIA sul muro e due mensoline lo reggono: la prima
	# stesura lo lasciava a mezz'aria, una stecca inclinata che galleggiava
	var goccia := _box(n, Vector3(0.80, 0.028, 0.13), wood_scuro, Vector3(0, 1.70, -0.045))
	goccia.rotation.x = 0.30
	for gm: float in [-0.32, 0.32]:
		_box(n, Vector3(0.05, 0.06, 0.07), wood_scuro, Vector3(gm, 1.655, -0.075))

	# ---- le mensoline e la trave di colmo col coprigiunto: identiche al
	# Muro, così la corona corre ininterrotta lungo tutta la casa
	for sx3: float in [-1.0, 1.0]:
		_box(n, Vector3(0.07, 0.07, 0.2), wood, Vector3(sx3 * 0.435, 1.965, 0))
	_box(n, Vector3(1.0, 0.08, 0.18), wood, Vector3(0, 2.04, 0))
	_box(n, Vector3(1.0, 0.03, 0.22), wood_scuro, Vector3(0, 2.095, 0))

	# ---- L'ANTA. Chiusa di default; il BuildSystem la apre all'avvicinarsi
	# ruotando il nodo «Hinge» (e Sfx fa il cigolio).
	var hinge := Node3D.new()
	hinge.name = "Hinge"
	hinge.position = Vector3(-0.34, 0, 0)
	n.add_child(hinge)
	var doga := _mat(Color("b3805a"), Color("96683f"), 3.0, 0.55)
	var doga_giunto := _mat(Color("96683f"), Color("7d5634"), 2.5, 0.5)
	# il corpo di doghe verticali: la tavola piena piu' i tre giunti che si
	# leggono da vicino
	_box(hinge, Vector3(0.68, 1.56, 0.045), doga, Vector3(0.34, 0.78, 0))
	for gx: float in [0.17, 0.34, 0.51]:
		_box(hinge, Vector3(0.008, 1.50, 0.052), doga_giunto, Vector3(gx, 0.78, 0))
	# le due traverse e la DIAGONALE: la porta a Z di ogni bottega vera.
	# La diagonale corre dal cardine in basso al pomello in alto: e' cosi'
	# che il peso dell'anta scarica sul perno.
	for ty: float in [0.34, 1.10]:
		_box(hinge, Vector3(0.58, 0.075, 0.022), doga_giunto, Vector3(0.34, ty, -0.032))
	var diag := _box(hinge, Vector3(0.075, 0.86, 0.022), doga_giunto,
			Vector3(0.34, 0.72, -0.032))
	diag.rotation.z = -0.60
	# le bandelle di ferro dei cardini, coi bulloni: escono dal perno e
	# attraversano le doghe
	for by: float in [0.30, 1.18]:
		_box(hinge, Vector3(0.30, 0.05, 0.014), ferro, Vector3(0.17, by, -0.036))
		_box(hinge, Vector3(0.05, 0.09, 0.012), ferro, Vector3(0.035, by, -0.038))
		for bx: float in [0.10, 0.20, 0.28]:
			_ball(hinge, 0.011, ferro, Vector3(bx, by, -0.045), Vector3(1, 1, 0.5))
	# il perno vero e proprio, in vista
	for py: float in [0.30, 1.18]:
		_cyl(hinge, 0.016, 0.016, 0.14, ferro, Vector3(0.008, py, 0))
	# il pomello d'ottone con la rosetta, su TUTTE E DUE le facce, e la
	# bocchetta della serratura sotto
	for pz: float in [-0.045, 0.045]:
		_cyl(hinge, 0.030, 0.030, 0.008, ottone, Vector3(0.60, 0.82, pz))
		_ball(hinge, 0.026, ottone, Vector3(0.60, 0.82, pz * 1.35))
	_box(hinge, Vector3(0.026, 0.05, 0.008), ottone, Vector3(0.60, 0.72, -0.028))
	_ball(hinge, 0.007, ferro, Vector3(0.60, 0.735, -0.034))
	# la FINESTRELLA a quattro vetri in alto: la cornice crema, il vetro
	# incassato e la croce del telaio. (Vive dentro l'anta, non e' figlia
	# del pezzo: la sera delle PozzeDiLuce appartiene alle Finestre.)
	var wy := 1.38
	for lato_c: Array in [[Vector3(0.26, 0.030, 0.060), Vector3(0.34, wy + 0.115, 0.0)],
			[Vector3(0.26, 0.030, 0.060), Vector3(0.34, wy - 0.115, 0.0)],
			[Vector3(0.030, 0.20, 0.060), Vector3(0.225, wy, 0.0)],
			[Vector3(0.030, 0.20, 0.060), Vector3(0.455, wy, 0.0)]]:
		_box(hinge, lato_c[0], crema, lato_c[1])
	var vetro_p := MeshInstance3D.new()
	var vm := BoxMesh.new()
	vm.size = Vector3(0.20, 0.20, 0.056)
	vetro_p.mesh = vm
	vetro_p.material_override = _vetro()
	vetro_p.position = Vector3(0.34, wy, 0.0)
	hinge.add_child(vetro_p)
	_box(hinge, Vector3(0.014, 0.20, 0.062), crema, Vector3(0.34, wy, 0.0))
	_box(hinge, Vector3(0.20, 0.014, 0.062), crema, Vector3(0.34, wy, 0.0))
	return n


# LA STACCIONATA. Una staccionata di paese e' TONDA — pali torniti col
# collarino e il pomello (la stessa lingua dei montanti della Scala),
# correnti in tondino che si IMBARCANO di due centimetri fra un palo e
# l'altro, legature di corda, l'erba ai piedi dei pali. E i pali hanno
# i NOMI (PaloSx/PaloDx), perche' non sono solo decorazione: quando un
# altro segmento continua la stessa retta, BuildSystem.rinfresca_pali
# spegne il palo sul capo condiviso — il recinto corre continuo, coi
# pali solo dove serve, e le punte dei correnti (a filo del bordo) si
# fondono nel punto della giunta come un nodo di innesto.
static func _fence() -> Node3D:
	var n := Node3D.new()
	var palo_m := _mat(WOOD, WOOD_DARK, 3.8, 0.5)
	var tondo := _mat(WOOD_PALE, WOOD, 3.5, 0.5)
	var scuro := _mat(WOOD_DARK, Color("8a6440"), 4.0, 0.5)
	var corda := _mat(Color("d9c49a"), Color("bfa87e"), 5.0, 0.45)
	var erba := _mat(Color("8aa870"), Color("6f8d58"), 5.0, 0.5)

	for lato in [["PaloSx", -0.40], ["PaloDx", 0.40]]:
		# tutto cio' che appartiene al palo vive DENTRO il suo nodo:
		# collarino, pomello, legature ed erba spariscono con lui
		var palo := Node3D.new()
		palo.name = str(lato[0])
		palo.position.x = float(lato[1])
		n.add_child(palo)
		_cyl(palo, 0.042, 0.055, 0.80, palo_m, Vector3(0, 0.40, 0))
		_cyl(palo, 0.050, 0.050, 0.020, scuro, Vector3(0, 0.815, 0))
		_cyl(palo, 0.024, 0.028, 0.035, palo_m, Vector3(0, 0.843, 0))
		_ball(palo, 0.047, palo_m, Vector3(0, 0.895, 0))
		for h0: float in [0.585, 0.315]:
			var giro := _cyl(palo, 0.040, 0.040, 0.055, corda,
					Vector3(0, h0 - 0.006, 0))
			giro.rotation.z = PI * 0.5
		_ball(palo, 0.055, erba, Vector3(-0.035, 0.018, 0.035),
				Vector3(1.2, 0.45, 0.9))
		_ball(palo, 0.042, erba, Vector3(0.045, 0.014, -0.030),
				Vector3(1.0, 0.40, 0.8))

	# i due correnti: tondini con la PANCIA e le punte tonde A FILO DEL
	# BORDO (±0.5): dove la giunta perde il palo, le punte dei due
	# segmenti si fondono in un nodo d'innesto
	for h: float in [0.585, 0.315]:
		BUILDER.tube(n, [Vector3(-0.5, h, 0.0), Vector3(-0.245, h - 0.016, 0.006),
				Vector3(0.0, h - 0.022, 0.0), Vector3(0.245, h - 0.016, -0.006),
				Vector3(0.5, h, 0.0)],
				[0.030, 0.033, 0.034, 0.033, 0.030], tondo)
		for xt: float in [-0.5, 0.5]:
			_ball(n, 0.030, tondo, Vector3(xt, h, 0))
	return n


## IL TETTO. Era una scatola arancione con tre listelli sopra, e il
## commento diceva «lastra di coppi» — ma di coppi non ce n'era uno: e'
## il caso di scuola della famiglia «la cosa sbagliata», un codice che
## dichiara un'intenzione e non la consegna. E' anche il pezzo piu' visto
## del gioco: sta sopra ogni casa del villaggio.
##
## Tre difetti veri, tutti misurati:
##  1. SI MANGIAVA LA CORONA DEL MURO. La lastra occupava y 2.01-2.11, e
##     la trave di colmo del Muro (2.00-2.08) col suo coprigiunto scuro
##     (2.08-2.11) — i due piani sfalsati che sono il coronamento piu'
##     curato del muro — ci finivano DENTRO. Posavi un tetto e la casa
##     perdeva la sua cornice. Adesso il tavolato POGGIA a 2.11, sopra la
##     trave, che torna a vedersi.
##  2. IL RITMO NON SI AFFIANCAVA. I listelli stavano a z = -0.3 / 0.0 /
##     +0.3 su un passo di cella di 1.0: attraversando il confine la
##     sequenza diventava 0.3, 0.3, 0.4, 0.3, 0.3, 0.4 — l'unico ornamento
##     del pezzo, spaziato male proprio nel pezzo il cui mestiere e'
##     essere affiancato. Adesso TUTTI i passi dividono 1.0: i coppi
##     stanno a x = ±0.5, ±0.3, ±0.1 (quelli sul confine si sovrappongono
##     esatti col vicino e leggono come uno solo) e i corsi a passo 0.25.
##  3. NON ERANO COPPI. Adesso lo sono: canali concavi e coppi convessi
##     sopra i giunti, e ogni coppo e' UN loft che si ingrossa all'inizio
##     di ogni corso e si assottiglia alla fine — e' quello scalino a
##     fare i corsi, non una riga dipinta.
##
## RESTA FUORI la GRONDA vera (20-40 cm di sporto): un tetto e' modulare
## e non puo' sapere da solo dov'e' il bordo del tetto, quindi lo sporto
## va solo sui lati APERTI. Si fa come il Sentiero e la Serra —
## `tetto_cella(vicini)` piu' un `rinfresca_tetti` in BuildSystem — ma
## quel giro tocca anche la cache `_roofs` (la dissolvenza del tetto
## tiene le mesh in un dizionario) e va fatto con calma.
static func _roof_tile() -> Node3D:
	var n := Node3D.new()
	var cotto := _mat(Color("d97e5f"), Color("c26847"), 3.0, 0.55)
	var cotto_cupo := _mat(Color("c26847"), Color("a94f34"), 3.0, 0.5)
	var cotto_vivo := _mat(Color("e08a68"), Color("cb7050"), 3.0, 0.55)
	var legno_sotto := _mat(WOOD_DARK, Color("5c4028"), 4.0, 0.6)

	# la corona del muro finisce a 2.110: il tavolato POGGIA li' sopra
	var y_tav := 2.110
	var y_coppi := y_tav + 0.030

	# ---- IL TAVOLATO: quel che si vede da sotto, e il letto dei coppi ----
	# 1.005 e non 1.0: due tavolati adiacenti si sovrappongono di 2 mm e
	# la fuga non si vede. A 1.0 esatti la giuntura sfarfalla.
	# NIENTE ROTAZIONE: la _lastra e' gia' spessa `sp` lungo X, larga 2w
	# lungo Z e alta `h` lungo Y — cioe' gia' un pavimento. Ruotandola di
	# PI/2 su Z lo spessore (1.005) finiva in verticale e il tavolato
	# diventava un MURO che tagliava il tetto in due.
	_lastra(n, 0.5025, 0.030, 0.010, 1.005, legno_sotto,
			Vector3(0, y_tav + 0.015, 0))

	# ---- I CANALI (i concavi) e i COPPI (i convessi sopra i giunti) ----
	# I passi DIVIDONO la cella: canali a ±0.4, ±0.2, 0 e coppi a ±0.5,
	# ±0.3, ±0.1. Quelli a ±0.5 stanno sul confine e si sovrappongono
	# esatti a quelli della cella accanto: da sopra e' un tetto solo.
	var corsi := 4
	var passo := 1.0 / float(corsi)

	# le stazioni di UN coppo lungo la falda: si ingrossa all'inizio di
	# ogni corso e si assottiglia alla fine — e' lo scalino a fare i corsi
	var stazioni_coppo := func(w: float, alto: float, basso: float,
			raggio: float) -> Array:
		var st: Array = []
		for c in corsi:
			var z0 := -0.5 + passo * float(c)
			st.append([z0, w, -0.008, alto, raggio])
			st.append([z0 + 0.018, w, -0.008, alto * 0.96, raggio])
			st.append([z0 + passo - 0.002, w, -0.008, basso, raggio * 0.9])
		return st

	# i canali: bassi e piu' cupi, e' l'ombra in fondo al canale
	for cx: float in [-0.4, -0.2, 0.0, 0.2, 0.4]:
		var perno := Node3D.new()
		perno.position = Vector3(cx, y_coppi, 0)
		perno.rotation.y = PI * 0.5
		n.add_child(perno)
		_loft(perno, stazioni_coppo.call(0.086, 0.020, 0.014, 0.016),
				cotto_cupo)
	# i coppi: alti e tondi, uno ogni due, e uno stinto ogni tanto —
	# nessun tetto ha tutte le tegole dello stesso colore
	var tinte := [cotto, cotto_vivo, cotto, cotto, cotto_vivo, cotto]
	var i_coppo := 0
	for cx2: float in [-0.5, -0.3, -0.1, 0.1, 0.3, 0.5]:
		var perno2 := Node3D.new()
		perno2.position = Vector3(cx2, y_coppi, 0)
		perno2.rotation.y = PI * 0.5
		n.add_child(perno2)
		_loft(perno2, stazioni_coppo.call(0.062, 0.058, 0.044, 0.052),
				tinte[i_coppo])
		i_coppo += 1

	# la pioggia si ferma sulle tegole: dentro casa non piove
	var pcol := GPUParticlesCollisionBox3D.new()
	pcol.size = Vector3(1.04, 0.13, 1.04)
	pcol.position = Vector3(0, y_tav + 0.065, 0)
	n.add_child(pcol)
	return n


# ---------------------------------------------------------------- arredo

# IL TAVOLINO DI CASA. Prima erano tre cilindri impilati; ora il piede
# e' UN tornito solo — campana, collarino, pancia a vaso, fusto e collo,
# come lo farebbe il tornio — coi tre piedini a cipolla che spuntano
# sotto la campana. Il piano tiene la quota di sempre (0.66) e ha il
# bordo a toro con il gradino d'ombra sotto; sopra NIENTE: il piano di
# un tavolino e' della vita che ci si appoggia.
# (E' un pezzo TINTABILE: tutto legno e stoffa, cosi' la variante menta
# tinge un mobile, non un soprammobile.)
static func _table() -> Node3D:
	var n := Node3D.new()
	var pale := _mat(WOOD_PALE, WOOD, 3.0, 0.5)
	var wood := _mat(WOOD, WOOD_DARK, 4.0, 0.55)
	var scuro := _mat(WOOD_DARK, Color("8a6540"), 4.0, 0.5)

	# il piede tornito, dalla campana al collo, in un profilo solo
	# (le anse si CAMPIONANO come archi: con i soli vertici la lathe
	# tira dritte le corde e la pancia esce a diamante)
	BUILDER.lathe(n, [Vector2(0.235, 0.0), Vector2(0.246, 0.018),
			Vector2(0.215, 0.042), Vector2(0.150, 0.072), Vector2(0.100, 0.102),
			Vector2(0.080, 0.132), Vector2(0.084, 0.150), Vector2(0.086, 0.160),
			Vector2(0.084, 0.170), Vector2(0.070, 0.185), Vector2(0.066, 0.205),
			Vector2(0.076, 0.235), Vector2(0.080, 0.262), Vector2(0.076, 0.290),
			Vector2(0.062, 0.315), Vector2(0.050, 0.340), Vector2(0.042, 0.400),
			Vector2(0.038, 0.470), Vector2(0.040, 0.530), Vector2(0.048, 0.575),
			Vector2(0.058, 0.598), Vector2(0.070, 0.610), Vector2(0.078, 0.615)],
			wood)
	# i tre piedini a cipolla, sotto la campana
	for pi3 in 3:
		var ap := float(pi3) * TAU / 3.0 + 0.5
		_ball(n, 0.036, scuro, Vector3(cos(ap) * 0.165, 0.018, sin(ap) * 0.165),
				Vector3(1.0, 0.55, 1.0))

	# il piano (superficie a 0.66, la quota di sempre), il gradino
	# d'ombra sotto, e il bordo a toro
	_cyl(n, 0.30, 0.30, 0.022, scuro, Vector3(0, 0.607, 0))
	_cyl(n, 0.42, 0.42, 0.045, pale, Vector3(0, 0.6375, 0))
	var bordo := MeshInstance3D.new()
	var bm := TorusMesh.new()
	bm.inner_radius = 0.392
	bm.outer_radius = 0.432
	bordo.mesh = bm
	bordo.material_override = wood
	bordo.position = Vector3(0, 0.643, 0)
	n.add_child(bordo)

	return n


## LA SEDIA, terza vita. La seconda era ancora «forme geometriche a
## caso»: cilindri per gambe, scatole per stecche, palline per fiocchi.
## Questa è TORNITA e IMBOTTITA per davvero:
##  · gambe e montanti escono dal tornio (`lathe`): piede, perlina,
##    collarino e pomello sono UN profilo, non pezzi impilati che
##    cadevano fuori asse;
##  · sedile e cuscino sono superellissoidi (`_soffice`): legno smussato
##    e stoffa gonfia, coi bottoni della trapuntatura SCAVATI nella mesh;
##  · il cappello dello schienale è bombato (`_loft`), le anse dei
##    fiocchi sono nastro vero (cordoli schiacciati), e la cucitura del
##    cuscino è un cordolo continuo.
## Lo schienale sta DIETRO (+Z) e si reclina di `incl`: ogni quota che
## gli appartiene si DERIVA da lì (`zs`), mai scritta a mano.
static func _chair() -> Node3D:
	var n := Node3D.new()
	var legno := _mat(WOOD, WOOD_DARK, 4.0, 0.55)
	var legno_chiaro := _mat(WOOD_PALE, WOOD, 3.5, 0.5)
	var y_sed := 0.44
	var apre := 0.05

	# ---- LE GAMBE: tornite, divaricate a TERRA ----
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var gamba := BUILDER.lathe(n, [Vector2(0.001, 0.0),
					Vector2(0.024, 0.0), Vector2(0.027, 0.010),
					Vector2(0.0225, 0.024), Vector2(0.0205, 0.062),
					Vector2(0.0225, 0.115), Vector2(0.0295, 0.145),
					Vector2(0.0225, 0.175), Vector2(0.020, 0.30),
					Vector2(0.0245, 0.375), Vector2(0.0265, 0.392),
					Vector2(0.0230, 0.408), Vector2(0.020, y_sed),
					Vector2(0.001, y_sed)], legno,
					Vector3(sx * (0.160 + y_sed * apre), 0.0,
							sz * (0.150 + y_sed * apre * 0.8)))
			gamba.rotation.z = sx * apre
			gamba.rotation.x = -sz * apre * 0.8
	# ---- LE TRAVERSE a H, tornite con l'entasi ----
	for sx2: float in [-1.0, 1.0]:
		var tr := BUILDER.lathe(n, [Vector2(0.001, 0.0), Vector2(0.011, 0.004),
				Vector2(0.0150, 0.16), Vector2(0.011, 0.316),
				Vector2(0.001, 0.32)], legno,
				Vector3(sx2 * 0.174, 0.155, -0.16))
		tr.rotation.x = PI * 0.5
	var tm := BUILDER.lathe(n, [Vector2(0.001, 0.0), Vector2(0.010, 0.004),
			Vector2(0.0140, 0.17), Vector2(0.010, 0.336),
			Vector2(0.001, 0.34)], legno, Vector3(-0.17, 0.148, 0))
	tm.rotation.z = -PI * 0.5
	var td := BUILDER.lathe(n, [Vector2(0.001, 0.0), Vector2(0.010, 0.004),
			Vector2(0.0135, 0.17), Vector2(0.010, 0.336),
			Vector2(0.001, 0.34)], legno, Vector3(-0.17, 0.205, -0.160))
	td.rotation.z = -PI * 0.5

	# ---- IL SEDILE: una tavola morbida, non una lastra a coltello ----
	_soffice(n, Vector3(0.46, 0.055, 0.43), legno_chiaro,
			Vector3(0, y_sed + 0.018, 0.004), 0.15, 0.45)

	# ---- LO SCHIENALE, DIETRO (+Z), reclinato di `incl` ----
	var incl := 0.10
	var z_base := 0.185 - 0.2275 * sin(incl)
	var zs := func(y: float) -> float: return z_base + (y - y_sed) * sin(incl)
	for sx3: float in [-1.0, 1.0]:
		var mont := BUILDER.lathe(n, [Vector2(0.001, 0.0), Vector2(0.023, 0.0),
				Vector2(0.021, 0.05), Vector2(0.018, 0.28),
				Vector2(0.021, 0.33), Vector2(0.0235, 0.345),
				Vector2(0.019, 0.362), Vector2(0.013, 0.378),
				Vector2(0.024, 0.398), Vector2(0.0265, 0.414),
				Vector2(0.023, 0.430), Vector2(0.014, 0.448),
				Vector2(0.001, 0.457)], legno,
				Vector3(sx3 * 0.163, y_sed, z_base))
		mont.rotation.x = incl
	# il cappello: bombato al centro, in un perno che pende con lo schienale
	var y_cap := 0.820
	var perno_c := Node3D.new()
	perno_c.position = Vector3(0, y_cap, zs.call(y_cap))
	perno_c.rotation.x = incl
	n.add_child(perno_c)
	var staz: Array = []
	for k in 7:
		var fx := float(k) / 6.0 * 2.0 - 1.0
		staz.append([fx * 0.142, 0.020,
				-0.034 - 0.008 * cos(fx * 1.3), 0.032 + 0.026 * cos(fx * 1.3),
				0.009])
	_loft(perno_c, staz, legno_chiaro)
	# la traversa bassa, bombata anche lei ma piatta
	var y_bas := 0.60
	var perno_b := Node3D.new()
	perno_b.position = Vector3(0, y_bas, zs.call(y_bas))
	perno_b.rotation.x = incl
	n.add_child(perno_b)
	var staz2: Array = []
	for k2 in 5:
		var fx2 := float(k2) / 4.0 * 2.0 - 1.0
		staz2.append([fx2 * 0.176, 0.016, -0.020, 0.020, 0.007])
	_loft(perno_b, staz2, legno)
	# le tre stecche (quella di mezzo più larga) col cuore della famiglia:
	# lo stesso intaglio della testiera del letto — è UNA casa
	var y_st := 0.700
	for k3 in 3:
		var dx := -0.105 + 0.105 * float(k3)
		var perno_s := Node3D.new()
		perno_s.position = Vector3(dx, y_st, zs.call(y_st) - 0.002)
		perno_s.rotation.x = incl
		n.add_child(perno_s)
		var largo := 0.024 if k3 != 1 else 0.052
		_lastra(perno_s, largo, 0.210, 0.014, 0.020, legno, Vector3.ZERO,
				Vector3(0, PI * 0.5, 0))
		if k3 == 1:
			var buio := _mat(Color("5a4028"), Color("42301d"), 4.0, 0.35)
			for lobo: float in [-1.0, 1.0]:
				_ball(perno_s, 0.0135, buio,
						Vector3(lobo * 0.010, 0.028, -0.012), Vector3(1, 1, 0.3))
			var punta := _box(perno_s, Vector3(0.025, 0.025, 0.008), buio,
					Vector3(0, 0.011, -0.012))
			punta.rotation.z = PI * 0.25

	# ---- IL CUSCINO: gonfio, trapuntato, cucito — e LEGATO ----
	var stoffa := _mat(PINK, PINK_DEEP, 5.0, 0.4)
	var scuro := _mat(PINK_DEEP, PINK_DEEP.darkened(0.22), 5.0, 0.35)
	var cusc := Node3D.new()
	cusc.position = Vector3(0, y_sed + 0.066, -0.004)
	cusc.rotation.y = 0.04
	n.add_child(cusc)
	_soffice(cusc, Vector3(0.34, 0.058, 0.31), stoffa, Vector3.ZERO,
			0.35, 0.55, [[0.0, 0.0, 0.050, 0.012],
			[0.082, 0.075, 0.036, 0.008], [-0.082, 0.075, 0.036, 0.008],
			[0.082, -0.075, 0.036, 0.008], [-0.082, -0.075, 0.036, 0.008]])
	_cordolo(cusc, _super_anello(0.168, 0.153, 0.35, 0.0), 0.0055, stoffa)
	# i nastri: la fascia che GIRA intorno al montante, il nodo, le due
	# anse di nastro vero (cordoli schiacciati) e i capi che ricadono
	var y_fio := y_sed + 0.075
	for sx4: float in [-1.0, 1.0]:
		var zf: float = zs.call(y_fio)
		_cordolo(n, _super_anello(0.029, 0.029, 1.0, 0.0, 24), 0.0065, stoffa,
				Vector3(sx4 * 0.163, y_fio, zf))
		var nodo := Node3D.new()
		nodo.position = Vector3(sx4 * 0.168, y_sed + 0.075, zf - 0.030)
		nodo.rotation = Vector3(incl, 0, sx4 * 0.25)
		n.add_child(nodo)
		for ala: float in [-1.0, 1.0]:
			var ansa := _cordolo(nodo, _super_anello(0.017, 0.013, 0.8, 0.0, 20),
					0.0055, stoffa, Vector3(ala * 0.020, 0.004, -0.002))
			ansa.rotation.z = ala * 0.9
			ansa.scale = Vector3(1.0, 0.55, 0.8)
		_ball(nodo, 0.0105, scuro, Vector3(0, 0.0, -0.004))
		for coda: float in [-1.0, 1.0]:
			var capo := _soffice(nodo, Vector3(0.013, 0.044, 0.005), stoffa,
					Vector3(coda * 0.011, -0.028, -0.002), 0.5, 0.6)
			capo.rotation.z = coda * 0.22
	return n


static func _stool() -> Node3D:
	# LO SGABELLO: era un tronco di cono con quattro listelli squadrati
	# che atterravano di punta (gli spigoli galleggiavano sull'ombra) e
	# un disco piatto per cuscino. Adesso è tornito come in bottega: il
	# sedile a bordo tondo, le gambe svasate coi collarini e i piedini,
	# i pioli incrociati a due altezze, e un cuscino GONFIO col bordino
	# in cordoncino e il bottone al centro.
	var n := Node3D.new()
	var legno := _mat(WOOD, WOOD_DARK, 4.0, 0.55)
	var legno_scuro := _mat(WOOD_DARK, WOOD_DARK.darkened(0.22), 4.0, 0.45)
	# ---- il sedile, un profilo di tornio a bordo tondo
	BUILDER.lathe(n, [
		Vector2(0.0, 0.375), Vector2(0.155, 0.375), Vector2(0.185, 0.385),
		Vector2(0.196, 0.404), Vector2(0.186, 0.423), Vector2(0.158, 0.432),
		Vector2(0.0, 0.432),
	], legno, Vector3.ZERO, 26)
	# ---- le quattro gambe tornite, svasate, coi collarini e i piedini
	for i in 4:
		var gamba := Node3D.new()
		gamba.rotation.y = (float(i) + 0.5) / 4.0 * TAU
		n.add_child(gamba)
		var fusto := _cyl(gamba, 0.021, 0.024, 0.39, legno, Vector3(0.135, 0.195, 0))
		fusto.rotation.z = 0.105
		var collare := _cyl(gamba, 0.029, 0.029, 0.022, legno_scuro, Vector3(0.125, 0.295, 0))
		collare.rotation.z = 0.105
		var anello := _cyl(gamba, 0.027, 0.027, 0.014, legno_scuro, Vector3(0.147, 0.085, 0))
		anello.rotation.z = 0.105
		_ball(gamba, 0.027, legno_scuro, Vector3(0.155, 0.014, 0), Vector3(1, 0.6, 1))
	# ---- i pioli incrociati, a due altezze come li fa un falegname
	for i in 4:
		var lato := Node3D.new()
		lato.rotation.y = (float(i) + 1.0) / 4.0 * TAU
		n.add_child(lato)
		var alto := i % 2 == 0
		var piolo := _cyl(lato, 0.011, 0.011, 0.2, legno,
				Vector3(0.101 if alto else 0.097, 0.175 if alto else 0.13, 0))
		piolo.rotation.x = PI * 0.5
	# ---- il cuscino gonfio, col cordoncino e il bottone
	var stoffa := _mat(Color("bfe0c8"), Color("a8ccb2"), 5.0, 0.4)
	var stoffa_cupa := _mat(Color("a8ccb2"), Color("93b89e"), 5.0, 0.4)
	_ball(n, 0.165, stoffa, Vector3(0, 0.455, 0), Vector3(1, 0.31, 1))
	var cordoncino := MeshInstance3D.new()
	var cm := TorusMesh.new()
	cm.inner_radius = 0.148
	cm.outer_radius = 0.176
	cordoncino.mesh = cm
	cordoncino.material_override = stoffa_cupa
	cordoncino.position = Vector3(0, 0.443, 0)
	n.add_child(cordoncino)
	_ball(n, 0.013, stoffa_cupa, Vector3(0, 0.503, 0), Vector3(1, 0.55, 1))
	return n


## IL LETTO, rifatto. Prima erano quattro scatole impilate — un cassone,
## una tavola dritta, una lastra crema e una lastra rosa — e la testiera
## stava a -Z: nella vista frontale del catalogo si vedeva IL RETRO DI UN
## MURO DI LEGNO. Un letto che dà le spalle alla stanza è, di nuovo, un
## pezzo che nessuno ha mai guardato.
##
## Adesso la testiera sta dietro (+Z), dove si appoggia al muro, e il
## letto si legge da davanti come si legge un letto. Quello che lo rende
## vero non è il numero di pezzi ma tre cose:
##
##  · IL PIUMONE NON È UNA LASTRA. È imbottito a RIQUADRI (una griglia di
##    cuscinetti appena bombati con le cuciture in mezzo), ha il RISVOLTO
##    del lenzuolo in cima — la piega bianca che si vede in ogni letto
##    fatto — e CADE sui fianchi con la sua gonna morbida. Una lastra
##    piatta non è una coperta: è un coperchio.
##  · I CUSCINI HANNO LA CONCA. Due guanciali paffuti, appoggiati storti
##    l'uno sull'altro, con l'infossatura di chi ci ha dormito. Un
##    parallelepipedo bianco è un mattone.
##  · IL TELAIO HA LE GAMBE. Quattro piedi torniti e le sponde a giorno:
##    il cassone pieno faceva galleggiare il letto sul pavimento senza
##    un'ombra sotto, e l'ombra sotto un letto è metà del suo peso.
##
## Più il plaid piegato ai piedi, la testiera a doghe col cuoricino
## intagliato, e l'orsetto che qualcuno ha lasciato lì.
static func _bed() -> Node3D:
	var n := Node3D.new()
	var legno := _mat(WOOD, WOOD_DARK, 4.0, 0.55)
	var legno_chiaro := _mat(WOOD_PALE, WOOD, 3.5, 0.5)
	var lenzuolo := _mat(Color("fbf6ec"), Color("e6dccb"), 6.0, 0.3)
	var piumone := _mat(PINK, PINK_DEEP, 5.0, 0.45)

	# ---- IL TELAIO: quattro gambe tornite e le sponde a giorno ----
	var y_rete := 0.20
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var gx := sx * 0.415
			var gz := sz * 0.445
			_cyl(n, 0.035, 0.045, y_rete, legno, Vector3(gx, y_rete * 0.5, gz))
			# il pomello tornito sopra la gamba, dove la sponda si innesta
			_ball(n, 0.042, legno_chiaro, Vector3(gx, y_rete + 0.012, gz),
					Vector3(1, 0.7, 1))
	for sx2: float in [-1.0, 1.0]:
		_box(n, Vector3(0.055, 0.10, 0.90), legno, Vector3(sx2 * 0.415, y_rete - 0.02, 0))
	for sz2: float in [-1.0, 1.0]:
		_box(n, Vector3(0.84, 0.10, 0.055), legno, Vector3(0, y_rete - 0.02, sz2 * 0.445))
	# la pedana ai piedi, più bassa: dà lo scalino che rompe il cassone
	_box(n, Vector3(0.88, 0.075, 0.075), legno_chiaro, Vector3(0, y_rete + 0.045, -0.445))

	# ---- LA TESTIERA, DIETRO (+Z): montanti, doghe e il cuoricino ----
	var y_test := 0.72
	for sx3: float in [-1.0, 1.0]:
		_cyl(n, 0.038, 0.046, y_test, legno, Vector3(sx3 * 0.415, y_test * 0.5, 0.445))
		_ball(n, 0.046, legno_chiaro, Vector3(sx3 * 0.415, y_test + 0.012, 0.445),
				Vector3(1, 0.85, 1))
	# la traversa alta, appena bombata, e quella bassa
	_box(n, Vector3(0.84, 0.085, 0.05), legno_chiaro, Vector3(0, y_test - 0.045, 0.445))
	_box(n, Vector3(0.84, 0.05, 0.05), legno, Vector3(0, 0.40, 0.445))
	# le doghe verticali, una appena più stretta (nessun falegname le fa
	# uguali) e il cuore intagliato in quella di mezzo
	for k in 5:
		var dx := -0.30 + 0.15 * float(k)
		var largo := 0.062 if k != 2 else 0.086
		_box(n, Vector3(largo, 0.28, 0.032), legno, Vector3(dx, 0.545, 0.442))
	for lobo: float in [-1.0, 1.0]:
		_ball(n, 0.026, _mat(WOOD_DARK, Color("6d4f31"), 4.0, 0.4),
				Vector3(lobo * 0.019, 0.585, 0.424), Vector3(1, 1, 0.35))
	var punta := _box(n, Vector3(0.048, 0.048, 0.018),
			_mat(WOOD_DARK, Color("6d4f31"), 4.0, 0.4), Vector3(0, 0.552, 0.424))
	punta.rotation.z = PI * 0.25

	# ---- IL MATERASSO: un superellissoide, non una scatola ----
	# La forma vera di un materasso — fianchi appena bombati, spigoli
	# pieni — con la cucitura come UN cordolo continuo lungo il bordo.
	var y_mat := y_rete + 0.085
	_soffice(n, Vector3(0.84, 0.14, 0.88), lenzuolo, Vector3(0, y_mat, 0),
			0.28, 0.42)
	var cucitura := _mat(Color("efe7d8"), Color("d6ccb8"), 6.0, 0.3)
	_cordolo(n, _super_anello(0.408, 0.428, 0.28, 0.0), 0.0075, cucitura,
			Vector3(0, y_mat + 0.052, 0))
	_cordolo(n, _super_anello(0.408, 0.428, 0.28, 0.0), 0.0075, cucitura,
			Vector3(0, y_mat - 0.052, 0))

	# ---- IL PIUMONE: una tela sola, trapuntata, che CADE ----
	# Prima era una griglia di palline sopra una scatola, con la gonna a
	# salsicciotti: adesso i riquadri sono bombature della superficie e i
	# fianchi girano e cadono con le onde nell'orlo (vedi _trapunta).
	var y_piu := y_mat + 0.058
	var z_da := -0.44
	var z_a := 0.20                    # sotto i cuscini
	_trapunta(n, 0.435, z_da, z_a, y_piu, 0.055, 3, 4, 0.030,
			0.105, 0.068, piumone, 20_260_808)

	# IL RISVOLTO: la piega bianca del lenzuolo, morbida anche lei
	var risv := _soffice(n, Vector3(0.87, 0.045, 0.17), lenzuolo,
			Vector3(0, y_piu + 0.055, z_a - 0.02), 0.30, 0.5)
	risv.rotation.x = -0.13

	# ---- I CUSCINI: in piedi contro la testiera ----
	# Superellissoidi paffuti con la conca scavata NELLA mesh (`conche`)
	# e la cucitura della federa come cordolo sull'equatore. Appoggiati
	# IN PIEDI contro la testiera, come quando si rifà il letto:
	# sdraiati, visti di profilo, leggevano come asciugamani piegati.
	for i in 2:
		var cus := Node3D.new()
		# la quota z si RICAVA dalla testiera, che finisce a 0.470: a 0.335
		# i guanciali arrivavano a 0.5025 e sbucavano 3,2 cm DIETRO il
		# letto — invisibile di fronte, evidente girandoci intorno
		cus.position = Vector3(-0.18 + 0.36 * float(i), y_mat + 0.155,
				0.276 + 0.012 * float(i))
		cus.rotation.x = 0.55 + 0.05 * float(i)
		cus.rotation.y = (0.10 if i == 0 else -0.07)
		cus.rotation.z = (-0.05 if i == 0 else 0.06)
		n.add_child(cus)
		var federa := _mat(Color("fdfaf3"), Color("e9e0d0"), 7.0, 0.28)
		if i == 1:
			federa = _mat(Color("f7f0e4"), Color("e0d5c2"), 7.0, 0.28)
		_soffice(cus, Vector3(0.37, 0.125, 0.26), federa, Vector3.ZERO,
				0.45, 0.66, [[0.01, -0.005, 0.10, 0.028]])
		_cordolo(cus, _super_anello(0.182, 0.127, 0.45, 0.0), 0.005, federa)

	# ---- IL PLAID: una coperta stesa ai piedi, che RICADE ----
	# Tre falde impilate leggevano come vassoi: un plaid vero è UNA
	# coperta stesa di traverso che pende dai fianchi più giù del
	# piumone — due stoffe che cadono una sopra l'altra, ed è la
	# sovrapposizione a dire «qualcuno l'ha buttata lì».
	var plaid := _mat(Color("9db894"), Color("7e9a76"), 6.0, 0.45)
	_trapunta(n, 0.448, -0.442, -0.235, 0.402, 0.026, 1, 1, 0.010,
			0.135, 0.075, plaid, 20_260_809)
	var rotolo := _cyl(n, 0.017, 0.017, 0.86, plaid, Vector3(0, 0.425, -0.237))
	rotolo.rotation.z = PI * 0.5

	# ---- L'ORSETTO che qualcuno ha lasciato lì ----
	var orso := Node3D.new()
	orso.position = Vector3(0.28, y_piu + 0.096, -0.04)
	orso.rotation.y = 2.65
	orso.rotation.z = 0.22
	n.add_child(orso)
	var pelo := _mat(Color("cbab84"), Color("a98a66"), 7.0, 0.5)
	_ball(orso, 0.058, pelo, Vector3.ZERO, Vector3(1.0, 0.85, 0.9))
	_ball(orso, 0.045, pelo, Vector3(0, 0.072, 0.01), Vector3(1.0, 0.95, 0.95))
	for lato3: float in [-1.0, 1.0]:
		_ball(orso, 0.019, pelo, Vector3(lato3 * 0.032, 0.105, 0.005))
		_ball(orso, 0.022, pelo, Vector3(lato3 * 0.058, -0.010, 0.02),
				Vector3(1, 0.8, 1))
	_ball(orso, 0.017, _mat(Color("e8d6bc"), Color("cbb79a"), 7.0, 0.4),
			Vector3(0, 0.058, 0.038), Vector3(1, 0.8, 1))
	for occhio: float in [-1.0, 1.0]:
		_ball(orso, 0.006, _mat(Color("3a2f28"), Color("241d18"), 6.0, 0.3),
				Vector3(occhio * 0.018, 0.080, 0.040))
	return n


static func _bookshelf() -> Node3D:
	# LA LIBRERIA. Guscio aperto sul fronte (-Z) — e la CIMA resta piatta e
	# LIBERA: è la vetrina dei barattoli della Collection (si posano a
	# y 1.55, x da -0.36 a 0.36, due file in z). Perciò la cornice sporge
	# solo verso l'esterno e il basso, mai sopra il piano.
	# Il resto è falegnameria e vita: zoccolo scuro, cornice a gradoni,
	# fianchi a specchiatura (la libreria si guarda anche di profilo),
	# il labbro sotto ogni ripiano; e sugli scaffali libri VERI — dorsi a
	# profondità irregolare, fascette del titolo, qualcuno che pende
	# appoggiato al vicino, la pila orizzontale con la piantina sopra.
	# Semi FISSI: questa libreria è sempre questa libreria.
	var n := Node3D.new()
	var wood := _mat(WOOD, WOOD_DARK, 4.0, 0.55)
	var pale := _mat(WOOD_PALE, WOOD, 3.0, 0.45)
	var scuro := _mat(WOOD_DARK, WOOD_DARK.darkened(0.15), 3.5, 0.45)
	_box(n, Vector3(0.9, 1.55, 0.06), pale, Vector3(0, 0.775, 0.12))
	for side in [-0.435, 0.435]:
		_box(n, Vector3(0.06, 1.55, 0.3), wood, Vector3(side, 0.775, 0))
	_box(n, Vector3(0.9, 0.06, 0.3), wood, Vector3(0, 1.52, 0))
	_box(n, Vector3(0.9, 0.06, 0.3), wood, Vector3(0, 0.03, 0))
	# lo zoccolo, la cornice a gradoni (sotto il piano, mai sopra), e le
	# specchiature sui fianchi
	_box(n, Vector3(0.96, 0.10, 0.36), scuro, Vector3(0, 0.05, 0))
	_box(n, Vector3(0.98, 0.045, 0.37), wood, Vector3(0, 1.4675, 0))
	_box(n, Vector3(0.94, 0.035, 0.34), scuro, Vector3(0, 1.4275, 0))
	for side: float in [-1.0, 1.0]:
		_box(n, Vector3(0.016, 1.16, 0.235), pale, Vector3(side * 0.468, 0.76, 0))
		for tz: float in [-0.125, 0.125]:
			_box(n, Vector3(0.022, 1.26, 0.05), scuro, Vector3(side * 0.469, 0.76, tz))
		_box(n, Vector3(0.022, 0.05, 0.30), scuro, Vector3(side * 0.469, 0.155, 0))
		_box(n, Vector3(0.022, 0.05, 0.30), scuro, Vector3(side * 0.469, 1.365, 0))
	var tavolozza: Array[Color] = [Color("d97f7f"), Color("7fa8d9"),
			Color("d9c27f"), Color("8fbc8a"), Color("b78ac2")]
	for row in 3:
		var base_y := 0.06 + row * 0.48
		if row > 0:
			_box(n, Vector3(0.78, 0.04, 0.26), wood, Vector3(0, base_y - 0.02, 0))
			_box(n, Vector3(0.78, 0.055, 0.025), scuro, Vector3(0, base_y - 0.02, -0.138))
		var rng := RandomNumberGenerator.new()
		rng.seed = row * 17 + 3
		var x := -0.36
		# sul ripiano di mezzo, prima dei libri, la pila orizzontale con
		# la piantina sopra: la firma di una libreria abitata
		if row == 1:
			var py := base_y
			for pk in 3:
				var pw: float = [0.155, 0.14, 0.125][pk]
				var pcol: Color = tavolozza[(pk * 2 + 1) % 5]
				var piatto := _box(n, Vector3(0.19, 0.027, pw),
						_mat(pcol, pcol.darkened(0.2), 6.0, 0.4),
						Vector3(-0.285, py + 0.0135, -0.015))
				piatto.rotation.y = [0.05, -0.07, 0.03][pk]
				py += 0.027
			_cyl(n, 0.030, 0.024, 0.05, _mat(Color("c08d5f"), Color("9c7049"), 4.0, 0.45),
					Vector3(-0.285, py + 0.025, -0.015))
			_ball(n, 0.042, _mat(Color("7fae6a"), Color("5f8a4e"), 4.0, 0.45),
					Vector3(-0.285, py + 0.075, -0.015), Vector3(1.0, 0.78, 1.0))
			x = -0.155
		while x < 0.3:
			var w := rng.randf_range(0.055, 0.09)
			var h := rng.randf_range(0.24, 0.36)
			var col: Color = tavolozza[rng.randi() % 5]
			var mat := _mat(col, col.darkened(0.2), 6.0, 0.4)
			# dorsi a profondità irregolare: nessuno scaffale vero è a filo
			var z := -0.02 - rng.randf_range(0.0, 0.02)
			var pende := rng.randf() < 0.22 and x > -0.28
			if pende:
				# il libro che PENDE, appoggiato al vicino di sinistra:
				# ruotato sul piede, e lo spazio che occupa cresce
				var tilt := rng.randf_range(0.10, 0.17)
				var libro := _box(n, Vector3(w, h, 0.2), mat,
						Vector3(x + w * 0.5 + sin(tilt) * h * 0.28,
								base_y + h * 0.5 * cos(tilt) - 0.002, z))
				libro.rotation.z = tilt
				x += w + sin(tilt) * h * 0.55
			else:
				_box(n, Vector3(w, h, 0.2), mat,
						Vector3(x + w * 0.5, base_y + h * 0.5, z))
				# la fascetta del titolo, su un dorso sì e uno no
				if rng.randf() < 0.5:
					_box(n, Vector3(w * 0.7, 0.014, 0.006),
							_mat(CREAM, Color("f0e4cc"), 5.0, 0.3),
							Vector3(x + w * 0.5, base_y + h * 0.82, z - 0.101))
				x += w
			x += rng.randf_range(0.005, 0.03)
	return n


static func _nightstand() -> Node3D:
	# IL COMODINO: era una scatola nuda con la candela, e il cassetto
	# stava sul RETRO (+Z) — nella vista del catalogo si vedeva un cubo
	# cieco, la stessa trappola del vecchio camino. Adesso è falegnameria:
	# gambette tornite, montanti agli spigoli, il cassetto sul fronte -Z
	# col pomello, una nicchia aperta VERA coi libri della buonanotte, il
	# piano che sborda — e la candela su una bugia d'ottone, con la
	# colatura di cera e il manico ad anello.
	var n := Node3D.new()
	var legno := _mat(WOOD, WOOD_DARK, 4.0, 0.55)
	var legno_scuro := _mat(WOOD_DARK, WOOD_DARK.darkened(0.22), 4.0, 0.45)
	var legno_chiaro := _mat(WOOD_PALE, WOOD, 3.5, 0.45)
	var ombra := _mat(Color("4a3527"), Color("3b2a1f"), 3.0, 0.3)
	var ottone := _mat(OTTONE, OTTONE_SCURO, 5.0, 0.35)
	# ---- le gambette tornite, coi piedini a sfera schiacciata
	for gx: float in [-0.17, 0.17]:
		for gz: float in [-0.13, 0.13]:
			_cyl(n, 0.017, 0.022, 0.09, legno, Vector3(gx, 0.075, gz))
			_ball(n, 0.024, legno_scuro, Vector3(gx, 0.026, gz), Vector3(1, 0.75, 1))
	# ---- la cassa: fianchi, schiena, due ripiani — la nicchia è VUOTA
	_box(n, Vector3(0.03, 0.36, 0.32), legno, Vector3(-0.19, 0.3, 0))
	_box(n, Vector3(0.03, 0.36, 0.32), legno, Vector3(0.19, 0.3, 0))
	_box(n, Vector3(0.41, 0.36, 0.025), legno, Vector3(0, 0.3, 0.148))
	_box(n, Vector3(0.35, 0.022, 0.3), legno, Vector3(0, 0.132, -0.005))
	_box(n, Vector3(0.35, 0.022, 0.3), legno_scuro, Vector3(0, 0.335, -0.005))
	# i montanti agli spigoli, fieri di qualche millimetro
	for mx: float in [-0.195, 0.195]:
		for mz: float in [-0.145, 0.145]:
			_box(n, Vector3(0.042, 0.37, 0.042), legno_scuro, Vector3(mx, 0.3, mz))
	# le specchiature chiare sui fianchi e sul retro: senza, di profilo
	# il comodino torna una lastra piatta
	_box(n, Vector3(0.01, 0.26, 0.22), legno_chiaro, Vector3(-0.208, 0.3, 0))
	_box(n, Vector3(0.01, 0.26, 0.22), legno_chiaro, Vector3(0.208, 0.3, 0))
	_box(n, Vector3(0.3, 0.26, 0.008), legno_chiaro, Vector3(0, 0.3, 0.1605))
	# ---- il cassetto, sul FRONTE (-Z): riquadro chiaro nel telaio scuro
	_box(n, Vector3(0.36, 0.15, 0.012), legno_scuro, Vector3(0, 0.412, -0.155))
	_box(n, Vector3(0.325, 0.115, 0.014), legno_chiaro, Vector3(0, 0.412, -0.158))
	# il pomello tornito: colletto e sfera
	var colletto := _cyl(n, 0.014, 0.017, 0.016, legno_scuro, Vector3(0, 0.412, -0.172))
	colletto.rotation.x = PI * 0.5
	_ball(n, 0.021, legno_scuro, Vector3(0, 0.412, -0.186))
	# ---- i libri della buonanotte, nella nicchia
	var rosso := _mat(TERRACOTTA, TERRACOTTA.darkened(0.18), 4.0, 0.4)
	var verde := _mat(LEAF, LEAF.darkened(0.2), 4.0, 0.4)
	var blu := _mat(BLU_CUPO, Color("4c6699"), 4.0, 0.4)
	_box(n, Vector3(0.045, 0.125, 0.2), rosso, Vector3(-0.09, 0.206, -0.02))
	_box(n, Vector3(0.04, 0.11, 0.18), blu, Vector3(-0.04, 0.198, -0.01))
	var storto := _box(n, Vector3(0.038, 0.115, 0.19), verde, Vector3(0.025, 0.2, -0.015))
	storto.rotation.z = -0.16    # quello che si appoggia agli altri
	# le paginette chiare che spuntano dal taglio
	_box(n, Vector3(0.034, 0.1, 0.185), _mat(CREAM, Color("efe3cc"), 5.0, 0.3),
			Vector3(-0.04, 0.198, -0.014))
	# ---- il piano che sborda, con la fascia sotto
	_box(n, Vector3(0.4, 0.02, 0.34), legno_scuro, Vector3(0, 0.492, 0))
	_box(n, Vector3(0.46, 0.035, 0.4), legno, Vector3(0, 0.519, 0))
	_box(n, Vector3(0.42, 0.008, 0.36), legno_chiaro, Vector3(0, 0.5405, 0))
	# ---- la bugia d'ottone: piattino, manico ad anello, candela colata
	var bugia := Node3D.new()
	bugia.name = "Bugia"
	bugia.position = Vector3(-0.11, 0.5445, -0.05)
	n.add_child(bugia)
	_cyl(bugia, 0.052, 0.058, 0.012, ottone, Vector3(0, 0.006, 0))
	_cyl(bugia, 0.036, 0.03, 0.014, ottone, Vector3(0, 0.018, 0))
	var anello := MeshInstance3D.new()
	var am := TorusMesh.new()
	am.inner_radius = 0.014
	am.outer_radius = 0.026
	anello.mesh = am
	anello.material_override = ottone
	anello.position = Vector3(0.066, 0.012, 0)
	anello.rotation.x = PI * 0.5
	bugia.add_child(anello)
	var cera := _mat(CREAM, Color("f3e6d0"), 5.0, 0.35)
	_cyl(bugia, 0.026, 0.028, 0.085, cera, Vector3(0, 0.066, 0))
	_cyl(bugia, 0.021, 0.026, 0.02, cera, Vector3(0, 0.117, 0))
	# la colatura: parte dal cratere e scende in un rivolo sottile che
	# ABBRACCIA il fusto (a palline staccate sembrava gomma da masticare)
	_ball(bugia, 0.009, cera, Vector3(-0.019, 0.122, 0.005), Vector3(1.0, 0.7, 1.0))
	_ball(bugia, 0.011, cera, Vector3(-0.0272, 0.088, 0.006), Vector3(0.55, 2.6, 0.55))
	_ball(bugia, 0.008, cera, Vector3(-0.0282, 0.052, 0.008), Vector3(0.5, 1.4, 0.5))
	# lo stoppino e la fiamma a goccia
	_cyl(bugia, 0.0025, 0.0025, 0.012, ombra, Vector3(0, 0.132, 0))
	_ball(bugia, 0.016, _glow(Color("ffd382"), Color("ffb84d"), 2.5),
			Vector3(0, 0.15, 0), Vector3(0.9, 1.6, 0.9))
	return n


## IL CAMINO DI PIETRA, rifatto. Prima erano tre scatole lisce impilate e
## il focolare guardava DALLA PARTE SBAGLIATA: nella vista frontale del
## catalogo si vedeva un muro cieco, perché l'apertura stava sul lato +Z
## mentre in questo catalogo il fronte è -Z. Un camino che dà le spalle
## alla stanza è la definizione di pezzo mai guardato.
##
## Adesso: muratura di conci veri, l'architrave sopra la bocca, il
## focolare con la cenere, gli alari, i ceppi e le braci — e IL FUOCO CHE
## SI MUOVE. Il fuoco non è una fiamma disegnata: sono due emettitori (la
## fiamma e le scintille che salgono nella cappa) più la LUCE CHE TREMA,
## animata a chiavi irregolari. È il tremolio a fare il fuoco: una luce
## calda ma ferma legge «lampadina», e nessun caminetto è mai stato una
## lampadina. Le chiavi non sono un seno — un seno si smaschera in due
## cicli — ma undici valori scritti a mano su una durata che non si
## richiude con niente.
static func _fireplace() -> Node3D:
	var n := Node3D.new()
	# la pietra di un focolare è SCURA e calda: il grigio chiaro del muro
	# di casa, qui, faceva un camino di gesso — e il fuoco non aveva su
	# cosa battere. Tre tinte di fiume, brunite dal fumo di anni.
	var pietra := _mat(Color("8e8578"), Color("6b6459"), 3.0, 0.55)
	var pietra_ombra := _mat(Color("776f64"), Color("585149"), 3.0, 0.5)
	var pietra_chiara := _mat(Color("a89c8b"), Color("847a6c"), 3.5, 0.5)
	var fuligg := _mat(Color("3a3230"), Color("241f1e"), 3.0, 0.4)
	var ferro := _mat(Color("4a4640"), Color("332f2b"), 5.0, 0.35)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20_260_806

	# ---- LA MURATURA: conci veri, non una scatola. Il fronte è a -Z,
	# quindi la bocca si apre di là: è quella la stanza. ----
	var z_fronte := -0.20
	var bocca_l := 0.52
	var bocca_h := 0.56
	var y_arch := 0.62               # sotto l'architrave
	var corsi := [[0.00, 0.16], [0.16, 0.15], [0.31, 0.16], [0.47, 0.15],
			[0.62, 0.14], [0.76, 0.16]]
	for c in corsi:
		var y_c: float = c[0]
		var h_c: float = c[1]
		var dentro_bocca: bool = y_c + h_c <= y_arch + 0.001
		# ogni corso è fatto di conci di larghezza diversa, con lo sfalso
		var x := -0.45
		var k := 0
		while x < 0.449:
			var largo: float = minf(rng.randf_range(0.13, 0.26), 0.45 - x)
			var salta: bool = dentro_bocca and absf(x + largo * 0.5) < bocca_l * 0.5 - 0.02
			if not salta:
				var mat: Material = [pietra, pietra_chiara, pietra_ombra][
						rng.randi_range(0, 2)]
				var prof := 0.40
				var zc := 0.0
				if dentro_bocca and absf(x + largo * 0.5) < bocca_l * 0.5 + 0.14:
					prof = 0.22          # lo stipite: il muro si assottiglia
					zc = 0.09
				var concio := _box(n, Vector3(largo - 0.012,
						h_c - 0.012 + rng.randf_range(-0.004, 0.004), prof),
						mat, Vector3(x + largo * 0.5,
						y_c + h_c * 0.5 + rng.randf_range(-0.004, 0.004), zc))
				concio.rotation.z = rng.randf_range(-0.012, 0.012)
				concio.rotation.y = rng.randf_range(-0.02, 0.02)
			x += largo
			k += 1
	# l'ARCHITRAVE: un solo blocco lungo che scavalca la bocca e sporge
	var arch := _box(n, Vector3(0.78, 0.13, 0.44), pietra_chiara,
			Vector3(0, y_arch + 0.065, -0.008))
	arch.rotation.z = -0.006
	_box(n, Vector3(0.80, 0.022, 0.46), pietra_ombra, Vector3(0, y_arch + 0.005, -0.012))

	# ---- IL FOCOLARE: la cavità, la fuliggine, la lastra che sporge ----
	# LA CAVITÀ È VUOTA, non un blocco nero. Prima era UNA SCATOLA PIENA:
	# la sua faccia davanti murava ceppi, braci e fiamme: si vedeva il
	# nero e basta, e tutto il fuoco stava dietro un muro. Adesso sono
	# quattro pareti sottili — fondo, fianchi e cappa — e il focolare si
	# guarda dentro.
	_box(n, Vector3(bocca_l, bocca_h, 0.02), fuligg, Vector3(0, bocca_h * 0.5 + 0.02, 0.175))
	for sxi: float in [-1.0, 1.0]:
		_box(n, Vector3(0.02, bocca_h, 0.26), fuligg,
				Vector3(sxi * (bocca_l * 0.5 - 0.01), bocca_h * 0.5 + 0.02, 0.06))
	_box(n, Vector3(bocca_l, 0.02, 0.26), fuligg, Vector3(0, bocca_h + 0.02, 0.06))
	# il fondo annerito, e l'ALONE DI FUMO sopra la bocca: è la prova che
	# il camino è stato acceso mille volte
	_box(n, Vector3(bocca_l - 0.04, 0.30, 0.012), _mat(Color("2a2422"), Color("1a1615"), 4.0, 0.3),
			Vector3(0, 0.36, 0.163))
	var alone := _box(n, Vector3(0.42, 0.16, 0.012), _mat(Color("6b625c"), Color("4e4744"), 5.0, 0.35),
			Vector3(0, y_arch + 0.15, z_fronte - 0.008))
	alone.rotation.z = 0.01
	# IL BAGLIORE SUL FONDO: il fuoco illumina la parete che ha dietro, e
	# senza quel riverbero la bocca resta un buco nero anche col fuoco
	# acceso — nelle foto e nelle stanze buie
	_box(n, Vector3(bocca_l - 0.08, 0.24, 0.010),
			_glow(Color("d97a3a"), Color("c2521f"), 0.7), Vector3(0, 0.18, 0.158))
	_box(n, Vector3(bocca_l - 0.20, 0.13, 0.010),
			_glow(Color("f0a862"), Color("e07a30"), 1.1), Vector3(0, 0.14, 0.152))
	# la lastra del focolare, consumata al centro dal passaggio
	_box(n, Vector3(0.86, 0.055, 0.52), pietra_chiara, Vector3(0, 0.028, -0.06))
	_box(n, Vector3(0.44, 0.016, 0.30), pietra_ombra, Vector3(0, 0.056, -0.14))
	# la cenere
	_ball(n, 0.19, _mat(Color("b8b0a6"), Color("968e85"), 6.0, 0.4),
			Vector3(0, 0.055, 0.02), Vector3(1.25, 0.16, 0.75))

	# ---- GLI ALARI e i CEPPI ----
	for sx: float in [-0.16, 0.16]:
		_cyl(n, 0.012, 0.012, 0.24, ferro, Vector3(sx, 0.105, 0.02)).rotation.x = PI * 0.5
		_cyl(n, 0.010, 0.010, 0.09, ferro, Vector3(sx, 0.062, -0.08))
		_ball(n, 0.020, ferro, Vector3(sx, 0.145, -0.09), Vector3(1, 1.3, 1))
	var scorza := _mat(Color("7d5c40"), Color("5e442f"), 5.0, 0.5)
	var scorza_bruc := _mat(Color("4a3a30"), Color("2e2420"), 5.0, 0.4)
	var taglio := _mat(Color("d9bb8e"), Color("bb9c6f"), 6.0, 0.35)
	# tre ceppi incrociati: due sotto, uno di traverso — mai paralleli
	var ceppi := [[-0.10, 0.115, 0.02, 0.30, 0.055, -0.10, false],
			[0.11, 0.115, 0.05, 0.28, 0.050, 0.16, false],
			[0.0, 0.175, -0.01, 0.26, 0.046, 1.15, true]]
	for cp in ceppi:
		var ceppo := Node3D.new()
		ceppo.position = Vector3(float(cp[0]), float(cp[1]), float(cp[2]))
		ceppo.rotation.y = float(cp[5])
		ceppo.rotation.z = rng.randf_range(-0.08, 0.08)
		n.add_child(ceppo)
		var lung := float(cp[3])
		var r := float(cp[4])
		_cyl(ceppo, r, r, lung, scorza_bruc if bool(cp[6]) else scorza,
				Vector3.ZERO).rotation.z = PI * 0.5
		# i due tagli chiari alle estremità: è il legno spaccato di fresco
		for lato: float in [-1.0, 1.0]:
			_cyl(ceppo, r * 0.92, r * 0.92, 0.012, taglio,
					Vector3(lato * lung * 0.5, 0, 0)).rotation.z = PI * 0.5
	# LE BRACI: tante, piccole, di calore diverso — un fuoco non ha due
	# braci uguali
	for i in 9:
		var a := TAU * float(i) / 9.0 + rng.randf_range(-0.3, 0.3)
		var rr := rng.randf_range(0.03, 0.17)
		var caldo := rng.randf_range(0.7, 2.6)
		var brace := _glow(Color("ff9440").lerp(Color("ffd28a"), caldo * 0.3),
				Color("ff7a26").lerp(Color("ffc46a"), caldo * 0.25), caldo)
		_ball(n, rng.randf_range(0.030, 0.055), brace,
				Vector3(cos(a) * rr, 0.092, 0.02 + sin(a) * rr * 0.55),
				Vector3(1, rng.randf_range(0.5, 0.75), 1))

	# ---- IL FUOCO CHE SI MUOVE ----
	# LE FIAMME DEVONO RESTARE NEL FOCOLARE. Con velocità 0.75 e vita 0.85
	# le particelle salivano quasi un metro: uscivano dalla bocca (alta
	# 0.56) e le scintille finivano SOPRA IL COMIGNOLO, due puntini bianchi
	# per aria. Vita corta e spinta bassa: la fiamma nasce e muore dentro
	# la cappa, che è quello che fa un fuoco.
	_emit_fx(n, Vector3(0, 0.11, 0.01), Color("ffb43c"), 0.30, 0.22, 30, 0.45, 0.15)
	_emit_fx(n, Vector3(0, 0.15, 0.02), Color("fff0c8"), 0.44, 0.30, 12, 0.55, 0.045)

	# la luce del fuoco, col suo tremolio (il nodo si chiama Fuoco: lo
	# cerca l'animazione qui sotto)
	# il focolare deve arrivare alla mensola e alla canna sopra di sé: a
	# 1.15 il fuoco si vedeva ma la pietra attorno restava blu, cioè il
	# camino era acceso in una stanza fredda
	var luce := OmniLight3D.new()
	luce.name = "Fuoco"
	luce.light_color = Color(1.0, 0.72, 0.42)
	luce.light_energy = CAMINO_ENERGIA
	luce.omni_range = 3.8
	luce.omni_attenuation = 1.15
	luce.position = Vector3(0, 0.30, -0.16)
	n.add_child(luce)
	var anim := Animation.new()
	anim.length = 3.7          # non si richiude con niente: il fuoco non ha ritmo
	anim.loop_mode = Animation.LOOP_LINEAR
	var tr_e := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(tr_e, NodePath("Fuoco:light_energy"))
	# FRAZIONI, non valori: vedi CAMINO_ENERGIA
	var chiavi := [[0.0, 1.00], [0.23, 1.17], [0.51, 0.83], [0.78, 1.06],
			[1.10, 0.91], [1.44, 1.20], [1.90, 0.78], [2.28, 1.03],
			[2.66, 0.89], [3.10, 1.13], [3.42, 0.85], [3.70, 1.00]]
	for kk in chiavi:
		anim.track_insert_key(tr_e, float(kk[0]), CAMINO_ENERGIA * float(kk[1]))
	anim.track_set_interpolation_type(tr_e, Animation.INTERPOLATION_CUBIC)
	# e la sorgente si sposta di pochi millimetri: le ombre nella stanza
	# respirano invece di stare inchiodate
	var tr_x := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(tr_x, NodePath("Fuoco:position:x"))
	anim.track_insert_key(tr_x, 0.0, -0.02)
	anim.track_insert_key(tr_x, 1.3, 0.025)
	anim.track_insert_key(tr_x, 2.5, -0.015)
	anim.track_insert_key(tr_x, 3.7, -0.02)
	anim.track_set_interpolation_type(tr_x, Animation.INTERPOLATION_CUBIC)
	var lib := AnimationLibrary.new()
	lib.add_animation("fiamma", anim)
	var player := AnimationPlayer.new()
	n.add_child(player)
	player.add_animation_library("", lib)
	player.autoplay = "fiamma"

	# ---- LA MENSOLA: trave di rovere, smussata e consumata ----
	var trave := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	_box(n, Vector3(1.0, 0.085, 0.50), trave, Vector3(0, 0.925, -0.03))
	_box(n, Vector3(1.0, 0.020, 0.52), _mat(WOOD_PALE, WOOD, 3.5, 0.45),
			Vector3(0, 0.972, -0.035))
	for sx2: float in [-1.0, 1.0]:
		_box(n, Vector3(0.05, 0.05, 0.05), _mat(WOOD_DARK, Color("8a6440"), 4.0, 0.5),
				Vector3(sx2 * 0.47, 0.90, -0.22))

	# ---- LA CANNA: si restringe salendo, coi suoi corsi ----
	var canna := [[0.98, 0.17, 0.38, 0.34], [1.15, 0.16, 0.35, 0.32],
			[1.31, 0.15, 0.33, 0.30], [1.46, 0.13, 0.31, 0.29]]
	for cn in canna:
		var blocco := _box(n, Vector3(float(cn[2]), float(cn[1]) - 0.010,
				float(cn[3])), pietra, Vector3(0, float(cn[0]) + float(cn[1]) * 0.5, 0))
		blocco.rotation.y = rng.randf_range(-0.01, 0.01)
		_box(n, Vector3(float(cn[2]) + 0.012, 0.008, float(cn[3]) + 0.012),
				pietra_ombra, Vector3(0, float(cn[0]) + 0.004, 0))
	# il cappello di terracotta, il vaso e il coperchio: da qui esce il
	# fumo della sera (VitaSecondaria lo aggancia a quota 1.82)
	var terra := _mat(TERRACOTTA, Color("c47a58"), 3.0, 0.5)
	_box(n, Vector3(0.42, 0.055, 0.40), terra, Vector3(0, 1.62, 0))
	_cyl(n, 0.082, 0.100, 0.17, terra, Vector3(0, 1.72, 0))
	_cyl(n, 0.070, 0.070, 0.020, _mat(Color("8a4f3a"), Color("6d3d2c"), 4.0, 0.4),
			Vector3(0, 1.805, 0))
	for sx3: float in [-1.0, 1.0]:
		_cyl(n, 0.010, 0.010, 0.10, ferro, Vector3(sx3 * 0.062, 1.845, 0))
	_box(n, Vector3(0.24, 0.028, 0.24), pietra_chiara, Vector3(0, 1.90, 0))

	# ---- I DETTAGLI DI CHI CI VIVE ----
	# l'attizzatoio appoggiato allo stipite
	var att := Node3D.new()
	att.position = Vector3(0.40, 0.30, -0.24)
	att.rotation.z = 0.16
	att.rotation.x = -0.10
	n.add_child(att)
	_cyl(att, 0.008, 0.008, 0.58, ferro, Vector3.ZERO)
	_cyl(att, 0.016, 0.016, 0.03, ferro, Vector3(0, 0.30, 0))
	var uncino := _cyl(att, 0.007, 0.007, 0.06, ferro, Vector3(0.02, -0.28, 0))
	uncino.rotation.z = PI * 0.45
	# la catasta di legna accanto, sotto la mensola
	for i2 in 5:
		var riga := i2 / 3
		var col := i2 % 3
		var log := _cyl(n, 0.036, 0.036, 0.20, scorza,
				Vector3(-0.32 + float(col) * 0.075, 0.075 + float(riga) * 0.072,
						-0.30 + rng.randf_range(-0.01, 0.01)))
		log.rotation.x = PI * 0.5
		log.rotation.z = rng.randf_range(-0.05, 0.05)
		_cyl(n, 0.033, 0.033, 0.012, taglio,
				Vector3(-0.32 + float(col) * 0.075, 0.075 + float(riga) * 0.072,
						-0.40)).rotation.x = PI * 0.5
	return n


static func _lamp() -> Node3D:
	return _lampada_base(true)


## La variante SENZA il cestino dei fiori: stessa lanterna, per chi vuole
## il viale sobrio. Un builder solo per tutte e due: se un domani cambia
## il cappello, cambia per entrambe.
static func _lamp_liscia() -> Node3D:
	return _lampada_base(false)


static func _lampada_base(con_cesto: bool) -> Node3D:
	# LA LAMPADA DA GIARDINO. Prima era tre primitive in fila: palo liscio,
	# palla, cono. Ora ha la grammatica di un lampioncino vero — la base a
	# gradoni col collare, il palo rastremato con le ghiere d'ottone, la
	# coppa che CULLA il globo (una palla appoggiata a mezz'aria non regge),
	# il cappello a due spioventi con la gronda e il pomolo d'ottone. E la
	# firma cozy: il braccetto con la voluta da cui pende il cestino dei
	# fiori — tre cordini, la ciotola di legno, e il rosa che trabocca.
	# L'OmniLight non si tocca: è tarata sulle sere del villaggio.
	var n := Node3D.new()
	var metal := _mat(METAL, Color("6f665b"), 5.0, 0.4)
	var ottone := _mat(OTTONE, OTTONE_SCURO, 5.0, 0.4)
	# la base a gradoni
	_cyl(n, 0.125, 0.16, 0.05, metal, Vector3(0, 0.025, 0))
	_cyl(n, 0.095, 0.115, 0.035, metal, Vector3(0, 0.0675, 0))
	_cyl(n, 0.042, 0.062, 0.07, metal, Vector3(0, 0.12, 0))
	# il palo rastremato, con le due ghiere d'ottone
	_cyl(n, 0.026, 0.036, 1.30, metal, Vector3(0, 0.80, 0))
	for gy: float in [0.38, 1.10]:
		_cyl(n, 0.034, 0.034, 0.028, ottone, Vector3(0, gy, 0))
	# il braccetto con la voluta, e il cestino dei fiori appeso
	if con_cesto:
		var corda := _mat(Color("c9b088"), Color("ab9066"), 5.0, 0.5)
		var braccio := _cyl(n, 0.011, 0.011, 0.17, metal, Vector3(0.085, 1.22, 0))
		braccio.rotation.z = PI * 0.5
		_ball(n, 0.018, metal, Vector3(0.0, 1.22, 0))
		_ball(n, 0.016, ottone, Vector3(0.17, 1.22, 0))
		var verde := _mat(Color("7fae6a"), Color("5f8a4e"), 4.0, 0.45)
		var legno := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
		for ck in 3:
			var ca := float(ck) * TAU / 3.0 + 0.3
			var dx := cos(ca) * 0.030
			var dz := sin(ca) * 0.030
			var giu := _cyl(n, 0.004, 0.004, 0.118, corda,
					Vector3(0.17 + dx * 0.5, 1.166, dz * 0.5))
			giu.rotation.z = asin(dx / 0.118)
			giu.rotation.x = -asin(dz / 0.118)
		_cyl(n, 0.052, 0.034, 0.05, legno, Vector3(0.17, 1.085, 0))
		_ball(n, 0.052, verde, Vector3(0.17, 1.118, 0), Vector3(1.0, 0.62, 1.0))
		var rosa := _mat(PINK, PINK_DEEP, 5.0, 0.4)
		for fk in 4:
			var af := float(fk) * TAU / 4.0 + 0.5
			_ball(n, 0.018, rosa,
					Vector3(0.17 + cos(af) * 0.034, 1.149, sin(af) * 0.034))
		_ball(n, 0.016, _mat(CREAM, Color("f3dfc8"), 5.0, 0.3),
				Vector3(0.17, 1.156, 0))
	# la coppa che culla il globo
	_cyl(n, 0.075, 0.045, 0.06, ottone, Vector3(0, 1.465, 0))
	_cyl(n, 0.095, 0.075, 0.02, ottone, Vector3(0, 1.503, 0))
	# il globo (la stessa luce calda di sempre)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color("ffe6b0")
	glow.emission_enabled = true
	glow.emission = Color("ffd382")
	glow.emission_energy_multiplier = 2.2
	_ball(n, 0.16, glow, Vector3(0, 1.6, 0))
	# il cappello a due spioventi: la gronda, il cono, la calotta e il
	# pomolo d'ottone
	_cyl(n, 0.205, 0.215, 0.014, metal, Vector3(0, 1.723, 0))
	_cyl(n, 0.06, 0.20, 0.085, metal, Vector3(0, 1.772, 0))
	_ball(n, 0.058, metal, Vector3(0, 1.812, 0), Vector3(1.0, 0.72, 1.0))
	_ball(n, 0.020, ottone, Vector3(0, 1.856, 0))
	# LA POZZA, scelta al buio (provino_taratura, quattro tarature): a
	# 1.6/4.5/1.4 il globo era bianco e per terra restava una velatura
	# grigia — la lampada brillava e non illuminava. La pozza si fa con la
	# PORTATA e con la caduta, non spingendo l'energia dentro il vetro.
	# Sta un gradino sotto al Lampione (4.0/5.2/1.2): un lampioncino da
	# giardino fa un cerchio più piccolo di quello della strada.
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.86, 0.6)
	light.light_energy = 3.2
	light.omni_range = 4.6
	light.omni_attenuation = 1.15
	light.position = Vector3(0, 1.58, 0)
	n.add_child(light)
	return n


# ---------------------------------------------------------------- giardino

## Il fusto di un cactus: un barile a COSTE, generato come griglia col
## raggio modulato attorno all'asse — r(u) = R·(1 + 0.07·cos(coste·u)).
## Le coste vere le fanno le normali per vertice (_mesh_griglia): con le
## sfere lisce un cactus è solo una pianta grassa qualunque.
static func _cacto(parent: Node3D, rag: float, alt: float, coste: int,
		mat: Material, pos := Vector3.ZERO, incl := Vector3.ZERO) -> MeshInstance3D:
	var file := 16
	var lati := coste * 6
	var vg: Array = []
	for i in file + 1:
		var v := PI * float(i) / float(file)
		var rf := pow(sin(v), 0.82)
		var y := (1.0 - cos(v)) * 0.5 * alt
		var riga := PackedVector3Array()
		for j in lati:
			var u := TAU * float(j) / float(lati)
			var r := rag * rf * (1.0 + 0.07 * cos(float(coste) * u))
			riga.append(Vector3(cos(u) * r, y, sin(u) * r))
		vg.append(riga)
	var mi := _mesh_griglia(parent, vg, mat, pos, true)
	mi.rotation = incl
	return mi


## LA PIANTA: un piccolo cactus in vaso, rifatto. Prima era tre sfere
## verdi in un tronco di cono: adesso il vaso è TORNITO col labbro e il
## piede, sta nel suo sottovaso, la terra ha i sassolini, il fusto ha le
## COSTE con le areole sui crinali, un braccio che spunta di lato — e il
## fiore in cima è un fiore, non un pallino rosa.
static func _plant() -> Node3D:
	var n := Node3D.new()
	var cotto := _mat(TERRACOTTA, Color("bd7455"), 4.0, 0.5)
	var terra := _mat(Color("6a4a38"), Color("53382a"), 6.0, 0.4)
	var leaf := _mat(LEAF, LEAF_DARK, 3.0, 0.6)

	# ---- IL SOTTOVASO e il VASO, torniti, col labbro arrotolato ----
	BUILDER.lathe(n, [Vector2(0.001, 0.0), Vector2(0.130, 0.0),
			Vector2(0.147, 0.010), Vector2(0.153, 0.030),
			Vector2(0.143, 0.034), Vector2(0.134, 0.022),
			Vector2(0.001, 0.018)], cotto)
	BUILDER.lathe(n, [Vector2(0.001, 0.006), Vector2(0.096, 0.006),
			Vector2(0.114, 0.018), Vector2(0.111, 0.038),
			Vector2(0.148, 0.185), Vector2(0.151, 0.198),
			Vector2(0.169, 0.204), Vector2(0.173, 0.222),
			Vector2(0.167, 0.240), Vector2(0.149, 0.238),
			Vector2(0.143, 0.222), Vector2(0.138, 0.212),
			Vector2(0.001, 0.208)], cotto)
	# la riga dipinta a mano che gira sul fianco
	# aderente alla parete (che a y 0.155 ha raggio 0.140): mezza affogata,
	# o invece di una riga dipinta diventa un elastico che galleggia
	_cordolo(n, _super_anello(0.1418, 0.1418, 1.0, 0.0, 40), 0.0042,
			_mat(CREAM, PLASTER_SHADE, 5.0, 0.35), Vector3(0, 0.155, 0))

	# ---- LA TERRA: il tumulo e i sassolini ----
	_cyl(n, 0.136, 0.136, 0.014, terra, Vector3(0, 0.212, 0))
	_ball(n, 0.11, terra, Vector3(0, 0.218, 0), Vector3(1.15, 0.28, 1.15))
	var rngp := RandomNumberGenerator.new()
	rngp.seed = 20_260_808
	for sasso in 7:
		var sa := TAU * float(sasso) / 7.0 + rngp.randf_range(-0.3, 0.3)
		var sr := rngp.randf_range(0.075, 0.122)
		_ball(n, rngp.randf_range(0.008, 0.014),
				_mat(STONE, STONE_DARK, 5.0, 0.4),
				Vector3(cos(sa) * sr, 0.223, sin(sa) * sr),
				Vector3(1, 0.7, 1))

	# ---- IL CACTUS: fusto a dieci coste, braccio a otto, areole ----
	var corpo := Node3D.new()
	corpo.position = Vector3(0, 0.215, 0)
	corpo.rotation.z = 0.045          # nessuna pianta cresce a piombo
	n.add_child(corpo)
	_cacto(corpo, 0.155, 0.335, 10, leaf)
	_cacto(corpo, 0.082, 0.185, 8, leaf, Vector3(0.115, 0.085, 0.030),
			Vector3(0, 0, -0.52))
	# le areole: i puntini chiari sui crinali delle coste
	var areola := _mat(Color("f2ecd8"), Color("ddd3b8"), 6.0, 0.3)
	for lf: float in [0.38, 0.56, 0.74, 0.88]:
		var v2 := PI * lf
		var rf2 := pow(sin(v2), 0.82)
		var y2 := (1.0 - cos(v2)) * 0.5 * 0.335
		for k in 10:
			var u2 := TAU * float(k) / 10.0
			var r2 := 0.155 * rf2 * 1.045
			_ball(corpo, 0.006, areola,
					Vector3(cos(u2) * r2, y2, sin(u2) * r2))
	for lf2: float in [0.50, 0.72]:
		var v3 := PI * lf2
		var rf3 := pow(sin(v3), 0.82)
		var y3 := (1.0 - cos(v3)) * 0.5 * 0.185
		for k2 in 8:
			var u3 := TAU * float(k2) / 8.0
			var r3 := 0.082 * rf3 * 1.045
			var pa := Vector3(cos(u3) * r3, y3, sin(u3) * r3)
			# nel riferimento del braccio inclinato
			var brac := Basis(Vector3(0, 0, 1), -0.52)
			_ball(corpo, 0.0055, areola,
					Vector3(0.115, 0.085, 0.030) + brac * pa)

	# ---- IL FIORE in cima: petali veri attorno al cuore giallo ----
	var fiore := Node3D.new()
	fiore.position = Vector3(0.025, 0.338, 0.012)
	fiore.rotation.z = -0.12
	corpo.add_child(fiore)
	var petalo := _mat(PINK, Color("ffd7e2"), 6.0, 0.4)
	for pt in 7:
		var pu := TAU * float(pt) / 7.0
		var pet := _ball(fiore, 0.026, petalo,
				Vector3(cos(pu) * 0.030, 0.006, sin(pu) * 0.030),
				Vector3(1.0, 0.42, 0.58))
		pet.rotation.y = -pu
		pet.rotation.z = 0.28
	_ball(fiore, 0.0145, _mat(Color("f4c95d"), Color("d9a83f"), 6.0, 0.35),
			Vector3(0, 0.014, 0))
	return n


static func _flowerbed() -> Node3D:
	# L'AIUOLA del catalogo: quella sola, senza vicine. La forma vera la
	# decide aiuola_cella, che sa anche UNIRSI alle aiuole accanto.
	return aiuola_cella({}, 11)


## L'AIUOLA CHE SI UNISCE. `vicini` dice in coordinate MONDO da che parti
## c'è un'altra Aiuola ({"e","o","s","n"}: +X, -X, +Z, -Z): da quelle
## parti la palizzata si apre, la terra si allunga fino al confine di
## cella (e quattro millimetri oltre, dentro la terra della vicina: mai
## tappi complanari sul confine) e i solchi proseguono — due aiuole
## affiancate diventano UNA striscia di terra. Il rinfresco è di
## BuildSystem.rinfresca_aiuole, lo stesso patto del Sentiero; il seme è
## della cella, così la stessa cella rifà sempre le stesse zolle.
##
## Tutta la geometria vive nel figlio «Terra»: il Garden appende velo
## d'acqua e germogli alla RADICE del pezzo, e il rinfresco che scambia
## «Terra» non li tocca mai.
##
## VINCOLO DEL GARDEN: il velo d'acqua (_make_wet_overlay) è un disco
## r 0.4 a y 0.076 — dentro quel raggio la terra resta SOTTO 0.074,
## o il velo annega. I tronchetti stanno FUORI (r 0.44+).
static func aiuola_cella(vicini: Dictionary, seme: int) -> Node3D:
	var radice := Node3D.new()
	var n := Node3D.new()
	n.name = "Terra"
	radice.add_child(n)
	var e := bool(vicini.get("e", false))
	var o := bool(vicini.get("o", false))
	var s := bool(vicini.get("s", false))
	var nn := bool(vicini.get("n", false))
	var terra := _mat(Color("7a5a42"), Color("64483a"), 4.0, 0.5)
	var terra_cupa := _mat(Color("5e4534"), Color("50392c"), 3.0, 0.4)
	# la terra: TRATTENUTA dal bordo, sale fin quasi all'orlo dei
	# tronchetti e si bomba appena al centro (il profilo SALE — fondo,
	# fuori, su, centro — o il tornio cuce le facce alla rovescia)
	BUILDER.lathe(n, [
		Vector2(0.0, 0.0), Vector2(0.44, 0.0), Vector2(0.43, 0.05),
		Vector2(0.4, 0.062), Vector2(0.24, 0.0685), Vector2(0.0, 0.0695),
	], terra, Vector3.ZERO, 26)
	# le lingue di terra verso le vicine: un loft dal centro al confine
	# (la rotazione porta il suo asse X sull'asse del mondo giusto)
	var giri := {"e": 0.0, "s": -PI * 0.5, "o": PI, "n": PI * 0.5}
	for lato in ["e", "o", "s", "n"]:
		if not bool(vicini.get(lato, false)):
			continue
		var lingua := Node3D.new()
		lingua.name = "Estensione" + lato.to_upper()
		lingua.rotation.y = giri[lato]
		n.add_child(lingua)
		_loft(lingua, [[0.0, 0.43, 0.0, 0.065, 0.03],
				[0.504, 0.43, 0.0, 0.065, 0.03]], terra)
	# i solchi di semina: appena sopra il colmo della cupola (0.0695) ma
	# sempre sotto il velo d'acqua del Garden (0.076). Verso una vicina a
	# est/ovest PROSEGUONO sulla lingua di terra — si fermano un soffio
	# prima del confine: il varco di terra nuda fra le righe è il modo
	# più onesto (e senza z-fighting) di attraversarlo
	for i in 3:
		var solco := _box(n, Vector3(0.4 - 0.05 * absf(float(i) - 1.0), 0.007, 0.048),
				terra_cupa, Vector3(0.02 * float(i - 1), 0.07, -0.19 + 0.19 * i))
		solco.name = "Solco%d" % i
		solco.rotation.y = 0.05 * float(i - 1)
	for lato2 in ["e", "o"]:
		if not bool(vicini.get(lato2, false)):
			continue
		var verso := 1.0 if lato2 == "e" else -1.0
		for i in 3:
			var seg := _box(n, Vector3(0.3, 0.007, 0.044), terra_cupa,
					Vector3(verso * 0.31, 0.0685, -0.19 + 0.19 * i))
			seg.name = "Solco%s%d" % [lato2.to_upper(), i]
	# le zolle: la terra smossa non è liscia (il seme è della cella)
	var rng := RandomNumberGenerator.new()
	rng.seed = seme
	for i in 6:
		var az := rng.randf() * TAU
		var rz := rng.randf_range(0.16, 0.36)
		_ball(n, rng.randf_range(0.01, 0.014), terra_cupa,
				Vector3(cos(az) * rz, 0.0655, sin(az) * rz), Vector3(1.2, 0.6, 1.0))
	# la palizzata: CONTIGUA (i tronchetti si toccano), col taglio chiaro
	# in cima. Verso una vicina l'arco SI APRE (via i tronchetti che
	# guardano di là) e il bordo prosegue DRITTO lungo i fianchi della
	# lingua — a meno che anche quel fianco non sia terra unita
	var corteccia := _mat(Color("8a5f43"), Color("6f4c36"), 4.0, 0.5)
	var taglio := _mat(WOOD_PALE, WOOD, 4.5, 0.4)
	var palizzata := Node3D.new()
	palizzata.name = "Palizzata"
	n.add_child(palizzata)
	var quanti := 30
	for i in quanti:
		var a := float(i) / float(quanti) * TAU
		var dir := Vector2(cos(a), sin(a))
		if (e and dir.x > 0.05) or (o and dir.x < -0.05) \
				or (s and dir.y > 0.05) or (nn and dir.y < -0.05):
			rng.randf(); rng.randf()   # il dado gira lo stesso: stesse
			continue                   # altezze per chi resta, sempre
		_tronchetto_aiuola(palizzata, rng, corteccia, taglio,
				Vector3(dir.x * 0.44, 0, dir.y * 0.44), -a, i % 2 == 0)
	# i fianchi dritti delle lingue (5 tronchetti dal tangente al confine)
	for lato3 in ["e", "o", "s", "n"]:
		if not bool(vicini.get(lato3, false)):
			continue
		var lungo := Vector2(1, 0) if lato3 in ["e", "o"] else Vector2(0, 1)
		var segno := 1.0 if lato3 in ["e", "s"] else -1.0
		for fianco: float in [-1.0, 1.0]:
			# il fianco è interno se anche di là c'è terra unita
			var di_la := ("s" if fianco > 0 else "n") if lato3 in ["e", "o"] \
					else ("e" if fianco > 0 else "o")
			if bool(vicini.get(di_la, false)):
				continue
			for k in 5:
				var t := segno * (0.115 + 0.092 * float(k))
				var p := Vector3(lungo.x * t + lungo.y * fianco * 0.44, 0,
						lungo.y * t + lungo.x * fianco * 0.44)
				_tronchetto_aiuola(palizzata, rng, corteccia, taglio,
						p, 0.0 if lato3 in ["e", "o"] else PI * 0.5, k % 2 == 0)
	# l'etichetta segna-semi e i sassi: solo per l'aiuola sola. In una
	# striscia un'etichetta per cella sarebbe un cimitero di cartellini.
	if not (e or o or s or nn):
		var etichetta := Node3D.new()
		etichetta.name = "Etichetta"
		n.add_child(etichetta)
		var stecco := _cyl(etichetta, 0.007, 0.009, 0.15, _mat(WOOD, WOOD_DARK, 4.0, 0.5),
				Vector3(0.3, 0.11, -0.26))
		stecco.rotation.z = 0.09
		stecco.rotation.x = -0.06
		_box(etichetta, Vector3(0.06, 0.042, 0.009), taglio, Vector3(0.307, 0.175, -0.264))
		var pebble := _mat(Color("c9c2b4"), Color("a89f92"), 5.0, 0.5)
		for i in 3:
			var a := TAU * 0.13 + float(i) * 2.2
			_ball(n, rng.randf_range(0.024, 0.036), pebble,
					Vector3(cos(a) * 0.53, 0.016, sin(a) * 0.53),
					Vector3(1.0, 0.62, rng.randf_range(0.8, 1.1)))
	return radice


static func _tronchetto_aiuola(parent: Node3D, rng: RandomNumberGenerator,
		corteccia: Material, taglio: Material, pos: Vector3, giro: float,
		alto: bool) -> void:
	var h := 0.092 if alto else 0.072
	h += rng.randf_range(-0.007, 0.007)
	var tronco := Node3D.new()
	tronco.position = pos
	tronco.rotation.y = giro
	tronco.rotation.z = rng.randf_range(-0.04, 0.04)
	parent.add_child(tronco)
	_cyl(tronco, 0.044, 0.047, h, corteccia, Vector3(0, h * 0.5, 0))
	_cyl(tronco, 0.037, 0.037, 0.006, taglio, Vector3(0, h + 0.001, 0))


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


## LA LAVAGNA del villaggio: una bacheca da piazza col TETTUCCIO.
##
## IL CONTRATTO, prima di tutto: il quadro resta un BoxMesh figlio
## DIRETTO — il piu' grande del pezzo — di 0.94x1.02x0.045, centrato a
## (0, 0.97, 0.06) e inclinato di 0.05 rad. Non sono numeri scelti qui:
## li ricopia `Calendar.ARDESIA_*` per ancorarci le righe di gesso, e
## test_lavagna_gessetto li ricava dalla geometria VERA e li confronta.
## Toccarli senza toccare Calendar scriverebbe i compleanni sul legno.
## Il telaio, per la stessa ragione, non puo' coprire piu' di 4 cm di
## lastra per lato (ARDESIA_L = 0.86 su 0.94), o le righe lunghe
## finirebbero sotto la cornice: il montante interno si DERIVA da li'.
##
## Tutto il resto e' nuovo: montanti torniti su PATTINI (e' il piede a
## dare profondita' — di taglio la vecchia lavagna era una lama), il
## tettuccio a due falde con le assi, i correnti scuri e il colmo
## tornito, le mensole curve che lo reggono, cornice stondata che segue
## l'inclinazione del quadro, vaschetta a canale coi gessetti TONDI e
## la spugna, e il gessetto di scorta appeso al gancio d'ottone —
## sul FIANCO del montante, mai davanti al quadro. Fronte verso -Z.
static func _blackboard() -> Node3D:
	var n := Node3D.new()
	var legno := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	var chiaro := _mat(WOOD_PALE, WOOD, 3.5, 0.5)
	var scuro := _mat(WOOD_DARK, Color("6d4f31"), 4.0, 0.45)
	var ottone := _mat(OTTONE, OTTONE_SCURO, 5.0, 0.4)

	var y_cima := 1.545                       # dove appoggia la GRONDA
	var y_colmo := 1.672
	var x_mont := 0.492
	var z_piano := 0.06
	# L'INTRADOSSO DEL TETTO, ricavato: la falda e' spessa 0.014 misurati
	# perpendicolarmente, che in verticale diventano 0.014/cos(pendenza).
	var pend_f := (y_colmo - y_cima) / 0.24
	var sp_vert := 0.014 / cos(atan(pend_f))
	var y_intra := func(d: float) -> float: return y_colmo - pend_f * d - sp_vert
	# LA TRAPPOLA CHE HA FATTO GALLEGGIARE IL TETTO: `y_cima` e' una quota
	# di MONDO (l'altezza della gronda), ma il tornio del montante e'
	# posato a y=0.045 e il suo profilo e' LOCALE. Chiudendolo a y_cima la
	# cima usciva a 1.590 mentre sopra di lei — sul filo del colmo, dove
	# il tetto e' piu' alto — l'intradosso sta a 1.656: 66 mm d'aria, e
	# nel profilo si vedeva il cielo fra il montante e il tetto.
	var y_asta: float = y_intra.call(0.0) - 0.045 + 0.004

	for sx: float in [-1.0, 1.0]:
		# ---- IL PATTINO: il piede corre in Z, ed e' lui a dare profondita' ----
		var perno_p := Node3D.new()
		perno_p.position = Vector3(sx * x_mont, 0.0, 0.055)
		perno_p.rotation.y = PI * 0.5
		n.add_child(perno_p)
		_loft(perno_p, [[-0.255, 0.018, 0.012, 0.030, 0.008],
				[-0.225, 0.027, 0.004, 0.048, 0.013],
				[-0.06, 0.032, 0.0, 0.056, 0.015],
				[0.13, 0.032, 0.0, 0.056, 0.015],
				[0.235, 0.027, 0.004, 0.048, 0.013],
				[0.265, 0.018, 0.012, 0.030, 0.008]], legno)
		# ---- IL MONTANTE: tornito, dal pattino alla gronda ----
		BUILDER.lathe(n, [Vector2(0.001, 0.0), Vector2(0.036, 0.0),
				Vector2(0.038, 0.020), Vector2(0.033, 0.052),
				Vector2(0.031, 0.30), Vector2(0.0325, 0.62),
				Vector2(0.030, 0.98), Vector2(0.0335, 1.20),
				Vector2(0.036, 1.26), Vector2(0.030, 1.31),
				Vector2(0.029, y_asta - 0.155), Vector2(0.034, y_asta - 0.115),
				Vector2(0.032, y_asta), Vector2(0.001, y_asta)], legno,
				Vector3(sx * x_mont, 0.045, z_piano))
		# le mensole curve che portano le falde: una davanti e una dietro
		# (con la sola davanti, la falda posteriore non poggiava su niente)
		for verso_m: float in [-1.0, 1.0]:
			BUILDER.tube(n, [Vector3(sx * x_mont, 1.315, z_piano + verso_m * 0.020),
					Vector3(sx * x_mont, 1.395, z_piano + verso_m * 0.070),
					Vector3(sx * x_mont, 1.455, z_piano + verso_m * 0.130),
					Vector3(sx * x_mont, 1.500, z_piano + verso_m * 0.188),
					Vector3(sx * x_mont, y_intra.call(0.220) + 0.002,
							z_piano + verso_m * 0.220)],
					[0.017, 0.016, 0.015, 0.014, 0.012], legno, 20, 8)

	# la traversa tornita fra i due montanti, in basso
	var trav := BUILDER.lathe(n, [Vector2(0.001, 0.0), Vector2(0.017, 0.006),
			Vector2(0.023, 0.50), Vector2(0.017, 0.994),
			Vector2(0.001, 1.0)], legno, Vector3(-x_mont, 0.235, z_piano))
	trav.scale.y = (x_mont * 2.0) / 1.0
	trav.rotation.z = -PI * 0.5

	# ---- IL QUADRO (il contratto) ----
	var slate := _box(n, Vector3(0.94, 1.02, 0.045),
			_mat(Color("3d4a40"), Color("32403a"), 5.0, 0.35),
			Vector3(0, 0.97, z_piano))
	slate.rotation.x = 0.05

	# ---- LA CORNICE: segue l'inclinazione del quadro ----
	var telaio := Node3D.new()
	telaio.position = Vector3(0, 0.97, z_piano)
	telaio.rotation.x = 0.05
	n.add_child(telaio)
	# la velatura di gesso: mezzo secolo di parole cancellate male
	# (la posa e' (x, y, z): la prima stesura metteva -0.0245 sulla X e
	# lasciava z a zero — la velatura finiva DENTRO la lastra, invisibile)
	_lastra(telaio, 0.448, 0.945, 0.20, 0.004,
			_mat(Color("415049"), Color("38463f"), 6.0, 0.3),
			Vector3(0, -0.015, -0.0245), Vector3(0, PI * 0.5, 0))
	for oriz: float in [-1.0, 1.0]:
		var st: Array = []
		for k in 5:
			var fx := float(k) / 4.0 * 2.0 - 1.0
			st.append([fx * 0.478, 0.031, -0.0225, 0.0225, 0.010])
		_loft(telaio, st, chiaro, Vector3(0, oriz * 0.532, 0))
	for vert: float in [-1.0, 1.0]:
		var perno_v := Node3D.new()
		# l'interno del montante si DERIVA dal margine di ARDESIA_L:
		# 0.4505 - 0.0225 = 0.428, un filo dentro il 0.43 concesso
		perno_v.position = Vector3(vert * 0.4505, 0, 0)
		perno_v.rotation.z = PI * 0.5
		telaio.add_child(perno_v)
		var st2: Array = []
		for k2 in 5:
			var fx2 := float(k2) / 4.0 * 2.0 - 1.0
			st2.append([fx2 * 0.5545, 0.031, -0.0225, 0.0225, 0.010])
		_loft(perno_v, st2, chiaro)
	# ---- IL RETRO: pannello di legno e croce di S. Andrea ----
	# Di dietro era una lastra verde nuda: una bacheca in mezzo alla
	# piazza la si gira intorno, e il retro deve essere finito come il
	# davanti — tavola, due traverse e la diagonale, come una porta di
	# fienile.
	_lastra(telaio, 0.470, 1.020, 0.020, 0.010, legno,
			Vector3(0, 0, 0.0285), Vector3(0, PI * 0.5, 0))
	# LE FUGHE fra le tavole: senza, il retro e' un foglio liscio.
	# (Nel _loft la stazione e' [x, MEZZA-PROFONDITA-IN-Z, y0, y1, r]:
	# scambiando i due campi la fuga si estendeva 47 cm in Z e portava
	# l'ingombro del pezzo da 0.52 a 0.94 di profondita'.)
	for fuga: float in [-1.0, 0.0, 1.0]:
		_loft(telaio, [[-0.006, 0.004, -0.470, 0.470, 0.003],
				[0.006, 0.004, -0.470, 0.470, 0.003]], scuro,
				Vector3(fuga * 0.235, 0, 0.0345))
	for ledger: float in [-1.0, 1.0]:
		_loft(telaio, [[-0.452, 0.009, -0.030, 0.030, 0.008],
				[0.452, 0.009, -0.030, 0.030, 0.008]], scuro,
				Vector3(0, ledger * 0.355, 0.042))
	var perno_d := Node3D.new()
	perno_d.position = Vector3(0, 0, 0.042)
	perno_d.rotation.z = atan2(0.71, 0.90)
	telaio.add_child(perno_d)
	var mezzo_d := Vector2(0.90, 0.71).length() * 0.5
	_loft(perno_d, [[-mezzo_d, 0.009, -0.026, 0.026, 0.008],
			[mezzo_d, 0.009, -0.026, 0.026, 0.008]], scuro)

	# i bulloni d'ottone agli angoli della cornice
	for bx: float in [-1.0, 1.0]:
		for by: float in [-1.0, 1.0]:
			_ball(telaio, 0.010, ottone,
					Vector3(bx * 0.4505, by * 0.532, -0.030), Vector3(1, 1, 0.55))

	# ---- IL TETTUCCIO a due falde, con le assi e il colmo ----
	for verso: float in [-1.0, 1.0]:
		var z_gronda := z_piano + verso * 0.24
		var perno_f := Node3D.new()
		perno_f.position = Vector3(0, (y_colmo + y_cima) * 0.5,
				(z_piano + z_gronda) * 0.5)
		perno_f.rotation.x = verso * atan2(y_colmo - y_cima, 0.24)
		n.add_child(perno_f)
		var mezzo_f := Vector2(0.24, y_colmo - y_cima).length() * 0.5
		_loft(perno_f, [[-0.508, mezzo_f, -0.014, 0.014, 0.010],
				[0.508, mezzo_f, -0.014, 0.014, 0.010]], legno)
		# i due correnti scuri: solo sulla faccia di FUORI
		for corso: float in [-0.42, 0.28]:
			_box(perno_f, Vector3(1.016, 0.010, 0.014), scuro,
					Vector3(0, 0.016, corso * mezzo_f))
		# la testata della falda, chiara: e' il taglio dell'asse
		_loft(perno_f, [[-0.516, mezzo_f, -0.015, 0.015, 0.011],
				[-0.508, mezzo_f, -0.015, 0.015, 0.011]], chiaro)
		_loft(perno_f, [[0.508, mezzo_f, -0.015, 0.015, 0.011],
				[0.516, mezzo_f, -0.015, 0.015, 0.011]], chiaro)
	var colmo := BUILDER.lathe(n, [Vector2(0.001, 0.0), Vector2(0.019, 0.006),
			Vector2(0.024, 0.51), Vector2(0.019, 1.014),
			Vector2(0.001, 1.02)], chiaro, Vector3(-0.51, y_colmo + 0.008, z_piano))
	colmo.rotation.z = -PI * 0.5
	# i pomelli stanno DENTRO la falda: sporgenti, portavano l'ingombro a
	# 1.17 m in una cella da 1 (il dump geometrico, non l'occhio)
	for fx3: float in [-1.0, 1.0]:
		_ball(n, 0.017, ottone, Vector3(fx3 * 0.508, y_colmo + 0.008, z_piano))

	# ---- LA VASCHETTA: un canale, coi gessetti TONDI e la spugna ----
	var y_vas := 0.398
	_loft(n, [[-0.452, 0.078, -0.012, 0.012, 0.009],
			[0.452, 0.078, -0.012, 0.012, 0.009]], chiaro,
			Vector3(0, y_vas, z_piano - 0.052))
	# LA SPONDA sta piu' BASSA dei gessetti, o li nasconde: arrivava a
	# 0.444 mentre il gesso in mezzo al canale finisce a 0.432, e di
	# fronte non si vedeva niente di quello che c'e' dentro.
	_loft(n, [[-0.452, 0.010, -0.014, 0.022, 0.008],
			[0.452, 0.010, -0.014, 0.022, 0.008]], chiaro,
			Vector3(0, y_vas + 0.008, z_piano - 0.122))
	for lato: float in [-1.0, 1.0]:
		_loft(n, [[-0.010, 0.078, -0.014, 0.022, 0.009],
				[0.010, 0.078, -0.014, 0.022, 0.009]], chiaro,
				Vector3(lato * 0.452, y_vas + 0.008, z_piano - 0.052))
	# IL CUORE INTAGLIATO, come sulla testiera del letto e sulla stecca
	# della sedia: e' lo stesso falegname, ed e' la stessa casa. Sta sulla
	# fronte del canale — sulla traversa alta della cornice finiva
	# NELL'OMBRA della gronda, e un segno che non si vede non e' un segno.
	var buio_c := _mat(Color("5a4028"), Color("42301d"), 4.0, 0.35)
	# (sta DENTRO la fronte della sponda, che va da y_vas-0.006 a
	# y_vas+0.030: piu' grande, sbucava sotto il legno)
	for lobo: float in [-1.0, 1.0]:
		_ball(n, 0.0088, buio_c,
				Vector3(lobo * 0.0064, y_vas + 0.0185, z_piano - 0.131),
				Vector3(1, 1, 0.35))
	var punta_c := _box(n, Vector3(0.0155, 0.0155, 0.007), buio_c,
			Vector3(0, y_vas + 0.0075, z_piano - 0.131))
	punta_c.rotation.z = PI * 0.25

	var gesso_b := _mat(Color("fff8ee"), Color("efe6da"), 6.0, 0.3)
	var gesso_r := _mat(Color("f4c2cf"), Color("e8aebe"), 6.0, 0.3)
	var g1 := _cyl(n, 0.011, 0.011, 0.10, gesso_b,
			Vector3(-0.20, y_vas + 0.026, z_piano - 0.062))
	g1.rotation.z = PI * 0.5
	g1.rotation.y = 0.14
	var g2 := _cyl(n, 0.011, 0.010, 0.068, gesso_r,
			Vector3(0.10, y_vas + 0.026, z_piano - 0.078))
	g2.rotation.z = PI * 0.5
	g2.rotation.y = -0.22
	# la spugna, col fianco impolverato di gesso
	_soffice(n, Vector3(0.115, 0.048, 0.078),
			_mat(Color("c9b78f"), Color("ab9871"), 5.0, 0.4),
			Vector3(0.30, y_vas + 0.036, z_piano - 0.062), 0.3, 0.5)
	_soffice(n, Vector3(0.10, 0.012, 0.066), _mat(Color("efe7d6"), Color("d8cfbc"), 6.0, 0.3),
			Vector3(0.30, y_vas + 0.058, z_piano - 0.062), 0.3, 0.5)

	# ---- IL GESSETTO DI SCORTA: al gancio, sul FIANCO del montante ----
	_ball(n, 0.011, ottone, Vector3(x_mont + 0.030, 1.155, z_piano),
			Vector3(1, 0.8, 1))
	BUILDER.tube(n, [Vector3(x_mont + 0.034, 1.150, z_piano),
			Vector3(x_mont + 0.048, 1.100, z_piano - 0.012),
			Vector3(x_mont + 0.046, 1.048, z_piano - 0.020),
			Vector3(x_mont + 0.038, 0.998, z_piano - 0.024)],
			[0.0035, 0.0035, 0.0035, 0.0035], scuro, 16, 6)
	var g3 := _cyl(n, 0.010, 0.010, 0.072, gesso_b,
			Vector3(x_mont + 0.038, 0.972, z_piano - 0.024))
	g3.rotation.z = 0.12
	return n


# ------------------------------------------------- verticalità

# LA SCALA DEL PIANO DI SOPRA. Prima saliva un piano intero (2.15)
# dentro UNA cella: 65 gradi, una scala a pioli travestita. Ora la
# CORSA e' di due celle: la cima resta sul bordo -Z della sua cella
# (il solaio si posa sulle celle accanto: il vano non cambia) e il
# PIEDE sconfina nella cella a +Z — pendenza 48 gradi, nove gradini,
# e finalmente si sale col passo e non con le unghie. I gradini sono
# PEDATE APERTE senza alzata (l'aria fra i gradini alleggerisce
# tutto), portate da listelli sui due cosciali; il corrimano e' TONDO
# e chiaro (lucidato dalle mani), i montanti hanno il pomello tornito,
# le colonnine si RICAVANO dalle due rette parallele (cosciale
# y = 1.5916 − 1.1208·z, corrimano +0.78). Sale verso -Z (R per
# girarla). La collisione-rampa e' allungata con lei.
static func _stairs() -> Node3D:
	var n := Node3D.new()
	var legno := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	var chiaro := _mat(WOOD_PALE, WOOD, 4.2, 0.5)
	var scuro := _mat(WOOD_DARK, Color("8a6440"), 4.0, 0.5)

	# le PEDATE aperte: nove, col naso bombato sul filo davanti
	for i in 9:
		var cima := (float(i) + 1.0) * 0.2391
		var z := 1.42 - (float(i) + 0.5) * 0.2133
		var ped := _prisma(n, _rrect_xz(0.88, 0.235, 0.02), cima - 0.04,
				0.04, legno)
		ped.position.z = z
		var naso := _cyl(n, 0.017, 0.017, 0.83, legno,
				Vector3(0, cima - 0.018, z + 0.0995))
		naso.rotation.z = PI * 0.5
		for sx0: float in [-0.40, 0.40]:
			_box(n, Vector3(0.05, 0.030, 0.16), scuro,
					Vector3(sx0, cima - 0.056, z))

	for sx: float in [-0.45, 0.45]:
		# il COSCIALE lungo la rampa. (Trappola pagata due volte: nella
		# _lastra la w e' la MEZZA larghezza lungo Z e la h corre lungo
		# Y — per inclinarla si ruota dell'angolo della rampa MENO PI/2.)
		_lastra(n, 0.085, 2.95, 0.04, 0.055, scuro,
				Vector3(sx, 1.076, 0.46), Vector3(0.8425 - PI * 0.5, 0, 0))
		# i tasselli in fila sulla faccia esterna, uno per gradino
		for i2 in 9:
			var tass := _cyl(n, 0.0065, 0.0065, 0.006, legno,
					Vector3(sx * (0.478 / 0.45), (float(i2) + 1.0) * 0.2391 - 0.06,
					1.42 - (float(i2) + 0.5) * 0.2133))
			tass.rotation.z = PI * 0.5

		# il CORRIMANO tondo, chiaro come il legno lucidato dalle mani
		var mano := _cyl(n, 0.030, 0.030, 2.95, chiaro, Vector3(sx, 1.856, 0.46))
		mano.rotation.x = 0.8425 - PI * 0.5

		# i MONTANTI col collarino e il pomello tornito, ai due capi
		_cyl(n, 0.030, 0.036, 0.95, legno, Vector3(sx, 0.475, 1.38))
		_cyl(n, 0.040, 0.040, 0.022, scuro, Vector3(sx, 0.962, 1.38))
		_ball(n, 0.044, legno, Vector3(sx, 1.012, 1.38))
		_cyl(n, 0.030, 0.036, 0.86, legno, Vector3(sx, 2.53, -0.44))
		_cyl(n, 0.040, 0.040, 0.022, scuro, Vector3(sx, 2.972, -0.44))
		_ball(n, 0.044, legno, Vector3(sx, 3.022, -0.44))

		# le COLONNINE, dalla retta del cosciale a quella del corrimano
		for pz: float in [1.20, 0.84, 0.47, 0.10, -0.26]:
			var y_rampa := 1.5916 - 1.1208 * pz + 0.08
			var y_mano := 2.3716 - 1.1208 * pz - 0.02
			_cyl(n, 0.014, 0.017, y_mano - y_rampa, scuro,
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
	# IL PONTICELLO DI CORDA, rifatto da capo. Il vecchio aveva tre bugie:
	# si chiamava «di corda» e non aveva UNA corda (pali e corrimano erano
	# color canapa, ma erano cilindri rigidi in due tratti spezzati); i
	# paletti verticali erano piantati a quota fissa, quindi trapassavano
	# le assi e finivano a mezz'aria senza toccare il corrimano; e le assi
	# erano sospese nel vuoto, senza niente che le reggesse.
	#
	# La regola è quella di tutte le correzioni di ieri: NIENTE QUOTE A
	# OCCHIO. Qui vivono due curve — l'incurvarsi del piano (dip) e la
	# pancia della corda corrimano (mano) — e OGNI cosa si aggancia
	# leggendo quelle: le assi seguono la curva E la sua tangente, le due
	# corde portanti corrono sotto il bordo delle assi, i tiranti vanno
	# da una curva all'altra con la lunghezza che risulta, e le corde
	# maestre finiscono sui pali nel punto ESATTO in cui i pali stanno —
	# che è calcolato dalla loro inclinazione, perché i pali pendono un
	# po' in fuori come i paletti piantati a mano.
	#
	# Corre lungo Z (R per orientarlo); il piano resta camminabile e la
	# collisione del catalogo non cambia.
	var n := Node3D.new()
	var plank := _mat(WOOD, WOOD_DARK, 4.0, 0.55)
	var palo_mat := _mat(WOOD_DARK, Color("8a6440"), 4.0, 0.5)
	var rope := _mat(Color("c9b088"), Color("ab9066"), 5.0, 0.5)
	var rope_dark := _mat(Color("b39a72"), Color("96805c"), 5.0, 0.5)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20_260_803    # due ponticelli uguali si incurvano uguale

	# --- le due curve, e le loro letture ---
	var dip := func(z: float) -> float:
		var t := clampf((z + 0.415) / 0.83, 0.0, 1.0)
		return -0.05 - 0.045 * sin(PI * t)
	var dip_slope := func(z: float) -> float:
		var t := clampf((z + 0.415) / 0.83, 0.0, 1.0)
		return -0.045 * PI * cos(PI * t) / 0.83
	# --- i quattro pali: tronchetti rastremati che pendono in fuori.
	# Ogni palo vive in un PIVOT alla propria base: la testa, la legatura
	# di corda e il punto d'aggancio delle corde maestre si spostano
	# INSIEME al palo — attaccare la corda alla posizione teorica di un
	# palo che nel frattempo si è inclinato è come mettere i pilastrini
	# della scala a quota fissa. Il pivot restituisce il punto vero.
	var attacchi := {}
	for sx: float in [-0.44, 0.44]:
		for sz: float in [-0.47, 0.47]:
			var piede := Node3D.new()
			piede.position = Vector3(sx, -0.145, sz)
			# pende in fuori, un po' diverso per ogni palo
			piede.rotation.x = -signf(sz) * rng.randf_range(0.03, 0.06)
			piede.rotation.z = signf(sx) * rng.randf_range(0.03, 0.06)
			n.add_child(piede)
			_cyl(piede, 0.034, 0.046, 0.56, palo_mat, Vector3(0, 0.28, 0))
			# la testa a cupola, appena schiacciata: un tronchetto tagliato
			_ball(piede, 0.036, palo_mat, Vector3(0, 0.565, 0), Vector3(1.0, 0.55, 1.0))
			# LA LEGATURA: tre giri di corda sotto la testa, dove le
			# corde maestre si annodano. È lei a «spiegare» l'aggancio.
			for g in 3:
				_cyl(piede, 0.041, 0.041, 0.014, rope_dark,
						Vector3(0, 0.475 + 0.017 * float(g), 0))
			# il punto d'aggancio VERO, nel mondo: centro della legatura
			var locale := Vector3(0, 0.492, 0)
			attacchi[Vector2(sx, sz)] = piede.position \
					+ Basis.from_euler(piede.rotation) * locale

	# --- le corde maestre (i corrimano): CORDE VIVE, tese fra le legature
	# dei due pali (ognuna parte da dove il suo palo pende davvero). Nel
	# mondo ondeggiano col vento e si scostano se Mochi le sfiora; i
	# tiranti le SEGUONO — dichiarati nel meta, il gestore li ritende a
	# ogni frame fra la corda e il loro punto fisso. molle 0.016 dà la
	# pancia di sempre (~7 cm su questa campata). ---
	var maestre := {}
	for sx2: float in [-0.44, 0.44]:
		var da: Vector3 = attacchi[Vector2(sx2, -0.47)]
		var a: Vector3 = attacchi[Vector2(sx2, 0.47)]
		var viva := _corda_viva(n, da, a, 0.016, 0.016, rope, 0.5, 12, 8)
		viva.name = "Maestra_sx" if sx2 < 0.0 else "Maestra_dx"
		maestre[sx2] = viva

	# --- le due corde portanti: corrono sotto il bordo delle assi,
	# seguono la STESSA curva del piano, e muoiono alla base dei pali ---
	for sx3: float in [-0.40, 0.40]:
		var punti2: Array = []
		var raggi2: Array = []
		for k2 in 7:
			var z2 := lerpf(-0.50, 0.50, float(k2) / 6.0)
			var y2: float = dip.call(clampf(z2, -0.415, 0.415)) - 0.034
			if absf(z2) > 0.46:
				y2 -= 0.02     # scende ad annodarsi al piede del palo
			punti2.append(Vector3(sx3, y2, z2))
			raggi2.append(0.014)
		BUILDER.tube(n, punti2, raggi2, rope, 20, 8)
		# il nodo alle due estremità
		for sz3: float in [-0.50, 0.50]:
			_ball(n, 0.024, rope_dark,
					Vector3(sx3, dip.call(clampf(sz3, -0.415, 0.415)) - 0.054, sz3),
					Vector3(1.0, 0.8, 1.0))

	# --- le assi: SULLE corde portanti, seguendo curva e TANGENTE.
	# Larghezze diverse e imperfezioni piccolissime: un'asse posata a mano
	# è storta di millimetri, non di centimetri — con gli scarti grossi il
	# piano diventava una scalinata rotta. E le assi finiscono ALLE corde
	# portanti (±0.40), non oltre: più larghe, attraversavano i tiranti. ---
	var z_corr := -0.415
	while z_corr < 0.395:
		var largo := rng.randf_range(0.115, 0.150)
		var zc := minf(z_corr + largo * 0.5, 0.415 - largo * 0.5)
		var p2 := _box(n, Vector3(rng.randf_range(0.76, 0.80), 0.040, largo),
				plank, Vector3(rng.randf_range(-0.008, 0.008), dip.call(zc), zc))
		p2.rotation.x = atan(dip_slope.call(zc))
		p2.rotation.z = rng.randf_range(-0.013, 0.013)
		p2.rotation.y = rng.randf_range(-0.015, 0.015)
		z_corr += largo + rng.randf_range(0.005, 0.013)

	# --- i tiranti: dalla corda maestra alla corda portante, uno ogni
	# quarto. La cima si legge dalla POSA VERA della corda (campiona), il
	# fondo dal piano — e nel meta della maestra ogni tirante dichiara
	# path, frazione e punto fisso: così quando la corda si muove, il
	# gestore lo ritende e il nodino resta sulla corda. ---
	for sx4: float in [-0.44, 0.44]:
		var viva2: MeshInstance3D = maestre[sx4]
		var posa: Array = viva2.get_meta("posa")
		var da3: Vector3 = attacchi[Vector2(sx4, -0.47)]
		var a3: Vector3 = attacchi[Vector2(sx4, 0.47)]
		var elenco: Array = []
		for k3 in 4:
			var z3 := lerpf(-0.33, 0.33, float(k3) / 3.0)
			var u3 := clampf((z3 - da3.z) / (a3.z - da3.z), 0.0, 1.0)
			var su: Vector3 = FISICA.campiona(posa, u3)
			var giu := Vector3(signf(sx4) * 0.40, dip.call(z3) - 0.034, z3)
			var nome_t := "Tirante_%s_%d" % ["sx" if sx4 < 0.0 else "dx", k3]
			var t2 := _cyl(n, 0.008, 0.008, su.distance_to(giu), rope_dark,
					(su + giu) * 0.5)
			t2.name = nome_t
			t2.quaternion = Quaternion(Vector3.UP, (su - giu).normalized())
			# i nodini dove il tirante morde le due corde
			var palla := _ball(n, 0.015, rope_dark, su, Vector3(1.0, 0.75, 1.0))
			palla.name = nome_t + "_nodo"
			_ball(n, 0.013, rope_dark, giu, Vector3(1.0, 0.8, 1.0))
			elenco.append({"path": NodePath("../" + nome_t), "t": u3,
					"fondo": giu, "resto": su.distance_to(giu),
					"nodino": NodePath("../" + nome_t + "_nodo")})
		var meta2: Dictionary = viva2.get_meta("corda")
		meta2["tiranti"] = elenco
		viva2.set_meta("corda", meta2)

	# --- il capo di corda avanzato: pende da un palo, LIBERO — è la corda
	# più viva di tutte, quella che il vento agita per prima. Il nodo in
	# punta è un appeso: segue la coda dovunque vada. ---
	var capo_da: Vector3 = attacchi[Vector2(0.44, -0.47)]
	var capo := _corda_viva(n, capo_da, capo_da + Vector3(0, -0.19, 0),
			0.04, 0.009, rope_dark, 1.4, 8, 6, true)
	capo.name = "Capo"
	var nodo_capo := _ball(n, 0.016, rope_dark, capo_da + Vector3(0, -0.198, 0))
	nodo_capo.name = "NodoCapo"
	var meta3: Dictionary = capo.get_meta("corda")
	meta3["appesi"] = [{"path": NodePath("../NodoCapo"), "t": 1.0, "giu": 0.0}]
	capo.set_meta("corda", meta3)
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
	# la lanterna del ballatoio: deve accendere il ponte E arrivare al
	# tronco, se no «c'è qualcuno lassù» non si vede da terra. Più su di
	# così (2.6) il tavolato va in bianco e perde le venature.
	var light := OmniLight3D.new()
	light.light_color = Color("ffc98a")
	light.light_energy = 1.9
	light.omni_range = 4.4
	light.omni_attenuation = 1.1
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
	# LA CASSETTA DELLA POSTA. Animabile dal sistema posta, e i suoi tre
	# nodi sono un CONTRATTO: "Lid" (sportello incernierato in basso),
	# "Flag" (bandierina: rotation.x 0 = alzata, -1.35 = giu'), "Letter"
	# (la busta che fa capolino). Il fronte guarda verso -Z. Perni e assi
	# NON si toccano: Mail.gd li anima con quei numeri.
	# Il resto e' falegnameria: il palo tornito col collare e la
	# mensola col vassoio su cui la cassetta sta APPOGGIATA, il bordo chiaro dell'imboccatura, le
	# fasce sul barile, le cerniere dello sportello e la boccola d'ottone
	# della bandierina.
	var n := Node3D.new()
	var legno := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	var chiaro := _mat(WOOD_PALE, WOOD, 3.0, 0.45)
	var ottone := _mat(OTTONE, OTTONE_SCURO, 5.0, 0.4)
	var body := _mat(Color("d97f7f"), Color("c26a6a"), 4.0, 0.45)
	var body_scuro := _mat(Color("c26a6a"), Color("a85858"), 4.0, 0.4)
	var crema := _mat(CREAM, Color("f0e4cc"), 4.0, 0.35)

	# il palo: base svasata, fusto rastremato, collare sotto la mensola
	_cyl(n, 0.052, 0.068, 0.06, legno, Vector3(0, 0.03, 0))
	_cyl(n, 0.030, 0.045, 0.76, legno, Vector3(0, 0.44, 0))
	_cyl(n, 0.047, 0.040, 0.025, legno, Vector3(0, 0.815, 0))
	# la mensola col vassoio, e la saetta che la regge
	_box(n, Vector3(0.20, 0.022, 0.30), legno, Vector3(0, 0.836, 0.01))
	_box(n, Vector3(0.27, 0.018, 0.37), chiaro, Vector3(0, 0.856, 0.01))

	# il corpo a barile, appoggiato sul vassoio
	_box(n, Vector3(0.24, 0.2, 0.34), body, Vector3(0, 0.965, 0.01))
	_cyl(n, 0.12, 0.12, 0.36, body, Vector3(0, 1.065, 0.01)).rotation.x = PI * 0.5
	# le due fasce piu' cupe che abbracciano il barile
	for fz: float in [-0.06, 0.09]:
		var arco := _cyl(n, 0.1225, 0.1225, 0.024, body_scuro, Vector3(0, 1.065, fz))
		arco.rotation.x = PI * 0.5
		_box(n, Vector3(0.245, 0.2, 0.024), body_scuro, Vector3(0, 0.965, fz))
	# il bordo CHIARO dell'imboccatura: la bocca ha una cornice, non un
	# taglio vivo
	_box(n, Vector3(0.25, 0.205, 0.018), crema, Vector3(0, 0.9625, -0.156))
	var bocca := _cyl(n, 0.125, 0.125, 0.018, crema, Vector3(0, 1.065, -0.156))
	bocca.rotation.x = PI * 0.5
	# fondo scuro dell'imboccatura, svelato dallo sportello aperto
	_box(n, Vector3(0.2, 0.16, 0.012), _mat(Color("4a3230"), Color("3a2624"), 3.0, 0.4),
			Vector3(0, 0.965, -0.150))

	# la busta, nascosta finche' non arriva posta (nodo "Letter")
	var letter := _box(n, Vector3(0.15, 0.105, 0.012),
			_mat(CREAM, Color("f3e6d0"), 5.0, 0.35), Vector3(0, 0.975, -0.125))
	letter.name = "Letter"
	letter.rotation.x = -0.3
	letter.visible = false
	_ball(letter, 0.016, _mat(PINK_DEEP, PINK, 4.0, 0.3), Vector3(0, 0.0, -0.01))

	# lo sportello (nodo "Lid"), incernierato sul bordo basso del fronte:
	# l'anta bombata col pannello, il pomello, e le due cerniere d'ottone
	var lid := Node3D.new()
	lid.name = "Lid"
	lid.position = Vector3(0, 0.865, -0.175)
	n.add_child(lid)
	_box(lid, Vector3(0.22, 0.19, 0.016), _mat(Color("e89090"), Color("d47a7a"), 4.0, 0.45),
			Vector3(0, 0.095, 0))
	_box(lid, Vector3(0.17, 0.14, 0.010), _mat(Color("d47a7a"), Color("c26a6a"), 4.0, 0.4),
			Vector3(0, 0.10, -0.010))
	_ball(lid, 0.018, _mat(CREAM, WOOD_PALE, 4.0, 0.3), Vector3(0, 0.155, -0.014))
	for cx: float in [-0.07, 0.07]:
		_box(lid, Vector3(0.028, 0.018, 0.020), ottone, Vector3(cx, 0.004, 0.004))

	# la bandierina (nodo "Flag"): la boccola d'ottone sul fianco e' fissa,
	# il braccio con la paletta ruota — abbassata di default, si alza
	# quando arriva una lettera
	var boccola := _cyl(n, 0.020, 0.020, 0.018, ottone, Vector3(0.132, 1.01, 0.08))
	boccola.rotation.z = PI * 0.5
	var flag := Node3D.new()
	flag.name = "Flag"
	flag.position = Vector3(0.135, 1.01, 0.08)
	flag.rotation.x = -1.35
	n.add_child(flag)
	var yellow := _mat(Color("ffd76e"), Color("eec254"), 4.0, 0.4)
	_box(flag, Vector3(0.016, 0.16, 0.030), yellow, Vector3(0, 0.08, 0))
	_box(flag, Vector3(0.016, 0.055, 0.095), yellow, Vector3(0, 0.145, -0.055))
	_ball(flag, 0.013, ottone, Vector3(0.0, 0.0, 0.0))
	return n


## LA PANCHINA da parco, rifatta. Prima era due lastroni per gambe e
## quattro assi a coltello. Lo schienale RESTA a -Z: e' la convenzione
## di tutto l'ecosistema NPC (r_bench, il passerotto sullo schienale,
## l'approccio da +0.7z, SEATS a +0.08) — quindi dev'essere bella da
## TUTTI i lati, come una panchina vera in mezzo a un prato:
##  · fianchi torniti (lathe) col pomello, gamba dietro inclinata che
##    SALE a fare da montante dello schienale — un pezzo solo;
##  · BRACCIOLI a ricciolo (tube): partono dal montante e si arrotolano
##    sopra la gamba davanti;
##  · sedile a tre doghe stondate (_lastra), quella centrale un filo
##    piu' bassa: la conca di chi ci si siede;
##  · schienale con la doga alta ARCUATA (_loft) e i bulloncini d'ottone
##    dove le doghe incontrano i montanti;
##  · piedini scuri, perche' il legno non tocchi mai la terra bagnata.
## Ogni quota dello schienale si DERIVA dall'inclinazione dei montanti.
static func _bench() -> Node3D:
	var n := Node3D.new()
	var legno := _mat(WOOD, WOOD_DARK, 4.0, 0.55)
	var chiaro := _mat(WOOD_PALE, WOOD, 3.5, 0.5)
	var scuro := _mat(WOOD_DARK, Color("6d4f31"), 4.0, 0.45)
	var ottone := _mat(OTTONE, OTTONE_SCURO, 5.0, 0.4)
	var incl := 0.13
	var y_sed := 0.44
	# l'asse dei montanti dietro: VERTICALE fino al sedile, poi si corica.
	# (Con la pendenza da terra la panchina sembrava cedere all'indietro:
	# nelle panchine vere il ginocchio sta sotto il sedile.)
	var zm := func(y: float) -> float: \
			return -0.148 - maxf(y - y_sed, 0.0) * sin(incl)

	for sx: float in [-1.0, 1.0]:
		# la gamba davanti: UN pezzo tornito dalla terra al capitello —
		# attraversa il sedile e diventa la colonnina su cui ATTERRA il
		# bracciolo (prima il ricciolo finiva a mezz'aria: un bracciolo
		# che non appoggia su niente non e' un bracciolo)
		BUILDER.lathe(n, [Vector2(0.001, 0.0), Vector2(0.030, 0.0),
				Vector2(0.034, 0.010), Vector2(0.028, 0.024),
				Vector2(0.025, 0.20), Vector2(0.028, 0.30),
				Vector2(0.032, 0.36), Vector2(0.028, 0.40),
				Vector2(0.023, 0.46), Vector2(0.019, 0.50),
				Vector2(0.0175, 0.525), Vector2(0.022, 0.545),
				Vector2(0.0255, 0.556), Vector2(0.021, 0.566),
				Vector2(0.001, 0.570)], legno,
				Vector3(sx * 0.40, 0.0, 0.155))
		# la gamba dietro: dritta fino al sedile...
		BUILDER.lathe(n, [Vector2(0.001, 0.0), Vector2(0.030, 0.0),
				Vector2(0.034, 0.010), Vector2(0.028, 0.024),
				Vector2(0.026, 0.30), Vector2(0.025, y_sed + 0.02),
				Vector2(0.001, y_sed + 0.02)], legno,
				Vector3(sx * 0.40, 0.0, -0.148))
		# ...e il montante che si reclina DA LI', col pomello tornito
		var mont := BUILDER.lathe(n, [Vector2(0.001, 0.0), Vector2(0.025, 0.0),
				Vector2(0.023, 0.18), Vector2(0.026, 0.26),
				Vector2(0.028, 0.315), Vector2(0.023, 0.35),
				Vector2(0.015, 0.372), Vector2(0.024, 0.386),
				Vector2(0.0265, 0.40), Vector2(0.022, 0.416),
				Vector2(0.012, 0.432), Vector2(0.001, 0.438)], legno,
				Vector3(sx * 0.40, y_sed, -0.148))
		mont.rotation.x = -incl
		# IL BRACCIOLO a ricciolo: dal montante scende in avanti e CHIUDE
		# il ricciolo esattamente sul capitello della colonnina (0.155):
		# la spirale si avvolge sopra il punto d'appoggio, come il legno
		# piegato delle panchine vere
		BUILDER.tube(n, [Vector3(sx * 0.40, 0.615, zm.call(0.615) + 0.02),
				Vector3(sx * 0.40, 0.648, -0.02),
				Vector3(sx * 0.40, 0.655, 0.065),
				Vector3(sx * 0.40, 0.642, 0.130),
				Vector3(sx * 0.40, 0.616, 0.172),
				Vector3(sx * 0.40, 0.585, 0.180),
				Vector3(sx * 0.40, 0.566, 0.162),
				Vector3(sx * 0.40, 0.572, 0.140),
				Vector3(sx * 0.40, 0.590, 0.132)],
				[0.020, 0.021, 0.022, 0.022, 0.023, 0.023, 0.019, 0.015, 0.011],
				chiaro, 30, 10)
		# i piedini scuri sotto le due gambe
		_cyl(n, 0.036, 0.032, 0.014, scuro, Vector3(sx * 0.40, 0.007, 0.155))
		_cyl(n, 0.036, 0.032, 0.014, scuro, Vector3(sx * 0.40, 0.007, -0.150))

	# la traversa sotto il sedile, fra i due fianchi
	_box(n, Vector3(0.80, 0.05, 0.045), legno, Vector3(0, 0.375, 0.02))

	# ---- IL SEDILE: tre doghe stondate, la centrale un filo piu' bassa ----
	for d in 3:
		var dz := -0.13 + 0.13 * float(d)
		var giu := 0.006 if d == 1 else 0.0
		_lastra(n, 0.062, 0.94, 0.018, 0.034, chiaro,
				Vector3(0, y_sed + 0.017 - giu, dz), Vector3(0, 0, PI * 0.5))

	# ---- LO SCHIENALE: la doga alta arcuata, la bassa dritta, i bulloni ----
	var y_alta := 0.745
	var perno_a := Node3D.new()
	perno_a.position = Vector3(0, y_alta, zm.call(y_alta) + 0.030)
	perno_a.rotation.x = -incl
	n.add_child(perno_a)
	var staz: Array = []
	for k in 7:
		var fx := float(k) / 6.0 * 2.0 - 1.0
		staz.append([fx * 0.435, 0.017,
				-0.052 - 0.010 * cos(fx * 1.35), 0.052 + 0.026 * cos(fx * 1.35),
				0.010])
	_loft(perno_a, staz, chiaro)
	var y_bassa := 0.585
	var perno_b := Node3D.new()
	perno_b.position = Vector3(0, y_bassa, zm.call(y_bassa) + 0.028)
	perno_b.rotation.x = -incl
	n.add_child(perno_b)
	var staz2: Array = []
	for k2 in 5:
		var fx2 := float(k2) / 4.0 * 2.0 - 1.0
		staz2.append([fx2 * 0.435, 0.015, -0.044, 0.044, 0.009])
	_loft(perno_b, staz2, chiaro)
	# i bulloncini d'ottone dove le doghe incontrano i montanti
	for bx: float in [-1.0, 1.0]:
		for quota: Array in [[y_alta, 0.050], [y_bassa, 0.046]]:
			_ball(n, 0.0085, ottone, Vector3(bx * 0.40, float(quota[0]),
					zm.call(float(quota[0])) + float(quota[1])),
					Vector3(1, 1, 0.6))
	# DOVE SI STA, dichiarato dal MOBILE. Visitor teneva due costanti
	# scritte a mano — la seduta (0, 0.52, 0.02) e il posatoio del
	# passerotto (0, 0.86, -0.18) — tarate sulla panchina VECCHIA. Con la
	# doga alta rifatta, che finisce a 0.8245, il passerotto si sarebbe
	# appollaiato 3,5 cm sopra il legno e 2 cm dietro: appeso al vento.
	# Il numero adesso vive dove vive la forma, e chi rifa' la panchina lo
	# rifa' con lei.
	n.set_meta("seduta", Vector3(0, y_sed + 0.089, 0.02))
	n.set_meta("posatoio", Vector3(0, 0.8105, -0.159))
	return n


static func _player_stall() -> Node3D:
	var n := Node3D.new()
	var pale := _mat(WOOD_PALE, WOOD, 3.0, 0.45)
	var wood := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	var scuro := _mat(WOOD_DARK, Color("8a6540"), 4.0, 0.5)
	var menta := _mat(Color("9fd8cf"), Color("86c2b8"), 4.0, 0.4)
	var crema := _mat(CREAM, Color("f0e2cc"), 4.0, 0.4)
	var spago := _mat(Color("d9c08a"), Color("c0a878"), 10.0, 0.4)

	# zoccolo e cassa stondata
	var zocc := _prisma(n, _rrect_xz(1.16, 0.60, 0.04), 0.0, 0.09, scuro)
	zocc.position.z = 0.0
	var cassa := _prisma(n, _rrect_xz(1.06, 0.48, 0.035), 0.09, 0.70, pale)
	cassa.position.z = 0.0
	# le DOGHE con le fughe, sul fronte E sul retro (il catalogo guarda
	# il retro: una cassa liscia era una scatola da scarpe)
	for lato_z: float in [0.245, -0.245]:
		var xd := -0.46
		for d in 6:
			var wd: float = [0.155, 0.135, 0.150, 0.140, 0.155, 0.145][d]
			var doga := _prisma(n, _rrect_xz(wd, 0.045, 0.014), 0.13, 0.60, wood)
			doga.position = Vector3(xd + wd * 0.5, 0.0, lato_z)
			xd += wd + 0.012
	# le specchiature incassate sui fianchi
	for lato_x: float in [-0.535, 0.535]:
		_lastra(n, 0.145, 0.50, 0.03, 0.012, wood, Vector3(lato_x, 0.44, 0))

	# il PIANO chiaro con la fascia scura e il naso bombato
	var piano := _prisma(n, _rrect_xz(1.24, 0.60, 0.045), 0.79, 0.06, pale)
	piano.position.z = 0.0
	var fascia := _prisma(n, _rrect_xz(1.25, 0.61, 0.045), 0.782, 0.022, wood)
	fascia.position.z = 0.0
	var naso := _cyl(n, 0.024, 0.024, 1.18, wood, Vector3(0, 0.842, 0.295))
	naso.rotation.z = PI * 0.5

	# il RUNNER di stoffa a righe sotto le alzatine, coi lembi che
	# pendono dai lati corti
	var runner := _prisma(n, _rrect_xz(1.30, 0.34, 0.03), 0.851, 0.008, crema)
	runner.position.z = 0.02
	for r in 2:
		_box(n, Vector3(1.30, 0.004, 0.028), menta,
				Vector3(0, 0.8585, 0.02 - 0.10 + 0.20 * float(r)))
	for lx: float in [-0.628, 0.628]:
		var lembo := _lastra(n, 0.155, 0.15, 0.03, 0.010, crema,
				Vector3(lx, 0.792, 0.02), Vector3(0, 0, 0.05 * signf(lx)))
		lembo.rotation.y = 0.0
		_box(lembo, Vector3(0.006, 0.14, 0.026), menta, Vector3(0, 0, 0))

	# le TRE ALZATINE tornite (cima a 0.915: la merce si posa a 0.94)
	for sx: float in [-0.38, 0.0, 0.38]:
		_cyl(n, 0.052, 0.062, 0.022, wood, Vector3(sx, 0.876, 0.02))
		_cyl(n, 0.024, 0.030, 0.022, wood, Vector3(sx, 0.895, 0.02))
		_cyl(n, 0.098, 0.086, 0.016, wood, Vector3(sx, 0.905, 0.02))
		_cyl(n, 0.102, 0.098, 0.007, scuro, Vector3(sx, 0.9155, 0.02))

	# i MONTANTI torniti col pomello, e la traversa dietro
	for sx2: float in [-0.56, 0.56]:
		_cyl(n, 0.026, 0.034, 1.46, wood, Vector3(sx2, 0.80, -0.18))
		_cyl(n, 0.030, 0.030, 0.016, scuro, Vector3(sx2, 1.538, -0.18))
		_ball(n, 0.034, wood, Vector3(sx2, 1.576, -0.18))
	var trave := _cyl(n, 0.018, 0.018, 1.10, wood, Vector3(0, 1.50, -0.18))
	trave.rotation.z = PI * 0.5

	# LA FALDA DI TELA: sei strisce che SI INSACCANO fra la traversa e
	# il filo davanti — stoffa, non assi
	var falda := Node3D.new()
	falda.name = "Falda"
	falda.position = Vector3(0, 1.535, -0.02)
	falda.rotation.x = -0.13
	n.add_child(falda)
	var sagoma: Array = [Vector2(0.42, 0.0), Vector2(0.21, -0.030),
			Vector2(0.0, -0.044), Vector2(-0.21, -0.030), Vector2(-0.42, 0.0)]
	for i in 6:
		var x0 := -0.65 + 0.2167 * float(i)
		var mat_t: Material = menta if i % 2 == 0 else crema
		_vetro_curvo(falda, x0, x0 + 0.2167, sagoma, mat_t)
		# la MANTOVANA: il lembo che pende dal filo davanti, con lo
		# smerlo di mezza palla in punta
		_lastra(falda, 0.105, 0.115, 0.028, 0.012, mat_t,
				Vector3(x0 + 0.108, -0.058, 0.425), Vector3(0, PI * 0.5, 0))
		_ball(falda, 0.052, mat_t, Vector3(x0 + 0.108, -0.118, 0.425),
				Vector3(1.75, 0.85, 0.30))
	# il colmo: il rotolino di tela sulla traversa
	var colmo := _cyl(falda, 0.026, 0.026, 1.30, crema, Vector3(0, 0.005, -0.42))
	colmo.rotation.z = PI * 0.5

	# il CARTELLINO di legno sul fianco, appeso allo spago col nodo
	var targa := _lastra(n, 0.115, 0.17, 0.025, 0.022, pale,
			Vector3(0.645, 0.565, 0.30), Vector3(0, 0, -0.08))
	targa.rotation.y = PI * 0.5
	var filo := _cyl(n, 0.007, 0.007, 0.15, spago, Vector3(0.635, 0.720, 0.295))
	filo.rotation.x = 0.12
	_ball(n, 0.013, spago, Vector3(0.633, 0.790, 0.292))

	# la CASSETTINA delle arance, a terra accanto allo zoccolo
	var cass := Node3D.new()
	cass.position = Vector3(0.38, 0.0, 0.40)
	cass.rotation.y = 0.28
	n.add_child(cass)
	for sponda_z: float in [-0.075, 0.075]:
		_box(cass, Vector3(0.24, 0.085, 0.014), wood, Vector3(0, 0.058, sponda_z))
	for sponda_x: float in [-0.115, 0.115]:
		_box(cass, Vector3(0.014, 0.085, 0.16), wood, Vector3(sponda_x, 0.058, 0))
	_box(cass, Vector3(0.22, 0.012, 0.14), wood, Vector3(0, 0.022, 0))
	var arancia := _mat(Color("e8934a"), Color("cc7a36"), 5.0, 0.45)
	_ball(cass, 0.042, arancia, Vector3(-0.05, 0.075, -0.02))
	_ball(cass, 0.042, arancia, Vector3(0.05, 0.072, 0.025))
	_ball(cass, 0.040, arancia, Vector3(0.005, 0.115, -0.005))
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
	# la corda del bucato: VIVA ma tesa (molle piccolo) e col vento quasi
	# a zero — i teli di VitaSecondaria le stanno appesi con la loro onda
	# shader, e una corda che ballasse troppo li lascerebbe a mezz'aria
	var corda := _mat(Color("d9c08a"), Color("c0a878"), 10.0, 0.4)
	_corda_viva(n, Vector3(-0.55, 1.12, 0), Vector3(0.55, 1.12, 0),
			0.035, 0.012, corda, 0.15, 9, 6)
	# il cestello del bucato, di vimini, appoggiato a un palo
	var vimini := _mat(Color("c9a86a"), Color("a8874c"), 5.0, 0.5)
	_box(n, Vector3(0.24, 0.15, 0.17), vimini, Vector3(0.36, 0.08, 0.16))
	_box(n, Vector3(0.26, 0.03, 0.19), _mat(Color("b8935a"), Color("97783f"), 5.0, 0.5),
			Vector3(0.36, 0.16, 0.16))
	return n


# IL CARILLON: la scatola di ciliegio che cambia la musica del villaggio.
# Il MECCANISMO sta in vista, ed e' lui il pezzo: il rullo d'ottone con
# le puntine vere disposte a spirale, il PETTINE coi denti a scalare
# (i bassi lunghi, gli acuti corti: e' cosi' che un pettine suona), il
# ruotino dentato che porta il moto, e la manovella a gomito con
# l'impugnatura tornita di ciliegio. La cassa ha il filetto d'ottone,
# l'intarsio a rombo sul fronte e la targhetta. La musica vera la mette
# Interactions (E per caricarlo): qui il corpo — coi nomi (Manovella,
# Rullo) gia' pronti per chi un giorno vorra' farli girare.
static func _musicbox() -> Node3D:
	var n := Node3D.new()
	var ciliegio := _mat(Color("b06a4a"), Color("8f5238"), 4.0, 0.5)
	var ciliegio_s := _mat(Color("8a4f36"), Color("6e3d29"), 4.0, 0.5)
	var ottone := _mat(Color("e8c46a"), Color("c49c48"), 5.0, 0.35)
	var ottone_s := _mat(Color("c9a24a"), Color("a67f33"), 5.0, 0.35)
	var chiaro := _mat(Color("d9a878"), Color("bf8d5e"), 4.5, 0.45)

	# lo zoccolo scuro coi piedini a panetto
	var zocc := _prisma(n, _rrect_xz(0.42, 0.36, 0.03), 0.025, 0.075, ciliegio_s)
	zocc.position.z = 0.0
	for px: float in [-0.16, 0.16]:
		for pz: float in [-0.13, 0.13]:
			_ball(n, 0.026, ciliegio_s, Vector3(px, 0.018, pz),
					Vector3(1.0, 0.62, 1.0))

	# la cassa di ciliegio col filetto d'ottone e il coperchio
	var cassa := _prisma(n, _rrect_xz(0.38, 0.32, 0.028), 0.10, 0.28, ciliegio)
	cassa.position.z = 0.0
	var filo := _prisma(n, _rrect_xz(0.39, 0.33, 0.028), 0.38, 0.012, ottone_s)
	filo.position.z = 0.0
	var coper := _prisma(n, _rrect_xz(0.40, 0.34, 0.030), 0.392, 0.035, ciliegio)
	coper.position.z = 0.0

	# l'intarsio a rombo sul fronte, con la puntina d'ottone, e la
	# targhetta sotto il coperchio
	var rombo := _lastra(n, 0.028, 0.075, 0.012, 0.008, chiaro,
			Vector3(0, 0.24, -0.158), Vector3(0, PI * 0.5, PI * 0.25))
	rombo.rotation.x = 0.0
	_ball(n, 0.0085, ottone, Vector3(0, 0.24, -0.165))
	_lastra(n, 0.042, 0.028, 0.008, 0.006, ottone_s,
			Vector3(0, 0.352, -0.162), Vector3(0, PI * 0.5, 0))

	# IL RULLO, coi supporti a staffa e le PUNTINE a spirale
	var rullo := Node3D.new()
	rullo.name = "Rullo"
	rullo.position = Vector3(0, 0.475, 0.03)
	n.add_child(rullo)
	var tamburo := _cyl(rullo, 0.062, 0.062, 0.24, ottone, Vector3.ZERO)
	tamburo.rotation.z = PI * 0.5
	for i in 18:
		var a := float(i) * 2.1
		var lx := -0.10 + 0.2 * fmod(float(i) * 0.37, 1.0)
		_ball(rullo, 0.006, ottone_s,
				Vector3(lx, cos(a) * 0.066, sin(a) * 0.066))
	for sx: float in [-0.135, 0.135]:
		_box(n, Vector3(0.022, 0.085, 0.05), ottone_s,
				Vector3(sx, 0.455, 0.03))
		_ball(n, 0.016, ottone_s, Vector3(sx, 0.50, 0.03))

	# il PETTINE coi denti a scalare: i bassi lunghi, gli acuti corti
	_box(n, Vector3(0.26, 0.016, 0.045), ottone_s, Vector3(0, 0.43, -0.085))
	for d in 9:
		var lung := 0.062 - 0.0028 * float(d)
		_box(n, Vector3(0.017, 0.008, lung), ottone,
				Vector3(-0.104 + 0.026 * float(d), 0.436, -0.062 + lung * 0.5 - 0.03))

	# il RUOTINO dentato in punta al rullo, che porta il moto alla manovella
	var ruota := _cyl(n, 0.036, 0.036, 0.016, ottone_s, Vector3(0.155, 0.475, 0.03))
	ruota.rotation.z = PI * 0.5
	for dt in 8:
		var ad := float(dt) * PI * 0.25
		var dente := _box(n, Vector3(0.012, 0.014, 0.012), ottone_s,
				Vector3(0.155, 0.475 + cos(ad) * 0.042, 0.03 + sin(ad) * 0.042))
		dente.rotation.x = ad

	# LA MANOVELLA a gomito: boccola sul fianco, albero, braccio e
	# impugnatura tornita che gira folle
	var mano := Node3D.new()
	mano.name = "Manovella"
	mano.position = Vector3(0.19, 0.30, 0)
	n.add_child(mano)
	_cyl(mano, 0.030, 0.034, 0.018, ottone_s, Vector3(0.005, 0, 0)).rotation.z = PI * 0.5
	var albero := _cyl(mano, 0.013, 0.013, 0.075, ottone, Vector3(0.04, 0, 0))
	albero.rotation.z = PI * 0.5
	_ball(mano, 0.017, ottone_s, Vector3(0.078, 0, 0))
	_box(mano, Vector3(0.022, 0.10, 0.022), ottone, Vector3(0.078, -0.05, 0))
	# l'impugnatura sta LUNGO L'ALBERO (parallela a X, verso fuori):
	# e' cosi' che una mano la afferra e la fa girare
	var presa := _cyl(mano, 0.016, 0.018, 0.062, ciliegio, Vector3(0.112, -0.10, 0))
	presa.rotation.z = PI * 0.5
	_ball(mano, 0.019, ciliegio_s, Vector3(0.082, -0.10, 0))
	_ball(mano, 0.017, ciliegio_s, Vector3(0.142, -0.10, 0))
	return n


# la serra: un giardino di vetro col telaio chiaro e il tetto a capanna.
# Dentro, due vasi che sognano l'estate anche a gennaio.
# ============================================================================
# LA VETRERIA: la serra che smette di essere un pezzo e diventa un EDIFICIO
# ============================================================================
# Due serre vicine non sono due serre: sono una serra piu' grande. Il muro in
# mezzo non sparisce — diventa un'ARCATA — il colmo prosegue attraverso il
# confine, e fra due campate affiancate di traverso nasce il COMPLUVIO, il
# canale di rame che ogni serra a piu' navate ha. Con tre, quattro, nove
# campate cambia anche il mestiere di dentro: la serretta da giardino diventa
# galleria, poi giardino d'inverno, poi palmeria.
#
# COME STA IN PIEDI (e perche' non c'e' niente da salvare):
#  · la fusione e' DERIVATA dalle celle occupate, come coppia() in Affetti.
#    Il salvataggio resta una riga per cella: ricaricare ridera' lo stesso
#    edificio, e nessun villaggio va migrato.
#  · ogni cella disegna la PROPRIA campata guardandosi intorno (e' il
#    mestiere di aiuola_cella, portato su un edificio): niente capogruppo,
#    quindi ogni nodo tiene la sua identita', le sue collisioni e i suoi meta.
#  · il RETTANGOLO di ogni cella si spinge a 0.95 dove il lato e' aperto e a
#    0.50 dove di la' c'e' un'altra campata: la serra SOLA resta esattamente
#    quella di prima, 1.90 x 1.90.
#  · dove c'e' muro lo decide la COPERTURA (nessun altro rettangolo copre quel
#    filo); di chi e' il tetto lo decide la TENDA PIU' ALTA. Sono due regole
#    diverse, ed e' li' che si sbaglia: il tetto di due campate diagonali si
#    incontra sempre a meta' strada, a 2.19, che e' il compluvio.
#  · l'elemento condiviso (montante, canale, arcata) appartiene alla cella
#    LESSICOGRAFICAMENTE MINIMA fra quelle che lo toccano: nessun doppione.
#  · il dado dei dettagli e' della CELLA (hash della cella): aggiungere una
#    vicina cambia la forma, non l'arredamento gia' posato.

const SERRA_MURO := 0.95        # filo del muro dal centro cella
const SERRA_BORDO := 0.50       # confine fra due campate
const SERRA_RIENTRO := 0.05     # 1.00 - MURO: il rientro nell'angolo concavo
const SERRA_SPORTO := 1.02      # bordo di gronda sui lati aperti
const SERRA_GRONDA := 1.92
const SERRA_COLMO := 2.44
const SERRA_PENDENZA := 0.4636  # atan(0.5): la falda scende di 0.5 in 1.0
const SERRA_TELAIO := Color("e8e2d2")
const SERRA_TELAIO_B := Color("cfc8b4")


## LA PIANTA. Pura, deterministica, senza scena: da un insieme di celle
## escono l'asse del colmo, l'ancora, la porta, il cuore e i ruoli. E' la
## fonte unica da cui la geometria E le collisioni discendono.
static func serra_pianta(celle: Array) -> Dictionary:
	var s := {}
	for c in celle:
		s[c] = true
	if s.is_empty():
		s[Vector2i.ZERO] = true
	# L'ASSE DEL COLMO: quello con piu' adiacenze. Una cella sola da' 0 e 0,
	# cioe' X — il colmo della serra di sempre.
	var nx := 0
	var nz := 0
	for c: Vector2i in s:
		if s.has(c + Vector2i(1, 0)):
			nx += 1
		if s.has(c + Vector2i(0, 1)):
			nz += 1
	var asse := 0 if nx >= nz else 1
	# l'ancora: la cella lessicograficamente minima (mai un contatore, mai la
	# cella cliccata: al caricamento l'ordine delle righe e' quello del file)
	var ancora: Vector2i = Vector2i(9999, 9999)
	for c: Vector2i in s:
		if c.y < ancora.y or (c.y == ancora.y and c.x < ancora.x):
			ancora = c
	# LA PORTA: la campata piu' a nord col fianco -Z libero (il fronte del
	# catalogo). Con una cella sola e' lei, e la porta e' quella di sempre.
	var porta: Vector2i = ancora
	var trovata := false
	for c: Vector2i in s:
		if s.has(c + Vector2i(0, -1)):
			continue
		if not trovata or c.y < porta.y or (c.y == porta.y and c.x < porta.x):
			porta = c
			trovata = true
	# IL CUORE: una campata con tutti e quattro i vicini non ha nessuna
	# fascia — e' tutta corsia, e li' ci sta un albero.
	var cuore = null
	for c: Vector2i in s:
		if s.has(c + Vector2i(1, 0)) and s.has(c + Vector2i(-1, 0)) \
				and s.has(c + Vector2i(0, 1)) and s.has(c + Vector2i(0, -1)):
			if cuore == null or c.y < (cuore as Vector2i).y \
					or (c.y == (cuore as Vector2i).y and c.x < (cuore as Vector2i).x):
				cuore = c
	var n := s.size()
	var taglia := "sola"
	if n >= 7:
		taglia = "palmeria"
	elif n >= 4:
		taglia = "inverno"
	elif n >= 2:
		taglia = "galleria"
	# LA CAMPATA PIU' LONTANA dalla porta: e' li' che vanno i gradoni, ed e'
	# quello che si vede dalla soglia guardando in fondo.
	var fondo: Vector2i = porta
	var lontano := -1
	for c: Vector2i in s:
		var d := absi(c.x - porta.x) + absi(c.y - porta.y)
		if d > lontano or (d == lontano and (c.y < fondo.y
				or (c.y == fondo.y and c.x < fondo.x))):
			lontano = d
			fondo = c
	return {"celle": s, "asse": asse, "ancora": ancora, "porta": porta,
			"cuore": cuore, "fondo": fondo, "taglia": taglia, "n": n}


## Quanto si spinge il filo del lato `d` della cella `c` andando verso `t`.
## Tre righe che generano TUTTI i bordi: muretto, coprimuro, vetro, gronda,
## timpano e scatola di collisione. Il rientro a 0.05 e' l'angolo concavo
## della L: e' li' che il rettangolo della diagonale entra nel tuo.
static func serra_estremo(celle: Dictionary, c: Vector2i, d: Vector2i,
		t: Vector2i) -> float:
	if celle.has(c + t + d):
		return SERRA_RIENTRO
	if celle.has(c + t):
		return SERRA_BORDO
	return SERRA_MURO


## La voce a catalogo: la serra SOLA. Firma invariata (la chiamano
## _build_placed, il fantasma, i test e i due fotografi): il caso «sola» e'
## solo la pianta a una cella, come _flowerbed chiama aiuola_cella.
static func _greenhouse() -> Node3D:
	return serra_cella(serra_pianta([Vector2i.ZERO]), Vector2i.ZERO)


## LA CAMPATA: la geometria della cella `c` dentro `pianta`. Torna una radice
## col solo figlio «Vetreria», che porta il meta «scatole» (le collisioni,
## generate dalle STESSE variabili della geometria: non possono divergere).
static func serra_cella(pianta: Dictionary, c: Vector2i) -> Node3D:
	var radice := Node3D.new()
	var n := Node3D.new()
	n.name = "Vetreria"
	radice.add_child(n)
	var s: Dictionary = pianta["celle"]
	var asse := int(pianta["asse"])
	var taglia := str(pianta["taglia"])
	var quante := int(pianta["n"])
	# IL TELAIO DI RIFERIMENTO. La campata si disegna sempre con u = X e
	# v = Z; se il colmo del gruppo corre lungo Z, si gira tutto di -90° e
	# le domande sui vicini seguono lo stesso giro. Cosi' la geometria e'
	# scritta UNA volta sola.
	var gu := Vector2i(1, 0)
	var gv := Vector2i(0, 1)
	if asse == 1:
		n.rotation.y = -PI * 0.5
		gu = Vector2i(0, 1)
		gv = Vector2i(-1, 0)
	var seme := int(hash(c)) & 0x7fffffff
	var rng := RandomNumberGenerator.new()
	rng.seed = seme

	var telaio := _mat(SERRA_TELAIO, SERRA_TELAIO_B, 4.0, 0.4)
	var chiaro := _mat(WOOD_PALE, WOOD, 3.5, 0.5)
	var legno := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	var ottone := _mat(OTTONE, OTTONE_SCURO, 5.0, 0.4)
	var ghisa := _mat(Color("4a4640"), Color("343029"), 6.0, 0.35)
	var rame := _mat(Color("b98456"), Color("966542"), 6.0, 0.4)
	var cotto := _mat(TERRACOTTA, Color("c47a58"), 3.0, 0.5)
	var verde := _mat(LEAF, LEAF_DARK, 4.0, 0.5)
	var pietra := _mat(STONE, STONE_DARK, 4.0, 0.45)
	var vetro := _vetro(0.42)
	var scatole: Array = []

	# --- le quattro direzioni nel telaio locale: +u, -u, +v, -v
	var aperto := {}
	for k in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var g: Vector2i = gu * k.x + gv * k.y
		aperto[k] = not s.has(c + g)
	# gli estremi di ogni lato (quanto si spinge il filo, per verso)
	var est_p := {}
	var est_n := {}
	for d: Vector2i in aperto:
		var t := Vector2i(1, 0) if d.x == 0 else Vector2i(0, 1)
		var gd: Vector2i = gu * d.x + gv * d.y
		var gt: Vector2i = gu * t.x + gv * t.y
		est_p[d] = serra_estremo(s, c, gd, gt)
		est_n[d] = serra_estremo(s, c, gd, -gt)

	var lato_porta: bool = (c == pianta["porta"])
	var varco := 0.77 if quante == 1 else 1.10

	# ---------------------------------------------------------- LA PLATEA
	var px0 := -(SERRA_MURO if aperto[Vector2i(-1, 0)] else SERRA_BORDO)
	var px1 := (SERRA_MURO if aperto[Vector2i(1, 0)] else SERRA_BORDO)
	var pz0 := -(SERRA_MURO if aperto[Vector2i(0, -1)] else SERRA_BORDO)
	var pz1 := (SERRA_MURO if aperto[Vector2i(0, 1)] else SERRA_BORDO)
	_box(n, Vector3(px1 - px0, 0.06, pz1 - pz0), pietra,
			Vector3((px0 + px1) * 0.5, 0.03, (pz0 + pz1) * 0.5))

	# ---- LA CORSIA: lastre lungo le rette che uniscono i centri delle
	# campate adiacenti. Attraversa i confini e prosegue: e' il primo
	# dettaglio che dice «un edificio solo».
	var corsie: Array = []
	if not aperto[Vector2i(0, -1)] or lato_porta:
		corsie.append(Vector2i(0, -1))
	if not aperto[Vector2i(0, 1)]:
		corsie.append(Vector2i(0, 1))
	if not aperto[Vector2i(1, 0)]:
		corsie.append(Vector2i(1, 0))
	if not aperto[Vector2i(-1, 0)]:
		corsie.append(Vector2i(-1, 0))
	if corsie.is_empty():
		corsie.append(Vector2i(0, -1))
	for dir: Vector2i in corsie:
		for k in 2:
			var t := 0.22 + float(k) * 0.44
			var pp := Vector3(float(dir.x), 0.0, float(dir.y)) * t
			_box(n, Vector3(0.52 if dir.x == 0 else 0.38, 0.014,
					0.38 if dir.x == 0 else 0.52), chiaro,
					Vector3(pp.x, 0.067, pp.z))
	_box(n, Vector3(0.52, 0.014, 0.52), chiaro, Vector3(0, 0.067, 0))

	# ------------------------------------------------- I LATI: muro o arcata
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1),
			Vector2i(0, -1)]:
		var e_pos: float = est_p[d]
		var e_neg: float = est_n[d]
		if aperto[d]:
			# ---- LATO CHIUSO: muretto, coprimuro, vetro a riquadri, gronda.
			# Il filo puo' spezzarsi in due tratti se c'e' la porta.
			var tratti: Array = []
			if lato_porta and d == Vector2i(0, -1):
				tratti.append([-e_neg, -varco * 0.5])
				tratti.append([varco * 0.5, e_pos])
			else:
				tratti.append([-e_neg, e_pos])
			for tr: Array in tratti:
				var a: float = tr[0]
				var b: float = tr[1]
				var len := b - a
				if len < 0.02:
					continue
				var mid := (a + b) * 0.5
				# posizione: sul filo del lato, spostata lungo la tangente
				var fil := Vector3(float(d.x), 0.0, float(d.y)) * SERRA_MURO
				var tan := Vector3(0, 0, 1) if d.x != 0 else Vector3(1, 0, 0)
				var base := fil + tan * mid
				var sz := func(l: float, h: float, sp: float) -> Vector3:
					return Vector3(sp, h, l) if d.x != 0 else Vector3(l, h, sp)
				_box(n, sz.call(len, 0.24, 0.07), telaio,
						Vector3(base.x, 0.18, base.z))
				_box(n, sz.call(len + 0.05, 0.035, 0.09), telaio,
						Vector3(base.x, 0.317, base.z))
				_box(n, sz.call(maxf(len - 0.09, 0.05), 1.52, 0.035), vetro,
						Vector3(base.x, 1.09, base.z))
				for ty: float in [0.92, 1.46]:
					_box(n, sz.call(maxf(len - 0.09, 0.05), 0.045, 0.04), telaio,
							Vector3(base.x, ty, base.z))
				# i montanti intermedi: la griglia dei riquadri
				var quanti := int(len / 0.62)
				for k in quanti:
					var q := a + len * (float(k) + 1.0) / float(quanti + 1)
					var pm := fil + tan * q
					_box(n, Vector3(0.07, 1.52, 0.07), telaio,
							Vector3(pm.x, 1.09, pm.z))
				# la gronda
				_box(n, sz.call(len, 0.06, 0.09), telaio,
						Vector3(base.x, SERRA_GRONDA, base.z))
				# collisione: il tratto di parete
				scatole.append([sz.call(len, 1.90, 0.12),
						Vector3(base.x, 0.95, base.z)])
			if lato_porta and d == Vector2i(0, -1):
				# il sopraluce sopra la porta
				scatole.append([Vector3(varco, 0.42, 0.12),
						Vector3(0, 1.76, -SERRA_MURO)])
		else:
			# ---- LATO CONDIVISO: l'ARCATA. Il muro non sparisce: diventa
			# un arco. Lo disegna la campata lessicograficamente minore.
			var gd: Vector2i = gu * d.x + gv * d.y
			var vicina := c + gd
			var mia: bool = (c.y < vicina.y) or (c.y == vicina.y and c.x < vicina.x)
			if not mia:
				continue
			var fil := Vector3(float(d.x), 0.0, float(d.y)) * SERRA_BORDO
			var tan := Vector3(0, 0, 1) if d.x != 0 else Vector3(1, 0, 0)
			for sg: float in [-1.0, 1.0]:
				var pp := fil + tan * (sg * SERRA_MURO)
				_box(n, Vector3(0.09, SERRA_GRONDA, 0.09), telaio,
						Vector3(pp.x, SERRA_GRONDA * 0.5, pp.z))
			if d.x != 0:
				# CONFINE SOTTO IL COLMO: l'ARCONE a cuspide, che segue il
				# profilo della tenda. Chi cammina in navata ne vede una
				# fila, una per campata: e' il colpo d'occhio del Crystal
				# Palace, e costa quattro scatole.
				for sg2: float in [-1.0, 1.0]:
					var falda := _box(n, Vector3(0.075, 0.07, 1.10), telaio,
							Vector3(fil.x, 2.14, sg2 * 0.49))
					falda.rotation.x = -sg2 * SERRA_PENDENZA
					var tirante := _box(n, Vector3(0.05, 0.045, 0.62), telaio,
							Vector3(fil.x, 1.99, sg2 * 0.30))
					tirante.rotation.x = -sg2 * 0.62
				_box(n, Vector3(0.07, 0.05, 1.86), telaio,
						Vector3(fil.x, 1.83, 0))
				_ball(n, 0.05, ottone, Vector3(fil.x, 2.30, 0), Vector3(1, 1.5, 1))
			else:
				# CONFINE SOTTO IL COMPLUVIO: architrave dritto e la
				# COLONNINA di ghisa tornita che lo regge — i canali delle
				# serre a piu' navate stanno in piedi cosi', e in un
				# quadrato di quattro se ne vede una sola, al centro.
				_box(n, Vector3(1.86, 0.09, 0.11), telaio,
						Vector3(0, SERRA_GRONDA, fil.z))
				for cx3: float in [-0.62, 0.62]:
					_cyl(n, 0.040, 0.050, SERRA_GRONDA - 0.14, telaio,
							Vector3(cx3, (SERRA_GRONDA - 0.14) * 0.5, fil.z))
					_cyl(n, 0.066, 0.046, 0.06, telaio,
							Vector3(cx3, SERRA_GRONDA - 0.11, fil.z))
					_cyl(n, 0.026, 0.026, 0.02, ottone,
							Vector3(cx3, SERRA_GRONDA - 0.17, fil.z))
					_cyl(n, 0.060, 0.074, 0.05, telaio, Vector3(cx3, 0.025, fil.z))

	# ---- I MONTANTI D'ANGOLO. Due fili di muro che si incontrano fanno un
	# angolo, e un angolo senza montante e' una fessura: in controluce, che
	# e' come si guarda una serra, si vede il cielo passare. Ce ne sono di
	# due specie: quelli CONVESSI del perimetro (0.95, 0.95) e quelli
	# CONCAVI del pizzico diagonale, dove i fili si fermano a 0.05 — e
	# quelli, toccati da due campate, li disegna la minore.
	for su: float in [-1.0, 1.0]:
		for sv: float in [-1.0, 1.0]:
			var au: bool = aperto[Vector2i(int(su), 0)]
			var av: bool = aperto[Vector2i(0, int(sv))]
			if not (au and av):
				continue
			var gdiag: Vector2i = gu * int(su) + gv * int(sv)
			if not s.has(c + gdiag):
				_box(n, Vector3(0.09, SERRA_GRONDA, 0.09), telaio,
						Vector3(su * SERRA_MURO, SERRA_GRONDA * 0.5, sv * SERRA_MURO))
				continue
			var vd := c + gdiag
			if not ((c.y < vd.y) or (c.y == vd.y and c.x < vd.x)):
				continue
			for coppia: Vector2 in [Vector2(SERRA_MURO, SERRA_RIENTRO),
					Vector2(SERRA_RIENTRO, SERRA_MURO)]:
				_box(n, Vector3(0.09, SERRA_GRONDA, 0.09), telaio,
						Vector3(su * coppia.x, SERRA_GRONDA * 0.5, sv * coppia.y))

	# ------------------------------------------------------------- IL TETTO
	# La tenda: y = COLMO - 0.5*|v|. Il tetto dell'edificio e' l'inviluppo
	# superiore delle tende, e per ogni zona di u la falda si ferma a 0.50
	# (se di la' c'e' una campata) o a 1.02 (lo sporto di gronda).
	var u_neg: float = SERRA_SPORTO if aperto[Vector2i(-1, 0)] else SERRA_BORDO
	var u_pos: float = SERRA_SPORTO if aperto[Vector2i(1, 0)] else SERRA_BORDO
	var zone: Array = [[-SERRA_BORDO, SERRA_BORDO, Vector2i(0, 0)]]
	if u_neg > SERRA_BORDO:
		zone.append([-u_neg, -SERRA_BORDO, Vector2i(-1, 0)])
	if u_pos > SERRA_BORDO:
		zone.append([SERRA_BORDO, u_pos, Vector2i(1, 0)])
	for dv: float in [-1.0, 1.0]:
		for z: Array in zone:
			var a: float = z[0]
			var b: float = z[1]
			var off: Vector2i = z[2]
			var g_diag: Vector2i = gu * off.x + gv * int(dv)
			var chiusa: bool = s.has(c + g_diag)
			var v_ext: float = SERRA_BORDO if chiusa else SERRA_SPORTO
			var len_u := b - a
			if len_u < 0.02:
				continue
			var falda := _box(n, Vector3(len_u, 0.03, v_ext * 1.118), vetro,
					Vector3((a + b) * 0.5, SERRA_COLMO - 0.25 * v_ext,
							dv * v_ext * 0.5))
			falda.rotation.x = dv * SERRA_PENDENZA
			# i correntini: il ritmo della struttura coincide col ritmo
			# delle campate, ed e' quello che fa leggere la taglia
			var passi := maxi(1, int(round(len_u / 0.52)))
			for k in passi + 1:
				var ux := a + len_u * float(k) / float(passi)
				var cr := _box(n, Vector3(0.05, 0.028, v_ext * 1.118), telaio,
						Vector3(ux, SERRA_COLMO - 0.25 * v_ext + 0.015,
								dv * v_ext * 0.5))
				cr.rotation.x = dv * SERRA_PENDENZA
			# la trave di gronda sul bordo basso, solo se il bordo e' vero
			if not chiusa:
				var gr := _box(n, Vector3(len_u, 0.05, 0.07), telaio,
						Vector3((a + b) * 0.5, SERRA_COLMO - 0.5 * v_ext,
								dv * v_ext))
				gr.rotation.x = dv * SERRA_PENDENZA
	# I LUCERNARI: uno per falda, incernierato al colmo e socchiuso di
	# poco. E' il dettaglio che toglie al tetto l'aria di prisma.
	for dv3: float in [-1.0, 1.0]:
		var gvv3: Vector2i = gv * int(dv3)
		var v_ap: float = SERRA_BORDO if s.has(c + gvv3) else SERRA_SPORTO
		if v_ap < 0.9:
			continue
		var cardine := Node3D.new()
		cardine.position = Vector3(rng.randf_range(-0.18, 0.18), SERRA_COLMO - 0.035, 0)
		cardine.rotation.x = dv3 * (SERRA_PENDENZA + rng.randf_range(0.16, 0.30))
		n.add_child(cardine)
		var telaietto := Node3D.new()
		telaietto.position = Vector3(0, 0, dv3 * 0.31)
		cardine.add_child(telaietto)
		_box(telaietto, Vector3(0.62, 0.022, 0.44), vetro, Vector3.ZERO)
		for lx3: float in [-0.31, 0.31]:
			_box(telaietto, Vector3(0.035, 0.03, 0.44), telaio, Vector3(lx3, 0.008, 0))
		for lz3: float in [-0.22, 0.22]:
			_box(telaietto, Vector3(0.62, 0.03, 0.035), telaio, Vector3(0, 0.008, lz3))
		# l'astina forata che lo tiene aperto
		var astina := _cyl(cardine, 0.008, 0.008, 0.30, ghisa,
				Vector3(0.22, -0.10, dv3 * 0.16))
		astina.rotation.x = dv3 * 0.9

	# il COLMO, un segmento per campata: si toccano sul confine e fanno
	# una riga continua
	_box(n, Vector3(u_pos + u_neg, 0.07, 0.07), telaio,
			Vector3((u_pos - u_neg) * 0.5, SERRA_COLMO, 0))
	for du: float in [-1.0, 1.0]:
		var fine: float = u_pos if du > 0.0 else u_neg
		if fine <= SERRA_BORDO:
			continue
		_cyl(n, 0.012, 0.016, 0.03, ottone, Vector3(du * fine, SERRA_COLMO + 0.05, 0))
		_ball(n, 0.026, ottone, Vector3(du * fine, SERRA_COLMO + 0.08, 0))
	# la CRESTA di ferro battuto: il segnale vittoriano piu' forte che
	# esista, e compare solo quando l'edificio e' grande
	if quante >= 4:
		var quante_punte: int = int((u_pos + u_neg) / 0.16)
		for k in quante_punte:
			var ux := -u_neg + 0.08 + float(k) * 0.16
			_box(n, Vector3(0.012, 0.07, 0.012), ghisa,
					Vector3(ux, SERRA_COLMO + 0.075, 0))
	# IL COMPLUVIO: dove due tende si incontrano, a 2.19, il canale di rame
	for dv2: float in [-1.0, 1.0]:
		var gvv: Vector2i = gv * int(dv2)
		if not s.has(c + gvv):
			continue
		var vic := c + gvv
		var mia2: bool = (c.y < vic.y) or (c.y == vic.y and c.x < vic.x)
		if not mia2:
			continue
		for sg3: float in [-1.0, 1.0]:
			var sponda := _box(n, Vector3(u_pos + u_neg, 0.02, 0.09), rame,
					Vector3((u_pos - u_neg) * 0.5, 2.205,
							dv2 * SERRA_BORDO + sg3 * 0.042))
			sponda.rotation.x = sg3 * SERRA_PENDENZA * dv2
		_box(n, Vector3(u_pos + u_neg, 0.018, 0.06), rame,
				Vector3((u_pos - u_neg) * 0.5, 2.17, dv2 * SERRA_BORDO))
	# I TIMPANI: la sagoma fra il profilo del proprio tetto e la gronda, sui
	# lati U chiusi. Due campate di traverso viste di testa danno due timpani
	# gemelli con la tacca del compluvio in mezzo: la W, l'immagine icona.
	for du2: float in [-1.0, 1.0]:
		var gdu: Vector2i = gu * int(du2)
		if s.has(c + gdu):
			continue
		var v_n: float = SERRA_BORDO if s.has(c - gv) else SERRA_MURO
		var v_p: float = SERRA_BORDO if s.has(c + gv) else SERRA_MURO
		var y_n := maxf(SERRA_GRONDA, SERRA_COLMO - 0.5 * v_n)
		var y_p := maxf(SERRA_GRONDA, SERRA_COLMO - 0.5 * v_p)
		var punti: Array[Vector2] = [
			Vector2(-v_n, SERRA_GRONDA - 0.02),
			Vector2(-v_n, y_n),
			Vector2(0.0, SERRA_COLMO),
			Vector2(v_p, y_p),
			Vector2(v_p, SERRA_GRONDA - 0.02)]
		var timpano := _prisma(n, punti, 0.0, 0.028, vetro)
		timpano.basis = Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0))
		timpano.position = Vector3(du2 * SERRA_MURO - du2 * 0.014, 0, 0)
		_box(n, Vector3(0.05, 0.46, 0.035), telaio,
				Vector3(du2 * SERRA_MURO, 2.17, 0))

	# -------------------------------------------------------------- LA PORTA
	if lato_porta:
		var zf := -SERRA_MURO
		if quante == 1:
			for ds: float in [-1.0, 1.0]:
				_box(n, Vector3(0.07, 1.62, 0.09), telaio,
						Vector3(ds * 0.42, 1.10, zf))
			_box(n, Vector3(0.92, 0.07, 0.09), telaio, Vector3(0, 1.60, zf))
			_box(n, Vector3(0.78, 0.28, 0.035), vetro, Vector3(0, 1.73, zf))
			for ante: float in [-1.0, 1.0]:
				var anta := Node3D.new()
				anta.position = Vector3(ante * 0.565, 0, zf + 0.065)
				n.add_child(anta)
				_box(anta, Vector3(0.38, 1.50, 0.028), vetro, Vector3(0, 0.815, 0))
				for ay: float in [0.10, 0.815, 1.53]:
					_box(anta, Vector3(0.38, 0.045, 0.04), telaio, Vector3(0, ay, 0))
				for ax: float in [-0.17, 0.17]:
					_box(anta, Vector3(0.04, 1.48, 0.04), telaio, Vector3(ax, 0.815, 0))
				_ball(n, 0.020, ottone, Vector3(ante * 0.40, 0.80, zf + 0.09))
		else:
			# IL PORTALE: luce 1.10, lunetta a raggiera e due gradini. Tutto
			# STA SOTTO LA GRONDA (1.92): un portale che sfonda il tetto non
			# e' un portale, e' un errore — la prima stesura arrivava a 2.46
			# e la pensilina volava sopra le falde.
			for ds2: float in [-1.0, 1.0]:
				_box(n, Vector3(0.12, 1.50, 0.11), telaio,
						Vector3(ds2 * 0.61, 0.75, zf))
			_box(n, Vector3(1.34, 0.09, 0.13), telaio, Vector3(0, 1.55, zf))
			var raggi := 7
			for k in raggi:
				var a0 := PI * float(k) / float(raggi)
				var a1 := PI * float(k + 1) / float(raggi)
				var pl: Array[Vector2] = [Vector2(0, 0),
						Vector2(cos(a0) * 0.28, sin(a0) * 0.28),
						Vector2(cos(a1) * 0.28, sin(a1) * 0.28)]
				var spicchio := _prisma(n, pl, 0.0, 0.026, vetro)
				spicchio.basis = Basis(Vector3(0, 0, 1), Vector3(1, 0, 0),
						Vector3(0, 1, 0))
				spicchio.position = Vector3(0, 1.60, zf - 0.013)
				var mont := _box(n, Vector3(0.03, 0.28, 0.035), telaio,
						Vector3(cos(a0) * 0.14, 1.60 + sin(a0) * 0.14, zf))
				mont.rotation.z = a0 - PI * 0.5
			# la cimasa di rame che chiude l'arco, sul filo del muro
			var arco := 9
			for k2 in arco:
				var aa := PI * (float(k2) + 0.5) / float(arco)
				var conc := _box(n, Vector3(0.10, 0.032, 0.05), rame,
						Vector3(cos(aa) * 0.295, 1.60 + sin(aa) * 0.295, zf))
				conc.rotation.z = aa - PI * 0.5
			for ante2: float in [-1.0, 1.0]:
				var anta2 := Node3D.new()
				anta2.position = Vector3(ante2 * 0.80, 0, zf + 0.07)
				n.add_child(anta2)
				_box(anta2, Vector3(0.52, 1.40, 0.03), vetro, Vector3(0, 0.75, 0))
				for ay2: float in [0.08, 0.75, 1.43]:
					_box(anta2, Vector3(0.54, 0.05, 0.045), telaio, Vector3(0, ay2, 0))
				for ax2: float in [-0.24, 0.24]:
					_box(anta2, Vector3(0.045, 1.38, 0.045), telaio, Vector3(ax2, 0.75, 0))
				_ball(n, 0.024, ottone, Vector3(ante2 * 0.56, 0.78, zf + 0.10))
			for k3 in 2:
				_box(n, Vector3(1.5 - float(k3) * 0.2, 0.05, 0.26 - float(k3) * 0.06),
						pietra, Vector3(0, 0.025 + float(k3) * 0.05,
								zf - 0.28 + float(k3) * 0.07))

	# ------------------------------------------------------------ GLI INTERNI
	# L'arredo non appartiene alla cella: appartiene alla PIANTA. Le FASCE
	# nascono dai lati chiusi, quindi cambiano da sole quando cambia il
	# gruppo — il salto e' radicale perche' TOGLIE, non perche' aggiunge.
	var fasce: Array = []
	for d2: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1)]:
		if aperto[d2] and not (lato_porta and d2 == Vector2i(0, -1)):
			fasce.append(d2)
	var e_cuore: bool = (pianta["cuore"] != null and c == pianta["cuore"])
	# le sedute che gli interni dichiarano strada facendo: si montano in
	# fondo, quando l'ancoraggio sa gia' cosa deve guardare
	var _sedute_serra: Array = []
	var e_fondo: bool = (c == pianta["fondo"] and quante >= 2)
	# la direzione LOCALE che va via dalla porta: e' li' che sta il fondo
	# della navata, e quello che si vede dalla soglia guardando dentro
	var via := Vector2i(0, 1)
	if quante >= 2:
		var dg: Vector2i = c - (pianta["porta"] as Vector2i)
		var vu := dg.x * gu.x + dg.y * gu.y
		var vv := dg.x * gv.x + dg.y * gv.y
		if absi(vu) >= absi(vv):
			via = Vector2i(signi(vu), 0) if vu != 0 else Vector2i(0, 1)
		else:
			via = Vector2i(0, signi(vv))

	if taglia == "sola":
		# la serretta da giardino: com'era, e come deve restare
		_box(n, Vector3(0.36, 0.03, 1.5), chiaro, Vector3(0.70, 0.52, 0.1))
		_box(n, Vector3(0.32, 0.022, 1.4), chiaro, Vector3(0.70, 0.22, 0.1))
		for lz: float in [-0.58, 0.78]:
			for lx: float in [0.56, 0.84]:
				_box(n, Vector3(0.035, 0.50, 0.035), chiaro, Vector3(lx, 0.26, lz + 0.02))
		scatole.append([Vector3(0.50, 1.00, 1.60), Vector3(0.70, 0.5, 0.1)])
		for vk in 3:
			var vx := 0.62 + float(vk % 2) * 0.16
			var vz := -0.38 + float(vk) * 0.42
			_cyl(n, 0.05, 0.06, 0.085, cotto, Vector3(vx, 0.578, vz))
			_ball(n, 0.06, verde, Vector3(vx, 0.66, vz), Vector3(1.0, 0.8, 1.0))
		for fk in 3:
			var fa := float(fk) * TAU / 3.0 + 0.4
			_ball(n, 0.015, _mat(PINK, PINK_DEEP, 5.0, 0.4),
					Vector3(0.62 + cos(fa) * 0.038, 0.70, -0.38 + sin(fa) * 0.038))
		var latta := _mat(Color("8aa89a"), Color("6f8d80"), 4.0, 0.4)
		_cyl(n, 0.062, 0.07, 0.13, latta, Vector3(0.70, 0.296, 0.62))
		var becco := _cyl(n, 0.011, 0.014, 0.15, latta, Vector3(0.61, 0.32, 0.57))
		becco.rotation.z = 1.05
		becco.rotation.y = -0.5
		_cyl(n, 0.024, 0.016, 0.02, latta, Vector3(0.555, 0.355, 0.54))
		_cyl(n, 0.055, 0.065, 0.07, cotto, Vector3(0.70, 0.10, -0.62))
		_cyl(n, 0.055, 0.065, 0.07, cotto, Vector3(0.72, 0.165, -0.60))
		# l'AIUOLA RIALZATA: c'e' solo qui. Una serra grande coltiva in vaso.
		_box(n, Vector3(0.44, 0.24, 1.5), legno, Vector3(-0.70, 0.18, 0.1))
		_box(n, Vector3(0.40, 0.02, 1.46), _mat(Color("5a4636"), Color("46362a"), 3.0, 0.4),
				Vector3(-0.70, 0.30, 0.1))
		scatole.append([Vector3(0.50, 0.62, 1.60), Vector3(-0.70, 0.31, 0.1)])
		for ak in 4:
			var az := -0.5 + float(ak) * 0.40
			var asc := 0.10 + 0.02 * float(ak % 2)
			_ball(n, asc, verde, Vector3(-0.70 + 0.06 * float(ak % 2 * 2 - 1),
					0.33 + asc * 0.6, az + 0.1), Vector3(1.0, 0.8, 1.0))
		for fk2 in 4:
			var fb := float(fk2) * TAU / 4.0 + 0.7
			_ball(n, 0.014, _mat(CREAM, Color("f3dfc8"), 5.0, 0.3),
					Vector3(-0.70 + cos(fb) * 0.10, 0.44, 0.20 + sin(fb) * 0.10))
		for sx4: float in [-0.44, 0.44]:
			_cyl(n, 0.09, 0.11, 0.14, cotto, Vector3(sx4, 0.13, -0.68))
			_ball(n, 0.11, verde, Vector3(sx4, 0.27, -0.68), Vector3(1.0, 0.85, 1.0))
	else:
		# LA GALLERIA e oltre: banconi CONTINUI sulle fasce, che attraversano
		# i confini, e i vasi sopra. Niente aiuola: si coltiva in vaso.
		for d3: Vector2i in fasce:
			var fil3 := Vector3(float(d3.x), 0.0, float(d3.y)) * 0.68
			var tan3 := Vector3(0, 0, 1) if d3.x != 0 else Vector3(1, 0, 0)
			var lung: float = float(est_p[d3]) + float(est_n[d3])
			var mid3: float = (float(est_p[d3]) - float(est_n[d3])) * 0.5
			if lung < 0.5:
				continue
			var base3: Vector3 = fil3 + tan3 * mid3
			var szf := func(l: float, h: float, sp: float) -> Vector3:
				return Vector3(sp, h, l) if d3.x != 0 else Vector3(l, h, sp)
			if e_fondo and d3 == via:
				# LA SCALINATA DEI VASI: tre gradoni sulla testata di fondo,
				# la fila di vasetti che sale. E' quello che si vede dalla
				# soglia guardando in fondo alla navata.
				for gk in 3:
					var gy := 0.30 + float(gk) * 0.22
					var gz := 0.86 - float(gk) * 0.15
					var pg3 := fil3 + tan3 * mid3 \
							- Vector3(float(d3.x), 0, float(d3.y)) * (float(gk) * 0.15)
					_box(n, szf.call(lung, 0.03, 0.15), chiaro,
							Vector3(pg3.x, gy, pg3.z))
					var quanti_v: int = maxi(2, int(lung / 0.30))
					for vk2 in quanti_v:
						var vx2: float = -lung * 0.5 + lung * (float(vk2) + 0.5) / float(quanti_v)
						var pv: Vector3 = pg3 + tan3 * vx2
						_cyl(n, 0.042, 0.05, 0.07, cotto,
								Vector3(pv.x, gy + 0.05, pv.z))
						_ball(n, 0.05, verde, Vector3(pv.x, gy + 0.10, pv.z),
								Vector3(1.0, 0.8, 1.0))
				scatole.append([szf.call(lung, 0.80, 0.44),
						Vector3(base3.x - float(d3.x) * 0.16, 0.40,
								base3.z - float(d3.y) * 0.16)])
			else:
				_box(n, szf.call(lung, 0.03, 0.36), chiaro,
						Vector3(base3.x, 0.52, base3.z))
				_box(n, szf.call(lung - 0.06, 0.022, 0.32), chiaro,
						Vector3(base3.x, 0.22, base3.z))
				var gambe: int = maxi(2, int(lung / 0.7) + 1)
				for gk2 in gambe:
					var gx: float = -lung * 0.5 + lung * float(gk2) / float(gambe - 1)
					for sp2: float in [-0.14, 0.14]:
						var pg: Vector3 = base3 + tan3 * gx + Vector3(float(d3.x), 0, float(d3.y)) * sp2
						_box(n, Vector3(0.035, 0.50, 0.035), chiaro,
								Vector3(pg.x, 0.26, pg.z))
				scatole.append([szf.call(lung, 1.00, 0.44),
						Vector3(base3.x, 0.50, base3.z)])
				var quanti_v2: int = maxi(2, int(lung / 0.42))
				for vk3 in quanti_v2:
					var t3: float = -lung * 0.5 + lung * (float(vk3) + 0.5) / float(quanti_v2)
					var pv2: Vector3 = base3 + tan3 * t3 \
							+ Vector3(float(d3.x), 0, float(d3.y)) * (0.06 * float(vk3 % 2))
					_cyl(n, 0.05, 0.06, 0.085, cotto, Vector3(pv2.x, 0.578, pv2.z))
					_ball(n, 0.06, verde, Vector3(pv2.x, 0.66, pv2.z),
							Vector3(1.0, 0.8, 1.0))
					if vk3 % 3 == 1:
						for fk3 in 3:
							var fa3 := float(fk3) * TAU / 3.0 + 0.4
							_ball(n, 0.015, _mat(PINK, PINK_DEEP, 5.0, 0.4),
									Vector3(pv2.x + cos(fa3) * 0.038, 0.70,
											pv2.z + sin(fa3) * 0.038))
					# i vasi di scorta capovolti sul ripiano basso
					if vk3 % 2 == 0:
						_cyl(n, 0.055, 0.045, 0.07, cotto,
								Vector3(pv2.x, 0.27, pv2.z))
		# LA STUFA DI GHISA: nella campata piu' lontana dalla porta. Di
		# notte, da fuori, la serra grande ha una finestra calda.
		if e_fondo:
			# in un angolo dove non c'e' bancone, e mai in mezzo alla navata
			var av := Vector3(float(via.x), 0, float(via.y))
			var at := Vector3(0, 0, 1) if via.x != 0 else Vector3(1, 0, 0)
			var ang := av * 0.52 + at * 0.60
			_cyl(n, 0.15, 0.17, 0.10, ghisa, Vector3(ang.x, 0.05, ang.z))
			_cyl(n, 0.14, 0.155, 0.46, ghisa, Vector3(ang.x, 0.33, ang.z))
			_cyl(n, 0.17, 0.15, 0.06, ghisa, Vector3(ang.x, 0.59, ang.z))
			var brace := _glow(Color("ff9a4a"), Color("ff7a28"), 3.0)
			_box(n, Vector3(0.13, 0.10, 0.02), brace,
					Vector3(ang.x, 0.30, ang.z - 0.152))
			# LA CANNA esce dal vetro: l'altezza del tetto in quel punto si
			# CALCOLA (colmo meno mezza distanza dall'asse), non si indovina
			var y_tetto := SERRA_COLMO - 0.5 * absf(ang.z)
			_cyl(n, 0.042, 0.042, y_tetto - 0.50, ghisa,
					Vector3(ang.x, 0.59 + (y_tetto - 0.50) * 0.5, ang.z))
			_cyl(n, 0.085, 0.065, 0.06, rame, Vector3(ang.x, y_tetto, ang.z))
			_cyl(n, 0.038, 0.030, 0.20, ghisa, Vector3(ang.x, y_tetto + 0.13, ang.z))
			_cyl(n, 0.052, 0.040, 0.04, ghisa, Vector3(ang.x, y_tetto + 0.25, ang.z))
			# la finestra calda promessa qui sopra ESISTE solo se la stufa
			# illumina i banconi attraverso il vetro: a 0.75/2.8 da fuori
			# la serra restava una scatola blu come tutte le altre
			var luce := OmniLight3D.new()
			luce.light_color = Color(1.0, 0.72, 0.42)
			luce.light_energy = 1.2
			luce.omni_range = 3.4
			luce.omni_attenuation = 1.1
			luce.position = Vector3(ang.x, 0.34, ang.z - 0.12)
			n.add_child(luce)
			scatole.append([Vector3(0.38, 0.62, 0.38), Vector3(ang.x, 0.31, ang.z)])
		# IL TUBO DI GHISA che gira tutto il perimetro: attraversa le
		# campate, e nessuno lo nota. Se manca, si pensa «ci sono N pezzi qui».
		if quante >= 4:
			for d4: Vector2i in fasce:
				var fil4 := Vector3(float(d4.x), 0.0, float(d4.y)) * 0.855
				var tan4 := Vector3(0, 0, 1) if d4.x != 0 else Vector3(1, 0, 0)
				var lung4: float = float(est_p[d4]) + float(est_n[d4])
				var mid4: float = (float(est_p[d4]) - float(est_n[d4])) * 0.5
				var pt := fil4 + tan4 * mid4
				var tubo := _cyl(n, 0.028, 0.028, lung4, ghisa,
						Vector3(pt.x, 0.12, pt.z))
				if d4.x == 0:
					tubo.rotation.z = PI * 0.5
				else:
					tubo.rotation.x = PI * 0.5
		# IL CUORE: l'agrume in mastello e la panca ad anello. Ci si siede
		# sotto un albero, dentro una casa di vetro, in inverno.
		if e_cuore and quante >= 5:
			_cyl(n, 0.28, 0.24, 0.42, legno, Vector3(0, 0.21, 0))
			for ck in 2:
				_cyl(n, 0.285, 0.285, 0.035, ghisa,
						Vector3(0, 0.10 + float(ck) * 0.22, 0))
			_cyl(n, 0.055, 0.075, 0.95, _mat(WOOD_DARK, Color("6b4a33"), 4.0, 0.45),
					Vector3(0, 0.86, 0))
			for chk in 3:
				var ca := float(chk) * TAU / 3.0 + 0.5
				_ball(n, 0.34, verde, Vector3(cos(ca) * 0.16, 1.42 + float(chk) * 0.10,
						sin(ca) * 0.16), Vector3(1.0, 0.85, 1.0))
			for fr in 6:
				var fra := float(fr) * TAU / 6.0 + 0.3
				_ball(n, 0.045, _mat(Color("f0a83c"), Color("d98a26"), 5.0, 0.4),
						Vector3(cos(fra) * 0.34, 1.36 + 0.14 * float(fr % 3),
								sin(fra) * 0.34))
			for pk in 8:
				var pa := float(pk) * TAU / 8.0
				var seg := _box(n, Vector3(0.66, 0.05, 0.24), chiaro,
						Vector3(cos(pa) * 0.72, 0.40, sin(pa) * 0.72))
				seg.rotation.y = -pa
				_box(n, Vector3(0.06, 0.36, 0.06), chiaro,
						Vector3(cos(pa) * 0.72, 0.20, sin(pa) * 0.72))
				# ci si siede sotto l'albero, dentro una casa di vetro: le
				# sedute guardano il mastello
				if pk % 2 == 0:
					_sedute_serra.append([Vector3(cos(pa) * 0.72, 0.425,
							sin(pa) * 0.72), Vector3(0, 0.55, 0)])
			scatole.append([Vector3(0.62, 0.45, 0.62), Vector3(0, 0.22, 0)])
		elif e_cuore:
			# quattro vicini ma gruppo piccolo: la VASCA dell'acqua
			_box(n, Vector3(0.90, 0.34, 0.60), pietra, Vector3(0, 0.17, 0))
			_box(n, Vector3(0.80, 0.03, 0.50), _mat(Color("6f97a8"), Color("52788a"), 3.0, 0.2),
					Vector3(0, 0.325, 0))
			scatole.append([Vector3(0.95, 0.35, 0.65), Vector3(0, 0.18, 0)])
		# IL POSTO DOVE STARE: da qui la serra non e' piu' un attrezzo,
		# e' una stanza. Tavolino di ferro e due sedie in un angolo.
		if quante >= 4 and fasce.size() >= 2 and not e_cuore and not e_fondo \
				and not lato_porta:
			_cyl(n, 0.035, 0.045, 0.42, ghisa, Vector3(0.30, 0.21, -0.30))
			_cyl(n, 0.26, 0.26, 0.025, chiaro, Vector3(0.30, 0.435, -0.30))
			_cyl(n, 0.16, 0.20, 0.02, ghisa, Vector3(0.30, 0.02, -0.30))
			for sk in 2:
				var sa := 0.9 + float(sk) * 2.4
				var sp3 := Vector3(0.30 + cos(sa) * 0.44, 0, -0.30 + sin(sa) * 0.44)
				var sedia := Node3D.new()
				sedia.position = sp3
				sedia.rotation.y = -sa + PI * 0.5
				n.add_child(sedia)
				_box(sedia, Vector3(0.28, 0.03, 0.26), chiaro, Vector3(0, 0.28, 0))
				_box(sedia, Vector3(0.28, 0.30, 0.03), chiaro, Vector3(0, 0.44, -0.12))
				for lk in 4:
					_box(sedia, Vector3(0.03, 0.28, 0.03), ghisa,
							Vector3(-0.11 + 0.22 * float(lk % 2), 0.14,
									-0.10 + 0.20 * float(lk / 2)))
				_sedute_serra.append([sp3 + Vector3(0, 0.30, 0),
						Vector3(0.30, 0.44, -0.30)])
			scatole.append([Vector3(0.60, 0.45, 0.60), Vector3(0.30, 0.22, -0.30)])
		# la PALMERIA: il pavimento a scacchi e le palme negli angoli
		if taglia == "palmeria":
			for qx in 2:
				for qz in 2:
					var pari := (qx + qz + c.x + c.y) % 2 == 0
					_box(n, Vector3(0.50, 0.008, 0.50),
							cotto if pari else pietra,
							Vector3(-0.25 + float(qx) * 0.50, 0.072,
									-0.25 + float(qz) * 0.50))
			if fasce.size() >= 2 and not e_cuore:
				var pmx: float = 0.36 * signf(float(fasce[0].x) + 0.001)
				var pmz := 0.36
				_cyl(n, 0.19, 0.16, 0.28, legno, Vector3(pmx, 0.14, pmz))
				_cyl(n, 0.042, 0.058, 1.42, _mat(Color("b09a72"), Color("8e7a58"), 5.0, 0.45),
						Vector3(pmx, 0.97, pmz))
				for fo in 7:
					var foa := float(fo) * TAU / 7.0 + 0.4
					var foglia := _box(n, Vector3(0.46, 0.02, 0.17), verde,
							Vector3(pmx + cos(foa) * 0.22, 1.70, pmz + sin(foa) * 0.22))
					foglia.rotation.y = -foa
					foglia.rotation.z = -0.34
				scatole.append([Vector3(0.40, 0.32, 0.40), Vector3(pmx, 0.16, pmz)])
	# il CESTO appeso al colmo, uno per campata
	if not e_cuore:
		_cyl(n, 0.006, 0.006, 0.42, _mat(Color("c9b088"), Color("ab9066"), 5.0, 0.5),
				Vector3(0, 2.20, 0))
		_cyl(n, 0.07, 0.05, 0.08, cotto, Vector3(0, 1.95, 0))
		_ball(n, 0.085, verde, Vector3(0, 2.01, 0), Vector3(1.0, 0.65, 1.0))
		for gk3 in 3:
			var ga := float(gk3) * TAU / 3.0 + 0.2
			_ball(n, 0.035, verde, Vector3(cos(ga) * 0.075, 1.93, sin(ga) * 0.075),
					Vector3(1.0, 1.5, 1.0))

	# ---- LE SEDUTE. L'ancoraggio E' il posto (meta «seduta» a zero, come il
	# Gazebo) e guarda quello che si e' venuti a guardare (meta «tavolo»).
	# Ogni taglia ne ha almeno una: lo sgabello al bancone da rinvaso, le
	# sedie del tavolino, la panca ad anello sotto l'agrume. Le trovano sia
	# il giocatore (BuildSystem.get_interactables) sia i vicini
	# (Visitors._free_bench): un interno che non si puo' usare e' una
	# vetrina.
	#
	# TRAPPOLA PAGATA: i nomi si danno con l'INDICE del ciclo, non con un
	# contatore dentro una lambda — le lambda di GDScript catturano per
	# VALORE, quindi il contatore non avanzava e tutti gli ancoraggi
	# nascevano «Posto0»; Godot rinominava i doppioni in «@Node3D@78», che
	# non risponde piu' a find_children("Posto*"). Restava UNA seduta su
	# quattro, e nessun test se ne sarebbe accorto guardando la geometria.
	if taglia == "sola" or (not e_cuore and fasce.size() >= 1 and quante <= 3):
		# lo sgabello al bancone: anche la serra piccola si abita
		var d5: Vector2i = Vector2i(1, 0) if taglia == "sola" else fasce[0]
		var vso := Vector3(float(d5.x), 0, float(d5.y))
		var sg5 := vso * 0.30 - Vector3(0, 0, 0.30)
		_cyl(n, 0.115, 0.10, 0.03, chiaro, Vector3(sg5.x, 0.315, sg5.z))
		for gk5 in 3:
			var ga5 := float(gk5) * TAU / 3.0 + 0.5
			var gam5 := _cyl(n, 0.016, 0.020, 0.31, chiaro,
					Vector3(sg5.x + cos(ga5) * 0.06, 0.155, sg5.z + sin(ga5) * 0.06))
			gam5.rotation.x = sin(ga5) * 0.16
			gam5.rotation.z = -cos(ga5) * 0.16
		_sedute_serra.append([Vector3(sg5.x, 0.33, sg5.z),
				vso * 0.68 + Vector3(0, 0.55, sg5.z * 0.5)])
		scatole.append([Vector3(0.28, 0.34, 0.28), Vector3(sg5.x, 0.17, sg5.z)])

	for i_sd in _sedute_serra.size():
		var sd: Array = _sedute_serra[i_sd]
		var dove: Vector3 = sd[0]
		var guarda: Vector3 = sd[1]
		var a := Node3D.new()
		a.name = "Posto%d" % i_sd
		a.position = dove
		var dir := (guarda - dove) * Vector3(1, 0, 1)
		if dir.length() > 0.02:
			# il rig guarda -Z: e' la convenzione di ChibiBuilder
			a.rotation.y = atan2(-dir.x, -dir.z)
		a.set_meta("seduta", Vector3.ZERO)
		a.set_meta("tavolo", guarda)
		n.add_child(a)

	n.set_meta("scatole", scatole)
	n.set_meta("asse", asse)
	return radice


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


## UNA CORDA VIVA. Il builder scolpisce la posa di riposo (è quella delle
## foto e dei salvataggi caricati con «Riduci animazioni»); nel mondo,
## CordeVive.gd la trova col gruppo «corda_viva», legge il meta e la fa
## muovere con la fisica vera — vento, inerzia, la spinta di chi ci passa
## contro. I punti vivono nello SPAZIO DEL PEZZO: il nodo sta a
## trasformata identità sotto la radice, così gli appesi (che sono suoi
## fratelli) condividono le coordinate senza conversioni.
##
## `molle` è l'abbondanza di corda (0.15 = lunga il 115% della distanza):
## è LEI a decidere quanto pende — la pancia non si disegna, risulta.
## `libera` = pende dal solo capo `a` (la corda della campana); allora
## `b` serve solo a dire quanto è lunga.
static func _corda_viva(parent: Node3D, a: Vector3, b: Vector3, molle: float,
		raggio: float, mat: Material, vento := 1.0, punti := 10, lati := 6,
		libera := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "CordaViva"
	mi.material_override = mat
	var posa: Array
	if libera:
		posa = FISICA.riposo_libera(a, FISICA.lunghezza(a, b, molle), punti)
	else:
		posa = FISICA.riposo(a, b, molle, punti)
	var im := ImmediateMesh.new()
	FISICA.scrivi_tubo(im, posa, raggio, lati)
	mi.mesh = im
	mi.set_meta("corda", {"a": a, "b": b, "molle": molle, "raggio": raggio,
			"punti": punti, "lati": lati, "vento": vento, "libera": libera})
	mi.set_meta("posa", posa)     # la posa di riposo: i builder ci appoggiano
	mi.add_to_group("corda_viva", true)
	parent.add_child(mi)
	return mi


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
	# IL PREPROCESS: senza, l'emettitore parte VUOTO e ci mette un ciclo a
	# riempirsi. Chi accende un camino e guarda subito vede un focolare
	# spento, e nelle foto del catalogo il fuoco non c'era proprio. Un
	# ciclo e mezzo simulato in partenza, e la fiamma c'è dal primo frame.
	p.preprocess = life * 1.5
	p.process_material = pm
	p.draw_pass_1 = quad
	p.position = pos
	parent.add_child(p)


# LA CASETTA DEGLI UCCELLINI, terza stesura — le prime due erano un
# cartone del latte su uno stecco. Questa e' una CASA: doghe di legno
# miele, timpani crema che chiudono il sottotetto, tetto cicciotto a
# scandole con lo sporto largo, il TETTUCCIO sopra il foro, la
# MANGIATOIA coi semi al posto del trespolo nudo, il camino piccolo su
# una falda, e il RAMPICANTE fiorito che si avvita sul palo tornito.
# Vincolo di ferro: il colmo sta a ~1.44 e resta LIBERO al centro —
# Nido.gd posa la covata a +1.47 dal piede del palo.
static func _birdhouse() -> Node3D:
	var n := Node3D.new()
	var wood := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	var miele := _mat(WOOD_PALE, WOOD, 3.2, 0.5)
	var scuro := _mat(Color("4a3226"), Color("31201a"), 3.0, 0.4)
	var crema := _mat(CREAM, Color("efe2ca"), 4.0, 0.35)
	var tegola := _mat(TERRACOTTA, Color("c47a58"), 3.0, 0.5)
	var tegola2 := _mat(Color("d98a64"), Color("b96f4e"), 3.2, 0.5)
	var verde := _mat(Color("7da35e"), Color("5f8544"), 4.5, 0.5)
	var rosa := _mat(PINK, PINK_DEEP, 5.0, 0.4)

	# il palo tornito, grosso il giusto, con la basetta a campana
	BUILDER.lathe(n, [Vector2(0.085, 0.0), Vector2(0.090, 0.016),
			Vector2(0.070, 0.04), Vector2(0.050, 0.08), Vector2(0.042, 0.30),
			Vector2(0.038, 0.72), Vector2(0.046, 0.86), Vector2(0.056, 0.93),
			Vector2(0.060, 0.95)], wood)
	# il RAMPICANTE che si avvita: gambo a elica, foglie e tre fiorellini
	var giri: Array = []
	var raggi: Array = []
	for g in 9:
		var t := float(g) / 8.0
		var ag := t * TAU * 1.6 + 0.7
		var rg := 0.052 - 0.008 * t
		giri.append(Vector3(cos(ag) * rg, 0.06 + t * 0.74, sin(ag) * rg))
		raggi.append(0.009 - 0.003 * t)
	BUILDER.tube(n, giri, raggi, verde)
	for fg in [1, 3, 5, 7]:
		var pf: Vector3 = giri[fg]
		_ball(n, 0.030, verde, pf + pf.normalized() * 0.02 * Vector3(1, 0, 1),
				Vector3(1.3, 0.35, 0.9))
	for ff in [2, 5, 8]:
		var pf2: Vector3 = giri[ff]
		_ball(n, 0.016, rosa, pf2 + Vector3(0, 0.015, 0))

	# LA CASA: zoccolo, pareti a DOGHE orizzontali, cantonali scuri
	var zocc := _prisma(n, _rrect_xz(0.38, 0.34, 0.03), 0.93, 0.026, wood)
	zocc.position.z = 0.0
	for da in 5:
		var doga := _prisma(n, _rrect_xz(0.36, 0.32, 0.028), 0.956 + 0.062 * float(da),
				0.058, miele)
		doga.position.z = 0.0
	for cx: float in [-0.165, 0.165]:
		for cz: float in [-0.145, 0.145]:
			_cyl(n, 0.016, 0.016, 0.32, wood, Vector3(cx, 1.115, cz))

	# i TIMPANI crema: il box ruotato di 45 gradi chiude il sottotetto
	# davanti e dietro (la meta' bassa affoga nelle pareti)
	var timpano := _box(n, Vector3(0.25, 0.25, 0.30), crema, Vector3(0, 1.27, 0))
	timpano.rotation.z = PI * 0.25

	# il TETTO: falde col cardine al colmo, scandole cicciotte sfalsate,
	# sporto largo; il listello di colmo a 1.44 (il nido arriva a 1.47)
	for lato: float in [-1.0, 1.0]:
		var falda := Node3D.new()
		falda.position = Vector3(0, 1.438, 0)
		falda.rotation.z = -lato * 0.62
		n.add_child(falda)
		for fila in 3:
			var lx := 0.018 + 0.085 * float(fila)
			var nt := 4 if fila % 2 == 0 else 3
			for t2 in nt:
				var lz := -0.155 + 0.103 * float(t2) + (0.0515 if fila % 2 == 1 else 0.0)
				var mat_s: Material = tegola if (fila + t2) % 2 == 0 else tegola2
				var scand := _prisma(falda, _rrect_xz(0.100, 0.098, 0.024),
						-0.007 * float(fila), 0.016, mat_s)
				scand.position = Vector3(lx * lato, 0.0, lz)
	var colmo := _cyl(n, 0.028, 0.028, 0.40, tegola, Vector3(0, 1.443, 0))
	colmo.rotation.x = PI * 0.5

	# il CAMINO piccolo, su una falda, fuori dal posto del nido
	_box(n, Vector3(0.055, 0.10, 0.055), tegola2, Vector3(0.115, 1.37, -0.105))
	_box(n, Vector3(0.07, 0.022, 0.07), scuro, Vector3(0.115, 1.425, -0.105))

	# il FORO con l'anello, il TETTUCCIO sopra, e la MANGIATOIA coi semi
	var foro := _cyl(n, 0.048, 0.048, 0.04, scuro, Vector3(0, 1.16, -0.165))
	foro.rotation.x = PI * 0.5
	var anello := MeshInstance3D.new()
	var am := TorusMesh.new()
	am.inner_radius = 0.046
	am.outer_radius = 0.064
	anello.mesh = am
	anello.material_override = wood
	anello.position = Vector3(0, 1.16, -0.178)
	anello.rotation.x = PI * 0.5
	n.add_child(anello)
	var tettuccio := _prisma(n, _rrect_xz(0.16, 0.09, 0.02), 0.0, 0.014, tegola)
	tettuccio.position = Vector3(0, 1.265, -0.20)
	tettuccio.rotation.x = 0.35
	# la mangiatoia: il vassoio con le sponde, i semi, e il posatoio
	var vasso := _prisma(n, _rrect_xz(0.19, 0.095, 0.025), 1.045, 0.020, wood)
	vasso.position.z = -0.21
	var vasca := _prisma(n, _rrect_xz(0.16, 0.07, 0.02), 1.062, 0.012, scuro)
	vasca.position.z = -0.21
	for sg in 7:
		var ags := float(sg) * 2.4
		_ball(n, 0.0095, _mat(Color("e8c34a"), Color("b98a2e"), 5.0, 0.4),
				Vector3(cos(ags) * 0.055, 1.076, -0.21 + sin(ags) * 0.022),
				Vector3(1.0, 0.6, 1.3))
	var posatoio := _cyl(n, 0.009, 0.011, 0.06, wood, Vector3(0, 1.03, -0.27))
	posatoio.rotation.x = PI * 0.5
	_ball(n, 0.013, scuro, Vector3(0, 1.03, -0.303))

	# ai piedi: l'erba, la margherita, un sassolino
	_ball(n, 0.06, verde, Vector3(-0.10, 0.016, 0.06), Vector3(1.2, 0.5, 0.9))
	_ball(n, 0.045, verde, Vector3(0.115, 0.012, -0.06), Vector3(1.0, 0.45, 0.85))
	_ball(n, 0.028, _mat(Color("b3aa9a"), Color("948b7c"), 4.0, 0.5),
			Vector3(0.14, 0.02, 0.10), Vector3(1.2, 0.7, 1.0))
	_cyl(n, 0.004, 0.004, 0.10, verde, Vector3(-0.135, 0.05, 0.085))
	for pt in 5:
		var ap := float(pt) * TAU / 5.0
		_ball(n, 0.014, _mat(Color.WHITE, CREAM, 6.0, 0.2),
				Vector3(-0.135 + cos(ap) * 0.020, 0.104, 0.085 + sin(ap) * 0.020),
				Vector3(1.0, 0.35, 1.0))
	_ball(n, 0.011, _mat(Color("e8c34a"), Color("cc9c2e"), 5.0, 0.4),
			Vector3(-0.135, 0.108, 0.085))
	return n


# IL LAMPIONE DA GIARDINO. Il pezzo vive di NOTTE: e' una goccia di
# miele nel buio, con la sua pozza di luce sull'erba. Tutto qui dentro
# serve a quello, e ogni quota viene da un panel di revisione che ha
# MISURATO i pixel delle foto invece di guardarle.
#
# LE QUATTRO SCELTE CHE LO REGGONO
# 1. IL FERRO E' VERDE-NERO, e il suo secondo tono e' PIU' CHIARO del
#    primo. La tinta scura fa risaltare il miele (su un palo beige,
#    miele su beige e' miele su miele). L'inversione dei toni fa
#    leggere il rumore handpaint come MARTELLATURA invece che come
#    sporco: e' l'unica cosa che salva la base dentro la sua ombra.
# 2. IL VETRO E' IN DUE TONI, con la fiamma in ALTO e l'ambra fonda in
#    basso, e la giunzione nascosta sotto la cintura d'ottone (legge
#    come vetro piombato, non come una banda dipinta). Misurato: il
#    vetro a un tono usciva LIMONE (tinta 58°, saturazione 0.37) e col
#    fondo piu' chiaro della cima — l'inverso di una fiamma.
# 3. IL CAPPELLO E' PIU' LARGO DELLA BASE (0.236 contro 0.210). A
#    larghezze pari nessuna delle due comanda e la sagoma legge come un
#    MANUBRIO; un lampione deve avere la luce come cosa piu' grande.
# 4. L'ALONE E' GEOMETRIA, non glow. Lo studio del catalogo, la
#    Modalita' Foto e il diorama del menu' non hanno il bagliore
#    dell'Environment: senza un quad additivo, li' la lanterna sembra
#    SPENTA. Con quello, e' accesa ovunque.
#
# RITMO: ricci, montanti della gabbia e costoloni del tetto stanno
# tutti sui MEDESIMI sei meridiani (k·60°). E' quello a far leggere la
# testa come UN oggetto invece che come tre pezzi impilati.
#
# La OmniLight resta identica — colore, energia, raggio e posizione
# (0, 2.14, 0), dentro il vetro, al 78% della sua altezza.
static func _streetlamp() -> Node3D:
	var n := Node3D.new()
	# il secondo tono PIU' CHIARO del primo: martellatura, non sporco
	var ferro := _mat(Color("3f4a42"), Color("55645a"), 5.0, 0.42)
	var ferro_c := _mat(Color("4d5a50"), Color("64756a"), 5.0, 0.45)
	var ottone := _mat(OTTONE, OTTONE_SCURO, 5.0, 0.4)
	# la regola del miele: il ROSSO deve saturare (dice «sorgente»), il
	# BLU deve restare basso (e' quello che tiene il colore)
	var vetro_a := _glow(Color("ffc65f"), Color("ffa02a"), 1.05)
	var vetro_b := _glow(Color("f5a13a"), Color("e8760f"), 0.85)

	# LA PIASTRA ottagonale e i quattro BULLONI a testa esagonale: fra
	# bullone e campana restano 12 mm di ferro nudo, ed e' quello a
	# farli esistere (prima la campana se li mangiava)
	var piastra := _cyl(n, 0.200, 0.210, 0.036, ferro, Vector3(0, 0.018, 0))
	(piastra.mesh as CylinderMesh).radial_segments = 8
	piastra.rotation.y = PI / 8.0 + 0.035
	for bl in 4:
		var ab := float(bl) * TAU / 4.0 + PI * 0.25
		# uno dei quattro e' avvitato 4 mm piu' a fondo: il fabbro
		var yb := 0.043 if bl == 2 else 0.047
		var bullone := _cyl(n, 0.021, 0.024, 0.022, ottone,
				Vector3(cos(ab) * 0.160, yb, sin(ab) * 0.160))
		(bullone.mesh as CylinderMesh).radial_segments = 6

	# LA CAMPANA che raccoglie il fusto: la gola e il toro di saldatura
	# sono la tacca che spezza il nero senza aggiungere un pezzo
	BUILDER.lathe(n, [Vector2(0.124, 0.036), Vector2(0.130, 0.062),
			Vector2(0.126, 0.088), Vector2(0.104, 0.122), Vector2(0.086, 0.164),
			Vector2(0.074, 0.212), Vector2(0.076, 0.238), Vector2(0.068, 0.262)],
			ferro)

	# IL FUSTO tornito con le sue DUE riprese (mai una sola a mezzeria:
	# farebbe lo specchio) e la SVASATURA DI SPALLA che arriva fino
	# sotto il piattino — cosi' il tappo del tornio non galleggia
	BUILDER.lathe(n, [Vector2(0.066, 0.256), Vector2(0.063, 0.42),
			Vector2(0.060, 0.62), Vector2(0.058, 0.755), Vector2(0.063, 0.780),
			Vector2(0.063, 0.822), Vector2(0.056, 0.848), Vector2(0.053, 1.10),
			Vector2(0.051, 1.305), Vector2(0.055, 1.330), Vector2(0.055, 1.355),
			Vector2(0.050, 1.380), Vector2(0.048, 1.50), Vector2(0.047, 1.58),
			Vector2(0.052, 1.618), Vector2(0.062, 1.672), Vector2(0.072, 1.728),
			Vector2(0.080, 1.775), Vector2(0.086, 1.812)], ferro)
	_cyl(n, 0.078, 0.078, 0.048, ottone, Vector3(0, 0.801, 0))
	var col := _cyl(n, 0.066, 0.066, 0.032, ferro_c, Vector3(0, 1.3425, 0))
	col.rotation.y = 0.06

	# I SEI RICCI, mensole che SPINGONO SU il piattino. Sezione COSTANTE
	# sul braccio (una barra battuta non si rastrema come un filo), la
	# radice ESCE dal palo invece di nascerci dentro, e lo sbraccio non
	# e' mai due volte uguale — con seme FISSO, perche' due lampioni
	# affiancati devono essere gemelli imperfetti, non pezzi diversi
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("lampione")
	for rc in 6:
		var ar := float(rc) * TAU / 6.0
		var cx := cos(ar)
		var cz := sin(ar)
		var sb := 0.156 + rng.randf_range(-0.006, 0.006)
		BUILDER.tube(n, [
				Vector3(cx * 0.056, 1.600, cz * 0.056),
				Vector3(cx * 0.118, 1.630, cz * 0.118),
				Vector3(cx * sb, 1.692, cz * sb),
				Vector3(cx * sb, 1.764, cz * sb),
				Vector3(cx * 0.130, 1.818, cz * 0.130)],
				[0.016, 0.016, 0.015, 0.013, 0.010], ferro_c, 24, 8)

	# IL PIATTINO: un vassoio modanato con l'ORLO DI GOCCIOLAMENTO a
	# meta' altezza, non un imbuto (largo sotto e stretto sopra)
	BUILDER.lathe(n, [Vector2(0.148, 1.812), Vector2(0.170, 1.826),
			Vector2(0.174, 1.842), Vector2(0.160, 1.856), Vector2(0.134, 1.868),
			Vector2(0.126, 1.876)], ferro)

	# IL VETRO in due toni: l'ambra fonda sotto, la fiamma sopra. La
	# giunzione cade a 2.024 e la cintura la copre — i raggi combaciano
	# esattamente, quindi non resta nessuna fessura
	BUILDER.lathe(n, [Vector2(0.122, 1.876), Vector2(0.136, 1.912),
			Vector2(0.142, 1.958), Vector2(0.142, 2.000), Vector2(0.139, 2.024)],
			vetro_b)
	BUILDER.lathe(n, [Vector2(0.139, 2.024), Vector2(0.134, 2.070),
			Vector2(0.122, 2.140), Vector2(0.104, 2.185), Vector2(0.094, 2.212)],
			vetro_a)

	# LA CINTURA d'ottone: fascia tornita che abbraccia la pancia e
	# nasconde la giunzione. Mai un toro schiacciato — leggeva come un
	# elastico molle appeso di sbieco
	BUILDER.lathe(n, [Vector2(0.144, 1.996), Vector2(0.152, 2.008),
			Vector2(0.153, 2.038), Vector2(0.145, 2.052)], ottone)

	# LA GABBIA: sei montanti che ADERISCONO al vetro (4-5 mm fuori
	# dalla parete: staccati leggerebbero come una gabbietta per
	# uccelli), nati dentro l'orlo del piattino e morti dentro la gola
	for mt in 6:
		var am := float(mt) * TAU / 6.0
		var mx := cos(am)
		var mz := sin(am)
		BUILDER.tube(n, [
				Vector3(mx * 0.126, 1.874, mz * 0.126),
				Vector3(mx * 0.146, 1.925, mz * 0.146),
				Vector3(mx * 0.147, 1.985, mz * 0.147),
				Vector3(mx * 0.140, 2.055, mz * 0.140),
				Vector3(mx * 0.124, 2.142, mz * 0.124),
				Vector3(mx * 0.100, 2.205, mz * 0.100)],
				[0.012, 0.012, 0.011, 0.011, 0.010, 0.010], ferro, 22, 8)

	# LA GOLA (che copre l'orlo APERTO del tornio del vetro: il lathe
	# non chiude in cima, e scoperto si vedrebbe il buco) e l'anello di
	# sfiato, il gradino che presenta il tetto un passo prima
	BUILDER.lathe(n, [Vector2(0.100, 2.198), Vector2(0.120, 2.212),
			Vector2(0.126, 2.234), Vector2(0.114, 2.250)], ferro)
	_cyl(n, 0.120, 0.116, 0.016, ferro_c, Vector3(0, 2.258, 0))

	# IL CAPPELLO a pagoda ESAGONALE: falda CONCAVA (la pendenza sale
	# monotona salendo — l'inverso della falda convessa, che legge come
	# un fungo), LABBRO RIALZATO di 24 mm sull'attacco del sottotetto e
	# GRONDA con lo spessore vero di 12 mm. A sei lati i costoloni
	# cadono esattamente sui montanti, che cadono sui ricci.
	BUILDER.lathe(n, [Vector2(0.190, 2.266), Vector2(0.228, 2.278),
			Vector2(0.236, 2.290), Vector2(0.230, 2.302), Vector2(0.196, 2.316),
			Vector2(0.156, 2.338), Vector2(0.116, 2.366), Vector2(0.078, 2.400),
			Vector2(0.046, 2.438), Vector2(0.022, 2.470), Vector2(0.008, 2.496)],
			ferro, Vector3.ZERO, 6)

	# IL POMELLO a ghianda, che COPRE il colmo invece di posarcisi accanto
	BUILDER.lathe(n, [Vector2(0.020, 2.480), Vector2(0.032, 2.490),
			Vector2(0.036, 2.502), Vector2(0.027, 2.512), Vector2(0.038, 2.528),
			Vector2(0.040, 2.550), Vector2(0.032, 2.574), Vector2(0.017, 2.594),
			Vector2(0.006, 2.608)], ottone)

	# L'ALONE: la sola cosa che dice «e' ACCESO» dove non c'e' il glow
	# dell'Environment. Quad additivo billboard col gradiente radiale,
	# centrato sul vetro. La prova di profondita' resta ACCESA: cosi'
	# cappello e montanti lo occludono, i ferri restano neri e la bolla
	# compare solo ATTORNO alla sagoma.
	var gt := GradientTexture2D.new()
	gt.width = 64
	gt.height = 64
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	var gr := Gradient.new()
	gr.offsets = PackedFloat32Array([0.0, 0.30, 0.64, 1.0])
	var ca := Color("ffb45c")
	gr.colors = PackedColorArray([Color(ca, 0.30), Color(ca, 0.165),
			Color(ca, 0.052), Color(ca, 0.0)])
	gt.gradient = gr
	var qm := QuadMesh.new()
	qm.size = Vector2(0.72, 0.72)
	var qmat := StandardMaterial3D.new()
	qmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qmat.albedo_texture = gt
	qmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var alone := MeshInstance3D.new()
	alone.mesh = qm
	alone.material_override = qmat
	# OBBLIGATORIO: senza, il quad tira un'ombra QUADRATA sul prato
	alone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	alone.position = Vector3(0, 2.05, 0)
	n.add_child(alone)

	# LA POZZA DELLA STRADA. Il vetro era già bello, ma per terra non
	# succedeva niente: 1.6/5.5/1.0 su un ambiente notturno dà una
	# velatura uniforme, cioè il contrario di un lampione. Scelta al buio
	# su cinque tarature: sotto (3.0) il cerchio non si stacca dal fondo,
	# sopra (5.2/4.8/1.35) il vetro comincia a sbiancare. È la luce più
	# ampia del catalogo, ed è giusto: è quella della strada.
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.86, 0.6)
	light.light_energy = 4.0
	light.omni_range = 5.2
	light.omni_attenuation = 1.2
	light.position = Vector3(0, 2.14, 0)
	n.add_child(light)
	return n


## L'AMACA, terza vita. La prima erano nove doghe rigide col vuoto in
## mezzo (un ponte tibetano in miniatura); la seconda — quella che
## sostituisce — era TELA, ma tela PIATTA: tredici scatole affiancate
## lungo una catenaria, larghe uguali da un capo all'altro, tenute aperte
## da due bilancini di legno. Cioe' una BRANDINA appesa, non un'amaca:
## una barella da campo tesa fra due pali.
##
## Un'amaca vera fa due cose che quella non faceva, e sono le uniche due
## che contano:
##  1. SI STRIZZA AI CAPI. La tela non finisce dritta: si raccoglie fino
##     a quasi niente e da li' parte la ZAMPA DI CORDE che converge
##     nell'anello. E' quella pinzatura la firma dell'amaca — via i
##     bilancini, che sono di un'altra cosa (l'amaca da giardino
##     americana, che infatti sembra una barella).
##  2. FA LA CULLA. La sezione trasversale non e' piatta: i bordi si
##     alzano e il centro affonda, e affonda di piu' dove ci sta il peso.
## Perciò la tela adesso e' una SUPERFICIE parametrica (_mesh_griglia):
##  · larghezza(u) = W · sin(pi·u)^0.62  → piena in mezzo, zero ai capi;
##  · quota(u) = catenaria, ma spostata verso il cuscino: chi ci dorme
##    sta piu' vicino a un capo, e l'amaca lo sa;
##  · culla(v) = i bordi salgono con v², in proporzione alla larghezza —
##    dove la tela e' strizzata non c'e' culla, e' un cordone.
## Le righe restano righe perche' ogni fascia e' la SUA griglia: adiacenti
## condividono i bordi, quindi da lontano e' una curva sola.
static func _hammock() -> Node3D:
	var n := Node3D.new()
	var wood := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	var scuro := _mat(WOOD_DARK, WOOD_DARK.darkened(0.15), 3.5, 0.45)
	var ottone := _mat(OTTONE, OTTONE_SCURO, 5.0, 0.4)
	var corda := _mat(Color("c9b088"), Color("ab9066"), 5.0, 0.5)
	var a_mat := _mat(PINK, PINK_DEEP, 5.0, 0.4)
	var b_mat := _mat(CREAM, Color("f3dfc8"), 5.0, 0.4)

	# i numeri dei pali servono anche alle funi: stanno scritti una volta
	var palo_x := 0.42
	var palo_y := 0.45
	var palo_h := 0.9
	var incl := 0.12
	var asse := func(y: float) -> float:
		return palo_x + sin(incl) * (y - palo_y) / cos(incl)
	var faccia := func(y: float) -> float:
		var h: float = (y - palo_y) / cos(incl)
		return float(asse.call(y)) - lerpf(0.06, 0.04, h / palo_h + 0.5) / cos(incl)
	# ---- I PALI: torniti, col pomolo e il manicotto alla base ----
	for lato: float in [-1.0, 1.0]:
		# LA CIMA E' PIATTA, col capitello che si allarga: il profilo
		# tornito col bulbo e la punta tonda, a questa scala, non
		# leggeva affatto come un palo.
		var post := BUILDER.lathe(n, [Vector2(0.001, 0.0), Vector2(0.062, 0.0),
				Vector2(0.066, 0.018), Vector2(0.058, 0.050),
				Vector2(0.051, 0.34), Vector2(0.046, 0.74),
				Vector2(0.048, 0.83), Vector2(0.058, 0.858),
				Vector2(0.060, 0.884), Vector2(0.052, 0.906),
				Vector2(0.044, 0.916), Vector2(0.001, 0.918)], wood,
				Vector3(lato * (palo_x - sin(incl) * palo_y / cos(incl)), 0.0, 0))
		post.rotation.z = -lato * incl
		var manicotto := _cyl(n, 0.074, 0.088, 0.085, scuro,
				Vector3(lato * float(asse.call(0.042)), 0.042, 0))
		manicotto.rotation.z = -lato * incl

	# ---- LA TELA: una superficie, non una fila di assi ----
	var quota := 0.47
	var mezza := 0.295
	var dip := 0.128
	var largh := 0.265           # mezza larghezza in mezzo alla tela
	var culla := 0.048           # di quanto si alzano i bordi
	var sbilancio := -0.06       # dove affonda di piu': dalla parte del cuscino
	# la quota della tela lungo la lunghezza (u da 0 a 1)
	var y_tela := func(u: float) -> float:
		var s := sin(PI * u)
		# la catenaria, piu' un affondo asimmetrico verso il cuscino
		return quota - dip * s - 0.035 * s * s * cos(PI * (u - 0.5) + sbilancio)
	var w_tela := func(u: float) -> float:
		return largh * pow(sin(PI * u), 0.55)
	# la superficie, a fasce: ognuna la sua griglia, cosi' le righe restano
	var fasce := 11
	var nv := 9
	for f in fasce:
		var vg: Array = []
		var passi := 3
		for i in passi + 1:
			var u: float = (float(f) + float(i) / float(passi)) / float(fasce)
			var w: float = w_tela.call(u)
			var yc: float = y_tela.call(u)
			var riga := PackedVector3Array()
			for j in nv:
				var v := -1.0 + 2.0 * float(j) / float(nv - 1)
				# la culla e' proporzionale alla larghezza: dove la tela e'
				# strizzata non c'e' culla, c'e' un cordone
				var su := culla * v * v * (w / largh)
				riga.append(Vector3(-mezza + u * mezza * 2.0, yc + su, v * w))
			vg.append(riga)
		_mesh_griglia(n, vg, a_mat if f % 2 == 0 else b_mat, Vector3.ZERO, false, true)
	# l'orlo di corda che corre sui due fili della tela
	for fz: float in [-1.0, 1.0]:
		var orlo := PackedVector3Array()
		for i in 25:
			var u := float(i) / 24.0
			var w: float = w_tela.call(u)
			orlo.append(Vector3(-mezza + u * mezza * 2.0,
					float(y_tela.call(u)) + culla * (w / largh) + 0.004, fz * w))
		BUILDER.tube(n, orlo, _raggi_uguali(orlo.size(), 0.009), corda, 26, 6)

	# ---- I CAPI: la zampa di corde, l'anello, la fune al palo ----
	var nodo_y := 0.60
	for lato: float in [-1.0, 1.0]:
		# il capo strizzato della tela: la larghezza non e' zero, e' un
		# cordoncino — si lega proprio li'
		var u_capo: float = 0.008 if lato < 0.0 else 0.992
		var x_capo := -mezza + u_capo * mezza * 2.0
		var y_capo: float = y_tela.call(u_capo)
		var w_capo: float = w_tela.call(u_capo)
		# la legatura che raccoglie la tela
		# la fascetta che raccoglie la tela: STRETTA. Larga quanto la tela
		# (w_capo + 0.014) faceva due dischi color corda grossi come il
		# letto, e ai capi dell'amaca c'erano due funghi.
		var leg := _cyl(n, w_capo * 0.62 + 0.012, w_capo * 0.62 + 0.012, 0.042,
				corda, Vector3(x_capo - lato * 0.012, y_capo + 0.004, 0))
		leg.rotation.z = PI * 0.5
		var anello_p := Vector3(lato * 0.335, 0.520, 0)
		# il ventaglio: cinque cordini dal capo all'anello, che si aprono
		# quel tanto che basta a far vedere il ventaglio
		for fv: float in [-1.0, -0.5, 0.0, 0.5, 1.0]:
			_fune(n, Vector3(x_capo + lato * 0.012,
					y_capo + 0.006 + absf(fv) * 0.010, fv * (w_capo + 0.020)),
					anello_p, 0.007, corda)
		var anello := TorusMesh.new()
		anello.inner_radius = 0.012
		anello.outer_radius = 0.028
		anello.rings = 12
		anello.ring_segments = 8
		var ami := MeshInstance3D.new()
		ami.mesh = anello
		ami.material_override = ottone
		ami.position = anello_p
		ami.rotation.z = PI * 0.5
		n.add_child(ami)
		# LA FUNE AL PALO E' VIVA: in questo gioco tutte le corde lo sono
		# (vedi CordaFisica/CordeVive). Prima era un cilindro dritto.
		_corda_viva(n, anello_p,
				Vector3(lato * float(faccia.call(nodo_y)), nodo_y, 0),
				1.04, 0.013, corda, 0.7, 8, 6)
		var fascia := _cyl(n, 0.060, 0.060, 0.055, corda,
				Vector3(lato * float(asse.call(nodo_y)), nodo_y, 0))
		fascia.rotation.z = -lato * incl

	# ---- LA VITA SOPRA LA TELA: il cuscino nella culla, il plaid ----
	var u_cus := 0.30
	var x_cus := -mezza + u_cus * mezza * 2.0
	var cuscino := _soffice(n, Vector3(0.17, 0.062, 0.135), b_mat,
			Vector3(x_cus, float(y_tela.call(u_cus)) + 0.036, 0.0),
			0.45, 0.62, [[0.0, 0.0, 0.055, 0.016]])
	cuscino.rotation.z = 0.10
	var rosa_cupo := _mat(PINK_DEEP, PINK_DEEP.darkened(0.2), 4.0, 0.4)
	var u_cop := 0.68
	var x_cop := -mezza + u_cop * mezza * 2.0
	var y_cop: float = y_tela.call(u_cop)
	for k in 2:
		var falda := _soffice(n, Vector3(0.135 - 0.010 * float(k), 0.024,
				0.160 - 0.012 * float(k)), rosa_cupo,
				Vector3(x_cop, y_cop + 0.024 + 0.020 * float(k), 0.004), 0.35, 0.55)
		falda.rotation.z = -0.08
	return n


## Un array di raggi tutti uguali, per BUILDER.tube (che li vuole punto
## per punto). Piccolo, ma scritto una volta sola.
static func _raggi_uguali(quanti: int, r: float) -> Array:
	var out: Array = []
	for i in quanti:
		out.append(r)
	return out


static func _swing() -> Node3D:
	# L'ALTALENA. Prima stava su per miracolo: due pali COMPLANARI (di
	# profilo era UN bastone) e una tavoletta appesa. Un'altalena da
	# giardino sta su con le CAPRIATE: due gambe ad A per lato col
	# traversino che le lega, la trave con le testate
	# tornite e le legature di corda sui nodi, e le funi che scendono dai
	# due ANELLI d'ottone che abbracciano la trave. Il sedile è una tavola
	# vera: bordi tondi, i correntini sotto, e i nodi delle funi che
	# spuntano — perché una fune non finisce nel legno: ci si annoda.
	var n := Node3D.new()
	var wood := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	var scuro := _mat(WOOD_DARK, WOOD_DARK.darkened(0.15), 3.5, 0.45)
	var rope := _mat(Color("c9b088"), Color("ab9066"), 5.0, 0.5)
	var ottone := _mat(OTTONE, OTTONE_SCURO, 5.0, 0.4)
	# le capriate ad A, col traversino e i piedini
	for x: float in [-0.48, 0.48]:
		for vz: float in [-1.0, 1.0]:
			var gamba := _cyl(n, 0.032, 0.045, 1.62, wood, Vector3(x, 0.755, vz * 0.165))
			gamba.rotation.x = -vz * 0.21
		var tira := _cyl(n, 0.018, 0.018, 0.46, wood, Vector3(x, 0.58, 0))
		tira.rotation.x = PI * 0.5
	# la trave: le testate tornite oltre le capriate, e le legature di
	# corda sui nodi
	var bar := _cyl(n, 0.042, 0.042, 1.16, wood, Vector3(0, 1.53, 0))
	bar.rotation.z = PI * 0.5
	for ex: float in [-1.0, 1.0]:
		var testata := _cyl(n, 0.052, 0.052, 0.03, scuro, Vector3(ex * 0.585, 1.53, 0))
		testata.rotation.z = PI * 0.5
		_ball(n, 0.045, wood, Vector3(ex * 0.612, 1.53, 0), Vector3(0.7, 1, 1))
		var lega := _cyl(n, 0.050, 0.050, 0.075, rope, Vector3(ex * 0.48, 1.53, 0))
		lega.rotation.z = PI * 0.5
	# i due anelli d'ottone da cui scendono le funi
	for ax: float in [-0.16, 0.16]:
		var anello := MeshInstance3D.new()
		var am := TorusMesh.new()
		am.inner_radius = 0.044
		am.outer_radius = 0.058
		am.rings = 20
		am.ring_segments = 8
		anello.mesh = am
		anello.material_override = ottone
		anello.position = Vector3(ax, 1.53, 0.015)
		anello.rotation.z = PI * 0.5
		n.add_child(anello)
	# LE DUE CORDE SONO VIVE E GEMELLE: il sedile è appeso a tutte e due
	# (vincolo fra i loro fondi), quindi spingerlo lo fa DONDOLARE come
	# un'altalena vera — e il vento lo culla da solo. peso_fondo è la
	# massa del sedile che tende le corde.
	var corda_a := _corda_viva(n, Vector3(-0.16, 1.51, 0.05),
			Vector3(-0.16, 0.625, 0.05), 0.015, 0.01, rope, 0.45, 8, 6)
	corda_a.name = "CordaA"
	var corda_b := _corda_viva(n, Vector3(0.16, 1.51, 0.05),
			Vector3(0.16, 0.625, 0.05), 0.015, 0.01, rope, 0.45, 8, 6)
	corda_b.name = "CordaB"
	# il sedile vive in un nodo suo, col pivot al punto d'aggancio: è il
	# gestore a posarlo fra le due corde, comunque stiano
	var sedile := Node3D.new()
	sedile.name = "Sedile"
	sedile.position = Vector3(0, 0.625, 0.05)
	n.add_child(sedile)
	var pale := _mat(WOOD_PALE, WOOD, 3.0, 0.5)
	_box(sedile, Vector3(0.44, 0.045, 0.20), pale, Vector3(0, -0.025, 0))
	for oz: float in [-1.0, 1.0]:
		var orlo := _cyl(sedile, 0.0225, 0.0225, 0.44, pale,
				Vector3(0, -0.025, oz * 0.10))
		orlo.rotation.z = PI * 0.5
	# i correntini sotto, e i nodi delle funi che spuntano dalla tavola
	for kx: float in [-0.16, 0.16]:
		_box(sedile, Vector3(0.05, 0.018, 0.21), scuro, Vector3(kx, -0.054, 0))
		_cyl(sedile, 0.012, 0.012, 0.055, rope, Vector3(kx, -0.028, 0))
		_ball(sedile, 0.019, rope, Vector3(kx, -0.072, 0))
	var meta_a: Dictionary = corda_a.get_meta("corda")
	meta_a["gemella"] = NodePath("../CordaB")
	meta_a["solidale"] = NodePath("../Sedile")
	meta_a["larghezza"] = 0.32
	meta_a["peso_fondo"] = 2.5
	corda_a.set_meta("corda", meta_a)
	var meta_b: Dictionary = corda_b.get_meta("corda")
	meta_b["peso_fondo"] = 2.5
	corda_b.set_meta("corda", meta_b)
	return n


static func _fountain() -> Node3D:
	# LA FONTANA DEL VILLAGGIO, monumentale. Prima era un tamburo PIENO
	# con un dischetto d'acqua sepolto DENTRO la pietra (la vasca in foto
	# era asciutta), un fuso e un tappo. Adesso è una fontana a due
	# ordini: la vasca bassa è un MURO ad anello modanato con l'acqua
	# vera dentro (e le monetine dei desideri sul fondo), la colonna è
	# tornita coi collarini, la vasca alta TRABOCCA — quattro rivoli
	# scendono davvero nell'acqua di sotto, con l'anello increspato dove
	# toccano — e in cima la pigna spinge lo zampillo. Di notte fa da
	# luce dolce: la Veglia la conta fra le luci del villaggio.
	var n := Node3D.new()
	var pietra := _mat(STONE, STONE_DARK, 3.0, 0.5)
	var pietra_chiara := _mat(Color("d8d0c2"), STONE, 3.5, 0.45)
	var acqua := _glow(Color(0.55, 0.82, 0.95, 0.75), Color(0.4, 0.7, 0.9), 0.18)
	acqua.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var acqua_viva := _glow(Color(0.68, 0.88, 1.0, 0.85), Color(0.5, 0.78, 0.95), 0.3)
	acqua_viva.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# ---- la vasca bassa: un muro ad anello col plinto e il bordo a toro
	# (il profilo sale fuori, scavalca il bordo e SCENDE dentro: la vasca
	# è cava e l'acqua ci sta dentro davvero)
	BUILDER.lathe(n, [
		Vector2(0.0, 0.0), Vector2(0.5, 0.0), Vector2(0.5, 0.05),
		Vector2(0.465, 0.07),                          # il plinto
		Vector2(0.45, 0.2), Vector2(0.435, 0.3),
		Vector2(0.47, 0.325), Vector2(0.475, 0.36),    # il bordo a toro
		Vector2(0.45, 0.375), Vector2(0.4, 0.36),      # …e il rientro
		Vector2(0.39, 0.1), Vector2(0.0, 0.08),        # dentro, fino al fondo
	], pietra, Vector3.ZERO, 30)
	# l'acqua della vasca, SOTTO il bordo — si vede perché la vasca è cava
	_cyl(n, 0.395, 0.395, 0.016, acqua, Vector3(0, 0.295, 0))
	# le monetine dei desideri sul fondo, sotto il velo d'acqua
	var monete := _mat(OTTONE, OTTONE_SCURO, 5.0, 0.35)
	for mi in 3:
		var ma := 0.8 + float(mi) * 2.3
		_cyl(n, 0.022, 0.022, 0.006, monete,
				Vector3(cos(ma) * (0.14 + 0.07 * float(mi)), 0.095,
				sin(ma) * (0.14 + 0.07 * float(mi))))
	# ---- la colonna tornita: base, entasi, collarino, capitello
	BUILDER.lathe(n, [
		Vector2(0.19, 0.08), Vector2(0.185, 0.13), Vector2(0.14, 0.16),
		Vector2(0.105, 0.2),
		Vector2(0.092, 0.36), Vector2(0.085, 0.52),    # l'entasi
		Vector2(0.098, 0.565), Vector2(0.098, 0.585), Vector2(0.088, 0.605),
		Vector2(0.085, 0.68), Vector2(0.12, 0.72), Vector2(0.15, 0.735),
	], pietra, Vector3.ZERO, 24)
	# ---- la vasca alta: una coppa che TRABOCCA
	BUILDER.lathe(n, [
		Vector2(0.02, 0.72), Vector2(0.16, 0.75), Vector2(0.24, 0.79),
		Vector2(0.285, 0.85), Vector2(0.295, 0.9),     # fuori, fino al labbro
		Vector2(0.27, 0.91), Vector2(0.25, 0.885),     # il labbro rientra
		Vector2(0.1, 0.855), Vector2(0.0, 0.85),       # dentro
	], pietra_chiara, Vector3.ZERO, 26)
	_cyl(n, 0.255, 0.255, 0.014, acqua_viva, Vector3(0, 0.878, 0))
	# ---- i quattro rivoli che scendono dalla coppa nell'acqua di sotto,
	# con l'anello increspato dove toccano
	for i in 4:
		var a := float(i) * TAU / 4.0 + 0.4
		var rx := cos(a)
		var rz := sin(a)
		var rivolo := _cyl(n, 0.012, 0.017, 0.58, acqua_viva,
				Vector3(rx * 0.293, 0.6, rz * 0.293))
		rivolo.rotation.z = rx * 0.06
		rivolo.rotation.x = -rz * 0.06
		var cerchio := MeshInstance3D.new()
		var cm := TorusMesh.new()
		cm.inner_radius = 0.035
		cm.outer_radius = 0.055
		cerchio.mesh = cm
		cerchio.material_override = acqua_viva
		cerchio.position = Vector3(rx * 0.31, 0.302, rz * 0.31)
		n.add_child(cerchio)
	# ---- la pigna in cima, e lo zampillo che ci ricade sopra
	BUILDER.lathe(n, [
		Vector2(0.055, 0.85), Vector2(0.075, 0.9), Vector2(0.078, 0.95),
		Vector2(0.06, 1.01), Vector2(0.028, 1.06), Vector2(0.0, 1.08),
	], pietra, Vector3.ZERO, 18)
	var zampillo := _cyl(n, 0.014, 0.02, 0.24, acqua_viva, Vector3(0, 1.17, 0))
	zampillo.name = "Zampillo"
	_ball(n, 0.032, acqua_viva, Vector3(0, 1.285, 0), Vector3(1, 0.7, 1))
	_emit_fx(n, Vector3(0, 1.3, 0), Color(0.72, 0.9, 1.0), 1.5, -3.4, 26, 1.0, 0.075)
	_emit_fx(n, Vector3(0, 0.9, 0), Color(0.78, 0.92, 1.0), 0.5, -2.2, 10, 0.8, 0.05)
	# ---- il muschio ai piedi, dove l'acqua schizza da sempre
	var muschio := _mat(LEAF, LEAF.darkened(0.2), 4.0, 0.4)
	for i in 3:
		var a := 1.1 + float(i) * 2.4
		_ball(n, 0.05 + 0.015 * float(i % 2), muschio,
				Vector3(cos(a) * 0.49, 0.045, sin(a) * 0.49), Vector3(1.2, 0.55, 1.0))
	# di notte è una luce dolce: la Veglia la conta fra le luci del
	# villaggio, e una fontana che brilla senza fare luce sarebbe bugiarda
	# ...e a 0.65/2.6 era proprio bugiarda: l'acqua brillava da sola e la
	# pietra restava nera. Adesso la vasca è illuminata DA DENTRO e per
	# terra resta un alone freddo. Non si sale oltre: a 2.2 lo specchio
	# d'acqua va in bianco e la fontana diventa una lampada.
	var luce := OmniLight3D.new()
	luce.light_color = Color(0.72, 0.86, 1.0)
	luce.light_energy = 1.1
	luce.omni_range = 3.0
	luce.omni_attenuation = 1.1
	luce.position = Vector3(0, 0.9, 0)
	luce.shadow_enabled = false
	n.add_child(luce)
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
	# «venite a sedervi» lo dice il TAVOLATO acceso, non la lanterna
	# accesa: a 0.9 il salotto restava al buio con una lucina in mezzo.
	# Oltre 2.1 il pavimento va in bianco e le assi spariscono.
	var luce := OmniLight3D.new()
	luce.light_color = Color(1.0, 0.86, 0.62)
	luce.light_energy = 1.5
	luce.omni_range = 3.6
	luce.omni_attenuation = 1.15
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


## LA GIOSTRA, stavolta in GRANDE: non più un soprammobile ma una
## giostra su cui salire — la pedana girevole a spicchi col gradino
## fisso tutt'attorno, quattro cavalli in taglia da cucciolo (sella,
## staffe, briglie, criniera, tutti sfalsati al galoppo), la corona
## decorata con le lucine calde per la sera, e su ogni sella un nodo
## «Posto»: il gancio per il giorno in cui un cucciolo ci monterà
## davvero, e girerà col nodo «Giro» — che intanto gira da solo,
## pianissimo, come il vento che l'ha appena caricata.
static func _carousel() -> Node3D:
	var n := Node3D.new()
	var legno_c := _mat(WOOD_PALE, WOOD, 3.0, 0.4)
	var rosa := _mat(PINK, PINK_DEEP, 4.0, 0.4)
	var panna := _mat(CREAM, Color("f3dfc8"), 4.0, 0.4)
	var oro := _mat(Color("f2cf7e"), Color("d9a84a"), 3.0, 0.4)
	var ottone := _mat(OTTONE, OTTONE_SCURO, 5.0, 0.4)
	var ferro := _mat(METAL, Color("6f665b"), 5.0, 0.4)
	var scuro_b := _mat(Color("6e4a35"), Color("59391f"), 4.0, 0.5)
	# il basamento FISSO: è anche il gradino da cui si sale
	BUILDER.lathe(n, [Vector2(1.16, 0.0), Vector2(1.18, 0.025),
			Vector2(1.13, 0.06), Vector2(1.0, 0.08), Vector2(0.2, 0.09)],
			legno_c)
	var bordo_b := MeshInstance3D.new()
	var bb := TorusMesh.new()
	bb.inner_radius = 1.13
	bb.outer_radius = 1.18
	bordo_b.mesh = bb
	bordo_b.material_override = rosa
	bordo_b.position = Vector3(0, 0.03, 0)
	n.add_child(bordo_b)
	# il palo centrale con la spirale a caramella e la manovella di carica
	_cyl(n, 0.055, 0.08, 2.42, ferro, Vector3(0, 1.28, 0))
	var spirale: Array = []
	var raggi_s: Array = []
	for i in 29:
		var t := float(i) / 28.0
		var a_s := t * TAU * 3.5
		var r_e := 0.088 - 0.024 * t
		spirale.append(Vector3(cos(a_s) * r_e, 0.22 + t * 1.9, sin(a_s) * r_e))
		raggi_s.append(0.014)
	BUILDER.tube(n, spirale, raggi_s, rosa, 84, 6)
	var braccio_m := _cyl(n, 0.012, 0.012, 0.11, ottone, Vector3(0.13, 0.3, 0))
	braccio_m.rotation.z = PI * 0.5
	_cyl(n, 0.02, 0.02, 0.07, scuro_b, Vector3(0.185, 0.335, 0))
	# TUTTO QUELLO CHE GIRA sta sotto questo nodo
	var giro := Node3D.new()
	giro.name = "Giro"
	n.add_child(giro)
	# la pedana girevole a spicchi rosa e panna, col suo bordo
	var pavimento: Array = [Vector2(1.0, 0.14), Vector2(0.98, 0.155),
			Vector2(0.55, 0.16), Vector2(0.14, 0.165)]
	for s_p in 12:
		var a_p := TAU / 12.0 * float(s_p)
		_lathe_spicchio(giro, pavimento, rosa if s_p % 2 == 0 else panna,
				a_p, a_p + TAU / 12.0)
	var cinta := MeshInstance3D.new()
	var cm := TorusMesh.new()
	cm.inner_radius = 0.955
	cm.outer_radius = 1.005
	cinta.mesh = cm
	cinta.material_override = legno_c
	cinta.position = Vector3(0, 0.135, 0)
	giro.add_child(cinta)
	# il tendone a spicchi con la frangia smerlata e il puntale con la
	# bandierina; sotto il bordo, la CORONA coi pomelli d'oro e le
	# lucine calde della sera
	var tenda: Array = [Vector2(1.25, -0.24), Vector2(1.21, -0.19),
			Vector2(1.04, -0.08), Vector2(0.76, 0.05), Vector2(0.45, 0.17),
			Vector2(0.16, 0.27), Vector2(0.0, 0.31)]
	var falda_g := Node3D.new()
	falda_g.position = Vector3(0, 2.42, 0)
	giro.add_child(falda_g)
	for s2 in 12:
		var a0 := TAU / 12.0 * float(s2)
		_lathe_spicchio(falda_g, tenda, rosa if s2 % 2 == 0 else panna,
				a0, a0 + TAU / 12.0)
	for d_f in 24:
		var a_d := TAU / 24.0 * (float(d_f) + 0.5)
		var dente := _ball(giro, 0.07,
				rosa if (d_f >> 1) % 2 == 0 else panna,
				Vector3(cos(a_d) * 1.22, 2.165, -sin(a_d) * 1.22),
				Vector3(1.0, 0.55, 0.45))
		dente.rotation.y = a_d + PI * 0.5
	_cyl(giro, 0.02, 0.02, 0.14, oro, Vector3(0, 2.78, 0))
	_ball(giro, 0.085, oro, Vector3(0, 2.87, 0))
	var bandiera := _prisma(giro, [Vector2(0.0, 0.0), Vector2(0.17, 0.05),
			Vector2(0.17, -0.05)], 0.0, 0.014, rosa)
	bandiera.position = Vector3(0.02, 2.85, 0)
	bandiera.rotation.x = PI * 0.5
	bandiera.rotation.y = -0.4
	var corona := _cyl(giro, 1.235, 1.235, 0.13, panna, Vector3(0, 2.13, 0))
	corona.name = "Corona"
	for g_c in 16:
		var a_c := TAU / 16.0 * float(g_c)
		if g_c % 2 == 0:
			_ball(giro, 0.035, oro,
					Vector3(cos(a_c) * 1.24, 2.13, sin(a_c) * 1.24))
		else:
			_ball(giro, 0.028, _glow(Color("ffe6b0"), Color("ffcf86"), 1.2),
					Vector3(cos(a_c) * 1.24, 2.13, sin(a_c) * 1.24))
	# i QUATTRO CAVALLI in taglia da cucciolo, sfalsati al galoppo, coi
	# pali d'oro che li infilzano dalla tenda alla pedana. Su ogni sella
	# il nodo «Posto»: un giorno un cucciolo ci monta, e gira col Giro.
	var manti: Array = [[Color("fff3e0"), Color("efe2ca")],
			[PINK, PINK_DEEP], [Color("9ec9e8"), Color("7fb2d8")],
			[Color("cdbff0"), Color("b3a2e0")]]
	for i in 4:
		var a := float(i) * TAU / 4.0 + 0.4
		var hx := cos(a) * 0.72
		var hz := sin(a) * 0.72
		var hy := 0.62 if i % 2 == 0 else 0.5
		# IL PALO PASSA DAL GARRESE, davanti alla sella: chi monta siede
		# DIETRO e lo tiene davanti a sé — un palo in mezzo alla sella è
		# un cucciolo compenetrato. Alla base il collare fermapalo, e in
		# quota i due collari-impugnatura dove si stringono le zampe.
		var px := hx - 0.11 * sin(a)
		var pz := hz + 0.11 * cos(a)
		_cyl(giro, 0.016, 0.016, 2.06, ottone, Vector3(px, 1.19, pz))
		_cyl(giro, 0.026, 0.03, 0.028, ottone, Vector3(px, 0.185, pz))
		for qg: float in [0.24, 0.36]:
			_cyl(giro, 0.021, 0.021, 0.014, ottone, Vector3(px, hy + qg, pz))
		var cav := Node3D.new()
		cav.position = Vector3(hx, hy, hz)
		cav.rotation.y = -(a + PI * 0.5)
		giro.add_child(cav)
		var manto := _mat(manti[i][0], manti[i][1], 4.0, 0.45)
		var criniera := _mat(manti[(i + 2) % 4][0], manti[(i + 2) % 4][1], 4.0, 0.5)
		_ball(cav, 0.13, manto, Vector3.ZERO, Vector3(1.7, 0.85, 0.75))
		# collo, testa china, musetto, orecchie — e la criniera SCRIMINATA,
		# le ciocche buttate un po' di qua e un po' di là: lascia il varco
		# al palo, ed è così che stanno le criniere al vento
		_ball(cav, 0.075, manto, Vector3(0.175, 0.1, 0), Vector3(0.85, 1.35, 0.7))
		_ball(cav, 0.075, manto, Vector3(0.225, 0.205, 0))
		_ball(cav, 0.046, manto, Vector3(0.295, 0.175, 0), Vector3(1.3, 0.8, 0.85))
		for or_c: float in [-1.0, 1.0]:
			var orecchia := _ball(cav, 0.024, manto,
					Vector3(0.2, 0.265, or_c * 0.035), Vector3(0.7, 1.5, 0.6))
			orecchia.rotation.z = -0.3
		for cr in 4:
			var lato_cr := 0.024 if cr % 2 == 0 else -0.024
			_ball(cav, 0.032, criniera,
					Vector3(0.2 - float(cr) * 0.055, 0.185 - float(cr) * 0.028, lato_cr),
					Vector3(0.8, 1.1, 0.55))
		# le briglie dal musetto alla sella
		BUILDER.tube(cav, [Vector3(0.3, 0.14, 0.03), Vector3(0.16, 0.1, 0.05),
				Vector3(0.02, 0.115, 0.04)], [0.006, 0.006, 0.006], scuro_b, 12, 5)
		# le zampe al galoppo: davanti raccolte, dietro distese
		for z_c: Array in [[0.115, -0.55], [0.06, -0.4], [-0.09, 0.5], [-0.14, 0.65]]:
			var zampa := _cyl(cav, 0.021, 0.027, 0.15, manto,
					Vector3(float(z_c[0]), -0.125, 0.0))
			zampa.rotation.z = float(z_c[1])
		# la sella imbottita col bottone, le staffe che pendono, il codino
		_lastra(cav, 0.1, 0.175, 0.045, 0.012, criniera,
				Vector3(-0.02, 0.092, 0), Vector3(0, 0, PI * 0.5))
		var sella := _lastra(cav, 0.085, 0.15, 0.035, 0.025,
				rosa if i % 2 == 1 else panna,
				Vector3(-0.01, 0.105, 0), Vector3(0, 0, PI * 0.5))
		sella.name = "Sella"
		# la sella resta PIATTA e sgombra: bottone e pomo, a questa
		# scala, sembravano cose dimenticate sul sedile — ci si tiene
		# al palo, che per questo sta davanti
		for st_f: float in [-1.0, 1.0]:
			_lastra(cav, 0.012, 0.1, 0.005, 0.008, scuro_b,
					Vector3(-0.01, 0.02, st_f * 0.1), Vector3(0, 0, 0))
			var staffa := MeshInstance3D.new()
			var sf := TorusMesh.new()
			sf.inner_radius = 0.016
			sf.outer_radius = 0.028
			staffa.mesh = sf
			staffa.material_override = ottone
			staffa.position = Vector3(-0.01, -0.04, st_f * 0.1)
			staffa.rotation.x = PI * 0.5
			staffa.rotation.z = PI * 0.5
			cav.add_child(staffa)
		_ball(cav, 0.05, criniera, Vector3(-0.21, 0.04, 0), Vector3(1.4, 0.6, 0.6))
		var posto := Node3D.new()
		posto.name = "Posto%d" % i
		posto.position = Vector3(-0.01, 0.16, 0)
		cav.add_child(posto)
	# la luce calda sotto la corona: la sera la giostra è una lanterna.
	# Il tetto piano dell'energia lo dà la PEDANA: oltre 2.0 gli spicchi
	# crema e rosa si fondono in un disco bianco e la ruota di colori —
	# che è tutta la festa — sparisce.
	var luce_g := OmniLight3D.new()
	luce_g.light_color = Color(1.0, 0.86, 0.66)
	luce_g.light_energy = 1.4
	luce_g.omni_range = 4.0
	luce_g.omni_attenuation = 1.1
	luce_g.position = Vector3(0, 1.9, 0)
	n.add_child(luce_g)
	# e il giro LENTO: un giro intero in quaranta secondi
	var anim := Animation.new()
	anim.length = 40.0
	anim.loop_mode = Animation.LOOP_LINEAR
	var tr := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(tr, NodePath("Giro:rotation:y"))
	anim.track_insert_key(tr, 0.0, 0.0)
	anim.track_insert_key(tr, 40.0, TAU)
	anim.track_set_interpolation_type(tr, Animation.INTERPOLATION_LINEAR)
	var lib := AnimationLibrary.new()
	lib.add_animation("gira", anim)
	var player := AnimationPlayer.new()
	n.add_child(player)
	player.add_animation_library("", lib)
	player.autoplay = "gira"
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
	# IL CERCHIO CALDO. Un braciere non è una lampada: il suo mestiere è
	# scaldare il cerchio di chi ci sta intorno, e a 1.7/4.2/1.0 per terra
	# c'era una foschia uniforme senza centro. Con la caduta a 1.3 il
	# cerchio ha un cuore e un bordo, e la brace sopra torna incandescente.
	var light := OmniLight3D.new()
	light.name = "Brace"
	light.light_color = Color(1.0, 0.82, 0.5)
	light.light_energy = BRACE_ENERGIA
	light.omni_range = 4.6
	light.omni_attenuation = 1.2
	# la sorgente resta dov'era, appena sopra il piatto. (Provata anche a
	# 0.92, dentro la colonna di fiamma, sospettando che da così vicino
	# sbiancasse la brace: renduto, non cambia niente di visibile. Il
	# piatto esce chiaro perché è brace vera, e la brace al culmine è
	# gialla — non è una bruciatura da correggere.)
	light.position = Vector3(0, 0.72, 0)
	n.add_child(light)
	# ...e RESPIRA. Un fuoco con la luce ferma è un adesivo di fuoco: si
	# smaschera in due secondi. Il giro è di 4.3 s (il Camino ne fa 3.7:
	# due fuochi vicini non devono richiudersi mai insieme) e i battiti
	# non sono a passo regolare — un fuoco non ha ritmo.
	var fiamma := Animation.new()
	fiamma.length = 4.3
	fiamma.loop_mode = Animation.LOOP_LINEAR
	var tr_b := fiamma.add_track(Animation.TYPE_VALUE)
	fiamma.track_set_path(tr_b, NodePath("Brace:light_energy"))
	for kb in [[0.0, 1.00], [0.29, 1.13], [0.62, 0.88], [0.95, 1.06],
			[1.37, 0.94], [1.78, 1.18], [2.21, 0.85], [2.64, 1.09],
			[3.05, 0.97], [3.48, 1.15], [3.90, 0.91], [4.30, 1.00]]:
		fiamma.track_insert_key(tr_b, float(kb[0]), BRACE_ENERGIA * float(kb[1]))
	fiamma.track_set_interpolation_type(tr_b, Animation.INTERPOLATION_CUBIC)
	# e la sorgente si sposta di pochi millimetri: le ombre attorno si
	# assestano invece di restare inchiodate
	var tr_bx := fiamma.add_track(Animation.TYPE_VALUE)
	fiamma.track_set_path(tr_bx, NodePath("Brace:position:x"))
	fiamma.track_insert_key(tr_bx, 0.0, -0.018)
	fiamma.track_insert_key(tr_bx, 1.6, 0.022)
	fiamma.track_insert_key(tr_bx, 2.9, -0.012)
	fiamma.track_insert_key(tr_bx, 4.3, -0.018)
	fiamma.track_set_interpolation_type(tr_bx, Animation.INTERPOLATION_CUBIC)
	var lib_b := AnimationLibrary.new()
	lib_b.add_animation("brace", fiamma)
	var player_b := AnimationPlayer.new()
	n.add_child(player_b)
	player_b.add_animation_library("", lib_b)
	player_b.autoplay = "brace"
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

	# LA VITA SUL PIANO: a distanza di catalogo la console leggeva come un
	# tavolo da pranzo vuoto. Un piano da estetista e' un piccolo paesaggio:
	# le boccette di profumo coi tappi d'ottone, il vasetto con UN fiore,
	# il vassoio con la spazzola, la pila di asciugamani.
	var vetro_c := StandardMaterial3D.new()
	vetro_c.albedo_color = Color(0.9, 0.94, 0.96, 0.45)
	vetro_c.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	vetro_c.roughness = 0.1
	var piano_y := SAL_CONSOLE + 0.0175
	# le due boccette tonde e quella quadrata, coi tappi d'ottone
	_cyl(n, 0.016, 0.018, 0.05, vetro_c, Vector3(0.245, piano_y + 0.025, z - 0.045))
	_ball(n, 0.011, ottone, Vector3(0.245, piano_y + 0.058, z - 0.045))
	_cyl(n, 0.012, 0.014, 0.038, vetro_c, Vector3(0.30, piano_y + 0.019, z - 0.01))
	_ball(n, 0.009, ottone, Vector3(0.30, piano_y + 0.045, z - 0.01))
	_box(n, Vector3(0.032, 0.042, 0.032), _mat(Color("f0b3c4"), Color("dd9aae"), 5.0, 0.35),
			Vector3(0.19, piano_y + 0.021, z + 0.015))
	_cyl(n, 0.008, 0.008, 0.014, ottone, Vector3(0.19, piano_y + 0.049, z + 0.015))
	# il vasetto col fiore
	_cyl(n, 0.011, 0.014, 0.06, vetro_c, Vector3(-0.30, piano_y + 0.03, z - 0.02))
	_cyl(n, 0.003, 0.003, 0.05, _mat(Color("7fae6a"), Color("5f8a4e"), 4.0, 0.45),
			Vector3(-0.30, piano_y + 0.075, z - 0.02))
	_ball(n, 0.014, _mat(PINK, PINK_DEEP, 5.0, 0.4),
			Vector3(-0.30, piano_y + 0.104, z - 0.02))
	# il vassoio con la spazzola
	_box(n, Vector3(0.15, 0.008, 0.095), _mat(WOOD, WOOD_DARK, 5.0, 0.4),
			Vector3(-0.11, piano_y + 0.004, z + 0.03))
	var spazzola := _box(n, Vector3(0.085, 0.014, 0.032),
			_mat(WOOD_DARK, WOOD_DARK.darkened(0.15), 5.0, 0.4),
			Vector3(-0.12, piano_y + 0.015, z + 0.025))
	spazzola.rotation.y = 0.35
	var setole := _box(n, Vector3(0.062, 0.010, 0.024),
			_mat(Color("f3e6d0"), Color("dfd0b8"), 6.0, 0.35),
			Vector3(-0.12, piano_y + 0.027, z + 0.025))
	setole.rotation.y = 0.35
	# la pila di asciugamani
	_box(n, Vector3(0.075, 0.016, 0.055), _mat(CREAM, Color("f0e4cc"), 5.0, 0.35),
			Vector3(0.10, piano_y + 0.008, z - 0.05))
	_box(n, Vector3(0.07, 0.014, 0.05), _mat(Color("f0b3c4"), Color("dd9aae"), 5.0, 0.35),
			Vector3(0.10, piano_y + 0.023, z - 0.05))

	# I MONTANTI: due colonnine tornite che salgono fino alla VITA dello
	# specchio, dove i PERNI d'ottone con la rosetta lo reggono davvero —
	# la grammatica dello specchio da toeletta: appeso ai suoi perni, e
	# proprio lì si inclina. (Prima i pali finivano a mezz'aria: a 0.78 la
	# cornice ovale è già rientrata a ±0.17, e restavano cinque centimetri
	# di vuoto.)
	for sx2: float in [-1.0, 1.0]:
		var px := sx2 * 0.265
		# il collarino alla base, il fusto rastremato, la perlina a metà,
		# il collo e il pomolo in cima
		_cyl(n, 0.027, 0.032, 0.024, legno_chiaro, Vector3(px, 0.490, z))
		_cyl(n, 0.016, 0.020, 0.44, legno_chiaro, Vector3(px, 0.72, z))
		_cyl(n, 0.024, 0.024, 0.016, legno_chiaro, Vector3(px, 0.60, z))
		_cyl(n, 0.021, 0.016, 0.03, legno_chiaro, Vector3(px, 0.952, z))
		_ball(n, 0.026, legno_chiaro, Vector3(px, 0.982, z), Vector3(1, 0.8, 1))
		# il perno che entra nella cornice, la rosetta sul fusto e il
		# pomellino per stringere
		var perno := _cyl(n, 0.011, 0.011, 0.06, ottone,
				Vector3(sx2 * 0.238, SAL_SPECCHIO, z))
		perno.rotation.z = PI * 0.5
		var rosetta := _cyl(n, 0.019, 0.019, 0.012, ottone,
				Vector3(sx2 * 0.288, SAL_SPECCHIO, z))
		rosetta.rotation.z = PI * 0.5
		_ball(n, 0.012, ottone, Vector3(sx2 * 0.299, SAL_SPECCHIO, z))

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
	# il filetto d'ottone appena dentro la cornice: il bordo molato che a
	# distanza di catalogo separa il vetro dal legno (senza, il disco pare
	# dipinto sulla cornice)
	var filetto := MeshInstance3D.new()
	var fm := TorusMesh.new()
	fm.inner_radius = 0.180
	fm.outer_radius = 0.192
	fm.rings = 40
	fm.ring_segments = 6
	filetto.mesh = fm
	filetto.material_override = ottone
	filetto.position = Vector3(0, SAL_SPECCHIO, z + 0.006)
	filetto.rotation.x = PI * 0.5
	filetto.scale = Vector3(1.0, 1.0, 1.20)
	n.add_child(filetto)

	# il fondo del vetro, piu' caldo: la stanza che ci si specchia
	var basso := StandardMaterial3D.new()
	basso.albedo_color = Color(0.78, 0.73, 0.70)
	basso.roughness = 0.12
	basso.metallic = 0.2
	var giu := _cyl(n, 0.193, 0.193, 0.005, basso, Vector3(0, SAL_SPECCHIO - 0.075, z + 0.008))
	giu.rotation.x = PI * 0.5
	giu.scale = Vector3(1.0, 1.0, 0.72)

	# LA LAMA DI LUCE: un nastro sottile in diagonale, unshaded e
	# additivo — non "colora" il vetro, ci si somma sopra come un
	# riflesso vero
	var lama_mat := StandardMaterial3D.new()
	lama_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lama_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lama_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	lama_mat.albedo_color = Color(1, 1, 1, 0.5)
	var lama := _box(n, Vector3(0.062, 0.34, 0.003), lama_mat,
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
	var orlo := _cyl(n, 0.021, 0.021, 0.29, velluto_scuro,
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
	var cima := _cyl(sch, 0.028, 0.028, 0.275, velluto_scuro, Vector3(0, 0.236, 0))
	cima.rotation.z = PI * 0.5
	for sx0: float in [-1.0, 1.0]:
		_cyl(sch, 0.024, 0.024, 0.235, velluto_scuro, Vector3(sx0 * 0.137, 0.118, 0))
	# i tre bottoni del capitonne': a distanza di catalogo sono loro a
	# dire «imbottito»
	for bp: Vector2 in [Vector2(-0.062, 0.085), Vector2(0.062, 0.085), Vector2(0.0, 0.16)]:
		_ball(sch, 0.0095, velluto_scuro, Vector3(bp.x, bp.y, 0.030))
	# la cucitura verticale al centro
	_box(sch, Vector3(0.008, 0.20, 0.008), velluto_scuro, Vector3(0, 0.115, 0.028))
	# il poggiatesta: un cuscinetto staccato, sospeso su due astine
	for sx1: float in [-1.0, 1.0]:
		_cyl(sch, 0.006, 0.006, 0.05, acciaio, Vector3(sx1 * 0.045, 0.275, 0.0))
	_box(sch, Vector3(0.15, 0.062, 0.052), velluto, Vector3(0, 0.325, 0.0))
	var cima2 := _cyl(sch, 0.026, 0.026, 0.15, velluto_scuro, Vector3(0, 0.352, 0.0))
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
const RAME := Color("c9824f")
const SEGNALE_ROSSO := Color("dd8474")
const SEGNALE_BIANCO := Color("f7f2e6")
# l'ottone lo dichiara già la tavolozza in cima al file: qui si riusa il suo,
# o due tonalità diverse dello stesso metallo convivrebbero nel villaggio
const SUGHERO := Color("d8b487")


## LA LUCE BLU, tarata di NOTTE e una volta sola: la montano il lume
## della guardiola, quello dell'insegna e il fanale del lampione, e se
## ognuno tenesse i suoi numeri il villaggio avrebbe tre blu diversi.
##
## I numeri vengono da un provino notturno vero (tools/provino_variante.gd
## con CHIBI_NOTTE=1), e la lezione e' questa: LA POZZA SI FA CON LA
## PORTATA, NON CON L'ENERGIA. A raggio 9 la luce arrivava dappertutto e
## per terra restava una velatura uniforme — cioe' nessuna pozza; spingere
## l'energia non cambiava niente, sbiancava solo il vetro. Corta e ripida
## Scelta su CINQUE tarature affiancate e renderizzate al buio: la piu'
## stretta (3.6/4.9/1.9) fa una pozza intensa ma l'alone si mangia i
## pannelli della gabbia, la piu' larga (8/9/1.5) torna a velatura.
## 4.5 / 6.0 / 1.2: pozza ampia e il vetro resta leggibile.
## Il colore va SATURO: un bianco appena freddo non e' una lanterna blu.
static func _luce_blu(parent: Node3D, pos: Vector3, forza := 1.0) -> OmniLight3D:
	var luce := OmniLight3D.new()
	luce.light_color = Color(0.42, 0.60, 1.0)
	luce.light_energy = 4.5 * forza
	luce.omni_range = 6.0
	luce.omni_attenuation = 1.2
	luce.shadow_enabled = false
	luce.position = pos
	parent.add_child(luce)
	return luce


## Il lume azzurro: il segnale che di notte dice «qui c'è qualcuno
## sveglio». Ritorna il nodo della lanterna, così i pezzi che la
## montano possono chiamarlo "Lume" e accenderlo o spegnerlo.
## Da lanterna VERA: cappello a pagodina con l'anello, coppa tornita
## con la goccia, montanti tondi legati da due anelli, la fiammella
## dentro il vetro — e una luce BLU sul serio, non azzurrina slavata.
static func _lume_azzurro(parent: Node3D, pos: Vector3, scala := 1.0) -> Node3D:
	var lume := Node3D.new()
	lume.name = "Lume"
	lume.position = pos
	lume.scale = Vector3.ONE * scala
	parent.add_child(lume)
	var ottone := _mat(OTTONE, OTTONE_SCURO, 5.0, 0.4)
	# il cappello a pagodina, con l'anello per appenderla
	BUILDER.lathe(lume, [Vector2(0.105, 0.0), Vector2(0.1, 0.013),
			Vector2(0.075, 0.04), Vector2(0.045, 0.062), Vector2(0.018, 0.08),
			Vector2(0.0, 0.088)], ottone, Vector3(0, 0.112, 0))
	_cyl(lume, 0.006, 0.006, 0.02, ottone, Vector3(0, 0.208, 0))
	var anello_l := MeshInstance3D.new()
	var am := TorusMesh.new()
	am.inner_radius = 0.012
	am.outer_radius = 0.022
	anello_l.mesh = am
	anello_l.material_override = ottone
	anello_l.position = Vector3(0, 0.235, 0)
	anello_l.rotation.x = PI * 0.5
	lume.add_child(anello_l)
	# la coppa tornita sotto, con la goccia che finisce il lavoro
	BUILDER.lathe(lume, [Vector2(0.02, 0.0), Vector2(0.052, 0.014),
			Vector2(0.068, 0.032), Vector2(0.072, 0.05)], ottone,
			Vector3(0, -0.14, 0))
	_ball(lume, 0.016, ottone, Vector3(0, -0.15, 0))
	_cyl(lume, 0.002, 0.008, 0.022, ottone, Vector3(0, -0.172, 0))
	# i quattro montanti TONDI, legati dai due anelli
	for i in 4:
		var a := PI * 0.5 * float(i) + PI * 0.25
		_cyl(lume, 0.007, 0.007, 0.2, ottone,
				Vector3(cos(a) * 0.056, 0.012, sin(a) * 0.056))
	for qa: float in [-0.078, 0.104]:
		var cerchio := MeshInstance3D.new()
		var cm := TorusMesh.new()
		cm.inner_radius = 0.052
		cm.outer_radius = 0.066
		cerchio.mesh = cm
		cerchio.material_override = ottone
		cerchio.position = Vector3(0, qa, 0)
		lume.add_child(cerchio)
	# il vetro. Il blu va SATURO e l'emissione tenuta bassa: con l'energia
	# alta il vetro si sbianca e la lanterna «blu» esce color miele come
	# tutte le altre. Dentro, la FIAMMELLA: un cuore più chiaro che dà
	# profondità al vetro invece di lasciarlo una biglia.
	var vetro := _ball(lume, 0.072, _glow(Color("4f78d4"), Color("5f8ce8"), 0.9),
			Vector3(0, 0.015, 0), Vector3(1.0, 1.25, 1.0))
	vetro.name = "Vetro"
	_ball(lume, 0.022, _glow(Color("cfe2ff"), Color("e8f2ff"), 1.8),
			Vector3(0, 0.0, 0), Vector3(0.8, 1.3, 0.8))
	# e la luce viene dalla fonte unica, tarata al buio
	_luce_blu(lume, Vector3(0, 0.015, 0))
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
	# L'INSEGNA DELLA GUARDIA: un'insegna da locanda fatta come si deve.
	# Il palo tornito con basetta e pomello, il braccio col puntone di
	# legno, il tettuccio di rame che ripara la tavola, e la tavola stessa
	# non è legno nudo: è una BANDIERA dipinta di blu col fondo tondo,
	# bordata d'ottone, appesa a due catenelle vere. Sopra, il glifo della
	# lanterna col vetrino caldo e tre stelle piccole — la notte vegliata.
	# E in punta al braccio pende la lanterna VERA, accesa: è la guardia
	# quella che tiene il lume per tutti, e la sua insegna lo fa, non lo
	# dice soltanto. Si monta sul bordo di una cella, come un muro.
	# (Ci fu anche una voluta di ferro battuto sotto il braccio: da vicino
	# era un riccio, da lontano un coso di ferro sopra lo stemma — via.)
	var n := Node3D.new()
	var legno := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	var legno_scuro := _mat(WOOD_DARK, Color("8a6540"), 3.5, 0.5)
	var ottone := _mat(OTTONE, OTTONE_SCURO, 5.0, 0.4)
	var ferro := _mat(METAL, Color("6d6259"), 5.0, 0.4)
	var pietra := _mat(STONE, STONE_DARK, 4.0, 0.5)
	var blu := _mat(BLU, BLU_CUPO, 5.0, 0.4)
	var rame := _mat(RAME, RAME.darkened(0.3), 5.0, 0.4)

	# il palo: basetta di pietra, fusto rastremato, anello a mezza
	# altezza, collarino e pomello d'ottone — un arredo, non un'asta
	_cyl(n, 0.075, 0.09, 0.07, pietra, Vector3(-0.36, 0.035, 0))
	_cyl(n, 0.042, 0.056, 1.95, legno, Vector3(-0.36, 1.045, 0))
	_cyl(n, 0.056, 0.056, 0.025, legno_scuro, Vector3(-0.36, 1.05, 0))
	_cyl(n, 0.058, 0.058, 0.035, legno_scuro, Vector3(-0.36, 2.03, 0))
	_ball(n, 0.036, ottone, Vector3(-0.36, 2.08, 0))

	# il braccio, un filo più lungo: in punta ci vive la lanterna. La
	# rosetta di ferro dove morde il palo, e il pomellino in cima
	_box(n, Vector3(0.76, 0.06, 0.06), legno, Vector3(0.01, 1.94, 0))
	_cyl(n, 0.05, 0.05, 0.03, ferro, Vector3(-0.355, 1.94, 0)).rotation.z = PI * 0.5
	_cyl(n, 0.017, 0.022, 0.036, legno_scuro, Vector3(0.365, 1.892, 0))
	_ball(n, 0.015, legno_scuro, Vector3(0.365, 1.874, 0))

	# il puntone di legno che regge il braccio: pulito, senza ferri in
	# vista sopra lo stemma — e RIPIDO, stretto al palo, così non
	# attraversa la catenella che gli pende accanto
	var puntone := _box(n, Vector3(0.045, 0.32, 0.045), legno, Vector3(-0.315, 1.82, 0))
	puntone.rotation.z = -0.35

	# IL TETTUCCIO di rame sopra la tavola: due faldine e il colmo — la
	# pioggia scivola via, e il rame fa il paio con l'ottone del corredo
	for fz: float in [-1.0, 1.0]:
		var faldina := _box(n, Vector3(0.6, 0.02, 0.13), rame,
				Vector3(-0.03, 1.985, fz * 0.05))
		faldina.rotation.x = fz * -0.5
	_box(n, Vector3(0.62, 0.025, 0.05), legno_scuro, Vector3(-0.03, 2.02, 0))

	# la tavola appesa: nodo a parte, così può dondolare
	var appesa := Node3D.new()
	appesa.name = "Insegna"
	appesa.position = Vector3(-0.03, 1.91, 0)
	n.add_child(appesa)
	# le CATENELLE: anellini d'ottone alternati, non due astine rigide —
	# è la catena a dire «appeso», e si vede anche da lontano
	for dx: float in [-0.2, 0.2]:
		for k in 4:
			var maglia := TorusMesh.new()
			maglia.inner_radius = 0.008
			maglia.outer_radius = 0.016
			maglia.rings = 12
			maglia.ring_segments = 6
			var mmi := MeshInstance3D.new()
			mmi.mesh = maglia
			mmi.material_override = ottone
			mmi.position = Vector3(dx, -0.018 - float(k) * 0.026, 0)
			mmi.rotation.x = PI * 0.5
			mmi.rotation.y = PI * 0.5 * float(k % 2)
			appesa.add_child(mmi)

	# LA BANDIERA: rettangolo + fondo tondo, doppio strato (cornice scura
	# dietro, campo blu davanti) — una tavola dipinta, non legno grezzo
	var tavola := _box(appesa, Vector3(0.56, 0.36, 0.04), legno_scuro, Vector3(0, -0.29, 0))
	tavola.name = "Tavola"
	var fondo_scuro := _cyl(appesa, 0.28, 0.28, 0.04, legno_scuro, Vector3(0, -0.47, 0))
	fondo_scuro.rotation.x = PI * 0.5
	var scudo := _box(appesa, Vector3(0.5, 0.33, 0.032), blu, Vector3(0, -0.285, -0.008))
	scudo.name = "Scudo"
	var fondo_blu := _cyl(appesa, 0.25, 0.25, 0.032, blu, Vector3(0, -0.46, -0.008))
	fondo_blu.rotation.x = PI * 0.5
	# il filetto d'ottone che rifinisce il campo: sopra e ai due lati
	_box(appesa, Vector3(0.46, 0.014, 0.01), ottone, Vector3(0, -0.145, -0.028))
	for lx: float in [-1.0, 1.0]:
		_box(appesa, Vector3(0.014, 0.32, 0.01), ottone, Vector3(lx * 0.225, -0.3, -0.028))
	# le borchie d'ottone ai due angoli alti
	for bx: float in [-1.0, 1.0]:
		_ball(appesa, 0.014, ottone, Vector3(bx * 0.245, -0.165, -0.024), Vector3(1, 1, 0.5))

	# il glifo della lanterna, grande, col vetrino caldo: cappellino,
	# montanti, vetro acceso, coppa e anellino
	_ball(appesa, 0.012, ottone, Vector3(0, -0.245, -0.03))
	_cyl(appesa, 0.016, 0.052, 0.045, ottone, Vector3(0, -0.283, -0.03))
	for mx: float in [-1.0, 1.0]:
		_box(appesa, Vector3(0.01, 0.075, 0.01), ottone, Vector3(mx * 0.036, -0.345, -0.03))
	var vetro_lume := _glow(Color("ffe9b8"), Color("ffd27a"), 0.42)
	_box(appesa, Vector3(0.056, 0.072, 0.018), vetro_lume, Vector3(0, -0.345, -0.03))
	_cyl(appesa, 0.036, 0.042, 0.02, ottone, Vector3(0, -0.393, -0.03))
	# le tre stelle piccole attorno: la notte vegliata
	_ball(appesa, 0.011, ottone, Vector3(-0.14, -0.24, -0.028), Vector3(1, 1, 0.45))
	_ball(appesa, 0.009, ottone, Vector3(0.15, -0.27, -0.028), Vector3(1, 1, 0.45))
	_ball(appesa, 0.01, ottone, Vector3(0.11, -0.5, -0.028), Vector3(1, 1, 0.45))

	# LA LANTERNA VERA, appesa in punta al braccio: il gancetto e il lume
	# azzurro acceso — l'insegna della guardia FA luce, non la disegna.
	# Il cappello tocca il gancio: un vuoto lì in mezzo è una lanterna
	# che levita, non che pende
	_box(n, Vector3(0.02, 0.06, 0.02), ferro, Vector3(0.365, 1.835, 0))
	_lume_azzurro(n, Vector3(0.365, 1.74, 0), 0.5)

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
	#
	# La prima stesura era due box scuri e una riga di fasce: squadrata, e
	# con DUE difetti che si vedevano solo guardando la foto — l'asta
	# galleggiava trentasei centimetri sopra il paletto d'appoggio (troppo
	# corto), e la punta non lo raggiungeva nemmeno. Ora l'asta è TONDA
	# con gli anelli rossi calzati sopra, la cerniera ha le guance e il
	# perno passante con le testine d'ottone, il contrappeso ha il collare,
	# e il paletto arriva dove deve: con la FORCELLA che culla l'asta.
	var n := Node3D.new()
	var legno := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	var legno_scuro := _mat(WOOD_DARK, Color("8a6540"), 3.5, 0.5)
	var ottone := _mat(OTTONE, OTTONE_SCURO, 5.0, 0.4)
	var ferro := _mat(METAL, Color("6d6259"), 5.0, 0.4)
	var pietra := _mat(STONE, STONE_DARK, 4.0, 0.5)
	var bianco := _mat(SEGNALE_BIANCO, Color("e9e2d2"), 4.0, 0.35)
	var rosso := _mat(SEGNALE_ROSSO, Color("c96f60"), 4.0, 0.4)

	# IL MONTANTE: basetta di pietra a due corsi, fusto tondo di legno,
	# coperchietto e pomello — la famiglia è quella del posto di guardia,
	# non un paracarro di metallo
	_cyl(n, 0.15, 0.185, 0.06, pietra, Vector3(-0.42, 0.03, 0))
	_cyl(n, 0.115, 0.14, 0.05, pietra, Vector3(-0.42, 0.085, 0))
	_cyl(n, 0.062, 0.078, 0.76, legno, Vector3(-0.42, 0.49, 0))
	_cyl(n, 0.07, 0.07, 0.03, legno_scuro, Vector3(-0.42, 0.885, 0))
	_ball(n, 0.032, ottone, Vector3(-0.42, 0.925, 0))
	# lo scudetto araldico sul fusto (non un quadratino blu qualsiasi: se
	# si legge «coso», non sta facendo il suo mestiere) — bordo d'ottone,
	# campo blu con la punta, borchietta al centro
	# (sta BASSO sul fusto: a sbarra alzata il contrappeso spazza proprio
	# l'altezza dove stava prima, e ci finiva dentro)
	_box(n, Vector3(0.088, 0.082, 0.014), ottone, Vector3(-0.42, 0.42, -0.066))
	var scud_bp := _box(n, Vector3(0.062, 0.062, 0.014), ottone, Vector3(-0.42, 0.383, -0.064))
	scud_bp.rotation.z = PI * 0.25
	_box(n, Vector3(0.07, 0.066, 0.016), _mat(BLU, BLU_CUPO, 5.0, 0.4),
			Vector3(-0.42, 0.42, -0.07))
	var scud_p := _box(n, Vector3(0.05, 0.05, 0.016), _mat(BLU, BLU_CUPO, 5.0, 0.4),
			Vector3(-0.42, 0.386, -0.068))
	scud_p.rotation.z = PI * 0.25
	_ball(n, 0.011, ottone, Vector3(-0.42, 0.413, -0.079), Vector3(1, 1, 0.5))

	# LA CERNIERA SU STAFFA, di lato al palo: il piano in cui l'asta gira
	# è STACCATO dal fusto — col perno sull'asse del palo, ad asta alzata
	# il contrappeso ruotava DENTRO il legno. La staffa la porta in fuori,
	# e il giro torna pulito in ogni posizione.
	_box(n, Vector3(0.06, 0.12, 0.06), legno_scuro, Vector3(-0.42, 0.835, -0.075))
	for gz: float in [-1.0, 1.0]:
		var guancia := _cyl(n, 0.075, 0.075, 0.02, ferro,
				Vector3(-0.42, 0.82, -0.115 + gz * 0.032))
		guancia.rotation.x = PI * 0.5
	var perno := _cyl(n, 0.02, 0.02, 0.12, ottone, Vector3(-0.42, 0.82, -0.115))
	perno.rotation.x = PI * 0.5
	for tz: float in [-1.0, 1.0]:
		var testina := _cyl(n, 0.03, 0.03, 0.014, ottone,
				Vector3(-0.42, 0.82, -0.115 + tz * 0.062))
		testina.rotation.x = PI * 0.5

	var asta := Node3D.new()
	asta.name = "Asta"
	asta.position = Vector3(-0.42, 0.82, -0.115)
	n.add_child(asta)
	# IL BRACCIO, tondo: il fusto bianco con gli anelli rossi calzati
	# sopra (non fasce dipinte su un box), il manicotto d'ottone al perno
	# e il cappuccio rosso in punta
	var braccio := Node3D.new()
	braccio.position = Vector3(0.7, 0, 0)
	asta.add_child(braccio)
	var fusto := _cyl(braccio, 0.03, 0.03, 1.34, bianco, Vector3.ZERO)
	fusto.rotation.z = PI * 0.5
	for i in 3:
		var anello := _cyl(braccio, 0.034, 0.034, 0.14, rosso,
				Vector3(-0.44 + float(i) * 0.44, 0, 0))
		anello.rotation.z = PI * 0.5
	var cappuccio := _cyl(braccio, 0.024, 0.034, 0.06, rosso, Vector3(0.67, 0, 0))
	cappuccio.rotation.z = -PI * 0.5
	_ball(braccio, 0.024, rosso, Vector3(0.7, 0, 0))
	var manicotto := _cyl(braccio, 0.037, 0.037, 0.07, ottone, Vector3(-0.66, 0, 0))
	manicotto.rotation.z = PI * 0.5
	# IL CONTRAPPESO, dalla parte corta: il codolo, il collare d'ottone
	# LIBERO dalla sfera (prima ci affogava dentro per metà) e la sfera
	# di ferro con l'anellino sotto per tirarla giù a mano
	var codolo := _cyl(asta, 0.024, 0.024, 0.14, ferro, Vector3(-0.13, 0, 0))
	codolo.rotation.z = PI * 0.5
	_cyl(asta, 0.034, 0.034, 0.028, ottone, Vector3(-0.132, 0, 0)).rotation.z = PI * 0.5
	_ball(asta, 0.075, ferro, Vector3(-0.23, 0, 0), Vector3(1, 0.9, 1))
	var anellino := TorusMesh.new()
	anellino.inner_radius = 0.014
	anellino.outer_radius = 0.026
	anellino.rings = 12
	anellino.ring_segments = 6
	var ami := MeshInstance3D.new()
	ami.mesh = anellino
	ami.material_override = ottone
	ami.position = Vector3(-0.23, -0.085, 0)
	asta.add_child(ami)

	# IL PALETTO D'APPOGGIO: alto quanto serve (l'asta ci si POSA), sulla
	# STESSA linea dell'asta (che ora gira sul piano della staffa), con la
	# sua basetta e la forcella a due corni che la culla
	_cyl(n, 0.1, 0.13, 0.05, pietra, Vector3(0.88, 0.025, -0.115))
	_cyl(n, 0.042, 0.055, 0.72, legno, Vector3(0.88, 0.41, -0.115))
	_cyl(n, 0.05, 0.05, 0.025, legno_scuro, Vector3(0.88, 0.782, -0.115))
	for fz: float in [-1.0, 1.0]:
		var corno := _cyl(n, 0.014, 0.018, 0.1, legno_scuro,
				Vector3(0.88, 0.835, -0.115 + fz * 0.045))
		corno.rotation.x = fz * -0.3
	return n


static func _bancone_piantone() -> Node3D:
	# IL BANCONE: il piano dove si consegna e si chiede. Non una cassa di
	# legno: un mobile VERO — zoccolo scuro, montanti, specchiature chiare
	# incassate su fronte e fianchi, il piano chiaro che sporge col bordo
	# tondo (ci si appoggiano i gomiti). Sopra, la vita del posto: il
	# registro rilegato con la penna e il segnalibro, il calamaio, il
	# timbro col suo tampone, tre lettere legate con lo spago, il campanello che si suona quando non c'è
	# nessuno — nodo "Campanello", così un domani può fare tin. Sul retro,
	# lato guardia, i due cassetti col pomello e il vano aperto.
	var n := Node3D.new()
	var legno := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	var scuro := _mat(WOOD_DARK, WOOD_DARK.darkened(0.15), 3.5, 0.45)
	var chiaro := _mat(WOOD_PALE, WOOD, 3.5, 0.5)
	var ottone := _mat(OTTONE, OTTONE_SCURO, 5.0, 0.4)
	var carta := _mat(CREAM, Color("f0e4cc"), 6.0, 0.25)

	# ---- lo zoccolo e il corpo
	_box(n, Vector3(0.98, 0.07, 0.46), scuro, Vector3(0, 0.035, 0.02))
	_box(n, Vector3(0.92, 0.64, 0.40), legno, Vector3(0, 0.39, 0.02))

	# ---- il FRONTE a specchiature: due pannelli chiari dentro la
	# cornice scura (montanti e traverse in rilievo: è l'ombra a
	# disegnare il mobile, non una striscia dipinta)
	for px: float in [-0.19, 0.19]:
		_box(n, Vector3(0.345, 0.44, 0.016), chiaro, Vector3(px, 0.40, -0.183))
	for mx: float in [-0.42, 0.0, 0.42]:
		_box(n, Vector3(0.05, 0.56, 0.024), scuro, Vector3(mx, 0.40, -0.185))
	_box(n, Vector3(0.89, 0.05, 0.024), scuro, Vector3(0, 0.655, -0.185))
	_box(n, Vector3(0.89, 0.05, 0.024), scuro, Vector3(0, 0.145, -0.185))

	# ---- i FIANCHI con la loro specchiatura (il catalogo fotografa
	# anche di profilo, e in gioco ci si gira attorno)
	for sx: float in [-1.0, 1.0]:
		_box(n, Vector3(0.016, 0.44, 0.27), chiaro, Vector3(sx * 0.463, 0.40, 0.02))
		for tz: float in [-0.165, 0.165]:
			_box(n, Vector3(0.024, 0.56, 0.05), scuro, Vector3(sx * 0.465, 0.40, 0.02 + tz))
		_box(n, Vector3(0.024, 0.05, 0.36), scuro, Vector3(sx * 0.465, 0.655, 0.02))
		_box(n, Vector3(0.024, 0.05, 0.36), scuro, Vector3(sx * 0.465, 0.145, 0.02))

	# ---- il PIANO: la fascia scura di raccordo, la lastra chiara che
	# sporge da tutti i lati, e il bordo tondo davanti — il naso su cui
	# si appoggiano i gomiti di chi chiede
	_box(n, Vector3(0.96, 0.05, 0.44), scuro, Vector3(0, 0.715, 0.02))
	_box(n, Vector3(1.06, 0.05, 0.56), chiaro, Vector3(0, 0.765, 0.02))
	var naso := _cyl(n, 0.026, 0.026, 1.06, chiaro, Vector3(0, 0.765, -0.262))
	naso.rotation.z = PI * 0.5

	# ---- il RETRO, lato guardia: due cassetti col pomello d'ottone e
	# il vano aperto con la coperta piegata
	for cy: float in [0.60, 0.44]:
		_box(n, Vector3(0.30, 0.13, 0.016), chiaro, Vector3(0.18, cy, 0.226))
		_ball(n, 0.016, ottone, Vector3(0.18, cy, 0.239))
	_box(n, Vector3(0.36, 0.34, 0.012), _mat(WOOD_DARK.darkened(0.35),
			WOOD_DARK.darkened(0.45), 3.0, 0.3), Vector3(-0.20, 0.35, 0.225))
	_box(n, Vector3(0.30, 0.055, 0.02), carta, Vector3(-0.20, 0.21, 0.228))

	# ---- IL REGISTRO rilegato, appena storto come lo lascia chi ci
	# scrive: copertina scura, pagine sventagliate, la penna col
	# pennino, il segnalibro che scende dalla copertina
	var libro := Node3D.new()
	libro.position = Vector3(0.02, 0.0, 0.02)
	libro.rotation.y = 0.09
	n.add_child(libro)
	_box(libro, Vector3(0.36, 0.014, 0.25), scuro, Vector3(0, 0.797, 0))
	for lato: float in [-1.0, 1.0]:
		var pag := _box(libro, Vector3(0.155, 0.010, 0.225), carta,
				Vector3(lato * 0.082, 0.806, 0))
		pag.rotation.z = lato * 0.05
		var pag2 := _box(libro, Vector3(0.150, 0.008, 0.218), carta,
				Vector3(lato * 0.078, 0.8135, 0))
		pag2.rotation.z = lato * 0.033
	_box(libro, Vector3(0.024, 0.018, 0.225), scuro, Vector3(0, 0.809, 0))
	var nastro := _mat(Color("b05c4a"), Color("8e4938"), 4.0, 0.35)
	_box(libro, Vector3(0.017, 0.005, 0.115), nastro, Vector3(-0.062, 0.8185, -0.045))
	var coda := _box(libro, Vector3(0.017, 0.005, 0.075), nastro,
			Vector3(-0.062, 0.789, -0.148))
	coda.rotation.x = -0.95
	var penna := _cyl(libro, 0.007, 0.0085, 0.15, _mat(WOOD_DARK, WOOD_DARK, 4.0, 0.35),
			Vector3(0.07, 0.822, -0.03))
	penna.rotation.x = PI * 0.5
	penna.rotation.z = 0.55
	_ball(libro, 0.0085, ottone, Vector3(0.107, 0.820, 0.028), Vector3(1, 1, 1.6))

	# ---- il calamaio col collo d'ottone, il timbro, e il suo tampone
	_cyl(n, 0.026, 0.030, 0.045, scuro, Vector3(0.27, 0.8125, 0.16))
	_cyl(n, 0.030, 0.030, 0.010, ottone, Vector3(0.27, 0.840, 0.16))
	_cyl(n, 0.045, 0.045, 0.05, _mat(WOOD_DARK, WOOD_DARK, 4.0, 0.4),
			Vector3(0.33, 0.815, -0.06))
	_cyl(n, 0.018, 0.026, 0.07, ottone, Vector3(0.33, 0.865, -0.06))
	_ball(n, 0.028, _mat(WOOD, WOOD_DARK, 4.0, 0.4), Vector3(0.33, 0.912, -0.06))
	_box(n, Vector3(0.095, 0.018, 0.075), scuro, Vector3(0.33, 0.799, -0.148))
	_box(n, Vector3(0.078, 0.010, 0.058), _mat(Color("46333a"), Color("2f2229"), 3.0, 0.2),
			Vector3(0.33, 0.808, -0.148))

	# ---- tre lettere legate con lo spago, in attesa di partire
	var buste := Node3D.new()
	buste.position = Vector3(-0.31, 0.0, 0.15)
	n.add_child(buste)
	for k in 3:
		var busta := _box(buste, Vector3(0.15, 0.007, 0.10), carta,
				Vector3(0, 0.7935 + float(k) * 0.007, 0))
		busta.rotation.y = [0.14, -0.09, 0.05][k]
	_box(buste, Vector3(0.014, 0.004, 0.104), _mat(Color("8a7a5c"), Color("6e6148"), 4.0, 0.3),
			Vector3(0, 0.816, 0))
	_ball(buste, 0.009, _mat(Color("8a7a5c"), Color("6e6148"), 4.0, 0.3),
			Vector3(0, 0.819, 0))

	# ---- il campanello da banco (nodo "Campanello": un domani farà tin)
	var campanello := Node3D.new()
	campanello.name = "Campanello"
	campanello.position = Vector3(-0.34, 0.79, -0.05)
	n.add_child(campanello)
	_cyl(campanello, 0.06, 0.062, 0.012, ottone, Vector3(0, 0, 0))
	_ball(campanello, 0.055, ottone, Vector3(0, 0.035, 0), Vector3(1, 0.72, 1))
	_ball(campanello, 0.014, ottone, Vector3(0, 0.075, 0))
	return n


static func _armadio_smarriti() -> Node3D:
	# L'ARMADIO DEGLI OGGETTI SMARRITI: il cuore del posto di guardia.
	# Un mobile da falegname vero: carcassa coi tondi, cimasa a due
	# gradini, zoccolo scuro, e dodici cassetti che sono GRUPPI (fronte
	# stondato, pomello tornito d'ottone, portacartellino con la sua
	# cartolina) — cosi' i socchiusi e quello storto portano con se'
	# tutto il loro corredo. Dietro le fughe c'e' il buio vero; i
	# socchiusi hanno la CASSA vera (sponde, fondo, schienalino), e da
	# uno fa capolino una pallina rossa che nessuno e' ancora venuto a
	# riprendersi.
	var n := Node3D.new()
	var legno := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	var fronte := _mat(WOOD_PALE, WOOD, 3.5, 0.45)
	var scuro := _mat(Color("3d332a"), Color("2e2620"), 4.0, 0.3)
	var ottone := _mat(OTTONE, OTTONE_SCURO, 5.0, 0.4)
	var crema := _mat(CREAM, Color("efe2ca"), 6.0, 0.2)

	# la carcassa stondata, il buio dietro le fughe, zoccolo e cimasa
	var corpo := _prisma(n, _rrect_xz(0.92, 0.44, 0.030), 0.10, 1.38, legno)
	corpo.position.z = 0.03
	_box(n, Vector3(0.86, 1.30, 0.012), scuro, Vector3(0, 0.80, -0.182))
	var zocc := _prisma(n, _rrect_xz(0.98, 0.50, 0.035), 0.0, 0.11, scuro)
	zocc.position.z = 0.03
	var cim1 := _prisma(n, _rrect_xz(1.00, 0.52, 0.040), 1.48, 0.05, legno)
	cim1.position.z = 0.03
	var cim2 := _prisma(n, _rrect_xz(0.94, 0.46, 0.030), 1.53, 0.032, fronte)
	cim2.position.z = 0.03
	# le SPECCHIATURE incassate sui fianchi: un mobile vero non ha i
	# lati a lastrone nudo
	for lato_f: float in [-0.465, 0.465]:
		_lastra(n, 0.155, 1.16, 0.035, 0.012, fronte,
				Vector3(lato_f, 0.79, 0.03))

	# dodici cassetti a GRUPPO: quattro file da tre
	for riga in 4:
		for col in 3:
			var y := 0.3025 + 0.3267 * float(riga)
			var x := -0.29 + 0.29 * float(col)
			# due socchiusi (la vita e' storta, gli armadi anche) e uno
			# appena sghembo, che nessuno raddrizza mai
			var fuori := 0.0
			if (riga == 2 and col == 0) or (riga == 0 and col == 2):
				fuori = 0.085
				# la CAVITA': il buio del cassetto aperto
				_box(n, Vector3(0.25, 0.28, 0.02), scuro,
						Vector3(x, y, -0.172))
			var cass := Node3D.new()
			cass.name = "Cassetto%d%d" % [riga, col]
			cass.position = Vector3(x, y, -0.19 - fuori)
			if riga == 1 and col == 2:
				cass.rotation.z = 0.022
			n.add_child(cass)
			if fuori > 0.0:
				# la CASSA del cassetto tirato fuori: sponde, fondo e
				# schienalino — un fronte che galleggia a mezz'aria non
				# e' un cassetto, e' un francobollo
				for sponda: float in [-0.122, 0.122]:
					_box(cass, Vector3(0.016, 0.170, 0.190), legno,
							Vector3(sponda, -0.017, 0.100))
				_box(cass, Vector3(0.256, 0.014, 0.190), legno,
						Vector3(0, -0.098, 0.100))
				_box(cass, Vector3(0.256, 0.150, 0.014), legno,
						Vector3(0, -0.02, 0.190))
			# il fronte stondato (lastra girata a guardare -Z)
			_lastra(cass, 0.136, 0.305, 0.028, 0.035, fronte,
					Vector3(0, 0, 0), Vector3(0, PI * 0.5, 0))
			# il pomello tornito: collarino e palla d'ottone
			var collo := _cyl(cass, 0.016, 0.020, 0.016, ottone,
					Vector3(0, -0.048, -0.026))
			collo.rotation.x = PI * 0.5
			_ball(cass, 0.023, ottone, Vector3(0, -0.048, -0.040))
			# il PORTACARTELLINO d'ottone con la sua cartolina
			_lastra(cass, 0.054, 0.062, 0.010, 0.006, ottone,
					Vector3(0, 0.075, -0.021), Vector3(0, PI * 0.5, 0))
			_lastra(cass, 0.045, 0.050, 0.008, 0.005, crema,
					Vector3(0, 0.075, -0.026), Vector3(0, PI * 0.5, 0))

	# la pallina rossa smarrita, mezza fuori dall'altro socchiuso
	_ball(n, 0.040, _mat(Color("c94f43"), Color("a83c33"), 5.0, 0.45),
			Vector3(-0.235, 1.085, -0.245))
	return n


## LA BACHECA DEGLI AVVISI, rifatta. Prima era una tavola su due gambe con
## cinque rettangoli identici appiccicati sopra: di profilo, un asse.
##
## Adesso è il cartellone della piazza, e a farlo sono tre cose:
##
##  1. IL TETTUCCIO. Una bacheca all'aperto SENZA tetto è una bacheca che
##     nessuno ha mai usato: la carta si bagna alla prima pioggia. Le due
##     falde sporgenti sono anche ciò che, di profilo, trasforma la tavola
##     in una costruzione — insieme ai due puntoni obliqui dietro, che
##     sono il motivo per cui il cartellone sta in piedi al vento.
##  2. IL SUGHERO GRANULOSO. Un pannello liscio è cartone. Le granaglie
##     sono trenta scaglie piatte di tono appena diverso, sparse: da
##     lontano fanno la grana, da vicino sono sughero.
##  3. I BIGLIETTI HANNO UNA STORIA. Non cinque rettangoli uguali: un
##     avviso ufficiale con le righe scritte, una foto col bordo bianco,
##     un biglietto tenuto su dal washi al posto della puntina, uno
##     appeso a UNA puntina sola che è ruotato di sghembo, uno con
##     l'ANGOLO ARRICCIATO (la firma della carta che sta lì da mesi), e
##     quello coi tagliandi da strappare — con due tagliandi già presi.
##     È il disordine a raccontare che il paese lo usa davvero.
##
## Più la matita legata allo spago, che è una CORDA VIVA: al vento
## dondola per conto suo.
static func _bacheca_avvisi() -> Node3D:
	var n := Node3D.new()
	var legno := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	var legno_chiaro := _mat(WOOD_PALE, WOOD, 3.5, 0.45)
	var legno_scuro := _mat(Color("8a6440"), Color("6d4f31"), 4.5, 0.45)
	var legno_medio := _mat(Color("d9b283"), Color("bd9463"), 4.0, 0.45)
	var sughero := _mat(SUGHERO, Color("c39a6c"), 7.0, 0.45)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20_260_805

	# --- i due pali: rastremati, appena storti, col cuneo al piede ---
	for sx: float in [-0.44, 0.44]:
		var palo := _cyl(n, 0.038, 0.050, 1.30, legno, Vector3(sx, 0.65, 0.045))
		palo.rotation.z = -sx * 0.012
		# il rincalzo al piede: BASSO e stretto al palo (prima era uno
		# spuntone lungo che partiva per aria di fianco), più il sasso
		var cuneo := _box(n, Vector3(0.05, 0.10, 0.05), legno_scuro,
				Vector3(sx * 1.03, 0.045, 0.045))
		cuneo.rotation.z = sx * 0.36
		_ball(n, 0.040, _mat(STONE, STONE_DARK, 3.0, 0.5),
				Vector3(sx * 0.97, 0.018, -0.02), Vector3(1.15, 0.5, 0.9))
	# NIENTE PUNTONI OBLIQUI: tolti per scelta dell'autore. La bacheca sta
	# su due pali piantati e basta — la struttura la spiegano il rincalzo
	# al piede e le mensoline sotto il tetto, e la sagoma resta pulita.

	# --- la cornice: quattro liste con la battuta interna, e i quattro
	# tasselli d'angolo che spiegano il giunto (una cornice senza giunto
	# è un rettangolo disegnato) ---
	var y0 := 0.62
	var y1 := 1.32
	var mezzo := (y0 + y1) * 0.5
	for dy: float in [y0, y1]:
		_box(n, Vector3(0.98, 0.075, 0.075), legno, Vector3(0, dy, 0.045))
	for sx3: float in [-0.4525, 0.4525]:
		_box(n, Vector3(0.075, y1 - y0, 0.075), legno, Vector3(sx3, mezzo, 0.045))
	for sx4: float in [-0.4525, 0.4525]:
		for dy2: float in [y0, y1]:
			_box(n, Vector3(0.09, 0.09, 0.05), legno_chiaro,
					Vector3(sx4, dy2, 0.012))
	# la battuta: il listello sottile che tiene il sughero, un filo avanti
	for dy3: float in [y0 + 0.043, y1 - 0.043]:
		_box(n, Vector3(0.86, 0.016, 0.03), legno_scuro, Vector3(0, dy3, 0.020))

	# --- il sughero, con la grana ---
	_box(n, Vector3(0.87, y1 - y0 - 0.075, 0.035), sughero, Vector3(0, mezzo, 0.048))
	for _i in 34:
		var gx := rng.randf_range(-0.41, 0.41)
		var gy := mezzo + rng.randf_range(-0.29, 0.29)
		var tono := SUGHERO.darkened(rng.randf_range(0.04, 0.16)) \
				if rng.randf() < 0.6 else SUGHERO.lightened(rng.randf_range(0.04, 0.10))
		var scaglia := _box(n, Vector3(rng.randf_range(0.016, 0.040), 0.012, 0.004),
				_mat(tono, tono.darkened(0.06), 7.0, 0.3), Vector3(gx, gy, 0.030))
		scaglia.rotation.z = rng.randf_range(0.0, PI)

	# --- la targhetta d'ottone sulla lista alta ---
	_box(n, Vector3(0.20, 0.045, 0.008), _mat(OTTONE, OTTONE_SCURO, 5.0, 0.35),
			Vector3(-0.02, y1 + 0.002, 0.004))
	for k in 3:
		_box(n, Vector3(0.035 - 0.006 * float(k), 0.006, 0.004),
				_mat(OTTONE_SCURO, OTTONE_SCURO.darkened(0.2), 5.0, 0.3),
				Vector3(-0.07 + 0.05 * float(k), y1 + 0.002, -0.001))

	# --- I BIGLIETTI ---
	var zc := 0.028      # il piano della carta, davanti al sughero
	# 1. l'avviso ufficiale, grande, con le righe scritte e due puntine
	var avviso := _carta_bacheca(n, Vector3(-0.235, mezzo + 0.115, zc), 0.30, 0.21,
			Color("fff6e2"), -0.035)
	for r in 4:
		_box(avviso, Vector3(0.20 - 0.03 * float(r), 0.008, 0.003),
				_mat(Color("b9ab92"), Color("9d9078"), 6.0, 0.25),
				Vector3(-0.03 + 0.012 * float(r), 0.045 - 0.035 * float(r), -0.006))
	_puntina(n, Vector3(-0.235 - 0.11, mezzo + 0.19, zc), SEGNALE_ROSSO)
	_puntina(n, Vector3(-0.235 + 0.12, mezzo + 0.20, zc), Color("6f9ad6"))
	# 2. la foto col bordo bianco, appesa storta a una puntina sola
	var foto := _carta_bacheca(n, Vector3(0.175, mezzo + 0.145, zc), 0.17, 0.15,
			Color("fbf8f2"), 0.16)
	_box(foto, Vector3(0.135, 0.10, 0.004),
			_mat(Color("9fc4d8"), Color("7ea6bd"), 6.0, 0.3), Vector3(0, 0.012, -0.005))
	_puntina(n, Vector3(0.175 - 0.055, mezzo + 0.205, zc), Color("e8c46a"))
	# 3. il biglietto col washi al posto della puntina
	var washi := _carta_bacheca(n, Vector3(0.30, mezzo - 0.055, zc), 0.17, 0.13,
			Color("e8f2e0"), -0.09)
	for lato: float in [-1.0, 1.0]:
		var nastro := _box(washi, Vector3(0.055, 0.022, 0.004),
				_mat(Color("f4b8c8"), Color("e39fb2"), 8.0, 0.3),
				Vector3(lato * 0.068, 0.062, -0.005))
		nastro.rotation.z = lato * 0.7
	# 4. il biglietto vecchio, con l'ANGOLO ARRICCIATO
	var vecchio := _carta_bacheca(n, Vector3(-0.30, mezzo - 0.14, zc), 0.19, 0.14,
			Color("f2e6cc"), 0.10)
	var ricciolo := _box(vecchio, Vector3(0.070, 0.055, 0.004),
			_mat(Color("e6d6b8"), Color("c8b696"), 6.0, 0.25),
			Vector3(0.062, -0.048, -0.012))
	ricciolo.rotation.x = -0.9
	ricciolo.rotation.z = -0.5
	_puntina(n, Vector3(-0.30, mezzo - 0.075, zc), Color("7fbc62"))
	# 5. il foglio coi TAGLIANDI da strappare, due già presi
	# i tagliandi sono TAGLI NEL FOGLIO, non linguette appese sotto: prima
	# spuntavano oltre il bordo e il biglietto sembrava un animaletto con
	# le zampe. Sono fessure scure fra una linguetta e l'altra, dentro la
	# metà bassa — e dove il tagliando manca la fessura è larga.
	var tagli := _carta_bacheca(n, Vector3(0.06, mezzo - 0.135, zc), 0.22, 0.155,
			Color("e4eef8"), 0.02)
	var fessura := _mat(Color("9fb0c4"), Color("8393a6"), 6.0, 0.25)
	for k2 in 7:
		var fx := -0.093 + 0.031 * float(k2)
		var largo_f := 0.026 if (k2 == 2 or k2 == 5) else 0.004
		_box(tagli, Vector3(largo_f, 0.075, 0.003), fessura,
				Vector3(fx, -0.038, -0.003))
	_puntina(n, Vector3(0.06, mezzo - 0.095, zc), SEGNALE_ROSSO)

	# --- il tettuccio. POSA sulla lista alta: sollevato restava un
	# cappello a mezz'aria. Le falde sono profonde (0.26) e sporgono
	# DAVANTI al pannello — un tetto che non ripara la carta non ripara
	# niente — e il colmo copre la giunzione delle due. ---
	# la pendenza è 0.62 rad (35°), non 0.46: un tetto poco inclinato letto
	# di fronte è un coperchio, e il tettuccio smette di dire «riparo»
	var y_colmo := y1 + 0.085
	for lato2: float in [-1.0, 1.0]:
		var incl := lato2 * 0.62
		# il centro della falda: metà pendenza a partire dal colmo
		var falda := _box(n, Vector3(1.08, 0.028, 0.26), legno_chiaro,
				Vector3(0, y_colmo - sin(0.62) * 0.13,
						0.045 + lato2 * cos(0.62) * 0.13))
		falda.rotation.x = incl
		# le tegoline: due listelli in rilievo per falda
		# le tegoline: tono su tono, NON scure — a contrasto sembravano
		# due maniglie appoggiate sul coperchio
		for k3 in 2:
			var u := -0.06 + 0.12 * float(k3)
			var t := _box(n, Vector3(1.04, 0.010, 0.050), legno_medio,
					Vector3(0, y_colmo - sin(0.62) * (0.13 + u) + cos(0.62) * 0.016,
							0.045 + lato2 * (cos(0.62) * (0.13 + u) + sin(0.62) * 0.016)))
			t.rotation.x = incl
	# il colmo, a cavallo delle due falde
	_box(n, Vector3(1.10, 0.040, 0.075), legno, Vector3(0, y_colmo + 0.012, 0.045))
	# le due mensoline che reggono lo sbalzo davanti
	for sx5: float in [-0.36, 0.36]:
		var mens := _box(n, Vector3(0.028, 0.135, 0.028), legno_scuro,
				Vector3(sx5, y1 + 0.010, -0.030))
		mens.rotation.x = -0.62

	# --- la matita allo spago: CORDA VIVA, dondola al vento ---
	var attacco := Vector3(0.400, y0 - 0.005, -0.012)
	var spago := _corda_viva(n, attacco, attacco + Vector3(0, -0.115, 0),
			0.0, 0.005, _mat(Color("d8c49a"), Color("b8a077"), 6.0, 0.3),
			1.3, 8, 5, true)
	spago.name = "Spago"
	var matita := Node3D.new()
	matita.name = "Matita"
	matita.position = attacco + Vector3(0, -0.115, 0)
	n.add_child(matita)
	_cyl(matita, 0.011, 0.011, 0.13, _mat(Color("e0a24a"), Color("c2842f"), 6.0, 0.3),
			Vector3(0, -0.065, 0))
	_cyl(matita, 0.0, 0.011, 0.028, _mat(Color("f0dcc0"), Color("d4bd9c"), 6.0, 0.3),
			Vector3(0, -0.144, 0))
	_cyl(matita, 0.0035, 0.0035, 0.012, _mat(Color("4a4640"), Color("38352f"), 6.0, 0.3),
			Vector3(0, -0.162, 0))
	var meta_s: Dictionary = spago.get_meta("corda")
	meta_s["appesi"] = [{"path": NodePath("../Matita"), "t": 1.0, "giu": 0.0}]
	spago.set_meta("corda", meta_s)
	return n


## Un biglietto della bacheca: la carta, la sua ombra portata sul sughero
## (è l'ombra a staccarla dal fondo) e il nodo che la contiene, già
## ruotato — così quello che ci si attacca dentro (righe, washi, riccioli)
## eredita la storta senza doverla ricalcolare.
static func _carta_bacheca(parent: Node3D, pos: Vector3, largo: float,
		alto: float, tinta: Color, giro: float) -> Node3D:
	var carta := Node3D.new()
	carta.position = pos
	carta.rotation.z = giro
	parent.add_child(carta)
	_box(carta, Vector3(largo, alto, 0.004),
			_mat(tinta, tinta.darkened(0.09), 6.0, 0.2), Vector3.ZERO)
	# l'ombra: appena più piccola, appena spostata in basso a destra
	_box(carta, Vector3(largo * 0.98, alto * 0.98, 0.002),
			_mat(Color("9c7f5e"), Color("7f6748"), 6.0, 0.25),
			Vector3(0.008, -0.008, 0.006))
	return carta


## Una puntina da disegno: lo spillo e la testa tonda che sporge.
static func _puntina(parent: Node3D, pos: Vector3, tinta: Color) -> void:
	var mat := _mat(tinta, tinta.darkened(0.18), 4.0, 0.3)
	_cyl(parent, 0.004, 0.004, 0.020, _mat(METAL, Color("6f665b"), 5.0, 0.3),
			pos + Vector3(0, 0, 0.004))
	_ball(parent, 0.013, mat, pos + Vector3(0, 0, -0.008), Vector3(1.0, 1.0, 0.7))


static func _attaccapanni_berretto() -> Node3D:
	# L'ATTACCAPANNI COL BERRETTO: il turno finisce, il berretto resta lì.
	# Un fusto TORNITO come lo farebbe un falegname — piede a campana,
	# pomo, collarini, capitello e cimasa in un profilo solo — quattro
	# bracci piegati a S coi pomelli chiari, quattro pioli bassi per le
	# cose piccole. E la vita di chi ci passa: il berretto d'ordinanza
	# appeso storto, una sciarpa che qualcuno riprenderà.
	var n := Node3D.new()
	var legno := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	var legno_scuro := _mat(WOOD_DARK, WOOD_DARK.darkened(0.22), 4.0, 0.45)
	var legno_chiaro := _mat(WOOD_PALE, WOOD, 4.5, 0.4)
	# ---- il fusto, tutto d'un pezzo di tornio
	BUILDER.lathe(n, [
		Vector2(0.0, 0.0), Vector2(0.155, 0.0), Vector2(0.155, 0.022),
		Vector2(0.125, 0.05),                      # il piede a campana
		Vector2(0.085, 0.078), Vector2(0.066, 0.112),
		Vector2(0.075, 0.135), Vector2(0.062, 0.158),   # tondino di base
		Vector2(0.048, 0.185),
		Vector2(0.056, 0.235), Vector2(0.063, 0.29),    # il pomo basso
		Vector2(0.05, 0.35), Vector2(0.036, 0.395),
		Vector2(0.033, 0.58),
		Vector2(0.04, 0.605), Vector2(0.04, 0.625), Vector2(0.031, 0.648),
		Vector2(0.03, 0.9),                        # il collarino a metà
		Vector2(0.028, 1.15),
		Vector2(0.037, 1.175), Vector2(0.037, 1.198), Vector2(0.028, 1.22),
		Vector2(0.026, 1.32),                      # il collo
		Vector2(0.048, 1.355), Vector2(0.056, 1.4),     # il capitello
		Vector2(0.042, 1.44), Vector2(0.038, 1.5),
		Vector2(0.048, 1.525), Vector2(0.022, 1.565),   # la cimasa
		Vector2(0.03, 1.592), Vector2(0.013, 1.63), Vector2(0.0, 1.652),
	], legno, Vector3.ZERO, 28)
	# ---- i quattro bracci a S, ognuno col suo pomello tornito
	for gradi: float in [90.0, 0.0, 180.0, 270.0]:
		var braccio := Node3D.new()
		braccio.rotation.y = deg_to_rad(gradi)
		n.add_child(braccio)
		BUILDER.tube(braccio, [
			Vector3(0.03, 1.40, 0), Vector3(0.11, 1.362, 0),
			Vector3(0.158, 1.40, 0), Vector3(0.175, 1.468, 0),
		], [0.017, 0.014, 0.012, 0.011], legno, 22, 10)
		_cyl(braccio, 0.017, 0.013, 0.014, legno_scuro, Vector3(0.175, 1.478, 0))
		_ball(braccio, 0.025, legno_chiaro, Vector3(0.175, 1.499, 0))
	# ---- i pioli bassi, inclinati appena in su
	for gradi: float in [45.0, 135.0, 225.0, 315.0]:
		var piolo := Node3D.new()
		piolo.rotation.y = deg_to_rad(gradi)
		n.add_child(piolo)
		var asta := _cyl(piolo, 0.011, 0.013, 0.09, legno, Vector3(0.066, 1.253, 0))
		asta.rotation.z = -1.24
		_ball(piolo, 0.017, legno_chiaro, Vector3(0.108, 1.268, 0))
	# ---- il berretto d'ordinanza, appeso storto sul braccio davanti
	var berretto := Node3D.new()
	berretto.name = "Berretto"
	berretto.position = Vector3(0.0, 1.447, -0.183)
	berretto.rotation.x = 0.24
	berretto.rotation.y = 0.18
	berretto.rotation.z = -0.09    # nessuno lo appende dritto
	n.add_child(berretto)
	var panno := _mat(BLU, BLU_CUPO, 5.0, 0.45)
	var panno_cupo := _mat(BLU_CUPO, Color("4c6699"), 4.0, 0.4)
	var cuoio := _mat(Color("38302a"), Color("2b241f"), 4.0, 0.35)
	var ottone := _mat(OTTONE, OTTONE_SCURO, 5.0, 0.35)
	# la corona bombata: fascia che rientra, poi il piatto che sboccia
	BUILDER.lathe(berretto, [
		Vector2(0.0, 0.0), Vector2(0.102, 0.0),
		Vector2(0.106, 0.012), Vector2(0.097, 0.045),
		Vector2(0.105, 0.072), Vector2(0.114, 0.096),
		Vector2(0.098, 0.116), Vector2(0.052, 0.131), Vector2(0.0, 0.136),
	], panno, Vector3.ZERO, 24)
	# la fascia scura, a filo ma più fuori (mai complanare)
	_cyl(berretto, 0.108, 0.108, 0.036, panno_cupo, Vector3(0, 0.018, 0))
	# il filetto d'ottone dove la fascia incontra la corona
	var filetto := MeshInstance3D.new()
	var fm := TorusMesh.new()
	fm.inner_radius = 0.101
	fm.outer_radius = 0.111
	filetto.mesh = fm
	filetto.material_override = ottone
	filetto.position = Vector3(0, 0.038, 0)
	berretto.add_child(filetto)
	# il soggolo di cuoio SOLO sul davanti (ad anello pieno diventava una
	# tesa nera che girava tutt'attorno), coi bottoncini ai suoi capi
	_lathe_spicchio(berretto, [Vector2(0.1065, 0.003), Vector2(0.1075, 0.011),
			Vector2(0.1065, 0.019)], cuoio, PI * 0.5 - 0.62, PI * 0.5 + 0.62, 8)
	_ball(berretto, 0.009, ottone, Vector3(0.062, 0.011, -0.0875))
	_ball(berretto, 0.009, ottone, Vector3(-0.062, 0.011, -0.0875))
	# la visiera: una calotta schiacciata color ardesia, curva in giù —
	# piccola, che spunti da sotto il soggolo invece di fare da piatto
	var ardesia := _mat(Color("3f4a5c"), Color("313a49"), 4.0, 0.35)
	var visiera := _ball(berretto, 0.088, ardesia, Vector3(0, -0.002, -0.066),
			Vector3(0.95, 0.13, 0.66))
	visiera.rotation.x = 0.32
	# il fregio: coccarda d'ottone con la borchia, fiera sul davanti
	var fregio := _cyl(berretto, 0.021, 0.021, 0.008, ottone, Vector3(0, 0.062, -0.104))
	fregio.rotation.x = PI * 0.5 - 0.12
	_ball(berretto, 0.008, ottone, Vector3(0, 0.062, -0.109))
	# ---- la sciarpa di lana, buttata sul braccio di destra. TERRACOTTA:
	# bianca sul pomello chiaro spariva (sembrava un osso), il caldo sul
	# blu del berretto è il contrasto giusto per un posto di guardia cozy
	var sciarpa := Node3D.new()
	sciarpa.name = "Sciarpa"
	n.add_child(sciarpa)
	var lana := _mat(TERRACOTTA, TERRACOTTA.darkened(0.18), 5.0, 0.45)
	var lana_riga := _mat(CREAM, Color("e8dcc4"), 5.0, 0.4)
	# il fagotto piegato che ABBRACCIA il pomello (non un fungo sopra)
	_ball(sciarpa, 0.043, lana, Vector3(0.175, 1.499, 0), Vector3(1.3, 0.55, 1.35))
	# la coda davanti: l'onda va in LARGHEZZA (x), che è quella che si
	# vede — in profondità la vede solo il profilo, e da lì sembrava un
	# serpente incollato al palo. Si allarga in punta, come cade la lana.
	var davanti := BUILDER.tube(sciarpa, [
		Vector3(0.173, 1.49, 0.032), Vector3(0.205, 1.4, 0.045),
		Vector3(0.163, 1.3, 0.052), Vector3(0.195, 1.21, 0.048),
		Vector3(0.19, 1.15, 0.045),
	], [0.028, 0.027, 0.026, 0.027, 0.031], lana, 26, 10)
	davanti.scale = Vector3(1.0, 1.0, 0.55)
	# la coda dietro, più corta: STESSA fase dell'onda ma più tenue —
	# in controfase le due code si intrecciavano come una treccia
	var dietro := BUILDER.tube(sciarpa, [
		Vector3(0.173, 1.49, -0.032), Vector3(0.192, 1.41, -0.046),
		Vector3(0.168, 1.32, -0.05), Vector3(0.178, 1.26, -0.046),
	], [0.028, 0.026, 0.025, 0.028], lana, 20, 10)
	dietro.scale = Vector3(1.0, 1.0, 0.55)
	# le righe crema e la frangia: la scala z del tubo schiaccia anche le
	# POSIZIONI dei suoi punti (0.045 -> ~0.025), quindi le decorazioni
	# stanno a quel z, non al z del punto di controllo — o galleggiano
	var riga := _cyl(sciarpa, 0.0285, 0.028, 0.014, lana_riga, Vector3(0.1925, 1.184, 0.026))
	riga.rotation.x = 0.06
	riga.rotation.z = 0.06
	riga.scale = Vector3(1.0, 1.0, 0.56)
	var riga2 := _cyl(sciarpa, 0.028, 0.0275, 0.009, lana_riga, Vector3(0.194, 1.214, 0.0265))
	riga2.rotation.x = 0.06
	riga2.rotation.z = 0.06
	riga2.scale = Vector3(1.0, 1.0, 0.56)
	for fi in 4:
		var fx := -0.017 + 0.0113 * float(fi)
		var filo := _cyl(sciarpa, 0.0032, 0.0024, 0.032, lana,
				Vector3(0.19 + fx, 1.121, 0.0245))
		filo.rotation.z = 0.12 - 0.08 * float(fi)
	return n


static func _brandina_turno() -> Node3D:
	# LA BRANDINA DEL TURNO DI NOTTE: una branda da campo VERA. Le X ai
	# piedi e in testa (prima correvano lungo il fianco e sembrava un
	# tavolo da picnic), i pali tondi che sporgono coi pomelli, i perni
	# d'ottone allo snodo, la crociera in mezzo. Il telo CEDE al centro
	# come un telo, la coperta ha la piega e un lembo che scende oltre il
	# palo, il cuscino è ammaccato da chi ci ha dormito.
	var n := Node3D.new()
	var legno := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	var legno_scuro := _mat(WOOD_DARK, WOOD_DARK.darkened(0.22), 4.0, 0.45)
	var ottone := _mat(OTTONE, OTTONE_SCURO, 5.0, 0.35)
	var telo := _mat(Color("cfd8c8"), Color("b8c2b0"), 5.0, 0.45)
	var panno := _mat(BLU, BLU_CUPO, 5.0, 0.5)
	var panno_cupo := _mat(BLU_CUPO, Color("4c6699"), 5.0, 0.4)
	var lana_riga := _mat(CREAM, Color("e8dcc4"), 5.0, 0.4)
	# ---- i due pali lunghi, tondi, che sporgono coi pomelli
	for pz: float in [-0.3, 0.3]:
		var palo := _cyl(n, 0.026, 0.026, 0.98, legno, Vector3(0, 0.4, pz))
		palo.rotation.z = PI * 0.5
		_ball(n, 0.03, legno_scuro, Vector3(-0.49, 0.4, pz))
		_ball(n, 0.03, legno_scuro, Vector3(0.49, 0.4, pz))
	# ---- le X ai due capi (nel piano CORTO), coi piedini e il perno
	for px: float in [-0.32, 0.32]:
		for verso: float in [-1.0, 1.0]:
			var gamba := _cyl(n, 0.02, 0.022, 0.75, legno,
					Vector3(px, 0.2, -verso * 0.0225))
			gamba.rotation.x = verso * 1.05
			_cyl(n, 0.026, 0.028, 0.022, legno_scuro,
					Vector3(px, 0.011, -verso * 0.345))
		# il perno d'ottone dove le gambe si incrociano
		var perno := _cyl(n, 0.011, 0.011, 0.075, ottone, Vector3(px, 0.2, 0))
		perno.rotation.z = PI * 0.5
		_ball(n, 0.016, ottone, Vector3(px - 0.038, 0.2, 0))
		_ball(n, 0.016, ottone, Vector3(px + 0.038, 0.2, 0))
	# la crociera che tiene le due X: la reggono gli stessi perni
	var crociera := _cyl(n, 0.015, 0.015, 0.64, legno, Vector3(0, 0.2, 0))
	crociera.rotation.z = PI * 0.5
	# ---- il telo: cede al centro, come sotto un peso che non c'è più
	# (mezzo-lato 0.315: il bordo muore DENTRO l'orlo arrotolato, non oltre)
	_loft(n, [[-0.46, 0.315, 0.413, 0.45, 0.014],
			[-0.28, 0.315, 0.401, 0.439, 0.014],
			[0.0, 0.315, 0.392, 0.431, 0.014],
			[0.28, 0.315, 0.401, 0.439, 0.014],
			[0.46, 0.315, 0.413, 0.45, 0.014]], telo)
	# gli orli arrotolati che avvolgono i pali
	for pz: float in [-0.322, 0.322]:
		var orlo := _cyl(n, 0.017, 0.017, 0.9, telo, Vector3(0, 0.428, pz))
		orlo.rotation.z = PI * 0.5
	# ---- il cuscino, a due gobbe: nessuno lo sprimaccia dopo il turno
	var cuscino := _ball(n, 0.135, _mat(CREAM, Color("f0e4cc"), 5.0, 0.35),
			Vector3(-0.29, 0.485, -0.015), Vector3(1.05, 0.5, 1.3))
	cuscino.name = "Cuscino"
	cuscino.rotation.y = 0.1
	_ball(n, 0.1, _mat(CREAM, Color("f0e4cc"), 5.0, 0.35),
			Vector3(-0.235, 0.478, 0.055), Vector3(0.92, 0.44, 1.05))
	# ---- la coperta piegata in fondo, col bordo tondo della piega
	var piega := _cyl(n, 0.037, 0.037, 0.54, panno, Vector3(0.135, 0.478, 0))
	piega.rotation.x = PI * 0.5
	_box(n, Vector3(0.29, 0.074, 0.54), panno, Vector3(0.28, 0.478, 0))
	var piega_fondo := _cyl(n, 0.037, 0.037, 0.54, panno, Vector3(0.425, 0.478, 0))
	piega_fondo.rotation.x = PI * 0.5
	# il secondo strato, appena storto come lo lascia una mano
	var strato := Node3D.new()
	strato.position = Vector3(0.28, 0.532, 0.012)
	strato.rotation.y = 0.055
	n.add_child(strato)
	var s_piega := _cyl(strato, 0.016, 0.016, 0.47, panno_cupo, Vector3(-0.125, 0, 0))
	s_piega.rotation.x = PI * 0.5
	_box(strato, Vector3(0.25, 0.032, 0.47), panno_cupo, Vector3(0, 0, 0))
	var s_fondo := _cyl(strato, 0.016, 0.016, 0.47, panno_cupo, Vector3(0.125, 0, 0))
	s_fondo.rotation.x = PI * 0.5
	# le righe crema tessute vicino alla piega, come sulle coperte di lana
	_box(strato, Vector3(0.02, 0.005, 0.472), lana_riga, Vector3(-0.07, 0.017, 0))
	_box(strato, Vector3(0.011, 0.005, 0.472), lana_riga, Vector3(-0.035, 0.017, 0))
	# ---- il lembo che scende oltre il palo: prima il dorso tondo che
	# scavalca l'orlo (senza, coperta e lembo restavano staccati a mezz'aria)
	var dorso := _cyl(n, 0.028, 0.028, 0.28, panno, Vector3(0.28, 0.462, 0.302))
	dorso.rotation.z = PI * 0.5
	var lembo := Node3D.new()
	lembo.position = Vector3(0.28, 0.43, 0.328)
	lembo.rotation.x = 0.14
	n.add_child(lembo)
	_box(lembo, Vector3(0.28, 0.17, 0.026), panno, Vector3(0, -0.045, 0))
	var orlo_lembo := _cyl(lembo, 0.015, 0.015, 0.28, panno_cupo, Vector3(0, -0.13, 0))
	orlo_lembo.rotation.z = PI * 0.5
	_box(lembo, Vector3(0.28, 0.018, 0.005), lana_riga, Vector3(0, -0.098, 0.0145))
	return n


# ============================================================================
# LA LANTERNA BLU — il faro del posto di guardia
# ============================================================================
# Il pezzo che di notte dice «c'è qualcuno sveglio per te», e che per anni
# e' stato un lumino da bicicletta in cima a un tubo. Rifatto da zero
# scegliendo fra quattro strade disegnate e RENDERIZZATE tutte e quattro,
# di giorno e di notte (tools/provino_variante.gd con CHIBI_NOTTE=1):
# la gabbia coi vetri a pannelli ha vinto la costruzione, il fanale da
# molo la tavolozza (blu laccato e ottone: e' la lanterna BLU, il corpo
# non poteva restare marrone), la cipolla fiabesca il terreno vissuto
# attorno alla base e le campanule sul rampicante.
#
# LA GEOMETRIA E' UNA SOLA, e ne discende tutto: un esagono con gli
# spigoli a A0 + k*60 e le facce in mezzo, cosi' una faccia di vetro
# guarda esattamente -Z (il fronte del catalogo) e tetto, gabbia,
# pavimento e gradini di pietra condividono lo stesso poligono senza una
# rotazione scritta a mano.
const LB_LATI := 6
const LB_A0 := -PI / 3.0
const LB_R := 0.196           # raggio agli spigoli della gabbia
const LB_APOTEMA := 0.170     # il piano su cui stanno i vetri
const LB_SEMI := 0.092        # semi-larghezza di un pannello
const LB_BANDE := [[-0.062, 0.048], [0.070, 0.262]]
const LB_Y_LUME := 1.60


static func _lb_anello(n: Node3D, mat: Material, y: float, dentro: float,
		fuori: float, schiaccia := 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = dentro
	tm.outer_radius = fuori
	tm.rings = 20
	mi.mesh = tm
	mi.material_override = mat
	mi.position = Vector3(0, y, 0)
	mi.scale = Vector3(1, schiaccia, 1)
	n.add_child(mi)
	return mi


## I VETRI: dodici lastre PIANE, due per faccia, generate come un'unica
## mesh a griglia. Non sono lisce — il vetro soffiato ha l'onda dentro, e
## sono le onde a far scivolare il riflesso in modo diverso su ogni
## pannello e a increspare la fiamma che ci sta dietro.
static func _lb_pannello(st: SurfaceTool, a: float, y0: float, y1: float) -> void:
	var u := Vector3(cos(a), 0.0, sin(a))
	var t := Vector3(-sin(a), 0.0, cos(a))
	var nu := 6
	var nv := 5
	var vg: Array = []
	for j in nv + 1:
		var riga := PackedVector3Array()
		for i in nu + 1:
			var s := lerpf(-LB_SEMI, LB_SEMI, float(i) / float(nu))
			var yy := lerpf(y0, y1, float(j) / float(nv))
			var onda := sin(s * 30.0 + a * 3.1) * 0.0036 \
					+ sin(yy * 15.0 + a * 5.7) * 0.0028
			riga.append(u * (LB_APOTEMA + onda) + t * s + Vector3(0.0, yy, 0.0))
		vg.append(riga)
	var ng: Array = []
	for j in nv + 1:
		var riga_n := PackedVector3Array()
		var qui := vg[j] as PackedVector3Array
		var su := vg[mini(j + 1, nv)] as PackedVector3Array
		var giu := vg[maxi(j - 1, 0)] as PackedVector3Array
		for i in nu + 1:
			var tx := qui[mini(i + 1, nu)] - qui[maxi(i - 1, 0)]
			var ty := su[i] - giu[i]
			riga_n.append(ty.cross(tx).normalized())
		ng.append(riga_n)
	for j in nv:
		var r0 := vg[j] as PackedVector3Array
		var r1 := vg[j + 1] as PackedVector3Array
		var n0 := ng[j] as PackedVector3Array
		var n1 := ng[j + 1] as PackedVector3Array
		for i in nu:
			var q := [r0[i], r0[i + 1], r1[i + 1], r1[i]]
			var qn := [n0[i], n0[i + 1], n1[i + 1], n1[i]]
			for e in [0, 1, 2, 0, 2, 3]:
				st.set_normal(qn[e])
				st.add_vertex(q[e])


## Un ciuffo d'erba: tre lame di lunghezza diversa, non una pallina verde.
static func _lb_ciuffo(n: Node3D, pos: Vector3, sz: float, giro: float,
		erba: Material) -> void:
	var c := Node3D.new()
	c.position = pos
	c.rotation.y = giro
	n.add_child(c)
	for l in [[0.0, 1.0, 0.0], [0.55, 0.78, 0.5], [-0.5, 0.66, -0.42]]:
		var lama := _cyl(c, 0.002, 0.011 * sz, 0.13 * sz * float(l[1]), erba,
				Vector3(float(l[0]) * 0.03 * sz, 0.065 * sz * float(l[1]),
						float(l[2]) * 0.03 * sz))
		lama.rotation = Vector3(float(l[2]) * 0.45, 0.0, -float(l[0]) * 0.5)


## Una campanula appesa al tralcio: il gambo che si piega e la corolla
## rivolta all'INGIU' — una campanula col muso all'insu' e' un tulipano.
static func _lb_campanula(n: Node3D, pos: Vector3, giro: float, sz: float,
		verde: Material, fiore: Material) -> void:
	var c := Node3D.new()
	c.position = pos
	c.rotation.y = giro
	n.add_child(c)
	BUILDER.tube(c, [Vector3(0, 0, 0), Vector3(0.010, 0.014, 0.018),
			Vector3(0.024, 0.012, 0.038), Vector3(0.030, -0.005, 0.049)],
			[0.004, 0.0034, 0.003, 0.0026], verde, 10, 5)
	var testa := Node3D.new()
	testa.position = Vector3(0.030, -0.009, 0.049)
	c.add_child(testa)
	BUILDER.lathe(testa, [Vector2(0.019, -0.008), Vector2(0.029, 0.002),
			Vector2(0.026, 0.014), Vector2(0.023, 0.030), Vector2(0.016, 0.048),
			Vector2(0.008, 0.058), Vector2(0.005, 0.064)], fiore,
			Vector3(0, -0.064 * sz, 0), 14, sz, sz)


static func _lanterna_blu() -> Node3D:
	var n := Node3D.new()
	var pietra := _mat(Color("bdb3a1"), STONE_DARK, 4.0, 0.5)
	var pietra_cupa := _mat(STONE_DARK, Color("877e72"), 4.5, 0.45)
	# IL CORPO E' BLU LACCATO, non ghisa marrone: il pezzo si chiama
	# «Lanterna blu», e un lampione che dice blu solo nel vetro non lo dice
	var lacca := _mat(Color("35485f"), Color("223040"), 5.0, 0.42)
	var lacca_cupa := _mat(Color("243344"), Color("18232f"), 5.0, 0.4)
	var ottone := _mat(OTTONE, OTTONE_SCURO, 5.0, 0.42)
	var ottone_cupo := _mat(OTTONE_SCURO, Color("8a6420"), 5.0, 0.4)

	# --- il basamento: tre gradini esagonali con gli spigoli smussati (una
	# pietra posata da cent'anni non ha spigoli vivi) e le facce allineate
	# a quelle della gabbia lassu'. Il piede e' LARGO: una testa generosa
	# senza base che la regga sembra in equilibrio, non piantata li'.
	BUILDER.lathe(n, [Vector2(0.284, 0.0), Vector2(0.294, 0.012),
			Vector2(0.294, 0.052), Vector2(0.282, 0.066)],
			pietra, Vector3.ZERO, LB_LATI)
	BUILDER.lathe(n, [Vector2(0.229, 0.060), Vector2(0.239, 0.073),
			Vector2(0.239, 0.114), Vector2(0.225, 0.128)],
			pietra_cupa, Vector3.ZERO, LB_LATI)
	BUILDER.lathe(n, [Vector2(0.175, 0.122), Vector2(0.185, 0.135),
			Vector2(0.185, 0.172), Vector2(0.163, 0.190)],
			pietra, Vector3.ZERO, LB_LATI)
	BUILDER.lathe(n, [Vector2(0.148, 0.182), Vector2(0.156, 0.198),
			Vector2(0.147, 0.218), Vector2(0.118, 0.238),
			Vector2(0.094, 0.252), Vector2(0.082, 0.264)],
			lacca, Vector3.ZERO, 24)

	# il terreno attorno: sassi e ciuffi d'erba. Un lampione che esce dal
	# prato pulito e' un asset; uno con l'erba che gli cresce contro e' un
	# posto. I sassi vanno di taglia diversa, o sono uova.
	var erba := _mat(LEAF, LEAF_DARK, 6.0, 0.55)
	var sasso := _mat(Color("a9a294"), Color("8d867a"), 5.0, 0.45)
	for k in 5:
		var a_s := TAU / 5.0 * float(k) + 0.7
		var d := 0.33 + 0.035 * float(k % 3)
		var s := _ball(n, 0.036 + 0.012 * float(k % 3), sasso,
				Vector3(cos(a_s) * d, 0.012, sin(a_s) * d),
				Vector3(1.3, 0.62, 1.0))
		s.rotation.y = a_s * 1.7
	for k in 7:
		var a_e := TAU / 7.0 * float(k) + 0.25
		var d2 := 0.30 + 0.05 * float(k % 3)
		_lb_ciuffo(n, Vector3(cos(a_e) * d2, 0.0, sin(a_e) * d2),
				0.85 + 0.3 * float(k % 2), a_e * 2.3, erba)

	# --- la colonna: UNA SOLA superficie tornita — toro del piede, gola,
	# fusto con l'ENTASI (si gonfia appena nel terzo basso: e' quello a
	# togliergli l'aria di tubo), collarino e astragalo in cima
	BUILDER.lathe(n, [
			Vector2(0.076, 0.258), Vector2(0.083, 0.275), Vector2(0.081, 0.291),
			Vector2(0.063, 0.310), Vector2(0.0565, 0.335), Vector2(0.0585, 0.450),
			Vector2(0.0578, 0.620), Vector2(0.0545, 0.800), Vector2(0.0502, 0.960),
			Vector2(0.0462, 1.100), Vector2(0.0438, 1.180), Vector2(0.0458, 1.196),
			Vector2(0.0432, 1.214)],
			lacca, Vector3.ZERO, 24)

	# --- la targhetta smaltata fra due collari d'ottone: fondo blu, la
	# LUNA e due stelline in panna. E' il mestiere della lanterna scritto
	# sul palo, e l'unica cosa che tiene lo sguardo a meta' altezza, dove
	# prima c'era un metro di tubo liscio.
	var smalto := _mat(Color("2b4a86"), Color("1c3363"), 3.0, 0.35)
	var panna := _mat(CREAM, Color("efdfbe"), 4.0, 0.3)
	var yt := 0.775
	_lb_anello(n, ottone, yt - 0.086, 0.052, 0.073)
	_lb_anello(n, ottone, yt + 0.086, 0.051, 0.071)
	for lato: float in [-1.0, 1.0]:
		var st_g := _cyl(n, 0.008, 0.008, 0.038, ottone_cupo,
				Vector3(lato * 0.030, yt, -0.041))
		st_g.rotation.x = PI * 0.5
	_lastra(n, 0.080, 0.136, 0.040, 0.010, ottone,
			Vector3(0, yt, -0.060), Vector3(0, PI * 0.5, 0))
	_lastra(n, 0.070, 0.122, 0.034, 0.008, smalto,
			Vector3(0, yt, -0.068), Vector3(0, PI * 0.5, 0))
	# la luna: un disco panna morso da un disco di smalto
	_lastra(n, 0.031, 0.062, 0.030, 0.005, panna,
			Vector3(0.007, yt + 0.008, -0.0735), Vector3(0, PI * 0.5, 0))
	_lastra(n, 0.026, 0.052, 0.025, 0.006, smalto,
			Vector3(0.027, yt + 0.017, -0.0755), Vector3(0, PI * 0.5, 0))
	# due stelline di taglia diversa: due uguali sarebbero un timbro
	_lastra(n, 0.009, 0.018, 0.0085, 0.005, panna,
			Vector3(-0.031, yt + 0.040, -0.0735), Vector3(0, PI * 0.5, 0))
	_lastra(n, 0.006, 0.012, 0.0055, 0.005, panna,
			Vector3(-0.039, yt - 0.020, -0.0735), Vector3(0, PI * 0.5, 0))
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			_ball(n, 0.0065, ottone,
					Vector3(sx * 0.060, yt + sy * 0.050, -0.070),
					Vector3(1.0, 1.0, 0.7))

	# --- l'edera che sale il primo terzo del palo, con le campanule
	# azzurre. Non e' decorazione gratuita: dice da quanto tempo questa
	# lanterna sta li', e rompe la verticale con una diagonale viva.
	var foglia := _mat(LEAF, LEAF_DARK, 6.0, 0.5)
	var foglia_cupa := _mat(LEAF_DARK, Color("47773a"), 6.0, 0.5)
	var stelo := _mat(Color("6f7a4e"), Color("55603a"), 5.0, 0.45)
	var fiore := _mat(Color("9fc0f0"), Color("7fa4e0"), 5.0, 0.35)
	# il ramo vive su UNA funzione sola: le foglie si attaccano dove passa
	# davvero, non a una copia delle sue formule scritta poco piu' sotto
	var sul_ramo := func(t: float) -> Vector3:
		var y := lerpf(0.238, 0.700, t)
		var ang := -1.35 + t * 8.4
		var rr: float = lerpf(0.070, 0.058, t) + 0.008 + sin(t * 6.0) * 0.004
		return Vector3(cos(ang) * rr, y, sin(ang) * rr)
	var pts: Array = []
	var raggi: Array = []
	for i in 15:
		var t := float(i) / 14.0
		pts.append(sul_ramo.call(t))
		raggi.append(lerpf(0.0074, 0.0034, t))
	BUILDER.tube(n, pts, raggi, stelo, 46, 6)
	# LE FOGLIE sono LAMINE, non palline schiacciate: una sfera appiattita
	# esce a fagiolo da ogni angolazione. E la faccia sta inclinata
	# all'insu': perfettamente aderente al palo si vedrebbe di taglio da
	# mezzo giro di camera, e l'edera diventerebbe una fila di trattini.
	for i in 14:
		var t := 0.05 + float(i) / 13.0 * 0.90
		var attacco: Vector3 = sul_ramo.call(t)
		var verso := 1.0 if i % 2 == 0 else -1.0
		var nrm := Vector3(attacco.x, 0.0, attacco.z).normalized()
		var tang := Vector3(-nrm.z, 0.0, nrm.x)
		var su := (Vector3.UP * 0.72 + tang * (0.62 * verso)
				+ nrm * 0.16).normalized()
		var faccia := (nrm * 0.78 + Vector3.UP * 0.55).normalized()
		var taglia := lerpf(1.7, 1.05, t) * (1.12 if i % 3 == 0 else 0.88)
		var pos := attacco + su * (0.030 * taglia) + nrm * 0.006
		var f := _lastra(n, 0.019 * taglia, 0.042 * taglia,
				0.016 * taglia, 0.0045,
				foglia if i % 2 == 0 else foglia_cupa, pos)
		var zz := faccia.cross(su).normalized()
		f.transform = Transform3D(
				Basis(faccia, zz.cross(faccia).normalized(), zz), pos)
		BUILDER.tube(n, [attacco, attacco + su * (0.012 * taglia), pos],
				[0.0026, 0.0022, 0.0016], stelo, 8, 5)
	for k in 3:
		var t_c := 0.3 + 0.26 * float(k)
		var att: Vector3 = sul_ramo.call(t_c)
		_lb_campanula(n, att, atan2(att.z, att.x) + 1.1 + float(k), 0.95,
				stelo, fiore)

	# --- il capitello: QUI IL PEZZO CAMBIA METALLO. Sotto e' lacca sul
	# ferro, da qui in su e' ottone — il ferro regge, l'ottone fa luce.
	BUILDER.lathe(n, [Vector2(0.0435, 1.210), Vector2(0.0505, 1.230),
			Vector2(0.0475, 1.248), Vector2(0.0585, 1.272),
			Vector2(0.0760, 1.298), Vector2(0.0880, 1.322),
			Vector2(0.0925, 1.338), Vector2(0.0840, 1.348),
			Vector2(0.0700, 1.344), Vector2(0.0620, 1.336)],
			ottone, Vector3.ZERO, 24)
	_lb_anello(n, ottone_cupo, 1.222, 0.045, 0.062)
	# le quattro mensole di ferro battuto: UNA SOLA BARRA CONTINUA che
	# nasce sotto la coppa, scende in fuori e FINISCE IN UN RICCIOLO che
	# si chiude stringendo — il raggio della spirale CALA giro dopo giro.
	# A raggio costante il ferro esce un anello, e due anelli ai lati del
	# palo sembrano un paio d'occhiali appesi al lampione (visto, e tolto).
	for k in 4:
		var a := float(k) * PI * 0.5
		var u := Vector3(cos(a), 0.0, sin(a))
		var barra: Array = [
			u * 0.044 + Vector3(0, 1.332, 0),
			u * 0.096 + Vector3(0, 1.306, 0),
			u * 0.134 + Vector3(0, 1.264, 0),
			u * 0.146 + Vector3(0, 1.224, 0)]
		var rag_b: Array = [0.0110, 0.0102, 0.0094, 0.0086]
		var centro := u * 0.118 + Vector3(0, 1.192, 0)
		for s in 10:
			var f2 := float(s) / 9.0
			var ang := f2 * TAU * 1.35
			var rr2 := lerpf(0.034, 0.005, f2 * f2 * 0.6 + f2 * 0.4)
			barra.append(centro + u * (cos(ang) * rr2)
					+ Vector3(0, sin(ang) * rr2, 0))
			rag_b.append(lerpf(0.0082, 0.0030, f2))
		BUILDER.tube(n, barra, rag_b, lacca_cupa, 42, 7)

	# ======================== IL FANALE ========================
	var lume := Node3D.new()
	lume.name = "Lume"
	lume.position = Vector3(0, LB_Y_LUME, 0)
	n.add_child(lume)

	# LA COPPA: una sola tornitura dal collo alla bocca — il bulbo a
	# goccia che nasconde l'innesto, la strozzatura, l'ogiva che si apre
	# e il labbro che rientra. Da sola vale meta' del carattere del pezzo.
	BUILDER.lathe(lume, [
			Vector2(0.058, -0.306), Vector2(0.062, -0.296),
			Vector2(0.078, -0.282), Vector2(0.082, -0.264),
			Vector2(0.070, -0.246), Vector2(0.060, -0.232),
			Vector2(0.086, -0.208), Vector2(0.122, -0.182),
			Vector2(0.160, -0.154), Vector2(0.190, -0.128),
			Vector2(0.208, -0.110), Vector2(0.213, -0.098),
			Vector2(0.200, -0.090)],
			ottone, Vector3.ZERO, 26)
	# il pavimento esagonale: sotto lo tappa il tornio, sopra si richiude
	# a cupolina (o si vedrebbe il buco attraverso i vetri bassi)
	BUILDER.lathe(lume, [Vector2(0.204, -0.100), Vector2(0.219, -0.090),
			Vector2(0.219, -0.068), Vector2(0.204, -0.060),
			Vector2(0.120, -0.054), Vector2(0.0, -0.050)],
			ottone, Vector3.ZERO, LB_LATI)

	# i sei montanti agli spigoli, con la nocca all'altezza del traversino
	# e la fascetta in alto: un montante liscio e' un fil di ferro, un
	# montante con due nodi e' ottone battuto
	for k in LB_LATI:
		var a2 := LB_A0 + float(k) * TAU / float(LB_LATI)
		var pm := Vector3(cos(a2) * LB_R, 0.0, sin(a2) * LB_R)
		_cyl(lume, 0.0130, 0.0142, 0.358, ottone, pm + Vector3(0, 0.093, 0))
		_ball(lume, 0.0190, ottone_cupo, pm + Vector3(0, 0.059, 0),
				Vector3(1.0, 0.72, 1.0))
		_ball(lume, 0.0170, ottone_cupo, pm + Vector3(0, 0.242, 0),
				Vector3(1.0, 0.60, 1.0))
		_ball(lume, 0.0182, ottone_cupo, pm + Vector3(0, -0.052, 0),
				Vector3(1.0, 0.68, 1.0))
	# IL TRAVERSINO per faccia: e' lui a spezzare la vetrata in due lastre.
	# Senza, l'esagono di vetro e' un lampione da strada, non una lanterna.
	for k in LB_LATI:
		var a3 := LB_A0 + (float(k) + 0.5) * TAU / float(LB_LATI)
		_lastra(lume, 0.096, 0.028, 0.012, 0.022, ottone,
				Vector3(cos(a3) * LB_APOTEMA, 0.059, sin(a3) * LB_APOTEMA),
				Vector3(0, -a3, 0))
	BUILDER.lathe(lume, [Vector2(0.200, 0.258), Vector2(0.219, 0.270),
			Vector2(0.219, 0.292), Vector2(0.204, 0.300),
			Vector2(0.120, 0.306), Vector2(0.0, 0.310)],
			ottone, Vector3.ZERO, LB_LATI)
	_lb_anello(lume, ottone_cupo, -0.080, 0.192, 0.214, 0.5)

	# i vetri: dodici lastre in UNA mesh sola, col nome che il gioco cerca
	var vmat := _vetro(0.54)
	vmat.albedo_color = Color(0.15, 0.33, 0.78, 0.58)
	vmat.emission = Color("5f95ee")
	vmat.emission_energy_multiplier = 0.34
	vmat.roughness = 0.09
	vmat.metallic = 0.15
	vmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var st_v := SurfaceTool.new()
	st_v.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in LB_LATI:
		var a4 := LB_A0 + (float(k) + 0.5) * TAU / float(LB_LATI)
		for b in LB_BANDE:
			_lb_pannello(st_v, a4, float(b[0]), float(b[1]))
	var vetro_mi := MeshInstance3D.new()
	vetro_mi.mesh = st_v.commit()
	vetro_mi.material_override = vmat
	vetro_mi.name = "Vetro"
	lume.add_child(vetro_mi)

	# DENTRO: il serbatoio panciuto, il bruciatore e la fiammella. Il
	# serbatoio non e' un vezzo da collezionisti: e' cio' che si vede
	# attraverso i vetri BASSI, che senza di lui inquadrano il vuoto.
	BUILDER.lathe(lume, [Vector2(0.001, -0.048), Vector2(0.052, -0.050),
			Vector2(0.074, -0.034), Vector2(0.076, -0.010),
			Vector2(0.060, 0.010), Vector2(0.036, 0.020),
			Vector2(0.032, 0.032)], ottone_cupo, Vector3.ZERO, 18)
	BUILDER.lathe(lume, [Vector2(0.032, 0.030), Vector2(0.042, 0.042),
			Vector2(0.027, 0.056), Vector2(0.025, 0.070),
			Vector2(0.036, 0.078), Vector2(0.026, 0.088)],
			ottone, Vector3.ZERO, 16)
	# la fiamma non e' una palla emissiva: e' una goccia tornita col cuore
	# piu' chiaro dentro, e il vetro increspato la spezza sui pannelli
	BUILDER.lathe(lume, [Vector2(0.001, 0.086), Vector2(0.036, 0.112),
			Vector2(0.046, 0.142), Vector2(0.036, 0.180),
			Vector2(0.018, 0.210), Vector2(0.0, 0.228)],
			_glow(Color("6f9df0"), Color("87b6ff"), 1.5), Vector3.ZERO, 16)
	BUILDER.lathe(lume, [Vector2(0.001, 0.102), Vector2(0.019, 0.124),
			Vector2(0.023, 0.150), Vector2(0.015, 0.176),
			Vector2(0.0, 0.194)],
			_glow(Color("dceaff"), Color("eef5ff"), 2.6), Vector3.ZERO, 14)
	_luce_blu(lume, Vector3(0, 0.14, 0))

	# LA PAGODINA: la gronda SPORGE oltre la gabbia (0.314 contro 0.219)
	# col labbro rivoltato all'insu' — e' lo sporto a fare l'ombra sui
	# vetri di giorno e il cappello di luce di notte. La falda e' CONCAVA
	# (ripida in cima, quasi piana al bordo): e' quello a distinguere una
	# pagodina da un imbuto rovesciato. Blu laccata come il palo, con le
	# costole d'ottone sugli spigoli: tutta dorata pesava.
	BUILDER.lathe(lume, [
			Vector2(0.070, 0.328), Vector2(0.180, 0.300), Vector2(0.272, 0.288),
			Vector2(0.308, 0.292), Vector2(0.314, 0.306), Vector2(0.304, 0.322),
			Vector2(0.252, 0.342), Vector2(0.186, 0.378), Vector2(0.118, 0.424),
			Vector2(0.056, 0.468), Vector2(0.0, 0.492)],
			lacca, Vector3.ZERO, LB_LATI)
	for k in LB_LATI:
		var a5 := LB_A0 + float(k) * TAU / float(LB_LATI)
		var u5 := Vector3(cos(a5), 0.0, sin(a5))
		var costa: Array = []
		var rr5: Array = []
		for pv: Vector2 in [Vector2(0.312, 0.308), Vector2(0.302, 0.324),
				Vector2(0.250, 0.344), Vector2(0.184, 0.380),
				Vector2(0.116, 0.426), Vector2(0.052, 0.470),
				Vector2(0.016, 0.488)]:
			costa.append(u5 * (pv.x * 1.012) + Vector3(0, pv.y + 0.004, 0))
			rr5.append(lerpf(0.0104, 0.0056, float(rr5.size()) / 6.0))
		BUILDER.tube(lume, costa, rr5, ottone, 28, 7)
		# la gocciola appesa a ogni angolo della gronda
		var giu := u5 * 0.306
		_cyl(lume, 0.006, 0.005, 0.022, ottone_cupo, giu + Vector3(0, 0.278, 0))
		_ball(lume, 0.0180, ottone, giu + Vector3(0, 0.256, 0),
				Vector3(1.0, 1.25, 1.0))
		_cyl(lume, 0.0055, 0.0008, 0.020, ottone, giu + Vector3(0, 0.234, 0))
	# il pomello e la puntina: il punto piu' alto del pezzo
	_lb_anello(lume, ottone_cupo, 0.496, 0.026, 0.046, 0.62)
	_ball(lume, 0.040, ottone, Vector3(0, 0.524, 0), Vector3(1.0, 0.86, 1.0))
	BUILDER.lathe(lume, [Vector2(0.028, 0.548), Vector2(0.037, 0.559),
			Vector2(0.028, 0.574), Vector2(0.016, 0.596),
			Vector2(0.007, 0.618), Vector2(0.0, 0.630)],
			ottone, Vector3.ZERO, 16)
	return n


static func _cono_segnaletico() -> Node3D:
	# IL CONO, rifatto al tornio. Prima era tre pezzi impilati — scatola,
	# tronco di cono, anello che galleggiava davanti al fusto: adesso è
	# la sagoma VERA di un cono da cantiere. La gonna svasata che si
	# raccorda alla base, il fusto con un filo di entasi, il labbro
	# arrotolato in cima e la bocca APERTA (un cono è cavo, e il buio
	# dentro è quello a dirlo); il collare riflettente AVVOLGE il fusto
	# seguendone la pendenza, coi bordi arrotolati di chi l'ha cucito.
	# E resta storto: nessun cono è mai perfettamente dritto.
	var n := Node3D.new()
	var arancio := _mat(Color("e8956a"), Color("d07a52"), 4.0, 0.45)
	var arancio_scuro := _mat(Color("d07a52"), Color("b8663f"), 4.0, 0.4)
	var bianco := _mat(SEGNALE_BIANCO, Color("e9e2d2"), 5.0, 0.3)

	# LA BASE: lastra ad angoli tondi col gradino smussato sopra, non
	# una scatola a coltello (la _lastra si sdraia ruotandola di PI/2)
	_lastra(n, 0.15, 0.30, 0.045, 0.032, arancio_scuro,
			Vector3(0, 0.016, 0), Vector3(0, 0, PI * 0.5))
	_lastra(n, 0.122, 0.244, 0.05, 0.020, arancio_scuro,
			Vector3(0, 0.038, 0), Vector3(0, 0, PI * 0.5))

	var corpo := Node3D.new()
	corpo.position = Vector3(0, 0.042, 0)
	corpo.rotation.z = 0.05
	corpo.name = "Cono"
	n.add_child(corpo)
	# il fusto, dalla gonna al labbro: UN profilo tornito
	BUILDER.lathe(corpo, [Vector2(0.120, 0.0), Vector2(0.116, 0.008),
			Vector2(0.102, 0.032), Vector2(0.087, 0.065),
			Vector2(0.0755, 0.100), Vector2(0.0655, 0.145),
			Vector2(0.056, 0.195), Vector2(0.0475, 0.245),
			Vector2(0.0405, 0.290), Vector2(0.0375, 0.322),
			Vector2(0.0390, 0.333), Vector2(0.0398, 0.342),
			Vector2(0.0372, 0.352), Vector2(0.0295, 0.356),
			Vector2(0.0235, 0.351), Vector2(0.0225, 0.341)], arancio)
	# il buio della bocca: è lui a dire «cavo»
	_cyl(corpo, 0.0225, 0.0225, 0.004,
			_mat(Color("8a4f33"), Color("6d3d27"), 4.0, 0.3),
			Vector3(0, 0.344, 0))
	# UNA nervatura stampata sopra la gonna: due la facevano «michelin»
	_cordolo(corpo, _super_anello(0.0895, 0.0895, 1.0, 0.0, 40),
			0.0025, arancio_scuro, Vector3(0, 0.058, 0))
	# il collare riflettente, un filo fuori asse: si è assestato
	BUILDER.lathe(corpo, [Vector2(0.0660, 0.138), Vector2(0.0745, 0.146),
			Vector2(0.0685, 0.185), Vector2(0.0605, 0.222),
			Vector2(0.0515, 0.230), Vector2(0.0468, 0.222)], bianco,
			Vector3(0.002, 0, 0))
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
	# LA BICICLETTA DI SERVIZIO: dritta, col cestino davanti. Nessuno insegue nessuno, in questo villaggio: si fa il giro.
	# Una bicicletta si legge dalle sue VERITÀ: le ruote coi RAGGI, il
	# telaio a diamante i cui tubi si INCONTRANO nei nodi, la forcella che
	# scavalca la ruota, la catena, i pedali opposti. E LE CLEARANCE SONO
	# MISURATE, non a occhio: la gomma è un toro largo ±0.030, quindi
	# forcella, foderi e tiranti corrono a x ±0.055 (mai dentro il fianco),
	# e ogni tubo del piano centrale passa ad almeno 0.24 dai centri ruota
	# (gomma 0.23 + margine). La prima stesura aveva il tubo obliquo a
	# 0.17 dal centro: DENTRO il cerchio.
	var n := Node3D.new()
	var telaio := _mat(BLU, BLU_CUPO, 5.0, 0.45)
	var gomma := _mat(Color("4a4640"), Color("3a3733"), 4.0, 0.35)
	var cerchio_mat := _mat(SEGNALE_BIANCO, CREAM, 5.0, 0.25)
	var ottone := _mat(OTTONE, OTTONE_SCURO, 5.0, 0.4)
	var cuoio := _mat(WOOD_DARK, Color("6b4a33"), 4.0, 0.4)
	var bici := Node3D.new()
	bici.name = "Bici"
	n.add_child(bici)
	var tubo := func(a: Vector3, b: Vector3, r: float, mat: Material) -> void:
		var c := _cyl(bici, r, r, a.distance_to(b), mat, (a + b) * 0.5)
		c.rotation.x = atan2(b.z - a.z, b.y - a.y)

	# ---- LE RUOTE: gomma a toro, cerchio, mozzo lungo (ci arrivano
	# forcella e foderi) e otto raggi
	for dz: float in [-0.34, 0.34]:
		var pneu := MeshInstance3D.new()
		var pm := TorusMesh.new()
		pm.inner_radius = 0.17
		pm.outer_radius = 0.23
		pm.rings = 32
		pm.ring_segments = 10
		pneu.mesh = pm
		pneu.material_override = gomma
		pneu.position = Vector3(0, 0.24, dz)
		pneu.rotation.z = PI * 0.5
		bici.add_child(pneu)
		var cerchio := MeshInstance3D.new()
		var cm := TorusMesh.new()
		cm.inner_radius = 0.152
		cm.outer_radius = 0.175
		cm.rings = 32
		cm.ring_segments = 8
		cerchio.mesh = cm
		cerchio.material_override = cerchio_mat
		cerchio.position = Vector3(0, 0.24, dz)
		cerchio.rotation.z = PI * 0.5
		bici.add_child(cerchio)
		var mozzo := _cyl(bici, 0.028, 0.028, 0.13, ottone, Vector3(0, 0.24, dz))
		mozzo.rotation.z = PI * 0.5
		for k in 8:
			var ra := float(k) * TAU / 8.0 + (0.2 if dz > 0.0 else 0.0)
			var raggio := _cyl(bici, 0.0055, 0.0055, 0.14, cerchio_mat,
					Vector3(0, 0.24 + cos(ra) * 0.09, dz + sin(ra) * 0.09))
			raggio.rotation.x = ra

	# ---- IL TELAIO: sterzo col rake, obliquo che SCHIVA la ruota (0.24
	# misurati dal centro), orizzontale, piantone
	tubo.call(Vector3(0, 0.65, -0.235), Vector3(0, 0.50, -0.26), 0.030, telaio)
	tubo.call(Vector3(0, 0.50, -0.25), Vector3(0, 0.295, 0.03), 0.028, telaio)
	tubo.call(Vector3(0, 0.615, -0.225), Vector3(0, 0.635, 0.155), 0.024, telaio)
	tubo.call(Vector3(0, 0.295, 0.03), Vector3(0, 0.655, 0.185), 0.026, telaio)
	var mc := _cyl(bici, 0.036, 0.036, 0.19, telaio, Vector3(0, 0.295, 0.03))
	mc.rotation.z = PI * 0.5
	# la testa della forcella, e le due gambe che scavalcano la gomma
	_box(bici, Vector3(0.13, 0.032, 0.05), telaio, Vector3(0, 0.505, -0.263))
	for fx: float in [-0.055, 0.055]:
		tubo.call(Vector3(fx, 0.505, -0.265), Vector3(fx, 0.24, -0.335), 0.013, telaio)
		tubo.call(Vector3(fx, 0.29, 0.05), Vector3(fx, 0.24, 0.33), 0.013, telaio)
		tubo.call(Vector3(fx, 0.62, 0.165), Vector3(fx, 0.245, 0.325), 0.012, telaio)

	# ---- LA TRASMISSIONE: corona, pignone, catena, pedivelle opposte
	# che nascono dal perno
	var corona := _cyl(bici, 0.075, 0.075, 0.014, ottone, Vector3(0.06, 0.295, 0.03))
	corona.rotation.z = PI * 0.5
	var pignone := _cyl(bici, 0.040, 0.040, 0.012, ottone, Vector3(0.06, 0.24, 0.33))
	pignone.rotation.z = PI * 0.5
	var su := _box(bici, Vector3(0.010, 0.298, 0.014), gomma, Vector3(0.06, 0.3215, 0.1825))
	su.rotation.x = atan2(0.285, -0.087)
	var giu := _box(bici, Vector3(0.010, 0.286, 0.014), gomma, Vector3(0.06, 0.2135, 0.1825))
	giu.rotation.x = atan2(0.285, -0.023)
	# le pedivelle: destra avanti in basso (dove il fianco è libero),
	# sinistra dietro in alto (dentro il triangolo posteriore, non a
	# mezz'aria sopra l'obliquo); ogni pedale ha il suo PERNO che lo
	# lega alla pedivella, e l'occhio d'ottone sul filo esterno
	var ped_dx := _box(bici, Vector3(0.014, 0.105, 0.026), telaio,
			Vector3(0.085, 0.2525, -0.0025))
	ped_dx.rotation.x = 0.65
	var perno_dx := _cyl(bici, 0.008, 0.008, 0.034, telaio, Vector3(0.102, 0.205, -0.05))
	perno_dx.rotation.z = PI * 0.5
	_box(bici, Vector3(0.07, 0.018, 0.05), gomma, Vector3(0.128, 0.205, -0.05))
	_ball(bici, 0.009, ottone, Vector3(0.165, 0.205, -0.05))
	var ped_sx := _box(bici, Vector3(0.014, 0.105, 0.026), telaio,
			Vector3(-0.085, 0.3375, 0.0625))
	ped_sx.rotation.x = 0.65
	var perno_sx := _cyl(bici, 0.008, 0.008, 0.034, telaio, Vector3(-0.102, 0.385, 0.115))
	perno_sx.rotation.z = PI * 0.5
	_box(bici, Vector3(0.07, 0.018, 0.05), gomma, Vector3(-0.128, 0.385, 0.115))
	_ball(bici, 0.009, ottone, Vector3(-0.165, 0.385, 0.115))

	# ---- LA SELLA di cuoio sul cannotto (nodo "Sella")
	tubo.call(Vector3(0, 0.645, 0.165), Vector3(0, 0.705, 0.18), 0.015, telaio)
	var sella := _ball(bici, 0.062, cuoio, Vector3(0, 0.72, 0.18), Vector3(1.0, 0.42, 1.55))
	sella.name = "Sella"

	# ---- MANUBRIO (nodo omonimo): attacco, tubo, manopole e campanello
	tubo.call(Vector3(0, 0.645, -0.235), Vector3(0, 0.695, -0.25), 0.017, telaio)
	var manubrio := _cyl(bici, 0.016, 0.016, 0.36, telaio, Vector3(0, 0.70, -0.25))
	manubrio.name = "Manubrio"
	manubrio.rotation.z = PI * 0.5
	for sx: float in [-0.165, 0.165]:
		var manopola := _cyl(bici, 0.024, 0.024, 0.085, cuoio, Vector3(sx, 0.70, -0.25))
		manopola.rotation.z = PI * 0.5
	_cyl(bici, 0.026, 0.026, 0.018, ottone, Vector3(-0.125, 0.725, -0.245))
	_ball(bici, 0.020, ottone, Vector3(-0.125, 0.738, -0.245), Vector3(1, 0.6, 1))

	# ---- IL FANALINO d'ottone sotto il cestino, sul tubo di sterzo
	var fanale := _cyl(bici, 0.024, 0.030, 0.045, ottone, Vector3(0, 0.50, -0.30))
	fanale.rotation.x = PI * 0.5
	var lente := _cyl(bici, 0.020, 0.020, 0.012, _mat(CREAM, Color("ffe6b0"), 6.0, 0.3),
			Vector3(0, 0.50, -0.327))
	lente.rotation.x = PI * 0.5

	# ---- IL CESTINO di vimini (nodo "Cestino") con le fascette, retto
	# dai due tiranti d'ottone che vanno alla testa della forcella
	var cesto := _cyl(bici, 0.145, 0.11, 0.16, _mat(WOOD_PALE, WOOD, 7.0, 0.6),
			Vector3(0, 0.60, -0.40))
	cesto.name = "Cestino"
	for banda: Array in [[0.665, 0.138, 0.150], [0.575, 0.118, 0.130]]:
		var fascia := MeshInstance3D.new()
		var fm := TorusMesh.new()
		fm.inner_radius = banda[1]
		fm.outer_radius = banda[2]
		fm.rings = 28
		fm.ring_segments = 6
		fascia.mesh = fm
		fascia.material_override = _mat(WOOD, WOOD_DARK, 6.0, 0.5)
		fascia.position = Vector3(0, banda[0], -0.40)
		bici.add_child(fascia)
	for cx: float in [-0.05, 0.05]:
		tubo.call(Vector3(cx, 0.545, -0.37), Vector3(cx, 0.515, -0.26), 0.008, ottone)

	# ---- IL PARAFANGO sopra la ruota dietro: sette segmenti tangenti
	# alla curva, come la tela dell'amaca — è lui a separare la ruota dal
	# portapacchi, e il retro smette di essere un incrocio di stecche
	for pk in 7:
		var pa := -0.9 + float(pk) * 0.3
		var lamiera := _box(bici, Vector3(0.07, 0.013, 0.078), telaio,
				Vector3(0, 0.24 + cos(pa) * 0.247, 0.34 + sin(pa) * 0.247))
		lamiera.rotation.x = pa

	# ---- IL PORTAPACCHI, montato come si monta davvero: DUE punti per
	# lato — i tiranti al mozzo e i braccetti ai foderi alti — e sopra
	# la piattaforma coi listelli
	for rx: float in [-0.05, 0.05]:
		_box(bici, Vector3(0.014, 0.010, 0.24), telaio, Vector3(rx, 0.527, 0.38))
		tubo.call(Vector3(rx, 0.523, 0.46), Vector3(rx, 0.26, 0.345), 0.008, telaio)
		tubo.call(Vector3(rx, 0.523, 0.275), Vector3(rx, 0.565, 0.19), 0.008, telaio)
	_box(bici, Vector3(0.112, 0.010, 0.016), telaio, Vector3(0, 0.527, 0.265))
	for rz: float in [0.305, 0.37, 0.435, 0.495]:
		_box(bici, Vector3(0.11, 0.006, 0.016), telaio, Vector3(0, 0.535, rz))

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


## ------------------------------------------------------------------
## I FERRI PER LE SUPERFICI MORBIDE. Un materasso non è una scatola, un
## cuscino non è una sfera schiacciata e un piumone non è una griglia di
## palline: sono SUPERFICI — normali morbide, bordi che girano, pieghe
## dove la stoffa cade. Questi ferri le costruiscono per davvero.

## Triangola una griglia di vertici (righe di PackedVector3Array) con le
## normali calcolate PER VERTICE dalle tangenti — è questo a rendere
## morbida una superficie, non il numero di poligoni. `avvolgi` chiude
## l'ultima colonna sulla prima (superfici di giro); `doppia` emette
## anche il rovescio, per i teli sottili che si vedono da sotto (l'orlo
## di un piumone), che altrimenti sparirebbero nel backface culling.
static func _mesh_griglia(parent: Node3D, vg: Array, mat: Material,
		pos := Vector3.ZERO, avvolgi := false, doppia := false) -> MeshInstance3D:
	var nr := vg.size()
	var nc := (vg[0] as PackedVector3Array).size()
	var ng: Array = []
	for i in nr:
		var riga := (vg[i] as PackedVector3Array)
		var su := (vg[mini(i + 1, nr - 1)] as PackedVector3Array)
		var giu := (vg[maxi(i - 1, 0)] as PackedVector3Array)
		var riga_n := PackedVector3Array()
		for j in nc:
			var jp := (j + 1) % nc if avvolgi else mini(j + 1, nc - 1)
			var jm := (j - 1 + nc) % nc if avvolgi else maxi(j - 1, 0)
			var t_col := riga[jp] - riga[jm]
			var t_riga := su[j] - giu[j]
			riga_n.append(t_riga.cross(t_col).normalized())
		ng.append(riga_n)
	# ai poli (righe degeneri) le tangenti si annullano: si eredita la
	# normale della riga accanto, che lì converge comunque
	for i in nr:
		for j in nc:
			if (ng[i] as PackedVector3Array)[j].length_squared() < 0.5:
				var presta := (ng[clampi(i + (1 if i == 0 else -1), 0, nr - 1)] 						as PackedVector3Array)[j]
				(ng[i] as PackedVector3Array)[j] = presta
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nq := nc if avvolgi else nc - 1
	for i in nr - 1:
		var r0 := (vg[i] as PackedVector3Array)
		var r1 := (vg[i + 1] as PackedVector3Array)
		var n0 := (ng[i] as PackedVector3Array)
		var n1 := (ng[i + 1] as PackedVector3Array)
		for j in nq:
			var j2 := (j + 1) % nc
			if r0[j].distance_squared_to(r0[j2]) < 1e-14 					and r1[j].distance_squared_to(r1[j2]) < 1e-14:
				continue
			st.set_normal(n0[j]);  st.add_vertex(r0[j])
			st.set_normal(n1[j2]); st.add_vertex(r1[j2])
			st.set_normal(n1[j]);  st.add_vertex(r1[j])
			st.set_normal(n0[j]);  st.add_vertex(r0[j])
			st.set_normal(n0[j2]); st.add_vertex(r0[j2])
			st.set_normal(n1[j2]); st.add_vertex(r1[j2])
			if doppia:
				st.set_normal(-n0[j]);  st.add_vertex(r0[j])
				st.set_normal(-n1[j]);  st.add_vertex(r1[j])
				st.set_normal(-n1[j2]); st.add_vertex(r1[j2])
				st.set_normal(-n0[j]);  st.add_vertex(r0[j])
				st.set_normal(-n1[j2]); st.add_vertex(r1[j2])
				st.set_normal(-n0[j2]); st.add_vertex(r0[j2])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


## IL SUPERELLISSOIDE: la forma vera delle cose imbottite. Fra la scatola
## (spigoli a coltello) e la sfera (niente facce) c'è tutta la famiglia
## dei cuscini: `e_o`/`e_v` dicono quanto gli spigoli sono pieni —
## piccoli = squadrato morbido (materassi), grandi = paffuto (guanciali).
## `conche` scava avvallamenti VERI nella faccia di sopra (la testa di
## chi ha dormito, il bottone della trapuntatura): [x, z, raggio, prof].
static func _soffice(parent: Node3D, dim: Vector3, mat: Material,
		pos := Vector3.ZERO, e_o := 0.5, e_v := 0.62, conche: Array = [],
		lati := 28, file := 16) -> MeshInstance3D:
	var a := dim.x * 0.5
	var b := dim.y * 0.5
	var c := dim.z * 0.5
	var vg: Array = []
	for i in file + 1:
		var v := -PI * 0.5 + PI * float(i) / float(file)
		var rf := pow(absf(cos(v)), e_v)
		var yf := signf(sin(v)) * pow(absf(sin(v)), e_v) * b
		var riga := PackedVector3Array()
		for j in lati:
			var u := TAU * float(j) / float(lati)
			var px := signf(cos(u)) * pow(absf(cos(u)), e_o) * rf * a
			var pz := signf(sin(u)) * pow(absf(sin(u)), e_o) * rf * c
			var py := yf
			for k in conche:
				if v > 0.0:
					var dq := Vector2(px - float(k[0]), pz - float(k[1])) 							.length() / maxf(float(k[2]), 1e-5)
					py -= float(k[3]) * exp(-dq * dq) * sin(v)
			riga.append(Vector3(px, py, pz))
		vg.append(riga)
	return _mesh_griglia(parent, vg, mat, pos, true)


## Il percorso a superellisse (la pianta di un materasso), per i cordoli.
static func _super_anello(a: float, c: float, e: float, y: float,
		np := 48) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in np:
		var u := TAU * float(i) / float(np)
		out.append(Vector3(signf(cos(u)) * pow(absf(cos(u)), e) * a, y,
				signf(sin(u)) * pow(absf(sin(u)), e) * c))
	return out


## IL CORDOLO: la cucitura in rilievo che corre lungo un percorso CHIUSO
## — il bordo di un materasso, l'orlo di una federa. UN tubo continuo:
## quattro cilindri più quattro sfere agli angoli non sono una cucitura,
## sono l'impalcatura di una cucitura.
static func _cordolo(parent: Node3D, percorso: PackedVector3Array,
		raggio: float, mat: Material, pos := Vector3.ZERO,
		lati := 10) -> MeshInstance3D:
	var np := percorso.size()
	var vg: Array = []
	for i in np + 1:
		var ii := i % np
		var t := (percorso[(ii + 1) % np] - percorso[(ii - 1 + np) % np]).normalized()
		var lato := t.cross(Vector3.UP).normalized()
		if lato.length_squared() < 0.5:
			lato = Vector3.RIGHT
		var alza := lato.cross(t).normalized()
		var riga := PackedVector3Array()
		for j in lati:
			var a2 := TAU * float(j) / float(lati)
			riga.append(percorso[ii] + (lato * cos(a2) + alza * sin(a2)) * raggio)
		vg.append(riga)
	return _mesh_griglia(parent, vg, mat, pos, true)


## LA TRAPUNTA CHE CADE: il piumone come UNA tela. Sopra, i riquadri
## dell'imbottitura sono bombature della superficie stessa (le cuciture
## sono le valli fra loro, non un disegno appoggiato); ai bordi la tela
## GIRA — un quarto di cerchio, come fa la stoffa su uno spigolo — e poi
## cade, e l'orlo ondeggia con tre sinusoidi incommensurabili: le pieghe
## di un telo appeso non sono una fila di rulli, sono onde di UNA
## superficie. Drappeggia i fianchi (±X) e i piedi (z0); il lato di
## testa (z1) resta crudo perché lì sopra ci vanno risvolto e cuscini.
static func _trapunta(parent: Node3D, wx2: float, z0: float, z1: float,
		y_base: float, gonf: float, nx: int, nz: int, amp: float,
		drappo_x: float, drappo_z: float, mat: Material, seme: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seme
	var fasi := [rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU,
			rng.randf() * TAU]
	# --- la faccia di sopra: bombature a riquadri su una griglia ---
	var gx := 40
	var gz := 30
	var lx := wx2 * 2.0
	var lz := z1 - z0
	var vg: Array = []
	for i in gz:
		var z := z0 + lz * float(i) / float(gz - 1)
		var riga := PackedVector3Array()
		for j in gx:
			var x := -wx2 + lx * float(j) / float(gx - 1)
			# quanto sei lontano dai tre bordi che drappeggiano
			var bordo := minf(minf(wx2 - absf(x), z - z0), 0.10)
			var fat := smoothstep(0.0, 0.10, bordo)
			var fx := fposmod((x + wx2) / lx * float(nx), 1.0)
			var fz := fposmod((z - z0) / lz * float(nz), 1.0)
			# ogni riquadro col suo gonfiore: due gemelli tradiscono il timbro
			var cel := float(int((x + wx2) / lx * float(nx)) * 7
					+ int((z - z0) / lz * float(nz)) * 13 + seme % 97)
			var vita := 0.72 + 0.28 * fposmod(sin(cel * 12.9898) * 43758.55, 1.0)
			var cuscino := amp * vita * pow(sin(PI * fx) * sin(PI * fz), 1.35)
			riga.append(Vector3(x,
					y_base + gonf * 0.25 + (gonf * 0.75 + cuscino) * fat, z))
		vg.append(riga)
	_mesh_griglia(parent, vg, mat, Vector3.ZERO, false, true)
	# --- il drappo: la tela gira sul bordo e cade, l'orlo ondeggia ---
	var rc := 0.045                    # il raggio con cui la stoffa gira
	var rc2 := 0.06                    # gli angoli della pianta
	var y_giro := y_base + gonf * 0.25
	var passo := 0.02
	# il percorso dei tre bordi, con gli angoli tondi: (punto, normale)
	var rotta: Array = []
	var z_c := z0 + rc2
	var zq := z1
	while zq > z_c:
		rotta.append([Vector3(-wx2, 0, zq), Vector3(-1, 0, 0)])
		zq -= passo
	for k in 7:
		var a3 := PI + PI * 0.5 * float(k) / 6.0
		var nrm := Vector3(cos(a3), 0, sin(a3))
		rotta.append([Vector3(-wx2 + rc2, 0, z_c) + nrm * rc2, nrm])
	var xq := -wx2 + rc2
	while xq < wx2 - rc2:
		rotta.append([Vector3(xq, 0, z0), Vector3(0, 0, -1)])
		xq += passo
	for k2 in 7:
		var a4 := PI * 1.5 + PI * 0.5 * float(k2) / 6.0
		var nrm2 := Vector3(cos(a4), 0, sin(a4))
		rotta.append([Vector3(wx2 - rc2, 0, z_c) + nrm2 * rc2, nrm2])
	zq = z_c
	while zq <= z1:
		rotta.append([Vector3(wx2, 0, zq), Vector3(1, 0, 0)])
		zq += passo
	# la spazzata: righe lungo la rotta, colonne lungo la caduta
	var vd: Array = []
	var s_cam := 0.0
	var prima: Vector3 = (rotta[0] as Array)[0]
	for passo_r in rotta:
		var pun: Vector3 = (passo_r as Array)[0]
		var nrm3: Vector3 = (passo_r as Array)[1]
		s_cam += pun.distance_to(prima)
		prima = pun
		# quanto cade QUI: sui fianchi drappo_x, ai piedi drappo_z, e in
		# curva la normale li fonde da sola — niente cuciture di casi
		var cade: float = nrm3.x * nrm3.x * drappo_x + nrm3.z * nrm3.z * drappo_z
		# l'onda dell'orlo: tre frequenze che non si richiudono mai
		var onda: float = amp * 0.55 * (sin(s_cam * 21.0 + fasi[0])
				+ 0.55 * sin(s_cam * 33.7 + fasi[1])
				+ 0.30 * sin(s_cam * 54.1 + fasi[2]))
		var riga2 := PackedVector3Array()
		for k3 in 9:
			var fr := float(k3) / 8.0
			var fuori: float
			var giu: float
			if k3 <= 4:
				var th := float(k3) / 4.0 * PI * 0.5
				fuori = rc * sin(th)
				giu = rc * (1.0 - cos(th))
			else:
				fuori = rc
				giu = rc + (float(k3) - 4.0) / 4.0 * maxf(cade - rc, 0.0)
			giu *= 1.0 + 0.12 * sin(s_cam * 13.3 + fasi[3]) * fr
			var base := pun - nrm3 * 0.006
			riga2.append(Vector3(base.x + nrm3.x * (fuori + onda * fr * fr),
					y_giro - giu, base.z + nrm3.z * (fuori + onda * fr * fr)))
		vd.append(riga2)
	_mesh_griglia(parent, vd, mat, Vector3.ZERO, false, true)


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


## IL PORTONE DELLA RIMESSA. Un portone da autorimessa si misura sul suo
## mezzo: l'Autopompa è larga 0.83 e alta 1.08, e la luce qui è 1.76 × 1.96 —
## una campata VERA, larga due celle (il pezzo sborda sui bordi vicini come
## la Sbarra: si piazza lasciando liberi i lati). L'impianto è un PORTALE in
## rilievo — pilastri con base di pietra e capitello, architrave con la
## cornice in aggetto, soglia a rampa su cui l'autopompa scende in strada —
## con la SERRANDA incassata dietro, a pannelli bugnati coi giunti in ombra,
## nelle sue guide di ferro quasi nascoste. I gioielli: TRE oblò con la
## ghiera d'ottone imbullonata e il vetro vero in fila sul pannello alto,
## il maniglione, il paraurti a strisce diagonali tagliate dentro la fascia,
## e il lampeggiante rosso sulla mensolina — spento, finché non c'è da
## correre.
static func _portone_rimessa() -> Node3D:
	var n := Node3D.new()
	var rosso := _mat(POMPA_ROSSO, POMPA_ROSSO_SCURO, 3.0, 0.45)
	var rosso_cupo := _mat(POMPA_ROSSO_SCURO, POMPA_ROSSO_SCURO.darkened(0.2), 3.0, 0.4)
	var crema := _mat(CREAM, PLASTER_SHADE, 4.0, 0.4)
	var pietra := _mat(STONE, STONE_DARK, 3.0, 0.55)
	var ferro := _mat(Color("4a443c"), Color("332f29"), 5.0, 0.4)
	var ottone := _mat(OTTONE, OTTONE_SCURO, 6.0, 0.35)

	# ---- IL PORTALE: pilastri con base di pietra e capitello ai bordi
	# della campata, architrave che la scavalca tutta, cornice in aggetto
	for sx: float in [-1.0, 1.0]:
		_box(n, Vector3(0.14, 0.13, 0.24), pietra, Vector3(sx * 0.94, 0.065, 0))
		_box(n, Vector3(0.12, 1.80, 0.20), crema, Vector3(sx * 0.94, 1.03, 0))
		_box(n, Vector3(0.15, 0.09, 0.23), crema, Vector3(sx * 0.94, 1.975, 0))
	_box(n, Vector3(2.0, 0.22, 0.22), crema, Vector3(0, 2.07, 0))
	_box(n, Vector3(2.06, 0.055, 0.26), _mat(PLASTER_SHADE, Color("cbb89a"), 3.0, 0.45),
			Vector3(0, 2.21, 0))
	_box(n, Vector3(1.86, 0.05, 0.20), pietra, Vector3(0, 0.025, 0))
	var rampa := _box(n, Vector3(1.86, 0.035, 0.20), pietra, Vector3(0, 0.030, -0.16))
	rampa.rotation.x = -0.20

	# ---- LE GUIDE della serranda: due binari di ferro quasi tutti nascosti
	# dietro i pilastri — se ne vede solo il filo, com'è giusto
	for gx: float in [-0.875, 0.875]:
		_box(n, Vector3(0.03, 1.86, 0.05), ferro, Vector3(gx, 0.98, 0.035))

	# ---- LA SERRANDA, incassata dietro il portale: quattro pannelli larghi
	# quanto la campata, ognuno con QUATTRO bugne in rilievo più cupe, e fra
	# l'uno e l'altro un giunto sottile in ombra (niente strisce dipinte: è
	# il rilievo a disegnarla)
	for pnl in 4:
		var py := 0.29 + float(pnl) * 0.482
		_box(n, Vector3(1.80, 0.48, 0.05), rosso, Vector3(0, py, 0.035))
		if pnl < 3:
			for bx: float in [-0.648, -0.216, 0.216, 0.648]:
				_box(n, Vector3(0.36, 0.30, 0.016), rosso_cupo, Vector3(bx, py, 0.006))
			_box(n, Vector3(1.80, 0.014, 0.036), ferro, Vector3(0, py + 0.241, 0.042))

	# ---- I TRE OBLÒ in fila sul pannello alto, ognuno sulla sua bugna:
	# ghiera d'ottone coi bulloncini e il vetro VERO che affiora dalle due
	# facce (di sera, il muso dell'autopompa)
	for x: float in [-0.56, 0.0, 0.56]:
		_box(n, Vector3(0.44, 0.30, 0.016), rosso_cupo, Vector3(x, 1.736, 0.006))
		var ghiera := _cyl(n, 0.112, 0.112, 0.035, ottone, Vector3(x, 1.736, -0.005))
		ghiera.rotation.x = PI * 0.5
		var v := MeshInstance3D.new()
		var vm := CylinderMesh.new()
		vm.top_radius = 0.086
		vm.bottom_radius = 0.086
		vm.height = 0.13
		v.mesh = vm
		v.material_override = _vetro()
		v.position = Vector3(x, 1.736, 0.03)
		v.rotation.x = PI * 0.5
		n.add_child(v)
		for b in 4:
			var ab := float(b) * TAU / 4.0 + 0.4
			_ball(n, 0.010, ottone,
					Vector3(x + cos(ab) * 0.100, 1.736 + sin(ab) * 0.100, -0.021),
					Vector3(1, 1, 0.5))

	# ---- IL PARAURTI a strisce diagonali in basso: crema su fondo cupo,
	# come si dipinge dove entra un mezzo. Le strisce restano DENTRO la
	# fascia: tagliate su misura, non appoggiate
	_box(n, Vector3(1.80, 0.15, 0.014), rosso_cupo, Vector3(0, 0.155, -0.0))
	for st in 12:
		var stx := -0.693 + float(st) * 0.126
		var striscia := _box(n, Vector3(0.04, 0.125, 0.010), crema,
				Vector3(stx, 0.155, -0.006))
		striscia.rotation.z = -0.55

	# ---- IL MANIGLIONE d'ottone sul secondo pannello: la barra con le
	# due staffe
	for mx: float in [-0.19, 0.19]:
		_box(n, Vector3(0.025, 0.05, 0.05), ottone, Vector3(mx, 0.60, -0.02))
	var barra := _cyl(n, 0.017, 0.017, 0.44, ottone, Vector3(0, 0.60, -0.045))
	barra.rotation.z = PI * 0.5

	# ---- IL LAMPEGGIANTE sulla mensolina dell'architrave: la campana
	# rossa sulla base d'ottone. Spento — in questo villaggio l'unico
	# allarme è la campana, ma la rimessa ce l'ha, perché una rimessa
	# vera ce l'ha.
	_box(n, Vector3(0.13, 0.024, 0.07), crema, Vector3(0, 1.985, -0.135))
	_cyl(n, 0.045, 0.052, 0.028, ottone, Vector3(0, 2.011, -0.135))
	_ball(n, 0.046, _mat(Color("e0524a"), Color("b8423c"), 8.0, 0.3),
			Vector3(0, 2.045, -0.135), Vector3(1.0, 0.85, 1.0))
	return n


## LA TORRETTA DI VEDETTA, e stavolta CI SI SALE: lo spiazzo è largo un
## metro e trenta ed è un pavimento vero (collisioni da pezzo
## calpestabile, scaletta-rampa come la casa sull'albero), e la gronda
## sta a un metro e sessantotto dal piancito — la volpina, che con le
## orecchie fa un metro e sessanta, lassù non si china. Gambe tornite
## sui basamenti di pietra, croci a tondino coi bulloni d'ottone, tetto
## a pagoda svasata, pennone con la bandierina, campanella d'allarme e
## lanterna appese alla gronda SOPRA IL VUOTO (mai dove si cammina), il
## cannocciale puntato sull'orizzonte: di sera è un faro gentile.
static func _torretta() -> Node3D:
	var n := Node3D.new()
	var pale := _mat(WOOD_PALE, WOOD, 3.0, 0.45)
	var wood := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	var rosso := _mat(POMPA_ROSSO, POMPA_ROSSO_SCURO, 3.0, 0.45)
	var ottone := _mat(OTTONE, OTTONE_SCURO, 5.0, 0.4)
	var canapa := _mat(Color("d9c49a"), Color("c0a978"), 7.0, 0.5)

	# le gambe TORNITE, un filo svasate, ognuna sul suo basamento di
	# pietra (il legno a terra nuda marcisce, e una vedetta lo sa)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var g := _cyl(n, 0.042, 0.058, 1.86, wood,
					Vector3(sx * 0.4, 0.95, sz * 0.4))
			g.rotation.z = -sx * 0.05
			g.rotation.x = sz * 0.05
			_cyl(n, 0.068, 0.082, 0.06, _mat(STONE, STONE_DARK, 4.0, 0.5),
					Vector3(sx * 0.447, 0.03, sz * 0.447))
	# gli anelli orizzontali che legano le gambe, su due quote
	for quota: Array in [[0.6, 0.428], [1.5, 0.383]]:
		var qy := float(quota[0])
		var qr := float(quota[1])
		for lato in 4:
			var a := float(lato) * PI * 0.5
			var trave := _cyl(n, 0.028, 0.028, qr * 2.0 + 0.08, wood,
					Vector3(sin(a) * qr, qy, cos(a) * qr))
			trave.rotation.z = PI * 0.5
			trave.rotation.y = a
	# le croci di controvento a TONDINO fra i due anelli, col bullone
	# d'ottone nel punto in cui si incrociano
	for lato in 4:
		var a := float(lato) * PI * 0.5
		for verso: float in [-1.0, 1.0]:
			var c := _cyl(n, 0.021, 0.021, 1.22, wood,
					Vector3(sin(a) * 0.405, 1.05, cos(a) * 0.405))
			c.rotation.y = a
			c.rotation.z = verso * 0.74
		_ball(n, 0.03, ottone, Vector3(sin(a) * 0.41, 1.05, cos(a) * 0.41))

	# la SCALETTA sul fronte: montanti tondi appoggiati al bordo dello
	# spiazzo e pioli tondi — si sale da qui, dal varco della ringhiera.
	# A filo terra, non DENTRO la terra: la guardia d'altezza misura la
	# taglia, e i centimetri sotto lo zero contano.
	for sx2: float in [-0.15, 0.15]:
		var montante := _cyl(n, 0.026, 0.03, 2.05, wood, Vector3(sx2, 1.02, -0.9))
		montante.rotation.x = 0.24
	for i in 8:
		var t := (float(i) + 0.6) / 8.6
		var piolo := _cyl(n, 0.019, 0.019, 0.33, pale,
				Vector3(0, 0.13 + t * 1.73, -1.12 + t * 0.45))
		piolo.rotation.z = PI * 0.5

	# lo SPIAZZO stondato, largo che ci si sta in tre a guardare il
	# tramonto, con le righe delle assi
	_loft(n, [[-0.65, 0.62, 1.84, 1.92, 0.035],
			[-0.62, 0.65, 1.84, 1.92, 0.022],
			[0.62, 0.65, 1.84, 1.92, 0.022],
			[0.65, 0.62, 1.84, 1.92, 0.035]], pale)
	for gz: float in [-0.44, -0.22, 0.0, 0.22, 0.44]:
		_box(n, Vector3(1.26, 0.005, 0.016), wood, Vector3(0, 1.923, gz))

	# la ringhiera: paletti col pomello, corrimano cilindrico e mezza
	# traversa; a sud il VARCO dove arriva la scaletta
	for p_r: Array in [[-0.62, -0.62], [0.62, -0.62], [-0.62, 0.62],
			[0.62, 0.62], [-0.62, 0.0], [0.62, 0.0], [0.0, 0.62],
			[-0.22, -0.62], [0.22, -0.62]]:
		_cyl(n, 0.022, 0.025, 0.32, pale,
				Vector3(float(p_r[0]), 2.08, float(p_r[1])))
		_ball(n, 0.032, pale, Vector3(float(p_r[0]), 2.255, float(p_r[1])))
	for quota_r: Array in [[2.24, 0.024], [2.09, 0.016]]:
		var qy2 := float(quota_r[0])
		var qr2 := float(quota_r[1])
		var nord_r := _cyl(n, qr2, qr2, 1.28, pale, Vector3(0, qy2, 0.62))
		nord_r.rotation.z = PI * 0.5
		for sx3: float in [-0.62, 0.62]:
			var fianco_r := _cyl(n, qr2, qr2, 1.28, pale, Vector3(sx3, qy2, 0))
			fianco_r.rotation.x = PI * 0.5
		for sx4: float in [-0.42, 0.42]:
			var sud_r := _cyl(n, qr2, qr2, 0.4, pale, Vector3(sx4, qy2, -0.62))
			sud_r.rotation.z = PI * 0.5

	# i quattro montanti che reggono il tetto, alti quanto serve perché
	# lassù nessuno si chini (prima il cono galleggiava per fede)
	for sx5: float in [-1.0, 1.0]:
		for sz5: float in [-1.0, 1.0]:
			_cyl(n, 0.03, 0.036, 1.54, wood, Vector3(sx5 * 0.55, 2.69, sz5 * 0.55))

	# IL TETTO A PAGODA: una falda tornita che si svasa verso la gronda —
	# un cono dritto è geometria, non un tetto — col pennone d'ottone e
	# la bandierina rossa in cima. La gronda copre tutto lo spiazzo, e
	# la guardia d'altezza per la torre visitabile concede quattro metri.
	BUILDER.lathe(n, [Vector2(0.95, -0.06), Vector2(0.92, -0.043),
			Vector2(0.80, -0.008), Vector2(0.60, 0.062), Vector2(0.40, 0.145),
			Vector2(0.22, 0.222), Vector2(0.06, 0.262), Vector2(0.0, 0.28)],
			rosso, Vector3(0, 3.52, 0))
	_cyl(n, 0.008, 0.008, 0.06, ottone, Vector3(0, 3.815, 0))
	_ball(n, 0.014, ottone, Vector3(0, 3.838, 0))
	var bandiera := _prisma(n, [Vector2(0.0, 0.0), Vector2(0.13, 0.04),
			Vector2(0.13, -0.04)], 0.0, 0.012, rosso)
	bandiera.position = Vector3(0.015, 3.81, 0)
	bandiera.rotation.x = PI * 0.5
	bandiera.rotation.y = -0.4

	# la campanella d'allarme appesa alla gronda di sud-ovest, SOPRA IL
	# VUOTO oltre la ringhiera: si suona per chiamare, e non c'è mai
	# stato bisogno di suonarla
	var braccio_c := _cyl(n, 0.011, 0.011, 0.14, ottone, Vector3(-0.48, 3.42, -0.48))
	braccio_c.rotation.z = 0.7
	braccio_c.rotation.y = PI * 0.25
	BUILDER.lathe(n, [Vector2(0.037, 0.0), Vector2(0.04, 0.006),
			Vector2(0.035, 0.016), Vector2(0.028, 0.03), Vector2(0.02, 0.042),
			Vector2(0.008, 0.052), Vector2(0.0, 0.056)],
			ottone, Vector3(-0.53, 3.31, -0.53))
	_ball(n, 0.008, ottone, Vector3(-0.53, 3.31, -0.53))
	_cyl(n, 0.0035, 0.0035, 0.1, canapa, Vector3(-0.53, 3.26, -0.53))

	# il cannocciale d'ottone sulla ringhiera, puntato fuori: è il
	# mestiere di questo posto, guardare lontano
	_cyl(n, 0.009, 0.009, 0.055, ottone, Vector3(0.62, 2.28, 0.15))
	_ball(n, 0.015, ottone, Vector3(0.62, 2.31, 0.15))
	var tubo_c := _cyl(n, 0.017, 0.024, 0.17, ottone, Vector3(0.68, 2.335, 0.15))
	tubo_c.rotation.z = 1.35
	# il rotolo di corda sul piancito, pronto da calare
	var rotolo := MeshInstance3D.new()
	var rm := TorusMesh.new()
	rm.inner_radius = 0.028
	rm.outer_radius = 0.072
	rotolo.mesh = rm
	rotolo.material_override = canapa
	rotolo.position = Vector3(0.42, 1.94, 0.42)
	n.add_child(rotolo)

	# la lanterna in GABBIA appesa alla gronda di nord-est, anche lei
	# sopra il vuoto: cappello, vetro caldo e la goccia d'ottone sotto —
	# il punto caldo della sera, e nessuna testa da urtare
	_cyl(n, 0.01, 0.01, 0.13, ottone, Vector3(0.52, 3.39, 0.52))
	_cyl(n, 0.022, 0.058, 0.05, ottone, Vector3(0.52, 3.30, 0.52))
	_ball(n, 0.075, _glow(Color("ffe6b0"), Color("ffcf86"), 1.4), Vector3(0.52, 3.235, 0.52))
	for a_g in 3:
		var stecca_g := _cyl(n, 0.004, 0.004, 0.13, ottone, Vector3(0.52, 3.235, 0.52))
		stecca_g.rotation.y = float(a_g) * PI / 3.0
		stecca_g.position += Vector3(cos(float(a_g) * PI / 3.0) * 0.072, 0,
				-sin(float(a_g) * PI / 3.0) * 0.072)
	_ball(n, 0.018, ottone, Vector3(0.52, 3.16, 0.52))
	# la lanterna sta a 3.2 m: perché faccia la guardia deve arrivare
	# GIÙ, alle gambe e alla scaletta, se no illumina solo se stessa.
	# Oltre 2.6 il tavolato del ballatoio va in bianco.
	var luce := OmniLight3D.new()
	luce.light_color = Color(1.0, 0.85, 0.62)
	luce.light_energy = 1.9
	luce.omni_range = 4.8
	luce.omni_attenuation = 1.1
	luce.position = Vector3(0.52, 3.235, 0.52)
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



## LA CAMPANA DELLA CASERMA. Sul suo palo tornito col basamento di
## pietra, il braccio che curva, il tettuccio rosso a pagodina e la
## campana TORNITA appesa al perno, col cordino di canapa che scende
## fino alla maniglietta: è quella che chiama tutti in piazza —
## l'unico allarme di questo villaggio è «venite a vedere».
static func _campana_caserma() -> Node3D:
	var n := Node3D.new()
	var wood := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	var ottone := _mat(OTTONE, OTTONE_SCURO, 5.0, 0.4)
	var rosso := _mat(POMPA_ROSSO, POMPA_ROSSO_SCURO, 3.0, 0.45)
	var canapa := _mat(Color("d9c49a"), Color("c0a978"), 7.0, 0.5)
	# il palo tornito sul suo sasso, con la fascia d'ottone e il pomello
	BUILDER.lathe(n, [Vector2(0.11, 0.0), Vector2(0.115, 0.02),
			Vector2(0.09, 0.045), Vector2(0.07, 0.06)],
			_mat(STONE, STONE_DARK, 4.0, 0.5), Vector3(-0.28, 0, 0))
	_cyl(n, 0.045, 0.06, 1.4, wood, Vector3(-0.28, 0.72, 0))
	_cyl(n, 0.052, 0.052, 0.028, ottone, Vector3(-0.28, 1.05, 0))
	_cyl(n, 0.05, 0.038, 0.03, wood, Vector3(-0.28, 1.43, 0))
	_ball(n, 0.055, wood, Vector3(-0.28, 1.47, 0))
	# il braccio che CURVA verso fuori e la saetta che gli sale incontro,
	# col bullone d'ottone dove si stringono la mano
	BUILDER.tube(n, [Vector3(-0.3, 1.30, 0), Vector3(-0.10, 1.315, 0),
			Vector3(0.10, 1.31, 0), Vector3(0.19, 1.29, 0)],
			[0.038, 0.034, 0.030, 0.026], wood)
	BUILDER.tube(n, [Vector3(-0.29, 1.0, 0), Vector3(-0.16, 1.10, 0),
			Vector3(-0.03, 1.22, 0), Vector3(0.02, 1.285, 0)],
			[0.024, 0.022, 0.020, 0.017], wood)
	_ball(n, 0.028, ottone, Vector3(0.02, 1.295, 0))
	# il tettuccio rosso a pagodina sopra la campana, con la puntina
	_cyl(n, 0.02, 0.02, 0.08, wood, Vector3(0.18, 1.335, 0))
	BUILDER.lathe(n, [Vector2(0.26, -0.02), Vector2(0.25, -0.011),
			Vector2(0.20, 0.013), Vector2(0.13, 0.046), Vector2(0.05, 0.076),
			Vector2(0.0, 0.09)], rosso, Vector3(0.18, 1.375, 0))
	_ball(n, 0.012, ottone, Vector3(0.18, 1.47, 0))
	# tutto quello che dondola sta sotto questo nodo: il perno visibile,
	# la corona, la campana tornita col labbro, il batacchio e la corda
	var giogo := Node3D.new()
	giogo.name = "Campana"
	giogo.position = Vector3(0.18, 1.27, 0)
	n.add_child(giogo)
	var perno := _cyl(giogo, 0.012, 0.012, 0.1, ottone, Vector3.ZERO)
	perno.rotation.x = PI * 0.5
	_cyl(giogo, 0.02, 0.026, 0.07, ottone, Vector3(0, -0.033, 0))
	BUILDER.lathe(giogo, [Vector2(0.150, -0.315), Vector2(0.163, -0.30),
			Vector2(0.155, -0.275), Vector2(0.128, -0.225), Vector2(0.108, -0.16),
			Vector2(0.098, -0.115), Vector2(0.086, -0.08), Vector2(0.055, -0.062),
			Vector2(0.02, -0.055)], ottone)
	_cyl(giogo, 0.008, 0.008, 0.1, _mat(OTTONE_SCURO, OTTONE_SCURO.darkened(0.3), 5.0, 0.4),
			Vector3(0, -0.29, 0))
	_ball(giogo, 0.032, _mat(OTTONE_SCURO, OTTONE_SCURO.darkened(0.3), 5.0, 0.4),
			Vector3(0, -0.345, 0))
	BUILDER.tube(giogo, [Vector3(0, -0.34, 0), Vector3(0.012, -0.52, 0),
			Vector3(0.005, -0.72, 0), Vector3(-0.008, -0.90, 0)],
			[0.008, 0.008, 0.008, 0.008], canapa, 16, 6)
	_cyl(giogo, 0.016, 0.02, 0.07, wood, Vector3(-0.008, -0.935, 0))
	_ball(giogo, 0.02, wood, Vector3(-0.008, -0.985, 0))
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


## GLI STIVALI, ricreati da zero: il pezzo più piccolo della caserma e
## quello che la racconta meglio. Ogni stivale è un corpo UNICO che
## curva nella caviglia fino alla punta tonda, con la suola a PIANTA DI
## PIEDE (tallone tondo, punta più larga, coi tasselli del battistrada
## sotto: si vedono solo quando uno è rovesciato, ed è lì che servono),
## il risvolto rosso arrotolato e l'interno scuro — sono vuoti,
## qualcuno se li è tolti. E OGNI POSA È DIVERSA: cinque disposizioni
## (la fila della sera, la margherita nel paio in fondo, il caduto, i
## tolti di corsa, la raggiera ad asciugare) più un soffio di caso su
## ogni stivale — due soglie non si somigliano mai.
static func _stivale(parent: Node3D) -> Node3D:
	var s := Node3D.new()
	parent.add_child(s)
	var gomma := _mat(GOMMA, GOMMA.darkened(0.25), 6.0, 0.35)
	var suola := _mat(GOMMA.darkened(0.3), GOMMA.darkened(0.45), 6.0, 0.3)
	var rosso := _mat(POMPA_ROSSO, POMPA_ROSSO_SCURO, 4.0, 0.45)
	var scuro := _mat(GOMMA.darkened(0.45), GOMMA.darkened(0.55), 5.0, 0.3)
	# il corpo unico: gambale, caviglia che piega, collo del piede, punta
	BUILDER.tube(s, [Vector3(0, 0.225, 0.008), Vector3(0, 0.13, 0.008),
			Vector3(0, 0.065, -0.012), Vector3(0, 0.05, -0.075),
			Vector3(0, 0.046, -0.115), Vector3(0, 0.05, -0.142)],
			[0.05, 0.05, 0.049, 0.05, 0.046, 0.028], gomma, 22, 12)
	# LA SUOLA SEGUE LA PIANTA DEL PIEDE: il giro del tallone, i fianchi
	# appena bombati, il giro largo della punta — un rettangolo stondato
	# è una ciabatta di legno, non uno stivale
	var pianta: Array = []
	for i in 7:
		var a := PI * float(i) / 6.0
		pianta.append(Vector2(cos(a) * 0.044, 0.055 + sin(a) * 0.046))
	for i in 9:
		var a2 := PI + PI * float(i) / 8.0
		pianta.append(Vector2(cos(a2) * 0.052, -0.098 + sin(a2) * 0.054))
	_prisma(s, pianta, 0.0, 0.026, suola)
	# i tasselli del battistrada, sotto
	for t_b: Array in [[-0.12, 0.042], [-0.075, 0.049], [-0.03, 0.048],
			[0.015, 0.045], [0.06, 0.039]]:
		_box(s, Vector3(float(t_b[1]) * 2.0 - 0.01, 0.007, 0.02), scuro,
				Vector3(0, -0.001, float(t_b[0])))
	# il risvolto rosso arrotolato, e l'interno scuro: lo stivale è VUOTO
	_cyl(s, 0.054, 0.056, 0.05, rosso, Vector3(0, 0.215, 0.008))
	var orlo := MeshInstance3D.new()
	var om := TorusMesh.new()
	om.inner_radius = 0.041
	om.outer_radius = 0.066
	orlo.mesh = om
	orlo.material_override = rosso
	orlo.position = Vector3(0, 0.242, 0.008)
	s.add_child(orlo)
	_cyl(s, 0.043, 0.043, 0.012, scuro, Vector3(0, 0.243, 0.008))
	# la linguetta dietro per tirarli su, e la fascia chiara sul TRATTO
	# DRITTO del gambale (alla piega tagliava il tubo di sbieco)
	_lastra(s, 0.013, 0.055, 0.006, 0.01, rosso,
			Vector3(0, 0.245, 0.066), Vector3(0.18, PI * 0.5, 0))
	_cyl(s, 0.0515, 0.0515, 0.016, _mat(CREAM, PLASTER_SHADE, 5.0, 0.3),
			Vector3(0, 0.145, 0.008))
	return s


static func _stivali() -> Node3D:
	var n := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.randomize()    # ogni soglia dispone gli stivali a modo suo
	# le disposizioni: [x, z, giro] per sei stivali; "fiore" e "caduto"
	# sono indici (o -1). La margherita NON sta mai in mezzo alla fila:
	# cresce nel paio in fondo, vicino al muro, dove l'acqua ristagna.
	var varianti: Array = [
		# la fila della sera: tutti a posto
		{"posti": [[-0.34, -0.01, 0.07], [-0.245, 0.01, -0.05],
				[-0.05, 0.02, 0.1], [0.05, -0.01, -0.07],
				[0.25, 0.0, 0.05], [0.345, 0.02, -0.04]],
			"fiore": -1, "caduto": -1},
		# la margherita nell'ultimo paio
		{"posti": [[-0.35, 0.0, 0.05], [-0.255, -0.02, -0.08],
				[-0.05, 0.01, 0.12], [0.045, 0.0, -0.05],
				[0.24, -0.01, 0.02], [0.35, 0.03, 0.18]],
			"fiore": 5, "caduto": -1},
		# uno è caduto, e nessuno si prende la briga di raddrizzarlo
		{"posti": [[-0.345, -0.005, 0.07], [-0.25, 0.01, -0.05],
				[-0.05, 0.005, 0.14], [0.05, -0.012, -0.09],
				[0.25, 0.0, 0.04], [0.4, 0.045, 0.4]],
			"fiore": -1, "caduto": 5},
		# tolti DI CORSA: sparsi dove capitava, uno è volato in là
		{"posti": [[-0.36, 0.06, 0.5], [-0.19, -0.1, -0.45],
				[0.0, 0.12, 0.85], [0.09, -0.05, -0.2],
				[0.29, 0.03, 0.3], [0.44, 0.15, -0.7]],
			"fiore": -1, "caduto": 2},
		# la raggiera: messi in tondo ad asciugare al sole
		{"posti": [], "fiore": -1, "caduto": -1, "tondo": true},
	]
	var scelta: Dictionary = varianti[rng.randi_range(0, varianti.size() - 1)]
	var posti: Array = scelta["posti"]
	if bool(scelta.get("tondo", false)):
		for k in 6:
			var a := TAU / 6.0 * float(k) + 0.26
			posti.append([cos(a) * 0.27, sin(a) * 0.27,
					atan2(-cos(a), -sin(a))])
	for i in 6:
		var s := _stivale(n)
		var p_s: Array = posti[i]
		s.position = Vector3(float(p_s[0]) + rng.randf_range(-0.012, 0.012), 0,
				float(p_s[1]) + rng.randf_range(-0.012, 0.012))
		s.rotation.y = float(p_s[2]) + rng.randf_range(-0.07, 0.07)
		if i == int(scelta.get("caduto", -1)):
			s.position.y = 0.055
			s.rotation.z = -1.52
			s.rotation.y += rng.randf_range(-0.3, 0.3)
		elif i == int(scelta.get("fiore", -1)):
			var verde := _mat(LEAF, LEAF_DARK, 6.0, 0.55)
			var stelo := _cyl(s, 0.006, 0.008, 0.16, verde, Vector3(0.012, 0.3, 0.01))
			stelo.rotation.z = -0.12
			_ball(s, 0.02, verde, Vector3(0.05, 0.33, 0.012), Vector3(1.3, 0.4, 0.9))
			for k2 in 5:
				var a2 := TAU / 5.0 * float(k2)
				_ball(s, 0.016, _mat(Color.WHITE, CREAM, 5.0, 0.25),
						Vector3(0.03 + cos(a2) * 0.021, 0.385, 0.008 + sin(a2) * 0.021),
						Vector3(1.0, 0.5, 1.0))
			_ball(s, 0.013, _mat(Color("ffd76e"), Color("eec254"), 5.0, 0.3),
					Vector3(0.03, 0.392, 0.008))
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


## IL FARO DELLA CASERMA: un GIROFARO vero, non una lanterna da
## giardino (quella è stata abbattuta su ordine dell'autore). La forma
## viene dai fari d'emergenza industriali: la piastra imbullonata a
## terra, la colonna d'acciaio verniciata con lo stivale rosso e il
## fusto PULITO (l'autore ha fatto togliere pioli, gussets e tubo
## portacavi: niente ferraglia sporgente), il bicchiere d'ottone con la
## fascetta a tre viti — e sopra la calotta rossa a COSTE FRESNEL,
## tornita con le coste nel profilo, che gira col fascio. Il contratto
## resta quello di sempre: la testa si chiama Girella, il giro lo dà un
## AnimationPlayer in loop (test_caserma._test_faro_gira).
static func _faro_caserma() -> Node3D:
	var n := Node3D.new()
	var crema := _mat(CREAM, PLASTER_SHADE, 4.0, 0.4)
	var rosso := _mat(POMPA_ROSSO, POMPA_ROSSO_SCURO, 4.0, 0.45)
	var ottone := _mat(OTTONE, OTTONE_SCURO, 5.0, 0.4)
	var metallo := _mat(METAL, METAL.darkened(0.25), 5.0, 0.4)

	# ---- LA PIASTRA imbullonata, coi quattro bulloni e i gussets ----
	_lastra(n, 0.165, 0.33, 0.05, 0.028, metallo, Vector3(0, 0.014, 0),
			Vector3(0, 0, PI * 0.5))
	for bx: float in [-1.0, 1.0]:
		for bz: float in [-1.0, 1.0]:
			_cyl(n, 0.016, 0.016, 0.014, ottone,
					Vector3(bx * 0.125, 0.033, bz * 0.125))
			_ball(n, 0.013, ottone, Vector3(bx * 0.125, 0.041, bz * 0.125),
					Vector3(1, 0.6, 1))
	# ---- LA COLONNA: stivale rosso, fusto crema, collare in cima ----
	BUILDER.lathe(n, [Vector2(0.001, 0.0), Vector2(0.088, 0.008),
			Vector2(0.078, 0.06), Vector2(0.062, 0.14),
			Vector2(0.056, 0.20), Vector2(0.058, 0.215),
			Vector2(0.001, 0.218)], rosso, Vector3(0, 0.028, 0))
	BUILDER.lathe(n, [Vector2(0.001, 0.0), Vector2(0.050, 0.0),
			Vector2(0.044, 0.40), Vector2(0.038, 0.90),
			Vector2(0.036, 1.04), Vector2(0.042, 1.06),
			Vector2(0.042, 1.09), Vector2(0.036, 1.10),
			Vector2(0.001, 1.105)], crema, Vector3(0, 0.24, 0))

	# ---- IL BICCHIERE: la base d'ottone con la fascetta a tre viti ----
	BUILDER.lathe(n, [Vector2(0.001, 0.0), Vector2(0.052, 0.0),
			Vector2(0.088, 0.012), Vector2(0.092, 0.032),
			Vector2(0.092, 0.070), Vector2(0.084, 0.082)], ottone,
			Vector3(0, 1.345, 0))
	_cordolo(n, _super_anello(0.094, 0.094, 1.0, 0.0, 36), 0.008, ottone,
			Vector3(0, 1.408, 0))
	for vt in 3:
		var va := float(vt) * TAU / 3.0
		_ball(n, 0.010, metallo,
				Vector3(sin(va) * 0.099, 1.408, cos(va) * 0.099))

	# ---- LA TESTA CHE GIRA: la calotta rossa a coste Fresnel ----
	var testa := Node3D.new()
	testa.name = "Girella"
	testa.position = Vector3(0, 1.428, 0)
	n.add_child(testa)
	# le coste sono NEL profilo del tornio: quattro gonfiori regolari
	# lungo la salita — è la rigatura della lente a dire «girofaro»
	BUILDER.lathe(testa, [Vector2(0.001, 0.0), Vector2(0.078, 0.0),
			Vector2(0.080, 0.010), Vector2(0.083, 0.020), Vector2(0.080, 0.030),
			Vector2(0.083, 0.043), Vector2(0.080, 0.056),
			Vector2(0.083, 0.069), Vector2(0.080, 0.082),
			Vector2(0.082, 0.095), Vector2(0.078, 0.108),
			Vector2(0.070, 0.128), Vector2(0.052, 0.148),
			Vector2(0.029, 0.163), Vector2(0.001, 0.170)],
			_glow(POMPA_ROSSO, POMPA_ROSSO_SCURO, 0.45))
	# il riflettore dentro la calotta: gli spigoli del box (il conto si
	# fa su di LORO) stanno a sqrt(0.060^2 + 0.040^2) = 0.072, sotto il
	# raggio minimo delle coste (0.076) per tutta l'altezza del box
	_box(testa, Vector3(0.04, 0.085, 0.08), _glow(CREAM, Color("ffd9a8"), 1.6),
			Vector3(0.040, 0.062, 0))
	# il cappellotto d'ottone col pomellino di sfiato
	_cyl(testa, 0.021, 0.024, 0.010, ottone, Vector3(0, 0.170, 0))
	_ball(testa, 0.0095, ottone, Vector3(0, 0.180, 0))
	# IL FASCIO. Puntato all'ORIZZONTALE non toccava niente e non si
	# vedeva affatto: la testa sta a 1.6 m, il cono si apre di 13° per
	# lato, e il bordo basso avrebbe incontrato il prato a 6.9 m — fuori
	# dalla portata di 6.5. Un girofaro che gira per nessuno.
	# Inclinato di 34° in giù il fascio APPOGGIA per terra e girando
	# disegna la sua fetta di luce sull'erba: è quello che fa capire, da
	# lontano, che la caserma è sveglia. L'asse tocca a 2.5 m e il cono
	# spazza da 1.5 a 4.3: comincia VICINO al palo — a 20° partiva a
	# quattro metri e attorno al faro restava il buio, che è il difetto di
	# prima con un altro numero. La portata sale a 8 perché la coda del
	# cono non venga tagliata a metà.
	var fascio := SpotLight3D.new()
	fascio.light_color = Color(1.0, 0.74, 0.58)
	fascio.light_energy = 4.5
	fascio.spot_range = 8.0
	fascio.spot_angle = 26.0
	fascio.spot_angle_attenuation = 1.2
	fascio.spot_attenuation = 1.1
	fascio.shadow_enabled = false
	fascio.position = Vector3(0.06, 0.06, 0)
	fascio.rotation = Vector3(-0.60, -PI * 0.5, 0)
	testa.add_child(fascio)
	# e il faro illumina SE STESSO: la calotta rossa buttava luce zero
	# sull'ottone sotto e sul fusto, e un girofaro con il proprio palo al
	# buio è una lampadina appesa al niente. Corta, calda, appena rosata.
	var alone_f := OmniLight3D.new()
	alone_f.light_color = Color(1.0, 0.66, 0.54)
	alone_f.light_energy = 1.3
	alone_f.omni_range = 2.4
	alone_f.omni_attenuation = 1.25
	alone_f.shadow_enabled = false
	alone_f.position = Vector3(0, 0.02, 0)
	testa.add_child(alone_f)
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


## LA CUCCIA DELLA CASERMA, rifatta. Prima era una scatola bianca con
## due lastre a coltello appoggiate sopra e un buco nero: il tetto non
## aveva frontoni (dai tre quarti si vedeva il TRIANGOLO VUOTO fra le
## falde), niente spessore, niente gronda. Adesso è una casetta vera:
## pedana di legno coi piedini, timpani pieni (_prisma), falde con lo
## spessore, la gronda che sporge e i corsi delle tegole, il colmo
## tornito coi pomelli d'ottone, l'arco di legno intorno all'ingresso,
## l'osso dipinto sul timpano, una copertina che sbuca dal buio — e la
## ciotola d'ottone TORNITA, con le crocchette dentro. Nessun cane, per
## ora: ma adesso si capisce che qualcuno lo sta aspettando.
static func _cuccia_caserma() -> Node3D:
	var n := Node3D.new()
	var rosso := _mat(POMPA_ROSSO, POMPA_ROSSO_SCURO, 3.5, 0.45)
	var rosso_scuro := _mat(POMPA_ROSSO_SCURO, POMPA_ROSSO_SCURO.darkened(0.18), 4.0, 0.4)
	var crema := _mat(CREAM, PLASTER_SHADE, 4.0, 0.4)
	var wood := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	var wood_scuro := _mat(WOOD_DARK, Color("6d4f31"), 4.0, 0.45)
	var ottone := _mat(OTTONE, OTTONE_SCURO, 5.0, 0.4)
	var buio := _mat(GOMMA.lightened(0.05), GOMMA, 5.0, 0.3)

	# ---- LA PEDANA: rialzata da terra sui piedini, come le cucce vere ----
	_lastra(n, 0.30, 0.66, 0.045, 0.05, wood, Vector3(0, 0.062, 0),
			Vector3(0, 0, PI * 0.5))
	for px: float in [-1.0, 1.0]:
		for pz: float in [-1.0, 1.0]:
			_cyl(n, 0.032, 0.036, 0.04, wood_scuro,
					Vector3(px * 0.27, 0.02, pz * 0.24))

	# ---- IL CORPO: intonaco, montanti d'angolo e battiscopa ----
	_box(n, Vector3(0.60, 0.415, 0.52), crema, Vector3(0, 0.2925, 0))
	for cx: float in [-1.0, 1.0]:
		for cz: float in [-1.0, 1.0]:
			_box(n, Vector3(0.05, 0.425, 0.05), wood,
					Vector3(cx * 0.283, 0.297, cz * 0.243))
	for bz: float in [-1.0, 1.0]:
		_box(n, Vector3(0.62, 0.035, 0.02), wood_scuro,
				Vector3(0, 0.105, bz * 0.256))
	for bx: float in [-1.0, 1.0]:
		_box(n, Vector3(0.02, 0.035, 0.54), wood_scuro,
				Vector3(bx * 0.296, 0.105, 0))

	# ---- I TIMPANI: triangoli PIENI, non aria fra le falde ----
	# (_prisma estrude in Y: punti in (x, -y) e mezzo giro in X)
	var tri: Array = [Vector2(-0.30, -0.50), Vector2(0, -0.69), Vector2(0.30, -0.50)]
	for gz: float in [-1.0, 1.0]:
		var timpano := _prisma(n, tri, 0.0, 0.045, crema)
		timpano.rotation.x = PI * 0.5
		timpano.position.z = gz * 0.26 - 0.0225
	# la trave che il timpano appoggia sul muro
	_box(n, Vector3(0.64, 0.045, 0.56), wood, Vector3(0, 0.492, 0))

	# ---- LE FALDE: spessore, gronda, corsi di tegole, bordi di legno ----
	var theta := atan2(0.19, 0.30)
	var lung := 0.44
	for sx: float in [-1.0, 1.0]:
		var perno := Node3D.new()
		# il centro della falda: a 0.21 di strada dal colmo, LUNGO la falda
		perno.position = Vector3(sx * 0.21 * cos(theta),
				0.69 - 0.21 * sin(theta), 0)
		perno.rotation.z = -sx * (PI * 0.5 + theta)
		n.add_child(perno)
		_lastra(perno, 0.33, lung, 0.02, 0.035, rosso, Vector3.ZERO)
		# i due corsi orizzontali delle tegole, SOLO sulla faccia di fuori:
		# messi su entrambe le facce si vedevano galleggiare sotto la
		# gronda. Il lato di fuori dipende dal segno della falda (-sx).
		for corso: float in [-0.065, 0.085]:
			_box(perno, Vector3(0.008, 0.016, 0.64), rosso_scuro,
					Vector3(-sx * 0.0215, corso, 0))
		# i bordi di legno sul fronte e sul retro della falda
		for gz2: float in [-1.0, 1.0]:
			_box(perno, Vector3(0.048, lung - 0.02, 0.026), wood,
					Vector3(0, 0, gz2 * 0.325))

	# ---- IL COLMO: tornito, coi pomelli d'ottone alle punte ----
	var colmo := BUILDER.lathe(n, [Vector2(0.001, 0.0), Vector2(0.023, 0.005),
			Vector2(0.028, 0.28), Vector2(0.023, 0.555),
			Vector2(0.001, 0.56)], wood, Vector3(0, 0.684, -0.28))
	colmo.rotation.x = PI * 0.5
	# il cappello a rombo sull'apice dei timpani: copre la tacca fra le
	# falde (da cui, di fronte, si vedeva la punta del colmo come una
	# candela accesa) e porta il pomello d'ottone
	for fz: float in [-1.0, 1.0]:
		var rombo := _box(n, Vector3(0.118, 0.118, 0.022), wood,
				Vector3(0, 0.664, fz * 0.344))
		rombo.rotation.z = PI * 0.25
		_ball(n, 0.018, ottone, Vector3(0, 0.682, fz * 0.360))
	# l'oblò d'ottone sui fianchi: il tondino di buio e l'anello lucido
	for ox: float in [-1.0, 1.0]:
		var vetro_blo := _cyl(n, 0.052, 0.052, 0.014, buio,
				Vector3(ox * 0.298, 0.335, 0.05))
		vetro_blo.rotation.z = PI * 0.5
		var anello_blo := _cordolo(n, _super_anello(0.056, 0.056, 1.0, 0.0, 32),
				0.011, ottone, Vector3(ox * 0.306, 0.335, 0.05))
		anello_blo.rotation.z = PI * 0.5

	# ---- L'INGRESSO: il buio, l'arco di legno, la soglia ----
	# Il buio si RICAVA dal telaio, mai il contrario: la corona del tubo
	# sta a 0.44 col raggio 0.019 (filo interno 0.421), e il primo buio
	# (raggio 0.13, centro 0.335) arrivava a 0.465 — sbucava SOPRA il
	# legno. Ora l'arco nero finisce a 0.419, due millimetri sotto il
	# filo, e i fianchi lasciano un dito di stipite in vista.
	_box(n, Vector3(0.238, 0.215, 0.014), buio, Vector3(0, 0.1925, -0.262))
	var arco := _cyl(n, 0.119, 0.119, 0.014, buio, Vector3(0, 0.30, -0.262))
	arco.rotation.x = PI * 0.5
	BUILDER.tube(n, [Vector3(-0.148, 0.085, -0.266), Vector3(-0.150, 0.20, -0.266),
			Vector3(-0.140, 0.30, -0.266), Vector3(-0.092, 0.405, -0.266),
			Vector3(0, 0.44, -0.266), Vector3(0.092, 0.405, -0.266),
			Vector3(0.140, 0.30, -0.266), Vector3(0.150, 0.20, -0.266),
			Vector3(0.148, 0.085, -0.266)],
			[0.019, 0.019, 0.019, 0.019, 0.019, 0.019, 0.019, 0.019, 0.019],
			wood, 24, 10)
	var soglia := _cyl(n, 0.018, 0.018, 0.30, wood_scuro, Vector3(0, 0.088, -0.272))
	soglia.rotation.z = PI * 0.5

	# ---- L'OSSO dipinto sul timpano ----
	var osso := Node3D.new()
	osso.position = Vector3(0, 0.548, -0.286)
	osso.rotation.z = 0.06
	n.add_child(osso)
	var bianco := _mat(SEGNALE_BIANCO, Color("e9e2d2"), 5.0, 0.3)
	_box(osso, Vector3(0.068, 0.018, 0.012), bianco, Vector3.ZERO)
	for ox: float in [-1.0, 1.0]:
		for oy: float in [-1.0, 1.0]:
			_ball(osso, 0.0145, bianco, Vector3(ox * 0.036, oy * 0.0105, 0))

	# ---- LA CIOTOLA: tornita, col bordo arrotolato e le crocchette ----
	# Davanti alla pedana, staccata del proprio raggio più un dito d'aria:
	# la posa si RICAVA (pedana z/2 = 0.30), mai piantata nell'intonaco.
	var ciotola := Node3D.new()
	ciotola.position = Vector3(0.20, 0.0, -0.30 - 0.095 - 0.02)
	n.add_child(ciotola)
	BUILDER.lathe(ciotola, [Vector2(0.001, 0.0), Vector2(0.052, 0.0),
			Vector2(0.068, 0.006), Vector2(0.080, 0.020),
			Vector2(0.089, 0.042), Vector2(0.094, 0.052),
			Vector2(0.088, 0.058), Vector2(0.079, 0.052),
			Vector2(0.074, 0.040)], ottone)
	_cyl(ciotola, 0.070, 0.070, 0.006, _mat(Color("6b4a33"), Color("523823"), 5.0, 0.35),
			Vector3(0, 0.040, 0))
	var rngc := RandomNumberGenerator.new()
	rngc.seed = 20_260_808
	for k in 6:
		var ang := TAU * float(k) / 6.0 + rngc.randf_range(-0.3, 0.3)
		var rad := rngc.randf_range(0.012, 0.048)
		_ball(ciotola, rngc.randf_range(0.010, 0.0135),
				_mat(Color("9a6f47"), Color("7d5735"), 5.0, 0.4),
				Vector3(cos(ang) * rad, 0.047, sin(ang) * rad))
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


## Il contorno di un pianoforte a CODA, nello stesso verso del vecchio
## profilo. Il lato dritto davanti e' la tastiera; la S del fianco destro
## e la coda sono UNA Bezier cubica campionata fitta (22 punti): le
## faccette dure del profilo a mano erano il motivo per cui la cassa
## leggeva come un diamante sbozzato.
static func _profilo_coda(lung: float, larg: float) -> Array:
	var out: Array = []
	out.append(Vector2(-larg * 0.5, 0.0))          # spigolo tastiera sinistro
	out.append(Vector2(larg * 0.5, 0.0))           # spigolo tastiera destro
	out.append(Vector2(larg * 0.5, -lung * 0.30))  # il fianco destro, dritto
	# LA CURVA: dal fianco destro, giro largo della coda, fino in fondo
	# al lato sinistro (la vertebra dritta del coperchio)
	var p0 := Vector2(larg * 0.5, -lung * 0.30)
	var p1 := Vector2(larg * 0.5, -lung * 0.82)
	var p2 := Vector2(larg * 0.10, -lung * 0.84)
	var p3 := Vector2(-larg * 0.5, -lung * 0.60)
	for i in range(1, 22):
		var t := float(i) / 21.0
		var u := 1.0 - t
		out.append(p0 * (u * u * u) + p1 * (3.0 * u * u * t)
				+ p2 * (3.0 * u * t * t) + p3 * (t * t * t))
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

	# LA CORDIERA: piastra dorata, il SOMIERE scuro coi piroli, e corde
	# di bronzo abbastanza spesse da leggersi sotto il coperchio
	_prisma(n, interno, y - 0.035, 0.012, oro)
	var bronzo := _mat(Color("9a7a44"), Color("7c6034"), 8.0, 0.3)
	var somiere := _mat(Color("3a3136"), Color("282226"), 10.0, 0.25)
	_box(n, Vector3(larg * 0.80, 0.014, 0.05), somiere, Vector3(0, y - 0.020, -0.075))
	for i in 12:
		var t := float(i) / 11.0
		var x := -larg * 0.38 + t * larg * 0.76
		_cyl(n, 0.004, 0.004, 0.014, oro, Vector3(x, y - 0.010, -0.075))
		# le corde CONVERGONO verso la coda, come le vere — ed e' anche
		# il modo di restare DENTRO la sagoma che si stringe (dritte,
		# le laterali sforavano il fianco come aghi)
		var ex := x * 0.22
		var ez := -lung * (0.68 - 0.26 * pow(absf(t - 0.5) * 2.0, 1.6))
		var dx := ex - x
		var dz := ez + 0.10
		var corda := _box(n, Vector3(0.0068, 0.006, sqrt(dx * dx + dz * dz)),
				bronzo, Vector3((x + ex) * 0.5, y - 0.026, (-0.10 + ez) * 0.5))
		corda.rotation.y = atan2(dx, dz)
	# i due ponticelli, di legno scuro come i veri
	for sz: float in [-0.24, -0.46]:
		_box(n, Vector3(larg * 0.72, 0.015, 0.020), somiere, Vector3(0, y - 0.020, sz))

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
	# i GUANCIALI ai capi della tastiera, il frontalino e il feltro
	for gx: float in [-larg * 0.465, larg * 0.465]:
		_box(n, Vector3(larg * 0.055, 0.034, 0.13), lacca, Vector3(gx, y + 0.012, 0.062))
	_box(n, Vector3(larg, 0.05, 0.022), lacca, Vector3(0, y - 0.012, 0.125))
	_box(n, Vector3(larg * 0.88, 0.006, 0.010), feltro, Vector3(0, y + 0.020, 0.004))

	# IL COPERCHIO, APERTO, e la sua asta: e' questo che dice «suona»
	var cop := Node3D.new()
	cop.position = Vector3(-larg * 0.5, y, 0.0)
	cop.rotation.z = 0.62
	n.add_child(cop)
	var sopra: Array = []
	for p in prof:
		# il coperchio parte DIETRO la tastiera (un coperchio che copre
		# i tasti e' un tavolo): il bordo davanti si ferma a -0.05
		var pv := p as Vector2
		sopra.append(Vector2(pv.x + larg * 0.5, minf(pv.y, -lung * 0.05) + lung * 0.05))
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

	# LE TRE GAMBE: capitello, fusto rastremato, collarino d'ottone e
	# la ROTELLINA mezza affondata — non un tappo d'oro
	for p3: Vector2 in [Vector2(-larg * 0.40, 0.02), Vector2(larg * 0.40, 0.02),
			Vector2(0.0, -lung * 0.62)]:
		_box(n, Vector3(0.062, 0.030, 0.062), lacca, Vector3(p3.x, y - h - 0.012, p3.y))
		_cyl(n, 0.024, 0.036, y - h - 0.05, lacca,
				Vector3(p3.x, (y - h) * 0.5 - 0.012, p3.y))
		_cyl(n, 0.028, 0.028, 0.014, oro, Vector3(p3.x, 0.045, p3.y))
		_ball(n, 0.020, oro, Vector3(p3.x, 0.016, p3.y))

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
	# lo SPARTITO, appoggiato al leggio con la stessa inclinazione
	var spart := _lastra(n, 0.052, 0.085, 0.008, 0.004,
			_mat(CREAM, Color("efe2ca"), 6.0, 0.2),
			Vector3(0.02, y + 0.105, -0.047), Vector3(0, PI * 0.5, 0))
	spart.rotation.x = -0.28

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
	var tavola_p := _prisma(panca, _rrect_xz(0.38, 0.17, 0.030), 0.272, 0.028, lacca)
	tavola_p.position = Vector3.ZERO
	var cusc := _prisma(panca, _rrect_xz(0.34, 0.14, 0.035), 0.285, 0.030, feltro)
	cusc.position = Vector3.ZERO
	for bx: float in [-0.08, 0.08]:
		_ball(panca, 0.008, lacca, Vector3(bx, 0.316, 0), Vector3(1, 0.4, 1))
	for px: float in [-0.15, 0.15]:
		for pz: float in [-0.055, 0.055]:
			_cyl(panca, 0.012, 0.017, 0.272, lacca, Vector3(px, 0.136, pz))
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
	# L'avvertimento è VERO, ed è stato rimisurato rendendo TRE campate
	# affiancate: a 1.3/4.0 la prima conchiglia va in bianco davvero. Si
	# alza appena e si ACCORCIA la portata — è la sovrapposizione a
	# bruciare, non l'energia — così la volta prende il caldo e il
	# pannello resta leggibile anche in fila.
	luce.light_energy = 1.1
	luce.omni_range = 3.6
	luce.omni_attenuation = 1.15
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
	# LA LAVAGNETTA DEI GUSTI, ricreata da zero: il cavalletto A LIBRO
	# fuori dalla porta, e stavolta da falegname — montanti stondati coi
	# pomelli torniti, la crestina ad ARCO sopra ogni anta, la perlina
	# chiara che incornicia l'ardesia, le cerniere con le bandelle, la
	# corda continua che si affloscia, il vassoio con le guance e i gessi
	# colorati nella polvere. E il gesso non scrive soltanto: DISEGNA —
	# la cornicetta a mano libera attorno al menù, la tazzina che fuma,
	# il cuore rosa, e sul retro un sole scarabocchiato da qualcuno che
	# aspettava. È la lavagna PICCOLA: quella grande è _blackboard.
	#
	# La SCRITTURA resta il sistema di sempre (_riga_gesso): parole di
	# lunghezze diverse, storte, coi prezzi staccati e il margine
	# sfrangiato — quella era già viva, ed era l'anima del pezzo.
	var n := Node3D.new()
	var legno := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	var legno_chiaro := _mat(WOOD_PALE, WOOD, 3.5, 0.5)
	var ottone := _mat(OTTONE, OTTONE_SCURO, 5.0, 0.4)
	var canapa := _mat(Color("d9c49a"), Color("c0a978"), 7.0, 0.5)
	var ardesia := _mat(Color("2f3a33"), Color("26302a"), 5.5, 0.3)
	var gesso := _mat(Color("fdf6e8"), Color("ece2cf"), 6.0, 0.22)
	var gesso_rosa := _mat(PINK, PINK_DEEP, 6.0, 0.3)
	# l'alone di ieri è appena più chiaro dell'ardesia, non bianco: un
	# grigio chiaro pieno non è «cancellato», è una toppa
	var gesso_tenue := _mat(Color("55605a"), Color("48524d"), 7.0, 0.35)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260729    # sempre la stessa: due lavagnette non si scrivono da sole in modo diverso

	# --- la cerniera in cima: canotto di legno, bandelle d'ottone e
	# pomellini alle estremità ---
	var cerniera := Vector3(0, 0.94, 0)
	_cyl(n, 0.018, 0.018, 0.5, legno, cerniera).rotation.z = PI * 0.5
	for bx: float in [-0.16, 0.16]:
		var bandella := _cyl(n, 0.024, 0.024, 0.05, ottone, cerniera + Vector3(bx, 0, 0))
		bandella.rotation.z = PI * 0.5
	for cx: float in [-0.26, 0.26]:
		_ball(n, 0.026, ottone, cerniera + Vector3(cx, 0, 0), Vector3(0.7, 1, 1))

	# --- i due pannelli che si aprono a libro ---
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
		var fronte := lato * -0.034
		# i montanti stondati col pomello tornito in cima
		for sx: float in [-0.255, 0.255]:
			_lastra(perno, 0.026, 0.92, 0.012, 0.05, legno, Vector3(sx, -0.45, 0),
					Vector3(0, PI * 0.5, 0))
			_cyl(perno, 0.014, 0.02, 0.025, legno, Vector3(sx, 0.025, 0))
			_ball(perno, 0.024, legno, Vector3(sx, 0.05, 0))
		# le traverse alta e bassa, e la CRESTINA ad arco che corona
		_lastra(perno, 0.24, 0.05, 0.018, 0.046, legno, Vector3(0, -0.025, 0),
				Vector3(0, PI * 0.5, 0))
		_lastra(perno, 0.24, 0.06, 0.018, 0.046, legno, Vector3(0, -0.87, 0),
				Vector3(0, PI * 0.5, 0))
		BUILDER.tube(perno, [Vector3(-0.24, 0.005, 0), Vector3(0, 0.055, 0),
				Vector3(0.24, 0.005, 0)], [0.018, 0.021, 0.018], legno, 14, 8)
		# l'ardesia incassata, con la PERLINA chiara che la incornicia
		_box(perno, Vector3(0.47, 0.8, 0.02), ardesia,
				Vector3(0, -0.45, lato * -0.02))
		for pl: float in [-0.243, 0.243]:
			_cyl(perno, 0.008, 0.008, 0.76, legno_chiaro, Vector3(pl, -0.45, fronte))
		for py: float in [-0.075, -0.825]:
			var perlina := _cyl(perno, 0.008, 0.008, 0.47, legno_chiaro,
					Vector3(0, py, fronte))
			perlina.rotation.z = PI * 0.5
		# le gambe tornite che continuano i montanti, coi piedini larghi
		for sx2: float in [-0.245, 0.245]:
			var g := _cyl(perno, 0.02, 0.026, 0.1, legno, Vector3(sx2, -0.945, 0))
			g.rotation.z = -sx2 * 0.3
			_cyl(perno, 0.028, 0.032, 0.022, legno,
					Vector3(sx2 - sx2 * 0.062, -0.99, 0))

	# LA CORDA VA DA UN'ANTA ALL'ALTRA, cioè lungo Z: un cavalletto a
	# libro si apre avanti-indietro. Alla quota 0.25 le ante stanno a
	# ±0.169 (0.710 di anta per sin 0.24). Ed è UNA CORDA CONTINUA che si
	# affloscia, con le maglie d'ottone agli attacchi: la catenella di
	# palline staccate, di profilo, era una fila di sassolini a mezz'aria.
	BUILDER.tube(n, [Vector3(0, 0.25, -0.169), Vector3(0, 0.217, -0.06),
			Vector3(0, 0.217, 0.06), Vector3(0, 0.25, 0.169)],
			[0.0075, 0.0075, 0.0075, 0.0075], canapa, 18, 6)
	for za: float in [-0.169, 0.169]:
		_ball(n, 0.013, ottone, Vector3(0, 0.252, za), Vector3(0.7, 1.0, 1.0))

	# --- il fronte scritto. Tutto dentro l'anta, così segue la sua
	# inclinazione. Prima la CORNICETTA tirata a mano libera (coi vuoti
	# agli angoli: nessuno chiude i quattro tratti), poi il menù ---
	var anta: Node3D = n.get_node(^"Anta")
	var zs := -0.036          # il gesso sta DAVANTI all'ardesia
	for tr_c: Array in [[0.0, -0.095, 0.37, true], [0.0, -0.755, 0.34, true],
			[0.207, -0.425, 0.58, false], [-0.207, -0.425, 0.6, false]]:
		var cornice: MeshInstance3D
		if bool(tr_c[3]):
			cornice = _box(anta, Vector3(float(tr_c[2]), 0.009, 0.007), gesso,
					Vector3(float(tr_c[0]), float(tr_c[1]), zs))
		else:
			cornice = _box(anta, Vector3(0.009, float(tr_c[2]), 0.007), gesso,
					Vector3(float(tr_c[0]), float(tr_c[1]), zs))
		cornice.rotation.z = rng.randf_range(-0.025, 0.025)
	# il titolo, più grosso, e la sottolineatura tirata di fretta
	_riga_gesso(anta, gesso, 0.16, -0.16, [0.075, 0.055, 0.05], zs, 0.03, rng)
	var sotto := _box(anta, Vector3(0.215, 0.012, 0.008), gesso,
			Vector3(0.055, -0.205, zs))
	sotto.rotation.z = -0.02
	# tre righe di menù: parole vere, margine destro sfrangiato, e su due
	# righe il prezzo staccato in fondo
	var righe := [[0.062, 0.038, 0.052], [0.045, 0.07], [0.058, 0.034, 0.046]]
	for i in righe.size():
		var y := -0.3 - 0.105 * float(i)
		var fine_r := _riga_gesso(anta, gesso, 0.19, y, righe[i], zs, 0.019, rng)
		if i != 1:
			_riga_gesso(anta, gesso, minf(fine_r - 0.05, -0.1), y,
					[0.024, 0.02], zs, 0.019, rng)
	# l'ALONE di quello che c'era scritto ieri, mezzo cancellato: è il
	# dettaglio che rende la lavagna usata invece che nuova. Tre macchie
	# sovrapposte e appena storte — una sola era un rettangolo incollato.
	for m in [[0.2, 0.05, -0.02, 0.02], [0.13, 0.038, 0.08, -0.035],
			[0.09, 0.03, -0.1, 0.015]]:
		var macchia := _box(anta, Vector3(float(m[0]), float(m[1]), 0.005),
				gesso_tenue, Vector3(float(m[2]), -0.605, zs + 0.003))
		macchia.rotation.z = float(m[3])
	# LA TAZZINA DISEGNATA COL GESSO che fuma, in basso a sinistra di chi
	# guarda (x positiva): il gesso non sa scrivere soltanto
	var tazza_g := MeshInstance3D.new()
	var tz := TorusMesh.new()
	tz.inner_radius = 0.024
	tz.outer_radius = 0.034
	tazza_g.mesh = tz
	tazza_g.material_override = gesso
	tazza_g.position = Vector3(0.15, -0.685, zs)
	tazza_g.rotation.x = PI * 0.5
	anta.add_child(tazza_g)
	var manico_g := MeshInstance3D.new()
	var mz := TorusMesh.new()
	mz.inner_radius = 0.008
	mz.outer_radius = 0.015
	manico_g.mesh = mz
	manico_g.material_override = gesso
	manico_g.position = Vector3(0.108, -0.685, zs)
	manico_g.rotation.x = PI * 0.5
	anta.add_child(manico_g)
	var piattino_g := _box(anta, Vector3(0.1, 0.008, 0.006), gesso,
			Vector3(0.15, -0.725, zs))
	piattino_g.rotation.z = 0.015
	# le due volute di fumo salgono PARALLELE e ondulano insieme: due
	# curve specchiate si incrociavano e sopra la tazzina compariva una X
	for fv: float in [0.138, 0.164]:
		BUILDER.tube(anta, [Vector3(fv, -0.645, zs),
				Vector3(fv + 0.011, -0.622, zs),
				Vector3(fv - 0.004, -0.598, zs)],
				[0.0035, 0.0035, 0.0035], gesso, 10, 5)
	# il cuore col gesso ROSA nell'angolo (a destra di chi guarda =
	# x locale negativa), due palline e una punta
	_ball(anta, 0.018, gesso_rosa, Vector3(-0.155, -0.68, zs), Vector3(1, 1, 0.35))
	_ball(anta, 0.018, gesso_rosa, Vector3(-0.12, -0.68, zs), Vector3(1, 1, 0.35))
	var punta := _box(anta, Vector3(0.031, 0.031, 0.006), gesso_rosa,
			Vector3(-0.1375, -0.707, zs))
	punta.rotation.z = PI * 0.25

	# --- la bacinella dei gessetti: fondo SCURO (su legno chiaro un
	# gessetto bianco non si vede), le guance ai lati, il labbro a
	# tondino, i gessi nella loro polvere e il cancellino stondato ---
	_box(anta, Vector3(0.44, 0.022, 0.055), _mat(WOOD_DARK, Color("5c4030"), 4.0, 0.45),
			Vector3(0, -0.815, -0.045))
	for gs: float in [-0.222, 0.222]:
		_lastra(anta, 0.026, 0.05, 0.01, 0.018, legno, Vector3(gs, -0.8, -0.046))
	var labbro := _cyl(anta, 0.013, 0.013, 0.44, legno_chiaro,
			Vector3(0, -0.798, -0.071))
	labbro.rotation.z = PI * 0.5
	for bs: float in [-0.21, 0.21]:
		_ball(anta, 0.015, legno_chiaro, Vector3(bs, -0.798, -0.071))
	_ball(anta, 0.03, gesso_tenue, Vector3(-0.04, -0.802, -0.05),
			Vector3(2.2, 0.14, 0.7))
	var gessetto := _cyl(anta, 0.013, 0.013, 0.085, gesso, Vector3(-0.11, -0.793, -0.05))
	gessetto.rotation.z = PI * 0.5
	gessetto.rotation.y = 0.2
	gessetto.name = "Gessetto"
	# il mozzicone rosa di sempre, e uno azzurro nuovo di zecca
	var mozzicone := _cyl(anta, 0.01, 0.01, 0.035, gesso_rosa,
			Vector3(0.02, -0.795, -0.05))
	mozzicone.rotation.z = PI * 0.5
	var azzurro := _cyl(anta, 0.01, 0.01, 0.05, _mat(Color("bfd8ee"), Color("a5c4de"), 6.0, 0.3),
			Vector3(0.07, -0.794, -0.044))
	azzurro.rotation.z = PI * 0.5
	azzurro.rotation.y = -0.3
	# il cancellino di feltro, stondato come un sapone consumato
	var cancellino := _lastra(anta, 0.021, 0.075, 0.012, 0.026,
			_mat(Color("6f665b"), Color("585047"), 5.0, 0.4),
			Vector3(0.145, -0.788, -0.05), Vector3(0, 0, PI * 0.5))
	cancellino.name = "Cancellino"
	_lastra(anta, 0.022, 0.075, 0.012, 0.013,
			_mat(Color("cfd4c8"), Color("b8bdb0"), 7.0, 0.4),
			Vector3(0.145, -0.806, -0.05), Vector3(0, 0, PI * 0.5))
	# il gessetto DI SCORTA appeso al montante con lo spago, come nei
	# bar veri: nessuno si fida che quello nella bacinella resti lì
	BUILDER.tube(anta, [Vector3(-0.272, -0.53, -0.03), Vector3(-0.288, -0.61, -0.046),
			Vector3(-0.281, -0.68, -0.04)], [0.0035, 0.0035, 0.0035], canapa, 12, 6)
	var appeso := _cyl(anta, 0.011, 0.011, 0.07, gesso, Vector3(-0.281, -0.715, -0.04))
	appeso.rotation.z = 0.14

	# --- e sul RETRO, dove nessuno guarda mai, qualcuno che aspettava
	# ha scarabocchiato un sole ---
	var retro: Node3D = n.get_node(^"Retro")
	var zr := 0.036
	_ball(retro, 0.032, gesso, Vector3(0.1, -0.3, zr), Vector3(1, 1, 0.2))
	for raggio in 8:
		var ar := TAU / 8.0 * float(raggio) + 0.3
		var r_box := _box(retro, Vector3(0.026, 0.007, 0.006), gesso,
				Vector3(0.1 + cos(ar) * 0.052, -0.3 + sin(ar) * 0.052, zr))
		r_box.rotation.z = ar
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
	# LA FIORIERA DEL DEHORS, ricreata da zero un'altra volta — stavolta
	# col metro giusto: le fioriere dei cozy game che commuovono sono
	# BASSE e RIGOGLIOSE. Corolle grandi e PIENE (due giri di petali
	# sagomati) su steli corti, una rosetta di foglie alla base di ogni
	# pianta, cespetti di solo verde a riempire i vuoti: la cassa trabocca
	# di vita, non è terra nuda con gli stecchi. La cassa stessa è nuova:
	# doghe VERTICALI svasate (si aprono verso l'alto come un cesto), due
	# toni alternati col millimetro di gioco, il CUORE intagliato sulla
	# doga centrale, i montanti torniti coi pomelli, la cornice col
	# mezzotondo, i piedini. E un tralcio d'edera per fianco, a scudetti.
	var n := Node3D.new()
	var legno := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	var legno_scuro := _mat(WOOD_DARK, WOOD_DARK.darkened(0.22), 4.0, 0.45)
	var doga_a := _mat(WOOD_PALE, WOOD, 3.5, 0.5)
	var doga_b := _mat(WOOD_PALE.lightened(0.06), WOOD_PALE, 3.5, 0.45)
	var ombra := _mat(Color("5a422e"), Color("46331f"), 3.0, 0.4)
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	# ---- la pancia interna scura (nelle fessure si vede ombra)
	_box(n, Vector3(0.86, 0.34, 0.26), ombra, Vector3(0, 0.23, 0))
	# ---- le doghe VERTICALI dei lati lunghi: sette per lato, svasate
	# (in alto si aprono), due toni alternati. Le fessure sono FILI di
	# lama, non varchi: a doghe strette la cassa diventava uno steccato
	# col buio che urlava in mezzo
	for sz: float in [-1.0, 1.0]:
		for di in 7:
			var dx := -0.375 + 0.125 * float(di)
			var doga := _lastra(n, 0.06, 0.37, 0.018, 0.026,
					doga_a if di % 2 == 0 else doga_b,
					Vector3(dx + rng.randf_range(-0.002, 0.002), 0.225, sz * 0.155))
			doga.rotation.x = -sz * 0.09
			doga.rotation.z = rng.randf_range(-0.006, 0.006)
	# il CUORE intagliato sulla doga centrale del fronte (-Z): la sagoma
	# scura ben fuori dalla doga, grande abbastanza da leggersi da lontano
	var cuore := _prisma(n, [Vector2(0.0, 0.038), Vector2(0.026, 0.01),
			Vector2(0.032, -0.01), Vector2(0.022, -0.024), Vector2(0.008, -0.024),
			Vector2(0.0, -0.011), Vector2(-0.008, -0.024), Vector2(-0.022, -0.024),
			Vector2(-0.032, -0.01), Vector2(-0.026, 0.01)], 0.0, 0.006, ombra)
	cuore.position = Vector3(0, 0.3, -0.176)
	cuore.rotation.x = PI * 0.5 + 0.09
	# ---- le doghe corte dei fianchi, tre per lato, svasate anche loro
	for sx: float in [-1.0, 1.0]:
		for di2 in 3:
			var dz := -0.098 + 0.098 * float(di2)
			var doga2 := _lastra(n, 0.052, 0.37, 0.018, 0.026,
					doga_a if di2 % 2 == 0 else doga_b,
					Vector3(sx * 0.44, 0.225, dz), Vector3(0, PI * 0.5, 0))
			doga2.rotation.z = sx * 0.09
	# ---- i montanti torniti agli angoli: piedino, fusto, collarino, pomello
	for sx2: float in [-1.0, 1.0]:
		for sz2: float in [-1.0, 1.0]:
			var mx := sx2 * 0.465
			var mz := sz2 * 0.165
			_cyl(n, 0.041, 0.044, 0.035, legno_scuro, Vector3(mx, 0.018, mz))
			_cyl(n, 0.031, 0.037, 0.44, legno, Vector3(mx, 0.24, mz))
			_cyl(n, 0.039, 0.039, 0.016, legno_scuro, Vector3(mx, 0.468, mz))
			_ball(n, 0.033, legno, Vector3(mx, 0.497, mz))
	# ---- la cornice APERTA in cima, allargata quanto la svasatura,
	# col mezzotondo sul filo
	for cz: float in [-1.0, 1.0]:
		_box(n, Vector3(0.99, 0.034, 0.064), legno, Vector3(0, 0.437, cz * 0.172))
		var tondo := _cyl(n, 0.016, 0.016, 0.99, legno, Vector3(0, 0.455, cz * 0.172))
		tondo.rotation.z = PI * 0.5
	for cx: float in [-1.0, 1.0]:
		_box(n, Vector3(0.06, 0.034, 0.4), legno, Vector3(cx * 0.465, 0.437, 0))
		var tondo2 := _cyl(n, 0.016, 0.016, 0.4, legno, Vector3(cx * 0.465, 0.455, 0))
		tondo2.rotation.x = PI * 0.5
	# ---- la terra, dentro la cornice, bombata e a zolle
	var terra := _mat(Color("6b5340"), Color("57432f"), 5.0, 0.5)
	var terra_cupa := _mat(Color("57432f"), Color("463527"), 4.0, 0.4)
	_loft(n, [[-0.43, 0.138, 0.4, 0.446, 0.02],
			[0.0, 0.138, 0.4, 0.472, 0.03],
			[0.43, 0.138, 0.4, 0.446, 0.02]], terra)
	for zi in 4:
		_ball(n, rng.randf_range(0.011, 0.016), terra_cupa,
				Vector3(rng.randf_range(-0.36, 0.36), 0.458,
				rng.randf_range(-0.09, 0.09)), Vector3(1.2, 0.55, 1.0))
	# ---- LE PIANTE. Due file sfalsate (dietro più alte, davanti più
	# basse), ogni pianta con la sua ROSETTA di foglie alla base, lo
	# stelo corto che si piega, e una corolla PIENA: due giri di petali
	# sagomati, i sepali sotto, il bottone con l'anello di stami.
	var verde := _mat(LEAF, LEAF_DARK, 6.0, 0.55)
	var verde_cupo := _mat(LEAF_DARK, LEAF_DARK.darkened(0.2), 5.0, 0.45)
	var tinte := [PINK, Color("ffd76e"), Color("cdbff0"), Color("f6c39c")]
	var piante := [
		[-0.31, -0.055, 0.17], [-0.02, -0.06, 0.19], [0.28, -0.05, 0.16],
		[-0.17, 0.065, 0.11], [0.13, 0.07, 0.12], [0.38, 0.06, 0.1],
	]
	for i in piante.size():
		var px: float = piante[i][0]
		var pz: float = piante[i][1]
		var h: float = piante[i][2] + rng.randf_range(-0.012, 0.012)
		var pianta := Node3D.new()
		pianta.position = Vector3(px, 0.45, pz)
		pianta.rotation.x = rng.randf_range(-0.08, 0.08)
		pianta.rotation.z = rng.randf_range(-0.1, 0.1)
		n.add_child(pianta)
		# la rosetta di foglie alla base: è lei a fare «pianta vera»
		for rk in 5:
			_foglia_lanceolata(pianta, verde, verde_cupo, Vector3(0, 0.006, 0),
					TAU / 5.0 * float(rk) + rng.randf_range(-0.25, 0.25),
					rng.randf_range(0.5, 0.95), rng.randf_range(0.75, 1.0))
		# lo stelo corto, con una foglia a mezza via
		BUILDER.tube(pianta, [Vector3(0, 0, 0), Vector3(0.01, h * 0.55, 0.006),
				Vector3(0.004, h, 0)], [0.008, 0.0065, 0.005], verde, 12, 8)
		_foglia_lanceolata(pianta, verde, verde_cupo,
				Vector3(0.009, h * 0.5, 0.004), rng.randf() * TAU,
				rng.randf_range(0.4, 0.6), 0.7)
		# la corolla piena
		var c: Color = tinte[i % tinte.size()]
		var pmat := _mat(c, c.darkened(0.15), 5.0, 0.4)
		var pmat_cupo := _mat(c.darkened(0.08), c.darkened(0.24), 5.0, 0.4)
		var corolla := Node3D.new()
		corolla.position = Vector3(0.004, h + 0.012, 0)
		corolla.rotation.y = rng.randf() * TAU
		corolla.rotation.x = rng.randf_range(-0.12, 0.12)
		pianta.add_child(corolla)
		for sk in 3:
			var sepalo := Node3D.new()
			sepalo.rotation.y = TAU / 3.0 * float(sk) + 0.5
			corolla.add_child(sepalo)
			var sfoglia := _prisma(sepalo, [Vector2(0.004, 0.0),
					Vector2(0.016, 0.008), Vector2(0.03, 0.004), Vector2(0.034, 0.0),
					Vector2(0.03, -0.004), Vector2(0.016, -0.008)],
					0.0, 0.004, verde)
			sfoglia.position = Vector3(0.004, -0.007, 0)
			sfoglia.rotation.z = -0.18
		# il giro ESTERNO di petali (più aperti) e quello INTERNO
		# (più piccoli, più alzati, sfalsati di mezzo passo): la corolla
		# piena che un giro solo non dà
		for k in 6:
			var petalo := Node3D.new()
			petalo.rotation.y = TAU / 6.0 * float(k) + rng.randf_range(-0.05, 0.05)
			corolla.add_child(petalo)
			var lembo := _prisma(petalo, [Vector2(0.004, 0.0),
					Vector2(0.017, 0.013), Vector2(0.038, 0.017), Vector2(0.052, 0.01),
					Vector2(0.057, 0.0), Vector2(0.052, -0.01), Vector2(0.038, -0.017),
					Vector2(0.017, -0.013)], 0.0, 0.005, pmat)
			lembo.position = Vector3(0.007, 0.003, 0)
			lembo.rotation.z = 0.22 + rng.randf_range(-0.05, 0.05)
			var s := rng.randf_range(0.94, 1.05)
			lembo.scale = Vector3(s, 1, s)
		for k2 in 6:
			var petalo2 := Node3D.new()
			petalo2.rotation.y = TAU / 6.0 * (float(k2) + 0.5)
			corolla.add_child(petalo2)
			var lembo2 := _prisma(petalo2, [Vector2(0.004, 0.0),
					Vector2(0.014, 0.01), Vector2(0.028, 0.012), Vector2(0.038, 0.007),
					Vector2(0.042, 0.0), Vector2(0.038, -0.007), Vector2(0.028, -0.012),
					Vector2(0.014, -0.01)], 0.0, 0.005, pmat_cupo)
			lembo2.position = Vector3(0.007, 0.007, 0)
			lembo2.rotation.z = 0.5 + rng.randf_range(-0.06, 0.06)
		_ball(corolla, 0.016, _mat(Color("f2b64f"), Color("d99b36"), 5.0, 0.35),
				Vector3(0, 0.014, 0), Vector3(1, 0.72, 1))
		var stami := MeshInstance3D.new()
		var sm := TorusMesh.new()
		sm.inner_radius = 0.013
		sm.outer_radius = 0.021
		stami.mesh = sm
		stami.material_override = _mat(Color("d99b36"), Color("bd8329"), 5.0, 0.35)
		stami.position = Vector3(0, 0.011, 0)
		corolla.add_child(stami)
	# ---- i cespetti di solo verde nei vuoti, e due bocci
	for gi in 3:
		var ce := Node3D.new()
		ce.position = Vector3([-0.42, 0.045, 0.2][gi], 0.448,
				[0.02, -0.085, 0.09][gi])
		n.add_child(ce)
		for rk2 in 4:
			_foglia_lanceolata(ce, verde, verde_cupo, Vector3(0, 0.004, 0),
					TAU / 4.0 * float(rk2) + rng.randf_range(-0.3, 0.3),
					rng.randf_range(0.55, 1.0), rng.randf_range(0.55, 0.8))
	for bi in 2:
		var boccio := Node3D.new()
		boccio.position = Vector3([-0.14, 0.31][bi], 0.45, [-0.03, 0.09][bi])
		boccio.rotation.z = rng.randf_range(-0.2, 0.2)
		n.add_child(boccio)
		var bh := rng.randf_range(0.08, 0.11)
		BUILDER.tube(boccio, [Vector3(0, 0, 0), Vector3(0.007, bh, 0)],
				[0.007, 0.0045], verde, 8, 8)
		_ball(boccio, 0.016, verde, Vector3(0.007, bh + 0.01, 0),
				Vector3(0.85, 1.25, 0.85))
		_ball(boccio, 0.0085, _mat(PINK, PINK.darkened(0.15), 5.0, 0.4),
				Vector3(0.007, bh + 0.028, 0), Vector3(0.9, 1.1, 0.9))
		for sk2 in 3:
			var sep := Node3D.new()
			sep.position = Vector3(0.007, bh + 0.004, 0)
			sep.rotation.y = TAU / 3.0 * float(sk2)
			boccio.add_child(sep)
			var sf := _prisma(sep, [Vector2(0.0, 0.0), Vector2(0.011, 0.005),
					Vector2(0.022, 0.002), Vector2(0.024, 0.0), Vector2(0.022, -0.002),
					Vector2(0.011, -0.005)], 0.0, 0.0035, verde)
			sf.rotation.z = 0.9
	# ---- l'edera: un tralcio per fianco, che scavalca la cornice e
	# scende sul legno con le foglie a scudetto, ognuna col suo verso
	for ti in 2:
		var lato := 1.0 if ti == 0 else -1.0
		var da := Vector3(lato * 0.42, 0.455, 0.02)
		var tralcio := BUILDER.tube(n, [da,
				da + Vector3(lato * 0.045, 0.014, 0.015),
				da + Vector3(lato * 0.075, -0.08, 0.03),
				da + Vector3(lato * 0.09, -0.2, 0.01),
				da + Vector3(lato * 0.08, -0.31, -0.02)],
				[0.0075, 0.007, 0.006, 0.005, 0.004], verde, 24, 8)
		tralcio.name = "Edera%d" % ti
		for f in 5:
			var t := float(f) / 4.0
			var fp := da + Vector3(lato * lerpf(0.05, 0.085, t),
					lerpf(-0.02, -0.28, t), lerpf(0.02, -0.01, t) + sin(t * PI) * 0.02)
			var foglia := Node3D.new()
			foglia.position = fp
			foglia.rotation.y = (0.0 if lato > 0.0 else PI) + 0.5 - t * 2.4
			foglia.rotation.z = 0.3 - t * 0.5
			foglia.rotation.x = PI * 0.5 - 0.55 + rng.randf_range(-0.35, 0.35)
			foglia.scale = Vector3.ONE * rng.randf_range(1.1, 1.3)
			n.add_child(foglia)
			var picciolo := _cyl(foglia, 0.0016, 0.0016, 0.012, verde_cupo,
					Vector3(0.005, 0, 0))
			picciolo.rotation.z = PI * 0.5
			_prisma(foglia, [Vector2(0.011, 0.0), Vector2(0.016, 0.011),
					Vector2(0.027, 0.012), Vector2(0.038, 0.005), Vector2(0.042, 0.0),
					Vector2(0.038, -0.005), Vector2(0.027, -0.012),
					Vector2(0.016, -0.011)], -0.0015, 0.003, verde)
	return n


## Una foglia LANCEOLATA vera: il profilo estruso (largo a un terzo,
## punta fine), la nervatura centrale più scura, il picciolo che la
## attacca allo stelo. `giro` la orienta attorno allo stelo, `alza` è
## quanto punta in su, `taglia` scala tutta la foglia.
static func _foglia_lanceolata(parent: Node3D, verde: Material,
		nervatura: Material, attacco: Vector3, giro: float, alza: float,
		taglia: float) -> void:
	var foglia := Node3D.new()
	foglia.position = attacco
	foglia.rotation.y = giro
	foglia.rotation.z = alza
	foglia.scale = Vector3.ONE * taglia
	parent.add_child(foglia)
	var picciolo := _cyl(foglia, 0.0022, 0.0028, 0.014, verde, Vector3(0.006, 0, 0))
	picciolo.rotation.z = PI * 0.5
	_prisma(foglia, [Vector2(0.012, 0.0), Vector2(0.028, 0.011),
			Vector2(0.05, 0.0125), Vector2(0.068, 0.006), Vector2(0.078, 0.0),
			Vector2(0.068, -0.006), Vector2(0.05, -0.0125), Vector2(0.028, -0.011)],
			-0.002, 0.004, verde)
	# la nervatura centrale, un filo più scuro posato sul dorso
	var nervo := _cyl(foglia, 0.0016, 0.0016, 0.058, nervatura,
			Vector3(0.042, 0.0025, 0))
	nervo.rotation.z = PI * 0.5


static func _cesto_fiorito() -> Node3D:
	# IL CESTO DEL DEHORS, finito. Non una cassetta: un CESTO, e
	# l'intreccio è VERO — trentadue montanti piantati a distanza d'arco
	# costante e dieci file di vimini che passano davanti a un montante e
	# dietro al successivo, ogni fila in controfase con quella sotto. È
	# l'ALTERNANZA a leggersi come intreccio: una parete incisa resta una
	# parete, e delle doghe che non si toccano fanno uno steccato col buio
	# dietro. In cima il cordolo è una TRECCIA a tre capi, in basso ne gira
	# una a due che fa da piede, e ai fianchi due manici di fune ritorta
	# LEGATI al bordo con la fasciatura.
	# Dentro, fiori di CAMPO — mai un mazzo da fioraio: margherite in tre
	# tinte (bianche, crema-albicocca, rosa carico: una margherita di campo
	# vera declina, non è una vernice sola), campanule che pendono a testa
	# in giù dai peduncoli curvi, achillea e trifoglio a fiorellini minuti
	# nel sottobosco, spighe candide; e sotto di loro la MASSA che fa la
	# differenza fra una fioriera vissuta e un'aiuola appena seminata.
	#
	# Cosa è cambiato dal primo giro, e perché (i cinque difetti visti
	# dall'autore con gli occhi, non col compilatore):
	#  1. LA GONDOLA. Il contorno era una superellisse con esponente 0.66,
	#     cioè n = 3.0 su un rapporto di 2.8 a 1: dall'alto le due
	#     estremità finivano a punta e il cesto leggeva come una canoa.
	#     Ora l'esponente è 0.42 (n = 4.76) e la pancia è più larga: a nove
	#     decimi della lunghezza il cesto è ancora all'83% della sua
	#     larghezza (prima al 65%). È un ovale pieno con gli angoli molto
	#     tondi, che è quello che vuole una fioriera.
	#  2. I MANICI. Erano un ritorto sottile appeso in aria: di fronte le
	#     spire si leggevano come i denti di un pettine. Ora la fune è
	#     grossa il doppio (42 mm), il ritorto è lento (cinque giri su
	#     tutto l'arco, non otto) e soprattutto ha la FASCIATURA ai piedi —
	#     sei giri stretti di vimine che la legano al cordolo. È
	#     l'attacco visibile a dire «manico»: una corda che finisce in aria
	#     è una maniglia di plastica.
	#  3. LE CHIAZZE PIATTE. Le foglie del sottobosco erano prismi
	#     ESTRUSI posati quasi orizzontali: dall'alto sono lastre verdi, e
	#     una lastra verde legge come vetro o come una toppa. Ora ogni
	#     lembo è una SUPERFICIE (`_cesto_lembo_mesh`): la carena centrale
	#     lo piega a tetto lungo il suo asse e la curvatura lo fa cadere
	#     verso la punta. La luce ci scorre sopra invece di spegnersi tutta
	#     insieme, ed è quella la differenza fra una foglia e un adesivo.
	#     (Costa anche MENO: un lembo era tre prismi, adesso è un mesh.)
	#  4. NON TRABOCCAVA. Il verde restava dentro, usciva solo l'edera.
	#     Adesso una ghirlanda di lembi scavalca il cordolo e ricade
	#     sull'intreccio mangiandosene il bordo, i cuscinetti di muschio
	#     montano più in fuori, due margherite si sporgono oltre le teste
	#     del cesto e i tralci di edera sono cinque.
	#  5. FACEVA FREDDO. Bianco + lilla + verde. Il calore non arriva da
	#     una specie estranea (sarebbe un altro cesto): arriva dalle
	#     margherite declinate in crema-albicocca e rosa carico, e da una
	#     manciata di fiorellini caldi nel sottobosco — achillea rosata a
	#     ombrella piatta e teste di trifoglio.
	var n := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260809

	# ---- le misure: mezze luci di base, quota del bordo, e la svasatura.
	# Un cesto si allarga salendo e ha un filo di pancia: senza, è un
	# secchio. `quadro` è la QUADRATURA del contorno (vedi `_cesto_giro`):
	# più è piccolo, più il cesto è un rettangolo con gli angoli tondi.
	var ax := 0.368
	var az := 0.139
	var qh := 0.288
	var quadro := 0.36
	var svaso := func(y: float) -> float:
		var t := clampf(y / qh, 0.0, 1.0)
		return 1.0 + 0.112 * pow(t, 0.92) + 0.020 * sin(t * PI)
	var s_alto: float = svaso.call(qh)
	var np := 160
	var stecche := 32
	var per_stecca := np / stecche
	var g := _cesto_giro(np, ax, az, quadro)
	var giro: Array = g[0]
	var nor: Array = g[1]

	# ---- la paglia: due toni di vimine che si alternano fila per fila
	# (un cesto vero non è fatto di un unico bastone), i montanti più
	# scuri perché stanno sotto, e la fodera che fa da ombra piena
	var vimine_a := _mat(Color("e0bd8a"), Color("bb9260"), 5.5, 0.5)
	var vimine_b := _mat(Color("d3ae7a"), Color("ac8452"), 5.0, 0.52)
	var montanti := _mat(Color("c39a62"), Color("9c7541"), 4.5, 0.5)
	var fodera := _mat(Color("9d7a4c"), Color("7b5c37"), 3.5, 0.45)
	var corda := _mat(Color("d8c096"), Color("b09870"), 7.0, 0.5)
	var legaccio := _mat(Color("c9a874"), Color("a3814e"), 9.0, 0.55)

	# ---- il fondo e la fodera piena: la parete che si intravede fra i
	# vimini. Doppia faccia, perché dall'alto si guarda dentro il cesto
	var fondo_pts: Array = []
	var iq := 0
	while iq < np:
		fondo_pts.append((giro[iq] as Vector2) * float(svaso.call(0.02))
				+ (nor[iq] as Vector2) * -0.006)
		iq += 4
	_prisma(n, fondo_pts, 0.006, 0.028, fodera)
	var fodera_vg: Array = []
	for j in 5:
		var y := lerpf(0.014, qh - 0.004, float(j) / 4.0)
		var sy: float = svaso.call(y)
		var riga := PackedVector3Array()
		var ic := 0
		while ic < np:
			var p2: Vector2 = (giro[ic] as Vector2) * sy + (nor[ic] as Vector2) * -0.020
			riga.append(Vector3(p2.x, y, p2.y))
			ic += 2
		fodera_vg.append(riga)
	_mesh_griglia(n, fodera_vg, fodera, Vector3.ZERO, true, true)

	# ---- i montanti: rastremati verso l'alto, e ognuno col suo scarto
	# di un millimetro e mezzo — trentadue bastoni identici sono tornitura,
	# non vimini
	for k in stecche:
		var i := k * per_stecca
		var scarto := rng.randf_range(-0.0016, 0.0016)
		var perc := PackedVector3Array()
		for j in 6:
			var t := float(j) / 5.0
			var y := lerpf(0.008, qh + 0.010, t)
			var sy: float = svaso.call(y)
			var p2: Vector2 = ((giro[i] as Vector2) * sy
					+ (nor[i] as Vector2) * (scarto * sin(t * PI)))
			perc.append(Vector3(p2.x, y, p2.y))
		_cesto_vimine(n, perc, 0.0105, 0.0080, montanti, 6, false)

	# ---- L'INTRECCIO: ogni fila è un unico vimine continuo che ONDEGGIA
	# in fuori e in dentro con periodo di due montanti. Sul montante è
	# tutto davanti o tutto dietro, a metà gap passa a filo: è la stessa
	# geometria della randa vera, ed è per questo che si legge.
	for r in 10:
		var y := 0.038 + 0.0272 * float(r)
		var sy: float = svaso.call(y)
		var fase := PI * float(r)
		var perc := PackedVector3Array()
		for i in np:
			var onda := cos(PI * float(i) / float(per_stecca) + fase)
			var p2: Vector2 = ((giro[i] as Vector2) * sy
					+ (nor[i] as Vector2) * (onda * 0.0138))
			# la fila non è a livella: un vimine piegato a mano respira
			var dy := 0.0018 * sin(float(i) / float(np) * TAU * 3.0 + float(r) * 1.7)
			perc.append(Vector3(p2.x, y + dy, p2.y))
		_cesto_vimine(n, perc, 0.0126, 0.0126,
				vimine_a if r % 2 == 0 else vimine_b, 6, true)

	# ---- il cordolo in cima: TRE capi che si avvolgono l'uno sull'altro
	# lungo tutto il bordo. Un toro liscio sarebbe un cerchio di plastica;
	# la treccia è il gesto finale del cestaio, e chiude le teste dei
	# montanti
	var g2 := _cesto_giro(208, ax, az, quadro)
	var giro2: Array = g2[0]
	var nor2: Array = g2[1]
	for capo in 3:
		var perc := PackedVector3Array()
		for i in 208:
			var f := TAU * float(i) / 208.0 * 24.0 + TAU / 3.0 * float(capo)
			var p2: Vector2 = ((giro2[i] as Vector2) * s_alto
					+ (nor2[i] as Vector2) * (cos(f) * 0.0082))
			perc.append(Vector3(p2.x, qh + 0.012 + sin(f) * 0.0082, p2.y))
		_cesto_vimine(n, perc, 0.0082, 0.0082,
				vimine_a if capo != 1 else vimine_b, 6, true)
	# ---- e il piede: due capi ritorti che alzano il cesto da terra
	for capo2 in 2:
		var perc2 := PackedVector3Array()
		for i in 192:
			var f2 := TAU * float(i) / 192.0 * 18.0 + PI * float(capo2)
			var gi := int(round(float(i) * 208.0 / 192.0)) % 208
			var p3: Vector2 = ((giro2[gi] as Vector2) * float(svaso.call(0.022))
					+ (nor2[gi] as Vector2) * (0.004 + cos(f2) * 0.0068))
			perc2.append(Vector3(p3.x, 0.024 + sin(f2) * 0.0068, p3.y))
		_cesto_vimine(n, perc2, 0.0072, 0.0072, montanti, 6, true)

	# ---- i due manici alle teste, con la fasciatura (vedi `_cesto_manico`)
	var xr := ax * s_alto
	_cesto_manico(n, -1.0, xr, qh, corda, legaccio)
	_cesto_manico(n, 1.0, xr, qh, corda, legaccio)

	# ---- LA TERRA. Una sola formula per la sua quota, e la cupola si
	# COSTRUISCE da quella: `q` è il raggio superellittico (l'inversa
	# esatta del contorno, quindi con lo STESSO esponente — se i due
	# divergono si pianta il muschio due centimetri sotto la superficie) e
	# la quota è una campana su q.
	var esp := 2.0 / quadro
	var rx := ax * s_alto - 0.012
	var rz := az * s_alto - 0.012
	var colmo := 0.304
	var caduta := 0.013
	var terra_h := func(x: float, z: float) -> float:
		var q := pow(pow(clampf(absf(x) / rx, 0.0, 1.0), esp)
				+ pow(clampf(absf(z) / rz, 0.0, 1.0), esp), 1.0 / esp)
		return colmo - caduta * pow(minf(q, 1.0), 1.7)
	# la terra si vede FRA i cuscinetti di muschio, e allora deve leggersi
	# come terra bagnata: le zolle più cupe della prima stesura, viste
	# dall'alto, diventavano buchi neri nel prato — otto crateri
	var terra := _mat(Color("7a5f42"), Color("614a33"), 5.0, 0.45)
	var vg_t: Array = []
	for anello in 7:
		var q2 := float(anello) / 6.0
		var riga := PackedVector3Array()
		for j in 48:
			var gi := int(round(float(j) * float(np) / 48.0)) % np
			var bordo: Vector2 = ((giro[gi] as Vector2) * s_alto
					+ (nor[gi] as Vector2) * -0.012)
			var p2 := bordo * q2
			riga.append(Vector3(p2.x, colmo - caduta * pow(q2, 1.7), p2.y))
		vg_t.append(riga)
	_mesh_griglia(n, vg_t, terra, Vector3.ZERO, true)

	# ---- la tavolozza. Nessun colore pieno: i fiori di campo sono lavati,
	# e un rosa saturo su un petalo bombato è una caramella. Il controluce
	# (translucency) è quello che salva un petalo: sottile, si accende
	# quando il sole gli sta dietro.
	# Le tre tinte delle margherite sono il CALORE del pezzo: bianco
	# panna, crema-albicocca, rosa carico. Non tre specie: la stessa
	# margherita che in un prato vero non esce mai di un colore solo.
	var puff := SphereMesh.new()
	puff.radius = 1.0
	puff.height = 2.0
	puff.radial_segments = 9
	puff.rings = 4
	var tav := {
		"verde": _mat(LEAF, LEAF_DARK, 6.0, 0.55),
		"verde_cupo": _mat(LEAF_DARK, LEAF_DARK.darkened(0.22), 5.0, 0.5),
		"verde_tenero": _mat(Color("86b25e"), Color("6b9a4c"), 6.5, 0.5),
		"verde_oliva": _mat(Color("9cb45c"), Color("798f42"), 6.0, 0.5),
		"petalo": _mat(Color("fdfaf1"), Color("e4d9c2"), 4.0, 0.28, 0.28),
		"petalo_crema": _mat(Color("fde0ae"), Color("f2c283"), 4.0, 0.30, 0.30),
		"petalo_rosa": _mat(Color("ee92a8"), Color("cf6d87"), 4.0, 0.30, 0.30),
		"cuore": _mat(Color("f6c94f"), Color("d9a63a"), 5.0, 0.3),
		"cuore_cupo": _mat(Color("dda63c"), Color("bd862a"), 5.0, 0.3),
		"puff": puff,
	}
	var verdi: Array = [tav["verde"], tav["verde_tenero"], tav["verde_oliva"]]
	# la ghirlanda e l'edera hanno un verde in più, il CUPO: sul fianco al
	# sole il fogliame chiaro finiva alla stessa luminosità della paglia e
	# il trabocco spariva — di fronte (che è in ombra) si vedeva benissimo.
	# Un pezzo va guardato dai due lati anche per il CONTRASTO, non solo
	# per la forma.
	var verdi_bordo: Array = [tav["verde"], tav["verde_cupo"],
			tav["verde_tenero"], tav["verde_oliva"]]

	# ---- la biblioteca dei LEMBI. Cinque foglie tonde a lobi e quattro
	# lanceolate, costruite una volta sola e instanziate ottanta: la
	# geometria è la stessa, e il conto no.
	var lobate: Array = []
	for i in 5:
		lobate.append(_cesto_lembo_mesh(
				_cesto_lobi(0.0236 + 0.0033 * float(i), 5 if i % 2 == 0 else 7,
				0.40, 20), 3.4, 0.24, 2))
	# l'EDERA dei tralci: più piccola delle altre (una foglia d'edera vera
	# è quattro centimetri, non sette) e con la carena più marcata — sono
	# le uniche che si guardano da vicino e in faccia, appese al vimine
	var edera: Array = []
	for i in 3:
		edera.append(_cesto_lembo_mesh(
				_cesto_lobi(0.0219 + 0.0032 * float(i), 5, 0.46, 20), 4.2, 0.32, 2))
	# i lembi della ghirlanda sono piu' grandi degli altri: devono
	# MANGIARSI il cordolo, e una fogliolina da due centimetri e mezzo
	# appesa a una treccia da otto è una frangia, non un trabocco
	var ghirlanda: Array = []
	for i in 4:
		ghirlanda.append(_cesto_lembo_mesh(
				_cesto_lobi(0.0260 + 0.0036 * float(i), 5 if i % 2 == 0 else 7,
				0.40, 20), 3.0, 0.26, 2))
	var lance: Array = []
	for i in 4:
		lance.append(_cesto_lembo_mesh(
				_cesto_lancia(0.072 + 0.010 * float(i),
				0.0175 + 0.0022 * float(i), 9), 2.1, 0.16, 2))
	# le foglioline strette dell'achillea e del trifoglio
	var lance_min: Array = []
	for i in 2:
		lance_min.append(_cesto_lembo_mesh(
				_cesto_lancia(0.040 + 0.008 * float(i), 0.0072, 8), 3.4, 0.22, 2))

	# ---- IL MUSCHIO: cuscinetti irregolari (una sfera schiacciata è una
	# bolla verde), tre stampi e tre verdi. Tre taglie sovrapposte —
	# i mucchi grossi fanno il terreno, i medi lo rompono, i minuti fanno
	# il pelo: è la sovrapposizione a leggersi come muschio, un cuscinetto
	# solo si legge come un sasso verde.
	# Sul bordo monta a CHIAZZE e adesso SCAVALCA: dove monta esce oltre la
	# treccia, altrove si ritira e lascia vedere il vimine — una frangia
	# uniforme sarebbe una guarnizione di gomma, e coprirebbe il lavoro del
	# cestaio.
	var cuscini: Array = [_cesto_cuscino(11), _cesto_cuscino(29), _cesto_cuscino(47)]
	var muschi: Array = [_mat(Color("8cae5e"), Color("668a40"), 7.0, 0.6),
			_mat(Color("a3b768"), Color("7d9750"), 8.0, 0.55),
			_mat(Color("6d8f49"), Color("4d6b31"), 6.0, 0.6)]
	var im := 0
	while im < np:
		var monta := sin(float(im) / float(np) * TAU * 3.4 + 1.8)
		var sale := monta > -0.15
		var fuori := -0.014 + (0.024 if sale else 0.004) * (0.6 + 0.4 * rng.randf())
		var alza2 := (0.012 if sale else -0.008) + rng.randf_range(-0.006, 0.008)
		var p2: Vector2 = ((giro[im] as Vector2) * s_alto
				+ (nor[im] as Vector2) * fuori)
		var rr := rng.randf_range(0.020, 0.030)
		_cesto_puff(n, cuscini[im % 3], muschi[(im / 5) % 3],
				Vector3(p2.x, qh - 0.002 + alza2, p2.y),
				Vector3(rr, rr * rng.randf_range(0.60, 0.85), rr),
				rng.randf() * TAU)
		im += 4
	# tre CORONE con lo scarto addosso, non una manciata a caso: la
	# semina puramente casuale lasciava una calvizie di terra grossa come
	# una moneta sempre in un posto diverso, e per coprirla bisognava
	# raddoppiare i cuscinetti. Il reticolo disturbato copre tutto con la
	# metà dei pezzi e non si legge come reticolo.
	# (i tipi qui vanno DICHIARATI: il pescaggio da un array non tipizzato
	# non ha tipo statico, e un `:=` fa fallire il parse dell'intero file —
	# con il pezzo che sparisce dal catalogo senza che nulla lo dica)
	for corona in 3:
		var q3: float = [0.30, 0.60, 0.86][corona]
		var quanti: int = [8, 15, 22][corona]
		var rmin: float = [0.036, 0.028, 0.022][corona]
		var rmax: float = [0.056, 0.044, 0.036][corona]
		for k2 in quanti:
			var u2 := (float(k2) + rng.randf_range(-0.34, 0.34)) / float(quanti)
			var gi2 := int(u2 * float(np) + float(np)) % np
			var qq := clampf(q3 + rng.randf_range(-0.10, 0.10), 0.04, 0.95)
			var bordo2: Vector2 = ((giro[gi2] as Vector2) * s_alto
					+ (nor[gi2] as Vector2) * -0.016) * qq
			var rr2 := rng.randf_range(rmin, rmax)
			# il centro sta SOPRA la terra, non affondato: schiacciati e
			# sepolti i cuscinetti diventavano toppe verdi piatte, e il
			# dentro del cesto leggeva come un piatto dipinto
			var schiaccia := rng.randf_range(0.52, 0.78)
			_cesto_puff(n, cuscini[(k2 + corona) % 3], muschi[(k2 + corona * 2) % 3],
					Vector3(bordo2.x,
					float(terra_h.call(bordo2.x, bordo2.y)) + rr2 * schiaccia * 0.12,
					bordo2.y),
					Vector3(rr2, rr2 * schiaccia, rr2), rng.randf() * TAU)
	# e sopra le corone il PELO: cuscinetti minuti, questi sì a caso
	for k4 in 26:
		var q5 := sqrt(rng.randf()) * 0.92
		var gi4 := int(rng.randf() * float(np)) % np
		var b5: Vector2 = ((giro[gi4] as Vector2) * s_alto
				+ (nor[gi4] as Vector2) * -0.016) * q5
		var r5 := rng.randf_range(0.012, 0.020)
		_cesto_puff(n, cuscini[k4 % 3], muschi[(k4 + 1) % 3],
				Vector3(b5.x, float(terra_h.call(b5.x, b5.y)) + r5 * 0.4, b5.y),
				Vector3(r5, r5 * 0.9, r5), rng.randf() * TAU)

	# ---- il sottobosco: lembi tondi a lobi POSATI sul muschio. Dall'alto
	# il muschio da solo resta una macchia — sono le sagome riconoscibili
	# appoggiate sopra a dirti che lì sotto c'è terra viva. Mai in bolla:
	# ognuno ha la sua torsione, e uno su tre si alza di taglio (dall'occhio
	# del giocatore, che è basso, un tappeto di lembi coricati si vede di
	# fianco e torna a essere una lastra).
	for k3 in 26:
		var q4 := sqrt(rng.randf()) * 0.90
		var gi3 := int(rng.randf() * float(np)) % np
		var b3: Vector2 = ((giro[gi3] as Vector2) * s_alto
				+ (nor[gi3] as Vector2) * -0.020) * q4
		var eretta := k3 % 3 == 1
		_cesto_lembo(n, lobate[k3 % 5], verdi[k3 % 3],
				Vector3(b3.x, float(terra_h.call(b3.x, b3.y)) + 0.005, b3.y),
				Vector3(rng.randf_range(-0.55, 0.55), rng.randf() * TAU,
				rng.randf_range(0.42, 0.86) if eretta else rng.randf_range(-0.20, 0.26)),
				rng.randf_range(0.80, 1.14))

	# ---- LA GHIRLANDA CHE TRABOCCA. È il gesto che mancava: il verde
	# scavalca il cordolo e RICADE sull'intreccio, mangiandosi in parte il
	# bordo. Un cesto pieno di fiori col bordo nudo è una cesta di frutta.
	# I lembi si girano quasi lungo la TANGENTE del cesto: puntati in
	# fuori sporgerebbero di tutto il loro raggio e sfonderebbero la cella
	# (misurato: sono tre centimetri per lato, su un mezzo metro scarso).
	# Le teste si saltano, che lì ci passano i manici.
	for j in 52:
		var i := int(float(j) * float(np) / 52.0 + 1.0) % np
		var pc: Vector2 = giro[i] as Vector2
		if absf(pc.x) > ax * 0.90:
			continue
		var nn: Vector2 = nor[i] as Vector2
		var p2: Vector2 = pc * s_alto + nn * (-0.004 + rng.randf_range(-0.006, 0.006))
		var fuori2 := atan2(-nn.y, nn.x)
		# DUE MODI di stare sul bordo, e la scelta non è un vezzo.
		# Un lembo coricato lungo la TANGENTE è quello che costa meno
		# profondità — ma di fronte lo si vede di TAGLIO, cioè non lo si
		# vede: la prima ghirlanda era tutta così, e il cordolo restava
		# nudo come prima. Un lembo buttato IN FUORI e giù ripido invece
		# mostra la faccia a chi guarda, e in profondità costa solo il
		# coseno della sua caduta — tre centimetri, non sette.
		# Perciò: sui fianchi lunghi (dove si guarda il pezzo, e dove la
		# cella è stretta) i lembi si buttano in fuori a picco; alle teste,
		# dove c'è posto, restano coricati sulla treccia.
		var faccia := absf(nn.y)
		var giro5: float
		var cade: float
		var rollio: float
		var stampo: int
		if faccia > 0.42:
			# a picco: la faccia del lembo guarda chi passa, la larghezza
			# scende lungo il vimine e in profondità non costa niente
			giro5 = fuori2 + rng.randf_range(-0.40, 0.40)
			cade = rng.randf_range(-1.46, -0.98)
			rollio = rng.randf_range(-0.40, 0.40)
			stampo = (j + 2) % 4
		else:
			giro5 = (fuori2 + (PI * 0.5 if j % 2 == 0 else -PI * 0.5)
					+ rng.randf_range(-0.42, 0.42))
			cade = rng.randf_range(-0.96, -0.16)
			rollio = rng.randf_range(-0.50, 0.50)
			# alle teste il lembo resta coricato, e un lembo coricato
			# pesca in profondità tutta la sua LARGHEZZA: lì si tengono i
			# due stampi minori
			stampo = j % 2
		if j % 7 == 0:
			cade = rng.randf_range(0.12, 0.50)  # qualcuno si alza ancora
		var quota5 := qh + rng.randf_range(-0.004, 0.018)
		_cesto_lembo(n, ghirlanda[stampo], verdi_bordo[(j + 1) % 4],
				Vector3(p2.x, quota5, p2.y),
				Vector3(rollio, giro5, cade), rng.randf_range(0.86, 1.14))
		# uno su tre è un CIUFFO e non una foglia sola: il trabocco è una
		# massa che scavalca, e una massa si legge quando le sagome si
		# accavallano invece di stare in fila come i denti di un rastrello
		if j % 3 == 1:
			_cesto_lembo(n, ghirlanda[(stampo + 1) % 4 if faccia > 0.42 else stampo],
					verdi_bordo[j % 4],
					Vector3(p2.x, quota5 + rng.randf_range(0.004, 0.020), p2.y),
					Vector3(rollio + rng.randf_range(-0.4, 0.4),
					giro5 + rng.randf_range(-0.42, 0.42),
					cade + rng.randf_range(0.10, 0.52)),
					rng.randf_range(0.70, 0.96))

	# ---- IL NIDO AI PIEDI DEI MANICI. Dove la fune entra sotto il
	# cordolo il cesto restava nudo, e il manico — che di fronte si vede
	# di taglio — spuntava dal vimine pallido come un osso. In un cesto
	# piantato davvero è lì che il verde si aggrappa: due o tre lembi e un
	# cuscinetto di muschio nascondono l'attacco e legano il manico alla
	# massa invece di lasciarlo lì per conto suo.
	for sx: float in [-1.0, 1.0]:
		for zs: float in [-1.0, 1.0]:
			var fx := sx * xr * 0.94
			var fz := zs * 0.078
			for q in 3:
				_cesto_lembo(n, ghirlanda[(q + 1) % 4], verdi[q % 3],
						Vector3(fx + sx * rng.randf_range(-0.030, 0.004),
						qh + rng.randf_range(-0.008, 0.016),
						fz + zs * rng.randf_range(-0.020, 0.012)),
						Vector3(rng.randf_range(-0.5, 0.5),
						atan2(-fz, fx) + rng.randf_range(-1.0, 1.0),
						rng.randf_range(-1.30, -0.30)),
						rng.randf_range(0.76, 1.00))
			var rn := rng.randf_range(0.020, 0.030)
			_cesto_puff(n, cuscini[int(sx + zs + 2.0) % 3],
					muschi[int(sx - zs + 2.0) % 3],
					Vector3(fx - sx * 0.010, qh + rng.randf_range(0.000, 0.010),
					fz - zs * 0.006),
					Vector3(rn, rn * 0.66, rn), rng.randf() * TAU)

	# ---- LE MARGHERITE. Tre tinte, e nessuna alla quota o al giro
	# dell'altra. `[x, z, altezza, tinta, stampo, fuga x, fuga z]`: la
	# FUGA è quanto la cima dello stelo scappa via dalla base — le due che
	# scappano sopra le teste del cesto sono quelle che fanno traboccare
	# anche i fiori, non solo il fogliame. Scappano lungo la LUNGHEZZA e
	# non lungo la larghezza: una corolla è larga quattro centimetri e
	# mezzo, e sporta di fianco esce dalla cella.
	var corolle: Array = [_cesto_corolla_mesh(3, 8), _cesto_corolla_mesh(17, 9),
			_cesto_corolla_mesh(41, 8), _cesto_corolla_mesh(59, 9)]
	var tinte_pet: Array = [tav["petalo"], tav["petalo_crema"], tav["petalo_rosa"]]
	for m in [[-0.318, 0.026, 0.176, 0, 0, 0.0, 0.0],
			[-0.238, -0.058, 0.128, 2, 1, 0.0, 0.0],
			[-0.150, 0.068, 0.206, 1, 2, 0.0, 0.0],
			[-0.056, -0.038, 0.152, 0, 3, 0.0, 0.0],
			[0.028, 0.074, 0.192, 2, 1, 0.0, 0.0],
			[0.116, -0.066, 0.140, 1, 0, 0.0, 0.0],
			[0.204, 0.044, 0.198, 0, 2, 0.0, 0.0],
			[0.288, -0.034, 0.150, 2, 3, 0.0, 0.0],
			[-0.344, -0.036, 0.116, 1, 1, -0.062, -0.012],
			[0.342, 0.040, 0.108, 2, 0, 0.068, 0.008]]:
		var bx := float(m[0])
		var bz := float(m[1])
		_cesto_margherita(n, rng, Vector3(bx, float(terra_h.call(bx, bz)) - 0.010, bz),
				float(m[2]), tav, lance, corolle[int(m[4])],
				tinte_pet[int(m[3])], Vector2(float(m[5]), float(m[6])))
	# quattro bocci ancora chiusi: una fioriera vera non fiorisce tutta
	# insieme
	for b in [[-0.264, -0.006, 0.105, 2], [0.072, 0.072, 0.115, 0],
			[0.256, -0.020, 0.095, 1], [0.164, 0.080, 0.100, 2]]:
		var bx2 := float(b[0])
		var bz2 := float(b[1])
		_cesto_boccio(n, rng, Vector3(bx2, float(terra_h.call(bx2, bz2)) - 0.008, bz2),
				float(b[2]), tav, lance, tinte_pet[int(b[3])])

	# ---- LE CAMPANULE: l'arco esce dal cesto e le campane pendono dalla
	# metà alta, più piccole verso la punta — un racemo, non un lampadario.
	# Sono tre e non quattro: il lilla è il freddo del pezzo, e adesso deve
	# stare accanto al rosa senza spegnerlo.
	var campana := _cesto_campanella(5)
	var lilla := _mat(Color("aca7e0"), Color("8b85c6"), 5.0, 0.32, 0.34)
	var celeste := _mat(Color("a2b9e4"), Color("7f99c7"), 5.0, 0.32, 0.34)
	for cp in [[-0.336, 0.044, -0.62, -0.78, 0.165, 0.098, 4, 0],
			[0.048, 0.078, 0.24, 0.97, 0.195, 0.086, 4, 1],
			[0.330, -0.044, 0.70, -0.71, 0.140, 0.084, 3, 0]]:
		var cx4 := float(cp[0])
		var cz4 := float(cp[1])
		_cesto_campanule(n, rng,
				Vector3(cx4, float(terra_h.call(cx4, cz4)) - 0.008, cz4),
				Vector2(float(cp[2]), float(cp[3])), float(cp[4]), float(cp[5]),
				int(cp[6]), campana, lilla if int(cp[7]) == 0 else celeste,
				tav, lance)

	# ---- L'ACHILLEA ROSATA: l'ombrella PIATTA di fiorellini minuti che in
	# un prato vero sta sempre sotto le margherite. È il calore basso del
	# cesto — quello che si vede fra uno stelo e l'altro invece del verde
	# nudo. Ogni testa è un mesh solo (venti fiorellini cuciti insieme:
	# venti nodi per pianta sarebbero cento nodi per una macchia rosa
	# grande come un'unghia).
	var ombrelle: Array = [_cesto_ombrello_mesh(7), _cesto_ombrello_mesh(23),
			_cesto_ombrello_mesh(53)]
	var achi: Array = [_mat(Color("eda2a6"), Color("cd8086"), 9.0, 0.34, 0.20),
			_mat(Color("f2a583"), Color("d18062"), 9.0, 0.34, 0.20),
			_mat(Color("f8e0c2"), Color("ddbf99"), 9.0, 0.32, 0.22)]
	for a in [[-0.290, -0.062, 0.118, 0], [-0.108, -0.078, 0.132, 1],
			[0.016, 0.062, 0.104, 2], [0.166, -0.052, 0.126, 0],
			[0.276, 0.070, 0.110, 1], [0.372, -0.028, 0.096, 2]]:
		var axx := float(a[0])
		var azz := float(a[1])
		_cesto_achillea(n, rng, Vector3(axx, float(terra_h.call(axx, azz)) - 0.006, azz),
				float(a[2]), ombrelle[int(a[3])], achi[int(a[3])],
				tav, lance_min)

	# ---- IL TRIFOGLIO: le teste tonde e pelose, bassissime, appoggiate
	# sul muschio. Un cuscinetto rosa sotto un cuscinetto pallido: è così
	# che si legge una testa di trifoglio, e sono gli stessi stampi del
	# muschio (ogni forma nuova è una forma da mantenere)
	var trif := _mat(Color("e79ab4"), Color("c47a94"), 10.0, 0.4, 0.18)
	var trif_pal := _mat(Color("f7d3de"), Color("dcaebe"), 10.0, 0.36, 0.22)
	for tf in [[-0.246, 0.084, 0.062], [-0.020, -0.086, 0.070],
			[0.098, 0.088, 0.058], [0.232, -0.078, 0.066],
			[-0.126, 0.046, 0.054], [0.320, 0.028, 0.060]]:
		var tx := float(tf[0])
		var tz := float(tf[1])
		_cesto_trifoglio(n, rng, Vector3(tx, float(terra_h.call(tx, tz)) - 0.004, tz),
				float(tf[2]), cuscini, trif, trif_pal, tav, lobate)

	# ---- LE SPIGHE candide: riempiono l'aria fra le corolle senza pesare.
	# Restano tre — l'aria bianca è quella che tiene il mazzo un PRATO
	# raccolto e non un bouquet; di più, e il pezzo torna freddo.
	for sp in [[-0.204, 0.064, 0.212, "f4ecdc"], [0.086, -0.024, 0.226, "faf4e8"],
			[0.242, 0.074, 0.178, "cdbbe4"]]:
		var sx2 := float(sp[0])
		var sz2 := float(sp[1])
		_cesto_spiga(n, rng, Vector3(sx2, float(terra_h.call(sx2, sz2)) - 0.008, sz2),
				float(sp[2]), Color(str(sp[3])), tav, lance_min)

	# ---- i ciuffi d'erba: cinque fili per ciuffo, arcuati e mai allo
	# stesso angolo. Hanno il vento del handpaint addosso (sono mesh
	# INTERE, con la base a quota zero: l'ondina cresce col quadrato
	# dell'altezza e non stacca niente da niente — per questo l'erba NON si
	# può cucire in un mesh solo col resto: il vento leggerebbe la quota
	# del cesto invece di quella del filo)
	var erba := _mat(Color("8cb45f"), Color("6b9243"), 7.0, 0.5)
	erba.set_shader_parameter("wind_strength", 0.9)
	for c in [[-0.330, -0.068], [-0.244, 0.020], [-0.144, -0.078],
			[-0.048, 0.018], [0.048, 0.082], [0.158, -0.082],
			[0.264, 0.070], [0.348, -0.066]]:
		var cx3 := float(c[0])
		var cz3 := float(c[1])
		var ciuffo := Node3D.new()
		ciuffo.position = Vector3(cx3, float(terra_h.call(cx3, cz3)) - 0.004, cz3)
		ciuffo.rotation.y = rng.randf() * TAU
		n.add_child(ciuffo)
		for f4 in 5:
			var giro4 := TAU * float(f4) / 5.0 + rng.randf_range(-0.4, 0.4)
			var alt4 := rng.randf_range(0.050, 0.105)
			var apre := rng.randf_range(0.028, 0.056)
			var d4 := Vector3(cos(giro4), 0, sin(giro4))
			BUILDER.tube(ciuffo, [Vector3.ZERO,
					d4 * (apre * 0.22) + Vector3(0, alt4 * 0.5, 0),
					d4 * (apre * 0.72) + Vector3(0, alt4 * 0.92, 0),
					d4 * apre + Vector3(0, alt4, 0)],
					[0.0030, 0.0024, 0.0015, 0.0004], erba, 10, 4)

	# ---- LE RICADUTE: cinque tralci d'edera che scavalcano la treccia e
	# scendono davanti all'intreccio con i lembi appoggiati alla parete.
	# Rompono la linea del bordo — è la seconda metà del trabocco: la
	# ghirlanda si mangia il cordolo, l'edera scende fino a metà cesto.
	# Si agganciano a un PUNTO DEL CONTORNO, non a una z fissa: sui
	# fianchi la parete rientra, e un ramo appeso alla profondità massima
	# restava sepolto nel vimine da un lato e sporgeva fuori sagoma
	# dall'altro.
	for rc in [[0.680, -1.0], [0.828, 1.0], [0.316, 1.0], [0.185, -1.0],
			[0.545, 1.0], [0.735, 1.0], [0.258, -1.0]]:
		var ir := int(float(rc[0]) * float(np)) % np
		_cesto_ricaduta(n, rng, giro[ir] as Vector2, nor[ir] as Vector2,
				qh, svaso, float(rc[1]), tav, edera, verdi_bordo)
	return n


## Il contorno del cesto campionato a passo di ARCO COSTANTE, con la
## normale uscente punto per punto. Che sia costante è il perno di tutto:
## i montanti si piantano a distanza uguale e l'onda del vimine deve
## arrivare in fase su OGNUNO — con la parametrizzazione ingenua della
## superellisse i punti si affollano agli angoli e l'intreccio va fuori
## passo proprio dove il pezzo si guarda meglio, di tre quarti.
##
## `quadro` è la QUADRATURA: il contorno è la superellisse
## |x/ax|^n + |z/az|^n = 1 con n = 2/quadro. A 0.66 (n = 3) su un
## rapporto di quasi tre a uno le due teste finiscono a punta e il cesto
## legge come una gondola; a 0.42 (n = 4.76) è un rettangolo con gli
## angoli molto tondi — a nove decimi della lunghezza è ancora largo
## l'83%, contro il 65% di prima. È tutto lì il difetto della canoa.
static func _cesto_giro(np: int, ax: float, az: float, quadro := 0.36) -> Array:
	var fitto := 960
	var grezzo: Array[Vector2] = []
	for i in fitto:
		var u := TAU * float(i) / float(fitto)
		grezzo.append(Vector2(signf(cos(u)) * pow(absf(cos(u)), quadro) * ax,
				signf(sin(u)) * pow(absf(sin(u)), quadro) * az))
	var lungo := PackedFloat32Array()
	var tot := 0.0
	for i in fitto:
		lungo.append(tot)
		tot += grezzo[i].distance_to(grezzo[(i + 1) % fitto])
	var punti: Array[Vector2] = []
	var k := 0
	for i in np:
		var meta := tot * float(i) / float(np)
		while k < fitto - 1 and lungo[k + 1] < meta:
			k += 1
		var a: Vector2 = grezzo[k]
		var b: Vector2 = grezzo[(k + 1) % fitto]
		var d := maxf(a.distance_to(b), 1e-6)
		punti.append(a.lerp(b, clampf((meta - lungo[k]) / d, 0.0, 1.0)))
	var nor: Array[Vector2] = []
	for i in np:
		var t := (punti[(i + 1) % np] - punti[(i - 1 + np) % np]).normalized()
		nor.append(Vector2(t.y, -t.x))
	return [punti, nor]


## UN VIMINE: il tondo spazzato lungo un percorso, chiuso ad anello (le
## file dell'intreccio, i capi della treccia) oppure aperto e rastremato
## (i montanti, la fune dei manici). Il frame è trasportato dalla
## tangente, così il tondo non ruota lungo il percorso; le estremità
## aperte si chiudono a punta, perché un vimine tagliato di netto è un
## tubo e da vicino si vede il buco.
static func _cesto_vimine(parent: Node3D, percorso: PackedVector3Array,
		r0: float, r1: float, mat: Material, lati := 6,
		chiuso := true) -> MeshInstance3D:
	var np := percorso.size()
	var righe := np + 1 if chiuso else np
	var vg: Array = []
	for i in righe:
		var ii := i % np
		var prima := (ii - 1 + np) % np if chiuso else maxi(ii - 1, 0)
		var dopo := (ii + 1) % np if chiuso else mini(ii + 1, np - 1)
		var t := (percorso[dopo] - percorso[prima]).normalized()
		var lato := t.cross(Vector3.UP)
		if lato.length_squared() < 1e-8:
			lato = t.cross(Vector3.RIGHT)
		lato = lato.normalized()
		var alza := lato.cross(t).normalized()
		var r := r0 if chiuso else lerpf(r0, r1, float(ii) / float(maxi(np - 1, 1)))
		if not chiuso and i == 0:
			var tappo0 := PackedVector3Array()
			for j in lati:
				tappo0.append(percorso[0] - t * (r * 0.7))
			vg.append(tappo0)
		var riga := PackedVector3Array()
		for j in lati:
			var a := TAU * float(j) / float(lati)
			riga.append(percorso[ii] + (lato * cos(a) + alza * sin(a)) * r)
		vg.append(riga)
		if not chiuso and i == righe - 1:
			var tappo1 := PackedVector3Array()
			for j in lati:
				tappo1.append(percorso[np - 1] + t * (r * 0.7))
			vg.append(tappo1)
	return _mesh_griglia(parent, vg, mat, Vector3.ZERO, true)


## IL MANICO, e le tre cose che glielo fanno leggere.
## 1. LA GROSSEZZA. La prima stesura era una funicella da otto millimetri:
##    di fronte, dove l'arco si vede quasi di taglio, le spire del ritorto
##    diventavano i denti di un pettine. Un manico si riconosce perché ci
##    passa la mano — quindi è grosso (qui 42 mm) e il ritorto è LENTO
##    (cinque giri su tutto l'arco): spire fitte su una fune sottile sono
##    una filettatura, non una corda.
## 2. LA FASCIATURA. I due piedi entrano sotto il cordolo e lì sono
##    LEGATI, con sei giri stretti di vimine attorno alla fune. È l'unico
##    dettaglio che dice «attaccato»: una corda che finisce in aria è una
##    maniglia di plastica incollata al bordo.
## 3. L'ALZATA. L'arco sale di quindici centimetri sopra la treccia e
##    resta dentro la sagoma del cesto in pianta: un manico che sporge in
##    fuori ruba il posto ai vicini nella cella.
static func _cesto_manico(parent: Node3D, sx: float, xr: float, qh: float,
		fune: Material, legaccio: Material) -> void:
	# L'APICE STA BASSO. A qh + 0.156 il manico usciva sopra la massa
	# fiorita e dal FRONTE — dove lo si vede di taglio — restavano due
	# virgole pallide ai lati della sagoma, senza il buco sotto l'arco che
	# le avrebbe fatte leggere come manici. Sceso a qh + 0.088 sparisce
	# dentro il verde di fronte, e di profilo (dove il buco si vede) resta
	# tutto: e' li' che un manico dice di essere un manico.
	var zb := 0.078
	var a0 := Vector3(sx * xr * 0.94, qh - 0.034, -zb)
	var a1 := Vector3(sx * (xr + 0.010), qh + 0.088, -zb * 0.66)
	var a2 := Vector3(sx * (xr + 0.010), qh + 0.088, zb * 0.66)
	var a3 := Vector3(sx * xr * 0.94, qh - 0.034, zb)
	var arco := func(t: float) -> Vector3:
		var u := 1.0 - t
		return (a0 * (u * u * u) + a1 * (3.0 * u * u * t)
				+ a2 * (3.0 * u * t * t) + a3 * (t * t * t))
	# il frame lungo l'arco: serve ai capi ritorti e alle fasciature
	var telaio := func(t: float) -> Array:
		var p: Vector3 = arco.call(t)
		var tg: Vector3 = ((arco.call(minf(t + 0.02, 1.0))
				- arco.call(maxf(t - 0.02, 0.0))) as Vector3).normalized()
		var lato := tg.cross(Vector3.UP)
		if lato.length_squared() < 1e-8:
			lato = tg.cross(Vector3.RIGHT)
		lato = lato.normalized()
		return [p, lato, lato.cross(tg).normalized()]
	for capo in 3:
		var perc := PackedVector3Array()
		for i in 56:
			var t := float(i) / 55.0
			var tl: Array = telaio.call(t)
			var f := t * TAU * 3.5 + TAU / 3.0 * float(capo)
			# la fune si assottiglia dentro la fasciatura: entra sotto il
			# cordolo, non ci si appoggia sopra
			var stretta := 1.0 - 0.34 * pow(maxf(absf(t - 0.5) * 2.0 - 0.80, 0.0)
					/ 0.20, 2.0)
			perc.append((tl[0] as Vector3)
					+ ((tl[1] as Vector3) * cos(f) + (tl[2] as Vector3) * sin(f))
					* (0.0158 * stretta))
		# I TRE CAPI DEVONO RESTARE TRE. Con tubo 0.0108 su un cerchio di
		# ritorto 0.0122 i capi si compenetravano in una massa piena
		# scanalata: una conchiglia, non una corda. Il rapporto giusto e'
		# raggio del giro ~2x il raggio del capo — cosi' fra un capo e
		# l'altro resta il solco, che e' l'unica cosa che dice «ritorta».
		_cesto_vimine(parent, perc, 0.0079, 0.0079, fune, 8, false)
	# LE FASCIATURE: sei giri stretti attorno alla fune, appena sopra i
	# piedi. Un'elica vera, non un anello: un toro liscio a mezz'aria
	# leggerebbe come una ghiera di metallo.
	for piede in 2:
		var t0 := 0.045 if piede == 0 else 0.865
		var perc2 := PackedVector3Array()
		for i in 46:
			var u := float(i) / 45.0
			var t := t0 + u * 0.090
			var tl2: Array = telaio.call(t)
			var f2 := u * TAU * 4.0
			perc2.append((tl2[0] as Vector3)
					+ ((tl2[1] as Vector3) * cos(f2) + (tl2[2] as Vector3) * sin(f2))
					* 0.0262)
		# LA FASCIATURA VA FUORI DALLA FUNE. Stava a 0.0162 + 0.0046 =
		# 0.0208 dall'asse mentre la fune arrivava a 0.0230: il legaccio
		# era SEPOLTO dentro la corda che doveva legare, e in sei viste
		# non se ne vedeva un giro. Ora la fune arriva a 0.0237 e l'elica
		# gira a 0.0262 + 0.0052: si posa sopra, come una legatura vera.
		_cesto_vimine(parent, perc2, 0.0052, 0.0052, legaccio, 5, false)


## UN LEMBO CURVO — la foglia che non è un adesivo.
## Il contorno (in millimetri, con l'attacco all'origine e la lamina che
## cresce verso +X) si riempie a corone concentriche che convergono sul
## PICCIOLO, e la quota di ogni punto è
##     y = −curva·ρ²  −  carena·|ρ.y|
## cioè: la punta CADE (è il peso della foglia) e la mezzeria sta più in
## alto dei bordi (è la nervatura, fatta di forma e non di colore). Le due
## leggi insieme danno una superficie a sella dolce su cui la luce SCORRE.
## Era questo che mancava: i lembi erano prismi estrusi, e dall'alto un
## prisma verde posato orizzontale è una lastra — leggeva come vetro, o
## come una toppa cucita sul muschio. Un mesh invece di tre, per giunta.
static func _cesto_lembo_mesh(contorno: Array, curva: float, carena: float,
		anelli := 2, doppia := true) -> ArrayMesh:
	var vg: Array = []
	for k in anelli + 1:
		var t := float(k) / float(anelli)
		var riga := PackedVector3Array()
		for p in contorno:
			var rho: Vector2 = (p as Vector2) * t
			riga.append(Vector3(rho.x,
					-curva * rho.length_squared() - carena * absf(rho.y), rho.y))
		vg.append(riga)
	var scarto := Node3D.new()
	var mi := _mesh_griglia(scarto, vg, null, Vector3.ZERO, true, doppia)
	var mesh: ArrayMesh = mi.mesh
	scarto.free()
	return mesh


## Il contorno DELL'EDERA e delle piante che ricadono dai vasi: lobi veri,
## seni profondi, il lobo di punta più lungo degli altri e il SENO BASALE
## a cuore dalla parte del picciolo.
## `prof` è quanto scende il seno: la prima stesura era a 0.115, cioè una
## rotellina appena ondulata — e a livello d'occhio del giocatore quelle
## foglie appese al vimine si leggevano come DISCHI verdi incollati sulla
## paglia. Un contorno è la firma di una pianta: se lo si smussa per
## prudenza, resta un bottone. Qui il seno arriva a poco più di metà
## raggio, e `pow(c, 0.42)` allarga i lobi tenendo i seni stretti — è la
## differenza fra una foglia e una margherita di cartone.
## Il centro sta a 0.94·raggio dall'origine, così il seno basale tocca
## l'attacco del picciolo.
static func _cesto_lobi(raggio: float, lobi: int, prof: float, passi: int) -> Array:
	var out: Array = []
	for i in passi:
		var a := TAU * float(i) / float(passi)
		var c := 0.5 + 0.5 * cos(float(lobi) * a)
		var rr := raggio * (1.0 - prof + prof * pow(c, 0.42))
		# il lobo di PUNTA è più lungo: una foglia non è un rosone
		rr *= 1.0 + 0.20 * exp(-(a if a < PI else TAU - a) * (a if a < PI else TAU - a) / 0.36)
		# e il seno basale rientra dalla parte del picciolo
		var d := absf(wrapf(a - PI, -PI, PI))
		rr *= 1.0 - 0.32 * exp(-(d * d) / 0.12)
		out.append(Vector2(raggio * 0.94 + cos(a) * rr, sin(a) * rr))
	return out


## Il contorno LANCEOLATO: largo a un terzo, punta fine, base all'origine.
## Si campiona il dorso e poi si torna indietro sul ventre, senza ripetere
## i due capi (l'anello si chiude da solo in `_mesh_griglia`).
static func _cesto_lancia(lung: float, larg: float, passi: int) -> Array:
	var out: Array = []
	for i in passi:
		var t := float(i) / float(passi - 1)
		out.append(Vector2(lung * t, larg * pow(sin(PI * pow(t, 0.70)), 0.80)))
	for i in range(passi - 2, 0, -1):
		var t2 := float(i) / float(passi - 1)
		out.append(Vector2(lung * t2, -larg * pow(sin(PI * pow(t2, 0.70)), 0.80)))
	return out


static func _cesto_lembo(parent: Node3D, mesh: Mesh, mat: Material,
		pos: Vector3, rot: Vector3, taglia := 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = Vector3.ONE * taglia
	parent.add_child(mi)
	return mi


## LA CAMPANULA: una superficie di rivoluzione MODULATA A LOBI — il raggio
## del profilo moltiplicato per (1 + amp·cos(lobi·θ)). È questa moltipli-
## cazione a fare la differenza fra una campanula e un ditale: cinque lobi
## che nascono all'attacco, si aprono scendendo e si ripiegano sul labbro
## (le ultime due stazioni RIENTRANO: il bordo di un fiore ha spessore).
## Il fiore PENDE, quindi il profilo scende da y 0 — il peduncolo — verso
## il basso. Un mesh solo, instanziato dieci volte con scarti di taglia.
static func _cesto_campanella(lobi: int, colonne := 18) -> ArrayMesh:
	var prof: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(0.0032, -0.0035),
			Vector2(0.0072, -0.0090), Vector2(0.0112, -0.0170),
			Vector2(0.0143, -0.0250), Vector2(0.0164, -0.0325),
			Vector2(0.0179, -0.0390), Vector2(0.0176, -0.0437),
			Vector2(0.0148, -0.0458), Vector2(0.0104, -0.0432)]
	var amp: Array[float] = [0.0, 0.03, 0.07, 0.11, 0.15, 0.185, 0.21, 0.21,
			0.18, 0.13]
	var vg: Array = []
	for i in prof.size():
		var p := prof[i]
		var riga := PackedVector3Array()
		for j in colonne:
			var a := TAU * float(j) / float(colonne)
			var r := p.x * (1.0 + amp[i] * cos(float(lobi) * a))
			riga.append(Vector3(cos(a) * r, p.y, sin(a) * r))
		vg.append(riga)
	# il mesh serve NUDO: si costruisce su un nodo di servizio e si tiene
	# solo la risorsa (la mesh è un Ref, sopravvive al nodo)
	var scarto := Node3D.new()
	var mi := _mesh_griglia(scarto, vg, null, Vector3.ZERO, true, true)
	var mesh: ArrayMesh = mi.mesh
	scarto.free()
	return mesh


## UN CUSCINETTO DI MUSCHIO: un ellissoide col raggio gonfiato da due seni
## incommensurabili, che si spengono ai poli (se non si spengono la
## calotta esce dentellata). Una sfera schiacciata è una bolla verde; il
## muschio è irregolare, ed è l'irregolarità a farlo leggere.
static func _cesto_cuscino(seme: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seme
	var lati := 10
	var file := 4
	var f1 := rng.randf_range(2.0, 3.0)
	var f2 := rng.randf_range(4.0, 6.0)
	var p1 := rng.randf() * TAU
	var p2 := rng.randf() * TAU
	var vg: Array = []
	for i in file + 1:
		var v := PI * float(i) / float(file)
		var riga := PackedVector3Array()
		for j in lati:
			var u := TAU * float(j) / float(lati)
			var r := 1.0 + sin(v) * (0.12 * sin(u * f1 + p1)
					+ 0.07 * sin(u * f2 + p2))
			riga.append(Vector3(sin(v) * cos(u) * r, cos(v) * r, sin(v) * sin(u) * r))
		vg.append(riga)
	var scarto := Node3D.new()
	var mi := _mesh_griglia(scarto, vg, null, Vector3.ZERO, true)
	var mesh: ArrayMesh = mi.mesh
	scarto.free()
	return mesh


static func _cesto_puff(parent: Node3D, mesh: Mesh, mat: Material,
		pos: Vector3, scl: Vector3, giro := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	mi.rotation.y = giro
	parent.add_child(mi)
	return mi


## LA COROLLA DELLA MARGHERITA, cucita in un mesh solo.
## I petali sono gli stessi di prima — sagome estruse, strette all'attacco
## e tonde in punta, ognuna col suo giro, la sua piega e la sua taglia, e
## una su quattro che cade più delle altre (una ruota perfetta di petali
## identici non è un fiore, è un ingranaggio). La differenza è che invece
## di nove nodi per corolla se ne costruisce UNO: le sagome si appendono a
## una `SurfaceTool` con la loro trasformata e si commissionano insieme.
## Su dieci margherite sono ottanta nodi risparmiati, e la resa è
## IDENTICA — la stessa geometria, negli stessi posti.
## Gli stampi si fanno in quattro varianti e si tingono per istanza: la
## stessa corolla esce bianca, crema o rosa senza costare un mesh in più.
static func _cesto_corolla_mesh(seme: int, petali: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seme
	var scarto := Node3D.new()
	var sagoma := _prisma(scarto, [Vector2(0.005, 0.0), Vector2(0.012, 0.0088),
			Vector2(0.023, 0.0114), Vector2(0.034, 0.0106),
			Vector2(0.0425, 0.0058), Vector2(0.0450, 0.0),
			Vector2(0.0425, -0.0058), Vector2(0.034, -0.0106),
			Vector2(0.023, -0.0114), Vector2(0.012, -0.0088)],
			0.0, 0.0032, null)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in petali:
		var tr := Transform3D.IDENTITY
		tr = tr.rotated_local(Vector3.UP,
				TAU * float(k) / float(petali) + rng.randf_range(-0.09, 0.09))
		tr = tr.translated_local(Vector3(0.0085, 0.0008, 0.0))
		var piega := 0.17 + rng.randf_range(-0.07, 0.11)
		if k % 4 == 2:
			piega -= 0.30
		tr = tr.rotated_local(Vector3(0, 0, 1), piega)
		tr = tr.scaled_local(Vector3(rng.randf_range(0.90, 1.08), 1.0,
				rng.randf_range(0.88, 1.10)))
		st.append_from(sagoma.mesh, 0, tr)
	var mesh: ArrayMesh = st.commit()
	scarto.free()
	return mesh


## L'OMBRELLA DELL'ACHILLEA: venti fiorellini minuti su una calotta quasi
## PIATTA (è il corimbo — i pedicelli di fuori sono più lunghi e arrivano
## tutti alla stessa quota: per questo l'achillea sembra un piattino).
## Disposti in fillotassi, non a caso e non in anelli: l'angolo aureo è
## l'unica semina che non lascia buchi e non fa reticolo.
## Cuciti in un mesh solo: venti nodi per una macchia grande come
## un'unghia sarebbero centoventi nodi per il cesto.
static func _cesto_ombrello_mesh(seme: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seme
	var globo := _cesto_globo(6, 3)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var quanti := 16
	for i in quanti:
		var t := float(i) / float(quanti - 1)
		var rr := 0.0265 * sqrt(t) * rng.randf_range(0.90, 1.08)
		var a := float(i) * 2.399963 + rng.randf_range(-0.10, 0.10)
		var s := 0.0060 * (1.0 - 0.22 * t) * rng.randf_range(0.86, 1.14)
		var p := Vector3(cos(a) * rr, 0.0062 * (1.0 - t * t)
				+ rng.randf_range(-0.0012, 0.0012), sin(a) * rr)
		st.append_from(globo, 0,
				Transform3D(Basis().scaled(Vector3(s, s * 0.58, s)), p))
	return st.commit()


## Un globo a poche facce fatto con la stessa fabbrica di tutto il resto
## (`_mesh_griglia`): serve perché le sfere di Godot portano UV e tangenti
## e non si possono CUCIRE con le sagome fatte a mano — `append_from`
## vuole lo stesso formato di vertice, altrimenti l'ombrella esce vuota.
static func _cesto_globo(lati: int, file: int) -> ArrayMesh:
	var vg: Array = []
	for i in file + 1:
		var v := PI * float(i) / float(file)
		var riga := PackedVector3Array()
		for j in lati:
			var u := TAU * float(j) / float(lati)
			riga.append(Vector3(sin(v) * cos(u), cos(v), sin(v) * sin(u)))
		vg.append(riga)
	var scarto := Node3D.new()
	var mi := _mesh_griglia(scarto, vg, null, Vector3.ZERO, true)
	var mesh: ArrayMesh = mi.mesh
	scarto.free()
	return mesh


## UNA MARGHERITA di campo: lo stelo che sale con un filo di S, le foglie
## lanceolate alla base, e la corolla — un mesh cucito, tinto per istanza
## (bianco panna, crema-albicocca o rosa carico), col ricettacolo verde
## sotto e il cuore a due toni sopra.
## `fuga` è di quanto la CIMA scappa via dalla base in pianta: a zero il
## fiore sta sopra le sue radici, e con qualche centimetro il gambo si
## sporge oltre il cordolo. È la leva del trabocco — ma si spende solo
## lungo la lunghezza del cesto: una corolla è larga quattro centimetri e
## mezzo e sporta di fianco esce dalla cella.
static func _cesto_margherita(parent: Node3D, rng: RandomNumberGenerator,
		base: Vector3, alt: float, tav: Dictionary, lance: Array,
		corolla_mesh: Mesh, tinta: Material, fuga := Vector2.ZERO) -> void:
	var verde: Material = tav["verde"]
	var pianta := Node3D.new()
	pianta.position = base
	pianta.rotation.y = rng.randf() * TAU
	parent.add_child(pianta)
	# la fuga è in coordinate del MONDO: si toglie il giro della pianta,
	# altrimenti lo stelo si sporge da una parte a caso
	var fg := Vector2(fuga.x, fuga.y).rotated(pianta.rotation.y)
	var pend := Vector2(rng.randf_range(-0.05, 0.05), rng.randf_range(-0.05, 0.05))
	var cima := Vector3(pend.x * alt + fg.x, alt, pend.y * alt + fg.y)
	BUILDER.tube(pianta, [Vector3.ZERO,
			Vector3(cima.x * 0.26 - 0.008, alt * 0.34, cima.z * 0.26 + 0.006),
			Vector3(cima.x * 0.66, alt * 0.71, cima.z * 0.66), cima],
			[0.0058, 0.0048, 0.0040, 0.0033], verde, 14, 6)
	for j in 2:
		_cesto_lembo(pianta, lance[(j + rng.randi() % 3) % 4],
				tav["verde"] if j == 0 else tav["verde_tenero"],
				Vector3(0.004, alt * (0.14 + 0.24 * float(j)), 0.002),
				Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU,
				rng.randf_range(-0.12, 0.50)), rng.randf_range(0.80, 1.05))
	var corolla := Node3D.new()
	corolla.position = cima + Vector3(0, 0.005, 0)
	corolla.rotation = Vector3(rng.randf_range(-0.26, 0.10), rng.randf() * TAU,
			rng.randf_range(-0.20, 0.20))
	corolla.scale = Vector3.ONE * rng.randf_range(0.88, 1.14)
	pianta.add_child(corolla)
	# il ricettacolo verde SOTTO: all'occhio del giocatore (12 cm da terra)
	# un fiore si guarda anche da sotto, e sotto un fiore non c'è il retro
	# giallo del cuore
	_cesto_puff(corolla, tav["puff"], tav["verde_tenero"], Vector3(0, -0.0042, 0),
			Vector3(0.0150, 0.0080, 0.0150))
	var pet := MeshInstance3D.new()
	pet.mesh = corolla_mesh
	pet.material_override = tinta
	corolla.add_child(pet)
	# il cuore: la cupola gialla e una calotta più cupa sopra (i fiorellini
	# del disco sono più fitti al centro)
	_cesto_puff(corolla, tav["puff"], tav["cuore"], Vector3(0, 0.0026, 0),
			Vector3(0.0172, 0.0078, 0.0172))
	_cesto_puff(corolla, tav["puff"], tav["cuore_cupo"], Vector3(0, 0.0058, 0),
			Vector3(0.0108, 0.0058, 0.0108))


## UN BOCCIO ancora chiuso: l'ovetto verde stretto nei sepali, con appena
## una punta di petalo che sbuca — della stessa tinta della margherita che
## diventerà. Serve al ritmo: una fioriera dove tutto è aperto insieme è
## un centrotavola, non una pianta che vive.
static func _cesto_boccio(parent: Node3D, rng: RandomNumberGenerator,
		base: Vector3, alt: float, tav: Dictionary, lance: Array,
		tinta: Material) -> void:
	var verde: Material = tav["verde"]
	var pianta := Node3D.new()
	pianta.position = base
	pianta.rotation.y = rng.randf() * TAU
	parent.add_child(pianta)
	var china := rng.randf_range(0.02, 0.06)
	var cima := Vector3(china * alt, alt, 0.004)
	BUILDER.tube(pianta, [Vector3.ZERO,
			Vector3(china * alt * 0.4, alt * 0.5, 0.002), cima],
			[0.0052, 0.0042, 0.0034], verde, 10, 6)
	_cesto_lembo(pianta, lance[rng.randi() % 4], tav["verde"],
			Vector3(0.004, alt * 0.3, 0.0),
			Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU,
			rng.randf_range(-0.1, 0.4)), rng.randf_range(0.72, 0.92))
	var testa := Node3D.new()
	testa.position = cima
	testa.rotation.z = -rng.randf_range(0.10, 0.34)
	pianta.add_child(testa)
	_cesto_puff(testa, tav["puff"], tav["verde_tenero"], Vector3(0, 0.011, 0),
			Vector3(0.0115, 0.0165, 0.0115))
	_cesto_puff(testa, tav["puff"], tinta, Vector3(0, 0.0245, 0),
			Vector3(0.0064, 0.0060, 0.0064))
	for k in 4:
		var sep := Node3D.new()
		sep.position = Vector3(0, 0.006, 0)
		sep.rotation.y = TAU * float(k) / 4.0 + rng.randf_range(-0.2, 0.2)
		testa.add_child(sep)
		var sf := _prisma(sep, [Vector2(0.0, 0.0), Vector2(0.010, 0.0052),
				Vector2(0.020, 0.0022), Vector2(0.023, 0.0),
				Vector2(0.020, -0.0022), Vector2(0.010, -0.0052)],
				0.0, 0.0030, verde)
		sf.rotation.z = 1.02 + rng.randf_range(-0.12, 0.12)


## LE CAMPANULE su un tralcio ARCUATO: sale, si piega in fuori e la punta
## ricade. Le campane pendono dalla metà alta, una per volta, col
## peduncolo che si incurva — e rimpiccioliscono verso la punta, come in
## un racemo vero. Ognuna col suo scarto di taglia e di pendolo: cinque
## campane identiche appese in fila sono un lampadario.
static func _cesto_campanule(parent: Node3D, rng: RandomNumberGenerator,
		base: Vector3, verso: Vector2, alt: float, sporgenza: float,
		quante: int, campana: Mesh, tinta: Material, tav: Dictionary,
		lance: Array) -> void:
	var verde: Material = tav["verde"]
	var verde_cupo: Material = tav["verde_cupo"]
	var d3 := Vector3(verso.x, 0.0, verso.y).normalized()
	var lat := Vector3(-d3.z, 0.0, d3.x)
	var p0 := Vector3.ZERO
	var p1 := Vector3(0, alt * 1.00, 0) + d3 * (sporgenza * 0.10)
	var p2 := Vector3(0, alt * 1.06, 0) + d3 * (sporgenza * 0.56)
	var p3 := Vector3(0, alt * 0.80, 0) + d3 * sporgenza
	var arco := func(t: float) -> Vector3:
		var u := 1.0 - t
		return (p0 * (u * u * u) + p1 * (3.0 * u * u * t)
				+ p2 * (3.0 * u * t * t) + p3 * (t * t * t))
	var pianta := Node3D.new()
	pianta.position = base
	parent.add_child(pianta)
	var ctrl: Array = []
	var raggi: Array = []
	for j in 9:
		ctrl.append(arco.call(float(j) / 8.0))
		raggi.append(lerpf(0.0062, 0.0022, float(j) / 8.0))
	BUILDER.tube(pianta, ctrl, raggi, verde, 24, 6)
	# le foglie basali, lunghe e ricadenti: senza, il tralcio è un filo
	for j2 in 3:
		_cesto_lembo(pianta, lance[(j2 + 1) % 4],
				verde if j2 % 2 == 0 else tav["verde_tenero"],
				Vector3(0.003, alt * (0.08 + 0.15 * float(j2)), 0.0),
				Vector3(rng.randf_range(-0.5, 0.5), rng.randf() * TAU,
				rng.randf_range(-0.20, 0.45)), rng.randf_range(0.86, 1.10))
	for k in quante:
		var t := lerpf(0.42, 0.95, float(k) / float(maxi(quante - 1, 1)))
		var attacco: Vector3 = arco.call(t)
		var giu := 0.026 + 0.014 * (1.0 - t)
		var fuori := (d3 * rng.randf_range(0.004, 0.014)
				+ lat * rng.randf_range(-0.014, 0.014))
		var fine := attacco + fuori + Vector3(0, -giu, 0)
		BUILDER.tube(pianta, [attacco,
				attacco + fuori * 0.65 + Vector3(0, -giu * 0.42, 0), fine],
				[0.0028, 0.0022, 0.0017], verde_cupo, 10, 5)
		var fiore := MeshInstance3D.new()
		fiore.mesh = campana
		fiore.material_override = tinta
		fiore.position = fine + Vector3(0, 0.001, 0)
		fiore.scale = Vector3.ONE * (rng.randf_range(0.90, 1.10) * (1.10 - 0.34 * t))
		fiore.rotation = Vector3(rng.randf_range(-0.24, 0.24), rng.randf() * TAU,
				rng.randf_range(-0.24, 0.24))
		pianta.add_child(fiore)


## L'ACHILLEA: lo stelo diritto e nervoso, le foglioline finissime attorno,
## e in cima l'ombrella piatta (più una seconda, minore, su un rametto).
## È il fiorellino minuto e CALDO del sottobosco: sta sotto le margherite,
## si vede fra uno stelo e l'altro, e riempie di rosa quello che prima era
## verde nudo.
static func _cesto_achillea(parent: Node3D, rng: RandomNumberGenerator,
		base: Vector3, alt: float, testa: Mesh, tinta: Material,
		tav: Dictionary, lance_min: Array) -> void:
	var verde: Material = tav["verde"]
	var pianta := Node3D.new()
	pianta.position = base
	pianta.rotation.y = rng.randf() * TAU
	parent.add_child(pianta)
	var china := Vector2(rng.randf_range(-0.05, 0.05), rng.randf_range(-0.05, 0.05))
	var cima := Vector3(china.x * alt, alt, china.y * alt)
	BUILDER.tube(pianta, [Vector3.ZERO,
			Vector3(cima.x * 0.34, alt * 0.42, cima.z * 0.34),
			Vector3(cima.x * 0.72, alt * 0.76, cima.z * 0.72), cima],
			[0.0040, 0.0033, 0.0028, 0.0024], verde, 12, 5)
	for j in 3:
		_cesto_lembo(pianta, lance_min[j % 2], tav["verde_oliva"],
				Vector3(0.002, alt * (0.16 + 0.20 * float(j)), 0.0),
				Vector3(rng.randf_range(-0.6, 0.6), rng.randf() * TAU,
				rng.randf_range(0.10, 0.62)), rng.randf_range(0.80, 1.10))
	var om := MeshInstance3D.new()
	om.mesh = testa
	om.material_override = tinta
	om.position = cima + Vector3(0, 0.004, 0)
	om.rotation = Vector3(rng.randf_range(-0.22, 0.22), rng.randf() * TAU,
			rng.randf_range(-0.22, 0.22))
	om.scale = Vector3.ONE * rng.randf_range(0.90, 1.14)
	pianta.add_child(om)
	# la seconda ombrella, più bassa e più piccola: un'achillea vera si
	# ramifica, e una sola testa in cima a un filo è un chiodo
	var lato := Vector3(cos(rng.randf() * TAU), 0, sin(rng.randf() * TAU))
	var giu := alt * rng.randf_range(0.56, 0.72)
	var pf := lato * rng.randf_range(0.020, 0.032) + Vector3(0, giu + 0.014, 0)
	BUILDER.tube(pianta, [Vector3(china.x * giu, giu, china.y * giu),
			pf.lerp(Vector3(china.x * giu, giu, china.y * giu), 0.45), pf],
			[0.0026, 0.0021, 0.0017], verde, 8, 5)
	var om2 := MeshInstance3D.new()
	om2.mesh = testa
	om2.material_override = tinta
	om2.position = pf + Vector3(0, 0.003, 0)
	om2.rotation = Vector3(rng.randf_range(-0.26, 0.26), rng.randf() * TAU,
			rng.randf_range(-0.26, 0.26))
	om2.scale = Vector3.ONE * rng.randf_range(0.62, 0.78)
	pianta.add_child(om2)


## UNA TESTA DI TRIFOGLIO: due cuscinetti sovrapposti — quello di sotto
## rosa carico, quello di sopra pallido e più piccolo — su un gambo
## sottile, con la fogliolina alla base. Gli stampi sono gli stessi del
## muschio: una forma nuova è una forma da mantenere, e a un metro e mezzo
## una testa di trifoglio È un batuffolo irregolare.
static func _cesto_trifoglio(parent: Node3D, rng: RandomNumberGenerator,
		base: Vector3, alt: float, cuscini: Array, rosa: Material,
		pallido: Material, tav: Dictionary, lobate: Array) -> void:
	var pianta := Node3D.new()
	pianta.position = base
	pianta.rotation.y = rng.randf() * TAU
	parent.add_child(pianta)
	var china := Vector2(rng.randf_range(-0.10, 0.10), rng.randf_range(-0.10, 0.10))
	var cima := Vector3(china.x * alt, alt, china.y * alt)
	BUILDER.tube(pianta, [Vector3.ZERO,
			Vector3(cima.x * 0.40, alt * 0.50, cima.z * 0.40), cima],
			[0.0030, 0.0025, 0.0021], tav["verde"], 10, 5)
	var rr := rng.randf_range(0.0130, 0.0165)
	_cesto_puff(pianta, cuscini[rng.randi() % 3], rosa,
			cima + Vector3(0, rr * 0.72, 0),
			Vector3(rr, rr * 1.06, rr), rng.randf() * TAU)
	_cesto_puff(pianta, cuscini[rng.randi() % 3], pallido,
			cima + Vector3(0, rr * 1.32, 0),
			Vector3(rr * 0.66, rr * 0.58, rr * 0.66), rng.randf() * TAU)
	_cesto_lembo(pianta, lobate[rng.randi() % 5], tav["verde_tenero"],
			Vector3(0.002, alt * 0.34, 0.0),
			Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU,
			rng.randf_range(-0.05, 0.35)), rng.randf_range(0.42, 0.56))


## UNA SPIGA di fiorellini minuti: un'elica di bocciolini attorno alla
## metà alta dello stelo, che si stringe e rimpicciolisce verso la punta.
## Il passo dell'elica è incommensurabile col numero dei fiori, così non
## si richiude mai su sé stessa (una spirale che si richiude si legge come
## una molla).
static func _cesto_spiga(parent: Node3D, rng: RandomNumberGenerator,
		base: Vector3, alt: float, tinta: Color, tav: Dictionary,
		lance_min: Array) -> void:
	var verde: Material = tav["verde"]
	var pianta := Node3D.new()
	pianta.position = base
	pianta.rotation.y = rng.randf() * TAU
	parent.add_child(pianta)
	var china := Vector2(rng.randf_range(-0.09, 0.09), rng.randf_range(-0.07, 0.07))
	var cima := Vector3(china.x * alt, alt, china.y * alt)
	BUILDER.tube(pianta, [Vector3.ZERO,
			Vector3(cima.x * 0.36, alt * 0.4, cima.z * 0.36),
			Vector3(cima.x * 0.74, alt * 0.75, cima.z * 0.74), cima],
			[0.0044, 0.0036, 0.0030, 0.0024], verde, 12, 5)
	var mat := _mat(tinta, tinta.darkened(0.22), 6.0, 0.32, 0.22)
	var mat_cupo := _mat(tinta.darkened(0.16), tinta.darkened(0.34), 6.0, 0.3)
	var quanti := 12
	for k in quanti:
		var t := float(k) / float(quanti - 1)
		var y := lerpf(alt * 0.48, alt + 0.012, t)
		var f := t * 11.3 + rng.randf_range(-0.12, 0.12)
		var rr := 0.0165 * (1.0 - t) + 0.0035
		var q := Vector3(china.x * y + cos(f) * rr, y, china.y * y + sin(f) * rr)
		var s := 0.0078 * (1.0 - 0.42 * t) * rng.randf_range(0.85, 1.15)
		_cesto_puff(pianta, tav["puff"], mat if t < 0.82 else mat_cupo, q,
				Vector3(s, s * rng.randf_range(0.8, 1.1), s), rng.randf() * TAU)
	for j in 2:
		_cesto_lembo(pianta, lance_min[j % 2], tav["verde_oliva"],
				Vector3(0.003, alt * (0.14 + 0.16 * float(j)), 0.0),
				Vector3(rng.randf_range(-0.5, 0.5), rng.randf() * TAU,
				rng.randf_range(0.0, 0.5)), rng.randf_range(0.90, 1.20))


## LA RICADUTA: un tralcio d'edera che scavalca la treccia e scende davanti
## all'intreccio, coi lembi tondi APPOGGIATI alla parete — girati lungo la
## TANGENTE del cesto, non in avanti: una foglia che sporge da una parete
## verticale è una bandierina, e in più sfonda la sagoma del pezzo. Il
## ramo scende seguendo la svasatura, sempre a tre centimetri dal
## contorno: appeso a una profondità fissa restava sepolto nel vimine dove
## la parete rientra.
static func _cesto_ricaduta(parent: Node3D, rng: RandomNumberGenerator,
		base: Vector2, fuori: Vector2, qh: float, svaso: Callable,
		verso: float, tav: Dictionary, foglie: Array, verdi: Array) -> void:
	var verde: Material = tav["verde"]
	var tang := Vector2(-fuori.y, fuori.x) * verso
	var giu := func(y: float, quanto: float, scorri: float) -> Vector3:
		var s: float = svaso.call(y)
		var p: Vector2 = base * s + fuori * quanto + tang * scorri
		return Vector3(p.x, y, p.y)
	var punti: Array = [
			giu.call(qh - 0.006, -0.024, 0.000),
			giu.call(qh + 0.026, 0.002, 0.008),
			giu.call(qh - 0.014, 0.018, 0.020),
			giu.call(qh - 0.082, 0.019, 0.032),
			giu.call(qh - 0.134, 0.018, 0.028),
			giu.call(qh - 0.176, 0.015, 0.014)]
	# il tralcio è SOTTILE e cupo: un filo verde chiaro da quattro
	# millimetri che scende per venti centimetri con tre foglie sopra si
	# legge come un cavo elettrico, non come un ramo d'edera
	BUILDER.tube(parent, punti, [0.0032, 0.0029, 0.0025, 0.0021, 0.0017, 0.0011],
			tav["verde_cupo"], 24, 5)
	var lungo_tang := atan2(-tang.y, tang.x)
	for k in 8:
		var t := float(k) / 7.0
		var seg := clampi(int(t * 4.999), 0, 4)
		var u := t * 4.999 - float(seg)
		var p: Vector3 = (punti[seg] as Vector3).lerp(punti[seg + 1] as Vector3, u)
		# il lembo sta a filo di parete: la rotazione su X lo corica sul
		# vimine invece di lasciarlo sporgere come una bandierina
		_cesto_lembo(parent, foglie[(k + 1) % 3], verdi[k % 4],
				p + Vector3(fuori.x * 0.002, 0.001, fuori.y * 0.002),
				Vector3(-PI * 0.5 + rng.randf_range(-0.24, 0.24),
				lungo_tang + (0.0 if k % 2 == 0 else PI) + rng.randf_range(-0.20, 0.20),
				-0.30 + rng.randf_range(-0.35, 0.30)),
				rng.randf_range(0.82, 1.04))
		# a nodi alterni la foglia è DOPPIA: l'edera mette due foglie per
		# nodo, e un tralcio con una foglia ogni tre centimetri di filo
		# nudo è una lenza da pesca
		if k % 2 == 1:
			_cesto_lembo(parent, foglie[k % 3], verdi[(k + 2) % 4],
					p + Vector3(fuori.x * 0.002, -0.006, fuori.y * 0.002),
					Vector3(-PI * 0.5 + rng.randf_range(-0.24, 0.24),
					lungo_tang + (PI if k % 2 == 0 else 0.0)
					+ rng.randf_range(-0.24, 0.24),
					-0.62 + rng.randf_range(-0.30, 0.30)),
					rng.randf_range(0.70, 0.92))


# ==================================================== IL FESTONE DI LUCI
#
# Un festone non è un pezzo: è una GRAMMATICA. Il giocatore pianta dei
# pali e il filo si tende da solo fra quelli che si guardano — in linea,
# in diagonale, fino a quattro celle — e più lungo è il filo, più
# lampadine ci stanno. Da tre pali esce un triangolo, da quattro un
# quadrato, da una griglia una volta di luci che si incrocia sopra la
# testa. Nessun pattern è scritto qui dentro: ci sono solo i pali.
#
# LE REGOLE, e perché sono queste:
#
# 1. Il collegamento è DERIVATO dalle celle occupate, come `coppia()` in
#    Affetti e come la fusione delle serre: il salvataggio resta una riga
#    per palo, non c'è niente da migrare e niente che possa restare
#    appeso a metà. Si toglie un palo e i fili che ci arrivavano
#    spariscono da soli, perché non erano mai stati «salvati».
# 2. Un palo cerca il PRIMO palo che incontra in ognuna delle otto
#    direzioni, entro FESTONE_PORTATA celle. Il primo, non tutti: senza
#    questa regola una fila di sei pali diventa un ventaglio di quindici
#    fili sovrapposti invece di una collana.
# 3. Il filo appartiene al palo lessicograficamente MINORE fra i due
#    (stessa regola del montante condiviso fra due serre): così viene
#    disegnato una volta sola, e non due mezzi fili che si compenetrano.
# 4. La VESTE del filo è quella del palo che lo tiene. Tre pali diversi,
#    tre vesti: alternandoli si alternano i fili, ed è lì che il
#    giocatore comincia a comporre invece di posare.
# 5. La pancia non si disegna: RISULTA dalla lunghezza. Il filo è una
#    corda viva (CordaFisica + CordeVive), quindi nel mondo ondeggia col
#    vento vero e le lampadine lo seguono punto per punto.

## Le tre vesti. Sono indici, non testo: viaggiano solo dentro il
## builder — quello che sta nel salvataggio è il NOME del palo.
const FESTONE_BULBI := 0
const FESTONE_LANTERNE := 1
const FESTONE_BANDIERINE := 2
## Il nome di pezzo di ogni palo, nell'ordine delle vesti. Fonte unica:
## BuildSystem legge di qui per sapere se una cella è un palo e che veste
## porta — mai una seconda lista scritta a mano di là.
const FESTONE_PALI := ["Palo lucine", "Palo lanterne", "Palo bandierine"]
## QUANTO È LUNGO UN FILO, in metri. Quattro metri con la sua pancia è
## già una campata generosa; a cinque il filo scende sotto l'altezza
## della testa di Mochi.
##
## È UNA DISTANZA VERA, non un conto di celle, e la differenza è tutto il
## controllo che ha il giocatore. In celle, quattro pali ai vertici di un
## quadrato di lato tre si legano anche sulle DIAGONALI (tre passi anche
## quelle) e il quadrato esce sempre con la X dentro: un disegno che il
## giocatore non ha chiesto e non può togliere. In metri, la diagonale di
## quel quadrato misura 4.24 — il filo non ci arriva — e il quadrato
## resta un quadrato. Metti i pali a due celle e la diagonale scende a
## 2.83: allora sì che si annoda, ed è l'intreccio.
## Una regola sola, che si spiega da sé: **il filo è lungo quattro metri**.
const FESTONE_PORTATA := 4.0
## Fin dove ci si spinge a CERCARE, in celle (oltre, la distanza vera
## supera comunque la portata anche in linea retta).
const FESTONE_PASSI := 4
## L'altezza dell'occhiello in cima al palo: è lì che si annoda il filo.
const FESTONE_CIMA := 1.92


## L'anello: un toro, che qui serve di continuo (le legature di spago, il
## golfare d'ottone, la matassa avanzata).
static func _anello(parent: Node3D, r_int: float, r_est: float, mat: Material,
		pos: Vector3, ritto := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = r_int
	tm.outer_radius = r_est
	tm.rings = 18
	tm.ring_segments = 8
	mi.mesh = tm
	mi.material_override = mat
	mi.position = pos
	# un toro nasce nel piano XZ (sdraiato): «ritto» lo mette in piedi,
	# che è come sta un occhiello a cui si lega qualcosa
	if ritto:
		mi.rotation.x = PI * 0.5
	parent.add_child(mi)
	return mi


## IL PALO. Non è un cilindro: è un ramo scortecciato piantato a terra.
## Il fusto è un tornio con due nodi veri dove sono stati tagliati i
## rami, la terra attorno è smossa, la cima ha la legatura di spago e il
## golfare d'ottone in cui passa il filo, e sotto la legatura sta
## arrotolata la corda che avanza — il dettaglio che dice «l'ha messo su
## qualcuno», che è tutta la differenza fra un asset e un oggetto.
##
## Torna il punto in cui si annoda il filo (in coordinate del pezzo).
static func _palo_festone(n: Node3D, base: Vector3, seme: int) -> Vector3:
	var rng := RandomNumberGenerator.new()
	rng.seed = seme
	var legno := _mat(WOOD, WOOD_DARK, 4.0, 0.5)
	var legno_cupo := _mat(WOOD_DARK, Color("8a6440"), 4.5, 0.5)
	var spago := _mat(Color("e0cfa8"), Color("c4ad82"), 6.0, 0.45)
	var ottone := _mat(OTTONE, OTTONE_SCURO, 5.0, 0.35)
	var ferro := _mat(Color("6b6259"), Color("4e463f"), 5.0, 0.4)
	var terra := _mat(Color("8a6f52"), Color("6b543c"), 3.0, 0.5)
	var sasso := _mat(STONE, STONE_DARK, 4.0, 0.5)

	# la PIANTATA: un palo piantato smuove la terra attorno, e senza
	# quella cicatrice sembra infilato in un pavimento. ZOLLE, però, non
	# un disco: una sfera schiacciata larga diciassette centimetri esce
	# come un sottovaso di terracotta — visto e corretto.
	for i in 5:
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.050, 0.100)
		var zolla := _ball(n, rng.randf_range(0.034, 0.060), terra,
				base + Vector3(cos(a) * d, rng.randf_range(0.008, 0.024),
						sin(a) * d),
				Vector3(1.0, rng.randf_range(0.42, 0.68), 1.0))
		zolla.rotation.y = rng.randf() * TAU
	for i in 3:
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.10, 0.15)
		_ball(n, rng.randf_range(0.015, 0.025), sasso,
				base + Vector3(cos(a) * d, 0.009, sin(a) * d),
				Vector3(1.3, 0.55, 1.0))
	# la ghiera di ferro che protegge il piede dal marcire: sta SOPRA le
	# zolle, se no la si seppellisce e tanto valeva non metterla
	_cyl(n, 0.049, 0.056, 0.072, ferro, base + Vector3(0, 0.078, 0))

	# IL FUSTO: un tornio, non un cono. Rastrema salendo e ha due nodi
	# (i rami tagliati), perché un palo dritto e liscio per due metri non
	# esiste in natura e si vede subito.
	var n1 := rng.randf_range(0.52, 0.68)
	var n2 := rng.randf_range(1.18, 1.36)
	var prof: Array = []
	var y := 0.02
	while y < 1.96:
		var r := 0.047 - 0.017 * (y / 1.96)
		# il rigonfio del nodo: una campana stretta attorno alla quota
		r += 0.010 * exp(-pow((y - n1) / 0.055, 2.0))
		r += 0.009 * exp(-pow((y - n2) / 0.050, 2.0))
		prof.append(Vector2(r, y))
		y += 0.055
	prof.push_front(Vector2(0.0, 0.0))
	prof.append(Vector2(0.0295, 1.98))
	BUILDER.lathe(n, prof, legno, base, 14)

	# i due MONCONI dei rami tagliati, sui nodi: il taglio è chiaro, il
	# legno attorno è scuro — è così che si legge una potatura vecchia
	for k in 2:
		var yq: float = n1 if k == 0 else n2
		var aq := rng.randf() * TAU
		var mon := _cyl(n, 0.011, 0.019, 0.042, legno_cupo,
				base + Vector3(cos(aq) * 0.050, yq, sin(aq) * 0.050))
		mon.rotation.z = -cos(aq) * 1.15
		mon.rotation.x = sin(aq) * 1.15
		_cyl(n, 0.011, 0.011, 0.004, _mat(WOOD_PALE, WOOD, 4.0, 0.4),
				base + Vector3(cos(aq) * 0.068, yq + 0.017, sin(aq) * 0.068))

	# LA MATASSA che avanza, arrotolata sotto la legatura. Tre giri
	# sbilenchi: una matassa perfetta non l'ha fatta nessuno.
	var filo_mat := _mat(Color("4f4a45"), Color("3d3935"), 4.0, 0.3)
	for k in 3:
		var mm := _anello(n, 0.033, 0.040, filo_mat,
				base + Vector3(0, 1.54 + float(k) * 0.019, 0))
		mm.rotation.z = rng.randf_range(-0.10, 0.10)
		mm.rotation.x = rng.randf_range(-0.08, 0.08)

	# LA LEGATURA di spago sotto il golfare: cinque giri, nessuno uguale
	for k in 5:
		var g := _anello(n, 0.031, 0.037, spago,
				base + Vector3(0, 1.71 + float(k) * 0.017, 0))
		g.rotation.z = rng.randf_range(-0.07, 0.07)
	# il capo dello spago che pende, il nodo mai tirato del tutto
	var capo := _cyl(n, 0.0035, 0.0035, 0.055, spago,
			base + Vector3(0.032, 1.685, 0.010))
	capo.rotation.z = 0.35

	# LA GHIERA E L'ANELLO d'ottone su cui si posa il filo. Un filo che
	# tocca il legno e basta è un filo appoggiato, non appeso — è questo
	# pezzetto a rendere credibile tutto il resto.
	# L'anello sta ORIZZONTALE, e non è un dettaglio di gusto: da un palo
	# partono fino a otto fili in otto direzioni diverse, e un occhiello
	# ritto guarderebbe in una sola. Piatto lo si legge da tutte.
	_cyl(n, 0.029, 0.034, 0.028, ottone, base + Vector3(0, 1.888, 0))
	_anello(n, 0.030, 0.043, ottone, base + Vector3(0, FESTONE_CIMA, 0))

	# IL CAPPELLO tornito: una ghianda, con la sua bruniture in punta
	BUILDER.lathe(n, [Vector2(0.0, 0.0), Vector2(0.030, 0.006),
			Vector2(0.036, 0.020), Vector2(0.034, 0.040),
			Vector2(0.026, 0.058), Vector2(0.014, 0.072),
			Vector2(0.0, 0.078)], legno, base + Vector3(0, 1.965, 0), 14)
	_ball(n, 0.009, ottone, base + Vector3(0, 2.044, 0))
	return base + Vector3(0, FESTONE_CIMA, 0)


## UNA LAMPADINA da festone: portalampada di bachelite, ghiera d'ottone,
## vetro a goccia e — dentro — il FILAMENTO. È il filamento a fare la
## differenza fra una lampadina e una biglia colorata: dà profondità al
## vetro, esattamente come la fiammella dentro la Lanterna blu.
static func _lampadina(parent: Node3D, pos: Vector3, c: Color, scala: float,
		pende: float) -> Node3D:
	var b := Node3D.new()
	b.position = pos
	b.rotation.z = pende
	b.scale = Vector3.ONE * scala
	parent.add_child(b)
	var bachelite := _mat(Color("3a3531"), Color("26221f"), 6.0, 0.35)
	var ottone := _mat(OTTONE, OTTONE_SCURO, 5.0, 0.3)
	# il codino di filo che scende dal cavo
	_cyl(b, 0.0035, 0.0035, 0.026, _mat(Color("4f4a45"), Color("3d3935"), 4.0, 0.3),
			Vector3(0, -0.013, 0))
	# il portalampada e la ghiera a vite (due filetti suggeriti)
	_cyl(b, 0.0135, 0.0165, 0.030, bachelite, Vector3(0, -0.041, 0))
	_cyl(b, 0.0140, 0.0140, 0.012, ottone, Vector3(0, -0.062, 0))
	_anello(b, 0.0125, 0.0150, ottone, Vector3(0, -0.060, 0))
	_anello(b, 0.0125, 0.0150, ottone, Vector3(0, -0.066, 0))
	# IL VETRO: una goccia tornita, costruita in su e rovesciata (il
	# tornio sale, la lampadina pende)
	var vetro := BUILDER.lathe(b, [Vector2(0.0125, 0.0), Vector2(0.021, 0.014),
			Vector2(0.028, 0.032), Vector2(0.0300, 0.052),
			Vector2(0.0265, 0.072), Vector2(0.017, 0.088),
			Vector2(0.0, 0.095)],
			# l'albedo va un filo PIÙ CUPO dell'emissione: con lo stesso
			# colore, di giorno, sei lampadine di sei colori diversi
			# escono sei biglie bianche identiche
			_glow(c.darkened(0.16), c, 0.55), Vector3(0, -0.070, 0), 16)
	vetro.rotation.x = PI
	# il filamento: due montantini e l'ansa incandescente in mezzo
	var acceso := _glow(Color("fff3d0"), Color("ffe9b0"), 3.2)
	for sx: float in [-1.0, 1.0]:
		_cyl(b, 0.0015, 0.0015, 0.022, acceso,
				Vector3(sx * 0.0055, -0.086, 0))
	_ball(b, 0.0055, acceso, Vector3(0, -0.100, 0), Vector3(1.9, 0.7, 1.0))
	return b


## UN LAMPIONCINO DI CARTA: la carta a soffietto (le costole nel profilo
## del tornio), i due cerchietti di stecca in cima e in fondo, e la
## nappina. Dentro sta la sua lucina, se no di notte è un sacchetto.
static func _lampioncino(parent: Node3D, pos: Vector3, c: Color, scala: float,
		pende: float) -> Node3D:
	var b := Node3D.new()
	b.position = pos
	b.rotation.z = pende
	b.scale = Vector3.ONE * scala
	parent.add_child(b)
	var stecca := _mat(Color("b89a72"), Color("94794f"), 5.0, 0.4)
	_cyl(b, 0.003, 0.003, 0.024, _mat(Color("4f4a45"), Color("3d3935"), 4.0, 0.3),
			Vector3(0, -0.012, 0))
	# la carta: raggio a campana con le COSTOLE del soffietto sopra
	var prof: Array = []
	for i in 13:
		var t := float(i) / 12.0
		var r := 0.060 * sin(PI * clampf(t * 0.94 + 0.03, 0.0, 1.0))
		# LE COSTOLE del soffietto: a 0.0035 non si vedevano affatto e il
		# lampioncino usciva una palla di carta liscia — cioè una palla
		r += 0.0065 * sin(t * PI * 7.0)
		prof.append(Vector2(maxf(r, 0.001), t * 0.115))
	var carta := BUILDER.lathe(b, prof, _glow(c, c, 0.42),
			Vector3(0, -0.140, 0), 18)
	carta.name = "Carta"
	# i due cerchietti di stecca
	_anello(b, 0.011, 0.017, stecca, Vector3(0, -0.030, 0))
	_anello(b, 0.011, 0.017, stecca, Vector3(0, -0.138, 0))
	# la lucina dentro, e la nappina sotto
	_ball(b, 0.020, _glow(Color("fff0cc"), Color("ffe4a8"), 2.4),
			Vector3(0, -0.084, 0))
	_cyl(b, 0.010, 0.004, 0.020, _mat(Color("d9584e"), Color("ac443c"), 5.0, 0.4),
			Vector3(0, -0.150, 0))
	for k in 4:
		var a := float(k) * TAU / 4.0 + 0.4
		var fp := _cyl(b, 0.0018, 0.0018, 0.032,
				_mat(Color("d9584e"), Color("ac443c"), 5.0, 0.4),
				Vector3(cos(a) * 0.006, -0.176, sin(a) * 0.006))
		fp.rotation.z = cos(a) * 0.18
		fp.rotation.x = -sin(a) * 0.18
	return b


## UNA BANDIERINA di stoffa: il triangolo con l'orlo ripiegato in cima e
## due punti di cucitura. Il festone di bandierine porta ANCHE le sue
## lucine piccole, alternate: una fila di bandierine e basta, di notte,
## è un festone spento — e questo resta un pezzo che fa luce.
static func _bandierina(parent: Node3D, pos: Vector3, c: Color, scala: float,
		pende: float, giro: float) -> Node3D:
	var b := Node3D.new()
	b.position = pos
	b.rotation.z = pende
	b.rotation.y = giro
	b.scale = Vector3.ONE * scala
	parent.add_child(b)
	var stoffa := _mat(c, c.darkened(0.20), 3.0, 0.45)
	var orlo := _mat(c.lightened(0.10), c.darkened(0.08), 3.0, 0.4)
	# il triangolo: sta nel piano XZ e si mette RITTO con pendenza PI/2,
	# così la punta cade in giù (vedi _falda)
	_falda(b, [Vector2(-0.052, 0.0), Vector2(0.052, 0.0), Vector2(0.0, 0.115)],
			stoffa, Vector3(0, -0.012, 0), 0.0, PI * 0.5, 0.005)
	# l'orlo ripiegato attorno al cavo, e i due punti di cucitura
	_box(b, Vector3(0.108, 0.016, 0.010), orlo, Vector3(0, -0.006, 0))
	for sx: float in [-1.0, 1.0]:
		_ball(b, 0.0035, orlo, Vector3(sx * 0.036, -0.006, -0.006),
				Vector3(1.0, 1.0, 0.6))
	return b


## IL FILO: la campata fra due cime. Tutto quello che il giocatore
## controlla — quanto è lungo, quindi quante luci ci stanno, quindi
## quanta pancia fa — esce da qui e da nient'altro.
##
## Torna il nodo contenitore: dentro c'è la corda viva e i suoi appesi.
static func festone(a: Vector3, b: Vector3, veste: int, seme: int) -> Node3D:
	var n := Node3D.new()
	n.name = "Festone"
	var rng := RandomNumberGenerator.new()
	rng.seed = seme
	var campata := a.distance_to(b)
	# LA PANCIA. L'abbondanza di corda va giù al crescere della campata,
	# non su: la freccia è già proporzionale alla campata, e tenendo la
	# stessa abbondanza un filo da quattro metri scendeva a 83 cm da
	# terra — sotto la testa di Mochi, che ci passa in mezzo. Così il
	# filo corto fa la sua pancia allegra (21 cm su 93) e quello lungo
	# resta a 1.25 m, che è alto abbastanza per passarci sotto.
	# (0.055 in fondo, non 0.075: a 0.075 la campata da quattro metri
	# scendeva a 1.16 m e con la lampadina appesa restavano 96 cm liberi,
	# cioè meno di quanto è alta Mochi. Misurato da test_festoni, non
	# stimato a occhio.)
	var molle := clampf(0.26 / (1.0 + campata), 0.055, 0.20)
	var lung := campata * (1.0 + molle)
	var punti := clampi(int(round(lung * 7.0)), 10, 26)
	var filo := _mat(Color("4f4a45"), Color("3d3935"), 4.0, 0.3)
	var vivo := _corda_viva(n, a, b, molle, 0.0055, filo, 1.0, punti, 6)
	var posa: Array = vivo.get_meta("posa")

	# QUANTE LUCI: una ogni ~17 cm di filo. È la risposta alla domanda
	# «allungo la corda per metterne di più»: sì, e non si tocca niente.
	var quante := clampi(int(round(lung / 0.17)), 4, 16)
	var colori: Array = [Color("ffd08a"), Color("ffb0a0"), Color("bfe0ff"),
			Color("ffe6a8"), Color("d8c0f0"), Color("ffc2d4")]
	var colori_carta: Array = [Color("ffd9a0"), Color("ff9f8c"), Color("ffe8bc"),
			Color("f2b3c8")]
	var colori_stoffa: Array = [PINK, Color("9ec9e8"), CREAM, LEAF,
			Color("ffd08a")]
	var appesi: Array = []
	for i in quante:
		# gli estremi finirebbero DENTRO il palo: le luci vivono FRA i
		# pali, non nei pali (era già la lezione delle vecchie Lucine)
		var t0 := (float(i) + 1.0) / (float(quante) + 1.0)
		var sul_filo: Vector3 = FISICA.campiona(posa, t0)
		var pende := rng.randf_range(-0.09, 0.09)
		var scala := rng.randf_range(0.93, 1.07)
		# `giu` È ZERO, e non per pigrizia: l'origine di ogni appeso sta
		# SUL filo (il codino parte da lì e il resto pende sotto), quindi
		# il posto giusto è il punto campionato, senza scarti. Il vecchio
		# festone aveva due nodi per lampadina — l'attacco e il bulbo, a
		# quote diverse — e lì un `giu` serviva.
		# Il numero dichiarato qui e la posizione scolpita dal builder
		# DEVONO combaciare: nelle foto del catalogo, nei test e con
		# «Riduci animazioni» CordeVive non gira mai, e resta valida la
		# posa da fermo. Con giu 0.06 e il nodo posato sul filo, ogni
		# lampadina restava sei centimetri troppo in alto — a cavallo del
		# cavo invece che appesa. L'ha trovato test_corde.gd.
		var nodo: Node3D = null
		match veste:
			FESTONE_LANTERNE:
				nodo = _lampioncino(n, sul_filo,
						colori_carta[i % colori_carta.size()], scala, pende)
			FESTONE_BANDIERINE:
				# bandierina · lucina · bandierina: la fila alternata è
				# quella che si vede appesa davvero, e resta accesa
				if i % 2 == 0:
					nodo = _bandierina(n, sul_filo,
							colori_stoffa[i % colori_stoffa.size()], scala,
							pende, rng.randf_range(-0.22, 0.22))
				else:
					nodo = _lampadina(n, sul_filo,
							colori[i % colori.size()], scala * 0.72, pende)
			_:
				nodo = _lampadina(n, sul_filo, colori[i % colori.size()],
						scala, pende)
		nodo.name = "Appeso%d" % i
		appesi.append({"path": NodePath("../Appeso%d" % i), "t": t0, "giu": 0.0})
	var meta: Dictionary = vivo.get_meta("corda")
	meta["appesi"] = appesi
	vivo.set_meta("corda", meta)

	# LA LUCE, e qui c'è la lezione più cara di tutta la faccenda.
	#
	# Un festone SOLO vuole una luce ampia (la taratura scelta al buio era
	# 1.5 / 4.2). Ma questi fili si MOLTIPLICANO: una griglia di nove pali
	# a due celle fa venti campate, e venti luci da 1.5 con quattro metri
	# di portata si sommano in un lenzuolo bianco — il prato sotto il
	# baldacchino era illeggibile, misurato in foto nel villaggio vero.
	# Non si può tarare per il caso singolo e sperare: un sistema che il
	# giocatore moltiplica va tarato sul MUCCHIO.
	#
	# La risposta è la stessa della Lanterna blu, letta al contrario: la
	# pozza si fa con la PORTATA. Corta (2.6) la luce resta sotto il suo
	# filo, e in una griglia si sovrappone due o tre volte invece di
	# venti. Il bello lo fanno comunque le lampadine, che sono emissive:
	# l'Omni serve solo a far cadere qualcosa per terra.
	var n_luci := clampi(int(round(campata / 1.8)), 1, 3)
	for k in n_luci:
		var tl := (float(k) + 1.0) / (float(n_luci) + 1.0)
		var pl: Vector3 = FISICA.campiona(posa, tl)
		var luce := OmniLight3D.new()
		luce.light_color = Color(1.0, 0.88, 0.72)
		luce.light_energy = 1.3 / sqrt(float(n_luci))
		luce.omni_range = 2.6
		luce.omni_attenuation = 1.25
		luce.shadow_enabled = false
		luce.position = pl + Vector3(0, -0.06, 0)
		n.add_child(luce)
	return n


## Il campione appeso al palo: quello che il palo PORTA, ed è come si
## capisce dallo scaffale che i tre pali non sono lo stesso pezzo in tre
## colori. Pende da un gancetto sul fianco, sotto la matassa.
static func _campione_palo(n: Node3D, base: Vector3, veste: int) -> void:
	var ottone := _mat(OTTONE, OTTONE_SCURO, 5.0, 0.3)
	# il braccetto va LUNGO: a cinque centimetri il campione restava
	# mezzo dentro il fusto — una bandierina tagliata a metà dal palo
	var p := base + Vector3(0.125, 1.44, 0.0)
	var braccio := _cyl(n, 0.005, 0.006, 0.115, ottone,
			base + Vector3(0.068, 1.468, 0))
	braccio.rotation.z = PI * 0.5
	_cyl(n, 0.004, 0.004, 0.030, ottone, p + Vector3(0, 0.014, 0))
	_anello(n, 0.005, 0.010, ottone, p + Vector3(0, 0.030, 0), true)
	match veste:
		FESTONE_LANTERNE:
			_lampioncino(n, p, Color("ffd9a0"), 0.85, 0.06)
		FESTONE_BANDIERINE:
			_bandierina(n, p, PINK, 0.9, 0.05, 0.3)
		_:
			_lampadina(n, p, Color("ffd08a"), 1.0, 0.05)


## Il palo nudo, com'è sullo scaffale e come sta piantato da solo: un
## palo e il suo campione. Il filo non è suo — nasce quando trova un
## compagno (vedi BuildSystem.ricostruisci_festoni).
static func _palo_veste(veste: int) -> Node3D:
	var n := Node3D.new()
	var cima := _palo_festone(n, Vector3.ZERO, 41_000 + veste * 977)
	_campione_palo(n, Vector3.ZERO, veste)
	# il segnaposto della cima: BuildSystem ci annoda i fili senza doversi
	# ricordare un numero scritto da un'altra parte
	var seg := Node3D.new()
	seg.name = "Cima"
	seg.position = cima
	n.add_child(seg)
	return n


static func _palo_lucine() -> Node3D:
	return _palo_veste(FESTONE_BULBI)


static func _palo_lanterne() -> Node3D:
	return _palo_veste(FESTONE_LANTERNE)


static func _palo_bandierine() -> Node3D:
	return _palo_veste(FESTONE_BANDIERINE)


static func _lucine() -> Node3D:
	# LE LUCINE già montate: due pali e la loro campata, per chi vuole il
	# festone e basta senza mettersi a comporre. Sono gli STESSI pali e lo
	# STESSO filo del sistema modulare — una implementazione sola, come
	# l'andatura dei vicini nel menù: se un domani cambia il golfare,
	# cambia in tutti e due i posti.
	var n := Node3D.new()
	var ca := _palo_festone(n, Vector3(-0.46, 0, 0), 41_101)
	var cb := _palo_festone(n, Vector3(0.46, 0, 0.06), 41_207)
	var f := festone(ca, cb, FESTONE_BULBI, 41_303)
	n.add_child(f)
	return n


# IL FRIGO DEI GELATI, rifatto da capo come un POZZETTO DA BAR ANNI
# CINQUANTA: il collare cromato bombato attorno alla bocca (la firma
# dei pozzetti veri), il corpo smaltato crema sullo zoccolo rientrante
# con la griglia di ventilazione, la fascia rossa in livrea col
# filetto — la stessa identita' della tenda del bar — e i VETRI CURVI
# scorrevoli che si SOVRAPPONGONO sui binari: il sinistro e' scorso
# sopra il destro, come si fa davvero per servire, e il pozzetto
# aperto mostra le vaschette dei gusti coi riccioli e la PALETTA
# piantata nel cioccolato. Sulla fascia, i gelati in rilievo.
static func _frigo_gelati() -> Node3D:
	var n := Node3D.new()
	var crema_s := _mat(Color("f4efe4"), Color("e0d9c8"), 5.0, 0.3)
	var rosso := _mat(BAR_ROSSO, BAR_ROSSO_CUPO, 4.5, 0.45)
	var cromo := _mat(CROMO, Color("b9bec6"), 7.0, 0.3)
	var zoc_s := _mat(Color("5c5650"), Color("46413c"), 5.0, 0.3)
	var inox := _mat(Color("8a9097"), Color("6d7378"), 6.0, 0.25)

	# lo ZOCCOLO rientrante (il corpo sembra sospeso: e' il trucco di
	# tutti gli elettrodomestici belli) e la GRIGLIA di ventilazione
	var zocc := _prisma(n, _rrect_xz(0.84, 0.42, 0.03), 0.0, 0.06, zoc_s)
	zocc.position.z = 0.0
	for gv in 5:
		_box(n, Vector3(0.10, 0.020, 0.012), cromo,
				Vector3(-0.26 + 0.13 * float(gv), 0.032, -0.215))

	# il CORPO smaltato con le spalle tonde, e il COLLARE cromato
	_loft(n, [[-0.46, 0.215, 0.06, 0.60, 0.085],
			[-0.42, 0.245, 0.06, 0.60, 0.045],
			[0.42, 0.245, 0.06, 0.60, 0.045],
			[0.46, 0.215, 0.06, 0.60, 0.085]], crema_s)
	_loft(n, [[-0.475, 0.225, 0.60, 0.665, 0.06],
			[-0.44, 0.255, 0.60, 0.665, 0.03],
			[0.44, 0.255, 0.60, 0.665, 0.03],
			[0.475, 0.225, 0.60, 0.665, 0.06]], cromo)

	# la FASCIA rossa in livrea coi due filetti crema
	var fascia := _prisma(n, _rrect_xz(0.945, 0.525, 0.05), 0.30, 0.105, rosso)
	fascia.position.z = 0.0
	for fy: float in [0.292, 0.405]:
		var filo := _prisma(n, _rrect_xz(0.948, 0.528, 0.05), fy, 0.010, crema_s)
		filo.position.z = 0.0

	# i GELATI in rilievo sulla fascia: ghiacciolo alla menta, mini-cono,
	# stecco bigusto — un frigo dei gelati si annuncia da solo
	var menta_g := _mat(Color("9fd8b4"), Color("7fbf98"), 5.0, 0.4)
	var stecco := _mat(Color("d4a45e"), Color("b98a48"), 6.0, 0.45)
	var cialda_m := _mat(Color("e8bd78"), Color("d4a45e"), 6.0, 0.45)
	_lastra(n, 0.030, 0.078, 0.022, 0.020, menta_g,
			Vector3(-0.30, 0.372, -0.272), Vector3(0, PI * 0.5, 0))
	_cyl(n, 0.006, 0.006, 0.032, stecco, Vector3(-0.30, 0.318, -0.270))
	var mcono := _cyl(n, 0.024, 0.004, 0.056, cialda_m, Vector3(0.0, 0.336, -0.272))
	mcono.rotation.z = PI
	_ball(n, 0.022, _mat(PINK, PINK_DEEP, 5.0, 0.4), Vector3(0.0, 0.377, -0.272))
	_lastra(n, 0.026, 0.044, 0.018, 0.018, crema_s,
			Vector3(0.30, 0.382, -0.272), Vector3(0, PI * 0.5, 0))
	_lastra(n, 0.026, 0.038, 0.018, 0.018, rosso,
			Vector3(0.30, 0.342, -0.272), Vector3(0, PI * 0.5, 0))
	_cyl(n, 0.006, 0.006, 0.028, stecco, Vector3(0.30, 0.310, -0.270))

	# dentro: la vasca d'acciaio e le VASCHETTE dei sei gusti, coi
	# riccioli della spatola e la paletta piantata nel cioccolato
	_box(n, Vector3(0.86, 0.30, 0.40), inox, Vector3(0, 0.48, 0))
	var gusti_v := [Color("f2b6c8"), Color("9fd8b4"), Color("e8c34a"),
			Color("8a5c3e"), Color("f0e4cc"), Color("9a8ac2")]
	# la camera del catalogo sta a 23 gradi: DENTRO un pozzetto non si
	# vede mai, per geometria. Percio' i gusti MONTANO sopra il filo
	# della bocca come nei banchi espositivi veri: montagne piene dove
	# il vetro e' scorso, gia' scavate sotto il vetro chiuso.
	for vg in 6:
		var vx := -0.26 + 0.26 * float(vg % 3)
		var vz := -0.095 + 0.19 * float(vg / 3)
		var col_v := gusti_v[vg] as Color
		var mat_g := _mat(col_v, col_v.darkened(0.2), 5.0, 0.4)
		var mat_c := _mat(col_v.lightened(0.10), col_v.darkened(0.1), 5.0, 0.4)
		var vaschetta := _prisma(n, _rrect_xz(0.235, 0.160, 0.02), 0.600,
				0.060, mat_g)
		vaschetta.position = Vector3(vx, 0.0, vz)
		if vg % 3 == 0:
			# la colonna scoperta: la montagna piena col ricciolo in cima
			_ball(n, 0.062, mat_c, Vector3(vx, 0.682, vz),
					Vector3(1.35, 0.85, 1.05))
			_ball(n, 0.026, mat_g, Vector3(vx + 0.03, 0.728, vz),
					Vector3(1.2, 0.6, 0.9))
		else:
			# sotto il vetro: il gusto gia' scavato, piu' basso
			_ball(n, 0.050, mat_c, Vector3(vx + 0.02, 0.664, vz),
					Vector3(1.3, 0.45, 1.0))
	var manico_p := _cyl(n, 0.008, 0.008, 0.11, cromo, Vector3(-0.235, 0.755, 0.095))
	manico_p.rotation.z = 0.45
	_ball(n, 0.021, cromo, Vector3(-0.258, 0.708, 0.095), Vector3(1.0, 0.6, 1.0))

	# i BINARI sul collare, e i due VETRI CURVI scorrevoli: il sinistro
	# e' scorso SOPRA il destro, come si fa per servire
	for bz: float in [-0.215, 0.215]:
		_box(n, Vector3(0.90, 0.012, 0.018), cromo, Vector3(0, 0.685, bz))
	var bombatura: Array = [Vector2(0.205, 0.0), Vector2(0.10, 0.024),
			Vector2(0.0, 0.032), Vector2(-0.10, 0.024), Vector2(-0.205, 0.0)]
	for lato: float in [-1.0, 1.0]:
		var cop := Node3D.new()
		cop.name = "Coperchio%d" % int(lato)
		if lato < 0.0:
			cop.position = Vector3(0.03, 0.732, 0.0)
		else:
			cop.position = Vector3(0.025, 0.695, 0.0)
		n.add_child(cop)
		_vetro_curvo(cop, 0.0, 0.41, bombatura, _vetro(0.20))
		# il telaietto cromato ai due capi della lastra, e la maniglietta
		for cx2: float in [0.006, 0.404]:
			_box(cop, Vector3(0.014, 0.016, 0.40), cromo, Vector3(cx2, 0.004, 0))
		_box(cop, Vector3(0.030, 0.020, 0.075), cromo, Vector3(0.012, 0.016, 0))

	# l'INSEGNA col cono: il palo NON spunta dal pozzetto (un'asta che
	# nasce dentro la vasca non ha senso) — e' AVVITATO al fianco con
	# due staffe cromate, braccio, manicotto e piastrina, come le
	# insegne dei bar veri, e sale esterno al corpo fino alla targa
	var palo := _cyl(n, 0.013, 0.016, 0.74, cromo, Vector3(0.55, 0.61, 0.12))
	for ys: float in [0.32, 0.55]:
		var braccio := _cyl(n, 0.009, 0.009, 0.10, cromo, Vector3(0.505, ys, 0.12))
		braccio.rotation.z = PI * 0.5
		_cyl(n, 0.020, 0.020, 0.016, cromo, Vector3(0.55, ys, 0.12))
		var piastra := _cyl(n, 0.017, 0.017, 0.010, cromo, Vector3(0.458, ys, 0.12))
		piastra.rotation.z = PI * 0.5
	var cartello := _lastra(n, 0.145, 0.32, 0.06, 0.02, rosso,
			Vector3(0.55, 1.08, 0.12), Vector3(0, PI * 0.5, 0))
	cartello.name = "Cartello"
	_lastra(n, 0.125, 0.28, 0.05, 0.02, crema_s,
			Vector3(0.55, 1.08, 0.114), Vector3(0, PI * 0.5, 0))
	var cialda := _cyl(n, 0.075, 0.012, 0.16, cialda_m, Vector3(0.55, 1.015, 0.098))
	cialda.rotation.z = 0.1
	_ball(n, 0.047, _mat(PINK, PINK_DEEP, 5.0, 0.4), Vector3(0.529, 1.122, 0.095))
	_ball(n, 0.044, _mat(CREAM, Color("f0e4cc"), 5.0, 0.35), Vector3(0.576, 1.148, 0.095))
	_ball(n, 0.015, _mat(BAR_ROSSO, BAR_ROSSO_CUPO, 5.0, 0.35),
			Vector3(0.581, 1.185, 0.093))
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
