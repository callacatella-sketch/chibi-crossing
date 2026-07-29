extends RefCounted
## Traduzione inglese — I vicini: animo, lavori, desideri, feste, Filo Rosso, congedo, commissioni.
##
## Chiave = la frase italiana del sorgente. Vedi docs/TRADUZIONE.md per il
## glossario vincolante e le regole di stile.
##
## NOTA per chi tocca questa parte: qui dentro ci sono anche voci che NON
## sembrano frasi — "diserzione", "taglia_legna", "catasta". Sono gli ID del
## gioco (gradini della scala, compiti, luoghi marchiati dal limbico) che il
## registro dei lavori MOSTRA così come sono: nel dato restano italiani, qui
## si traduce solo come si leggono. Non toglierle, e non tradurle nei sorgenti.

const T := {
	# --------------------------------- il sasso del collezionista, e il posto
	"%s ti ha portato un sasso piatto: perfetto per rimbalzare.":
		"%s has brought you a flat stone: perfect for skimming.",
	"quel posto dove ci si trovava senza dirselo":
		"that place where you met without ever saying so",
	# ------------------------------------------------------------ l'animo
	# La catena causale che il registro dei lavori mostra sotto ogni nome.
	"%s è a «%s»%s: %s.": "%s is %s%s: %s.",
	"%s non ha nulla da rimproverarti.": "%s has nothing to hold against you.",
	"nel villaggio se ne parla male": "the village talks, and not kindly",
	"(e lui sognava di fare %s)": "(and they dreamt of being %s)",
	"ha perso %s": "lost %s",
	"e nessuno gli è stato vicino": "and no one stood by them",
	"gira voce su %s": "there's talk going round about %s",
	"%s al limite": "%s at breaking point",
	"malessere": "low spirits",
	"giorno %d: %s → %s (%s)": "day %d: %s → %s (%s)",

	# lo sfogo: te lo dice in faccia, coi fatti in mano
	"Ti rendi conto?": "Do you realise?",
	"Guardami quando ti parlo.": "Look at me when I'm talking to you.",
	"Scusa… posso dirti una cosa?": "Sorry… may I say something?",
	"%s, e %s": "%s, and %s",
	"Non lo faccio più.": "I'm not doing it any more.",
	"Me ne vado.": "I'm leaving.",
	"Io ti sono stato accanto. Tu no.": "I stood by you. You didn't.",
	"Non è niente. Lascia stare.": "It's nothing. Leave it.",
	"si era trattenuto %d volte oggi": "they'd bitten their tongue %d times today",
	"non gli restava più pazienza": "they had no patience left",

	# i gradini della scala della ribellione (l'id resta italiano nel dato)
	"lavoro": "at work",
	"svogliato": "listless",
	"attrezzi": "losing their tools",
	"rifiuto": "refusing",
	"sabotaggio": "quietly sabotaging",
	"confronto": "ready to confront you",
	"diserzione": "about to leave",
	"ammutinamento": "in open mutiny",

	# la battuta di ogni gradino: il telegrafo che si vede addosso
	"Buongiorno!": "Good morning!",
	"…arrivo, sì, arrivo.": "…coming, yes, I'm coming.",
	"Oh. Ho scordato l'ascia. Di nuovo.": "Oh. I've forgotten the axe. Again.",
	"Oggi no. Chiedilo a qualcun altro.": "Not today. Ask someone else.",
	"Strano, era a posto ieri sera…": "Odd, it was fine last night…",
	"Possiamo parlare? Adesso.": "Can we talk? Now.",
	"Ho lasciato le mie cose in ordine. Addio.": "I've left my things tidy. Goodbye.",
	"Non sei più tu a decidere per noi.": "You don't decide for us any more.",

	# i sogni: chi voleva diventare cosa (dentro «sognava di fare…»)
	"boscaiolo": "a woodcutter",
	"giardiniere": "a gardener",
	"cuoco": "a cook",
	"guerriero": "a warrior",
	"artista": "an artist",
	"esploratore": "an explorer",

	# le pressioni interne, quando arrivano al limite
	"fatica": "weariness",
	"noia": "boredom",
	"sicurezza": "safety",
	"autonomia": "independence",
	"appartenenza": "belonging",
	"stima": "self-worth",

	# i compiti e i fatti contati, come li elenca la spiegazione
	"taglia_legna": "chopping wood",
	"coltiva": "tending the patch",
	"cucina": "cooking",
	"guardia": "standing guard",
	"esplora": "exploring the woods",
	"riposa": "resting",
	"festa": "parties",
	"lutto": "a loss",
	"lutto_ignorato": "grief left alone",
	"consolato": "being comforted",
	"regalo": "a gift",
	"piatto": "a warm dish",

	# come sta il CORPO: la riga che spiega una reazione sproporzionata
	"col cuore in gola": "heart in their throat",
	"ancora guardingo": "still on their guard",
	"di malumore": "out of sorts",
	"di buonumore": "in good spirits",
	"a corto di pazienza": "short on patience",

	# ------------------------------------------------ il registro dei lavori
	"Il registro dei lavori": "The work register",
	"↑↓ scegli il residente   ←→ cambia il suo lavoro   ·   N chiude":
			"↑↓ pick a neighbour   ←→ change their work   ·   N closes",
	"Non c'è ancora nessuno in paese.": "No one has moved in yet.",
	"gira al largo da: %s": "steers clear of: %s",
	"Con te accanto, %s ci torna — e non succede niente.":
			"With you beside them, %s goes back — and nothing happens at all.",
	"%s ha trovato la tua lettera.": "%s has found your letter.",

	# i lavori assegnabili
	"— riposo —": "— rest —",
	"Tagliare la legna": "Chop the wood",
	"Curare l'orto": "Tend the patch",
	"Cucinare": "Cook",
	"Fare la guardia": "Stand guard",
	"Esplorare il bosco": "Explore the woods",

	# come sta, in parole che si capiscono al volo
	"sereno": "at ease",
	"distratto, perde gli attrezzi": "distracted, keeps losing their tools",
	"si rifiuta": "refuses outright",
	"qualcosa non torna…": "something isn't adding up…",
	"vuole parlarti": "wants a word with you",
	"sta per andarsene": "about to leave",
	"non ti ascolta più": "won't listen to you any more",

	# i posti che si sono caricati di brutti ricordi
	"catasta": "the woodpile",
	"orto": "the vegetable patch",
	"confine": "the border",
	"bosco": "the woods",

	# la resa del mattino
	"+%d legna in catasta": "+%d wood on the pile",
	"%d aiuole annaffiate": "%d flower beds watered",
	"un'aiuola annaffiata": "one flower bed watered",
	"in tavola: %s": "on the table: %s",
	"%d tesori dal bosco": "%d treasures from the woods",
	"un tesoro dal bosco": "one treasure from the woods",

	# --- la ronda della guardia: quello che la notte ha lasciato ---
	"%d lanterne accese sulla ronda": "%d lanterns lit along the round",
	"una lanterna accesa sulla ronda": "one lantern lit along the round",
	"che buio, stanotte, dalle parti di %d case": "such a dark night, out by %d of the houses",
	"che buio, stanotte": "such a dark night",
	"Il lavoro del mattino: %s": "The morning's work: %s",

	# ------------------------------------------------------ la vita di ogni giorno
	"%s sgranocchia qualcosa tra i cespugli…": "%s is nibbling something in the shrubs…",
	"♥ %s sta annaffiando le tue aiuole!": "♥ %s is watering your flower beds!",
	"%s si è addormentato lì, così.": "%s has fallen asleep right there, just like that.",
	"%s è rimasto fuori a guardare le stelle…": "%s has stayed out to watch the stars…",
	"%s sta confidando un segreto a un fungo…": "%s is telling a mushroom a secret…",
	"Una farfalla ha spaventato %s!": "A butterfly has startled %s!",
	"♪ %s sta cantando alla luna.": "♪ %s is singing to the moon.",

	# l'indole e la stravaganza, in una riga
	"ha sempre un certo languorino": "always has a bit of an appetite",
	"poltrisce fino a tardi": "lies in until late",
	"è in piedi prima del sole": "is up before the sun",
	"attacca bottone con chiunque": "strikes up a chat with anyone",
	"si scioglie solo con gli amici veri": "only opens up with true friends",
	"si perde a guardare il cielo": "gets lost watching the sky",
	"non sopporta un'aiuola trascurata": "can't bear a neglected flower bed",
	"brontola, ma ha un cuore di panna": "grumbles, but has a heart of cream",
	"confida i suoi segreti ai funghi": "tells their secrets to mushrooms",
	"ha una paura buffa delle farfalle": "has a funny fear of butterflies",
	"canticchia alla luna": "hums to the moon",
	"colleziona sassolini bellissimi": "collects beautiful little pebbles",
	"ogni tanto fa una piroetta": "does a little pirouette now and then",
	"si addormenta nei posti più strani": "falls asleep in the oddest places",

	# i due desideri più forti del genoma: la riga che li presenta
	"adora i giardini fioriti": "adores a garden in bloom",
	"cerca il calore del camino": "seeks out the warmth of a fireplace",
	"sogna una casa ben arredata": "dreams of a well-furnished home",
	"vuole finestre da cui guardare il prato": "wants windows to watch the meadow from",
	"tiene alla sua privacy": "is fond of their privacy",
	"vuole una porta tutta sua": "wants a door of their very own",
	"non sopporta la pioggia sul naso": "can't abide rain on their nose",

	# ------------------------------------------------------------ il trasloco
	"C'è %s alla porta, valigia in zampa! (%s)":
			"%s is at the door, suitcase in paw! (%s)",
	"«%s… però %s»": "«%s… though %s»",
	"«Oh… la casetta non c'è più.» E %s riparte col trolley.":
			"«Oh… the little house is gone.» And %s sets off again, suitcase in tow.",
	"«Ci devo pensare… %s» E %s riparte col trolley.":
			"«I shall have to think about it… %s» And %s sets off again, suitcase in tow.",
	"%s ha deciso: si trasferisce nel villaggio!":
			"%s has decided: they're moving into the village!",
	"%s si è trasferito nel villaggio": "%s moved into the village",
	"E — dai il benvenuto": "E — welcome them",

	# quello che una casa candidata sa dire di sé
	"Un tetto vero sopra la testa!": "A real roof over my head!",
	"Che pareti solide e curate": "Such solid, well-kept walls",
	"Una porta tutta mia…": "A door all of my own…",
	"Adoro guardare fuori dalla finestra": "I do love looking out of a window",
	"È così accogliente qui dentro": "It's so snug in here",
	"Che giardinetto delizioso qui davanti": "What a lovely little garden out front",
	"Il camino scoppietta che è una meraviglia": "The fireplace crackles a treat",
	"E tu sei così gentile…": "And you are so kind…",
	"Che bel posticino": "What a nice little spot",
	"senza un tetto mi piove sul naso": "with no roof the rain lands on my nose",
	"servirebbe qualche parete in più": "it could do with a few more walls",
	"una porta mi farebbe sentire al sicuro": "a door would make me feel safe",
	"sogno una finestra da cui guardare il prato":
			"I dream of a window to watch the meadow from",
	"qualche mobile in più non guasterebbe": "a little more furniture wouldn't hurt",
	"un giardinetto davanti casa sarebbe un sogno":
			"a small garden out front would be a dream",
	"un caminetto scalderebbe le zampe": "a fireplace would warm my paws",
	"mi piacerebbe sentirmi davvero benvenuto": "I'd like to feel truly welcome",

	# ------------------------------------------------------ i piccoli desideri
	"%s sogna %s vicino a casa…": "%s dreams of %s near their home…",
	"%s è al settimo cielo: %s vicino a casa!":
			"%s is over the moon: %s right by their home!",
	"«sogno %s vicino a casa…»": "«I dream of %s near my home…»",
	"Grazie per %s vicino a casa mia!\nOgni mattina gli do il buongiorno.":
			"Thank you for %s by my home!\nI say good morning to it every day.",
	"un'aiuola": "a flower bed",
	"un fungo": "a mushroom",
	"un cespuglio": "a shrub",
	"una lampada": "a lamp",
	"una panchina": "a bench",

	# ------------------------------------------------------------ i regali
	"E / Tab — regala a %s": "E / Tab — give something to %s",
	"E — raccogli il regalino": "E — pick up the little gift",
	"%s ti ha lasciato %s!": "%s has left you %s!",
	"Il Riccio": "The Hedgehog",
	"Il Passerotto": "The Sparrow",
	"una bacca lucida": "a glossy berry",
	"un funghetto profumato": "a sweet-smelling little mushroom",
	"una foglia a forma di cuore": "a heart-shaped leaf",
	"una piuma morbidissima": "the softest feather",
	"un semino raro": "a rare little seed",
	"un fiocco di lana": "a tuft of wool",
	"%s ADORA %s %s!": "%s LOVES %s %s!",
	"%s ringrazia sorridendo per %s %s.": "%s smiles and thanks you for %s %s.",
	"%s ADORA %s!": "%s LOVES %s!",
	"%s ringrazia sorridendo per %s.": "%s smiles and thanks you for %s.",
	"Un amico": "A friend",
	"Mi trovo così bene nel villaggio.\nGrazie di essermi amica.":
			"I feel so at home in the village.\nThank you for being my friend.",
	"Mi trovo così bene nel villaggio.\nGrazie di essermi amico.":
			"I feel so at home in the village.\nThank you for being my friend.",

	# --------------------------------------------------------- la premura
	"Che languorino… il passo di Mochi si fa piccolo piccolo.":
			"Such an empty tummy… Mochi's steps go small and slow.",
	"%s si è accorta del languorino: un boccone del suo pranzo per te!":
			"%s has noticed the empty tummy: a bite of their own lunch, for you!",
	"%s si è accorto del languorino: un boccone del suo pranzo per te!":
			"%s has noticed the empty tummy: a bite of their own lunch, for you!",
	"un vicino": "a neighbour",
	"Bentornata! Ti hanno aspettata, giorno dopo giorno.":
			"Welcome home! They waited for you, day after day.",
	"%s viene a sederti accanto. Non dice niente.":
			"%s comes and sits beside you. They say nothing.",
	"%s ti ha raggiunta sotto la pioggia, per non lasciarti sola.":
			"%s came out to you in the rain, so you wouldn't be alone.",

	# ---------------------------------------------------------- la partenza
	"%s sta raccogliendo le sue cose.": "%s is gathering up their things.",
	"%s: «…niente. Lascia stare.»": "%s: «…nothing. Leave it.»",
	"%s se n'è andato.": "%s has gone.",
	"%s\n\nHo lasciato le mie cose in ordine.\nNon serbo rancore: serbo memoria.":
			"%s\n\nI've left my things tidy.\nI hold no grudge: I hold the memory.",

	# ------------------------------------------------------- il Filo Rosso
	"❀ Il filo con %s si colora: %s": "❀ The thread with %s takes colour: %s",
	"💭 %s ripensa: %s (giorno %d)": "💭 %s thinks back on: %s (day %d)",
	"il primo benvenuto sulla soglia": "the first welcome on the doorstep",
	"il giorno della valigia sulla soglia": "the day of the suitcase on the doorstep",
	"la prima zampina alzata": "the first little paw raised",
	"quel piatto fumante diviso in due": "that steaming dish shared in two",
	"un dono scelto con cura, zampa a zampa": "a gift chosen with care, paw to paw",
	"la festa a sorpresa coi coriandoli": "the surprise party with the confetti",
	"il bagno caldo alle terme, fianco a fianco":
			"the warm soak at the hot spring, side by side",
	"il desiderio esaudito vicino a casa": "the wish granted close to home",
	"la partita a nascondino nel bosco": "the game of hide-and-seek in the woods",
	"quella lettera lasciata nella cassetta": "that letter left in the postbox",
	"quell'ultimo desiderio, vissuto insieme": "that last wish, lived together",
	"il giorno in cui ha fatto il fagotto": "the day they packed their bundle",
	"il giorno della piccola valigia e del cappello in zampa":
			"the day of the small suitcase and the hat in paw",

	# l'autunno di un vicino
	"🍂 Sul musetto di %s brillano i primi peli d'argento":
			"🍂 The first silver hairs are showing on %s's little face",
	"l'autunno di %s è cominciato": "%s's autumn has begun",
	"Ho visto i primi peli d'argento\nsul musetto di %s.\nLe stagioni passano anche per noi.\nStagli vicino.":
			"I have seen the first silver hairs\non %s's little face.\nThe seasons pass for us too.\nStay close to them.",

	# ------------------------------------------------------------ il congedo
	"%s sente che è quasi tempo di partire\nper il Grande Prato. Vuole salutare il mondo:\naccompagnala tu, un desiderio al giorno.\nSarà la settimana più piena di tutte.":
			"%s feels it is almost time to leave\nfor the Great Meadow. They want to say goodbye to the world:\ngo with them, one wish a day.\nIt will be the fullest week of all.",
	"🍂 Per %s comincia la settimana delle ultime cose.":
			"🍂 For %s the week of last things begins.",
	"Oggi %s vorrebbe: %s. Raggiungila là.":
			"Today %s would like: %s. Go and meet them there.",
	"Stasera, al falò: tutto il villaggio è con %s.\nLungo i sentieri, una a una, si accendono le lanterne.":
			"Tonight, at the campfire: the whole village is with %s.\nAlong the paths, one by one, the lanterns come alight.",
	"✨ Desiderio esaudito: %s. Un momento d'oro sul filo.":
			"✨ Wish granted: %s. A golden moment on the thread.",

	# gli ultimi desideri, uno al giorno
	"rivedere la soglia del primo giorno": "to see the doorstep of that first day again",
	"sedersi ancora davanti a casa sua": "to sit outside their own home once more",
	"una zampina alzata in piazza, come la prima volta":
			"a little paw raised in the square, the way it was the first time",
	"sentire il profumo di un piatto davanti a casa":
			"to smell a warm dish outside the door",
	"tornare dove i regali passavano di zampa in zampa":
			"to go back where the gifts passed from paw to paw",
	"la piazza delle feste, un'ultima volta": "the square of the parties, one last time",
	"un ultimo bagno alle terme, fianco a fianco":
			"one last soak at the hot spring, side by side",
	"il posto del desiderio esaudito, vicino a casa":
			"the place of the granted wish, close to home",
	"un ultimo giro del villaggio": "one last turn around the village",

	# la partenza per il Grande Prato, e la lettera lasciata sul letto
	"Sono partita all'alba, col cappello in zampa.\nPorto con me %d momenti del nostro filo":
			"I left at dawn, hat in paw.\nI take with me %d moments of our thread",
	",\ne i %d d'oro dell'ultima settimana": ",\nand the %d golden ones of that last week",
	".\nTi lascio il mio ricordino: portalo tu.\nNon serbo che gratitudine. — %s":
			".\nI leave you my little keepsake: you carry it now.\nI hold nothing but gratitude. — %s",
	"%s è partito per il Grande Prato": "%s left for the Great Meadow",
	"🌸 %s è partita per il Grande Prato, con la valigia piccola.\nDavanti a casa sua è sbocciato un fiore mai visto.":
			"🌸 %s has left for the Great Meadow, with the small suitcase.\nOutside their home a flower no one has ever seen has bloomed.",

	# il lutto giocato: gli echi, la finestra accesa, il villaggio più zitto
	"Stasera il villaggio si raccoglie al Grande Albero.":
			"Tonight the village gathers at the Great Tree.",
	"Il villaggio è più silenzioso, senza %s.": "The village is quieter, without %s.",
	"Il villaggio riprende piano il suo respiro. %s è nei fiori, nelle stelle, negli anelli.":
			"The village slowly finds its breath again. %s is in the flowers, in the stars, in the rings.",
	"❀ Per un attimo, %s è lì di nuovo — %s.":
			"❀ For a moment, %s is there again — %s.",
	"il suo fiore, che non appassisce": "their flower, the one that never fades",
	"♥ Hai consolato %s: il ricordo di %s adesso pesa meno.":
			"♥ You comforted %s: the memory of %s weighs a little less now.",

	# il fiore-ricordo, e i momenti che riaffiorano accanto a lui
	"E — ricorda %s": "E — remember %s",
	"💭 Il fiore di %s ondeggia piano.": "💭 %s's flower sways gently.",
	"💭 Accanto al fiore, i ricordi di %s riaffiorano…":
			"💭 Beside the flower, memories of %s come drifting back…",
	"giorno %d — %s": "day %d — %s",

	# ------------------------------------------------------------ il Regista
	# Le lettere del Gufo: la voce in-fiction di chi ti guarda giocare.
	"Il Gufo": "The Owl",
	"Dal ramo alto conto colpi d'ascia e tetti nuovi:\n%d opere! Il villaggio cresce sotto le tue zampe.":
			"From the high branch I count axe strokes and new roofs:\n%d works! The village grows under your paws.",
	"Ti guardo annaffiare ogni mattina: %d gesti\ngentili. Anche le farfalle se ne sono accorte.":
			"I watch you watering every morning: %d small\nkindnesses. Even the butterflies have noticed.",
	"Ho contato %d creaturine nei tuoi barattoli.\nLo stagno sussurra che gli piaci.":
			"I have counted %d little creatures in your jars.\nThe pond whispers that it likes you.",
	"Che via vai di benvenuti e zuppette: %d gentilezze!\nNel bosco non si parla d'altro.":
			"Such a coming and going of welcomes and soups: %d kindnesses!\nThe woods talk of nothing else.",
	"Ti ho vista guardare le stelle e camminare piano.\n%d momenti di quiete: sei dei nostri, ormai.":
			"I have watched you watch the stars, and walk slowly.\n%d quiet moments: you are one of us now.",
	"Ti osservo da un po': annusi il mondo come un\nriccio al primo giorno. Mi piace chi curiosa.":
			"I have been watching you a while: you sniff at the world like a\nhedgehog on its first day. I do like a curious soul.",

	# ------------------------------------------------ le nuove leve (Nascite)
	# «cucciolo» -> "little one": i chibi sono gatti, conigli, orsetti,
	# volpine e topolini insieme, e *pup*/*kitten* ne sceglierebbe uno solo.
	# Il sesso lo dice la frase, mai un pronome: in inglese «they» per un
	# neonato è naturale e non costringe a scegliere prima del nome.
	"il Gufo": "the Owl",
	"In casa di %s e %s, stanotte, è arrivata una vocina nuova.":
			"In %s and %s's house, last night, a new little voice arrived.",
	"E — conosci il cucciolo": "E — meet the little one",
	"%s e %s aspettano te.\nCome si chiama?":
			"%s and %s are waiting for you.\nWhat shall we call them?",
	"Invio — e da quel momento è il suo nome":
			"Enter — and from that moment it is their name",
	"Non c'è un lettino libero dove metterlo. Aspettano.":
			"There is no little bed free to lay them in. They are waiting.",
	"È un maschietto.": "It's a little boy.",
	"È una femminuccia.": "It's a little girl.",
	"%s Si chiama %s. E da oggi c'è.":
			"%s Their name is %s. And from today, they are here.",
	"è nato %s": "%s was born",
	"%s ha detto la sua prima parola. Storta, ma sua.":
			"%s said their first word. Crooked, but theirs.",
	# il gene che torna da chi è partito: la frase che il villaggio dice
	# quando riconosce, addosso a un cucciolo, qualcosa di chi non c'è più
	"Poi te ne accorgi, e ti si stringe qualcosa: %s.":
			"Then you notice, and something in you tightens: %s.",
	"ha gli occhi di %s": "has %s's eyes",
	"ha lo stesso pelo di %s": "has the very same coat as %s",
	"ha le orecchie di %s": "has %s's ears",
	"quando guarda storto, è %s tale e quale":
			"when they scowl, they are %s all over again",
}


static func tabella() -> Dictionary:
	return T
