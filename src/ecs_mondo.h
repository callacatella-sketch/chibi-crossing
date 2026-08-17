#ifndef CHIBI_ECS_MONDO_H
#define CHIBI_ECS_MONDO_H

#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/vector3.hpp>


// IL REGISTRO. Un Node Godot che possiede un registry EnTT e gli fa fare
// UNA cosa sola: decidere se un residente sta sveglio, dorme, o è rimasto
// fuori perché qualcuno gli ha chiuso la porta.
//
// Perché così poco: la logica degli NPC di questo gioco sono ~15.000 righe
// di GDScript con undici sistemi che impongono stati a evento (il concerto,
// il salone, il nascondino, le promesse…). Un'autorità C++ che scrivesse
// «lo stato» ogni frame entrerebbe in guerra silenziosa con loro — uno dei
// due vince e nessuno se ne accorge. Qui l'autorità è su UN canale, quello
// del sonno, e su quel canale nessun altro scrive (vedi CLAUDE.md).
//
// COSA NON C'È, e non per dimenticanza:
//  · nessun `_process` / `_physics_process`. Il passo è `avanza()`, chiamato
//    da Visitors.gd dentro il suo frame: l'ordine fatti → passo →
//    applicazione dev'essere deterministico e guidabile dai test. (E i
//    virtuali di una GDExtension non sono chiamabili per nome da GDScript.)
//  · nessuna persistenza, nessun gruppo "persistable", nessun save/load.
//    È la garanzia MECCANICA che questa classe non tocchi village.json.
//  · nessun RNG. I dadi del villaggio si salvano (Animo._rng), e un secondo
//    generatore in C++ sarebbe una seconda storia.
//  · nessuna etichetta, nessun nome. Il villaggio ha già due anagrafi (nome
//    e label): questa non deve diventare la terza. Attraversa il ponte solo
//    un handle numerico, che vive in RAM e non finisce su disco.
class EcsMondo : public godot::Node {
	GDCLASS(EcsMondo, godot::Node)

	// PIMPL: entt.hpp (2.9 MB) vive SOLO dentro ecs_mondo.cpp. Senza, ogni
	// unità di compilazione che includesse questo header se lo tirerebbe
	// dietro, e il tempo di build della CI (che non ha cache) esploderebbe.
	struct Registro;
	Registro *_reg = nullptr;

	// L'ora dell'ultimo `avanza()`. Serve a `in_finestra()`, che è una
	// lettura per la marionetta e per i test: così la finestra continua a
	// esistere in UN posto solo (il sistema puro) e il chiamante non ha
	// modo di chiedersela con un'ora sua, che è come nascono due verità.
	double _ultima_ora = 0.0;

	// --- FASE 4: L'OROLOGIO MONOTONO, in secondi.
	//
	// `_ultima_ora` NON serve alla memoria, e sarebbe il difetto più
	// silenzioso di tutta questa fase: `p_ora` è la FRAZIONE DI GIORNATA
	// (0..1) che governa la finestra del sonno — torna indietro a ogni
	// mezzanotte e in tutti i banchi di prova resta ferma per minuti
	// («avanza(DT, 0.5)» diecimila volte). Un ricordo timbrato con quella
	// non decadrebbe mai, oppure ringiovanirebbe di colpo all'alba: e un
	// grafo eterno, con la suite verde, è precisamente il guasto che
	// `peso()` è stato scritto per rendere impossibile.
	//
	// L'orologio monotono della memoria e del sistema
	double _tempo = 0.0;

	// Contesto ambientale (temperatura, luce, pioggia, ora)

protected:
	static void _bind_methods();

public:
	// Il registry nasce nel COSTRUTTORE e non in `_ready`: la suite istanzia
	// le classi C++ con `.new()` FUORI dall'albero della scena e non chiama
	// mai `_ready` (convenzione dei test del progetto).
	EcsMondo();
	~EcsMondo();

	enum Stato {
		STATO_SVEGLIO = 0,
		STATO_DORME = 1,
		STATO_FUORI = 2,
	};


	// Le azioni dell'agenda. Il GDScript non scrive un indice a mano da
	// nessuna parte: legge queste costanti, come già fa per STATO_*.
	enum Azione {
		AZ_NESSUNA = -1,
		AZ_SPUNTINO = 0,
		AZ_RIPOSO = 1,
		AZ_CHIACCHIERE = 2,
		AZ_CURA_GIARDINO = 3,
		AZ_MERAVIGLIA = 4,
		AZ_STELLA = 5,
		AZ_REGIA = 6,
		AZ_GIRONZOLA = 7,
	};

