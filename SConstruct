#!/usr/bin/env python
import json
import os
import shutil
import subprocess

env = Environment(tools=["default"])

opts = Variables([], ARGUMENTS)
opts.Add(EnumVariable("target", "Compilation target", "template_debug", ["template_debug", "template_release"]))

# ---------------------------------------------------------------------------
# FASE 5 — il cuore che scrive (llama.cpp), SPENTO di default.
#
# Il gioco deve funzionare IDENTICO senza: chi non ha il modello ha un gioco
# meno sorprendente, non un gioco a cui manca un pezzo. Percio' `llm=no` non e'
# "compila e non usare": e' "non compila e non linka NIENTE". Con la leva
# spenta i sorgenti `src/llm_*.cpp` non entrano nemmeno nella lista, il define
# `CHIBI_LLM` non esiste, e il binario prodotto e' quello di sempre (verificato
# per impronta SHA-256, vedi CLAUDE.md).
# ---------------------------------------------------------------------------
opts.Add(BoolVariable("llm", "Compila e linka llama.cpp dentro il cuore (Fase 5)", False))
opts.Add(BoolVariable("llm_metal", "macOS: backend Metal per llama.cpp (GPU)", False))
opts.Add(
    BoolVariable(
        "llm_avx2",
        "x86: baseline Haswell (AVX2/FMA/F16C) come le release ufficiali di llama.cpp",
        True,
    )
)
opts.Add("llm_cmake", "Percorso dell'eseguibile cmake (vuoto = si cerca nel PATH)", "")
opts.Add(
    "llm_msvc_crt",
    "MSVC: runtime C con cui compilare llama.cpp (deve COMBACIARE col nostro, vedi sotto)",
    "MultiThreaded",
)
opts.Add(BoolVariable("llm_ricostruisci", "Rifa' la build di llama.cpp anche se e' gia' a posto", False))
opts.Update(env)

# La cartella del sottomodulo e quella di lavoro stanno tutte e due sotto
# `src/thirdparty/`, che ha gia' il suo `.gdignore`: l'importer di Godot
# scandaglia `src/` sul serio, e li' dentro ci sono migliaia di file (e dei
# .gguf di prova a monte) che non devono finire nel progetto.
LLM_RADICE = "src/thirdparty/llama.cpp"
LLM_LAVORO = "src/thirdparty/llm-build"


def _llm_ambiente_figlio(scons_env):
    """L'ambiente con cui far girare cmake.

    Su Windows e' la riga che conta: SCons tiene la configurazione di MSVC
    (PATH, INCLUDE, LIB, LIBPATH di vcvars) dentro `env["ENV"]`, NON nella
    shell che ci ha lanciati. Un cmake avviato con l'ambiente della shell non
    troverebbe `cl.exe` — e se lo trovasse potrebbe essere un MSVC diverso da
    quello con cui SCons compila il resto del cuore. Si parte da os.environ
    (li' c'e' cmake, installato dall'utente o dal runner) e ci si sovrappone
    quello di SCons, con i PATH concatenati in quest'ordine.
    """
    figlio = dict(os.environ)
    per_scons = scons_env.get("ENV", {})
    for chiave, valore in per_scons.items():
        if not isinstance(valore, str):
            continue
        if chiave.upper() == "PATH":
            gia = figlio.get(chiave, "")
            figlio[chiave] = valore + (os.pathsep + gia if gia else "")
        else:
            figlio[chiave] = valore
    return figlio


def _llm_cmake(scons_env, ambiente):
    if scons_env["llm_cmake"]:
        return scons_env["llm_cmake"]
    trovato = shutil.which("cmake", path=ambiente.get("PATH"))
    if trovato:
        return trovato
    print("ERRORE: llm=yes ma cmake non e' nel PATH.")
    print("        llama.cpp si compila con la SUA CMake (e' l'unico build supportato")
    print("        a monte: ggml sceglie i sorgenti per architettura, genera header e")
    print("        compone i backend). Installa cmake, oppure indicalo a mano:")
    print("        scons llm=yes llm_cmake=/percorso/di/cmake")
    Exit(1)


def _llm_versione():
    """Il SHA del sottomodulo: e' l'impronta della dipendenza."""
    try:
        fuori = subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=Dir(LLM_RADICE).abspath, stderr=subprocess.DEVNULL
        )
        return fuori.decode("utf-8").strip()
    except Exception:
        return ""


