#!/usr/bin/env python
import os

env = Environment(tools=["default"])

opts = Variables([], ARGUMENTS)
opts.Add(EnumVariable("target", "Compilation target", "template_debug", ["template_debug", "template_release"]))
opts.Update(env)

# Ensure godot-cpp builds
env.SConscript("godot-cpp/SConstruct")

env.Append(CPPPATH=[
    "src/",
    "godot-cpp/gdextension",
    "godot-cpp/include",
    "godot-cpp/gen/include"
])

# For MSVC we need these flags
if env["PLATFORM"] == "win32":
    env.Append(CPPDEFINES=["TYPED_METHOD_BIND", "WIN32", "_WINDOWS"])
    env.Append(CXXFLAGS=["/std:c++17", "/EHsc", "/Zc:preprocessor", "/vmp", "/vmg"])
    env.Append(LIBPATH=["godot-cpp/bin"])
    if env["target"] == "template_debug":
        env.Append(LIBS=["libgodot-cpp.windows.template_debug.x86_64.lib"])
    else:
        env.Append(LIBS=["libgodot-cpp.windows.template_release.x86_64.lib"])

sources = Glob("src/*.cpp")

library = env.SharedLibrary(
    "bin/chibi_crossing",
    source=sources
)

Default(library)