	// --- FASE 4: il grafo dei ricordi. Stesse costanti di chibi::Verbo,
	// chibi::Cosa e chibi::Bandiera, esposte al GDScript perché nessuno
	// scriva 0/1/2/4 a mano — la stessa disciplina di STATO_* e AZ_*.
	// Che le due copie non divergano lo tiene un test, che confronta
	// ognuna di queste costanti con `indice_verbo`/`indice_cosa` e con
	// `debug_grafo_costanti()`: è già successo, con la scala della
	// ribellione, che due tabelle gemelle prendessero strade diverse.
	enum Verbo {
		V_ANNAFFIA = 0,
		V_SEMINA = 1,
		V_RACCOGLIE = 2,
		V_COSTRUISCE = 3,
		V_TAGLIA = 4,
		V_PESCA = 5,
		V_CUCINA = 6,
		V_DONA = 7,
		N_VERBI = 8,
	};

	enum Cosa {
		C_FIORE = 0,
		C_CIBO = 1,
		C_CASA = 2,
		C_FUOCO = 3,
		C_PESCE = 4,
		C_AMICO = 5,
		N_COSE = 6,
	};

	enum Bandiera {
		R_SENTITO = 1,
		R_SU_DI_ME = 2,
		R_DETTO = 4,
	};

	// --- anagrafe -------------------------------------------------------
	// L'handle porta dentro la VERSIONE dell'entità EnTT: l'handle di un
	// vicino congedato non risolve mai a un residente nuovo.
	int64_t registra(const godot::PackedStringArray &p_indole, const godot::String &p_quirk);
	// La proiezione del DNA si può RIFARE. Serve perché indole e quirk sono
	// scrivibili a runtime (Visitors.debug_quirk → DebugHarness): una
	// fotografia scattata alla registrazione e mai più aggiornata farebbe
	// andare a letto alle 0.80 uno che è appena diventato nottambulo, e il
	// commento che giurava il contrario sarebbe stato una bugia.
	void riproietta(int64_t p_id, const godot::PackedStringArray &p_indole, const godot::String &p_quirk);
	void dimentica(int64_t p_id);
	void dimentica_tutti();
	bool conosce(int64_t p_id) const;
	int quanti() const;

	// --- i fatti che il mondo riferisce (una chiamata per residente/frame)
	// Sono FATTI, non decisioni: il C++ non entra mai nell'albero della
	// scena e non chiama mai una Callable.
	void riferisci(int64_t p_id, bool p_nascosto, bool p_corpo_libero, bool p_porta_aperta);

	// --- i fatti della FASE 2 (una chiamata per residente per frame) -----
	// I bisogni arrivano come SPECCHIO: il proprietario resta VillagerBrain
	// (sono persistiti), qui se ne tiene una copia di sola lettura per il
	// frame in corso.
	void riferisci_bisogni(int64_t p_id, const godot::PackedFloat64Array &p_bisogni);
	void riferisci_agenda(int64_t p_id, int p_fatti, bool p_corpo_a_riposo, bool p_zittita);
	// Il dado, tirato in GDScript e spinto di qua già estratto. Va rifornito
	// solo quando serve (vedi `vuole_dado`): congelarlo per DECISIONE invece
	// di ritirarlo a ogni frame è una delle tre leve contro il tremolio —
	// senza, misurato, si passa da 0.2 a 922 cambi d'idea al minuto.
	void semina_agenda(int64_t p_id, const godot::PackedFloat64Array &p_jitter);
	bool vuole_dado(int64_t p_id) const;

	// --- il passo -------------------------------------------------------
	void avanza(double p_delta, double p_ora);

	// --- letture (la marionetta) ----------------------------------------
	int azione(int64_t p_id) const;
	// IL FRONTE, ed è l'unico permesso di recitare: `_recita` va chiamata
	// SOLO quando l'azione cambia. Non è una mitigazione statistica del
	// tremolio, è l'impossibilità strutturale di rilanciare `do_task` due
	// frame di fila — che è ciò che impedirebbe al corpo di ARRIVARE.
	bool azione_cambiata(int64_t p_id) const;
	// L'argmax anche quando non si commuta: serve alla scena dell'esitazione
	// (si voleva fare una cosa e se ne sta facendo un'altra).
	int azione_desiderata(int64_t p_id) const;
	double azione_da(int64_t p_id) const;

