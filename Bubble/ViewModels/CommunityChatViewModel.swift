import Foundation
import FirebaseAuth
import SwiftUI

@Observable @MainActor
final class CommunityChatViewModel {
    private let communityChatService = CommunityChatService()
    private var messagesTask: Task<Void, Never>?

    var communities: [CommunityModel] = []
    var selectedCommunity: CommunityModel?
    var messages: [MessageModel] = []
    var members: [UserModel] = []
    var userColors: [String: Color] = [:]
    var isLoadingCommunities = false
    var isLoadingMessages = false
    var hasAccess = true
    var showError = false
    var errorTitle = ""
    var errorMessage = ""

    func stopListening() {
        messagesTask?.cancel()
        messagesTask = nil
    }

    func loadCommunities() async {
        isLoadingCommunities = true
        defer { isLoadingCommunities = false }

        do {
            communities = try await communityChatService.fetchCommunitiesForCurrentUser()
        } catch {
            showError(title: "Comunidades no disponibles", message: "No se pudo cargar tus comunidades. Verifica tu conexión a internet.")
        }
    }

    func openCommunity(_ community: CommunityModel) async {
        selectedCommunity = community
        isLoadingMessages = true
        hasAccess = true
        messages = []
        members = []
        messagesTask?.cancel()

        do {
            try await communityChatService.assertCurrentUserCanAccessCommunity(communityID: community.id)
            members = try await communityChatService.fetchMembers(for: community)
            assignColorsToMembers()
            listenMessages(communityID: community.id)
        } catch CommunityChatService.CommunityChatError.notMember,
                CommunityChatService.CommunityChatError.blocked {
            hasAccess = false
            isLoadingMessages = false
            showError(title: "Acceso denegado", message: "No tienes acceso a este chat.")
        } catch {
            isLoadingMessages = false
            showError(title: "Mensajes no disponibles", message: "No se pudo cargar los mensajes. Verifica tu conexión a internet.")
        }
    }

    func sendMessage(_ text: String) async -> Bool {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty, let communityID = selectedCommunity?.id else { return false }

        do {
            try await communityChatService.sendTextMessage(communityID: communityID, text: trimmedText)
            return true
        } catch CommunityChatService.CommunityChatError.notMember,
                CommunityChatService.CommunityChatError.blocked {
            hasAccess = false
            showError(title: "Acceso denegado", message: "No tienes acceso a este chat.")
            return false
        } catch {
            showError(title: "Error al enviar", message: "Error al enviar el mensaje. Inténtalo más tarde.")
            return false
        }
    }

    func member(for userID: String) -> UserModel? {
        members.first { $0.id == userID }
    }

    func colorForUser(userID: String) -> Color {
        userColors[userID] ?? .accentColor
    }

    func isCurrentUser(_ userID: String) -> Bool {
        Auth.auth().currentUser?.uid == userID
    }

    private func listenMessages(communityID: String) {
        messagesTask = Task { [weak self] in
            guard let self else { return }

            do {
                for try await messages in await communityChatService.listenMessages(communityID: communityID) {
                    self.messages = messages
                    self.isLoadingMessages = false
                }
            } catch {
                self.isLoadingMessages = false
                self.showError(title: "Mensajes no disponibles", message: "No se pudo cargar los mensajes. Verifica tu conexión a internet.")
            }
        }
    }

    private func assignColorsToMembers() {
        userColors.removeAll()
        guard !members.isEmpty else { return }

        for (index, member) in members.enumerated() {
            let hue = Double(index) / Double(members.count)
            userColors[member.id] = Color(hue: hue, saturation: 0.62, brightness: 0.88)
        }
    }

    private func showError(title: String, message: String) {
        errorTitle = title
        errorMessage = message
        showError = true
    }
}
