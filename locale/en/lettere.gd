extends RefCounted
## Traduzione inglese — La prosa lunga: gli Ordini del Gufo, la posta del mattino, le bottiglie.
##
## Chiave = la frase italiana del sorgente. Vedi docs/TRADUZIONE.md per il
## glossario vincolante e le regole di stile.

const T := {
	# la lettera del posto di sempre (Mail.MOMENTI_TESTO)
	"C'e' un posto dove finivo sempre\nverso quell'ora, senza averlo deciso.\nIl giorno %d ci sei arrivato anche tu,\ne non ci siamo detti niente.":
		"There is a place I always ended up\nround about that hour, without ever deciding to.\nOn day %d you came there too,\nand neither of us said a word.",
	# ------------------------------------------------ gli Ordini del Gufo
	# la campagna: titolo, lettera, obiettivo, congratulazioni, e la
	# letterina del mattino dopo (GufoOrders.CHAIN)
	"La prima lettera": "The first letter",
	"Ho una cosa da dirti, e nessun posto dove posarla.\nMetti una cassetta accanto al sentiero:\nsarà lì che lascerò le mie parole, all'alba.":
		"I have something to tell you, and nowhere to set it down.\nPut a mailbox beside the path:\nthat is where I shall leave my words, at dawn.",
	"posa la Cassetta posta": "set down the Mailbox",
	"Ecco. Ora ho un posto dove scriverti. Comincia il nostro carteggio.":
		"There. Now I have somewhere to write to you. Our correspondence begins.",
	"Stamattina ho lasciato la prima lettera dentro la tua cassetta. Profumava già di legno e di attesa. Ora tocca a te far crescere qualcosa di verde intorno.":
		"This morning I left the first letter inside your mailbox. It already smelled of wood and of waiting. Now it is your turn to grow something green around it.",

	"Qualcosa di verde": "Something green",
	"La terra qui è nuda e un po' timida.\nPianta qualcosa di verde, una cosa sola:\nbasta un germoglio perché il resto prenda coraggio.":
		"The ground here is bare, and a little shy.\nPlant something green, just the one thing:\na single shoot is enough to give the rest courage.",
	"pianta almeno una Pianta": "plant at least one Plant",
	"Guarda: una foglia sola, e già l'aria sembra più gentile.":
		"Look: a single leaf, and already the air seems kinder.",

	"Il piccolo orto": "The little vegetable patch",
	"Chi mette radici, mette anche un pensiero al domani.\nApri un orto in un angolo di sole:\nvoglio vedere cosa deciderai di far crescere.":
		"Whoever puts down roots puts down a thought for tomorrow.\nOpen a vegetable patch in a corner of sun:\nI want to see what you decide to grow.",
	"un Orto in un angolo soleggiato": "a Vegetable patch in a sunny corner",
	"Un orto! Verrò a rubarti un pomodoro, di notte. Sarà il nostro segreto.":
		"A vegetable patch! I shall come and steal a tomato from you, at night. It will be our secret.",

	"Quattro mura e una porta": "Four walls and a door",
	"Il vento gira e non trova dove fermarsi.\nAlza dei muri e apri una porta:\nfai una stanza, anche piccola, dove il freddo bussi prima di entrare.":
		"The wind goes round and finds nowhere to settle.\nRaise some walls and open a door:\nmake a room, however small, where the cold must knock before it comes in.",
	"una stanza chiusa, con almeno una porta": "a closed room, with at least one door",
	"Una stanza! Ho sentito il primo silenzio caldo del villaggio.":
		"A room! I heard the first warm silence of the village.",
	"Stamattina ho sbirciato dalla soglia: dentro c'era già profumo di casa.":
		"This morning I peeped in from the doorstep: inside it already smelled of home.",

	"Un tetto sopra la testa": "A roof over your head",
	"Le stelle sono belle, ma bagnano.\nPosa un tetto sopra la tua stanza:\nsotto un tetto anche la pioggia diventa una ninnananna.":
		"The stars are lovely, but they do let the rain in.\nLay a roof over your little room:\nunder a roof, even the rain becomes a lullaby.",
	"un Tetto sopra la stanza": "a Roof over the room",
	"Ora hai un dentro e un fuori. Il villaggio ha imparato a proteggere.":
		"Now you have an inside and an outside. The village has learnt to shelter.",

	"Un posto per due": "A place for two",
	"Un tavolo apparecchiato per uno fa un po' di malinconia.\nMetti un tavolino e due sedie:\nprima o poi qualcuno verrà a sedersi di fronte a te.":
		"A table laid for one is a melancholy thing.\nSet out a little table and two chairs:\nsooner or later someone will come and sit across from you.",
	"un tavolino e almeno 2 sedie": "a little table and at least 2 chairs",
	"Due sedie una di fronte all'altra. Ho già in mente chi potrebbe riempirne una.":
		"Two chairs facing one another. I already have someone in mind to fill one of them.",

	"Il fuoco e la luce": "The fire and the light",
	"Quando cala il buio, un villaggio si riconosce da come si illumina.\nAccendi un camino e appendi una lampada:\ndue piccole luci bastano a dire «qui c'è vita».":
		"When the dark comes down, you know a village by the way it lights up.\nLight a fireplace and hang a lamp:\ntwo small lights are enough to say «there is life here».",
	"due piccole luci accese": "two small lights burning",
	"Da quassù vedo le tue luci: sembrano un piccolo faro tra gli alberi.":
		"From up here I can see your lights: they look like a little lighthouse among the trees.",

	"Una stanza per un ospite": "A room for a guest",
	"Prepara un letto e mettilo al riparo di un tetto.\nQualcuno, con una valigia e tanta timidezza,\nsta cercando proprio un posto così per fermarsi.":
		"Make up a bed and put it in the shelter of a roof.\nSomeone, with a suitcase and a great deal of shyness,\nis looking for just such a place to stop.",
	"un letto sotto un tetto": "a bed under a roof",
	"C'è un letto pronto, all'asciutto. Ora aspettiamo: qualcuno arriverà.":
		"There is a bed ready, and dry. Now we wait: someone will come.",
	"All'alba ho visto una valigia posata sulla soglia. Il tuo primo ospite ha annusato l'aria, ha guardato il letto sotto il tetto, e ha deciso di restare.":
		"At dawn I saw a suitcase set down on the doorstep. Your first guest sniffed the air, looked at the bed under the roof, and decided to stay.",

	"Il primo abitante": "The first resident",
	"Presto, col sereno del giorno, busserà un ospite\ncon la valigia in zampa. Preparagli un letto tutto suo,\nsotto un tetto — non quello di casa tua — e aspetta:\nsceglierà di restare.":
		"Soon, on a clear day, a guest will knock\nwith a suitcase in paw. Make up a bed all their own,\nunder a roof — not the one in your house — and wait:\nthey will choose to stay.",
	"un letto per l'ospite (non quello di casa) sotto un tetto, poi aspetta":
		"a bed for the guest (not the one in your house) under a roof, then wait",
	"Un abitante! Il villaggio ha smesso di essere un'idea: adesso respira.":
		"A resident! The village has stopped being an idea: now it breathes.",
	"Il tuo nuovo vicino stamattina ha spazzato la soglia canticchiando, e mi ha chiesto dove potrà segnare i giorni di festa. Gli ho promesso che gli avresti dato una lavagna tutta sua. Una casa che accoglie, prima o poi, ha voglia di crescere anche verso l'alto.":
		"Your new neighbour swept the doorstep this morning, humming, and asked me where they might mark the feast days. I promised you would give them a chalkboard of their own. A house that welcomes, sooner or later, wants to grow upwards too.",

	"Verso l'alto": "Upwards",
	"Il villaggio ha preso coraggio e vuole guardare più lontano.\nCostruisci un piano di sopra, un solaio:\nda lassù anche i tetti sembrano un piccolo mare ondulato.":
		"The village has taken heart and wants to look further off.\nBuild an upper storey, a loft:\nfrom up there even the roofs look like a small rippling sea.",
	"un piano di sopra (un Solaio)": "an upper storey (a Loft)",
	"Un piano nuovo, più vicino ai rami. Comincio a sentirti quasi alla mia altezza.":
		"A new storey, closer to the branches. I am beginning to feel you almost at my height.",

	"La casa sull'albero": "The treehouse",
	"Ci siamo arrivati in cima, tu ed io.\nLancia un ponticello di corda tra i tetti più alti:\nè l'ultimo ponte prima del ramo dove ti aspetto.":
		"We have come to the top, you and I.\nThrow a rope bridge between the highest roofs:\nit is the last bridge before the branch where I am waiting.",
	"un ponticello tra i tetti alti": "a rope bridge between the high roofs",
	"Il ponte regge. Il villaggio adesso tocca i rami: puoi costruire la casa sull'albero.":
		"The bridge holds. The village touches the branches now: you can build the treehouse.",
	"Stanotte mi trasferisco nella casa sull'albero che hai immaginato per me. Dal ramo più alto conto i tetti nuovi, le luci, gli orti, l'ospite che ora ha un nome: hai costruito un mondo intero, e io ho avuto il posto in prima fila. Grazie, piccolo Regista. — Il Gufo":
		"Tonight I move into the treehouse you dreamed up for me. From the highest branch I count the new roofs, the lights, the vegetable patches, the guest who has a name now: you have built a whole world, and I have had the best seat in the house. Thank you, little Director. — The Owl",

	# --------------------------------------- il Fiato Sospeso (FiatoSospeso)
	"Oggi ti ho vista arrivare di corsa e mi sono spostata.\nNon te la prendere: sei molto grande.\nSe però ti abbassi nell'erba e stai ferma (tieni premuto C),\ndopo un po' mi dimentico di te. E allora vengo a vedere chi sei.":
		"Today I saw you coming at a run, and I moved aside.\nDon't take it to heart: you are very large.\nBut if you crouch down in the grass and keep still (hold C),\nafter a while I forget about you. And then I come to see who you are.",
	"Mi dicono che %s\nsi è posata su di te e non è scappata.\nNon si insegna: si aspetta e basta.\nHai imparato il verbo più difficile.":
		"They tell me that %s\nsettled on you and did not take fright.\nIt cannot be taught: one simply waits.\nYou have learnt the hardest verb of all.",

	# ------------------------------------- le lettere-stagione (GufoOrders.DESIDERI)
	"Un prato che applaude": "A meadow that applauds",
	"Dalla casa sull'albero vedo i prati sbadigliare.\nVorrei contare dieci fiori aperti tutti insieme:\nun applauso colorato per la primavera.":
		"From the treehouse I can see the meadows yawning.\nI should like to count ten flowers open all at once:\na coloured applause for the spring.",
	"dieci fiori in fiore nello stesso giorno": "ten flowers in bloom on the same day",
	"Dieci corolle aperte! Stamattina il prato applaudiva da solo.":
		"Ten open blossoms! This morning the meadow was applauding all by itself.",

	"Posti in prima fila": "Seats in the front row",
	"I petali cadono meglio se qualcuno li guarda.\nMetti due panchine rivolte al vento:\nvoglio vedere chi si siede sotto la neve rosa.":
		"Petals fall better when somebody is watching them.\nSet two benches facing the wind:\nI want to see who sits under the pink snow.",
	"due panchine per guardare i petali": "two benches for watching the petals",
	"Due panchine, e gia' qualcuno ci sonnecchia sotto i petali.":
		"Two benches, and already somebody is dozing on them under the petals.",

	"Le stelle basse": "The low stars",
	"Le sere d'estate meritano una riva accesa.\nPianta tre lampioni lungo il fiume:\nvoglio specchiarli nell'acqua, dalla mia finestra.":
		"Summer evenings deserve a riverbank alight.\nPlant three lampposts along the river:\nI want to see them mirrored in the water, from my window.",
	"tre lampioni accesi lungo il fiume": "three lampposts burning along the river",
	"Tre lucine sull'acqua: il fiume adesso ha le sue stelle basse.":
		"Three little lights on the water: the river has its own low stars now.",

	"Il metronomo dell'estate": "The metronome of summer",
	"Le cicale cantano, ma sono stonate.\nRegala loro una fontana che tenga il tempo:\nlo zampillo e' il metronomo dell'estate.":
		"The cicadas are singing, but they are out of tune.\nGive them a fountain to keep the beat:\nthe spout is the metronome of summer.",
	"una fontana che canti in piazza": "a fountain to sing in the square",
	"La fontana canta e le cicale la seguono.\nNel pacco c'e' un braciere di scintille: accendilo\nalla prossima notte di lucciole.":
		"The fountain sings and the cicadas follow it.\nIn the parcel there is a brazier of sparks: light it\non the next night of fireflies.",

	"Il tepore di domani": "Tomorrow's warmth",
	"L'autunno e' la stagione delle scorte e dei rami pieni.\nFai crescere il boschetto fino a dodici alberi:\nla legna che non tagli oggi e' il tepore di domani.":
		"Autumn is the season of stores and of full branches.\nGrow the copse to twelve trees:\nthe wood you leave standing today is tomorrow's warmth.",
	"un boschetto di dodici alberi": "a copse of twelve trees",
	"Dodici chiome! Il bosco e' piu' ricco di come l'abbiamo trovato.":
		"Twelve crowns of leaves! The woods are richer than we found them.",

	"Le ceste piene": "The full baskets",
	"Si avvicina la sagra e le ceste sono leggere.\nApri quattro orti per il raccolto:\nnessuna festa e' tale a pancia vuota.":
		"The fair is coming and the baskets are light.\nOpen four vegetable patches for the harvest:\nno feast is a feast on an empty belly.",
	"quattro orti per la sagra del raccolto": "four vegetable patches for the harvest fair",
	"Quattro orti in fila: la sagra quest'anno avra' le guance piene.":
		"Four vegetable patches in a row: this year the fair will have full cheeks.",

	"Respiri dorati": "Golden breaths",
	"La neve spegne i colori, non i cuori.\nAccendi cinque luci tra camini, lampade e lampioni:\nvoglio vedere il villaggio respirare vapore dorato.":
		"Snow puts out the colours, not the hearts.\nLight five lights among fireplaces, lamps and lampposts:\nI want to see the village breathing golden steam.",
	"cinque luci accese tra camini, lampade e lampioni":
		"five lights burning among fireplaces, lamps and lampposts",
	"Cinque respiri di luce nella neve. Da quassu' sembrate un presepe.":
		"Five breaths of light in the snow. From up here you look like a nativity scene.",

	"Primavere tascabili": "Pocket springtimes",
	"Le sere lunghe vogliono storie lunghe.\nMetti due librerie al caldo del villaggio:\nun libro e' una primavera tascabile.":
		"Long evenings want long stories.\nPut two bookcases in the warm of the village:\na book is a springtime you can pocket.",
	"due librerie per le sere lunghe": "two bookcases for the long evenings",
	"Due librerie piene! Ti lascio la giostrina:\nanche le storie girano in tondo.":
		"Two full bookcases! I leave you the carousel:\nstories go round in circles too.",

	# ------------------------------- il cartiglio, il banner e il diario del Gufo
	"Il Gufo sussurra:  %s": "The Owl whispers:  %s",
	"Il Gufo sogna:  %s": "The Owl dreams:  %s",
	"Il villaggio e' completo — la tela e' tua.":
		"The village is complete — the canvas is yours.",
	"prepara un letto sotto un tetto per l'ospite in arrivo":
		"make up a bed under a roof for the guest on the way",
	"l'ospite vuole un letto tutto suo (non quello di casa), sotto un tetto":
		"the guest wants a bed all their own (not the one in your house), under a roof",
	"col sereno, di giorno, qualcuno arrivera' con la valigia — tieni il letto pronto":
		"on a clear day, someone will come with a suitcase — keep the bed ready",
	"~  Gli Ordini del Gufo  ~": "~  The Owl's Wishes  ~",
	"Il tuo villaggio era gia' cresciuto prima di me.\nLa tela e' tua: costruisci come il cuore ti detta.":
		"Your village had already grown before I came.\nThe canvas is yours: build as your heart tells you.",
	"obiettivo:  %s": "goal:  %s",
	"desiderio:  %s": "wish:  %s",
	"·   gli Ordini a venire restano un segreto del ramo...":
		"·   the Wishes to come remain a secret of the branch...",
	"Il villaggio e' completo. Grazie, piccolo Regista. — Il Gufo":
		"The village is complete. Thank you, little Director. — The Owl",
	"✿   lettera di %s: «%s» — esaudita!": "✿   %s letter: «%s» — granted!",
	"»   lettera di %s: %s": "»   %s letter: %s",
	"(una nuova lettera arrivera' con la prossima stagione)":
		"(a new letter will come with the next season)",
	"%s\n\nTi lascio %d stelline sul davanzale.":
		"%s\n\nI leave you %d stars on the windowsill.",
	"\nE il pacco contiene: %s. E' tuo.": "\nAnd the parcel holds: %s. It is yours.",
	"O — chiudi": "O — close",

	# ------------------------------------------------ la posta del mattino
	# i mittenti del bosco e le loro letterine (Mail.LETTERS)
	"Il Gufo": "The Owl",
	"Passerotto": "Little Sparrow",
	"Ho visto il tuo giardino dall'alto:\nle aiuole sono le più belle del prato!":
		"I saw your garden from up high:\nyour flower beds are the loveliest in the meadow!",
	"Riccio": "Hedgehog",
	"Stanotte ho dormito sotto la tua panchina.\nGrazie per l'erba alta: era morbidissima.":
		"Last night I slept under your bench.\nThank you for the long grass: it was ever so soft.",
	"Volpe del bosco": "Fox of the Woods",
	"Il sentiero profuma di funghi nuovi.\nSe vedi una coda rossa tra le felci, ti sto salutando.":
		"The path smells of new mushrooms.\nIf you see a red tail among the ferns, I am waving to you.",
	"Gufo": "Owl",
	"Le tue lucciole tengono compagnia alle mie veglie.\nStanotte ho contato dodici stelle cadenti su casa tua.":
		"Your fireflies keep my night watches company.\nLast night I counted twelve shooting stars over your house.",
	"Scoiattolo": "Squirrel",
	"Ho nascosto una ghianda vicino al falò...\nanzi no: tienila tu, è il mio regalo!":
		"I hid an acorn near the campfire...\nno, on second thoughts: you keep it, it is my present!",
	"Farfalla": "Butterfly",
	"I tuoi fiori sono i più dolci che conosca.\nDomani torno con le mie sorelle: prepara il tè!":
		"Your flowers are the sweetest I know of.\nTomorrow I shall be back with my sisters: put the kettle on!",
	"Talpa": "Mole",
	"Scavando sono sbucata nel tuo giardino, scusa il buchetto.\nTi lascio un sassolino brillante per farmi perdonare.":
		"I was digging and popped up in your garden, sorry about the little hole.\nI leave you a shiny pebble by way of apology.",
	"Merlo": "Blackbird",
	"La tua musichetta si sente fino al ciliegio.\nAscolta bene domattina: la fischietto anch'io.":
		"Your little tune carries as far as the cherry tree.\nListen closely tomorrow morning: I shall be whistling it too.",

	# le lettere che nascono dai momenti del Filo Rosso (Mail.MOMENTI_TESTO)
	"Ripenso spesso al giorno %d:\nil tuo benvenuto sulla soglia.\nNessuno mi aveva mai aspettato così.":
		"I often think back to day %d:\nyour welcome on the doorstep.\nNobody had ever waited for me like that.",
	"La valigia è ancora sotto il letto.\nOgni tanto la guardo e sorrido:\ndal giorno %d questa è casa mia.":
		"The suitcase is still under the bed.\nNow and then I look at it and smile:\nsince day %d this has been my home.",
	"Ti ricordi il giorno %d?\nLa prima zampina alzata, da lontano.\nIo l'ho contata come un inizio.":
		"Do you remember day %d?\nThe first little paw raised, from far off.\nI counted it as a beginning.",
	"Ho ancora in mente il profumo\ndi quel piatto del giorno %d.\nUn giorno cucino io, promesso.":
		"I still have in my head the smell\nof that dish on day %d.\nOne day I shall do the cooking, promise.",
	"Il regalo del giorno %d\nce l'ho sulla mensola, al posto d'onore.\nGrazie di avermi pensato.":
		"The present from day %d\nis up on my shelf, in the place of honour.\nThank you for thinking of me.",
	"La festa del giorno %d!\nHo ritrovato un coriandolo nel pelo\ne mi è tornata tutta l'allegria.":
		"The party on day %d!\nI found a scrap of confetti in my fur\nand all the gladness came back to me.",
	"L'acqua calda del giorno %d,\nfianco a fianco, senza dire niente.\nEra tutto quello che serviva.":
		"The hot water on day %d,\nside by side, saying nothing at all.\nIt was everything that was needed.",
	"Non ho dimenticato il giorno %d,\nquando hai esaudito il mio desiderio.\nIl filo tra noi da lì si è colorato.":
		"I have not forgotten day %d,\nwhen you granted my wish.\nThe thread between us took its colour from there.",
	"Il giorno %d, dietro quel tronco,\nmi scappava da ridere e tu lo sapevi.\nGiochiamo ancora, promesso?":
		"On day %d, behind that tree trunk,\nI was bursting to laugh and you knew it.\nShall we play again, promise?",
	"Quel desiderio del giorno %d,\nl'ultimo, vissuto insieme:\nlo tengo tra i momenti d'oro.":
		"That wish on day %d,\nthe last one, lived together:\nI keep it among the golden moments.",
	"Del giorno %d non parlo volentieri,\nma il filo non si è spezzato:\nha solo cambiato forma.":
		"I do not speak gladly of day %d,\nbut the thread did not break:\nit only changed its shape.",
	"Dal Grande Prato si vede il villaggio.\nIl giorno %d avevo la valigia piccola\ne il cuore pieno. Grazie di tutto.":
		"From the Great Meadow you can see the village.\nOn day %d my suitcase was small\nand my heart was full. Thank you for everything.",
	"\n(E ho contato: i nostri momenti sono già %d!)":
		"\n(And I have counted: we are at %d moments already!)",

	"… e c'è anche un regalino!": "… and there is a little present too!",
	"E — leggi la posta": "E — read the post",
	"E — chiudi": "E — close",

	# ------------------------------- i messaggi in bottiglia (Bottiglie.LETTERE)
	"La lontra viaggiatrice": "The travelling otter",
	"Ho risalito tre fiumi e nessuno aveva un villaggio così.\nL'ho visto dall'orlo della cascata: sembrava una lanterna accesa.\nContinuate a tenere la luce, laggiù.":
		"I have swum up three rivers and none of them had a village like this.\nI saw it from the lip of the waterfall: it looked like a lantern left burning.\nKeep the light going, down there.",
	"Il capitano Gabbiano": "Captain Seagull",
	"Questo fiume, per chi non lo sapesse, finisce nel MARE.\nUn giorno vi porto un po' di vento salato.\nNel frattempo: si naviga anche restando fermi.":
		"This river, in case anybody was wondering, ends in the SEA.\nOne day I shall bring you a little salt wind.\nIn the meantime: one can sail while standing still.",
	"Nonna Castoro": "Granny Beaver",
	"Sento battere i colpi d'ascia fin quassù, alla mia diga.\nChi costruisce non è mai solo: il legno si ricorda le zampe.\nMangia qualcosa di caldo, che l'autunno morde.":
		"I can hear the axe-blows all the way up here, at my dam.\nWhoever builds is never alone: the wood remembers the paws.\nEat something warm, now that autumn bites.",
	"Il pescatore di stelle": "The fisher of stars",
	"Di notte pesco le stelle che cadono nel lago di sopra.\nSe ne vedi passare una, esprimi il desiderio per me:\ni miei li ho finiti tutti, e sono avanzate solo grazie.":
		"At night I fish out the stars that fall into the lake above.\nIf you see one go by, make the wish for me:\nmine are all used up, and only thank-yous are left over.",
	"La rana del lago di sopra": "The frog of the lake above",
	"Se nello stagno trovi un girino con l'aria di chi sa il fatto suo,\nè uno dei miei. Digli che a casa va tutto bene\ne che la ninfea grande è ancora sua, se torna.":
		"If you find a tadpole in the pond with the air of one who knows his business,\nhe is one of mine. Tell him all is well at home\nand that the big lily pad is still his, if he comes back.",
	"La talpa cartografa": "The mapmaker mole",
	"Sto disegnando la mappa di tutto quel che c'è SOTTO.\nSotto il tuo prato passa una galleria che profuma di noccioline:\nqualcuno, tanto tempo fa, ci ha nascosto qualcosa.":
		"I am drawing the map of everything there is BELOW.\nUnder your meadow runs a tunnel that smells of acorns:\nsomebody, a long time ago, hid something down there.",
	"L'airone postino": "The heron postman",
	"Consegno lettere da prima che esistessero le cassette.\nQuesta l'ho affidata all'acqua perché l'acqua non sbaglia strada.\nSe la stai leggendo, avevo ragione io.":
		"I have been delivering letters since before mailboxes existed.\nThis one I trusted to the water, because water never takes the wrong road.\nIf you are reading it, I was right.",
	"Una zampa sconosciuta": "An unknown paw",
	"Non so chi troverà questa bottiglia.\nSo che quando il mondo mi sembra troppo grande, ne scrivo una,\ne il fiume se la porta via. Ora il troppo è un po' di meno.\nGrazie.":
		"I do not know who will find this bottle.\nI know that when the world feels too big, I write one,\nand the river carries it away. Now the too-much is a little less.\nThank you.",
	"Nel fondo: %d noccioline. 🌰": "At the bottom: %d acorns. 🌰",
	"Nel fondo: %s, per la dispensa.": "At the bottom: %s, for the pantry.",
	"E incastrata nel vetro: una conchiglia di fiume.":
		"And wedged in the glass: a river shell.",
	"E sul fondo, una stellina. ⭐": "And on the bottom, a star. ⭐",
	"E — ripesca la bottiglia!": "E — fish the bottle out!",
	# la riga che la prima bottiglia incide sugli anelli del Grande Albero
	"una bottiglia da oltre la cascata": "a bottle from beyond the waterfall",

	# --------------------------------- le richieste della lavagna (Commissioni)
	"📌 %s ha appeso una richiesta alla lavagna:\n«%s» (%d🌰)":
		"📌 %s has pinned a request to the chalkboard:\n«%s» (%d🌰)",
	"✔ Consegnato! %s è al settimo cielo: +%d🌰 (e un momento sul filo)":
		"✔ Delivered! %s is over the moon: +%d🌰 (and a moment on the thread)",
	"E — consegna: %s": "E — hand over: %s",
	# i plurali che nascono da _plurale(): la lavagna chiede sempre più d'uno
	"carote": "carrots",
	"zucche": "pumpkins",
	"bacche": "berries",
	"funghi": "mushrooms",
	"mele": "apples",
	"pere": "pears",

	# --- il biglietto della lavagna, ricomposto al momento di leggerlo
	# (Commissioni.biglietto): il template + la voglia di chi lo appende ---
	"Sogno %s: %s.": "I keep dreaming of %s: %s.",
	"%d %s per %s!": "%d %s for %s!",
	"mi serve per la mia ricetta segreta": "I need it for my secret recipe",
	"voglio ritrarla prima che voli via": "I want to draw it before it flies off",
	"l'ho inseguita per tutto il bosco, invano": "I chased it all through the woods, and lost it",
	"dicono porti fortuna ai giardini": "they say it brings a garden luck",
	"mi ricorda il bosco dov'era la mia tana": "it reminds me of the woods where my burrow was",
	"solo il tuo retino può riuscirci": "only your net could ever manage it",
	"ci penso da giorni e giorni": "I've been thinking about it for days and days",
	"la mia marmellata": "my jam", "la mia torta": "my pie",
	"la mia composta": "my compote", "la mia zuppa": "my soup",
	"la mia vellutata": "my velvet soup", "il mio risotto": "my risotto",
	"la mia cena": "my supper",

	# ------------------------------------------------------ le Promesse
	# I bigliettini dell'appuntamento e le lettere della scena persa.
	# Tono: quieto, concreto, mai un rimprovero — chi scrive racconta
	# quello che ha visto, non quello che ti sei perso.
	"Domattina, quando si alza la bruma,\nallo stagno. Dura il tempo di un tè:\npoi il sole se la beve tutta.\nIo ci sono comunque, nell'acqua bianca.":
		"Tomorrow morning, when the mist comes up,\nat the pond. It lasts about as long as a cup of tea:\nthen the sun drinks it all.\nI'll be there either way, in the white water.",
	"Domani, quando il sole tocca l'acqua,\nallo stagno: i pesci salgono a respirare.\nSi sentono prima di vederli. Vieni piano.":
		"Tomorrow, when the sun touches the water,\nat the pond: the fish come up to breathe.\nYou hear them before you see them. Come quietly.",
	"L'autunno finisce e l'aria sa di ferro.\nIl primo fiocco cade prima che uno se l'aspetti:\nquel giorno, appena comincia, vieni al Grande Albero.\nVoglio vederlo insieme a qualcuno.":
		"Autumn is ending and the air tastes of iron.\nThe first flake falls before you expect it:\nthat day, as soon as it starts, come to the Great Tree.\nI want to watch it with someone.",
	"La bruma è venuta, alta fino alle orecchie.\nLo stagno non c'era più: c'era il fiato dell'acqua\ne i giunchi che spuntavano come dita.\nHo aspettato finché il sole non l'ha bevuta.\nIl posto accanto a me è rimasto libero e tiepido.":
		"The mist came, up to my ears.\nThe pond was gone: there was the water's breath\nand the reeds poking through like fingers.\nI waited until the sun drank it away.\nThe place beside me stayed empty, and warm.",
	"Ne sono saliti sette, forse otto.\nUno ha fatto un anello così largo\nche è arrivato fino alla mia zampa.\nPoi l'acqua si è richiusa e ha fatto buio.":
		"Seven came up, maybe eight.\nOne made a ring so wide\nit reached all the way to my paw.\nThen the water closed over and it got dark.",
	"È cominciata senza avvisare.\nAl Grande Albero c'ero solo io e i primi fiocchi,\nche a toccarli non erano freddi, erano lenti.\nQuest'inverno ne cadranno milioni.\nQuesto era il primo, e adesso lo so io soltanto.":
		"It began without warning.\nAt the Great Tree it was only me and the first flakes,\nwhich weren't cold to touch, only slow.\nMillions will fall this winter.\nThis was the first, and now only I know it.",
	"Il giorno %d ti ho dato appuntamento\ne tu sei venuto davvero.\nDi tutte le cose che abbiamo visto insieme,\nquella me la ricordo dall'inizio.":
		"On day %d I asked you to meet me\nand you actually came.\nOf all the things we've seen together,\nthat one I remember from the very start.",

	# ------------------------------------------------ le nuove leve (Nascite)
	# la lettera con cui il Gufo annuncia che è nato qualcuno
	"Stanotte non ho chiuso occhio, e per una buona ragione.\nIn casa di %s e %s è arrivato qualcuno\npiù piccolo delle mie due ali messe insieme.\n\nVai a conoscerlo, quando puoi.\nUn nome non ce l'ha: hanno detto che lo sceglierai tu.":
		"I did not close an eye last night, and for a good reason.\nIn %s and %s's house someone has arrived\nsmaller than both my wings put together.\n\nGo and meet them, when you can.\nA name they have not got: they said you would choose it.",
	# i tre momenti nuovi del Filo Rosso (Mail.MOMENTI_TESTO)
	"Il giorno %d è la mattina più lunga\nche io ricordi, e la più corta.\nSei venuto a vederlo che era ancora\npiù piccolo delle mie due zampe.":
		"Day %d is the longest morning\nI can remember, and the shortest.\nYou came to see them when they were still\nsmaller than my two paws.",
	"Il nome che porto me l'hai dato tu,\nil giorno %d, quando ero grande così.\nNon me lo ricordo. Me l'hanno raccontato\nabbastanza volte da ricordarmelo lo stesso.":
		"The name I carry, you gave me,\non day %d, when I was only this big.\nI don't remember it. They have told me about it\noften enough that I remember it anyway.",
	"Dicono che la prima parola\nl'ho detta il giorno %d, tutta storta,\ne che tu eri lì e hai riso.\nPoi l'ho imparata bene, ma quella era mia.":
		"They say my first word\ncame out on day %d, all crooked,\nand that you were there, and laughed.\nI learned to say it properly later, but that one was mine.",
	# l'ultimo desiderio di chi lascia dei figli (Congedo.DESIDERI_TESTO)
	"tornare sulla soglia dove l'ha visto per la prima volta":
		"to stand again on the doorstep where they first saw them",
}


static func tabella() -> Dictionary:
	return T
