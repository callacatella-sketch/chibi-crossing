# Firma e notarizzazione delle release

Questa guida spiega **come ottenere i certificati** e **quali GitHub Secrets
creare** per far uscire il gioco firmato (macOS notarizzata + Windows firmato),
così gli antivirus e i sistemi operativi non lo bloccano.

> **Importante:** i certificati costano soldi e sono legati alla tua identità.
> Nessuno li può creare al posto tuo, e i loro valori vanno inseriti **solo tu**,
> come *GitHub Secrets* (restano cifrati). L'agente Claude non li vede e non li
> inserisce mai.
>
> **Dove si inseriscono i secret:** repository su GitHub → **Settings** →
> **Secrets and variables** → **Actions** → **New repository secret**.

Finché i secret non ci sono, la pipeline (`.github/workflows/release.yml`)
**esporta comunque** il gioco, ma **non firmato** (vedrai un avviso giallo nel
log). Appena aggiungi i secret, la firma si attiva **da sola**, senza altre
modifiche.

---

## Nota onesta sull'obiettivo "antivirus"

Firmare + notarizzare è il passo **necessario e corretto** ed elimina gli avvisi
del sistema operativo:

- **macOS**: con la notarizzazione, Gatekeeper apre l'app senza "sviluppatore non
  identificato". Praticamente risolto.
- **Windows**: la firma toglie "Editore sconosciuto" e gran parte degli avvisi
  SmartScreen. La **reputazione** però si costruisce nel tempo; i certificati EV
  e **Azure Trusted Signing** partono già con buona reputazione.

Non è una garanzia matematica al 100%: i giochi Godot a volte vengono segnalati
in modo *euristico* comunque (per come impacchettano il `.pck`). Se capita un
falso positivo, si segnala al vendor dell'antivirus (es. Microsoft Defender ha un
modulo per i falsi positivi) e di solito viene sbloccato in fretta.

---

## 1) macOS — firma "Developer ID" + notarizzazione

### Cosa ti serve
1. **Apple Developer Program** — 99 $/anno: <https://developer.apple.com/programs/>
2. Un certificato **"Developer ID Application"** (per distribuire **fuori** dal
   Mac App Store). Lo crei da Xcode (*Settings → Accounts → Manage Certificates →
   + → Developer ID Application*) oppure dal portale sviluppatori con una CSR.
3. Esportalo dal **Portachiavi** come file **`.p12`** con una password.
4. Il tuo **Team ID** (10 caratteri): lo trovi su
   <https://developer.apple.com/account> → *Membership*.
5. Una **password specifica per app** per la notarizzazione: creala su
   <https://appleid.apple.com> → *Sicurezza → Password per le app*.

### Converti il certificato in base64 (dal tuo Mac)
```bash
base64 -i Certificati.p12 | pbcopy   # copia negli appunti da incollare nel secret
```

### Secret da creare su GitHub
| Secret | Valore |
|---|---|
| `MACOS_CERT_BASE64` | il `.p12` codificato in base64 (comando sopra) |
| `MACOS_CERT_PASSWORD` | la password che hai messo esportando il `.p12` |
| `MACOS_SIGNING_IDENTITY` | es. `Developer ID Application: Mario Rossi (ABCDE12345)` |
| `APPLE_ID` | la tua email Apple ID |
| `APPLE_TEAM_ID` | il Team ID (es. `ABCDE12345`) |
| `APPLE_APP_PASSWORD` | la password specifica per app (formato `xxxx-xxxx-xxxx-xxxx`) |

> Il nome esatto per `MACOS_SIGNING_IDENTITY` lo ottieni sul Mac con:
> `security find-identity -v -p codesigning`

Se la notarizzazione fallisce o l'app crasha all'avvio, rivedi le *entitlement*
in [`misc/macos_entitlements.plist`](misc/macos_entitlements.plist).

### ⚠️ Il MODELLO non viaggia nel pacchetto (e cosa ci viaggia al suo posto)

Dal **2026-08-13** il modello linguistico **non sta dentro la release**. Se lo
scarica il gioco, al primo uso, quando chi gioca accende la funzione — così il
pacchetto resta piccolo per tutti, e chi non userà mai il villaggio pensante non
paga niente. La ragione tecnica che ha chiuso la questione: **GitHub non accetta
allegati sopra i 2 GiB** in una Release, e il modello da solo ne pesa 2,32.

Quindi in `release.yml` **non c'è nessun `curl` che scarica i pesi**, e non ci
deve tornare. Quel che ci viaggia adesso è:

* il **cuore C++ compilato con `llm=yes`** — cioè con llama.cpp dentro (+7,1 MB
  sul binario: 1 141 496 byte senza, 8 226 280 con, misurati su macOS
  universale). Senza `llm=yes` la classe nativa `LlmLocale` non viene
  registrata, `Llm.disponibile()` è falsa per chiunque, la casella «Il villaggio
  pensa» non compare mai e **il modello che il gioco scaricherebbe non avrebbe
  chi lo apre**;
* le **licenze**, che non sono cortesia: la MIT chiede l'avviso «in all copies»
  (godot-cpp, EnTT, lua-gdextension, llama.cpp). Su Windows finiscono in
  `Licenze/` accanto all'`.exe`; su macOS **dentro** il bundle, in
  `Contents/Resources/Licenze/`.

**Su macOS il posto non è una preferenza di ordine**, e la regola vale per
qualunque file si voglia aggiungere al bundle (le licenze oggi, un modello
domani se mai ci si tornasse):

