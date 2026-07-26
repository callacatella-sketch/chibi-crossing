# IL FILO ROSSO — il sistema emozionale di Chibi Crossing

> Un filo invisibile lega Mochi a ogni vicino. Si annoda coi momenti
> vissuti insieme, si colora con gli anni, e non si spezza mai —
> nemmeno quando qualcuno parte per sempre. Cambia solo forma.

## Perché è diverso da tutto

Animal Crossing fa *convivere* col villaggio. Il Filo Rosso fa
*volere bene* al villaggio. La differenza sta in quattro scelte:

1. **La memoria è condivisa e narrativa** — non punti d'amicizia, ma
   MOMENTI: "il giorno della valigia sulla soglia", "il bagno alle
   terme, fianco a fianco". Il gioco li ricorda e li fa riaffiorare.
2. **Il tempo passa per tutti** — i vicini invecchiano, davvero:
   nel corpo, nel passo, nella VOCE (la voce è sintetizzata dal DNA:
   può incrinarsi con l'età — nessun gioco può farlo così).
3. **La perdita trasforma, non cancella** — chi parte non sparisce:
   diventa un fiore che non esiste da nessun'altra parte, una
   costellazione, un anello del Grande Albero, un capo nell'armadio.
4. **L'empatia è BIDIREZIONALE** — il colpo di scena: quando Mochi
   soffre, sono i vicini a consolarla. Vengono a sedersi accanto,
   in silenzio. Il giocatore riceve l'empatia che ha seminato.

## Le regole cozy della mortalità (non negoziabili)

- La partenza non è MAI casuale né punitiva: arriva solo dopo una
  lunga vita piena e una settimana di congedo annunciata.
- Mai durante l'assenza del giocatore: nessuno parte "mentre non
  c'eri". Il congedo aspetta che tu torni.
- Mai due partenze vicine (minimo un ciclo intero di distanza).
- Il tono è Spiritfarer, non Grim Reaper: si "parte per il Grande
  Prato", con la valigia piccola e il cappello in zampa.
- Impostazione «Prato Eterno»: chi vuole può disattivare le partenze.
  Il gioco resta intero anche senza.

## Architettura

```
Legami.gd (il cuore: ledger dei momenti, fili, età, lutto)
   ▲ call_group("legami", "momento", nome, tipo, extra)
   │
   ├── Visitors.gd     (trasloco, benvenuto, saluto T, piatti, desideri)
   ├── Onsen.gd        (bagno condiviso)
   ├── Calendar.gd     (feste di compleanno)
   ├── Weather.gd      (riparo dalla pioggia insieme — futuro)
   │
   ├── VillagerBrain   (bisogni/indoli: già esistente, resta il "cervello")
   ├── Visitor.gd      (recita: andatura, posa, età visibile, conforto)
   ├── Chibiese.gd     (la voce che invecchia: rate ↓, pitch ↓, rough ↑)
   ├── Mochi.gd        (il lutto incarnato: orecchie, coda, passo)
   ├── GrandTree.gd    (l'anello commemorativo)
   ├── Stargazing.gd   (la costellazione di chi è partito)
   ├── Wardrobe.gd     (l'accessorio lasciato, indossabile)
   └── Regista/Lua     (orchestrazione delle veglie e dei conforti)
```

Il contatore `friend` esistente resta la QUANTITÀ del legame.
Il Filo aggiunge la QUALITÀ: la storia, l'età, il lutto.

### Dati (persistiti in village.json, chiave "legami")

```
_fili = { nome: {
    "momenti":       [{d, t, x}],   # giorno, tipo, extra (max 30)
    "giorno_arrivo": int,
    "eta":           "giovane" | "adulto" | "anziano" | "congedo",
    "partito":       false,
    "giorno_partenza": -1,
}}
_lutto = {"attivo": false, "nome": "", "intensita": 0.0, "giorni": 0}
```

## Le fasi di costruzione (una per volta, qualità massima)

### ✅ FASE 1 — Il Filo dei Momenti (fondamenta)
Il ledger narrativo. Ogni gesto condiviso diventa un momento datato
e raccontabile. Il primo momento di ogni tipo "colora il filo"
(toast poetico). Salutando (T) un amico, a volte lui *ricorda*: un
pensiero riaffiora, con le parole giuste in Chibiese. Persistito.
**Senza questa base niente ha peso: il lutto fa male solo se c'è
una storia da perdere.**

### ✅ FASE 2 — Le Stagioni della Vita
Dal giorno 14 di amicizia si è "adulti", dal 40 "anziani" — con un
fattore continuo (eta_f 0..1) che attraversa corpo e voce: passo
-38%, saltello che si posa, schiena china, coda pigra, pelo e
vestitino che sbiadiscono verso l'argento (sempre dai colori
originali: mai derive). Oltre la soglia dell'autunno arrivano i
SEGNI: baffetti brizzolati, sopracciglia d'argento, ciuffetto sul
mento e il bastoncino di ciliegio col pomello lucido. La voce
invecchia DAVVERO (Chibiese.invecchia: pitch e canto giù, incrinatura
e respiro su, cadenza lenta). L'ingresso nell'autunno è un evento:
toast, anello 🍂 sul Grande Albero, lettera del Gufo. Gli anziani
raccontano: i ricordi del filo riaffiorano più spesso.

