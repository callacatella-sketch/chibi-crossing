extends RefCounted

## CHE ORA È DA TE — la luce del menù segue l'orologio VERO del giocatore.
##
## Il titolo era in golden hour perpetua: bellissima la prima volta, uguale
## la centesima. Adesso chi apre il gioco alle sette di mattina trova
## un'alba rosa, chi lo apre a mezzanotte trova il prato blu con le
## lucciole, e chi lo apre alle sei di sera trova la golden hour di sempre.
## Nessuno ci ha messo un'opzione e nessuno lo spiega: semplicemente il
## villaggio è sveglio quando sei sveglio tu.
##
## È la leva più economica che esista per «non vedere mai la stessa cosa»:
## non c'è casualità, non c'è contenuto nuovo da produrre — c'è che il
## mondo sta al passo con te. E la sera, quando la maggior parte delle
## persone gioca, è anche il momento più bello.
##
## PERCHÉ NON RIUSA IL CIELO DI `DayNight`: quello segue l'ora DEL GIOCO e
## la stagione del villaggio, e vive di tween su un mondo acceso. Qui
## l'ora è quella VERA, la scena è un diorama, e la palette è una scelta
## d'illustrazione. Sono due cose diverse che si somigliano, non la stessa
## cosa in due posti.
##
## Tutto puro: entra un numero d'ora, esce una palette.

## I momenti della giornata, in ordine.
const MOMENTI := ["notte", "alba", "mattina", "pomeriggio", "tramonto", "sera"]


## Che momento è, dall'ora (0..23) dell'orologio di chi gioca.
static func momento(ora: int) -> String:
	var h := int(wrapi(ora, 0, 24))
	if h >= 22 or h < 5:
		return "notte"
	if h < 8:
		return "alba"
	if h < 12:
		return "mattina"
	if h < 17:
		return "pomeriggio"
	if h < 20:
		return "tramonto"
	return "sera"


## Il momento di ADESSO, dall'orologio di sistema.
##
## `CHIBI_ORA=23` la forza, per i provini: guardare com'è il menù a
## mezzanotte non deve richiedere di aspettare mezzanotte (è la stessa
## convenzione delle altre verifiche da riga di comando del progetto).
static func momento_ora() -> String:
	var forzata := OS.get_environment("CHIBI_ORA")
	if forzata != "" and forzata.is_valid_int():
		return momento(int(forzata))
	return momento(int(Time.get_datetime_dict_from_system().get("hour", 12)))


## La palette di un momento. `angolo` è l'inclinazione del sole (gradi):
## bassa all'alba e al tramonto, alta a mezzogiorno — è lei a decidere se
## le ombre sono lunghe e drammatiche o corte e allegre.
static func palette(quando: String) -> Dictionary:
	match quando:
		"notte":
			return {"top": Color(0.06, 0.09, 0.20), "orizz": Color(0.16, 0.20, 0.36),
					"terra": Color(0.08, 0.10, 0.18), "sole": Color(0.62, 0.72, 1.0),
					"energia": 0.55, "amb": 0.30, "angolo": -55.0, "yaw": 30.0,
					"nebbia": 0.014, "notte": 1.0}
		"alba":
			return {"top": Color(0.36, 0.46, 0.76), "orizz": Color(0.99, 0.72, 0.66),
					"terra": Color(0.36, 0.34, 0.42), "sole": Color(1.0, 0.76, 0.68),
					"energia": 0.95, "amb": 0.40, "angolo": -8.0, "yaw": 68.0,
					"nebbia": 0.009, "notte": 0.18}
		"mattina":
			return {"top": Color(0.24, 0.50, 0.90), "orizz": Color(0.63, 0.80, 0.94),
					"terra": Color(0.40, 0.44, 0.42), "sole": Color(1.0, 0.96, 0.86),
					"energia": 1.28, "amb": 0.40, "angolo": -38.0, "yaw": -30.0,
					"nebbia": 0.005, "notte": 0.0}
		"pomeriggio":
			return {"top": Color(0.21, 0.48, 0.92), "orizz": Color(0.66, 0.81, 0.92),
					"terra": Color(0.42, 0.45, 0.41), "sole": Color(1.0, 0.98, 0.90),
					"energia": 1.36, "amb": 0.41, "angolo": -62.0, "yaw": -12.0,
					"nebbia": 0.004, "notte": 0.0}
		"sera":
			return {"top": Color(0.18, 0.26, 0.52), "orizz": Color(0.62, 0.50, 0.66),
					"terra": Color(0.28, 0.28, 0.36), "sole": Color(0.86, 0.78, 1.0),
					"energia": 0.78, "amb": 0.36, "angolo": -6.0, "yaw": -70.0,
					"nebbia": 0.011, "notte": 0.62}
		_:  # tramonto — la golden hour, la casa del gioco
			return {"top": Color(0.35, 0.50, 0.80), "orizz": Color(0.95, 0.72, 0.49),
					"terra": Color(0.35, 0.50, 0.80).lerp(Color(0.62, 0.50, 0.44), 0.7),
					"sole": Color(1.0, 0.82, 0.60),
					"energia": 1.22, "amb": 0.44, "angolo": -16.0, "yaw": -52.0,
					"nebbia": 0.006, "notte": 0.05}


## IL CLIMA SI POSA SOPRA L'ORA, non la sostituisce.
##
## L'ora dice che luce c'è; il clima dice come si sta. Sono due assi
## indipendenti, ed è per questo che il menù non si ripete: sei momenti
## per sette climi fanno quarantadue mattine diverse, e nessuna è stata
## disegnata a mano.
##
## Il lutto è l'unico che stravolge: toglie il colore al mondo qualunque
## ora sia — perché è vero che una giornata così è grigia anche se fuori
## c'è il sole.
static func con_clima(base: Dictionary, clima: String) -> Dictionary:
	var p := base.duplicate()
	p["sat"] = 1.12
	p["petali"] = 26
	match clima:
		"lutto":
			p["sat"] = 0.42
			p["petali"] = 0
			p["energia"] = float(p["energia"]) * 0.72
			p["amb"] = float(p["amb"]) * 1.15   # meno sole, più cielo piatto
			p["nebbia"] = float(p["nebbia"]) + 0.014
		"commiato":
			p["sat"] = 0.86
			p["petali"] = 10
			p["energia"] = float(p["energia"]) * 0.88
			p["nebbia"] = float(p["nebbia"]) + 0.005
		"malinconia":
			p["sat"] = 0.90
			p["petali"] = 16
			p["energia"] = float(p["energia"]) * 0.94
			p["nebbia"] = float(p["nebbia"]) + 0.003
		"attesa":
			p["sat"] = 1.05
			p["petali"] = 18
		"armonia":
			p["sat"] = 1.24
			p["petali"] = 46
			p["energia"] = float(p["energia"]) * 1.08
		"allegria":
			p["sat"] = 1.18
			p["petali"] = 36
			p["energia"] = float(p["energia"]) * 1.04
	return p


## Quanto è notte, 0..1: la usano lucciole, lanterne e stelle cadenti per
## sapere se è il loro momento.
static func e_notte(p: Dictionary) -> float:
	return clampf(float(p.get("notte", 0.0)), 0.0, 1.0)
