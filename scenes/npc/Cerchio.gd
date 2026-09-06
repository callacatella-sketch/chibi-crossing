extends RefCounted

## IL CERCHIO DEL FALÒ — chi si siede accanto a chi, e il posto di chi non c'è più.
##
## Ogni sera il villaggio si ritrova attorno al fuoco, e fino a ieri l'ordine
## in cui si sedeva era **l'ordine in cui la gente aveva traslocato**:
## `Visitors._posto_al_falo(i)` con `i` = l'indice in `_residents`. Non era
## sbagliato — era muto. Questo file lo lascia intatto e cambia soltanto
## **l'intero che gli si passa**: attorno al fuoco si mettono vicini quelli che
## nella vita del villaggio stanno già vicini, e il posto di chi è partito
## resta vuoto per qualche sera.
##
## È **puro**: nessuno stato, nessun nodo, nessun orologio, nessun dado. Entra
## un elenco di nomi e quel che il villaggio sa già di loro, esce un elenco di
## nomi. Si prova headless con `.new()`, come `Cricche`, `Deriva`, `Gesti`.
##
## ============================================================
## ⚜️ LA COSA CHE NON SI TOCCA: L'ANCORA È L'ANZIANITÀ, MAI L'AFFETTO
## ============================================================
## Una catenella si mette dove sta il suo membro **più anziano** — cioè
## l'indice che il falò usa già oggi, l'ordine di trasloco. Se si ordinasse per
## `Affetti.conto()`, per `quanto()`, o mettendo i più cari più vicini al
## fuoco, questo cerchio diventerebbe **un podio**: il posto al falò ordinato
## per affetto *è* la classifica resa visibile, ed è letteralmente l'esempio
## che la regola 2 degli Affetti vieta per iscritto. Nessun numero di questo
## file esprime «quanto», tutti esprimono «con chi»:
##
##  · **l'adiacenza è binaria e reciproca** — «questi due siedono vicini» non
##    ordina nessuno rispetto a nessun altro;
##  · **non esiste il complemento.** Ogni condizione qui dentro è un fatto
##    POSITIVO. Non c'è un ramo che chieda «e chi non sta con nessuno?», non
##    c'è una partizione, quindi non c'è un elenco di chi è fuori. Chi non ha
##    coppia, non si ritrova con nessuno e non ha figli è **catenella di uno**,
##    ancora uguale al proprio indice: se nessuno davanti a lui si è mosso, il
##    suo posto è quello di ieri, bit per bit;
##  · **il degrado è il caso limite dell'algoritmo, non un `if` scritto
##    apposta**: `cerchio(base, [], [], [], {}) == base`. Senza registri, senza
##    coppie e senza vuoti — un villaggio appena nato, un banco, il diorama del
##    titolo — questo file restituisce il falò di sempre perché l'aritmetica
##    non ha niente da spostare, non perché qualcuno l'abbia previsto.
##
## ============================================================
## IL POSTO VUOTO — ed è la metà che vale
## ============================================================
## Quando qualcuno parte, il suo posto **non si richiude la sera stessa**: un
## fantasma lo tiene per `Legami.giorni_di_vuoto()` sere — 3 se se n'è andato
## dopo tre giorni, 8 se aveva una vita intera qui. È **la stessa formula del
## lutto**, letta dallo stesso posto: la proporzione la fa già il filo, quindi
## non c'è un ramo che decide quanto vale una persona.
##
##  · **vale anche per chi se n'è andato arrabbiato.** Non è un onore
##    concesso: è una constatazione. Un `if` che distinguesse la diserzione
##    dal Grande Prato sarebbe il gioco che dice chi ha sbagliato;
##  · **nessuno lo nomina.** Niente toast, niente bolla, niente fiore acceso,
##    niente riga sul filo. Il buco è **una spaziatura doppia** in una fila
##    dove tutte le altre distanze sono uguali (nell'anello del falò il passo
##    fra due vicini è sempre lo stesso, e saltare una sedia lo moltiplica per
##    `2·cos(0.275) = 1.9249`): è la REGOLARITÀ a rendere visibile
##    l'eccezione, e un cartello la sostituirebbe con un'informazione che si
##    legge una volta sola. Da qui non esce una sola stringa destinata a chi
##    gioca — zero voci in `locale/en/`, per costruzione;
##  · **il vicino resta accanto al vuoto.** Il fantasma si cuce a chi gli
##    sedeva di fianco: la sedia vuota resta al fianco di chi ci stava
##    accanto, che è tutta la frase. Il `posto` che la riga si porta dietro è
##    quindi **il posto che si tiene quando non c'è più nessuno accanto a cui
##    stare**: se anche quel vicino è partito il giorno dopo, il fantasma
##    torna lì e resta catenella di uno. Si tollera, non si inventa.
##
## ============================================================
## LE DUE ANAGRAFI — e qui la moneta è il NOME
## ============================================================
## Il villaggio ha due chiavi per la stessa persona: il **nome** del DNA
## («Papavero») e la **label** («la volpina Papavero»). Le tre sorgenti che
## ordinano questo cerchio parlano tutte nomi — `Cricche.compagni`,
## `Affetti._coppie_ieri`, `Legami.genitori_di`/`figli_di` — mentre
## `_residents` e `_posto_al_falo` parlano label. **Dentro questo file si parla
## NOMI, sempre**, e chi cabla converte una volta sola al bordo con
## `Legami.nome_da_chiave` (statica, pura, e l'unica che funziona anche su chi
## è partito: `Visitors._nome_da_label` cicla `_residents` e per un partito
## restituisce la label invariata, in silenzio).
##
## ⚠️ **E IL FANTASMA NON ATTRAVERSA MAI UN CONFINE.** La sua chiave è
## `"\n" + nome`, e `"\n"` è **lo stesso separatore di `Cricche.chiave(a, b)`**:
## una chiave-fantasma finita là dentro si spezzerebbe in `["", nome]` — due
## pezzi, quindi nessun errore, quindi scartata in silenzio — e
## `Legami.nome_da_chiave("\nPapavero")` la restituirebbe tale e quale,
## aprendo un filo a un nome che non esiste. Il fantasma vive dentro `Cerchio`
## e dentro `_vuoti`, e in nessun altro posto: mai a `Legami`, mai ad
## `Affetti`, mai a `Cricche`, mai a `node_di`.
##
## ============================================================
## IL CERCHIO NON RETROAGISCE — e questo è un firewall, non una cortesia
## ============================================================
## Da qui non si scrive niente: `cerchio()` non tocca nemmeno gli argomenti che
## riceve. È la seconda metà del cancello che `Visitors._segna_incontro` tiene
## già chiuso (al falò la co-presenza non si registra). Se il cerchio potesse
## scrivere in `Cricche`, la sera fabbricherebbe i ritrovi che la sera dopo
## legge: le catenelle diventerebbero clique per costruzione `(i, i+1, i+2)`
## che passano OGNI collaudo — è la forma esatta del guasto che `Affetti.GESTI`
## ha già chiuso togliendo la voce `falo`.
##
## ============================================================
## LA RISONANZA CON L'EREDITÀ, e va detta perché non la si fonda
## ============================================================
## Il cucciolo siede **fra i suoi** al falò (qui), e da grande andrà **nel posto
## dei suoi** (`Eredita.gd`). Sono due canali indipendenti, due file diversi,
## **nessuna tabella condivisa**: questo legge `Legami.genitori_di`, quello
## legge `Cricche.ritrovo_di`, e nessuno dei due sa dell'altro. Chi un domani li
## fondesse «perché dicono la stessa cosa» si ritroverebbe una tabella gemella
## dove oggi ci sono due letture indipendenti dello stesso villaggio.


