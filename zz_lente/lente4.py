#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""LENTE 3 — gli avanzi: il cablaggio di Percezione, le valvole rimaste."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lente2 as L
C, K, G, RG, V, VS, LB = L.C, L.K, L.G, L.RG, L.V, L.VS, L.L
P = "scenes/npc/Percezione.gd"

L.MUT = [
C(P, "soggetto >= 0 and soggetto == id)", "false)  # MUT",
  "CABL era_per_me·nessun dono e' mai «fatto a me»"),
C(V, "	if _hidden or dorme() or in_scena():\n		return false",
  "	return true  # MUT", "VALV gesto_libero·tutte e tre le valvole tolte"),
C(V, "	if _gs_nome != \"\" or _gs_spegni > 0.0 or _gs_attesa > 0.0:\n		return false",
  "	if _gs_nome != \"\":\n		return false  # MUT",
  "VALV gesto_libero·un gesto sopra la rampa di quello di prima"),
C(V, "			if _state != \"walk\" or _andatura == null \\\n					or float(_andatura.blend) < GESTO_BLEND_MIN:\n				return false",
  "			pass  # MUT", "VALV punto·nessun passo richiesto"),
C(V, "		\"largo\":\n			if _state != \"walk\":\n				return false",
  "		\"largo\":\n			pass  # MUT", "VALV largo·si recita da fermi"),
C(V, "	if _gs_capo_liv == on:\n		return", "	if false:\n		return  # MUT",
  "RETE capo_pende·riarma il livello a ogni chiamata"),
C(V, "func capo_livello() -> bool:\n	return _gs_capo_liv",
  "func capo_livello() -> bool:\n	return _gs_capo  # MUT",
  "RETE capo_livello·legge il bit derivato invece del livello"),
C(VS, "	var ce_l_ha := bool(nodo.call(\"capo_livello\"))",
  "	var ce_l_ha := bool(nodo.call(\"capo_storto\"))  # MUT",
  "USH capo·il registro legge la TESTA invece del livello"),
K(G, "PUNTO_TENUTA_SCARTO", "0.12", "0.0", "AMP punto·nessuno scarto personale"),
K(G, "RACCOLTO_AX_DX", "0.23", "0.02", "AMP raccolto·braccio destro ~0"),
K(G, "RIALZO_VX", "0.05", "0.0", "AMP rialzo·il petto non si apre"),
K(G, "LARGO_AX", "0.12", "0.0", "AMP largo·braccia 0"),
K(G, "CODA_MEZZA_TAU", "2.55", "0.30", "META' coda·la seconda meta' muore subito"),
K(G, "SOMA_TAU", "18.0", "1.0", "TEMPO soma·rallentando di un secondo"),
K(G, "CODA_TAU", "2.8", "0.4", "TEMPO coda·posa che dura mezzo secondo"),
K(G, "RIALZO_SALITA", "22.0", "200.0", "TEMPO rialzo·salita istantanea"),
K(G, "CAPO_IV_MAX", "9.0", "4.5", "TEMPO capo·intervallo FISSO (metronomo)"),
K(G, "CAPO_AMP_MIN", "0.08", "0.11", "AMP capo·ampiezza FISSA"),
]

if __name__ == "__main__":
    sys.exit(L.main())
