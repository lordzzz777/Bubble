//
//  UserService.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 3/2/25.
//

import Foundation
import FirebaseCore
import Firebase

class UserService {
    private let database = Firestore.firestore()
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
    func fetchMessages(for chatID: String , completion: @escaping([MessageModel]) -> Void){
        
        let messagesRef = database.collection("chats").document(chatID).collection("message")
        
        messagesRef.order(by: "timestamp", descending: false).getDocuments{ snapshot, error in
            guard let documents = snapshot?.documents, error == nil else {
                print("Error al obtener mensajes: \(error?.localizedDescription ?? "Desconocido")")
                completion([])
                return
            }
            
            let messages = documents.compactMap { doc -> MessageModel? in
                try? doc.data(as: MessageModel.self)
            }
            
            completion(messages)
            
        }
    }
}
