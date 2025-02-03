//
//  ChatViewModel.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 1/2/25.
//

import Foundation
import FirebaseFirestore
import Observation

@Observable
class ChatViewModel{
    private var database = Firestore.firestore()
    private var userService = UserService()
    private var firestoreService = FirestoreService()
   
    var user: UserModel?
    
    //var userModel: [UserModel] = []
    var chats: [ChatModel] = []
    var messages: [MessageModel] = []
    var isfetchChatsError = false
    
    // Cargar Usuarios
    @MainActor
    func fetchUser(userID: String){
       
        userService.getUser(by: userID){ user in
                DispatchQueue.main.async{
                    self.user = user
                }
            }
        
    }
    
    func updateUserOnlineStatus(userID: String, isOnline: Bool) {
        userService.updateUserOnlineStatus(userID: userID, isOnline: isOnline)
    }
    
    func updateLastConnection(userID: String) {
        userService.updateLastConnection(userID: userID)
    }
    
    
    // Formatea Timestamp para combertir en String
    func formatTimestamp(_ timestamp: Timestamp) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm" // Formato personalizado
        
        return formatter.string(from: timestamp.dateValue())
    }
    
    // Cargar los chats
    @MainActor
    func fetchChats(){
        database.collection("chats").order(by: "lastMessageTimestamp", descending: true).addSnapshotListener{ [weak self] snapshot, error in
            guard let documents = snapshot?.documents, error == nil else {
                print("Error al obtener chats: \(error?.localizedDescription ?? "Desconocido")")
                self?.isfetchChatsError = true
                return
            }
            
            self?.chats = documents.compactMap{ doc -> ChatModel? in
                try? doc.data(as: ChatModel.self)
            }
        }
    }
    
    // Cargar mensaje de un chat
    func fetchMessages(for chatID: String) {
        database.collection("chats").document(chatID).collection("message").order(by: "timestamp", descending: false).addSnapshotListener { [weak self] snapshot, error in
            
            guard let documens = snapshot?.documents, error == nil else {
                print("Error al obtener mensajes: \(error?.localizedDescription ?? "Desconocido")")
                return
            }
            
            self?.messages = documens.compactMap{ doc -> MessageModel? in
                try? doc.data(as: MessageModel.self)
            }
        }
        
    }
    

}