## QUANTO PUÒ ESSERE LUNGA UNA CATENELLA fatta di ritrovi. È uno dei DUE soli
## numeri nuovi di questo pacchetto, e il suo valore è una lettura della
## geometria del falò: il passo fra due sedie è `0.55 rad`, quindi quattro
## sedie occupano **tre** passi — `1.65 rad`, cioè **95°** del primo anello,
## poco più di un quarto del giro. Sopra, un gruppo di conoscenti smette di
## essere un gruppo e diventa metà villaggio seduto in fila, e attorno al fuoco
## non si legge più «questi si trovano»: si legge un banco di scuola.
##
## ⚠️ Il numero d'angolo si conta sui PASSI, non sulle sedie: `n × 0.55` è
## l'arco che ne separa `n + 1`, e chi lo scrive per `n` sedie si trova a
## discutere di un tetto un terzo più largo di quello vero.
##
## ⚠️ **NON VALE PER LE CATENELLE DURE** (le famiglie e le coppie), che possono
## arrivare a sei — due famiglie cucite da una coppia nata dopo una rottura.
## Sei posti sono cinque passi, `2.75 rad` = **158°**, quasi metà cerchio, e si
## accetta: sono relazioni esclusive e vere, e mettere un tetto lì vorrebbe
## dire scegliere **quale famiglia spezzare**. Si conta nel banco, non si
## taglia.
const CATENELLA_MAX := 4