	int stato(int64_t p_id) const;
	double da_quanto(int64_t p_id) const;
	bool in_finestra(int64_t p_id) const;

	// --- tabelle: i NOMI restano in GDScript, qui solo la traduzione -----
	int maschera_indole(const godot::PackedStringArray &p_nomi) const;
	int indice_quirk(const godot::String &p_nome) const;
	int maschera_fatti(const godot::PackedStringArray &p_nomi) const;
	// --- FASE 3: il pianificatore. Metodi CONST e senza entità: il piano
	// non entra nell'ECS. Il C++ possiede l'ALGORITMO; la vita del piano
	// (i corpi, i segnali, l'albero della scena) resta in GDScript, dove
	// stanno le cose che il piano muove.
	godot::PackedInt32Array pianifica(int p_stato, int p_obiettivo,
			const godot::PackedFloat64Array &p_cammino) const;
	int indice_operatore(const godot::String &p_nome) const;
	int maschera_obiettivo(const godot::String &p_nome) const;
	godot::Dictionary debug_piano(int p_stato, int p_obiettivo,
			const godot::PackedFloat64Array &p_cammino) const;
	godot::Dictionary debug_operatore(int p_id) const;
	void debug_tara_piani(double p_budget, int p_max_nodi, int p_max_prof);
	int indice_azione(const godot::String &p_nome) const;
	int indice_bisogno(const godot::String &p_nome) const;

	// --- oracoli per i test (precedente: EcosystemManager::debug_farfalla)
	godot::Dictionary debug_entita(int64_t p_id) const;
	bool debug_in_finestra(int p_maschera, int p_quirk, double p_ora) const;
	// Quante entità portano una posa. In Fase 1 deve essere SEMPRE 0: un
	// componente scritto ogni frame e letto da nessuno è un motore acceso a
	// vuoto. Il giorno in cui arriva il primo lettore vero, questo test si
	// capovolge di proposito.
	int debug_quante_pose() const;
	// L'ORACOLO DEI PUNTEGGI, e il modulatore lo costruisce LUI: otto 1.0
	// letterali, nati in C++. È la strada della prova di equivalenza.
	godot::PackedFloat64Array debug_punteggi(const godot::PackedFloat64Array &p_bisogni,
			int p_fatti, int p_indole, int p_quirk) const;
	// --- FASE 4 (P3): lo stesso oracolo, col modulatore che arriva DAL
	// PONTE. Esiste per una ragione sola, ed è la lezione già pagata due
	// volte in Fase 1: se `p_mod` fosse nullable, la prova di equivalenza
	// passerebbe dal ramo `nullptr` e NON PROVEREBBE IL CODICE NUOVO. Con
	// questo metodo i 67.200 confronti bit-esatti si rifanno passando otto
	// 1.0 da GDScript, e la stessa spazzata si rifà una terza volta con un
	// modulatore che MORDE, pretendendo il valore esatto: è quest'ultima
	// che diventa rossa se qualcuno svuota la moltiplicazione.
	godot::PackedFloat64Array debug_punteggi_mod(const godot::PackedFloat64Array &p_bisogni,
			int p_fatti, int p_indole, int p_quirk,
			const godot::PackedFloat64Array &p_mod) const;
	// Le costanti dell'innesto (DELTA_MAX) e la taratura viva del registro,
	// così il test non riscrive un solo numero a mano: la relazione che
	// tiene in piedi la regola 8 è `delta_max < margine`, e va letta, non
	// ricordata.
	godot::Dictionary debug_costanti_agenda() const;
	godot::Dictionary debug_agenda(int64_t p_id) const;
	// --- FASE 4: l'ORACOLO DELLE TINTE.
	// Costruisce un grafo dai ricordi passati e ne torna la lettura
	// (`chibi::valuta`) e i modulatori (`chibi::modulatori`) — le stesse due
	// funzioni che il gioco chiamerà, non una scorciatoia scritta per il test
	// (è il difetto che la revisione della Fase 1 ha trovato).
	//
	// `p_ricordi` è piatto, CINQUE double per ricordo, nell'ordine
	// [verbo, bandiere, quante, intensita, quando]. Manca il `soggetto`
	// apposta: `valuta()` non lo guarda, e un campo che l'oracolo accetta ma
	// il sistema ignora è una bugia in una firma. `cosa` non si passa affatto:
	// la decide COSA_DEL_VERBO, che è la tabella unica.
	//
	// I ricordi si posano DIRITTI nel grafo, senza passare da `inserisci()`:
	// qui si prova la LETTURA, e la fusione (che unirebbe due ricordi gemelli
	// a otto secondi di distanza) è provata da test_grafo_ricordi. Le costanti
	// del C++ (le bandiere, la tabella verbo→cosa, i conteggi) tornano dentro
	// il dizionario, così il test non ne scrive nemmeno una a mano.
	godot::Dictionary debug_occ(const godot::PackedFloat64Array &p_ricordi,
			const godot::PackedFloat64Array &p_gusto, double p_ora,
			const godot::Dictionary &p_taratura) const;
	// La taratura si può muovere SOLO da un test: in partita i numeri sono
	// quelli misurati (vedi TaraturaAgenda). Serve alle ablazioni, che
	// guastano una valvola per volta e pretendono che qualcosa fallisca.
	void debug_tara_agenda(double p_t_min, double p_bonus, double p_margine, double p_tetto);

