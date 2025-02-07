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
    var chats: [ChatModel] = []
    var messages: [MessageModel] = []
    
    let visibilityOptions = ["privado", "Publico"]
    var selectedVisibility = "privado"
    var searchText = ""
    var errorTitle = ""
    var errorDescription = ""
    var successMessasTitle = ""
    var successMessasDescription = ""
    
    var isMessageDestructive = false
    var isfetchChatsError = false
    var isSuccessMessas = false
    var isWiffi = false
    
    // Cargar Usuarios
    @MainActor
    func fetchUser(userID: String){
        userService.getUser(by: userID){ [weak self] result in
            switch result {
            case .success(let success):
                self?.user = success
            case .failure(_):
                self?.isfetchChatsError = true
                self?.errorTitle = "Error al traerte el usuario"
                self?.errorDescription = "Ocurrió un error por el cual no se apodido mostrar el ususrio intentelo mas tarde"
            }
        }
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
    
    // Metodo para eliminar un solo chat
    func deleteChat(chatID: String){
        userService.deleteChat(chatID: chatID) { [weak self] result in
            
            switch result{
            case .success(_):
                self?.successMessasTitle = "Exrito"
                self?.successMessasDescription = "El chat se ha eliminado con exito"
                self?.isSuccessMessas = true
                self?.chats.removeAll(where: {$0.id == chatID})
            case .failure(_):
                self?.errorTitle = "Error"
                self?.errorDescription = "El chat no se ha podido eliminar, intentelo mas tarde"
                self?.isfetchChatsError = true
            }
        }
    }
    
    // Metodo para leliminar todos los chat del usuario
    func deleteChats(uid: String){
        userService.deleteAllChatsForUser(uI: uid){ [weak self] result in
            
            switch result{
            case .success:
                self?.successMessasTitle = "Exrito"
                self?.successMessasDescription = "Los chats se ha eliminado con exito"
                self?.isSuccessMessas = true
                self?.chats.removeAll(where: {$0.id == uid})
            case .failure(_):
                self?.errorTitle = "Error"
                self?.errorDescription = "Los chats no se ha podido eliminar, intentelo mas tarde"
                self?.isfetchChatsError = true
            }
        }
    }
    
    // Obtener el idi del usuario
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
    
    // Formatea Timestamp para combertir en String
    func formatTimestamp(_ timestamp: Timestamp) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm" // Formato personalizado
        
        return formatter.string(from: timestamp.dateValue())
    }

}
