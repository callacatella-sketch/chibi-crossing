#!/usr/bin/env python3
"""IL BANCO DELLA RELEASE — si prova quello che la CI non fa provare a nessuno.

    python3 tools/prova_release.py            # tutto, tranne la rete
    python3 tools/prova_release.py --rete     # aggiunge la HEAD vera a monte

`.github/workflows/release.yml` ha dei cancelli che valgono UNA volta sola, il
giorno del tag, dopo un'ora fra compilazione, export e notarizzazione: se uno di
loro e' scritto storto non lo scopre nessuno — o peggio, resta VERDE su un
pacchetto rotto. E il guasto che sorvegliano e' invisibile per progetto: un gioco
senza la Fase 5 e' un gioco INTERO (le lettere scritte a mano ci sono e restano,
la casella «Il villaggio pensa» semplicemente non compare), quindi nessuna
partita, nessun collaudo e nessuna segnalazione potranno mai dire che e' rotto.

Questo banco NON REIMPLEMENTA NIENTE: gli script se li estrae dal workflow vero
(sono quelli, byte per byte) e li fa girare su pacchetti FABBRICATI che hanno la
forma di quelli veri. Poi guasta UNA cosa per volta e pretende il rosso GIUSTO —
il messaggio, non solo il codice d'uscita: un cancello che rifiuta tutto sarebbe
verde qui e inutile in partita.

Tre cose che questo banco ha gia' trovato, e che `bash -n` non poteva vedere:
  · dei backtick vivi dentro un messaggio d'errore (facevano partire un `sed`
    senza argomenti: legge stdin, e il passo si piantava per sempre);
  · l'elenco delle licenze scritto a mano restava VERDE quando ne compariva una
    nuova in `misc/licenze/` (la controprova qui sotto lo dimostra sul codice
    vecchio, preso da git);
  · un pacchetto scritto con le barre ROVESCIATE deve restare verde — e ci
    riesce solo se il `tr` e gli asterischi dei `find` ci sono.

Serve PyYAML (`python3 -m pip install --user pyyaml`).
"""
import os
import shutil
import stat
import subprocess
import sys

try:
    import yaml
except ImportError:  # pragma: no cover
    sys.exit("serve PyYAML: python3 -m pip install --user pyyaml")

RADICE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORKFLOW = os.path.join(RADICE, ".github/workflows/release.yml")
LAVORO = "/tmp/chibi-prova-release"
FRASE = ("Gemma is provided under and subject to the Gemma Terms of Use found at "
         "ai.google.dev/gemma/terms")


def carica(percorso=None):
    return yaml.safe_load(open(percorso or WORKFLOW, encoding="utf-8"))


def passo(doc, job, nome):
    for p in doc["jobs"][job].get("steps", []):
        if p.get("name") == nome:
            return p["run"]
    raise SystemExit("passo non trovato nel workflow: %s / %s" % (job, nome))


def gira(script, cwd, amb=None):
    r = subprocess.run(["bash", "-c", script], cwd=cwd, capture_output=True,
                       text=True, env=amb, stdin=subprocess.DEVNULL, timeout=120)
    return r.returncode, r.stdout + r.stderr


def riga(ok, titolo, coda=""):
    print(("  ok    " if ok else "  ROSSO ") + titolo + coda, flush=True)
    return ok


# ===========================================================================
# 1) LA FORMA: il YAML si legge, e ogni script di shell e' sintatticamente sano
# ===========================================================================
def la_forma():
    print("\n== la forma del workflow ==")
    doc = carica()
    buoni = riga(True, "il YAML si legge · job: " + ", ".join(doc["jobs"]))
    for nome, job in doc["jobs"].items():
        implicito = "pwsh" if str(job.get("runs-on", "")).startswith("windows") else "bash"
        for p in job.get("steps", []):
            script = p.get("run")
            if script is None or (p.get("shell") or implicito) not in ("bash", "sh"):
                continue
            r = subprocess.run(["bash", "-n", "-c", script], capture_output=True, text=True)
            if r.returncode != 0:
                buoni &= riga(False, "%s · %s" % (nome, p.get("name")), "\n" + r.stderr)
            # I BACKTICK VIVI: dentro un messaggio a doppi apici sono una
            # sostituzione di comando, non una citazione. `sed` senza argomenti
            # legge stdin, e il passo si pianta. Nei commenti (#) vanno bene.
            for i, l in enumerate(script.split("\n"), 1):
                if "`" in l and not l.lstrip().startswith("#"):
                    buoni &= riga(False, "%s · %s · riga %d: backtick VIVO fuori da un commento"
                                  % (nome, p.get("name"), i))
    return riga(buoni, "tutti gli script di shell sono sani") and buoni


