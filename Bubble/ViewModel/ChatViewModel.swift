//
//  ChatViewModel.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 1/2/25.
//

import Foundation
import FirebaseFirestore
import Observation
import FirebaseAuth

@Observable
class ChatViewModel{

    private var userService = ChatsService()
    private var firestoreService = FirestoreService()
   
    var user: UserModel?
    
    //var userModel: [UserModel] = []
    var chats: [ChatModel] = []
    var messages: [MessageModel] = []
    var isfetchChatsError = false
    var errorTitle = ""
    var errorDescription = ""
    
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

    func fetchChats(){
        
        userService.fetchChats { [weak self] result in
            switch result {
            case .success(let success):
                self?.chats = success
            case .failure(_):
                self?.isfetchChatsError = true
                self?.errorTitle = "Error al obtener los chats"
                self?.errorDescription = "Ocurrió un error desconocido al obtener los chas, intentelo mas tarde"
            }
        }
        
    }
    

    
//    // Cargar mensaje de un chat
//    func fetchMessages(for chatID: String) {
//        database.collection("chats").document(chatID).collection("message").order(by: "timestamp", descending: false).addSnapshotListener { [weak self] snapshot, error in
//            
//            guard let documens = snapshot?.documents, error == nil else {
//                print("Error al obtener mensajes: \(error?.localizedDescription ?? "Desconocido")")
//                return
//            }
//            
//            self?.messages = documens.compactMap{ doc -> MessageModel? in
//                try? doc.data(as: MessageModel.self)
//            }
//        }
//        
//    }
//    
//    // Eliminar Chat y susmensajes
//    func deleteChat(chatID: String){
//        let chatRef = database.collection("chats").document(chatID)
//        
//        // Elimina todos los mensajes dentro del Chat
//        chatRef.collection("message").getDocuments { snapshot, error in
//            guard let documents = snapshot?.documents else {
//                print("No hay mensajes para eliminar o error: \(error?.localizedDescription ?? "Desconocido")")
//                return
//            }
//            
//            for document in documents {
//                document.reference.delete()
//            }
//            
//            // Eliminar el chat una vez que se elimine los mesajes
//            chatRef.delete { error in
//                
//                if error != nil {
//                    print("")
//                } else {
//                    
//                }
//            }
//        }
//    }
    
    func getFriendID(_ ids: [String]) -> String {
        var friendID = ""
        let uID = Auth.auth().currentUser?.uid ?? ""
        ids.forEach { id in
            if id != uID {
                friendID = id
            }
        }
        return friendID
    }

}
