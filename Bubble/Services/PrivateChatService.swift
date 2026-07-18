//
//  PrivateChatService.swift
//  Bubble
//
//  Created by Jacob Aguilar on 3/2/25.
//

import Foundation
@preconcurrency import FirebaseFirestore
import FirebaseAuth
import FirebaseCore
import Firebase

private final class PrivateChatListenerBox: @unchecked Sendable {
    private let listener: ListenerRegistration

    init(_ listener: ListenerRegistration) {
        self.listener = listener
    }

    func remove() {
        listener.remove()
    }
}

enum PrivateChatServiceError: Error {
    case fetchingMessagesFailed
    case fetchingDocumentsFailed
    case sendMessageFailed
}

actor PrivateChatService {
    
    private let database = Firestore.firestore()
    private let uid = Auth.auth().currentUser?.uid ?? ""
    private let messageEncryptionService = MessageEncryptionService()
    private let moderationService = ModerationService()
    private let readStateService = ReadStateService()
    
    func prepareMessageEncryptionIdentity() async throws {
        try await messageEncryptionService.ensureCurrentUserPublicKeyIsPublished()
    }
    
    /// Obtiene los chats en tiempo real en los que el usuario participa.
    /// - Returns: Un `AsyncThrowingStream` que emite un array de `ChatModel` y maneja errores.
    func getChats() -> AsyncThrowingStream<[ChatModel], Error>  {
        Self.makeChatsStream(uid: uid)
    }
    
    func checkIfFriend(friendID: String) async throws -> Bool {
        do {
            guard let currentUID = Auth.auth().currentUser?.uid else {
                throw PrivateChatServiceError.fetchingMessagesFailed
            }
            async let currentDocument = database.collection("users").document(currentUID).getDocument()
            async let friendDocument = database.collection("users").document(friendID).getDocument()
            let (currentSnapshot, friendSnapshot) = try await (currentDocument, friendDocument)
            guard let userData = try? currentSnapshot.data(as: UserModel.self) else {
                fatalError("No se pudo obtener el usuario")
            }
            let reciprocalFriendship = (try? friendSnapshot.data(as: UserModel.self))?
                .friends.contains(currentUID) ?? false
            AppLogger.debug("Comprobación de amistad completada.")
            return userData.friends.contains(friendID) || reciprocalFriendship
        } catch {
            throw error
        }
    }
    
    /// Obtiene un usuario en tiempo real desde Firestore y devuelve un flujo asíncrono de actualizaciones.
    /// - Parameter id: El ID del usuario que se desea obtener.
    /// - Returns: Un `AsyncThrowingStream` que emite `UserModel?` y maneja errores.
    func getUser(by id: String) -> AsyncThrowingStream<UserModel?, Error> {
        guard !id.isEmpty else { // Me aseguro que que si el id esta bacio no crache
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: NSError(domain: "FirestoreError", code: 0, userInfo: [NSLocalizedDescriptionKey: "El ID de usuario no puede estar vacío."]))
            }
        }
        return Self.makeUserStream(id: id)
    }
    
    /// Obtiene los mensajes de un chat en tiempo real usando un `SnapshotListener`.
    ///
    /// - Parameters:
    ///   - chatID: El identificador único del chat del cual se desean obtener los mensajes.
    ///   - completionHandler: Un bloque de finalización que devuelve un `Result<[MessageModel], Error>`,
    ///                        donde se entrega la lista de mensajes o un error en caso de fallo.
    func fetchMessagesFromChat(chatID: String) -> AsyncThrowingStream<[MessageModel], Error> {
        Self.makeMessagesStream(
            chatID: chatID,
            encryptionService: messageEncryptionService
        )
    }

    /// Firestore invoca sus listeners desde una cola propia. Crear el callback
    /// fuera del aislamiento del actor evita un `swift_task_checkIsolated` en
    /// Swift 6 y reentra en concurrencia estructurada solo para descifrar.
    private nonisolated static func makeMessagesStream(
        chatID: String,
        encryptionService: MessageEncryptionService
    ) -> AsyncThrowingStream<[MessageModel], Error> {
        AsyncThrowingStream { continuation in
            let query = Firestore.firestore()
                .collection("chats")
                .document(chatID)
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
                        guard var message = try? document.data(as: MessageModel.self) else {
                            continue
                        }
                        message.id = document.documentID

                        if message.encryptionVersion != nil, message.type == .text {
                            do {
                                message = try await encryptionService.decrypt(
                                    message,
                                    chatID: chatID
                                )
                            } catch {
                                message.content = "No se pudo descifrar este mensaje"
                            }
                        }
                        messages.append(message)
                    }
                    continuation.yield(messages)
                }
            }

            let listenerBox = PrivateChatListenerBox(listener)
            continuation.onTermination = { _ in
                listenerBox.remove()
            }
        }
    }

    private nonisolated static func makeChatsStream(
        uid: String
    ) -> AsyncThrowingStream<[ChatModel], Error> {
        AsyncThrowingStream { continuation in
            let query = Firestore.firestore()
                .collection("chats")
                .whereField("participants", arrayContains: uid)
                .order(by: "lastMessageTimestamp", descending: false)

            let listener = query.addSnapshotListener { snapshot, error in
                if let error {
                    AppLogger.error("No se pudieron obtener los chats privados.")
                    continuation.finish(throwing: error)
                    return
                }

                let chats = snapshot?.documents.compactMap {
                    try? $0.data(as: ChatModel.self)
                } ?? []
                continuation.yield(chats)
            }

            let listenerBox = PrivateChatListenerBox(listener)
            continuation.onTermination = { _ in
                listenerBox.remove()
            }
        }
    }

    private nonisolated static func makeUserStream(
        id: String
    ) -> AsyncThrowingStream<UserModel?, Error> {
        AsyncThrowingStream { continuation in
            let reference = Firestore.firestore().collection("users").document(id)
            let listener = reference.addSnapshotListener { snapshot, error in
                if let error {
                    continuation.finish(throwing: error)
                    return
                }

                guard let snapshot, snapshot.exists else {
                    continuation.yield(nil)
                    return
                }

                do {
                    continuation.yield(try snapshot.data(as: UserModel.self))
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            let listenerBox = PrivateChatListenerBox(listener)
            continuation.onTermination = { _ in
                listenerBox.remove()
            }
        }
    }

    /// Elimina un chat específico en Firestore.
    /// - Parameter chatID: El ID del chat que se desea eliminar.
    /// - Throws: Lanza un error si la eliminación falla.
    func deleteChat(chatID: String) async throws {
        let chatRef = database.collection("chats").document(chatID)
        
        do{
            try await chatRef.delete()
            AppLogger.info("Chat privado eliminado.")
        }catch {
            AppLogger.error("No se pudo eliminar el chat privado.")
            throw error
        }
        
    }
    
    /// Elimina todos los chats en los que el usuario participa en Firestore.
    /// - Parameter uiD: El ID del usuario cuyos chats se desean eliminar.
    /// - Throws: Lanza un error si la eliminación falla.
    func deleteAllChatsForUser(uiD: String) async throws {
        let chatsRef = database.collection("chats").whereField("participants", arrayContains: uid)
        
        do{
            let chatsDocument = try await chatsRef.getDocuments()
            let batch = database.batch()
            
            for document in chatsDocument.documents {
                batch.deleteDocument(document.reference) // Agregar eliminación al batch
            }
            
            try await batch.commit()
            AppLogger.info("Chats del usuario eliminados correctamente.")
        }catch{
            AppLogger.error("Error al eliminar chats del usuario.")
            throw error
            
        }
    }
    
    private func encryptedMessageIfNeeded(_ message: MessageModel, chatID: String) async throws -> MessageModel {
        guard message.type == .text, !message.content.isEmpty, message.encryptedContent == nil else {
            return message
        }
        
        let chatSnapshot = try await database.collection("chats").document(chatID).getDocument()
        let participants = chatSnapshot.data()?["participants"] as? [String] ?? []
        let payload = try await messageEncryptionService.encryptText(
            message.content,
            replyingToText: message.replyingToText,
            chatID: chatID,
            messageID: message.id,
            participantIDs: participants
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
    
    /// Envía un mensaje en un chat y actualiza la información del chat en Firestore.
    ///
    /// - Parameters:
    ///   - chatID: El identificador único del chat al que se enviará el mensaje.
    ///   - messageText: El contenido del mensaje a enviar.
    /// - Throws: Lanza un error `PrivateChatServiceError.sendMessageFailed` si ocurre un problema al enviar el mensaje o actualizar el chat.
    func sendMessage(chatID: String, messageText: String) async throws {
        do {
            try await moderationService.assertCanSendPrivateMessage(chatID: chatID)
            // Enviando mensaje en el chat
            let message = MessageModel(id: UUID().uuidString, senderUserID: uid, content: messageText, timestamp: .init(), type: MessageType.text)
            let encryptedMessage = try await encryptedMessageIfNeeded(message, chatID: chatID)
            try await database.collection("chats").document(chatID).collection("messages").document(encryptedMessage.id).setData(encryptedMessage.dictionary)
            
            // Actualizando información del chat
            let updateChatInfo: [String: Any] = [
                "lastMessageTimestamp": encryptedMessage.timestamp,
                "lastMessageSenderUserID": uid,
                "lastMessage": encryptedMessage.encryptionVersion == nil ? encryptedMessage.content : "Mensaje cifrado",
                "lastMessageType": encryptedMessage.type.rawValue
            ]
            try await database.collection("chats").document(chatID).updateData(updateChatInfo)
            try await readStateService.incrementPrivateChat(chatID: chatID, senderID: uid)
        } catch {
            throw PrivateChatServiceError.sendMessageFailed
        }
    }
    
    /// Envía un mensaje avanzado al chat y actualiza los metadatos del chat en Firestore.
    ///
    /// Este método guarda un `MessageModel` completo en la subcolección `messages`
    /// del chat especificado y actualiza los campos de resumen en el documento principal del chat.
    ///
    /// - Parameters:
    ///   - chatID: El identificador del chat al que se enviará el mensaje.
    ///   - message: El objeto `MessageModel` completo a enviar.
    /// - Throws: `PrivateChatServiceError.sendMessageFailed` si ocurre un error al escribir en Firestore.
    func sendAdvancedMessage(chatID: String, message: MessageModel) async throws{
        do{
            try await moderationService.assertCanSendPrivateMessage(chatID: chatID)
            let encryptedMessage = try await encryptedMessageIfNeeded(message, chatID: chatID)
            try await database.collection("chats")
                .document(chatID).collection("messages")
                .document(encryptedMessage.id)
                .setData(encryptedMessage.dictionary)
            
            let updataChatInfo: [String: Any] = [
                "lastMessageTimestamp": encryptedMessage.timestamp,
                "lastMessageSenderUserID": uid,
                "lastMessage": encryptedMessage.encryptionVersion == nil ? encryptedMessage.content : "Mensaje cifrado",
                "lastMessageType": encryptedMessage.type.rawValue
            ]

            try await database.collection("chats").document(chatID).updateData(updataChatInfo)
            try await readStateService.incrementPrivateChat(chatID: chatID, senderID: uid)
        }catch{
            throw PrivateChatServiceError.sendMessageFailed
        }
    }

    func markChatRead(chatID: String) async throws {
        try await readStateService.markPrivateChatRead(chatID: chatID)
    }
    
    /// Lee una sola vez el documento `users/{id}` y devuelve el `UserModel`.
    /// - Returns: `UserModel` si existe, `nil` si el doc. no está.
    /// - Throws: Propaga cualquier error de Firestore.
    func getUserOnce(by id: String) async throws -> UserModel? {
        guard !id.isEmpty else { return nil }
        
        let docRef = database.collection("users").document(id)
        let snapshot = try await docRef.getDocument()
        return try snapshot.data(as: UserModel.self)
    }
   
    /// Actualiza el contenido de un mensaje específico por ID.
    func editMessage(chatsID: String, messageID: String, newContent: String) async throws {
        guard !messageID.isEmpty, !chatsID.isEmpty else{
            throw PrivateChatServiceError.fetchingMessagesFailed
        }
        
        let chatRef = database.collection("chats").document(chatsID)
        let messageRef = chatRef.collection("messages").document(messageID)

        do{
            let message = MessageModel(id: messageID, senderUserID: uid, content: newContent, timestamp: .init(), type: .text)
            let encryptedMessage = try await encryptedMessageIfNeeded(message, chatID: chatsID)
            var updateData: [String: Any] = ["content": encryptedMessage.content]
            updateData["encryptedContent"] = encryptedMessage.encryptedContent ?? FieldValue.delete()
            updateData["encryptedMessageKeys"] = encryptedMessage.encryptedMessageKeys ?? FieldValue.delete()
            updateData["senderPublicKey"] = encryptedMessage.senderPublicKey ?? FieldValue.delete()
            updateData["encryptionVersion"] = encryptedMessage.encryptionVersion ?? FieldValue.delete()
            updateData["encryptionScheme"] = encryptedMessage.encryptionScheme ?? FieldValue.delete()
            try await messageRef.updateData(updateData)
            AppLogger.debug("Editando mensaje privado.")
        }catch{
            AppLogger.error("No se pudo editar el mensaje privado.")
            throw error
        }
    }
    
    /// Marca un mensaje como eliminado, sin borrarlo físicamente.
    func deleteMessage(chatID: String, messageID: String) async throws {
        guard !messageID.isEmpty, !chatID.isEmpty else{
            throw PrivateChatServiceError.fetchingMessagesFailed
        }
        
        let chatRef = database.collection("chats").document(chatID)
        let messageRef = chatRef.collection("messages").document(messageID)
        
        do{
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
            AppLogger.error("El mensaje privado no se ha actualizado.")
            throw error
        }
    }
    
    /// Elimina físicamente un mensaje de Firestore.
    func permanentlyDeleteMessage(chatID: String, messageID: String) async throws {
        guard !messageID.isEmpty, !chatID.isEmpty else{
            throw PrivateChatServiceError.fetchingMessagesFailed
        }
        
        let chatRef = database.collection("chats").document(chatID)
        let messageRef = chatRef.collection("messages").document(messageID)
        
        do{
            try await messageRef.delete()
            AppLogger.info("Mensaje privado eliminado.")
        }catch{
            AppLogger.error("Error al eliminar mensaje privado.")
            throw error
        }
    }
    
    /// Agrega metodo para actualizar la reacción
    func reactToMessage(chatsID: String, messageID: String, emoji: String, userID: String) async throws {
        let chatRef = database.collection("chats").document(chatsID)
        let messageRef = chatRef.collection("messages").document(messageID)
        
        do {
            try await messageRef.updateData(["reactions.\(userID)": emoji])
        } catch {
            AppLogger.error("No se guardó la reacción privada.")
            throw error
        }
    }
    
    
    /// Elimina la reaccion del mensaje
    func removeReaction(fromChatsIDID chatsID: String, messageID: String, userID: String) async throws {
        let chatRef = database.collection("chats").document(chatsID)
        let messageRef = chatRef.collection("messages").document(messageID)
        
        do {
            try await messageRef.updateData(["reactions.\(userID)": FieldValue.delete()])
        }catch{
            AppLogger.error("No se eliminó la reacción privada.")
            throw error
        }
    }
    
}
