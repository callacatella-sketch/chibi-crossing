#!/usr/bin/env python3
"""UNA mutazione di produzione per volta.  muta.py <n> on|off

⚠️ ANCORE UNICHE E IMPRONTA. La prima stesura usava `str.replace(a, b, 1)` con
ancore che nel file compaiono PIÙ VOLTE (`return 0.0`, `pass`): il verso OFF
rimetteva il codice in un punto a caso — dentro `punto_ritmo` e dentro
`c_decide` — e il banco misurava mutazioni fatte su un file corrotto. Adesso
ogni ancora deve comparire ESATTAMENTE una volta, e dopo ogni OFF si confronta
l'impronta del file con quella di partenza."""
import sys, io, hashlib, json, os
R = "/Users/duck/Developer/chibi-crossing/"
IMP = "/Users/duck/Developer/chibi-crossing/zz_tmp/impronte.json"

MUT = {
 1: ("scenes/npc/Visitors.gd",
     '''		match str(s.get("reazione", "nulla")):
			"trasalisce":
				node.set_meta("postura", "trasalisce")''',
     '''		if node.has_method("somatico"):
			node.call("somatico", float(s.get("forza", 0.0)))
		match str(s.get("reazione", "nulla")):
			"trasalisce":
				node.set_meta("postura", "trasalisce")'''),
 2: ("scenes/npc/Limbico.gd",
     '''	var allarme: float = clampf((maxf(0.0, -carica) + grezzo) * reattivita''',
     '''	var allarme: float = clampf((absf(carica) + grezzo) * reattivita'''),
 3: ("scenes/npc/Limbico.gd",
     '''	elif calore > SOGLIA_SUSSULTO and grezzo <= RIFLESSO_GREZZO:''',
     '''	elif allarme > SOGLIA_SUSSULTO and grezzo <= RIFLESSO_GREZZO:'''),
 4: ("scenes/npc/Limbico.gd",
     '''		reazione = "si_illumina"
	ultimo_sussulto''',
     '''		reazione = "si_illumina"
		arousal = clampf(arousal + calore * SCIA_ALLARME, 0.0, 1.0)
	ultimo_sussulto'''),
 5: ("scenes/npc/Limbico.gd",
     '''	arousal = clampf(arousal + maxf(0.0, -sorpresa) * acuto * reattivita, 0.0, 1.0)''',
     '''	arousal = clampf(arousal + absf(sorpresa) * acuto * reattivita, 0.0, 1.0)'''),
 6: ("scenes/npc/Visitor.gd",
     '''		# e sta qui perché nessun chiamante possa dimenticarselo.
		soma_sciogli()''',
     '''		# e sta qui perché nessun chiamante possa dimenticarselo.
		pass'''),
 7: ("scenes/npc/Gesti.gd",
     '''	var x := clampf(s / SPEGNI, 0.0, 1.0)
	return 1.0 - x * x * (3.0 - 2.0 * x)''',
     '''	return 0.0   # il taglio secco'''),
 8: ("scenes/npc/Visitor.gd",
     '''		# cioè proprio nei decimi di secondo in cui il giocatore è lì.
		_gs_soma_sciolto = -1.0''',
     '''		# cioè proprio nei decimi di secondo in cui il giocatore è lì.
		pass   # non riarma'''),
 9: ("scenes/npc/Limbico.gd",
     '''	var allarme: float = clampf((maxf(0.0, -carica) + grezzo) * reattivita
			* (1.0 + arousal * 0.6), 0.0, 1.0)''',
     '''	var allarme: float = clampf((maxf(0.0, -carica) + grezzo)
			* (1.0 + arousal * 0.6), 0.0, 1.0)'''),
}

def impronta(p):
    return hashlib.sha256(io.open(p, "rb").read()).hexdigest()

n = int(sys.argv[1]); verso = sys.argv[2]
f, vecchio, nuovo = MUT[n]
p = R + f
imp = json.load(io.open(IMP)) if os.path.exists(IMP) else {}
if verso == "on":
    imp[str(n)] = impronta(p)
    json.dump(imp, io.open(IMP, "w"))
s = io.open(p, encoding="utf-8").read()
a, b = (vecchio, nuovo) if verso == "on" else (nuovo, vecchio)
q = s.count(a)
if q != 1:
    raise SystemExit("MUT %d %s: l'ancora compare %d volte in %s — SERVE UN'ANCORA UNICA" % (n, verso, q, f))
io.open(p, "w", encoding="utf-8").write(s.replace(a, b, 1))
if verso == "off":
    if impronta(p) != imp.get(str(n)):
        raise SystemExit("MUT %d: IL FILE NON È TORNATO COM'ERA (%s)" % (n, f))
    print("mutazione %d tolta, file identico all'impronta" % n)
else:
    print("mutazione %d messa su %s" % (n, f))
