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

@Observable @MainActor
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
   
    func fetchUser(userID: String) async{
        do{
            let userData = try await userService.getUser(id: userID)
            user = userData
        }catch {
            errorTitle = ""
            errorDescription = ""
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
    
    func deleteChat(id: String) async {
        do{
           try await userService.deleteChat(chatID: id)
        }catch{
            errorTitle = "no se pudo eliminar el Chat"
            errorDescription = "Ocurrio un error desconocido al eliminar el chat, intentelo mas tarde"
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
