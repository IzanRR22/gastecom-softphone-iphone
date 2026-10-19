#!/bin/bash
# ============================================================================
#  Compilar el softphone de Gastecom para iOS, en un Mac
#
#  Uso:
#     ./compilar-en-mac.sh              compila para SIMULADOR, sin firma
#     ./compilar-en-mac.sh simulador    igual que arriba
#     ./compilar-en-mac.sh dispositivo  compila para iPhone real (NECESITA firma)
#
#  Los comandos de aquí NO son teóricos: están verificados el 2026-08-17 en el
#  Mac Mini de Gastecom (192.168.111.195, macOS 26.5.1, Xcode 26.2). La
#  compilación de simulador dio BUILD SUCCEEDED.
# ============================================================================

set -euo pipefail
cd "$(dirname "$0")"

MODO="${1:-simulador}"
PROYECTO="LinphoneApp.xcodeproj"
ESQUEMA="Linphone"          # ojo: el ESQUEMA es "Linphone", el TARGET es "LinphoneApp"
BUNDLE="es.gastecom.softphone.phone"

echo "=== Comprobaciones previas ==="

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "ERROR: no hay xcodebuild. Instala Xcode desde la App Store y luego:"
  echo "       sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  exit 1
fi
echo "  Xcode: $(xcodebuild -version | head -1)"

if [ ! -d "$PROYECTO" ]; then
  echo "ERROR: no encuentro $PROYECTO. ¿Has copiado la carpeta entera?"
  exit 1
fi

# Las dependencias son Swift Package Manager y se descargan de GitHub. Hace falta
# red la primera vez: linphone-sdk-swift-ios, AppAuth-iOS, firebase-ios-sdk y
# Elegant-Emoji-Picker. En el Mac de Gastecom ya estaban en cache y resolvio solo.
echo "  Resolviendo dependencias SPM (la primera vez tarda: baja el SDK de Linphone)..."
xcodebuild -resolvePackageDependencies -project "$PROYECTO" -scheme "$ESQUEMA" >/dev/null 2>&1 || {
  echo "ERROR: no se pudieron resolver los paquetes. Revisa la conexion a GitHub."
  exit 1
}
echo "  dependencias OK"
echo

case "$MODO" in
  simulador)
    echo "=== Compilando para SIMULADOR (sin firma) ==="
    # CODE_SIGNING_ALLOWED=NO es lo que permite compilar sin certificados. Sirve
    # para verificar que el codigo compila y para probar en el simulador.
    #
    # -derivedDataPath fija la salida DENTRO del proyecto, y no es un capricho:
    # la primera version de este script buscaba el .app con
    #     find ~/Library/Developer/Xcode/DerivedData -name LinphoneApp.app | head -1
    # y eso devolvia CUALQUIERA de las compilaciones anteriores. En el Mac de
    # Gastecom habia cuatro carpetas DerivedData de este proyecto, de rutas
    # distintas, y el script imprimio la ruta de una compilacion del dia
    # anterior. Habria hecho instalar un binario viejo creyendo que era el nuevo.
    # Con -derivedDataPath la ruta es una sola y es la de ESTA compilacion.
    SALIDA="$PWD/build-simulador"
    xcodebuild -scheme "$ESQUEMA" -project "$PROYECTO" \
               -sdk iphonesimulator \
               -destination 'generic/platform=iOS Simulator' \
               -configuration Debug \
               -derivedDataPath "$SALIDA" \
               CODE_SIGNING_ALLOWED=NO \
               build
    APP="$SALIDA/Build/Products/Debug-iphonesimulator/LinphoneApp.app"
    if [ ! -d "$APP" ]; then
      echo "ERROR: la compilacion dijo que fue bien pero no encuentro $APP"
      exit 1
    fi
    # Se comprueba que el .app es de AHORA, no un resto de otra compilacion.
    echo "  .app generado: $(date -r "$APP" '+%Y-%m-%d %H:%M:%S')"
    echo
    echo "=== LISTO ==="
    echo "  App: $APP"
    echo
    echo "Para probarla en el simulador:"
    echo "  DEV=\$(xcrun simctl list devices available | grep -m1 'iPhone' | sed 's/.*(\\([0-9A-F-]*\\)).*/\\1/')"
    echo "  xcrun simctl boot \$DEV ; sleep 10"
    echo "  xcrun simctl install \$DEV \"$APP\""
    echo "  xcrun simctl launch \$DEV $BUNDLE"
    echo
    echo "PRUEBA PENDIENTE del marcado automatico (esto es lo que falta por verificar):"
    echo "  xcrun simctl openurl \$DEV 'tel:600123456'"
    echo "  -> iOS preguntara '¿Abrir en Gastecom?'. PULSA 'Abrir'."
    echo "  -> DEBE aparecer el numero en el marcador y NO debe iniciarse la llamada."
    echo "  Ese toque no se puede automatizar por SSH: falta permiso de"
    echo "  accesibilidad para enviar Apple Events, y idb no esta instalado."
    ;;

  dispositivo)
    echo "=== Compilando para DISPOSITIVO ==="
    echo
    echo "⚠️  Esto NECESITA firma: cuenta de desarrollador de Gastecom, certificado"
    echo "    y perfil de aprovisionamiento para $BUNDLE y sus extensiones"
    echo "    (msgNotificationService, linphoneExtension, intentsExtension)."
    echo
    echo "⚠️  Para ARCHIVAR de cara a TestFlight, el esquema TIENE que ser Release."
    echo "    En Debug la app registra apns.dev mientras Apple emite un token de"
    echo "    produccion, y las notificaciones no llegan. Esta documentado en"
    echo "    ../../CLAUDE.md."
    echo
    xcodebuild -scheme "$ESQUEMA" -project "$PROYECTO" \
               -sdk iphoneos \
               -destination 'generic/platform=iOS' \
               -configuration Release \
               build
    ;;

  *)
    echo "ERROR: modo no valido '$MODO'. Usa 'simulador' o 'dispositivo'."
    exit 1
    ;;
esac
