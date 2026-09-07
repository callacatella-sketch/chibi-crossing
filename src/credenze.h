#ifndef CHIBI_CREDENZE_H
#define CHIBI_CREDENZE_H

#include <cstdint>

#include "grafo_ricordi.h" // N_VERBI, SOGG_NESSUNO

// LA TEORIA DELLA MENTE: che cosa io credo che TU sappia.
//
// Sesto gemello di sistema_sonno, sistema_agenda, sistema_piani,
// grafo_ricordi e grafo_deduzioni: puro. Niente Godot, niente EnTT, niente
// rng, niente allocazioni.
//
// ────────────────────────────────────────────────────────────────────────
// PERCHÉ ESISTE — il narratore era ONNISCIENTE
// ────────────────────────────────────────────────────────────────────────
//
// Fino a qui, prima di raccontare qualcosa, A costruiva la maschera di ciò
// che B sa **leggendo il grafo dei ricordi VERO di B** (`EcsMondo::racconta`,
// il ciclo su `gb`). Nessun agente, in tutto il progetto, teneva una
// rappresentazione di ciò che un altro sa: la conoscenza altrui si guardava
// come si guarda una variabile.
//
// Il substrato per farlo bene era già calcolato e buttato via: `Percezione`
// produce `visti` — la lista dei co-testimoni di un gesto —, la usa per il
// ciclo delle due righe e la lascia cadere. **A vede che anche B ha visto**,
// e quello è l'unico fatto da cui questo villaggio ha il permesso di
// costruire un modello di un'altra mente.
//
// La differenza si misura, e non è una sfumatura: l'onniscienza produce zero
// ridondanza *per costruzione* (la maschera è una funzione pura del grafo di
// B valutata adesso, quindi non può sbagliare mai); un modello costruito
// dalla sola co-testimonianza produce qualche ripetizione benigna — due che
// si raccontano la stessa cosa e ridono — e, questa è la firma, **una coda
// di ritardatari**: gente che resta fuori perché tutti credono che sappia
// già. L'onniscienza non può generarla in nessun modo.
//
// ────────────────────────────────────────────────────────────────────────
// ⚠️ IL RISCHIO PIÙ ALTO, E LA CURA È IL TIPO — NON LA DISCIPLINA
// ────────────────────────────────────────────────────────────────────────
//
// Una teoria della mente completa apre la porta all'INGANNO: **«so che tu
// non sai» è la premessa della menzogna**. E questo progetto ha già
// rifiutato per iscritto, nella REGOLA SACRA, «gli abitanti che mentono per
// danneggiare un rivale» — la versione che sta sui binari era l'ERRORE
// ONESTO, la voce che si deforma viaggiando perché la memoria decade.
//
// La cura non è una taratura prudente e non è un commento che chiede
// gentilezza a chi verrà. È una **restrizione della struttura**: il modello
// è MONOTONO e SOLO POSITIVO, e **non esiste sintatticamente un posto in cui
// scrivere una credenza falsa**. Cinque proprietà, e ognuna toglie un modo
// di mentire:
//
//  1. **Il parametro è UN VERBO, non una maschera.** `p_verbo` è un indice
//     in [0, N_VERBI), non otto bit. Con una maschera si potrebbe passare 0
//     e — con un `=` al posto di un `|=` — azzerare tutto; con un indice
//     **non esiste il valore che significa «niente»**. È la stessa scelta
//     per cui `osserva()` prende un verbo e non un `Ricordo` già formato.
//  2. **Non c'è nessun booleano.** Non `so_che_sa(…, bool sa)`. Un booleano
//     è letteralmente il posto sintattico in cui si scrive «non sa», ed è la
//     stessa ragione per cui `R_SU_DI_ME` si DERIVA invece di arrivare come
//     parametro: un booleano in più è un secondo modo di dire la stessa
//     cosa, cioè la possibilità di dirla diversa.
//  3. **Non c'è nessun setter di maschera.** `saputi_di()` è `const` e torna
//     un `uint32_t` per VALORE; non esiste `imposta_saputi()`. La maschera si
//     può leggere e non si può rimettere dentro: il grafo delle scritture ha
//     un solo arco entrante, e su quell'arco passa un verbo alla volta.
//  4. **Non c'è nessuna funzione che spegne una credenza.** Non
//     `dimentica_che_sa()`, non `azzera_credenze()`. L'unica cosa che toglie
//     righe è `dimentica_gli_assenti()`, che **non si può puntare su una
//     persona**: non prende un bersaglio, prende l'elenco di CHI È VIVO e
//     butta ciò che non c'è più. Chi la usasse male (omettendo un vivo)
//     otterrebbe «non so più niente di lui» ⇒ glielo racconta ⇒ una
//     ripetizione benigna. **Il peggior abuso possibile di questa API è una
//     chiacchierata in più.**
//  5. **Il tempo non arriva da fuori del ponte.** `p_ora` lo passa
//     `EcsMondo` da `_tempo`, l'orologio monotono, esattamente come per un
//     ricordo: nessuno può antidatare una credenza per renderla eterna.
//
// Nel corpo di `so_che_sa()` c'è **un solo operatore che tocca una
// credenza**, ed è il timbro in avanti. Se un domani qualcuno volesse
// scrivere una credenza falsa dovrebbe **aggiungere una funzione a questo
// file** — e allora sappia che sta scrivendo il primo pezzo di un villaggio
// in cui la gente è crudele.
//
// LE DUE SOLE FORME DI ERRORE CHE RESTANO POSSIBILI, e nessuna è
// un'affermazione falsa su una persona:
//  · A crede che B sappia, e B ha dimenticato  → **la coda dei ritardatari**;
//  · A non sa che C gliel'ha già detto         → **la ripetizione benigna**.
// Non c'è, sintatticamente, un terzo caso.
//
// ────────────────────────────────────────────────────────────────────────
// ⚠️ E LA CREDENZA DEVE POTER SBIADIRE, O NON È UNA CODA: È UN MURO
// ────────────────────────────────────────────────────────────────────────
//
// È la cosa che il piano non diceva, e senza di lei questo file spegne il
// pettegolezzo — che è l'UNICA uscita a schermo della Fase 4 (il simbolo
// nella nuvoletta di `Visitors._run_chat`).
//
// Il conto: la co-testimonianza è molto più larga dell'anello dei ricordi.
// Al falò `visti` può contenere ventotto persone, e un gesto solo accende
// 28×27 credenze in un colpo. Se una credenza non scadesse mai, dopo qualche
// sera **ogni coppia avrebbe acceso ogni verbo**, e da lì in poi nessuno
// avrebbe più niente da dire a nessuno — in silenzio, lentamente, con la
// suite verde. È la forma di guasto che questo progetto ha già pagato cinque
// volte.
//
// L'anello dei ricordi non ha questo problema perché **si pota**: le sue 24
// righe si ricambiano. Qui non c'è nessun ricambio, quindi il ricambio
// dev'essere il TEMPO.
//
// ⚠️ MA SBIADIRE NON È UN `&= ~`, ED È TUTTA LA DIFFERENZA. Il dato non
// decade: ogni credenza porta il suo `quando`, e a decadere è la LETTURA —
// esattamente l'idioma di `chibi::peso` («nel dato non deve esistere nessun
// intero che decade»). Lo stato conservato può solo crescere; è
// `saputi_di()` a decidere, adesso, quali timbri sono ancora dentro la loro
// finestra. Nessuna funzione spegne un bit, mai.
//
// E sbiadire va nel verso GIUSTO: una credenza persa manda A a raccontare
// una cosa che B forse sapeva già ⇒ ripetizione benigna. Una credenza che
// non sbiadisce manda B fuori dal villaggio delle notizie per sempre.
//
// ────────────────────────────────────────────────────────────────────────
// COSA NON C'È, e ognuna di queste assenze è un veto
// ────────────────────────────────────────────────────────────────────────
//
//  · **nessun aggregato fra persone.** Non esiste un `quanto_ne_sa()`, e non
//    deve esistere: un `popcount` sulla riga di B è «quanto è informato B»,
//    cioè una classifica fra persone dalla porta di servizio — la stessa
//    regola per cui il posto al falò non si ordina per affetto. L'unico
//    consumatore legale della maschera è `p_gia_saputi` di `da_raccontare`.
//  · **nessun movimento.** Il modello può solo TOGLIERE un racconto, mai
//    aggiungerne uno né spostare un corpo. Non c'è e non deve esserci una
//    nona azione «vado a dirglielo»: sarebbe il guinzaglio, cioè ventotto
//    vicini che orbitano attorno al giocatore.
//  · **nessuna persistenza.** Come il grafo dei ricordi e come le deduzioni:
//    vive in RAM sull'entità e muore col cervello. E qui c'è una ragione IN
//    PIÙ: è il modello di un dato che non si salva. Se le credenze si
//    salvassero e i ricordi no, al ricaricamento A crederebbe che B sappia
//    cose che B **non può possibilmente ricordare** — non una coda, un muro
//    permanente costruito dal salvataggio.
//  · **nessuna provenienza indiretta.** Un bit non arriva MAI da quello che
//    un terzo ha detto: le sorgenti sono due, e sono tutte e due cose che
//    chi scrive HA OSSERVATO (eravamo lì insieme; gliel'ho appena detto io).
//    La monotonia vieta il CONTENUTO falso, questa vieta la PROVENIENZA
//    falsa, e servono tutte e due.

