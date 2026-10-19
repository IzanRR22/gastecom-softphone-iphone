/*
 * Gastecom - pestaña "Teclado" fija en la barra inferior, igual que en el
 * Android (ver DialpadViewModel.kt) y en el 3CX de referencia. Reutiliza la
 * misma llamada que StartCallViewModel.interpretAndStartCall() pero no toca
 * esa pantalla -sigue sirviendo para el "+" de Llamadas y sus sugerencias de
 * contacto-, aquí el teclado está siempre visible en vez de en un bottom
 * sheet.
 */

import linphonesw
import Combine
import SwiftUI

class DialpadViewModel: ObservableObject {

	static let TAG = "[DialpadViewModel]"

	@Published var dialedNumber: String = ""

	func appendDigit(_ digit: String) {
		dialedNumber += digit
	}

	func backspace() {
		if !dialedNumber.isEmpty {
			dialedNumber = String(dialedNumber.dropLast())
		}
	}

	func clear() {
		dialedNumber = ""
	}

	func call() {
		let urlToCall = dialedNumber
		guard !urlToCall.isEmpty else { return }
		CoreContext.shared.doOnCoreQueue { core in
			let address = core.interpretUrl(url: urlToCall, applyInternationalPrefix: LinphoneUtils.applyInternationalPrefix(core: core))
			if address != nil {
				TelecomManager.shared.doCallOrJoinConf(address: address!)
				DispatchQueue.main.async {
					self.dialedNumber = ""
				}
			}
		}
	}
}
