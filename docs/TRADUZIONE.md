# Tradurre Chibi Crossing — glossario e guida di stile

> In questo gioco la prosa **è una meccanica**. Le lettere del Gufo, i nomi
> delle creature, le frasi dei vicini: il giocatore ci si affeziona come
> alle immagini. Una traduzione tecnicamente corretta ma sorda romperebbe
> il gioco esattamente come un bug.

Questa pagina è il contratto: chi traduce (persona o agente) la segue alla
lettera, così le quattro parti della tabella parlano con **una voce sola**.

## Come funziona, in tre righe

- La **lingua sorgente è l'italiano**: nel codice le frasi restano quelle
  vere. La chiave della traduzione *è* la frase italiana.
- Si traduce solo al **momento di mostrare**: `L10n.t("Buongiorno!")`.
  Vedi [`systems/L10n.gd`](../systems/L10n.gd).
- Le tabelle stanno in [`locale/en/`](../locale/en), una per area:
  `ui.gd` · `lettere.gd` · `mondo.gd` · `npc.gd`.

## LA REGOLA DURA: mai tradurre un dato

Alcune stringhe **non sono testo, sono identità**: viaggiano nei
salvataggi, nei predicati, nelle tabelle parallele. Tradurle romperebbe i
villaggi salvati (e il gioco, in silenzio).

**Non si traducono MAI nel dato** — solo quando si disegnano a schermo:

| Cosa | Dove | Perché |
|---|---|---|
| i nomi dei pezzi (`"Cassetta posta"`, `"Letto"`, `"Tetto"`) | `BuildCatalog`, `BuildSystem`, `GufoOrders.CHAIN` | sono le chiavi di `village.json` e dei predicati degli Ordini |
| gli id delle specie (`"gialla"`, `"carpetta"`) | `Critters.SPECIE` | chiavi del salvataggio della collezione |
| i gradini della scala (`"diserzione"`, `"sabotaggio"`) | `Animo.SCALA` | indicizzano `SOGLIA`, `TELEGRAFO`, `STATO_UMANO` |
| i tipi di momento (`"trasloco"`, `"onsen"`) | `Legami` | chiavi del Filo Rosso salvato |
| gli id dei lavori, dei tesori, delle ricette, dei capi | vari | chiavi di salvataggio |

Regola pratica: se la stringa sta a sinistra di un `:` in una tabella, o
dentro un `save_extra()`, **non si tocca**. Si traduce il `nome`, mai l'`id`.

## La voce: che inglese scriviamo

Non «inglese neutro da manuale». L'italiano di Chibi Crossing è **caldo,
concreto, un po' antico, mai sdolcinato**: frasi brevi, immagini di cose
(legno, fiato, terra bagnata), tenerezza detta di sguincio. L'inglese deve
suonare come un **libro illustrato inglese ben scritto** — la tradizione di
Beatrix Potter e del *Vento tra i salici*, non quella dei tutorial.

Sette regole:

1. **Ritmo prima di letteralità.** Se la frase inglese non si legge bene ad
   alta voce, è sbagliata anche se traduce ogni parola. Gli a capo delle
   lettere sono **battute di respiro**: vanno conservati come struttura,
   non come conteggio di caratteri.
2. **Parole concrete, sassoni.** `warm`, `soft`, `home`, `nest`, `bloom` —
   non `comfortable`, `pleasant`, `residence`. L'italiano dice "il freddo
   bussi prima di entrare": l'inglese deve avere lo stesso mordente.
3. **Niente esclamativi in più.** L'inglese cozy tende all'iper-entusiasmo
   («Yay! Awesome!»): qui no. Il Gufo non urla mai.
4. **Il tu diventa un tu.** L'italiano dà del tu con affetto; l'inglese usa
   il contatto diretto e i verbi all'imperativo gentile: *Set a mailbox by
   the path*, non *The player should place a mailbox*.
5. **Mai spiegare quello che l'italiano lascia intendere.** Se l'originale
   sussurra, la traduzione sussurra.
