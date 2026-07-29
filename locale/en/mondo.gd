extends RefCounted
## Traduzione inglese — Il mondo: creature, stagioni, meteo, orto, cucina, pesca, bosco, riti.
##
## Chiave = la frase italiana del sorgente. Vedi docs/TRADUZIONE.md per il
## glossario vincolante e le regole di stile.

const T := {
	# ------------------------------------------------ il bestiario (Critters)
	# I nomi nudi: minuscoli e senza articolo, come in italiano. `etichetta()`
	# ci mette la maiuscola sopra, dopo aver tradotto.
	"farfalla rosa": "pink butterfly",
	"farfalla azzurra": "blue butterfly",
	"farfalla dorata": "golden butterfly",
	"farfalla di ciliegio": "cherry-blossom butterfly",
	"falena della luna": "moon moth",
	"libellula ambrata": "amber dragonfly",
	"farfalla di neve": "snow butterfly",
	"farfalla di bruma": "mist butterfly",
	"lucciola": "firefly",
	"lucciola regale": "royal firefly",
	"carpa dorata": "golden carp",
	"pesciolino azzurro": "little blue fish",
	"carpa rosina": "rosy carp",
	"girino": "tadpole",
	"pesce dell'alba": "dawnfish",
	"carpa foglia d'oro": "goldleaf carp",
	"pesce ghiaccio": "icefish",
	"trota del salto": "leaping trout",
	"anguilla della notte": "night eel",
	"cicala del bosco": "woodland cicada",
	"scarabeo dorato": "golden beetle",
	"lumachina di pioggia": "rain snail",
	"rana blu": "blue frog",
	"damigella di velo": "veil damselfly",
	"carota": "carrot",
	"zucca": "pumpkin",
	"bacca": "berry",
	"mela": "apple",
	"pera": "pear",
	"fungo": "mushroom",
	"fungo porcino": "porcini mushroom",

	# Le forme con l'articolo: si traduce la frase GIÀ composta perché in
	# inglese l'articolo dipende dal suono del nome (a / an).
	"una farfalla rosa": "a pink butterfly",
	"una farfalla azzurra": "a blue butterfly",
	"una farfalla dorata": "a golden butterfly",
	"una farfalla di ciliegio": "a cherry-blossom butterfly",
	"una falena della luna": "a moon moth",
	"una libellula ambrata": "an amber dragonfly",
	"una farfalla di neve": "a snow butterfly",
	"una farfalla di bruma": "a mist butterfly",
	"una lucciola": "a firefly",
	"una lucciola regale": "a royal firefly",
	"una carpa dorata": "a golden carp",
	"un pesciolino azzurro": "a little blue fish",
	"una carpa rosina": "a rosy carp",
	"un girino": "a tadpole",
	"un pesce dell'alba": "a dawnfish",
	"una carpa foglia d'oro": "a goldleaf carp",
	"un pesce ghiaccio": "an icefish",
	"una trota del salto": "a leaping trout",
	"una anguilla della notte": "a night eel",
	"una cicala del bosco": "a woodland cicada",
	"uno scarabeo dorato": "a golden beetle",
	"una lumachina di pioggia": "a rain snail",
	"una rana blu": "a blue frog",
	"una damigella di velo": "a veil damselfly",
	"una carota": "a carrot",
	"una zucca": "a pumpkin",
	"una bacca": "a berry",
	"una mela": "an apple",
	"una pera": "a pear",
	"un fungo": "a mushroom",
	"un fungo porcino": "a porcini mushroom",

	# Gli indizi dell'enciclopedia: dicono DOVE e QUANDO, mai che aspetto ha.
	"Nel prato, di giorno. La più affettuosa.":
		"In the meadow, by day. The fondest of them all.",
	"Nel prato, di giorno, col cielo sereno negli occhi.":
		"In the meadow, by day, with a clear sky in its eyes.",
	"Un lampo d'oro nel prato, nelle ore di sole.":
		"A flash of gold in the meadow, in the sunlit hours.",
	"In primavera, di giorno, dove nevicano i petali di ciliegio.":
		"In spring, by day, where the cherry petals come down like snow.",
	"Nelle notti d'autunno, al chiaro di luna.":
		"On autumn nights, by the light of the moon.",
	"Sfiora il prato soltanto all'alba e al tramonto.":
		"It brushes the meadow only at dawn and at dusk.",
	"Rarissima: appare solo d'inverno, mentre la neve scende.":
		"Rarest of all: it comes only in winter, while the snow is falling.",
	"Aleggia nella nebbiolina del mattino, come un pensiero.":
		"It drifts in the morning mist, like a passing thought.",
	"Si accende vicino a te, quando cala la notte.":
		"It lights up close beside you, once the night comes down.",
	"Una luce più grande e più calda, nelle notti d'estate.":
		"A bigger, warmer light, on summer nights.",
	"Nello stagno, a qualsiasi ora. La prima amica di ogni canna.":
		"In the pond, at any hour. Every rod's first friend.",
	"Guizza nello stagno, quando gli pare.":
		"It darts about the pond, whenever it pleases.",
	"Timida e rara: lo stagno la nasconde bene.":
		"Shy and rare: the pond hides it well.",
	"Nello stagno, in primavera: una virgola con la coda.":
		"In the pond, in spring: a comma with a tail.",
	"Abbocca solo all'alba e al tramonto, coi colori del cielo.":
		"It bites only at dawn and dusk, wearing the colours of the sky.",
	"D'autunno, quando le foglie d'oro toccano l'acqua.":
		"In autumn, when the golden leaves touch the water.",
	"Sotto l'acqua fredda d'inverno, quasi trasparente.":
		"Under the cold winter water, almost see-through.",
	"Risale la corrente e salta dove la cascata spumeggia.":
		"It climbs the current and leaps where the waterfall froths.",
	"Un nastro d'ombra nella corrente, solo col buio fitto.":
		"A ribbon of shadow in the current, only in the deep dark.",
	"Canta sugli alberi del bosco, nelle giornate d'estate.":
		"It sings in the trees of the woods, on summer days.",
	"Un luccichio nell'erba, nelle notti d'estate.":
		"A glimmer in the grass, on summer nights.",
	"Esce solo quando piove, col suo guscio a spirale.":
		"It comes out only in the rain, with its spiral shell.",
	"Saltella sulla riva dello stagno, sotto la pioggia.":
		"It hops along the edge of the pond, under the rain.",
	"Quando lo stagno fuma di nebbia, all'alba, lei cuce l'aria.":
		"When the pond steams with mist at dawn, it stitches the air.",
	"Un profumo raro nel sottobosco d'autunno.":
		"A rare scent in the autumn undergrowth.",
	"Qualcuno l'ha vista, da qualche parte...":
		"Someone saw it once, somewhere...",

	# ------------------------------------------ le stagioni e il calendario
	"primavera": "spring",
	"estate": "summer",
	"autunno": "autumn",
	"inverno": "winter",
	"È arrivata la primavera: i ciliegi sono in fiore!":
		"Spring is here: the cherry trees are in bloom!",
	"È arrivata l'estate: il prato è di un verde pieno!":
		"Summer is here: the meadow has gone a deep, full green!",
	"È arrivato l'autunno: le foglie si accendono d'oro e di rame!":
		"Autumn is here: the leaves are catching fire in gold and copper!",
	"È arrivato l'inverno: la neve copre il villaggio!":
		"Winter is here: the snow has covered the village!",

	# le quattro feste dell'anno
	"notte delle lucciole": "firefly night",
	"sagra del raccolto": "harvest fair",
	"pupazzo di neve": "snowman day",
	"hanami sotto il Grande Albero": "hanami under the Great Tree",
	"la notte delle lucciole allo stagno": "firefly night at the pond",
	"la sagra del raccolto all'orto": "the harvest fair in the vegetable patch",
	"il pupazzo di neve in piazza": "the snowman in the square",
	"Domani è hanami: picnic sotto il Grande Albero!":
		"Tomorrow is hanami: a picnic under the Great Tree!",
	"Domani sera, allo stagno: la notte delle lucciole!":
		"Tomorrow evening, at the pond: firefly night!",
	"Domani è la sagra del raccolto: portate le ceste!":
		"Tomorrow is the harvest fair: bring your baskets!",
	"Domani, se nevica ancora: il pupazzo di neve in piazza!":
		"Tomorrow, if the snow keeps up: a snowman in the square!",
	"È hanami! Tutti al picnic, sotto la neve rosa dei petali!":
		"It's hanami! Everyone to the picnic, under the pink snow of the petals!",
	"La notte delle lucciole! Tutti allo stagno, a lume spento!":
		"Firefly night! Everyone to the pond, and every lamp out!",
	"La sagra del raccolto! Tutti all'orto con le ceste piene!":
		"The harvest fair! Everyone to the vegetable patch with baskets full!",
	"Il pupazzo di neve! Tutti in piazza a far palle di neve!":
		"Snowman day! Everyone to the square to roll snowballs!",
	"l'hanami sotto il Grande Albero, coi petali nel tè":
		"the hanami under the Great Tree, with petals in the tea",
	"la notte delle lucciole, contate a bocca aperta":
		"firefly night, counting them open-mouthed",
	"la sagra del raccolto, a pancia piena":
		"the harvest fair, on a full belly",
	"il pupazzo di neve in piazza, col naso di carota":
		"the snowman in the square, with his carrot nose",
	"Il pupazzo di neve si è sciolto. Alla prossima nevicata!":
		"The snowman has melted away. Until the next snowfall!",

	# i compleanni e la festa a sorpresa
	"%s segna il suo compleanno sulla lavagna: Giorno %d!":
		"%s chalks their birthday up on the board: Day %d!",
	"Oggi è il compleanno di %s! Preparagli una sorpresa…":
		"It's %s's birthday today! Get a surprise ready…",
	"FESTA A SORPRESA per %s! Tutto il villaggio accorre!":
		"A SURPRISE PARTY for %s! The whole village comes running!",
	"la festa a sorpresa di %s": "the surprise party for %s",
	"La festa più bella della mia vita!\nCome facevi a saperlo? Ah già…\nla lavagna. Grazie, di cuore.":
		"The loveliest party of my whole life!\nHow did you know? Oh — of course…\nthe chalkboard. Thank you, truly.",

	# la lavagna col gessetto
	"· il calendario ·": "· the calendar ·",
	"%s · G%d": "%s · D%d",
	"…e altri %d": "…and %d more",
	"mercante · G%d": "pedlar · D%d",
	"richieste appese · %d": "errands pinned up · %d",

	# il mercante col carretto
	"Domani arriva il mercante col suo carretto!":
		"Tomorrow the pedlar comes by with his cart!",
	"Il mercante ha aperto il carretto in piazza!":
		"The pedlar has opened up his cart in the square!",
	"Il mercante divora %s e ti riempie la dispensa!":
		"The pedlar wolfs down %s and fills your pantry to the brim!",
	"il piatto": "the dish",
	"«Un piatto caldo del tuo camino, e la dispensa è tua» — cucina qualcosa!":
		"«A hot dish off your own fire, and the pantry is yours» — go and cook something!",
	"E — baratta col mercante": "E — barter with the pedlar",

	# il pannello degli eventi in arrivo
	"E — il calendario del villaggio": "E — the village calendar",
	"~ Il calendario del villaggio ~": "~ The village calendar ~",
	"Stagione: %s   ·   giorno %d di 28": "Season: %s   ·   day %d of 28",
	"Giorno %d · %s  (%s)": "Day %d · %s  (%s)",
	"OGGI!": "TODAY!",
	"domani": "tomorrow",
	"tra %d giorni": "in %d days",
	"…e altri %d eventi più in là": "…and %d more events further off",
	"compleanno %s": "birthday %s",
	"del %s": "of %s",
	"della %s": "of %s",
	"dell'%s": "of %s",
	"di %s": "of %s",
	"arriva il mercante": "the pedlar arrives",
	"compleanno del villaggio": "the village's birthday",
	"una nuova stagione": "a new season",
	"~ le commissioni ~": "~ the errands ~",
	"✔ ce l'hai: consegnala!": "✔ you have it: go and deliver!",
	"E — chiudi": "E — close",

	# ------------------------------------------------ la dispensa e il camino
	# i plurali dell'orto e del bosco (il singolare è il nome del bestiario)
	"carote": "carrots",
	"zucche": "pumpkins",
	"bacche": "berries",
	"funghi": "mushrooms",
	"porcino": "porcini mushroom",
	"porcini": "porcini mushrooms",
	"mele": "apples",
	"pere": "pears",
	"3 carote": "3 carrots",
	"2 zucche": "2 pumpkins",
	"4 bacche": "4 berries",

	# le ricette del camino (col maiuscolo nel menu, minuscole nella frase)
	"Tè del prato": "Meadow tea",
	"Zuppa di carote": "Carrot soup",
	"Vellutata di zucca": "Velvety pumpkin soup",
	"Risotto ai funghi": "Mushroom risotto",
	"Spiedini di bosco": "Woodland skewers",
	"Crumble di bacche": "Berry crumble",
	"Tè alle bacche": "Berry tea",
	"Torta di mele": "Apple pie",
	"Pere al miele": "Honeyed pears",
	"tè del prato": "meadow tea",
	"zuppa di carote": "carrot soup",
	"vellutata di zucca": "velvety pumpkin soup",
	"risotto ai funghi": "mushroom risotto",
	"spiedini di bosco": "woodland skewers",
	"crumble di bacche": "berry crumble",
	"tè alle bacche": "berry tea",
	"torta di mele": "apple pie",
	"pere al miele": "honeyed pears",

	"~ Ricettario del camino ~": "~ The fireside recipe book ~",
	"E — ricettario del camino": "E — the fireside recipe book",
	"E — cucinare al riparo dalla pioggia": "E — cook out of the rain",
	"E — chiudi il ricettario": "E — close the recipe book",
	"Dispensa: %s": "Pantry: %s",
	"vuota (orto e bosco ti aspettano)":
		"empty (the vegetable patch and the woods are waiting)",
	"senza ingredienti": "nothing needed",
	"Una porzione è finita nelle tasche (Tab): regalala a un amico!":
		"A helping has gone into your Pockets (Tab): give it to a friend!",

	# ------------------------------------------------- l'orto e le aiuole
	"E — pianta i semi": "E — plant the seeds",
	"E — semina le %s": "E — sow the %s",
	"E — annaffia": "E — water it",
	"cresce stanotte ✿": "it grows tonight ✿",
	"E — raccogli il mazzolino": "E — pick the posy",
	"E — raccogli le %s": "E — pick the %s",
	"+%s nella dispensa!": "+%s in the pantry!",
	"E — raccogli il fungo": "E — pick the mushroom",
	"E — raccogli il porcino!": "E — pick the porcini!",
	"+1 fungo nella dispensa!": "+1 mushroom in the pantry!",
	"+1 fungo porcino nella dispensa! Che profumo raro.":
		"+1 porcini mushroom in the pantry! What a rare scent.",

	# ------------------------------------------------------- il frutteto
	"melo": "apple tree",
	"pero": "pear tree",
	"E — pianta il semino raro": "E — plant the rare little seed",
	"Il semino raro è a dimora. Chissà cosa nasconde…":
		"The rare little seed is bedded down. Who knows what it's hiding…",
	"🌸 Il piccolo %s è in fiore: domani i primi frutti!":
		"🌸 The little %s is in blossom: tomorrow, the first fruit!",
	"Il %s è cresciuto: i primi %s pendono dai rami!":
		"The %s has grown up: the first %s are hanging from the branches!",
	"+%d %s nella dispensa! (il %s rifrutta tra %d giorni)":
		"+%d %s in the pantry! (the %s will fruit again in %d days)",

	# ---------------------------------------------------- l'ascia e il bosco
	"colpo": "blow",
	"colpi": "blows",
	"E — taglia la legna (%d %s)   ·   hai %d legna":
		"E — chop firewood (%d %s)   ·   you have %d logs",
	"E — estirpa il ceppo (libera il posto)":
		"E — pull up the stump (it frees the spot)",
	"+%d legna": "+%d logs",
	"+1 legna · il posto è libero": "+1 log · the spot is free",
	"serve %d legna in più": "%d more logs needed",

	# ------------------------------------ il retino, la canna e i barattoli
	"E — acchiappa %s!": "E — catch %s!",
	"Hai preso %s! (n. %d)": "You caught %s! (no. %d)",
	"%s — che rarità! Una stellina per te.": "%s — what a rarity! A star for you.",
	"in collezione: %s": "into the collection: %s",
	"E — pesca": "E — fish",
	"E — pesca dal fiume": "E — fish the river",
	"E — tira!": "E — pull!",

	# ------------------------------------------------------------ gli scavi
	"E — scava!": "E — dig!",
	"Sotto terra: %d noccioline! 🌰": "Down in the soil: %d acorns! 🌰",
	"Sotto terra: %s, dritta in dispensa!":
		"Down in the soil: %s, straight into the pantry!",
	"Sotto terra: una campanella di coccio. Suona ancora!":
		"Down in the soil: a little earthenware bell. It rings still!",
	"Sotto terra… una stellina! ⭐": "Down in the soil… a star! ⭐",

	# --------------------------------------------------- il nido e Briciola
	"🪺 Nella Casetta uccellini è comparso un nido, con tre uova!":
		"🪺 A nest has appeared in the Birdhouse, with three eggs in it!",
	"🐣 Cip! Due passerotti prendono il volo… ma uno resta.\nÈ %s — e la prima cosa che ha visto sei TU.":
		"🐣 Cheep! Two little sparrows take wing… but one stays.\nThis is %s — and the first thing they ever saw was YOU.",
	"%s sta crescendo: spuntano le penne della coda!":
		"%s is growing up: the tail feathers are coming through!",
	"🕊 %s è adulta: il cielo è suo. Ma ogni mattina, vedrai, torna.":
		"🕊 %s is grown: the sky is theirs now. But every morning, you'll see, they come back.",
	"🌧 %s trema sotto la pioggia: portala al riparo!":
		"🌧 %s is shivering in the rain: get them under cover!",
	"💛 %s si scrolla le piume, al riparo. Ti si strofina contro: grazie.":
		"💛 %s shakes out their feathers, safe and dry. They nuzzle up to you: thank you.",
	"%s è corsa a ripararsi da sola. (Un ombrello, la prossima volta?)":
		"%s ran off to shelter all alone. (An umbrella, next time?)",
	"🕊 %s è tornata a salutarti — e nel becco ha un semino raro!":
		"🕊 %s has come back to say hello — with a rare little seed in their beak!",
	"🕊 %s è tornata a salutarti: due saltelli e un cinguettio, come ogni mattina.":
		"🕊 %s has come back to say hello: two hops and a chirp, as every morning.",

	# ------------------------------------------------------- il concertino
	"un vicino": "a neighbour",
	"%s e %s": "%s and %s",
	"Il carillon chiama: %s si stringono attorno alla musica…":
		"The music box is calling: %s gather in around the tune…",
	"…e l'ultima nota resta sospesa nell'aria. ":
		"…and the last note hangs on in the air.",

	# -------------------------------------------- nascondino nel bosco
	"tronco": "fallen log",
	"ceppo": "stump",
	"masso": "boulder",
	"%s ti saltella incontro: nascondino nel bosco! (avvicìnati per dire di sì)":
		"%s comes hopping up to you: hide-and-seek in the woods! (step closer to say yes)",
	"%s sorride: «magari domani!»": "%s smiles: «tomorrow, perhaps!»",
	"Il bosco è troppo giovane per nascondersi: sarà per un'altra volta.":
		"The woods are too young to hide in yet: another time, then.",
	"Conta fino a dieci! %s corrono a nascondersi nel bosco…":
		"Count to ten! %s run off to hide in the woods…",
	"Nascondino nel bosco  ·  trovati 0/%d  ·  prima del tramonto":
		"Hide-and-seek in the woods  ·  found 0/%d  ·  before sundown",
	"Nascondino nel bosco  ·  trovati %d/%d  ·  prima del tramonto":
		"Hide-and-seek in the woods  ·  found %d/%d  ·  before sundown",
	"Pronti! Cercali nel bosco prima del tramonto.":
		"Ready! Go and find them in the woods before sundown.",
	"Il sole tocca gli alberi: ultimi minuti!":
		"The sun is touching the treetops: last few minutes!",
	"Trovato! %s sbuca da dietro il %s, rosso rosso ma raggiante.":
		"Found you! %s pops out from behind the %s, red as a berry and beaming.",
	"Trovato! %s non tratteneva più le risatine dietro il %s.":
		"Found you! %s couldn't hold the giggles in behind the %s a moment longer.",
	"Trovato! %s ride di gusto dietro il %s.":
		"Found you! %s laughs out loud behind the %s.",
	"Trovati tutti prima del tramonto! Il bosco è pieno di risate.":
		"All of them found before sundown! The woods are full of laughter.",
	"Il sole scende: escono dai nascondigli ridendo. Rivincita domani!":
		"The sun goes down: out they come from their hiding places, laughing. A rematch tomorrow!",

	# ----------------------------------- il meteo, la barchetta, l'onsen
	"La nebbiolina del mattino avvolge il villaggio…":
		"The morning mist wraps itself around the village…",
	"E — sali sulla barchetta": "E — climb into the rowboat",
	"E — scendi a riva": "E — step ashore",
	"I remi in zampa: su per il fiume! (si rema come si cammina, E per scendere)":
		"Oars in paw: away up the river! (you row as you walk, E to step off)",
	"E — immergiti nell'onsen ♨": "E — sink into the hot spring ♨",
	"E — esci dall'acqua (che pace…)": "E — out of the water (what peace…)",
	"E — stendi il bucato": "E — hang out the washing",
	"E — ritira il bucato": "E — take in the washing",

	# ------------------------------------ la casa, le sedute, il carillon
	"Questo lettino è di qualcun altro!": "This little bed belongs to somebody else!",
	"È già casa tua!": "This is home already!",
	"Casa impostata: è qui che ti sveglierai!":
		"Home it is: this is where you'll wake up!",
	"E — siediti": "E — sit down",
	"E — alzati": "E — get up",
	"E — dormi": "E — sleep",
	"E — dormi fino al mattino": "E — sleep until morning",
	"H — imposta casa": "H — make this home",
	"Buongiorno!": "Good morning!",
	"Buongiorno!\nGiorno %d": "Good morning!\nDay %d",
	"E — carica il carillon (cambia musica)": "E — wind the music box (it changes the tune)",
	"Il carillon gira piano: %s…": "The music box turns slowly: %s…",
	"la musichetta di sempre": "the same old tune",
	"la ninnananna": "the lullaby",
	"il valzer": "the waltz",

	# ------------------------------------------------- la modalità foto
	"WASD vola · mouse guarda · Q/E giù/su · rotella zoom · clic scatta · P esci":
		"WASD fly · mouse look · Q/E down/up · wheel zoom · click to shoot · P to leave",
	"Foto salvata!  (user://photos)": "Photo saved!  (user://photos)",

	# ---------------------------------------- ciò che si incide sugli anelli
	"una fioritura nel giardino": "a blooming in the garden",

	# le Promesse: la riga di gessetto sulla lavagna e la voce del pannello
	"%s ti aspetta: %s": "%s is waiting for you: %s",
	"la bruma": "the mist",
	"la levata": "the rising",
	"la prima neve": "the first snow",
	"quella volta che ti ho aspettato, e sei venuto":
		"that time I waited for you, and you came",
}


static func tabella() -> Dictionary:
	return T
