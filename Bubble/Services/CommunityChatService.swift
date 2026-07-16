import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import UIKit

private final class CommunityListenerBox: @unchecked Sendable {
    private let listener: ListenerRegistration

    init(_ listener: ListenerRegistration) {
        self.listener = listener
    }

    func remove() {
        listener.remove()
    }
}

actor CommunityChatService {
    private let database = Firestore.firestore()
    private let messageEncryptionService = MessageEncryptionService()
    private let readStateService = ReadStateService()

    enum CommunityChatError: LocalizedError {
        case notAuthenticated
        case communityNotFound
        case notMember
        case blocked
        case notOwner

        var errorDescription: String? {
            switch self {
            case .notAuthenticated:
                return "Usuario no autenticado."
            case .communityNotFound:
                return "Comunidad no encontrada."
            case .notMember:
                return "No tienes acceso a este chat."
            case .blocked:
                return "No tienes acceso a este chat."
            case .notOwner:
                return "Solo el propietario puede eliminar la comunidad."
            }
        }
    }

    func fetchCommunitiesForCurrentUser() async throws -> [CommunityModel] {
        let uid = try currentUserID()
        let memberSnapshot = try await database.collection("communities")
            .whereField("members", arrayContains: uid)
            .getDocuments()
        let ownedSnapshot = try await database.collection("communities")
            .whereField("ownerUID", isEqualTo: uid)
            .getDocuments()

        var communitiesByID: [String: CommunityModel] = [:]
        for document in memberSnapshot.documents + ownedSnapshot.documents {
            if var community = try? document.data(as: CommunityModel.self) {
                community.id = document.documentID
                communitiesByID[community.id] = community
            }
        }

        return communitiesByID.values.sorted {
            $0.createdAt.dateValue() > $1.createdAt.dateValue()
        }
    }

    func fetchMembers(for community: CommunityModel) async throws -> [UserModel] {
        let memberIDs = Array(Set(community.members + [community.ownerUID]))
        var members: [UserModel] = []

        for memberID in memberIDs {
            let document = try await database.collection("users").document(memberID).getDocument()
            guard var user = try? document.data(as: UserModel.self), user.isDeleted != true else { continue }
            user.id = document.documentID
            members.append(user)
        }

        return members.sorted { $0.nickname.localizedCaseInsensitiveCompare($1.nickname) == .orderedAscending }
    }

    func listenMessages(communityID: String) -> AsyncThrowingStream<[MessageModel], Error> {
        Self.makeMessagesStream(
            communityID: communityID,
            encryptionService: messageEncryptionService
        )
    }

    private nonisolated static func makeMessagesStream(
        communityID: String,
        encryptionService: MessageEncryptionService
    ) -> AsyncThrowingStream<[MessageModel], Error> {
        AsyncThrowingStream { continuation in
            let listener = Firestore.firestore().collection("communities")
                .document(communityID)
                .collection("messages")
                .order(by: "timestamp", descending: false)
                .addSnapshotListener { snapshot, error in
                    if let error {
                        continuation.finish(throwing: error)
                        return
                    }

                    Task {
                        var messages: [MessageModel] = []
                        for document in snapshot?.documents ?? [] {
                            do {
                                var message = try document.data(as: MessageModel.self)
                                message.id = document.documentID
                                
                                if message.encryptionVersion != nil, message.type == .text {
                                    do {
                                        message = try await encryptionService.decrypt(message, chatID: communityID)
                                    } catch {
                                        message.content = "No se pudo descifrar este mensaje"
                                    }
                                }
                                
                                messages.append(message)
                            } catch {
                                AppLogger.error("Error al parsear mensaje de comunidad.")
                            }
                        }

                        continuation.yield(messages)
                    }
                }

            let listenerBox = CommunityListenerBox(listener)
            continuation.onTermination = { _ in
                listenerBox.remove()
            }
        }
    }

    func sendTextMessage(
        communityID: String,
        text: String,
        replyTo repliedMessage: MessageModel? = nil,
        replyingToNickname: String? = nil
    ) async throws {
        let uid = try currentUserID()
        try await assertCurrentUserCanAccessCommunity(communityID: communityID)

        let message = MessageModel(
            id: UUID().uuidString,
            senderUserID: uid,
            content: text,
            timestamp: Timestamp(date: .now),
            type: .text,
            replyToMessageID: repliedMessage?.id,
            replyingToText: repliedMessage?.content,
            replyingToNickname: replyingToNickname
        )

        let communityRef = database.collection("communities").document(communityID)
        let communityDocument = try await communityRef.getDocument()
        guard let community = try? communityDocument.data(as: CommunityModel.self) else {
            throw CommunityChatError.communityNotFound
        }
        let participantIDs = Array(Set(community.members + [community.ownerUID]))
        let payload = try await messageEncryptionService.encryptText(
            text,
            replyingToText: message.replyingToText,
            chatID: communityID,
            messageID: message.id,
            participantIDs: participantIDs
        )
        
        var encryptedMessage = message
        encryptedMessage.content = "Mensaje cifrado"
        encryptedMessage.encryptedContent = payload.encryptedContent
        encryptedMessage.encryptedReplyingToText = payload.encryptedReplyingToText
        if payload.encryptedReplyingToText != nil { encryptedMessage.replyingToText = "Mensaje cifrado" }
        encryptedMessage.encryptedMessageKeys = payload.encryptedMessageKeys
        encryptedMessage.senderPublicKey = payload.senderPublicKey
        encryptedMessage.encryptionVersion = payload.encryptionVersion
        encryptedMessage.encryptionScheme = payload.encryptionScheme
        
        try await communityRef.collection("messages").document(encryptedMessage.id).setData(encryptedMessage.dictionary)
        try await communityRef.updateData([
            "lastMessage": "Mensaje cifrado",
            "lastMessageTimestamp": encryptedMessage.timestamp,
            "lastMessageSenderUserID": uid
        ])
        try await readStateService.incrementCommunity(
            communityID: communityID,
            senderID: uid,
            participantIDs: participantIDs
        )
    }

    func sendImage(communityID: String, image: UIImage) async throws {
        guard let data = image.jpegData(compressionQuality: 0.78) else { throw URLError(.cannotDecodeContentData) }
        try await sendAttachment(communityID: communityID, data: data, type: .image, fileName: nil)
    }

    func sendFile(communityID: String, fileURL: URL) async throws {
        let access = fileURL.startAccessingSecurityScopedResource()
        defer { if access { fileURL.stopAccessingSecurityScopedResource() } }
        let values = try fileURL.resourceValues(forKeys: [.fileSizeKey])
        if (values.fileSize ?? 0) > 25 * 1024 * 1024 {
            throw NSError(domain: "CommunityChat", code: 25, userInfo: [NSLocalizedDescriptionKey: "El archivo supera el límite de 25 MB."])
        }
        try await sendAttachment(
            communityID: communityID,
            data: Data(contentsOf: fileURL),
            type: .file,
            fileName: fileURL.lastPathComponent
        )
    }

    func sendVoice(communityID: String, fileURL: URL, duration: Double) async throws {
        try await sendAttachment(
            communityID: communityID,
            data: Data(contentsOf: fileURL),
            type: .audio,
            fileName: nil,
            audioDuration: duration
        )
    }

    private func sendAttachment(
        communityID: String,
        data: Data,
        type: MessageType,
        fileName: String?,
        audioDuration: Double? = nil
    ) async throws {
        let uid = try currentUserID()
        try await assertCurrentUserCanAccessCommunity(communityID: communityID)
        let participants = try await participantIDs(communityID: communityID)
        let messageID = UUID().uuidString
        let payload = try await messageEncryptionService.encryptAttachmentData(
            data, chatID: communityID, messageID: messageID, participantIDs: participants
        )
        let folder = type == .image ? "chat_images" : (type == .audio ? "voice_notes" : "shared_files")
        let reference = Storage.storage().reference().child("\(folder)/\(messageID).bin")
        let metadata = StorageMetadata()
        metadata.contentType = "application/octet-stream"
        metadata.customMetadata = ["ownerUID": uid]
        _ = try await reference.putDataAsync(payload.encryptedData, metadata: metadata)
        let url = try await reference.downloadURL().absoluteString
        var message = MessageModel(
            id: messageID, senderUserID: uid, content: url,
            timestamp: Timestamp(date: .now), type: type,
            audioDuration: audioDuration,
            attachmentFileName: fileName
        )
        message.encryptedMessageKeys = payload.encryptedMessageKeys
        message.senderPublicKey = payload.senderPublicKey
        message.encryptionVersion = payload.encryptionVersion
        message.encryptionScheme = payload.encryptionScheme
        try await saveAdvancedMessage(communityID: communityID, message: message, participants: participants)
    }

    private func saveAdvancedMessage(communityID: String, message: MessageModel, participants: [String]) async throws {
        let reference = database.collection("communities").document(communityID)
        try await reference.collection("messages").document(message.id).setData(message.dictionary)
        try await reference.updateData([
            "lastMessage": message.type == .text ? "Mensaje cifrado" : "Adjunto cifrado",
            "lastMessageTimestamp": message.timestamp,
            "lastMessageSenderUserID": message.senderUserID
        ])
        try await readStateService.incrementCommunity(
            communityID: communityID, senderID: message.senderUserID, participantIDs: participants
        )
    }

    func decryptedAttachment(_ message: MessageModel, communityID: String) async throws -> Data {
        guard let url = URL(string: message.content) else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try await messageEncryptionService.decryptAttachmentData(data, message: message, chatID: communityID)
    }

    func react(communityID: String, messageID: String, emoji: String?) async throws {
        let uid = try currentUserID()
        try await assertCurrentUserCanAccessCommunity(communityID: communityID)
        let value: Any = emoji ?? FieldValue.delete()
        try await database.collection("communities").document(communityID)
            .collection("messages").document(messageID).updateData(["reactions.\(uid)": value])
    }

    func editMessage(communityID: String, messageID: String, content: String) async throws {
        let uid = try currentUserID()
        let participants = try await participantIDs(communityID: communityID)
        let payload = try await messageEncryptionService.encryptText(
            content, chatID: communityID, messageID: messageID, participantIDs: participants
        )
        try await database.collection("communities").document(communityID)
            .collection("messages").document(messageID).updateData([
                "content": "Mensaje cifrado", "encryptedContent": payload.encryptedContent,
                "encryptedMessageKeys": payload.encryptedMessageKeys,
                "senderPublicKey": payload.senderPublicKey,
                "encryptionVersion": payload.encryptionVersion,
                "encryptionScheme": payload.encryptionScheme,
                "senderUserID": uid
            ])
    }

    func deleteMessage(communityID: String, messageID: String) async throws {
        try await database.collection("communities").document(communityID)
            .collection("messages").document(messageID).updateData([
                "content": "Mensaje eliminado", "type": MessageType.text.rawValue,
                "encryptedContent": FieldValue.delete(), "encryptedReplyingToText": FieldValue.delete(),
                "encryptedMessageKeys": FieldValue.delete(), "senderPublicKey": FieldValue.delete(),
                "encryptionVersion": FieldValue.delete(), "encryptionScheme": FieldValue.delete(),
                "attachmentFileName": FieldValue.delete(), "reactions": FieldValue.delete()
            ])
    }

    private func participantIDs(communityID: String) async throws -> [String] {
        let document = try await database.collection("communities").document(communityID).getDocument()
        guard let community = try? document.data(as: CommunityModel.self) else { throw CommunityChatError.communityNotFound }
        return Array(Set(community.members + [community.ownerUID]))
    }

    func markCommunityRead(communityID: String) async throws {
        try await readStateService.markCommunityRead(communityID: communityID)
    }

    func fetchInvitableFriends(for community: CommunityModel) async throws -> [UserModel] {
        let uid = try currentUserID()
        guard community.ownerUID == uid else { throw CommunityChatError.notOwner }
        let ownerDocument = try await database.collection("users").document(uid).getDocument()
        let friendIDs = Set(ownerDocument.data()?["friends"] as? [String] ?? [])
        let existingIDs = Set(community.members + [community.ownerUID])
        let snapshot = try await database.collection("users")
            .whereField("isDeleted", isEqualTo: false)
            .getDocuments()
        let users = snapshot.documents.compactMap { document -> UserModel? in
            guard !existingIDs.contains(document.documentID), document.documentID != uid,
                  var user = try? document.data(as: UserModel.self) else { return nil }
            user.id = document.documentID
            return user
        }
        return users.sorted { lhs, rhs in
            let lhsIsFriend = friendIDs.contains(lhs.id)
            let rhsIsFriend = friendIDs.contains(rhs.id)
            if lhsIsFriend != rhsIsFriend { return lhsIsFriend }
            return lhs.nickname.localizedCaseInsensitiveCompare(rhs.nickname) == .orderedAscending
        }
    }

    func addMember(communityID: String, userID: String, role: AdminRole?) async throws {
        let uid = try currentUserID()
        let reference = database.collection("communities").document(communityID)
        let document = try await reference.getDocument()
        guard var community = try? document.data(as: CommunityModel.self) else {
            throw CommunityChatError.communityNotFound
        }
        guard community.ownerUID == uid else { throw CommunityChatError.notOwner }

        if !community.members.contains(userID) { community.members.append(userID) }
        community.admins.removeAll { $0.id == userID }
        if let role {
            community.admins.append(AdminModel(
                id: userID,
                role: role,
                canRead: true,
                canWrite: true,
                canInvite: true,
                canKick: role == .admin,
                canMute: true,
                canChangeRole: role == .admin
            ))
        }
        try await reference.updateData([
            "members": community.members,
            "admins": community.admins.map(\.dictionary)
        ])
    }

    func updateCommunityImage(communityID: String, image: UIImage) async throws -> String {
        let uid = try currentUserID()
        let communityRef = database.collection("communities").document(communityID)
        let document = try await communityRef.getDocument()
        guard let community = try? document.data(as: CommunityModel.self) else {
            throw CommunityChatError.communityNotFound
        }
        guard community.ownerUID == uid else { throw CommunityChatError.notOwner }
        guard let data = image.jpegData(compressionQuality: 0.72) else {
            throw URLError(.cannotDecodeContentData)
        }

        // Una ruta nueva evita que imágenes antiguas sin ownerUID bloqueen el reemplazo.
        let reference = Storage.storage().reference()
            .child("communities/\(communityID)-\(UUID().uuidString).jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        metadata.customMetadata = ["ownerUID": uid]
        _ = try await reference.putDataAsync(data, metadata: metadata)
        let url = try await reference.downloadURL().absoluteString
        try await communityRef.updateData(["imgUrl": url])
        return url
    }

    func deleteCommunity(communityID: String, imageURL: String) async throws {
        let uid = try currentUserID()
        let communityRef = database.collection("communities").document(communityID)
        let document = try await communityRef.getDocument()
        guard let community = try? document.data(as: CommunityModel.self) else {
            throw CommunityChatError.communityNotFound
        }
        guard community.ownerUID == uid else {
            throw CommunityChatError.notOwner
        }

        // Firestore no elimina subcolecciones junto con el documento padre.
        // Borramos los mensajes en lotes antes de eliminar la comunidad.
        while true {
            let messages = try await communityRef.collection("messages").limit(to: 400).getDocuments()
            guard !messages.documents.isEmpty else { break }
            let batch = database.batch()
            messages.documents.forEach { batch.deleteDocument($0.reference) }
            try await batch.commit()
        }

        try await communityRef.delete()

        guard !imageURL.isEmpty else { return }
        do {
            try await Storage.storage().reference(forURL: imageURL).delete()
        } catch {
            // Una imagen heredada puede no tener ownerUID. La comunidad ya se
            // eliminó correctamente; el archivo podrá limpiarlo un administrador.
            AppLogger.warning("La comunidad se eliminó, pero no se pudo limpiar su imagen.")
        }
    }

    func assertCurrentUserCanAccessCommunity(communityID: String) async throws {
        let uid = try currentUserID()
        let document = try await database.collection("communities").document(communityID).getDocument()
        guard let community = try? document.data(as: CommunityModel.self) else {
            throw CommunityChatError.communityNotFound
        }

        guard community.ownerUID == uid || community.members.contains(uid) else {
            throw CommunityChatError.notMember
        }

        guard !community.blockedUsers.contains(uid) else {
            throw CommunityChatError.blocked
        }
    }

    private func currentUserID() throws -> String {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw CommunityChatError.notAuthenticated
        }
        return uid
    }
}
