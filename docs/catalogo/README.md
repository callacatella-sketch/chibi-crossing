# Il catalogo visivo di Chibi Crossing

Tre foto di **ogni singolo asset** del gioco — fronte, tre quarti e
profilo — una cartella per pezzo. In tutto **134 asset**, **402 immagini**.

Le foto NON sono disegni: sono i pezzi veri, costruiti dal loro builder e
renderizzati in uno studio con la luce e l'ombra del gioco. Se un pezzo
cambia, si rifanno con un comando solo e il catalogo torna vero.

```bash
CHIBI_CATALOGO=docs/catalogo ~/Downloads/Godot.app/Contents/MacOS/Godot \
    --path . --script res://tools/scatto_catalogo.gd
python3 tools/indice_catalogo.py
```

| categoria | pezzi | cos'è |
|---|---|---|
| [Struttura](0-struttura/README.md) | 28 | muri, pavimenti, tetti e i pezzi-guscio dei luoghi |
| [Arredo](1-arredo/README.md) | 31 | quello che si mette dentro: mobili, banconi, strumenti |
| [Giardino](2-giardino/README.md) | 32 | quello che sta fuori: verde, luci, giochi, servizi |
| [Palestra](3-palestra/README.md) | 8 | gli otto attrezzi di legno, tela e sassi di fiume |
| [Chiesa](4-chiesa/README.md) | 15 | la chiesa del paese, pezzo per pezzo |
| [Boutique](5-boutique/README.md) | 15 | il negozio di vestiti: vetrina, stender, camerini |
| [Personaggi](6-personaggi/README.md) | 5 | i cinque archetipi dei chibi, generati dal DNA |

## Come sono fatte le foto

- **900 × 900**, sempre: si renderizza in un `SubViewport`, non nella
  finestra (che su macOS non rispetta `--resolution` e cambia misura da
  una macchina all'altra).
- **L'inquadratura è calcolata**, non scelta a mano: si misura l'ingombro
  vero delle mesh e si arretra quanto basta perché ogni pezzo riempia la
  stessa frazione di immagine — dal fungo da dieci centimetri al
  campanile da due metri e mezzo.
- **Il fronte è -Z**: la vista «fronte» è quella che vede il giocatore
  quando posa il pezzo senza ruotarlo.
