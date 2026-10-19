/*
 * Gastecom - pestaña "Equipo" (BLF), igual que en Android/PC.
 * Lista simple, sin panel de detalle -las acciones ya están en la fila-.
 */

import SwiftUI

struct TeamListView: View {

	@EnvironmentObject var teamListViewModel: TeamListViewModel

	var body: some View {
		NavigationView {
			VStack(spacing: 0) {
				if teamListViewModel.members.isEmpty {
					Spacer()
					Text("team_list_empty")
						.default_text_style(styleSize: 15)
						.multilineTextAlignment(.center)
						.padding(.horizontal, 40)
					Spacer()
				} else {
					List {
						ForEach(teamListViewModel.members) { member in
							TeamMemberRow(
								member: member,
								onCall: { teamListViewModel.callMember(member) },
								onMessage: { teamListViewModel.messageMember(member) }
							)
							.listRowSeparator(.hidden)
						}
					}
					.listStyle(.plain)
				}
			}
			.navigationTitle("")
			.navigationBarHidden(true)
		}
		.navigationViewStyle(.stack)
	}
}

private struct TeamMemberRow: View {
	@ObservedObject var member: TeamMemberModel
	var onCall: () -> Void
	var onMessage: () -> Void

	var body: some View {
		HStack(spacing: 12) {
			Circle()
				.fill(member.stateColor)
				.frame(width: 10, height: 10)

			VStack(alignment: .leading, spacing: 2) {
				Text(member.displayName)
					.default_text_style_700(styleSize: 15)
				Text("\(member.ext) · \(member.stateLabel)")
					.default_text_style(styleSize: 13)
					.foregroundStyle(Color.grayMain2c600)
			}

			Spacer()

			Button(action: onCall) {
				Image("phone")
					.renderingMode(.template)
					.resizable()
					.foregroundStyle(Color.orangeMain500)
					.frame(width: 22, height: 22)
					.padding(8)
			}
			.buttonStyle(.borderless)

			Button(action: onMessage) {
				Image("chat-teardrop-text")
					.renderingMode(.template)
					.resizable()
					.foregroundStyle(Color.orangeMain500)
					.frame(width: 22, height: 22)
					.padding(8)
			}
			.buttonStyle(.borderless)
		}
		.padding(.vertical, 6)
		.padding(.horizontal, 16)
	}
}

#Preview {
	TeamListView()
		.environmentObject(TeamListViewModel())
}
