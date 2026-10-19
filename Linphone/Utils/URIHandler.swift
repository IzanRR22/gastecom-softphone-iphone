/*
 * Copyright (c) 2010-2024 Belledonne Communications SARL.
 *
 * This file is part of linphone-iphone
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

import Foundation
import linphonesw
import Combine
import SwiftUI

class URIHandler {
	
	// Need to cover all Info.plist URL schemes.
	private static let callSchemes = ["sip", "sip-linphone", "linphone-sip", "tel", "callto"]
	private static let secureCallSchemes = ["sips", "sips-linphone", "linphone-sips"]
	private static let configurationSchemes = ["linphone-config"]
	private static let sharedExtensionSchemes = ["linphone-message"]
	private static let mentionSchemes = ["linphone-mention"]

	private static var uriHandlerCoreDelegate: CoreDelegateStub?
	
	static func addCoreDelegate() {
		uriHandlerCoreDelegate = CoreDelegateStub(
			onCallStateChanged: { (_: Core, _: Call, state: Call.State, _: String) in
				if state == .Error {
					toast("Failed_uri_handler_call_failed")
					CoreContext.shared.removeCoreDelegateStub(delegate: uriHandlerCoreDelegate!)
				}
				if state == .End {
					CoreContext.shared.removeCoreDelegateStub(delegate: uriHandlerCoreDelegate!)
				}
			},
			onConfiguringStatus: { (_: Core, state: ConfiguringState, _: String) in
				if state == .Failed {
					toast("Failed_uri_handler_config_failed")
					CoreContext.shared.removeCoreDelegateStub(delegate: uriHandlerCoreDelegate!)
				}
				if state == .Successful {
					toast("Success_uri_handler_config_success")
					CoreContext.shared.removeCoreDelegateStub(delegate: uriHandlerCoreDelegate!)
				}
			})
		CoreContext.shared.addCoreDelegateStub(delegate: uriHandlerCoreDelegate!)
	}
	
	static func handleURL(url: URL) {
		Log.info("[URIHandler] handleURL scheme: \(url.scheme ?? "unknown")")
		if let scheme = url.scheme {
			if secureCallSchemes.contains(scheme) {
				initiateCall(url: url, withScheme: "sips")
			} else if callSchemes.contains(scheme) {
				initiateCall(url: url, withScheme: "sip")
			} else if configurationSchemes.contains(scheme) {
				initiateConfiguration(url: url)
			} else if sharedExtensionSchemes.contains(scheme) {
				processReceivedFiles(url: url)
			} else if mentionSchemes.contains(scheme) {
				openContact(url: url)
			} else if scheme == SingleSignOnManager.shared.ssoRedirectUri.scheme {
				continueSSO(url: url)
			} else {
				Log.error("[URIHandler] unhandled URL \(redactProvisioningToken(url.absoluteString)) (check Info.plist)")
			}
		} else {
			Log.error("[URIHandler] invalid scheme for URL \(redactProvisioningToken(url.absoluteString))")
		}
	}
	
	/// Gastecom 2026-08-06: NO se llama automáticamente.
	///
	/// Upstream construía la dirección con `interpretUrl()` y llamaba aquí mismo
	/// via `TelecomManager.shared.doCallWithCore(...)`. Con los esquemas
	/// `tel:`/`sip:`/`callto:` declarados en el Info.plist, cualquier web, correo,
	/// SMS o iframe que consiguiera un toque en un enlace establecía una llamada al
	/// número que quisiera, sin que el usuario llegara a verlo.
	///
	/// El riesgo real no es un permiso saltado: es **facturación**. Las llamadas
	/// salen por los troncales de IvozProvider/CommsMundi, así que se traduce en
	/// fraude tarificario a numeración premium, y con 200 terminales un enlace
	/// circulando por la empresa da para mucho. Mismo fix que en Android
	/// (`MainActivity.handleCallIntent`), aplicado aquí por primera vez.
	///
	/// Se MANTIENEN los esquemas registrados a propósito: así iOS sigue ofreciendo
	/// elegir entre la app de Teléfono y el softphone, que es el comportamiento que
	/// se quiere. Lo que cambia es que, al elegir el softphone, el número se deja
	/// PUESTO en el marcador (`StartCallFragment`) y es el usuario quien pulsa
	/// llamar — ver `SharedMainViewModel.pendingCallNumber`.
	///
	/// Se toma el número tal cual, sin `interpretUrl()`: es lo que el usuario
	/// espera ver, y el marcador ya lo interpreta al pulsar llamar. Por eso ya no
	/// hace falta `doOnCoreQueue` ni `addCoreDelegate()`: no se toca el core aquí.
	private static func initiateCall(url: URL, withScheme newScheme: String) {
		guard let newSchemeUrl = url.withNewScheme(newScheme) else {
			Log.error("[URIHandler] unable to build address from \(url.resourceSpecifier)")
			toast("Failed_uri_handler_bad_call_address")
			return
		}

		var numeroPrefijado = newSchemeUrl.resourceSpecifier
		if numeroPrefijado.hasPrefix("//") {
			numeroPrefijado = String(numeroPrefijado.dropFirst(2))
		}
		numeroPrefijado = numeroPrefijado.replacingOccurrences(of: "%40", with: "@") // Unescape @ si hace falta

		guard !numeroPrefijado.isEmpty else {
			Log.error("[URIHandler] empty number from \(url)")
			toast("Failed_uri_handler_bad_call_address")
			return
		}

		Log.info(
			"[URIHandler] Número [\(numeroPrefijado)] recibido desde un enlace externo: " +
			"se deja en el marcador, NO se llama automáticamente"
		)
		DispatchQueue.main.async {
			SharedMainViewModel.shared.pendingCallNumber = numeroPrefijado
		}
	}
	
	/// Dominios desde los que se acepta reaprovisionar la cuenta.
	///
	/// Comprobado por DNS el 2026-08-01 antes de fijar esta lista:
	///   sbcsoftphone.gastecom.es -> 51.92.197.34    = el SBC. Es la que usa el
	///                                                 portal (BASE_URL) y la que
	///                                                 llevan dentro los QR.
	///
	/// Se quito `sbcgastecom.gastecom.es`: resolvia a 82.223.212.145, la MISMA IP
	/// que gastecom.es, o sea el hosting de la web corporativa. No es el SBC (de
	/// hecho Caddy nunca llego a tener certificado para ese nombre). Tenerla aqui
	/// significaba aceptar aprovisionamiento desde cualquier fichero que alguien
	/// lograra subir a la web publica, que es justo lo que esta lista evita.
	///
	/// Se quito `provisioning.gastecom.es` el 2026-08-06: apuntaba al Pi antiguo
	/// (185.179.185.209), confirmado por Izan que ya no esta en uso, y verificado
	/// que ese Pi no tiene ningun contenedor de provisioning corriendo (no
	/// respondería aunque algo lo intentara). Menos superficie de aprovisionamiento
	/// aceptada = menos sitios desde los que repuntar la flota.
	private static let allowedProvisioningHosts = [
		"sbcsoftphone.gastecom.es"
	]

	/// Comprobacion compartida: hay DOS puertas al aprovisionamiento remoto y las
	/// dos acaban en `setProvisioninguri`. Esta (el esquema linphone-config:) y el
	/// escaneo de un QR (`QRScanner.swift`). No es `private` justamente para que
	/// el escaner la use y no se quede una via sin cubrir, que fue lo que paso en
	/// la primera correccion.
	///
	/// Vive aqui, y no en un fichero nuevo, para no tener que tocar el
	/// `project.pbxproj` y arriesgarse a que el fichero no entre en el target.
	/// Gastecom (2026-10-15): tapa el token de /config/<token> antes de escribir
	/// una URL de aprovisionamiento en el log. Ese token da acceso al XML con las
	/// credenciales SIP del terminal.
	static func redactProvisioningToken(_ text: String) -> String {
		return text.replacingOccurrences(of: "/config/[^\\s\"'&?#<\\]]+", with: "/config/***",
										 options: .regularExpression)
	}

	static func isProvisioningHostAllowed(_ urlString: String) -> Bool {
		guard let comps = URLComponents(string: urlString),
			  let host = comps.host?.lowercased() else {
			return false
		}
		// Se exige HTTPS ademas del dominio: el XML de aprovisionamiento lleva la
		// contrasena SIP y por http viajaria en claro.
		guard comps.scheme?.lowercased() == "https" else { return false }
		return allowedProvisioningHosts.contains(host)
	}

	private static func initiateConfiguration(url: URL) {
		if autoRemoteProvisioningOnConfigUriHandler() {
			CoreContext.shared.doOnCoreQueue { core in
				Log.info("[URIHandler] provisioning app with approved URI")
				do {
					addCoreDelegate()
					var urlString = url.resourceSpecifier
					if urlString.starts(with: "//") {
						urlString = String(urlString.dropFirst(2))
					}
					
					if !urlString.starts(with: "https://") {
						urlString = "https://" + urlString
					}

					// El esquema linphone-config: lo puede lanzar cualquier pagina web
					// o app. Sin esta comprobacion, un simple enlace repunta el telefono
					// a un SIP ajeno y toda la telefonia pasa por el, mientras la app
					// sigue mostrando "registrado".
					guard isProvisioningHostAllowed(urlString) else {
						Log.error("[URIHandler] SEGURIDAD: origen no confiable, se rechaza el aprovisionamiento")
						toast("Failed_uri_handler_bad_config_address")
						return
					}

					core.config?.setString(section: "misc", key: "config-uri", value: urlString)
					try core.setProvisioninguri(newValue: urlString)
					core.stop()
					try core.start()
				} catch {
					Log.error("[URIHandler] unable to configure the app: \(error)")
					toast("Failed_uri_handler_bad_config_address")
				}
			}
		} else {
			Log.warn("[URIHandler] received configuration request, but automatic provisioning is disabled.")
		}
	}
	
	private static func processReceivedFiles(url: URL) {
		Log.info("[URIHandler] processing received files from URL: \(url.path)")
		
		var urlString = url.path
		if urlString.starts(with: "//") {
			urlString = String(urlString.dropFirst(2))
		}
		
		for urlFile in urlString.components(separatedBy: ",") {
			SharedMainViewModel.shared.fileUrlsToShare.append(urlFile)
		}
		
		SharedMainViewModel.shared.changeIndexView(indexViewInt: 2)
	}
	
	private static func openContact(url: URL) {
		Log.info("[URIHandler] open contact from URL: \(url.resourceSpecifier)")
		
		var urlString = url.resourceSpecifier
		if urlString.starts(with: "//") {
			urlString = String(urlString.dropFirst(2))
		}

		// Gastecom fix (2026-09-30, auditoria S11): print() de depuracion suelto que
		// volcaba la URL completa a la consola del dispositivo, fuera del sistema Log.*
		// de la app. Ya se loguea arriba (linea 230) con Log.info, asi que no hace falta.

		let friendIndex = ContactsManager.shared.avatarListModel.first(
			where: {$0.addresses.contains(where: {$0 == urlString})})
		
		if friendIndex != nil {
			SharedMainViewModel.shared.displayedConversation = nil
			SharedMainViewModel.shared.changeIndexView(indexViewInt: 0)
			withAnimation {
				SharedMainViewModel.shared.displayedFriend = friendIndex
			}
		}
	}
	
	private static func continueSSO(url: URL) {
		if let authorizationFlow = SingleSignOnManager.shared.currentAuthorizationFlow,
		   authorizationFlow.resumeExternalUserAgentFlow(with: url) {
			SingleSignOnManager.shared.currentAuthorizationFlow = nil
		}
	}
	
	private static func autoRemoteProvisioningOnConfigUriHandler() -> Bool {
		return AppServices.config.getBool(section: "app", key: "auto_apply_provisioning_config_uri_handler", defaultValue: true)
	}
	
	private static func toast(_ message: String) {
		DispatchQueue.main.async {
			ToastViewModel.shared.show(message)
		}
	}
}