## QUANTI POSTI VUOTI AL MASSIMO, nello stesso cerchio. È l'altro numero nuovo.
## Due sedie vuote in ventotto sono un'assenza; cinque sono un villaggio che si
## sta svuotando, cioè **un grafico a barre delle partenze** — e un cerchio che
## racconta quanta gente se n'è andata sta dicendo al giocatore che ha
## sbagliato qualcosa. Sopra il tetto si tengono i vuoti più FRESCHI: quelli
## vecchi stavano comunque per richiudersi da sé.
const VUOTI_MAX := 2


# ============================================================ il fantasma

## LA CHIAVE DI UN POSTO VUOTO. Non è un nome e non deve poter essere scambiato
## per uno: comincia con un a-capo, che nessun nome del gioco contiene.
##
## ⚠️ Si passa il **nome** del DNA, non la label — vedi la nota sulle due
## anagrafi in testa al file.
static func chiave_vuoto(nome: String) -> String:
	return "\n" + nome


## …e la domanda opposta, in un posto solo. Esiste perché nessuno debba
## riscrivere `begins_with("\n")` a mano: la forma del sentinella si cambia
## qui e da nessun'altra parte.
static func e_un_vuoto(chiave: String) -> bool:
	return chiave.begins_with("\n")


## DAL DISCO TORNANO INTERI. Le righe dei vuoti si salvano, e nel JSON gli
## interi tornano `float`: si rilegge con `int()` e mai con `is int`, che è
## falso proprio per il numero che è appena passato dal disco. È la stessa
## trappola già pagata dal contrassegno `sognato` dei Sogni e dal ledger di
## `Strati`, e per questo la riga è JSON-safe **già in RAM** — solo stringhe e
## interi, nessun `Vector2i`, nessun nodo.
##
## Una riga malformata si butta senza dire niente: il degrado va sempre verso
## «il falò di sempre», mai verso un errore addosso a chi gioca.
static func vuoti_letti(grezzi) -> Array:
	var fuori: Array = []
	if not (grezzi is Array):
		return fuori
	for g in (grezzi as Array):
		if not (g is Dictionary):
			continue
		var d := g as Dictionary
		var chi := str(d.get("chi", ""))
		if chi == "":
			continue
		var giorni := int(d.get("giorni", 0))
		if giorni <= 0:
			continue
		fuori.append({
			"chi": chi,
			"vicino": str(d.get("vicino", "")),
			"posto": int(d.get("posto", 0)),
			"giorno": int(d.get("giorno", 0)),
			"giorni": giorni,
		})
	return fuori


## L'UNICO ORDINAMENTO DEI VUOTI, e ha due lettori: `a` viene prima di `b` se è
## **uscito dopo di lui**.
##
## La sequenza delle partenze del villaggio è: sera dopo sera, e dentro una sera
## dall'indice alto verso il basso (`Visitors._tick_partenze` cicla
## all'indietro). Rovesciarla — che è quello che serve per rimettere ognuno al
## suo posto — dà esattamente questo: **giorno decrescente, e a parità di
## giorno posto crescente**.
##
## ⚠️ `Array.sort_custom` in Godot **non è stabile**, e due partenze della
## stessa sera sono un pareggio vero (gli indici scalano a ogni `remove_at`):
## il terzo confronto sul nome non è pignoleria, è quel che rende due sere
## identiche due cerchi identici.
static func _uscito_dopo(a, b) -> bool:
	var da := a as Dictionary
	var db := b as Dictionary
	var ga := int(da.get("giorno", 0))
	var gb := int(db.get("giorno", 0))
	if ga != gb:
		return ga > gb
	var pa := int(da.get("posto", 0))
	var pb := int(db.get("posto", 0))
	if pa != pb:
		return pa < pb
	return str(da.get("chi", "")) < str(db.get("chi", ""))


