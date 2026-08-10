extends RefCounted
## L'ORACOLO DELL'AGENDA: la copia CONGELATA dei punteggi di `choose()`
## com'erano prima che l'utility AI passasse in C++.
##
## Sta FUORI da tests/cases/ apposta (il runner esegue solo
## tests/cases/test_*.gd): non è un caso di test, è il METRO con cui si
## misura che il villaggio non si è messo a comportarsi diversamente.
##
## Qui c'è solo la parte DETERMINISTICA di `choose()`: i sette punteggi.
## L'argmax e il dado restano di là, perché è lì che vivono ancora.
##
## NON CANCELLARE senza cancellare anche la prova di equivalenza: sarebbe
## come togliere il campione di riferimento e continuare a pesare.


## Era il corpo di VillagerBrain.choose(), riga per riga, con lo stesso
## ordine di moltiplicazione — che non è pedanteria: con gli stessi
## operandi e la stessa associazione i due risultati sono lo STESSO double,
## e l'equivalenza si può pretendere esatta invece che «circa».
static func punteggi(needs: Dictionary, ctx: Dictionary, indole: Array,
		quirk: String) -> Dictionary:
	var punti := {}

	punti["spuntino"] = (1.0 - float(needs["pancino"])) * 2.0 \
			* (1.6 if "goloso" in indole else 1.0) \
			* (1.0 if bool(ctx.get("spuntino_vicino", false)) else 0.25)

	punti["riposo"] = (1.0 - float(needs["energia"])) * 1.6 \
			* (1.4 if "dormiglione" in indole else 1.0)

	punti["quattro_chiacchiere"] = (1.0 - float(needs["compagnia"])) * 1.8 \
			* (1.5 if "chiacchierone" in indole else 1.0) \
			* (0.6 if "timido" in indole else 1.0) \
			* (1.0 if bool(ctx.get("amico_in_giro", false)) else 0.0)

	punti["cura_giardino"] = (1.0 - float(needs["cura"])) * 1.5 \
			* (1.7 if "ordinato" in indole else 1.0) \
			* (1.4 if bool(ctx.get("mattina", false)) else 1.0) \
			* (1.0 if bool(ctx.get("aiuola_da_annaffiare", false)) else 0.0)
	if bool(ctx.get("aiuola_da_annaffiare", false)):
		punti["cura_giardino"] = maxf(float(punti["cura_giardino"]), 0.9)

	punti["meraviglia"] = (1.0 - float(needs["meraviglia"])) * 1.4 \
			* (1.6 if "sognatore" in indole else 1.0)

	punti["stella"] = 3.0 if bool(ctx.get("sera_stellata", false)) \
			and ("sognatore" in indole or quirk == "canta_alla_luna") else 0.0

	punti["regia"] = 0.75 if bool(ctx.get("regia", false)) else 0.0

	return punti