def _llm_opzioni(scons_env, piattaforma, arch):
    """Le opzioni CMake, tutte esplicite. Ogni riga qui e' una decisione."""
    o = [
        # llama.cpp si compila SEMPRE in Release, anche quando il cuore e' in
        # template_debug: un ggml in Debug e' un ordine di grandezza piu' lento
        # (una lettera ci metterebbe minuti) e su MSVC tirerebbe dentro il CRT
        # di debug, che non combacia col nostro.
        "-DCMAKE_BUILD_TYPE=Release",
        # Librerie STATICHE: il gioco si firma e si notarizza, e ogni .dylib in
        # piu' e' un pezzo da firmare a parte e da ritrovare a runtime.
        "-DBUILD_SHARED_LIBS=OFF",
        # -fPIC: le .a finiscono dentro una libreria CONDIVISA. Senza, il link
        # su Linux muore con "relocation R_X86_64_32 against ... can not be
        # used when making a shared object".
        "-DCMAKE_POSITION_INDEPENDENT_CODE=ON",
        # I simboli di llama/ggml restano dentro casa: la tabella di export
        # della GDExtension deve contenere solo il punto d'ingresso di Godot.
        "-DCMAKE_C_VISIBILITY_PRESET=hidden",
        "-DCMAKE_CXX_VISIBILITY_PRESET=hidden",
        "-DCMAKE_VISIBILITY_INLINES_HIDDEN=ON",
        # NATIVE=OFF non vuol dire "senza SIMD": in ggml spegne `-march=native`
        # (che produrrebbe un binario buono solo per il PC che l'ha compilato)
        # e ACCENDE la baseline fissa. E' quello che fanno le release ufficiali.
        "-DGGML_NATIVE=OFF",
        "-DGGML_CCACHE=OFF",
        # OpenMP porterebbe una dipendenza a runtime (libgomp / libomp) da
        # ridistribuire e da firmare; ggml ha il suo pool di thread.
        "-DGGML_OPENMP=OFF",
        # I backend restano DENTRO l'archivio: niente caricamento dinamico,
        # niente file accanto all'eseguibile.
        "-DGGML_BACKEND_DL=OFF",
        "-DGGML_CPU_ALL_VARIANTS=OFF",
        # Di llama.cpp ci serve la libreria e basta: niente `common` (che usa
        # le eccezioni a mano libera e tira dentro httplib/openssl), niente
        # tool, niente server, niente interfaccia web, niente test.
        "-DLLAMA_BUILD_COMMON=OFF",
        "-DLLAMA_BUILD_TESTS=OFF",
        "-DLLAMA_BUILD_TOOLS=OFF",
        "-DLLAMA_BUILD_EXAMPLES=OFF",
        "-DLLAMA_BUILD_SERVER=OFF",
        "-DLLAMA_BUILD_APP=OFF",
        "-DLLAMA_BUILD_UI=OFF",
        "-DLLAMA_OPENSSL=OFF",
    ]

    if piattaforma == "macos":
        # Una passata per architettura: `arm64;x86_64` insieme non funziona,
        # perche' ggml sceglie i sorgenti e i flag guardando proprio
        # CMAKE_OSX_ARCHITECTURES (ggml/cmake/common.cmake) e con due valori
        # non riconosce ne' l'una ne' l'altra. Le due meta' si uniscono dopo
        # con `lipo`, che e' il mestiere di lipo.
        o.append("-DCMAKE_OSX_ARCHITECTURES=" + arch)
        o.append("-DGGML_METAL=" + ("ON" if scons_env["llm_metal"] else "OFF"))
        if scons_env["llm_metal"]:
            # Gli shader Metal vanno DENTRO il binario: la variante con il
            # file `default.metallib` accanto all'eseguibile non sopravvive a
            # un .app firmato e spostato.
            o.append("-DGGML_METAL_EMBED_LIBRARY=ON")
    elif piattaforma == "windows":
        # IL RISCHIO NUMERO UNO DI QUESTA FASE, e non e' verificabile da un Mac.
        # Il nostro ramo win32 non passa ne' /MD ne' /MT: cl.exe senza opzioni
        # usa il CRT statico (/MT), ed e' anche quello che godot-cpp sceglie
        # (use_static_cpp=True -> /MT). CMake invece parte da MultiThreadedDLL
        # (/MD): senza questa riga il link finisce in LNK2038 "mismatch
        # detected for 'RuntimeLibrary'". Se un giorno il nostro ramo passasse
        # a /MD, qui si scrive llm_msvc_crt=MultiThreadedDLL e basta.
        o.append("-DCMAKE_MSVC_RUNTIME_LIBRARY=" + scons_env["llm_msvc_crt"])

    if not scons_env["llm_avx2"] and piattaforma in ("windows", "linux"):
        # La baseline di llama.cpp e' Haswell (2013). Spegnendola si guadagna
        # qualche CPU vecchia e si perde parecchia velocita': e' una scelta da
        # fare con un numero in mano (token/s), non a naso.
        for spento in ("AVX2", "FMA", "F16C", "BMI2", "AVX", "SSE42"):
            o.append("-DGGML_{}=OFF".format(spento))

    return o