	// --- FASE 4 (P1): il GRAFO DEI RICORDI, interrogabile SENZA il ponte.
	//
	// In questo passo il grafo non vive ancora su nessun componente (ci
	// arriva in P4), e un sistema puro che nessuno può interrogare è un
	// sistema che nessuno può FALSIFICARE: resterebbe verde svuotandolo.
	// Perciò questi quattro metodi, e sono dichiarati per quello che sono.
	//
	// Sono CONST e SENZA ENTITÀ: il grafo attraversa il ponte come
	// Dictionary e torna indietro come Dictionary, quindi EcsMondo non ne
	// tiene nessuna copia. Non esiste uno stato di prova che possa restare
	// sporco fra un caso e l'altro — il banco dei Sogni lo è stato una
	// volta, ed è costato tre rese lette come un errore di illuminazione.
	//
	// FORMA DEL RICORDO (Dictionary, chiavi = campi di chibi::Ricordo):
	//   soggetto, verbo, cosa, bandiere, quante, intensita, px, pz, quando
	// FORMA DEL GRAFO (Dictionary): { "ricordi": Array, "versione": int }
	// — `n` non si passa: è la lunghezza dell'array, così non può esistere
	// un grafo che dichiara sei righe e ne porta due.
	godot::Dictionary debug_grafo_inserisci(const godot::Dictionary &p_grafo,
			const godot::Dictionary &p_ricordo, double p_ora, double p_mezza_vita) const;
	double debug_grafo_peso(const godot::Dictionary &p_ricordo, double p_ora,
			double p_mezza_vita) const;
	int debug_grafo_da_raccontare(const godot::Dictionary &p_grafo, double p_ora,
			double p_mezza_vita) const;
	// Le costanti del C++ (MAX_FATTI, la finestra di fusione, i conteggi, il
	// soggetto nullo, la tabella verbo→cosa): così il test non ne scrive
	// nemmeno una a mano, e cambiarne una di qua fa muovere il test invece
	// di farlo mentire.
	godot::Dictionary debug_grafo_costanti() const;

	// --- FASE 4 (P4): IL GRAFO VIVE SULL'ENTITÀ -------------------------
	//
	// Da qui in poi la memoria non è più un oracolo: è un componente di un
	// residente vero, e `avanza()` la legge per inclinare i suoi punteggi.

