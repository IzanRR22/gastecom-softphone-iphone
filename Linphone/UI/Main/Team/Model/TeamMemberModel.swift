/*
 * Gastecom - pestaña "Equipo" (BLF), igual que en Android/PC.
 *
 * Un compañero configurado en la sección "gastecom_team" del aprovisionamiento
 * (ver TeamListViewModel), con su estado de llamada en vivo (BLF, RFC 4235
 * Event:dialog). A diferencia de Android (que usa iconos led_*), aquí el
 * estado se pinta con un simple punto de color -no hay assets de LED en este
 * proyecto- para no tener que añadir imágenes nuevas al catálogo.
 */

import SwiftUI
import Combine

class TeamMemberModel: ObservableObject, Identifiable {
	let id: String
	let ext: String
	let name: String
	let addressString: String

	var displayName: String { name.isEmpty ? ext : name }

	@Published var stateLabel: String
	@Published var stateColor: Color

	init(ext: String, name: String, addressString: String) {
		self.id = ext
		self.ext = ext
		self.name = name
		self.addressString = addressString
		self.stateLabel = String(localized: "team_member_state_unknown")
		self.stateColor = Color.grayMain2c400
	}

	// dialog-info (RFC 4235): terminated=libre, confirmed/early/proceeding/trying=en llamada.
	func updateState(dialogState: String) {
		let label: String
		let color: Color
		switch dialogState {
		case "terminated":
			label = String(localized: "team_member_state_free")
			color = Color.greenSuccess500
		case "confirmed", "early", "proceeding", "trying":
			label = String(localized: "team_member_state_in_call")
			color = Color.orangeMain500
		default:
			label = String(localized: "team_member_state_unknown")
			color = Color.grayMain2c400
		}
		DispatchQueue.main.async {
			self.stateLabel = label
			self.stateColor = color
		}
	}
}
