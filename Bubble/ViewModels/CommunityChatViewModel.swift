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
    var isDeletingCommunity = false
    var invitableFriends: [UserModel] = []
    var isLoadingInvitableFriends = false
    var communityImageURL = ""
    var isUpdatingCommunityImage = false

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
        communityImageURL = community.imgUrl
        isLoadingMessages = true
        hasAccess = true
        messages = []
        members = []
        messagesTask?.cancel()
        messagesTask = nil

        do {
            try await communityChatService.assertCurrentUserCanAccessCommunity(communityID: community.id)
            members = try await communityChatService.fetchMembers(for: community)
            assignColorsToMembers()
            try await communityChatService.markCommunityRead(communityID: community.id)
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

    func updateCommunityImage(_ image: UIImage, communityID: String) async {
        isUpdatingCommunityImage = true
        defer { isUpdatingCommunityImage = false }
        do {
            communityImageURL = try await communityChatService.updateCommunityImage(
                communityID: communityID,
                image: image
            )
        } catch {
            showError(title: "No se pudo guardar la imagen", message: error.localizedDescription)
        }
    }

    func unreadCount(for community: CommunityModel) -> Int {
        guard let uid = Auth.auth().currentUser?.uid else { return 0 }
        if let count = community.unreadCounts?[uid] { return max(0, count) }
        let senderID = community.lastMessageSenderUserID
        return senderID == nil || senderID == uid ? 0 : 1
    }

    func sendMessage(_ text: String, replyingTo message: MessageModel? = nil) async -> Bool {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty, let communityID = selectedCommunity?.id else { return false }

        do {
            try await communityChatService.sendTextMessage(
                communityID: communityID,
                text: trimmedText,
                replyTo: message,
                replyingToNickname: message.map { member(for: $0.senderUserID)?.nickname ?? "Usuario" }
            )
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

    func sendImage(_ image: UIImage) async -> Bool {
        guard let communityID = selectedCommunity?.id else { return false }
        do { try await communityChatService.sendImage(communityID: communityID, image: image); return true }
        catch { showError(title: "No se pudo enviar la imagen", message: error.localizedDescription); return false }
    }

    func sendFile(_ url: URL) async -> Bool {
        guard let communityID = selectedCommunity?.id else { return false }
        do { try await communityChatService.sendFile(communityID: communityID, fileURL: url); return true }
        catch { showError(title: "No se pudo enviar el archivo", message: error.localizedDescription); return false }
    }

    func sendVoice(fileURL: URL, duration: Double) async -> Bool {
        guard let communityID = selectedCommunity?.id else { return false }
        do {
            try await communityChatService.sendVoice(
                communityID: communityID,
                fileURL: fileURL,
                duration: duration
            )
            return true
        } catch {
            showError(title: "No se pudo enviar el audio", message: error.localizedDescription)
            return false
        }
    }

    func attachmentData(for message: MessageModel) async -> Data? {
        guard let communityID = selectedCommunity?.id else { return nil }
        do { return try await communityChatService.decryptedAttachment(message, communityID: communityID) }
        catch { showError(title: "Adjunto no disponible", message: "No se pudo descargar o descifrar el adjunto."); return nil }
    }

    func react(to message: MessageModel, emoji: String?) async {
        guard let communityID = selectedCommunity?.id else { return }
        do { try await communityChatService.react(communityID: communityID, messageID: message.id, emoji: emoji) }
        catch { showError(title: "No se guardó la reacción", message: error.localizedDescription) }
    }

    func edit(_ message: MessageModel, content: String) async -> Bool {
        guard let communityID = selectedCommunity?.id else { return false }
        do { try await communityChatService.editMessage(communityID: communityID, messageID: message.id, content: content); return true }
        catch { showError(title: "No se pudo editar", message: error.localizedDescription); return false }
    }

    /// Marca el mensaje como eliminado y deja que el listener en tiempo real
    /// actualice la colección, igual que en el chat privado.
    func deleteMessageMark(messageID: String) async throws {
        guard let communityID = selectedCommunity?.id else { return }
        do {
            try await communityChatService.deleteMessage(
                communityID: communityID,
                messageID: messageID
            )

            // Mismo tiempo de cortesía que los chats público y privado.
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled else { return }
            try await communityChatService.permanentlyDeleteMessage(
                communityID: communityID,
                messageID: messageID
            )
        } catch {
            showError(title: "Error al eliminar", message: "No se pudo eliminar el mensaje.")
            AppLogger.error("No se pudo eliminar el mensaje de comunidad.")
            throw error
        }
    }

    func cleanUpDeletedMessages(olderThan seconds: TimeInterval = 60) async {
        guard let community = selectedCommunity,
              let uid = Auth.auth().currentUser?.uid else { return }

        let cutoffDate = Date().addingTimeInterval(-seconds)
        let deletableMessages = messages.filter {
            $0.content == "Mensaje eliminado"
                && $0.timestamp.dateValue() < cutoffDate
                && ($0.senderUserID == uid || community.ownerUID == uid)
        }

        for message in deletableMessages {
            do {
                try await communityChatService.permanentlyDeleteMessage(
                    communityID: community.id,
                    messageID: message.id
                )
            } catch {
                AppLogger.error("No se pudo eliminar permanentemente el mensaje de comunidad.")
            }
        }
    }

    func deleteCommunity(_ community: CommunityModel) async -> Bool {
        isDeletingCommunity = true
        defer { isDeletingCommunity = false }

        do {
            stopListening()
            try await communityChatService.deleteCommunity(
                communityID: community.id,
                imageURL: community.imgUrl
            )
            communities.removeAll { $0.id == community.id }
            return true
        } catch {
            showError(
                title: "No se pudo eliminar",
                message: error.localizedDescription
            )
            return false
        }
    }

    func updateCommunity(_ community: CommunityModel, name: String, image: UIImage?) async -> Bool {
        do {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            try await communityChatService.updateCommunityName(
                communityID: community.id,
                name: trimmedName
            )

            var imageURL = community.imgUrl
            if let image {
                imageURL = try await communityChatService.updateCommunityImage(
                    communityID: community.id,
                    image: image
                )
            }

            if let index = communities.firstIndex(where: { $0.id == community.id }) {
                communities[index].name = trimmedName
                communities[index].imgUrl = imageURL
            }
            return true
        } catch {
            showError(title: "No se pudo editar la comunidad", message: error.localizedDescription)
            return false
        }
    }

    func loadInvitableFriends(for community: CommunityModel) async {
        isLoadingInvitableFriends = true
        defer { isLoadingInvitableFriends = false }
        do {
            invitableFriends = try await communityChatService.fetchInvitableFriends(for: community)
        } catch {
            showError(title: "No se pudieron cargar los amigos", message: error.localizedDescription)
        }
    }

    func addMember(_ user: UserModel, role: AdminRole?, to community: CommunityModel) async -> Bool {
        do {
            try await communityChatService.addMember(
                communityID: community.id,
                userID: user.id,
                role: role
            )
            invitableFriends.removeAll { $0.id == user.id }
            return true
        } catch {
            showError(title: "No se pudo añadir el miembro", message: error.localizedDescription)
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
                    guard !Task.isCancelled else { return }
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

    func showError(title: String, message: String) {
        errorTitle = title
        errorMessage = message
        showError = true
    }
}
