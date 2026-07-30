# Il Prologo — la piccola Mochi sotto la tempesta

> **Questo documento è il piano dell'autore per l'apertura del gioco.** Non è
> una proposta di un agente: è la direzione, e va rispettata alla lettera nella
> sostanza e nel tono. Si realizza **un passo alla volta**, e questo file è la
> fonte unica di cosa deve diventare.

## Perché esiste

Oggi il gioco comincia in un prato. Il piano è farlo cominciare con una
**empatia pura**: una creatura piccola, tenera e in difficoltà, che il giocatore
vuole aiutare prima di sapere che cos'è questo gioco. È l'aggancio: uno si
affeziona a Mochi nei primi trenta secondi, e tutto quello che il gioco farà
dopo — il villaggio, i vicini, il Filo Rosso, i congedi — poggia su
quell'affetto.

E c'è una seconda cosa, più grossa: **Mochi rompe la quarta parete**. Non guarda
"la telecamera", guarda **te**. Il giocatore non è un avatar: è qualcuno che è
arrivato, e a cui Mochi chiede aiuto. Questo riquadra il gioco intero.

## La sequenza, dal tasto «nuova avventura»

**1. La tempesta.**
Si parte dal momento in cui il giocatore preme il tasto per iniziare la nuova
avventura. Non un prato: una **tempesta**. Una **piccola Mochi cucciola** —
impaurita, triste, tutta sola — che **cammina** sotto la pioggia.

**2. Si gira verso di te.**
La piccola si gira a favore di camera e **guarda il giocatore**. Orecchie
abbassate, sguardo abbassato:

> «dov'è mamma?... dov'è papà?... ho paura... mi sento sola...»

**3. La quarta parete si rompe.**
Poi aggiunge:

> «cosa? mi vuoi aiutare? perché?»

**4. La promessa.**

> «forse con te... Mochi non si sentirà mai più sola?»

*(Le tre battute sono trascritte come le ha scritte l'autore. Vanno portate in
gioco con questo senso e questo ritmo esatti — i puntini di sospensione sono
parte della recitazione, non punteggiatura da ripulire.)*

**5. Il cielo cambia.**
La tempesta si apre, **torna il sereno**. È il momento della catarsi: il mondo
risponde alla promessa.

**6. Il tutorial che fa crescere Mochi.**
Parte il tutorial, e il tutorial **fa letteralmente crescere Mochi** dalla
cucciola alla **versione adulta di adesso**. Durante la crescita, Mochi e il
giocatore **si scambiano dialoghi**: si impara a giocare mentre lei diventa
grande.

**7. Comincia il gioco.**
Finito il tutorial comincia il gioco vero e proprio: arrivano gli abitanti, e
tutto il resto come è oggi.

## Le cose che non si negoziano

1. **Mochi parla al giocatore, e il giocatore esiste.** Non è un monologo
   davanti a una telecamera: è una conversazione con qualcuno che è appena
   arrivato.
2. **Mochi è piccola all'inizio e adulta alla fine.** La crescita non è un
   taglio di montaggio: si vede.
3. **Dalla tempesta al sereno.** Il tempo del mondo cambia perché il giocatore
   ha detto sì.
4. **Prima l'affetto, poi le regole.** Il tutorial viene dopo l'aggancio
   emotivo, non prima.

## Cosa c'è già per costruirlo

Quasi tutti i mattoni esistono. Vanno **riusati**, non riscritti.

- **La crescita da cucciolo ad adulto è già un sistema.** `Visitor.set_cucciolo(t)`
  prende un valore continuo da 0.0 (appena nato) a 1.0 (adulto) e riscala il rig
  — testona, passo corto, vocina ([Visitors.gd:128](../scenes/npc/Visitors.gd:128),
  [Visitor.gd:1797](../scenes/npc/Visitor.gd:1797)). Il tutorial può muovere quel
  singolo numero.
- **Le nascite** hanno già scritto tutta la grammatica del cucciolo che cresce e
  dice la sua prima parola ([Nascite.gd](../scenes/world/Nascite.gd)).
- **Il volto** ha già le espressioni, le orecchie che si abbassano, lo sguardo,
  l'ammicco ([FaceController.gd](../scenes/characters/FaceController.gd)).
- **La tempesta e il sereno**: `Weather` sa già fare pioggia e schiarita
  ([Weather.gd](../scenes/world/Weather.gd)), e il velo del lutto col ritorno del
  primo sole è già stato scritto una volta — è la stessa lingua visiva.
- **Il titolo** è il punto d'innesto: il bottone «Nuova avventura» sta in
  [TitleScreen.gd](../scenes/ui/TitleScreen.gd).
- **La voce di Mochi** e i suoi «z» del sonno, le pose da seduta, l'espressione
  «dorme» sono in [Mochi.gd](../scenes/characters/Mochi.gd).

## Le domande da sciogliere quando ci arriveremo

Non sono obiezioni al piano: sono decisioni che il piano richiede, e conviene
prenderle prima di scrivere codice.

1. **In che lingua parla Mochi?** I vicini parlano **Chibiese** (lingua
   inventata, mai tradotta). Qui Mochi dice frasi vere in italiano. È
   un'eccezione voluta — Mochi parla *a te*, non ai vicini — ma va dichiarata,
   perché è il momento in cui il gioco stabilisce chi può parlarti.
2. **Come si mostrano queste battute?** Oggi il gioco ha toast, lettere e
   nuvolette in Chibiese: **non ha una presentazione da dialogo**. Serve una
   cosa nuova, e sarà la prima impressione visiva del gioco.
3. **Come risponde il giocatore?** «mi vuoi aiutare?» implica un sì. Un tasto
   solo, una scelta, o il silenzio che vale come sì?
4. **Il prologo si può rivedere o saltare?** Chi ricomincia una partita non
   deve essere obbligato a rifarlo, e chi lo ama deve poterlo rivedere.
5. **Quanto dura la crescita?** Il tutorial deve insegnare abbastanza verbi
   senza che la crescita diventi una barra di caricamento.
6. **Le battute vanno tradotte in inglese nella stessa sessione** in cui
   entrano in gioco (regola del progetto, vedi [TRADUZIONE.md](TRADUZIONE.md)).
   Sono le frasi più importanti del gioco: la traduzione va scritta con la
   stessa cura dell'italiano, non dopo.

## Stato

**Non ancora iniziato.** Si procede un passo alla volta, insieme all'autore.
