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
    private let messageEncryptionService = MessageEncryptionService()
    
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
                    
                    Task {
                        var messages: [MessageModel] = []
                        for doc in documents {
                            do {
                                var message = try doc.data(as: MessageModel.self)
                                message.id = doc.documentID
                                
                                if let reactions = doc.data()["reactions"] as? [String: String] {
                                    message.reactions = reactions
                                }
                                
                                if message.encryptionVersion != nil, message.type == .text {
                                    do {
                                        message = try await self.messageEncryptionService.decrypt(message, chatID: self.chatsRef.documentID)
                                    } catch {
                                        message.content = "No se pudo descifrar este mensaje"
                                    }
                                }
                                
                                messages.append(message)
                            } catch {
                                AppLogger.error("Error al parsear mensaje público.")
                            }
                        }
                        
                        continuation.yield(with: .success(messages))
                    }
                }
        }
    }
    
    /// Envía un mensaje al chat público en Firestore.
    ///
    /// - Parameter message: El mensaje `MessageModel` que se enviará.
    /// - Throws: Lanza un error si la operación en Firestore falla.
    func sendPublicMessage(_ message: MessageModel) async throws {
        let encryptedMessage = try await encryptedTextMessageIfNeeded(message)
        try await chatsRef.collection("messages").document(encryptedMessage.id).setData(encryptedMessage.dictionary)
    }
    
    /// Actualiza el contenido de un mensaje específico por ID.
    func editMessage(messageID: String, newContent: String) async throws {
        let messageRef = chatsRef.collection("messages").document(messageID)
        AppLogger.debug("Editando mensaje público.")
        try await messageRef.updateData(["content": newContent])
    }
    
    /// Marca un mensaje como eliminado, sin borrarlo físicamente.
    func deleteMessage(messageID: String) async throws {
        let messageRef = chatsRef.collection("messages").document(messageID)
        
        do{
            try await messageRef.updateData(["content": "Mensaje eliminado"])
        }catch{
            AppLogger.error("El mensaje público no se ha actualizado.")
            throw error
        }
        
    }
    
    /// Elimina físicamente un mensaje de Firestore.
    func permanentlyDeleteMessage(messageID: String) async throws {
        let messgeRef = chatsRef.collection("messages").document(messageID)
        
        do{
            try await messgeRef.delete()
            AppLogger.info("Mensaje público eliminado.")
        }catch{
            AppLogger.error("Error al eliminar mensaje público.")
            throw error
        }
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
                    AppLogger.debug("El usuario ya está en el chat público.")
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
    
    func publicChatParticipantIDs() async throws -> [String] {
        let chatDoc = try await chatsRef.getDocument()
        return chatDoc["participants"] as? [String] ?? []
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
    
    /// Agrega metodo para actualizar la reacción
    func reactToMessage(messageID: String, emoji: String, userID: String) async throws {
        let messageRef = chatsRef.collection("messages").document(messageID)
        //try await messageRef.updateData(["reactions.\(userID)": emoji])
        do {
            try await messageRef.updateData(["reactions.\(userID)": emoji])
        } catch {
            AppLogger.error("No se guardó la reacción pública.")
            throw error
        }
    }

    /// Elimina la reaccion del mensaje
    func removeReaction(fromMessageID messageID: String, userID: String) async throws {
        let messageRef = chatsRef.collection("messages").document(messageID)
        try await messageRef.updateData(["reactions.\(userID)": FieldValue.delete()])
    }
    
    private func encryptedTextMessageIfNeeded(_ message: MessageModel) async throws -> MessageModel {
        guard message.type == .text, !message.content.isEmpty, message.encryptedContent == nil else {
            return message
        }
        
        let participantIDs = try await publicChatParticipantIDs()
        let payload = try await messageEncryptionService.encryptText(
            message.content,
            replyingToText: message.replyingToText,
            chatID: chatsRef.documentID,
            messageID: message.id,
            participantIDs: participantIDs
        )
        
        var encryptedMessage = message
        encryptedMessage.content = "Mensaje cifrado"
        if payload.encryptedReplyingToText != nil {
            encryptedMessage.replyingToText = "Mensaje cifrado"
        }
        encryptedMessage.encryptedContent = payload.encryptedContent
        encryptedMessage.encryptedReplyingToText = payload.encryptedReplyingToText
        encryptedMessage.encryptedMessageKeys = payload.encryptedMessageKeys
        encryptedMessage.senderPublicKey = payload.senderPublicKey
        encryptedMessage.encryptionVersion = payload.encryptionVersion
        encryptedMessage.encryptionScheme = payload.encryptionScheme
        return encryptedMessage
    }
}