### ✅ FASE 3 — Il Congedo (la settimana delle ultime cose)
Quando è tempo, il Gufo scrive a Mochi: «Nocciola vuole salutare
il mondo, accompagnala tu». Sette giorni di ULTIMI DESIDERI, uno
al giorno, generati dai momenti del filo (rivedere le stelle
insieme, un ultimo bagno alle terme, quel piatto di quel giorno).
Ogni desiderio esaudito = un momento d'oro sul filo. L'ultima
sera: il falò con tutti i vicini, il Chibiese sottovoce.
All'alba, sul letto: l'accessorio piegato e una lettera.

### ✅ FASE 4 — Il Lutto
Il lutto è GIOCATO, non raccontato: per giorni (proporzionali al
filo) Mochi cambia — orecchie basse, coda ferma, passo lento, e
ogni tanto si ferma da sola dove i momenti sono accaduti (un
luccichio la aspetta lì: l'eco del ricordo). La casa di chi è
partito tiene la finestra accesa per una settimana. Gli altri
vicini lo sentono: si radunano al Grande Albero la prima sera.
E poi il capolavoro dell'empatia: **vengono a consolare Mochi** —
le si siedono accanto senza dire niente, le portano un piatto
caldo, la accompagnano a casa la sera. Non c'è un bottone per
"superare il lutto": passa coi giorni e coi riti, come quello vero.

### ✅ FASE 5 — I Ricordi che Restano
La trasformazione: davanti alla casa nasce IL FIORE — unico,
generato dal DNA di chi è partito (i suoi colori, la sua forma,
da nessun'altra parte nel mondo). Annaffiarlo non serve: non
appassisce mai. Sedendosi accanto, i momenti del filo riaffiorano
uno a uno. In cielo appare la sua costellazione (le stelle scelte
dal suo DNA) — «Nocciola adesso abita lassù». Il Grande Albero
incide l'anello d'oro. L'accessorio entra nel guardaroba: quando
Mochi lo indossa, i vicini si fermano — «mi-ka…» (amico).

### ✅ FASE 6 — L'Empatia Bidirezionale
I vicini leggono Mochi: se il giocatore manca da giorni (data
reale), al ritorno si radunano — ti sono mancati e glielo dici
sentendolo. Se Mochi è sfinita spesso, un amico le porta da
mangiare senza che nessuno chieda niente. Se piove e Mochi è
fuori, un amico la raggiunge sotto la tettoia. Il Regista Lua
orchestra tutto: l'empatia diventa la sua quinta dimensione.

## I tipi di momento (Fase 1)

| tipo          | quando                        | racconto                                |
|---------------|-------------------------------|-----------------------------------------|
| benvenuto     | il benvenuto al candidato     | il primo benvenuto sulla soglia         |
| trasloco      | il giorno che si trasferisce  | il giorno della valigia sulla soglia    |
| primo_saluto  | la prima zampina alzata (T)   | la prima zampina alzata                 |
| piatto        | un piatto regalato            | quel piatto fumante diviso in due       |
| festa         | la festa a sorpresa           | la festa a sorpresa coi coriandoli      |
| onsen         | il bagno alle terme insieme   | il bagno caldo, fianco a fianco         |
| desiderio     | il desiderio esaudito         | il desiderio esaudito vicino a casa     |
```