# ===========================================================================
# 2) I CANCELLI DEL JOB `release`, su pacchetti fabbricati
# ===========================================================================
def cuore(con_llm=True):
    """Un finto binario del cuore C++: con o senza il simbolo che conta."""
    b = b"\x7fELF" + os.urandom(4096) + b"\x00SurvivalComponent\x00GridManager\x00"
    if con_llm:
        b += b"\x00LlmLocale\x00_ZN9LlmLocale4apriEv\x00LlmLocale\x00"
    return b + os.urandom(2048)


def fabbrica(dist, licenze, *, llm_win=True, llm_mac=True, salta_licenza=None,
             rompi_frase=False, senza_dll=False, barre_rovesce=False):
    import zipfile
    os.makedirs(dist, exist_ok=True)
    sep = "\\" if barre_rovesce else "/"
    with zipfile.ZipFile(os.path.join(dist, "ChibiCrossing-windows.zip"), "w",
                         zipfile.ZIP_DEFLATED) as z:
        z.writestr("ChibiCrossing.exe", os.urandom(65536))
        if not senza_dll:
            z.writestr("chibi_crossing.windows.template_release.x86_64.dll", cuore(llm_win))
        z.writestr("lua_gdextension.dll", os.urandom(4096))  # un'altra dll, per non farla facile
        for n, c in licenze.items():
            if n == salta_licenza:
                continue
            if rompi_frase and n == "NOTICE-Gemma.txt":
                c = c.replace(FRASE, FRASE.replace(" found at", "\nfound at"))
            z.writestr("Licenze%s%s" % (sep, n), c)
    app = "ChibiCrossing.app"
    with zipfile.ZipFile(os.path.join(dist, "ChibiCrossing-macos.zip"), "w",
                         zipfile.ZIP_DEFLATED) as z:
        z.writestr(app + "/Contents/MacOS/ChibiCrossing", os.urandom(65536))
        z.writestr(app + "/Contents/Resources/ChibiCrossing.pck", os.urandom(131072))
        z.writestr(app + "/Contents/Frameworks/"
                   "libchibi_crossing.macos.template_release.universal.dylib", cuore(llm_mac))
        for n, c in licenze.items():
            if n != salta_licenza:
                z.writestr(app + "/Contents/Resources/Licenze/" + n, c)


def i_cancelli():
    print("\n== i cancelli del job `release` ==")
    doc = carica()
    ordine = ["Controlla che ci siano entrambe le build", "Apri i pacchetti",
              "Le licenze sono DENTRO i pacchetti?", "Il gioco che pubblichiamo sa pensare?"]
    script = {n: passo(doc, "release", n) for n in ordine}
    vere = {n: open(os.path.join(RADICE, "misc/licenze", n), encoding="utf-8").read()
            for n in sorted(os.listdir(os.path.join(RADICE, "misc/licenze"))) if n.endswith(".txt")}

    def scena(titolo, *, atteso, cerca=None, aggiungi=None, svuota=False, **kw):
        banco = os.path.join(LAVORO, "cancelli")
        shutil.rmtree(banco, ignore_errors=True)
        txt = os.path.join(banco, "misc/licenze")
        os.makedirs(txt)
        if not svuota:
            for n, c in vere.items():
                open(os.path.join(txt, n), "w", encoding="utf-8").write(c)
            for n, c in (aggiungi or {}).items():
                open(os.path.join(txt, n), "w", encoding="utf-8").write(c)
        fabbrica(os.path.join(banco, "dist"), vere, **kw)
        rossi, tutto = [], []
        for nome in ordine:
            codice, uscita = gira(script[nome], banco)
            tutto.append(uscita)
            if codice != 0:
                rossi.append(nome)
                break
        fuori = "\n".join(tutto)
        ok = (not rossi) if atteso == "verde" else bool(rossi)
        if ok and cerca:
            ok = cerca in fuori
        return riga(ok, titolo, "" if ok else "\n      " + fuori.strip()[-700:])

    prove = [
        scena("due pacchetti sani: verde", atteso="verde"),
        scena("manca una licenza nel pacchetto", atteso="rosso", cerca="non contiene Licenze/",
              salta_licenza="LICENZE-TERZE-PARTI.txt"),
        scena("il NOTICE c'e' ma la frase e' andata a capo", atteso="rosso",
              cerca="Sezione 3.1 punto 4", rompi_frase=True),
        scena("una licenza NUOVA nel repo, non nei pacchetti", atteso="rosso",
              cerca="non contiene Licenze/AVVISO-NUOVO.txt", aggiungi={"AVVISO-NUOVO.txt": "x\n"}),
        scena("misc/licenze svuotata (il cancello non si spegne da solo)", atteso="rosso",
              cerca="non contiene nessun .txt", svuota=True),
        scena("il cuore Windows non conosce LlmLocale", atteso="rosso",
              cerca="Nel pacchetto windows il cuore C++ non conosce LlmLocale", llm_win=False),
        scena("il cuore macOS non conosce LlmLocale", atteso="rosso",
              cerca="Nel pacchetto macos il cuore C++ non conosce LlmLocale", llm_mac=False),
        scena("nel pacchetto Windows manca proprio la libreria", atteso="rosso",
              cerca="NESSUNA libreria del cuore", senza_dll=True),
        scena("pacchetto con le barre ROVESCIATE: deve restare verde", atteso="verde",
              barre_rovesce=True),
    ]
    return all(prove)