def _llm_ordina_librerie(percorsi, piattaforma):
    """L'ordine di link, che su GNU ld non e' un dettaglio.

    llama chiama ggml, ggml (il registro dei backend) chiama ggml-cpu, e tutti
    chiamano ggml-base. GNU ld fa UNA passata sola: un archivio nominato prima
    di chi lo usa viene scartato e i simboli restano irrisolti. Su Linux la
    lista si ripete percio' due volte, che e' il rimedio classico e chiude
    anche gli anelli fra backend che dovessero nascere domani.
    Solo su Linux: ld64 di Apple e link.exe risolvono comunque, e ad Apple i
    doppioni non piacciono («ignoring duplicate libraries») — un avviso a ogni
    link e' il modo migliore per insegnare a non leggere gli avvisi.
    """

    def rango(p):
        nome = os.path.basename(p).lower()
        if "llama" in nome:
            return 0
        if "ggml-base" in nome:
            return 3
        if nome.startswith("libggml.") or nome.startswith("ggml."):
            return 1
        return 2  # i backend: ggml-cpu, ggml-blas, ggml-metal, ...

    ordinati = sorted(percorsi, key=lambda p: (rango(p), os.path.basename(p)))
    return ordinati + ordinati if piattaforma == "linux" else ordinati


def _llm_costruisci(scons_env, piattaforma, arch):
    """Configura + compila + installa llama.cpp. Torna il prefisso d'installazione.

    L'installazione non e' un vezzo: `cmake --install` mette librerie e header
    in un posto che NON dipende dal generatore (Ninja, Makefile o Visual
    Studio mettono i .a/.lib in tre posti diversi). Cosi' il resto di questo
    file guarda sempre `<lavoro>/inst/lib` e `<lavoro>/inst/include`.
    """
    if not os.path.exists(os.path.join(Dir(LLM_RADICE).abspath, "CMakeLists.txt")):
        print("ERRORE: llm=yes ma il sottomodulo llama.cpp non c'e'.")
        print("        git submodule update --init --depth 1 " + LLM_RADICE)
        Exit(1)

    ambiente = _llm_ambiente_figlio(scons_env)
    cmake = _llm_cmake(scons_env, ambiente)
    opzioni = _llm_opzioni(scons_env, piattaforma, arch)

    lavoro = Dir("{}/{}-{}".format(LLM_LAVORO, piattaforma, arch)).abspath
    costruzione = os.path.join(lavoro, "build")
    prefisso = os.path.join(lavoro, "inst")
    timbro = os.path.join(lavoro, "timbro.json")

    impronta = {
        "sha": _llm_versione(),
        "opzioni": opzioni,
        "cmake": cmake,
    }
    vecchio = None
    if os.path.exists(timbro):
        try:
            with open(timbro, "r") as f:
                vecchio = json.load(f)
        except Exception:
            vecchio = None

    ha_librerie = os.path.isdir(os.path.join(prefisso, "lib")) and bool(
        [n for n in os.listdir(os.path.join(prefisso, "lib")) if n.endswith((".a", ".lib"))]
    )
    if vecchio == impronta and ha_librerie and not scons_env["llm_ricostruisci"]:
        return prefisso

    lavori = scons_env.GetOption("num_jobs") or 1
    print("== llama.cpp ({} {}): compilo, e' lunga la prima volta ==".format(piattaforma, arch))

    def esegui(comando):
        esito = subprocess.call(comando, env=ambiente)
        if esito != 0:
            print("ERRORE: llama.cpp non ha compilato ({}).".format(" ".join(comando[:2])))
            Exit(1)

    generatore = []
    if shutil.which("ninja", path=ambiente.get("PATH")):
        generatore = ["-G", "Ninja"]
    esegui([cmake, "-S", Dir(LLM_RADICE).abspath, "-B", costruzione] + generatore + opzioni)
    esegui([cmake, "--build", costruzione, "--config", "Release", "-j", str(lavori)])
    if os.path.isdir(prefisso):
        shutil.rmtree(prefisso)
    esegui([cmake, "--install", costruzione, "--prefix", prefisso, "--config", "Release"])

    with open(timbro, "w") as f:
        json.dump(impronta, f, indent=1)
    return prefisso