## QUALI VUOTI SONO ANCORA APERTI STASERA, e quanti se ne possono vedere.
##
## La durata la porta la RIGA (`giorni`, scritta quando il vuoto si è aperto
## leggendo `Legami.giorni_di_vuoto`): qui non si ricopia la formula del lutto,
## o sarebbero due orologi per la stessa cosa. Un vuoto è vivo per `giorni`
## sere a partire dalla sua, e la sera dopo il cerchio si richiude da sé —
## **la richiusura non è un evento**: nessuna riga da cancellare, nessuna posa
## da togliere, il predicato smette di essere vero e basta.
##
## ⚠️ Sopra il tetto si taglia in coda, quindi l'ORDINE decide chi si vede:
## si tengono i più freschi, e a parità di sera si comincia da chi è uscito per
## ultimo — che è `_uscito_dopo`, l'unico ordinamento di questo file (vedi la
## sua nota: è anche quello con cui i fantasmi tornano al loro posto).
##
## ⚠️ E una riga senza nome NON si ignora e basta: si BUTTA. Se restasse
## nell'elenco occuperebbe uno dei due posti del tetto senza produrre nessuna
## sedia — cioè spegnerebbe in silenzio il vuoto di una persona vera.
static func vuoti_vivi(vuoti: Array, oggi: int, tetto := VUOTI_MAX) -> Array:
	var vivi: Array = []
	for v in vuoti:
		if not (v is Dictionary):
			continue
		var d := v as Dictionary
		if str(d.get("chi", "")) == "":
			continue
		# `giorni <= 0` NON ha un ramo suo, e non è una dimenticanza: `eta` qui
		# non è mai negativo, quindi `eta >= giorni` è già vero per qualunque
		# durata nulla o assurda. Una guardia che nessun test può far fallire è
		# una guardia che non c'è — quella che serve sta in `vuoti_letti`, dove
		# la riga viene rifiutata PRIMA di entrare nel salvataggio.
		var giorni := int(d.get("giorni", 0))
		var eta := oggi - int(d.get("giorno", 0))
		# `eta < 0` è una riga che viene dal futuro (un salvataggio con
		# l'orologio indietro, un banco): si butta, verso ieri come sempre
		if eta < 0 or eta >= giorni:
			continue
		vivi.append(d)
	vivi.sort_custom(_uscito_dopo)
	if tetto >= 0 and vivi.size() > tetto:
		vivi = vivi.slice(0, tetto)
	return vivi


# ============================================================ le catenelle

