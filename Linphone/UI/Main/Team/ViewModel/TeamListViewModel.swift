/*
 * Gastecom - pestaña "Equipo" (BLF), igual que en Android/PC.
 *
 * Lee la sección "gastecom_team" del XML de aprovisionamiento (mismo formato
 * que ya sirve el portal para PC/Android: member_N = "ext|nombre") y suscribe
 * Event:dialog (RFC 4235, BLF real) por cada miembro con la API de bajo nivel
 * core.createSubscribe() - el Friend normal del SDK solo sabe Event:presence,
 * y ese lo rechaza IvozProvider (489 Bad Event). Mismo criterio ya verificado
 * en PC y Android contra el mismo SBC (ver memoria softphone-blf-equipo-20260819).
 *
 * ⚠️ La firma exacta de core.createSubscribe/Event en linphonesw no se ha
 * podido verificar en esta sesión (sin Mac/Xcode a mano) — se ha escrito
 * siguiendo el mismo patrón que el resto del wrapper Swift (createXxx()
 * "throws", delegados "XxxDelegateStub" + "addDelegate(delegate:)", visto en
 * ConferenceDelegateStub/CallDelegateStub/ChatRoomDelegateStub). Si el nombre
 * exacto no coincide, Xcode lo señala al compilar y se ajusta aquí.
 */

import linphonesw
import Combine
import SwiftUI

class TeamListViewModel: ObservableObject {

	static let TAG = "[TeamListViewModel]"

	// IvozProvider respondió 423 Interval Too Brief / Min-Expires: 1800
	// al primer intento con 600 (ya probado en vivo con el softphone de PC).
	private static let subscribeExpires: Int = 1800

	@Published var members: [TeamMemberModel] = []

	private var events: [Event] = []

	private var eventDelegates: [EventDelegate] = []

	// Gastecom (2026-10-15): antes la lista y las suscripciones se creaban una
	// sola vez en init(). Si cambiaba la cuenta por defecto, Equipo seguia con
	// los miembros, el dominio y las suscripciones del perfil anterior.
	private var coreDelegate: CoreDelegate?

	init() {
		CoreContext.shared.doOnCoreQueue { core in
			self.startSubscriptions(core: core)
			// [weak self]: el Core retiene el delegado; con self fuerte el
			// ViewModel no se liberaria nunca y deinit no daria de baja nada.
			let delegate = CoreDelegateStub(onDefaultAccountChanged: { [weak self] (core: Core, _: Account?) in
				guard let self = self else { return }
				Log.info("\(TeamListViewModel.TAG) Default account changed, reloading team members and subscriptions")
				self.stopSubscriptions()
				self.startSubscriptions(core: core)
			})
			core.addDelegate(delegate: delegate)
			self.coreDelegate = delegate
		}
	}

	deinit {
		let delegate = coreDelegate
		let oldEvents = events
		CoreContext.shared.doOnCoreQueue { core in
			if let delegate = delegate {
				core.removeDelegate(delegate: delegate)
			}
			for event in oldEvents {
				event.terminate()
			}
		}
	}

	private func stopSubscriptions() {
		for event in events {
			event.terminate()
		}
		events.removeAll()
		eventDelegates.removeAll()
	}

	private func startSubscriptions(core: Core) {
		let domain = core.defaultAccount?.params?.domain ?? "sbcsoftphone.gastecom.es"

		// 2026-10-15: en linphonesw 5.5.6 core.config es Config? (opcional).
		guard let config = core.config else {
			Log.warn("\(TeamListViewModel.TAG) Core sin config, sin pestana Equipo")
			return
		}

		var list: [TeamMemberModel] = []
		var index = 0
		while true {
			let raw = config.getString(section: "gastecom_team", key: "member_\(index)", defaultString: "")
			if raw.isEmpty { break }
			guard let separatorRange = raw.range(of: "|") else {
				index += 1
				continue
			}
			let ext = String(raw[raw.startIndex..<separatorRange.lowerBound]).trimmingCharacters(in: .whitespaces)
			let name = String(raw[separatorRange.upperBound...]).trimmingCharacters(in: .whitespaces)
			if !ext.isEmpty {
				list.append(TeamMemberModel(ext: ext, name: name, addressString: "sip:\(ext)@\(domain)"))
			}
			index += 1
		}

		Log.info("\(TeamListViewModel.TAG) Found [\(list.count)] team members in provisioning")

		DispatchQueue.main.async {
			self.members = list
		}

		for memberModel in list {
			guard let address = try? Factory.Instance.createAddress(addr: memberModel.addressString) else {
				Log.warn("\(TeamListViewModel.TAG) Could not parse address for [\(memberModel.ext)]")
				continue
			}

			guard let event = try? core.createSubscribe(resource: address, event: "dialog", expires: TeamListViewModel.subscribeExpires) else {
				Log.error("\(TeamListViewModel.TAG) Could not create subscribe for [\(memberModel.ext)]")
				continue
			}

			// linphonesw 5.5.6: onNotifyReceived recibe (Event, Content?), sin el String del evento.
			let delegate = EventDelegateStub(onNotifyReceived: { (_: Event, content: Content?) in
				let body = content?.utf8Text ?? ""
				memberModel.updateState(dialogState: TeamListViewModel.parseDialogState(body))
			})
			event.addDelegate(delegate: delegate)
			eventDelegates.append(delegate)

			do {
				try event.sendSubscribe(body: nil)
			} catch {
				Log.error("\(TeamListViewModel.TAG) Failed to send subscribe for [\(memberModel.ext)]: \(error)")
			}

			events.append(event)
		}
	}

