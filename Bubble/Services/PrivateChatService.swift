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

enum PrivateChatServiceError: Error {
    case fetchingMessagesFailed
    case fetchingDocumentsFailed
    case sendMessageFailed
}

actor PrivateChatService {
    
    private let database = Firestore.firestore()
    private let uid = Auth.auth().currentUser?.uid ?? ""
    private var listenerRegistration: ListenerRegistration?
    
    /// Obtiene los chats en tiempo real en los que el usuario participa.
    /// - Returns: Un `AsyncThrowingStream` que emite un array de `ChatModel` y maneja errores.
    func getChats() -> AsyncThrowingStream<[ChatModel], Error>  {
        let chatsRef = database.collection("chats")
            .whereField("participants", arrayContains: uid)
            .order(by: "lastMessageTimestamp", descending: false)
        
        return AsyncThrowingStream {continuation in
            chatsRef.addSnapshotListener{ query, error in
                if let error = error {
                    print("No se pudo obtener los chat: \(error.localizedDescription)")
                    continuation.finish()
                    return
                }
                
                guard let doc = query?.documents.compactMap({$0}) else {
                    print("El documento chat esta vacio o no existe")
                    continuation.yield(with: .success([]))
                    return
                }
                
                let chats = doc.map{try? $0.data(as: ChatModel.self)}.compactMap{$0}
                continuation.yield(with: .success(chats))
            }
            
            // Cancelación segura dentro del actor
            continuation.onTermination = { _ in
                Task { await self.removeListener() }
            }
        }
        
    }
    
    /// Detiene la escucha activa en Firestore y libera la referencia del listener.
    ///
    /// - Nota: Si no hay un listener activo, imprime un mensaje en la consola.
    func removeListener() {
        guard let listener = listenerRegistration else {
            print("No hay listener activo")
            return
        }
        
        listener.remove()
        listenerRegistration = nil
    }
    
    func checkIfFriend(friendID: String) async throws -> Bool {
        do {
            let document = try await database.collection("users").document(uid).getDocument()
            guard let userData = try? document.data(as: UserModel.self) else {
                fatalError("No se pudo obtener el usuario")
            }
            print("Are users friends \(userData.friends.contains(friendID))")
            return userData.friends.contains(friendID)
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
        let userRef = database.collection("users").document(id)
        
        return AsyncThrowingStream { continuation in
            listenerRegistration = userRef.addSnapshotListener { documentSnapshot, error in
                if let error = error {
                    continuation.yield(with: .failure(error))
                    return
                }
                
                guard let document = documentSnapshot, document.exists else {
                    continuation.yield(with: .success(nil))
                    return
                }
                
                do {
                    let user = try document.data(as: UserModel.self)
                    continuation.yield(with: .success(user))
                } catch {
                    continuation.yield(with: .failure(error))
                }
            }
            
            // Cancelación segura dentro del actor
            continuation.onTermination = { _ in
                Task { await self.removeListener() }
            }
        }
    }
    
    /// Obtiene los mensajes de un chat en tiempo real usando un `SnapshotListener`.
    ///
    /// - Parameters:
    ///   - chatID: El identificador único del chat del cual se desean obtener los mensajes.
    ///   - completionHandler: Un bloque de finalización que devuelve un `Result<[MessageModel], Error>`,
    ///                        donde se entrega la lista de mensajes o un error en caso de fallo.
    func fetchMessagesFromChat(chatID: String) -> AsyncThrowingStream<[MessageModel], Error> {
        return AsyncThrowingStream { continuation in
            let listener = database.collection("chats")
                .document(chatID)
                .collection("messages")
                .order(by: "timestamp", descending: false)
                .addSnapshotListener { snapshot, error in
                    if let error = error {
                        continuation.finish(throwing: error)
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        continuation.yield([])
                        return
                    }
                    
                    let messages = documents.compactMap { doc -> MessageModel? in
                        // Intenta decodificar el documento a MessageModel
                        guard var msg = try? doc.data(as: MessageModel.self) else { return nil }
                        // Sobrescribe el id con el verdadero documentID
                        msg.id = doc.documentID
                        return msg
                    }

//                    let messages = documents.compactMap { try? $0.data(as: MessageModel.self) }
                    continuation.yield(messages)
                }
            
            // Asegurar que el listener se elimine cuando ya no se use
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    /// Elimina un chat específico en Firestore.
    /// - Parameter chatID: El ID del chat que se desea eliminar.
    /// - Throws: Lanza un error si la eliminación falla.
    func deleteChat(chatID: String) async throws {
        let chatRef = database.collection("chats").document(chatID)
        
        do{
            try await chatRef.delete()
            print("El chat se ha eliminado con exito")
        }catch {
            print("Error no se a podido eliminar \(error.localizedDescription)")
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
            print("Todos los chats del usuario \(uid) han sido eliminados correctamente.")
        }catch{
            print("Error al eliminar los chats del usuario: \(error.localizedDescription)")
            throw error
            
        }
    }
    
    /// Envía un mensaje en un chat y actualiza la información del chat en Firestore.
    ///
    /// - Parameters:
    ///   - chatID: El identificador único del chat al que se enviará el mensaje.
    ///   - messageText: El contenido del mensaje a enviar.
    /// - Throws: Lanza un error `PrivateChatServiceError.sendMessageFailed` si ocurre un problema al enviar el mensaje o actualizar el chat.
    func sendMessage(chatID: String, messageText: String) async throws {
        do {
            // Enviando mensaje en el chat
            let message = MessageModel(senderUserID: uid, content: messageText, timestamp: .init(), type: MessageType.text)
            try await database.collection("chats").document(chatID).collection("messages").addDocument(data: message.dictionary)
            
            // Actualizando información del chat
            let updateChatInfo: [String: Any] = [
                "lastMessageTimestamp": message.timestamp,
                "lastMessageSenderUserID": uid,
                "lastMessage": message.content,
                "lastMessageType": message.type.rawValue
            ]
            try await database.collection("chats").document(chatID).updateData(updateChatInfo)
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
            try await database.collection("chats")
                .document(chatID).collection("messages")
                .document(message.id)
                .setData(message.dictionary)
            
            let updataChatInfo: [String: Any] = [
                "lastMessageTimestamp": message.timestamp,
                "lastMessageSenderUserID": uid,
                "lastMessage": message.content,
                "lastMessageType": message.type.rawValue
            ]

            try await database.collection("chats").document(chatID).updateData(updataChatInfo)
        }catch{
            throw PrivateChatServiceError.sendMessageFailed
        }
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
            try await messageRef.updateData(["content": newContent])
            print("Editando mensaje con ID: \(messageID)")
        }catch{
            print("Error desde server: No se pudo editar: ")
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
            try await messageRef.updateData(["content": "Mensaje eliminado"])
        }catch{
            print("Mensaje del server -> Error, el mensaje no se ha actualizado")
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
            print("Mensaje eliminado con exito")
        }catch{
            print("Mensaje del server -> Error Al eliminar mensaje: ")
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
            print("Error Server: no se guardó la reacción")
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
            print("Error Server: no se elimino la reacción")
            throw error
        }
    }
    
}
