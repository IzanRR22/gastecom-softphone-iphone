# Compilar el softphone de Gastecom para iOS

Esta carpeta está lista para **copiarse a un Mac y compilar ahí**. No hay nada
más que preparar en Windows.

Verificado el **2026-08-17** en el Mac Mini de Gastecom (`192.168.111.195`,
macOS 26.5.1, Xcode 26.2): la compilación de simulador dio **BUILD SUCCEEDED**.

---

## Lo que hace falta en el Mac

| | |
|---|---|
| macOS | 26.x — probado en 26.5.1 |
| Xcode | 26.x — probado en 26.2 |
| Red | Sí, la primera vez: las dependencias se bajan de GitHub |
| Cuenta de desarrollador | **Solo** para compilar a un iPhone real o subir a TestFlight |

Para **verificar que compila** y para **probarlo en el simulador** no hace falta
ninguna cuenta ni certificado.

## Cómo llevarlo

Copia la carpeta `linphone-iphone` entera. Da igual el medio: USB, red o
`scp`. Lo único que **no** debe viajar son los `.bak-*` y cualquier `build/`,
que no hacen falta.

Desde Windows, para empaquetarla limpia:

```powershell
cd "C:\Users\izanr\Documents\ClaudeAI\Gastecom\proyectos\Softphone Gastecom\iphone"
tar czf linphone-iphone.tgz --exclude=".git" --exclude="build" --exclude="*.bak-*" linphone-iphone
```

Salen unos **4 MB**. En el Mac:

```bash
tar xzf linphone-iphone.tgz
cd linphone-iphone
chmod +x compilar-en-mac.sh
./compilar-en-mac.sh
```

## Qué hace el script

`compilar-en-mac.sh` resuelve las dependencias y compila. Dos modos:

```bash
./compilar-en-mac.sh              # simulador, sin firma  <- para verificar
./compilar-en-mac.sh dispositivo  # iPhone real, NECESITA firma
```

Al terminar el de simulador te imprime los comandos exactos para instalarlo y
lanzarlo, y los de la prueba que queda pendiente.

## ⚠️ Dos cosas que no son obvias y hacen perder tiempo

**El esquema se llama `Linphone`, el target `LinphoneApp`.** No coinciden, y el
`.app` que sale es `LinphoneApp.app` aunque en la pantalla del iPhone se vea como
«Gastecom». El identificador es `es.gastecom.softphone.phone`.

**Para archivar de cara a TestFlight, el esquema TIENE que ser Release.** En Debug
la app registra `apns.dev` mientras Apple emite un token de producción, y las
notificaciones no llegan. Está documentado en `../../CLAUDE.md`.

## Dependencias que se bajan solas (Swift Package Manager)

- `linphone-sdk-swift-ios` — el SDK, desde GitHub (no desde gitlab.linphone.org,
  así que no sufre la intermitencia que da problemas en el PC)
- `AppAuth-iOS`
- `firebase-ios-sdk`
- `Elegant-Emoji-Picker`

La primera resolución tarda: el SDK de Linphone es grande.

## ✅ Ya hay una compilación lista en el Mac Mini de Gastecom

Verificado el **2026-08-18**: se extrajo este mismo paquete en una carpeta nueva y
vacía y se compiló desde cero con el script. **BUILD SUCCEEDED.**

En `192.168.111.195` queda preparado, para que la prueba pendiente sea inmediata:

- Proyecto compilado en `~/prueba-v2/linphone-iphone/` (5,6 GB con la salida)
- Simulador **iPhone 17** (`68B9A9DC-CF5E-4AFC-A268-592A851456F6`) arrancado, con
  la compilación de hoy ya instalada

Así que basta con:

```bash
DEV=68B9A9DC-CF5E-4AFC-A268-592A851456F6
xcrun simctl launch $DEV es.gastecom.softphone.phone
xcrun simctl openurl $DEV 'tel:600123456'      # pulsa "Abrir" en el dialogo
xcrun simctl openurl $DEV 'sip-linphone:600123456'
```

## 🔴 La prueba que falta, y por qué no la he podido hacer yo

El **marcado automático**: al abrir un `tel:` la app debe dejar el número en el
marcador y **no** llamar. El código está puesto desde el 2026-08-06 y ahora
sabemos que **compila**, pero no está probado en ejecución.

Lo intenté en el simulador y me quedé a un toque:

```bash
xcrun simctl openurl <UDID> 'tel:600123456'
```

iOS muestra su propio diálogo **«¿Abrir en Gastecom?»** y no existe ninguna orden
de `simctl` para pulsar botones. Probé a automatizarlo con AppleScript y falló con
*«No tienes autorización para enviar eventos Apple a System Events»*: la sesión
SSH no tiene permiso de accesibilidad. `idb`, que sí permitiría tocar la interfaz,
no está instalado en ese Mac.

**Delante del Mac son diez segundos:** lanza el `openurl`, pulsa «Abrir», y
comprueba que el número aparece en el marcador sin que arranque la llamada.

Conviene repetirlo con el esquema propio de la app, que es el vector de verdad
—una web puede invocarlo—:

```bash
xcrun simctl openurl <UDID> 'sip-linphone:600123456'
```

## Cambio hecho el 2026-08-17 que afecta a la subida

Se corrigió el **cumplimiento de exportación** (IOS-20). El proyecto enviaba el
código de Belledonne, heredado de upstream. Ahora:

- `Info.plist` → `ITSAppUsesNonExemptEncryption` = `true`, y es la **única** fuente
  de verdad del dato
- del `project.pbxproj` se quitaron `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption`
  y `INFOPLIST_KEY_ITSEncryptionExportComplianceCode`

**Consecuencia:** al subir a App Store Connect, Apple pedirá documentación de
exportación **propia de Gastecom** — un ERN por SNAP-R o un informe de
autoclasificación. Poner `false` para esquivarlo sería declarar algo que no es
cierto: la app empaqueta su propio cifrado (mbedtls para TLS, SRTP y ZRTP).
