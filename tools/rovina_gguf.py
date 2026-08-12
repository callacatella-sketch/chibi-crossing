#!/usr/bin/env python3
"""ROVINA UN MODELLO IN NOVE MODI, E GUARDA CHI MUORE.

Il portiere (`src/llm_gguf.cpp`) esiste per una ragione sola: `GGML_ABORT`
chiama `abort()`, non e' `assert()`, `NDEBUG` non lo spegne e nessun `try` lo
prende. Un `.gguf` guasto puo' portarsi via il processo del GIOCATORE.

Questo script e' la MISURA di quella frase, ed e' il motivo per cui il
portiere controlla certe cose e non altre. Fa cosi':

 1. prende un modello vero e ne fabbrica delle copie guaste, una per ogni
    modo in cui un file puo' rompersi (download interrotto, bit girato,
    campo di tipo sbagliato, dimensione a zero...);
 2. per ognuna chiede due volte, in DUE PROCESSI DIVERSI:
      - cosa dice il portiere;
      - cosa fa llama.cpp da sola, senza portiere davanti;
 3. stampa la tabella. Un `MORTO(6)` nella colonna di llama e' un abort; un
    `MORTO(10)` e' un SIGBUS, cioe' una lettura oltre la fine di una
    mappatura — il guasto piu' silenzioso di tutti.

Le copie si fanno con `cp -c` (clone APFS): sono istantanee e non occupano
disco finche' non si toccano i byte.

    python3 tools/rovina_gguf.py <modello.gguf> [cartella_di_lavoro]

⚠️ Il parser qui dentro e' scritto DA CAPO, e non e' pigrizia al contrario:
se leggesse il file con lo stesso codice del portiere, la prova chiederebbe
al giudice se e' d'accordo con se' stesso. E' la stessa regola dell'oracolo
indipendente di `test_rotta_corpo.gd`.
"""

import os
import shutil
import struct
import subprocess
import sys

GGUF_STRINGA = 8
GGUF_ARRAY = 9

TAGLIE = {0: 1, 1: 1, 2: 2, 3: 2, 4: 4, 5: 4, 6: 4, 7: 1, 10: 8, 11: 8, 12: 8}


class Lettore:
    def __init__(self, dati):
        self.d = dati
        self.p = 0

    def prendi(self, n):
        v = self.d[self.p:self.p + n]
        self.p += n
        return v

    def u32(self):
        return struct.unpack_from("<I", self.prendi(4))[0]

    def u64(self):
        return struct.unpack_from("<Q", self.prendi(8))[0]

    def i64(self):
        return struct.unpack_from("<q", self.prendi(8))[0]

    def stringa(self):
        n = self.u64()
        return self.prendi(n).decode("utf-8", "replace")


def leggi_intestazione(percorso):
    """Torna un dizionario di OFFSET dentro il file: dove sta ogni campo che
    ci serve rompere. Legge solo i primi megabyte piu' quello che serve."""
    with open(percorso, "rb") as f:
        dati = f.read(64 * 1024 * 1024)
    r = Lettore(dati)
    assert r.prendi(4) == b"GGUF", "non e' un GGUF"
    versione = r.u32()
    n_tensori = r.u64()
    n_chiavi = r.u64()

    info = {
        "versione": versione,
        "n_tensori": n_tensori,
        "n_chiavi": n_chiavi,
        "allineamento": 32,
        "off_tipo_tokens": None,
        "off_tipo_toktype": None,
        "off_tipo_scores": None,
        "off_allineamento": None,
        "off_nome_file_type": None,
        "off_tipo_file_type": None,
    }

    for _ in range(n_chiavi):
        chiave = r.stringa()
        tipo = r.u32()
        e_array = tipo == GGUF_ARRAY
        quanti = 1
        off_tipo_elemento = None
        if e_array:
            off_tipo_elemento = r.p
            tipo = r.u32()
            quanti = r.u64()
        if chiave == "tokenizer.ggml.tokens":
            info["off_tipo_tokens"] = off_tipo_elemento
        if chiave == "tokenizer.ggml.token_type":
            info["off_tipo_toktype"] = off_tipo_elemento
        if chiave == "tokenizer.ggml.scores":
            info["off_tipo_scores"] = off_tipo_elemento
        # `general.file_type` e' lungo ESATTAMENTE quanto `general.alignment`
        # (diciassette lettere) ed e' un u32 come lui: si puo' rinominare sul
        # posto, senza spostare un solo byte del resto del file. Serve per
        # fabbricare il guasto piu' cattivo di tutti — l'allineamento col tipo
        # sbagliato — su un modello che quella chiave non ce l'ha.
        if chiave == "general.file_type" and not e_array:
            info["off_nome_file_type"] = r.p - 4 - len(chiave)
            info["off_tipo_file_type"] = r.p - 4
        if tipo == GGUF_STRINGA:
            for _ in range(quanti):
                n = r.u64()
                r.p += n
        else:
            if chiave == "general.alignment" and not e_array:
                info["off_allineamento"] = r.p
                info["allineamento"] = struct.unpack_from("<I", r.d, r.p)[0]
            r.p += TAGLIE[tipo] * quanti

    tensori = []
    for _ in range(n_tensori):
        nome = r.stringa()
        off_ndim = r.p
        n_dim = r.u32()
        off_ne = r.p
        ne = [r.i64() for _ in range(n_dim)]
        off_tipo = r.p
        tipo = r.u32()
        off_offset = r.p
        offset = r.u64()
        tensori.append({
            "nome": nome, "ne": ne, "tipo": tipo, "offset": offset,
            "off_ndim": off_ndim, "off_ne": off_ne,
            "off_tipo": off_tipo, "off_offset": off_offset,
        })
    info["tensori"] = tensori
    a = info["allineamento"]
    info["inizio_dati"] = (r.p + a - 1) & ~(a - 1)
    return info


