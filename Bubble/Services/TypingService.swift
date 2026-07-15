//
//  TypingService.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 13/6/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

private final class TypingListenerBox: @unchecked Sendable {
    private let listener: ListenerRegistration

    init(_ listener: ListenerRegistration) {
        self.listener = listener
    }

    func remove() {
        listener.remove()
    }
}

actor TypingService {
    enum TypingError: LocalizedError {
        case notAuthenticated
        case invalidChatID

        var errorDescription: String? {
            switch self {
            case .notAuthenticated:
                return "No hay un usuario autenticado."
            case .invalidChatID:
                return "El identificador del chat no es válido."
            }
        }
    }

    private let database = Firestore.firestore()
    
    /// Devuelve la sub-colección **typing** del chat indicado.
    /// - Parameter chatID: id de chat privado; se ignora en público.
    /// - Parameter isPublic: `true` → global_chat, `false` → chat privado.
    private func typingRef(chatID: String, isPublic: Bool) -> CollectionReference {
        isPublic ? database.collection("public_chats").document("global_chat").collection("typing") :
        database.collection("chats").document(chatID).collection("typing")
    }
    
    // MARK: – API ...
    
    /// Marca al usuario como «escribiendo» o borra su marca.
    /// Guarda un timestamp para depuración/limpieza futura.
    func setTyping(chatID: String, isTyping: Bool, isPublic: Bool = false) async throws {
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else {
            throw TypingError.notAuthenticated
        }
        guard isPublic || !chatID.isEmpty else {
            throw TypingError.invalidChatID
        }

        let ref = typingRef(chatID: chatID, isPublic: isPublic).document(uid)
        if isTyping {
            try await ref.setData(["isTyping": true,
                                   "ts": FieldValue.serverTimestamp()])
        } else {
            try await ref.delete()
        }
    }
   
    /// Devuelve un flujo con los *UID* de quienes están escribiendo (excluyéndote).
    /// Se actualiza en tiempo real gracias a `addSnapshotListener`.
    func typingPublisher(chatID: String, isPublic: Bool = false) -> AsyncThrowingStream<[String], Error> {
        guard let currentUserID = Auth.auth().currentUser?.uid, !currentUserID.isEmpty else {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: TypingError.notAuthenticated)
            }
        }
        guard isPublic || !chatID.isEmpty else {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: TypingError.invalidChatID)
            }
        }

        return Self.makeTypingStream(
            chatID: chatID,
            isPublic: isPublic,
            currentUserID: currentUserID
        )
    }

    private nonisolated static func makeTypingStream(
        chatID: String,
        isPublic: Bool,
        currentUserID: String
    ) -> AsyncThrowingStream<[String], Error> {
        AsyncThrowingStream { continuation in
            let database = Firestore.firestore()
            let reference = isPublic
                ? database.collection("public_chats").document("global_chat").collection("typing")
                : database.collection("chats").document(chatID).collection("typing")

            let listener = reference.addSnapshotListener { snapshot, error in
                if let error {
                    continuation.finish(throwing: error)
                    return
                }

                let ids = snapshot?.documents.map(\.documentID) ?? []
                continuation.yield(ids.filter { $0 != currentUserID })
            }

            let listenerBox = TypingListenerBox(listener)
            continuation.onTermination = { _ in
                listenerBox.remove()
            }
        }
    }
}