namespace chibi {

// QUANTE PERSONE SI PUÒ MODELLARE. È `Visitors.MAX_RESIDENTS`, e non lo si
// ricopia a occhio: un test lo confronta con la costante di là, come già per
// gli otto verbi e le sei cose.
//
// Non è un tetto stretto: un residente può co-testimoniare con al più 27
// altri. Ma gli handle dei PARTITI restano nella tabella (vedi
// `dimentica_gli_assenti`), quindi su una sessione lunga le voci distinte
// possono superare il numero dei vivi — ed è per questo che la potatura per
// capienza qui sotto non è codice morto.
constexpr int MAX_CONOSCIUTI = 28;

// «NON HO MAI SAPUTO CHE SAPESSE». Un tempo che nessun orologio monotono può
// raggiungere: è lo stesso idioma di `EmozioniComponent.t_valutato`, e sta
// qui — non nel .cpp — perché è il valore con cui una voce NASCE, e chi la
// legge deve poterlo riconoscere senza andarlo a cercare altrove.
constexpr float CREDENZA_MAI = -1.0e9f;

// LA TABELLA DELLE CREDENZE DI UNA PERSONA.
//
// `chi` è l'handle ECS **COMPLETO** (indice + versione), non l'indice a 20
// bit, ed è la riga più importante della struttura — la stessa lezione già
// pagata da `Ricordo.soggetto`. EnTT ricicla gli slot: con un indice nudo,
// il vicino nuovo che eredita lo slot di chi è partito **nascerebbe con
// addosso le credenze del vecchio**, cioè mezzo villaggio crederebbe di
// avergli già raccontato tutto e lui non riceverebbe una notizia per tutta
// la vita. In silenzio, dopo cento giorni, e SOLO in un villaggio che ha
// avuto partenze — dove nessun collaudo arriva.
//
// Con la versione, un handle morto **non combacia con nessuno**: la voce
// stantia diventa illeggibile invece che sbagliata, `saputi_di` torna 0, e
// si racconta. Il degrado va dove va sempre: verso il comportamento che
// c'era prima che questa fase esistesse.
//
// ⚠️ I quattro byte in più per voce COMPRANO ESATTAMENTE QUESTO. Chi un
// domani volesse risparmiarli tenendo solo l'indice riaprirebbe il guasto
// muto dei cento giorni, e la spazzata di `dimentica_gli_assenti` non è la
// rete che sembra: è igiene (recupera un posto), non la garanzia.
//
// `quando[k][v]` è QUANDO ho saputo che `chi[k]` sa il verbo `v`. Un timbro
// per (persona, verbo) e non uno per persona: con un timbro solo, un
// co-testimone di «pesca» rinfrescherebbe anche la credenza su «annaffia» di
// tre giornate fa — una credenza che si rigenera da sola per un motivo che
// con lei non c'entra. L'errore andrebbe pure nel verso buono (più coda, mai
// una falsità), ma sarebbe un orologio che mente su quale credenza sta
// invecchiando, e la coda misurata non sarebbe più attribuibile a niente.
// Ottocento byte a residente non sono un prezzo: sono un arrotondamento.
struct Credenze {
	uint32_t chi[MAX_CONOSCIUTI];        // SOGG_NESSUNO = voce libera
	float quando[MAX_CONOSCIUTI][N_VERBI]; // CREDENZA_MAI = non l'ho mai saputo
	uint8_t n;                           // voci usate, compattate in testa

