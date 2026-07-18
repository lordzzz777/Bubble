import Foundation
@preconcurrency import FirebaseFirestore
import FirebaseAuth
import Observation
import UserNotifications

private final class ReadStateListenerBox: @unchecked Sendable {
    private let listeners: [ListenerRegistration]

    init(_ listeners: [ListenerRegistration]) {
        self.listeners = listeners
    }

    func remove() {
        listeners.forEach { $0.remove() }
    }
}

enum ReadStateError: LocalizedError {
    case notAuthenticated
    case invalidIdentifier

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "No hay un usuario autenticado."
        case .invalidIdentifier:
            return "No se pudo identificar la conversación."
        }
    }
}

/// Mantiene contadores de no leídos por usuario dentro de cada chat.
/// `FieldValue.increment` evita perder incrementos si llegan mensajes desde
/// varios dispositivos al mismo tiempo.
actor ReadStateService {
    private let database = Firestore.firestore()

    func incrementPrivateChat(chatID: String, senderID: String) async throws {
        guard !chatID.isEmpty, !senderID.isEmpty else { throw ReadStateError.invalidIdentifier }
        let chatRef = database.collection("chats").document(chatID)
        let snapshot = try await chatRef.getDocument()
        let participants = snapshot.data()?["participants"] as? [String] ?? []
        try await increment(reference: chatRef, participantIDs: participants, senderID: senderID)
    }

    func incrementCommunity(communityID: String, senderID: String, participantIDs: [String]) async throws {
        guard !communityID.isEmpty, !senderID.isEmpty else { throw ReadStateError.invalidIdentifier }
        let reference = database.collection("communities").document(communityID)
        try await increment(reference: reference, participantIDs: participantIDs, senderID: senderID)
    }

    func markPrivateChatRead(chatID: String) async throws {
        try await markRead(reference: database.collection("chats").document(chatID), identifier: chatID)
    }

    func markCommunityRead(communityID: String) async throws {
        try await markRead(reference: database.collection("communities").document(communityID), identifier: communityID)
    }

    func badgeCounts() -> AsyncThrowingStream<(chats: Int, communities: Int), Error> {
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else {
            return AsyncThrowingStream { $0.finish(throwing: ReadStateError.notAuthenticated) }
        }
        return Self.makeBadgeStream(uid: uid)
    }

    private func increment(reference: DocumentReference, participantIDs: [String], senderID: String) async throws {
        var updates: [String: Any] = [
            "unreadCounts.\(senderID)": 0,
            "lastReadAt.\(senderID)": FieldValue.serverTimestamp()
        ]
        for participantID in Set(participantIDs) where !participantID.isEmpty && participantID != senderID {
            updates["unreadCounts.\(participantID)"] = FieldValue.increment(Int64(1))
        }
        try await reference.updateData(updates)
    }

    private func markRead(reference: DocumentReference, identifier: String) async throws {
        guard !identifier.isEmpty else { throw ReadStateError.invalidIdentifier }
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else {
            throw ReadStateError.notAuthenticated
        }
        try await reference.updateData([
            "unreadCounts.\(uid)": 0,
            "lastReadAt.\(uid)": FieldValue.serverTimestamp()
        ])
    }

    private nonisolated static func makeBadgeStream(
        uid: String
    ) -> AsyncThrowingStream<(chats: Int, communities: Int), Error> {
        AsyncThrowingStream { continuation in
            let database = Firestore.firestore()
            let lock = NSLock()
            var chatCount = 0
            var memberCommunities: [String: Int] = [:]
            var ownedCommunities: [String: Int] = [:]

            func yieldCounts() {
                lock.lock()
                let chats = chatCount
                let communities = memberCommunities.merging(ownedCommunities) { first, _ in first }.values.reduce(0, +)
                lock.unlock()
                continuation.yield((chats, communities))
            }

            let chatsListener = database.collection("chats")
                .whereField("participants", arrayContains: uid)
                .addSnapshotListener { snapshot, error in
                    if let error { continuation.finish(throwing: error); return }
                    lock.lock()
                    chatCount = snapshot?.documents.reduce(0) {
                        $0 + (($1.data()["unreadCounts"] as? [String: Int])?[uid] ?? 0)
                    } ?? 0
                    lock.unlock()
                    yieldCounts()
                }

            let memberListener = database.collection("communities")
                .whereField("members", arrayContains: uid)
                .addSnapshotListener { snapshot, error in
                    if let error { continuation.finish(throwing: error); return }
                    let values = Dictionary(uniqueKeysWithValues: (snapshot?.documents ?? []).map {
                        ($0.documentID, ($0.data()["unreadCounts"] as? [String: Int])?[uid] ?? 0)
                    })
                    lock.lock(); memberCommunities = values; lock.unlock()
                    yieldCounts()
                }

            let ownerListener = database.collection("communities")
                .whereField("ownerUID", isEqualTo: uid)
                .addSnapshotListener { snapshot, error in
                    if let error { continuation.finish(throwing: error); return }
                    let values = Dictionary(uniqueKeysWithValues: (snapshot?.documents ?? []).map {
                        ($0.documentID, ($0.data()["unreadCounts"] as? [String: Int])?[uid] ?? 0)
                    })
                    lock.lock(); ownedCommunities = values; lock.unlock()
                    yieldCounts()
                }

            let box = ReadStateListenerBox([chatsListener, memberListener, ownerListener])
            continuation.onTermination = { _ in box.remove() }
        }
    }
}

@Observable @MainActor
final class NotificationBadgeViewModel {
    private let readStateService = ReadStateService()
    private var task: Task<Void, Never>?

    var chatCount = 0
    var communityCount = 0
    var publicCount = 0
    var showError = false
    var errorMessage = ""

    var totalCount: Int {
        max(0, chatCount) + max(0, communityCount) + max(0, publicCount)
    }

    func start() {
        task?.cancel()
        Task { await prepareAppIconBadge() }
        task = Task { [weak self] in
            guard let self else { return }
            do {
                for try await counts in await readStateService.badgeCounts() {
                    chatCount = counts.chats
                    communityCount = counts.communities
                    await updateAppIconBadge()
                }
            } catch {
                errorMessage = "No se pudieron sincronizar los indicadores pendientes."
                showError = true
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        chatCount = 0
        communityCount = 0
        publicCount = 0
        Task { try? await UNUserNotificationCenter.current().setBadgeCount(0) }
    }

    func updatePublicCount(_ count: Int) {
        publicCount = max(0, count)
        Task { await updateAppIconBadge() }
    }

    private func prepareAppIconBadge() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.badge])
        }
        await updateAppIconBadge()
    }

    private func updateAppIconBadge() async {
        try? await UNUserNotificationCenter.current().setBadgeCount(totalCount)
    }
}