def clona(sorgente, destinazione):
    if os.path.exists(destinazione):
        os.remove(destinazione)
    # `cp -c` su APFS e' un clone: istantaneo, e non occupa disco finche'
    # non si scrive. Se il filesystem non lo sa fare, si copia e basta.
    if subprocess.call(["cp", "-c", sorgente, destinazione],
                       stderr=subprocess.DEVNULL) != 0:
        shutil.copyfile(sorgente, destinazione)


def scrivi(percorso, offset, byte):
    with open(percorso, "r+b") as f:
        f.seek(offset)
        f.write(byte)


def tronca(percorso, quanti_byte_via):
    dim = os.path.getsize(percorso)
    with open(percorso, "r+b") as f:
        f.truncate(max(0, dim - quanti_byte_via))


def fabbrica(sorgente, lavoro, info):
    """Torna [(nome, percorso, cosa ci si aspetta)]."""
    fatti = []
    t0 = info["tensori"][0]
    ultimo = info["tensori"][-1]

    def variante(nome, cambia):
        p = os.path.join(lavoro, "guasto_%s.gguf" % nome)
        clona(sorgente, p)
        cambia(p)
        fatti.append((nome, p))

    variante("sano", lambda p: None)
    variante("magia", lambda p: scrivi(p, 0, b"GGUX"))
    variante("troncato_testa", lambda p: tronca(p, os.path.getsize(p) - 100))
    variante("troncato_pesi", lambda p: tronca(p, 8 * 1024 * 1024))
    variante("troncato_un_byte", lambda p: tronca(p, 1))
    if info["off_tipo_tokens"] is not None:
        # L'elenco del vocabolario dichiarato come interi invece che come
        # stringhe: e' il caso che in llama fa GGML_ASSERT, non eccezione.
        variante("tokens_interi",
                 lambda p: scrivi(p, info["off_tipo_tokens"], struct.pack("<I", 5)))
    # I DUE CATTIVI VERI, e sono cattivi perche' NON cambiano la lunghezza di
    # niente: int32 e float32 occupano quattro byte tutti e due. Il file resta
    # perfetto nella forma, e llama.cpp legge quegli elenchi con un cast
    # crudo (`(const float *) gguf_get_arr_data`, llama-vocab.cpp:2419): non
    # controlla il tipo, quindi non se ne accorge e si ritrova un tokenizzatore
    # con dentro spazzatura. Un bit girato nel byte del tipo basta.
    if info["off_tipo_toktype"] is not None:
        variante("token_type_reali",
                 lambda p: scrivi(p, info["off_tipo_toktype"], struct.pack("<I", 6)))
    if info["off_tipo_scores"] is not None:
        variante("scores_interi",
                 lambda p: scrivi(p, info["off_tipo_scores"], struct.pack("<I", 5)))
    # IL PIU' CATTIVO DI TUTTI, ed e' l'unico che abortisce davvero.
    # `general.alignment` non lo legge llama: lo legge GGML, dentro
    # `gguf_init_from_file`, con `gguf_get_val_u32` — che fa
    # `GGML_ASSERT(tipo == u32)`. Tutti gli altri metadati passano dal ramo di
    # llama, che TIRA un'eccezione (e il gioco la vede come «modello non
    # caricato»). Questo no: questo e' `abort()`, e basta un byte.
    if info["off_nome_file_type"] is not None:
        def rinomina(p, tipo=None):
            scrivi(p, info["off_nome_file_type"], b"general.alignment")
            if tipo is not None:
                scrivi(p, info["off_tipo_file_type"], struct.pack("<I", tipo))
        # col tipo giusto ma un valore che non e' potenza di due (il numero
        # della quantizzazione): ggml lo rifiuta pulito. E' il contrasto.
        variante("allineamento_dal_ftype", lambda p: rinomina(p))
        # col tipo sbagliato: qui ggml non rifiuta, muore.
        variante("allineamento_reale", lambda p: rinomina(p, 6))
    variante("n_chiavi_enorme", lambda p: scrivi(p, 16, struct.pack("<Q", 1 << 40)))
    variante("n_tensori_enorme", lambda p: scrivi(p, 8, struct.pack("<Q", 1 << 40)))
    variante("tensore_ne_zero",
             lambda p: scrivi(p, t0["off_ne"], struct.pack("<q", 0)))
    variante("tensore_tipo_matto",
             lambda p: scrivi(p, t0["off_tipo"], struct.pack("<I", 900)))
    variante("tensore_offset_storto",
             lambda p: scrivi(p, ultimo["off_offset"],
                              struct.pack("<Q", ultimo["offset"] + 32)))
    if info["off_allineamento"] is not None:
        variante("allineamento_dispari",
                 lambda p: scrivi(p, info["off_allineamento"], struct.pack("<I", 3)))
    # UN BIT NEI PESI. Nessuno dei due lo vede, ed e' il residuo dichiarato:
    # contro questo c'e' solo l'impronta SHA-256.
    meta = info["inizio_dati"] + (os.path.getsize(sorgente) - info["inizio_dati"]) // 2
    variante("bit_nei_pesi", lambda p: scrivi(p, meta, b"\xa5"))
    return fatti


