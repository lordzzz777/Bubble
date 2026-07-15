import Foundation
import FirebaseAuth
import FirebaseFirestore

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

    enum CommunityChatError: LocalizedError {
        case notAuthenticated
        case communityNotFound
        case notMember
        case blocked

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
        AsyncThrowingStream { continuation in
            let listener = database.collection("communities")
                .document(communityID)
                .collection("messages")
                .order(by: "timestamp", descending: false)
                .addSnapshotListener { snapshot, error in
                    if let error {
                        continuation.finish(throwing: error)
                        return
                    }

                    let messages = snapshot?.documents.compactMap { document -> MessageModel? in
                        do {
                            var message = try document.data(as: MessageModel.self)
                            message.id = document.documentID
                            return message
                        } catch {
                            AppLogger.error("Error al parsear mensaje de comunidad.")
                            return nil
                        }
                    } ?? []

                    continuation.yield(messages)
                }

            let listenerBox = CommunityListenerBox(listener)
            continuation.onTermination = { _ in
                listenerBox.remove()
            }
        }
    }

    func sendTextMessage(communityID: String, text: String) async throws {
        let uid = try currentUserID()
        try await assertCurrentUserCanAccessCommunity(communityID: communityID)

        let message = MessageModel(
            id: UUID().uuidString,
            senderUserID: uid,
            content: text,
            timestamp: Timestamp(date: .now),
            type: .text
        )

        let communityRef = database.collection("communities").document(communityID)
        try await communityRef.collection("messages").document(message.id).setData(message.dictionary)
        try await communityRef.updateData([
            "lastMessage": text,
            "lastMessageTimestamp": message.timestamp,
            "lastMessageSenderUserID": uid
        ])
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
