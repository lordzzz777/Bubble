//
//  UserService.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 3/2/25.
//

import Foundation
import FirebaseCore
@preconcurrency import Firebase
import FirebaseAuth

final class ChatsService {
    
    private let database = Firestore.firestore()
    private let uid = Auth.auth().currentUser?.uid ?? ""
    
    func getUser(id: String, completion: @escaping (Result<UserModel, Error >) -> Void){
     let document =  database.collection("user").document(id)
        document.addSnapshotListener{ query, error in
            if let error = error {
                print("Error al recivir los datos de usurio: \(error) ")
                return
            }
            
            guard let document = query, document.exists else {
                completion(.failure(NSError(domain: "Firestore", code: 404, userInfo: [NSLocalizedDescriptionKey: "Usuario no encontrado"])))
                return
            }
                
            do{
                let user = try document.data(as: UserModel.self)
                completion(.success(user))
            }catch {
                completion(.failure(error))
            }
        }
    }
    
//    @MainActor func getUser(id: String) async throws -> UserModel {
//        
//        do{
//            let document = try await database.collection("user").document(id).getDocument()
//            let userData = try document.data(as: UserModel.self)
//            return userData
//        }catch {
//            throw error
//        }
//    }
    
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
    func fetchChats(completion: @escaping (Result<[ChatModel], Error >) -> Void){
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
    
    // Eliminar Chats
    
    @MainActor func deleteChat(chatID: String) async throws {

        do{
            try await database.collection("chats").document(chatID).delete()
        }catch {
            throw error
        }
    }
}
