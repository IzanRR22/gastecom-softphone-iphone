/*
 * Copyright (c) 2010-2023 Belledonne Communications SARL.
 *
 * This file is part of Linphone
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

import linphonesw
import Foundation
import SwiftUI
import AVFoundation

struct QRScanner: UIViewControllerRepresentable {
	
	@Binding var result: String
	
	func makeUIViewController(context: Context) -> QRScannerController {
		let controller = QRScannerController()
		controller.delegate = context.coordinator
		
		return controller
	}
	
	func makeCoordinator() -> Coordinator {
		Coordinator($result)
	}
	
	func updateUIViewController(_ uiViewController: QRScannerController, context: Context) {
	}
}

class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {

	private var coreContext = CoreContext.shared

	@Binding var scanResult: String
	private var lastResult: String = ""
	private var didInitiateProvisioning: Bool = false

	private var mCoreDelegate: CoreDelegate?

	init(_ scanResult: Binding<String>) {
		self._scanResult = scanResult
		super.init()

		addDelegate()
	}
	
	func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
		
		// Check if the metadataObjects array is not nil and it contains at least one object.
		if metadataObjects.isEmpty {
			scanResult = "Scan a QR code"
			return
		}
		
		// Get the metadata object.
		guard let metadataObj = metadataObjects[0] as? AVMetadataMachineReadableCodeObject else {
			return
		}
		
		if metadataObj.type == AVMetadataObject.ObjectType.qr,
		   let result = metadataObj.stringValue {
			if !result.isEmpty && result != lastResult {
				Log.info("[QRScanner] QR detected")

				let provisioningUrl: String?

				if result.hasPrefix("linphone-config:") {
					// Standard Linphone provisioning scheme
					var configUrl = String(result.dropFirst("linphone-config:".count))
					if configUrl.hasPrefix("//") {
						configUrl = "https://" + String(configUrl.dropFirst(2))
					}
					provisioningUrl = configUrl
				} else if result.hasPrefix("https://") || result.hasPrefix("http://") {
					// Portal generates a plain HTTPS/HTTP URL without linphone-config: prefix
					provisioningUrl = result
				} else {
					provisioningUrl = nil
				}

				// Un QR merece la misma desconfianza que un enlace: basta con pegar
				// una pegatina encima de la buena, o mandar un PDF, para reapuntar
				// el terminal al SBC de otro. Misma comprobacion que la via del
				// esquema linphone-config:, compartida a proposito.
				//
				// Ademas la rama de arriba acepta "http://" tal cual, y el XML de
				// aprovisionamiento lleva dentro la contrasena SIP.
				if let url = provisioningUrl, !URIHandler.isProvisioningHostAllowed(url) {
					Log.error("[QRScanner] SEGURIDAD: QR con origen no permitido, se descarta")
					// Se marca como ya visto: si no, la camara vuelve a leer el mismo
					// QR en cada fotograma y repite aviso y traza sin parar.
					lastResult = result
					DispatchQueue.main.async {
						ToastViewModel.shared.show("Gastecom_provisioning_host_rejected")
					}
					return
				}

				if let url = provisioningUrl {
					Log.info("[QRScanner] Using approved provisioning URL")
					lastResult = result
					didInitiateProvisioning = true
					coreContext.doOnCoreQueue { core in
						try? core.setProvisioninguri(newValue: url)
						core.stop()
						try? core.start()
					}
				} else {
					DispatchQueue.main.async {
						ToastViewModel.shared.show("Invalide URI")
					}
				}
			}
		}
	}
	
	func addDelegate() {
		mCoreDelegate = CoreDelegateStub(
			onConfiguringStatus: { (_: Core, status: ConfiguringState, message: String) in
				Log.info("New configuration state is \(status) = \(message)")
				self.handleConfigurationChanged(status: status)
			}
		)
		
		if let delegate = mCoreDelegate {
			coreContext.doOnCoreQueue { core in
				core.addDelegate(delegate: delegate)
			}
		}
	}
	
	func handleConfigurationChanged(status: ConfiguringState) {
		guard didInitiateProvisioning else { return }
		switch status {
		case .Successful:
			DispatchQueue.main.async {
				ToastViewModel.shared.show("Success_qr_code_validated")
			}
		case .Failed:
			// OJO: aqui el QR se leyo bien y el XML se descargo bien. Lo que ha
			// fallado es APLICAR la configuracion. Upstream mostraba el mismo
			// "URI no valida" que cuando el QR es ilegible, y eso mando el
			// diagnostico del 2026-08-03 en la direccion equivocada durante horas:
			// el fallo real era un servidor LDAP inalcanzable dentro del perfil.
			Log.error("[QRScanner] Configuracion DESCARGADA pero no aplicada. " +
			          "Mirar el contenido del perfil (LDAP, proxy), no el QR.")
			DispatchQueue.main.async {
				ToastViewModel.shared.show("Gastecom_provisioning_apply_failed")
			}
		default:
			break
		}
	}
}
