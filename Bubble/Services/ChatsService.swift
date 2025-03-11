//
//  UserService.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 3/2/25.
//

import Foundation
import FirebaseCore
import Firebase
import FirebaseAuth


actor ChatsService {
    
    private let database = Firestore.firestore()
    private let uid = Auth.auth().currentUser?.uid ?? ""
    private var listenerRegistration: ListenerRegistration?
    
    /// Detiene la escucha activa en Firestore y libera la referencia del listener.
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

    /// Obtiene los chats en tiempo real en los que el usuario participa.
    /// - Returns: Un `AsyncThrowingStream` que emite un array de `ChatModel` y maneja errores.
    nonisolated func getChats() -> AsyncThrowingStream<[ChatModel], Error>  {
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
}