	// HA VISTO. Incide un ricordo nel grafo di `p_id` e torna l'indice della
	// riga scritta, oppure **-1 se non ha scritto niente** (verbo fuori
	// tabella, oppure il ricordo era il più debole dei venticinque). Chi
	// chiama deve poter distinguere i due casi: un ricordo perso in silenzio
	// è ciò che questa uscita esiste per rendere visibile.
	//
	// COSA QUESTA FUNZIONE NON DECIDE, e non è una dimenticanza: **chi ha
	// visto**. Il predicato del testimone (sveglio, non nascosto, non in
	// scena, entro il raggio) vive in UNA funzione sola, `Visitors.testimoni`
	// in GDScript, perché le cose che decidono chi c'era stanno nell'albero
	// della scena. Riscriverne un pezzo qui vorrebbe dire due predicati che
	// divergono in silenzio — e il guasto sarebbe una conseguenza senza
	// premessa, cioè la cosa che insegna al giocatore che i vicini reagiscono
	// a caso.
	//
	// `p_soggetto` è l'handle di CHI ha ricevuto il gesto (SOGG_NESSUNO, o
	// un id negativo, se il gesto non era per nessuno). `R_SU_DI_ME` non è un
	// parametro: si DERIVA dal confronto `p_soggetto == p_id`. Un booleano in
	// più sarebbe un secondo modo di dire la stessa cosa, cioè un modo di
	// dirla diversa.
	//
	// L'intensità non si passa: chi vede con i propri occhi vede al massimo.
	// L'unica cosa che smorza, in tutta la fase, è il passaparola.
	int osserva(int64_t p_id, int p_verbo, const godot::Vector3 &p_dove, int64_t p_soggetto);

	// GLIEL'HA DETTO. `p_a` racconta a `p_b` la notizia più forte che `p_b`
	// non conosce già, e torna la **cosa** di cui si è parlato (indice di
	// chibi::Cosa) oppure -1 se non c'era niente da dirsi — che è il caso
	// normale. È quel valore a diventare il simbolo nella nuvoletta: il
	// villaggio non commenta MAI a parole, e l'unica uscita legittima di
	// questo sistema è un simbolo scambiato fra due di LORO.
	//
	// UNA COSA FUORI POSTO, MAI DUE. Nel passaggio si perde il SOGGETTO (il
	// ricordo di `p_b` dice «qualcuno», non un nome) e l'intensità si smorza
	// di `p_smorzamento` — che arriva dal chiamante (Villaggio.SMORZAMENTO) e
	// non è ricopiato qui. Il verbo, la cosa e il luogo passano INTATTI: se
	// si deformassero anche quelli, la nuvoletta che esce alla fine della
	// catena non significherebbe più niente, e un pettegolezzo che non
	// significa niente è rumore.
	//
	// E PASSA ANCHE IL FREDDO. L'eco nasce con l'intensità già ridotta dal
	// tempo che il ricordo dell'ORIGINALE ha preso (`chibi::sconto_tempo`),
	// perché `inserisci` ritimbra sempre `quando` ad adesso: senza quel
	// fattore la voce ripartiva da capo e — misurato — dopo venti minuti
	// pesava 562 volte l'occhio che l'aveva vista. Con il fattore vale
	// `smorzamento × il peso di chi l'ha vista`, adesso e per sempre.
	//
	// E da `p_b` non riparte: il suo ricordo porta `R_SENTITO`, e
	// `da_raccontare` salta i sentiti. Una notizia non è un broadcast.
	int racconta(int64_t p_a, int64_t p_b, double p_smorzamento);

	// LO SPECCHIO DEL GUSTO, come `riferisci_bisogni`: il proprietario resta
	// il GDScript (scenes/npc/Gusto.gd, derivato da dna.weights + indole,
	// entrambi mutabili a runtime), qui se ne tiene una copia. Si chiama
	// quando i valori CAMBIANO davvero — confronta-e-riproietta, non a ogni
	// frame — ed è lo stesso mestiere di `riproietta()` per il DNA.
	void riferisci_gusto(int64_t p_id, const godot::PackedFloat64Array &p_gusto);

	// IL RITMO DEL MONDO. Le mezze vite dei ricordi si DERIVANO dal ciclo del
	// giorno (`DayNight.cycle_seconds`), non si riscrivono: un villaggio con
	// le giornate lunghe ha ricordi lunghi, e il giorno che qualcuno muove il
	// ciclo non deve andare a cercare un 120 nascosto in un header.
	void imposta_ritmo(double p_ciclo_secondi);

