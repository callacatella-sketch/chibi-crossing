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
	# il torto contato, e la stessa riga quando quel torto tradiva il sogno
	# di chi l'ha subito: due righe intere, non una con una parentesi
	# appiccicata (la parentesi, altrove, vuole un altro posto)
	"%s × %d (e lui sognava di fare %s)": "%s × %d (and they dreamt of being %s)",
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
	# «amphitheatre», mai «amphitheater»: il villaggio parla britannico.
	# Mancava perché Lavori.LAVORI è una tabella dati e nessun letterale
	# passa da L10n.t(): il registro dei lavori la mostrava in italiano.
	"Suonare all'anfiteatro": "Play at the amphitheatre",

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
	"%s esce dal salone tutto nuovo": "%s walks out of the salon brand new",
	"ieri sera «%s», e %d ad applaudire": "last night \"%s\", and %d clapping",
	"%d vicini hanno ascoltato il concerto": "%d neighbours listened to the concert",
	"%s corre a farsi vedere: il villaggio se ne accorge.":
			"%s runs off to be seen: the village takes notice.",
	"%s non fa che girarsi a guardare il suo riflesso.":
			"%s can't stop turning to look at their own reflection.",
	# l'anfiteatro: la sera del mestiere dell'artista
	"%s si siede al pianoforte. Le lanterne del palco si accendono.":
			"%s sits down at the piano. The stage lanterns come on.",
	"«%s»": "\"%s\"",
	"%d vicini applaudono nel buio.": "%d neighbours clap in the dark.",
	"Un solo applauso, ma sincero.": "One pair of hands only, but it means it.",
	"Tenere il salone": "Keep the salon",
	"un tesoro dal bosco": "one treasure from the woods",
	# --- il titolo del brano della sera (Concerto.TITOLO_A + TITOLO_B).
	# Le due metà si traducono SEPARATE e poi si compongono: perciò ogni
	# coda deve reggere sotto ognuna delle teste — «Waltz for the slow
	# rain» come «Lullaby for those who have gone». Le teste sono nomi di
	# forme musicali, la maiuscola resta; le code cominciano minuscole.
	# «Berceuse» in inglese si scrive uguale e per questo NON sta qui:
	# l'eccezione è dichiarata in test_localizzazione.UGUALI_IN_INGLESE. ---
	"Notturno": "Nocturne",
	"Ninnananna": "Lullaby",
	"Valzer": "Waltz",
	"Preludio": "Prelude",
	"Canzone": "Song",
	"Studio": "Study",
	"Serenata": "Serenade",
	"delle lucciole": "of the fireflies",
	"per la pioggia lenta": "for the slow rain",
	"del ponte di legno": "of the wooden bridge",
	"per chi non dorme": "for those who cannot sleep",
	"della prima neve": "of the first snow",
	"dei tetti bagnati": "of the wet rooftops",
	"per una finestra accesa": "for a lit window",
	"del vento fra i panni stesi": "of the wind through the washing",
	"della luna bassa": "of the low moon",
	"per chi è partito": "for those who have gone",

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
	"quella sera seduti al buio ad ascoltare": "that evening sitting in the dark, listening",
	"quell'ultimo desiderio, vissuto insieme": "that last wish, lived together",
	"il giorno in cui ha fatto il fagotto": "the day they packed their bundle",
	"il giorno della piccola valigia e del cappello in zampa":
			"the day of the small suitcase and the hat in paw",
	# i momenti delle nuove leve e dell'accompagnare (Legami.TIPI). Vengono
	# da una TABELLA DATI: il guardiano dei letterali non li vedeva, e sul
	# filo del cucciolo tornavano indietro in italiano dentro il gioco
	# inglese. Il pronome del vicino è `they`, sempre (docs/TRADUZIONE.md).
	"il mattino in cui è arrivato il cucciolo": "the morning the little one arrived",
	"il nome che gli hai scelto tu": "the name you chose for them",
	"la prima parola, detta tutta storta": "the first word, come out all crooked",
	"quel posto che non fa più paura": "that place that frightens them no more",
	# la Stratigrafia: il momento che un reperto dissotterrato annoda al
	# filo di chi è partito (Legami.TIPI["reperto"], prima colonna — la
	# tabella dati che _test_le_tabelle_dati spulcia per nome)
	"il piccolo ricordo che la terra ha custodito":
			"the little keepsake the earth kept safe",

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

	# la partenza per il Grande Prato, e la lettera lasciata sul letto.
	# Due lettere INTERE e non tre pezzi da incollare: la riga dei momenti
	# d'oro cade in mezzo a una frase, e in inglese una subordinata così
	# non sta per forza nello stesso punto (vedi scenes/world/Congedo.gd).
	"Sono partita all'alba, col cappello in zampa.\nPorto con me %d momenti del nostro filo.\nTi lascio il mio ricordino: portalo tu.\nNon serbo che gratitudine. — %s":
			"I left at dawn, hat in paw.\nI take with me %d moments of our thread.\nI leave you my little keepsake: you carry it now.\nI hold nothing but gratitude. — %s",
	"Sono partita all'alba, col cappello in zampa.\nPorto con me %d momenti del nostro filo,\ne i %d d'oro dell'ultima settimana.\nTi lascio il mio ricordino: portalo tu.\nNon serbo che gratitudine. — %s":
			"I left at dawn, hat in paw.\nI take with me %d moments of our thread,\nand the %d golden ones of that last week.\nI leave you my little keepsake: you carry it now.\nI hold nothing but gratitude. — %s",
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

	# IL TACCUINO. Le lettere che citano un micro-gesto: qui la traduzione
	# non e' un servizio, e' la meccanica. La prima meta' di ogni frase
	# afferma solo cio' che si e' visto, la seconda dice cosa ha pensato il
	# Gufo — e va conservato quell'ordine, o la lettera comincia a
	# sostenere di sapere cosa avevi in testa.
	# E niente pronomi sulla cosa citata: in italiano si sfascia sul genere,
	# in inglese si sfascia sul numero. «tutto e' rimasto dov'era» / «all of
	# it stayed where it was» non ha ne' l'uno ne' l'altro.
	"stamattina": "this morning",
	"ieri": "yesterday",
	"l'altro giorno": "the other day",
	"la pioggia": "the rain",
	"le stelle": "the stars",
	"l'acqua": "the water",
	"la luce che si alzava": "the light coming up",
	"le ombre che si allungavano": "the shadows growing long",
	"il prato": "the meadow",
	"quella creaturina": "that little creature",
	"quell'ombra nell'acqua": "that shadow in the water",
	"quell'albero": "that tree",
	"quel ramo carico": "that heavy branch",
	"quella terra smossa": "that turned earth",
	"quel sasso piatto": "that flat stone",
	"una mela": "an apple",
	"una pera": "a pear",
	"Ti ho vista fermarti, %s,\ndavanti a %s.\nHai allungato la zampina, e poi sei ripartita:\ntutto è rimasto dov'era.\nCi ho pensato tutto il pomeriggio, sul mio ramo.":
			"I saw you stop, %s,\nin front of %s.\nYou reached out a paw, and then you walked on:\nall of it stayed where it was.\nI thought about that all afternoon, on my branch.",
	"È la seconda volta che ti fermi davanti a qualcosa\ne poi tiri indietro la zampina.\nHo smesso di pensare che sia distrazione:\ncredo sia una regola tua. Non te la chiedo. La rispetto.":
			"That is the second time you have stopped in front of something\nand then drawn your paw back again.\nI have stopped believing it is absent-mindedness:\nI think it is a rule of yours. I shan't ask. I shall keep it.",
	"Cammini sul sentiero. Sempre, anche quando tagliare\nsarebbe più corto e nessuno ti vedrebbe.\nAnche io faccio così, sui rami. Non so perché.":
			"You walk on the path. Always, even when cutting across\nwould be shorter and nobody would see you.\nI do the same, along the branches. I don't know why.",
	"Hai posato un sentiero e cammini accanto.\nNon è un rimprovero: l'ho guardato dall'alto, stamattina,\ne ho pensato che certe cose si fanno perché siano belle da vedere.":
			"You laid a path and you walk beside it.\nThis is not a reproach: I looked down on it this morning,\nand thought that some things are made simply to be looked at.",
	"Sei rimasta ferma tanto, %s.\nA guardare %s.\nNon ho mosso una piuma, per non disturbarti.":
			"You stood still a long while, %s.\nWatching %s.\nI did not move a feather, so as not to disturb you.",
	"Hai saputo una cosa, giorni fa: l'ho vista posarsi su di te.\nNon l'hai detta a nessuno — e io ho aspettato, perché le voci\nprima o poi volano. Questa no.\nNon ti chiedo cos'era: certe parole sono di chi le affida,\nnon di chi le porta. La rispetto. E mi fido un po' di più.":
			"You learnt something, days ago: I saw it settle on you.\nYou told no one — and I waited, because word\nalways flies, sooner or later. This one never did.\nI shan't ask what it was: some words belong to the one who entrusts them,\nnot to the one who carries them. I respect that. And I trust you a little more.",

	# ------------------------------------------------ la Voce (Voce.gd)
	# le confidenze: si parla piano, e in prima persona. I luoghi arrivano
	# già con l'articolo (Voce.LUOGO_DETTO), da tradurre come si dicono.
	"la catasta": "the woodpile",
	"l'orto": "the vegetable patch",
	"la cucina": "the kitchen",
	"il confine": "the border",
	"il bosco": "the woods",
	"%s, piano: «C'è un posto dove non riesco più a passare… %s.»":
			"%s, softly: \"There's a place I can't bring myself to pass any more… %s.\"",
	"%s, piano: «Questo lavoro non è per me. Ma a chi lo dico?»":
			"%s, softly: \"This work isn't for me. But who could I tell?\"",
	"%s, piano: «La notte non mi sento al sicuro. Non so a chi dirlo.»":
			"%s, softly: \"At night I don't feel safe. I don't know who to tell.\"",
	"%s, piano: «Ho una stanchezza addosso che non passa. Non so a chi dirlo.»":
			"%s, softly: \"There's a tiredness on me that won't lift. I don't know who to tell.\"",
	"%s, piano: «I giorni sono tutti uguali. Non so a chi dirlo.»":
			"%s, softly: \"The days are all the same. I don't know who to tell.\"",
	"%s, piano: «%s non sa quanto conta per me. E io non riesco a dirglielo.»":
			"%s, softly: \"%s has no idea how much they matter to me. And I can't find the words.\"",
	"%s, pianissimo: «Sto pensando di andarmene. Non l'ho detto a nessuno.»":
			"%s, barely a whisper: \"I've been thinking of leaving. I haven't told a soul.\"",
	# le conseguenze: ogni riga afferma solo ciò che è successo davvero
	"%s ha capito. Prende %s per zampa: ci tornano insieme.":
			"%s understands. Takes %s by the paw: they're going back together.",
	"Gli occhi di %s si accendono: quel lavoro passa di mano. %s respira.":
			"%s's eyes light up: the work changes hands. %s can breathe again.",
	"%s ascolta, poi si avvia verso %s: certe cose si sistemano di persona.":
			"%s listens, then heads over to %s: some things are best put right in person.",
	"%s adesso lo sa. E va da %s — certe parole vanno restituite di persona.":
			"%s knows now. And goes straight to %s — some words must be returned in person.",
	"%s lascia tutto e corre da %s.":
			"%s drops everything and runs to %s.",
	"%s ammutolisce. Proprio da te non se l'aspettava.":
			"%s falls silent. From you, of all people.",

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
	# --------------------------------------------- le due strade (Limbico)
	# il sussulto del corpo, e un istante dopo la testa che riconosce
	"%s ha fatto un salto, poi ti ha riconosciuto: «ah… sei tu».":
			"%s gave a start, then knew you: «oh… it's you».",
	# --- ACCOMPAGNARE: il verbo che spegne una paura appresa ---
	"E — accompagna %s (%s)": "E — go with %s (%s)",
	"state andando %s…": "you're heading to %s…",
	"si è fermato. Restagli accanto.": "they've stopped. Stay beside them.",
	"non succede niente. È esattamente il punto.":
			"nothing is happening. That is exactly the point.",
	"Siete stati lì, e non è successo niente. %s respira.":
			"You stood there, and nothing happened. %s breathes.",
	"%s non gira più al largo. Ci siete tornati insieme, e tanto è bastato.":
			"%s doesn't give it a wide berth any more. You went back together, and that was enough.",
	# i nomi dei posti che il Limbico marchia sono GIÀ tradotti più su (riga
	# 130 e seguenti, «i posti che si sono caricati di brutti ricordi»):
	# riscriverli qui rompeva il file — chiave doppia in un dizionario
	# costante è un errore di parse, e con la tabella rotta il gioco
	# inglese tornava tutto italiano senza dire niente.
	# la frase del perché arriva come TEMPLATE da Limbico.perche_evita_dati:
	# la chiave è dinamica, quindi il test di copertura non la vede — se
	# sparisce da qui, in inglese ricompare in italiano senza un errore
	"gli è successo qualcosa di brutto lì (%d volte)":
			"something bad happened to them there (%d times)",
	"quando guarda storto, è %s tale e quale":
			"when they scowl, they are %s all over again",
}


static func tabella() -> Dictionary:
	return T