def la_controprova():
    """Il cancello di PRIMA (git HEAD) sulla stessa cartella: se non distingue,
    la modifica non aveva un motivo misurato."""
    print("\n== la controprova (contro il cancello di git HEAD) ==")
    try:
        vecchio = subprocess.check_output(
            ["git", "-C", RADICE, "show", "HEAD:.github/workflows/release.yml"],
            text=True, stderr=subprocess.DEVNULL)
    except subprocess.CalledProcessError:
        return riga(True, "nessuna versione precedente in git: salto")
    try:
        prima = passo(yaml.safe_load(vecchio), "release", "Le licenze sono DENTRO i pacchetti?")
    except SystemExit:
        return riga(True, "il passo non esisteva ancora in git HEAD: salto")
    doc = carica()
    adesso = passo(doc, "release", "Le licenze sono DENTRO i pacchetti?")
    # ⚠️ SE I DUE CANCELLI SONO LO STESSO CANCELLO, NON C'E' NIENTE DA
    # DIMOSTRARE — e pretenderlo lo stesso e' una guardia che non puo' MAI
    # essere verde, cioe' lo specchio di una che non puo' mai essere rossa.
    #
    # Questa riga chiede `vecchio verde E nuovo rosso`: vero soltanto finche'
    # il miglioramento e' NON COMMITTATO. Committato, git HEAD e l'albero di
    # lavoro sono lo stesso testo, tutti e due escono 1, e la controprova
    # resta rossa per sempre. Cosi' `prova_release.py` ha stampato «QUALCOSA
    # NON VA» a ogni corsa dal giorno in cui quel cancello e' stato migliorato
    # — e un attrezzo che dice sempre di no smette di essere letto. E' per
    # questo che il difetto del preflight (nato il 2026-08-13: tre costanti su
    # cinque lette dal file sbagliato, e `needs: preflight` che avrebbe fatto
    # fallire il PRIMO tag) e' rimasto li' quaranta giorni: il banco lo
    # diceva, in mezzo a un verdetto rosso che non voleva dire piu' niente.
    if prima.strip() == adesso.strip():
        return riga(True, "il cancello non e' cambiato da git HEAD: niente da distinguere")
    banco = os.path.join(LAVORO, "controprova")
    shutil.rmtree(banco, ignore_errors=True)
    txt = os.path.join(banco, "misc/licenze")
    os.makedirs(txt)
    vere = {}
    for n in sorted(os.listdir(os.path.join(RADICE, "misc/licenze"))):
        if n.endswith(".txt"):
            vere[n] = open(os.path.join(RADICE, "misc/licenze", n), encoding="utf-8").read()
            open(os.path.join(txt, n), "w", encoding="utf-8").write(vere[n])
    open(os.path.join(txt, "AVVISO-NUOVO.txt"), "w").write("un avviso in piu'\n")  # IL GUASTO
    fabbrica(os.path.join(banco, "dist"), vere)
    gira(passo(doc, "release", "Apri i pacchetti"), banco)
    v, _ = gira(prima, banco)
    n, _ = gira(adesso, banco)
    # ⚠️ E SE IL VECCHIO GIA' LA VEDEVA (v != 0), IL ROSSO NON DICE «il tuo
    # cancello e' rotto»: dice «hai cambiato QUESTO passo per un'altra
    # ragione, e su QUESTA scena i due si comportano uguale». Va scritto, o il
    # prossimo va a cercare un guasto che non c'e' — che e' la stessa trappola
    # per cui questa funzione era rimasta rossa per sempre.
    nota = ""
    if v != 0:
        nota = (" — il vecchio la vedeva gia': se questo passo l'hai cambiato"
                " per un'altra ragione, la scena da distinguere e' un'altra")
    return riga(v == 0 and n != 0,
                "una licenza nuova: il cancello vecchio esce %d, il nuovo %d%s"
                % (v, n, nota))