	Credenze();
};

// La struttura attraversa tre piattaforme e due compilatori: se un giorno
// qualcuno allarga un campo, che lo dica il compilatore e non il profiler.
// 112 (chi) + 896 (quando) + 1 (n) → 1012 con alignof 4.
static_assert(sizeof(Credenze) == 1012, "Credenze deve restare 1012 byte");

// ⚠️ **L'UNICA SCRITTURA DI QUESTO FILE.** «Adesso so che `p_chi` sa
// `p_verbo`.» Accende, non spegne; un verbo alla volta; e il timbro va solo
// IN AVANTI (`max`), così una credenza non torna mai indietro nemmeno se un
// chiamante passasse un'ora vecchia.
//
// Rifiuta in silenzio `SOGG_NESSUNO` e i verbi fuori tabella: è una scrittura
// che gira k² volte per gesto, e un `ERR_FAIL` per coppia trasformerebbe un
// verbo sbagliato in ottocento righe di log. Il rumore lo fa il PONTE, una
// volta sola, prima di entrare qui.
//
// L'UNICO POSTO IN CUI UNA CREDENZA SI PERDE è la potatura per capienza qui
// dentro, quando le MAX_CONOSCIUTI voci sono tutte prese: se ne butta una, e
// **la sceglie il tempo, non il chiamante** — quella il cui timbro più
// recente è il più vecchio. Chi è partito non viene mai più rinfrescato da
// nessuno, quindi è per costruzione il primo a cadere: la funzione che
// aggiunge è anche la sola che toglie, e non esiste una seconda API con cui
// sbagliarsi.
void so_che_sa(Credenze &r_c, uint32_t p_chi, uint8_t p_verbo, float p_ora);

// ⚠️ **L'UNICA LETTURA.** La maschera dei verbi che credo `p_chi` sappia,
// ADESSO. Zero = «non so niente di lui», ed è il caso normale e il degrado
// di ogni cosa che va storta.
//
// `p_durata` è per quanti secondi una credenza resta buona, e **decade in
// LETTURA**: il dato non si tocca. Il predicato è un confronto, non un
// esponenziale — per un'uscita booleana `2^(-dt/mv) >= s` *è* `dt <= dt_max`,
// quindi si scrive la cosa che si intende invece della cosa da cui si
// deriva. Costa otto confronti di float e zero chiamate a `exp2`.
//
// `p_durata <= 0` vuol dire **non scade**, e non è una scorciatoia: è la
// convenzione già scritta di `p_finestra` in `deduzione_pronta` e di
// `p_apertura` in `chibi::Lettura`. Serve al banco, che deve poter misurare
// per primo il caso eterno — è così che la scadenza è falsificabile.
//
// ⚠️ NON C'È E NON DEVE ESSERCI una sorella che aggreghi: la maschera si
// legge per UNA persona per volta, e il suo unico consumatore in tutto il
// gioco è `p_gia_saputi` di `da_raccontare`.
uint32_t saputi_di(const Credenze &p_c, uint32_t p_chi, float p_ora,
		double p_durata);

// L'IGIENE, e non è la garanzia — quella è la versione dentro l'handle.
//
// Toglie le voci che parlano di gente che non c'è più, e **non si può
// puntare su nessuno**: non prende un bersaglio, prende l'elenco di chi è
// VIVO. Non esiste, in tutto il file, un modo di dire «dimentica che B sa».
//
// Il peggior abuso possibile (omettere un vivo dall'elenco) fa perdere delle
// credenze vere ⇒ si racconta di più ⇒ una ripetizione benigna. Con
// `p_vivi == nullptr` non fa niente: «non so chi è vivo» non è «non è vivo
// nessuno», e il degrado va sempre verso il comportamento di prima.
//
// Torna quante voci ha tolto (per il banco: una spazzata che non toglie mai
// niente è indistinguibile da una che non gira).
int dimentica_gli_assenti(Credenze &r_c, const uint32_t *p_vivi, int p_n_vivi);

} // namespace chibi

#endif // CHIBI_CREDENZE_H
