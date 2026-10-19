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

import SwiftUI

struct SplashScreen: View {
	var showSpinner: Bool = false

	private let brandGray = Color(red: 0.29, green: 0.29, blue: 0.29)
	private let subtitleGray = Color(red: 0.54, green: 0.54, blue: 0.54)

	var body: some View {
		ZStack {
			Color.white
				.ignoresSafeArea()

			VStack(spacing: 0) {
				Spacer()

				HStack(alignment: .center, spacing: 4) {
					Image("gastecom_logo")
						.resizable()
						.renderingMode(.original)
						.scaledToFit()
						.frame(width: 84, height: 84)

					VStack(alignment: .leading, spacing: 6) {
						(Text("gas")
							.foregroundColor(brandGray)
						 + Text("t")
							.foregroundColor(Color.orangeMain500)
						 + Text("ecom")
							.foregroundColor(brandGray))
							.font(.system(size: 36, weight: .light))

						Text("Tu operador más cercano")
							.font(.system(size: 14, weight: .regular))
							.foregroundColor(subtitleGray)
					}
				}
				.padding(.horizontal, 40)

				Spacer()

				ProgressView()
					.controlSize(.small)
					.progressViewStyle(CircularProgressViewStyle(tint: subtitleGray))
					.padding(.bottom, 60)
					.opacity(showSpinner ? 1 : 0)
			}
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.ignoresSafeArea(.all)
	}
}

#Preview {
	SplashScreen()
}
