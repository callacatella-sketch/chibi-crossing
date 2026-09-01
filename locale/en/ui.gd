extends RefCounted
## Traduzione inglese — Le schermate: titolo, pausa, impostazioni, HUD, Tasche, negozio, costruzione.
##
## Chiave = la frase italiana del sorgente. Vedi docs/TRADUZIONE.md per il
## glossario vincolante e le regole di stile.

const T := {
	# ------------------------------------------------ il sasso da rimbalzello
	"sasso piatto": "flat stone",
	"dal vicino che li colleziona": "from the neighbour who collects them",
	"Levigato dall'acqua, sottile come una moneta.\nSulla riva dello stagno (E) fa quattro rimbalzi, se l'aria è ferma.":
		"Worn smooth by the water, thin as a coin.\nOn the pond shore (E) it skips four times, if the air is still.",
	# ---------------------------------------------------------- il titolo
	# La riga sotto il titolo cambia col CLIMA del villaggio salvato
	# (RiassuntoSalvataggio.sottotitolo): è l'unica cosa che il menù dice,
	# e dice pochissimo — il resto lo fa vedere. In inglese vale doppio:
	# niente di più esplicito dell'italiano, o diventa una notifica.
	"Un villaggio ti aspetta sotto il Grande Albero.":
			"A village is waiting for you under the Great Tree.",
	"Il villaggio è più silenzioso, in questi giorni.":
			"The village is quieter, these days.",
	"Qualcuno sta salutando il mondo, sotto il Grande Albero.":
			"Someone is saying goodbye to the world, under the Great Tree.",
	"Il Grande Albero ti aspetta. C'è un posto vuoto, all'ombra.":
			"The Great Tree is waiting for you. There is an empty place, in the shade.",
	"Sono tutti qui, sotto il Grande Albero. Ti stavano aspettando.":
			"They are all here, under the Great Tree. They were waiting for you.",
	"Sotto il Grande Albero non si sta mai fermi.":
			"Nobody stays still for long under the Great Tree.",
	"Il Grande Albero ti aspetta, e i tuoi vicini anche.":
			"The Great Tree is waiting for you, and so are your neighbours.",
	"Continua": "Continue",
	"Nuovo villaggio": "New village",
	"Impostazioni": "Settings",
	"Esci": "Quit",
	"Ricominciare da capo?": "Start over?",
	"Il villaggio attuale sarà sostituito da uno nuovo.\nQuesta scelta non si può annullare.":
			"The village you have now will be replaced by a new one.\nThis choice cannot be undone.",
	"Annulla": "Cancel",

	# ---------------------------------------------------------- la pausa
	"In pausa": "Paused",
	"Il villaggio ti aspetta.": "The village is waiting for you.",
	"Riprendi": "Resume",
	"Torna al titolo": "Back to the title",
	"Esci dal gioco": "Quit the game",
	"Lingua": "Language",

	# ------------------------------------------------------ le impostazioni
	# (le etichette dei cursori: prima restavano in italiano dentro il
	# gioco inglese — le righe del pannello non passavano da L10n)
	"Volume generale": "Overall volume",
	"Musica": "Music",
	"Effetti": "Effects",
	"Voci": "Voices",
	"Velocità di Mochi": "Mochi's pace",
	"Schermo intero": "Full screen",
	"Riduci animazioni": "Reduce motion",
	"Prato Eterno (nessuna partenza)": "Eternal Meadow (nobody ever leaves)",
	# «Il villaggio pensa»: la leva del cuore che scrive (Fase 5). La riga
	# compare solo a chi ha un modello, e non nomina nessuna macchina — chi
	# gioca non deve sapere cos'è un modello linguistico per decidere se
	# vuole che i suoi vicini abbiano idee loro.
	"Il villaggio pensa": "The village thinks",
	"Ogni tanto un vicino ha un'idea tutta sua. Chiede memoria al computer, e cambia dal prossimo avvio.":
			"Now and then a neighbour has an idea all of their own. It asks the computer for some memory, and it changes from the next time you open the game.",
	"Indietro": "Back",
	"Qualità grafica": "Graphics quality",

	# ------------------------------------------------------ rispondere
	# La cassetta che si può anche riempire: si sceglie un momento vero
	# della vostra storia e due parole di Chibiese.
	"E — rispondi": "E — write back",
	# in inglese non c'è nessuna preposizione da fondere con l'articolo:
	# `con_di` non trova niente da cambiare e la frase passa intatta
	"Mi ricordo %s.": "I remember %s.",
	# e la SUA risposta, che arriva nella cassetta il mattino dopo: il
	# primo %s è il racconto del momento, il secondo il Chibiese del
	# grazie (che non si traduce: è la loro lingua), il terzo la firma
	"Ho letto e riletto la tua lettera.\nMe lo ricordo anch'io, %s.\n\n«%s»\n— %s":
			"I have read your letter over and over.\nI remember it too — %s.\n\n«%s»\n— %s",
	"quel giorno": "that day",
	"A chi vuoi rispondere?": "Who do you want to write to?",
	"Di cosa ti ricordi, con %s?": "What do you remember, you and %s?",
	"E due parole.": "And two words.",
	"Imbuca la lettera": "Post the letter",
	"↑↓ scegli   ·   E conferma   ·   ESC chiude":
			"↑↓ choose   ·   E confirms   ·   ESC closes",
	"è la vostra storia   ·   E sceglie   ·   ESC torna":
			"this is your story together   ·   E chooses   ·   ESC goes back",
	"E cambia le parole   ·   INVIO spedisce   ·   ESC torna":
			"E changes the words   ·   ENTER posts it   ·   ESC goes back",
	"(al Grande Prato)": "(in the Great Meadow)",
	"(gli hai già scritto oggi)": "(you've written to them today already)",
	"Non hai ancora una storia da raccontare a nessuno.":
			"You haven't a story to tell anyone yet.",
	"La lettera è nella cassetta: la troverà %s.":
			"The letter is in the box: %s will find it.",
	"La lettera è partita per il Grande Prato. Stasera il fiore di %s sarà acceso.":
			"The letter has gone to the Great Meadow. Tonight %s's flower will be lit.",
	"Basso": "Low",
	"Alto": "High",

	# ---------------------------------------------------------- le Tasche
	"✿   Le tasche   ✿": "✿   Pockets   ✿",
	"Dispensa": "Pantry",
	"orto e bosco": "patch and woods",
	"Cucina": "Kitchen",
	"porzioni avanzate": "leftover helpings",
	"Tesori": "Treasures",
	"doni del bosco": "gifts from the woods",
	"Collezione": "Collection",
	"in mostra": "on show",

	# gli ingredienti in dispensa (la scheda che si legge nel taccuino)
	"Carota": "Carrot",
	"Croccante e dolce. La base di zuppe che scaldano.":
			"Crisp and sweet. The making of soups that warm you.",
	"Zucca": "Pumpkin",
	"Panciuta e vellutata. Il cuore dell'autunno.":
			"Round-bellied and velvety. The heart of autumn.",
	"Bacche": "Berries",
	"Violacee e succose. Dolci da crumble.":
			"Purple and juicy. Sweet enough for a crumble.",
	"Funghi": "Mushrooms",
	"Profumo di sottobosco. Perfetti nel risotto.":
			"They smell of the undergrowth. Perfect in a risotto.",
	"Porcini": "Porcini mushrooms",
	"Il tesoro del sottobosco d'autunno. Il mercante lo paga bene.":
			"The treasure of the autumn undergrowth. The pedlar pays well for it.",
	"dall'orto": "from the patch",
	"dai cespugli": "from the bushes",
	"dal bosco": "from the woods",
	"dal bosco, d'autunno": "from the woods, in autumn",

	# le etichette di gusto
	"Caldo": "Warm",
	"Fresco": "Fresh",
	"Dolce": "Sweet",
	"Terroso": "Earthy",
	"Morbido": "Soft",
	"Floreale": "Flowery",
	"Bosco": "Woods",

	# le pagine, la vetrina e i suggerimenti
	"porzione avanzata": "leftover helping",
	"Ancora profumata. Un amico ne sarebbe felice.":
			"Still fragrant. A friend would be glad of it.",
	"mai vista": "never seen",
	"nella Libreria": "on the bookcase",
	"già incontrata": "already met",
	"In un barattolo sullo scaffale. Nessuna fretta.":
			"In a jar on the shelf. No hurry at all.",
	"Le tasche sono leggere:\nl'orto e il bosco ti aspettano.":
			"Your pockets are light:\nthe patch and the woods are waiting.",
	"ne hai %d": "you have %d",
	"un amico": "a friend",
	"Regala a": "A gift for",
	"♨ ama il calduccio": "♨ loves the warmth",
	"✿ ama l'orto": "✿ loves the garden",
	"E — regala (la adorerà! ♥)": "E — give (they'll adore it! ♥)",
	"E — regala": "E — give",
	"Cucina al camino per usarla": "Cook it at the fireplace",
	"Avvicìnati a un amico per regalarlo": "Step up to a friend to give it",
	"In mostra sugli scaffali": "On show on the shelves",
	"Là fuori, da qualche parte…": "Out there, somewhere…",
	"Portala al camino: E apre il ricettario.":
			"Take it to the fireplace: E opens the recipe book.",
	"Avvicìnati a un amico e riapri le tasche per regalarlo.":
			"Step up to a friend and open your Pockets again to give it.",
	"È già in mostra sugli scaffali della Libreria.":
			"It's already on show on the bookcase shelves.",
	"Il tuo amico si è allontanato…": "Your friend has wandered off…",
	"regala a %s": "give to %s",
	"usa / cucina": "use / cook",
	"1–4 pagine   ·   ↑↓←→ scorri   ·   E %s   ·   Tab chiudi":
			"1–4 pages   ·   ↑↓←→ browse   ·   E %s   ·   Tab close",

	# ---------------------------------------------------- i tesori del bosco
	"bacca lucida": "glossy berry",
	"Lucida come una gemma. Troppo bella da mangiare.":
			"Glossy as a gem. Far too pretty to eat.",
	"funghetto profumato": "sweet-smelling toadstool",
	"Un profumo che sa di pioggia e di muschio.": "A smell of rain and moss.",
	"foglia a cuore": "heart-shaped leaf",
	"La natura l'ha piegata a forma di cuore.": "Nature folded it into a heart.",
	"piuma morbidissima": "softest little feather",
	"Leggera come un soffio. Fa il solletico.": "Light as a breath. It tickles.",
	"semino raro": "rare little seed",
	"Piantalo su un prato libero (E): in una stagione\ndiventa un melo o un pero.":
			"Plant it on open meadow (E): in one season\nit becomes an apple or a pear tree.",
	"fiocco di lana": "tuft of wool",
	"Soffice e caldo. Chi ama il focolare lo adora.":
			"Soft and warm. Anyone who loves the hearth adores it.",
	"conchiglia di fiume": "river shell",
	"Accostala all'orecchio: dentro c'è ancora la cascata.":
			"Hold it to your ear: the waterfall is still inside.",
	"campanella di coccio": "little clay bell",
	"Chissà chi la perse. Suona ancora, un po' stonata.":
			"Who knows who lost it. It still rings, a little out of tune.",
	"dono del riccio": "a gift from the hedgehog",
	"dono del passerotto": "a gift from the sparrow",
	"da oltre la cascata": "from beyond the waterfall",
	"dissotterrata nel prato": "dug up in the meadow",

	# ------------------------------------- i reperti della Stratigrafia
	# Le schede nuove di Inventory.TREASURES (name/src/desc): il guardiano
	# dei letterali NON le vede (passano da L10n.t su una variabile), la
	# rete è il giro _test_lingua_reperti di test_strati più la disciplina.
	# I nomi vengono dal progetto della Stratigrafia; le desc delle sette
	# schede del mestiere sono qui per intero, le altre arrivano con le
	# loro schede.
	"scheggia di casa": "splinter of home",
	"sassolino lucido": "shiny little pebble",
	"foglietto di note": "slip of notes",
	"funghetto di legno": "little wooden mushroom",
	"farfallina di carta": "little paper butterfly",
	"nastrino da ballo": "dancing ribbon",
	"cuscinetto ricamato": "little embroidered cushion",
	"cucchiaino di legno": "little wooden spoon",
	"tazzina sbeccata": "chipped little cup",
	"campanellino": "tiny bell",
	"guscio di nocciola": "hazelnut shell",
	"stellina di latta": "little tin star",
	"gomitolino": "tiny ball of yarn",
	"cuoricino di legno": "little wooden heart",
	"bottone di legno": "wooden button",
	"petalo pressato": "pressed petal",
	"spiga dorata": "golden ear of wheat",
	"foglia d'oro": "golden leaf",
	"fiocco intatto": "unmelted snowflake",
	"truciolo riccio": "curly wood shaving",
	"sacchettino di semi": "little bag of seeds",
	"lanternina spenta": "little spent lantern",
	"mappina piegata": "little folded map",
	"pennellino consumato": "worn little paintbrush",
	"fischietto di canna": "little reed whistle",
	"barattolino di briciole": "little jar of crumbs",
	"dissotterrato nel prato": "dug up in the meadow",
	"lasciato da chi è partito": "left behind by someone who moved on",
	"lasciata da chi è partito": "left behind by someone who moved on",
	"Arricciato come un ricciolo.\nQualcuno faceva cantare la sega.":
			"Curled like a lock of hair.\nSomeone made the saw sing.",
	"Legato con cura. Qualcuno pensava\ngià alla primavera dopo.":
			"Tied with care. Someone was already\nthinking of the spring to come.",
	"Spenta da un pezzo. Vegliava sul sonno\ndegli altri, una notte per volta.":
			"Long since gone out. It kept watch over\nthe sleep of others, one night at a time.",
	"Piegata in otto. I posti belli\nhanno una crocetta.":
			"Folded in eight. The lovely places\nare marked with a little cross.",
	"Consumato fino al manico. Il villaggio\nera più bello dove passava.":
			"Worn down to the handle. The village\nwas lovelier wherever it went.",
	"Soffiaci piano: risponde ancora.": "Blow softly: it still answers.",
	"Due briciole rimaste. Qualcuno teneva\nsempre qualcosa per dopo.":
			"Two crumbs left. Someone always kept\na little something for later.",
	# …e le desc delle altre diciannove schede (Inventory.TREASURES,
	# la Stratigrafia): a-capo conservati, sono l'impaginazione della
	# scheda nelle Tasche.
	"Un pezzetto di qualcosa che c'era.\nLa terra non dimentica le case.":
			"A little piece of something that stood here.\nThe earth does not forget its homes.",
	"Scelto fra mille sassi uguali.\nPer qualcuno era quello giusto.":
			"Chosen from a thousand pebbles alike.\nTo someone, it was the right one.",
	"Le note sono sbiadite, ma la luna\nse le ricorda tutte.":
			"The notes have faded, but the moon\nremembers every one.",
	"Intagliato con pazienza. Forse\nascoltava meglio dei funghi veri.":
			"Patiently carved. Perhaps it listened\nbetter than the real mushrooms did.",
	"Piegata con cura: una farfalla\nche non fa paura a nessuno.":
			"Folded with care: a butterfly\nthat frightens no one at all.",
	"Consumato da mille giravolte.\nLa musica c'è ancora, dentro.":
			"Worn thin by a thousand twirls.\nThe music is still in there.",
	"Ancora morbido. Buono per un\npisolino in qualunque posto.":
			"Still soft. Just right for a nap\nin any old place.",
	"Consumato ai bordi da mille\nassaggi. Sa ancora di minestra.":
			"Worn at the edges by a thousand\ntastings. It still smells of soup.",
	"Sbeccata da un pezzo. Era quella\ndel primo sole del mattino.":
			"Chipped long ago. It was the one\nfor the first sun of the morning.",
	"Non sta mai zitto. Qualcuno\nchiacchierava anche col vento.":
			"It never stays quiet. Someone\nchatted even with the wind.",
	"Una casa piccola piccola.\nCi si sta solo se si è timidi.":
			"The littlest of homes. Only\nthe shy can fit inside.",
	"Un po' ammaccata. Chi sogna\nse le costruisce da sé, le stelle.":
			"A bit dented. Dreamers build\ntheir stars themselves.",
	"Avvolto stretto stretto.\nNeanche un filo fuori posto.":
			"Wound tight and true.\nNot a single thread out of place.",
	"Intagliato di nascosto. Brontolava,\nma intanto intagliava cuori.":
			"Carved in secret. All that grumbling,\nand still they carved little hearts.",
	"Caldo in mano. Di chi fosse\nnon si sa: lo teneva stretto.":
			"Warm in the hand. Whose it was,\nno one knows: they held it tight.",
	"Sa ancora di primavera.\nLa terra l'ha tenuto piatto e vivo.":
			"It still smells of spring.\nThe earth kept it flat and alive.",
	"Piegata dal sole d'estate.\nD'inverno scalda solo a guardarla.":
			"Bent by the summer sun.\nIn winter it warms you just to look.",
	"Scesa piano piano, un autunno.\nLa terra l'ha presa al volo.":
			"It drifted slowly down, one autumn.\nThe earth caught it mid-air.",
	"Non si è mai sciolto. L'inverno\ngli ha voluto bene fino in fondo.":
			"It never melted. Winter loved it\nright to the very end.",

	# ------------------------------------------- il carretto del mercante
	"Il carretto del mercante": "The pedlar's cart",
	"Vendi": "Sell",
	"Compra": "Buy",
	"E o Esc — chiudi il carretto": "E or Esc — close the cart",
	"La bisaccia è vuota.\nAcchiappa farfalle e pesci, coltiva l'orto,\npoi torna a vendere!":
			"Your satchel is empty.\nCatch butterflies and fish, tend the patch,\nthen come back to sell!",
	"La tua bisaccia": "Your satchel",
	"Vendendo tutto: %d noccioline": "The lot would fetch: %d acorns",
	"cad.": "each",
	"Vendi 1": "Sell 1",
	"Tutti": "All",
	"Mobili nuovi": "New furniture",
	"Hai già tutti i mobili del carretto!": "You already have every piece on the cart!",
	"Il banco di oggi è già spoglio: alla prossima visita\nil mercante porterà altra merce.":
			"Today's stall is bare already: next time round\nthe pedlar will bring other wares.",
	"Il raro del giorno": "The rare find of the day",
	"Sul carretto oggi": "On the cart today",
	"Colori dei mobili": "Furniture colours",
	"Hai già tutti i colori!": "You already have every colour!",
	"I colori tingono i mobili: in costruzione scegli la tinta dai campioni.":
			"Colours tint the furniture: in build mode pick the shade from the swatches.",

	# le didascalie della merce
	"Un nido dipinto su un palo: i passeri ci passano a salutare.":
			"A painted nest on a pole: the sparrows drop by to say hello.",
	# le tre fioriere del banco: «harebell» è la campanula britannica,
	# «yarrow» l'achillea. Gli a capo sono l'impaginazione del cartellino
	# e vanno conservati.
	"Un cesto di vimini intrecciato a mano, colmo di fiori di campo:\nmargherite, campanule che pendono e achillea.":
			"A hand-woven wicker basket brimming with wild flowers:\ndaisies, nodding harebells and yarrow.",
	"Avorio laccato e verde salvia, coi gerani in mazzo:\nquella dei caffè coi tavolini fuori.":
			"Lacquered ivory and sage green, with geraniums in clusters:\nthe one from cafés with tables outside.",
	"Una cassa rustica che il prato si è ripreso:\nerba alta, fiori misti e l'edera che scende.":
			"A rustic box the meadow has taken back:\nlong grass, mixed blooms and ivy tumbling over.",
	"Un lampione da giardino: la sera si accende di miele.":
			"A garden lamppost: come evening it lights up honey-warm.",
	"Un'amaca a righe tra due paletti. Per i pomeriggi lenti.":
			"A striped hammock between two posts. For slow afternoons.",
	"Un'altalena di corda e legno che dondola nel vento.":
			"A swing of rope and wood that sways in the wind.",
	"Una fontanella tonda con lo zampillo che canta.":
			"A small round fountain with a jet that sings.",
	"Un gazebo esagonale col tetto a pagoda: il salotto all'aperto.":
			"A six-sided gazebo with a pagoda roof: the parlour out of doors.",
	"Il banchetto di Mochi: esponi tre tesori col tuo\nprezzo, e chi passa compra ciò che il cuore gli dice.":
			"Mochi's own stall: set out three treasures at your\nown price, and passers-by buy what their heart says.",
	"Due pali, una corda e le mollette: il bucato che\nondeggia al sole è il respiro del villaggio.":
			"Two posts, a line and some pegs: washing swaying\nin the sun is the village breathing.",
	"Una piccola giostra a cavallucci. Gira piano, come un carillon.":
			"A little carousel of hobby horses. It turns slowly, like a music box.",
	"Un braciere che sputa scintille dorate nella notte.":
			"A brazier that spits golden sparks into the night.",
	"Una scatola di ciliegio con la manovella: caricala\ne cambia la musica di tutto il villaggio.":
			"A cherrywood box with a crank: wind it up\nand the whole village changes its tune.",
	# la vetrina del banco dei pali: è QUI che il gioco spiega la
	# meccanica, quindi la traduzione deve insegnarla, non solo dirla
	"Paletti da piantare dove vuoi. Fra due che si vedono\nil filo si tende da solo: più lontani li metti, più\nlampadine ci stanno. Il disegno lo fai tu.":
		"Little posts to plant wherever you like. Between any two\nthat can see each other the wire strings itself: the\nfurther apart, the more bulbs. The pattern is yours.",
	"Un giardino di vetro: col suo tepore, orto e fiori\ncrescono anche sotto la neve.":
			"A garden of glass: in its warmth, patch and flowers\ngrow even under the snow.",
	"Una mongolfiera a strisce, ormeggiata in giardino.\nDondola nel vento e non parte mai senza di te.":
			"A striped hot-air balloon, moored in the garden.\nIt sways in the wind and never leaves without you.",

	# i colori comprati al carretto (l'id resta italiano: qui solo l'etichetta)
	"Menta": "Mint",
	"Lavanda": "Lavender",
	"Cielo": "Sky",
	"Pesca": "Peach",
	"Rosa confetto": "Sugared pink",
	"Aurora": "Northern lights",
	"Originale": "Original",

	# ------------------------------------------------------ la costruzione
	# I nomi dei pezzi sono CHIAVI del salvataggio: restano italiani nel dato
	# (BuildCatalog) e si traducono soltanto qui, quando si disegnano.
	"Struttura": "Structure",
	"Arredo": "Furniture",
	"Giardino": "Garden",
	"Pavimento": "Floor",
	"Sentiero": "Path",
	"Tappeto": "Rug",
	"Muro": "Wall",
	"Finestra": "Window",
	"Porta": "Door",
	"Staccionata": "Fence",
	"Tetto": "Roof",
	"Scala": "Stairs",
	"Solaio": "Loft",
	"Ponticello": "Rope bridge",
	"Casa albero": "Treehouse",
	"Tavolino": "Little table",
	"Sedia": "Chair",
	"Sgabello": "Stool",
	"Letto": "Bed",
	"Libreria": "Bookcase",
	"Comodino": "Nightstand",
	"Camino": "Fireplace",
	"Lampada": "Lamp",
	"Lampada semplice": "Plain lamp",
	"Amaca": "Hammock",
	"Braciere stellato": "Starlit brazier",
	"Pianta": "Plant",
	"Aiuola": "Flower bed",
	"Orto": "Vegetable patch",
	"Alberello": "Sapling",
	"Cespuglio": "Shrub",
	"Fungo": "Mushroom",
	"Cassetta posta": "Mailbox",
	"Panchina": "Bench",
	"Lavagna": "Chalkboard",
	"Casetta uccellini": "Birdhouse",
	"Lampione": "Lamppost",
	"Altalena": "Swing",
	"Fontana": "Fountain",
	"Giostrina": "Carousel",
	"Carillon": "Music box",
	"Bancarella": "Stall",
	"Stendino": "Clothesline",
	# --- il posto di guardia: SOLO il nome mostrato. Gli id restano
	# italiani, sono le chiavi di village.json e del corredo ---
	"Il posto di guardia: una casina col lume azzurro sempre\nacceso, e l'armadio dove le cose perse aspettano\nchi le ha perse. Arriva con tutto il suo corredo.":
		"The guard post: a little house with a blue lantern always\nlit, and the cabinet where lost things wait for\nwhoever lost them. It comes with all its furnishings.",
	# --- il bar del paese: SOLO il nome mostrato ---
	"Il bar del paese, tutto intero: il bancone di zinco, la\nmacchina del caffè che sbuffa, i tavolini sotto\nl'ombrellone e il biliardino. Il posto dove ci si trova.":
		"The village café, all of it: the zinc counter, the\ncoffee machine huffing away, the little tables under\nthe parasol and the table football. The place where you meet.",
	"Bancone bar": "Café counter",
	"Tenda bar": "Awning",
	"Insegna bar": "Café sign",
	"Macchina caffè": "Coffee machine",
	"Vetrina dolci": "Pastry case",
	"Sgabello alto": "Bar stool",
	"Mensola bottiglie": "Bottle shelf",
	"Tavolino bar": "Café table",
	"Sedia vimini": "Wicker chair",
	"Lavagnetta": "Little chalkboard",
	"Biliardino": "Table football",
	"Ombrellone": "Parasol",
	# ------------------------------------------- il banco del builder
	# Con centotrentasette pezzi il pannello ha una griglia, una ricerca e
	# la scheda dei recenti: queste sono le sue parole.
	"★ Recenti": "★ Recent",
	"/ per cercare un pezzo": "/ to search for a piece",
	"Dal mercante": "From the pedlar",
	"Arriva col tempo": "Comes in time",
	"Niente da queste parti.": "Nothing over here.",
	"Nessun pezzo con questo nome.": "No piece by that name.",
	"%d di %d": "%d of %d",
	"%d pezzi": "%d pieces",
	"B esci  ·  / cerca  ·  rotella / 1-9 scegli  ·  R ruota  ·  V piano su/giù  ·  F ruota piazzato  ·  clic piazza  ·  X rimuovi":
			"B exit  ·  / search  ·  wheel / 1-9 pick  ·  R rotate  ·  V floor up/down  ·  F turn placed  ·  click to place  ·  X remove",
	# ------------------------------------------------------- L'ATELIER
	# Il banco dei pezzi è diventato uno studio: a sinistra le categorie e
	# i corredi, al centro i ritratti dei pezzi, a destra il taccuino che
	# dice quello che il villaggio ha visto. «Atelier» resta com'è: in
	# inglese vuol dire la stessa cosa (lo studio di chi fa le cose a
	# mano) ed è il NOME del posto, non la sua descrizione.
	"L'Atelier": "The Atelier",
	"Il catalogo": "The catalogue",
	"Tutto il catalogo": "The whole catalogue",
	"I corredi": "The sets",
	"Qui finiscono i pezzi che posi": "This is where the pieces you put down go",
	# l'intestazione dice la GRANDEZZA: le categorie contano il possesso,
	# i corredi contano quel che hai posato — e nella stessa colonna, con
	# la stessa frazione, si leggerebbero come la stessa cosa
	"I corredi — quanti ne hai posati": "The sets — how many you have put down",
	"Il taccuino": "The notebook",
	"cerca un pezzo…": "search for a piece…",
	"Tab — richiudi": "Tab — fold away",
	"Tab — apri": "Tab — open up",
	"Tab — apri l'Atelier": "Tab — open the Atelier",
	# la carta di un pezzo che porterà un Ordine del Gufo: il nome non si
	# dice (la rivelazione è il premio), e sotto il punto interrogativo
	# c'è solo una promessa di tempo
	"un giorno": "one day",
	# il nastrino sulla carta di un compagno di corredo: UNA parola, o non
	# ci sta (il nome del capo può essere lungo il doppio della carta)
	"corredo": "set",
	"clic posa  ·  R gira  ·  V piano  ·  F gira un pezzo posato  ·  X toglie  ·  rotella e 1-9 scelgono  ·  / cerca  ·  Tab richiude  ·  B esce":
			"click to place  ·  R turns  ·  V storey  ·  F turns a placed piece  ·  X removes  ·  wheel and 1-9 choose  ·  / search  ·  Tab folds away  ·  B leaves",
	# --- il taccuino: quello che il villaggio ha visto (Consigli.gd).
	# Nessuna di queste frasi mette fretta e nessuna accusa nessuno: dicono
	# cosa c'è, mai cosa manca. In inglese vale doppio — «you still need»
	# sarebbe una lista di cose da fare, e questo è un gioco in cui si
	# torna volentieri.
	"Un letto dorme sotto le stelle. Un Tetto sulla sua cella, e qualcuno potrà abitarci.":
			"A bed is sleeping under the stars. A Roof on its cell, and someone will be able to live there.",
	"Ci sono %d letti che dormono sotto le stelle. Basta un Tetto sulla loro cella.":
			"There are %d beds sleeping under the stars. A Roof on their cell is all it takes.",
	"Del corredo di %s hai posato %d pezzi su %d. C'è anche %s, da qualche parte.":
			"Of the %s set you have put down %d pieces out of %d. There is also %s, somewhere.",
	# la sorella al singolare: «1 pieces» e la macchina che si vede
	# attraverso, e capita al PRIMO pezzo di ogni corredo
	"Del corredo di %s hai posato un pezzo su %d. C'è anche %s, da qualche parte.":
			"Of the %s set you have put down one piece out of %d. There is also %s, somewhere.",
	# il FATTO col suo campione, mai l'inferenza: «nearly always» il
	# giocatore la puo smentire, «three times out of four» no
	"%s e %s: li hai messi insieme %d volte su %d.":
			"%s and %s: you have put them together %d times out of %d.",
	"Hai da parte abbastanza per %s: %d %s.":
			"You have enough put by for %s: %d %s.",
	# ⚠️ L'ORDINE DEI SEGNAPOSTO È QUELLO DELL'ITALIANO: gli argomenti
	# arrivano gia in fila da `L10n.tf`, e girarli qui stampa una frase con
	# i pezzi al posto sbagliato. E niente articolo davanti a un nome di
	# catalogo: «a Armchair» e il secondo modo di sbagliare la stessa riga.
	"Ancora %d %s, e %s ti aspetta al carretto.":
			"Another %d %s, and %s is waiting at the pedlar's cart.",
	# la sorella per quando quel pezzo NON è sul banco di oggi: si dice la
	# provenienza, che è vera sempre, invece della presenza, che il
	# mercante smentisce cinque giorni su sei
	"Ancora %d %s per %s, dal carretto del mercante.":
			"Another %d %s for %s, from the pedlar's cart.",
	"Nel villaggio non c'è ancora traccia di %s.":
			"There is not a single %s anywhere in the village yet.",
	"Qui non c'è ancora niente. Un Pavimento è un buon posto da cui cominciare.":
			"There is nothing here yet. A Floor is a good place to begin.",
	"Fioriera": "Planter",
	# le tre sorelle della fioriera: cesto di vimini, cassa da bistrot,
	# e quella che nessuno pota
	"Cesto fiorito": "Flower basket",
	"Fioriera bistrot": "Bistro planter",
	"Fioriera selvatica": "Wild planter",
	"Lucine": "String lights",
	# i tre pali del festone: si piantano e il filo si tende da solo fra
	# quelli che si vedono. «Post» e non «Pole»: è un paletto piantato in
	# giardino, non un palo della luce.
	"Palo lucine": "Bulb post",
	"Palo lanterne": "Lantern post",
	"Palo bandierine": "Bunting post",
	"Frigo gelati": "Ice-cream freezer",
	"Guardiola": "Guard post",
	"Insegna guardia": "Guard post sign",
	"Sbarra": "Barrier",
	"Bancone guardia": "Guard's counter",
	"Armadio smarriti": "Lost property cabinet",
	"Bacheca avvisi": "Notice board",
	"Attaccapanni": "Coat stand",
	"Brandina": "Camp bed",
	"Lanterna blu": "Blue lantern",
	"Cono": "Traffic cone",
	"Transenna": "Barrier fence",
	"Bicicletta": "Bicycle",
	"Cassetta smarriti": "Lost property box",
	# --- la caserma dei pompieri: SOLO il nome mostrato. Come sopra, gli
	# id restano italiani: sono le chiavi di village.json e del corredo ---
	"La caserma dei pompieri, tutta intera: l'autopompa\nlucidata, la campana che chiama in piazza e gli\nstivali in fila. Qui non brucia niente: si tiene pronto.":
		"The whole fire station: the engine polished, the bell\nthat calls everyone to the square, and the boots lined\nup by the door. Nothing burns here — we just stay ready.",
	"Autopompa": "Fire engine",
	"Portone rimessa": "Engine bay door",
	"Torretta": "Watchtower",
	"Palo pompieri": "Fire pole",
	"Scala a pioli": "Ladder",
	"Insegna caserma": "Fire station sign",
	"Campana caserma": "Station bell",
	"Casco appeso": "Helmet and coat",
	"Stivali": "Boots",
	"Secchi": "Red buckets",
	"Idrante": "Hydrant",
	"Manichetta": "Hose reel",
	"Faro caserma": "Beacon",
	"Cuccia": "Dog kennel",
	"Pennone": "Flagpole",
	# --- la chiesa del paese. «Chapel», non «Church»: e la chiesa di un paese
	# di due strade, non una cattedrale. Gli id restano italiani ---
	"Chiesa": "Chapel",
	"La chiesa del paese, tutta intera: la torre che si vede\nda ogni prato, le vetrate che accendono il pavimento, e\nil lume che si accende per chi è partito.":
		"The village chapel, all of it: the tower you can see\nfrom every meadow, the windows that light up the floor,\nand the lamp lit for whoever has gone.",
	"Campanile": "Bell tower",
	"Muro di pietra": "Stone wall",
	"Lastricato": "Flagstones",
	"Vetrata": "Stained glass",
	"Banco": "Pew",
	"Volta": "Ribbed vault",
	"Sagrato": "Church steps",
	"Arcata": "Stone arch",
	"Portale": "Church door",
	"Frontone": "Rose gable",
	"Abside": "Apse",
	"Altare": "Altar",
	"Candeliere": "Candle stand",
	"Fonte dei nomi": "Naming font",
	# --- IL PROLOGO. Sono le prime parole del gioco e le piu importanti:
	# tradotte con la stessa cura dell'italiano, non dopo. I puntini di
	# sospensione sono recitazione: si conservano tutti e tre. ---
	"dov'è mamma?... dov'è papà?...": "where's mummy?... where's daddy?...",
	"ho paura... mi sento sola...": "i'm scared... i feel so alone...",
	"cosa? mi vuoi aiutare? perché?": "what? you want to help me? why?",
	"forse con te... Mochi non si sentirà mai più sola?":
		"maybe with you... Mochi will never feel alone again?",
	"Armonium": "Harmonium",
	"Serra": "Greenhouse",

	# ----------------------------------------------------------- la boutique
	# Inglese BRITANNICO, e qui si sente: «fitting room» (non *dressing
	# room*), «clothes rail» (non *rack*), «tailor's dummy» (non *dress
	# form*). Gli id restano italiani: sono le chiavi di village.json e
	# del corredo. E «Stender» in italiano e un anglicismo da negozio —
	# in inglese torna semplicemente la cosa che e.
	# la scheda della categoria: «Clothes shop», non «Boutique» — copiare
	# la parola italiana lascerebbe una voce che finge di essere tradotta
	# (e il guardiano della localizzazione la becca, giustamente)
	"Boutique": "Clothes shop",
	"La boutique del paese, tutta intera: la vetrina che di\nsera illumina la strada, gli stender, i camerini con la\ntenda pesante e lo specchio a tre ante.":
		"The village boutique, all of it: the window that lights\nthe street at dusk, the clothes rails, the fitting rooms\nwith their heavy curtains and the triple mirror.",
	"Vetrina moda": "Shop window",
	"Insegna boutique": "Boutique sign",
	"Manichino": "Mannequin",
	"Busto sartoriale": "Tailor's dummy",
	"Stender": "Clothes rail",
	"Tavolo piegati": "Folding table",
	"Scaffale a giorno": "Open shelving",
	"Camerino": "Fitting room",
	"Specchiera": "Triple mirror",
	"Cassa boutique": "Shop counter",
	"Poltroncina": "Little armchair",
	"Cesto saldi": "Sale basket",
	"Faretti": "Spotlights",
	"Passatoia": "Runner",
	"Sacchetti": "Paper bags",

	# ------------------------------------------------------------ la palestra
	"Palestra": "Gym",
	"Tappetino": "Exercise mat",
	"Panca dei pesi": "Weights bench",
	"Sacco": "Punchbag",
	"Cyclette": "Exercise bike",
	"Sbarra da trazione": "Pull-up bar",
	"Specchio": "Mirror",
	"Fontanella": "Drinking fountain",
	"Rastrelliera": "Weights rack",
	"Rastrelliera dischi": "Plate rack",
	"Rastrelliera pietre": "Stone rack",
	"Mongolfiera": "Hot-air balloon",

	"✕ Demolisci": "✕ Demolish",
	"B esci  ·  rotella / 1-9 scegli  ·  R ruota  ·  V piano su/giù  ·  F ruota piazzato  ·  clic piazza  ·  X rimuovi":
			"B leave  ·  wheel / 1-9 choose  ·  R turn  ·  V storey up/down  ·  F turn a placed piece  ·  click to place  ·  X remove",
	"B — modalità costruzione": "B — build mode",
	"Un Ordine del Gufo lo porterà": "An Owl's Wish will bring it",
	# il compagno di corredo NON lo porta un Ordine: arriva insieme al pezzo
	# capo che si compra al carretto. Il %s è il nome del capo, già tradotto
	# a parte con L10n.t() — qui dentro non va mai ricomposta la frase.
	"Arriva col corredo di %s": "It comes with the %s set",
	"noccioline": "acorns",
	"stelline": "stars",
	"Dal carretto del mercante · %d %s": "From the pedlar's cart · %d %s",
	"Puoi permettertelo!": "You can afford it!",
	"Mettine da parte ancora un po'.": "Put a little more by.",

	# ------------------------------------------------------- il guardaroba
	"~ Il guardaroba di Mochi ~": "~ Mochi's wardrobe ~",
	"ogni capo è un ricordo indossabile": "every piece is a memory you can wear",
	"↑↓ — scegli  ·  E — indossa/togli  ·  G — chiudi":
			"↑↓ — choose  ·  E — wear/take off  ·  G — close",
	"indossato ♥": "worn ♥",
	"nel baule": "in the chest",
	"%s?  un ricordo da vivere: %s": "%s?  a memory still to live: %s",
	"Nuovo capo nel guardaroba: %s! (G per indossarlo)":
			"Something new in the wardrobe: %s! (G to put it on)",
	"il ricordino di %s": "the keepsake of %s",
	"Nel guardaroba c'è il ricordino di %s, piegato con cura. (G)":
			"In the wardrobe there's the keepsake of %s, folded with care. (G)",

	"il cappello di petali": "the petal hat",
	"la prima fioritura del giardino": "the garden's first bloom",
	"la lanterna-lucciola da polso": "the firefly lantern for your wrist",
	"una lucciola in collezione": "a firefly in the collection",
	"la sciarpina di lana": "the little woollen scarf",
	"un regalino del passerotto": "a small gift from the sparrow",
	"l'impermeabilino giallo": "the little yellow raincoat",
	"la prima pioggerella vissuta": "living through your first drizzle",
	"il fiocco di ciliegio": "the cherry-blossom bow",
	"vivere un'alba di primavera": "living a spring dawn",
	"gli occhialini da sole": "the little sunglasses",
	"vivere un'alba d'estate": "living a summer dawn",
	"la mantellina di foglie": "the little cloak of leaves",
	"vivere un'alba d'autunno": "living an autumn dawn",
	"la cuffietta di neve": "the snow bonnet",
	"vivere un'alba d'inverno": "living a winter dawn",
	"il cerchietto di stelle": "the circlet of stars",
	"battezzare la prima costellazione": "naming your first constellation",
	"il cappellino di festa": "the party hat",
	"la prima festa a sorpresa": "the first surprise party",
	"il campanellino d'argento": "the little silver bell",
	"l'amicizia piena con un gattino": "full friendship with a kitten",
	"la carotina portafortuna": "the lucky little carrot",
	"l'amicizia piena con una coniglietta": "full friendship with a bunny",
	"il vasetto di miele": "the little pot of honey",
	"l'amicizia piena con un orsetto": "full friendship with a bear cub",
	"la coda-sciarpa fulva": "the russet tail-scarf",
	"l'amicizia piena con una volpina": "full friendship with a little fox",
	"il berretto con le orecchie": "the cap with ears",
	"l'amicizia piena con un topolino": "full friendship with a little mouse",

	# ------------------------------------------------- l'amico in visita
	"%s si siede accanto a te! (IJKL muove · U aiuta in giardino · F2 saluta)":
			"%s sits down beside you! (IJKL to move · U to help in the garden · F2 to wave)",
	"%s ti saluta con la zampina. A presto!": "%s waves a little paw at you. See you soon!",
	"U — %s aiuta in giardino": "U — %s helps in the garden",
	"l'amico": "your friend",

	# ------------------------------------------------- la bancarella di Mochi
	"La bancarella di Mochi": "Mochi's stall",
	"tre tesori in vetrina, al prezzo che dici tu":
			"three treasures on show, at the price you say",
	"↑↓ piedistallo · ←→ merce · SPAZIO cartellino · E chiudi":
			"↑↓ stand · ←→ wares · SPACE price tag · E close",
	"E — sistema la bancarella": "E — set out the stall",
	"E — sistema la bancarella (%d in vendita)": "E — set out the stall (%d for sale)",
	"— piedistallo vuoto —": "— empty stand —",
	"(finita!)": "(all gone!)",
	"economico": "a bargain",
	"giusto": "fair",
	"caro": "dear",
	"carissimo": "very dear",
	"un vicino": "a neighbour",
	"%s ha comprato %s: +%d 🌰 alla bancarella!":
			"%s has bought %s: +%d 🌰 at the stall!",

	# ------------------------------------------------------------ le stelle
	"E — sdraiati a guardare le stelle": "E — lie down and watch the stars",
	"clic — unisci le stelle  ·  destro — annulla  ·  E — dai il nome":
			"click — join the stars  ·  right — undo  ·  E — give it a name",
	"clic — unisci le stelle (%d/3)  ·  E — torna giù":
			"click — join the stars (%d/3)  ·  E — get up again",
	"SPAZIO — esprimi un desiderio!": "SPACE — make a wish!",
	"Hai espresso un desiderio… la stella l'ha sentito.":
			"You made a wish… and the star heard it.",
	"Come si chiama la tua costellazione?": "What is your constellation called?",
	"Costellazione %d": "Constellation %d",
	"Invio — battezzala": "Enter — name it",
	"«%s» brilla nel cielo, da stanotte e per sempre.":
			"«%s» shines in the sky, from tonight and for always.",
	"✨ %s adesso abita lassù: guarda il cielo, stanotte.":
			"✨ %s lives up there now: look at the sky tonight.",
	"La stella cadente": "The shooting star",
	"Quella notte ti ho sentito, sai?\nI desideri sussurrati nell'erba\narrivano sempre, prima o poi.":
			"I heard you that night, you know.\nWishes whispered in the grass\nalways arrive, sooner or later.",

	# ------------------------------------------------- gli anelli dell'albero
	"E — gli anelli del Grande Albero": "E — the rings of the Great Tree",
	"~ Gli anelli del Grande Albero ~": "~ The rings of the Great Tree ~",
	"E — chiudi": "E — close",
	"Il legno è ancora giovane e liscio.\nGli anelli aspettano la vostra storia.":
			"The wood is still young and smooth.\nThe rings are waiting for your story.",
	"Giorno %d   %s  %s": "Day %d   %s  %s",
	"è nata una casa sull'albero": "a treehouse was born",

	# -------------------------------------------------- il proiettore dei ricordi
	"~ I ricordi del villaggio ~": "~ The village remembers ~",
	"E — chiudi il proiettore": "E — close the projector",
	"Il proiettore aspetta almeno due mattine di ricordi…":
			"The projector needs at least two mornings of memories…",
	"Giorno %d": "Day %d",
	"…e la storia continua": "…and the story goes on",

	# ------------------------------------------------------- i sogni di foto
	"io e te accanto al falò": "you and me by the campfire",
	"io e te in riva allo stagno": "you and me at the edge of the pond",
	"io e te sotto il Grande Albero": "you and me under the Great Tree",
	"io e te sotto le stelle, davanti a casa mia":
			"you and me under the stars, outside my house",
	"l'arcobaleno, visto dal ponte del fiume": "the rainbow, seen from the river bridge",
	"%s sogna una foto: «%s»  (P per la Modalità Foto)":
			"%s is dreaming of a photo: «%s»  (P for Photo Mode)",
	"Il sogno di %s: «%s»": "%s is dreaming of: «%s»",
	"Inquadratura perfetta — scatta!": "The frame is perfect — take it!",
	"aspetta la sera: il sogno vuole le stelle":
			"wait for the evening: the dream wants stars",
	"serve un arcobaleno nel cielo (dopo la pioggia)":
			"a rainbow is needed in the sky (after the rain)",
	"il sognatore non è ancora sul posto": "the dreamer isn't at the spot yet",
	"troppo lontano: avvicìnati col volo": "too far off: fly in closer",
	"troppo vicino: un passo indietro": "too close: a step back",
	"il sognatore è fuori dall'inquadratura": "the dreamer is out of frame",
	"inquadra anche il posto del sogno": "frame the place of the dream too",
	"mettiti in posa anche tu, lì vicino": "get into the picture yourself, just there",
	"anche Mochi va nel quadro": "Mochi belongs in the picture too",
	"nessun sogno in corso": "no dream in the air",
	"il sognatore non c'è": "the dreamer isn't here",
	"niente camera": "no camera",
	"La foto che sognavo — %s!\nL'ho appesa sopra il letto: la guardo ogni sera.\nGrazie, con tutto il cuore.":
			"The photo I dreamed of — %s!\nI've hung it over my bed: I look at it every evening.\nThank you, with all my heart.",
	"Il sogno di %s si è avverato: la foto è appesa in casa sua!":
			"%s's dream has come true: the photo is hanging in their house!",

	# ---- Le tabelle DATI (i desideri del Gufo, il negozio). Il guardiano
	# della localizzazione cerca i letterali dentro L10n.t(): questo testo
	# arriva da una tabella e gli sfuggiva, uscendo INTERO in italiano.
	"Il salone di chi lo sogna":
			"The salon of the one who dreams it",
	"C'è una cosa che ho notato dal ramo alto.\nQualcuno, in paese, guarda gli altri e pensa\n«come starebbe bene, con un altro colore».\nNon glielo ha mai detto a nessuno.\nTi mando il progetto di un salone: lo specchio,\nla poltrona, il carrello dei colori. Costruiscilo,\ne poi dagli l'incarico: vedrai cosa sa fare.":
			"There is something I have noticed from the high branch.\nSomeone in the village looks at the others and thinks\n\"how well they would suit another colour\".\nThey have never said so to a soul.\nI am sending you the plans for a salon: the mirror,\nthe chair, the trolley of colours. Build it,\nand then give them the post: you will see what they can do.",
	"accogli qualcuno che sogna di fare l'estetista":
			"take in someone who dreams of being a stylist",
	"Ecco il progetto. Ora il villaggio ha un posto dove ci si guarda allo specchio insieme.":
			"Here are the plans. Now the village has a place where we look in the mirror together.",
	"Il posto dove si ascolta":
			"The place where one listens",
	"Ce n'è uno, in paese, che tamburella sempre.\nSul tavolo, sul recinto, sul manico della zappa.\nNon ha un posto dove farlo sul serio.\nTi mando il progetto di un anfiteatro: il tavolato,\nla conchiglia che rimanda la voce, le gradinate\ne un pianoforte a coda. Costruiscilo grande.\nPoi dagli l'incarico, e siediti anche tu.":
			"There is one, in the village, who is always drumming.\nOn the table, on the fence, on the handle of the hoe.\nThey have nowhere to do it properly.\nI am sending you the plans for an amphitheatre: the boards,\nthe shell that carries the voice, the stone tiers\nand a grand piano. Build it big.\nThen give them the post, and sit down yourself.",
	"accogli qualcuno che sogna di fare l'artista":
			"take in someone who dreams of being an artist",
	"Ecco il progetto. Da stasera il villaggio ha un posto dove ci si siede tutti insieme al buio.":
			"Here are the plans. From tonight the village has a place where we all sit together in the dark.",
	"Salone":
			"Salon",
	"Palco":
			"Stage",
	"Fondale":
			"Shell",
	"Gradinata":
			"Tier",
	"Pianoforte":
			"Piano",
	"Un sacco da farina rattoppato, appeso a un braccio di legno.\nCol sacco arriva tutta la palestra del villaggio: il\ntappetino, la panca, la sbarra, e la botte dell'acqua.":
			"A patched flour sack, hung from a wooden arm.\nWith the sack comes the whole village gym: the\nmat, the bench, the bar, and the water barrel.",
	"Specchio ovale, poltrona col pistone e carrello dei\ncolori: chi ci si siede se ne va diverso.":
			"An oval mirror, a chair on a piston and a trolley of\ncolours: whoever sits down leaves looking different.",
	"Un tavolato d'assi chiare. Posane quanti ne vuoi:\nil palco e' grande quanto lo fai tu.":
			"A deck of pale boards. Lay down as many as you like:\nthe stage is as big as you make it.",
	"La conchiglia acustica: rimanda la voce a chi\nascolta, e di sera si accende ai due lati.":
			"The acoustic shell: it carries the voice out to the\nlisteners, and at dusk it lights up on both sides.",
	"Due file di pietra per sedersi davanti al palco.\nAffiancane quante ne servono: e' la platea.":
			"Two stone rows to sit on, facing the stage.\nSet as many side by side as you need: that is the audience.",
	"A coda, col coperchio aperto. Chi sogna di fare\nl'artista non aspetta altro.":
			"A grand, with the lid up. Whoever dreams of being\nan artist wants nothing else.",
	# la sbornia di succo di mela, al bancone del bar
	"E — un succo di mela (%d 🌰)": "E — an apple juice (%d 🌰)",
	"Servono %d 🌰 per un succo.": "You need %d 🌰 for a juice.",
	"Il succo di mela scende che è un piacere.":
			"The apple juice goes down a treat.",
	"Il pavimento ondeggia. Colpa del pavimento, sicuro.":
			"The floor is swaying. Definitely the floor's fault.",
	"Da quando i banconi sono due?": "Since when are there two counters?",
	"Il mondo sembra disegnato col mouse.":
			"The world looks like it was drawn with a mouse.",
	# ------------------------------------------------------- le note legali
	# La pagina che porta gli avvisi di licenza dei componenti di terze parti
	# (obbligo MIT) e i documenti di Gemma — che il gioco NON spedisce: chi
	# accende la funzione se lo scarica, e scaricandolo si vincola ai Gemma
	# Terms of Use. Questa pagina e la schermata dello scaricamento sono gli
	# unici posti in cui glieli mostra qualcuno.
	# ⚠️ QUI SI TRADUCE PER FARSI CAPIRE, NON PER FARE BELLA
	# FIGURA: se una di queste righe diventa vaga, l'avviso non è più un
	# avviso. I NOMI PROPRI non si toccano — «Gemma Terms of Use» e «Gemma
	# Prohibited Use Policy» sono i titoli dei documenti veri, e chi li cerca
	# li cerca così anche in italiano.
	"Note legali": "Legal notices",
	"Licenze dei componenti di terze parti": "Third-party licences",
	"Gemma — che cosa scarichi": "Gemma — what you download",
	"Chibi Crossing è un'opera protetta: il codice, i disegni, la musica e i testi sono di chi l'ha fatto. Quello che segue, invece, non è nostro — e viaggia con le sue condizioni.":
			"Chibi Crossing is a protected work: the code, the drawings, the music and the writing belong to the people who made it. What follows, though, is not ours — and it travels with conditions of its own.",
	"Il motore e le librerie": "The engine and the libraries",
	"Godot Engine, godot-cpp, EnTT, lua-gdextension: licenza MIT.":
			"Godot Engine, godot-cpp, EnTT, lua-gdextension: MIT licence.",
	"Una parte dei testi che leggi — certe lettere, certi pensieri dei vicini — la può scrivere un modello linguistico che gira sul tuo computer, mentre giochi. Il modello non è dentro il gioco: se accendi «Il villaggio pensa», il gioco lo scarica una volta sola (%s, da %s). Dopo, non esce più niente da questa macchina: il testo nasce qui e resta qui. E se non lo accendi, il gioco non apre nessuna connessione per lui — il villaggio resta lo stesso, con i testi scritti a mano.":
			"Some of the writing you read — certain letters, certain thoughts of the neighbours — can be written by a language model running on your own computer, while you play. The model is not inside the game: if you switch on “The village thinks”, the game downloads it just once (%s, from %s). After that, nothing leaves this machine: the writing is born here and stays here. And if you never switch it on, the game opens no connection for it — the village is the same village, with the writing done by hand.",
	"Il motore che lo fa girare": "The engine that runs it",
	"llama.cpp e ggml: licenza MIT.": "llama.cpp and ggml: MIT licence.",
	"Il modello che il gioco può scaricare per te. Non è nostro e non è MIT: valgono i Gemma Terms of Use di Google, e i vincoli d'uso di quei termini valgono anche per te. Il gioco te li mostra, e ti chiede di accettarli, prima di scaricare qualunque cosa.":
			"The model the game can download for you. It is not ours and it is not MIT: Google's Gemma Terms of Use apply, and the use restrictions in those terms apply to you as well. The game shows them to you, and asks you to accept them, before it downloads anything.",
	"Leggi il testo": "Read the text",
	"Leggi i Gemma Terms of Use": "Read the Gemma Terms of Use",
	"Leggi la Prohibited Use Policy": "Read the Prohibited Use Policy",
	"Gemma e Google sono marchi di Google LLC. Chibi Crossing non è affiliato a Google, né approvato da Google.":
			"Gemma and Google are trademarks of Google LLC. Chibi Crossing is not affiliated with, nor endorsed by, Google.",
	"I testi completi delle licenze sono nella cartella «%s», accanto al gioco.":
			"The full licence texts are in the “%s” folder, next to the game.",

	# --- LA SCHERMATA CHE CHIEDE (scenes/ui/OffertaModello.gd) --------------
	# Il modello non viaggia più nel pacchetto: si scarica al primo uso, e
	# questa è la pagina che lo chiede. Il giocatore la vede UNA VOLTA SOLA:
	# è lei a decidere se userà mai la funzione.
	#
	# ⚠️ IL TONO È METÀ DEL LAVORO, e in inglese si perde più facilmente che
	# altrove: la lingua dei download tira verso il commerciale («Unlock!»,
	# «Get the full experience»), e questa pagina non ha il permesso di
	# spingere. Frasi corte, verbi concreti, nessun esclamativo, e il rifiuto
	# scritto con la stessa cura del sì. Dove l'italiano dice «non cambia
	# niente», l'inglese dice «nothing changes» e non «you won't miss much»:
	# la seconda è una rassicurazione, la prima è un fatto.
	"Ogni tanto un vicino si accorge di qualcosa, ci pensa su, e più tardi fa una cosa che nessuno gli ha chiesto di fare. A scrivere quei pensieri è un piccolo modello di linguaggio, che gira qui — sul tuo computer, mentre giochi.":
			"Every so often a neighbour notices something, turns it over for a while, and later goes and does something nobody asked them to do. Those thoughts are written by a small language model that runs here — on your own computer, while you play.",
	"Dentro il gioco non c'è: ne raddoppierebbe il peso, e se lo porterebbe appresso anche chi non lo vorrà mai. Se lo vuoi, si scarica una volta sola.":
			"It isn't inside the game: it would double the size, and everyone who never wants it would be carrying it about all the same. If you'd like it, it comes down just the once.",
	# La scheda dei fatti. Etichette corte, allineate a sinistra: sono una
	# colonna, non frasi.
	"Che cos'è": "What it is",
	"Quanto pesa": "How big",
	"Da dove": "Where from",
	"Quante volte": "How often",
	"una sola: poi resta sul tuo disco": "just the once: then it stays on your disk",
	"Quanto ci mette": "How long",
	"su una linea di casa, minuti — a volte una mezz'ora":
			"on a home line, minutes — sometimes half an hour",
	"Mentre arriva, il tuo indirizzo si vede da Hugging Face e dalla rete che consegna il file — come per qualunque cosa si scarichi. Dal gioco non parte niente, né adesso né dopo: quello che i vicini pensano nasce su questa macchina e resta qui.":
			"While it comes down, your address is visible to Hugging Face and to the network that delivers the file — as it is for anything you download. Nothing leaves the game, neither now nor later: what the neighbours think is born on this machine and stays here.",
	"Il modello è di Google, e viaggia con le sue condizioni: scaricandolo le accetti. Restano leggibili per sempre da Impostazioni → Note legali.":
			"The model is Google's, and it travels with Google's conditions: by downloading it you accept them. They stay readable for good under Settings → Legal notices.",
	# L'ATTO. «I am old enough to do so» e non «I confirm I am of age»: chi
	# accetta sta dando una dichiarazione (Sezione 2.1 dell'accordo), e una
	# dichiarazione si scrive in prima persona e in parole di tutti i giorni.
	"Accetto i Gemma Terms of Use e la Prohibited Use Policy, e ho l'età per farlo.":
			"I accept the Gemma Terms of Use and the Prohibited Use Policy, and I am old enough to do so.",
	"Se dici di no non cambia niente: il villaggio è già scritto a mano, e resta come lo conosci.":
			"If you say no, nothing changes: the village is already written by hand, and stays as you know it.",
	"Non adesso": "Not now",
	"Scaricalo": "Download it",

	# Il pezzo già arrivato.
	"Ne era già arrivato un pezzo: %s di %s. Posso riprendere da lì — non si ricomincia da capo.":
			"Part of it had already arrived: %s of %s. I can carry on from there — no starting over.",
	"Oppure lo butto via, e il disco torna com'era.":
			"Or I throw it away, and the disk goes back to how it was.",
	"Butta via il pezzo": "Throw the part away",

	# La macchina che non ce la fa. NIENTE NUMERI, in nessuna delle due
	# lingue: quello che serve sapere è che non c'è niente da scaricare e che
	# non è colpa di chi legge.
	"Questo computer non ha memoria da prestargli, e non è una cosa che si aggiusta chiudendo una finestra.":
			"This computer hasn't the memory to lend it, and that isn't something a closed window can mend.",
	"Non c'è niente da scaricare, allora — meglio così, sarebbe stata una lunga attesa per niente. Il villaggio resta quello che conosci: le lettere e i pensieri scritti a mano ci sono tutti, e sono la maggior parte.":
			"So there's nothing to download — just as well, it would have been a long wait for nothing. The village stays the one you know: the letters and the thoughts written by hand are all there, and they are most of them.",
	"Va bene così": "That's all right",
	"Questo computer, in questo momento, non ha memoria da prestargli. Un villaggio che pensa a spese del villaggio che si muove non sarebbe un buon affare.":
			"This computer, just now, hasn't the memory to lend it. A village that thinks at the expense of the village that moves would be a poor bargain.",
	"Non c'è niente da scaricare, allora. Se chiudi qualcos'altro e torni qui, riprovo volentieri.":
			"So there's nothing to download. Close something else and come back, and I'll gladly try again.",
	"Riprova": "Try again",

	# Mentre arriva.
	"Sta arrivando": "On its way",
	"%s di %s": "%s of %s",
	"Puoi chiudere questa pagina e tornare a giocare: va avanti per conto suo. Il villaggio comincerà a pensare dal prossimo avvio.":
			"You can close this page and go back to playing: it carries on by itself. The village will start thinking the next time you open the game.",
	"Se lo fermi, quello che è già arrivato resta: si riprende da lì.":
			"If you stop it, what has already arrived stays: it carries on from there.",
	"Ferma": "Stop",
	# «quanto manca», detto come lo direbbe una persona (systems/Capienza.gd)
	"ancora un momento": "a moment more",
	"meno di un minuto": "less than a minute",
	"un minuto circa": "about a minute",
	"circa %d minuti": "about %d minutes",
	"circa un'ora": "about an hour",
	"più di %d ore": "more than %d hours",

	# Quando va storto. Nessuna di queste frasi dà la colpa a chi legge, e
	# tutte dicono che cosa ne è stato di quello che era già arrivato: è la
	# sola cosa che una persona vuole sapere davanti a un errore.
	"Ricomincia": "Start again",

	# È arrivato.
	"È arrivato": "It's here",
	"Da qui in avanti, ogni tanto, un vicino avrà un'idea tutta sua: si accorgerà di qualcosa, ci penserà su, e andrà a fare una cosa che nessuno gli ha chiesto.":
			"From now on, every so often, a neighbour will have an idea of their own: they'll notice something, turn it over, and go and do something nobody asked them to.",
	"Comincia dal prossimo avvio del gioco. Se un giorno cambi idea, basta spegnere «Il villaggio pensa» qui nelle impostazioni.":
			"It starts the next time you open the game. If you change your mind one day, just switch “The village thinks” off here in the settings.",
	"Va bene": "All right",

	"Quello che era arrivato l'ho lasciato dov'era: se fai un po' di posto, si riprende da lì.":
			"What had arrived I've left where it was: make a little room and it carries on from there.",
	"Non dipende da te né da questo computer: se il posto è cambiato, lo sistemiamo noi.":
			"It's nothing to do with you or with this computer: if it has moved, we shall put it right.",

	# La riga nel pannello, per chi il modello non ce l'ha ancora.
	"Ogni tanto un vicino ha un'idea tutta sua. Per farlo il gioco ha bisogno di scaricare una cosa, una volta sola: prima te lo chiede.":
			"Every so often a neighbour has an idea of their own. For that, the game needs to download something, just the once: it asks you first.",

	# --- IL CORRIERE (systems/Scarico.gd) -----------------------------------
	# Le frasi dello scaricamento vero: cosa sta facendo, e com'è andata. Le
	# scrive `Scarico` e le MOSTRA `OffertaModello`, che è la ragione per cui
	# stanno qui accanto alle sue: chi rilegge questa parte deve poter vedere
	# in colonna tutto quello che una persona legge in quella pagina, e
	# accorgersi se due frasi vicine si contraddicono.
	#
	# ⚠️ Ogni riga di esito dice DUE cose: cos'è successo, e cosa si può fare
	# adesso. «Non ha funzionato» senza un seguito è solo un modo elegante di
	# dare la colpa a chi legge, e in inglese lo è ancora di più (la lingua
	# degli errori tira verso il passivo e la sigla).
	"Un momento…": "One moment…",
	"Mi collego…": "Getting in touch…",
	"Controllo che sia arrivato tutto…": "Checking that all of it arrived…",
	"Ci siamo.": "Nearly there.",
	"È arrivato. Dal prossimo avvio i vicini avranno idee tutte loro.":
			"It's here. From the next time you open the game, the neighbours will have ideas of their own.",
	"Lasciato a metà. Quello che è arrivato resta: si riprende da lì.":
			"Left half done. What arrived stays: it carries on from there.",
	"Sul disco non c'è abbastanza spazio libero.":
			"There isn't enough free room on the disk.",
	"La connessione non ha retto. Riprova quando vuoi: si riprende da dov'era.":
			"The connection didn't hold. Try again whenever you like: it carries on from where it was.",
	"Quello che è arrivato non era intero, e l'ho buttato. Riprova quando vuoi.":
			"What arrived wasn't whole, and I've thrown it away. Try again whenever you like.",
	"Adesso non si trova. Riprova più tardi.": "It can't be found just now. Try again later.",
	"Non riesco a scrivere sul disco.": "I can't write to the disk.",
}


static func tabella() -> Dictionary:
	return T
