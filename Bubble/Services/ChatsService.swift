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

class ChatsService {
    
    private let database = Firestore.firestore()
    private let uid = Auth.auth().currentUser?.uid ?? ""
    
    
    // Obtener un usuario por ID ...
    func getUser(by id: String, completion: @escaping (Result<UserModel?, Error>) -> Void) {
        let userRef = database.collection("users").document(id)
        
        userRef.getDocument { query, error in
            if let error = error {
                print("Error al intentar traer los datos del usuario \(error)")
                completion(.failure(error))
                return
            }
            
            guard let document = query, document.exists else {
                let defaultError = NSError(domain: "Firestore", code: 404, userInfo: [NSLocalizedDescriptionKey: "Usuario no encontrado"])
                print("Usuario no encontrado")
                completion(.failure(defaultError))
                return
            }
            
            // Intentamos convertir el documento a UserModel
            let user = try? document.data(as: UserModel.self)
            completion(.success(user))
        }
    }
    
    
    // Traerme los chas de este usuario en tiempo real
    func fetchChats(completion: @escaping(Result<[ChatModel], Error >) -> Void){
        let chatsRef = database.collection("chats").whereField("participants", arrayContains: uid)
        
        chatsRef.addSnapshotListener { query, error in
            if let error = error{
                print("No se puede obtenido los chats: \(error.localizedDescription )")
                completion(.failure(error))
                return
            }
            
            guard let chatDocument = query?.documents.compactMap({$0})  else{
                completion(.success([]))
                return
            }
            
            let chats = chatDocument.map{try? $0.data(as: ChatModel.self)}.compactMap{$0}
            print(chats)
            completion(.success(chats))
            
        }
        
    }
    
    // Metodo para eliminar los chats
    func deleteChat(chatID: String, completion: @escaping (Result<Void, Error>) -> Void){
        let chatRef = database.collection("chats").document(chatID)
        
        chatRef.delete{ error in
            if let error = error {
                print("Error al eliminar el chat: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }else {
                print("El chat se ha eliminado con exito")
                completion(.success(()))
            }
        }
    }
    
    // Metodo para eliminar todos los chats del Usuario
    func deleteAllChatsForUser(uI: String, completion: @escaping (Result<Void, Error>) -> Void){
        let chatsRef = database.collection("chats").whereField("participants", arrayContains: uid)
        chatsRef.getDocuments{ query, error in
            if let error = error {
                print("Error al obtener los chats: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            let batch = self.database.batch()
            
            query?.documents.forEach{ document in
                batch.deleteDocument(document.reference)
            }
            
            batch.commit{ batchError in
                if let batchError = batchError {
                    print("Error al eliminar los chats: \(batchError.localizedDescription)")
                    completion(.failure(batchError))
                }else {
                    print("Todo los chats eliminados con exito")
                    completion(.success(()))
                }
            }
        }
    }
    
    
    
}
