extends RefCounted
## IL TACCUINO DELL'ATELIER — la colonna che RAGIONA.
##
## Non è un aiuto e non è un tutorial: è il villaggio che ti dice quello
## che ha visto. Ogni riga di questo file nasce da un dato che il gioco
## possiede GIÀ — un letto senza tetto (`BuildSystem.has_cover`), i pezzi
## che finiscono sempre vicini fra loro (le celle di `_placed`), un
## corredo che si sta popolando (`Economy.CORREDO`), il borsellino contro
## il listino (`Economy.SHOP_PIECES`). **Se non lo si può derivare, non lo
## si scrive**: un consiglio inventato non è un aiuto un po' più debole, è
## una UI che smette di meritare fiducia, e da lì non si torna indietro.
##
## LE TRE REGOLE DEL TONO, e vengono dalla REGOLA SACRA (il cozy prima di
## tutto):
##
##  1. **Non si mette fretta.** Nessuna riga dice «ti manca», «devi»,
##     «completa»: dice cosa c'è. «Del corredo del bar hai posato nove
##     pezzi» è la stessa informazione di «te ne mancano cinque», e non
##     lascia in debito nessuno.
##  2. **Non si accusa e non si classifica.** Nessun consiglio nomina un
##     vicino, e nessuno mette in fila i pezzi per quanto li usi.
##  3. **Il silenzio è un esito.** Un villaggio appena nato ha una riga
##     sola da leggere, e va benissimo così: riempire la colonna di fondi
##     di magazzino sarebbe un cruscotto.
##
## La funzione è PURA: prende i fatti e torna le carte. Chi li raccoglie è
## `BuildSystem._fatti_atelier()`, che li legge dalle loro fonti uniche.
##
## E LE FRASI SI TRADUCONO QUI, dove sono scritte. Passare la chiave a
## `L10n.tf` dal chiamante funzionerebbe uguale e sarebbe invisibile alla
## guardia della traduzione (che cerca i LETTERALI dentro `L10n.t/tf`):
## queste quattro lettere uscirebbero in italiano dentro la versione
## inglese, con la suite verde.

## Quante carte al massimo. Quattro riempiono la colonna; oltre, si scorre
## una lista di avvisi — e una lista di avvisi non è un taccuino.
const MAX := 4

## I toni: ogni famiglia ha il suo colore, sempre lo stesso, così una
## carta si riconosce prima di leggerla.
const TINTA := {
	"letto": Color("f2c27a"),      # miele — la cosa che cambia il villaggio
	"corredo": Color("d9c8ef"),    # lavanda — le collezioni
	"insieme": Color("bfe6c8"),    # menta — quello che hai imparato tu
	"borsa": Color("c68a54"),      # nocciola — i risparmi
	"mai": Color("bcdcf3"),        # cielo — un pezzo che non hai provato
	"inizio": Color("f7c9a8"),     # pesca — il primo giorno
}