## CHI SIEDE ACCANTO A CHI. Entra la base (i nomi nell'ordine di anzianità,
## **coi fantasmi già infilati**: li mette `cerchio()`), escono le catenelle —
## una per persona all'inizio, poi cucite fra loro.
##
## L'ORDINE IN CUI SI CUCE È LA PRIORITÀ, e non è gusto:
##
## 1. **le FAMIGLIE** — genitore, figli in fila per età, genitore. Il cucciolo
##    sta in mezzo e i genitori non si toccano più: **è la frase**, non un
##    effetto collaterale da compensare. E i fratelli arrivano già in ordine
##    d'età da `Legami.figli_di` (ordina per `giorno_arrivo`): qui non si
##    riordina a mano, o sarebbero due risposte alla stessa domanda;
## 2. **le COPPIE** — i due adiacenti;
## 3. **i VUOTI** — il fantasma accanto al suo vicino. Dopo le relazioni dei
##    vivi, prima dei ritrovi: una sedia vuota non deve perdere il suo posto
##    contro una conoscenza, ma non scavalca una famiglia;
## 4. **i RITROVI** — chi si trova con chi (`Cricche.compagni`), ed è **l'unico
##    legame che paga il tetto**.
##
## Le prime tre sono relazioni **esclusive e reciproche** (un cucciolo ha due
## genitori, una coppia è due persone, un vuoto ha un vicino); i ritrovi sono
## molti-a-molti e mangerebbero gli estremi che alle esclusive servono. Da qui
## il caso `_il_ritrovo_non_spezza_una_coppia`.
##
## Dentro ogni famiglia si va per ancora, e dentro coppie e ritrovi per la
## coppia di indici: **così l'ordine in cui i registri elencano le loro righe
## non conta**, e due sere identiche danno un cerchio identico anche se
## `Cricche` ha rimescolato la sua lista.
static func catenelle(base: PackedStringArray, famiglie: Array, coppie: Array,
		vuoti: Array, ritrovi: Dictionary,
		tetto := CATENELLA_MAX) -> Array:
	var indice := _indice(base)
	var cat: Array = []
	var dove := {}
	# OGNI PERSONA COMINCIA CATENELLA DI SÉ. È l'invariante del degrado resa
	# STRUTTURA invece che ramo: senza un solo legame, quel che esce di qui è
	# il falò di sempre — non perché ci sia un `if`, ma perché non c'è niente
	# da cucire.
	for i in base.size():
		cat.append(PackedStringArray([base[i]]))
		dove[base[i]] = i
	# ⚠️ due omonimi: `indice` ne perderebbe uno e `anello` gli toglierebbe la
	# sedia — due corpi sullo stesso punto. `ChibiDNA` garantisce l'unicità
	# delle LABEL, non quella dei nomi: è un residuo aperto del progetto, e
	# questo file non lo peggiora. Si tira indietro e lascia il falò di ieri.
	if indice.size() < base.size():
		return cat

	for blocco in _blocchi_famiglia(famiglie, indice):
		for k in range((blocco as PackedStringArray).size() - 1):
			_cuci(cat, dove, blocco[k], blocco[k + 1], 0)
	for c in _coppie_in_ordine(coppie, indice):
		_cuci(cat, dove, c[0], c[1], 0)
	for v in _vuoti_in_ordine(vuoti, indice):
		_cuci(cat, dove, chiave_vuoto(str((v as Dictionary).get("chi", ""))),
				str((v as Dictionary).get("vicino", "")), 0)
	for r in _ritrovi_in_ordine(ritrovi, indice):
		_cuci(cat, dove, r[0], r[1], tetto)

	var vive: Array = []
	for c in cat:
		if not (c as PackedStringArray).is_empty():
			vive.append(c)
	return vive


## DOVE VA OGNI CATENELLA: **si mette dove sta il suo più anziano.**
##
## L'ancora è il minimo degli indici di base dei suoi membri — cioè l'ordine di
## trasloco, cioè quello che il falò fa già oggi. Non c'è nessun altro
## criterio, e non deve entrarcene nessuno: vedi la nota in testa al file.
##
## ⚠️ **Il pareggio è impossibile per costruzione, e per questo qui non c'è un
## tie-break** (una guardia che nessun test può far fallire è una guardia che
## non c'è): ogni nome sta in esattamente una catenella, quindi il suo indice
## appartiene a una sola ancora, quindi due ancore non possono coincidere.
## `Array.sort_custom` non è stabile, ma su chiavi distinte l'instabilità non
## ha dove mordere.
##
## E chi non compare in nessuna catenella è catenella di sé: è la riga che
## rende `anello(base, [])` esattamente `base`.
static func anello(base: PackedStringArray, cat: Array) -> PackedStringArray:
	var indice := _indice(base)
	if indice.size() < base.size():
		return base.duplicate()      # omonimi: il falò di ieri (vedi `catenelle`)
	var righe: Array = []
	var visto := {}
	for c in cat:
		var pulita := PackedStringArray()
		var ancora := -1
		for n in (c as PackedStringArray):
			var s := str(n)
			# chi non è nella base di stasera non siede: `Legami.figli_di` e
			# `genitori_di` ciclano anche i partiti, ed è il loro mestiere
			if not indice.has(s) or visto.has(s):
				continue
			visto[s] = true
			pulita.append(s)
			var k: int = indice[s]
			if ancora < 0 or k < ancora:
				ancora = k
		if pulita.is_empty():
			continue
		righe.append([ancora, pulita])
	for i in base.size():
		if visto.has(base[i]):
			continue
		visto[base[i]] = true
		righe.append([i, PackedStringArray([base[i]])])
	righe.sort_custom(func(a, b) -> bool: return int(a[0]) < int(b[0]))
	var fuori := PackedStringArray()
	for r in righe:
		fuori.append_array(r[1])
	return fuori