6. **Il pronome dei vicini è `they`.** Il DNA non assegna un genere: mai
   `he`/`she` per un residente. (In italiano il gioco se la cava col nome.)
7. **Le unità del cozy**: mai numeri dove l'italiano usa una parola
   («qualche», «una manciata» → *a few*, *a handful*).

## Glossario — i nomi propri del mondo

Queste scelte sono **vincolanti**: cambiarne una significa cambiarla
ovunque, e il test se ne accorge.

### I personaggi e i sistemi

| Italiano | Inglese | Nota |
|---|---|---|
| Mochi | **Mochi** | nome proprio, mai tradotto |
| il Gufo | **the Owl** | maiuscola: è un personaggio |
| gli Ordini del Gufo | **the Owl's Wishes** | mai *orders*: il Gufo sussurra, non comanda |
| il Regista | **the Director** | «piccolo Regista» → *little Director* |
| il Chibiese | **Chibiese** | il nome della lingua resta |
| il Filo Rosso | **the Red Thread** | la leggenda del filo del destino |
| il Grande Albero | **the Great Tree** | |
| il Grande Prato | **the Great Meadow** | dove si parte, alla fine |
| il congedo | **the leave-taking** | mai *death*, mai *passing away* |
| il Prato Eterno (opzione) | **Endless Meadow** | l'opzione che spegne le partenze |
| l'Animo | **the Heart** *(sistema)* | in UI: *how they're feeling* |
| la scala della ribellione | **the ladder of discontent** | |
| la Premura | **Care** | il sistema che li fa accorgere di te |
| il mercante | **the pedlar** | *pedlar* (carretto, strada), non *merchant* |
| il villaggio | **the village** | |
| i vicini / i residenti | **neighbours** / **residents** | inglese **britannico** (vedi sotto) |

### Le monete e le cose

| Italiano | Inglese | Nota |
|---|---|---|
| noccioline 🌰 | **acorns** | mai *nuts* (in inglese fa un altro effetto) |
| stelline ⭐ | **stars** | |
| la dispensa | **the pantry** | |
| le Tasche (taccuino) | **Pockets** | |
| i tesori | **treasures** | |
| i barattoli | **jars** | |
| la collezione / l'enciclopedia | **the collection** / **the field guide** | |
| il retino | **the net** | |
| la canna | **the rod** | |
| il ricettario | **the recipe book** | |
| la bisaccia | **the satchel** | |
| la bancarella | **the stall** | |

### I luoghi

| Italiano | Inglese |
|---|---|
| il prato | **the meadow** |
| il bosco | **the woods** *(non forest: più intimo)* |
| la radura del falò | **the campfire clearing** |
| lo stagno | **the pond** |
| il fiume | **the river** |
| la cascata | **the waterfall** |
| la scogliera | **the bluff** |
| l'onsen | **the hot spring** |
| il sottobosco | **the undergrowth** |

### I pezzi del catalogo (solo per il DISPLAY — l'id resta italiano!)

Pavimento **Floor** · Sentiero **Path** · Tappeto **Rug** · Muro **Wall** ·
Finestra **Window** · Porta **Door** · Staccionata **Fence** · Tetto **Roof** ·
Scala **Stairs** · Solaio **Loft** · Ponticello **Rope bridge** ·
Casa albero **Treehouse** · Gazebo **Gazebo** · Tavolino **Little table** ·
Sedia **Chair** · Sgabello **Stool** · Letto **Bed** · Libreria **Bookcase** ·
Comodino **Nightstand** · Camino **Fireplace** · Lampada **Lamp** ·
Amaca **Hammock** · Braciere stellato **Starlit brazier** · Pianta **Plant** ·
Aiuola **Flower bed** · Orto **Vegetable patch** · Alberello **Sapling** ·
Cespuglio **Shrub** · Fungo **Mushroom** · Cassetta posta **Mailbox** ·
Panchina **Bench** · Lavagna **Chalkboard** · Casetta uccellini **Birdhouse** ·
Lampione **Lamppost** · Altalena **Swing** · Fontana **Fountain** ·
Giostrina **Carousel** · Carillon **Music box** · Serra **Greenhouse** ·
Mongolfiera **Hot-air balloon** · Stendino **Clothesline** ·
Barchetta **Rowboat**

