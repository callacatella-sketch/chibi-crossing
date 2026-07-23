#!/usr/bin/env python
import os

# godot-cpp compila se stesso e restituisce un ambiente gia configurato
# per la piattaforma corrente (Windows, macOS, Linux): compilatore, flag
# giusti e libreria statica di godot-cpp sono gia agganciati. Cosi lo
# stesso SConstruct costruisce il cuore C++ su ogni sistema, senza piu
# blocchi specifici per Windows.
env = SConscript("godot-cpp/SConstruct")

env.Append(CPPPATH=["src/"])
sources = Glob("src/*.cpp")

if env["platform"] == "macos":
    # dylib universale (arm64 + x86_64): gira su Apple Silicon e Intel.
    # Il nome porta la piattaforma e il target, cosi debug e release
    # convivono nella stessa cartella bin/ e il .gdextension li distingue.
    library = env.SharedLibrary(
        "bin/chibi_crossing.macos.{}.dylib".format(env["target"]),
        source=sources,
    )
elif env["platform"] == "linux":
    library = env.SharedLibrary(
        "bin/chibi_crossing.linux.{}.x86_64.so".format(env["target"]),
        source=sources,
    )
else:
    # Windows: resta bin/chibi_crossing.dll, come i binari gia versionati
    library = env.SharedLibrary(
        "bin/chibi_crossing",
        source=sources,
    )

Default(library)
