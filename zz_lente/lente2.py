#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""LA LENTE «I TEST CHE MENTONO» — vocabolario del corpo.

Guasta UNA riga di produzione per volta e guarda se qualche test diventa
ROSSO. Ogni ancora deve comparire ESATTAMENTE una volta nel file; dopo ogni
ripristino l'impronta SHA-256 del file deve tornare quella di partenza.
"""
import hashlib, json, os, re, subprocess, sys

R = "/Users/duck/Developer/chibi-crossing"
GODOT = os.path.expanduser("~/Downloads/Godot.app/Contents/MacOS/Godot")
G = "scenes/npc/Gesti.gd"
RG = "scenes/npc/Regia.gd"
V = "scenes/npc/Visitor.gd"
VS = "scenes/npc/Visitors.gd"
L = "scenes/npc/Limbico.gd"

def C(f, da, a, id_, nota=""):
    return {"id": id_, "file": f, "da": da, "a": a, "nota": nota}

def K(f, nome, vecchio, nuovo, id_, nota=""):
    return C(f, "const %s := %s" % (nome, vecchio),
             "const %s := %s" % (nome, nuovo), id_, nota)

MUT = [
# ---------------------------------------------------- AMPIEZZE (Gesti.gd)
K(G, "PUNTO_EAR", "-0.30", "-0.02", "AMP punto·orecchie ~0",
  "le orecchie arrivano prime: il segnale di TEMPO del Punto"),
K(G, "PUNTO_VZ", "0.030", "0.0", "AMP punto·peso che continua a 0",
  "l'overshoot che dice muscolo invece di interruttore"),
K(G, "PUNTO_SWAY_PX", "0.008", "0.0", "AMP punto·assestamento px a 0"),
K(G, "PUNTO_SWAY_VRZ", "0.014", "0.0", "AMP punto·assestamento vrz a 0"),
K(G, "PUNTO_FRENO", "0.16", "1.20", "TEMPO punto·frenata 7x piu' lunga",
  "l'istante in cui il corpo si e' fermato E' il gesto"),
K(G, "PUNTO_TENUTA", "1.8", "0.4", "TEMPO punto·tenuta 0.4 (illeggibile)",
  "provinato: sotto 1,2 si confonde con un'esitazione del passo"),
K(G, "PUNTO_TENUTA", "1.8", "6.0", "TEMPO punto·tenuta 6.0 (sembra rotto)",
  "provinato: sopra 2,4 il vicino sembra rotto"),
K(G, "PUNTO_SPINTA", "1.12", "1.00", "AMP punto·ripartenza senza spinta"),
K(G, "PUNTO_EAR_K", "20.0", "1.5", "TEMPO punto·orecchie lente",
  "0,11 s di attacco: sono su PRIMA che il corpo rallenti"),
K(G, "RACCOLTO_SY", "0.90", "0.84", "AMP raccolto·scala 0.84 (verso ✗)",
  "provinato: 0,87 e 0,84 non passano da tutti gli azimut"),
K(G, "RACCOLTO_SY", "0.90", "0.985", "AMP raccolto·scala 0.985 (niente)"),
K(G, "RACCOLTO_EAR", "0.22", "0.02", "AMP raccolto·orecchie ~0"),
K(G, "RACCOLTO_VZ", "0.030", "0.002", "AMP raccolto·passo indietro ~0",
  "il SECONDO canale portante del Raccolto"),
K(G, "RACCOLTO_VX", "0.05", "0.30", "AMP raccolto·busto 6x (diluente)",
  "misurato: e' lui il diluente principale del verso"),
K(G, "RACCOLTO_AX", "0.30", "0.02", "AMP raccolto·braccia ~0"),
K(G, "RACCOLTO_EAR_TREM", "0.007", "0.0", "FORMA raccolto·tremolio orecchie 0"),
K(G, "RIALZO_VY", "0.055", "0.30", "AMP rialzo·verticale 0.30 (verso ✗)",
  "misurato: passa fino a 0,10, non oltre"),
K(G, "RIALZO_SALITA", "22.0", "3.0", "TEMPO rialzo·salita lenta",
  "il segnale E' la velocita': 46 cm/s nel primo decimo"),
K(G, "RIALZO_EAR", "0.34", "0.70", "AMP rialzo·orecchie 0.70 (coprono)",
  "documentato: a 0,70 l'accento copre il verticale"),
K(G, "RIALZO_EAR_RIT", "0.06", "0.0", "FORMA rialzo·orecchie senza ritardo"),
K(G, "CAPO_AMP_MAX", "0.11", "0.24", "AMP capo·ampiezza 0.24 (verso 1,10 ✗)"),
K(G, "CAPO_AMP_MIN", "0.08", "0.008", "AMP capo·ampiezza minima ~0"),
K(G, "CAPO_IV_MIN", "4.5", "0.35", "TEMPO capo·intervallo 0.35 (metronomo)"),
K(G, "CAPO_C", "10.0", "40.0", "FORMA capo·molla sovrasmorzata",
  "zeta 0,383: overshoot del 27% — e' la molla di FaceController"),
K(G, "LARGO_PX", "0.09", "0.02", "AMP largo·scostamento ~0 (canale portante)"),
K(G, "LARGO_VRZ", "0.085", "0.0", "AMP largo·inclinazione 0",
  "un corpo che trasla senza inclinarsi non si sposta, scivola"),
K(G, "LARGO_HZ", "0.11", "0.0", "AMP largo·rollio del capo 0"),
K(G, "LARGO_RITMO", "1.08", "1.0", "AMP largo·ritmo invariato"),
K(G, "LARGO_DIP", "0.45", "0.85", "AMP largo·esitazione 0.85 (fermata)",
  "provinato: a 0,70 diventa una fermata = la parola del Punto"),
K(G, "LARGO_TESTA", "0.55", "0.0", "AMP largo·testa che resta indietro 0"),
K(G, "LARGO_EAR", "0.20", "0.02", "AMP largo·orecchie ~0"),
K(G, "CODA_EAR", "0.45", "0.05", "AMP coda·orecchie ~0"),
K(G, "CODA_AX", "0.30", "0.02", "AMP coda·braccia ~0"),
K(G, "CODA_SCATTO", "0.09", "0.0", "FORMA coda·scatto orecchio 0",
  "«la cosa che dice guardingo meglio di qualunque quota»"),
K(G, "CODA_TREM", "0.012", "0.0", "FORMA coda·tremolio orecchie 0"),
K(G, "CODA_AX_TREM", "0.040", "0.0", "FORMA coda·tremolio braccia 0"),
K(G, "SOMA_PAVIMENTO", "0.72", "0.10", "AMP soma·pavimento 0.10",
  "un vicino che cammina al 10% per minuti"),
K(G, "SOMA_CALO", "0.42", "0.03", "AMP soma·rallentando invisibile"),
K(G, "SOMA_TAU", "18.0", "180.0", "TEMPO soma·rallentando di 20 minuti"),
K(G, "CODA_SOGLIA", "0.06", "0.0", "RETE coda·soglia 0 (non muore mai)"),
K(G, "SPEGNI", "0.35", "0.02", "TEMPO rampa di spegnimento ~taglio"),
K(G, "LIVELLI_RAMPA", "0.55", "0.30", "TEMPO rampa livelli 0.30",
  "misurato: sotto 0,45 salta piu' di quanto e' permesso a un gesto"),
K(G, "DEBITO_MAX", "4.0", "100.0", "RETE debito·tetto a 100 m"),
K(G, "VELOCITA_METRO", "1.45", "0.05", "RETE debito·metro sbagliato"),
K(G, "TREM_DX", "0.73", "1.0", "FORMA seconda lancetta = la prima"),
C(G, "	return 0.85 + 0.15 * sin(fase * 2.3 + 0.7)",
     "	return 1.0   # MUT", "FORMA pigrizia uguale per tutti",
     "il vicino con l'orecchio pigro ce l'ha per sempre"),
C(G, "	return minf(1.0, pow(a, 14.0) + 0.7 * pow(b, 14.0))",
     "	return minf(1.0, pow(a, 2.0) + 0.7 * pow(b, 2.0))  # MUT",
     "FORMA scatto orecchio: gobba larga",
     "una gobba stretta ogni pochi secondi, non un'onda"),
C(G, "	var x := clampf(s / SPEGNI, 0.0, 1.0)\n	return 1.0 - x * x * (3.0 - 2.0 * x)",
     "	return 0.0   # MUT: il taglio secco", "RETE coda_rilascio: taglio secco",
     "un livello che sparisce in un fotogramma, in faccia al giocatore"),
C(G, "	if a < CODA_SOGLIA:\n		return 0.0\n	return a * smoothstep(CODA_SOGLIA, CODA_SOGLIA * 2.0, a)",
     "	if a < CODA_SOGLIA:\n		return 0.0\n	return a  # MUT: gradino",
     "RETE coda sparisce invece di spegnersi"),
# ------------------------------------------------------------- REGIA
C(RG, '"ah_sei_tu": {"frase": "sollievo", "attesa": 0.10},',
      '"ah_sei_tu": {"frase": "sollievo", "attesa": 1.00},',
      "REGIA ah_sei_tu paga il periodo intero",
      "il momento PIU' attribuibile del gioco perde sempre"),
C(RG, '"ha_visto": {"frase": "premessa", "attesa": 1.00},',
      '"ha_visto": {"frase": "premessa", "attesa": 0.0},',
      "REGIA ha_visto non aspetta piu' niente",
      "misurato: 383 richieste in 5 min — si riprende il palco sempre"),
C(RG, '"ha_dedotto": {"frase": "pensiero", "attesa": 0.15},',
      '"ha_dedotto": {"frase": "pensiero", "attesa": 1.00},',
      "REGIA ha_dedotto paga il periodo intero"),
C(RG, "	return posto.distance_to(casa) > 0.25",
      "	return posto.distance_to(casa) > 50.0  # MUT",
      "REGIA ancora_valida: nessuna ancora e' mai valida"),
C(RG, "	if posto == Vector3.ZERO:\n		return false",
      "	if posto == Vector3.ZERO:\n		return true  # MUT",
      "REGIA ancora_valida: «non lo so» diventa un si'"),
K(RG, "CAPO_REGOLAZIONE", "0.45", "0.02", "REGIA capo·regolazione ~mai"),
K(RG, "CAPO_UMORE", "-0.35", "-0.99", "REGIA capo·umore ~mai"),
C(RG, "	return regolazione < CAPO_REGOLAZIONE or umore < CAPO_UMORE or rimugina",
      "	return regolazione < CAPO_REGOLAZIONE or umore < CAPO_UMORE  # MUT",
      "REGIA capo·tolta la causa «rimugina»"),
C(RG, "	return regolazione < CAPO_REGOLAZIONE or umore < CAPO_UMORE or rimugina",
      "	return regolazione < CAPO_REGOLAZIONE  # MUT",
      "REGIA capo·UNA causa sola (il cruscotto)"),
C(RG, "	if not ricordo_nuovo:\n		return \"\"          # la raffica: la testa si rialza, il corpo no",
      "	pass  # MUT: la raffica passa",
      "REGIA sguardo·la raffica non si ferma piu'",
      "misurato: il 79% delle richieste erano ripetizioni"),
C(RG, '	return "era_per_me" if per_me else "ha_visto"',
      '	return "ha_visto" if per_me else "era_per_me"  # MUT',
      "REGIA sguardo·le due occasioni invertite"),
C(RG, "	if not OCCASIONI.has(occasione):\n		return false",
      "	if not OCCASIONI.has(occasione):\n		return true  # MUT",
      "REGIA palco·l'occasione sconosciuta passa"),
C(RG, "	return residuo <= passo * (1.0 - attesa_di(occasione)) + 0.0001",
      "	return residuo <= 0.0001  # MUT: solo il gettone",
      "REGIA palco·l'ordine delle occasioni non esiste piu'"),
# ------------------------------------------------------------ VISITOR
K(V, "GESTO_BLEND_MIN", "0.6", "0.0", "VALV blend·nessun passo da spezzare"),
K(V, "GESTO_STRADA_MIN", "3.0", "0.0", "VALV strada·zero metri davanti"),
K(V, "GESTO_ATTESA_MAX", "8.0", "600.0", "VALV anziano·aspetta 10 minuti"),
K(V, "SOLLIEVO_FINESTRA", "1.5", "60.0", "VALV sollievo·finestra di un minuto"),
K(V, "CAPO_STORTO", "0.02", "3.0", "VALV capo_storto·mai storto"),
C(V, "	return _gs_soma > 0.0 and _gs_soma_t <= SOLLIEVO_FINESTRA \\\n			and GESTI.coda_ampiezza(_gs_soma, _gs_soma_t) > 0.0",
     "	return true  # MUT", "VALV sussulto_fresco·sempre vero"),
C(V, "			if bool(d.get(\"buio\", false)) and not _sussulto_fresco():\n				return false",
     "			pass  # MUT", "VALV rialzo·il buio non e' piu' precondizione"),
C(V, "			if _gs_viaggio:\n				return false      # una sola per viaggio",
     "			pass  # MUT", "VALV un Punto per viaggio·tolta"),
C(V, "	if _hidden or dorme() or in_scena():\n		return false",
     "	if dorme() or in_scena():\n		return false  # MUT", "VALV gesto_libero·senza _hidden"),
C(V, "	if _hidden or dorme() or in_scena():\n		return false",
     "	if _hidden or in_scena():\n		return false  # MUT", "VALV gesto_libero·senza dorme()"),
C(V, "	if _hidden or dorme() or in_scena():\n		return false",
     "	if _hidden or dorme():\n		return false  # MUT", "VALV gesto_libero·senza in_scena()"),
C(V, "	if _rc_trans != \"\" and not (scioglie_il_riflesso and _rc_trans == \"trasalisce\"):\n		return false",
     "	pass  # MUT", "VALV riflesso sopra il vocabolario·tolta"),
C(V, "	if ok and bool(d.get(\"capo\", false)) and not _gs_capo_frase \\\n			and (_gs_capo or _capo_concesso()):",
     "	if ok and bool(d.get(\"capo\", false)) and not _gs_capo_frase:  # MUT",
     "VALV frase·non chiede il permesso al villaggio"),
C(V, "	if _gs_capo_frase and gesto_in_corso() == \"\":\n		_gs_capo_frase = false\n		_capo_aggiorna()",
     "	pass  # MUT", "RETE capo·la testa resta storta per sempre",
     "misurato col Salone vero: 5,9 gradi 35 s dopo"),
C(V, "	if _gs_capo_frase and gesto_in_corso() == \"\":",
     "	if _gs_capo_frase and _gs_nome == \"\":  # MUT",
     "RETE capo·guarda il nome invece di gesto_in_corso"),
C(V, "			or not is_instance_valid(_corpo) or _hidden or _state == \"tk_nap\" \\\n			or in_scena()",
     "			or not is_instance_valid(_corpo) or _hidden or _state == \"tk_nap\"  # MUT",
     "RETE sospeso·senza in_scena()"),
C(V, "			or not is_instance_valid(_corpo) or _hidden or _state == \"tk_nap\" \\\n			or in_scena()",
     "			or not is_instance_valid(_corpo) or _hidden or in_scena()  # MUT",
     "RETE sospeso·senza tk_nap"),
C(V, "	if _gs_soma <= 0.0:\n		return\n	_gs_soma_t += delta",
     "	if _gs_soma <= 0.0:\n		return\n	if guadagno > 0.0:\n		_gs_soma_t += delta  # MUT",
     "RETE soma·l'orologio si ferma da sospesi",
     "un livello sospeso che non invecchia riemerge intatto"),
C(V, "	canali[\"r\"] = float(canali[\"r\"]) * lerpf(1.0, r, guadagno)",
     "	canali[\"r\"] = float(canali[\"r\"]) * r  # MUT",
     "RETE soma·il ritmo non passa dalla rampa",
     "restituirlo di colpo = +28% di velocita' in un fotogramma"),
C(V, "	if forza >= _gs_soma * exp(-_gs_soma_t / GESTI.CODA_TAU) * _soma_resto():\n		_gs_soma = forza",
     "	if true:\n		_gs_soma = forza  # MUT",
     "RETE soma·una paura piccola ACCORCIA la grande"),
C(V, "		# cioè proprio nei decimi di secondo in cui il giocatore è lì.\n		_gs_soma_sciolto = -1.0",
     "		# cioè proprio nei decimi di secondo in cui il giocatore è lì.\n		pass  # MUT",
     "RETE soma·la paura nuova non interrompe lo scioglimento"),
C(V, "		# e sta qui perché nessun chiamante possa dimenticarselo.\n		soma_sciogli()",
     "		# e sta qui perché nessun chiamante possa dimenticarselo.\n		pass  # MUT",
     "RETE sollievo·il corpo NON molla la coda"),
C(V, "	_gs_cede = lerpf(_gs_cede, 0.0 if _tst_t > 0.0 else 1.0,\n			1.0 - exp(-6.0 * delta))",
     "	_gs_cede = 1.0  # MUT",
     "VALV largo·la testa non cede mai alla ricevuta"),
C(V, "	if _gs_debito > GESTI.DEBITO_MAX:",
     "	if false:  # MUT", "RETE debito·il tetto tolto"),
C(V, "	_gs_r = clampf(float(canali[\"r\"]), 0.0, 1.25)",
     "	_gs_r = float(canali[\"r\"])  # MUT", "RETE ritmo·nessuna forbice"),
C(V, "	if absf(f - 1.0) < 0.0005:\n		if _gs_scala_nodo != null:\n			if is_instance_valid(_gs_scala_nodo) and _gs_scala_nodo == _corpo:\n				_corpo.scale = _gs_scala_riposo\n			_gs_scala_nodo = null\n		return",
     "	if absf(f - 1.0) < 0.0005:\n		_gs_scala_nodo = null\n		return  # MUT",
     "RETE scala·non restituisce la scala di riposo"),
C(V, "	_gesto_scala(float(_gs_cur.get(\"sy\", 1.0)))",
     "	pass  # MUT", "RETE scala·il canale sy non arriva al corpo"),
# ----------------------------------------------------------- VISITORS
K(VS, "GESTO_RAGGIO", "9.0", "15.0", "USH raggio 15 m (6,7 px = rumore)"),
K(VS, "GESTO_QUOTA", "0.55", "1.6", "USH quota dell'inquadratura 1,6 m"),
K(VS, "GESTO_PASSO", "12.0", "0.5", "USH gettone del villaggio 0,5 s"),
K(VS, "GESTO_RIPOSO", "300.0", "1.0", "USH riposo della persona 1 s (teatrino)"),
K(VS, "CAPO_MAX", "2", "5", "USH cinque teste inclinate insieme"),
K(VS, "GESTO_EVITA_RAGGIO", "7.0", "100.0", "USH sala d'attesa senza raggio"),
C(VS, "	return cam.is_position_in_frustum(pos + Vector3(0, GESTO_QUOTA, 0))",
      "	return true  # MUT", "USH inquadratura·il cancello tolto",
      "misurato: 8 gesti su 12 fuori dall'inquadratura"),
C(VS, "	if _player == null \\\n			or _player.global_position.distance_to(nodo.global_position) > GESTO_RAGGIO:\n		_no(conta, \"fuori raggio\")\n		return false",
      "	pass  # MUT", "USH fuori raggio·il cancello tolto"),
C(VS, "	if _gesto_chi != \"\":\n		_no(conta, \"un altro sta parlando\")\n		return false",
      "	pass  # MUT", "USH gettone·due gesti insieme (il carillon)"),
C(VS, "	if not REGIA.palco_libero(occasione, float(_gesto_riposo.get(label, 0.0)),\n			GESTO_RIPOSO):",
      "	if false:  # MUT", "USH riposo della persona·tolto"),
C(VS, "	if vuole and not bool(nodo.call(\"capo_storto\")) and capi_storti() >= CAPO_MAX:\n		return",
      "	pass  # MUT", "USH tetto delle teste·tolto"),
C(VS, "			and not bool(nodo.call(\"dorme\")) and not bool(nodo.call(\"is_hidden\")) \\\n			and not bool(nodo.call(\"in_scena\"))",
      "  # MUT", "USH capo·le tre valvole tolte"),
C(VS, "				if node.has_method(\"somatico\"):\n					node.call(\"somatico\", float(s.get(\"forza\", 0.0)))",
      "				pass  # MUT", "CABL somatico·la coda non si accende mai"),
C(VS, '			chiedi_gesto(str(r.get("label", "")), "ha_dedotto")',
      "			pass  # MUT", "CABL ha_dedotto"),
C(VS, '	if chiedi_gesto(label, "se_lo_tiene"):',
      "	if false:  # MUT", "CABL se_lo_tiene"),
C(VS, '				chiedi_gesto(label, "si_e_trattenuto")',
      "				pass  # MUT", "CABL si_e_trattenuto"),
C(VS, '			chiedi_gesto(label, "ah_sei_tu")',
      "			pass  # MUT", "CABL ah_sei_tu"),
C(VS, '			_rimanda_gesto(label, "quel_posto_no", 4.0, {"posto": dove}, dove)',
      "			pass  # MUT", "CABL quel_posto_no"),
C(VS, '	_rimanda_gesto(label, "se_lo_tiene", PERCEZIONE.DURATA_SGUARDO)',
      "	pass  # MUT", "CABL se_lo_tiene·sala d'attesa"),
# ------------------------------------------------------------ LIMBICO
C(L, "	var allarme: float = clampf((maxf(0.0, -carica) + grezzo) * reattivita",
     "	var allarme: float = clampf((absf(carica) + grezzo) * reattivita  # MUT",
     "LIMB due monete·l'allarme rimangia l'affetto"),
C(L, "	elif calore > SOGLIA_SUSSULTO and grezzo <= RIFLESSO_GREZZO:",
     "	elif allarme > SOGLIA_SUSSULTO and grezzo <= RIFLESSO_GREZZO:  # MUT",
     "LIMB cuoricino·acceso dall'allarme"),
C(L, "		reazione = \"si_illumina\"",
     "		reazione = \"si_illumina\"\n		arousal = clampf(arousal + calore * SCIA_ALLARME, 0.0, 1.0)  # MUT",
     "LIMB gioia·lascia scia di allerta"),
C(L, "	arousal = clampf(arousal + maxf(0.0, -sorpresa) * acuto * reattivita, 0.0, 1.0)",
     "	arousal = clampf(arousal + absf(sorpresa) * acuto * reattivita, 0.0, 1.0)  # MUT",
     "LIMB strada lenta·la gioia alza l'allerta"),
C(L, "	var allarme: float = clampf((maxf(0.0, -carica) + grezzo) * reattivita\n			* (1.0 + arousal * 0.6), 0.0, 1.0)",
     "	var allarme: float = clampf((maxf(0.0, -carica) + grezzo)\n			* (1.0 + arousal * 0.6), 0.0, 1.0)  # MUT",
     "LIMB allarme·senza il guadagno del carattere"),
K(L, "SOGLIA_SUSSULTO", "0.22", "0.02", "LIMB soglia·tutto fa sussultare"),
K(L, "RIFLESSO_GREZZO", "0.25", "0.99", "LIMB cuoricino·anche caricando addosso"),
K(L, "SCIA_ALLARME", "0.55", "0.0", "LIMB la paura non lascia scia"),
]

def impronta(p):
    return hashlib.sha256(open(p, "rb").read()).hexdigest()

def prova(casi):
    env = dict(os.environ)
    if casi:
        env["CHIBI_CASI"] = casi
        script = "res://zz_lente/runner_filtrato.gd"
    else:
        script = "res://tests/test_runner.gd"
    r = subprocess.run([GODOT, "--headless", "--path", R, "--script", script],
                       capture_output=True, text=True, env=env, cwd=R)
    out = r.stdout + r.stderr
    m = re.search(r"TEST: (\d+) passati, (\d+) falliti", out)
    err = out.count("SCRIPT ERROR")
    if not m:
        return {"ok": -1, "ko": -1, "err": err, "rossi": ["(nessun referto)"]}
    return {"ok": int(m.group(1)), "ko": int(m.group(2)), "err": err,
            "rossi": [l.strip() for l in out.splitlines() if "FAIL:" in l]}

def main():
    modo = sys.argv[1] if len(sys.argv) > 1 else "filtro"
    solo = sys.argv[2] if len(sys.argv) > 2 else None
    casi = None if modo == "intera" else open(os.path.join(R, "zz_lente/casi.txt")).read().strip()
    # 1) le ancore
    guasti = 0
    for m in MUT:
        p = os.path.join(R, m["file"])
        n = open(p, encoding="utf-8").read().count(m["da"])
        if n != 1:
            print("ANCORA NON UNICA (%d)  %s   [%s]" % (n, m["id"], m["file"]))
            guasti += 1
    if guasti:
        print("--- %d ancore da sistemare, non si parte" % guasti)
        return 1
    base = prova(casi)
    print("BASE  passati=%d falliti=%d err=%d   (%s)"
          % (base["ok"], base["ko"], base["err"], modo))
    sys.stdout.flush()
    esiti = []
    for m in MUT:
        if solo and solo not in m["id"]:
            continue
        p = os.path.join(R, m["file"])
        testo = open(p, encoding="utf-8").read()
        imp0 = impronta(p)
        try:
            open(p, "w", encoding="utf-8").write(testo.replace(m["da"], m["a"]))
            r = prova(casi)
        finally:
            open(p, "w", encoding="utf-8").write(testo)
            assert impronta(p) == imp0, "RIPRISTINO FALLITO " + m["file"]
        verde = r["ko"] == 0
        stato = ">>> VERDE <<<" if verde else ("ROSSE %d" % r["ko"])
        print("%-52s %-14s err=%d pass=%d" % (m["id"], stato, r["err"], r["ok"]))
        for l in r["rossi"][:3]:
            print("        ", l[:140])
        sys.stdout.flush()
        esiti.append(dict(m, verde=verde, ko=r["ko"], err=r["err"], ok=r["ok"],
                          rossi=r["rossi"][:6]))
    fuori = os.path.join(R, "zz_lente/esiti_%s.json" % modo)
    json.dump(esiti, open(fuori, "w"), indent=1, ensure_ascii=False)
    verdi = [e for e in esiti if e["verde"]]
    print("\n=== %d mutazioni · %d VERDI (la suite non le vede) ===" % (len(esiti), len(verdi)))
    for e in verdi:
        print("   VERDE  " + e["id"])
    return 0

if __name__ == "__main__":
    sys.exit(main())