### Le creature (il `nome` di `Critters.SPECIE`)

I nomi restano **minuscoli e senza articolo**, come in italiano: le due
forme (`etichetta()` col maiuscolo, `con_articolo()` dentro la frase) si
derivano da lì. **Attenzione:** in inglese `con_articolo()` deve produrre
*a golden butterfly* / *an amber dragonfly* — l'articolo giusto va messo
nella riga della specie.

farfalla rosa **pink butterfly** · farfalla azzurra **blue butterfly** ·
farfalla dorata **golden butterfly** · farfalla di ciliegio **cherry-blossom butterfly** ·
falena della luna **moon moth** · libellula ambrata **amber dragonfly** ·
farfalla di neve **snow butterfly** · farfalla di bruma **mist butterfly** ·
lucciola **firefly** · lucciola regale **royal firefly** ·
carpa dorata **golden carp** · pesciolino azzurro **little blue fish** ·
carpa rosina **rosy carp** · girino **tadpole** · pesce dell'alba **dawnfish** ·
carpa foglia d'oro **goldleaf carp** · pesce ghiaccio **icefish** ·
trota del salto **leaping trout** · anguilla della notte **night eel** ·
cicala del bosco **woodland cicada** · scarabeo dorato **golden beetle** ·
lumachina di pioggia **rain snail** · rana blu **blue frog** ·
damigella di velo **veil damselfly** ·
carota **carrot** · zucca **pumpkin** · bacca **berry** · fungo **mushroom** ·
fungo porcino **porcini mushroom** · mela **apple** · pera **pear**

### I gradini della scala (solo display: l'id resta italiano)

lavoro **at work** · svogliato **listless** · attrezzi **losing their tools** ·
rifiuto **refusing** · sabotaggio **quietly sabotaging** ·
confronto **ready to confront you** · diserzione **about to leave** ·
ammutinamento **in open mutiny**

## Inglese britannico

Il mondo è un villaggio di legno e tè: **UK spelling**.
`colour`, `neighbour`, `favourite`, `grey`, `apologise`, `travelled`,
`marvellous`. E *pedlar*, *storey* (piano), *autumn* (mai *fall*: si
confonde con la cascata e col cadere).

## Le cose che non si traducono

Il **Chibiese** («ya-ho», «ta-ki», «po-mo», «mi-ka») è una lingua vera del
gioco: resta identica in ogni edizione — è il suo bello. Si traduce solo
l'eventuale glossa italiana attorno.

Restano identici anche: i nomi dei residenti (Nocciola, Miele, Brioche…),
i simboli (✿ ♥ ★ ♦ ♨ 🌰 ⭐), i tasti (E, B, Tab…).

## Il formato delle tabelle

```gdscript
extends RefCounted
## <area>: che cosa copre questa parte.

const T := {
	"Buongiorno!": "Good morning!",
	"Hai preso %s! (n. %d)": "You caught %s! (no. %d)",
}

static func tabella() -> Dictionary:
	return T
```

Regole di forma, verificate da
[`tests/cases/test_localizzazione.gd`](../tests/cases/test_localizzazione.gd):

- i **segnaposto** (`%s`, `%d`, `%.1f`) devono essere **gli stessi e nello
  stesso ordine** dell'italiano: uno in meno e il gioco crasha alla prima
  frase formattata;
- niente valori vuoti (una traduzione vuota è peggio della frase italiana);
- niente chiave uguale al valore (vuol dire che qualcuno non ha tradotto);
- niente chiavi doppie **con traduzioni diverse** tra le parti;
- gli **a capo** `\n` vanno conservati: sono l'impaginazione delle lettere.
