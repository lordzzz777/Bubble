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
    
    /// 🔹 **Obtener un usuario por ID**
    func getUser(by id: String ,completion: @escaping(UserModel?) -> Void) {
        let userRef = database.collection("users").document(id)
        userRef.getDocument{ document, error in
            guard let document = document, document.exists, let user = try? document.data(as: UserModel.self) else {
                print("Usuario no encontrado o error: \(error?.localizedDescription ?? "Desconocido")")
                completion(nil)
                return
            }
            completion(user)
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
