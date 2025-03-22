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
        let database = Firestore.firestore()
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
                    
                    let messages = documents.compactMap { try? $0.data(as: MessageModel.self) }
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
        let database = Firestore.firestore()
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
}