def _llm_lipo(scons_env, prefissi):
    """Le due meta' di macOS diventano una libreria universale sola.

    Il timbro non e' un'ottimizzazione: rifare `lipo` a ogni invocazione
    cambierebbe la data degli archivi, SCons li vedrebbe nuovi e RILINKEREBBE
    il cuore tutte le volte — anche quando non c'e' niente da fare.
    """
    # Stessa forma delle passate singole (`<lavoro>/<nome>/inst`): cosi' la CI
    # puo' tenere da parte le sole librerie installate con un unico modello di
    # percorso, senza portarsi dietro le centinaia di megabyte di oggetti.
    unito = Dir("{}/macos-universal/inst".format(LLM_LAVORO)).abspath
    lib = os.path.join(unito, "lib")
    timbro = Dir("{}/macos-universal".format(LLM_LAVORO)).abspath + os.sep + "timbro.json"
    impronta = {}
    for p in prefissi:
        cartella = os.path.join(p, "lib")
        for n in sorted(os.listdir(cartella)):
            if n.endswith(".a"):
                s = os.stat(os.path.join(cartella, n))
                impronta[os.path.join(os.path.basename(p), n)] = [s.st_size, int(s.st_mtime)]
    if os.path.exists(timbro):
        try:
            with open(timbro, "r") as f:
                if json.load(f) == impronta and os.path.isdir(lib):
                    return unito
        except Exception:
            pass
    if os.path.isdir(unito):
        shutil.rmtree(unito)
    os.makedirs(lib)
    shutil.copytree(os.path.join(prefissi[0], "include"), os.path.join(unito, "include"))
    nomi = sorted(n for n in os.listdir(os.path.join(prefissi[0], "lib")) if n.endswith(".a"))
    for nome in nomi:
        pezzi = [os.path.join(p, "lib", nome) for p in prefissi]
        mancanti = [p for p in pezzi if not os.path.exists(p)]
        if mancanti:
            print("ERRORE: manca {} per l'universale.".format(mancanti[0]))
            Exit(1)
        esito = subprocess.call(["lipo", "-create"] + pezzi + ["-output", os.path.join(lib, nome)])
        if esito != 0:
            print("ERRORE: lipo non ha unito " + nome)
            Exit(1)
    with open(timbro, "w") as f:
        json.dump(impronta, f, indent=1)
    return unito


def _llm_cabla(scons_env, ambiente_link, piattaforma):
    """Accende llama.cpp dentro l'ambiente che compila e linka il cuore."""
    if piattaforma == "macos":
        arch = ambiente_link.get("arch", "universal")
        if arch == "universal":
            prefissi = [_llm_costruisci(scons_env, "macos", a) for a in ("arm64", "x86_64")]
            prefisso = _llm_lipo(scons_env, prefissi)
        else:
            prefisso = _llm_costruisci(scons_env, "macos", arch)
    else:
        arch = ambiente_link.get("arch", "x86_64")
        prefisso = _llm_costruisci(scons_env, piattaforma, arch)

    lib = os.path.join(prefisso, "lib")
    archivi = [
        os.path.join(lib, n) for n in sorted(os.listdir(lib)) if n.endswith(".a") or n.endswith(".lib")
    ]
    if not archivi:
        print("ERRORE: llama.cpp ha compilato ma non ha lasciato nessuna libreria in " + lib)
        Exit(1)

    ambiente_link.Append(CPPPATH=[os.path.join(prefisso, "include")])
    ambiente_link.Append(CPPDEFINES=["CHIBI_LLM"])
    ambiente_link.Append(LIBS=[File(p) for p in _llm_ordina_librerie(archivi, piattaforma)])

    if piattaforma == "macos":
        ambiente_link.Append(LINKFLAGS=["-framework", "Accelerate"])
        if scons_env["llm_metal"]:
            ambiente_link.Append(
                LINKFLAGS=["-framework", "Foundation", "-framework", "Metal", "-framework", "MetalKit"]
            )
    elif piattaforma == "linux":
        ambiente_link.Append(LIBS=["pthread", "dl", "m"])

    print("== llm=yes: llama.cpp {} ==".format((_llm_versione() or "?")[:12]))


