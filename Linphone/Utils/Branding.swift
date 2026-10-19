import Foundation

// Gastecom Softphone — iOS Branding & Configuration
// Todos los valores específicos de la app Gastecom para iPhone.
// Este fichero reemplaza los defaults de Linphone upstream.

enum GastecomBranding {

    // MARK: — Identidad
    static let appName     = "Gastecom"
    static let bundleId    = "es.gastecom.softphone.phone"   // el sufijo .phone es el real, no cambiar
    static let version     = "6.1.0"

    // MARK: — Soporte
    static let supportEmail      = "soporte@gastecom.es"
    static let website           = URL(string: "https://gastecom.es")!
    static let privacyPolicy     = URL(string: "https://gastecom.es/politica-de-privacidad-softphone/")!
    static let termsAndConditions = URL(string: "https://gastecom.es/aviso-legal/")!

    // MARK: — SIP (SBC Kamailio en producción)
    // Todos los registros usan TLS puerto 5091
    static let sipProxyHost      = "sbcsoftphone.gastecom.es"
    static let sipProxyPort      = 5091
    static let sipProxyTransport = "tls"

    // Portal de provisioning QR
    static let sbcHost           = "sbcsoftphone.gastecom.es"
    static let sbcPort           = 5091
    static let sbcTransport      = "tls"

    // MARK: — Push Notifications (iOS/APNs + PushKit)
    //
    // iOS usa APNs (Apple Push Notification service), NO Firebase FCM.
    // El servidor de push es Flexisip corriendo en el servidor Gastecom.
    //
    // Arquitectura:
    //   iPhone ──REGISTER──► SBC Kamailio (5080/5091)
    //                               │ (extrae pn-prid del Contact)
    //                               ▼
    //   INVITE entrante ──► Flexisip envía APNs ──► Apple ──► iPhone despierta
    //
    // Flexisip debe estar configurado con el APNs .p8 key.
    // Ver: iphone/flexisip-apns-setup.sh para la configuración del servidor.
    //
    static let pushProxyHost      = "sbcsoftphone.gastecom.es"
    static let pushProxyPort      = 5065        // Puerto Flexisip
    static let pushProxyTransport = "udp"

    // Bundle ID del topic APNs (debe coincidir con el Bundle ID real de la app)
    static let apnsTopic          = "es.gastecom.softphone.phone"
    // Para VoIP PushKit, el topic tiene el sufijo .voip
    static let apnsVoipTopic      = "es.gastecom.softphone.phone.voip"

    // Entorno APNs. NO hay que cambiar nada a mano al pasar a producción.
    //
    // El valor real que se registra NO sale de aquí: lo fija el SDK en tres sitios
    // (CoreContext.swift:291, AccountLoginViewModel.swift:135 y
    // RegisterViewModel.swift:299) con `#if DEBUG` -> ".dev", `#else` -> "".
    // Es decir: build Debug -> apns.dev (sandbox), build Release -> apns (producción).
    // Y el servicio de push del SBC deduce el host de APNs por dispositivo leyendo
    // el pn-provider del contacto registrado, así que un terminal de desarrollo y
    // uno de TestFlight pueden convivir sin tocar nada.
    //
    // Esta constante estaba antes con el comentario "cambia a apns cuando subas a
    // App Store" y NADIE LA LEE. El 2026-08-03 ese comentario me llevó a dar por
    // bloqueado el despliegue por un problema que no existía. Se deja derivada para
    // que, si algún día alguien la usa, no pueda estar desincronizada.
#if DEBUG
    static let apnsProvider       = "apns.dev"   // sandbox
#else
    static let apnsProvider       = "apns"       // producción
#endif

    // MARK: — Colores Gastecom (naranja corporativo)
    // Para usar en SwiftUI: Color("OrangePrimary")
    // Para UIKit: UIColor(named: "OrangePrimary")
    static let primaryColor   = "#F07D00"   // orange_main_500 — botones, tint, navbar
    static let primaryDark    = "#C06000"   // orange_main_700 — pressed/dark
    static let primaryLight   = "#F8A94B"   // orange_main_300 — secundario
    static let primaryPale    = "#FDE8D0"   // orange_main_100 — fondos
}