def chiedi(binario, cosa, file):
    try:
        r = subprocess.run([binario, cosa, file], capture_output=True, text=True,
                           timeout=600)
    except subprocess.TimeoutExpired:
        return "APPESO", ""
    if r.returncode < 0:
        return "MORTO(%d)" % (-r.returncode), (r.stderr or "").strip().splitlines()[-1:] and \
            (r.stderr or "").strip().splitlines()[-1] or ""
    riga = (r.stdout or "").strip()
    pezzi = riga.split("\t", 1)
    return (pezzi[0] if pezzi else "?"), (pezzi[1] if len(pezzi) > 1 else "")


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    sorgente = sys.argv[1]
    lavoro = sys.argv[2] if len(sys.argv) > 2 else "/tmp/chibi_gguf_guasti"
    binario = os.environ.get("PORTIERE", "/tmp/portiere_vs_llama")
    os.makedirs(lavoro, exist_ok=True)

    info = leggi_intestazione(sorgente)
    print("modello: %s" % sorgente)
    print("  %d tensori, %d metadati, allineamento %d, dati dal byte %d"
          % (info["n_tensori"], info["n_chiavi"], info["allineamento"],
             info["inizio_dati"]))
    fatti = fabbrica(sorgente, lavoro, info)

    print()
    print("%-24s %-12s %-14s %s" % ("guasto", "PORTIERE", "LLAMA DA SOLA", "cosa dice il portiere"))
    print("-" * 110)
    for nome, percorso in fatti:
        vp, mp = chiedi(binario, "portiere", percorso)
        vl, _ = chiedi(binario, "llama", percorso)
        print("%-24s %-12s %-14s %s" % (nome, vp, vl, mp[:60]))
    print()
    print("MORTO(6) = abort() · MORTO(10) = SIGBUS (lettura oltre la mappatura)")
    print("MORTO(11) = SIGSEGV · APPESO = non e' tornato entro 10 minuti")
    return 0


if __name__ == "__main__":
    sys.exit(main())
