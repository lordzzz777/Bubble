//
//  PublicChatService.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 16/3/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

private final class PublicChatListenerBox: @unchecked Sendable {
    private let listener: ListenerRegistration

    init(_ listener: ListenerRegistration) {
        self.listener = listener
    }

    func remove() {
        listener.remove()
    }
}

actor PublicChatService {
    private let database = Firestore.firestore()
    private let chatsRef = Firestore.firestore().collection("public_chats").document("global_chat")
    private let messageEncryptionService = MessageEncryptionService()
    
    /// Obtiene los mensajes del chat público en tiempo real utilizando `AsyncThrowingStream`.
    ///
    /// - Returns: Un flujo asíncrono (`AsyncThrowingStream`) que emite listas de `MessageModel` actualizadas en tiempo real.
    /// - Throws: Si ocurre un error en la suscripción a Firestore, el flujo finaliza con una excepción.
    func fetchPublicChatMessages() -> AsyncThrowingStream<[MessageModel], Error> {
        Self.makePublicMessagesStream(encryptionService: messageEncryptionService)
    }

    private nonisolated static func makePublicMessagesStream(
        encryptionService: MessageEncryptionService
    ) -> AsyncThrowingStream<[MessageModel], Error> {
        AsyncThrowingStream { continuation in
            let query = Firestore.firestore()
                .collection("public_chats")
                .document("global_chat")
                .collection("messages")
                .order(by: "timestamp", descending: false)

            let listener = query.addSnapshotListener { snapshot, error in
                if let error {
                    continuation.finish(throwing: error)
                    return
                }

                let documents = snapshot?.documents ?? []
                Task {
                    var messages: [MessageModel] = []
                    for document in documents {
                        do {
                            var message = try document.data(as: MessageModel.self)
                            message.id = document.documentID
                            if let reactions = document.data()["reactions"] as? [String: String] {
                                message.reactions = reactions
                            }

                            if message.encryptionVersion != nil, message.type == .text {
                                do {
                                    message = try await encryptionService.decrypt(
                                        message,
                                        chatID: "global_chat"
                                    )
                                } catch {
                                    message.content = "No se pudo descifrar este mensaje"
                                }
                            }
                            messages.append(message)
                        } catch {
                            AppLogger.error("Error al parsear mensaje público.")
                        }
                    }
                    continuation.yield(messages)
                }
            }

            let listenerBox = PublicChatListenerBox(listener)
            continuation.onTermination = { _ in
                listenerBox.remove()
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
            // Igual que en el chat privado: además del marcador hay que retirar
            // el cifrado, o el listener descifra y vuelve a mostrar el texto original.
            try await messageRef.updateData([
                "content": "Mensaje eliminado",
                "encryptedContent": FieldValue.delete(),
                "encryptedReplyingToText": FieldValue.delete(),
                "encryptedMessageKeys": FieldValue.delete(),
                "attachmentFileName": FieldValue.delete(),
                "senderPublicKey": FieldValue.delete(),
                "encryptionVersion": FieldValue.delete(),
                "encryptionScheme": FieldValue.delete()
            ])
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
