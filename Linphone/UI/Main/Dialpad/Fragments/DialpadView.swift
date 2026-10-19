/*
 * Gastecom - pestaña "Teclado" fija en la barra inferior, igual que en el
 * 3CX de referencia. El grid de teclas reproduce el mismo estilo visual que
 * DialerBottomSheet.swift (History/Fragments), pero desacoplado de
 * StartCallViewModel/CallViewModel -no se toca esa pantalla, sigue sirviendo
 * para el "+" de Llamadas y el DTMF en llamada-.
 *
 * 2026-10-15: teclas de 100 pt como MAXIMO (no fijo) y margenes de 30. Con
 * 60+100+100+100+60 = 420 pt fijos la fila no cabia en los iPhone de 393 pt
 * (14 Pro, 15, 16, 16 Pro...): ensanchaba toda la pantalla, el teclado salia
 * desplazado y la barra inferior cortaba "Conversaciones". Solo cabia en los
 * Plus/Pro Max (430-440 pt).
 * Las teclas llevan .layoutPriority(1): sin eso SwiftUI reparte el ancho a
 * partes iguales entre las 3 teclas y los 2 Spacer y las teclas se quedan en
 * 63-76 pt. Con prioridad, los Spacer se quedan en su minimo (8 pt) y las
 * teclas crecen hasta 100: ~99.7 pt en 375 pt (SE) y 100 pt de 393 en adelante.
 */

import SwiftUI

struct DialpadView: View {

	@EnvironmentObject var dialpadViewModel: DialpadViewModel

	var body: some View {
		VStack(alignment: .center, spacing: 0) {

			HStack {
				Text(dialpadViewModel.dialedNumber)
					.foregroundStyle(Color.grayMain2c600)
					.default_text_style(styleSize: 25)
					.frame(maxWidth: .infinity)
					.padding(.horizontal, 10)
					.lineLimit(1)
					.truncationMode(.head)

				Button {
					dialpadViewModel.backspace()
				} label: {
					Image("backspace-fill")
						.renderingMode(.template)
						.resizable()
						.foregroundStyle(Color.grayMain2c500)
						.frame(width: 32, height: 32)
				}
				.frame(width: 100, height: 60)
				.opacity(dialpadViewModel.dialedNumber.isEmpty ? 0 : 1)
				.disabled(dialpadViewModel.dialedNumber.isEmpty)
				.simultaneousGesture(
					LongPressGesture()
						.onEnded { _ in
							dialpadViewModel.clear()
						}
				)
			}
			.padding(.horizontal, 20)
			.padding(.top, 30)
			.frame(maxWidth: SharedMainViewModel.shared.maxWidth)

			Spacer()

			digitRow(["1", "2", "3"])
				.padding(.top, 10)
			digitRow(["4", "5", "6"])
				.padding(.top, 10)
			digitRow(["7", "8", "9"])
				.padding(.top, 10)

			HStack {
				digitButton("*")

				Spacer()

				ZStack {
					Text("0")
						.foregroundStyle(Color.grayMain2c600)
						.default_text_style(styleSize: 32)
						.multilineTextAlignment(.center)
						.frame(maxWidth: 100, minHeight: 75, maxHeight: 75)
						.padding(.top, -15)
						.background(.white)
						.cornerRadius(40)
						.shadow(color: .black.opacity(0.2), radius: 4)
					Text("+")
						.foregroundStyle(Color.grayMain2c600)
						.default_text_style(styleSize: 20)
						.multilineTextAlignment(.center)
						.frame(maxWidth: 100, minHeight: 85, maxHeight: 85)
						.padding(.bottom, -25)
						.background(.clear)
						.cornerRadius(40)
				}
				.simultaneousGesture(
					LongPressGesture()
						.onEnded { _ in
							dialpadViewModel.appendDigit("+")
						}
				)
				.highPriorityGesture(
					TapGesture()
						.onEnded { _ in
							dialpadViewModel.appendDigit("0")
						}
				)
				.layoutPriority(1)

				Spacer()

				digitButton("#")
			}
			.padding(.horizontal, 30)
			.padding(.top, 10)
			.frame(maxWidth: SharedMainViewModel.shared.maxWidth)

			Button {
				dialpadViewModel.call()
			} label: {
				Image("phone")
					.renderingMode(.template)
					.resizable()
					.foregroundStyle(.white)
					.frame(width: 32, height: 32)
			}
			.frame(width: 100, height: 60)
			.background(Color.greenSuccess500)
			.cornerRadius(40)
			.shadow(color: .black.opacity(0.2), radius: 4)
			.padding(.top, 20)
			.opacity(dialpadViewModel.dialedNumber.isEmpty ? 0.4 : 1)
			.disabled(dialpadViewModel.dialedNumber.isEmpty)

			Spacer()
		}
		.frame(maxWidth: .infinity)
		.frame(maxHeight: .infinity)
		.background(.white)
	}

	@ViewBuilder
	func digitRow(_ digits: [String]) -> some View {
		HStack {
			digitButton(digits[0])
			Spacer()
			digitButton(digits[1])
			Spacer()
			digitButton(digits[2])
		}
		.padding(.horizontal, 30)
		.frame(maxWidth: SharedMainViewModel.shared.maxWidth)
	}

	@ViewBuilder
	func digitButton(_ digit: String) -> some View {
		Button {
			dialpadViewModel.appendDigit(digit)
		} label: {
			Text(digit)
				.foregroundStyle(Color.grayMain2c600)
				.default_text_style(styleSize: 32)
				.multilineTextAlignment(.center)
				.frame(maxWidth: 100, minHeight: 60, maxHeight: 60)
				.background(.white)
				.cornerRadius(40)
				.shadow(color: .black.opacity(0.2), radius: 4)
		}
		.layoutPriority(1)
	}
}

#Preview {
	DialpadView()
		.environmentObject(DialpadViewModel())
}
