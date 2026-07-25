#!/usr/bin/env python
import os

env = Environment(tools=["default"])

opts = Variables([], ARGUMENTS)
opts.Add(EnumVariable("target", "Compilation target", "template_debug", ["template_debug", "template_release"]))
opts.Update(env)

# Compila godot-cpp e cattura l'ambiente gia' configurato che restituisce
# (Return("env")): contiene standard C++, define, flag di architettura e il
# link alla libreria statica di godot-cpp gia' pronti per la piattaforma scelta.
godot_env = env.SConscript("godot-cpp/SConstruct")

sources = Glob("src/*.cpp")

if env["PLATFORM"] == "win32":
    # --- Windows (PC di sviluppo): setup MSVC manuale, un'unica DLL ---
    env.Append(CPPPATH=[
        "src/",
        "godot-cpp/gdextension",
        "godot-cpp/include",
        "godot-cpp/gen/include"
    ])
    env.Append(CPPDEFINES=["TYPED_METHOD_BIND", "WIN32", "_WINDOWS"])
    env.Append(CXXFLAGS=["/std:c++17", "/EHsc", "/Zc:preprocessor", "/vmp", "/vmg"])
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
    # godot_env["suffix"] == ".<piattaforma>.<target>.<arch>" (es. ".macos.template_debug.universal")
    # SHLIBSUFFIX == ".dylib" su macOS / ".so" su Linux. Il prefisso "lib" e il
    # suffisso vanno messi espliciti, altrimenti SCons scambia ".universal" per
    # estensione e non aggiunge ".dylib".
    lib_name = "bin/libchibi_crossing{}{}".format(
        godot_env["suffix"], godot_env["SHLIBSUFFIX"]
    )
    library = godot_env.SharedLibrary(
        lib_name,
        source=sources
    )

Default(library)
