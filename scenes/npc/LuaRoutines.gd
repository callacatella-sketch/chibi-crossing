extends RefCounted

## Il recinto delle routine Lua. Il Regista compone piccoli script Lua
## (i "mattoncini": vai_a, annusa, parla_di, aspetta…) e questo wrapper
## li compila ed esegue DENTRO una sandbox: l'environment del codice
## generato contiene SOLO i mattoncini — niente io, niente os, niente
## load. Una routine eseguita produce un PIANO (lista di passi) che il
## Visitor sa recitare; se la routine è rotta, il piano torna vuoto e
## l'NPC ricade sulla routine di default: nessun salvataggio si rompe.

const CHIBIESE := preload("res://audio/Chibiese.gd")

# verbo -> numero di elementi attesi nel passo
const VERBI := {
	"vai_a": 3, "verso_casa": 1, "aspetta": 2, "annusa": 2,
	"parla_di": 3, "cuoricino": 1,
}
const UMORI := ["neutro", "felice", "domanda", "triste"]
const MAX_PASSI := 10

var _lua  # LuaState (classe della GDExtension, risolta a runtime)
var compilate := 0
var respinte := 0
var eseguite := 0
var fallite := 0

# Il preambolo fidato: definisce il recinto e le due porte d'ingresso
# (compila / esegui). Tutto il resto dello stato Lua non è mai esposto
# al codice generato.
const PRELUDIO := """
local piano = {}

-- i mattoncini: l'INTERO mondo visibile alle routine generate
local recinto = {}
recinto.vai_a = function(x, z) piano[#piano + 1] = { "vai_a", x, z } end
recinto.verso_casa = function() piano[#piano + 1] = { "verso_casa" } end
recinto.aspetta = function(s) piano[#piano + 1] = { "aspetta", s } end
recinto.annusa = function(s) piano[#piano + 1] = { "annusa", s } end
recinto.parla_di = function(c, m) piano[#piano + 1] = { "parla_di", c, m or "neutro" } end
recinto.cuoricino = function() piano[#piano + 1] = { "cuoricino" } end
recinto.caso = function() return math.random() end
recinto.tra = function(a, b) return a + math.random() * (b - a) end
recinto.leggi = function(_chiave) return nil end

local routines = {}

function compila(nome, sorgente)
	nome = tostring(nome)
	sorgente = tostring(sorgente)
	local f, err = load(sorgente, nome, "t", recinto)
	if not f then
		return "sintassi: " .. tostring(err)
	end
	-- guinzaglio a conteggio istruzioni: un sorgente ostile nel salvataggio
	-- non può congelare il gioco all'avvio
	debug.sethook(function() error("timeout", 2) end, "", 300000)
	local ok, routine = pcall(f)
	debug.sethook()
	if not ok then
		return "preambolo: " .. tostring(routine)
	end
	if type(routine) ~= "function" then
		return "la sorgente non restituisce una funzione"
	end
	routines[nome] = routine
	return ""
end

function esegui(nome, ctx)
	local routine = routines[tostring(nome)]
	if routine == nil then
		return nil
	end
	piano = {}
	recinto.leggi = function(chiave) return ctx:get(chiave) end
	debug.sethook(function() error("timeout", 2) end, "", 300000)
	local ok = pcall(routine)
	debug.sethook()
	recinto.leggi = function(_chiave) return nil end
	if not ok then
		return nil
	end
	local out = Array()
	for i = 1, #piano do
		local passo = Array()
		for j = 1, #piano[i] do
			passo:append(piano[i][j])
		end
		out:append(passo)
	end
	return out
end
"""


func _init() -> void:
	if not ClassDB.class_exists("LuaState"):
		printerr("LuaRoutines: LuaState assente (lua-gdextension non caricata)")
		return
	_lua = ClassDB.instantiate("LuaState")
	_lua.open_libraries()
	var r: Variant = _lua.do_string(PRELUDIO)
	if r is LuaError:
		printerr("LuaRoutines: preludio rotto: %s" % r)
		_lua = null


func attivo() -> bool:
	return _lua != null


## Compila una routine nel recinto. Ritorna "" se tutto bene, altrimenti
## il messaggio d'errore (e la routine NON entra in servizio).
func compile_routine(nome: String, sorgente: String) -> String:
	if _lua == null:
		return "lua non attivo"
	if sorgente.length() > 4096:
		respinte += 1
		return "sorgente troppo lunga (%d caratteri)" % sorgente.length()
	_lua.globals["__nome"] = nome
	_lua.globals["__sorgente"] = sorgente
	var res: Variant = _lua.do_string("return compila(__nome, __sorgente)")
	if res is LuaError:
		respinte += 1
		return str(res)
	var err := str(res)
	if err == "":
		compilate += 1
	else:
		respinte += 1
	return err


## Esegue una routine col contesto dato e ritorna il piano validato:
## una lista di passi [verbo, ...]. Vuota = fallback alla routine
## di default (routine assente, errore a runtime o piano non valido).
func plan(nome: String, ctx: Dictionary) -> Array:
	if _lua == null:
		return []
	_lua.globals["__nome"] = nome
	_lua.globals["__ctx"] = ctx
	var res: Variant = _lua.do_string("return esegui(__nome, __ctx)")
	if res == null or res is LuaError or res is not Array:
		fallite += 1
		return []
	var piano := _valida(res)
	if piano.is_empty():
		fallite += 1
	else:
		eseguite += 1
	return piano


# il piano passa la dogana: verbi in whitelist, argomenti sensati,
# coordinate nel prato, durate miti, concetti del vocabolario Chibiese
func _valida(grezzo: Array) -> Array:
	var out := []
	for passo in grezzo:
		if out.size() >= MAX_PASSI:
			break
		if passo is not Array or (passo as Array).is_empty():
			continue
		var p := passo as Array
		var verbo := str(p[0])
		if not VERBI.has(verbo) or p.size() != int(VERBI[verbo]):
			continue
		match verbo:
			"vai_a":
				if p[1] is not float and p[1] is not int:
					continue
				if p[2] is not float and p[2] is not int:
					continue
				out.append(["vai_a",
						clampf(float(p[1]), -30.0, 30.0),
						clampf(float(p[2]), -50.0, 30.0)])
			"aspetta", "annusa":
				if p[1] is not float and p[1] is not int:
					continue
				out.append([verbo, clampf(float(p[1]), 0.5, 15.0)])
			"parla_di":
				var concetto := str(p[1])
				var umore := str(p[2])
				if not CHIBIESE.VOCAB.has(concetto) or umore not in UMORI:
					continue
				out.append(["parla_di", concetto, umore])
			"verso_casa", "cuoricino":
				out.append([verbo])
	return out
