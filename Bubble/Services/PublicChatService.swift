//
//  PublicChatService.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 16/3/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

actor PublicChatService {
    private let database = Firestore.firestore()
    private let chatsRef = Firestore.firestore().collection("public_chats").document("global_chat")
    
    /// Obtiene los mensajes del chat público en tiempo real utilizando `AsyncThrowingStream`.
    ///
    /// - Returns: Un flujo asíncrono (`AsyncThrowingStream`) que emite listas de `MessageModel` actualizadas en tiempo real.
    /// - Throws: Si ocurre un error en la suscripción a Firestore, el flujo finaliza con una excepción.
    func fetchPublicChatMessages() -> AsyncThrowingStream<[MessageModel], Error> {
        return AsyncThrowingStream { continuation in
            chatsRef.collection("messages")
                .order(by: "timestamp", descending: false)
                .addSnapshotListener { snapshot, error in
                    if let error = error {
                        continuation.finish(throwing: error)
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        continuation.yield(with: .success([]))
                        return
                    }
                    
                    let messages = documents.compactMap { try? $0.data(as: MessageModel.self) }
                    continuation.yield(with: .success(messages))
                }
        }
    }
    
    /// Envía un mensaje al chat público en Firestore.
    ///
    /// - Parameter message: El mensaje `MessageModel` que se enviará.
    /// - Throws: Lanza un error si la operación en Firestore falla.
    func sendPublicMessage(_ message: MessageModel) async throws {
        try await chatsRef.collection("messages").addDocument(data: message.dictionary)
    }
    
    /// Agrega un usuario al chat público "global_chat". Si el chat no existe, lo crea.
    ///
    /// - Parameter userID: El identificador del usuario que se agregará al chat.
    /// - Throws: Lanza un error si la operación en Firestore falla.
    func addUserToPublicChat(userID: String) async throws {
        do {
            let chatDoc = try await chatsRef.getDocument()
            
            if chatDoc.exists {
                var participants = chatDoc["participants"] as? [String] ?? []
                
                if !participants.contains(userID) {
                    participants.append(userID)
                    try await chatsRef.updateData(["participants": participants])
                }else{
                    print("Usuario \(userID) ya está en el chat público.")
                }
                
            } else {
                let publicChatData: [String: Any] = [
                    "id": "global_chat",
                    "participants": [userID],
                    "lastMessage": "Bienvenidos al chat público!",
                    "lastMessageTimestamp": Timestamp()
                ]
                try await chatsRef.setData(publicChatData)
            }
        } catch {
            throw error
        }
    }
    
    /// Obtiene todos los usuarios visibles en Firestore.
    /// - Returns: Un array de `UserModel` con los usuarios que no están marcados como eliminados.
    func fetchVisibleUsers() async throws -> [UserModel] {
        do{
            let querySnapshot = try await database.collection("users") .whereField("isDeleted", isEqualTo: false).getDocuments()
            return querySnapshot.documents.compactMap({try? $0.data(as: UserModel.self)})
        }catch{
            throw error
        }
    }
}
