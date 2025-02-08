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
     let uid = Auth.auth().currentUser?.uid ?? ""
    private var listenerRegistration: ListenerRegistration?
    
    func removeListener() {
        guard let listener = listenerRegistration else {
            print("")
            return
        }
        
        listener.remove()
        listenerRegistration = nil
    }
    
    func getUser(by id: String) -> AsyncThrowingStream<UserModel?, Error> {
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
    
    func getChats() async throws -> AsyncThrowingStream<[ChatModel], Error> {
        let chatsRef = database.collection("chats").whereField("participants", arrayContains: uid).order(by: "lastMessageTimestamp", descending: false)
        return AsyncThrowingStream { continuation in
            listenerRegistration = chatsRef.addSnapshotListener{ query, error in
                if let error = error {
                    print("No se puede obtenr los Chats: \(error.localizedDescription)")
                    continuation.yield(with: .failure(error))
                }
                
                guard let chatsDocument = query?.documents.compactMap({$0}) else {
                    continuation.yield(with: .success([]))
                    return
                }
                    let chats = chatsDocument.map{try?  $0.data(as: ChatModel.self)}.compactMap{$0}
                    continuation.yield(with: .success(chats))
            }
            
            // Cancelación segura dentro del actor
            continuation.onTermination = { _ in
                Task { await self.removeListener() }
            }
        }
  
    }
    
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
    
//    func deleteAllChatsForUser(uiD: String) async throws {
//        let chatsRef = database.collection("chats").whereField("participants", arrayContains: uid)
//        
//        do{
//            let chatsDocument = try await chatsRef.getDocuments()
//            let batch = database.batch()
//            
//            for document in chatsDocument.documents {
//                do {
//                    try await document.reference.delete()
//                    print("Chat eliminado: \(document.documentID)")
//                } catch {
//                    print("Error al eliminar el chat \(document.documentID): \(error.localizedDescription)")
//                }
//            }
//            
//            try await batch.commit()
//            print("Todos los chats del usuario \(uid) han sido eliminados correctamente.")
//        }catch{
//            print("Error al eliminar los chats del usuario: \(error.localizedDescription)")
//            throw error
//
//        }
//    }
    
//    // Metodo para eliminar todos los chats del Usuario
//    func deleteAllChatsForUser(uI: String, completion: @escaping (Result<Void, Error>) -> Void){
//        let chatsRef = database.collection("chats").whereField("participants", arrayContains: uid)
//        chatsRef.getDocuments{ query, error in
//            if let error = error {
//                print("Error al obtener los chats: \(error.localizedDescription)")
//                completion(.failure(error))
//                return
//            }
//            
//            let batch = self.database.batch()
//            
//            query?.documents.forEach{ document in
//                batch.deleteDocument(document.reference)
//            }
//            
//            batch.commit{ batchError in
//                if let batchError = batchError {
//                    print("Error al eliminar los chats: \(batchError.localizedDescription)")
//                    completion(.failure(batchError))
//                }else {
//                    print("Todo los chats eliminados con exito")
//                    completion(.success(()))
//                }
//            }
//        }
//    }
//    
//    // Metodo para eliminar todos los chats del Usuario
//    func deleteAllChatsForUser(uI: String, completion: @escaping (Result<Void, Error>) -> Void){
//        let chatsRef = database.collection("chats").whereField("participants", arrayContains: uid)
//        chatsRef.getDocuments{ query, error in
//            if let error = error {
//                print("Error al obtener los chats: \(error.localizedDescription)")
//                completion(.failure(error))
//                return
//            }
//            
//            let batch = self.database.batch()
//            
//            query?.documents.forEach{ document in
//                batch.deleteDocument(document.reference)
//            }
//            
//            batch.commit{ batchError in
//                if let batchError = batchError {
//                    print("Error al eliminar los chats: \(batchError.localizedDescription)")
//                    completion(.failure(batchError))
//                }else {
//                    print("Todo los chats eliminados con exito")
//                    completion(.success(()))
//                }
//            }
//        }
//    }
    
//        // Versin async ... Obtener un usuario
//        func getUser(by id: String) async throws -> UserModel?{
//            let userRef = database.collection("user").document(id)
//    
//            do{
//                let document = try await userRef.getDocument()
//                guard let data = document.data() else {
//                    throw NSError(domain: "Firestore", code: 404, userInfo: [NSLocalizedDescriptionKey: "Usuario no encontrado"])
//                }
//    
//                return try document.data(as: UserModel.self)
//            }catch {
//                print("Error al obterner los datos del usuario \(error.localizedDescription)")
//                throw error
//            }
//        }
//     

//    // Traerme los chas de este usuario en tiempo real
//    func fetchChats(completion: @escaping(Result<[ChatModel], Error >) -> Void){
//        let chatsRef = database.collection("chats").whereField("participants", arrayContains: uid).order(by: "lastMessageTimestamp", descending: false)
//        
//        chatsRef.addSnapshotListener { query, error in
//            if let error = error{
//                print("No se puede obtenido los chats: \(error.localizedDescription )")
//                completion(.failure(error))
//                return
//            }
//            
//            guard let chatDocument = query?.documents.compactMap({$0})  else{
//                completion(.success([]))
//                return
//            }
//            
//            let chats = chatDocument.map{try? $0.data(as: ChatModel.self)}.compactMap{$0}
//            print(chats)
//            completion(.success(chats))
//            
//        } 
//    }
// 
    
//    // Obtener un usuario por ID ...
//    func getUser(by id: String, completion: @escaping (Result<UserModel?, Error>) -> Void) {
//        let userRef = database.collection("users").document(id)
//        
//        userRef.getDocument { query, error in
//            if let error = error {
//                print("Error al intentar traer los datos del usuario \(error)")
//                completion(.failure(error))
//                return
//            }
//            
//            guard let document = query, document.exists else {
//                let defaultError = NSError(domain: "Firestore", code: 404, userInfo: [NSLocalizedDescriptionKey: "Usuario no encontrado"])
//                print("Usuario no encontrado")
//                completion(.failure(defaultError))
//                return
//            }
//            
//            // Intentamos convertir el documento a UserModel
//            let user = try? document.data(as: UserModel.self)
//            completion(.success(user))
//        }
//    }
    
}
