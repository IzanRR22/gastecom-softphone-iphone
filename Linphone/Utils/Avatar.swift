/*
 * Copyright (c) 2010-2023 Belledonne Communications SARL.
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

import SwiftUI
import linphonesw

struct Avatar: View {
	
	private var contactsManager = ContactsManager.shared
	
	@ObservedObject var contactAvatarModel: ContactAvatarModel
	
	let avatarSize: CGFloat
	let hidePresence: Bool
	
	init(contactAvatarModel: ContactAvatarModel, avatarSize: CGFloat, hidePresence: Bool = false) {
		self.contactAvatarModel = contactAvatarModel
		self.avatarSize = avatarSize
		self.hidePresence = hidePresence
	}
	
	var body: some View {
		ZStack {
			if !contactAvatarModel.photo.isEmpty {
				let uniqueUrl = ContactsManager.shared.getImagePath(friendPhotoPath: contactAvatarModel.photo)
				//let finalUrl = uniqueUrl.appendingQueryItem("v", value: UUID().uuidString)

				// Gastecom fix (2026-09-30): antes AsyncImage(url:) puro, sin cache entre
				// reconstrucciones de la vista -cada reciclado de celda al hacer scroll
				// volvia a decodificar la foto de disco. CachedAvatarImage reusa el mismo
				// NSCache (ImageCache, en ChatBubbleView.swift) que ya usan los adjuntos de
				// chat, con las mismas 3 fases (cargando/exito/fallo). Ver RENDIMIENTO.md.
				CachedAvatarImage(url: uniqueUrl, avatarSize: avatarSize)
			} else if !contactAvatarModel.name.isEmpty {
				ZStack {
					Image(uiImage: contactsManager.textToImage(
						firstName: contactAvatarModel.name,
						lastName: contactAvatarModel.name.components(separatedBy: " ").count > 1
						? contactAvatarModel.name.components(separatedBy: " ")[1]
						: ""))
					.resizable()
					.frame(width: avatarSize, height: avatarSize)
					.clipShape(Circle())
				}
			} else {
				Image("profil-picture-default")
					.resizable()
					.frame(width: avatarSize, height: avatarSize)
					.clipShape(Circle())
			}
			
			if contactAvatarModel.friend != nil && !hidePresence {
				if contactAvatarModel.unsafeFriend || contactAvatarModel.trustedFriend {
					Circle()
						.stroke(contactAvatarModel.trustedFriend ? Color.blueInfo500 : Color.redDanger500, lineWidth: 2)
						.frame(width: avatarSize, height: avatarSize)
					
					HStack {
						VStack {
							Spacer()
							Image(contactAvatarModel.trustedFriend ? "trusted" : "not-trusted")
								.resizable()
								.frame(width: avatarSize/4, height: avatarSize/4)
								.padding(.trailing, avatarSize == 50 || avatarSize == 35 ? 1 : 3)
								.padding(.bottom, avatarSize == 50 || avatarSize == 35 ? 1 : 3)
						}
						Spacer()
					}
					.frame(width: avatarSize, height: avatarSize)
				}
				
				HStack {
					Spacer()
					VStack {
						Spacer()
						if !hidePresence && (contactAvatarModel.presenceStatus == .Online || contactAvatarModel.presenceStatus == .Busy) {
							Image(contactAvatarModel.presenceStatus == .Online ? "presence-online" : "presence-busy")
								.resizable()
								.frame(width: avatarSize/4, height: avatarSize/4)
								.padding(.trailing, avatarSize == 50 || avatarSize == 35 ? 1 : 3)
								.padding(.bottom, avatarSize == 50 || avatarSize == 35 ? 1 : 3)
						}
					}
				}
				.frame(width: avatarSize, height: avatarSize)
			}
		}
	}
}

// Gastecom fix (2026-09-30): extraido de Avatar.body para poder cachear con @State
// (ver RENDIMIENTO.md). Mismas 3 fases que el AsyncImage anterior: cargando (ProgressView),
// exito (foto recortada en circulo) y fallo (icono por defecto) - ningun comportamiento
// visible cambia, solo se evita redecodificar la misma foto en cada reciclado de celda.
private struct CachedAvatarImage: View {
	let url: URL
	let avatarSize: CGFloat

	@State private var loadedImage: UIImage?
	@State private var failed = false

	var body: some View {
		Group {
			if let loadedImage {
				Image(uiImage: loadedImage)
					.resizable()
					.aspectRatio(contentMode: .fill)
					.frame(width: avatarSize, height: avatarSize)
					.clipShape(Circle())
			} else if failed {
				Image("profil-picture-default")
					.resizable()
					.frame(width: avatarSize, height: avatarSize)
					.clipShape(Circle())
			} else {
				ProgressView()
					.frame(width: avatarSize, height: avatarSize)
					.onAppear(perform: load)
			}
		}
	}

	private func load() {
		if let cached = ImageCache.shared.object(forKey: url as NSURL) {
			loadedImage = cached
			return
		}
		Task {
			do {
				let (data, _) = try await URLSession.shared.data(from: url)
				if let image = UIImage(data: data) {
					ImageCache.shared.setObject(image, forKey: url as NSURL)
					await MainActor.run { loadedImage = image }
				} else {
					await MainActor.run { failed = true }
				}
			} catch {
				await MainActor.run { failed = true }
			}
		}
	}
}