	func callMember(_ model: TeamMemberModel) {
		CoreContext.shared.doOnCoreQueue { _ in
			if let address = try? Factory.Instance.createAddress(addr: model.addressString) {
				TelecomManager.shared.doCallOrJoinConf(address: address)
			} else {
				Log.error("\(TeamListViewModel.TAG) Failed to parse address [\(model.addressString)] to call")
			}
		}
	}

	// Mismo patrón que el resto de la app para 1-1: los compañeros de equipo
	// son siempre del mismo dominio que la cuenta -se construyen con ese
	// dominio en startSubscriptions()-, así que no hace falta contemplar un
	// dominio distinto como sí necesitaría un contacto cualquiera.
	func messageMember(_ model: TeamMemberModel) {
		let sharedMainViewModel = SharedMainViewModel.shared
		CoreContext.shared.doOnCoreQueue { core in
			guard let account = core.defaultAccount else { return }
			guard let remote = try? Factory.Instance.createAddress(addr: model.addressString) else {
				Log.error("\(TeamListViewModel.TAG) Failed to parse address [\(model.addressString)] to message")
				return
			}

			do {
				let params = try core.createConferenceParams(conference: nil)
				params.chatEnabled = true
				params.groupEnabled = false
				params.subject = String(localized: "conversation_one_to_one_hidden_subject")
				params.account = account

				guard let chatParams = params.chatParams else { return }
				chatParams.ephemeralLifetime = 0

				if account.params?.instantMessagingEncryptionMandatory == true || LinphoneUtils.isEndToEndEncryptedChatAvailable(core: core) {
					chatParams.backend = ChatRoom.Backend.FlexisipChat
					params.securityLevel = Conference.SecurityLevel.EndToEnd
				} else {
					chatParams.backend = ChatRoom.Backend.Basic
					params.securityLevel = Conference.SecurityLevel.None
				}

				let participants = [remote]
				let localAddress = account.params?.identityAddress

				if let existingChatRoom = core.searchChatRoom(params: params, localAddr: localAddress, remoteAddr: nil, participants: participants) {
					Log.info("\(TeamListViewModel.TAG) Found existing conversation with [\(model.ext)]")
					let conversationModel = ConversationModel(chatRoom: existingChatRoom)
					DispatchQueue.main.async {
						sharedMainViewModel.displayedConversation = conversationModel
						sharedMainViewModel.changeIndexView(indexViewInt: 2)
					}
					return
				}

				Log.info("\(TeamListViewModel.TAG) No existing conversation with [\(model.ext)], creating it")
				let chatRoom = try core.createChatRoom(params: params, participants: participants)
				let conversationModel = ConversationModel(chatRoom: chatRoom)
				DispatchQueue.main.async {
					sharedMainViewModel.displayedConversation = conversationModel
					sharedMainViewModel.changeIndexView(indexViewInt: 2)
				}
			} catch {
				Log.error("\(TeamListViewModel.TAG) Failed to create 1-1 conversation with [\(model.ext)]: \(error)")
			}
		}
	}

	private static func parseDialogState(_ xml: String) -> String {
		guard let startRange = xml.range(of: "<state>"), let endRange = xml.range(of: "</state>"), startRange.upperBound <= endRange.lowerBound else {
			return "unknown"
		}
		return String(xml[startRange.upperBound..<endRange.lowerBound]).trimmingCharacters(in: .whitespaces)
	}
}
