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


    /// 🔹 **Actualizar el estado en línea**
    func updateUserOnlineStatus(userID: String, isOnline: Bool) {
        database.collection("users").document(userID).updateData(["isOnline": isOnline]) { error in
            if let error = error {
                print("Error al actualizar estado online: \(error.localizedDescription)")
            }
        }
    }
    
    
    /// 🔹 **Actualizar la última conexión**
    func updateLastConnection(userID: String) {
        database.collection("users").document(userID).updateData(["lastConnectionTimestamp": Timestamp()]) { error in
            if let error = error {
                print("Error al actualizar la última conexión: \(error.localizedDescription)")
            }
        }
    }
    
    
    // Traerme los chas de este usuario en tiempo real
    func fetchChats(completion: @escaping(Result<[ChatModel], Error >) -> Void){
        let chatsRef = database.collection("chats").whereField("participants", arrayContains: uid)
        
        chatsRef.addSnapshotListener { query, error in
            if let errors = error{
                print("No se puede motrar los chats: \(errors.localizedDescription )")
                completion(.failure(errors))
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
}
