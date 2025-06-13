//
//  TypingService.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 13/6/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

actor TypingService {
    private let database = Firestore.firestore()
    private let uid = Auth.auth().currentUser?.uid ?? ""
    
    /// Listener vivo que no es `Sendable`; se mantiene dentro del actor.
    private var typingListener: ListenerRegistration?
    
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
        let ref = typingRef(chatID: chatID, isPublic: isPublic)
        
        return AsyncThrowingStream { continuation in
            
            self.typingListener = ref.addSnapshotListener { [weak self] snap, err in
                guard let self else { return }
                if let err { continuation.finish(throwing: err); return }
                
                let ids = snap?.documents.map(\.documentID) ?? []
                continuation.yield(ids.filter { $0 != self.uid })
            }
            
            // Limpia el listener cuando el stream se cancele.
            continuation.onTermination = { [weak self] _ in
                Task { await self?.stopTypingListener() }
            }
        }
    }
    
    /// Cierra la suscripción y libera memoria.
    private func stopTypingListener() {
        typingListener?.remove()
        typingListener = nil
    }
}