## IL CERCHIO DI STASERA: i nomi nell'ordine in cui si siedono attorno al
## fuoco, fantasmi compresi. La posizione nell'elenco è l'intero che va a
## `Visitors._posto_al_falo`, e quella funzione non si tocca.
##
## ⚠️ **`vuoti` sono i vuoti VIVI** (`vuoti_vivi(_vuoti, oggi)`), non tutto lo
## storico: la potatura è una domanda sul calendario, e il calendario qui
## dentro non c'è.
static func cerchio(base: PackedStringArray, famiglie: Array, coppie: Array,
		vuoti: Array, ritrovi: Dictionary,
		tetto := CATENELLA_MAX) -> PackedStringArray:
	var piena := _infila_i_vuoti(base, vuoti)
	return anello(piena, catenelle(piena, famiglie, coppie, vuoti, ritrovi, tetto))


# ============================================================ il macchinario
# Da qui in giù non c'è nessuna decisione di gioco: solo il modo in cui le
# quattro sorgenti diventano un elenco di legami sempre nello stesso ordine.

static func _indice(base: PackedStringArray) -> Dictionary:
	var d := {}
	for i in base.size():
		d[base[i]] = i
	return d


## I FANTASMI TORNANO A RITROSO: si RIDISFANNO le partenze, l'ultima per prima.
##
## `posto` è l'indice che quella persona aveva in `_residents` **nell'istante in
## cui è uscita**, cioè in una fila da cui chi era già partito era stato tolto e
## chi doveva ancora partire c'era ancora. Rimettercelo dentro è quindi
## letteralmente l'inverso di un `remove_at`, e come ogni inverso si applica
## **in ordine rovesciato**: si reinserisce prima chi è uscito per ultimo, e la
## fila che ne esce è quella di prima, sedia per sedia.
##
## ⚠️ **NON è «dal fondo», e non è un dettaglio.** Ordinare per `posto`
## decrescente sembra la cosa giusta — è l'idioma con cui si tolgono più
## elementi da un array — ma qui i due `posto` sono misurati su file DIVERSE, e
## la regola sbaglia in metà degli scenari a due fantasmi. MISURATO su cinque
## sequenze di partenza vere (`tools`-less, la sonda in `test_cerchio`), fra cui
## la più comune di tutte: `_tick_partenze` cicla ALL'INDIETRO, quindi due che
## se ne vanno la stessa sera escono dall'indice alto verso il basso — e per
## ridisfarle si va dal basso verso l'alto, cioè **all'incontrario** di quel che
## il nome «dal fondo» suggerisce. Con la regola vecchia il secondo fantasma
## finiva una sedia più in là, e il cerchio «sembrava giusto» comunque.
##
## L'ordine è `_uscito_dopo`, lo stesso di `vuoti_vivi`: uno solo, in un posto
## solo, o i due divergerebbero il giorno che qualcuno ne ritocca uno.
##
## **Il residuo, dichiarato:** se un vuoto FRESCO scade prima di uno VECCHIO
## (le durate vanno da 3 a 8 sere), il vecchio si ritrova reinserito in una fila
## a cui manca anche l'altro, e scivola di una sedia. Non è riparabile senza
## tenere la storia intera delle partenze, e la cucitura col `vicino` lo copre
## nel caso che conta: si tollera, non si inventa.
static func _infila_i_vuoti(base: PackedStringArray, vuoti: Array) -> PackedStringArray:
	var piena := base.duplicate()
	# si scartano le righe malformate PRIMA di ordinare: il comparatore le
	# leggerebbe come dizionari e un errore a runtime, in questo progetto, non
	# fa fallire niente — interrompe la funzione e lascia il verde
	var righe: Array = []
	for v in vuoti:
		if v is Dictionary and str((v as Dictionary).get("chi", "")) != "":
			righe.append(v)
	righe.sort_custom(_uscito_dopo)
	for v in righe:
		var d := v as Dictionary
		var chi := str(d.get("chi", ""))
		# mai due sedie per lo stesso fantasma, e mai una sedia a chi è seduto:
		# se un nome è tornato nella base (un omonimo, una riga vecchia), il
		# vivo ha la precedenza sul proprio ricordo
		if piena.find(chi) >= 0 or piena.find(chiave_vuoto(chi)) >= 0:
			continue
		piena.insert(clampi(int(d.get("posto", 0)), 0, piena.size()),
				chiave_vuoto(chi))
	return piena