	// --- FASE 4 (P6): LE TRE LETTURE VIVE -------------------------------
	//
	// Fino a qui il cuore di un vicino si poteva leggere SOLO da
	// `debug_emozioni`/`debug_grafo`, che sono oracoli: allocano un Dictionary
	// e tre array per rispondere, e portano `debug_` nel nome perché il gioco
	// non deve chiamarli. Ma senza una lettura vera l'emozione non poteva
	// uscire dall'agenda — e un motore che nessuno può interrogare produce
	// esattamente una cosa: niente.
	//
	// Sono TRE e non una perché hanno tre chiamanti diversi, ognuno col suo
	// momento (la scelta del riposo, la scelta dell'aiuola, il passaggio
	// giornaliero della memoria). Una lettura unica che le torna tutte e tre
	// sarebbe un Dictionary in più per frame e — peggio — una firma in cui
	// nessuna delle tre regole si può guastare da sola, cioè tre guardie che
	// nessun test può far diventare rosse una per volta.
	//
	// Tutte e tre sono CONST e non muovono niente: chiedere non cambia.

	// QUANTO TI AMMIRA, adesso. È `Tinte.ammirazione`: la somma delle sei
	// tinte, cioè quanto pesa in questo momento tutto ciò che ti ha visto
	// fare. Zero per chi non ha visto niente — che è il caso normale.
	//
	// A cosa serve, ed è l'unico uso che ha il permesso di avere: SPOSTARE
	// UN'ANCORA, mai muovere un corpo. Chi ti ammira, quando decide di
	// riposare, cerca una panchina partendo da un punto un po' più vicino a
	// dove sei tu. Non ti segue, non ti parla, non si avvicina: ventotto
	// vicini che orbitano attorno al giocatore sarebbero un incubo, e ci si
	// arriva TARANDO BENE un sistema progettato male (regola 5 della Fase 4).
	double ammirazione(int64_t p_id) const;

	// DOVE L'HA VISTO. La posizione del ricordo più PESANTE fra quelli che
	// riguardano `p_cosa` — è la scena 4, «l'aiuola che ha visto»: Mochi
	// torna all'orto e ritrova il proprio gesto, nello stesso punto, fatto da
	// un altro.
	//
	// IL RIPIEGO È UN PARAMETRO, e non è pigrizia: se questa funzione
	// tornasse un sentinella (uno zero, un infinito, un booleano a parte) ci
	// sarebbe un chiamante che prima o poi si dimentica di guardarlo, e il
	// corpo partirebbe verso l'origine del mondo. Così invece «non ricordo
	// niente» e «ricordo casa mia» sono lo stesso identico Vector3, e il
	// degrado va da solo verso il comportamento di sempre.
	//
	// I ricordi SENTITI contano: la posizione attraversa il passaparola
	// intatta (vedi `racconta`), ed è ciò che permette a un terzo che non
	// c'era di andare all'aiuola giusta — la sola prova che un pettegolezzo
	// ha una conseguenza nel mondo e non solo in un dizionario.
	//
	// LA SOGLIA È LA RIGA PER CUI UN'ANCORA TORNA A CASA, e arriva dal
	// chiamante come lo smorzamento in `racconta`. Sotto quel peso il
	// ricordo non indica più niente e si torna al ripiego: senza pavimento
	// bastava un peso > 0, che `2^(-dt/mv)` non raggiunge prima di ~1074
	// mezze vite — cioè l'ancora spostata da un gesto non tornava MAI
	// indietro. Zero riproduce il comportamento di prima, ed è così che il
	// test lo può falsificare.
	godot::Vector3 dove(int64_t p_id, int p_cosa, double p_soglia,
			const godot::Vector3 &p_se_niente) const;

	// COSA VALE LA PENA RICORDARSI PER DAVVERO. Torna la `cosa` del ricordo
	// più pesante fra quelli VISTI COI PROPRI OCCHI, se supera `p_soglia`;
	// -1 altrimenti, ed è il caso normale.
	//
	// È l'unica cosa di tutta la Fase 4 che attraversa un riavvio, e ci
	// attraversa passando da un canale che ESISTE GIÀ e non è mio:
	// `VillagerBrain.remember()`, persistito, limitato a sei, con un
	// consumatore che lo mette in scena senza parole (il simbolo che esce in
	// una chiacchiera). Il grafo dei ricordi, lui, non si salva.
	//
	// DUE REGOLE, ed entrambe si possono guastare da sole:
	//  · **solo i VISTI**. Una voce non diventa un ricordo permanente: se lo
	//    diventasse, una diceria sopravviverebbe alla propria fonte, e questo
	//    gioco ha già scritto (in `Animo.senti_dire`) che quella è la via più
	//    corta perché una storia triste diventi una gogna.
	//  · **la SOGLIA arriva dal chiamante**, come lo smorzamento in
	//    `racconta`: è una decisione di gioco, e le decisioni di gioco stanno
	//    dove si leggono. Un'occhiata sola vale esattamente 1.0 — chi vuole
	//    che una passata di sfuggita non diventi un ricordo di una vita
	//    chiede più di uno.
	int cosa_da_ricordare(int64_t p_id, double p_soglia) const;