def _llm_oggetti_ponte(ambiente_link, sorgenti, e_msvc):
    """Compila i file del confine — e SOLO quelli — con le eccezioni accese.

    godot-cpp compila tutto il cuore con `-fno-exceptions`, e ha ragione: Godot
    non le usa. Ma llama.cpp sì, e `llama_decode` non se le riprende da sola:
    un throw che arriva su un frame compilato senza eccezioni non è un errore
    da gestire, è `std::terminate`. Il confine è l'unico posto che può
    prenderla e tradurla in un valore di ritorno, quindi è l'unico che si
    compila diversamente. La guardia sta in `src/llm_llama.h`: se questa
    funzione smettesse di fare il suo mestiere, la build FALLISCE (`#error`),
    non diventa silenziosamente pericolosa.
    """
    ponte = ambiente_link.Clone()
    for lista in ("CXXFLAGS", "CCFLAGS"):
        if lista in ponte:
            ponte[lista] = [f for f in ponte[lista] if f != "-fno-exceptions"]
    if not e_msvc:
        ponte.Append(CXXFLAGS=["-fexceptions"])
    # Su MSVC il nostro ramo passa già /EHsc e non definisce _HAS_EXCEPTIONS=0:
    # le eccezioni sono accese, e `_CPPUNWIND` lo conferma al preprocessore.
    return [ponte.SharedObject(n) for n in sorgenti]


# Le variabili della Fase 5 non esistono per godot-cpp: se restano in ARGUMENTS
# il suo SConstruct le elenca come "Unknown SCons variables were passed and
# will be ignored" — un avviso giallo a ogni compilazione, che insegna a non
# leggere gli avvisi. I nostri valori sono gia' al sicuro (`opts.Update(env)`
# qui sopra): si tolgono per la durata della chiamata e si rimettono subito,
# perche' ARGUMENTS e' globale e non e' roba nostra da svuotare.
_llm_argomenti = {k: ARGUMENTS[k] for k in list(ARGUMENTS.keys()) if k.startswith("llm")}
for _k in _llm_argomenti:
    del ARGUMENTS[_k]

# Compila godot-cpp e cattura l'ambiente gia' configurato che restituisce
# (Return("env")): contiene standard C++, define, flag di architettura e il
# link alla libreria statica di godot-cpp gia' pronti per la piattaforma scelta.
godot_env = env.SConscript("godot-cpp/SConstruct")

ARGUMENTS.update(_llm_argomenti)

# Con la leva spenta i sorgenti del ponte non entrano nella lista: non e' un
# `#ifdef` attorno a un file compilato a vuoto, e' un file che NON si compila
# affatto. E' la differenza fra "il binario e' identico" e "il binario e'
# quasi identico".
_tutti_i_sorgenti = Glob("src/*.cpp")
_llm_sorgenti_ponte = [n for n in _tutti_i_sorgenti if os.path.basename(str(n)).startswith("llm_")]
sources = [n for n in _tutti_i_sorgenti if n not in _llm_sorgenti_ponte]