## I fatti entrano, le carte escono. Ogni carta è
## `{testo, pezzo, tinta, tono, peso}`: `pezzo` è il nome di catalogo su
## cui porta il bottoncino ("" = nessun bottone).
static func consiglia(f: Dictionary) -> Array:
	var out: Array = []

	# 1 · IL LETTO SENZA TETTO. Prima di tutti, perché è l'unico consiglio
	# che cambia CHI abita il villaggio: un letto scoperto è una casa che
	# nessuno può prendere (è la stessa condizione del trasloco dei
	# Visitatori, `has_bed_under_roof`).
	var scoperti := int(f.get("letti_scoperti", 0))
	if scoperti == 1:
		out.append(_carta(L10n.t("Un letto dorme sotto le stelle. Un Tetto sulla sua cella, e qualcuno potrà abitarci."),
				"Tetto", "letto", 100))
	elif scoperti > 1:
		out.append(_carta(L10n.tf("Ci sono %d letti che dormono sotto le stelle. Basta un Tetto sulla loro cella.",
				[scoperti]), "Tetto", "letto", 100))

	# 2 · IL CORREDO CHE SI STA POPOLANDO. Si mostra solo quello che hai
	# già cominciato (almeno un pezzo posato): un corredo intatto non è
	# una cosa lasciata a metà, è una cosa che non hai ancora aperto.
	var cor: Dictionary = f.get("corredo", {})
	if not cor.is_empty() and int(cor.get("messi", 0)) > 0 \
			and str(cor.get("prossimo", "")) != "":
		out.append(_carta(L10n.tf("Del corredo di %s hai posato %d pezzi su %d. C'è anche %s, da qualche parte.",
				[L10n.t(str(cor.get("capo", ""))), int(cor.get("messi", 0)),
				int(cor.get("totale", 0)), L10n.t(str(cor.get("prossimo", "")))]),
				str(cor.get("prossimo", "")), "corredo", 80))

	# 3 · QUELLO CHE METTI SEMPRE VICINO. Non è una regola scritta da
	# nessuno: è il conteggio dei pezzi che nel TUO villaggio finiscono a
	# meno di due celle da quello che hai in mano.
	var vic: Dictionary = f.get("vicino", {})
	if not vic.is_empty():
		out.append(_carta(L10n.tf("Vicino ai tuoi %s c'è quasi sempre %s.",
				[L10n.t(str(vic.get("perno", ""))), L10n.t(str(vic.get("nome", "")))]),
				str(vic.get("nome", "")), "insieme", 70))

	# 4 · I RISPARMI. Il pezzo del carretto più vicino alle tue tasche: o
	# ce la fai già, o si dice quanto manca. Nessuna barra che si riempie:
	# un numero e basta, come quando conti le monete in una scatola.
	var aff: Dictionary = f.get("affare", {})
	if not aff.is_empty():
		var soldi := L10n.t("noccioline") if str(aff.get("cur", "nut")) == "nut" \
				else L10n.t("stelline")
		if bool(aff.get("puoi", false)):
			out.append(_carta(L10n.tf("Hai da parte abbastanza per %s: %d %s.",
					[L10n.t(str(aff.get("nome", ""))), int(aff.get("costo", 0)), soldi]),
					str(aff.get("nome", "")), "borsa", 60))
		else:
			out.append(_carta(L10n.tf("Ancora %d %s e %s è tuo.",
					[int(aff.get("manca", 0)), soldi, L10n.t(str(aff.get("nome", "")))]),
					str(aff.get("nome", "")), "borsa", 55))

	# 5 · IL PEZZO CHE NON HAI MAI PROVATO. Ce l'hai, è tuo, e non l'hai
	# mai posato nemmeno una volta. Non è un rimprovero: è la scatola in
	# fondo all'armadio.
	var mai := str(f.get("mai_usato", ""))
	if mai != "":
		out.append(_carta(L10n.tf("%s ce l'hai da un po', e non l'hai mai posato nemmeno una volta.",
				[L10n.t(mai)]), mai, "mai", 40))

	# 6 · IL PRIMO GIORNO. Se non c'è niente, non c'è niente da dedurre —
	# e allora si dice l'unica cosa vera.
	if int(f.get("posati", 0)) == 0:
		out.clear()
		out.append(_carta(L10n.t("Qui non c'è ancora niente. Un Pavimento è un buon posto da cui cominciare."),
				"Pavimento", "inizio", 10))

	out.sort_custom(func(a, b): return int(a["peso"]) > int(b["peso"]))
	if out.size() > MAX:
		out.resize(MAX)
	return out


static func _carta(testo: String, pezzo: String, tono: String, peso: int) -> Dictionary:
	return {"testo": testo, "pezzo": pezzo, "tono": tono,
			"tinta": TINTA.get(tono, Color("f2c27a")), "peso": peso}