	// --- FASE 5 (P3): L'INJECTION -----------------------------------------
	//
	// Un modello linguistico ha scritto un JSON, il Giudice l'ha collaudato,
	// e quello che attraversa il ponte sono DUE INTERI E UNA LISTA DI INDICI.
	// Mai la stringa.
	//
	// ⚠️ E QUI C'È UNO SCOSTAMENTO DICHIARATO dal piano dell'autore, che dice
	// «il JSON viene parsato dal C++». Il JSON si apre in GDScript
	// (`JSON.parse_string`), per due ragioni che tirano nella stessa
	// direzione:
	//  1. **il collaudo di una deduzione è già in GDScript** ed è tutto lì
	//     (`Giudice.utile`, che sa quali obiettivi il mondo può servire
	//     ADESSO e quali ricordi sono ancora vivi). Un parser di qua
	//     vorrebbe dire due posti che decidono se una deduzione è buona, e
	//     questo progetto ha già pagato tre volte le tabelle gemelle;
	//  2. **il testo di un modello è l'ingresso più ostile del gioco.** Un
	//     parser scritto a mano in C++ su quell'ingresso è una superficie
	//     nuova, in un cuore che gira dentro il processo del giocatore. In
	//     GDScript un JSON malformato torna `null` e basta.
	// Quello che attraversa il confine, come per il foglio del Pensatoio,
	// sono BYTE — e i byte non portano una frase allo schermo.

	// DEDUCE. Torna l'indice della deduzione, oppure **-1 se non ha scritto
	// niente** (obiettivo che non è uno dei quattro, righe fuori dal grafo o
	// ripetute, deduzione già fioca, gemella viva, anello pieno di più
	// forti). Come `osserva()`: chi chiama deve poter distinguere i due casi.
	//
	// `p_righe` sono gli INDICI delle righe del grafo che la reggono — gli
	// stessi che `Suggeritore.fatti()` porta nel campo `riga`. Si copiano, e
	// **si copiano SENZA IL SOGGETTO**: una deduzione non è mai su qualcuno.
	//
	// La soglia arriva dal chiamante, come in `dove()` e in
	// `cosa_da_ricordare()`: quanto deve pesare un ricordo per contare è una
	// decisione di gioco, e le decisioni di gioco stanno dove si leggono.
	int deduci(int64_t p_id, int p_obiettivo, const godot::PackedInt32Array &p_righe,
			double p_soglia);

	// LA DEDUZIONE CHE ASPETTA LA SUA RICEVUTA, o -1 (il caso normale).
	int deduzione_muta(int64_t p_id, double p_soglia) const;

	// LA DEDUZIONE CHE PUÒ DIVENTARE UN OBIETTIVO ADESSO, o -1 (il caso
	// normale, e il caso di SEMPRE per chi non ha il modello).
	int deduzione_pronta(int64_t p_id, double p_soglia, double p_attesa,
			double p_finestra) const;

	// DOVE GUARDA. Il posto del ricordo più forte fra quelli che la reggono
	// **e che si leggono da lì** — cioè un posto in cui il giocatore ha
	// DAVVERO fatto qualcosa mentre quel vicino guardava, e che sta nella
	// stessa direzione in cui il corpo sta per andare.
	//
	// `p_corpo` fa due mestieri, e sono lo stesso: è il RIPIEGO («non c'è
	// niente da mostrare» e «guarda casa sua» sono lo stesso Vector3, come in
	// `dove()`, e nessun chiamante può dimenticarsi di controllare) ed è il
	// VERTICE da cui si giudica la lettura — un collo non guarda dove sta, e
	// due direzioni si confrontano solo se partono dallo stesso punto.
	//
	// `p_meta` è dove quel vicino andrà se la deduzione diventa un gesto, e
	// `p_apertura` (radianti, `<= 0` = «non filtrare») quanto largo è il cono
	// dentro il quale le due direzioni sono la stessa. Vedi `chibi::Lettura`.
	godot::Vector3 deduzione_dove(int64_t p_id, int p_i,
			const godot::Vector3 &p_corpo, const godot::Vector3 &p_meta,
			double p_apertura) const;