* `codesign` **sigilla** il bundle, e ogni file che sta dentro `Contents/` ma
  fuori da `Resources/` (per esempio accanto all'eseguibile, in
  `Contents/MacOS/`) diventa *unsealed contents*: la firma non verifica e la
  notarizzazione non passa;
* **i file vanno messi PRIMA della firma.** Iniettare qualcosa in un bundle già
  firmato ne rompe la firma, e il risultato è una release che Gatekeeper
  rifiuta.

### I tre cancelli che impediscono di pubblicare una release muta

La Fase 5 ha una modalità di guasto che **nessuno può vedere giocando**: senza,
il gioco è un gioco INTERO — le lettere scritte a mano ci sono e restano, la
casella semplicemente non compare. Nessun collaudo e nessuna segnalazione
potranno mai dire che è rotto, quindi il silenzio si rompe solo in CI:

1. **preflight** — *«Il modello si scarica ancora senza credenziali?»*: una
   richiesta `HEAD` a Hugging Face (nessun byte scaricato) confronta
   `x-linked-etag` e `x-linked-size` con `Llm.IMPRONTA_SPEDITO` e
   `Llm.BYTE_MODELLO`. Si chiede **senza token, apposta**: chi gioca un token
   non ce l'ha, e una CI che passasse *grazie* a un token direbbe di sì proprio
   nel caso in cui tutti sono rotti. Rosso su 401/403/404 (sono per sempre),
   avviso su rete e 5xx (la Release esce lo stesso: il modello non ci viaggia
   dentro).
2. **nei due job che compilano** — *«Il cuore compilato conosce LlmLocale?»*:
   guarda il **binario**, non il comando, cioè fa all'artefatto la stessa
   domanda che il gioco fa a `ClassDB`.
3. **prima di pubblicare** — *«Il gioco che pubblichiamo sa pensare?»*: apre i
   **pacchetti veri** e ripete la domanda alla libreria che riceve chi gioca,
   perché fra il binario compilato e il pacchetto ci sono l'export di Godot, la
   firma e (su macOS) un giro di `unzip`/`ditto`.

Il gioco cerca i pesi in tre posti, in ordine — `CHIBI_MODELLO`,
`user://modelli/pensieri.gguf` (dove finisce anche il download), e accanto
all'eseguibile — e la mappa eseguibile → modello vive in
`Llm.spedito_accanto_a()` (unica casa, provata per tutte e tre le piattaforme in
`tests/cases/test_llm_spedito.gd`: da un Mac quella riga non si può verificare in
nessun altro modo). **Mai dentro il `.pck`**: llama.cpp apre un percorso su
disco, e una risorsa impacchettata non ne ha uno.

---

## 2) Windows — Azure Trusted Signing (consigliato)

È l'opzione moderna e adatta alla CI: **~10 $/mese**, niente token hardware,
buona reputazione SmartScreen. In alternativa esistono servizi cloud HSM come
**SSL.com eSigner** o **DigiCert KeyLocker** (più costosi); se preferisci uno di
questi, dimmelo e adatto il workflow.

### Cosa ti serve (Azure Trusted Signing)
1. Un **account Azure**: <https://azure.microsoft.com>.
2. Crea una risorsa **Trusted Signing** (nel portale Azure) e al suo interno un
   **Certificate Profile**. Richiede una **verifica dell'identità** (individuale
   o aziendale) fatta da Microsoft — è la parte che richiede qualche giorno.
3. Crea una **App Registration** (service principal) con un **client secret**, e
   assegnale il ruolo **"Trusted Signing Certificate Profile Signer"** sulla
   risorsa Trusted Signing.
4. Segnati l'**endpoint** della regione (es. `https://weu.codesigning.azure.net/`
   per Europa occidentale), il **nome dell'account** e il **nome del profilo**.

### Secret da creare su GitHub
| Secret | Valore |
|---|---|
| `AZURE_TENANT_ID` | Directory (tenant) ID della App Registration |
| `AZURE_CLIENT_ID` | Application (client) ID della App Registration |
| `AZURE_CLIENT_SECRET` | il client secret generato |
| `AZURE_TS_ENDPOINT` | endpoint regionale, es. `https://weu.codesigning.azure.net/` |
| `AZURE_TS_ACCOUNT` | nome dell'account Trusted Signing |
| `AZURE_TS_CERT_PROFILE` | nome del Certificate Profile |

---

## 3) Come pubblicare una release firmata

Quando i secret sono a posto:

```bash
git tag v1.0.0
git push origin v1.0.0
```

Il workflow **"Release firmata (Windows + macOS)"** parte, esporta il gioco, lo
firma/notarizza e crea una **GitHub Release** con allegati
`ChibiCrossing-windows.zip` e `ChibiCrossing-macos.zip`.

Per una prova **senza** creare una release: *Actions → Release firmata → Run
workflow* (esporta e carica gli artifact, senza pubblicare nulla).

---

## Riepilogo di tutti i secret

**macOS:** `MACOS_CERT_BASE64`, `MACOS_CERT_PASSWORD`, `MACOS_SIGNING_IDENTITY`,
`APPLE_ID`, `APPLE_TEAM_ID`, `APPLE_APP_PASSWORD`

**Windows:** `AZURE_TENANT_ID`, `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`,
`AZURE_TS_ENDPOINT`, `AZURE_TS_ACCOUNT`, `AZURE_TS_CERT_PROFILE`

Puoi aggiungerli in qualsiasi momento e anche uno alla volta: se metti solo
quelli macOS, verrà firmata solo l'app Mac; se metti solo quelli Windows, solo
l'`.exe`.