# ===========================================================================
# 3) IL PREFLIGHT: costanti guaste, e risposte di Hugging Face preparate
# ===========================================================================
def teste(codice="302", etag=None, size="2489757856"):
    r = ["HTTP/2 %s " % codice, "content-type: text/plain"]
    if etag:
        r.append('x-linked-etag: "%s"' % etag)
    if size:
        r.append("x-linked-size: " + size)
    return "\r\n".join(r) + "\r\n\r\n"


def il_preflight(con_rete=False):
    print("\n== il preflight (la sorgente del modello) ==")
    doc = carica()
    script = passo(doc, "preflight", "Il modello si scarica ancora senza credenziali?")
    # ⚠️ LE CINQUE COSTANTI STANNO IN DUE CASE, e il banco deve metterle in
    # scena tutte e due: `systems/Scarico.gd` dice DOVE andare a prendere il
    # modello (REPO, FILE_A_MONTE, REVISIONE), `systems/Llm.gd` dice COS'E'
    # (IMPRONTA_SPEDITO, BYTE_MODELLO).
    #
    # Fino al 2026-09-22 questo banco ne metteva in scena UNA — ma anche il
    # passo vero leggeva tutto da Llm.gd, quindi la scena «verde» era ROSSA e
    # diceva esattamente la cosa giusta: tre costanti su cinque non si
    # leggevano, il preflight usciva 1, e con `needs: preflight` il primo tag
    # non avrebbe prodotto nessuna Release. Il banco la guardia ce l'aveva;
    # non l'aveva fatto girare nessuno dal 2026-08-13.
    CASE = ("systems/Llm.gd", "systems/Scarico.gd")
    veri = {f: open(os.path.join(RADICE, f), encoding="utf-8").read() for f in CASE}

    def leggi(dove, nome, forma='"([^"]*)"'):
        import re
        m = re.search(r'^const %s := %s$' % (nome, forma), veri[dove], re.M)
        return m.group(1) if m else ""

    impronta = leggi("systems/Llm.gd", "IMPRONTA_SPEDITO")
    byte = leggi("systems/Llm.gd", "BYTE_MODELLO", r"(\d+)")

    def scena(titolo, *, atteso, cerca=None, guasto=None, risposta=None):
        banco = os.path.join(LAVORO, "preflight")
        shutil.rmtree(banco, ignore_errors=True)
        os.makedirs(os.path.join(banco, "systems"))
        os.makedirs(os.path.join(banco, "finto"))
        for f, t in veri.items():
            open(os.path.join(banco, f), "w", encoding="utf-8").write(
                guasto(f, t) if guasto else t)
        amb = dict(os.environ)
        if risposta is not None:
            # un finto `curl` in testa al PATH: la rete non si interroga otto
            # volte dentro un banco, e certe risposte (403, 404, 429) non si
            # possono ottenere a comando.
            open(os.path.join(banco, "finto/risposta.txt"), "w").write(risposta)
            f = os.path.join(banco, "finto/curl")
            open(f, "w").write('#!/bin/sh\ncat "$(dirname "$0")/risposta.txt"\n')
            os.chmod(f, os.stat(f).st_mode | stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH)
            amb["PATH"] = os.path.join(banco, "finto") + ":" + amb["PATH"]
        codice, fuori = gira(script, banco, amb)
        ok = (codice == 0) if atteso == "verde" else (codice != 0)
        if ok and cerca:
            ok = cerca in fuori
        return riga(ok, titolo, "" if ok else "\n      " + fuori.strip()[-600:])

    rev = leggi("systems/Scarico.gd", "REVISIONE")
    buona = teste(etag=impronta, size=byte)
    prove = [
        scena("le costanti del gioco + la risposta buona", atteso="verde",
              cerca="scaricabile senza credenziali", risposta=buona),
        scena("IMPRONTA_SPEDITO rinominata (Llm.gd)", atteso="rosso",
              cerca="Non riesco a leggere IMPRONTA_SPEDITO", risposta=buona,
              guasto=lambda f, t: t.replace("const IMPRONTA_SPEDITO :=", "const IMPRONTA_X :=")),
        scena("REPO rinominata (Scarico.gd)", atteso="rosso",
              cerca="Non riesco a leggere REPO", risposta=buona,
              guasto=lambda f, t: t.replace("const REPO :=", "const REPOSITORY :=")),
        scena("FILE_A_MONTE rinominata (Scarico.gd)", atteso="rosso",
              cerca="Non riesco a leggere FILE_A_MONTE", risposta=buona,
              guasto=lambda f, t: t.replace("const FILE_A_MONTE :=", "const IL_FILE :=")),
        scena("REVISIONE rinominata (Scarico.gd)", atteso="rosso",
              cerca="Non riesco a leggere REVISIONE", risposta=buona,
              guasto=lambda f, t: t.replace("const REVISIONE :=", "const REV :=")),
        # ⚠️ IL DIFETTO DEL 2026-08-13, RIPRODOTTO: la costante non sparisce —
        # TRASLOCA. C'e' ancora, nel progetto, col suo nome e col suo valore,
        # solo in un'altra casa; e il cancello deve accorgersene lo stesso,
        # perche' e' esattamente cosi' che si e' rotto (il corriere si porto'
        # via le tre costanti della sorgente e questo passo resto' a cercarle
        # dov'erano non state mai).
        scena("REVISIONE traslocata da Scarico.gd a Llm.gd", atteso="rosso",
              cerca="VIVE IN UN ALTRO FILE", risposta=buona,
              guasto=lambda f, t: (
                  t.replace("const REVISIONE :=", "const REVISIONE_ALTROVE :=")
                  if f.endswith("Scarico.gd")
                  else t + '\nconst REVISIONE := "%s"\n' % rev)),
        scena("BYTE_MODELLO rinominata (Llm.gd)", atteso="rosso",
              cerca="Non riesco a leggere BYTE_MODELLO", risposta=buona,
              guasto=lambda f, t: t.replace("const BYTE_MODELLO :=", "const QUANTO_PESA :=")),
        scena("il file a monte e' stato RICARICATO diverso", atteso="rosso",
              cerca="Il file a monte ha impronta", risposta=teste(etag="a" * 64, size=byte)),
        scena("il file a monte ha cambiato dimensione", atteso="rosso", cerca="la barra mente",
              risposta=teste(etag=impronta, size="1234567890")),
        scena("il repository e' diventato «gated» (403)", atteso="rosso",
              cerca="e' diventato «gated»", risposta=teste("403", size=None)),
        scena("servono credenziali (401)", atteso="rosso", cerca="e' diventato «gated»",
              risposta=teste("401", size=None)),
        scena("la revisione pinnata non c'e' piu' (404)", atteso="rosso",
              cerca="il file pinnato non c'e' piu'", risposta=teste("404", size=None)),
        scena("troppe richieste (429): passa, con avviso", atteso="verde",
              cerca="::warning::Hugging Face risponde 429", risposta=teste("429", size=None)),
        scena("la rete non risponde: passa, con avviso", atteso="verde",
              cerca="::warning::Nessuna risposta", risposta=""),
        scena("niente x-linked-etag: passa, con avviso", atteso="verde",
              cerca="non ha mandato x-linked-etag", risposta=teste(size=byte)),
    ]
    if con_rete:
        prove.append(scena("LA SORGENTE VERA, adesso (una HEAD, nessun byte)",
                           atteso="verde", cerca="scaricabile senza credenziali"))
    return all(prove)


if __name__ == "__main__":
    rete = "--rete" in sys.argv
    esiti = [la_forma(), i_cancelli(), la_controprova(), il_preflight(rete)]
    print("\n" + ("TUTTO A POSTO" if all(esiti) else "QUALCOSA NON VA"))
    if not rete:
        print("(la sorgente vera non e' stata interrogata: `--rete` per farlo)")
    sys.exit(0 if all(esiti) else 1)