if env["PLATFORM"] == "win32":
    # --- Windows (PC di sviluppo): setup MSVC manuale, un'unica DLL ---
    env.Append(CPPPATH=[
        "src/",
        "godot-cpp/gdextension",
        "godot-cpp/include",
        "godot-cpp/gen/include"
    ])
    env.Append(CPPDEFINES=["TYPED_METHOD_BIND", "WIN32", "_WINDOWS"])
    # /Zc:__cplusplus e' OBBLIGATORIO con godot-cpp 4.7: senza, MSVC lascia
    # __cplusplus a 199711L anche con /std:c++17, e defs.hpp fallisce lo
    # static_assert "Minimum of C++17 required".
    env.Append(CXXFLAGS=["/std:c++17", "/Zc:__cplusplus", "/EHsc", "/Zc:preprocessor", "/vmp", "/vmg"])
    env.Append(LIBPATH=["godot-cpp/bin"])
    if env["target"] == "template_debug":
        # Debug: nessuna ottimizzazione (/Od) + info di debug. Si usa /Z7 (non
        # /Zi): /Z7 mette le info di debug DENTRO ogni .obj, mentre /Zi le scrive
        # in un PDB condiviso (vc140.pdb) su cui i cl.exe in parallelo (-j) si
        # scontrano -> errore C1041. Con /Z7 la build parallela e' sicura; il
        # linker con /DEBUG produce comunque il .pdb finale della DLL.
        env.Append(CXXFLAGS=["/Od", "/Z7"])
        env.Append(LINKFLAGS=["/DEBUG"])
        env.Append(LIBS=["libgodot-cpp.windows.template_debug.x86_64.lib"])
    else:
        # Release: ottimizzazione per velocita' (/O2), intrinseche (/Oi),
        # linking a livello di funzione (/Gy) e NDEBUG per disattivare gli
        # assert. Il linker rimuove funzioni/dati morti (/OPT:REF) e fonde le
        # sezioni identiche (/OPT:ICF): DLL piu' piccola e veloce.
        env.Append(CXXFLAGS=["/O2", "/Oi", "/Gy"])
        env.Append(CPPDEFINES=["NDEBUG"])
        env.Append(LINKFLAGS=["/OPT:REF", "/OPT:ICF"])
        env.Append(LIBS=["libgodot-cpp.windows.template_release.x86_64.lib"])

    if env["llm"]:
        _llm_cabla(env, env, "windows")
        sources = sources + _llm_oggetti_ponte(env, _llm_sorgenti_ponte, True)

    library = env.SharedLibrary(
        "bin/chibi_crossing",
        source=sources
    )
else:
    # --- macOS / Linux: si usa l'ambiente di godot-cpp cosi' i nostri sorgenti
    # ereditano -std=c++17, i define, i flag di architettura (es. universale)
    # e il link automatico alla libreria statica di godot-cpp. Il nome del file
    # segue la convenzione Godot (lib<nome>.<piattaforma>.<target>.<arch>.dylib),
    # la stessa usata dagli addon del progetto.
    godot_env.Append(CPPPATH=["src/"])

    # `godot_env` E' l'ambiente con cui godot-cpp compila SE STESSO, e SCons
    # esegue le azioni DOPO aver letto tutto questo file: quello che si scrive
    # qui dentro finisce anche sui duemila oggetti di godot-cpp. Con `llm=yes`
    # (che aggiunge -DCHIBI_LLM e un -I) godot-cpp si ricompilava INTERO, e si
    # ricompilava di nuovo al ritorno a `llm=no`: dieci minuti a ogni cambio di
    # leva, per un define che godot-cpp non guarda nemmeno. Percio' la roba di
    # llama va su un CLONE, e le due configurazioni si spartiscono gli stessi
    # oggetti di godot-cpp. Con la leva spenta il clone non nasce: si compila e
    # si linka esattamente come prima, con lo stesso oggetto Environment.
    nostro_env = godot_env
    if env["llm"]:
        nostro_env = godot_env.Clone()
        # La piattaforma la dice godot-cpp, non `sys.platform`: chi compila
        # macOS da Linux (osxcross) deve ricevere le stesse opzioni di chi la
        # compila da un Mac.
        _llm_cabla(env, nostro_env, godot_env.get("platform", "linux"))
        sources = sources + _llm_oggetti_ponte(nostro_env, _llm_sorgenti_ponte, False)

    # godot_env["suffix"] == ".<piattaforma>.<target>.<arch>" (es. ".macos.template_debug.universal")
    # SHLIBSUFFIX == ".dylib" su macOS / ".so" su Linux. Il prefisso "lib" e il
    # suffisso vanno messi espliciti, altrimenti SCons scambia ".universal" per
    # estensione e non aggiunge ".dylib".
    lib_name = "bin/libchibi_crossing{}{}".format(
        godot_env["suffix"], godot_env["SHLIBSUFFIX"]
    )
    library = nostro_env.SharedLibrary(
        lib_name,
        source=sources
    )

Default(library)