	// LA MASCHERA DEL PROVVEDIMENTO, quella che `pianifica()` si aspetta.
	// 0 se l'indice non è di una deduzione.
	int deduzione_obiettivo(int64_t p_id, int p_i) const;

	// LA RICEVUTA È PAGATA: la testa si è girata, il giocatore ha visto.
	//
	// ⚠️ Questa funzione ha UN SOLO CHIAMANTE LEGITTIMO in tutto il gioco, ed
	// è la funzione che gira la testa (`Deduzioni.consegna`, due righe
	// consecutive, l'idioma di `Percezione._testimonia`). Chiamarla senza
	// aver girato la testa vuol dire una conseguenza senza premessa, e una
	// conseguenza senza premessa non attenua l'effetto: **lo inverte**.
	void deduzione_ricevuta(int64_t p_id, int p_i);

	// SPESA: il piano è stato consegnato, e non si ripete. Senza questa
	// riga la deduzione resterebbe la priorità di quel vicino per sempre.
	void deduzione_spendi(int64_t p_id, int p_i);

	// --- le letture di prova (nessuna di queste muove niente) ------------
	// Il grafo di un residente, nella stessa forma dei quattro oracoli di P1
	// ({ "ricordi": Array, "versione": int }).
	godot::Dictionary debug_grafo(int64_t p_id) const;
	// Il LATCH (`mod`, `vista`, `t_valutato`) **e** la lettura fatta adesso
	// (`ammirazione`, `gratitudine`, `interesse`). Sono due cose diverse
	// apposta, e possono legittimamente non combaciare: il `mod` è di un
	// gradino fa. Confonderle vorrebbe dire non poter più provare il gradino.
	godot::Dictionary debug_emozioni(int64_t p_id) const;
	// La taratura VIVA della memoria più `PASSO_EMO` e l'orologio monotono,
	// così nessun test riscrive un numero a mano.
	godot::Dictionary debug_ritmo() const;
	// LE DEDUZIONI di un residente: una riga per deduzione, con obiettivo,
	// bandiere, peso di adesso e le righe che la reggono in forma di
	// `Ricordo` (le stesse chiavi di `debug_grafo`). E le costanti del C++
	// (`MAX_DEDUZIONI`, `MAX_PERCHE`, le due bandiere), così nessun test ne
	// riscrive una a mano.
	godot::Dictionary debug_deduzioni(int64_t p_id) const;
	godot::Dictionary debug_deduzioni_costanti() const;
	// «Cosa racconterei a chi sa già questi verbi»: la stessa funzione pura
	// di `debug_grafo_da_raccontare`, con la maschera che `racconta()` usa in
	// partita. Senza, la scelta filtrata sarebbe provabile solo di rimbalzo.
	int debug_grafo_novita(const godot::Dictionary &p_grafo, double p_ora,
			double p_mezza_vita, int p_gia_saputi) const;

	// I NOMI dei verbi e delle cose. Come per indoli, quirk, fatti e azioni,
	// il ponte parla per NOME e la traduzione sta in un posto solo: il bus
	// della percezione (P6) manderà `{"verbo": "annaffia"}`, non un intero.
	int indice_verbo(const godot::String &p_nome) const;
	int indice_cosa(const godot::String &p_nome) const;
	godot::String nome_verbo(int p_verbo) const;
	// Serve anche alla PROMOZIONE (P6): `brain.remember()` vuole un nome, e
	// quel nome dev'essere uno dei simboli che un chibi sa dire.
	godot::String nome_cosa(int p_cosa) const;

	// --- SISTEMA NEUROCHIMICO -------------------------------------------
};

VARIANT_ENUM_CAST(EcsMondo::Stato);
VARIANT_ENUM_CAST(EcsMondo::Azione);
VARIANT_ENUM_CAST(EcsMondo::Verbo);
VARIANT_ENUM_CAST(EcsMondo::Cosa);
VARIANT_ENUM_CAST(EcsMondo::Bandiera);

#endif // CHIBI_ECS_MONDO_H