## LA CUCITURA: `a` e `b` finiscono seduti l'uno accanto all'altro.
##
## Tre rifiuti, e ognuno chiude una scena precisa:
##
##  · **stessa catenella** — si chiuderebbe ad anello, e un anello attorno al
##    fuoco non è più una fila: qualcuno finirebbe seduto due volte;
##  · **non a un ESTREMO** — infilarsi in mezzo spezzerebbe un'adiacenza già
##    promessa a qualcun altro. È così che un ritrovo non può mettersi fra due
##    che stanno insieme;
##  · **oltre il tetto** — solo per i legami molli. `tetto <= 0` vuol dire
##    «nessun tetto», ed è come passano famiglie, coppie e vuoti.
##
## Cucendo, una delle due catenelle può doversi rovesciare: un cerchio non ha
## un verso privilegiato, e quel che conta è che fra due fratelli non si
## infili nessuno — non da che parte si comincia a leggerli.
static func _cuci(cat: Array, dove: Dictionary, a: String, b: String,
		tetto: int) -> bool:
	if a == "" or b == "" or a == b:
		return false
	if not dove.has(a) or not dove.has(b):
		return false
	var ia: int = dove[a]
	var ib: int = dove[b]
	if ia == ib:
		return false
	var ca: PackedStringArray = cat[ia]
	var cb: PackedStringArray = cat[ib]
	var pa := ca.find(a)
	var pb := cb.find(b)
	if pa != 0 and pa != ca.size() - 1:
		return false
	if pb != 0 and pb != cb.size() - 1:
		return false
	if tetto > 0 and ca.size() + cb.size() > tetto:
		return false
	var fusa := ca.duplicate()
	if pa == 0:
		fusa.reverse()
	var coda := cb.duplicate()
	if pb == cb.size() - 1:
		coda.reverse()
	fusa.append_array(coda)
	cat[ia] = fusa
	cat[ib] = PackedStringArray()
	for n in coda:
		dove[str(n)] = ia
	return true


## L'ancora di un gruppo di nomi: il più anziano che ci sia dentro. `-1` se non
## ce n'è nessuno nella base di stasera.
static func _ancora(nomi, indice: Dictionary) -> int:
	var m := -1
	for n in nomi:
		var s := str(n)
		if not indice.has(s):
			continue
		var k: int = indice[s]
		if m < 0 or k < m:
			m = k
	return m


## LA FAMIGLIA COME BLOCCO: genitore, figli in fila per età, genitore.
##
## I figli arrivano già ordinati da `Legami.figli_di` e non si toccano. Se un
## genitore è partito il blocco si accorcia da sé; se sono partiti tutti e due,
## i fratelli restano insieme lo stesso — che è la cosa giusta e viene gratis.
## Un blocco senza figli non produce niente: l'adiacenza di due genitori è
## mestiere della coppia, non della famiglia.
static func _blocchi_famiglia(famiglie: Array, indice: Dictionary) -> Array:
	var fuori: Array = []
	for f in famiglie:
		if not (f is Dictionary):
			continue
		var d := f as Dictionary
		var genitori: Array = []
		for g in (d.get("genitori", []) as Array):
			var gs := str(g)
			if indice.has(gs) and not genitori.has(gs):
				genitori.append(gs)
		var figli: Array = []
		for c in (d.get("figli", []) as Array):
			var cs := str(c)
			if indice.has(cs) and not genitori.has(cs) and not figli.has(cs):
				figli.append(cs)
		if figli.is_empty():
			continue
		var blocco := PackedStringArray()
		if genitori.size() > 0:
			blocco.append(str(genitori[0]))
		for c in figli:
			blocco.append(str(c))
		if genitori.size() > 1:
			blocco.append(str(genitori[1]))
		fuori.append([_ancora(blocco, indice), blocco])
	fuori.sort_custom(func(a, b) -> bool: return int(a[0]) < int(b[0]))
	var blocchi: Array = []
	for r in fuori:
		blocchi.append(r[1])
	return blocchi


## Le coppie, ognuna col più anziano davanti, in ordine di ancora. Entra la
## forma di `Affetti._coppie_ieri`: un array di `[nome, nome]`.
static func _coppie_in_ordine(coppie: Array, indice: Dictionary) -> Array:
	var righe: Array = []
	var viste := {}
	for c in coppie:
		if not (c is Array) or (c as Array).size() < 2:
			continue
		var a := str((c as Array)[0])
		var b := str((c as Array)[1])
		if not indice.has(a) or not indice.has(b) or a == b:
			continue
		righe.append(_riga_legame(a, b, indice, viste))
	return _senza_vuote(righe)


## I ritrovi, dalla forma di `Cricche.compagni()`: un dizionario
## `nome -> PackedStringArray` di chi si ritrova con lui. La riga non ha un
## verso (`Cricche` la scrive coi due nomi in ordine alfabetico), quindi qui si
## normalizza sull'anzianità come per le coppie: da un legame senza verso non
## si ricava chi cercava chi.
static func _ritrovi_in_ordine(ritrovi: Dictionary, indice: Dictionary) -> Array:
	var righe: Array = []
	var viste := {}
	for k in ritrovi:
		var a := str(k)
		if not indice.has(a):
			continue
		var compagni = ritrovi[k]
		# `Cricche.compagni()` risponde `PackedStringArray`, ma un banco o un
		# salvataggio riletto possono passare un Array: si accettano tutti e
		# due invece di rifiutare in silenzio la riga sbagliata
		if not (compagni is PackedStringArray or compagni is Array):
			continue
		for c in compagni:
			var b := str(c)
			if not indice.has(b) or a == b:
				continue
			righe.append(_riga_legame(a, b, indice, viste))
	return _senza_vuote(righe)


## I vuoti nell'ordine in cui il loro fantasma siede: deterministico, e non
## dipende da come il salvataggio ha elencato le righe.
static func _vuoti_in_ordine(vuoti: Array, indice: Dictionary) -> Array:
	var righe: Array = []
	for v in vuoti:
		if not (v is Dictionary):
			continue
		var k := chiave_vuoto(str((v as Dictionary).get("chi", "")))
		if not indice.has(k):
			continue
		righe.append([indice[k], v])
	righe.sort_custom(func(a, b) -> bool: return int(a[0]) < int(b[0]))
	var fuori: Array = []
	for r in righe:
		fuori.append(r[1])
	return fuori


## Un legame normalizzato e mai ripetuto: `[ancora, altro_indice, a, b]` col
## più anziano davanti. Restituisce `[]` se quel legame è già passato — la
## stessa coppia elencata dai due lati non è due legami.
static func _riga_legame(a: String, b: String, indice: Dictionary,
		viste: Dictionary) -> Array:
	var ia: int = indice[a]
	var ib: int = indice[b]
	var primo := a if ia < ib else b
	var secondo := b if ia < ib else a
	var chiave := primo + "\n" + secondo
	if viste.has(chiave):
		return []
	viste[chiave] = true
	return [mini(ia, ib), maxi(ia, ib), primo, secondo]


## Butta le righe vuote e mette in ordine di ancora — e a parità di ancora,
## per l'altro estremo: due legami che partono dalla stessa persona sono un
## pareggio VERO, e `sort_custom` non è stabile.
static func _senza_vuote(righe: Array) -> Array:
	var piene: Array = []
	for r in righe:
		if not (r as Array).is_empty():
			piene.append([int(r[0]), int(r[1]), str(r[2]), str(r[3])])
	piene.sort_custom(func(a, b) -> bool:
		if int(a[0]) != int(b[0]):
			return int(a[0]) < int(b[0])
		return int(a[1]) < int(b[1]))
	var fuori: Array = []
	for r in piene:
		fuori.append([str(r[2]), str(r[3])])
	return fuori
